local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Environment = getgenv()

if Environment.__SenseLuaMenu and type(Environment.__SenseLuaMenu.Destroy) == "function" then
    pcall(function() Environment.__SenseLuaMenu:Destroy() end)
end

-- A failed or interrupted reload can lose the Lua controller while leaving its
-- ScreenGui behind. Remove every orphaned Sense overlay before constructing the
-- replacement so detached window strokes cannot accumulate on the game view.
do
    local seen = {}
    local roots = { game:GetService("CoreGui") }
    pcall(function()
        if type(gethui) == "function" then roots[#roots + 1] = gethui() end
    end)
    for _, root in ipairs(roots) do
        if root and not seen[root] then
            seen[root] = true
            for _, object in ipairs(root:GetDescendants()) do
                if object:IsA("ScreenGui") and object.Name == "SenseLuaOverlay" then
                    pcall(function() object:Destroy() end)
                end
            end
        end
    end
end

local function load_api()
    local direct = Environment.SenseMenuApiUrl
    local base = Environment.SenseMenuBaseUrl
    local url = type(direct) == "string" and direct ~= "" and direct
        or (type(base) == "string" and base ~= "" and (base:gsub("/+$", "") .. "/api.lua"))
    if url then
        local ok, result = pcall(function() return loadstring(game:HttpGet(url))() end)
        if ok and type(result) == "table" and type(result.new) == "function" then return result end
    end
    if type(Environment.__SenseLuaMenuApiFactory) == "table"
        and type(Environment.__SenseLuaMenuApiFactory.new) == "function" then
        return Environment.__SenseLuaMenuApiFactory
    end
    return nil
end

local function load_font()
    local direct = Environment.SenseMenuFontUrl
    local base = Environment.SenseMenuBaseUrl
    local url = type(direct) == "string" and direct ~= "" and direct
        or (type(base) == "string" and base ~= "" and (base:gsub("/+$", "") .. "/font.lua"))
    if url then
        local ok, result = pcall(function() return loadstring(game:HttpGet(url))() end)
        if ok and type(result) == "table" and type(result.decorate) == "function" then return result end
    end
    if type(Environment.__SenseSmallFontModule) == "table"
        and type(Environment.__SenseSmallFontModule.decorate) == "function" then
        return Environment.__SenseSmallFontModule
    end
    return nil
end

local ApiFactory = load_api()
if type(ApiFactory) ~= "table" or type(ApiFactory.ParseDefaults) ~= "function" then return nil end
local MenuDefaults
if Environment.SenseMenuDefaults ~= nil then
    MenuDefaults = ApiFactory.ParseDefaults(Environment.SenseMenuDefaults)
end
local MenuColors = type(Environment.SenseMenuColors) == "table" and Environment.SenseMenuColors or nil
local existingApi = Environment.SenseMenuApi
local Api
if type(existingApi) == "table" and existingApi.Version == 2 and not existingApi.Destroyed
    and type(existingApi.Set) == "function" and type(existingApi.Bind) == "function"
    and type(existingApi.RegisterDefaults) == "function" and existingApi.Changed
    and type(existingApi.NotifyHit) == "function" and existingApi.HitNotification
    and existingApi.HitNotificationsCleared then
    Api = existingApi
    if MenuDefaults then
        local additions = {}
        for key, value in pairs(MenuDefaults) do
            if not Api:Has(key) then additions[key] = value end
        end
        if next(additions) then Api:RegisterDefaults(additions) end
    end
    if MenuColors and type(Api.RegisterColors) == "function" then Api:RegisterColors(MenuColors) end
else
    if not MenuDefaults then return nil end
    local created = ApiFactory.new({ defaults = MenuDefaults, colors = MenuColors,
        configDirectory = Environment.SenseMenuConfigDirectory })
    if type(created) ~= "table" then return nil end
    Api = created
    if type(existingApi) == "table" and not existingApi.Destroyed
        and type(existingApi.State) == "table" then
        for key, value in pairs(existingApi.Defaults or {}) do
            if not Api:Has(key) then Api:Register(key, value) end
        end
        for key, value in pairs(existingApi.State) do
            if Api:Has(key) then Api:Set(key, value) end
        end
        for key, value in pairs(existingApi.Colors or {}) do Api:SetColor(key, value) end
    end
end
for key, value in pairs({ show_personalization = false, menu_tint_strength = 0,
    target_hud_scale = 1 }) do
    if not Api:Has(key) then Api:Register(key, value) end
end
do
    local targetScale = math.clamp(tonumber(Api:Get("target_hud_scale")) or 1, 0.75, 1.5)
    Api:Set("target_hud_scale", targetScale)
    -- Older live API objects can survive a hot reload. Keep their carried state
    -- inside the new HUD limit even when their old Set implementation is reused.
    if Api:Get("target_hud_scale") ~= targetScale then Api.State.target_hud_scale = targetScale end
end
-- Utility popouts should only open after an explicit click in this session.
for _, key in ipairs({ "show_configs", "show_personalization" }) do
    if Api:Has(key) and Api:Get(key) ~= false then Api:Set(key, false) end
end
for key, entry in pairs({
    menu_surface_color = { Color3.fromRGB(62, 51, 68), { mode = "Solid" } },
    animation_color = { Color3.fromRGB(61, 54, 64), {
        mode = "Horizontal", secondary = Color3.fromRGB(62, 51, 68),
    } },
    checkbox_color = { Color3.fromRGB(62, 51, 68), {
        mode = "Horizontal", secondary = Color3.fromRGB(48, 39, 51),
    } },
    slider_color = { Color3.fromRGB(63, 48, 69), {
        mode = "Vertical", secondary = Color3.fromRGB(44, 37, 43),
    } },
    menu_window_color = { Color3.fromRGB(15, 15, 17), { mode = "Solid" } },
    menu_panel_color = { Color3.fromRGB(11, 13, 13), { mode = "Solid" } },
    menu_panel_alt_color = { Color3.fromRGB(19, 21, 23), { mode = "Solid" } },
    menu_field_color = { Color3.fromRGB(15, 17, 17), { mode = "Solid" } },
    menu_field_top_color = { Color3.fromRGB(27, 29, 29), { mode = "Solid" } },
    menu_hover_color = { Color3.fromRGB(30, 32, 32), { mode = "Solid" } },
    menu_border_color = { Color3.fromRGB(29, 31, 31), { mode = "Solid" } },
    menu_bevel_color = { Color3.fromRGB(68, 64, 70), { mode = "Solid" } },
    menu_bevel_inner_color = { Color3.fromRGB(39, 32, 42), { mode = "Solid" } },
    menu_text_color = { Color3.fromRGB(244, 246, 245), { mode = "Solid" } },
    menu_dim_color = { Color3.fromRGB(131, 133, 133), { mode = "Solid" } },
    window_rail_color = { Color3.fromRGB(68, 64, 70), {
        mode = "Horizontal", secondary = Color3.fromRGB(39, 32, 42),
    } },
    tab_rail_color = { Color3.fromRGB(46, 42, 50), {
        mode = "Horizontal", secondary = Color3.fromRGB(20, 18, 24),
    } },
    section_rail_color = { Color3.fromRGB(39, 32, 42), {
        mode = "Horizontal", secondary = Color3.fromRGB(46, 42, 50),
    } },
}) do
    if not Api:GetColor(key) then
        Api:RegisterColor(key, entry[1], 1, entry[2])
    end
end
local S, C = Api.State, Api.Colors
local Menu = { Api = Api, State = S, Colors = C, Connections = {}, ColorSwatches = {},
    Open = true, Destroyed = false }
Environment.__SenseLuaMenu = Menu
Environment.SenseMenuApi = Api

local mouseReleased = false
local mouseBindingName = "SenseLuaMenuMouse"

local function release_mouse_for_menu()
    mouseReleased = true
    UserInputService.MouseBehavior = Enum.MouseBehavior.Default
    UserInputService.MouseIconEnabled = true
end

local function restore_game_mouse()
    if not mouseReleased then return end
    mouseReleased = false
    -- A menu can be loaded while Roblox temporarily has the cursor locked
    -- (camera drag, first person, Shift Lock, or a previous menu instance).
    -- Restoring that captured value can leave the cursor permanently centered.
    -- Release it here and let Roblox's camera controller request a fresh lock
    -- on its next update only when the current game state actually needs one.
    UserInputService.MouseBehavior = Enum.MouseBehavior.Default
    UserInputService.MouseIconEnabled = true
end

pcall(function()
    RunService:BindToRenderStep(mouseBindingName, Enum.RenderPriority.Last.Value + 10, function()
        if not Menu.Destroyed and Menu.Open then release_mouse_for_menu() end
    end)
end)

local T = {
    window = Color3.fromRGB(15, 15, 17), panel = Color3.fromRGB(11, 13, 13),
    panelAlt = Color3.fromRGB(19, 21, 23), field = Color3.fromRGB(15, 17, 17),
    fieldTop = Color3.fromRGB(27, 29, 29), hover = Color3.fromRGB(30, 32, 32),
    border = Color3.fromRGB(29, 31, 31), borderDark = Color3.fromRGB(0, 1, 3),
    bevel = Color3.fromRGB(68, 64, 70), bevelInner = Color3.fromRGB(39, 32, 42),
    text = Color3.fromRGB(244, 246, 245), dim = Color3.fromRGB(131, 133, 133),
    disabled = Color3.fromRGB(59, 56, 63),
}
local baseTheme = {}
for key, value in pairs(T) do baseTheme[key] = value end
local surfaceThemeKeys = { "window", "panel", "panelAlt", "field", "fieldTop", "hover",
    "border", "bevel", "bevelInner" }
local paletteColorKeys = {
    window = "menu_window_color", panel = "menu_panel_color",
    panelAlt = "menu_panel_alt_color", field = "menu_field_color",
    fieldTop = "menu_field_top_color", hover = "menu_hover_color",
    border = "menu_border_color", bevel = "menu_bevel_color",
    bevelInner = "menu_bevel_inner_color", text = "menu_text_color",
    dim = "menu_dim_color",
}
local paletteApiKeys = {}
for _, apiKey in pairs(paletteColorKeys) do paletteApiKeys[apiKey] = true end
local apply_menu_tint

local function themed_surface(base, tint, strength)
    local hue, saturation = tint:ToHSV()
    local _, _, brightness = base:ToHSV()
    local colored = Color3.fromHSV(hue, saturation, brightness)
    return base:Lerp(colored, strength)
end

local function conn(signal, callback)
    local connection = signal:Connect(callback)
    table.insert(Menu.Connections, connection)
    return connection
end
local function prune_connections()
    for i = #Menu.Connections, 1, -1 do
        if not Menu.Connections[i].Connected then table.remove(Menu.Connections, i) end
    end
end

local function new(class, parent, properties)
    local object = Instance.new(class)
    for key, value in pairs(properties or {}) do object[key] = value end
    object.Parent = parent
    return object
end

local function px(x, y) return UDim2.fromOffset(x, y) end
local function fill(x, y) return UDim2.new(1, x or 0, 1, y or 0) end
local function animation_duration(speed)
    -- Sense clamps a zero animation speed to 0.1 after applying the speed divisor.
    return math.clamp(12.6 / math.max(speed or S.section_fade_speed, 0.3), 0.08, 42)
end
local function tween(object, properties, speed)
    if Menu.Destroyed or not S.animations then
        for key, value in pairs(properties) do object[key] = value end
        return
    end
    local duration = animation_duration(speed)
    TweenService:Create(object, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), properties):Play()
end

local function stroke(parent, color, thickness)
    return new("UIStroke", parent, { Color = color or T.borderDark, Thickness = thickness or 1,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
end

local function gradient(parent, top, bottom, rotation, preserveBase)
    if not preserveBase then parent.BackgroundColor3 = Color3.new(1, 1, 1) end
    return new("UIGradient", parent, { Color = ColorSequence.new(top, bottom), Rotation = rotation or 90 })
end

local chromeSurfaces = { window = {}, tabs = {}, sections = {} }
local chromeColorKeys = {
    window = { "window_rail_color", "window_rail_color_secondary" },
    tabs = { "tab_rail_color", "tab_rail_color_secondary" },
    sections = { "section_rail_color", "section_rail_color_secondary" },
}
local function register_chrome_surface(object, group)
    local keys = chromeColorKeys[group]
    if not keys then return object end
    object.BackgroundColor3 = C[keys[1]]
    local effect = object:FindFirstChildOfClass("UIGradient")
        or gradient(object, C[keys[1]], C[keys[2]], 0)
    effect.Color = ColorSequence.new(C[keys[1]], C[keys[2]])
    chromeSurfaces[group][#chromeSurfaces[group] + 1] = { object = object, effect = effect }
    return object
end
local function refresh_chrome_colors(group)
    local groups = group and { group } or { "window", "tabs", "sections" }
    for _, groupName in ipairs(groups) do
        local entries, keys = chromeSurfaces[groupName], chromeColorKeys[groupName]
        for index = #entries, 1, -1 do
            local entry = entries[index]
            if not entry.object.Parent then
                table.remove(entries, index)
            else
                entry.object.BackgroundColor3 = C[keys[1]]
                entry.effect.Color = ColorSequence.new(C[keys[1]], C[keys[2]])
            end
        end
    end
end

local function frame(parent, x, y, w, h, color, name)
    return new("Frame", parent, { Name = name or "Frame", Position = px(x, y), Size = px(w, h),
        BackgroundColor3 = color or T.field, BorderSizePixel = 0 })
end

local function label(parent, value, x, y, w, h, color, size, align)
    return new("TextLabel", parent, { Name = "Label", Text = value, Position = px(x, y), Size = px(w, h),
        BackgroundTransparency = 1, BorderSizePixel = 0, Font = Enum.Font.Arial,
        TextSize = size or 13, TextColor3 = color or T.text,
        TextXAlignment = align or Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center, TextTruncate = Enum.TextTruncate.AtEnd })
end

local function button(parent, text, x, y, w, h, bright)
    local b = new("TextButton", parent, { Name = "Button", Text = text, Position = px(x, y), Size = px(w, h),
        AutoButtonColor = false, BackgroundColor3 = T.fieldTop, BorderSizePixel = 0,
        Font = Enum.Font.Arial, TextSize = h <= 12 and 10 or 13,
        TextColor3 = bright and T.text or T.dim, TextTruncate = Enum.TextTruncate.AtEnd,
        ClipsDescendants = true })
    -- The native control surface runs from field_top to field at its lower edge.
    gradient(b, Color3.new(1, 1, 1), Color3.fromRGB(142, 149, 149), 90, true)
    local outline = stroke(b, T.borderDark)
    conn(b.MouseEnter, function()
        tween(b, { BackgroundColor3 = T.hover, TextColor3 = T.text }, 22)
        tween(outline, { Color = C.accent:Lerp(T.borderDark, 0.55) }, 22)
    end)
    conn(b.MouseLeave, function()
        tween(b, { BackgroundColor3 = T.fieldTop,
            TextColor3 = bright and T.text or T.dim }, 22)
        tween(outline, { Color = T.borderDark }, 22)
    end)
    return b
end

local function combo_surface(parent, text, x, y, w, h)
    local control = new("TextButton", parent, { Name = "Dropdown", Text = "", Position = px(x, y),
        Size = px(w, h), AutoButtonColor = false, BackgroundColor3 = T.fieldTop,
        BorderSizePixel = 0 })
    gradient(control, T.fieldTop, T.field)
    local outline = stroke(control, T.borderDark)
    local soft = frame(control, 2, 2, w - 4, h - 4, C.accent, "HoverFill")
    soft.Size = UDim2.new(1, -4, 1, -4)
    soft.BackgroundTransparency = 1
    local top = frame(control, 1, 1, w - 2, 1, T.border, "TopHighlight")
    top.Size = UDim2.new(1, -2, 0, 1)
    local left = frame(control, 1, 1, 1, h - 2, T.border, "LeftHighlight")
    left.Size = UDim2.new(0, 1, 1, -2)
    local separator = frame(control, w - 2, 1, 1, h - 2,
        Color3.fromRGB(26, 28, 28), "ArrowSeparator")
    separator.Position = UDim2.new(1, -2, 0, 1)
    separator.Size = UDim2.new(0, 1, 1, -2)
    local caption = label(control, text, 4, 0, w - 18, h, T.text, 13)
    caption.Name = "SelectedValue"
    caption.Size = UDim2.new(1, -18, 1, 0)
    caption.ZIndex = 3
    local arrow = label(control, "▼", w - 13, 0, 12, h, T.text, 8,
        Enum.TextXAlignment.Center)
    arrow.Position = UDim2.new(1, -13, 0, 0)
    arrow.Size = UDim2.new(0, 12, 1, 0)
    arrow.ZIndex = 3
    local function hover(value)
        local active = control:GetAttribute("PopupOpen") == true
        tween(soft, { BackgroundTransparency = (value or active) and 1 - 58 / 255 or 1 },
            S.section_fade_speed)
        tween(outline, { Color = (value or active) and C.accent or T.borderDark,
            Transparency = (value or active) and 1 - 190 / 255 or 0 }, S.section_fade_speed)
    end
    conn(control.MouseEnter, function() hover(true) end)
    conn(control.MouseLeave, function() hover(false) end)
    return control, caption, arrow, hover
end

local sliderSurfaces = {}
local function slider_surface(track)
    local primary = C.slider_color or C.accent_secondary
    local secondary = C.slider_color_secondary or C.accent
    local leftTop, leftMiddle, leftBottom
    local middleTop, middleMiddle, middleBottom
    local rightTop, rightMiddle, rightBottom
    local leftHighlightStart, middleHighlight, rightHighlightEnd
    local capTop, capMiddle, capLower, capBottom
    local function calculate_palette()
        primary = C.slider_color or C.accent_secondary
        secondary = C.slider_color_secondary or C.accent
        middleTop = primary
        middleMiddle = primary:Lerp(secondary, 0.34)
        middleBottom = secondary
        leftTop = primary:Lerp(T.text, 0.12)
        leftMiddle = middleMiddle:Lerp(T.dim, 0.12)
        leftBottom = secondary:Lerp(T.window, 0.28)
        rightTop = primary:Lerp(T.dim, 0.18)
        rightMiddle = middleMiddle:Lerp(T.window, 0.12)
        rightBottom = secondary:Lerp(T.window, 0.18)
        leftHighlightStart = leftMiddle:Lerp(T.text, 0.08)
        middleHighlight = primary:Lerp(T.text, 0.06)
        rightHighlightEnd = rightMiddle:Lerp(T.text, 0.06)
        capTop, capMiddle = rightTop, rightMiddle
        capLower = rightMiddle:Lerp(rightBottom, 0.55)
        capBottom = rightBottom
    end
    calculate_palette()
    local fillBar = frame(track, 1, 1, 0, 8, Color3.new(1, 1, 1), "Fill")
    fillBar.ClipsDescendants = true
    fillBar.ZIndex = track.ZIndex + 1
    local body = gradient(fillBar, middleTop, middleBottom)
    body.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, middleTop),
        ColorSequenceKeypoint.new(0.55, middleMiddle),
        ColorSequenceKeypoint.new(1, middleBottom),
    })
    local left = frame(fillBar, 0, 0, 10, 8, T.window, "LeftRamp")
    left.BackgroundTransparency = 1
    left.ClipsDescendants = true
    left.ZIndex = fillBar.ZIndex + 1
    local right = frame(fillBar, 0, 0, 5, 8, T.window, "RightRamp")
    right.BackgroundTransparency = 1
    right.ClipsDescendants = true
    right.ZIndex = fillBar.ZIndex + 1
    local leftColumns, rightColumns = {}, {}
    local function ramp_column(parent, x, name)
        local pixel = frame(parent, x, 0, 1, 8, Color3.new(1, 1, 1), name)
        pixel.ZIndex = parent.ZIndex + 1
        return pixel, new("UIGradient", pixel, { Rotation = 90 })
    end
    for index = 1, 10 do
        local pixel, shading = ramp_column(left, index - 1, "LeftPixel" .. index)
        leftColumns[index] = { pixel = pixel, shading = shading }
    end
    for index = 1, 5 do
        local pixel, shading = ramp_column(right, index - 1, "RightPixel" .. index)
        rightColumns[index] = { pixel = pixel, shading = shading }
    end
    local highlight = frame(fillBar, 0, 1, 1, 1, middleHighlight, "Highlight")
    highlight.Size = UDim2.new(1, 0, 0, 1)
    highlight.ZIndex = fillBar.ZIndex + 2
    local leftHighlights, rightHighlights = {}, {}
    for index = 1, 10 do
        local pixel = frame(fillBar, index - 1, 1, 1, 1, T.window,
            "LeftHighlight" .. index)
        pixel.ZIndex = highlight.ZIndex + 1
        leftHighlights[index] = pixel
    end
    for index = 1, 5 do
        local pixel = frame(fillBar, 0, 1, 1, 1, T.window,
            "RightHighlight" .. index)
        pixel.ZIndex = highlight.ZIndex + 1
        rightHighlights[index] = pixel
    end
    local cap = frame(fillBar, 0, 0, 1, 8, Color3.new(1, 1, 1), "EndCap")
    cap.Position = UDim2.new(1, -1, 0, 0)
    cap.ZIndex = highlight.ZIndex + 2
    local capGradient = gradient(cap, capTop, capBottom)
    capGradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, capTop),
        ColorSequenceKeypoint.new(0.5, capMiddle),
        ColorSequenceKeypoint.new(0.75, capLower),
        ColorSequenceKeypoint.new(1, capBottom),
    })
    local previousLeft, previousRight = -1, -1
    local function fit_segments()
        local width = math.floor(fillBar.AbsoluteSize.X + 0.5)
        fillBar.Visible = width > 0
        local leftWidth = math.min(10, width)
        local rightWidth = math.min(5, math.max(0, width - leftWidth))
        left.Size = px(leftWidth, 8)
        left.Visible = leftWidth > 0
        right.Position = UDim2.new(1, -rightWidth, 0, 0)
        right.Size = px(rightWidth, 8)
        right.Visible = rightWidth > 0
        cap.Visible = width > 0
        if leftWidth ~= previousLeft then
            previousLeft = leftWidth
            for index, entry in ipairs(leftColumns) do
                entry.pixel.Visible = index <= leftWidth
                local mark = leftHighlights[index]
                mark.Visible = index <= leftWidth
                if index <= leftWidth then
                    local fraction = (index - 0.5) / leftWidth
                    entry.shading.Color = ColorSequence.new({
                        ColorSequenceKeypoint.new(0, leftTop:Lerp(middleTop, fraction)),
                        ColorSequenceKeypoint.new(0.55, leftMiddle:Lerp(middleMiddle, fraction)),
                        ColorSequenceKeypoint.new(1, leftBottom:Lerp(middleBottom, fraction)),
                    })
                    mark.BackgroundColor3 = leftHighlightStart:Lerp(middleHighlight, fraction)
                end
            end
        end
        if rightWidth ~= previousRight then
            previousRight = rightWidth
            for index, entry in ipairs(rightColumns) do
                entry.pixel.Visible = index <= rightWidth
                local mark = rightHighlights[index]
                mark.Visible = index <= rightWidth
                if index <= rightWidth then
                    local fraction = (index - 0.5) / rightWidth
                    entry.shading.Color = ColorSequence.new({
                        ColorSequenceKeypoint.new(0, middleTop:Lerp(rightTop, fraction)),
                        ColorSequenceKeypoint.new(0.55, middleMiddle:Lerp(rightMiddle, fraction)),
                        ColorSequenceKeypoint.new(1, middleBottom:Lerp(rightBottom, fraction)),
                    })
                    mark.BackgroundColor3 = middleHighlight:Lerp(rightHighlightEnd, fraction)
                end
            end
        end
        for index = 1, rightWidth do
            rightHighlights[index].Position = px(width - rightWidth + index - 1, 1)
        end
    end
    conn(fillBar:GetPropertyChangedSignal("AbsoluteSize"), fit_segments)
    fit_segments()
    local function repaint()
        calculate_palette()
        body.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, middleTop),
            ColorSequenceKeypoint.new(0.55, middleMiddle),
            ColorSequenceKeypoint.new(1, middleBottom),
        })
        highlight.BackgroundColor3 = middleHighlight
        capGradient.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, capTop),
            ColorSequenceKeypoint.new(0.5, capMiddle),
            ColorSequenceKeypoint.new(0.75, capLower),
            ColorSequenceKeypoint.new(1, capBottom),
        })
        previousLeft, previousRight = -1, -1
        fit_segments()
    end
    sliderSurfaces[#sliderSurfaces + 1] = { fill = fillBar, repaint = repaint }
    for _, edge in ipairs({
        { "BorderTop", UDim2.fromOffset(0, 0), UDim2.new(1, 0, 0, 1) },
        { "BorderBottom", UDim2.new(0, 0, 1, -1), UDim2.new(1, 0, 0, 1) },
        { "BorderLeft", UDim2.fromOffset(0, 0), UDim2.new(0, 1, 1, 0) },
        { "BorderRight", UDim2.new(1, -1, 0, 0), UDim2.new(0, 1, 1, 0) },
    }) do
        local line = frame(track, 0, 0, 1, 1, T.borderDark, edge[1])
        line.Position = edge[2]
        line.Size = edge[3]
        line.ZIndex = track.ZIndex + 4
    end
    return fillBar
end

local function refresh_slider_colors()
    for index = #sliderSurfaces, 1, -1 do
        local entry = sliderSurfaces[index]
        if not entry.fill.Parent then
            table.remove(sliderSurfaces, index)
        else
            entry.repaint()
        end
    end
end

local function field_track_top_line(track)
    local line = frame(track, 1, 1, 1, 1, T.border, "TopHighlight")
    line.Size = UDim2.new(1, -2, 0, 1)
    line.ZIndex = track.ZIndex + 1
end

local function layered(parent, x, y, w, h, name)
    local outer = frame(parent, x, y, w, h, T.window, name)
    stroke(outer, T.borderDark)
    for i, color in ipairs({ T.bevel, T.borderDark, T.border, T.panelAlt }) do
        local rail = frame(outer, i, i, w - i * 2, h - i * 2, color, "Rail" .. i)
        rail.ZIndex = outer.ZIndex + 1
    end
    local inner = frame(outer, 5, 5, w - 10, h - 10, T.window, "Inner")
    inner.ZIndex = outer.ZIndex + 5
    return outer, inner
end

local guiParent
pcall(function() if type(gethui) == "function" then guiParent = gethui() end end)
guiParent = guiParent or game:GetService("CoreGui")
local gui = new("ScreenGui", guiParent, { Name = "SenseLuaOverlay", ResetOnSpawn = false,
    IgnoreGuiInset = true, DisplayOrder = 1000, ZIndexBehavior = Enum.ZIndexBehavior.Sibling })
Menu.Gui = gui

local function same_color(first, second)
    return math.abs(first.R - second.R) < 0.0001
        and math.abs(first.G - second.G) < 0.0001
        and math.abs(first.B - second.B) < 0.0001
end

apply_menu_tint = function()
    local old, replacements = {}, {}
    local tint = C.menu_surface_color or C.accent_secondary
    local strength = math.clamp((tonumber(S.menu_tint_strength) or 0) / 100, 0, 1)
    for key in pairs(baseTheme) do old[key] = T[key] end
    for key, colorKey in pairs(paletteColorKeys) do
        T[key] = C[colorKey] or baseTheme[key]
    end
    T.borderDark = baseTheme.borderDark
    T.disabled = T.dim:Lerp(T.window, 0.58)
    for _, key in ipairs(surfaceThemeKeys) do
        local themed = T[key]
        T[key] = themed_surface(themed, tint, strength)
    end
    for key in pairs(baseTheme) do
        replacements[#replacements + 1] = { old[key], T[key] }
    end
    local function replace_color(color)
        for _, pair in ipairs(replacements) do
            if same_color(color, pair[1]) then return pair[2] end
        end
        return color
    end
    for _, object in ipairs(gui:GetDescendants()) do
        if object:IsA("GuiObject") then
            object.BackgroundColor3 = replace_color(object.BackgroundColor3)
        elseif object:IsA("UIStroke") then
            object.Color = replace_color(object.Color)
        elseif object:IsA("UIGradient") then
            local points, changed = {}, false
            for _, point in ipairs(object.Color.Keypoints) do
                local color = replace_color(point.Value)
                points[#points + 1] = ColorSequenceKeypoint.new(point.Time, color)
                changed = changed or not same_color(color, point.Value)
            end
            if changed then object.Color = ColorSequence.new(points) end
        end
    end
end

local viewport = Workspace.CurrentCamera and Workspace.CurrentCamera.ViewportSize or Vector2.new(1920, 1080)
local main = new("CanvasGroup", gui, { Name = "Main", Position = px(28, 70),
    Size = px(644, 668), BackgroundColor3 = T.window, BorderSizePixel = 0,
    GroupTransparency = 1, Visible = true, ZIndex = 3 })
stroke(main, T.borderDark)
Menu.Main = main
local haloLayers = {}
for i = 1, 18 do
    local layer = new("Frame", gui, { Name = "ShineHalo" .. i, Position = main.Position,
        Size = main.Size, BackgroundTransparency = 1, BorderSizePixel = 0,
        Visible = false, ZIndex = 1 })
    haloLayers[i] = { frame = layer, line = stroke(layer, C.shine_color) }
end

-- Port the twelve native DrawBevel inset rails, including their side gradients.
local bevelLayers = {
    C.window_rail_color, T.borderDark, Color3.fromRGB(29, 25, 33), Color3.fromRGB(28, 26, 30),
    Color3.fromRGB(27, 28, 29), Color3.fromRGB(27, 28, 30), T.borderDark,
    T.border, T.panelAlt, T.window, T.panel, T.window, T.borderDark, T.border,
}
for i, color in ipairs(bevelLayers) do
    local rail = frame(main, i, i, 644 - i * 2, 668 - i * 2, color, "Rail" .. i)
    if i == 1 then register_chrome_surface(rail, "window") end
    rail.ZIndex = 1
end
local content = frame(main, 15, 15, 614, 638, T.window, "Content")
content.ZIndex = 2
for offset = 3, 14 do
    local topColor, bottomColor
    if offset <= 6 then
        topColor = bevelLayers[offset]
        bottomColor = Color3.fromRGB(21, 19, 20)
    elseif offset == 7 or offset == 13 then
        topColor, bottomColor = T.borderDark, T.borderDark
    elseif offset == 8 or offset == 14 then
        topColor, bottomColor = Color3.fromRGB(31, 33, 33), Color3.fromRGB(31, 33, 33)
    else
        topColor, bottomColor = Color3.fromRGB(19, 21, 21), Color3.fromRGB(15, 15, 15)
    end
    for _, x in ipairs({ offset, 643 - offset }) do
        local side = frame(main, x, offset + 1, 1, 666 - offset * 2,
            topColor, "SideRail" .. offset)
        gradient(side, topColor, bottomColor)
        side.ZIndex = 3
    end
end
-- The native header and tab strip sit between two stepped, pixel-sized gutters.
local function gutter(x, y, w, h, color, name)
    local part = frame(main, x, y, w, h, color, name)
    part.ZIndex = 3
    return part
end
gutter(7, 29, 630, 4, Color3.fromRGB(26, 28, 28), "HeaderSpacer")
gutter(7, 33, 630, 1, T.borderDark, "HeaderSpacerBorder")
gutter(8, 34, 628, 1, Color3.fromRGB(30, 32, 34), "HeaderSpacerHighlight")
gutter(9, 35, 626, 4, T.panelAlt, "UpperTabGutter")
gradient(gutter(9, 63, 626, 4, T.panelAlt, "LowerTabGutter"),
    T.panelAlt, Color3.fromRGB(22, 22, 24))
gutter(13, 67, 618, 1, T.borderDark, "LowerTabBorder")
gutter(14, 68, 616, 1, Color3.fromRGB(30, 32, 34), "LowerTabHighlight")
gutter(14, 69, 616, 4, T.window, "LowerTabSpacer")
local header = frame(main, 7, 7, 630, 22, Color3.fromRGB(26, 28, 28), "Header")
header.ZIndex = 4
local movingGloss, glossSurfaces = {}, {}
local function gloss(parent, x, y, width, speed, lowerColor)
    local top = frame(parent, x, y, width, 1, Color3.new(1, 1, 1), "GlossTop")
    local animationColor = C.animation_color or C.accent
    local animationSecondary = C.animation_color_secondary or C.accent_secondary
    local topGradient = gradient(top, animationColor, animationSecondary, 0)
    top.ZIndex = 5
    local lower = frame(parent, x, y + 1, width, 1,
        lowerColor or Color3.fromRGB(46, 42, 50), "GlossLower")
    lower.ZIndex = 5
    local sheen = {}
    for index, alpha in ipairs({ { 0.16, 0.96 }, { 0.13, 0.74 } }) do
        local stripColor = animationSecondary:Lerp(T.text, 0.68)
        local strip = frame(parent, x, y + index - 1, 56, 1, stripColor, "MovingGloss" .. index)
        strip.ZIndex = 6
        local effect = gradient(strip, stripColor, stripColor, 0)
        effect.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1 - alpha[1]),
            NumberSequenceKeypoint.new(18 / 56, 1 - alpha[2]),
            NumberSequenceKeypoint.new(1, 1),
        })
        sheen[index] = strip
    end
    glossSurfaces[#glossSurfaces + 1] = { top = topGradient, strips = sheen }
    if speed then
        movingGloss[#movingGloss + 1] = { strips = sheen, x = x, width = width, speed = speed }
    end
end

local function refresh_gloss_colors()
    local primary = C.animation_color or C.accent
    local secondary = C.animation_color_secondary or C.accent_secondary
    local stripColor = secondary:Lerp(T.text, 0.68)
    for index = #glossSurfaces, 1, -1 do
        local entry = glossSurfaces[index]
        if not entry.top.Parent then
            table.remove(glossSurfaces, index)
        else
            entry.top.Color = ColorSequence.new(primary, secondary)
            for _, strip in ipairs(entry.strips) do
                if strip.Parent then
                    strip.BackgroundColor3 = stripColor
                    local effect = strip:FindFirstChildOfClass("UIGradient")
                    if effect then effect.Color = ColorSequence.new(stripColor, stripColor) end
                end
            end
        end
    end
end
for index, cell in ipairs({ { 0, 140, "" }, { 144, 340, "Sense" },
    { 488, 142, "build - release" } }) do
    local f = frame(header, cell[1], 0, cell[2], 22, T.fieldTop, "HeaderCell" .. index)
    gradient(f, T.hover, Color3.fromRGB(14, 16, 16))
    stroke(f, T.borderDark)
    f.ZIndex = 5
    local inset = frame(f, 1, 1, cell[2] - 2, 20, T.fieldTop, "InnerBorder")
    inset.BackgroundTransparency = 1
    stroke(inset, Color3.fromRGB(31, 33, 33))
    inset.ZIndex = 5
    local innerLine = frame(f, 1, 1, cell[2] - 2, 1,
        Color3.fromRGB(35, 30, 36), "InnerHighlight")
    innerLine.ZIndex = 5
    gloss(f, 2, 2, cell[2] - 4, function() return S.shine_speed end,
        Color3.fromRGB(42, 36, 45))
    label(f, cell[3], 0, 1, cell[2], 21, T.text, 13,
        Enum.TextXAlignment.Center).ZIndex = 7
end
for index, color in ipairs({
    Color3.fromRGB(26, 28, 30), Color3.fromRGB(27, 29, 31),
    Color3.fromRGB(27, 29, 31), Color3.fromRGB(28, 31, 32),
}) do
    frame(header, 139 + index, 0, 1, 22, color, "HeaderGapLeft" .. index).ZIndex = 5
end
for index, color in ipairs({
    Color3.fromRGB(26, 26, 26), Color3.fromRGB(26, 26, 26),
    Color3.fromRGB(31, 31, 31), Color3.fromRGB(33, 33, 33),
}) do
    frame(header, 483 + index, 0, 1, 22, color, "HeaderGapRight" .. index).ZIndex = 5
end
local iconPng = {
    skull = "iVBORw0KGgoAAAANSUhEUgAAABQAAAAUCAYAAACNiR0NAAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAAAJcEhZcwAADsMAAA7DAcdvqGQAAACsSURBVDhP7ZPbDYMwEARdAA3QQBpwHzRCKWkhNdAEfZnsOpMICR3cX34Y6eTXrG0ZUfa01uYtwGtoORR4kg2xg36OxInMJXaJxUha8S+xSywG1/JLzaCqfeKD+wNrHWIxeKYy5VsvLoZ2focwFaNg/yCZG9olFiNptJzBLrFzJD7IhNhBz6HAQvaA19DyKPR9p9kbUP3vcR8tj0IjG1S1k4u+D8i93c3N3ynlDUDuwaqF9Bm7AAAAAElFTkSuQmCC",
    rocket = "iVBORw0KGgoAAAANSUhEUgAAABQAAAAUCAYAAACNiR0NAAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAAAJcEhZcwAADsMAAA7DAcdvqGQAAACnSURBVDhP7ZJRDYQwEEQroAYwgAEMoAAjOMACFtCACVycmHJvy8AHKVzp3yW8ZNNud2ZoAHdHCKFfE2j8DMJG+Vf2s5XavEB03m6kGjbrBn1lpTYvEMNxgzM22+eskyzXIOqiM49Gtmsk/AkPHmW5B2GNvqHa6EyAppc8HwUnkeQ59j6pifooK6JxOQQeX539ouNy9kBW+ye9jsshpCWsVvvy8kc49wXFLVgBLWDu7gAAAABJRU5ErkJggg==",
    music = "iVBORw0KGgoAAAANSUhEUgAAABQAAAAUCAYAAACNiR0NAAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAAAJcEhZcwAADsMAAA7DAcdvqGQAAACvSURBVDhP7ZJhDYMwEIUrAAM1MAM1MAVTgIM6mIVZQAMm5gIx3d4jL80BKbkM/izhS17g7t69lIawRyklQj00fAwa+8DyDXpCb+1vkNWHdnaR1Yd2KjjpxBPjNeGZ2ZPVhwnh3UW1Z44EZpULTgtE/YBGaHIHwhzhTetAhrFn0agNA+SdWQX2alc0aiNfxQai7FC/1Ocn3zVqA+PIBUPS6HcQyovP0OJXubj4P0L4AlwMQLo+mmtpAAAAAElFTkSuQmCC",
}
local function decode_base64(source)
    if crypt and type(crypt.base64decode) == "function" then return crypt.base64decode(source) end
    local alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
    local values = {}
    for i = 1, #alphabet do values[alphabet:sub(i, i)] = i - 1 end
    local bytes, carry, bits = {}, 0, 0
    for i = 1, #source do
        local value = values[source:sub(i, i)]
        if value then
            carry = carry * 64 + value
            bits += 6
            if bits >= 8 then
                bits -= 8
                bytes[#bytes + 1] = string.char(math.floor(carry / 2 ^ bits) % 256)
                carry %= 2 ^ bits
            end
        end
    end
    return table.concat(bytes)
end
local function icon_asset(name)
    local ok, asset = pcall(function()
        if type(writefile) ~= "function" or type(getcustomasset) ~= "function" then return nil end
        if not isfolder("SenseLua") then makefolder("SenseLua") end
        if not isfolder("SenseLua/icons") then makefolder("SenseLua/icons") end
        local path = "SenseLua/icons/" .. name .. ".png"
        if not isfile(path) then writefile(path, decode_base64(iconPng[name])) end
        return getcustomasset(path)
    end)
    return ok and asset or nil
end
for index, name in ipairs({ "skull", "rocket", "music" }) do
    local imageId = icon_asset(name)
    if imageId then
        new("ImageLabel", header.HeaderCell1, { Name = name, Position = px(47 + (index - 1) * 20, 7),
            Size = px(15, 15), BackgroundTransparency = 1, Image = imageId,
            ScaleType = Enum.ScaleType.Fit })
    else
        label(header.HeaderCell1, ({ "☠", "➤", "♫" })[index],
            47 + (index - 1) * 20, 7, 15, 15, T.text, 12)
    end
end
local headerDragHit = new("TextButton", header, { Name = "HeaderDragHit", Text = "",
    Size = fill(), BackgroundTransparency = 1, BorderSizePixel = 0,
    AutoButtonColor = false, Active = true, ZIndex = 8 })
local tabStrip = frame(main, 14, 39, 616, 24, T.panelAlt, "Tabs")
tabStrip.ZIndex = 4
gradient(tabStrip, Color3.fromRGB(20, 22, 25), Color3.fromRGB(11, 16, 15))
local tabTopLine = register_chrome_surface(
    frame(tabStrip, 1, 3, 614, 1, C.tab_rail_color, "TabTopLine"), "tabs")
tabTopLine.ZIndex = 5
frame(tabStrip, 0, 0, 616, 1, T.borderDark, "TabBorderTop").ZIndex = 5
frame(tabStrip, 0, 23, 616, 1, T.borderDark, "TabBorderBottom").ZIndex = 5
gloss(tabStrip, 0, 1, 616, function() return 70 end)
local tabButtons = {}
local pages = {}
local externalSchemas = type(Environment.SenseMenuSchemas) == "table" and Environment.SenseMenuSchemas or nil
local tabNames = type(Environment.SenseMenuTabNames) == "table" and Environment.SenseMenuTabNames
    or { "Combat", "Visuals", "Exploits", "Settings" }
if #tabNames == 0 then tabNames = { "Combat" } end
local activeTab = S.active_tab

local pageArea = frame(main, 15, 73, 616, 570, T.window, "PageArea")
pageArea.BackgroundTransparency = 1
pageArea.ZIndex = 3

local popup
local popupArrow
local popupAnchor
local popupMotionConnection
local function close_popup()
    if popupArrow and popupArrow.Parent then tween(popupArrow, { Rotation = 0, TextColor3 = T.text }, S.menu_fade_speed) end
    popupArrow = nil
    if popupAnchor and popupAnchor.Parent then
        popupAnchor:SetAttribute("PopupOpen", false)
        local selectedValue = popupAnchor:FindFirstChild("SelectedValue")
        if selectedValue then tween(selectedValue, { TextColor3 = T.text }, S.menu_fade_speed) end
        local hoverFill = popupAnchor:FindFirstChild("HoverFill")
        if hoverFill then tween(hoverFill, { BackgroundTransparency = 1 }, S.section_fade_speed) end
        local outline = popupAnchor:FindFirstChildOfClass("UIStroke")
        if outline then tween(outline, { Color = T.borderDark, Transparency = 0 }, S.section_fade_speed) end
    end
    popupAnchor = nil
    if popupMotionConnection then popupMotionConnection:Disconnect(); popupMotionConnection = nil end
    if popup then popup:Destroy(); popup = nil end
    prune_connections()
end

local function root_space(absolute)
    -- gethui/CoreGui can apply a topbar inset even with IgnoreGuiInset.
    local offset = main.AbsolutePosition - Vector2.new(main.Position.X.Offset, main.Position.Y.Offset)
    return absolute - offset
end

local function popup_list(anchor, choices, selected, onClick, width, keepOpen, arrow)
    local ap = root_space(anchor.AbsolutePosition)
    local aw = anchor.AbsoluteSize.X
    close_popup()
    popupArrow = arrow
    popupAnchor = anchor
    anchor:SetAttribute("PopupOpen", true)
    local selectedValue = anchor:FindFirstChild("SelectedValue")
    if selectedValue then tween(selectedValue, { TextColor3 = C.accent }, S.menu_fade_speed) end
    if arrow then tween(arrow, { Rotation = 180, TextColor3 = C.accent_secondary }, S.menu_fade_speed) end
    local rowHeight = 20
    local height = math.min(#choices * (rowHeight + 1) + 11, 190)
    local view = Workspace.CurrentCamera and Workspace.CurrentCamera.ViewportSize or viewport
    local popupWidth = width or aw
    local targetX = math.clamp(ap.X, 4, math.max(4, view.X - popupWidth - 4))
    local below = ap.Y + anchor.AbsoluteSize.Y + 3
    local above = ap.Y - height - 3
    local opensAbove = below + height > view.Y - 4 and above >= 4
    local targetY = opensAbove and above or math.clamp(below, 4, math.max(4, view.Y - height - 4))
    popup = new("CanvasGroup", gui, { Name = "Popup", Position = px(targetX, targetY + (opensAbove and 6 or -6)),
        Size = px(popupWidth, height), BackgroundColor3 = T.panel, BorderSizePixel = 0,
        GroupTransparency = S.animations and 1 or 0, ZIndex = 100 })
    stroke(popup, T.border)
    local scroll = new("ScrollingFrame", popup, { Name = "Items", Position = px(6, 6),
        Size = UDim2.new(1, -12, 1, -12),
        BackgroundTransparency = 1, BorderSizePixel = 0,
        ScrollBarThickness = 5, ScrollBarImageColor3 = C.accent_secondary,
        CanvasSize = UDim2.fromOffset(0, #choices * (rowHeight + 1) - 1), ZIndex = 100 })
    tween(popup, { Position = px(targetX, targetY), GroupTransparency = 0 }, S.menu_fade_speed)
    for index, item in ipairs(choices) do
        local isSelected = type(selected) == "function" and selected(item) or selected == item
        local itemButton = new("TextButton", scroll, { Name = "Item" .. index, Text = "",
            Position = px(0, (index - 1) * (rowHeight + 1)), Size = px((width or aw) - 12, rowHeight),
            BackgroundTransparency = 1, BorderSizePixel = 0, AutoButtonColor = false })
        itemButton.ZIndex = 101
        local hover = frame(itemButton, 0, 0, (width or aw) - 12, rowHeight, C.accent, "HoverFill")
        hover.BackgroundTransparency = 1
        hover.ZIndex = 101
        local caption = label(itemButton, item, 5, 0, (width or aw) - 22, rowHeight,
            isSelected and C.accent_secondary or T.dim, 13)
        caption.ZIndex = 102
        conn(itemButton.MouseEnter, function()
            tween(hover, { BackgroundTransparency = 1 - 58 / 255 }, S.section_fade_speed)
            if not (type(selected) == "function" and selected(item) or selected == item) then
                tween(caption, { TextColor3 = T.dim:Lerp(C.accent, 0.35) }, S.section_fade_speed)
            end
        end)
        conn(itemButton.MouseLeave, function()
            tween(hover, { BackgroundTransparency = 1 }, S.section_fade_speed)
            local active = type(selected) == "function" and selected(item) or selected == item
            tween(caption, { TextColor3 = active and C.accent_secondary or T.dim }, S.section_fade_speed)
        end)
        conn(itemButton.MouseButton1Click, function()
            onClick(item)
            if keepOpen then
                local active = type(selected) == "function" and selected(item) or selected == item
                tween(caption, { TextColor3 = active and C.accent_secondary or T.dim }, S.section_fade_speed)
            else
                close_popup()
            end
        end)
    end
end
conn(UserInputService.InputBegan, function(input)
    if not popup or (input.UserInputType ~= Enum.UserInputType.MouseButton1
        and input.UserInputType ~= Enum.UserInputType.Touch) then return end
    local m = input.Position
    if popupAnchor and popupAnchor.Parent then
        local anchorPosition, anchorSize = popupAnchor.AbsolutePosition, popupAnchor.AbsoluteSize
        if m.X >= anchorPosition.X and m.Y >= anchorPosition.Y
            and m.X <= anchorPosition.X + anchorSize.X
            and m.Y <= anchorPosition.Y + anchorSize.Y then
            return
        end
    end
    local p, sz = popup.AbsolutePosition, popup.AbsoluteSize
    if m.X < p.X or m.Y < p.Y or m.X > p.X + sz.X or m.Y > p.Y + sz.Y then close_popup() end
end)

local dragSlider
local dragPicker
local captureButton
local function short_key(key)
    local names = { MouseButton1 = "m1", MouseButton2 = "m2", MouseButton3 = "m3",
        MouseButton4 = "m4", MouseButton5 = "m5", LeftShift = "lshift",
        RightShift = "rshift", LeftControl = "lctrl", RightControl = "rctrl",
        LeftAlt = "lalt", RightAlt = "ralt", Backspace = "bksp",
        PageUp = "pgup", PageDown = "pgdn", None = "-" }
    return names[key] or string.lower(tostring(key or "-"))
end
conn(UserInputService.InputChanged, function(input)
    if input.UserInputType ~= Enum.UserInputType.MouseMovement and
        input.UserInputType ~= Enum.UserInputType.Touch then return end
    if dragSlider then dragSlider(input.Position.X) end
    if dragPicker then dragPicker(input.Position) end
end)
conn(UserInputService.InputEnded, function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragSlider = nil
        dragPicker = nil
    end
end)
conn(UserInputService.InputBegan, function(input, processed)
    if captureButton then
        local key = input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode.Name
            or input.UserInputType.Name
        if key == "Escape" or key == "Backspace" then key = "None" end
        Api:Set(captureButton.key, key)
        if captureButton.update then captureButton.update(key)
        elseif captureButton.button.Parent then captureButton.button.Text = short_key(key) end
        captureButton = nil
        return
    end
    if processed then return end
    if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode.Name == S.menu_key then
        Menu:SetOpen(not Menu.Open)
    end
end)

local function make_draggable(target, handle, condition, followers)
    local dragging, start, origin, followerOrigins
    conn(handle.InputBegan, function(input)
        if condition and not condition() then return end
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            start = input.Position
            origin = target.Position
            followerOrigins = {}
            local linked = type(followers) == "function" and followers() or followers
            for _, follower in ipairs(type(linked) == "table" and linked or {}) do
                if follower and follower.Parent then
                    followerOrigins[#followerOrigins + 1] = {
                        object = follower, position = follower.Position,
                    }
                end
            end
        end
    end)
    conn(UserInputService.InputChanged, function(input)
        if not dragging then return end
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            local d = input.Position - start
            target.Position = UDim2.new(origin.X.Scale, origin.X.Offset + d.X,
                origin.Y.Scale, origin.Y.Offset + d.Y)
            for _, entry in ipairs(followerOrigins or {}) do
                if entry.object.Parent then
                    entry.object.Position = UDim2.new(entry.position.X.Scale,
                        entry.position.X.Offset + d.X, entry.position.Y.Scale,
                        entry.position.Y.Offset + d.Y)
                end
            end
        end
    end)
    conn(UserInputService.InputEnded, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
            followerOrigins = nil
        end
    end)
end
local config
local personalization
make_draggable(main, headerDragHit, nil, function()
    local linked = {}
    if config then linked[#linked + 1] = config end
    if personalization then linked[#linked + 1] = personalization end
    return linked
end)

local function panel(parent, title, x, y, w, h)
    local shell = frame(parent, x, y, w, h, T.panelAlt, title)
    gradient(shell, T.panelAlt, T.panel)
    stroke(shell, T.borderDark)
    local inner = frame(shell, 1, 1, w - 2, h - 2, T.panelAlt, "InnerBorder")
    inner.BackgroundTransparency = 1
    stroke(inner, T.border)
    local top = frame(shell, 1, 1, w - 2, 17, T.panelAlt, "Title")
    label(top, title, 4, 1, w - 10, 16, T.dim, 13)
    local sectionRail = register_chrome_surface(
        frame(shell, 1, 1, w - 2, 1, C.section_rail_color, "TitleInnerHighlight"), "sections")
    sectionRail.ZIndex = 4
    gloss(shell, 3, 2, w - 6, function() return S.shine_speed end)
    local body = new("ScrollingFrame", shell, { Name = "Body", Position = px(6, 18),
        Size = px(w - 12, h - 18), BackgroundTransparency = 1, BorderSizePixel = 0,
        ScrollBarThickness = 6, ScrollBarImageColor3 = C.accent_secondary,
        AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.fromOffset(0, 0) })
    new("UIListLayout", body, { Padding = UDim.new(0, 0), SortOrder = Enum.SortOrder.LayoutOrder })
    return shell, body
end

local refreshCurrent
local refreshWindows
local menuSetDepth = 0
local function set(key, value, rerender)
    menuSetDepth += 1
    local ok = Api:Set(key, value)
    menuSetDepth -= 1
    if ok then
        if rerender then task.defer(refreshCurrent) end
        task.defer(refreshWindows)
    end
end

local function row(body, height, name)
    return new("Frame", body, { Name = name or "Row", Size = UDim2.new(1, 0, 0, height),
        BackgroundTransparency = 1, BorderSizePixel = 0 })
end

local function paint_swatch(swatch, key)
    local surface = swatch:FindFirstChild("Preview") or swatch
    local old = surface:FindFirstChildOfClass("UIGradient")
    if old then old:Destroy() end
    surface.BackgroundColor3 = C[key]
    surface.BackgroundTransparency = 1 - (Api.ColorAlpha[key] or 1)
    local options = Api.ColorOptions[key]
    if options and options.mode ~= "Solid" then
        local grad = gradient(surface, C[key], C[key .. "_secondary"] or C[key],
            options.mode == "Vertical" and 90 or options.angle)
        grad.Offset = Vector2.new(0, 0)
    end
end

local function register_color_swatch(swatch, key, secondKey)
    for _, watchedKey in ipairs({ key, secondKey or key .. "_secondary" }) do
        local swatches = Menu.ColorSwatches[watchedKey]
        if not swatches then
            swatches = setmetatable({}, { __mode = "k" })
            Menu.ColorSwatches[watchedKey] = swatches
        end
        swatches[swatch] = true
    end
end

local function refresh_color_swatches(key)
    local swatches = Menu.ColorSwatches[key]
    if not swatches then return end
    for swatch in pairs(swatches) do
        if swatch.Parent then
            paint_swatch(swatch, swatch:GetAttribute("ColorKey") or key)
        else
            swatches[swatch] = nil
        end
    end
end

local function color_popup(anchor, colorKey, secondKey, advanced)
    if popup and popupAnchor == anchor then
        close_popup()
        return
    end
    close_popup()
    popupAnchor = anchor
    anchor:SetAttribute("PopupOpen", true)
    local ap = root_space(anchor.AbsolutePosition)
    secondKey = secondKey or colorKey .. "_secondary"
    local w, h = advanced and 410 or 232, advanced and 420 or 188
    local x = math.clamp(ap.X + (advanced and 17 or 0), 4, math.max(4, viewport.X - w - 4))
    local y = math.clamp(ap.Y + (advanced and -2 or 13), 4, math.max(4, viewport.Y - h - 4))
    popup = frame(gui, x, y, w, h, T.panel, advanced and "AdvancedColorPopup" or "BasicColorPopup")
    popup.ZIndex = 100
    stroke(popup, T.border)
    local selectedKey = colorKey
    local refreshPreview
    local function refresh_anchor_swatch()
        if not anchor.Parent then return end
        local swatch = anchor.Name == "ColorSwatch" and anchor
            or anchor.Parent:FindFirstChild("ColorSwatch")
        if swatch then paint_swatch(swatch, colorKey) end
    end
    local pickerY = advanced and 51 or 6
    local pickerW, pickerH = w - 12, advanced and 208 or h - 12
    local picker = frame(popup, 6, pickerY, pickerW, pickerH, T.field, "Picker")
    picker.ZIndex = 101
    local planeW = pickerW - 34
    local plane = frame(picker, 0, 0, planeW, pickerH, Color3.fromHSV(0, 1, 1), "SVPlane")
    plane.ZIndex = 102
    stroke(plane, T.bevelInner)
    local white = frame(plane, 0, 0, planeW, pickerH, Color3.new(1, 1, 1), "WhiteBlend")
    white.ZIndex = 103
    local wg = gradient(white, Color3.new(1, 1, 1), Color3.new(1, 1, 1), 0)
    wg.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) })
    local black = frame(plane, 0, 0, planeW, pickerH, Color3.new(0, 0, 0), "BlackBlend")
    black.ZIndex = 104
    local bg = gradient(black, Color3.new(1, 1, 1), Color3.new(1, 1, 1), 90, true)
    bg.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0) })
    local planeHit = new("TextButton", plane, { Name = "PickSV", Size = fill(), Text = "",
        BackgroundTransparency = 1, ZIndex = 106 })
    local planeMarker = frame(plane, 0, 0, 8, 8, T.text, "Marker")
    planeMarker.ZIndex = 105
    new("UICorner", planeMarker, { CornerRadius = UDim.new(1, 0) })
    stroke(planeMarker, T.borderDark, 2)
    local hue = frame(picker, planeW + 4, 0, 13, pickerH, T.text, "Hue")
    hue.ZIndex = 102
    stroke(hue, T.bevelInner)
    new("UIGradient", hue, { Rotation = 90, Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromHSV(0, 1, 1)),
        ColorSequenceKeypoint.new(1 / 6, Color3.fromHSV(1 / 6, 1, 1)),
        ColorSequenceKeypoint.new(2 / 6, Color3.fromHSV(2 / 6, 1, 1)),
        ColorSequenceKeypoint.new(3 / 6, Color3.fromHSV(3 / 6, 1, 1)),
        ColorSequenceKeypoint.new(4 / 6, Color3.fromHSV(4 / 6, 1, 1)),
        ColorSequenceKeypoint.new(5 / 6, Color3.fromHSV(5 / 6, 1, 1)),
        ColorSequenceKeypoint.new(1, Color3.fromHSV(0, 1, 1)),
    }) })
    local hueMarker = frame(picker, planeW + 3, 0, 15, 3, T.text, "HueMarker")
    hueMarker.ZIndex = 104
    stroke(hueMarker, T.borderDark)
    local hueHit = new("TextButton", picker, { Name = "PickHue", Position = px(planeW + 4, 0),
        Size = px(13, pickerH), Text = "", BackgroundTransparency = 1, ZIndex = 106 })
    local alphaBar = frame(picker, planeW + 21, 0, 13, pickerH, T.fieldTop, "Alpha")
    alphaBar.ZIndex = 102
    stroke(alphaBar, T.bevelInner)
    local alphaGradient = new("UIGradient", alphaBar, { Rotation = 90,
        Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) }) })
    local alphaMarker = frame(picker, planeW + 20, 0, 15, 3, T.text, "AlphaMarker")
    alphaMarker.ZIndex = 104
    stroke(alphaMarker, T.borderDark)
    local alphaHit = new("TextButton", picker, { Name = "PickAlpha", Position = px(planeW + 21, 0),
        Size = px(13, pickerH), Text = "", BackgroundTransparency = 1, ZIndex = 106 })
    local hueValue, saturation, brightness = C[selectedKey]:ToHSV()
    local function refresh_picker()
        if not picker.Parent then return end
        local hueNow, saturationNow, brightnessNow = C[selectedKey]:ToHSV()
        if saturationNow > 0.0001 then hueValue = hueNow end
        saturation, brightness = saturationNow, brightnessNow
        plane.BackgroundColor3 = Color3.fromHSV(hueValue, 1, 1)
        alphaBar.BackgroundColor3 = C[selectedKey]
        planeMarker.Position = UDim2.new(saturation, -4, 1 - brightness, -4)
        hueMarker.Position = px(planeW + 3, math.floor(hueValue * (pickerH - 2)))
        alphaMarker.Position = px(planeW + 20, math.floor((1 - (Api.ColorAlpha[selectedKey] or 1)) * (pickerH - 2)))
    end
    local function picker_input(hit, change)
        conn(hit.InputBegan, function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragPicker = change
                change(input.Position)
            end
        end)
    end
    picker_input(planeHit, function(position)
        if not picker.Parent then dragPicker = nil; return end
        local p, sz = plane.AbsolutePosition, plane.AbsoluteSize
        saturation = math.clamp((position.X - p.X) / sz.X, 0, 1)
        brightness = 1 - math.clamp((position.Y - p.Y) / sz.Y, 0, 1)
        Api:SetColor(selectedKey, Color3.fromHSV(hueValue, saturation, brightness))
        refresh_picker()
        refresh_anchor_swatch()
        if refreshPreview then refreshPreview() end
    end)
    picker_input(hueHit, function(position)
        if not picker.Parent then dragPicker = nil; return end
        local p, sz = hueHit.AbsolutePosition, hueHit.AbsoluteSize
        hueValue = math.clamp((position.Y - p.Y) / sz.Y, 0, 1)
        Api:SetColor(selectedKey, Color3.fromHSV(hueValue, saturation, brightness))
        refresh_picker()
        refresh_anchor_swatch()
        if refreshPreview then refreshPreview() end
    end)
    picker_input(alphaHit, function(position)
        if not picker.Parent then dragPicker = nil; return end
        local p, sz = alphaHit.AbsolutePosition, alphaHit.AbsoluteSize
        Api:SetColorAlpha(selectedKey, 1 - math.clamp((position.Y - p.Y) / sz.Y, 0, 1))
        refresh_picker()
        refresh_anchor_swatch()
    end)
    refresh_picker()
    if not advanced then return end

    local title = label(popup, "Advanced color & gradient", 6, 5, 398, 18, T.dim, 12)
    title.ZIndex = 101
    local separator = frame(popup, 6, 23, 398, 1, T.border, "TitleRule")
    separator.ZIndex = 101
    for index, key in ipairs({ colorKey, secondKey }) do
        local xButton = 6 + (index - 1) * 201
        local endpoint = button(popup, index == 1 and "Primary" or "Secondary",
            xButton, 27, 197, 20, true)
        endpoint.Name = index == 1 and "Primary" or "Secondary"
        endpoint.ZIndex = 101
        conn(endpoint.MouseButton1Click, function()
            selectedKey = key
            refresh_picker()
        end)
    end
    local options = Api.ColorOptions[colorKey]
    label(popup, "Gradient mode", 6, 261, 398, 14, T.text, 12)
    local mode = button(popup, options.mode, 6, 275, 398, 16, true)
    mode.Name = "GradientMode"
    conn(mode.MouseButton1Click, function()
        popup_list(mode, { "Solid", "Horizontal", "Vertical", "Radial" }, options.mode, function(choice)
            Api:SetColorOption(colorKey, "mode", choice)
            refresh_anchor_swatch()
            task.defer(function() if anchor.Parent then color_popup(anchor, colorKey, secondKey, true) end end)
        end, 398)
    end)
    local function option_slider(field, caption, minValue, maxValue, yPos)
        local captionLabel = label(popup, caption, 6, yPos, 200, 14, T.text, 12)
        captionLabel.ZIndex = 101
        local valueLabel = label(popup, "", 210, yPos, 194, 14, T.text, 11, Enum.TextXAlignment.Right)
        valueLabel.ZIndex = 101
        local track = frame(popup, 6, yPos + 15, 398, 10, T.fieldTop, field)
        track.ZIndex = 101
        track.ClipsDescendants = true
        gradient(track, T.fieldTop, T.field)
        field_track_top_line(track)
        local bar = slider_surface(track)
        bar.ZIndex = 102
        local function redraw()
            local value = options[field]
            local fraction = math.clamp((value - minValue) / (maxValue - minValue), 0, 1)
            local trackWidth = track.AbsoluteSize.X
            local fillWidth = fraction > 0 and math.max(1,
                math.floor(math.min(fraction * trackWidth, trackWidth - 1) - 0.5)) or 0
            bar.Size = px(fillWidth, 8)
            valueLabel.Text = field == "angle" and string.format("%.0f deg", value)
                or field == "midpoint" and string.format("%.2f", value)
                or string.format("%.0f%%", value)
        end
        conn(track:GetPropertyChangedSignal("AbsoluteSize"), redraw)
        redraw()
        local hit = new("TextButton", track, { Name = "SliderHit", Text = "", Size = fill(),
            BackgroundTransparency = 1, ZIndex = 103 })
        conn(hit.InputBegan, function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                local function move(x)
                    if not track.Parent then dragSlider = nil; return end
                    local fraction = math.clamp((x - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
                    Api:SetColorOption(colorKey, field, minValue + fraction * (maxValue - minValue))
                    redraw()
                    if refreshPreview then refreshPreview() end
                    refresh_anchor_swatch()
                end
                dragSlider = move
                move(input.Position.X)
            end
        end)
    end
    option_slider("angle", "Angle", 0, 360, 294)
    option_slider("midpoint", "Midpoint", 0.05, 0.95, 321)
    option_slider("speed", "Motion", -100, 100, 348)
    local preview = frame(popup, 6, 377, 398, 17, T.field, "GradientPreview")
    preview.ZIndex = 101
    stroke(preview, T.bevelInner)
    preview.ClipsDescendants = true
    for y = 0, 1 do
        for x = 0, 49 do
            if (x + y) % 2 == 0 then
                local checker = frame(preview, x * 8, y * 8, 8, 8,
                    Color3.fromRGB(85, 85, 85), "Checker")
                checker.ZIndex = 102
            end
        end
    end
    local previewCells = {}
    for rowIndex = 0, 3 do
        for columnIndex = 0, 31 do
            local cell = new("Frame", preview, { Name = "Sample", BackgroundColor3 = C[colorKey],
                BorderSizePixel = 0, Position = UDim2.new(columnIndex / 32, 0, rowIndex / 4, 0),
                Size = UDim2.new(1 / 32, 0, 1 / 4, 0), ZIndex = 103 })
            previewCells[#previewCells + 1] = cell
        end
    end
    local function gradient_position(u, v)
        if options.mode == "Radial" then
            local dx, dy = (u - 0.5) * 2, (v - 0.5) * 2
            return math.clamp(math.sqrt(dx * dx + dy * dy), 0, 1)
        end
        local angle = math.rad(options.angle + (options.mode == "Vertical" and 90 or 0))
        local directionX, directionY = math.cos(angle), math.sin(angle)
        local extent = math.max(0.0001, math.abs(directionX) + math.abs(directionY))
        return math.clamp(0.5 + ((u - 0.5) * directionX + (v - 0.5) * directionY) / extent, 0, 1)
    end
    refreshPreview = function()
        if not preview.Parent then return end
        local primary, secondary = C[colorKey], C[secondKey]
        local primaryAlpha = Api.ColorAlpha[colorKey] or 1
        local secondaryAlpha = Api.ColorAlpha[secondKey] or 1
        for index, cell in ipairs(previewCells) do
            local columnIndex = (index - 1) % 32
            local rowIndex = math.floor((index - 1) / 32)
            local position = 0
            if options.mode ~= "Solid" then
                position = gradient_position((columnIndex + 0.5) / 32, (rowIndex + 0.5) / 4)
                if math.abs(options.speed) > 0.001 then
                    position = (position + os.clock() * options.speed * 0.01) % 2
                    if position > 1 then position = 2 - position end
                end
                local midpoint = math.clamp(options.midpoint, 0.001, 0.999)
                position = position < midpoint and 0.5 * position / midpoint
                    or 0.5 + 0.5 * (position - midpoint) / (1 - midpoint)
            end
            cell.BackgroundColor3 = primary:Lerp(secondary, position)
            cell.BackgroundTransparency = 1 - (primaryAlpha + (secondaryAlpha - primaryAlpha) * position)
        end
    end
    refreshPreview()
    local lastPreview = 0
    popupMotionConnection = conn(RunService.RenderStepped, function()
        if options.speed == 0 or not preview.Parent then return end
        local now = os.clock()
        if now - lastPreview >= 1 / 30 then
            lastPreview = now
            refreshPreview()
        end
    end)
    local swap = button(popup, "Swap endpoints", 6, 398, 197, 16, true)
    local preset = button(popup, "Accent preset", 207, 398, 197, 16, true)
    swap.Name, preset.Name = "SwapEndpoints", "AccentPreset"
    conn(swap.MouseButton1Click, function()
        local first, second = C[colorKey], C[secondKey]
        local firstAlpha, secondAlpha = Api.ColorAlpha[colorKey], Api.ColorAlpha[secondKey]
        Api:SetColor(colorKey, second)
        Api:SetColor(secondKey, first)
        Api:SetColorAlpha(colorKey, secondAlpha)
        Api:SetColorAlpha(secondKey, firstAlpha)
        refresh_picker()
        refreshPreview()
        refresh_anchor_swatch()
    end)
    conn(preset.MouseButton1Click, function()
        Api:SetColor(colorKey, C.accent)
        Api:SetColor(secondKey, C.accent_secondary)
        Api:SetColorAlpha(colorKey, 1)
        Api:SetColorAlpha(secondKey, 1)
        Api:SetColorOption(colorKey, "mode", "Horizontal")
        refresh_picker()
        refreshPreview()
        refresh_anchor_swatch()
    end)
end

local function add_color_controls(parent, colorKey, secondKey, allowAdvanced)
    allowAdvanced = allowAdvanced ~= false
    local swatch = new("TextButton", parent, { Name = "ColorSwatch", Text = "",
        Position = px(0, 2), Size = px(22, 10), AutoButtonColor = false,
        BackgroundColor3 = T.field, BorderSizePixel = 0 })
    swatch.Position = UDim2.new(1, allowAdvanced and -38 or -23, 0, 2)
    swatch:SetAttribute("ColorKey", colorKey)
    local swatchOutline = stroke(swatch, allowAdvanced and T.border or T.borderDark)
    local checker = frame(swatch, 1, 1, 20, 8, Color3.fromRGB(34, 36, 36), "Checkerboard")
    checker.ClipsDescendants = true
    for index = 0, 9 do
        local alternate = (index + math.floor(index / 5)) % 2 == 0
        local cell = frame(checker, (index % 5) * 4, math.floor(index / 5) * 4,
            4, 4, alternate and Color3.fromRGB(77, 79, 79) or Color3.fromRGB(38, 40, 40), "Cell")
        cell.ZIndex = checker.ZIndex
    end
    local preview = frame(swatch, 1, 1, 20, 8, C[colorKey], "Preview")
    preview.ZIndex = checker.ZIndex + 1
    conn(swatch.MouseEnter, function()
        tween(swatchOutline, { Color = C.accent_secondary }, S.section_fade_speed)
    end)
    conn(swatch.MouseLeave, function()
        tween(swatchOutline, { Color = allowAdvanced and T.border or T.borderDark },
            S.section_fade_speed)
    end)
    register_color_swatch(swatch, colorKey, secondKey)
    paint_swatch(swatch, colorKey)
    conn(swatch.MouseButton1Click, function() color_popup(swatch, colorKey, secondKey, false) end)
    if not allowAdvanced then return end
    local plus = new("TextButton", parent, { Name = "AdvancedColor", Text = "",
        Position = px(0, 2), Size = px(13, 10), AutoButtonColor = false,
        BackgroundColor3 = T.field, BorderSizePixel = 0 })
    plus.Position = UDim2.new(1, -14, 0, 2)
    local plusOutline = stroke(plus, T.border)
    local horizontal = frame(plus, 3, 4, 7, 1, T.dim, "Horizontal")
    local vertical = frame(plus, 6, 1, 1, 7, T.dim, "Vertical")
    horizontal.ZIndex, vertical.ZIndex = plus.ZIndex + 1, plus.ZIndex + 1
    conn(plus.MouseEnter, function()
        tween(plusOutline, { Color = C.accent }, S.section_fade_speed)
        tween(horizontal, { BackgroundColor3 = T.text }, S.section_fade_speed)
        tween(vertical, { BackgroundColor3 = T.text }, S.section_fade_speed)
    end)
    conn(plus.MouseLeave, function()
        tween(plusOutline, { Color = T.border }, S.section_fade_speed)
        tween(horizontal, { BackgroundColor3 = T.dim }, S.section_fade_speed)
        tween(vertical, { BackgroundColor3 = T.dim }, S.section_fade_speed)
    end)
    conn(plus.MouseButton1Click, function() color_popup(plus, colorKey, secondKey, true) end)
end

local function toggle_surface(parent, key, enabled)
    local check = new("TextButton", parent, { Name = key, Text = "", Position = px(2, 3),
        Size = px(10, 10), AutoButtonColor = false, BackgroundColor3 = T.fieldTop,
        BorderSizePixel = 0, Active = true })
    gradient(check, T.fieldTop, T.field)
    stroke(check, T.borderDark)
    local top = frame(check, 1, 1, 8, 1, T.border, "TopHighlight")
    top.ZIndex = check.ZIndex + 1
    local checkboxTop = C.checkbox_color or C.accent_secondary
    local checkboxBottom = C.checkbox_color_secondary or C.accent
    local checkFill = frame(check, 1, 1, 8, 8, checkboxTop, "CheckFill")
    checkFill.ZIndex = check.ZIndex + 2
    gradient(checkFill, checkboxTop, checkboxBottom)
    checkFill.BackgroundTransparency = enabled and 0 or 1
    return check, checkFill
end

local function refresh_checkbox_colors()
    local top = C.checkbox_color or C.accent_secondary
    local bottom = C.checkbox_color_secondary or C.accent
    for _, object in ipairs(gui:GetDescendants()) do
        if object:IsA("GuiObject") and object.Name == "CheckFill" then
            object.BackgroundColor3 = top
            local effect = object:FindFirstChildOfClass("UIGradient")
            if effect then effect.Color = ColorSequence.new(top, bottom) end
        end
    end
end

local function add_control(body, spec)
    local kind, text, key = spec[1], spec[2], spec[3]
    if spec.when and not spec.when(S) then return end
    if kind == "sep" then
        local r = row(body, 7, "Separator")
        local line = frame(r, 0, 3, 1, 1, T.border)
        line.Size = UDim2.new(1, 0, 0, 1)
    elseif kind == "section" then
        local r = row(body, 15, text)
        label(r, text, 1, 0, 270, 15, T.text, 13)
    elseif kind == "text" then
        local r = row(body, 14, text)
        label(r, text, 1, 0, 270, 14, T.dim, 11)
    elseif kind == "toggle" or kind == "keytoggle" then
        local r = row(body, 16, key)
        local check, checkFill = toggle_surface(r, key, S[key])
        local hit = new("TextButton", r, { Name = "Hit", Text = text, Position = px(16, 1),
            Size = UDim2.new(1, -16, 0, 14), BackgroundTransparency = 1, BorderSizePixel = 0,
            Font = Enum.Font.Arial, TextColor3 = S[key] and T.text or T.dim, TextSize = 13,
            TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd })
        local function hover_text(hovered)
            tween(hit, { TextColor3 = (hovered or S[key]) and T.text or T.dim }, 20)
        end
        conn(hit.MouseEnter, function() hover_text(true) end)
        conn(hit.MouseLeave, function() hover_text(false) end)
        conn(check.MouseEnter, function() hover_text(true) end)
        conn(check.MouseLeave, function() hover_text(false) end)
        conn(hit.MouseButton1Click, function()
            set(key, not S[key], spec.rebuild)
            tween(checkFill, { BackgroundTransparency = S[key] and 0 or 1 }, S.scroll_speed)
            tween(hit, { TextColor3 = S[key] and T.text or T.dim }, 20)
        end)
        conn(check.MouseButton1Click, function()
            set(key, not S[key], spec.rebuild)
            tween(checkFill, { BackgroundTransparency = S[key] and 0 or 1 }, S.scroll_speed)
            tween(hit, { TextColor3 = S[key] and T.text or T.dim }, 20)
        end)
        if kind == "keytoggle" then
            local keyText = short_key(S[spec.bind])
            local keyWidth = math.clamp(#keyText * 7 + 10, 38, 96)
            local keyButton = button(r, keyText, 0, 1, keyWidth, 14)
            keyButton.Name = "Keybind"
            local function update_key(value)
                if not keyButton.Parent then return end
                local valueText = short_key(value)
                local width = math.clamp(#valueText * 7 + 10, 38, 96)
                keyButton.Text = valueText
                keyButton.Position = UDim2.new(1, -width - 2, 0, 1)
                keyButton.Size = px(width, 14)
                hit.Size = UDim2.new(1, -21 - width, 0, 14)
            end
            update_key(S[spec.bind])
            conn(keyButton.MouseButton1Click, function()
                keyButton.Text = "..."
                captureButton = { key = spec.bind, button = keyButton, update = update_key }
            end)
            conn(keyButton.MouseButton2Click, function()
                popup_list(keyButton, { "Toggle", "Hold", "Always" }, S[spec.mode], function(choice)
                    set(spec.mode, choice)
                end, 76)
            end)
        elseif spec.color then
            add_color_controls(r, spec.color, nil, spec.advanced)
            hit.Size = UDim2.new(1, spec.advanced == false and -39 or -56, 0, 14)
        end
    elseif kind == "slider" then
        local r = row(body, 27, key)
        label(r, text, 0, 0, 273, 13, T.text, 13)
        local track = frame(r, 0, 15, 1, 10, T.fieldTop, "Track")
        track.Size = UDim2.new(1, 0, 0, 10)
        track.ClipsDescendants = true
        gradient(track, T.fieldTop, T.field)
        field_track_top_line(track)
        local fillBar = slider_surface(track)
        local display = label(r, "", 0, 14, 1, 12, T.text, 12, Enum.TextXAlignment.Center)
        display.Size = UDim2.new(1, 0, 0, 12)
        display.TextTransparency = 1
        display.ZIndex = track.ZIndex + 5
        local min, max = spec.min, spec.max
        local initialized = false
        local function fmt(value)
            if spec.suffix then
                local precision = spec.precision or 0
                return string.format("%." .. precision .. "f%s", value, spec.suffix)
            end
            return tostring(value)
        end
        local function redraw()
            local alpha = math.clamp((S[key] - min) / (max - min), 0, 1)
            local trackWidth = track.AbsoluteSize.X
            local fillWidth = alpha > 0 and math.max(1,
                math.floor(math.min(alpha * trackWidth, trackWidth - 1) - 0.5)) or 0
            local size = px(fillWidth, 8)
            if initialized then tween(fillBar, { Size = size }, S.scroll_speed)
            else fillBar.Size = size; initialized = true end
            display.Text = fmt(S[key])
        end
        conn(track:GetPropertyChangedSignal("AbsoluteSize"), redraw)
        redraw()
        local hit = new("TextButton", track, { Name = "SliderHit", Text = "", Size = fill(),
            BackgroundTransparency = 1, BorderSizePixel = 0 })
        hit.ZIndex = display.ZIndex + 1
        conn(hit.MouseEnter, function() tween(display, { TextTransparency = 0 }, 20) end)
        conn(hit.MouseLeave, function()
            if not dragSlider then tween(display, { TextTransparency = 1 }, 20) end
        end)
        local function move(x)
            if not track.Parent then dragSlider = nil; return end
            local alpha = math.clamp((x - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
            local value = min + (max - min) * alpha
            local step = spec.step or (spec.precision and 0.01 or 1)
            value = math.clamp(math.floor(value / step + 0.5) * step, min, max)
            set(key, value)
            redraw()
        end
        conn(hit.InputBegan, function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragSlider = move
                move(input.Position.X)
            end
        end)
    elseif kind == "combo" or kind == "multi" then
        local r = row(body, 33, key)
        label(r, text, 1, 2, 272, 13, T.text, 13)
        if spec.color then
            add_color_controls(r, spec.color, nil, spec.advanced)
        end
        local function current()
            if kind == "combo" then return tostring(S[key]) end
            local names = {}
            for _, choice in ipairs(spec.values) do if S[key][choice] then names[#names + 1] = choice end end
            return #names > 0 and table.concat(names, ", ") or "None"
        end
        local dropdown, display, arrow, hover = combo_surface(r, current(), 0, 15, 273, 16)
        dropdown.Size = UDim2.new(1, 0, 0, 16)
        conn(dropdown.MouseButton1Click, function()
            if popup and popupAnchor == dropdown then close_popup(); hover(false); return end
            popup_list(dropdown, spec.values,
                kind == "combo" and S[key] or function(choice) return S[key][choice] end,
                function(choice)
                if kind == "combo" then set(key, choice, spec.rebuild) else
                    local copy = table.clone(S[key]); copy[choice] = not copy[choice]
                    set(key, copy)
                end
                display.Text = current()
            end, nil, kind == "multi", arrow)
            hover(true)
        end)
    elseif kind == "button" then
        local r = row(body, 20, text)
        local b = button(r, text, 0, 1, 273, 16, true)
        b.Size = UDim2.new(1, 0, 0, 16)
        local armedUntil = 0
        local armToken = 0
        local function restore_button()
            if not b.Parent then return end
            b.Text = text
            tween(b, { TextColor3 = T.text }, S.section_fade_speed)
        end
        conn(b.MouseButton1Click, function()
            local now = os.clock()
            if spec.confirm and now > armedUntil then
                armedUntil = now + 1.8
                armToken += 1
                local token = armToken
                b.Text = spec.confirmText or "Click again to confirm"
                tween(b, { TextColor3 = C.accent_secondary }, S.section_fade_speed)
                task.delay(1.8, function()
                    if token == armToken and os.clock() >= armedUntil then restore_button() end
                end)
                return
            end
            armedUntil = 0
            armToken += 1
            restore_button()
            spec.action()
        end)
    elseif kind == "color" then
        local r = row(body, 16, key)
        label(r, text, 0, 1, 245, 14, T.dim, 13)
        add_color_controls(r, key, spec.secondary, spec.advanced)
    elseif kind == "input" then
        local r = row(body, 36, key)
        label(r, text, 0, 0, 273, 15, T.dim, 13)
        local box = new("TextBox", r, { Name = key, Position = px(0, 17), Size = UDim2.new(1, 0, 0, 17),
            BackgroundColor3 = T.fieldTop, BorderSizePixel = 0, ClearTextOnFocus = false,
            Text = S[key], Font = Enum.Font.Arial, TextSize = 11, TextColor3 = T.text,
            PlaceholderText = text })
        stroke(box, T.borderDark)
        conn(box.FocusLost, function() set(key, box.Text) end)
    end
end

local function control(kind, text, key, extra)
    local result = { kind, text, key }
    for k, v in pairs(extra or {}) do result[k] = v end
    return result
end
local function togg(text, key, extra) return control("toggle", text, key, extra) end
local function kt(text, key, bind, mode, extra)
    extra = extra or {}; extra.bind = bind; extra.mode = mode
    return control("keytoggle", text, key, extra)
end
local function sl(text, key, min, max, suffix, precision, extra)
    extra = extra or {}; extra.min = min; extra.max = max
    extra.suffix = suffix; extra.precision = precision
    return control("slider", text, key, extra)
end
local function cb(text, key, values, extra)
    extra = extra or {}; extra.values = values
    return control("combo", text, key, extra)
end
local function multi(text, key, values) return control("multi", text, key, { values = values }) end
local function sec(text) return control("section", text) end
local function sep() return control("sep") end
local bones = { "Head", "Torso", "Arms", "Legs" }
local origins = { "Mouse cursor", "Screen center" }
local fonts = { "Small Fonts", "ProggyTiny", "ProggyClean", "Tahoma", "Verdana", "Consolas", "Arial", "Poppins" }
local visibleIf = function(k) return function(s) return s[k] end end

local schemas = externalSchemas or {
    Combat = {
        { title = "Aimbot", x = 0, y = 0, h = 350, rows = {
            kt("Enabled", "aimbot_enabled", "aimbot_key", "aimbot_key_mode"),
            cb("Mode", "aimbot_mode", { "Camera", "Mouse" }), sec("Targeting"),
            multi("Allowed Bones", "aimbot_bones", bones),
            togg("Skip Knocked", "aimbot_skip_knocked", { when = visibleIf("dahood_detected") }),
            cb("FOV Origin", "aimbot_fov_origin", origins),
            togg("Team Check", "aimbot_team_check"), togg("Target Lock", "aimbot_target_lock"),
            togg("Draw FOV", "aimbot_draw_fov"), sl("FOV Size", "aimbot_fov", 5, 500, " px"),
            sl("Smoothing", "aimbot_smoothing", 0.1, 40, "", 1),
            sl("Deadzone", "aimbot_deadzone", 0, 30, " px", 1),
            sl("Max Step", "aimbot_max_step", 1, 150, " px"),
            sl("Reaction Delay", "aimbot_reaction", 0, 500, " ms"),
            sl("Max Distance", "aimbot_max_distance", 50, 5000, " studs"),
            togg("Prediction", "aimbot_prediction", { rebuild = true }),
            sl("Lead Time", "aimbot_prediction_time", 0, 0.3, " s", 2,
                { when = visibleIf("aimbot_prediction") }),
        } },
        { title = "Silent Aim", x = 0, y = 354, h = 413, rows = {
            kt("Enabled", "silent_enabled", "silent_key", "silent_key_mode"),
            togg("Team Check", "silent_team_check"), togg("Sticky Target", "silent_sticky"),
            togg("Random Hit Part", "silent_random_hitpart"),
            togg("Dynamic FOV", "silent_dynamic_fov", { rebuild = true }), sec("Targeting"),
            multi("Allowed Bones", "silent_bones", bones),
            togg("Skip Knocked", "silent_skip_knocked", { when = visibleIf("dahood_detected") }),
            togg("Skip Shielded", "rivals_skip_shielded", { when = visibleIf("rivals_detected") }),
            togg("Skip Deflecting", "rivals_skip_deflecting", { when = visibleIf("rivals_detected") }),
            cb("Target Priority", "silent_priority", { "Head priority", "Torso priority", "Closest bone" }),
            sl("Hit Chance", "silent_hit_chance", 0, 100, "%"),
            sl("Reaction Delay", "silent_reaction_ms", 0, 500, " ms"),
            sl("FOV Size", "silent_fov_size", 20, 500, " px"),
            sl("Max Distance", "silent_max_distance", 50, 5000, " studs"),
            togg("Draw FOV", "silent_draw_fov", { color = "fov_draw_color", advanced = false }),
            togg("Target HUD", "silent_target_marker"), sec("Raycast Feedback"),
            togg("Raycast Bullet Tracers", "raycast_tracers", { color = "raycast_tracer_color", rebuild = true }),
            togg("Impact Markers", "raycast_impact_markers", { when = visibleIf("raycast_tracers") }),
            togg("Allow Camera-Origin Rays", "raycast_camera_origins", { when = visibleIf("raycast_tracers") }),
            sl("Tracer Lifetime", "raycast_tracer_lifetime", 0.05, 5, " s", 2, { when = visibleIf("raycast_tracers") }),
            sl("Tracer Thickness", "raycast_tracer_thickness", 0.5, 6, " px", 1, { when = visibleIf("raycast_tracers") }),
            togg("Raycast Hit Damage", "raycast_hit_damage", { color = "raycast_damage_color", rebuild = true }),
            cb("Damage Font", "raycast_damage_font", { "Bungee Display", "Datdata", "Poppins", "Arial Bold", "Tahoma Bold" }, { when = visibleIf("raycast_hit_damage") }),
            sl("Damage Font Size", "raycast_damage_font_size", 12, 48, " px", nil, { when = visibleIf("raycast_hit_damage") }),
            sl("Damage Lifetime", "raycast_damage_lifetime", 0.25, 8, " s", 1, { when = visibleIf("raycast_hit_damage") }),
            togg("Hit Watermark", "raycast_hit_watermark", { when = visibleIf("raycast_hit_damage"), rebuild = true }),
            control("input", "Message: {name} and {damage}", "raycast_hit_watermark_text", { when = function(s) return s.raycast_hit_damage and s.raycast_hit_watermark end }),
            sl("Reference Distance", "silent_dynamic_reference", 25, 500, " studs", nil, { when = visibleIf("silent_dynamic_fov") }),
            sl("Minimum FOV Scale", "silent_dynamic_min_scale", 0.1, 1, "", 2, { when = visibleIf("silent_dynamic_fov") }),
        } },
        { title = "Triggerbot", x = 310, y = 0, h = 359, rows = {
            kt("Enabled", "trigger_enabled", "trigger_key", "trigger_key_mode"),
            togg("Internal Visibility", "trigger_internal_visibility"),
            togg("Use Silent FOV", "trigger_use_silent_fov"),
            togg("Team Check", "trigger_team_check"), sec("Targeting"),
            multi("Allowed Bones", "trigger_bones", bones),
            togg("Skip Knocked", "trigger_skip_knocked", { when = visibleIf("dahood_detected") }),
            cb("Ray Origin", "trigger_ray_origin", origins),
            cb("Priority", "trigger_priority", { "Closest to crosshair", "First ray hit", "Closest player" }),
            sl("Hit Chance", "trigger_hit_chance", 0, 100, "%"),
            sl("Hitbox Scale", "trigger_scale", 0.1, 1, "", 2),
            sl("Max Distance", "trigger_max_distance", 25, 5000, " studs"),
        } },
        { title = "Trigger Timing", x = 310, y = 363, h = 100, rows = {
            sl("Fire Delay", "trigger_delay", 0, 500, " ms"),
            sl("Button Hold", "trigger_click_duration", 1, 250, " ms"),
            sl("Shot Cooldown", "trigger_cooldown", 0, 500, " ms"),
        } },
    },
    Visuals = {
        { title = "ESP", x = 0, y = 0, h = 570, rows = {
            togg("Enabled", "esp"),
            cb("Box Style", "box_style", { "None", "Box", "Corner Box" }, { color = "box_color" }),
            togg("Box Fill", "box_fill", { color = "box_fill_color" }),
            togg("Box Outline", "box_outline", { color = "box_outline_color" }),
            togg("Health bar", "health", { color = "health_color", rebuild = true }),
            togg("Health-based color", "health_based_color", { when = visibleIf("health") }),
            togg("Health text", "health_text", { color = "health_text_color" }),
            togg("Armor Bar", "dahood_armor_bar", { color = "armor_color", when = visibleIf("dahood_detected") }),
            togg("Show Knocked", "dahood_show_knocked", { when = visibleIf("dahood_detected") }),
            togg("Skeleton", "skeleton", { color = "skeleton_color" }),
            togg("Name", "name", { color = "name_color" }),
            togg("Distance", "distance_text", { color = "distance_color" }),
            togg("Held item", "tool", { color = "held_item_color" }),
            togg("Flags", "esp_flags", { color = "flags_color" }),
            togg("Rig Flag", "rig_flag"), togg("Health Percent Flag", "health_percent_flag"),
            togg("Tracers", "tracers", { color = "tracer_color" }),
            togg("Head Dot", "center_dot", { color = "head_dot_color" }),
            togg("Team Check", "visual_team_check"),
        } },
        { title = "Appearance", x = 310, y = 0, h = 570, rows = {
            sl("Max Distance", "visual_max_distance", 100, 5000, " studs"),
            sl("Line Thickness", "visual_thickness", 1, 4, " px", 1),
            sl("Box Padding", "box_padding", 0, 12, " px"),
            cb("Name Source", "name_source", { "Username", "Display Name" }),
            cb("Distance Unit", "distance_unit", { "Meters", "Studs" }),
            cb("Health Bar Side", "health_side", { "Left", "Right" }),
            togg("Uppercase Held Item", "tool_uppercase"),
            togg("Text Outline", "text_outline", { color = "text_outline_color" }),
            sep(), sec("ESP Fonts"),
            togg("Use Same Font", "visual_shared_font", { rebuild = true }),
            cb("All ESP Text", "visual_shared_font_index", fonts, { when = visibleIf("visual_shared_font") }),
            cb("Name Font", "visual_name_font", fonts, { when = function(s) return not s.visual_shared_font end }),
            cb("Distance Font", "visual_distance_font", fonts, { when = function(s) return not s.visual_shared_font end }),
            cb("Held Item Font", "visual_tool_font", fonts, { when = function(s) return not s.visual_shared_font end }),
            cb("Health Text Font", "visual_health_font", fonts, { when = function(s) return not s.visual_shared_font end }),
            cb("Flags Font", "visual_flags_font", fonts, { when = function(s) return not s.visual_shared_font end }),
        } },
    },
    Exploits = {
        { title = "Movement", x = 0, y = 0, h = 570, rows = {
            kt("Walk Speed", "walk_speed_enabled", "walk_speed_key", "walk_speed_key_mode", { rebuild = true }),
            sl("Walk Speed", "walk_speed", 1, 2500, " studs/s", nil, { when = visibleIf("walk_speed_enabled") }),
            togg("Sprint Only", "walk_sprint_only", { when = visibleIf("walk_speed_enabled") }), sep(),
            kt("Fly", "fly_enabled", "fly_key", "fly_key_mode", { rebuild = true }),
            sl("Fly Speed", "fly_speed", 1, 4000, " studs/s", nil, { when = visibleIf("fly_enabled") }),
            sl("Vertical Speed", "fly_vertical_speed", 1, 4000, " studs/s", nil, { when = visibleIf("fly_enabled") }),
            togg("Move With View Pitch", "fly_camera_pitch", { when = visibleIf("fly_enabled") }),
            togg("Shift Boost", "fly_shift_boost", { when = visibleIf("fly_enabled"), rebuild = true }),
            sl("Boost Multiplier", "fly_boost_multiplier", 1, 10, "x", 1,
                { when = function(s) return s.fly_enabled and s.fly_shift_boost end }), sep(),
            kt("Orbit", "orbit_enabled", "orbit_key", "orbit_key_mode", { rebuild = true }),
            cb("Orbit Mode", "orbit_mode", { "Circle", "Vertical Wave", "Figure Eight" }, { when = visibleIf("orbit_enabled"), rebuild = true }),
            cb("Direction", "orbit_direction", { "Clockwise", "Counter-clockwise" }, { when = visibleIf("orbit_enabled") }),
            sl("Orbit Speed", "orbit_speed", 5, 1440, " deg/s", nil, { when = visibleIf("orbit_enabled") }),
            sl("Orbit Radius", "orbit_radius", 2, 100, " studs", 1, { when = visibleIf("orbit_enabled") }),
            sl("Orbit Height", "orbit_height", -50, 100, " studs", 1, { when = visibleIf("orbit_enabled") }),
            sl("Vertical Range", "orbit_vertical_range", 0, 50, " studs", 1,
                { when = function(s) return s.orbit_enabled and s.orbit_mode == "Vertical Wave" end }),
            sl("Orbit Target Range", "orbit_max_distance", 10, 1000, " studs", nil, { when = visibleIf("orbit_enabled") }),
            togg("Face Target", "orbit_face_target", { when = visibleIf("orbit_enabled") }),
            togg("Lock Orbit Target", "orbit_target_lock", { when = visibleIf("orbit_enabled") }),
            togg("Orbit Team Check", "orbit_team_check", { when = visibleIf("orbit_enabled") }),
            togg("Orbit Skip Knocked", "orbit_skip_knocked",
                { when = function(s) return s.orbit_enabled and s.dahood_detected end }),
            sep(),
            kt("Desync", "desync_enabled", "desync_key", "desync_key_mode", { rebuild = true }),
            cb("Desync Mode", "desync_mode", { "Freeze", "Pulse", "Anchor Echo (Hook)" }, { when = visibleIf("desync_enabled"), rebuild = true }),
            sl("Choke Time", "desync_choke_ms", 25, 2000, " ms", nil, { when = function(s) return s.desync_enabled and s.desync_mode == "Pulse" end }),
            sl("Release Time", "desync_release_ms", 10, 1000, " ms", nil, { when = function(s) return s.desync_enabled and s.desync_mode == "Pulse" end }),
            sl("Anchor Distance", "desync_anchor_distance", 2, 100, " studs", nil, { when = function(s) return s.desync_enabled and s.desync_mode == "Anchor Echo (Hook)" end }),
            sl("Maximum Hold", "desync_anchor_max_hold_ms", 100, 3000, " ms", nil, { when = function(s) return s.desync_enabled and s.desync_mode == "Anchor Echo (Hook)" end }),
            sl("Echo Window", "desync_release_ms", 10, 250, " ms", nil,
                { when = function(s) return s.desync_enabled and s.desync_mode == "Anchor Echo (Hook)" end }),
            control("sep", nil, nil, { when = visibleIf("desync_enabled") }),
            togg("Ghost Pose", "desync_ghost", { color = "desync_ghost_color", when = visibleIf("desync_enabled"), rebuild = true }),
            togg("Ghost Outline", "desync_ghost_outline", { when = function(s) return s.desync_enabled and s.desync_ghost end }),
            togg("Anchor Dot", "desync_anchor_dot", { when = visibleIf("desync_enabled") }),
            togg("Anchor Tether", "desync_anchor_tether", { when = visibleIf("desync_enabled") }),
        } },
        { title = "Rivals", x = 310, y = 0, h = 570, when = visibleIf("rivals_detected"), rows = {
            kt("Slide Boost", "rivals_slide_boost", "rivals_slide_key", "rivals_slide_key_mode", { rebuild = true }),
            sl("Slide Speed", "rivals_slide_speed", 25, 300, " studs/s", nil, { when = visibleIf("rivals_slide_boost") }),
            sep(), togg("No Flash", "rivals_no_flash"), togg("No Burn", "rivals_no_burn"),
        } },
    },
    Settings = {
        { title = "Appearance", x = 0, y = 0, h = 570, rows = {
            control("color", "Accent & gradient", "accent", { secondary = "accent_secondary" }),
            togg("Smooth animations", "animations"), sep(),
            control("button", "Configs", nil, { action = function() set("show_configs", not S.show_configs) end }),
            sep(), sec("Hit Notifications"),
            togg("Enabled", "hit_notifications_enabled", { rebuild = true }),
            sl("Duration", "hit_notifications_duration", 0.25, 15, " s", 1,
                { when = visibleIf("hit_notifications_enabled") }),
            sl("Maximum", "hit_notifications_max_count", 1, 20, "", nil,
                { when = visibleIf("hit_notifications_enabled") }),
            control("button", "Test Hit Notification", nil, { when = visibleIf("hit_notifications_enabled"),
                action = function()
                    Api:NotifyHit({ name = "Preview Target", damage = 42, headshot = true,
                        part = "Head", weapon = "Preview" })
                end }),
        } },
        { title = "Windows", x = 310, y = 0, h = 570, rows = {
            sec("Overlay"), togg("Streamproof", "overlay_streamproof"),
            togg("VSync", "overlay_vsync", { rebuild = true }),
            sl("FPS Cap", "overlay_fps", 30, 5000, " FPS", nil,
                { when = function(s) return not s.overlay_vsync end }), sep(),
            togg("Watermark", "show_watermark"), togg("Keybind list", "show_keybinds"),
            togg("Target HUD", "silent_target_marker", { rebuild = true }),
            sl("Target HUD Scale", "target_hud_scale", 0.75, 1.5, "x", 2,
                { when = visibleIf("silent_target_marker") }),
            togg("Config manager", "show_configs"),
            sep(), sec("Shine"),
            togg("Shine", "window_shine"), control("color", "Color", "shine_color"),
            sl("Speed", "shine_speed", 0, 140, ""), sl("Glow", "shine_glow", 0, 100, ""),
            sl("Width", "shine_width", 0, 100, ""), sl("Halo Size", "shine_halo_size", 0, 100, ""),
            sl("Halo Amount", "shine_halo_amount", 0, 100, ""), sep(),
            sl("Scroll Speed", "scroll_speed", 0, 100, ""),
            sl("Menu Fade Speed", "menu_fade_speed", 0, 100, ""),
            sl("Section Fade Speed", "section_fade_speed", 0, 100, ""),
            sl("Tab Fade Speed", "tab_fade_speed", 0, 100, ""),
            sl("Menu Glow", "menu_glow", 0, 100, ""), sl("Menu Blur", "menu_blur", 0, 100, ""),
        } },
    },
}

local tabWidth = 616 / #tabNames
for index, name in ipairs(tabNames) do
    local tabX = math.floor((index - 1) * tabWidth + 0.5)
    local nextX = math.floor(index * tabWidth + 0.5)
    local tab = new("TextButton", tabStrip, { Name = name, Text = name,
        Position = px(tabX, 0), Size = px(nextX - tabX, 24),
        BackgroundTransparency = 1, BorderSizePixel = 0, AutoButtonColor = false,
        Active = true, Font = Enum.Font.Arial, TextSize = 13,
        TextColor3 = T.dim, ZIndex = 6 })
    conn(tab.MouseEnter, function()
        tween(tab, { TextColor3 = S.active_tab == name and T.disabled or T.text }, S.tab_fade_speed)
    end)
    conn(tab.MouseLeave, function()
        tween(tab, { TextColor3 = S.active_tab == name and T.disabled or T.dim }, S.tab_fade_speed)
    end)
    if index > 1 then
        local divider = frame(tabStrip, tabX, 3, 1, 21, T.borderDark, "TabDivider")
        divider.ZIndex = 5
    end
    tabButtons[name] = tab
    conn(tab.MouseButton1Click, function() Menu:SelectTab(name) end)
end

local visibleKeys = {}
local function render_tab(name)
    close_popup()
    dragSlider = nil
    for _, child in ipairs(pageArea:GetChildren()) do child:Destroy() end
    prune_connections()
    local page = new("CanvasGroup", pageArea, { Name = name, Size = fill(),
        BackgroundTransparency = 1, GroupTransparency = S.animations and 1 or 0 })
    pages[name] = page
    local panelParent = page
    local pageHeights = Environment.SenseMenuPageHeights
    local canvasHeight = type(pageHeights) == "table" and tonumber(pageHeights[name])
    if externalSchemas or name == "Combat" then
        panelParent = new("ScrollingFrame", page, { Name = name .. "Scroll", Size = fill(),
            BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 6,
            ScrollBarImageColor3 = C.accent_secondary,
            CanvasSize = px(0, math.max(570, canvasHeight or (name == "Combat" and 771 or 570))) })
    end
    local specs = schemas[name] or {}
    local shownKeys = {}
    for _, section in ipairs(specs) do
        if not section.when or section.when(S) then
            local x = section.x == 0 and 4 or section.x
            local _, body = panel(panelParent, section.title, x, section.y, 301, section.h)
            for _, spec in ipairs(section.rows) do
                if not spec.when or spec.when(S) then
                    if spec[3] then shownKeys[spec[3]] = true end
                    if spec.bind then shownKeys[spec.bind] = true end
                    if spec.mode then shownKeys[spec.mode] = true end
                end
                add_control(body, spec)
            end
        end
    end
    visibleKeys = shownKeys
    tween(page, { GroupTransparency = 0 }, S.tab_fade_speed)
    for tabName, tab in pairs(tabButtons) do
        tween(tab, { TextColor3 = tabName == name and T.disabled or T.dim }, S.tab_fade_speed)
    end
end
refreshCurrent = function()
    if not Menu.Destroyed then render_tab(activeTab) end
end

function Menu:SelectTab(name)
    if not schemas[name] then return end
    self.TabTransition = (self.TabTransition or 0) + 1
    local token = self.TabTransition
    self.RequestedTab = name
    Api:Set("active_tab", name)
    for tabName, tab in pairs(tabButtons) do
        tween(tab, { TextColor3 = tabName == name and T.disabled or T.dim }, S.tab_fade_speed)
    end
    if activeTab == name then
        local current = pages[activeTab]
        if current and current.Parent then tween(current, { GroupTransparency = 0 }, S.tab_fade_speed) end
        self.RequestedTab = nil
        return
    end
    local previous = pages[activeTab]
    if not S.animations or not previous or not previous.Parent then
        activeTab = name
        self.RequestedTab = nil
        render_tab(name)
        return
    end
    tween(previous, { GroupTransparency = 1 }, S.tab_fade_speed)
    local duration = math.clamp(animation_duration(S.tab_fade_speed) * 0.786, 0.08, 35)
    task.delay(duration, function()
        if self.Destroyed or self.TabTransition ~= token then return end
        activeTab = name
        self.RequestedTab = nil
        render_tab(name)
    end)
end

function Menu:Refresh()
    if not self.Destroyed then refreshCurrent() end
end

local function detached(name, w, h, y, rightOffset)
    local group = new("CanvasGroup", gui, { Name = name,
        Position = UDim2.new(1, -(w + (rightOffset or 8)), 0, y), Size = px(w, h),
        BackgroundColor3 = T.window, BorderSizePixel = 0, GroupTransparency = 1, ZIndex = 10 })
    stroke(group, T.borderDark)
    local bevel = frame(group, 1, 1, w - 2, h - 2, T.window, "OuterBevel")
    bevel.BackgroundTransparency = 1
    stroke(bevel, T.bevel)
    local surface = frame(group, 2, 2, w - 4, h - 4, T.panel, "Surface")
    surface.Size = UDim2.new(1, -4, 1, -4)
    stroke(surface, T.borderDark)
    return group
end

local watermark = detached("Watermark", 116, 32, 44)
local watermarkField = frame(watermark, 7, 8, 102, 18, T.fieldTop)
gradient(watermarkField, T.fieldTop, T.field)
stroke(watermarkField, T.borderDark)
local watermarkSense = label(watermarkField, "Sense", 4, 0, 39, 18, T.text, 11)
local watermarkSlash = label(watermarkField, " / ", 42, 0, 12, 18, T.disabled, 11)
local watermarkRelease = label(watermarkField, "release", 53, 0, 45, 18, T.text, 11)
watermarkSense.Font, watermarkSlash.Font, watermarkRelease.Font = Enum.Font.ArialBold,
    Enum.Font.ArialBold, Enum.Font.ArialBold
for _, segment in ipairs({ watermarkSense, watermarkSlash, watermarkRelease }) do
    segment:SetAttribute("SenseFontTracking", 1.05)
    segment:SetAttribute("SenseFontBold", true)
end
make_draggable(watermark, watermarkField, function() return Menu.Open end)

local function titled(group, title, w, h)
    local bar = frame(group, 5, 4, w - 10, 22, T.fieldTop, "TitleBar")
    gradient(bar, T.fieldTop, T.field)
    stroke(bar, T.borderDark)
    local barInset = frame(bar, 1, 1, w - 12, 20, T.fieldTop, "InnerBorder")
    barInset.BackgroundTransparency = 1
    stroke(barInset, T.border)
    frame(bar, 2, 2, w - 14, 1, T.bevelInner, "TopHighlight")
    local accentLine = frame(bar, 1, 20, w - 12, 1, C.accent, "AccentLine")
    accentLine.BackgroundTransparency = 1 - 78 / 255
    label(bar, title, 0, 0, w - 10, 22, T.text, 12, Enum.TextXAlignment.Center)
    local field = frame(group, 7, 30, w - 14, h - 37, T.field, "Field")
    gradient(field, T.fieldTop, T.field)
    stroke(field, T.borderDark)
    local fieldInset = frame(field, 1, 1, w - 16, h - 39, T.field, "InnerBorder")
    fieldInset.BackgroundTransparency = 1
    stroke(fieldInset, T.border)
    return bar, field
end

local keybindHeight = S.rivals_detected and 136 or 120
local keybinds = detached("Keybinds", 190, keybindHeight, 322)
local keybindTitle, keyField = titled(keybinds, "Keybinds", 190, keybindHeight)
make_draggable(keybinds, keybindTitle, function() return Menu.Open end)
local function refresh_keybinds()
    for _, child in ipairs(keyField:GetChildren()) do
        if child:IsA("TextLabel") then child:Destroy() end
    end
    local rows = {}
    local configured = Menu.KeybindRows or Api.KeybindRows or Environment.SenseMenuKeybindRows
    if type(configured) == "table" and #configured > 0 then
        for _, item in ipairs(configured) do
            local key = tostring(S[item.keyFlag] or "None")
            local isMenuBind = item.keyFlag == "sense_bind_key_menu_keybind"
                or tostring(item.label):lower() == "menu keybind"
            if not isMenuBind and key ~= "None" and key ~= "NONE" and key ~= "Unknown" then
                rows[#rows + 1] = { item.label, item.stateFlag, item.keyFlag }
            end
        end
    else
        local defaults = { { "Silent Aim", "silent_enabled", "silent_key" },
            { "Triggerbot", "trigger_enabled", "trigger_key" },
            { "Walk Speed", "walk_speed_enabled", "walk_speed_key" },
            { "Fly", "fly_enabled", "fly_key" }, { "Desync", "desync_enabled", "desync_key" } }
        for _, item in ipairs(defaults) do rows[#rows + 1] = item end
        if S.rivals_detected then
            rows[#rows + 1] = { "Slide Boost", "rivals_slide_boost", "rivals_slide_key" }
        end
    end
    if #rows == 0 then
        label(keyField, "No binds assigned", 3, 1, 168, 15, T.dim, 11)
        return
    end
    local maximumRows = S.rivals_detected and 6 or 5
    for i = 1, math.min(#rows, maximumRows) do
        local item = rows[i]
        label(keyField, item[1], 3, 1 + (i - 1) * 16, 125, 15,
            (item[2] == nil or S[item[2]]) and T.text or T.dim, 11)
        label(keyField, short_key(item[4] or S[item[3]]), 126, 1 + (i - 1) * 16, 42, 15,
            T.dim, 11, Enum.TextXAlignment.Right)
    end
end

local target = detached("TargetHUD", 190, 84, 92)
target.AnchorPoint = Vector2.new(1, 0)
target.Position = UDim2.new(1, -8, 0, 92)
local targetTitle, targetField = titled(target, "Target", 190, 84)
local portrait = frame(targetField, 1, 2, 44, 44, T.fieldTop, "Portrait")
gradient(portrait, T.fieldTop, T.panel)
stroke(portrait, T.borderDark)
local avatar = new("ImageLabel", portrait, { Name = "Avatar", Position = px(2, 2), Size = px(40, 40),
    BackgroundTransparency = 1, Image = "", Visible = false })
local portraitText = label(portrait, "LOCK", 0, 0, 44, 28, C.accent_secondary, 10,
    Enum.TextXAlignment.Center)
local distanceStrip = frame(portrait, 2, 29, 40, 13, Color3.new(0, 0, 0), "DistanceStrip")
distanceStrip.BackgroundTransparency = 0.41
local distanceText = label(portrait, "-- st", 0, 29, 44, 13, T.dim, 9,
    Enum.TextXAlignment.Center)
local targetName = label(targetField, "", 47, -1, 128, 14, Color3.fromRGB(65, 103, 132), 12)
local targetPart = label(targetField, "", 47, 12, 128, 13, T.dim, 11)
local healthBack = frame(targetField, 47, 26, 128, 17, T.fieldTop, "Health")
stroke(healthBack, T.borderDark)
local healthFill = frame(healthBack, 1, 1, 126, 15, C.accent_secondary, "Fill")
gradient(healthFill, C.accent_secondary, C.accent)
local healthText = label(healthBack, "", 0, 0, 128, 17, T.text, 11,
    Enum.TextXAlignment.Center)
healthText:SetAttribute("SenseFontTracking", 1.25)
healthText:SetAttribute("SenseFontBold", true)
local targetBaseGeometry = {}
for _, object in ipairs(target:GetDescendants()) do
    local entry = { object = object }
    if object:IsA("GuiObject") then
        entry.position, entry.size = object.Position, object.Size
        if object:IsA("TextLabel") or object:IsA("TextButton") then
            entry.textSize = object.TextSize
        end
    elseif object:IsA("UIStroke") then
        entry.thickness = object.Thickness
    end
    targetBaseGeometry[#targetBaseGeometry + 1] = entry
end
local currentTargetScale = 1
local function scaled_offset(value, scale)
    return value >= 0 and math.floor(value * scale + 0.5)
        or math.ceil(value * scale - 0.5)
end
local function scale_target_hud(value)
    local scale = math.clamp(tonumber(value) or 1, 0.75, 1.5)
    if S.target_hud_scale ~= scale then S.target_hud_scale = scale end
    if math.abs(scale - currentTargetScale) < 0.001 then return end
    currentTargetScale = scale
    target.Size = px(scaled_offset(190, scale), scaled_offset(84, scale))
    for _, entry in ipairs(targetBaseGeometry) do
        local object = entry.object
        if object.Parent then
            if entry.position then
                object.Position = UDim2.new(entry.position.X.Scale,
                    scaled_offset(entry.position.X.Offset, scale), entry.position.Y.Scale,
                    scaled_offset(entry.position.Y.Offset, scale))
                object.Size = UDim2.new(entry.size.X.Scale,
                    scaled_offset(entry.size.X.Offset, scale), entry.size.Y.Scale,
                    scaled_offset(entry.size.Y.Offset, scale))
                if entry.textSize then
                    object.TextSize = math.max(1, entry.textSize * scale)
                    object:SetAttribute("SenseFontScale", scale)
                end
            elseif entry.thickness then
                object.Thickness = entry.thickness * scale
            end
        end
    end
end
local thumbnailUserId = 0
local function refresh_target()
    local data = Api.Target
    local preview = Menu.Open and not data.active
    targetTitle.Label.Text = Menu.Open and "Target - drag me" or "Target"
    targetName.Text = preview and "drag me" or data.name
    targetPart.Text = preview and "move target HUD" or data.part
    distanceText.Text = data.distance >= 0 and string.format("%.0f st", data.distance) or "-- st"
    local fraction = preview and 1 or (data.maxHealth > 0 and math.clamp(data.health / data.maxHealth, 0, 1) or 0)
    tween(healthFill, { Size = UDim2.new(fraction,
        scaled_offset(-2 * fraction, currentTargetScale), 0,
        scaled_offset(15, currentTargetScale)) }, 22)
    healthText.Text = preview and "drag me" or (data.maxHealth > 0 and
        string.format("%.0f/%.0f", data.health, data.maxHealth) or "health --")
    portraitText.Text = preview and "DRAG ME" or "LOCK"
    avatar.Visible = data.userId > 0 and data.active
    if data.userId > 0 and data.userId ~= thumbnailUserId then
        thumbnailUserId = data.userId
        task.spawn(function()
            local ok, url = pcall(Players.GetUserThumbnailAsync, Players, data.userId,
                Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size48x48)
            if ok and thumbnailUserId == data.userId and avatar.Parent then avatar.Image = url end
        end)
    end
end
make_draggable(target, targetTitle, function() return Menu.Open end)

config = detached("Config", 302, 340, math.max(8, viewport.Y - 341), 217)
do
    local view = Workspace.CurrentCamera and Workspace.CurrentCamera.ViewportSize or viewport
    local menuWidth, configWidth, gap = 644, 302, 7
    local combinedWidth = menuWidth + gap + configWidth
    local guiOffset = main.AbsolutePosition
        - Vector2.new(main.Position.X.Offset, main.Position.Y.Offset)
    local x = math.max(4, math.floor((view.X - combinedWidth) * 0.5 + 0.5))
    local y = math.max(4, math.floor((view.Y - 668) * 0.5 + 0.5))
    if combinedWidth > view.X - 8 then
        x = math.max(4, math.floor((view.X - menuWidth) * 0.5 + 0.5))
    end
    local configX = math.clamp(x + menuWidth + gap, 4,
        math.max(4, view.X - configWidth - 4))
    main.Position = px(x - guiOffset.X, y - guiOffset.Y)
    config.Position = px(configX - guiOffset.X, y - guiOffset.Y)
end
local configBar = frame(config, 8, 7, 286, 22, T.fieldTop, "TitleBar")
gradient(configBar, T.fieldTop, T.field)
stroke(configBar, T.borderDark)
local configBarInset = frame(configBar, 1, 1, 284, 20, T.fieldTop, "InnerBorder")
configBarInset.BackgroundTransparency = 1
stroke(configBarInset, T.border)
frame(configBar, 1, 1, 284, 1, T.bevelInner, "TopHighlight")
gloss(configBar, 3, 2, 280, function() return S.shine_speed end)
local configAccentLine = frame(configBar, 0, 21, 286, 1, C.accent, "AccentLine")
configAccentLine.BackgroundTransparency = 1 - 78 / 255
label(configBar, "Config", 0, 0, 286, 22, T.text, 12,
    Enum.TextXAlignment.Center).ZIndex = 7
local search = new("TextBox", config, { Name = "ConfigSearch", Position = px(13, 38), Size = px(276, 18),
    BackgroundColor3 = T.fieldTop, BorderSizePixel = 0, ClearTextOnFocus = false,
    PlaceholderText = "search or new config", Text = "", Font = Enum.Font.Arial,
    TextSize = 12, TextColor3 = T.text, PlaceholderColor3 = T.dim,
    TextXAlignment = Enum.TextXAlignment.Left })
stroke(search, T.borderDark)
field_track_top_line(search)
new("UIPadding", search, { PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 4) })
local configList = new("ScrollingFrame", config, { Name = "ConfigList", Position = px(13, 60), Size = px(276, 204),
    BackgroundColor3 = T.panelAlt, BorderSizePixel = 0, ScrollBarThickness = 5,
    ScrollBarImageColor3 = C.accent_secondary, AutomaticCanvasSize = Enum.AutomaticSize.Y,
    CanvasSize = px(0, 0) })
gradient(configList, T.panelAlt, T.panel)
stroke(configList, T.border)
new("UIListLayout", configList, { Padding = UDim.new(0, 1), SortOrder = Enum.SortOrder.Name })
new("UIPadding", configList, { PaddingLeft = UDim.new(0, 3), PaddingTop = UDim.new(0, 4),
    PaddingRight = UDim.new(0, 3), PaddingBottom = UDim.new(0, 4) })
local selectedConfig
local status = "ready"
local function refresh_configs()
    for _, child in ipairs(configList:GetChildren()) do if child:IsA("TextButton") or child:IsA("TextLabel") then child:Destroy() end end
    local query = string.lower(search.Text)
    local names = Api:ListConfigs()
    local count = 0
    for _, name in ipairs(names) do
        if query == "" or string.find(string.lower(name), query, 1, true) then
            count += 1
            local selected = selectedConfig == name
            local b = new("TextButton", configList, { Text = "", Size = UDim2.new(1, 0, 0, 16),
                BackgroundTransparency = 1, BorderSizePixel = 0, AutoButtonColor = false })
            b.Name = name
            local hover = frame(b, 0, 0, 1, 16, T.hover, "Hover")
            hover.Size = fill()
            hover.Visible = false
            local selection = frame(b, 0, 0, 1, 16, C.accent, "Selection")
            selection.Size = fill()
            selection.Visible = selected
            local selectionFade = gradient(selection, C.accent, C.accent, 0)
            selectionFade.Transparency = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 1 - 56 / 255),
                NumberSequenceKeypoint.new(0.5, 1),
                NumberSequenceKeypoint.new(1, 1 - 56 / 255),
            })
            local selectionOutline = stroke(b, C.accent)
            selectionOutline.Transparency = selected and 1 - 150 / 255 or 1
            local nameLabel = label(b, name, 5, 0, 1, 16, T.text, 12)
            nameLabel.Size = UDim2.new(1, -10, 1, 0)
            nameLabel.ZIndex = b.ZIndex + 2
            if Api.LoadedConfig == name then
                local loadedLabel = label(b, "(loaded)", 0, 0, 65, 16, C.accent_secondary, 12,
                    Enum.TextXAlignment.Right)
                loadedLabel.Position = UDim2.new(1, -70, 0, 0)
                loadedLabel.ZIndex = nameLabel.ZIndex
                nameLabel.Size = UDim2.new(1, -78, 1, 0)
            end
            conn(b.MouseEnter, function() if not selected then hover.Visible = true end end)
            conn(b.MouseLeave, function() hover.Visible = false end)
            conn(b.MouseButton1Click, function()
                selectedConfig = name
                refresh_configs()
            end)
        end
    end
    if count == 0 then label(configList, "No saved configs", 6, 6, 260, 16, T.dim, 11) end
    prune_connections()
end
conn(search:GetPropertyChangedSignal("Text"), refresh_configs)
local function action_button(text, x, y, w, action)
    local b = button(config, text, x, y, w, 16, true)
    b.Name = "Config" .. text:gsub("%W", "")
    conn(b.MouseButton1Click, function()
        local ok, message = action()
        status = ok and (message or (text .. " complete")) or tostring(message)
        refresh_configs()
    end)
end
action_button("Save", 13, 268, 136, function()
    local name = search.Text ~= "" and search.Text or selectedConfig
    local ok, err = Api:SaveConfig(name)
    if ok then selectedConfig = name end
    return ok, err
end)
action_button("Unload", 153, 268, 136, function()
    Api.LoadedConfig = nil
    return true, "configuration unloaded"
end)
action_button("Delete", 13, 288, 136, function()
    local ok, err = Api:DeleteConfig(selectedConfig or search.Text)
    if ok then selectedConfig = nil end
    return ok, err
end)
action_button("Refresh", 153, 288, 136, function() return true end)
action_button("Load", 13, 308, 276, function()
    local name = selectedConfig or (search.Text ~= "" and search.Text or nil)
    local ok, err = Menu:LoadConfig(name)
    if ok then selectedConfig = name end
    return ok, err
end)
refresh_configs()

personalization = detached("Personalization", 302, 330, 0, 217)
personalization.Position = UDim2.new(config.Position.X.Scale, config.Position.X.Offset,
    config.Position.Y.Scale, config.Position.Y.Offset + 347)
local personalizationBar = frame(personalization, 8, 7, 286, 22, T.fieldTop, "TitleBar")
gradient(personalizationBar, T.fieldTop, T.field)
stroke(personalizationBar, T.borderDark)
local personalizationBarInset = frame(personalizationBar, 1, 1, 284, 20, T.fieldTop, "InnerBorder")
personalizationBarInset.BackgroundTransparency = 1
stroke(personalizationBarInset, T.border)
frame(personalizationBar, 1, 1, 284, 1, T.bevelInner, "TopHighlight")
gloss(personalizationBar, 3, 2, 280, function() return S.shine_speed end)
local personalizationAccentLine = frame(personalizationBar, 0, 21, 286, 1, C.accent, "AccentLine")
personalizationAccentLine.BackgroundTransparency = 1 - 78 / 255
label(personalizationBar, "Personalization", 0, 0, 286, 22, T.text, 12,
    Enum.TextXAlignment.Center).ZIndex = 7

local personalizationBody = new("ScrollingFrame", personalization, {
    Name = "PersonalizationControls", Position = px(13, 38), Size = px(276, 280),
    BackgroundColor3 = T.panelAlt, BorderSizePixel = 0, ScrollBarThickness = 0,
    ScrollBarImageColor3 = C.accent_secondary, AutomaticCanvasSize = Enum.AutomaticSize.Y,
    CanvasSize = px(0, 0),
})
gradient(personalizationBody, T.panelAlt, T.panel)
stroke(personalizationBody, T.border)
new("UIPadding", personalizationBody, { PaddingLeft = UDim.new(0, 1),
    PaddingTop = UDim.new(0, 4), PaddingRight = UDim.new(0, 2),
    PaddingBottom = UDim.new(0, 4) })
new("UIListLayout", personalizationBody, {
    Padding = UDim.new(0, 0), SortOrder = Enum.SortOrder.LayoutOrder,
})
for _, spec in ipairs({
    sec("Menu colors"),
    control("color", "Surface tint", "menu_surface_color", { advanced = false }),
    sl("Surface tint strength", "menu_tint_strength", 0, 100, "%"),
    control("color", "Accent gradient", "accent", { secondary = "accent_secondary" }),
    control("color", "Checkbox gradient", "checkbox_color",
        { secondary = "checkbox_color_secondary" }),
    control("color", "Slider gradient", "slider_color",
        { secondary = "slider_color_secondary" }),
    sec("Chrome rails"),
    control("color", "Window outer rail", "window_rail_color",
        { secondary = "window_rail_color_secondary" }),
    control("color", "Tab rail", "tab_rail_color",
        { secondary = "tab_rail_color_secondary" }),
    control("color", "Section rail", "section_rail_color",
        { secondary = "section_rail_color_secondary" }),
    sec("Animation"),
    togg("Enable animations", "animations"),
    togg("Enable shine halo", "window_shine"),
    control("color", "Animation color", "animation_color",
        { secondary = "animation_color_secondary" }),
    control("color", "Shine halo color", "shine_color",
        { secondary = "shine_color_secondary" }),
    sl("Control animation speed", "scroll_speed", 0, 100, "%"),
    sl("Menu fade speed", "menu_fade_speed", 0, 100, "%"),
    sl("Section fade speed", "section_fade_speed", 0, 100, "%"),
    sl("Tab fade speed", "tab_fade_speed", 0, 100, "%"),
    sl("Moving shine speed", "shine_speed", 0, 140, "%"),
}) do
    add_control(personalizationBody, spec)
end

local HIT_WIDTH, HIT_HEIGHT, HIT_GAP = 252, 48, 6
local hitCards = {}

local function hit_position(index, entering)
    -- Leave the game's player list and Sense's target HUD unobstructed.
    local view = Workspace.CurrentCamera and Workspace.CurrentCamera.ViewportSize or viewport
    local right = math.min(200, math.max(12, view.X - HIT_WIDTH - 680))
    return UDim2.new(1, -HIT_WIDTH - right + (entering and 18 or 0),
        0, 84 + (index - 1) * (HIT_HEIGHT + HIT_GAP))
end

local function layout_hit_cards()
    local view = Workspace.CurrentCamera and Workspace.CurrentCamera.ViewportSize or viewport
    local visibleCount = math.max(1, math.floor((view.Y - 96) / (HIT_HEIGHT + HIT_GAP)))
    for index = #hitCards, visibleCount + 1, -1 do
        hitCards[index].card:Destroy()
        table.remove(hitCards, index)
    end
    for index, entry in ipairs(hitCards) do
        local position = hit_position(index)
        if entry.card.Position ~= position then
            tween(entry.card, { Position = position }, S.section_fade_speed)
        end
    end
end

local function dismiss_hit_card(id)
    for index, entry in ipairs(hitCards) do
        if entry.id == id then
            table.remove(hitCards, index)
            if entry.card.Parent then
                local card = entry.card
                tween(card, { GroupTransparency = 1,
                    Position = hit_position(index, true) }, S.menu_fade_speed)
                task.delay(0.25, function() if card.Parent then card:Destroy() end end)
            end
            layout_hit_cards()
            return
        end
    end
end

local function add_hit_card(hit)
    if Menu.Destroyed or not S.hit_notifications_enabled then return end
    local card = new("CanvasGroup", gui, { Name = "HitNotification" .. hit.id,
        Position = hit_position(1, true), Size = px(HIT_WIDTH, HIT_HEIGHT),
        BackgroundColor3 = T.window, BorderSizePixel = 0, GroupTransparency = 1,
        ZIndex = 50 })
    stroke(card, T.borderDark)
    local inner = frame(card, 2, 2, HIT_WIDTH - 4, HIT_HEIGHT - 4, T.panel, "Surface")
    stroke(inner, T.border)
    frame(card, 6, 9, 2, 30, hit.killed and C.accent or C.accent_secondary, "Accent")
    gloss(card, 3, 3, HIT_WIDTH - 6)

    local title = hit.killed and "ELIMINATION" or (hit.headshot and "HEADSHOT" or "HIT")
    label(card, title, 13, 6, 120, 15, T.text, 13)
    label(card, string.format("+%s", tostring(math.floor(hit.damage + 0.5))),
        HIT_WIDTH - 83, 6, 61, 15, C.accent_secondary, 13, Enum.TextXAlignment.Right)
    local summary = hit.name
    if hit.weapon ~= "" then summary = summary .. "  /  " .. hit.weapon end
    if #summary > 45 then summary = summary:sub(1, 42) .. "..." end
    label(card, summary, 13, 21, HIT_WIDTH - 32, 15, T.dim, 12)

    local close = button(card, "x", HIT_WIDTH - 18, 7, 12, 12, false)
    close.Name = "Dismiss"
    close.ZIndex = 52
    conn(close.MouseButton1Click, function() dismiss_hit_card(hit.id) end)

    local timerBack = frame(card, 13, HIT_HEIGHT - 7, HIT_WIDTH - 25, 2, T.fieldTop, "Timer")
    local timerFill = frame(timerBack, 0, 0, HIT_WIDTH - 25, 2, C.accent_secondary, "Remaining")
    local remaining = math.max(0, hit.expiresAt - os.clock())
    TweenService:Create(timerFill, TweenInfo.new(math.max(remaining, 0.01), Enum.EasingStyle.Linear),
        { Size = px(0, 2) }):Play()

    table.insert(hitCards, 1, { id = hit.id, card = card })
    layout_hit_cards()
    tween(card, { GroupTransparency = 0, Position = hit_position(1) }, S.menu_fade_speed)
    task.delay(remaining, function()
        if not Menu.Destroyed then dismiss_hit_card(hit.id) end
    end)
end

conn(Api.HitNotification.Event, add_hit_card)
conn(Api.HitNotificationsCleared.Event, function()
    for index = #hitCards, 1, -1 do dismiss_hit_card(hitCards[index].id) end
end)
for _, hit in ipairs(Api:GetHitNotifications()) do add_hit_card(hit) end

local function show_window(window, visible)
    if visible then
        if window.Visible and window.GroupTransparency < 0.01 then return end
        window.Visible = true
        tween(window, { GroupTransparency = 0 }, S.menu_fade_speed)
    elseif window.Visible then
        -- CanvasGroup transparency does not reliably suppress every UIStroke
        -- in all Roblox renderers. Fully hide closed windows to prevent empty
        -- black frames from leaking over the game.
        window.GroupTransparency = 1
        window.Visible = false
    end
end

refreshWindows = function()
    if Menu.Destroyed then return end
    local targetVisible = S.silent_target_marker and (Api.Target.active or Menu.Open)
    show_window(watermark, S.show_watermark)
    show_window(keybinds, S.show_keybinds)
    show_window(target, targetVisible)
    show_window(config, S.show_configs and Menu.Open)
    show_window(personalization, S.show_personalization and Menu.Open)
    scale_target_hud(S.target_hud_scale)
    refresh_keybinds()
    refresh_target()
    layout_hit_cards()
end

function Menu:RefreshWindows()
    if not self.Destroyed then refreshWindows() end
end

function Menu:SetOpen(value)
    if self.Destroyed then return end
    self.Open = value == true
    if self.Open then release_mouse_for_menu() else restore_game_mouse() end
    close_popup()
    show_window(main, self.Open)
    refreshWindows()
end

function Menu:SetTarget(data) self.Api:SetTarget(data) end
function Menu:ClearTarget() self.Api:ClearTarget() end
function Menu:NotifyHit(data) return self.Api:NotifyHit(data) end
function Menu:SetConfigVisible(value) return self.Api:Set("show_configs", value == true) end
function Menu:ToggleConfigs() return self.Api:Set("show_configs", not self.State.show_configs) end
function Menu:SetPersonalizationVisible(value)
    return self.Api:Set("show_personalization", value == true)
end
function Menu:TogglePersonalization()
    return self.Api:Set("show_personalization", not self.State.show_personalization)
end
function Menu:SaveConfig(name) return self.Api:SaveConfig(name) end
function Menu:LoadConfig(name)
    local ok, err = self.Api:LoadConfig(name)
    if ok then refreshCurrent(); refreshWindows() end
    return ok, err
end

local pageRefreshQueued = false
local function queue_page_refresh()
    if pageRefreshQueued then return end
    pageRefreshQueued = true
    task.defer(function()
        pageRefreshQueued = false
        if not Menu.Destroyed then refreshCurrent() end
    end)
end

conn(Api.Changed.Event, function(key)
    local colorKey = key:match("^color:(.+)$") or key:match("^color_alpha:(.+)$")
        or key:match("^color_option:(.+)$")
    if colorKey then refresh_color_swatches(colorKey) end
    if key == "active_tab" and S.active_tab ~= activeTab and schemas[S.active_tab]
        and Menu.RequestedTab ~= S.active_tab then
        activeTab = S.active_tab
        queue_page_refresh()
    elseif key == "color:accent" or key == "color:accent_secondary" then
        configAccentLine.BackgroundColor3 = C.accent
        personalizationAccentLine.BackgroundColor3 = C.accent
        queue_page_refresh()
    elseif key == "color:checkbox_color" or key == "color:checkbox_color_secondary" then
        refresh_checkbox_colors()
    elseif key == "color:animation_color" or key == "color:animation_color_secondary" then
        refresh_gloss_colors()
    elseif key == "color:slider_color" or key == "color:slider_color_secondary" then
        refresh_slider_colors()
    elseif key == "color:window_rail_color" or key == "color:window_rail_color_secondary" then
        refresh_chrome_colors("window")
    elseif key == "color:tab_rail_color" or key == "color:tab_rail_color_secondary" then
        refresh_chrome_colors("tabs")
    elseif key == "color:section_rail_color" or key == "color:section_rail_color_secondary" then
        refresh_chrome_colors("sections")
    elseif key == "color:menu_surface_color" or key == "menu_tint_strength" then
        apply_menu_tint()
        refresh_slider_colors()
        queue_page_refresh()
    elseif colorKey and paletteApiKeys[colorKey] then
        apply_menu_tint()
        refresh_slider_colors()
        queue_page_refresh()
    elseif menuSetDepth == 0 and (visibleKeys[key] or key == "rivals_detected"
        or key == "dahood_detected") then
        queue_page_refresh()
    end
    refreshWindows()
end)
conn(Api.TargetChanged.Event, refresh_target)
conn(RunService.RenderStepped, function()
    local shine = Menu.Open and S.window_shine
    for index = #movingGloss, 1, -1 do
        local entry = movingGloss[index]
        if not entry.strips[1].Parent then
            table.remove(movingGloss, index)
        else
            local travel = math.max(0, entry.width - 56)
            local distance = S.animations and travel > 0
                and (os.clock() * entry.speed()) % (travel * 2) or 0
            local offset = distance <= travel and distance or travel * 2 - distance
            for _, strip in ipairs(entry.strips) do
                strip.Position = px(entry.x + math.floor(offset + 0.5), strip.Position.Y.Offset)
            end
        end
    end
    local strength = (S.shine_glow / 100) * (S.menu_glow / 100) * (S.shine_halo_amount / 100)
    local reach = 1 + S.shine_width * 0.12 + S.shine_halo_size * 0.08
    local layers = math.clamp(4 + math.floor(S.menu_blur * 0.12), 4, 18)
    for i, layer in ipairs(haloLayers) do
        local visible = shine and i <= layers and strength > 0
        layer.frame.Visible = visible
        if visible then
            local progress = i / layers
            local falloff = 1 - progress
            local distance = math.floor(reach * progress + 0.5)
            layer.frame.Position = UDim2.new(main.Position.X.Scale, main.Position.X.Offset - distance,
                main.Position.Y.Scale, main.Position.Y.Offset - distance)
            layer.frame.Size = px(644 + 2 * distance, 668 + 2 * distance)
            layer.line.Color = C.shine_color
            layer.line.Transparency = 1 - math.clamp(strength * (0.05 + falloff * falloff * 0.46), 0, 1)
        end
    end
end)

function Menu:Destroy()
    if self.Destroyed then return end
    self.Destroyed = true
    pcall(function() RunService:UnbindFromRenderStep(mouseBindingName) end)
    restore_game_mouse()
    dragSlider = nil
    captureButton = nil
    close_popup()
    for _, connection in ipairs(self.Connections) do pcall(function() connection:Disconnect() end) end
    self.Connections = {}
    if self.FontDecoration then pcall(function() self.FontDecoration:Destroy() end) end
    self.Gui:Destroy()
    if Environment.__SenseLuaMenu == self then Environment.__SenseLuaMenu = nil end
end

activeTab = schemas[activeTab] and activeTab or tabNames[1]
if S.active_tab ~= activeTab then Api:Set("active_tab", activeTab) end
apply_menu_tint()
refresh_checkbox_colors()
refresh_gloss_colors()
refresh_slider_colors()
refresh_chrome_colors()
render_tab(activeTab)
refreshWindows()
Menu:SetOpen(true)
local SmallFont = load_font()
if SmallFont then
    local ok, decoration = pcall(SmallFont.decorate, gui)
    if ok then Menu.FontDecoration = decoration
    end
end
return Menu
