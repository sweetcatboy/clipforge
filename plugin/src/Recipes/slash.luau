-- ClipForge base recipe "slash": from vfxmith (github.com/Frxctured/roblox-vfxmith), knowledge/categories/slash_recipe.luau,
-- MIT License, Copyright (c) 2026 Frxctured (see THIRD_PARTY_NOTICES). Texture ids are public Roblox images owned by
-- their uploaders; their terms apply. Recoloured, retimed and rescaled at play time by ClipForge's FX module.
-- ClipForge change: the wide "glow" uses the clear soft dot 16879789169 (the faint BlurredSpec card showed its
-- square edge over a pale floor in daylight).
-- OSSlash: one generic slash / sword hit for VFXTimeline (vfxmith spec format), distilled from the
-- open-source slash group studied in slash.md (same folder). UNTESTED DRAFT: no Studio capture yet.
-- Sources: GL = glassComboOS glassSlash2 (e68be036caa3), MO = MoltenSlashes Slash1/Attachment1 (63020ef9dca0),
-- PZ = slashes.rbxm pizza (f4fefa4bc478), SS = SacredSwords Portal (7332b80f6ea7). Every texture id below appears in
-- those effects' layer tables; ids without a library thumbnail are marked "look unverified".
-- Geometry: horizontal swing plane at chest height (flat cards emitted "Top", as GL and MO's slash cards). Tilt the
-- whole slash with `rot` on the card layers (e.g. rot = {0, 0, 35} for a diagonal; {0, 0, 90} = vertical). The swing
-- travels toward the emitter part's +X ("Right"), as GL and PZ; Acceleration is world space, rotate it with the swing.
-- S = slash card size, 10.5 studs (swing radius ~5; v1 used 14, glass's value). All bursts fire at t = 0 like every studied effect: flipbooks,
-- Size-from-0 curves and fade-in Transparency keys do the staging.
-- Phases (s, re-read from the 2026-11-14 recapture): pop 0-0.06 | sweep (flipbook draw-in) 0-0.1 | peak 0.1-0.2 |
-- body and ink out by 0.35 | specks, faint ghost arcs to ~0.8 (hanging sparks to ~1.2).
-- Three tones: white/cream core (flash, core strands, hot body ramp start), saturated body (violet/blue cards, glow,
-- streaks), dark ink (Brightness-0 cards, black backing, dark streak twin, black ghost crescents).
-- Brightness: LE 0 + Br 10-30 is the studied "opaque but glowing" stack (MO: 58 of 62 emitters at LE 0). If bloom
-- washes it out, lower the body cards first, never the tiny sparks. Brightness 0 = black ink (seen in the recapture:
-- GL's Br-0 cards show as a black band under the violet crescent at 0.20 s).
-- Molten palette swap: hot "#FF815C", light "#FF4C18", body "#E12E11", deep "#721A00", ink "#0A0A0A".

-- v2 tuning pass (after the first Studio capture): the crescent overflowed the frame and the white core blew out,
-- the pop was not caught at 0.03 s. Half steps: S 14 -> 10.5 (inside the studied 10-19.6), height 3 -> 2, pop life
-- 0.06 -> 0.09 (+ burst 0.03 -> 0.045), core Brightness 30 -> 15 tinted ice blue.
local S = 10.5

local FADE_IN_OUT = { { 0, 1 }, { 0.2, 0 }, { 0.7, 0 }, { 1, 1 } } -- GL slash cards
local HOLD_OUT = { { 0, 0 }, { 0.4, 0.01 }, { 0.6, 0.17 }, { 1, 1 } } -- MO Main/Bck Slash2
local GHOST = { { 0, 1 }, { 0.1, 0.36 }, { 0.3, 0.53 }, { 0.45, 0.9 }, { 1, 1 } } -- MO Thin Winds / Meshed Linger
local GHOST_SIZE = { { 0, 0 }, { 0.1, 0.47 }, { 0.2, 0.66 }, { 0.3, 0.78 }, { 0.5, 0.9 }, { 0.7, 0.96 }, { 1, 1 } } -- MO, x final

local function scaled(curve, k)
	local out = {}
	for i, key in curve do
		out[i] = { key[1], key[2] * k }
	end
	return out
end

local CHEST = { 0, 2, 0 }

return {
	name = "OSSlash",
	palette = {
		white = "#FFFFFF",
		hot = "#FFE19C", -- GL cream
		light = "#82B2F0", -- GL ice blue
		body = "#7B70F8", -- GL violet
		steel = "#5586C6", -- GL steel blue
		deep = "#2A1C70",
		ink = "#0A0A0A", -- MO
	},
	textures = {
		-- [..] at the end of a texture comment = measured traits (gallery/textures/traits.json, legend in kit/scripts/texture_traits.py)
		Star99 = 10598374841, -- thin cross with glow core (GL, MO) [FAINT, white, 1 part, eff 133, fill 8%]
		Impact591 = 11037528577, -- radial streak burst on black, additive only (GL)
		-- [BLACK card, white, 10 parts, eff 112, fill 16%]
		SoftDot = 16879789169, -- clear small soft dot, scaled up = edge-free glow (starter kit)
		BlurredSpec = 11037772334, -- soft blurred spec (MO glow) [FAINT, white, 1 part, eff 16 smooth, fill 40%]
		GreySlash4 = 84127812322926, -- 4x4 grey slash sheet (GL hot body, MO)
		-- [clear, white, 2 parts, eff 103, fill 3%, 15/16 cells]
		GlowingSlash = 13580352351, -- 4x4 glowing slash (MO halo) [clear, white, 1 part, eff 102, fill 4%, 14/16 cells]
		SmallSlash = 13580362430, -- 4x4 thin slash strands (MO) [clear, white, 1 part, eff 99, fill 2%, 13/16 cells]
		Slash28 = 99925185052573, -- 4x4 slash (MO spinning detail) [clear, white, 1 part, eff 82, fill 5%, 13/16 cells]
		LayeredSlash = 9181472195, -- 4x4 layered slash (GL ink, Br 0)
		-- [clear, white, 1 part, eff 84, fill 8%, 14/16 cells]
		BottomBlack = 88366169080988, -- 4x4 "Bottom layer black slash" (MO)
		-- [clear, white, 2 parts, eff ~69, fill 3%, 15/16 cells]
		WindDetails = 15556415618, -- thin broken ring arcs (GL ground ring)
		-- [clear, black+white, 3 parts, eff 139, fill 6%]
		Shards = 17842430380, -- 2x2 shards (GL) [FAINT, white, 1 part, eff 48, fill 15%]
		EmberSpecs = 88848729824097, -- tiny specks in a big frame (GL, MO) [clear, white, 7 parts, eff ~234, fill 4%]
		SparksLinger = 7922645282, -- spark dot (SS) [clear, white, 1 part, eff 115, fill 8%]
		OffCenterSpec = 16171528032, -- off-centre sharp dot (PZ) [clear, white, 1 part, eff 57, fill 3%]
		WavyStreak = 139843022964858, -- 8x8 cells of one small glowing 4-point star, squashed into streaks (PZ "Wavy
		-- Glowing Star" speed lines; seen on its thumbnail 2026-11-14) [FAINT, white, 1 part, eff ~27 smooth, fill 10%]
		MeshedLinger = 104185000871508, -- thin broken crescent arcs (MO ghost crescents)
		-- [clear, white, 4 parts, eff ~207, fill 4%]
		ThinWinds = 123392140151112, -- MO ghost crescents: faint soft swirl arcs in a ring (seen on its thumbnail 2026-11-14)
		-- [FAINT, white, 1 part, eff ~131, fill 13%]
	},
	layers = {
		------------------------------------------------------------------ pop (0 - 0.06)
		{ -- frame-1 cross, full size and shrinking (GL Star99: 20.5-24.6 -> 0 in 0.06 s, ZOffset 4)
			id = "flashStar", kind = "emitter", t = 0, life = 0.05, at = CHEST,
			props = {
				Texture = "Star99", Color = "body", LightEmission = 1, LightInfluence = 0, Brightness = 5,
				Size = { { 0, 1.6 * S }, { 1, 0 } }, Transparency = { { 0, 0 }, { 0.65, 0 }, { 1, 1 } },
				Lifetime = 0.09, Speed = 0, Rotation = { -360, 360 }, ZOffset = 4, -- v1 0.06 was never caught
			},
			emit = { { 0, 1 } },
		},
		{ -- 2-frame radial burst behind the cross (GL Impact591: 0 -> 16 over 0.03 s)
			id = "flashBurst", kind = "emitter", t = 0, life = 0.05, at = CHEST,
			props = {
				Texture = "Impact591", Color = "body", LightEmission = 1, LightInfluence = 0, Brightness = 5,
				Size = { { 0, 0 }, { 1, 1.15 * S } }, Transparency = 0,
				Lifetime = 0.045, Speed = 0, Rotation = { -360, 360 }, ZOffset = 4, -- v1 0.03
			},
			emit = { { 0, 1 } },
		},
		{ -- faint wide glow over the hit (MO Blurred Spec 6: Br 2, Size 18.7, never above 0.85 transparency, ZOffset 5)
			id = "glow", kind = "emitter", t = 0, life = 0.05, at = CHEST,
			props = {
				Texture = "SoftDot", Color = "body", LightEmission = 1, LightInfluence = 0, Brightness = 2,
				Size = 2.6 * S, Transparency = { { 0, 1 }, { 0.3, 0.85 }, { 1, 1 } },
				Lifetime = 0.75, Speed = 0, ZOffset = 5,
			},
			emit = { { 0, 1 } },
		},
		------------------------------------------------------------------ crescent stack (0 - 0.63)
		{ -- black backing card, bigger than the body (MO Bottom layer black slash: #0A0A0A Br 6, 17.7, 0.25 s;
			-- MO Black Slash2: 1.2 S, only -40 deg/s). Life 0.35: the recapture shows MO's ink gone by 0.35 s even on
			-- its 0.63-s cards
			id = "inkBack", kind = "emitter", t = 0, life = 0.05, at = CHEST,
			props = {
				Texture = "BottomBlack", FlipbookLayout = 4, FlipbookMode = "OneShot",
				Color = "ink", LightEmission = 0, LightInfluence = 0, Brightness = 6,
				Orientation = "VelocityPerpendicular", EmissionDirection = "Top", Speed = 0.001,
				Size = 1.2 * S, Transparency = HOLD_OUT, Lifetime = 0.35,
				Rotation = { 290, 290 }, RotSpeed = { -40, -40 }, ZOffset = -0.5,
			},
			emit = { { 0, 1 } },
		},
		{ -- Brightness-0 ink card turning at half the body's speed: lags 54 deg by its end (GL Grey Slash 2 x3: Br 0,
			-- RotSpeed -180, sizes 8/13.8/15.2; texture from GL Layered Slash, the Br-0 ink at ZOffset -0.5)
			id = "inkLag", kind = "emitter", t = 0, life = 0.05, at = CHEST,
			props = {
				Texture = "LayeredSlash", FlipbookLayout = 4, FlipbookMode = "OneShot",
				Color = "deep", LightEmission = 0, LightInfluence = 0, Brightness = 0,
				Orientation = "VelocityPerpendicular", EmissionDirection = "Top", Speed = 0.0014,
				Size = { { 0, 1.0 * S, 0.1 * S }, { 1, 1.0 * S, 0.1 * S } }, -- envelope: each card a bit different
				Transparency = FADE_IN_OUT, Lifetime = 0.3,
				Rotation = { 340, 340 }, RotSpeed = { -180, -180 }, ZOffset = -0.1,
			},
			emit = { { 0, 2 } },
		},
		{ -- hot opaque body: still card, the flipbook draws the sweep (GL Grey Slash 4: LE 0, Br 10, cream -> ice blue
			-- @0.39 -> violet @0.66, Size 14, 0.3 s, RotSpeed 0)
			id = "body", kind = "emitter", t = 0, life = 0.05, at = CHEST,
			props = {
				Texture = "GreySlash4", FlipbookLayout = 4, FlipbookMode = "OneShot",
				Color = { { 0, "hot" }, { 0.16, "hot" }, { 0.39, "light" }, { 0.66, "body" }, { 1, "body" } },
				LightEmission = 0, LightInfluence = 0, Brightness = 10,
				Orientation = "VelocityPerpendicular", EmissionDirection = "Top", Speed = 0.0014,
				Size = S, Transparency = FADE_IN_OUT, Lifetime = 0.3,
				Rotation = { 300, 300 }, RotSpeed = { 0, 0 }, ZOffset = 0.1,
			},
			emit = { { 0, 1 } },
		},
		{ -- additive halo copy, turning -360 deg/s (108 deg over its life) (GL Shaded Slash 3: LE 1 Br 10, RotSpeed -360;
			-- texture and 1.15 S size from MO Glowing Slash)
			id = "halo", kind = "emitter", t = 0, life = 0.05, at = CHEST,
			props = {
				Texture = "GlowingSlash", FlipbookLayout = 4, FlipbookMode = "OneShot",
				Color = { { 0, "body" }, { 0.47, "steel" }, { 0.7, "hot" }, { 1, "hot" } },
				LightEmission = 1, LightInfluence = 0, Brightness = 10,
				Orientation = "VelocityPerpendicular", EmissionDirection = "Top", Speed = 0.0014,
				Size = 1.15 * S, Transparency = FADE_IN_OUT, Lifetime = 0.3,
				Rotation = { 320, 320 }, RotSpeed = { -360, -360 }, ZOffset = -0.2,
			},
			emit = { { 0, 1 } },
		},
		{ -- white core strands, 3 cards with a size envelope, LE 0 at high Brightness (MO Small Slash 2: EmitCount 3,
			-- Br 30, Size 11.5 +-2.4, 0.38 s, Transparency 0 to 0.5 then out)
			id = "core", kind = "emitter", t = 0, life = 0.05, at = CHEST,
			props = {
				Texture = "SmallSlash", FlipbookLayout = 4, FlipbookMode = "OneShot",
				Color = "light", LightEmission = 0, LightInfluence = 0, Brightness = 15, -- v1 white x 30 blew out to flat white blobs
				Orientation = "VelocityPerpendicular", EmissionDirection = "Top", Speed = 0.0009,
				Size = { { 0, 0.82 * S, 0.17 * S }, { 1, 0.82 * S, 0.17 * S } },
				Transparency = { { 0, 0 }, { 0.5, 0 }, { 1, 1 } }, Lifetime = 0.38,
				Rotation = { 290, 310 }, RotSpeed = { -360, -360 }, ZOffset = 0.15,
			},
			emit = { { 0, 3 } },
		},
		{ -- counter-rotating detail fill (MO Slash28: +627 deg/s while its neighbours turn negative; Br 10, Size 14.5)
			id = "detail", kind = "emitter", t = 0, life = 0.05, at = CHEST,
			props = {
				Texture = "Slash28", FlipbookLayout = 4, FlipbookMode = "OneShot",
				Color = "light", LightEmission = 0, LightInfluence = 0, Brightness = 10,
				Orientation = "VelocityPerpendicular", EmissionDirection = "Top", Speed = 0.0011,
				Size = 1.0 * S, Transparency = { { 0, 0 }, { 0.5, 0 }, { 1, 1 } }, Lifetime = 0.38,
				Rotation = { 0, 360 }, RotSpeed = { 627, 627 }, ZOffset = 0.1,
			},
			emit = { { 0, 1 } },
		},
		------------------------------------------------------------------ ground (0 - 0.4)
		{ -- faint grey wind rings on the floor, each a different radius (GL Wind Details: LE 1, Br 0.05, Size 11.2 +-5.6
			-- -> 20, 0.2-0.4 s, RotSpeed -180..-90, Spread 10, EmitCount 4). Br 0.05 read as a faint grey in GL's stills.
			id = "groundRing", kind = "emitter", t = 0, life = 0.05, at = { 0, 0.15, 0 },
			props = {
				Texture = "WindDetails", Color = "white", LightEmission = 1, LightInfluence = 0, Brightness = 0.05,
				Orientation = "VelocityPerpendicular", EmissionDirection = "Top", Speed = 0.0016, SpreadAngle = { 10, 10 },
				Size = { { 0, 0.8 * S, 0.4 * S }, { 0.5, 1.25 * S, 0.4 * S }, { 1, 1.43 * S, 0.4 * S } },
				Transparency = { { 0, 0 }, { 1, 1 } }, Lifetime = { 0.2, 0.4 },
				Rotation = { -180, 540 }, RotSpeed = { -180, -90 }, ZOffset = 1,
			},
			emit = { { 0, 4 } },
		},
		------------------------------------------------------------------ motion (0 - 0.25)
		{ -- speed lines that stretch while thinning, along the swing (PZ Wavy Glowing Star: Speed 72-144, Drag 5,
			-- Size 5 -> 0, Squash 0 -> 5, 0.15-0.2 s, LE 0 Br 45)
			id = "speedLines", kind = "emitter", t = 0, life = 0.05, at = CHEST,
			props = {
				Texture = "WavyStreak", FlipbookLayout = 8, FlipbookMode = "OneShot",
				Color = "body", LightEmission = 0, LightInfluence = 0, Brightness = 45,
				Orientation = "VelocityParallel", EmissionDirection = "Right", Speed = { 72, 144 }, Drag = 5,
				Size = { { 0, 0.36 * S }, { 1, 0 } }, Squash = { { 0, 0 }, { 1, 5 } },
				Transparency = { { 0, 1 }, { 0.3, 0 }, { 0.8, 0 }, { 1, 1 } }, Lifetime = { 0.15, 0.2 },
				Rotation = { 90, 90 }, ZOffset = 0.1,
			},
			emit = { { 0, 4 } },
		},
		{ -- dark twin of the speed lines (PZ: same streak, #0C0405, LightEmission -0.5, Br 45). Negative LE is outside
			-- the documented 0-1 range: check it still darkens after engine updates; else LE 0 with Brightness 0.
			id = "inkStreaks", kind = "emitter", t = 0, life = 0.05, at = CHEST,
			props = {
				Texture = "WavyStreak", FlipbookLayout = 8, FlipbookMode = "OneShot",
				Color = "#0C0405", LightEmission = -0.5, LightInfluence = 0, Brightness = 45,
				Orientation = "VelocityParallel", EmissionDirection = "Right", Speed = { 72, 144 }, Drag = 5,
				Size = { { 0, 0.36 * S }, { 1, 0 } }, Squash = { { 0, 0 }, { 1, 5 } },
				Transparency = { { 0, 1 }, { 0.3, 0 }, { 0.8, 0 }, { 1, 1 } }, Lifetime = { 0.15, 0.2 },
				Rotation = { 90, 90 }, ZOffset = 0.05,
			},
			emit = { { 0, 4 } },
		},
		------------------------------------------------------------------ sparks and shards (0 - 1.2)
		{ -- curling sparks blown along the swing (PZ OffCentered Spec: Spread 360, Speed 76-153, Drag 15,
			-- Acceleration {600, -50, 0}, RotSpeed +-1000, Br 15)
			id = "curlSparks", kind = "emitter", t = 0, life = 0.05, at = CHEST,
			props = {
				Texture = "OffCenterSpec", Color = "light", LightEmission = 0, LightInfluence = 0, Brightness = 15,
				Orientation = "VelocityParallel", EmissionDirection = "Right", SpreadAngle = { -360, 360 },
				Speed = { 76, 153 }, Drag = 15, Acceleration = { 600, -50, 0 },
				Size = { { 0, 0.07 * S }, { 1, 0 } }, Transparency = 0, Lifetime = { 0.4, 0.7 },
				Rotation = { -360, 360 }, RotSpeed = { -1000, 1000 }, ZOffset = 0.1,
			},
			emit = { { 0, 4 } },
		},
		{ -- pop-and-hang sparks: peak size at 6% of life, drag stops them, then they hang (SS SparksLinger: Speed 14-97,
			-- Drag 5.15, Spread 45, Br 35, ZOffset 3.5; count cut 25 -> 16 and life 1.75 -> 1.2 for a single hit)
			id = "sparks", kind = "emitter", t = 0, life = 0.05, at = CHEST,
			props = {
				Texture = "SparksLinger", Color = "hot", LightEmission = 1, LightInfluence = 0, Brightness = 35,
				Orientation = "VelocityParallel", EmissionDirection = "Right", SpreadAngle = { 45, 45 },
				Speed = { 14, 97 }, Drag = 5.15,
				Size = { { 0, 0 }, { 0.06, 0.03 * S }, { 1, 0 } }, Transparency = 0, Lifetime = { 0.58, 1.2 },
				Rotation = { -360, 360 }, RotSpeed = { -343, 343 }, ZOffset = 3.5,
			},
			emit = { { 0, 16 } },
		},
		{ -- tiny specks drifting off the swing, colour ramp violet -> blue -> cream (GL small ember specs: LE 0 Br 10,
			-- Size 6 const = a speck in a big frame, Speed 4-14, 0.2-0.3 s, fade-in to 0.3)
			id = "embers", kind = "emitter", t = 0, life = 0.05, at = CHEST,
			props = {
				Texture = "EmberSpecs", Color = { { 0, "body" }, { 0.5, "steel" }, { 1, "hot" } },
				LightEmission = 0, LightInfluence = 0, Brightness = 10,
				EmissionDirection = "Right", Speed = { 4, 14 }, Size = 0.43 * S,
				Transparency = { { 0, 1 }, { 0.3, 0 }, { 1, 1 } }, Lifetime = { 0.2, 0.3 }, Rotation = { -360, 360 },
			},
			emit = { { 0, 5 } },
		},
		{ -- glass shards, one fixed hue per layer (GL Shards 2x2 2: three palette copies x 2, LE 0 Br 10,
			-- Size 0.72 -> 0, Speed 4-14, 0.2-0.4 s; one copy here, add cream/blue copies for the palette trick)
			id = "shards", kind = "emitter", t = 0, life = 0.05, at = CHEST,
			props = {
				Texture = "Shards", FlipbookLayout = 2, FlipbookMode = "OneShot",
				Color = "body", LightEmission = 0, LightInfluence = 0, Brightness = 10,
				EmissionDirection = "Right", Speed = { 4, 14 }, Size = { { 0, 0.05 * S }, { 1, 0 } },
				Transparency = 0, Lifetime = { 0.2, 0.4 }, Rotation = { -360, 360 },
			},
			emit = { { 0, 4 } },
		},
		------------------------------------------------------------------ linger (0.1 - 1.2)
		{ -- glowing ghost crescents that keep opening, tilted fan (MO Meshed Linger: dark #481000 x Br 32, Spread 32,
			-- Speed up to 0.29, Size 0 -> 16.4 +-2.7, Transparency min 0.38 at 0.1 of life, 0.32-1.07 s)
			id = "ghostGlow", kind = "emitter", t = 0, life = 0.05, at = CHEST,
			props = {
				Texture = "MeshedLinger", Color = "deep", LightEmission = 0, LightInfluence = 0, Brightness = 32,
				Orientation = "VelocityPerpendicular", EmissionDirection = "Top", SpreadAngle = { 32, 32 },
				Speed = { 0.0012, 0.29 }, Size = scaled(GHOST_SIZE, 1.15 * S), Transparency = GHOST,
				Lifetime = { 0.32, 1.07 }, Rotation = { 325, 325 }, RotSpeed = { 6, 6 },
			},
			emit = { { 0, 2 } },
		},
		{ -- black ghost crescents: the slash ends dark (MO Thin Winds: Brightness 0, Size 0 -> 21.8 +-3.6, Spread 15,
			-- RotSpeed -17.4, 0.32-1.7 s, ZOffset 0.002)
			id = "ghostInk", kind = "emitter", t = 0, life = 0.05, at = CHEST,
			props = {
				Texture = "ThinWinds", Color = "ink", LightEmission = 0, LightInfluence = 0, Brightness = 0,
				Orientation = "VelocityPerpendicular", EmissionDirection = "Top", SpreadAngle = { 15, 15 },
				Speed = 0.0016, Size = scaled(GHOST_SIZE, 1.4 * S), Transparency = GHOST,
				Lifetime = { 0.32, 1.2 }, Rotation = { 0, 720 }, RotSpeed = { -17, -17 }, ZOffset = 0.002,
			},
			emit = { { 0, 3 } },
		},
	},
}
