-- ClipForge base recipe "impact": from vfxmith (github.com/Frxctured/roblox-vfxmith), knowledge/categories/impact_recipe.luau,
-- MIT License, Copyright (c) 2026 Frxctured (see THIRD_PARTY_NOTICES). Texture ids are public Roblox images owned by
-- their uploaders; their terms apply. Recoloured, retimed and rescaled at play time by ClipForge's FX module.
-- GroundSlam: one generic impact / slam / ground hit for VFXTimeline (vfxmith spec format), distilled from
-- the 7 open-source impact effects studied in impact.md (same folder). UNTESTED DRAFT: no Studio capture yet.
-- Origin = the impact point ON the floor (y = 0 is the floor surface). The dome layers rely on the floor hiding the
-- lower half of a camera-facing sprite: with no floor they show as full circles.
-- Heights (impact.md d28, revised after the 2026-11-14 recapture): ground cards 0.05-0.2 studs up, swell ~0.2R up, core /
-- flash / sparks ~0.3R up (Yuji: +2.1 / +3.9 studs). Wukong keeps everything at y = 0 and loses its first beat on a floor.
-- Phases (s): flash 0-0.05 | stab + core 0-0.15 | flash swell 0-0.15 | dome 0.03-0.45 | rings 0.05-0.65 |
-- sparks 0-0.12 | orbs 0.1-1.2 | smoke 0.1-2 (dominant 0.2-0.8) | ground glow to 1 | scorch to 2.4.
-- Scale: R = 8 studs = half the main ground ring's final Size (16). Sizes copied from Wukong Slam1 (R ~12.3) are
-- x0.65; from kick barrage (R ~10) x0.8; from wallcombo (R ~5) x1.6. opts.scale resizes everything.
-- Three tones: white core (flash, stab, Br-clipped core), saturated body (core, dome, swell, sparks, orbs, glow),
-- black ink (flash ink, stab ink, swell ink, dome ink, ink smoke, scorch).
-- Sources: WK = Wukong Slam1 ea2342503619, YJ = Yuji FinalHitModel 53681671d73f (same kit as WK, recoloured),
-- WC = wallcombo ground1 f179743ad3c1, KB = kick barrage Slam d269c33f2a0a, BW = Black White h9 e937fd217dcc,
-- HK = hakari impactWU 8e7cd9fc76b3, VG = Vergil Ground2 aff199dac08d.
-- Lifetimes are REAL seconds: the sources run some emitters at TimeScale 0.6-0.9; VFXTimeline overwrites TimeScale
-- (slow motion), so those lifetimes were divided by the source TimeScale instead.
-- Recolour: change palette.body / bodyLight / glow (Yuji = #446FF9 / #529AF9 / #3D91F9); keep white and ink.
-- Out-of-range values copied on purpose (LightEmission -7 / -10, Transparency -50): if Studio refuses or they look
-- wrong after an engine update, use LightEmission 0 and Transparency 0.
-- Texture traits pass (2026-11-14, kit/scripts/texture_traits.py): Flash 18118762332 (420 px starburst with an
-- effective resolution of ~110 px: soft, stair-stepped spikes at Size 13) -> 17296456452 (radial spike burst, 1024 px,
-- eff 247); StarCross 17062416111 (an RGB-split chromatic cross: tinted "body" its fringes go muddy) -> 17062452122
-- (plain white short cross of the same Star series); SpikyRing 14538969234 (a 128 px image drawn at Size 14) ->
-- 7417145436 (the same ragged spiky ring at 420 px), shockRing Brightness 1 -> 0.5 because the new ring is white where
-- the old one was mid-grey (tone 0.49). Other layer values unchanged.

return {
	name = "GroundSlam",
	palette = {
		white = "#FFF6E6",
		body = "#FF622E", -- WK Fire42 / Bezier1 / sparks; Br 10-50 clips it to white in the bright texels
		bodyLight = "#FF9C55", -- WK dome
		swell = "#FF753E", -- WK R Impact
		glow = "#FF9334", -- WK Fading Glow
		ember = "#3A1606",
		smoke = "#616161", -- WK / KB Plume5
		ink = "#000000",
	},
	textures = {
		-- [..] at the end of a texture comment = measured traits (gallery/textures/traits.json, legend in kit/scripts/texture_traits.py)
		Flash = 17296456452, -- radial spike burst; was WC / YJ's 18118762332 (low-res)
		-- [clear, white, 1 part, eff 247, fill 32%]
		FlashInk = 79229618038296, -- YJ black twin under the flash [clear, multicolour, 1 part, eff 283, fill 53%]
		SpeedLines = 18465146997, -- BW / YJ stab cross [clear, white, 3 parts, eff 160, fill 25%]
		Fire42 = 16860398159, -- 8x8 fire burst (WK, YJ) [clear, grey, 1 part, eff 38 smooth, fill 8%, 31/64 cells]
		Bezier1 = 15423151910, -- 4x4 (WK, YJ) [clear, white, 1 part, eff 91, fill 1%, 15/16 cells]
		RImpact = 101995042384072, -- 4x4 flash swell (WK, YJ, HK) [clear, white, 2 parts, eff ~73, fill 9%, 8/16 cells]
		FixedCircle = 134557993252093, -- 4x4 disc -> ring (WK, HK)
		-- [clear, white, 1 part, eff ~70, fill 14%, 8/16 cells]
		SphereRim = 14457094589, -- Impact333 (WK, YJ): the dome [DARK haze, grey, 1 part, eff ~171, fill 42%]
		Ring = 18765326355, -- Impact145 (WK, YJ) [clear, white, 1 part, eff 58, fill 45%]
		SpikyRing = 7417145436, -- ragged spiky shock ring (Impact446); was KB's 14538969234 (128 px)
		-- [clear, white, 1 part, eff 72, fill 17%]
		Swirl = 127940423551603, -- 4x4 wind swirl (WK, YJ, BW) [clear, white, 3 parts, eff 75, fill 4%, 10/16 cells]
		StarCross = 17062452122, -- Star12 short white cross; was WK / YJ's Star3 chromatic cross 17062416111
		-- [clear, white, 1 part, eff 126, fill 2%]
		ShortImpact = 14379744080, -- 4x4 bolt flicks (WK, YJ) [clear, white, 1 part, eff 104, fill 6%, 6/16 cells]
		Spec = 11448304274, -- specs (WC, HK, YJ) [clear, white, 1 part, eff 40 smooth, fill 7%]
		Plume = 8527116276, -- Plume5 (WK, YJ, KB) [clear, white, 1 part, eff 84, fill 57%]
		Billow = 15415212938, -- 4x4 Billowing (WK, YJ, KB) [clear, grey, 1 part, eff 54, fill 50%]
		FadingGlow = 107821950776778, -- WK ground glow [FAINT, white, 1 part, eff 523, fill 40%]
		Crack = 17137667240, -- 4x4 crack (WK, KB) [clear, white, 4 parts, eff ~42 smooth, fill 25%, 15/16 cells]
	},
	layers = {
		------------------------------------------------------------------ flash (0 - 0.06)
		{ -- white impact frame, full size on frame 1, gone in 3 frames (WC n2 10 -> 8.25 at 26 % -> 0; YJ 16.4 -> 0)
			id = "flash", kind = "emitter", t = 0, life = 0.05, at = { 0, 2.5, 0 }, -- YJ Chonk +3.9 x0.65
			props = {
				Texture = "Flash", Color = "white", LightEmission = 0.5, Brightness = 6, LightInfluence = 0,
				Orientation = "FacingCamera", Speed = 0.002, Rotation = { -360, 360 }, ZOffset = 2,
				-- Size x0.7 (13 -> 9): the new flash texture fills 32 % of its card, the old one 22 % (checked in Studio)
				Size = { { 0, 9 }, { 0.26, 7.5 }, { 1, 0 } }, Transparency = 0, Lifetime = 0.05,
			},
			emit = { { 0, 1 } },
		},
		{ -- black twin behind the flash (YJ 79229618038296: Br0 = black whatever the Color, 1 -> 0 at 43 % -> 1)
			id = "flashInk", kind = "emitter", t = 0, life = 0.05, at = { 0, 2.5, 0 },
			props = {
				Texture = "FlashInk", Color = "ink", LightEmission = 0, Brightness = 0, LightInfluence = 0,
				Orientation = "FacingCamera", Speed = 0.001, Rotation = { -360, 360 }, ZOffset = 0,
				Size = { { 0, 15 }, { 1, 0 } }, Transparency = { { 0, 1 }, { 0.43, 0 }, { 1, 1 } }, Lifetime = 0.06,
			},
			emit = { { 0, 1 } },
		},
		------------------------------------------------------------------ stab cross (0 - 0.11)
		{ -- vertical stab line: speed-line band turned 90 deg along an upward velocity, Squash 3 (BW, YJ; 0.083 s at
			-- TimeScale 0.75 = 0.11 s). Check orientation in Studio: if it lies flat, set Rotation 0.
			id = "stabLight", kind = "emitter", t = 0, life = 0.05, at = { 0, 3, 0 },
			props = {
				Texture = "SpeedLines", Color = "white", LightEmission = 1, Brightness = 3, LightInfluence = 0,
				Orientation = "VelocityParallel", EmissionDirection = "Top", Speed = 0.001, Rotation = 90,
				Squash = 3, ZOffset = 0.1,
				Size = { { 0, 0 }, { 0.13, 9.5 }, { 1, 0 } }, Transparency = 0, Lifetime = 0.11,
			},
			emit = { { 0, 1 } },
		},
		{ -- its black twin 1.6x bigger, drawn behind (BW 14.7 vs 9.1, ZOffset -0.1 vs +0.1)
			id = "stabInk", kind = "emitter", t = 0, life = 0.05, at = { 0, 3, 0 },
			props = {
				Texture = "SpeedLines", Color = "ink", LightEmission = 0, Brightness = 0, LightInfluence = 0,
				Orientation = "VelocityParallel", EmissionDirection = "Top", Speed = 0.001, Rotation = 90,
				Squash = 3, ZOffset = -0.1,
				Size = { { 0, 0 }, { 0.17, 15 }, { 1, 0 } }, Transparency = 0, Lifetime = 0.11,
			},
			emit = { { 0, 1 } },
		},
		------------------------------------------------------------------ core (0 - 0.2)
		{ -- flat fire burst on the ground; Br10 on orange clips the bright texels to white = white core + orange rim
			-- (WK / YJ Fire42: 0 -> 10 at 0.1-0.2 s, x0.65)
			id = "core", kind = "emitter", t = 0, life = 0.05, at = { 0, 2.5, 0 }, -- YJ FirstMoveStart +3.9 x0.65
			props = {
				Texture = "Fire42", FlipbookLayout = 8, FlipbookMode = "OneShot", Color = "body",
				LightEmission = 0, Brightness = 10, LightInfluence = 0,
				Orientation = "VelocityPerpendicular", EmissionDirection = "Top", Speed = 0.1, Rotation = { -360, 360 },
				Size = { { 0, 0 }, { 0.11, 3.4 }, { 0.44, 5.7 }, { 1, 7 } },
				Transparency = { { 0, 0 }, { 0.7, 0 }, { 1, 1 } }, Lifetime = { 0.1, 0.2 },
			},
			emit = { { 0, 1 } },
		},
		{ -- white-hot flat flick, 1-frame fade-in, Br50 (WK / YJ Bezier1 x2, 0.05 s, ZOffset 0.2)
			id = "coreHot", kind = "emitter", t = 0, life = 0.05, at = { 0, 2.55, 0 },
			props = {
				Texture = "Bezier1", FlipbookLayout = 4, FlipbookMode = "OneShot", Color = "body",
				LightEmission = 0, Brightness = 50, LightInfluence = 0,
				Orientation = "VelocityPerpendicular", EmissionDirection = "Top", Speed = { 0.06, 0.13 }, Drag = 5,
				Rotation = { -360, 360 }, ZOffset = 0.2,
				Size = 4, Transparency = { { 0, 1 }, { 0.11, 0 }, { 0.7, 0 }, { 1, 1 } }, Lifetime = 0.05,
			},
			emit = { { 0, 2 } },
		},
		------------------------------------------------------------------ flash swell (0 - 0.15)
		{ -- big additive swell to ~3.6R in 0.15 s (WK R Impact 0 -> 45 in 0.09 s at TimeScale 0.6, x0.65)
			id = "flashSwell", kind = "emitter", t = 0, life = 0.05, at = { 0, 1.4, 0 }, -- YJ NormalHit +2.1 x0.65
			props = {
				Texture = "RImpact", FlipbookLayout = 4, FlipbookMode = "OneShot", Color = "swell",
				LightEmission = 1, Brightness = 5, LightInfluence = 0,
				Orientation = "FacingCamera", Speed = 0.015, Rotation = { -360, 360 },
				Size = { { 0, 0 }, { 0.3, 15 }, { 0.5, 22 }, { 0.77, 27.7 }, { 1, 29 } }, Transparency = 0,
				Lifetime = 0.15,
			},
			emit = { { 0, 1 } },
		},
		{ -- black disc -> ring behind the burst, read as the dark halo at 0.03 s (WK Fixed circle, black, LE0.9 Br10,
			-- 0 -> 28.5 in 0.08 s, x0.65)
			id = "swellInk", kind = "emitter", t = 0, life = 0.05, at = { 0, 1.4, 0 },
			props = {
				Texture = "FixedCircle", FlipbookLayout = 4, FlipbookMode = "OneShot", Color = "ink",
				LightEmission = 0.9, Brightness = 10, LightInfluence = 0,
				Orientation = "FacingCamera", Speed = 0.004, Rotation = { -360, 360 }, ZOffset = -0.5,
				Size = { { 0, 0 }, { 0.1, 5.1 }, { 0.2, 9.1 }, { 0.3, 12.2 }, { 0.5, 16.2 }, { 0.7, 18 }, { 1, 18.5 } },
				Transparency = 0, Lifetime = 0.08,
			},
			emit = { { 0, 1 } },
		},
		------------------------------------------------------------------ dome (0 - 0.45)
		{ -- black dome backing, 1.55x the dome (WK black Impact333 0 -> 22, 0.2 s at TimeScale 0.9, x0.65)
			id = "domeInk", kind = "emitter", t = 0, life = 0.05, at = { 0, 0, 0 },
			props = {
				Texture = "SphereRim", Color = "ink", LightEmission = 0, Brightness = 35, LightInfluence = 0,
				Orientation = "FacingCamera", Speed = 0.002, Rotation = { -360, 360 }, ZOffset = 0.5,
				Size = { { 0, 0 }, { 0.1, 3.3 }, { 0.24, 6.9 }, { 0.4, 9.4 }, { 0.6, 11.7 }, { 0.82, 13.3 }, { 1, 14.3 } },
				Transparency = { { 0, 0 }, { 0.09, 0.41 }, { 0.17, 0.62 }, { 0.24, 0.75 }, { 0.32, 0.85 }, { 0.6, 0.93 }, { 1, 1 } },
				Lifetime = 0.22,
			},
			emit = { { 0, 1 } },
		},
		{ -- the dome: camera-facing sphere rim emitted at floor level, floor hides the lower half (WK; YJ raises it
			-- 2.1 studs for a bit more than a hemisphere)
			-- (WK Impact333 orange LE0 Br35 0 -> 14.1, 0.4 s at TimeScale 0.9, ZOffset 0.75, x0.65; WC shock is the same idea)
			id = "dome", kind = "emitter", t = 0, life = 0.05, at = { 0, 0, 0 },
			props = {
				Texture = "SphereRim", Color = "bodyLight", LightEmission = 0, Brightness = 35, LightInfluence = 0,
				Orientation = "FacingCamera", Speed = 0.002, Rotation = { -360, 360 }, ZOffset = 0.75,
				Size = { { 0, 0 }, { 0.1, 2.1 }, { 0.24, 4.5 }, { 0.4, 6.1 }, { 0.6, 7.5 }, { 0.82, 8.6 }, { 1, 9.2 } },
				Transparency = { { 0, 0 }, { 0.09, 0.41 }, { 0.17, 0.62 }, { 0.24, 0.75 }, { 0.32, 0.85 }, { 0.6, 0.93 }, { 1, 1 } },
				Lifetime = 0.45,
			},
			emit = { { 0, 1 } },
		},
		------------------------------------------------------------------ ground rings (0 - 1)
		{ -- main flat ring, 2R; ease-out (33 % of final at 10 % life). WK Impact145 0 -> 24.6, 0.4-0.6 s at TimeScale 0.9,
			-- x0.65. WK starts at Transparency 0.765 and never reads (impact.md e): started at 0.45 here (unverified).
			id = "groundRing", kind = "emitter", t = 0, life = 0.05, at = { 0, 0.1, 0 },
			props = {
				Texture = "Ring", Color = "white", LightEmission = 0.45, Brightness = 1, LightInfluence = 0,
				Orientation = "VelocityPerpendicular", EmissionDirection = "Top", Speed = 0.001, Rotation = { -360, 360 },
				Size = { { 0, 0 }, { 0.1, 5.3 }, { 0.2, 7.9 }, { 0.31, 9.9 }, { 0.44, 11.2 }, { 0.56, 12.4 }, { 0.82, 14.6 }, { 1, 16 } },
				Transparency = { { 0, 0.45 }, { 0.16, 0.65 }, { 0.34, 0.85 }, { 0.5, 0.94 }, { 0.7, 1 }, { 1, 1 } },
				Lifetime = { 0.45, 0.65 },
			},
			emit = { { 0, 3 } },
		},
		{ -- spiky shock ring, punchier: 48 % of final at 10 % life, 0.67 transparent by then (KB 14538969234, 0 -> 21, x0.67)
			id = "shockRing", kind = "emitter", t = 0, life = 0.05, at = { 0, 0.12, 0 },
			props = {
				Texture = "SpikyRing", Color = "white", LightEmission = 0, Brightness = 0.5, LightInfluence = 0,
				Orientation = "VelocityPerpendicular", EmissionDirection = "Top", Speed = 0.014, Rotation = { 0, 360 },
				Size = { { 0, 0 }, { 0.1, 6.7 }, { 0.2, 8.9 }, { 0.3, 10.4 }, { 0.4, 11.4 }, { 0.5, 12.25 }, { 0.7, 13.3 }, { 1, 14 } },
				Transparency = { { 0, 0 }, { 0.1, 0.67 }, { 0.2, 0.85 }, { 0.3, 0.92 }, { 0.5, 0.98 }, { 1, 1 } },
				Lifetime = { 0.5, 0.9 },
			},
			emit = { { 0, 2 } },
		},
		{ -- faint spinning wind swirls, 1.6R (WK 127940423551603 x5: LE0.25, T 0.75, 0 -> 19.6, 0.2-0.4 s at TimeScale 0.75)
			id = "windSwirl", kind = "emitter", t = 0, life = 0.05, at = { 0, 0.3, 0 },
			props = {
				Texture = "Swirl", FlipbookLayout = 4, FlipbookMode = "OneShot", Color = "white",
				LightEmission = 0.25, Brightness = 1, LightInfluence = 0,
				Orientation = "VelocityPerpendicular", EmissionDirection = "Top", Speed = { 1.2, 2.3 },
				Rotation = { -360, 360 }, RotSpeed = { -150, 150 },
				Size = { { 0, 0 }, { 0.1, 3.5 }, { 0.2, 6.2 }, { 0.3, 8.4 }, { 0.4, 9.9 }, { 0.5, 11 }, { 0.7, 12.3 }, { 1, 12.7 } },
				Transparency = { { 0, 0.75 }, { 0.3, 0.86 }, { 0.6, 0.95 }, { 1, 1 } }, Lifetime = { 0.27, 0.53 },
			},
			emit = { { 0, 5 } },
		},
		------------------------------------------------------------------ sparks (0 - 0.12) and orbs (0.1 - 1.2)
		{ -- chromatic cross sparks that flicker twice inside 0.07-0.12 s; distance ~ Speed / Drag = up to ~7.5 studs
			-- (WK / YJ Star3: Speed 1-354, Drag 30.5, LE0 Br25, 6-key flicker curve, x0.65)
			id = "starSparks", kind = "emitter", t = 0, life = 0.05, at = { 0, 2.5, 0 },
			props = {
				Texture = "StarCross", Color = "body", LightEmission = 0, Brightness = 25, LightInfluence = 0,
				Orientation = "FacingCamera", Speed = { 1, 230 }, Drag = 30, SpreadAngle = 360, Rotation = 0,
				Size = { { 0, 0 }, { 0.16, 0.27 }, { 0.2, 7.7 }, { 0.3, 1.2 }, { 0.49, 0 }, { 0.74, 2.6 }, { 1, 0 } },
				Transparency = 0, Lifetime = { 0.066, 0.118 },
			},
			emit = { { 0, 3 } },
		},
		{ -- fast bolt flicks streaking out, negative LE = solid, no halo (WK / YJ Shorter impact: Speed 118-236, Drag 5,
			-- LE -10 Br10, 0.1 s). Sources use Spread 360 from below; here Top + 70 so none are lost under the floor.
			id = "streaks", kind = "emitter", t = 0, life = 0.05, at = { 0, 2.5, 0 },
			props = {
				Texture = "ShortImpact", FlipbookLayout = 4, FlipbookMode = "OneShot", Color = "body",
				LightEmission = -10, Brightness = 10, LightInfluence = 0,
				Orientation = "VelocityParallel", EmissionDirection = "Top", Speed = { 77, 153 }, Drag = 5,
				SpreadAngle = 70, Rotation = 0,
				Size = 3.8, Transparency = 0, Lifetime = 0.1,
			},
			emit = { { 0, 4 } },
		},
		{ -- hard little orbs leaving from the outer half of a disc, spinning, slowing to a stop (~12 studs max)
			-- (WC / HK / YJ specs 11448304274: Disc ShapePartial 0.5, Speed 6-127, Drag 8.64, RotSpeed +-500,
			-- LE -7 Br20, Transparency -50 = hard edge, Size 0 -> peak at 16 % -> 0, 0.5-1.5 s)
			id = "orbs", kind = "emitter", t = 0, life = 0.05, at = { 0, 0.4, 0 }, box = { 5, 0.2, 5 },
			props = {
				Texture = "Spec", Color = "bodyLight", LightEmission = -7, Brightness = 20, LightInfluence = 0,
				Shape = "Disc", ShapePartial = 0.5, EmissionDirection = "Top",
				Orientation = "VelocityParallel", Speed = { 6, 100 }, Drag = 8.6, SpreadAngle = 360, Rotation = 90,
				RotSpeed = { -500, 500 }, ZOffset = 2,
				Size = { { 0, 0 }, { 0.16, 0.8 }, { 1, 0 } }, Transparency = -50, Lifetime = { 0.5, 1.2 },
			},
			emit = { { 0, 12 } },
		},
		------------------------------------------------------------------ smoke (0.1 - 2)
		{ -- grey plumes that stretch upward as they grow (FacingCameraWorldUp + Squash 0 -> 1.79), half-fan up
			-- (WK / KB Plume5: #616161 LE0 LI0.75 Br15, Speed 1-100, Drag 7, Spread (0, 180), 1-2 s, x0.65).
			-- Emitted 0.8 studs up and with Acceleration -6 (WK's mildest copy, -9.44) instead of -29: the sources'
			-- falling cards cut hard lines into the floor.
			id = "plume", kind = "emitter", t = 0, life = 0.05, at = { 0, 0.8, 0 },
			props = {
				Texture = "Plume", Color = "smoke", LightEmission = 0, Brightness = 15, LightInfluence = 0.75,
				Orientation = "FacingCameraWorldUp", EmissionDirection = "Top", Speed = { 1, 65 }, Drag = 7,
				SpreadAngle = { 0, 180 }, Acceleration = { 0, -6, 0 }, Rotation = 0, ZOffset = 0.2,
				Size = { { 0, 0 }, { 0.09, 2.5 }, { 0.22, 4.5 }, { 0.37, 6 }, { 0.54, 7.4 }, { 0.76, 8.5 }, { 1, 9.4 } },
				Squash = { { 0, 0 }, { 1, 1.79 } },
				Transparency = { { 0, 0 }, { 0.1, 0.45 }, { 0.2, 0.69 }, { 0.3, 0.8 }, { 0.4, 0.88 }, { 0.5, 0.92 }, { 0.7, 0.955 }, { 1, 1 } },
				Lifetime = { 1, 2 },
			},
			emit = { { 0, 5 } },
		},
		{ -- black billow inside the grey: the smoke's ink tone (WK Billowing black LE0.75 Br1.15, 1-2 s at TimeScale 0.85)
			id = "inkSmoke", kind = "emitter", t = 0, life = 0.05, at = { 0, 0.8, 0 },
			props = {
				Texture = "Billow", FlipbookLayout = 4, FlipbookMode = "OneShot", Color = "ink",
				LightEmission = 0.75, Brightness = 1.15, LightInfluence = 0,
				Orientation = "FacingCameraWorldUp", EmissionDirection = "Top", Speed = { 1, 65 }, Drag = 7,
				SpreadAngle = { 0, 180 }, Acceleration = { 0, -6, 0 }, Rotation = { -360, 360 }, ZOffset = 0.2,
				Size = { { 0, 0 }, { 0.1, 3.2 }, { 0.2, 4.1 }, { 0.3, 4.7 }, { 0.5, 5.4 }, { 0.7, 5.7 }, { 1, 5.9 } },
				Transparency = { { 0, 0 }, { 0.095, 0.53 }, { 0.2, 0.74 }, { 0.32, 0.84 }, { 0.5, 0.92 }, { 0.7, 0.97 }, { 0.9, 1 }, { 1, 1 } },
				Lifetime = { 1.2, 2.4 },
			},
			emit = { { 0, 3 } },
		},
		------------------------------------------------------------------ ground marks (0 - 2.4)
		{ -- additive ground glow that cools: colour ramps to a dark ember at ~65 % of life (WK Fading Glow 15 studs,
			-- LE1 Br1, 1 s; ramp from WK Faint Wispy Energy: orange to 0.6, black at 0.69)
			id = "groundGlow", kind = "emitter", t = 0, life = 0.05, at = { 0, 0.1, 0 },
			props = {
				Texture = "FadingGlow", LightEmission = 1, Brightness = 1, LightInfluence = 0, LockedToPart = true,
				Color = { { 0, "glow" }, { 0.6, "glow" }, { 0.69, "ember" }, { 1, "ink" } },
				Orientation = "VelocityPerpendicular", EmissionDirection = "Top", Speed = 0.001, Rotation = { -360, 360 },
				Size = 10, Transparency = { { 0, 0 }, { 0.5, 0.3 }, { 0.76, 0.63 }, { 1, 1 } }, Lifetime = 1,
			},
			emit = { { 0, 1 } },
		},
		{ -- scorch cracks: Brightness 0 makes the crack sheet black whatever the colour; LE 0.5 softens it
			-- (WK crack1 8 studs 2.4 s; KB 23.7 studs 7 s -> 1.25R and 2.4 s here)
			id = "scorch", kind = "emitter", t = 0, life = 0.05, at = { 0, 0.08, 0 },
			props = {
				Texture = "Crack", FlipbookLayout = 4, FlipbookMode = "OneShot", Color = "white",
				LightEmission = 0.5, Brightness = 0, LightInfluence = 0,
				Orientation = "VelocityPerpendicular", EmissionDirection = "Top", Speed = 0.0002, Rotation = { -360, 360 },
				Size = 10,
				Transparency = { { 0, 0 }, { 0.1, 0.415 }, { 0.2, 0.563 }, { 0.3, 0.666 }, { 0.4, 0.746 }, { 0.5, 0.811 },
					{ 0.6, 0.864 }, { 0.7, 0.909 }, { 0.8, 0.946 }, { 0.9, 0.977 }, { 1, 1 } },
				Lifetime = 2.4,
			},
			emit = { { 0, 1 } },
		},
	},
}
