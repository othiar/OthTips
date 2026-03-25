-- Settings panel layout and control wiring.
local addonName, addon = ...

function addon.BuildOptionsPanel()
    if not (Settings and Settings.RegisterCanvasLayoutCategory) then
        return
    end

    local panel = CreateFrame("Frame")
    panel.name = addonName

    addon.options.CreateTitle(panel, "OthTips", "TOPLEFT", panel, "TOPLEFT", 16, -16)
    addon.options.CreateText(panel, "Tooltip anchor and delay settings.", "TOPLEFT", panel, "TOPLEFT", 16, -48, 560)

    local generalHeader = addon.options.CreateHeader(panel, "General Options", "TOPLEFT", panel, "TOPLEFT", 16, -92)
    local fontLabel = addon.options.CreateText(panel, "Tooltip font", "TOPLEFT", generalHeader, "BOTTOMLEFT", 4, -8, 220)
    local fontDropdown = addon.options.CreateModernDropdown(panel, 200)
    fontDropdown:SetPoint("TOPLEFT", fontLabel, "BOTTOMLEFT", 0, -10)
    addon.options.SetupFontDropdown(fontDropdown)

    local paddingLabel = addon.options.CreateText(panel, "Tooltip padding: 1 px", "TOPLEFT", generalHeader, "BOTTOMLEFT", 4, -8, 220)
    paddingLabel:ClearAllPoints()
    paddingLabel:SetPoint("TOPLEFT", fontDropdown, "BOTTOMLEFT", 4, -16)
    local paddingSlider = addon.options.CreateModernSlider(panel, 240, 0, 16, 1, function(value)
        return string.format("%d px", value)
    end)
    paddingSlider:SetPoint("TOPLEFT", paddingLabel, "BOTTOMLEFT", 10, -18)

    local mouseHeader = addon.options.CreateHeader(panel, "Mouse Anchor", "TOPLEFT", paddingSlider, "BOTTOMLEFT", -10, -30)
    local mouseAnchor = addon.options.CreateModernCheckbox(panel, "Enabled", "Uses a cursor anchor instead of the movable OthTips anchor frame.")
    mouseAnchor:SetPoint("TOPLEFT", mouseHeader, "BOTTOMLEFT", 0, -10)

    local directionDropdown = addon.options.CreateModernDropdown(panel, 160)
    directionDropdown:SetPoint("LEFT", mouseAnchor.Label or mouseAnchor, "RIGHT", 24, 0)
    addon.options.SetupDirectionDropdown(directionDropdown)

    local mouseGapLabel = addon.options.CreateText(panel, "Mouse gap: 16 px", "TOPLEFT", mouseAnchor, "BOTTOMLEFT", 4, -12, 220)
    local mouseGapSlider = addon.options.CreateModernSlider(panel, 240, 0, 48, 1, function(value)
        return string.format("%d px", value)
    end)
    mouseGapSlider:SetPoint("TOPLEFT", mouseGapLabel, "BOTTOMLEFT", 10, -18)

    local movableHeader = addon.options.CreateHeader(panel, "Moveable Anchor", "TOPLEFT", mouseGapSlider, "BOTTOMLEFT", -10, -30)
    local unlockButton = addon.options.CreateButton(panel, 140, 24, "Unlock Anchor")
    unlockButton:SetPoint("TOPLEFT", movableHeader, "BOTTOMLEFT", 0, -10)

    local resetButton = addon.options.CreateButton(panel, 140, 24, "Reset Position")
    resetButton:SetPoint("LEFT", unlockButton, "RIGHT", 12, 0)

    local delayHeader = addon.options.CreateHeader(panel, "Tooltip Delay", "TOPLEFT", unlockButton, "BOTTOMLEFT", 0, -30)
    local hideDelayLabel = addon.options.CreateText(panel, "Tooltip hide delay: 0.0 sec", "TOPLEFT", delayHeader, "BOTTOMLEFT", 4, -8, 220)
    local hideDelaySlider = addon.options.CreateModernSlider(panel, 240, 0, 3, 0.5, function(value)
        return string.format("%.1f sec", value)
    end)
    hideDelaySlider:SetPoint("TOPLEFT", hideDelayLabel, "BOTTOMLEFT", 10, -18)

    local function SyncControls()
        -- The panel is the source of truth for widget state; pull fresh values on show and after clicks.
        local db = addon.GetDB()
        if db.useCustomAnchor == false then
            db.useCustomAnchor = true
            addon.ApplySettings()
        end

        mouseAnchor:SetChecked(db.anchorToMouse)
        directionDropdown:SetText(addon.options.DIRECTION_LABELS[db.anchorDirection] or addon.options.DIRECTION_LABELS.TOPLEFT)
        mouseGapSlider:SetValue(db.cursorOffset or 16)
        mouseGapLabel:SetText(string.format("Mouse gap: %d px", db.cursorOffset or 16))

        local fontEntry = addon.fonts.entries[db.fontKey or addon.DEFAULTS.fontKey] or addon.fonts.entries[addon.DEFAULTS.fontKey]
        fontDropdown:SetText(fontEntry.label)

        paddingSlider:SetValue(db.tooltipPadding or 1)
        paddingLabel:SetText(string.format("Tooltip padding: %d px", db.tooltipPadding or 1))

        hideDelaySlider:SetValue(db.hideDelay or 0)
        hideDelayLabel:SetText(string.format("Tooltip hide delay: %.1f sec", db.hideDelay or 0))

        if db.anchorToMouse then
            directionDropdown:Enable()
            mouseGapSlider:Enable()
            unlockButton:SetEnabled(false)
            resetButton:SetEnabled(false)
        else
            directionDropdown:Disable()
            mouseGapSlider:Disable()
            unlockButton:SetEnabled(true)
            resetButton:SetEnabled(true)
        end

        unlockButton:SetText(db.unlocked and "Lock Anchor" or "Unlock Anchor")
    end

    mouseAnchor:SetScript("OnClick", function(self)
        addon.GetDB().anchorToMouse = self:GetChecked()
        addon.ApplySettings()
        addon.HidePreviewTooltip()
        SyncControls()
    end)

    paddingSlider:RegisterCallback(MinimalSliderWithSteppersMixin.Event.OnValueChanged, function(_, value)
        value = math.floor(value + 0.5)
        addon.GetDB().tooltipPadding = value
        paddingLabel:SetText(string.format("Tooltip padding: %d px", value))
        addon.RefreshAllTooltips()
    end)

    mouseGapSlider:RegisterCallback(MinimalSliderWithSteppersMixin.Event.OnValueChanged, function(_, value)
        value = math.floor(value + 0.5)
        addon.GetDB().cursorOffset = value
        mouseGapLabel:SetText(string.format("Mouse gap: %d px", value))
        addon.ApplySettings()
        if addon.GetDB().anchorToMouse then
            addon.ShowPreviewTooltip()
        end
    end)

    hideDelaySlider:RegisterCallback(MinimalSliderWithSteppersMixin.Event.OnValueChanged, function(_, value)
        value = math.floor((value * 2) + 0.5) / 2
        addon.GetDB().hideDelay = value
        hideDelayLabel:SetText(string.format("Tooltip hide delay: %.1f sec", value))
    end)

    unlockButton:SetScript("OnClick", function()
        local db = addon.GetDB()
        db.unlocked = not db.unlocked
        addon.ApplySettings()
        if db.unlocked then
            addon.ShowPreviewTooltip()
        else
            addon.HidePreviewTooltip()
        end
        SyncControls()
    end)

    resetButton:SetScript("OnClick", function()
        addon.ResetAnchorPosition()
        addon.ApplySettings()
        if addon.GetDB().unlocked then
            addon.ShowPreviewTooltip()
        end
    end)

    panel:SetScript("OnShow", SyncControls)

    local category = Settings.RegisterCanvasLayoutCategory(panel, "OthTips")
    Settings.RegisterAddOnCategory(category)
    addon.category = category
end
