-- ClipForge Library: every base effect, by category. Three kinds of entries:
--   recipe = "<module>"   a studied effect from Recipes/ (vfxmith)
--   build  = function     an effect composed from Blocks (tuned layers)
--   combo  = { parts }    several effects timed together (a slash combo, a meteor = fall + explosion + crater)
-- Origin convention: the effect's origin is on the ground at the caster's feet, facing -Z (forward).
-- ambient = true: a looping effect (weather, campfires) that runs until stopped.

local B = require(script.Parent:WaitForChild("Blocks"))
local PAL = B.PAL

local Library = {}
Library.CATEGORIES = { "Combat", "Elements", "Magic", "Movement", "Game feel", "Ambient" }

local list = {}
local function add(e)
	table.insert(list, e)
end

local CHEST = { 0, 3, 0 }

local function emits(from, to, every, n)
	local out = {}
	local t = from
	while t <= to + 1e-6 do
		table.insert(out, { t, n or 1 })
		t += every
	end
	return out
end

--------------------------------------------------------------------------------------------------------- COMBAT
add({ id = "slash", title = "Slash", category = "Combat", recipe = "slash", tags = "sword cut swipe crescent blade katana",
	blurb = "Crescent swipe with a hot edge, ink twin and sparks" })
add({ id = "impact", title = "Ground Slam", category = "Combat", recipe = "impact", tags = "slam punch smash stomp ground",
	blurb = "Spike flash, dome, racing rings, debris orbs, smoke, scorch", shake = { amp = 0.5, dur = 0.35 } })
add({ id = "hitspark", title = "Hit Spark", category = "Combat", tags = "hit spark small impact sword clash",
	blurb = "Small, fast spark for every hit",
	build = function()
		return B.spec({ name = "HitSpark", palette = PAL.fire, layers = {
			B.stamp({ at = CHEST, size = 3.4 }),
			B.flash({ at = CHEST, size = 3.2, lifetime = 0.07 }),
			B.star({ at = CHEST, size = 3.6, lifetime = 0.14, rotation = { -20, 20 } }),
			B.shockwave({ at = CHEST, size = 3.6, lifetime = 0.18 }),
			B.sparks({ at = CHEST, count = 10, speed = { 30, 60 }, size = 0.3, spread = { 180, 180 }, gravity = { 0, -30, 0 }, lifetime = { 0.15, 0.35 } }),
			B.light({ at = CHEST, brightness = 4, range = 10, life = 0.2 }),
		} })
	end })
add({ id = "punch", title = "Punch Impact", category = "Combat", tags = "punch fist hit impact boxing", shake = { amp = 0.35, dur = 0.25 },
	blurb = "Ink-framed flash, shock ring, speed lines, dust",
	build = function()
		local at = { 0, 3, -2.5 }
		return B.spec({ name = "PunchImpact", palette = PAL.fire, layers = {
			B.inkFlash({ at = at, size = 7 }),
			B.stamp({ at = at, size = 7.5 }),
			B.flash({ at = at, size = 6 }),
			B.bloom({ at = at, size = 8, alpha = 0.45, lifetime = 0.25 }),
			B.shockwave({ at = at, size = 9, lifetime = 0.28 }),
			B.shockburst({ at = at, dir = "Front", size = 9, count = 5 }),
			B.puff({ at = at, size = 2.2, count = 3, speed = { 2, 6 } }),
			B.streaks({ at = at, count = 12 }),
			B.sparks({ at = at, count = 12, spread = { 70, 70 } }),
			B.dust({ at = { 0, 0.2, -2.5 }, count = 6, size = 2.5 }),
			B.light({ at = at, brightness = 6, range = 14, life = 0.3 }),
		} })
	end })
add({ id = "critical", title = "Critical Hit", category = "Combat", tags = "critical crit big hit heavy finisher", shake = { amp = 0.8, dur = 0.45 },
	blurb = "Huge impact frame, rays, double shockwave, spark storm",
	build = function()
		local at = { 0, 3, -2 }
		return B.spec({ name = "CriticalHit", palette = PAL.blood, layers = {
			B.inkFlash({ at = at, size = 12 }),
			B.stamp({ at = at, size = 12, lifetime = 0.07 }),
			B.flash({ at = at, size = 9 }),
			B.star({ at = at, size = 9, lifetime = 0.25 }),
			B.shockburst({ at = at, dir = "Front", size = 15 }),
			B.plume({ at = at, size = 4.5, count = 4 }),
			B.rays({ at = at, size = 15, lifetime = 0.5 }),
			B.shockwave({ at = at, size = 12, lifetime = 0.3 }),
			B.shockwave({ id = "shock2", t = 0.07, at = at, size = 18, lifetime = 0.35, tex = "THINRING" }),
			B.bloom({ at = at, size = 12, alpha = 0.4 }),
			B.sparks({ at = at, count = 22, speed = { 50, 100 }, spread = { 180, 180 } }),
			B.streaks({ at = at, count = 16 }),
			B.grade({ brightness = 0.15, contrast = 0.35 }),
			B.light({ at = at, brightness = 9, range = 22, life = 0.45 }),
		} })
	end })
add({ id = "parry", title = "Parry Clash", category = "Combat", tags = "parry block clash deflect metal sparks guard",
	blurb = "Bright cross glint and a shower of metal sparks",
	build = function()
		return B.spec({ name = "ParryClash", palette = PAL.holy, layers = {
			B.flash({ at = CHEST, size = 4, lifetime = 0.06 }),
			B.stamp({ at = CHEST, size = 4.5, tex = "ASHOCK", lifetime = 0.05 }),
			B.star({ at = CHEST, size = 7, lifetime = 0.2, rotation = { 40, 50 } }),
			B.shockwave({ at = CHEST, size = 5, tex = "THINRING", lifetime = 0.2 }),
			B.sparks({ at = CHEST, count = 28, speed = { 40, 95 }, spread = { 55, 55 }, size = 0.32, gravity = { 0, -55, 0 } }),
			B.specks({ at = CHEST, count = 8, speed = { 6, 14 }, lifetime = { 0.4, 0.8 } }),
			B.light({ at = CHEST, brightness = 5, range = 12, life = 0.25 }),
		} })
	end })
add({ id = "uppercut", title = "Uppercut Launch", category = "Combat", tags = "uppercut launch rising air juggle", shake = { amp = 0.4, dur = 0.3 },
	blurb = "Rising rings and streaks that launch upward",
	build = function()
		return B.spec({ name = "UppercutLaunch", palette = PAL.energy, layers = {
			B.stamp({ at = { 0, 2.5, -1.5 }, size = 6 }),
			B.flash({ at = { 0, 2.5, -1.5 }, size = 5 }),
			B.windRing({ at = { 0, 1.5, -1.5 }, size = 5, lifetime = 0.35 }),
			B.shockburst({ at = { 0, 3, -1.5 }, dir = "Top", size = 8, count = 4 }),
			B.windRing({ id = "ring2", t = 0.05, at = { 0, 4, -1.5 }, size = 6.5, lifetime = 0.4 }),
			B.windRing({ id = "ring3", t = 0.1, at = { 0, 6.5, -1.5 }, size = 8, lifetime = 0.45 }),
			B.streaks({ at = { 0, 2, -1.5 }, dir = "Top", spread = { 12, 12 }, speed = { 90, 150 }, count = 14, size = 2 }),
			B.sparks({ at = { 0, 2, -1.5 }, dir = "Top", spread = { 25, 25 }, count = 12 }),
			B.dust({ at = { 0, 0.2, -1.5 }, count = 6, size = 2.2 }),
			B.light({ at = { 0, 3, -1.5 }, brightness = 5, range = 14 }),
		} })
	end })
add({ id = "shockwave", title = "Shockwave", category = "Combat", tags = "shockwave blast ring stomp aoe wave", shake = { amp = 0.6, dur = 0.4 },
	blurb = "Wide ring racing over the ground, dome and dust wall",
	build = function()
		return B.spec({ name = "Shockwave", palette = PAL.energy, layers = {
			B.flash({ at = { 0, 1.2, 0 }, size = 8 }),
			B.stamp({ at = { 0, 1.2, 0 }, size = 9 }),
			B.sphere({ at = { 0, 0, 0 }, size = 16, life = 0.45 }),
			B.shockburst({ at = { 0, 0.4, 0 }, dir = "Top", size = 22, count = 3, lifetime = { 0.3, 0.42 } }),
			B.plume({ at = { 0, 0.6, 0 }, size = 6, count = 6, speed = { 6, 14 }, spread = { 85, 85 } }),
			B.ring({ size = 24, lifetime = 0.75 }),
			B.ring({ id = "shockRing", t = 0.06, size = 17, tex = "SHOCKRING", le = 0.7, lifetime = 0.6 }),
			B.dust({ at = { 0, 0.3, 0 }, count = 18, size = 4.5, speed = { 22, 42 } }),
			B.sparks({ at = { 0, 1, 0 }, count = 14, spread = { 80, 80 } }),
			B.grade({}),
			B.light({ at = { 0, 2, 0 }, brightness = 7, range = 26, life = 0.5 }),
		} })
	end })
add({ id = "groundpound", title = "Crater Slam", category = "Combat", tags = "crater slam rocks earth smash ground pound", shake = { amp = 0.9, dur = 0.5 },
	blurb = "Rock spikes burst from a cracked crater, debris and dust",
	build = function()
		return B.spec({ name = "CraterSlam", palette = PAL.earth, layers = {
			B.inkFlash({ at = { 0, 1.5, 0 }, size = 9 }),
			B.stamp({ at = { 0, 1.5, 0 }, size = 10 }),
			B.flash({ at = { 0, 1.5, 0 }, size = 8 }),
			B.shockburst({ at = { 0, 0.4, 0 }, dir = "Top", size = 16, count = 3 }),
			B.plume({ at = { 0, 0.8, 0 }, size = 6.5, count = 6, speed = { 4, 12 } }),
			B.decalDisc({ tex = "CRACKSTAR", size = 17, color = "ink", life = 2.6, fade = { { 0, 0.1 }, { 0.7, 0.2 }, { 1, 1 } } }),
			B.spikes({ count = 10, radius = 5.5, height = 4.5, lean = 38, hot = false, deepColor = "deep", bodyColor = "body", tipColor = "core", life = 1.8 }),
			B.ring({ size = 15, color = "core", le = 0.5, lifetime = 0.55 }),
			B.debris({ count = 16, speed = { 25, 45 } }),
			B.dust({ count = 16, size = 5, speed = { 18, 36 } }),
			B.smoke({ count = 6, size = 6, at = { 0, 1, 0 } }),
			B.light({ at = { 0, 2, 0 }, color = "core", brightness = 5, range = 18 }),
		} })
	end })
add({ id = "thrust", title = "Spear Thrust", category = "Combat", tags = "thrust stab spear lance pierce rapier",
	blurb = "Piercing streak cone with a ring at the tip",
	build = function()
		return B.spec({ name = "SpearThrust", palette = PAL.energy, layers = {
			B.streaks({ at = { 0, 3, -1 }, dir = "Front", spread = { 7, 7 }, speed = { 130, 210 }, count = 12, size = 2.4 }),
			B.windRing({ at = { 0, 3, -3 }, size = 4, dir = "Front", lifetime = 0.25 }),
			B.stamp({ at = { 0, 3, -7 }, size = 5.5 }),
			B.flash({ at = { 0, 3, -7 }, size = 4.5 }),
			B.shockwave({ at = { 0, 3, -7 }, size = 6, lifetime = 0.22 }),
			B.shockburst({ at = { 0, 3, -7 }, dir = "Front", size = 7, count = 4 }),
			B.sparks({ at = { 0, 3, -7 }, dir = "Front", spread = { 45, 45 }, count = 12 }),
			B.light({ at = { 0, 3, -6 }, brightness = 5, range = 12 }),
		} })
	end })
add({ id = "xslash", title = "Cross Slash", category = "Combat", tags = "x slash cross double sword combo",
	blurb = "Two crossing slashes and a hit spark",
	combo = { { base = "slash", t = 0, roll = 40 }, { base = "slash", t = 0.09, roll = -40 }, { base = "hitspark", t = 0.14, at = { 0, 0, -3 } } } })
add({ id = "slashcombo", title = "Slash Combo", category = "Combat", tags = "combo triple slash sword finisher",
	blurb = "Three slashes, then a critical finisher",
	combo = { { base = "slash", t = 0, roll = -30 }, { base = "slash", t = 0.16, roll = 30 }, { base = "slash", t = 0.32, roll = 0, scale = 1.2 },
		{ base = "critical", t = 0.4, scale = 0.8 } } })

------------------------------------------------------------------------------------------------------- ELEMENTS
add({ id = "explosion", title = "Explosion", category = "Elements", recipe = "explosion", tags = "explosion boom blast bomb fireball",
	blurb = "Flash, fireball body, shock rings, smoke column, embers", shake = { amp = 0.8, dur = 0.5 } })
add({ id = "fire", title = "Fire Eruption", category = "Elements", recipe = "fire", tags = "fire flame burn eruption",
	blurb = "Ignition flash, rising flames, cooling smoke and embers" })
add({ id = "lightning", title = "Lightning Strike", category = "Elements", recipe = "lightning", tags = "lightning thunder strike bolt electric",
	blurb = "Ink frame, bolts with re-strikes, arcs, crack glints", shake = { amp = 0.6, dur = 0.35 } })
add({ id = "icewater", title = "Frost Burst", category = "Elements", recipe = "icewater", tags = "ice frost freeze cold burst water",
	blurb = "Crisp flash, ice crown, whirl rings, frost on the ground" })
add({ id = "projectile", title = "Projectile", category = "Elements", recipe = "projectile", tags = "projectile orb fireball shot bullet",
	blurb = "Launch flash, travelling orb with trail, contact burst" })
add({ id = "flamejet", title = "Flame Jet", category = "Elements", tags = "flamethrower fire breath jet stream dragon",
	blurb = "A forward stream of fire with smoke and embers",
	build = function()
		local at = { 0, 3, -1.5 }
		return B.spec({ name = "FlameJet", palette = PAL.fire, layers = {
			B.flames({ at = at, life = 1.3, box = { 0.6, 0.6, 0.6 }, size = 3.4, rateTrack = { { 0, 150 }, { 1.2, 150 }, { 1.25, 0 } },
				props = { EmissionDirection = "Front", SpreadAngle = { 9, 9 }, Speed = { 38, 52 }, Drag = 2.2, Acceleration = { 0, 5, 0 },
					Orientation = "FacingCamera", Rotation = { -360, 360 }, Size = { { 0, 0.7 }, { 0.35, 2.6 }, { 1, 3.8 } },
					Lifetime = { 0.45, 0.6 } } }),
			B.smoke({ at = { 0, 3.5, -9 }, count = 10, size = 6, emit = { { 0.25, 10, 1.1 } }, color = "deep", le = 0.1 }),
			B.embers({ at = { 0, 3, -6 }, count = 26, emit = { { 0.1, 26, 1.2 } }, spread = { 50, 50 } }),
			{ id = "flicker", kind = "light", t = 0, life = 1.35, at = { 0, 3, -5 }, props = { Color = "body", Range = 22, Brightness = 0 },
				tracks = { Brightness = { { 0, 0 }, { 0.1, 6 }, { 0.3, 4 }, { 0.5, 6.5 }, { 0.7, 4.5 }, { 0.9, 6 }, { 1.2, 5 }, { 1.35, 0 } } } },
		} })
	end })
add({ id = "firepillar", title = "Fire Pillar", category = "Elements", tags = "fire pillar column flame geyser inferno",
	blurb = "A roaring column of fire with a scorched base",
	build = function()
		return B.spec({ name = "FirePillar", palette = PAL.fire, layers = {
			B.flash({ at = { 0, 1, 0 }, size = 7 }),
			B.flames({ life = 1.1, box = { 2.6, 0.3, 2.6 }, size = 4, speed = { 34, 48 }, lift = 18, lifetime = { 0.55, 0.85 },
				rateTrack = { { 0, 150 }, { 0.95, 150 }, { 1.05, 0 } } }),
			B.flames({ id = "baseFire", life = 1.1, box = { 4, 0.3, 4 }, size = 3, speed = { 6, 12 }, lift = 5,
				rateTrack = { { 0, 60 }, { 0.95, 60 }, { 1.05, 0 } } }),
			B.ring({ size = 10, color = "core", lifetime = 0.5 }),
			B.decalDisc({ tex = "CRACKSTAR", size = 11, color = "ink", life = 2.4, fade = { { 0, 0.15 }, { 0.75, 0.25 }, { 1, 1 } } }),
			B.embers({ at = { 0, 4, 0 }, count = 30, emit = { { 0.1, 30, 1.2 } }, speed = { 8, 18 }, lift = 8 }),
			B.smoke({ at = { 0, 14, 0 }, count = 8, size = 7, emit = { { 0.5, 8, 0.8 } } }),
			B.light({ at = { 0, 5, 0 }, brightness = 7, range = 26, life = 1.2 }),
		} })
	end })
add({ id = "meteorfall", hidden = true, title = "Meteor Fall", category = "Elements",
	build = function()
		local path = { { 0, { 26, 70, 34 } }, { 0.55, { 0, 1.5, 0 }, "quadIn" } }
		return B.spec({ name = "MeteorFall", palette = PAL.fire, layers = {
			B.mover({ life = 0.56, size = 4.2, color = "core", path = path }),
			B.trail({ life = 0.56, path = path, size = 3.2 }),
			B.trail({ id = "smokeTrail", life = 0.56, path = path, size = 4, tex = "SMOKE", color = "smoke", le = 0.1, lifetime = { 0.6, 0.9 } }),
		} })
	end })
add({ id = "meteor", title = "Meteor Strike", category = "Elements", tags = "meteor comet asteroid strike sky fall", shake = { amp = 1, dur = 0.6, t = 0.55 },
	blurb = "A burning rock falls from the sky and craters the ground",
	combo = { { base = "meteorfall", t = 0 }, { base = "explosion", t = 0.55 }, { base = "groundpound", t = 0.55, scale = 0.8 } } })
add({ id = "electricburst", title = "Electric Burst", category = "Elements", tags = "electric shock zap crackle static plasma",
	blurb = "Crackling bolts around the target with sparks",
	build = function()
		return B.spec({ name = "ElectricBurst", palette = PAL.electric, layers = {
			B.flash({ at = CHEST, size = 5 }),
			B.bolts({ at = CHEST, box = { 6, 5, 6 }, size = 4.5, life = 0.7, strikes = emits(0, 0.6, 0.06, 2) }),
			B.sparks({ at = CHEST, count = 18, spread = { 180, 180 }, speed = { 25, 60 } }),
			B.ring({ size = 9, color = "core", lifetime = 0.45 }),
			B.specks({ at = CHEST, count = 12, lifetime = { 0.4, 0.9 } }),
			{ id = "flicker", kind = "light", t = 0, life = 0.7, at = CHEST, props = { Color = "body", Range = 18, Brightness = 0 },
				tracks = { Brightness = { { 0, 8 }, { 0.05, 2 }, { 0.12, 7 }, { 0.2, 1 }, { 0.3, 6 }, { 0.45, 2 }, { 0.55, 5 }, { 0.7, 0 } } } },
		} })
	end })
add({ id = "thunder", title = "Thunder Pillar", category = "Elements", tags = "thunder pillar lightning sky judgment strike", shake = { amp = 0.9, dur = 0.4 },
	blurb = "A bolt column from the sky with a scorched blast",
	build = function()
		return B.spec({ name = "ThunderPillar", palette = PAL.electric, layers = {
			B.pillar({ height = 60, width = 6, color = "body", life = 0.4 }),
			B.bolts({ at = { 0, 12, 0 }, size = 14, life = 0.3 }),
			B.flash({ at = { 0, 1.5, 0 }, size = 9 }),
			B.shockwave({ at = { 0, 2, 0 }, size = 12 }),
			B.ring({ size = 16, color = "core" }),
			B.decalDisc({ tex = "CRACKSTAR", size = 12, color = "ink", life = 2.2, fade = { { 0, 0.1 }, { 0.7, 0.2 }, { 1, 1 } } }),
			B.sparks({ at = { 0, 1, 0 }, count = 20, spread = { 80, 80 } }),
			B.grade({ brightness = 0.25, contrast = 0.3 }),
			B.light({ at = { 0, 6, 0 }, brightness = 10, range = 30, life = 0.4 }),
		} })
	end })
add({ id = "icespikes", title = "Ice Spikes", category = "Elements", tags = "ice spikes crystal frost erupt shards",
	blurb = "Faceted ice spikes erupt in a ring, with frost mist",
	build = function()
		return B.spec({ name = "IceSpikes", palette = PAL.ice, layers = {
			B.flash({ at = { 0, 1.5, 0 }, size = 6 }),
			B.spikes({ count = 11, radius = 5, height = 7, lean = 18, life = 1.9 }),
			B.ring({ size = 12, color = "core", lifetime = 0.5 }),
			B.smoke({ at = { 0, 1, 0 }, count = 7, size = 6, color = "smoke", le = 0.45, speed = { 3, 8 } }),
			B.specks({ at = { 0, 2, 0 }, count = 16, color = "white" }),
			B.light({ at = { 0, 3, 0 }, brightness = 5, range = 16 }),
		} })
	end })
add({ id = "watersplash", title = "Water Splash", category = "Elements", tags = "water splash wave liquid drop aqua",
	blurb = "A splash crown with droplets and ripples",
	build = function()
		return B.spec({ name = "WaterSplash", palette = PAL.water, layers = {
			B.splash({ at = { 0, 2.5, 0 }, size = 6 }),
			B.droplets({ at = { 0, 1, 0 }, count = 24 }),
			B.ring({ tex = "THINRING", size = 9, color = "core", le = 0.6, lifetime = 0.6 }),
			B.ring({ id = "ripple", t = 0.18, tex = "THINRING", size = 14, color = "core", le = 0.5, lifetime = 0.8 }),
			B.smoke({ at = { 0, 1.2, 0 }, count = 5, size = 4.5, color = "white", le = 0.35, speed = { 3, 7 } }),
		} })
	end })
add({ id = "tornado", title = "Tornado", category = "Elements", tags = "tornado wind cyclone whirlwind vortex twister",
	blurb = "A dusty funnel that widens upward, with spinning wind bands",
	build = function()
		local layers = {}
		-- the funnel: dust rising, widening and spinning (reads in daylight because it is darker than the sky)
		table.insert(layers, B.smoke({ id = "funnel", at = { 0, 0.4, 0 }, tex = "SMOKE", count = 70, color = "deep", le = 0.08,
			speed = { 15, 22 }, spread = { 10, 10 }, gravity = { 0, 3, 0 }, lifetime = { 1.1, 1.5 }, emit = { { 0, 70, 2.3 } },
			props = { RotSpeed = { 200, 320 }, Drag = 0.6, Size = { { 0, 1.2 }, { 0.5, 4.5 }, { 1, 8 } },
				Transparency = { { 0, 0.35 }, { 0.6, 0.5 }, { 1, 1 } } } }))
		table.insert(layers, B.smoke({ id = "funnelLight", at = { 0, 0.4, 0 }, tex = "SMOKE", count = 40, color = "smoke", le = 0.2,
			speed = { 14, 20 }, spread = { 14, 14 }, gravity = { 0, 3, 0 }, lifetime = { 1, 1.4 }, emit = { { 0.05, 40, 2.25 } },
			props = { RotSpeed = { -320, -200 }, Drag = 0.6, Size = { { 0, 1.5 }, { 0.5, 5 }, { 1, 9 } },
				Transparency = { { 0, 0.5 }, { 0.6, 0.6 }, { 1, 1 } } } }))
		for i = 0, 5 do
			local h = 2 + i * 3.2
			table.insert(layers, B.windRing({ id = "band" .. i, at = { 0, h, 0 }, size = 3.5 + i * 2.1, le = 0.35, brightness = 1.5,
				color = if i % 2 == 0 then "deep" else "core", lifetime = 0.32, rotSpeed = { 700, 900 },
				emit = emits(i * 0.02, 2.3, 0.1) }))
		end
		table.insert(layers, B.dust({ at = { 0, 0.3, 0 }, count = 40, size = 5, emit = { { 0, 40, 2.3 } } }))
		table.insert(layers, B.debris({ at = { 0, 1, 0 }, count = 16, speed = { 20, 32 }, spread = { 25, 25 }, emit = { { 0.1, 16, 2 } } }))
		return B.spec({ name = "Tornado", palette = PAL.wind, layers = layers })
	end })
add({ id = "windgust", title = "Wind Gust", category = "Elements", tags = "wind gust push blow air breeze",
	blurb = "Forward wind rings with streaks and dust",
	build = function()
		return B.spec({ name = "WindGust", palette = PAL.wind, layers = {
			B.windRing({ at = { 0, 3, -2 }, dir = "Front", size = 4, lifetime = 0.35 }),
			B.windRing({ id = "r2", t = 0.06, at = { 0, 3, -6 }, dir = "Front", size = 5.5, lifetime = 0.4 }),
			B.windRing({ id = "r3", t = 0.12, at = { 0, 3, -10 }, dir = "Front", size = 7, lifetime = 0.45 }),
			B.streaks({ at = { 0, 3, -2 }, dir = "Front", spread = { 18, 18 }, speed = { 60, 100 }, count = 14, color = "white" }),
			B.dust({ at = { 0, 0.2, -4 }, count = 8, size = 3 }),
		} })
	end })
add({ id = "poison", title = "Poison Cloud", category = "Elements", tags = "poison toxic gas cloud acid venom",
	blurb = "A lingering toxic cloud with bubbles",
	build = function()
		return B.spec({ name = "PoisonCloud", palette = PAL.toxic, layers = {
			B.smoke({ at = { 0, 1.5, 0 }, count = 12, size = 7, color = "body", le = 0.45, speed = { 1, 4 }, spread = { 90, 90 },
				lifetime = { 2.2, 3.2 }, gravity = { 0, 0.4, 0 }, emit = { { 0, 12, 0.8 } } }),
			B.smoke({ id = "darkCore", at = { 0, 1, 0 }, count = 6, size = 5, color = "deep", le = 0.1, speed = { 1, 3 },
				lifetime = { 1.8, 2.6 }, emit = { { 0.1, 6, 0.6 } } }),
			B.rise({ tex = "SPEC", radius = 4, count = 26, over = 2, color = "accent", size = 0.4, lift = 2 }),
			B.ring({ size = 9, color = "body", le = 0.4, lifetime = 0.8 }),
		} })
	end })

---------------------------------------------------------------------------------------------------------- MAGIC
add({ id = "aura", title = "Aura Charge", category = "Magic", recipe = "aura", tags = "aura charge power up transform ki",
	blurb = "Building aura, swirl pulling in, release burst" })
add({ id = "beam", title = "Beam", category = "Magic", recipe = "beam", tags = "beam laser ray cannon kamehameha",
	blurb = "Charge, hitscan beam with core line, impact, smoke" })
add({ id = "darkportal", title = "Void Breach", category = "Magic", recipe = "darkportal", tags = "void dark portal rift shadow curse",
	blurb = "Ink punch, dark body in waves, rings, void fog" })
add({ id = "misc", title = "Holy Burst", category = "Magic", recipe = "misc", tags = "holy light divine angel bless radiant",
	blurb = "Radiant flash, halo and rays, drifting motes" })
add({ id = "heal", title = "Heal", category = "Magic", tags = "heal health regen restore cure",
	blurb = "Rising sparkles, a soft healing circle and glow",
	build = function()
		return B.spec({ name = "Heal", palette = PAL.nature, layers = {
			B.decalDisc({ size = 9, life = 1.6, spin = { 0, 30, 0 }, color = "body" }),
			B.rise({ count = 28, over = 0.9, radius = 2.5 }),
			B.ring({ size = 7, color = "body", lifetime = 0.6 }),
			B.bloom({ at = { 0, 2.5, 0 }, size = 6, alpha = 0.55, lifetime = 0.9 }),
			B.specks({ at = { 0, 2, 0 }, count = 10, tex = "SPARKLE", size = 0.45 }),
			B.light({ at = { 0, 2.5, 0 }, brightness = 3, range = 12, life = 1 }),
		} })
	end })
add({ id = "buff", title = "Power Buff", category = "Magic", tags = "buff power up strength boost enrage",
	blurb = "Rising rings and streaks that power you up",
	build = function()
		return B.spec({ name = "PowerBuff", palette = PAL.fire, layers = {
			B.flash({ at = { 0, 3, 0 }, size = 5 }),
			B.ring({ size = 9, lifetime = 0.5 }),
			B.windRing({ at = { 0, 0.6, 0 }, size = 4.5, lifetime = 0.5 }),
			B.windRing({ id = "r2", t = 0.1, at = { 0, 2.8, 0 }, size = 4, lifetime = 0.5 }),
			B.rise({ tex = "STREAK", count = 26, over = 0.6, radius = 2, speed = { 8, 14 }, size = 0.7,
				props = { Orientation = "VelocityParallel", Squash = { { 0, 3 }, { 1, 2 } } } }),
			B.bloom({ at = { 0, 3, 0 }, size = 7, alpha = 0.5 }),
			B.light({ at = { 0, 3, 0 }, brightness = 5, range = 14, life = 0.7 }),
		} })
	end })
add({ id = "shield", title = "Shield Bubble", category = "Magic", tags = "shield barrier bubble protect forcefield block",
	blurb = "An energy bubble that holds, then pops",
	build = function()
		return B.spec({ name = "ShieldBubble", palette = PAL.energy, layers = {
			B.sphere({ at = { 0, 3, 0 }, size = 10, life = 2.3,
				scale = { { 0, 0.2 }, { 0.12, 1.06, "backOut" }, { 0.9, 1 }, { 1, 1.18, "quadIn" } },
				fade = { { 0, 0 }, { 0.88, 0.05 }, { 1, 1 } } }),
			B.ring({ tex = "THINRING", size = 7, color = "core", lifetime = 0.5 }),
			B.flash({ t = 2.05, at = { 0, 3, 0 }, size = 6 }),
			B.specks({ t = 2.05, at = { 0, 3, 0 }, count = 22, speed = { 10, 22 } }),
			B.light({ at = { 0, 3, 0 }, brightness = 3, range = 14, life = 2.3,
				tracks = { Brightness = { { 0, 4 }, { 0.3, 2.5 }, { 2.0, 2.5 }, { 2.1, 6 }, { 2.3, 0 } } } }),
		} })
	end })
add({ id = "magiccircle", title = "Summoning Circle", category = "Magic", tags = "magic circle summon rune ritual sigil",
	blurb = "Two spinning rune circles, then a pillar of light",
	build = function()
		return B.spec({ name = "SummoningCircle", palette = PAL.void, layers = {
			B.decalDisc({ size = 16, life = 2.6, spin = { 0, 25, 0 }, color = "body" }),
			B.decalDisc({ id = "inner", t = 0.12, size = 10.5, life = 2.4, spin = { 0, -45, 0 }, color = "accent" }),
			B.rise({ count = 34, over = 1.3, radius = 6, size = 0.4 }),
			B.pillar({ t = 0.6, height = 34, width = 4.5, color = "core", life = 0.9 }),
			B.flash({ t = 0.6, at = { 0, 2, 0 }, size = 7 }),
			B.ring({ t = 0.6, size = 15 }),
			B.light({ t = 0.6, at = { 0, 4, 0 }, brightness = 7, range = 24, life = 0.9 }),
		} })
	end })
add({ id = "teleport", title = "Teleport", category = "Magic", tags = "teleport blink warp vanish appear dash",
	blurb = "A light column, ring and sparkles with a puff",
	build = function()
		return B.spec({ name = "Teleport", palette = PAL.energy, layers = {
			B.pillar({ height = 14, width = 3.5, life = 0.5 }),
			B.flash({ at = { 0, 3, 0 }, size = 5 }),
			B.ring({ size = 8, lifetime = 0.45 }),
			B.windRing({ at = { 0, 1, 0 }, size = 4.5, lifetime = 0.4 }),
			B.specks({ at = { 0, 3, 0 }, count = 22, speed = { 6, 16 } }),
			B.smoke({ tex = "TOONSMOKE", at = { 0, 1.5, 0 }, count = 6, size = 3.5, color = "white", le = 0.5, speed = { 4, 9 },
				lifetime = { 0.5, 0.8 }, spread = { 180, 180 } }),
			B.light({ at = { 0, 3, 0 }, brightness = 5, range = 14 }),
		} })
	end })
add({ id = "blackhole", title = "Black Hole", category = "Magic", tags = "black hole singularity gravity void collapse vortex",
	blurb = "A dark core pulls everything in, then collapses", shake = { amp = 0.5, dur = 0.4, t = 2.1 },
	build = function()
		local at = { 0, 4, 0 }
		return B.spec({ name = "BlackHole", palette = PAL.void, layers = {
			B.sphere({ at = at, size = 5.5, life = 2.25, material = "Neon", color = "ink",
				scale = { { 0, 0.1 }, { 0.11, 1, "backOut" }, { 0.89, 1.12 }, { 1, 0, "backIn" } }, fade = { { 0, 0 }, { 1, 0 } } }),
			B.sphere({ id = "rim", at = at, size = 7, life = 2.25, color = "body",
				scale = { { 0, 0.1 }, { 0.13, 1, "backOut" }, { 0.89, 1.1 }, { 1, 0, "backIn" } }, fade = { { 0, 0.2 }, { 1, 0.4 } } }),
			B.swirl({ at = at, size = 13, orientation = "FacingCamera", rotSpeed = { 280, 400 }, emit = emits(0, 1.9, 0.3, 1) }),
			B.windRing({ at = at, size = 10, orientation = "FacingCamera", le = 0.8, emit = emits(0.1, 1.9, 0.25) }),
			B.specks({ at = at, count = 50, emit = { { 0, 50, 1.9 } }, lifetime = { 0.6, 0.9 },
				props = { Shape = "Sphere", ShapeInOut = "Inward", ShapeStyle = "Surface", Speed = { 14, 22 }, Drag = 0, Acceleration = { 0, 0, 0 } },
				box = { 22, 22, 22 } }),
			B.grade({ life = 2.2, brightness = -0.05, contrast = 0.2, saturation = -0.35,
				tracks = { Saturation = { { 0, 0 }, { 0.4, -0.35 }, { 2.0, -0.4 }, { 2.2, 0 } }, Brightness = { { 0, 0 }, { 0.4, -0.06 }, { 2.2, 0 } } } }),
			B.flash({ t = 2.12, at = at, size = 9 }),
			B.shockwave({ t = 2.12, at = at, size = 14 }),
			B.light({ at = at, brightness = 4, range = 20, life = 2.4, tracks = { Brightness = { { 0, 0 }, { 0.4, 3 }, { 2.1, 4 }, { 2.15, 9 }, { 2.4, 0 } } } }),
		} })
	end })
add({ id = "holybeam", title = "Holy Pillar", category = "Magic", tags = "holy pillar heaven light beam judgment divine",
	blurb = "A beam of light from the sky with rays and motes",
	build = function()
		return B.spec({ name = "HolyPillar", palette = PAL.holy, layers = {
			B.pillar({ height = 70, width = 7, color = "core", life = 1.2 }),
			B.rays({ at = { 0, 2, 0 }, size = 16, lifetime = 0.9 }),
			B.ring({ size = 13, color = "core", lifetime = 0.7 }),
			B.rise({ count = 30, over = 1, radius = 4, color = "core" }),
			B.flash({ at = { 0, 2, 0 }, size = 7 }),
			B.grade({ brightness = 0.12, contrast = 0.1, saturation = 0.1 }),
			B.light({ at = { 0, 5, 0 }, brightness = 7, range = 28, life = 1.2 }),
		} })
	end })
add({ id = "chargeball", title = "Energy Charge", category = "Magic", tags = "charge orb energy ball spirit bomb gather",
	blurb = "An orb gathers energy, then releases in a burst",
	build = function()
		local at = { 0, 3.5, -2 }
		return B.spec({ name = "EnergyCharge", palette = PAL.energy, layers = {
			B.sphere({ at = at, size = 3.2, life = 1.12, material = "Neon", color = "core",
				scale = { { 0, 0.1 }, { 0.89, 1, "quadIn" }, { 1, 0, "quadIn" } }, fade = { { 0, 0 }, { 1, 0 } } }),
			B.sphere({ id = "shell", at = at, size = 5, life = 1.12, color = "body",
				scale = { { 0, 0.1 }, { 0.89, 1, "quadIn" }, { 1, 1.5 } }, fade = { { 0, 0.3 }, { 0.89, 0.1 }, { 1, 1 } } }),
			B.specks({ at = at, count = 40, emit = { { 0, 40, 0.95 } }, lifetime = { 0.45, 0.6 },
				props = { Shape = "Sphere", ShapeInOut = "Inward", ShapeStyle = "Surface", Speed = { 12, 18 }, Drag = 0, Acceleration = { 0, 0, 0 } },
				box = { 14, 14, 14 } }),
			B.orbit({ at = at, count = 4, emit = emits(0, 0.9, 0.3, 2), size = 3 }),
			B.flash({ t = 1.05, at = at, size = 8 }),
			B.shockwave({ t = 1.05, at = at, size = 11 }),
			B.sparks({ t = 1.05, at = at, count = 18, spread = { 180, 180 } }),
			B.light({ at = at, brightness = 6, range = 16, life = 1.3,
				tracks = { Brightness = { { 0, 0 }, { 1.0, 5 }, { 1.06, 10 }, { 1.3, 0 } } } }),
		} })
	end })
add({ id = "spellcast", title = "Spell Cast", category = "Magic", tags = "spell cast hand magic wand quick",
	blurb = "A quick rune flare at the hand",
	build = function()
		local at = { 0, 3, -1.5 }
		return B.spec({ name = "SpellCast", palette = PAL.void, layers = {
			B.star({ at = at, size = 4, lifetime = 0.22 }),
			B.flash({ at = at, size = 3 }),
			B.windRing({ at = at, size = 3, orientation = "FacingCamera", lifetime = 0.35 }),
			B.specks({ at = at, count = 14, speed = { 6, 12 }, lifetime = { 0.4, 0.8 } }),
			B.light({ at = at, brightness = 4, range = 10, life = 0.4 }),
		} })
	end })

-------------------------------------------------------------------------------------------------------- MOVEMENT
add({ id = "dash", title = "Dash Burst", category = "Movement", tags = "dash sprint rush speed burst air",
	blurb = "Wind rings along the dash with speed lines",
	build = function()
		return B.spec({ name = "DashBurst", palette = PAL.wind, layers = {
			B.windRing({ at = { 0, 3, 0 }, dir = "Front", size = 3.5, lifetime = 0.3 }),
			B.windRing({ id = "r2", t = 0.04, at = { 0, 3, -4 }, dir = "Front", size = 4.2, lifetime = 0.32 }),
			B.windRing({ id = "r3", t = 0.08, at = { 0, 3, -8 }, dir = "Front", size = 5, lifetime = 0.35 }),
			B.streaks({ at = { 0, 3, -2 }, dir = "Back", spread = { 14, 14 }, speed = { 70, 110 }, count = 14 }),
			B.dust({ at = { 0, 0.2, 0 }, count = 7, size = 2.6 }),
			B.puff({ at = { 0, 0.5, 0.5 }, size = 2, count = 3, dir = "Back", spread = { 40, 40 }, speed = { 6, 12 } }),
		} })
	end })
add({ id = "speedboost", title = "Speed Boost", category = "Movement", tags = "speed boost haste fast sprint",
	blurb = "Rushing wind around you",
	build = function()
		return B.spec({ name = "SpeedBoost", palette = PAL.energy, layers = {
			B.streaks({ at = { 0, 3, 0 }, box = { 4, 5, 4 }, dir = "Back", spread = { 5, 5 }, speed = { 40, 70 }, count = 30,
				emit = { { 0, 30, 0.8 } }, size = 1.2 }),
			B.windRing({ at = { 0, 3, 0 }, dir = "Front", size = 4, emit = emits(0, 0.7, 0.18) }),
			B.specks({ at = { 0, 2, 0 }, count = 12 }),
		} })
	end })
add({ id = "landing", title = "Landing Dust", category = "Movement", tags = "landing land jump fall dust heavy",
	blurb = "A dust ring and pebbles where you land",
	build = function()
		return B.spec({ name = "LandingDust", palette = PAL.earth, layers = {
			B.dust({ count = 12, size = 3 }),
			B.ring({ tex = "THINRING", size = 6, color = "smoke", le = 0.2, lifetime = 0.4 }),
			B.shockburst({ at = { 0, 0.3, 0 }, dir = "Top", size = 7, count = 4, color = "smoke", le = 0.2 }),
			B.puff({ at = { 0, 0.4, 0 }, size = 2.4, count = 4, spread = { 80, 80 }, speed = { 5, 11 } }),
			B.debris({ count = 6, size = 0.35, speed = { 10, 20 } }),
		} })
	end })
add({ id = "footstep", title = "Footstep Puff", category = "Movement", tags = "footstep step walk run dust puff",
	blurb = "A small puff for each step",
	build = function()
		return B.spec({ name = "FootstepPuff", palette = PAL.earth, layers = {
			B.dust({ count = 4, size = 1.4, speed = { 4, 8 }, lifetime = { 0.4, 0.7 } }),
		} })
	end })
add({ id = "doublejump", title = "Double Jump", category = "Movement", tags = "double jump air jump hop wings",
	blurb = "A burst ring under your feet in mid-air",
	build = function()
		return B.spec({ name = "DoubleJump", palette = PAL.wind, layers = {
			B.windRing({ at = { 0, 0, 0 }, size = 4.5, lifetime = 0.35 }),
			B.ring({ tex = "THINRING", size = 5.5, lifetime = 0.35 }),
			B.specks({ count = 10, dir = "Bottom", spread = { 50, 50 }, speed = { 8, 14 }, lifetime = { 0.3, 0.6 } }),
		} })
	end })

------------------------------------------------------------------------------------------------------- GAME FEEL
add({ id = "levelup", title = "Level Up", category = "Game feel", tags = "level up rank promotion upgrade achievement",
	blurb = "Light column, rising sparkles and a star burst",
	build = function()
		return B.spec({ name = "LevelUp", palette = PAL.holy, layers = {
			B.pillar({ height = 22, width = 3, life = 0.8 }),
			B.ring({ size = 11 }),
			B.windRing({ at = { 0, 1, 0 }, size = 5, lifetime = 0.6, emit = { { 0, 1 }, { 0.15, 1 } } }),
			B.rise({ count = 40, over = 1, radius = 3 }),
			B.flash({ at = { 0, 3, 0 }, size = 6 }),
			B.star({ t = 0.1, at = { 0, 4, 0 }, size = 8, tex = "SPARKLE", lifetime = 0.5 }),
			B.specks({ t = 0.1, at = { 0, 4, 0 }, count = 24, speed = { 10, 22 } }),
			B.light({ at = { 0, 3, 0 }, brightness = 6, range = 20, life = 1 }),
		} })
	end })
add({ id = "pickup", title = "Coin Pickup", category = "Game feel", tags = "coin pickup collect gem item sparkle reward",
	blurb = "A bright pop of sparkles",
	build = function()
		local at = { 0, 2, 0 }
		return B.spec({ name = "CoinPickup", palette = PAL.holy, layers = {
			B.flash({ at = at, size = 2.5, lifetime = 0.07 }),
			B.star({ at = at, size = 3.2, tex = "SPARKLE", lifetime = 0.3 }),
			B.ring({ at = at, tex = "THINRING", size = 3, lifetime = 0.3, props = { Orientation = "FacingCamera" } }),
			B.specks({ at = at, count = 10, speed = { 6, 12 }, size = 0.25, lifetime = { 0.4, 0.8 } }),
		} })
	end })
add({ id = "spawn", title = "Spawn In", category = "Game feel", tags = "spawn respawn appear arrive portal in",
	blurb = "A light column and ring as you appear",
	build = function()
		return B.spec({ name = "SpawnIn", palette = PAL.energy, layers = {
			B.pillar({ height = 16, width = 4.2, life = 0.75 }),
			B.ring({ size = 9 }),
			B.rise({ count = 24, over = 0.6, radius = 2.5 }),
			B.flash({ t = 0.05, at = { 0, 3, 0 }, size = 5 }),
			B.light({ at = { 0, 3, 0 }, brightness = 5, range = 16, life = 0.8 }),
		} })
	end })
add({ id = "checkpoint", title = "Checkpoint", category = "Game feel", tags = "checkpoint save flag reach goal",
	blurb = "A clean ring and rising lights",
	build = function()
		return B.spec({ name = "Checkpoint", palette = PAL.nature, layers = {
			B.ring({ size = 8 }),
			B.ring({ id = "r2", t = 0.15, size = 11, tex = "THINRING" }),
			B.rise({ count = 22, over = 0.7, radius = 3.5, tex = "SPEC" }),
			B.star({ at = { 0, 3, 0 }, size = 5, lifetime = 0.35 }),
			B.light({ at = { 0, 3, 0 }, brightness = 4, range = 14, life = 0.8 }),
		} })
	end })
add({ id = "defeat", title = "Defeat Poof", category = "Game feel", tags = "defeat death die poof kill despawn knockout",
	blurb = "A cartoon smoke poof with stars",
	build = function()
		return B.spec({ name = "DefeatPoof", palette = PAL.wind, layers = {
			B.smoke({ tex = "TOONSMOKE", at = { 0, 2.5, 0 }, count = 9, size = 4.5, color = "white", le = 0.35, speed = { 6, 12 },
				spread = { 180, 180 }, lifetime = { 0.6, 1 } }),
			B.star({ at = { 0, 3, 0 }, tex = "TOONSTAR", size = 3, lifetime = 0.5, emit = { { 0, 3 } },
				props = { Speed = { 8, 12 }, SpreadAngle = { 180, 180 }, EmissionDirection = "Top" } }),
			B.specks({ at = { 0, 2.5, 0 }, count = 10, color = "deep", tex = "SPEC" }),
		} })
	end })
add({ id = "confetti", title = "Confetti Burst", category = "Game feel", tags = "confetti party celebrate win victory birthday",
	blurb = "Paper confetti in your colours, fluttering down",
	build = function()
		return B.spec({ name = "ConfettiBurst", palette = PAL.party, layers = {
			B.confetti({ count = 50 }),
			B.flash({ at = { 0, 1.5, 0 }, size = 3, color = "core" }),
			B.star({ at = { 0, 2, 0 }, size = 4, tex = "SPARKLE" }),
		} })
	end })
add({ id = "firework", title = "Firework", category = "Game feel", tags = "firework celebrate new year rocket burst party",
	blurb = "A rocket rises and bursts into a shower of sparks",
	build = function()
		local path = { { 0, { 0, 0, 0 } }, { 0.7, { 0, 30, 0 }, "quadOut" } }
		local top = { 0, 30, 0 }
		return B.spec({ name = "Firework", palette = PAL.party, layers = {
			B.mover({ life = 0.7, size = 0.8, color = "core", path = path }),
			B.trail({ life = 0.7, path = path, size = 0.6, tex = "SPARK", lifetime = { 0.3, 0.5 } }),
			B.flash({ t = 0.7, at = top, size = 7, color = "core" }),
			B.sparks({ t = 0.7, at = top, count = 70, spread = { 180, 180 }, speed = { 25, 45 }, gravity = { 0, -12, 0 }, drag = 2.2,
				lifetime = { 0.9, 1.5 }, size = 0.5 }),
			B.specks({ t = 1.1, at = top, count = 26, box = { 14, 10, 14 }, speed = { 1, 3 }, lifetime = { 0.3, 0.6 }, size = 0.3 }),
			B.light({ t = 0.7, at = top, brightness = 6, range = 40, life = 1 }),
		} })
	end })

-------------------------------------------------------------------------------------------------------- AMBIENT
add({ id = "campfire", title = "Campfire", category = "Ambient", ambient = true, tags = "campfire fire camp bonfire loop",
	blurb = "Flames, embers and smoke that keep burning",
	build = function()
		return B.spec({ name = "Campfire", palette = PAL.fire, layers = {
			B.flames({ life = 600, box = { 1.6, 0.3, 1.6 }, size = 1.8, speed = { 4, 7 }, lift = 4, rateTrack = { { 0, 34 }, { 600, 34 } } }),
			B.embers({ life = 600, at = { 0, 1.5, 0 }, emit = {}, tracks = { Rate = { { 0, 5 }, { 600, 5 } } }, lifetime = { 1.5, 2.5 } }),
			B.smoke({ life = 600, at = { 0, 3.5, 0 }, emit = {}, tracks = { Rate = { { 0, 2 }, { 600, 2 } } }, size = 4, speed = { 2, 4 },
				lifetime = { 2.5, 3.5 }, color = "smoke", le = 0.05 }),
			{ id = "glow", kind = "light", t = 0, life = 600, at = { 0, 2, 0 }, props = { Color = "body", Range = 16, Brightness = 2.5 } },
		} })
	end })
add({ id = "torch", title = "Torch Flame", category = "Ambient", ambient = true, tags = "torch flame candle lamp loop",
	blurb = "A small steady flame with embers",
	build = function()
		return B.spec({ name = "TorchFlame", palette = PAL.fire, layers = {
			B.flames({ life = 600, box = { 0.4, 0.2, 0.4 }, size = 0.9, speed = { 2, 4 }, lift = 3, rateTrack = { { 0, 24 }, { 600, 24 } } }),
			B.embers({ life = 600, at = { 0, 1, 0 }, emit = {}, tracks = { Rate = { { 0, 2 }, { 600, 2 } } }, size = 0.12 }),
			{ id = "glow", kind = "light", t = 0, life = 600, at = { 0, 1, 0 }, props = { Color = "body", Range = 12, Brightness = 2 } },
		} })
	end })
add({ id = "rain", title = "Rain", category = "Ambient", ambient = true, tags = "rain weather storm drizzle loop",
	blurb = "Falling rain over a 60-stud area with splashes",
	build = function()
		return B.spec({ name = "Rain", palette = PAL.water, layers = {
			B.area({ id = "drops", at = { 0, 30, 0 }, box = { 60, 1, 60 }, rate = 500, props = {
				Texture = "STREAK", Color = "core", LightEmission = 0.3, Brightness = 1.5, LightInfluence = 0.5, Shape = "Box",
				Orientation = "VelocityParallel", EmissionDirection = "Bottom", Speed = { 70, 90 }, Rotation = 90,
				Squash = { { 0, 5 }, { 1, 5 } }, Size = { { 0, 0.14 }, { 1, 0.14 } }, Transparency = 0.35, Lifetime = 0.42 } }),
			B.area({ id = "splashes", at = { 0, 0.1, 0 }, box = { 60, 0.1, 60 }, rate = 90, props = {
				Texture = "THINRING", Color = "core", LightEmission = 0.3, Brightness = 1, LightInfluence = 0.5, Shape = "Box",
				Orientation = "VelocityPerpendicular", EmissionDirection = "Top", Speed = 0.01,
				Size = { { 0, 0.05 }, { 1, 0.6 } }, Transparency = { { 0, 0.3 }, { 1, 1 } }, Lifetime = 0.35 } }),
		} })
	end })
add({ id = "snow", title = "Snowfall", category = "Ambient", ambient = true, tags = "snow snowfall winter weather flakes loop",
	blurb = "Gently drifting snowflakes over a 60-stud area",
	build = function()
		return B.spec({ name = "Snowfall", palette = PAL.ice, layers = {
			B.area({ id = "flakes", at = { 0, 26, 0 }, box = { 60, 1, 60 }, rate = 110, props = {
				Texture = "SPEC", Color = "white", LightEmission = 0.4, Brightness = 2, LightInfluence = 0.3, Shape = "Box",
				Orientation = "FacingCamera", EmissionDirection = "Bottom", Speed = { 2.5, 4 }, Acceleration = { 0.6, 0, 0.3 },
				Rotation = { -360, 360 }, RotSpeed = { -40, 40 }, Size = { { 0, 0.18, 0.06 }, { 1, 0.18, 0.06 } },
				Transparency = { { 0, 1 }, { 0.05, 0 }, { 0.9, 0 }, { 1, 1 } }, Lifetime = { 7, 9 } } }),
		} })
	end })
add({ id = "fireflies", title = "Fireflies", category = "Ambient", ambient = true, tags = "fireflies night forest glow bugs loop",
	blurb = "Softly blinking lights drifting around",
	build = function()
		return B.spec({ name = "Fireflies", palette = PAL.nature, layers = {
			B.area({ id = "flies", at = { 0, 3, 0 }, box = { 30, 5, 30 }, rate = 5, props = {
				Texture = "SPARK", Color = "accent", LightEmission = 1, Brightness = 4, LightInfluence = 0, Shape = "Box",
				Orientation = "FacingCamera", EmissionDirection = "Top", SpreadAngle = { 180, 180 }, Speed = { 0.3, 1 },
				Acceleration = { 0, 0.15, 0 }, Size = { { 0, 0 }, { 0.2, 0.22 }, { 0.5, 0.08 }, { 0.75, 0.22 }, { 1, 0 } },
				Transparency = 0, Lifetime = { 5, 8 } } }),
		} })
	end })
add({ id = "mist", title = "Ground Mist", category = "Ambient", ambient = true, tags = "mist fog haze ground spooky loop",
	blurb = "Low, slow mist hugging the ground",
	build = function()
		return B.spec({ name = "GroundMist", palette = PAL.wind, layers = {
			B.area({ id = "mist", at = { 0, 0.8, 0 }, box = { 40, 0.5, 40 }, rate = 3, props = {
				Texture = "SMOKE", FlipbookLayout = 4, FlipbookMode = "Loop", FlipbookFramerate = { 2, 4 }, Color = "smoke",
				LightEmission = 0.25, Brightness = 1, LightInfluence = 0.6, Shape = "Box", Orientation = "FacingCamera",
				EmissionDirection = "Right", Speed = { 0.4, 1.2 }, Rotation = { -360, 360 }, RotSpeed = { -6, 6 },
				Size = { { 0, 6, 1.5 }, { 1, 9, 1.5 } }, Transparency = { { 0, 1 }, { 0.3, 0.82 }, { 0.7, 0.85 }, { 1, 1 } },
				Lifetime = { 7, 10 } } }),
		} })
	end })
add({ id = "sparkleloop", title = "Magic Sparkles", category = "Ambient", ambient = true, tags = "sparkle twinkle magic item glow idle loop",
	blurb = "Twinkling sparkles for items and pickups",
	build = function()
		return B.spec({ name = "MagicSparkles", palette = PAL.holy, layers = {
			B.area({ id = "twinkle", at = { 0, 2, 0 }, box = { 3, 4, 3 }, rate = 8, props = {
				Texture = "SPARKLE", Color = "core", LightEmission = 1, Brightness = 3, LightInfluence = 0, Shape = "Box",
				Orientation = "FacingCamera", Speed = { 0.2, 0.6 }, Rotation = { -45, 45 },
				Size = { { 0, 0 }, { 0.3, 0.45 }, { 1, 0 } }, Transparency = 0, Lifetime = { 0.8, 1.3 } } }),
		} })
	end })
add({ id = "embersloop", title = "Floating Embers", category = "Ambient", ambient = true, tags = "embers ash volcano lava hell loop",
	blurb = "Hot embers drifting up through the air",
	build = function()
		return B.spec({ name = "FloatingEmbers", palette = PAL.fire, layers = {
			B.area({ id = "embers", at = { 0, 0.5, 0 }, box = { 40, 1, 40 }, rate = 14, props = {
				Texture = "SPARK", Color = { { 0, "core" }, { 0.6, "body" }, { 1, "deep" } }, LightEmission = 1, Brightness = 3,
				LightInfluence = 0, Shape = "Box", Orientation = "FacingCamera", EmissionDirection = "Top", SpreadAngle = { 30, 30 },
				Speed = { 2, 5 }, Acceleration = { 0.8, 1.5, 0 }, Size = { { 0, 0.16 }, { 1, 0 } },
				Transparency = { { 0, 0 }, { 0.5, 0.2 }, { 1, 1 } }, Lifetime = { 4, 7 } } }),
		} })
	end })

-------------------------------------------------------------------------------------------- MORE EFFECTS (v1.1)
-- helpers for the effects below ----------------------------------------------------------------------------------
local function hexColor(hex, fallback: Color3?): Color3
	local r, g, b = string.match(hex or "", "#(%x%x)(%x%x)(%x%x)")
	if r then
		return Color3.fromRGB(tonumber(r, 16), tonumber(g, 16), tonumber(b, 16))
	end
	return fallback or Color3.new(1, 1, 1)
end

local function loosePart(ctx, size: Vector3, color: Color3, material)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Size = size
	p.Material = material or Enum.Material.SmoothPlastic
	p.Color = color
	p.Parent = ctx.folder
	return p
end

-- Offset keys (seconds) going round a circle: stars over a dizzy head, sparks orbiting a point.
local function circlePath(radius: number, height: number, turns: number, life: number, phase: number)
	local keys = {}
	local steps = math.max(8, math.floor(turns * 16))
	for i = 0, steps do
		local u = i / steps
		local a = phase + u * turns * math.pi * 2
		table.insert(keys, { u * life, { math.cos(a) * radius, height, math.sin(a) * radius } })
	end
	return keys
end

-- A little star flying round the head, leaving a short trail of stars.
local function starTrail(id: string, phase: number)
	return {
		id = id, kind = "emitter", t = 0, life = 2, at = { 0, 0, 0 },
		props = {
			Texture = "TOONSTAR", Color = { { 0, "core" }, { 1, "body" } }, LightEmission = 0.6, Brightness = 2, LightInfluence = 0,
			Orientation = "FacingCamera", Speed = 0, Rotation = { -30, 30 }, RotSpeed = { -120, 120 },
			Size = { { 0, 0.55 }, { 1, 0 } }, Transparency = { { 0, 0 }, { 1, 0.5 } }, Lifetime = 0.22, ZOffset = 1,
		},
		tracks = { Rate = { { 0, 45 }, { 1.85, 45 }, { 1.9, 0 } }, Offset = circlePath(1.5, 5.7, 3, 2, phase) },
	}
end

-- Real coins (shiny cylinders in the palette's body colour) that pop up, flip, land flat and fade.
local function coins(o)
	local n = o.count or 18
	return {
		id = o.id or "coins", kind = "custom", t = o.t or 0, life = o.life or 2, at = o.at or { 0, 1.5, 0 },
		start = function(ctx, L)
			local col = hexColor(ctx.palette.body, Color3.fromRGB(255, 197, 48))
			local s = { list = {} }
			for _ = 1, n do
				local p = loosePart(ctx, Vector3.new(0.14, 0.85, 0.85) * ctx.scale, col, Enum.Material.Foil)
				p.Shape = Enum.PartType.Cylinder
				local a = ctx.random:NextNumber(0, math.pi * 2)
				local out = ctx.random:NextNumber(3, 9)
				table.insert(s.list, { p = p, v = Vector3.new(math.cos(a) * out, ctx.random:NextNumber(20, 32), math.sin(a) * out),
					spin = ctx.random:NextNumber(9, 16) * (if ctx.random:NextNumber() < 0.5 then -1 else 1),
					tilt = ctx.random:NextNumber(-0.5, 0.5), yaw = ctx.random:NextNumber(0, math.pi * 2), delay = ctx.random:NextNumber(0, 0.12) })
			end
			return s
		end,
		update = function(ctx, L, s, lt)
			local base = ctx.origin * CFrame.new(Vector3.new(L.at.X, L.at.Y, L.at.Z) * ctx.scale)
			local g, h = 55, L.at.Y -- gravity; height of the burst above the ground
			for _, e in s.list do
				local t = math.max(0, lt - e.delay)
				local land = (e.v.Y + math.sqrt(e.v.Y * e.v.Y + 2 * g * h)) / g
				local cf
				if t < land then
					local pos = e.v * t + Vector3.new(0, -g * t * t * 0.5, 0)
					cf = base * CFrame.new(pos * ctx.scale) * CFrame.Angles(0, e.spin * t, e.tilt)
				else -- lying flat where it landed
					local pos = e.v * land + Vector3.new(0, -g * land * land * 0.5 + 0.08, 0)
					cf = base * CFrame.new(pos * ctx.scale) * CFrame.Angles(0, e.yaw, math.rad(90))
				end
				e.p.CFrame = cf
				e.p.Transparency = math.clamp((lt - (L.life - 0.45)) / 0.45, 0, 1)
			end
		end,
		stop = function(ctx, L, s)
			for _, e in s.list do
				e.p:Destroy()
			end
		end,
	}
end

-- Leaves / petals: thin plates that fall, sway and tumble, then start again at the top (a loop that is already full
-- when it starts).
local function fallingPlates(o)
	local n = o.count or 40
	local area, top = o.area or 40, o.height or 22
	return {
		id = o.id or "falling", kind = "custom", t = 0, life = o.life or 600, at = o.at or { 0, 0, 0 },
		start = function(ctx, L)
			local names = o.colors or { "body", "accent", "core", "deep" }
			local s = { list = {} }
			for i = 1, n do
				local col = hexColor(ctx.palette[names[(i % #names) + 1]])
				local k = ctx.random:NextNumber(0.75, 1.25)
				local p = loosePart(ctx, Vector3.new((o.w or 0.6) * k, 0.04, (o.l or 0.4) * k) * ctx.scale, col)
				table.insert(s.list, {
					p = p, x = ctx.random:NextNumber(-area / 2, area / 2), z = ctx.random:NextNumber(-area / 2, area / 2),
					speed = ctx.random:NextNumber(o.minSpeed or 1.6, o.maxSpeed or 2.8), phase = ctx.random:NextNumber(),
					sway = ctx.random:NextNumber(0.8, 1.8), freq = ctx.random:NextNumber(0.7, 1.5),
					spin = Vector3.new(ctx.random:NextNumber(-2.2, 2.2), ctx.random:NextNumber(-1.5, 1.5), ctx.random:NextNumber(-2.2, 2.2)),
				})
			end
			return s
		end,
		update = function(ctx, L, s, lt)
			local base = ctx.origin * CFrame.new(Vector3.new(L.at.X, L.at.Y, L.at.Z) * ctx.scale)
			for _, e in s.list do
				local period = top / e.speed
				local u = ((lt / period) + e.phase) % 1 -- 0 at the top, 1 at the ground
				local t = lt + e.phase * 10
				local x = e.x + math.sin(t * e.freq) * e.sway + (o.drift or 2) * u
				local z = e.z + math.cos(t * e.freq * 0.8) * e.sway * 0.6
				e.p.CFrame = base * CFrame.new(Vector3.new(x, top * (1 - u), z) * ctx.scale)
					* CFrame.Angles(e.spin.X * t, e.spin.Y * t, e.spin.Z * t)
				e.p.Transparency = math.max(math.clamp(1 - u / 0.05, 0, 1), math.clamp((u - 0.95) / 0.05, 0, 1))
			end
		end,
		stop = function(ctx, L, s)
			for _, e in s.list do
				e.p:Destroy()
			end
		end,
	}
end

-- Lightning between two points: a jagged chain of thin Neon segments (white core in a coloured glow) that re-strikes
-- into a new shape every 50 ms, then cuts out.
local function lightningArc(id: string, a, b, o)
	o = o or {}
	local segs = o.segments or 8
	return {
		id = id, kind = "custom", t = o.t or 0, life = o.life or 0.3, at = { 0, 0, 0 },
		start = function(ctx, L)
			local s = { core = {}, glow = {}, nextStrike = 0 }
			local core, glow = hexColor(ctx.palette.white), hexColor(ctx.palette.body)
			for i = 1, segs do
				s.core[i] = loosePart(ctx, Vector3.new(0.14, 0.14, 1) * ctx.scale, core, Enum.Material.Neon)
				s.glow[i] = loosePart(ctx, Vector3.new(0.5, 0.5, 1) * ctx.scale, glow, Enum.Material.Neon)
				s.glow[i].Transparency = 0.55
			end
			return s
		end,
		update = function(ctx, L, s, lt)
			if lt >= s.nextStrike then
				s.nextStrike = lt + 0.05
				local A = ctx.origin * (Vector3.new(a[1], a[2], a[3]) * ctx.scale)
				local Bw = ctx.origin * (Vector3.new(b[1], b[2], b[3]) * ctx.scale)
				local dir = Bw - A
				local side = dir:Cross(Vector3.yAxis)
				side = if side.Magnitude > 1e-3 then side.Unit else Vector3.xAxis
				local up = side:Cross(dir).Unit
				local pts = { A }
				for i = 1, segs - 1 do
					local u = i / segs
					local j = dir.Magnitude * 0.13 * (1 - math.abs(u - 0.5))
					table.insert(pts, A + dir * u + side * ctx.random:NextNumber(-j, j) + up * ctx.random:NextNumber(-j, j))
				end
				table.insert(pts, Bw)
				for i = 1, segs do
					local p0, p1 = pts[i], pts[i + 1]
					local d = math.max((p1 - p0).Magnitude, 0.05)
					local cf = CFrame.lookAt((p0 + p1) / 2, p1)
					s.core[i].Size = Vector3.new(0.14 * ctx.scale, 0.14 * ctx.scale, d)
					s.core[i].CFrame = cf
					s.glow[i].Size = Vector3.new(0.5 * ctx.scale, 0.5 * ctx.scale, d)
					s.glow[i].CFrame = cf
				end
			end
			local fade = math.clamp((lt - (L.life - 0.08)) / 0.08, 0, 1)
			for i = 1, segs do
				s.core[i].Transparency = fade
				s.glow[i].Transparency = 0.55 + 0.45 * fade
			end
		end,
		stop = function(ctx, L, s)
			for i = 1, segs do
				s.core[i]:Destroy()
				s.glow[i]:Destroy()
			end
		end,
	}
end

-- A soft glowing band (loot beams, god rays): a camera-facing beam with a soft dot stretched along it.
local function softBand(id: string, a, b, w0: number, w1: number, color, o)
	o = o or {}
	return B.beam({ id = id, life = o.life or 600, t = o.t, a = a, b = b, width = w0, tex = "SOFTDOT", color = color,
		props = { TextureMode = "Stretch", TextureLength = 1, TextureSpeed = 0, FaceCamera = true, Width1 = w1,
			LightEmission = 1, Brightness = o.brightness or 2, Transparency = o.transparency or { { 0, 0.15 }, { 0.75, 0.45 }, { 1, 1 } } },
		tracks = { Width = o.widthTrack or { { 0, 0 }, { 0.6, 1, "backOut" }, { 600, 1 } } } })
end

-- claw marks: hot red edges by default (the effect-wide palette still recolours them)
local CLAW = { core = "#FFFFFF", primary = "#FF4A3D", secondary = "#FFB04A", deep = "#3A0606" }

------------------------------------------------------------------------------------------------- more COMBAT
add({ id = "spinslash", title = "Spin Slash", category = "Combat", tags = "spin whirlwind sweep spinning cyclone sword",
	shake = { amp = 0.35, dur = 0.3 }, blurb = "A full 360 slash ring around you with sparks and dust",
	build = function()
		local at = { 0, 2.8, 0 }
		return B.spec({ name = "SpinSlash", palette = PAL.energy, layers = {
			B.flash({ at = at, size = 4, lifetime = 0.06 }),
			B.windRing({ at = at, size = 8.5, lifetime = 0.3, rotSpeed = { 1100, 1300 }, le = 1, brightness = 3, color = "white" }),
			B.windRing({ id = "edge", t = 0.03, at = at, size = 10.5, lifetime = 0.34, rotSpeed = { 900, 1100 }, le = 1, brightness = 2, color = "body" }),
			B.ring({ at = at, tex = "THINRING", size = 12, lifetime = 0.28, color = "core" }),
			B.sparks({ at = at, count = 18, spread = { 180, 180 }, speed = { 35, 70 }, gravity = { 0, -45, 0 } }),
			B.streaks({ at = at, count = 12, speed = { 60, 100 }, size = 1.3 }),
			B.dust({ count = 10, size = 3.2 }),
			B.light({ at = at, brightness = 5, range = 14, life = 0.3 }),
		} })
	end })
add({ id = "clawstrike", title = "Claw Strike", category = "Combat", tags = "claw scratch beast wolf feral rake talon",
	blurb = "Three raking claw slashes and a hit spark",
	combo = { { base = "slash", t = 0, roll = 62, scale = 0.55, at = { -1.4, 0.75, 0 }, palette = CLAW },
		{ base = "slash", t = 0.025, roll = 62, scale = 0.6, at = { 0, 0, 0 }, palette = CLAW },
		{ base = "slash", t = 0.05, roll = 62, scale = 0.55, at = { 1.4, -0.75, 0 }, palette = CLAW },
		{ base = "hitspark", t = 0.08, at = { 0, 0, -3 }, palette = CLAW } } })
add({ id = "bloodsplat", title = "Blood Splatter", category = "Combat", tags = "blood splatter gore bleed wound damage",
	blurb = "A wet splat with droplets that arc and fall",
	build = function()
		local at = { 0, 3, -1.5 }
		return B.spec({ name = "BloodSplatter", palette = PAL.blood, layers = {
			B.flash({ at = at, size = 2.4, color = "core", lifetime = 0.05 }),
			B.splash({ at = at, size = 3.6, count = 2, le = 0.05, color = { { 0, "body" }, { 1, "deep" } },
				props = { Orientation = "FacingCamera", Rotation = { -180, 180 } } }),
			B.droplets({ at = at, count = 26, speed = { 14, 28 }, size = 0.28, color = "body",
				props = { LightEmission = 0.05, SpreadAngle = { 70, 70 }, EmissionDirection = "Front" } }),
			B.specks({ at = at, tex = "SPEC", color = "deep", count = 12, speed = { 6, 14 }, gravity = { 0, -40, 0 }, size = 0.2,
				lifetime = { 0.35, 0.6 }, props = { LightEmission = 0, Brightness = 1, LightInfluence = 0.6 } }),
			B.smoke({ at = at, count = 3, size = 2, color = "body", le = 0.05, speed = { 1, 3 }, lifetime = { 0.35, 0.55 } }),
		} })
	end })
add({ id = "stun", title = "Stun Stars", category = "Combat", tags = "stun dizzy daze stunned knocked status",
	blurb = "Little stars circling over a dizzy head",
	build = function()
		return B.spec({ name = "StunStars", palette = PAL.holy, layers = {
			starTrail("star1", 0), starTrail("star2", math.pi * 2 / 3), starTrail("star3", math.pi * 4 / 3),
			B.windRing({ at = { 0, 5.7, 0 }, size = 2, lifetime = 0.5, le = 0.5, color = "core", emit = emits(0, 1.6, 0.4) }),
			B.specks({ at = { 0, 5.7, 0 }, count = 8, tex = "SPARKLE", speed = { 1, 3 }, size = 0.25, lifetime = { 0.4, 0.7 },
				emit = { { 0, 8, 1.8 } } }),
		} })
	end })
add({ id = "muzzleflash", title = "Muzzle Flash", category = "Combat", tags = "muzzle gun pistol rifle shoot firearm",
	blurb = "A one-frame gun flash with a cone, sparks and a wisp of smoke",
	build = function()
		local at = { 0, 3, -2.5 }
		return B.spec({ name = "MuzzleFlash", palette = PAL.fire, layers = {
			B.flash({ at = at, size = 2.2, lifetime = 0.045 }),
			B.star({ at = at, size = 2.8, lifetime = 0.05, rotation = { -15, 15 } }),
			B.bloom({ at = at, size = 3, alpha = 0.3, lifetime = 0.08 }),
			B.streaks({ at = at, dir = "Front", spread = { 7, 7 }, speed = { 40, 70 }, count = 7, size = 1.1, color = "core",
				lifetime = { 0.04, 0.07 } }),
			B.sparks({ at = at, dir = "Front", spread = { 25, 25 }, count = 5, size = 0.18, speed = { 40, 70 }, lifetime = { 0.08, 0.16 } }),
			B.smoke({ at = at, count = 3, size = 1.4, dir = "Front", spread = { 25, 25 }, speed = { 2, 5 }, lifetime = { 0.5, 0.8 }, le = 0.05 }),
			B.light({ at = at, brightness = 7, range = 10, life = 0.08 }),
		} })
	end })
add({ id = "bulletimpact", title = "Bullet Impact", category = "Combat", tags = "bullet ricochet gunshot wall spark hole",
	blurb = "Sparks, a dust puff and chips where a shot lands",
	build = function()
		return B.spec({ name = "BulletImpact", palette = PAL.impact, layers = {
			B.flash({ at = { 0, 0.3, 0 }, size = 1.6, lifetime = 0.05, color = "white" }),
			B.sparks({ at = { 0, 0.2, 0 }, count = 9, spread = { 45, 45 }, speed = { 25, 55 }, size = 0.25, lifetime = { 0.12, 0.3 } }),
			B.dust({ at = { 0, 0.2, 0 }, count = 4, size = 1.6, speed = { 6, 12 }, lifetime = { 0.5, 0.8 } }),
			B.debris({ at = { 0, 0.2, 0 }, count = 5, size = 0.25, speed = { 10, 20 } }),
			B.smoke({ at = { 0, 0.5, 0 }, count = 2, size = 1.4, speed = { 1, 3 }, lifetime = { 0.6, 0.9 } }),
			B.decalDisc({ tex = "CRACKSTAR", size = 1.4, color = "ink", life = 3, fade = { { 0, 0.2 }, { 0.8, 0.3 }, { 1, 1 } } }),
		} })
	end })
add({ id = "punchbarrage", title = "Punch Barrage", category = "Combat", tags = "barrage rapid punches flurry multi hit rush",
	shake = { amp = 0.3, dur = 0.85 }, blurb = "A flurry of fast hits ending in a big finisher",
	build = function()
		local zone, box = { 0, 3, -3 }, { 3, 2.6, 0.6 }
		return B.spec({ name = "PunchBarrage", palette = PAL.fire, layers = {
			B.flash({ at = zone, box = box, size = 2.4, lifetime = 0.05, emit = emits(0, 0.72, 0.045, 1) }),
			B.shockwave({ at = zone, box = box, size = 3.2, lifetime = 0.14, emit = emits(0.01, 0.73, 0.045, 1) }),
			B.streaks({ at = { 0, 3, -1 }, box = { 2.4, 2, 0.4 }, dir = "Front", spread = { 12, 12 }, speed = { 70, 120 }, size = 1.4,
				emit = emits(0, 0.72, 0.03, 2) }),
			B.sparks({ at = zone, count = 3, size = 0.25, emit = emits(0, 0.72, 0.09, 3) }),
			B.inkFlash({ t = 0.8, at = zone, size = 9 }),
			B.flash({ id = "finisher", t = 0.8, at = zone, size = 7 }),
			B.shockwave({ id = "finisherRing", t = 0.8, at = zone, size = 11 }),
			B.streaks({ id = "finisherLines", t = 0.8, at = zone, count = 14 }),
			B.dust({ t = 0.8, at = { 0, 0.2, -3 }, count = 8, size = 3 }),
			{ id = "flicker", kind = "light", t = 0, life = 1.0, at = zone, props = { Color = "body", Range = 14, Brightness = 0 },
				tracks = { Brightness = { { 0, 4 }, { 0.1, 2 }, { 0.2, 4 }, { 0.3, 2 }, { 0.4, 4 }, { 0.5, 2 }, { 0.6, 4 }, { 0.7, 2 },
					{ 0.8, 8 }, { 1.0, 0 } } } },
		} })
	end })
add({ id = "knockback", title = "Knockback Blast", category = "Combat", tags = "knockback push repel force blowback",
	shake = { amp = 0.5, dur = 0.3 }, blurb = "A forward blast cone that throws enemies back",
	build = function()
		return B.spec({ name = "KnockbackBlast", palette = PAL.energy, layers = {
			B.flash({ at = { 0, 3, -2 }, size = 5 }),
			B.shockwave({ at = { 0, 3, -2 }, size = 8, lifetime = 0.25 }),
			B.windRing({ at = { 0, 3, -3 }, dir = "Front", size = 4.5, lifetime = 0.3 }),
			B.windRing({ id = "r2", t = 0.04, at = { 0, 3, -7 }, dir = "Front", size = 6.5, lifetime = 0.34 }),
			B.windRing({ id = "r3", t = 0.08, at = { 0, 3, -11 }, dir = "Front", size = 8.5, lifetime = 0.38 }),
			B.streaks({ at = { 0, 3, -1.5 }, dir = "Front", spread = { 22, 22 }, speed = { 90, 150 }, count = 18, size = 2 }),
			B.sparks({ at = { 0, 3, -2 }, dir = "Front", spread = { 35, 35 }, count = 12 }),
			B.dust({ at = { 0, 0.2, -4 }, count = 10, size = 3.5 }),
			B.light({ at = { 0, 3, -3 }, brightness = 5, range = 16 }),
		} })
	end })

----------------------------------------------------------------------------------------------- more ELEMENTS
add({ id = "earthquake", title = "Earthquake", category = "Elements", tags = "quake tremor rumble fissure seismic crack",
	shake = { amp = 0.9, dur = 1.3 }, blurb = "The ground cracks wide, rocks jut up and dust rolls out",
	build = function()
		return B.spec({ name = "Earthquake", palette = PAL.earth, layers = {
			B.decalDisc({ tex = "CRACKSTAR", size = 24, color = "ink", life = 3.2, fade = { { 0, 0.1 }, { 0.75, 0.2 }, { 1, 1 } } }),
			B.spikes({ count = 8, radius = 8, height = 3.2, lean = 48, hot = false, deepColor = "deep", bodyColor = "body", tipColor = "core",
				life = 2.6, stagger = 0.08 }),
			B.ring({ size = 26, color = "smoke", le = 0.15, tex = "THINRING", lifetime = 0.9 }),
			B.ring({ id = "ring2", t = 0.35, size = 30, color = "smoke", le = 0.15, tex = "THINRING", lifetime = 1 }),
			B.dust({ count = 34, size = 6, speed = { 10, 26 }, emit = { { 0, 34, 1.1 } } }),
			B.debris({ at = { 0, 0.4, 0 }, box = { 18, 0.5, 18 }, count = 26, speed = { 14, 30 }, spread = { 35, 35 }, emit = { { 0, 26, 1.1 } } }),
			B.smoke({ at = { 0, 1, 0 }, box = { 14, 1, 14 }, count = 12, size = 8, speed = { 2, 6 }, lifetime = { 1.6, 2.4 },
				emit = { { 0.15, 12, 0.9 } } }),
			B.grade({ life = 1.2, brightness = -0.03, contrast = 0.15, saturation = -0.1 }),
		} })
	end })
add({ id = "earthspikes", title = "Earth Spikes", category = "Elements", tags = "rock stone spikes wave erupt boulder",
	shake = { amp = 0.5, dur = 0.5 }, blurb = "A wave of rock spikes bursting out of the ground ahead",
	build = function()
		local layers = {}
		for i = 1, 5 do
			local z, t = -2.5 - i * 2.6, (i - 1) * 0.07
			table.insert(layers, B.spikes({ id = "rocks" .. i, t = t, at = { 0, 0, z }, count = 4, radius = 1.1, height = 2.6 + i * 0.7,
				width = 1.3 + i * 0.1, lean = 16, hot = false, deepColor = "deep", bodyColor = "body", tipColor = "core", life = 1.9 - t, seed = i * 7 }))
			table.insert(layers, B.dust({ id = "dust" .. i, t = t, at = { 0, 0.2, z }, count = 6, size = 2.8, speed = { 8, 16 } }))
			table.insert(layers, B.debris({ id = "debris" .. i, t = t, at = { 0, 0.4, z }, count = 4, size = 0.4, speed = { 14, 24 } }))
		end
		table.insert(layers, B.decalDisc({ tex = "CRACKSTAR", at = { 0, 0.06, -9 }, size = 12, color = "ink", life = 2.4,
			fade = { { 0, 0.15 }, { 0.75, 0.25 }, { 1, 1 } } }))
		return B.spec({ name = "EarthSpikes", palette = PAL.earth, layers = layers })
	end })
add({ id = "lavaburst", title = "Lava Burst", category = "Elements", tags = "lava magma molten volcano eruption",
	shake = { amp = 0.5, dur = 0.4 }, blurb = "Molten lava bursts up, splashes and leaves glowing cracks",
	build = function()
		return B.spec({ name = "LavaBurst", palette = PAL.fire, layers = {
			B.flash({ at = { 0, 1.5, 0 }, size = 7 }),
			B.splash({ at = { 0, 2.5, 0 }, size = 7.5, count = 3, le = 0.9, color = { { 0, "core" }, { 0.5, "body" }, { 1, "deep" } } }),
			B.sparks({ id = "globs", at = { 0, 1, 0 }, dir = "Top", spread = { 28, 28 }, speed = { 30, 55 }, count = 18, size = 0.7,
				gravity = { 0, -55, 0 }, drag = 0.4, lifetime = { 0.7, 1.1 } }),
			B.droplets({ at = { 0, 1, 0 }, count = 36, size = 0.5, color = { { 0, "core" }, { 1, "body" } }, speed = { 24, 44 },
				props = { LightEmission = 1, Brightness = 3, LightInfluence = 0 } }),
			B.flames({ life = 1.1, box = { 3.5, 0.3, 3.5 }, size = 2.8, speed = { 8, 14 }, lift = 8, rateTrack = { { 0, 90 }, { 0.9, 90 }, { 1, 0 } } }),
			B.embers({ at = { 0, 2, 0 }, count = 40, speed = { 12, 26 }, lift = 7 }),
			B.ring({ size = 11, color = "core", lifetime = 0.5 }),
			B.decalDisc({ tex = "CRACKSTAR", size = 12, color = "body", life = 2.8, fade = { { 0, 0 }, { 0.6, 0.15 }, { 1, 1 } } }),
			B.smoke({ at = { 0, 4, 0 }, count = 10, size = 7, color = "deep", le = 0.05, emit = { { 0.15, 10, 0.8 } } }),
			B.light({ at = { 0, 2.5, 0 }, brightness = 8, range = 22, life = 1.3 }),
		} })
	end })
add({ id = "iceshatter", title = "Ice Shatter", category = "Elements", tags = "shatter frozen shards glass smash break",
	shake = { amp = 0.35, dur = 0.25 }, blurb = "A frozen shell bursts into glinting ice shards and frost",
	build = function()
		local at = { 0, 3, 0 }
		return B.spec({ name = "IceShatter", palette = PAL.ice, layers = {
			B.sphere({ at = at, size = 6, life = 0.18, material = "Glass", color = "core", scale = { { 0, 1 }, { 1, 1.25 } },
				fade = { { 0, 0.3 }, { 1, 1 } } }),
			B.flash({ at = at, size = 7 }),
			B.star({ at = at, size = 8, lifetime = 0.2 }),
			B.shockwave({ at = at, size = 11, tex = "THINRING", lifetime = 0.3 }),
			B.debris({ at = at, count = 24, size = 0.55, speed = { 22, 40 }, spread = { 180, 180 }, color = "core",
				props = { LightEmission = 0.5, LightInfluence = 0.4, Brightness = 2 } }),
			B.sparks({ at = at, count = 22, spread = { 180, 180 }, speed = { 30, 60 }, color = { { 0, "white" }, { 1, "body" } } }),
			B.specks({ at = at, count = 26, tex = "SPARKLE", color = "white", speed = { 8, 18 }, gravity = { 0, -6, 0 } }),
			B.smoke({ at = at, count = 7, size = 5, le = 0.5, speed = { 4, 10 }, spread = { 180, 180 }, lifetime = { 0.8, 1.2 } }),
			B.light({ at = at, brightness = 6, range = 16, life = 0.4 }),
		} })
	end })
add({ id = "frostnova", title = "Frost Nova", category = "Elements", tags = "nova freeze chill blizzard aoe cold",
	shake = { amp = 0.4, dur = 0.35 }, blurb = "A freezing ring races out and ice grows where it passes",
	build = function()
		return B.spec({ name = "FrostNova", palette = PAL.ice, layers = {
			B.flash({ at = { 0, 1.5, 0 }, size = 7 }),
			B.ring({ size = 24, color = "core", lifetime = 0.8 }),
			B.ring({ id = "edge", t = 0.04, size = 20, tex = "THINRING", color = "white", lifetime = 0.7 }),
			B.spikes({ count = 16, radius = 9, height = 2.8, lean = 30, width = 1.1, life = 2.2, stagger = 0.006 }),
			B.spikes({ id = "inner", t = 0.05, count = 8, radius = 4.5, height = 2, lean = 20, width = 0.9, life = 2.15, seed = 40 }),
			B.smoke({ at = { 0, 0.6, 0 }, count = 14, size = 6, le = 0.45, speed = { 10, 20 }, spread = { 85, 85 }, gravity = { 0, 0.5, 0 },
				lifetime = { 1.2, 1.8 } }),
			B.specks({ at = { 0, 1, 0 }, count = 24, color = "white", tex = "SPARKLE", speed = { 6, 16 } }),
			B.grade({ brightness = 0.06, contrast = 0.1, saturation = -0.15 }),
			B.light({ at = { 0, 2, 0 }, brightness = 6, range = 24, life = 0.7 }),
		} })
	end })
add({ id = "chainlightning", title = "Chain Lightning", category = "Elements", tags = "chain arc jump bolt electric zap multi",
	blurb = "Lightning leaps from target to target", shake = { amp = 0.4, dur = 0.4 },
	build = function()
		local hops = { { 0, 3, -1 }, { 0, 3, -6 }, { 4, 3, -10 }, { -3, 3, -14 }, { 2, 3, -18 } }
		local layers = {}
		for i = 2, #hops do
			local t = (i - 2) * 0.09
			table.insert(layers, lightningArc("arc" .. i, hops[i - 1], hops[i], { t = t, life = 0.32 }))
			table.insert(layers, B.flash({ id = "hit" .. i, t = t, at = hops[i], size = 4 }))
			table.insert(layers, B.bloom({ id = "glow" .. i, t = t, at = hops[i], size = 4, alpha = 0.35, lifetime = 0.3 }))
			table.insert(layers, B.sparks({ id = "sparks" .. i, t = t, at = hops[i], count = 10, spread = { 180, 180 }, speed = { 20, 45 } }))
		end
		table.insert(layers, B.star({ at = hops[1], size = 3.5, lifetime = 0.22 }))
		table.insert(layers, { id = "flicker", kind = "light", t = 0, life = 0.6, at = { 0, 3, -9 },
			props = { Color = "body", Range = 24, Brightness = 0 },
			tracks = { Brightness = { { 0, 7 }, { 0.06, 2 }, { 0.1, 7 }, { 0.16, 2 }, { 0.2, 7 }, { 0.26, 2 }, { 0.3, 6 }, { 0.6, 0 } } } })
		return B.spec({ name = "ChainLightning", palette = PAL.electric, layers = layers })
	end })
add({ id = "steamburst", title = "Steam Burst", category = "Elements", tags = "steam vapor hiss geyser vent",
	blurb = "A hissing jet of steam that billows out",
	build = function()
		return B.spec({ name = "SteamBurst", palette = PAL.wind, layers = {
			B.smoke({ id = "jet", at = { 0, 0.5, 0 }, count = 16, size = 4, color = "white", le = 0.4, speed = { 18, 30 }, spread = { 12, 12 },
				gravity = { 0, 4, 0 }, drag = 2, lifetime = { 0.9, 1.4 }, emit = { { 0, 16, 0.5 } } }),
			B.smoke({ id = "billow", at = { 0, 0.5, 0 }, count = 8, size = 6, le = 0.3, speed = { 4, 10 }, spread = { 80, 80 },
				lifetime = { 1.2, 1.8 } }),
			B.droplets({ count = 10, size = 0.2, color = "white", speed = { 14, 24 } }),
			B.ring({ tex = "THINRING", size = 6, color = "white", le = 0.4, lifetime = 0.5 }),
		} })
	end })
add({ id = "acidsplash", title = "Acid Splash", category = "Elements", tags = "acid corrosive slime goo spit ooze",
	blurb = "A green splash that fizzes and eats into the ground",
	build = function()
		return B.spec({ name = "AcidSplash", palette = PAL.toxic, layers = {
			B.splash({ at = { 0, 2, 0 }, size = 5, le = 0.6, color = { { 0, "accent" }, { 1, "body" } } }),
			B.droplets({ count = 22, color = "accent", speed = { 14, 28 }, props = { LightEmission = 0.6 } }),
			B.smoke({ at = { 0, 0.8, 0 }, count = 8, size = 4, color = "body", le = 0.5, speed = { 1, 4 }, lifetime = { 1.5, 2.2 },
				gravity = { 0, 1, 0 } }),
			B.rise({ tex = "SPEC", radius = 2.5, count = 14, over = 1.2, color = "accent", size = 0.3, lift = 2 }),
			B.decalDisc({ tex = "CRACKSTAR", size = 7, color = "body", life = 2.4, fade = { { 0, 0.1 }, { 0.7, 0.2 }, { 1, 1 } } }),
			B.ring({ size = 6, color = "body", le = 0.5 }),
		} })
	end })

-------------------------------------------------------------------------------------------------- more MAGIC
add({ id = "smokebomb", title = "Smoke Bomb", category = "Magic", tags = "bomb ninja vanish escape cloud stealth hide",
	blurb = "A pop and a thick cloud of smoke to vanish in",
	build = function()
		return B.spec({ name = "SmokeBomb", palette = PAL.smoke, layers = {
			B.flash({ at = { 0, 1, 0 }, size = 4, lifetime = 0.06 }),
			B.smoke({ tex = "BILLOW", at = { 0, 1.5, 0 }, count = 16, size = 7, color = "body", le = 0.1, li = 0.8, speed = { 8, 18 },
				spread = { 180, 180 }, drag = 4, gravity = { 0, 0.6, 0 }, lifetime = { 2.2, 3.2 } }),
			B.smoke({ id = "core", tex = "TOONSMOKE", at = { 0, 2, 0 }, count = 10, size = 5, color = "core", le = 0.3, speed = { 6, 12 },
				spread = { 180, 180 }, lifetime = { 1.2, 1.8 } }),
			B.dust({ count = 10, size = 4 }),
			B.sparks({ at = { 0, 1, 0 }, count = 6, size = 0.25, color = { { 0, "white" }, { 1, "body" } } }),
		} })
	end })
add({ id = "curse", title = "Curse Mark", category = "Magic", tags = "curse hex dark debuff doom sigil shadow",
	blurb = "A dark sigil brands the target as shadows rise",
	build = function()
		return B.spec({ name = "CurseMark", palette = PAL.void, layers = {
			B.decalDisc({ size = 11, life = 2.2, spin = { 0, -60, 0 }, color = "body" }),
			B.inkFlash({ at = { 0, 3, 0 }, size = 8 }),
			B.smoke({ at = { 0, 1, 0 }, box = { 3, 0.5, 3 }, count = 18, size = 5.5, color = "deep", le = 0.2, speed = { 3, 6 },
				gravity = { 0, 4, 0 }, lifetime = { 1.3, 1.9 }, emit = { { 0, 18, 1.2 } } }),
			B.rise({ tex = "SPARK", radius = 2.5, count = 30, over = 1.2, color = { { 0, "accent" }, { 1, "body" } }, lift = 4, size = 0.45 }),
			B.windRing({ at = { 0, 0.5, 0 }, size = 5, le = 0.8, color = "accent", lifetime = 0.6, emit = emits(0, 1, 0.25) }),
			B.star({ at = { 0, 6, 0 }, size = 4.5, color = "accent", lifetime = 0.7 }),
			B.grade({ life = 0.6, brightness = -0.04, contrast = 0.1, saturation = -0.25 }),
			B.light({ at = { 0, 3, 0 }, brightness = 4, range = 14, life = 1.4 }),
		} })
	end })
add({ id = "lifedrain", title = "Life Drain", category = "Magic", tags = "drain siphon steal vampire leech soul absorb",
	blurb = "Life streams out of the target and into you",
	build = function()
		local target, me = { 0, 3, -10 }, { 0, 3, 0 }
		local stream = { Shape = "Box", Speed = { 20, 26 }, Drag = 0, Acceleration = { 0, 0, 0 } }
		return B.spec({ name = "LifeDrain", palette = PAL.blood, layers = {
			B.beam({ id = "tether", a = target, b = { 0, 3, -0.6 }, width = 2.4, life = 1.5, tex = "BEAMSMOKE", texSpeed = 5, color = "body" }),
			B.beam({ id = "core", a = target, b = { 0, 3, -0.6 }, width = 0.8, life = 1.5, texSpeed = 6, color = "core" }),
			B.specks({ id = "orbs", at = target, box = { 1.2, 1.2, 1.2 }, dir = "Back", spread = { 6, 6 }, count = 70, emit = { { 0, 70, 1.3 } },
				lifetime = { 0.42, 0.5 }, tex = "SOFTDOT", size = 0.8, color = { { 0, "core" }, { 1, "body" } }, props = stream }),
			B.specks({ id = "sparks", at = target, box = { 1.2, 1.2, 1.2 }, dir = "Back", spread = { 10, 10 }, count = 50, emit = { { 0, 50, 1.3 } },
				lifetime = { 0.42, 0.5 }, tex = "SPARK", size = 0.3, color = "white", props = stream }),
			B.smoke({ at = target, count = 8, size = 4, color = "deep", le = 0.25, speed = { 1, 3 }, emit = { { 0, 8, 1.1 } } }),
			B.bloom({ id = "victim", at = target, size = 5, alpha = 0.5, lifetime = 1.4 }),
			B.bloom({ at = me, size = 6, alpha = 0.45, lifetime = 1.5 }),
			B.flash({ t = 1.3, at = me, size = 5, color = "core" }),
			B.rise({ t = 1.15, count = 24, over = 0.45, radius = 1.8, color = { { 0, "white" }, { 1, "body" } } }),
			B.light({ at = me, brightness = 4, range = 14, life = 1.6 }),
		} })
	end })
add({ id = "arcanebolt", title = "Arcane Bolt", category = "Magic", tags = "arcane missile spell mage shot magic",
	blurb = "A magic missile with a sparkling trail and a bright pop",
	build = function()
		local from, to = { 0, 3, -1.5 }, { 0, 3, -30 }
		local path = { { 0, from }, { 0.45, to, "quadIn" } }
		return B.spec({ name = "ArcaneBolt", palette = PAL.void, layers = {
			B.star({ at = from, size = 4, lifetime = 0.22 }),
			B.windRing({ at = from, dir = "Front", size = 3.2, lifetime = 0.28 }),
			B.mover({ life = 0.45, size = 1.3, color = "white", path = path }),
			B.mover({ id = "shell", life = 0.45, size = 2.4, color = "body", material = "ForceField", path = path }),
			B.trail({ life = 0.45, path = path, tex = "SPARKLE", size = 1.4, color = { { 0, "white" }, { 1, "body" } }, lifetime = { 0.3, 0.5 } }),
			B.trail({ id = "glow", life = 0.45, path = path, tex = "SOFTDOT", size = 3.6, color = "body", le = 1, lifetime = { 0.14, 0.22 } }),
			B.flash({ t = 0.45, at = to, size = 7 }),
			B.shockwave({ t = 0.45, at = to, size = 10, lifetime = 0.28 }),
			B.specks({ t = 0.45, at = to, count = 26, speed = { 12, 24 }, tex = "SPARKLE", size = 0.5 }),
			B.light({ t = 0.45, at = to, brightness = 6, range = 16, life = 0.4 }),
		} })
	end })
add({ id = "shieldbreak", title = "Shield Break", category = "Magic", tags = "guard broken barrier shatter crack",
	shake = { amp = 0.5, dur = 0.3 }, blurb = "An energy shield cracks and shatters into shards",
	build = function()
		local at = { 0, 3, 0 }
		return B.spec({ name = "ShieldBreak", palette = PAL.energy, layers = {
			B.sphere({ at = at, size = 10, life = 0.25, scale = { { 0, 1 }, { 1, 1.15 } }, fade = { { 0, 0.15 }, { 1, 1 } } }),
			B.flash({ at = at, size = 8 }),
			B.shockwave({ at = at, size = 13, tex = "THINRING", lifetime = 0.35 }),
			B.debris({ at = at, color = "core", count = 22, speed = { 20, 36 }, spread = { 180, 180 }, size = 0.5,
				props = { LightEmission = 0.7, LightInfluence = 0.2, Brightness = 2 } }),
			B.sparks({ at = at, count = 16, spread = { 180, 180 } }),
			B.specks({ at = at, count = 30, speed = { 14, 28 }, tex = "SPARKLE" }),
			B.light({ at = at, brightness = 7, range = 18, life = 0.35 }),
		} })
	end })
add({ id = "manaburst", title = "Mana Burst", category = "Magic", tags = "mana arcane energy release nova blast",
	shake = { amp = 0.4, dur = 0.3 }, blurb = "A burst of raw magic: sphere, rays, rings and sparkles",
	build = function()
		local at = { 0, 3, 0 }
		return B.spec({ name = "ManaBurst", palette = PAL.energy, layers = {
			B.flash({ at = at, size = 7 }),
			B.sphere({ at = at, size = 9, life = 0.4 }),
			B.rays({ at = at, size = 12, lifetime = 0.5 }),
			B.shockwave({ at = at, size = 12 }),
			B.ring({ size = 14 }),
			B.orbit({ at = at, size = 5, count = 4 }),
			B.specks({ at = at, count = 40, speed = { 16, 34 }, tex = "SPARKLE", size = 0.5 }),
			B.light({ at = at, brightness = 7, range = 20, life = 0.5 }),
		} })
	end })
add({ id = "timestop", title = "Time Stop", category = "Magic", tags = "time freeze slow world clock pause stop",
	blurb = "A dome sweeps out and the world drains of colour",
	build = function()
		local at = { 0, 3, 0 }
		return B.spec({ name = "TimeStop", palette = PAL.time, layers = {
			B.flash({ at = at, size = 6 }),
			B.sphere({ at = at, size = 40, life = 1.6, color = "body",
				scale = { { 0, 0.05 }, { 0.45, 1, "quadOut" }, { 0.85, 1.05 }, { 1, 0, "backIn" } }, fade = { { 0, 0.1 }, { 0.85, 0.35 }, { 1, 1 } } }),
			B.shockwave({ at = at, size = 24, tex = "THINRING", lifetime = 0.5 }),
			B.decalDisc({ size = 14, life = 1.6, spin = { 0, 90, 0 }, color = "core" }),
			B.grade({ life = 1.6, tracks = { Saturation = { { 0, 0 }, { 0.3, -1 }, { 1.3, -1 }, { 1.6, 0 } },
				Contrast = { { 0, 0 }, { 0.3, 0.25 }, { 1.6, 0 } }, Brightness = { { 0, 0 }, { 0.3, 0.05 }, { 1.6, 0 } } } }),
			B.light({ at = at, brightness = 4, range = 30, life = 1.6, color = "core" }),
		} })
	end })
add({ id = "starfall", title = "Star Fall", category = "Magic", tags = "starfall shower sky rain stars celestial",
	shake = { amp = 0.25, dur = 1.4 }, blurb = "Stars streak down from the sky and burst on the ground",
	build = function()
		local rng = Random.new(11)
		local layers = {}
		for i = 1, 12 do
			local land = { rng:NextNumber(-8, 8), 0.4, rng:NextNumber(-8, 8) }
			local t0 = (i - 1) * 0.11 + rng:NextNumber(0, 0.05)
			local path = { { 0, { land[1] - 9, 30, land[3] + 5 } }, { 0.4, land, "quadIn" } }
			table.insert(layers, B.mover({ id = "star" .. i, t = t0, life = 0.4, size = 0.8, color = "white", path = path }))
			table.insert(layers, B.trail({ id = "tail" .. i, t = t0, life = 0.4, path = path, tex = "SPARKLE", size = 1.2, le = 1,
				color = { { 0, "white" }, { 0.5, "core" }, { 1, "body" } }, lifetime = { 0.2, 0.35 } }))
			table.insert(layers, B.flash({ id = "hit" .. i, t = t0 + 0.4, at = land, size = 3.5 }))
			table.insert(layers, B.ring({ id = "ring" .. i, t = t0 + 0.4, at = { land[1], 0.1, land[3] }, size = 4.5, tex = "THINRING", lifetime = 0.45 }))
		end
		table.insert(layers, B.specks({ at = { 0, 0.5, 0 }, box = { 16, 0.2, 16 }, count = 34, emit = { { 0.4, 34, 1.4 } }, tex = "SPARKLE",
			speed = { 1, 4 }, size = 0.4 }))
		table.insert(layers, B.light({ at = { 0, 6, 0 }, brightness = 4, range = 30, life = 2 }))
		return B.spec({ name = "StarFall", palette = PAL.holy, layers = layers })
	end })
----------------------------------------------------------------------------------------------- more MOVEMENT
add({ id = "superjump", title = "Super Jump", category = "Movement", tags = "leap launch high takeoff spring",
	shake = { amp = 0.3, dur = 0.25 }, blurb = "A cracked launch ring and rising wind as you shoot up",
	build = function()
		return B.spec({ name = "SuperJump", palette = PAL.wind, layers = {
			B.flash({ at = { 0, 0.6, 0 }, size = 4 }),
			B.ring({ size = 10, color = "core", lifetime = 0.4 }),
			B.decalDisc({ tex = "CRACKSTAR", size = 7, color = "ink", life = 1.6, fade = { { 0, 0.2 }, { 0.7, 0.3 }, { 1, 1 } } }),
			B.dust({ count = 14, size = 3.5 }),
			B.streaks({ at = { 0, 1, 0 }, dir = "Top", spread = { 10, 10 }, speed = { 90, 140 }, count = 14, size = 2 }),
			B.windRing({ at = { 0, 1.5, 0 }, size = 4, lifetime = 0.3 }),
			B.windRing({ id = "r2", t = 0.05, at = { 0, 5, 0 }, size = 5, lifetime = 0.35 }),
			B.windRing({ id = "r3", t = 0.1, at = { 0, 9, 0 }, size = 6, lifetime = 0.4 }),
		} })
	end })
add({ id = "launchpad", title = "Launch Pad", category = "Movement", tags = "pad bounce boost trampoline booster",
	blurb = "A glowing pad fires you up through rising rings",
	build = function()
		return B.spec({ name = "LaunchPad", palette = PAL.energy, layers = {
			B.decalDisc({ size = 7, life = 1.2, spin = { 0, 120, 0 }, color = "body" }),
			B.pillar({ height = 16, width = 3, life = 0.5, color = "body" }),
			B.windRing({ at = { 0, 1, 0 }, size = 3.5, lifetime = 0.3 }),
			B.windRing({ id = "r2", t = 0.05, at = { 0, 4, 0 }, size = 3.8, lifetime = 0.32 }),
			B.windRing({ id = "r3", t = 0.1, at = { 0, 7, 0 }, size = 4.1, lifetime = 0.34 }),
			B.rise({ tex = "STREAK", count = 24, over = 0.4, radius = 2, speed = { 20, 30 }, size = 0.6,
				props = { Orientation = "VelocityParallel", Squash = { { 0, 3 }, { 1, 2 } } } }),
			B.ring({ size = 8 }),
			B.light({ at = { 0, 2, 0 }, brightness = 5, range = 14, life = 0.6 }),
		} })
	end })
add({ id = "slidedust", title = "Slide Dust", category = "Movement", tags = "slide skid drift trail sprint",
	blurb = "A dust trail and pebbles as you slide along the ground",
	build = function()
		local path = { { 0, { 0, 0.4, 0 } }, { 0.6, { 0, 0.4, -10 }, "quadOut" } }
		return B.spec({ name = "SlideDust", palette = PAL.earth, layers = {
			B.dust({ count = 8, size = 3, speed = { 10, 18 } }),
			B.trail({ life = 0.6, path = path, tex = "SMOKE", size = 3.4, color = "smoke", le = 0.05, lifetime = { 0.8, 1.3 },
				rate = { { 0, 80 }, { 1, 60 } }, props = { LightInfluence = 0.8, Speed = { 2, 5 }, SpreadAngle = { 70, 70 },
					Transparency = { { 0, 0.3 }, { 0.6, 0.55 }, { 1, 1 } } } }),
			B.trail({ id = "pebbles", life = 0.6, path = path, tex = "ROCKS", size = 0.3, color = "smoke", le = 0, lifetime = { 0.4, 0.7 },
				rate = { { 0, 30 }, { 1, 20 } }, props = { FlipbookLayout = 2, FlipbookMode = "Loop", LightInfluence = 1, Speed = { 6, 12 },
					SpreadAngle = { 50, 50 }, Acceleration = { 0, -40, 0 }, EmissionDirection = "Top" } }),
			B.streaks({ at = { 0, 1, -2 }, dir = "Back", spread = { 8, 8 }, speed = { 40, 70 }, count = 8, size = 1.2, color = "core" }),
		} })
	end })
add({ id = "jetburst", title = "Jet Burst", category = "Movement", tags = "jet jetpack thruster rocket hover propulsion",
	blurb = "Thruster flames and smoke blasting the ground below", shake = { amp = 0.2, dur = 0.8 },
	build = function()
		local nozzle = { 0, 2.5, 1 }
		return B.spec({ name = "JetBurst", palette = PAL.fire, layers = {
			B.flames({ at = nozzle, life = 0.9, box = { 0.6, 0.3, 0.6 }, size = 2.6, rateTrack = { { 0, 140 }, { 0.8, 140 }, { 0.9, 0 } },
				props = { EmissionDirection = "Bottom", Speed = { 45, 65 }, SpreadAngle = { 7, 7 }, Acceleration = { 0, -5, 0 },
					Orientation = "FacingCamera", Rotation = { -360, 360 }, Lifetime = { 0.12, 0.2 } } }),
			B.streaks({ id = "core", at = nozzle, dir = "Bottom", spread = { 4, 4 }, speed = { 50, 70 }, size = 1.3, color = "white",
				lifetime = { 0.05, 0.09 }, emit = emits(0, 0.8, 0.02, 2) }),
			B.smoke({ at = { 0, 0.5, 1 }, count = 18, size = 5, emit = { { 0.08, 18, 0.8 } }, speed = { 10, 18 }, spread = { 85, 85 } }),
			B.ring({ size = 8, color = "core", emit = emits(0, 0.8, 0.15) }),
			B.dust({ at = { 0, 0.2, 1 }, count = 14, size = 3.5, emit = { { 0, 14, 0.8 } } }),
			{ id = "flicker", kind = "light", t = 0, life = 0.9, at = { 0, 1.5, 1 }, props = { Color = "body", Range = 16, Brightness = 0 },
				tracks = { Brightness = { { 0, 6 }, { 0.15, 4 }, { 0.3, 6 }, { 0.45, 4 }, { 0.6, 6 }, { 0.9, 0 } } } },
		} })
	end })
---------------------------------------------------------------------------------------------- more GAME FEEL
add({ id = "coinburst", title = "Coin Burst", category = "Game feel", tags = "coins money cash gold shower payout jackpot",
	blurb = "Shiny coins pop out, flip, land and sparkle",
	build = function()
		return B.spec({ name = "CoinBurst", palette = PAL.holy, layers = {
			coins({ count = 20 }),
			B.flash({ at = { 0, 1.5, 0 }, size = 4, color = "core" }),
			B.star({ at = { 0, 2, 0 }, size = 5, tex = "SPARKLE", lifetime = 0.35 }),
			B.ring({ size = 7, color = "core", lifetime = 0.4 }),
			B.specks({ at = { 0, 1.5, 0 }, count = 20, speed = { 10, 20 }, tex = "SPARKLE", size = 0.35 }),
			B.light({ at = { 0, 2, 0 }, brightness = 4, range = 12, life = 0.5 }),
		} })
	end })
add({ id = "egghatch", title = "Egg Hatch", category = "Game feel", tags = "egg hatch pet reveal crack open simulator rarity",
	shake = { amp = 0.25, dur = 0.25 }, blurb = "The shell bursts with rays, sparkles and confetti",
	build = function()
		local at = { 0, 2, 0 }
		return B.spec({ name = "EggHatch", palette = PAL.party, layers = {
			B.flash({ at = at, size = 8, color = "white" }),
			B.rays({ at = at, size = 16, lifetime = 0.9, color = "core" }),
			B.star({ at = at, size = 10, tex = "SPARKLE", lifetime = 0.5 }),
			B.debris({ at = at, count = 14, color = "white", size = 0.6, speed = { 16, 28 }, spread = { 70, 70 },
				props = { LightInfluence = 0.9, LightEmission = 0.15 } }),
			B.confetti({ count = 30, at = { 0, 2, 0 } }),
			B.ring({ size = 10, color = "core" }),
			B.specks({ at = at, count = 30, speed = { 12, 24 }, tex = "SPARKLE" }),
			B.light({ at = at, brightness = 6, range = 18, life = 0.8 }),
		} })
	end })
add({ id = "lootbeam", title = "Loot Beam", category = "Game feel", ambient = true, tags = "loot drop rarity legendary item marker glow",
	blurb = "A tall beam of light marking dropped loot (recolour per rarity)",
	build = function()
		return B.spec({ name = "LootBeam", palette = PAL.holy, layers = {
			softBand("beamGlow", { 0, 0, 0 }, { 0, 28, 0 }, 3.2, 1.8, "body", { brightness = 2.5 }),
			softBand("beamCore", { 0, 0, 0 }, { 0, 24, 0 }, 1, 0.5, "core", { brightness = 3, transparency = { { 0, 0 }, { 0.8, 0.3 }, { 1, 1 } } }),
			B.area({ id = "motes", at = { 0, 1, 0 }, box = { 1.6, 0.5, 1.6 }, rate = 12, props = {
				Texture = "SPARKLE", Color = "core", LightEmission = 1, Brightness = 3, LightInfluence = 0, Shape = "Box",
				Orientation = "FacingCamera", EmissionDirection = "Top", Speed = { 4, 8 }, Acceleration = { 0, 2, 0 },
				Size = { { 0, 0 }, { 0.2, 0.4 }, { 1, 0 } }, Transparency = 0, Lifetime = { 1.5, 2.5 } } }),
			B.decalDisc({ size = 5, life = 600, spin = { 0, 45, 0 }, color = "body", scale = { { 0, { 1, 1, 1 } } },
				fade = { { 0, 1 }, { 0.0008, 0 }, { 1, 0 } } }),
			{ id = "glow", kind = "light", t = 0, life = 600, at = { 0, 3, 0 }, props = { Color = "body", Range = 12, Brightness = 2 } },
		} })
	end })
add({ id = "questcomplete", title = "Quest Complete", category = "Game feel", tags = "quest mission done success objective",
	blurb = "Golden rays, a star burst, sparkles and confetti",
	build = function()
		local at = { 0, 4, 0 }
		return B.spec({ name = "QuestComplete", palette = PAL.holy, layers = {
			B.flash({ at = at, size = 6 }),
			B.rays({ at = at, size = 18, lifetime = 1 }),
			B.star({ at = at, size = 10, tex = "SPARKLE", lifetime = 0.6 }),
			B.ring({ size = 12 }),
			B.ring({ id = "r2", t = 0.15, size = 16, tex = "THINRING" }),
			B.rise({ count = 30, over = 1, radius = 3, tex = "SPARKLE" }),
			B.specks({ at = at, count = 30, speed = { 12, 26 } }),
			B.confetti({ count = 24, at = { 0, 3, 0 } }),
			B.light({ at = at, brightness = 6, range = 22, life = 1 }),
		} })
	end })
add({ id = "rebirth", title = "Rebirth", category = "Game feel", tags = "prestige reborn ascend rank power rainbow",
	shake = { amp = 0.4, dur = 0.5 }, blurb = "A huge column of light, rainbow rings and a shower of sparkles",
	build = function()
		return B.spec({ name = "Rebirth", palette = PAL.party, layers = {
			B.pillar({ height = 40, width = 6, life = 1.2, color = "body" }),
			B.flash({ at = { 0, 3, 0 }, size = 9 }),
			B.rays({ at = { 0, 3, 0 }, size = 18, lifetime = 0.8, color = "core" }),
			B.ring({ size = 18, color = "accent" }),
			B.ring({ id = "r2", t = 0.12, size = 24, color = "body", tex = "THINRING" }),
			B.windRing({ at = { 0, 1, 0 }, size = 6, lifetime = 0.6 }),
			B.windRing({ id = "w2", t = 0.15, at = { 0, 5, 0 }, size = 5, lifetime = 0.6, color = "accent" }),
			B.rise({ count = 50, over = 1.2, radius = 4, color = { { 0, "white" }, { 0.3, "core" }, { 0.7, "body" }, { 1, "accent" } } }),
			B.specks({ at = { 0, 4, 0 }, count = 40, speed = { 14, 30 }, tex = "SPARKLE" }),
			B.grade({ brightness = 0.15, contrast = 0.1, saturation = 0.4 }),
			B.light({ at = { 0, 4, 0 }, brightness = 8, range = 30, life = 1.2 }),
		} })
	end })
add({ id = "xpgain", title = "XP Gain", category = "Game feel", tags = "xp experience exp orbs points progress",
	blurb = "Glowing orbs fly in from all around and pop into you",
	build = function()
		local chest = { 0, 3, 0 }
		return B.spec({ name = "XPGain", palette = PAL.nature, layers = {
			B.specks({ at = chest, count = 24, emit = { { 0, 24, 0.6 } }, lifetime = { 0.5, 0.7 }, tex = "SOFTDOT", size = 0.55, color = "accent",
				props = { Shape = "Sphere", ShapeInOut = "Inward", ShapeStyle = "Surface", Speed = { 10, 16 }, Drag = 0, Acceleration = { 0, 0, 0 } },
				box = { 12, 12, 12 } }),
			B.specks({ id = "cores", at = chest, count = 24, emit = { { 0, 24, 0.6 } }, lifetime = { 0.5, 0.7 }, tex = "SPARK", size = 0.25, color = "white",
				props = { Shape = "Sphere", ShapeInOut = "Inward", ShapeStyle = "Surface", Speed = { 10, 16 }, Drag = 0, Acceleration = { 0, 0, 0 } },
				box = { 12, 12, 12 } }),
			B.bloom({ t = 0.6, at = chest, size = 5, alpha = 0.4, lifetime = 0.4 }),
			B.flash({ t = 0.65, at = chest, size = 3.5, color = "core" }),
			B.ring({ t = 0.65, size = 6, color = "body" }),
			B.rise({ t = 0.65, count = 12, over = 0.3, radius = 1.5, tex = "SPARKLE", size = 0.35 }),
			B.light({ at = chest, brightness = 3, range = 12, life = 0.9 }),
		} })
	end })
add({ id = "bossspawn", title = "Boss Spawn", category = "Game feel", tags = "boss arrive summon emerge villain entrance dramatic",
	shake = { amp = 1, dur = 0.8, t = 1 }, blurb = "Dark smoke, red lightning and a pillar as the boss arrives",
	build = function()
		return B.spec({ name = "BossSpawn", palette = PAL.void, layers = {
			B.decalDisc({ size = 20, life = 2.6, spin = { 0, 30, 0 }, color = "accent" }),
			B.smoke({ tex = "BILLOW", at = { 0, 1, 0 }, count = 20, size = 9, color = "ink", le = 0, li = 0.5, speed = { 6, 14 }, spread = { 85, 85 },
				lifetime = { 1.6, 2.4 }, emit = { { 0, 20, 1 } } }),
			B.bolts({ at = { 0, 6, 0 }, box = { 10, 6, 10 }, size = 6, life = 1, strikes = emits(0.2, 0.9, 0.12, 1), color = "accent" }),
			B.pillar({ t = 1, height = 50, width = 8, color = "body", life = 0.7 }),
			B.inkFlash({ t = 1, at = { 0, 3, 0 }, size = 14 }),
			B.flash({ t = 1, at = { 0, 3, 0 }, size = 12 }),
			B.shockwave({ t = 1, at = { 0, 3, 0 }, size = 20 }),
			B.ring({ t = 1, size = 28 }),
			B.grade({ life = 1.6, tracks = { Saturation = { { 0, 0 }, { 0.3, -0.4 }, { 1, -0.5 }, { 1.1, 0.3 }, { 1.6, 0 } },
				Brightness = { { 0, 0 }, { 0.3, -0.08 }, { 1, -0.1 }, { 1.05, 0.2 }, { 1.6, 0 } }, Contrast = { { 0, 0 }, { 0.3, 0.2 }, { 1.6, 0 } } } }),
			{ id = "flicker", kind = "light", t = 0, life = 1.7, at = { 0, 5, 0 }, props = { Color = "accent", Range = 30, Brightness = 0 },
				tracks = { Brightness = { { 0, 0 }, { 0.3, 3 }, { 0.35, 0.5 }, { 0.5, 3 }, { 0.55, 0.5 }, { 0.8, 3 }, { 1, 10 }, { 1.7, 0 } } } },
		} })
	end })

------------------------------------------------------------------------------------------------- more AMBIENT
add({ id = "fallingleaves", title = "Falling Leaves", category = "Ambient", ambient = true, tags = "leaves autumn fall forest tree loop",
	blurb = "Autumn leaves drifting and tumbling down",
	build = function()
		return B.spec({ name = "FallingLeaves", palette = PAL.autumn, layers = {
			fallingPlates({ count = 44, area = 44, height = 22, w = 0.6, l = 0.42 }),
		} })
	end })
add({ id = "petals", title = "Cherry Blossoms", category = "Ambient", ambient = true, tags = "cherry blossom petals sakura spring flowers loop",
	blurb = "Pink petals floating down on a light breeze",
	build = function()
		return B.spec({ name = "CherryBlossoms", palette = PAL.sakura, layers = {
			fallingPlates({ count = 60, area = 40, height = 20, w = 0.32, l = 0.24, minSpeed = 1.1, maxSpeed = 2, drift = 5,
				colors = { "body", "core", "white", "accent" } }),
		} })
	end })
add({ id = "bubbles", title = "Bubbles", category = "Ambient", ambient = true, tags = "bubbles underwater water fish tank loop",
	blurb = "Bubbles wobbling up from the floor",
	build = function()
		return B.spec({ name = "Bubbles", palette = PAL.water, layers = {
			B.area({ id = "bubbles", at = { 0, 0.5, 0 }, box = { 20, 1, 20 }, rate = 8, props = {
				Texture = "THINRING", Color = "core", LightEmission = 0.6, Brightness = 1.5, LightInfluence = 0.3, Shape = "Box",
				Orientation = "FacingCamera", EmissionDirection = "Top", Speed = { 2, 4 }, Acceleration = { 0.4, 1.5, 0 },
				Size = { { 0, 0.2 }, { 1, 0.6 } }, Transparency = { { 0, 0.2 }, { 0.85, 0.3 }, { 1, 1 } }, Lifetime = { 3, 5 } } }),
			B.area({ id = "glints", at = { 0, 0.5, 0 }, box = { 20, 1, 20 }, rate = 5, props = {
				Texture = "SPEC", Color = "white", LightEmission = 0.8, Brightness = 2, LightInfluence = 0.2, Shape = "Box",
				Orientation = "FacingCamera", EmissionDirection = "Top", Speed = { 2.5, 4.5 }, Acceleration = { 0.4, 1.5, 0 },
				Size = { { 0, 0.08 }, { 1, 0.2 } }, Transparency = { { 0, 0.1 }, { 0.85, 0.2 }, { 1, 1 } }, Lifetime = { 3, 5 } } }),
		} })
	end })
add({ id = "wisps", title = "Spirit Wisps", category = "Ambient", ambient = true, tags = "wisps spirit ghost souls spooky haunted glow loop",
	blurb = "Soft glowing wisps floating through the air",
	build = function()
		return B.spec({ name = "SpiritWisps", palette = PAL.spirit, layers = {
			B.area({ id = "wispGlow", at = { 0, 3, 0 }, box = { 30, 4, 30 }, rate = 3, props = {
				Texture = "SOFTDOT", Color = "body", LightEmission = 1, Brightness = 2, LightInfluence = 0, Shape = "Box",
				Orientation = "FacingCamera", EmissionDirection = "Top", SpreadAngle = { 180, 180 }, Speed = { 0.4, 1.2 },
				Acceleration = { 0, 0.3, 0 }, Size = { { 0, 0 }, { 0.15, 1.2 }, { 0.5, 0.8 }, { 0.85, 1.2 }, { 1, 0 } },
				Transparency = { { 0, 0.4 }, { 0.5, 0.5 }, { 1, 1 } }, Lifetime = { 6, 9 } } }),
			B.area({ id = "wispCore", at = { 0, 3, 0 }, box = { 30, 4, 30 }, rate = 3, props = {
				Texture = "SPARK", Color = "white", LightEmission = 1, Brightness = 3, LightInfluence = 0, Shape = "Box",
				Orientation = "FacingCamera", EmissionDirection = "Top", SpreadAngle = { 180, 180 }, Speed = { 0.4, 1.2 },
				Acceleration = { 0, 0.3, 0 }, Size = { { 0, 0 }, { 0.15, 0.3 }, { 0.85, 0.3 }, { 1, 0 } }, Transparency = 0, Lifetime = { 6, 9 } } }),
		} })
	end })
add({ id = "godrays", title = "Light Rays", category = "Ambient", ambient = true, tags = "god rays sunbeams shafts sunlight heavenly loop",
	blurb = "Soft shafts of light from above with floating dust",
	build = function()
		local soft = { { 0, 0.72 }, { 0.5, 0.78 }, { 1, 1 } }
		local grow = { { 0, 0 }, { 2, 1, "sineOut" }, { 600, 1 } }
		return B.spec({ name = "LightRays", palette = PAL.holy, layers = {
			softBand("shaft1", { -9, 36, 10 }, { -3, 0, 2 }, 5, 8, "core", { brightness = 1.4, transparency = soft, widthTrack = grow }),
			softBand("shaft2", { 0, 36, 12 }, { 3, 0, 3 }, 7, 11, "core", { brightness = 1.4, transparency = soft, widthTrack = grow }),
			softBand("shaft3", { 8, 36, 9 }, { 9, 0, 0 }, 4, 7, "core", { brightness = 1.4, transparency = soft, widthTrack = grow }),
			B.area({ id = "dust", at = { 2, 4, 2 }, box = { 16, 6, 10 }, rate = 6, props = {
				Texture = "SPEC", Color = "core", LightEmission = 1, Brightness = 2, LightInfluence = 0.2, Shape = "Box",
				Orientation = "FacingCamera", EmissionDirection = "Top", SpreadAngle = { 180, 180 }, Speed = { 0.1, 0.4 },
				Size = { { 0, 0 }, { 0.2, 0.12 }, { 0.8, 0.12 }, { 1, 0 } }, Transparency = 0.3, Lifetime = { 6, 10 } } }),
		} })
	end })
---------------------------------------------------------------------------------------------------------- index
Library.list = list
Library.byId = {}
for _, e in list do
	Library.byId[e.id] = e
end

-- Entries shown in the UI (helpers like meteorfall stay hidden), filtered by text, category and favourites.
function Library.search(query: string?, category: string?, favourites)
	local q = string.lower(query or "")
	local out = {}
	for _, e in list do
		if e.hidden then
			continue
		end
		if category and category ~= "All" then
			if category == "Favourites" then
				if not (favourites and favourites[e.id]) then
					continue
				end
			elseif e.category ~= category then
				continue
			end
		end
		if q ~= "" then
			local hay = string.lower(e.id .. " " .. e.title .. " " .. (e.tags or "") .. " " .. e.category)
			local ok = true
			for word in string.gmatch(q, "%S+") do
				if not string.find(hay, word, 1, true) then
					ok = false
					break
				end
			end
			if not ok then
				continue
			end
		end
		table.insert(out, e)
	end
	return out
end

-- Best entry for free text (used by the offline prompt parser): most tag hits wins.
-- Best effect for some text and its score. The effect's whole title said outright wins ("level up", "heal",
-- "meteor strike"); then title words, then tags. `prefer` (the broad kind the words point at, e.g. "slash") breaks
-- near-ties; combos lose ties to single effects; "loop"/"ambient" favours looping effects. 2 or more is a real match.
-- (Same scoring as the bot server's catalog.match_effect, so bots and the plugin read text the same way.)
function Library.match(text: string, prefer: string?)
	local t = " " .. string.lower(text or "") .. " "
	local function has(w)
		return string.find(t, "%f[%a]" .. string.gsub(w, "%p", "%%%0") .. "%f[%A]") ~= nil
	end
	local wantsLoop = has("loop") or has("looping") or has("ambient")
	local best, bestScore = nil, 0
	for _, e in list do
		if e.hidden then
			continue
		end
		local title = string.lower(e.title)
		local score = 0
		if has(title) or has((string.gsub(title, " ", ""))) then
			score += 8
		end
		local titleWords = {}
		for w in string.gmatch(title, "%a+") do
			if not titleWords[w] then
				titleWords[w] = true
				if #w > 2 and has(w) then
					score += 2.5
				end
			end
		end
		local seen = {}
		for w in string.gmatch(string.lower(e.tags or ""), "%a+") do
			if not titleWords[w] and not seen[w] then
				seen[w] = true
				if #w > 2 and has(w) then
					score += if #w > 5 then 2 else 1
				end
			end
		end
		if prefer and e.id == prefer then
			score += 1
		end
		if e.combo and score < 8 then
			score -= 0.5
		end
		if wantsLoop and e.ambient then
			score += 2
		end
		if score > bestScore then
			best, bestScore = e, score
		end
	end
	return best, bestScore
end

-- Every word of an effect's title and tags (to tell whether "fire" or "black" already describes it).
function Library.words(e): { [string]: boolean }
	local out = {}
	for w in string.gmatch(string.lower(e.title .. " " .. (e.tags or "")), "%a+") do
		out[w] = true
	end
	return out
end

return Library
