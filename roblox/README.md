# Rainbow egg for the egg hunt

Turns your Rainbow Egg in Roblox Studio into a glowing Ultra Instinct–coloured egg (violet, magenta,
pink, cyan crystals, silver-white light) with a hatch cutscene when a player finds it.

## Putting it in your egg

1. In Explorer, find your **Rainbow Egg** (a Part, MeshPart or Model).
2. Hover over it, click **+**, add a **Script**, and name it `RainbowEgg`.
   Paste in [`RainbowEgg.server.luau`](RainbowEgg.server.luau).
3. Hover over that `RainbowEgg` Script, click **+**, add a **LocalScript**, and name it `RainbowEggCutscene`.
   Paste in [`RainbowEggCutscene.client.luau`](RainbowEggCutscene.client.luau).

```
Workspace
  └ Rainbow Egg
      └ RainbowEgg              (Script)
          └ RainbowEggCutscene  (LocalScript)
```

Press Play, walk up to the egg and hold **E** to hatch it.

## Settings

The top of the `RainbowEgg` Script has a `SETTINGS` section: cutscene length, the hatch text, whether
players can find it more than once, and the prompt text.

## Linking it to your egg hunt

- If players have `leaderstats` with an `Eggs` value, finding the rainbow egg adds 1.
  Change `LeaderstatName` / `EggValue` in `SETTINGS` to match yours.
- Your own scripts can react when it's found:

  ```lua
  game.ServerStorage:WaitForChild("RainbowEggFound").Event:Connect(function(player, egg)
      -- give a badge, pet, etc.
  end)
  ```
