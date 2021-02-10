--- ============================ HEADER ============================
--- ======= LOCALIZE =======
-- Addon
local addonName, addonTable = ...
-- HeroDBC
local DBC = HeroDBC.DBC
-- HeroLib
local HL = HeroLib
local Cache = HeroCache
local Unit = HL.Unit
local Player = Unit.Player
local Pet = Unit.Pet
local Target = Unit.Target
local Spell = HL.Spell
local MultiSpell = HL.MultiSpell
local Item = HL.Item
-- HeroRotation
local HR = HeroRotation
local AoEON = HR.AoEON
local CDsON = HR.CDsON
-- Lua


--- ============================ CONTENT ============================
--- ======= APL LOCALS =======

-- Define S/I for spell and item arrays
local S = Spell.Shaman.Elemental
local I = Item.Shaman.Elemental

-- Create table to exclude above trinkets from On Use function
local OnUseExcludes = {
}

-- Rotation Var
local Enemies40y, Enemies40yCount, EnemiesCount10ySplash
local SEActive, FEActive
local EnemiesFlameShockCount = 0
local EnemiesWithFlameShockDebuff
local DeeptremorStoneEquipped = Player:HasLegendaryEquipped(131)
local ElementalEquilibriumEquipped = Player:HasLegendaryEquipped(135)
local EchoesofGreatSunderingEquipped = Player:HasLegendaryEquipped(136)

-- GUI Settings
local Everyone = HR.Commons.Everyone
local Settings = {
  General = HR.GUISettings.General,
  Commons = HR.GUISettings.APL.Shaman.Commons,
  Elemental = HR.GUISettings.APL.Shaman.Elemental
}

HL:RegisterForEvent(function()
  DeeptremorStoneEquipped = Player:HasLegendaryEquipped(131)
  ElementalEquilibriumEquipped = Player:HasLegendaryEquipped(135)
  EchoesofGreatSunderingEquipped = Player:HasLegendaryEquipped(136)
end, "PLAYER_EQUIPMENT_CHANGED")

HL:RegisterForEvent(function()
  S.ElementalBlast:RegisterInFlight()
end, "LEARNED_SPELL_IN_TAB")
S.ElementalBlast:RegisterInFlight()


local function num(val)
  if val then return 1 else return 0 end
end

local function bool(val)
  return val ~= 0
end

-- Counter for Debuff on other enemies
local function calcEnemiesFlameShockCount(Object, Enemies)
  local debuffs = 0;
  if HR.AoEON() then
    for _, CycleUnit in pairs(Enemies) do
      if CycleUnit:DebuffUp(Object) then
        debuffs = debuffs + 1;
        EnemiesFlameShockCount = debuffs
      end
    end
  end
end

local function EvaluateCycleFlameShock(TargetUnit)
  return (TargetUnit:DebuffRefreshable(S.FlameShockDebuff))
end

local function EvaluateCycleLavaBurst200(TargetUnit)
  return (TargetUnit:DebuffUp(S.FlameShockDebuff))
end

local function EvaluateCycleFlameShock202(TargetUnit)
  return (TargetUnit:DebuffRemains(S.FlameShockDebuff) <= Player:GCD() and (Player:BuffUp(S.LavaSurgeBuff) or Player:BloodlustDown()))
end

local function EvaluateCycleFlameShock204(TargetUnit)
  return ((TargetUnit:DebuffRemains(S.FlameShockDebuff) <= Player:GCD() or S.Ascendance:IsAvailable() and Target:DebuffRemains(S.FlameShockDebuff) < (S.Ascendance:CooldownRemains() + S.Ascendance:BaseDuration()) and S.Ascendance:CooldownRemains() < 4) and (Player:BuffUp(S.LavaSurgeBuff) or Player:BloodlustDown()))
end

-- prioritize targets with flame shock when casting lava burst
local function EvaluateCycleLavaBurstOnFlameShockTargets(TargetUnit)
  return TargetUnit:DebuffUp(S.FlameShockDebuff) and (TargetUnit:AffectingCombat() or TargetUnit:IsDummy())
end

local function Precombat()
  -- flask
  -- food
  -- augmentation
  -- lightning_shield
  if S.LightningShield:IsCastable() and Player:BuffDown(S.LightningShield) then
    if HR.Cast(S.LightningShield) then return "lightning_shield precombat 1"; end
  end
  --actions.precombat+=/earth_elemental,if=!talent.primal_elementalist.enabled
  if S.EarthElemental:IsCastable() and not S.PrimalElementalist:IsAvailable() then
    if HR.Cast(S.EarthElemental, Settings.Commons.GCDasOffGCD.EarthElemental) then return "earth_elemental precombat 2"; end
  end
  --# Use Stormkeeper precombat unless some adds will spawn soon.
  -- actions.precombat+=/stormkeeper,if=talent.stormkeeper.enabled&(raid_event.adds.count<3|raid_event.adds.in>50)
  if S.Stormkeeper:IsCastable() and S.Stormkeeper:IsAvailable() then
    if HR.Cast(S.Stormkeeper, Settings.Elemental.GCDasOffGCD.Stormkeeper) then return "stormkeeper precombat 3"; end
  end
  -- actions.precombat+=/elemental_blast,if=talent.elemental_blast.enabled
  if S.ElementalBlast:IsCastable() and S.ElementalBlast:IsAvailable() then
    if HR.Cast(S.ElementalBlast, nil, nil, not Target:IsSpellInRange(S.ElementalBlast)) then return "elemental_blast precombat 4"; end
  end
  -- actions.precombat+=/lava_burst,if=!talent.elemental_blast.enabled
  if S.LavaBurst:IsCastable() and not S.ElementalBlast:IsAvailable() then
    if Everyone.CastCycle(S.LavaBurst, Enemies40y, EvaluateCycleLavaBurstOnFlameShockTargets, not Target:IsSpellInRange(S.LavaBurst)) then return "lava_burst precombat 4"; end
  end
  -- potion
  -- snapshot_stats
end

local function Aoe()
  -- earthquake,if=buff.echoing_shock.up
  if S.Earthquake:IsReady() and Player:MaelstromP() >= 60 and (Player:BuffUp(S.EchoingShockBuff)) then
    if HR.Cast(S.Earthquake) then return "earthquake aoe 2"; end
  end
  -- chain_harvest
  if S.ChainHarvest:IsReady() then
    if HR.Cast(S.ChainHarvest, nil, Settings.Commons.CovenantDisplayStyle, not Target:IsSpellInRange(S.ChainHarvest)) then return "chain_harvest aoe 4"; end
  end
  -- stormkeeper,if=talent.stormkeeper.enabled
  if S.Stormkeeper:IsCastable() and not Player:IsCasting(S.Stormkeeper) then
    if HR.Cast(S.Stormkeeper, Settings.Elemental.GCDasOffGCD.Stormkeeper) then return "stormkeeper aoe 6"; end
  end
  -- flame_shock,if=active_dot.flame_shock<3&active_enemies<=5,target_if=refreshable
  if S.FlameShock:IsReady() and (EnemiesFlameShockCount < 3 and EnemiesCount10ySplash <= 5) then
    if Everyone.CastCycle(S.FlameShock, Enemies40y, EvaluateCycleFlameShock, not Target:IsSpellInRange(S.FlameShock)) then return "flame_shock aoe 8"; end
  end
  -- flame_shock,if=!active_dot.flame_shock
  if S.FlameShock:IsReady() and (Target:DebuffDown(S.FlameShockDebuff)) then
    if HR.Cast(S.FlameShock, nil, nil, not Target:IsSpellInRange(S.FlameShock)) then return "flame_shock aoe 10"; end
  end
  -- echoing_shock,if=talent.echoing_shock.enabled&maelstrom>=60
  if S.EchoingShock:IsReady() and S.EchoingShock:IsAvailable() and Player:MaelstromP() >= 60 then
    if HR.Cast(S.EchoingShock, Settings.Elemenal.GCDasOffGCD.EchoingShock) then return "echoing_shock aoe 12"; end
  end
  -- ascendance,if=talent.ascendance.enabled&(!pet.storm_elemental.active)&(!talent.icefury.enabled|!buff.icefury.up&!cooldown.icefury.up)
  if S.Ascendance:IsCastable() and ((not SEActive) and (not S.Icefury:IsAvailable() or not Player:BuffUp(S.IcefuryBuff) and not S.Icefury:CooldownUp())) then
    if HR.Cast(S.Ascendance, Settings.Elemental.GCDasOffGCD.Ascendance) then return "ascendance aoe 14"; end
  end
  -- liquid_magma_totem,if=talent.liquid_magma_totem.enabled
  if S.LiquidMagmaTotem:IsReady() then
    if HR.Cast(S.LiquidMagmaTotem) then return "liquid_magma_totem aoe 16"; end
  end
  -- earth_shock,if=runeforge.echoes_of_great_sundering.equipped&!buff.echoes_of_great_sundering.up
  if EchoesofGreatSunderingEquipped and Player:BuffDown(S.EchoesofGreatSunderingBuff) and Player:MaelstromP() >= 60 then
    if HR.Cast(S.EarthShock, nil, nil, not Target:IsSpellInRange(S.EarthShock)) then return "earth_shock aoe 18"; end
  end
  -- earth_elemental,if=runeforge.deeptremor_stone.equipped&(!talent.primal_elementalist.enabled|(!pet.storm_elemental.active&!pet.fire_elemental.active))
  if S.EarthElemental:IsCastable() and (DeeptremorStoneEquipped and (not S.PrimalElementalist:IsAvailable() or (not SEActive and not FEActive))) then
    if HR.Cast(S.EarthElemental, Settings.Commons.GCDasOffGCD.EarthElemental) then return "earth_elemental aoe 20"; end
  end
  -- lavaburst,target_if=dot.flame_shock.remains,if=spell_targets.chain_lightning<4|buff.lava_surge.up|(talent.master_of_the_elements.enabled&!buff.master_of_the_elements.up&maelstrom>=60)
  if S.LavaBurst:IsReady() and (EnemiesCount10ySplash < 4 or Player:BuffUp(S.LavaSurgeBuff) or (S.MasterOfTheElements:IsAvailable() and Player:BuffDown(S.MasterOfTheElementsBuff) and Player:MaelstromP() >= 60)) then
    if Everyone.CastCycle(S.LavaBurst, Enemies40y, EvaluateCycleLavaBurst200, not Target:IsSpellInRange(S.LavaBurst)) then return "lava_burst aoe 22"; end
  end
  -- earthquake,if=!talent.master_of_the_elements.enabled|buff.stormkeeper.up|maelstrom>=(100-4*spell_targets.chain_lightning)|buff.master_of_the_elements.up|spell_targets.chain_lightning>3
  if S.Earthquake:IsReady() and Player:MaelstromP() >= 60 and (not S.MasterOfTheElements:IsAvailable() or Player:BuffUp(S.StormkeeperBuff) or Player:MaelstromP() >= (100 - 4 * EnemiesCount10ySplash) or Player:BuffUp(S.MasterOfTheElementsBuff) or EnemiesCount10ySplash > 3) then
    if HR.Cast(S.Earthquake) then return "earthquake aoe 24"; end
  end
  -- chain_lightning,if=buff.stormkeeper.remains<3*gcd*buff.stormkeeper.stack
  if S.ChainLightning:IsReady() and (Player:BuffRemains(S.StormkeeperBuff) < 3 * Player:GCD() * Player:BuffStack(S.StormkeeperBuff)) then
    if HR.Cast(S.ChainLightning, nil, nil, not Target:IsSpellInRange(S.ChainLightning)) then return "chain_lightning aoe 26"; end
  end
  -- lava_burst,if=buff.lava_surge.up&spell_targets.chain_lightning<4&(!pet.storm_elemental.active)&dot.flame_shock.ticking
  if S.LavaBurst:IsReady() and (Player:BuffUp(S.LavaSurgeBuff) and EnemiesCount10ySplash < 4 and (not SEActive) and Target:DebuffUp(S.FlameShockDebuff)) then
    if Everyone.CastCycle(S.LavaBurst, Enemies40y, EvaluateCycleLavaBurstOnFlameShockTargets, not Target:IsSpellInRange(S.LavaBurst)) then return "lava_burst aoe 28"; end
  end
  -- elemental_blast,if=talent.elemental_blast.enabled&spell_targets.chain_lightning<5&(!pet.storm_elemental.active)
  if S.ElementalBlast:IsReady() and not Player:IsCasting(S.ElementalBlast) and not S.ElementalBlast:InFlight() and (EnemiesCount10ySplash < 5 and (not SEActive)) then
    if HR.Cast(S.ElementalBlast, nil, nil, not Target:IsSpellInRange(S.ElementalBlast)) then return "elemental_blast aoe 30"; end
  end
  -- lava_beam,if=talent.ascendance.enabled
  if S.LavaBeam:IsReady() then
    if Everyone.CastCycle(S.LavaBurst, Enemies40y, EvaluateCycleLavaBurstOnFlameShockTargets, not Target:IsSpellInRange(S.LavaBurst)) then return "lava_beam aoe 32"; end
  end
  -- chain_lightning
  if S.ChainLightning:IsReady() then
    if HR.Cast(S.ChainLightning, nil, nil, not Target:IsSpellInRange(S.ChainLightning)) then return "chain_lightning aoe 34"; end
  end
  -- lava_burst,moving=1,if=buff.lava_surge.up&cooldown_react
  if S.LavaBurst:IsReady() and Player:IsMoving() and (Player:BuffUp(S.LavaSurgeBuff)) then
    if Everyone.CastCycle(S.LavaBurst, Enemies40y, EvaluateCycleLavaBurstOnFlameShockTargets, not Target:IsSpellInRange(S.LavaBurst)) then return "lava_burst aoe 36"; end
  end
  -- flame_shock,moving=1,target_if=refreshable
  if S.FlameShock:IsReady() and Player:IsMoving() and Target:DebuffRefreshable(S.FlameShockDebuff) then
    if HR.Cast(S.FlameShock, nil, nil, not Target:IsSpellInRange(S.FlameShock)) then return "flame_shock aoe 38"; end
  end
  -- frost_shock,moving=1
  if S.FrostShock:IsReady() and Player:IsMoving() then
    if HR.Cast(S.FrostShock, nil, nil, not Target:IsSpellInRange(S.FrostShock)) then return "frost_shock aoe 40"; end
  end
end

local function SESingle()
  -- additional apl cause its not listed and the Storm Elemental does not automatically cast eye of the storm
  if SEActive and Pet:BuffUp(S.StormElementalPetBuff) and S.PEEyeOfTheStorm:CooldownRemains() <= 0 and Settings.Elemental.Commons.ShowSpeiclaElementalAblities then
    if HR.Cast(S.PEEyeOfTheStorm, Settings.Elemental.OffGCDasOffGCD.PEEyeOfTheStorm) then return "eye_of_the_storm ses 001"; end
  end

  -- flame_shock,target_if=(remains<=gcd)&(buff.lava_surge.up|!buff.bloodlust.up)
  if S.FlameShock:IsReady() then
    if Everyone.CastCycle(S.FlameShock, Enemies40y, EvaluateCycleFlameShock202, not Target:IsSpellInRange(S.FlameShock)) then return "flame_shock ses 62"; end
  end
  -- ascendance,if=talent.ascendance.enabled&(time>=60|buff.bloodlust.up)&(cooldown.lava_burst.remains>0)&(!talent.icefury.enabled|!buff.icefury.up&!cooldown.icefury.up)
  if S.Ascendance:IsCastable() and ((HL.CombatTime() >= 60 or Player:BloodlustUp()) and S.LavaBurst:CooldownRemains() > 0 and (not S.Icefury:IsAvailable() or Player:BuffDown(S.IcefuryBuff) and not S.Icefury:CooldownUp())) then
    if HR.Cast(S.Ascendance) then return "ascendance ses 64"; end
  end
  -- elemental_blast,if=talent.elemental_blast.enabled
  if S.ElementalBlast:IsReady() and not Player:IsCasting(S.ElementalBlast) and not S.ElementalBlast:InFlight() then
    if HR.Cast(S.ElementalBlast, nil, nil, not Target:IsSpellInRange(S.ElementalBlast)) then return "elemental_blast ses"; end
  end
  -- stormkeeper,if=talent.stormkeeper.enabled&(maelstrom<44)
  if S.Stormkeeper:IsCastable() and (Player:MaelstromP() < 44) then
    if HR.Cast(S.Stormkeeper, Settings.Elemental.GCDasOffGCD.Stormkeeper) then return "stormkeeper ses 66"; end
  end
  -- echoing_shock,if=talent.echoing_shock.enabled
  if S.EchoingShock:IsReady() and S.EchoingShock:IsAvailable() then
    if HR.Cast(S.EchoingShock, Settings.Elemental.GCDasOffGCD.EchoingShock, nil, not Target:IsSpellInRange(S.EchoingShock)) then return "echoing_shock ses 68"; end
  end
  -- lava_burst,if=buff.wind_gust.stack<18|buff.lava_surge.up
  if S.LavaBurst:IsReady() and S.LavaBurst:ChargesP() > 0 and (Player:BuffStack(S.WindGustBuff) < 18 or Player:BuffUp(S.LavaSurgeBuff)) then
    if Everyone.CastCycle(S.LavaBurst, Enemies40y, EvaluateCycleLavaBurstOnFlameShockTargets, not Target:IsSpellInRange(S.LavaBurst)) then return "lava_burst ses 70"; end
  end
  -- lightning_bolt,if=buff.stormkeeper.up
  if S.LightningBolt:IsReady() and (Player:BuffUp(S.StormkeeperBuff)) then
    if HR.Cast(S.LightningBolt, nil, nil, not Target:IsSpellInRange(S.LightningBolt)) then return "lightning_bolt ses 72"; end
  end
  -- earthquake,if=buff.echoes_of_great_sundering.up
  if S.Earthquake:IsReady() and Player:MaelstromP() >= 60 and (Player:BuffUp(S.EchoesofGreatSunderingBuff)) then
    if HR.Cast(S.Earthquake) then return "earthquake ses 74"; end
  end
  -- earthquake,if=(spell_targets.chain_lightning>1)&(!dot.flame_shock.refreshable)
  if S.Earthquake:IsReady() and Player:MaelstromP() >= 60 and (EnemiesCount10ySplash > 1 and not Target:DebuffRefreshable(S.FlameShockDebuff)) then
    if HR.Cast(S.Earthquake) then return "earthquake ses 76"; end
  end
  -- earth_shock,if=spell_targets.chain_lightning<2&maelstrom>=60&(buff.wind_gust.stack<20|maelstrom>90)
  if EnemiesCount10ySplash < 2 and Player:MaelstromP() >= 60 and (Player:BuffStack(S.WindGustBuff) < 20 or Player:MaelstromP() > 90) then
    if HR.Cast(S.EarthShock, nil, nil, not Target:IsSpellInRange(S.EarthShock)) then return "earth_shock ses 78"; end
  end
  -- lightning_bolt,if=(buff.stormkeeper.remains<1.1*gcd*buff.stormkeeper.stack|buff.stormkeeper.up&buff.master_of_the_elements.up)
  if S.LightningBolt:IsReady() and (Player:BuffRemains(S.StormkeeperBuff) < 1.1 * Player:GCD() * Player:BuffStack(S.StormkeeperBuff) or Player:BuffUp(S.StormkeeperBuff) and Player:BuffUp(S.MasterOfTheElementsBuff)) then
    if HR.Cast(S.LightningBolt, nil, nil, not Target:IsSpellInRange(S.LightningBolt)) then return "lightning_bolt ses 80"; end
  end
  -- frost_shock,if=talent.icefury.enabled&talent.master_of_the_elements.enabled&buff.icefury.up&buff.master_of_the_elements.up
  if S.FrostShock:IsReady() and (S.Icefury:IsAvailable() and S.MasterOfTheElements:IsAvailable() and Player:BuffUp(S.IcefuryBuff) and Player:BuffUp(S.MasterOfTheElementsBuff)) then
    if HR.Cast(S.FrostShock, nil, nil, not Target:IsSpellInRange(S.FrostShock)) then return "frost_shock ses 82"; end
  end
  -- lava_burst,if=buff.ascendance.up
  if S.LavaBurst:IsReady() and (Player:BuffUp(S.AscendanceBuff)) then
    if Everyone.CastCycle(S.LavaBurst, Enemies40y, EvaluateCycleLavaBurstOnFlameShockTargets, not Target:IsSpellInRange(S.LavaBurst)) then return "lava_burst ses 84"; end
  end
  -- lava_burst,if=cooldown_react&!talent.master_of_the_elements.enabled
  if S.LavaBurst:IsReady() and (not S.MasterOfTheElements:IsAvailable()) and S.LavaBurst:ChargesP() > 0 then
    if Everyone.CastCycle(S.LavaBurst, Enemies40y, EvaluateCycleLavaBurstOnFlameShockTargets, not Target:IsSpellInRange(S.LavaBurst)) then return "lava_burst ses 86"; end
  end
  -- icefury,if=talent.icefury.enabled&!(maelstrom>75&cooldown.lava_burst.remains<=0)
  if S.Icefury:IsReady() and not Player:IsCasting(S.IceFury) and (not (Player:MaelstromP() > 75 and S.LavaBurst:CooldownUp())) then
    if HR.Cast(S.Icefury, nil, nil, not Target:IsSpellInRange(S.Icefury)) then return "icefury ses 88"; end
  end
  -- lava_burst,if=cooldown_react&charges>talent.echo_of_the_elements.enabled
  if S.LavaBurst:IsReady() and (S.LavaBurst:ChargesP() > num(S.EchoOfTheElements:IsAvailable())) then
    if Everyone.CastCycle(S.LavaBurst, Enemies40y, EvaluateCycleLavaBurstOnFlameShockTargets, not Target:IsSpellInRange(S.LavaBurst)) then return "lava_burst ses 90"; end
  end
  -- frost_shock,if=talent.icefury.enabled&buff.icefury.up
  if S.FrostShock:IsReady() and (Player:BuffUp(S.IcefuryBuff)) then
    if HR.Cast(S.FrostShock, nil, nil, not Target:IsSpellInRange(S.FrostShock)) then return "frost_shock ses 92"; end
  end
  -- chain_harvest
  if S.ChainHarvest:IsReady() then
    if HR.Cast(S.ChainHarvest, nil, Settings.Commons.CovenantDisplayStyle, not Target:IsSpellInRange(S.ChainHarvest)) then return "chain_harvest ses 94"; end
  end
  -- static_discharge,if=talent.static_discharge.enabled
  if S.StaticDischarge:IsReady() then
    if HR.Cast(S.StaticDischarge, nil, nil, not Target:IsSpellInRange(S.StaticDischarge)) then return "static_discharge ses 96"; end
  end
  -- earth_elemental,if=!talent.primal_elementalist.enabled|talent.primal_elementalist.enabled&(!pet.storm_elemental.active)
  if S.EarthElemental:IsCastable() and (not S.PrimalElementalist:IsAvailable() or S.PrimalElementalist:IsAvailable() and (not SEActive)) then
    if HR.Cast(S.EarthElemental, Settings.Commons.GCDasOffGCD.EarthElemental) then return "earth_elemental ses 98"; end
  end
  -- lightning_bolt
  -- additional apl: dont show lightning_bolt if any other "better" spell is castable
  if S.LightningBolt:IsReady() and not (S.LavaBurst:ChargesP() > 0 or S.ElementalBlast:IsReady() or Player:MaelstromP() >= 60) then
    if HR.Cast(S.LightningBolt, nil, nil, not Target:IsSpellInRange(S.LightningBolt)) then return "lightning_bolt ses 100"; end
  end
  -- flame_shock,moving=1,target_if=refreshable
  -- flame_shock,moving=1,if=movement.distance>6
  if S.FlameShock:IsReady() and Player:IsMoving() and Target:DebuffRefreshable(S.FlameShockDebuff) then
    if HR.Cast(S.FlameShock, nil, nil, not Target:IsSpellInRange(S.FlameShock)) then return "flame_shock ses 102"; end
  end
  -- frost_shock,moving=1
  if S.FrostShock:IsReady() and Player:IsMoving() then
    if HR.Cast(S.FrostShock, nil, nil, not Target:IsSpellInRange(S.FrostShock)) then return "frost_shock ses 104"; end
  end
end

local function Single()
  -- additional apl cause its not listed and the Storm Elemental does not automatically cast meteor
  if FEActive and S.PEMeteor:CooldownRemains() <= 0 and Settings.Elemental.Commons.ShowSpeiclaElementalAblities then
    if HR.Cast(S.PEMeteor, Settings.Elemental.OffGCDasOffGCD.PEMeteor) then return "meteor single 001"; end
  end

  -- flame_shock,target_if=(!ticking|dot.flame_shock.remains<=gcd|talent.ascendance.enabled&dot.flame_shock.remains<(cooldown.ascendance.remains+buff.ascendance.duration)&cooldown.ascendance.remains<4)&(buff.lava_surge.up|!buff.bloodlust.up)
  if S.FlameShock:IsReady() then
    if Everyone.CastCycle(S.FlameShock, Enemies40y, EvaluateCycleFlameShock204, not Target:IsSpellInRange(S.FlameShock)) then return "flame_shock single 122"; end
  end
  -- ascendance,if=talent.ascendance.enabled&(time>=60|buff.bloodlust.up)&(cooldown.lava_burst.remains>0)&(!talent.icefury.enabled|!buff.icefury.up&!cooldown.icefury.up)
  if S.Ascendance:IsCastable() and ((HL.CombatTime() >= 60 or Player:BloodlustUp()) and S.LavaBurst:CooldownRemains() > 0 and (not S.Icefury:IsAvailable() or Player:BuffDown(S.IcefuryBuff) and not S.Icefury:CooldownUp())) then
    if HR.Cast(S.Ascendance) then return "ascendance single 124"; end
  end
  -- elemental_blast,if=talent.elemental_blast.enabled&(talent.master_of_the_elements.enabled&(buff.master_of_the_elements.up&maelstrom<60|!buff.master_of_the_elements.up)|!talent.master_of_the_elements.enabled)
  if S.ElementalBlast:IsReady() and not Player:IsCasting(S.ElementalBlast) and (S.MasterOfTheElements:IsAvailable() and (Player:BuffUp(S.MasterOfTheElementsBuff) and Player:MaelstromP() < 60 or Player:BuffDown(S.MasterOfTheElementsBuff)) or not S.MasterOfTheElements:IsAvailable()) then
    if HR.Cast(S.ElementalBlast, nil, nil, not Target:IsSpellInRange(S.ElementalBlast)) then return "elemental_blast single 126"; end
  end
  -- stormkeeper,if=talent.stormkeeper.enabled&(raid_event.adds.count<3|raid_event.adds.in>50)&(maelstrom<44)
  if S.Stormkeeper:IsCastable() and not Player:IsCasting(S.Stormkeeper) and (Player:MaelstromP() < 44) then
    if HR.Cast(S.Stormkeeper, Settings.Elemental.GCDasOffGCD.Stormkeeper) then return "stormkeeper single 128"; end
  end
  -- echoing_shock,if=talent.echoing_shock.enabled&cooldown.lava_burst.remains<=0
  if S.EchoingShock:IsReady() and S.EchoingShock:IsAvailable() and (S.LavaBurst:CooldownUp()) then
    if HR.Cast(S.EchoingShock, Settings.Elemental.GCDasOffGCD.EchoingShock, nil, not Target:IsSpellInRange(S.EchoingShock)) then return "echoing_shock single 130"; end
  end
  -- lava_burst,if=talent.echoing_shock.enabled&buff.echoing_shock.up
  if S.LavaBurst:IsReady() and (Player:BuffUp(S.EchoingShockBuff)) then
    if Everyone.CastCycle(S.LavaBurst, Enemies40y, EvaluateCycleLavaBurstOnFlameShockTargets, not Target:IsSpellInRange(S.LavaBurst)) then return "lava_burst single 132"; end
  end
  -- liquid_magma_totem,if=talent.liquid_magma_totem.enabled
  if S.LiquidMagmaTotem:IsReady() then
    if HR.Cast(S.LiquidMagmaTotem) then return "liquid_magma_totem single 134"; end
  end
  -- lightning_bolt,if=buff.stormkeeper.up&spell_targets.chain_lightning<2&(buff.master_of_the_elements.up)
  if S.LightningBolt:IsReady() and (Player:BuffUp(S.StormkeeperBuff) and EnemiesCount10ySplash < 2 and Player:BuffUp(S.MasterOfTheElementsBuff)) then
    if HR.Cast(S.LightningBolt, nil, nil, not Target:IsSpellInRange(S.LightningBolt)) then return "lightning_bolt single 136"; end
  end
  -- earthquake,if=buff.echoes_of_great_sundering.up&(!talent.master_of_the_elements.enabled|buff.master_of_the_elements.up)
  if S.Earthquake:IsReady() and Player:MaelstromP() >= 60 and (Player:BuffUp(S.EchoesofGreatSunderingBuff) and (not S.MasterOfTheElements:IsAvailable() or Player:BuffUp(S.MasterOfTheElementsBuff))) then
    if HR.Cast(S.Earthquake) then return "earthquake single 138"; end
  end
  -- earthquake,if=(spell_targets.chain_lightning>1)&(!dot.flame_shock.refreshable)&(!talent.master_of_the_elements.enabled|buff.master_of_the_elements.up|cooldown.lava_burst.remains>0&maelstrom>=92)
  if S.Earthquake:IsReady() and Player:MaelstromP() >= 60 and (EnemiesCount10ySplash > 1 and not Target:DebuffRefreshable(S.FlameShockDebuff) and (not S.MasterOfTheElements:IsAvailable() or Player:BuffUp(S.MasterOfTheElementsBuff) or S.LavaBurst:CooldownRemains() > 0 and Player:MaelstromP() >= 92)) then
    if HR.Cast(S.Earthquake) then return "earthquake single 140"; end
  end
  -- earth_shock,if=talent.master_of_the_elements.enabled&(buff.master_of_the_elements.up|cooldown.lava_burst.remains>0&maelstrom>=92|spell_targets.chain_lightning<2&buff.stormkeeper.up&cooldown.lava_burst.remains<=gcd)|!talent.master_of_the_elements.enabled
  if S.MasterOfTheElements:IsAvailable() and Player:MaelstromP() >= 60 and (Player:BuffUp(S.MasterOfTheElementsBuff) or S.LavaBurst:CooldownRemains() > 0 and Player:MaelstromP() >= 92 or EnemiesCount10ySplash < 2 and Player:BuffUp(S.StormkeeperBuff) and S.LavaBurst:CooldownRemains() <= Player:GCD()) or not S.MasterOfTheElements:IsAvailable() then
    if HR.Cast(S.EarthShock, nil, nil, not Target:IsSpellInRange(S.EarthShock)) then return "earth_shock single 142"; end
  end
  -- lightning_bolt,if=(buff.stormkeeper.remains<1.1*gcd*buff.stormkeeper.stack|buff.stormkeeper.up&buff.master_of_the_elements.up)
  if S.LightningBolt:IsReady() and (Player:BuffRemains(S.StormkeeperBuff) < 1.1 * Player:GCD() * Player:BuffStack(S.StormkeeperBuff) or Player:BuffUp(S.StormkeeperBuff) and Player:BuffUp(S.MasterOfTheElementsBuff)) then
    if HR.Cast(S.LightningBolt, nil, nil, not Target:IsSpellInRange(S.LightningBolt)) then return "lightning_bolt single 144"; end
  end
  -- frost_shock,if=talent.icefury.enabled&talent.master_of_the_elements.enabled&buff.icefury.up&buff.master_of_the_elements.up
  if S.FrostShock:IsReady() and (S.Icefury:IsAvailable() and S.MasterOfTheElements:IsAvailable() and Player:BuffUp(S.IcefuryBuff) and Player:BuffUp(S.MasterOfTheElementsBuff)) then
    if HR.Cast(S.FrostShock, nil, nil, not Target:IsSpellInRange(S.FrostShock)) then return "frost_shock single 146"; end
  end
  -- lava_burst,if=buff.ascendance.up
  if S.LavaBurst:IsReady() and (Player:BuffUp(S.AscendanceBuff)) then
    if Everyone.CastCycle(S.LavaBurst, Enemies40y, EvaluateCycleLavaBurstOnFlameShockTargets, not Target:IsSpellInRange(S.LavaBurst)) then return "lava_burst single 148"; end
  end
  -- lava_burst,if=cooldown_react&!talent.master_of_the_elements.enabled
  if S.LavaBurst:IsReady() and S.LavaBurst:ChargesP() > 0 and (not S.MasterOfTheElements:IsAvailable()) then
    if Everyone.CastCycle(S.LavaBurst, Enemies40y, EvaluateCycleLavaBurstOnFlameShockTargets, not Target:IsSpellInRange(S.LavaBurst)) then return "lava_burst single 150"; end
  end
  -- icefury,if=talent.icefury.enabled&!(maelstrom>75&cooldown.lava_burst.remains<=0)
  if S.Icefury:IsReady() and not Player:IsCasting(S.IceFury) and (not (Player:MaelstromP() > 75 and S.LavaBurst:CooldownUp())) then
    if HR.Cast(S.Icefury, nil, nil, not Target:IsSpellInRange(S.Icefury)) then return "icefury single 152"; end
  end
  -- lava_burst,if=cooldown_react&charges>talent.echo_of_the_elements.enabled
  if S.LavaBurst:IsReady() and (S.LavaBurst:ChargesP() > num(S.EchoOfTheElements:IsAvailable())) then
    if Everyone.CastCycle(S.LavaBurst, Enemies40y, EvaluateCycleLavaBurstOnFlameShockTargets, not Target:IsSpellInRange(S.LavaBurst)) then return "lava_burst single 154"; end
  end
  -- frost_shock,if=talent.icefury.enabled&buff.icefury.up&buff.icefury.remains<1.1*gcd*buff.icefury.stack
  if S.FrostShock:IsReady() and (S.Icefury:IsAvailable() and Player:BuffUp(S.IcefuryBuff) and Player:BuffRemains(S.IcefuryBuff) < 1.1 * Player:GCD() * Player:BuffStack(S.IcefuryBuff)) then
    if HR.Cast(S.FrostShock, nil, nil, not Target:IsSpellInRange(S.FrostShock)) then return "frost_shock single 156"; end
  end
  -- lava_burst,if=cooldown_react
  if S.LavaBurst:IsReady() and S.LavaBurst:ChargesP() > 0 then
    if Everyone.CastCycle(S.LavaBurst, Enemies40y, EvaluateCycleLavaBurstOnFlameShockTargets, not Target:IsSpellInRange(S.LavaBurst)) then return "lava_burst single 158"; end
  end
  -- flame_shock,target_if=refreshable
  if S.FlameShock:IsReady() then
    if Everyone.CastCycle(S.FlameShock, Enemies10ySplash, EvaluateCycleFlameShock, not Target:IsSpellInRange(S.FlameShock)) then return "flame_shock single 160"; end
  end
  -- earthquake,if=spell_targets.chain_lightning>1&!runeforge.echoes_of_great_sundering.equipped|(buff.echoes_of_great_sundering.up&buff.master_of_the_elements.up)
  if S.Earthquake:IsReady() and Player:MaelstromP() >= 60 and (EnemiesCount10ySplash > 1 and not EchoesofGreatSunderingEquipped or (Player:BuffUp(S.EchoesofGreatSunderingBuff) and Player:BuffUp(S.MasterOfTheElementsBuff))) then
    if HR.Cast(S.Earthquake) then return "earthquake single 162"; end
  end
  -- frost_shock,if=talent.icefury.enabled&buff.icefury.up&(buff.icefury.remains<gcd*4*buff.icefury.stack|buff.stormkeeper.up|!talent.master_of_the_elements.enabled)
  if S.FrostShock:IsReady() and (Player:BuffUp(S.IcefuryBuff) and (Player:BuffRemains(S.IcefuryBuff) < Player:GCD() * 4 * Player:BuffStack(S.IcefuryBuff) or Player:BuffUp(S.StormkeeperBuff) or not S.MasterOfTheElements:IsAvailable())) then
    if HR.Cast(S.FrostShock, nil, nil, not Target:IsSpellInRange(S.FrostShock)) then return "frost_shock single 164"; end
  end
  -- frost_shock,if=runeforge.elemental_equilibrium.equipped&!buff.elemental_equilibrium_debuff.up&!talent.elemental_blast.enabled&!talent.echoing_shock.enabled
  if S.FrostShock:IsReady() and (ElementalEquilibriumEquipped and Player:BuffDown(S.ElementalEquilibriumBuff) and not S.ElementalBlast:IsAvailable() and not S.EchoingShock:IsAvailable()) then
    if HR.Cast(S.FrostShock, nil, nil, not Target:IsSpellInRange(S.FrostShock)) then return "frost_shock single 166"; end
  end
  -- chain_harvest
  if S.ChainHarvest:IsReady() then
    if HR.Cast(S.ChainHarvest, nil, Settings.Commons.CovenantDisplayStyle, not Target:IsSpellInRange(S.ChainHarvest)) then return "chain_harvest single 168"; end
  end
  -- static_discharge,if=talent.static_discharge.enabled
  if S.StaticDischarge:IsReady() then
    if HR.Cast(S.StaticDischarge) then return "static_discharge single 170"; end
  end
  -- earth_elemental,if=!talent.primal_elementalist.enabled|!pet.fire_elemental.active
  if S.EarthElemental:IsCastable() and (not S.PrimalElementalist:IsAvailable() or not FEActive) then
    if HR.Cast(S.EarthElemental, Settings.Commons.GCDasOffGCD.EarthElemental) then return "earth_elemental single 172"; end
  end
  -- lightning_bolt
  -- additional apl: dont show lightning_bolt if any other "better" spell is castable
  if S.LightningBolt:IsReady() and not (S.LavaBurst:ChargesP() > 0 or S.ElementalBlast:IsReady() or Player:MaelstromP() >= 92) then
    if HR.Cast(S.LightningBolt, nil, nil, not Target:IsSpellInRange(S.LightningBolt)) then return "ightning_bolt single 174"; end
  end
  -- flame_shock,moving=1,target_if=refreshable
  -- flame_shock,moving=1,if=movement.distance>6
  if S.FlameShock:IsCastable() and Player:IsMoving() and Target:DebuffRefreshable(S.FlameShock) then
    if HR.Cast(S.FlameShock, nil, nil, not Target:IsSpellInRange(S.FlameShock)) then return "flame_shock single 176"; end
  end
  -- frost_shock,moving=1
  if S.FrostShock:IsCastable() and Player:IsMoving() then
    if HR.Cast(S.FrostShock, nil, nil, not Target:IsSpellInRange(S.FrostShock)) then return "frost_shock single 178"; end
  end
end

--- ======= MAIN =======
local function APL()
  -- Unit Update
  Enemies40y = Player:GetEnemiesInRange(40)
  Enemies10ySplash = Target:GetEnemiesInSplashRange(10)
  if AoEON() then
    EnemiesCount10ySplash = Target:GetEnemiesInSplashRangeCount(10)
    Enemies40yCount = #Enemies40y
    calcEnemiesFlameShockCount(S.FlameShock, Enemies40y)
  else
    EnemiesCount10ySplash = 1
    Enemies40yCount = 1
    EnemiesFlameShockCount = 1
  end

  SEActive = (S.StormElemental:IsAvailable() and S.StormElemental:CooldownRemains() > S.StormElemental:Cooldown() - 30)
  FEActive = (not S.StormElemental:IsAvailable() and S.FireElemental:CooldownRemains() > S.FireElemental:Cooldown() - 30)

  -- In Combat
  if Everyone.TargetIsValid() then
    -- Precombat
    if not Player:AffectingCombat() then
      local ShouldReturn = Precombat(); if ShouldReturn then return ShouldReturn; end
    end
    -- wind_shear
    local ShouldReturn = Everyone.Interrupt(30, S.WindShear, Settings.Commons.OffGCDasOffGCD.WindShear, false); if ShouldReturn then return ShouldReturn; end
    -- use_items
    local TrinketToUse = Player:GetUseableTrinkets(OnUseExcludes)
    if TrinketToUse then
      if HR.Cast(TrinketToUse, nil, Settings.Commons.TrinketDisplayStyle) then return "Generic use_items for " .. TrinketToUse:Name(); end
    end
    -- flame_shock,if=!ticking
    if S.FlameShock:IsCastable() and Target:DebuffDown(S.FlameShock) then
      if HR.Cast(S.FlameShock, nil, nil, not Target:IsSpellInRange(S.FlameShock)) then return "flame_shock main 202"; end
    end
    if CDsON() then
      -- fire_elemental
      if S.FireElemental:IsCastable() then
        if HR.Cast(S.FireElemental, Settings.Elemental.GCDasOffGCD.FireElemental) then return "fire_elemental main 204"; end
      end
      -- storm_elemental
      if S.StormElemental:IsCastable() then
        if HR.Cast(S.StormElemental, Settings.Elemental.GCDasOffGCD.StormElemental) then return "storm_elemental main 206"; end
      end
      -- blood_fury,if=!talent.ascendance.enabled|buff.ascendance.up|cooldown.ascendance.remains>50
      if S.BloodFury:IsCastable() and ( not S.Ascendance:IsAvailable() or Player:BuffUp(S.Ascendance) or S.Ascendance:CooldownRemains() > 50 ) then
        if HR.Cast(S.BloodFury, Settings.Commons.OffGCDasOffGCD.Racials) then return "blood_fury racial"; end
      end
      -- berserking,if=!talent.ascendance.enabled|buff.ascendance.up
      if S.BloodFury:IsCastable() and ( not S.Ascendance:IsAvailable() or Player:BuffUp(S.Ascendance) ) then
        if HR.Cast(S.Berserking, Settings.Commons.OffGCDasOffGCD.Racials) then return "berserking racial"; end
      end
      -- ancestral_call,if=!talent.ascendance.enabled|buff.ascendance.up|cooldown.ascendance.remains>50
      if S.AncestralCall:IsCastable() and ( not S.Ascendance:IsAvailable() or Player:BuffUp(S.Ascendance) or S.Ascendance:CooldownRemains() > 50 ) then
        if HR.Cast(S.AncestralCall, Settings.Commons.OffGCDasOffGCD.Racials) then return "ancestral_call racial"; end
      end
      -- fireblood,if=!talent.ascendance.enabled|buff.ascendance.up|cooldown.ascendance.remains>50
      if S.Fireblood:IsCastable() and ( not S.Ascendance:IsAvailable() or Player:BuffUp(S.Ascendance) or S.Ascendance:CooldownRemains() > 50 ) then
        if HR.Cast(S.Fireblood, Settings.Commons.OffGCDasOffGCD.Racials) then return "fireblood racial"; end
      end
      -- bag_of_tricks,if=!talent.ascendance.enabled|!buff.ascendance.up
      if S.BagofTricks:IsCastable() and ( not S.Ascendance:IsAvailable() or not Player:BuffUp(S.Ascendance) ) then
        if HR.Cast(S.BagofTricks, Settings.Commons.OffGCDasOffGCD.Racials, nil, not Target:SpellInRange(S.BagofTricks)) then return "bag_of_tricks racial"; end
      end
    end
    -- primordial_wave,target_if=min:dot.flame_shock.remains,cycle_targets=1,if=!buff.primordial_wave.up
    if S.PrimordialWave:IsReady() and (Player:BuffDown(S.PrimordialWaveBuff)) then
      if Everyone.CastCycle(S.PrimordialWave, Enemies40y, EvaluateCycleFlameShock, not Target:IsSpellInRange(S.PrimordialWave)) then return "primordial_wave main 208"; end
    end
    -- vesper_totem,if=covenant.kyrian
    if S.VesperTotem:IsReady() then
      if HR.Cast(S.VesperTotem, nil, Settings.Commons.CovenantDisplayStyle, not Target:IsInRange(40)) then return "vesper_totem main 210"; end
    end
    -- fae_transfusion,if=covenant.night_fae
    if S.FaeTransfusion:IsReady() then
      if HR.Cast(S.FaeTransfusion, nil, Settings.Commons.CovenantDisplayStyle, not Target:IsInRange(40)) then return "fae_transfusion main 212"; end
    end
    -- run_action_list,name=aoe,if=active_enemies>2&(spell_targets.chain_lightning>2|spell_targets.lava_beam>2)
    if EnemiesCount10ySplash > 2 and AoEON() then
      local ShouldReturn = Aoe(); if ShouldReturn then return ShouldReturn; end
    end
    -- run_action_list,name=single_target,if=!talent.storm_elemental.enabled&active_enemies<=2
    if not S.StormElemental:IsAvailable() and EnemiesCount10ySplash <= 2 then
      local ShouldReturn = Single(); if ShouldReturn then return ShouldReturn; end
    end
    -- run_action_list,name=se_single_target,if=talent.storm_elemental.enabled&active_enemies<=2
    if S.StormElemental:IsAvailable() and EnemiesCount10ySplash <= 2 then
      local ShouldReturn = SESingle(); if ShouldReturn then return ShouldReturn; end
    end
    -- If nothing else to do, show the Pool icon
    if HR.CastAnnotated(S.Pool, false, "WAIT") then return "Wait/Pool Resources"; end
  end
end

local function Init()

end

HR.SetAPL(262, APL, Init)
