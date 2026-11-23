-- ClipForge Models tab: weapons and props built in code, matched to your effects; attach to rigs or make Tools.

local Tab = {}

function Tab.build(page, ctx)
	local UI, ModelKit, Installer = ctx.UI, ctx.ModelKit, ctx.Installer
	local Selection = game:GetService("Selection")
	local cfg = { type = "sword", style = "steel", glow = nil, scale = 1 }
	local last = nil

	local card = UI.card(page, "Make a model")
	local promptBox = UI.input(card, "glowing purple katana · golden greatsword · crystal staff · meteor rock")
	local types = {}
	local labels = {}
	for _, t in ModelKit.TYPES do
		table.insert(types, t.id)
		labels[t.id] = t.title
	end
	local typeChips = UI.chips(card, types, "sword", function(v)
		cfg.type = v
	end, { labels = labels, columns = 3 })
	UI.dim(card, "Style", 12)
	local styleSeg = UI.segmented(card, { "steel", "dark", "gold", "crystal", "energy", "wood" }, "steel", function(v)
		cfg.style = v
	end, { steel = "Steel", dark = "Dark", gold = "Gold", crystal = "Crystal", energy = "Energy", wood = "Wood" })
	UI.dim(card, "Glow colour (blank = none)", 12)
	local glowRow = UI.row(card, 6, 26)
	local glowBox = UI.input(glowRow, "#9B3CFF", "", { Size = UDim2.new(0.5, -4, 1, 0) })
	for _, hex in { "#9B3CFF", "#22E6FF", "#FFC530", "#FF2A2A", "#2EE85A" } do
		local c = ctx.Recolor.hexToColor(hex)
		UI.swatch(glowRow, c, 24, function()
			glowBox.Text = hex
		end)
	end
	UI.dim(card, "Size", 12)
	local sizeSeg = UI.segmented(card, { "0.6", "0.8", "1", "1.3", "1.6", "2" }, "1", function(v)
		cfg.scale = tonumber(v)
	end)

	local function readGlow()
		local hex = string.upper((string.gsub(glowBox.Text or "", "%s", "")))
		if hex == "" then
			return nil
		end
		if string.sub(hex, 1, 1) ~= "#" then
			hex = "#" .. hex
		end
		return if ctx.Recolor.hexToColor(hex) then hex else nil
	end

	local lastOrigin = nil
	local function build()
		cfg.glow = readGlow()
		local model
		ctx.record("build model", function()
			model = ModelKit.build(cfg)
			local origin = ctx.previewOrigin(true)
			-- building again in the same spot: stand the new one beside the last one, never on top of it
			if last and last.Parent == workspace and lastOrigin and (lastOrigin.Position - origin.Position).Magnitude < 6 then
				local gap = (last:GetExtentsSize().X + model:GetExtentsSize().X) / 2 + 1.5
				origin = lastOrigin * CFrame.new(gap, 0, 0)
			end
			lastOrigin = origin
			local isProp = model:GetAttribute("ClipForgeKind") == "prop"
			local lift = if isProp then 0 else 3
			model:PivotTo(origin * CFrame.new(0, lift, 0) * (if isProp then CFrame.identity else CFrame.Angles(0, 0, math.rad(-20))))
			if not isProp then
				for _, p in model:GetDescendants() do
					if p:IsA("BasePart") then
						p.Anchored = true -- displayed in the world: hold still until attached
					end
				end
			end
			model.Parent = workspace
		end)
		last = model
		Selection:Set({ model })
		ctx.setStatus("Built " .. model.Name .. " (" .. #model:GetDescendants() .. " parts and welds)", UI.OK)
		return model
	end

	local r1 = UI.row(card, 6, 32)
	UI.button(r1, "Make from text", "secondary", function()
		local p = ModelKit.parse(promptBox.Text)
		cfg.type, cfg.style, cfg.scale = p.type, p.style, p.scale
		typeChips.set(p.type)
		styleSeg.set(p.style)
		glowBox.Text = p.glow or ""
		build()
	end, 130)
	UI.button(r1, "Build", "primary", build, 90)

	local use = UI.card(page, "Use it")
	UI.dim(use, "Select a model built here (or the last one) and:", 12)
	local function target()
		for _, s in Selection:Get() do
			local m = if s:IsA("Model") then s else s:FindFirstAncestorOfClass("Model")
			if m and m:GetAttribute("ClipForgeModel") then
				return m
			end
		end
		return last
	end
	local r2 = UI.row(use, 6, 30)
	UI.button(r2, "Attach to rig", "secondary", function()
		local m = target()
		if not m then
			ctx.setStatus("Build or select a ClipForge model first.", UI.WARN)
			return
		end
		local rig = ctx.currentRig(true)
		ctx.record("attach model", function()
			for _, c in rig:GetChildren() do
				if c:IsA("Model") and c:GetAttribute("ClipForgeHeld") and c:GetAttribute("ClipForgeKind") == m:GetAttribute("ClipForgeKind") then
					c:Destroy()
				end
			end
			local copy, err = ModelKit.attach(m, rig)
			if not copy then
				error(err)
			end
		end)
		ctx.setStatus("Attached to " .. rig.Name .. ": it follows the hand in animation previews.", UI.OK)
	end, 110)
	UI.button(r2, "Make Tool", "secondary", function()
		local m = target()
		if not m then
			ctx.setStatus("Build or select a ClipForge model first.", UI.WARN)
			return
		end
		local tool
		ctx.record("make tool", function()
			tool = ModelKit.toTool(m)
			for _, p in tool:GetDescendants() do
				if p:IsA("BasePart") then
					p.Anchored = false
				end
			end
			tool.Parent = game:GetService("StarterPack")
		end)
		Selection:Set({ tool })
		ctx.setStatus("Tool added to StarterPack: players spawn with " .. tool.Name .. ".", UI.OK)
	end, 100)
	UI.button(r2, "Try with animation", "secondary", function()
		local m = target()
		if not m then
			ctx.setStatus("Build or select a ClipForge weapon first.", UI.WARN)
			return
		end
		local kfs = ctx.state.currentKfs
		if not kfs or not kfs.Parent then
			ctx.setStatus("Play an animation in the Anim tab first: the tool swings the last one you played.", UI.WARN)
			return
		end
		ctx.tryInGame(kfs, m)
	end, 140)
	UI.button(r2, "Save", "secondary", function()
		local m = target()
		if not m then
			return
		end
		local saved
		ctx.record("save model", function()
			saved = Installer.saveModel(m)
		end)
		Selection:Set({ saved })
		ctx.setStatus("Saved " .. saved:GetFullName(), UI.OK)
	end, 70)
	UI.dim(use, "Weapons are welded around a Grip point; Tools use it as their grip. Try with animation makes a tool that holds this weapon and plays the last animation you played (with its effects) when clicked: press Play to try it. Everything is plain parts: recolour or edit freely.", 12)
end

return Tab
