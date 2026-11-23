-- ClipForge Cutscenes tab: build a cutscene from a template, text or your own camera views; preview; save to the game.

local Tab = {}

function Tab.build(page, ctx)
	local UI, Cutscene, Installer = ctx.UI, ctx.Cutscene, ctx.Installer
	local Selection = game:GetService("Selection")
	local cs = nil -- the cutscene being edited
	local actorModel = nil
	local handle = nil

	local function trim(s)
		return (string.gsub(s or "", "^%s*(.-)%s*$", "%1"))
	end

	local function actorName()
		return if actorModel then actorModel.Name else "Target"
	end

	-- the filmed model answers to its own name, to "Target" (bot and template default) and to the cutscene's `who`
	local function actors()
		local map = {}
		if actorModel then
			map[actorModel.Name] = actorModel
			map.Target = actorModel
			if cs and cs.who then
				map[cs.who] = actorModel
			end
		end
		return map
	end

	local function anchorCF()
		if actorModel then
			local hrp = actorModel:FindFirstChild("HumanoidRootPart")
			local cf = if hrp then hrp.CFrame else actorModel:GetPivot()
			return CFrame.new(cf.Position) * CFrame.fromOrientation(0, select(2, cf:ToOrientation()), 0)
		end
		return ctx.previewOrigin()
	end

	-------------------------------------------------------------------------------------------------- make
	local make = UI.card(page, "Make a cutscene")
	local actorLabel = UI.dim(make, "", 12)
	local function showActor()
		actorLabel.Text = if actorModel then ("Films <b>" .. actorModel.Name .. "</b> (select a model and press Use selection to change)")
			else "Select the character/model to film, then press Use selection (or it films where the camera looks)."
	end
	local ar = UI.row(make, 6, 28)
	UI.button(ar, "Use selection", "secondary", function()
		for _, s in Selection:Get() do
			local m = if s:IsA("Model") then s elseif s:IsA("BasePart") then (s:FindFirstAncestorOfClass("Model") or s) else nil
			if m then
				actorModel = m
				break
			end
		end
		showActor()
	end, 120)
	showActor()
	local promptBox = UI.input(make, "boss intro with \"You dare challenge me?\" · victory · map flyover")
	local templates, labels = {}, {}
	for _, t in Cutscene.TEMPLATES do
		table.insert(templates, t.id)
		labels[t.id] = t.title
	end
	local tpl = UI.chips(make, templates, "intro", nil, { labels = labels, columns = 3 })

	------------------------------------------------------------------------------------------------- shots
	local shotsCard = UI.card(page, "Shots")
	local shotList = UI.frame(shotsCard)
	UI.list(shotList, 6)
	local eventsCard = UI.card(page, "Events")
	local eventList = UI.frame(eventsCard)
	UI.list(eventList, 4)

	local refresh
	local function cameraShot(t, dur)
		-- the current Studio view, stored relative to the cutscene anchor
		local cam = workspace.CurrentCamera.CFrame
		local a = anchorCF()
		local p = a:PointToObjectSpace(cam.Position)
		local l = a:PointToObjectSpace(cam.Position + cam.LookVector * 20)
		return { t = t, dur = dur, type = "static", cf = { p.X, p.Y, p.Z, l.X, l.Y, l.Z }, fov = math.floor(workspace.CurrentCamera.FieldOfView) }
	end

	local function retime()
		local t = 0
		for _, s in cs.shots do
			s.t = t
			t += s.dur or 2
		end
	end

	function refresh()
		for _, l in { shotList, eventList } do
			for _, c in l:GetChildren() do
				if c:IsA("GuiObject") then
					c:Destroy()
				end
			end
		end
		UI.prune()
		if not cs then
			UI.dim(shotList, "Make one from a template or text above, or add shots from your camera view.", 12)
			return
		end
		for i, s in cs.shots do
			local row = UI.row(shotList, 5, 28)
			UI.label(row, string.format("<b>%d</b> %s", i, s.type), { Size = UDim2.new(0, 84, 1, 0), AutomaticSize = Enum.AutomaticSize.None,
				TextYAlignment = Enum.TextYAlignment.Center, TextSize = 13 }).Parent = row
			local dur = UI.input(row, "s", string.format("%.1f", s.dur or 2), { Size = UDim2.new(0, 46, 1, 0) })
			dur.FocusLost:Connect(function()
				s.dur = math.clamp(tonumber(dur.Text) or s.dur or 2, 0.3, 30)
				retime()
				refresh()
			end)
			UI.button(row, "View", "secondary", function()
				local shot = cameraShot(s.t, s.dur)
				for k, v in shot do
					s[k] = v
				end
				s.target = nil
				refresh()
			end, 54)
			UI.button(row, "Look", "ghost", function()
				local h = Cutscene.play({ shots = { s }, events = {}, letterbox = false }, { anchor = anchorCF(), actors = actors(), preview = true })
				task.delay(math.min(s.dur or 2, 6), h.stop)
			end, 44)
			UI.button(row, "✕", "ghost", function()
				table.remove(cs.shots, i)
				retime()
				refresh()
			end, 28)
		end
		for i, e in cs.events do
			local row = UI.row(eventList, 5, 24)
			local what = e.text or e.effect or e.animation or (e.type == "shake" and ("amp " .. tostring(e.amp))) or ""
			UI.label(row, string.format("<b>%.1fs</b> %s  <font transparency=\"0.4\">%s</font>", e.t or 0, e.type, what),
				{ Size = UDim2.new(1, -36, 1, 0), AutomaticSize = Enum.AutomaticSize.None, TextYAlignment = Enum.TextYAlignment.Center,
					TextSize = 12, TextTruncate = Enum.TextTruncate.AtEnd }).Parent = row
			UI.button(row, "✕", "ghost", function()
				table.remove(cs.events, i)
				refresh()
			end, 28)
		end
	end

	local function makeIt(fromText)
		local o = { who = actorName(), name = nil }
		if fromText and trim(promptBox.Text) ~= "" then
			cs = Cutscene.fromPrompt(promptBox.Text, o)
		else
			cs = Cutscene.template(tpl.get(), o)
		end
		for _, s in cs.shots do
			if s.target == nil and s.type ~= "static" and s.type ~= "dolly" then
				s.target = actorName()
			end
		end
		refresh()
		ctx.setStatus("Cutscene ready: " .. #cs.shots .. " shots, " .. #cs.events .. " events. Preview it below.", UI.OK)
	end
	local mr = UI.row(make, 6, 32)
	UI.button(mr, "From template", "secondary", function()
		makeIt(false)
	end, 120)
	UI.button(mr, "From text", "primary", function()
		makeIt(true)
	end, 100)

	local sr = UI.row(shotsCard, 6, 30)
	UI.button(sr, "+ Shot from view", "secondary", function()
		cs = cs or { name = "MyCutscene", letterbox = true, skippable = true, shots = {}, events = {} }
		local last = cs.shots[#cs.shots]
		local t = if last then (last.t or 0) + (last.dur or 2) else 0
		table.insert(cs.shots, cameraShot(t, 2.5))
		refresh()
	end, 140)
	UI.button(sr, "Make last a dolly to view", "ghost", function()
		if not cs or #cs.shots == 0 then
			return
		end
		local last = cs.shots[#cs.shots]
		local to = cameraShot(last.t, last.dur)
		last.type = "dolly"
		last.from = last.cf
		last.to = to.cf
		refresh()
	end, 170)

	-- quick events at the time in the box
	local er = UI.row(eventsCard, 5, 28)
	local tBox = UI.input(er, "time s", "1", { Size = UDim2.new(0, 56, 1, 0) })
	local textBox = UI.input(er, "line / effect id / title", "", { Size = UDim2.new(1, -62, 1, 0) })
	local er2 = UI.row(eventsCard, 5, 28)
	local function addEvent(e)
		cs = cs or { name = "MyCutscene", letterbox = true, skippable = true, shots = {}, events = {} }
		e.t = tonumber(tBox.Text) or 0
		table.insert(cs.events, e)
		table.sort(cs.events, function(a, b)
			return (a.t or 0) < (b.t or 0)
		end)
		refresh()
	end
	UI.button(er2, "Line", "secondary", function()
		addEvent({ type = "text", text = textBox.Text, speaker = actorName(), dur = 2.5 })
	end, 54)
	UI.button(er2, "VFX", "secondary", function()
		local id = trim(textBox.Text)
		addEvent({ type = "fx", effect = if id ~= "" then id else "shockwave", at = actorName() })
	end, 50)
	UI.button(er2, "Shake", "secondary", function()
		addEvent({ type = "shake", amp = 0.7, dur = 0.4 })
	end, 56)
	UI.button(er2, "Title", "secondary", function()
		addEvent({ type = "title", text = textBox.Text, dur = 2.5 })
	end, 50)
	UI.button(er2, "Fade", "secondary", function()
		addEvent({ type = "fade", from = 0, to = 1, dur = 0.6 })
	end, 50)

	---------------------------------------------------------------------------------------------- play / save
	local playCard = UI.card(page, "Preview & save")
	local nameBox = UI.input(playCard, "Cutscene name", "")
	local pr = UI.row(playCard, 6, 32)
	UI.button(pr, "Preview", "primary", function()
		if not cs then
			makeIt(trim(promptBox.Text) ~= "")
		end
		if handle then
			handle.stop()
		end
		handle = Cutscene.play(cs, { anchor = anchorCF(), actors = actors(), preview = true,
			resolveAnimation = ctx.resolveAnimation })
	end, 100)
	UI.button(pr, "Stop", "secondary", function()
		if handle then
			handle.stop()
			handle = nil
		end
	end, 70)
	UI.button(playCard, "Save to game", "secondary", function()
		if not cs then
			return
		end
		local n = trim(nameBox.Text)
		if n ~= "" then
			cs.name = n
		end
		local mod
		ctx.record("save cutscene", function()
			mod = Installer.saveCutscene(cs)
		end)
		Selection:Set({ mod })
		ctx.setStatus("Saved " .. mod:GetFullName(), UI.OK)
	end)
	UI.dim(playCard, "In a LocalScript:\n<font face=\"RobotoMono\">require(game.ReplicatedStorage.ClipForge.Cutscene).play(\"Name\", { actors = { Target = workspace.Boss } })</font>\nPositions are relative to the filmed model, so the same cutscene works anywhere.", 12)

	ctx.loadCutscene = function(config, model)
		cs = config
		actorModel = model or actorModel
		if config.name then
			nameBox.Text = config.name
		end
		showActor()
		refresh()
	end
	ctx.state.loadCutscene = ctx.loadCutscene -- bot-made cutscenes open here, ready to preview
	refresh()
end

return Tab
