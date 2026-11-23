-- ClipForge FX: plays ClipForge effects in your game (and in Studio for previews).
--
--   local FX = require(game.ReplicatedStorage.ClipForge.FX)
--   FX.play("PurpleSlash", character.HumanoidRootPart.CFrame * CFrame.new(0, 0, -4))
--   FX.play("groundpound", somePart)                    -- any Library effect id works too (see FX.list())
--   FX.play("PurpleSlash", cf, { scale = 1.5, speed = 0.8, shake = false })
--   local h = FX.play("rain", workspace.Map.Center)       -- ambient effects run until h.stop()
--   FX.preload("PurpleSlash")                            -- once at load: the first play otherwise misses textures
--   FX.shake(0.6, 0.4)                                    -- camera shake (amplitude, seconds)
--
-- An effect is a small ModuleScript in ReplicatedStorage.ClipForge.Effects that returns a config:
--   { base = "slash", palette = { core, primary, secondary, deep }, scale, speed, intensity, roll, yaw, shake,
--     parts = { { base = "slash", t = 0 }, { base = "impact", t = 0.25, at = {0, 0, -6}, scale = 0.85 } } }
-- Bots and the ClipForge plugin write these; you can edit the numbers by hand.
-- Play effects on the CLIENT (fire a RemoteEvent "play X at Y" from the server): particles are visual only.

local RunService = game:GetService("RunService")

local root = script.Parent
local VFXTimeline = require(root:WaitForChild("VFXTimeline"))
local Recolor = require(root:WaitForChild("Recolor"))
local Library = require(root:WaitForChild("Library"))
local HttpService = game:GetService("HttpService")
local Generator = nil -- loaded on first generated effect
local function gen()
	Generator = Generator or require(root:WaitForChild("Generator"))
	return Generator
end

local FX = {}
FX.VFXTimeline = VFXTimeline
FX.Recolor = Recolor
FX.Library = Library

FX.Bases = {}
FX.BaseInfo = {}
for _, e in Library.list do
	FX.BaseInfo[e.id] = e
	if not e.hidden then
		table.insert(FX.Bases, e.id)
	end
end

-- which way an effect may be turned: slashes roll (diagonal swipes)
local ROLLS = { slash = true }
-- half-width of a slash's crescent cards at scale 1 (recipe S = 10.5) and the height of its swing plane
local SLASH_HALF, SLASH_CHEST = 10.5, 2

local function deepCopy(v, seen)
	if type(v) ~= "table" then
		return v
	end
	seen = seen or {}
	if seen[v] then
		return seen[v]
	end
	local out = {}
	seen[v] = out
	for k, x in v do
		out[deepCopy(k, seen)] = deepCopy(x, seen)
	end
	return out
end
FX.deepCopy = deepCopy

function FX.list()
	return FX.Bases
end

local recipeCache = {}
-- The un-coloured spec of a base effect: a studied recipe module, or a Library effect built from Blocks.
-- A generated description (prompt or full desc) -> its cache key and the desc to build.
local function genDesc(g)
	local d = g
	if g.prompt and not g.mode then
		d = gen().fromPrompt(g.prompt, g.seed)
		for k, v in g do
			if k ~= "prompt" then
				d[k] = v
			end
		end
	end
	return "@gen:" .. HttpService:JSONEncode(d), d
end

function FX.recipe(base: string, generate)
	if generate then
		local key, d = genDesc(generate)
		local c = recipeCache[key]
		if c == nil then
			c = gen().build(d)
			recipeCache[key] = c
		end
		return c
	end
	local cached = recipeCache[base]
	if cached ~= nil then
		return cached
	end
	local entry = Library.byId[base]
	local folder = root:FindFirstChild("Recipes")
	if entry and entry.build then
		cached = entry.build()
	else
		local name = (entry and entry.recipe) or base
		local mod = folder and folder:FindFirstChild(name)
		if not mod then
			error("ClipForge: unknown base effect '" .. tostring(base) .. "'")
		end
		cached = require(mod)
	end
	recipeCache[base] = cached
	return cached
end

-- Builds the VFXTimeline spec for one part of an effect: the base, recoloured and with the intensity applied.
local specCache = {}
local function paletteKey(p)
	if not p then
		return "orig"
	end
	return table.concat({ p.core or "", p.primary or "", p.secondary or "", p.deep or "" }, "|")
end

function FX.buildSpec(base: string, palette, intensity: number?, name: string?, generate)
	local key = (if generate then genDesc(generate) else base) .. "#" .. paletteKey(palette) .. "#" .. tostring(intensity or 1)
	local spec = specCache[key]
	if spec then
		return spec
	end
	spec = deepCopy(FX.recipe(base, generate))
	if palette then
		Recolor.apply(spec, palette)
	end
	local k = intensity or 1
	if k ~= 1 then
		for _, L in spec.layers do
			if L.emit then
				for _, e in L.emit do
					if type(e[2]) == "number" and e[2] > 1 then
						e[2] = math.max(1, math.round(e[2] * k))
					end
				end
			end
		end
	end
	spec.name = (name or "ClipForge") .. "_" .. base
	specCache[key] = spec
	return spec
end

function FX.clearCache()
	table.clear(specCache)
	table.clear(recipeCache)
end

-- Accepts an effect name (module in ReplicatedStorage.ClipForge.Effects), a config table, or a Library id.
function FX.resolve(effect)
	if type(effect) == "table" then
		return effect
	end
	if typeof(effect) == "Instance" and effect:IsA("ModuleScript") then
		return require(effect)
	end
	local effects = root:FindFirstChild("Effects")
	local mod = effects and effects:FindFirstChild(effect)
	if mod then
		return require(mod)
	end
	local entry = Library.byId[effect]
	if entry then
		if entry.combo then
			return { name = entry.id, parts = entry.combo, shake = entry.shake }
		end
		return { name = entry.id, base = entry.id, shake = entry.shake, ambient = entry.ambient }
	end
	error("ClipForge: no effect named '" .. tostring(effect) .. "' (Effects folder or Library)")
end

function FX.isAmbient(effect): boolean
	local ok, cfg = pcall(FX.resolve, effect)
	if not ok then
		return false
	end
	if cfg.ambient then
		return true
	end
	for _, p in cfg.parts or {} do
		local e = Library.byId[p.base]
		if e and e.ambient then
			return true
		end
	end
	local e = Library.byId[cfg.base or ""]
	return e ~= nil and e.ambient == true
end

local function toCFrame(where): CFrame
	local t = typeof(where)
	if t == "CFrame" then
		return where
	elseif t == "Vector3" then
		return CFrame.new(where)
	elseif t == "Instance" then
		if where:IsA("Attachment") then
			return where.WorldCFrame
		elseif where:IsA("BasePart") then
			return where.CFrame
		elseif where:IsA("Model") then
			return where:GetPivot()
		end
	end
	error("ClipForge: play() needs a CFrame, Vector3, BasePart, Attachment or Model")
end

local function partsOf(cfg)
	if cfg.parts and #cfg.parts > 0 then
		return cfg.parts
	end
	if cfg.generate then
		return { { base = "@gen", t = 0, generate = cfg.generate } }
	end
	return { { base = cfg.base or "impact", t = 0 } }
end

-- A tilted slash must not slice into the floor (the floor cuts its cards into hard-edged wedges): lift it just
-- enough to clear the ground below the origin.
local function groundClearance(origin: CFrame, rollDeg: number, scale: number, ignore): number
	local reach = SLASH_HALF * scale * math.sin(math.rad(math.abs(rollDeg))) * 0.85
	local centre = SLASH_CHEST * scale
	if reach <= centre then
		return 0
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore or {}
	local hit = workspace:Raycast(origin.Position + Vector3.new(0, 0.5, 0), Vector3.new(0, -60, 0), params)
	local above = if hit then origin.Position.Y - hit.Position.Y else 60
	return math.max(0, reach - (above + centre) + 0.4)
end

------------------------------------------------------------------------------------------------------ camera shake
local shakes = {}
local shakeConn = nil
local editOffset = CFrame.identity
local BIND = "ClipForgeShake"

local function reducedMotion(): boolean
	local ok, on = pcall(function()
		return game:GetService("GuiService").ReducedMotionEnabled
	end)
	return ok and on == true
end

local function shakeOffset(): CFrame
	local now = os.clock()
	local x, y, rx, ry, rz = 0, 0, 0, 0, 0
	for i = #shakes, 1, -1 do
		local s = shakes[i]
		local k = (now - s.start) / s.dur
		if k >= 1 then
			table.remove(shakes, i)
		else
			-- trauma-style: strength falls off squared, and the camera mostly rotates (up to ~2.6 degrees at amp 1)
			-- rather than sliding, which reads as a jolt instead of jitter
			local a = s.amp * (1 - k) * (1 - k)
			local t = (now - s.start) * s.freq
			x += math.noise(t, s.seed, 0.5) * a * 0.35
			y += math.noise(s.seed, t, 0.5) * a * 0.35
			rx += math.noise(t, 0.5, s.seed) * a * 0.045
			ry += math.noise(0.5, t, s.seed) * a * 0.045
			rz += math.noise(t, t, s.seed) * a * 0.03
		end
	end
	return CFrame.new(x, y, 0) * CFrame.Angles(rx, ry, rz)
end
FX.shakeOffset = shakeOffset

local function stopShakeLoop()
	if shakeConn then
		shakeConn:Disconnect()
		shakeConn = nil
	end
	pcall(function()
		RunService:UnbindFromRenderStep(BIND)
	end)
	local cam = workspace.CurrentCamera
	if cam and editOffset ~= CFrame.identity then
		cam.CFrame = cam.CFrame * editOffset:Inverse()
	end
	editOffset = CFrame.identity
end

-- Camera shake: amp ~0.2 (tap) .. 1 (huge), dur in seconds. Stacks with other shakes; respects Reduced Motion.
function FX.shake(amp: number?, dur: number?, freq: number?)
	if reducedMotion() or not workspace.CurrentCamera then
		return
	end
	table.insert(shakes, { amp = amp or 0.5, dur = math.max(dur or 0.35, 0.05), freq = freq or 16,
		start = os.clock(), seed = math.random() * 100 })
	if RunService:IsRunning() then
		-- in a game: run right after the camera scripts, as an offset on top of whatever they set this frame
		if not FX._bound then
			FX._bound = true
			RunService:BindToRenderStep(BIND, Enum.RenderPriority.Camera.Value + 1, function()
				local cam = workspace.CurrentCamera
				if #shakes == 0 then
					FX._bound = false
					RunService:UnbindFromRenderStep(BIND)
					return
				end
				if cam and not FX._cutsceneOwnsShake then
					cam.CFrame = cam.CFrame * shakeOffset()
				end
			end)
		end
	elseif not shakeConn then
		-- in Studio edit mode the camera holds its CFrame, so undo last frame's offset before adding the new one
		shakeConn = RunService.Heartbeat:Connect(function()
			local cam = workspace.CurrentCamera
			if not cam then
				return
			end
			-- a cutscene preview composes the shake into its own camera; then only the shake list ages here
			local off = if #shakes > 0 and not FX._cutsceneOwnsShake then shakeOffset() else CFrame.identity
			if FX._cutsceneOwnsShake then
				shakeOffset()
			end
			cam.CFrame = cam.CFrame * editOffset:Inverse() * off
			editOffset = off
			if #shakes == 0 then
				editOffset = CFrame.identity
				stopShakeLoop()
			end
		end)
	end
end

-------------------------------------------------------------------------------------------------------------- play
-- Plays an effect. Returns a handle { stop(), setSpeed(s), time() } covering every part of a combined effect.
-- opts: scale, speed, seed, parent, important, noGrade, freezeAt, shake (false = no camera shake), ignore, clearGround
function FX.play(effect, where, opts)
	opts = opts or {}
	local cfg = FX.resolve(effect)
	local origin = toCFrame(where)
	local yaw = math.rad(cfg.yaw or 0)
	local scale = (cfg.scale or 1) * (opts.scale or 1)
	local speed = (cfg.speed or 1) * (opts.speed or 1)
	local handles, timers, stopped = {}, {}, false
	local startClock = os.clock()

	local function addShake(sh, t0, k)
		if not sh or opts.shake == false or opts.freezeAt then
			return
		end
		local delay = ((sh.t or 0) + (t0 or 0)) / math.max(speed, 0.01)
		local function go()
			if not stopped then
				FX.shake((sh.amp or 0.5) * math.clamp(k or 1, 0.3, 2), sh.dur or 0.35)
			end
		end
		if delay <= 0 then
			go()
		else
			table.insert(timers, task.delay(delay, go))
		end
	end
	addShake(cfg.shake, 0, scale)

	for i, part in partsOf(cfg) do
		local base = part.base or cfg.base
		local entry = Library.byId[base]
		if entry and entry.combo then
			-- a combo inside a config: play it as its own effect at this part's time and place
			local sub = { name = cfg.name, parts = entry.combo, palette = cfg.palette or part.palette, intensity = cfg.intensity,
				yaw = cfg.yaw, roll = part.roll or cfg.roll }
			local at = part.at or { 0, 0, 0 }
			local cf = origin * CFrame.Angles(0, yaw, 0) * CFrame.new(at[1] * scale, at[2] * scale, at[3] * scale)
			local delay = (part.t or 0) / math.max(speed, 0.01)
			local subOpts = deepCopy(opts)
			subOpts.scale = scale * (part.scale or 1)
			subOpts.speed = speed
			table.insert(timers, task.delay(delay, function()
				if not stopped then
					table.insert(handles, FX.play(sub, cf, subOpts))
				end
			end))
			continue
		end
		if entry and entry.shake and part.base ~= cfg.base then
			addShake(entry.shake, part.t, scale * (part.scale or 1))
		end
		local spec = FX.buildSpec(base, cfg.palette or part.palette, (cfg.intensity or 1) * (part.intensity or 1), cfg.name, part.generate)
		local at = part.at or { 0, 0, 0 }
		local cf = origin * CFrame.Angles(0, yaw, 0) * CFrame.new(at[1] * scale, at[2] * scale, at[3] * scale)
		if ROLLS[base] then
			local roll = part.roll or cfg.roll or 0
			if opts.clearGround ~= false then
				local lift = groundClearance(cf, roll, scale * (part.scale or 1), opts.ignore)
				if lift > 0 then
					cf = cf + Vector3.new(0, lift, 0)
				end
			end
			cf *= CFrame.Angles(0, 0, math.rad(roll))
		end
		local playOpts = {
			scale = scale * (part.scale or 1),
			speed = speed,
			seed = opts.seed and (opts.seed + i) or nil,
			parent = opts.parent,
			important = opts.important,
			noGrade = opts.noGrade or reducedMotion(),
			freezeAt = opts.freezeAt and math.max(0, opts.freezeAt - (part.t or 0)) or nil,
		}
		local delay = (part.t or 0) / math.max(speed, 0.01)
		if delay <= 0 then
			table.insert(handles, VFXTimeline.play(spec, cf, playOpts))
		else
			table.insert(timers, task.delay(delay, function()
				if not stopped then
					table.insert(handles, VFXTimeline.play(spec, cf, playOpts))
				end
			end))
		end
	end

	return {
		stop = function()
			stopped = true
			for _, th in timers do
				pcall(task.cancel, th)
			end
			for _, h in handles do
				h.stop()
			end
		end,
		setSpeed = function(s)
			for _, h in handles do
				if h.setSpeed then
					h.setSpeed(s)
				end
			end
		end,
		time = function()
			return os.clock() - startClock
		end,
	}
end

function FX.preload(effect)
	local cfg = FX.resolve(effect)
	for _, part in partsOf(cfg) do
		local base = part.base or cfg.base
		local entry = Library.byId[base]
		if entry and entry.combo then
			FX.preload(base)
		else
			VFXTimeline.preload(FX.buildSpec(base, cfg.palette or part.palette, (cfg.intensity or 1) * (part.intensity or 1), cfg.name, part.generate))
		end
	end
end

-- Seconds from start to the last visible moment (ambient effects report how long they run, capped at 10 for previews).
function FX.length(effect)
	local cfg = FX.resolve(effect)
	local speed = math.max(cfg.speed or 1, 0.01)
	local n = 0
	for _, part in partsOf(cfg) do
		local base = part.base or cfg.base
		local entry = Library.byId[base]
		local len
		if entry and entry.combo then
			len = FX.length(base)
		else
			len = VFXTimeline.length(FX.buildSpec(base, cfg.palette or part.palette, 1, cfg.name, part.generate))
		end
		n = math.max(n, (part.t or 0) + math.min(len, 600))
	end
	return n / speed
end

return FX
