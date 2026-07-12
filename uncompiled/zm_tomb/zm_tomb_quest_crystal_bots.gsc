
#include common_scripts\utility;
#include maps\mp\_utility;
#include maps\mp\zombies\_zm_utility;
#include maps\mp\zombies\_zm_laststand;

#include scripts\zm\zm_bo2_bots;

main()
{
	if(getdvar("mapname") != "zm_tomb")
		return;

	level thread zm_tomb_bot_crystal_coordinator();
}

zm_tomb_bot_crystal_coordinator()
{
	level endon("end_game");

	level thread zm_tomb_crystal_teleport_watcher();

	for(;;)
	{
		foreach(player in get_players())
		{
			if(!isdefined(player.pers["isbot"]))
				continue;

			if(isdefined(player.bot_tomb_crystal_coordinated))
				continue;

			player.bot_tomb_crystal_coordinated = true;

			player thread bot_tomb_crystal_watch_respawn();
		}

		wait 1;
	}
}

zm_tomb_crystal_teleport_watcher()
{
	level endon("end_game");

	level.tomb_crystal_teleported = [];

	for(;;)
	{
		level waittill("player_teleported", e_player, n_teleport_enum);

		level.tomb_crystal_teleported[n_teleport_enum] = true;

		if(isdefined(e_player))
		{
			if(!isdefined(e_player.tomb_crystal_teleported_here))
				e_player.tomb_crystal_teleported_here = [];

			e_player.tomb_crystal_teleported_here[n_teleport_enum] = true;
		}
	}
}

bot_tomb_crystal_watch_respawn()
{
	self endon("disconnect");

	level endon("end_game");

	for(;;)
	{
		if(isalive(self))
			self thread bot_tomb_crystal_think();

		self waittill("spawned_player");
	}
}

bot_tomb_crystal_think()
{
	self endon("disconnect");
	self endon("death");

	level endon("end_game");

	for(;;)
	{
		self bot_tomb_crystal_update();

		wait 0.5;
	}
}

bot_tomb_crystal_get_element_info(n_enum)
{
	info = spawnstruct();
	info.enum = n_enum;

	switch(n_enum)
	{
		case 1:
			info.open_flag = "fire_open";
			info.craftable_name = "elemental_staff_fire";
			break;
		case 2:
			info.open_flag = "air_open";
			info.craftable_name = "elemental_staff_air";
			break;
		case 3:
			info.open_flag = "lightning_open";
			info.craftable_name = "elemental_staff_lightning";
			break;
		case 4:
			info.open_flag = "ice_open";
			info.craftable_name = "elemental_staff_water";
			break;
		default:
			return undefined;
	}

	info.plinth_targetname = "crystal_plinth" + n_enum;

	return info;
}

bot_tomb_crystal_update()
{
	if(self maps\mp\zombies\_zm_laststand::player_is_in_laststand())
		return;

	if(is_true(self.bot.is_using_box) || is_true(self.bot.is_buying) || is_true(self.bot.is_reviving) || is_true(self.bot.is_selfreviving) || is_true(self.bot.is_throwing_grenade))
		return;

	if(is_true(self.bot.is_panicking))
		return;

	if(isdefined(level.bot_train_leader) && level.bot_train_leader == self)
		return;

	if(is_true(self.bot_tomb_is_digging) || is_true(self.bot_tomb_is_crafting) || is_true(self.bot_tomb_is_capturing) || is_true(self.bot_tomb_is_charging))
		return;

	if(is_true(self.bot_tomb_is_crystal_questing))
		return;

	if(isdefined(self.current_craftable_piece))
		return;

	tunnels = getstructarray("stargate_gramophone_pos", "targetname");

	if(!isdefined(tunnels))
		return;

	if(!flag("gramophone_placed"))
	{
		foreach(tunnel in tunnels)
		{
			if(!isdefined(tunnel) || !isdefined(tunnel.script_int))
				continue;

			info = bot_tomb_crystal_get_element_info(tunnel.script_int);

			if(!isdefined(info) || flag(info.open_flag))
				continue;

			if(bot_tomb_crystal_piece_exists(info.craftable_name))
				continue;

			if(isdefined(tunnel.gramophone_model))
				continue;

			if(!is_true(tunnel.has_vinyl))
				continue;

			self bot_tomb_crystal_pursue_place_gramophone(tunnel);
			return;
		}
	}

	foreach(tunnel in tunnels)
	{
		if(!isdefined(tunnel) || !isdefined(tunnel.script_int) || !isdefined(tunnel.gramophone_model))
			continue;

		info = bot_tomb_crystal_get_element_info(tunnel.script_int);

		if(!isdefined(info) || flag(info.open_flag))
			continue;

		if(bot_tomb_crystal_piece_exists(info.craftable_name))
			continue;

		if(flag("enable_teleporter_" + info.enum) && !is_true(level.tomb_crystal_teleported[info.enum]))
		{
			self bot_tomb_crystal_pursue_teleporter(info);
			return;
		}

		if(isdefined(self.tomb_crystal_teleported_here) && is_true(self.tomb_crystal_teleported_here[info.enum]))
		{
			self bot_tomb_crystal_pursue_plinth(info);
			return;
		}

		return;
	}
}

bot_tomb_crystal_piece_exists(craftable_name)
{
	if(!isdefined(level.a_uts_craftables))
		return false;

	foreach(uts in level.a_uts_craftables)
	{
		if(!isdefined(uts) || uts.equipname != craftable_name || !isdefined(uts.craftablespawn))
			continue;

		if(is_true(uts.crafted))
			return true;

		foreach(piecespawn in uts.craftablespawn.a_piecespawns)
		{
			if(isdefined(piecespawn) && (isdefined(piecespawn.model) || is_true(piecespawn.crafted)))
				return true;
		}
	}

	return false;
}

bot_tomb_crystal_pursue_place_gramophone(tunnel)
{
	if(!findpath(self.origin, tunnel.origin, undefined, 0, 1))
		return;

	dist_sq = distancesquared(self.origin, tunnel.origin);

	if(dist_sq > 22500)
	{
		tunnel.tomb_bot_claimer = self;

		if(!self hasgoal("crystal_gramophone") || distancesquared(self getgoal("crystal_gramophone"), tunnel.origin) > 2500)
		{
			self cancelgoal("crystal_gramophone");
			self addgoal(tunnel.origin, 40, 2, "crystal_gramophone");
		}

		return;
	}

	self cancelgoal("crystal_gramophone");

	self thread bot_tomb_crystal_do_place_gramophone(tunnel);
}

bot_tomb_crystal_do_place_gramophone(tunnel)
{
	self endon("disconnect");
	level endon("end_game");

	self.bot_tomb_is_crystal_questing = true;

	self thread bot_tomb_crystal_cleanup_watcher(tunnel);

	self allowattack(0);
	self pressads(0);

	if(self getgoal("wander") || self hasgoal("wander"))
		self cancelgoal("wander");

	stub = bot_tomb_crystal_find_stub_at(tunnel.origin);

	timeout = gettime() + 4000;

	while(gettime() < timeout)
	{
		if(!isdefined(self) || !isalive(self))
			break;

		if(!isdefined(tunnel) || isdefined(tunnel.gramophone_model) || flag("gramophone_placed"))
			break;

		if(self maps\mp\zombies\_zm_laststand::player_is_in_laststand())
			break;

		if(distancesquared(self.origin, tunnel.origin) > 22500)
			break;

		self lookat(self bot_tomb_crystal_get_lookat_point(tunnel.origin));

		if(!isdefined(stub))
			stub = bot_tomb_crystal_find_stub_at(tunnel.origin);

		if(isdefined(stub))
			stub notify("trigger", self);

		wait 0.05;
	}

	if(isdefined(self) && isalive(self))
		self clearlookat();

	self notify("tomb_crystal_attempt_done");
}

bot_tomb_crystal_pursue_teleporter(info)
{
	pads = getstructarray("trigger_teleport_pad", "targetname");

	if(!isdefined(pads))
		return;

	pad = undefined;

	foreach(candidate in pads)
	{
		if(isdefined(candidate) && isdefined(candidate.script_int) && candidate.script_int == info.enum)
		{
			pad = candidate;
			break;
		}
	}

	if(!isdefined(pad))
		return;

	target = pad.origin - (0, 0, 30);

	if(!findpath(self.origin, target, undefined, 0, 1))
		return;

	dist_sq = distancesquared(self.origin, target);

	if(dist_sq > 2500)
	{
		if(!self hasgoal("crystal_teleporter") || distancesquared(self getgoal("crystal_teleporter"), target) > 900)
		{
			self cancelgoal("crystal_teleporter");
			self addgoal(target, 35, 2, "crystal_teleporter");
		}

		return;
	}

	self cancelgoal("crystal_teleporter");

	self thread bot_tomb_crystal_do_stand_in_teleporter(target, info);
}

bot_tomb_crystal_do_stand_in_teleporter(target, info)
{
	self endon("disconnect");
	level endon("end_game");

	self.bot_tomb_is_crystal_questing = true;

	self thread bot_tomb_crystal_cleanup_watcher(undefined);

	if(self getgoal("wander") || self hasgoal("wander"))
		self cancelgoal("wander");

	timeout = gettime() + 3000;

	while(gettime() < timeout)
	{
		if(!isdefined(self) || !isalive(self))
			break;

		if(is_true(level.tomb_crystal_teleported[info.enum]))
			break;

		if(self maps\mp\zombies\_zm_laststand::player_is_in_laststand())
			break;

		if(!flag("enable_teleporter_" + info.enum))
			break;

		if(distancesquared(self.origin, target) > 22500)
			break;

		wait 0.1;
	}

	self notify("tomb_crystal_attempt_done");
}

bot_tomb_crystal_pursue_plinth(info)
{
	plinth = getent(info.plinth_targetname, "targetname");

	if(!isdefined(plinth) || !isdefined(plinth.origin))
		return;

	dist_sq = distancesquared(self.origin, plinth.origin);

	if(dist_sq > 62500)
	{
		if(!self hasgoal("crystal_plinth") || distancesquared(self getgoal("crystal_plinth"), plinth.origin) > 2500)
		{
			self cancelgoal("crystal_plinth");
			self addgoal(plinth.origin, 80, 2, "crystal_plinth");
		}

		return;
	}

	self cancelgoal("crystal_plinth");

	self thread bot_tomb_crystal_do_look_at_plinth(plinth, info);
}

bot_tomb_crystal_do_look_at_plinth(plinth, info)
{
	self endon("disconnect");
	level endon("end_game");

	self.bot_tomb_is_crystal_questing = true;

	self thread bot_tomb_crystal_cleanup_watcher(undefined);

	self allowattack(0);
	self pressads(0);

	if(self getgoal("wander") || self hasgoal("wander"))
		self cancelgoal("wander");

	timeout = gettime() + 8000;

	while(gettime() < timeout)
	{
		if(!isdefined(self) || !isalive(self))
			break;

		if(bot_tomb_crystal_piece_exists(info.craftable_name))
			break;

		if(!isdefined(plinth) || !isdefined(plinth.origin))
			break;

		if(self maps\mp\zombies\_zm_laststand::player_is_in_laststand())
			break;

		if(distancesquared(self.origin, plinth.origin) > 62500)
			break;

		self lookat(plinth.origin);

		wait 0.1;
	}

	if(isdefined(self) && isalive(self))
		self clearlookat();

	self notify("tomb_crystal_attempt_done");
}

bot_tomb_crystal_find_stub_at(target_origin)
{
	if(!isdefined(level._unitriggers) || !isdefined(level._unitriggers.dynamic_stubs))
		return undefined;

	foreach(stub in level._unitriggers.dynamic_stubs)
	{
		if(!isdefined(stub) || stub.script_unitrigger_type != "unitrigger_radius_use")
			continue;

		if(distancesquared(stub.origin, target_origin) < 4)
			return stub;
	}

	return undefined;
}

bot_tomb_crystal_get_lookat_point(pos)
{
	eye_z = self.origin[2] + 45;

	return (pos[0], pos[1], eye_z);
}

bot_tomb_crystal_cleanup_watcher(claimable)
{
	self waittill_any("tomb_crystal_attempt_done", "death", "disconnect");

	if(isdefined(claimable) && isdefined(claimable.tomb_bot_claimer) && claimable.tomb_bot_claimer == self)
		claimable.tomb_bot_claimer = undefined;

	self.bot_tomb_is_crystal_questing = false;
}
