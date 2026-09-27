-- Animates the rainbow egg and plays its hatch cutscene.
-- Lives in StarterPlayer > StarterPlayerScripts as a LocalScript.

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("RainbowEggConfig"))
local C = Config.Colors

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local function shellColor(t: number): Color3
	local cycle = Config.ShellCycle
	local n = #cycle
	local pos = (t / Config.ShellCycleSeconds % 1) * n
	local i = math.floor(pos)
	local a = cycle[i + 1]
	local b = cycle[(i + 1) % n + 1]
	return a:Lerp(b, pos - i)
end

local function makeCrystal(parent: Instance, size: number): BasePart
	local p = Instance.new("Part")
	p.Name = "Crystal"
	p.Size = Vector3.new(size * 0.45, size, size * 0.45)
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Color = C.Ice
	p.Transparency = 0.15
	p.Parent = parent
	return p
end

---------------------------------------------------------------------------
-- Idle animation: colour-cycling shell, bobbing, orbiting ice crystals.
---------------------------------------------------------------------------

local idleEggs: { [BasePart]: { home: CFrame, crystals: { BasePart }, folder: Folder, hidden: boolean } } = {}

local function setupEgg(egg: Instance)
	if not egg:IsA("BasePart") or idleEggs[egg] then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "RainbowEggFX"
	folder.Parent = workspace
	local crystals = {}
	for i = 1, 6 do
		crystals[i] = makeCrystal(folder, 1 + (i % 3) * 0.4)
	end
	idleEggs[egg] = { home = egg.CFrame, crystals = crystals, folder = folder, hidden = false }
	egg.AncestryChanged:Connect(function()
		if not egg:IsDescendantOf(workspace) and idleEggs[egg] then
			idleEggs[egg].folder:Destroy()
			idleEggs[egg] = nil
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
	for egg, data in idleEggs do
		if data.hidden then
			continue
		end
		-- Client-side CFrame/colour changes only affect this player's view.
		egg.CFrame = data.home * CFrame.new(0, math.sin(t * 2) * 0.35, 0) * CFrame.Angles(0, t * 0.6, math.sin(t * 1.5) * 0.05)
		egg.Color = col
		local glow = egg:FindFirstChild("Glow")
		if glow then
			glow.OutlineColor = shellColor(t + Config.ShellCycleSeconds / 2)
		end
		local light = egg:FindFirstChild("Light")
		if light then
			light.Color = col
			light.Brightness = 2.5 + math.sin(t * 3) * 1
		end
		for i, crystal in data.crystals do
			local a = t * 0.5 + i / #data.crystals * math.pi * 2
			local r = 5 + math.sin(t + i) * 0.6
			local pos = data.home.Position + Vector3.new(math.cos(a) * r, math.sin(t * 1.3 + i) * 1.2 + 0.5, math.sin(a) * r)
			crystal.CFrame = CFrame.new(pos) * CFrame.Angles(t + i, t * 0.7 + i, 0.4)
		end
	end
end)

local function setEggVisible(egg: BasePart, visible: boolean)
	local data = idleEggs[egg]
	if data then
		data.hidden = not visible
		data.folder.Parent = if visible then workspace else nil
	end
	-- Client-side changes, so the egg only disappears for this player.
	egg.Transparency = if visible then 0 else 1
	for _, d in egg:GetDescendants() do
		if d:IsA("ParticleEmitter") or d:IsA("Light") or d:IsA("ProximityPrompt") or d:IsA("Highlight") then
			d.Enabled = visible
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
		local pm = require(player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule"))
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

-- A random point on the egg's surface (in egg-local space), front-facing.
local function surfacePoint(size: Vector3, theta: number, phi: number): Vector3
	return Vector3.new(
		math.sin(phi) * math.cos(theta) * size.X / 2,
		math.cos(phi) * size.Y / 2,
		math.sin(phi) * math.sin(theta) * size.Z / 2
	)
end

-- Glowing zig-zag crack across the shell made of Beams.
local function makeCrack(eggPart: BasePart, size: Vector3, color: Color3): { Beam }
	local beams = {}
	local theta = math.random() * math.pi * 2
	local phi = math.rad(math.random(40, 140))
	local prev = Instance.new("Attachment")
	prev.Position = surfacePoint(size * 1.02, theta, phi)
	prev.Parent = eggPart
	for _ = 1, 5 do
		theta += math.rad(math.random(10, 25))
		phi += math.rad(math.random(-25, 25))
		phi = math.clamp(phi, 0.3, math.pi - 0.3)
		local nxt = Instance.new("Attachment")
		nxt.Position = surfacePoint(size * 1.02, theta, phi)
		nxt.Parent = eggPart
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
		beam.Parent = eggPart
		table.insert(beams, beam)
		prev = nxt
	end
	return beams
end

---------------------------------------------------------------------------
-- The cutscene
---------------------------------------------------------------------------

local playing = false

local function playCutscene(realEgg: BasePart)
	if playing then
		return
	end
	playing = true

	local home = idleEggs[realEgg] and idleEggs[realEgg].home or realEgg.CFrame
	local origin = home.Position
	setEggVisible(realEgg, false)
	setControls(false)

	local fx = Instance.new("Folder")
	fx.Name = "RainbowEggCutscene"
	fx.Parent = workspace

	-- Local copy of the egg that we can shake, crack and blow up.
	local size = Config.EggSize
	local egg = neonPart(fx, size, C.Magenta)
	egg.CFrame = CFrame.new(origin)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = egg
	local hl = Instance.new("Highlight")
	hl.FillColor = C.Silver
	hl.FillTransparency = 0.85
	hl.OutlineColor = C.Ice
	hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	hl.Parent = egg
	local light = Instance.new("PointLight")
	light.Color = C.Magenta
	light.Brightness = 3
	light.Range = 20
	light.Parent = egg

	-- Egg aura, stronger than the idle one.
	local aura = Instance.new("ParticleEmitter")
	aura.Texture = "rbxasset://textures/particles/fire_main.dds"
	aura.Color = Config.AuraSequence
	aura.LightEmission = 1
	aura.LightInfluence = 0
	aura.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2.5), NumberSequenceKeypoint.new(1, 0) })
	aura.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 1) })
	aura.Lifetime = NumberRange.new(0.5, 1)
	aura.Rate = 60
	aura.Speed = NumberRange.new(3, 6)
	aura.Acceleration = Vector3.new(0, 10, 0)
	aura.Shape = Enum.ParticleEmitterShape.Sphere
	aura.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
	aura.Parent = egg

	-- Energy streams pulled in from all around.
	local pullField = neonPart(fx, Vector3.new(40, 40, 40), C.Violet, Enum.PartType.Ball)
	pullField.Transparency = 1
	pullField.CFrame = CFrame.new(origin)
	local streams = Instance.new("ParticleEmitter")
	streams.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	streams.Color = Config.SparkleSequence
	streams.LightEmission = 1
	streams.LightInfluence = 0
	streams.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 0.8) })
	streams.Lifetime = NumberRange.new(0.8, 1)
	streams.Rate = 0
	streams.Speed = NumberRange.new(18, 22)
	streams.Shape = Enum.ParticleEmitterShape.Sphere
	streams.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
	streams.ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward
	streams.Parent = pullField

	-- Purple colour grade + bloom on the whole screen.
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "RainbowEggGrade"
	cc.TintColor = Color3.new(1, 1, 1)
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
	flash.BackgroundColor3 = C.Silver
	flash.BackgroundTransparency = 1
	flash.BorderSizePixel = 0
	flash.ZIndex = 5
	flash.Parent = gui
	local flashGrad = Instance.new("UIGradient")
	flashGrad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, C.Magenta),
		ColorSequenceKeypoint.new(0.5, Color3.new(1, 1, 1)),
		ColorSequenceKeypoint.new(1, C.Violet),
	})
	flashGrad.Parent = flash

	-- Camera: swing round to face the egg.
	local savedType = camera.CameraType
	local savedCF = camera.CFrame
	local savedFov = camera.FieldOfView
	camera.CameraType = Enum.CameraType.Scriptable
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local fromDir = root and (root.Position - origin) * Vector3.new(1, 0, 1) or Vector3.new(0, 0, 1)
	if fromDir.Magnitude < 0.1 then
		fromDir = Vector3.new(0, 0, 1)
	end
	local camPos = origin + fromDir.Unit * 14 + Vector3.new(0, 2.5, 0)
	local camBase = CFrame.lookAt(camPos, origin)
	tween(camera, 0.8, { CFrame = camBase }, Enum.EasingStyle.Sine)
	task.wait(0.8)

	-------------------------------------------------------------- charge-up
	local cracks: { { Beam } } = {}
	local crackColors = { C.Silver, C.Cyan, C.Pink, C.Silver, C.Magenta, C.Ice, C.Silver }
	local start = os.clock()
	while true do
		local k = math.min(1, (os.clock() - start) / Config.ChargeSeconds)
		local t = os.clock()
		local shake = k * k * 0.5
		egg.CFrame = CFrame.new(origin)
			* CFrame.Angles(0, 0, math.sin(t * 40) * 0.12 * k)
			* CFrame.new((math.random() - 0.5) * shake, (math.random() - 0.5) * shake, 0)
		local pulse = 1 + math.sin(t * 20) * 0.03 * k
		mesh.Scale = Vector3.new(pulse, 1 / pulse, pulse)
		egg.Color = shellColor(t * (1 + k * 4)):Lerp(C.Silver, k * 0.5)
		hl.FillTransparency = 0.85 - k * 0.6
		light.Brightness = 3 + k * 12
		light.Color = egg.Color
		aura.Rate = 60 + k * 200
		streams.Rate = 30 + k * 250
		cc.TintColor = Color3.new(1, 1, 1):Lerp(Color3.fromRGB(220, 170, 255), k)
		cc.Saturation = k * 0.4
		bloom.Intensity = 0.4 + k * 1.5
		camera.FieldOfView = savedFov - k * 18
		camera.CFrame = camBase * CFrame.new((math.random() - 0.5) * shake * 0.5, (math.random() - 0.5) * shake * 0.5, 0)

		-- Cracks appear in stages and grow in.
		while #cracks < math.floor(k * 7) do
			local crack = makeCrack(egg, size, crackColors[#cracks + 1])
			table.insert(cracks, crack)
			for _, beam in crack do
				tween(beam, 0.25, { Width0 = 0.25, Width1 = 0.25 })
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
	egg.Transparency = 1
	hl.Enabled = false
	for _, crack in cracks do
		for _, beam in crack do
			beam.Enabled = false
		end
	end

	-- Shell shards flying out.
	local shardColors = { C.Violet, C.Magenta, C.Pink, C.Cyan, C.Silver }
	for i = 1, 24 do
		local shard = neonPart(fx, Vector3.new(math.random() * 0.8 + 0.4, 0.15, math.random() * 0.8 + 0.4), shardColors[i % #shardColors + 1])
		shard.Anchored = false
		shard.CFrame = CFrame.new(origin + Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 2)
			* CFrame.Angles(math.random() * 6, math.random() * 6, math.random() * 6)
		local dir = Vector3.new(math.random() - 0.5, math.random() * 0.8 + 0.2, math.random() - 0.5).Unit
		shard.AssemblyLinearVelocity = dir * (math.random(25, 45))
		shard.AssemblyAngularVelocity = Vector3.new(math.random(-15, 15), math.random(-15, 15), math.random(-15, 15))
		Debris:AddItem(shard, 3)
	end

	-- Ice crystals shattering outwards.
	for _ = 1, 12 do
		local cr = makeCrystal(fx, 0.8 + math.random() * 1.2)
		cr.Anchored = false
		cr.CFrame = CFrame.new(origin)
		cr.AssemblyLinearVelocity = Vector3.new(math.random() - 0.5, math.random() * 0.6, math.random() - 0.5).Unit * math.random(20, 35)
		cr.AssemblyAngularVelocity = Vector3.new(math.random(-8, 8), math.random(-8, 8), math.random(-8, 8))
		Debris:AddItem(cr, 3)
	end

	-- Sparkle explosion.
	local burst = Instance.new("ParticleEmitter")
	burst.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	burst.Color = Config.SparkleSequence
	burst.LightEmission = 1
	burst.LightInfluence = 0
	burst.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0) })
	burst.Lifetime = NumberRange.new(1, 2)
	burst.Speed = NumberRange.new(15, 40)
	burst.Drag = 3
	burst.SpreadAngle = Vector2.new(180, 180)
	burst.Rate = 0
	burst.Parent = egg
	burst:Emit(200)

	camera.FieldOfView = savedFov
	camera.CFrame = camBase * CFrame.new(0, 0, 3)
	tween(camera, 1.5, { CFrame = camBase }, Enum.EasingStyle.Sine)
	tween(cc, 1.5, { TintColor = Color3.fromRGB(235, 215, 255), Saturation = 0.25 })
	tween(bloom, 1.5, { Intensity = 1 })

	-------------------------------------------------------------- reveal
	-- The radiant silver-violet energy core with orbiting coloured lights.
	local core = neonPart(fx, Vector3.new(0.5, 0.5, 0.5), Color3.new(1, 1, 1), Enum.PartType.Ball)
	core.CFrame = CFrame.new(origin)
	tween(core, 0.6, { Size = Vector3.new(3, 3, 3) }, Enum.EasingStyle.Back)
	local coreHl = Instance.new("Highlight")
	coreHl.FillColor = C.Silver
	coreHl.FillTransparency = 0.3
	coreHl.OutlineColor = C.Magenta
	coreHl.Parent = core
	local coreLight = Instance.new("PointLight")
	coreLight.Color = C.Ice
	coreLight.Brightness = 8
	coreLight.Range = 30
	coreLight.Parent = core
	local coreAura = aura:Clone()
	coreAura.Enabled = true
	coreAura.Rate = 120
	coreAura.Parent = core

	local orbiters = {}
	for i, col in { C.Cyan, C.Pink, C.Magenta, C.Ice } do
		local orb = neonPart(fx, Vector3.new(0.6, 0.6, 0.6), col, Enum.PartType.Ball)
		local a0 = Instance.new("Attachment")
		a0.Position = Vector3.new(0, 0.25, 0)
		a0.Parent = orb
		local a1 = Instance.new("Attachment")
		a1.Position = Vector3.new(0, -0.25, 0)
		a1.Parent = orb
		local trail = Instance.new("Trail")
		trail.Attachment0 = a0
		trail.Attachment1 = a1
		trail.Color = ColorSequence.new(col, C.Silver)
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
	title.Text = Config.RevealText
	title.TextColor3 = Color3.new(1, 1, 1)
	title.TextTransparency = 1
	title.ZIndex = 6
	title.Parent = gui
	local titleGrad = Instance.new("UIGradient")
	titleGrad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, C.Cyan),
		ColorSequenceKeypoint.new(0.25, C.Violet),
		ColorSequenceKeypoint.new(0.5, C.Pink),
		ColorSequenceKeypoint.new(0.75, C.Magenta),
		ColorSequenceKeypoint.new(1, C.Cyan),
	})
	titleGrad.Parent = title
	local stroke = Instance.new("UIStroke")
	stroke.Color = C.Indigo
	stroke.Thickness = 3
	stroke.Transparency = 1
	stroke.Parent = title
	tween(title, 0.6, { TextTransparency = 0 })
	tween(stroke, 0.6, { Transparency = 0 })

	local revealStart = os.clock()
	local conn = RunService.RenderStepped:Connect(function()
		local t = os.clock() - revealStart
		local pulse = 1 + math.sin(t * 6) * 0.08
		core.CFrame = CFrame.new(origin + Vector3.new(0, math.sin(t * 2) * 0.3, 0))
		coreHl.OutlineColor = shellColor(t * 2)
		coreLight.Brightness = 8 * pulse
		for i, orb in orbiters do
			local a = t * 3 + i / #orbiters * math.pi * 2
			local tilt = CFrame.Angles(i * 0.8, 0, i * 0.5)
			orb.CFrame = CFrame.new(origin) * tilt * CFrame.new(math.cos(a) * 3.2, 0, math.sin(a) * 3.2)
		end
		titleGrad.Offset = Vector2.new(math.sin(t * 1.5) * 0.3, 0)
		title.Rotation = math.sin(t * 2) * 2
		-- slow push-in with a gentle roll
		local camAt = origin + (camBase.Position - origin) * (1 - math.min(t, 3) * 0.05)
		camera.CFrame = CFrame.lookAt(camAt, origin) * CFrame.Angles(0, 0, math.sin(t) * 0.02)
	end)

	task.wait(Config.RevealSeconds)

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
	camera.CameraType = savedType
	if savedType == Enum.CameraType.Scriptable then
		camera.CFrame = savedCF
	end
	setControls(true)
	if not Config.OncePerPlayer then
		setEggVisible(realEgg, true)
	end
	playing = false
end

ReplicatedStorage:WaitForChild("RainbowEggHatch").OnClientEvent:Connect(function(egg: BasePart)
	if egg and egg:IsA("BasePart") then
		playCutscene(egg)
	end
end)
