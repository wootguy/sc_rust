#include "building_plan"

class PlayerState
{
	EHandle plr;
	CTextMenu@ menu;
	int useState = 0;
	int codeTime = 0; // time left to input lock code
	int numParts = 0; // number of unbroken build parts owned by the player
	array<EHandle> authedLocks; // locked objects the player can use
	EHandle currentLock; // lock currently being interacted with
	
	void initMenu(CBasePlayer@ plr, TextMenuPlayerSlotCallback@ callback)
	{
		CTextMenu temp(@callback);
		@menu = @temp;
	}
	
	void openMenu(CBasePlayer@ plr) 
	{
		if ( menu.Register() == false ) {
			g_Game.AlertMessage( at_console, "Oh dear menu registration failed\n");
		}
		menu.Open(60, 0, plr);
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
	
	// number of points available in the current build zone
	int maxPoints()
	{
		return 100;
	}
	
	// Points exist because of the 500 visibile entity limit. After reserving about 100 for items/players/trees/etc, only
	// 400 are left for players to build with. If this were split up evenly among 32 players, then each player only
	// only get ~12 parts to build with. This is too small to be fun, so we created multiple zones separated by mountains.
	// Each zone can have 500 ents inside, so if players are split up into these zones they will have a lot more freedom.
	//
	// Point rules:
	// 1) 400 max build points per zone. ~100 are reserved for items/players/trees/etc.
	// 2) Max of 4 players per zone, each getting 75 build points
	//    2a) New players can still build, but they are counted as raiders and their parts get deteriorate.
	// 3) Raiders allowed to build 100 things total in enemy zones.
	//    3a) All raiders share this value, so it could be as bad as 3 parts per raider (32 players and 30 are raiders)
	//    3b) Raider parts deteriorate quickly, so new raiders can have points to build with
	//    3c) Raider parts cannot be repaired.
	//    3d) Raider parts deteriorate faster when near the limit.
	//			0-25  = 60 minutes
	//			25-50 = 30 minutes
	//			50-75 = 10 minutes
	//			75-90 = 5 minutes
	//			90-100 = 1 minute
	// 4) Zone residents can share points with each other to build super bases
	//    4a) Unsharing is immediate, but if the sharee has already built something, then the sharer has to wait for
	//        any of the sharee's parts to be destroyed. This can be used to sabotage their base, since they won't have
	//        the points to repair a gaping hole in their wall.
}

class BuildPart
{
	EHandle ent;
	int parent; // part id
	int id;
	
	BuildPart()
	{
		parent = -1;
		id = -1;
	}
	
	BuildPart(CBaseEntity@ ent, int id, int parent)
	{
		ent.pev.team = id;
		this.ent = ent;
		this.id = id;
		this.parent = parent;
	}
	
	string serialize()
	{
		CBaseEntity@ e = ent;
		if (e !is null)
		{
			return e.pev.origin.ToString() + '"' + e.pev.angles.ToString() + '"' + e.pev.colormap + '"' +
				   id + '"' + parent  + '"' + e.pev.button + '"' + e.pev.body + '"' + e.pev.vuser1.ToString() + '"' + 
				   e.pev.vuser2.ToString() + '"' + e.pev.health + '"' + e.pev.classname + '"' + e.pev.model + '"' +
				   e.pev.groupinfo + '"' + e.pev.noise1 + '"' + e.pev.noise2 + '"' + e.pev.noise3;
		}
		else
			return "";
	}
}

dictionary player_states;

array<EHandle> g_tool_cupboards;
array<BuildPart> g_build_parts; // every build structure/item in the map

dictionary g_part_models;
float g_tool_cupboard_radius = 512;
int g_part_id = 0;
bool debug_mode = true;

int MAX_SAVE_DATA_LENGTH = 1015; // Maximum length of a value saved with trigger_save. Discovered through testing

void MapInit()
{
	g_CustomEntityFuncs.RegisterCustomEntity( "weapon_building_plan", "weapon_building_plan" );
	g_ItemRegistry.RegisterWeapon( "weapon_building_plan", "sc_rust", "9mm" );
	
	g_Hooks.RegisterHook( Hooks::Player::PlayerUse, @PlayerUse );
	g_Hooks.RegisterHook( Hooks::Player::ClientSay, @ClientSay );
	
	g_Scheduler.SetInterval("stabilityCheck", 0.0);
	g_Scheduler.SetInterval("inventoryCheck", 0.05);
	
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
	
	// precache breakable object assets
	PrecacheSound("debris/bustcrate1.wav");
	PrecacheSound("debris/bustcrate2.wav");
	PrecacheSound("debris/wood1.wav");
	PrecacheSound("debris/wood2.wav");
	PrecacheSound("debris/wood3.wav");
	g_Game.PrecacheModel( "models/woodgibs.mdl" );
}

void MapActivate()
{
	array<string> part_names = {
		"b_foundation",
		"b_foundation_tri",
		"b_wall",
		"b_doorway",
		"b_window",
		"b_low_wall",
		"b_floor",
		"b_floor_tri",
		"b_roof",
		"b_stairs",
		"b_stairs_l",
		"b_foundation_steps",
		
		"b_roof_wall_left",
		"b_roof_wall_right",
		"b_roof_wall_both",
		
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
		"b_ladder_hatch_door_lock",
	};
	
	for (uint i = 0; i < part_names.length(); i++)
	{
		CBaseEntity@ copy_ent = g_EntityFuncs.FindEntityByTargetname(null, part_names[i]);
		if (copy_ent !is null) {
			g_part_models[string(copy_ent.pev.model)] = part_names[i];
		}
		else
			println("Missing entity: " + part_names[i]);
	} 
}

void debug_stability(Vector start, Vector end)
{
	if (getPartAtPos(end) !is null)
		te_beampoints(start, end, "sprites/laserbeam.spr", 0, 100, 255,1,0,GREEN);
	else
		te_beampoints(start, end, "sprites/laserbeam.spr", 0, 100, 255,1,0,Color(255, 0, 0, 0));
}

bool searchFromFloorPos(Vector pos)
{
	string posKey = "" + int(pos.x + 0.5f) + int(pos.y + 0.5f) + int(pos.z + 0.5f);
	if (visited_pos.exists(posKey))
	{
		numSkip++;
		return false;
	}
	visited_pos[posKey] = true;
	
	// TODO: Tri to square checks

	numChecks++;
	CBaseEntity@ part = getPartAtPos(pos);
	if (part !is null) {
		if (part.pev.colormap == B_FOUNDATION or part.pev.colormap == B_FOUNDATION_TRI) {
			return true;
		}
		pos = part.pev.origin;
		if (part.pev.colormap == B_FLOOR or part.pev.colormap == B_LADDER_HATCH) {
			// search for walls underneath or adjacent floors
			g_EngineFuncs.MakeVectors(part.pev.angles);
			Vector v_forward = g_Engine.v_forward;
			Vector v_right = g_Engine.v_right;
			 
			return searchFromWallPos(pos + v_forward*64 + Vector(0,0,-128)) or
					searchFromWallPos(pos + v_forward*-64 + Vector(0,0,-128)) or
					searchFromWallPos(pos + v_right*64 + Vector(0,0,-128)) or
					searchFromWallPos(pos + v_right*-64 + Vector(0,0,-128)) or
					searchFromFloorPos(pos + v_forward*128) or
					searchFromFloorPos(pos + v_forward*-128) or
					searchFromFloorPos(pos + v_right*128) or
					searchFromFloorPos(pos + v_right*-128) or
					searchFromFloorPos(pos + v_forward*(64+36.95)) or
					searchFromFloorPos(pos + v_forward*-(64+36.95)) or
					searchFromFloorPos(pos + v_right*(64+36.95)) or
					searchFromFloorPos(pos + v_right*-(64+36.95));
		}
		if (part.pev.colormap == B_FLOOR_TRI) {
			// search for walls underneath or adjacent floors
			g_EngineFuncs.MakeVectors(part.pev.angles);
			Vector v_forward = g_Engine.v_forward;
			Vector v_right = g_Engine.v_right;

			return searchFromWallPos(pos + v_right*-32 + v_forward*18.476) or
					searchFromWallPos(pos + v_right*32 + v_forward*18.476) or
					searchFromWallPos(pos + v_forward*-36.95) or
					searchFromWallPos(pos + Vector(0,0,-128) + v_right*-32 + v_forward*18.476) or
					searchFromWallPos(pos + Vector(0,0,-128) + v_right*32 + v_forward*18.476) or
					searchFromWallPos(pos + Vector(0,0,-128) + v_forward*-36.95) or
					searchFromFloorPos(pos + v_forward*-73.9) or
					searchFromFloorPos(pos + v_right*64 + v_forward*36.95) or
					searchFromFloorPos(pos + v_right*-64 + v_forward*36.95) or
					searchFromFloorPos(pos + v_forward*-(36.95+64)) or
					searchFromFloorPos(pos + v_right*87 + v_forward*51) or
					searchFromFloorPos(pos + v_right*-87 + v_forward*51);
		}
	}
	return false;
}

bool searchFromWallPos(Vector pos)
{
	string posKey = "" + int(pos.x + 0.5f) + int(pos.y + 0.5f) + int(pos.z + 0.5f);
	if (visited_pos.exists(posKey))
	{
		numSkip++;
		return false;
	}
	visited_pos[posKey] = true;
	
	numChecks++;
	CBaseEntity@ part = getPartAtPos(pos);
	if (part !is null) {
		pos = part.pev.origin;
		if (socketType(part.pev.colormap) == SOCKET_WALL) {
			// search adjacent floor positions or wall underneath
			g_EngineFuncs.MakeVectors(part.pev.angles);
			Vector v_forward = g_Engine.v_forward;
			Vector v_right = g_Engine.v_right;
			
			// adjacent walls or walls connected by corners
			return searchFromFloorPos(pos + v_forward*64) or 
					searchFromFloorPos(pos - v_forward*64) or
					searchFromWallPos(pos + Vector(0,0,-128)) or
					searchFromWallPos(pos + Vector(0,0,128)) or
					searchFromWallPos(pos + v_right*128) or
					searchFromWallPos(pos + v_right*-128) or
					searchFromWallPos(pos + v_right*64 + v_forward*64) or
					searchFromWallPos(pos + v_right*64 + v_forward*-64) or
					searchFromWallPos(pos + v_right*-64 + v_forward*64) or
					searchFromWallPos(pos + v_right*-64 + v_forward*-64) or
					// triangle checks
					searchFromWallPos(pos + v_right*96 + v_forward*55.43) or
					searchFromWallPos(pos + v_right*96 + v_forward*-55.43) or
					searchFromWallPos(pos + v_right*-96 + v_forward*55.43) or
					searchFromWallPos(pos + v_right*-96 + v_forward*-55.43) or 
					searchFromFloorPos(pos + v_forward*36.95) or 
					searchFromFloorPos(pos + v_forward*-36.95);
		}
	}
	return false;
}

int numSkip = 0;
int numChecks = 0;
dictionary visited_pos; // used to mark positions as already visited when doing the stability search
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
	Vector pos = ent.pev.origin;
	g_EngineFuncs.MakeVectors(ent.pev.angles);
	if (type == B_FOUNDATION or type == B_FLOOR or (type == B_LADDER_HATCH and ent.pev.classname == "func_breakable"))
	{
		EHandle wall1 = getPartAtPos(pos + g_Engine.v_forward*64);
		EHandle wall2 = getPartAtPos(pos + g_Engine.v_forward*-64);
		EHandle wall3 = getPartAtPos(pos + g_Engine.v_right*64);
		EHandle wall4 = getPartAtPos(pos + g_Engine.v_right*-64);
		// steps/floors
		EHandle steps1 = getPartAtPos(pos + g_Engine.v_right*128);
		EHandle steps2 = getPartAtPos(pos + g_Engine.v_right*-128);
		EHandle steps3 = getPartAtPos(pos + g_Engine.v_forward*128);
		EHandle steps4 = getPartAtPos(pos + g_Engine.v_forward*-128);
		// square -> tri
		EHandle tri1 = getPartAtPos(pos + g_Engine.v_right*(64+36.95));
		EHandle tri2 = getPartAtPos(pos + g_Engine.v_right*-(64+36.95));
		EHandle tri3 = getPartAtPos(pos + g_Engine.v_forward*(64+36.95));
		EHandle tri4 = getPartAtPos(pos + g_Engine.v_forward*-(64+36.95));
		EHandle middle = getPartAtPos(pos + Vector(0,0,64));
		
		if (steps1) checkStabilityEnt(steps1);
		if (steps2) checkStabilityEnt(steps2);
		if (steps3) checkStabilityEnt(steps3);
		if (steps4) checkStabilityEnt(steps4);
		if (wall1) checkStabilityEnt(wall1);
		if (wall2) checkStabilityEnt(wall2);
		if (wall3) checkStabilityEnt(wall3);
		if (wall4) checkStabilityEnt(wall4);
		if (middle) checkStabilityEnt(middle);
		if (tri1) checkStabilityEnt(tri1);
		if (tri2) checkStabilityEnt(tri2);
		if (tri3) checkStabilityEnt(tri3);
		if (tri4) checkStabilityEnt(tri4);
	}
	if (type == B_FOUNDATION_TRI or type == B_FLOOR_TRI)
	{
		EHandle wall1 = getPartAtPos(pos + g_Engine.v_right*-32 + g_Engine.v_forward*18.476);
		EHandle wall2 = getPartAtPos(pos + g_Engine.v_right*32 + g_Engine.v_forward*18.476);
		EHandle wall3 = getPartAtPos(pos + g_Engine.v_forward*-36.95);
		
		if (type == B_FOUNDATION_TRI)
		{
			// TODO: the 87/51 numbers are just estimates
			EHandle steps1 = getPartAtPos(pos + g_Engine.v_forward*-(36.95+64));
			EHandle steps2 = getPartAtPos(pos + g_Engine.v_right*87 + g_Engine.v_forward*51);
			EHandle steps3 = getPartAtPos(pos + g_Engine.v_right*-87 + g_Engine.v_forward*51);
			if (steps1) checkStabilityEnt(steps1);
			if (steps2) checkStabilityEnt(steps2);
			if (steps3) checkStabilityEnt(steps3);
		}
		if (type == B_FLOOR_TRI)
		{
			// tri -> tri
			EHandle floor1 = getPartAtPos(pos + g_Engine.v_forward*-73.9);
			EHandle floor2 = getPartAtPos(pos + g_Engine.v_right*64 + g_Engine.v_forward*36.95);
			EHandle floor3 = getPartAtPos(pos + g_Engine.v_right*-64 + g_Engine.v_forward*36.95);
			// tri -> square
			EHandle floor4 = getPartAtPos(pos + g_Engine.v_forward*-(36.95+64));
			EHandle floor5 = getPartAtPos(pos + g_Engine.v_right*87 + g_Engine.v_forward*51);
			EHandle floor6 = getPartAtPos(pos + g_Engine.v_right*-87 + g_Engine.v_forward*51);
			if (floor1) checkStabilityEnt(floor1);
			if (floor2) checkStabilityEnt(floor2);
			if (floor3) checkStabilityEnt(floor3);
			if (floor4) checkStabilityEnt(floor4);
			if (floor5) checkStabilityEnt(floor5);
			if (floor6) checkStabilityEnt(floor6);
		}
		
		if (wall1) checkStabilityEnt(wall1);
		if (wall2) checkStabilityEnt(wall2);
		if (wall3) checkStabilityEnt(wall3);
	}
	if (socket == SOCKET_WALL)
	{
		EHandle wall1 = getPartAtPos(pos + Vector(0,0,128));
		EHandle wall2 = getPartAtPos(pos + Vector(0,0,-128));
		EHandle wall3 = getPartAtPos(pos + g_Engine.v_right*128);
		EHandle wall4 = getPartAtPos(pos + g_Engine.v_right*-128);
		EHandle wall5 = getPartAtPos(pos + g_Engine.v_right*64 + g_Engine.v_forward*64);
		EHandle wall6 = getPartAtPos(pos + g_Engine.v_right*64 + g_Engine.v_forward*-64);
		EHandle wall7 = getPartAtPos(pos + g_Engine.v_right*-64 + g_Engine.v_forward*64);
		EHandle wall8 = getPartAtPos(pos + g_Engine.v_right*-64 + g_Engine.v_forward*-64);
		EHandle floor1 = getPartAtPos(pos + g_Engine.v_forward*64);
		EHandle floor2 = getPartAtPos(pos + g_Engine.v_forward*-64);
		EHandle floor3 = getPartAtPos(pos + g_Engine.v_forward*64 + Vector(0,0,128));
		EHandle floor4 = getPartAtPos(pos + g_Engine.v_forward*-64 + Vector(0,0,128));
		EHandle roof1 = getPartAtPos(pos + g_Engine.v_forward*64 + Vector(0,0,192));
		EHandle roof2 = getPartAtPos(pos - g_Engine.v_forward*64 + Vector(0,0,192));
		
		//triangle connections
		EHandle tri1 = getPartAtPos(pos + g_Engine.v_forward*36.95);
		EHandle tri2 = getPartAtPos(pos + g_Engine.v_forward*-36.95);
		EHandle tri3 = getPartAtPos(pos + g_Engine.v_forward*36.95 + Vector(0,0,128));
		EHandle tri4 = getPartAtPos(pos + g_Engine.v_forward*-36.95 + Vector(0,0,128));
		EHandle wall9 = getPartAtPos(pos + g_Engine.v_right*96 + g_Engine.v_forward*55.43);
		EHandle wall10 = getPartAtPos(pos + g_Engine.v_right*96 + g_Engine.v_forward*-55.43);
		EHandle wall11 = getPartAtPos(pos + g_Engine.v_right*-96 + g_Engine.v_forward*55.43);
		EHandle wall12 = getPartAtPos(pos + g_Engine.v_right*-96 + g_Engine.v_forward*-55.43);
		EHandle floor5 = getPartAtPos(pos + g_Engine.v_forward*36.95);
		EHandle floor6 = getPartAtPos(pos + g_Engine.v_forward*-36.95);

		if (wall1) checkStabilityEnt(wall1);
		if (wall2) checkStabilityEnt(wall2);
		if (wall3) checkStabilityEnt(wall3);
		if (wall4) checkStabilityEnt(wall4);
		if (wall5) checkStabilityEnt(wall5);
		if (wall6) checkStabilityEnt(wall6);
		if (wall7) checkStabilityEnt(wall7);
		if (wall8) checkStabilityEnt(wall8);
		if (wall9) checkStabilityEnt(wall9);
		if (wall10) checkStabilityEnt(wall10);
		if (wall11) checkStabilityEnt(wall11);
		if (wall12) checkStabilityEnt(wall12);
		if (floor1) checkStabilityEnt(floor1);
		if (floor2) checkStabilityEnt(floor2);
		if (floor3) checkStabilityEnt(floor3);
		if (floor4) checkStabilityEnt(floor4);
		if (floor5) checkStabilityEnt(floor5);
		if (floor6) checkStabilityEnt(floor6);
		if (roof1) checkStabilityEnt(roof1);
		if (roof2) checkStabilityEnt(roof2);
		if (tri1) checkStabilityEnt(tri1);
		if (tri2) checkStabilityEnt(tri2);
		if (tri3) checkStabilityEnt(tri3);
		if (tri4) checkStabilityEnt(tri4);
	}
	
	// destroy objects parented to this one
	array<EHandle> children = getPartsByParent(ent.pev.team);
	for (uint i = 0; i < children.length(); i++)
	{
		CBaseEntity@ child = children[i];
		if (child.entindex() == ent.entindex())
			continue;
		child.TakeDamage(child.pev, child.pev, child.pev.health, 0);
		if (child.pev.classname == "func_ladder")
		{
			g_EntityFuncs.Remove(child);
		}
	}
	
	if (type == B_LADDER_HATCH)
	{
		// kill parent
		array<EHandle> parents = getPartsByID(ent.pev.team);
		if (parents.length() > 0)
		{
			CBaseEntity@ parent = parents[0];
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
	PlayerState@ state = getPlayerStateBySteamID(pCaller.pev.noise1, pCaller.pev.noise2);
	if (state !is null)
		state.numParts--;
	propogate_part_destruction(pCaller);
}

void stabilityCheck()
{
	int numIter = 0;
	
	// check for destroyed ents
	for (uint i = 0; i < g_build_parts.length(); i++)
	{
		CBaseEntity@ ent = g_build_parts[i].ent;
		if (ent is null)
		{
			g_build_parts.removeAt(i);
			i--;
		}
		
		if (ent !is null and ent.pev.team != g_build_parts[i].id)
		{
			println("UH OH BAD ID");
			ent.pev.team = g_build_parts[i].id;
		}
	}
	
	if (wait_stable_check > 0)
	{
		wait_stable_check--;
		return;
	}
	
	while(stability_ents.length() > 0)
	{		
		visited_pos.deleteAll();
		CBaseEntity@ src_part = stability_ents[0];
		
		if (src_part is null)
		{
			stability_ents.removeAt(0);
			continue;
		}
		
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
		
		bool supported = false;
		if (type == B_FOUNDATION_STEPS) 
		{
			g_EngineFuncs.MakeVectors(src_part.pev.angles);
			supported = searchFromFloorPos(pos + g_Engine.v_forward*128);
		}
		else if (type == B_ROOF)
		{
			g_EngineFuncs.MakeVectors(src_part.pev.angles);
			supported = searchFromFloorPos(pos + Vector(0,0,-64));
			supported = supported or searchFromWallPos(pos + g_Engine.v_forward*64 + Vector(0,0,-192));	
		}
		else if (socket == SOCKET_WALL)
		{
			supported = searchFromWallPos(pos);
		}
		else if (socket == SOCKET_MIDDLE)
		{
			supported = searchFromFloorPos(pos - Vector(0,0,64));
		}
		else if (type == B_FLOOR or (type == B_LADDER_HATCH and src_part.pev.classname == "func_breakable") or type == B_FLOOR_TRI) 
		{
			supported = searchFromFloorPos(pos);
		}

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
			
			int oldcolormap = ladder.pev.colormap;
			ladder.Use(@ladder, @ladder, USE_TOGGLE, 0.0F);
			ladder.pev.colormap = oldcolormap;
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
		CBaseEntity@ copy_ent = g_EntityFuncs.FindEntityByTargetname(null, newModel);	
		int oldcolormap = obj.pev.colormap;
		g_EntityFuncs.SetModel(obj, copy_ent.pev.model);
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
		CBaseEntity@ copy_ent = g_EntityFuncs.FindEntityByTargetname(null, newModel);	
		int oldcolormap = lock.pev.colormap;
		g_EntityFuncs.SetModel(lock, copy_ent.pev.model);
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
		
		if (phit !is null and (phit.pev.classname == "func_door_rotating" or phit.pev.classname == "func_breakable"))
		{
			int socket = socketType(phit.pev.colormap);
			if (socket == SOCKET_DOORWAY or (phit.pev.colormap == B_LADDER_HATCH and phit.pev.classname == "func_door_rotating"))
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
	
	BuildPart@ part = g_build_parts[idx];
	if (part.ent) {
		CBaseEntity@ ent = part.ent;
		println("Saving part " + ent.pev.team);
		
		// using quotes as delimitters because players can't use them in their names
		string data = part.serialize();
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
}

void loadPart(int idx)
{	
	string data = loadMapKeyvalue("RustPart" + idx);
	if (data.Length() > 0) {
		array<string> values = data.Split('"');
		
		if (values.length() == 16) {
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
			
			dictionary keys;
			keys["origin"] = origin.ToString();
			keys["model"] = model;
			keys["health"] = "health";
			//keys["colormap"] = "" + type;
			keys["material"] = "1";
			keys["target"] = "break_part_script";
			keys["fireonbreak"] = "break_part_script";
			
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
			ent.pev.angles = angles;
			ent.pev.button = button;
			ent.pev.body = body;
			ent.pev.vuser1 = vuser1;
			ent.pev.vuser2 = vuser2;
			ent.pev.groupinfo = groupinfo;
			ent.pev.noise1 = steamid;
			ent.pev.noise2 = netname;
			ent.pev.noise3 = code;
			ent.pev.team = id;
			
			PlayerState@ state = getPlayerStateBySteamID(steamid, netname);
			if (state !is null)
			{
				state.numParts++;
			}
			
			if (classname == "func_door_rotating")
			{
				ent.Use(@ent, @ent, USE_TOGGLE, 0.0F);
			}
			
			g_build_parts.insertLast(BuildPart(ent, id, parent));
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
		g_EntityFuncs.Remove(g_build_parts[i].ent);
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