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
  Obstacle rules: an obstacle the target stands inside is ignored (no hiding in the fountain / under the
  pergola), obstacles smaller than the enemy are trampled (the MEGA GRANDMA does not get stuck between bushes).
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
lighting; square park inside the ring road "Bingo Blvd", four spur streets across the arena lawn to the
perimeter street "Slipper Ave" just outside the arena fence, which the houses and the community buildings face;
the north side is the town's main street: Town Hall, Coffee Shop, Retirement Home, Grocery, Weapon Shop, and the Gas
Station on the north-east corner lot; obstacle circles never chained, see Known limitations), `Buildings`
(community buildings: RetirementHome, WeaponShop, Grocery, CoffeeShop, TownHall, GasStation, each with its lot
dressing; the Weapon Shop is scenery, buying stays in the shop panel),
`Streets` (asphalt with ink borders, lane lines, cracks, patches, manholes, storm drains; raised sidewalks with
curbs, slab joints, ramps, driveway aprons; chamfered corners; crosswalks; stepping stones), `Fences` (Picket,
Board backyard, Iron, Park, Border, ROAD CLOSED Barricade), `ParkProps` (tiered Fountain with spray particles,
Slide, CurvySlide, SwingSet, ClimbingFrame, Sandbox, Seesaw, SpringRider, PicnicTable, Pergola, Grill, BirdBath,
Sundial, SoccerGoal, PicnicBlanket, RoseArch), `Houses` (6 house designs: Family, Cottage, Colonial, GrandmaPink, Victorian, Bungalow + front yards
with yard props from their `Garden` lists: `{ "Prop", name, x, z, turn?, y? }`, `{ "Curb", name, x, turn? }`),
`Architecture` (reusable building parts: walls with siding/shingle/brick, gable roofs with shingles, fascia,
gutters, downspouts, recessed windows, paneled doors, porches with columns/railings, garages, dormers, bay windows,
chimneys), `Vegetation` (6 trees: Oak, Maple, Ornamental, Evergreen, Cherry, Roadside; 8 bushes: Round, Hedge,
Flowering, Pointed, Trimmed, Wild, Leafy, Corner; flowers: Daisy, Rose, Tulip, Sunflower, Wildflower; grass tufts,
garden beds, round flower beds), `Vehicles` (Sedan, Hatchback, Wagon, Minivan, SUV, Pickup from one spec-driven
car builder; grandma mobility Scooter; retirement-home Shuttle bus; Body + Details layers), the prop library:
`PropLibrary` (index of every prop builder by name and category, `Build(name, parent, cframe, rng?)`, `Small` set,
`Showcase(parent)` = one of everything in labelled rows; in Studio Edit mode run in the command bar
`require(game.ServerScriptService.Server.World.PropLibrary).Showcase(workspace)`), `YardProps` (wooden mailbox,
hose reel, lawn mower, wheelbarrow, shovel/rake/pitchfork + tool rack, flowerpots, watering can, gnome, flamingo,
Adirondack chair, patio table with umbrella, kettle grill, trash + recycling wheelie bins, welcome sign, hanging
basket, doghouse, birdhouse, crate, bunting, weather vane), `StreetProps` (lamps, street lights, stop signs with
street names, benches, park trash cans, hydrants, utility cabinets, planters, rocks, newspaper boxes, traffic
cones, A-frame and jersey barriers, garbage bags, bike racks, bicycles; manholes + open manhole are in `Streets`),
`GrandmaProps` (yarn balls, giant knitting needles with a scarf, knitting basket, slippers, rocking chair, cookie
stall, BINGO sign, retirement-home billboard, grandma statue, shopping cart with groceries), `ComicKit` (palette,
flat parts, wedges/prisms/spires/cones/gems, balls, rods/tubes, octagons, text, ink panels, outline groups),
`Meshes` (real mesh geometry from in-game CSG at server start: `Solid` = box cut by planes, `Frustum`, `Lump` =
faceted blob, `Union`/`Subtract`; `Ensure(name, build)` builds a template once, `Place(name, layers, cframe, scale,
paint)` clones it; CSG failure or `Config.Comic.Meshes = false` -> callers build their part version),
`EnemyFactory` (enemy models from welded parts).
Props: ground CFrame in (LookVector = front), Model out; small pieces deco, only big bodies solid; anything solid
inside the arena gets an obstacle circle in MapBuilder.

Comic art style (2026-10-19): hard comic look. Black silhouette outlines = one outline-only Highlight per
outline group (the map has 16 groups tagged `Config.Comic.OutlineTag`, all grandmas share one because
`workspace.Enemies` is a Model, one per character) added by the client's `OutlineController`; Roblox draws at most
31 Highlights, so never one per prop. Inner ink lines = black plates behind windows/doors/signs and thin black
bars. Flat SmoothPlastic, palette in `ComicKit.Colors`, hard shadows + color grade from `Config.Comic.Lighting`.
Small details are deco parts (no collision, no raycast, no shadow). Houses are split into HouseWalls / HouseRoofs /
HouseDetails groups so roofs, windows, doors and porches get a thick ink line against the walls. Vegetation:
leaf masses alternate FoliageA / FoliageB (ink lines between the masses of one canopy), Wood and Flowers are own
groups; the Grass model (blades, stems, soil) is NOT outlined on purpose (would turn into black scribbles).
Vehicles: body panels in `Cars`, glass/wheels/lights/bumpers/grille/mirrors/plates in `CarDetails` (ink around
windows and wheels), ink parts for door/hood/trunk seams. Streets: asphalt in `Roads`, sidewalks/curbs in
`Sidewalks` (black line where curb meets road).

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
- [~] Comic vehicles (written 2026-10-19, NOT yet seen in Studio): Vehicles module. Placement: 4 cars at the ring
  road's outer curb (Sedan, Minivan by the park, Hatchback, Wagon; obstacles as before), cars nose-in on the
  Family/Bungalow driveways, Scooter on the pink house porch + 2 on the retirement home porch, Shuttle (replaces
  the school bus) by the retirement home. Mock run ~17.7k parts.
- [~] Comic streets (written 2026-10-19, NOT yet seen in Studio): Streets + Fences modules, new street layout
  (spurs + perimeter street; houses moved to `Config.Map.WallDistance + 42`, retirement home to -(d + 55),
  ground 470), stop signs, street lights, utility boxes, planters, park fences (short, backed by obstacles),
  barricades where the spurs cross the arena fence. Mock run ~21k parts, 117 obstacles; preview renders.
- [~] Central park redesign (written 2026-10-19, NOT yet seen in Studio): exactly 126 x 126 (measured from the
  parts: inner sidewalk edges at +-63), round plaza + fountain, four 10-wide paths, sections: playground (+X +Z),
  picnic (-X +Z), garden + seating (-X -Z), open lawn (+X -Z). Furniture groups (bench + lamp + bin, pergola +
  tables, garden bed + benches, slides) use overlapping or merged obstacle circles so no pockets trap
  grandmas; checked for narrow gaps with a script. Mock run ~21k parts, 159 obstacles.
- [~] Comic prop library (written 2026-10-19, NOT yet seen in Studio): YardProps, StreetProps (was Props),
  GrandmaProps, PropLibrary. Placed: yard props per house design (curb bins on trash day, doghouse + grill, hose
  reel + mower, patio set, porch rocking chair + knitting + slippers, hanging baskets...), arena: road works on
  Knitting Way, newspaper boxes at two ring corners, cookie stall + scooter on the east lawn, giant yarn balls /
  needles on the lawn diagonals, grandma statue in the park garden, bike rack by the playground path; outside:
  jersey barriers behind the ROAD CLOSED barricades, BINGO sign, bike rack and carts at the retirement home,
  4 retirement-home billboards in the map corners (ring trees no longer land on the perimeter street corners).
  Mock run ~25k parts (~23k with SmallDetails off), 170 obstacles; preview renders of every prop.
- [~] Community buildings + quality pass (written 2026-10-19, NOT yet seen in Studio): Buildings module
  (Retirement Home rebuilt: brick ground floor, wings with front gables, dormers, clock tower with steeple,
  veranda with a gabled entrance, grounds; Weapon Shop with a barrel roof, stepped false front and a giant
  revolver; Grocery; Coffee Shop with a rooftop cup; Town Hall with a clock cupola; Gas Station), Architecture
  FlatRoof / Storefront / Awning, ComicKit.Cone replacing flat-topped spires on pines, shrubs, towers, lamps.
  Quality pass: obstacle chains replaced by single circles (cars, park fences, hedges, playground, plaza rows,
  newspaper boxes) after a reachability simulation found grandmas stuck in their notches; enemy obstacle rules
  (hiding spots, boss trampling); floating/buried part checks (fixed: shuttle mirrors, CARTS sign, retirement
  home window ink buried under the upper-floor shell, sunken flower centers); fewer repeated lines (siding,
  brick, shingles), no shingles/gutters on hidden back roof slopes, no ring trees hidden behind houses, shorter
  hidden backyard fences, fence-post finials; outside-the-arena parts non-colliding. Park re-measured: 126 x 126.
  Mock run ~26.4k parts, 127 obstacles.

- [~] Mesh quality benchmark (written 2026-10-19, NOT yet seen in Studio): `Meshes` (runtime CSG via
  GeometryService). Mesh versions of the Oak + Roadside trees (tapered octagonal trunk, branch + root mesh, a crown
  of 16-22 faceted lumps in three greens, two canopy meshes for inner ink lines), Round + Flowering bushes (with a
  blossom mesh), the Sedan (body with sloped hood/trunk, bevels and cut wheel arches merged with a raked cabin; a
  glass shell with A/B/C pillars cut out; one-mesh wheels). Street section: Family yard landscaping (foundation
  bushes, flowering shrubs, front-yard oak), street trees on the lot lines, two rings of mesh trees behind the
  houses (no obstacles outside the arena). 3 variants per tree/bush kind, ~300 CSG calls at server start.
  Mock run ~27.8k instances (a mesh tree is 4 parts instead of ~30), 127 obstacles; CSG-failure fallback
  checked in the mock; preview renders from an offline CSG evaluator.

## Known limitations (now)
- Meshes: custom MeshParts cannot be uploaded from code. EditableMesh could build them at runtime, but published
  games only allow it when the owner is 13+ and ID-verified (plus a Game Settings toggle), and its meshes do not
  replicate, so the map uses in-game CSG (`Meshes`) instead: flat-faceted convex solids, unions and cuts (no
  smooth curves, no sculpted shapes). ~300 CSG calls at server start: check the startup time in Studio. Only the
  benchmark kinds are meshes so far (Oak, Roadside, Round + Flowering bushes, Sedan).
- Comic map: everything else is Parts/Wedges/Cylinders/Balls, so
  curves (hoses, rockers, wheels, arches) are short straight segments or round parts, and cones/steeples have a
  small flat tip (capped with a ball where it shows). ~26.4k parts (98% decoration: no collision, no raycasts;
  everything outside the arena fence is non-colliding) and ~25 Highlights: check FPS on a phone.
  Levers: `Config.Comic.Outlines = false` (all outlines off), `Config.Comic.SkipOutlinesOnTouch` (e.g. the four
  house groups, ~60% of the parts, off on touch devices), `Config.Comic.SmallDetails = false` (~2k parts fewer).
  Sign lettering is SurfaceGui text (GothamBlack).
  Grandma and gun models are not restyled yet.
- Not yet run in Studio; first playtest may show bugs.
- Enemies avoid obstacles with simple circle push-out + sliding (`MapBuilder.GetObstacles`), not pathfinding:
  keep arena props small and round-ish; long walls or narrow corridors would trap them. Give each prop ONE
  circle (two overlapping circles leave a notch that traps grandmas walking straight at it) and keep at least
  ~3.6 studs between circles. Checked by an offline simulation of the AI from all 8 spawns to a 4-stud grid of
  player positions (normal, scooter and boss sizes): every position reached.
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
