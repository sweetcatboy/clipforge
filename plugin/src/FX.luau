-- ClipForge FX: plays ClipForge effects in your game (and in Studio for previews).
--
--   local FX = require(game.ReplicatedStorage.ClipForge.FX)
--   FX.play("PurpleSlash", character.HumanoidRootPart.CFrame * CFrame.new(0, 0, -4))
--   FX.play("PurpleSlash", somePart)                 -- a BasePart, Attachment, Model or Vector3 works too
--   FX.play("PurpleSlash", cf, { scale = 1.5, speed = 0.8 })
--   FX.preload("PurpleSlash")                         -- once at load: the first play otherwise misses textures
--
-- An effect is a small ModuleScript in ReplicatedStorage.ClipForge.Effects that returns a config:
--   { base = "slash", palette = { core, primary, secondary, deep }, scale, speed, intensity, roll, yaw,
--     parts = { { base = "slash", t = 0 }, { base = "impact", t = 0.25, at = {0, 0, -6}, scale = 0.85 } } }
-- Bots and the ClipForge plugin write these; you can edit the numbers by hand.
-- Play effects on the CLIENT (fire a RemoteEvent "play X at Y" from the server): particles are visual only.

local root = script.Parent
local VFXTimeline = require(root:WaitForChild("VFXTimeline"))
local Recolor = require(root:WaitForChild("Recolor"))

local FX = {}
FX.VFXTimeline = VFXTimeline
FX.Recolor = Recolor

FX.Bases = { "slash", "impact", "explosion", "aura", "beam", "lightning", "projectile", "fire", "icewater", "darkportal", "misc" }
FX.BaseInfo = {
	slash = { title = "Slash", blurb = "Crescent sword swipe with hot edge, ink twin and sparks" },
	impact = { title = "Ground Slam", blurb = "Spike flash, dome, racing rings, debris orbs, smoke, scorch" },
	explosion = { title = "Explosion", blurb = "Flash, fireball body, shock rings, smoke column, embers" },
	aura = { title = "Aura Charge", blurb = "Building aura, swirl pulling in, release burst, ground cloud" },
	beam = { title = "Beam", blurb = "Charge, hitscan beam with core line, impact, lingering smoke" },
	lightning = { title = "Lightning", blurb = "Ink frame, bolts with re-strikes, arcs, crack glints" },
	projectile = { title = "Projectile", blurb = "Launch flash, travelling orb with trail, contact burst" },
	fire = { title = "Fire Eruption", blurb = "Ignition flash, rising flames, cooling to smoke and embers" },
	icewater = { title = "Frost Burst", blurb = "Crisp flash, ice crown, whirl rings, frost on the ground" },
	darkportal = { title = "Void Breach", blurb = "Ink punch, dark body in waves, rings, void fog" },
	misc = { title = "Holy Burst", blurb = "Radiant flash, halo and rays, drifting motes" },
}
-- which way an effect may be turned: slashes roll (diagonal swipes), beams/projectiles aim (yaw)
local ROLLS = { slash = true }
-- half-width of a slash's crescent cards at scale 1 (recipe S = 10.5) and the height of its swing plane
local SLASH_HALF, SLASH_CHEST = 10.5, 2

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

local recipeCache = {}
function FX.recipe(base: string)
	local cached = recipeCache[base]
	if cached == nil then
		local folder = root:FindFirstChild("Recipes")
		local mod = folder and folder:FindFirstChild(base)
		if not mod then
			error("ClipForge: unknown base effect '" .. tostring(base) .. "'")
		end
		cached = require(mod)
		recipeCache[base] = cached
	end
	return cached
end

-- Builds the VFXTimeline spec for one part of an effect: the recipe, recoloured and with the intensity applied.
local specCache = {}
local function paletteKey(p)
	if not p then
		return "orig"
	end
	return table.concat({ p.core or "", p.primary or "", p.secondary or "", p.deep or "" }, "|")
end

function FX.buildSpec(base: string, palette, intensity: number?, name: string?)
	local key = base .. "#" .. paletteKey(palette) .. "#" .. tostring(intensity or 1)
	local spec = specCache[key]
	if spec then
		return spec
	end
	spec = deepCopy(FX.recipe(base))
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

-- Accepts an effect name (module in ReplicatedStorage.ClipForge.Effects), a config table, or a base recipe name.
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
	if FX.BaseInfo[effect] then
		return { base = effect, name = effect }
	end
	error("ClipForge: no effect named '" .. tostring(effect) .. "' in ReplicatedStorage.ClipForge.Effects")
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
	return { { base = cfg.base or "impact", t = 0 } }
end

-- Plays an effect. Returns a handle { stop(), setSpeed(s), time() } covering every part of a combined effect.
function FX.play(effect, where, opts)
	opts = opts or {}
	local cfg = FX.resolve(effect)
	local origin = toCFrame(where)
	local yaw = math.rad(cfg.yaw or 0)
	local scale = (cfg.scale or 1) * (opts.scale or 1)
	local speed = (cfg.speed or 1) * (opts.speed or 1)
	local handles, timers, stopped = {}, {}, false
	local startClock = os.clock()

	for i, part in partsOf(cfg) do
		local base = part.base or cfg.base
		local spec = FX.buildSpec(base, part.palette or cfg.palette, (cfg.intensity or 1) * (part.intensity or 1), cfg.name)
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
			noGrade = opts.noGrade,
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
		VFXTimeline.preload(FX.buildSpec(base, part.palette or cfg.palette, (cfg.intensity or 1) * (part.intensity or 1), cfg.name))
	end
end

-- Seconds from start to the last visible moment (for previews and cooldown timing).
function FX.length(effect)
	local cfg = FX.resolve(effect)
	local speed = math.max(cfg.speed or 1, 0.01)
	local n = 0
	for _, part in partsOf(cfg) do
		local spec = FX.buildSpec(part.base or cfg.base, part.palette or cfg.palette, 1, cfg.name)
		n = math.max(n, (part.t or 0) + VFXTimeline.length(spec))
	end
	return n / speed
end

return FX
