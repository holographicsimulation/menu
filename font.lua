-- Embedded Sense pixel-font renderer.
local Font = {}

local ATLAS_BASE64 = "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"
local ASSET_PATH = "SenseLua/small_fonts_gdi_v1.png"
local CELL_WIDTH, CELL_HEIGHT, COLUMNS, ROWS = 20, 18, 16, 14

local FACES = {
    body = {
        row = 0, height = 13, line = 13, offset = 0,
        widths = "33476A83445734326466666666336766B888887983687A898988888C887333663676764773363A767746376866643453111111111111111111111111111111113366662649467486474346634346AAA6777777B7777733338888888688888787666666A6666624446666666666666575",
    },
    title = {
        row = 14, height = 14, line = 13, offset = 0,
        widths = "33476A83445734326466666666336766B888887983687A898988888C887333663676764773363A767746376866643453111111111111111111111111111111113366662649467486474346634346AAA6777777B7777733338888888688888787666666A6666624446666666666666575",
    },
    tiny = {
        row = 28, height = 12, line = 13, offset = 1,
        widths = "23466972334635336466666666336666A7777668725768787877677977633336366666366225286666353657555333321111111111111111111111111111111122666626384662853633365332358885777777A666663333778888858777767666666696666623335666666466666565",
    },
    esp = {
        row = 42, height = 10, line = 10, offset = 0,
        widths = "22464552333423235355545455224445866665565245486656655668665333453454543542242645553434464443234211111111111111111111111111111111224544243635526424222542323566646666668555552333666666646666665544444464444423335455555454444444",
    },
}

local attached = setmetatable({}, { __mode = "k" })
local atlasAsset

local function base64_decode(value)
    if crypt and type(crypt.base64decode) == "function" then
        local ok, decoded = pcall(crypt.base64decode, value)
        if ok and type(decoded) == "string" then return decoded end
    end
    local alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
    local map = {}
    for index = 1, #alphabet do map[alphabet:byte(index)] = index - 1 end
    local output, accumulator, bits = {}, 0, 0
    for index = 1, #value do
        local digit = map[value:byte(index)]
        if digit then
            accumulator = accumulator * 64 + digit
            bits = bits + 6
            if bits >= 8 then
                bits = bits - 8
                output[#output + 1] = string.char(math.floor(accumulator / 2 ^ bits) % 256)
                accumulator = accumulator % 2 ^ bits
            end
        end
    end
    return table.concat(output)
end

local function ensure_asset()
    if atlasAsset then return atlasAsset end
    local ok, asset = pcall(function()
        if type(getcustomasset) ~= "function" or type(writefile) ~= "function"
            or type(isfile) ~= "function" or type(makefolder) ~= "function"
            or type(isfolder) ~= "function" then return nil end
        if not isfolder("SenseLua") then makefolder("SenseLua") end
        if not isfile(ASSET_PATH) then writefile(ASSET_PATH, base64_decode(ATLAS_BASE64)) end
        return getcustomasset(ASSET_PATH)
    end)
    if ok and type(asset) == "string" and asset ~= "" then
        atlasAsset = asset
        return asset
    end
    return nil
end

local function advance(face, codepoint)
    local index = codepoint - 31
    if index < 1 or index > 224 then return 0 end
    local encoded = face.widths:byte(index)
    if not encoded then return 0 end
    return encoded <= 57 and encoded - 48 or encoded - 55
end

local function glyphs_for(text)
    local output = {}
    local supported = true
    local ok = pcall(function()
        for _, codepoint in utf8.codes(text) do
            if codepoint > 255 and codepoint ~= 8230 then
                supported = false
                return
            end
            if codepoint == 8230 then
                output[#output + 1] = 46
                output[#output + 1] = 46
                output[#output + 1] = 46
            else
                output[#output + 1] = codepoint
            end
        end
    end)
    return ok and supported and output or nil
end

local function is_text_host(instance)
    return instance:IsA("TextLabel") or instance:IsA("TextButton")
end

local function choose_kind(host)
    local node = host.Parent
    while node do
        if node.Name == "HeaderCell2" then return "title", 0.75, 1 end
        if node.Name == "HeaderCell3" then return "title", -0.22, 1 end
        node = node.Parent
    end
    local size = host.TextSize
    if size <= 10 then return "esp", 0, 0 end
    if size == 12 then return "tiny", 0, 0 end
    return "body", 0, 0
end

local Attachment = {}
Attachment.__index = Attachment

function Attachment:_colors()
    if not self.overlay then return end
    local color = self.host.TextColor3
    for _, glyph in ipairs(self.glyphs) do
        glyph.ImageColor3 = color
        glyph.ImageTransparency = self.transparency
    end
end

local function make_image(parent, image, zIndex)
    local glyph = Instance.new("ImageLabel")
    glyph.Name = "Glyph"
    glyph.BackgroundTransparency = 1
    glyph.BorderSizePixel = 0
    glyph.Image = image
    glyph.ScaleType = Enum.ScaleType.Stretch
    glyph.Active = false
    glyph.Selectable = false
    glyph.ZIndex = zIndex
    pcall(function() glyph.ResampleMode = Enum.ResamplerMode.Pixelated end)
    pcall(function() glyph.Interactable = false end)
    glyph.Parent = parent
    return glyph
end

function Attachment:_render()
    if not self.overlay or not self.host.Parent then return end
    local host, face = self.host, FACES[self.kind]
    local text = self.text
    local codes = glyphs_for(text)
    if not codes then
        -- Let Roblox draw unusual Unicode such as icon-font symbols.
        self.overlay.Visible = false
        if host.Text ~= self.text then
            self.pendingNativeText = self.text
            host.Text = self.text
        end
        return
    end
    self.overlay.Visible = true
    if host.Text ~= "" then
        self.pendingBlank = (self.pendingBlank or 0) + 1
        host.Text = ""
    end

    local lines = { { codes = {}, width = 0 } }
    for _, codepoint in ipairs(codes) do
        if codepoint == 10 then
            lines[#lines + 1] = { codes = {}, width = 0 }
        elseif codepoint == 9 then
            local line = lines[#lines]
            for _ = 1, 4 do
                line.codes[#line.codes + 1] = 32
                line.width = line.width + advance(face, 32)
            end
        elseif codepoint >= 32 and codepoint <= 255 then
            local line = lines[#lines]
            line.codes[#line.codes + 1] = codepoint
            line.width = line.width + advance(face, codepoint)
        end
    end
    for _, line in ipairs(lines) do
        line.width = line.width + math.max(0, #line.codes - 1) * self.tracking
    end

    local size = host.AbsoluteSize
    local totalHeight = #lines * face.line
    local y = 0
    if host.TextYAlignment == Enum.TextYAlignment.Center then
        y = math.floor((size.Y - totalHeight) * 0.5 + 0.5)
    elseif host.TextYAlignment == Enum.TextYAlignment.Bottom then
        y = size.Y - totalHeight
    end
    local visibleGlyphs = 0
    for _, line in ipairs(lines) do
        local x = 0
        if host.TextXAlignment == Enum.TextXAlignment.Center then
            x = math.floor((size.X - line.width) * 0.5 + 0.5)
        elseif host.TextXAlignment == Enum.TextXAlignment.Right then
            x = size.X - line.width
        end
        for _, codepoint in ipairs(line.codes) do
            local width = advance(face, codepoint)
            if codepoint ~= 32 and width > 0 then
                visibleGlyphs = visibleGlyphs + 1
                local glyph = self.glyphs[visibleGlyphs]
                if not glyph then
                    glyph = make_image(self.overlay, self.asset, host.ZIndex + 1)
                    self.glyphs[visibleGlyphs] = glyph
                end
                local index = codepoint - 32
                glyph.ImageRectOffset = Vector2.new(
                    (index % COLUMNS) * CELL_WIDTH,
                    (face.row + math.floor(index / COLUMNS)) * CELL_HEIGHT
                )
                glyph.ImageRectSize = Vector2.new(width, face.height)
                glyph.Position = UDim2.fromOffset(math.floor(x), y + face.offset + self.yOffset)
                glyph.Size = UDim2.fromOffset(width, face.height)
                glyph.ZIndex = host.ZIndex + 1
                glyph.Visible = true
            end
            x = x + width + self.tracking
        end
        y = y + face.line
    end
    for index = visibleGlyphs + 1, #self.glyphs do self.glyphs[index].Visible = false end
    self:_colors()
end

function Attachment:SetKind(kind)
    if not FACES[kind] then return false end
    self.kind = kind
    self:_render()
    return true
end

function Attachment:Destroy()
    if self.destroyed then return end
    self.destroyed = true
    attached[self.host] = nil
    for _, connection in ipairs(self.connections) do connection:Disconnect() end
    if self.overlay then self.overlay:Destroy(); self.overlay = nil end
    pcall(function() self.host.Text = self.text end)
end

function Font.attach(host, kind)
    if not host or not is_text_host(host) then return nil end
    local previous = attached[host]
    if previous then
        if kind then previous:SetKind(kind) end
        return previous
    end
    local asset = ensure_asset()
    if not asset then return nil end
    local detectedKind, tracking, yOffset = choose_kind(host)
    local faceKind = kind or detectedKind
    if not FACES[faceKind] or not glyphs_for(host.Text) then return nil end
    local overlay = Instance.new("Frame")
    overlay.Name = "SensePixelText"
    overlay.BackgroundTransparency = 1
    overlay.BorderSizePixel = 0
    overlay.Size = UDim2.fromScale(1, 1)
    overlay.ClipsDescendants = true
    overlay.Active = false
    overlay.Selectable = false
    overlay.ZIndex = host.ZIndex + 1
    pcall(function() overlay.Interactable = false end)
    overlay.Parent = host
    local self = setmetatable({
        host = host, overlay = overlay, asset = asset, kind = faceKind,
        text = host.Text, transparency = host.TextTransparency,
        glyphs = {}, connections = {},
        tracking = tracking, yOffset = yOffset,
    }, Attachment)
    attached[host] = self
    local function listen(property, callback)
        self.connections[#self.connections + 1] = host:GetPropertyChangedSignal(property):Connect(callback)
    end
    listen("Text", function()
        local value = host.Text
        if value == "" and self.pendingBlank and self.pendingBlank > 0 then
            self.pendingBlank = self.pendingBlank - 1
            return
        end
        if value == self.pendingNativeText then
            self.pendingNativeText = nil
            return
        end
        self.text = value
        self:_render()
    end)
    listen("TextColor3", function() self:_colors() end)
    listen("TextTransparency", function()
        self.transparency = host.TextTransparency
        self:_colors()
    end)
    listen("AbsoluteSize", function() self:_render() end)
    listen("TextXAlignment", function() self:_render() end)
    listen("TextYAlignment", function() self:_render() end)
    listen("ZIndex", function()
        overlay.ZIndex = host.ZIndex + 1
        for _, glyph in ipairs(self.glyphs) do glyph.ZIndex = overlay.ZIndex end
    end)
    self.connections[#self.connections + 1] = host.AncestryChanged:Connect(function(_, parent)
        if parent == nil then self:Destroy() end
    end)
    self:_render()
    return self
end

function Font.decorate(root, options)
    if typeof(root) ~= "Instance" then return nil end
    options = options or {}
    local owned = setmetatable({}, { __mode = "k" })
    local function attach_if_text(instance)
        if not is_text_host(instance) then return end
        local kind = options.kindForLabel and options.kindForLabel(instance) or nil
        if kind == false then return end
        local attachment = Font.attach(instance, kind)
        if attachment then owned[attachment] = true end
    end
    if is_text_host(root) then attach_if_text(root) end
    for _, descendant in ipairs(root:GetDescendants()) do attach_if_text(descendant) end
    local connection = root.DescendantAdded:Connect(function(instance)
        if is_text_host(instance) then task.defer(function()
            if instance.Parent then attach_if_text(instance) end
        end) end
    end)
    local decoration = {}
    function decoration:Destroy()
        connection:Disconnect()
        for attachment in pairs(owned) do attachment:Destroy() end
        table.clear(owned)
    end
    return decoration
end

Font.Faces = FACES
Font.AssetPath = ASSET_PATH
pcall(function() getgenv().__SenseSmallFontModule = Font end)
return Font
