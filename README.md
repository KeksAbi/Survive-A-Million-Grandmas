# Survive 1 Million Angry Grandmas

Co-op Roblox wave shooter: survive 10 waves of angry grandmas, earn cash, buy bigger guns.

## Required software
- Roblox Studio
- [Rojo](https://rojo.space) 7.x: the command-line tool **and** the Rojo Studio plugin
  (install the plugin from the Creator Store, or with `rojo plugin install`).
- Optional: [Aftman](https://github.com/LPGhatguy/aftman) or [Rokit](https://github.com/rojo-rbx/rokit) to install Rojo, and
  [luau-lsp](https://github.com/JohnnyMorganz/luau-lsp) for type checking.

## Open and sync the game
1. Open `SurviveAMillionGrandmas.rbxl` in Roblox Studio.
2. In a terminal in this folder run: `rojo serve`
3. In Studio: Plugins > Rojo > **Connect**. The scripts from `src/` appear in
   `ReplicatedStorage.Shared`, `ServerScriptService.Server` and `StarterPlayer.StarterPlayerScripts.Client`.
4. Edit code on disk (or let Claude do it). Rojo syncs every save into Studio live.
5. Save the place in Studio with **Ctrl+S** so the synced scripts are stored in the `.rbxl` too.

Do not edit synced scripts inside Studio: Rojo overwrites them from disk.

## Test
- **Solo:** press **Play** (F5). You spawn in the park with a pistol; grandmas keep coming from the red spawn circles.
  - Left mouse: shoot. **R**: reload. **1 / 2 / 3**: weapons (only owned ones). Mouse is locked to the crosshair; press Esc to free it.
- **Co-op:** Test tab > Clients and Servers > 2-3 players > Start.
- Watch the Output window for errors (`[SurviveMillionGrandmas] server started` means the server booted).

## Build without Studio
`rojo build -o build/SurviveMillionGrandmas.rbxl` creates a place file from the code (the map is generated at runtime).

## Gamepasses and the Revive product
The game must be published first (File > Publish to Roblox). Then, on create.roblox.com > your experience:
1. **Monetization > Passes**: create `2X CASH` (suggested 149 Robux), `VIP` (299) and `SKIN PACK` (99).
   Put each one on sale and copy its id.
2. **Monetization > Developer Products**: create `REVIVE` (suggested 29) and copy its id.
3. Paste the ids into `src/shared/Config.luau` > `Monetization` (`Passes.DoubleCash.Id`, `Passes.VIP.Id`,
   `Passes.SkinPack.Id`, `Products.Revive.Id`). While an id is 0 its store button shows **SOON** and does nothing.

What they do: 2X CASH doubles cash from kills (not wave bonuses). VIP gives a VIP tag over the head, the golden
gun skin and golden sparkles. SKIN PACK unlocks the Candy, Toxic and Galaxy gun skins. REVIVE gives one revive
credit; it is used at once if you are dead during a wave (max 1 revive per wave), otherwise it is kept for later.
The real Robux prices are read from Roblox; the prices in Config are only a fallback for display.

Testing purchases in Studio: Roblox shows a test prompt and no Robux are spent. A test-bought pass works until
you stop the test (Roblox does not remember it as owned). Revive test purchases go through the same receipt code.

## Saved stats (DataStores)
Saved per player: lifetime grandma kills, best wave, victories, unused revive credits. They show in the player
list (Kills, Best Wave, Wins). Matches where admin tools (or `Config.Debug.StartWave` > 1) were used do not count.
To save while testing in Studio: publish the place, then Game Settings > Security > **Enable Studio Access to
API Services**. Without it the game still runs, stats just are not saved (the Output window says so).

## Publish
File > Publish to Roblox (first time: create a new experience). Then set the experience to Public in the
Creator Dashboard when ready.
