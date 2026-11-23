-- ClipForge base recipe "projectile": from vfxmith (github.com/Frxctured/roblox-vfxmith), knowledge/categories/projectile_recipe.luau,
-- MIT License, Copyright (c) 2026 Frxctured (see THIRD_PARTY_NOTICES). Texture ids are public Roblox images owned by
-- their uploaders; their terms apply. Recoloured, retimed and rescaled at play time by ClipForge's FX module.
-- ProjectileOrb: one generic fired orb (launch -> travel -> impact) as a VFXTimeline spec.
-- Built from the projectile / orb study (projectile.md, same folder): every value comes from its anatomy table, every
-- texture id from the seven studied effects' layer tables. Draft: capture it with the pipeline before use.
--
-- v2 (one tuning pass after the first Studio capture; half steps, grounded in the tables):
--   the v1 orb was a dot in a 32-stud frame, the launch flash peaked for <1 frame, the trail was a hairline, the impact
--   read as one opaque orange dome (half under the floor) that hid the sparks and ring behind it, and the ink layers
--   (black wake, dark back disc) were invisible against the dark stage. Changes:
--   flight raised to y = 3 (chest height, as Event Ball's ball / Yoru's hit point) so the impact is not cut by the floor;
--   core D 2.5 -> 3.75 (+50 %) plus a soft glow halo 2.4 D (random orb glare role); hot trail width 1 -> 2.4 and a
--   second, longer body trail (Christmas trail stack); launch flash x1.5 with a longer peak, sparks 4 -> 8;
--   impact sparks/shards/ring moved in front of the opaque disc (z 6), counts up by half steps, a soft impact glow
--   backdrop (Event Ball Dots role) replaces the Blurred Flare halo so the ink star and dark smoke have light behind them;
--   wakeInk and coreBack removed (black on a dark stage showed nothing).
--
-- Phases (seconds): launch flash 0-0.25 | travel 0-0.4 (32 studs along +X at y = 3 = 80 studs/s) | contact C = 0.4 |
-- flash C+0.02 (0.1 s) | overexposed disc + ink star C+0.02 to C+0.32 | impact glow C+0.02 to C+0.67 | toon pop C+0.2
-- (0.4 s, the handoff as the disc collapses) | sparks to C+0.5 | rings to C+0.45 | smoke lingers to ~C+1.3.
-- Scale: core sprite D = 3.75 studs (glow 9); flash peak 15 (4 D); disc 10-13.6; impact glow 18; toon pop 5.3-11;
-- muzzle 7.
-- Tones: white (hot core, flash), saturated body (orange), dark ink (ink star, dark sparks, smoke over the glow).
-- Unverified engine behaviour used here (check in Studio): negative LightEmission (coreBody, sparkLit), how the
-- untested textures 17062452367 / 14483718869 look (no thumbnails were available).
-- Orientation: in the pipeline's capture rig the camera sits on -Z looking +Z, so +X (the flight) runs to screen LEFT.
-- [..] after a Texture id = measured traits (gallery/textures/traits.json, legend in kit/scripts/texture_traits.py).
-- Seen 2026-11-14 (thumbnail / original): 17062452367 = a black 4-point star inside a soft white glow rim; 14483718869
-- = 8x8 frames of a white ball with swirling dark streaks (a rolling orb), 61 of 64 cells used.

local Y = 3 -- flight height (studs)
local HIT = { 32, Y, 0 } -- contact point (layer space, studs)

local function flight() -- the core's path as an Offset from `at`: 0 -> 32 studs along +X in 0.4 s, linear
	return { { 0, { 0, 0, 0 } }, { 0.4, { 32, 0, 0 }, "linear" } }
end

return {
	name = "ProjectileOrb",
	scale = 1,
	palette = {
		white = "#FFF6E8",
		hot = "#FFD27A",
		body = "#FF6A1C", -- saturated body hue; swap for the element
		deep = "#5A1A06",
		shadow = "#2A0C04", -- deep version of the body hue (random orb used #100E38 for blue)
		ink = "#000000",
	},
	layers = {
		------------------------------------------------------------------ launch (0 - 0.3)
		{ -- muzzle flash, flattened sideways. v2: x1.5 size (0.47x the impact flash, inside the 0.3-0.6x band) and the
			-- peak held to 12 % of a 0.25 s life (v1: 1-2 frames, missed). [Artemis Weapons/Rain Flare20New]
			id = "launchFlash", kind = "emitter", t = 0, life = 0.05, at = { 0.5, Y, 0 },
			props = {
				Texture = 70728001087698, Color = "hot", LightEmission = 1, Brightness = 5, -- [BLACK card, multicolour, 1 part, eff ~87, fill 56%]
				Size = { { 0, 0 }, { 0.12, 3.9 }, { 0.3, 6.9 }, { 1, 7.1 } },
				Transparency = { { 0, 0.94 }, { 0.03, 0 }, { 0.12, 0.5 }, { 1, 1 } },
				Squash = { { 0, 0 }, { 1, -0.38 } },
				Lifetime = 0.25, Speed = 0, ZOffset = 4,
			},
			emit = { { 0, 1 } },
		},
		{ -- forward spark spray that stops on Drag and droops. v2: 4 -> 8 (bow kit fires 12 sparks in 4 layers), size
			-- 0.69 -> 1.0 (the x1.38 Rain copy uses 0.95). [Artemis Weapons Flare247New]
			id = "launchSparks", kind = "emitter", t = 0, life = 0.05, at = { 0.5, Y, 0 },
			props = {
				Texture = 13161986324, Color = { { 0, "white" }, { 1, "hot" } }, LightEmission = 1, Brightness = 2.8, -- [DARK haze, grey, 1 part, eff 45 smooth, fill 31%]
				Size = { { 0, 1.0, 0.5 }, { 1, 0 } }, Transparency = 0,
				Lifetime = { 0.2, 0.3 }, Speed = 25, Drag = 8.5, SpreadAngle = { 100, 100 }, EmissionDirection = "Right",
				Acceleration = { 0, -10, 0 }, ZOffset = 4,
			},
			emit = { { 0, 8 } },
		},
		------------------------------------------------------------------ travelling core (0 - 0.4)
		{ -- NEW v2: soft glow halo round the core, 2.4 D, so the orb reads at distance. [random orb glare role (1.5-2.5 D,
			-- LE 1, Br 1, Transparency ~0.66); texture: Artemis Fading Glow]
			id = "coreGlow", kind = "emitter", t = 0, life = 0.4, at = { 0, Y, 0 },
			props = {
				Texture = 107821950776778, Color = "body", LightEmission = 1, Brightness = 1, -- [FAINT, white, 1 part, eff 523, fill 40%]
				Size = 9, Transparency = 0.55, Lifetime = 0.42, Speed = 0, LockedToPart = true, ZOffset = 1,
			},
			tracks = { Offset = flight() },
			emit = { { 0, 1 } },
		},
		{ -- body: constant-size 8x8 orb flipbook, solid saturated colour (LE -1 as in the source; use 0 if it reads
			-- black). v2: 2.5 -> 3.75 studs. [Event Ball Enabled/Ball2]
			id = "coreBody", kind = "emitter", t = 0, life = 0.4, at = { 0, Y, 0 },
			props = {
				Texture = 14483718869, FlipbookLayout = 8, FlipbookMode = "OneShot", -- [clear, white, 1 part, eff ~29 smooth, fill 57%, 61/64 cells]
				Color = "body", LightEmission = -1, Brightness = 6,
				Size = 3.75, Transparency = 0, Lifetime = 0.42, Speed = 0,
				Rotation = { 90, 150 }, LockedToPart = true, ZOffset = 5,
			},
			tracks = { Offset = flight() },
			emit = { { 0, 1 } },
		},
		{ -- white-hot centre (0.44 D). v2: 1.1 -> 1.6. [Yoru impact texture / Shards2 role: hard orb core]
			id = "coreHot", kind = "emitter", t = 0, life = 0.4, at = { 0, Y, 0 },
			props = {
				Texture = 15153511168, Color = "white", LightEmission = 1, Brightness = 3, -- [FAINT, white, 1 part, eff 76, fill 47%]
				Size = 1.6, Transparency = 0, Lifetime = 0.42, Speed = 0, LockedToPart = true, ZOffset = 6,
			},
			tracks = { Offset = flight() },
			emit = { { 0, 1 } },
		},
		{ -- anamorphic lens line through the core: a star squashed flat (Squash -2.85). v2: 3.5 -> 5 (1.4 D).
			-- [random orb star]
			id = "coreFlare", kind = "emitter", t = 0, life = 0.4, at = { 0, Y, 0 },
			props = {
				Texture = 14590086212, Color = "hot", LightEmission = 1, Brightness = 3, -- [FAINT, white, 1 part, eff 354, fill 14%]
				Size = 5, Squash = { { 0, -2.85 }, { 1, -2.85 } }, Transparency = 0.34,
				Lifetime = 0.42, Speed = 0, LockedToPart = true, ZOffset = 6,
			},
			tracks = { Offset = flight() },
			emit = { { 0, 1 } },
		},
		{ -- hot streak trail: tail lags 0.15 s (12 studs at 80 studs/s), then catches up and closes. v2: head width
			-- 1.0 -> 2.4 (half way to 1 D; Christmas trails are 1 D wide). [Christmas `middle` role, Event Trail2 texture]
			id = "trail", kind = "beam", t = 0, life = 0.55, a = { 0, Y, 0 }, b = { 0, Y, 0 },
			props = {
				Width0 = 2.4, Width1 = 0, Texture = 12781750620, TextureMode = "Stretch", -- [clear, white, 1 part, eff 33 smooth, fill 44%]
				Color = { { 0, "hot" }, { 1, "body" } }, LightEmission = 1, Brightness = 5,
				Transparency = { { 0, 0 }, { 0.6, 0.35 }, { 1, 1 } },
			},
			tracks = {
				A = { { 0, { 0, 0, 0 } }, { 0.4, { 32, 0, 0 }, "linear" } },
				B = { { 0, { 0, 0, 0 } }, { 0.15, { 0, 0, 0 } }, { 0.55, { 32, 0, 0 }, "linear" } },
			},
		},
		{ -- NEW v2: longer, wider, dimmer body trail under the hot one: lags 0.3 s (24 studs, inside the 12-30 band).
			-- [Christmas `middle2` (LE 1, life 0.5) and `dark` (colour to near-black) trail stack]
			id = "trailBody", kind = "beam", t = 0, life = 0.7, a = { 0, Y, 0 }, b = { 0, Y, 0 },
			props = {
				Width0 = 3.2, Width1 = 0, Texture = 126171454491178, TextureMode = "Stretch", -- [clear, grey, 1 part, eff ~302, fill 14%]
				Color = { { 0, "body" }, { 1, "deep" } }, LightEmission = 1, Brightness = 2,
				Transparency = { { 0, 0.2 }, { 0.5, 0.45 }, { 1, 1 } },
			},
			tracks = {
				A = { { 0, { 0, 0, 0 } }, { 0.4, { 32, 0, 0 }, "linear" } },
				B = { { 0, { 0, 0, 0 } }, { 0.3, { 0, 0, 0 } }, { 0.7, { 32, 0, 0 }, "linear" } },
			},
		},
		{ -- wake: off-centre specks that orbit while they drift up, left behind along the path. v2: 30 -> 45, size
			-- 0.4 -> 0.7 (Don's 0.25-0.4 on ~1.5-stud limbs = ~0.2 D). [Don Lorenzo OffCentered Spec 46]
			id = "wake", kind = "emitter", t = 0, life = 0.4, at = { 0, Y, 0 },
			props = {
				Texture = 16171528032, Color = "body", LightEmission = 0, Brightness = 25, -- [clear, white, 1 part, eff 57, fill 3%]
				Size = { { 0, 0.7 }, { 1, 0 } }, Transparency = { { 0, 1 }, { 0.5, 0 }, { 1, 1 } },
				Lifetime = { 0.4, 0.7 }, Speed = { 4, 8 }, Drag = 7, SpreadAngle = { 360, 360 },
				Rotation = { -360, 360 }, RotSpeed = { -250, 250 }, Acceleration = { 0, 1, 0 },
				LockedToPart = false, ZOffset = -1.2,
			},
			tracks = { Offset = flight() },
			emit = { { 0, 45, 0.4 } },
		},
		------------------------------------------------------------------ impact (C = 0.4)
		{ -- white flash one frame after contact: swell to 4 D at 15 % of 0.1 s. [Christmas `center`]
			id = "impactFlash", kind = "emitter", t = 0.42, life = 0.05, at = HIT,
			props = {
				Texture = 15888463683, Color = "white", LightEmission = 1, Brightness = 5, -- [clear, white, 1 part, eff ~140, fill 5%]
				Size = { { 0, 0 }, { 0.15, 15 }, { 0.39, 13 }, { 1, 0 } }, Transparency = 0,
				Lifetime = 0.1, Speed = 0, Rotation = { -360, 360 }, ZOffset = 6,
			},
			emit = { { 0, 1 } },
		},
		{ -- NEW v2 (replaces the Blurred Flare halo): soft impact glow backdrop, fades in 0.18 s, holds, out by 0.65 s,
			-- so the ink star and the dark smoke have light behind them and the hit lingers. Additive here (LE 1, Br 1.5)
			-- instead of the source's LE 0 / Br 16, so it does not become a second opaque dome. [Event Ball Explode/Dots]
			id = "impactGlow", kind = "emitter", t = 0.42, life = 0.05, at = HIT,
			props = {
				Texture = 107821950776778, Color = "hot", LightEmission = 1, Brightness = 1.5, -- [FAINT, white, 1 part, eff 523, fill 40%]
				Size = 18, Transparency = { { 0, 0.98 }, { 0.12, 0.64 }, { 0.28, 0.05 }, { 0.6, 0 }, { 0.8, 0.5 }, { 1, 1 } },
				Lifetime = 0.65, Speed = 0, ZOffset = 0,
			},
			emit = { { 0, 1 } },
		},
		{ -- overexposed disc: saturated orange at LE 0 / Br 4 renders pale yellow with an orange edge; grows, holds,
			-- then COLLAPSES in its last 15 % (no fade). [Event Ball Explode/Circle, sizes x0.13]
			id = "impactDisc", kind = "emitter", t = 0.42, life = 0.05, at = HIT,
			props = {
				Texture = 107251295851688, Color = "body", LightEmission = 0, Brightness = 4, -- [clear, white, 1 part, eff 53, fill 32%]
				Size = { { 0, 10 }, { 0.22, 13 }, { 0.85, 13.6 }, { 1, 4.5 } }, Transparency = 0,
				Lifetime = 0.24, Speed = 0, ZOffset = 5,
			},
			emit = { { 0, 1 } },
		},
		{ -- black 4-point star in front of the disc (z 7): the silhouette beat. Colour forced to ink so it is dark
			-- whatever the texture art (the source, #FF8A47 Br 5, renders black to dark bronze). [Event Ball Explode/Star]
			id = "inkStar", kind = "emitter", t = 0.42, life = 0.05, at = HIT,
			props = {
				Texture = 17062452367, Color = "ink", LightEmission = 0, Brightness = 5, -- [clear, grey, 1 part, eff 348, fill 24%]
				Size = { { 0, 1.3 }, { 0.11, 5.2 }, { 0.73, 8 }, { 1, 4 } }, Transparency = 0,
				Lifetime = 0.3, Speed = 0, Rotation = { -90, 90 }, ZOffset = 7,
			},
			emit = { { 0, 1 } },
		},
		{ -- toon smack flipbook takes over as the disc collapses (handoff at C + 0.2). [Event Ball Explode/Impact2]
			id = "toonPop", kind = "emitter", t = 0.6, life = 0.05, at = HIT,
			props = {
				Texture = 18140248952, FlipbookLayout = 4, FlipbookMode = "OneShot", -- [clear, white, 2 parts, eff ~67, fill 11%, 7/16 cells]
				Color = { { 0, "hot" }, { 1, "body" } }, LightEmission = 0, Brightness = 12,
				Size = { { 0, 5.3 }, { 0.3, 8.6 }, { 1, 11 } }, Transparency = 0,
				Lifetime = 0.4, Speed = 0, Rotation = { -360, 360 }, ZOffset = 6,
			},
			emit = { { 0, 1 } },
		},
		{ -- two thick-to-hairline ring flipbooks, each flat in a random plane (VelocityPerpendicular + tiny Speed +
			-- SpreadAngle 360), spinning. v2: z 1 -> 6 (the opaque disc hid it), Br 2 -> 3, end size 10 -> 13 (Christmas
			-- rings end at ~0.8x the flash). [Event Ball Circle flipbook; recipe from Yoru/Artemis flat rings]
			id = "ring", kind = "emitter", t = 0.44, life = 0.05, at = HIT,
			props = {
				Texture = 126034245450101, FlipbookLayout = 4, FlipbookMode = "OneShot", -- [clear, white, 1 part, eff ~69, fill 15%, 12/16 cells]
				Color = { { 0, "white" }, { 1, "hot" } }, LightEmission = 1, Brightness = 3,
				Orientation = "VelocityPerpendicular", Speed = 0.005, SpreadAngle = { 360, 360 },
				Size = { { 0, 4 }, { 1, 13 } }, Transparency = { { 0, 0 }, { 0.7, 0.3 }, { 1, 1 } },
				Lifetime = 0.4, Rotation = { 0, 360 }, RotSpeed = { -150, 150 }, ZOffset = 6,
			},
			emit = { { 0, 2 } },
		},
		{ -- stop-dead streak shards: fast, Drag 30, squash-stretched along velocity, gone in ~0.2 s. v2: 12 -> 15 (the
			-- source count), z 1.5 -> 6 (in front of the disc). [Christmas shinyShard2]
			id = "shards", kind = "emitter", t = 0.42, life = 0.05, at = HIT,
			props = {
				Texture = 14271209798, FlipbookLayout = 4, FlipbookMode = "OneShot", -- [clear, white, 1 part, eff 57, fill 7%]
				Color = { { 0, "white" }, { 1, "hot" } }, LightEmission = 0, Brightness = 10,
				Orientation = "VelocityParallel", Squash = { { 0, 0 }, { 1, 3 } },
				Size = { { 0, 0 }, { 0.31, 2.2 }, { 0.77, 1.1 }, { 1, 0 } }, Transparency = 0,
				Lifetime = { 0.1, 0.21 }, Speed = { 40, 120 }, Drag = 30, SpreadAngle = { 360, 360 }, ZOffset = 6,
			},
			emit = { { 0, 15 } },
		},
		{ -- two-tone sparks, half 1: the DARK copy of the same spark (same texture and motion). v2: 5 -> 8, z 0 -> 6.
			-- [Yoru Spec9 dark]
			id = "sparkInk", kind = "emitter", t = 0.42, life = 0.05, at = HIT,
			props = {
				Texture = 16879585719, FlipbookLayout = 4, FlipbookMode = "OneShot", -- [clear, white, 1 part, eff 51, fill 20%]
				Color = "deep", LightEmission = 0, Brightness = 1,
				Size = { { 0, 1.8 }, { 1, 0 } }, Squash = { { 0, 1 }, { 1, 1 } }, Transparency = 0,
				Lifetime = { 0.25, 0.45 }, Speed = { 15, 60 }, Drag = 4.5, SpreadAngle = { 360, 360 },
				Rotation = { -360, 360 }, ZOffset = 6,
			},
			emit = { { 0, 8 } },
		},
		{ -- two-tone sparks, half 2: the bright copy (negative LE + Br 8 as in the source). v2: 5 -> 8, z 0 -> 6.
			-- [Yoru Spec9 bright]
			id = "sparkLit", kind = "emitter", t = 0.42, life = 0.05, at = HIT,
			props = {
				Texture = 16879585719, FlipbookLayout = 4, FlipbookMode = "OneShot", -- [clear, white, 1 part, eff 51, fill 20%]
				Color = "hot", LightEmission = -1, Brightness = 8,
				Size = { { 0, 1.8 }, { 1, 0 } }, Squash = { { 0, 1 }, { 1, 1 } }, Transparency = 0,
				Lifetime = { 0.25, 0.45 }, Speed = { 15, 60 }, Drag = 4.5, SpreadAngle = { 360, 360 },
				Rotation = { -360, 360 }, ZOffset = 6,
			},
			emit = { { 0, 8 } },
		},
		{ -- dark smoke whose colour ramps body -> near-black over life (three tones inside one emitter). v2: z -1.5 ->
			-- 0.5 so it draws over the impact glow (ink needs light behind it), size 6 -> 7.5 (0.5x the flash), 6 -> 8.
			-- [Don Lorenzo Black Smoke 3 ramp; motion from Yoru smoke_0]
			id = "smokeInk", kind = "emitter", t = 0.45, life = 0.05, at = HIT,
			props = {
				Texture = 15222191191, FlipbookLayout = 8, FlipbookMode = "OneShot", -- [FAINT, black, 2 parts, eff 33 smooth, fill 30%]
				Color = { { 0, "body" }, { 1, "shadow" } }, LightEmission = 0, Brightness = 6,
				Size = { { 0, 0 }, { 1, 7.5 } }, Transparency = { { 0, 0.1 }, { 1, 1 } },
				Lifetime = { 0.5, 0.8 }, Speed = { 6, 18 }, Drag = 5, SpreadAngle = { 180, 180 },
				Rotation = { -360, 360 }, RotSpeed = { -30, 30 }, ZOffset = 0.5,
			},
			emit = { { 0, 8 } },
		},
		{ -- one light pulse at the hit, no shadows (vault: Brightness 3 -> 0 over ~0.2-0.3 s)
			id = "light", kind = "light", t = 0.4, life = 0.3, at = { 32, Y + 1, 0 },
			props = { Color = "body", Range = 16, Brightness = 0 },
			tracks = { Brightness = { { 0, 0 }, { 0.02, 3 }, { 0.3, 0, "quadOut" } } },
		},
	},
}
