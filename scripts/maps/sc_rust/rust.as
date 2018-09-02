#include "../weapon_custom/v4/weapon_custom"
#include "building_plan"
#include "hammer"
#include "func_breakable_custom"
#include "func_build_zone"
#include "player_corpse"
#include "ByteBuffer"
#include "saveload"
#include "items"
#include "stability"
#include "monster_c4"
#include "airdrop"
#include "DayNightCycle"
#include "apache"
#include "func_boat"

// TODO:
// nobody voted shown when people voted
// 400+ built parts on twlz
// auto save plz
// getting frozen in certain areas (only seen this in twlz so far)
// remove ladders cuz freezing :'<
// mp_decals 2 message :<
// can place roof on ground
// HUD map would be nice
// update zone names
// prevent repairing when recently attacked

// Should do/fix but too lazy:
// crashing/leaving players leave unusable items and sometimes duplicate player states
// supply crate not disappearing on lossy server
// window shutters have different hp each half
// crash when farming with inv open
// can't disable decals on airdrops
// lossy can't join teams?
// merging not working in teams
// inventory full message not always shown
// cant drop more thqn 2 items after mining when full
// protect creative from griefers
// force game mode cvar?
// base loading crashes
// too much ammo carry capacity?
// 20 items and u crash if look at inventory?
// collecting items is sometimes difficult
// rejoining didn't spawn in the right place (cause i did .clean ?)
// C4 was empty on death
// fuse part rotated for no reason (4x1 bridge square floor)
// part highlighting/info traces should be consistent
// monsters tend to crap up the server (20 per zone unplayable)
// monsters congregating in one spot in most zones
// decay raider structures
// save/load dropped items and player inventories?
// combine dropped stackables
// destroy items?
// corpse collision without stucking players
// weapon durability?
// textures are too bright
// Balance weapons
// bandage?
// make all bullets projectiles?
// airdrops don't fall if the object they're sitting on is removed after they land
// distant explosion sounds
// houndeye doesn't always stop attacking
// allow dropping weapons, but convert to an item with the same model(?)
// map screen
// blue blood sniper
// baby garg wasn't getting killed by bow
// flesh doesn't spawn where monsters die depending on death animation
// monsters attack each other if only one is agro
// still firing flamethrower (animation)
// hatchet and other tools mb are still too loud
// sniper doesn't zoom in after 
// cant place doors in fused doorways
// build ents aren't always see-through/tinted
// "cryokeen succ my ween. notice me senpai" -Faith4Dead

// note: impulse 197 = show node connections
// BSP Settings: Max node size 65536
// RAD settings: Default bounce, Direct Scale 1, Scale 1.2, Min light 16

//
// Game settings
//

int g_settler_reduction = 1; // reduces settlers per zone to increase build points
int g_raider_points = 40; // best if multiple of zone count
bool g_build_point_rounding = true; // rounds build points to a multiple of 10 (may reduce build points)
bool g_disable_ents = false; // disable node spawns
bool g_build_anywhere = false; // disables build zones
bool g_free_build = true; // buildings/items don't cost any materials and build points are shared
int g_inventory_size = 20; // max items in player inventories
int g_max_item_drops = 2; // maximum item drops per player (more drops = less build points)
float g_tool_cupboard_radius = 512;
int g_max_corpses = 2; // max corpses per player (should be at least 2 to prevent despawning valuable loot)
float g_corpse_time = 60.0f; // time (in seconds) before corpses despawn
float g_item_time = 30.0f; // time (in seconds) before items despawn
float g_supply_time = 150.0f; // time (in seconds) before air drop crate disappears
float g_revive_time = 5.0f; // time needed to revive player holding USE
float g_airdrop_min_delay = 10.0f; // time (in minutes) between airdrops
float g_airdrop_max_delay = 20.0f; // time (in minutes) between airdrops
float g_airdrop_first_delay = 15.0f; // time (in minutes) before the FIRST airdrop
float g_node_spawn_time = 60.0f; // time (in seconds) between node spawns
float g_chest_touch_dist = 96; // maximum distance from which a chest can be opened
float g_gather_multiplier = 2.0f; // resource gather amount multiplied by this (for faster/slower games)
float g_monster_forget_time = 6.0f; // time it takes for a monster to calm down after not seeing any players
int g_max_zone_monsters = 3;
uint NODES_PER_ZONE = 64;
float g_xen_agro_dist = 300.0f;

float g_apache_forget_time = 30.0f; // seconds it takes for an apache to forget a player had guns
float g_apache_roam_time = 15.0f; // minutes until the apache flies back out to sea
float g_apache_min_delay = 10.0f; // time (in minutes) between apache spawns
float g_apache_max_delay = 20.0f; // time (in minutes) between apache spawns
float g_apache_first_delay = 20.0f; // time (in minutes) between apache spawns

bool g_shared_build_points_in_pvp_mode = true; // cool var name
int g_global_solids = 0;
int MAX_SOLIDS = 512-(NODES_PER_ZONE*8); // any more than this causes glitchy movement or getting stuck. Much more than this causes server crashes

bool g_invasion_mode = false; // monsters spawn in waves and always attack
float g_invasion_delay = 8.0f; // minutes between waves
float g_invasion_initial_delay = 8.0f; // minutes before the invasion starts (first wave)
float g_node_spawn_time_invasion = 10.0f; // time (in seconds) between node spawns when in invasion mode

float g_vote_time = 20.0f; // time (in seconds) for vote to expire. Timer resets when new player joins.

const int CHEST_ITEM_MAX_SMALL = 14; // 2 menu pages for small chests
const int CHEST_ITEM_MAX_LARGE = 28; // 4 menu pages for large chests
const int CHEST_ITEM_MAX_FURNACE = 3; // slots for wood, ore, and result

float COOK_TIME_WOOD = 2.0f;
float COOK_TIME_METAL = 2.0f;
float COOK_TIME_HQMETAL = 4.0f;

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
	int partsPerZone;
	int reservedParts; // for trees/items/etc.
	int raiderParts; // parts for raiders, shared across all raiders for each zone
	
	ZoneInfo() {}
	
	void init()
	{
		if (g_build_zones.length() == 0)
		{
			println("Error: no build zones exist.");
			return;
		}
		// each player entity counts towards limit, x2 is so each player can drop an item or spawn an effect or something.
		int maxNodes = NODES_PER_ZONE;
		maxNodes += 16; // airdops (plane + box + chute) + 6 water func_conveyors + worldspawn + sun/moon + skyboxes + heli + 1
		// players + corpses + player item drops + trees/stones/animals
		reservedParts = g_Engine.maxClients*2 + maxNodes; // minimum reserved (assumes half of players won't have a corpse/dropped item)
		
		if (g_invasion_mode) {
			reservedParts += g_Engine.maxClients*2; // all players confined to a single zone, must account for worst case (2 items + 2 corpses)
			reservedParts += 32; // for monsters that spawn other monsters (tor, agrunt, gonarch)
		}
		
		int raider_points = g_raider_points;
		if (g_invasion_mode or g_creative_mode or g_shared_build_points_in_pvp_mode)
			raider_points = 0;
		
		int maxSettlerParts = MAX_VISIBLE_ENTS - (reservedParts+raider_points);
		if (g_build_point_rounding)
			maxSettlerParts = (maxSettlerParts / 10) * 10;
		numZones = g_build_zones.length();
		slots = g_Engine.maxClients + (g_build_zones.length()-1);
		settlersPerZone = Math.max(1, (slots / g_build_zones.length()) - g_settler_reduction);		
		wastedSettlers = g_Engine.maxClients - (settlersPerZone*g_build_zones.length());
		partsPerPlayer = maxSettlerParts / settlersPerZone;
		
		if (true) {
			// should work for 32 players. Client crashes more common after this(?)
			partsPerZone = 300; 
		}
		
		for (uint i = 0; i < g_build_zones.length(); i++)
			g_build_zones[i].maxSettlers = settlersPerZone;
		
		raiderParts = raider_points;
		
		if (g_build_point_rounding)
		{
			// round build points to nearest multiple of 10 so they look nicer
			partsPerPlayer = (partsPerPlayer / 10) * 10;
			reservedParts = MAX_VISIBLE_ENTS - (partsPerPlayer*settlersPerZone + raiderParts); // give remainder to reserved
		}
		
		int maxExpectedEnts = (NODES_PER_ZONE*2 + (partsPerPlayer + raiderParts))*numZones;
		maxExpectedEnts += 10 + g_Engine.maxClients*(3+g_max_item_drops+g_inventory_size);
		println("Max expected ents: " + maxExpectedEnts);
	}
	
	string getZoneName(int zoneid)
	{
		switch(zoneid) {
			case 1: return "Bay";
			case 2: return "Forest";
			case 3: return "Lake";
			case 4: return "Dunes";
			case 5: return "Snow";
			case 6: return "Hill";
			case 7: return "River";
			case 8: return "Beach";
		}
		return zoneid;
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
		//println("TEAM OVERFLOW? " + numParts + " / " + maxPoints);

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

enum tips
{
	TIP_ACTION_MENU = 1,
	TIP_HATCHET = 2,
	TIP_PICKAXE = 4,
	TIP_CUPBOARD = 8,
	TIP_PLACE_ITEMS = 16,
	TIP_HAMMER = 32,
	TIP_SLEEP = 64,
	TIP_CHEST = 128,
	TIP_ARMOR = 256,
	TIP_LOOT = 512,
	TIP_LOCK_DOOR = 1024,
	TIP_LOCK_HATCH = 2048,
	TIP_CODE = 4096,
	TIP_METAL = 8192,
	TIP_FURNACE = 16384,
	TIP_AUTH = 32768,
	TIP_CHEST_ITEMS = 65536,
	TIP_FIRE_RESIST = 131072,
	TIP_FUEL = 262144,
	TIP_FLAMETHROWER = 524288,
	TIP_PLAN = 1048576,
	TIP_SCRAP = 2097152,
}

class PlayerState
{
	EHandle plr;
	CTextMenu@ menu;
	int useState = 0;
	int codeTime = 0; // time left to input lock code
	dictionary zoneParts; // number of unbroken build parts owned by the player (per zone)
	int home_zone = -1; // zone the player is allowed to settle in (-1 = nomad)
	array<EHandle> authedLocks; // locked objects the player can use
	array<EHandle> droppedEnts;
	Team@ team = null;
	EHandle currentLock; // lock currently being interacted with
	EHandle currentChest; // current corpse/chest being interacted with
	bool reviving = false;
	float reviveStart = 0; // time this player started reviving someone
	float lastBreakAll = 0; // last time the player used the breakall command
	dictionary teamRequests; // outgoing requests for team members
	bool inGame = true;
	float lastDangerous = 0; // last time this player was dangerous (had guns)
	float lastFireHeal = 0; // prevent fire heal stacking
	
	uint64 tips = 0; // bitfield for shown tips
	
	// guitar vars
	float songPosition = 0; // for guitar song
	bool playingSong = false;
	float lastNote = 0;
	int songId = 0;
	
	// vars for resuming after disconnected
	array<RawItem> allItems; // need to maintain this list in case player leaves (so we can spawn a corpse)
	array<EHandle> beds;
	int oldWeaponClip = 0; // for tracking clip usage
	int activeWepIdx = 0;
	string oldWeaponClass;
	Vector oldAngles;
	float oldHealth = 100;
	float oldArmor = 0;
	int oldDead = DEAD_NO;
	EHandle lastCorpse = null;
	bool resumeOnJoin = false;
	
	void showTip(int tipType)
	{
		if (@plr.GetEntity() == null)
			return;
		CBasePlayer@ p = cast<CBasePlayer@>(plr.GetEntity());
			
		if (tips & tipType != 0)
			return;
		tips |= tipType;
		
		if (tipType == TIP_PLAN and g_creative_mode)
			return;
		
		string msg = "";
		switch(tipType)
		{
			case TIP_ACTION_MENU: msg = "Press +impulse to open the action menu"; break;
			case TIP_HATCHET: msg = "Hatchets collect wood faster\n\nPress +impulse -> Craft -> Tools"; break;
			case TIP_PICKAXE: msg = "Pickaxes collect stone/metal faster\n\nPress +impulse -> Craft -> Tools"; break;
			case TIP_CUPBOARD: msg = "Tool Cupboards prevent griefing\n\nPress +impulse -> Craft -> Interior Items"; break;
			case TIP_PLACE_ITEMS: msg = "Place items by selecting the\n\nBuilding Plan and pressing +reload"; break;
			case TIP_HAMMER: msg = "Upgrade your base with the Hammer\n\nPress +impulse -> Craft -> Tools"; break;
			case TIP_SLEEP: msg = "Place a SleepingBag to respawn here\n\nPress +impulse -> Craft -> Interior Items"; break;
			case TIP_CHEST: msg = "Build a Chest to store excess items\n\nPress +impulse -> Craft -> Interior Items"; break;
			case TIP_ARMOR: msg = "Equip armor to protect yourself\n\nPress +impulse -> Craft -> Medical / Armor"; break;
			case TIP_LOOT: msg = "A corpse is spawned when you die.\n\nPress +use on corpses to loot them."; break;
			case TIP_LOCK_DOOR: msg = "You can place Code Locks on doors\n\nPress +impulse -> Craft -> Interior Items"; break;
			case TIP_LOCK_HATCH: msg = "You can place Code Locks on hatches\n\nPress +impulse -> Craft -> Interior Items"; break;
			case TIP_METAL: msg = "Metal is smelted in a furnace\n\nPress +impulse -> Craft -> Interior Items"; break;
			case TIP_FURNACE: msg = "Press +USE to open the furnace.\n\nWood and Ore is required to make metal."; break;
			case TIP_CODE: msg = "Hold +USE on the Code Lock\n\nto open the lock menu."; break;
			case TIP_AUTH: msg = "Press +USE to authorize yourself.\n\nHold +USE to unauthorize all users."; break;
			case TIP_CHEST_ITEMS: msg = "Press +USE on the chest to open it"; break;
			case TIP_FIRE_RESIST: msg = "Stone/Metal/Armor is immune to fire"; break;
			case TIP_FUEL: msg = "Fuel is harvested from dead aliens"; break;
			case TIP_FLAMETHROWER: msg = "Equip Fuel to load the Flamethrower\n\nPress +impulse -> Equip -> Fuel"; break;
			case TIP_PLAN: msg = "Craft a Building Plan to build\n\nPress +impulse -> Craft -> Tools"; break;
			case TIP_SCRAP: msg = "Collect Scrap from blue barrels"; break;
		}
		
		if (msg.Length() > 0)
			PrintKeyBindingStringXLong(p, "TIP: " + msg);
	}
	
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
			if (activeItem is null)
			{
				activeWepIdx = -1;
				return;
			}
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
		if (newAmt == oldWeaponClip or activeWepIdx == -1)
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
			
		if (part.pev.colormap == B_BED)
		{
			beds.insertLast(EHandle(part));
		}
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
			zone.addRaiderParts(-1);
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
		/*
		for (uint i = 0; i < droppedEnts.size(); i++)
		{
			bool pickedup = true;
			if (droppedEnts[i].IsValid())
			{
				CBaseEntity@ wep = droppedEnts[i];
				CBaseEntity@ aiment = g_EntityFuncs.Instance(wep.pev.aiment);
				pickedup = aiment !is null;
			}
			
			if (pickedup)
			{
				// weapon picked up
				droppedEnts.removeAt(i);
				i--;
				droppedEnts--;
				continue;
			}
		}
		*/
	}
	
	void addPartCount(int num, int zoneid)
	{
		int count = 0;
		if (zoneParts.exists(zoneid))
			zoneParts.get(zoneid, count);
		count += num;
		zoneParts[zoneid] = count;
	}
	
	void leaveTeam()
	{
		CBasePlayer@ p_plr = cast<CBasePlayer@>(plr.GetEntity());
		Team@ team = getPlayerTeam(p_plr);
		if (team !is null and team.members.size() > 1)
		{
			for (int i = 0; i < int(team.members.size()); i++)
			{
				CBasePlayer@ member = getPlayerByName(p_plr, team.members[i], true);
				if (member.entindex() == p_plr.entindex())
				{
					team.members.removeAt(i);
					i--;
				}
				else
					g_PlayerFuncs.SayText(member, "" + p_plr.pev.netname + " left your team");
			}
			g_PlayerFuncs.SayText(p_plr, "You left your team");
			@team = null;
			
			int overflow = getNumParts(home_zone) - maxPoints(home_zone);
			if (overflow > 0)
			{
				g_PlayerFuncs.SayText(p_plr, "You have too many parts! Your most recently built parts will be broken.");
				breakParts(overflow); // break most recent parts until we're within our new build point limit
			}
			team.breakOverflowParts();
			BuildZone@ zone = getBuildZone(team.home_zone);
			
			for (uint i = 0; i < g_teams.size(); i++)
			{
				if (g_teams[i].members.size() <= 1)
				{
					for (int k = 0; k < int(g_teams[i].members.size()); k++)
					{
						CBasePlayer@ member = getPlayerByName(p_plr, g_teams[i].members[k], true);
						if (member !is null)
						{
							PlayerState@ memberState = getPlayerState(member);
							@memberState.team = null;
							memberState.checkHomeless();
							//println("IS HOMELESS? " + member.pev.netname);
						}
					}
				
					println("Deleted team " + i);
					g_teams.removeAt(i);
					i--;
				}
			}
		}
		else
		{
			g_PlayerFuncs.SayText(p_plr, "You're already solo.\n");
		}
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
	
		if (zoneid != home_zone or g_creative_mode or g_shared_build_points_in_pvp_mode)
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
		if (g_invasion_mode or g_creative_mode or g_shared_build_points_in_pvp_mode)
			return g_zone_info.partsPerZone;
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
array<EHandle> g_boats; // max 1 per player!
Vector g_dead_zone; // where dead players go until they respawn
Vector g_void_spawn; // place where you can spawn items outside the play area
float g_airdrop_height = 2048; // height where planes spawn
float g_apache_height = 2000; // height where apaches roam between zones
int g_invasion_round = 0;
float g_next_invasion_wave = 0;
bool g_wave_in_progress = false;
int g_vote_state = 1;
int g_mode_select = 0;
int g_difficulty = 0;
bool g_creative_mode = false;
bool waiting_for_voters = true;
bool finished_invasion = false;
bool debug_mode = false;
bool game_started = false;
bool g_friendly_fire = true;

array<string> g_upgrade_suffixes = {
	"_twig",
	"_wood",
	"_stone",
	"_metal",
	"_armor"
};

array<string> g_puff_sprites = {"sprites/black_smoke3.spr", "sprites/boom.spr", "sprites/boom2.spr",
					"sprites/boom3.spr", "sprites/puff1.spr", "sprites/puff2.spr"};

dictionary g_partname_to_model; // maps models to part names
dictionary g_model_to_partname; // maps part names to models
dictionary g_pretty_part_names;

int g_part_id = 0;
//bool debug_mode = false;
ZoneInfo g_zone_info;

EHandle g_invasion_zone;

int MAX_SAVE_DATA_LENGTH = 1015; // Maximum length of a value saved with trigger_save. Discovered through testing
//int MAX_VISIBLE_ENTS = 510;
int MAX_VISIBLE_ENTS = 480; // slightly reduced since I still got max vis ents error

string beta_dir = "beta/"; // set to blank before release, or change when assets need updating

void MapInit()
{
	debug_mode = false;
	
	g_CustomEntityFuncs.RegisterCustomEntity( "weapon_building_plan", "weapon_building_plan" );
	g_ItemRegistry.RegisterWeapon( "weapon_building_plan", "sc_rust/beta", "" );
	
	g_CustomEntityFuncs.RegisterCustomEntity( "weapon_hammer", "weapon_hammer" );
	g_ItemRegistry.RegisterWeapon( "weapon_hammer", "sc_rust/beta", "" );
	
	g_CustomEntityFuncs.RegisterCustomEntity( "func_breakable_custom", "func_breakable_custom" );
	g_CustomEntityFuncs.RegisterCustomEntity( "func_build_zone", "func_build_zone" );
	g_CustomEntityFuncs.RegisterCustomEntity( "player_corpse", "player_corpse" );
	g_CustomEntityFuncs.RegisterCustomEntity( "monster_c4", "monster_c4" );
	g_CustomEntityFuncs.RegisterCustomEntity( "monster_satchel_charge", "monster_satchel_charge" );
	g_CustomEntityFuncs.RegisterCustomEntity( "monster_b17", "monster_b17" );
	g_CustomEntityFuncs.RegisterCustomEntity( "item_parachute", "item_parachute" );
	
	g_Hooks.RegisterHook( Hooks::Player::PlayerUse, @PlayerUse );
	g_Hooks.RegisterHook( Hooks::Player::ClientSay, @ClientSay );
	g_Hooks.RegisterHook( Hooks::Player::ClientDisconnect, @ClientLeave );
	g_Hooks.RegisterHook( Hooks::Player::ClientPutInServer, @ClientJoin );
	
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
	PrecacheSound("debris/bustcrate1.wav");
	PrecacheSound("debris/bustcrate2.wav");
	PrecacheSound("debris/wood1.wav");
	PrecacheSound("debris/wood2.wav");
	PrecacheSound("debris/wood3.wav");
	PrecacheSound("ambience/burning3.wav"); // furnace
	PrecacheSound("items/ammopickup1.wav"); // armor
	PrecacheSound("items/ammopickup2.wav"); // armor
	PrecacheSound("player/pl_jump2.wav"); // item give/loot
	PrecacheModel("models/woodgibs.mdl");
	PrecacheModel("models/concrete_gibs.mdl");
	PrecacheModel("models/metalplategibs.mdl");
	PrecacheModel("models/skeleton.mdl");
	PrecacheModel("sprites/xbeam4.spr");
	PrecacheModel("sprites/fire.spr");
	
	g_Game.PrecacheMonster("monster_apache", false);
	PrecacheModel("models/sc_rust/apache.mdl");
	
	for (uint i = 0; i < g_puff_sprites.size(); i++)
		PrecacheModel(g_puff_sprites[i]);
	
	PrecacheSound("sc_rust/flesh1.ogg");
	PrecacheSound("sc_rust/flesh2.ogg");
	PrecacheSound("sc_rust/flesh3.ogg");
	PrecacheSound("sc_rust/guitar.ogg");
	PrecacheSound("sc_rust/guitar2.ogg");
	PrecacheSound("sc_rust/c4_beep.wav");
	PrecacheSound("sc_rust/fuse.ogg");
	PrecacheSound("sc_rust/b17.ogg");
	PrecacheSound("sc_rust/b17_far.ogg");
	PrecacheSound("sc_rust/heli_far.ogg");
	PrecacheSound("sc_rust/sizzle.ogg");
	PrecacheSound("ambience/burning1.wav");
	PrecacheModel("models/sc_rust/pine_tree.mdl");
	PrecacheModel("models/sc_rust/rock.mdl");
	PrecacheModel("models/sc_rust/tr_barrel.mdl");
	PrecacheModel("models/sc_rust/w_c4.mdl");
	PrecacheModel("models/sc_rust/b17.mdl");
	PrecacheModel("models/sc_rust/parachute.mdl");
	
	for (uint i = 0; i < g_material_damage_sounds.length(); i++)
		for (uint k = 0; k < g_material_damage_sounds[i].length(); k++)
			PrecacheSound(g_material_damage_sounds[i][k]);
	for (uint i = 0; i < g_material_break_sounds.length(); i++)
		for (uint k = 0; k < g_material_break_sounds[i].length(); k++)
			PrecacheSound(g_material_break_sounds[i][k]);
			
	WeaponCustomMapInit();
	
	// add custom weapon ammos (defined in weapon_custom scripts)
	WeaponCustom::g_ammo_types.insertLast("arrows");
	WeaponCustom::g_ammo_types.insertLast("fuel");
	
	VehicleMapInit( true, false );
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
		"b_bed",
		"b_fire",
		
		"b_wood_shutter_r",
		"b_wood_shutter_l",
		"b_wood_door_lock",
		"b_wood_door_unlock",
		"b_metal_door_unlock",
		"b_metal_door_lock",
		"b_ladder_box",
		"b_ladder_hatch_ladder",
		"b_ladder_hatch_frame",
		"b_ladder_hatch_door",
		"b_ladder_hatch_door_unlock",
		"b_ladder_hatch_door_lock",
		
		"e_tree",
		"e_rock",
		"e_barrel",
		"e_supply_crate",
		"e_boat_wood",
		"e_boat_metal",
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
			func_build_zone@ zone = cast<func_build_zone@>(CastToScriptClass(ent));
			int id = zone.id;
			bool unique = true;
			for (uint i = 0; i < g_build_zones.length(); i++)
			{
				if (g_build_zones[i].id == id)
				{
					func_build_zone@ parent = cast<func_build_zone@>(CastToScriptClass(g_build_zone_ents[i]));
					parent.subZones.insertLast(EHandle(ent));
					unique = false;
					break;
				}
			}
			if (!unique)
				continue;
				
			zone.Enable();
			g_build_zone_ents.insertLast(EHandle(ent));
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
		println("ERROR: rust_dead_zone entity is missing. Dead players will be able to spy on people.");
	
	CBaseEntity@ void_spawn = g_EntityFuncs.FindEntityByTargetname(null, "void_spawn_pos");
	if (void_spawn !is null)
	{
		g_void_spawn = void_spawn.pev.origin;
		g_EntityFuncs.Remove(void_spawn);
	} 
	else 
		println("ERROR: void_spawn_pos entity is missing. Item containers will not function correctly.");
		
	CBaseEntity@ drop_height = g_EntityFuncs.FindEntityByTargetname(null, "air_drop_height");
	if (drop_height !is null)
	{
		g_airdrop_height = drop_height.pev.origin.z;
		g_EntityFuncs.Remove(drop_height);
	} 
	else 
		println("ERROR: air_drop_height entity is missing. Planes will spawn at the wrong height.");
	
	day_night_cycle = DayNightCycle("sun", "sun2", "moon", "sky_mid", "sky_dawn", "sky_night");
	
	WeaponCustomMapActivate();
	
	removeExtraEnts();
	
	dropNodes();
	
	resetVoteBlockers();
	
	@ent = null;
	do {
		@ent = g_EntityFuncs.FindEntityByTargetname(ent, "wawa");
		if (ent !is null)
			ent.pev.effects |= EF_NODRAW;
	} while (ent !is null);
	
	//setupInvasionMode();
	//setupCreativeMode();
	//setupPvpMode();
}

void delay_say(string text)
{
	g_PlayerFuncs.SayTextAll(getAnyPlayer(), text +"\n");
}

void resetVoteBlockers()
{
	CBaseEntity@ block1 = g_EntityFuncs.FindEntityByTargetname(null, "option1_block");
	CBaseEntity@ block2 = g_EntityFuncs.FindEntityByTargetname(null, "option2_block");
	CBaseEntity@ block3 = g_EntityFuncs.FindEntityByTargetname(null, "option3_block");
	if (block1 is null or block2 is null or block3 is null)
	{
		println("Missing option*_block ents. Voting will be broken");
		return;
	}
	block1.pev.solid = block2.pev.solid = block3.pev.solid = SOLID_NOT;
	block1.pev.rendercolor = block2.pev.rendercolor = block3.pev.rendercolor = Vector(0, 255, 0);
}

void tallyVotes()
{
	if (waiting_for_voters)
		return;
		
	if (g_next_invasion_wave == 0 or g_next_invasion_wave > g_Engine.time)
	{
		g_Scheduler.SetTimeout("tallyVotes", 0.1f);
		return;
	}
	
	g_EntityFuncs.FireTargets("tally_votes", null, null, USE_TOGGLE);
	
	CBaseEntity@ option1 = g_EntityFuncs.FindEntityByTargetname(null, "option1_vote");
	CBaseEntity@ option2 = g_EntityFuncs.FindEntityByTargetname(null, "option2_vote");
	CBaseEntity@ option3 = g_EntityFuncs.FindEntityByTargetname(null, "option3_vote");
	if (option1 is null or option2 is null or option3 is null)
	{
		println("Error: missing game_conter ents for tallying votes!");
		return;
	}
	
	clearTimer();
	
	// choose game mode
	int op1_votes = int(option1.pev.frags);
	int op2_votes = int(option2.pev.frags);
	int op3_votes = int(option3.pev.frags);
	option1.pev.frags = option2.pev.frags = option3.pev.frags = 0;
	
	println("Vote totals: " + op1_votes + " " + op2_votes + " " + op3_votes);
	
	if (g_vote_state == 1)
	{
		int selection = getVoteSelection(op1_votes, op2_votes, op3_votes, "PvP", "Co-op", "Creative");
		if (selection == -1)
		{
			waiting_for_voters = true;
			return;
		}
		
		g_mode_select = selection;
		if (selection == 0)
		{
			g_PlayerFuncs.SayTextAll(getAnyPlayer(), "PvP mode selected.\n");
			g_vote_state = 0;
			g_Scheduler.SetTimeout("setupPvpMode", 3.0f);
		}
		else if (selection == 1)
		{
			g_PlayerFuncs.SayTextAll(getAnyPlayer(), "Co-op mode selected. Now vote for a difficulty level.\n");
			g_vote_state = 2;
			waiting_for_voters = true;
			g_PlayerFuncs.RespawnAllPlayers(true, true);
			g_EntityFuncs.FireTargets("vote_options1", null, null, USE_OFF);
			g_EntityFuncs.FireTargets("vote_options2", null, null, USE_ON);
		}
		else if (selection == 2)
		{
			g_PlayerFuncs.SayTextAll(getAnyPlayer(), "Creative mode selected.\n");
			g_vote_state = 0;
			g_Scheduler.SetTimeout("setupCreativeMode", 3.0f);
		}
		resetVoteBlockers();
	}
	else if (g_vote_state == 2)
	{
		int selection = getVoteSelection(op1_votes, op2_votes, op3_votes, "Easy", "Medium", "Hard");
		if (selection == -1)
		{
			waiting_for_voters = true;
			return;
		}
		
		g_difficulty = selection;
		if (selection == 0)
			g_PlayerFuncs.SayTextAll(getAnyPlayer(), "Easy mode selected.\n");
		else if (selection == 1)
			g_PlayerFuncs.SayTextAll(getAnyPlayer(), "Medium mode selected.\n");
		else if (selection == 2)
			g_PlayerFuncs.SayTextAll(getAnyPlayer(), "Hard mode selected.\n");
			
		g_Scheduler.SetTimeout("setupInvasionMode", 3.0f);
	}
}

int getVoteSelection(int votes1, int votes2, int votes3, string op1, string op2, string op3)
{
	if (votes1 + votes2 + votes3 == 0)
	{
		g_PlayerFuncs.SayTextAll(getAnyPlayer(), "Nobody voted. Stand in a green room to vote.\n");
		return -1;
	}
	else if (votes1 == votes2 and votes2 == votes3)
	{
		g_PlayerFuncs.SayTextAll(getAnyPlayer(), "The vote was evenly split. A random mode will be chosen.\n");
		return Math.RandomLong(0, 2);
	}
	else if (votes1 == votes2 and votes1 > 0)
	{
		if (votes3 > 0) {
			g_PlayerFuncs.SayTextAll(getAnyPlayer(), "The vote is tied between " + op1 + " and " + op2 + ". Vote again.\n");
			CBaseEntity@ block = g_EntityFuncs.FindEntityByTargetname(null, "option3_block");
			block.pev.solid = SOLID_BSP;
			block.pev.rendercolor = Vector(255, 0, 0);
			g_PlayerFuncs.RespawnAllPlayers(true, true);
			return -1;
		} else {
			g_PlayerFuncs.SayTextAll(getAnyPlayer(), "The vote is tied between " + op1 + " and " + op2 + ". A random option will be chosen.\n");
			return Math.RandomLong(0, 1);
		}
	}
	else if (votes1 == votes3 and votes1 > 0)
	{
		if (votes2 > 0) {
			g_PlayerFuncs.SayTextAll(getAnyPlayer(), "The vote is tied between " + op1 + " and " + op3 + ". Vote again.\n");
			CBaseEntity@ block = g_EntityFuncs.FindEntityByTargetname(null, "option2_block");
			block.pev.solid = SOLID_BSP;
			block.pev.rendercolor = Vector(255, 0, 0);
			g_PlayerFuncs.RespawnAllPlayers(true, true);
			return -1;
		} else {
			g_PlayerFuncs.SayTextAll(getAnyPlayer(), "The vote is tied between " + op1 + " and " + op3 + ". A random option will be chosen.\n");
			return Math.RandomLong(0, 1)*2;
		}
	}
	else if (votes2 == votes3 and votes2 > 0)
	{
		if (votes1 > 0) {
			g_PlayerFuncs.SayTextAll(getAnyPlayer(), "The vote is tied between " + op2 + " and " + op3 + ". Vote again.\n");
			CBaseEntity@ block = g_EntityFuncs.FindEntityByTargetname(null, "option1_block");
			block.pev.solid = SOLID_BSP;
			block.pev.rendercolor = Vector(255, 0, 0);
			g_PlayerFuncs.RespawnAllPlayers(true, true);
			return -1;
		} else {
			g_PlayerFuncs.SayTextAll(getAnyPlayer(), "The vote is tied between " + op2 + " and " + op3 + ". A random option will be chosen.\n");
			return Math.RandomLong(2, 3);
		}
	}
	else if (votes1 > votes2 and votes1 > votes3)
		return 0;
	else if (votes2 > votes3 and votes2 > votes1)
		return 1;
	else
		return 2;
}

void cast_vote(CBaseEntity@ pActivator, CBaseEntity@ pCaller, USE_TYPE useType, float flValue)
{
	if (waiting_for_voters) // vote hasn't started yet
	{
		waiting_for_voters = false;
		resetVoteTimer();
		g_PlayerFuncs.SayTextAll(getAnyPlayer(), "Vote started!\n");
	}
}

void resetVoteTimer()
{
	g_next_invasion_wave = g_Engine.time + g_vote_time;
	updateWaveTimer();
	tallyVotes();
}

void startGame()
{
	g_vote_state = 0;
	waiting_for_voters = false;
	
	g_Scheduler.SetTimeout("spawn_airdrop", g_airdrop_first_delay*60);
	if (!g_invasion_mode)
		g_Scheduler.SetTimeout("spawn_heli", g_apache_first_delay*60);
	g_Scheduler.SetInterval("inventoryCheck", 0.1);
	g_Scheduler.SetInterval("cleanup_map", 60);
	g_Scheduler.SetTimeout("showGameModeTip", 3);
	game_started = true;
	
	day_night_cycle.start();
	
	g_EntityFuncs.FireTargets("vote_spawn", null, null, USE_OFF);
	equipAllPlayers();	
	g_PlayerFuncs.RespawnAllPlayers(true, true);
	
	CBaseEntity@ ent = null;
	do {
		@ent = g_EntityFuncs.FindEntityByTargetname(ent, "wawa");
		if (ent !is null)
			ent.pev.effects &= ~EF_NODRAW;
	} while (ent !is null);
	
	if (g_invasion_mode) {
		g_PlayerFuncs.SayTextAll(getAnyPlayer(), "Invasion starts in " + g_invasion_initial_delay + " minutes\n");
		updateWaveTimer();
	}
}

void showGameModeTip()
{
	//PrintKeyBindingStringAllLong("TIP:\n\nPress +missionbriefing to learn how to play");
	if (g_invasion_mode)
	{
		PrintKeyBindingStringAllLong("Build a base before the invasion starts.\n\nYou lose when your base is destroyed.");
	}

	g_Scheduler.SetTimeout("PrintKeyBindingStringAllLong", 20.0f, "TIP: Press +missionbriefing to learn how to do stuff");
	g_Scheduler.SetTimeout("showTipAll", 7.0f, int(TIP_ACTION_MENU));
}

void setupInvasionMode()
{
	if (g_invasion_mode) {
		return;
	}
	g_invasion_mode = true;
	g_free_build = false;
	g_build_anywhere = false;
	
	disableFriendlyFire();
	
	if (g_difficulty == 0)
		g_invasion_delay = g_invasion_initial_delay = 8.0f;
	if (g_difficulty == 1)
		g_invasion_delay = g_invasion_initial_delay = 6.0f;
	if (g_difficulty == 2)
		g_invasion_delay = g_invasion_initial_delay = 5.0f;
		
	//g_invasion_delay = g_invasion_initial_delay = 0.5f;
	
	g_zone_info.init();
	g_EntityFuncs.FireTargets("zone_clip", null, null, USE_TOGGLE);
	int rand = Math.RandomLong(0, g_build_zone_ents.size()-1);
	CBaseEntity@ randomZoneEnt = g_build_zone_ents[rand];
	func_build_zone@ randomZone = cast<func_build_zone@>(CastToScriptClass(randomZoneEnt));
	g_invasion_zone = randomZoneEnt;
	println("Starting invasion mode in zone " + randomZone.id);
	
	for (uint i = 0; i < g_build_zone_ents.size(); i++)
	{
		func_build_zone@ zone = cast<func_build_zone@>(CastToScriptClass(g_build_zone_ents[i].GetEntity()));
		zone.Clear();
		randomZone.UpdateNodeRatios();
		if (zone.id != randomZone.id)
			zone.Disable();
	}
	
	CBaseEntity@ ent = null;
	do {
		@ent = g_EntityFuncs.FindEntityByTargetname(ent, "zone_spawn");
		if (ent !is null)
		{
			if (getBuildZone(ent) == randomZone.id)
				ent.Use(null, null, USE_ON);
			else
				ent.Use(null, null, USE_OFF);
		}
	} while (ent !is null);
	
	g_invasion_round = 0;
	g_next_invasion_wave = 3.0f + g_Engine.time + g_invasion_initial_delay*60;
	g_Scheduler.SetTimeout("spawnInvasionWave", g_next_invasion_wave-g_Engine.time);
	
	g_Scheduler.SetTimeout("startGame", 3.0f);
	g_Scheduler.SetTimeout("updateWaveStatus", 3.0f);
}

void setupPvpMode()
{
	g_invasion_mode = false;
	g_free_build = false;
	g_build_anywhere = false;
	
	g_EntityFuncs.FireTargets("zone_spawn", null, null, USE_ON);
	
	g_Scheduler.SetTimeout("startGame", 3.0f);
}

void disableFriendlyFire()
{
	g_friendly_fire = false;
	CBaseEntity@ ent = null;
	do {
		@ent = g_EntityFuncs.FindEntityByClassname(ent, "*");
		if (ent !is null and string(ent.pev.classname).StartsWith("weapon_custom_")) {
			ent.KeyValue("friendly_fire", "0");
		}
	} while (ent !is null);
}

void setupCreativeMode()
{
	g_invasion_mode = false;
	g_free_build = true;
	g_creative_mode = true;
	g_build_anywhere = false;
	
	disableFriendlyFire();

	g_EntityFuncs.FireTargets("zone_spawn", null, null, USE_ON);
	
	g_Scheduler.SetTimeout("startGame", 3.0f);
}

array<string> invasion_waves = {"babyvolt_spawner", "zombie_spawner", "pitdrone_spawner", "slave_spawner",
								"bullsquid_spawner", "controller_spawner", "houndeye_spawner", "gonome_spawner", 
								"babygarg_spawner", "trooper_spawner", "agrunt_spawner", "volt_spawner", 
								"garg_spawner", "kingpin_spawner"};
array<string> invasion_wave_titles = {"Baby Voltigores", "Zombie Barneys", "Pit Drones", "Alien Slaves",
								"Bullsquids", "Alien Controllers", "Houndeyes", "Gonomes", "Baby Gargs", "Shock Troopers", 
								"Alien Grunts", "Voltigores", "Gargantuas", "Kingpins"};

void clearTimer()
{
	HUDNumDisplayParams params;
	params.channel = 0;
	params.flags = HUD_ELEM_HIDDEN;
	g_PlayerFuncs.HudTimeDisplay( null, params );
}

// thanks th_escape for le codes :>
void updateWaveTimer()
{
	if (g_invasion_mode or (g_vote_state > 0 and !waiting_for_voters)) {
		g_Scheduler.SetTimeout("updateWaveTimer", 1.0f);
	} else {
		return;
	}
	
	HUDNumDisplayParams params;
	
	params.channel = 0;
	
	params.flags = HUD_ELEM_SCR_CENTER_X | HUD_ELEM_DEFAULT_ALPHA |
		HUD_TIME_MINUTES | HUD_TIME_SECONDS | HUD_TIME_COUNT_DOWN;
	
	float timeLeft = g_next_invasion_wave - g_Engine.time;
	params.value = timeLeft;
	
	params.x = 0;
	params.y = 0.06;

	params.color1 = RGBA_SVENCOOP;
	
	if ( (g_invasion_mode and timeLeft < 60) or (g_vote_state > 0 and timeLeft < 5))
	{
		params.flags |= HUD_TIME_MILLISECONDS;
		params.color1 = RGBA_RED;
	}
	
	params.spritename = "stopwatch";
	
	g_PlayerFuncs.HudTimeDisplay( null, params );
}

bool checkWaveStatus()
{
	func_build_zone@ zone = cast<func_build_zone@>(CastToScriptClass(g_invasion_zone.GetEntity()));
	return zone.monstersAreAlive();
}

void invasionLose()
{
	g_EntityFuncs.FireTargets("game_over_sound", null, null, USE_TOGGLE);
	g_EntityFuncs.FireTargets("game_over", null, null, USE_TOGGLE);
}

void equipAllPlayers()
{
	CBaseEntity@ ent = null;
	do {
		@ent = g_EntityFuncs.FindEntityByClassname(ent, "player");
		if (ent !is null and ent.IsAlive()) {
			CBasePlayer@ plr = cast<CBasePlayer@>(ent);
			plr.RemoveAllItems(false);
			equipPlayer(plr);
		}
	} while (ent !is null);
}

void updateWaveStatus()
{
	bool old_state = g_wave_in_progress;
	g_wave_in_progress = checkWaveStatus();
	if (!g_wave_in_progress and old_state)
	{
		g_PlayerFuncs.SayTextAll(getAnyPlayer(), "Wave defeated. " + invasion_wave_titles[g_invasion_round] + " are coming next.");
	}
	
	if (g_wave_in_progress and g_build_parts.length() == 0)
	{
		g_PlayerFuncs.ScreenFadeAll(Vector(32,0,0), 3.0f, 255.0f, 255, FFADE_OUT);
		g_EntityFuncs.FireTargets("game_over_text", null, null, USE_TOGGLE);
		g_Scheduler.SetTimeout("invasionLose", 6.0f);
		return;
	}
	
	bool isFinalWave = g_invasion_round >= int(invasion_waves.size())-1;
	
	if (!g_wave_in_progress and isFinalWave and !finished_invasion)
	{
		finished_invasion = true;
		
		equipAllPlayers();
		
		g_PlayerFuncs.SayTextAll(getAnyPlayer(), "You win! Destroy what's left of your base to end the game.\n");
		g_EntityFuncs.FireTargets("game_win_sound", null, null, USE_TOGGLE);
		for (uint i = 0; i < g_build_parts.length(); i++)
		{
			CBaseEntity@ ent = g_build_parts[i].GetEntity();
			if (ent is null) {
				g_build_parts.removeAt(i);
				i--;
				continue;
			}
			ent.pev.health = 1;
			ent.pev.max_health = 1;
		}
	}
	
	if (finished_invasion and g_build_parts.length() == 0)
	{
		g_EntityFuncs.FireTargets("game_over", null, null, USE_TOGGLE);
	}
	
	g_Scheduler.SetTimeout("updateWaveStatus", 2.0f);
}

void spawnInvasionWave()
{	
	func_build_zone@ zone = cast<func_build_zone@>(CastToScriptClass(g_invasion_zone.GetEntity()));

	bool isFinalWave = g_invasion_round >= int(invasion_waves.size())-1;
	
	float extrahealth = zone.SpawnInvasionWave(invasion_waves[g_invasion_round]);
	string penalty = "";
	if (extrahealth > 0) { 
		penalty = " (+" + extrahealth + " health from living monsters in previous wave)";
	}
	
	g_PlayerFuncs.SayTextAll(getAnyPlayer(), "Wave " + (g_invasion_round+1) + " - " + invasion_wave_titles[g_invasion_round] + penalty + "\n");
	
	g_invasion_round++;
	
	if (isFinalWave)
	{
		g_PlayerFuncs.SayTextAll(getAnyPlayer(), "Final wave! Kill all monsters to win.\n");
		clearTimer();
	}
	else
	{
		g_Scheduler.SetTimeout("spawnInvasionWave", g_invasion_delay*60);
		g_next_invasion_wave = g_Engine.time + g_invasion_delay*60;
	}
}

void dropNodes()
{
	// place nodes on the ground (they're in the sky cause i'm too lazy to do this myself)
	int count = 0;
	CBaseEntity@ ent = null;
	do {
		@ent = g_EntityFuncs.FindEntityByTargetname(ent, "node_pos");
		if (ent !is null) {
			TraceResult tr;
			g_Utility.TraceLine( ent.pev.origin, ent.pev.origin + Vector(0,0,-8192), ignore_monsters, null, tr );
			Vector nodePos = tr.vecEndPos + Vector(0,0,1);
			g_EntityFuncs.SetOrigin(ent, nodePos);
			
			/*
			int zone = getBuildZone(ent);
			ent.pev.team = zone;
			if (zone >= 0 and zone < int(g_build_zone_ents.length()))
			{
				println("Assigned node to zone " + ent.pev.team);
				func_build_zone@ zoneEnt = cast<func_build_zone@>(CastToScriptClass(g_build_zone_ents[zone]));
				zoneEnt.ainodes.insertLast(nodePos);
			}
			else
				println("Node at " + ent.pev.origin.ToString() + " not assigned to a build zone");
			*/
			
			dictionary keys;
			keys["origin"] = nodePos.ToString();
			g_EntityFuncs.CreateEntity("info_node", keys, true);
			
			keys["origin"] = (nodePos + Vector(0,0,512)).ToString();
			g_EntityFuncs.CreateEntity("info_node_air", keys, true);
			
			g_EntityFuncs.Remove(ent);
			
			count++;
		}
	} while (ent !is null);
	
	//println("Dropped " + count + " nodes");
}

void removeExtraEnts()
{
	// TODO?
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

void monster_node(EHandle h_mon)
{
	if (!h_mon.IsValid())
		return;
		
	CBaseEntity@ mon = h_mon;
	if (mon.pev.deadflag == DEAD_DEAD)
	{
		dictionary keys; 
		keys["origin"] = mon.pev.origin.ToString();
		keys["model"] = string(mon.pev.model);
		keys["min"] = mon.pev.mins.ToString();
		keys["max"] = mon.pev.maxs.ToString();
		keys["material"] = "1";
		keys["health"] = "" + mon.pev.max_health;
		keys["colormap"] = "-1";
		keys["message"] = "node";
		keys["nodetype"] = "" + NODE_XEN;
		
		CBaseEntity@ ent = g_EntityFuncs.CreateEntity("func_breakable_custom", keys, false);
		func_breakable_custom@ cent = cast<func_breakable_custom@>(CastToScriptClass(ent));
		cent.monster = mon;
		g_EntityFuncs.DispatchSpawn(ent.edict());
		mon.pev.solid = SOLID_NOT;
		return;
	}
	g_Scheduler.SetTimeout("monster_node", 0, h_mon);
}

void monster_spawned(CBaseEntity@ pActivator, CBaseEntity@ pCaller, USE_TYPE useType, float flValue)
{	
	
}

void monster_killed(CBaseEntity@ pActivator, CBaseEntity@ pCaller, USE_TYPE useType, float flValue)
{	
	if (pCaller.pev.classname == "monster_apache")
		heli_die(pCaller);
}

void equipPlayer(CBasePlayer@ plr)
{
	if (g_vote_state > 0) 
	{
		plr.GiveNamedItem("weapon_guitar", 0, 0);
		return;
	}
	plr.GiveNamedItem("weapon_rock", 0, 0);
	if (g_creative_mode)
	{
		plr.GiveNamedItem("weapon_building_plan", 0, 0);
		plr.GiveNamedItem("weapon_hammer", 0, 0);
		plr.GiveNamedItem("weapon_guitar", 0, 0);
		plr.GiveNamedItem("weapon_custom_crowbar", 0, 0);
		plr.GiveNamedItem("weapon_custom_deagle", 0, 0);
		plr.GiveNamedItem("weapon_bow", 0, 0);
		plr.GiveNamedItem("weapon_metal_hatchet", 0, 0);
		plr.GiveNamedItem("weapon_metal_pickaxe", 0, 0);
		plr.GiveNamedItem("weapon_flamethrower", 0, 0);
		plr.GiveNamedItem("weapon_custom_sniper", 0, 0);
		plr.GiveNamedItem("weapon_custom_saw", 0, 100);
		plr.GiveNamedItem("weapon_custom_grenade", 0, 5);
		giveItem(plr, I_9MM, 250, false, true, true);
		giveItem(plr, I_556, 600, false, true, true);
		giveItem(plr, I_ARROW, 100, false, true, true);
		giveItem(plr, I_BUCKSHOT, 50, false, true, true);
		giveItem(plr, I_ROCKET, 5, false, true, true);
		giveItem(plr, I_FUEL, 200, false, true, true);
		giveItem(plr, I_GRENADE, 10, false, true, true);
		plr.pev.armorvalue = 100;
		plr.pev.health = 100;
	}
	else if (finished_invasion)
	{
		plr.GiveNamedItem("weapon_custom_saw", 0, 0);
		plr.GiveNamedItem("weapon_custom_rpg", 0, 0);
		plr.GiveNamedItem("weapon_custom_flamethrower", 0, 0);
		giveItem(plr, I_556, 200, false, true, true);
		giveItem(plr, I_ROCKET, 5, false, true, true);
		giveItem(plr, I_FUEL, 200, false, true, true);
	}
}

void player_respawn(CBaseEntity@ pActivator, CBaseEntity@ pCaller, USE_TYPE useType, float flValue)
{
	if (!pCaller.IsPlayer())
		return;
	CBasePlayer@ plr = cast<CBasePlayer@>(pCaller);
	equipPlayer(plr);
	activateCorpses(plr);
	clearInventory(plr);
	PlayerState@ state = getPlayerState(plr);
	state.updateItemList();
	for (uint i = 0; i < state.beds.length(); i++)
	{
		if (!state.beds[i].IsValid())
		{
			state.beds.removeAt(i);
			i--;
			continue;
		}
		plr.pev.origin = state.beds[i].GetEntity().pev.origin + Vector(0,0,40);
	}
	
	if (game_started)
	{
		if (state.tips & TIP_ACTION_MENU == 0)
			g_Scheduler.SetTimeout("showTip", 2.0f, EHandle(pCaller), int(TIP_ACTION_MENU));
		else if (state.tips & TIP_LOOT == 0)
			g_Scheduler.SetTimeout("showTip", 2.0f, EHandle(pCaller), int(TIP_LOOT));
		else if (state.tips & TIP_ARMOR == 0)
			g_Scheduler.SetTimeout("showTip", 2.0f, EHandle(pCaller), int(TIP_ARMOR));
	}
	
	// Monster angry -> hate player, dislike bases
	// apache -> dislike player, ignore bases, ignore unarmed players
	plr.SetClassification(CLASS_PLAYER); // monsters will give this higher priority
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

void cleanup_map()
{
	array<EHandle> orphans;
	CBaseEntity@ ent = null;
	do {
		@ent = g_EntityFuncs.FindEntityByClassname(ent, "item_inventory");
		if (ent !is null) {
			CBaseEntity@ owner = g_EntityFuncs.Instance( ent.pev.owner );
			if (owner is null and ent.pev.effects != EF_NODRAW)
			{
				bool orphan = true;
				for (uint i = 0; i < g_item_drops.size(); i++)
				{
					if (!g_item_drops[i].IsValid())
						continue;
					if (g_item_drops[i].GetEntity().entindex() == ent.entindex())
					{
						orphan = false;
						break;
					}
				}
				if (orphan)
				{
					int type = ent.pev.colormap-1;
					string details = "";
					if (type >= 0 and type < int(g_items.size()))
					{
						details += " " + g_items[type].title + " x" + ent.pev.button;
					}
					orphans.insertLast(EHandle(ent));
					println("Found orphaned item at " + ent.pev.origin.ToString() + " " + details);
				}
			}
		}
	} while (ent !is null);
	
	for (uint i = 0; i < orphans.size(); i++)
		g_EntityFuncs.Remove(orphans[i]);
}

bool doRustCommand(CBasePlayer@ plr, const CCommand@ args)
{
	PlayerState@ state = getPlayerState(plr);
	bool isAdmin = g_PlayerFuncs.AdminLevel(plr) >= ADMIN_YES;
	
	if ( args.ArgC() > 0 )
	{
		if (args[0] == ".version")
		{
			g_PlayerFuncs.SayText(plr, "Script version: v6 (August 24, 2018)");
			return true;
		}
		if (args[0] == ".save")
		{
			if (!isAdmin)
			{
				g_PlayerFuncs.SayText(plr, "You don't have access to that command, peasent\n");
				return true;
			}
			g_PlayerFuncs.SayTextAll(plr, "Saving map state (expect server lag)\n");
			g_Scheduler.SetTimeout("saveMapData", 0.5f);
			return true;
		}
		if (args[0] == ".load")
		{
			if (!isAdmin)
			{
				g_PlayerFuncs.SayText(plr, "You don't have access to that command, peasent\n");
				return true;
			}
			g_PlayerFuncs.SayTextAll(plr, "Loading map state\n");
			loadMapData();
			return true;
		}
		if (args[0] == ".airdrop")
		{
			if (!isAdmin)
			{
				g_PlayerFuncs.SayText(plr, "You don't have access to that command, peasent\n");
				return true;
			}
			spawn_airdrop();
			return true;
		}
		if (args[0] == ".vis")
		{
			if (!isAdmin)
			{
				g_PlayerFuncs.SayText(plr, "You don't have access to that command, peasent\n");
				return true;
			}
			printVisibleEnts(plr);
			return true;
		}
		if (args[0] == ".item")
		{
			if (!isAdmin)
			{
				g_PlayerFuncs.SayText(plr, "You don't have access to that command, peasent\n");
				return true;
			}
			if (!plr.IsAlive() or plr.pev.flags & FL_NOTARGET != 0)
			{
				g_PlayerFuncs.SayText(plr, "Can't spawn items when dead or if notarget is enabled");
				return true;
			}
			if (args.ArgC() > 2)
			{
				string name = args[1];
				int amt = atoi(args[2]);
				Item@ item = null;
				for (uint i = 0; i < g_items.size(); i++)
				{
					string title = g_items[i].title;
					string titleLower = title.ToLowercase();
					string nameLower = name.ToLowercase();
					string cnameLower = string(g_items[i].classname).ToLowercase();
					if (cnameLower == nameLower or titleLower == nameLower)
					{
						@item = @g_items[i];
						break;
					}
					if (int(cnameLower.Find(nameLower)) != -1 or int(titleLower.Find(nameLower)) != -1)
						@item = @g_items[i];
				}
				if (item !is null)
				{
					giveItem(plr, item.type, amt, false, true, true);
					g_PlayerFuncs.SayTextAll(plr, "" + plr.pev.netname + " gave " + amt + " " + item.title + " to self");
				}
			}
			return true;
		}
		if (args[0] == ".clean")
		{
			if (!isAdmin)
			{
				g_PlayerFuncs.SayText(plr, "You don't have access to that command, peasent\n");
				return true;
			}
			println("Cleanup started");
			cleanup_map();
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
		if (args[0] == ".breakall")
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
				//if (bpart.zoneid == state.home_zone)
				{
					g_Scheduler.SetTimeout("breakPart", delay, parts[i]);
					delay += 0.1f;
					count++;
				}
			}
			
			if (count > 0)
				g_PlayerFuncs.SayText(plr, "Destroying parts built by you\n");
			else
				g_PlayerFuncs.SayText(plr, "You haven't built any parts\n");
			
			
			state.lastBreakAll = g_Engine.time + delay;
			return true;
		}
		/*
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
			state.leaveTeam();
			return true;
		}
		if (args[0] == ".teams")
		{
			bool anyActive = false;
			for (uint i = 0; i < g_teams.size(); i++)
			{
				string msg = "Team " + i + ": ";
				for (uint k = 0; k < g_teams[i].members.size(); k++)
				{
					msg += g_teams[i].members[k] + ", ";
				}
				anyActive = true;
				msg = msg.SubString(0, msg.Length()-2);
				g_PlayerFuncs.SayText(plr, msg);
			}
			if (!anyActive)
				g_PlayerFuncs.SayText(plr, "No active teams");
			return true;
		}
		if (args[0] == ".home")
		{
			if (state.home_zone != -1)
				g_PlayerFuncs.SayText(plr, "Your home is zone " + state.home_zone + "\n");
			else
				g_PlayerFuncs.SayText(plr, "You don't have a home. You can settle in any zone.\n");
			return true;
		}
		*/
		if (args[0] == ".mode")
		{
			string msg = "";
			if (g_creative_mode)
				msg = "Game mode: Creative";
			else if (g_invasion_mode)
			{
				msg = "Game mode: Co-op (";
				if (g_difficulty == 0)
					msg += "easy";
				else if (g_difficulty == 1)
					msg += "medium";
				else if (g_difficulty == 2)
					msg += "hard";
				else
					msg += "unknown difficulty";
				msg += ")";
			}
			else
				msg = "Game mode: PvP";
			g_PlayerFuncs.SayText(plr, msg + "\n");
			return true;
		}
		if (args[0] == ".nodes")
		{
			if (!isAdmin)
			{
				g_PlayerFuncs.SayText(plr, "You don't have access to that command, peasent\n");
				return true;
			}
			g_disable_ents = !g_disable_ents;
			g_PlayerFuncs.SayTextAll(plr, "Nodes spawns are " + (g_disable_ents ? "disabled" : "enabled"));
			return true;
		}
		if (args[0] == ".lag")
		{
			if (!isAdmin)
			{
				g_PlayerFuncs.SayText(plr, "You don't have access to that command, peasent\n");
				return true;
			}
			
			int cleared = 0;
			for (uint i = 0; i < g_build_zone_ents.size(); i++)
			{
				func_build_zone@ zone = cast<func_build_zone@>(CastToScriptClass(g_build_zone_ents[i].GetEntity()));
				cleared += zone.ClearMonsters();
			}
			
			g_PlayerFuncs.SayTextAll(plr, "Removed " + cleared + " monsters to fix lag caused by AI navigation");
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
					g_SoundSystem.PlaySound(ent.edict(), CHAN_ITEM, fixPath("sc_rust/code_lock_update.ogg"), 1.0f, 1.0f, 0, 100);
					state.authedLocks.insertLast(state.currentLock);
				} 
				else // guest is unlocking
				{ 
					if (code == ent.pev.noise3) {
						PrintKeyBindingStringLong(plr, "Code accepted");
						g_SoundSystem.PlaySound(ent.edict(), CHAN_ITEM, fixPath("sc_rust/code_lock_update.ogg"), 1.0f, 1.0f, 0, 100);
						state.authedLocks.insertLast(state.currentLock);
					} else {
						PrintKeyBindingStringLong(plr, "Incorrect code");
						g_SoundSystem.PlaySound(ent.edict(), CHAN_ITEM, fixPath("sc_rust/code_lock_shock.ogg"), 1.0f, 1.0f, 0, 100);
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
	if (g_vote_state > 0) {
		return HOOK_CONTINUE;
	}
	PlayerState@ state = getPlayerState(plr);
	state.inGame = false;
	state.resumeOnJoin = true;
	state.leaveTeam();
	
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
	
	g_Scheduler.SetTimeout("cleanup_map", 1);
	
	return HOOK_CONTINUE;
}

HookReturnCode ClientJoin(CBasePlayer@ plr)
{
	if (plr is null)
		return HOOK_CONTINUE;
		
	if (g_vote_state > 0 and !waiting_for_voters) {
		resetVoteTimer();
		return HOOK_CONTINUE;
	}
		
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