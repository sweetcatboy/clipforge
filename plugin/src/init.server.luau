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

local VERSION = "1.0.0"

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

Bridge.url = setting("ServerUrl", "http://127.0.0.1:7313")
Bridge.token = setting("Token", "")

local state = {
	running = true,
	botLink = false, -- per Studio window: build jobs other bots send
	previewOnBuild = setting("PreviewOnBuild", true),
	mine = {}, -- job ids submitted from this window
	claimed = {},
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
local function selectTab(name)
	for n, page in pages do
		page.Visible = n == name
	end
	for n, b in tabButtons do
		local on = n == name
		b.BackgroundTransparency = if on then 0 else 1
		b.BackgroundColor3 = UI.ACCENT
		b.TextColor3 = if on then Color3.new(1, 1, 1) else UI.color("text")
	end
	saveSetting("Tab", name)
end
for i, name in { "Create", "Library", "Animations", "Bots" } do
	local b = Instance.new("TextButton")
	b.AutoButtonColor = false
	b.Size = UDim2.new(0, 10, 1, 0)
	b.Text = name
	b.FontFace = UI.FONT_MED
	b.TextSize = 14
	b.LayoutOrder = i
	UI.corner(b, 6)
	b.Parent = tabBar
	tabButtons[name] = b
	local page = UI.scroll(content)
	page.Visible = false
	pages[name] = page
	b.Activated:Connect(function()
		selectTab(name)
	end)
end
settings().Studio.ThemeChanged:Connect(function()
	selectTab(setting("Tab", "Create"))
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

local function cameraGround(): Vector3
	local cam = workspace.CurrentCamera
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore = { cam }
	local rig = workspace:FindFirstChild("ClipForgeRig")
	if rig then
		table.insert(ignore, rig)
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
local function previewOrigin(): CFrame
	local cam = workspace.CurrentCamera
	local look = cam.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude < 1e-3 then
		flat = Vector3.new(0, 0, -1)
	end
	local pos
	for _, s in Selection:Get() do
		if s:IsA("BasePart") then
			pos = s.Position
			break
		elseif s:IsA("Model") and not s:FindFirstChildOfClass("Humanoid") then
			pos = s:GetPivot().Position
			break
		end
	end
	pos = pos or cameraGround()
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
local function buildJob(job)
	if state.claimed[job.id] then
		return
	end
	state.claimed[job.id] = true
	local okC = Bridge.request("POST", "/api/jobs/" .. job.id .. "/claim", { studio = game.Name })
	if not okC then
		return -- another Studio window took it
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
				local mod = Installer.saveEffect(cfg)
				paths.vfx = mod:GetFullName()
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
			end
		end)
	end)
	if not okB then
		setStatus("Build failed: " .. tostring(err), UI.BAD)
		Bridge.request("POST", "/api/jobs/" .. job.id .. "/claim", { release = true })
		state.claimed[job.id] = nil
		return
	end
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
					buildJob(job)
				end, 100)
				UI.button(acts, "Dismiss", "ghost", function()
					Bridge.cancel(job.id)
					state.mine[job.id] = nil
					r.frame:Destroy()
					rows[job.id] = nil
				end, 70)
				rows[job.id] = r
			end
			local kind = if job.kind == "both" then "animation + VFX" else job.kind
			local who = if job.client and job.client ~= "studio" then ("  •  from " .. job.client) else ""
			r.title.Text = string.format("%s  <font transparency=\"0.4\">%s%s</font>", job.name ~= "" and job.name or (job.source or job.prompt or job.id), kind, who)
			local color = if job.status == "failed" then UI.BAD elseif job.status == "done" then UI.OK else UI.ACCENT
			r.bar.set(job.progress or 0, color)
			local msg = job.error or job.message or ""
			if job.status == "done" and job.delivered then
				msg = "In your place" .. (if job.deliveredInfo and job.deliveredInfo.studio then " (" .. job.deliveredInfo.studio .. ")" else "")
			end
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
	local card = UI.card(create, "From a video")
	UI.dim(card, "Paste a YouTube, Shorts, TikTok, Instagram Reel, X or Reddit link, or the path of a video on this PC.")
	local src = UI.input(card, "https://www.tiktok.com/@creator/video/…")
	local kind = UI.segmented(card, { "animation", "vfx", "both" }, setting("Kind", "both"), function(v)
		saveSetting("Kind", v)
	end, { animation = "Animation", vfx = "VFX", both = "Both" })
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
			b.BackgroundColor3 = if on then UI.ACCENT else UI.color("field")
			b.TextColor3 = if on then Color3.new(1, 1, 1) else UI.color("text")
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
	settings().Studio.ThemeChanged:Connect(paintChips)
	local steer = UI.input(vfxCard, "Steer it (optional): \"make it purple\", \"slash\"")

	local go = UI.button(create, "Generate", "primary")
	createStatus = UI.dim(create, "")
	go.Activated:Connect(function()
		local s = trim(src.Text)
		if s == "" then
			setStatus("Paste a link or a file path first.", UI.WARN)
			return
		end
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
			local payload = { source = s, kind = kind.get(), options = options, client = "studio" }
			if trim(nameBox.Text) ~= "" then
				payload.name = trim(nameBox.Text)
			end
			if trim(steer.Text) ~= "" then
				payload.prompt = trim(steer.Text)
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
-- LIBRARY tab
----------------------------------------------------------------------------------------------------------------------
local library = pages.Library
do
	local lib = state.lib
	local promptCard = UI.card(library, "Describe an effect")
	local promptBox = UI.input(promptCard, "huge purple lightning slash, small holy heal…")
	local controls = {}

	local function currentConfig()
		return {
			name = if trim(controls.nameBox and controls.nameBox.Text or "") ~= "" then trim(controls.nameBox.Text) else (FX.BaseInfo[lib.base].title:gsub("%s", "")),
			base = lib.base,
			palette = lib.palette,
			scale = lib.scale,
			speed = lib.speed,
			intensity = 1,
			roll = if lib.base == "slash" then lib.roll else 0,
			yaw = 0,
			parts = lib.parts or { { base = lib.base, t = 0 } },
		}
	end

	local function preview()
		previewEffect(currentConfig(), controls.loop and controls.loop.get())
	end

	local paletteViews = {}
	local function showPalette()
		local p = lib.palette
		for role, v in paletteViews do
			local hex = p and p[role]
			if hex then
				v.swatch.BackgroundColor3 = Recolor.hexToColor(hex) or Color3.new(1, 1, 1)
				v.box.Text = hex
			else
				v.swatch.BackgroundColor3 = UI.color("field")
				v.box.Text = ""
			end
		end
	end

	local makeRow = UI.row(promptCard, 6, 32)
	UI.button(makeRow, "Make it", "primary", function()
		local cfg = Prompt.parse(promptBox.Text)
		lib.base = cfg.base
		lib.palette = cfg.palette
		lib.scale = cfg.scale
		lib.speed = cfg.speed
		lib.roll = cfg.roll ~= 0 and cfg.roll or lib.roll
		lib.parts = cfg.parts
		if controls.nameBox then
			controls.nameBox.Text = cfg.name
		end
		if controls.refresh then
			controls.refresh()
		end
		showPalette()
		preview()
	end, 110)
	UI.dim(makeRow, "Works offline.", 12).Size = UDim2.new(1, -120, 1, 0)

	-- base effects grid
	local baseCard = UI.card(library, "Base effects")
	UI.dim(baseCard, "Built from studied pro effects (layered flashes, flipbooks, rings, ink twins, smoke). Click to preview.")
	local gridFrame = UI.frame(baseCard)
	local g = Instance.new("UIGridLayout")
	g.CellSize = UDim2.new(0.5, -4, 0, 46)
	g.CellPadding = UDim2.new(0, 8, 0, 8)
	g.SortOrder = Enum.SortOrder.LayoutOrder
	g.Parent = gridFrame
	local baseButtons = {}
	local function paintBases()
		for b, btn in baseButtons do
			local on = b == lib.base
			btn.stroke.Color = if on then UI.ACCENT else UI.color("border")
			btn.stroke.Thickness = if on then 2 else 1
		end
	end
	for i, base in FX.Bases do
		local info = FX.BaseInfo[base]
		local b = Instance.new("TextButton")
		b.AutoButtonColor = false
		b.Text = ""
		b.LayoutOrder = i
		UI.bind(b, "BackgroundColor3", "field")
		UI.corner(b, 7)
		local s = Instance.new("UIStroke")
		s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		s.Parent = b
		b.Parent = gridFrame
		local t = UI.label(b, "<b>" .. info.title .. "</b>", { TextSize = 13, Position = UDim2.new(0, 8, 0, 4), Size = UDim2.new(1, -16, 0, 16), AutomaticSize = Enum.AutomaticSize.None })
		t.Parent = b
		-- the recipe's own colours as a strip
		local strip = Instance.new("Frame")
		strip.BackgroundTransparency = 1
		strip.Position = UDim2.new(0, 8, 0, 26)
		strip.Size = UDim2.new(1, -16, 0, 10)
		strip.Parent = b
		local sl = UI.list(strip, 3, true)
		sl.HorizontalFlex = Enum.UIFlexAlignment.Fill
		pcall(function()
			local pal = FX.recipe(base).palette or {}
			local cols = {}
			for _, hex in pal do
				local c = Recolor.hexToColor(hex)
				if c then
					table.insert(cols, c)
				end
			end
			table.sort(cols, function(a, c)
				local _, _, va = a:ToHSV()
				local _, _, vc = c:ToHSV()
				return va > vc
			end)
			for k = 1, math.min(#cols, 6) do
				local sw = Instance.new("Frame")
				sw.BorderSizePixel = 0
				sw.Size = UDim2.new(0, 8, 1, 0)
				sw.BackgroundColor3 = cols[k]
				sw.LayoutOrder = k
				UI.corner(sw, 3)
				sw.Parent = strip
			end
		end)
		baseButtons[base] = { button = b, stroke = s }
		b.Activated:Connect(function()
			lib.base = base
			lib.parts = nil
			paintBases()
			if controls.refresh then
				controls.refresh()
			end
			preview()
		end)
	end
	paintBases()
	settings().Studio.ThemeChanged:Connect(paintBases)

	-- colours
	local colorCard = UI.card(library, "Colours")
	local presetFrame = UI.frame(colorCard)
	local pg = Instance.new("UIGridLayout")
	pg.CellSize = UDim2.new(0.25, -5, 0, 24)
	pg.CellPadding = UDim2.new(0, 5, 0, 5)
	pg.SortOrder = Enum.SortOrder.LayoutOrder
	pg.Parent = presetFrame
	for i, preset in Recolor.Presets do
		local b = Instance.new("TextButton")
		b.AutoButtonColor = false
		b.Text = preset.name
		b.FontFace = UI.FONT_MED
		b.TextSize = 12
		b.LayoutOrder = i
		UI.corner(b, 5)
		if preset.palette then
			local c = Recolor.hexToColor(preset.palette.primary)
			b.BackgroundColor3 = c
			local _, _, v = c:ToHSV()
			b.TextColor3 = if v > 0.75 and preset.name ~= "Void" and preset.name ~= "Blood" then Color3.new(0.08, 0.08, 0.1) else Color3.new(1, 1, 1)
		else
			UI.bind(b, "BackgroundColor3", "field")
			UI.bind(b, "TextColor3", "text")
		end
		b.Parent = presetFrame
		b.Activated:Connect(function()
			lib.palette = if preset.palette then FX.deepCopy(preset.palette) else nil
			showPalette()
			preview()
		end)
	end
	for _, role in { "core", "primary", "secondary", "deep" } do
		local r = UI.row(colorCard, 8, 26)
		local sw = UI.swatch(r, Color3.new(1, 1, 1), 24)
		local lab = UI.label(r, string.upper(string.sub(role, 1, 1)) .. string.sub(role, 2), { Size = UDim2.new(0, 70, 1, 0), AutomaticSize = Enum.AutomaticSize.None, TextYAlignment = Enum.TextYAlignment.Center })
		lab.TextSize = 13
		local box = UI.input(r, "#RRGGBB", "", { Size = UDim2.new(1, -110, 1, 0) })
		box.FocusLost:Connect(function()
			local hex = string.upper(trim(box.Text))
			if string.sub(hex, 1, 1) ~= "#" then
				hex = "#" .. hex
			end
			if Recolor.hexToColor(hex) then
				lib.palette = lib.palette or { core = "#FFFFFF", primary = "#7FB2FF", secondary = "#C38CFF", deep = "#101830" }
				lib.palette[role] = hex
				showPalette()
			else
				showPalette()
			end
		end)
		paletteViews[role] = { swatch = sw, box = box }
	end
	showPalette()

	-- size & timing
	local stCard = UI.card(library, "Size & timing")
	UI.dim(stCard, "Size")
	local scaleSeg = UI.segmented(stCard, { "0.6", "0.8", "1", "1.3", "1.6", "2" }, "1", function(v)
		lib.scale = tonumber(v)
	end)
	UI.dim(stCard, "Speed")
	local speedSeg = UI.segmented(stCard, { "0.6", "0.8", "1", "1.2", "1.5" }, "1", function(v)
		lib.speed = tonumber(v)
	end)
	UI.dim(stCard, "Slash angle")
	local rollSeg = UI.segmented(stCard, { "-45", "-25", "0", "25", "45", "90" }, "-25", function(v)
		lib.roll = tonumber(v)
	end)
	controls.refresh = function()
		local function nearest(seg, opts, v)
			local best, bd = opts[1], math.huge
			for _, o in opts do
				local d = math.abs(tonumber(o) - v)
				if d < bd then
					best, bd = o, d
				end
			end
			seg.set(best)
		end
		nearest(scaleSeg, { "0.6", "0.8", "1", "1.3", "1.6", "2" }, lib.scale)
		nearest(speedSeg, { "0.6", "0.8", "1", "1.2", "1.5" }, lib.speed)
		nearest(rollSeg, { "-45", "-25", "0", "25", "45", "90" }, lib.roll)
		paintBases()
	end

	local playCard = UI.card(library, "Preview & insert")
	local pr = UI.row(playCard, 6, 32)
	UI.button(pr, "Preview", "primary", preview, 110)
	UI.button(pr, "Stop", "secondary", stopEffectPreview, 70)
	controls.loop = UI.toggle(playCard, "Loop preview", false, function(on)
		if not on then
			state.fxLoop = false
		end
	end)
	UI.dim(playCard, "Plays where the camera looks (or on the selected part).", 12)
	controls.nameBox = UI.input(playCard, "Effect name", "")
	UI.button(playCard, "Insert into game", "secondary", function()
		local cfg = currentConfig()
		local mod
		record("insert effect " .. cfg.name, function()
			mod = Installer.saveEffect(cfg, false)
		end)
		Selection:Set({ mod })
		setStatus("Saved " .. mod:GetFullName(), UI.OK)
	end)
	UI.dim(playCard, "Saves to ReplicatedStorage.ClipForge.Effects with the runtime. In a LocalScript:\n<font face=\"RobotoMono\">require(game.ReplicatedStorage.ClipForge.FX).play(\"Name\", cframe)</font>", 12)
end

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
						if j.status == "done" and not j.delivered and (state.mine[j.id] or state.botLink) then
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
