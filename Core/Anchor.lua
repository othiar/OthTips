-- Anchor handling, preview tooltip, autohide, and external unit frame compatibility.
local _, addon = ...

function addon.HasWorldCursorTooltip()
    if not (C_TooltipInfo and C_TooltipInfo.GetWorldCursor) then
        return addon.worldCursorTooltipActive
    end

    local ok, tooltipInfo = pcall(C_TooltipInfo.GetWorldCursor)
    if not ok or not tooltipInfo or not tooltipInfo.lines then
        return false
    end

    return #tooltipInfo.lines > 0
end

function addon.ApplyTooltipAutoHide(tooltip)
    if not tooltip or tooltip:IsForbidden() then
        return
    end

    local db = addon.GetDB()
    tooltip.OthTipsHideDelay = db and db.hideDelay or 0
    tooltip.OthTipsHideElapsed = nil
    tooltip.OthTipsWorldCursorDriven = false
end

function addon.ApplyTooltipAnchor(tooltip)
    local db = addon.GetDB()
    if not db or not db.useCustomAnchor or tooltip ~= GameTooltip then
        return
    end

    if db.anchorToMouse then
        if tooltip.OthTipsAnchorMode == "mouse" then
            return
        end
        tooltip.OthTipsAnchorMode = "mouse"
        tooltip.OthTipsAnchorTarget = nil
        return
    end

    local anchor = addon.frames.anchor or addon.CreateAnchor()
    if tooltip.OthTipsAnchorMode == "fixed" and tooltip.OthTipsAnchorTarget == anchor then
        return
    end

    tooltip:ClearAllPoints()
    tooltip:SetPoint("BOTTOMLEFT", anchor, "TOPLEFT", 0, 8)
    tooltip.OthTipsAnchorMode = "fixed"
    tooltip.OthTipsAnchorTarget = anchor
end

function addon.PositionTooltipAtCursor(tooltip)
    local db = addon.GetDB()
    if not db or not db.anchorToMouse or tooltip ~= GameTooltip or not tooltip:IsShown() then
        return
    end

    local scale = UIParent:GetEffectiveScale()
    local cursorX, cursorY = GetCursorPosition()
    cursorX = cursorX / scale
    cursorY = cursorY / scale

    local direction = db.anchorDirection or "RIGHT"
    local cursorOffset = db.cursorOffset or addon.DEFAULTS.cursorOffset or 16
    local point, offsetX, offsetY

    if direction == "TOPLEFT" then
        point, offsetX, offsetY = "BOTTOMRIGHT", -cursorOffset, cursorOffset
    elseif direction == "TOPRIGHT" then
        point, offsetX, offsetY = "BOTTOMLEFT", cursorOffset, cursorOffset
    elseif direction == "BOTTOMLEFT" then
        point, offsetX, offsetY = "TOPRIGHT", -cursorOffset, -cursorOffset
    elseif direction == "BOTTOMRIGHT" then
        point, offsetX, offsetY = "TOPLEFT", cursorOffset, -cursorOffset
    elseif direction == "LEFT" then
        point, offsetX, offsetY = "RIGHT", -cursorOffset, 0
    else
        point, offsetX, offsetY = "LEFT", cursorOffset, 0
    end

    tooltip:ClearAllPoints()
    tooltip:SetPoint(point, UIParent, "BOTTOMLEFT", cursorX + offsetX, cursorY + offsetY)
end

function addon.FinalizeTooltipAppearance(tooltip)
    if not tooltip or tooltip:IsForbidden() or not tooltip:IsShown() then
        return
    end

    addon.StyleTooltip(tooltip)
    addon.ApplyTooltipAnchor(tooltip)
    addon.ApplyFactionDisplayRuntime(tooltip)
    addon.SetTooltipArtVisible(tooltip, true)
end

function addon.QueueTooltipFinalize(tooltip)
    if not tooltip or tooltip:IsForbidden() then
        return
    end

    -- Defer custom art until Blizzard finishes sizing object/world tooltips.
    addon.SetTooltipArtVisible(tooltip, false)
    C_Timer.After(0, function()
        addon.FinalizeTooltipAppearance(tooltip)
    end)
end

function addon.UpdateTooltipAnchor()
    local anchor = addon.frames.anchor
    local db = addon.GetDB()
    if not anchor or not db then
        return
    end

    anchor:ClearAllPoints()
    anchor:SetPoint(db.anchorPoint, UIParent, db.anchorPoint, db.anchorX, db.anchorY)
    anchor:SetClampedToScreen(db.clampToScreen)
end

function addon.SaveAnchorPosition()
    local anchor = addon.frames.anchor
    if not anchor then
        return
    end

    local point, _, _, x, y = anchor:GetPoint(1)
    local db = addon.GetDB()
    db.anchorPoint = point
    db.anchorX = math.floor(x + 0.5)
    db.anchorY = math.floor(y + 0.5)
end

function addon.RefreshAnchorVisibility()
    local anchor = addon.frames.anchor
    local db = addon.GetDB()
    if not anchor or not db then
        return
    end

    anchor:SetClampedToScreen(db.clampToScreen)
    anchor:EnableMouse(db.unlocked)
    anchor:SetMovable(db.unlocked)

    if db.unlocked and not db.anchorToMouse and db.useCustomAnchor then
        anchor:Show()
    else
        anchor:Hide()
    end
end

function addon.CreateAnchor()
    if addon.frames.anchor then
        return addon.frames.anchor
    end

    local anchor = CreateFrame("Frame", "OthTipsAnchorFrame", UIParent)
    anchor:SetFrameStrata("TOOLTIP")
    anchor:SetSize(addon.constants.ANCHOR_SIZE.width, addon.constants.ANCHOR_SIZE.height)
    anchor:RegisterForDrag("LeftButton")
    anchor:SetScript("OnDragStart", function(self)
        if addon.GetDB().unlocked then
            self:StartMoving()
        end
    end)
    anchor:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        addon.SaveAnchorPosition()
    end)

    local bg = anchor:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.06, 0.08, 0.10, 0.88)
    anchor.bg = bg

    addon.CreateBorder(anchor)
    addon.SetBorderColor(anchor, unpack(addon.constants.TOOLTIP_ACCENT))

    local text = anchor:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    text:SetPoint("CENTER")
    text:SetText("OthTips Anchor")
    text:SetTextColor(0.92, 0.95, 0.97, 0.9)
    text:SetFont(addon.GetTooltipFont(), 12, "OUTLINE")
    anchor.text = text

    local hint = anchor:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hint:SetPoint("TOP", text, "BOTTOM", 0, -2)
    hint:SetText("Drag to move tooltip")
    hint:SetFont(addon.GetTooltipFont(), 10, "")
    anchor.hint = hint

    addon.frames.anchor = anchor
    addon.UpdateTooltipAnchor()
    addon.RefreshAnchorVisibility()
    return anchor
end

function addon.ResetAnchorPosition()
    local db = addon.GetDB()
    db.anchorPoint = addon.DEFAULTS.anchorPoint
    db.anchorX = addon.DEFAULTS.anchorX
    db.anchorY = addon.DEFAULTS.anchorY
    addon.UpdateTooltipAnchor()
end

function addon.ShowPreviewTooltip()
    local anchor = addon.frames.anchor or addon.CreateAnchor()
    local db = addon.GetDB()

    if db.anchorToMouse then
        GameTooltip:SetOwner(WorldFrame or UIParent, "ANCHOR_NONE")
    else
        GameTooltip:SetOwner(anchor, "ANCHOR_NONE")
        GameTooltip:ClearAllPoints()
        GameTooltip:SetPoint("BOTTOMLEFT", anchor, "TOPLEFT", 0, 8)
    end

    GameTooltip:ClearLines()
    GameTooltip:AddLine("OthTips")
    GameTooltip:AddLine("Custom tooltip skin", 0.85, 0.88, 0.92, true)
    GameTooltip:AddLine(" ")
    if db.anchorToMouse then
        GameTooltip:AddLine("Tooltip is anchored to the cursor using the selected direction.", unpack(addon.constants.TOOLTIP_ACCENT))
    else
        GameTooltip:AddLine("Drag the anchor while unlocked.", unpack(addon.constants.TOOLTIP_ACCENT))
    end
    GameTooltip:Show()
    if db.anchorToMouse then
        addon.PositionTooltipAtCursor(GameTooltip)
    end
end

function addon.HidePreviewTooltip()
    if GameTooltip:IsOwned(addon.frames.anchor) or GameTooltip:IsOwned(UIParent) or GameTooltip:IsOwned(WorldFrame) then
        GameTooltip:Hide()
    end
end

function addon.RefreshAllTooltips()
    for _, name in ipairs(addon.tooltipNames) do
        local tooltip = _G[name]
        if tooltip then
            addon.StyleTooltip(tooltip)
        end
    end
end

function addon.ApplySettings()
    addon.UpdateTooltipAnchor()
    addon.RefreshAnchorVisibility()
end

function addon.ApplyDefaultAnchor(tooltip)
    local db = addon.GetDB()
    if not db or not db.useCustomAnchor then
        return
    end

    if tooltip ~= GameTooltip then
        return
    end

    addon.ApplyTooltipAnchor(tooltip)
end

function addon.SafeMouseIsOver(frame)
    if not frame then
        return false
    end

    -- Some owners return protected booleans here; treat anything tainted as not-hovered.
    local ok = pcall(function()
        return MouseIsOver(frame)
    end)
    if ok then
        local success, untainted = pcall(function()
            return MouseIsOver(frame) == true
        end)
        if success and untainted then
            return true
        end
    end

    return false
end

function addon.AttachUnitTooltipCompatibility(region, frame)
    if not region or region.OthTipsUnitTooltipCompatHooked then
        return
    end

    region:HookScript("OnEnter", function(self)
        if GameTooltip:IsForbidden() then
            return
        end

        local ownerFrame = frame or self
        local unit = addon.NormalizeUnitToken(ownerFrame.unit)
        if not unit and ownerFrame.GetAttribute then
            unit = addon.NormalizeUnitToken(ownerFrame:GetAttribute("unit"))
        end
        if not unit then
            return
        end

        GameTooltip:SetOwner(self, "ANCHOR_NONE")
        addon.ApplyTooltipAnchor(GameTooltip)
        GameTooltip:SetUnit(unit)

        C_Timer.After(0, function()
            if GameTooltip and GameTooltip:IsShown() then
                addon.ApplyTooltipAnchor(GameTooltip)
            end
        end)
    end)

    region:HookScript("OnLeave", function(self)
        if GameTooltip:IsForbidden() then
            return
        end

        local owner = GameTooltip.GetOwner and GameTooltip:GetOwner() or nil
        if owner == self then
            GameTooltip:Hide()
        end
    end)

    region.OthTipsUnitTooltipCompatHooked = true
end

function addon.HookUnitFrameTooltipCompatibility(frame)
    if not frame or frame.OthTipsUnitTooltipCompatHooked then
        return
    end

    addon.AttachUnitTooltipCompatibility(frame, frame)
    addon.AttachUnitTooltipCompatibility(frame.Health, frame)
    addon.AttachUnitTooltipCompatibility(frame.NameText, frame)
    addon.AttachUnitTooltipCompatibility(frame.HealthValue, frame)
    addon.AttachUnitTooltipCompatibility(frame.CenterText, frame)

    frame.OthTipsUnitTooltipCompatHooked = true
end

function addon.RegisterExternalUnitFrameCompatibility()
    -- Optional support for third-party unit frames that do not show GameTooltip on their own.
    local frameNames = {
        "EllesmereUIUnitFrames_Player",
        "EllesmereUIUnitFrames_Target",
        "EllesmereUIUnitFrames_Focus",
        "EllesmereUIUnitFrames_Pet",
        "EllesmereUIUnitFrames_TargetTarget",
        "EllesmereUIUnitFrames_FocusTarget",
    }

    for _, name in ipairs(frameNames) do
        addon.HookUnitFrameTooltipCompatibility(_G[name])
    end

    for index = 1, 8 do
        addon.HookUnitFrameTooltipCompatibility(_G["EllesmereUIUnitFrames_Boss" .. index])
    end

    if oUF and oUF.RegisterInitCallback and not addon.euiUnitFrameCompatRegistered then
        oUF:RegisterInitCallback(function(frame)
            local name = frame and frame.GetName and frame:GetName() or nil
            if name and name:find("^EllesmereUIUnitFrames_") then
                addon.HookUnitFrameTooltipCompatibility(frame)
            end
        end)
        addon.euiUnitFrameCompatRegistered = true
    end
end

function addon.RetryExternalUnitFrameCompatibility()
    addon.RegisterExternalUnitFrameCompatibility()
    C_Timer.After(1, addon.RegisterExternalUnitFrameCompatibility)
    C_Timer.After(3, addon.RegisterExternalUnitFrameCompatibility)
end
