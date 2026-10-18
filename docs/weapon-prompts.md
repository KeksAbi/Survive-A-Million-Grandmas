# Weapon models: Claude Design prompts

One prompt per weapon. Open a **brand-new Claude Design chat** for each one and paste the whole block.

How the game uses the result (`src/shared/GunModels.luau`):
- In Studio: **File > Import 3D** > pick the `.glb` > Import. Rename the imported Model to `Pistol`, `Shotgun` or
  `AssaultRifle` and drag it into a Folder `ReplicatedStorage > WeaponModels` (create the folder once). Save the place.
- The game needs one part with **Grip** and one with **Barrel** in its name. It works out the hand position, the
  barrel direction, the muzzle and the size by itself. Parts ending in `_Body` / `_Accent` get recolored by gun skins.
- No model in `WeaponModels` = the game uses its simple built-in gun.

---

## Pistol

````
3D model of a PISTOL for a Roblox game ("Survive 1 Million Angry Grandmas": a bright, funny, cartoon co-op
shooter for young players). Build ONE detailed, game-ready handgun as a static prop (no rig). It must look like a
polished, chunky cartoon toy-style pistol from a popular Roblox shooter: clearly readable from far away, soft
beveled edges, real gun details. NOT a plain block, NOT a few stacked boxes.

STYLE
- Stylized low-poly 3D with free mesh modelling: chamfers, bevels (~0.02 studs on every outer edge), extrusions,
  grooves, slanted cuts. Slightly chunky, cartoon proportions (about 15% thicker than a real pistol).
- No textures, no text, no letters, no logos. Flat colors per material, bright neutral preview lighting.
- 1500-4000 triangles.

COLORS (materials, flat, exactly these, no darkening)
- Body   #2D2D34  (slide, frame top)
- Accent #5A5A64  (grip panels, trigger, sights' white dots are Dot)
- Metal  #9AA0AA  (barrel tip, slide release, hammer)
- Dark   #18191D  (inner barrel hole, grooves, trigger guard)
- Dot    #FFFFFF  (3 sight dots only)

SCALE AND ORIENTATION (1 unit = 1 Roblox stud)
- Total length 1.70 (back of the slide to the muzzle), height 1.15 (top of the rear sight to the bottom of the grip),
  width 0.34.
- The barrel points toward -Z. Up is +Y. Centered on X (left/right symmetric).
- Origin (0,0,0) = where the shooting hand closes: the top of the grip, just under the slide.

PARTS (each a separate mesh, exact names)
- Slide_Body: 1.55 long (z +0.30 to -1.25), 0.32 tall (y +0.05 to +0.37), 0.30 wide. Top edges chamfered 0.05.
  Back end: 7 vertical serration grooves (0.03 wide, 0.02 deep, 0.04 apart) on BOTH sides, z +0.05 to +0.28.
  Ejection port on the RIGHT side (+X): a 0.30 x 0.12 recess, 0.03 deep, at z -0.25, top of the slide.
- Frame_Body: under the slide, 1.15 long (z +0.20 to -0.95), 0.18 tall (y -0.13 to +0.05), 0.28 wide. Front end
  rounded. A small accessory rail under the front: 3 ribs 0.05 wide, z -0.55 to -0.90.
- Barrel_Metal: a cylinder 0.13 diameter sticking out 0.15 in front of the slide (z -1.25 to -1.40) at y +0.21,
  with a Dark hole 0.07 diameter, 0.05 deep, in its front face. The front face of Barrel_Metal is the muzzle.
- Grip_Accent: the handle, 0.75 tall (y -0.05 down to -0.80), 0.30 wide, 0.40 deep, raked back 14 degrees (the
  bottom is further back toward +Z than the top). Both side panels have a raised grid texture: 5 rows x 3 columns
  of small square bumps (0.06, 0.015 high). Bottom: a magazine base plate 0.34 wide x 0.44 deep x 0.06, Metal.
- TriggerGuard_Dark: a closed loop 0.04 thick in front of the grip, from y -0.13 to -0.38, z -0.05 to -0.45, round
  front, hollow inside (you can see through it from the side).
- Trigger_Accent: a curved blade 0.05 wide inside the guard, at z -0.20, from y -0.13 to -0.30, curved back.
- Hammer_Metal: a small rounded spur at the back top (z +0.32, y +0.20 to +0.32), 0.10 wide.
- FrontSight_Body: 0.07 wide, 0.07 tall block on the slide top at z -1.15 with one Dot (0.03) on its back face.
- RearSight_Body: 0.26 wide U-notch on the slide top at z +0.22, 0.08 tall, with a Dot on each side of the notch.

CHECK BEFORE EXPORT
- Render left side, right side, top and front. The silhouette from the side must read instantly as a pistol:
  slide on top, raked grip, open trigger guard, barrel tip.
- Nothing floats: every piece touches or sinks 0.01 into its neighbour. No holes in the mesh except the barrel
  hole and the trigger guard opening.
- The barrel points to -Z, origin at the top of the grip, total length 1.70.
- Fix every difference, then export.

EXPORT
- One binary file `pistol.glb`. Root node `Pistol` -> one mesh node per part with the names above
  (Slide_Body, Frame_Body, Barrel_Metal, Grip_Accent, TriggerGuard_Dark, Trigger_Accent, Hammer_Metal,
  FrontSight_Body, RearSight_Body). Small details of the same material may be merged into their part.
- Also print a materials table: name, hex color.
````

---

## Shotgun

````
3D model of a PUMP SHOTGUN for a Roblox game ("Survive 1 Million Angry Grandmas": a bright, funny, cartoon co-op
shooter for young players). Build ONE detailed, game-ready pump-action shotgun as a static prop (no rig). It must
look like a polished, chunky cartoon shotgun from a popular Roblox shooter: readable from far away, soft beveled
edges, real gun details, warm wooden furniture. NOT a plain block, NOT a few stacked boxes.

STYLE
- Stylized low-poly 3D with free mesh modelling: chamfers, bevels (~0.02 studs on every outer edge), grooves,
  rounded ends. Slightly chunky cartoon proportions.
- No textures, no text, no letters, no logos. Flat colors per material, bright neutral preview lighting.
- 2500-5000 triangles.

COLORS (materials, flat, exactly these, no darkening)
- Body   #3C3C42  (receiver)
- Accent #8C5528  (wooden pump and stock, warm brown)
- Metal  #9AA0AA  (barrel, magazine tube, bead)
- Dark   #18191D  (barrel hole, recoil pad, grooves, trigger guard)
- Brass  #E2B33C  (2 shotgun shells on the side saddle only)

SCALE AND ORIENTATION (1 unit = 1 Roblox stud)
- Total length 4.30 (back of the stock to the muzzle), height 0.95 (top of the receiver to the bottom of the
  stock heel), width 0.36.
- The barrel points toward -Z. Up is +Y. Centered on X.
- Origin (0,0,0) = where the shooting hand closes: the top of the pistol grip, under the receiver.

PARTS (each a separate mesh, exact names)
- Receiver_Body: 0.90 long (z +0.45 to -0.45), 0.42 tall (y -0.12 to +0.30), 0.34 wide, rounded top edge.
  Ejection port on the RIGHT side (+X): 0.40 x 0.14 recess at z -0.05. Side saddle on the LEFT side (-X): a plate
  with 2 Brass shells (0.12 diameter, 0.35 long, lying along Z) at z -0.10 and +0.15.
- Barrel_Metal: a cylinder 0.22 diameter from z -0.45 to -2.75, at y +0.18, with a Dark hole 0.14 diameter,
  0.06 deep, in its front face. A thin vent rib on top (0.06 wide, 0.03 tall) along its whole length. The front
  face of Barrel_Metal is the muzzle.
- Tube_Metal: magazine tube under the barrel, cylinder 0.18 diameter, z -0.45 to -2.45, y -0.05, with a rounded
  cap at the front.
- Pump_Accent: wooden fore-end around the tube, 0.75 long (z -0.95 to -1.70), 0.30 tall, 0.32 wide, rounded, with
  8 grip grooves (0.03 deep) around it.
- Grip_Accent: pistol grip under the back of the receiver, 0.50 tall (y -0.10 to -0.60), 0.26 wide, 0.30 deep,
  raked back 12 degrees, flows into the stock.
- Stock_Accent: wooden stock from z +0.45 to +1.50, top line slightly lower toward the back (drops 0.10), height
  0.42 at the receiver growing to 0.55 at the butt. Rounded edges.
- Pad_Dark: recoil pad at the back of the stock, 0.10 thick, same outline as the stock's end, 3 horizontal grooves.
- TriggerGuard_Dark: closed loop 0.04 thick under the receiver in front of the grip, z -0.05 to -0.40, hollow.
- Trigger_Metal: curved blade inside the guard at z -0.22.
- Bead_Metal: a small sphere 0.06 on the barrel top at z -2.68.

CHECK BEFORE EXPORT
- Render left side, right side, top and front. The side silhouette must read instantly as a pump shotgun: long
  barrel over a tube, wooden pump, wooden stock with a recoil pad.
- Nothing floats, no gaps between pieces, no holes except the barrel hole and the trigger guard opening.
- The barrel points to -Z, origin at the top of the grip, total length 4.30.
- Fix every difference, then export.

EXPORT
- One binary file `shotgun.glb`. Root node `Shotgun` -> one mesh node per part with the names above (Receiver_Body,
  Barrel_Metal, Tube_Metal, Pump_Accent, Grip_Accent, Stock_Accent, Pad_Dark, TriggerGuard_Dark, Trigger_Metal,
  Bead_Metal). The 2 shells may be merged into Receiver_Body as material Brass.
- Also print a materials table: name, hex color.
````

---

## Assault rifle

````
3D model of an ASSAULT RIFLE for a Roblox game ("Survive 1 Million Angry Grandmas": a bright, funny, cartoon
co-op shooter for young players). Build ONE detailed, game-ready modern assault rifle as a static prop (no rig).
It must look like a polished, chunky cartoon rifle from a popular Roblox shooter: readable from far away, soft
beveled edges, real gun details, gold accents. NOT a plain block, NOT a few stacked boxes.

STYLE
- Stylized low-poly 3D with free mesh modelling: chamfers, bevels (~0.02 studs on every outer edge), grooves,
  vents, slanted cuts. Slightly chunky cartoon proportions.
- No textures, no text, no letters, no logos. Flat colors per material, bright neutral preview lighting.
- 3000-6000 triangles.

COLORS (materials, flat, exactly these, no darkening)
- Body   #23262D  (upper and lower receiver, stock)
- Accent #C8AA46  (gold: magazine stripe, grip, scope rings, handguard side panels)
- Metal  #9AA0AA  (barrel, bolt, charging handle)
- Dark   #121317  (handguard, magazine, rail, flash hider, holes and grooves)
- Lens   #49D6FF  (scope glass front and back, emissive glow)

SCALE AND ORIENTATION (1 unit = 1 Roblox stud)
- Total length 4.30 (back of the stock to the end of the flash hider), height 1.30 (top of the scope to the
  bottom of the magazine), width 0.34.
- The barrel points toward -Z. Up is +Y. Centered on X.
- Origin (0,0,0) = where the shooting hand closes: the top of the pistol grip, under the receiver.

PARTS (each a separate mesh, exact names)
- Receiver_Body: 1.40 long (z +0.50 to -0.90), 0.40 tall (y -0.15 to +0.25), 0.30 wide. Ejection port on the
  RIGHT side (+X) at z -0.20 with a Metal bolt visible inside. Magazine well (0.26 wide) under it at z -0.55.
  Charging handle_Metal at the back top (z +0.45, a T-shape 0.30 wide).
- Handguard_Dark: z -0.90 to -2.10, 0.32 tall, 0.32 wide, 8-sided cross-section, 4 long vent slots (0.25 x 0.06)
  on each side. Gold Accent side panels (0.70 x 0.12) on BOTH sides, named HandguardPanel_Accent.
- Barrel_Metal: cylinder 0.12 diameter from z -2.10 to -2.55, y +0.10.
- FlashHider_Dark: cylinder 0.19 diameter, z -2.55 to -2.80, with 4 slots around the front; Dark hole 0.07 in the
  front face. Name it Barrel_FlashHider so the front face of the barrel group is the muzzle.
- Rail_Dark: picatinny rail on top, z +0.40 to -1.90, 0.14 wide, 0.06 tall, 14 ribs.
- Scope_Accent: a scope on the rail: tube 0.20 diameter, 0.80 long (z +0.10 to -0.70) at y +0.50, wider bells at
  both ends (0.26 diameter, 0.15 long), Lens circles on both ends, 2 gold rings holding it to the rail.
- Magazine_Dark: curved box magazine, 0.22 wide, 0.32 deep, 0.70 long, angled forward 14 degrees at the bottom,
  inserted in the magazine well at z -0.55; a gold Accent stripe 0.04 wide around it 0.10 from the bottom.
- Grip_Accent: pistol grip, 0.50 tall (y -0.15 to -0.65), 0.22 wide, 0.28 deep, raked back 14 degrees, 4 finger
  grooves on the front.
- TriggerGuard_Dark: closed loop under the receiver between grip and magazine, hollow; Trigger_Metal inside.
- Stock_Body: from z +0.50 to +1.50, a skeleton stock: top bar 0.10 thick and a slanted lower bar, open triangle
  between them (see-through), butt plate 0.50 tall at z +1.45 to +1.50 with a Dark rubber pad.

CHECK BEFORE EXPORT
- Render left side, right side, top and front. The side silhouette must read instantly as an assault rifle:
  scope on top, curved magazine, pistol grip, skeleton stock, vented handguard, flash hider.
- Nothing floats, no gaps, no holes except vents, the stock opening, the trigger guard opening and the barrel hole.
- The barrel points to -Z, origin at the top of the grip, total length 4.30.
- Fix every difference, then export.

EXPORT
- One binary file `assault_rifle.glb`. Root node `AssaultRifle` -> one mesh node per part with the names above
  (Receiver_Body, Handguard_Dark, HandguardPanel_Accent, Barrel_Metal, Barrel_FlashHider, Rail_Dark, Scope_Accent,
  Magazine_Dark, Grip_Accent, TriggerGuard_Dark, Trigger_Metal, Stock_Body). Small details may be merged into
  their part.
- Also print a materials table: name, hex color.
````
