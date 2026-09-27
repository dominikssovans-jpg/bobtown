--[[
	RAINBOW EGG
	Put this Script INSIDE your Rainbow Egg (a Part, MeshPart or Model).
	Put the "RainbowEggCutscene" LocalScript INSIDE this Script.

	Workspace
	  └ Rainbow Egg
	      └ RainbowEgg              (Script, this one)
	          └ RainbowEggCutscene  (LocalScript)

	It turns the egg rainbow (Ultra Instinct colours), adds aura flames, sparkles
	and a "Hatch" prompt, and plays the hatch cutscene for whoever finds it.
]]

---------------------------------------------------------------- SETTINGS
local SETTINGS = {
	-- How long the egg charges up and cracks before it bursts (seconds).
	ChargeSeconds = 3.2,
	-- How long the hatched energy core stays on screen (seconds).
	RevealSeconds = 4,
	-- Text shown when it hatches.
	RevealText = "RAINBOW EGG HATCHED!",

	-- true = each player can only find it once, then it disappears for them.
	OncePerPlayer = true,

	-- If players have leaderstats with a value of this name, it goes up by EggValue.
	LeaderstatName = "Eggs",
	EggValue = 1,

	PromptText = "Hatch",
	PromptObjectText = "Rainbow Egg",
	-- How close players must be to see the prompt (studs).
	PromptDistance = 12,
}
------------------------------------------------------------------------

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local StarterPlayer = game:GetService("StarterPlayer")

-- Ultra Instinct colours.
local VIOLET = Color3.fromRGB(106, 44, 255)
local MAGENTA = Color3.fromRGB(196, 60, 255)
local PINK = Color3.fromRGB(255, 95, 210)
local CYAN = Color3.fromRGB(95, 216, 255)
local ICE = Color3.fromRGB(168, 232, 255)
local SILVER = Color3.fromRGB(244, 240, 255)

local egg = script.Parent

-- The main part of the egg: the egg itself if it's a Part, otherwise the
-- Model's PrimaryPart or its biggest part.
local function findMainPart(): BasePart?
	if egg:IsA("BasePart") then
		return egg
	end
	if egg:IsA("Model") and egg.PrimaryPart then
		return egg.PrimaryPart
	end
	local best, bestSize = nil, 0
	for _, d in egg:GetDescendants() do
		if d:IsA("BasePart") then
			local s = d.Size.X * d.Size.Y * d.Size.Z
			if s > bestSize then
				best, bestSize = d, s
			end
		end
	end
	return best
end

local main = findMainPart()
if not main then
	warn("[RainbowEgg] The RainbowEgg script must be inside a Part, MeshPart or Model with parts in it.")
	return
end

-- Make the egg glow. The client script animates the colours.
local parts = {}
if egg:IsA("BasePart") then
	table.insert(parts, egg)
end
for _, d in egg:GetDescendants() do
	if d:IsA("BasePart") then
		table.insert(parts, d)
	end
end
for _, p in parts do
	p.Anchored = true
	p.Material = Enum.Material.Neon
	p.Color = MAGENTA
	if p:IsA("MeshPart") then
		p.TextureID = "" -- a texture would hide the rainbow colours
	end
end

local glow = Instance.new("Highlight")
glow.Name = "RainbowGlow"
glow.FillColor = SILVER
glow.FillTransparency = 0.85
glow.OutlineColor = ICE
glow.DepthMode = Enum.HighlightDepthMode.Occluded
glow.Parent = egg

local light = Instance.new("PointLight")
light.Name = "RainbowLight"
light.Color = MAGENTA
light.Brightness = 3
light.Range = 16
light.Parent = main

local aura = Instance.new("ParticleEmitter")
aura.Name = "RainbowAura"
aura.Texture = "rbxasset://textures/particles/fire_main.dds"
aura.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, SILVER),
	ColorSequenceKeypoint.new(0.3, MAGENTA),
	ColorSequenceKeypoint.new(0.65, VIOLET),
	ColorSequenceKeypoint.new(1, CYAN),
})
aura.LightEmission = 1
aura.LightInfluence = 0
aura.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2.2), NumberSequenceKeypoint.new(1, 0) })
aura.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 1) })
aura.Lifetime = NumberRange.new(0.6, 1.1)
aura.Rate = 40
aura.Speed = NumberRange.new(2, 4)
aura.Acceleration = Vector3.new(0, 6, 0)
aura.SpreadAngle = Vector2.new(15, 15)
aura.Shape = Enum.ParticleEmitterShape.Sphere
aura.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
aura.EmissionDirection = Enum.NormalId.Top
aura.Parent = main

local sparkles = Instance.new("ParticleEmitter")
sparkles.Name = "RainbowSparkles"
sparkles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
sparkles.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, SILVER),
	ColorSequenceKeypoint.new(0.5, PINK),
	ColorSequenceKeypoint.new(1, CYAN),
})
sparkles.LightEmission = 1
sparkles.LightInfluence = 0
sparkles.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) })
sparkles.Lifetime = NumberRange.new(1, 2)
sparkles.Rate = 12
sparkles.Speed = NumberRange.new(1, 3)
sparkles.SpreadAngle = Vector2.new(180, 180)
sparkles.Parent = main

local prompt = Instance.new("ProximityPrompt")
prompt.Name = "HatchPrompt"
prompt.ActionText = SETTINGS.PromptText
prompt.ObjectText = SETTINGS.PromptObjectText
prompt.HoldDuration = 0.5
prompt.MaxActivationDistance = SETTINGS.PromptDistance
prompt.RequiresLineOfSight = false
prompt.Parent = main

-- Settings the cutscene needs.
egg:SetAttribute("ChargeSeconds", SETTINGS.ChargeSeconds)
egg:SetAttribute("RevealSeconds", SETTINGS.RevealSeconds)
egg:SetAttribute("RevealText", SETTINGS.RevealText)
egg:SetAttribute("OncePerPlayer", SETTINGS.OncePerPlayer)
CollectionService:AddTag(egg, "RainbowEgg")

-- Shared between all rainbow eggs.
local hatchRemote = ReplicatedStorage:FindFirstChild("RainbowEggHatch")
if not hatchRemote then
	hatchRemote = Instance.new("RemoteEvent")
	hatchRemote.Name = "RainbowEggHatch"
	hatchRemote.Parent = ReplicatedStorage
end

-- Other scripts in your egg hunt can listen to this to give rewards:
--   game.ServerStorage.RainbowEggFound.Event:Connect(function(player, egg) ... end)
local foundEvent = ServerStorage:FindFirstChild("RainbowEggFound")
if not foundEvent then
	foundEvent = Instance.new("BindableEvent")
	foundEvent.Name = "RainbowEggFound"
	foundEvent.Parent = ServerStorage
end

-- Hand the cutscene LocalScript to players. LocalScripts don't run inside
-- Workspace, so it's moved to StarterPlayerScripts (for players who join later)
-- and copied into PlayerGui for anyone already in the game.
local cutscene = script:FindFirstChild("RainbowEggCutscene")
local starterScripts = StarterPlayer:WaitForChild("StarterPlayerScripts")
if cutscene and not starterScripts:FindFirstChild("RainbowEggCutscene") then
	for _, player in Players:GetPlayers() do
		local holder = Instance.new("ScreenGui")
		holder.Name = "RainbowEggCutsceneHolder"
		holder.ResetOnSpawn = false
		cutscene:Clone().Parent = holder
		holder.Parent = player:WaitForChild("PlayerGui")
	end
	cutscene.Parent = starterScripts
elseif not cutscene and not starterScripts:FindFirstChild("RainbowEggCutscene") then
	warn("[RainbowEgg] Put the RainbowEggCutscene LocalScript inside the RainbowEgg script, or the cutscene won't play.")
end

local found: { [Player]: boolean } = {}
local busy: { [Player]: boolean } = {}

prompt.Triggered:Connect(function(player)
	if busy[player] or (SETTINGS.OncePerPlayer and found[player]) then
		return
	end
	busy[player] = true
	found[player] = true

	local stats = player:FindFirstChild("leaderstats")
	local counter = stats and stats:FindFirstChild(SETTINGS.LeaderstatName)
	if counter and (counter:IsA("IntValue") or counter:IsA("NumberValue")) then
		counter.Value += SETTINGS.EggValue
	end

	foundEvent:Fire(player, egg)
	hatchRemote:FireClient(player, egg)

	task.delay(SETTINGS.ChargeSeconds + SETTINGS.RevealSeconds + 2, function()
		busy[player] = nil
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	found[player] = nil
	busy[player] = nil
end)
