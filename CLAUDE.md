# Survive 1 Million Angry Grandmas: project instructions

Roblox co-op wave shooter (1-8 players). Players in a colorful suburban neighborhood shoot waves of
angry grandmas, earn cash per kill, buy better weapons and grenades, and survive 10 waves (bosses on
waves 5 and 10). Funny, chaotic, readable in 10 seconds. Target run: 10-15 minutes. Owner: Alex.

Standalone project. Never touch other projects (e.g. Evo Wars).

## Goals (in priority order)
1. Simple, addictive gameplay. 2. Small codebase, fast to ship. 3. Funny and chaotic for young players.
4. Good performance with many NPCs. 5. Co-op multiplayer. 6. Simple fair monetization.
7. Colorful, professional Roblox UI. 8. Easy to extend without rewrites.
MVP only: no pets, rebirths, crafting, trading, multiple worlds or deep progression.

## Code layout (Rojo, `default.project.json`)
| Folder | Becomes in Studio | Contents |
|---|---|---|
| `src/shared` | `ReplicatedStorage.Shared` | `Config`, `WeaponDefinitions`, `EnemyDefinitions`, `WaveDefinitions`, `SkinDefinitions`, `GunModels`, `Remotes`, `Signal` |
| `src/server` | `ServerScriptService.Server` | `Main.server.luau` (bootstrap), `Services/*`, `World/*` |
| `src/client` | `StarterPlayer.StarterPlayerScripts.Client` | `Main.client.luau`, `Effects`, `Controllers/*` |

Server services (`src/server/Services`):
- `PlayerService`: character setup, spawn shield, spawning (`CharacterAutoLoads` is off; `Config.Player.BasicBody`:
  classic blocky R6 for everyone, built with CreateHumanoidModelFromDescription(R6) whatever the avatar
  settings: own clothes/colors/accessories, CharacterMesh packages removed), `RespawnAndHealAll()`,
  `GetLivingPlayers()`, signals `CharacterSpawned`, `PlayerDied`, `PlayerJoined`.
- `EconomyService`: per-player match cash (`Reset`, `AddCash`, `TrySpend`). Replicated as player attribute `Cash`.
- `EnemyService`: spawning, ONE central AI loop for all enemies (behaviors Melee / Ranged slipper throw /
  Boss stomp), damage, `DamageInRadius`, boss tracking (`MarkBoss`, workspace `Boss*` attrs), kills, `ClearAll`.
- `CombatService`: weapon ownership, equipped weapon, ammo, reload, fire-rate, server raycasts, damage.
- `ShopService`: `Purchase` remote: weapons (WeaponDefinitions.Cost) and grenades; buys auto-equip.
- `GrenadeService`: grenade count (`Grenades` attr), `ThrowGrenade` remote, server-side landing + explosion.
- `DataService`: saved stats (DataStore `Config.Data.StoreName`): Kills, BestWave, Victories, Revives. Delta saves
  via UpdateAsync (counts added, BestWave = max), retries, autosave, save on leave + BindToClose, receipts stored
  in the same document (`GrantReceipt`, exactly-once). Attributes LifetimeKills/BestWave/Victories/Revives +
  `leaderstats` (Kills, Best Wave, Wins). Without DataStore access: session only, warning in Output.
- `PurchaseService`: gamepasses (`Config.Monetization.Passes`: DoubleCash -> `CashMultiplier` attr on kill cash,
  VIP -> tag + Gold skin + sparkles, SkinPack -> skins), Revive product (ProcessReceipt -> DataService credit,
  auto-used when dead in a wave, `UseRevive` remote, `RevivesPerWave`), `SelectSkin` remote. When the whole
  team is down, WaveService gives a `LastChanceSeconds` revive window (enemies frozen, workspace `ReviveCountdown`). Attrs `Pass<Key>`,
  `Skin`, `RevivedWave`.
- `AdminService`: admin panel requests (`Admin` remote: jump to wave, skip wave/countdown, cash, all guns,
  kill all, heal). Admins = `Config.Admin.UserIds`, the place owner, everyone in Studio; player attr `Admin`.
- `WaveService`: the single match loop: Waiting -> (Intermission -> Wave) x10 -> Victory/Defeat -> results
  -> new match. Spawns waves gradually, scales by player count, bonuses, respawns, `MatchResult`, `MatchEnded` signal.

World (`src/server/World`): `MapBuilder` (layout of the whole map at server start, spawn points, obstacles,
lighting), `Houses` (6 house designs: Family, Cottage, Colonial, GrandmaPink, Victorian, Bungalow + front yards),
`Architecture` (reusable building parts: walls with siding/shingle/brick, gable roofs with shingles, fascia,
gutters, downspouts, recessed windows, paneled doors, porches with columns/railings, garages, dormers, bay windows,
chimneys), `Vegetation` (6 trees: Oak, Maple, Ornamental, Evergreen, Cherry, Roadside; 8 bushes: Round, Hedge,
Flowering, Pointed, Trimmed, Wild, Leafy, Corner; flowers: Daisy, Rose, Tulip, Sunflower, Wildflower; grass tufts,
garden beds, round flower beds), `Props` (cars, school bus, retirement home, fountain, lamps, benches,
hydrants, fences, flamingos, gnomes, bunting, weather vane), `ComicKit` (palette, flat parts, wedges/prisms/
spires/gems, ink panels, outline groups), `EnemyFactory` (enemy models from welded parts).

Comic art style (2026-10-19): hard comic look. Black silhouette outlines = one outline-only Highlight per
outline group (the map has 14 groups tagged `Config.Comic.OutlineTag`, all grandmas share one because
`workspace.Enemies` is a Model, one per character) added by the client's `OutlineController`; Roblox draws at most
31 Highlights, so never one per prop. Inner ink lines = black plates behind windows/doors/signs and thin black
bars. Flat SmoothPlastic, palette in `ComicKit.Colors`, hard shadows + color grade from `Config.Comic.Lighting`.
Small details are deco parts (no collision, no raycast, no shadow). Houses are split into HouseWalls / HouseRoofs /
HouseDetails groups so roofs, windows, doors and porches get a thick ink line against the walls. Vegetation:
leaf masses alternate FoliageA / FoliageB (ink lines between the masses of one canopy), Wood and Flowers are own
groups; the Grass model (blades, stems, soil) is NOT outlined on purpose (would turn into black scribbles).

Client (`src/client`): `InputController` (keys -> signals), `CameraController` (normal Roblox camera, starts each
spawn zoomed out and higher; right-click drag turns, wheel zooms), `GunController` (crosshair = mouse cursor,
fire toward the cursor, effects, G = grenade), `HUDController` (all UI built in code, results screen, boss bar; exports `Kit` and
`CreateContainer` for other panels), `ShopController` (shop panel left, grenade panel right),
`OutlineController` (comic ink outlines, own outline off in first person), `WorldFxController` (plays WorldFx: slippers, grenades, explosions, stomps), `MobileController` (touch
buttons FIRE/R/G; touch aims through the screen center with aim assist), `EnemyBarController` (health bars over
damaged grandmas from the `HealthRatio` attribute), `BossCutsceneController` (7 s MEGA GRANDMA intro: rises
out of the ground, lightning, title slam; server freezes enemies + shields players meanwhile), `AdminController` (admin panel top right, F2), `StoreController` (STORE button bottom left / top left on
touch: passes + gun skins; REVIVE button while dead), `ViewmodelController` (first-person gun bottom right), `AtmosphereController` (dark red
dusk from the boss cutscene until that wave ends, `Config.Boss.WaveLighting`), `SpectateController` (follow a teammate
while dead), `Effects` (trails, flashes, damage numbers, sound hooks).

Gun models (`shared/GunModels`): detailed mesh guns imported in Studio go in `ReplicatedStorage.WeaponModels`
(not synced by Rojo; saved in the place file), one Model per weapon id with parts named `*Grip*` and `*Barrel*`;
grip point, barrel direction, muzzle, scale (`TARGET_LENGTH`) and skin tint (`*_Body`/`*_Accent`) are computed.
Missing -> part-built fallback guns. Held gun: welded to the UpperTorso (points where the body faces,
sized by arm length). R15: hands by IKControls on Handle attachments RightGrip/LeftGrip + bladed waist twist.
R6 (default, blocky): shoulder Motor6Ds disabled, fixed Welds ("Right Shoulder Gun") point the arms at the
grips, so the walk animation cannot swing them.
The held gun (CombatService) and the 3D icons (`client/GunIcon`, shop,
hotbar, store) use the same model. Claude Design prompts: `docs/weapon-prompts.md`.

## Rojo workflow
`rojo serve` in the repo root, then connect from the Rojo plugin in Studio. Code is edited on disk only;
anything edited in Studio inside the synced folders is overwritten. The map is generated by
`MapBuilder` at runtime, so the place file itself only needs default services.
Check before pushing: `rojo build -o build/test.rbxl` (must succeed) and, if available,
`luau-lsp analyze --definitions=<globalTypes.d.luau> --sourcemap=sourcemap.json src` (must be clean).

## Conventions
- Luau, tabs, `--!nonstrict` for scripts using Roblox APIs, `--!strict` for pure data modules.
- One module = one responsibility. Services expose `Init()`; `Main.server.luau` decides the order.
  No circular requires: World -> nothing; Player/Economy -> shared; Enemy -> Player, Economy; Combat -> Enemy, Player.
- All tunable numbers live in `Config` / `*Definitions`. No magic numbers in services.
- Remotes are declared only in `shared/Remotes.luau` (with their argument list in the header comment).
- Server -> client state: prefer attributes (player: `Cash`, `Weapon`, `Ammo`, `MagSize`, `Reloading`,
  `Owns<Id>`, `Alive`, `BestWave`; workspace: `MatchState`, `Wave`, `WaveKills`, `WaveTotal`, `Countdown`,
  `EnemiesAlive`) over remotes.

## Client / server responsibilities and security
- The server is authoritative for: cash, purchases, ownership, ammo, reloads, fire rate, hit detection,
  damage, enemy health/death, grenades, waves, gamepass/product rewards.
- The client only reads input, aims, plays effects instantly, and sends requests.
- Every remote handler validates argument types, finiteness, rate (`Config.Combat.MaxRemotesPerSecond`),
  that the player is alive, and gameplay rules (owned weapon, cooldown, ammo, shot origin near the head).
- Never trust client damage, cash, ammo, ownership or kill claims. Never fake purchases.

## Performance rules
- Enemies: no Humanoid, no pathfinding, no per-enemy scripts. Root part anchored, everything else welded.
  One Heartbeat loop moves all enemies at `Config.Enemies.UpdateRate`. Cap: `Config.Enemies.MaxActive` (60).
- Only the invisible `Hitbox` part of an enemy is queryable; server raycasts use an Include filter
  (`workspace.Enemies` + `workspace.Map`).
- Effects are client-only (`workspace.ClientEffects`), cleaned with Debris. The server sends one
  `HitFeedback` to the shooter and one `ShotFx` per shot to others, nothing per frame.

## How to add things
- **Weapon:** add an entry to `WeaponDefinitions.Weapons` (+ `Order` for its hotbar slot). Combat, HUD
  slot, gun model and ammo work automatically. The shop sells it once ShopController exists.
- **Enemy:** add data to `EnemyDefinitions` (Behavior Melee/Ranged/Boss, Radius, optional Scale/HitboxSize),
  add a builder to `BUILDERS` in `EnemyFactory` (`buildGrandma` takes colors, Scale, Held item...).
  A new behavior is a branch in the `EnemyService` step loop keyed on `def.Behavior`.
- **Wave:** add a row to `WaveDefinitions` (enemy counts for one player, optional `Boss`, spawn interval).
  Scaling numbers are in `Config.Waves`. Enemy types not in `EnemyDefinitions` fall back to NormalGrandma.

## How to test
Claude cannot run Studio from a cloud session. Static checks: `rojo build`, `luau-lsp analyze`.
In Studio (Alex): Play solo (F5) for combat; Test > Clients and Servers with 2-3 players for co-op.
Report honestly what was tested and what was not.

## Implementation status
- [x] Phase 1 Foundation: Rojo project, folders, configs, remotes, bootstrap, generated arena.
- [x] Phase 2 First combat (playtested by Alex 2026-10-18: works; fixed HUD scaling, aim, hotbar):
  Normal Grandma with central chase AI, enemy + player health, 3 weapons, server-validated raycast shooting
  with lag tolerance, ammo/reload, kills, cash, HUD (cash, health, ammo, slots, crosshair, hitmarker, damage numbers).
- [x] Phase 3 Waves (written, NOT yet tested in Studio): WaveService, 10 waves, countdowns, player scaling,
  completion bonus, stay-dead-until-next-wave + spectating, mid-wave join, victory/defeat results, auto restart.
- [x] Phase 3 playtested by Alex: waves, countdown OK. Controls changed on request: normal Roblox camera
  zoomed out (first person when fully zoomed in), crosshair = mouse cursor, body not turned to the cursor.
- [x] Phase 4 playtested by Alex: works. Hotbar shows only bought guns; reload timer added.
- [x] Phase 5 (written, NOT yet tested in Studio): mobile buttons + center aim + aim assist, tappable hotbar,
  sound system (`Config.Sounds`, ids still empty), music hook, enemy health bars, boss entrance flash + shake,
  low-health red edges, results pop-in, map details (school bus, crosswalks, flower beds, more lamps).
- [x] Phase 4: shop (left panel, keys 1-3 buy/equip), grenades (G, $60,
  max 5), Slipper Grandma (ranged slipper arcs), Scooter Grandma, MEGA GRANDMA (stomp + boss bars).
- [x] Phase 6 (written, NOT yet tested in Studio): DataService stats + leaderstats, PurchaseService passes /
  Revive product / skins (`SkinDefinitions`), StoreController. Pass/product ids set in Config.Monetization (created by Alex).
  Alex 2026-10-18: stats save and load across sessions in Studio (API access on). Purchases still untested.
- [~] Phase 7 Testing and optimization: code review (match flow, security, performance/mobile) done and fixed
  2026-10-18: revive limits reset per match/jump, freeze cleared on ClearAll and not cut short by a revive,
  a won wave beats a same-tick team wipe, per-weapon fire budget (swap no longer refills), claims only count
  pellets that land, no shooting with the muzzle through a wall, skin/grenade spam limits, receipt writes
  serialized with saves, mobile layout (grenade panel top right on touch, buttons above the jump button).
  Studio checklist for Alex: `docs/test-checklist.md` (not yet run).
  Alex 2026-10-18: blocky R6 bodies, R6 gun hold (arms on the gun, no walk swing), first-person viewmodel,
  shooting/ammo all confirmed working in Studio.

- [~] Comic map overhaul (written 2026-10-19 from a cloud session, NOT yet seen in Studio): ComicKit + Props +
  new MapBuilder + OutlineController. Same layout, spawns, obstacles and API as before. Checked: rojo build,
  luau-lsp, and a mock run of MapBuilder (no errors, ~6.9k parts, 60 obstacles).
- [~] Six detailed house designs (written 2026-10-19, NOT yet seen in Studio): Houses + Architecture. Houses now
  stand square to the streets (d + 26 from the center). Checked: rojo build, luau-lsp, mock run (~12.8k parts,
  93% deco) and preview renders of every design from a simple offline renderer (no Roblox lighting).
- [~] Comic vegetation (written 2026-10-19, NOT yet seen in Studio): Vegetation module; planned planting in the
  park (oaks/maples, cherries, path beds, round beds), outer lawn (bushes, roadside trees, sidewalk planting
  spots), house gardens (`Garden` lists in Houses), retirement home hedges, ring of trees behind the houses.
  Checked like the houses (mock run ~16.7k parts, 73 obstacles; preview renders).

## Known limitations (now)
- Comic map: no custom MeshParts (cannot be uploaded from code); shapes are Parts/Wedges. ~16.7k parts (95% deco)
  and ~23 Highlights: check FPS on a phone; `Config.Comic.Outlines = false` turns the outlines off,
  `Config.Comic.GrassTufts = false` drops the grass tufts.
  Grandma and gun models are not restyled yet.
- Not yet run in Studio; first playtest may show bugs.
- Enemies avoid obstacles with simple circle push-out + sliding (`MapBuilder.GetObstacles`), not pathfinding:
  keep arena props small and round-ish; long walls or narrow corridors would trap them.
- Mobile controls are untested on a real phone (use Studio's device emulator first).
- Sounds: `Config.Sounds` ids are empty on purpose: Alex will make his own sounds later (the generated set was
  rejected). Every hook is in place; filling an id there is all it takes.
- Admin panel (F2): wave buttons 1-10 (red = boss), skip wave, start now, +$, all guns, kill all, heal.
- `Config.Debug.GiveAllWeapons` (false): set true to own every gun for testing.
- First person: Roblox hides the own character; `ViewmodelController` draws the equipped gun bottom right
  (bob, sway, recoil, reload dip). It can poke into walls when standing right against one.

## Future (after MVP, only on request)
More grandma types (flying, exploding, ninja, zombie), boss variants, barricades, turrets, airstrike,
new maps, endless mode, global kill counter, leaderboards, daily rewards, weapon skins, events.
