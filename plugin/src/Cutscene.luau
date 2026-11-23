-- ClipForge Cutscene: plays a cutscene described as data (camera shots + timed events). Client-side in games; the
-- ClipForge plugin also uses it to preview in Studio edit mode.
--
--   local Cutscene = require(game.ReplicatedStorage.ClipForge.Cutscene)
--   local h = Cutscene.play("BossIntro", { actors = { Boss = workspace.Boss, Player = player.Character } })
--   h.finished:Wait()
--
-- Config (a ModuleScript in ReplicatedStorage.ClipForge.Cutscenes, or a table):
--   { name, letterbox = true, skippable = true,
--     shots = { { t, dur, type = "static"|"dolly"|"orbit"|"push"|"pan"|"follow", target = "Boss", fov, fovTo, ease,
--                 blend (s), cf = {px,py,pz, lx,ly,lz}, from, to, radius, height, distance, angle, side, lookHeight } },
--     events = { { t, type = "text", text, speaker, dur } , { t, type = "fx", effect, at = "Boss", offset = {x,y,z}, scale },
--                { t, type = "anim", actor, animation }, { t, type = "shake", amp, dur }, { t, type = "fade", from, to, dur },
--                { t, type = "flash", dur, color }, { t, type = "title", text, sub, dur, pos = "low"|"center" }, { t, type = "sound", id, volume },
--                { t, type = "slowmo", speed, dur }, { t, type = "letterbox", on } } }
-- Positions in shots ("cf", "at") are in the space of the cutscene's anchor (opts.anchor, else the first actor).

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local root = script.Parent
local Cutscene = {}

local function fx()
	local ok, FX = pcall(function()
		return require(root:WaitForChild("FX", 2))
	end)
	return if ok then FX else nil
end

local EASE = {
	linear = function(x) return x end,
	sineInOut = function(x) return -(math.cos(math.pi * x) - 1) / 2 end,
	quadOut = function(x) return 1 - (1 - x) * (1 - x) end,
	quadIn = function(x) return x * x end,
	cubicInOut = function(x) return if x < 0.5 then 4 * x * x * x else 1 - (-2 * x + 2) ^ 3 / 2 end,
	expoOut = function(x) return if x >= 1 then 1 else 1 - 2 ^ (-10 * x) end,
}

local function resolve(cs)
	if type(cs) == "table" then
		return cs
	end
	if typeof(cs) == "Instance" and cs:IsA("ModuleScript") then
		return require(cs)
	end
	local folder = root:FindFirstChild("Cutscenes")
	local mod = folder and folder:FindFirstChild(cs)
	if not mod then
		error("ClipForge: no cutscene named " .. tostring(cs))
	end
	return require(mod)
end

local function pivotOf(x): CFrame?
	if typeof(x) == "CFrame" then
		return x
	elseif typeof(x) == "Vector3" then
		return CFrame.new(x)
	elseif typeof(x) == "Instance" then
		if x:IsA("Model") then
			local hrp = x:FindFirstChild("HumanoidRootPart")
			return if hrp then hrp.CFrame else x:GetPivot()
		elseif x:IsA("BasePart") then
			return x.CFrame
		elseif x:IsA("Attachment") then
			return x.WorldCFrame
		end
	end
	return nil
end

function Cutscene.length(cs)
	cs = resolve(cs)
	local n = cs.length or 0
	for _, s in cs.shots or {} do
		n = math.max(n, (s.t or 0) + (s.dur or 2))
	end
	for _, e in cs.events or {} do
		n = math.max(n, (e.t or 0) + (e.dur or 0))
	end
	return n
end

----------------------------------------------------------------------------------------------------------- GUI
local function makeGui(preview: boolean)
	local gui = Instance.new("ScreenGui")
	gui.Name = "ClipForgeCutscene"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 50
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	local function frame(name, props)
		local f = Instance.new("Frame")
		f.Name = name
		f.BorderSizePixel = 0
		for k, v in props do
			(f :: any)[k] = v
		end
		f.Parent = gui
		return f
	end
	local top = frame("BarTop", { BackgroundColor3 = Color3.new(0, 0, 0), Size = UDim2.new(1, 0, 0.11, 0), Position = UDim2.new(0, 0, -0.11, 0) })
	local bottom = frame("BarBottom", { BackgroundColor3 = Color3.new(0, 0, 0), Size = UDim2.new(1, 0, 0.11, 0), Position = UDim2.new(0, 0, 1, 0) })
	local fade = frame("Fade", { BackgroundColor3 = Color3.new(0, 0, 0), Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 5 })
	local flash = frame("Flash", { BackgroundColor3 = Color3.new(1, 1, 1), Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 6 })
	local function label(name, props)
		local t = Instance.new("TextLabel")
		t.Name = name
		t.BackgroundTransparency = 1
		t.TextColor3 = Color3.new(1, 1, 1)
		t.TextStrokeTransparency = 0.6
		t.Font = Enum.Font.GothamBold
		t.TextScaled = true
		t.Text = ""
		t.ZIndex = 4
		for k, v in props do
			(t :: any)[k] = v
		end
		t.Parent = gui
		return t
	end
	local speaker = label("Speaker", { Size = UDim2.new(0.6, 0, 0.035, 0), Position = UDim2.new(0.2, 0, 0.775, 0),
		TextColor3 = Color3.fromRGB(255, 214, 102), TextXAlignment = Enum.TextXAlignment.Left })
	local line = label("Line", { Size = UDim2.new(0.6, 0, 0.075, 0), Position = UDim2.new(0.2, 0, 0.815, 0), Font = Enum.Font.GothamMedium,
		TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, TextWrapped = true })
	local title = label("Title", { Size = UDim2.new(0.8, 0, 0.1, 0), Position = UDim2.new(0.1, 0, 0.38, 0), TextTransparency = 1, TextStrokeTransparency = 1 })
	local sub = label("Sub", { Size = UDim2.new(0.6, 0, 0.045, 0), Position = UDim2.new(0.2, 0, 0.49, 0), Font = Enum.Font.GothamMedium,
		TextTransparency = 1, TextStrokeTransparency = 1 })
	-- scaled text, but capped to a size that reads as subtitles rather than a poster
	local vh = if workspace.CurrentCamera then workspace.CurrentCamera.ViewportSize.Y else 720
	for t, share in { [speaker] = 0.026, [line] = 0.036, [title] = 0.085, [sub] = 0.034 } do
		local cap = Instance.new("UITextSizeConstraint")
		cap.MinTextSize = 10
		cap.MaxTextSize = math.max(12, math.floor(vh * share))
		cap.Parent = t
	end
	local skip = Instance.new("TextButton")
	skip.Name = "Skip"
	skip.Text = "Skip  >>"
	skip.Font = Enum.Font.GothamBold
	skip.TextScaled = true
	skip.TextColor3 = Color3.new(1, 1, 1)
	skip.BackgroundColor3 = Color3.new(0, 0, 0)
	skip.BackgroundTransparency = 0.4
	skip.Size = UDim2.new(0.09, 0, 0.04, 0)
	skip.Position = UDim2.new(0.89, 0, 0.93, 0)
	skip.ZIndex = 7
	skip.Visible = false
	local c = Instance.new("UICorner")
	c.Parent = skip
	skip.Parent = gui
	if preview or not RunService:IsRunning() then
		gui.Parent = game:GetService("CoreGui")
	else
		local pl = Players.LocalPlayer
		gui.Parent = pl and pl:WaitForChild("PlayerGui") or game:GetService("CoreGui")
	end
	return { gui = gui, top = top, bottom = bottom, fade = fade, flash = flash, speaker = speaker, line = line, title = title, sub = sub, skip = skip }
end

------------------------------------------------------------------------------------------------------------ play
-- opts: actors = { Name = Model|BasePart }, anchor = CFrame|Instance, preview = bool, resolveAnimation = fn(ref) -> id,
--       onEvent = fn(event), startAt = seconds
function Cutscene.play(cs, opts)
	opts = opts or {}
	cs = resolve(cs)
	local FX = fx()
	local cam = workspace.CurrentCamera
	local actors = opts.actors or {}
	local anchorCF = pivotOf(opts.anchor)
	if not anchorCF then
		for _, a in actors do
			anchorCF = pivotOf(a)
			if anchorCF then
				break
			end
		end
	end
	anchorCF = anchorCF or CFrame.new()
	anchorCF = CFrame.new(anchorCF.Position) * CFrame.fromOrientation(0, select(2, anchorCF:ToOrientation()), 0) -- yaw only

	local function actor(name)
		if not name then
			return nil
		end
		local a = actors[name]
		if a == nil then
			a = workspace:FindFirstChild(name, true)
		end
		return a
	end
	local function targetCF(name, fallback)
		local cf = pivotOf(actor(name))
		if cf then
			return CFrame.new(cf.Position) * CFrame.fromOrientation(0, select(2, cf:ToOrientation()), 0)
		end
		return fallback or anchorCF
	end
	local function v3(t, default)
		if not t then
			return default
		end
		return Vector3.new(t[1] or 0, t[2] or 0, t[3] or 0)
	end
	-- shots on a character keep the same framing on a giant boss or a tiny pet: distances scale with its height
	local sizes = {}
	local function sizeOf(name)
		if not name then
			return 1
		end
		if sizes[name] == nil then
			local a, k = actor(name), 1
			if typeof(a) == "Instance" and a:IsA("Model") and a:FindFirstChildOfClass("Humanoid") then
				local ok, ext = pcall(a.GetExtentsSize, a)
				if ok and ext then
					k = math.clamp(ext.Y / 5.2, 0.5, 8)
				end
			end
			sizes[name] = k
		end
		return sizes[name]
	end

	local shots = table.clone(cs.shots or {})
	table.sort(shots, function(a, b)
		return (a.t or 0) < (b.t or 0)
	end)
	local events = table.clone(cs.events or {})
	table.sort(events, function(a, b)
		return (a.t or 0) < (b.t or 0)
	end)
	local length = Cutscene.length(cs)

	-- camera for one shot at local progress u (0..1)
	local function shotCF(s, u)
		local e = (EASE[s.ease or "sineInOut"] or EASE.sineInOut)(math.clamp(u, 0, 1))
		local kind = s.type or "static"
		if kind == "static" or kind == "dolly" then
			-- positions are relative to the shot's target when it has one (templates), else to the cutscene anchor (camera views)
			local a = s.cf or s.from or { 0, 6, 16, 0, 3, 0 }
			local b = if kind == "dolly" then (s.to or a) else a
			local base = if s.target and actor(s.target) then targetCF(s.target) else anchorCF
			local k = if s.target then sizeOf(s.target) else 1
			local pa, la = base * (Vector3.new(a[1], a[2], a[3]) * k), base * (Vector3.new(a[4], a[5], a[6]) * k)
			local pb, lb = base * (Vector3.new(b[1], b[2], b[3]) * k), base * (Vector3.new(b[4], b[5], b[6]) * k)
			return CFrame.lookAt(pa:Lerp(pb, e), la:Lerp(lb, e))
		end
		local t = targetCF(s.target, if s.at then anchorCF * CFrame.new(v3(s.at, Vector3.zero)) else nil)
		local k = sizeOf(s.target)
		local up = Vector3.new(0, (s.height or 4) * k, 0)
		-- aim around head height by default so the subject sits in the upper-middle of frame
		local look = t.Position + Vector3.new(0, (s.lookHeight or math.min((s.height or 4) * 0.6, 2.2)) * k, 0)
		if kind == "orbit" then
			local ang = math.rad((s.from or -30) + ((s.to or 30) - (s.from or -30)) * e)
			local dir = (t * CFrame.Angles(0, ang, 0)).LookVector
			return CFrame.lookAt(t.Position + dir * (s.radius or 14) * k + up, look)
		elseif kind == "push" then
			local dist = ((s.from or 18) + ((s.to or 8) - (s.from or 18)) * e) * k
			local dir = (t * CFrame.Angles(0, math.rad(s.angle or 0), 0)).LookVector
			return CFrame.lookAt(t.Position + dir * dist + up, look)
		elseif kind == "pan" then
			local pos = if s.at then anchorCF * v3(s.at, Vector3.zero) else t.Position + t.LookVector * (s.distance or 14) * k + up
			local ang = math.rad((s.from or -25) + ((s.to or 25) - (s.from or -25)) * e)
			local base = CFrame.lookAt(pos, look)
			return CFrame.new(pos) * base.Rotation * CFrame.Angles(0, ang, 0)
		elseif kind == "follow" then
			local back = -t.LookVector * (s.distance or 10) * k + t.RightVector * (s.side or 2.5) * k
			return CFrame.lookAt(t.Position + back + up, look + t.LookVector * 4 * k)
		end
		return cam.CFrame
	end

	local function activeShot(time)
		local cur, prev = nil, nil
		for _, s in shots do
			if (s.t or 0) <= time then
				prev, cur = cur, s
			end
		end
		return cur, prev
	end

	-- state
	local saved = { type = cam.CameraType, cf = cam.CFrame, fov = cam.FieldOfView, subject = cam.CameraSubject }
	local ui = makeGui(opts.preview == true)
	local finished = Instance.new("BindableEvent")
	local running, time, fxSpeed = true, opts.startAt or 0, 1
	local nextEvent = 1
	local handles, animTracks, animators = {}, {}, {}
	local textToken = 0
	local live = RunService:IsRunning()

	local function tween(inst, props, dur)
		if dur and dur > 0 then
			TweenService:Create(inst, TweenInfo.new(dur, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props):Play()
		else
			for k, v in props do
				(inst :: any)[k] = v
			end
		end
	end
	local function letterbox(on)
		tween(ui.top, { Position = UDim2.new(0, 0, if on then 0 else -0.11, 0) }, 0.45)
		tween(ui.bottom, { Position = UDim2.new(0, 0, if on then 0.89 else 1, 0) }, 0.45)
	end
	if cs.letterbox ~= false then
		letterbox(true)
	end
	ui.skip.Visible = cs.skippable ~= false and live and not opts.preview
	-- starting part-way (previewing one shot): settle fades/letterbox to where they'd be, skip moments already over
	while nextEvent <= #events and (events[nextEvent].t or 0) < time - 0.01 do
		local e = events[nextEvent]
		if e.type == "fade" then
			local done = time >= (e.t or 0) + (e.dur or 0.5)
			ui.fade.BackgroundTransparency = 1 - (if done then (e.to or 1) else (e.from or 0))
			if not done then
				tween(ui.fade, { BackgroundTransparency = 1 - (e.to or 1) }, (e.t or 0) + (e.dur or 0.5) - time)
			end
		elseif e.type == "letterbox" then
			letterbox(e.on ~= false)
		end
		nextEvent += 1
	end

	local function fire(e)
		if opts.onEvent then
			pcall(opts.onEvent, e)
		end
		local kind = e.type
		if kind == "text" then
			textToken += 1
			local token = textToken
			-- typewriter by revealing graphemes: the whole line is laid out once, so it never re-wraps or resizes while typing
			local text = e.text or ""
			local count = utf8.len(text) or #text
			local step = e.speed or 0.025
			ui.speaker.Text = e.speaker or ""
			ui.line.Text = text
			ui.line.MaxVisibleGraphemes = 0
			task.spawn(function()
				for i = 1, count do
					if token ~= textToken or not running then
						return
					end
					ui.line.MaxVisibleGraphemes = i
					task.wait(step)
				end
				ui.line.MaxVisibleGraphemes = -1
				task.wait(math.max(0.2, (e.dur or 2.5) - count * step))
				if token == textToken then
					ui.speaker.Text, ui.line.Text = "", ""
				end
			end)
		elseif kind == "title" then
			-- lower third by default so the name never covers a face; pos = "center" for wide scenic shots
			local low = e.pos ~= "center"
			ui.title.Position = UDim2.new(0.1, 0, if low then 0.62 else 0.38, 0)
			ui.sub.Position = UDim2.new(0.2, 0, if low then 0.725 else 0.49, 0)
			ui.title.Text, ui.sub.Text = e.text or "", e.sub or ""
			tween(ui.title, { TextTransparency = 0, TextStrokeTransparency = 0.5 }, 0.5)
			tween(ui.sub, { TextTransparency = 0, TextStrokeTransparency = 0.6 }, 0.7)
			task.delay(math.max(0.6, (e.dur or 2.5) - 0.6), function()
				tween(ui.title, { TextTransparency = 1, TextStrokeTransparency = 1 }, 0.6)
				tween(ui.sub, { TextTransparency = 1, TextStrokeTransparency = 1 }, 0.6)
			end)
		elseif kind == "fade" then
			ui.fade.BackgroundTransparency = 1 - (e.from or 0)
			tween(ui.fade, { BackgroundTransparency = 1 - (e.to or 1) }, e.dur or 0.5)
		elseif kind == "flash" then
			if e.color then
				local r, g, b = string.match(e.color, "#(%x%x)(%x%x)(%x%x)")
				if r then
					ui.flash.BackgroundColor3 = Color3.fromRGB(tonumber(r, 16), tonumber(g, 16), tonumber(b, 16))
				end
			end
			ui.flash.BackgroundTransparency = 0.1
			tween(ui.flash, { BackgroundTransparency = 1 }, e.dur or 0.2)
		elseif kind == "letterbox" then
			letterbox(e.on ~= false)
		elseif kind == "shake" then
			if FX then
				FX.shake(e.amp or 0.6, e.dur or 0.4)
			end
		elseif kind == "fx" then
			if FX then
				local base = targetCF(e.at, anchorCF)
				local cf = base * CFrame.new(v3(e.offset, Vector3.zero))
				local ok, h = pcall(FX.play, e.effect, cf, { scale = e.scale, speed = fxSpeed, important = true,
					parent = if live then nil else workspace.CurrentCamera })
				if ok then
					table.insert(handles, h)
				else
					warn("[ClipForge] cutscene fx: " .. tostring(h))
				end
			end
		elseif kind == "anim" then
			local a = actor(e.actor)
			local hum = a and (a:FindFirstChildOfClass("Humanoid") or a:FindFirstChildOfClass("AnimationController"))
			if hum then
				local animator = hum:FindFirstChildOfClass("Animator")
				if not animator then
					animator = Instance.new("Animator")
					animator.Parent = hum
				end
				local id = e.animation
				if opts.resolveAnimation then
					id = opts.resolveAnimation(e.animation) or id
				end
				if id then
					local anim = Instance.new("Animation")
					anim.AnimationId = id
					local ok, track = pcall(animator.LoadAnimation, animator, anim)
					if ok then
						track.Looped = e.loop == true
						track:Play(e.fade or 0.15, 1, e.speed or 1)
						table.insert(animTracks, track)
						animators[animator] = true
					end
				end
			end
		elseif kind == "sound" then
			local s = Instance.new("Sound")
			s.SoundId = e.id or ""
			s.Volume = e.volume or 0.6
			s.Parent = workspace.CurrentCamera
			s:Play()
			s.Ended:Once(function()
				s:Destroy()
			end)
			table.insert(handles, { stop = function()
				s:Destroy()
			end })
		elseif kind == "slowmo" then
			fxSpeed = e.speed or 0.3
			for _, h in handles do
				if h.setSpeed then
					h.setSpeed(fxSpeed)
				end
			end
			task.delay(e.dur or 0.5, function()
				fxSpeed = 1
				for _, h in handles do
					if h.setSpeed then
						h.setSpeed(1)
					end
				end
			end)
		end
	end

	local blendFrom, blendStart, lastShot = nil, 0, nil
	local finish -- assigned below; step() ends this cutscene through it
	local function step(dt)
		if not running then
			return
		end
		time += dt
		while nextEvent <= #events and (events[nextEvent].t or 0) <= time do
			fire(events[nextEvent])
			nextEvent += 1
		end
		local s = activeShot(time)
		if s then
			if s ~= lastShot then
				if (s.blend or 0) > 0 then
					blendFrom, blendStart = cam.CFrame, time
				else
					blendFrom = nil
				end
				lastShot = s
			end
			local u = (time - (s.t or 0)) / math.max(s.dur or 2, 0.01)
			local cf = shotCF(s, u)
			if blendFrom then
				local k = math.clamp((time - blendStart) / s.blend, 0, 1)
				cf = blendFrom:Lerp(cf, EASE.sineInOut(k))
			end
			if FX and FX.shakeOffset then
				cf = cf * FX.shakeOffset()
			end
			cam.CameraType = Enum.CameraType.Scriptable
			cam.CFrame = cf
			local fov = s.fov or 70
			if s.fovTo then
				fov = fov + (s.fovTo - fov) * EASE.sineInOut(math.clamp(u, 0, 1))
			end
			cam.FieldOfView = fov
		end
		if not live then
			for animator in animators do
				pcall(animator.StepAnimations, animator, dt)
			end
		end
		if time >= length then
			running = false
			task.defer(function()
				finish()
			end)
		end
	end

	local conn
	local handle
	local BIND = "ClipForgeCutscene"
	if FX then
		FX._cutsceneOwnsShake = true
	end
	if live then
		RunService:BindToRenderStep(BIND, Enum.RenderPriority.Camera.Value, step)
	else
		conn = RunService.Heartbeat:Connect(step)
	end

	local done = false
	function finish()
		if done then
			return
		end
		done = true
		running = false
		if conn then
			conn:Disconnect()
		end
		if live then
			pcall(function()
				RunService:UnbindFromRenderStep(BIND)
			end)
		end
		if FX then
			FX._cutsceneOwnsShake = false
		end
		for _, h in handles do
			pcall(h.stop)
		end
		for _, tr in animTracks do
			pcall(function()
				tr:Stop(0.2)
			end)
		end
		letterbox(false)
		task.delay(0.5, function()
			ui.gui:Destroy()
		end)
		cam.CameraType = saved.type
		cam.FieldOfView = saved.fov
		if saved.subject then
			cam.CameraSubject = saved.subject
		end
		if not live then
			cam.CFrame = saved.cf
		end
		finished:Fire()
	end
	ui.skip.Activated:Connect(finish)

	handle = {
		stop = finish,
		finished = finished.Event,
		time = function()
			return time
		end,
		length = length,
	}
	return handle
end

-------------------------------------------------------------------------------------------------- templates
-- Ready-made cutscenes. who = the main actor's name, other = a second actor, effect = a ClipForge effect id/name.
Cutscene.TEMPLATES = {
	{ id = "intro", title = "Boss Intro", tags = "boss intro entrance villain enemy appear" },
	{ id = "victory", title = "Victory", tags = "victory win celebrate champion" },
	{ id = "reveal", title = "Dramatic Reveal", tags = "reveal dramatic show unveil discover" },
	{ id = "ability", title = "Ability Showcase", tags = "ability attack skill move special ultimate showcase" },
	{ id = "flyover", title = "Map Flyover", tags = "flyover establishing map world area tour overview" },
	{ id = "dialogue", title = "Dialogue", tags = "dialogue talk conversation chat story npc" },
	{ id = "defeat", title = "Defeat", tags = "defeat death die lose game over" },
}

function Cutscene.template(id: string, o)
	o = o or {}
	local who, other = o.who or "Target", o.other or "Player"
	local fxId = o.effect
	local lines = o.lines or {}
	if id == "intro" then
		return { name = o.name or "BossIntro", letterbox = true, skippable = true,
			shots = {
				{ t = 0, dur = 3, type = "orbit", target = who, radius = 22, height = 7, from = -60, to = -10, fov = 60 },
				{ t = 3, dur = 2.2, type = "push", target = who, from = 16, to = 9, height = 3.5, angle = 8, fov = 50, blend = 0.35 },
				{ t = 5.2, dur = 2.3, type = "static", target = who, cf = { 3, -0.8, -7.5, 0, 2, 0 }, fov = 45 }, -- low hero angle
			},
			events = {
				{ t = 0, type = "fade", from = 1, to = 0, dur = 0.8 },
				{ t = 3.4, type = "text", speaker = o.speaker or who, text = lines[1] or "So... you finally made it.", dur = 2.2 },
				{ t = 5.3, type = "fx", effect = fxId or "shockwave", at = who },
				{ t = 5.3, type = "shake", amp = 0.9, dur = 0.5 },
				{ t = 5.6, type = "title", text = string.upper(o.title or who), sub = o.sub or "Boss Battle", dur = 1.9 },
				{ t = 7.0, type = "fade", from = 0, to = 1, dur = 0.5 },
			} }
	elseif id == "victory" then
		return { name = o.name or "Victory", letterbox = true,
			shots = {
				{ t = 0, dur = 4.5, type = "orbit", target = who, radius = 11, height = 3, from = 150, to = 230, fov = 55 },
				{ t = 4.5, dur = 1.5, type = "push", target = who, from = 9, to = 6.5, height = 2.6, angle = 10, fov = 50, blend = 0.4 },
			},
			events = {
				{ t = 0.2, type = "fx", effect = fxId or "confetti", at = who, offset = { 0, 1, 0 } },
				{ t = 0.6, type = "fx", effect = "firework", at = who, offset = { 6, 0, -8 } },
				{ t = 1.0, type = "title", text = string.upper(o.title or "Victory"), sub = o.sub or "", dur = 3 },
				{ t = 5.6, type = "fade", from = 0, to = 1, dur = 0.4 },
			} }
	elseif id == "reveal" then
		return { name = o.name or "Reveal", letterbox = true,
			shots = {
				{ t = 0, dur = 4, type = "push", target = who, from = 40, to = 14, height = 5, angle = 0, fov = 45, ease = "cubicInOut" },
				{ t = 4, dur = 2.5, type = "orbit", target = who, radius = 13, height = 4, from = 0, to = 35, fov = 50 },
			},
			events = {
				{ t = 0, type = "fade", from = 1, to = 0, dur = 1.2 },
				{ t = 3.9, type = "flash", dur = 0.25 },
				{ t = 3.9, type = "fx", effect = fxId or "holybeam", at = who },
				{ t = 4.2, type = "title", text = string.upper(o.title or who), sub = o.sub or "", dur = 2.2 },
			} }
	elseif id == "ability" then
		return { name = o.name or "AbilityShowcase", letterbox = true,
			shots = {
				{ t = 0, dur = 1.2, type = "follow", target = who, distance = 9, height = 3, side = 2.5, fov = 65 },
				{ t = 1.2, dur = 1.3, type = "static", target = who, cf = { 8, 1.5, -5, 0, 1.5, -3 }, fov = 50 },
				{ t = 2.5, dur = 2.5, type = "orbit", target = who, radius = 16, height = 5, from = 20, to = 70, fov = 60, blend = 0.3 },
			},
			events = {
				{ t = 1.25, type = "slowmo", speed = 0.35, dur = 0.6 },
				{ t = 1.3, type = "fx", effect = fxId or "slash", at = who },
				{ t = 1.35, type = "shake", amp = 0.6, dur = 0.35 },
				{ t = 1.35, type = "flash", dur = 0.12 },
				{ t = 2.6, type = "title", text = string.upper(o.title or "Special Move"), dur = 2 },
			} }
	elseif id == "flyover" then
		return { name = o.name or "Flyover", letterbox = true,
			shots = {
				{ t = 0, dur = 6, type = "orbit", target = who, radius = 70, height = 35, from = 0, to = 90, fov = 60, lookHeight = 0, ease = "linear" },
				{ t = 6, dur = 3, type = "push", target = who, from = 60, to = 30, height = 18, angle = 90, fov = 55, lookHeight = 2, blend = 0.6 },
			},
			events = {
				{ t = 0, type = "fade", from = 1, to = 0, dur = 1 },
				{ t = 1.5, type = "title", text = string.upper(o.title or "Welcome"), sub = o.sub or "", dur = 3.5, pos = "center" },
				{ t = 8.4, type = "fade", from = 0, to = 1, dur = 0.6 },
			} }
	elseif id == "dialogue" then
		local ev, sh, t = {}, {}, 0
		local said = if #lines > 0 then lines else { "Have you heard the rumours?", "About the old temple? Everyone has.", "Then you know what we must do." }
		for i, line in said do
			local speaker = if i % 2 == 1 then who else other
			local listener = if i % 2 == 1 then other else who
			local dur = math.clamp(#line * 0.06 + 1.2, 2, 5)
			table.insert(sh, { t = t, dur = dur, type = "static", target = listener, cf = { -2.2, 1.6, 3.5, 0, 1.4, -6 }, fov = 50 })
			table.insert(ev, { t = t + 0.1, type = "text", speaker = speaker, text = line, dur = dur - 0.2 })
			t += dur
		end
		return { name = o.name or "Dialogue", letterbox = true, shots = sh, events = ev }
	elseif id == "defeat" then
		return { name = o.name or "Defeat", letterbox = true,
			shots = { { t = 0, dur = 4, type = "push", target = who, from = 14, to = 6, height = 8, angle = 20, lookHeight = 0.5, fov = 55 } },
			events = {
				{ t = 0.2, type = "fx", effect = fxId or "defeat", at = who },
				{ t = 1.2, type = "title", text = string.upper(o.title or "Defeated"), sub = o.sub or "", dur = 2.5 },
				{ t = 3.4, type = "fade", from = 0, to = 1, dur = 0.6 },
			} }
	end
	return Cutscene.template("intro", o)
end

-- Text -> cutscene: picks the closest template, pulls quoted lines and an effect name from the words.
function Cutscene.fromPrompt(prompt: string, o)
	o = table.clone(o or {})
	prompt = string.gsub(string.gsub(prompt or "", "\u{201C}", "\""), "\u{201D}", "\"") -- phone-style quotes
	local text = " " .. string.lower(prompt or "") .. " "
	local best, bestScore = "intro", 0
	for _, t in Cutscene.TEMPLATES do
		local s = 0
		for word in string.gmatch(t.tags, "%a+") do
			if string.find(text, "%f[%a]" .. word .. "%f[%A]") then
				s += #word
			end
		end
		if s > bestScore then
			best, bestScore = t.id, s
		end
	end
	o.lines = o.lines or {}
	for quoted in string.gmatch(prompt or "", "\"([^\"]+)\"") do
		table.insert(o.lines, quoted)
	end
	local FX = fx()
	if FX and not o.effect then
		local e, score = FX.Library.match(prompt or "")
		if e and score >= 2 then
			o.effect = e.id
		end
	end
	return Cutscene.template(best, o)
end

return Cutscene
