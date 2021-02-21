--- ============================ HEADER ============================
--- ======= LOCALIZE =======
-- Addon
local addonName, addonTable = ...
-- HeroRotation
local HR = HeroRotation
-- HeroLib
local HL = HeroLib
-- File Locals
local GUI = HL.GUI
local CreateChildPanel = GUI.CreateChildPanel
local CreatePanelOption = GUI.CreatePanelOption
local CreateARPanelOption = HR.GUI.CreateARPanelOption
local CreateARPanelOptions = HR.GUI.CreateARPanelOptions

--- ============================ CONTENT ============================
HR.GUISettings.APL.Paladin = {
  Commons = {
    UseTrinkets = true,
    UsePotions = true,
    TrinketDisplayStyle = "Suggested",
    CovenantDisplayStyle = "Suggested",
    GCDasOffGCD = {
      Racials = false,
    },
    OffGCDasOffGCD = {
      Racials = true,
      Rebuke = true,
    }
  },
  Protection = {
    -- CDs HP %
    GoAKHP = 40,
    WordofGloryHP = 50,
    ArdentDefenderHP = 60,
    ShieldoftheRighteousHP = 70,
    GCDasOffGCD = {
      AvengingWrath = true,
      WordofGlory = true,
      Seraphim = true,
    },
    OffGCDasOffGCD = {
      MomentofGlory = true,
      ShieldoftheRighteous = true,
    }
  },
  Retribution = {
    Playstyle = {
      DontForceCDs = false
    },
    OffGCDasOffGCD = {
      AvengingWrath = true,
    },
  },
}
-- GUI
HR.GUI.LoadSettingsRecursively(HR.GUISettings)
-- Child Panels
local ARPanel = HR.GUI.Panel
local CP_Paladin = CreateChildPanel(ARPanel, "Paladin")
local CP_Protection = CreateChildPanel(CP_Paladin, "Protection")
local CP_Retribution = CreateChildPanel(CP_Paladin, "Retribution")

-- Shared Paladin settings
CreatePanelOption("CheckButton", CP_Paladin, "APL.Paladin.Commons.UsePotions", "Show Potions", "Enable this if you want the addon to show you when to use Potions.")
CreatePanelOption("CheckButton", CP_Paladin, "APL.Paladin.Commons.UseTrinkets", "Use Trinkets", "Use Trinkets as part of the rotation")
CreatePanelOption("Dropdown", CP_Paladin, "APL.Paladin.Commons.TrinketDisplayStyle", {"Main Icon", "Suggested", "SuggestedRight", "Cooldown"}, "Trinket Display Style", "Define which icon display style to use for Trinkets.")
CreatePanelOption("Dropdown", CP_Paladin, "APL.Paladin.Commons.CovenantDisplayStyle", {"Main Icon", "Suggested", "SuggestedRight", "Cooldown"}, "Covenant Display Style", "Define which icon display style to use for active Shadowlands Covenant Abilities.")
CreateARPanelOptions(CP_Paladin, "APL.Paladin.Commons")

-- Protection
CreatePanelOption("Slider", CP_Protection, "APL.Paladin.Protection.GoAKHP", {0, 100, 1}, "GoAK HP", "Set the Guardian of Ancient Kings HP threshold.")
CreatePanelOption("Slider", CP_Protection, "APL.Paladin.Protection.WordofGloryHP", {0, 100, 1}, "Word of Glory HP", "Set the Word of Glory HP threshold.")
CreatePanelOption("Slider", CP_Protection, "APL.Paladin.Protection.ArdentDefenderHP", {0, 100, 1}, "Ardent Defender HP", "Set the Ardent Defender HP threshold.")
CreatePanelOption("Slider", CP_Protection, "APL.Paladin.Protection.ShieldoftheRighteousHP", {0, 100, 1}, "Shield of the Righteous HP", "Set the Shield of the Righteous HP threshold.")
CreateARPanelOptions(CP_Protection, "APL.Paladin.Protection")

-- Retribution
CreateARPanelOptions(CP_Retribution, "APL.Paladin.Retribution")
CreatePanelOption("CheckButton", CP_Retribution, "APL.Paladin.Retribution.Playstyle.DontForceCDs", "Dont force using CDs", "Enable this if you want the addon to show to dont force use Avenging Wrath or Crusade.")
