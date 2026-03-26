-- Event and script wiring for tooltip hooks, slash commands, and SavedVariables init.
local addonName, addon = ...

function addon.OnTooltipUpdated(self, elapsed)
    local db = addon.GetDB()

    -- OthTips owns hide timing so mouse-anchored world tooltips can snap-hide cleanly.
    local hideDelay = self.OthTipsHideDelay
    local owner = self.GetOwner and self:GetOwner() or nil
    if self == GameTooltip and owner and hideDelay ~= nil then
        local hoveringOwner
        local hoveringTooltip
        if self.OthTipsWorldCursorDriven then
            hoveringOwner = addon.HasWorldCursorTooltip()
            hoveringTooltip = false
        elseif owner == WorldFrame then
            hoveringOwner = addon.HasWorldCursorTooltip()
            hoveringTooltip = false
        else
            hoveringOwner = addon.SafeMouseIsOver(owner)
            hoveringTooltip = db and db.anchorToMouse and false or addon.SafeMouseIsOver(self)
        end

        if hoveringOwner or hoveringTooltip then
            self.OthTipsHideElapsed = nil
        else
            if hideDelay <= 0 then
                self:Hide()
                return
            end
            self.OthTipsHideElapsed = (self.OthTipsHideElapsed or 0) + (elapsed or 0)
            if self.OthTipsHideElapsed >= hideDelay then
                self:Hide()
                return
            end
        end
    end

    if self == GameTooltip and db and db.anchorToMouse and self:IsShown() then
        if hideDelay ~= nil and hideDelay <= 0 and self.OthTipsWorldCursorDriven and not addon.HasWorldCursorTooltip() then
            self:Hide()
            return
        end
        addon.PositionTooltipAtCursor(self)
    end

end

function addon.OnTooltipDataUpdated(dataInstanceID)
    local tooltip = GameTooltip
    if not tooltip or not tooltip:IsShown() or tooltip:IsForbidden() then
        return
    end

    if tooltip.OthTipsUnitDataInstanceID ~= dataInstanceID then
        return
    end

    local updatedData = tooltip.OthTipsUnitData
    if tooltip.GetTooltipData then
        local ok, tooltipData = pcall(tooltip.GetTooltipData, tooltip)
        if ok and tooltipData then
            updatedData = tooltipData
        end
    end

    addon.PrepareSupportedUnitTooltipData(updatedData)

    if not addon.IsSupportedUnitTooltipData(tooltip, updatedData) then
        return
    end

    tooltip.OthTipsUnitData = updatedData
    tooltip.OthTipsRenderedDataInstanceID = nil
    addon.ReapplyVisibleUnitTooltip(tooltip)
end

function addon.OnTooltipCleared(self)
    self.OthTipsAnchorMode = nil
    self.OthTipsAnchorTarget = nil
    self.OthTipsHostileStatusLineIndex = nil
    self.OthTipsUnit = nil
    self.OthTipsUnitDataInstanceID = nil
    self.OthTipsUnitData = nil
    self.OthTipsRenderedDataInstanceID = nil
    self.OthTipsHideElapsed = nil
    self.OthTipsWorldCursorDriven = false
    addon.ResetTopRightTextAnchor(self)
    addon.SetTooltipArtVisible(self, true)
    if self:GetName() then
        local rightLine = _G[self:GetName() .. "TextRight1"]
        if rightLine and rightLine.SetText then
            rightLine:SetText(nil)
            if rightLine.ClearAllPoints then
                rightLine:ClearAllPoints()
                rightLine:SetPoint("RIGHT", self, "RIGHT", -13, 0)
            end
        end
    end
    addon.StyleTooltip(self)
end

function addon.RegisterTooltipHooks()
    for _, name in ipairs(addon.tooltipNames) do
        local tooltip = _G[name]
        if tooltip and not tooltip.OthTipsHooked then
            tooltip:HookScript("OnShow", function(self)
                addon.StyleTooltip(self)
                addon.ApplyTooltipAutoHide(self)
                addon.ApplyTooltipAnchor(self)
                addon.ApplyFactionDisplayRuntime(self)
                addon.OnTooltipUpdated(self)
            end)
            tooltip:HookScript("OnUpdate", addon.OnTooltipUpdated)
            tooltip:HookScript("OnHide", function(self)
                self.OthTipsWorldCursorDriven = false
            end)
            tooltip:HookScript("OnTooltipCleared", addon.OnTooltipCleared)
            tooltip.OthTipsHooked = true
            tooltip.OthTipsAnchorMode = nil
            tooltip.OthTipsAnchorTarget = nil
            addon.StyleTooltip(tooltip)
        end
    end

    hooksecurefunc("GameTooltip_SetDefaultAnchor", addon.ApplyDefaultAnchor)

    if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType and not addon.unitColorHooked then
        -- Only player unit tooltips use custom content formatting; non-player
        -- tooltips stay on Blizzard's default text path.
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, addon.ApplyUnitTextFormattingFromData)
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, addon.ApplyFactionRuntimeFromData)
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Object, addon.FinalizeSupportedTooltipData)
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Currency, addon.FinalizeSupportedTooltipData)
        addon.unitColorHooked = true
    end
end

function addon.InitDatabase()
    OthTipsDB = OthTipsDB or {}
    addon.CopyDefaults(OthTipsDB, addon.DEFAULTS)
end

function addon.OpenSettings()
    if addon.category and Settings and Settings.OpenToCategory then
        Settings.OpenToCategory(addon.category:GetID())
        Settings.OpenToCategory(addon.category:GetID())
    end
end

SLASH_OTHTIPS1 = "/othtips"
SlashCmdList.OTHTIPS = function(message)
    local command = message and strtrim(message):lower() or ""
    if command == "unlock" then
        local db = addon.GetDB()
        db.unlocked = not db.unlocked
        addon.ApplySettings()
        if db.unlocked then
            addon.ShowPreviewTooltip()
        else
            addon.HidePreviewTooltip()
        end
        return
    end

    addon.OpenSettings()
end

addon.worldCursorTooltipActive = false

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("WORLD_CURSOR_TOOLTIP_UPDATE")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("TOOLTIP_DATA_UPDATE")
eventFrame:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        addon.InitDatabase()
        addon.ApplyTooltipFonts()
        addon.CreateAnchor()
        addon.RegisterTooltipHooks()
        addon.RegisterExternalUnitFrameCompatibility()
        addon.RefreshAllTooltips()
        addon.ApplySettings()
    elseif event == "ADDON_LOADED" and arg1 == "EllesmereUIUnitFrames" then
        addon.RetryExternalUnitFrameCompatibility()
    elseif event == "PLAYER_ENTERING_WORLD" then
        addon.RetryExternalUnitFrameCompatibility()
    elseif event == "TOOLTIP_DATA_UPDATE" then
        addon.OnTooltipDataUpdated(arg1)
    elseif event == "WORLD_CURSOR_TOOLTIP_UPDATE" then
        local noneAnchor = Enum and Enum.WorldCursorAnchorType and Enum.WorldCursorAnchorType.None
        addon.worldCursorTooltipActive = arg1 ~= nil and arg1 ~= noneAnchor
        if GameTooltip and GameTooltip:IsShown() then
            GameTooltip.OthTipsWorldCursorDriven = true
        end
        if not addon.worldCursorTooltipActive and GameTooltip and GameTooltip:IsShown() and GameTooltip.OthTipsWorldCursorDriven then
            local delay = GameTooltip.OthTipsHideDelay or 0
            local db = addon.GetDB()
            if db and db.anchorToMouse and delay <= 0 then
                GameTooltip:Hide()
            else
                GameTooltip.OthTipsHideElapsed = 0
            end
        end
    end
end)
