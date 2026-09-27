-- Shared settings for the rainbow egg. Lives in ReplicatedStorage as a ModuleScript
-- named "RainbowEggConfig".

local Config = {}

-- Colours taken from the Ultra Instinct background: violet / magenta / pink energy,
-- cyan-ice crystals and silver-white light.
Config.Colors = {
	Void = Color3.fromRGB(11, 6, 32),
	Indigo = Color3.fromRGB(29, 15, 74),
	Violet = Color3.fromRGB(106, 44, 255),
	Magenta = Color3.fromRGB(196, 60, 255),
	Pink = Color3.fromRGB(255, 95, 210),
	Cyan = Color3.fromRGB(95, 216, 255),
	Ice = Color3.fromRGB(168, 232, 255),
	Silver = Color3.fromRGB(244, 240, 255),
}

local C = Config.Colors

-- The shell cycles through these in order.
Config.ShellCycle = { C.Cyan, C.Violet, C.Magenta, C.Pink, C.Ice, C.Violet }
Config.ShellCycleSeconds = 6

Config.AuraSequence = ColorSequence.new({
	ColorSequenceKeypoint.new(0, C.Silver),
	ColorSequenceKeypoint.new(0.3, C.Magenta),
	ColorSequenceKeypoint.new(0.65, C.Violet),
	ColorSequenceKeypoint.new(1, C.Cyan),
})

Config.SparkleSequence = ColorSequence.new({
	ColorSequenceKeypoint.new(0, C.Silver),
	ColorSequenceKeypoint.new(0.5, C.Pink),
	ColorSequenceKeypoint.new(1, C.Cyan),
})

-- Egg size in studs (width, height, depth).
Config.EggSize = Vector3.new(4, 5.2, 4)

-- How long the charge-up part of the cutscene lasts before the egg bursts.
Config.ChargeSeconds = 3.2
-- How long the hatched energy core stays on screen before control comes back.
Config.RevealSeconds = 4

-- Each player can find the rainbow egg once. Set to false to allow repeat finds.
Config.OncePerPlayer = true

-- If the player has leaderstats with a value of this name, it goes up by EggValue.
Config.LeaderstatName = "Eggs"
Config.EggValue = 1

Config.PromptText = "Hatch"
Config.PromptObjectText = "Rainbow Egg"
Config.RevealText = "RAINBOW EGG HATCHED!"

return Config
