-- Options loader kept separate so the panel only builds once the addon is ready.
local addonName, addon = ...

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent", function(_, _, loadedAddon)
    if loadedAddon == addonName then
        addon.BuildOptionsPanel()
    end
end)
