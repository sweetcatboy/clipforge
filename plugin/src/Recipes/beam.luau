-- ClipForge base recipe "beam": from vfxmith (github.com/Frxctured/roblox-vfxmith), knowledge/categories/beam_recipe.luau,
-- MIT License, Copyright (c) 2026 Frxctured (see THIRD_PARTY_NOTICES). Texture ids are public Roblox images owned by
-- their uploaders; their terms apply. Recoloured, retimed and rescaled at play time by ClipForge's FX module.
-- ArcLance: one generic beam / laser effect for VFXTimeline, built from the 7 open-source effects studied in beam.md
-- (same folder). UNTESTED draft: valid Luau, not yet played in Studio. Values come from the anatomy table in beam.md
-- section b; each layer names the effect(s) it was learned from:
--   proto = f4248717e073 (Prototype 2 laser)   yav = 79af1f3a498d (Yaversu kick drill)   zolt = d6a216ec5995 (Zoltraak)
--   blue = b72098bc93a1 (Blue Beam charge)     jewel = f7c71691a378 (Light Sacred Jewel Dash)
--   purple = ad89e82f9154 (purple TestingPart hit)   bloody = ebf853272c64 (bloody orbs)
-- Shape: the laser fires along +X from the muzzle at {0, 3, 0} to the hit point at {36, 3, 0}: L = 36 studs, body width
-- W = 7.5 (0.21 L; zolt barrel 0.19 L, proto 0.22-0.3 L).
-- v2 tuning pass (first Studio capture: charge a tiny dot, beam thin and fading before the hit, no clear impact): half
-- steps toward the anatomy table on charge size/count, body width/density, core width, hit sizes; the sigil now forms in
-- the charge; body, core and ink stay visible to the hit; the hit re-pulses through the hold. Marked "v2" per layer. With the capture camera on -Z looking +Z the beam is seen side-on
-- (beam.md e: end-on views hide beam structure).
-- Phases (beam.md c): charge 0-0.3 | fire flash 0.30-0.38 | beam on 0.32 (+0.02, hitscan) | hold to ~0.95 | width/fade
-- out 0.95-1.27 | hit at 0.32 | linger smoke to ~2.6 s.
-- Three tones: white core (coreBeam, muzzleFlash, hitFlash, hitSparks start), saturated pink-violet body (bodyBeam,
-- cage, rings, streaks, specks, sigil), dark ink (inkBeam, cageInk, hitInk, smoke).
-- Deliberate departures from the evidence (beam.md e): a white core line (none of the 7 has a dedicated white layer;
-- proto reaches white only where pink additive layers overlap, so its core value changes with the view), body fade along the
-- length softened (0.82 instead of 0.91 at mid-length) so a 36-stud beam still reaches its hit, cage ribbons kept
-- FaceCamera = true (the runtime does not expose the ribbon plane; proto used false), ink as black at LE 0 instead of
-- negative LightEmission, particle counts cut to roughly a third of proto / zolt.
-- World-space caveat: streamSpecks uses Acceleration along +X (proto technique 10). If the effect origin is rotated,
-- set that Acceleration from the aim direction in code.
-- Texture traits pass (2026-11-14, kit/scripts/texture_traits.py): Sigil 75751709312199 (zolt's rune circle is a
-- DARK BLUE 16:9 card: tinted it turns blue / olive, and it is stretched on a square particle) -> 135141028133816
-- (white rune circle, square, clear, effective resolution 458 px); the sigil layer's Brightness 10 -> 5 for it.
-- SpikyStar 16892226410 (Impact13 is a 128 px image: blurry at hitFlash's Size 10) -> 17296456452 (radial spike burst
-- round a hollow centre like Impact13, 1024 px). Other layer values unchanged.
return {
	name = "ArcLance",
	scale = 1,
	palette = {
		white = "#FFF4FF",
		lilac = "#D7B5FF",
		pink = "#FF297B", -- proto cage "pink"
		magenta = "#E081FF", -- proto Wind1 / Wind5
		violet = "#9B7DFF", -- proto ray / Wind1
		deep = "#38206C", -- proto cage "violet" (LE 0)
		inkViolet = "#2A2044", -- proto Beam7 ink beam
		sigilDark = "#3A1F59", -- zolt Sigil is #252F59: dark colour x Brightness, hue by ratio (beam.md d14)
		sparkDark = "#4A3A78", -- zolt SparksLinger #364862 Br35: dark colour x high Brightness
		smoke = "#3A2466",
		ink = "#000000",
	},
	textures = {
		-- [..] at the end of a texture comment = measured traits (gallery/textures/traits.json, legend in kit/scripts/texture_traits.py)
		ThinRing = 7394759196, -- zolt "2.5": thin ring with gaps [clear, white, 2 parts, eff 125, fill 7%]
		WaveLine = 13801691431, -- blue / yav "BeamWave": spiky white waveform
		-- [clear, white, 1 part, eff ~137, fill 44%]
		DustyImpact = 10198439352, -- zolt "HIT EFFECTS 2": Grid4x4 spiky burst
		-- [clear, white, 2 parts, eff 96, fill 5%, 14/16 cells]
		Sigil = 135141028133816, -- white rune circle (beam.md row 5 sigil list); was zolt's 75751709312199, a dark-blue card
		-- [clear, white, 2 parts, eff 458, fill 26%]
		SoftBar = 16892386886, -- proto Beam7 "Real2": soft-edged white band along the beam
		-- [FAINT, white, 1 part, eff 44 smooth, fill 91%]
		SmokeNoise = 15824130839, -- proto "Beam": wavy smoke-noise lines on BLACK (additive only)
		-- [BLACK card, white, 1 part, eff ~163, fill 58%]
		WavyLine = 12713360567, -- yav "BeamAura": one sinuous white line [clear, white, 1 part, eff 99, fill 39%]
		ToonStreak = 10240434007, -- yav "Beam101" / "BeamDrag smoke": hard-edged toon blob streak
		-- [clear, white, 2 parts, eff 170, fill 19%]
		Streaks8 = 131290109763904, -- zolt "IMG_9350": Grid8x8 streak flipbook
		-- [clear, grey, 1 part, eff ~23 smooth, fill 10%, 50/64 cells]
		Spec37 = 16879834064, -- proto "Spec37" (look not checked on a contact sheet)
		-- [clear, white, 1 part, eff 117, fill 6%]
		TwoArcRing = 15269685466, -- zolt "decay16": two-arc ring [clear, black+white, 3 parts, eff 137, fill 6%]
		Disc = 7922645282, -- zolt "SparksLinger": solid white disc [clear, white, 1 part, eff 115, fill 8%]
		SpikyStar = 17296456452, -- radial spike burst, hollow centre; was bloody / yav "Impact13" 16892226410 (128 px)
		-- [clear, white, 1 part, eff 247, fill 32%]
		FuzzyRing = 133650067075481, -- zolt "shock": fuzzy radial ring [clear, white, 1 part, eff 78, fill 17%]
		JaggedBurst = 127136593142768, -- zolt impact ink: jagged starburst [clear, white, 10 parts, eff 79, fill 14%]
		Sparkle4 = 14006783533, -- yav "Star" / "Flash": fat concave 4-point sparkle
		-- [clear, white, 1 part, eff 564, fill 8%]
		ToonPuff = 138231890129613, -- zolt "smh": toon puff with dark speckles, Grid4x4
		-- [clear, white, 1 part, eff 43 smooth, fill 26%, 12/16 cells]
	},
	layers = {
		------------------------------------------------------------------ charge (0 - 0.3)
		{ -- rings tightening onto the muzzle, flat round the beam axis (proto Swirls29 shrink 42.7 -> 2.85 out-expo,
			-- RotSpeed -1000..-500; zolt "2.5" ring texture)
			id = "chargeRings", kind = "emitter", t = 0, life = 0.28, at = { 0, 3, 0 },
			props = {
				-- v2 (half steps toward proto: Br 5, peak 2 W, life 0.25-0.67, Rate 12 x 4 tones)
				Texture = "ThinRing", Color = "lilac", LightEmission = 1, Brightness = 3.5,
				Orientation = "VelocityPerpendicular", EmissionDirection = "Right", Speed = 0.005,
				Size = { { 0, 12.5, 2.5 }, { 0.1, 7 }, { 0.2, 3.9 }, { 0.4, 1.5 }, { 1, 0.8 } },
				Transparency = { { 0, 0.1 }, { 0.5, 0.6 }, { 1, 1 } },
				Lifetime = { 0.25, 0.45 }, Rotation = { 0, 360 }, RotSpeed = { -1000, -500 },
			},
			emit = { { 0, 10, 0.24 } },
		},
		{ -- 2-frame electric streaks round the muzzle (blue BeamWave / Beam97 / Spec48: life 0.03, Squash 0 -> 3,
			-- Speed 13-65, LE 0 Br 5-20, Rate 50 per layer)
			-- v2: Size 1.3 was for a 0.45-scale avatar (= 2.9 at full scale), half step to 2.2; ~250/s (blue: 350/s)
			id = "chargeCrackle", kind = "emitter", t = 0, life = 0.3, at = { 0, 3, 0 }, box = { 3.5, 3.5, 3.5 },
			props = {
				Texture = "WaveLine", Color = "white", LightEmission = 0, Brightness = 10, Shape = "Box",
				Orientation = "VelocityParallel", EmissionDirection = "Top", Speed = { 13, 65 },
				Size = { { 0, 2.2 }, { 1, 0 } }, Squash = { { 0, 0 }, { 1, 3 } },
				Lifetime = 0.03, Transparency = 0, ZOffset = 1,
			},
			emit = { { 0, 70, 0.28 } },
		},
		------------------------------------------------------------------ fire (0.30)
		{ -- white flash at the muzzle, 4-7 frames (zolt HIT EFFECTS 2: Grid4x4 OneShot, shrink to 0, life 0.06-0.12,
			-- LE 1, ZOffset 7; bloody Spec19 1-frame flash). Peak 14 studs = 2.3 W (evidence 5-10 W: cut, beam.md e)
			id = "muzzleFlash", kind = "emitter", t = 0.3, life = 0.05, at = { 0.5, 3, 0 },
			props = {
				Texture = "DustyImpact", FlipbookLayout = 4, FlipbookMode = "OneShot", Color = "white",
				LightEmission = 1, Brightness = 4, Speed = 0,
				Size = { { 0, 14 }, { 0.5, 4, 2 }, { 1, 0 } }, Transparency = 0,
				Lifetime = { 0.06, 0.12 }, Rotation = { 0, 360 }, ZOffset = 3,
			},
			emit = { { 0, 3 } },
		},
		{ -- 1-2 frame smear streaks along the shot (yav BeamWave / Impact27: life 0.03-0.05, VelocityParallel,
			-- Squash 0 -> 1.57, Size 0 -> 10.7, Speed 45-123, LE 0 Br 6)
			id = "smear", kind = "emitter", t = 0.3, life = 0.05, at = { 0.5, 3, 0 },
			props = {
				Texture = "WaveLine", Color = "magenta", LightEmission = 0, Brightness = 6,
				Orientation = "VelocityParallel", EmissionDirection = "Right", Speed = { 45, 120 }, SpreadAngle = { 8, 8 },
				Size = { { 0, 0 }, { 1, 9 } }, Squash = { { 0, 0 }, { 1, 1.5 } },
				Lifetime = { 0.03, 0.05 }, Transparency = 0, ZOffset = 2,
			},
			emit = { { 0, 4 } },
		},
		{ -- rune circle standing round the muzzle, facing down the beam (zolt Sigil: const 10 studs = 1.4 barrel W,
			-- LE 1 Br 5, life 1.17; proto pentagon: hidden until 0.28 of life, RotSpeed -500..-250). Recapture 2026-11-14:
			-- the zolt sigil fades in from 0.20 s after the fire and is full 0.35-0.80 s. v2: starts in the charge (proto's
			-- muzzle sigils run from t 0, Rate 2) so the charge reads; forms over 0.26 s, full at the fire, Br 6 -> 10
			-- (half step toward proto pentagon Br 15) because Br 6 read as a dark disc in the first capture.
			-- Traits pass: white texture now, so Br 10 -> 5 (zolt's own Br 5). The old dark-blue texture passed only
			-- (0.17, 0.26, 0.34) of sigilDark x 10 = a dim blue disc; on white, d14 (dark colour x Brightness) gives
			-- the palette's violet at about the old peak intensity
			id = "sigil", kind = "emitter", t = 0.05, life = 0.05, at = { 0.3, 3, 0 },
			props = {
				Texture = "Sigil", Color = "sigilDark", LightEmission = 1, Brightness = 5,
				Orientation = "VelocityPerpendicular", EmissionDirection = "Right", Speed = 0.02,
				Size = 8, Transparency = { { 0, 1 }, { 0.12, 0.5 }, { 0.2, 0 }, { 0.75, 0.1 }, { 1, 1 } },
				Lifetime = 1.3, Rotation = { 0, 360 }, RotSpeed = { 60, 90 }, ZOffset = 0.5,
			},
			emit = { { 0, 2 } },
		},
		------------------------------------------------------------------ beam (0.32 - 1.27)
		{ -- dark ink band behind the glow (proto Beam7: SoftBar, #2A2044, LE 0, ZOffset 1, width 0.64-0.88 of the body;
			-- denser than proto's 0.68 because it is the only dark beam here)
			id = "inkBeam", kind = "beam", t = 0.32, life = 0.95, a = { 0, 3, 0 }, b = { 36, 3, 0 },
			props = {
				Texture = "SoftBar", Color = "inkViolet", LightEmission = 0, Brightness = 1,
				-- v2: width follows the wider body (0.75 W); stays visible to the hit (0.8 at the far end, was 1)
				Width0 = 5.6, Width1 = 5.6, TextureSpeed = 5, TextureMode = "Stretch", TextureLength = 1, ZOffset = 0,
				Transparency = { { 0, 0.35 }, { 0.85, 0.5 }, { 1, 0.8 } },
			},
			tracks = {
				-- yav Width0 15 -> 4 out-cubic: snap wide, then tighten
				Width = { { 0, 0.3 }, { 0.04, 1.6, "quadOut" }, { 0.3, 1, "cubicOut" }, { 0.75, 1 }, { 0.95, 0, "quadIn" } },
				Fade = { { 0.75, 0 }, { 0.95, 1 } },
			},
		},
		{ -- saturated hazy body that fades along its length (proto "Beam": SmokeNoise, LE 1, Br 14, Transparency
			-- 0.64 -> 0.71 @0.16 -> 0.91 @0.5 -> 1, TextureSpeed 2.6, FaceCamera); white for the first frames (PATTERNS 2)
			id = "bodyBeam", kind = "beam", t = 0.32, life = 0.95, a = { 0, 3, 0 }, b = { 36, 3, 0 },
			props = {
				-- v2: W 6 -> 7.5 (half step toward 0.22-0.3 L), Br 12 -> 13 (proto 14), denser and reaching the hit: proto
				-- stacks 4 haze + 3 line beams for its density, we have one haze beam
				Texture = "SmokeNoise", Color = "pink", LightEmission = 1, Brightness = 13,
				Width0 = 7.5, Width1 = 7.5, TextureSpeed = 2.6, TextureMode = "Stretch", TextureLength = 1, ZOffset = 0.5,
				Transparency = { { 0, 0.45 }, { 0.16, 0.5 }, { 0.5, 0.6 }, { 0.9, 0.7 }, { 1, 0.85 } },
			},
			tracks = {
				Width = { { 0, 0.3 }, { 0.03, 1.8, "quadOut" }, { 0.3, 1, "cubicOut" }, { 0.75, 1 }, { 0.95, 0, "quadIn" } },
				Color = { { 0, "white" }, { 0.05, "pink", "quadOut" } },
				Fade = { { 0.8, 0 }, { 0.95, 1 } },
			},
		},
		{ -- thin white core line (our addition, beam.md e: no dedicated white layer in 6 of 7). SoftBar texture as proto Beam7,
			-- dies 0.1 s before the body
			id = "coreBeam", kind = "beam", t = 0.32, life = 0.85, a = { 0, 3, 0 }, b = { 36, 3, 0 },
			props = {
				-- v2: 1.6 -> 2.4 wide (half step toward proto line beams, 0.64 W), Br 3 -> 4, solid to the hit point
				Texture = "SoftBar", Color = "white", LightEmission = 1, Brightness = 4,
				Width0 = 2.4, Width1 = 2.4, TextureSpeed = 5, TextureMode = "Stretch", TextureLength = 1, ZOffset = 1,
				Transparency = { { 0, 0 }, { 0.9, 0.1 }, { 1, 0.5 } },
			},
			tracks = {
				Width = { { 0, 0.5 }, { 0.03, 1.4, "quadOut" }, { 0.2, 1, "cubicOut" }, { 0.7, 1 }, { 0.85, 0, "quadIn" } },
			},
		},
		{ -- bowed ribbons rolled round the beam (proto cage: CurveSize0 +k / CurveSize1 -k bows out 0.75 k, width ~0.5 W,
			-- pink LE 1 Br 7; texture from yav BeamAura). k = 3 -> 2.25-stud bulge = 0.75 of the body radius.
			-- Positive TextureSpeed: a = muzzle, so the texture flows away from the muzzle (proto built far-end-first: -4)
			id = "cage", kind = "beam", t = 0.33, life = 0.75, at = { 0, 3, 0 }, a = { 0, 0, 0 }, b = { 36, 0, 0 },
			axis = { 0, 1, 0 },
			copies = { n = 4, jitter = 0.04, rotSpread = { 180, 0, 0 } },
			props = {
				Texture = "WavyLine", Color = "violet", LightEmission = 1, Brightness = 4,
				Width0 = 3, Width1 = 3.5, CurveSize0 = 3.5, CurveSize1 = -3.5, Segments = 20, -- v2: scaled with W 7.5
				TextureSpeed = 4, TextureMode = "Stretch", TextureLength = 1, ZOffset = 0.8,
				-- yav BeamAura along-beam shape: soft ends, densest near the first quarter
				Transparency = { { 0, 1 }, { 0.12, 0.3 }, { 0.3, 0.2 }, { 0.75, 0.45 }, { 1, 1 } },
			},
			tracks = {
				Width = { { 0, 0 }, { 0.06, 1, "quadOut" }, { 0.55, 1 }, { 0.75, 0, "quadIn" } },
			},
		},
		{ -- dark ribbons in the cage, 1.1-1.25x wider than the bright ones (proto black / violet LE 0, TextureSpeed -5;
			-- texture from yav Beam101). ZOffset between body and core so the ink reads over the glow (sorting unverified)
			id = "cageInk", kind = "beam", t = 0.34, life = 0.7, at = { 0, 3, 0 }, a = { 0, 0, 0 }, b = { 36, 0, 0 },
			axis = { 0, 1, 0 },
			copies = { n = 3, jitter = 0.04, rotSpread = { 180, 0, 0 } },
			props = {
				Texture = "ToonStreak", Color = "ink", LightEmission = 0, Brightness = 1,
				Width0 = 3.5, Width1 = 4, CurveSize0 = 3, CurveSize1 = -3, Segments = 20, -- v2: scaled with W 7.5
				TextureSpeed = 5, TextureMode = "Stretch", TextureLength = 1, ZOffset = 0.7,
				Transparency = { { 0, 1 }, { 0.15, 0.2 }, { 0.7, 0.4 }, { 1, 1 } },
			},
			tracks = {
				Width = { { 0, 0 }, { 0.06, 1, "quadOut" }, { 0.5, 1 }, { 0.7, 0, "quadIn" } },
			},
		},
		{ -- streaks flying along the body inside a box the length of the beam (zolt barrel: EmissionDirection along the
			-- shot, VelocityParallel, Speed 8.6-257 Drag 5.1, Size 10 -> 25 scaled 0.3, Squash 0 -> 0.5 -> 0.6, Rotation
			-- fixed -90, Grid8x8 OneShot, dark colour x Br 15 additive)
			id = "bodyStreaks", kind = "emitter", t = 0.32, life = 0.6, at = { 18, 3, 0 }, box = { 36, 1.2, 1.2 },
			props = {
				Texture = "Streaks8", FlipbookLayout = 8, FlipbookMode = "OneShot", Color = "deep",
				LightEmission = 1, Brightness = 15, Shape = "Box", -- v2: Br 10 -> 15 (zolt 5-25)
				Orientation = "VelocityParallel", EmissionDirection = "Right", Speed = { 10, 90 }, Drag = 5,
				Size = { { 0, 3, 0.7 }, { 0.5, 6, 0.7 }, { 1, 7.5 } },
				Squash = { { 0, 0, 0.2 }, { 0.5, 0.5, 0.2 }, { 1, 0.6 } },
				Transparency = { { 0, 0 }, { 0.5, 0.46 }, { 1, 1 } },
				Lifetime = { 0.35, 0.85 }, Rotation = { -90, -90 }, ZOffset = 1.2,
			},
			emit = { { 0, 18 }, { 0.25, 12 }, { 0.5, 9 } }, -- v2: half step toward zolt 15-25 per layer x 4 layers
		},
		{ -- specks bent into streams down the beam (proto Spec37: Speed 100-120 halved, SpreadAngle 100, Drag 14,
			-- Acceleration along the axis 1000 halved, hidden until 0.31 of life, Size 7.17 -> 0 with envelope = peak,
			-- Squash 0.2, Rotation 90, LE 0.87 Br 2; EmitCount 35 + Rate 100 cut to bursts)
			id = "streamSpecks", kind = "emitter", t = 0.32, life = 0.65, at = { 0.5, 3, 0 },
			props = {
				Texture = "Spec37", Color = "pink", LightEmission = 0.87, Brightness = 2,
				Orientation = "VelocityParallel", EmissionDirection = "Right", Speed = { 50, 60 },
				SpreadAngle = { 100, 100 }, Drag = 14, Acceleration = { 500, 0, 0 },
				Size = { { 0, 3.5, 3.5 }, { 1, 0 } }, Squash = 0.2, Rotation = { 90, 90 },
				Transparency = { { 0, 1 }, { 0.3, 1 }, { 0.36, 0 }, { 0.84, 0 }, { 1, 1 } },
				Lifetime = { 0.3, 0.6 }, ZOffset = 1.5,
			},
			emit = { { 0, 14 }, { 0.2, 12 }, { 0.4, 12 }, { 0.6, 8 } },
		},
		{ -- rings running down the axis and widening into a wake (proto Wind1: Speed 19-31 along the axis, SpreadAngle 24,
			-- out-expo 0 -> 24 = 1.2 W scaled to 1 W, Transparency 0 -> 0.875 @0.46 -> 1, RotSpeed -1000..-500, Rate 12;
			-- zolt decay16 ring texture)
			id = "travelRings", kind = "emitter", t = 0.32, life = 0.7, at = { 0.5, 3, 0 },
			props = {
				Texture = "TwoArcRing", Color = "lilac", LightEmission = 1, Brightness = 2,
				Orientation = "VelocityPerpendicular", EmissionDirection = "Right", Speed = { 20, 30 }, SpreadAngle = { 24, 24 },
				Size = { { 0, 0 }, { 0.1, 2.5, 1.5 }, { 0.2, 4.1, 2 }, { 0.3, 5, 2.5 }, { 0.5, 5.8, 3 }, { 1, 6, 3 } },
				Transparency = { { 0, 0 }, { 0.46, 0.87 }, { 1, 1 } },
				Lifetime = { 0.25, 0.6 }, Rotation = { 0, 360 }, RotSpeed = { -1000, -500 }, ZOffset = 0.5,
			},
			emit = { { 0, 3 }, { 0.12, 3 }, { 0.24, 3 }, { 0.36, 3 }, { 0.48, 3 }, { 0.6, 3 } },
		},
		{ -- sparks thrown forward from the muzzle (zolt SparksLinger: Speed 20-142, spread 45, Drag 5.15, life 0.58-1.75,
			-- swell 0 -> 0.61 @0.4 -> 0, RotSpeed +-343, dark colour x Br 35; jewel Squash 0 -> 0.554 for streaks)
			id = "muzzleSparks", kind = "emitter", t = 0.3, life = 0.05, at = { 0.5, 3, 0 },
			props = {
				Texture = "Disc", Color = "sparkDark", LightEmission = 1, Brightness = 12,
				Orientation = "VelocityParallel", EmissionDirection = "Right", Speed = { 20, 110 }, SpreadAngle = { 45, 45 },
				Drag = 5, Size = { { 0, 0 }, { 0.4, 0.5, 0.2 }, { 1, 0 } }, Squash = { { 0, 0 }, { 1, 0.55 } },
				Transparency = 0, Lifetime = { 0.5, 1.2 }, RotSpeed = { -343, 343 }, ZOffset = 2,
			},
			emit = { { 0, 25 } },
		},
		------------------------------------------------------------------ hit (0.32, hitscan: muzzle + 0.02)
		{ -- white spiky star at the hit point, re-pulsing once during the hold (bloody Impact13: LE 1 Br 1-3,
			-- grow 0 -> 12.7, life 0.07-0.1, 3 at once)
			-- v2: peak 7 -> 10 (half step toward 12.7), life toward the 0.25 s bloody copy, re-pulses through the hold so
			-- the hit stays readable while the beam is on (proto feeds its specks for the whole beam)
			id = "hitFlash", kind = "emitter", t = 0.32, life = 0.6, at = { 36, 3, 0 },
			props = {
				Texture = "SpikyStar", Color = "white", LightEmission = 1, Brightness = 4, Speed = 0,
				Size = { { 0, 0 }, { 1, 10 } }, Transparency = 0, Lifetime = { 0.08, 0.18 }, Rotation = { 0, 360 },
				ZOffset = 2,
			},
			emit = { { 0, 3 }, { 0.15, 2 }, { 0.35, 2 }, { 0.55, 2 } },
		},
		{ -- flat rings at random 3D tilts (zolt shock / decay16: VelocityPerpendicular + Speed ~0.003 + SpreadAngle 360,
			-- grow 0 -> 26.7 scaled, Transparency 0.38, life 0.1-0.2)
			-- v2: peak 8 -> 13 (half step toward zolt 21-30 = 3-4 barrel W), life 0.15-0.35 (zolt 0.07-0.74)
			id = "hitRings", kind = "emitter", t = 0.32, life = 0.55, at = { 36, 3, 0 },
			props = {
				Texture = "FuzzyRing", Color = "lilac", LightEmission = 1, Brightness = 3,
				Orientation = "VelocityPerpendicular", Speed = { 0.002, 0.005 }, SpreadAngle = { 360, 360 },
				Size = { { 0, 0 }, { 1, 13 } }, Transparency = { { 0, 0.38 }, { 0.7, 0.5 }, { 1, 1 } },
				Lifetime = { 0.15, 0.35 }, Rotation = { 0, 360 }, RotSpeed = { -77, 77 }, ZOffset = 1.5,
			},
			emit = { { 0, 4 }, { 0.25, 2 }, { 0.5, 2 } },
		},
		{ -- dark jagged splat over the flash for ~5 frames (zolt 127136593142768: shrink 11.6 -> 0, life 0.083, random
			-- 3D tilt; source used LE -1 Br 50, we use black at LE 0 to stay in the documented range)
			id = "hitInk", kind = "emitter", t = 0.33, life = 0.05, at = { 36, 3, 0 },
			props = {
				Texture = "JaggedBurst", Color = "ink", LightEmission = 0, Brightness = 1,
				Orientation = "VelocityPerpendicular", Speed = 0.002, SpreadAngle = { 360, 360 },
				Size = { { 0, 8 }, { 1, 0 } }, Transparency = 0, Lifetime = 0.09, Rotation = { 0, 360 }, ZOffset = 2.5, -- v2: 6 -> 8
			},
			emit = { { 0, 3 } },
		},
		{ -- stars that pop out and stop dead, splashing back toward the muzzle (purple Star131: Speed 492-985 halved,
			-- Drag 76 -> 60, life 0.15-0.35, shrink to 0, Squash swell 0.11 -> 0.98 @0.29 -> -0.25, LE 0 + Brightness)
			id = "hitSparks", kind = "emitter", t = 0.32, life = 0.55, at = { 36, 3, 0 },
			props = {
				Texture = "Sparkle4", Color = { { 0, "white" }, { 0.3, "pink" } }, LightEmission = 0, Brightness = 8,
				EmissionDirection = "Left", Speed = { 250, 500 }, SpreadAngle = { 70, 70 }, Drag = 60,
				Size = { { 0, 3.5 }, { 1, 0 } }, Squash = { { 0, 0.11 }, { 0.29, 0.98 }, { 1, -0.25 } },
				Transparency = 0, Lifetime = { 0.15, 0.35 }, Rotation = { 0, 360 }, ZOffset = 2,
			},
			emit = { { 0, 10 }, { 0.25, 5 }, { 0.5, 5 } }, -- v2: size 2.5 -> 3.5 (purple 6.15), fed through the hold
		},
		------------------------------------------------------------------ linger (to ~2.6 s)
		{ -- dark violet toon smoke from the hit point (zolt smh: life 1.79-3.35 cut to 1.2-2.2, grow 0 -> 6.7, Speed
			-- 22-64 Drag 9.25, Grid4x4 OneShot, LE 0; start transparency 0.5 instead of 0.9, beam.md e "near-invisible")
			id = "smoke", kind = "emitter", t = 0.36, life = 0.45, at = { 36, 3, 0 },
			props = {
				Texture = "ToonPuff", FlipbookLayout = 4, FlipbookMode = "OneShot",
				Color = { { 0, "smoke" }, { 1, "#1A1030" } }, LightEmission = 0, Brightness = 1,
				EmissionDirection = "Left", Speed = { 6, 20 }, SpreadAngle = { 180, 180 }, Drag = 9,
				Size = { { 0, 1 }, { 1, 5 } }, Transparency = { { 0, 0.5 }, { 0.6, 0.7 }, { 1, 1 } },
				Lifetime = { 1.2, 2.2 }, Rotation = { 0, 360 }, RotSpeed = { -30, 30 },
			},
			emit = { { 0, 6 }, { 0.4, 4 } },
		},
		{ -- one light on the beam (bloody: PointLight Brightness 2.5 -> 0 over 0.6 s, impact Range up to 40)
			-- v2: mid-beam, Range 18 -> 26 and peak 2.5 -> 4 (half steps toward the impact light: Br 9, Range 40)
			id = "light", kind = "light", t = 0.3, life = 1.0, at = { 18, 3, 0 },
			props = { Color = "magenta", Range = 26, Brightness = 0 },
			tracks = { Brightness = { { 0, 0 }, { 0.02, 4 }, { 0.65, 2 }, { 1.0, 0, "quadOut" } } },
		},
	},
}
