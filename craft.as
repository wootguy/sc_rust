
// max menu dimensions: 5x3
array<array<array<int>>> craftMenus = {
	// items menu
	{
		{I_WOOD_DOOR, I_METAL_DOOR, I_WOOD_BARS, I_METAL_BARS, I_WOOD_SHUTTERS}, 
		{I_HIGH_WOOD_WALL, I_HIGH_STONE_WALL, I_LADDER, I_LADDER_HATCH, I_FURNACE}, 
		{I_SMALL_CHEST, I_LARGE_CHEST, I_TOOL_CUPBOARD, I_CODE_LOCK, I_BED}
	},
	
	// tools menu
	{
		{I_ROCK, I_BUILDING_PLAN, I_HAMMER},
		{I_STONE_HATCHET, I_STONE_PICKAXE, I_METAL_HATCHET, I_METAL_PICKAXE}
	},
	
	// util menu
	{
		{I_GUITAR, I_SYRINGE, I_ARMOR},
		{I_FIRE, I_BOAT_WOOD, I_BOAT_METAL}
	},
	
	// weapons menu
	{
		{I_CROWBAR, I_BOW},
		{I_DEAGLE, I_UZI, I_SHOTGUN, I_SNIPER, I_SAW},
		{I_FLAMETHROWER, I_RPG, I_GRENADE, I_SATCHEL, I_C4}
	},
	
	// ammo menu
	{
		{I_ARROW, I_ROCKET},
		{I_9MM, I_BUCKSHOT, I_556}
	}
};

// spawn a camera so the player can use their mouse to select things on the HUD
void enterMenuMode(PlayerState@ state)
{
	CBasePlayer@ plr = cast<CBasePlayer@>(state.plr.GetEntity());
	
	dictionary keys;
	keys["origin"] = (plr.pev.origin + plr.pev.view_ofs).ToString();
	keys["angles"] = plr.pev.v_angle.ToString();
	keys["spawnflags"] = "640";
	keys["m_iszASMouseEventCallbackName"] = "menuMouseCallback";
	keys["hud_health"] = "1";
	keys["hud_flashlight"] = "1";
	CBaseEntity@ cam = g_EntityFuncs.CreateEntity("trigger_camera", keys, true);
	
	if (state.menuCam) {
		g_EntityFuncs.Remove(state.menuCam);
	}
	
	cam.Use(plr, plr, USE_ON);
	state.menuCam = cam;
	state.lastMenuHighlight = -1;
	
	clearHud(plr);
	g_PlayerFuncs.ScreenFade(plr, Vector(50, 48, 40), 0, 0, 240, FFADE_STAYOUT);
	
	HUDTextParams textParams;
	textParams.x = -1;
	textParams.y = 0;
	textParams.r1 = 255;
	textParams.g1 = 255;
	textParams.b1 = 255;
	textParams.fadeinTime = 0;
	textParams.fadeoutTime = 0.0f;
	textParams.holdTime = 5.0f;
	textParams.channel = 4;
	g_PlayerFuncs.HudMessage(plr, textParams, "Left Click = Craft\nRight Click = Exit Menu");
}

// returns currently selected item id
int drawCraftingMenu(CBasePlayer@ plr, int submenu=-1, float screenX=0, float screenY=0, bool highlight=false, 
	bool forceRefresh=false)
{
	if (plr is null)
		return -1;
	
	PlayerState@ state = getPlayerState(plr);
	if (!state.menuCam.IsValid())
		return -1;
	
	if (submenu == -1)
		submenu = state.lastCraftSubmenu;
	if (submenu < 0 or submenu >= int(craftMenus.length()))
		submenu = 0;
	state.lastCraftSubmenu = submenu;
	
	HUDSpriteParams params;
	string makeResguyHappy = "menu"; // don't let it try to find the sprite. It will only FAIL (TODO: fix resguy)
	params.spritename = "rust/" + makeResguyHappy + ".spr";
	params.flags = HUD_SPR_MASKED | HUD_ELEM_SCR_CENTER_X | HUD_ELEM_SCR_CENTER_Y | HUD_ELEM_NO_BORDER;
	//params.flags = HUD_SPR_OPAQUE | HUD_ELEM_SCR_CENTER_X | HUD_ELEM_SCR_CENTER_Y | HUD_ELEM_NO_BORDER;
	params.holdTime = 99999.0f;
	params.color1 = RGBA( 255, 255, 255, 255 );
	
	array<HUDSpriteParams> icons;
	
	float gapScale = 1.0f/((state.gapScale+1)*0.5f + 0.5f);
	
	int gridWidth = 5;
	int gridHeight = craftMenus[submenu].length();
	float xgap = 0.15f*gapScale;
	float ygap = 0.26f*gapScale;
	float bestDelta = 9e99;
	float bestX = 0;
	float bestY = 0;
	int bestRow = 0;
	int bestCol = 0;
	int bestItemId = 0;
	int bestChannel = 0;
	int bestIcon = 0;
	RGBA bestColor;
	int channel = 0;
	int idx = 0;
	for (uint row = 0; row < craftMenus[submenu].length(); row++)
	{
		gridWidth = craftMenus[submenu][row].length();
		for (uint col = 0; col < craftMenus[submenu][row].length(); col++)
		{
			if (craftMenus[submenu][row][col] != -1)
			{
				int x = col;
				int y = row;
				params.channel = channel;
				params.frame = craftMenus[submenu][row][col] + state.menuScale*ITEM_TYPES;
				params.x = x*xgap + (-gridWidth*0.5f*xgap) + (xgap*0.5f);
				params.y = y*ygap + (-gridHeight*0.5f*ygap) + (ygap*0.5f);
				
				if (!g_free_build)
				{
					bool canCraft = true;
					Item@ craftItem = g_items[craftMenus[submenu][row][col]];
					for (uint i = 0; i < craftItem.costs.size(); i++)
					{
						int costType = craftItem.costs[i].type;
						int cost = craftItem.costs[i].amt;
						if (getItemCount(plr, costType, true, true) < cost)
						{
							canCraft = false;
							break;
						}
					}
					if (canCraft)
						params.color1 = RGBA( 255, 255, 255, 255 );
					else
						params.color1 = RGBA( 0, 0, 0, 255 );
				}
				
				float delta = (Vector(params.x, params.y, 0) - Vector(screenX*0.5f, screenY*-0.5f, 0)).Length();
				if (delta < bestDelta) {
					bestDelta = delta;
					bestRow = row;
					bestCol = col;
					bestIcon = idx;
					bestChannel = channel;
					bestItemId = craftMenus[submenu][row][col];
					bestColor = params.color1;
					bestX = params.x;
					bestY = params.y;
				}
				
				icons.insertLast(params);
				channel++;
			}
			idx++;
		}
	}
	
	if (!highlight or state.lastMenuHighlight != bestIcon or forceRefresh)
	{
		for (uint i = 0; i < icons.length(); i++)
		{
			g_PlayerFuncs.HudCustomSprite(plr, icons[i]);
		}
	}
	
	if (highlight and (state.lastMenuHighlight != bestIcon or forceRefresh))
	{
		params.x = bestX;
		params.y = bestY;		
		params.channel = bestChannel;
		params.frame = bestItemId + state.menuScale*ITEM_TYPES;
		params.color1 = bestColor;
		if (params.color1.r == 0)
			params.color2 = RGBA(64, 64, 64, 255);
		else
			params.color2 = RGBA(bestColor.r/2, bestColor.g/2, bestColor.b/2, 255);
		params.fxTime = 0.5f;
		params.effect = HUD_EFFECT_TRIANGLE;
		g_PlayerFuncs.HudCustomSprite(plr, params);
		
		state.lastMenuHighlight = bestIcon;
	}
	
	if (!highlight)
		state.lastMenuHighlight = -1;
	
	if (highlight and bestItemId >= 0 and bestItemId < ITEM_TYPES)
	{
		HUDTextParams textParams;
		textParams.x = -1;
		textParams.y = 0.95;
		
		//textParams.x = screenX*0.5f + 0.5f;
		//textParams.y = -screenY*0.5f + 0.5f;
		textParams.x = -1;
		textParams.y = 0;
		
		textParams.r1 = 255;
		textParams.g1 = 255;
		textParams.b1 = 255;
		textParams.fadeinTime = 0;
		textParams.fadeoutTime = 0;
		textParams.holdTime = 9999.0f;
		textParams.channel = 2;
		
		Item@ item = g_items[bestItemId];
		
		//g_PlayerFuncs.HudMessage(plr, textParams, "\n" + item.title + "\n" + item.getCostText());
		
		textParams.channel = 1;
		textParams.x = -1;
		textParams.y = 1;
		
		string extraNewline = "";
		if (int(item.desc.Find("\n")) == -1)
		{
			extraNewline = "\n";
		}
		g_PlayerFuncs.HudMessage(plr, textParams, item.title + "\n" + item.getCostText() + "\n\n" + item.desc + extraNewline);
	}
	
	return bestItemId;
}

void clearHud(CBasePlayer@ plr)
{
	PlayerState@ state = getPlayerState(plr);
	
	for (int i = 0; i < 16; i++)
		g_PlayerFuncs.HudToggleElement(plr, i, false);
		
	HUDTextParams textParams;
	for (int i = 0; i < 5; i++)
	{
		textParams.channel = i;
		g_PlayerFuncs.HudMessage(plr, textParams, "");
	}
	g_PlayerFuncs.ScreenFade(plr, Vector(0,0,0), 0, 0, 0, 0);
		
	state.map_update = true;
}

void exitMenu(CBaseEntity@ cam, CBasePlayer@ plr)
{
	PlayerState@ state = getPlayerState(plr);
	if (cam is null or plr is null)
		return;
	
	cam.Use(plr, plr, USE_OFF);
	g_EntityFuncs.Remove(cam);
	
	clearHud(plr);
	state.closeMenus();
}

bool menuMouseCallback(CBaseEntity@ cam, CBaseEntity@ pPlayer, CBaseEntity@ pEntity, 
	int mouseEvent, int mouseEventParam, float screenX, float screenY, 
	Vector mousePosition, Vector clickDirection, Vector clickPlaneNormal, float scale)
{
	CBasePlayer@ plr = cast<CBasePlayer@>(pPlayer);
	
	int itemId = drawCraftingMenu(plr, -1, screenX, screenY, true);
	
	if (itemId != -1 and mouseEvent == 1 and mouseEventParam == 0) {
		int given = craftItem(plr, itemId);
		if (given > 0)
		{
			HUDTextParams textParams;
			textParams.x = screenX*0.5f + 0.5f;
			textParams.y = screenY*-0.5f + 0.5f;
			textParams.r1 = 255;
			textParams.g1 = 255;
			textParams.b1 = 255;
			textParams.fadeinTime = 0;
			textParams.fadeoutTime = 0.5f;
			textParams.holdTime = 0.0f;
			textParams.channel = 3;
			Item@ item = g_items[itemId];
			g_PlayerFuncs.HudMessage(plr, textParams, "\n+" + given + " " + item.title);
			
			drawCraftingMenu(plr, -1, screenX, screenY, true, true);
		}
	}
	
	if (mouseEvent == 1 and mouseEventParam == 1) {
		exitMenu(cam, plr);
		return true;
	}
	
	return true;
}

void openCraftMenu(PlayerState@ state, int submenu=-1)
{
	CBasePlayer@ plr = cast<CBasePlayer@>(state.plr.GetEntity());
	
	enterMenuMode(state);
	drawCraftingMenu(plr, submenu);
}