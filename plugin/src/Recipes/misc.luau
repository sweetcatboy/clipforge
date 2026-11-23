-- ClipForge base recipe "misc": from vfxmith (github.com/Frxctured/roblox-vfxmith), knowledge/categories/misc_recipe.luau,
-- MIT License, Copyright (c) 2026 Frxctured (see THIRD_PARTY_NOTICES). Texture ids are public Roblox images owned by
-- their uploaders; their terms apply. Recoloured, retimed and rescaled at play time by ClipForge's FX module.
-- HolyBurst: one generic "miscellaneous" effect (holy / light / character burst) for VFXTimeline, built from the
-- 10 open-source effects studied in misc.md (same folder). v2 = one tuning pass after the first Studio capture (v1 was
-- small and faint: no frame-1 pop, no glowing body). Changes are half steps toward the misc.md tables.
-- Values come from the anatomy table in misc.md; source effects are named per layer:
--   lamp2 = 174b4feeb18f (WrathPump lamp glow)   gravity = fea421530c94 (Gravity/Pull)   jane = fc291adfbbff
--   head = fc25b1ce31bb (WrathPump flaming eyes)  gon = ea235b3b244f   galaxy = c064a4796d09   golden = db693743ee74
--   mochiFX = e83e1882d477   skyrim = 2d159f40caf9 (Skyrim Healing)   mochiHit = 01c9657c80d8
-- Shape: R = 6 studs (character scale); burst centre 3 studs above the origin (chest height), ground layers at y 0.1.
-- Phases: flash + burst 0-0.3 | glow, halo + rays 0.05-1.4 | linger motes / dust to ~2.6 s.
-- Three tones: white core (flash, bloom, core, glints, specks), saturated gold body (rays, streaks, rings,
-- ripples, glow, halo, ray fan, motes), dark ink (coreInk, inkCrown, glintInk, streakInk, dust).
-- Deliberate departures from the evidence (lessons from misc.md section e): fewer particles per bright layer than
-- lamp2 (12 instead of 20) to avoid its white-out, dust Transparency 0.8 instead of 0.98 (too faint), every layer
-- LightInfluence 0 (the runtime sets it), the core's ink twin is a Br0 copy behind it instead of lamp2's LE -2 copy
-- (the recapture showed that pair as a dim muddy flicker). Floor layers sit 0.1 studs above the origin: the origin
-- must be ON the ground (the first replay lost floor layers under the stage).
-- Texture traits pass (2026-11-14, kit/scripts/texture_traits.py): glintInk no longer shares the glints' Star113
-- 14590086212, whose wide low-alpha glow fills its frame (a faint card: at Brightness 0 every glint dragged a soft dark
-- square over the glow); it uses StarInk 17450657969, a clean long thin 4-point star. Layer values unchanged.
return {
	name = "HolyBurst",
	palette = {
		white = "#FFF6E6",
		gold = "#FFB347",
		amber = "#FF8E4C", -- skyrim Light / LightRays colour
		deep = "#FF5015", -- skyrim RingBG colour: the saturated end of the ramps
		peach = "#FFB37C", -- golden mid-life colour
		hot = "#13100D", -- lamp2 near-black: hue by ratio, intensity by Brightness (misc.md d1)
		hotGold = "#1A1308", -- same trick, gold ratio: x Brightness 10 = (1.0, 0.75, 0.31) per particle
		ember = "#821D13", -- mochiFX Wisps end colour
		dust = "#6A4A30",
		brown = "#2D160B", -- golden end colour
		ink = "#000000",
	},
	textures = {
		-- [..] at the end of a texture comment = measured traits (gallery/textures/traits.json, legend in kit/scripts/texture_traits.py)
		PullStreak = 17627858096, -- gravity FlashWhite / FlashGreem, Grid4x4 (Loop at fps 1 = first frame)
		-- [clear, white, 13 parts, eff ~327, fill 3%]
		Rays = 7265756294, -- mochiHit "Rays": one-frame ray flash [BLACK card, white, 1 part, eff ~169, fill 9%]
		Flare = 16511998441, -- lamp2 / head "flare" bloom [FAINT, white, 1 part, eff 272, fill 9%]
		EnergyFire = 11458438415, -- EnergyVFX10, Grid8x8 realistic energy fire
		-- [clear, white, 2 parts, eff 39 smooth, fill 13%, 52/64 cells]
		SpikeInk = 17093828340, -- gravity FlashBlack: jagged spike silhouette [clear, white, 1 part, eff 110, fill 32%]
		Needle = 1053548563, -- jane Star1b: needle from the bottom edge to the centre, on BLACK (additive only)
		-- [BLACK card, white, 1 part, eff 263, fill 1%]
		Star = 14590086212, -- Star113: long thin cross [FAINT, white, 1 part, eff 354, fill 14%]
		StarInk = 17450657969, -- long thin 4-point star with no halo, for the black twin of the glints
		-- [clear, white, 1 part, eff 151, fill 6%]
		Lines = 16969300854, -- gravity "Sharp" LinesBG1/2, Grid4x4
		-- [clear, white, 2 parts, eff ~50, fill 10%, 9/16 cells]
		SoftRing = 8030746658, -- mochiFX "Gradient": soft ring with a bright rim
		-- [clear, white, 1 part, eff 136, fill 43%]
		SpinRing = 12402897209, -- jane Impact327: ring with inner rays [clear, white, 1 part, eff ~113, fill 37%]
		RayFan = 8905957078, -- skyrim LightRays: needle from the top edge to the centre
		-- [clear, white, 1 part, eff 456, fill 2%]
		Halo = 1084999891, -- skyrim Light: soft radial rays round a dark centre, on BLACK (additive only)
		-- [BLACK card, white, 5 parts, eff 99, fill 13%]
		Smoke = 8120749500, -- mochiFX / mochiHit smoke puff [clear, white, 1 part, eff 53, fill 53%]
		Wisp = 6910301489, -- mochiFX Wisps: off-centre dot (orbits when spun) [clear, white, 1 part, eff 65, fill 2%]
		Pin = 13712002093, -- gravity Specs: pin-prick dot [clear, white, 1 part, eff 373, fill <1%]
		Ripple = 13455499583, -- galaxy ImpactRipple: flat floor ripple ring
		-- [BLACK card, white, 6 parts, eff ~124, fill 8%]
		Glow = 867619398, -- head "Glow": big soft blob (texture-vocab: big soft glow)
		-- [clear, white, 1 part, eff 16 smooth, fill 58%]
	},
	layers = {
		------------------------------------------------------------------ flash + burst (t = 0: frame-1 pop)
		{ -- one-frame white ray flash (mochiHit Rays: life 0.1, 0 -> 7.2, opacity peak at 47% of life)
			id = "flash", kind = "emitter", t = 0, life = 0.05, at = { 0, 3, 0 },
			props = {
				Texture = "Rays", Color = "white", LightEmission = 1, Brightness = 3,
				Size = { { 0, 2 }, { 1, 10 } }, Transparency = { { 0, 0.5 }, { 0.47, 0.14 }, { 1, 1 } },
				Lifetime = 0.15, Speed = 0, Rotation = { 0, 360 }, ZOffset = 6,
			},
			emit = { { 0, 1 } },
		},
		{ -- gold-white bloom ball: near-black colour x Brightness 10, drag piles it up (lamp2 flare, 20 -> 12 particles)
			id = "bloom", kind = "emitter", t = 0, life = 0.05, at = { 0, 3, 0 },
			props = {
				Texture = "Flare", Color = "hotGold", LightEmission = 1, Brightness = 10,
				Size = { { 0, 0 }, { 0.5, 12 }, { 1, 0 } }, Squash = -0.25,
				Speed = { 2.8, 12 }, Drag = 16.8, SpreadAngle = 30, Lifetime = { 0.5, 0.9 },
				Transparency = 0, ZOffset = -0.01,
			},
			emit = { { 0, 12 } },
		},
		{ -- big soft gold glow behind everything: lamp2's halo layers (life 1, 6-14 studs, opacity peak ~50% at mid-life);
			-- a large sprite gets a low Brightness (vault: brightness by screen area)
			id = "glow", kind = "emitter", t = 0, life = 0.05, at = { 0, 3, 0 },
			props = {
				Texture = "Glow", Color = { { 0, "white" }, { 0.3, "gold" }, { 1, "amber" } }, LightEmission = 1, Brightness = 1.5,
				Size = { { 0, 5 }, { 0.45, 13 }, { 1, 10 } }, Transparency = { { 0, 0.6 }, { 0.45, 0.45 }, { 1, 1 } },
				Lifetime = 1, Speed = 0, ZOffset = -1,
			},
			emit = { { 0, 2 } },
		},
		{ -- white-hot flickering core: #13100D x Brightness 150 clips white with a warm fringe (lamp2 / head "fire")
			id = "core", kind = "emitter", t = 0, life = 0.05, at = { 0, 3, 0 },
			props = {
				Texture = "EnergyFire", FlipbookLayout = 8, FlipbookMode = "OneShot",
				Color = "hot", LightEmission = 1, Brightness = 150,
				Size = 3.5, Squash = -0.5, Speed = { 2, 16 }, Drag = 16.8, SpreadAngle = 30,
				Rotation = { 0, 360 }, RotSpeed = { -8.4, 8.4 }, Lifetime = { 0.36, 0.8 }, Transparency = 0, ZOffset = 0.01,
			},
			emit = { { 0, 12 } },
		},
		{ -- dark rim: same flipbook 1.2x bigger, BEHIND the core (lamp2 / head "fire black" size ratio 1.1x). Rendered
			-- black with jane's Br0 twin (LE0 Br0) rather than lamp2's LE -2 in the same ZOffset band: in the recapture
			-- that pair read as a dim orange-brown flicker with black patches, not a white core (misc.md d1, d2)
			id = "coreInk", kind = "emitter", t = 0, life = 0.05, at = { 0, 3, 0 },
			props = {
				Texture = "EnergyFire", FlipbookLayout = 8, FlipbookMode = "OneShot",
				Color = "hot", LightEmission = 0, Brightness = 0,
				Size = 4.2, Squash = -0.5, Speed = { 2, 16 }, Drag = 16.8, SpreadAngle = 30,
				Rotation = { 0, 360 }, RotSpeed = { -8.4, 8.4 }, Lifetime = { 0.36, 0.8 }, Transparency = 0, ZOffset = -0.5,
			},
			emit = { { 0, 12 } },
		},
		{ -- black spike crown behind the flash; ink outlives the flash ~1.5x (gravity Flash2 0.56 s vs Flash 0.36 s,
			-- FlashBlack texture). As a static crown its look is UNVERIFIED (gravity flies it inward)
			id = "inkCrown", kind = "emitter", t = 0, life = 0.05, at = { 0, 3, 0 },
			props = {
				Texture = "SpikeInk", Color = "ink", LightEmission = 0, Brightness = 1,
				Size = { { 0, 4 }, { 1, 9 } }, Transparency = { { 0, 0 }, { 0.7, 0.15 }, { 1, 1 } },
				Lifetime = 0.45, Speed = 0, Rotation = { 0, 360 }, ZOffset = -1,
			},
			emit = { { 0, 1 } },
		},
		{ -- light shafts from the centre, pulsed over 0.3 s (jane Star1b: VelocityParallel, Speed ~0, grow 0 -> 4.5)
			id = "rays", kind = "emitter", t = 0, life = 0.35, at = { 0, 3, 0 },
			props = {
				Texture = "Needle", Orientation = "VelocityParallel", Speed = 0.003, Drag = 2.25, SpreadAngle = 360,
				Color = { { 0, "white" }, { 0.4, "gold" }, { 1, "amber" } }, LightEmission = 1, Brightness = 3,
				Size = { { 0, 0 }, { 1, 12 } }, Transparency = { { 0, 0 }, { 0.5, 0.1 }, { 1, 1 } },
				Lifetime = { 0.4, 1.0 },
			},
			emit = { { 0, 16, 0.3 } },
		},
		{ -- white cross glints that shoot out and stop near R (jane Star113 values: Speed 60-120, Drag 15; stop ~1.44 v/Drag)
			id = "glints", kind = "emitter", t = 0, life = 0.05, at = { 0, 3, 0 },
			props = {
				Texture = "Star", Color = "white", LightEmission = 1, Brightness = 10,
				Size = 1.2, Speed = { 50, 90 }, Drag = 15, SpreadAngle = 360,
				Lifetime = { 0.1, 0.25 }, Transparency = 0, ZOffset = 3,
			},
			emit = { { 0, 12 } },
		},
		{ -- black twin of the glints: LightEmission 0 + Brightness 0 renders black whatever the colour (jane, 5 pairs)
			id = "glintInk", kind = "emitter", t = 0, life = 0.05, at = { 0, 3, 0 },
			props = {
				Texture = "StarInk", Color = "gold", LightEmission = 0, Brightness = 0,
				Size = 1.2, Speed = { 50, 90 }, Drag = 15, SpreadAngle = 360,
				Lifetime = { 0.1, 0.25 }, Transparency = 0, ZOffset = 2.9,
			},
			emit = { { 0, 8 } },
		},
		{ -- streak sparks: deep -> peach ramp, squash grows with age (gravity LinesBG1: 36-47 studs/s, Drag 6)
			id = "streaks", kind = "emitter", t = 0, life = 0.05, at = { 0, 3, 0 },
			props = {
				Texture = "Lines", FlipbookLayout = 4, FlipbookMode = "OneShot", Orientation = "VelocityParallel",
				Color = { { 0, "deep" }, { 1, "peach" } }, LightEmission = 1, Brightness = 12,
				Size = { { 0, 0 }, { 1, 1.9 } }, Squash = { { 0, 0 }, { 1, 0.8 } },
				Speed = { 36, 47 }, Drag = 6, SpreadAngle = 360, Lifetime = { 0.3, 0.4 }, Transparency = 0, ZOffset = 2,
			},
			emit = { { 0, 6 } },
		},
		{ -- black streaks among the bright ones, 4 vs 6 (gravity LinesBG2: colour black, LE -1)
			id = "streakInk", kind = "emitter", t = 0, life = 0.05, at = { 0, 3, 0 },
			props = {
				Texture = "Lines", FlipbookLayout = 4, FlipbookMode = "OneShot", Orientation = "VelocityParallel",
				Color = "ink", LightEmission = -1, Brightness = 1,
				Size = { { 0, 0 }, { 1, 1.9 } }, Squash = { { 0, 0 }, { 1, 0.8 } },
				Speed = { 36, 47 }, Drag = 6, SpreadAngle = 360, Lifetime = { 0.3, 0.4 }, Transparency = 0, ZOffset = 1.9,
			},
			emit = { { 0, 4 } },
		},
		{ -- flat soft gold ground ring, 2R wide in 0.4 s: mochiFX Gradient texture + life (1 particle, 0.4 s, constant
			-- 34-51% opacity), laid flat and sized like gravity's flat rings (~2R)
			id = "groundRing", kind = "emitter", t = 0, life = 0.05, at = { 0, 0.1, 0 },
			props = {
				Texture = "SoftRing", Orientation = "VelocityPerpendicular", EmissionDirection = "Top", Speed = 0.01,
				Color = "gold", LightEmission = 0.5, Brightness = 2,
				Size = { { 0, 0 }, { 1, 12 } }, Transparency = { { 0, 0.3 }, { 1, 1 } }, Lifetime = 0.4,
			},
			emit = { { 0, 1 } },
		},
		{ -- floor ripples readable from frame 1-3 (galaxy ImpactRipple: 3 @0, flat, LE1 Br15 on a dark purple colour,
			-- 0 -> 8.81 studs, life 0.5-2; seen at 0.10-0.55 s in the recapture). Gold here, so Brightness 3
			id = "ripples", kind = "emitter", t = 0, life = 0.05, at = { 0, 0.1, 0 },
			props = {
				Texture = "Ripple", Orientation = "VelocityPerpendicular", EmissionDirection = "Top", Speed = 0.002,
				Color = "gold", LightEmission = 1, Brightness = 3,
				Size = { { 0, 0 }, { 1, 12 } }, Transparency = { { 0, 0 }, { 1, 1 } }, Lifetime = { 0.5, 1.2 },
			},
			emit = { { 0, 3 } },
		},
		{ -- thin randomly tilted rings spinning at 1500-2000 deg/s round the core (jane Impact327)
			id = "spinRings", kind = "emitter", t = 0, life = 0.05, at = { 0, 3, 0 },
			props = {
				Texture = "SpinRing", Orientation = "VelocityPerpendicular", Speed = 0.002, SpreadAngle = 360,
				Color = "gold", LightEmission = 1, Brightness = 3,
				Size = { { 0, 0 }, { 1, 6 } }, Rotation = { 0, 360 }, RotSpeed = { 1500, 2000 },
				Transparency = { { 0, 1 }, { 0.32, 0 }, { 0.5, 0 }, { 1, 1 } }, Lifetime = { 0.17, 0.33 }, ZOffset = 1.4,
			},
			emit = { { 0, 2 } },
		},
		------------------------------------------------------------------ halo + rays (0.05 - 1.4)
		{ -- shimmering halo: many 25%-opacity copies, random rotation, slow spin (skyrim Light: Rate 20 = 20 over 0.9 s)
			id = "halo", kind = "emitter", t = 0.05, life = 0.95, at = { 0, 3, 0 },
			props = {
				Texture = "Halo", Color = "amber", LightEmission = 1, Brightness = 3,
				Size = { { 0, 8 }, { 1, 6 } }, Transparency = { { 0, 1 }, { 0.5, 0.75 }, { 1, 1 } },
				Lifetime = { 0.8, 1.4 }, Speed = 0, Rotation = { 0, 360 }, RotSpeed = { -15, 15 }, ZOffset = 0.99,
			},
			emit = { { 0, 20, 0.9 } },
		},
		{ -- slow sweeping light wedges: flat needles, each at a random tilt (SpreadAngle 360), opaque for 16% of life then
			-- fading (skyrim LightRays). Seen near edge-on they turn into big cones: drop this layer for low cameras
			id = "rayFan", kind = "emitter", t = 0.05, life = 0.05, at = { 0, 3, 0 },
			props = {
				Texture = "RayFan", Orientation = "VelocityPerpendicular", Speed = 0.014, Drag = 1, SpreadAngle = 360,
				Color = "amber", LightEmission = 1, Brightness = 1,
				Size = { { 0, 0 }, { 1, 6 } }, Squash = { { 0, 0 }, { 1, 0.475 } },
				Transparency = { { 0, 0 }, { 0.16, 0 }, { 1, 1 } }, Lifetime = 1.4,
				Rotation = { 0, 360 }, RotSpeed = { -35, 35 }, ZOffset = 0.5,
			},
			emit = { { 0, 3 } },
		},
		{ -- burst light (the lamp, head, galaxy and skyrim rigs carry one PointLight; values here are ours)
			id = "light", kind = "light", t = 0, life = 0.8, at = { 0, 3, 0 },
			props = { Color = "gold", Range = 20, Brightness = 0 },
			tracks = { Brightness = { { 0, 0 }, { 0.03, 3 }, { 0.8, 0, "quadOut" } } },
		},
		------------------------------------------------------------------ linger (0.03 - ~2.6)
		{ -- dark warm dust thrown out, stopped by drag and pulled down = a settling ring (mochiFX smoke: Speed 14-31,
			-- Drag 5, Acceleration -14.5; opacity raised from 0.02-0.05 to 0.2 because the original is near-invisible)
			id = "dust", kind = "emitter", t = 0.03, life = 0.05, at = { 0, 1, 0 },
			props = {
				Texture = "Smoke", Color = { { 0, "dust" }, { 1, "brown" } }, LightEmission = 0, Brightness = 1,
				Size = { { 0, 0 }, { 1, 6 } }, Transparency = { { 0, 0.8 }, { 1, 1 } },
				Speed = { 14, 31 }, Drag = 5, SpreadAngle = 360, Acceleration = { 0, -14.5, 0 },
				Rotation = { 0, 360 }, RotSpeed = { -200, 200 }, Lifetime = { 1.2, 1.8 }, ZOffset = -0.5,
			},
			emit = { { 0, 12 } },
		},
		{ -- gold motes spiralling inward as they rise: off-centre dot, Size 5 -> 0, RotSpeed +-385 (mochiFX Wisps)
			id = "motes", kind = "emitter", t = 0.1, life = 0.35, at = { 0, 3, 0 },
			props = {
				Texture = "Wisp", Color = { { 0, "gold" }, { 1, "ember" } }, LightEmission = 1, Brightness = 4,
				Size = { { 0, 5 }, { 1, 0 } }, Transparency = { { 0, 1 }, { 0.35, 0 }, { 1, 0 } },
				Speed = { 0, 18 }, Drag = 3, SpreadAngle = 360, Acceleration = { 0, 4, 0 },
				Rotation = { 0, 360 }, RotSpeed = { -385, 385 }, Lifetime = { 1.5, 2.5 }, ZOffset = 3.6,
			},
			emit = { { 0, 16, 0.3 } },
		},
		{ -- white specks rising in front of everything (gravity Specs: Speed 41-71, Drag 7, Acceleration +41, z 15.7)
			id = "specks", kind = "emitter", t = 0, life = 0.05, at = { 0, 3, 0 },
			props = {
				Texture = "Pin", Color = { { 0, "white" }, { 1, "gold" } }, LightEmission = 1, Brightness = 10,
				Size = { { 0, 4 }, { 1, 0 } }, Speed = { 25, 45 }, Drag = 7, SpreadAngle = 360,
				Acceleration = { 0, 25, 0 }, Lifetime = { 0.5, 1.4 }, Transparency = 0, ZOffset = 8,
			},
			emit = { { 0, 20 } },
		},
	},
}
