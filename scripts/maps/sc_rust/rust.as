#include "building_plan"
#include "hammer"
#include "func_breakable_custom"
#include "func_build_zone"
#include "player_corpse"
#include "../weapon_custom/v3.1/weapon_custom"
#include "saveload"
#include "items"
#include "stability"

// TODO:
// corpse collision without stucking players
// destroy items?
// combine dropped stackables
// refactor drop/equip/chest logic (LOTS of duplicate and confusing code)

//
// Game settings
//

int g_settler_reduction = 0; // reduces settlers per zone to increase build points
int g_raider_points = 40; // best if multiple of zone count
bool g_build_point_rounding = true; // rounds build points to a multiple of 10 (may reduce build points)
bool g_disable_ents = false;
bool g_build_anywhere = true; // disables build zones
bool g_free_build = true; // buildings don't cost any materials
int g_inventory_size = 20;
int g_max_item_drops = 2; // maximum item drops per player (more drops = less build points)
float g_tool_cupboard_radius = 512;
float g_corpse_time = 60.0f; // time before corpses despawn
int g_max_corpses = 2; // max corpses per player (should be at least 2 to prevent despawning valuable loot)
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

// the basic info needed to create an item
class RawItem
{
	int type = -1;
	int amt = 0;
	
	RawItem() {}
	
	RawItem(int type, int amt)
	{
		this.type = type;
		this.amt = amt;
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
	bool inGame = true;
	
	// vars for resuming after disconnected
	array<RawItem> allItems; // need to maintain this list in case player leaves (so we can spawn a corpse)
	int oldWeaponClip = 0; // for tracking clip usage
	int activeWepIdx = 0;
	string oldWeaponClass;
	Vector oldAngles;
	float oldHealth = 100;
	float oldArmor = 0;
	int oldDead = DEAD_NO;
	EHandle lastCorpse = null;
	bool resumeOnJoin = false;
	
	void initMenu(CBasePlayer@ plr, TextMenuPlayerSlotCallback@ callback)
	{
		CTextMenu temp(@callback);
		@menu = @temp;
	}
	
	void updateItemList()
	{
		if (!plr or !inGame)
			return;
		allItems = getAllItemsRaw(cast<CBasePlayer@>(plr.GetEntity()));
		
		updateActiveItem();
	}
	
	void updateActiveItem()
	{
		CBasePlayer@ p_plr = cast<CBasePlayer@>(plr.GetEntity());
		CBasePlayerWeapon@ activeWep = cast<CBasePlayerWeapon@>(p_plr.m_hActiveItem.GetEntity());
		if (activeWep !is null)
		{
			Item@ activeItem = getItemByClassname(activeWep.pev.classname);
			oldWeaponClass = activeWep.pev.classname;
			for (uint i = 0; i < allItems.size(); i++)
			{
				if (allItems[i].type == activeItem.type and allItems[i].amt == activeWep.m_iClip)
				{
					activeWepIdx = i;
					oldWeaponClip = activeWep.m_iClip;
					return;
				}
			}
		}
	}
	
	void updateItemListQuick(int type, int newAmt)
	{
		if (newAmt == oldWeaponClip)
			return;
		if (newAmt < oldWeaponClip)
		{
			if (activeWepIdx < int(allItems.size()) and allItems[activeWepIdx].type == type 
				and allItems[activeWepIdx].amt == oldWeaponClip)
			{
				allItems[activeWepIdx].amt = newAmt;
				oldWeaponClip = newAmt;
				return;
			}
		}
		updateItemList();
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
	g_Hooks.RegisterHook( Hooks::Player::ClientDisconnect, @ClientLeave );
	g_Hooks.RegisterHook( Hooks::Player::ClientPutInServer, @ClientJoin );
	
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
	PrecacheSound("ambience/burning3.wav"); // furnace
	PrecacheSound("items/ammopickup1.wav"); // armor
	PrecacheSound("items/ammopickup2.wav"); // armor
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
		"b_furnace",
		
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

void activateCorpses(CBaseEntity@ plr)
{
	array<player_corpse@> corpses = getCorpses(plr);
	for (uint i = 0; i < corpses.size(); i++)
		corpses[i].Activate();
}

array<player_corpse@> getCorpses(CBaseEntity@ plr)
{
	array<player_corpse@> corpses;
	for (uint i = 0; i < g_corpses.size(); i++)
	{
		if (!g_corpses[i])
			continue;
			
		string steamid = g_corpses[i].GetEntity().pev.noise1;
		string netname = g_corpses[i].GetEntity().pev.noise2;
		PlayerState@ state = getPlayerStateBySteamID(steamid, netname);
		if (state.plr.GetEntity().entindex() == plr.entindex())
			corpses.insertLast(cast<player_corpse@>(CastToScriptClass(g_corpses[i])));
	}
	return corpses;
}

void player_respawn(CBaseEntity@ pActivator, CBaseEntity@ pCaller, USE_TYPE useType, float flValue)
{
	activateCorpses(pCaller);
	getPlayerState(cast<CBasePlayer@>(pCaller)).updateItemList();
}

EHandle createCorpse(CBasePlayer@ plr)
{
	dictionary keys;
	keys["model"] = "models/skeleton.mdl";
	keys["origin"] = (plr.pev.origin + Vector(0,0,-36)).ToString();
	keys["angles"] = Vector(0, plr.pev.angles.y, 0).ToString();
	keys["netname"] = string(plr.pev.netname);
	keys["noise1"] = g_EngineFuncs.GetPlayerAuthId( plr.edict() );
	keys["noise2"] = string(plr.pev.netname);
	CBaseEntity@ ent = g_EntityFuncs.CreateEntity("player_corpse", keys, true);
	
	player_corpse@ corpse = cast<player_corpse@>(CastToScriptClass(ent));
	corpse.owner = plr;
	corpse.Update();
	
	g_corpses.insertLast(EHandle(ent));
	
	return EHandle(ent);
}

void player_killed(CBaseEntity@ pActivator, CBaseEntity@ pCaller, USE_TYPE useType, float flValue)
{
	if (!pCaller.IsPlayer())
		return;
	CBasePlayer@ plr = cast<CBasePlayer@>(pCaller);

	// always die on back (because I can't make player-model-based corpse work properly)
	createCorpse(plr);	
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

HookReturnCode ClientLeave(CBasePlayer@ plr)
{
	PlayerState@ state = getPlayerState(plr);
	state.inGame = false;
	state.resumeOnJoin = true;
	println("" + plr.pev.netname + " left the paws");
	
	// spawn corpse for leaver
	if (plr.pev.deadflag == DEAD_NO)
	{
		plr.pev.deadflag = DEAD_DEAD;
		plr.pev.effects |= EF_NODRAW;
		state.lastCorpse = createCorpse(plr);
	}
	else
	{
		activateCorpses(plr);
	}
	
	return HOOK_CONTINUE;
}

HookReturnCode ClientJoin(CBasePlayer@ plr)
{
	if (plr is null)
		return HOOK_CONTINUE;
	PlayerState@ state = getPlayerState(plr);
	
	if (state.resumeOnJoin and state.lastCorpse.IsValid())
	{
		player_corpse@ corpse = cast<player_corpse@>(CastToScriptClass(state.lastCorpse.GetEntity()));
		if (corpse !is null)
		{
			plr.pev.origin = corpse.pev.origin + Vector(0,0,36);
			plr.pev.angles = state.oldAngles;
			plr.pev.fixangle = FAM_FORCEVIEWANGLES;
			plr.pev.armorvalue = state.oldArmor;
			
			string oldWep = state.oldWeaponClass;
			
			plr.RemoveAllItems(false);
			for (uint i = 0; i < corpse.items.size(); i++)
				pickupItem(plr, corpse.items[i]);
			corpse.Destroy();
			
			CBasePlayerItem@ oldItem = @plr.HasNamedPlayerItem(oldWep);
			if (oldItem !is null)
			{
				plr.SwitchWeapon(oldItem);
			}
			
			if (state.oldDead != DEAD_NO)
				plr.Killed(plr.pev, 0);
			else
				plr.pev.health = state.oldHealth;
			
			g_Scheduler.SetTimeout("sayPlayer", 1, @plr, "Welcome back. Your inventory and position have been restored.");
		}
		else
			g_Scheduler.SetTimeout("sayPlayer", 1, @plr, "You lost your items because your corpse was looted or despawned.");
	}
	
	state.inGame = true;
	
	println("" + plr.pev.netname + " joined the paws");

	return HOOK_CONTINUE;
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

// Weird keyvalue effects:
// skin = disables ladder