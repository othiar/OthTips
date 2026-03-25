-- Tooltip skinning and shared font application.
local _, addon = ...

function addon.CreateBorder(frame)
    if frame.OthTipsBorder then
        return frame.OthTipsBorder
    end

    local border = {}
    border.top = frame:CreateTexture(nil, "BORDER", nil, 1)
    border.top:SetHeight(2)
    border.top:SetPoint("TOPLEFT")
    border.top:SetPoint("TOPRIGHT")

    frame.OthTipsBorder = border
    return border
end

function addon.SetBorderColor(frame, r, g, b, a)
    local border = addon.CreateBorder(frame)
    border.top:SetColorTexture(r, g, b, a)
end

function addon.SetTooltipArtVisible(frame, visible)
    if not frame then
        return
    end

    if frame.OthTipsBackground then
        if visible then
            frame.OthTipsBackground:Show()
        else
            frame.OthTipsBackground:Hide()
        end
    end

    if frame.OthTipsBorder and frame.OthTipsBorder.top then
        if visible then
            frame.OthTipsBorder.top:Show()
        else
            frame.OthTipsBorder.top:Hide()
        end
    end
end

function addon.StripTooltipTextures(frame)
    if frame.OthTipsStripped then
        return
    end

    -- Hide Blizzard's stock tooltip art once and let OthTips own the visuals.
    local regions = { frame:GetRegions() }
    for _, region in ipairs(regions) do
        if region and region:GetObjectType() == "Texture" then
            local texture = region:GetTexture()
            if type(texture) == "string" and texture:find("UI%-Tooltip%-") then
                region:SetAlpha(0)
            end
        end
    end

    if frame.NineSlice then
        frame.NineSlice:Hide()
        hooksecurefunc(frame.NineSlice, "Show", function()
            frame.NineSlice:Hide()
        end)
    end

    if frame.BottomOverlay then
        frame.BottomOverlay:Hide()
    end

    frame.OthTipsStripped = true
end

function addon.ResetTopRightTextAnchor(tooltip)
    if tooltip == GameTooltip and GameTooltipTextRight1 and GameTooltipTextRight1.ClearAllPoints then
        GameTooltipTextRight1:ClearAllPoints()
        GameTooltipTextRight1:SetPoint("RIGHT", tooltip, "RIGHT", -13, 0)
    end
end

function addon.ApplyFactionDisplayRuntime(tooltip)
    if not tooltip or tooltip:IsForbidden() then
        return
    end

    addon.ResetTopRightTextAnchor(tooltip)
end

function addon.StyleTooltip(frame)
    if not frame or frame:IsForbidden() then
        return
    end

    -- This runs repeatedly, so keep it idempotent and avoid rebuilding art.
    addon.StripTooltipTextures(frame)

    if not frame.OthTipsBackground then
        local bg = frame:CreateTexture(nil, "BACKGROUND")
        bg:SetColorTexture(unpack(addon.constants.TOOLTIP_BACKDROP))
        frame.OthTipsBackground = bg
    end
    frame.OthTipsBackground:ClearAllPoints()
    frame.OthTipsBackground:SetPoint("TOPLEFT", 1, -1)
    frame.OthTipsBackground:SetPoint("BOTTOMRIGHT", -1, 1)

    if frame.SetPadding then
        local padding = addon.GetTooltipPadding()
        pcall(frame.SetPadding, frame, padding, padding, padding, padding)
    end

    if frame.StatusBar then
        frame.StatusBar:Hide()
        if not frame.StatusBar.OthTipsHideHooked then
            hooksecurefunc(frame.StatusBar, "Show", function(bar)
                bar:Hide()
            end)
            frame.StatusBar.OthTipsHideHooked = true
        end
    end

    if frame.OthTipsBorder and frame.OthTipsBorder.top then
        frame.OthTipsBorder.top:Hide()
    end

    local font = addon.GetTooltipFont()
    local name = frame:GetName()
    if name then
        for i = 1, frame:NumLines() do
            local left = _G[name .. "TextLeft" .. i]
            local right = _G[name .. "TextRight" .. i]
            if left then
                left:SetFont(font, i == 1 and 13 or 12, i == 1 and "OUTLINE" or "")
            end
            if right then
                right:SetFont(font, 12, "")
            end
        end
    end

    if frame == GameTooltip then
        if GameTooltipHeaderText then
            GameTooltipHeaderText:SetFont(font, 13, "OUTLINE")
        end
        if GameTooltipText then
            GameTooltipText:SetFont(font, 12, "")
        end
        if GameTooltipTextSmall then
            GameTooltipTextSmall:SetFont(font, 11, "")
        end
    end
end

function addon.ApplyTooltipFonts()
    local fontName = addon.GetTooltipFont()
    if GameTooltipHeaderText then
        GameTooltipHeaderText:SetFont(fontName, 13, "OUTLINE")
    end
    if GameTooltipText then
        GameTooltipText:SetFont(fontName, 12, "")
    end
    if GameTooltipTextSmall then
        GameTooltipTextSmall:SetFont(fontName, 11, "")
    end

    local anchor = addon.frames and addon.frames.anchor or nil
    if anchor and anchor.text then
        anchor.text:SetFont(fontName, 12, "OUTLINE")
    end
    if anchor and anchor.hint then
        anchor.hint:SetFont(fontName, 10, "")
    end
end
