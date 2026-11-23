-- ClipForge base recipe "darkportal": from vfxmith (github.com/Frxctured/roblox-vfxmith), knowledge/categories/darkportal_recipe.luau,
-- MIT License, Copyright (c) 2026 Frxctured (see THIRD_PARTY_NOTICES). Texture ids are public Roblox images owned by
-- their uploaders; their terms apply. Recoloured, retimed and rescaled at play time by ClipForge's FX module.
-- VoidBreach: one generic dark / void / portal burst for VFXTimeline, built from the 6 open-source effects studied in
-- darkportal.md (same folder). UNTESTED draft: valid Luau, not yet played in Studio.
-- Values come from the anatomy table (darkportal.md section b); the source effect is named on every layer:
--   voidstorm = a449104719e7 (VoidStorm debris cloud)   doom = 55f32e520bc4 (DoomSlayer Bonus/4 hell-strike)
--   collab = e73b7ea4943e (Collab FX violet slash)      crucible = 941b0d77b160 (DoomSlayer Crucible sword)
--   voidflare = 80d86b0489f6 (Voidflare Dive/Jump)      tatsumaki = 783fb2166dc6 (tatsumakirip psychic burst)
-- Shape: R = 8 studs (body radius). Body centre 4 studs up; ground layers at y 0.1. The portal plane faces -Z
-- (EmissionDirection "Front" = toward the default capture camera); set those layers to "Top" for a ground domain.
-- Phases: flash 0-0.15 | ink punch 0.05-0.2 | body in three waves 0 / 0.1 / 0.2, peak 0.05-0.35 | rings 0.15-1.2 |
-- smoke + void fog 0.3-2.4 | ground ink to ~3.3 s.
-- Three tones: white core (flash, needles, swirl, crackle), saturated violet body (star, slash, orbs, embers,
-- glowCrack, rings at birth), dark ink (inkCore, inkShock, darkCrescents, needleInk, blackSmoke, voidFog, scorch).
-- Deliberate departures from the evidence (darkportal.md section e): flash Br 15 instead of doom's 600, embers 40
-- instead of 150, one smoke emitter instead of ten, the big ring at Transparency 0.9 instead of 0.97.
-- Ids marked (nt) have no thumbnail in our texture index: check them in Studio first.
-- Checked against the 2026-11-14 recapture: no layer value changed. Not added: the dome forms the recapture shows
-- (Collab's Neon arc meshes, tatsumaki's rim card; darkportal.md techniques 30-31), because their sources are meshes or
-- an unidentified layer.
return {
	name = "VoidBreach",
	palette = {
		white = "#FFFFFF",
		lilac = "#C8B4FF",
		violet = "#6830FF", -- collab body colour (slash, orbs, beams)
		glow = "#713DFF", -- collab GlowCrack
		deepViolet = "#3A1E8C",
		dip = "#120830", -- near-black mid-life key: additive layers go out and re-ignite (doom #180701)
		cloud = "#231E35", -- voidstorm negative-LE cloud ramp
		cloudMid = "#323554",
		cloudEnd = "#393C5D",
		ringWhite = "#F1FEFF", -- voidflare ring ramp
		ringGrey = "#889090",
		nearBlack = "#121212",
		ink = "#000000",
	},
	textures = {
		-- [..] at the end of a texture comment = measured traits (gallery/textures/traits.json, legend in kit/scripts/texture_traits.py)
		QuickFlash = 12118255430, -- doom "6": soft white burst (QuickFLash) [clear, white, 1 part, eff 115, fill 22%]
		ImpactStar = 10357935135, -- collab "impact": spiky white starburst [clear, white, 3 parts, eff 62, fill 30%]
		InkDisc = 102977909637329, -- tatsumaki ink disc (nt), used at Brightness 0
		-- [clear, white, 1 part, eff ~80, fill 43%]
		BlackShock = 16509144751, -- doom ground shock flipbook, Grid4x4 (ImpactExplod)
		-- [FAINT, white, 6 parts, eff 84, fill 14%, 11/16 cells]
		Slash = 78371370584447, -- collab slash card, Grid4x4 (nt) [clear, white, 1 part, eff ~63, fill 8%]
		ToonCrescents = 14973797453, -- collab "wind": four bold toon crescents, Grid2x2
		-- [clear, white, 1 part, eff 227, fill 10%]
		SpinSwirl = 14850595833, -- collab "cres" / doom "FinalWindTest": swirl ring
		-- [clear, white, 4 parts, eff 122, fill 6%]
		WindRing = 17848865880, -- voidflare spiky flat wind ring (nt) [clear, grey, 4 parts, eff 122, fill 5%]
		StreakRing = 11715867299, -- doom "Wind": ring with radial streaks, on BLACK (additive only)
		-- [clear, black, 1 part, eff 78, fill 30%]
		Needle = 16171607099, -- voidflare LinesWhite / Linesback2: thin vertical needle
		-- [clear, white, 1 part, eff 117, fill 9%]
		ZigZag = 13390196434, -- voidstorm "moving lightning": small zigzag arcs, Grid4x4
		-- [clear, white, 2 parts, eff 79, fill 7%, 10/16 cells]
		Orb = 13712004045, -- collab "specs": big soft blob, used tiny [clear, white, 1 part, eff 16 smooth, fill 45%]
		OffDot = 17334135713, -- doom embers: dot in the bottom-left corner (orbits when spun)
		-- [clear, white, 1 part, eff ~63, fill 1%]
		GreySmoke = 16867490141, -- doom Images/56: faint grey smoke, Grid4x4, used black
		-- [clear, grey, 1 part, eff 39 smooth, fill 26%, 12/16 cells]
		VoidFog = 89816655384560, -- voidstorm "uhh_original_fog" (nt), Grid4x4
		-- [FAINT, grey, 1 part, eff ~43 smooth, fill 49%]
		GlowCrack = 13781849388, -- collab GlowCrack / Cracks, Grid4x4
		-- [clear, white, 1 part, eff 89, fill 34%, 15/16 cells]
		Dissolve = 13784241004, -- doom Dissolve: scorch that dissolves, Grid4x4
		-- [clear, black+white, 4 parts, eff 82, fill 23%, 15/16 cells]
	},
	layers = {
		------------------------------------------------------------------ flash + punch (0 - 0.2)
		{ -- white-out card that collapses into the body; doom "6" curve (halves every ~10% of life), size 2R
			id = "flash", kind = "emitter", t = 0, life = 0.05, at = { 0, 4, 0 },
			props = {
				Texture = "QuickFlash", Color = { { 0, "white" }, { 1, "lilac" } }, LightEmission = 1, Brightness = 15,
				Size = { { 0, 16 }, { 0.2, 10.7 }, { 0.3, 6.3 }, { 0.5, 2.3 }, { 0.7, 0.7 }, { 1, 0 } },
				Transparency = 0, Lifetime = 0.15, Speed = 0, Rotation = { -360, 360 }, ZOffset = 8,
			},
			emit = { { 0, 1 } },
		},
		{ -- violet spiky star, re-fired with each wave; collab "impact" (LE -1 Br 12, 6.18 -> 0 in 0.12 s)
			id = "impactStar", kind = "emitter", t = 0, life = 0.25, at = { 0, 4, 0 },
			props = {
				Texture = "ImpactStar", Color = "violet", LightEmission = -1, Brightness = 12,
				Size = { { 0, 6 }, { 1, 0 } }, Transparency = 0, Lifetime = 0.12, Speed = 0,
				Rotation = { 0, 360 }, ZOffset = 3,
			},
			emit = { { 0, 1 }, { 0.1, 1 }, { 0.2, 1 } },
		},
		{ -- the void core: Brightness 0 disc just under the bright cards; tatsumaki "2"/"16" (Br 0-0.05, LE -1..-4)
			id = "inkCore", kind = "emitter", t = 0, life = 0.05, at = { 0, 4, 0 },
			props = {
				Texture = "InkDisc", Color = "ink", LightEmission = -1, Brightness = 0,
				Size = { { 0, 0 }, { 0.3, 9 }, { 1, 13 } }, Transparency = { { 0, 0 }, { 0.2, 0 }, { 1, 1 } },
				Lifetime = 0.2, Speed = 0, ZOffset = 2.9,
			},
			emit = { { 0, 1 } },
		},
		{ -- black ground shock out to 4R in 0.3 s; doom ParticleEmitter 16509144751 (#000000 LE 0, fast sqrt-like grow)
			id = "inkShock", kind = "emitter", t = 0, life = 0.05, at = { 0, 0.1, 0 },
			props = {
				Texture = "BlackShock", FlipbookLayout = 4, FlipbookMode = "OneShot", Color = "ink", LightEmission = 0,
				Brightness = 1, Orientation = "VelocityPerpendicular", EmissionDirection = "Top", Speed = 0.01,
				Size = { { 0, 0 }, { 0.1, 10 }, { 0.2, 15 }, { 0.5, 24 }, { 1, 32 } },
				Transparency = { { 0, 0 }, { 0.39, 0.66 }, { 1, 1 } }, Lifetime = 0.3, Rotation = { -180, 180 },
			},
			emit = { { 0, 2 } },
		},
		------------------------------------------------------------------ body: three waves 0.1 s apart (0 - 0.5)
		{ -- violet slash cards on the portal plane; collab "slash" (LE -1 Br 12, 7 studs const, 0.3 s, z 1.2)
			id = "slash", kind = "emitter", t = 0, life = 0.25, at = { 0, 4, 0 },
			props = {
				Texture = "Slash", FlipbookLayout = 4, FlipbookMode = "OneShot", Color = "violet", LightEmission = -1,
				Brightness = 12, Orientation = "VelocityPerpendicular", EmissionDirection = "Front", Speed = 0.001,
				SpreadAngle = { 25, 25 }, Size = 7, Transparency = 0, Lifetime = 0.3, Rotation = { 0, 360 },
				ZOffset = 1.2,
			},
			emit = { { 0, 1 }, { 0.1, 1 }, { 0.2, 1 } },
		},
		{ -- dark violet crescents spinning behind the slash; collab "wind" (LE 0, tr 0.7, z -1, -500..-200 deg/s)
			id = "darkCrescents", kind = "emitter", t = 0, life = 0.25, at = { 0, 4, 0 },
			props = {
				Texture = "ToonCrescents", FlipbookLayout = 2, FlipbookMode = "OneShot", Color = "deepViolet",
				LightEmission = 0, Brightness = 1, Orientation = "VelocityPerpendicular", EmissionDirection = "Front",
				Speed = 0.0015, SpreadAngle = { 6, 6 },
				Size = { { 0, 0 }, { 0.1, 3.4 }, { 0.3, 8.3 }, { 0.5, 11 }, { 1, 12.6 } },
				Transparency = { { 0, 0.7 }, { 0.6, 0.75 }, { 1, 1 } }, Lifetime = { 0.4, 1 },
				Rotation = { 0, 360 }, RotSpeed = { -500, -200 }, ZOffset = -1,
			},
			emit = { { 0, 4 }, { 0.1, 4 }, { 0.2, 4 } },
		},
		{ -- white swirl rings, faint because they are big (2R at Br 0.4); collab "cres" (tr 1 -> 0.7 at 20%)
			id = "swirl", kind = "emitter", t = 0, life = 0.05, at = { 0, 4, 0 },
			props = {
				Texture = "SpinSwirl", Color = { { 0, "white" }, { 1, "lilac" } }, LightEmission = 1, Brightness = 0.4,
				Orientation = "VelocityPerpendicular", EmissionDirection = "Front", Speed = 0.0012,
				SpreadAngle = { 30, 30 }, Size = { { 0, 0 }, { 0.1, 4.3 }, { 0.3, 10.5 }, { 0.5, 14 }, { 1, 16 } },
				Transparency = { { 0, 1 }, { 0.2, 0.7 }, { 1, 1 } }, Lifetime = { 0.57, 1.46 },
				Rotation = { 0, 360 }, RotSpeed = { 15, 90 },
			},
			emit = { { 0, 3 } },
		},
		------------------------------------------------------------------ rings (0 - 1.2)
		{ -- tilted spiky flat rings, white -> grey -> near-black; voidflare "4" 17848865880 (0 -> 46 at R 10 = 4R)
			id = "windRings", kind = "emitter", t = 0, life = 0.05, at = { 0, 0.5, 0 },
			props = {
				Texture = "WindRing", Color = { { 0, "ringWhite" }, { 0.5, "ringGrey" }, { 1, "nearBlack" } },
				LightEmission = 1, Brightness = 1, Orientation = "VelocityPerpendicular", EmissionDirection = "Top",
				Speed = { 0.94, 9.55 }, Drag = 1.2, SpreadAngle = { 30, 30 },
				Size = { { 0, 0 }, { 0.1, 8.7 }, { 0.3, 21 }, { 0.5, 28 }, { 1, 32 } },
				Transparency = { { 0, 0 }, { 1, 1 } }, Lifetime = { 0.42, 1.2 },
				Rotation = { 0, 360 }, RotSpeed = { 135, 276 },
			},
			emit = { { 0, 3 } },
		},
		{ -- one big faint streak ring on the ground; doom "Wind" 11715867299 (0 -> 58-62 = 4R, tr 0.94-0.97 there)
			id = "bigRing", kind = "emitter", t = 0, life = 0.05, at = { 0, 0.15, 0 },
			props = {
				Texture = "StreakRing", Color = "lilac", LightEmission = 1, Brightness = 5,
				Orientation = "VelocityPerpendicular", EmissionDirection = "Top", Speed = 0.004, SpreadAngle = { 6, 6 },
				Size = { { 0, 0 }, { 0.1, 8.7 }, { 0.3, 21 }, { 0.5, 28 }, { 1, 32 } },
				Transparency = { { 0, 1 }, { 0.17, 0.9 }, { 1, 1 } }, Lifetime = { 0.37, 1.1 }, Rotation = { 0, 360 },
			},
			emit = { { 0, 2 } },
		},
		------------------------------------------------------------------ sparks, crackle, orbs (0 - 2.5)
		{ -- white needles shooting out and stopping (~Speed/Drag = 4-20 studs); voidflare LinesWhite (LE -2 Br 15)
			id = "needles", kind = "emitter", t = 0, life = 0.05, at = { 0, 4, 0 },
			props = {
				Texture = "Needle", Color = "white", LightEmission = -2, Brightness = 15,
				Orientation = "VelocityParallel", Speed = { 16.5, 82.5 }, Drag = 3.85, SpreadAngle = { 180, 180 },
				Size = { { 0, 0 }, { 0.1, 1.5 }, { 1, 0 } }, Squash = 1, Transparency = 0, Lifetime = { 0.36, 0.55 },
				ZOffset = 3,
			},
			emit = { { 0, 10 } },
		},
		{ -- black copy of the same needle, stretching as it flies; voidflare Linesback2 (#000000 LE 0.6, Squash 0 -> 2.86)
			id = "needleInk", kind = "emitter", t = 0, life = 0.05, at = { 0, 4, 0 },
			props = {
				Texture = "Needle", Color = "ink", LightEmission = 0.6, Brightness = 1,
				Orientation = "VelocityParallel", Speed = { 16.5, 49.5 }, Drag = 3.85, SpreadAngle = { 180, 180 },
				Size = { { 0, 0 }, { 0.1, 1.5 }, { 1, 0 } }, Squash = { { 0, 0 }, { 1, 2.86 } }, Transparency = 0,
				Lifetime = { 0.36, 0.55 }, ZOffset = 2,
			},
			emit = { { 0, 8 } },
		},
		{ -- zigzag crackle inside the body with doom's one-frame dropouts; voidstorm 13390196434 (Loop 10 fps, LE 0.5 Br 25)
			id = "crackle", kind = "emitter", t = 0.03, life = 0.4, at = { 0, 4, 0 }, box = { 6, 6, 2 },
			props = {
				Texture = "ZigZag", FlipbookLayout = 4, FlipbookMode = "Loop", FlipbookFramerate = { 10, 10 },
				Color = { { 0, "white" }, { 1, "lilac" } }, LightEmission = 0.5, Brightness = 25, Shape = "Box",
				Size = 2.5, Speed = 0, Rotation = { 0, 360 }, Lifetime = 0.6, ZOffset = 2.5,
				Transparency = { -- doom "Recolor" keys: hidden to 17%, then blinks off at 23 / 45 / 65 / 75% of life
					{ 0, 1 }, { 0.171, 1 }, { 0.196, 0 }, { 0.23, 1 }, { 0.264, 0 }, { 0.42, 0 }, { 0.446, 1 },
					{ 0.477, 0 }, { 0.616, 0 }, { 0.646, 1 }, { 0.673, 0 }, { 0.732, 0 }, { 0.748, 1 }, { 0.767, 0 },
					{ 0.801, 0 }, { 1, 1 },
				},
			},
			emit = { { 0, 6, 0.4 } },
		},
		{ -- tiny solid violet orbs, one set per wave; collab "specs" (LE -1 Br 18, swell 0 -> 0.44 at 10%, gravity -3.27)
			id = "orbs", kind = "emitter", t = 0, life = 0.25, at = { 0, 4, 0 },
			props = {
				Texture = "Orb", Color = "violet", LightEmission = -1, Brightness = 18,
				Size = { { 0, 0 }, { 0.1, 0.44 }, { 1, 0 } }, Speed = { 5.45, 21.8 }, Drag = 3, SpreadAngle = { 180, 180 },
				Acceleration = { 0, -3.27, 0 }, Transparency = 0, Lifetime = { 0.3, 1 }, ZOffset = 0.6,
			},
			emit = { { 0, 12 }, { 0.1, 12 }, { 0.2, 12 } },
		},
		{ -- curly embers that go dark mid-life and re-ignite; doom 17334135713 (LE -1 Br 35, RotSpeed +-130), scaled to R 8
			id = "embers", kind = "emitter", t = 0.03, life = 0.05, at = { 0, 4, 0 },
			props = {
				Texture = "OffDot", Color = { { 0, "lilac" }, { 0.25, "violet" }, { 0.47, "dip" }, { 0.75, "violet" }, { 1, "deepViolet" } },
				LightEmission = -1, Brightness = 35, Size = { { 0, 0 }, { 0.05, 1.9 }, { 1, 0 } },
				Speed = { 16, 110 }, Drag = 7.33, SpreadAngle = { 180, 180 }, Acceleration = { 0, -3.11, 0 },
				Rotation = { 0, 360 }, RotSpeed = { -130, 130 }, Transparency = 0, Lifetime = { 0.96, 2.5 }, ZOffset = 4,
			},
			emit = { { 0, 40 } },
		},
		------------------------------------------------------------------ dark aftermath (0.05 - 3.3)
		{ -- black smoke: #000000 at LE 0, held at Transparency 0.5, cubic-out grow, hangs; doom Images/56 + smoke_4
			id = "blackSmoke", kind = "emitter", t = 0.05, life = 0.3, at = { 0, 2, 0 },
			props = {
				Texture = "GreySmoke", FlipbookLayout = 4, FlipbookMode = "OneShot", Color = "ink", LightEmission = 0,
				Brightness = 1, Size = { { 0, 0 }, { 0.1, 3.5 }, { 0.2, 6.3 }, { 0.3, 8.5 }, { 0.5, 11.4 }, { 1, 13 } },
				Transparency = { { 0, 0.5 }, { 1, 1 } }, Speed = { 11, 77 }, Drag = 4.92, SpreadAngle = { 90, 90 },
				Lifetime = { 0.85, 2.4 }, Rotation = { 0, 360 },
			},
			emit = { { 0, 6, 0.25 } },
		},
		{ -- void fog that darkens what is behind it, visible only 25-75% of life (Transparency keys above 1);
			-- voidstorm "uhh_ori"/"Cloud" (LE -0.7 Br 2.5, #231E35 ramp, Squash -0.7). voidstorm used VelocityParallel on a
			-- moving locked part; FacingCamera here because this effect does not move.
			id = "voidFog", kind = "emitter", t = 0.1, life = 0.3, at = { 0, 4, 0 }, box = { 8, 4, 3 },
			props = {
				Texture = "VoidFog", FlipbookLayout = 4, FlipbookMode = "OneShot",
				Color = { { 0, "cloud" }, { 0.5, "cloudMid" }, { 1, "cloudEnd" } }, LightEmission = -0.7, Brightness = 2.5,
				Shape = "Box", Size = 10, Squash = -0.5, Speed = { 0.5, 1.5 }, Rotation = { 0, 360 },
				Transparency = { { 0, 1.5 }, { 0.5, 0.42 }, { 1, 1.5 } }, Lifetime = 1.74, ZOffset = 0.5,
			},
			emit = { { 0, 5, 0.3 } },
		},
		{ -- violet glow cracks running outward (Squash 0 -> 5.4 on a flat card); collab GlowCrack (LE 1 Br 10, 0.875 s)
			id = "glowCrack", kind = "emitter", t = 0.05, life = 0.05, at = { 0, 0.12, 0 },
			props = {
				Texture = "GlowCrack", FlipbookLayout = 4, FlipbookMode = "OneShot", Color = "glow", LightEmission = 1,
				Brightness = 10, Orientation = "VelocityPerpendicular", EmissionDirection = "Top", Speed = 0.0003,
				Size = 3.65, Squash = { { 0, 0 }, { 1, 5.4 } }, Transparency = 0, Lifetime = 0.875,
				Rotation = { 0, 360 }, ZOffset = 2,
			},
			emit = { { 0, 3 } }, -- collab emits 1; 3 with random Rotation make a star of cracks
		},
		{ -- Brightness 0 scorch that outlives everything, dissolving after 62% of life; doom Dissolve (3.26 s)
			id = "scorch", kind = "emitter", t = 0.05, life = 0.05, at = { 0, 0.08, 0 },
			props = {
				Texture = "Dissolve", FlipbookLayout = 4, FlipbookMode = "OneShot", Color = "ink", LightEmission = 0.6,
				Brightness = 0, Orientation = "VelocityPerpendicular", EmissionDirection = "Top", Speed = 0.05,
				Size = 9, Transparency = { { 0, 0 }, { 0.62, 0 }, { 1, 1 } }, Lifetime = 3.26, Rotation = { -360, 360 },
				ZOffset = 1,
			},
			emit = { { 0, 1 } },
		},
	},
}
