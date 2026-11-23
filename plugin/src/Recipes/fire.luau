-- ClipForge base recipe "fire": from vfxmith (github.com/Frxctured/roblox-vfxmith), knowledge/categories/fire_recipe.luau,
-- MIT License, Copyright (c) 2026 Frxctured (see THIRD_PARTY_NOTICES). Texture ids are public Roblox images owned by
-- their uploaders; their terms apply. Recoloured, retimed and rescaled at play time by ClipForge's FX module.
-- FireEruption: one generic ground fire burst for VFXTimeline (vfxmith spec format), distilled from the
-- 7 open-source fire effects studied in fire.md (same folder). UNTESTED DRAFT: no Studio capture yet.
-- Phases (s): ignite/flash 0-0.1 | peak 0-0.35 | body second wave 0.2-1.0 | cool (colour -> oxblood, smoke)
-- 0.35-0.8 | linger (cracks, scorch, smoke) to ~1.4 | last embers ~3.1.
-- v2 (after the first Studio capture): fires at t=0 like FireTowers (flash on frame 1); the charge read as a radial
-- streak burst, so it is off by default (enable it and set IGNITE = 0.35 for an anticipation); fuller body with a
-- second wave; brighter maroon smoke; black ink in front of the flames.
-- Scale: R = final size of the main ground ring (12 studs here; FireTowers' is 17.9). Every size is a fraction of R,
-- so opts.scale resizes the whole stack. Speeds were scaled by 12 / 17.9 = 0.67 from FireTowers.
-- Three tones: white core (flash, core seat), saturated orange/red body (column, tongues, blobs, body, rings),
-- dark ink (ink tongues, scorch, black smoke, ramps that cool to #1E0702).
-- Sources: FT = FireTowers 6f9f67b2a7cf, SUN = The sun! 56ff37281fe7, SLOP = RoVfx Flame Slop 818f3ffd4aef,
-- FOS = flameos 1fd017316313, F2 = flame2 521e568eee6a, CUBE = oragnecubething d9609eb01ee4.
-- Brightness/LightEmission values are copied from those effects: Br 25 flashes and LE -1 rings are what the authors
-- used; if bloom washes the screen, lower the big flat ones first (cracks, shockRing), never the tiny sparks.

local R = 12 -- main ground ring size in studs (see header)

-- Size-over-life shapes measured on FireTowers (fraction of the final size at 0.1, 0.2, ... of life).
local SOFT = { { 0, 0 }, { 0.1, 0.16 }, { 0.2, 0.31 }, { 0.3, 0.45 }, { 0.4, 0.58 }, { 0.5, 0.70 }, { 0.6, 0.80 },
	{ 0.7, 0.89 }, { 0.8, 0.95 }, { 1, 1 } } -- FT rings, smoke discs, flashes
local PUNCHY = { { 0, 0 }, { 0.1, 0.19 }, { 0.2, 0.54 }, { 0.3, 0.73 }, { 0.4, 0.83 }, { 0.5, 0.90 }, { 0.6, 0.94 },
	{ 0.8, 0.99 }, { 1, 1 } } -- FT starburst, shock rings, cracks

local function grow(curve, peak)
	local out = {}
	for i, k in ipairs(curve) do
		out[i] = { k[1], k[2] * peak }
	end
	return out
end

local FLAT = { Orientation = "VelocityPerpendicular", EmissionDirection = "Top", Speed = 0.01 } -- FT ground stack

local function flat(props)
	for k, v in pairs(FLAT) do
		if props[k] == nil then props[k] = v end
	end
	return props
end

local IGNITE = 0 -- the moment the fire goes off (0.35 with the optional charge)

return {
	name = "FireEruption",
	palette = {
		white = "#FFF1D6", -- core: flash and seat
		hot = "#FF9A50", -- at Br 25 this clips to yellow-white (FT flash measured (255,254,64) on screen)
		orange = "#FF4E08", -- FT tongues
		red = "#FF431D", -- FT ramp start
		oxblood = "#1E0702", -- FT ramp end: every body layer cools into this
		scorch = "#240000", -- FT dark crack twin
		ink = "#000000",
	},
	textures = {
		-- [..] at the end of a texture comment = measured traits (gallery/textures/traits.json, legend in kit/scripts/texture_traits.py)
		Charge = 14704600122, -- radial soft streaks (SUN "Charge") [FAINT, white, 7 parts, eff 85, fill 10%]
		GlowDot = 13189667061, -- 4x4 glow dot with cross flare, grows/peaks/shrinks (FT "23")
		-- [clear, white, 1 part, eff 24 smooth, fill 6%]
		Starburst = 16892268625, -- spiky star burst, single image (FT "55") [FAINT, white, 6 parts, eff 262, fill 15%]
		CoreSmoke = 9470659899, -- 8x8 soft smoke on BLACK, additive only (F2 "3", hot base)
		-- [BLACK card, white, 1 part, eff ~28 smooth, fill 11%]
		BigFire = 17703378809, -- 4x4 big flame (FT "Recolorable Big Fire"); not seen as a thumbnail
		-- [clear, white, 1 part, eff ~49, fill 28%]
		FireShard = 118422915306523, -- 4x4 flame shard (FT "edgier_fire_shard"); not seen as a thumbnail
		-- [clear, grey, 1 part, eff ~60, fill 16%]
		FireDark = 119387723789903, -- 4x4 flame (FT "fire3", used dark); not seen as a thumbnail
		-- [clear, white, 1 part, eff 70, fill 31%]
		FlameFlip = 13528076463, -- 4x4 flame flick (FT "flameflip3"); not seen as a thumbnail
		-- [clear, white, 1 part, eff 69, fill 12%]
		FireRise = 15730376453, -- 4x4 rising toon flame (FT "diff_angle_fire_shard")
		-- [clear, grey, 1 part, eff 90, fill 29%]
		ShockRing = 18707464177, -- 4x4 crackling ring, only ~6 of 16 cells filled = built-in early cut
		-- [clear, white, 4 parts, eff ~63, fill 13%, 5/16 cells]
		FireRing = 13800461961, -- 4x4 ring of fire puffs spreading (FT "2P_RBurst5_Contrast")
		-- [clear, white, 3 parts, eff 75, fill 10%, 15/16 cells]
		Scorch = 82556288879264, -- 4x4 dark fractal wisps (FT dark crack twin)
		-- [FAINT, white, 7 parts, eff ~55, fill 21%]
		Cracks = 124744903601692, -- 4x4 glowing ground cracks (FT); not seen as a thumbnail
		-- [FAINT, white, 5 parts, eff ~46 smooth, fill 24%]
		Smoke = 15072761142, -- 4x4 soft smoke (SLOP maroon smoke)
		-- [clear, grey, 2 parts, eff 41 smooth, fill 37%, 12/16 cells]
		InkSmoke = 16867492882, -- 4x4 toon smoke (SLOP Br 0 black smoke)
		-- [clear, white, 1 part, eff 34 smooth, fill 16%, 13/16 cells]
		Ember = 115530057206994, -- F2 "EMBER"; not seen as a thumbnail
		-- [clear, grey, 1 part, eff ~46 smooth, fill 3%, 11/16 cells]
		Twinkle = 12224333321, -- 2x2 looping sparkle (CUBE "sparkles"); not seen as a thumbnail
		-- [BLACK card, white, 1 part, eff 122, fill 11%]
	},
	layers = {
		------------------------------------------------------------------ charge (0 - 0.35)
		{ -- streak marks far out on big sprites slide to the centre as the sprites shrink (CUBE "charge", SUN "Charge").
			-- OFF in v2: on the stills it read as an outward streak burst, not a charge
			id = "charge", kind = "emitter", t = 0, life = 0.05, at = { 0, 2.5, 0 }, enabled = false,
			props = {
				Texture = "Charge", Color = { { 0, "#FF4006" }, { 1, "#FFA145" } }, LightEmission = 1, Brightness = 1,
				Size = { { 0, 1.5 * R, 0.6 * R }, { 1, 0 } }, Speed = 0, Drag = 1.75, Lifetime = { 0.3, 0.35 },
				Rotation = { -180, 180 }, RotSpeed = { -50, 50 }, Squash = { { 0, -1 }, { 1, -0.7 } },
				Transparency = { { 0, 1 }, { 0.5, 0.2, 0.2 }, { 1, 1 } }, ZOffset = 2.5,
			},
			emit = { { 0, 16 } },
		},
		------------------------------------------------------------------ ignite + flash (0.35 - 0.45)
		{ -- one big soft white-hot flash, 4-6 frames (FT "23": LE 1, Br 25, Size -> 1.8 R, z 15). Lifetime min raised
			-- from FT's 0 to 0.06 so the flash can never roll ~0 (fire.md e.7; the recapture caught no FT flash at 0.03 s)
			id = "flash", kind = "emitter", t = IGNITE, life = 0.05, at = { 0, 0.25 * R, 0 },
			props = {
				Texture = "GlowDot", FlipbookLayout = 4, FlipbookMode = "OneShot", Color = "hot",
				LightEmission = 1, Brightness = 25, Orientation = "FacingCameraWorldUp", Speed = 0.01,
				Size = grow(SOFT, 1.8 * R), Lifetime = { 0.08, 0.1 }, Rotation = { -360, 360 }, Transparency = 0,
				ZOffset = 15,
			},
			emit = { { 0, 1 } },
		},
		{ -- vertical flare: same sprite, Squash 1, Rotation 0 (FT's second "23")
			id = "flareV", kind = "emitter", t = IGNITE, life = 0.05, at = { 0, 0.25 * R, 0 },
			props = {
				Texture = "GlowDot", FlipbookLayout = 4, FlipbookMode = "OneShot", Color = "white",
				LightEmission = 1, Brightness = 25, Orientation = "FacingCameraWorldUp", Speed = 0.01,
				Size = grow(SOFT, 1.4 * R), Squash = 1, Lifetime = { 0.08, 0.1 }, Rotation = 0, Transparency = 0,
				ZOffset = 15,
			},
			emit = { { 0, 1 } },
		},
		{ -- spiky starburst flat on the ground, fades by its ramp to near black (FT "55": LE 1, Br 25, life 0.1)
			id = "starburst", kind = "emitter", t = IGNITE, life = 0.05, at = { 0, 0.1, 0 },
			props = flat({
				Texture = "Starburst", Color = { { 0, "#FF3A0A" }, { 0.49, "#621604" }, { 1, "#0E0200" } },
				LightEmission = 1, Brightness = 25, Size = grow(PUNCHY, 0.6 * R), Lifetime = 0.12,
				Rotation = { -360, 360 }, Transparency = 0, ZOffset = 5,
			}),
			emit = { { 0, 1 } },
		},
		{ -- white-hot seat at the base: the only opaque additive layer (F2's white-hot ball, layer "3": 8x8, LE 1,
			-- Br 5, Tr 0, RotSpeed +-150; in F2 it reads as a ~3-stud ball inside the halo)
			id = "core", kind = "emitter", t = IGNITE, life = 0.05, at = { 0, 1.5, 0 }, box = { 0.2 * R, 0.1 * R, 0.2 * R },
			props = {
				Texture = "CoreSmoke", FlipbookLayout = 8, FlipbookMode = "OneShot", Shape = "Box",
				Color = { { 0, "white" }, { 0.4, "#FFC870" }, { 1, "#FF6A1A" } }, LightEmission = 1, Brightness = 5,
				Size = { { 0, 0.15 * R }, { 0.25, 0.4 * R }, { 1, 0.5 * R } }, Lifetime = { 0.45, 0.6 },
				Speed = { 1, 3 }, Acceleration = { 0, 6, 0 }, Rotation = { -360, 360 }, RotSpeed = { -150, 150 },
				Transparency = { { 0, 0 }, { 0.6, 0.1 }, { 1, 1 } }, ZOffset = 3,
			},
			emit = { { 0, 6 } }, -- v2: 4 -> 6
		},
		------------------------------------------------------------------ body (0.35 - 0.95)
		{ -- upright column: one big flame sprite stretched by Squash 0 -> 3, cooling to oxblood (FT "Recolorable Big
			-- Fire": FacingCameraWorldUp, const Size, life 0.5, Br 5; FT used LE -1 on this copy, LE 0 here)
			id = "column", kind = "emitter", t = IGNITE, life = 0.05, at = { 0, 0.45 * R, 0 },
			props = {
				Texture = "BigFire", FlipbookLayout = 4, FlipbookMode = "OneShot", Orientation = "FacingCameraWorldUp",
				Color = { { 0, "red" }, { 1, "oxblood" } }, LightEmission = 0, Brightness = 5, Speed = 0.01,
				Size = 1.1 * R, Squash = { { 0, 0 }, { 0.1, 0.48 }, { 0.2, 0.94 }, { 0.4, 1.75 }, { 1, 3 } },
				Lifetime = 0.5, Rotation = 0, Transparency = { { 0, 0 }, { 0.6, 0.1 }, { 1, 1 } }, ZOffset = 0,
			},
			emit = { { 0, 1 } },
		},
		{ -- bright tongues: one burst, Spread 0, a 25x speed range = a tower of tongues at different heights
			-- (FT "edgier_fire_shard": LE 1, Br 5, Speed 4.7-118, swell 0 -> peak @0.37 -> half @0.52 -> 0).
			-- FT rolled Rotation +-360; narrowed so tongues point up (untested)
			id = "tongues", kind = "emitter", t = IGNITE + 0.01, life = 0.05, at = { 0, 1, 0 },
			props = {
				Texture = "FireShard", FlipbookLayout = 4, FlipbookMode = "OneShot", Orientation = "FacingCameraWorldUp",
				Color = "orange", LightEmission = 1, Brightness = 5, SpreadAngle = 0, Speed = { 3, 70 },
				Size = { { 0, 0 }, { 0.37, 0.4 * R, 0.18 * R }, { 0.52, 0.2 * R }, { 1, 0 } },
				Lifetime = { 0.2, 0.45 }, Rotation = { -25, 25 }, Transparency = 0, ZOffset = 1,
			},
			emit = { { 0, 6 } }, -- v2: 4 -> 6 (FT fired 3 + 3 + 3 shard layers)
		},
		{ -- dark tongues behind the bright ones (FT "fire3": LE 0, Br 5, #441401, Speed 1.8-44); made a bit bigger
			-- than FT's so the ink twin reads (fire.md e.2)
			id = "tonguesInk", kind = "emitter", t = IGNITE + 0.01, life = 0.05, at = { 0, 1, 0 },
			props = {
				Texture = "FireDark", FlipbookLayout = 4, FlipbookMode = "OneShot", Orientation = "FacingCameraWorldUp",
				Color = "#441401", LightEmission = 0, Brightness = 5, SpreadAngle = 0, Speed = { 2, 45 },
				Size = { { 0, 0.3 * R }, { 0.3, 0.35 * R, 0.1 * R }, { 0.55, 0.18 * R }, { 1, 0 } },
				Lifetime = { 0.25, 0.8 }, Rotation = { -25, 25 }, Transparency = 0, ZOffset = 0.5,
			},
			emit = { { 0, 3 } },
		},
		{ -- blobs flung up and out, solid colour that cools yellow -> red -> oxblood by its ramp at Br 15
			-- (FT "flameflip3"/"somefire"/"yesfire": VelocityParallel, Speed 50, Spread 90, LE 0, Br 15; FT's
			-- Acceleration (25, 50, 25) leaned them to one side, made symmetric here)
			id = "blobs", kind = "emitter", t = IGNITE + 0.02, life = 0.05, at = { 0, 0.5, 0 },
			props = {
				Texture = "FlameFlip", FlipbookLayout = 4, FlipbookMode = "OneShot", Orientation = "VelocityParallel",
				Color = { { 0, "#FF4B08" }, { 0.004, "#9A2D05" }, { 0.47, "#5B1407" }, { 1, "#270606" } },
				LightEmission = 0, Brightness = 15, Speed = 34, SpreadAngle = { 90, -90 }, Acceleration = { 0, 34, 0 },
				Size = { { 0, 0.29 * R, 0.045 * R }, { 1, 0 } }, Lifetime = { 0.25, 0.5 }, Rotation = { -360, 360 },
				Transparency = 0, ZOffset = 5,
			},
			emit = { { 0, 8 } },
		},
		{ -- solid flame body round the base: burst out, rise, stop; fade-in-and-hold envelope (shape: SLOP Br 8 LE 0
			-- flames, Speed 1-6, Drag 4-7, Acc +12; envelope: FOS; texture FT "diff_angle_fire_shard")
			id = "body", kind = "emitter", t = IGNITE + 0.03, life = 0.25, -- life covers the 0.2 s second wave at = { 0, 1, 0 }, box = { 0.6 * R, 0.1 * R, 0.6 * R },
			props = {
				Texture = "FireRise", FlipbookLayout = 4, FlipbookMode = "OneShot", Orientation = "FacingCameraWorldUp",
				Shape = "Box", Color = { { 0, "#FF7A3E" }, { 0.35, "red" }, { 0.75, "#80220E" }, { 1, "oxblood" } },
				LightEmission = 0, Brightness = 8, Speed = { 2, 6 }, SpreadAngle = 35, Drag = 4,
				Acceleration = { 0, 12, 0 }, Size = { { 0, 0.2 * R }, { 0.3, 0.6 * R, 0.1 * R }, { 1, 0.8 * R } },
				Lifetime = { 0.45, 0.8 }, Rotation = { -20, 20 },
				Transparency = { { 0, 1 }, { 0.06, 0.3 }, { 0.23, 0 }, { 0.5, 0.08 }, { 0.8, 0.49 }, { 1, 1 } },
				ZOffset = 0.8,
			},
			-- v2: 10 -> 12 plus a second wave so the flame body carries 0.2-1.0 s (the gap after the peak)
			emit = { { 0, 12 }, { 0.2, 8 } },
		},
		------------------------------------------------------------------ ground stack (0.35 - 1.6)
		{ -- crackling shock ring; its sheet fills ~6 of 16 cells, so it cuts out at ~40 % of life
			-- (FT "Texture"/"SmokeOrImpact": LE -1, Br 25, Size -> 0.83 R punchy, life 1; LE -1 is undocumented,
			-- fall back to LE 0, Br 10 if it renders wrong)
			id = "shockRing", kind = "emitter", t = IGNITE, life = 0.05, at = { 0, 0.12, 0 },
			props = flat({
				Texture = "ShockRing", FlipbookLayout = 4, FlipbookMode = "OneShot", Color = "#FF3911",
				LightEmission = -1, Brightness = 25, Size = grow(PUNCHY, 0.83 * R), Lifetime = 1,
				Rotation = { -360, 360 }, Transparency = 0, ZOffset = 5,
			}),
			emit = { { 0, 1 } },
		},
		{ -- ring of fire puffs spreading on the ground, cooling to oxblood (FT "2P_RBurst5_Contrast" /
			-- "ContrastSmokeBurst": LE 0, Br 1, #FF431D -> #1E0702, Size -> 1 R soft, life 1)
			id = "groundFire", kind = "emitter", t = IGNITE + 0.01, life = 0.05, at = { 0, 0.08, 0 },
			props = flat({
				Texture = "FireRing", FlipbookLayout = 4, FlipbookMode = "OneShot",
				Color = { { 0, "red" }, { 1, "oxblood" } }, LightEmission = 0, Brightness = 1,
				Size = grow(SOFT, 1.0 * R), Lifetime = 1, Rotation = { -360, 360 },
				Transparency = { { 0, 0 }, { 1, 1 } }, ZOffset = 5,
			}),
			emit = { { 0, 2 } },
		},
		{ -- dark scorch under the cracks (FT "Texture" 82556288879264: LE 0, #240000, Tr 0 -> 0.485 @0.68 -> 0.95;
			-- ends at 1 here so it does not pop)
			id = "scorch", kind = "emitter", t = IGNITE + 0.05, life = 0.05, at = { 0, 0.06, 0 },
			props = flat({
				Texture = "Scorch", FlipbookLayout = 4, FlipbookMode = "OneShot", Color = "scorch",
				LightEmission = 0, Brightness = 1, Size = grow(PUNCHY, 0.7 * R), Lifetime = 1.3,
				Rotation = { -360, 360 }, Transparency = { { 0, 0 }, { 0.68, 0.485 }, { 1, 1 } }, ZOffset = 4.5,
			}),
			emit = { { 0, 1 } },
		},
		{ -- glowing cracks that outlive the flames (FT "Texture" 124744903601692: LE 1, Br 25, #FF3B00, life 1)
			id = "cracks", kind = "emitter", t = IGNITE + 0.05, life = 0.05, at = { 0, 0.1, 0 },
			props = flat({
				Texture = "Cracks", FlipbookLayout = 4, FlipbookMode = "OneShot", Color = "#FF3B00",
				LightEmission = 1, Brightness = 25, Size = grow(PUNCHY, 0.85 * R), Lifetime = 1.2,
				Rotation = { -360, 360 }, Transparency = { { 0, 0 }, { 0.68, 0.485 }, { 1, 1 } }, ZOffset = 5,
			}),
			emit = { { 0, 1 } },
		},
		------------------------------------------------------------------ smoke (0.45 - 1.95)
		{ -- maroon smoke that thickens as it cools (SLOP 15072761142: Color #FF3A0A, LE 0, Br 0.2,
			-- Tr 0.944 -> 0.562 @0.27 -> 0.356 @0.72 -> 1, Drag 1.3, Acc +2..4)
			id = "smoke", kind = "emitter", t = IGNITE + 0.15, life = 0.05, at = { 0, 2, 0 }, box = { 0.6 * R, 0.2 * R, 0.6 * R },
			props = {
				Texture = "Smoke", FlipbookLayout = 4, FlipbookMode = "OneShot", Shape = "Box", Color = "#FF3A0A",
				-- v2: Br 0.2 -> 0.5 (flameos ink 0.25-0.5): at 0.2 it vanished on the dark stage
				LightEmission = 0, Brightness = 0.5, Size = { { 0, 0.35 * R, 0.15 * R }, { 1, 0.7 * R, 0.15 * R } },
				Lifetime = { 0.9, 1.45 }, Speed = { 1, 4 }, SpreadAngle = 60, Drag = 1.3, Acceleration = { 0, 4, 0 },
				Rotation = { -360, 360 },
				Transparency = { { 0, 0.944 }, { 0.27, 0.562 }, { 0.72, 0.356 }, { 1, 1 } }, ZOffset = 1.3,
			},
			emit = { { 0, 12 } }, -- v2: 8 -> 12
		},
		{ -- black ink smoke between flames and the maroon smoke (SLOP 16867492882: LE 0, Br 0 = black whatever
			-- the Color). SLOP kept Tr 0.86 because it streamed at Rate 10; a one-shot burst needs it denser
			id = "inkSmoke", kind = "emitter", t = IGNITE + 0.1, life = 0.05, at = { 0, 2.5, 0 }, box = { 0.5 * R, 0.2 * R, 0.5 * R },
			props = {
				Texture = "InkSmoke", FlipbookLayout = 4, FlipbookMode = "OneShot", Shape = "Box", Color = "ink",
				LightEmission = 0, Brightness = 0, Size = { { 0, 0.3 * R, 0.1 * R }, { 1, 0.55 * R, 0.1 * R } },
				Lifetime = { 0.7, 1.4 }, Speed = { 1, 5 }, SpreadAngle = 70, Drag = 1, Acceleration = { 0, 4.4, 0 },
				Rotation = { -360, 360 }, Transparency = { { 0, 1 }, { 0.15, 0.55 }, { 0.6, 0.6 }, { 1, 1 } },
				-- v2: 0.4 -> 1.5, half way to SLOP's dark swirls at z 2.4: black only reads over the flames
				ZOffset = 1.5,
			},
			emit = { { 0, 8 } },
		},
		------------------------------------------------------------------ sparks + embers (0.35 - 3.4)
		{ -- tiny hot sparks: pop out and stop (stop distance ~ Speed / Drag), then rise (F2 "EMBER": LE 1, Br 100,
			-- Size 0 -> 0.25, Speed 0.01-50, Drag 15, Spread 360, Acc +50 Y, VelocityParallel)
			id = "sparks", kind = "emitter", t = IGNITE, life = 0.05, at = { 0, 1.5, 0 },
			props = {
				Texture = "Ember", FlipbookLayout = 4, FlipbookMode = "OneShot", Orientation = "VelocityParallel",
				Color = { { 0, "#F9C31F" }, { 1, "#F92815" } }, LightEmission = 1, Brightness = 100,
				Size = { { 0, 0 }, { 0.12, 0.08 }, { 0.25, 0.15 }, { 1, 0.25 } }, Speed = { 0.01, 50 }, Drag = 15,
				SpreadAngle = 360, Acceleration = { 0, 30, 0 }, Lifetime = { 0.3, 0.7 },
				Transparency = { { 0, 0.5 }, { 1, 1 } }, ZOffset = 2,
			},
			emit = { { 0, 40 } },
		},
		{ -- twinkling embers that hang and drift up (CUBE "sparkles": 2x2 Loop 16-25 fps, LE 1, Br 6.3, Size 0.364,
			-- life 0.5-3, Speed 3-43, Drag 2.5; CUBE fell at Acc -1, these rise at +2; CUBE LI 0.5 -> 0 here)
			id = "embers", kind = "emitter", t = IGNITE + 0.1, life = 0.05, at = { 0, 2, 0 },
			props = {
				Texture = "Twinkle", FlipbookLayout = 2, FlipbookMode = "Loop", FlipbookFramerate = { 16, 24 },
				Color = "#FF6E20", LightEmission = 1, Brightness = 6.3,
				Size = { { 0, 0.36, 0.36 }, { 0.88, 0.35, 0.22 }, { 1, 0 } }, Lifetime = { 0.8, 3 },
				Speed = { 3, 25 }, SpreadAngle = 50, Drag = 2.5, Acceleration = { 0, 2, 0 }, Rotation = { -180, 180 },
				RotSpeed = { -10, 10 }, Transparency = { { 0, 1 }, { 0.34, 0 }, { 1, 0 } }, ZOffset = 2,
			},
			emit = { { 0, 30 } },
		},
		------------------------------------------------------------------ light
		{ -- warm spill (SLOP: PointLights #FF6141 Br 3 Range 7 + Br 1 Range 12; one light per effect here)
			id = "light", kind = "light", t = IGNITE, life = 1.2, at = { 0, 0.3 * R, 0 },
			props = { Color = "#FF6141", Range = 0.6 * R, Brightness = 0 },
			tracks = { Brightness = { { 0, 0 }, { 0.03, 3 }, { 0.3, 2 }, { 1.2, 0, "quadOut" } } },
		},
	},
}
