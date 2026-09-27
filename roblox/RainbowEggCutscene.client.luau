--[[
	RAINBOW EGG CUTSCENE
	Put this LocalScript INSIDE the "RainbowEgg" Script (which is inside your egg).
	The RainbowEgg script hands it to players automatically.

	It animates the rainbow egg (colour cycling, bobbing, orbiting ice crystals)
	and plays the hatch cutscene.
]]

local Players = game:GetService("Players")
local player = Players.LocalPlayer

-- Only run once per player, even with several rainbow eggs in the game.
if player:GetAttribute("RainbowEggCutsceneRunning") then
	return
end
player:SetAttribute("RainbowEggCutsceneRunning", true)

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local camera = workspace.CurrentCamera

-- Ultra Instinct colours.
local INDIGO = Color3.fromRGB(29, 15, 74)
local VIOLET = Color3.fromRGB(106, 44, 255)
local MAGENTA = Color3.fromRGB(196, 60, 255)
local PINK = Color3.fromRGB(255, 95, 210)
local CYAN = Color3.fromRGB(95, 216, 255)
local ICE = Color3.fromRGB(168, 232, 255)
local SILVER = Color3.fromRGB(244, 240, 255)

local SHELL_CYCLE = { CYAN, VIOLET, MAGENTA, PINK, ICE, VIOLET }
local CYCLE_SECONDS = 6

local AURA_COLORS = ColorSequence.new({
	ColorSequenceKeypoint.new(0, SILVER),
	ColorSequenceKeypoint.new(0.3, MAGENTA),
	ColorSequenceKeypoint.new(0.65, VIOLET),
	ColorSequenceKeypoint.new(1, CYAN),
})
local SPARKLE_COLORS = ColorSequence.new({
	ColorSequenceKeypoint.new(0, SILVER),
	ColorSequenceKeypoint.new(0.5, PINK),
	ColorSequenceKeypoint.new(1, CYAN),
})

local function shellColor(t: number): Color3
	local n = #SHELL_CYCLE
	local pos = (t / CYCLE_SECONDS % 1) * n
	local i = math.floor(pos)
	return SHELL_CYCLE[i + 1]:Lerp(SHELL_CYCLE[(i + 1) % n + 1], pos - i)
end

local function partsOf(obj: Instance): { BasePart }
	local list = {}
	if obj:IsA("BasePart") then
		table.insert(list, obj)
	end
	for _, d in obj:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(list, d)
		end
	end
	return list
end

local function sizeOf(obj: Instance): Vector3
	if obj:IsA("Model") then
		return obj:GetExtentsSize()
	elseif obj:IsA("BasePart") then
		return obj.Size
	end
	return Vector3.new(4, 5, 4)
end

local function pivotOf(obj: Instance): CFrame
	return (obj :: any):GetPivot()
end

local function neonPart(parent: Instance, size: Vector3, color: Color3, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Size = size
	p.Shape = shape or Enum.PartType.Block
	p.Material = Enum.Material.Neon
	p.Color = color
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Parent = parent
	return p
end

local function makeCrystal(parent: Instance, size: number): Part
	local p = neonPart(parent, Vector3.new(size * 0.45, size, size * 0.45), ICE)
	p.Name = "Crystal"
	p.Transparency = 0.15
	return p
end

---------------------------------------------------------------------------
-- Idle animation: colour-cycling shell, bobbing, orbiting ice crystals.
---------------------------------------------------------------------------

type EggData = { home: CFrame, crystals: { Part }, folder: Folder, hidden: boolean, parts: { BasePart } }
local eggs: { [Instance]: EggData } = {}

local function setupEgg(egg: Instance)
	if eggs[egg] or not (egg:IsA("BasePart") or egg:IsA("Model")) then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "RainbowEggCrystals"
	folder.Parent = workspace
	local crystals = {}
	local ring = math.max(sizeOf(egg).X, sizeOf(egg).Z)
	for i = 1, 6 do
		crystals[i] = makeCrystal(folder, ring * 0.25 + (i % 3) * 0.4)
	end
	eggs[egg] = { home = pivotOf(egg), crystals = crystals, folder = folder, hidden = false, parts = partsOf(egg) }
	egg.AncestryChanged:Connect(function()
		if not egg:IsDescendantOf(workspace) and eggs[egg] then
			eggs[egg].folder:Destroy()
			eggs[egg] = nil
		end
	end)
end

CollectionService:GetInstanceAddedSignal("RainbowEgg"):Connect(setupEgg)
for _, egg in CollectionService:GetTagged("RainbowEgg") do
	setupEgg(egg)
end

RunService.RenderStepped:Connect(function()
	local t = os.clock()
	local col = shellColor(t)
	for egg, data in eggs do
		if data.hidden then
			continue
		end
		-- These changes are client-side, so they're smooth and only affect this player's view.
		local size = sizeOf(egg)
		;(egg :: any):PivotTo(data.home * CFrame.new(0, math.sin(t * 2) * size.Y * 0.07, 0) * CFrame.Angles(0, t * 0.6, 0))
		for _, p in data.parts do
			p.Color = col
		end
		local glow = egg:FindFirstChild("RainbowGlow")
		if glow then
			glow.OutlineColor = shellColor(t + CYCLE_SECONDS / 2)
		end
		local light = egg:FindFirstChild("RainbowLight", true)
		if light then
			light.Color = col
			light.Brightness = 2.5 + math.sin(t * 3)
		end
		local r = math.max(size.X, size.Z) * 1.25
		for i, crystal in data.crystals do
			local a = t * 0.5 + i / #data.crystals * math.pi * 2
			local pos = data.home.Position
				+ Vector3.new(math.cos(a) * r, math.sin(t * 1.3 + i) * size.Y * 0.25, math.sin(a) * r)
			crystal.CFrame = CFrame.new(pos) * CFrame.Angles(t + i, t * 0.7 + i, 0.4)
		end
	end
end)

local savedTransparency: { [BasePart]: number } = {}

local function setEggVisible(egg: Instance, visible: boolean)
	local data = eggs[egg]
	if data then
		data.hidden = not visible
		data.folder.Parent = if visible then workspace else nil
	end
	for _, p in partsOf(egg) do
		if visible then
			p.Transparency = savedTransparency[p] or 0
		else
			savedTransparency[p] = p.Transparency
			p.Transparency = 1
		end
	end
	for _, d in egg:GetDescendants() do
		if d:IsA("ParticleEmitter") or d:IsA("Light") or d:IsA("ProximityPrompt") or d:IsA("Highlight") then
			d.Enabled = visible
		elseif d:IsA("Decal") or d:IsA("Texture") then
			d.Transparency = if visible then 0 else 1
		end
	end
end

---------------------------------------------------------------------------
-- Cutscene helpers
---------------------------------------------------------------------------

local function tween(obj: Instance, time: number, props: { [string]: any }, style: Enum.EasingStyle?, dir: Enum.EasingDirection?)
	local tw = TweenService:Create(obj, TweenInfo.new(time, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end

local function setControls(enabled: boolean)
	local ok, controls = pcall(function()
		local pm = require(player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule") :: any)
		return pm:GetControls()
	end)
	if ok and controls then
		if enabled then
			controls:Enable()
		else
			controls:Disable()
		end
	end
end

-- A copy of the player's egg just for the cutscene, with scripts/prompts/effects removed.
local function copyEgg(egg: Instance, parent: Instance): Instance
	local old = egg.Archivable
	egg.Archivable = true
	local copy = egg:Clone()
	egg.Archivable = old
	for _, d in copy:GetDescendants() do
		if d:IsA("LuaSourceContainer") or d:IsA("ProximityPrompt") or d:IsA("ParticleEmitter") or d:IsA("Light") or d:IsA("Highlight") then
			d:Destroy()
		end
	end
	for _, p in partsOf(copy) do
		p.Anchored = true
		p.CanCollide = false
	end
	copy.Parent = parent
	return copy
end

-- A point on an egg-shaped surface around the centre.
local function surfacePoint(size: Vector3, theta: number, phi: number): Vector3
	return Vector3.new(
		math.sin(phi) * math.cos(theta) * size.X / 2,
		math.cos(phi) * size.Y / 2,
		math.sin(phi) * math.sin(theta) * size.Z / 2
	)
end

-- Glowing zig-zag crack on the shell, made of Beams on an invisible anchor part.
local function makeCrack(anchor: BasePart, size: Vector3, color: Color3): { Beam }
	local beams = {}
	local theta = math.random() * math.pi * 2
	local phi = math.rad(math.random(40, 140))
	local prev = Instance.new("Attachment")
	prev.Position = surfacePoint(size * 1.03, theta, phi)
	prev.Parent = anchor
	for _ = 1, 5 do
		theta += math.rad(math.random(10, 25))
		phi = math.clamp(phi + math.rad(math.random(-25, 25)), 0.3, math.pi - 0.3)
		local nxt = Instance.new("Attachment")
		nxt.Position = surfacePoint(size * 1.03, theta, phi)
		nxt.Parent = anchor
		local beam = Instance.new("Beam")
		beam.Attachment0 = prev
		beam.Attachment1 = nxt
		beam.Color = ColorSequence.new(color)
		beam.LightEmission = 1
		beam.LightInfluence = 0
		beam.Width0 = 0
		beam.Width1 = 0
		beam.FaceCamera = true
		beam.Segments = 1
		beam.Parent = anchor
		table.insert(beams, beam)
		prev = nxt
	end
	return beams
end

---------------------------------------------------------------------------
-- The cutscene
---------------------------------------------------------------------------

local playing = false

local function playCutscene(realEgg: Instance)
	if playing then
		return
	end
	playing = true

	local chargeSeconds = realEgg:GetAttribute("ChargeSeconds") or 3.2
	local revealSeconds = realEgg:GetAttribute("RevealSeconds") or 4
	local revealText = realEgg:GetAttribute("RevealText") or "RAINBOW EGG HATCHED!"
	local oncePerPlayer = realEgg:GetAttribute("OncePerPlayer")

	local home = eggs[realEgg] and eggs[realEgg].home or pivotOf(realEgg)
	local size = sizeOf(realEgg)
	local scale = math.max(size.X, size.Y, size.Z) / 5 -- effects are tuned for a ~5 stud egg
	local origin = home.Position

	local fx = Instance.new("Folder")
	fx.Name = "RainbowEggCutscene"
	fx.Parent = workspace

	-- Copy first, then hide the real one, so the copy keeps the egg's own look.
	local egg = copyEgg(realEgg, fx)
	setEggVisible(realEgg, false)
	setControls(false)
	local eggParts = partsOf(egg)
	local hl = Instance.new("Highlight")
	hl.FillColor = SILVER
	hl.FillTransparency = 0.85
	hl.OutlineColor = ICE
	hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	hl.Parent = egg

	-- Invisible centre part that holds the light, aura and cracks.
	local centre = neonPart(fx, size, MAGENTA)
	centre.Transparency = 1
	centre.CFrame = CFrame.new(origin)
	local light = Instance.new("PointLight")
	light.Color = MAGENTA
	light.Brightness = 3
	light.Range = 20 * scale
	light.Parent = centre

	local aura = Instance.new("ParticleEmitter")
	aura.Texture = "rbxasset://textures/particles/fire_main.dds"
	aura.Color = AURA_COLORS
	aura.LightEmission = 1
	aura.LightInfluence = 0
	aura.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2.5 * scale), NumberSequenceKeypoint.new(1, 0) })
	aura.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 1) })
	aura.Lifetime = NumberRange.new(0.5, 1)
	aura.Rate = 60
	aura.Speed = NumberRange.new(3 * scale, 6 * scale)
	aura.Acceleration = Vector3.new(0, 10 * scale, 0)
	aura.Shape = Enum.ParticleEmitterShape.Sphere
	aura.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
	aura.Parent = centre

	-- Energy streams pulled in from all around.
	local pullField = neonPart(fx, Vector3.new(40, 40, 40) * scale, VIOLET, Enum.PartType.Ball)
	pullField.Transparency = 1
	pullField.CFrame = CFrame.new(origin)
	local streams = Instance.new("ParticleEmitter")
	streams.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	streams.Color = SPARKLE_COLORS
	streams.LightEmission = 1
	streams.LightInfluence = 0
	streams.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3 * scale), NumberSequenceKeypoint.new(1, 0.8 * scale) })
	streams.Lifetime = NumberRange.new(0.8, 1)
	streams.Rate = 0
	streams.Speed = NumberRange.new(18 * scale, 22 * scale)
	streams.Shape = Enum.ParticleEmitterShape.Sphere
	streams.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
	streams.ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward
	streams.Parent = pullField

	-- Purple colour grade + bloom on the whole screen.
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "RainbowEggGrade"
	cc.Parent = Lighting
	local bloom = Instance.new("BloomEffect")
	bloom.Name = "RainbowEggBloom"
	bloom.Intensity = 0.4
	bloom.Size = 30
	bloom.Threshold = 1.5
	bloom.Parent = Lighting

	-- Letterbox bars, flash and title.
	local gui = Instance.new("ScreenGui")
	gui.Name = "RainbowEggCutscene"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 100
	gui.Parent = player:WaitForChild("PlayerGui")

	local function bar(anchorY: number): Frame
		local f = Instance.new("Frame")
		f.BackgroundColor3 = Color3.new(0, 0, 0)
		f.BorderSizePixel = 0
		f.AnchorPoint = Vector2.new(0, anchorY)
		f.Position = UDim2.fromScale(0, anchorY)
		f.Size = UDim2.fromScale(1, 0)
		f.Parent = gui
		return f
	end
	local topBar, bottomBar = bar(0), bar(1)
	tween(topBar, 0.6, { Size = UDim2.fromScale(1, 0.1) })
	tween(bottomBar, 0.6, { Size = UDim2.fromScale(1, 0.1) })

	local flash = Instance.new("Frame")
	flash.Size = UDim2.fromScale(1, 1)
	flash.BackgroundColor3 = SILVER
	flash.BackgroundTransparency = 1
	flash.BorderSizePixel = 0
	flash.ZIndex = 5
	flash.Parent = gui
	local flashGrad = Instance.new("UIGradient")
	flashGrad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, MAGENTA),
		ColorSequenceKeypoint.new(0.5, Color3.new(1, 1, 1)),
		ColorSequenceKeypoint.new(1, VIOLET),
	})
	flashGrad.Parent = flash

	-- Camera: swing round to face the egg.
	local savedType = camera.CameraType
	local savedFov = camera.FieldOfView
	camera.CameraType = Enum.CameraType.Scriptable
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local fromDir = if root then (root.Position - origin) * Vector3.new(1, 0, 1) else Vector3.new(0, 0, 1)
	if fromDir.Magnitude < 0.1 then
		fromDir = Vector3.new(0, 0, 1)
	end
	local camPos = origin + fromDir.Unit * 14 * scale + Vector3.new(0, 2.5 * scale, 0)
	local camBase = CFrame.lookAt(camPos, origin)
	tween(camera, 0.8, { CFrame = camBase }, Enum.EasingStyle.Sine)
	task.wait(0.8)

	-------------------------------------------------------------- charge-up
	local cracks: { { Beam } } = {}
	local crackColors = { SILVER, CYAN, PINK, SILVER, MAGENTA, ICE, SILVER }
	local start = os.clock()
	while true do
		local k = math.min(1, (os.clock() - start) / chargeSeconds)
		local t = os.clock()
		local shake = k * k * 0.5 * scale
		local jiggle = CFrame.Angles(0, 0, math.sin(t * 40) * 0.12 * k)
			* CFrame.new((math.random() - 0.5) * shake, (math.random() - 0.5) * shake, 0)
		;(egg :: any):PivotTo(home * jiggle)
		centre.CFrame = CFrame.new(origin) * jiggle
		local col = shellColor(t * (1 + k * 4)):Lerp(SILVER, k * 0.5)
		for _, p in eggParts do
			p.Color = col
		end
		hl.FillTransparency = 0.85 - k * 0.6
		light.Brightness = 3 + k * 12
		light.Color = col
		aura.Rate = 60 + k * 200
		streams.Rate = 30 + k * 250
		cc.TintColor = Color3.new(1, 1, 1):Lerp(Color3.fromRGB(220, 170, 255), k)
		cc.Saturation = k * 0.4
		bloom.Intensity = 0.4 + k * 1.5
		camera.FieldOfView = savedFov - k * 18
		camera.CFrame = camBase * CFrame.new((math.random() - 0.5) * shake * 0.5, (math.random() - 0.5) * shake * 0.5, 0)

		-- Cracks appear in stages and grow in.
		while #cracks < math.floor(k * 7) do
			local crack = makeCrack(centre, size, crackColors[#cracks + 1])
			table.insert(cracks, crack)
			for _, beam in crack do
				tween(beam, 0.25, { Width0 = 0.25 * scale, Width1 = 0.25 * scale })
			end
		end

		if k >= 1 then
			break
		end
		RunService.RenderStepped:Wait()
	end

	-------------------------------------------------------------- burst
	streams.Rate = 0
	aura.Enabled = false
	flash.BackgroundTransparency = 0
	tween(flash, 1.2, { BackgroundTransparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	egg:Destroy()
	for _, crack in cracks do
		for _, beam in crack do
			beam.Enabled = false
		end
	end

	-- Shell shards flying out.
	local shardColors = { VIOLET, MAGENTA, PINK, CYAN, SILVER }
	for i = 1, 24 do
		local shard = neonPart(
			fx,
			Vector3.new(math.random() * 0.8 + 0.4, 0.15, math.random() * 0.8 + 0.4) * scale,
			shardColors[i % #shardColors + 1]
		)
		shard.Anchored = false
		shard.CFrame = CFrame.new(origin + Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 2 * scale)
			* CFrame.Angles(math.random() * 6, math.random() * 6, math.random() * 6)
		local dir = Vector3.new(math.random() - 0.5, math.random() * 0.8 + 0.2, math.random() - 0.5).Unit
		shard.AssemblyLinearVelocity = dir * math.random(25, 45) * scale
		shard.AssemblyAngularVelocity = Vector3.new(math.random(-15, 15), math.random(-15, 15), math.random(-15, 15))
		Debris:AddItem(shard, 3)
	end

	-- Ice crystals shattering outwards.
	for _ = 1, 12 do
		local cr = makeCrystal(fx, (0.8 + math.random() * 1.2) * scale)
		cr.Anchored = false
		cr.CFrame = CFrame.new(origin)
		cr.AssemblyLinearVelocity = Vector3.new(math.random() - 0.5, math.random() * 0.6, math.random() - 0.5).Unit
			* math.random(20, 35)
			* scale
		cr.AssemblyAngularVelocity = Vector3.new(math.random(-8, 8), math.random(-8, 8), math.random(-8, 8))
		Debris:AddItem(cr, 3)
	end

	-- Sparkle explosion.
	local burst = Instance.new("ParticleEmitter")
	burst.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	burst.Color = SPARKLE_COLORS
	burst.LightEmission = 1
	burst.LightInfluence = 0
	burst.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, scale), NumberSequenceKeypoint.new(1, 0) })
	burst.Lifetime = NumberRange.new(1, 2)
	burst.Speed = NumberRange.new(15 * scale, 40 * scale)
	burst.Drag = 3
	burst.SpreadAngle = Vector2.new(180, 180)
	burst.Rate = 0
	burst.Parent = centre
	burst:Emit(200)

	camera.FieldOfView = savedFov
	camera.CFrame = camBase * CFrame.new(0, 0, 3 * scale)
	tween(camera, 1.5, { CFrame = camBase }, Enum.EasingStyle.Sine)
	tween(cc, 1.5, { TintColor = Color3.fromRGB(235, 215, 255), Saturation = 0.25 })
	tween(bloom, 1.5, { Intensity = 1 })

	-------------------------------------------------------------- reveal
	-- The radiant silver-violet energy core with orbiting coloured lights.
	local core = neonPart(fx, Vector3.new(0.5, 0.5, 0.5), Color3.new(1, 1, 1), Enum.PartType.Ball)
	core.CFrame = CFrame.new(origin)
	tween(core, 0.6, { Size = Vector3.new(3, 3, 3) * scale }, Enum.EasingStyle.Back)
	local coreHl = Instance.new("Highlight")
	coreHl.FillColor = SILVER
	coreHl.FillTransparency = 0.3
	coreHl.OutlineColor = MAGENTA
	coreHl.Parent = core
	local coreLight = Instance.new("PointLight")
	coreLight.Color = ICE
	coreLight.Brightness = 8
	coreLight.Range = 30 * scale
	coreLight.Parent = core
	local coreAura = aura:Clone()
	coreAura.Enabled = true
	coreAura.Rate = 120
	coreAura.Parent = core

	local orbiters = {}
	for i, col in { CYAN, PINK, MAGENTA, ICE } do
		local orb = neonPart(fx, Vector3.new(0.6, 0.6, 0.6) * scale, col, Enum.PartType.Ball)
		local a0 = Instance.new("Attachment")
		a0.Position = Vector3.new(0, 0.25 * scale, 0)
		a0.Parent = orb
		local a1 = Instance.new("Attachment")
		a1.Position = Vector3.new(0, -0.25 * scale, 0)
		a1.Parent = orb
		local trail = Instance.new("Trail")
		trail.Attachment0 = a0
		trail.Attachment1 = a1
		trail.Color = ColorSequence.new(col, SILVER)
		trail.LightEmission = 1
		trail.LightInfluence = 0
		trail.Lifetime = 0.5
		trail.WidthScale = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0) })
		trail.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) })
		trail.Parent = orb
		orbiters[i] = orb
	end

	-- Title text with a moving rainbow gradient.
	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.AnchorPoint = Vector2.new(0.5, 0.5)
	title.Position = UDim2.fromScale(0.5, 0.2)
	title.Size = UDim2.fromScale(0.8, 0.1)
	title.Font = Enum.Font.FredokaOne
	title.TextScaled = true
	title.Text = revealText
	title.TextColor3 = Color3.new(1, 1, 1)
	title.TextTransparency = 1
	title.ZIndex = 6
	title.Parent = gui
	local titleGrad = Instance.new("UIGradient")
	titleGrad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, CYAN),
		ColorSequenceKeypoint.new(0.25, VIOLET),
		ColorSequenceKeypoint.new(0.5, PINK),
		ColorSequenceKeypoint.new(0.75, MAGENTA),
		ColorSequenceKeypoint.new(1, CYAN),
	})
	titleGrad.Parent = title
	local stroke = Instance.new("UIStroke")
	stroke.Color = INDIGO
	stroke.Thickness = 3
	stroke.Transparency = 1
	stroke.Parent = title
	tween(title, 0.6, { TextTransparency = 0 })
	tween(stroke, 0.6, { Transparency = 0 })

	local revealStart = os.clock()
	local conn = RunService.RenderStepped:Connect(function()
		local t = os.clock() - revealStart
		core.CFrame = CFrame.new(origin + Vector3.new(0, math.sin(t * 2) * 0.3 * scale, 0))
		coreHl.OutlineColor = shellColor(t * 2)
		coreLight.Brightness = 8 * (1 + math.sin(t * 6) * 0.08)
		for i, orb in orbiters do
			local a = t * 3 + i / #orbiters * math.pi * 2
			local tilt = CFrame.Angles(i * 0.8, 0, i * 0.5)
			orb.CFrame = CFrame.new(origin) * tilt * CFrame.new(math.cos(a) * 3.2 * scale, 0, math.sin(a) * 3.2 * scale)
		end
		titleGrad.Offset = Vector2.new(math.sin(t * 1.5) * 0.3, 0)
		title.Rotation = math.sin(t * 2) * 2
		if t > 1.5 then
			-- slow push-in with a gentle roll
			local camAt = origin + (camBase.Position - origin) * (1 - math.min(t - 1.5, 3) * 0.05)
			camera.CFrame = CFrame.lookAt(camAt, origin) * CFrame.Angles(0, 0, math.sin(t) * 0.02)
		end
	end)

	task.wait(revealSeconds)

	-------------------------------------------------------------- wrap up
	tween(topBar, 0.5, { Size = UDim2.fromScale(1, 0) })
	tween(bottomBar, 0.5, { Size = UDim2.fromScale(1, 0) })
	tween(title, 0.5, { TextTransparency = 1 })
	tween(stroke, 0.5, { Transparency = 1 })
	tween(cc, 0.5, { TintColor = Color3.new(1, 1, 1), Saturation = 0 })
	tween(bloom, 0.5, { Intensity = 0 })
	tween(core, 0.5, { Size = Vector3.new(0.1, 0.1, 0.1) }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
	coreAura.Enabled = false
	task.wait(0.5)

	conn:Disconnect()
	fx:Destroy()
	gui:Destroy()
	cc:Destroy()
	bloom:Destroy()
	camera.FieldOfView = savedFov
	camera.CameraType = if savedType == Enum.CameraType.Scriptable then Enum.CameraType.Custom else savedType
	setControls(true)
	if oncePerPlayer == false then
		setEggVisible(realEgg, true)
	end
	playing = false
end

ReplicatedStorage:WaitForChild("RainbowEggHatch").OnClientEvent:Connect(function(egg: Instance)
	if egg then
		playCutscene(egg)
	end
end)
