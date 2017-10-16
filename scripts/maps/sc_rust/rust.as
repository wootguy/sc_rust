#include "building_plan"
#include "hammer"
#include "func_breakable_custom"
#include "func_build_zone"
#include "player_corpse"
#include "../weapon_custom/v3.1/weapon_custom"

// TODO:
// corpse collision without stucking players
// destroy items?
// combine dropped stackables

//
// Game settings
//

int g_settler_reduction = 0; // reduces settlers per zone to increase build points
int g_raider_points = 40; // best if multiple of zone count
bool g_build_point_rounding = true; // rounds build points to a multiple of 10 (may reduce build points)
bool g_disable_ents = false;
bool g_build_anywhere = true; // disables build zones
int g_inventory_size = 20;
int g_max_item_drops = 2; // maximum item drops per player (more drops = less build points)
float g_tool_cupboard_radius = 512;
float g_corpse_time = 60.0f; // time before corpses despawn
float g_item_time = 60.0f; // time before items despawn
float g_revive_time = 5.0f;

//
// End game settings
//


void dummyCallback(CTextMenu@ menu, CBasePlayer@ plr, int page, const CTextMenuItem@ item) {}

class ZoneInfo
{
	int slots;
	int numZones;
	int settlersPerZone;
	int wastedSettlers;
	int partsPerPlayer;
	int reservedParts; // for trees/items/etc.
	int raiderParts; // parts for raiders, shared across all raiders for each zone
	
	ZoneInfo() {}
	
	void init()
	{
		// each player entity counts towards limit, x2 is so each player can drop an item or spawn an effect or something.
		int maxNodes = 64;
		// players + corpses + player item drops + trees/stones/animals
		reservedParts = (g_Engine.maxClients*2) + (g_Engine.maxClients*g_max_item_drops) + maxNodes; // minimum reserved
		
		int maxSettlerParts = MAX_VISIBLE_ENTS - (reservedParts+g_raider_points);
		if (g_build_point_rounding)
			maxSettlerParts = (maxSettlerParts / 10) * 10;
		numZones = g_build_zones.length();
		slots = g_Engine.maxClients + (g_build_zones.length()-1);
		settlersPerZone = Math.max(1, (slots / g_build_zones.length()) - g_settler_reduction);
		wastedSettlers = g_Engine.maxClients - (settlersPerZone*g_build_zones.length());
		partsPerPlayer = maxSettlerParts / settlersPerZone;
			
		
		for (uint i = 0; i < g_build_zones.length(); i++)
			g_build_zones[i].maxSettlers = settlersPerZone;
		
		raiderParts = g_raider_points;
		
		if (g_build_point_rounding)
		{
			// round build points to nearest multiple of 10 so they look nicer
			partsPerPlayer = (partsPerPlayer / 10) * 10;
			reservedParts = MAX_VISIBLE_ENTS - (partsPerPlayer*settlersPerZone + raiderParts); // give remainder to reserved
		}
	}
}

class Team
{
	array<string> members;
	int numParts; // parts built (shared across all members)
	int home_zone; // all members live here
	
	Team() {}
	
	void sendMessage(string msg)
	{
		for (uint i = 0; i < members.size(); i++)
		{
			CBasePlayer@ member = getPlayerByName(null, members[i], true);
			if (member !is null)
				g_PlayerFuncs.SayText(member, msg);
		}
	}
	
	void setHomeZone(int zoneid)
	{
		home_zone = zoneid;
		for (uint i = 0; i < members.size(); i++)
		{
			CBasePlayer@ member = getPlayerByName(null, members[i], true);
			if (member !is null)
			{
				PlayerState@ memberState = getPlayerState(member);
				memberState.home_zone = zoneid;
			}
		}
	}
	
	void breakOverflowParts()
	{
		int maxPoints = members.size()*g_zone_info.partsPerPlayer;
		int overflow = numParts - maxPoints;
		println("TEAM OVERFLOW? " + numParts + " / " + maxPoints);

		if (overflow > 0)
		{
			sendMessage("Your team has too many parts! Recently built parts will be destroyed.");
			
			array<array<EHandle>> teamParts;
			for (uint i = 0; i < members.size(); i++)
			{
				CBasePlayer@ member = getPlayerByName(null, members[i], true);
				teamParts.insertLast(getPartsByOwner(member));
			}
			
			// break team member parts, spread out equally between each member
			int destroyed = 0;
			uint idx = 1;
			float delay = 0.0f;
			while (destroyed < overflow)
			{
				for (uint i = 0; i < teamParts.size(); i++)
				{
					if (idx < teamParts[i].size())
					{
						g_Scheduler.SetTimeout("breakPart", delay, teamParts[i][teamParts[i].size()-idx]);
						delay += 0.1f;
						destroyed++;
					}
				}
				if (idx++ > 500)
				{
					println("Failed to delete overflow parts for team!");
					break;
				}
			}
		}
	}
}

class PlayerState
{
	EHandle plr;
	CTextMenu@ menu;
	int useState = 0;
	int codeTime = 0; // time left to input lock code
	int droppedItems = 0; // number of item drops owned by the player
	dictionary zoneParts; // number of unbroken build parts owned by the player (per zone)
	int home_zone = -1; // zone the player is allowed to settle in (-1 = nomad)
	array<EHandle> authedLocks; // locked objects the player can use
	array<EHandle> droppedWeapons;
	Team@ team = null;
	EHandle currentLock; // lock currently being interacted with
	EHandle currentChest; // current corpse/chest being interacted with
	bool reviving = false;
	float reviveStart = 0; // time this player started reviving someone
	float lastBreakAll = 0; // last time the player used the breakall command
	dictionary teamRequests; // outgoing requests for team members
	
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

	void addPart(CBaseEntity@ part, int zoneid)
	{
		int count = 0;
		if (zoneParts.exists(zoneid))
			zoneParts.get(zoneid, count);
		count++;
		zoneParts[zoneid] = count;
		
		part.pev.noise1 = g_EngineFuncs.GetPlayerAuthId( plr.GetEntity().edict() );
		part.pev.noise2 = plr.GetEntity().pev.netname;
		
		if (team !is null and zoneid == team.home_zone)
			team.numParts++;
	}
	
	void partDestroyed(CBaseEntity@ bpart)
	{
		if (bpart is null)
			return;
			
		func_breakable_custom@ part = cast<func_breakable_custom@>(CastToScriptClass(bpart));

		if (team !is null and part.zoneid == home_zone)
			team.numParts--;
		
		if (part.zoneid != home_zone)
		{
			BuildZone@ zone = getBuildZone(part.zoneid);
			zone.numRaiderParts--;
		}
		
		if (zoneParts.exists(part.zoneid))
		{
			int count;
			zoneParts.get(part.zoneid, count);
			count--;
			zoneParts[part.zoneid] = count;
			
			if (part.zoneid == home_zone)
			{
				checkHomeless();
			}
		}
	}
	
	int breakParts(int count)
	{
		CBasePlayer@ p = cast<CBasePlayer@>(plr.GetEntity());
		array<EHandle> parts = getPartsByOwner(p);
		float delay = 0.1f;
		int broken = 0;
		for (int i = int(parts.size())-1; i >= 0; i--)
		{
			func_breakable_custom@ bpart = castToPart(parts[i]);
			if (bpart.zoneid == home_zone)
			{
				g_Scheduler.SetTimeout("breakPart", delay, parts[i]);
				delay += 0.1f;
				if (++broken >= count)
					return broken;
			}
		}
		return broken;
	}
	
	bool checkHomeless()
	{
		if (home_zone == -1)
			return true;
		int count = 0;
		zoneParts.get(home_zone, count);
		
		if (team !is null)
			count = team.numParts;
		
		if (count == 0)
		{
			BuildZone@ zone = getBuildZone(home_zone);
			CBasePlayer@ p = cast<CBasePlayer@>(plr.GetEntity());
			string msg = "Your base in zone " + zone.id + " was completely destroyed. You can rebuild in any zone.\n";
			if (team !is null)
			{
				team.sendMessage(msg);
				team.setHomeZone(-1);
				zone.numSettlers -= team.members.size();
			}
			else
			{
				g_PlayerFuncs.SayText(p, msg);
				zone.numSettlers--;
			}	
			home_zone = -1;
			return true;
		}
		return false;
	}
	
	void updateDroppedWeapons()
	{
		for (uint i = 0; i < droppedWeapons.size(); i++)
		{
			if (!droppedWeapons[i].IsValid())
			{
				droppedWeapons.removeAt(i);
				i--;
				droppedItems--;
			}
		}
	}
	
	void addPartCount(int num, int zoneid)
	{
		int count = 0;
		if (zoneParts.exists(zoneid))
			zoneParts.get(zoneid, count);
		count += num;
		zoneParts[zoneid] = count;
	}
	
	int getNumParts(int zoneid)
	{
		if (zoneid == -1337)
		{
			// get ALL owned parts
			array<string>@ zoneKeys = zoneParts.getKeys();
			int total = 0;
			for (uint i = 0; i < zoneKeys.length(); i++)
			{
				int count = 0;
				zoneParts.get(zoneKeys[i], count);
				total += count;
			}
			return total;
		}
	
		if (zoneid != home_zone)
		{
			// use shared part count
			BuildZone@ zone = getBuildZone(zoneid);
			if (zone !is null)
				return zone.numRaiderParts;
			else
				return 0;
		}
		
		if (team !is null and team.members.size() > 1)
		{
			return team.numParts;
		}
		int count = 0;
		if (zoneParts.exists(zoneid))
			zoneParts.get(zoneid, count);	
		return count;
	}
	
	// number of points available in the current build zone
	int maxPoints(int zoneid)
	{
		if (zoneid == -1)
			return 0;
		if (zoneid != home_zone)
			return g_zone_info.raiderParts;
			
		return team !is null ? g_zone_info.partsPerPlayer*team.members.size() : g_zone_info.partsPerPlayer;
	}
	
	// Points exist because of the 500 visibile entity limit. After reserving about 100 for items/players/trees/etc, only
	// 400 are left for players to build with. If this were split up evenly among 32 players, then each player only
	// only get ~12 parts to build with. This is too small to be fun, so I created multiple zones separated by mountains.
	// Each zone can have 500 ents inside, so if players are split up into these zones they will have a lot more freedom.
	//
	// Point rules (for 32 players):
	// 1) 400 max build points per zone. ~100 are reserved for items/players/trees/etc.
	// 2) Max of 6 players per zone, so worst case is 50 build points for each player
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
array<Team> g_teams;
array<EHandle> g_item_drops; // items that are currently sitting around
array<EHandle> g_weapon_drops; // these disappear when they're picked up
array<EHandle> g_corpses; // these disappear when they're picked up
Vector g_dead_zone; // where dead players go until they respawn
array<string> g_upgrade_suffixes = {
	"_twig",
	"_wood",
	"_stone",
	"_metal",
	"_armor"
};

dictionary g_partname_to_model; // maps models to part names
dictionary g_model_to_partname; // maps part names to models
dictionary g_pretty_part_names;

int g_part_id = 0;
//bool debug_mode = false;
ZoneInfo g_zone_info;

int MAX_SAVE_DATA_LENGTH = 1015; // Maximum length of a value saved with trigger_save. Discovered through testing

void MapInit()
{
	g_CustomEntityFuncs.RegisterCustomEntity( "weapon_building_plan", "weapon_building_plan" );
	g_ItemRegistry.RegisterWeapon( "weapon_building_plan", "sc_rust", "" );
	
	g_CustomEntityFuncs.RegisterCustomEntity( "weapon_hammer", "weapon_hammer" );
	g_ItemRegistry.RegisterWeapon( "weapon_hammer", "sc_rust", "" );
	
	g_CustomEntityFuncs.RegisterCustomEntity( "func_breakable_custom", "func_breakable_custom" );
	g_CustomEntityFuncs.RegisterCustomEntity( "func_build_zone", "func_build_zone" );
	g_CustomEntityFuncs.RegisterCustomEntity( "player_corpse", "player_corpse" );
	
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
	PrecacheSound("sc_rust/stone_tree.ogg");
	
	// precache breakable object assets
	PrecacheSound("debris/bustcrate1.wav");
	PrecacheSound("debris/bustcrate2.wav");
	PrecacheSound("debris/wood1.wav");
	PrecacheSound("debris/wood2.wav");
	PrecacheSound("debris/wood3.wav");
	g_Game.PrecacheModel( "models/woodgibs.mdl" );
	g_Game.PrecacheModel( "models/sc_rust/pine_tree.mdl" );
	g_Game.PrecacheModel( "models/sc_rust/rock.mdl" );
	g_Game.PrecacheModel( "models/skeleton.mdl" );
	
	for (uint i = 0; i < g_material_damage_sounds.length(); i++)
		for (uint k = 0; k < g_material_damage_sounds[i].length(); k++)
			PrecacheSound(g_material_damage_sounds[i][k]);
	for (uint i = 0; i < g_material_break_sounds.length(); i++)
		for (uint k = 0; k < g_material_break_sounds[i].length(); k++)
			PrecacheSound(g_material_break_sounds[i][k]);
			
	WeaponCustomMapInit();
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
		"b_small_chest",
		"b_large_chest",
		
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
		
		"e_tree",
		"e_rock"
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
	
	g_zone_info.init();
	
	CBaseEntity@ dead_zone = g_EntityFuncs.FindEntityByTargetname(null, "rust_dead_zone");
	if (dead_zone !is null)
	{
		g_dead_zone = dead_zone.pev.origin;
		g_EntityFuncs.Remove(dead_zone);
	} 
	else 
	{
		println("ERROR: rust_dead_zone entity is missing. Dead players will be able to spy on people.");
	}
	
	WeaponCustomMapActivate();
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
	if (!ent)
		return;
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

void delay_remove(EHandle ent)
{
	if (ent)
		g_EntityFuncs.Remove(ent);
}

void undo_drop(EHandle h_item, EHandle h_plr)
{
	if (h_item.IsValid() and h_plr.IsValid())
	{
		CBaseEntity@ item = h_item.GetEntity();
		CBasePlayer@ plr = cast<CBasePlayer@>(h_plr.GetEntity());
		int amt = item.pev.button > 0 ? item.pev.button : 1;
		giveItem(plr, item.pev.colormap-1, amt, false);
		g_EntityFuncs.Remove(item);
	}
}

void player_respawn(CBaseEntity@ pActivator, CBaseEntity@ pCaller, USE_TYPE useType, float flValue)
{
	for (uint i = 0; i < g_corpses.size(); i++)
	{
		if (!g_corpses[i])
			continue;
			
		player_corpse@ corpse = cast<player_corpse@>(CastToScriptClass(g_corpses[i]));
		if (corpse.owner.IsValid() and corpse.owner.GetEntity().entindex() == pCaller.entindex())
		{
			corpse.Activate();
		}
	}
}

void player_killed(CBaseEntity@ pActivator, CBaseEntity@ pCaller, USE_TYPE useType, float flValue)
{
	if (!pCaller.IsPlayer())
		return;
	CBasePlayer@ plr = cast<CBasePlayer@>(pCaller);

	// always die on back (because I can't make player-model-based corpse work properly)

	dictionary keys;
	keys["model"] = "models/skeleton.mdl";
	keys["origin"] = (plr.pev.origin + Vector(0,0,-36)).ToString();
	keys["angles"] = Vector(0, plr.pev.angles.y, 0).ToString();
	keys["netname"] = string(plr.pev.netname);
	CBaseEntity@ ent = g_EntityFuncs.CreateEntity("player_corpse", keys, true);
	
	player_corpse@ corpse = cast<player_corpse@>(CastToScriptClass(ent));
	corpse.owner = plr;
	
	g_corpses.insertLast(EHandle(ent));
}

void item_dropped(CBaseEntity@ pActivator, CBaseEntity@ pCaller, USE_TYPE useType, float flValue)
{
	if (pCaller.pev.classname != "item_inventory" and !pActivator.IsPlayer())
		return;
		
	CBasePlayer@ plr = cast<CBasePlayer@>(pActivator);
	CItemInventory@ item = cast<CItemInventory@>(pCaller);
	if (item.pev.renderfx == -9999)
		return; // this was just a stackable item that was replaced with a larger stack, ignore it
	
	PlayerState@ state = getPlayerState(plr);
	if (state.droppedItems >= g_max_item_drops)
	{
		g_PlayerFuncs.PrintKeyBindingString(plr, "Can't drop more than " + g_max_item_drops + " item" + (g_max_item_drops > 1 ? "s" : ""));
		// timeout prevents repeating item_dropped over and over (SC bug)
		g_Scheduler.SetTimeout("undo_drop", 0.0f, EHandle(item), EHandle(plr)); 
		return;
	}
	
	item.pev.teleport_time = g_Engine.time + g_item_time;
	
	state.droppedItems++;
	item.pev.noise1 = getPlayerUniqueId(plr);
	
	g_item_drops.insertLast(EHandle(item));
	item.pev.team = 0; // trigger item_collect callback
}

void remove_item_from_drops(CBaseEntity@ item)
{
	for (uint i = 0; i < g_item_drops.size(); i++)
	{
		if (!g_item_drops[i].IsValid() or g_item_drops[i].GetEntity().entindex() == item.entindex())
		{
			CBasePlayer@ owner = getPlayerByName(null, g_item_drops[i].GetEntity().pev.noise1, true);
			if (owner !is null)
				getPlayerState(owner).droppedItems--;
			
			g_item_drops.removeAt(i);
			i--;
			break;
		}
	}
}

void item_collected(CBaseEntity@ pActivator, CBaseEntity@ pCaller, USE_TYPE useType, float flValue)
{
	if (pCaller.pev.classname != "item_inventory" or !pActivator.IsPlayer())
		return;
		
	CBasePlayer@ plr = cast<CBasePlayer@>(pActivator);
	int type = pCaller.pev.colormap-1;
	int amount = pCaller.pev.button;
	if (amount <= 0)
		amount = 1;
	
	if (pCaller.pev.team != 1)
	{
		g_PlayerFuncs.PrintKeyBindingString(plr, "" + amount + "x " + g_items[type].title);
		if (g_items[type].stackSize > 1)
		{
			Vector oldOri = pCaller.pev.origin;
			string oldOwner = pCaller.pev.noise1;
			int barf = combineItemStacks(plr, type);
			if (barf > 0)
			{
				CBaseEntity@ item = spawnItem(oldOri, type, barf);
				item.pev.noise1 = oldOwner;
				g_item_drops.insertLast(EHandle(item));
				println("Couldn't hold " + barf + " of that");
				return;
			}
		}
			
		remove_item_from_drops(pCaller);
	}
}

void item_cant_collect(CBaseEntity@ pActivator, CBaseEntity@ pCaller, USE_TYPE useType, float flValue)
{
	if (!pActivator.IsPlayer())
		return;
	g_PlayerFuncs.PrintKeyBindingString(cast<CBasePlayer@>(pActivator), "Your inventory is full");
}

void part_broken(CBaseEntity@ pActivator, CBaseEntity@ pCaller, USE_TYPE useType, float flValue)
{
	if (pCaller.pev.effects & EF_NODRAW == 0)
	{
		PlayerState@ state = getPlayerStateBySteamID(pCaller.pev.noise1, pCaller.pev.noise2);
		if (state !is null)
			state.partDestroyed(pCaller);
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

		//println("Stability for part " + src_part.pev.team + " finished in " + numChecks + " checks (" + numSkip + " skipped). Result is " + supported);
		
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

int combineItemStacks(CBasePlayer@ plr, int addedType)
{
	InventoryList@ inv = plr.get_m_pInventory();
	
	dictionary totals;
	while(inv !is null)
	{
		CItemInventory@ item = cast<CItemInventory@>(inv.hItem.GetEntity());
		@inv = inv.pNext;
		if (item !is null)
		{
			int type = item.pev.colormap-1;
			if (g_items[type].stackSize > 1 and type >= 0)
			{
				int newTotal = 0;
				if (totals.exists(type))
					totals.get(type, newTotal);
				newTotal += item.pev.button;
				totals[type] = newTotal;
				
				item.pev.renderfx = -9999;
				g_EntityFuncs.Remove(item);
			}
		}
	}
	
	int spaceLeft = getInventorySpace(plr);
	array<string>@ totalKeys = totals.getKeys();
	
	for (uint i = 0; i < totalKeys.length(); i++)
	{
		if (atoi(totalKeys[i]) == addedType)
		{
			// newly added item should be stacked last in case there is overflow
			// e.g. if you collect too much wood, you shouldn't drop your stack of stone
			totalKeys.removeAt(i);
			totalKeys.insertLast(addedType);
			break;
		}
	}
	
	for (uint i = 0; i < totalKeys.length(); i++)
	{
		int type = atoi(totalKeys[i]);
		int total = 0;
		totals.get(totalKeys[i], total);
		
		while (total > 0)
		{
			if (spaceLeft-- > 0)
				giveItem(plr, atoi(totalKeys[i]), Math.min(total, g_items[type].stackSize), false, false);
			else
			{
				// TODO: What if this type wasn't the item given? (given stone, but drop extra wood)
				g_PlayerFuncs.PrintKeyBindingString(plr, "Your inventory is full");
				return total;
			}
			total -= g_items[type].stackSize;
		}
	}
	
	return 0;
}

CBaseEntity@ spawnItem(Vector origin, int type, int amt)
{
	dictionary keys;
	keys["origin"] = origin.ToString();
	keys["model"] = "models/w_weaponbox.mdl";
	keys["weight"] = "0";
	keys["spawnflags"] = "" + (256 + 512 + 128);
	keys["solid"] = "0";
	keys["return_timelimit"] = "-1";
	keys["holder_can_drop"] = "1";
	keys["carried_hidden"] = "1";
	keys["target_on_drop"] = "item_dropped";
	keys["target_on_collect"] = "item_collected";
	keys["target_cant_collect"] = "item_cant_collect";
	
	if (type < 0 or type > ITEM_TYPES)
	{
		println("spawnItem: bad type " + type);
		return null;
	}
	
	keys["netname"] = g_items[type].title; // because m_szItemName doesn't work...
	keys["colormap"] = "" + (type+1); // +1 so that normal items don't appear as my custom ones
	keys["team"] = "0"; // so we ignore this in the item_collected callback
	
	keys["display_name"] = g_items[type].title;
	keys["description"] =  g_items[type].desc;
	
	if (g_items[type].stackSize == 1)
	{
		CBaseEntity@ lastSpawn = null;
		for (int i = 0; i < amt; i++)
		{
			@lastSpawn = g_EntityFuncs.CreateEntity("item_inventory", keys, true);
			lastSpawn.pev.origin = origin;
		}
		return lastSpawn;
	}
	else
	{
		keys["button"] = "" + amt;
		keys["display_name"] = g_items[type].title + "  (" + prettyNumber(amt) + ")";
		
		return g_EntityFuncs.CreateEntity("item_inventory", keys, true);
	}
}

// returns # of items that couldn't be stored (e.g. could stack 100 more but was given 300: return 200)
int giveItem(CBasePlayer@ plr, int type, int amt, bool drop=false, bool combineStacks=true)
{
	dictionary keys;
	keys["origin"] = plr.pev.origin.ToString();
	keys["model"] = "models/w_weaponbox.mdl";
	keys["weight"] = "0";
	keys["spawnflags"] = "" + (256 + 512 + 128);
	keys["solid"] = "0";
	keys["return_timelimit"] = "-1";
	keys["holder_can_drop"] = "1";
	keys["carried_hidden"] = "1";
	keys["target_on_drop"] = "item_dropped";
	keys["target_on_collect"] = "item_collected";
	keys["target_cant_collect"] = "item_cant_collect";
	keys["holder_keep_on_death"] = "1";
	keys["holder_keep_on_respawn"] = "1";
	
	plr.SetItemPickupTimes(0);
	
	if (type < 0 or type > ITEM_TYPES)
	{
		println("giveItem: bad type");
		return amt;
	}
	
	keys["button"] = "1"; // will be giving at least 1x of something
	keys["netname"] = g_items[type].title; // because m_szItemName doesn't work...
	keys["colormap"] = "" + (type+1); // +1 so that normal items don't appear as my custom ones
	keys["team"] = drop ? "0" : "1"; // so we ignore this in the item_collected callback
	
	keys["display_name"] = g_items[type].title;
	keys["description"] =  g_items[type].desc;
	
	//if (showText)
	//	g_PlayerFuncs.PrintKeyBindingString(plr, "" + amt + "x " + g_items[type].title);
	
	int dropSpeed = Math.RandomLong(250, 400);
	int spaceLeft = getInventorySpace(plr);
	
	if (g_items[type].stackSize == 1)
	{
		if (!g_items[type].isWeapon)
		{
			for (int i = 0; i < amt; i++)
			{
				if (spaceLeft-- <= 0 and !drop)
				{
					g_PlayerFuncs.PrintKeyBindingString(plr, "Your inventory is full");
					return amt - i;
				}
				CBaseEntity@ ent = g_EntityFuncs.CreateEntity("item_inventory", keys, true);
				if (drop)
				{
					g_EngineFuncs.MakeVectors(plr.pev.angles);
					ent.pev.velocity = g_Engine.v_forward*dropSpeed;
					ent.pev.origin = plr.pev.origin;
				}
				else
					ent.Use(@plr, @plr, USE_ON, 0.0F);
			}
		}
		else
		{
			keys["button"] = "" + amt; // now button = ammo in clip
			if (spaceLeft <= 0 and !drop)
			{
				g_PlayerFuncs.PrintKeyBindingString(plr, "Your inventory is full");
				return 1;
			}
			CBaseEntity@ ent = g_EntityFuncs.CreateEntity("item_inventory", keys, true);
			if (drop)
			{
				g_EngineFuncs.MakeVectors(plr.pev.angles);
				ent.pev.origin = plr.pev.origin;
				ent.pev.velocity = g_Engine.v_forward*dropSpeed;
			}
			else
				ent.Use(@plr, @plr, USE_ON, 0.0F);
		}
	}
	else
	{
		keys["button"] = "" + amt;
		keys["display_name"] = g_items[type].title + "  (" + prettyNumber(amt) + ")";
		
		CBaseEntity@ ent = g_EntityFuncs.CreateEntity("item_inventory", keys, true);
		if (drop)
		{
			g_EngineFuncs.MakeVectors(Vector(0, plr.pev.angles.y, 0));
			ent.pev.velocity = g_Engine.v_forward*dropSpeed;
			item_dropped(plr, ent, USE_TOGGLE, 0);
		}
		else
			ent.Use(@plr, @plr, USE_ON, 0.0F);
		
		if (combineStacks)
			return combineItemStacks(plr, type);
	}
	return 0;
}

void craftMenuCallback(CTextMenu@ menu, CBasePlayer@ plr, int page, const CTextMenuItem@ item)
{
	if (item is null)
		return;
	string action;
	item.m_pUserData.retrieve(action);
	PlayerState@ state = getPlayerState(plr);
	
	if (int(action.Find("-menu")) != -1)
	{
		g_Scheduler.SetTimeout("openPlayerMenu", 0, @plr, action);
	}
	else if (action.Find("unequip-") == 0)
	{
		string name = action.SubString(8);
		
		CBasePlayerItem@ wep = plr.HasNamedPlayerItem(name);
		if (wep !is null)
		{
			CBasePlayerWeapon@ cwep = cast<CBasePlayerWeapon@>(wep);
			
			Item@ invItem = getItemByClassname(name);
			if (invItem !is null)
			{
				if (giveItem(plr, invItem.type, cwep.m_iClip) == 0)
				{					
					plr.RemovePlayerItem(wep);
					g_PlayerFuncs.PrintKeyBindingString(plr, invItem.title + " was moved your inventory");
				}
			}
			else
				println("Unknown weapon: " + name);		
		}
		else
		{
			int ammoIdx = g_PlayerFuncs.GetAmmoIndex(name);
			int ammo = plr.m_rgAmmo(ammoIdx);
			if (ammo > 0)
			{
				Item@ ammoItem = getItemByClassname(name);
				
				if (ammoItem !is null)
				{
					int ammoLeft = giveItem(plr, ammoItem.type, ammo);
					plr.m_rgAmmo(ammoIdx, ammoLeft);
				}
				else
					println("Unknown ammo: " + name);
			}
		}

		g_Scheduler.SetTimeout("openPlayerMenu", 0, @plr, "unequip-menu");
	}
	else if (action.Find("equip-") == 0)
	{
		int itemId = atoi(action.SubString(6));
		Item@ invItem = g_items[itemId-1];
		
		if (invItem !is null)
		{
			if (invItem.isWeapon)
			{
				if (plr.HasNamedPlayerItem(invItem.classname) is null)
				{
					InventoryList@ inv = plr.get_m_pInventory();
					int clip = 0;
					while (inv !is null)
					{
						CItemInventory@ wep = cast<CItemInventory@>(inv.hItem.GetEntity());
						@inv = inv.pNext;
						if (wep.pev.colormap == itemId)
						{
							clip = wep.pev.button;
							wep.pev.renderfx = -9999;
							g_Scheduler.SetTimeout("delay_remove", 0, EHandle(wep));
							break;
						}
					}
					
					plr.SetItemPickupTimes(0);
					plr.GiveNamedItem(invItem.classname, 0);
					CBasePlayerItem@ givenItem = plr.HasNamedPlayerItem(invItem.classname);
					if (givenItem !is null)
					{
						CBasePlayerWeapon@ givenWep = cast<CBasePlayerWeapon@>(givenItem);
						givenWep.m_iClip = clip;
					}
				}
				else
					g_PlayerFuncs.PrintKeyBindingString(plr, "You already have one of these equipped");
			}				
			else if (invItem.isAmmo)
			{
				int invAmmo = getItemCount(plr, invItem.type);
				int ammoIdx = g_PlayerFuncs.GetAmmoIndex(invItem.classname);
				int beforeAmmo = plr.m_rgAmmo(ammoIdx);
				plr.GiveAmmo(invAmmo, invItem.classname, 9999); // TODO: set proper max?
				int amtGiven = plr.m_rgAmmo(ammoIdx) - beforeAmmo;
				
				giveItem(plr, invItem.type, -amtGiven);
				
				if (amtGiven > 0)
					g_SoundSystem.PlaySound(plr.edict(), CHAN_ITEM, "items/9mmclip1.wav", 1.0f, 1.0f, 0, 100);
				else
					g_PlayerFuncs.PrintKeyBindingString(plr, "Already equipped with max ammo");
			}
		}
		else
			println("Invalid item ID to equip: " + itemId);
		
		g_Scheduler.SetTimeout("openPlayerMenu", 0.05, @plr, "equip-menu");
	}
	else if (action.Find("unstack-") == 0)
	{
		g_Scheduler.SetTimeout("openPlayerMenu", 0, @plr, action);
	}
	else if (action.Find("drop-") == 0)
	{
		int dropAmt = atoi(action.SubString(5,6));
		int dropType = atoi(action.SubString(12));
		
		giveItem(plr, dropType-1, -dropAmt); // decrease stack size
		giveItem(plr, dropType-1, dropAmt, true); // drop selected amount
		
		g_Scheduler.SetTimeout("openPlayerMenu", 0, @plr, "unstack-" + dropType);
	}
	else
	{
		if (action == "wood-door") giveItem(@plr, I_WOOD_DOOR, 1);
		if (action == "tool-cupboard") giveItem(@plr, I_TOOL_CUPBOARD, 1);
		g_Scheduler.SetTimeout("openPlayerMenu", 0, @plr, "");
	}
	
	menu.Unregister();
	@menu = null;
}

void openPlayerMenu(CBasePlayer@ plr, string subMenu)
{
	PlayerState@ state = getPlayerState(plr);
	state.initMenu(plr, craftMenuCallback);
	
	if (subMenu == "build-menu") 
	{
		state.menu.SetTitle("Actions -> Craft -> Build:\n");
		state.menu.AddItem("Wood Door", any("wood-door"));
		state.menu.AddItem("Metal Door", any("metal-door"));
		state.menu.AddItem("Wood Shutters", any("wood-shutters"));
		state.menu.AddItem("Wood Window Bars", any("wood-window-bars"));
		state.menu.AddItem("Metal Window Bars", any("metal-window-bars"));
		state.menu.AddItem("Code Lock", any("code-lock"));
		state.menu.AddItem("Tool Cupboard", any("tool-cupboard"));
		state.menu.AddItem("High External Wood Wall", any("wood-wall"));
		state.menu.AddItem("High External Stone Wall", any("stone-wall"));
		state.menu.AddItem("Ladder", any("ladder"));
		state.menu.AddItem("Ladder Hatch", any("ladder-hatch"));
	}
	else if (subMenu == "item-menu") 
	{
		state.menu.SetTitle("Actions -> Craft -> Items:\n");
		state.menu.AddItem("Chest", any("small-chest"));
		state.menu.AddItem("Large Chest", any("large-chest"));
		state.menu.AddItem("Camp Fire", any("fire"));
		state.menu.AddItem("Furnace", any("furnace"));
		state.menu.AddItem("Large Furnace", any("large-furnace"));
		state.menu.AddItem("Stash", any("stash"));
		state.menu.AddItem("Sleeping Bag", any("sleeping-bag"));
	}
	else if (subMenu == "armor-menu") 
	{
		state.menu.SetTitle("Actions -> Craft -> Armor:\n");
		state.menu.AddItem("Wood Helmet", any("wood-helmet"));
		state.menu.AddItem("Wood Chestplate", any("wood-chestplate"));
		state.menu.AddItem("Wood Pants", any("wood-pants"));
		state.menu.AddItem("Metal Helmet", any("metal-helmet"));
		state.menu.AddItem("Metal Chestplate", any("metal-chestplate"));
		state.menu.AddItem("Metal Pants", any("metal-pants"));
	}
	else if (subMenu == "tool-menu")
	{
		state.menu.SetTitle("Actions -> Craft -> Tools:\n");
		state.menu.AddItem("Rock", any("rock"));
		state.menu.AddItem("Torch", any("torch"));
		state.menu.AddItem("Building Plan", any("build-plan"));
		state.menu.AddItem("Hammer", any("hammer"));
		state.menu.AddItem("Stone Hatchet", any("stone-axe"));
		state.menu.AddItem("Stone Pick Axe", any("stone-pick"));
		state.menu.AddItem("Metal Hatchet", any("metal-axe"));
		state.menu.AddItem("Metal Pick Axe", any("metal-pick"));
	}
	else if (subMenu == "medical-menu")
	{
		state.menu.SetTitle("Actions -> Craft -> Medical:\n");
		state.menu.AddItem("Bandage", any("bandage"));
		state.menu.AddItem("Small Medkit", any("small-medkit"));
		state.menu.AddItem("Large Medkit", any("large-medkit"));
		state.menu.AddItem("Acoustic Guitar", any("guitar"));
	}
	else if (subMenu == "weapon-menu")
	{
		state.menu.SetTitle("Actions -> Craft -> Weapons:\n");
		state.menu.AddItem("Crowbar", any("crowbar"));
		state.menu.AddItem("Wrench", any("wrench"));
		state.menu.AddItem("Bow", any("bow"));
		state.menu.AddItem("Pistol", any("pistol"));
		state.menu.AddItem("Shotgun", any("shotgun"));
		state.menu.AddItem("Flamethrower", any("flamethrower"));
		state.menu.AddItem("Sniper Rifle", any("sniper"));
		state.menu.AddItem("RPG", any("rpg"));
		state.menu.AddItem("Uzi", any("uzi"));
		state.menu.AddItem("Saw", any("saw"));
		state.menu.AddItem("Grenade", any("grenade"));
		state.menu.AddItem("Satchel charge", any("satchel"));
		state.menu.AddItem("C4", any("c4"));
	}
	else if (subMenu == "ammo-menu")
	{
		state.menu.SetTitle("Actions -> Craft -> Ammo:\n");
		state.menu.AddItem("Arrow", any("arrow"));
		state.menu.AddItem("9mm", any("9mm"));
		state.menu.AddItem("556", any("556"));
		state.menu.AddItem("Buckshot", any("buckshot"));
		state.menu.AddItem("Rocket", any("rocket"));
	}
	else if (subMenu == "craft-menu")
	{
		state.menu.SetTitle("Actions -> Craft:\n");
		state.menu.AddItem("Build", any("build-menu"));
		state.menu.AddItem("Items", any("item-menu"));
		state.menu.AddItem("Armor", any("armor-menu"));
		state.menu.AddItem("Tools", any("tool-menu"));
		state.menu.AddItem("Medical", any("medical-menu"));
		state.menu.AddItem("Weapons", any("weapon-menu"));
		state.menu.AddItem("Ammo", any("ammo-menu"));
	}
	else if (subMenu == "equip-menu")
	{
		state.menu.SetTitle("Actions -> Equip:\n");
		
		int count = 0;
		InventoryList@ inv = plr.get_m_pInventory();
		dictionary listed;
		while(inv !is null)
		{
			CItemInventory@ item = cast<CItemInventory@>(inv.hItem.GetEntity());
			if (item !is null and item.pev.colormap > 0)
			{
				Item@ wep = g_items[item.pev.colormap-1];
				if (wep !is null and (wep.isWeapon or wep.isAmmo) and !listed.exists(wep.classname))
				{
					int amt = wep.isAmmo ? getItemCount(plr, wep.type) : 1;
					state.menu.AddItem(wep.title + (wep.isAmmo ? " (" + amt + ")" : ""), any("equip-" + item.pev.colormap));
					listed[wep.classname] = 1;
					count++;
				}
			}
			@inv = inv.pNext;
		}
		
		if (count == 0)
		{
			g_PlayerFuncs.PrintKeyBindingString(plr, "You don't have any equipable items");
			openPlayerMenu(plr, "");
			return;
		}
	}
	else if (subMenu == "unequip-menu")
	{
		state.menu.SetTitle("Actions -> Unequip:\n");
		int count = 0;
		for (uint i = 0; i < MAX_ITEM_TYPES; i++)
		{
			CBasePlayerItem@ item = plr.m_rgpPlayerItems(i);
			while (item !is null)
			{
				Item@ invItem = getItemByClassname(item.pev.classname);
				string displayName = invItem !is null ? invItem.title : string(item.pev.classname);
				state.menu.AddItem(displayName, any("unequip-" + item.pev.classname));
				@item = cast<CBasePlayerItem@>(item.m_hNextItem.GetEntity());		
				count++;
			}
		}
		
		for (uint i = 0; i < g_ammo_types.size(); i++)
		{
			int ammo = plr.m_rgAmmo(g_PlayerFuncs.GetAmmoIndex(g_ammo_types[i]));
			if (ammo > 0)
			{
				Item@ item = getItemByClassname(g_ammo_types[i]);
				string name = item !is null ? item.title : g_ammo_types[i];
				state.menu.AddItem(name + " (" + ammo + ")", any("unequip-" + g_ammo_types[i]));
				count++;
			}
		}
		
		if (count == 0)
		{
			g_PlayerFuncs.PrintKeyBindingString(plr, "You don't have any items equipped");
			openPlayerMenu(plr, "");
			return;
		}
	}
	else if (subMenu == "drop-stack-menu")
	{
		state.menu.SetTitle("Actions -> Drop Stackables:\n");
		
		int count = 0;
		InventoryList@ inv = plr.get_m_pInventory();
		dictionary types;
		while(inv !is null)
		{
			CItemInventory@ item = cast<CItemInventory@>(inv.hItem.GetEntity());
			if (item !is null and item.pev.colormap > 0)
			{
				Item@ wep = g_items[item.pev.colormap-1];
				if (wep !is null and wep.stackSize > 1 and !types.exists(item.pev.colormap))
				{
					state.menu.AddItem(wep.title, any("unstack-" + item.pev.colormap));
					types[item.pev.colormap] = true;
					count++;
				}
			}
			@inv = inv.pNext;
		}
		
		if (count == 0)
		{
			g_PlayerFuncs.PrintKeyBindingString(plr, "You don't have any stacked items");
			openPlayerMenu(plr, "");
			return;
		}
	}
	else if (subMenu.Find("unstack-") == 0)
	{
		int itemId = atoi(subMenu.SubString(8));
		Item@ invItem = g_items[itemId-1];
		
		string displayName = invItem.title;
		int amount = getItemCount(plr, itemId-1);
		if (amount > 0)
			displayName += " (" + amount + ")";
		else
		{
			openPlayerMenu(plr, "drop-stack-menu");
			return;
		}
		
		state.menu.SetTitle("Actions -> Drop " + displayName + ":\n");
		state.menu.AddItem("Drop 1", any("drop-000001-" + itemId));
		if (amount >= 10) state.menu.AddItem("Drop 10", any("drop-000010-" + itemId));
		if (amount >= 100) state.menu.AddItem("Drop 100", any("drop-000100-" + itemId));
		if (amount >= 1000) state.menu.AddItem("Drop 1,000", any("drop-001000-" + itemId));
		if (amount >= 10000) state.menu.AddItem("Drop 10,000", any("drop-010000-" + itemId));
		if (amount >= 10000) state.menu.AddItem("Drop 100,000", any("drop-100000-" + itemId));
	}
	else
	{
		state.menu.SetTitle("Actions:\n");
		state.menu.AddItem("Craft", any("craft-menu"));
		state.menu.AddItem("Equip", any("equip-menu"));
		state.menu.AddItem("Unequip", any("unequip-menu"));
		state.menu.AddItem("Drop Stackables", any("drop-stack-menu"));
	}
	
	state.openMenu(plr);
}

void revive_finish(EHandle h_plr)
{
	if (!h_plr)
		return;
		
	CBaseEntity@ plr = h_plr;
	
	if (plr.pev.deadflag == 0)
	{
		plr.pev.health = 5.0f;
		plr.pev.renderfx = 0;
		return;
	}
	
	g_Scheduler.SetTimeout("revive_finish", 0.05f, h_plr);
}

void inventoryCheck()
{
	for (uint i = 0; i < g_item_drops.size(); i++)
	{
		if (!g_item_drops[i].IsValid())
			continue;
		if (g_item_drops[i].GetEntity().pev.teleport_time < g_Engine.time)
		{
			CBaseEntity@ item = g_item_drops[i];
			item.pev.renderfx = -9999;
			remove_item_from_drops(item);
			g_EntityFuncs.Remove(item);
			i--;
		}
		else
			g_item_drops[i].GetEntity().pev.renderfx = 0;
	}
	for (uint i = 0; i < g_corpses.size(); i++)
	{
		if (!g_corpses[i].IsValid())
			continue;
		g_corpses[i].GetEntity().pev.renderfx = 0;
	}
	CBaseEntity@ ent = null;
	do {
		@ent = g_EntityFuncs.FindEntityByClassname(ent, "player");
		if (ent !is null and ent.pev.deadflag > 0)
		{
			ent.pev.renderfx = 0;
			if (ent.pev.sequence != 13)
			{
				ent.pev.frame = 0;
				ent.pev.sequence = 13;
			}
		}
	} while (ent !is null);
	
	/*
	// check for dropped weapons
	CBaseEntity@ wep = null;
	do {
		@wep = g_EntityFuncs.FindEntityByClassname(wep, "weaponbox");
		if (wep !is null and wep.pev.noise3 == "")
		{
			CBaseEntity@ owner = g_EntityFuncs.Instance(wep.pev.owner);
			if (owner !is null and owner.IsPlayer())
			{
				CBasePlayer@ plr = cast<CBasePlayer@>(owner);
				PlayerState@ state = getPlayerState(plr);
				
				if (plr.pev.deadflag > 0)
				{
					// don't drop weapons on death
					wep.Touch(plr);
					wep.pev.effects = EF_NODRAW;
					wep.pev.movetype = MOVETYPE_NONE;
				}
				
				if (state.droppedItems >= g_max_item_drops)
				{
					wep.Touch(plr);
					wep.pev.effects = EF_NODRAW;
					wep.pev.movetype = MOVETYPE_NONE;
					g_PlayerFuncs.PrintKeyBindingString(plr, "Can't drop more than " + g_max_item_drops + " item" + (g_max_item_drops > 1 ? "s" : ""));
				}
				else
				{
					state.droppedItems++;
					wep.pev.noise3 = getPlayerUniqueId(plr);
					state.droppedWeapons.insertLast(EHandle(wep));
				}
			}
		}
	} while(wep !is null);
	*/
	
	CBaseEntity@ e_plr = null;
	do {
		@e_plr = g_EntityFuncs.FindEntityByClassname(e_plr, "player");
		if (e_plr !is null)
		{
			CBasePlayer@ plr = cast<CBasePlayer@>(e_plr);
			PlayerState@ state = getPlayerState(plr);
			state.updateDroppedWeapons();
			
			// TODO: prevent nearby players from getting the same class
			//plr.SetClassification(Math.RandomLong(-1, 13));
			
			if (plr.pev.deadflag > 0)
				continue;
			
			if (e_plr.pev.button & IN_RELOAD != 0 and e_plr.pev.button & IN_USE != 0) {
				openPlayerMenu(plr, "");
			}
			
			TraceResult tr = TraceLook(plr, 96, true);
			CBaseEntity@ phit = g_EntityFuncs.Instance( tr.pHit );
			
			if (e_plr.pev.button & IN_USE != 0)
			{
				// increment force_retouch
				g_EntityFuncs.FireTargets("push", e_plr, e_plr, USE_TOGGLE);
				//println("RETOUCH");
			}
			
			if (state.currentChest)
			{
				if ((state.currentChest.GetEntity().pev.origin - plr.pev.origin).Length() > 96)
				{
					state.currentChest = null;
					g_PlayerFuncs.PrintKeyBindingString(plr, "Loot target too far away");
					state.closeMenus();
				}
			}
			
			HUDTextParams params;
			params.effect = 0;
			params.fadeinTime = 0;
			params.fadeoutTime = 0;
			params.holdTime = 0.2f;
			params.r1 = 255;
			params.g1 = 255;
			params.b1 = 255;
			params.x = -1;
			params.y = 0.7;
			params.channel = 1;
			
			// highlight items on ground (and see what they are)
			CBaseEntity@ closestItem = getLookItem(plr, tr.vecEndPos);
			
			//println("CLOSE TO  " + g_item_drops.size());
			
			if (closestItem !is null)
			{
				closestItem.pev.renderfx = kRenderFxGlowShell;
				closestItem.pev.renderamt = 1;
				closestItem.pev.rendercolor = Vector(200, 200, 200);
				
				if (closestItem.IsPlayer() and (plr.pev.button & IN_USE) != 0)
				{
					if (state.reviving)
					{
						float time = g_Engine.time - state.reviveStart;
						float t = time / g_revive_time;
						string progress = "\n\n[";
						for (float i = 0; i < 1.0f; i += 0.03f)
						{
							progress += t > i ? "|||" : "__";
						}
						progress += "]";
						
						if (time > 0.5f)
							g_PlayerFuncs.HudMessage(plr, params, "Reviving " + closestItem.pev.netname + progress);
						
						if (time > g_revive_time)
						{
							closestItem.EndRevive(0);
							revive_finish(EHandle(closestItem));
						}
					}
					else
					{
						state.reviving = true;
						state.reviveStart = g_Engine.time;
					}
				}
				else
				{
					state.reviving = false;
					g_PlayerFuncs.HudMessage(plr, params, getItemDisplayName(closestItem));
				}
				continue;
			}
			else
			{
				state.reviving = false;
			}
			
			if (phit is null or phit.pev.classname == "worldspawn" or phit.pev.colormap == -1)
				continue;
			
			g_PlayerFuncs.HudMessage(plr, params, 
				string(prettyPartName(phit)) + "\n" + int(phit.pev.health) + " / " + int(phit.pev.max_health));
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

void lootMenuCallback(CTextMenu@ menu, CBasePlayer@ plr, int page, const CTextMenuItem@ mitem)
{
	if (mitem is null)
		return;
	string action;
	mitem.m_pUserData.retrieve(action);
	PlayerState@ state = getPlayerState(plr);
	CBaseEntity@ chest = state.currentChest;
	
	if (chest is null)
		return;
	
	string submenu = "";
	
	if (action == "do-give")
	{
		submenu = "give";
	}
	else if (action == "do-take")
	{
		submenu = "take";
	}
	else if (action.Find("give-") == 0)
	{
		string itemName = action.SubString(5);
	}
	else if (action.Find("loot-") == 0)
	{
		string itemDesc = action.SubString(5);
		int sep = int(itemDesc.Find(","));
		int type = atoi( itemDesc.SubString(0, sep) );
		int amt = atoi( itemDesc.SubString(sep+1) );
		
		bool found = false;
		if (chest.IsPlayer() and chest.pev.deadflag > 0)
		{
			CBasePlayer@ corpse = cast<CBasePlayer@>(chest);
			if (sep != -1)
			{
				InventoryList@ inv = corpse.get_m_pInventory();
				while (inv !is null)
				{
					CItemInventory@ item = cast<CItemInventory@>(inv.hItem.GetEntity());
					@inv = inv.pNext;
					if (item !is null and item.pev.colormap == type and item.pev.button == amt)
					{
						if (giveItem(plr, type, amt > 0 ? amt : 1) == 0)
						{
							item.pev.renderfx = -9999;
							g_Scheduler.SetTimeout("delay_remove", 0, EHandle(item));
						}
						
						found = true;
						break;
					}
				}
			}
			else
			{
				Item@ gItem = getItemByClassname(itemDesc);
				CBasePlayerItem@ hasItem = corpse.HasNamedPlayerItem(itemDesc);
				if (hasItem !is null and gItem !is null)
				{
					if (plr.HasNamedPlayerItem(itemDesc) is null)
					{
						plr.SetItemPickupTimes(0);
						plr.GiveNamedItem(itemDesc);
						corpse.RemovePlayerItem(hasItem);
					}
					else if (giveItem(plr, gItem.type, amt > 0 ? amt : 1) == 0)
						corpse.RemovePlayerItem(hasItem);
						
					found = true;
				}
				
				if (!found)
				{
					int ammoIdx = g_PlayerFuncs.GetAmmoIndex(itemDesc);
					int ammo = corpse.m_rgAmmo(ammoIdx);
					if (ammo > 0)
					{
						int beforeAmmo = plr.m_rgAmmo(ammoIdx);
						plr.GiveAmmo( ammo, itemDesc, 9999); // TODO: set proper max?
						int amtGiven = plr.m_rgAmmo(ammoIdx) - beforeAmmo;
						int ammoLeft = ammo - amtGiven;
						Item@ ammoItem = getItemByClassname(itemDesc);
						
						if (ammoItem !is null)
						{
							ammoLeft = giveItem(plr, ammoItem.type, ammoLeft);
							
							if (ammoLeft < ammo)
								g_SoundSystem.PlaySound(plr.edict(), CHAN_ITEM, "items/9mmclip1.wav", 1.0f, 1.0f, 0, 100);
							
							corpse.m_rgAmmo(ammoIdx, ammoLeft);
						}
						else
							println("Unknown ammo: " + itemDesc);
							
						found = true;
					}
				}
				
			}
		}
		else if (chest.pev.classname == "player_corpse")
		{
			player_corpse@ corpse = cast<player_corpse@>(CastToScriptClass(chest));
		
			for (uint i = 0; i < corpse.items.size(); i++)
			{
				if (!corpse.items[i])
					continue;
				CBaseEntity@ item = corpse.items[i];	
				if (item.pev.colormap == type and item.pev.button == amt)
				{
					item_collected(plr, item, USE_TOGGLE, 0);
					undo_drop(EHandle(item), EHandle(plr));
					
					corpse.items.removeAt(i);
					i--;
					found = true;
					break;
				}
			}
		}
		if (!found)
		{
			g_PlayerFuncs.PrintKeyBindingString(plr, "Item no longer exists");
		}
	}
	
	g_Scheduler.SetTimeout("openLootMenu", 0.05, @plr, @chest, submenu);
}

void openLootMenu(CBasePlayer@ plr, CBaseEntity@ corpse, string submenu="")
{
	PlayerState@ state = getPlayerState(plr);
	state.initMenu(plr, lootMenuCallback);
	state.currentChest = corpse;
	
	string title = "Loot " + corpse.pev.netname + "'s corpse:\n";
	
	int numItems = 0;
	if (corpse.IsPlayer())
	{
		CBasePlayer@ pcorpse = cast<CBasePlayer@>(corpse);
		
		for (uint i = 0; i < MAX_ITEM_TYPES; i++)
		{
			CBasePlayerItem@ wep = pcorpse.m_rgpPlayerItems(i);
			while (wep !is null)
			{
				state.menu.AddItem(getItemDisplayName(wep), any("loot-" + wep.pev.classname));
				numItems++;
				@wep = cast<CBasePlayerItem@>(wep.m_hNextItem.GetEntity());				
			}
		}
		
		for (uint i = 0; i < g_ammo_types.size(); i++)
		{
			int ammo = pcorpse.m_rgAmmo(g_PlayerFuncs.GetAmmoIndex(g_ammo_types[i]));
			if (ammo > 0)
			{
				Item@ item = getItemByClassname(g_ammo_types[i]);
				string name = item !is null ? item.title : g_ammo_types[i];
				state.menu.AddItem(name + " (" + ammo + ")", any("loot-" + g_ammo_types[i]));
				numItems++;
			}
		}
		
		InventoryList@ inv = pcorpse.get_m_pInventory();
		while (inv !is null)
		{
			CItemInventory@ item = cast<CItemInventory@>(inv.hItem.GetEntity());
			@inv = inv.pNext;
			if (item !is null)
			{
				state.menu.AddItem(getItemDisplayName(item), any("loot-" + item.pev.colormap + "," + item.pev.button));
				numItems++;
			}
		}
	}
	else if (corpse.pev.classname == "player_corpse")
	{
		player_corpse@ pcorpse = cast<player_corpse@>(CastToScriptClass(corpse));
		for (uint i = 0; i < pcorpse.items.size(); i++)
		{
			if (!pcorpse.items[i])
				continue;
				
			CBaseEntity@ item = pcorpse.items[i];
			state.menu.AddItem(getItemDisplayName(item), any("loot-" + item.pev.colormap + "," + item.pev.button));
		}
		numItems = pcorpse.items.size();
	}
	else if (corpse.IsBSPModel())
	{
		numItems++;
		
		switch(corpse.pev.colormap)
		{
			case B_SMALL_CHEST:
				title = "Small Chest:\n";
				break;
			case B_LARGE_CHEST:
				title = "Large Chest:\n";
				break;
		}
		
		if (submenu == "give")
		{			
			for (uint i = 0; i < MAX_ITEM_TYPES; i++)
			{
				CBasePlayerItem@ item = plr.m_rgpPlayerItems(i);
				while (item !is null)
				{
					Item@ invItem = getItemByClassname(item.pev.classname);
					string displayName = invItem !is null ? invItem.title : string(item.pev.classname);
					state.menu.AddItem(displayName, any("give-" + item.pev.classname));
					@item = cast<CBasePlayerItem@>(item.m_hNextItem.GetEntity());		
				}
			}
			
			dictionary stacks;
			for (uint i = 0; i < g_ammo_types.size(); i++)
			{
				int ammo = plr.m_rgAmmo(g_PlayerFuncs.GetAmmoIndex(g_ammo_types[i]));
				if (ammo > 0)
				{
					Item@ item = getItemByClassname(g_ammo_types[i]);
					if (item !is null)
						stacks[item.type] = ammo;
				}
			}
			
			InventoryList@ inv = plr.get_m_pInventory();
			while(inv !is null)
			{
				CItemInventory@ item = cast<CItemInventory@>(inv.hItem.GetEntity());
				if (item !is null and item.pev.colormap > 0)
				{
					Item@ wep = g_items[item.pev.colormap-1];
					if (wep !is null)
					{
						if (stacks.exists(wep.type))
						{
							int oldCount = 0;
							stacks.get(wep.type, oldCount);
							stacks[wep.type] = oldCount + item.pev.button;
						}
						else
							stacks[wep.type] = item.pev.button;
					}
				}
				@inv = inv.pNext;
			}
			
			array<string>@ stackKeys = stacks.getKeys();
			for (uint i = 0; i < stackKeys.size(); i++)
			{
				Item@ item = g_items[ atoi(stackKeys[i]) ];
				int amt = 1;
				stacks.get(stackKeys[i], amt);
				state.menu.AddItem(item.title + (item.stackSize > 1 ? " (" + amt + ")" : ""), any("give-" + item.type));
			}
		}
		else if (submenu == "take")
		{
			state.menu.AddItem("some stuff", any("loot-"));
		}
		else
		{
			state.menu.AddItem("Give", any("do-give"));
			state.menu.AddItem("Take", any("do-take"));
		}
		
	}
	
	state.menu.SetTitle(title);
	
	if (numItems == 0)
	{
		g_PlayerFuncs.PrintKeyBindingString(plr, "Nothing left to loot");
		state.currentChest = null;
		return;
	}
	
	
	state.openMenu(plr);
}

CBaseEntity@ getLookItem(CBasePlayer@ plr, Vector lookPos)
{
	// highlight items on ground (and see what they are)
	float closestDist = 9e99;
	CBaseEntity@ closestItem = null;
	for (uint i = 0; i < g_item_drops.size(); i++)
	{
		if (!g_item_drops[i].IsValid())
			continue;
	
		CBaseEntity@ item = g_item_drops[i];				
		float dist = (item.pev.origin - lookPos).Length();
		if (dist < 32 and dist < closestDist)
		{
			@closestItem = @item;
			closestDist = dist;
		}
	}
	for (uint i = 0; i < g_corpses.size(); i++)
	{
		if (!g_corpses[i].IsValid())
			continue;
	
		CBaseEntity@ item = g_corpses[i];				
		float dist = (item.pev.origin - lookPos).Length();
		if (item.pev.effects != EF_NODRAW and dist < 32 and dist < closestDist)
		{
			@closestItem = @item;
			closestDist = dist;
		}
	}
	
	CBaseEntity@ ent = null;
	do {
		@ent = g_EntityFuncs.FindEntityByClassname(ent, "player");
		if (ent !is null and ent.pev.deadflag > 0 and (ent.pev.effects & EF_NODRAW) == 0)
		{
			float dist = (ent.pev.origin - lookPos).Length();
			if (dist < 32 and dist < closestDist)
			{
				@closestItem = @ent;
				closestDist = dist;
			}
		}
	} while (ent !is null);
	
	//println("CLOSE TO  " + g_item_drops.size());
	return closestItem;
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
		
		bool didAction = false;
		if (phit !is null and (phit.pev.classname == "func_door_rotating" or phit.pev.classname == "func_breakable_custom"))
		{
			didAction = true;
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
			else if (phit.pev.colormap == B_LARGE_CHEST)
			{
				state.currentChest = phit;
				openLootMenu(plr, phit);
			}
			else
				didAction = false;
		}
		if (!didAction)
		{			
			TraceResult tr2 = TraceLook(plr, 96, true);
			CBaseEntity@ lookItem = getLookItem(plr, tr2.vecEndPos);
			
			if (lookItem !is null)
			{
				if (lookItem.pev.classname == "item_inventory")
				{
					// I do my own pickup logic to bypass the 3 second drop wait in SC
					int barf = giveItem(plr, lookItem.pev.colormap-1, lookItem.pev.button);
					if (barf > 0)
					{
						lookItem.pev.button = barf;
						println("Couldn't hold " + barf + " of that");
					}
					else
					{
						item_collected(plr, lookItem, USE_TOGGLE, 0);
						lookItem.pev.renderfx = -9999;
						g_Scheduler.SetTimeout("delay_remove", 0, EHandle(lookItem));
					}
					
				}
				if (lookItem.pev.classname == "player_corpse" or lookItem.IsPlayer())
				{
					openLootMenu(plr, lookItem);
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
		if (args[0] == ".zones")
		{
			g_PlayerFuncs.SayText(plr, "Zone Info:\t " + g_zone_info.numZones + " zones, " + g_Engine.maxClients + " player slots\n");
			if (g_zone_info.wastedSettlers < 0)
				g_PlayerFuncs.SayText(plr, "\t\t\t\t\t\t\tSettlers per zone: " + g_zone_info.settlersPerZone + " (" + -g_zone_info.wastedSettlers + " slot(s) unused).\n"); 
			else if (g_zone_info.wastedSettlers > 0)
				g_PlayerFuncs.SayText(plr, "\t\t\t\t\t\t\tSettlers per zone: " + g_zone_info.settlersPerZone + " (" + g_zone_info.wastedSettlers + " player(s) can't settle).\n"); 
			else
				g_PlayerFuncs.SayText(plr, "\t\t\t\t\t\t\tSettlers per zone: " + g_zone_info.settlersPerZone + "\n");
			g_PlayerFuncs.SayText(plr, "\t\t\t\t\t\t\tParts per settler:  " + g_zone_info.partsPerPlayer + "\n");
			g_PlayerFuncs.SayText(plr, "\t\t\t\t\t\t\tParts for raiders:  " + g_zone_info.raiderParts + "\n");
			g_PlayerFuncs.SayText(plr, "\t\t\t\t\t\t\tReserved:            " + g_zone_info.reservedParts + "\n");
			
			return true;
		}
		if (args[0] == ".breakhome")
		{
			float delta = (state.lastBreakAll + 1.0f) - g_Engine.time;
			if (delta > 0)
			{
				g_PlayerFuncs.SayText(plr, "Wait " + int(delta + 1) + " seconds before using this command again\n");
				return true;
			}
			array<EHandle> parts = getPartsByOwner(plr);
			float delay = 0.1f;
			int count = 0;
			for (uint i = 0; i < parts.size(); i++)
			{
				func_breakable_custom@ bpart = castToPart(parts[i]);
				if (bpart.zoneid == state.home_zone)
				{
					g_Scheduler.SetTimeout("breakPart", delay, parts[i]);
					delay += 0.1f;
					count++;
				}
			}
			
			if (count > 0)
				g_PlayerFuncs.SayText(plr, "Destroying parts built by you in your home zone\n");
			else
				g_PlayerFuncs.SayText(plr, "You haven't built any parts in your home zone\n");
			
			state.lastBreakAll = g_Engine.time + delay;
			return true;
		}
		if (args[0] == ".team")
		{
			Team@ team = getPlayerTeam(plr);
			if (args.ArgC() < 2)
			{
				if (team !is null and team.members.size() > 1)
				{
					string members;
					for (int i = 0; i < int(team.members.size()); i++)
					{
						string member = getPlayerByName(plr, team.members[i], true).pev.netname;
						if (member != plr.pev.netname)
						{
							members += member + ", ";
						}
					}
					members = members.SubString(0, members.Length()-2);
					g_PlayerFuncs.SayText(plr, "You are sharing resources with: " + members);
					return true;
				}
				g_PlayerFuncs.SayText(plr, "You aren't on a team. Type \".team (player)\" to team with someone\n");
				return true;
			}
			
			CBasePlayer@ friend = getPlayerByName(plr, args[1]);
			
			if (friend !is null)
			{
				if (friend.entindex() == plr.entindex())
				{
					g_PlayerFuncs.SayText(plr, "You want to share resources with yourself. Type this in chat to accept:");
					g_PlayerFuncs.SayText(plr, "\"team with me plz i have no fren :<\"");
					return true;
				}
				
				string plrId = getPlayerUniqueId(plr);
				string friendId = getPlayerUniqueId(friend);
				
				Team@ friendTeam = getPlayerTeam(friend);
				
				if (friendTeam !is null and team !is null)
				{
					bool sameTeam = false;
					for (uint i = 0; i < team.members.size(); i++)
					{
						if (team.members[i] == friendId)
						{
							sameTeam = true;
							break;
						}
					}
					if (sameTeam)
						g_PlayerFuncs.SayText(plr, "You and " + friend.pev.netname + " are on the same team.\n");
					else
						g_PlayerFuncs.SayText(plr, "You and " + friend.pev.netname + " both have teams. Leave your team before joining theirs.\n");
					return true;
				}
				
				if (g_zone_info.settlersPerZone == 1)
				{
					g_PlayerFuncs.SayText(plr, "Teams aren't allowed in this game. Only 1 settler is allowed per zone");
					return true;
				}
				if (team !is null and int(team.members.size()) >= g_zone_info.settlersPerZone)
				{
					g_PlayerFuncs.SayText(plr, "Your team doesn't have room for another settler (max of " + g_zone_info.settlersPerZone + " per zone)");
					return true;
				}
				if (friendTeam !is null and int(friendTeam.members.size()) >= g_zone_info.settlersPerZone)
				{
					g_PlayerFuncs.SayText(plr, "Their team doesn't have room for another settler (max of " + g_zone_info.settlersPerZone + " per zone)");
					return true;
				}
				
				PlayerState@ friendState = getPlayerState(friend);
				if (friendState.home_zone != state.home_zone and state.home_zone != -1 and friendState.home_zone != -1)
				{
					g_PlayerFuncs.SayText(plr, "You and " + friend.pev.netname + " are settled in different zones. Destroy your base (.breakall) before joining their team.\n");
					return true;
				}
				
				BuildZone@ zone = getBuildZone(state.home_zone);
				if (zone !is null and zone.maxSettlers - zone.numSettlers < 1 and friendState.home_zone != state.home_zone)
				{
					g_PlayerFuncs.SayText(plr, "The zone you've settled in doesn't have room for another settler.\n");
					return true;
				}
				
				if (friendState.teamRequests.exists(plrId))
				{
					// answering a team request
					Team@ joinTeam = null;
					CBasePlayer@ newMember = null;
					string inviter = friend.pev.netname;
					
					if (team is null and friendTeam is null)
					{
						state.teamRequests.delete(friendId);
						friendState.teamRequests.delete(plrId);
						Team@ newTeam = Team();
						newTeam.members.insertLast(plrId);
						newTeam.members.insertLast(friendId);
						newTeam.home_zone = -1;
						if (state.home_zone != -1)
							newTeam.home_zone = state.home_zone;
						else if (friendState.home_zone != -1)
							newTeam.home_zone = friendState.home_zone;
							
						state.home_zone = friendState.home_zone = newTeam.home_zone;
						newTeam.numParts = state.getNumParts(newTeam.home_zone) + friendState.getNumParts(newTeam.home_zone);
						g_teams.insertLast(newTeam);
						@joinTeam = @g_teams[g_teams.size()-1];
					}
					else if (team !is null)
					{
						@joinTeam = @team;
						@newMember = @friend;
						inviter = plr.pev.netname;
						team.numParts += friendState.getNumParts(team.home_zone);
					}
					else if (friendTeam !is null)
					{
						friendTeam.numParts += state.getNumParts(team.home_zone);
						@joinTeam = @friendTeam;
						@newMember = @plr;
					}
					@state.team = @joinTeam;
					@friendState.team = @joinTeam;	

					BuildZone@ teamZone = getBuildZone(joinTeam.home_zone);
					if (teamZone !is null)
					{
						if (teamZone.maxSettlers - teamZone.numSettlers < 1)
						{
							g_PlayerFuncs.SayText(plr, "The team doesn't have room for another settler anymore.\n");
							return true;
						}
						teamZone.numSettlers++;
					}
					
					if (newMember !is null)
						joinTeam.members.insertLast(getPlayerUniqueId(newMember));
					
					int numOthers = 0;
					for (uint i = 0; i < joinTeam.members.size(); i++)
					{
						CBasePlayer@ otherPlr = getPlayerByName(plr, joinTeam.members[i], true);
						if (otherPlr is null)
							continue;
						string member = string(otherPlr.pev.netname);
						if (member != plr.pev.netname and member != friend.pev.netname)
						{
							g_PlayerFuncs.SayText(otherPlr, "" + newMember.pev.netname + " has joined your team (invited by " + inviter + ")\n");
							numOthers++;
						}
					}
					string others = numOthers > 0 ? " and " + numOthers + " others" : "";
					
					g_PlayerFuncs.SayText(plr, "You are now sharing resources with " + friend.pev.netname + others + "\n");
					g_PlayerFuncs.SayText(friend, "You are now sharing resources with " + plr.pev.netname + others + "\n");
				}
				else
				{
					g_PlayerFuncs.SayText(plr, "Team request sent to " + friend.pev.netname + "\n");
					state.teamRequests[getPlayerUniqueId(friend)] = true;
					g_PlayerFuncs.SayText(friend, string(plr.pev.netname) + " wants to share resources with you. Type this in chat to accept:\n");
					if (int(string(plr.pev.netname).Find(" ")) >= 0)
						g_PlayerFuncs.SayText(friend, ".team \"" + plr.pev.netname + "\"\n");
					else
						g_PlayerFuncs.SayText(friend, ".team " + plr.pev.netname + "\n");
				}
			}
			return true;
		}
		if (args[0] == ".solo")
		{
			Team@ team = getPlayerTeam(plr);
			if (team !is null and team.members.size() > 1)
			{
				for (int i = 0; i < int(team.members.size()); i++)
				{
					CBasePlayer@ member = getPlayerByName(plr, team.members[i], true);
					if (member.entindex() == plr.entindex())
					{
						team.members.removeAt(i);
						i--;
					}
					else
						g_PlayerFuncs.SayText(member, "" + plr.pev.netname + " left your team");
				}
				g_PlayerFuncs.SayText(plr, "You left your team");
				@state.team = null;
				
				int overflow = state.getNumParts(state.home_zone) - state.maxPoints(state.home_zone);
				if (overflow > 0)
				{
					g_PlayerFuncs.SayText(plr, "You have too many parts! Your most recently built parts will be broken.");
					state.breakParts(overflow); // break most recent parts until we're within our new build point limit
				}
				team.breakOverflowParts();
				BuildZone@ zone = getBuildZone(team.home_zone);
				
				for (uint i = 0; i < g_teams.size(); i++)
				{
					if (g_teams[i].members.size() <= 1)
					{
						for (int k = 0; k < int(g_teams[i].members.size()); k++)
						{
							CBasePlayer@ member = getPlayerByName(plr, g_teams[i].members[k], true);
							if (member !is null)
							{
								PlayerState@ memberState = getPlayerState(member);
								@memberState.team = null;
								memberState.checkHomeless();
								println("IS HOMELESS? " + member.pev.netname);
							}
						}
					
						println("Deleted team " + i);
						g_teams.removeAt(i);
						i--;
					}
				}
				return true;
			}
			else
			{
				g_PlayerFuncs.SayText(plr, "You're already solo.n");
			}
			return true;
		}
		if (args[0] == ".teams")
		{
			for (uint i = 0; i < g_teams.size(); i++)
			{
				string msg = "Team " + i + ": ";
				for (uint k = 0; k < g_teams[i].members.size(); k++)
				{
					msg += g_teams[i].members[k] + ", ";
				}
				msg = msg.SubString(0, msg.Length()-2);
				g_PlayerFuncs.SayText(plr, msg);
			}
			return true;
		}
		if (args[0] == ".home")
		{
			if (state.home_zone != -1)
				g_PlayerFuncs.SayText(plr, "Your home is zone " + state.home_zone);
			else
				g_PlayerFuncs.SayText(plr, "You don't have a home. You can settle in any zone.");
			return true;
		}
		if (args[0] == ".nodes")
		{
			g_disable_ents = !g_disable_ents;
			g_PlayerFuncs.SayText(plr, "Nodes spawns are " + (g_disable_ents ? "disabled" : "enabled"));
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
			int zoneid = getBuildZone(ent);
			ent.KeyValue("zoneid", "" + zoneid);
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
					state.addPart(ent, zoneid);
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