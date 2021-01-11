-- ----- ============================ HEADER ============================
--- ======= LOCALIZE =======
-- Addon
local addonName, addonTable = ...;
-- HeroDBC
local DBC        = HeroDBC.DBC
-- HeroLib
local HL         = HeroLib
local Cache      = HeroCache
local Unit       = HL.Unit
local Player     = Unit.Player
local Target     = Unit.Target
local Pet        = Unit.Pet
local Spell      = HL.Spell
local MultiSpell = HL.MultiSpell
local Item       = HL.Item
-- HeroRotation
local HR         = HeroRotation
local AoEON      = HR.AoEON
local CDsON      = HR.CDsON
-- Lua
local mathmin    = math.min
local pairs      = pairs;


--- ============================ CONTENT ============================
--- ======= APL LOCALS =======
-- luacheck: max_line_length 9999

-- Define S/I for spell and item arrays
local S = Spell.Monk.Windwalker;
local I = Item.Monk.Windwalker;

-- Create table to exclude above trinkets from On Use function
local OnUseExcludes = {
--  I.GalecallersBoon:ID(),
}

-- Rotation Var
local IsInMeleeRange
local IsInAoERange
local Enemies5y
local Enemies8y
local EnemiesCount8
local ShouldReturn
local Interrupts = {
  { S.SpearHandStrike, "Cast Spear Hand Strike (Interrupt)", function () return true end },
}
local Stuns = {
  { S.LegSweep, "Cast Leg Sweep (Stun)", function () return true end },
}
local KnockBack = {
  { S.RingOfPeace, "Cast Ring Of Peace (Stun)", function () return true end },
}
local Traps = {
  { S.Paralysis, "Cast Paralysis (Stun)", function () return true end },
}

-- GUI Settings
local Everyone = HR.Commons.Everyone;
local Monk = HR.Commons.Monk;
local Settings = {
  General    = HR.GUISettings.General,
  Commons    = HR.GUISettings.APL.Monk.Commons,
  Windwalker = HR.GUISettings.APL.Monk.Windwalker
};

-- Legendary variables
local CelestialInfusionEquipped = Player:HasLegendaryEquipped(88)
local EscapeFromRealityEquipped = Player:HasLegendaryEquipped(82)
local FatalTouchEquipped = Player:HasLegendaryEquipped(85)
local InvokersDelightEquipped = Player:HasLegendaryEquipped(83)
local JadeIgnitionEquipped = Player:HasLegendaryEquipped(96)
local KeefersSkyreachEquipped = Player:HasLegendaryEquipped(95)
local LastEmperorsCapacitorEquipped = Player:HasLegendaryEquipped(97)
local XuensTreasureEquipped = Player:HasLegendaryEquipped(94)

HL:RegisterForEvent(function()
  VarFoPPreChan = 0
end, "PLAYER_REGEN_ENABLED")

-- Melee Is In Range w/ Movement Handlers
local function IsInMeleeRange(range)
  if S.TigerPalm:TimeSinceLastCast() <= Player:GCD() then
    return true
  end
  return range and Target:IsInMeleeRange(range) or Target:IsInMeleeRange(5)
end

local EnemyRanges = {5, 8, 10, 30, 40, 100}
local TargetIsInRange = {}
local function ComputeTargetRange()
  for _, i in ipairs(EnemyRanges) do
    if i == 8 or 5 then TargetIsInRange[i] = Target:IsInMeleeRange(i) end
    TargetIsInRange[i] = Target:IsInRange(i)
  end
end

local function num(val)
  if val then return 1 else return 0 end
end

local function bool(val)
  return val ~= 0
end

local function EnergyTimeToMaxRounded()
  -- Round to the nearesth 10th to reduce prediction instability on very high regen rates
  return math.floor(Player:EnergyTimeToMaxPredicted() * 10 + 0.5) / 10
end

local function EnergyPredictedRounded()
  -- Round to the nearesth int to reduce prediction instability on very high regen rates
  return math.floor(Player:EnergyPredicted() + 0.5)
end

local function ComboStrike(SpellObject)
  return (not Player:PrevGCD(1, SpellObject))
end

-- Cast the given spell, but if it's a crane-stack applying spell, 
-- choose the nearby target with the minimum remaining timer on it's crane stacks.
local function OptimallyTargetedCast(SpellObject, DebugMessage)
  -- Spell is NIL, error.
  if SpellObject == nil then
    return "Spell object passed in was nil!"
  -- Spell applices MOTC
  elseif (SpellObject == S.TigerPalm or SpellObject == S.RisingSunKick or SpellObject == S.FistOfTheWhiteTiger or SpellObject == S.BlackoutKick) then
    local BestUnit = Target
    local min_time = Target:DebuffRemains(S.MarkOfTheCraneDebuff)
    for _, Unit in pairs(Enemies5y) do
      local unit_time = Unit:DebuffRemains(S.MarkOfTheCraneDebuff)
      if unit_time < min_time then
        BestUnit = Unit
        min_time = unit_time
      end
    end
    if BestUnit and BestUnit:GUID() == Target:GUID()  then
      HR.Cast(SpellObject, nil, nil, not Target:IsInMeleeRange(8)) 
    else
      HR.CastLeftNameplate(BestUnit, SpellObject)
    end
  else
  -- Spell does not apply MOTC, just regular cast it.
    HR.Cast(SpellObject, nil, nil, not Target:IsInMeleeRange(8)) 
  end
  return DebugMessage
end

-- This function returns a table, indexed by spell object (S.XXX) keys.
-- It contains the current-state chi costs of each chi spender (perhaps zero).
-- Assumption here is that we always want to fists on CD, so we don't bother tracking it here.
local function ChiSpenderCosts()
  costs = {}
  costs[S.RisingSunKick] = 2
  costs[S.SpinningCraneKick] = 2
  costs[S.RushingJadeWind] = 1
  costs[S.BlackoutKick] = 1
  if Player:BuffUp(S.WeaponsOfOrder) then
    for spell, cost in pairs(costs) do
      costs[spell] = max(0, cost-1)
    end
  end
  if Player:BuffUp(S.DanceOfChijiBuff) then
    costs[S.SpinningCraneKick] = 0
  end
  if Player:BuffUp(S.BlackoutKickBuff) then
    costs[S.BlackoutKick] = 0
  end
  if Player:BuffUp(S.SerenityBuff) then
    for spell, cost in pairs(costs) do
      costs[spell] = 0
    end
  end
  return costs
end

local function MarkOfTheCraneStacks()
  return GetSpellCount(101546)
end

local function AbilityPower()
  local mh = GetInventoryItemLink("player", 16)
  local mh_dps = GetItemStats(mh)["ITEM_MOD_DAMAGE_PER_SECOND_SHORT"]
  local oh = GetInventoryItemLink("player", 17)
  if oh ~= nil then
    local oh_dps = GetItemStats(oh)["ITEM_MOD_DAMAGE_PER_SECOND_SHORT"]
    return 1.02 * (4*mh_dps + 2*oh_dps + Player:AttackPower())
  else
    return 0.98 * (6*mh_dps + Player:AttackPower())
  end
end

-- This function returns a table, indexed by spell object (S.XXX) keys.
-- It returns a table of values of using the given chi spender in the current state.
-- See https://docs.google.com/spreadsheets/d/1Agwilw8sG5PeBBgACneZl3J4jumS1EBWQAJK8BIUzgE/edit#gid=0
-- TODO: autoattack loss on SCK (low importance)
-- TODO: BOK value from CDR (high importance)
local function ChiSpenderValues()
  -- Set up some variables/constants here.
  -- Base multipliers
  local ability_power = AbilityPower()
  local mastery_coeff = 1 + Player:MasteryPct() / 100.0
  local vers_coeff = 1 + Player:VersatilityDmgPct() / 100.0
  local armor_reduction_coeff = 0.70
  local mystic_touch_coeff = 1.05

  values = {}
  -- RSK
  local rsk_ap_coeff = 1.438
  local rsk_aura_coeff = 0.87 * 1.26 * 1.7
  local rsk_tooltip = ability_power * rsk_ap_coeff * rsk_aura_coeff * vers_coeff
  local rsk_damage = rsk_tooltip * mastery_coeff * armor_reduction_coeff * mystic_touch_coeff
  values[S.RisingSunKick] = rsk_damage
  -- SCK
  local sck_ap_coeff = 0.40
  local sck_aura_coeff = 0.87 * 2.4
  local calculated_strikes_effect = 0.0
  if S.CalculatedStrikes:ConduitEnabled() then calculated_strikes_effect = 0.1 + 0.01*(S.CalculatedStrikes:ConduitRank() - 1) end
  local crane_coeff = 1 + (0.1 + calculated_strikes_effect) * MarkOfTheCraneStacks()
  local chiji_coeff = 1.0
  if Player:BuffUp(S.DanceOfChijiBuff) then chiji_coeff = 3.0 end
  local sck_tooltip = ability_power * sck_ap_coeff * sck_aura_coeff * vers_coeff * crane_coeff * chiji_coeff
  local sck_damage = sck_tooltip * mastery_coeff * armor_reduction_coeff * mystic_touch_coeff
  local num_targets = min(6, EnemiesCount8)
  values[S.SpinningCraneKick] = sck_damage * num_targets
  -- RJW
  local rjw_ap_coeff = 0.90
  local rjw_aura_coeff = 0.87 * 1.22
  local rjw_tooltip = ability_power * rjw_ap_coeff * rjw_aura_coeff * vers_coeff
  local rjw_damage = rjw_tooltip * mastery_coeff * armor_reduction_coeff * mystic_touch_coeff
  local num_targets = min(6, EnemiesCount8)
  values[S.RushingJadeWind] = num_targets * rjw_damage
  -- BOK
  local bok_ap_coeff = 0.847
  local bok_aura_coeff = 0.87 * 1.26 * 1.1
  local bok_tooltip = ability_power * bok_ap_coeff * bok_aura_coeff * vers_coeff
  local bok_damage = bok_tooltip * mastery_coeff * armor_reduction_coeff * mystic_touch_coeff
  values[S.BlackoutKick] = bok_damage

  return values
end

-- Can return nil
local function UseItems()
  -- use_items
  local TrinketToUse = Player:GetUseableTrinkets(OnUseExcludes)
  if TrinketToUse then
    if HR.Cast(TrinketToUse, nil, Settings.Commons.TrinketDisplayStyle) then return "Generic use_items for " .. TrinketToUse:Name(); end
  end
end

-- Can return nil
local function UseCooldowns()
  -- notable TODO: consider putting energizing elixir into main rotation
  -- elixir is off gcd, as is serenity/SEF, but elixir is less of a CD and more of a rotational thing
  if S.InvokeXuenTheWhiteTiger:IsReady() then
    if HR.Cast(S.InvokeXuenTheWhiteTiger, Settings.Windwalker.GCDasOffGCD.InvokeXuenTheWhiteTiger, nil, not Target:IsInRange(40)) then return "Invoke Xuen the White Tiger"; end
  end
  if S.StormEarthAndFire:IsReady() and (S.StormEarthAndFire:Charges() == 2 or HL.BossFilteredFightRemains("<", 20) or ((not S.WeaponsOfOrder:IsAvailable()) and ((S.InvokeXuenTheWhiteTiger:CooldownRemains() > S.StormEarthAndFire:FullRechargeTime())) and (S.FistsOfFury:CooldownRemains() <= 9) and Player:Chi() >= 2 and S.WhirlingDragonPunch:CooldownRemains() <= 12)) then
    if HR.CastSuggested(S.StormEarthAndFire) then return "Storm Earth and Fire non-kyrian"; end
  end
  if S.StormEarthAndFire:IsReady() and S.WeaponsOfOrder:IsAvailable() and (Player:BuffUp(S.WeaponsOfOrder) or ((HL.BossFilteredFightRemains("<", S.WeaponsOfOrder:CooldownRemains()) or (S.WeaponsOfOrder:CooldownRemains() > S.StormEarthAndFire:FullRechargeTime())) and S.FistsOfFury:CooldownRemains() <= 9 and Player:Chi() >= 2 and S.WhirlingDragonPunch:CooldownRemains() <= 12)) then
    if HR.CastSuggested(S.StormEarthAndFire) then return "Storm Earth and Fire kyrian"; end
  end

  if S.EnergizingElixir:IsReady() and ((Player:ChiDeficit() >= 2 and EnergyTimeToMaxRounded() > 2) or Player:ChiDeficit() >= 4) then
    if HR.CastRightSuggested(S.EnergizingElixir) then return "Elixir CD"; end
  end
  if S.TouchOfDeath:IsReady() and Target:Health() < UnitHealthMax("player") then
    if HR.CastRightSuggested(S.TouchOfDeath) then return "Touch of Death Main Target"; end
  end
  if S.WeaponsOfOrder:IsReady() then
    if HR.Cast(S.WeaponsOfOrder, true, nil, not Target:IsInRange(40)) then return "Weapons of Order" end
  end
end

-- Can return nil
local function Precombat()
  if S.ChiBurst:IsReady() then
    if HR.Cast(S.ChiBurst, nil, nil, not Target:IsInRange(40)) then return "Precombat Chi Burst"; end
  end
end

-- Returns true if any chi-generating energy-spender would push you to the chi cap or beyond.
local function ChiCapped()
  return Player:ChiDeficit() <= 1 or (Player:ChiDeficit() <= 3 and S.FistOfTheWhiteTiger:IsReady())
end

-- Return true if you'll be energy capped before the GCD is up, or if you'll be energy capped during your FOF channel given that it's your next spell.
local function EnergyCapped(chi_costs)
  local FOFChannelTime = 4.0 / (1 + Player:HastePct() / 100.0)
  return (EnergyTimeToMaxRounded() < Player:GCD()) or 
         (EnergyTimeToMaxRounded() < Player:GCD() + FOFChannelTime and S.FistsOfFury:CooldownRemains() < Player:GCD() and Player:Chi() >= 3)
end

-- This function can return nil if force_spend is not true.
-- If it returns nil, that means you'd actually rather not spend chi, because the best chi spender you want to use in this situation wouldn't be a combo strike.
local function SpendChi(force_spend, chi_costs, chi_values)
  -- Fists of Fury, if it's ready.
  if S.FistsOfFury:IsReady() then
    return OptimallyTargetedCast(S.FistsOfFury, "Fists of Fury")
  end

  -- Use the best free spell that's ready and a combo strike.
  -- TODO: decide where to actually prioritize free casts of chi spenders. First experiment is with then below FOF priority.
  -- local best_free_spell = nil
  -- local best_free_spell_value = 0
  -- for spell, cost in pairs(chi_costs) do
  --   if cost == 0 then
  --     local value = chi_values[spell]
  --     if value > best_free_spell_value and spell:IsReady() and ComboStrike(spell) then
  --       best_free_spell = spell
  --       best_free_spell_value = value
  --     end
  --   end
  -- end
  -- if best_free_spell ~= nil then
  --   return OptimallyTargetedCast(best_free_spell, "Free cast of " .. best_free_spell.SpellName)
  -- end

  -- Use the situationally best chi spender if it's ready!
  local rsk_efficiency = chi_values[S.RisingSunKick] / (chi_costs[S.RisingSunKick] + 2)
  local rjw_efficiency = chi_values[S.RushingJadeWind] / (chi_costs[S.RushingJadeWind] + 2)
  local bok_efficiency = chi_values[S.BlackoutKick] / (chi_costs[S.BlackoutKick] + 2)
  local sck_efficiency = chi_values[S.SpinningCraneKick] / (chi_costs[S.SpinningCraneKick] + 2)
  if rsk_efficiency > max(rjw_efficiency, bok_efficiency, sck_efficiency) then
    if S.RisingSunKick:IsReady() and ComboStrike(S.RisingSunKick) then
      return OptimallyTargetedCast(S.RisingSunKick, "RSK is best possible chi spender and it's ready.")
    end
  end
  if rjw_efficiency > max(rsk_efficiency, bok_efficiency, sck_efficiency) then
    if S.RushingJadeWind:IsReady() and ComboStrike(S.RushingJadeWind) then
      return OptimallyTargetedCast(S.RushingJadeWind, "RJW is best possible chi spender and it's ready.")
    end
  end
  if bok_efficiency > max(rsk_efficiency, rjw_efficiency, sck_efficiency) then
    if S.BlackoutKick:IsReady() and ComboStrike(S.BlackoutKick) then
      return OptimallyTargetedCast(S.BlackoutKick, "BOK is best possible chi spender and it's ready.")
    end
  end
  if sck_efficiency > max(rsk_efficiency, rjw_efficiency, bok_efficiency) then
    if S.SpinningCraneKick:IsReady() and ComboStrike(S.SpinningCraneKick) then
      return OptimallyTargetedCast(S.SpinningCraneKick, "SCK is best possible chi spender and it's ready.")
    end
  end

  -- If we're being forced to spend since we're at the chi cap, pick the most efficient spell that's available.
  if force_spend then
    local efficiencies = {}
    efficiencies[S.RisingSunKick] = rsk_efficiency
    efficiencies[S.RushingJadeWind] = rjw_efficiency
    efficiencies[S.BlackoutKick] = bok_efficiency
    efficiencies[S.SpinningCraneKick] = sck_efficiency
    local best_available_spell = nil
    local best_available_efficiency = 0
    for spell, efficiency in pairs(efficiencies) do
      if efficiency > best_available_efficiency and spell:IsReady() and ComboStrike(spell) then
        best_available_spell = spell
        best_available_efficiency = efficiency
      end
    end
    return OptimallyTargetedCast(best_available_spell, "Forced to spend chi, " .. best_available_spell.SpellName .. " has the best efficiency right now.")
  end

  -- Otherwise, try not to spend chi on the non-situationally-best chi spender - don't just burn Chi on BOK in aoe if you've cast SCK, try to tiger's palm first or something
  return nil
end


-- This function is called when you are about to cap energy in the next GCD, or the next spell you cast will cap your energy during it (consider FOF + Chi Burst here)
-- It is POSSIBLE that this function returns nil, even if force_spend is true: this happens when you're basically energy capped *and* Tiger Palm was the last spell you cast.
-- If this is the cast, we just try to Flying Serpent Kick ourselves to victory.
local function SpendEnergy(force_spend)
  if S.FistOfTheWhiteTiger:IsReady() and Player:ChiDeficit() >= 3 then
    return OptimallyTargetedCast(S.FistOfTheWhiteTiger, "FOTWT @ Energy Cap")
  end
  if S.ExpelHarm:IsReady() and Player:ChiDeficit() >= 1 then
    return OptimallyTargetedCast(S.ExpelHarm, "Expel Harm @ Energy Cap")
  end
  -- NOTE: this is a chi deficit of ONE here if force_spend, because if you're about to cap energy then it's better to get the 1 chi and cap anyways.
  if ComboStrike(S.TigerPalm) and Player:ChiDeficit() >= 2 - num(force_spend) then
    return OptimallyTargetedCast(S.TigerPalm, "Tiger Palm @ Energy Cap")
  end
  return nil
end

-- Can return nil.
local function SpecialCases()
  -- Handle WDP + WDP setup as a highest priority
  if S.WhirlingDragonPunch:IsReady() and Player:BuffUp(S.WhirlingDragonPunchBuff) then
    return OptimallyTargetedCast(S.WhirlingDragonPunch, "Whirling Dragon Punch")
  end
  -- Fire off RSK to enable WDP
  if S.WhirlingDragonPunch:IsAvailable() and S.RisingSunKick:IsReady() and S.WhirlingDragonPunch:CooldownRemains() < 3 and (S.FistsOfFury:CooldownRemains() > 3 or Player:Chi() >= 5) then
    return OptimallyTargetedCast(S.RisingSunKick, "RSK to Enable WDP")
  end
  -- Faeline stomp on CD
  if S.FaelineStomp:IsReady() then
    return OptimallyTargetedCast(S.FaelineStomp, "Faeline Stomp")
  end
  -- Get the chi-reduction ASAP in Weapons of Order buff.
  if Player:BuffUp(S.WeaponsOfOrder) and S.RisingSunKick:IsReady() and ComboStrike(S.RisingSunKick) then
    return OptimallyTargetedCast(S.RisingSunKick, "RSK during Weapons of Order")
  end
end

local function ShortCDs()
  local ChiBurstCastTime = 1.0 / (1 + Player:HastePct() / 100.0)
  if S.ChiBurst:IsReady() and Player:ChiDeficit() >= 1 and EnergyTimeToMaxRounded() > ChiBurstCastTime + 0.200 then
    return OptimallyTargetedCast(S.ChiBurst, "ChiBurst")
  end
  if S.ChiWave:IsReady() then
    return OptimallyTargetedCast(S.ChiWave, "ChiWave")
  end
end

-- Action Lists --
--- ======= MAIN =======
-- APL Main
local function APL()
  Enemies5y = Player:GetEnemiesInMeleeRange(5) -- Multiple Abilities
  Enemies8y = Player:GetEnemiesInMeleeRange(8) -- Multiple Abilities
  EnemiesCount8 = #Enemies8y -- AOE Toogle
  ComputeTargetRange()
  local DebugMessage;


  if Everyone.TargetIsValid() then
    if not Player:AffectingCombat() then
      DebugMessage = Precombat(); if DebugMessage then return DebugMessage; end
    end
    DebugMessage = Everyone.Interrupt(5, S.SpearHandStrike, Settings.Commons.OffGCDasOffGCD.SpearHandStrike, Interrupts); if DebugMessage then return DebugMessage; end

    local chi_costs = ChiSpenderCosts()
    local chi_values = ChiSpenderValues()

    UseCooldowns()
    UseItems()
    
    DebugMessage = SpecialCases()
    if DebugMessage then return DebugMessage end

    if ChiCapped() then
      DebugMessage = SpendChi(true, chi_costs, chi_values)
      if DebugMessage then return DebugMessage end
    end

    if EnergyCapped(chi_costs) then
      DebugMessage = SpendEnergy(true)
      if DebugMessage then return DebugMessage end
    end

    DebugMessage = SpendChi(false, chi_costs, chi_values)
    if DebugMessage then return DebugMessage end

    DebugMessage = ShortCDs()
    if DebugMessage then return DebugMessage end

    DebugMessage = SpendEnergy(false)
    if DebugMessage then return DebugMessage end

    -- No buttons left to press; try Flying Serpent Kick
    if S.FlyingSerpentKick:IsReady() then
      if HR.Cast(S.FlyingSerpentKick) then return "Flying Serpent Kick for Mastery" end
    end

    -- Manually added Pool filler
    if HR.Cast(S.PoolEnergy) then return "Pool Energy" end
  end
end

local function Init()
--  HL.RegisterNucleusAbility(113656, 8, 6)               -- Fists of Fury
--  HL.RegisterNucleusAbility(101546, 8, 6)               -- Spinning Crane Kick
--  HL.RegisterNucleusAbility(261715, 8, 6)               -- Rushing Jade Wind
--  HL.RegisterNucleusAbility(152175, 8, 6)               -- Whirling Dragon Punch
end

HR.SetAPL(269, APL, Init);