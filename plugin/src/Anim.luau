-- ClipForge Anim: turns ClipForge motion data (part orientations in character space + root motion, from the bot
-- server) into a KeyframeSequence for the actual rig: R15 or R6, any proportions, any C0/C1. Feet are kept on the
-- ground by forward kinematics on the real rig, so crouches and stances land correctly whatever the body shape.

local RunService = game:GetService("RunService")
local AnimationClipProvider = game:GetService("AnimationClipProvider")

local Anim = {}

local R15_FEET = { "LeftFoot", "RightFoot" }
local R6_FEET = { "Left Leg", "Right Leg" }
local R6_TRACK = { Torso = "Torso", Head = "Head", ["Left Arm"] = "LeftArm", ["Right Arm"] = "RightArm",
	["Left Leg"] = "LeftLeg", ["Right Leg"] = "RightLeg" }

local function rotOnly(cf: CFrame): CFrame
	return cf - cf.Position
end

-- Everything we need to know about a rig, measured from its joints in the rest pose (all Transforms = identity).
function Anim.rigInfo(model: Model)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local hrp = model:FindFirstChild("HumanoidRootPart")
	if not (humanoid and hrp and hrp:IsA("BasePart")) then
		return nil, "Pick a character model with a Humanoid and a HumanoidRootPart"
	end
	local rigType = if model:FindFirstChild("UpperTorso") then "R15" elseif model:FindFirstChild("Torso") then "R6" else nil
	if not rigType then
		return nil, "Only R15 and R6 rigs are supported"
	end
	-- joints: classic Motor6Ds, or the AnimationConstraints that newer avatars use (same maths: C0/C1 come from
	-- the two attachments). Poses are matched by part name either way.
	local byParent = {}
	local function add(inst, p0, p1, c0, c1)
		if p0 and p1 and p0:IsA("BasePart") and p1:IsA("BasePart") and p1:IsDescendantOf(model) then
			byParent[p0] = byParent[p0] or {}
			table.insert(byParent[p0], { inst = inst, Part0 = p0, Part1 = p1, C0 = c0, C1 = c1 })
		end
	end
	for _, d in model:GetDescendants() do
		if d:IsA("Motor6D") then
			add(d, d.Part0, d.Part1, d.C0, d.C1)
		elseif d:IsA("AnimationConstraint") and d.Attachment0 and d.Attachment1 then
			add(d, d.Attachment0.Parent, d.Attachment1.Parent, d.Attachment0.CFrame, d.Attachment1.CFrame)
		end
	end
	-- parent-before-child order from the root part, with rest CFrames in HumanoidRootPart space
	local order, restCF, seen = {}, { [hrp.Name] = CFrame.identity }, { [hrp] = true }
	local queue = { hrp }
	while #queue > 0 do
		local p = table.remove(queue, 1)
		for _, m in byParent[p] or {} do
			if not seen[m.Part1] then
				seen[m.Part1] = true
				restCF[m.Part1.Name] = restCF[p.Name] * m.C0 * m.C1:Inverse()
				table.insert(order, m)
				table.insert(queue, m.Part1)
			end
		end
	end
	if #order == 0 then
		return nil, "The rig has no Motor6D or AnimationConstraint joints"
	end
	local feetNames = if rigType == "R15" then R15_FEET else R6_FEET
	local function bottom(name, cf)
		local part = model:FindFirstChild(name)
		if not (part and part:IsA("BasePart")) then
			return math.huge
		end
		local s = part.Size / 2
		local low = math.huge
		for _, x in { -s.X, s.X } do
			for _, y in { -s.Y, s.Y } do
				for _, z in { -s.Z, s.Z } do
					low = math.min(low, (cf * Vector3.new(x, y, z)).Y)
				end
			end
		end
		return low
	end
	local restFoot = math.huge
	for _, f in feetNames do
		if restCF[f] then
			restFoot = math.min(restFoot, bottom(f, restCF[f]))
		end
	end
	-- standing pelvis height: hip joints above the soles
	local hipY
	for _, m in order do
		if m.Part1.Name == "LeftUpperLeg" or m.Part1.Name == "Left Leg" then
			hipY = (restCF[m.Part0.Name] * m.C0).Position.Y
		end
	end
	local legLength = if hipY and restFoot < math.huge then hipY - restFoot else 2.5
	return {
		model = model,
		humanoid = humanoid,
		hrp = hrp,
		rigType = rigType,
		order = order,
		restCF = restCF,
		feet = feetNames,
		restFoot = restFoot,
		legLength = math.max(legLength, 0.5),
		bottom = bottom,
		rootMotor = order[1],
	}
end

local function quat(q)
	return CFrame.new(0, 0, 0, q[1], q[2], q[3], q[4])
end

-- Joint transforms for one key: { [Motor6D] = CFrame }.
local function solveKey(info, data, i, groundLock)
	local tracks = if info.rigType == "R15" then data.parts else data.r6
	local rot = { [info.hrp.Name] = CFrame.identity }
	local T = {}
	for _, m in info.order do
		local p0, p1 = m.Part0.Name, m.Part1.Name
		local trackName = if info.rigType == "R6" then R6_TRACK[p1] else p1
		local track = trackName and tracks[trackName]
		local C0r, C1r = rotOnly(m.C0), rotOnly(m.C1)
		local Rp = rot[p0] or rotOnly(info.restCF[p0] or CFrame.identity)
		if track and track[i] then
			local Rc = quat(track[i]) * rotOnly(info.restCF[p1])
			rot[p1] = Rc
			T[m] = C0r:Inverse() * Rp:Inverse() * Rc * C1r
		else
			rot[p1] = Rp * C0r * C1r:Inverse()
			T[m] = CFrame.identity
		end
	end
	-- root translation (leg-length units -> studs on this rig)
	local L = info.legLength
	local root = data.root and data.root[i] or { 0, 0, 0 }
	local air = (data.airborne and data.airborne[i] or 0) * L
	local offset = Vector3.new(root[1] * L, 0, root[3] * L)
	local rm = info.rootMotor
	local rootPart = rm.Part1.Name
	local function rootT(off)
		local desired = CFrame.new(info.restCF[rootPart].Position + off) * rot[rootPart]
		return rm.C0:Inverse() * desired * rm.C1
	end
	T[rm] = rootT(offset)
	local dy
	if groundLock then
		-- forward kinematics on the real rig: where do the soles end up?
		local cf = { [info.hrp.Name] = CFrame.identity }
		for _, m in info.order do
			cf[m.Part1.Name] = cf[m.Part0.Name] * m.C0 * T[m] * m.C1:Inverse()
		end
		local low = math.huge
		for _, f in info.feet do
			if cf[f] then
				low = math.min(low, info.bottom(f, cf[f]))
			end
		end
		dy = if low < math.huge then (info.restFoot - low) + air else air
	else
		dy = (data.vertical and data.vertical[i] or 0) * L + air
	end
	T[rm] = rootT(offset + Vector3.new(0, dy, 0))
	return T
end

-- Builds the KeyframeSequence. opts: { groundLock = true, name = string }
function Anim.build(data, info, opts)
	opts = opts or {}
	local groundLock = opts.groundLock ~= false
	local kfs = Instance.new("KeyframeSequence")
	kfs.Name = opts.name or data.name or "ClipForgeAnim"
	kfs.Loop = data.loop == true
	local ok, prio = pcall(function()
		return Enum.AnimationPriority[data.priority or "Action"]
	end)
	kfs.Priority = if ok and prio then prio else Enum.AnimationPriority.Action
	local times = data.keyTimes
	local keyframes = {}
	for i, t in times do
		local T = solveKey(info, data, i, groundLock)
		local kf = Instance.new("Keyframe")
		kf.Time = t
		local poses = {}
		local rootPose = Instance.new("Pose")
		rootPose.Name = info.hrp.Name
		rootPose.Weight = 0
		rootPose.Parent = kf
		poses[info.hrp.Name] = rootPose
		for _, m in info.order do
			local pose = Instance.new("Pose")
			pose.Name = m.Part1.Name
			pose.CFrame = T[m]
			pose.EasingStyle = Enum.PoseEasingStyle.Linear
			pose.EasingDirection = Enum.PoseEasingDirection.In
			pose.Parent = poses[m.Part0.Name] or rootPose
			poses[m.Part1.Name] = pose
		end
		kf.Parent = kfs
		keyframes[i] = kf
		if i % 60 == 0 then
			task.wait()
		end
	end
	-- named markers (e.g. "Hit" on the contact frame): game code and abilities listen with
	-- track:GetMarkerReachedSignal("Hit") to fire effects, damage and hit-stop exactly on the frame
	for _, mk in data.markers or {} do
		local best, bestDt = nil, math.huge
		for i, t in times do
			local dt = math.abs(t - (mk.t or 0))
			if dt < bestDt then
				best, bestDt = keyframes[i], dt
			end
		end
		if best then
			local marker = Instance.new("KeyframeMarker")
			marker.Name = mk.name or "Hit"
			marker.Value = mk.value or ""
			best:AddMarker(marker)
		end
	end
	kfs:SetAttribute("ClipForge", true)
	kfs:SetAttribute("Rig", info.rigType)
	kfs:SetAttribute("Duration", times[#times] or 0)
	if data.source and data.source.url then
		kfs:SetAttribute("SourceUrl", data.source.url)
	end
	return kfs
end

-- Edit-mode preview with the engine's own animator (what the Animation Editor uses).
local preview = nil

function Anim.stopPreview()
	if not preview then
		return
	end
	local p = preview
	preview = nil
	if p.conn then
		p.conn:Disconnect()
	end
	pcall(function()
		p.track:Stop(0)
		p.track:Destroy()
		p.animator:StepAnimations(0)
	end)
	for _, d in p.model:GetDescendants() do
		if d:IsA("Motor6D") or d:IsA("AnimationConstraint") then
			pcall(function()
				d.Transform = CFrame.identity
			end)
		end
	end
end

function Anim.preview(model: Model, kfs: KeyframeSequence, looped: boolean?)
	Anim.stopPreview()
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return false, "The rig needs a Humanoid"
	end
	local controller = humanoid
	local animator = controller:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = controller
	end
	local ok, id = pcall(function()
		return AnimationClipProvider:RegisterAnimationClip(kfs)
	end)
	if not ok then
		return false, "Could not register the clip for preview: " .. tostring(id)
	end
	local anim = Instance.new("Animation")
	anim.AnimationId = id
	local track = animator:LoadAnimation(anim)
	track.Looped = looped ~= false
	track:Play(0)
	local state = { model = model, animator = animator, track = track }
	state.conn = RunService.Heartbeat:Connect(function(dt)
		if not track.IsPlaying and not track.Looped then
			Anim.stopPreview()
			return
		end
		animator:StepAnimations(dt)
	end)
	preview = state
	return true
end

function Anim.isPreviewing()
	return preview ~= nil
end

-- Pause the running preview at a time (seconds) - for scrubbing and stills.
function Anim.seek(t: number)
	if not preview then
		return false
	end
	local p = preview
	p.track:AdjustSpeed(0)
	p.track.TimePosition = math.clamp(t, 0, p.track.Length)
	p.animator:StepAnimations(0)
	return true
end

function Anim.resume(speed: number?)
	if preview then
		preview.track:AdjustSpeed(speed or 1)
	end
end

function Anim.previewTime(): number
	return if preview then preview.track.TimePosition else 0
end

function Anim.previewLength(): number
	return if preview then preview.track.Length else 0
end

return Anim
