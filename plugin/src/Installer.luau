-- ClipForge Installer: puts what a game needs into the place (with undo).
--   ReplicatedStorage.ClipForge          FX runtime (VFXTimeline, Recolor, FX, Recipes) + Effects (configs)
--   ServerStorage.ClipForge.Animations   KeyframeSequences made from videos
--   ServerStorage.ClipForge.MotionData   the raw motion of each animation (re-bake on another rig any time)
--   ServerStorage.RBX_ANIMSAVES          copies the Animation Editor can open

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local HttpService = game:GetService("HttpService")
local MOTION_CHUNK = 190000 -- characters per motion-data part (a script's Source is capped at 200,000)

local Installer = {}
local pluginRoot = script.Parent

local RUNTIME = { "VFXTimeline", "Recolor", "Blocks", "Library", "Generator", "FX", "Cutscene", "Abilities" }

local function folder(parent: Instance, name: string): Folder
	local f = parent:FindFirstChild(name)
	if not f then
		f = Instance.new("Folder")
		f.Name = name
		f.Parent = parent
	end
	return f :: Folder
end

local function sourceOf(m: Instance): string
	return (m :: any).Source
end

-- Copies (or refreshes) the runtime modules into ReplicatedStorage.ClipForge. Effects already there are kept, and so
-- is anything saved inside a runtime module: saved abilities live under the Abilities module (require(...).play finds
-- them there), so refreshing it after a plugin update moves them into the new copy instead of deleting them.
function Installer.ensureRuntime(): Folder
	local rs = folder(ReplicatedStorage, "ClipForge")
	for _, name in RUNTIME do
		local src = pluginRoot:FindFirstChild(name)
		local dst, strays = nil, {}
		for _, c in rs:GetChildren() do
			if c.Name == name then
				if c:IsA("ModuleScript") and not dst then
					dst = c
				else
					table.insert(strays, c) -- e.g. a Folder of the same name from an older version
				end
			end
		end
		if not dst or sourceOf(dst) ~= sourceOf(src) then
			local fresh = src:Clone()
			if dst then
				for _, saved in dst:GetChildren() do
					if not src:FindFirstChild(saved.Name) then
						saved.Parent = fresh
					end
				end
				dst:Destroy()
			end
			fresh.Parent = rs
			dst = fresh
		end
		for _, stray in strays do
			for _, saved in stray:GetChildren() do
				if not dst:FindFirstChild(saved.Name) then
					saved.Parent = dst
				end
			end
			if #stray:GetChildren() == 0 then
				stray:Destroy()
			end
		end
	end
	local recipes = folder(rs, "Recipes")
	for _, src in pluginRoot.Recipes:GetChildren() do
		local dst = recipes:FindFirstChild(src.Name)
		if not dst or sourceOf(dst) ~= sourceOf(src) then
			if dst then
				dst:Destroy()
			end
			src:Clone().Parent = recipes
		end
	end
	folder(rs, "Effects")
	if not rs:FindFirstChild("README") then
		local readme = Instance.new("ModuleScript")
		readme.Name = "README"
		readme.Source = table.concat({
			"--[[ ClipForge effects",
			"",
			"Play an effect (on the client; from the server, fire a RemoteEvent and play it on each client):",
			"",
			"    local FX = require(game.ReplicatedStorage.ClipForge.FX)",
			"    FX.preload(\"MyEffect\")                                  -- once, so the first play has its textures",
			"    FX.play(\"MyEffect\", humanoidRootPart.CFrame * CFrame.new(0, 0, -4))",
			"    FX.play(\"MyEffect\", somePart, { scale = 1.5, speed = 0.8 })",
			"",
			"Each module in Effects/ is a plain config (base recipe, palette, scale, speed, roll, parts).",
			"Edit the numbers and replay with the ClipForge plugin. Effect runtime and recipes: vfxmith (MIT).",
			"]]",
			"return nil",
		}, "\n")
		readme.Parent = rs
	end
	return rs
end

-- Luau source for a plain-data table (configs are numbers, strings, booleans and nested tables).
local function isArray(t)
	local n = 0
	for k in t do
		if type(k) ~= "number" then
			return false
		end
		n += 1
	end
	return n == #t
end

local function serialize(v, indent: string): string
	local t = type(v)
	if t == "string" then
		return string.format("%q", v)
	elseif t == "number" then
		if v == math.floor(v) and math.abs(v) < 1e15 then
			return tostring(math.floor(v))
		end
		return string.format("%.4g", v)
	elseif t == "boolean" or t == "nil" then
		return tostring(v)
	elseif t == "table" then
		local inner = indent .. "\t"
		local parts = {}
		if isArray(v) then
			local simple = true
			for _, x in v do
				if type(x) == "table" then
					simple = false
				end
			end
			for _, x in v do
				table.insert(parts, serialize(x, inner))
			end
			if simple then
				return "{ " .. table.concat(parts, ", ") .. " }"
			end
			return "{\n" .. inner .. table.concat(parts, ",\n" .. inner) .. ",\n" .. indent .. "}"
		end
		local keys = {}
		for k in v do
			table.insert(keys, k)
		end
		table.sort(keys, function(a, b)
			return tostring(a) < tostring(b)
		end)
		for _, k in keys do
			local key = if type(k) == "string" and string.match(k, "^[%a_][%w_]*$") then k else "[" .. serialize(k, inner) .. "]"
			table.insert(parts, key .. " = " .. serialize(v[k], inner))
		end
		if #parts == 0 then
			return "{}"
		end
		return "{\n" .. inner .. table.concat(parts, ",\n" .. inner) .. ",\n" .. indent .. "}"
	end
	return "nil"
end
Installer.serialize = serialize

local function uniqueName(parent: Instance, name: string): string
	name = string.gsub(name, "[^%w_]", "")
	if name == "" then
		name = "Effect"
	end
	if not parent:FindFirstChild(name) then
		return name
	end
	local i = 2
	while parent:FindFirstChild(name .. i) do
		i += 1
	end
	return name .. i
end

-- Writes an effect config as ReplicatedStorage.ClipForge.Effects.<Name>. Returns the ModuleScript.
function Installer.saveEffect(config, overwrite: boolean?): ModuleScript
	local rs = Installer.ensureRuntime()
	local effects = rs:FindFirstChild("Effects")
	local clean = {
		name = config.name,
		base = config.base,
		archetype = config.archetype,
		description = config.description,
		palette = config.palette,
		scale = config.scale,
		speed = config.speed,
		intensity = config.intensity,
		roll = config.roll,
		yaw = config.yaw,
		parts = config.parts,
		prompt = config.prompt,
		generate = config.generate,
		shake = config.shake,
	}
	local name = string.gsub(config.name or "Effect", "[^%w_]", "")
	local existing = effects:FindFirstChild(name)
	if existing and overwrite then
		existing:Destroy()
	else
		name = uniqueName(effects, name)
	end
	clean.name = name
	local src = config.source and config.source.url and ("-- Made by ClipForge from " .. config.source.url .. "\n") or "-- Made by ClipForge\n"
	if config.analysis and config.analysis.confidence then
		src ..= string.format("-- Read as: %s (%d%% sure)\n", tostring(config.description or config.archetype), math.floor(config.analysis.confidence * 100))
	end
	local m = Instance.new("ModuleScript")
	m.Name = name
	m.Source = src .. "-- Play: require(game.ReplicatedStorage.ClipForge.FX).play(\"" .. name .. "\", cframe)\nreturn " .. serialize(clean, "") .. "\n"
	m:SetAttribute("ClipForge", true)
	m.Parent = effects
	return m
end

-- Stores an animation: KeyframeSequence in ServerStorage.ClipForge.Animations (+ motion data, + Animation Editor copy).
function Installer.saveAnimation(kfs: KeyframeSequence, data, rig: Model?): KeyframeSequence
	local cf = folder(ServerStorage, "ClipForge")
	local anims = folder(cf, "Animations")
	kfs.Name = uniqueName(anims, kfs.Name)
	kfs.Parent = anims
	-- raw motion, so the same clip can be re-baked on another rig or with other options
	local md = folder(cf, "MotionData")
	local old = md:FindFirstChild(kfs.Name)
	if old then
		old:Destroy()
	end
	local holder = Instance.new("ModuleScript")
	holder.Name = kfs.Name
	local json = HttpService:JSONEncode(data)
	-- a script's Source holds at most 200,000 characters: a long clip's motion is split over Part1, Part2... children
	if #json <= MOTION_CHUNK then
		holder.Source = "-- ClipForge motion data (JSON). Used by the plugin to re-bake this animation.\nreturn [==[" .. json .. "]==]\n"
	else
		local count = math.ceil(#json / MOTION_CHUNK)
		holder.Source = "-- ClipForge motion data (JSON in " .. count .. " parts, the Part children). Used by the plugin to re-bake this animation.\n"
			.. "local parts = {}\nfor i = 1, " .. count .. " do\n\tparts[i] = require(script:FindFirstChild(\"Part\" .. i))\nend\nreturn table.concat(parts)\n"
		for i = 1, count do
			local part = Instance.new("ModuleScript")
			part.Name = "Part" .. i
			part.Source = "return [==[" .. string.sub(json, (i - 1) * MOTION_CHUNK + 1, i * MOTION_CHUNK) .. "]==]\n"
			part.Parent = holder
		end
	end
	holder.Parent = md
	if rig then
		Installer.sendToAnimationEditor(kfs, rig)
	end
	return kfs
end

-- The Animation Editor lists saves from ServerStorage.RBX_ANIMSAVES.<rig name>.
function Installer.sendToAnimationEditor(kfs: KeyframeSequence, rig: Model)
	local saves = ServerStorage:FindFirstChild("RBX_ANIMSAVES")
	if not saves then
		saves = Instance.new("Model")
		saves.Name = "RBX_ANIMSAVES"
		saves.Parent = ServerStorage
	end
	local slot = saves:FindFirstChild(rig.Name)
	if not slot then
		slot = Instance.new("ObjectValue")
		slot.Name = rig.Name
		slot.Value = rig
		slot.Parent = saves
	end
	local existing = slot:FindFirstChild(kfs.Name)
	if existing then
		existing:Destroy()
	end
	kfs:Clone().Parent = slot
end

function Installer.motionData(name: string)
	local md = ServerStorage:FindFirstChild("ClipForge") and ServerStorage.ClipForge:FindFirstChild("MotionData")
	local holder = md and md:FindFirstChild(name)
	if not holder then
		return nil
	end
	local json = string.match((holder :: any).Source, "%[==%[(.*)%]==%]")
	if not json and holder:FindFirstChild("Part1") then -- a long clip, saved in parts
		local pieces, i = {}, 1
		local part = holder:FindFirstChild("Part1")
		while part do
			table.insert(pieces, string.match((part :: any).Source, "%[==%[(.*)%]==%]") or "")
			i += 1
			part = holder:FindFirstChild("Part" .. i)
		end
		json = table.concat(pieces)
	end
	if not json then
		return nil
	end
	local ok, data = pcall(HttpService.JSONDecode, HttpService, json)
	return if ok then data else nil
end

local function saveData(folderName: string, config, header: string)
	local rs = Installer.ensureRuntime()
	local f = folder(rs, folderName)
	local name = uniqueName(f, config.name or folderName)
	config.name = name
	local m = Instance.new("ModuleScript")
	m.Name = name
	m.Source = header .. "return " .. serialize(config, "") .. "\n"
	m:SetAttribute("ClipForge", true)
	m.Parent = f
	return m
end

-- ReplicatedStorage.ClipForge.Cutscenes.<Name>
function Installer.saveCutscene(config)
	return saveData("Cutscenes", config, "-- ClipForge cutscene. Play (LocalScript): require(game.ReplicatedStorage.ClipForge.Cutscene).play(script.Name, { actors = {...} })\n")
end

-- ReplicatedStorage.ClipForge.Abilities.<Name> (animation + effects in sync)
function Installer.saveAbility(config)
	return saveData("Abilities", config, "-- ClipForge ability. Publish the animation, put its id in `animation`, then (LocalScript):\n-- require(game.ReplicatedStorage.ClipForge.Abilities).play(script.Name, character)\n")
end

-- ReplicatedStorage.ClipForge.Models.<Name>
function Installer.saveModel(model: Model)
	local rs = Installer.ensureRuntime()
	local f = folder(rs, "Models")
	local copy = model:Clone()
	copy.Name = uniqueName(f, model.Name)
	copy.Parent = f
	return copy
end

return Installer
