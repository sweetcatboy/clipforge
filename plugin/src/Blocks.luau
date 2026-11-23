-- ClipForge Blocks: tuned VFX layers to compose effects from (VFXTimeline spec format).
--
-- Every block returns one layer (or a list of layers) with values that follow how pro Roblox VFX are built:
--   * hits land in ONE frame: flashes are full size on frame 1 and gone in 2-5 frames;
--   * rings and shockwaves travel: they start at ~20% size, ease out, keep growing while they fade;
--   * flashes carry size with SHAPE (spike bursts, rays) instead of round white blobs that wash out in daylight;
--   * each effect has a value range: white core, saturated body, deep tone, so recolouring never flattens it;
--   * things that break or burst leave something behind (smoke, embers, scorch, debris that lands).
-- Colours are palette names, so ClipForge's Recolor can move any effect into any colour family:
--   white (hottest) > core (hot tint) > body (saturated) > accent (second hue) > deep (dark tone) > ink; smoke = grey.
-- Sizes: a particle's Size is its HALF-width (Size 4 = 8 studs across); parts and beams are full sizes.

local B = {}

-- Public Roblox textures, all used by the studied open-source effects (see THIRD_PARTY_NOTICES).
B.TEX = {
	SPARK = 16878181512, -- hard spark dot
	SPEC = 9997556038, -- soft spec
	ORBIT = 16171528032, -- off-centre sharp dot: spinning it makes the dot orbit
	GLOW = 867619398, -- big soft glow
	SOFTDOT = 16879789169, -- small soft dot: scaled up = edge-free bloom
	CROSS = 14590086212, -- sharp thin lens cross
	SPARKLE = 14006783533, -- fat 4-point sparkle
	SHORTCROSS = 17062452122, -- short white cross
	TOONSTAR = 16892332741, -- crisp toon star
	STREAK = 8030734851, -- spark streak (VelocityParallel + Squash)
	SPEEDLINES = 18465146997, -- speed lines
	RAYS = 1053548563, -- light rays from a point (black card: LightEmission 1 only)
	WINDRING = 18527700887, -- spinning two-arc wind ring
	THINRING = 18682826321, -- clean thin ring
	SHOCKRING = 7417145436, -- ragged spiky shock ring
	STARBURST = 17296456452, -- radial spike burst (impact flash)
	RINGFLIP = 126034245450101, -- 4x4 ring, thick -> hairline
	CRESCENT = 13780268621, -- 4x4 crescent slash
	SWIRL = 109440284900004, -- 4x4 wind swirl
	SMOKE = 11871320339, -- 4x4 soft smoke
	TOONSMOKE = 16867483883, -- 4x4 toon smoke
	BILLOW = 15415212938, -- 4x4 dense billow
	DUST = 7216851093, -- lingering dust cloud
	TOONFIRE = 11846119288, -- 4x4 toon fire
	FLAME = 15413764911, -- 4x4 flame flick
	LIGHTNING = 13780092154, -- 4x4 lightning
	POP = 18140248952, -- 4x4 toon impact pop
	ROCKS = 15441282898, -- 2x2 rocks
	SPLAT = 14431663347, -- 4x4 liquid splat
	CRACKSTAR = 99911247720869, -- clean crack starburst (single image, decal-friendly)
	BEAMFLOW = 16892453445, -- beam energy flow
	BEAMSMOKE = 12823611043, -- beam smoke strands
	RUNES = 135141028133816, -- white rune circle
}

-- Ready palettes (role -> hex). Effects pick one; the user's palette replaces it through Recolor.
B.PAL = {
	fire = { white = "#FFF6E6", core = "#FFD27A", body = "#FF6A1C", accent = "#FFB238", deep = "#4A1204", ink = "#120402", smoke = "#5E5753" },
	ice = { white = "#F2FBFF", core = "#C8F1FF", body = "#4FC3FF", accent = "#B9E8FF", deep = "#0C2E66", ink = "#040C1A", smoke = "#B8C8D8" },
	electric = { white = "#F6F8FF", core = "#BFE0FF", body = "#3F9BFF", accent = "#B38CFF", deep = "#0B1640", ink = "#03050F", smoke = "#5A6478" },
	void = { white = "#FFFFFF", core = "#E2C8FF", body = "#8A2BFF", accent = "#FF2F9E", deep = "#1A0033", ink = "#05000A", smoke = "#3C3048" },
	holy = { white = "#FFFDF4", core = "#FFF0B0", body = "#FFC530", accent = "#FFF6D0", deep = "#5A3600", ink = "#1A1000", smoke = "#D8CFB8" },
	nature = { white = "#F6FFF2", core = "#D8FFC8", body = "#3BD76B", accent = "#B6FF6A", deep = "#0B3D1A", ink = "#031008", smoke = "#9BB59A" },
	toxic = { white = "#F8FFE8", core = "#E6FF9A", body = "#7CFF00", accent = "#C8FF3A", deep = "#1E3A00", ink = "#060C00", smoke = "#6B7A4A" },
	blood = { white = "#FFEFEF", core = "#FF9A9A", body = "#E0102C", accent = "#FF5A3C", deep = "#3A0006", ink = "#0A0002", smoke = "#5A4246" },
	water = { white = "#F2FCFF", core = "#BDEFFF", body = "#2FA8FF", accent = "#8EE6FF", deep = "#06305A", ink = "#020A14", smoke = "#CFE6F2" },
	earth = { white = "#FFF6E8", core = "#E8D2B0", body = "#B07A48", accent = "#D9B27A", deep = "#3A2614", ink = "#120A04", smoke = "#8A7A68" },
	wind = { white = "#FFFFFF", core = "#EAF7FF", body = "#BFE6F2", accent = "#E8FFF8", deep = "#5A7A88", ink = "#1A2428", smoke = "#D8E4EA" },
	party = { white = "#FFFFFF", core = "#FFF27A", body = "#FF4FB8", accent = "#3FE0FF", deep = "#6A20FF", ink = "#140620", smoke = "#E8E0F0" },
	energy = { white = "#FFFFFF", core = "#C8FFF6", body = "#00E5FF", accent = "#7C5CFF", deep = "#002A40", ink = "#00080C", smoke = "#5A7078" },
	impact = { white = "#FFF8EC", core = "#FFD27A", body = "#FF8A3C", accent = "#FFB238", deep = "#3A2614", ink = "#120A04", smoke = "#8A7A68" },
	smoke = { white = "#FFFFFF", core = "#E4E4EA", body = "#9C9CA8", accent = "#C8C8D2", deep = "#4A4A55", ink = "#16161C", smoke = "#7A7A86" },
	time = { white = "#FFFFFF", core = "#E6EEFF", body = "#8FA8FF", accent = "#FFE38A", deep = "#2A3560", ink = "#0A0E1C", smoke = "#C8D0E0" },
	autumn = { white = "#FFF2D6", core = "#FFC24A", body = "#E8731C", accent = "#C0391B", deep = "#5A2A0A", ink = "#1A0A02", smoke = "#8A6A4A" },
	sakura = { white = "#FFF6FA", core = "#FFD6E6", body = "#FF9CCB", accent = "#FF6FA8", deep = "#9A2F64", ink = "#2A0818", smoke = "#E8C8D8" },
	spirit = { white = "#F4FFFF", core = "#B8FFF4", body = "#3FE0C8", accent = "#7CC8FF", deep = "#0A3A40", ink = "#021012", smoke = "#8AB8B8" },
}

local function copy(t)
	local o = {}
	for k, v in t do
		o[k] = v
	end
	return o
end

-- Applies overrides and common fields to a layer.
-- Block tracks are written in NORMALISED time (0..1 of the layer's life) so they follow any life override; they are
-- converted to the runtime's seconds here. Tracks passed in o.tracks are already in seconds.
local function finish(L, o)
	if o.props then
		for k, v in o.props do
			L.props[k] = v
		end
	end
	for _, k in { "id", "t", "life", "at", "rot", "copies", "box", "spin", "pivot", "enabled" } do
		if o[k] ~= nil then
			L[k] = o[k]
		end
	end
	if L.tracks then
		local life = L.life or 1
		for name, keys in L.tracks do
			local conv = {}
			for i, key in keys do
				conv[i] = { key[1] * life, key[2], key[3] }
			end
			L.tracks[name] = conv
		end
	end
	if o.tracks then
		L.tracks = L.tracks or {}
		for k, v in o.tracks do
			L.tracks[k] = v
		end
	end
	-- an emitter layer must stay alive until its last burst has fired
	if L.kind == "emitter" and L.emit then
		local last = 0
		for _, e in L.emit do
			last = math.max(last, (e[1] or 0) + (e[3] or 0))
		end
		if last + 0.02 > (L.life or 0.05) then
			L.life = last + 0.02
		end
	end
	return L
end

-- Sets tracks that are already in seconds (paths, emission rates) after finish().
local function secondsTracks(L, tracks)
	L.tracks = L.tracks or {}
	for k, v in tracks do
		L.tracks[k] = v
	end
	return L
end

-- "grow" curve for travelling rings: ~45% at 10% life, ~80% at 40% (rule: rings race out and ease out)
local function grow(r, start)
	start = start or 0.18
	return { { 0, r * start }, { 0.1, r * 0.45 }, { 0.25, r * 0.66 }, { 0.4, r * 0.8 }, { 0.7, r * 0.93 }, { 1, r } }
end
B.grow = grow

local function emitter(id, o, props, emitCount)
	return finish({
		id = id, kind = "emitter", t = 0, life = 0.05, at = { 0, 0, 0 },
		props = props,
		emit = o.emit or { { 0, emitCount or 1 } },
	}, o)
end

----------------------------------------------------------------------------------------------------- hits & flashes
-- White spike burst, full size on frame 1, gone in ~5 frames.
function B.flash(o)
	o = o or {}
	local s = o.size or 7
	return emitter("flash", o, {
		Texture = o.tex or "STARBURST", Color = o.color or "white", LightEmission = 1, Brightness = o.brightness or 3,
		LightInfluence = 0, Orientation = "FacingCamera", Speed = 0, Rotation = { -360, 360 }, ZOffset = 3,
		Size = { { 0, s }, { 0.35, s * 0.8 }, { 1, 0 } }, Transparency = { { 0, 0 }, { 0.6, 0.15 }, { 1, 1 } },
		Lifetime = o.lifetime or 0.09,
	})
end

-- Saturated bloom around the core (carries size without a flat white ball).
function B.bloom(o)
	o = o or {}
	local s = o.size or 12
	return emitter("bloom", o, {
		Texture = "SOFTDOT", Color = o.color or "body", LightEmission = 1, Brightness = o.brightness or 2, LightInfluence = 0,
		Orientation = "FacingCamera", Speed = 0, ZOffset = 1,
		Size = { { 0, s * 0.6 }, { 0.15, s }, { 1, s * 1.1 } },
		Transparency = { { 0, o.alpha or 0.35 }, { 0.3, (o.alpha or 0.35) + 0.15 }, { 1, 1 } },
		Lifetime = o.lifetime or 0.35,
	})
end

-- Thin cross star (impact frame accent, pickups, glints).
function B.star(o)
	o = o or {}
	local s = o.size or 5
	return emitter("star", o, {
		Texture = o.tex or "CROSS", Color = o.color or "white", LightEmission = 1, Brightness = o.brightness or 4,
		LightInfluence = 0, Orientation = "FacingCamera", Speed = 0, Rotation = o.rotation or { 0, 0 }, ZOffset = 4,
		Size = { { 0, 0 }, { 0.12, s }, { 1, 0 } }, Transparency = { { 0, 0 }, { 0.7, 0.2 }, { 1, 1 } },
		Lifetime = o.lifetime or 0.18,
	})
end

-- Dark twin behind a flash (anime impact frame ink). Keep it thin and quick.
function B.inkFlash(o)
	o = o or {}
	local s = o.size or 9
	return emitter("inkFlash", o, {
		Texture = "STARBURST", Color = o.color or "deep", LightEmission = 0, Brightness = 0, LightInfluence = 0,
		Orientation = "FacingCamera", Speed = 0, Rotation = { -360, 360 }, ZOffset = 2.5,
		Size = { { 0, s * 1.2 }, { 1, s * 0.4 } }, Transparency = { { 0, 0.25 }, { 0.5, 0.5 }, { 1, 1 } },
		Lifetime = o.lifetime or 0.07,
	})
end

-- Light rays from a point (holy, crits, reveals).
function B.rays(o)
	o = o or {}
	local s = o.size or 12
	return emitter("rays", o, {
		Texture = "RAYS", Color = o.color or "core", LightEmission = 1, Brightness = o.brightness or 2, LightInfluence = 0,
		Orientation = "FacingCamera", Speed = 0, Rotation = { -360, 360 }, RotSpeed = { -25, 25 }, ZOffset = 0.5,
		Size = { { 0, s * 0.5 }, { 0.2, s }, { 1, s * 1.15 } },
		Transparency = { { 0, 0.2 }, { 0.5, 0.45 }, { 1, 1 } }, Lifetime = o.lifetime or 0.7,
	}, o.count or 14)
end

------------------------------------------------------------------------------------------------ rings & shockwaves
-- Flat ring racing out along the ground.
function B.ring(o)
	o = o or {}
	local r = o.size or 12
	return emitter("ring", o, {
		Texture = o.tex or "RINGFLIP", FlipbookLayout = (o.tex == nil or o.tex == "RINGFLIP") and 4 or nil,
		FlipbookMode = (o.tex == nil or o.tex == "RINGFLIP") and "OneShot" or nil,
		Color = o.color or "core", LightEmission = o.le or 1, Brightness = o.brightness or 2, LightInfluence = 0,
		Orientation = "VelocityPerpendicular", EmissionDirection = "Top", Speed = 0.01, Rotation = { -360, 360 },
		Size = grow(r), Transparency = { { 0, 0 }, { 0.45, 0.25 }, { 1, 1 } }, Lifetime = o.lifetime or 0.5,
	})
end

-- Camera-facing shock ring (punches, explosions): crisp, thin, fast.
function B.shockwave(o)
	o = o or {}
	local r = o.size or 10
	return emitter("shockwave", o, {
		Texture = o.tex or "SHOCKRING", Color = o.color or "white", LightEmission = 1, Brightness = o.brightness or 1.5,
		LightInfluence = 0, Orientation = "FacingCamera", Speed = 0, Rotation = { -360, 360 }, ZOffset = 1.5,
		Size = grow(r, 0.12), Transparency = { { 0, 0 }, { 0.3, 0.35 }, { 1, 1 } }, Lifetime = o.lifetime or 0.3,
	})
end

-- Spinning wind ring (dashes, tornado bands, auras).
function B.windRing(o)
	o = o or {}
	local r = o.size or 8
	return emitter("windRing", o, {
		Texture = "WINDRING", Color = o.color or "core", LightEmission = o.le or 0.6, Brightness = o.brightness or 1,
		LightInfluence = 0, Orientation = o.orientation or "VelocityPerpendicular", EmissionDirection = o.dir or "Top",
		Speed = o.speed or 0.01, Rotation = { -360, 360 }, RotSpeed = o.rotSpeed or { 380, 520 },
		Size = { { 0, r * 0.4 }, { 0.3, r * 0.85 }, { 1, r } }, Transparency = { { 0, 0.15 }, { 0.6, 0.45 }, { 1, 1 } },
		Lifetime = o.lifetime or 0.45,
	}, o.count or 1)
end

-- Spinning swirl flipbook (charge-ups, portals, vortex floors).
function B.swirl(o)
	o = o or {}
	local r = o.size or 8
	return emitter("swirl", o, {
		Texture = "SWIRL", FlipbookLayout = 4, FlipbookMode = "OneShot", Color = o.color or "body",
		LightEmission = o.le or 0.8, Brightness = o.brightness or 1.5, LightInfluence = 0,
		Orientation = o.orientation or "VelocityPerpendicular", EmissionDirection = "Top", Speed = 0.01,
		Rotation = { -360, 360 }, RotSpeed = o.rotSpeed or { -260, -160 },
		Size = { { 0, r * 0.5 }, { 0.4, r * 0.9 }, { 1, r } }, Transparency = { { 0, 0.2 }, { 0.6, 0.4 }, { 1, 1 } },
		Lifetime = o.lifetime or 0.7,
	}, o.count or 2)
end

------------------------------------------------------------------------------------------------------ particles
-- Hot spark streaks flying out and arcing down.
function B.sparks(o)
	o = o or {}
	return emitter("sparks", o, {
		Texture = "STREAK", Color = o.color or { { 0, "white" }, { 0.35, "core" }, { 1, "body" } },
		LightEmission = 1, Brightness = o.brightness or 4, LightInfluence = 0,
		Orientation = "VelocityParallel", EmissionDirection = o.dir or "Top", SpreadAngle = o.spread or { 75, 75 },
		Speed = o.speed or { 35, 80 }, Drag = o.drag or 5, Acceleration = o.gravity or { 0, -40, 0 },
		Rotation = 90, Squash = { { 0, 1.5 }, { 1, 0.5 } },
		Size = { { 0, o.size or 0.45 }, { 1, 0 } }, Transparency = 0, Lifetime = o.lifetime or { 0.25, 0.55 }, ZOffset = 2,
	}, o.count or 14)
end

-- Fast speed lines bursting from the centre (anime hits, dashes).
function B.streaks(o)
	o = o or {}
	return emitter("streaks", o, {
		Texture = "STREAK", Color = o.color or "white", LightEmission = 1, Brightness = o.brightness or 3, LightInfluence = 0,
		Orientation = "VelocityParallel", EmissionDirection = o.dir or "Top", SpreadAngle = o.spread or { 180, 180 },
		Speed = o.speed or { 70, 130 }, Drag = 8, Rotation = 90, Squash = { { 0, 4 }, { 1, 2 } },
		Size = { { 0, o.size or 1.6 }, { 1, 0 } }, Transparency = 0, Lifetime = o.lifetime or { 0.08, 0.14 }, ZOffset = 2,
	}, o.count or 10)
end

-- Soft glowing specks that drift and twinkle (magic, pickups, linger).
function B.specks(o)
	o = o or {}
	return emitter("specks", o, {
		Texture = o.tex or "SPARK", Color = o.color or "core", LightEmission = 1, Brightness = o.brightness or 3,
		LightInfluence = 0, Orientation = "FacingCamera", EmissionDirection = o.dir or "Top",
		SpreadAngle = o.spread or { 180, 180 }, Speed = o.speed or { 4, 14 }, Drag = o.drag or 2,
		Acceleration = o.gravity or { 0, 2, 0 }, Rotation = { -360, 360 },
		Size = { { 0, 0 }, { 0.12, o.size or 0.35 }, { 0.7, (o.size or 0.35) * 0.7 }, { 1, 0 } },
		Transparency = { { 0, 0 }, { 0.5, 0.1 }, { 0.75, 0.6 }, { 0.85, 0.1 }, { 1, 1 } },
		Lifetime = o.lifetime or { 0.8, 1.6 }, ZOffset = 1,
	}, o.count or 16)
end

-- Rising motes from a disc at the feet (heals, buffs, level ups, ambient magic).
function B.rise(o)
	o = o or {}
	local r = o.radius or 3
	return finish({
		id = "rise", kind = "emitter", t = 0, life = o.life or 0.8, at = o.at or { 0, 0.2, 0 }, box = { r * 2, 0.2, r * 2 },
		props = {
			Texture = o.tex or "SPARKLE", Color = o.color or { { 0, "white" }, { 0.3, "core" }, { 1, "body" } },
			LightEmission = 1, Brightness = o.brightness or 3, LightInfluence = 0, Shape = "Box",
			Orientation = "FacingCamera", EmissionDirection = "Top", Speed = o.speed or { 2, 5 }, Drag = 0.5,
			Acceleration = { 0, o.lift or 4, 0 }, Rotation = { -45, 45 }, RotSpeed = { -60, 60 },
			Size = { { 0, 0 }, { 0.15, o.size or 0.5 }, { 0.8, (o.size or 0.5) * 0.6 }, { 1, 0 } }, Transparency = 0,
			Lifetime = o.lifetime or { 0.9, 1.5 }, ZOffset = 1,
		},
		emit = o.emit or { { 0, o.count or 18, o.over or 0.6 } },
	}, o)
end

-- Off-centre dots spinning = specks orbiting the centre.
function B.orbit(o)
	o = o or {}
	return emitter("orbit", o, {
		Texture = "ORBIT", Color = o.color or "core", LightEmission = 1, Brightness = o.brightness or 3, LightInfluence = 0,
		Orientation = "FacingCamera", Speed = 0, Rotation = { -360, 360 }, RotSpeed = o.rotSpeed or { 260, 420 },
		Size = { { 0, (o.size or 4) * 0.6 }, { 0.5, o.size or 4 }, { 1, (o.size or 4) * 0.8 } },
		Transparency = { { 0, 1 }, { 0.15, 0 }, { 0.8, 0 }, { 1, 1 } }, Lifetime = o.lifetime or 0.9, ZOffset = 1,
	}, o.count or 5)
end

----------------------------------------------------------------------------------------------- smoke, dust, debris
function B.smoke(o)
	o = o or {}
	local s = o.size or 5
	return emitter("smoke", o, {
		Texture = o.tex or "SMOKE", FlipbookLayout = 4, FlipbookMode = "OneShot", Color = o.color or "smoke",
		LightEmission = o.le or 0.15, Brightness = o.brightness or 1, LightInfluence = o.li or 0.6,
		Orientation = "FacingCamera", EmissionDirection = o.dir or "Top", SpreadAngle = o.spread or { 60, 60 },
		Speed = o.speed or { 4, 12 }, Drag = o.drag or 3, Acceleration = o.gravity or { 0, 2, 0 },
		Rotation = { -360, 360 }, RotSpeed = { -30, 30 },
		Size = { { 0, s * 0.4 }, { 0.3, s * 0.85 }, { 1, s } },
		Transparency = { { 0, 0.25 }, { 0.4, 0.45 }, { 1, 1 } }, Lifetime = o.lifetime or { 1, 1.7 }, ZOffset = -0.5,
	}, o.count or 6)
end

-- Ground dust ring kicked outward (landings, slams, dashes).
function B.dust(o)
	o = o or {}
	local s = o.size or 3.5
	return emitter("dust", o, {
		Texture = "DUST", Color = o.color or "smoke", LightEmission = 0, Brightness = 1, LightInfluence = 0.9,
		Orientation = "FacingCamera", EmissionDirection = "Top", SpreadAngle = { 82, 82 },
		Speed = o.speed or { 14, 26 }, Drag = 5, Acceleration = { 0, -3, 0 }, Rotation = { -360, 360 }, RotSpeed = { -40, 40 },
		Size = { { 0, s * 0.3 }, { 0.25, s * 0.8 }, { 1, s } }, Transparency = { { 0, 0.35 }, { 0.5, 0.55 }, { 1, 1 } },
		Lifetime = o.lifetime or { 0.7, 1.2 }, ZOffset = -0.3,
	}, o.count or 10)
end

-- Rocks that pop out, tumble and fall (sprites, lit by the scene).
function B.debris(o)
	o = o or {}
	return emitter("debris", o, {
		Texture = "ROCKS", FlipbookLayout = 2, FlipbookMode = "Loop", FlipbookFramerate = { 4, 10 },
		Color = o.color or "smoke", LightEmission = 0, Brightness = 1, LightInfluence = 1,
		Orientation = "FacingCamera", EmissionDirection = "Top", SpreadAngle = o.spread or { 55, 55 },
		Speed = o.speed or { 22, 40 }, Drag = 0.5, Acceleration = { 0, -70, 0 }, Rotation = { -360, 360 },
		RotSpeed = { -300, 300 }, Size = { { 0, o.size or 0.6, 0.2 }, { 1, o.size or 0.6, 0.2 } },
		Transparency = { { 0, 0 }, { 0.85, 0 }, { 1, 1 } }, Lifetime = o.lifetime or { 0.9, 1.3 },
	}, o.count or 10)
end

-- Embers drifting up and flickering out.
function B.embers(o)
	o = o or {}
	return emitter("embers", o, {
		Texture = "SPARK", Color = o.color or { { 0, "core" }, { 0.6, "body" }, { 1, "deep" } },
		LightEmission = 1, Brightness = o.brightness or 3, LightInfluence = 0, Orientation = "FacingCamera",
		EmissionDirection = "Top", SpreadAngle = o.spread or { 70, 70 }, Speed = o.speed or { 4, 12 }, Drag = 1.5,
		Acceleration = { 0, o.lift or 5, 0 }, Size = { { 0, o.size or 0.18 }, { 1, 0 } },
		Transparency = { { 0, 0 }, { 0.3, 0.2 }, { 0.5, 0 }, { 0.7, 0.4 }, { 1, 1 } },
		Lifetime = o.lifetime or { 1, 2 }, ZOffset = 1,
	}, o.count or 14)
end

------------------------------------------------------------------------------------------------- elements
-- Flames rising (fire pillars, torches, burning ground). Continuous when given a Rate track.
function B.flames(o)
	o = o or {}
	local s = o.size or 2.2
	local L = finish({
		id = "flames", kind = "emitter", t = 0, life = o.life or 0.6, at = o.at or { 0, 0, 0 },
		box = o.box or { 1.5, 0.3, 1.5 },
		props = {
			Texture = o.tex or "TOONFIRE", FlipbookLayout = 4, FlipbookMode = "OneShot",
			Color = o.color or { { 0, "white" }, { 0.2, "core" }, { 0.55, "body" }, { 1, "deep" } },
			LightEmission = o.le or 0.7, Brightness = o.brightness or 2.5, LightInfluence = 0, Shape = "Box",
			Orientation = "FacingCameraWorldUp", EmissionDirection = "Top", SpreadAngle = { 12, 12 },
			Speed = o.speed or { 5, 10 }, Drag = 1, Acceleration = { 0, o.lift or 6, 0 }, Rotation = { -15, 15 },
			Size = { { 0, s * 0.6 }, { 0.3, s }, { 1, s * 0.4 } }, Transparency = { { 0, 0.1 }, { 0.75, 0.25 }, { 1, 1 } },
			Lifetime = o.lifetime or { 0.45, 0.8 }, ZOffset = 0.5,
		},
		emit = o.emit,
	}, o)
	if o.rateTrack then
		secondsTracks(L, { Rate = o.rateTrack }) -- emission rate over the layer, in seconds
	end
	return L
end

-- Lightning bolts flickering (several strikes over a short window).
function B.bolts(o)
	o = o or {}
	local s = o.size or 7
	local strikes = o.strikes or { { 0, 2 }, { 0.08, 1 }, { 0.17, 2 } }
	return finish({
		id = "bolts", kind = "emitter", t = 0, life = o.life or 0.3, at = o.at or { 0, 3, 0 }, box = o.box,
		props = {
			Texture = "LIGHTNING", FlipbookLayout = 4, FlipbookMode = "OneShot", Color = o.color or "core",
			LightEmission = 1, Brightness = o.brightness or 5, LightInfluence = 0, Orientation = "FacingCamera",
			Speed = 0, Rotation = o.rotation or { -40, 40 }, Size = { { 0, s }, { 1, s * 0.9 } }, Transparency = 0,
			Lifetime = o.lifetime or { 0.12, 0.2 }, ZOffset = 2, Shape = o.box and "Box" or nil,
		},
		emit = strikes,
	}, o)
end

-- Liquid splash crown (water, blood, slime).
function B.splash(o)
	o = o or {}
	local s = o.size or 5
	return emitter("splash", o, {
		Texture = "SPLAT", FlipbookLayout = 4, FlipbookMode = "OneShot", Color = o.color or { { 0, "core" }, { 1, "body" } },
		LightEmission = o.le or 0.3, Brightness = 1.5, LightInfluence = 0.4, Orientation = "FacingCameraWorldUp",
		Speed = 0.01, Rotation = { -20, 20 }, Size = { { 0, s * 0.5 }, { 0.4, s }, { 1, s * 1.1 } },
		Transparency = { { 0, 0 }, { 0.6, 0.1 }, { 1, 1 } }, Lifetime = o.lifetime or 0.55,
	}, o.count or 2)
end

-- Droplets arcing out (water / blood / slime).
function B.droplets(o)
	o = o or {}
	return emitter("droplets", o, {
		Texture = "SPEC", Color = o.color or "core", LightEmission = 0.4, Brightness = 2, LightInfluence = 0.5,
		Orientation = "VelocityParallel", EmissionDirection = "Top", SpreadAngle = { 60, 60 },
		Speed = o.speed or { 18, 34 }, Drag = 0.5, Acceleration = { 0, -60, 0 }, Squash = { { 0, 1 }, { 1, 1.5 } },
		Size = { { 0, o.size or 0.35 }, { 1, 0.1 } }, Transparency = 0, Lifetime = o.lifetime or { 0.5, 0.9 },
	}, o.count or 16)
end

------------------------------------------------------------------------------------------------ geometry layers
-- Expanding ball (Neon core, or ForceField for a fresnel energy shell).
function B.sphere(o)
	o = o or {}
	local d = o.size or 8
	return finish({
		id = "sphere", kind = "part", t = 0, life = o.life or 0.35, at = o.at or { 0, 0, 0 }, size = { d, d, d },
		props = { Shape = "Ball", Material = o.material or "ForceField", Color = o.color or "body", Transparency = 0 },
		tracks = {
			Scale = o.scale or { { 0, 0.15 }, { 0.25, 0.85, "quadOut" }, { 1, 1.1, "sineOut" } },
			Transparency = o.fade or { { 0, 0 }, { 0.5, 0.2 }, { 1, 1, "quadIn" } },
		},
	}, o)
end

-- Vertical light column (teleports, holy beams, level ups): a thin white-hot Neon core inside a wider translucent
-- ForceField glow. Width pops in with an overshoot, then thins out to nothing (fading Neon turns grey in daylight).
function B.pillar(o)
	o = o or {}
	local h, d = o.height or 24, o.width or 3
	local life = o.life or 0.6
	local id = o.id or "pillar"
	local where = { t = o.t, at = o.at, enabled = o.enabled }
	local core = finish({
		id = id .. "Core", kind = "part", t = 0, life = life * 0.7, at = { 0, 0, 0 }, rot = { 0, 0, 90 },
		size = { h, d * 0.3, d * 0.3 }, pivot = { -0.5, 0, 0 },
		props = { Shape = "Cylinder", Material = "Neon", Color = o.coreColor or "white", Transparency = 0.05 },
		tracks = {
			Scale = { { 0, { 1, 0.05, 0.05 } }, { 0.18, { 1, 1, 1 }, "backOut" }, { 1, { 1, 0.01, 0.01 }, "quadIn" } },
		},
	}, where)
	local glow = finish({
		id = id .. "Glow", kind = "part", t = 0, life = life, at = { 0, 0, 0 }, rot = { 0, 0, 90 },
		size = { h, d, d }, pivot = { -0.5, 0, 0 },
		props = { Shape = "Cylinder", Material = "ForceField", Color = o.color or "body", Transparency = 0 },
		tracks = {
			Scale = { { 0, { 1, 0.1, 0.1 } }, { 0.15, { 1, 1.1, 1.1 }, "backOut" }, { 0.6, { 1, 0.9, 0.9 } }, { 1, { 1, 0.2, 0.2 }, "quadIn" } },
			Transparency = { { 0, 0 }, { 0.6, 0.2 }, { 1, 1 } },
		},
	}, where)
	return { core, glow }
end

-- Flat part with a decal on top (rune circles, scorch, cracks: stays readable in daylight).
function B.decalDisc(o)
	o = o or {}
	local d = o.size or 14
	return finish({
		id = "decal", kind = "part", t = 0, life = o.life or 2, at = o.at or { 0, 0.06, 0 }, size = { d, 0.05, d },
		props = { Shape = "Block", Material = "SmoothPlastic", Transparency = 1, Color = "deep" },
		decal = { Texture = o.tex or "RUNES", Face = "Top", Color3 = o.color or "body", Transparency = 0 },
		spin = o.spin,
		tracks = {
			Scale = o.scale or { { 0, { 0.3, 1, 0.3 } }, { 0.15, { 1, 1, 1 }, "backOut" } },
			DecalTransparency = o.fade or { { 0, 1 }, { 0.08, 0 }, { 0.75, 0.1 }, { 1, 1 } },
		},
	}, o)
end

-- Point light that pops with the hit and fades (one per effect).
function B.light(o)
	o = o or {}
	return finish({
		id = "light", kind = "light", t = 0, life = o.life or 0.5, at = o.at or { 0, 3, 0 },
		props = { Color = o.color or "body", Range = o.range or 18, Brightness = 0 },
		tracks = { Brightness = { { 0, o.brightness or 6 }, { 0.15, (o.brightness or 6) * 0.8 }, { 1, 0, "quadIn" } } },
	}, o)
end

-- Beam between two points (lasers, tethers).
function B.beam(o)
	o = o or {}
	local w = o.width or 2
	return finish({
		id = "beam", kind = "beam", t = 0, life = o.life or 0.8, at = o.at or { 0, 0, 0 },
		a = o.a or { 0, 3, 0 }, b = o.b or { 0, 3, -40 },
		props = {
			Texture = o.tex or "BEAMFLOW", TextureMode = "Wrap", TextureLength = o.texLength or 8,
			TextureSpeed = o.texSpeed or -3, Color = o.color or "body", LightEmission = 1, Brightness = 3,
			Width0 = w, Width1 = w * (o.taper or 0.9), Transparency = { { 0, 0 }, { 1, 0.1 } },
		},
		tracks = {
			Width = { { 0, 0.1 }, { 0.08, 1.2, "backOut" }, { 0.85, 1 }, { 1, 0, "quadIn" } },
		},
	}, o)
end

-- Faceted crystal / rock spikes erupting in a ring (VFXTimeline Crystal: real geometry, no upload needed).
-- Colours come from the palette (deep, body, white) so recolouring works on them too.
function B.spikes(o)
	o = o or {}
	local n, radius, height = o.count or 9, o.radius or 6, o.height or 6
	local hot = o.hot ~= false
	return {
		id = o.id or "spikes", kind = "custom", t = o.t or 0, life = o.life or 1.6, at = o.at or { 0, 0, 0 },
		start = function(ctx, L)
			local function c(name, fallback)
				local hex = ctx.palette[name]
				local r, g, b = string.match(hex or "", "#(%x%x)(%x%x)(%x%x)")
				if r then
					return Color3.fromRGB(tonumber(r, 16), tonumber(g, 16), tonumber(b, 16))
				end
				return fallback
			end
			local P = { deep = c(o.deepColor or "deep", Color3.fromRGB(40, 30, 25)), body = c(o.bodyColor or "body", Color3.fromRGB(150, 120, 90)),
				tip = c(o.tipColor or "white", Color3.fromRGB(230, 220, 200)) }
			local s = { list = {} }
			for i = 1, n do
				local a = (i / n) * math.pi * 2 + ctx.random:NextNumber(-0.2, 0.2)
				local cr = ctx.Crystal.new("spike", { seed = i + (o.seed or 0), palette = P, parent = ctx.folder, simple = o.simple })
				local h = height * (0.65 + 0.7 * ctx.random:NextNumber()) * ((i % 3 == 0) and 1.2 or 1)
				table.insert(s.list, { c = cr, a = a, h = h, w = (o.width or 1.5) * (0.8 + 0.4 * ctx.random:NextNumber()),
					delay = (o.stagger or 0.012) * i, lean = (o.lean or 22) + ctx.random:NextNumber(-8, 8),
					r = radius * (0.85 + 0.3 * ctx.random:NextNumber()) })
			end
			return s
		end,
		update = function(ctx, L, s, lt)
			local origin = ctx.origin * CFrame.new(Vector3.new(L.at.X, L.at.Y, L.at.Z) * ctx.scale)
			for _, e in s.list do
				local out = Vector3.new(math.cos(e.a), 0, math.sin(e.a))
				local up = (Vector3.yAxis * math.cos(math.rad(e.lean)) + out * math.sin(math.rad(e.lean))).Unit
				local base = origin.Position + origin:VectorToWorldSpace(out * e.r * ctx.scale)
				local upW = origin:VectorToWorldSpace(up)
				local outW = origin:VectorToWorldSpace(out)
				local cf = CFrame.fromMatrix(base, upW:Cross(outW).Unit, upW)
				local g = math.clamp((lt - e.delay) / 0.12, 0, 1)
				local growK = 1 + 2.70158 * (g - 1) ^ 3 + 1.70158 * (g - 1) ^ 2 -- back-out overshoot
				local endK = math.clamp((L.life - lt) / 0.35, 0, 1) -- sink back into the ground at the end
				e.c:set(cf, Vector3.new(e.w * ctx.scale, math.max(0.01, e.h * ctx.scale * growK * (0.25 + 0.75 * endK)), e.w * ctx.scale))
				if hot then
					e.c:hot(1 - math.clamp((lt - e.delay) / 0.15, 0, 1))
				end
				e.c:fade(1 - endK)
			end
		end,
		stop = function(ctx, L, s)
			for _, e in s.list do
				e.c:destroy()
			end
		end,
	}
end

-- Confetti: little paper squares in the palette's colours, fluttering down.
function B.confetti(o)
	o = o or {}
	local n = o.count or 46
	return {
		id = "confetti", kind = "custom", t = o.t or 0, life = o.life or 2.6, at = o.at or { 0, 1, 0 },
		start = function(ctx, L)
			local names = { "body", "accent", "core", "deep", "white" }
			local s = { list = {} }
			for i = 1, n do
				local p = Instance.new("Part")
				p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
				p.Size = Vector3.new(0.7, 0.05, 0.42) * ctx.scale
				p.Material = Enum.Material.SmoothPlastic
				local hex = ctx.palette[names[(i % #names) + 1]] or "#FFFFFF"
				local r, g, b = string.match(hex, "#(%x%x)(%x%x)(%x%x)")
				p.Color = if r then Color3.fromRGB(tonumber(r, 16), tonumber(g, 16), tonumber(b, 16)) else Color3.new(1, 1, 1)
				p.Parent = ctx.folder
				local a = ctx.random:NextNumber(0, math.pi * 2)
				local sp = ctx.random:NextNumber(8, 20)
				table.insert(s.list, { p = p, v = Vector3.new(math.cos(a) * sp * 0.45, ctx.random:NextNumber(18, 30), math.sin(a) * sp * 0.45),
					spin = Vector3.new(ctx.random:NextNumber(-12, 12), ctx.random:NextNumber(-12, 12), ctx.random:NextNumber(-12, 12)),
					phase = ctx.random:NextNumber(0, 6.28) })
			end
			return s
		end,
		update = function(ctx, L, s, lt)
			local base = ctx.origin * CFrame.new(Vector3.new(L.at.X, L.at.Y, L.at.Z) * ctx.scale)
			for _, e in s.list do
				-- fast pop, then air drag and a gentle flutter
				local t = lt
				local drag = 2.2
				local k = (1 - math.exp(-drag * t)) / drag
				local pos = e.v * k + Vector3.new(0, -9 * t * t * 0.5, 0)
				pos += Vector3.new(math.sin(t * 6 + e.phase) * 0.6, 0, math.cos(t * 5 + e.phase) * 0.6) * math.min(1, t)
				e.p.CFrame = base * CFrame.new(pos * ctx.scale) * CFrame.Angles(e.spin.X * t, e.spin.Y * t, e.spin.Z * t)
				e.p.Transparency = math.clamp((lt - (L.life - 0.5)) / 0.5, 0, 1)
			end
		end,
		stop = function(ctx, L, s)
			for _, e in s.list do
				e.p:Destroy()
			end
		end,
	}
end

-- A solid moving along a path (meteors, thrown rocks): Neon ball (or crystal shard) with an Offset track.
function B.mover(o)
	o = o or {}
	local d = o.size or 3
	local L = finish({
		id = "mover", kind = "part", t = 0, life = o.life or 0.5, at = { 0, 0, 0 }, size = { d, d, d },
		props = { Shape = o.shape or "Ball", Material = o.material or "Neon", Color = o.color or "core", Transparency = 0 },
	}, o)
	return secondsTracks(L, { Offset = o.path, Transparency = o.fade }) -- path keys are in seconds
end

-- A trail of particles that follows the same path (emits continuously while moving).
function B.trail(o)
	o = o or {}
	local s = o.size or 2
	local L = finish({
		id = "trail", kind = "emitter", t = 0, life = o.life or 0.5, at = { 0, 0, 0 },
		props = {
			Texture = o.tex or "FLAME", FlipbookLayout = 4, FlipbookMode = "OneShot",
			Color = o.color or { { 0, "white" }, { 0.25, "core" }, { 0.6, "body" }, { 1, "deep" } },
			LightEmission = o.le or 0.8, Brightness = o.brightness or 2.5, LightInfluence = 0, Orientation = "FacingCamera",
			Speed = { 0.5, 2 }, SpreadAngle = { 180, 180 }, Rotation = { -360, 360 }, RotSpeed = { -90, 90 },
			Size = { { 0, s }, { 1, s * 0.25 } }, Transparency = { { 0, 0.05 }, { 1, 1 } }, Lifetime = o.lifetime or { 0.25, 0.45 },
		},
		tracks = { Rate = o.rate or { { 0, 120 }, { 1, 120 } } },
	}, o)
	return secondsTracks(L, { Offset = o.path }) -- the same path (seconds) as the mover it follows
end

-- Gentle colour grade pulse on impact (skipped by FX when the player has reduced motion / noGrade).
function B.grade(o)
	o = o or {}
	return finish({
		id = "grade", kind = "grade", t = 0, life = o.life or 0.3,
		props = { Brightness = 0, Contrast = 0, Saturation = 0, TintColor = "#FFFFFF" },
		tracks = {
			Brightness = { { 0, o.brightness or 0.12 }, { 1, 0, "quadOut" } },
			Contrast = { { 0, o.contrast or 0.25 }, { 1, 0, "quadOut" } },
			Saturation = { { 0, o.saturation or 0.2 }, { 1, 0, "quadOut" } },
		},
	}, o)
end

------------------------------------------------------------------------------------------------------- ambient
-- Area weather / ambience: continuous emission in a box, for looping effects (life = how long it runs).
function B.area(o)
	o = o or {}
	local life = o.life or 600
	local L = finish({
		id = o.id or "area", kind = "emitter", t = 0, life = life, at = o.at or { 0, 0, 0 }, box = o.box or { 40, 1, 40 },
		props = o.props,
	}, {})
	return secondsTracks(L, { Rate = { { 0, o.rate or 40 }, { life, o.rate or 40 } } })
end

-- Wraps layers into a spec with the shared texture table.
function B.spec(def)
	local layers = {}
	local function add(x)
		if x == nil then
			return
		end
		if x.kind then
			table.insert(layers, x)
		else
			for _, y in x do
				add(y)
			end
		end
	end
	add(def.layers)
	return {
		name = def.name or "Effect",
		scale = def.scale or 1,
		palette = copy(def.palette or B.PAL.energy),
		textures = B.TEX,
		layers = layers,
	}
end

return B
