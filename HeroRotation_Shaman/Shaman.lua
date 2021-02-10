--- ============================ HEADER ============================
--- ======= LOCALIZE =======
-- Addon
local addonName, addonTable = ...
-- HeroLib
local HL = HeroLib
local Cache = HeroCache
local Unit = HL.Unit
local Player = Unit.Player
local Target = Unit.Target
local MouseOver = Unit.MouseOver
local Spell = HL.Spell
local Item = HL.Item
-- HeroRotation
local HR = HeroRotation
local Settings = HR.GUISettings.APL.Shaman.Commons
local Everyone = HR.Commons.Everyone
-- Lua
-- File Locals
local Commons = {}

--- ======= GLOBALIZE =======
HR.Commons.Class = Commons


--- ============================ CONTENT ============================


-- Spells
if not Spell.Shaman then Spell.Shaman = {} end
Spell.Shaman.Enhancement = {
  -- General Abilities

  -- Abilities Shaman
  Bloodlust                             = Spell(2825),
  ChainLightning                        = Spell(188443),
  EarthElemental                        = Spell(198103),
  FlameShock                            = Spell(188389),
  FlameShockDebuff                      = Spell(188389),
  FlamentongueWeapon                    = Spell(318038),
  FrostShock                            = Spell(196840),
  LightningBolt                         = Spell(188196),
  LightningShield                       = Spell(192106),
  WindShear                             = Spell(57994),

  -- Defensive
  AstralShift                           = Spell(10871),

  -- Utility
  CapacitorTotem                        = Spell(192058),

  -- Racials
  BloodFury                             = Spell(33697),
  Berserking                            = Spell(26297),
  Fireblood                             = Spell(265221),
  AncestralCall                         = Spell(274738),
  BagofTricks                           = Spell(312411),

  -- Abilities
  Bloodlust                             = Spell(2825),
  ChainLightning                        = Spell(188443),
  EarthElemental                        = Spell(198103),
  FlamentongueWeapon                    = Spell(318038),
  FrostShock                            = Spell(196840),
  LightningBolt                         = Spell(188196),
  LightningShield                       = Spell(192106),
  LightningShieldBuff                   = Spell(192106),

  -- Defensive
  AstralShift                           = Spell(10871),

  -- Utility
  CapacitorTotem                        = Spell(192058),


  CrashLightning                        = Spell(187874),
  FeralSpirit                           = Spell(51533),
  LavaLash                              = Spell(60103),
  Stormstrike                           = Spell(17364),
  Windstrike                            = Spell(115356),
  WindfuryTotem                         = Spell(8512),
  WindfuryTotemBuff                     = Spell(327942),
  WindfuryWeapon                        = Spell(33757),
  MaelstromWeaponBuff                   = Spell(344179),
  CrashLightningBuff                    = Spell(187878),

  -- Talents
  Ascendance                            = Spell(114051),
  AscendanceBuff                        = Spell(114051),
  Sundering                             = Spell(197214),
  Hailstorm                             = Spell(334195),
  HailstormBuff                         = Spell(334196),
  Stormkeeper                           = Spell(320137),
  StormkeeperBuff                       = Spell(320137),
  EarthenSpike                          = Spell(188089),
  FireNova                              = Spell(333974),
  LashingFlames                         = Spell(334046),
  LashingFlamesDebuff                   = Spell(334168),
  ElementalBlast                        = Spell(117014),
  Stormflurry                           = Spell(344357),
  HotHand                               = Spell(201900),
  HotHandBuff                           = Spell(215785),
  IceStrike                             = Spell(342240),
  CrashingStorm                         = Spell(192246),
  ElementalSpirits                      = Spell(262624),
  ForcefulWinds                         = Spell(262647),
  -- Artifact

  -- Defensive

  -- Covenant Abilities
  ChainHarvest                          = Spell(320674),
  FaeTransfusion                        = Spell(328923),
  PrimordialWave                        = Spell(326059),
  PrimordialWaveBuff                    = Spell(327164),
  VesperTotem                           = Spell(324386),

  -- Legendaries
  DoomWindsBuff                         = Spell(335903),
  DoomWindsDebuff                       = Spell(335904),
  PrimalLavaActuatorsBuff               = Spell(335896),

  -- Misc
  Pool                                  = Spell(999910),

  -- Macros

}

Spell.Shaman.Elemental = {
  -- General Abilities

  -- Abilities Shaman
  Bloodlust                             = Spell(2825),
  ChainLightning                        = Spell(188443),
  EarthElemental                        = Spell(198103),
  FlameShock                            = Spell(188389),
  FlameShockDebuff                      = Spell(188389),
  FlamentongueWeapon                    = Spell(318038),
  FrostShock                            = Spell(196840),
  LightningBolt                         = Spell(188196),
  LightningShield                       = Spell(192106),
  WindShear                             = Spell(57994),

  -- Defensive
  AstralShift                           = Spell(10871),

  -- Utility
  CapacitorTotem                        = Spell(192058),

  -- Racials
  BloodFury                             = Spell(33697),
  Berserking                            = Spell(26297),
  Fireblood                             = Spell(265221),
  AncestralCall                         = Spell(274738),
  BagofTricks                           = Spell(312411),

  -- Abilities
  EarthShock                            = Spell(8042),
  Earthquake                            = Spell(61882),
  FireElemental                         = Spell(198067),
  LavaBurst                             = Spell(51505),
  LavaSurgeBuff                         = Spell(77762),

  -- Talents
  EarthenRage                           = Spell(170374),
  EchoOfTheElements                     = Spell(333919),
  StaticDischarge                       = Spell(342243),

  Aftershock                            = Spell(273221),
  EchoingShock                          = Spell(320125),
  EchoingShockBuff                      = Spell(320125),
  ElementalBlast                        = Spell(117014),

  MasterOfTheElements                   = Spell(16166),
  MasterOfTheElementsBuff               = Spell(260734),
  StormElemental                        = Spell(192249),
  StormElementalPetBuff                 = Spell(157348),
  WindGustBuff                          = Spell(263806),
  LiquidMagmaTotem                      = Spell(192222),

  SurgeOfPower                          = Spell(262303),
  PrimalElementalist                    = Spell(117013),
  PEMeteor                              = Spell(117588),
  PEEyeOfTheStorm                       = Spell(157375),
  Icefury                               = Spell(210714),
  IcefuryBuff                           = Spell(210714),

  UnlimitedPower                        = Spell(260895),
  Stormkeeper                           = Spell(191634),
  StormkeeperBuff                       = Spell(191634),
  Ascendance                            = Spell(114050),
  AscendanceBuff                        = Spell(114050),
  LavaBeam                              = Spell(114074),

  -- Defensive

  -- Covenant Abilities
  ChainHarvest                          = Spell(320674),
  FaeTransfusion                        = Spell(328923),
  PrimordialWave                        = Spell(326059),
  PrimordialWaveBuff                    = Spell(327164),
  VesperTotem                           = Spell(324386),

  -- Legendaries
  EchoesofGreatSunderingBuff            = Spell(336217),
  ElementalEquilibriumBuff              = Spell(347348),

  -- Misc
  Pool                                  = Spell(999910),

  -- Macros

}

if not Item.Shaman then Item.Shaman = {} end
Item.Shaman.Enhancement = {
}

Item.Shaman.Elemental = {
}
