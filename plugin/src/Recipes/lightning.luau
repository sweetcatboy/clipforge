-- ClipForge base recipe "lightning": from vfxmith (github.com/Frxctured/roblox-vfxmith), knowledge/categories/lightning_recipe.luau,
-- MIT License, Copyright (c) 2026 Frxctured (see THIRD_PARTY_NOTICES). Texture ids are public Roblox images owned by
-- their uploaders; their terms apply. Recoloured, retimed and rescaled at play time by ClipForge's FX module.
-- LightningStrike: one generic lightning / electric ground strike for VFXTimeline (vfxmith spec format),
-- distilled from the 7 open-source effects studied in lightning.md (same folder). UNTESTED DRAFT: no Studio capture yet.
-- Phases (s): ink frame 0-0.05 | flash 0.03-0.15 | bolts 0.03-0.45 (re-strikes at +0.1, +0.2) | streaks and
-- rings 0.03-0.35 | arcs, crescents, smoke 0.05-1.3 | second beat (shards) 0.5-0.9 | linger (scorch, glints) to ~2.6.
-- Scale: R = 6 studs (character-scale strike); every size and speed is a multiple of R, so opts.scale resizes it.
-- Three tones: white core (flash, star, glow, hot bolt start, needles, glints), saturated electric blue body
-- (solid bolts, shock card, arcs, crescents, shards), dark ink (ink frame, ink bolts, smoke, scorch).
-- Sources: PIL = LightingPillar Main/Lightning 7363005673d2, DEB = Debris30 6bd2745beea6, HAND = Voidstrike handeff
-- 69f2a565d257, LB = lightningburst Debris 5b3db2b419f7, TH = iso_textures THUNDER af00e114ff57,
-- LOS = lightningos Character 7a7a6d0cb951.
-- Changes from the sources on purpose: one flash event only (PIL re-emitted a 151-stud card at Rate 30/s = strobe);
-- the ink frame uses 150 cards, not LOS's 500; TimeScale tricks are baked into Lifetime (the runtime owns TimeScale).
-- Textures without a library thumbnail (check once in Studio): 18751910490 (LOS ink lines), 17745162015 (TH crater).
-- Unverified: VelocityParallel + negative Squash needles (layer "needles"; see lightning.md d.16).
-- Revised 2026-11-14 after the corrected recapture: only comments changed (ink frame and scorch evidence).
-- v2 tuning (2026-11-14, after the first Studio capture showed flash + a few bolts, then nothing): added a strike
-- column (2 beams, 3 strikes down one channel at 0.03 / 0.13 / 0.23), 2 more bolt beats (+0.35, +0.55), a second
-- star at +0.45, a ground burn glow that cools over 1.6 s, and half-step raises to arcs, crescents, shards, glints.

local R = 6

-- Ease-out size shape measured on PIL's radial card and energy rings (fraction of final size at time t).
local EASE_OUT = { { 0, 0 }, { 0.1, 0.37 }, { 0.2, 0.56 }, { 0.3, 0.68 }, { 0.5, 0.85 }, { 0.7, 0.945 }, { 1, 1 } }

local function grow(curve, peak)
	local out = {}
	for i, k in ipairs(curve) do
		out[i] = { k[1], k[2] * peak }
	end
	return out
end

-- Bolt flicker (PIL Lightning1/2, rescaled to ~0.5-2 R and visible from frame 1): size jumps between 0 and a peak
-- and transparency blinks off for ~3% of life four times, so a 0.07-0.3 s particle blinks 3-5 times.
local BOLT_SIZE = {
	{ 0, 4 }, { 0.06, 9 }, { 0.1, 6 }, { 0.2, 5 }, { 0.25, 9 }, { 0.3, 3 }, { 0.42, 6 }, { 0.445, 0 }, { 0.5, 12 },
	{ 0.53, 6 }, { 0.55, 0 }, { 0.58, 6 }, { 0.66, 3 }, { 0.74, 7 }, { 0.8, 5 }, { 0.82, 0 }, { 0.88, 3 }, { 1, 0 },
}
local BOLT_BLINK = {
	{ 0, 0 }, { 0.2, 0 }, { 0.23, 1 }, { 0.26, 0 }, { 0.42, 0 }, { 0.445, 1 }, { 0.48, 0 }, { 0.62, 0 }, { 0.645, 1 },
	{ 0.67, 0 }, { 0.8, 0 }, { 1, 1 },
}

return {
	name = "LightningStrike",
	palette = {
		white = "#F4F7FF",
		hot = "#CFE0FF", -- TH flash/glow tint (#D2E3FF)
		body = "#4F86FF", -- between LOS #3964FF and HAND #5185EC
		violet = "#7A5CFF",
		deep = "#0329FF", -- LOS ToonLightning2
		inkBlue = "#0B1240",
		ink = "#000000",
	},
	textures = {
		-- [..] at the end of a texture comment = measured traits (gallery/textures/traits.json, legend in kit/scripts/texture_traits.py)
		InkLines = 18751910490, -- LOS "lines" (Grid4x4); no thumbnail [clear, white, 2 parts, eff ~74, fill 18%]
		Starburst = 16151520120, -- PIL "Impact" starburst (D) [clear, white, 1 part, eff ~112, fill 21%]
		Star4 = 7160024951, -- HAND 4-point star with glow on a dark haze card: additive only (A) [DARK haze, grey, 1 part, eff 127, fill 15%]
		Glow = 12159555294, -- LOS "Glow" medium soft glow (M) [FAINT, white, 1 part, eff 29 smooth, fill 25%]
		BoltSheet = 13622252312, -- PIL Lightning1 jagged bolts (Grid4x4 per the texture index; PIL played it as 8x8)
		-- [clear, white, 6 parts, eff 107, fill 3%, 15/16 cells]
		ToonBoltA = 98371801305515, -- LOS ToonLightning (Grid4x4, D) [clear, white, 1 part, eff 85, fill 3%]
		ToonBoltB = 98016283117283, -- LOS ToonLightning / Bolt model LE -1 variant (Grid4x4, D)
		-- [clear, white, 1 part, eff 71, fill 11%, 12/16 cells]
		Needle = 14080708584, -- LOS "FingerHit" arrow streak (M) [clear, white, 1 part, eff 30 smooth, fill 20%]
		Disc = 1084982817, -- LB "dotsburst" solid disc (M) [clear, white, 1 part, eff 28 smooth, fill 70%]
		RadialCard = 12043778355, -- PIL "Shockwave2" radial streak burst (M) [clear, white, 7 parts, eff ~182, fill 6%]
		ShockRing = 13478831328, -- HAND "Shock" ring (D) [FAINT, white, 1 part, eff 43 smooth, fill 36%]
		Arc = 1084996536, -- LB "wind4" sharp arc on BLACK: additive only (A)
		-- [BLACK card, white, 1 part, eff 198, fill 1%]
		Crescents = 17085222506, -- LOS "wind stuff" crescents (Grid4x4, M)
		-- [clear, white, 2 parts, eff 87, fill 5%, 8/16 cells]
		Clouds = 14006773822, -- DEB realistic clouds (Grid4x4, D) [clear, grey, 1 part, eff 21 smooth, fill 25%]
		Shards = 10439119562, -- LOS "Shards" lens streak (M) [clear, white, 1 part, eff 105, fill 3%]
		Crater = 17745162015, -- TH ground crater; no thumbnail [clear, white, 1 part, eff 110, fill 41%]
		OrbitDot = 8414194072, -- LB "Specs" dot in the top-left corner (A) [clear, white, 1 part, eff 199, fill 1%]
		Lines = 8415143764, -- PIL pillar beam "Lines": vertical streaks on BLACK, additive only (A)
		-- [BLACK card, white, 2 parts, eff 307, fill 30%]
	},
	layers = {
		------------------------------------------------------------------ ink frame (0 - 0.05)
		{ -- black cards for 1-3 frames so the flash lands on black (LOS lines: #000000, LE -1, life 0.05, x500).
			-- Seen only in the first capture (the 2026-11-14 recapture's 0.03 frame of LOS is empty): verify in the
			-- first Studio capture; disable this layer if it does not read.
			id = "inkFrame", kind = "emitter", t = 0, life = 0.05, at = { 0, R * 0.5, 0 }, box = { R * 1.5, R, R * 1.5 },
			props = {
				Texture = "InkLines", FlipbookLayout = 4, FlipbookMode = "Loop", FlipbookFramerate = { 30, 30 },
				Color = "ink", LightEmission = -1, Brightness = 1, Shape = "Box",
				Size = R * 1.2, Squash = -0.3, Orientation = "FacingCameraWorldUp",
				Transparency = { { 0, 0.575 }, { 0.56, 0.84 }, { 1, 1 } }, Lifetime = 0.05, Speed = 0.001,
				Rotation = { 0, 360 }, ZOffset = 1,
			},
			emit = { { 0, 150 } },
		},
		------------------------------------------------------------------ flash (0.03 - 0.15)
		{ -- big starburst cards lying at random tilts, swelling to 6R and gone by 0.12 s (PIL Impact: LE 0.5, Br 25,
			-- swell 0 -> 151 @0.65 -> 0, life 0.04-0.125, Spread 50, Squash 0.4; TH flash 4R). Br 12: tune with bloom.
			id = "flash", kind = "emitter", t = 0.03, life = 0.05, at = { 0, R * 0.5, 0 },
			props = {
				Texture = "Starburst", Color = { { 0, "white" }, { 0.5, "hot" }, { 1, "body" } },
				LightEmission = 0.5, Brightness = 12,
				Size = { { 0, 0 }, { 0.65, R * 6 }, { 1, 0 } }, Squash = 0.4, Transparency = 0,
				Lifetime = { 0.06, 0.12 }, Orientation = "VelocityPerpendicular", Speed = 0.2, SpreadAngle = { 50, 50 },
				Rotation = { 0, 360 }, ZOffset = 6,
			},
			emit = { { 0, 2 } },
		},
		{ -- white 4-point star whose size blinks 3 times in 0.15 s (HAND star: 2.55/3.85/1.95/3.85/0.99/3.85/0)
			-- v2: a second star at +0.45 as the late beat (HAND end glint at 0.35 s; PIL re-flares; 2 flashes < 3/s)
			id = "coreStar", kind = "emitter", t = 0.03, life = 0.5, at = { 0, R * 0.5, 0 },
			props = {
				Texture = "Star4", Color = "white", LightEmission = 1, Brightness = 10,
				Size = { { 0, R * 1.0 }, { 0.13, R * 1.6 }, { 0.17, R * 0.8 }, { 0.25, R * 1.6 }, { 0.33, R * 0.4 },
					{ 0.41, R * 1.6 }, { 1, 0 } },
				Transparency = 0, Lifetime = 0.15, Speed = 0, Rotation = { -300, 300 }, RotSpeed = { -500, 500 },
				ZOffset = 7,
			},
			emit = { { 0, 1 }, { 0.45, 1 } },
		},
		{ -- wide soft glow that cools to black (TH glow: LE 1, Br 3, 85 studs = 3R, Squash -0.5, 0.5 s, Color -> black)
			id = "glow", kind = "emitter", t = 0.03, life = 0.05, at = { 0, R * 0.6, 0 },
			props = {
				Texture = "Glow", Color = { { 0, "hot" }, { 1, "#000000" } }, LightEmission = 1, Brightness = 2,
				Size = R * 3, Squash = -0.5, Transparency = { { 0, 0.2 }, { 1, 1 } }, Lifetime = 0.4, Speed = 0,
				ZOffset = 3,
			},
			emit = { { 0, 1 } },
		},
		------------------------------------------------------------------ strike column (0.03 - 0.33), v2
		{ -- sky-to-ground channel, 3 strikes down the same path (TH sky bolt d.9: Segments 2, CurveSize -55/-200,
			-- width 0.25R at the ground -> ~0.9R at the sky, LE 1, Br 10, Wrap texture; PIL beam texture `Lines` LE 1 Br 6.5,
			-- TextureSpeed 3-10). Segments 3 + equal CurveSizes = a zigzag of +-0.22 x CurveSize (2 kinks). Br 3, not 10:
			-- a 36-stud additive beam at Br 10 washes out; raise by half steps if it reads weak.
			id = "strikeBody", kind = "beam", t = 0.03, life = 0.1, copies = { n = 3, every = 0.1 },
			a = { 0, 0, 0 }, b = { R * 0.5, R * 6, R * 0.2 }, axis = { 1, 0, 0 },
			props = {
				Texture = "Lines", TextureMode = "Wrap", TextureLength = R * 2, TextureSpeed = 6,
				Width0 = R * 0.35, Width1 = R * 0.7, Segments = 3, CurveSize0 = R * 3, CurveSize1 = R * 3,
				Color = { { 0, "hot" }, { 0.5, "body" }, { 1, "violet" } }, LightEmission = 1, Brightness = 3,
				Transparency = { { 0, 0 }, { 0.7, 0.1 }, { 1, 0.7 } },
			},
			tracks = {
				Width = { { 0, 1.4 }, { 0.035, 1, "quadOut" }, { 0.1, 0.6 } }, -- pop 1.4x on frame 1 (PATTERNS 2)
				Fade = { { 0, 0 }, { 0.05, 0 }, { 0.1, 1 } }, -- on ~3 frames, gone in 0.1 s (vault: < 0.2 s)
			},
		},
		{ -- white core of the same channel (same geometry and copies, no jitter, so it stays inside the body)
			id = "strikeCore", kind = "beam", t = 0.03, life = 0.1, copies = { n = 3, every = 0.1 },
			a = { 0, 0, 0 }, b = { R * 0.5, R * 6, R * 0.2 }, axis = { 1, 0, 0 },
			props = {
				Width0 = R * 0.08, Width1 = R * 0.16, Segments = 3, CurveSize0 = R * 3, CurveSize1 = R * 3,
				Color = "white", LightEmission = 1, Brightness = 2,
				Transparency = { { 0, 0 }, { 0.8, 0 }, { 1, 0.5 } },
			},
			tracks = {
				Width = { { 0, 1.4 }, { 0.035, 1, "quadOut" }, { 0.1, 0.6 } },
				Fade = { { 0, 0 }, { 0.05, 0 }, { 0.1, 1 } },
			},
		},
		------------------------------------------------------------------ bolts (0.03 - 0.7)
		{ -- additive bolts scattered by a 400x speed range + Drag 62 (stop at Speed/Drag = 0-6.5 studs ~ R), blinking
			-- via BOLT_SIZE/BOLT_BLINK, re-striking twice (PIL Lightning1/2: Speed 2-2136, Drag 62.2, Spread 95,
			-- VelocityParallel, Rotation -90, Squash 1, LE 1, Br 25, colour-by-age ramp)
			-- v2: two more, smaller beats at +0.35 / +0.55 (PIL keeps crackling 3.4 s with re-flares at 0.8 / 1.2 / 2.6)
			id = "boltsHot", kind = "emitter", t = 0.03, life = 0.6, at = { 0, R * 0.5, 0 },
			props = {
				Texture = "BoltSheet", FlipbookLayout = 4, FlipbookMode = "OneShot",
				Color = { { 0, "white" }, { 0.45, "hot" }, { 1, "violet" } }, LightEmission = 1, Brightness = 20,
				Size = BOLT_SIZE, Transparency = BOLT_BLINK, Lifetime = { 0.07, 0.3 },
				Speed = { 1, 400 }, Drag = 62, SpreadAngle = { 95, 95 }, Orientation = "VelocityParallel",
				Rotation = { -90, -90 }, Squash = 1, ZOffset = 8,
			},
			emit = { { 0, 10 }, { 0.1, 5 }, { 0.2, 4 }, { 0.35, 4 }, { 0.55, 3 } },
		},
		{ -- solid toon bolts: normal blend + Br 15 keeps the blue saturated under bloom (LOS ToonLightning: LE 0,
			-- Br 15, Size 5 = 1R, life 0.1-0.3, Grid4x4 OneShot, 1 per emitter x 8 emitters)
			id = "boltsSolid", kind = "emitter", t = 0.03, life = 0.6, at = { 0, R * 0.6, 0 },
			box = { R * 1.5, R * 0.6, R * 1.5 },
			props = {
				Texture = "ToonBoltA", FlipbookLayout = 4, FlipbookMode = "OneShot", Shape = "Box",
				Color = "body", LightEmission = 0, Brightness = 15, Size = R * 1.15, Transparency = 0,
				Lifetime = { 0.1, 0.3 }, Speed = 0.1, Rotation = { 0, 360 }, ZOffset = 2,
			},
			emit = { { 0, 3 }, { 0.09, 2 }, { 0.19, 2 }, { 0.34, 2 }, { 0.54, 1 } },
		},
		{ -- dark ink bolts behind the bright ones (LOS ToonLightning2 #0329FF; the LOS Bolt model runs the same sheet at
			-- LE -1, Br 15). This is the black-between-bright-bolts tone.
			id = "boltsInk", kind = "emitter", t = 0.05, life = 0.05, at = { 0, R * 0.6, 0 },
			box = { R * 1.6, R * 0.6, R * 1.6 },
			props = {
				Texture = "ToonBoltB", FlipbookLayout = 4, FlipbookMode = "OneShot", Shape = "Box",
				Color = "deep", LightEmission = -1, Brightness = 15, Size = R * 1.35, Transparency = 0,
				Lifetime = { 0.15, 0.35 }, Speed = 0.1, Rotation = { 0, 360 }, ZOffset = 0,
			},
			emit = { { 0, 3 } },
		},
		------------------------------------------------------------------ streaks, sticks, rings (0.03 - 0.35)
		{ -- white needles shooting out and stopping (LOS FingerHit: Size 2, life 0.07, Squash -1.39 -> -2.77, LE 1, Br 35;
			-- distance from TH streaks: Speed 950 / Drag 39 = 0.9R). Stop here at 4-10 studs.
			id = "needles", kind = "emitter", t = 0.03, life = 0.05, at = { 0, R * 0.3, 0 },
			props = {
				Texture = "Needle", Color = { { 0, "white" }, { 1, "body" } }, LightEmission = 1, Brightness = 20,
				Size = R * 0.27, Squash = { { 0, -1.4 }, { 1, -2.8 } }, Transparency = 0, Lifetime = { 0.1, 0.2 },
				Speed = { R * 20, R * 50 }, Drag = 30, SpreadAngle = { 80, 80 }, Orientation = "VelocityParallel",
				ZOffset = 4,
			},
			emit = { { 0, 14 } },
		},
		{ -- 2-frame sticks that shrink to drifting dots (LB dotsburst: Size 5.27 -> 0.04 by 5% of 0.65 s, Squash -3,
			-- LE 0, Br 2.09, Speed 1-20, Drag 6.5, Spread 50, rising)
			id = "sticks", kind = "emitter", t = 0.03, life = 0.05, at = { 0, R * 0.2, 0 },
			box = { R, R * 0.2, R },
			props = {
				Texture = "Disc", Color = "hot", LightEmission = 0, Brightness = 2, Shape = "Box",
				Size = { { 0, R * 0.5 }, { 0.05, 0.05 }, { 1, 0 } }, Squash = { { 0, -3 }, { 0.62, -3 }, { 1, 0 } },
				Transparency = 0, Lifetime = 0.65, Speed = { 1, 20 }, Drag = 6.5, SpreadAngle = { 50, 50 },
				Acceleration = { 0, 10, 0 }, Orientation = "VelocityParallel",
			},
			emit = { { 0, 20 } },
		},
		{ -- radial streak card, mostly flat, ease-out to 2R (PIL Shockwave2: LE 0, Br 10, 0 -> 21.3, 0.08-0.29 s,
			-- Transparency 1 -> 0 @0.1 -> 0 @0.5 -> 1, Spread 35, Squash 1, x15)
			id = "shockCard", kind = "emitter", t = 0.03, life = 0.05, at = { 0, R * 0.15, 0 },
			props = {
				Texture = "RadialCard", Color = { { 0, "deep" }, { 0.45, "body" }, { 1, "deep" } },
				LightEmission = 0, Brightness = 10,
				Size = grow(EASE_OUT, R * 2), Squash = 1, Transparency = { { 0, 1 }, { 0.1, 0 }, { 0.5, 0 }, { 1, 1 } },
				Lifetime = { 0.08, 0.29 }, Orientation = "VelocityPerpendicular", EmissionDirection = "Top",
				Speed = 0.002, SpreadAngle = { 35, 35 }, Rotation = { 0, 360 }, ZOffset = 1,
			},
			emit = { { 0, 8 } },
		},
		{ -- thin white ground ring, never fully opaque (HAND Shock ring: LE 0, Br 1, 0 -> 4.3 = 2.9R, start 0.4)
			id = "ring", kind = "emitter", t = 0.04, life = 0.05, at = { 0, 0.15, 0 },
			props = {
				Texture = "ShockRing", Color = "white", LightEmission = 0, Brightness = 1,
				Size = grow(EASE_OUT, R * 2.7), Transparency = { { 0, 0.4 }, { 1, 1 } }, Lifetime = { 0.17, 0.25 },
				Orientation = "VelocityPerpendicular", EmissionDirection = "Top", Speed = 0.0004,
				SpreadAngle = { 20, 20 }, Rotation = { 0, 360 },
			},
			emit = { { 0, 3 } },
		},
		------------------------------------------------------------------ arcs, crescents, smoke (0.05 - 1.3)
		{ -- flat arcs spinning 700-1500 deg/s (LB wind4: additive only, Size 4.5 -> 40, life 0.15-0.3, Speed 12-42)
			id = "arcs", kind = "emitter", t = 0.03, life = 0.05, at = { 0, R * 0.2, 0 },
			props = {
				Texture = "Arc", Color = { { 0, "body" }, { 1, "violet" } }, LightEmission = 1, Brightness = 5, -- v2: LB Br 5
				Size = { { 0, R * 0.35 }, { 1, R * 3.3 } },
				Transparency = { { 0, 1 }, { 0.07, 0 }, { 0.25, 0.42 }, { 0.57, 0.82 }, { 1, 1 } },
				Lifetime = { 0.15, 0.3 }, Speed = { R, R * 3.3 }, SpreadAngle = { 15, 15 },
				Orientation = "VelocityPerpendicular", EmissionDirection = "Top",
				Rotation = { 0, 360 }, RotSpeed = { 700, 1500 },
			},
			emit = { { 0, 10 } },
		},
		{ -- wind crescents spreading to 4R on the ground (LOS: LE 1, Br 3, 0 -> 10.6 @0.34 -> 21.3, life 0.2-1.2,
			-- RotSpeed 200, Drag 9, x7)
			id = "crescents", kind = "emitter", t = 0.05, life = 0.05, at = { 0, 0.3, 0 },
			props = {
				Texture = "Crescents", FlipbookLayout = 4, FlipbookMode = "OneShot", Color = "body", -- v2: was violet
				LightEmission = 1, Brightness = 4.5, -- v2: half step up from 3 (invisible in the first capture)
				Size = { { 0, 0 }, { 0.34, R * 2 }, { 1, R * 4 } }, Transparency = { { 0, 1 }, { 0.11, 0.42 }, { 1, 1 } },
				Lifetime = { 0.2, 1.2 }, Speed = { 0.001, 15 }, Drag = 9, SpreadAngle = { 25, 25 },
				Orientation = "VelocityPerpendicular", EmissionDirection = "Top",
				Rotation = { -360, 360 }, RotSpeed = { 200, 200 }, ZOffset = 0.5,
			},
			emit = { { 0, 6 } },
		},
		{ -- dark violet-black smoke, darkening with age (DEB clouds LE -0.25 at Br 14 with violet; TH smoke cools to
			-- #1D1F23). Low Br here so it stays the ink tone.
			id = "smoke", kind = "emitter", t = 0.08, life = 0.12, at = { 0, R * 0.3, 0 }, box = { R, R * 0.3, R },
			props = {
				Texture = "Clouds", FlipbookLayout = 4, FlipbookMode = "OneShot", Shape = "Box",
				Color = { { 0, "#2B3270" }, { 0.5, "inkBlue" }, { 1, "ink" } }, LightEmission = -0.25, Brightness = 1.5,
				Size = { { 0, R }, { 0.3, R * 1.7 }, { 1, R * 2.2 } },
				Transparency = { { 0, 1 }, { 0.25, 0.45 }, { 0.7, 0.6 }, { 1, 1 } }, Lifetime = { 0.6, 1.2 },
				Speed = { R, R * 3 }, Drag = 4, SpreadAngle = { 60, 60 }, Acceleration = { 0, 4, 0 },
				Rotation = { 0, 360 }, RotSpeed = { -40, 40 }, ZOffset = -1,
			},
			emit = { { 0, 8, 0.1 } },
		},
		------------------------------------------------------------------ second beat (0.5 - 0.9)
		{ -- small blue shard sparks as an aftershock (LOS Shards: EmitDelay 0.7, LE 0, Br 5, 0 -> 1.06 @0.55 -> 0,
			-- Speed 15-55, Drag 5, VelocityParallel, x20). 0.5 s here for a shorter move.
			id = "shards", kind = "emitter", t = 0.5, life = 0.05, at = { 0, R * 0.3, 0 }, box = { R, R * 0.3, R },
			props = {
				-- v2: Size 1.1 -> 1.6, Br 5 -> 8, x12 -> x18 (not visible in the first capture)
				Texture = "Shards", Color = "body", LightEmission = 0, Brightness = 8, Shape = "Box",
				Size = { { 0, 0 }, { 0.55, 1.6 }, { 1, 0 } }, Squash = 1, Transparency = 0, Lifetime = { 0.1, 0.4 },
				Speed = { 15, 55 }, Drag = 5, SpreadAngle = { 70, 70 }, Orientation = "VelocityParallel",
			},
			emit = { { 0, 18 } },
		},
		------------------------------------------------------------------ linger (to ~2.6)
		{ -- v2: glowing burn spot on the ground that cools white-blue -> deep blue over 1.6 s (TH cool-down by colour
			-- d.4; LOS `Glow` 12159555294 ground haze, life 3; size ~2.5R like TH's 54.9-stud ground discs at R 27 = 2R)
			id = "burnGlow", kind = "emitter", t = 0.05, life = 0.05, at = { 0, 0.12, 0 },
			props = {
				Texture = "Glow", Color = { { 0, "hot" }, { 0.25, "body" }, { 1, "deep" } }, LightEmission = 1,
				Brightness = 1.5, Size = { { 0, R * 1.5 }, { 0.2, R * 2.5 }, { 1, R * 2.8 } },
				Transparency = { { 0, 0.15 }, { 0.5, 0.45 }, { 1, 1 } }, Lifetime = 1.6,
				Orientation = "VelocityPerpendicular", EmissionDirection = "Top", Speed = 0.01, ZOffset = 0.2,
			},
			emit = { { 0, 1 } },
		},
		{ -- scorch on the ground fading over 2.5 s (TH crater: LE 0, Br 0, 37.5 = 1.4R, 4 s, #41464F -> black).
			-- The recapture shows TH's pure-dark crater vanishing on a dark floor: here it sits under the bigger burn glow,
			-- which gives it a lit rim (v2); on dark ground without the glow, drop it.
			id = "scorch", kind = "emitter", t = 0.05, life = 0.05, at = { 0, 0.08, 0 },
			props = {
				Texture = "Crater", Color = { { 0, "#41464F" }, { 1, "ink" } }, LightEmission = 0, Brightness = 0.5,
				Size = R * 1.4, Transparency = { { 0, 0 }, { 1, 1 } }, Lifetime = 2.5,
				Orientation = "VelocityPerpendicular", EmissionDirection = "Top", Speed = 0.01, Rotation = { 0, 360 },
			},
			emit = { { 0, 1 } },
		},
		{ -- glints that shoot out, stop dead and circle (LB Specs: off-centre dot, Rotation and RotSpeed +-360, Size
			-- 3.81 -> 0, life 1-3, Speed 1-250, Drag 20, LE 1, Br 7)
			id = "glints", kind = "emitter", t = 0.06, life = 0.05, at = { 0, R * 0.4, 0 },
			props = {
				-- v2: Size 1.2 -> 1.8 (LB 3.81 at R ~12 = 0.3R), Br 7 -> 10, life 1-2 s, x12 -> x18
				Texture = "OrbitDot", Color = "hot", LightEmission = 1, Brightness = 10,
				Size = { { 0, 1.8 }, { 1, 0 } }, Transparency = 0, Lifetime = { 1.0, 2.0 },
				Speed = { 1, R * 10 }, Drag = 20, SpreadAngle = { 180, 180 },
				Rotation = { -360, 360 }, RotSpeed = { -360, 360 }, ZOffset = 2,
			},
			emit = { { 0, 18 } },
		},
	},
}
