# ZM-BO2-T6-Bots
An functional system for implement bos for BO2/T6.

Installation: Open Windows+R, write appdata, and follow this next direction: AppData/Local/Plutonium/storage/t6/mods (if you don't have a mods folder, create one with minus in all words) get into the folder and paste the zm_bots folder to it, now in the game, under all options is the Mods, select it and upload the mod. 

For setting the bots write the next **set zm_bots #** ""# is the amount of bots you want in the game" You can upload maximum 7 bots in a game (I don't know if you can upload more in Grief Mode) and puting max. player in the party = 8 pressing P before starting a match.

You can control the bots using LB+X/L1+Square/6 for make them wander/follow you/stay, is an inspiration for the BO3 ZM Bots Mod.

You can teleport all the bots to your position, press twice L3/L/5.

This bot is obviously just for having fun, because the full funcionality in specific maps was not implemented yet, I was working in Origins for the full funcionality for the bots (pick craftables, activate generators, dig, etc.) and that is like an ambition I have, make that for all maps (MOTD like Origins, Buried, Die Rise and Tranzit) with the NavMesh fully implemented, make the system for the bots to make EE's, but that's too ambitious, like I say, I began with Origins, but is a tedious work, so I'll better upload this for the community to taste/play.

If you detect a bug/issue in the mod, you can write the comment in the Plutonium forum/Github issues.

Thank you for your attention pal', especially for GerardS0406, BySc, techboy04gaming and RIKk01 that make this possible before this.

====================================================================================================================================================================================================

I made some fixes about the uploaded files of RIKk01 of the mod in April 2026, seeing that the incredible job he, and GerardS0406, BySc and techboy04gaming made for this wakes me an interested in working and adding my own touch to the mod. I made a lot of implementations/fixes about the .gsc files, and here is all I made, you can call this as the changelog if you want:

spawned_player fires again on the same entity every time a bot revives without death firing first. As a result, the entire thread tree from bot_main()/bot_health() of the previous life stayed alive forever, and every respawn stacked a full new copy on top. This exhausted the engine's child script variable limit, the error was everytime popping up as a: "exceeded maximum number of child server script variables" within 1-2 minutes with 3-7 bots, more minutes with a game of 4 players (1 player/3 bots) and 30s-1min with 8 players (1 player/7 bots).

For that, I made that the "bot_relife" notify was added right before relaunching the threads on every respawn, and all of the bot's long-running threads (bot_main, bot_health, bot_update_wander, bot_wander_watchdog, bot_failsafe_watchdog, bot_weapon_switch_think, bot_weapon_failsafe_monitor, bot_wakeup_think, bot_damage_think, bot_reset_flee_goal, bot_give_ammo) now have self endon("bot_relife"). Only one generation of threads exists per bot at any given time.

This system monitors a "heartbeat" (self.bot.wander_heartbeat, updated roughly every 0.1s inside bot_update_wander()). If more than 5s pass without a heartbeat, the movement thread died from an unexpected error and this watchdog restarts it. Previously, a bot that lost this thread would stay frozen in place for the rest of the match with no way to recover.

bot_update_failsafe() is like a rescue for bots stuck in geometry, it already existed in the original code but was never called from anywhere. It now runs every 4s, the function itself already self-throttles to every 3.5s via self.bot.update_failsafe.

Before this upload: The health of the bots was set to 1500 by counting get_players().size (humans + bots), so 3 humans + 2 bots would already lower the health even though there were only 2 real bots. Now bots are specifically counted (player.pers["isbot"]): with more than 4 bots, 1500 health is used; otherwise, 3000 health.

I identified that getnodesinradiussorted() and getnodesinradius() scale in cost with node density within the requested radius, not just with how many results are requested. These were replaced or trimmed in:
1. get_random_walkable_location(): It was previously used getnodesinradiussorted(), and crashed with a stack overflow above 800 units (my test, you can check this one in line 635 of zm_bo2_bots.gsc), and was called constantly for every idle bot. It now uses a bullettrace based search of random points + getnearestnode() + findpath() without touching the node graph at all.
2. bot_get_explore_target(): now tries getnearestnode() first before falling back to getnodesinradiussorted(door.origin, 256, 8, 16), before this it always used a 512 radius, 10,240 temp variables on a map with for example 20 doors.
3. bot_update_failsafe(): getnodesinradius() is now capped at a maximum of 48 random nodes instead of returning all nodes in the radius, which could be hundreds.
4. bot_nearest_node(): the getnodesinradiussorted(origin, 256, 0, 256) fallback was reduced to 0, 32.
5. bot_leader_kite_update(), bot_maintain_kiting_formation(), bot_panic_evade(), bot_combat_think(): as a reactive dodge, all of them migrated from the old getnodesinradiussorted() to the same bullettrace helper used by get_random_walkable_location().
6. bot_get_explore_target(): as a last resort branch, self.bot.visited_points was capped at 25 entries with pruning by age/distance, preventing unbounded growth of spawnstruct() that a repeatedly stuck bot (for example next to lava on zm_transit) generated on every cycle.

When all 15 attempts of get_random_walkable_location() fail, it now returns undefined instead of the bot's current position, which made it look frozen when given a goal pointing to where it was already standing. All call sites, 7, already checked isdefined(), so the change is safe.

I replaced the random exploration to a one priority-based exploration in bot_get_explore_target(): (needs deep testing)
1. Objectives registered by map extensions.
2. Unopened doors/debris across the whole map, claiming the door with bot_door_claimer so another bot doesn't head to the same spot.
3. Random far-off points, using 1500-5000 units via bullettrace + snap to navmesh node, with memory of already-visited points with self.bot.visited_points, pruned by time/distance to avoid always repeating the same corner.
4. As a last resort, this has a far point without filtering by visited locations.

Instead of only one bot at a time being able to do deep exploration, which in round-30 testing for example, meant only the doors near spawn ever got opened, up to 3 bots can now be explorers simultaneously in parallel, with an inactivity expiration of 20s to free up the slot with level.bot_explorers.

With bot_get_hunt_target() implemented, if the bot has no enemy in sight, it looks for the nearest reachable living zombie, this because previously it fell straight into random exploration/following. Normally capped at 4000 units; the mechanism the cap is lifted when there are like 3 zombies left alive in the round, avoiding losing entire rounds chasing 2-3 stragglers, which was the biggest bottleneck I found in a round-30 testing in Origins, where a bunch of 7 bots take time to find and kill the last zombies of the round.

Previously, bot_update_wander() used players[0] as its anchor, which could resolve to another bot, a downed/disconnected entity, or one without a valid origin, breaking the entire thread, leaving the bot frozen forever, since this is the only thread controlling movement. Now it explicitly looks for a living human by checking both pers["isbot"] and .bot. If no valid human exists, the hunt/exploration system keeps working fully autonomously.

Previously, a bot deep-exploring toward a far area got yanked back to the human as soon as it got 4500 units away which was exactly what prevented completing real exploration routes. Now that safety net only kicks in if the bot is genuinely lost/isolated, like 9000 units, not on every normal lap.

Bots that aren't actively reviving now form a perimeter around the downed player with guard_claimer_count, max 2 guards, random offset to avoid clustering, instead of continuing their normal routine and leaving the reviver exposed.

This was an inspiration of the ZM Bots mod of BO3/BOIII, I implemented a button combo (L1/LB + Square/X) movement behavior between wander (normal) or follow (follow the player who triggered the command) or stay (hold position) or again wander and like that every time we push the buttons. Implemented via level.bot_tomb_command_mode and level.bot_tomb_commander. This doesn't interfere with combat, reviving, or box purchases, those guards still take priority.

With bot_leader_kite_update(), this computes the center of mass of nearby zombies with bot_get_zombie_cluster_center(), the bot moves tangentially (perpendicular) to create a real loop instead of a straight-line retreat, with a random direction reversal every 8-16s so the horde doesn't learn to cut across. It doesn't interrupt a shot that's already lined up.
bot_maintain_kiting_formation() is the same principle, but only acts if the bot is closer to the horde than the leader.

The underlying problem I found is that the zombie AI targets the nearest player, so if bots flee independently, the horde's attention splits between them instead of following a single clean loop. The solution was that every 0.75s, with a +2 hysteresis to prevent flickering, the bot with the most nearby zombies, using bot_count_nearby_zombies() is chosen as "leader." Only that bot actively kites in a loop with bot_leader_kite_update(); the rest deliberately stay farther from the horde's center than the leader with bot_maintain_kiting_formation(), so zombies keep preferring the leader as the nearest target.

With bot_update_panic_state implemented, this detects the moment a bot should "panic" (health ≤30% with a zombie already attached, or proactively if there are ≥4 zombies within 200 units, regardless of health). Previously, the bot only reacted once already critical; now it reacts to being surrounded, just like a real player would.
With bot_panic_evade() evades away from all nearby zombies in a proximity-weighted repulsion, not just the closest one, looking for the actual gap in the circle. Reaction cooldown of just 120ms, is the most aggressive in the whole mod. The escape jump distance is 450 units, it was previously 250, which was just below the engine's sprint threshold that bot_sprintdistance = 256 used, so bots never actually sprinted while fleeing. While panicking always fires from the hip, so never ADS, which is more accurate but slower, doesn't melee, doesn't throw grenades, and has a wider aim tolerance, with 100 instead of 70 — prioritizing speed over precision, just like a cornered player.

The fire-eligibility check allowattack(1), required angular alignment on its own, without verifying real line of sight. It now also requires a fresh botsighttracepassed() before every shot — previously a bot could keep "firing" at a wall if the target ducked behind it.
The aim check compared against threat.entity.origin instead of the actual aim point with threat.aim_target, which has a height offset. This made bot_on_target() fail even when the bot was correctly aligned — the real cause of the "aims but doesn't fire" or "aims above the head" bug.
The fixed height offset, up to +36 at short range, overestimated head height on many zombie models/poses, causing shots to fly over the target. It now aims at the zombie's centroid with a random +-8 jitter, prioritizing consistent hits over a "pretty" aim at one specific point.
frac = (time - time_first_sight) / 100 or / 50: aim correction now converges twice as fast after spotting a target.

With bot_best_enemy() was implemented because previously it strictly picked the nearest zombie arraysort + first valid result. Now every zombie gets a score 2000 - distance +500 if within 100 units, +600/+250 if it's threatening a downed teammate within 400/800 units via get_active_revive_point() and the best one is chosen. This makes a bot on guard actually protect the reviver instead of just shooting whatever is closest to itself.

With bot_expire_stale_threat(), a 350ms "memory" window after losing sight of a target before forgetting it entirely, for example a real player doesn't instantly forget a zombie that ducked out of view. It doesn't affect the actual firing decision, which always requires a fresh trace, only how long the bot keeps looking toward the last known position.

Why throw grenades at round 1-2? With bot_should_throw_grenade() and bot_combat_throw_grenade() requires a real cluster (6-7 zombies within 350 units, previously 1000 — which was essentially "the whole horde"), with a throw probability that drops from 35% in early rounds to 8% in late rounds (so it's an occasional decision, not an automatic reflex). Long cooldown (20-32s + half a second per round) so a bot doesn't empty its entire grenade stock at once. Switches to the grenade, checks the target is still alive before and during the throw, and returns to the original weapon afterward.

Previously, a zombie with health below the knife-damage threshold remained "meleeable" in any round, which made bots try to close in for a melee kill instead of just shooting — making it look like they "only shoot while backing away" (backing off was the only thing that took them out of melee range). Now, from round 3 onward melee never happens; the bot always shoots instead. Melee is also disabled while panicking (a melee animation leaves you exposed if you're surrounded of course).

Implementing bot_should_visit_box(), because previously, bot_should_take_weapon() only evaluated what to do with whatever came out of the box after spending 950 points. Now, if the whole loadout is already top-tier, the bot simply doesn't go to the box. If it has a free slot, it only goes if its worst weapon has a score <90; with both slots full, only if the worst score is <75. Point buffer raised from 950 to 1200 (except with a truly bad weapon, where the minimum is kept).

With level.bot_last_team_box_use, each bot already had its own individual cooldown from 90-900s depending on round, but with 3-4 bots for example deciding "it's worth it" in similar windows, there was always someone off cooldown — the box looked permanently camped from a human's perspective. There's now a 20s team-wide cooldown between uses by any bot.

If box.zbarrier.weapon_string or box.weapon_string don't exist in maps/versions that don't expose that info, it now detects which weapon was actually received by comparing inventory before/after, it deliberately switches to its worst weapon right before pulling the box to allow this comparison. If the result is bad (<75), the box cooldown is halved so it can retry sooner.

Implementing bot_get_perk_value(), because previously, bot_buy_perks() bought the first affordable perk it found, in the order the machine listed them. Now every available perk is scored based on the bot's actual context (equipped weapon, round, whether it's the current train leader, etc.) and the best one is bought:
- Juggernog: 95.
- Deadshot Daiquiri: 45.
- Speed Cola: 90.
- Double Tap II: 65, +15 with rifle/SMG/pistol.
- Quick Revive: 70, +25 if round <15.
- Stamin-Up: 60, +30 if the bot is the current train leader, +15 in rounds ≥10.
- Mule Kick: 45, +20 if it has no backup weapon.
- Who's Who: 70. Tombstone Soda: 40. Electric Cherry: 60 (+10 with frequently-reloading weapons). Vulture Aid: 30.

Implemented level.bot_cached_perks, because previously, the available perks/costs arrays were rebuilt every 60s, for every bot. Now the first bot to arrive builds the list and stores it in level; everyone else just reads it. Per-map availability list corrected and expanded (Stamin-Up, Mule Kick, Deadshot, Tombstone, Who's Who, Electric Cherry, Vulture Aid, each with its real map condition).

Implemented bot_pack_gun(), because previously the PaP had no cooldown of its own; it ran on every damage tick in bot_main(), so a bot with a lot of points could try to Pack-a-Punch on every hit taken. It now respects self.bot.next_pap_time with 5s.

bot_tomb_get_nearest_door_cost() was implemented, because before spending on a wallbuy, if the current weapon isn't entirely bad (score ≥50), the cost of the cheapest open-and-reachable door is reserved, so the bot doesn't run out of points to progress through the map.

The loop that scans all wall weapons with findpath() ran on every tick while the bot hadn't chosen one yet, for example no money, or already has a good weapon. It now has its own 2.5s throttle, independent of the existing post-selection cooldown.

Every 2s, if the bot heading to revive hasn't reduced its distance to the downed teammate by more than 100 units and is surrounded by 3 zombies within 200 units at minimun, it drops the claim revive_claimer_count--, applies a 3s lockout in revive_claim_blocked_until to avoid immediately re-claiming the same teammate, and yields to another bot with a better path or position.

New revive_last_claim_time, now if more than 10s have passed since the last claim on a downed player, reviving is allowed regardless of how many claimers are already counted prevents a stale count from indefinitely blocking a revive.

The original code had no handling at all for the "afterlife" state (This one was confusing, but I guess is Who's Who for Die Rise, again, testing is needed). Now, if the bot is in afterlife with an active corpse (self.e_afterlife_corpse), it walks to it and simulates the use button press (pressusebutton(2)) until complete or until the condition breaks (corpse changes, exits afterlife, or moves more than 75 units away).

Coordination helper with get_active_revive_point(): any bot can check whether someone is currently downed, without necessarily being the one reviving them. Used both by the guard formation and by combat target prioritization.

I added a button combination with L1+Square/LB+X, for have the wander/follow/stay system that exist in the BO3 ZM Bots Mod.

bot_buy_door() now claims the door bot_door_claimer = self synchronously before any wait or point deduction (GSC threads only switch context on a wait/notify, so this fully closes the race window). Includes a safety net: if the "claimer" dies or disconnects or goes more than 4s without buying, the claim is released so another bot can try.

Previously, _door_open and has_been_opened were set to 1 immediately after launching the opening thread, without waiting for it to finish. If door_buy() failed or never completed, the door ended up marked open without actually being open, blocking any other bot from buying it. Now bot_finish_door_open(), the flag is set after the actual opening finishes; if it fails, the claim simply expires via the 4s safety net.

With bot_force_door_nearby, the bot ran on every wakeup tick (as often as every 0.05-0.1s), looping through the entire doors array. It now has its own 250ms throttle, and also claims the door bot_door_claimer, both when buying it instantly and when walking toward it — previously it didn't, allowing two bots to head to the same door. Its unused twin function, bot_force_door_approach(), was removed as dead code, because it was never called from anywhere.

bot_buy_door() now checks isdefined(door) and isdefined(door.origin) before operating on each door. bot_buy_wallbuy() now checks that level._spawned_wallbuys exists and has elements before calling array_randomize() on it, this was previously a guaranteed error on maps/modes that don't populate it.

The detection radius of doors extended from 90000 to 250000 (units^2); debris reduced from 160000 to 90000, for more realistic behavior for each, independently.
