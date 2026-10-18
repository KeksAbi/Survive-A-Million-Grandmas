# Phase 7 Studio test checklist

Tick each line. Anything wrong: screenshot + the red lines from Output.
**F5** = Play (your own account). **F7** = Server and Clients: set the player count (person icon, top left) first.

## Solo (F5)
- [ ] Full match wave 1 -> 10 without admin tools: countdowns, wave banner, kill counter, wave bonus.
- [ ] Wave 5 and 10: boss cutscene plays, sky stays dark until the wave ends, boss bar, stomp.
- [ ] Die during a wave: LAST CHANCE 20 countdown + REVIVE button; grandmas frozen; revive -> back in, wave goes on.
- [ ] Let LAST CHANCE run out -> GAME OVER, results, new match starts by itself.
- [ ] Revive once on wave 3, finish/lose the match, then die on wave 3 in the NEXT match: REVIVE must show again.
- [ ] Throw a grenade at the last grandma and die before it explodes: the wave must count as WON, not GAME OVER.
- [ ] Reload: R, empty magazine auto-reload, swapping guns during a reload.
- [ ] Shotgun: firing as fast as you can stays at about 1 shot per second, also when you swap guns in between.
- [ ] Shooting from behind the school bus / a house with the gun poking through: no hits through the wall.
- [ ] Shop: buy with too little cash -> "NOT ENOUGH CASH"; keys 1-3 buy/equip.
- [ ] Store: skins switch the held gun AND the icons in the shop, hotbar and store.
- [ ] Stats: Kills / Best Wave / Wins in the player list survive Stop + Play.

## Multiplayer (F7, 2-3 players)
- [ ] Grandmas chase different players.
- [ ] One player dies: spectates a teammate, REVIVE button, back next wave.
- [ ] Everyone dies: LAST CHANCE for everyone; any one revive saves the team.
- [ ] A player leaves mid-wave (close its window): the wave continues; if it was the last living player -> LAST
      CHANCE / GAME OVER, no error.
- [ ] Add a player mid-wave (Test > Add Clients): "WAVE IN PROGRESS", spectates, spawns next wave.
- [ ] Tracers of other players visible, golden for VIP skin.
- [ ] Test purchases in the client window (Player1 owns nothing): 2X CASH ($24 per normal grandma), VIP (tag,
      sparkles, golden gun), SKIN PACK (Candy/Toxic/Galaxy), REVIVE.

## Mobile (Test > Device Simulator / "Current device" dropdown -> a phone, then a tablet)
- [ ] FIRE / R / G buttons work and do not cover the grenade panel or Roblox's jump button.
- [ ] Holding FIRE with the rifle, sliding the finger off the button and lifting: firing must stop.
- [ ] Tap a hotbar slot to switch guns; STORE button (top left on touch) opens and closes.
- [ ] Shop / grenade / ammo / cash all readable, nothing cut off.

## Load
- [ ] Wave 9-10 with 3 players (F7): no big lag (FPS top right), 60 grandmas max on screen.
