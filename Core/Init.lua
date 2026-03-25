-- Core bootstrap: shared defaults, constants, and simple accessors.
local addonName, addon = ...

addon.frames = addon.frames or {}

addon.DEFAULTS = {
    useCustomAnchor = true,
    anchorToMouse = false,
    anchorDirection = "RIGHT",
    cursorOffset = 16,
    hideDelay = 0,
    tooltipPadding = 1,
    fontKey = "inter-semibold",
    unlocked = false,
    clampToScreen = true,
    anchorPoint = "BOTTOMRIGHT",
    anchorX = -380,
    anchorY = 240,
}

addon.constants = {
    TOOLTIP_BACKDROP = { 0.06, 0.08, 0.10, 0.95 },
    TOOLTIP_ACCENT = { 12 / 255, 210 / 255, 157 / 255, 0.95 },
    ANCHOR_SIZE = { width = 200, height = 36 },
    HORDE_COLOR = { r = 1.0, g = 0.20, b = 0.20 },
    ALLIANCE_COLOR = { r = 0.25, g = 0.55, b = 1.0 },
    ELITE_COLOR = { r = 0.96, g = 0.82, b = 0.28 },
    RARE_COLOR = { r = 0.78, g = 0.80, b = 0.86 },
    PVP_TAG = "|cffffa500[PVP]|r",
}

addon.fonts = {
    order = {
        "inter-thin",
        "inter-extralight",
        "inter-light",
        "inter-regular",
        "inter-medium",
        "inter-semibold",
        "inter-bold",
        "inter-extrabold",
        "inter-black",
    },
    entries = {
        ["inter-thin"] = {
            label = "Inter Thin",
            path = "Interface\\AddOns\\OthTips\\Media\\Inter-Thin.ttf",
        },
        ["inter-extralight"] = {
            label = "Inter ExtraLight",
            path = "Interface\\AddOns\\OthTips\\Media\\Inter-ExtraLight.ttf",
        },
        ["inter-light"] = {
            label = "Inter Light",
            path = "Interface\\AddOns\\OthTips\\Media\\Inter-Light.ttf",
        },
        ["inter-regular"] = {
            label = "Inter Regular",
            path = "Interface\\AddOns\\OthTips\\Media\\Inter-Regular.ttf",
        },
        ["inter-medium"] = {
            label = "Inter Medium",
            path = "Interface\\AddOns\\OthTips\\Media\\Inter-Medium.ttf",
        },
        ["inter-semibold"] = {
            label = "Inter SemiBold",
            path = "Interface\\AddOns\\OthTips\\Media\\Inter-SemiBold.ttf",
        },
        ["inter-bold"] = {
            label = "Inter Bold",
            path = "Interface\\AddOns\\OthTips\\Media\\Inter-Bold.ttf",
        },
        ["inter-extrabold"] = {
            label = "Inter ExtraBold",
            path = "Interface\\AddOns\\OthTips\\Media\\Inter-ExtraBold.ttf",
        },
        ["inter-black"] = {
            label = "Inter Black",
            path = "Interface\\AddOns\\OthTips\\Media\\Inter-Black.ttf",
        },
    },
}

addon.tooltipNames = {
    "GameTooltip",
    "ItemRefTooltip",
    "ItemRefShoppingTooltip1",
    "ItemRefShoppingTooltip2",
    "ShoppingTooltip1",
    "ShoppingTooltip2",
    "EmbeddedItemTooltip",
}

function addon.CopyDefaults(target, defaults)
    -- Recursively seed missing SavedVariables without overwriting user values.
    for key, value in pairs(defaults) do
        if type(value) == "table" then
            target[key] = target[key] or {}
            addon.CopyDefaults(target[key], value)
        elseif target[key] == nil then
            target[key] = value
        end
    end
end

function addon.GetDB()
    return OthTipsDB
end

function addon.GetTooltipPadding()
    local db = addon.GetDB()
    return db and db.tooltipPadding or addon.DEFAULTS.tooltipPadding or 1
end

function addon.GetTooltipFont()
    local db = addon.GetDB()
    local key = db and db.fontKey or addon.DEFAULTS.fontKey
    local fontEntry = key and addon.fonts.entries[key] or nil
    return fontEntry and fontEntry.path or addon.fonts.entries[addon.DEFAULTS.fontKey].path
end
