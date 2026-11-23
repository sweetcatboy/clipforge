-- ClipForge base recipe "aura": from vfxmith (github.com/Frxctured/roblox-vfxmith), knowledge/categories/aura_recipe.luau,
-- MIT License, Copyright (c) 2026 Frxctured (see THIRD_PARTY_NOTICES). Texture ids are public Roblox images owned by
-- their uploaders; their terms apply. Recoloured, retimed and rescaled at play time by ClipForge's FX module.
-- AuraCharge: one generic aura / charge-up effect, distilled from 7 open-source effects (study notes: aura.md next to
-- this file). Spec for the VFXTimeline runtime (knowledge/spec-format.md).
-- UNTESTED DRAFT: built from layer tables + freeze-frame stills, never played in Studio. Run it through the pipeline
-- (capture, compare, blind review) before using it in a game.
--
-- Shape: a charge ball of radius R = 3 studs centred 3 studs above the origin (origin = the ground under the caster).
-- Sources were rescaled to R = 3 (Charge Up x0.6, Voidstrike hand x2, Sukuna limb x2-2.5); opts.scale resizes all.
-- Phases (s): ignition 0-0.1 | build 0.05-0.75 (faint bubbles pulse and a swirl sucks in round an opaque core
--             crescent, flames rise, filaments crackle) | release 0.8-0.95 | linger to ~2.7 (smoke, ground cloud).
-- Three tones: white core (stars, core crescent, pale sparks), saturated body (body flames, glitter, filaments,
-- rings), dark ink (Brightness-0 flame twins, LE -2 halo, dark smoke).
-- Revised 2026-11-14 after the recapture (see aura.md): + coreCrescent, swirlIn back to source opacity, ground ring
-- made light (a Brightness-0 ring vanished on a dark floor), releaseDiscInk dropped (unreadable under the release).
-- Values outside the documented range are kept where the sources rely on them (negative LightEmission, Brightness
-- 25-150); each such layer names a safe fallback in its comment.
-- Sources: Sukuna = Sukuna Aura.rbxm (ca02a0ef8c5a / 169d8de5f532), Tatsumaki = tatsumakirip.rbxl Charge
-- (dfdc1ff4eaa4), Voidstrike = Voidstrike.rbxl HandAura (d4822fa4128e), ChargeUp = Charge Up.rbxm (ace632d5c265),
-- Angel = angel aura.rbxm (a71fc16cc7b0), Voidflare = Voidflare.rbxl Rush Aura (79f04711219b).
-- Texture traits pass (2026-11-14, kit/scripts/texture_traits.py): rgbSparks' RGB-split chromatic cross 17062416111
-- (tinted pale -> body, its red and green fringes turn dark and teal) -> 17062452122, a plain white short cross of the
-- same Star series (key RGBCross renamed Cross). Layer values unchanged.
return {
	name = "AuraCharge",
	scale = 1,
	palette = {
		white = "#F4F8FF",
		pale = "#92BFFF", -- ChargeUp sparks #92BFFF, release #87ACFF-#90B8FF
		body = "#4A71FF", -- Voidstrike dots #4A71FF, ChargeUp glow #5A78FF
		bolt = "#5185EC", -- Voidstrike filaments
		deep = "#222356", -- ChargeUp dark glow twin
		smoke = "#141A4A", -- Sukuna smoke #510000 (about 32% value) re-hued to blue at the same value
		ink = "#000000",
	},
	textures = {
		-- [..] at the end of a texture comment = measured traits (gallery/textures/traits.json, legend in kit/scripts/texture_traits.py)
		Star2a = 7216849703, -- blurry soft 4-point glow (Tatsumaki ignition)
		-- [FAINT, grey, 1 part, eff 41 smooth, fill 12%]
		Cross = 17062452122, -- small short white cross (Star12); was Voidstrike Sparks' RGB-split cross 17062416111
		-- [clear, white, 1 part, eff 126, fill 2%]
		Needle = 18118860997, -- solid diamond needle (Voidstrike) [clear, white, 1 part, eff 203, fill 3%]
		SoftHalo = 6673021984, -- soft halo with a tiny bright centre (ChargeUp Glow particle)
		-- [FAINT, white, 1 part, eff ~142, fill 27%]
		Bubble = 7216856402, -- soft ring / sphere rim (ChargeUp circle_01) [clear, grey, 1 part, eff 172, fill 42%]
		SwirlRing = 109574326366882, -- swirl ring of fine strands (Angel "galaxy thing")
		-- [FAINT, white, 3 parts, eff ~224, fill 13%]
		OffSpec = 16171528032, -- off-centre sharp dot (ChargeUp sparks) [clear, white, 1 part, eff 57, fill 3%]
		UpBurst = 17226921546, -- Grid4x4 "Stylized Upwards Burst" (Sukuna)
		-- [clear, white, 5 parts, eff 108, fill 1%, 7/16 cells]
		StylSmoke = 11858203067, -- Grid4x4 stylized smoke (Sukuna) [clear, grey, 1 part, eff 56, fill 28%, 13/16 cells]
		Bolts = 17005480412, -- Grid4x4 electric squiggle (Voidstrike) [FAINT, white, 3 parts, eff 80, fill 7%]
		Glitter = 16511093402, -- Grid8x8 tiny glitter specks (Voidstrike dots) [clear, white, scatter, eff 49, fill 5%]
		RingFlat = 7216856024, -- soft thin ring (ChargeUp circle_04) [clear, grey, 1 part, eff 151, fill 27%]
		Star15 = 17062452486, -- long thin 4-point star (ChargeUp release) [FAINT, white, 1 part, eff 49, fill 16%]
		Disc = 6631155345, -- solid white disc (ChargeUp Filled circle) [clear, white, 1 part, eff ~268, fill 79%]
		CoreSheet = 74187681812534, -- Grid4x4 "Texture" (ChargeUp core; no thumbnail, read in the recapture as
		-- white-blue crescents at 0.20-0.55 s, attribution Inferred: check the look in Studio)
		-- [clear, white, 1 part, eff ~69, fill 1%, 13/16 cells]
		RingDissolve = 119057920510209, -- Grid4x4 ring breaking up (ChargeUp Circle_Disolve)
		-- [clear, white, 3 parts, eff 93, fill 8%, 10/16 cells]
		Cloud = 12713735498, -- swirly smoke crescent (ChargeUp fx_cloud_white)
		-- [FAINT, white, 3 parts, eff 52, fill 20%]
	},
	layers = {
		------------------------------------------------------------------ ignition (0 - 0.1)
		{ -- white 4-point flash, 3 R wide, gone in 0.1 s (Tatsumaki Cast "1" + Star "8": size 9-10 -> 0, life 0.1)
			id = "ignitionStar", kind = "emitter", t = 0, life = 0.05, at = { 0, 3, 0 },
			props = {
				Texture = "Star2a", Color = "white", LightEmission = 1, Brightness = 5,
				Size = { { 0, 9 }, { 1, 0 } }, Transparency = 0, Lifetime = 0.1, Speed = 0,
				Rotation = { 45, 45 }, RotSpeed = { 180, 180 }, ZOffset = 4,
			},
			emit = { { 0, 1 } },
		},
		{ -- tension needles: flip from wide to tall inside one 0.1 s life (Voidstrike: squash -3 -> 3 at 0.28,
			-- Rotation 90, VelocityParallel). LE -5 is undocumented; fallback LE 0, Brightness 8.
			id = "needles", kind = "emitter", t = 0, life = 0.05, at = { 0, 3, 0 }, box = { 1, 2, 1 },
			props = {
				Texture = "Needle", Color = { { 0, "pale" }, { 1, "body" } }, LightEmission = -5, Brightness = 25,
				Shape = "Box", Orientation = "VelocityParallel", Speed = { 0, 5 }, Rotation = { 90, 90 },
				Size = { { 0, 0 }, { 0.3, 1.6 }, { 1, 0 } }, Squash = { { 0, -3 }, { 0.28, 3 }, { 1, 3 } },
				Transparency = 0, Lifetime = { 0.064, 0.128 }, ZOffset = 1,
			},
			emit = { { 0, 10 } },
		},
		{ -- cross that twinkles twice (size 0 -> 1.47 -> 0.15 -> 1.41 -> 0, x2 here), speed 0-5 stopped by Drag 15.3
			-- (Voidstrike Sparks, whose RGB-fringed texture is swapped for a white one; the source has a second emitter
			-- with Squash -0.5 for the other axis)
			id = "rgbSparks", kind = "emitter", t = 0.02, life = 0.05, at = { 0, 3, 0 },
			props = {
				Texture = "Cross", Color = { { 0, "pale" }, { 1, "body" } }, LightEmission = 0, Brightness = 5,
				Size = { { 0, 0 }, { 0.21, 3 }, { 0.49, 0.3 }, { 0.74, 2.8 }, { 1, 0 } }, Squash = 0.5,
				Speed = { 0, 5 }, Drag = 15.3, SpreadAngle = 5, Lifetime = { 0.13, 0.24 }, Transparency = 0,
				ZOffset = 1,
			},
			emit = { { 0, 6 } },
		},
		------------------------------------------------------------------ build (0.05 - 0.75)
		{ -- core glow: ~2 R soft halo at only 10% opacity, re-emitted 10/s so ~5 overlap (ChargeUp Glow particle:
			-- LE 0, Brightness 8, size 9.63, Transparency 0.9 -> 1, life 0.5, Rate 10 for EmitDuration 0.5)
			id = "coreGlow", kind = "emitter", t = 0.05, life = 0.55, at = { 0, 3, 0 },
			props = {
				Texture = "SoftHalo", Color = "body", LightEmission = 0, Brightness = 8,
				Size = 5.8, Transparency = { { 0, 0.9 }, { 1, 1 } }, Lifetime = 0.5, Speed = 0,
				Rotation = { -360, 360 }, ZOffset = 0.01,
			},
			emit = { { 0, 5, 0.5 } },
		},
		{ -- dark halo twin 16% bigger, just behind the glow (ChargeUp: #222356, LE -2, Brightness 1, size 11.2,
			-- ZOffset -0.01). Fallback for LE -2: LE 0, Brightness 0.3.
			id = "coreInk", kind = "emitter", t = 0.05, life = 0.55, at = { 0, 3, 0 },
			props = {
				Texture = "SoftHalo", Color = "deep", LightEmission = -2, Brightness = 1,
				Size = 6.7, Transparency = { { 0, 0.9 }, { 1, 1 } }, Lifetime = 0.5, Speed = 0,
				Rotation = { -360, 360 }, ZOffset = -0.01,
			},
			emit = { { 0, 5, 0.5 } },
		},
		{ -- heartbeat bubble: ONE particle pulses three times (size 0 -> 8.4 -> 0 -> 4.9 -> 0 -> 10 -> 0), very faint
			-- (Transparency 1 -> 0.84 -> 1). ChargeUp circle_01 x3 emitters (Rate 2/5/2 for 0.5 s).
			id = "pulseRings", kind = "emitter", t = 0.05, life = 0.55, at = { 0, 3, 0 },
			props = {
				Texture = "Bubble", Color = "white", LightEmission = 0, Brightness = 5,
				Size = { { 0, 0 }, { 0.1, 8.4 }, { 0.26, 0 }, { 0.4, 4.9 }, { 0.5, 0 }, { 0.7, 10 }, { 1, 0 } },
				Transparency = { { 0, 1 }, { 0.5, 0.84 }, { 1, 1 } }, Lifetime = 0.5, Speed = 0,
				Rotation = { -360, 360 },
			},
			emit = { { 0, 3, 0.5 } },
		},
		{ -- suction swirl: shrinks 2 R -> 0 while spinning 500 deg/s (ChargeUp Swirls27: size 10 -> 0, RotSpeed 500,
			-- LE 1, Br 1, Transparency 1 -> 0.84 -> 1; texture swapped for Angel's swirl ring). Kept faint: in the
			-- recapture the shell layers read as glass and the opaque coreCrescent carries the build.
			id = "swirlIn", kind = "emitter", t = 0.1, life = 0.5, at = { 0, 3, 0 },
			props = {
				Texture = "SwirlRing", Color = "pale", LightEmission = 1, Brightness = 1,
				Size = { { 0, 6 }, { 1, 0 } }, Transparency = { { 0, 1 }, { 0.5, 0.84 }, { 1, 1 } },
				Lifetime = 0.5, Speed = 0, Rotation = { 0, 360 }, RotSpeed = { 500, 500 },
			},
			emit = { { 0, 4, 0.5 } },
		},
		{ -- opaque core crescent: the sprite that carries the build (ChargeUp "Texture": Grid4x4, LE -1, Br 8,
			-- Transparency 0, VelocityParallel with Speed 0.014 + Spread 360 = a random plane each, Squash -0.8,
			-- size 11.2 -> 6.7 here, life 0.5, Rate 10 for 0.5 s). Seen 0.20-0.55 s as white-blue crescents.
			-- Fallback for LE -1: LE 0, Brightness 6.
			id = "coreCrescent", kind = "emitter", t = 0.1, life = 0.5, at = { 0, 3, 0 },
			props = {
				Texture = "CoreSheet", FlipbookLayout = 4, FlipbookMode = "OneShot", Color = "pale",
				LightEmission = -1, Brightness = 8, Orientation = "VelocityParallel", Speed = 0.014,
				SpreadAngle = { 360, 360 }, Size = 6.7, Squash = -0.8, Transparency = 0, Lifetime = 0.5,
				Rotation = { -360, 360 }, ZOffset = 0.2,
			},
			emit = { { 0, 5, 0.5 } },
		},
		{ -- curling sparks: off-centre dot + spin = spiral paths; Speed 7-30 stopped by Drag 5 (ChargeUp Images/322:
			-- Speed 12.4-49.8, Drag 5, SpreadAngle 360, RotSpeed +-200, size 1.25 -> 0, life 0.25-0.55)
			id = "orbitSparks", kind = "emitter", t = 0.05, life = 0.6, at = { 0, 3, 0 },
			props = {
				Texture = "OffSpec", Color = "pale", LightEmission = 0, Brightness = 10,
				Size = { { 0, 0.75 }, { 1, 0 } }, Speed = { 7, 30 }, Drag = 5, SpreadAngle = { 360, 360 },
				Rotation = { 0, 360 }, RotSpeed = { -200, 200 }, Lifetime = { 0.25, 0.55 }, Transparency = 0,
			},
			emit = { { 0, 8, 0.6 } },
		},
		{ -- rising flame tongues: shrink to 0 while they stretch upward (Sukuna Stylized Upwards Burst: LE 0,
			-- Brightness 11, size 1.44 -> 0, Speed 3.6, Spread 55, Acceleration 0,10.8,0, Squash 0 -> 0.75; x2 here)
			id = "bodyFlames", kind = "emitter", t = 0.1, life = 0.6, at = { 0, 2, 0 }, box = { 2, 1, 2 },
			props = {
				Texture = "UpBurst", FlipbookLayout = 4, FlipbookMode = "OneShot", Color = "body",
				LightEmission = 0, Brightness = 11, Shape = "Box", EmissionDirection = "Top",
				Size = { { 0, 2.9 }, { 1, 0 } }, Squash = { { 0, 0 }, { 1, 0.75 } }, Speed = 7, SpreadAngle = 55,
				Acceleration = { 0, 21, 0 }, Lifetime = 0.5, Transparency = 0,
			},
			emit = { { 0, 12, 0.6 } },
		},
		{ -- the SAME flames at Brightness 0 = black tongues mixed into the bright ones (Sukuna pairs every element
			-- as Br 11-15 + Br 0-0.1 twins; here fewer dark ones so the body stays readable)
			id = "bodyFlamesInk", kind = "emitter", t = 0.1, life = 0.6, at = { 0, 2, 0 }, box = { 2, 1, 2 },
			props = {
				Texture = "UpBurst", FlipbookLayout = 4, FlipbookMode = "OneShot", Color = "body",
				LightEmission = 0, Brightness = 0, Shape = "Box", EmissionDirection = "Top",
				Size = { { 0, 2.9 }, { 1, 0 } }, Squash = { { 0, 0 }, { 1, 0.75 } }, Speed = 7, SpreadAngle = 55,
				Acceleration = { 0, 21, 0 }, Lifetime = 0.5, Transparency = 0, ZOffset = -0.1,
			},
			emit = { { 0, 6, 0.6 } },
		},
		{ -- slow dark smoke behind everything: eased grow, eased fade over ~1.8 s (Sukuna: colour #510000, LE 0.3,
			-- Brightness 0.3, size 0 -> 1.16, Speed 0.6-1.2, Drag 3.07, Spread 170, Acc 0,1.31,0, ZOffset -1)
			id = "darkSmoke", kind = "emitter", t = 0.1, life = 0.6, at = { 0, 2.5, 0 },
			props = {
				Texture = "StylSmoke", FlipbookLayout = 4, FlipbookMode = "OneShot", Color = "smoke",
				LightEmission = 0.3, Brightness = 0.3,
				Size = { { 0, 0 }, { 0.2, 0.9 }, { 0.4, 1.7 }, { 0.6, 2.3 }, { 0.8, 2.75 }, { 1, 2.9 } },
				Transparency = { { 0, 0 }, { 0.2, 0.31 }, { 0.4, 0.58 }, { 0.6, 0.8 }, { 0.8, 0.95 }, { 1, 1 } },
				Speed = { 1.2, 2.5 }, Drag = 3, SpreadAngle = 170, Acceleration = { 0, 2.6, 0 },
				Lifetime = { 1.6, 2.0 }, Rotation = { -360, 360 }, ZOffset = -1,
			},
			emit = { { 0, 5, 0.6 } },
		},
		{ -- electric squiggles thrown out and stopped dead (Voidstrike: spread 360, Speed 3.7-18, Drag 15, life
			-- 0.17-0.33, LE -2, Brightness 25; x2 here). Fallback for LE -2: LE 0, Brightness 10.
			id = "filaments", kind = "emitter", t = 0.25, life = 0.35, at = { 0, 3, 0 },
			props = {
				Texture = "Bolts", FlipbookLayout = 4, FlipbookMode = "OneShot", Color = "bolt",
				LightEmission = -2, Brightness = 25,
				Size = { { 0, 0 }, { 0.1, 0.7 }, { 1, 1 } }, Speed = { 7, 36 }, Drag = 15,
				SpreadAngle = { 360, 360 }, Rotation = { -180, 180 }, Lifetime = { 0.17, 0.33 }, Transparency = 0,
				ZOffset = 2,
			},
			emit = { { 0, 6 }, { 0.3, 6 } },
		},
		{ -- glitter column: a Grid8x8 sheet of tiny specks, many specks per particle, stretched upward (Voidstrike
			-- dots: LE -5, Brightness 150, VelocityParallel, Squash 2, Rotation 90, Speed 0.51, Drag 1, visible until
			-- 0.68 of life). Upward Acceleration added here. Fallback: LE 0, Brightness 15.
			id = "glitter", kind = "emitter", t = 0.15, life = 1.2, at = { 0, 3, 0 }, box = { 2, 3, 2 },
			props = {
				Texture = "Glitter", FlipbookLayout = 8, FlipbookMode = "OneShot", Color = "body",
				LightEmission = -5, Brightness = 150, Shape = "Box", Orientation = "VelocityParallel",
				Squash = 2, Rotation = { 90, 90 }, Speed = 0.5, Drag = 1, Acceleration = { 0, 2, 0 },
				Size = { { 0, 0 }, { 1, 2.5 } },
				Transparency = { { 0, 0 }, { 0.68, 0 }, { 0.78, 0.86 }, { 1, 1 } }, Lifetime = { 0.2, 0.5 },
			},
			emit = { { 0, 30, 1.2 } },
		},
		{ -- light ring on the ground, eased grow then hold, eased fade (ChargeUp FloorWind circle_04 timing: size
			-- 0 -> 10.2, life 1). The source draws it black (Brightness 0); the recapture showed dark floor rings
			-- vanish on a dark floor (Tatsumaki) while LE 1 rings read (Angel), so it is light here. On a light
			-- floor, Brightness 0 gives the black version.
			id = "groundRing", kind = "emitter", t = 0, life = 0.5, at = { 0, 0.1, 0 },
			props = {
				Texture = "RingFlat", Color = "pale", LightEmission = 1, Brightness = 2,
				Orientation = "VelocityPerpendicular", EmissionDirection = "Top", Speed = 0.03,
				Size = { { 0, 0 }, { 0.06, 2.2 }, { 0.11, 3.7 }, { 0.16, 5 }, { 0.21, 5.7 }, { 0.27, 6.1 }, { 1, 6.1 } },
				Transparency = { { 0, 0.33 }, { 0.04, 0.51 }, { 0.09, 0.64 }, { 0.15, 0.76 }, { 0.21, 0.84 },
					{ 0.27, 0.91 }, { 1, 1 } },
				Lifetime = 1, Rotation = { -360, 360 },
			},
			emit = { { 0, 3, 0.5 } },
		},
		------------------------------------------------------------------ release (0.8 - 0.95)
		{ -- release star: long 4-point star shrinking 2.5 R -> 0 in 0.103 s while squash stretches it (ChargeUp
			-- Star15: LE -1, Brightness 10, size 12.6 -> 0, Squash 0 -> 2.21, EmitDelay 0.8). Fallback: LE 1, Br 3.
			id = "releaseStar", kind = "emitter", t = 0.8, life = 0.05, at = { 0, 3, 0 },
			props = {
				Texture = "Star15", Color = "pale", LightEmission = -1, Brightness = 10,
				Size = { { 0, 7.5 }, { 1, 0 } }, Squash = { { 0, 0 }, { 1, 2.2 } }, Rotation = { 0, 360 },
				Lifetime = 0.103, Speed = 0, Transparency = 0, ZOffset = 0.5,
			},
			emit = { { 0, 1 } },
		},
		{ -- release disc: cubic-out size baked into keys (38% of full size at 5% of life, 92% at 15%), 20% opacity
			-- (ChargeUp Filled circle: LE 0.5, Brightness 1, size 0 -> 7.39, Transparency 0.8 -> 1, Squash 0 -> 1.5)
			id = "releaseDisc", kind = "emitter", t = 0.8, life = 0.05, at = { 0, 3, 0 },
			props = {
				Texture = "Disc", Color = "pale", LightEmission = 0.5, Brightness = 1,
				Size = { { 0, 0 }, { 0.05, 1.7 }, { 0.1, 2.7 }, { 0.15, 3.7 }, { 0.24, 4.4 }, { 1, 4.4 } },
				Squash = { { 0, 0 }, { 1, 1.5 } }, Transparency = { { 0, 0.8 }, { 1, 1 } }, Lifetime = 0.103,
				Speed = 0, ZOffset = 0.4,
			},
			emit = { { 0, 1 } },
		},
		{ -- flat shock ring that breaks up as it grows (ChargeUp Circle_Disolve: Grid4x4 OneShot, Brightness 8,
			-- size 0 -> 13.7 cubic-out, life 0.15, EmitDelay 0.83, VelocityPerpendicular)
			id = "releaseRing", kind = "emitter", t = 0.83, life = 0.05, at = { 0, 3, 0 },
			props = {
				Texture = "RingDissolve", FlipbookLayout = 4, FlipbookMode = "OneShot", Color = "pale",
				LightEmission = 0, Brightness = 8, Orientation = "VelocityPerpendicular", EmissionDirection = "Top",
				Speed = 0.016,
				Size = { { 0, 0 }, { 0.05, 3.1 }, { 0.1, 5.1 }, { 0.15, 6.8 }, { 0.24, 8.1 }, { 1, 8.2 } },
				Transparency = 0, Lifetime = 0.15, Rotation = { -360, 360 }, ZOffset = 0.4,
			},
			emit = { { 0, 1 } },
		},
		{ -- ground cloud pushed out by the release, eased grow + eased fade over 1 s (ChargeUp fx_cloud_white_3:
			-- LE 0, Brightness 1, size 0 -> 16.5, Transparency 0.33 -> 0.91 by 0.27 of life; tinted pale here because
			-- the still at 0.80 s reads blue, cause unclear)
			id = "groundCloud", kind = "emitter", t = 0.8, life = 0.05, at = { 0, 0.15, 0 },
			props = {
				Texture = "Cloud", Color = "pale", LightEmission = 0, Brightness = 1,
				Orientation = "VelocityPerpendicular", EmissionDirection = "Top", Speed = 0.05, SpreadAngle = 25,
				Size = { { 0, 0 }, { 0.06, 3.6 }, { 0.11, 6 }, { 0.16, 8 }, { 0.21, 9.1 }, { 0.27, 9.9 }, { 1, 9.9 } },
				Transparency = { { 0, 0.33 }, { 0.04, 0.51 }, { 0.09, 0.64 }, { 0.15, 0.76 }, { 0.21, 0.84 },
					{ 0.27, 0.91 }, { 1, 1 } },
				Lifetime = 1, Rotation = { -360, 360 },
			},
			emit = { { 0, 2 } },
		},
		------------------------------------------------------------------ light (whole effect)
		{ -- one PointLight: ignition kick, quint-out dip during the build, kick again at release (Tatsumaki Light:
			-- Brightness 2 -> 0 over 0.5 s Quint, Range 8 around a hand; Range 12 here for R = 3)
			id = "light", kind = "light", t = 0, life = 1.4, at = { 0, 3, 0 },
			props = { Color = "body", Range = 12, Brightness = 0 },
			tracks = {
				Brightness = { { 0, 2 }, { 0.5, 0.6, "quintOut" }, { 0.78, 1.2, "sineIn" }, { 0.8, 3 },
					{ 1.4, 0, "quadOut" } },
			},
		},
	},
}
