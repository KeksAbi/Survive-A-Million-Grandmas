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

## Gamepass and product IDs (Phase 6)
Create them in the Creator Dashboard (Monetization > Passes / Developer Products), then put the IDs into the
monetization config module (added in Phase 6). Buttons stay disabled while an ID is 0.

## DataStores (Phase 6)
For stats to save while testing in Studio: Game Settings > Security > **Enable Studio Access to API Services**.
The game must be published first.

## Publish
File > Publish to Roblox (first time: create a new experience). Then set the experience to Public in the
Creator Dashboard when ready.
