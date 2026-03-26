-- Unit tooltip formatting: players, NPCs, quest lines, and safe unit helpers.
local _, addon = ...

function addon.NormalizeUnitToken(unit)
    local ok, exists = pcall(UnitExists, unit)
    if ok and exists then
        return unit
    end

    return nil
end

function addon.SafeUnitCall(func, unit, ...)
    -- World and nameplate tooltips can hand us unusable unit tokens; fail closed.
    unit = addon.NormalizeUnitToken(unit)
    if not unit then
        return nil
    end

    local ok, result1, result2, result3, result4 = pcall(func, unit, ...)
    if not ok then
        return nil
    end

    return result1, result2, result3, result4
end

function addon.NormalizeTooltipText(text)
    if text == nil then
        return nil
    end

    local ok, normalized = pcall(function()
        return tostring(text):gsub("^%s+", ""):gsub("%s+$", "")
    end)
    if ok then
        return normalized
    end

    return nil
end

function addon.GetUnitClassColor(unit)
    if not addon.SafeUnitCall(UnitIsPlayer, unit) then
        return nil
    end

    local _, class = addon.SafeUnitCall(UnitClass, unit)
    if not class then
        return nil
    end

    return (CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS)[class]
end

function addon.GetUnitReactionColor(unit)
    local reaction = addon.SafeUnitCall(UnitReaction, unit, "player")
    local color = reaction and FACTION_BAR_COLORS and FACTION_BAR_COLORS[reaction] or nil
    if color then
        return color
    end

    if addon.SafeUnitCall(UnitIsFriend, "player", unit) then
        return GREEN_FONT_COLOR or { r = 0.25, g = 0.88, b = 0.25 }
    end

    if addon.SafeUnitCall(UnitCanAttack, "player", unit) then
        return RED_FONT_COLOR or { r = 1, g = 0.1, b = 0.1 }
    end

    return nil
end

function addon.GetUnitFactionInfo(unit)
    local faction = addon.SafeUnitCall(UnitFactionGroup, unit)
    if faction == "Horde" then
        return faction, addon.constants.HORDE_COLOR, nil, { "Horde", _G.HORDE }
    elseif faction == "Alliance" then
        return faction, addon.constants.ALLIANCE_COLOR, nil, { "Alliance", _G.ALLIANCE }
    end

    return nil
end

function addon.GetUnitNameTextFromData(data)
    if not data or not data.lines then
        return nil
    end

    for _, lineData in ipairs(data.lines) do
        if lineData and lineData.type == Enum.TooltipDataLineType.UnitName and lineData.leftText then
            return addon.NormalizeTooltipText(lineData.leftText)
        end
    end

    return nil
end

function addon.GetTooltipLineText(tooltip, index, side)
    if not tooltip or tooltip:IsForbidden() or not tooltip.GetName then
        return nil
    end

    local tooltipName = tooltip:GetName()
    if not tooltipName then
        return nil
    end

    local region = _G[string.format("%sText%s%d", tooltipName, side or "Left", index)]
    if not region or not region.GetText then
        return nil
    end

    local ok, text = pcall(region.GetText, region)
    if ok then
        return addon.NormalizeTooltipText(text)
    end

    return nil
end

function addon.HasUnitLikeTooltipData(data)
    if not data or not data.lines then
        return false
    end

    for _, lineData in ipairs(data.lines) do
        if lineData and lineData.type == Enum.TooltipDataLineType.UnitName and lineData.leftText then
            return true
        end

        local leftText = lineData and addon.NormalizeTooltipText(lineData.leftText) or nil
        if leftText and (leftText:find("%d") or leftText:find("??", 1, true)) then
            return true
        end
    end

    return false
end

function addon.BuildFactionLineText(unit)
    local faction, color = addon.GetUnitFactionInfo(unit)
    if not faction or not color then
        return nil
    end

    local factionLabel = faction == "Horde" and (_G.HORDE or "Horde") or (_G.ALLIANCE or "Alliance")
    local lineText = ("|cff%02x%02x%02x%s|r"):format(color.r * 255, color.g * 255, color.b * 255, factionLabel)

    if addon.SafeUnitCall(UnitIsPVP, unit) then
        lineText = lineText .. " " .. addon.constants.PVP_TAG
    end

    return lineText
end

function addon.WrapColor(text, color)
    return ("|cff%02x%02x%02x%s|r"):format(color.r * 255, color.g * 255, color.b * 255, text)
end

function addon.BuildClassificationTag(unit)
    if addon.SafeUnitCall(UnitIsPlayer, unit) then
        return nil
    end

    local classification = addon.SafeUnitCall(UnitClassification, unit)
    if classification == "rareelite" then
        return "[" .. addon.WrapColor("Rare", addon.constants.RARE_COLOR) .. " " .. addon.WrapColor("Elite", addon.constants.ELITE_COLOR) .. "]"
    elseif classification == "rare" then
        return "[" .. addon.WrapColor("Rare", addon.constants.RARE_COLOR) .. "]"
    elseif classification == "elite" then
        return "[" .. addon.WrapColor("Elite", addon.constants.ELITE_COLOR) .. "]"
    end

    return nil
end

function addon.BuildClassificationTagFromData(data)
    if not data or not data.lines then
        return nil
    end

    for _, lineData in ipairs(data.lines) do
        for _, candidate in ipairs({
            lineData and addon.NormalizeTooltipText(lineData.leftText) or nil,
            lineData and addon.NormalizeTooltipText(lineData.rightText) or nil,
        }) do
            if candidate then
                local lower = candidate:lower()
                local hasRare = lower:find("rare", 1, true)
                local hasElite = lower:find("elite", 1, true)
                if hasRare and hasElite then
                    return "[" .. addon.WrapColor("Rare", addon.constants.RARE_COLOR) .. " " .. addon.WrapColor("Elite", addon.constants.ELITE_COLOR) .. "]"
                elseif hasRare then
                    return "[" .. addon.WrapColor("Rare", addon.constants.RARE_COLOR) .. "]"
                elseif hasElite then
                    return "[" .. addon.WrapColor("Elite", addon.constants.ELITE_COLOR) .. "]"
                end
            end
        end
    end

    return nil
end

function addon.GetNPCLevelInfoText(unit, data)
    local level = addon.SafeUnitCall(UnitLevel, unit)
    local levelText = level and (level < 0 and "??" or tostring(level)) or nil
    local classificationTag = addon.BuildClassificationTag(unit) or addon.BuildClassificationTagFromData(data)

    if not levelText and data and data.lines then
        for _, lineData in ipairs(data.lines) do
            for _, candidate in ipairs({
                lineData and addon.NormalizeTooltipText(lineData.leftText) or nil,
                lineData and addon.NormalizeTooltipText(lineData.rightText) or nil,
            }) do
                if candidate and (candidate:find("%d") or candidate:find("??", 1, true)) then
                    local cleaned = candidate
                    cleaned = cleaned:gsub("%s*%([Rr]are [Ee]lite%)", "")
                    cleaned = cleaned:gsub("%s*%([Rr]are%)", "")
                    cleaned = cleaned:gsub("%s*%([Ee]lite%)", "")
                    cleaned = cleaned:gsub("%s+$", "")
                    if classificationTag then
                        return cleaned .. " " .. classificationTag
                    end
                    return cleaned
                end
            end
        end
    end

    if levelText then
        local infoText = "Level " .. levelText
        if classificationTag then
            infoText = infoText .. " " .. classificationTag
        end
        return infoText
    end

    return nil
end

function addon.GetNPCLevelInfoTextFromTooltip(tooltip, unit, data)
    local infoText = addon.GetNPCLevelInfoText(unit, data)
    if infoText then
        return infoText
    end

    local renderedLine = addon.GetTooltipLineText(tooltip, 2, "Left")
    if not renderedLine or renderedLine == "" then
        return nil
    end

    renderedLine = renderedLine:gsub("%s*%([Rr]are [Ee]lite%)", "")
    renderedLine = renderedLine:gsub("%s*%([Rr]are%)", "")
    renderedLine = renderedLine:gsub("%s*%([Ee]lite%)", "")
    renderedLine = renderedLine:gsub("%s+$", "")

    local classificationTagFromTooltip = addon.BuildClassificationTag(unit)
    if not classificationTagFromTooltip then
        local lower = renderedLine:lower()
        local hasRare = lower:find("rare", 1, true)
        local hasElite = lower:find("elite", 1, true)
        if hasRare and hasElite then
            classificationTagFromTooltip = "[" .. addon.WrapColor("Rare", addon.constants.RARE_COLOR) .. " " .. addon.WrapColor("Elite", addon.constants.ELITE_COLOR) .. "]"
        elseif hasRare then
            classificationTagFromTooltip = "[" .. addon.WrapColor("Rare", addon.constants.RARE_COLOR) .. "]"
        elseif hasElite then
            classificationTagFromTooltip = "[" .. addon.WrapColor("Elite", addon.constants.ELITE_COLOR) .. "]"
        end
    end

    if classificationTagFromTooltip then
        return renderedLine .. " " .. classificationTagFromTooltip
    end

    return renderedLine
end

function addon.GetNPCTypeTextFromTooltip(tooltip, unit, data)
    local typeText = addon.GetNPCTypeText(unit, data)
    if typeText then
        return typeText
    end

    local renderedLine = addon.GetTooltipLineText(tooltip, 3, "Left")
    if renderedLine and renderedLine ~= "" then
        return renderedLine
    end

    return nil
end

function addon.GetTooltipUnit(tooltip)
    -- Hostile/world tooltips are inconsistent, so walk the common fallback chain.
    if not tooltip or tooltip:IsForbidden() or not tooltip.GetUnit then
        return UnitExists("mouseover") and "mouseover" or nil
    end

    local _, unit = tooltip:GetUnit()
    unit = addon.NormalizeUnitToken(unit)
    if unit then
        return unit
    end

    local owner = tooltip:GetOwner()
    if owner then
        if owner.GetAttribute then
            local attributeUnit = addon.NormalizeUnitToken(owner:GetAttribute("unit"))
            if attributeUnit and UnitExists(attributeUnit) then
                return attributeUnit
            end
        end

        local ownerUnit = addon.NormalizeUnitToken(owner.unit)
        if ownerUnit and UnitExists(ownerUnit) then
            return ownerUnit
        end
    end

    local mouseFocus = GetMouseFocus and GetMouseFocus() or nil
    if mouseFocus then
        if mouseFocus.GetAttribute then
            local focusUnit = addon.NormalizeUnitToken(mouseFocus:GetAttribute("unit"))
            if focusUnit and UnitExists(focusUnit) then
                return focusUnit
            end
        end

        local focusOwnerUnit = addon.NormalizeUnitToken(mouseFocus.unit)
        if focusOwnerUnit and UnitExists(focusOwnerUnit) then
            return focusOwnerUnit
        end
    end

    if UnitExists("mouseover") then
        return "mouseover"
    end

    return nil
end

function addon.GetPlayerGuildTextFromData(data, nameText)
    if not data or not data.lines then
        return nil
    end

    for _, lineData in ipairs(data.lines) do
        local text = lineData and addon.NormalizeTooltipText(lineData.leftText) or nil
        if text and text ~= nameText and text:match("^<.+>$") then
            return text
        end
    end

    return nil
end

function addon.GetPlayerGuildText(unit, data, nameText)
    local guildName = select(1, addon.SafeUnitCall(GetGuildInfo, unit))
    if guildName and guildName ~= "" then
        return "<" .. guildName .. ">"
    end

    return addon.GetPlayerGuildTextFromData(data, nameText)
end

function addon.GetPlayerIdentityText(unit)
    local level = addon.SafeUnitCall(UnitLevel, unit)
    local race = select(1, addon.SafeUnitCall(UnitRace, unit))
    if not level or not race then
        return nil
    end

    local levelText = level < 0 and "??" or tostring(level)
    return string.format("Level %s %s [Player]", levelText, race)
end

function addon.GetPlayerSpecClassText(data, unit, nameText, guildText, identityText, factionText)
    local localizedClass = select(1, addon.SafeUnitCall(UnitClass, unit))
    if not localizedClass then
        return nil
    end

    if data and data.lines then
        for _, lineData in ipairs(data.lines) do
            local text = lineData and addon.NormalizeTooltipText(lineData.leftText) or nil
            if text
                and text ~= nameText
                and text ~= guildText
                and text ~= identityText
                and text ~= factionText
                and not text:match("^<.+>$")
                and text:find(localizedClass, 1, true)
            then
                return text
            end
        end
    end

    return localizedClass
end

function addon.GetNPCTypeText(unit, data)
    local creatureType = select(1, addon.SafeUnitCall(UnitCreatureType, unit))
    if addon.NormalizeTooltipText(creatureType) then
        return creatureType
    end

    local creatureFamily = select(1, addon.SafeUnitCall(UnitCreatureFamily, unit))
    if addon.NormalizeTooltipText(creatureFamily) then
        return creatureFamily
    end

    if data and data.lines then
        local nameText = addon.GetUnitNameTextFromData(data)
        for _, lineData in ipairs(data.lines) do
            local text = lineData and addon.NormalizeTooltipText(lineData.leftText) or nil
            if text
                and text ~= nameText
                and not text:match("^<.+>$")
                and not text:find("%d")
                and not text:find("??", 1, true)
                and not text:find("elite", 1, true)
                and not text:find("rare", 1, true)
                and not text:find("pvp", 1, true)
                and not text:find("horde", 1, true)
                and not text:find("alliance", 1, true)
            then
                return text
            end
        end
    end

    return nil
end

local GATHER_TAG_COLORS = {
    available = GREEN_FONT_COLOR or { r = 0.25, g = 0.88, b = 0.25 },
    unavailable = { r = 0.62, g = 0.64, b = 0.68 },
}

function addon.GetKnownProfessionNames()
    local known = {}
    local prof1, prof2, archaeology, fishing, cooking = GetProfessions()

    for _, professionIndex in ipairs({ prof1, prof2, archaeology, fishing, cooking }) do
        if professionIndex then
            local skillName, _, _, _, _, _, _, _, _, _, skillLineName = GetProfessionInfo(professionIndex)
            local normalizedSkillName = addon.NormalizeTooltipText(skillName)
            local normalizedSkillLineName = addon.NormalizeTooltipText(skillLineName)
            if normalizedSkillName then
                known[normalizedSkillName] = true
            end
            if normalizedSkillLineName then
                known[normalizedSkillLineName] = true
            end
        end
    end

    return known
end

function addon.GetNPCGatherTagInfo(data)
    local gatherTexts = {
        {
            matches = {
                addon.NormalizeTooltipText(_G.UNIT_SKINNABLE),
                addon.NormalizeTooltipText(_G.UNIT_SKINNABLE_LEATHER),
                addon.NormalizeTooltipText(_G.UNIT_SKINNABLE_CLOTH),
                addon.NormalizeTooltipText(_G.SKINNING),
            },
            keywords = { "skinning", "skinnable", "skin" },
            label = "Skinnable",
            profession = addon.NormalizeTooltipText(_G.SKINNING) or "Skinning",
        },
        {
            matches = {
                addon.NormalizeTooltipText(_G.UNIT_SKINNABLE_HERB),
                addon.NormalizeTooltipText(_G.HERBALISM),
            },
            keywords = { "herbalism", "herb" },
            label = addon.NormalizeTooltipText(_G.HERBALISM) or "Herbalism",
            profession = addon.NormalizeTooltipText(_G.HERBALISM) or "Herbalism",
        },
        {
            matches = {
                addon.NormalizeTooltipText(_G.UNIT_SKINNABLE_MINING),
                addon.NormalizeTooltipText(_G.MINING),
            },
            keywords = { "mining", "mine", "miner" },
            label = addon.NormalizeTooltipText(_G.MINING) or "Mining",
            profession = addon.NormalizeTooltipText(_G.MINING) or "Mining",
        },
        {
            matches = {
                addon.NormalizeTooltipText(_G.UNIT_SKINNABLE_ENGINEERING),
                addon.NormalizeTooltipText(_G.ENGINEERING),
            },
            keywords = { "engineering", "engineer" },
            label = addon.NormalizeTooltipText(_G.ENGINEERING) or "Engineering",
            profession = addon.NormalizeTooltipText(_G.ENGINEERING) or "Engineering",
        },
    }

    if not data or not data.lines then
        return nil
    end

    for _, lineData in ipairs(data.lines) do
        for _, text in ipairs({
            lineData and addon.NormalizeTooltipText(lineData.leftText) or nil,
            lineData and addon.NormalizeTooltipText(lineData.rightText) or nil,
        }) do
            if text then
                local lowerText = text:lower()
                for _, gatherInfo in ipairs(gatherTexts) do
                    for _, matchText in ipairs(gatherInfo.matches) do
                        if matchText and (text == matchText or text:find(matchText, 1, true)) then
                            return gatherInfo
                        end
                    end
                    for _, keyword in ipairs(gatherInfo.keywords or {}) do
                        if lowerText:find(keyword, 1, true) then
                            return gatherInfo
                        end
                    end
                end
            end
        end
    end

    return nil
end

function addon.GetGatherTooltipDefinitions()
    return {
        {
            matches = {
                addon.NormalizeTooltipText(_G.UNIT_SKINNABLE),
                addon.NormalizeTooltipText(_G.UNIT_SKINNABLE_LEATHER),
                addon.NormalizeTooltipText(_G.UNIT_SKINNABLE_CLOTH),
                addon.NormalizeTooltipText(_G.SKINNING),
            },
            keywords = { "skinning", "skinnable", "skin" },
            label = "Skinnable",
            profession = addon.NormalizeTooltipText(_G.SKINNING) or "Skinning",
        },
        {
            matches = {
                addon.NormalizeTooltipText(_G.UNIT_SKINNABLE_HERB),
                addon.NormalizeTooltipText(_G.HERBALISM),
            },
            keywords = { "herbalism", "herb" },
            label = addon.NormalizeTooltipText(_G.HERBALISM) or "Herbalism",
            profession = addon.NormalizeTooltipText(_G.HERBALISM) or "Herbalism",
        },
        {
            matches = {
                addon.NormalizeTooltipText(_G.UNIT_SKINNABLE_MINING),
                addon.NormalizeTooltipText(_G.MINING),
            },
            keywords = { "mining", "mine", "miner" },
            label = addon.NormalizeTooltipText(_G.MINING) or "Mining",
            profession = addon.NormalizeTooltipText(_G.MINING) or "Mining",
        },
        {
            matches = {
                addon.NormalizeTooltipText(_G.UNIT_SKINNABLE_ENGINEERING),
                addon.NormalizeTooltipText(_G.ENGINEERING),
            },
            keywords = { "engineering", "engineer" },
            label = addon.NormalizeTooltipText(_G.ENGINEERING) or "Engineering",
            profession = addon.NormalizeTooltipText(_G.ENGINEERING) or "Engineering",
        },
    }
end

function addon.MatchGatherInfoFromText(text, gatherTexts)
    if not text then
        return nil
    end

    local lowerText = text:lower()
    for _, gatherInfo in ipairs(gatherTexts) do
        for _, matchText in ipairs(gatherInfo.matches or {}) do
            if matchText and (text == matchText or text:find(matchText, 1, true)) then
                return gatherInfo
            end
        end
        for _, keyword in ipairs(gatherInfo.keywords or {}) do
            if lowerText:find(keyword, 1, true) then
                return gatherInfo
            end
        end
    end

    return nil
end

function addon.GetNPCGatherTagInfoFromTooltip(tooltip, data)
    local gatherInfo = addon.GetNPCGatherTagInfo(data)
    if gatherInfo then
        return gatherInfo
    end

    if not tooltip or tooltip:IsForbidden() then
        return nil
    end

    local gatherTexts = addon.GetGatherTooltipDefinitions()
    for index = 1, math.max(tooltip:NumLines(), 6) do
        local leftText = addon.GetTooltipLineText(tooltip, index, "Left")
        local rightText = addon.GetTooltipLineText(tooltip, index, "Right")
        gatherInfo = addon.MatchGatherInfoFromText(leftText, gatherTexts) or addon.MatchGatherInfoFromText(rightText, gatherTexts)
        if gatherInfo then
            return gatherInfo
        end
    end

    return nil
end

function addon.GetNPCStatusText(unit, data)
    local isDead = addon.SafeUnitCall(UnitIsDeadOrGhost, unit)
    local gatherInfo = addon.GetNPCGatherTagInfo(data)
    if not isDead and not gatherInfo then
        return nil
    end

    local parts = {}
    if isDead then
        parts[#parts + 1] = addon.WrapColor("Corpse", RED_FONT_COLOR or { r = 1, g = 0.1, b = 0.1 })
    end

    if gatherInfo then
        local knownProfessions = addon.GetKnownProfessionNames()
        local color = knownProfessions[gatherInfo.profession] and GATHER_TAG_COLORS.available or GATHER_TAG_COLORS.unavailable
        parts[#parts + 1] = addon.WrapColor("[" .. gatherInfo.label .. "]", color)
    end

    return table.concat(parts, " ")
end

function addon.GetNPCStatusLine(unit, data)
    local isDead = addon.SafeUnitCall(UnitIsDeadOrGhost, unit)
    local gatherInfo = addon.GetNPCGatherTagInfo(data)
    if not isDead and not gatherInfo then
        return nil, nil
    end

    local parts = {}
    local color

    if isDead then
        parts[#parts + 1] = "Corpse"
        color = RED_FONT_COLOR or { r = 1, g = 0.1, b = 0.1 }
    end

    if gatherInfo then
        local knownProfessions = addon.GetKnownProfessionNames()
        local gatherColor = knownProfessions[gatherInfo.profession] and GATHER_TAG_COLORS.available or GATHER_TAG_COLORS.unavailable
        parts[#parts + 1] = addon.WrapColor("[" .. gatherInfo.label .. "]", gatherColor)
    end

    return table.concat(parts, " "), color
end

function addon.GetNPCStatusLineFromTooltip(tooltip, unit, data)
    local isDead = addon.SafeUnitCall(UnitIsDeadOrGhost, unit)
    local gatherInfo = addon.GetNPCGatherTagInfoFromTooltip(tooltip, data)
    if not isDead and not gatherInfo then
        return nil, nil
    end

    local parts = {}
    local color

    if isDead then
        parts[#parts + 1] = "Corpse"
        color = RED_FONT_COLOR or { r = 1, g = 0.1, b = 0.1 }
    end

    if gatherInfo then
        local knownProfessions = addon.GetKnownProfessionNames()
        local gatherColor = knownProfessions[gatherInfo.profession] and GATHER_TAG_COLORS.available or GATHER_TAG_COLORS.unavailable
        parts[#parts + 1] = addon.WrapColor("[" .. gatherInfo.label .. "]", gatherColor)
    end

    return table.concat(parts, " "), color
end

function addon.GetCorpseLabel()
    return addon.NormalizeTooltipText(_G.CORPSE) or "Corpse"
end

function addon.GetQuestStatusLines(data, excludedTexts)
    -- Preserve only likely objective/progress lines after rebuilding a custom unit tooltip.
    if not data or not data.lines then
        return {}
    end

    local excluded = {}
    for _, text in ipairs(excludedTexts or {}) do
        if text then
            excluded[addon.NormalizeTooltipText(text)] = true
        end
    end

    local questLines = {}
    for _, lineData in ipairs(data.lines) do
        local text = lineData and addon.NormalizeTooltipText(lineData.leftText) or nil
        if text
            and not excluded[text]
            and not text:match("^<.+>$")
            and (
                text:find("/", 1, true)
                or text:find("%%", 1, true)
                or text:find(QUEST_DASH or "-", 1, true)
                or text:lower():find("quest", 1, true)
                or text:lower():find("objective", 1, true)
            )
        then
            questLines[#questLines + 1] = text
            excluded[text] = true
        end
    end

    return questLines
end

function addon.FormatQuestStatusLine(text)
    local normalized = addon.NormalizeTooltipText(text)
    if not normalized then
        return nil
    end

    local isComplete = false
    local current, required = normalized:match("(%d+)%s*/%s*(%d+)")
    if current and required then
        isComplete = tonumber(current) and tonumber(required) and tonumber(current) >= tonumber(required) or false
    else
        local lower = normalized:lower()
        isComplete = lower:find("complete", 1, true) ~= nil or lower:find("completed", 1, true) ~= nil
    end

    local color
    if isComplete then
        color = GREEN_FONT_COLOR or { r = 0.25, g = 0.88, b = 0.25 }
    else
        color = { r = 0.95, g = 0.78, b = 0.22 }
    end

    return addon.WrapColor("[" .. normalized .. "]", color)
end

function addon.CleanupTooltipExtraLines(tooltip, usedLines)
    if not tooltip or tooltip:IsForbidden() or not tooltip.GetName then
        return
    end

    local tooltipName = tooltip:GetName()
    if not tooltipName then
        return
    end

    for index = usedLines + 1, tooltip:NumLines() do
        local leftLine = _G[tooltipName .. "TextLeft" .. index]
        local rightLine = _G[tooltipName .. "TextRight" .. index]
        if leftLine then
            leftLine:SetText(nil)
            leftLine:Hide()
        end
        if rightLine then
            rightLine:SetText(nil)
            rightLine:Hide()
        end
    end
end

function addon.SetTooltipLine(tooltip, index, text, r, g, b)
    if not tooltip or tooltip:IsForbidden() or not tooltip.GetName then
        return false
    end

    local tooltipName = tooltip:GetName()
    if not tooltipName then
        return false
    end

    local leftLine = _G[tooltipName .. "TextLeft" .. index]
    local rightLine = _G[tooltipName .. "TextRight" .. index]
    if not leftLine or not leftLine.SetText then
        return false
    end

    leftLine:SetText(text)
    leftLine:Show()
    if leftLine.SetTextColor and r and g and b then
        leftLine:SetTextColor(r, g, b)
    end

    if rightLine and rightLine.SetText then
        rightLine:SetText(nil)
        rightLine:Hide()
    end

    return true
end

function addon.HideTooltipLine(tooltip, index)
    if not tooltip or tooltip:IsForbidden() or not tooltip.GetName then
        return
    end

    local tooltipName = tooltip:GetName()
    if not tooltipName then
        return
    end

    local leftLine = _G[tooltipName .. "TextLeft" .. index]
    local rightLine = _G[tooltipName .. "TextRight" .. index]
    if leftLine then
        leftLine:SetText(nil)
        leftLine:Hide()
    end
    if rightLine then
        rightLine:SetText(nil)
        rightLine:Hide()
    end
end

function addon.HideDuplicateStatusLines(tooltip, startIndex)
    if not tooltip or tooltip:IsForbidden() then
        return
    end

    for index = startIndex or 5, tooltip:NumLines() do
        local text = addon.GetTooltipLineText(tooltip, index, "Left")
        if text then
            local lower = text:lower()
            if lower:find("corpse", 1, true)
                or lower:find("skinnable", 1, true)
                or lower:find("skinning", 1, true)
                or lower:find("mining", 1, true)
                or lower:find("herbalism", 1, true)
                or lower:find("engineering", 1, true)
            then
                addon.HideTooltipLine(tooltip, index)
            end
        end
    end
end

function addon.IsStatusLikeTooltipLine(text)
    if not text then
        return false
    end

    local normalized = addon.NormalizeTooltipText(text)
    if not normalized then
        return false
    end

    local corpseLabel = addon.GetCorpseLabel()
    if normalized == corpseLabel or normalized:find(corpseLabel, 1, true) then
        return true
    end

    if addon.MatchGatherInfoFromText(normalized, addon.GetGatherTooltipDefinitions()) then
        return true
    end

    local lower = normalized:lower()
    return lower:find("corpse", 1, true)
        or lower:find("skinnable", 1, true)
        or lower:find("skinning", 1, true)
        or lower:find("mining", 1, true)
        or lower:find("herbalism", 1, true)
        or lower:find("engineering", 1, true)
end

function addon.StripStatusLikeLinesFromTooltipData(data)
    if not data or not data.lines then
        return
    end

    -- Remove corpse/gather status lines before Blizzard renders them so our
    -- custom hostile status line does not have to race a later duplicate.
    for index = #data.lines, 1, -1 do
        local lineData = data.lines[index]
        if addon.IsStatusLikeTooltipLine(lineData and lineData.leftText)
            or addon.IsStatusLikeTooltipLine(lineData and lineData.rightText)
        then
            table.remove(data.lines, index)
        end
    end
end

function addon.HideStatusLikeLinesExcept(tooltip, keepIndex)
    if not tooltip or tooltip:IsForbidden() then
        return
    end

    for index = 2, tooltip:NumLines() do
        if index ~= keepIndex then
            local text = addon.GetTooltipLineText(tooltip, index, "Left")
            if addon.IsStatusLikeTooltipLine(text) then
                addon.HideTooltipLine(tooltip, index)
            end
        end
    end
end

function addon.FindTooltipStatusLineIndex(tooltip, startIndex)
    if not tooltip or tooltip:IsForbidden() then
        return nil
    end

    for index = startIndex or 2, tooltip:NumLines() do
        local text = addon.GetTooltipLineText(tooltip, index, "Left")
        if addon.IsStatusLikeTooltipLine(text) then
            return index
        end
    end

    return nil
end

function addon.ClearHostileStatusLine(tooltip)
    if not tooltip or tooltip:IsForbidden() then
        return
    end

    local previousStatusIndex = tooltip.OthTipsHostileStatusLineIndex
    if previousStatusIndex then
        addon.HideTooltipLine(tooltip, previousStatusIndex)
    end

    addon.HideStatusLikeLinesExcept(tooltip, nil)
    tooltip.OthTipsHostileStatusLineIndex = nil
end

function addon.IsQuestLikeTooltipLine(text)
    if not text then
        return false
    end

    return text:find("/", 1, true) ~= nil
        or text:find("%%", 1, true) ~= nil
        or text:find(QUEST_DASH or "-", 1, true) ~= nil
        or text:lower():find("quest", 1, true) ~= nil
        or text:lower():find("objective", 1, true) ~= nil
end

function addon.HideTrailingHostileStatusLines(tooltip, statusLineIndex)
    if not tooltip or tooltip:IsForbidden() or not statusLineIndex then
        return
    end

    for index = statusLineIndex + 1, math.min(tooltip:NumLines(), statusLineIndex + 2) do
        local leftText = addon.GetTooltipLineText(tooltip, index, "Left")
        local rightText = addon.GetTooltipLineText(tooltip, index, "Right")

        if addon.IsStatusLikeTooltipLine(leftText)
            or addon.IsStatusLikeTooltipLine(rightText)
            or ((leftText == nil and rightText == nil) and not addon.IsQuestLikeTooltipLine(leftText))
        then
            addon.HideTooltipLine(tooltip, index)
        end
    end
end

function addon.EstimateUnitTooltipWidth(lineTexts)
    -- Estimate from the rebuilt lines instead of reading protected fontstring widths.
    local padding = addon.GetTooltipPadding()
    local maxLength = 0
    for _, text in ipairs(lineTexts or {}) do
        if text then
            local plain = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
            maxLength = math.max(maxLength, #plain)
        end
    end

    if maxLength <= 0 then
        return nil
    end

    local estimatedWidth = math.ceil((maxLength * 6.1) + 28 + (padding * 2))
    return math.min(360, math.max(120, estimatedWidth))
end

function addon.ResizeUnitTooltip(tooltip, usedLines, lineTexts)
    if not tooltip or tooltip:IsForbidden() or tooltip ~= GameTooltip then
        return
    end

    -- Custom unit tooltips replace Blizzard lines entirely, so size from our own content.
    if usedLines > 0 then
        local width = addon.EstimateUnitTooltipWidth(lineTexts)
        if width and width > 0 then
            tooltip:SetWidth(width)
            if tooltip.SetMinimumWidth then
                tooltip:SetMinimumWidth(width)
            end
        end

        local padding = addon.GetTooltipPadding()
        local height = 24 + (usedLines * 20) + (padding * 2)
        tooltip:SetHeight(height)
    end
end

function addon.ApplyHostileTooltipFallback(tooltip, unit, data)
    if not tooltip or tooltip:IsForbidden() or not unit or addon.SafeUnitCall(UnitIsPlayer, unit) then
        addon.ClearHostileStatusLine(tooltip)
        return false
    end

    if not addon.SafeUnitCall(UnitCanAttack, "player", unit) then
        addon.ClearHostileStatusLine(tooltip)
        return false
    end

    local infoText = addon.GetNPCLevelInfoTextFromTooltip(tooltip, unit, data)
    local npcTypeText = addon.GetNPCTypeTextFromTooltip(tooltip, unit, data)
    local npcStatusText, npcStatusColor = addon.GetNPCStatusLineFromTooltip(tooltip, unit, data)
    local applied = false
    local previousStatusIndex = tooltip.OthTipsHostileStatusLineIndex
    local statusLineIndex = addon.FindTooltipStatusLineIndex(tooltip, 2) or previousStatusIndex or 4

    if infoText and addon.SetTooltipLine(tooltip, 2, infoText, 0.78, 0.82, 0.88) then
        applied = true
    end

    if npcTypeText and addon.SetTooltipLine(tooltip, 3, npcTypeText, 0.65, 0.68, 0.72) then
        applied = true
    end

    if npcStatusText and addon.SetTooltipLine(
        tooltip,
        statusLineIndex,
        npcStatusText,
        npcStatusColor and npcStatusColor.r or nil,
        npcStatusColor and npcStatusColor.g or nil,
        npcStatusColor and npcStatusColor.b or nil
    ) then
        applied = true
        if previousStatusIndex and previousStatusIndex ~= statusLineIndex then
            addon.HideTooltipLine(tooltip, previousStatusIndex)
        end
        tooltip.OthTipsHostileStatusLineIndex = statusLineIndex
        addon.HideStatusLikeLinesExcept(tooltip, statusLineIndex)
        addon.HideTrailingHostileStatusLines(tooltip, statusLineIndex)
    else
        -- Clear any stale status line from a previous corpse/gather tooltip.
        if previousStatusIndex then
            addon.HideTooltipLine(tooltip, previousStatusIndex)
        end
        addon.HideStatusLikeLinesExcept(tooltip, nil)
        tooltip.OthTipsHostileStatusLineIndex = nil
    end

    -- Keep Blizzard's hostile tooltip content intact, but ensure the panel is tall enough
    -- for any extra line we appended such as the corpse/status line.
    if applied and tooltip == GameTooltip then
        if tooltip.Layout then
            tooltip:Layout()
        end
    end

    return applied
end

function addon.IsSupportedUnitTooltipData(tooltip, data)
    if not data or not data.lines then
        return false
    end

    if data.type == Enum.TooltipDataType.Unit or data.type == Enum.TooltipDataType.Corpse then
        return true
    end

    if data.type == Enum.TooltipDataType.Object then
        return addon.GetTooltipUnit(tooltip) ~= nil or addon.HasUnitLikeTooltipData(data)
    end

    return false
end

function addon.ShouldUseCustomUnitRendering(unit)
    if not unit then
        return false
    end

    if addon.SafeUnitCall(UnitIsPlayer, unit) then
        return true
    end

    return true
end

function addon.ApplyCustomUnitRendering(tooltip, data)
    if not tooltip or tooltip:IsForbidden() then
        return false
    end

    -- Rebuild unit tooltips from scratch so player/NPC layouts stay consistent.
    local unit = tooltip.OthTipsUnit or addon.GetTooltipUnit(tooltip)
    local nameText = addon.GetUnitNameTextFromData(data)
        or addon.NormalizeTooltipText(addon.SafeUnitCall(UnitName, unit))
        or addon.NormalizeTooltipText(addon.SafeUnitCall(GetUnitName, unit, true))
        or addon.GetTooltipLineText(tooltip, 1, "Left")
    if not nameText or nameText == "" then
        return addon.ApplyHostileTooltipFallback(tooltip, unit, data)
    end

    -- Hostile world tooltips do not always expose a live unit token, but their tooltip data is
    -- still rich enough to rebuild the NPC layout.
    if not unit and not data then
        return false
    end

    if unit and not addon.ShouldUseCustomUnitRendering(unit) then
        return false
    end

    local classColor = addon.GetUnitClassColor(unit)
    local isPlayer = unit and addon.SafeUnitCall(UnitIsPlayer, unit) or false
    local usedLines = 0
    local lineTexts = {}
    local excludedTexts = { nameText }

    tooltip:ClearLines()
    if classColor then
        tooltip:AddLine(nameText, classColor.r, classColor.g, classColor.b, false)
    else
        local reactionColor = addon.GetUnitReactionColor(unit)
        tooltip:AddLine(nameText, reactionColor and reactionColor.r or 1, reactionColor and reactionColor.g or 1, reactionColor and reactionColor.b or 1, false)
    end
    lineTexts[#lineTexts + 1] = nameText
    usedLines = usedLines + 1

    if isPlayer then
        local guildText = addon.GetPlayerGuildText(unit, data, nameText)
        local identityText = addon.GetPlayerIdentityText(unit)
        local factionText = addon.BuildFactionLineText(unit)
        local specClassText = addon.GetPlayerSpecClassText(data, unit, nameText, guildText, identityText, factionText)

        if guildText then
            tooltip:AddLine(guildText, 0.65, 0.68, 0.72, false)
            lineTexts[#lineTexts + 1] = guildText
            excludedTexts[#excludedTexts + 1] = guildText
            usedLines = usedLines + 1
        end

        if identityText then
            tooltip:AddLine(identityText, 0.78, 0.82, 0.88, false)
            lineTexts[#lineTexts + 1] = identityText
            excludedTexts[#excludedTexts + 1] = identityText
            usedLines = usedLines + 1
        end

        if specClassText then
            tooltip:AddLine(specClassText, classColor and classColor.r or 1, classColor and classColor.g or 1, classColor and classColor.b or 1, false)
            lineTexts[#lineTexts + 1] = specClassText
            excludedTexts[#excludedTexts + 1] = specClassText
            usedLines = usedLines + 1
        end

        if factionText then
            tooltip:AddLine(factionText)
            lineTexts[#lineTexts + 1] = factionText
            excludedTexts[#excludedTexts + 1] = factionText
            usedLines = usedLines + 1
        end
    else
        local infoText = addon.GetNPCLevelInfoTextFromTooltip(tooltip, unit, data)
        local npcTypeText = addon.GetNPCTypeTextFromTooltip(tooltip, unit, data)
        local npcStatusText = addon.GetNPCStatusText(unit, data)
        if infoText then
            tooltip:AddLine(infoText, 0.78, 0.82, 0.88, false)
            lineTexts[#lineTexts + 1] = infoText
            excludedTexts[#excludedTexts + 1] = infoText
            usedLines = usedLines + 1
        end

        if npcTypeText then
            tooltip:AddLine(npcTypeText, 0.65, 0.68, 0.72, false)
            lineTexts[#lineTexts + 1] = npcTypeText
            excludedTexts[#excludedTexts + 1] = npcTypeText
            usedLines = usedLines + 1
        end

        if npcStatusText then
            tooltip:AddLine(npcStatusText, 0.72, 0.72, 0.72, false)
            lineTexts[#lineTexts + 1] = npcStatusText
            excludedTexts[#excludedTexts + 1] = npcStatusText
            usedLines = usedLines + 1
        end
    end

    for _, questLine in ipairs(addon.GetQuestStatusLines(data, excludedTexts)) do
        local formattedQuestLine = addon.FormatQuestStatusLine(questLine)
        tooltip:AddLine(formattedQuestLine or questLine, 0.84, 0.87, 0.92, true)
        lineTexts[#lineTexts + 1] = formattedQuestLine or questLine
        usedLines = usedLines + 1
    end

    addon.CleanupTooltipExtraLines(tooltip, usedLines)
    addon.ResizeUnitTooltip(tooltip, usedLines, lineTexts)
    if tooltip.Layout then
        tooltip:Layout()
    end
    tooltip:Show()
    return true
end

function addon.ReapplyVisibleUnitTooltip(tooltip)
    if not tooltip or tooltip:IsForbidden() or tooltip ~= GameTooltip or not tooltip:IsShown() then
        return
    end

    -- World-cursor tooltips can refresh after the initial callback, so reapply while visible.
    local data = tooltip.OthTipsUnitData
    if (not data or not data.lines) and C_TooltipInfo and C_TooltipInfo.GetWorldCursor then
        local ok, worldData = pcall(C_TooltipInfo.GetWorldCursor)
        if ok and worldData and worldData.lines then
            data = worldData
            if addon.IsSupportedUnitTooltipData(tooltip, data) then
                tooltip.OthTipsUnitData = data
            end
        end
    end

    if not addon.IsSupportedUnitTooltipData(tooltip, data) then
        return
    end

    if tooltip.OthTipsRenderedDataInstanceID == (data.dataInstanceID or true) then
        return
    end

    if addon.ApplyCustomUnitRendering(tooltip, data) then
        tooltip.OthTipsRenderedDataInstanceID = data.dataInstanceID or true
        addon.ResetTopRightTextAnchor(tooltip)
    end
end

function addon.ApplyUnitTextFormattingFromData(tooltip, data)
    if not tooltip or not data or tooltip:IsForbidden() then
        return
    end

    if not addon.IsSupportedUnitTooltipData(tooltip, data) then
        return
    end

    local dataInstanceID = data.dataInstanceID or true
    addon.ClearHostileStatusLine(tooltip)
    tooltip.OthTipsUnitDataInstanceID = dataInstanceID
    tooltip.OthTipsUnitData = data
    tooltip.OthTipsUnit = addon.GetTooltipUnit(tooltip)
    tooltip.OthTipsRenderedDataInstanceID = nil

    -- Run once on the next frame and once shortly after; later async changes are
    -- handled by TOOLTIP_DATA_UPDATE instead of polling on every frame.
    local function ApplyDeferredCustomRender(delay)
        C_Timer.After(delay, function()
            if not tooltip or tooltip:IsForbidden() or not tooltip:IsShown() or tooltip.OthTipsUnitDataInstanceID ~= dataInstanceID then
                return
            end

            if addon.ApplyCustomUnitRendering(tooltip, data) then
                addon.ResetTopRightTextAnchor(tooltip)
            end
        end)
    end

    ApplyDeferredCustomRender(0)
    ApplyDeferredCustomRender(0.05)
end

function addon.ApplyFactionRuntimeFromData(tooltip, data)
    if not tooltip or not data or tooltip:IsForbidden() then
        return
    end

    if not addon.IsSupportedUnitTooltipData(tooltip, data) then
        return
    end

    addon.ApplyFactionDisplayRuntime(tooltip)
    addon.QueueTooltipFinalize(tooltip)
end

function addon.IsActionButtonTooltipOwner(owner)
    local frame = owner
    while frame do
        if frame.action ~= nil or frame.commandName ~= nil then
            return true
        end

        if frame.GetAttribute then
            local action = frame:GetAttribute("action")
            local actionType = frame:GetAttribute("type")
            local spell = frame:GetAttribute("spell")
            if action ~= nil or spell ~= nil or actionType == "action" or actionType == "spell" or actionType == "macro" then
                return true
            end
        end

        local name = frame.GetName and frame:GetName() or nil
        if name and (
            name:find("ActionButton")
            or name:find("MultiBar")
            or name:find("OverrideActionBar")
            or name:find("PossessButton")
            or name:find("SingleButton")
            or name:find("OneButton")
            or name:find("Assisted")
            or name:find("RecommendedSpell")
        ) then
            return true
        end

        frame = frame.GetParent and frame:GetParent() or nil
    end

    return false
end

function addon.IsSingleButtonAssistantTooltip(data)
    if not data or not data.lines then
        return false
    end

    for _, lineData in ipairs(data.lines) do
        local text = lineData and addon.NormalizeTooltipText(lineData.leftText) or nil
        if text then
            if text:find("Single%-Button") or text:find("One%-Button") or text:find("Assisted Highlight") then
                return true
            end
        end
    end

    return false
end

function addon.FinalizeSupportedTooltipData(tooltip, data)
    if not tooltip or not data or tooltip:IsForbidden() then
        return
    end

    local owner = tooltip.GetOwner and tooltip:GetOwner() or nil
    if addon.IsActionButtonTooltipOwner(owner) or addon.IsSingleButtonAssistantTooltip(data) then
        return
    end

    addon.QueueTooltipFinalize(tooltip)
end
