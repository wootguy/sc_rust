
DayNightCycle day_night_cycle;
float g_brightness;

void day_night_think()
{
	day_night_cycle.Think();
}

class DayNightCycle {

	EHandle h_sun, h_sun_dusk, h_moon;
	EHandle h_skybox_day, h_skybox_dusk, h_skybox_moon;
	EHandle h_light_env;
	int state = 0;
	
	// a is pitch black
	string light_levels = "abcdefghijklmnopqrstuvwxyz";

	DayNightCycle() {
	
	}
	
	DayNightCycle(string sun_tname, string sun_dusk_tname, string moon_tname, 
				  string skybox_day_tname, string skybox_dusk_tname, string skybox_moon_tname)
	{
		h_sun = g_EntityFuncs.FindEntityByTargetname(null, sun_tname);
		h_sun_dusk = g_EntityFuncs.FindEntityByTargetname(null, sun_dusk_tname);
		h_moon = g_EntityFuncs.FindEntityByTargetname(null, moon_tname);
		
		h_skybox_day = g_EntityFuncs.FindEntityByTargetname(null, skybox_day_tname);
		h_skybox_dusk = g_EntityFuncs.FindEntityByTargetname(null, skybox_dusk_tname);
		h_skybox_moon = g_EntityFuncs.FindEntityByTargetname(null, skybox_moon_tname);
		h_light_env = g_EntityFuncs.FindEntityByTargetname(null, "light_day");
	}
	
	void test()
	{
		CBaseEntity@ sun = h_sun;
		CBaseEntity@ sun_dusk = h_sun_dusk;
		CBaseEntity@ moon = h_moon;
		
		sun.pev.angles.z = sun_dusk.pev.angles.z = moon.pev.angles.z = -43;
	}
	
	void test2()
	{
		CBaseEntity@ sun = h_sun;
		CBaseEntity@ sun_dusk = h_sun_dusk;
		CBaseEntity@ moon = h_moon;
		
		sun.pev.angles.z = sun_dusk.pev.angles.z = moon.pev.angles.z = -180 - 43;
	}
	
	void start()
	{
		CBaseEntity@ sun = h_sun;
		CBaseEntity@ sun_dusk = h_sun_dusk;
		CBaseEntity@ moon = h_moon;
		
		if (sun is null or moon is null)
			return;
		
		sun.pev.movetype = sun_dusk.pev.movetype = moon.pev.movetype = MOVETYPE_NOCLIP;
		
		sun.pev.angles.z = sun_dusk.pev.angles.z = moon.pev.angles.z = 45;
		sun.pev.avelocity.z = sun_dusk.pev.avelocity.z = moon.pev.avelocity.z = -1;
		
		moon.pev.renderamt = 255;
		
		g_Scheduler.SetInterval("day_night_think", 0.0);
		
		g_EntityFuncs.FireTargets("light_dusk", null, null, USE_OFF);
		g_EntityFuncs.FireTargets("light_night", null, null, USE_OFF);
		g_EntityFuncs.FireTargets("light_dusk_bright", null, null, USE_OFF);
		g_EntityFuncs.FireTargets("light_dusk_dim", null, null, USE_OFF);
		//g_EntityFuncs.FireTargets("light_day", null, null, USE_OFF);
		
		println("Day Night Cycle started");
	}
	
	void pause()
	{
		CBaseEntity@ sun = h_sun;
		CBaseEntity@ sun_dusk = h_sun_dusk;
		CBaseEntity@ moon = h_moon;
		
		sun.pev.avelocity.z = sun_dusk.pev.avelocity.z = moon.pev.avelocity.z = 0;
	}
	
	void wrapAngle(CBaseEntity@ ent)
	{
		while (ent.pev.angles.z < -360) {
			ent.pev.angles.z += 360;
		}
	}
	
	void Think()
	{
		CBaseEntity@ sun = h_sun;
		CBaseEntity@ sun_dusk = h_sun_dusk;
		CBaseEntity@ moon = h_moon;
		
		CBaseEntity@ skybox_day = h_skybox_day;
		CBaseEntity@ skybox_dusk = h_skybox_dusk;
		CBaseEntity@ skybox_night = h_skybox_moon;
		
		CBaseEntity@ light_env = h_light_env;
		
		//sun.pev.effects = sun_dusk.pev.effects = moon.pev.effects = skybox_day.pev.effects = skybox_dusk.pev.effects = skybox_night.pev.effects =  EF_NODRAW;
		
		wrapAngle(sun);
		wrapAngle(sun_dusk);
		wrapAngle(moon);
		
		float sunAngle = -sun.pev.angles.z / 360.0f;
		
		float fade_time = 0.1f;
		
		float day_fadeout_end = 0.25f;
		float night_fadein_start = 0.25f;
		float night_fadeout_end = 0.75f;
		float day_fadein_start = 0.75f;
		
		if (sunAngle > day_fadeout_end - fade_time and sunAngle < day_fadeout_end)
		{
			skybox_day.pev.renderamt = ((day_fadeout_end - sunAngle) / fade_time)*255.0f;
			skybox_dusk.pev.renderamt = 255.0f - skybox_day.pev.renderamt;
		}
		
		if (sunAngle > night_fadein_start and sunAngle < night_fadein_start + fade_time)
		{
			skybox_night.pev.renderamt = 255.0f - (((night_fadein_start+fade_time) - sunAngle) / fade_time)*255.0f;
			skybox_dusk.pev.renderamt = 255.0f - skybox_night.pev.renderamt;
			skybox_night.pev.renderamt *= 0.5f;
		}
		
		if (sunAngle > night_fadeout_end - fade_time and sunAngle < night_fadeout_end)
		{
			skybox_night.pev.renderamt = ((night_fadeout_end - sunAngle) / fade_time)*255.0f;
			skybox_dusk.pev.renderamt = 255.0f - skybox_night.pev.renderamt;
			skybox_night.pev.renderamt *= 0.5f;
		}
		
		if (sunAngle > day_fadein_start and sunAngle < day_fadein_start + fade_time)
		{
			skybox_day.pev.renderamt = 255.0f - (((day_fadein_start+fade_time) - sunAngle) / fade_time)*255.0f;
			skybox_dusk.pev.renderamt = 255.0f - skybox_day.pev.renderamt;
		}
		
		if (sunAngle > night_fadein_start + fade_time and sunAngle < night_fadeout_end - fade_time)
		{
			skybox_day.pev.renderamt = skybox_dusk.pev.renderamt = 0;
			skybox_night.pev.renderamt = 128;
		}
		if (sunAngle < day_fadeout_end - fade_time or sunAngle > day_fadein_start + fade_time)
		{
			skybox_night.pev.renderamt = skybox_dusk.pev.renderamt = 0;
			skybox_day.pev.renderamt = 255;
		}
		
		skybox_day.pev.effects = skybox_day.pev.renderamt > 0 ? 0 : EF_NODRAW;
		skybox_dusk.pev.effects = skybox_dusk.pev.renderamt > 0 ? 0 : EF_NODRAW;
		skybox_night.pev.effects = skybox_night.pev.renderamt > 0 ? 0 : EF_NODRAW;
		
		g_brightness = ((skybox_day.pev.renderamt/255.0f)*2 + (skybox_dusk.pev.renderamt)/255.0f)*0.5f;
		if (g_brightness > 1.0f)
			g_brightness = 1.0f;
		
		float bright = 0;
		Vector color;
		if (g_brightness > 0.7f)
		{
			g_EntityFuncs.FireTargets("light_dusk", null, null, USE_OFF);
			g_EntityFuncs.FireTargets("light_night", null, null, USE_OFF);
			g_EntityFuncs.FireTargets("light_day", null, null, USE_ON);
			color = Vector(255, 255, 250);
			bright = ((g_brightness-0.7f)/0.3f)*0.95f + 0.05f;
		}
		else if (g_brightness > 0.4f)
		{
			g_EntityFuncs.FireTargets("light_dusk", null, null, USE_ON);
			g_EntityFuncs.FireTargets("light_night", null, null, USE_OFF);
			g_EntityFuncs.FireTargets("light_day", null, null, USE_OFF);
			color = Vector(255, 160, 32);
			bright = ((g_brightness-0.4f)/0.3f)*0.95f + 0.05f;
		}
		else
		{
			g_EntityFuncs.FireTargets("light_dusk", null, null, USE_OFF);
			g_EntityFuncs.FireTargets("light_night", null, null, USE_ON);
			g_EntityFuncs.FireTargets("light_day", null, null, USE_OFF);
			color = Vector(64, 107, 255);
			bright = Math.max(0.35f, (g_brightness/0.4f)*1.0f);
		}
		
		color = color*(g_brightness*0.94f + 0.06f);
		light_env.KeyValue("_light", color.ToString()); // This updates the sv_skylight_* cvars (can't do this in map scripts directly)
		
		int styleidx = int(bright * (light_levels.Length()-1) + 0.5f);
		g_EngineFuncs.LightStyle(0, string(light_levels[styleidx]));
		
		CBaseEntity@ ent = null;
		do {
			@ent = g_EntityFuncs.FindEntityByTargetname(ent, "wawa");
			if (ent !is null)
			{
				ent.pev.renderamt = 24 + g_brightness*96;
			}
		} while (ent !is null);
		
		
		//println("thinking " + sunAngle + " " + g_brightness + " " + light_levels[styleidx]);
	}
}