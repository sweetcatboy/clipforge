-- ClipForge Abilities: an animation and its effects in sync (hit markers), with hit-stop and camera shake.
--
--   local Abilities = require(game.ReplicatedStorage.ClipForge.Abilities)
--   Abilities.play("GroundSmash", player.Character)          -- from a LocalScript (effects are client-side)
--
-- Config (a ModuleScript in ReplicatedStorage.ClipForge.Abilities, or a table):
--   { name, animation = "rbxassetid://<published id>", speed = 1,
--     hits = { { at = 0.42, effect = "groundpound", attach = "Ground", offset = {0, 0, -3}, scale = 1, shake = { amp = 0.6, dur = 0.35 } },
--              { marker = "Hit", effect = "hitspark", attach = "RightHand" } } }
-- attach: "Root" (HumanoidRootPart), "RightHand", "LeftHand", "Ground" (below the root), "Front" (on the ground in front)
-- `at` is seconds into the animation; `marker` waits for a KeyframeMarker of that name instead.
-- Hit-stop: on a marker hit (the contact frame) the animation freezes for 0.03 + 0.045 x strength seconds, which is
-- what makes a hit feel heavy. strength = hit.strength, else the hit's shake amp, else 0.6. Set hitstop = false (on
-- the config or a hit) to turn it off, or a number of seconds to fix it; timed hits (`at`) get it with hitstop = true.

local root = script.Parent
local Abilities = {}

local function FX()
	return require(root:WaitForChild("FX"))
end

local function resolve(a)
	if type(a) == "table" then
		return a
	end
	if typeof(a) == "Instance" and a:IsA("ModuleScript") then
		return require(a)
	end
	local folder = root:FindFirstChild("Abilities")
	local mod = folder and folder:FindFirstChild(a)
	if not mod then
		error("ClipForge: no ability named " .. tostring(a))
	end
	return require(mod)
end

-- Where a hit's effect plays for a character.
function Abilities.origin(character: Model, attach: string?, offset)
	local hrp = character:FindFirstChild("HumanoidRootPart")
	local base = if hrp and hrp:IsA("BasePart") then hrp.CFrame else character:GetPivot()
	local flat = CFrame.new(base.Position) * CFrame.fromOrientation(0, select(2, base:ToOrientation()), 0)
	local off = if offset then Vector3.new(offset[1] or 0, offset[2] or 0, offset[3] or 0) else Vector3.zero
	local function ground(cf: CFrame)
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { character }
		local hit = workspace:Raycast(cf.Position + Vector3.new(0, 2, 0), Vector3.new(0, -50, 0), params)
		return if hit then CFrame.new(hit.Position) * cf.Rotation else cf * CFrame.new(0, -3, 0)
	end
	if attach == "RightHand" or attach == "LeftHand" then
		local hand = character:FindFirstChild(attach) or character:FindFirstChild(if attach == "RightHand" then "Right Arm" else "Left Arm")
		if hand then
			return CFrame.new(hand.Position) * flat.Rotation * CFrame.new(off)
		end
	elseif attach == "Ground" then
		return ground(flat) * CFrame.new(off)
	elseif attach == "Front" then
		return ground(flat * CFrame.new(0, 0, -4)) * CFrame.new(off)
	end
	return flat * CFrame.new(off)
end

-- Plays the ability. opts: animationId (overrides config), speed, track (an already-loaded AnimationTrack),
-- noAnimation (effects only), noHitStop, onHit(hit). Returns { track, stop() }.
function Abilities.play(ability, character: Model, opts)
	opts = opts or {}
	local cfg = resolve(ability)
	local fx = FX()
	local speed = (cfg.speed or 1) * (opts.speed or 1)
	local track = opts.track
	if not track and not opts.noAnimation then
		local id = opts.animationId or cfg.animation
		local hum = character:FindFirstChildOfClass("Humanoid") or character:FindFirstChildOfClass("AnimationController")
		if id and hum and id ~= "" and id ~= "rbxassetid://0" then
			local animator = hum:FindFirstChildOfClass("Animator")
			if not animator then
				animator = Instance.new("Animator")
				animator.Parent = hum
			end
			local anim = Instance.new("Animation")
			anim.AnimationId = id
			local ok, t = pcall(animator.LoadAnimation, animator, anim)
			if ok then
				track = t
				track.Priority = Enum.AnimationPriority.Action
				track:Play(0.1, 1, speed)
			else
				warn("[ClipForge] ability animation failed to load: " .. tostring(t))
			end
		end
	end
	local handles, conns, timers = {}, {}, {}
	local function hitStop(hit, fromMarker: boolean)
		local want = if hit.hitstop ~= nil then hit.hitstop elseif cfg.hitstop ~= nil then cfg.hitstop else fromMarker
		if not track or not want or opts.noHitStop then
			return
		end
		local strength = hit.strength or (hit.shake and hit.shake.amp) or cfg.strength or 0.6
		local dur = if type(want) == "number" then want else 0.03 + 0.045 * math.clamp(strength, 0, 2)
		if dur <= 0 or not track.IsPlaying then
			return
		end
		track:AdjustSpeed(0)
		table.insert(timers, task.delay(dur, function()
			if track.IsPlaying and track.Speed == 0 then
				track:AdjustSpeed(speed)
			end
		end))
	end
	local function fire(hit, fromMarker: boolean?)
		hitStop(hit, fromMarker == true)
		if opts.onHit then
			pcall(opts.onHit, hit)
		end
		if hit.effect then
			local ok, h = pcall(fx.play, hit.effect, Abilities.origin(character, hit.attach, hit.offset),
				{ scale = hit.scale, shake = hit.shake == nil and nil or false, parent = opts.parent, important = opts.important })
			if ok then
				table.insert(handles, h)
			else
				warn("[ClipForge] ability effect: " .. tostring(h))
			end
		end
		if hit.shake then
			fx.shake(hit.shake.amp or 0.5, hit.shake.dur or 0.35)
		end
	end
	for _, hit in cfg.hits or {} do
		if hit.marker and track then
			table.insert(conns, track:GetMarkerReachedSignal(hit.marker):Connect(function()
				fire(hit, true)
			end))
		else
			table.insert(timers, task.delay((hit.at or 0) / math.max(speed, 0.01), fire, hit))
		end
	end
	return {
		track = track,
		stop = function()
			for _, c in conns do
				c:Disconnect()
			end
			for _, t in timers do
				pcall(task.cancel, t)
			end
			for _, h in handles do
				pcall(h.stop)
			end
			if track then
				pcall(function()
					track:Stop(0.15)
				end)
			end
		end,
	}
end

return Abilities
