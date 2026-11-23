-- ClipForge ModelKit: weapons and props built from parts in code (no uploads), styled to match your effects.
--
--   local model = ModelKit.build({ type = "katana", style = "dark", glow = "#9B3CFF", scale = 1 })
--   ModelKit.attach(model, rig)        -- weld it into the rig's hand (previews swing it with the animation)
--   local tool = ModelKit.toTool(model) -- a Tool players can equip
--
-- Weapons are built around their grip: origin = where the hand holds it, +Y = towards the tip/head, +X = edge
-- direction, +Z = thickness. Props stand on the ground at their origin.

local ModelKit = {}

local function C(v)
	if typeof(v) == "Color3" then
		return v
	end
	local r, g, b = string.match(tostring(v or ""), "#(%x%x)(%x%x)(%x%x)")
	if r then
		return Color3.fromRGB(tonumber(r, 16), tonumber(g, 16), tonumber(b, 16))
	end
	return Color3.new(1, 1, 1)
end

ModelKit.STYLES = {
	steel = { metal = "#C9CED6", trim = "#C8A24A", grip = "#3A2A22", wood = "#6B4A2F", stone = "#7E848C", material = "Metal" },
	dark = { metal = "#3B3D45", trim = "#7A3FA8", grip = "#16161A", wood = "#2A2228", stone = "#3A3940", material = "Metal" },
	gold = { metal = "#E8C15A", trim = "#FFF0B0", grip = "#5A2A10", wood = "#7A4A22", stone = "#C9B27A", material = "Metal" },
	crystal = { metal = "#BFE8FF", trim = "#FFFFFF", grip = "#2A3A52", wood = "#3A4A62", stone = "#9FC4DA", material = "Glass" },
	energy = { metal = "#00E5FF", trim = "#E8F8FF", grip = "#1C2230", wood = "#1C2230", stone = "#4A5A6A", material = "Neon" },
	wood = { metal = "#A9AEB6", trim = "#8A6A3A", grip = "#4A3220", wood = "#7A5534", stone = "#8A8F96", material = "Metal" },
}

ModelKit.TYPES = {
	{ id = "sword", title = "Sword", kind = "weapon", tags = "sword longsword blade knight" },
	{ id = "katana", title = "Katana", kind = "weapon", tags = "katana samurai sword blade curved" },
	{ id = "greatsword", title = "Greatsword", kind = "weapon", tags = "greatsword claymore big sword zweihander" },
	{ id = "dagger", title = "Dagger", kind = "weapon", tags = "dagger knife kunai short blade" },
	{ id = "axe", title = "Axe", kind = "weapon", tags = "axe battleaxe hatchet" },
	{ id = "spear", title = "Spear", kind = "weapon", tags = "spear lance pike trident halberd" },
	{ id = "staff", title = "Staff", kind = "weapon", tags = "staff mage wizard rod" },
	{ id = "wand", title = "Wand", kind = "weapon", tags = "wand magic stick" },
	{ id = "scythe", title = "Scythe", kind = "weapon", tags = "scythe reaper death sickle" },
	{ id = "hammer", title = "Hammer", kind = "weapon", tags = "hammer warhammer mallet maul" },
	{ id = "shield", title = "Shield", kind = "shield", tags = "shield buckler guard" },
	{ id = "orb", title = "Magic Orb", kind = "prop", tags = "orb sphere ball magic" },
	{ id = "crystals", title = "Crystal Cluster", kind = "prop", tags = "crystal crystals gem cluster ore" },
	{ id = "rock", title = "Rock", kind = "prop", tags = "rock boulder stone" },
	{ id = "meteor", title = "Meteor", kind = "prop", tags = "meteor asteroid comet rock lava" },
	{ id = "portal", title = "Portal", kind = "prop", tags = "portal gate ring rift" },
	{ id = "totem", title = "Rune Totem", kind = "prop", tags = "totem rune stone monolith obelisk pillar" },
}
ModelKit.byId = {}
for _, t in ModelKit.TYPES do
	ModelKit.byId[t.id] = t
end

------------------------------------------------------------------------------------------------------- builder
local B = {}
B.__index = B

local function newBuilder(name, isProp)
	local model = Instance.new("Model")
	model.Name = name
	return setmetatable({ model = model, prop = isProp, parts = {} }, B)
end

function B:part(name, size, cf, color, material, shape)
	local p
	if shape == "Wedge" then
		p = Instance.new("WedgePart")
	else
		p = Instance.new("Part")
		p.Shape = Enum.PartType[shape or "Block"]
	end
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = C(color)
	local ok = pcall(function()
		p.Material = Enum.Material[material or "SmoothPlastic"]
	end)
	if not ok then
		p.Material = Enum.Material.SmoothPlastic
	end
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.CastShadow = material ~= "Neon"
	p.Parent = self.model
	table.insert(self.parts, p)
	return p
end

-- cylinder whose axis runs along the given CFrame's Y axis
function B:cyl(name, length, diameter, cf, color, material)
	return self:part(name, Vector3.new(length, diameter, diameter), cf * CFrame.Angles(0, 0, math.rad(90)), color, material, "Cylinder")
end

-- pointed tip: two wedges forming an isosceles triangle in the XY plane; base centre at cf, point towards +Y
function B:tip(name, width, height, thick, cf, color, material)
	local half = width / 2
	self:part(name .. "R", Vector3.new(thick, height, half), cf * CFrame.new(half / 2, height / 2, 0) * CFrame.Angles(0, math.rad(-90), 0), color, material, "Wedge")
	self:part(name .. "L", Vector3.new(thick, height, half), cf * CFrame.new(-half / 2, height / 2, 0) * CFrame.Angles(0, math.rad(90), 0), color, material, "Wedge")
end

-- faceted crystal or rock from the effect runtime's Crystal builder (wedge facets with their own shading)
function B:crystal(kind, cf, size, palette, seed)
	local ok, VT = pcall(function()
		return require(script.Parent:WaitForChild("VFXTimeline"))
	end)
	if not ok then
		return self:part("Crystal", size, cf * CFrame.new(0, size.Y / 2, 0), palette.body, "Glass")
	end
	local holder = Instance.new("Folder")
	local c = VT.Crystal.new(kind, { seed = seed or 1, palette = palette, parent = holder, backend = "wedge" })
	c:set(cf, size)
	for _, w in (c.model and c.model:GetChildren() or {}) do
		if w:IsA("BasePart") and w.Transparency < 1 then
			w.CastShadow = true
			w.Parent = self.model
			table.insert(self.parts, w)
		end
	end
	holder:Destroy()
end

-- Finish: PrimaryPart, grip attachment, welds (weapons) or anchoring (props), scale.
function B:finish(primary, grip: CFrame?, scale: number?)
	local model = self.model
	model.PrimaryPart = primary
	-- pivot = the grip point (weapons) or the ground centre (props), upright: PivotTo places them as you'd expect.
	-- (With a PrimaryPart, a model's pivot lives in that part's PivotOffset; WorldPivot would be ignored.)
	primary.PivotOffset = primary.CFrame:Inverse()
	if self.prop then
		for _, p in self.parts do
			p.Anchored = true
			p.CanCollide = p.Transparency < 0.9 and p.Material ~= Enum.Material.Neon and p.Material ~= Enum.Material.ForceField
		end
	else
		primary.Name = "Handle"
		for _, p in self.parts do
			p.Anchored = false
			p.CanCollide = false
			p.CanTouch = p == primary
			p.Massless = true
			if p ~= primary then
				local w = Instance.new("WeldConstraint")
				w.Part0, w.Part1 = primary, p
				w.Parent = p
			end
		end
		local a = Instance.new("Attachment")
		a.Name = "Grip"
		a.CFrame = primary.CFrame:ToObjectSpace(grip or CFrame.identity)
		a.Parent = primary
	end
	if scale and scale ~= 1 then
		pcall(function()
			model:ScaleTo(scale)
		end)
	end
	model:SetAttribute("ClipForgeModel", true)
	return model
end

---------------------------------------------------------------------------------------------------- weapons
local W = {}

function W.sword(b, s, glow, opts)
	local mat = s.material
	local handle = b:cyl("Grip", 1.1, 0.24, CFrame.new(0, 0, 0), s.grip, "Fabric")
	b:part("Pommel", Vector3.new(0.36, 0.36, 0.36), CFrame.new(0, -0.66, 0), s.trim, "Metal", "Ball")
	b:part("Guard", Vector3.new(1.5, 0.2, 0.32), CFrame.new(0, 0.65, 0), s.trim, "Metal")
	b:part("GuardL", Vector3.new(0.24, 0.24, 0.24), CFrame.new(-0.78, 0.65, 0), s.trim, "Metal", "Ball")
	b:part("GuardR", Vector3.new(0.24, 0.24, 0.24), CFrame.new(0.78, 0.65, 0), s.trim, "Metal", "Ball")
	local L = opts.length or 3.4
	b:part("Blade", Vector3.new(0.36, L, 0.08), CFrame.new(0, 0.75 + L / 2, 0), s.metal, mat)
	b:tip("Tip", 0.36, 0.55, 0.08, CFrame.new(0, 0.75 + L, 0), s.metal, mat)
	if glow then
		b:part("Fuller", Vector3.new(0.08, L * 0.85, 0.1), CFrame.new(0, 0.75 + L * 0.45, 0), glow, "Neon")
	end
	return handle
end

function W.greatsword(b, s, glow)
	local handle = b:cyl("Grip", 1.6, 0.28, CFrame.new(0, -0.1, 0), s.grip, "Fabric")
	b:part("Pommel", Vector3.new(0.46, 0.46, 0.46), CFrame.new(0, -1, 0), s.trim, "Metal", "Ball")
	b:part("Guard", Vector3.new(2.3, 0.3, 0.42), CFrame.new(0, 0.85, 0), s.trim, "Metal")
	b:tip("GuardTipL", 0.42, 0.35, 0.3, CFrame.new(-1.15, 0.85, 0) * CFrame.Angles(0, 0, math.rad(90)), s.trim, "Metal")
	b:tip("GuardTipR", 0.42, 0.35, 0.3, CFrame.new(1.15, 0.85, 0) * CFrame.Angles(0, 0, math.rad(-90)), s.trim, "Metal")
	local L = 4.6
	b:part("Blade", Vector3.new(0.72, L, 0.12), CFrame.new(0, 1 + L / 2, 0), s.metal, s.material)
	b:tip("Tip", 0.72, 0.9, 0.12, CFrame.new(0, 1 + L, 0), s.metal, s.material)
	if glow then
		b:part("Rune", Vector3.new(0.14, L * 0.8, 0.14), CFrame.new(0, 1 + L * 0.45, 0), glow, "Neon")
	end
	return handle
end

function W.dagger(b, s, glow)
	local handle = b:cyl("Grip", 0.7, 0.2, CFrame.new(0, 0, 0), s.grip, "Fabric")
	b:part("Pommel", Vector3.new(0.26, 0.26, 0.26), CFrame.new(0, -0.42, 0), s.trim, "Metal", "Ball")
	b:part("Guard", Vector3.new(0.8, 0.14, 0.2), CFrame.new(0, 0.42, 0), s.trim, "Metal")
	b:part("Blade", Vector3.new(0.26, 1.3, 0.06), CFrame.new(0, 0.49 + 0.65, 0), s.metal, s.material)
	b:tip("Tip", 0.26, 0.4, 0.06, CFrame.new(0, 0.49 + 1.3, 0), s.metal, s.material)
	if glow then
		b:part("Edge", Vector3.new(0.05, 1.2, 0.08), CFrame.new(0.13, 1.1, 0), glow, "Neon")
	end
	return handle
end

function W.katana(b, s, glow)
	local handle = b:cyl("Grip", 1.6, 0.2, CFrame.new(0, -0.1, 0), s.grip, "Fabric")
	for i = 0, 3 do -- wrap diamonds
		b:part("Wrap" .. i, Vector3.new(0.12, 0.12, 0.215), CFrame.new(0, -0.7 + i * 0.36, 0) * CFrame.Angles(0, 0, math.rad(45)), s.trim, "Fabric")
	end
	b:part("Kashira", Vector3.new(0.22, 0.12, 0.22), CFrame.new(0, -0.94, 0), s.trim, "Metal")
	b:cyl("Tsuba", 0.1, 0.62, CFrame.new(0, 0.75, 0), s.trim, "Metal")
	b:part("Habaki", Vector3.new(0.18, 0.2, 0.1), CFrame.new(0, 0.9, 0), s.trim, "Metal")
	-- curved blade: segments along a gentle arc bending back (-X)
	local segs, segL, bend = 7, 0.56, math.rad(2.4)
	local cf = CFrame.new(0, 1.0, 0)
	for i = 1, segs do
		local w = 0.22 - i * 0.008
		b:part("Blade" .. i, Vector3.new(w, segL, 0.06), cf * CFrame.new(0, segL / 2, 0), s.metal, s.material)
		if glow then
			b:part("Hamon" .. i, Vector3.new(0.05, segL, 0.075), cf * CFrame.new(w / 2 - 0.02, segL / 2, 0), glow, "Neon")
		end
		cf = cf * CFrame.new(0, segL, 0) * CFrame.Angles(0, 0, bend)
	end
	b:tip("Kissaki", 0.17, 0.32, 0.06, cf * CFrame.Angles(0, 0, bend), s.metal, s.material)
	return handle
end

function W.axe(b, s, glow)
	local handle = b:cyl("Shaft", 4.2, 0.22, CFrame.new(0, 1.3, 0), s.wood, "Wood")
	b:cyl("Band", 0.25, 0.28, CFrame.new(0, 2.6, 0), s.trim, "Metal")
	b:part("Head", Vector3.new(1.2, 1.1, 0.14), CFrame.new(0.65, 3.05, 0), s.metal, s.material)
	b:part("Edge", Vector3.new(0.18, 1.6, 0.16), CFrame.new(1.33, 3.05, 0), s.metal, s.material)
	b:tip("EdgeTop", 0.16, 0.35, 0.18, CFrame.new(1.33, 3.85, 0) * CFrame.Angles(0, math.rad(90), 0), s.metal, s.material)
	b:tip("EdgeBot", 0.16, 0.35, 0.18, CFrame.new(1.33, 2.25, 0) * CFrame.Angles(0, math.rad(90), math.rad(180)), s.metal, s.material)
	b:tip("Spike", 0.5, 0.55, 0.12, CFrame.new(-0.12, 3.05, 0) * CFrame.Angles(0, 0, math.rad(90)), s.metal, s.material)
	b:part("Cap", Vector3.new(0.3, 0.3, 0.3), CFrame.new(0, 3.45, 0), s.trim, "Metal", "Ball")
	if glow then
		b:part("EdgeGlow", Vector3.new(0.06, 1.5, 0.18), CFrame.new(1.43, 3.05, 0), glow, "Neon")
	end
	return handle
end

function W.spear(b, s, glow)
	local handle = b:cyl("Shaft", 6.4, 0.18, CFrame.new(0, 2.2, 0), s.wood, "Wood")
	b:cyl("Collar", 0.3, 0.28, CFrame.new(0, 5.45, 0), s.trim, "Metal")
	b:cyl("Butt", 0.25, 0.24, CFrame.new(0, -1, 0), s.trim, "Metal")
	b:part("Head", Vector3.new(0.38, 0.9, 0.08), CFrame.new(0, 6.05, 0), s.metal, s.material)
	b:tip("Tip", 0.38, 0.75, 0.08, CFrame.new(0, 6.5, 0), s.metal, s.material)
	b:part("Wing", Vector3.new(0.8, 0.1, 0.1), CFrame.new(0, 5.65, 0), s.trim, "Metal")
	if glow then
		b:part("Core", Vector3.new(0.08, 1.1, 0.1), CFrame.new(0, 6.1, 0), glow, "Neon")
	end
	return handle
end

function W.staff(b, s, glow)
	local handle = b:cyl("Shaft", 5.6, 0.22, CFrame.new(0, 1.8, 0), s.wood, "Wood")
	b:cyl("Band1", 0.2, 0.28, CFrame.new(0, 3.9, 0), s.trim, "Metal")
	b:cyl("Band2", 0.2, 0.28, CFrame.new(0, -0.6, 0), s.trim, "Metal")
	local orbC = CFrame.new(0, 5.15, 0)
	for i = 0, 2 do
		local a = i * math.pi * 2 / 3
		b:part("Prong" .. i, Vector3.new(0.1, 1.1, 0.1),
			CFrame.new(0, 4.6, 0) * CFrame.Angles(0, a, 0) * CFrame.new(0.32, 0.45, 0) * CFrame.Angles(0, 0, math.rad(-18)), s.trim, "Metal")
	end
	b:part("Orb", Vector3.new(0.7, 0.7, 0.7), orbC, glow or s.trim, "Neon", "Ball")
	b:part("OrbShell", Vector3.new(1.05, 1.05, 1.05), orbC, glow or s.trim, "ForceField", "Ball")
	return handle
end

function W.wand(b, s, glow)
	local handle = b:cyl("Stick", 1.6, 0.12, CFrame.new(0, 0.4, 0), s.wood, "Wood")
	b:cyl("Grip", 0.5, 0.16, CFrame.new(0, -0.15, 0), s.grip, "Fabric")
	b:cyl("Ring", 0.08, 0.2, CFrame.new(0, 0.15, 0), s.trim, "Metal")
	b:part("Tip", Vector3.new(0.2, 0.2, 0.2), CFrame.new(0, 1.25, 0), glow or s.trim, "Neon", "Ball")
	return handle
end

function W.scythe(b, s, glow)
	local handle = b:cyl("Shaft", 5.8, 0.2, CFrame.new(0, 1.9, 0), s.wood, "Wood")
	b:cyl("Collar", 0.3, 0.26, CFrame.new(0, 4.7, 0), s.trim, "Metal")
	-- blade: arc from the top, sweeping out to +X and curling down
	local cf = CFrame.new(0, 4.75, 0) * CFrame.Angles(0, 0, math.rad(-80))
	local segs, segL = 8, 0.45
	for i = 1, segs do
		local w = 0.5 - i * 0.045
		b:part("Blade" .. i, Vector3.new(w, segL, 0.07), cf * CFrame.new(-w / 2 + 0.05, segL / 2, 0), s.metal, s.material)
		if glow then
			b:part("Edge" .. i, Vector3.new(0.05, segL, 0.09), cf * CFrame.new(-w + 0.06, segL / 2, 0), glow, "Neon")
		end
		cf = cf * CFrame.new(0, segL, 0) * CFrame.Angles(0, 0, math.rad(-9))
	end
	b:tip("Tip", 0.14, 0.35, 0.07, cf, s.metal, s.material)
	return handle
end

function W.hammer(b, s, glow)
	local handle = b:cyl("Handle", 3.2, 0.22, CFrame.new(0, 0.8, 0), s.wood, "Wood")
	b:cyl("Grip", 0.9, 0.26, CFrame.new(0, -0.2, 0), s.grip, "Fabric")
	b:part("Head", Vector3.new(1.7, 0.95, 0.95), CFrame.new(0, 2.65, 0), s.metal, s.material)
	b:part("FaceL", Vector3.new(0.2, 1.1, 1.1), CFrame.new(-0.9, 2.65, 0), s.trim, "Metal")
	b:part("FaceR", Vector3.new(0.2, 1.1, 1.1), CFrame.new(0.9, 2.65, 0), s.trim, "Metal")
	if glow then
		b:part("Core", Vector3.new(1.2, 0.2, 1.0), CFrame.new(0, 2.65, 0), glow, "Neon")
	end
	return handle
end

function W.shield(b, s, glow)
	-- disc facing -Z (the outside), the arm strap at the origin on its back
	local face = b:part("Face", Vector3.new(0.25, 3.2, 3.2), CFrame.new(0, 0, -0.35) * CFrame.Angles(0, math.rad(90), 0), s.metal, s.material, "Cylinder")
	for i = 0, 15 do
		local a = i / 16 * math.pi * 2
		b:part("Rim" .. i, Vector3.new(0.22, 0.68, 0.32),
			CFrame.new(0, 0, -0.35) * CFrame.Angles(0, 0, a) * CFrame.new(0, 1.55, 0) * CFrame.Angles(0, 0, math.rad(90)), s.trim, "Metal")
	end
	b:part("Boss", Vector3.new(0.75, 0.75, 0.75), CFrame.new(0, 0, -0.5), s.trim, "Metal", "Ball")
	if glow then
		b:part("Emblem", Vector3.new(0.06, 1.6, 1.6), CFrame.new(0, 0, -0.49) * CFrame.Angles(0, math.rad(90), 0), glow, "Neon", "Cylinder")
	end
	local strap = b:part("Strap", Vector3.new(0.3, 0.9, 0.2), CFrame.new(0, 0, -0.1), s.grip, "Fabric")
	return strap, face
end

------------------------------------------------------------------------------------------------------ props
local P = {}

local function crystalPalette(glow, s)
	local c = C(glow or s.metal)
	local h, sat = c:ToHSV()
	return { deep = Color3.fromHSV(h, math.min(1, sat * 1.1 + 0.2), 0.25), body = Color3.fromHSV(h, math.max(sat, 0.5), 0.85),
		tip = Color3.fromHSV(h, 0.12, 1) }
end

function P.orb(b, s, glow)
	local g = glow or s.trim
	local core = b:part("Core", Vector3.new(1.4, 1.4, 1.4), CFrame.new(0, 3, 0), g, "Neon", "Ball")
	b:part("Shell", Vector3.new(2.2, 2.2, 2.2), CFrame.new(0, 3, 0), g, "ForceField", "Ball")
	b:part("Ring1", Vector3.new(0.12, 3.1, 3.1), CFrame.new(0, 3, 0) * CFrame.Angles(math.rad(70), 0, math.rad(20)), s.trim, "Neon", "Cylinder")
	b:part("Ring2", Vector3.new(0.12, 3.5, 3.5), CFrame.new(0, 3, 0) * CFrame.Angles(math.rad(-30), math.rad(40), 0), s.trim, "Metal", "Cylinder")
	b:part("Base", Vector3.new(0.6, 1.6, 1.6), CFrame.new(0, 0.3, 0) * CFrame.Angles(0, 0, math.rad(90)), s.stone, "Slate", "Cylinder")
	return core
end

function P.crystals(b, s, glow)
	local pal = crystalPalette(glow, s)
	local rng = Random.new(7)
	b:crystal("shard", CFrame.new(0, -0.3, 0), Vector3.new(3.4, 1.2, 3), { deep = C(s.stone):Lerp(Color3.new(0, 0, 0), 0.5), body = C(s.stone), tip = C(s.stone):Lerp(Color3.new(1, 1, 1), 0.4) }, 3)
	local base = b.parts[1]
	for i = 1, 6 do
		local a = i / 6 * math.pi * 2 + rng:NextNumber(-0.3, 0.3)
		local r = if i == 1 then 0 else rng:NextNumber(0.5, 1.1)
		local h = if i == 1 then 4.2 else rng:NextNumber(1.6, 3.2)
		local lean = if i == 1 then 0 else rng:NextNumber(18, 34)
		local out = Vector3.new(math.cos(a), 0, math.sin(a))
		local up = (Vector3.yAxis * math.cos(math.rad(lean)) + out * math.sin(math.rad(lean))).Unit
		local pos = out * r + Vector3.new(0, 0.2, 0)
		b:crystal("spike", CFrame.fromMatrix(pos, up:Cross(out).Unit, up), Vector3.new(0.9, h, 0.9), pal, i)
	end
	return base or b.parts[1]
end

function P.rock(b, s)
	local tone = C(s.stone)
	local pal = { deep = tone:Lerp(Color3.new(0, 0, 0), 0.55), body = tone, tip = tone:Lerp(Color3.new(1, 1, 1), 0.35) }
	b:crystal("shard", CFrame.new(0, -0.4, 0), Vector3.new(4.2, 3.2, 3.6), pal, 11)
	b:crystal("shard", CFrame.new(1.9, -0.3, 0.8) * CFrame.Angles(0, 0.7, 0.2), Vector3.new(2.2, 1.8, 2), pal, 17)
	b:crystal("shard", CFrame.new(-1.6, -0.3, -0.6) * CFrame.Angles(0, -0.4, -0.15), Vector3.new(1.8, 1.4, 1.6), pal, 23)
	return b.parts[1]
end

function P.meteor(b, s, glow)
	local pal = { deep = Color3.fromRGB(28, 18, 16), body = Color3.fromRGB(70, 46, 38), tip = Color3.fromRGB(120, 90, 74) }
	b:crystal("shard", CFrame.new(0, 0, 0), Vector3.new(4, 4.4, 4), pal, 5)
	local g = glow or "#FF6A1C"
	local rng = Random.new(3)
	for i = 1, 7 do
		local a, e = rng:NextNumber(0, math.pi * 2), rng:NextNumber(-0.6, 0.9)
		local dir = Vector3.new(math.cos(a) * math.cos(e), math.sin(e), math.sin(a) * math.cos(e))
		b:part("Crack" .. i, Vector3.new(0.12, rng:NextNumber(0.8, 1.6), 0.12),
			CFrame.lookAt(Vector3.new(0, 2.2, 0) + dir * 1.55, Vector3.new(0, 2.2, 0) + dir * 3) * CFrame.Angles(0, 0, rng:NextNumber(0, 3)), g, "Neon")
	end
	b:part("Heat", Vector3.new(4.4, 4.4, 4.4), CFrame.new(0, 2.2, 0), g, "ForceField", "Ball")
	return b.parts[1]
end

function P.portal(b, s, glow)
	local g = glow or "#8A2BFF"
	local centre = CFrame.new(0, 4.6, 0)
	local first
	for i = 0, 19 do
		local a = i / 20 * math.pi * 2
		local p = b:part("Frame" .. i, Vector3.new(0.65, 1.35, 0.7), centre * CFrame.Angles(0, 0, a) * CFrame.new(0, 4, 0), s.stone, "Slate")
		first = first or p
		if i % 2 == 0 then
			b:part("Rune" .. i, Vector3.new(0.2, 0.5, 0.74), centre * CFrame.Angles(0, 0, a) * CFrame.new(0, 3.95, 0), g, "Neon")
		end
	end
	b:part("Void", Vector3.new(0.1, 7.2, 7.2), centre * CFrame.Angles(0, math.rad(90), 0), g, "ForceField", "Cylinder")
	b:part("Core", Vector3.new(0.05, 6.6, 6.6), centre * CFrame.Angles(0, math.rad(90), 0), C(g):Lerp(Color3.new(0, 0, 0), 0.75), "Neon", "Cylinder")
	b:part("Base", Vector3.new(6, 0.6, 2.2), CFrame.new(0, 0.3, 0), s.stone, "Slate")
	return first
end

function P.totem(b, s, glow)
	local g = glow or "#3FA9FF"
	local body = b:part("Stone", Vector3.new(1.7, 4.2, 1.3), CFrame.new(0, 2.1, 0), s.stone, "Slate")
	b:tip("Cap", 1.7, 0.7, 1.3, CFrame.new(0, 4.2, 0), s.stone, "Slate")
	local runes = { { 0, 3.3, 0.9 }, { -0.35, 2.6, 0.5 }, { 0.35, 2.6, 0.5 }, { 0, 1.8, 0.9 }, { 0, 1.1, 0.5 } }
	for i, r in runes do
		b:part("Rune" .. i, Vector3.new(r[3], 0.12, 0.08), CFrame.new(r[1], r[2], -0.66), g, "Neon")
	end
	b:part("RuneV", Vector3.new(0.12, 2.6, 0.08), CFrame.new(0, 2.25, -0.67), g, "Neon")
	b:part("Base", Vector3.new(2.4, 0.4, 2), CFrame.new(0, 0.2, 0), s.stone, "Slate")
	return body
end

------------------------------------------------------------------------------------------------------ public
-- cfg: { type, style ("steel"|"dark"|"gold"|"crystal"|"energy"|"wood"), glow (hex or nil), scale, name }
function ModelKit.build(cfg)
	cfg = cfg or {}
	local t = ModelKit.byId[cfg.type or "sword"] or ModelKit.byId.sword
	local s = table.clone(ModelKit.STYLES[cfg.style or "steel"] or ModelKit.STYLES.steel)
	if cfg.metal then
		s.metal = cfg.metal
	end
	local glow = cfg.glow
	if cfg.style == "energy" then
		glow = glow or s.metal
		s.metal = glow
	end
	local b = newBuilder(cfg.name or t.title:gsub("%s", ""), t.kind == "prop")
	local primary, extra
	if W[t.id] then
		primary, extra = W[t.id](b, s, glow, cfg)
	else
		primary = P[t.id](b, s, glow, cfg)
	end
	local model = b:finish(primary, CFrame.identity, cfg.scale)
	model:SetAttribute("ClipForgeType", t.id)
	model:SetAttribute("ClipForgeKind", t.kind)
	if cfg.style == "energy" or cfg.style == "crystal" then
		for _, p in b.parts do
			if p.Material == Enum.Material.Glass then
				p.Transparency = 0.35
			end
		end
	end
	return model
end

-- Weld a weapon into a rig's hand (or a shield onto the forearm). Returns the welded copy.
function ModelKit.attach(model: Model, rig: Model, hand: string?)
	local kind = model:GetAttribute("ClipForgeKind") or "weapon"
	local copy = model:Clone()
	local handle = copy.PrimaryPart or copy:FindFirstChild("Handle")
	if not handle then
		return nil, "This model has no handle"
	end
	local r15 = rig:FindFirstChild("UpperTorso") ~= nil
	local left = hand == "Left" or kind == "shield"
	local target = if r15 then rig:FindFirstChild(if left then (if kind == "shield" then "LeftLowerArm" else "LeftHand") else "RightHand")
		else rig:FindFirstChild(if left then "Left Arm" else "Right Arm")
	if not target then
		return nil, "No hand on this rig"
	end
	for _, p in copy:GetDescendants() do
		if p:IsA("BasePart") then
			p.Anchored = false
			p.CanCollide = false
			p.Massless = true
		end
	end
	local grip = handle:FindFirstChild("Grip")
	local weld = Instance.new("Weld")
	weld.Name = "ClipForgeGrip"
	weld.Part0 = target
	weld.Part1 = handle
	if kind == "shield" then
		-- disc on the outside of the forearm, facing out
		weld.C0 = CFrame.new(if left then -target.Size.X / 2 - 0.15 else target.Size.X / 2 + 0.15, 0, 0)
			* CFrame.Angles(0, math.rad(if left then 90 else -90), 0)
	else
		-- blade/shaft out of the fist, pointing forward when the arm hangs (hand -Z)
		local down = if r15 then target.Size.Y * 0.42 else target.Size.Y * 0.45
		weld.C0 = CFrame.new(0, -down, 0) * CFrame.Angles(math.rad(-90), 0, 0)
	end
	weld.C1 = if grip then grip.CFrame else CFrame.identity
	weld.Parent = handle
	copy.Name = model.Name
	copy:SetAttribute("ClipForgeHeld", true)
	copy.Parent = rig
	return copy
end

-- A Tool with this weapon as its Handle (players equip it from the backpack).
function ModelKit.toTool(model: Model)
	local tool = Instance.new("Tool")
	tool.Name = model.Name
	tool.RequiresHandle = true
	tool.CanBeDropped = false
	local copy = model:Clone()
	local handle = copy.PrimaryPart or copy:FindFirstChild("Handle")
	for _, d in copy:GetChildren() do
		d.Parent = tool
	end
	copy:Destroy()
	if handle then
		handle.Name = "Handle"
		local grip = handle:FindFirstChild("Grip")
		-- Tool.Grip maps the handle onto the hand's RightGripAttachment; +Y of our weapons points forward then
		tool.Grip = if grip then grip.CFrame else CFrame.identity
	end
	return tool
end

-- "glowing purple katana", "golden greatsword", "crystal staff", "big meteor rock"
local COLORS = {
	red = "#FF2A2A", crimson = "#DC143C", orange = "#FF7A1A", gold = "#FFC530", yellow = "#FFE135", green = "#2EE85A",
	lime = "#9BFF2E", teal = "#14D2C0", cyan = "#22E6FF", blue = "#2F7BFF", purple = "#9B3CFF", violet = "#8F4DFF",
	magenta = "#FF2FD3", pink = "#FF5EB8", white = "#F4F8FF", black = "#1A1024",
}
local STYLE_WORDS = { golden = true, gold = true, dark = true, shadow = true, obsidian = true, crystal = true, ice = true,
	glass = true, energy = true, laser = true, plasma = true, light = true, wooden = true, wood = true, iron = true }
function ModelKit.parse(prompt: string)
	local text = " " .. string.lower(prompt or "") .. " "
	-- the item: style words ("crystal staff", "golden sword") only pick the type when nothing else does
	local best, bestScore = "sword", 0
	for _, withStyle in { false, true } do
		for _, t in ModelKit.TYPES do
			local score = 0
			for word in string.gmatch(t.tags, "%a+") do
				if (withStyle or not STYLE_WORDS[word]) and string.find(text, "%f[%a]" .. word .. "s?%f[%A]") then
					score += #word
				end
			end
			if score > bestScore then
				best, bestScore = t.id, score
			end
		end
		if bestScore > 0 then
			break
		end
	end
	local style = "steel"
	for _, pair in { { "golden", "gold" }, { "gold", "gold" }, { "dark", "dark" }, { "shadow", "dark" }, { "obsidian", "dark" },
		{ "crystal", "crystal" }, { "ice", "crystal" }, { "glass", "crystal" }, { "energy", "energy" }, { "laser", "energy" },
		{ "plasma", "energy" }, { "light", "energy" }, { "wooden", "wood" }, { "wood", "wood" }, { "iron", "steel" } } do
		if string.find(text, "%f[%a]" .. pair[1] .. "%f[%A]") then
			style = pair[2]
			break
		end
	end
	local glow, glowAt = nil, math.huge
	for name, hx in COLORS do -- the first colour named
		local at = string.find(text, "%f[%a]" .. name .. "%f[%A]")
		if at and at < glowAt then
			glow, glowAt = hx, at
		end
	end
	if not glow and (string.find(text, "glow") or string.find(text, "magic") or string.find(text, "enchant")) then
		glow = "#7C5CFF"
	end
	local scale = 1
	for _, pair in { { "tiny", 0.6 }, { "small", 0.8 }, { "big", 1.3 }, { "large", 1.3 }, { "huge", 1.6 }, { "giant", 1.8 } } do
		if string.find(text, "%f[%a]" .. pair[1] .. "%f[%A]") then
			scale = pair[2]
		end
	end
	return { type = best, style = style, glow = glow, scale = scale, name = nil, prompt = prompt }
end

return ModelKit
