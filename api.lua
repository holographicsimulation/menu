local HttpService = game:GetService("HttpService")

local API = {}
API.__index = API
API.Version = 2
API.ConfigDirectory = "configs"

local transientStateKeys = {
    show_configs = true,
    show_personalization = true,
}


local colorDefaults = {
    accent = Color3.fromRGB(48, 39, 51), accent_secondary = Color3.fromRGB(62, 51, 68),
    box_color = Color3.fromRGB(244, 246, 245), box_color_secondary = Color3.fromRGB(170, 174, 174),
    box_fill_color = Color3.fromRGB(51, 219, 230),
    box_outline_color = Color3.fromRGB(8, 8, 8), text_outline_color = Color3.fromRGB(0, 0, 0),
    health_color = Color3.fromRGB(46, 242, 77), health_text_color = Color3.fromRGB(255, 255, 255),
    skeleton_color = Color3.fromRGB(255, 219, 82), name_color = Color3.fromRGB(184, 230, 255),
    distance_color = Color3.fromRGB(204, 209, 219), held_item_color = Color3.fromRGB(255, 255, 255),
    flags_color = Color3.fromRGB(51, 219, 230), tracer_color = Color3.fromRGB(77, 199, 255),
    head_dot_color = Color3.fromRGB(255, 82, 107), fov_draw_color = Color3.fromRGB(255, 255, 255),
    fov_draw_color_secondary = Color3.fromRGB(179, 179, 179),
    raycast_tracer_color = Color3.fromRGB(255, 255, 255),
    raycast_damage_color = Color3.fromRGB(255, 89, 61),
    raycast_damage_color_secondary = Color3.fromRGB(255, 173, 61),
    armor_color = Color3.fromRGB(115, 89, 130), armor_color_secondary = Color3.fromRGB(181, 145, 194),
    desync_ghost_color = Color3.fromRGB(148, 61, 255),
    desync_ghost_color_secondary = Color3.fromRGB(199, 148, 255),
    shine_color = Color3.fromRGB(48, 39, 51), shine_color_secondary = Color3.fromRGB(62, 51, 68),
    menu_surface_color = Color3.fromRGB(62, 51, 68),
    animation_color = Color3.fromRGB(61, 54, 64),
    animation_color_secondary = Color3.fromRGB(62, 51, 68),
    checkbox_color = Color3.fromRGB(62, 51, 68),
    checkbox_color_secondary = Color3.fromRGB(48, 39, 51),
    slider_color = Color3.fromRGB(63, 48, 69),
    slider_color_secondary = Color3.fromRGB(44, 37, 43),
    menu_window_color = Color3.fromRGB(15, 15, 17),
    menu_panel_color = Color3.fromRGB(11, 13, 13),
    menu_panel_alt_color = Color3.fromRGB(19, 21, 23),
    menu_field_color = Color3.fromRGB(15, 17, 17),
    menu_field_top_color = Color3.fromRGB(27, 29, 29),
    menu_hover_color = Color3.fromRGB(30, 32, 32),
    menu_border_color = Color3.fromRGB(29, 31, 31),
    menu_bevel_color = Color3.fromRGB(68, 64, 70),
    menu_bevel_inner_color = Color3.fromRGB(39, 32, 42),
    menu_text_color = Color3.fromRGB(244, 246, 245),
    menu_dim_color = Color3.fromRGB(131, 133, 133),
    window_rail_color = Color3.fromRGB(68, 64, 70),
    window_rail_color_secondary = Color3.fromRGB(39, 32, 42),
    tab_rail_color = Color3.fromRGB(46, 42, 50),
    tab_rail_color_secondary = Color3.fromRGB(20, 18, 24),
    section_rail_color = Color3.fromRGB(39, 32, 42),
    section_rail_color_secondary = Color3.fromRGB(46, 42, 50),
}

local colorOptionsDefaults = {}
local colorAlphaDefaults = {}
local primaryColors = {}
for key, color in pairs(colorDefaults) do
    if not key:match("_secondary$") then
        primaryColors[#primaryColors + 1] = { key, color }
        colorOptionsDefaults[key] = { mode = (key == "accent" or key == "box_color" or key == "shine_color"
                or key == "animation_color" or key == "checkbox_color" or key == "slider_color"
                or key == "window_rail_color" or key == "tab_rail_color"
                or key == "section_rail_color"
                or key == "raycast_tracer_color" or key == "raycast_damage_color"
                or key == "armor_color" or key == "desync_ghost_color")
                and "Horizontal" or (key == "fov_draw_color" and "Vertical" or "Solid"),
            angle = 0, midpoint = 0.5, speed = key == "desync_ghost_color" and 18 or 0 }
        colorAlphaDefaults[key] = ({ box_fill_color = 20 / 255,
            box_outline_color = 190 / 255, text_outline_color = 230 / 255,
            raycast_tracer_color = 0.96, desync_ghost_color = 0.22 })[key] or 1
    end
end
for _, entry in ipairs(primaryColors) do
    local key, color = entry[1], entry[2]
    if colorDefaults[key .. "_secondary"] == nil then colorDefaults[key .. "_secondary"] = color end
    colorAlphaDefaults[key .. "_secondary"] = colorAlphaDefaults[key]
end
colorAlphaDefaults.raycast_tracer_color_secondary = 0.08
colorAlphaDefaults.desync_ghost_color_secondary = 0.30

local function copy(value, seen)
    if type(value) ~= "table" then return value end
    seen = seen or {}
    if seen[value] then return seen[value] end
    local result = {}
    seen[value] = result
    for k, v in pairs(value) do result[k] = copy(v, seen) end
    return result
end

local function finite_number(value)
    return type(value) == "number" and value == value
        and value ~= math.huge and value ~= -math.huge
end

local function valid_state_value(value, visiting)
    local kind = type(value)
    if kind == "string" or kind == "boolean" then return true end
    if kind == "number" then return finite_number(value) end
    if kind ~= "table" or getmetatable(value) ~= nil then return false end
    visiting = visiting or {}
    if visiting[value] then return false end
    visiting[value] = true
    for key, item in pairs(value) do
        if type(key) ~= "string" and not (finite_number(key) and key >= 1 and key % 1 == 0) then
            visiting[value] = nil
            return false
        end
        if not valid_state_value(item, visiting) then
            visiting[value] = nil
            return false
        end
    end
    visiting[value] = nil
    return true
end

local function valid_key(key)
    return type(key) == "string" and #key > 0 and #key <= 96
        and key:match("^[%a_][%w_]*$") ~= nil
end

function API.ParseDefaults(source)
    local result = {}
    if type(source) == "table" then
        for key, value in pairs(source) do
            if not valid_key(key) then return nil, "invalid default key: " .. tostring(key) end
            if not valid_state_value(value) then
                return nil, "default must be JSON-compatible: " .. key
            end
            result[key] = copy(value)
        end
        return result
    end
    if type(source) ~= "string" then return nil, "expected a defaults table or string" end

    local lineNumber = 0
    for rawLine in (source .. "\n"):gmatch("(.-)\n") do
        lineNumber += 1
        local line = rawLine:gsub("\r$", ""):match("^%s*(.-)%s*$")
        if line ~= "" and line:sub(1, 1) ~= "#" and line:sub(1, 2) ~= "--" then
            local key, encoded = line:match("^([%a_][%w_]*)%s*=%s*(.+)$")
            if not key or not valid_key(key) then
                return nil, "invalid default declaration on line " .. lineNumber
            end
            if result[key] ~= nil then return nil, "duplicate default key: " .. key end

            local decodedOk, value = pcall(HttpService.JSONDecode, HttpService, encoded)
            if not decodedOk then
                local first = encoded:sub(1, 1)
                if first == "{" or first == "[" or first == '"' then
                    return nil, "invalid JSON default on line " .. lineNumber .. ": " .. key
                end
                value = encoded -- bare strings such as Insert or Small Fonts
            end
            if not valid_state_value(value) then
                return nil, "invalid default on line " .. lineNumber .. ": " .. key
            end
            result[key] = copy(value)
        end
    end
    return result
end

local function safe_name(name)
    if type(name) ~= "string" then return nil end
    name = name:match("^%s*(.-)%s*$")
    if #name == 0 or #name > 48 or name:find("[^%w_%- ]") then return nil end
    return name
end

local function ensure_directory(path)
    if type(isfolder) ~= "function" or type(makefolder) ~= "function" then return false end
    if type(path) ~= "string" or path == "" or path:find("..", 1, true)
        or path:match("^[/\\]") or path:match("^%a:") then return false end
    local current = ""
    for part in path:gmatch("[^/\\]+") do
        if part == "." or part == ".." then return false end
        current = current == "" and part or (current .. "/" .. part)
        local ok = pcall(function()
            if not isfolder(current) then makefolder(current) end
        end)
        if not ok then return false end
    end
    return current ~= ""
end

function API.new(options)
    options = type(options) == "table" and options or {}
    local defaults = {}
    if options.defaults ~= nil then
        local parsed, parseError = API.ParseDefaults(options.defaults)
        if not parsed then return nil, parseError end
        defaults = parsed
    end
    local self = setmetatable({}, API)
    self.Defaults = defaults
    self.State = copy(self.Defaults)
    if type(options.configDirectory) == "string" and options.configDirectory ~= "" then
        self.ConfigDirectory = options.configDirectory
    end
    self.Colors = copy(colorDefaults)
    self.ColorAlpha = copy(colorAlphaDefaults)
    self.ColorOptions = copy(colorOptionsDefaults)
    self.ColorDefaults = copy(colorDefaults)
    self.ColorAlphaDefaults = copy(colorAlphaDefaults)
    self.ColorOptionsDefaults = copy(colorOptionsDefaults)
    self.Target = { active = false, name = "", part = "", health = 0, maxHealth = 0, distance = -1, userId = 0 }
    self.Changed = Instance.new("BindableEvent")
    self.TargetChanged = Instance.new("BindableEvent")
    self.HitNotification = Instance.new("BindableEvent")
    self.HitNotificationsCleared = Instance.new("BindableEvent")
    self.HitNotifications = {}
    self.LastHitNotificationId = 0
    self.LoadedConfig = nil
    self.Destroyed = false
    if options.colors ~= nil then
        local ok, colorError = self:RegisterColors(options.colors)
        if not ok then
            self:Destroy()
            return nil, colorError
        end
    end
    return self
end

function API:Has(key)
    return self.Defaults[key] ~= nil
end

function API:Get(key)
    return self.State[key]
end

function API:GetDefault(key)
    return copy(self.Defaults[key])
end

function API:Register(key, defaultValue)
    if self.Destroyed then return false, "API destroyed" end
    if not valid_key(key) then return false, "invalid state key" end
    if self:Has(key) then return false, "state key already registered" end
    if not valid_state_value(defaultValue) then return false, "default must be JSON-compatible" end
    self.Defaults[key] = copy(defaultValue)
    self.State[key] = copy(defaultValue)
    self.Changed:Fire(key, self.State[key])
    return true
end

function API:RegisterDefaults(values)
    if self.Destroyed then return false, "API destroyed" end
    local parsed, err = API.ParseDefaults(values)
    if not parsed then return false, err end
    values = parsed
    for key, value in pairs(values) do
        if self:Has(key) then return false, "state key already registered: " .. key end
    end
    for key, value in pairs(values) do
        self.Defaults[key] = copy(value)
        self.State[key] = copy(value)
        self.Changed:Fire(key, self.State[key])
    end
    return true
end

function API:Set(key, value)
    if self.Destroyed then return false, "API destroyed" end
    if not self:Has(key) then return false, "unknown state key" end
    if type(value) ~= type(self.Defaults[key]) then return false, "wrong value type" end
    if not valid_state_value(value) then return false, "value must be JSON-compatible" end
    if key == "hit_notifications_duration" then
        value = math.clamp(value, 0.25, 15)
    elseif key == "hit_notifications_max_count" then
        value = math.floor(math.clamp(value, 1, 20))
    elseif key == "target_hud_scale" then
        value = math.clamp(value, 0.75, 1.5)
    end
    self.State[key] = copy(value)
    self.Changed:Fire(key, self.State[key])
    if key == "hit_notifications_enabled" and not value then
        self:ClearHitNotifications()
    end
    return true
end

function API:Toggle(key)
    if not self:Has(key) or type(self.Defaults[key]) ~= "boolean" then
        return false, "not a boolean state key"
    end
    return self:Set(key, not self.State[key])
end

function API:ResetKey(key)
    if not self:Has(key) then return false, "unknown state key" end
    return self:Set(key, self.Defaults[key])
end

function API:Bind(key, callback, immediately)
    if self.Destroyed then return nil, "API destroyed" end
    if type(callback) ~= "function" then return nil, "expected a callback" end
    local initialValue
    if key ~= "*" then
        if self:Has(key) then
            initialValue = self:Get(key)
        elseif type(key) == "string" then
            local colorKey = key:match("^color:(.+)$")
            local alphaKey = key:match("^color_alpha:(.+)$")
            local optionKey = key:match("^color_option:(.+)$")
            if colorKey then initialValue = self:GetColor(colorKey)
            elseif alphaKey then initialValue = self:GetColorAlpha(alphaKey)
            elseif optionKey then initialValue = self:GetColorOptions(optionKey) end
        end
        if initialValue == nil then return nil, "unknown state key" end
    end
    local connection = self.Changed.Event:Connect(function(changedKey, value)
        if key == "*" or key == changedKey then callback(value, changedKey, self) end
    end)
    if immediately and key ~= "*" then callback(initialValue, key, self) end
    return connection
end

function API:GetColor(key)
    return self.Colors[key]
end

function API:GetColorAlpha(key)
    return self.ColorAlpha[key]
end

function API:GetColorOptions(key)
    return self.ColorOptions[key]
end

function API:RegisterColor(key, value, alpha, options)
    if self.Destroyed then return false, "API destroyed" end
    if not valid_key(key) or typeof(value) ~= "Color3" then return false, "invalid color" end
    if self.ColorDefaults[key] ~= nil then return false, "color already registered: " .. key end
    alpha = tonumber(alpha) or 1
    if not finite_number(alpha) then return false, "invalid color alpha" end
    options = type(options) == "table" and options or {}
    local mode = options.mode or "Solid"
    if mode ~= "Solid" and mode ~= "Horizontal" and mode ~= "Vertical" and mode ~= "Radial" then
        return false, "invalid color mode"
    end
    self.ColorDefaults[key] = value
    self.Colors[key] = value
    self.ColorAlpha[key] = math.clamp(alpha, 0, 1)
    self.ColorAlphaDefaults[key] = self.ColorAlpha[key]
    self.ColorOptions[key] = {
        mode = mode,
        angle = math.clamp(tonumber(options.angle) or 0, 0, 360),
        midpoint = math.clamp(tonumber(options.midpoint) or 0.5, 0.05, 0.95),
        speed = math.clamp(tonumber(options.speed) or 0, -100, 100),
    }
    self.ColorOptionsDefaults[key] = copy(self.ColorOptions[key])
    local secondary = options.secondary
    local secondaryKey = key .. "_secondary"
    if self.ColorDefaults[secondaryKey] == nil then
        secondary = typeof(secondary) == "Color3" and secondary or value
        self.ColorDefaults[secondaryKey] = secondary
        self.Colors[secondaryKey] = secondary
        self.ColorAlpha[secondaryKey] = math.clamp(tonumber(options.secondaryAlpha) or alpha, 0, 1)
        self.ColorAlphaDefaults[secondaryKey] = self.ColorAlpha[secondaryKey]
    end
    self.Changed:Fire("color:" .. key, value)
    return true
end

function API:RegisterColors(values)
    if self.Destroyed then return false, "API destroyed" end
    if type(values) ~= "table" then return false, "expected a color table" end
    for key, entry in pairs(values) do
        local value = entry
        local alpha, options
        if type(entry) == "table" then
            value, alpha, options = entry.color or entry[1], entry.alpha, entry.options
        end
        if self.ColorDefaults[key] == nil then
            local ok, err = self:RegisterColor(key, value, alpha, options)
            if not ok then return false, err end
        end
    end
    return true
end

function API:SetColor(key, value)
    if self.Destroyed then return false, "API destroyed" end
    if self.ColorDefaults[key] == nil or typeof(value) ~= "Color3" then return false end
    self.Colors[key] = value
    self.Changed:Fire("color:" .. key, value)
    return true
end

function API:SetColorAlpha(key, value)
    if self.Destroyed then return false, "API destroyed" end
    value = tonumber(value)
    if self.ColorAlpha[key] == nil or not finite_number(value) then return false end
    value = math.clamp(value, 0, 1)
    self.ColorAlpha[key] = value
    self.Changed:Fire("color_alpha:" .. key, value)
    return true
end

function API:SetColorOption(key, option, value)
    if self.Destroyed then return false, "API destroyed" end
    local settings = self.ColorOptions[key]
    if not settings or settings[option] == nil then return false end
    if option == "mode" then
        if value ~= "Solid" and value ~= "Horizontal" and value ~= "Vertical" and value ~= "Radial" then return false end
    else
        value = tonumber(value)
        if not finite_number(value) then return false end
        if option == "angle" then value = math.clamp(value, 0, 360)
        elseif option == "midpoint" then value = math.clamp(value, 0.05, 0.95)
        elseif option == "speed" then value = math.clamp(value, -100, 100) end
    end
    settings[option] = value
    self.Changed:Fire("color_option:" .. key, settings)
    return true
end

function API:SetTarget(data)
    if self.Destroyed then return false, "API destroyed" end
    if data ~= nil and type(data) ~= "table" then return false, "expected a table" end
    data = data or {}
    self.Target = {
        active = data.active == true,
        name = tostring(data.name or ""), part = tostring(data.part or ""),
        health = tonumber(data.health) or 0, maxHealth = tonumber(data.maxHealth) or 0,
        distance = tonumber(data.distance) or -1, userId = tonumber(data.userId) or 0,
    }
    self.TargetChanged:Fire(self.Target)
    return true
end

function API:ClearTarget()
    return self:SetTarget()
end

function API:BindTarget(callback, immediately)
    if self.Destroyed then return nil, "API destroyed" end
    if type(callback) ~= "function" then return nil, "expected a callback" end
    local connection = self.TargetChanged.Event:Connect(function(target)
        callback(target, self)
    end)
    if immediately then callback(self.Target, self) end
    return connection
end

local function notification_limit(api)
    local value = tonumber(api.State.hit_notifications_max_count) or 5
    if not finite_number(value) then value = 5 end
    return math.floor(math.clamp(value, 1, 20))
end

local function notification_duration(api, override)
    local value = tonumber(override) or tonumber(api.State.hit_notifications_duration) or 3
    if not finite_number(value) then value = 3 end
    return math.clamp(value, 0.25, 15)
end

local function trim_hit_notifications(api, now)
    local items = api.HitNotifications
    for index = #items, 1, -1 do
        if items[index].expiresAt <= now then table.remove(items, index) end
    end
    local limit = notification_limit(api)
    while #items > limit do table.remove(items, 1) end
end

-- data: { name/target, damage, headshot, killed, part, weapon, duration? }
function API:NotifyHit(data)
    if self.Destroyed then return false, "API destroyed" end
    if not self.State.hit_notifications_enabled then return false, "hit notifications disabled" end
    if type(data) ~= "table" then return false, "expected hit data table" end

    local now = os.clock()
    local damage = tonumber(data.damage)
    if not finite_number(damage) then damage = 0 end
    local health = tonumber(data.health)
    if not finite_number(health) then health = nil end
    local duration = notification_duration(self, data.duration)
    self.LastHitNotificationId = self.LastHitNotificationId + 1
    local hit = {
        id = self.LastHitNotificationId,
        name = tostring(data.name or data.targetName or data.target_name or data.target or "Unknown"),
        damage = math.max(damage, 0),
        headshot = data.headshot == true or data.isHeadshot == true or data.is_headshot == true,
        killed = data.killed == true or data.isKill == true or data.is_kill == true,
        part = tostring(data.part or data.hitpart or data.hitPart or ""),
        weapon = tostring(data.weapon or ""),
        health = health,
        timestamp = now,
        duration = duration,
        expiresAt = now + duration,
    }
    trim_hit_notifications(self, now)
    local items = self.HitNotifications
    items[#items + 1] = hit
    trim_hit_notifications(self, now)
    self.HitNotification:Fire(copy(hit))
    return true, copy(hit)
end

function API:GetHitNotifications()
    if self.Destroyed then return {} end
    trim_hit_notifications(self, os.clock())
    return copy(self.HitNotifications)
end

function API:ClearHitNotifications()
    if self.Destroyed then return false, "API destroyed" end
    self.HitNotifications = {}
    self.HitNotificationsCleared:Fire()
    return true
end

function API:BindHitNotification(callback, replayActive)
    if self.Destroyed then return nil, "API destroyed" end
    if type(callback) ~= "function" then return nil, "expected a callback" end
    local connection = self.HitNotification.Event:Connect(function(hit)
        callback(hit, self)
    end)
    if replayActive then
        for _, hit in ipairs(self:GetHitNotifications()) do callback(hit, self) end
    end
    return connection
end

function API:ConfigPath(name)
    name = safe_name(name)
    return name and (self.ConfigDirectory .. "/" .. name .. ".json") or nil
end

function API:SaveConfig(name)
    if self.Destroyed then return false, "API destroyed" end
    local path = self:ConfigPath(name)
    if not path then return false, "invalid config name" end
    if not ensure_directory(self.ConfigDirectory) or type(writefile) ~= "function" then
        return false, "file API unavailable"
    end
    local colors = {}
    for key, color in pairs(self.Colors) do
        colors[key] = { math.floor(color.R * 255 + 0.5), math.floor(color.G * 255 + 0.5), math.floor(color.B * 255 + 0.5) }
    end
    local customDefaults = copy(self.Defaults)
    local savedState = copy(self.State)
    for key in pairs(transientStateKeys) do savedState[key] = nil end
    local ok, err = pcall(function()
        local json = HttpService:JSONEncode({ version = self.Version,
            state = savedState, customDefaults = customDefaults, colors = colors,
            colorAlpha = self.ColorAlpha, colorOptions = self.ColorOptions })
        writefile(path, json)
    end)
    if not ok then return false, tostring(err) end
    self.LoadedConfig = name
    return true
end

function API:LoadConfig(name)
    if self.Destroyed then return false, "API destroyed" end
    local path = self:ConfigPath(name)
    if not path then return false, "invalid config name" end
    if type(isfile) ~= "function" or type(readfile) ~= "function" then
        return false, "config not found"
    end
    local existsOk, exists = pcall(isfile, path)
    if not existsOk or not exists then return false, "config not found" end
    local ok, data = pcall(function() return HttpService:JSONDecode(readfile(path)) end)
    if not ok or type(data) ~= "table" then return false, "invalid config" end
    if type(data.customDefaults) == "table" then
        for key, value in pairs(data.customDefaults) do
            if not self:Has(key) then self:Register(key, value) end
        end
    end
    for key, value in pairs(type(data.state) == "table" and data.state or {}) do
        if not transientStateKeys[key] and self:Has(key)
            and type(value) == type(self.Defaults[key]) then
            self:Set(key, value)
        end
    end
    for key, rgb in pairs(type(data.colors) == "table" and data.colors or {}) do
        if self.ColorDefaults[key] and type(rgb) == "table" then
            local r, g, b = tonumber(rgb[1]), tonumber(rgb[2]), tonumber(rgb[3])
            if finite_number(r) and finite_number(g) and finite_number(b) then
                self:SetColor(key, Color3.fromRGB(math.clamp(r, 0, 255), math.clamp(g, 0, 255), math.clamp(b, 0, 255)))
            end
        end
    end
    for key, alpha in pairs(type(data.colorAlpha) == "table" and data.colorAlpha or {}) do
        if self.ColorAlpha[key] ~= nil then self:SetColorAlpha(key, alpha) end
    end
    for key, options in pairs(type(data.colorOptions) == "table" and data.colorOptions or {}) do
        if self.ColorOptions[key] and type(options) == "table" then
            for option, value in pairs(options) do self:SetColorOption(key, option, value) end
        end
    end
    self.LoadedConfig = name
    return true
end

function API:ListConfigs()
    local names = {}
    if self.Destroyed or not ensure_directory(self.ConfigDirectory) or type(listfiles) ~= "function" then
        return names
    end
    local ok, files = pcall(listfiles, self.ConfigDirectory)
    if ok and type(files) == "table" then
        for _, path in ipairs(files) do
            local name = path:match("([^/\\]+)%.json$")
            if name then names[#names + 1] = name end
        end
    end
    table.sort(names)
    return names
end

function API:DeleteConfig(name)
    if self.Destroyed then return false, "API destroyed" end
    local path = self:ConfigPath(name)
    if not path or type(delfile) ~= "function" or type(isfile) ~= "function" then
        return false, "config not found"
    end
    local existsOk, exists = pcall(isfile, path)
    if not existsOk or not exists then return false, "config not found" end
    local ok, err = pcall(delfile, path)
    if not ok then return false, tostring(err) end
    if self.LoadedConfig == name then self.LoadedConfig = nil end
    return true
end

function API:Reset()
    if self.Destroyed then return false, "API destroyed" end
    for key, value in pairs(self.Defaults) do self:Set(key, value) end
    for key, color in pairs(self.ColorDefaults) do self:SetColor(key, color) end
    for key, value in pairs(self.ColorAlphaDefaults) do self:SetColorAlpha(key, value) end
    for key, options in pairs(self.ColorOptionsDefaults) do
        for option, value in pairs(options) do self:SetColorOption(key, option, value) end
    end
    self:ClearHitNotifications()
    self.LoadedConfig = nil
    return true
end

function API:Destroy()
    if self.Destroyed then return end
    self.Destroyed = true
    self.HitNotifications = {}
    self.Changed:Destroy()
    self.TargetChanged:Destroy()
    self.HitNotification:Destroy()
    self.HitNotificationsCleared:Destroy()
end

if type(getgenv) == "function" then getgenv().__SenseLuaMenuApiFactory = API end
return API
