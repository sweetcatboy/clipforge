-- ClipForge Recolor: moves a professionally balanced effect into a new colour family without flattening it.
-- Every recipe colour keeps its VALUE (how light or dark it is) and its role, and takes its hue from the target
-- palette: saturated tones follow the primary (or the secondary when they were an accent), whites become the
-- target's tinted core, greys pick up a little of the primary, dark tones move to the deep tone. So the white-hot
-- core, the saturated body and the dark ink of the original design all survive (rule: the hero carries its own
-- value range).

local Recolor = {}

export type Palette = { core: string?, primary: string?, secondary: string?, deep: string? }

local function hexToColor(s: string): Color3?
	local r, g, b = string.match(s, "^#(%x%x)(%x%x)(%x%x)$")
	if not r then
		return nil
	end
	return Color3.fromRGB(tonumber(r, 16) :: number, tonumber(g, 16) :: number, tonumber(b, 16) :: number)
end
Recolor.hexToColor = hexToColor

local function colorToHex(c: Color3): string
	return string.format(
		"#%02X%02X%02X",
		math.clamp(math.round(c.R * 255), 0, 255),
		math.clamp(math.round(c.G * 255), 0, 255),
		math.clamp(math.round(c.B * 255), 0, 255)
	)
end
Recolor.colorToHex = colorToHex

local function hueDiff(a: number, b: number): number
	local d = (a - b) % 1
	if d > 0.5 then
		d -= 1
	end
	return d
end

local function asColor(v: any): Color3?
	if typeof(v) == "Color3" then
		return v
	elseif type(v) == "string" then
		return hexToColor(v)
	end
	return nil
end

-- Weighted circular mean hue of the saturated colours in a palette (the recipe's "colour family").
local function dominantHue(colors: { Color3 }): number?
	local x, y, w = 0, 0, 0
	for _, c in colors do
		local h, s, v = c:ToHSV()
		if s > 0.25 and v > 0.3 then
			local wt = s * v
			x += math.cos(h * 2 * math.pi) * wt
			y += math.sin(h * 2 * math.pi) * wt
			w += wt
		end
	end
	if w <= 0 then
		return nil
	end
	return (math.atan2(y, x) / (2 * math.pi)) % 1
end

-- Builds the colour mapping function for one recipe palette -> target palette.
function Recolor.mapper(sourceColors: { Color3 }, target: Palette, strength: number?): (Color3) -> Color3
	local k = math.clamp(strength or 1, 0, 1)
	local core = hexToColor(target.core or "") or Color3.new(1, 1, 1)
	local primary = hexToColor(target.primary or "") or Color3.fromRGB(80, 170, 255)
	local secondary = hexToColor(target.secondary or "")
	local deep = hexToColor(target.deep or "")
	local pH, pS, pV = primary:ToHSV()
	local sH, sS = pH, pS
	if secondary then
		sH, sS = secondary:ToHSV()
	end
	local dH, dS = pH, math.max(pS, 0.6)
	if deep then
		dH, dS = deep:ToHSV()
	end
	local dom = dominantHue(sourceColors) or pH
	local neutralTarget = pS < 0.12 -- a white/grey/black target palette: desaturate everything

	return function(c: Color3): Color3
		local h, s, v = c:ToHSV()
		local out: Color3
		if s < 0.12 then
			if v > 0.85 then
				out = c:Lerp(core, 0.75) -- whites become the tinted core
			elseif v < 0.1 then
				out = Color3.fromHSV(dH, dS, v) -- ink stays ink, tinted to the deep tone
			else
				out = Color3.fromHSV(pH, math.min(0.35, s + pS * 0.18), v) -- smoke takes a hint of the body hue
			end
		elseif neutralTarget then
			out = Color3.fromHSV(h, s * 0.15, v)
		elseif v < 0.3 then
			out = Color3.fromHSV(dH, math.clamp(math.max(s, dS * 0.85), 0, 1), v) -- embers, dark rims -> deep tone
		else
			local dh = hueDiff(h, dom)
			local nh, ns
			if math.abs(dh) > 0.1 and secondary then
				nh, ns = sH, sS -- accents keep being accents, in the secondary hue
			else
				nh, ns = (pH + dh * 0.5) % 1, pS -- body tones keep their small hue offsets (warm rim vs body)
			end
			out = Color3.fromHSV(nh, math.clamp(s * 0.45 + ns * 0.55, 0, 1), v)
		end
		if k < 1 then
			out = c:Lerp(out, k)
		end
		return out
	end
end

local function walk(t: any, map: (Color3) -> Color3, seen: { [any]: boolean })
	if type(t) ~= "table" or seen[t] then
		return
	end
	seen[t] = true
	for key, v in t do
		if type(v) == "string" and #v == 7 and string.sub(v, 1, 1) == "#" then
			local c = hexToColor(v)
			if c then
				t[key] = colorToHex(map(c))
			end
		elseif typeof(v) == "Color3" then
			t[key] = map(v)
		elseif type(v) == "table" then
			walk(v, map, seen)
		end
	end
end

-- Recolours a spec IN PLACE (call it on a deep copy): its palette entries and any "#RRGGBB" written directly in layers.
function Recolor.apply(spec: any, target: Palette?, strength: number?)
	if not target or not (target.primary or target.core) then
		return spec
	end
	local colors = {}
	for _, v in spec.palette or {} do
		local c = asColor(v)
		if c then
			table.insert(colors, c)
		end
	end
	local map = Recolor.mapper(colors, target, strength)
	local seen = {}
	if spec.palette then
		for name, v in spec.palette do
			local c = asColor(v)
			if c then
				spec.palette[name] = colorToHex(map(c))
			end
		end
		seen[spec.palette] = true
	end
	for _, layer in spec.layers or {} do
		walk(layer, map, seen)
	end
	return spec
end

-- Named palettes for the UI and for bots ("palette": "Void").
Recolor.Presets = {
	{ name = "Original", palette = nil },
	{ name = "Fire", palette = { core = "#FFF1D6", primary = "#FF6418", secondary = "#FFB238", deep = "#3B0A04" } },
	{ name = "Ice", palette = { core = "#E8F6FF", primary = "#5CC8FF", secondary = "#BDEBFF", deep = "#0C2E66" } },
	{ name = "Void", palette = { core = "#FFFFFF", primary = "#8A2BFF", secondary = "#FF2F9E", deep = "#0A0014" } },
	{ name = "Holy", palette = { core = "#FFF6E6", primary = "#FFC530", secondary = "#FFF0A8", deep = "#4A2A00" } },
	{ name = "Toxic", palette = { core = "#F4FFE8", primary = "#7CFF00", secondary = "#D4FF5C", deep = "#0E2A00" } },
	{ name = "Blood", palette = { core = "#FFE6E6", primary = "#E0102C", secondary = "#FF5A3C", deep = "#2A0006" } },
	{ name = "Electric", palette = { core = "#F4F7FF", primary = "#3FA9FF", secondary = "#C38CFF", deep = "#0B1640" } },
	{ name = "Sakura", palette = { core = "#FFF4FA", primary = "#FF6FB5", secondary = "#FFC2DE", deep = "#3A0A22" } },
	{ name = "Emerald", palette = { core = "#EFFFF6", primary = "#18D27A", secondary = "#7CFFC4", deep = "#03281A" } },
	{ name = "Shadow", palette = { core = "#E9E4FF", primary = "#5B3FA8", secondary = "#1E1433", deep = "#050208" } },
}

return Recolor
