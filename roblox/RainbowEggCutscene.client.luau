--[[
	RAINBOW EGG CUTSCENE
	Put this LocalScript INSIDE the "RainbowEgg" Script (which is inside your egg).
	The RainbowEgg script hands it to players automatically.

	It animates the rainbow egg (colour cycling, bobbing, orbiting ice crystals)
	and plays the hatch cutscene: the world fades into an Ultra Instinct space
	void with rising violet ki bubbles and anime speed lines, then the egg
	charges up, cracks and bursts into a silver energy core.
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

-- Ultra Instinct colours: deep space blue-black, violet ki bubbles,
-- lavender light and a silver-white/ice glow.
local VOID = Color3.fromRGB(5, 3, 14)
local NEBULA = Color3.fromRGB(34, 22, 110)
local LAVENDER = Color3.fromRGB(170, 120, 255)
local VIOLET = Color3.fromRGB(106, 44, 255)
local MAGENTA = Color3.fromRGB(196, 60, 255)
local ICE = Color3.fromRGB(168, 232, 255)
local SILVER = Color3.fromRGB(244, 240, 255)

local SHELL_CYCLE = { VIOLET, LAVENDER, ICE, LAVENDER, MAGENTA, VIOLET }
local CYCLE_SECONDS = 6

local AURA_COLORS = ColorSequence.new({
	ColorSequenceKeypoint.new(0, SILVER),
	ColorSequenceKeypoint.new(0.3, ICE),
	ColorSequenceKeypoint.new(0.65, LAVENDER),
	ColorSequenceKeypoint.new(1, VIOLET),
})
local SPARKLE_COLORS = ColorSequence.new({
	ColorSequenceKeypoint.new(0, SILVER),
	ColorSequenceKeypoint.new(0.5, ICE),
	ColorSequenceKeypoint.new(1, LAVENDER),
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
-- Cutscene scenery: the Ultra Instinct void, ki bubbles and speed lines
---------------------------------------------------------------------------

local GLOW_TEXTURE = "rbxasset://textures/particles/forcefield_glow_main.dds"
local SPARKLE_TEXTURE = "rbxasset://textures/particles/sparkles_main.dds"
local FIRE_TEXTURE = "rbxasset://textures/particles/fire_main.dds"
local SHOCKWAVE_TEXTURE = "rbxasset://textures/particles/explosion01_shockwave_main.dds"

local function kp(time: number, value: number, envelope: number?): NumberSequenceKeypoint
	return NumberSequenceKeypoint.new(time, value, envelope or 0)
end

-- Eases 0..1 in and out, so nothing starts or stops with a jolt.
local function smooth(k: number): number
	k = math.clamp(k, 0, 1)
	return k * k * (3 - 2 * k)
end

local function numberValue(value: number): NumberValue
	local v = Instance.new("NumberValue")
	v.Value = value
	return v
end

-- A huge dark wall behind the egg, facing the camera, with a glowing violet
-- column and twinkling stars painted on it: the space behind Ultra Instinct.
local function makeVoid(parent: Instance, camBase: CFrame, origin: Vector3, scale: number)
	local wall = neonPart(parent, Vector3.new(math.min(400 * scale, 2048), math.min(200 * scale, 2048), 1), VOID)
	wall.Name = "Void"
	wall.Transparency = 1
	wall.CFrame = camBase.Rotation + (origin + camBase.LookVector * 70 * scale)

	local sg = Instance.new("SurfaceGui")
	sg.Face = Enum.NormalId.Back -- the side facing the camera
	sg.LightInfluence = 0
	sg.Brightness = 1.6
	sg.CanvasSize = Vector2.new(1000, 500)
	sg.Parent = wall

	-- Soft nebula column: stacked, see-through ellipses fake a radial glow.
	local layers = {}
	local nebula = {
		{ Vector2.new(0.46, 1.1), NEBULA, 0.55 },
		{ Vector2.new(0.3, 0.9), NEBULA, 0.5 },
		{ Vector2.new(0.2, 0.75), VIOLET, 0.72 },
		{ Vector2.new(0.12, 0.6), LAVENDER, 0.8 },
		{ Vector2.new(0.05, 0.4), ICE, 0.88 },
	}
	for i, n in nebula do
		local f = Instance.new("Frame")
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.Position = UDim2.fromScale(0.5, 0.5)
		f.Size = UDim2.fromScale(n[1].X, n[1].Y)
		f.BackgroundColor3 = n[2]
		f.BackgroundTransparency = 1
		f.BorderSizePixel = 0
		f.ZIndex = i
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.5, 0)
		corner.Parent = f
		f.Parent = sg
		layers[i] = { frame = f, base = n[3], phase = i * 1.3 }
	end

	local stars = {}
	for i = 1, 110 do
		local f = Instance.new("Frame")
		local s = math.random(2, 5)
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.Position = UDim2.fromScale(0.18 + math.random() * 0.64, 0.18 + math.random() * 0.64)
		f.Size = UDim2.fromOffset(s, s)
		f.BackgroundColor3 = if math.random() < 0.6 then SILVER else ICE
		f.BackgroundTransparency = 1
		f.BorderSizePixel = 0
		f.ZIndex = 10
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.5, 0)
		corner.Parent = f
		f.Parent = sg
		stars[i] = { frame = f, phase = math.random() * 6.28, speed = 0.8 + math.random() * 2.5 }
	end

	return function(alpha: number, t: number)
		wall.Transparency = 1 - alpha
		for _, l in layers do
			-- slow breathing glow
			local breathe = 1 + math.sin(t * 0.9 + l.phase) * 0.08
			l.frame.BackgroundTransparency = 1 - (1 - l.base) * alpha * breathe
		end
		for _, s in stars do
			local twinkle = 0.55 + 0.45 * math.sin(t * s.speed + s.phase)
			s.frame.BackgroundTransparency = 1 - alpha * twinkle
		end
	end
end

-- Anime speed lines rushing in toward the middle of the screen.
local function makeSpeedLines(gui: ScreenGui)
	local lines = {}
	for i = 1, 64 do
		local f = Instance.new("Frame")
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.BorderSizePixel = 0
		f.BackgroundTransparency = 1
		f.ZIndex = 2
		-- fades away toward the centre of the screen
		local g = Instance.new("UIGradient")
		g.Transparency = NumberSequence.new({ kp(0, 1), kp(0.6, 0.35), kp(1, 0) })
		g.Parent = f
		f.Parent = gui
		local life = 0.3 + math.random() * 0.35
		lines[i] = { frame = f, life = life, age = math.random() * life, angle = 0, len = 0, thick = 1, alpha = 0 }
	end

	local function respawn(l, radius: number)
		l.age = 0
		l.life = 0.3 + math.random() * 0.35
		l.angle = math.random() * math.pi * 2
		l.len = (0.2 + math.random() * 0.35) * radius
		l.thick = 1 + math.random() * 3
		l.alpha = 0.25 + math.random() * 0.55
		l.frame.BackgroundColor3 = if math.random() < 0.7 then SILVER else LAVENDER
	end

	return function(dt: number, intensity: number)
		local radius = gui.AbsoluteSize.Magnitude / 2
		for _, l in lines do
			l.age += dt
			if l.age >= l.life or l.len == 0 then
				respawn(l, radius)
			end
			local p = l.age / l.life
			-- the outer end slides inward while the line fades in and out
			local outer = radius * (1.05 - p * 0.4)
			local mid = outer - l.len / 2
			local f = l.frame
			f.Position = UDim2.new(0.5, math.cos(l.angle) * mid, 0.5, math.sin(l.angle) * mid)
			f.Size = UDim2.fromOffset(l.len, l.thick)
			f.Rotation = math.deg(l.angle)
			f.BackgroundTransparency = 1 - l.alpha * math.sin(p * math.pi) * intensity
		end
	end
end

-- Violet ki bubbles and tiny star specks drifting up through the scene.
local function makeKiBubbles(parent: Instance, origin: Vector3, camBase: CFrame, scale: number)
	local look = (camBase.LookVector * Vector3.new(1, 0, 1)).Unit
	local centre = origin + look * 6 * scale - Vector3.new(0, 9 * scale, 0)
	local source = neonPart(parent, Vector3.new(36, 1, 20) * scale, VIOLET)
	source.Name = "KiBubbleSource"
	source.Transparency = 1
	source.CFrame = CFrame.lookAt(centre, centre + look)

	local bubbles = Instance.new("ParticleEmitter")
	bubbles.Texture = GLOW_TEXTURE
	bubbles.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, MAGENTA),
		ColorSequenceKeypoint.new(0.4, LAVENDER),
		ColorSequenceKeypoint.new(1, VIOLET),
	})
	bubbles.LightEmission = 1
	bubbles.LightInfluence = 0
	bubbles.Brightness = 2
	bubbles.Size = NumberSequence.new({ kp(0, 0), kp(0.2, 0.9 * scale, 0.45 * scale), kp(0.8, 0.7 * scale, 0.35 * scale), kp(1, 0) })
	bubbles.Transparency = NumberSequence.new({ kp(0, 1), kp(0.2, 0.15), kp(0.75, 0.35), kp(1, 1) })
	bubbles.Squash = NumberSequence.new({ kp(0, 0), kp(0.4, 0.25), kp(0.7, -0.2), kp(1, 0.1) })
	bubbles.Lifetime = NumberRange.new(3.5, 6)
	bubbles.Speed = NumberRange.new(2.5 * scale, 5 * scale)
	bubbles.SpreadAngle = Vector2.new(12, 12)
	bubbles.Acceleration = Vector3.new(0, 0.6 * scale, 0)
	bubbles.Drag = 0.2
	bubbles.Rotation = NumberRange.new(0, 360)
	bubbles.RotSpeed = NumberRange.new(-40, 40)
	bubbles.Rate = 0
	bubbles.Parent = source

	local specks = Instance.new("ParticleEmitter")
	specks.Texture = SPARKLE_TEXTURE
	specks.Color = ColorSequence.new(SILVER, ICE)
	specks.LightEmission = 1
	specks.LightInfluence = 0
	specks.Size = NumberSequence.new({ kp(0, 0.25 * scale, 0.1 * scale), kp(1, 0.1 * scale) })
	specks.Transparency = NumberSequence.new({ kp(0, 1), kp(0.25, 0), kp(0.5, 0.7), kp(0.75, 0), kp(1, 1) })
	specks.Lifetime = NumberRange.new(2.5, 4.5)
	specks.Speed = NumberRange.new(1 * scale, 3 * scale)
	specks.Rate = 0
	specks.Parent = source

	return bubbles, specks
end

-- A glowing ring that grows and fades. Flat rings lie horizontally,
-- the others face the camera.
local function shockwave(parent: BasePart, color: Color3, size: number, life: number, flat: boolean)
	local e = Instance.new("ParticleEmitter")
	e.Texture = SHOCKWAVE_TEXTURE
	e.Color = ColorSequence.new(color)
	e.LightEmission = 1
	e.LightInfluence = 0
	e.Brightness = 3
	e.Size = NumberSequence.new({ kp(0, size * 0.05), kp(1, size) })
	e.Transparency = NumberSequence.new({ kp(0, 0), kp(0.6, 0.4), kp(1, 1) })
	e.Lifetime = NumberRange.new(life)
	e.Speed = NumberRange.new(0.01)
	e.EmissionDirection = Enum.NormalId.Top
	e.LockedToPart = true
	e.Rate = 0
	if flat then
		e.Orientation = Enum.ParticleOrientation.VelocityPerpendicular
	end
	e.Parent = parent
	e:Emit(1)
end

local function setCharacterHidden(hidden: boolean)
	local character = player.Character
	if not character then
		return
	end
	for _, d in character:GetDescendants() do
		if d:IsA("BasePart") or d:IsA("Decal") then
			d.LocalTransparencyModifier = if hidden then 1 else 0
		end
	end
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
	local eggStart = pivotOf(egg)
	setEggVisible(realEgg, false)
	setControls(false)
	local eggParts = partsOf(egg)
	-- Silver-white rim light around the egg, like the glow around Ultra Instinct.
	local hl = Instance.new("Highlight")
	hl.FillColor = ICE
	hl.FillTransparency = 0.9
	hl.OutlineColor = SILVER
	hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	hl.Parent = egg

	-- Invisible centre part that holds the light, aura and cracks.
	local centre = neonPart(fx, size, LAVENDER)
	centre.Transparency = 1
	centre.CFrame = CFrame.new(origin)
	local light = Instance.new("PointLight")
	light.Color = LAVENDER
	light.Brightness = 3
	light.Range = 20 * scale
	light.Parent = centre

	local aura = Instance.new("ParticleEmitter")
	aura.Texture = FIRE_TEXTURE
	aura.Color = AURA_COLORS
	aura.LightEmission = 1
	aura.LightInfluence = 0
	aura.Size = NumberSequence.new({ kp(0, 2.2 * scale), kp(1, 0) })
	aura.Transparency = NumberSequence.new({ kp(0, 1), kp(0.15, 0.45), kp(1, 1) })
	aura.Lifetime = NumberRange.new(0.6, 1.1)
	aura.Rate = 40
	aura.Speed = NumberRange.new(2 * scale, 4 * scale)
	aura.Acceleration = Vector3.new(0, 9 * scale, 0)
	aura.Shape = Enum.ParticleEmitterShape.Sphere
	aura.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
	aura.Parent = centre

	-- Energy streams pulled in from all around.
	local pullField = neonPart(fx, Vector3.new(40, 40, 40) * scale, VIOLET, Enum.PartType.Ball)
	pullField.Transparency = 1
	pullField.CFrame = CFrame.new(origin)
	local streams = Instance.new("ParticleEmitter")
	streams.Texture = SPARKLE_TEXTURE
	streams.Color = SPARKLE_COLORS
	streams.LightEmission = 1
	streams.LightInfluence = 0
	streams.Size = NumberSequence.new({ kp(0, 0.3 * scale), kp(1, 0.8 * scale) })
	streams.Transparency = NumberSequence.new({ kp(0, 1), kp(0.3, 0), kp(1, 0) })
	streams.Lifetime = NumberRange.new(0.8, 1)
	streams.Rate = 0
	streams.Speed = NumberRange.new(18 * scale, 22 * scale)
	streams.Shape = Enum.ParticleEmitterShape.Sphere
	streams.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
	streams.ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward
	streams.Parent = pullField

	-- Dim the world so only the glowing effects stand out, then grade it violet.
	local savedLighting = {
		Brightness = Lighting.Brightness,
		Ambient = Lighting.Ambient,
		OutdoorAmbient = Lighting.OutdoorAmbient,
	}
	local dark = Color3.fromRGB(20, 12, 48)
	tween(Lighting, 1.2, { Brightness = 0, Ambient = dark, OutdoorAmbient = dark }, Enum.EasingStyle.Sine)

	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "RainbowEggGrade"
	cc.Parent = Lighting
	tween(cc, 1.2, { TintColor = Color3.fromRGB(215, 200, 255), Contrast = 0.15, Saturation = 0.15 }, Enum.EasingStyle.Sine)
	local bloom = Instance.new("BloomEffect")
	bloom.Name = "RainbowEggBloom"
	bloom.Intensity = 0
	bloom.Size = 40
	bloom.Threshold = 1.2
	bloom.Parent = Lighting
	tween(bloom, 1.2, { Intensity = 0.7 }, Enum.EasingStyle.Sine)
	local dof = Instance.new("DepthOfFieldEffect")
	dof.Name = "RainbowEggFocus"
	dof.FocusDistance = 14 * scale
	dof.InFocusRadius = 6 * scale
	dof.NearIntensity = 0.5
	dof.FarIntensity = 0.25
	dof.Parent = Lighting

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
		f.ZIndex = 4
		f.Parent = gui
		return f
	end
	local topBar, bottomBar = bar(0), bar(1)
	tween(topBar, 0.9, { Size = UDim2.fromScale(1, 0.1) }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
	tween(bottomBar, 0.9, { Size = UDim2.fromScale(1, 0.1) }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)

	-- Black "impact frame" overlay used for a split second before the burst.
	local impact = Instance.new("Frame")
	impact.Size = UDim2.fromScale(1, 1)
	impact.BackgroundColor3 = Color3.new(0, 0, 0)
	impact.BackgroundTransparency = 1
	impact.BorderSizePixel = 0
	impact.ZIndex = 3
	impact.Parent = gui

	local flash = Instance.new("Frame")
	flash.Size = UDim2.fromScale(1, 1)
	flash.BackgroundColor3 = Color3.new(1, 1, 1)
	flash.BackgroundTransparency = 1
	flash.BorderSizePixel = 0
	flash.ZIndex = 5
	flash.Parent = gui
	local flashGrad = Instance.new("UIGradient")
	flashGrad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, LAVENDER),
		ColorSequenceKeypoint.new(0.5, Color3.new(1, 1, 1)),
		ColorSequenceKeypoint.new(1, ICE),
	})
	flashGrad.Rotation = 90
	flashGrad.Parent = flash

	-- Camera: every shot is an orbit around the egg, driven by tweened values,
	-- so the camera always glides instead of jumping.
	local savedType = camera.CameraType
	local savedFov = camera.FieldOfView
	local startCF = camera.CFrame
	camera.CameraType = Enum.CameraType.Scriptable
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local fromDir = if root then (root.Position - origin) * Vector3.new(1, 0, 1) else Vector3.new(0, 0, 1)
	if fromDir.Magnitude < 0.1 then
		fromDir = Vector3.new(0, 0, 1)
	end
	local camOffset = fromDir.Unit * 14 * scale + Vector3.new(0, 2.5 * scale, 0)
	local camBase = CFrame.lookAt(origin + camOffset, origin)

	local camBlend = numberValue(0) -- 0 = player's camera, 1 = cutscene camera
	local camAngle = numberValue(0)
	local camDist = numberValue(1)
	local camShake = numberValue(0)
	local camFov = numberValue(savedFov)
	local voidAlpha = numberValue(0)
	local speedLines = numberValue(0)

	local function orbitCF(angle: number, dist: number): CFrame
		return CFrame.lookAt(origin + CFrame.Angles(0, angle, 0) * (camOffset * dist), origin)
	end

	local updateVoid = makeVoid(fx, camBase, origin, scale)
	local updateSpeedLines = makeSpeedLines(gui)
	local bubbles, specks = makeKiBubbles(fx, origin, camBase, scale)
	tween(bubbles, 1.2, { Rate = 22 })
	tween(specks, 1.2, { Rate = 25 })

	local sceneStart = os.clock()
	local fxConn = RunService.RenderStepped:Connect(function(dt)
		local t = os.clock() - sceneStart
		updateVoid(voidAlpha.Value, t)
		updateSpeedLines(dt, speedLines.Value)
		setCharacterHidden(true)

		-- smooth noise shake instead of random jitter
		local s = camShake.Value
		local shake = CFrame.new(math.noise(t * 9, 0.5) * s, math.noise(1.7, t * 9) * s, 0)
			* CFrame.Angles(0, 0, math.noise(t * 5, 3.3) * s * 0.05)
		local target = orbitCF(camAngle.Value, camDist.Value)
		local cf = if camBlend.Value < 1 then startCF:Lerp(target, camBlend.Value) else target
		camera.CFrame = cf * shake
		camera.FieldOfView = camFov.Value
	end)

	tween(camBlend, 1.3, { Value = 1 }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
	tween(voidAlpha, 1.5, { Value = 1 }, Enum.EasingStyle.Sine)
	task.wait(1.3)

	-------------------------------------------------------------- charge-up
	local cracks: { { Beam } } = {}
	local crackColors = { SILVER, ICE, LAVENDER, SILVER, ICE, SILVER, LAVENDER }
	local start = os.clock()
	local last = start
	local spin = 0
	while true do
		local now = os.clock()
		local dt = now - last
		last = now
		local k = math.min(1, (now - start) / chargeSeconds)
		local ek = smooth(k)

		-- the egg spins faster and faster and trembles harder
		spin += dt * (0.6 + ek * 9)
		local tremble = k * k * 0.25 * scale
		local jiggle = CFrame.new(math.noise(now * 14, 0.2) * tremble, math.noise(0.9, now * 14) * tremble, math.noise(now * 14, 5.1) * tremble)
			* CFrame.Angles(0, 0, math.noise(now * 10, 8.4) * 0.25 * k)
		;(egg :: any):PivotTo(eggStart * CFrame.Angles(0, spin, 0) * jiggle)
		centre.CFrame = CFrame.new(origin) * jiggle

		local col = shellColor(now * (1 + ek * 3)):Lerp(SILVER, ek * 0.6)
		for _, p in eggParts do
			p.Color = col
		end
		hl.FillTransparency = 0.9 - ek * 0.6
		hl.OutlineTransparency = math.max(0, 0.3 * (1 - ek) + math.sin(now * 12) * 0.15 * ek)
		light.Brightness = 3 + ek * 12
		light.Color = col
		aura.Rate = 40 + ek * 220
		streams.Rate = 20 + ek * 260
		bubbles.Rate = 22 + ek * 60
		bloom.Intensity = 0.7 + ek * 1.3

		-- slow orbit and push-in while the tension builds
		camAngle.Value = math.rad(18) * ek
		camDist.Value = 1 - 0.28 * ek
		camFov.Value = savedFov - 14 * ek
		camShake.Value = k * k * 0.35 * scale
		speedLines.Value = smooth((k - 0.25) / 0.75)

		-- Cracks appear in stages and grow in.
		while #cracks < math.floor(k * 7) do
			local crack = makeCrack(centre, size, crackColors[#cracks + 1])
			table.insert(cracks, crack)
			for _, beam in crack do
				tween(beam, 0.3, { Width0 = 0.22 * scale, Width1 = 0.22 * scale }, Enum.EasingStyle.Sine)
			end
		end

		if k >= 1 then
			break
		end
		RunService.RenderStepped:Wait()
	end

	-------------------------------------------------------------- impact frames
	-- Two split-second black-and-white anime impact frames before the burst.
	streams.Rate = 0
	aura.Enabled = false
	speedLines.Value = 1
	cc.TintColor = Color3.new(1, 1, 1)
	cc.Saturation = -1
	cc.Contrast = 1
	impact.BackgroundTransparency = 0.3
	task.wait(0.07)
	impact.BackgroundTransparency = 1
	cc.Brightness = 0.25
	task.wait(0.07)

	-------------------------------------------------------------- burst
	cc.Brightness = 0
	flash.BackgroundTransparency = 0
	tween(flash, 1.4, { BackgroundTransparency = 1 }, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
	tween(cc, 1.4, { TintColor = Color3.fromRGB(225, 212, 255), Saturation = 0.2, Contrast = 0.15 }, Enum.EasingStyle.Sine)
	tween(bloom, 1.6, { Intensity = 1.1 }, Enum.EasingStyle.Sine)
	egg:Destroy()
	for _, crack in cracks do
		for _, beam in crack do
			beam.Enabled = false
		end
	end

	-- Camera kicks back from the blast, then glides in again.
	camDist.Value = 1.05
	camFov.Value = savedFov + 6
	camShake.Value = 0.9 * scale
	tween(camDist, 1.8, { Value = 0.82 }, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
	tween(camFov, 1.8, { Value = savedFov - 4 }, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
	tween(camShake, 1.2, { Value = 0 }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	tween(speedLines, 2, { Value = 0.3 }, Enum.EasingStyle.Sine)

	-- Shockwave rings, one facing the camera and one flat on the ground.
	shockwave(centre, SILVER, 30 * scale, 0.7, false)
	shockwave(centre, LAVENDER, 40 * scale, 1, true)
	task.delay(0.12, function()
		shockwave(centre, ICE, 22 * scale, 0.8, false)
	end)

	-- A pillar of light shooting up through the sky.
	local pillarHeight = math.min(600 * scale, 2048)
	for _, layer in { { SILVER, 2.5, 0 }, { LAVENDER, 6, 0.55 } } do
		local pillar = neonPart(fx, Vector3.new(pillarHeight, 0.1, 0.1), layer[1], Enum.PartType.Cylinder)
		pillar.CFrame = CFrame.new(origin + Vector3.new(0, pillarHeight / 2 - 2 * scale, 0)) * CFrame.Angles(0, 0, math.pi / 2)
		pillar.Transparency = layer[3]
		local w = layer[2] * scale
		tween(pillar, 0.15, { Size = Vector3.new(pillarHeight, w, w) }, Enum.EasingStyle.Quad)
		task.delay(0.15, function()
			tween(pillar, 1.3, { Size = Vector3.new(pillarHeight, 0.05, 0.05), Transparency = 1 }, Enum.EasingStyle.Quart, Enum.EasingDirection.In)
		end)
	end

	-- Shell shards flying out.
	local shardColors = { VIOLET, LAVENDER, ICE, SILVER, MAGENTA }
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
		task.delay(1.5, function()
			if shard.Parent then
				tween(shard, 1, { Transparency = 1, Size = shard.Size * 0.3 })
			end
		end)
		Debris:AddItem(shard, 2.6)
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
		task.delay(1.5, function()
			if cr.Parent then
				tween(cr, 1, { Transparency = 1, Size = cr.Size * 0.3 })
			end
		end)
		Debris:AddItem(cr, 2.6)
	end

	-- Sparkles and ki bubbles bursting out.
	local burst = Instance.new("ParticleEmitter")
	burst.Texture = SPARKLE_TEXTURE
	burst.Color = SPARKLE_COLORS
	burst.LightEmission = 1
	burst.LightInfluence = 0
	burst.Size = NumberSequence.new({ kp(0, scale), kp(1, 0) })
	burst.Lifetime = NumberRange.new(1, 2)
	burst.Speed = NumberRange.new(15 * scale, 40 * scale)
	burst.Drag = 3
	burst.SpreadAngle = Vector2.new(180, 180)
	burst.Rate = 0
	burst.Parent = centre
	burst:Emit(180)

	local kiBurst = bubbles:Clone()
	kiBurst.Rate = 0
	kiBurst.Speed = NumberRange.new(10 * scale, 26 * scale)
	kiBurst.Drag = 2.5
	kiBurst.Lifetime = NumberRange.new(1.5, 3)
	kiBurst.SpreadAngle = Vector2.new(180, 180)
	kiBurst.Acceleration = Vector3.new(0, 2 * scale, 0)
	kiBurst.Parent = centre
	kiBurst:Emit(70)

	-------------------------------------------------------------- reveal
	-- The radiant silver energy core with orbiting violet and ice lights.
	local core = neonPart(fx, Vector3.new(0.5, 0.5, 0.5), Color3.new(1, 1, 1), Enum.PartType.Ball)
	core.CFrame = CFrame.new(origin)
	tween(core, 0.7, { Size = Vector3.new(3, 3, 3) * scale }, Enum.EasingStyle.Back)
	local coreHl = Instance.new("Highlight")
	coreHl.FillColor = SILVER
	coreHl.FillTransparency = 0.3
	coreHl.OutlineColor = ICE
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
	for i, col in { LAVENDER, ICE, VIOLET, SILVER } do
		local orb = neonPart(fx, Vector3.new(0.6, 0.6, 0.6) * scale, col, Enum.PartType.Ball)
		orb.CFrame = CFrame.new(origin)
		local a0 = Instance.new("Attachment")
		a0.Position = Vector3.new(0, 0.25 * scale, 0)
		a0.Parent = orb
		local a1 = Instance.new("Attachment")
		a1.Position = Vector3.new(0, -0.25 * scale, 0)
		a1.Parent = orb
		local trail = Instance.new("Trail")
		trail.Attachment0 = a0
		trail.Attachment1 = a1
		trail.Color = ColorSequence.new(col, VIOLET)
		trail.LightEmission = 1
		trail.LightInfluence = 0
		trail.Lifetime = 0.6
		trail.WidthScale = NumberSequence.new({ kp(0, 1), kp(1, 0) })
		trail.Transparency = NumberSequence.new({ kp(0, 0), kp(1, 1) })
		trail.Parent = orb
		orbiters[i] = orb
	end

	-- Title text with a slowly moving silver-violet gradient.
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
		ColorSequenceKeypoint.new(0, LAVENDER),
		ColorSequenceKeypoint.new(0.3, SILVER),
		ColorSequenceKeypoint.new(0.5, ICE),
		ColorSequenceKeypoint.new(0.7, SILVER),
		ColorSequenceKeypoint.new(1, LAVENDER),
	})
	titleGrad.Parent = title
	local stroke = Instance.new("UIStroke")
	stroke.Color = VIOLET
	stroke.Thickness = 3
	stroke.Transparency = 1
	stroke.Parent = title
	local titleScale = Instance.new("UIScale")
	titleScale.Scale = 0.6
	titleScale.Parent = title
	tween(title, 0.8, { TextTransparency = 0 }, Enum.EasingStyle.Sine)
	tween(stroke, 0.8, { Transparency = 0 }, Enum.EasingStyle.Sine)
	tween(titleScale, 0.8, { Scale = 1 }, Enum.EasingStyle.Back)

	-- Slow cinematic orbit around the core for the rest of the reveal.
	tween(camAngle, revealSeconds + 1, { Value = camAngle.Value + math.rad(40) }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)

	local revealStart = os.clock()
	local conn = RunService.RenderStepped:Connect(function()
		local t = os.clock() - revealStart
		core.CFrame = CFrame.new(origin + Vector3.new(0, math.sin(t * 2) * 0.3 * scale, 0))
		coreHl.OutlineColor = ICE:Lerp(LAVENDER, 0.5 + math.sin(t * 2.5) * 0.5)
		coreLight.Brightness = 8 * (1 + math.sin(t * 6) * 0.08)
		for i, orb in orbiters do
			local a = t * 2.6 + i / #orbiters * math.pi * 2
			local tilt = CFrame.Angles(i * 0.8, 0, i * 0.5)
			-- orbits open up smoothly from the centre
			local r = 3.2 * scale * smooth(t / 0.8)
			orb.CFrame = CFrame.new(origin) * tilt * CFrame.new(math.cos(a) * r, 0, math.sin(a) * r)
		end
		titleGrad.Offset = Vector2.new(math.sin(t * 1.2) * 0.35, 0)
		title.Rotation = math.sin(t * 1.5) * 1.5
	end)

	task.wait(revealSeconds)

	-------------------------------------------------------------- wrap up
	-- Everything fades out together while the camera glides back to the player.
	local outTime = 1
	tween(topBar, outTime, { Size = UDim2.fromScale(1, 0) }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
	tween(bottomBar, outTime, { Size = UDim2.fromScale(1, 0) }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
	tween(title, 0.6, { TextTransparency = 1 }, Enum.EasingStyle.Sine)
	tween(stroke, 0.6, { Transparency = 1 }, Enum.EasingStyle.Sine)
	tween(cc, outTime, { TintColor = Color3.new(1, 1, 1), Saturation = 0, Contrast = 0 }, Enum.EasingStyle.Sine)
	tween(bloom, outTime, { Intensity = 0 }, Enum.EasingStyle.Sine)
	tween(dof, outTime, { NearIntensity = 0, FarIntensity = 0 }, Enum.EasingStyle.Sine)
	tween(Lighting, outTime, savedLighting, Enum.EasingStyle.Sine)
	tween(voidAlpha, outTime, { Value = 0 }, Enum.EasingStyle.Sine)
	tween(speedLines, 0.6, { Value = 0 }, Enum.EasingStyle.Sine)
	tween(camBlend, outTime, { Value = 0 }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
	tween(camFov, outTime, { Value = savedFov }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
	tween(core, 0.6, { Size = Vector3.new(0.1, 0.1, 0.1) }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
	for _, orb in orbiters do
		tween(orb, 0.6, { Size = Vector3.new(0.05, 0.05, 0.05), Transparency = 1 }, Enum.EasingStyle.Sine)
	end
	coreAura.Enabled = false
	bubbles.Rate = 0
	specks.Rate = 0
	task.wait(outTime)

	conn:Disconnect()
	fxConn:Disconnect()
	setCharacterHidden(false)
	fx:Destroy()
	gui:Destroy()
	cc:Destroy()
	bloom:Destroy()
	dof:Destroy()
	for _, v in { camBlend, camAngle, camDist, camShake, camFov, voidAlpha, speedLines } do
		v:Destroy()
	end
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
