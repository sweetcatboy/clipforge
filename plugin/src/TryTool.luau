-- ClipForge TryTool: a Tool that plays an animation, and the effects linked to it, when you click. Put it in
-- StarterPack, press Play, equip it and click to see how it looks in the game. With a weapon model it is held in
-- the hand (the animation swings it); without one it is an empty-handed tool.
--
--   TryTool.make({ kfs = KeyframeSequence, ability = "FirePunchAnimAbility"?, weapon = Model?, name = string? })
--
-- In Studio play tests the animation plays straight from the KeyframeSequence kept inside the tool. A live game
-- needs a published animation: Publish it (Anim tab), then put the id in the tool's AnimationId attribute (or in
-- the ability's `animation`).

local StarterPack = game:GetService("StarterPack")

local TryTool = {}

TryTool.SOURCE = [==[
-- ClipForge "Try in game" tool: equip it and click to play the animation with its effects (hit-stop, camera shake).
-- Made by the ClipForge plugin. Studio play tests play it straight away. For a live game, publish the animation
-- (ClipForge > Anim > Publish) and put the id in this tool's AnimationId attribute.
local tool = script.Parent
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ClipForge = ReplicatedStorage:WaitForChild("ClipForge")
local Abilities = require(ClipForge:WaitForChild("Abilities"))

local function abilityModule()
	local name = tool:GetAttribute("Ability")
	local folder = ClipForge:FindFirstChild("Abilities")
	return if type(name) == "string" and name ~= "" and folder then folder:FindFirstChild(name) else nil
end

local registered = nil
local function animationId(): string?
	local id = tool:GetAttribute("AnimationId")
	if type(id) == "string" and id ~= "" and id ~= "rbxassetid://0" then
		return id
	end
	local module = abilityModule()
	if module then
		local ok, cfg = pcall(require, module)
		if ok and type(cfg) == "table" and type(cfg.animation) == "string" and cfg.animation ~= "" and cfg.animation ~= "rbxassetid://0" then
			return cfg.animation
		end
	end
	if registered then
		return registered
	end
	local kfs = tool:FindFirstChild("ClipForgeAnimation")
	if kfs then
		local ok, temp = pcall(function()
			return game:GetService("AnimationClipProvider"):RegisterAnimationClip(kfs)
		end)
		if ok and temp then
			registered = temp
			return temp
		end
	end
	warn("[ClipForge] " .. tool.Name .. ": publish the animation (ClipForge > Anim > Publish), then put its id in this tool's AnimationId attribute to play it in a live game.")
	return nil
end

local playing = nil
tool.Activated:Connect(function()
	local character = tool.Parent
	if not (character and character:FindFirstChildOfClass("Humanoid")) then
		return
	end
	if playing then
		if playing.track and playing.track.Looped then -- a looping animation: click again to stop it
			playing.stop()
			playing = nil
		end
		return
	end
	local id = animationId()
	if not id then
		return
	end
	local module = abilityModule()
	local config = if module then module.Name else { name = tool.Name, hits = {} }
	local ok, handle = pcall(Abilities.play, config, character, { animationId = id })
	if not ok then
		warn("[ClipForge] " .. tostring(handle))
		return
	end
	local track = handle.track
	if not track then
		return
	end
	playing = handle
	if not track.Looped then
		task.spawn(function()
			local t0 = os.clock()
			repeat
				task.wait()
			until not track.IsPlaying or os.clock() - t0 > 30
			if playing == handle then
				playing = nil
			end
		end)
	end
end)

tool.Unequipped:Connect(function()
	if playing then
		playing.stop()
		playing = nil
	end
end)
]==]

local function inside(tool: Instance, part: Instance?): boolean
	return part ~= nil and part:IsDescendantOf(tool)
end

-- Builds the tool and puts it in StarterPack (replacing an older ClipForge test tool of the same name).
function TryTool.make(opts)
	local Installer = require(script.Parent.Installer)
	local ModelKit = require(script.Parent.ModelKit)
	Installer.ensureRuntime() -- the tool plays through ReplicatedStorage.ClipForge.Abilities and FX
	local kfs = assert(opts.kfs, "TryTool.make needs an animation")
	local name = opts.name or ("Try " .. kfs.Name)
	local tool
	if opts.weapon then
		tool = ModelKit.toTool(opts.weapon)
		for _, d in tool:GetDescendants() do
			if d:IsA("BasePart") then
				d.Anchored = false
				d.CanCollide = false
				d.Massless = true
			elseif (d:IsA("JointInstance") or d:IsA("WeldConstraint")) and not (inside(tool, (d :: any).Part0) and inside(tool, (d :: any).Part1)) then
				d:Destroy() -- e.g. the weld that held it in a preview rig's hand: the tool's grip does that now
			end
		end
	else
		tool = Instance.new("Tool")
		tool.RequiresHandle = false
	end
	tool.Name = name
	tool.CanBeDropped = false
	tool.ToolTip = "Click: " .. kfs.Name
	tool:SetAttribute("ClipForgeTry", true)
	tool:SetAttribute("Ability", opts.ability or "")
	tool:SetAttribute("AnimationId", opts.animationId or "")
	local anim = kfs:Clone()
	anim.Name = "ClipForgeAnimation"
	anim.Parent = tool
	local script_ = Instance.new("LocalScript")
	script_.Name = "ClipForgeTry"
	script_.Source = TryTool.SOURCE
	script_.Parent = tool
	local old = StarterPack:FindFirstChild(name)
	if old and old:GetAttribute("ClipForgeTry") then
		old:Destroy()
	end
	tool.Parent = StarterPack
	return tool
end

return TryTool
