-- ClipForge VFX tab: generate showcase effects from a description, browse/search the library, recolour, preview, insert.

local Tab = {}

function Tab.build(page, ctx)
	local UI, FX, Recolor, Prompt, Installer = ctx.UI, ctx.FX, ctx.Recolor, ctx.Prompt, ctx.Installer
	local Generator = ctx.Generator
	local lib = { base = "slash", palette = nil, scale = 1, speed = 1, roll = -25, parts = nil, generate = nil, seed = 1 }
	ctx.state.lib = lib
	local controls = {}
	local favourites = ctx.setting("Favourites", {})
	local savedPalettes = ctx.setting("Palettes", {})

	local function trim(s)
		return (string.gsub(s or "", "^%s*(.-)%s*$", "%1"))
	end

	local function currentConfig()
		local name = trim(controls.nameBox and controls.nameBox.Text or "")
		if lib.generate then
			return { name = if name ~= "" then name else (lib.generate.name or "Generated"), generate = lib.generate,
				palette = lib.palette, scale = lib.scale, speed = lib.speed }
		end
		local info = FX.BaseInfo[lib.base]
		return {
			name = if name ~= "" then name else (string.gsub(info and info.title or lib.base, "%s", "")),
			base = lib.base, palette = lib.palette, scale = lib.scale, speed = lib.speed, intensity = 1,
			roll = if lib.base == "slash" then lib.roll else 0, yaw = 0,
			parts = lib.parts or (info and info.combo) or nil, shake = info and info.shake,
		}
	end

	local function preview()
		local cfg = currentConfig()
		local ambient = (not lib.generate) and FX.isAmbient(cfg)
		ctx.previewEffect(cfg, (controls.loop and controls.loop.get()) and not ambient)
	end

	--------------------------------------------------------------------------------------------- generator
	local gen = UI.card(page, "Generate a VFX")
	UI.dim(gen, "Describe a showcase piece or an attack: hero shape, frames, atmosphere, colours.", 12)
	local genBox = UI.input(gen, "golden cube with light wings · galaxy wireframe cube with orbit rings · blue black hole")
	local mode = UI.chips(gen, { "auto", "showcase", "impact", "vortex" }, "auto", nil,
		{ labels = { auto = "Auto", showcase = "Showcase", impact = "Impact", vortex = "Vortex" }, columns = 4 })
	local chroma = UI.toggle(gen, "Chromatic fringes (rainbow RGB split)", false)
	local function generate(reroll)
		if reroll then
			lib.seed += 1
		end
		local text = trim(genBox.Text)
		if text == "" then
			text = "glowing cube with orbit rings and stars"
		end
		local d = Generator.fromPrompt(text, lib.seed)
		if mode.get() ~= "auto" then
			d.mode = mode.get()
		end
		if chroma.get() then
			d.chromatic = true
		end
		d.seed = lib.seed
		lib.generate = d
		lib.parts = nil
		if controls.nameBox then
			controls.nameBox.Text = d.name
		end
		ctx.setStatus("Generated: " .. d.mode .. " · " .. tostring(d.hero) .. (if #d.frames > 0 then " · " .. table.concat(d.frames, ", ") else ""), UI.OK)
		preview()
	end
	local gr = UI.row(gen, 6, 32)
	UI.button(gr, "Generate", "primary", function()
		generate(false)
	end, 110)
	UI.button(gr, "Reroll", "secondary", function()
		generate(true)
	end, 80)
	UI.dim(gen, "Showcase pieces add a soft bloom while they play. Effects stay editable configs.", 12)

	------------------------------------------------------------------------------------------------ browse
	local find = UI.card(page, "Effect library")
	local search = UI.input(find, "Search 100 effects: slash, heal, meteor, coins, rain…")
	local cats = { "All", "Favourites" }
	for _, c in FX.Library.CATEGORIES do
		table.insert(cats, c)
	end
	local catLabels = { Favourites = "★ Favs", ["Game feel"] = "Game feel" }
	local refresh
	local category = UI.chips(find, cats, "All", function()
		task.defer(refresh)
	end, { labels = catLabels, columns = 4 })
	-- results scroll on their own, so Colours / Size / Insert below stay a short scroll away
	local CELL, GAP, MAX_H = 48, 8, 300
	local results = Instance.new("ScrollingFrame")
	results.BackgroundTransparency = 1
	results.BorderSizePixel = 0
	results.Size = UDim2.new(1, 0, 0, MAX_H)
	results.CanvasSize = UDim2.new(0, 0, 0, 0)
	results.AutomaticCanvasSize = Enum.AutomaticSize.Y
	results.ScrollingDirection = Enum.ScrollingDirection.Y
	results.ScrollBarThickness = 4
	results.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar
	UI.bind(results, "ScrollBarImageColor3", "border")
	results.LayoutOrder = UI.nextOrder()
	results.Parent = find
	local rpad = Instance.new("UIPadding")
	rpad.PaddingTop = UDim.new(0, 2) -- room for the selected card's outline
	rpad.PaddingBottom = UDim.new(0, 2)
	rpad.PaddingLeft = UDim.new(0, 2)
	rpad.PaddingRight = UDim.new(0, 4)
	rpad.Parent = results
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.new(0.5, -4, 0, CELL)
	grid.CellPadding = UDim2.new(0, GAP, 0, GAP)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = results
	local countLabel = UI.dim(find, "", 12)
	local buttons = {}

	local function paintSelection()
		for id, b in buttons do
			local on = (not lib.generate) and id == lib.base
			b.stroke.Color = if on then UI.accent() else UI.color("border")
			b.stroke.Thickness = if on then 2 else 1
			b.star.TextColor3 = if favourites[id] then Color3.fromRGB(255, 200, 60) else UI.color("dim")
		end
	end
	UI.onTheme(paintSelection)

	local function strip(parent, id)
		local f = Instance.new("Frame")
		f.BackgroundTransparency = 1
		f.Position = UDim2.new(0, 8, 0, 31)
		f.Size = UDim2.new(1, -16, 0, 8)
		f.Parent = parent
		local l = Instance.new("UIListLayout")
		l.FillDirection = Enum.FillDirection.Horizontal
		l.Padding = UDim.new(0, 3)
		l.HorizontalFlex = Enum.UIFlexAlignment.Fill
		l.Parent = f
		pcall(function()
			local cols = {}
			for _, hex in FX.recipe(id).palette or {} do
				local c = Recolor.hexToColor(hex)
				if c then
					table.insert(cols, c)
				end
			end
			table.sort(cols, function(a, b)
				local _, _, va = a:ToHSV()
				local _, _, vb = b:ToHSV()
				return va > vb
			end)
			for k = 1, math.min(#cols, 6) do
				local sw = Instance.new("Frame")
				sw.BorderSizePixel = 0
				sw.Size = UDim2.new(0, 8, 1, 0)
				sw.BackgroundColor3 = cols[k]
				sw.LayoutOrder = k
				UI.corner(sw, 3)
				local edge = Instance.new("UIStroke") -- keeps white swatches visible on the light theme
				edge.Transparency = 0.3
				UI.bind(edge, "Color", "border")
				edge.Parent = sw
				sw.Parent = f
			end
		end)
	end

	function refresh()
		for _, c in results:GetChildren() do
			if c:IsA("GuiObject") then
				c:Destroy()
			end
		end
		table.clear(buttons)
		UI.prune()
		local list = FX.Library.search(search.Text, category.get(), favourites)
		for i, e in list do
			local b = Instance.new("TextButton")
			b.AutoButtonColor = false
			b.Text = ""
			b.LayoutOrder = i
			UI.bind(b, "BackgroundColor3", "field")
			UI.corner(b, 7)
			local s = Instance.new("UIStroke")
			s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			s.Parent = b
			b.Parent = results
			local t = UI.label(b, "<b>" .. e.title .. "</b>" .. (if e.ambient then "  <font transparency=\"0.45\">loop</font>" elseif e.combo then "  <font transparency=\"0.45\">combo</font>" else ""),
				{ TextSize = 13, Position = UDim2.new(0, 8, 0, 6), Size = UDim2.new(1, -34, 0, 18), AutomaticSize = Enum.AutomaticSize.None,
					TextTruncate = Enum.TextTruncate.AtEnd })
			t.Parent = b
			if not e.combo then
				strip(b, e.id)
			else
				local d = UI.dim(b, e.category, 11)
				d.AutomaticSize = Enum.AutomaticSize.None
				d.Position = UDim2.new(0, 8, 0, 27)
				d.Size = UDim2.new(1, -16, 0, 14)
			end
			local star = Instance.new("TextButton")
			star.BackgroundTransparency = 1
			star.Text = "★"
			star.TextSize = 16
			star.Size = UDim2.new(0, 24, 0, 24)
			star.Position = UDim2.new(1, -26, 0, 2)
			star.Parent = b
			star.Activated:Connect(function()
				favourites[e.id] = if favourites[e.id] then nil else true
				ctx.saveSetting("Favourites", favourites)
				paintSelection()
			end)
			buttons[e.id] = { button = b, stroke = s, star = star }
			b.Activated:Connect(function()
				lib.base = e.id
				lib.generate = nil
				lib.parts = nil
				if controls.nameBox then
					controls.nameBox.Text = string.gsub(e.title, "%s", "")
				end
				paintSelection()
				if controls.refresh then
					controls.refresh()
				end
				preview()
			end)
		end
		-- shrink to fit short result lists; long ones scroll inside the box
		local rows = math.ceil(#list / 2)
		local h = if rows == 0 then 0 else rows * (CELL + GAP) - GAP + 4
		results.Size = UDim2.new(1, 0, 0, math.min(h, MAX_H))
		results.CanvasPosition = Vector2.zero
		countLabel.Text = if #list == 0 then "No effects match. Try another word or category."
			elseif h > MAX_H then string.format("%d effects · scroll the list for more", #list)
			else string.format("%d effects", #list)
		paintSelection()
	end
	search:GetPropertyChangedSignal("Text"):Connect(refresh)
	local mr = UI.row(find, 6, 30)
	UI.button(mr, "Make from text", "secondary", function()
		local cfg = Prompt.parse(search.Text)
		lib.base, lib.palette, lib.scale, lib.speed = cfg.base, cfg.palette, cfg.scale, cfg.speed
		lib.roll = if cfg.roll ~= 0 then cfg.roll else lib.roll
		lib.parts, lib.generate = cfg.parts, nil
		if controls.nameBox then
			controls.nameBox.Text = cfg.name
		end
		if controls.refresh then
			controls.refresh()
		end
		if controls.showPalette then
			controls.showPalette()
		end
		paintSelection()
		preview()
	end, 130)
	UI.dim(mr, "Reads words like \"huge purple slash\".", 12).Size = UDim2.new(1, -140, 1, 0)
	refresh()

	---------------------------------------------------------------------------------------------- colours
	local colorCard = UI.card(page, "Colours")
	local presetFrame = UI.frame(colorCard)
	local pg = Instance.new("UIGridLayout")
	pg.CellSize = UDim2.new(0.25, -5, 0, 24)
	pg.CellPadding = UDim2.new(0, 5, 0, 5)
	pg.SortOrder = Enum.SortOrder.LayoutOrder
	pg.Parent = presetFrame
	local paletteViews = {}
	local function showPalette()
		local p = lib.palette
		for role, v in paletteViews do
			local hex = p and p[role]
			v.swatch.BackgroundColor3 = if hex then (Recolor.hexToColor(hex) or Color3.new(1, 1, 1)) else UI.color("field")
			v.box.Text = hex or ""
		end
	end
	controls.showPalette = showPalette
	local function presetButton(i, name, palette)
		local b = Instance.new("TextButton")
		b.AutoButtonColor = false
		b.Text = name
		b.FontFace = UI.FONT_MED
		b.TextSize = 12
		b.LayoutOrder = i
		UI.corner(b, 5)
		if palette then
			local c = Recolor.hexToColor(palette.primary) or Color3.new(1, 1, 1)
			b.BackgroundColor3 = c
			local _, _, v = c:ToHSV()
			b.TextColor3 = if v > 0.75 and (c.R + c.G) > 1.2 then Color3.fromRGB(20, 20, 28) else Color3.new(1, 1, 1)
		else
			UI.bind(b, "BackgroundColor3", "field")
			UI.bind(b, "TextColor3", "text")
		end
		b.Parent = presetFrame
		b.Activated:Connect(function()
			lib.palette = if palette then table.clone(palette) else nil
			showPalette()
			preview()
		end)
	end
	local function rebuildPresets()
		for _, c in presetFrame:GetChildren() do
			if c:IsA("GuiObject") then
				c:Destroy()
			end
		end
		for i, p in Recolor.Presets do
			presetButton(i, p.name, p.palette)
		end
		for i, p in savedPalettes do
			presetButton(100 + i, p.name, p.palette)
		end
	end
	rebuildPresets()
	for _, role in { "core", "primary", "secondary", "deep" } do
		local r = UI.row(colorCard, 8, 26)
		local sw = UI.swatch(r, Color3.new(1, 1, 1), 24)
		local lab = UI.label(r, string.upper(string.sub(role, 1, 1)) .. string.sub(role, 2), { Size = UDim2.new(0, 70, 1, 0),
			AutomaticSize = Enum.AutomaticSize.None, TextYAlignment = Enum.TextYAlignment.Center, TextSize = 13 })
		lab.Parent = r
		local box = UI.input(r, "#RRGGBB", "", { Size = UDim2.new(1, -110, 1, 0) })
		box.FocusLost:Connect(function()
			local hex = string.upper(trim(box.Text))
			if hex ~= "" and string.sub(hex, 1, 1) ~= "#" then
				hex = "#" .. hex
			end
			if Recolor.hexToColor(hex) then
				lib.palette = lib.palette or { core = "#FFFFFF", primary = "#7FB2FF", secondary = "#C38CFF", deep = "#101830" }
				lib.palette[role] = hex
			end
			showPalette()
		end)
		paletteViews[role] = { swatch = sw, box = box }
	end
	local sr = UI.row(colorCard, 6, 30)
	UI.button(sr, "Save palette", "secondary", function()
		if not lib.palette then
			ctx.setStatus("Pick or type colours first.", UI.WARN)
			return
		end
		table.insert(savedPalettes, { name = "Mine " .. (#savedPalettes + 1), palette = table.clone(lib.palette) })
		while #savedPalettes > 12 do
			table.remove(savedPalettes, 1)
		end
		ctx.saveSetting("Palettes", savedPalettes)
		rebuildPresets()
	end, 120)
	showPalette()

	---------------------------------------------------------------------------------------- size & timing
	local stCard = UI.card(page, "Size & timing")
	UI.dim(stCard, "Size")
	local scaleSeg = UI.segmented(stCard, { "0.6", "0.8", "1", "1.3", "1.6", "2" }, "1", function(v)
		lib.scale = tonumber(v)
	end)
	UI.dim(stCard, "Speed")
	local speedSeg = UI.segmented(stCard, { "0.6", "0.8", "1", "1.2", "1.5" }, "1", function(v)
		lib.speed = tonumber(v)
	end)
	UI.dim(stCard, "Slash angle")
	local rollSeg = UI.segmented(stCard, { "-45", "-25", "0", "25", "45", "90" }, "-25", function(v)
		lib.roll = tonumber(v)
	end)
	controls.refresh = function()
		local function nearest(seg, opts, v)
			local best, bd = opts[1], math.huge
			for _, o in opts do
				local d = math.abs(tonumber(o) - v)
				if d < bd then
					best, bd = o, d
				end
			end
			seg.set(best)
		end
		nearest(scaleSeg, { "0.6", "0.8", "1", "1.3", "1.6", "2" }, lib.scale)
		nearest(speedSeg, { "0.6", "0.8", "1", "1.2", "1.5" }, lib.speed)
		nearest(rollSeg, { "-45", "-25", "0", "25", "45", "90" }, lib.roll)
	end

	----------------------------------------------------------------------------------------- preview / insert
	local playCard = UI.card(page, "Preview & insert")
	local pr = UI.row(playCard, 6, 32)
	UI.button(pr, "Preview", "primary", preview, 110)
	UI.button(pr, "Stop", "secondary", ctx.stopEffectPreview, 70)
	controls.loop = UI.toggle(playCard, "Loop preview", false, function(on)
		if not on then
			ctx.state.fxLoop = false
		end
	end)
	UI.dim(playCard, "Plays where the camera looks (or on the selected part). Looping effects run until Stop.", 12)
	controls.nameBox = UI.input(playCard, "Effect name", "")
	UI.button(playCard, "Insert into game", "secondary", function()
		local cfg = currentConfig()
		local mod
		ctx.record("insert effect " .. cfg.name, function()
			mod = Installer.saveEffect(cfg, false)
		end)
		game:GetService("Selection"):Set({ mod })
		ctx.setStatus("Saved " .. mod:GetFullName(), UI.OK)
	end)
	UI.dim(playCard, "Saves to ReplicatedStorage.ClipForge.Effects with the runtime. In a LocalScript:\n<font face=\"RobotoMono\">require(game.ReplicatedStorage.ClipForge.FX).play(\"Name\", cframe)</font>", 12)
end

return Tab
