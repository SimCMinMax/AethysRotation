--- ============================ HEADER ============================
--- ======= LOCALIZE =======
-- Addon
local addonName, addonTable = ...
  -- HeroLib
local HL = HeroLib
-- HeroRotation
local HR = HeroRotation
-- File Locals
local GUI = HL.GUI
local CreateChildPanel = GUI.CreateChildPanel
local CreatePanelOption = GUI.CreatePanelOption
local CreateARPanelOption = HR.GUI.CreateARPanelOption
local CreateARPanelOptions = HR.GUI.CreateARPanelOptions


--- ============================ CONTENT ============================
-- All settings here should be moved into the GUI someday.
HR.GUISettings.APL.Shaman = {
  Commons = {
    UseTrinkets = true,
    UsePotions = true,
    TrinketDisplayStyle = "Suggested",
    CovenantDisplayStyle = "Suggested",
    UseBloodlust = false,
    -- {Display GCD as OffGCD, ForceReturn}
    GCDasOffGCD = {
      -- Abilities
      EarthElemental = true
    },
    -- {Display OffGCD as OffGCD, ForceReturn}
    OffGCDasOffGCD = {
      -- Racials
      Racials = true,
      -- Abilities
      WindShear = true
    }
  },
  Enhancement = {
    -- {Display GCD as OffGCD, ForceReturn}
    GCDasOffGCD = {
      -- Abilities
      FeralSpirit = true,
      Ascendance = true
    },
    -- {Display OffGCD as OffGCD, ForceReturn}
    OffGCDasOffGCD = {
      -- Racials

      -- Abilities

    },
  },
    Elemental = {
      Commons = {
        ShowSpeiclaElementalAblities = true,
      },
    -- {Display GCD as OffGCD, ForceReturn}
    GCDasOffGCD = {
      -- Abilities
      Ascendance = true,
      FireElemental = true,
      StormElemental = true,
      Stormkeeper =  true,
      EchoingShock = true,
    },
    -- {Display OffGCD as OffGCD, ForceReturn}
    OffGCDasOffGCD = {
      -- Racials
      -- Abilities
      PEMeteor = true,
      PEEyeOfTheStorm = true,
    }
  }
}

HR.GUI.LoadSettingsRecursively(HR.GUISettings);

-- Child Panels
local ARPanel = HR.GUI.Panel;
local CP_Shaman = CreateChildPanel(ARPanel, "Shaman");
local CP_Enhancement = CreateChildPanel(CP_Shaman, "Enhancement");
local CP_Elemental = CreateChildPanel(CP_Shaman, "Elemental");
local aplCommons = "APL.Shaman.Commons";

-- Controls
-- Shaman
CreateARPanelOptions(CP_Shaman, aplCommons);
--CreatePanelOption("CheckButton", CP_Mage, "APL.Shaman.Commons.UseTimeWarp", "Use Time Warp (NYI)", "Enable this if you want the addon to show you when to use Time Warp.");
CreatePanelOption("CheckButton", CP_Shaman, "APL.Shaman.Commons.UsePotions", "Show Potions", "Enable this if you want the addon to show you when to use Potions.");
CreatePanelOption("CheckButton", CP_Shaman, "APL.Shaman.Commons.UseTrinkets", "Use Trinkets", "Use Trinkets as part of the rotation");
CreatePanelOption("Dropdown", CP_Shaman, "APL.Shaman.Commons.TrinketDisplayStyle", {"Main Icon", "Suggested", "Cooldown"}, "Trinket Display Style", "Define which icon display style to use for Trinkets.");
CreatePanelOption("Dropdown", CP_Shaman, "APL.Shaman.Commons.CovenantDisplayStyle", {"Main Icon", "Suggested", "Cooldown"}, "Covenant Display Style", "Define which icon display style to use for active Shadowlands Covenant Abilities.");
-- Enhancement
CreateARPanelOptions(CP_Enhancement, "APL.Shaman.Enhancement");
-- Elemental
CreateARPanelOptions(CP_Elemental, "APL.Shaman.Elemental");
CreatePanelOption("CheckButton", CP_Elemental, "APL.Shaman.Elemental.Commons.ShowSpeiclaElementalAblities", "Show Special Elemental abilities", "Enable this if you want the addon to show you when to use special elemental abilities when selected the Primal Elementalists talent");
