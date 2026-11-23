-- ClipForge UI kit: small building blocks for the dock widget, with a live theme.
-- Theme: mode (studio = follow Studio, dark, midnight, light), accent colour, text scale, density. Everything built
-- with this kit re-colours, re-sizes and re-spaces itself when the theme changes (UI.setTheme).

local UI = {}

UI.OK = Color3.fromRGB(64, 200, 130)
UI.WARN = Color3.fromRGB(255, 176, 64)
UI.BAD = Color3.fromRGB(255, 92, 92)

UI.ACCENTS = {
	{ "Violet", Color3.fromRGB(124, 92, 255) }, { "Blue", Color3.fromRGB(61, 139, 255) },
	{ "Cyan", Color3.fromRGB(18, 184, 214) }, { "Green", Color3.fromRGB(47, 191, 113) },
	{ "Gold", Color3.fromRGB(224, 165, 38) }, { "Orange", Color3.fromRGB(255, 138, 61) },
	{ "Pink", Color3.fromRGB(255, 79, 163) }, { "Red", Color3.fromRGB(240, 75, 75) },
}

local PRESETS = {
	dark = { bg = "#1E1F24", panel = "#26282E", field = "#1A1B20", text = "#E8E9ED", dim = "#9A9DA8", border = "#34363E",
		button = "#2C2E35", buttonHover = "#363944" },
	midnight = { bg = "#0E1018", panel = "#151826", field = "#0B0D14", text = "#E6E8F2", dim = "#8E93A8", border = "#23273A",
		button = "#1A1E2E", buttonHover = "#242A40" },
	light = { bg = "#F4F5F8", panel = "#FFFFFF", field = "#EEF0F4", text = "#1E2028", dim = "#666B79", border = "#D5D8E0",
		button = "#FFFFFF", buttonHover = "#EBEEF4" },
}

UI.theme = { mode = "studio", accent = UI.ACCENTS[1][2], scale = 1, density = "comfortable" }
UI.ACCENT = UI.theme.accent

local function hex(h)
	local r, g, b = string.match(h, "#(%x%x)(%x%x)(%x%x)")
	return Color3.fromRGB(tonumber(r, 16), tonumber(g, 16), tonumber(b, 16))
end

local function font(weight)
	local ok, f = pcall(Font.new, "rbxasset://fonts/families/BuilderSans.json", weight or Enum.FontWeight.Regular)
	if ok then
		return f
	end
	return Font.fromEnum(Enum.Font.GothamMedium)
end
UI.FONT = font(Enum.FontWeight.Regular)
UI.FONT_MED = font(Enum.FontWeight.Medium)
UI.FONT_BOLD = font(Enum.FontWeight.Bold)

------------------------------------------------------------------------------------------------------------ theme
local function themeColor(role: string): Color3
	if role == "accent" then
		return UI.theme.accent
	elseif role == "accentHover" then
		return UI.theme.accent:Lerp(Color3.new(1, 1, 1), 0.15)
	elseif role == "onAccent" then
		local _, _, v = UI.theme.accent:ToHSV()
		return if v > 0.85 and (UI.theme.accent.R + UI.theme.accent.G) > 1.6 then Color3.fromRGB(20, 20, 28) else Color3.new(1, 1, 1)
	end
	local p = PRESETS[UI.theme.mode]
	if p and p[role] then
		return hex(p[role])
	end
	local theme = settings().Studio.Theme
	local C = Enum.StudioStyleGuideColor
	if role == "bg" then
		return theme:GetColor(C.MainBackground)
	elseif role == "panel" then
		return theme:GetColor(C.MainBackground):Lerp(theme:GetColor(C.MainText), 0.05)
	elseif role == "field" then
		return theme:GetColor(C.InputFieldBackground)
	elseif role == "text" then
		return theme:GetColor(C.MainText)
	elseif role == "dim" then
		return theme:GetColor(C.DimmedText)
	elseif role == "border" then
		return theme:GetColor(C.Border)
	elseif role == "button" then
		return theme:GetColor(C.Button)
	elseif role == "buttonHover" then
		return theme:GetColor(C.Button, Enum.StudioStyleGuideModifier.Hover)
	end
	return theme:GetColor(C.MainText)
end
UI.color = themeColor

function UI.accent(): Color3
	return UI.theme.accent
end

local bound = {} -- { inst, prop, role }
local texts = {} -- { inst, baseSize }
local spacings = {} -- { inst, prop, base }
local repaints = {} -- callbacks

function UI.bind(inst: Instance, prop: string, role: string)
	(inst :: any)[prop] = themeColor(role)
	table.insert(bound, { inst, prop, role })
end

-- Register something to re-run whenever the theme changes (custom paints, tab highlights...).
function UI.onTheme(fn)
	table.insert(repaints, fn)
	return fn
end

local function textSize(inst, base)
	inst.TextSize = math.floor(base * UI.theme.scale + 0.5)
	table.insert(texts, { inst, base })
end
UI.textSize = textSize

local function densityK()
	return if UI.theme.density == "compact" then 0.6 else 1
end

local function spacing(inst, prop, base)
	(inst :: any)[prop] = UDim.new(0, math.floor(base * densityK() + 0.5))
	table.insert(spacings, { inst, prop, base })
end

function UI.applyTheme()
	UI.ACCENT = UI.theme.accent
	for _, t in bound do
		pcall(function()
			(t[1] :: any)[t[2]] = themeColor(t[3])
		end)
	end
	for _, t in texts do
		pcall(function()
			t[1].TextSize = math.floor(t[2] * UI.theme.scale + 0.5)
		end)
	end
	for _, t in spacings do
		pcall(function()
			(t[1] :: any)[t[2]] = UDim.new(0, math.floor(t[3] * densityK() + 0.5))
		end)
	end
	for _, fn in repaints do
		pcall(fn)
	end
end

function UI.setTheme(patch)
	for k, v in patch do
		UI.theme[k] = v
	end
	UI.applyTheme()
end

settings().Studio.ThemeChanged:Connect(function()
	if UI.theme.mode == "studio" then
		UI.applyTheme()
	end
end)

------------------------------------------------------------------------------------------------------- helpers
local function corner(p, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r or 6)
	c.Parent = p
	return c
end
UI.corner = corner

local function stroke(p, role, t)
	local s = Instance.new("UIStroke")
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Thickness = t or 1
	UI.bind(s, "Color", role or "border")
	s.Parent = p
	return s
end
UI.stroke = stroke

local function pad(p, a, b, c, d)
	local u = Instance.new("UIPadding")
	spacing(u, "PaddingTop", a)
	spacing(u, "PaddingRight", b or a)
	spacing(u, "PaddingBottom", c or a)
	spacing(u, "PaddingLeft", d or b or a)
	u.Parent = p
	return u
end
UI.pad = pad

function UI.list(p, gap, horizontal, align)
	local l = Instance.new("UIListLayout")
	l.SortOrder = Enum.SortOrder.LayoutOrder
	spacing(l, "Padding", gap or 6)
	l.FillDirection = if horizontal then Enum.FillDirection.Horizontal else Enum.FillDirection.Vertical
	if align then
		l.VerticalAlignment = align
	end
	l.Parent = p
	return l
end

local order = 0
local function nextOrder()
	order += 1
	return order
end
UI.nextOrder = nextOrder

function UI.frame(parent, props)
	local f = Instance.new("Frame")
	f.BackgroundTransparency = 1
	f.BorderSizePixel = 0
	f.Size = UDim2.new(1, 0, 0, 0)
	f.AutomaticSize = Enum.AutomaticSize.Y
	f.LayoutOrder = nextOrder()
	for k, v in props or {} do
		(f :: any)[k] = v
	end
	f.Parent = parent
	return f
end

function UI.row(parent, gap, height)
	local f = UI.frame(parent, { AutomaticSize = Enum.AutomaticSize.None, Size = UDim2.new(1, 0, 0, height or 28) })
	local l = UI.list(f, gap or 6, true, Enum.VerticalAlignment.Center)
	return f, l
end

function UI.card(parent, title: string?)
	local f = UI.frame(parent)
	UI.bind(f, "BackgroundColor3", "panel")
	f.BackgroundTransparency = 0
	corner(f, 8)
	stroke(f, "border")
	pad(f, 10)
	UI.list(f, 8)
	if title then
		UI.label(f, title, { FontFace = UI.FONT_BOLD, TextSize = 15 })
	end
	return f
end

function UI.label(parent, text: string, props)
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.new(1, 0, 0, 0)
	t.AutomaticSize = Enum.AutomaticSize.Y
	t.FontFace = UI.FONT
	t.TextWrapped = true
	t.RichText = true
	t.TextXAlignment = Enum.TextXAlignment.Left
	t.Text = text
	t.LayoutOrder = nextOrder()
	UI.bind(t, "TextColor3", (props and props.role) or "text")
	local size = (props and props.TextSize) or 14
	for k, v in props or {} do
		if k ~= "role" and k ~= "TextSize" then
			(t :: any)[k] = v
		end
	end
	textSize(t, size)
	t.Parent = parent
	return t
end

function UI.dim(parent, text: string, size: number?)
	return UI.label(parent, text, { role = "dim", TextSize = size or 13 })
end

function UI.button(parent, text: string, style: string?, onClick: (() -> ())?, width: number?)
	style = style or "secondary"
	local b = Instance.new("TextButton")
	b.AutoButtonColor = false
	b.Size = if width then UDim2.new(0, width, 0, 30) else UDim2.new(1, 0, 0, 32)
	b.FontFace = UI.FONT_MED
	b.Text = text
	b.LayoutOrder = nextOrder()
	textSize(b, 14)
	corner(b, 6)
	local hover = false
	if style == "primary" then
		local function paint()
			b.BackgroundColor3 = themeColor(if hover then "accentHover" else "accent")
			b.TextColor3 = themeColor("onAccent")
		end
		paint()
		UI.onTheme(paint)
		b.MouseEnter:Connect(function()
			hover = true
			paint()
		end)
		b.MouseLeave:Connect(function()
			hover = false
			paint()
		end)
	elseif style == "ghost" then
		b.BackgroundTransparency = 1
		UI.bind(b, "TextColor3", "dim")
	else
		UI.bind(b, "BackgroundColor3", "button")
		UI.bind(b, "TextColor3", "text")
		stroke(b, "border")
		b.MouseEnter:Connect(function()
			b.BackgroundColor3 = themeColor("buttonHover")
		end)
		b.MouseLeave:Connect(function()
			b.BackgroundColor3 = themeColor("button")
		end)
	end
	if onClick then
		b.Activated:Connect(function()
			local ok, err = pcall(onClick)
			if not ok then
				warn("[ClipForge] " .. tostring(err))
			end
		end)
	end
	b.Parent = parent
	return b
end

function UI.input(parent, placeholder: string, text: string?, props)
	local box = Instance.new("TextBox")
	box.Size = UDim2.new(1, 0, 0, 32)
	box.ClearTextOnFocus = false
	box.FontFace = UI.FONT
	box.Text = text or ""
	box.PlaceholderText = placeholder
	box.TextXAlignment = Enum.TextXAlignment.Left
	box.TextTruncate = Enum.TextTruncate.AtEnd
	box.LayoutOrder = nextOrder()
	textSize(box, 14)
	UI.bind(box, "BackgroundColor3", "field")
	UI.bind(box, "TextColor3", "text")
	UI.bind(box, "PlaceholderColor3", "dim")
	corner(box, 6)
	stroke(box, "border")
	local p = Instance.new("UIPadding")
	p.PaddingLeft = UDim.new(0, 9)
	p.PaddingRight = UDim.new(0, 9)
	p.Parent = box
	for k, v in props or {} do
		(box :: any)[k] = v
	end
	box.Parent = parent
	return box
end

-- segmented control: one of N. Returns { get(), set(v), frame }
function UI.segmented(parent, options: { string }, default: string, onChange: ((string) -> ())?, labels: { [string]: string }?)
	local f = UI.frame(parent, { AutomaticSize = Enum.AutomaticSize.None, Size = UDim2.new(1, 0, 0, 30) })
	UI.bind(f, "BackgroundColor3", "field")
	f.BackgroundTransparency = 0
	corner(f, 7)
	stroke(f, "border")
	local p = Instance.new("UIPadding")
	p.PaddingTop, p.PaddingBottom, p.PaddingLeft, p.PaddingRight = UDim.new(0, 2), UDim.new(0, 2), UDim.new(0, 2), UDim.new(0, 2)
	p.Parent = f
	local l = Instance.new("UIListLayout")
	l.FillDirection = Enum.FillDirection.Horizontal
	l.SortOrder = Enum.SortOrder.LayoutOrder
	l.Padding = UDim.new(0, 2)
	l.HorizontalFlex = Enum.UIFlexAlignment.Fill
	l.Parent = f
	local value = default
	local buttons = {}
	local function paint()
		for v, b in buttons do
			if v == value then
				b.BackgroundTransparency = 0
				b.BackgroundColor3 = themeColor("accent")
				b.TextColor3 = themeColor("onAccent")
			else
				b.BackgroundTransparency = 1
				b.TextColor3 = themeColor("text")
			end
		end
	end
	for i, v in options do
		local b = Instance.new("TextButton")
		b.AutoButtonColor = false
		b.Size = UDim2.new(0, 10, 1, 0)
		b.FontFace = UI.FONT_MED
		b.Text = (labels and labels[v]) or v
		b.LayoutOrder = i
		textSize(b, 13)
		corner(b, 5)
		b.Parent = f
		buttons[v] = b
		b.Activated:Connect(function()
			value = v
			paint()
			if onChange then
				onChange(v)
			end
		end)
	end
	paint()
	UI.onTheme(paint)
	return {
		frame = f,
		get = function()
			return value
		end,
		set = function(v)
			value = v
			paint()
		end,
	}
end

-- wrapping grid of selectable chips: one of N (or many with multi = true)
function UI.chips(parent, options: { string }, default, onChange, opts)
	opts = opts or {}
	local f = UI.frame(parent)
	local g = Instance.new("UIGridLayout")
	g.CellSize = UDim2.new(1 / (opts.columns or 4), -5, 0, opts.height or 26)
	g.CellPadding = UDim2.new(0, 5, 0, 5)
	g.SortOrder = Enum.SortOrder.LayoutOrder
	g.Parent = f
	local value = default
	local buttons = {}
	local function paint()
		for v, b in buttons do
			local on = v == value
			b.BackgroundColor3 = if on then themeColor("accent") else themeColor("field")
			b.TextColor3 = if on then themeColor("onAccent") else themeColor("text")
		end
	end
	for i, v in options do
		local b = Instance.new("TextButton")
		b.AutoButtonColor = false
		b.Text = (opts.labels and opts.labels[v]) or v
		b.FontFace = UI.FONT_MED
		b.LayoutOrder = i
		textSize(b, 12)
		corner(b, 5)
		b.Parent = f
		buttons[v] = b
		b.Activated:Connect(function()
			value = v
			paint()
			if onChange then
				onChange(v)
			end
		end)
	end
	paint()
	UI.onTheme(paint)
	return {
		frame = f,
		get = function()
			return value
		end,
		set = function(v)
			value = v
			paint()
		end,
	}
end

-- switch-style toggle with a label
function UI.toggle(parent, text: string, default: boolean, onChange: ((boolean) -> ())?)
	local row = UI.frame(parent, { AutomaticSize = Enum.AutomaticSize.None, Size = UDim2.new(1, 0, 0, 24) })
	local box = Instance.new("TextButton")
	box.AutoButtonColor = false
	box.Size = UDim2.new(0, 36, 0, 20)
	box.Position = UDim2.new(0, 0, 0.5, -10)
	box.Text = ""
	corner(box, 10)
	box.Parent = row
	local knob = Instance.new("Frame")
	knob.Size = UDim2.new(0, 16, 0, 16)
	knob.BorderSizePixel = 0
	corner(knob, 8)
	knob.Parent = box
	local track = Instance.new("UIStroke")
	track.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	track.Parent = box
	local lab = UI.label(row, text, { Size = UDim2.new(1, -46, 1, 0), Position = UDim2.new(0, 46, 0, 0),
		AutomaticSize = Enum.AutomaticSize.None, TextYAlignment = Enum.TextYAlignment.Center })
	lab.Parent = row
	local value = default
	local function paint()
		box.BackgroundColor3 = if value then themeColor("accent") else themeColor("field")
		track.Color = if value then themeColor("accent") else themeColor("dim")
		knob.BackgroundColor3 = if value then themeColor("onAccent") else themeColor("dim")
		knob.Position = if value then UDim2.new(1, -18, 0.5, -8) else UDim2.new(0, 2, 0.5, -8)
	end
	box.Activated:Connect(function()
		value = not value
		paint()
		if onChange then
			onChange(value)
		end
	end)
	paint()
	UI.onTheme(paint)
	return {
		frame = row,
		get = function()
			return value
		end,
		set = function(v)
			value = v
			paint()
		end,
	}
end

function UI.progress(parent)
	local bar = UI.frame(parent, { AutomaticSize = Enum.AutomaticSize.None, Size = UDim2.new(1, 0, 0, 6) })
	UI.bind(bar, "BackgroundColor3", "field")
	bar.BackgroundTransparency = 0
	corner(bar, 3)
	local fill = Instance.new("Frame")
	fill.BorderSizePixel = 0
	fill.BackgroundColor3 = themeColor("accent")
	fill.Size = UDim2.new(0, 0, 1, 0)
	corner(fill, 3)
	fill.Parent = bar
	local custom = nil
	UI.onTheme(function()
		if not custom then
			fill.BackgroundColor3 = themeColor("accent")
		end
	end)
	return {
		frame = bar,
		set = function(f: number, color: Color3?)
			custom = color
			fill.Size = UDim2.new(math.clamp(f, 0, 1), 0, 1, 0)
			fill.BackgroundColor3 = color or themeColor("accent")
		end,
	}
end

function UI.swatch(parent, color: Color3, size: number?, onClick: (() -> ())?)
	local b = Instance.new("TextButton")
	b.AutoButtonColor = false
	b.Text = ""
	b.Size = UDim2.new(0, size or 22, 0, size or 22)
	b.BackgroundColor3 = color
	b.LayoutOrder = nextOrder()
	corner(b, 5)
	stroke(b, "border")
	if onClick then
		b.Activated:Connect(onClick)
	end
	b.Parent = parent
	return b
end

function UI.scroll(parent)
	local s = Instance.new("ScrollingFrame")
	s.Size = UDim2.new(1, 0, 1, 0)
	s.BackgroundTransparency = 1
	s.BorderSizePixel = 0
	s.ScrollBarThickness = 6
	s.AutomaticCanvasSize = Enum.AutomaticSize.Y
	s.CanvasSize = UDim2.new(0, 0, 0, 0)
	s.ScrollingDirection = Enum.ScrollingDirection.Y
	UI.bind(s, "ScrollBarImageColor3", "border")
	s.Parent = parent
	pad(s, 10, 12, 16, 10)
	UI.list(s, 10)
	return s
end

function UI.clear(container: Instance)
	for _, c in container:GetChildren() do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
end

-- drop registry entries for destroyed instances (call after clearing big lists)
function UI.prune()
	local function keep(list)
		for i = #list, 1, -1 do
			local inst = list[i][1]
			if typeof(inst) == "Instance" and not inst.Parent then
				table.remove(list, i)
			end
		end
	end
	keep(bound)
	keep(texts)
	keep(spacings)
end

return UI
