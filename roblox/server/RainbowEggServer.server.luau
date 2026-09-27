-- Places the rainbow egg in the egg hunt and handles players finding it.
-- Lives in ServerScriptService as a Script.
--
-- Where the egg goes: put a Part named "RainbowEggSpawn" (or tag Parts with
-- "RainbowEggSpawn") where you want it hidden. One spawn is picked at random.
-- The spawn Part is made invisible.
--
-- Hooking into your egg hunt: listen to ServerStorage.RainbowEggFound (a
-- BindableEvent), which fires with the player who found the egg.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Config = require(ReplicatedStorage:WaitForChild("RainbowEggConfig"))
local C = Config.Colors

local hatchRemote = Instance.new("RemoteEvent")
hatchRemote.Name = "RainbowEggHatch"
hatchRemote.Parent = ReplicatedStorage

local foundEvent = ServerStorage:FindFirstChild("RainbowEggFound") or Instance.new("BindableEvent")
foundEvent.Name = "RainbowEggFound"
foundEvent.Parent = ServerStorage

local function findSpawn(): BasePart?
	local spawns = CollectionService:GetTagged("RainbowEggSpawn")
	for _, d in workspace:GetDescendants() do
		if d:IsA("BasePart") and d.Name == "RainbowEggSpawn" and not table.find(spawns, d) then
			table.insert(spawns, d)
		end
	end
	if #spawns == 0 then
		return nil
	end
	return spawns[math.random(1, #spawns)]
end

local function addEmitter(parent: Instance, props: { [string]: any }): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	for k, v in props do
		(e :: any)[k] = v
	end
	e.Parent = parent
	return e
end

local function buildEgg(cf: CFrame): BasePart
	local egg = Instance.new("Part")
	egg.Name = "RainbowEgg"
	egg.Size = Config.EggSize
	egg.CFrame = cf
	egg.Anchored = true
	egg.CanCollide = false
	egg.CastShadow = false
	egg.Material = Enum.Material.Neon
	egg.Color = C.Magenta

	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = egg

	-- Glowing outline; the client animates its colour.
	local hl = Instance.new("Highlight")
	hl.Name = "Glow"
	hl.FillColor = C.Silver
	hl.FillTransparency = 0.85
	hl.OutlineColor = C.Ice
	hl.OutlineTransparency = 0
	hl.DepthMode = Enum.HighlightDepthMode.Occluded
	hl.Parent = egg

	local light = Instance.new("PointLight")
	light.Name = "Light"
	light.Color = C.Magenta
	light.Brightness = 3
	light.Range = 16
	light.Parent = egg

	-- Purple aura flames rising off the shell.
	addEmitter(egg, {
		Name = "Aura",
		Texture = "rbxasset://textures/particles/fire_main.dds",
		Color = Config.AuraSequence,
		LightEmission = 1,
		LightInfluence = 0,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2.2), NumberSequenceKeypoint.new(1, 0) }),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.5),
			NumberSequenceKeypoint.new(0.5, 0.6),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Lifetime = NumberRange.new(0.6, 1.1),
		Rate = 40,
		Speed = NumberRange.new(2, 4),
		Acceleration = Vector3.new(0, 6, 0),
		SpreadAngle = Vector2.new(15, 15),
		Shape = Enum.ParticleEmitterShape.Sphere,
		ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
		EmissionDirection = Enum.NormalId.Top,
	})

	-- Silver / pink / cyan sparkles.
	addEmitter(egg, {
		Name = "Sparkles",
		Texture = "rbxasset://textures/particles/sparkles_main.dds",
		Color = Config.SparkleSequence,
		LightEmission = 1,
		LightInfluence = 0,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) }),
		Lifetime = NumberRange.new(1, 2),
		Rate = 12,
		Speed = NumberRange.new(1, 3),
		SpreadAngle = Vector2.new(180, 180),
	})

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "HatchPrompt"
	prompt.ActionText = Config.PromptText
	prompt.ObjectText = Config.PromptObjectText
	prompt.HoldDuration = 0.5
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = egg

	CollectionService:AddTag(egg, "RainbowEgg")
	egg.Parent = workspace
	return egg
end

local spawnPart = findSpawn()
local eggCFrame
if spawnPart then
	spawnPart.Transparency = 1
	spawnPart.CanCollide = false
	eggCFrame = spawnPart.CFrame * CFrame.new(0, Config.EggSize.Y / 2, 0)
else
	warn("[RainbowEgg] No part named or tagged 'RainbowEggSpawn' found; placing the egg at 0, 5, 0")
	eggCFrame = CFrame.new(0, 5, 0)
end

local egg = buildEgg(eggCFrame)
local prompt = egg:FindFirstChild("HatchPrompt") :: ProximityPrompt

local found: { [Player]: boolean } = {}
local busy: { [Player]: boolean } = {}

prompt.Triggered:Connect(function(player)
	if busy[player] or (Config.OncePerPlayer and found[player]) then
		return
	end
	busy[player] = true
	found[player] = true

	local stats = player:FindFirstChild("leaderstats")
	local counter = stats and stats:FindFirstChild(Config.LeaderstatName)
	if counter and (counter:IsA("IntValue") or counter:IsA("NumberValue")) then
		counter.Value += Config.EggValue
	end

	foundEvent:Fire(player)
	hatchRemote:FireClient(player, egg)

	task.delay(Config.ChargeSeconds + Config.RevealSeconds + 1, function()
		busy[player] = nil
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	found[player] = nil
	busy[player] = nil
end)
