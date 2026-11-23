-- ClipForge base recipe "icewater": from vfxmith (github.com/Frxctured/roblox-vfxmith), knowledge/categories/icewater_recipe.luau,
-- MIT License, Copyright (c) 2026 Frxctured (see THIRD_PARTY_NOTICES). Texture ids are public Roblox images owned by
-- their uploaders; their terms apply. Recoloured, retimed and rescaled at play time by ClipForge's FX module.
-- FrostBurst: one generic ice / water ground burst for VFXTimeline, built from the 6 open-source effects studied in
-- icewater.md (same folder). UNTESTED draft: valid Luau, not yet played in Studio.
-- Values come from the anatomy table in icewater.md (section b); source effects are named per layer:
--   Ice = f94ba5a23040 (Ice.rbxm, frozen-ground eruption)     icy = ab56eca4fb1c (icy.rbxm, crystal eruption)
--   WW  = 8679294aa869 (Whirlwind VFX1, water/wind vortex)    Frost = 0695319f172d (FrostOs aura showcase)
--   poly = 50b56a6be8e6 (polething rune burst)                Chara = 37b080b2910d (pixel hit)
-- Shape: R = 10 studs (radius of the largest ground ring); everything sits on the ground (y 0.1) unless noted.
-- Phases: flash 0-0.15 | ring peak 0.1-0.35 | body 0.1-1.8 | ground frost 0.1-2.6, gone ~3.2 s (ice).
--   For WATER instead of ice: disable groundSplash, crack, frostDisc, fog and iceCrown; keep whirlRings, ripples,
--   mist, twinkles, shards (water ends by ~1.2 s).
-- Three tones: white core (flashGlow, flashRing, hitSparkle, iceCrown, iceSpecs, twinkles, groundSplash, crack),
-- saturated body (groundHit, shockDisc, whirlRings, ripples, radialMist, plume, shards, frostDisc, fog), dark ink
-- (inkPool, inkMist).
-- Deliberate departures from the evidence (icewater.md section e):
--   * an ink layer pair (the four real ice/water files have none) made the polething / FrostOs way (LE 0, dark colour);
--   * a white flash (Whirlwind and icy have no opening beat; Ice's flash ring sat at Transparency 0.85, LE 0);
--   * groundHit keeps Brightness 4 (Ice 10; its flat rings were only edge-on streaks on screen, so unverified) and the
--     crown 10 (icy 20, not separable on screen); radialMist and shards use the sources' Brightness 10 / 15, which the
--     2026-11-14 recapture shows reading as soft pale cyan puffs and glowing cyan droplets;
--   * TimeScale (WW 0.5, Ice 0.5/0.65) is folded into Lifetime because the runtime sets TimeScale itself;
--   * one crater splash at Transparency 0.15 instead of Ice's 100 stacked copies at 0.74.
-- Recapture changes (2026-11-14): Ice's wind rings (thinArcs) never read as rings from a low camera -> replaced by icy's
-- long-life ripple rings, which read as water ripples; ground frost now lands WITH the hit (Seen in Ice and icy) instead
-- of the crack's slow reveal; added the crater splash that is Ice's dominant ground read.
-- Textures whose look we could not preview (outside the top-1500 index): 99030912594735, 11541772958. Check they load.
return {
	name = "FrostBurst",
	scale = 1,
	palette = {
		white = "#E8F6FF", -- white core
		pale = "#BCDCFF", -- icy's single colour (= Frost's #13161A at Brightness 10)
		crackBlue = "#A1E1FF", -- Ice ground layers
		ice = "#80C8FF", -- Ice body colour
		water = "#73BAFC", -- WW smoke / shock disc
		whirl = "#87B4FC", -- WW ring colour
		deep = "#5792FF", -- WW debris tint: the saturated end
		ink = "#0A1430",
	},
	textures = {
		-- [..] at the end of a texture comment = measured traits (gallery/textures/traits.json, legend in kit/scripts/texture_traits.py)
		FadingGlow = 107821950776778, -- poly: soft round glow (flash) [FAINT, white, 1 part, eff 523, fill 40%]
		SpikyRing = 18397658030, -- Ice: soft ring with a spiky fringe (flash ring)
		-- [clear, grey, 2 parts, eff 75, fill 28%]
		HitRing = 16125610617, -- Ice: ring of sparkle flashes, 4x4
		-- [clear, white, 4 parts, eff 89, fill 12%, 5/16 cells]
		HitCross = 13778611432, -- Ice: cross sparkle that grows and breaks, 4x4
		-- [clear, white, 4 parts, eff ~58, fill 4%, 6/16 cells]
		ShockDisc = 75353285142738, -- WW: soft radial-streak ring [clear, white, 1 part, eff 80, fill 27%]
		Whirl = 99030912594735, -- WW: whirl ring arcs (not previewed) [clear, white, 1 part, eff 186, fill 3%]
		Ripple = 11541772958, -- icy: long-life flat ring, reads as a water ripple (not previewed)
		-- [clear, white, 4 parts, eff 269, fill 3%]
		Crater = 130658933079638, -- Ice: white frost splash / crater with cracks
		-- [clear, white, 1 part, eff 110, fill 41%]
		CrossStitch = 8133845150, -- icy: V of streaks on BLACK (additive only)
		-- [BLACK card, white, 2 parts, eff 357, fill 16%]
		Mist = 16867447521, -- Ice: smoke2 4x4 [clear, white, 1 part, eff 28 smooth, fill 16%, 15/16 cells]
		DenseSmoke = 83337784980211, -- Ice: dense realistic smoke 4x4 [clear, white, 1 part, eff 63, fill 27%]
		ToonPuff = 138231890129613, -- Ice: toon puff breaking up 4x4
		-- [clear, white, 1 part, eff 43 smooth, fill 26%, 12/16 cells]
		SoftDot = 12222002958, -- icy: soft white dot [clear, white, 1 part, eff 38 smooth, fill 5%]
		Star = 8180428772, -- WW: fat 4-point star [clear, white, 1 part, eff 202, fill 13%]
		Rocks = 15441282898, -- WW: four rocks 2x2 [clear, grey, 1 part, eff 51, fill 52%]
		SoftDisc = 2065086791, -- Frost: soft white disc (ground pool) [clear, white, 1 part, eff ~23 smooth, fill 65%]
		Crack = 99911247720869, -- Ice: bright crack starburst [clear, white, 1 part, eff 129, fill 16%]
		IceDisc = 13781849388, -- icy: cracked ice disc crumbling, 4x4
		-- [clear, white, 1 part, eff 89, fill 34%, 15/16 cells]
		Fog = 11447021694, -- icy: Outward Fog 8x8 [clear, white, 1 part, eff 38 smooth, fill 9%, 47/64 cells]
	},
	layers = {
		------------------------------------------------------------------ flash (0 - 0.15): white core
		{ -- soft white bloom at the hit point. poly Fading Glow (life 0.1-0.3, Size 5-30, LE 1, Br 0.5-2)
			id = "flashGlow", kind = "emitter", t = 0, life = 0.05, at = { 0, 1, 0 },
			props = {
				Texture = "FadingGlow", Color = "white", LightEmission = 1, Brightness = 2,
				Size = { { 0, 9 }, { 1, 12 } }, Transparency = { { 0, 0 }, { 0.4, 0.2 }, { 1, 1 } },
				Lifetime = 0.12, Speed = 0, ZOffset = 1,
			},
			emit = { { 0, 1 } },
		},
		{ -- camera-facing spiky ring that opens fast. Ice flash ring (1 -> 9.3 @28% -> 14.6, 0.135 s at TimeScale 0.65)
			id = "flashRing", kind = "emitter", t = 0, life = 0.05, at = { 0, 1, 0 },
			props = {
				Texture = "SpikyRing", Color = "white", LightEmission = 1, Brightness = 2,
				Size = { { 0, 0.7 }, { 0.28, 6.4 }, { 1, 10 } }, Transparency = { { 0, 0.3 }, { 1, 1 } },
				Lifetime = 0.2, Speed = 0, Rotation = { -180, 180 }, ZOffset = 1,
			},
			emit = { { 0, 1 } },
		},
		------------------------------------------------------------------ ground impact (0.02 - 0.45)
		{ -- flat sparkle-ring flipbook, born OPEN at 0.2 of final size, fade-in 15%, hold to 75%. Ice hitFast
			id = "groundHit", kind = "emitter", t = 0.02, life = 0.05, at = { 0, 0.1, 0 },
			props = {
				Texture = "HitRing", FlipbookLayout = 4, FlipbookMode = "OneShot",
				Color = "ice", LightEmission = 0, Brightness = 4, -- Ice: Brightness 10
				Orientation = "VelocityPerpendicular", EmissionDirection = "Top", Speed = 0.01,
				Size = { { 0, 4 }, { 0.1, 8.3 }, { 0.2, 11.3 }, { 0.3, 13.6 }, { 0.5, 16.8 }, { 0.7, 18.8 }, { 1, 20 } },
				Transparency = { { 0, 1 }, { 0.15, 0 }, { 0.75, 0 }, { 1, 1 } },
				Lifetime = { 0.26, 0.43 }, Rotation = { 0, 360 },
			},
			emit = { { 0, 2 } },
		},
		{ -- flat cross-sparkle flipbook on top, random aspect via the Squash envelope. Ice hitFast (Squash env 0.5)
			id = "hitSparkle", kind = "emitter", t = 0.02, life = 0.05, at = { 0, 0.15, 0 },
			props = {
				Texture = "HitCross", FlipbookLayout = 4, FlipbookMode = "OneShot",
				Color = "white", LightEmission = 1, Brightness = 2,
				Orientation = "VelocityPerpendicular", EmissionDirection = "Top", Speed = 0.03,
				Size = { { 0, 4 }, { 0.1, 8.3 }, { 0.3, 13.6 }, { 0.5, 16.8 }, { 1, 20 } },
				Transparency = { { 0, 1 }, { 0.15, 0 }, { 0.75, 0 }, { 1, 1 } },
				Squash = { { 0, 0, 0.5 }, { 1, 0, 0.5 } },
				Lifetime = 0.43, Rotation = { 0, 360 }, SpreadAngle = { 10, 10 },
			},
			emit = { { 0, 3 } },
		},
		{ -- soft radial-streak disc, ease-out 0 -> 2R, front-loaded fade. WW Shockwave2 (0.35 s at TimeScale 0.5)
			id = "shockDisc", kind = "emitter", t = 0.02, life = 0.05, at = { 0, 0.12, 0 },
			props = {
				Texture = "ShockDisc", Color = "water", LightEmission = 1, Brightness = 0.5,
				Orientation = "VelocityPerpendicular", EmissionDirection = "Top", Speed = 0.001,
				Size = { { 0, 0 }, { 0.06, 6.3 }, { 0.12, 10 }, { 0.21, 13.6 }, { 0.32, 15.8 }, { 0.47, 17.7 },
					{ 0.6, 18.6 }, { 1, 19.6 } },
				Transparency = { { 0, 0.49 }, { 0.154, 0.66 }, { 0.34, 0.91 }, { 0.54, 0.98 }, { 1, 1 } },
				Lifetime = 0.7, Rotation = { -180, 180 },
			},
			emit = { { 0, 1 } },
		},
		------------------------------------------------------------------ rings (0.03 - 2.3)
		{ -- whirlpool: flat ring arcs spinning ONE way, ease-out to 2R. WW Wind51/16/36 (life 0.5-1.15 at TS 0.5)
			id = "whirlRings", kind = "emitter", t = 0.03, life = 0.05, at = { 0, 0.14, 0 },
			props = {
				Texture = "Whirl", Color = "whirl", LightEmission = 1, Brightness = 1,
				Orientation = "VelocityPerpendicular", EmissionDirection = "Top", Speed = 0.001, SpreadAngle = { 10, 10 },
				Size = { { 0, 0 }, { 0.04, 5.9 }, { 0.09, 9.6 }, { 0.17, 11.9 }, { 0.27, 13.7 }, { 0.44, 15.7 },
					{ 0.62, 17.2 }, { 1, 19.6 } },
				Transparency = { { 0, 0.49 }, { 0.154, 0.66 }, { 0.34, 0.91 }, { 0.54, 0.98 }, { 1, 1 } },
				Lifetime = { 1.0, 2.3 }, Rotation = { -180, 180 }, RotSpeed = { -450, -50 },
			},
			emit = { { 0, 4 } },
		},
		{ -- concentric water ripples round the frozen ground, long-lived, expo-like ease-out to ~1.8R. icy 11541772958
			-- (Seen 0.2-1.8 s as pale-rimmed rings with dark bands; icy R = 12 -> Size 22 scaled to 18)
			id = "ripples", kind = "emitter", t = 0.15, life = 0.05, at = { 0, 0.16, 0 },
			props = {
				Texture = "Ripple", Color = "pale", LightEmission = 1, Brightness = 6,
				Orientation = "VelocityPerpendicular", EmissionDirection = "Top", Speed = 0.01, SpreadAngle = { 4, 4 },
				Size = { { 0, 0, 0.3 }, { 0.1, 12, 0.3 }, { 0.2, 14.7, 0.3 }, { 0.3, 16, 0.3 }, { 0.5, 17.3, 0.3 },
					{ 0.7, 17.8, 0.3 }, { 1, 18, 0.3 } },
				Transparency = { { 0, 0.59 }, { 0.1, 0.68, 0.08 }, { 0.2, 0.76, 0.13 }, { 0.38, 0.85, 0.15 },
					{ 0.5, 0.91, 0.12 }, { 0.7, 0.98 }, { 0.8, 1 }, { 1, 1 } },
				Lifetime = { 1, 4.2 }, Rotation = { -180, 180 }, RotSpeed = { -24, 24 },
			},
			emit = { { 0, 4 } },
		},
		------------------------------------------------------------------ body (0.05 - 2.5)
		{ -- crown of standing ice spikes: radial fan + VelocityPerpendicular, V texture flipped by Rotation -180. icy
			id = "iceCrown", kind = "emitter", t = 0.05, life = 0.05, at = { 0, 0.5, 0 },
			props = {
				Texture = "CrossStitch", Color = "pale", LightEmission = 1, Brightness = 10, -- icy: Br 20
				Orientation = "VelocityPerpendicular", EmissionDirection = "Back", SpreadAngle = { 0, 360 },
				Speed = 80, Drag = 8.88,
				Size = { { 0, 0 }, { 0.1, 3.9 }, { 0.2, 5.2 }, { 0.3, 6 }, { 0.5, 7.1 }, { 0.7, 7.7 }, { 1, 8 } },
				Transparency = { { 0, 0.68 }, { 0.3, 0.75 }, { 0.6, 0.87 }, { 1, 1 } },
				Lifetime = { 0.46, 0.6 }, Rotation = { -180, -180 },
			},
			emit = { { 0, 12 } },
		},
		{ -- ground-hugging radial mist fan (flat ring of smoke that shoots out and stops). Ice smoke2 + WW smoke
			id = "radialMist", kind = "emitter", t = 0.05, life = 0.05, at = { 0, 0.6, 0 },
			props = {
				Texture = "Mist", FlipbookLayout = 4, FlipbookMode = "OneShot",
				Color = "ice", LightEmission = 0, Brightness = 10, -- Ice: Br 10, Seen as soft pale mint/cyan-grey puffs
				EmissionDirection = "Front", SpreadAngle = { 9, 360 }, Speed = { 18, 80 }, Drag = 5.3,
				Size = { { 0, 0 }, { 0.1, 2.3 }, { 0.2, 3.5 }, { 0.3, 4.3 }, { 0.5, 5.4 }, { 0.7, 6 }, { 1, 6.9 } },
				Transparency = { { 0, 1 }, { 0.05, 0.36 }, { 1, 1 } },
				Squash = -0.2, -- WW: slightly wider than tall
				Lifetime = { 0.46, 0.76 }, Rotation = { 0, 360 }, ZOffset = 1,
			},
			emit = { { 0, 16 } },
		},
		{ -- small up-cone of toon frost puffs. Ice "Stuff" layers (VelocityParallel, spread 45, Drag 3.5-12)
			id = "plume", kind = "emitter", t = 0.06, life = 0.05, at = { 0, 0.5, 0 },
			props = {
				Texture = "ToonPuff", FlipbookLayout = 4, FlipbookMode = "OneShot",
				Color = "ice", LightEmission = 0, Brightness = 2,
				Orientation = "VelocityParallel", EmissionDirection = "Top", SpreadAngle = { 45, 45 },
				Speed = { 15, 45 }, Drag = 8,
				Size = { { 0, 0 }, { 0.1, 3.2 }, { 0.3, 4.5 }, { 0.5, 5.1 }, { 1, 6, 0.8 } },
				Transparency = { { 0, 1 }, { 0.2, 0.6 }, { 1, 1 } }, -- Ice: min 0.87-0.9 (too faint)
				Lifetime = { 1.3, 2.5 }, Rotation = { -360, 360 },
			},
			emit = { { 0, 3 } },
		},
		{ -- ice dust: burst ~8 studs, hang, float up, fade LATE (ease-in). icy specks 12222002958
			id = "iceSpecs", kind = "emitter", t = 0.06, life = 0.05, at = { 0, 1, 0 },
			props = {
				Texture = "SoftDot", Color = "white", LightEmission = 0, Brightness = 4,
				EmissionDirection = "Top", SpreadAngle = { 360, 360 }, Speed = 48, Drag = 6, Acceleration = { 0, 20, 0 },
				Size = { { 0, 0 }, { 0.1, 0.28 }, { 0.3, 0.49 }, { 0.5, 0.6 }, { 0.7, 0.7 }, { 1, 0.88 } },
				Transparency = { { 0, 0 }, { 0.4, 0.12 }, { 0.6, 0.27 }, { 0.8, 0.51 }, { 0.9, 0.7 }, { 1, 1 } },
				Lifetime = { 1, 2 }, Rotation = { -180, 180 }, RotSpeed = { -280, 280 }, ZOffset = 2,
			},
			emit = { { 0, 20 } },
		},
		{ -- delayed twinkles: invisible until 18% of life, one pop at 26%, gone at 35%; random life spreads them. WW
			-- (WW used an orange #FF7231 complementary accent; swap Color to "#FF7231" for that look)
			id = "twinkles", kind = "emitter", t = 0.08, life = 0.05, at = { 0, 1.5, 0 },
			props = {
				Texture = "Star", Color = "white", LightEmission = 0.76, Brightness = 5,
				EmissionDirection = "Back", SpreadAngle = { 10, 360 }, Speed = { 0, 40 }, Drag = 3,
				Size = { { 0, 0 }, { 0.179, 0 }, { 0.259, 0.9 }, { 0.355, 0 }, { 1, 0 } },
				Transparency = 0, Lifetime = { 0.5, 1.35 }, ZOffset = 2,
			},
			emit = { { 0, 7 } },
		},
		{ -- ice/water droplets: rock sprites (random static frame of a 2x2 sheet) tinted the saturated hue at Br 15
			-- render as glowing cyan droplets, not rocks (WW, Seen 0.10-0.55 s)
			id = "shards", kind = "emitter", t = 0.08, life = 0.05, at = { 0, 0.8, 0 },
			props = {
				Texture = "Rocks", FlipbookLayout = 2, FlipbookMode = "Loop", FlipbookFramerate = 0,
				FlipbookStartRandom = true,
				Color = "deep", LightEmission = 0, Brightness = 15,
				EmissionDirection = "Back", SpreadAngle = { 15, 360 }, Speed = { 0, 40 }, Drag = 3,
				Acceleration = { 0, -20, 0 },
				Size = { { 0, 0 }, { 0.32, 0.6 }, { 1, 0 } }, Squash = 0.25,
				Transparency = 0, Lifetime = { 0.45, 0.85 }, Rotation = { -360, 360 },
			},
			emit = { { 0, 7 } },
		},
		------------------------------------------------------------------ ink (0.1 - 2.5): the layer the ice files lack
		{ -- dark pool under the burst so the pale layers read. Frost "darkground" (2065086791, LE 0, near-black)
			id = "inkPool", kind = "emitter", t = 0.1, life = 0.05, at = { 0, 0.08, 0 },
			props = {
				Texture = "SoftDisc", Color = "ink", LightEmission = 0, Brightness = 1,
				Orientation = "VelocityPerpendicular", EmissionDirection = "Top", Speed = 0.001,
				Size = { { 0, 8 }, { 0.2, 16 }, { 1, 20 } },
				Transparency = { { 0, 1 }, { 0.15, 0.45 }, { 0.6, 0.55 }, { 1, 1 } },
				Lifetime = 1.6, ZOffset = -0.5,
			},
			emit = { { 0, 1 } },
		},
		{ -- dark mist behind the bright mist: Ice's slow smoke recoloured as ink (poly: LE 0 dark splats)
			id = "inkMist", kind = "emitter", t = 0.12, life = 0.05, at = { 0, 0.6, 0 },
			props = {
				Texture = "DenseSmoke", FlipbookLayout = 4, FlipbookMode = "OneShot",
				Color = "ink", LightEmission = 0, Brightness = 1,
				EmissionDirection = "Front", SpreadAngle = { 5, 360 }, Speed = { 6, 25 }, Drag = 2.5,
				Size = { { 0, 0 }, { 0.1, 2.2 }, { 0.3, 4.2 }, { 0.5, 5.2 }, { 1, 6.7 } },
				Transparency = { { 0, 1 }, { 0.22, 0.55 }, { 1, 1 } },
				Lifetime = { 1.5, 2.5 }, Rotation = { 0, 360 }, ZOffset = -1,
			},
			emit = { { 0, 6 } },
		},
		------------------------------------------------------------------ ice tail (0.1 - 3.2)
		{ -- cracked-ice disc that crumbles through its flipbook. icy ground (13781849388, LE 0, Br 1.48, Size 16, 6 s)
			id = "frostDisc", kind = "emitter", t = 0.1, life = 0.05, at = { 0, 0.1, 0 },
			props = {
				Texture = "IceDisc", FlipbookLayout = 4, FlipbookMode = "OneShot",
				Color = "pale", LightEmission = 0, Brightness = 1.5,
				Orientation = "VelocityPerpendicular", EmissionDirection = "Top", Speed = 0.001,
				Size = 13, Transparency = { { 0, 0.15 }, { 1, 0.15 } },
				Lifetime = 3, Rotation = { 0, 360 }, ZOffset = -0.2,
			},
			emit = { { 0, 1 } },
		},
		{ -- white frost splash that lands WITH the hit and holds ~2.5 s: Ice's dominant ground read (Seen 0.10-2.6 s).
			-- Ice crater 130658933079638 (Size 20.2 for R 20 -> 10; one particle at 0.15 instead of 100 at 0.74)
			id = "groundSplash", kind = "emitter", t = 0.07, life = 0.05, at = { 0, 0.1, 0 },
			props = {
				Texture = "Crater", Color = "crackBlue", LightEmission = 0, Brightness = 2,
				Orientation = "VelocityPerpendicular", EmissionDirection = "Top", Speed = 0.001,
				Size = 12, Transparency = { { 0, 1 }, { 0.02, 0.15 }, { 0.8, 0.2 }, { 1, 1 } },
				Lifetime = 3, Rotation = { 0, 360 }, ZOffset = -0.15,
			},
			emit = { { 0, 1 } },
		},
		{ -- bright crack starburst over the splash. Ice Crack2 (slow reveal 1 -> 0 @70% in the source, but on screen the
			-- ground frost lands with the hit, so it appears fast here and holds)
			id = "crack", kind = "emitter", t = 0.1, life = 0.05, at = { 0, 0.11, 0 },
			props = {
				Texture = "Crack", Color = "crackBlue", LightEmission = 0, Brightness = 3, -- Ice: Br 4
				Orientation = "VelocityPerpendicular", EmissionDirection = "Top", Speed = 0.001,
				Size = 12, Transparency = { { 0, 1 }, { 0.08, 0.2 }, { 0.75, 0.1 }, { 1, 1 } },
				Lifetime = 3, Rotation = { 0, 360 }, ZOffset = -0.1,
			},
			emit = { { 0, 1 } },
		},
		{ -- lingering frost fog: 85% size at 10% of life, slow rise. icy Outward Fog (LE 0.2, Br 4, 2-6 s)
			id = "fog", kind = "emitter", t = 0.15, life = 0.05, at = { 0, 1, 0 },
			props = {
				Texture = "Fog", FlipbookLayout = 8, FlipbookMode = "OneShot",
				Color = "pale", LightEmission = 0.2, Brightness = 3,
				EmissionDirection = "Top", SpreadAngle = { 360, 360 }, Speed = 17, Drag = 4, Acceleration = { 0, 6, 0 },
				Size = { { 0, 0 }, { 0.1, 8.5 }, { 0.2, 9.3 }, { 0.4, 9.8 }, { 1, 10, 1.5 } },
				Transparency = { { 0, 0.6 }, { 0.1, 0.75 }, { 0.3, 0.85 }, { 0.6, 0.93 }, { 1, 1 } },
				Lifetime = { 2, 4 }, Rotation = { -180, 180 }, ZOffset = 1,
			},
			emit = { { 0, 6 } },
		},
		------------------------------------------------------------------ light
		{ -- cold point light, flashes then fades. Ice PointLight (Br 3, Range 25, #9DE2FF, static)
			id = "light", kind = "light", t = 0, life = 0.6, at = { 0, 2, 0 },
			props = { Color = "#9DE2FF", Brightness = 3, Range = 18 },
			tracks = { Brightness = { { 0, 3 }, { 0.08, 3 }, { 0.6, 0, "quadOut" } } },
		},
	},
}
