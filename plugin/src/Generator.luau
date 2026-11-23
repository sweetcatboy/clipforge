-- ClipForge Generator: composes showcase-grade effects from a description.
--
--   local spec = Generator.build(Generator.fromPrompt("golden glowing cube with light wings"))
--   FX.play({ generate = { prompt = "galaxy cube with orbit rings", seed = 3 } }, cframe)
--
-- Three compositions, each a stack of layers the way high-end Roblox VFX artists build them:
--   showcase  a hero centrepiece (glass/wire cube, crystal, orb, sphere) framed by orbit rings, light wings, a heart or
--             halos, in an atmosphere (nebula, stars, floating flakes, petals, a leaf mound), with light shafts, rays,
--             arcs; pops in with a flash, holds while everything orbits and drifts, then collapses with a burst.
--   impact    a combat payoff: charge (arcs converging on an orb), one-frame hit (ink + white flash, chromatic star,
--             needle burst, crystal shards, stacked neon halos, light shafts), aftermath (smoke wall, wind crescents,
--             debris, embers, cracks).
--   vortex    a black hole: black core with a photon ring, tilted accretion disc, swirling wisps, ground vortex,
--             levitating rocks orbiting, a dome; collapses into a burst.
-- Everything is geometry (Neon/Glass/ForceField parts, Beams) or verified public textures: no uploads needed.

local B = require(script.Parent:WaitForChild("Blocks"))
local Generator = {}

-- extra textures from the studied effects (chromatic and needle art)
B.TEX.CHROMASTAR = 17062416111 -- cross with RGB-split fringe (multicolour: keep white)
B.TEX.CHROMASHARDS = 12401154143 -- chromatic shards (multicolour)
B.TEX.RAINBOWHALO = 12105193694 -- soft double rainbow halo (multicolour)
B.TEX.RAINBOWRING = 85664013418740 -- thin rainbow ring (multicolour)
B.TEX.NEEDLE = 8970920735 -- diamond needle with long thin tips
B.TEX.NEEDLE2 = 8905957078 -- needle from the edge to the centre
B.TEX.FOG = 119473092655714 -- dark vortex of noisy wisps, galaxy fog (black card: additive only)
B.TEX.PUFFRING = 14004151283 -- 4x4 ring of puffs growing outward
B.TEX.DUSTPUFF = 14945509165 -- 4x4 realistic dust puff

Generator.PALETTES = {
	mono = { white = "#FFFFFF", core = "#F4F4F6", body = "#D8D9DF", accent = "#A9ADB8", deep = "#2A2C33", ink = "#060607",
		smoke = "#7E818A", keepWhite = "#FFFFFF" },
	golden = { white = "#FFFDF2", core = "#FFE9A8", body = "#FFC23A", accent = "#FFF3C8", deep = "#3A2A08", ink = "#0E0A02",
		smoke = "#4A3A1A", keepWhite = "#FFFFFF" },
	galaxy = { white = "#FFFFFF", core = "#E4DEFF", body = "#7A6BFF", accent = "#3FB7FF", deep = "#140A3A", ink = "#05030F",
		smoke = "#2A2050", keepWhite = "#FFFFFF" },
	emerald = { white = "#F2FFF6", core = "#C8FFD9", body = "#2BE36A", accent = "#A8FF5C", deep = "#04301A", ink = "#010A05",
		smoke = "#0E2A18", keepWhite = "#FFFFFF" },
	abyss = { white = "#F2FAFF", core = "#BFEFFF", body = "#2FA8FF", accent = "#7FE0FF", deep = "#03243F", ink = "#000000",
		smoke = "#1A3448", keepWhite = "#FFFFFF" },
	crimson = { white = "#FFF2F2", core = "#FFB0B0", body = "#FF2E4A", accent = "#FF8A3D", deep = "#3A0008", ink = "#080002",
		smoke = "#3A1A20", keepWhite = "#FFFFFF" },
}

------------------------------------------------------------------------------------------------------- helpers
local function col(ctx, name, fallback)
	local hex = ctx.palette[name] or name
	local r, g, b = string.match(hex or "", "#(%x%x)(%x%x)(%x%x)")
	if r then
		return Color3.fromRGB(tonumber(r, 16), tonumber(g, 16), tonumber(b, 16))
	end
	return fallback or Color3.new(1, 1, 1)
end

local function neon(ctx, size, color, material)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Material = material or Enum.Material.Neon
	p.Color = color
	p.Size = size
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Parent = ctx.folder
	return p
end

local function smooth(x)
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end

local function backOut(x)
	x = math.clamp(x, 0, 1)
	local c1 = 1.70158
	return 1 + (c1 + 1) * (x - 1) ^ 3 + c1 * (x - 1) ^ 2
end

-- 0 -> 1 pop in over `inT`, hold, then 1 -> 0 over the last `outT` seconds of `life`
local function envelope(lt, life, inT, outT)
	local a = if inT > 0 then backOut(lt / inT) else 1
	local b = if outT > 0 then smooth((life - lt) / outT) else 1
	return math.max(0, a) * b
end

local function base(ctx, L)
	return ctx.origin * CFrame.new(L.at * ctx.scale)
end

local function custom(id, o, start, update)
	return {
		id = id, kind = "custom", t = o.t or 0, life = o.life or 3, at = o.at or { 0, 0, 0 },
		start = start, update = update,
		stop = function(ctx, L, s)
			for _, p in s.parts or {} do
				p:Destroy()
			end
			if s.holder then
				s.holder:Destroy()
			end
		end,
	}
end

----------------------------------------------------------------------------------------------- geometry layers
-- Cube: Neon edges (wire) and optionally a glass body with a glowing core; spins, breathes, collapses at the end.
function Generator.cube(o)
	o = o or {}
	local size, th = o.size or 3, o.edge or 0.09
	return custom("cube", o, function(ctx, L)
		local s = { parts = {}, edges = {} }
		local h = size / 2
		local edgeColor = col(ctx, o.edgeColor or "white")
		for _, axis in { "X", "Y", "Z" } do
			for _, a in { -1, 1 } do
				for _, b in { -1, 1 } do
					local mid = if axis == "X" then Vector3.new(0, a * h, b * h) elseif axis == "Y" then Vector3.new(a * h, 0, b * h) else Vector3.new(a * h, b * h, 0)
					local sz = if axis == "X" then Vector3.new(size + th, th, th) elseif axis == "Y" then Vector3.new(th, size + th, th) else Vector3.new(th, th, size + th)
					local p = neon(ctx, sz, edgeColor)
					table.insert(s.parts, p)
					table.insert(s.edges, { p = p, mid = mid, size = sz })
				end
			end
		end
		if o.glass ~= false then
			s.body = neon(ctx, Vector3.one * size * 0.97, col(ctx, o.bodyColor or "body"), Enum.Material.Glass)
			s.body.Transparency = 0.4
			s.body.Reflectance = 0.15
			table.insert(s.parts, s.body)
			s.core = neon(ctx, Vector3.one * size * 0.42, col(ctx, "core"))
			s.core.Shape = Enum.PartType.Ball
			s.core.Transparency = 0.05
			table.insert(s.parts, s.core)
			s.shell = neon(ctx, Vector3.one * size * 1.12, col(ctx, "body"), Enum.Material.ForceField)
			table.insert(s.parts, s.shell)
		end
		return s
	end, function(ctx, L, s, lt)
		local k = envelope(lt, L.life, o.popIn or 0.35, o.popOut or 0.35)
		local breathe = 1 + math.sin(lt * 2.4) * 0.03
		local sc = math.max(0.001, k * breathe * ctx.scale)
		local spinY, spinX = math.rad((o.spin or 28) * lt), math.rad((o.tumble or 12) * lt)
		local cf = base(ctx, L) * CFrame.new(0, math.sin(lt * 1.6) * 0.15 * ctx.scale, 0) * CFrame.Angles(spinX, spinY, spinX * 0.5)
		for _, e in s.edges do
			e.p.Size = e.size * sc
			e.p.CFrame = cf * CFrame.new(e.mid * sc)
		end
		if s.body then
			s.body.Size = Vector3.one * size * 0.97 * sc
			s.body.CFrame = cf
			s.core.Size = Vector3.one * size * 0.42 * sc * (1 + math.sin(lt * 5) * 0.08)
			s.core.CFrame = cf
			s.shell.Size = Vector3.one * size * 1.12 * sc
			s.shell.CFrame = cf
		end
	end)
end

-- Crisp Neon ring (halo, orbit, photon ring). Grows r0 -> r1, can tilt, spin, face the camera, carry a comet.
function Generator.ring(o)
	o = o or {}
	local n = o.segments or 40
	return custom("ring", o, function(ctx, L)
		local s = { parts = {} }
		local c = col(ctx, o.color or "white")
		for i = 1, n do
			table.insert(s.parts, neon(ctx, Vector3.new(0.2, 0.08, 0.08), c))
		end
		if o.comet then
			s.comet = neon(ctx, Vector3.one * 0.45, col(ctx, "white"))
			s.comet.Shape = Enum.PartType.Ball
			table.insert(s.parts, s.comet)
		end
		return s
	end, function(ctx, L, s, lt)
		local g = smooth(lt / (o.grow or 0.4))
		local r = ((o.r0 or 0.5) + ((o.r1 or 6) - (o.r0 or 0.5)) * (if o.ease == "linear" then math.clamp(lt / (o.grow or 0.4), 0, 1) else g)) * ctx.scale
		local fadeOut = smooth((L.life - lt) / (o.fadeOut or 0.4))
		local th = (o.thick or 0.12) * ctx.scale * fadeOut * (if o.thin then (1 - 0.7 * g) else 1)
		local cf = base(ctx, L)
		if o.faceCamera and workspace.CurrentCamera then
			local p = cf.Position
			cf = CFrame.lookAt(p, workspace.CurrentCamera.CFrame.Position) * CFrame.Angles(math.rad(90), 0, 0)
		elseif o.tilt then
			cf = cf * CFrame.Angles(math.rad(o.tilt[1] or 0), math.rad(o.tilt[2] or 0), math.rad(o.tilt[3] or 0))
		end
		cf = cf * CFrame.Angles(0, math.rad((o.spin or 0) * lt), 0)
		local seg = 2 * math.pi * r / n * 1.08
		for i = 1, n do
			local a = (i / n) * math.pi * 2
			local pos = cf * Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
			local tangent = cf:VectorToWorldSpace(Vector3.new(-math.sin(a), 0, math.cos(a)))
			local p = s.parts[i]
			p.Size = Vector3.new(math.max(seg, 0.01), math.max(th, 0.005), math.max(th, 0.005))
			p.CFrame = CFrame.fromMatrix(pos, tangent, cf.UpVector)
		end
		if s.comet then
			local a = lt * (o.cometSpeed or 2.2)
			s.comet.CFrame = cf * CFrame.new(math.cos(a) * r, 0, math.sin(a) * r)
			s.comet.Size = Vector3.one * 0.45 * ctx.scale * fadeOut
		end
	end)
end

-- Lightning arcs: jagged Neon chains re-struck every few frames, from the centre outward (or converging).
function Generator.arcs(o)
	o = o or {}
	local count, segs = o.count or 4, o.segments or 7
	return custom("arcs", o, function(ctx, L)
		local s = { parts = {}, arcs = {}, last = -1 }
		local c = col(ctx, o.color or "white")
		for i = 1, count do
			local arc = {}
			for j = 1, segs do
				local p = neon(ctx, Vector3.new(0.1, 0.1, 0.1), c)
				table.insert(arc, p)
				table.insert(s.parts, p)
			end
			table.insert(s.arcs, arc)
		end
		return s
	end, function(ctx, L, s, lt)
		local strike = math.floor(lt / (o.every or 0.06))
		local fade = smooth((L.life - lt) / 0.15)
		if strike == s.last then
			return
		end
		s.last = strike
		local rng = Random.new(strike * 97 + (o.seed or 1))
		local cf = base(ctx, L)
		local reach = (o.radius or 6) * ctx.scale
		local conv = if o.converge then math.clamp(lt / L.life, 0, 1) else 0
		for i, arc in s.arcs do
			local dir = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-0.5, 1), rng:NextNumber(-1, 1))
			if dir.Magnitude < 0.1 then
				dir = Vector3.yAxis
			end
			dir = dir.Unit
			local a = cf.Position + dir * reach * (if o.converge then (1 - conv) else 0.1)
			local b = cf.Position + dir * reach * (if o.converge then 0.05 else rng:NextNumber(0.6, 1))
			local prev = a
			for j, p in arc do
				local u = j / #arc
				local jit = (o.jitter or 0.7) * ctx.scale * math.sin(u * math.pi)
				local nxt = a:Lerp(b, u) + Vector3.new(rng:NextNumber(-jit, jit), rng:NextNumber(-jit, jit), rng:NextNumber(-jit, jit))
				if j == #arc then
					nxt = b
				end
				local len = (nxt - prev).Magnitude
				local th = (o.thick or 0.1) * ctx.scale * fade * (1 - u * 0.5)
				p.Size = Vector3.new(math.max(th, 0.005), math.max(th, 0.005), math.max(len, 0.01))
				p.CFrame = CFrame.lookAt((prev + nxt) / 2, nxt)
				p.Transparency = if rng:NextNumber() < 0.15 then 0.7 else 0
				prev = nxt
			end
		end
	end)
end

-- Light wings: fans of glowing feathers (Beams), flapping gently, with sparkles along the edges.
function Generator.wings(o)
	o = o or {}
	local feathers = o.feathers or 14
	return custom("wings", o, function(ctx, L)
		local s = { parts = {}, beams = {} }
		local holder = Instance.new("Part")
		holder.Anchored, holder.CanCollide, holder.CanQuery, holder.CanTouch = true, false, false, false
		holder.Transparency = 1
		holder.Size = Vector3.one * 0.2
		holder.CFrame = base(ctx, L)
		holder.Parent = ctx.folder
		s.holder = holder
		local soft = "rbxassetid://" .. tostring(B.TEX.BEAMSMOKE)
		local line = "rbxassetid://" .. tostring(B.TEX.STREAK)
		local function beam(a0, a1, tex, colorA, colorB, t0, t1, mode)
			local bm = Instance.new("Beam")
			bm.Attachment0, bm.Attachment1 = a0, a1
			bm.Texture = tex
			bm.TextureMode = mode
			bm.TextureLength = 6
			bm.TextureSpeed = -0.4
			bm.LightEmission = 1
			bm.LightInfluence = 0
			bm.Brightness = 2
			bm.FaceCamera = true
			bm.Segments = 14
			bm.Color = ColorSequence.new(colorA, colorB)
			bm.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, t0), NumberSequenceKeypoint.new(0.55, t1), NumberSequenceKeypoint.new(1, 1) })
			bm.Parent = a0.Parent
			return bm
		end
		for _, side in { -1, 1 } do
			for i = 1, feathers do
				local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
				a0.Parent, a1.Parent = holder, holder
				local body = beam(a0, a1, soft, col(ctx, "core"), col(ctx, o.color or "body"), 0.2, 0.45, Enum.TextureMode.Wrap)
				local core = beam(a0, a1, line, col(ctx, "white"), col(ctx, "core"), 0.05, 0.3, Enum.TextureMode.Stretch)
				table.insert(s.beams, { b = body, c = core, a0 = a0, a1 = a1, side = side, i = i })
			end
		end
		return s
	end, function(ctx, L, s, lt)
		local k = envelope(lt, L.life, o.popIn or 0.5, o.popOut or 0.5)
		local span = (o.span or 9) * ctx.scale * k
		local flap = math.sin(lt * (o.flapSpeed or 1.8)) * (o.flap or 0.1)
		s.holder.CFrame = base(ctx, L)
		local armA = math.rad(18) + flap
		for _, f in s.beams do
			local u = (f.i - 1) / math.max(1, feathers - 1) -- 0 = inner/lower feather, 1 = top primary
			local shoulder = Vector3.new(f.side * 0.9 * ctx.scale, 0, 0.4 * ctx.scale)
			local arm = Vector3.new(f.side * math.cos(armA), math.sin(armA), 0.08)
			local root = shoulder + arm * span * (0.08 + 0.42 * u)
			local ang = math.rad(-28 + 62 * u) + flap * (0.4 + u)
			local len = span * (0.38 + 0.55 * u ^ 0.7)
			local dir = Vector3.new(f.side * math.cos(ang), math.sin(ang), 0.1 + 0.1 * u)
			f.a0.Position = root
			f.a1.Position = root + dir.Unit * len
			f.b.Width0 = (o.width or 2.4) * ctx.scale * k
			f.b.Width1 = 0.3 * ctx.scale
			f.c.Width0 = 0.5 * ctx.scale * k
			f.c.Width1 = 0.05 * ctx.scale
			for _, bm in { f.b, f.c } do
				bm.CurveSize0 = -len * 0.18
				bm.CurveSize1 = len * 0.1
			end
		end
	end)
end

-- Heart outline (classic parametric heart) in Neon, pulsing.
function Generator.heart(o)
	o = o or {}
	local n = o.segments or 36
	return custom("heart", o, function(ctx, L)
		local s = { parts = {} }
		local c = col(ctx, o.color or "core")
		for i = 1, n do
			table.insert(s.parts, neon(ctx, Vector3.new(0.1, 0.1, 0.1), c))
		end
		return s
	end, function(ctx, L, s, lt)
		local k = envelope(lt, L.life, 0.5, 0.4)
		local pulse = 1 + math.sin(lt * 4.2) * 0.04
		local sc = (o.size or 0.42) * ctx.scale * k * pulse
		local cf = base(ctx, L)
		if workspace.CurrentCamera then
			local cam = workspace.CurrentCamera.CFrame.Position
			cf = CFrame.lookAt(cf.Position, Vector3.new(cam.X, cf.Position.Y, cam.Z))
		end
		local function P(t)
			local x = 16 * math.sin(t) ^ 3
			local y = 13 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t)
			return cf * Vector3.new(x * sc, y * sc, 0)
		end
		local th = (o.thick or 0.14) * ctx.scale * k
		for i, p in s.parts do
			local a, b = P((i - 1) / n * math.pi * 2), P(i / n * math.pi * 2)
			p.Size = Vector3.new(math.max(th, 0.005), math.max(th, 0.005), math.max((b - a).Magnitude * 1.05, 0.01))
			p.CFrame = CFrame.lookAt((a + b) / 2, b)
		end
	end)
end

-- Floating flakes / petals: thin squares drifting, tumbling and twinkling around the centre.
function Generator.flakes(o)
	o = o or {}
	local n = o.count or 34
	return custom("flakes", o, function(ctx, L)
		local s = { parts = {}, list = {} }
		local names = o.colors or { "white", "core", "body", "accent" }
		for i = 1, n do
			local c = col(ctx, names[(i % #names) + 1])
			local sz = (o.size or 0.32) * ctx.random:NextNumber(0.6, 1.3)
			local p = neon(ctx, if o.petals then Vector3.new(sz * 1.4, 0.03, sz * 0.8) else Vector3.new(sz, sz, 0.03), c,
				if o.matte then Enum.Material.SmoothPlastic else Enum.Material.Neon)
			if o.petals then
				p.Shape = Enum.PartType.Cylinder
				p.Size = Vector3.new(0.03, sz * 1.2, sz * 0.8)
			end
			table.insert(s.parts, p)
			local r = (o.radius or 10) * math.sqrt(ctx.random:NextNumber(0.05, 1))
			table.insert(s.list, { p = p, a = ctx.random:NextNumber(0, math.pi * 2), r = r, y = ctx.random:NextNumber(-(o.height or 6), o.height or 6),
				spin = Vector3.new(ctx.random:NextNumber(-2, 2), ctx.random:NextNumber(-2, 2), ctx.random:NextNumber(-2, 2)),
				drift = ctx.random:NextNumber(0.1, 0.35) * (if ctx.random:NextNumber() < 0.5 then -1 else 1), ph = ctx.random:NextNumber(0, 6) })
		end
		return s
	end, function(ctx, L, s, lt)
		local k = envelope(lt, L.life, 0.6, 0.6)
		local cf = base(ctx, L)
		for _, f in s.list do
			local a = f.a + lt * f.drift
			local y = f.y + math.sin(lt * 0.8 + f.ph) * 0.6 - (o.fall or 0) * lt
			f.p.CFrame = cf * CFrame.new(math.cos(a) * f.r * ctx.scale, y * ctx.scale, math.sin(a) * f.r * ctx.scale)
				* CFrame.Angles(f.spin.X * lt, f.spin.Y * lt, f.spin.Z * lt)
			f.p.Transparency = 1 - k * (0.55 + 0.45 * math.abs(math.sin(lt * 2 + f.ph)))
		end
	end)
end

-- A mound of leaves (thin wedges in greens), swaying.
function Generator.leaves(o)
	o = o or {}
	local n = o.count or 110
	return custom("leaves", o, function(ctx, L)
		local s = { parts = {}, list = {} }
		local names = { "body", "deep", "accent", "body", "core" }
		for i = 1, n do
			local c = col(ctx, names[(i % #names) + 1])
			local w = Instance.new("WedgePart")
			w.Anchored, w.CanCollide, w.CanQuery, w.CanTouch, w.CastShadow = true, false, false, false, false
			w.Material = if i % 5 == 0 then Enum.Material.Neon else Enum.Material.SmoothPlastic
			w.Color = c
			w.Size = Vector3.new(0.04, 0.55, 0.38) * ctx.random:NextNumber(0.7, 1.3)
			w.Parent = ctx.folder
			table.insert(s.parts, w)
			local th, ph = ctx.random:NextNumber(0, math.pi * 2), math.acos(ctx.random:NextNumber(0.05, 1))
			table.insert(s.list, { p = w, size = w.Size, th = th, ph = ph, roll = ctx.random:NextNumber(0, 6.28), sway = ctx.random:NextNumber(0, 6) })
		end
		return s
	end, function(ctx, L, s, lt)
		local k = envelope(lt, L.life, 0.5, 0.5)
		local cf = base(ctx, L)
		local R, H = (o.radius or 4) * ctx.scale, (o.height or 2.2) * ctx.scale
		for _, f in s.list do
			local dir = Vector3.new(math.sin(f.ph) * math.cos(f.th), math.cos(f.ph), math.sin(f.ph) * math.sin(f.th))
			local pos = Vector3.new(dir.X * R, dir.Y * H, dir.Z * R) * (0.85 + 0.15 * k)
			local sway = math.sin(lt * 1.7 + f.sway) * 0.25
			f.p.Size = f.size * ctx.scale * k
			f.p.CFrame = cf * CFrame.new(pos) * CFrame.lookAt(Vector3.zero, dir) * CFrame.Angles(math.rad(90) + sway, f.roll, 0)
		end
	end)
end

-- Rocks levitating and orbiting (faceted shards from the Crystal builder).
function Generator.rocks(o)
	o = o or {}
	local n = o.count or 10
	local L = custom("rocks", o, function(ctx, L)
		local s = { list = {}, crystals = {} }
		local P = { deep = col(ctx, "deep"), body = col(ctx, o.color or "smoke"):Lerp(Color3.new(1, 1, 1), 0.35), tip = col(ctx, "core") }
		for i = 1, n do
			local c = ctx.Crystal.new("shard", { seed = i, palette = P, parent = ctx.folder, simple = true })
			table.insert(s.crystals, c)
			table.insert(s.list, { c = c, a = ctx.random:NextNumber(0, 6.28), r = ctx.random:NextNumber(0.6, 1) * (o.radius or 8),
				y = ctx.random:NextNumber(-1, 2.5), sz = ctx.random:NextNumber(0.35, 0.9) * (o.size or 1), spin = ctx.random:NextNumber(-1.5, 1.5),
				speed = ctx.random:NextNumber(0.25, 0.55), ph = ctx.random:NextNumber(0, 6) })
		end
		return s
	end, function(ctx, L, s, lt)
		local k = envelope(lt, L.life, 0.8, 0.5)
		local cf = base(ctx, L)
		for _, r in s.list do
			local a = r.a + lt * r.speed
			local pos = Vector3.new(math.cos(a) * r.r, r.y + math.sin(lt * 1.3 + r.ph) * 0.4 + (1 - k) * -2, math.sin(a) * r.r) * ctx.scale
			r.c:set(cf * CFrame.new(pos) * CFrame.Angles(lt * r.spin, lt * r.spin * 0.7, 0), Vector3.one * r.sz * ctx.scale * math.max(k, 0.01))
		end
	end)
	L.stop = function(ctx, LL, s)
		for _, c in s.crystals or {} do
			c:destroy()
		end
	end
	return L
end

-- Crystal shards bursting outward from a point (the Opus starburst), landing and fading.
function Generator.shardBurst(o)
	o = o or {}
	local n = o.count or 12
	local L = custom("shardBurst", o, function(ctx, L)
		local s = { list = {} }
		local P = { deep = col(ctx, "accent"), body = col(ctx, "core"), tip = col(ctx, "white") }
		for i = 1, n do
			local c = ctx.Crystal.new("spike", { seed = i + 30, palette = P, parent = ctx.folder, simple = true })
			local dir = Vector3.new(ctx.random:NextNumber(-1, 1), ctx.random:NextNumber(0.15, 1.2), ctx.random:NextNumber(-1, 1))
			table.insert(s.list, { c = c, dir = dir.Unit, len = ctx.random:NextNumber(0.6, 1) * (o.length or 5), w = ctx.random:NextNumber(0.3, 0.6) * (o.width or 1) })
		end
		return s
	end, function(ctx, L, s, lt)
		local cf = base(ctx, L)
		local g = backOut(lt / (o.grow or 0.12))
		local endK = smooth((L.life - lt) / 0.25)
		for _, e in s.list do
			local up = e.dir
			local right = up:Cross(Vector3.zAxis)
			if right.Magnitude < 0.1 then
				right = up:Cross(Vector3.xAxis)
			end
			right = right.Unit
			local start = cf.Position + up * (o.offset or 0.4) * ctx.scale
			e.c:set(CFrame.fromMatrix(start, right, up), Vector3.new(e.w * ctx.scale, math.max(0.02, e.len * ctx.scale * g * endK), e.w * ctx.scale))
			e.c:hot(1 - math.clamp(lt / 0.12, 0, 1))
			e.c:fade(1 - endK)
		end
	end)
	L.stop = function(ctx, LL, s)
		for _, e in s.list or {} do
			e.c:destroy()
		end
	end
	return L
end

-- Temporary cinematic bloom while the effect plays (removed at its end). Showcase VFX are graded like this.
function Generator.bloom(o)
	o = o or {}
	return {
		id = "bloom", kind = "custom", t = o.t or 0, life = o.life or 3, at = { 0, 0, 0 },
		start = function(ctx, L)
			local Lighting = game:GetService("Lighting")
			local b = Instance.new("BloomEffect")
			b.Name = "ClipForgeBloom"
			b.Intensity, b.Size, b.Threshold = 0, o.size or 28, o.threshold or 0.82
			b.Parent = Lighting
			return { bloom = b }
		end,
		update = function(ctx, L, s, lt)
			s.bloom.Intensity = (o.intensity or 1.1) * envelope(lt, L.life, 0.4, 0.5)
		end,
		stop = function(ctx, L, s)
			if s.bloom then
				s.bloom:Destroy()
			end
		end,
	}
end

-------------------------------------------------------------------------------------------- particle presets
local function nebula(o)
	o = o or {}
	local r = o.radius or 13
	local layers = {}
	for i, c in { o.c1 or "body", o.c2 or "accent", o.c3 or "deep" } do
		table.insert(layers, B.smoke({ id = "nebula" .. i, at = o.at, t = o.t, box = { r * 2, r * 1.3, r * 2 }, count = o.count or 9,
			color = c, le = if c == "deep" then 0.2 else 0.75, size = o.size or 11, speed = { 0.2, 0.8 }, spread = { 180, 180 },
			gravity = { 0, 0, 0 }, lifetime = { (o.life or 5) * 0.8, o.life or 5 },
			props = { Shape = "Sphere", ShapeStyle = "Volume", RotSpeed = { -8, 8 }, Drag = 0.5,
				Transparency = { { 0, 1 }, { 0.2, if c == "deep" then 0.55 else 0.72 }, { 0.8, if c == "deep" then 0.6 else 0.78 }, { 1, 1 } },
				Size = { { 0, (o.size or 11) * 0.8 }, { 1, o.size or 11 } } },
			emit = { { 0, o.count or 9, 0.4 } } }))
	end
	table.insert(layers, B.smoke({ id = "galaxyFog", at = o.at, t = o.t, tex = "FOG", box = { r, r * 0.6, r }, count = 4, color = o.c1 or "body",
		le = 1, size = (o.size or 11) * 1.2, lifetime = { (o.life or 5) * 0.8, o.life or 5 }, speed = { 0.1, 0.4 },
		props = { FlipbookLayout = "None", FlipbookMode = "Loop", Shape = "Sphere", RotSpeed = { -12, 12 }, Brightness = 1.5,
			Transparency = { { 0, 1 }, { 0.25, 0.55 }, { 0.75, 0.6 }, { 1, 1 } } },
		emit = { { 0, 4, 0.3 } } }))
	return layers
end

local function stars(o)
	o = o or {}
	local r = o.radius or 14
	return B.specks({ id = "stars", at = o.at, t = o.t, box = { r * 2, r * 1.2, r * 2 }, count = o.count or 60, tex = o.tex or "SPARK",
		color = o.color or "white", speed = { 0.1, 0.5 }, drag = 0, gravity = { 0, 0.1, 0 }, size = o.size or 0.22,
		lifetime = { (o.life or 5) * 0.5, o.life or 5 }, emit = { { 0, o.count or 60, (o.life or 5) * 0.4 } },
		props = { Shape = "Box", ShapeStyle = "Volume" } })
end

local function shafts(o)
	o = o or {}
	local layers = {}
	local n = o.count or 4
	for i = 1, n do
		local x = (i - (n + 1) / 2) * (o.spacing or 1.6)
		table.insert(layers, B.beam({ id = "shaft" .. i, t = (o.t or 0) + i * 0.05, life = o.life or 3,
			a = { x, (o.top or 40), 0 }, b = { x * 0.4, o.bottom or 2, 0 }, width = (o.width or 4.5) * (1 - math.abs(x) * 0.06),
			tex = "BEAMSMOKE", color = o.color or "core", taper = 0.5,
			props = { TextureMode = "Wrap", TextureSpeed = -0.6, TextureLength = 12, Brightness = 2.5,
				Transparency = { { 0, 0.95 }, { 0.55, 0.5 }, { 1, 0.7 } } },
			tracks = { Width = { { 0, 0.1 }, { 0.3, 1, "backOut" }, { (o.life or 3) - 0.4, 1 }, { o.life or 3, 0, "quadIn" } } } }))
	end
	return layers
end

local function chroma(o)
	o = o or {}
	return {
		B.star({ id = "chromaStar", t = o.t, at = o.at, tex = "CHROMASTAR", color = "keepWhite", size = o.size or 9, lifetime = 0.3, brightness = 3 }),
		B.bloom({ id = "rainbowHalo", t = o.t, at = o.at, color = "keepWhite", size = (o.size or 9) * 1.4, alpha = 0.35, lifetime = 0.45,
			props = { Texture = "RAINBOWHALO" } }),
		B.shockwave({ id = "rainbowRing", t = o.t, at = o.at, tex = "RAINBOWRING", color = "keepWhite", size = (o.size or 9) * 1.6, lifetime = 0.45 }),
	}
end

local function needles(o)
	o = o or {}
	return B.streaks({ id = "needles", t = o.t, at = o.at, tex = nil, count = o.count or 26, speed = o.speed or { 80, 160 },
		size = o.size or 2.6, lifetime = { 0.12, 0.22 }, color = o.color or "white",
		props = { Texture = "NEEDLE", Squash = { { 0, 3 }, { 1, 1 } }, Rotation = 0 } })
end

------------------------------------------------------------------------------------------------- compositions
local function showcase(d)
	local H = d.height or 4.5
	local hero = { 0, H, 0 }
	local life = d.length or 6
	local L = {}
	local function add(x)
		table.insert(L, x)
	end
	-- birth: flash + rays + chromatic pop + shell
	add(B.flash({ at = hero, size = 6 }))
	add(B.rays({ at = hero, size = 13, lifetime = 0.8 }))
	add(B.shockwave({ at = hero, size = 10, tex = "THINRING" }))
	if d.chromatic then
		add(chroma({ at = hero, size = 7 }))
	end
	-- hero
	local h = d.hero or "cube"
	if h == "cube" or h == "glasscube" then
		add(Generator.cube({ at = hero, size = d.heroSize or 3, life = life, glass = true }))
	elseif h == "wirecube" then
		add(Generator.cube({ at = hero, size = d.heroSize or 3.2, life = life, glass = false, edge = 0.07 }))
	elseif h == "crystal" then
		add(B.spikes({ at = { 0, H - 2, 0 }, count = 5, radius = 0.6, height = 4, lean = 12, life = life, hot = false, deepColor = "deep", bodyColor = "body", tipColor = "white" }))
	elseif h == "orb" or h == "sphere" then
		add(B.sphere({ at = hero, size = 2.4, life = life, material = "Neon", color = "core",
			scale = { { 0, 0.1 }, { 0.08, 1, "backOut" }, { 0.92, 1 }, { 1, 0, "backIn" } }, fade = { { 0, 0 }, { 1, 0 } } }))
		add(B.sphere({ id = "orbShell", at = hero, size = 3.6, life = life,
			scale = { { 0, 0.1 }, { 0.1, 1, "backOut" }, { 0.92, 1.05 }, { 1, 0, "backIn" } }, fade = { { 0, 0.2 }, { 1, 0.4 } } }))
	end
	add(B.bloom({ at = hero, size = 7, alpha = 0.55, lifetime = life, color = "body" }))
	-- frames
	for _, f in d.frames or {} do
		if f == "rings" then
			add(Generator.ring({ at = hero, r0 = 0.5, r1 = 7, grow = 0.6, tilt = { 72, 0, 18 }, spin = 25, comet = true, life = life, thick = 0.08 }))
			add(Generator.ring({ at = hero, r0 = 0.5, r1 = 5.2, grow = 0.7, tilt = { -20, 0, 64 }, spin = -35, comet = true, cometSpeed = -2.8, life = life, thick = 0.07, t = 0.08 }))
			add(Generator.ring({ at = hero, r0 = 0.5, r1 = 9, grow = 0.8, tilt = { 8, 0, -6 }, spin = 15, comet = true, cometSpeed = 1.4, life = life, thick = 0.06, t = 0.15 }))
		elseif f == "wings" then
			add(Generator.wings({ at = { 0, H + 0.6, 0.3 }, span = 9, life = life, color = "body" }))
			for _, side in { -1, 1 } do
				add(B.smoke({ id = "wingVeil" .. side, at = { side * 5.2, H + 2.2, 0.3 }, box = { 7, 3.5, 1 }, count = 14, size = 3.2, color = "body",
					le = 1, brightness = 1.2, speed = { 0.1, 0.4 }, spread = { 180, 180 }, gravity = { 0, 0.2, 0 }, lifetime = { 1.8, 2.6 },
					emit = { { 0.2, 14, life - 1.4 } }, props = { Texture = "SOFTDOT", FlipbookLayout = "None", Shape = "Box",
						Transparency = { { 0, 1 }, { 0.3, 0.8 }, { 0.7, 0.84 }, { 1, 1 } } } }))
				add(B.specks({ id = "wingSparks" .. side, at = { side * 5.2, H + 2.2, 0.3 }, box = { 8, 4, 1 }, count = 34, size = 0.26, tex = "SPARKLE",
					emit = { { 0.3, 34, life - 1.2 } }, gravity = { 0, 0.4, 0 }, speed = { 0.3, 1.2 }, props = { Shape = "Box" } }))
			end
		elseif f == "heart" then
			add(Generator.heart({ at = { 0, H + 1.6, 0 }, size = 0.42, life = life }))
		elseif f == "halo" then
			for i = 0, 2 do
				add(Generator.ring({ at = { 0, H + 2.2 + i * 1.3, 0 }, r0 = 0.3, r1 = 2.6 - i * 0.5, grow = 0.5, t = 0.1 * i, spin = 40, life = life, thick = 0.08 }))
			end
		elseif f == "circle" then
			add(B.decalDisc({ size = 14, life = life, spin = { 0, 20, 0 }, color = "body" }))
			add(B.decalDisc({ id = "circle2", size = 9, life = life, spin = { 0, -35, 0 }, color = "accent", t = 0.1 }))
		end
	end
	-- energy
	for _, e in d.energy or {} do
		if e == "shafts" then
			for _, x in shafts({ life = life, top = 46, bottom = H, color = "core" }) do
				add(x)
			end
		elseif e == "rays" then
			add(B.rays({ id = "holdRays", t = 0.2, at = hero, size = 11, count = 10, lifetime = { life - 0.6, life - 0.4 },
				props = { RotSpeed = { -6, 6 }, Transparency = { { 0, 1 }, { 0.1, 0.55 }, { 0.85, 0.6 }, { 1, 1 } } } }))
		elseif e == "lightning" then
			add(Generator.arcs({ at = hero, radius = 5, count = 3, life = life - 0.4, t = 0.3, every = 0.09 }))
		elseif e == "swirl" then
			add(B.swirl({ at = { 0, 0.15, 0 }, size = 10, emit = { { 0, 1 }, { life * 0.33, 1 }, { life * 0.66, 1 } }, lifetime = life * 0.4 }))
		end
	end
	-- atmosphere
	for _, a in d.atmos or {} do
		if a == "nebula" then
			for _, x in nebula({ at = hero, life = life, radius = 12 }) do
				add(x)
			end
		elseif a == "stars" then
			add(stars({ at = hero, life = life }))
		elseif a == "flakes" then
			add(Generator.flakes({ at = hero, life = life, radius = 11, height = 6 }))
		elseif a == "petals" then
			add(Generator.flakes({ at = hero, life = life, radius = 10, height = 6, petals = true, matte = true, fall = 0.25, colors = { "white", "core", "accent" } }))
		elseif a == "leaves" then
			add(Generator.leaves({ at = { 0, 0, 0 }, life = life, radius = 4.2, height = 2.4 }))
			add(B.smoke({ id = "leafShadow", at = { 0, 0.5, 0 }, count = 6, size = 5, color = "ink", le = 0, speed = { 0.5, 1.5 },
				lifetime = { 2, 3 }, emit = { { 0, 6, life * 0.6 } } }))
			add(B.rise({ count = 30, over = life * 0.8, radius = 4, color = "accent", tex = "SPEC", lift = 1.5 }))
		elseif a == "smoke" then
			add(B.smoke({ id = "baseSmoke", at = { 0, 1, 0 }, count = 10, size = 7, color = "deep", le = 0.15, speed = { 1, 3 },
				lifetime = { 2.5, 3.5 }, emit = { { 0, 10, life * 0.7 } } }))
		elseif a == "embers" then
			add(B.embers({ at = { 0, 1, 0 }, count = 40, emit = { { 0.2, 40, life * 0.8 } } }))
		end
	end
	-- collapse
	add(B.flash({ id = "endFlash", t = life - 0.3, at = hero, size = 7 }))
	add(B.specks({ id = "endBurst", t = life - 0.3, at = hero, count = 30, speed = { 14, 28 } }))
	add(B.light({ at = hero, brightness = 4, range = 24, life = life,
		tracks = { Brightness = { { 0, 6 }, { 0.4, 3.5 }, { life - 0.35, 3.5 }, { life - 0.3, 8 }, { life, 0 } } } }))
	return L
end

local function impact(d)
	local L = {}
	local function add(x)
		table.insert(L, x)
	end
	local T = d.charge or 0.45
	local c = { 0, 3, 0 }
	-- charge: arcs converging on a growing orb
	add(Generator.arcs({ at = c, radius = 8, count = 4, converge = true, life = T, every = 0.05 }))
	add(B.sphere({ at = c, size = 2.2, life = T + 0.05, material = "Neon", color = "white",
		scale = { { 0, 0.05 }, { 0.9, 1, "quadIn" }, { 1, 0.2 } }, fade = { { 0, 0 }, { 1, 0 } } }))
	add(B.specks({ at = c, count = 30, emit = { { 0, 30, T } }, lifetime = { 0.3, 0.4 }, box = { 12, 12, 12 },
		props = { Shape = "Sphere", ShapeInOut = "Inward", ShapeStyle = "Surface", Speed = { 20, 30 }, Drag = 0, Acceleration = { 0, 0, 0 } } }))
	-- the hit
	add(B.inkFlash({ t = T, at = c, size = 14 }))
	add(B.flash({ t = T, at = c, size = 12, lifetime = 0.12 }))
	if d.chromatic ~= false then
		for _, x in chroma({ t = T, at = c, size = 11 }) do
			add(x)
		end
	end
	add(needles({ t = T, at = c, count = 30 }))
	add(Generator.shardBurst({ t = T, at = { 0, 0.5, 0 }, count = 14, length = 6, life = 0.9 }))
	for i = 0, 2 do
		add(Generator.ring({ t = T + i * 0.05, at = { 0, 2.5 + i * 3.5, 0 }, r0 = 0.5, r1 = 7 + i * 3, grow = 0.35, thin = true, thick = 0.16, life = 0.9 + i * 0.1, fadeOut = 0.35 }))
	end
	add(Generator.ring({ t = T, at = { 0, 0.15, 0 }, r0 = 1, r1 = 18, grow = 0.45, thin = true, thick = 0.22, life = 0.75 }))
	add(B.ring({ t = T, size = 20, color = "core" }))
	for _, x in shafts({ t = T, life = 0.8, top = 50, bottom = 0, count = 5, spacing = 1.4, width = 2.6, color = "white" }) do
		add(x)
	end
	add(B.grade({ t = T, brightness = 0.2, contrast = 0.35, saturation = -0.3 }))
	add(B.light({ t = T, at = c, brightness = 10, range = 34, life = 0.6 }))
	-- aftermath
	add(B.smoke({ t = T + 0.05, at = { 0, 1.5, 0 }, tex = "BILLOW", count = 14, size = 9, color = "smoke", le = 0.25, speed = { 14, 26 },
		spread = { 70, 70 }, lifetime = { 1.6, 2.4 }, drag = 4 }))
	add(B.smoke({ id = "crescents", t = T + 0.05, at = { 0, 2, 0 }, tex = "CRESCENT", count = 8, size = 6, color = "core", le = 0.6,
		speed = { 16, 26 }, spread = { 80, 80 }, lifetime = { 0.5, 0.7 }, props = { Orientation = "VelocityPerpendicular", RotSpeed = { -200, 200 } } }))
	add(B.debris({ t = T, count = 18, speed = { 30, 55 } }))
	add(B.specks({ t = T + 0.05, at = c, count = 24, speed = { 20, 40 }, tex = "SHORTCROSS" }))
	add(B.decalDisc({ t = T, tex = "CRACKSTAR", size = 18, color = "ink", life = 2.4, fade = { { 0, 0.1 }, { 0.7, 0.25 }, { 1, 1 } } }))
	return L
end

local function vortex(d)
	local L = {}
	local function add(x)
		table.insert(L, x)
	end
	local life = d.length or 6
	local H = d.height or 5
	local c = { 0, H, 0 }
	add(B.sphere({ at = c, size = 4.6, life = life, material = "Neon", color = "ink",
		scale = { { 0, 0.05 }, { 0.08, 1, "backOut" }, { 0.93, 1.05 }, { 1, 0, "backIn" } }, fade = { { 0, 0 }, { 1, 0 } } }))
	add(Generator.ring({ at = c, r0 = 0.5, r1 = 2.55, grow = 0.4, faceCamera = true, life = life, thick = 0.07, segments = 48 }))
	add(Generator.ring({ id = "disc", at = c, r0 = 0.5, r1 = 4.2, grow = 0.6, tilt = { 8, 0, -4 }, life = life, thick = 0.05, color = "core" }))
	add(B.windRing({ at = c, size = 6.5, le = 1, brightness = 2, color = "body", rot = { 8, 0, -4 }, rotSpeed = { 300, 420 },
		emit = (function()
			local e = {}
			for t = 0, life - 0.6, 0.18 do
				table.insert(e, { t, 1 })
			end
			return e
		end)(), lifetime = 0.5 }))
	add(B.swirl({ id = "disc2", at = c, size = 10, le = 1, brightness = 2.4, color = "core", rot = { 8, 0, -4 }, rotSpeed = { 220, 300 },
		emit = (function()
			local e = {}
			for t = 0, life - 0.8, 0.3 do
				table.insert(e, { t, 1 })
			end
			return e
		end)(), lifetime = 0.8 }))
	add(Generator.ring({ id = "discInner", at = c, r0 = 0.5, r1 = 3.2, grow = 0.5, tilt = { 8, 0, -4 }, life = life, thick = 0.14, color = "body" }))
	add(B.swirl({ at = c, size = 11, orientation = "FacingCamera", le = 1, brightness = 2.4, color = "body", rotSpeed = { 160, 240 },
		emit = (function()
			local e = {}
			for t = 0, life - 0.8, 0.35 do
				table.insert(e, { t, 1 })
			end
			return e
		end)(), lifetime = 0.9 }))
	add(B.swirl({ id = "groundVortex", at = { 0, 0.15, 0 }, size = 11, le = 0.9, color = "body", rotSpeed = { 140, 200 },
		emit = { { 0, 1 }, { life * 0.3, 1 }, { life * 0.6, 1 } }, lifetime = life * 0.42 }))
	add(B.ring({ size = 12, color = "core", lifetime = 0.8 }))
	add(Generator.rocks({ at = { 0, H - 1.5, 0 }, count = 16, radius = 8.5, life = life, size = 1.2 }))
	add(B.specks({ at = c, count = 60, emit = { { 0, 60, life - 0.6 } }, lifetime = { 0.5, 0.8 }, box = { 20, 14, 20 },
		props = { Shape = "Sphere", ShapeInOut = "Inward", ShapeStyle = "Surface", Speed = { 12, 18 }, Drag = 0, Acceleration = { 0, 0, 0 } } }))
	add(B.sphere({ id = "dome", at = { 0, 0, 0 }, size = 22, life = life, color = "body",
		scale = { { 0, 0.3 }, { 0.15, 1, "backOut" }, { 0.9, 1.02 }, { 1, 1.2 } }, fade = { { 0, 0.4 }, { 0.15, 0.82 }, { 0.9, 0.85 }, { 1, 1 } } }))
	add(B.smoke({ at = { 0, 0.5, 0 }, count = 10, size = 6, color = "deep", le = 0.2, speed = { 1, 3 }, lifetime = { 2.5, 3.5 },
		emit = { { 0, 10, life * 0.7 } } }))
	if d.chromatic then
		for _, x in chroma({ t = life - 0.25, at = c, size = 10 }) do
			add(x)
		end
	end
	add(B.flash({ t = life - 0.25, at = c, size = 10 }))
	add(B.shockwave({ t = life - 0.25, at = c, size = 16 }))
	add(B.light({ at = c, brightness = 4, range = 26, life = life, tracks = { Brightness = { { 0, 0 }, { 0.5, 4 }, { life - 0.3, 4 }, { life - 0.25, 10 }, { life, 0 } } } }))
	return L
end

----------------------------------------------------------------------------------------------------- public
-- desc: { mode, hero, frames = {}, energy = {}, atmos = {}, palette (table or name), chromatic, length, height, heroSize }
function Generator.build(desc)
	desc = desc or {}
	local mode = desc.mode or "showcase"
	local layers = if mode == "impact" then impact(desc) elseif mode == "vortex" then vortex(desc) else showcase(desc)
	local palette = desc.palette
	if type(palette) == "string" then
		palette = Generator.PALETTES[palette]
	end
	palette = palette or Generator.PALETTES[if mode == "impact" then "mono" elseif mode == "vortex" then "abyss" else "golden"]
	local full = {}
	for k, v in Generator.PALETTES.mono do
		full[k] = v
	end
	for k, v in palette do
		full[k] = v
	end
	if desc.bloom ~= false and mode ~= "impact" then
		table.insert(layers, Generator.bloom({ life = desc.length or 6 }))
	end
	local spec = B.spec({ name = desc.name or "Generated", palette = full, layers = layers })
	spec.scale = desc.scale or (if mode == "showcase" then 1.5 elseif mode == "vortex" then 1.4 else 1)
	return spec
end

local THEMES = {
	{ words = { "gold", "golden", "holy", "divine", "angel", "heaven", "sun" }, palette = "golden" },
	{ words = { "galaxy", "cosmic", "space", "nebula", "star", "astral", "celestial", "purple", "violet" }, palette = "galaxy" },
	{ words = { "green", "emerald", "nature", "forest", "leaf", "leaves", "jade", "toxic" }, palette = "emerald" },
	{ words = { "blue", "ocean", "abyss", "water", "ice", "frost", "cyan" }, palette = "abyss" },
	{ words = { "red", "crimson", "blood", "fire", "hell", "demon" }, palette = "crimson" },
	{ words = { "white", "mono", "monochrome", "opus", "silver", "chromatic", "prism" }, palette = "mono" },
}

local function has(text, w)
	return string.find(text, "%f[%a]" .. w .. "%f[%A]") ~= nil
end

-- "golden glowing cube with light wings", "galaxy wireframe cube with orbit rings and nebula",
-- "blue black hole with floating rocks", "white chromatic impact", "green cube on a leaf bush"
function Generator.fromPrompt(prompt: string, seed: number?)
	local text = " " .. string.lower(prompt or "") .. " "
	local d = { frames = {}, energy = {}, atmos = {}, seed = seed or 1, prompt = prompt }
	if has(text, "black hole") or has(text, "blackhole") or has(text, "singularity") or has(text, "vortex") or has(text, "void") then
		d.mode = "vortex"
	elseif has(text, "impact") or has(text, "slam") or has(text, "attack") or has(text, "explosion") or has(text, "strike")
		or has(text, "punch") or has(text, "ultimate") or has(text, "burst") or has(text, "smash") then
		d.mode = "impact"
	else
		d.mode = "showcase"
	end
	d.hero = if has(text, "wireframe") or has(text, "wire") or has(text, "outline") then "wirecube"
		elseif has(text, "cube") or has(text, "box") or has(text, "tesseract") or has(text, "artifact") then "cube"
		elseif has(text, "crystal") or has(text, "gem") then "crystal"
		elseif has(text, "orb") or has(text, "sphere") or has(text, "core") or has(text, "sun") then "orb"
		else "cube"
	local function want(list, key, words)
		for _, w in words do
			if has(text, w) then
				table.insert(list, key)
				return
			end
		end
	end
	want(d.frames, "rings", { "ring", "rings", "orbit", "orbits", "planet", "atom" })
	want(d.frames, "wings", { "wing", "wings", "angel", "phoenix", "feather", "feathers" })
	want(d.frames, "heart", { "heart", "love" })
	want(d.frames, "halo", { "halo", "halos", "crown" })
	want(d.frames, "circle", { "circle", "rune", "runes", "sigil", "summon" })
	want(d.energy, "shafts", { "shaft", "shafts", "beam", "beams", "god rays", "pillar", "heaven", "holy" })
	want(d.energy, "rays", { "ray", "rays", "radiant", "shine", "sun" })
	want(d.energy, "lightning", { "lightning", "electric", "thunder", "arc", "arcs", "spark", "sparks" })
	want(d.energy, "swirl", { "swirl", "vortex", "spin", "whirl" })
	want(d.atmos, "nebula", { "nebula", "galaxy", "cosmic", "space", "cloud", "clouds", "astral" })
	want(d.atmos, "stars", { "star", "stars", "galaxy", "space", "cosmic", "sparkle", "sparkles", "twinkle" })
	want(d.atmos, "flakes", { "flake", "flakes", "square", "squares", "confetti", "shards", "particles" })
	want(d.atmos, "petals", { "petal", "petals", "sakura", "blossom", "flower", "flowers" })
	want(d.atmos, "leaves", { "leaf", "leaves", "bush", "forest", "nature", "grass" })
	want(d.atmos, "smoke", { "smoke", "dark", "shadow", "fog", "mist" })
	want(d.atmos, "embers", { "ember", "embers", "fire", "ash" })
	-- a showcase with nothing asked still gets a full composition
	if d.mode == "showcase" then
		if #d.frames == 0 then
			table.insert(d.frames, "rings")
		end
		if #d.atmos == 0 then
			table.insert(d.atmos, "stars")
			table.insert(d.atmos, "flakes")
		end
		if #d.energy == 0 then
			table.insert(d.energy, "rays")
		end
	end
	for _, theme in THEMES do
		for _, w in theme.words do
			if has(text, w) then
				d.palette = theme.palette
				break
			end
		end
		if d.palette then
			break
		end
	end
	d.chromatic = has(text, "chromatic") or has(text, "rainbow") or has(text, "prism") or has(text, "opus")
		or d.palette == "mono" or (d.mode == "impact" and not d.palette)
	if has(text, "big") or has(text, "huge") or has(text, "giant") then
		d.scale = if d.mode == "impact" then 1.5 else 2
	elseif has(text, "small") or has(text, "tiny") then
		d.scale = 0.8
	end
	if has(text, "long") or has(text, "idle") or has(text, "showcase") then
		d.length = 8
	end
	local words = {}
	for w in string.gmatch(prompt or "", "%a+") do
		if #words < 4 and #w > 2 then
			table.insert(words, string.upper(string.sub(w, 1, 1)) .. string.lower(string.sub(w, 2)))
		end
	end
	d.name = if #words > 0 then table.concat(words) else "Generated"
	return d
end

return Generator
