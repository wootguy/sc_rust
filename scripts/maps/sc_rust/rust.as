#include "building_plan"
#include "hammer"
#include "func_breakable_custom"
#include "func_build_zone"

void dummyCallback(CTextMenu@ menu, CBasePlayer@ plr, int page, const CTextMenuItem@ item) {}

class PlayerState
{
	EHandle plr;
	CTextMenu@ menu;
	int useState = 0;
	int codeTime = 0; // time left to input lock code
	int numParts = 0; // number of unbroken build parts owned by the player
	int home_zone = -1; // zone the player is allowed to settle in (-1 = nomad)
	array<EHandle> authedLocks; // locked objects the player can use
	EHandle currentLock; // lock currently being interacted with
	
	void initMenu(CBasePlayer@ plr, TextMenuPlayerSlotCallback@ callback)
	{
		CTextMenu temp(@callback);
		@menu = @temp;
	}
	
	void openMenu(CBasePlayer@ plr, int time=60) 
	{
		if ( menu.Register() == false ) {
			g_Game.AlertMessage( at_console, "Oh dear menu registration failed\n");
		}
		menu.Open(time, 0, plr);
	}
	
	void closeMenus()
	{
		if (menu !is null)
		{
			menu.Unregister();
			@menu = null;
		}
		
		if (plr)
		{
			
			CBasePlayer@ p = cast<CBasePlayer@>(plr.GetEntity());
			initMenu(p, dummyCallback);
			menu.AddItem("Closing menu...", any(""));
			openMenu(p, 1);
		}
	}

	bool isAuthed(CBaseEntity@ lock)
	{
		for (uint i = 0; i < authedLocks.length(); i++)
		{
			if (authedLocks[i] and authedLocks[i].GetEntity().entindex() == lock.entindex())
			{
				return true;
			}
		}
		return false;
	}

	void addPart(CBaseEntity@ part)
	{
		part.pev.noise1 = g_EngineFuncs.GetPlayerAuthId( plr.GetEntity().edict() );
		part.pev.noise2 = plr.GetEntity().pev.netname;
		numParts++;
	}
	
	void partDestroyed()
	{
		numParts--;
		if (numParts == 0)
		{
			BuildZone@ zone = getBuildZone(home_zone);
			zone.numSettlers--;
			CBasePlayer@ p = cast<CBasePlayer@>(plr.GetEntity());
			g_PlayerFuncs.SayText(p, "Your base in zone " + zone.id + " was completely destroyed. You can rebuild in any zone.");
			home_zone = -1;
		}
	}
	
	// number of points available in the current build zone
	int maxPoints()
	{
		return 100;
	}
	
	// Points exist because of the 500 visibile entity limit. After reserving about 100 for items/players/trees/etc, only
	// 400 are left for players to build with. If this were split up evenly among 32 players, then each player only
	// only get ~12 parts to build with. This is too small to be fun, so I created multiple zones separated by mountains.
	// Each zone can have 500 ents inside, so if players are split up into these zones they will have a lot more freedom.
	//
	// Point rules:
	// 1) 400 max build points per zone. ~100 are reserved for items/players/trees/etc.
	// 2) Max of 6 players per zone, each getting 50 build points
	//    2a) New players can still build, but they are counted as raiders and their parts deteriorate.
	// 3) Raiders allowed to build 100 things total in enemy zones.
	//    3a) All raiders share this value, so it could be as bad as 3 parts per raider (32 players and 30 are raiders)
	//    3b) Raider parts deteriorate quickly, so new raiders can have points to build with
	//    3c) Raider parts cannot be repaired.
	//    3d) Raider parts deteriorate faster when near the limit.
	//			0-50  = indefinate
	//			50-75 = 60 minutes
	//			75-90 = 10 minutes
	//			90-100 = 1 minute
	// 4) Zone residents can share points with each other to build super bases
	//    4a) Unsharing is immediate, but if the sharee has already built something, then the sharer has to wait for
	//        any of the sharee's parts to be destroyed. This can be used to sabotage their base, since they won't have
	//        the points to repair a gaping hole in their wall.
	// 5) Reserved points
}

dictionary player_states;

array<EHandle> g_tool_cupboards;
array<EHandle> g_build_parts; // every build structure in the map (func_breakable_custom)
array<EHandle> g_build_items; // every non-func_breakable_custom build item in the map (func_door)
array<EHandle> g_build_zone_ents;
array<BuildZone> g_build_zones;
array<string> g_upgrade_suffixes = {
	"_twig",
	"_wood",
	"_stone",
	"_metal",
	"_armor"
};

dictionary g_partname_to_model; // maps models to part names
dictionary g_model_to_partname; // maps part names to models
float g_tool_cupboard_radius = 512;
int g_part_id = 0;
bool debug_mode = false;

int MAX_SAVE_DATA_LENGTH = 1015; // Maximum length of a value saved with trigger_save. Discovered through testing

void MapInit()
{
	g_CustomEntityFuncs.RegisterCustomEntity( "weapon_building_plan", "weapon_building_plan" );
	g_ItemRegistry.RegisterWeapon( "weapon_building_plan", "sc_rust", "" );
	
	g_CustomEntityFuncs.RegisterCustomEntity( "weapon_hammer", "weapon_hammer" );
	g_ItemRegistry.RegisterWeapon( "weapon_hammer", "sc_rust", "" );
	
	g_CustomEntityFuncs.RegisterCustomEntity( "func_breakable_custom", "func_breakable_custom" );
	g_CustomEntityFuncs.RegisterCustomEntity( "func_build_zone", "func_build_zone" );
	
	g_Hooks.RegisterHook( Hooks::Player::PlayerUse, @PlayerUse );
	g_Hooks.RegisterHook( Hooks::Player::ClientSay, @ClientSay );
	
	g_Scheduler.SetInterval("stabilityCheck", 0.0);
	g_Scheduler.SetInterval("inventoryCheck", 0.05);
	//g_Scheduler.SetInterval("decalFix", 0.0);
	
	PrecacheSound("tfc/items/itembk2.wav");
	
	PrecacheSound("sc_rust/bars_metal_place.ogg");
	PrecacheSound("sc_rust/bars_wood_place.ogg");
	PrecacheSound("sc_rust/code_lock_beep.ogg");
	PrecacheSound("sc_rust/code_lock_update.ogg");
	PrecacheSound("sc_rust/code_lock_place.ogg");
	PrecacheSound("sc_rust/code_lock_denied.ogg");
	PrecacheSound("sc_rust/code_lock_shock.ogg");
	PrecacheSound("sc_rust/door_metal_close.ogg");
	PrecacheSound("sc_rust/door_metal_close2.ogg");
	PrecacheSound("sc_rust/door_metal_open.ogg");
	PrecacheSound("sc_rust/door_metal_place.ogg");
	PrecacheSound("sc_rust/door_wood_close.ogg");
	PrecacheSound("sc_rust/door_wood_open.ogg");
	PrecacheSound("sc_rust/door_wood_place.ogg");
	PrecacheSound("sc_rust/shutters_wood_close.ogg");
	PrecacheSound("sc_rust/shutters_wood_open.ogg");
	PrecacheSound("sc_rust/shutters_wood_place.ogg");
	PrecacheSound("sc_rust/tool_cupboard_place.ogg");
	PrecacheSound("sc_rust/ladder_place.ogg");
	PrecacheSound("sc_rust/ladder_hatch_place.ogg");
	PrecacheSound("sc_rust/ladder_hatch_open.ogg");
	PrecacheSound("sc_rust/ladder_hatch_close.ogg");
	PrecacheSound("sc_rust/high_wall_place_stone.ogg");
	PrecacheSound("sc_rust/high_wall_place_wood.ogg");
	
	// precache breakable object assets
	PrecacheSound("debris/bustcrate1.wav");
	PrecacheSound("debris/bustcrate2.wav");
	PrecacheSound("debris/wood1.wav");
	PrecacheSound("debris/wood2.wav");
	PrecacheSound("debris/wood3.wav");
	g_Game.PrecacheModel( "models/woodgibs.mdl" );
	
	for (uint i = 0; i < g_material_damage_sounds.length(); i++)
		for (uint k = 0; k < g_material_damage_sounds[i].length(); k++)
			PrecacheSound(g_material_damage_sounds[i][k]);
	for (uint i = 0; i < g_material_break_sounds.length(); i++)
		for (uint k = 0; k < g_material_break_sounds[i].length(); k++)
			PrecacheSound(g_material_break_sounds[i][k]);
}

void MapActivate()
{
	array<string> construct_part_names = {
		"b_foundation",
		"b_foundation_2x1",
		"b_foundation_2x2",
		"b_foundation_3x1",
		"b_foundation_4x1",
		"b_foundation_tri",
		"b_foundation_tri_2x1",
		"b_foundation_tri_2x2", // big tri
		"b_foundation_tri_3x1",
		"b_foundation_tri_4x1",
		"b_foundation_tri_1x4",
		"b_wall",
		"b_wall_1x2",
		"b_wall_1x3",
		"b_wall_1x4",
		"b_wall_2x1",
		"b_wall_2x2",
		"b_wall_3x1",
		"b_wall_4x1",
		"b_doorway",
		"b_doorway_1x2",
		"b_doorway_1x3",
		"b_doorway_1x4",
		"b_doorway_2x1",
		"b_doorway_2x2",
		"b_doorway_3x1",
		"b_doorway_4x1",
		"b_window",
		"b_window_1x2",
		"b_window_1x3",
		"b_window_1x4",
		"b_window_2x1",
		"b_window_2x2",
		"b_window_3x1",
		"b_window_4x1",
		"b_low_wall",
		"b_low_wall_2x1",
		"b_low_wall_3x1",
		"b_low_wall_4x1",
		"b_floor",
		"b_floor_2x1",
		"b_floor_2x2",
		"b_floor_3x1",
		"b_floor_4x1",
		"b_floor_tri",
		"b_floor_tri_2x1",
		"b_floor_tri_2x2",
		"b_floor_tri_3x1",
		"b_floor_tri_4x1",
		"b_floor_tri_1x4",
		"b_roof",
		"b_stairs",
		"b_stairs_l",
		"b_foundation_steps",
		
		"b_roof_wall_left",
		"b_roof_wall_right",
		"b_roof_wall_both"
	};
	array<string> part_names = {
		"b_wood_door",
		"b_metal_door",
		"b_wood_bars",
		"b_metal_bars",
		"b_wood_shutters",
		"b_code_lock",
		"b_tool_cupboard",
		"b_high_wood_wall",
		"b_high_stone_wall",
		"b_ladder",
		"b_ladder_hatch",
		
		"b_wood_shutter_r",
		"b_wood_shutter_l",
		"b_wood_door_lock",
		"b_wood_door_unlock",
		"b_metal_door_unlock",
		"b_metal_door_lock",
		"b_ladder_box",
		"b_ladder_hatch_ladder",
		"b_ladder_hatch_door",
		"b_ladder_hatch_door_unlock",
		"b_ladder_hatch_door_lock"
	};
	
	for (uint i = 0; i < part_names.length(); i++)
	{
		CBaseEntity@ copy_ent = g_EntityFuncs.FindEntityByTargetname(null, part_names[i]);
		if (copy_ent !is null) {
			g_partname_to_model[string(copy_ent.pev.model)] = part_names[i];
			g_model_to_partname[part_names[i]] = string(copy_ent.pev.model);
			g_EntityFuncs.Remove(copy_ent);
		}
		else
			println("Missing entity: " + part_names[i]);
	}
	
	for (uint i = 0; i < construct_part_names.length(); i++)
	{
		for (uint k = 0; k < g_upgrade_suffixes.length(); k++)
		{
			string name = construct_part_names[i] + g_upgrade_suffixes[k];
			CBaseEntity@ copy_ent = g_EntityFuncs.FindEntityByTargetname(null, name);
			if (copy_ent !is null) {
				g_partname_to_model[string(copy_ent.pev.model)] = name;
				g_model_to_partname[name] = string(copy_ent.pev.model);
				g_EntityFuncs.Remove(copy_ent);
			}
			else
				println("Missing entity: " + name);
		}
	}
	
	CBaseEntity@ ent = null;
	do {
		@ent = g_EntityFuncs.FindEntityByClassname(ent, "func_build_zone");
		if (ent !is null)
		{
			g_build_zone_ents.insertLast(EHandle(ent));
			int id = cast<func_build_zone@>(CastToScriptClass(ent)).id;
			bool unique = true;
			for (uint i = 0; i < g_build_zones.length(); i++)
			{
				if (g_build_zones[i].id == id)
				{
					unique = false;
					break;
				}
			}
			
			if (!unique)
				continue;
			
			g_build_zones.insertLast(BuildZone(id, "???"));
		}
	} while (ent !is null);
	
	int slots = g_Engine.maxClients;
	int settlersPerZone = Math.max(1, slots / g_build_zones.length());
	int wastedSettlers = slots - (settlersPerZone*g_build_zones.length());
	int partsPerPlayer = MAX_ZONE_BUILD_PARTS / settlersPerZone;
	int wastedParts = MAX_ZONE_BUILD_PARTS - (partsPerPlayer*settlersPerZone);
	for (uint i = 0; i < g_build_zones.length(); i++)
		g_build_zones[i].maxSettlers = settlersPerZone;
	println("\nBuild Zone Info:\n\t\t" + g_build_zones.length() + " zones" +
			"\n\t\t" + settlersPerZone + " players per zone (" + wastedSettlers + " player slots unaccounted for)." +
			"\n\t\t" + partsPerPlayer + " Build parts per player (" + wastedParts + " parts left over).\n");
}

void debug_stability(Vector start, Vector end)
{
	if (getPartAtPos(end) !is null)
		te_beampoints(start, end, "sprites/laserbeam.spr", 0, 100, 255,1,0,GREEN);
	else
		te_beampoints(start, end, "sprites/laserbeam.spr", 0, 100, 255,1,0,Color(255, 0, 0, 0));
}

bool searchFromPart(func_breakable_custom@ part)
{
	if (visited_parts.exists(part.entindex()))
	{
		numSkip++;
		return false;
	}
	visited_parts[part.entindex()] = true;
	numChecks++;
	
	if (part.pev.colormap == B_FOUNDATION or part.pev.colormap == B_FOUNDATION_TRI) {
		return true;
	}
	for (uint i = 0; i < part.connections.length(); i++)
	{
		if (part.connections[i])
		{
			if (searchFromPart(cast<func_breakable_custom@>(CastToScriptClass(part.connections[i].GetEntity()))))
				return true;
		}
		
	}
	return false;
}

int numSkip = 0;
int numChecks = 0;
dictionary visited_parts; // used to mark positions as already visited when doing the stability search
array<EHandle> stability_ents; // list of ents to check for stability
int wait_stable_check = 0; // frames to wait before next stability check (so broken parts aren't detected)

void checkStabilityEnt(EHandle ent)
{
	for (uint i = 0; i < stability_ents.length(); i++)
	{
		if (stability_ents[i] and stability_ents[i].GetEntity().entindex() == ent.GetEntity().entindex())
			return;
	}
	stability_ents.insertLast(ent);
}

void propogate_part_destruction(CBaseEntity@ ent)
{	
	int type = ent.pev.colormap;
	int socket = socketType(type);
	if (ent.pev.classname == "func_breakable_custom")
	{
		func_breakable_custom@ bpart = cast<func_breakable_custom@>(CastToScriptClass(ent));
		for (uint i = 0; i < bpart.connections.length(); i++)
			checkStabilityEnt(bpart.connections[i]);
	}

	// destroy objects parented to this one
	array<EHandle> children = getPartsByParent(ent.pev.team);
	for (uint i = 0; i < children.length(); i++)
	{
		CBaseEntity@ child = children[i];
		if (child.entindex() == ent.entindex())
			continue;
		child.TakeDamage(child.pev, child.pev, 9e99, 0);
		if (child.pev.classname == "func_ladder")
		{
			g_EntityFuncs.Remove(child);
		}
	}
	
	if (type == B_LADDER_HATCH or type == B_LADDER or type == B_WOOD_SHUTTERS)
	{
		// kill tied entities (ladder, secondary door)
		array<EHandle> parents = getPartsByID(ent.pev.team);
		for (uint i = 0; i < parents.length(); i++)
		{
			CBaseEntity@ parent = parents[i].GetEntity();
			parent.TakeDamage(parent.pev, parent.pev, parent.pev.health, 0);
			if (parent.pev.classname == "func_ladder")
			{
				g_EntityFuncs.Remove(parent);
			}
		}
	}
	wait_stable_check = 1;
}

void part_broken(CBaseEntity@ pActivator, CBaseEntity@ pCaller, USE_TYPE useType, float flValue)
{
	if (pCaller.pev.effects & EF_NODRAW == 0)
	{
		PlayerState@ state = getPlayerStateBySteamID(pCaller.pev.noise1, pCaller.pev.noise2);
		if (state !is null)
			state.partDestroyed();
	}
	
	propogate_part_destruction(pCaller);
}

void stabilityCheck()
{
	int numIter = 0;
	
	// check for destroyed ents
	for (uint i = 0; i < g_build_parts.length(); i++)
	{
		func_breakable_custom@ ent = cast<func_breakable_custom@>(CastToScriptClass(g_build_parts[i].GetEntity()));
		if (ent is null)
		{
			g_build_parts.removeAt(i);
			i--;
		}
		else
		{
			ent.pev.frame = 0;
			ent.pev.framerate = 0;
			if (ent.pev.team != ent.id)
			{
				println("UH OH BAD ID " + ent.id + " != " + ent.pev.team);
				ent.pev.team = ent.id;
			}
		}
	}
	
	if (wait_stable_check > 0)
	{
		wait_stable_check--;
		return;
	}
	
	while(stability_ents.length() > 0)
	{		
		visited_parts.deleteAll();
		CBaseEntity@ src_part = stability_ents[0];
		
		if (src_part is null)
		{
			stability_ents.removeAt(0);
			continue;
		}
		
		if (src_part.pev.classname != "func_breakable_custom")
		{
			println("Not a support part!");
			stability_ents.removeAt(0);
			continue;
		}
		
		func_breakable_custom@ bpart = cast<func_breakable_custom@>(CastToScriptClass(src_part));
		
		int type = src_part.pev.colormap;
		int socket = socketType(type);
		Vector pos = src_part.pev.origin;
		
		if (src_part.pev.colormap == B_FOUNDATION or socket == SOCKET_HIGH_WALL or src_part.pev.colormap == B_FOUNDATION_TRI)
		{
			stability_ents.removeAt(0);
			continue;
		}
			
		// try to find a connected path to a foundation
		// otherwise break the part
		
		numChecks = 0;
		numSkip = 0;
		
		bool supported = searchFromPart(bpart);

		println("Stability for part " + src_part.pev.team + " finished in " + numChecks + " checks (" + numSkip + " skipped). Result is " + supported);
		
		if (!supported) {
			propogate_part_destruction(src_part);
			src_part.TakeDamage(src_part.pev, src_part.pev, src_part.pev.health, 0);
			if (src_part.pev.classname == "func_ladder")
			{
				g_EntityFuncs.Remove(src_part);
			}
		}

		stability_ents.removeAt(0);
		break;
	}
}

void giveItem(CBasePlayer@ plr, int type, int amt)
{
	dictionary keys;
	keys["origin"] = plr.pev.origin.ToString();
	keys["model"] = "models/w_357.mdl";
	keys["weight"] = "1.0";
	keys["spawnflags"] = "" + (256 + 512);
	keys["return_timelimit"] = "-1";
	keys["holder_can_drop"] = "1";
	keys["carried_hidden"] = "1";
	
	keys["display_name"] = g_items[type].title;
	keys["description"] =  g_items[type].desc;
	
	println("GIB " + amt + "x " + g_items[type].title + " TO " + plr.pev.netname);
	g_PlayerFuncs.PrintKeyBindingString(plr, "" + amt + "x " + g_items[type].title);
	
	if (!g_items[type].stackable)
	{
		for (int i = 0; i < amt; i++)
		{
			CBaseEntity@ ent = g_EntityFuncs.CreateEntity("item_inventory", keys, true);
			ent.Use(@plr, @plr, USE_ON, 0.0F);
		}
	}
	else
	{
		// todo
	}
}

void craftMenuCallback(CTextMenu@ menu, CBasePlayer@ plr, int page, const CTextMenuItem@ item)
{
	if (item is null)
		return;
	string action;
	item.m_pUserData.retrieve(action);
	PlayerState@ state = getPlayerState(plr);
	
	if (action == "build-menu" or action == "item-menu" or action == "armor-menu" or action == "tool-menu" or
		action == "medical-menu" or action == "weapon-menu" or action == "ammo-menu")
	{
		g_Scheduler.SetTimeout("openCraftMenu", 0, @plr, action);
	}
	else
	{
		if (action == "wood-door") giveItem(@plr, I_WOOD_DOOR, 1);
		if (action == "tool-cupboard") giveItem(@plr, I_TOOL_CUPBOARD, 1);
		g_Scheduler.SetTimeout("openCraftMenu", 0, @plr, "");
	}
	
	menu.Unregister();
	@menu = null;
}

void openCraftMenu(CBasePlayer@ plr, string subMenu)
{
	PlayerState@ state = getPlayerState(plr);
	state.initMenu(plr, craftMenuCallback);
	
	if (subMenu == "build-menu") 
	{
		state.menu.SetTitle("Craft -> Build:\n\n");
		state.menu.AddItem("Wood Door\n", any("wood-door"));
		state.menu.AddItem("Metal Door\n", any("metal-door"));
		state.menu.AddItem("Wood Shutters\n", any("wood-shutters"));
		state.menu.AddItem("Wood Window Bars\n", any("wood-window-bars"));
		state.menu.AddItem("Metal Window Bars\n", any("metal-window-bars"));
		state.menu.AddItem("Code Lock\n", any("code-lock"));
		state.menu.AddItem("Tool Cupboard\n", any("tool-cupboard"));
		state.menu.AddItem("High External Wood Wall\n", any("wood-wall"));
		state.menu.AddItem("High External Stone Wall\n", any("stone-wall"));
		state.menu.AddItem("Ladder\n", any("ladder"));
		state.menu.AddItem("Ladder Hatch\n", any("ladder-hatch"));
	}
	else if (subMenu == "item-menu") 
	{
		state.menu.SetTitle("Craft -> Items:\n\n");
		state.menu.AddItem("Chest\n", any("small-chest"));
		state.menu.AddItem("Large Chest\n", any("large-chest"));
		state.menu.AddItem("Camp Fire\n", any("fire"));
		state.menu.AddItem("Furnace\n", any("furnace"));
		state.menu.AddItem("Large Furnace\n", any("large-furnace"));
		state.menu.AddItem("Stash\n", any("stash"));
		state.menu.AddItem("Sleeping Bag\n", any("sleeping-bag"));
	}
	else if (subMenu == "armor-menu") 
	{
		state.menu.SetTitle("Craft -> Armor:\n\n");
		state.menu.AddItem("Wood Helmet\n", any("wood-helmet"));
		state.menu.AddItem("Wood Chestplate\n", any("wood-chestplate"));
		state.menu.AddItem("Wood Pants\n", any("wood-pants"));
		state.menu.AddItem("Metal Helmet\n", any("metal-helmet"));
		state.menu.AddItem("Metal Chestplate\n", any("metal-chestplate"));
		state.menu.AddItem("Metal Pants\n", any("metal-pants"));
	}
	else if (subMenu == "tool-menu")
	{
		state.menu.SetTitle("Craft -> Tools:\n\n");
		state.menu.AddItem("Rock\n", any("rock"));
		state.menu.AddItem("Torch\n", any("torch"));
		state.menu.AddItem("Building Plan\n", any("build-plan"));
		state.menu.AddItem("Hammer\n", any("hammer"));
		state.menu.AddItem("Stone Hatchet\n", any("stone-axe"));
		state.menu.AddItem("Stone Pick Axe\n", any("stone-pick"));
		state.menu.AddItem("Metal Hatchet\n", any("metal-axe"));
		state.menu.AddItem("Metal Pick Axe\n", any("metal-pick"));
	}
	else if (subMenu == "medical-menu")
	{
		state.menu.SetTitle("Craft -> Medical:\n\n");
		state.menu.AddItem("Bandage\n", any("bandage"));
		state.menu.AddItem("Small Medkit\n", any("small-medkit"));
		state.menu.AddItem("Large Medkit\n", any("large-medkit"));
		state.menu.AddItem("Acoustic Guitar\n", any("guitar"));
	}
	else if (subMenu == "weapon-menu")
	{
		state.menu.SetTitle("Craft -> Weapons:\n\n");
		state.menu.AddItem("Crowbar\n", any("crowbar"));
		state.menu.AddItem("Wrench\n", any("wrench"));
		state.menu.AddItem("Bow\n", any("bow"));
		state.menu.AddItem("Pistol\n", any("pistol"));
		state.menu.AddItem("Shotgun\n", any("shotgun"));
		state.menu.AddItem("Flamethrower\n", any("flamethrower"));
		state.menu.AddItem("Sniper Rifle\n", any("sniper"));
		state.menu.AddItem("RPG\n", any("rpg"));
		state.menu.AddItem("Uzi\n", any("uzi"));
		state.menu.AddItem("Saw\n", any("saw"));
		state.menu.AddItem("Grenade\n", any("grenade"));
		state.menu.AddItem("Satchel charge\n", any("satchel"));
		state.menu.AddItem("C4\n", any("c4"));
	}
	else if (subMenu == "ammo-menu")
	{
		state.menu.SetTitle("Craft -> Ammo:\n\n");
		state.menu.AddItem("Arrow\n", any("arrow"));
		state.menu.AddItem("9mm\n", any("9mm"));
		state.menu.AddItem("556\n", any("556"));
		state.menu.AddItem("Buckshot\n", any("buckshot"));
		state.menu.AddItem("Rocket\n", any("rocket"));
	}
	else
	{
		state.menu.SetTitle("Craft:\n\n");
		state.menu.AddItem("Build\n", any("build-menu"));
		state.menu.AddItem("Items\n", any("item-menu"));
		state.menu.AddItem("Armor\n", any("armor-menu"));
		state.menu.AddItem("Tools\n", any("tool-menu"));
		state.menu.AddItem("Medical\n", any("medical-menu"));
		state.menu.AddItem("Weapons\n", any("weapon-menu"));
		state.menu.AddItem("Ammo\n", any("ammo-menu"));
	}
	
	state.openMenu(plr);
}

void te_decal(Vector pos, CBaseEntity@ brushEnt=null, string decal="{handi",
	NetworkMessageDest msgType=MSG_BROADCAST, edict_t@ dest=null)
{
	NetworkMessage m(msgType, NetworkMessages::SVC_TEMPENTITY, dest);
	m.WriteByte(TE_DECAL);
	m.WriteCoord(pos.x);
	m.WriteCoord(pos.y);
	m.WriteCoord(pos.z);
	m.WriteByte(g_EngineFuncs.DecalIndex(decal));
	m.WriteShort(brushEnt is null ? 0 : brushEnt.entindex());
	m.End();
}

// workaround for the "Too many decal textures" error. rip net usage.
void decalFix()
{
	Vector vecSrc = Vector(0,0,128);
	TraceResult tr2;
	Vector vecEnd = vecSrc + Vector(0,0,-128);
	g_Utility.TraceLine( vecSrc, vecEnd, ignore_monsters, null, tr2 );

	//g_Utility.DecalTrace(tr2, g_EngineFuncs.DecalIndex("{handi"));
	for (uint y = 0; y < 32; y++)
		for (uint x = 0; x < 32; x++)
			te_decal(tr2.vecEndPos + Vector(x*16, y*16, 0));
	println("DECAL");
}

void inventoryCheck()
{
	CBaseEntity@ e_plr = null;
	
	do {
		@e_plr = g_EntityFuncs.FindEntityByClassname(e_plr, "player");
		if (e_plr !is null)
		{
			CBasePlayer@ plr = cast<CBasePlayer@>(e_plr);
			if (e_plr.pev.button & IN_RELOAD != 0 and e_plr.pev.button & IN_USE != 0) {
				openCraftMenu(plr, "");
				println("OPEN MENU");
			}
			
			TraceResult tr = TraceLook(plr, 96, true);
			CBaseEntity@ phit = g_EntityFuncs.Instance( tr.pHit );
			
			if (e_plr.pev.button & IN_USE != 0)
			{
				// increment force_retouch
				g_EntityFuncs.FireTargets("push", e_plr, e_plr, USE_TOGGLE);
				println("RETOUCH");
			}
			
			
			if (phit is null or phit.pev.classname == "worldspawn")
				continue;

			HUDTextParams params;
			params.effect = 0;
			params.fadeinTime = 0;
			params.fadeoutTime = 0;
			params.holdTime = 0.2f;
			params.x = 0.5;
			params.y = 0.7;
			params.channel = 1;
			params.r1 = 255;
			params.g1 = 255;
			params.b1 = 255;
			g_PlayerFuncs.HudMessage(plr, params, 
				string(phit.pev.model) + "\n" + int(phit.pev.health) + " / " + int(phit.pev.max_health));
		}
	} while(e_plr !is null);
}

void rotate_door(CBaseEntity@ door, bool playSound)
{	
	if (door.pev.iuser1 == 1) // currently moving?
		return;
		
	bool opening = door.pev.groupinfo == 0;
	Vector dest = opening ? door.pev.vuser2 : door.pev.vuser1;
	
	float speed = 280;
	
	string soundFile = "";
	if (door.pev.colormap == B_WOOD_DOOR) {
		soundFile = opening ? "sc_rust/door_wood_open.ogg" : "sc_rust/door_wood_close.ogg";
	}
	if (door.pev.colormap == B_METAL_DOOR or door.pev.colormap == B_LADDER_HATCH) {
		soundFile = opening ? "sc_rust/door_metal_open.ogg" : "sc_rust/door_metal_close.ogg";
	}
	if (door.pev.colormap == B_LADDER_HATCH) {
		soundFile = opening ? "sc_rust/door_metal_open.ogg" : "sc_rust/door_metal_close2.ogg";
		speed = 200;
	}
	if (door.pev.colormap == B_WOOD_SHUTTERS) {
		soundFile = opening ? "sc_rust/shutters_wood_open.ogg" : "sc_rust/shutters_wood_close.ogg";
		speed = 128;
	}
	
	if (playSound) {
		g_SoundSystem.PlaySound(door.edict(), CHAN_ITEM, soundFile, 1.0f, 1.0f, 0, 90 + Math.RandomLong(0, 20));
	}	
	
	if (dest != door.pev.angles) {
		AngularMove(door, dest, speed);
		
		if (door.pev.colormap == B_LADDER_HATCH) {
			CBaseEntity@ ladder = g_EntityFuncs.FindEntityByTargetname(null, "ladder_hatch" + door.pev.team);
			
			if (ladder !is null)
			{
				int oldcolormap = ladder.pev.colormap;
				ladder.Use(@ladder, @ladder, USE_TOGGLE, 0.0F);
				ladder.pev.colormap = oldcolormap;
			}
			else
				println("ladder_hatch" + door.pev.team + " not found!");
			
		}
	}
	
	door.pev.groupinfo = 1 - door.pev.groupinfo;
}

void lock_object(CBaseEntity@ obj, string code, bool unlock)
{
	string newModel = "";
	if (obj.pev.colormap == B_WOOD_DOOR)
		newModel = "b_wood_door";
	if (obj.pev.colormap == B_METAL_DOOR)
		newModel = "b_metal_door";
	if (obj.pev.colormap == B_LADDER_HATCH)
		newModel = "b_ladder_hatch_door";
	newModel += unlock ? "_unlock" : "_lock";
	
	if (code.Length() > 0)
		obj.pev.noise3 = code;
	
	if (newModel.Length() > 0)
	{
		int oldcolormap = obj.pev.colormap;
		g_EntityFuncs.SetModel(obj, getModelFromName(newModel));
		obj.pev.colormap = oldcolormap;
	}
	
	obj.pev.body = unlock ? 0 : 1;
}

void waitForCode(CBasePlayer@ plr)
{
	PlayerState@ state = getPlayerState(plr);
	if (state.codeTime > 0)
	{
		state.codeTime = 0;
		g_PlayerFuncs.PrintKeyBindingString(plr, "Time expired");
	}
}

void PrintKeyBindingString(CBasePlayer@ plr, string text)
{
	g_PlayerFuncs.PrintKeyBindingString(plr, text);
}

// display the text for a second longer
void PrintKeyBindingStringLong(CBasePlayer@ plr, string text)
{
	g_PlayerFuncs.PrintKeyBindingString(plr, text);
	g_Scheduler.SetTimeout("PrintKeyBindingString", 1, @plr, text);
}

void codeLockMenuCallback(CTextMenu@ menu, CBasePlayer@ plr, int page, const CTextMenuItem@ item)
{
	if (item is null)
		return;
	string action;
	item.m_pUserData.retrieve(action);
	PlayerState@ state = getPlayerState(plr);
	CBaseEntity@ lock = state.currentLock;

	if (action == "code" or action == "unlock-code") {
		state.codeTime = 1;
		string msg = "Type the 4-digit code into chat now";
		PrintKeyBindingStringLong(plr, msg);
	}
	if (action == "unlock") {
		lock_object(state.currentLock, "", true);
		g_SoundSystem.PlaySound(lock.edict(), CHAN_ITEM, "sc_rust/code_lock_beep.ogg", 1.0f, 1.0f, 0, 100);
	}
	if (action == "lock") {
		lock_object(state.currentLock, "", false);
		g_SoundSystem.PlaySound(lock.edict(), CHAN_ITEM, "sc_rust/code_lock_beep.ogg", 1.0f, 1.0f, 0, 55);
	}
	if (action == "remove")
	{	
		string newModel = "";
		if (lock.pev.colormap == B_WOOD_DOOR)
			newModel = "b_wood_door";
		if (lock.pev.colormap == B_METAL_DOOR)
			newModel = "b_metal_door";
		if (lock.pev.colormap == B_LADDER_HATCH)
			newModel = "b_ladder_hatch_door";
		int oldcolormap = lock.pev.colormap;
		g_EntityFuncs.SetModel(lock, getModelFromName(newModel));
		lock.pev.colormap = oldcolormap;
		g_SoundSystem.PlaySound(lock.edict(), CHAN_ITEM, "sc_rust/code_lock_place.ogg", 1.0f, 1.0f, 0, 100);		
		giveItem(@plr, I_CODE_LOCK, 1);
		
		lock.pev.button = 0;
		lock.pev.body = 0;
		lock.pev.noise3 = "";
	}
	
	menu.Unregister();
	@menu = null;
}

void openCodeLockMenu(CBasePlayer@ plr, CBaseEntity@ door)
{
	PlayerState@ state = getPlayerState(plr);
	state.initMenu(plr, codeLockMenuCallback);
	
	state.menu.SetTitle("Code Lock:\n\n");
	
	bool authed = state.isAuthed(door);
	
	if (door.pev.body == 1) // locked
	{
		if (authed)
		{
			state.menu.AddItem("Change Code\n", any("code"));
			state.menu.AddItem("Unlock\n", any("unlock"));
			state.menu.AddItem("Remove Lock\n", any("remove"));
		}
		else
		{
			state.menu.AddItem("Unlock with code\n", any("unlock-code"));
		}
		
	}
	else // unlocked
	{
		state.menu.AddItem("Change Code\n", any("code"));
		if (string(door.pev.noise3).Length() > 0) {
			state.menu.AddItem("Lock\n", any("lock"));
		}
		state.menu.AddItem("Remove Lock\n", any("remove"));
	}
	
	state.openMenu(plr);
}

HookReturnCode PlayerUse( CBasePlayer@ plr, uint& out )
{
	PlayerState@ state = getPlayerState(plr);
	bool useit = plr.m_afButtonReleased & IN_USE != 0 and state.useState < 50 and state.useState != -1;
	bool heldUse = state.useState == 50;
	
	if (plr.m_afButtonPressed & IN_USE != 0)
	{
		state.useState = 0;
	}
	else if (plr.pev.button & IN_USE != 0) 
	{
		if (state.useState >= 0)
			state.useState += 1;
		if (heldUse)
		{
			useit = true;
			state.useState = -1;
		}
	}
	if (useit)
	{
		TraceResult tr = TraceLook(plr, 256);
		CBaseEntity@ phit = g_EntityFuncs.Instance( tr.pHit );
		
		if (phit !is null and (phit.pev.classname == "func_door_rotating" or phit.pev.classname == "func_breakable_custom"))
		{
			int socket = socketType(phit.pev.colormap);
			if (socket == SOCKET_DOORWAY or (phit.pev.colormap == B_LADDER_HATCH and phit.pev.targetname != ""))
			{
				if (heldUse)
				{
					if (phit.pev.button != 0) // door has lock?
					{
						openCodeLockMenu(plr, phit);
						state.currentLock = phit;
					}
				}
				else
				{
					bool locked = phit.pev.button == 1 and phit.pev.body == 1;
					bool authed = state.isAuthed(phit);
					if (!locked or authed)
					{
						rotate_door(phit, true);
						if (locked) {
							g_SoundSystem.PlaySound(phit.edict(), CHAN_WEAPON, "sc_rust/code_lock_beep.ogg", 1.0f, 1.0f, 0, 100);
						}
					}
					if (locked and !authed)
						g_SoundSystem.PlaySound(phit.edict(), CHAN_WEAPON, "sc_rust/code_lock_denied.ogg", 1.0f, 1.0f, 0, 100);
				}
			}
			else if (phit.pev.colormap == B_WOOD_SHUTTERS)
			{
				rotate_door(phit, true);
				
				// open adjacent shutter
				g_EngineFuncs.MakeVectors(phit.pev.vuser1);
				CBaseEntity@ right = getPartAtPos(phit.pev.origin + g_Engine.v_right*94);
				if (right !is null and right.pev.colormap == B_WOOD_SHUTTERS) {
					rotate_door(right, false);
				}
				
				CBaseEntity@ left = getPartAtPos(phit.pev.origin + g_Engine.v_right*-94);
				if (left !is null and left.pev.colormap == B_WOOD_SHUTTERS) {
					rotate_door(left, false);
				}
			}
			else if (phit.pev.colormap == B_TOOL_CUPBOARD)
			{
				bool authed = state.isAuthed(phit);
				if (heldUse)
				{
					clearDoorAuths(phit);
					g_PlayerFuncs.PrintKeyBindingString(plr, "Authorization List Cleared");
				}
				else if (authed)
				{
					// deauth
					for (uint k = 0; k < state.authedLocks.length(); k++)
					{
						if (!state.authedLocks[k] or state.authedLocks[k].GetEntity().entindex() == phit.entindex())
						{
							state.authedLocks.removeAt(k);
							k--;
						}
					}
					g_PlayerFuncs.PrintKeyBindingString(plr, "You are no longer authorized to build");
				} 
				else 
				{
					EHandle h_phit = phit;
					state.authedLocks.insertLast(h_phit);
					g_PlayerFuncs.PrintKeyBindingString(plr, "You are now authorized to build");
				}
			}
		}
	}
	return HOOK_CONTINUE;
}

void clearDoorAuths(CBaseEntity@ door)
{
	array<string>@ stateKeys = player_states.getKeys();
	for (uint i = 0; i < stateKeys.length(); i++)
	{
		PlayerState@ state = cast<PlayerState@>( player_states[stateKeys[i]] );
		for (uint k = 0; k < state.authedLocks.length(); k++)
		{
			if (!state.authedLocks[k] or state.authedLocks[k].GetEntity().entindex() == door.entindex())
			{
				state.authedLocks.removeAt(k);
				k--;
			}
		}
	}
}

bool doRustCommand(CBasePlayer@ plr, const CCommand@ args)
{
	PlayerState@ state = getPlayerState(plr);
	
	if ( args.ArgC() > 0 )
	{
		if (args[0] == ".save")
		{
			saveMapData();
			return true;
		}
		if (args[0] == ".load")
		{
			loadMapData();
			return true;
		}
		if (state.codeTime > 0)
		{
			state.codeTime = 0;
			string code = args[0];
			if (code.Length() != 4)
			{
				PrintKeyBindingStringLong(plr, "ERROR:\n\nCode must be 4 digits long");
				return true;
			}
			bool digitsOk = true;
			for (uint i = 0; i < code.Length(); i++)
			{
				if (!isdigit(code[i]))
				{
					digitsOk = false;
					break;
				}
			}
			if (!digitsOk) {
				PrintKeyBindingStringLong(plr, "ERROR:\n\nCode can only contain digits (0-9)");
				return true;
			}

			// lock code accepted
			if (state.currentLock)
			{
				CBaseEntity@ ent = state.currentLock;
				
				if (ent.pev.body == 0 or state.isAuthed(ent))  // owner changing code
				{
					PrintKeyBindingStringLong(plr, "Code accepted. Lock engaged.");
					lock_object(ent, code, false);
					clearDoorAuths(ent);
					g_SoundSystem.PlaySound(ent.edict(), CHAN_ITEM, "sc_rust/code_lock_update.ogg", 1.0f, 1.0f, 0, 100);
					state.authedLocks.insertLast(state.currentLock);
				} 
				else // guest is unlocking
				{ 
					if (code == ent.pev.noise3) {
						PrintKeyBindingStringLong(plr, "Code accepted");
						g_SoundSystem.PlaySound(ent.edict(), CHAN_ITEM, "sc_rust/code_lock_update.ogg", 1.0f, 1.0f, 0, 100);
						state.authedLocks.insertLast(state.currentLock);
					} else {
						PrintKeyBindingStringLong(plr, "Incorrect code");
						g_SoundSystem.PlaySound(ent.edict(), CHAN_ITEM, "sc_rust/code_lock_shock.ogg", 1.0f, 1.0f, 0, 100);
						plr.TakeDamage(ent.pev, ent.pev, 10.0f, DMG_SHOCK);
					}	
				}
			} 
			else
				PrintKeyBindingStringLong(plr, "ERROR:\n\nLock no longer exists");
			
			return true;
		}
	}
	return false;
}

HookReturnCode ClientSay( SayParameters@ pParams )
{
	CBasePlayer@ plr = pParams.GetPlayer();
	const CCommand@ args = pParams.GetArguments();	
	if (doRustCommand(plr, args))
	{
		pParams.ShouldHide = true;
		return HOOK_HANDLED;
	}
	return HOOK_CONTINUE;
}

bool saveLoadInProgress = false;

EHandle savePart(int idx)
{
	EHandle nullHandle = null;
	
	if (g_build_parts[idx]) {
		func_breakable_custom@ ent = cast<func_breakable_custom@>(CastToScriptClass(g_build_parts[idx].GetEntity()));
		println("Saving part " + ent.pev.team);
		
		// using quotes as delimitters because players can't use them in their names
		string data = ent.serialize();
		if (int(data.Length()) > MAX_SAVE_DATA_LENGTH)
			println("MAYDAY! MAYDAY! SAVE DATA IS TOO LONG FOR PART " + ent.pev.team);
		else
		{
			return createTriggerSave("RustPart" + idx, data, 'rust_save_ent_' + "RustPart" + (idx+1));
		}
	}
	return nullHandle;
}

// Warning: Doing this within a second of another save could result in a corrupted map save file
// It's safer to just make a chain of trigger_save if you need to save multiple values
void saveMapKeyvalue(string label, string value)
{
	dictionary keyvalues;
	string ent_name = 'rust_save_ent_' + label; 
	keyvalues["targetname"] = ent_name;
	keyvalues["target"] = ent_name;
	keyvalues["netname"] = label;
	keyvalues["message"] = "noise3";
	keyvalues["noise3"] = value;
	//keyvalues["m_iszTrigger"] = triggerAfterSave;
	
	// Create it, trigger it, and then delete it
	CBaseEntity@ ent = g_EntityFuncs.CreateEntity( "trigger_save", keyvalues, true );
	g_EntityFuncs.FireTargets(ent_name, null, null, USE_ON);
	if (ent !is null)
		g_EntityFuncs.Remove(ent);
	println("Saving key: " + label);
}

string loadMapKeyvalue(string label)
{
	dictionary keyvalues;
	string ent_name = 'rust_load_ent_' + label; 
	keyvalues["targetname"] = ent_name;
	keyvalues["target"] = ent_name;
	keyvalues["netname"] = label;
	keyvalues["message"] = "noise3";
	
	// Create and trigger it
	CBaseEntity@ ent = g_EntityFuncs.CreateEntity( "trigger_load", keyvalues, true );
	g_EntityFuncs.FireTargets(ent_name, null, null, USE_ON);
	
	// For some reason we have to run a Find in order to get the updated entity data.
	// It seems the load happens instantly, but the entity reference isn't updated that fast.
	string data;
	CBaseEntity@ updated_ent = g_EntityFuncs.FindEntityByTargetname(null, ent_name);
	if (updated_ent !is null)
		data = updated_ent.pev.noise3;
	else
		println("Failed to load '" + label + "' from map save file");
	
	if (ent !is null)
		g_EntityFuncs.Remove(ent);
	
	return data;
}


EHandle createTriggerSave(string label, string value, string triggerAfterSave)
{
	dictionary keyvalues;
	string ent_name = 'rust_save_ent_' + label; 
	keyvalues["targetname"] = ent_name;
	keyvalues["target"] = ent_name;
	keyvalues["netname"] = label;
	keyvalues["message"] = "noise3";
	keyvalues["noise3"] = value;
	keyvalues["m_iszTrigger"] = triggerAfterSave;
	
	CBaseEntity@ ent = g_EntityFuncs.CreateEntity( "trigger_save", keyvalues, true );
	EHandle ent_handle = ent;
	return ent_handle;
}

string numPartsKeyname = "RustNumParts";
void saveMapData()
{	
	saveMapKeyvalue(numPartsKeyname, "" + g_build_parts.length());
	
	if (g_build_parts.length() == 0)
		return;
		
	saveLoadInProgress = true;
		
	println("Saving " + g_build_parts.length() + " build parts");

	// creating a chain of trigger_save seems to work reliably
	// Too bad I have to create so many extra ents at once
	array<EHandle> partSaves; 
	for (uint i = 0; i < g_build_parts.length(); i++)
		partSaves.insertLast(savePart(i));

	CBaseEntity@ firstSave = partSaves[0];
	g_EntityFuncs.FireTargets(firstSave.pev.targetname, null, null, USE_ON);
	
	for (uint i = 0; i < partSaves.length(); i++)
	{
		CBaseEntity@ ent = partSaves[i];
		if (ent !is null) {
			g_EntityFuncs.Remove(ent);
		}
	}
	
	saveLoadInProgress = false;
}

void unlockSaveLoad()
{
	saveLoadInProgress = false;
	for (uint i = 0; i < g_build_parts.length(); i++)
	{
		func_breakable_custom@ ent = cast<func_breakable_custom@>(CastToScriptClass(g_build_parts[i].GetEntity()));
		ent.updateConnections();
	}
}

void loadPart(int idx)
{	
	string data = loadMapKeyvalue("RustPart" + idx);
	if (data.Length() > 0) {
		array<string> values = data.Split('"');
		
		if (values.length() == 17) {
			println("Loading part " + idx);
			Vector origin = parseVector(values[0]);
			Vector angles = parseVector(values[1]);
			int type = atoi( values[2] );
			int id = atoi( values[3] );
			int parent = atoi( values[4] );
			int button = atoi( values[5] );
			int body = atoi( values[6] );
			Vector vuser1 = parseVector(values[7]);
			Vector vuser2 = parseVector(values[8]);
			float health = atof( values[9] );
			string classname = values[10];
			string model = values[11];
			int groupinfo = atoi( values[12] );
			string steamid = values[13];
			string netname = values[14];
			string code = values[15];
			int effects = atoi( values[16] );
			
			dictionary keys;
			keys["origin"] = origin.ToString();
			keys["angles"] = angles.ToString();
			keys["model"] = model;
			keys["health"] = "health";
			//keys["colormap"] = "" + type;
			keys["material"] = "1";
			keys["target"] = "break_part_script";
			keys["fireonbreak"] = "break_part_script";
			keys["health"] = "100";
			keys["rendermode"] = "4";
			keys["renderamt"] = "255";
			keys["id"] = "" + id;
			keys["parent"] = "" + parent;
			
			int socket = socketType(type);
			if (socket == SOCKET_DOORWAY or type == B_WOOD_SHUTTERS or type == B_LADDER_HATCH)
			{
				keys["distance"] = "9999";
				keys["speed"] = "0.00000001";
				keys["breakable"] = "1";
				keys["targetname"] = "locked" + id;
				
			}
			if (type == "func_ladder")
			{
				keys["spawnflags"] = "1";
			}
			if (type == B_LADDER)
			{
				keys["rendermode"] = "4";
				keys["renderamt"] = "255";
			}
			
			CBaseEntity@ ent = g_EntityFuncs.CreateEntity(classname, keys, true);
			ent.pev.colormap = type;
			ent.pev.button = button;
			ent.pev.body = body;
			ent.pev.vuser1 = vuser1;
			ent.pev.vuser2 = vuser2;
			ent.pev.groupinfo = groupinfo;
			ent.pev.noise1 = steamid;
			ent.pev.noise2 = netname;
			ent.pev.noise3 = code;
			ent.pev.team = id;
			ent.pev.effects = effects | EF_NODECALS;
			//g_EntityFuncs.SetSize(ent.pev, ent.pev.mins, ent.pev.maxs);
			//g_EntityFuncs.SetOrigin(ent, ent.pev.origin);
			if (effects & EF_NODRAW != 0)
			{
				ent.pev.solid = SOLID_NOT;
				println("ITS A NODRAW");
			}
			else
			{
				PlayerState@ state = getPlayerStateBySteamID(steamid, netname);
				if (state !is null)
					state.numParts++;
			}
			
			g_build_parts.insertLast(EHandle(ent));
			
			if (id >= g_part_id)
				g_part_id = id+1;
		} else {
			println("Invalid data for part " + idx);
		}
		
	} else {
		println("Failed to load data for part " + idx);
	}
}


void loadMapData()
{		
	int numParts = atoi( loadMapKeyvalue(numPartsKeyname) );
	if (numParts <= 0) {
		println("No portal data found for this map");
		return;
	}
	
	saveLoadInProgress = true;
	
	// prevent anyone from messing up the portals during the load
	player_states.deleteAll();
		
	println("Loading " + numParts + " map portals");
	
	float initialWait = 1.0f;
	for (uint i = 0; i < g_build_parts.length(); i++)
	{
		g_EntityFuncs.Remove(g_build_parts[i]);
	}
	println("Loading " + numParts + " parts...");
	
	float waitTime = 0.01;
	float delay = initialWait + waitTime;
	for (int i = 0; i < numParts; i++)
	{
		// don't go wild and create tons of trigger_load all at once.
		g_Scheduler.SetTimeout("loadPart", delay, i);
		delay += waitTime;
	}
	g_Scheduler.SetTimeout("unlockSaveLoad", delay+0.1);
}

// Weird keyvalue effects:
// skin = disables ladder