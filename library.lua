local Environment = getgenv()
local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")

local function key_name(value)
    if typeof(value) == "EnumItem" then return value.Name end
    if type(value) == "table" and value.Name then value = tostring(value.Name) end
    value = tostring(value or "None")
    return (value == "NONE" or value:lower() == "none") and "None" or value
end

local function key_item(value)
    local name = key_name(value)
    if name == "None" then return { Name = "NONE" } end
    local ok, item = pcall(function() return Enum.KeyCode[name] end)
    if ok and item then return item end
    ok, item = pcall(function() return Enum.UserInputType[name] end)
    return ok and item or { Name = name }
end

local function input_name(input)
    return input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode.Name
        or input.UserInputType.Name
end

local function precision_for(step)
    local text = tostring(step or 1)
    local fraction = text:match("%.(%d+)")
    return fraction and #fraction or 0
end

local function row_height(spec)
    local kind = spec[1]
    return kind == "slider" and 27 or (kind == "combo" or kind == "multi") and 33
        or kind == "input" and 36 or kind == "button" and 20
        or kind == "section" and 15 or kind == "sep" and 7
        or (kind == "toggle" or kind == "keytoggle" or kind == "color") and 16 or 14
end

local function new_indicator(library, data)
    local gui = library.Menu and library.Menu.Gui
    local holder = Instance.new("Frame")
    holder.Name = "SenseIndicator"
    holder.Position = data.position or UDim2.new(1, -300, 0, 80)
    holder.Size = UDim2.fromOffset(276, 28)
    holder.BackgroundColor3 = Color3.fromRGB(15, 15, 17)
    holder.BorderColor3 = Color3.fromRGB(0, 1, 3)
    holder.Visible = data.enabled == true
    holder.ZIndex = 80
    holder.Parent = gui
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -8, 0, 20)
    title.Position = UDim2.fromOffset(4, 3)
    title.BackgroundTransparency = 1
    title.Font = Enum.Font.Arial
    title.TextSize = 13
    title.TextColor3 = Color3.fromRGB(244, 246, 245)
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Text = tostring(data.title or "Indicator")
    title.ZIndex = 81
    title.Parent = holder
    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 1)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    local rows = Instance.new("Frame")
    rows.Name = "Rows"
    rows.Position = UDim2.fromOffset(4, 24)
    rows.Size = UDim2.new(1, -8, 0, 0)
    rows.BackgroundTransparency = 1
    rows.ZIndex = 81
    rows.Parent = holder
    layout.Parent = rows

    local indicator = { enabled = data.enabled == true, Holder = holder, Values = {} }
    function indicator:SetEnabled(value)
        self.enabled = value == true
        holder.Visible = self.enabled
    end
    function indicator:AddValue(entry)
        local row = Instance.new("TextLabel")
        row.Size = UDim2.new(1, 0, 0, 16)
        row.BackgroundTransparency = 1
        row.Font = Enum.Font.Arial
        row.TextSize = 12
        row.TextColor3 = Color3.fromRGB(180, 183, 183)
        row.TextXAlignment = Enum.TextXAlignment.Left
        row.ZIndex = 82
        row.Parent = rows
        local value = { key = tostring(entry.key or ""), value = tostring(entry.value or "") }
        local function refresh()
            row.Text = value.key .. ":  " .. value.value
            rows.Size = UDim2.new(1, -8, 0, #indicator.Values * 17)
            holder.Size = UDim2.fromOffset(276, 29 + #indicator.Values * 17)
        end
        function value:SetKey(nextKey) self.key = tostring(nextKey); refresh() end
        function value:SetValue(nextValue) self.value = tostring(nextValue); refresh() end
        indicator.Values[#indicator.Values + 1] = value
        refresh()
        return value
    end
    function indicator:Destroy() holder:Destroy() end
    library.Indicators[#library.Indicators + 1] = indicator
    return indicator
end

local function create_library(options)
    options = type(options) == "table" and options or {}
    local library = {
        flags = {}, options = {}, themes = {}, Connections = {}, Indicators = {},
        Tabs = {}, TabOrder = {}, Defaults = {}, Colors = {}, Built = false,
        Suppress = {}, BindStates = {}, BindModes = {}, ColorOptions = {},
        OverlayKeybinds = {},
    }

    local baseDefaults = {
        active_tab = "Visuals", menu_key = "RightShift", animations = true,
        show_watermark = false, show_keybinds = false, show_configs = false,
        show_personalization = false, menu_tint_strength = 0,
        silent_target_marker = false, target_hud_scale = 1,
        hit_notifications_enabled = false, hit_notifications_duration = 3,
        hit_notifications_max_count = 5, rivals_detected = false, dahood_detected = false,
        overlay_streamproof = false, overlay_vsync = false, overlay_fps = 240,
        overlay_fade_speed = 45, scroll_speed = 40, section_fade_speed = 45,
        tab_fade_speed = 45, menu_fade_speed = 45, window_shine = false,
        shine_speed = 70, shine_glow = 78, shine_width = 42,
        shine_halo_size = 32, shine_halo_amount = 44, menu_glow = 72, menu_blur = 35,
    }
    for key, value in pairs(baseDefaults) do library.Defaults[key] = value end

    local function rgb(r, g, b) return Color3.fromRGB(r, g, b) end
    local function preset(name, accent, background, border1, border2, group, option)
        local brightAccent = accent:Lerp(Color3.new(1, 1, 1), 0.18)
        return { name = name, theme = {
            accent = accent, accent_secondary = brightAccent,
            window = background, panel = background:Lerp(Color3.new(0, 0, 0), 0.18),
            panel_alt = group, field = option:Lerp(background, 0.35), field_top = option,
            hover = option:Lerp(Color3.new(1, 1, 1), 0.09), border = border1,
            bevel = border1:Lerp(Color3.new(1, 1, 1), 0.22),
            bevel_inner = border2:Lerp(accent, 0.12),
            text = rgb(244, 246, 245), dim = rgb(137, 140, 140),
            checkbox = brightAccent, checkbox_secondary = accent,
            slider = brightAccent:Lerp(group, 0.22),
            slider_secondary = accent:Lerp(background, 0.42),
            animation = brightAccent, animation_secondary = accent,
            shine = accent, shine_secondary = brightAccent,
            window_rail = border1:Lerp(accent, 0.18),
            window_rail_secondary = border2:Lerp(accent, 0.12),
            tab_rail = border2:Lerp(accent, 0.22),
            tab_rail_secondary = border2:Lerp(background, 0.35),
            section_rail = border2:Lerp(accent, 0.26),
            section_rail_secondary = border1:Lerp(accent, 0.20),
        } }
    end
    library.themes = {
        { name = "Sense", theme = {
            accent = rgb(48, 39, 51), accent_secondary = rgb(62, 51, 68),
            window = rgb(15, 15, 17), panel = rgb(11, 13, 13), panel_alt = rgb(19, 21, 23),
            field = rgb(15, 17, 17), field_top = rgb(27, 29, 29), hover = rgb(30, 32, 32),
            border = rgb(29, 31, 31), bevel = rgb(68, 64, 70), bevel_inner = rgb(39, 32, 42),
            text = rgb(244, 246, 245), dim = rgb(131, 133, 133),
            checkbox = rgb(62, 51, 68), checkbox_secondary = rgb(48, 39, 51),
            slider = rgb(63, 48, 69), slider_secondary = rgb(44, 37, 43),
            animation = rgb(61, 54, 64), animation_secondary = rgb(62, 51, 68),
            shine = rgb(48, 39, 51), shine_secondary = rgb(62, 51, 68),
            window_rail = rgb(68, 64, 70), window_rail_secondary = rgb(39, 32, 42),
            tab_rail = rgb(46, 42, 50), tab_rail_secondary = rgb(20, 18, 24),
            section_rail = rgb(39, 32, 42), section_rail_secondary = rgb(46, 42, 50),
        } },
        preset("Default", rgb(159, 143, 243), rgb(18, 18, 18), rgb(60, 60, 60),
            rgb(35, 35, 35), rgb(35, 35, 35), rgb(35, 35, 35)),
        preset("Tokyo Night", rgb(103, 89, 179), rgb(22, 22, 31), rgb(50, 50, 50),
            rgb(24, 25, 37), rgb(24, 25, 37), rgb(24, 25, 37)),
        preset("Nekocheat", rgb(226, 30, 112), rgb(18, 18, 18), rgb(60, 60, 60),
            rgb(35, 35, 35), rgb(18, 18, 18), rgb(23, 23, 23)),
        preset("Nekocheat Blue", rgb(0, 247, 255), rgb(18, 18, 18), rgb(60, 60, 60),
            rgb(35, 35, 35), rgb(18, 18, 18), rgb(23, 23, 23)),
        preset("Fatality", rgb(197, 7, 83), rgb(25, 19, 53), rgb(60, 53, 93),
            rgb(29, 23, 66), rgb(29, 23, 66), rgb(29, 23, 66)),
        preset("Gamesense", rgb(147, 184, 26), rgb(17, 17, 17), rgb(47, 47, 47),
            rgb(35, 35, 35), rgb(17, 17, 17), rgb(35, 35, 35)),
        preset("Twitch", rgb(169, 112, 255), rgb(14, 14, 14), rgb(45, 45, 45),
            rgb(31, 31, 35), rgb(31, 31, 35), rgb(24, 24, 27)),
    }

    local function register(flag, value)
        if type(flag) == "string" and library.Defaults[flag] == nil then
            library.Defaults[flag] = value
        end
        if type(flag) == "string" then library.flags[flag] = value end
    end

    local function fake_objects()
        return {
            background = { Visible = true }, gradient = { Visible = true },
            border1 = { Visible = true }, border2 = { Visible = true },
            text = { Position = UDim2.new() },
        }
    end

    function library:_refresh()
        if self.Menu and not self.Menu.Destroyed then self.Menu:Refresh() end
    end

    function library:_set(option, value, silent)
        local field = option.class == "toggle" and "state" or option.class == "slider" and "value"
            or option.class == "list" and "selected" or option.class == "box" and "input"
        if not field then return end
        option[field] = value
        self.flags[option.flag] = value
        if self.Api and self.Api:Has(option.flag) then
            if self.Api:Get(option.flag) == value then return end
            self.Suppress[option.flag] = silent == true
            self.Api:Set(option.flag, value)
        elseif not silent and option.callback then
            option.callback(value)
        end
    end

    local function add_option(section, data, class, default, spec)
        local option = {
            class = class, flag = data.flag, callback = data.callback,
            tooltip = data.tooltip, enabled = data.enabled ~= false,
            objects = fake_objects(), Spec = spec,
        }
        register(data.flag, default)
        library.options[data.flag] = option
        if data.enabled ~= nil then spec.when = function() return option.enabled end end
        section.Rows[#section.Rows + 1] = spec
        return option
    end

    local sectionMethods = {}
    function sectionMethods:UpdateOptions() library:_refresh() end
    function sectionMethods:AddToggle(data)
        local value = data.state == true
        local spec = { "toggle", tostring(data.text or data.flag), data.flag }
        local option = add_option(self, data, "toggle", value, spec)
        option.state = value
        function option:SetState(nextValue, silent)
            library:_set(self, nextValue == true, silent)
        end
        function option:SetEnabled(value) self.enabled = value == true end
        function option:AddBind(bindData)
            local bindFlag = bindData.flag
            local keyFlag = "sense_bind_key_" .. bindFlag
            local modeFlag = "sense_bind_mode_" .. bindFlag
            local key = key_name(bindData.bind)
            local mode = tostring(bindData.mode or "toggle"):lower()
            local modeName = mode == "hold" and "Hold" or mode == "always" and "Always" or "Toggle"
            register(keyFlag, key)
            register(modeFlag, modeName)
            spec[1], spec.bind, spec.mode = "keytoggle", keyFlag, modeFlag
            local bind = {
                class = "bind", flag = bindFlag, bind = key_item(bindData.bind), mode = mode,
                state = false, callback = bindData.callback, keycallback = bindData.keycallback,
                parent = option, keyFlag = keyFlag, modeFlag = modeFlag,
                indicatorValue = { SetEnabled = function() end },
            }
            library.options[bindFlag] = bind
            library.BindStates[keyFlag] = bind
            library.BindModes[modeFlag] = bind
            library.OverlayKeybinds[#library.OverlayKeybinds + 1] = {
                label = tostring(data.text or option.flag), stateFlag = option.flag,
                keyFlag = keyFlag, modeFlag = modeFlag,
            }
            function bind:SetKeyText() end
            function bind:SetBind(nextKey)
                local name = key_name(nextKey)
                if self.flag == "menu_keybind" and name == "None" then
                    name = "RightShift"
                    nextKey = Enum.KeyCode.RightShift
                end
                self.bind = key_item(nextKey)
                library.Defaults[self.keyFlag] = name
                if library.Api and library.Api:Has(self.keyFlag) then library.Api:Set(self.keyFlag, name) end
                if self.flag == "menu_keybind" then
                    library.Defaults.menu_key = name
                    if library.Api then library.Api:Set("menu_key", name) end
                end
                if self.keycallback then self.keycallback(self.bind) end
            end
            function bind:SetMode(nextMode)
                nextMode = tostring(nextMode or "toggle"):lower()
                self.mode = nextMode == "hold" and "hold" or nextMode == "always" and "always" or "toggle"
                local display = self.mode == "hold" and "Hold" or self.mode == "always" and "Always" or "Toggle"
                if library.Api and library.Api:Has(self.modeFlag) then library.Api:Set(self.modeFlag, display) end
                if self.mode == "always" then self:_fire(true)
                elseif self.state then self:_fire(false) end
            end
            function bind:_fire(value)
                if self.state == value then return end
                self.state = value
                library.flags[self.flag] = value
                if self.callback then self.callback(value) end
            end
            return bind
        end
        return option
    end

    function sectionMethods:AddSlider(data)
        local value = tonumber(data.value) or tonumber(data.min) or 0
        local spec = { "slider", tostring(data.text or data.flag), data.flag,
            min = tonumber(data.min) or 0, max = tonumber(data.max) or 100,
            step = tonumber(data.increment) or 1, suffix = data.suffix,
            precision = precision_for(data.increment) }
        local option = add_option(self, data, "slider", value, spec)
        option.value = value
        function option:SetValue(nextValue, silent)
            nextValue = tonumber(nextValue) or self.value
            library:_set(self, nextValue, silent)
        end
        function option:SetEnabled(value) self.enabled = value == true end
        return option
    end

    function sectionMethods:AddList(data)
        local values = type(data.values) == "table" and table.clone(data.values) or {}
        local selected = data.selected or values[1] or ""
        local spec = { "combo", tostring(data.text or data.flag), data.flag, values = values }
        local option = add_option(self, data, "list", selected, spec)
        option.values, option.selected = values, selected
        function option:Select(value, silent)
            if not table.find(self.values, value) and #self.values > 0 then value = self.values[1] end
            library:_set(self, value, silent)
        end
        function option:UpdateOptions(nextValues, nextSelected, silent)
            if type(nextValues) == "table" then
                table.clear(self.values)
                for _, value in ipairs(nextValues) do self.values[#self.values + 1] = value end
            end
            local selectedValue = nextSelected or self.selected
            if #self.values == 0 then selectedValue = ""
            elseif not table.find(self.values, selectedValue) then selectedValue = self.values[1] end
            library:_set(self, selectedValue, silent == true)
            library:_refresh()
        end
        option.SetValues = option.UpdateOptions
        function option:ClearValues() table.clear(self.values); library:_refresh() end
        function option:AddValue(value) self.values[#self.values + 1] = value; library:_refresh() end
        function option:SetEnabled(value) self.enabled = value == true end
        return option
    end

    function sectionMethods:AddBox(data)
        local value = tostring(data.input or "")
        local spec = { "input", tostring(data.text or data.flag), data.flag }
        local option = add_option(self, data, "box", value, spec)
        option.input = value
        function option:SetInput(nextValue, silent) library:_set(self, tostring(nextValue or ""), silent) end
        function option:SetEnabled(value) self.enabled = value == true end
        return option
    end

    function sectionMethods:AddColor(data)
        local flag = data.flag
        local key = "sense_color_" .. flag
        local color = typeof(data.color) == "Color3" and data.color or Color3.new(1, 1, 1)
        local trans = math.clamp(tonumber(data.trans) or 0, 0, 1)
        library.Colors[key] = { color = color, alpha = 1 - trans }
        local spec = { "color", tostring(data.text or flag), key, advanced = false }
        self.Rows[#self.Rows + 1] = spec
        local option = { class = "color", flag = flag, colorKey = key, color = color,
            trans = trans, callback = data.callback, Spec = spec, enabled = data.enabled ~= false }
        library.options[flag] = option
        library.ColorOptions[key] = option
        library.flags[flag] = color
        function option:SetColor(value, silent)
            if typeof(value) ~= "Color3" then return end
            self.color = value
            library.flags[self.flag] = value
            if library.Api then
                library.Suppress["color:" .. self.colorKey] = silent == true
                library.Api:SetColor(self.colorKey, value)
            elseif not silent and self.callback then self.callback(value) end
        end
        function option:SetTrans(value)
            self.trans = math.clamp(tonumber(value) or 0, 0, 1)
            if library.Api then library.Api:SetColorAlpha(self.colorKey, 1 - self.trans) end
        end
        function option:SetEnabled(value) self.enabled = value == true end
        return option
    end

    function sectionMethods:AddButton(data)
        if type(data) == "string" then data = { text = data } end
        local spec = { "button", tostring(data.text or "Button"), nil,
            action = type(data.callback) == "function" and data.callback or function() end,
            confirm = data.confirm == true, confirmText = data.confirmText,
            style = data.style }
        self.Rows[#self.Rows + 1] = spec
        return { class = "button", callback = data.callback, Spec = spec }
    end

    local tabMethods = {}
    function tabMethods:AddSection(title, column)
        local section = setmetatable({ Title = tostring(title), Column = column == 2 and 2 or 1,
            Rows = {} }, { __index = sectionMethods })
        self.Sections[#self.Sections + 1] = section
        return section
    end
    function tabMethods:UpdateSections() library:_refresh() end

    local windowMethods = {}
    function windowMethods:AddTab(name)
        name = tostring(name)
        local tab = setmetatable({ Name = name, Sections = {} }, { __index = tabMethods })
        library.Tabs[name] = tab
        library.TabOrder[#library.TabOrder + 1] = name
        if #library.TabOrder == 1 then library.Defaults.active_tab = name end
        return tab
    end

    function library.NewWindow(data)
        library.WindowData = data or {}
        return setmetatable({}, { __index = windowMethods })
    end

    function library:_schemas()
        local schemas, heights = {}, {}
        for _, tabName in ipairs(self.TabOrder) do
            local tab, columns = self.Tabs[tabName], { 0, 0 }
            schemas[tabName] = {}
            for _, section in ipairs(tab.Sections) do
                local height = 22
                for _, spec in ipairs(section.Rows) do height += row_height(spec) end
                height = math.max(48, height)
                local column = section.Column
                schemas[tabName][#schemas[tabName] + 1] = {
                    title = section.Title, x = column == 1 and 0 or 310,
                    y = columns[column], h = height, rows = section.Rows,
                }
                columns[column] += height + 4
            end
            heights[tabName] = math.max(columns[1], columns[2], 570)
        end
        return schemas, heights
    end

    function library:_bindApi()
        local api = self.Api
        self.Connections[#self.Connections + 1] = api.Changed.Event:Connect(function(key, value)
            local bind = self.BindStates[key]
            if bind then
                bind.bind = key_item(value)
                bind.changedAt = os.clock()
                local name = key_name(value)
                if name == "None" and bind.state then bind:_fire(false) end
                if bind.flag == "menu_keybind" then
                    local menuKey = name == "None" and "RightShift" or name
                    if name == "None" then
                        bind.bind = Enum.KeyCode.RightShift
                        self.Defaults[bind.keyFlag] = menuKey
                        if api:Get(bind.keyFlag) ~= menuKey then api:Set(bind.keyFlag, menuKey) end
                    end
                    self.Defaults.menu_key = menuKey
                    if api:Has("menu_key") then api:Set("menu_key", menuKey) end
                end
                if bind.keycallback then bind.keycallback(bind.bind) end
                return
            end
            bind = self.BindModes[key]
            if bind then
                bind.mode = tostring(value):lower()
                if bind.mode == "always" then bind:_fire(true)
                elseif bind.state then bind:_fire(false) end
                return
            end
            if key:sub(1, 6) == "color:" then
                local colorKey = key:sub(7)
                local option = self.ColorOptions[colorKey]
                if option then
                    option.color = value
                    self.flags[option.flag] = value
                    local silent = self.Suppress[key]
                    self.Suppress[key] = nil
                    if not silent and option.callback then option.callback(value) end
                end
                return
            end
            local option = self.options[key]
            if not option or option.class == "bind" or option.class == "color" then return end
            if option.class == "toggle" then option.state = value
            elseif option.class == "slider" then option.value = value
            elseif option.class == "list" then option.selected = value
            elseif option.class == "box" then option.input = value end
            self.flags[key] = value
            local silent = self.Suppress[key]
            self.Suppress[key] = nil
            if not silent and option.callback then option.callback(value) end
        end)
        self.Connections[#self.Connections + 1] = UserInputService.InputBegan:Connect(function(input)
            if UserInputService:GetFocusedTextBox() then return end
            local name = input_name(input)
            for _, option in pairs(self.options) do
                if option.class == "bind" and key_name(option.bind) == name then
                    if os.clock() - (option.changedAt or 0) < 0.05 then continue end
                    if option.mode == "hold" then option:_fire(true)
                    elseif option.mode == "toggle" then option:_fire(not option.state) end
                end
            end
        end)
        self.Connections[#self.Connections + 1] = UserInputService.InputEnded:Connect(function(input)
            local name = input_name(input)
            for _, option in pairs(self.options) do
                if option.class == "bind" and option.mode == "hold" and key_name(option.bind) == name then
                    option:_fire(false)
                end
            end
        end)
        for _, option in pairs(self.options) do
            if option.class == "bind" and option.mode == "always" then option:_fire(true) end
        end
    end

    function library:Attach(menu)
        if not menu or not menu.Api then return false end
        self.Menu, self.Api, self.Built = menu, menu.Api, true
        menu.KeybindRows = self.OverlayKeybinds
        menu.Api.KeybindRows = self.OverlayKeybinds
        self:_bindApi()
        for _, indicator in ipairs(self.Indicators) do
            if indicator.Holder and not indicator.Holder.Parent then indicator.Holder.Parent = menu.Gui end
        end
        if type(menu.RefreshWindows) == "function" then menu:RefreshWindows() end
        return true
    end

    function library:_build()
        if self.Built then return self.Menu end
        self.Built = true
        local schemas, heights = self:_schemas()
        local previous = Environment.SenseMenuApi
        if type(previous) == "table" and type(previous.Destroy) == "function" and not previous.Destroyed then
            previous:Destroy()
        end
        Environment.SenseMenuApi = nil
        Environment.__SenseLuaMenuApiFactory = nil
        Environment.__SenseSmallFontModule = nil
        Environment.SenseMenuBaseUrl = options.baseUrl or Environment.SenseMenuBaseUrl
        Environment.SenseMenuApiUrl = options.apiUrl
        Environment.SenseMenuFontUrl = options.fontUrl
        Environment.SenseMenuDefaults = self.Defaults
        Environment.SenseMenuColors = self.Colors
        Environment.SenseMenuSchemas = schemas
        Environment.SenseMenuTabNames = self.TabOrder
        Environment.SenseMenuPageHeights = heights
        Environment.SenseMenuKeybindRows = self.OverlayKeybinds
        Environment.SenseMenuConfigDirectory = options.configDirectory
        local menu
        if type(options.loadMenu) == "function" then
            menu = options.loadMenu()
        elseif type(Environment.SenseMenuBaseUrl) == "string" then
            local source = game:HttpGet(Environment.SenseMenuBaseUrl:gsub("/+$", "") .. "/menu.lua")
            menu = loadstring(source)()
        end
        if menu then
            self:Attach(menu)
            if self.theme then self:SetTheme(self.theme) end
        end
        return menu
    end

    function library:init() return self end
    function library:SetOpen(value)
        local menu = self:_build()
        if menu then menu:SetOpen(value == true) end
    end
    function library:SetConfigsOpen(value)
        local menu = self:_build()
        if not menu or not menu.Api then return false end
        if value == nil then value = not menu.Api.State.show_configs end
        return menu.Api:Set("show_configs", value == true)
    end
    function library:ToggleConfigs() return self:SetConfigsOpen(nil) end
    function library:SetPersonalizationOpen(value)
        local menu = self:_build()
        if not menu or not menu.Api then return false end
        if value == nil then value = not menu.Api.State.show_personalization end
        return menu.Api:Set("show_personalization", value == true)
    end
    function library:TogglePersonalization() return self:SetPersonalizationOpen(nil) end
    function library:SetTheme(theme)
        if type(theme) == "string" then
            for _, entry in ipairs(self.themes) do
                if entry.name == theme then
                    theme = entry.theme
                    break
                end
            end
        end
        if type(theme) ~= "table" then return false end
        local menu = self:_build()
        local api = menu and menu.Api
        if not api then return false end
        self.theme = theme
        local colorMap = {
            accent = "accent", accent_secondary = "accent_secondary",
            window = "menu_window_color", panel = "menu_panel_color",
            panel_alt = "menu_panel_alt_color", field = "menu_field_color",
            field_top = "menu_field_top_color", hover = "menu_hover_color",
            border = "menu_border_color", bevel = "menu_bevel_color",
            bevel_inner = "menu_bevel_inner_color", text = "menu_text_color",
            dim = "menu_dim_color", checkbox = "checkbox_color",
            checkbox_secondary = "checkbox_color_secondary", slider = "slider_color",
            slider_secondary = "slider_color_secondary", animation = "animation_color",
            animation_secondary = "animation_color_secondary", shine = "shine_color",
            shine_secondary = "shine_color_secondary",
            window_rail = "window_rail_color",
            window_rail_secondary = "window_rail_color_secondary",
            tab_rail = "tab_rail_color", tab_rail_secondary = "tab_rail_color_secondary",
            section_rail = "section_rail_color",
            section_rail_secondary = "section_rail_color_secondary",
        }
        if api:Has("menu_tint_strength") then api:Set("menu_tint_strength", 0) end
        local surfaceTint = theme.surface_tint or theme.accent_secondary or theme.accent
        if typeof(surfaceTint) == "Color3" then api:SetColor("menu_surface_color", surfaceTint) end
        for themeKey, colorKey in pairs(colorMap) do
            if typeof(theme[themeKey]) == "Color3" then api:SetColor(colorKey, theme[themeKey]) end
        end
        return true
    end
    function library:SendNotification(message, duration)
        pcall(StarterGui.SetCore, StarterGui, "SendNotification", {
            Title = options.cheatname or "Sense", Text = tostring(message), Duration = duration or 3,
        })
    end
    function library:Unload()
        for _, connection in ipairs(self.Connections) do pcall(function() connection:Disconnect() end) end
        table.clear(self.Connections)
        for _, indicator in ipairs(self.Indicators) do pcall(function() indicator:Destroy() end) end
        table.clear(self.Indicators)
        if self.Menu and not self.Menu.Destroyed then self.Menu:Destroy() end
    end
    function library.NewIndicator(data)
        library:_build()
        return new_indicator(library, data or {})
    end

    return library
end

Environment.__SenseMenuLibraryFactory = create_library
return create_library
