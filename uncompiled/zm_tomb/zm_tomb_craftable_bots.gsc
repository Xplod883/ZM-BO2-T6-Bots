
#include common_scripts\utility;
#include maps\mp\_utility;
#include maps\mp\zombies\_zm_utility;
#include maps\mp\zm_tomb_craftables;
#include maps\mp\zombies\_zm_equipment;
#include maps\mp\zombies\_zm_laststand;
#include maps\mp\zombies\_zm_craftables;

#include scripts\zm\zm_bo2_bots;

main()
{
	if(getdvar("mapname") != "zm_tomb")
		return;

	level thread zm_tomb_bot_craftable_coordinator();

	scripts\zm\zm_bo2_bots::bot_tomb_register_objective_provider(::bot_tomb_explore_objective_craftables, 10);
}

bot_tomb_explore_objective_craftables()
{
	finished_uts = bot_tomb_find_finished_table_to_take();

	if(isdefined(finished_uts) && isdefined(finished_uts.origin))
		return bot_tomb_get_ground_point(finished_uts.origin);

	piece = self bot_tomb_find_nearest_loose_piece();

	if(isdefined(piece) && isdefined(piece.model) && isdefined(piece.model.origin))
		return bot_tomb_get_ground_point(piece.model.origin);

	ready_uts = self bot_tomb_find_ready_shared_table();

	if(isdefined(ready_uts) && isdefined(ready_uts.origin))
		return bot_tomb_get_ground_point(ready_uts.origin);

	return undefined;
}

zm_tomb_bot_craftable_coordinator()
{
	level endon("end_game");

	for(;;)
	{
		foreach(player in get_players())
		{
			if(!isdefined(player.pers["isbot"]))
				continue;

			if(isdefined(player.bot_tomb_craftable_coordinated))
				continue;

			player.bot_tomb_craftable_coordinated = true;

			player thread bot_tomb_craftable_watch_respawn();
		}

		wait 1;
	}
}

bot_tomb_craftable_watch_respawn()
{
	self endon("disconnect");

	level endon("end_game");

	for(;;)
	{
		if(isalive(self))
			self thread bot_tomb_craftable_think();

		self waittill("spawned_player");
	}
}

bot_tomb_craftable_think()
{
	self endon("disconnect");
	self endon("death");

	level endon("end_game");

	for(;;)
	{
		self bot_tomb_craftable_update();

		wait 0.5;
	}
}

bot_tomb_craftable_update()
{
	if(self maps\mp\zombies\_zm_laststand::player_is_in_laststand())
		return;

	if(is_true(self.bot.is_using_box) || is_true(self.bot.is_reviving) || is_true(self.bot.is_selfreviving) || is_true(self.bot.is_throwing_grenade))
		return;

	if(is_true(self.bot.is_panicking))
		return;

	if(is_true(self.bot_tomb_is_digging) || is_true(self.bot_tomb_is_crystal_questing) || is_true(self.bot_tomb_is_charging))
		return;

	if(isdefined(level.bot_train_leader) && level.bot_train_leader == self)
		return;

	if(is_true(self.bot_tomb_is_crafting))
		return;

	if(isdefined(self.current_craftable_piece) && bot_tomb_is_elemental_crystal_piece(self.current_craftable_piece))
	{
		uts = bot_tomb_find_craftable_table(self.current_craftable_piece.craftablename);

		if(isdefined(uts))
		{
			self bot_tomb_pursue_build(uts);
			return;
		}
	}

	if(isdefined(level.zone_capture) && isdefined(level.zone_capture.zones) && !self bot_tomb_has_immediate_craftable_action())
	{
		foreach(key, zone in level.zone_capture.zones)
		{
			if(!isdefined(zone) || !zone ent_flag("zone_contested"))
				continue;

			if(distancesquared(self.origin, zone.origin) <= 1440000)
				return;
		}
	}

	if(!isdefined(level.a_uts_craftables))
		return;

	finished_uts = bot_tomb_find_finished_table_to_take();

	if(isdefined(finished_uts))
	{
		self bot_tomb_pursue_build(finished_uts);
		return;
	}

	if(isdefined(self.current_craftable_piece))
	{
		uts = bot_tomb_find_craftable_table(self.current_craftable_piece.craftablename);

		if(isdefined(uts))
			self bot_tomb_pursue_build(uts);

		return;
	}

	ready_uts = bot_tomb_find_ready_shared_table();

	if(isdefined(ready_uts))
	{
		self bot_tomb_pursue_build(ready_uts);
		return;
	}

	self bot_tomb_pursue_piece();
}

bot_tomb_has_immediate_craftable_action()
{
	finished_uts = bot_tomb_find_finished_table_to_take();

	if(isdefined(finished_uts) && isdefined(finished_uts.origin) && distancesquared(self.origin, finished_uts.origin) <= 22500)
		return true;

	if(isdefined(self.current_craftable_piece))
	{
		uts = bot_tomb_find_craftable_table(self.current_craftable_piece.craftablename);

		if(isdefined(uts) && isdefined(uts.origin) && distancesquared(self.origin, uts.origin) <= 22500)
			return true;
	}

	ready_uts = bot_tomb_find_ready_shared_table();

	if(isdefined(ready_uts) && isdefined(ready_uts.origin) && distancesquared(self.origin, ready_uts.origin) <= 22500)
		return true;

	piece = self bot_tomb_find_nearest_loose_piece();

	if(isdefined(piece) && isdefined(piece.model) && isdefined(piece.model.origin) && distancesquared(self.origin, piece.model.origin) <= 22500)
		return true;

	return false;
}

bot_tomb_find_craftable_table(craftablename)
{
	foreach(uts in level.a_uts_craftables)
	{
		if(!isdefined(uts) || uts.equipname == "open_table")
			continue;

		if(is_true(uts.crafted))
			continue;

		if(uts.equipname == craftablename)
			return uts;
	}

	return undefined;
}

bot_tomb_find_ready_shared_table()
{
	foreach(uts in level.a_uts_craftables)
	{
		if(!isdefined(uts) || uts.equipname == "open_table")
			continue;

		if(is_true(uts.crafted))
			continue;

		if(!isdefined(uts.craftablespawn))
			continue;

		if(isdefined(uts.tomb_bot_claimer) && uts.tomb_bot_claimer != self && isalive(uts.tomb_bot_claimer))
			continue;

		if(uts.craftablespawn craftable_can_use_shared_piece())
			return uts;
	}

	return undefined;
}

bot_tomb_find_finished_table_to_take()
{
	foreach(uts in level.a_uts_craftables)
	{
		if(!isdefined(uts) || uts.equipname == "open_table")
			continue;

		if(!is_true(uts.crafted))
			continue;

		if(!isdefined(uts.weaponname) || !isdefined(uts.origin))
			continue;

		if(self hasweapon(uts.weaponname))
			continue;

		if(bot_tomb_is_staff_weapon(uts.weaponname) && !self maps\mp\zm_tomb_craftables::is_unclaimed_staff_weapon(uts.weaponname))
			continue;

		if(isdefined(uts.tomb_bot_claimer) && uts.tomb_bot_claimer != self && isalive(uts.tomb_bot_claimer))
			continue;

		return uts;
	}

	return undefined;
}

bot_tomb_find_nearest_loose_piece()
{
	closest = undefined;
	closest_dist_sq = 999999999;

	foreach(uts in level.a_uts_craftables)
	{
		if(!isdefined(uts) || uts.equipname == "open_table" || !isdefined(uts.craftablespawn))
			continue;

		foreach(piecespawn in uts.craftablespawn.a_piecespawns)
		{
			if(!isdefined(piecespawn) || !isdefined(piecespawn.model) || !isdefined(piecespawn.model.origin))
				continue;

			if(is_true(piecespawn.crafted) || is_true(piecespawn.in_shared_inventory))
				continue;

			if(isdefined(uts.equipname) && issubstr(uts.equipname, "elemental_staff_") && isdefined(piecespawn.piecename) && piecespawn.piecename == "gem")
				continue;

			if(isdefined(piecespawn.tomb_bot_claimer) && piecespawn.tomb_bot_claimer != self && isalive(piecespawn.tomb_bot_claimer))
				continue;

			d = distancesquared(self.origin, piecespawn.model.origin);

			if(d < closest_dist_sq)
			{
				closest_dist_sq = d;
				closest = piecespawn;
			}
		}
	}

	return closest;
}

bot_tomb_get_ground_point(origin)
{
	trace_start = (origin[0], origin[1], origin[2] + 40);
	trace_end = (origin[0], origin[1], origin[2] - 200);

	ground_trace = bullettrace(trace_start, trace_end, 0, undefined);

	if(!isdefined(ground_trace) || !isdefined(ground_trace["position"]))
		return origin;

	return ground_trace["position"];
}

bot_tomb_pursue_piece()
{
	piece = bot_tomb_find_nearest_loose_piece();

	if(!isdefined(piece))
	{
		if(self hasgoal("craftable_piece"))
			self cancelgoal("craftable_piece");

		return;
	}

	ground_origin = bot_tomb_get_ground_point(piece.model.origin);

	if(!findpath(self.origin, ground_origin, undefined, 0, 1))
		return;

	dist_sq = distancesquared(self.origin, piece.model.origin);

	if(dist_sq > 22500)
	{
		piece.tomb_bot_claimer = self;

		if(!self hasgoal("craftable_piece") || distancesquared(self getgoal("craftable_piece"), ground_origin) > 2500)
		{
			self cancelgoal("craftable_piece");
			self addgoal(ground_origin, 40, 2, "craftable_piece");
		}

		return;
	}

	self cancelgoal("craftable_piece");

	self thread bot_tomb_do_take_piece(piece);
}

bot_tomb_pursue_build(uts)
{
	if(!isdefined(uts) || !isdefined(uts.origin))
		return;

	ground_origin = bot_tomb_get_ground_point(uts.origin);

	if(!findpath(self.origin, ground_origin, undefined, 0, 1))
		return;

	dist_sq = distancesquared(self.origin, uts.origin);

	if(dist_sq > 22500)
	{
		uts.tomb_bot_claimer = self;

		if(!self hasgoal("craftable_build") || distancesquared(self getgoal("craftable_build"), ground_origin) > 2500)
		{
			self cancelgoal("craftable_build");
			self addgoal(ground_origin, 50, 2, "craftable_build");
		}

		return;
	}

	self cancelgoal("craftable_build");

	self thread bot_tomb_do_craft(uts);
}

bot_tomb_do_take_piece(piece)
{
	self endon("disconnect");
	level endon("end_game");

	self.bot_tomb_is_crafting = true;

	self thread bot_tomb_craftable_cleanup_watcher(piece);

	self allowattack(0);
	self pressads(0);

	if(self getgoal("wander") || self hasgoal("wander"))
		self cancelgoal("wander");

	windup_end = gettime() + 300;

	while(gettime() < windup_end)
	{
		if(!isdefined(self) || !isalive(self))
			break;

		if(!isdefined(piece) || !isdefined(piece.model) || !isdefined(piece.model.origin))
			break;

		if(self maps\mp\zombies\_zm_laststand::player_is_in_laststand())
			break;

		self lookat(self bot_tomb_get_lookat_point(piece.model.origin));

		wait 0.05;
	}

	if(isdefined(self) && isalive(self))
		self clearlookat();

	if(isdefined(self) && isalive(self) && isdefined(piece) && isdefined(piece.model) && isdefined(piece.model.origin)
		&& !is_true(piece.crafted) && !is_true(piece.in_shared_inventory)
		&& !isdefined(self.current_craftable_piece)
		&& !self maps\mp\zombies\_zm_laststand::player_is_in_laststand()
		&& distancesquared(self.origin, piece.model.origin) <= 22500)
	{
		self player_take_piece(piece);
	}

	self notify("tomb_craftable_attempt_done");
}

bot_tomb_craftable_cleanup_watcher(claimable)
{
	self waittill_any("tomb_craftable_attempt_done", "death", "disconnect");

	if(isdefined(claimable) && isdefined(claimable.tomb_bot_claimer) && claimable.tomb_bot_claimer == self)
		claimable.tomb_bot_claimer = undefined;

	self.bot_tomb_is_crafting = false;
}

bot_tomb_do_craft(uts)
{
	self endon("disconnect");
	level endon("end_game");

	self.bot_tomb_is_crafting = true;

	self thread bot_tomb_craftable_cleanup_watcher(uts);

	self allowattack(0);
	self pressads(0);

	if(self getgoal("wander") || self hasgoal("wander"))
		self cancelgoal("wander");

	windup_end = gettime() + 800;

	while(gettime() < windup_end)
	{
		if(!isdefined(self) || !isalive(self))
			break;

		if(!isdefined(uts) || !isdefined(uts.origin))
			break;

		if(is_true(uts.crafted) && isdefined(uts.weaponname) && self hasweapon(uts.weaponname))
			break;

		if(self maps\mp\zombies\_zm_laststand::player_is_in_laststand())
			break;

		self lookat(self bot_tomb_get_lookat_point(uts.origin));
		self usebuttonpressed();

		wait 0.05;
	}

	if(isdefined(self) && isalive(self))
		self clearlookat();

	if(isdefined(self) && isalive(self) && isdefined(uts) && isdefined(uts.origin)
		&& !self maps\mp\zombies\_zm_laststand::player_is_in_laststand()
		&& distancesquared(self.origin, uts.origin) <= 22500)
	{
		if(is_true(uts.crafted))
		{
			if(isdefined(uts.weaponname) && !self hasweapon(uts.weaponname))
			{
				if(bot_tomb_is_staff_weapon(uts.weaponname))
				{

					wrapper = spawnstruct();
					wrapper.stub = uts;
					wrapper maps\mp\zm_tomb_craftables::tomb_check_crafted_weapon_persistence(self);
				}
				else
				{
					maps\mp\zombies\_zm_equipment::equipment_buy(uts.weaponname);
					self giveweapon(uts.weaponname);
					self setweaponammoclip(uts.weaponname, 1);

					if(uts.weaponname != "keys_zm")
						self setactionslot(1, "weapon", uts.weaponname);
				}
			}
		}
		else if(isdefined(uts.craftablespawn)
			&& (uts.craftablespawn craftable_can_use_shared_piece() || (isdefined(self.current_craftable_piece) && self.current_craftable_piece.craftablename == uts.equipname)))
		{
			self player_craft(uts.craftablespawn);
		}
	}

	self notify("tomb_craftable_attempt_done");
}

bot_tomb_get_lookat_point(pos)
{
	eye_z = self.origin[2] + 45;

	return (pos[0], pos[1], eye_z);
}

bot_tomb_is_staff_weapon(weaponname)
{
	return weaponname == "staff_air_zm" || weaponname == "staff_fire_zm" || weaponname == "staff_lightning_zm" || weaponname == "staff_water_zm";
}

bot_tomb_is_elemental_crystal_piece(piece)
{
	if(!isdefined(piece) || !isdefined(piece.craftablename))
		return false;

	return piece.craftablename == "elemental_staff_air" || piece.craftablename == "elemental_staff_fire" || piece.craftablename == "elemental_staff_lightning" || piece.craftablename == "elemental_staff_water";
}
