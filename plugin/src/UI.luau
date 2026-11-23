-- ClipForge UI kit: small, theme-aware building blocks for the dock widget (follows Studio light/dark theme).

local UI = {}

local ACCENT = Color3.fromRGB(124, 92, 255)
local ACCENT_HOVER = Color3.fromRGB(143, 117, 255)
local OK = Color3.fromRGB(64, 200, 130)
local WARN = Color3.fromRGB(255, 176, 64)
local BAD = Color3.fromRGB(255, 92, 92)
UI.ACCENT, UI.OK, UI.WARN, UI.BAD = ACCENT, OK, WARN, BAD

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

-- theme -----------------------------------------------------------------------------------------------------------
local themed = {} -- { inst, prop, role }
local function themeColor(role: string): Color3
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

function UI.bind(inst: Instance, prop: string, role: string)
	(inst :: any)[prop] = themeColor(role)
	table.insert(themed, { inst, prop, role })
end

function UI.refreshTheme()
	for i = #themed, 1, -1 do
		local t = themed[i]
		if t[1].Parent == nil and not t[1]:IsDescendantOf(game) then
			-- keep: widgets live outside the DataModel; only drop destroyed ones
		end
		pcall(function()
			(t[1] :: any)[t[2]] = themeColor(t[3])
		end)
	end
end
settings().Studio.ThemeChanged:Connect(UI.refreshTheme)

-- helpers ---------------------------------------------------------------------------------------------------------
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
	u.PaddingTop = UDim.new(0, a)
	u.PaddingRight = UDim.new(0, b or a)
	u.PaddingBottom = UDim.new(0, c or a)
	u.PaddingLeft = UDim.new(0, d or b or a)
	u.Parent = p
	return u
end
UI.pad = pad

function UI.list(p, gap, horizontal, align)
	local l = Instance.new("UIListLayout")
	l.SortOrder = Enum.SortOrder.LayoutOrder
	l.Padding = UDim.new(0, gap or 6)
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
	t.TextSize = 14
	t.TextWrapped = true
	t.RichText = true
	t.TextXAlignment = Enum.TextXAlignment.Left
	t.Text = text
	t.LayoutOrder = nextOrder()
	UI.bind(t, "TextColor3", (props and props.role) or "text")
	for k, v in props or {} do
		if k ~= "role" then
			(t :: any)[k] = v
		end
	end
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
	b.TextSize = 14
	b.Text = text
	b.LayoutOrder = nextOrder()
	corner(b, 6)
	if style == "primary" then
		b.BackgroundColor3 = ACCENT
		b.TextColor3 = Color3.new(1, 1, 1)
		b.MouseEnter:Connect(function()
			b.BackgroundColor3 = ACCENT_HOVER
		end)
		b.MouseLeave:Connect(function()
			b.BackgroundColor3 = ACCENT
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
	box.TextSize = 14
	box.Text = text or ""
	box.PlaceholderText = placeholder
	box.TextXAlignment = Enum.TextXAlignment.Left
	box.TextTruncate = Enum.TextTruncate.AtEnd
	box.LayoutOrder = nextOrder()
	UI.bind(box, "BackgroundColor3", "field")
	UI.bind(box, "TextColor3", "text")
	UI.bind(box, "PlaceholderColor3", "dim")
	corner(box, 6)
	stroke(box, "border")
	pad(box, 0, 9)
	for k, v in props or {} do
		(box :: any)[k] = v
	end
	box.Parent = parent
	return box
end

-- segmented control: one of N, returns { get(), set(v), frame }
function UI.segmented(parent, options: { string }, default: string, onChange: ((string) -> ())?, labels: { [string]: string }?)
	local f = UI.frame(parent, { AutomaticSize = Enum.AutomaticSize.None, Size = UDim2.new(1, 0, 0, 30) })
	UI.bind(f, "BackgroundColor3", "field")
	f.BackgroundTransparency = 0
	corner(f, 7)
	stroke(f, "border")
	pad(f, 2)
	local l = UI.list(f, 2, true)
	l.HorizontalFlex = Enum.UIFlexAlignment.Fill
	local value = default
	local buttons = {}
	local function paint()
		for v, b in buttons do
			if v == value then
				b.BackgroundTransparency = 0
				b.BackgroundColor3 = ACCENT
				b.TextColor3 = Color3.new(1, 1, 1)
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
		b.TextSize = 13
		b.Text = (labels and labels[v]) or v
		b.LayoutOrder = i
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
	settings().Studio.ThemeChanged:Connect(paint)
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

-- checkbox-style toggle with a label
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
	knob.BackgroundColor3 = Color3.new(1, 1, 1)
	knob.BorderSizePixel = 0
	corner(knob, 8)
	knob.Parent = box
	local lab = UI.label(row, text, { Size = UDim2.new(1, -46, 1, 0), Position = UDim2.new(0, 46, 0, 0), AutomaticSize = Enum.AutomaticSize.None, TextYAlignment = Enum.TextYAlignment.Center })
	lab.Parent = row
	local track = Instance.new("UIStroke")
	track.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	track.Parent = box
	local value = default
	local function paint()
		box.BackgroundColor3 = if value then ACCENT else themeColor("field")
		track.Color = if value then ACCENT else themeColor("dim")
		knob.BackgroundColor3 = if value then Color3.new(1, 1, 1) else themeColor("dim")
		knob.Position = if value then UDim2.new(1, -18, 0.5, -8) else UDim2.new(0, 2, 0.5, -8)
	end
	settings().Studio.ThemeChanged:Connect(paint)
	box.Activated:Connect(function()
		value = not value
		paint()
		if onChange then
			onChange(value)
		end
	end)
	paint()
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
	fill.BackgroundColor3 = ACCENT
	fill.Size = UDim2.new(0, 0, 1, 0)
	corner(fill, 3)
	fill.Parent = bar
	return {
		frame = bar,
		set = function(f: number, color: Color3?)
			fill.Size = UDim2.new(math.clamp(f, 0, 1), 0, 1, 0)
			fill.BackgroundColor3 = color or ACCENT
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

return UI
