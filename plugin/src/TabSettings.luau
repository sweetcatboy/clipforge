-- ClipForge Settings tab: make the plugin look the way you like (saved between sessions).

local Tab = {}

local DEFAULTS = { mode = "studio", accent = "#7C5CFF", scale = 1, density = "comfortable" }

local function hexOf(c: Color3)
	return string.format("#%02X%02X%02X", math.round(c.R * 255), math.round(c.G * 255), math.round(c.B * 255))
end

-- Read the saved look and apply it (called before the UI is built).
function Tab.load(ctx)
	local saved = ctx.setting("Theme", nil) or DEFAULTS
	local accent = ctx.Recolor.hexToColor(saved.accent or DEFAULTS.accent) or ctx.UI.ACCENTS[1][2]
	ctx.UI.setTheme({ mode = saved.mode or DEFAULTS.mode, accent = accent, scale = saved.scale or 1, density = saved.density or DEFAULTS.density })
end

function Tab.build(page, ctx)
	local UI = ctx.UI
	local function save()
		ctx.saveSetting("Theme", { mode = UI.theme.mode, accent = hexOf(UI.theme.accent), scale = UI.theme.scale, density = UI.theme.density })
	end

	local look = UI.card(page, "Theme")
	local modeSeg = UI.segmented(look, { "studio", "dark", "midnight", "light" }, UI.theme.mode, function(v)
		UI.setTheme({ mode = v })
		save()
	end, { studio = "Studio", dark = "Dark", midnight = "Midnight", light = "Light" })
	UI.dim(look, "Studio follows Studio's own light/dark theme.", 12)

	local accentCard = UI.card(page, "Accent colour")
	local swatches = UI.frame(accentCard)
	local g = Instance.new("UIGridLayout")
	g.CellSize = UDim2.new(0.25, -6, 0, 30)
	g.CellPadding = UDim2.new(0, 6, 0, 6)
	g.SortOrder = Enum.SortOrder.LayoutOrder
	g.Parent = swatches
	local hexBox
	for i, a in UI.ACCENTS do
		local b = Instance.new("TextButton")
		b.AutoButtonColor = false
		b.Text = a[1]
		b.FontFace = UI.FONT_MED
		b.TextSize = 12
		b.TextColor3 = Color3.new(1, 1, 1)
		b.BackgroundColor3 = a[2]
		b.LayoutOrder = i
		UI.corner(b, 6)
		b.Parent = swatches
		b.Activated:Connect(function()
			UI.setTheme({ accent = a[2] })
			if hexBox then
				hexBox.Text = hexOf(a[2])
			end
			save()
		end)
	end
	local hr = UI.row(accentCard, 6, 30)
	hexBox = UI.input(hr, "#RRGGBB", hexOf(UI.theme.accent), { Size = UDim2.new(0, 110, 1, 0) })
	UI.button(hr, "Use colour", "secondary", function()
		local hex = string.upper((string.gsub(hexBox.Text, "%s", "")))
		if string.sub(hex, 1, 1) ~= "#" then
			hex = "#" .. hex
		end
		local c = ctx.Recolor.hexToColor(hex)
		if c then
			UI.setTheme({ accent = c })
			save()
		end
	end, 100)

	local text = UI.card(page, "Text & spacing")
	UI.dim(text, "Text size", 12)
	local sizeSeg = UI.segmented(text, { "0.9", "1", "1.15", "1.3" }, tostring(UI.theme.scale), function(v)
		UI.setTheme({ scale = tonumber(v) })
		save()
	end, { ["0.9"] = "Small", ["1"] = "Normal", ["1.15"] = "Large", ["1.3"] = "Huge" })
	UI.dim(text, "Density", 12)
	local densSeg = UI.segmented(text, { "compact", "comfortable" }, UI.theme.density, function(v)
		UI.setTheme({ density = v })
		save()
	end, { compact = "Compact", comfortable = "Comfortable" })

	UI.button(page, "Reset to defaults", "ghost", function()
		local a = ctx.Recolor.hexToColor(DEFAULTS.accent)
		UI.setTheme({ mode = DEFAULTS.mode, accent = a, scale = DEFAULTS.scale, density = DEFAULTS.density })
		modeSeg.set(DEFAULTS.mode)
		sizeSeg.set("1")
		densSeg.set(DEFAULTS.density)
		hexBox.Text = DEFAULTS.accent
		save()
	end)

	local about = UI.card(page, "About")
	UI.dim(about, "ClipForge " .. tostring(ctx.version) .. " · effect runtime and base recipes from vfxmith (MIT) · see THIRD_PARTY_NOTICES in the plugin.", 12)
end

return Tab
