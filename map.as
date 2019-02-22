

// z is frame
HUDSpriteParams getIconForEnt(PlayerState@ state, CBaseEntity@ ent)
{
	HUDSpriteParams params;
	params.flags = HUD_SPR_MASKED | HUD_ELEM_ABSOLUTE_X | HUD_ELEM_ABSOLUTE_Y | HUD_ELEM_SCR_CENTER_X | HUD_ELEM_SCR_CENTER_Y;
	params.spritename = "sprites/rust/map_plr.spr".SubString("sprites/".Length());
	params.holdTime = 99999.0f;
	params.color1 = RGBA( 255, 255, 255, 255 );
	
	int size = state.map_size + (state.map_mode == 2 ? 1 : 0);
	float scale = 1 / float(2**size);
	
	float angle = ent.pev.angles.y + 180 + 90;
	if (angle >= 360)
		angle -= 360;
	if (angle < 0)
		angle += 360;
	angle = (angle / 360.0f) * 8.0f - 0.5f;
	if (angle < 0)
		angle += 8;
	
	// old value was 31744 scaled to 475/512
	float MAP_SIZE = g_map_size;
	
	float orix = Math.max(-MAP_SIZE, Math.min(ent.pev.origin.x, MAP_SIZE));
	float oriy = Math.max(-MAP_SIZE, Math.min(ent.pev.origin.y, MAP_SIZE));
	
	float mx = (orix / MAP_SIZE)*512.0f*scale + 0.5f;
	float my = (-oriy / MAP_SIZE)*512.0f*scale + 0.5f;
	if (state.map_mode == 2)
	{
		params.flags = HUD_SPR_MASKED | HUD_ELEM_ABSOLUTE_X | HUD_ELEM_ABSOLUTE_Y;
		mx -= 256 / Math.max(1, state.map_size*2);
		my += 256 / Math.max(1, state.map_size*2);
		size -= 1;
		
		int sprMiddleOffset = size > 0 ? 6 : 14;
		mx += sprMiddleOffset;
		my -= sprMiddleOffset;
	}
	if (size > 1)
		size = 1;
	
	int frame = (7 - int(angle)) + size*8;
	
	if (state.map_mode == 2) {
		// don't let the icon wrap around the screen
		if (mx >= 0)
			mx = -0.01;
		if (my < 0)
			my = 0;
		if (mx < -960.0f*scale)
			mx = -960.0f*scale;
		if (my > 960.0f*scale)
			my = 960.0f*scale;
	}
	
	params.x = mx;
	params.y = my;
	params.frame = frame;
	
	return params;
}

void drawMap(PlayerState@ state)
{
	CBasePlayer@ plr = cast<CBasePlayer@>(state.plr.GetEntity());
	
	HUDSpriteParams params;
	params.spritename = "rust/" + g_Engine.mapname + ".spr";
	//params.flags = HUD_SPR_OPAQUE | HUD_ELEM_ABSOLUTE_X | HUD_ELEM_ABSOLUTE_Y;
	params.flags = HUD_SPR_OPAQUE | HUD_ELEM_ABSOLUTE_X | HUD_ELEM_ABSOLUTE_Y | HUD_ELEM_SCR_CENTER_X | HUD_ELEM_SCR_CENTER_Y;
	params.holdTime = 99999.0f;
	params.color1 = RGBA( 255, 255, 255, 255 );
	
	params.channel = 0;
	params.frame = 0;
	params.x = 0;
	params.y = 0;
	
	if (state.map_update)
	{
		state.map_update = false;
		if (!state.map_enabled)
		{
			for (uint i = 0; i < 16; i++)
				g_PlayerFuncs.HudToggleElement(plr, i, false);
		}
		else if (state.map_mode == 1)
		{
			params.flags = HUD_SPR_OPAQUE | HUD_ELEM_ABSOLUTE_X | HUD_ELEM_ABSOLUTE_Y | HUD_ELEM_SCR_CENTER_X | HUD_ELEM_SCR_CENTER_Y;
			if (state.map_size == 0)
			{
				params.channel = 0;
				params.frame = 0;
				params.x = -256;
				params.y = -256;
				g_PlayerFuncs.HudCustomSprite(plr, params);
				
				params.channel = 1;
				params.frame = 1;
				params.x = 256;
				params.y = -256;
				g_PlayerFuncs.HudCustomSprite(plr, params);
				
				params.channel = 2;
				params.frame = 2;
				params.x = -256;
				params.y = 256;
				g_PlayerFuncs.HudCustomSprite(plr, params);
				
				params.channel = 3;
				params.frame = 3;
				params.x = 256;
				params.y = 256;
				g_PlayerFuncs.HudCustomSprite(plr, params);
			}
			else
			{
				params.frame = 3+state.map_size;
				g_PlayerFuncs.HudCustomSprite(plr, params);
				g_PlayerFuncs.HudToggleElement(plr, 1, false);
				g_PlayerFuncs.HudToggleElement(plr, 2, false);
				g_PlayerFuncs.HudToggleElement(plr, 3, false);
			}
		}
		else if (state.map_mode == 2)
		{
			params.x = -1;
			params.frame = 4+state.map_size;
			params.flags = HUD_SPR_OPAQUE | HUD_ELEM_ABSOLUTE_X | HUD_ELEM_ABSOLUTE_Y;
			
			g_PlayerFuncs.HudCustomSprite(plr, params);
			g_PlayerFuncs.HudToggleElement(plr, 1, false);
			g_PlayerFuncs.HudToggleElement(plr, 2, false);
			g_PlayerFuncs.HudToggleElement(plr, 3, false);
		}
	}
	
	// draw player cursor
	if (state.map_enabled)
	{		
		int channel = 4;
		HUDSpriteParams icon = getIconForEnt(state, plr);
		icon.channel = channel++;
		g_PlayerFuncs.HudCustomSprite(plr, icon);
		
		if (g_invasion_mode)
		{
			CBaseEntity@ enemy = null;
			do {
				@enemy = g_EntityFuncs.FindEntityByTargetname(enemy, "node_xen");
				
				if (enemy !is null and enemy.IsAlive())
				{
					icon = getIconForEnt(state, enemy);
					icon.channel = channel++;
					icon.color1 = RGBA( 255, 64, 64, 255 );
					g_PlayerFuncs.HudCustomSprite(plr, icon);
					if (channel > 14)
						break;
				}
			} while(enemy !is null);
		}
		CBaseEntity@ enemy = null;
		do {
			@enemy = g_EntityFuncs.FindEntityByClassname(enemy, "monster_apache");
			
			if (enemy !is null)
			{
				icon = getIconForEnt(state, enemy);
				icon.channel = channel++;
				icon.color1 = RGBA( 255, 64, 64, 255 );
				g_PlayerFuncs.HudCustomSprite(plr, icon);
				if (channel > 14)
					break;
			}
		} while(enemy !is null);
		
		int numIcons = channel;
		while (channel < state.lastMapIcons)
			g_PlayerFuncs.HudToggleElement(plr, channel++, false);
		state.lastMapIcons = numIcons;
	}
	
	
	
	//g_PlayerFuncs.HudToggleElement(plr, tile, false);
}
