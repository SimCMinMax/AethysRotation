--- ============================ HEADER ============================
-- HeroLib
local HL      = HeroLib
local Cache   = HeroCache
local Unit    = HL.Unit
local Player  = Unit.Player
local Pet     = Unit.Pet
local Target  = Unit.Target
local Spell   = HL.Spell
local Item    = HL.Item
-- HeroRotation
local HR      = HeroRotation
-- Spells
local SpellElemental   = Spell.Shaman.Elemental
-- Lua

--- ============================ CONTENT ============================
-- Elemental, ID: 262
HL.AddCoreOverride ("Spell.ChargesP",
  function ()
    local FutureLavaBurstCharges = SpellElemental.LavaBurst:Charges()
    if not Player:IsCasting() then
      return FutureLavaBurstCharges
    else
      if Player:IsCasting(SpellElemental.LavaBurst)  then
        return FutureLavaBurstCharges - 1
      else
        return FutureLavaBurstCharges
      end
    end
  end
  , 262)

HL.AddCoreOverride ("Player.MaelstromP",
  function ()
    local PlayerMaelstrom = Player:Maelstrom()
    if not Player:IsCasting() then
      return PlayerMaelstrom
    else
      if Player:IsCasting(SpellElemental.LavaBurst)  then
        return PlayerMaelstrom + 10
      elseif Player:IsCasting(SpellElemental.LightningBolt) then
        return PlayerMaelstrom + 8
      elseif Player:IsCasting(SpellElemental.ElementalBlast) then
        return PlayerMaelstrom + 30
      elseif Player:IsCasting(SpellElemental.ChainLightning) then
        return PlayerMaelstrom + (Target:GetEnemiesInSplashRangeCount(10) * 4)
      else
        return PlayerMaelstrom
      end
    end
  end
  , 262)
