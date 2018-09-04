int g_heli_idx = 0;

void heli_think(EHandle h_heli)
{
	CBaseMonster@ heli = cast<CBaseMonster@>(h_heli.GetEntity());
	CBaseEntity@ target = g_EntityFuncs.FindEntityByTargetname(null, heli.pev.target);
	
	if (heli is null or target is null)
	{
		g_Scheduler.SetTimeout("spawn_heli", Math.RandomFloat(g_apache_min_delay, g_apache_max_delay)*60);
		return;
	}
	
	CBaseEntity@ enemy = heli.m_hEnemy;
	
	float dist = (heli.pev.origin - target.pev.origin).Length();
	bool readyToMove = dist < 400.0f;
	
	float aliveTime = g_Engine.time - heli.pev.teleport_time;
	if (aliveTime > g_apache_roam_time*60)
	{
		if (heli.pev.origin.z < g_apache_height)
			target.pev.origin.z = g_apache_height;
		else
		{
			if (heli.pev.fixangle != 1337) // magic go-home number
			{
				heli.pev.fixangle = 1337;
				
				// search for neareset sky
				Vector oldOri = target.pev.origin;
				float bestDist = 9e99;
				Vector bestPos;
				for (int r = -180; r < 180; r += 10)
				{
					g_EngineFuncs.MakeVectors(Vector(0,r,0));
					
					TraceResult tr;
					string tex = g_Utility.TraceTexture( null, oldOri, oldOri + g_Engine.v_forward*65535 );
					if (tex.ToLowercase() != "sky")
						continue;
					g_Utility.TraceHull( oldOri, oldOri + g_Engine.v_forward*65535, ignore_monsters, large_hull, null, tr );
					float skyDist = (tr.vecEndPos - oldOri).Length();
					if (skyDist < bestDist)
					{
						bestDist = skyDist;
						bestPos = tr.vecEndPos;
					}
				}
				target.pev.origin = bestPos;
			}
			else
			{
				if (dist < 512.0f)
				{
					g_SoundSystem.StopSound(heli.edict(), CHAN_ITEM, fixPath("sc_rust/heli_far.ogg"));
					g_EntityFuncs.Remove(target);
					g_EntityFuncs.Remove(heli);
					g_Scheduler.SetTimeout("spawn_heli", Math.RandomFloat(g_apache_min_delay, g_apache_max_delay)*60);
					return;
				}
			}
		}
		readyToMove = false;
	}
	else if (enemy !is null and target.pev.colormap == 0) // just found a target
	{
		readyToMove = true;
		//println("Found a target!");
		
		dictionary keys;
		keys["targetname"] = "heli_path" + g_heli_idx++;
		keys["origin"] = target.pev.origin.ToString();
		CBaseEntity@ path = g_EntityFuncs.CreateEntity("path_corner", keys, true);
		
		g_EntityFuncs.Remove(target);
		heli.pev.target = path.pev.targetname;
		@target = @path;
	}
	
	if (enemy is null)
	{
		target.pev.colormap = 0;
	}
	
	if (readyToMove)
	{
		Vector oldOri = target.pev.origin;
		bool canMove = false;
		
		if (enemy !is null)
		{			
			for (uint i = 0; i < 64; i++)
			{
				float horiDist = 1024;
				float vertDist = 768;
				float r = Math.RandomFloat(0, 2*Math.PI);
				target.pev.origin = enemy.pev.origin + Vector(horiDist*cos(r), horiDist*sin(r), vertDist);
				
				TraceResult tr;
				g_Utility.TraceLine( oldOri, target.pev.origin, ignore_monsters, heli.edict(), tr );
				if (tr.flFraction >= 1.0f)
				{
					canMove = true;
					target.pev.colormap = 1;
					break;
				}
			}
			
			// prevent running into the ground or mountains
			TraceResult tr;
			g_Utility.TraceLine( oldOri, oldOri + Vector(0,0,-65536), ignore_monsters, heli.edict(), tr );
			target.pev.origin.z = Math.max(target.pev.origin.z, tr.vecEndPos.z);
			
			Vector belowPos = heli.pev.origin;
			belowPos.z = target.pev.origin.z;
			g_Utility.TraceLine(belowPos, target.pev.origin, ignore_monsters, heli.edict(), tr );
			if (tr.flFraction < 1.0f)
			{
				// don't move down, we'll run into something
				target.pev.origin.z = heli.pev.origin.z;
			}
			
		}
		else
		{		
			for (uint i = 0; i < 64; i++)
			{
				target.pev.origin = getRandomPosition();
				target.pev.origin.z = g_apache_height;
				
				TraceResult tr;
				g_Utility.TraceLine( oldOri, target.pev.origin, ignore_monsters, heli.edict(), tr );
				if (tr.flFraction >= 1.0f)
				{
					canMove = true;
					break;
				}
			}
			target.pev.colormap = 0;
		}
		
		if (!canMove)
		{
			target.pev.origin = oldOri;
			//println("Apache failed to move!");
		}		
	}
	
	// break things with helicopter blades
	g_EngineFuncs.MakeVectors(heli.pev.angles);
	float bladeLength = 300.0f;
	array<Vector> blades = {
		g_Engine.v_forward, 
		g_Engine.v_forward*-1,
		g_Engine.v_right, 
		g_Engine.v_right*-1,
		g_Engine.v_forward*0.707f + g_Engine.v_right*0.707f,
		g_Engine.v_forward*-0.707f + g_Engine.v_right*-0.707f,
		g_Engine.v_forward*-0.707f + g_Engine.v_right*0.707f,
		g_Engine.v_forward*0.707f + g_Engine.v_right*-0.707f
	};
	
	for (uint i = 0; i < blades.length()-1; i+=2)
	{
		Vector bladeStart = heli.pev.origin + blades[i]*bladeLength;
		Vector bladeEnd = heli.pev.origin + blades[i+1]*bladeLength;
		//te_beampoints(bladeStart, bladeEnd);
		
		TraceResult tr;
		g_Utility.TraceHull( bladeStart, bladeEnd, ignore_monsters, head_hull, heli.edict(), tr );
		if (tr.fStartSolid != 0) {
			g_Utility.TraceHull( bladeEnd, bladeStart, ignore_monsters, head_hull, heli.edict(), tr );
		}
		CBaseEntity@ phit = g_EntityFuncs.Instance( tr.pHit );
		if (phit !is null)
		{
			//println("Blocked by " + phit.pev.classname);
			if (phit.pev.classname != "worldspawn")
			{
				float dmg = Math.min(phit.pev.health, 2000.0f);
				phit.TakeDamage(heli.pev, heli.pev, dmg, DMG_SLASH);
				heli.TakeDamage(phit.pev, phit.pev, (dmg/2000.0f)*100.0f, DMG_CLUB);
			}
			else
				heli.TakeDamage(phit.pev, phit.pev, 1.0f, DMG_CLUB); // prevent getting stuck forever
		}
	}
	
	//te_beampoints(heli.pev.origin, target.pev.origin);
	
	g_Scheduler.SetTimeout("heli_think", 0.1f, h_heli);
}

void heli_die(CBaseEntity@ heli)
{
	CBaseEntity@ target = g_EntityFuncs.FindEntityByTargetname(null, heli.pev.target);
	g_EntityFuncs.Remove(target);
	g_SoundSystem.StopSound(heli.edict(), CHAN_ITEM, fixPath("sc_rust/heli_far.ogg"));
	
	Vector itemPos = heli.pev.origin;
	CBaseEntity@ item = null;
	switch(Math.RandomLong(0,5))
	{
		case 0: @item = spawnItem(itemPos, I_METAL, 1000, true); break;
		case 1: @item = spawnItem(itemPos, I_HQMETAL, 100, true); break;
		case 2: @item = spawnItem(itemPos, I_SAW, 1, true); break;
		case 3: @item = spawnItem(itemPos, I_556, 100, true); break;
		case 4: @item = spawnItem(itemPos, I_ROCKET, 5, true); break;
	}
	if (item !is null)
		item.pev.movetype = MOVETYPE_TOSS;
}

void spawn_heli()
{	
	Vector spawnPos = Vector(0,0,g_airdrop_height);
	g_EngineFuncs.MakeVectors(Vector(0,Math.RandomFloat(-180,180),0));
	TraceResult tr;
	g_Utility.TraceHull( spawnPos, spawnPos + g_Engine.v_forward*65536, ignore_monsters, large_hull, null, tr );
	spawnPos = tr.vecEndPos - g_Engine.v_forward*512;
	spawnPos.z = g_apache_height;
	
	dictionary keys;
	keys["targetname"] = "heli_path" + g_heli_idx++;
	keys["origin"] = spawnPos.ToString();
	CBaseEntity@ path = g_EntityFuncs.CreateEntity("path_corner", keys, true);
	
	keys["targetname"] = "heli";
	keys["model"] = fixPath("models/sc_rust/apache.mdl");
	keys["origin"] = spawnPos.ToString();
	keys["health"] = "1000";
	keys["target"] = string(path.pev.targetname);
	keys["TriggerTarget"] = "monster_killed";
	keys["TriggerCondition"] = "4"; // Death
	CBaseEntity@ ent = g_EntityFuncs.CreateEntity("monster_apache", keys, true);
	ent.pev.teleport_time = g_Engine.time;
	
	g_SoundSystem.PlaySound(ent.edict(), CHAN_ITEM, fixPath("sc_rust/heli_far.ogg"), 1.0f, 0.04f, SND_FORCE_LOOP, 100);
	
	ent.SetClassification(CLASS_XRACE_PITDRONE);
	
	g_Scheduler.SetTimeout("heli_think", 1.0f, EHandle(ent));
}
