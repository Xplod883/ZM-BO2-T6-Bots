
#include common_scripts\utility;
#include maps\mp\_utility;
#include maps\mp\zombies\_zm_utility;
#include maps\mp\zombies\_zm_laststand;

#include scripts\zm\zm_bo2_bots;

main()
{
	if(getdvar("mapname") != "zm_tomb")
		return;

	level thread zm_tomb_bot_air_coordinator();

	scripts\zm\zm_bo2_bots::bot_tomb_register_objective_provider(::bot_tomb_explore_objective_air, 10);
}

bot_tomb_explore_objective_air()
{
	if(!self hasweapon("staff_air_zm"))
		return undefined;

	closest = undefined;
	closest_dist_sq = 999999999;

	if(!flag("air_puzzle_1_complete"))
	{
		if(!isdefined(level.a_ceiling_rings))
			return undefined;

		foreach(ring in level.a_ceiling_rings)
		{
			if(!isdefined(ring) || !isdefined(ring.origin) || !isdefined(ring.position) || !isdefined(ring.script_int))
				continue;

			if(ring.position == ring.script_int)
				continue;

			d = distancesquared(self.origin, ring.origin);

			if(d < closest_dist_sq)
			{
				closest_dist_sq = d;
				closest = ring.origin;
			}
		}

		return closest;
	}

	if(!flag("air_puzzle_2_complete"))
	{
		smoke_positions = getstructarray("puzzle_smoke_origin", "targetname");

		if(!isdefined(smoke_positions))
			return undefined;

		foreach(smoke in smoke_positions)
		{
			if(!isdefined(smoke) || !isdefined(smoke.origin) || !isdefined(smoke.detector_brush))
				continue;

			if(is_true(smoke.solved))
				continue;

			d = distancesquared(self.origin, smoke.origin);

			if(d < closest_dist_sq)
			{
				closest_dist_sq = d;
				closest = smoke.origin;
			}
		}

		return closest;
	}

	return undefined;
}

zm_tomb_bot_air_coordinator()
{
	level endon("end_game");

	for(;;)
	{
		foreach(player in get_players())
		{
			if(!isdefined(player.pers["isbot"]))
				continue;

			if(isdefined(player.bot_tomb_air_coordinated))
				continue;

			player.bot_tomb_air_coordinated = true;

			player thread bot_tomb_air_watch_respawn();
		}

		wait 1;
	}
}

bot_tomb_air_watch_respawn()
{
	self endon("disconnect");

	level endon("end_game");

	for(;;)
	{
		if(isalive(self))
			self thread bot_tomb_air_think();

		self waittill("spawned_player");
	}
}

bot_tomb_air_think()
{
	self endon("disconnect");
	self endon("death");

	level endon("end_game");

	for(;;)
	{
		self bot_tomb_air_update();

		wait 0.5;
	}
}

bot_tomb_air_update()
{
	if(self maps\mp\zombies\_zm_laststand::player_is_in_laststand())
		return;

	if(is_true(self.bot.is_using_box) || is_true(self.bot.is_buying) || is_true(self.bot.is_reviving) || is_true(self.bot.is_selfreviving) || is_true(self.bot.is_throwing_grenade))
		return;

	if(is_true(self.bot.is_panicking))
		return;

	if(isdefined(level.bot_train_leader) && level.bot_train_leader == self)
		return;

	if(is_true(self.bot_tomb_is_digging) || is_true(self.bot_tomb_is_crafting) || is_true(self.bot_tomb_is_capturing))
		return;

	if(is_true(self.bot_tomb_is_air_questing))
		return;

	if(!self hasweapon("staff_air_zm"))
		return;

	if(!flag("air_puzzle_1_complete"))
	{
		self bot_tomb_pursue_ring_puzzle();
		return;
	}

	if(!flag("air_puzzle_2_complete"))
	{
		self bot_tomb_pursue_smoke_puzzle();
		return;
	}
}

bot_tomb_air_area_clear()
{
	return self bot_count_nearby_zombies(500) == 0;
}

bot_tomb_pursue_ring_puzzle()
{
	if(!isdefined(level.a_ceiling_rings))
		return;

	closest = undefined;
	closest_dist_sq = 999999999;

	foreach(ring in level.a_ceiling_rings)
	{
		if(!isdefined(ring) || !isdefined(ring.origin) || !isdefined(ring.position) || !isdefined(ring.script_int))
			continue;

		if(ring.position == ring.script_int)
			continue;

		if(isdefined(ring.tomb_bot_claimer) && ring.tomb_bot_claimer != self && isalive(ring.tomb_bot_claimer))
			continue;

		d = distancesquared(self.origin, ring.origin);

		if(d < closest_dist_sq)
		{
			closest_dist_sq = d;
			closest = ring;
		}
	}

	if(!isdefined(closest))
		return;

	ground_target = (closest.origin[0], closest.origin[1], self.origin[2]);

	if(!findpath(self.origin, ground_target, undefined, 0, 1))
		return;

	dist_sq = distancesquared(self.origin, closest.origin);

	if(dist_sq > 250000)
	{
		closest.tomb_bot_claimer = self;

		if(!self hasgoal("air_ring") || distancesquared(self getgoal("air_ring"), ground_target) > 4900)
		{
			self cancelgoal("air_ring");
			self addgoal(ground_target, 80, 2, "air_ring");
		}

		return;
	}

	self cancelgoal("air_ring");

	self thread bot_tomb_do_shoot_ring(closest);
}

bot_tomb_do_shoot_ring(ring)
{
	self endon("disconnect");
	level endon("end_game");

	self.bot_tomb_is_air_questing = true;

	self thread bot_tomb_air_cleanup_watcher(ring);

	if(self getgoal("wander") || self hasgoal("wander"))
		self cancelgoal("wander");

	attempt_end = gettime() + 6000;

	while(gettime() < attempt_end)
	{
		if(!isdefined(self) || !isalive(self))
			break;

		if(!isdefined(ring) || !isdefined(ring.origin) || !isdefined(ring.position) || !isdefined(ring.script_int))
			break;

		if(ring.position == ring.script_int)
			break;

		if(self maps\mp\zombies\_zm_laststand::player_is_in_laststand())
			break;

		if(distancesquared(self.origin, ring.origin) > 250000)
			break;

		if(!self bot_tomb_air_area_clear())
		{
			wait 0.3;
			continue;
		}

		if(self getcurrentweapon() != "staff_air_zm")
		{
			self switchtoweapon("staff_air_zm");
			wait 0.2;
			continue;
		}

		self lookat(ring.origin);

		if(!self botsighttracepassed(ring))
		{
			wait 0.1;
			continue;
		}

		self allowattack(1);
		wait 0.1;
		self allowattack(0);

		wait 0.3;
	}

	if(isdefined(self) && isalive(self))
	{
		self allowattack(0);
		self clearlookat();
	}

	self notify("tomb_air_attempt_done");
}

bot_tomb_pursue_smoke_puzzle()
{
	smoke_positions = getstructarray("puzzle_smoke_origin", "targetname");

	if(!isdefined(smoke_positions) || !smoke_positions.size)
		return;

	closest = undefined;
	closest_dist_sq = 999999999;

	foreach(smoke in smoke_positions)
	{
		if(!isdefined(smoke) || !isdefined(smoke.origin) || !isdefined(smoke.detector_brush))
			continue;

		if(is_true(smoke.solved))
			continue;

		if(isdefined(smoke.tomb_bot_claimer) && smoke.tomb_bot_claimer != self && isalive(smoke.tomb_bot_claimer))
			continue;

		d = distancesquared(self.origin, smoke.origin);

		if(d < closest_dist_sq)
		{
			closest_dist_sq = d;
			closest = smoke;
		}
	}

	if(!isdefined(closest))
		return;

	if(!findpath(self.origin, closest.origin, undefined, 0, 1))
		return;

	dist_sq = distancesquared(self.origin, closest.origin);

	if(dist_sq > 4900)
	{
		closest.tomb_bot_claimer = self;

		if(!self hasgoal("air_smoke") || distancesquared(self getgoal("air_smoke"), closest.origin) > 900)
		{
			self cancelgoal("air_smoke");
			self addgoal(closest.origin, 30, 2, "air_smoke");
		}

		return;
	}

	self cancelgoal("air_smoke");

	self thread bot_tomb_do_shoot_smoke(closest);
}

bot_tomb_do_shoot_smoke(smoke)
{
	self endon("disconnect");
	level endon("end_game");

	self.bot_tomb_is_air_questing = true;

	self thread bot_tomb_air_cleanup_watcher(smoke);

	if(self getgoal("wander") || self hasgoal("wander"))
		self cancelgoal("wander");

	s_dest = getstruct("puzzle_smoke_dest", "targetname");

	if(!isdefined(s_dest) || !isdefined(s_dest.origin))
	{
		self notify("tomb_air_attempt_done");
		return;
	}

	v_to_dest = vectornormalize(s_dest.origin - smoke.origin);

	attempt_end = gettime() + 6000;

	while(gettime() < attempt_end)
	{
		if(!isdefined(self) || !isalive(self))
			break;

		if(!isdefined(smoke) || is_true(smoke.solved))
			break;

		if(self maps\mp\zombies\_zm_laststand::player_is_in_laststand())
			break;

		if(distancesquared(self.origin, smoke.origin) > 4900)
			break;

		if(!self bot_tomb_air_area_clear())
		{
			wait 0.3;
			continue;
		}

		if(self getcurrentweapon() != "staff_air_zm")
		{
			self switchtoweapon("staff_air_zm");
			wait 0.2;
			continue;
		}

		aim_point = self.origin + vectorscale(v_to_dest, 2000);

		self lookat(aim_point);

		self allowattack(1);
		wait 0.15;
		self allowattack(0);

		wait 0.3;
	}

	if(isdefined(self) && isalive(self))
	{
		self allowattack(0);
		self clearlookat();
	}

	self notify("tomb_air_attempt_done");
}

bot_tomb_air_cleanup_watcher(claimable)
{
	self waittill_any("tomb_air_attempt_done", "death", "disconnect");

	if(isdefined(claimable) && isdefined(claimable.tomb_bot_claimer) && claimable.tomb_bot_claimer == self)
		claimable.tomb_bot_claimer = undefined;

	self.bot_tomb_is_air_questing = false;
}
