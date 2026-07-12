
#include common_scripts\utility;
#include maps\mp\_utility;
#include maps\mp\zombies\_zm_utility;
#include maps\mp\zombies\_zm_laststand;

#include scripts\zm\zm_bo2_bots;

main()
{
	if(getdvar("mapname") != "zm_tomb")
		return;

	level thread zm_tomb_bot_dig_coordinator();
}

zm_tomb_bot_dig_coordinator()
{
	level endon("end_game");

	for(;;)
	{
		foreach(player in get_players())
		{
			if(!isdefined(player.pers["isbot"]))
				continue;

			if(isdefined(player.bot_tomb_dig_coordinated))
				continue;

			player.bot_tomb_dig_coordinated = true;

			player thread bot_tomb_dig_watch_respawn();
		}

		wait 1;
	}
}

bot_tomb_dig_watch_respawn()
{
	self endon("disconnect");

	level endon("end_game");

	for(;;)
	{
		if(isalive(self))
			self thread bot_tomb_dig_think();

		self waittill("spawned_player");
	}
}

bot_tomb_dig_think()
{
	self endon("disconnect");
	self endon("death");

	level endon("end_game");

	if(!isdefined(self.dig_vars))
		self.dig_vars = [];

	for(;;)
	{
		self bot_tomb_dig_update();

		wait 0.5;
	}
}

bot_tomb_dig_update()
{
	if(self maps\mp\zombies\_zm_laststand::player_is_in_laststand())
		return;

	if(is_true(self.bot.is_using_box) || is_true(self.bot.is_reviving) || is_true(self.bot.is_selfreviving) || is_true(self.bot.is_throwing_grenade))
		return;

	if(is_true(self.bot.is_panicking))
		return;

	if(isdefined(level.bot_train_leader) && level.bot_train_leader == self)
		return;

	if(is_true(self.bot_tomb_is_digging))
		return;

	if(!is_true(self.dig_vars["has_shovel"]))
	{
		self bot_tomb_pursue_shovel();

		return;
	}

	self bot_tomb_pursue_dig_spot();
}

bot_tomb_pursue_shovel()
{
	stubs = bot_tomb_get_cached_shovel_stubs();

	if(!isdefined(stubs) || !stubs.size)
	{
		if(self hasgoal("dig_shovel"))
			self cancelgoal("dig_shovel");
		return;
	}

	closest = undefined;
	closest_dist_sq = 999999999;

	foreach(stub in stubs)
	{
		if(!isdefined(stub) || !isdefined(stub.e_shovel) || !isdefined(stub.e_shovel.origin))
			continue;
		if(isdefined(stub.tomb_bot_claimer) && stub.tomb_bot_claimer != self && isalive(stub.tomb_bot_claimer))
			continue;

		d = distancesquared(self.origin, stub.e_shovel.origin);
		if(d < closest_dist_sq)
		{
			closest_dist_sq = d;
			closest = stub;
		}
	}

	if(!isdefined(closest))
		return;

	ground_origin = closest.e_shovel.origin;

	if(!findpath(self.origin, ground_origin, undefined, 0, 1))
		return;

	if(closest_dist_sq > 20000)
	{
		closest.tomb_bot_claimer = self;

		if(!self hasgoal("dig_shovel") || distancesquared(self getgoal("dig_shovel"), ground_origin) > 900)
		{
			self cancelgoal("dig_shovel");
			self addgoal(ground_origin, 40, 2, "dig_shovel");
		}
		return;
	}

	self cancelgoal("dig_shovel");
	self thread bot_tomb_do_interact_shovel(closest);
}

bot_tomb_get_cached_shovel_stubs()
{
	if(!isdefined(level.tomb_bot_shovel_cache_time) || gettime() - level.tomb_bot_shovel_cache_time > 2000)
	{
		level.tomb_bot_shovel_cache_time = gettime();
		level.tomb_bot_shovel_cache = bot_tomb_scan_shovel_stubs();
	}

	return level.tomb_bot_shovel_cache;
}

bot_tomb_scan_shovel_stubs()
{
	found = [];

	if(isdefined(level.zones))
	{
		zone_keys = getarraykeys(level.zones);

		foreach(zkey in zone_keys)
		{
			zone = level.zones[zkey];

			if(!isdefined(zone.unitrigger_stubs))
				continue;

			foreach(stub in zone.unitrigger_stubs)
			{
				if(isdefined(stub) && isdefined(stub.e_shovel))
					found[found.size] = stub;
			}
		}
	}

	if(isdefined(level._unitriggers) && isdefined(level._unitriggers.dynamic_stubs))
	{
		foreach(stub in level._unitriggers.dynamic_stubs)
		{
			if(isdefined(stub) && isdefined(stub.e_shovel))
				found[found.size] = stub;
		}
	}

	return found;
}

bot_tomb_pursue_dig_spot()
{
	if(!isdefined(level.a_dig_spots))
		return;

	closest = undefined;
	closest_dist_sq = 4000000;

	foreach(spot in level.a_dig_spots)
	{
		if(!isdefined(spot) || !isdefined(spot.origin) || !isdefined(spot.m_dig))
			continue;

		if(isdefined(spot.dug) && spot.dug)
			continue;

		if(isdefined(spot.tomb_bot_claimer) && spot.tomb_bot_claimer != self && isalive(spot.tomb_bot_claimer))
			continue;

		d = distancesquared(self.origin, spot.origin);

		if(d < closest_dist_sq)
		{
			closest_dist_sq = d;
			closest = spot;
		}
	}

	if(!isdefined(closest))
	{
		if(self hasgoal("dig_spot"))
			self cancelgoal("dig_spot");

		return;
	}

	if(!findpath(self.origin, closest.origin, undefined, 0, 1))
		return;

	dist_sq = distancesquared(self.origin, closest.origin);

	if(dist_sq > 10000)
	{
		closest.tomb_bot_claimer = self;

		if(!self hasgoal("dig_spot") || distancesquared(self getgoal("dig_spot"), closest.origin) > 2500)
		{
			self cancelgoal("dig_spot");
			self addgoal(closest.origin, 60, 1, "dig_spot");
		}

		return;
	}

	self cancelgoal("dig_spot");

	self thread bot_tomb_do_interact_dig_spot(closest);
}

bot_tomb_find_dig_spot_stub(spot)
{
	if(!isdefined(level._unitriggers) || !isdefined(level._unitriggers.dynamic_stubs))
		return undefined;

	target_origin = spot.origin + (0, 0, 20);

	foreach(stub in level._unitriggers.dynamic_stubs)
	{
		if(!isdefined(stub) || stub.script_unitrigger_type != "unitrigger_radius_use")
			continue;

		if(distancesquared(stub.origin, target_origin) < 4)
			return stub;
	}

	return undefined;
}

bot_tomb_get_lookat_point(pos)
{
	eye_z = self.origin[2] + 45;

	return (pos[0], pos[1], eye_z);
}

bot_tomb_do_interact_shovel(stub)
{
    self endon("disconnect");
    self endon("death");
    level endon("end_game");

    self.bot_tomb_is_digging = true;

    self allowattack(0);
    self pressads(0);

    if(self getgoal("wander") || self hasgoal("wander"))
        self cancelgoal("wander");

    look_point = self bot_tomb_get_lookat_point(stub.e_shovel.origin);
    windup_end = gettime() + 500;

    while(gettime() < windup_end)
    {
        if(!isdefined(stub) || !isdefined(stub.e_shovel))
            break;
        if(self maps\mp\zombies\_zm_laststand::player_is_in_laststand())
            break;

        self lookat(look_point);
        wait 0.05;
    }

    self clearlookat();

    if(isdefined(stub) && isdefined(stub.e_shovel) && !is_true(self.dig_vars["has_shovel"])
        && !self maps\mp\zombies\_zm_laststand::player_is_in_laststand())
    {
        self.dig_vars["has_shovel"] = 1;
        self playsound("zmb_craftable_pickup");
        self maps\mp\zm_tomb_dig::dig_reward_dialog("pickup_shovel");

        n_player = self getentitynumber() + 1;
        level setclientfield("shovel_player" + n_player, 1);
        self thread maps\mp\zm_tomb_dig::dig_disconnect_watch(n_player, stub.e_shovel.origin, stub.e_shovel.angles);

        stub.e_shovel delete();
        stub.e_shovel = undefined;
        maps\mp\zombies\_zm_unitrigger::unregister_unitrigger(stub);
    }

    if(isdefined(stub) && isdefined(stub.tomb_bot_claimer) && stub.tomb_bot_claimer == self)
        stub.tomb_bot_claimer = undefined;

    self.bot_tomb_is_digging = false;
}

bot_tomb_do_interact_dig_spot(target)
{
	self endon("disconnect");
	self endon("death");
	level endon("end_game");

	self.bot_tomb_is_digging = true;

	self allowattack(0);
	self pressads(0);

	if(self getgoal("wander") || self hasgoal("wander"))
		self cancelgoal("wander");

	stub = bot_tomb_find_dig_spot_stub(target);

	timeout = gettime() + 4000;

	while(gettime() < timeout)
	{
		if(!isdefined(target) || !isdefined(target.m_dig) || (isdefined(target.dug) && target.dug))
			break;

		if(self maps\mp\zombies\_zm_laststand::player_is_in_laststand())
			break;

		trigger_check_origin = target.origin + (0, 0, 20);

		if(distancesquared(self.origin, trigger_check_origin) > 22500)
			break;

		self lookat(self bot_tomb_get_lookat_point(target.origin));

		if(!isdefined(stub))
			stub = bot_tomb_find_dig_spot_stub(target);

		if(isdefined(stub))
			stub notify("trigger", self);
		else
			self usebuttonpressed();

		wait 0.05;
	}

	self clearlookat();

	if(isdefined(target) && isdefined(target.tomb_bot_claimer) && target.tomb_bot_claimer == self)
		target.tomb_bot_claimer = undefined;

	self.bot_tomb_is_digging = false;
}