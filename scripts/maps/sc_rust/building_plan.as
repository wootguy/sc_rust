#include "utils"

float EPSILON = 0.03125f;

class BuildPartInfo
{
	int type;
	string copy_ent;
	string title;
	
	BuildPartInfo() {
		type = -1;
	}
	
	BuildPartInfo(int t, string tit, string copy) {
		type = t;
		copy_ent = copy;
		title = tit;
	}
}

class Item
{
	int type;
	bool stackable;
	string title;
	string desc;
	
	Item() {
		type = -1;
		stackable = false;
	}
	
	Item(int t, bool stack, string tit, string description) {
		type = t;
		stackable = stack;
		title = tit;
		desc = description;
	}
}

enum build_types
{
	B_FOUNDATION = 0,
	B_WALL,
	B_DOORWAY,
	B_WINDOW,
	B_LOW_WALL,
	B_FLOOR,
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
};

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

int B_TYPES = B_FOUNDATION_STEPS+1;
int B_ITEM_TYPES = B_LADDER_HATCH+1;

array<BuildPartInfo> BuildPartInfos = {
	BuildPartInfo(B_FOUNDATION, "Foundation", "b_foundation"),
	BuildPartInfo(B_WALL, "Wall", "b_wall"),
	BuildPartInfo(B_DOORWAY, "Doorway", "b_doorway"),
	BuildPartInfo(B_WINDOW, "Window", "b_window"),
	BuildPartInfo(B_LOW_WALL, "Low Wall", "b_low_wall"),
	BuildPartInfo(B_FLOOR, "Floor", "b_floor"),
	BuildPartInfo(B_ROOF, "Roof", "b_roof"),
	BuildPartInfo(B_STAIRS, "Stairs (U-shape)", "b_stairs"),
	BuildPartInfo(B_STAIRS_L, "Stairs (L-shape)", "b_stairs_l"),
	BuildPartInfo(B_FOUNDATION_STEPS, "Foundation Steps", "b_foundation_steps"),
	
	BuildPartInfo(B_WOOD_DOOR, "Wood Door", "b_wood_door"),
	BuildPartInfo(B_METAL_DOOR, "Metal Door", "b_metal_door"),
	BuildPartInfo(B_WOOD_BARS, "Wood Window Bars", "b_wood_bars"),
	BuildPartInfo(B_METAL_BARS, "Metal Window Bars", "b_metal_bars"),
	BuildPartInfo(B_WOOD_SHUTTERS, "Wood Shutters", "b_wood_shutters"),
	BuildPartInfo(B_CODE_LOCK, "Code Lock", "b_code_lock"),
	BuildPartInfo(B_TOOL_CUPBOARD, "Tool Cupboard", "b_tool_cupboard"),
	BuildPartInfo(B_HIGH_WOOD_WALL, "High External Wood Wall", "b_high_wood_wall"),
	BuildPartInfo(B_HIGH_STONE_WALL, "High External Stone Wall", "b_high_stone_wall"),
	BuildPartInfo(B_LADDER, "Ladder", "b_ladder"),
	BuildPartInfo(B_LADDER_HATCH, "Ladder Hatch", "b_ladder_hatch"),
};

array<Item> g_items = {	
	Item(I_WOOD_DOOR, false, "Wood Door", "A hinged door which is made out of wood"),
	Item(I_METAL_DOOR, false, "Metal Door", "b_metal_door"),
	Item(I_WOOD_BARS, false, "Wood Window Bars", "b_wood_bars"),
	Item(I_METAL_BARS, false, "Metal Window Bars", "b_metal_bars"),
	Item(I_WOOD_SHUTTERS, false, "Wood Shutters", "b_wood_shutters"),
	Item(I_CODE_LOCK, false, "Code Lock", "An electronic lock. Locked and unlocked with four-digit code. Hold your USE key while looking at the lock to activate it."),
	Item(I_TOOL_CUPBOARD, false, "Tool Cupboard", "Only players authorized to this cupboard will be able to build near it.\nPress USE to authorize yourself and hold USE to clear previous authorizations."),
	Item(I_HIGH_WOOD_WALL, false, "High External Wood Wall", "b_wood_wall"),
	Item(I_HIGH_STONE_WALL, false, "High External Stone Wall", "b_stone_wall"),
	Item(I_LADDER, false, "Ladder", "b_ladder"),
	Item(I_LADDER_HATCH, false, "Ladder Hatch", "b_ladder_hatch"),
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
	int nextSnd = 0;
	bool alternateBuild = false;
	
	void Spawn()
	{		
		Precache();
		g_EntityFuncs.SetModel( self, "models/w_357.mdl" );

		//self.m_iDefaultAmmo = 0;
		//self.m_iClip = self.m_iDefaultAmmo;
		
		self.FallInit();
		SetThink( ThinkFunction( WeaponThink ) );
	}
	
	void Precache()
	{
		self.PrecacheCustomModels();
		g_Game.PrecacheModel( "models/w_357.mdl" );
		g_Game.PrecacheModel( "models/p_357.mdl" );
		g_Game.PrecacheModel( "models/v_357.mdl" );
		
		PrecacheSound("sc_rust/build1.ogg");
		PrecacheSound("sc_rust/build2.ogg");
	}
	
	bool GetItemInfo( ItemInfo& out info )
	{				
		info.iMaxAmmo1 	= 20;
		info.iMaxAmmo2 	= -1;
		info.iMaxClip 	= 0;
		info.iSlot 		= 3;
		info.iPosition 	= 6;
		info.iFlags 	= 0;
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
		bool bResult = self.DefaultDeploy( self.GetV_Model( "models/v_357.mdl" ), self.GetP_Model( "models/p_357.mdl" ), 0, "shotgun" );
		
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
		
		CBaseEntity@ copy_ent = g_EntityFuncs.FindEntityByTargetname(null, BuildPartInfos[buildType].copy_ent);
		
		dictionary keys;
		keys["origin"] = look.vecEndPos.ToString();
		keys["model"] = string(copy_ent.pev.model);
		keys["rendermode"] = "1";
		keys["renderamt"] = "128";
		keys["rendercolor"] = "0 255 255";
		keys["colormap"] = "" + buildType;
			
		CBaseEntity@ ent = g_EntityFuncs.CreateEntity("func_illusionary", keys, false);	
		g_EntityFuncs.DispatchSpawn(ent.edict());
		@buildEnt = @ent;
		
		keys["rendermode"] = "2";
		CBaseEntity@ ent2 = g_EntityFuncs.CreateEntity("func_illusionary", keys, false);	
		g_EntityFuncs.DispatchSpawn(ent2.edict());
		@buildEnt2 = @ent2;
		ent2.pev.scale = 0.5f;
		
		g_PlayerFuncs.PrintKeyBindingString(getPlayer(), BuildPartInfos[buildType].title);
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
		
		TraceResult tr = TraceLook(getPlayer(), 192);
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
				CBaseEntity@ part = g_build_parts[i].ent;
				
				if (part is null or socketType(part.pev.colormap) != SOCKET_HIGH_WALL)
					continue;
					
				if ((part.pev.origin - buildEnt.pev.origin).Length() > 500)
					continue;
				
				float attachDist = 64;
				g_EngineFuncs.MakeVectors(part.pev.angles);
				Vector attachLeft = part.pev.origin - g_Engine.v_right*128;
				Vector attachRight = part.pev.origin + g_Engine.v_right*128;
				
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
		}
		else if (partSocket == SOCKET_FOUNDATION or partSocket == SOCKET_WALL or buildType == B_FLOOR or 
				buildType == B_LADDER_HATCH or buildType == B_ROOF or partSocket == SOCKET_MIDDLE or
				partSocket == SOCKET_DOORWAY or partSocket == SOCKET_WINDOW)
		{
			g_EngineFuncs.MakeVectors(buildEnt.pev.angles);
			float bestDist = 9000;
			
			for (uint i = 0; i < g_build_parts.size(); i++)
			{	
				CBaseEntity@ part = g_build_parts[i].ent;
				if (part is null)
					continue;
					
				int attachType = part.pev.colormap;
				int attachSocket = socketType(part.pev.colormap);
					
				if (partSocket == SOCKET_FOUNDATION and part.pev.colormap != B_FOUNDATION)
					continue;
				if ((partSocket == SOCKET_WALL or buildType == B_FLOOR or buildType == B_LADDER_HATCH) and !isFloorPiece(part) and socketType(part.pev.colormap) != SOCKET_WALL)
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
				
				float attachDist = 128;
				if (partSocket == SOCKET_DOORWAY or partSocket == SOCKET_WINDOW)
					attachDist = 200;
				g_EngineFuncs.MakeVectors(part.pev.angles);
				
				Vector attachOri = tr.vecEndPos;
				float attachYaw = part.pev.angles.y;
				float minDist = 0;
				
				if (isFloorPiece(part) and partSocket != SOCKET_MIDDLE and 
					!((buildType == B_FLOOR or buildType == B_LADDER_HATCH) and 
					part.pev.colormap == B_FOUNDATION))
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
					if (buildType == B_ROOF)
						oriDist = 0;
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
				}
				else if (attachSocket == SOCKET_WALL and (buildType == B_FLOOR or buildType == B_LADDER_HATCH))
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
					minDist = df;
					if (df < db)
					{
						attachOri = part.pev.origin + g_Engine.v_forward*64 + Vector(0,0,128);
						attachYaw = Math.VecToAngles(part.pev.origin - front).y;
						minDist = df;
					}
					else if (db < df)
					{
						attachOri = part.pev.origin + g_Engine.v_forward*-64 + Vector(0,0,128);
						attachYaw = Math.VecToAngles(part.pev.origin - back).y;
						minDist = db;
					}
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
					Vector front = part.pev.origin + g_Engine.v_forward*64 + Vector(0,0,128);
					Vector back = part.pev.origin +  g_Engine.v_forward*-64 + Vector(0,0,128);
					float df = (front - tr.vecEndPos).Length();
					float db = (back - tr.vecEndPos).Length();
					
					if (df > attachDist or db > attachDist)
						continue;
					if (df > bestDist or db > bestDist)
						continue;
						
					attachYaw = part.pev.angles.y;
					minDist = df;
					if (df < db)
					{
						attachOri = front + Vector(0,0,64);
						attachYaw = Math.VecToAngles(part.pev.origin - front).y;
						minDist = df;
					}
					else if (db < df)
					{
						attachOri = back + Vector(0,0,64);
						attachYaw = Math.VecToAngles(part.pev.origin - back).y;
						minDist = db;
					}
				}
				else if (partSocket == SOCKET_MIDDLE and isFloorPiece(part))
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
				
				bestDist = minDist;
					
				newOri = attachOri;
				attaching = true;
				validBuild = true;
				@phit = @part;
				
				if (buildType == B_FOUNDATION or buildType == B_FLOOR)
					newYaw = part.pev.angles.y;
				else
					newYaw = attachYaw;
			}
			
			if (buildType == B_FOUNDATION or buildType == B_FOUNDATION_STEPS)
			{
				// check that all 4 corners of the foundation/steps touch the floor
				validBuild = buildType == B_FOUNDATION_STEPS ? attaching : true; // check all 4 points for contact with ground
			
				g_EngineFuncs.MakeVectors(buildEnt.pev.angles);
				array<Vector> posts;
				
				posts.insertLast(buildEnt.pev.origin + g_Engine.v_right*62 + g_Engine.v_forward*62 + Vector(0,0,-1));
				posts.insertLast(buildEnt.pev.origin + g_Engine.v_right*62 + g_Engine.v_forward*-62 + Vector(0,0,-1));
				posts.insertLast(buildEnt.pev.origin + g_Engine.v_right*-62 + g_Engine.v_forward*62 + Vector(0,0,-1));
				posts.insertLast(buildEnt.pev.origin + g_Engine.v_right*-62 + g_Engine.v_forward*-62 + Vector(0,0,-1));
				
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
			
		
		bool attachableEnt = phit.pev.classname == "func_breakable" or phit.pev.classname == "func_door_rotating";
		if (attachableEnt and !attaching) {
			int attachType = phit.pev.colormap;
			int attachSocket = socketType(attachType);
			
			if (buildType == B_TOOL_CUPBOARD)
			{
				if (isFloorPiece(phit))
				{
					validBuild = true;
					attaching = true;
				}
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
					
					if (phit2 !is null and phit.pev.classname == "func_breakable" and socketType(phit.pev.colormap) == SOCKET_WALL)
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
					phit.pev.classname == "func_door_rotating")
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
		
		// check collision
		CBaseEntity@ ent = null;
		do {
			@ent = g_EntityFuncs.FindEntityInSphere(ent, newOri, 300, "*", "classname"); 
			if (ent !is null)
			{
				if (ent.entindex() == buildEnt.entindex() or ent.entindex() == buildEnt2.entindex())
					continue;
				if (skipCollide !is null and skipCollide.entindex() == ent.entindex())
					continue;
				if (attachEnt !is null and ent.entindex() == attachEnt.entindex())
					continue;
				if (ent.pev.solid == SOLID_NOT or ent.pev.solid == SOLID_TRIGGER)
					continue;

				string cname = string(ent.pev.classname);
				if ((cname == "func_breakable" or cname == "func_door_rotating") && attaching) {
					// still a small chance a separate base perfectly aligns, letting
					// you build overlapping pieces, but that should be pretty rare.
					float diff = (ent.pev.origin - buildEnt.pev.origin).Length();
					int rdiff = int( ( (ent.pev.angles.y - buildEnt.pev.angles.y)) * 100);
					//println("RDIFF: " + rdiff);
					if (diff < 1.0f) {
						validBuild = false; // socket already filled
						break;
					} else if (rdiff % 900 <= 1 or rdiff % 900 >= 899) { // ignore it if it's part of the same base
						continue;
					}
				}
				
				if (collisionBoxesYaw(buildEnt, ent)) {
					//println("BLOCKED BY: " + cname);
					validBuild = false;
					break;
				}	
			}
		} while (ent !is null);
		
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
			
			updateBuildPlaceholder();
		}
		
		pev.nextthink = g_Engine.time;
	}
	
	CBasePlayer@ getPlayer()
	{
		CBaseEntity@ e_plr = self.m_hPlayer;
		return cast<CBasePlayer@>(e_plr);
	}
	
	void updateRoofWalls(CBaseEntity@ roof)
	{
		// put walls under roofs when there are no adjacent roofs and there is a wall underneath one/both edges
		string brushModel = roof.pev.model;
		g_EngineFuncs.MakeVectors(roof.pev.angles);
		Vector roofCheckR = roof.pev.origin + g_Engine.v_right*128;
		Vector roofCheckL = roof.pev.origin + -g_Engine.v_right*128;
		Vector wallCheckR = roof.pev.origin + g_Engine.v_right*64 + Vector(0,0,-192);
		Vector wallCheckL = roof.pev.origin + -g_Engine.v_right*64 + Vector(0,0,-192);
		
		
		CBaseEntity@ wallR = getPartAtPos(wallCheckR);
		bool hasWallR = wallR !is null and 
					(wallR.pev.colormap == B_WALL or wallR.pev.colormap == B_WINDOW or wallR.pev.colormap == B_DOORWAY);

		CBaseEntity@ wallL = getPartAtPos(wallCheckL);
		bool hasWallL = wallL !is null and 
					(wallL.pev.colormap == B_WALL or wallL.pev.colormap == B_WINDOW or wallL.pev.colormap == B_DOORWAY);

		CBaseEntity@ roofR = getPartAtPos(roofCheckR);
		bool hasRoofR = roofR !is null and roofR.pev.colormap == B_ROOF;
			
		CBaseEntity@ roofL = getPartAtPos(roofCheckL);
		bool hasRoofL = roofL !is null and roofL.pev.colormap == B_ROOF;
		
		if (hasWallL and hasWallR and !hasRoofL and !hasRoofR) {
			CBaseEntity@ copy_ent = g_EntityFuncs.FindEntityByTargetname(null, "b_roof_wall_both");
			brushModel = copy_ent.pev.model;
		} else if (hasWallL and !hasRoofL) {
			CBaseEntity@ copy_ent = g_EntityFuncs.FindEntityByTargetname(null, "b_roof_wall_left");
			brushModel = copy_ent.pev.model;
		} else if (hasWallR and !hasRoofR) {
			CBaseEntity@ copy_ent = g_EntityFuncs.FindEntityByTargetname(null, "b_roof_wall_right");
			brushModel = copy_ent.pev.model;
		}
		
		int oldcolormap = roof.pev.colormap;
		g_EntityFuncs.SetModel(roof, brushModel);
		roof.pev.colormap = oldcolormap;
	}
	
	void Build()
	{		
		if (buildEnt !is null and forbidden)
		{
			g_PlayerFuncs.PrintKeyBindingString(getPlayer(), "Building blocked by tool cupboard");
			return;
		}
		if (buildEnt !is null && validBuild) 
		{
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
				println("SET NEW MODEL: " + newModel);
					
				CBaseEntity@ copy_ent = g_EntityFuncs.FindEntityByTargetname(null, newModel);
				
				int oldcolormap = attachEnt.pev.colormap;
				g_EntityFuncs.SetModel(attachEnt, copy_ent.pev.model);
				attachEnt.pev.colormap = oldcolormap;
				
				attachEnt.pev.button = 1;
				attachEnt.pev.body = 0;
				
				g_SoundSystem.PlaySound(attachEnt.edict(), CHAN_STATIC, soundFile, 1.0f, 1.0f, 0, 90 + Math.RandomLong(0, 20));
				return;
			}
		
			Vector origin = buildEnt.pev.origin;				
			string classname = "func_breakable";
			dictionary keys;
			keys["origin"] = origin.ToString();
			keys["model"] = brushModel;
			keys["colormap"] = "" + buildEnt.pev.colormap;
			keys["material"] = "1";
			keys["target"] = "break_part_script";
			keys["fireonbreak"] = "break_part_script";
				
			if (buildSocket == SOCKET_DOORWAY or buildType == B_WOOD_SHUTTERS)
			{
				classname = "func_door_rotating";
				keys["distance"] = "9999";
				keys["speed"] = "0.00000001";
				keys["breakable"] = "1";
				keys["targetname"] = "locked";
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
				/*
				keys["rendermode"] = "4";
				keys["renderamt"] = "255";
				*/
				CBaseEntity@ l_shutter = g_EntityFuncs.FindEntityByTargetname(null, "b_wood_shutter_l");
				keys["origin"] = (buildEnt.pev.origin + g_Engine.v_right*47).ToString();
				keys["model"] = string(l_shutter.pev.model);
				@ent = g_EntityFuncs.CreateEntity(classname, keys, false);	
				g_EntityFuncs.DispatchSpawn(ent.edict());
				ent.pev.angles = buildEnt.pev.angles;
				
				CBaseEntity@ r_shutter = g_EntityFuncs.FindEntityByTargetname(null, "b_wood_shutter_l");
				keys["origin"] = (buildEnt.pev.origin + g_Engine.v_right*-47).ToString();
				keys["model"] = string(r_shutter.pev.model);
				CBaseEntity@ ent2 = g_EntityFuncs.CreateEntity(classname, keys, false);	
				g_EntityFuncs.DispatchSpawn(ent2.edict());
				ent2.pev.angles = buildEnt.pev.angles + Vector(0,180,0);
				
				ent.pev.vuser1 = ent.pev.angles;
				ent.pev.vuser2 = ent.pev.angles + Vector(0,-150,0);
				
				ent2.pev.vuser1 = ent2.pev.angles;
				ent2.pev.vuser2 = ent2.pev.angles + Vector(0,150,0);
				
				ent.Use(@ent, @ent, USE_TOGGLE, 0.0F);
				ent2.Use(@ent2, @ent2, USE_TOGGLE, 0.0F);
				
				g_SoundSystem.PlaySound(ent.edict(), CHAN_STATIC, "sc_rust/shutters_wood_place.ogg", 1.0f, 1.0f, 0, 90 + Math.RandomLong(0, 20));
				
				g_build_parts.insertLast(BuildPart(ent, g_part_id, parent));
				g_build_parts.insertLast(BuildPart(ent2, g_part_id, parent));
				g_part_id++;
			}
			else
			{				
				@ent = g_EntityFuncs.CreateEntity(classname, keys, true);
				ent.pev.angles = buildEnt.pev.angles;
				
				g_SoundSystem.PlaySound(ent.edict(), CHAN_STATIC, soundFile, 1.0f, 1.0f, 0, 90 + Math.RandomLong(0, 20));
				
				EHandle h_ent = ent;
				g_build_parts.insertLast(BuildPart(ent, g_part_id++, parent));
				
				if (buildType == B_TOOL_CUPBOARD) {
					g_tool_cupboards.insertLast(h_ent);
				}
				
				if (buildType == B_LADDER) {
					ent.pev.rendermode = kRenderTransAlpha;
					ent.pev.renderamt = 255;
					CBaseEntity@ ladder_box = g_EntityFuncs.FindEntityByTargetname(null, "b_ladder_box");
					keys["model"] = string(ladder_box.pev.model);
					CBaseEntity@ ent2 = g_EntityFuncs.CreateEntity("func_ladder", keys, true);	
					ent2.pev.angles = buildEnt.pev.angles;
					ent2.pev.colormap = buildEnt.pev.colormap;
					g_build_parts.insertLast(BuildPart(ent2, g_part_id - 1, parent));
				}
				
				if (buildType == B_LADDER_HATCH) {
					CBaseEntity@ hatch_door = g_EntityFuncs.FindEntityByTargetname(null, "b_ladder_hatch_door");
					keys["origin"] = (buildEnt.pev.origin + g_Engine.v_forward*32 + Vector(0,0,-4)).ToString();
					keys["model"] = string(hatch_door.pev.model);
					keys["distance"] = "9999";
					keys["speed"] = "0.00000001";
					keys["breakable"] = "1";
					keys["targetname"] = "locked";
					CBaseEntity@ ent2 = g_EntityFuncs.CreateEntity("func_door_rotating", keys, true);	
					ent2.pev.angles = buildEnt.pev.angles;
					g_build_parts.insertLast(BuildPart(ent2, g_part_id - 1, g_part_id - 1));
					
					ent2.pev.rendermode = kRenderTransAlpha;
					ent2.pev.renderamt = 255;
					
					ent2.pev.vuser1 = buildEnt.pev.angles;
					ent2.pev.vuser2 = buildEnt.pev.angles + Vector(-82,0,0);
					
					ent2.Use(@ent2, @ent2, USE_TOGGLE, 0.0F);
					
					CBaseEntity@ ladder_box = g_EntityFuncs.FindEntityByTargetname(null, "b_ladder_hatch_ladder");
					keys["origin"] = (buildEnt.pev.origin + g_Engine.v_forward*32).ToString();
					keys["model"] = string(ladder_box.pev.model);
					keys["targetname"] = "ladder_hatch" + (g_part_id - 1);
					keys["spawnflags"] = "1"; // start off
					CBaseEntity@ ent3 = g_EntityFuncs.CreateEntity("func_ladder", keys, true);	
					ent3.pev.angles = buildEnt.pev.angles;
					g_build_parts.insertLast(BuildPart(ent3, g_part_id - 1, g_part_id - 1));
				}
				
				if (buildSocket == SOCKET_DOORWAY)
				{
					ent.pev.vuser1 = buildEnt.pev.angles;
					ent.pev.vuser2 = buildEnt.pev.angles + Vector(0,-110,0);
					
					ent.Use(@ent, @ent, USE_TOGGLE, 0.0F); // start door think function (otherwise rotation won't be animated)
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
