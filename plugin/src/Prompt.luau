-- ClipForge Prompt: "huge purple lightning slash" -> effect config, offline (same rules as the bot server).

local Library = require(script.Parent.Library)

local Prompt = {}

local KEYWORDS = {
	slash = { "slash", "sword", "cut", "blade", "katana", "swing", "crescent", "slice", "cleave", "scythe" },
	impact = { "impact", "slam", "punch", "hit", "smash", "ground", "stomp", "shockwave", "quake", "kick", "land" },
	explosion = { "explosion", "explode", "boom", "blast", "bomb", "nuke", "detonat", "grenade" },
	aura = { "aura", "charge", "power up", "powerup", "transform", "buff", "rage", "awaken" },
	beam = { "beam", "laser", "kamehameha", "ray", "lance", "cannon", "breath" },
	lightning = { "lightning", "thunder", "electric", "shock", "zap", "volt", "storm", "plasma" },
	projectile = { "projectile", "fireball", "orb", "bullet", "shot", "missile", "throw", "ball", "arrow" },
	fire = { "fire", "flame", "burn", "inferno", "blaze", "magma", "lava", "ember" },
	icewater = { "ice", "frost", "freeze", "snow", "water", "splash", "wave", "aqua", "glacier", "crystal" },
	darkportal = { "dark", "void", "portal", "shadow", "black hole", "rift", "abyss", "curse", "domain", "demon" },
	misc = { "holy", "light", "heal", "divine", "angel", "bless", "sparkle", "star", "teleport", "magic" },
}
local ORDER = { "slash", "impact", "explosion", "aura", "beam", "lightning", "projectile", "fire", "icewater", "darkportal", "misc" }
local CORE_KINDS = { "slash", "beam", "projectile", "impact", "explosion", "aura", "lightning" }
-- element words recolour an effect that is not already that element ("ice slam", "fire tornado", "lightning slash");
-- `native` words mark effects that already are ("explosion" is fire, "frost burst" is ice)
local ELEMENTS = {
	{ words = { "ice", "frost", "frozen", "freeze", "cryo", "snow", "glacier" }, native = { "cold", "crystal", "snowfall" },
		colors = { "#5CC8FF", "#BDEBFF" } },
	{ words = { "fire", "flame", "flaming", "inferno", "lava", "magma", "burning", "blaze" },
		native = { "fireball", "explosion", "eruption", "flamethrower", "campfire", "bonfire", "torch", "embers", "volcano", "meteor" },
		colors = { "#FF6418", "#FFB238" } },
	{ words = { "electric", "lightning", "thunder", "shock", "plasma", "volt" }, native = { "zap", "bolt", "crackle" },
		colors = { "#6FB6FF", "#B98CFF" } },
	{ words = { "holy", "divine", "angel", "heaven", "celestial" }, native = { "radiant", "bless", "judgment" },
		colors = { "#FFC530", "#FFF0A8" } },
	{ words = { "water", "aqua", "ocean", "tidal" }, native = { "splash", "liquid", "rain" }, colors = { "#2AD8FF", "#5CC8FF" } },
	{ words = { "nature", "leaf", "leaves", "forest", "plant" }, native = { "fireflies" }, colors = { "#2EE85A", "#9BFF2E" } },
	{ words = { "wind", "air" }, native = { "gust", "tornado", "cyclone", "breeze", "whirlwind" }, colors = { "#CFEFFF", "#FFFFFF" } },
}

Prompt.COLORS = {
	red = "#FF2A2A", crimson = "#DC143C", blood = "#B0001E", orange = "#FF7A1A", amber = "#FFB000",
	gold = "#FFC530", golden = "#FFC530", yellow = "#FFE135", lime = "#9BFF2E", green = "#2EE85A",
	toxic = "#7CFF00", emerald = "#18C77A", teal = "#14D2C0", cyan = "#22E6FF", aqua = "#2AD8FF",
	blue = "#2F7BFF", navy = "#1430A8", indigo = "#5A3CFF", purple = "#9B3CFF", violet = "#8F4DFF",
	magenta = "#FF2FD3", pink = "#FF5EB8", rose = "#FF4F8B", sakura = "#FF9CCB", white = "#F4F8FF",
	silver = "#CFD8E6", black = "#1A1024",
}

local function hsvHex(h, s, v)
	local c = Color3.fromHSV(h % 1, math.clamp(s, 0, 1), math.clamp(v, 0, 1))
	return string.format("#%02X%02X%02X", math.round(c.R * 255), math.round(c.G * 255), math.round(c.B * 255))
end

function Prompt.paletteFrom(primaryHex: string, secondaryHex: string?, dark: boolean?)
	local function parse(hx)
		local r, g, b = string.match(hx, "#(%x%x)(%x%x)(%x%x)")
		return Color3.fromRGB(tonumber(r, 16), tonumber(g, 16), tonumber(b, 16))
	end
	local h, s, v = parse(primaryHex):ToHSV()
	local pal = {
		core = hsvHex(h, if s > 0.15 then 0.08 else 0, 1),
		primary = hsvHex(h, if s > 0.12 then math.max(s, 0.55) else s, math.max(v, 0.85)),
		deep = hsvHex(h + 0.02, math.max(s, 0.6) * 1.1, if dark then 0.12 else 0.2),
	}
	if secondaryHex then
		local h2, s2, v2 = parse(secondaryHex):ToHSV()
		pal.secondary = hsvHex(h2, math.max(s2, 0.5), math.max(v2, 0.8))
	else
		pal.secondary = hsvHex(h + 0.04, s * 0.7 + 0.1, 1)
	end
	return pal
end

local function has(text, w)
	return string.find(text, w, 1, true) ~= nil
end

local function word(text, w)
	return string.find(text, "%f[%a]" .. w .. "%f[%A]") ~= nil
end

function Prompt.parse(prompt: string)
	local text = " " .. string.lower(prompt or "") .. " "
	-- the broad kind the words point at
	local scores = {}
	local best, bestScore = "impact", 0
	for _, kind in ORDER do
		local s = 0
		for _, w in KEYWORDS[kind] do
			if has(text, w) then
				s += if #w > 4 then 2 else 1
			end
		end
		scores[kind] = s
		if s > bestScore then
			best, bestScore = kind, s
		end
	end
	if scores.projectile > 0 and has(text, "fireball") then
		best = "projectile"
	end
	if best == "darkportal" or best == "misc" or best == "fire" or best == "icewater" then
		for _, k in CORE_KINDS do
			if scores[k] > 0 then
				best = k
				break
			end
		end
	end
	-- a specific library effect ("heal", "tornado", "meteor strike", "level up") beats the broad kind
	local entry, libScore = Library.match(prompt, best)
	local useLib = entry ~= nil and libScore >= 2
	local own = if useLib then Library.words(entry) else {}
	local base = if useLib then entry.id else best

	-- colours in the order they appear ("poison cloud" / "black hole" name the effect's own colours: keep them)
	local found = {}
	for name, hx in Prompt.COLORS do
		local at = string.find(text, "%f[%a]" .. name .. "%f[%A]")
		if at and not own[name] then
			table.insert(found, { at = at, hex = hx })
		end
	end
	table.sort(found, function(a, b)
		return a.at < b.at
	end)
	local dark = word(text, "dark") or word(text, "black") or word(text, "void")
	local palette = nil
	if #found > 0 then
		palette = Prompt.paletteFrom(found[1].hex, found[2] and found[2].hex, dark)
	elseif dark and best ~= "darkportal" and not (own.dark or own.void or own.shadow) then
		palette = Prompt.paletteFrom("#8A2BFF", "#FF2F9E", true)
	elseif useLib then
		-- another element asked of this effect recolours it; its own element keeps the designed colours
		local hits = {}
		for _, el in ELEMENTS do
			local first = nil
			for _, w in el.words do
				local at = string.find(text, "%f[%a]" .. w .. "%f[%A]")
				if at and (first == nil or at < first) then
					first = at
				end
			end
			if first then
				table.insert(hits, { at = first, el = el })
			end
		end
		table.sort(hits, function(a, b)
			return a.at < b.at
		end)
		for _, h in hits do
			local native = false
			for _, w in h.el.words do
				native = native or own[w] == true
			end
			for _, w in h.el.native do
				native = native or own[w] == true
			end
			if not native then
				palette = Prompt.paletteFrom(h.el.colors[1], h.el.colors[2], dark)
				break
			end
		end
	end
	local scale = 1
	for _, pair in { { "tiny", 0.6 }, { "small", 0.75 }, { "little", 0.8 }, { "big", 1.35 }, { "large", 1.35 },
		{ "huge", 1.6 }, { "massive", 1.8 }, { "giant", 1.8 }, { "ultimate", 1.7 }, { "epic", 1.5 } } do
		if word(text, pair[1]) then
			scale = pair[2]
		end
	end
	local speed = 1
	for _, pair in { { "fast", 1.3 }, { "quick", 1.25 }, { "rapid", 1.3 }, { "snappy", 1.2 }, { "slow", 0.75 }, { "heavy", 0.85 } } do
		if word(text, pair[1]) then
			speed = pair[2]
		end
	end
	local parts = { { base = base, t = 0 } }
	-- "...and/then/into/with/that explodes": a slash, shot or beam followed by an explosion or impact
	local function followUp()
		for _, c in { "and", "then", "into", "with", "that" } do
			local at = string.find(text, "%f[%a]" .. c .. "%f[%A]")
			if at then
				local rest = string.sub(text, at)
				for _, w in { "explo", "boom", "blast", "impact", "slam" } do
					if string.find(rest, "%f[%a]" .. w) then
						return true
					end
				end
			end
		end
		return false
	end
	if (best == "slash" or best == "projectile" or best == "beam") and followUp() then
		local follow = if has(text, "explo") or has(text, "boom") or has(text, "blast") then "explosion" else "impact"
		table.insert(parts, { base = follow, t = if best == "slash" then 0.25 else 0.4, at = { 0, 0, -6 }, scale = 0.9 })
	end
	local words = {}
	for w in string.gmatch(prompt or "", "%a+") do
		local lw = string.lower(w)
		if lw ~= "a" and lw ~= "an" and lw ~= "the" and lw ~= "with" and lw ~= "and" and lw ~= "of" and lw ~= "that" then
			table.insert(words, string.upper(string.sub(w, 1, 1)) .. string.lower(string.sub(w, 2)))
		end
		if #words >= 4 then
			break
		end
	end
	return {
		name = if #words > 0 then table.concat(words) else base,
		base = base,
		palette = palette,
		scale = scale,
		speed = speed,
		intensity = 1,
		roll = if base == "slash" then -25 else 0,
		yaw = 0,
		parts = parts,
		prompt = prompt,
		shake = if useLib then entry.shake else nil,
	}
end

return Prompt
