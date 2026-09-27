# Rainbow egg for the egg hunt

A rainbow egg in the Ultra Instinct colours (violet, magenta, pink, cyan crystals, silver-white light).
When a player finds it, they get a hatch cutscene: the egg charges up, cracks, flashes and bursts
into a glowing energy core.

## Putting it in Roblox Studio

Copy each file's contents into a new script:

| File | Where in Studio | Script type |
| --- | --- | --- |
| `shared/RainbowEggConfig.luau` | ReplicatedStorage, named `RainbowEggConfig` | ModuleScript |
| `server/RainbowEggServer.server.luau` | ServerScriptService | Script |
| `client/RainbowEggClient.client.luau` | StarterPlayer > StarterPlayerScripts | LocalScript |

(With Rojo, `rojo serve roblox/default.project.json` does this for you.)

Then put a Part named **`RainbowEggSpawn`** where you want the egg hidden. Add several and one is
picked at random each server. The spawn Part turns invisible.

## Linking it to your egg hunt

- If players have `leaderstats` with an `Eggs` value, finding the rainbow egg adds 1.
  Change `LeaderstatName` / `EggValue` in `RainbowEggConfig`.
- The server also fires `ServerStorage.RainbowEggFound` (a BindableEvent) with the player, so your
  own egg hunt script can do anything else:

  ```lua
  game.ServerStorage:WaitForChild("RainbowEggFound").Event:Connect(function(player)
      -- give a badge, pet, etc.
  end)
  ```

- Each player can find it once (`OncePerPlayer = true`). After that it disappears for them only.
