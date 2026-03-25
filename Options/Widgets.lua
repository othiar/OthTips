-- Reusable options-panel widget helpers and shared dropdown metadata.
local _, addon = ...

addon.options = addon.options or {}

addon.options.DIRECTION_ORDER = {
    "TOPLEFT",
    "TOPRIGHT",
    "BOTTOMLEFT",
    "BOTTOMRIGHT",
    "LEFT",
    "RIGHT",
}

addon.options.DIRECTION_LABELS = {
    TOPLEFT = "Above Left",
    TOPRIGHT = "Above Right",
    BOTTOMLEFT = "Below Left",
    BOTTOMRIGHT = "Below Right",
    LEFT = "Left",
    RIGHT = "Right",
}

addon.options.FONT_LABELS = {}
for key, entry in pairs(addon.fonts.entries) do
    addon.options.FONT_LABELS[key] = entry.label
end

function addon.options.CreateTitle(parent, text, point, relativeTo, relativePoint, x, y)
    local title = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint(point, relativeTo, relativePoint, x, y)
    title:SetText(text)
    return title
end

function addon.options.CreateHeader(parent, text, point, relativeTo, relativePoint, x, y)
    local header = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    header:SetPoint(point, relativeTo, relativePoint, x, y)
    header:SetText(text)
    return header
end

function addon.options.CreateText(parent, text, point, relativeTo, relativePoint, x, y, width)
    local fs = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    fs:SetPoint(point, relativeTo, relativePoint, x, y)
    fs:SetJustifyH("LEFT")
    fs:SetJustifyV("TOP")
    fs:SetText(text)
    fs:SetWidth(width)
    return fs
end

function addon.options.CreateModernCheckbox(parent, labelText, tooltipText)
    local checkbox = CreateFrame("CheckButton", nil, parent, "SettingsCheckboxTemplate")
    checkbox:SetText(labelText)
    checkbox.tooltipText = tooltipText
    checkbox:SetNormalFontObject(GameFontHighlight)
    local text = checkbox.GetFontString and checkbox:GetFontString() or checkbox.Text
    if text then
        text:ClearAllPoints()
        text:SetPoint("LEFT", checkbox, "RIGHT", 8, 0)
        text:SetJustifyH("LEFT")
        checkbox.Label = text
    end
    return checkbox
end

function addon.options.CreateModernSlider(parent, width, minValue, maxValue, step, formatter)
    local slider = CreateFrame("Slider", nil, parent, "MinimalSliderWithSteppersTemplate")
    slider:SetWidth(width)
    slider:SetHeight(20)
    slider:Init(minValue, minValue, maxValue, maxValue - minValue, {
        [MinimalSliderWithSteppersMixin.Label.Right] = CreateMinimalSliderFormatter(
            MinimalSliderWithSteppersMixin.Label.Right,
            formatter
        ),
    })
    slider.Slider:SetValueStep(step)
    slider.Slider:SetObeyStepOnDrag(true)
    slider.RightText:SetFontObject(GameFontHighlight)
    return slider
end

function addon.options.CreateModernDropdown(parent, width)
    local dropdown = CreateFrame("DropdownButton", nil, parent, "WowStyle1DropdownTemplate")
    dropdown:SetWidth(width)
    return dropdown
end

function addon.options.CreateButton(parent, width, height, text)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width, height)
    button:SetText(text)
    return button
end

function addon.options.SetupDirectionDropdown(dropdown)
    -- Keep the menu definition centralized so both sync and click paths share labels/order.
    dropdown:SetupMenu(function(_, rootDescription)
        local db = addon.GetDB()
        for _, direction in ipairs(addon.options.DIRECTION_ORDER) do
            rootDescription:CreateRadio(
                addon.options.DIRECTION_LABELS[direction],
                function()
                    return db.anchorDirection == direction
                end,
                function()
                    db.anchorDirection = direction
                    addon.ApplySettings()
                    if db.anchorToMouse then
                        addon.ShowPreviewTooltip()
                    end
                    dropdown:GenerateMenu()
                end
            )
        end
    end)
end

function addon.options.SetupFontDropdown(dropdown)
    dropdown:SetupMenu(function(_, rootDescription)
        local db = addon.GetDB()
        for _, key in ipairs(addon.fonts.order) do
            local entry = addon.fonts.entries[key]
            rootDescription:CreateRadio(
                entry.label,
                function()
                    return db.fontKey == key
                end,
                function()
                    db.fontKey = key
                    addon.ApplyTooltipFonts()
                    addon.RefreshAllTooltips()
                    if GameTooltip and GameTooltip:IsShown() then
                        addon.StyleTooltip(GameTooltip)
                    end
                    dropdown:SetText(entry.label)
                    dropdown:GenerateMenu()
                end
            )
        end
    end)
end
