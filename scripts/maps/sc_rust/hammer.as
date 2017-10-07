#include "utils"

void upgradeMenuCallback(CTextMenu@ menu, CBasePlayer@ plr, int page, const CTextMenuItem@ item)
{
	if (item is null)
		return;
	string action;
	item.m_pUserData.retrieve(action);
	PlayerState@ state = getPlayerState(plr);
	
	weapon_hammer@ hammer = null;
	for (uint i = 0; i < MAX_ITEM_TYPES; i++)
	{
		CBasePlayerItem@ wep = plr.m_rgpPlayerItems(i);
		if (wep !is null and wep.pev.classname == "weapon_hammer")
		{
			@hammer = cast<weapon_hammer@>(CastToScriptClass(wep));
		}
	}
	
	if (hammer is null)
	{
		g_PlayerFuncs.PrintKeyBindingString(plr, "You no longer have a hammer");
		return;
	}
	
	if (action == "wood")
		hammer.Upgrade(0);
	if (action == "stone")
		hammer.Upgrade(1);
	if (action == "metal")
		hammer.Upgrade(2);
	if (action == "armor")
		hammer.Upgrade(3);
	
	menu.Unregister();
	@menu = null;
}

class weapon_hammer : ScriptBasePlayerWeaponEntity
{
	float m_flNextAnimTime;
	float nextRepair = 0;
	float nextUpgrade = 0;
	float nextFuse = 0;
	float nextRotate = 0;
	bool active = false;
	bool upgrading = false;
	bool fusing = false;
	float lastHudUpdate = 0;
	bool validTarget = false;
	CBaseEntity@ buildEnt = null;
	CBaseEntity@ buildEnt2 = null;
	CBaseEntity@ lookEnt = null;
	int lastSequence = -1;
	int zoneid = -1;
	float attackDamage = 5.0f;
	array<int> missAnims = {6,8,10};
	array<int> hitAnims = {5,7,9};
	SOUND_CHANNEL lastChannel = CHAN_WEAPON;
	string repairSound = "";
	string swingSound = "sc_rust/hammer_swing.ogg";
	string worldHitSound = "sc_rust/stone_tree.ogg";
	array<string> repairWoodSounds = {"sc_rust/repair_wood.ogg"};
	array<string> repairStoneSounds = {"sc_rust/repair_stone.ogg", "sc_rust/repair_stone2.ogg"};
	array<string> repairMetalSounds = {"sc_rust/repair_metal.ogg", "sc_rust/repair_metal2.ogg"};
	array<string> hitFleshSounds = {"weapons/pwrench_hitbod1.wav", "weapons/pwrench_hitbod2.wav", "weapons/pwrench_hitbod3.wav"};
	
	// repair sounds:
	// wood and twig share sounds
	// metal and armored share sounds
	// build sound plays if repair made
	
	void Spawn()
	{		
		Precache();
		g_EntityFuncs.SetModel( self, "models/sc_rust/w_hammer.mdl" );

		//self.m_iDefaultAmmo = 0;
		//self.m_iClip = self.m_iDefaultAmmo;
		
		self.FallInit();
		SetThink( ThinkFunction( WeaponThink ) );
	}
	
	void Precache()
	{
		self.PrecacheCustomModels();
		g_Game.PrecacheModel( "models/sc_rust/w_hammer.mdl" );
		g_Game.PrecacheModel( "models/sc_rust/p_hammer.mdl" );
		g_Game.PrecacheModel( "models/sc_rust/v_hammer.mdl" );
		
		PrecacheSound(repairSound);
		PrecacheSound(swingSound);
		PrecacheSound(worldHitSound);
		
		for (uint i = 0; i < repairWoodSounds.length(); i++)
			PrecacheSound(repairWoodSounds[i]);
		for (uint i = 0; i < repairStoneSounds.length(); i++)
			PrecacheSound(repairStoneSounds[i]);
		for (uint i = 0; i < repairMetalSounds.length(); i++)
			PrecacheSound(repairMetalSounds[i]);
		for (uint i = 0; i < hitFleshSounds.length(); i++)
			PrecacheSound(hitFleshSounds[i]);
	}
	
	bool GetItemInfo( ItemInfo& out info )
	{				
		info.iMaxAmmo1 	= 20;
		info.iMaxAmmo2 	= -1;
		info.iMaxClip 	= 0;
		info.iSlot 		= 6;
		info.iPosition 	= 10;
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
		
		bool bResult = self.DefaultDeploy( self.GetV_Model( "models/sc_rust/v_hammer.mdl" ), self.GetP_Model( "models/sc_rust/p_hammer.mdl" ), 3, "crowbar" );
		active = true;
		createBuildEnts();
		
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
		
		dictionary keys;
		keys["origin"] = getPlayer().pev.origin.ToString();
		keys["model"] = getModelFromName(g_part_info[0].copy_ent + "_twig");
		keys["rendermode"] = "1";
		keys["renderamt"] = "64";
		keys["rendercolor"] = "0 255 255";
			
		@buildEnt = g_EntityFuncs.CreateEntity("func_illusionary", keys, true);	
		
		@buildEnt2 = g_EntityFuncs.CreateEntity("func_illusionary", keys, true);	
		buildEnt2.pev.rendercolor = Vector(0,200,0);
		buildEnt2.pev.effects |= EF_NODRAW;
	}
	
	void updateBuildPlaceholder()
	{
		CBasePlayer@ plr = getPlayer();
		validTarget = false;
		@lookEnt = null;
		
		// show building placeholder
		if (buildEnt is null)
			return;
		
		TraceResult tr = TraceLook(getPlayer(), 160);
		CBaseEntity@ phit = g_EntityFuncs.Instance( tr.pHit );
		
		
		buildEnt.pev.effects |= EF_NODRAW;
		if (phit is null or phit.pev.classname == "worldspawn" or !isUpgradable(phit))
			return;
			
		buildEnt.pev.effects &= ~EF_NODRAW;
		
		validTarget = true;
		
		//println("ID: " + phit.pev.team);
		for (uint i = 0; i < g_build_parts.size(); i++)
		{	
			func_breakable_custom@ part = cast<func_breakable_custom@>(CastToScriptClass(g_build_parts[i].GetEntity()));
			if (part !is null and part.entindex() == phit.entindex())
			{
				//println("PARENT " + g_build_parts[i].parent);
				if (part.parent != -1)
				{
					array<EHandle> parents = getPartsByID(part.parent);
					if (parents.length() > 0)
						@phit = parents[0];
					else
						println("Couldn't find parent!");
				}
				break;
			}
		}
		
		@lookEnt = @phit;
		buildEnt.pev.origin = phit.pev.origin;
		buildEnt.pev.angles = phit.pev.angles;
		g_EntityFuncs.SetModel(buildEnt, phit.pev.model);
		
		if (fusing and debug_mode)
		{
			te_beampoints(buildEnt.pev.origin, buildEnt.pev.origin + Vector(0,0,64));
			te_beampoints(buildEnt2.pev.origin, buildEnt2.pev.origin + Vector(0,0,64));
			
			g_EngineFuncs.MakeVectors(buildEnt.pev.angles);
			te_beampoints(buildEnt.pev.origin + Vector(0,0,64), buildEnt.pev.origin + Vector(0,0,64) + g_Engine.v_forward*32);
			g_EngineFuncs.MakeVectors(buildEnt2.pev.angles);
			te_beampoints(buildEnt2.pev.origin + Vector(0,0,64), buildEnt2.pev.origin + Vector(0,0,64) + g_Engine.v_forward*32);
		}
	}
	
	void Holster(int iSkipLocal = 0) 
	{
		cancelUpgrade();
		cancelFuse();
		active = false;
		upgrading = false;
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
	
	void cancelUpgrade(string reason="")
	{
		if (!upgrading)
			return;
		if (reason.Length() > 0)
			g_PlayerFuncs.PrintKeyBindingString(getPlayer(), reason);
		getPlayerState(getPlayer()).closeMenus();
		upgrading = false;
		if (buildEnt !is null)
			buildEnt.pev.rendercolor = Vector(0, 255, 255);
	}
	
	void cancelFuse(string reason="")
	{
		if (!fusing)
			return;
		if (reason.Length() > 0)
			g_PlayerFuncs.PrintKeyBindingString(getPlayer(), reason);
		fusing = false;
		if (buildEnt !is null)
			buildEnt.pev.rendercolor = Vector(0, 255, 255);
		if (buildEnt2 !is null)
			buildEnt2.pev.effects |= EF_NODRAW;
	}
	
	void WeaponThink()
	{
		if (active && self.m_hPlayer) 
		{
			CBasePlayer@ plr = getPlayer();
			
			if (!upgrading)
				updateBuildPlaceholder();
				
			if (upgrading and (getCentroid(lookEnt) - plr.pev.origin).Length() > 320)
				cancelUpgrade("Part went out of range");
			if (fusing and (getCentroid(buildEnt2) - plr.pev.origin).Length() > 320)
				cancelFuse("Part went out of range");
			
			if (lastHudUpdate < g_Engine.time + 0.05f)
			{
				lastHudUpdate = g_Engine.time;
				PlayerState@ state = getPlayerState(plr);
				zoneid = getBuildZone(plr);
			
				HUDTextParams params;
				params.effect = 0;
				params.fadeinTime = 0;
				params.fadeoutTime = 0;
				params.holdTime = 0.2f;
				
				params.x = 0.8;
				params.y = 0.88;
				params.channel = 0;
				params.r1 = 255;
				params.g1 = 255;
				params.b1 = 255;
				g_PlayerFuncs.HudMessage(plr, params, 
					"Build Points:\n" + (state.maxPoints(zoneid)-state.getNumParts(zoneid)) + " / " + state.maxPoints(zoneid));
			}	
		}
		
		pev.nextthink = g_Engine.time;
	}
	
	CBasePlayer@ getPlayer()
	{
		CBaseEntity@ e_plr = self.m_hPlayer;
		return cast<CBasePlayer@>(e_plr);
	}

	int getRandomAnim(const array<int>& anims)
	{
		if (anims.length() == 0)
			return 0;

		lastSequence = (lastSequence+1) % anims.length();
		return anims[lastSequence];
	}
	
	string getRandomSound(array<string>& sounds)
	{
		if (sounds.length() == 0)
			return "NO_SOUNDS";
		int randIdx = Math.RandomLong(0, sounds.length()-1);
		return sounds[randIdx];
	}
	
	TraceResult meleeTrace()
	{
		CBasePlayer@ plr = getPlayer();
		Vector vecSrc = plr.GetGunPosition();
		Math.MakeVectors( plr.pev.v_angle );
		Vector vecAiming = g_Engine.v_forward;
		
		plr.SetAnimation( PLAYER_ATTACK1 );
		
		TraceResult tr;
		Vector vecEnd = vecSrc + vecAiming * 32;
		g_Utility.TraceLine( vecSrc, vecEnd, dont_ignore_monsters, plr.edict(), tr );
		
		if ( tr.flFraction >= 1.0)
		{
			// This does a trace in the form of a box so there is a much higher chance of hitting something
			// From crowbar.cpp in the hlsdk:
			g_Utility.TraceHull( vecSrc, vecEnd, dont_ignore_monsters, head_hull, plr.edict(), tr );
			if ( tr.flFraction < 1.0 )
			{
				// Calculate the point of intersection of the line (or hull) and the object we hit
				// This is and approximation of the "best" intersection
				CBaseEntity@ pHit = g_EntityFuncs.Instance( tr.pHit );
				if ( pHit is null or pHit.IsBSPModel() )
					g_Utility.FindHullIntersection( vecSrc, tr, tr, VEC_DUCK_HULL_MIN, VEC_DUCK_HULL_MAX, plr.edict() );
				vecEnd = tr.vecEndPos;	// This is the point on the actual surface (the hull could have hit space)
			}
		}
		return tr;
	}
	
	void Melee()
	{
		CBasePlayer@ plr = getPlayer();
		TraceResult tr = meleeTrace();
		
		bool meleeHit = tr.flFraction < 1.0;
		
		lastChannel = lastChannel == CHAN_WEAPON ? CHAN_VOICE : CHAN_WEAPON;
		if( tr.flFraction < 1.0 )
		{
			self.SendWeaponAnim( getRandomAnim(hitAnims), 0, 0 );
			if( tr.pHit !is null )
			{
				CBaseEntity@ pHit = g_EntityFuncs.Instance( tr.pHit );
				
				if( pHit !is null ) 
				{
					if (pHit.pev.classname == "func_breakable_custom" or pHit.pev.classname == "func_door_rotating")
					{
						if (pHit.pev.health < pHit.pev.max_health)
						{
							float healAmt = Math.min(10, pHit.pev.max_health - pHit.pev.health);
							pHit.pev.health += healAmt;
							
						}
						g_SoundSystem.PlaySound(plr.edict(), lastChannel, getRandomSound(repairWoodSounds), 1.0f, 1.0f, 0, 90 + Math.RandomLong(0, 20));
					}
					else if ((pHit.IsPlayer() or pHit.IsMonster()) and !pHit.IsMachine())
					{
						g_SoundSystem.PlaySound(plr.edict(), lastChannel, getRandomSound(hitFleshSounds), 0.9f, 1.0f, 0, 90 + Math.RandomLong(0, 20));

						g_WeaponFuncs.ClearMultiDamage(); // fixes TraceAttack() crash for some reason
						Vector attackDir = (tr.vecEndPos - plr.GetGunPosition()).Normalize();
						pHit.TraceAttack(plr.pev, attackDamage, attackDir, tr, DMG_CLUB);
						g_WeaponFuncs.ApplyMultiDamage(pHit.pev, plr.pev);
					}
					else
					{
						g_SoundSystem.PlaySound(plr.edict(), lastChannel, worldHitSound, 0.9f, 1.0f, 0, 90 + Math.RandomLong(0, 20));
					}
				}
			}
		}
		else
		{
			self.SendWeaponAnim( getRandomAnim(missAnims), 0, 0 );
			g_SoundSystem.PlaySound(plr.edict(), lastChannel, swingSound, 1.0f, 1.0f, 0, 90 + Math.RandomLong(0, 20));
		}
	}
	
	void UpgradeMenu()
	{
		CBasePlayer@ plr = getPlayer();
		PlayerState@ state = getPlayerState(getPlayer());
		state.initMenu(plr, upgradeMenuCallback);

		state.menu.SetTitle("Upgrade to:\n\n");
		state.menu.AddItem("Wood\n", any("wood"));
		state.menu.AddItem("Stone\n", any("stone"));
		state.menu.AddItem("Metal\n", any("metal"));
		state.menu.AddItem("Armor\n", any("armor"));
		
		state.openMenu(plr);
	}
	
	void Upgrade(int material)
	{
		if (active and upgrading) 
		{			
			string matname = g_upgrade_suffixes[material+1];
			string partname = g_part_info[lookEnt.pev.colormap].copy_ent;
			string size = getModelSize(lookEnt);
			if (size == "_1x1")
				size = "";
			
			g_EntityFuncs.SetModel( lookEnt, getModelFromName(partname + size + matname));
			if (lookEnt.pev.colormap == B_ROOF)
				updateRoofWalls(lookEnt);
			if (buildEnt !is null)
				buildEnt.pev.rendercolor = Vector(0, 255, 255);
				
			int health = 100;
			switch(material)
			{
				case 0: health = 2500; break;
				case 1: health = 5000; break;
				case 2: health = 7000; break;
				case 3: health = 9000; break;
			}
			lookEnt.pev.health = lookEnt.pev.max_health = health;
		}
		else
			g_PlayerFuncs.PrintKeyBindingString(getPlayer(), "Hammer not active");
			
		upgrading = false;
	}
	
	void Separate(CBaseEntity@ ent)
	{
		g_EngineFuncs.MakeVectors(ent.pev.angles);
		
		int fuseType = ent.pev.colormap;
		int socket = socketType(ent.pev.colormap);
		string size = getModelSize(ent);
		string material = getMaterialType(ent);
		int fuseZone = getBuildZone(ent);
		
		array<CBaseEntity@> parts = { @ent };
		
		string prefix;
		if (fuseType == B_FOUNDATION or fuseType == B_FLOOR)
		{
			prefix = fuseType == B_FOUNDATION ? "b_foundation" : "b_floor";
			
			if (size == "_2x1")
			{
				parts.insertLast(getPartAtPos(ent.pev.origin + g_Engine.v_right*128));
			}
			else if (size == "_3x1")
			{
				parts.insertLast(getPartAtPos(ent.pev.origin + g_Engine.v_right*128));
				parts.insertLast(getPartAtPos(ent.pev.origin + g_Engine.v_right*256));
			}
			else if (size == "_4x1")
			{
				parts.insertLast(getPartAtPos(ent.pev.origin + g_Engine.v_right*128));
				parts.insertLast(getPartAtPos(ent.pev.origin + g_Engine.v_right*256));
				parts.insertLast(getPartAtPos(ent.pev.origin + g_Engine.v_right*384));
			}
			else if (size == "_2x2")
			{
				parts.insertLast(getPartAtPos(ent.pev.origin + g_Engine.v_right*128));
				parts.insertLast(getPartAtPos(ent.pev.origin + g_Engine.v_forward*128));
				parts.insertLast(getPartAtPos(ent.pev.origin + g_Engine.v_forward*128 + g_Engine.v_right*128));
			}
		}
		else if (fuseType == B_FOUNDATION_TRI or fuseType == B_FLOOR_TRI)
		{
			prefix = fuseType == B_FOUNDATION_TRI ? "b_foundation_tri" : "b_floor_tri";
			
			if (size == "_2x1")
			{
				parts.insertLast(getPartAtPos(ent.pev.origin + g_Engine.v_right*64 + g_Engine.v_forward*36.95));
			}
			else if (size == "_3x1")
			{
				parts.insertLast(getPartAtPos(ent.pev.origin + g_Engine.v_right*64 + g_Engine.v_forward*36.95));
				parts.insertLast(getPartAtPos(ent.pev.origin + g_Engine.v_right*128));
			}
			else if (size == "_4x1")
			{
				parts.insertLast(getPartAtPos(ent.pev.origin + g_Engine.v_right*64 + g_Engine.v_forward*36.95));
				parts.insertLast(getPartAtPos(ent.pev.origin + g_Engine.v_right*128));
				parts.insertLast(getPartAtPos(ent.pev.origin + g_Engine.v_right*192 + g_Engine.v_forward*36.95));
			}
			else if (size == "_1x4")
			{
				parts.insertLast(getPartAtPos(ent.pev.origin + g_Engine.v_right*-64 + g_Engine.v_forward*36.95));
				parts.insertLast(getPartAtPos(ent.pev.origin + g_Engine.v_right*-128));
				parts.insertLast(getPartAtPos(ent.pev.origin + g_Engine.v_right*-192 + g_Engine.v_forward*36.95));
			}
			else if (size == "_2x2")
			{
				parts.insertLast(getPartAtPos(ent.pev.origin + g_Engine.v_right*64 + g_Engine.v_forward*36.95));
				parts.insertLast(getPartAtPos(ent.pev.origin + g_Engine.v_right*128));
				parts.insertLast(getPartAtPos(ent.pev.origin + g_Engine.v_right*64 + g_Engine.v_forward*110.85));
			}
		}
		else if (socket == SOCKET_WALL)
		{
			prefix = "b_wall";
			if (fuseType == B_WINDOW) 
				prefix = "b_window";
			if (fuseType == B_DOORWAY)
				prefix = "b_doorway";
			if (fuseType == B_LOW_WALL)
				prefix = "b_low_wall";
			
			if (size == "_2x1")
			{
				parts.insertLast(getPartAtPos(ent.pev.origin + g_Engine.v_right*128));
			}
			else if (size == "_3x1")
			{
				parts.insertLast(getPartAtPos(ent.pev.origin + g_Engine.v_right*128));
				parts.insertLast(getPartAtPos(ent.pev.origin + g_Engine.v_right*256));
			}
			else if (size == "_4x1")
			{
				parts.insertLast(getPartAtPos(ent.pev.origin + g_Engine.v_right*128));
				parts.insertLast(getPartAtPos(ent.pev.origin + g_Engine.v_right*256));
				parts.insertLast(getPartAtPos(ent.pev.origin + g_Engine.v_right*384));
			}
			else if (size == "_1x2")
			{
				parts.insertLast(getPartAtPos(ent.pev.origin + g_Engine.v_up*128));
			}
			else if (size == "_1x3")
			{
				parts.insertLast(getPartAtPos(ent.pev.origin + g_Engine.v_up*128));
				parts.insertLast(getPartAtPos(ent.pev.origin + g_Engine.v_up*256));
			}
			else if (size == "_1x4")
			{
				parts.insertLast(getPartAtPos(ent.pev.origin + g_Engine.v_up*128));
				parts.insertLast(getPartAtPos(ent.pev.origin + g_Engine.v_up*256));
				parts.insertLast(getPartAtPos(ent.pev.origin + g_Engine.v_up*384));
			}
			else if (size == "_2x2")
			{
				parts.insertLast(getPartAtPos(ent.pev.origin + g_Engine.v_right*128));
				parts.insertLast(getPartAtPos(ent.pev.origin + g_Engine.v_up*128));
				parts.insertLast(getPartAtPos(ent.pev.origin + g_Engine.v_up*128 + g_Engine.v_right*128));
			}
		}
	
		
		PlayerState@ state = getPlayerStateBySteamID(ent.pev.noise1, ent.pev.noise2);
		if (state.getNumParts(fuseZone) + parts.length()-1 > state.maxPoints(fuseZone))
		{
			cancelFuse("Not enough build points to separate!");
			return;
		}
		if (state !is null)
			state.addPartCount(parts.length() - 1, fuseZone);
		
		// disconnect children
		for (uint i = 0; i < g_build_parts.size(); i++)
		{
			func_breakable_custom@ part = cast<func_breakable_custom@>(CastToScriptClass(g_build_parts[i].GetEntity()));
			if (part.parent == ent.pev.team) 
			{
				part.parent = -1;
			}
		}
		
		for (uint i = 0; i < parts.length(); i++)
		{
			if (parts[i] is null)
			{
				println("Failed to get adjacent square during separation");
				continue;
			}
			parts[i].pev.model = getModelFromName(prefix + material);
			if (socket == SOCKET_WALL)
				parts[i].pev.angles.y = ent.pev.angles.y;
			respawnPart(parts[i].pev.team);
			
			func_breakable_custom@ bpart = cast<func_breakable_custom@>(CastToScriptClass(parts[i]));
			bpart.parent = -1;
		}

		cancelFuse("Fused parts were separated");
	}
	
	void Fuse()
	{
		CBaseEntity@ part1 = getPartAtPos(buildEnt2.pev.origin);
		CBaseEntity@ part2 = getPartAtPos(buildEnt.pev.origin);
			
		if (part1.pev.colormap != part2.pev.colormap)
		{
			cancelFuse("Can only fuse parts of the same type");
			return;
		}
	
		string size1 = getModelSize(part1);
		string size2 = getModelSize(part2);
		int isize1 = getModelSizei(part1);
		int isize2 = getModelSizei(part2);
		int mergeSize = isize1 + isize2;
		
		if (part1.entindex() == part2.entindex())
		{
			if (isize1 > 1)
				Separate(part1);
			else
				cancelFuse("Can't fuse a part with itself");
			return;
		}
		
		PlayerState@ state1 = getPlayerStateBySteamID(part1.pev.noise1, part1.pev.noise2);
		PlayerState@ state2 = getPlayerStateBySteamID(part2.pev.noise1, part2.pev.noise2);
		
		if (state1.plr.GetEntity() != state2.plr.GetEntity())
		{
			cancelFuse("Can't fuse parts owned by other players");
			return;
		}
		
		if (mergeSize > 4)
		{
			cancelFuse("Can't fuse more than 4 parts together");
			return;
		}
		
		string material = getMaterialType(part1);
		string mat2 = getMaterialType(part2);
		if (material != mat2)
		{
			cancelFuse("Can only fuse parts of the same material");
			return;
		}
		
		int fuseZone = getBuildZone(part1);
		if (fuseZone != getBuildZone(part2))
		{
			cancelFuse("Can only fuse parts in the same zone");
			return;
		}
		
		if (isize2 > isize1)
		{
			CBaseEntity@ temp = @part1;
			@part1 = @part2;
			@part2 = @temp;
			
			string stemp = size1;
			size1 = size2;
			size2 = stemp;
			
			int itemp = isize1;
			isize1 = isize1;
			isize2 = itemp;
		}
		
		string curSize = getModelSize(part1);
		string newModel;
		int fuseType = part1.pev.colormap;
		int socket = socketType(part1.pev.colormap);
		float dist = (part1.pev.origin - part2.pev.origin).Length();
		Vector dir = (part2.pev.origin - part1.pev.origin).Normalize();
		if (fuseType == B_FOUNDATION or fuseType == B_FLOOR)
		{
			string prefix = fuseType == B_FOUNDATION ? "b_foundation" : "b_floor";
			
			if (mergeSize == 2)
			{
				if (abs(dist - 128) > EPSILON)
				{
					cancelFuse("Can only fuse adjacent pieces");
					return;
				}

				g_EngineFuncs.MakeVectors(part1.pev.angles);
				
				if (DotProduct(dir, g_Engine.v_forward) > 0.9f) // front
					part1.pev.angles.y += 90;
				else if (DotProduct(dir, -g_Engine.v_forward) > 0.9f) // back
					part1.pev.angles.y += -90;
				else if (DotProduct(dir, -g_Engine.v_right) > 0.9f) // left
					part1.pev.angles.y += 180;
				
				newModel = prefix + "_2x1" + material;
			}
			else if (size1 == "_2x1" and size2 == "_2x1")
			{
				g_EngineFuncs.MakeVectors(part2.pev.angles);
				Vector p2_right = g_Engine.v_right;
				g_EngineFuncs.MakeVectors(part1.pev.angles);
				
				if ((abs(dist - 128) > EPSILON and abs(dist - 181.019) > EPSILON and abs(dist - 256) > EPSILON and abs(dist - 384) > EPSILON) or
					(abs(dist - 181.019) < EPSILON and DotProduct(p2_right, g_Engine.v_right) > 0.9f))
				{
					cancelFuse("Can only fuse adjacent pieces");
					return;
				}
				
				string newSize = "_2x2";
				
				if (DotProduct(dir, -g_Engine.v_right) > 0.9f) // left
				{
					newSize = "_4x1";

					if (abs(dist - 128) < EPSILON) // facing opposite directions (outward, not inward)
					{
						float newAngle = part1.pev.angles.y + 180;
						part1.pev.effects |= EF_NODRAW;
						part1.pev.solid = SOLID_NOT;
						@part1 = getPartAtPos(part1.pev.origin + g_Engine.v_right*128);
						if (part1 is null)
						{
							println("Failed to get adjacent square during fusion");
							return;
						}
						@part1 = respawnPart(part1.pev.team);
						part1.pev.angles.y = newAngle;
					}
					else
					{
						CBaseEntity@ temp = @part1;
						@part1 = @part2;
						@part2 = @temp;
					}
				}
				else if (DotProduct(dir, g_Engine.v_right) > 0.9f) // right
				{
					newSize = "_4x1";
				}
				else if (DotProduct(dir, -g_Engine.v_forward) > 0.2f) // behind
				{
					part1.pev.angles.y -= 90;
				}
				
				if ( abs(DotProduct(dir, g_Engine.v_forward)) > EPSILON and newSize == "_4x1")
				{
					cancelFuse("Can only fuse adjacent pieces");
					return;
				}
				
				newModel = prefix + newSize + material;
			}
			else if (mergeSize == 3)
			{				
				g_EngineFuncs.MakeVectors(part1.pev.angles);
				
				if (abs(dist - 128) > EPSILON and (DotProduct(dir, -g_Engine.v_right) > 0.9f and abs(dist - 256) > EPSILON)) //CHECK
				{
					cancelFuse("Can only fuse adjacent pieces");
					return;
				}
				if (abs(DotProduct(dir, -g_Engine.v_forward)) > 0.1f) // behind
				{
					cancelFuse("Fused pieces must form a rectangle");
					return;
				}

				if (DotProduct(dir, -g_Engine.v_right) > 0.9f) // left
				{
					part2.pev.angles.y = part1.pev.angles.y;
					CBaseEntity@ temp = @part1;
					@part1 = @part2;
					@part2 = @temp;
				}
				
				newModel = prefix + "_3x1" + material;
			}
			else if (mergeSize == 4 and size2 == "_1x1")
			{				
				g_EngineFuncs.MakeVectors(part1.pev.angles);
				
				if (abs(dist - 128) > EPSILON and (DotProduct(dir, -g_Engine.v_right) > 0.9f and abs(dist - 384) > EPSILON)) // CHECK
				{
					cancelFuse("Can only fuse adjacent pieces");
					return;
				}
				if (abs(DotProduct(dir, -g_Engine.v_forward)) > 0.1f) // behind
				{
					cancelFuse("Fused pieces must form a rectangle");
					return;
				}

				if (DotProduct(dir, -g_Engine.v_right) > 0.9f) // left
				{
					CBaseEntity@ temp = @part1;
					@part1 = @part2;
					@part2 = @temp;
				}
				
				newModel = prefix + "_4x1" + material;
			}
			else
			{
				cancelFuse("Fused pieces must form a rectangle");
				return;
			}
		}
		else if (fuseType == B_FOUNDATION_TRI or fuseType == B_FLOOR_TRI)
		{
			if (mergeSize == 2)
			{
				if (abs(dist - 73.899) > EPSILON)
				{
					cancelFuse("Can only fuse adjacent pieces");
					return;
				}

				g_EngineFuncs.MakeVectors(part1.pev.angles);
				
				if (DotProduct(dir, -g_Engine.v_forward) > 0.7f) // back
					part1.pev.angles.y -= 120;
				else if (DotProduct(dir, -g_Engine.v_right) > 0.7f) // left
					part1.pev.angles.y += 120;
				
				string prefix = fuseType == B_FOUNDATION_TRI ? "b_foundation_tri" : "b_floor_tri";
				newModel = prefix + "_2x1" + material;
			}
			else if (mergeSize == 3)
			{
				g_EngineFuncs.MakeVectors(part1.pev.angles);
				
				if (abs(dist - 73.899) > EPSILON and abs(dist - 128) > EPSILON or
					(DotProduct(dir, -g_Engine.v_forward) > 0.2f and abs(DotProduct(dir, g_Engine.v_right)) > 0.2f) or
					(DotProduct(dir, -g_Engine.v_right) > 0.5f and abs(dist - 128) < EPSILON) or
					(DotProduct(dir, g_Engine.v_forward) > 0.7f and DotProduct(dir, -g_Engine.v_right) > 0.2f))
				{
					cancelFuse("Can only fuse adjacent pieces");
					return;
				}
				
				if (DotProduct(dir, -g_Engine.v_forward) > 0.7f) // back
				{
					CBaseEntity@ temp = @part1;
					@part1 = @part2;
					@part2 = @temp;
					part1.pev.angles.y = part2.pev.angles.y + 60;
				}
				else if (DotProduct(dir, g_Engine.v_right) > 0.2f and DotProduct(dir, g_Engine.v_forward) > 0.2f) // front & right a bit
				{
					CBaseEntity@ temp = @part1;
					@part1 = @part2;
					@part2 = @temp;
					part1.pev.angles.y = part2.pev.angles.y - 120;
				}
				else if (DotProduct(dir, -g_Engine.v_right) > 0.4f) // left
				{
					float newAngle = part1.pev.angles.y + 180;
					part1.pev.effects |= EF_NODRAW;
					part1.pev.solid = SOLID_NOT;
					@part1 = getPartAtPos(part1.pev.origin + g_Engine.v_right*64 + g_Engine.v_forward*36.95);
					if (part1 is null)
					{
						println("Failed to get adjacent tri during fusion");
						return;
					}
					@part1 = respawnPart(part1.pev.team);
					part1.pev.angles.y = newAngle;
				}
				
				string prefix = fuseType == B_FOUNDATION_TRI ? "b_foundation_tri" : "b_floor_tri";
				newModel = prefix + "_3x1" + material;
			}
			else if (mergeSize == 4)
			{
				g_EngineFuncs.MakeVectors(part2.pev.angles);
				Vector pright = g_Engine.v_right;
				g_EngineFuncs.MakeVectors(part1.pev.angles);
				
				println("the d " + dist);
				
				if ((abs(dist - 73.899) > EPSILON and abs(dist - 128) > EPSILON and abs(dist - 195.521) > EPSILON) or
					(curSize == "_3x1" and abs(dist - 195.521) < EPSILON and DotProduct(dir, g_Engine.v_forward) > 0.4f) or 
					(curSize == "_3x1" and DotProduct(dir, g_Engine.v_forward) > 0.7f and DotProduct(dir, -g_Engine.v_right) > 0.1f) or 
					(curSize == "_2x1" and abs(DotProduct(pright, g_Engine.v_right)) < 0.9f ) or
					(curSize == "_2x1" and DotProduct(dir, -g_Engine.v_forward) > 0.1f and DotProduct(dir, g_Engine.v_right) > 0.1f ) or
					(curSize == "_3x1" and DotProduct(dir, -g_Engine.v_forward) > 0.1f) or
					(curSize == "_3x1" and DotProduct(dir, -g_Engine.v_right) > 0.1f and abs(dist - 73.899) > EPSILON))
				{
					cancelFuse("Can only fuse adjacent pieces");
					return;
				}

				string newSize = "_4x1";
				
				if (size1 == "_3x1" and DotProduct(dir, g_Engine.v_forward) > 0.6f) // front & right a bit
				{
					newSize = "_2x2";
				}
				else if (size1 == "_2x1" and DotProduct(dir, g_Engine.v_forward) > 0.6f)
				{
					newSize = "_1x4";
					part1.pev.angles.y -= 120;
				}
				else if (DotProduct(dir, -g_Engine.v_right) > 0.7f and size1 == "_2x1" and abs(dist - 73.899) < EPSILON)
				{
					float newAngle = part1.pev.angles.y;
					part1.pev.effects |= EF_NODRAW;
					part1.pev.solid = SOLID_NOT;
					@part1 = getPartAtPos(part1.pev.origin + g_Engine.v_right*-128);
					if (part1 is null)
					{
						println("Failed to get adjacent tri during fusion");
						return;
					}
					@part1 = respawnPart(part1.pev.team);
					part1.pev.angles.y = newAngle;
				}
				else if ((DotProduct(dir, -g_Engine.v_forward) > 0.7f and size1 == "_2x1" and abs(dist - 73.899) < EPSILON))
				{
					newSize = "_1x4";
					float newAngle = part1.pev.angles.y + 60;
					part1.pev.effects |= EF_NODRAW;
					part1.pev.solid = SOLID_NOT;
					@part1 = getPartAtPos(part1.pev.origin + g_Engine.v_right*64 + g_Engine.v_forward*36.95);
					if (part1 is null)
					{
						println("Failed to get adjacent tri during fusion");
						return;
					}
					@part1 = respawnPart(part1.pev.team);
					part1.pev.angles.y = newAngle;
				}
				else if (DotProduct(dir, -g_Engine.v_right) > 0.7f) // left
				{
					if (size2 == "_1x1")
					{
						newSize = "_1x4";
						part2.pev.angles.y = part1.pev.angles.y + 180;
					}
					CBaseEntity@ temp = @part1;
					@part1 = @part2;
					@part2 = @temp;
				}
				
				string prefix = fuseType == B_FOUNDATION_TRI ? "b_foundation_tri" : "b_floor_tri";
				newModel = prefix + newSize + material;
			}
			else
			{
				cancelFuse("Fused piece must be convex");
				return;
			}
		}
		else if (socket == SOCKET_WALL)
		{
			g_EngineFuncs.MakeVectors(part2.pev.angles);
			Vector pright = g_Engine.v_right;
			g_EngineFuncs.MakeVectors(part1.pev.angles);
			
			if (DotProduct(g_Engine.v_right, pright) < -0.9f)
			{
				cancelFuse("Walls not facing the same direction");
				return;
			}
			
			string prefix = "b_wall";
			if (fuseType == B_WINDOW)
				prefix = "b_window";
			if (fuseType == B_DOORWAY)
				prefix = "b_doorway";
			if (fuseType == B_LOW_WALL)
				prefix = "b_low_wall";
			
			if (mergeSize == 2)
			{
				if (abs(dist - 128) > EPSILON)
				{
					cancelFuse("Can only fuse adjacent pieces");
					return;
				}

				g_EngineFuncs.MakeVectors(part1.pev.angles);
				
				string newSize = "_2x1";
				
				if (DotProduct(dir, -g_Engine.v_right) > 0.9f) // left
				{
					CBaseEntity@ temp = @part1;
					@part1 = @part2;
					@part2 = @temp;
				}
				else if (DotProduct(dir, g_Engine.v_up) > 0.9f) // up
					newSize = "_1x2";
				else if (DotProduct(dir, -g_Engine.v_up) > 0.9f) // down
				{	
					newSize = "_1x2";
					CBaseEntity@ temp = @part1;
					@part1 = @part2;
					@part2 = @temp;
				}
				
				if (fuseType == B_LOW_WALL and newSize == "_1x2")
				{
					cancelFuse("Can only fuse adjacent pieces");
					return;
				}
				
				newModel = prefix + newSize + material;
			}
			else if (mergeSize == 4 and (curSize == "_2x1" or curSize == "_1x2"))
			{
				if ((abs(dist - 128) > EPSILON and abs(dist - 181.019) > EPSILON and abs(dist - 256) > EPSILON and abs(dist - 384) > EPSILON) or
					(abs(dist - 181.019) < EPSILON and DotProduct(pright, g_Engine.v_right) > 0.9f))
				{
					cancelFuse("Can only fuse adjacent pieces");
					return;
				}
				
				string newSize = "_2x2";
				
				if (dist > 255)
				{
					newSize = abs(dir.z) > 0.1f ? "_1x4" : "_4x1";
					if (DotProduct(dir, -g_Engine.v_right) > 0.9f or DotProduct(dir, -g_Engine.v_up) > 0.9f)
					{
						CBaseEntity@ temp = @part1;
						@part1 = @part2;
						@part2 = @temp;
					}
				}
				else if ((curSize == "_2x1" and DotProduct(dir, -g_Engine.v_up) > 0.2f) or
						(curSize == "_1x2" and DotProduct(dir, -g_Engine.v_right) > 0.9f)) // down or left
				{	
					CBaseEntity@ temp = @part1;
					@part1 = @part2;
					@part2 = @temp;
				}
				
				if (fuseType == B_LOW_WALL and abs(dir.z) > 0.1f)
				{
					cancelFuse("Can only fuse adjacent pieces");
					return;
				}
				
				newModel = prefix + newSize + material;
			}
			else if (mergeSize == 4 and (curSize == "_3x1" or curSize == "_1x3"))
			{
				if (abs(dist - 128) > EPSILON and 
					(DotProduct(dir, g_Engine.v_right) < 0.9f and abs(dist - 384) > EPSILON) )
				{
					cancelFuse("Can only fuse adjacent pieces");
					return;
				}
				
				string newSize = abs(dir.z) > 0.1f ? "_1x4" : "_4x1";
				
				if (DotProduct(dir, -g_Engine.v_up) > 0.1f or DotProduct(dir, -g_Engine.v_right) > 0.1f) // down/left
				{	
					CBaseEntity@ temp = @part1;
					@part1 = @part2;
					@part2 = @temp;
				}
				
				newModel = prefix + newSize + material;
			}
			else if (mergeSize == 3)
			{
				if ((abs(dist - 128) > EPSILON and abs(dist - 256) > EPSILON) or
					(curSize == "_2x1" and abs(DotProduct(dir, g_Engine.v_up)) > 0.1f) or
					(curSize == "_1x2" and abs(DotProduct(dir, g_Engine.v_right)) > 0.1f))
				{
					cancelFuse("Can only fuse adjacent pieces");
					return;
				}
				
				string newSize = abs(dir.z) > 0.1f ? "_1x3" : "_3x1";
				
				if (DotProduct(dir, -g_Engine.v_up) > 0.1f or DotProduct(dir, -g_Engine.v_right) > 0.1f) // down/left
				{	
					CBaseEntity@ temp = @part1;
					@part1 = @part2;
					@part2 = @temp;
				}
				
				newModel = prefix + newSize + material;
			}
		}
		
		if (newModel.Length() > 0)
		{
			PlayerState@ state = getPlayerStateBySteamID(part2.pev.noise1, part2.pev.noise2);
			if (state !is null)
				state.addPartCount(-1, fuseZone);
			
			func_breakable_custom@ b1 = getBuildPartByID(part1.pev.team);
			int oldParent = b1.parent;
			b1.parent = -1;
			
			g_EntityFuncs.SetModel(part1, getModelFromName(newModel));
			part2.pev.effects |= EF_NODRAW;
			part2.pev.solid = SOLID_NOT;
			// set invisible part (and its children) as child of fused part (so they get destroyed properly)
			for (uint i = 0; i < g_build_parts.size(); i++)
			{
				func_breakable_custom@ part = cast<func_breakable_custom@>(CastToScriptClass(g_build_parts[i].GetEntity()));
				if (part !is null)
				{
					// reparent attachment point and its children
					if (part.pev.team == part2.pev.team or part.parent == part2.pev.team or 
						(oldParent != -1 and part.parent == oldParent or part.pev.team == oldParent))
					{
						//println("REPARENT " + part.pev.team + " FROM " + part.parent + " TO " + part1.pev.team);
						part.parent = part1.pev.team;
					}
				}
			}
			cancelFuse();
			return;
		}
		cancelFuse("Sorry, can't fuse those");
	}

	void PrimaryAttack()  
	{
		if (nextRepair < g_Engine.time) {
			nextRepair = g_Engine.time + 0.6f;
			Melee();
		}
	}
	
	void SecondaryAttack() 
	{
		if (nextUpgrade < g_Engine.time) {
			nextUpgrade = g_Engine.time + 0.6f;
			if (validTarget)
			{
				if (upgrading)
					cancelUpgrade("Upgrade cancelled");
				else
				{
					upgrading = true;
					buildEnt.pev.rendercolor = Vector(255, 128, 0);
					UpgradeMenu();
				}
			}
			else
			{
				g_PlayerFuncs.PrintKeyBindingString(getPlayer(), "Highlight a part to upgrade it");
				
				// I sometimes press a number on accident when i expect a part to be highlighted.
				// So, always open a menu so that I don't get annoyed.
				getPlayerState(getPlayer()).closeMenus();
			}
		}
	}
	
	void TertiaryAttack()
	{ 
		if (nextFuse < g_Engine.time) {
			nextFuse = g_Engine.time + 0.6f;
			cancelUpgrade();
			if (validTarget)
			{
				if (fusing)
				{
					Fuse();
				}
				else
				{
					fusing = true;
					buildEnt.pev.rendercolor = Vector(0, 200, 0);
					
					buildEnt2.pev.effects &= ~EF_NODRAW;
					buildEnt2.pev.origin = buildEnt.pev.origin;
					buildEnt2.pev.angles = buildEnt.pev.angles;
					g_EntityFuncs.SetModel(buildEnt2, buildEnt.pev.model);
				}
			}
			else
			{
				if (fusing)
				{
					cancelFuse("No part selected to fuse with");
				}
				else
					g_PlayerFuncs.PrintKeyBindingString(getPlayer(), "Highlight a part to begin fusing");
			}
		}
	}
	
	void Reload()
	{
		if (nextRotate < g_Engine.time) {
			nextRotate = g_Engine.time + 0.6f;
			if (validTarget)
			{
				int partType = lookEnt.pev.colormap;
				int socket = socketType(lookEnt.pev.colormap);
				g_EngineFuncs.MakeVectors(lookEnt.pev.angles);
				if (socket == SOCKET_WALL)
				{
					string modelSize = getModelSize(lookEnt);
					if (modelSize == "_2x1" or modelSize == "_2x2" or modelSize == "_3x1" or modelSize == "_4x1")
					{
						int oldParent = lookEnt.pev.team;
						float dist = 128;
						if (modelSize == "_3x1")
							dist = 256;
						if (modelSize == "_4x1")
							dist = 384;
						CBaseEntity@ right = getPartAtPos(lookEnt.pev.origin + g_Engine.v_right*dist);
						if (right !is null)
						{
							string temp1 = lookEnt.pev.model;
							string temp2 = right.pev.model;
							g_EntityFuncs.SetModel(right, temp1);
							g_EntityFuncs.SetModel(lookEnt, temp2);
							lookEnt.pev.effects |= EF_NODRAW;
							lookEnt.pev.solid = SOLID_NOT;
							lookEnt.pev.angles.y += 180;
							right.pev.angles.y += 180;
							
							// can't just turn on solidity or else the part will become semi-solid (game bug)
							@right = respawnPart(right.pev.team);
							
							
							for (uint i = 0; i < g_build_parts.size(); i++)
							{
								func_breakable_custom@ part = cast<func_breakable_custom@>(CastToScriptClass(g_build_parts[i].GetEntity()));
								if (part !is null and (part.entindex() == lookEnt.entindex() or part.parent == oldParent))
								{
									part.parent = right.pev.team;
								}
								if (part !is null and (part.entindex() == right.entindex()))
								{
									part.parent = -1;
								}
							}
						}
					}
					else
					{
						lookEnt.pev.angles.y += 180;
					}
				}
				else if (partType == B_STAIRS or partType == B_STAIRS_L)
				{
					lookEnt.pev.angles.y -= 90;
				}
				else if (partType == B_ROOF)
				{
					Vector oldPos = lookEnt.pev.origin;
					lookEnt.pev.angles.y += 180;
					lookEnt.pev.origin = oldPos + g_Engine.v_forward*128;
					updateRoofWalls(lookEnt);
					updateRoofWalls(getPartAtPos(oldPos + g_Engine.v_right*128));
					updateRoofWalls(getPartAtPos(oldPos + g_Engine.v_right*-128));
					updateRoofWalls(getPartAtPos(lookEnt.pev.origin + g_Engine.v_right*128));
					updateRoofWalls(getPartAtPos(lookEnt.pev.origin + g_Engine.v_right*-128));
				}
				else
				{
					g_PlayerFuncs.PrintKeyBindingString(getPlayer(), "This type of part can't be rotated");
				}
			}
			else
			{
				g_PlayerFuncs.PrintKeyBindingString(getPlayer(), "Highlight a part to rotate it");
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
