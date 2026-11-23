-- ClipForge: social-media video -> professional Roblox animations & VFX, for you and for your bots.
-- Studio plugin entry. The heavy lifting (download, pose tracking, VFX reading) runs in the local ClipForge bot
-- server; this plugin builds the results in your place, previews them and gives your game a runtime to play them.

local RunService = game:GetService("RunService")
if not RunService:IsEdit() then
	return -- edit mode only (plugins also load into play-test DataModels)
end

local Selection = game:GetService("Selection")
local ChangeHistoryService = game:GetService("ChangeHistoryService")
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local HttpService = game:GetService("HttpService")

local root = script
local UI = require(root.UI)
local FX = require(root.FX)
local Anim = require(root.Anim)
local Bridge = require(root.Bridge)
local Installer = require(root.Installer)
local Prompt = require(root.Prompt)
local Recolor = require(root.Recolor)
local Generator = require(root.Generator)
local ModelKit = require(root.ModelKit)
local Cutscene = require(root.Cutscene)
local Abilities = require(root.Abilities)
local TabLibrary = require(root.TabLibrary)
local TabModels = require(root.TabModels)
local TabScenes = require(root.TabScenes)
local TabSettings = require(root.TabSettings)

local VERSION = "1.2.0"

-- settings ---------------------------------------------------------------------------------------------------------
local function setting(key, default)
	local ok, v = pcall(plugin.GetSetting, plugin, "ClipForge_" .. key)
	if not ok or v == nil then
		return default
	end
	return v
end
local function saveSetting(key, v)
	pcall(plugin.SetSetting, plugin, "ClipForge_" .. key, v)
end

-- the saved look (theme, accent, text size, density) applies before anything is drawn
TabSettings.load({ UI = UI, Recolor = Recolor, setting = setting })

Bridge.url = setting("ServerUrl", "http://127.0.0.1:7313")
Bridge.token = setting("Token", "")

local state = {
	running = true,
	botLink = false, -- per Studio window: build jobs other bots send
	previewOnBuild = setting("PreviewOnBuild", true),
	mine = {}, -- job ids submitted from this window
	claimed = {},
	failed = {}, -- job id -> build error: not retried by itself (Build here retries)
	jobs = {},
	fxHandle = nil,
	fxLoop = false,
	lib = { base = "slash", palette = nil, scale = 1, speed = 1, roll = -25, name = "" },
	lastPoll = 0,
}

-- toolbar & widget -------------------------------------------------------------------------------------------------
local toolbar = plugin:CreateToolbar("ClipForge")
local button = toolbar:CreateButton(
	"ClipForge",
	"Turn YouTube / TikTok / Instagram clips into Roblox animations & VFX",
	"rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Large/Sparkles.png",
	"ClipForge"
)
button.ClickableWhenViewportHidden = true

local widgetInfo = DockWidgetPluginGuiInfo.new(Enum.InitialDockState.Right, false, false, 380, 680, 320, 420)
local widget
do
	local ok, w = pcall(function()
		return plugin:CreateDockWidgetPluginGuiAsync("ClipForgeMain", widgetInfo)
	end)
	if not ok then
		w = plugin:CreateDockWidgetPluginGui("ClipForgeMain", widgetInfo)
	end
	widget = w
end
pcall(function()
	widget.Title = "ClipForge"
end)
widget.Name = "ClipForge"
widget.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
button.Click:Connect(function()
	widget.Enabled = not widget.Enabled
end)
widget:GetPropertyChangedSignal("Enabled"):Connect(function()
	button:SetActive(widget.Enabled)
end)

local bg = Instance.new("Frame")
bg.Size = UDim2.fromScale(1, 1)
bg.BorderSizePixel = 0
UI.bind(bg, "BackgroundColor3", "bg")
bg.Parent = widget

-- header
local header = Instance.new("Frame")
header.Size = UDim2.new(1, 0, 0, 52)
header.BackgroundTransparency = 1
header.Parent = bg
UI.pad(header, 10, 12, 4, 12)
local title = UI.label(header, "<b>ClipForge</b>", { TextSize = 19, FontFace = UI.FONT_BOLD, Size = UDim2.new(1, -120, 0, 22), AutomaticSize = Enum.AutomaticSize.None })
title.Position = UDim2.new(0, 0, 0, 0)
local subtitle = UI.dim(header, "Video → animation & VFX", 12)
subtitle.AutomaticSize = Enum.AutomaticSize.None
subtitle.Size = UDim2.new(1, -120, 0, 16)
subtitle.Position = UDim2.new(0, 0, 0, 23)
local conn = Instance.new("TextLabel")
conn.BackgroundTransparency = 1
conn.AnchorPoint = Vector2.new(1, 0)
conn.Position = UDim2.new(1, 0, 0, 4)
conn.Size = UDim2.new(0, 118, 0, 18)
conn.FontFace = UI.FONT_MED
conn.TextSize = 12
conn.TextXAlignment = Enum.TextXAlignment.Right
conn.RichText = true
conn.Parent = header
UI.bind(conn, "TextColor3", "dim")

-- tabs
local tabBar = Instance.new("Frame")
tabBar.Position = UDim2.new(0, 10, 0, 52)
tabBar.Size = UDim2.new(1, -20, 0, 32)
tabBar.BackgroundTransparency = 1
tabBar.Parent = bg
local tabList = UI.list(tabBar, 4, true)
tabList.HorizontalFlex = Enum.UIFlexAlignment.Fill

local content = Instance.new("Frame")
content.Position = UDim2.new(0, 0, 0, 88)
content.Size = UDim2.new(1, 0, 1, -88)
content.BackgroundTransparency = 1
content.Parent = bg

local pages, tabButtons = {}, {}
local currentTab = "Create"
local function selectTab(name)
	if not pages[name] then
		name = "Create"
	end
	currentTab = name
	for n, page in pages do
		page.Visible = n == name
	end
	for n, b in tabButtons do
		local on = n == name
		b.BackgroundTransparency = if on then 0 else 1
		b.BackgroundColor3 = UI.accent()
		b.TextColor3 = if on then UI.color("onAccent") else UI.color("text")
		local icon = b:FindFirstChild("Icon")
		if icon then
			icon.ImageColor3 = b.TextColor3
		end
	end
	saveSetting("Tab", name)
end
local TABS = { { "Create", "Create" }, { "VFX", "VFX" }, { "Animations", "Anim" }, { "Scenes", "Scenes" }, { "Models", "Models" },
	{ "Bots", "Bots" }, { "Settings", "" } }
for i, pair in TABS do
	local name = pair[1]
	local b = Instance.new("TextButton")
	b.AutoButtonColor = false
	b.Size = UDim2.new(0, 10, 1, 0)
	b.Text = pair[2]
	b.FontFace = UI.FONT_MED
	UI.textSize(b, 13)
	b.LayoutOrder = i
	UI.corner(b, 6)
	if name == "Settings" then
		-- a real icon (the gear glyph falls back to a colour emoji that ignores the theme)
		local icon = Instance.new("ImageLabel")
		icon.Name = "Icon"
		icon.BackgroundTransparency = 1
		icon.Image = "rbxasset://textures/ui/Settings/MenuBarIcons/GameSettingsTab@2x.png"
		icon.Size = UDim2.fromOffset(16, 16)
		icon.AnchorPoint = Vector2.new(0.5, 0.5)
		icon.Position = UDim2.fromScale(0.5, 0.5)
		icon.Parent = b
	end
	b.Parent = tabBar
	tabButtons[name] = b
	local page = UI.scroll(content)
	page.Visible = false
	pages[name] = page
	b.Activated:Connect(function()
		selectTab(name)
	end)
end
UI.onTheme(function()
	selectTab(currentTab)
end)

-- shared helpers ---------------------------------------------------------------------------------------------------
local function trim(s)
	return (string.gsub(s or "", "^%s*(.-)%s*$", "%1"))
end

local function record(name, fn)
	local rec = nil
	pcall(function()
		rec = ChangeHistoryService:TryBeginRecording("ClipForge: " .. name)
	end)
	local ok, err = pcall(fn)
	if rec then
		ChangeHistoryService:FinishRecording(rec, if ok then Enum.FinishRecordingOperation.Commit else Enum.FinishRecordingOperation.Cancel)
	end
	if not ok then
		error(err, 0)
	end
end

-- a weapon/prop built by ClipForge (or a part of one)
local function isClipForgeModel(x: Instance): boolean
	local m = if x:IsA("Model") then x else x:FindFirstAncestorOfClass("Model")
	while m do
		if m:GetAttribute("ClipForgeModel") then
			return true
		end
		m = m:FindFirstAncestorOfClass("Model")
	end
	return false
end

local function cameraGround(skipModels: boolean?): Vector3
	local cam = workspace.CurrentCamera
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore = { cam }
	local rig = workspace:FindFirstChild("ClipForgeRig")
	if rig then
		table.insert(ignore, rig)
	end
	if skipModels then -- look through ClipForge's own models to the ground
		for _, c in workspace:GetChildren() do
			if c:IsA("Model") and c:GetAttribute("ClipForgeModel") then
				table.insert(ignore, c)
			end
		end
	end
	params.FilterDescendantsInstances = ignore
	local hit = workspace:Raycast(cam.CFrame.Position, cam.CFrame.LookVector * 500, params)
	if hit then
		return hit.Position
	end
	local p = cam.CFrame.Position + cam.CFrame.LookVector * 30
	local down = workspace:Raycast(p + Vector3.new(0, 50, 0), Vector3.new(0, -500, 0), params)
	return if down then down.Position else p
end

-- where previews play: the selected part/model, else where the camera looks; facing away from the camera
-- Where previews and builds go: the selected part/model, else where the camera looks. skipModels: ignore
-- ClipForge's own weapons/props (so a new model is not placed on top of the one just built and selected).
local function previewOrigin(skipModels: boolean?): CFrame
	local cam = workspace.CurrentCamera
	local look = cam.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude < 1e-3 then
		flat = Vector3.new(0, 0, -1)
	end
	local pos
	for _, s in Selection:Get() do
		if skipModels and isClipForgeModel(s) then
			continue
		end
		if s:IsA("BasePart") then
			pos = s.Position
			break
		elseif s:IsA("Model") and not s:FindFirstChildOfClass("Humanoid") then
			pos = s:GetPivot().Position
			break
		end
	end
	pos = pos or cameraGround(skipModels)
	return CFrame.lookAt(pos, pos + flat.Unit)
end

local function stopEffectPreview()
	state.fxLoop = false
	if state.fxHandle then
		pcall(state.fxHandle.stop)
		state.fxHandle = nil
	end
end

local function previewEffect(cfg, loop)
	stopEffectPreview()
	local origin = previewOrigin()
	local ok, h = pcall(FX.play, cfg, origin, { important = true, parent = workspace.CurrentCamera })
	if not ok then
		warn("[ClipForge] preview failed: " .. tostring(h))
		return
	end
	state.fxHandle = h
	if loop then
		state.fxLoop = true
		local token = {}
		state.fxLoopToken = token
		task.spawn(function()
			local len = 2.5
			pcall(function()
				len = FX.length(cfg)
			end)
			while state.fxLoop and state.fxLoopToken == token and state.running do
				task.wait(math.clamp(len, 0.8, 6) + 0.5)
				if not (state.fxLoop and state.fxLoopToken == token) then
					break
				end
				local okP, h2 = pcall(FX.play, cfg, origin, { important = true, parent = workspace.CurrentCamera })
				if okP then
					state.fxHandle = h2
				end
			end
		end)
	end
end

-- preview rig: the selected character, else workspace.ClipForgeRig (spawned on demand)
local function selectedRig()
	for _, s in Selection:Get() do
		local m = if s:IsA("Model") then s else s:FindFirstAncestorOfClass("Model")
		if m and m:FindFirstChildOfClass("Humanoid") and m:FindFirstChild("HumanoidRootPart") then
			return m
		end
	end
	return nil
end

local function spawnRig(kind: string)
	local old = workspace:FindFirstChild("ClipForgeRig")
	if old then
		old:Destroy()
	end
	local rigType = if kind == "R6" then Enum.HumanoidRigType.R6 else Enum.HumanoidRigType.R15
	local rig = Players:CreateHumanoidModelFromDescription(Instance.new("HumanoidDescription"), rigType)
	rig.Name = "ClipForgeRig"
	local cam = workspace.CurrentCamera
	local ground = cameraGround()
	local camFlat = Vector3.new(cam.CFrame.Position.X, ground.Y, cam.CFrame.Position.Z)
	local cf, size = rig:GetBoundingBox()
	local lift = rig:GetPivot().Position.Y - (cf.Position.Y - size.Y / 2)
	local at = ground + Vector3.new(0, lift, 0)
	rig:PivotTo(if (camFlat - ground).Magnitude > 0.1 then CFrame.lookAt(at, Vector3.new(camFlat.X, at.Y, camFlat.Z)) else CFrame.new(at))
	for _, p in rig:GetDescendants() do
		if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" then
			p.Color = Color3.fromRGB(214, 214, 220)
		end
	end
	rig.HumanoidRootPart.Anchored = true
	rig.Parent = workspace
	return rig
end

local function currentRig(create: boolean?)
	local r = selectedRig() or workspace:FindFirstChild("ClipForgeRig")
	if r then
		return r
	end
	if create then
		return spawnRig("R15")
	end
	return nil
end

-- forward declarations
local refreshAnimations
local activityViews = {}
local setStatus

-- building finished jobs -------------------------------------------------------------------------------------------
local function buildJob(job, manual: boolean?)
	if state.claimed[job.id] then
		return
	end
	state.claimed[job.id] = true
	local okC, why = Bridge.request("POST", "/api/jobs/" .. job.id .. "/claim", { studio = game.Name, force = manual == true })
	if not okC then
		if manual then
			setStatus(tostring(why), UI.WARN)
		end
		return -- another Studio window took it (or it is paused after failing)
	end
	local ok, res = Bridge.result(job.id)
	if not ok or type(res) ~= "table" then
		setStatus("Could not fetch result: " .. tostring(res), UI.BAD)
		return
	end
	local paths, focus = {}, nil
	local okB, err = pcall(function()
		record("build " .. tostring(res.name), function()
			if res.vfx then
				local cfg = res.vfx
				cfg.name = cfg.name or res.name or "ClipEffect"
				local entry = cfg.base and FX.Library.byId[cfg.base]
				if cfg.shake == nil and entry and entry.shake then
					cfg.shake = entry.shake -- library effects keep their camera shake
				end
				local mod = Installer.saveEffect(cfg)
				paths.vfx = mod:GetFullName()
				res._vfxName = mod.Name
				focus = mod
				if state.previewOnBuild and not res.animation then
					local live = FX.deepCopy(cfg)
					live.name = mod.Name
					previewEffect(live, false)
				end
			end
			if res.animation then
				local rig = currentRig(true)
				local info, e = Anim.rigInfo(rig)
				if not info then
					error(e)
				end
				local kfs = Anim.build(res.animation, info, { name = res.animation.name })
				Installer.saveAnimation(kfs, res.animation, rig)
				paths.animation = kfs:GetFullName()
				focus = focus or kfs
				if state.previewOnBuild then
					Anim.preview(rig, kfs, true)
				end
				-- words with both (e.g. "fire punch"): an ability that fires the effect on every Hit marker
				local timing = res.vfx and res.vfx.analysis and res.vfx.analysis.timing
				if res._vfxName and res.ability then
					local hits = {}
					for _, t in res.ability.at or {} do
						table.insert(hits, { marker = res.ability.marker or "Hit", at = t, effect = res._vfxName,
							attach = res.ability.attach or "Front" })
						break -- one marker entry fires on every Hit (combos included); `at` is the fallback timing
					end
					local ab = Installer.saveAbility({ name = kfs.Name .. "Ability", animation = "rbxassetid://0", keyframes = kfs.Name,
						hits = hits })
					paths.ability = ab:GetFullName()
				-- a clip with both: an ability that fires the effect at the clip's detected hit
				elseif res._vfxName and timing and timing.peak then
					local ab = Installer.saveAbility({ name = kfs.Name .. "Ability", animation = "rbxassetid://0", keyframes = kfs.Name,
						hits = { { at = timing.peak, effect = res._vfxName, attach = "Front" } } })
					paths.ability = ab:GetFullName()
				end
			end
			if res.cutscene then
				local cs = res.cutscene
				if not cs.shots then -- from a prompt: the server chose the template, lines and effect
					cs = Cutscene.template(cs.template or "intro", { who = cs.who, lines = cs.lines, effect = cs.effect,
						name = cs.name, title = cs.title, sub = cs.sub })
				end
				local m = Installer.saveCutscene(cs)
				paths.cutscene = m:GetFullName()
				focus = focus or m
				if state.loadCutscene then
					state.loadCutscene(cs) -- ready to preview in the Scenes tab
				end
			end
			if res.model then
				local model = ModelKit.build(res.model)
				local isProp = model:GetAttribute("ClipForgeKind") == "prop"
				model:PivotTo(previewOrigin(true) * CFrame.new(0, if isProp then 0 else 3, 0)
					* (if isProp then CFrame.identity else CFrame.Angles(0, 0, math.rad(-20))))
				for _, part in model:GetDescendants() do
					if part:IsA("BasePart") then
						part.Anchored = true -- on display until attached to a rig or made a Tool
					end
				end
				model.Parent = workspace
				paths.model = model:GetFullName()
				focus = focus or model
			end
		end)
	end)
	if not okB then
		-- report it once and stop: retrying on every poll would loop forever on the same error
		local msg = string.gsub(tostring(err), "^[%w%._]+:%d+: ", "")
		setStatus("Build failed: " .. msg .. " (press Build here to try again)", UI.BAD)
		Bridge.request("POST", "/api/jobs/" .. job.id .. "/claim", { release = true, error = msg })
		state.claimed[job.id] = nil
		state.failed[job.id] = msg
		return
	end
	state.failed[job.id] = nil
	Bridge.delivered(job.id, { studio = game.Name, paths = paths })
	if focus then
		Selection:Set({ focus })
	end
	setStatus("Built " .. tostring(res.name) .. " in your place", UI.OK)
	if refreshAnimations then
		refreshAnimations()
	end
end

-- activity list (shared by Create and Bots tabs) ------------------------------------------------------------------
local STATUS_TEXT = {
	queued = "Waiting", downloading = "Downloading", tracking = "Tracking motion", analyzing = "Reading the VFX",
	building = "Building", done = "Ready", failed = "Failed", cancelled = "Cancelled",
}

local function makeActivity(parent, onlyMine: boolean)
	local list = UI.frame(parent)
	UI.list(list, 8)
	local empty = UI.dim(list, if onlyMine then "Nothing yet. Paste a link above and press Generate." else "No bot jobs yet.")
	local rows = {}
	local view = {}
	function view.update(jobs)
		local seen = {}
		local n = 0
		for _, job in jobs do
			if onlyMine and not state.mine[job.id] then
				continue
			end
			n += 1
			if n > 8 then
				break
			end
			seen[job.id] = true
			local r = rows[job.id]
			if not r then
				r = {}
				r.frame = UI.frame(list)
				r.frame.LayoutOrder = -(job.seq or 0)
				UI.list(r.frame, 4)
				r.title = UI.label(r.frame, "", { FontFace = UI.FONT_MED })
				r.bar = UI.progress(r.frame)
				r.msg = UI.dim(r.frame, "", 12)
				local acts = UI.frame(r.frame, { AutomaticSize = Enum.AutomaticSize.None, Size = UDim2.new(1, 0, 0, 28), Visible = false })
				UI.list(acts, 6, true)
				r.acts = acts
				UI.button(acts, "Build here", "secondary", function()
					state.claimed[job.id] = nil
					state.failed[job.id] = nil
					buildJob(job, true)
				end, 100)
				UI.button(acts, "Dismiss", "ghost", function()
					Bridge.cancel(job.id)
					state.mine[job.id] = nil
					r.frame:Destroy()
					rows[job.id] = nil
				end, 70)
				rows[job.id] = r
			end
			local kind = job.kind
			if kind == "auto" and job.summary then -- words: name what the server made of them
				local made = {}
				for _, k in { "animation", "vfx", "model", "cutscene" } do
					if job.summary[k] then
						table.insert(made, if k == "vfx" then "VFX" else k)
					end
				end
				kind = if #made > 0 then table.concat(made, " + ") else "words"
			elseif kind == "auto" then
				kind = "words"
			elseif kind == "both" then
				kind = "animation + VFX"
			end
			local who = if job.client and job.client ~= "studio" then ("  •  from " .. job.client) else ""
			r.title.Text = string.format("%s  <font transparency=\"0.4\">%s%s</font>", job.name ~= "" and job.name or (job.source or job.prompt or job.id), kind, who)
			local color = if job.status == "failed" then UI.BAD elseif job.status == "done" then UI.OK else UI.ACCENT
			local msg = job.error or job.message or ""
			if job.status == "done" and job.delivered then
				msg = "In your place" .. (if job.deliveredInfo and job.deliveredInfo.studio then " (" .. job.deliveredInfo.studio .. ")" else "")
			elseif job.status == "done" and (state.failed[job.id] or job.buildError) then
				msg = "Could not build: " .. tostring(state.failed[job.id] or job.buildError)
				color = UI.BAD
			end
			r.bar.set(job.progress or 0, color)
			r.msg.Text = (STATUS_TEXT[job.status] or job.status) .. (if msg ~= "" then "  –  " .. msg else "")
			r.acts.Visible = job.status == "done" and not job.delivered
		end
		for id, r in rows do
			if not seen[id] then
				r.frame:Destroy()
				rows[id] = nil
			end
		end
		empty.Visible = n == 0
	end
	table.insert(activityViews, view)
	return view
end

----------------------------------------------------------------------------------------------------------------------
-- CREATE tab
----------------------------------------------------------------------------------------------------------------------
local create = pages.Create
local createStatus
do
	local card = UI.card(create, "From a video or words")
	UI.dim(card, "Paste a YouTube, Shorts, TikTok, Instagram Reel, X or Reddit link or a video file path, or just describe it: \"fire punch\", \"backflip\", \"heavy sword slash\", \"jab then cross then uppercut\".")
	local src = UI.input(card, "Link, file path, or words: fire punch, backflip, wave…")
	-- Auto: the server reads the words (an animation, an effect, both as an ability, a model or a cutscene); a clip
	-- on Auto makes both
	local kind = UI.segmented(card, { "auto", "animation", "vfx", "both" }, setting("Kind", "auto"), function(v)
		saveSetting("Kind", v)
	end, { auto = "Auto", animation = "Animation", vfx = "VFX", both = "Both" })
	local trimRow = UI.row(card, 6, 32)
	local startBox = UI.input(trimRow, "Start (s)", "", { Size = UDim2.new(0.25, -4, 1, 0) })
	local endBox = UI.input(trimRow, "End (s)", "", { Size = UDim2.new(0.25, -4, 1, 0) })
	local nameBox = UI.input(trimRow, "Name (optional)", "", { Size = UDim2.new(0.5, -4, 1, 0) })

	local animCard = UI.card(create, "Animation")
	local rootSeg = UI.segmented(animCard, { "inplace", "full", "none" }, setting("RootMotion", "inplace"), function(v)
		saveSetting("RootMotion", v)
	end, { inplace = "In place", full = "Travels", none = "Locked" })
	local smoothSeg = UI.segmented(animCard, { "0.25", "0.5", "0.8" }, setting("Smoothing", "0.5"), function(v)
		saveSetting("Smoothing", v)
	end, { ["0.25"] = "Crisp", ["0.5"] = "Smooth", ["0.8"] = "Silky" })
	local loopT = UI.toggle(animCard, "Loop (blends the end into the start)", false)
	local mirrorT = UI.toggle(animCard, "Mirror left / right", false)
	local faceT = UI.toggle(animCard, "Always face forward (attacks, emotes)", false)

	local vfxCard = UI.card(create, "VFX")
	UI.dim(vfxCard, "ClipForge reads the clip's colours, timing and motion, picks the closest pro recipe and fits it.")
	local styles = { "auto", "slash", "impact", "explosion", "aura", "beam", "lightning", "projectile", "fire", "ice", "dark", "holy" }
	local styleGrid = UI.frame(vfxCard)
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.new(0.25, -5, 0, 26)
	grid.CellPadding = UDim2.new(0, 5, 0, 5)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = styleGrid
	local style = "auto"
	local chips = {}
	local function paintChips()
		for v, b in chips do
			local on = v == style
			b.BackgroundColor3 = if on then UI.accent() else UI.color("field")
			b.TextColor3 = if on then UI.color("onAccent") else UI.color("text")
		end
	end
	for i, v in styles do
		local b = Instance.new("TextButton")
		b.AutoButtonColor = false
		b.Text = string.upper(string.sub(v, 1, 1)) .. string.sub(v, 2)
		b.FontFace = UI.FONT_MED
		b.TextSize = 12
		b.LayoutOrder = i
		UI.corner(b, 5)
		b.Parent = styleGrid
		chips[v] = b
		b.Activated:Connect(function()
			style = v
			paintChips()
		end)
	end
	paintChips()
	UI.onTheme(paintChips)
	local steer = UI.input(vfxCard, "Steer it (optional): \"make it purple\", \"slash\"")

	local go = UI.button(create, "Generate", "primary")
	createStatus = UI.dim(create, "")
	go.Activated:Connect(function()
		local s = trim(src.Text)
		if s == "" then
			setStatus("Paste a link or a file path, or describe a move or an effect.", UI.WARN)
			return
		end
		-- a link or a video file goes to the video pipeline; anything else is a description
		local lower = string.lower(s)
		local isVideo = string.match(lower, "^https?://") ~= nil or string.match(s, "^%a:[\\/]") ~= nil
			or string.match(lower, "%.mp4$") ~= nil or string.match(lower, "%.mov$") ~= nil or string.match(lower, "%.webm$") ~= nil
			or string.match(lower, "%.mkv$") ~= nil
		setStatus("Connecting to the bot server…")
		task.spawn(function()
			local okH = Bridge.connected or Bridge.health()
			if not okH then
				setStatus(Bridge.lastError or "Bot server not reachable", UI.BAD)
				return
			end
			local options = {
				rootMotion = rootSeg.get(),
				smoothing = tonumber(smoothSeg.get()),
				loop = loopT.get(),
				mirror = mirrorT.get(),
				lockFacing = faceT.get(),
				style = style,
			}
			local st, en = tonumber(trim(startBox.Text)), tonumber(trim(endBox.Text))
			if st then
				options.start = st
			end
			if en then
				options["end"] = en
			end
			local payload = { kind = kind.get(), options = options, client = "studio" }
			if isVideo then
				payload.source = s
				if trim(steer.Text) ~= "" then
					payload.prompt = trim(steer.Text)
				end
			else
				-- words: a hand-keyed move and/or an effect (Both links them as an ability on the Hit frame)
				payload.prompt = s
				options.loop = if loopT.get() then true else nil
				options.mirror = if mirrorT.get() then true else nil
				options.rootMotion = nil
				options.smoothing = nil
				options.style = nil
			end
			if trim(nameBox.Text) ~= "" then
				payload.name = trim(nameBox.Text)
			end
			local ok, job = Bridge.submit(payload)
			if ok then
				state.mine[job.id] = true
				setStatus("Queued. You can keep working; it builds itself when ready.", UI.OK)
				state.lastPoll = 0
			else
				setStatus(tostring(job), UI.BAD)
			end
		end)
	end)
	local act = UI.card(create, "Activity")
	makeActivity(act, true)
end

function setStatus(text, color)
	if createStatus then
		createStatus.Text = text
		createStatus.TextColor3 = color or UI.color("dim")
	end
end

----------------------------------------------------------------------------------------------------------------------
-- shared context for the tab modules
----------------------------------------------------------------------------------------------------------------------
local AnimationClipProvider = game:GetService("AnimationClipProvider")
local ctx = {
	UI = UI, FX = FX, Anim = Anim, Bridge = Bridge, Installer = Installer, Prompt = Prompt, Recolor = Recolor,
	Generator = Generator, ModelKit = ModelKit, Cutscene = Cutscene, Abilities = Abilities,
	state = state, plugin = plugin, version = VERSION,
	setting = setting, saveSetting = saveSetting, record = record,
	previewEffect = previewEffect, stopEffectPreview = stopEffectPreview, previewOrigin = previewOrigin,
	currentRig = currentRig, spawnRig = spawnRig,
	setStatus = function(...)
		setStatus(...)
	end,
	-- cutscene/ability previews: a KeyframeSequence name from ServerStorage.ClipForge.Animations -> a temporary id
	resolveAnimation = function(ref)
		local folder = ServerStorage:FindFirstChild("ClipForge") and ServerStorage.ClipForge:FindFirstChild("Animations")
		local kfs = folder and folder:FindFirstChild(tostring(ref))
		if kfs then
			local ok, id = pcall(AnimationClipProvider.RegisterAnimationClip, AnimationClipProvider, kfs)
			return if ok then id else nil
		end
		return ref
	end,
}

----------------------------------------------------------------------------------------------------------------------
-- VFX tab (generator + library), Cutscenes, Models, Settings
----------------------------------------------------------------------------------------------------------------------
TabLibrary.build(pages.VFX, ctx)
TabScenes.build(pages.Scenes, ctx)
TabModels.build(pages.Models, ctx)
TabSettings.build(pages.Settings, ctx)

----------------------------------------------------------------------------------------------------------------------
-- ANIMATIONS tab
----------------------------------------------------------------------------------------------------------------------
local animations = pages.Animations
do
	local rigCard = UI.card(animations, "Preview rig")
	local rigLabel = UI.dim(rigCard, "")
	local function showRig()
		local r = currentRig(false)
		rigLabel.Text = if r then ("Using <b>" .. r.Name .. "</b> (" .. (if r:FindFirstChild("UpperTorso") then "R15" else "R6") .. ")") else "No rig yet: select a character, or spawn a dummy."
	end
	local rr = UI.row(rigCard, 6, 30)
	UI.button(rr, "Spawn R15", "secondary", function()
		record("spawn rig", function()
			spawnRig("R15")
		end)
		showRig()
	end, 100)
	UI.button(rr, "Spawn R6", "secondary", function()
		record("spawn rig", function()
			spawnRig("R6")
		end)
		showRig()
	end, 90)
	UI.button(rr, "Stop", "ghost", function()
		Anim.stopPreview()
	end, 60)
	Selection.SelectionChanged:Connect(showRig)
	showRig()

	local listCard = UI.card(animations, "Your animations")
	local listFrame = UI.frame(listCard)
	UI.list(listFrame, 8)
	UI.dim(animations, "Publish uploads the animation to your Roblox account (Studio asks first). Use the id it gives you in an Animation object. \"Edit\" opens it in the Animation Editor's saves for this rig.", 12)

	refreshAnimations = function()
		UI.clear(listFrame)
		local folder = ServerStorage:FindFirstChild("ClipForge") and ServerStorage.ClipForge:FindFirstChild("Animations")
		local items = folder and folder:GetChildren() or {}
		if #items == 0 then
			UI.dim(listFrame, "None yet. Generate one from a video in the Create tab.")
			return
		end
		for _, kfs in items do
			if not kfs:IsA("KeyframeSequence") then
				continue
			end
			local item = UI.frame(listFrame)
			UI.list(item, 4)
			local dur = kfs:GetAttribute("Duration") or 0
			UI.label(item, string.format("<b>%s</b>  <font transparency=\"0.4\">%.1f s • %d keys • %s%s</font>", kfs.Name, dur, #kfs:GetChildren(), tostring(kfs:GetAttribute("Rig") or "?"), if kfs.Loop then " • loop" else ""), { TextSize = 13 })
			local br = UI.row(item, 5, 28)
			UI.button(br, "Play", "primary", function()
				local rig = currentRig(true)
				state.currentKfs = kfs
				local ok, err = Anim.preview(rig, kfs, true)
				if not ok then
					warn("[ClipForge] " .. tostring(err))
				end
			end, 58)
			UI.button(br, "Re-bake", "secondary", function()
				local data = Installer.motionData(kfs.Name)
				local rig = currentRig(true)
				local info, e = Anim.rigInfo(rig)
				if not (data and info) then
					warn("[ClipForge] " .. tostring(e or "no motion data saved for this animation"))
					return
				end
				record("re-bake " .. kfs.Name, function()
					local fresh = Anim.build(data, info, { name = kfs.Name })
					local parent = kfs.Parent
					kfs:Destroy()
					fresh.Parent = parent
					Installer.sendToAnimationEditor(fresh, rig)
				end)
				refreshAnimations()
			end, 74)
			UI.button(br, "Edit", "secondary", function()
				local rig = currentRig(true)
				Installer.sendToAnimationEditor(kfs, rig)
				Selection:Set({ rig })
				setStatus("Open the Animation Editor with " .. rig.Name .. " selected, then Load: " .. kfs.Name, UI.OK)
			end, 50)
			UI.button(br, "Publish", "secondary", function()
				Selection:Set({ kfs })
				local ok, err = pcall(function()
					plugin:SaveSelectedToRoblox()
				end)
				if not ok then
					warn("[ClipForge] publish: " .. tostring(err))
				end
			end, 70)
		end
	end
	refreshAnimations()

	local abil = UI.card(animations, "Ability: animation + VFX in sync")
	UI.dim(abil, "Play an animation above, then choose the effect and when it hits. Abilities save to ReplicatedStorage.ClipForge.Abilities.", 12)
	local abRow = UI.row(abil, 5, 28)
	local fxBox = UI.input(abRow, "effect (e.g. groundpound or MyEffect)", "", { Size = UDim2.new(1, -66, 1, 0) })
	local atBox = UI.input(abRow, "at s", "0.4", { Size = UDim2.new(0, 60, 1, 0) })
	local attach = UI.chips(abil, { "Front", "Ground", "RightHand", "LeftHand", "Root" }, "Front", nil, { columns = 5 })
	local function abilityConfig()
		local kfs = state.currentKfs
		local effect = trim(fxBox.Text)
		if effect == "" then
			effect = "impact"
		end
		return {
			name = (if kfs then kfs.Name else "My") .. "Ability",
			animation = "rbxassetid://0",
			keyframes = if kfs then kfs.Name else nil,
			hits = { { at = tonumber(atBox.Text) or 0.4, effect = effect, attach = attach.get() } },
		}
	end
	local abr = UI.row(abil, 6, 30)
	UI.button(abr, "Preview", "primary", function()
		local rig = currentRig(true)
		if state.currentKfs then
			Anim.preview(rig, state.currentKfs, false)
		end
		Abilities.play(abilityConfig(), rig, { noAnimation = true, parent = workspace.CurrentCamera, important = true })
	end, 90)
	UI.button(abr, "Save ability", "secondary", function()
		local m
		record("save ability", function()
			m = Installer.saveAbility(abilityConfig())
		end)
		Selection:Set({ m })
		setStatus("Saved " .. m:GetFullName() .. ". Publish the animation and paste its id into it.", UI.OK)
	end, 110)
end

----------------------------------------------------------------------------------------------------------------------
-- BOTS tab
----------------------------------------------------------------------------------------------------------------------
local bots = pages.Bots
local linkToggle
do
	local card = UI.card(bots, "Bot server")
	local statusLine = UI.label(card, "", { TextSize = 13 })
	local url = UI.input(card, "http://127.0.0.1:7313", Bridge.url)
	local token = UI.input(card, "Bot token (only for a server on another machine)", Bridge.token)
	local function showStatus()
		if Bridge.connected then
			statusLine.Text = string.format("<font color=\"#40C882\">●</font> Connected to ClipForge %s", tostring(Bridge.version or ""))
			conn.Text = "<font color=\"#40C882\">●</font> bot server"
		else
			statusLine.Text = "<font color=\"#FF5C5C\">●</font> " .. (Bridge.lastError or "Not connected")
			conn.Text = "<font color=\"#FF5C5C\">●</font> offline"
		end
	end
	local r = UI.row(card, 6, 30)
	UI.button(r, "Connect", "primary", function()
		Bridge.url = trim(url.Text) ~= "" and trim(url.Text) or "http://127.0.0.1:7313"
		Bridge.token = trim(token.Text)
		saveSetting("ServerUrl", Bridge.url)
		saveSetting("Token", Bridge.token)
		statusLine.Text = "Connecting…"
		task.spawn(function()
			Bridge.health()
			showStatus()
			state.lastPoll = 0
		end)
	end, 100)
	linkToggle = UI.toggle(card, "Bot Link: build what bots send (this window)", false, function(on)
		state.botLink = on
		state.lastPoll = 0
	end)
	UI.toggle(card, "Preview results when they arrive", state.previewOnBuild, function(on)
		state.previewOnBuild = on
		saveSetting("PreviewOnBuild", on)
	end)
	state.showStatus = showStatus
	showStatus()

	local how = UI.card(bots, "Hook up a bot")
	UI.dim(how, "<b>1.</b> Run <font face=\"RobotoMono\">start-server.ps1</font> in the ClipForge folder (setup.ps1 once first).", 12)
	UI.dim(how, "<b>2.</b> Any bot (Discord, script, n8n...) sends:\n<font face=\"RobotoMono\">POST /api/jobs  {\"source\": \"&lt;link&gt;\", \"kind\": \"both\"}</font>\nor <font face=\"RobotoMono\">{\"prompt\": \"huge purple lightning slash\"}</font>", 12)
	UI.dim(how, "<b>3.</b> AI agents (Claude, Cursor...) use the MCP server: <font face=\"RobotoMono\">python -m clipforge mcp</font>", 12)
	UI.dim(how, "<b>4.</b> Turn on Bot Link above: results build here automatically.", 12)

	local feed = UI.card(bots, "Bot jobs")
	makeActivity(feed, false)
end

-- polling ------------------------------------------------------------------------------------------------------------
local function anyMinePending()
	for id in state.mine do
		local j = state.jobs[id]
		if not j or (j.status ~= "failed" and j.status ~= "cancelled" and not j.delivered) then
			return true
		end
	end
	return false
end

task.spawn(function()
	-- no network traffic until the widget is opened (Studio asks for HTTP permission on first contact)
	local greeted = false
	while state.running do
		if widget.Enabled and not greeted then
			greeted = true
			Bridge.health()
			if state.showStatus then
				state.showStatus()
			end
		end
		local now = os.clock()
		local interval = if anyMinePending() then 1.5 elseif state.botLink then 2 else 8
		if widget.Enabled or anyMinePending() or state.botLink then
			if now - state.lastPoll >= interval then
				state.lastPoll = now
				local ok, jobs = Bridge.jobs(25)
				local wasConnected = Bridge.connected
				Bridge.connected = ok
				if ok then
					for _, j in jobs do
						state.jobs[j.id] = j
					end
					for _, v in activityViews do
						pcall(v.update, jobs)
					end
					for _, j in jobs do
						if j.status == "done" and not j.delivered and not state.failed[j.id] and (state.mine[j.id] or state.botLink) then
							task.spawn(buildJob, j)
						end
					end
				end
				if wasConnected ~= Bridge.connected and state.showStatus then
					state.showStatus()
				end
			end
		end
		task.wait(0.5)
	end
end)

plugin.Unloading:Connect(function()
	state.running = false
	stopEffectPreview()
	Anim.stopPreview()
end)

selectTab(setting("Tab", "Create"))
-- dev hook for automated tests (command bar): _G.ClipForgePlugin
_G.ClipForgePlugin = { FX = FX, Anim = Anim, Bridge = Bridge, Installer = Installer, Prompt = Prompt, state = state, version = VERSION, widget = widget, selectTab = selectTab }
