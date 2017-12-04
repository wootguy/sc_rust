#include "utils"

float EPSILON = 0.03125f;
int BUILD_MATERIAL = I_WOOD; // material needed to build stuff

class BuildPartInfo
{
	int type;
	string copy_ent;
	string title;
	int cost; // material needed to build
	
	BuildPartInfo() {
		type = -1;
	}
	
	BuildPartInfo(int t, string tit, string copy, int matCost) {
		type = t;
		copy_ent = copy;
		title = tit;
		cost = matCost;
	}
}

class Item
{
	int type;
	int stackSize;
	bool isWeapon;
	bool isAmmo;
	string title;
	string desc;
	string classname;
	
	Item() {
		type = -1;
		stackSize = 1;
	}
	
	Item(int t, int stackSz, bool wep, bool ammo, string cname, string tit, string description) {
		type = t;
		stackSize = stackSz;
		title = tit;
		desc = description;
		isWeapon = wep;
		isAmmo = ammo;
		classname = cname;
	}
}

enum build_types
{
	B_FOUNDATION = 0,
	B_FOUNDATION_TRI,
	B_WALL,
	B_DOORWAY,
	B_WINDOW,
	B_LOW_WALL,
	B_FLOOR,
	B_FLOOR_TRI,
	B_ROOF,
	B_STAIRS,
	B_STAIRS_L,
	B_FOUNDATION_STEPS,
	
	B_WOOD_DOOR,
	B_METAL_DOOR,
	B_WOOD_BARS,
	B_METAL_BARS,
	B_WOOD_SHUTTERS,
	B_CODE_LOCK,
	B_TOOL_CUPBOARD,
	B_HIGH_WOOD_WALL,
	B_HIGH_STONE_WALL,
	B_LADDER,
	B_LADDER_HATCH,
	B_SMALL_CHEST,
	B_LARGE_CHEST,
	B_FURNACE,
	
	B_ITEM_TYPES,
};

int B_TYPES = B_FOUNDATION_STEPS+1;

enum item_types
{
	I_WOOD_DOOR = 0,
	I_METAL_DOOR,
	I_WOOD_BARS,
	I_METAL_BARS,
	I_WOOD_SHUTTERS,
	I_CODE_LOCK,
	I_TOOL_CUPBOARD,
	I_HIGH_WOOD_WALL,
	I_HIGH_STONE_WALL,
	I_LADDER,
	I_LADDER_HATCH,
	I_SMALL_CHEST,
	I_LARGE_CHEST,
	I_FURNACE,
	
	I_WOOD,
	I_STONE,
	I_METAL,
	I_HQMETAL,
	I_METAL_ORE,
	I_HQMETAL_ORE,
	I_HAMMER,
	I_BUILDING_PLAN,
	I_ROCK,
	I_STONE_HATCHET,
	I_STONE_PICKAXE,
	I_METAL_HATCHET,
	I_METAL_PICKAXE,
	I_BOW,
	I_SYRINGE,
	I_FLAMETHROWER,
	I_SAW,
	
	I_ARROW,
	I_FUEL,
	I_556,
	
	ITEM_TYPES,
};

enum socket_types
{
	SOCKET_FOUNDATION = 0,
	SOCKET_MIDDLE,
	SOCKET_WALL,
	SOCKET_DOORWAY,
	SOCKET_DOOR,
	SOCKET_WINDOW,
	SOCKET_HIGH_WALL,
};

enum builder_status
{
	STATUS_RAIDER = 0,
	STATUS_SETTLER,
	STATUS_OUTSKIRTS,
}

array<BuildPartInfo> g_part_info = {
	BuildPartInfo(B_FOUNDATION, "Square Foundation", "b_foundation", 200),
	BuildPartInfo(B_FOUNDATION_TRI, "Triangle Foundation", "b_foundation_tri", 100),
	BuildPartInfo(B_WALL, "Wall", "b_wall", 200),
	BuildPartInfo(B_DOORWAY, "Doorway", "b_doorway", 140),
	BuildPartInfo(B_WINDOW, "Window", "b_window", 140),
	BuildPartInfo(B_LOW_WALL, "Low Wall", "b_low_wall", 100),
	BuildPartInfo(B_FLOOR, "Square Floor", "b_floor", 100),
	BuildPartInfo(B_FLOOR_TRI, "Triangle Floor", "b_floor_tri", 50),
	BuildPartInfo(B_ROOF, "Roof", "b_roof", 200),
	BuildPartInfo(B_STAIRS, "Stairs (U-shape)", "b_stairs", 200),
	BuildPartInfo(B_STAIRS_L, "Stairs (L-shape)", "b_stairs_l", 200),
	BuildPartInfo(B_FOUNDATION_STEPS, "Foundation Steps", "b_foundation_steps", 100),
	
	BuildPartInfo(B_WOOD_DOOR, "Wood Door", "b_wood_door", 0),
	BuildPartInfo(B_METAL_DOOR, "Metal Door", "b_metal_door", 0),
	BuildPartInfo(B_WOOD_BARS, "Wood Window Bars", "b_wood_bars", 0),
	BuildPartInfo(B_METAL_BARS, "Metal Window Bars", "b_metal_bars", 0),
	BuildPartInfo(B_WOOD_SHUTTERS, "Wood Shutters", "b_wood_shutters", 0),
	BuildPartInfo(B_CODE_LOCK, "Code Lock", "b_code_lock", 0),
	BuildPartInfo(B_TOOL_CUPBOARD, "Tool Cupboard", "b_tool_cupboard", 0),
	BuildPartInfo(B_HIGH_WOOD_WALL, "High External Wood Wall", "b_high_wood_wall", 0),
	BuildPartInfo(B_HIGH_STONE_WALL, "High External Stone Wall", "b_high_stone_wall", 0),
	BuildPartInfo(B_LADDER, "Ladder", "b_ladder", 0),
	BuildPartInfo(B_LADDER_HATCH, "Ladder Hatch", "b_ladder_hatch", 0),
	BuildPartInfo(B_SMALL_CHEST, "Small Chest", "b_small_chest", 0),
	BuildPartInfo(B_LARGE_CHEST, "Large Chest", "b_large_chest", 0),
	BuildPartInfo(B_FURNACE, "Furnace", "b_furnace", 0),
};

array<Item> g_items = {	
	Item(I_WOOD_DOOR, 1, false, false, "", "Wood Door", "A hinged door which is made out of wood."),
	Item(I_METAL_DOOR, 1, false, false, "", "Metal Door", "A hinged door which is made out of metal."),
	Item(I_WOOD_BARS, 1, false, false, "", "Wood Window Bars", "b_wood_bars"),
	Item(I_METAL_BARS, 1, false, false, "", "Metal Window Bars", "b_metal_bars"),
	Item(I_WOOD_SHUTTERS, 1, false, false, "", "Wood Shutters", "b_wood_shutters"),
	Item(I_CODE_LOCK, 1, false, false, "", "Code Lock", "An electronic lock. Locked and unlocked with four-digit code. Hold your USE key while looking at the lock to activate it."),
	Item(I_TOOL_CUPBOARD, 1, false, false, "", "Tool Cupboard", "Only players authorized to this cupboard will be able to build near it.\nPress USE to authorize yourself and hold USE to clear previous authorizations."),
	Item(I_HIGH_WOOD_WALL, 1, false, false, "", "High External Wood Wall", "b_wood_wall"),
	Item(I_HIGH_STONE_WALL, 1, false, false, "", "High External Stone Wall", "b_stone_wall"),
	Item(I_LADDER, 1, false, false, "", "Ladder", "b_ladder"),
	Item(I_LADDER_HATCH, 1, false, false, "", "Ladder Hatch", "b_ladder_hatch"),
	Item(I_SMALL_CHEST, 1, false, false, "", "Small Chest", "Keep your things in this storage box. Stores up to " + CHEST_ITEM_MAX_SMALL + " items."),
	Item(I_LARGE_CHEST, 1, false, false, "", "Large Chest", "Keep your things in this storage box. Stores up to " + CHEST_ITEM_MAX_LARGE + " items."),
	Item(I_FURNACE, 1, false, false, "", "Furnace", "Use this to smelt mined ore."),
	
	Item(I_WOOD, 200, false, false, "", "Wood", "Collected from trees and used to build bases and craft items."),
	Item(I_STONE, 1000, false, false, "", "Stone", "Collected from rocks and used to reinforce bases and craft items."),
	Item(I_METAL, 1000, false, false, "", "Metal", "Smelted from metal ore."),
	Item(I_HQMETAL, 100, false, false, "", "HQ Metal", "High quality metal smelted from HQ Metal Ore."),
	Item(I_METAL_ORE, 1000, false, false, "", "Metal Ore", "Collected from rocks. Smelt this in a furnace to produce Metal."),
	Item(I_HQMETAL_ORE, 100, false, false, "", "HQ Metal Ore", "Collected from rocks. Smelt this in a furnace to produce HQ Metal."),
	Item(I_HAMMER, 1, true, false, "weapon_hammer", "Hammer", "Used to upgrade, repair, and merge base parts."),
	Item(I_BUILDING_PLAN, 1, true, false, "weapon_building_plan", "Building Plan", "Used to craft buildings."),
	Item(I_ROCK, 1, true, false, "weapon_rock", "Rock", "The most basic melee weapon and gathering tool."),
	Item(I_STONE_HATCHET, 1, true, false, "weapon_stone_hatchet", "Stone Hatchet", "Use this to chop trees"),
	Item(I_STONE_PICKAXE, 1, true, false, "weapon_stone_pickaxe", "Stone Pickaxe", "Use this to mine rocks"),
	Item(I_METAL_HATCHET, 1, true, false, "weapon_metal_hatchet", "Metal Hatchet", "Effective tree chopper and melee weapon"),
	Item(I_METAL_PICKAXE, 1, true, false, "weapon_metal_pickaxe", "Metal Pickaxe", "Effective rock breaker and melee weapon"),
	Item(I_BOW, 1, true, false, "weapon_bow", "Hunting Bow", "Hard to aim with lag. Right-click to load and aim, left-click to fire."),
	Item(I_SYRINGE, 100, true, false, "weapon_syringe", "Syringe", "Right-click heals you, left-click heals a target."),
	Item(I_FLAMETHROWER, 1, true, false, "weapon_flamethrower", "Flame Thrower", "Effective against wood and flesh. Does not damage stone or metal."),
	Item(I_SAW, 1, true, false, "weapon_m249", "M249 SAW", "Powerful machine gun with a high firing rate and damage."),
	
	Item(I_ARROW, 64, false, true, "arrows", "Wooden Arrow", "Used with the hunting bow and crossbow."),
	Item(I_FUEL, 500, false, true, "fuel", "Fuel", "Used with the flame thrower."),
	Item(I_556, 128, false, true, "556", "5.56 Rifle Ammo", "Used with the saw and sniper rifle."),
};


class weapon_building_plan : ScriptBasePlayerWeaponEntity
{
	float m_flNextAnimTime;
	bool canShootAgain = false;
	CBaseEntity@ buildEnt = null;
	CBaseEntity@ buildEnt2 = null;
	CBaseEntity@ attachEnt = null;
	bool active = false;
	bool validBuild = false;
	bool forbidden = false;
	int buildType = B_FOUNDATION;
	float nextCycle = 0;
	float nextAlternate = 0;
	float lastHudUpdate = 0;
	int nextSnd = 0;
	int zoneid = -1;
	bool alternateBuild = false;
	
	void Spawn()
	{		
		Precache();
		g_EntityFuncs.SetModel( self, "models/sc_rust/w_blueprint.mdl" );

		//self.m_iDefaultAmmo = 0;
		//self.m_iClip = self.m_iDefaultAmmo;
		
		self.FallInit();
		SetThink( ThinkFunction( WeaponThink ) );
	}
	
	void Precache()
	{
		self.PrecacheCustomModels();
		g_Game.PrecacheModel( "models/sc_rust/w_blueprint.mdl" );
		g_Game.PrecacheModel( "models/sc_rust/p_blueprint.mdl" );
		g_Game.PrecacheModel( "models/sc_rust/v_blueprint.mdl" );
		
		PrecacheSound("sc_rust/build1.ogg");
		PrecacheSound("sc_rust/build2.ogg");
	}
	
	bool GetItemInfo( ItemInfo& out info )
	{				
		info.iMaxAmmo1 	= 20;
		info.iMaxAmmo2 	= -1;
		info.iMaxClip 	= 0;
		info.iSlot 		= 6;
		info.iPosition 	= 9;
		info.iFlags 	= 6;
		info.iWeight 	= 5;
		
		return true;
	}
	
	bool AddToPlayer( CBasePlayer@ pPlayer )
	{
		if( BaseClass.AddToPlayer( pPlayer ) == true )
		{
			NetworkMessage message( MSG_ONE, NetworkMessages::WeapPickup, pPlayer.edict() );
				message.WriteLong( self.m_iId );
			message.End();
			return true;
		}
		
		return false;
	}
	
	bool Deploy()
	{
		bool bResult = self.DefaultDeploy( self.GetV_Model( "models/sc_rust/v_blueprint.mdl" ), 
										   self.GetP_Model( "models/sc_rust/p_blueprint.mdl" ), 0, "trip" );
		
		createBuildEnts();
		
		active = true;
		
		return true;
	}
	
	void createBuildEnts()
	{
		if (buildEnt !is null) {
			g_EntityFuncs.Remove(buildEnt);
			@buildEnt = null;
		}
		if (buildEnt2 !is null) {
			g_EntityFuncs.Remove(buildEnt2);
			@buildEnt2 = null;
		}
		
		TraceResult look = TraceLook(getPlayer(), 280);
		string suffix = alternateBuild ? "" : "_twig";
		
		dictionary keys;
		keys["origin"] = (look.vecEndPos + Vector(0,0,16)).ToString();
		keys["model"] = getModelFromName(g_part_info[buildType].copy_ent + suffix);
		keys["rendermode"] = "1";
		keys["renderamt"] = "128";
		keys["rendercolor"] = "0 255 255";
		keys["colormap"] = "" + buildType;
			
		@buildEnt = g_EntityFuncs.CreateEntity("func_illusionary", keys, true);	
		
		keys["rendermode"] = "2";
		@buildEnt2 = g_EntityFuncs.CreateEntity("func_illusionary", keys, true);	
		buildEnt2.pev.scale = 0.5f;
		
		buildEnt.pev.movetype = MOVETYPE_NONE;
		buildEnt.pev.solid = SOLID_TRIGGER;
		//g_EntityFuncs.SetOrigin(buildEnt, buildEnt.pev.origin);
		
		// increment force_retouch
		//g_EntityFuncs.FireTargets("push", null, null, USE_TOGGLE);
		
		string cost = "\n\n(" + g_part_info[buildType].cost + " " + g_items[BUILD_MATERIAL].title + ")";
		
		g_PlayerFuncs.PrintKeyBindingString(getPlayer(), g_part_info[buildType].title + cost);
	}
	
	void Holster(int iSkipLocal = 0) 
	{
		active = false;
		if (buildEnt !is null) {
			g_EntityFuncs.Remove(buildEnt);
			@buildEnt = null;
		}
		if (buildEnt2 !is null) {
			g_EntityFuncs.Remove(buildEnt2);
			@buildEnt2 = null;
		}
	}
	
	float WeaponTimeBase()
	{
		return g_Engine.time; //g_WeaponFuncs.WeaponTimeBase();
	}
	
	void updateBuildPlaceholder()
	{
		CBasePlayer@ plr = getPlayer();
		
		@attachEnt = null;
		
		// show building placeholder
		if (buildEnt is null)
			return;
		
		TraceResult tr = TraceLook(getPlayer(), 160);
		Vector newOri = tr.vecEndPos;
		float newYaw = plr.pev.angles.y;
		float newPitch = buildEnt.pev.angles.x;
		CBaseEntity@ phit = g_EntityFuncs.Instance( tr.pHit );
		
		int partSocket = socketType(buildType);
		bool attaching = false;
		CBaseEntity@ skipCollide = null;
		
		validBuild = false;
					
		if (partSocket == SOCKET_HIGH_WALL)
		{
			if (phit.pev.classname == "worldspawn" and tr.flFraction < 1.0f) {
				validBuild = true;
			}
		
			g_EngineFuncs.MakeVectors(buildEnt.pev.angles);
			
			Vector left = tr.vecEndPos - g_Engine.v_right*128;
			Vector right = tr.vecEndPos + g_Engine.v_right*128;
			
			for (uint i = 0; i < g_build_parts.size(); i++)
			{	
				CBaseEntity@ part = g_build_parts[i].GetEntity();
				
				if (part is null or socketType(part.pev.colormap) != SOCKET_HIGH_WALL)
					continue;
					
				if ((part.pev.origin - buildEnt.pev.origin + Vector(0,0,120)).Length() > 500)
					continue;
				
				float attachDist = 64;
				g_EngineFuncs.MakeVectors(part.pev.angles);
				Vector attachLeft = part.pev.origin + g_Engine.v_right*-128 + Vector(0,0,-120);
				Vector attachRight = part.pev.origin + g_Engine.v_right*128 + Vector(0,0,-120);
				
				float ll = (attachLeft - left).Length();
				float lr = (attachLeft - right).Length();
				float rr = (attachRight - right).Length();
				float rl = (attachRight - left).Length();
				
				if (ll > attachDist and lr > attachDist and rr > attachDist and rl > attachDist)
					continue;
				
				if (attaching)
				{
					// can attach to two walls (bridging a gap)
					// just disable collision and let the player align it right
					// (but only if it's close enough to the end)
					@skipCollide = @part;
					break;
				}
				bool sameDir = false;
				if (ll < lr and ll < rr and ll < rl)
				{
					newOri = newOri + (attachLeft - left);
					attaching = true;
				}
				else if (lr < ll and lr < rr and lr < rl)
				{
					newOri = newOri + (attachLeft - right);
					attaching = true;
					sameDir = true;
				}
				else if (rr < ll and rr < lr and rr < rl)
				{
					newOri = newOri + (attachRight - right);
					attaching = true;
				}
				else if (rl < ll and rl < lr and rl < rr)
				{
					newOri = newOri + (attachRight - left);
					attaching = true;
					sameDir = true;
				}
				if (attaching)
				{
					float dot = DotProduct((attachLeft - attachRight).Normalize(), (left - right).Normalize());
					if (!sameDir)
						dot = -dot;
					
					if (dot > -0.55f)
					{
						validBuild = true;
						@phit = @part;
					}
					else
					{
						validBuild = false;
					}
				}
			}
			newOri.z += 120;
		}
		else if (partSocket == SOCKET_FOUNDATION or partSocket == SOCKET_WALL or buildType == B_FLOOR or 
				buildType == B_LADDER_HATCH or buildType == B_ROOF or partSocket == SOCKET_MIDDLE or
				partSocket == SOCKET_DOORWAY or partSocket == SOCKET_WINDOW or buildType == B_FLOOR_TRI)
		{
			g_EngineFuncs.MakeVectors(buildEnt.pev.angles);
			float bestDist = 9000;
			
			for (uint i = 0; i < g_build_parts.size(); i++)
			{	
				CBaseEntity@ part = g_build_parts[i].GetEntity();
				if (part is null)
					continue;
					
				int attachType = part.pev.colormap;
				int attachSocket = socketType(part.pev.colormap);
					
				if (partSocket == SOCKET_FOUNDATION and (part.pev.colormap != B_FOUNDATION and part.pev.colormap != B_FOUNDATION_TRI))
					continue;
				if ((partSocket == SOCKET_WALL or buildType == B_FLOOR or buildType == B_LADDER_HATCH or buildType == B_FLOOR_TRI) 
					and !isFloorPiece(part) and attachSocket != SOCKET_WALL)
					continue;
				if (buildType == B_ROOF and attachSocket != SOCKET_WALL)
					continue;
				if (partSocket == SOCKET_MIDDLE and !isFloorPiece(part))
					continue;
				if (partSocket == SOCKET_DOORWAY and attachType != B_DOORWAY)
					continue;
				if (partSocket == SOCKET_WINDOW and attachType != B_WINDOW)
					continue;
				if ((part.pev.origin - tr.vecEndPos).Length() > 256)
					continue;
				
				float attachDist = 96;
				if (partSocket == SOCKET_DOORWAY or partSocket == SOCKET_WINDOW)
					attachDist = 200;
				g_EngineFuncs.MakeVectors(part.pev.angles);
				
				Vector attachOri = tr.vecEndPos;
				float attachYaw = part.pev.angles.y;
				float minDist = 0;
				
				if (isFloorPiece(part) and partSocket != SOCKET_MIDDLE and 
					!((buildType == B_FLOOR or buildType == B_LADDER_HATCH or buildType == B_FLOOR_TRI) and 
					isFoundation(part)))
				{
					if (isTriangular(part))
					{
						// Tri mathematical properties:
						// Height = 110.851
						// Center point = 64, 36.95
						// edge mid point (relative to origin) = -32, 18.476
						// Actual brush properties are different, but using floats instead of ints in the export fucks this up somehow
						Vector left = part.pev.origin + g_Engine.v_right*-32 + g_Engine.v_forward*18.476;
						Vector right = part.pev.origin + g_Engine.v_right*32 + g_Engine.v_forward*18.476;
						Vector back = part.pev.origin + g_Engine.v_forward*-36.95;
						
						float dl = (left - tr.vecEndPos).Length();
						float dr = (right - tr.vecEndPos).Length();
						float db = (back - tr.vecEndPos).Length();
						
						if (dl > attachDist and dr > attachDist and db > attachDist)
							continue;
						if (dl > bestDist and dr > bestDist and db > bestDist)
							continue;
							
						float oriDist = 73.9;
						if (partSocket == SOCKET_WALL)
							oriDist = 36.95;
						if (buildType == B_FOUNDATION or buildType == B_FOUNDATION_STEPS or buildType == B_FLOOR or buildType == B_LADDER_HATCH)
							oriDist = 64 + 36.95;
						attachYaw = part.pev.angles.y;
						minDist = dl;
						if (dl < dr and dl < db)
						{
							attachOri = part.pev.origin + (left - part.pev.origin).Normalize()*oriDist;
							attachYaw = part.pev.angles.y + (buildType == B_FOUNDATION_TRI ? -60 : 60);
							minDist = dl;
						}
						else if (dr < dl and dr < db)
						{
							attachOri = part.pev.origin + (right - part.pev.origin).Normalize()*oriDist;
							attachYaw = part.pev.angles.y + (buildType == B_FOUNDATION_TRI ? 60 : -60);
							minDist = dr;
						}
						else if (db < dl and db < dr)
						{
							attachOri = part.pev.origin + g_Engine.v_forward*-oriDist;
							attachYaw = Math.VecToAngles(part.pev.origin - back).y + 180;
							minDist = db;
						}
						if (buildType == B_FOUNDATION_STEPS) {
							attachYaw += 180;
						}

					}
					else
					{
						Vector left = part.pev.origin + g_Engine.v_right*-64;
						Vector right = part.pev.origin + g_Engine.v_right*64;
						Vector front = part.pev.origin + g_Engine.v_forward*64;
						Vector back = part.pev.origin + g_Engine.v_forward*-64;
						
						float dl = (left - tr.vecEndPos).Length();
						float dr = (right - tr.vecEndPos).Length();
						float df = (front - tr.vecEndPos).Length();
						float db = (back - tr.vecEndPos).Length();
						
						if (dl > attachDist and dr > attachDist and df > attachDist and db > attachDist)
							continue;
						if (dl > bestDist and dr > bestDist and df > bestDist and db > bestDist)
							continue;
							
						float oriDist = 128;
						if (partSocket == SOCKET_WALL)
							oriDist = 64;
						if (isTriangular(buildEnt))
							oriDist = 36.95 + 64;
						attachYaw = part.pev.angles.y;
						minDist = dl;
						if (dl < dr and dl < df and dl < db)
						{
							attachOri = part.pev.origin + g_Engine.v_right*-oriDist;
							attachYaw = Math.VecToAngles(part.pev.origin - left).y;
							minDist = dl;
						}
						else if (dr < dl and dr < df and dr < db)
						{
							attachOri = part.pev.origin + g_Engine.v_right*oriDist;
							attachYaw = Math.VecToAngles(part.pev.origin - right).y;
							minDist = dr;
						}
						else if (df < dl and df < dr and df < db)
						{
							attachOri = part.pev.origin + g_Engine.v_forward*oriDist;
							attachYaw = Math.VecToAngles(part.pev.origin - front).y;
							minDist = df;
						}
						else if (db < dl and db < dr and db < df)
						{
							attachOri = part.pev.origin + g_Engine.v_forward*-oriDist;
							attachYaw = Math.VecToAngles(part.pev.origin - back).y;
							minDist = db;
						}
						if (isTriangular(buildEnt)) {
							attachYaw += 180;
						}
					}
				}
				else if (attachSocket == SOCKET_WALL and (buildType == B_FLOOR or buildType == B_LADDER_HATCH or buildType == B_FLOOR_TRI))
				{
					Vector front = part.pev.origin + g_Engine.v_forward*4 + Vector(0,0,128);
					Vector back = part.pev.origin + g_Engine.v_forward*-4 + Vector(0,0,128);
					float df = (front - tr.vecEndPos).Length();
					float db = (back - tr.vecEndPos).Length();
					
					if (df > attachDist and db > attachDist)
						continue;
					if (df > bestDist and db > bestDist)
						continue;
						
					attachYaw = part.pev.angles.y;
					float oriDist = buildType == B_FLOOR_TRI ? 36.95 : 64;
					minDist = df;
					if (df < db)
					{
						attachOri = part.pev.origin + g_Engine.v_forward*oriDist + Vector(0,0,128);
						attachYaw = Math.VecToAngles(part.pev.origin - front).y;
						minDist = df;
					}
					else if (db < df)
					{
						attachOri = part.pev.origin + g_Engine.v_forward*-oriDist + Vector(0,0,128);
						attachYaw = Math.VecToAngles(part.pev.origin - back).y;
						minDist = db;
					}
					
					if (buildType == B_FLOOR_TRI)
						attachYaw += 180;
				}
				else if (partSocket == SOCKET_DOORWAY and attachType == B_DOORWAY)
				{
					Vector front = part.pev.origin + g_Engine.v_forward*32 + Vector(0,0,64);
					Vector back = part.pev.origin + g_Engine.v_forward*-32 + Vector(0,0,64);
					float df = (front - tr.vecEndPos).Length();
					float db = (back - tr.vecEndPos).Length();
					
					if (df > attachDist or db > attachDist)
						continue;
					if (df > bestDist or db > bestDist)
						continue;
						
					attachYaw = part.pev.angles.y;
					minDist = df;
					if (df > db)
					{
						attachOri = part.pev.origin + g_Engine.v_right*-32 + Vector(0,0,64);
						attachYaw = Math.VecToAngles(part.pev.origin - front).y;
						minDist = df;
					}
					else if (db > df)
					{
						attachOri = part.pev.origin + g_Engine.v_right*32 + Vector(0,0,64);
						attachYaw = Math.VecToAngles(part.pev.origin - back).y;
						minDist = db;
					}
				}
				else if (partSocket == SOCKET_WINDOW and attachType == B_WINDOW)
				{
					Vector front = part.pev.origin + g_Engine.v_forward*32 + Vector(0,0,64);
					Vector back = part.pev.origin + g_Engine.v_forward*-32 + Vector(0,0,64);
					float df = (front - tr.vecEndPos).Length();
					float db = (back - tr.vecEndPos).Length();
					
					if (df > attachDist or db > attachDist)
						continue;
					if (df > bestDist or db > bestDist)
						continue;
						
					float oriDist = buildType == B_WOOD_SHUTTERS ? 4 : 0;
					attachYaw = part.pev.angles.y;
					minDist = df;
					if (df > db)
					{
						attachOri = part.pev.origin + g_Engine.v_forward*-oriDist + Vector(0,0,64);
						attachYaw = Math.VecToAngles(part.pev.origin - front).y;
						minDist = df;
					}
					else if (db > df)
					{
						attachOri = part.pev.origin + g_Engine.v_forward*oriDist + Vector(0,0,64);
						attachYaw = Math.VecToAngles(part.pev.origin - back).y;
						minDist = db;
					}
				}
				else if (attachSocket == SOCKET_WALL and attachType != B_LOW_WALL and buildType != B_ROOF) // stacking walls
				{
					Vector up = part.pev.origin + Vector(0,0,128);
					float du = (up - tr.vecEndPos).Length();
					
					if (du > attachDist or du > bestDist)
						continue;
						
					attachOri = up;
					attachYaw = part.pev.angles.y;
					minDist = du;
				}
				else if (attachSocket == SOCKET_WALL and attachType != B_LOW_WALL and buildType == B_ROOF) // roof
				{
					Vector front = part.pev.origin + g_Engine.v_forward*16 + Vector(0,0,128);
					Vector back = part.pev.origin + g_Engine.v_forward*-16 + Vector(0,0,128);
					float df = (front - tr.vecEndPos).Length();
					float db = (back - tr.vecEndPos).Length();
					
					//attachDist = 112;
					
					if (df > attachDist or db > attachDist)
						continue;
					if (df > bestDist or db > bestDist)
						continue;
						
					attachYaw = part.pev.angles.y;
					minDist = df;
					if (df < db)
					{
						attachOri = part.pev.origin + g_Engine.v_forward*64 + Vector(0,0,192);
						attachYaw = Math.VecToAngles(part.pev.origin - front).y;
						minDist = df;
					}
					else if (db < df)
					{
						attachOri = part.pev.origin + g_Engine.v_forward*-64 + Vector(0,0,192);
						attachYaw = Math.VecToAngles(part.pev.origin - back).y;
						minDist = db;
					}
				}
				else if (partSocket == SOCKET_MIDDLE and attachType == B_FOUNDATION or attachType == B_FLOOR)
				{
					Vector up = part.pev.origin + Vector(0,0,64);
					float du = (up - tr.vecEndPos).Length();
					
					if (du > attachDist or du > bestDist)
						continue;
						
					attachOri = up;
					minDist = du;
				}
				else
					continue;
					
				if (buildType == B_LADDER_HATCH or partSocket == SOCKET_MIDDLE and isFloorPiece(part))
				{
					// orient stairs according to where the player is looking
					Vector floor_forward = g_Engine.v_forward;
					Vector floor_right = g_Engine.v_right;
					
					g_EngineFuncs.MakeVectors(plr.pev.angles);
					Vector plr_forward = g_Engine.v_forward;
					plr_forward.z = 0;
					plr_forward.Normalize();
					
					float fdot = DotProduct(plr_forward, floor_forward);
					float rdot = DotProduct(plr_forward, floor_right);
					
					if (buildType == B_LADDER_HATCH and attachSocket == SOCKET_WALL)
					{
						fdot = -fdot;
						rdot = -rdot;
					}
					
					if (abs(fdot) > abs(rdot)) {
						if (fdot > 0) {
							attachYaw += 0;
						} else {
							attachYaw += 180;
						}
					} else {
						if (rdot > 0) {
							attachYaw += 270;
						} else {
							attachYaw += 90;
						}
					}
				}
				
				if (getPartAtPos(attachOri) !is null)
					continue;
				if (partSocket == SOCKET_DOORWAY and getPartsByParent(part.pev.team).length() > 0)
					continue;
					
				if (buildType == B_FOUNDATION_TRI or buildType == B_FLOOR_TRI)
				{
					CBaseEntity@ ent = getPartAtPos(attachOri, 28);
					if (ent !is null and (ent.pev.colormap == B_FOUNDATION or ent.pev.colormap == B_FLOOR))
					{
						// triangle would be completely inside a square piece
						continue;
					}
				}
				if (buildType == B_FOUNDATION or buildType == B_FLOOR)
				{
					CBaseEntity@ ent = getPartAtPos(attachOri, 28);
					if (ent !is null and (ent.pev.colormap == B_FOUNDATION_TRI or ent.pev.colormap == B_FLOOR_TRI))
					{
						// square would be completely enclosing a tri piece
						continue;
					}
				}
				if (buildType == B_LADDER_HATCH)
				{
					CBaseEntity@ ent = getPartAtPos(attachOri + Vector(0,0,-64), 2);
					if (ent !is null and socketType(ent.pev.colormap) == SOCKET_MIDDLE)
					{
						// ladder hatch opens into stairs or something
						continue;
					}
				}
				
				bestDist = minDist;
					
				newOri = attachOri;
				attaching = true;
				validBuild = true;
				@phit = @part;
				
				if ((buildType == B_FOUNDATION or buildType == B_FLOOR) and (attachType == B_FOUNDATION or attachType == B_FLOOR))
					newYaw = part.pev.angles.y;
				else
					newYaw = attachYaw;
			}
			
			if (buildType == B_FOUNDATION or buildType == B_FOUNDATION_STEPS or buildType == B_FOUNDATION_TRI)
			{
				// check that all 4 corners of the foundation/steps touch the floor
				validBuild = buildType == B_FOUNDATION_STEPS ? attaching : true; // check all 4 points for contact with ground
			
				g_EngineFuncs.MakeVectors(buildEnt.pev.angles);
				array<Vector> posts;
				
				if (buildType == B_FOUNDATION_TRI)
				{
					posts.insertLast(buildEnt.pev.origin + g_Engine.v_right*62 + g_Engine.v_forward*-35 + Vector(0,0,-1));
					posts.insertLast(buildEnt.pev.origin + g_Engine.v_right*-62 + g_Engine.v_forward*-35 + Vector(0,0,-1));
					posts.insertLast(buildEnt.pev.origin + g_Engine.v_forward*71 + Vector(0,0,-1));
				}
				else
				{
					posts.insertLast(buildEnt.pev.origin + g_Engine.v_right*62 + g_Engine.v_forward*62 + Vector(0,0,-1));
					posts.insertLast(buildEnt.pev.origin + g_Engine.v_right*62 + g_Engine.v_forward*-62 + Vector(0,0,-1));
					posts.insertLast(buildEnt.pev.origin + g_Engine.v_right*-62 + g_Engine.v_forward*62 + Vector(0,0,-1));
					posts.insertLast(buildEnt.pev.origin + g_Engine.v_right*-62 + g_Engine.v_forward*-62 + Vector(0,0,-1));
				}
				
				bool allSolid = true;
				for (uint i = 0; i < posts.length(); i++)
				{
					TraceResult tr2;
					Vector vecEnd = posts[i] + Vector(0,0,-112);
					g_Utility.TraceLine( posts[i], vecEnd, dont_ignore_monsters, phit.edict(), tr2 );
					CBaseEntity@ phit2 = g_EntityFuncs.Instance( tr2.pHit );
					
					if (phit2 is null or phit2.pev.classname != "worldspawn" or tr2.flFraction >= 1.0f) {
						if (tr2.fAllSolid == 0)
						{
							validBuild = false;
							break;
						}
						continue;
					}
					allSolid = false;
					
					if (!attaching)
					{
						newOri.z = Math.max(newOri.z, (tr2.vecEndPos + tr2.vecPlaneNormal*8).z);
					}
				}
				
				if (allSolid)
					validBuild = false;
			}
		}
			
		
		bool attachableEnt = phit.pev.classname == "func_breakable_custom" or phit.pev.classname == "func_door_rotating";
		if (attachableEnt and !attaching) {
			int attachType = phit.pev.colormap;
			int attachSocket = socketType(attachType);
			
			if (isFloorPiece(phit))
			{
				validBuild = true;
				attaching = true;
			}
			else if (buildType == B_LADDER)
			{
				if (attachSocket == SOCKET_WALL)
				{
					g_EngineFuncs.MakeVectors(phit.pev.angles);
					float oldYaw = newYaw;
					newYaw = phit.pev.angles.y;
					if (vecEqual(tr.vecPlaneNormal, g_Engine.v_forward))
						newYaw += 180;
						
					newOri = newOri + tr.vecPlaneNormal*3;
					
					// check if the ladder is going to immediately break or not
					TraceResult tr2;
					Vector vecEnd = tr.vecEndPos + g_Engine.v_forward*4;
					g_Utility.TraceLine( tr.vecEndPos, vecEnd, ignore_monsters, null, tr2 );
					CBaseEntity@ phit2 = g_EntityFuncs.Instance( tr2.pHit );
					
					if (phit2 !is null and phit.pev.classname == "func_breakable_custom" and socketType(phit.pev.colormap) == SOCKET_WALL)
					{
						validBuild = true;
						attaching = true;
					}
					else
						newYaw = oldYaw;						
				}
			}
			else if (partSocket == SOCKET_DOOR)
			{
				g_EngineFuncs.MakeVectors(phit.pev.angles);
				// only allow attaching to the top when looking at the front/back of doorway
				if ((attachType == B_WOOD_DOOR or attachType == B_METAL_DOOR or attachType == B_LADDER_HATCH) and 
					phit.pev.targetname != "")
				{
					if (attachType == B_LADDER_HATCH and vecEqual(tr.vecPlaneNormal, g_Engine.v_up) or 
						vecEqual(tr.vecPlaneNormal, -g_Engine.v_up))
					{
						newOri = phit.pev.origin - g_Engine.v_forward*36 + Vector(0,0,-1);
						validBuild = true;
						attaching = true;
						newYaw = phit.pev.angles.y + 180;
						newPitch = 90;
						if (buildType == B_CODE_LOCK and phit.pev.button == 1)
							validBuild = false;
					}
					else if ((attachType == B_WOOD_DOOR or attachType == B_METAL_DOOR) and 
								vecEqual(tr.vecPlaneNormal, g_Engine.v_forward) or vecEqual(tr.vecPlaneNormal, -g_Engine.v_forward))
					{
						newOri = phit.pev.origin - g_Engine.v_right*32;
						validBuild = true;
						attaching = true;
						newYaw = phit.pev.angles.y;
						if (buildType == B_CODE_LOCK and phit.pev.button == 1)
							validBuild = false;
					}
					
				}
			}
		}
		
		if (attaching)
			@attachEnt = phit;
		
		buildEnt.pev.origin = buildEnt2.pev.origin = newOri;
		buildEnt.pev.angles.y = buildEnt2.pev.angles.y = newYaw;
		buildEnt.pev.angles.x = buildEnt2.pev.angles.x = newPitch;
		g_EntityFuncs.SetOrigin(buildEnt, buildEnt.pev.origin); // fix collision
		
		// check collision
		CBaseEntity@ ent = null;
		do {
			@ent = g_EntityFuncs.FindEntityInSphere(ent, newOri, 192, "*", "classname");
			if (ent !is null)
			{
				if (ent.entindex() == buildEnt.entindex() or ent.entindex() == buildEnt2.entindex())
					continue;
				if (skipCollide !is null and skipCollide.entindex() == ent.entindex())
					continue;
				if (attachEnt !is null and ent.entindex() == attachEnt.entindex())
					continue;
				if (ent.pev.solid == SOLID_NOT or ent.pev.effects & EF_NODRAW != 0)
					continue;
				if (ent.pev.solid == SOLID_TRIGGER and ent.pev.classname != "func_build_clip")
					continue;
				if (buildType == B_CODE_LOCK or buildType == B_LADDER)
					continue;

				string cname = string(ent.pev.classname);
				if ((cname == "func_breakable_custom" or cname == "func_door_rotating") && attaching) {
					// still a small chance a separate base perfectly aligns, letting
					// you build overlapping pieces, but that should be pretty rare.
					float diff = (ent.pev.origin - buildEnt.pev.origin).Length();

					if (diff < 1.0f) {
						validBuild = false; // socket already filled
						break;
					} 
				}
				float maxOverlap = ent.IsBSPModel() and !isFloorItem(buildEnt) ? 9.95f : 2.0f;
				float overlap = collisionBoxesYaw(buildEnt, ent);
				if (overlap > maxOverlap) {
					if (debug_mode)
						println("BLOCKED BY: " + cname + " overlap " + overlap);
					validBuild = false;
					break;
				} 
				else if (debug_mode && overlap > 0)
				{
					println("OVERLAP BY: " + cname + " overlap " + overlap);
				}
			}
		} while (ent !is null);
		
		// only allow building in build zones
		if (!g_build_anywhere)
		{
			zoneid = getBuildZone(buildEnt);
			if (zoneid == -1)
				validBuild = false;
		}

		forbidden = forbiddenByCupboard(plr, buildEnt.pev.origin);	
		
		if (forbidden and validBuild) {
			buildEnt.pev.rendercolor = Vector(255, 255, 0);
		} else if (validBuild) {
			buildEnt.pev.rendercolor = Vector(0, 255, 255);
		} else {
			buildEnt.pev.rendercolor = Vector(255, 0, 0);
		}
		//println(phit.pev.classname);
	}
	
	void WeaponThink()
	{
		if (active && self.m_hPlayer) 
		{
			CBasePlayer@ plr = getPlayer();
			
			if (plr.pev.button & 1 == 0) {
				canShootAgain = true;
			}
			
			if (lastHudUpdate < g_Engine.time + 0.05f)
			{
				lastHudUpdate = g_Engine.time;
				PlayerState@ state = getPlayerState(plr);
			
				HUDTextParams params;
				params.y = 0.88;
				params.effect = 0;
				params.r1 = 255;
				params.g1 = 255;
				params.b1 = 255;
				params.fadeinTime = 0;
				params.fadeoutTime = 0;
				params.holdTime = 0.2f;
				
				params.x = 0.1;
				params.channel = 1;
				
				if (!g_build_anywhere)
				{
					if (zoneid != -1)
					{
						BuildZone@ zone = getBuildZone(zoneid);
						string status;
						if (zoneid == state.home_zone)
						{
							status = "Settler";
							params.r1 = 48;
							params.g1 = 255;
							params.b1 = 48;
						}
						else
						{
							status = "Raider";
							params.r1 = 255;
							params.g1 = 48;
							params.b1 = 48;
						}

						g_PlayerFuncs.HudMessage(plr, params, "Build Zone: " + zoneid + 
												 "\nSettlers: " + zone.numSettlers + " / " + zone.maxSettlers +
												 "\nStatus: " + status);
					}
					else
					{
						g_PlayerFuncs.HudMessage(plr, params, "Build Zone: Outskirts\n(Building not allowed)");
					}
					
					params.x = 0.8;
					params.channel = 0;
					int maxPoints = state.maxPoints(zoneid);
					g_PlayerFuncs.HudMessage(plr, params,	"Build Points:\n" + (maxPoints-state.getNumParts(zoneid)) + " / " + maxPoints);
				}
				else
				{
					params.x = 0.8;
					params.channel = 0;
					int total = state.getNumParts(-1337);
					g_PlayerFuncs.HudMessage(plr, params, "Built Parts:\n" + total + " / 500");
				}
			}	
			updateBuildPlaceholder();
		}
		pev.nextthink = g_Engine.time;
	}
	
	CBasePlayer@ getPlayer()
	{
		CBaseEntity@ e_plr = self.m_hPlayer;
		return cast<CBasePlayer@>(e_plr);
	}
	
	void Build()
	{
		CBasePlayer@ plr = getPlayer();
		PlayerState@ state = getPlayerState(plr);
		if (buildEnt !is null and forbidden)
		{
			g_PlayerFuncs.PrintKeyBindingString(plr, "Building blocked by tool cupboard");
			return;
		}
		if (!g_build_anywhere)
		{
			if (zoneid == -1)
			{
				g_PlayerFuncs.PrintKeyBindingString(plr, "Building not allowed in outskirts");
				return;
			}
			if (state.home_zone == -1)
			{
				BuildZone@ zone = getBuildZone(zoneid);
				int needSpace = state.team !is null ? state.team.members.size() : 1;
				if (zone.maxSettlers - zone.numSettlers >= needSpace)
				{
					zone.numSettlers += needSpace;
					state.home_zone = zoneid;
					
					string msg = "Zone " + zoneid + " is now your home. You can build a permanent base here.\n";
					if (state.team !is null)
					{
						state.team.sendMessage(msg);
						state.team.setHomeZone(zoneid);
					}
					else
						g_PlayerFuncs.SayText(plr, msg);
					
					int previousRaiderParts = state.getNumParts(zoneid);
					zone.numRaiderParts -= previousRaiderParts; // parts built by this player no longer count as raider parts
				}
				else
				{
					println("Too many settlers in zone");
					//g_PlayerFuncs.SayText(plr, "This zone has too many settlers.");
				}
			}
			if (state.getNumParts(zoneid) >= state.maxPoints(zoneid))
			{
				g_PlayerFuncs.PrintKeyBindingString(plr, "You're out of build points!\n\nFuse your parts (Wrench) for more points.");
				return;
			}
			
			if (zoneid != state.home_zone)
				getBuildZone(zoneid).numRaiderParts++;
		}
		
		if (!g_free_build)
		{
			if (getItemCount(plr, BUILD_MATERIAL) < g_part_info[buildType].cost)
			{
				g_PlayerFuncs.PrintKeyBindingString(plr, "You don't have enough " + g_items[BUILD_MATERIAL].title);
				return;
			}
			else
			{
				HUDTextParams params;
				params.x = -1;
				params.y = -1;
				params.effect = 0;
				params.r1 = 255;
				params.g1 = 255;
				params.b1 = 255;
				params.fadeinTime = 0;
				params.fadeoutTime = 0.5f;
				params.holdTime = 0.0f;
				params.channel = 2;
			
				g_PlayerFuncs.HudMessage(plr, params, "-" + g_part_info[buildType].cost + " " + g_items[BUILD_MATERIAL].title);
				giveItem(plr, BUILD_MATERIAL, -g_part_info[buildType].cost, false);
			}
		}
		
		if (buildEnt !is null && validBuild) 
		{
			plr.SetAnimation( PLAYER_ATTACK1 );
			
			string brushModel = buildEnt.pev.model;
			int buildSocket = socketType(buildEnt.pev.colormap);
			int parent = -1;
			
			if (buildSocket == SOCKET_DOORWAY or buildType == B_WOOD_SHUTTERS or buildType == B_LADDER or 
				buildSocket == SOCKET_WINDOW or buildType == B_TOOL_CUPBOARD)
			{
				parent = attachEnt.pev.team;
			}
			
			string soundFile = nextSnd == 0 ? "sc_rust/build1.ogg" : "sc_rust/build2.ogg";
			nextSnd = 1 - nextSnd;
			
			if (buildType == B_WOOD_DOOR) soundFile = "sc_rust/door_wood_place.ogg";
			if (buildType == B_METAL_DOOR) soundFile = "sc_rust/door_metal_place.ogg";
			if (buildType == B_WOOD_BARS) soundFile = "sc_rust/bars_wood_place.ogg";
			if (buildType == B_METAL_BARS) soundFile = "sc_rust/bars_metal_place.ogg";			
			if (buildType == B_CODE_LOCK) soundFile = "sc_rust/code_lock_place.ogg";					
			if (buildType == B_TOOL_CUPBOARD) soundFile = "sc_rust/tool_cupboard_place.ogg";					
			if (buildType == B_LADDER) soundFile = "sc_rust/ladder_place.ogg";					
			if (buildType == B_LADDER_HATCH) soundFile = "sc_rust/ladder_hatch_place.ogg";					
			if (buildType == B_HIGH_STONE_WALL) soundFile = "sc_rust/high_wall_place_stone.ogg";					
			if (buildType == B_HIGH_WOOD_WALL) soundFile = "sc_rust/high_wall_place_wood.ogg";					
			
			if (buildType == B_CODE_LOCK)
			{
				// just change door model
				string newModel = "";
				if (attachEnt.pev.colormap == B_WOOD_DOOR)
					newModel = "b_wood_door_unlock";
				if (attachEnt.pev.colormap == B_METAL_DOOR)
					newModel = "b_metal_door_unlock";
				if (attachEnt.pev.colormap == B_LADDER_HATCH)
					newModel = "b_ladder_hatch_door_unlock";
				
				int oldcolormap = attachEnt.pev.colormap;
				g_EntityFuncs.SetModel(attachEnt, getModelFromName(newModel));
				attachEnt.pev.colormap = oldcolormap;
				
				attachEnt.pev.button = 1;
				attachEnt.pev.body = 0;
				
				g_SoundSystem.PlaySound(attachEnt.edict(), CHAN_STATIC, soundFile, 1.0f, 1.0f, 0, 90 + Math.RandomLong(0, 20));
				return;
			}
		
			Vector origin = buildEnt.pev.origin;				
			dictionary keys;
			keys["origin"] = origin.ToString();
			keys["angles"] = buildEnt.pev.angles.ToString();
			keys["model"] = brushModel;
			keys["colormap"] = "" + buildEnt.pev.colormap;
			keys["material"] = "1";
			keys["target"] = "break_part_script";
			keys["fireonbreak"] = "break_part_script";
			keys["zoneid"] = "" + zoneid;
			keys["health"] = "100";
			keys["max_health"] = "100";
			keys["rendermode"] = "4";
			keys["renderamt"] = "255";
			keys["id"] = "" + g_part_id;
			keys["parent"] = "" + parent;
			keys["frame"] = "2";
			//keys["effects"] = "512";
				
			if (buildSocket == SOCKET_DOORWAY or buildType == B_WOOD_SHUTTERS)
			{
				keys["distance"] = "9999";
				keys["speed"] = "0.00000001";
				keys["breakable"] = "1";
				keys["targetname"] = "locked" + g_part_id;
			}
			
			if (buildType == B_LADDER_HATCH)
			{
				CBaseEntity@ hatch_frame = g_EntityFuncs.FindEntityByTargetname(null, "b_ladder_hatch_frame");
				keys["model"] = string(hatch_frame.pev.model);
			}
			
			g_EngineFuncs.MakeVectors(buildEnt.pev.angles);
			
			CBaseEntity@ ent = null;
			if (buildType == B_WOOD_SHUTTERS)
			{
				CBaseEntity@ l_shutter = g_EntityFuncs.FindEntityByTargetname(null, "b_wood_shutter_l");
				keys["origin"] = (buildEnt.pev.origin + g_Engine.v_right*47).ToString();
				keys["model"] = string(l_shutter.pev.model);
				@ent = g_EntityFuncs.CreateEntity("func_breakable_custom", keys, true);	
				
				CBaseEntity@ r_shutter = g_EntityFuncs.FindEntityByTargetname(null, "b_wood_shutter_l");
				keys["origin"] = (buildEnt.pev.origin + g_Engine.v_right*-47).ToString();
				keys["model"] = string(r_shutter.pev.model);
				keys["angles"] = (buildEnt.pev.angles + Vector(0,180,0)).ToString();
				CBaseEntity@ ent2 = g_EntityFuncs.CreateEntity("func_breakable_custom", keys, true);	
				
				ent.pev.vuser1 = ent.pev.angles;
				ent.pev.vuser2 = ent.pev.angles + Vector(0,-150,0);
				
				ent2.pev.vuser1 = ent2.pev.angles;
				ent2.pev.vuser2 = ent2.pev.angles + Vector(0,150,0);	
				
				g_SoundSystem.PlaySound(ent.edict(), CHAN_STATIC, "sc_rust/shutters_wood_place.ogg", 1.0f, 1.0f, 0, 90 + Math.RandomLong(0, 20));
				
				g_build_parts.insertLast(EHandle(ent));
				g_build_parts.insertLast(EHandle(ent2));
				g_part_id++;
				
				state.addPart(ent, zoneid);
				state.addPart(ent2, zoneid);
			}
			else
			{				
				@ent = g_EntityFuncs.CreateEntity("func_breakable_custom", keys, true);
				
				g_SoundSystem.PlaySound(ent.edict(), CHAN_STATIC, soundFile, 1.0f, 1.0f, 0, 90 + Math.RandomLong(0, 20));
				
				EHandle h_ent = ent;
				g_build_parts.insertLast(EHandle(ent));
				g_part_id++;
				state.addPart(ent, zoneid);
				
				if (buildType == B_TOOL_CUPBOARD) {
					g_tool_cupboards.insertLast(h_ent);
				}
				
				if (buildType == B_LADDER) {
					ent.pev.rendermode = kRenderTransAlpha;
					ent.pev.renderamt = 255;
					CBaseEntity@ ladder_box = g_EntityFuncs.FindEntityByTargetname(null, "b_ladder_box");
					keys["model"] = string(ladder_box.pev.model);
					keys["parent"] = "" + (g_part_id - 1);
					
					CBaseEntity@ ent2 = g_EntityFuncs.CreateEntity("func_ladder", keys, true);
					ent2.pev.colormap = buildEnt.pev.colormap;
					ent2.pev.team = g_part_id - 1;
					g_build_items.insertLast(EHandle(ent2));
				}
				
				if (buildType == B_LADDER_HATCH) {
					CBaseEntity@ hatch_door = g_EntityFuncs.FindEntityByTargetname(null, "b_ladder_hatch_door");
					keys["origin"] = (buildEnt.pev.origin + g_Engine.v_forward*32 + Vector(0,0,-4)).ToString();
					keys["model"] = string(hatch_door.pev.model);
					keys["distance"] = "9999";
					keys["speed"] = "0.00000001";
					keys["breakable"] = "1";
					keys["targetname"] = "locked" + g_part_id;
					keys["parent"] = "" + (g_part_id - 1);
					CBaseEntity@ ent2 = g_EntityFuncs.CreateEntity("func_breakable_custom", keys, true);	
					g_build_parts.insertLast(EHandle(ent2));
					
					ent2.pev.rendermode = kRenderTransAlpha;
					ent2.pev.renderamt = 255;
					
					ent2.pev.vuser1 = buildEnt.pev.angles;
					ent2.pev.vuser2 = buildEnt.pev.angles + Vector(-82,0,0);
					
					CBaseEntity@ ladder_box = g_EntityFuncs.FindEntityByTargetname(null, "b_ladder_hatch_ladder");
					keys["origin"] = (buildEnt.pev.origin + g_Engine.v_forward*32).ToString();
					keys["model"] = string(ladder_box.pev.model);
					keys["targetname"] = "ladder_hatch" + (g_part_id - 1);
					keys["spawnflags"] = "1"; // start off
					CBaseEntity@ ent3 = g_EntityFuncs.CreateEntity("func_ladder", keys, true);	
					ent3.pev.team = g_part_id - 1;
					g_build_items.insertLast(EHandle(ent3));
					
					state.addPart(ent2, zoneid);
				}
				
				if (buildSocket == SOCKET_DOORWAY)
				{
					ent.pev.vuser1 = buildEnt.pev.angles;
					ent.pev.vuser2 = buildEnt.pev.angles + Vector(0,-95,0);
				}
				
				// conditional roof side wall
				bool wallSocket = buildEnt.pev.colormap == B_WALL or buildEnt.pev.colormap == B_WINDOW or buildEnt.pev.colormap == B_DOORWAY;
				if (buildEnt.pev.colormap == B_ROOF)
				{
					updateRoofWalls(ent);
					
					g_EngineFuncs.MakeVectors(buildEnt.pev.angles);
					Vector roofCheckR = buildEnt.pev.origin + g_Engine.v_right*128;
					Vector roofCheckL = buildEnt.pev.origin + -g_Engine.v_right*128;
					
					bool hasRoofL = false;
					bool hasRoofR = false;
					CBaseEntity@ roofR = getPartAtPos(roofCheckR);
					hasRoofR = roofR !is null and roofR.pev.colormap == B_ROOF;

					CBaseEntity@ roofL = getPartAtPos(roofCheckL);
					hasRoofL = roofL !is null and roofL.pev.colormap == B_ROOF;
					
					if (hasRoofL) {
						updateRoofWalls(roofL);
					}
					if (hasRoofR) {
						updateRoofWalls(roofR);
					}
					
				}
				else if (wallSocket)
				{
					g_EngineFuncs.MakeVectors(buildEnt.pev.angles);
					Vector roofCheckR = buildEnt.pev.origin + g_Engine.v_forward*64 + Vector(0,0,192);
					Vector roofCheckL = buildEnt.pev.origin + -g_Engine.v_forward*64 + Vector(0,0,192);
					
					bool hasRoofL = false;
					bool hasRoofR = false;
					CBaseEntity@ roofR = getPartAtPos(roofCheckR);
					hasRoofR = roofR !is null and roofR.pev.colormap == B_ROOF;

					CBaseEntity@ roofL = getPartAtPos(roofCheckL);
					hasRoofL = roofL !is null and roofL.pev.colormap == B_ROOF;
					
					if (hasRoofL) {
						updateRoofWalls(roofL);
					}
					if (hasRoofR) {
						updateRoofWalls(roofR);
					}
				}
			}
		}
	}
	
	void Cycle(int direction)
	{
		buildType += direction;
		if (alternateBuild) 
		{
			if (buildType >= B_ITEM_TYPES) {
				buildType = B_TYPES;
			}
			if (buildType < B_TYPES) {
				buildType = B_ITEM_TYPES - 1;
			}
		}
		else
		{
			if (buildType >= B_TYPES) {
			buildType = 0;
			}
			if (buildType < 0) {
				buildType = B_TYPES - 1;
			}
		}
		
		createBuildEnts();
	}
	
	void PrimaryAttack()  
	{
		if (canShootAgain) {
			Build();
			canShootAgain = false;
		}
	}
	
	void SecondaryAttack() 
	{ 
		if (nextCycle < g_Engine.time) {
			Cycle(1);
			canShootAgain = false;
			nextCycle = g_Engine.time + 0.3f;
		}
	}
	
	void TertiaryAttack()  
	{ 
		if (nextCycle < g_Engine.time) {
			Cycle(-1);
			canShootAgain = false;
			nextCycle = g_Engine.time + 0.3f;
		}
	}
	
	void Reload()
	{
		if (nextAlternate < g_Engine.time)
		{
			alternateBuild = !alternateBuild;
			nextAlternate = g_Engine.time + 0.3f;

			if (alternateBuild)
			{
				buildType = B_TYPES;
				createBuildEnts();
				g_PlayerFuncs.PrintKeyBindingString(getPlayer(), "Item Placement Mode");
			}
			else
			{
				buildType = 0;
				createBuildEnts();
				g_PlayerFuncs.PrintKeyBindingString(getPlayer(), "Construction Mode");
			}
		}
	}

	void WeaponIdle()
	{		
		if( self.m_flTimeWeaponIdle > WeaponTimeBase())
			return;

		self.SendWeaponAnim( 0, 0, 0 );
		self.m_flTimeWeaponIdle = WeaponTimeBase() + 10; // how long till we do this again.
	}
}
