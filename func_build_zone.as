class BuildZone
{
	int numRaiderParts = 0; // number of total build parts in this zone
	int numSettlers = 0; // number of players building bases here
	int maxSettlers = 0;
	int id = -1;
	string name = "???";
	
	void addRaiderParts(int amt)
	{
		g_global_solids += amt;
		numRaiderParts += amt;
	}
	
	BuildZone() {}
	
	BuildZone(int id, string name)
	{
		this.id = id;
		this.name = name;
	}
}

int g_node_id = 0;

enum node_types
{
	NODE_TREE,
	NODE_ROCK,
	NODE_BARREL,
	NODE_XEN,
}

class func_build_zone : ScriptBaseEntity
{
	BMaterial material;
	int id;
	float spawnDelay = 0.0f; // fill up quickly when map loads, then slowly replace stuff
	float nextSpawn = 0;
	float nextBush = 0;
	bool nodes_disabled = false;
	bool think_disabled = false;
	
	bool spawning_wave = false;
	string wave_spawner = "monster_gonome";
	float wave_extra_health = 0;
	
	BuildZone@ buildZone;
	
	float treeRatio = 0.68f;
	float rockRatio = 0.12f;
	float barrelRatio = 0.1f;
	float monsterRatio = 0.1f;
	
	int maxTrees = 0;
	int maxRocks = 0;
	int maxBarrels = 0;
	int maxMonsters = 0;
	
	int maxNodes = g_maxZoneNodes.GetInt();
	int maxBushes = g_maxZoneBushes.GetInt();
	
	array<EHandle> nodes; // trees & rocks
	array<EHandle> animals;
	array<EHandle> subZones;
	array<Vector> ainodes; // list of node locations
	array<EHandle> bushes;
	
	// too OP:
	// "agrunt_spawner"
	array<string> monster_spawners = {"houndeye_spawner", "gonome_spawner", "bullsquid_spawner", "headcrab_spawner",
									  "slave_spawner", "babygarg_spawner", "babyvolt_spawner",
									  "pitdrone_spawner"};
	
	bool KeyValue( const string& in szKey, const string& in szValue )
	{		
		if (szKey == "id") id = atoi(szValue);
		else if (szKey == "tree_ratio") treeRatio = atof(szValue);
		else if (szKey == "rock_ratio") rockRatio = atof(szValue);
		else if (szKey == "barrel_ratio") barrelRatio = atof(szValue);
		else if (szKey == "monster_ratio") monsterRatio = atof(szValue);
		else if (szKey == "disable_nodes") nodes_disabled = atoi(szValue) != 0;
		else return BaseClass.KeyValue( szKey, szValue );
		
		return true;
	}
	
	void Spawn()
	{
		self.pev.solid = SOLID_TRIGGER;
		self.pev.movetype = MOVETYPE_NONE;
		self.pev.team = id;
		
		self.pev.effects = EF_NODRAW;
		self.pev.rendermode = 2;
		self.pev.renderamt = 200;
		
		g_EntityFuncs.SetModel(self, self.pev.model);
		g_EntityFuncs.SetOrigin(self, self.pev.origin);
		
		maxNodes = g_maxZoneNodes.GetInt();
	}
	
	void Enable()
	{
		UpdateNodeRatios();
		SetThink( ThinkFunction( ZoneThink ) );
		pev.nextthink = g_Engine.time + 3.0f; // wait for node graph to generate before spawning stuff
		think_disabled = false;
	}
	
	void Disable()
	{
		think_disabled = true;
	}
	
	void DeleteNullNodes()
	{
		for (uint i = 0; i < animals.size(); i++)
		{
			if (@animals[i].GetEntity() == null)
			{
				animals.removeAt(i);
				i--;
			}
		}
		for (uint i = 0; i < nodes.size(); i++)
		{
			if (@nodes[i].GetEntity() == null)
			{
				nodes.removeAt(i);
				i--;
			}
		}
		for (uint i = 0; i < bushes.size(); i++)
		{
			if (@bushes[i].GetEntity() == null)
			{
				bushes.removeAt(i);
				i--;
			}
		}
	}
	
	void UpdateNodeRatios()
	{
		float oldTreeRatio = treeRatio;
		float oldRockRatio = rockRatio;
		float oldBarrelRatio = barrelRatio;
		float oldMonsterRatio = monsterRatio;
		
		if (g_invasion_mode) { 
			// force a balanced amount of resources when confined to a single zone
			treeRatio = 0.5f;
			rockRatio = 0.15f;
			barrelRatio = 0.15f;
			monsterRatio = 0.2f;
		}
	
		float total = treeRatio + rockRatio + barrelRatio + monsterRatio;
		if (abs(total - 1) > 0.01f)
			println("Ratios for zone " + id +  " (" + total + ") do not add up to 1.0! Nodes will not spawn as expected.");
			
		maxTrees = int(Math.Floor(maxNodes*treeRatio + 0.5f));
		maxRocks = int(Math.Floor(maxNodes*rockRatio + 0.5f));
		maxBarrels = int(Math.Floor(maxNodes*barrelRatio + 0.5f));
		maxMonsters = int(Math.Floor(maxNodes*monsterRatio + 0.5f));
		if (!g_invasion_mode and maxMonsters > g_maxZoneMonsters.GetInt())
			maxMonsters = g_maxZoneMonsters.GetInt();
		if (g_invasion_mode)
			maxMonsters = g_invasion_monster_count;
		
		int maxTotal = maxTrees + maxRocks + maxBarrels + maxMonsters;
		int diff = int(maxNodes) - maxTotal;
		if (diff != 0)
		{
			// adjust largest value, so this change is less noticeable
			if (maxTrees > maxRocks and maxTrees > maxBarrels and maxTrees > maxMonsters)
				maxTrees += diff;
			if (maxRocks > maxTrees and maxRocks > maxBarrels and maxRocks > maxMonsters)
				maxRocks += diff;
			if (maxBarrels > maxRocks and maxBarrels > maxTrees and maxBarrels > maxMonsters)
				maxBarrels += diff;
			if (maxMonsters > maxRocks and maxMonsters > maxBarrels and maxMonsters > maxTrees)
				maxMonsters += diff;
		}
		
		if (debug_mode)
			println("Zone " + id + " maxs: " + maxTrees + " trees + " + maxRocks + " rocks + " + maxBarrels + " barrels + " + 
				maxMonsters + " monsters");
				
		if (g_invasion_mode) {
			treeRatio = oldTreeRatio;
			rockRatio = oldRockRatio;
			barrelRatio = oldBarrelRatio;
			monsterRatio = oldMonsterRatio;
		}
	}
	
	bool monstersAreAlive()
	{
		DeleteNullNodes();
		for (uint i = 0; i < animals.length(); i++)
		{
			if (animals[i] and animals[i].GetEntity().IsAlive())
				return true;
		}
		return false;
	}
	
	int ClearMonsters()
	{
		DeleteNullNodes();
		int numRemoved = 0;
		for (uint i = 0; i < animals.length(); i++)
		{
			g_EntityFuncs.Remove(animals[i]);
			numRemoved++;
		}
		DeleteNullNodes();
		return numRemoved;
	}
	
	void Clear()
	{
		for (uint i = 0; i < nodes.length(); i++)
		{
			CBaseEntity@ node = nodes[i];
			if (node.pev.classname == "func_breakable_custom")
			{
				func_breakable_custom@ ent = cast<func_breakable_custom@>(CastToScriptClass(node));
				if (ent.killtarget.Length() > 0)
				{
					CBaseEntity@ kill = g_EntityFuncs.FindEntityByTargetname(null, ent.killtarget);
					if (kill !is null)
						g_EntityFuncs.Remove(kill);
				}
			}
			g_EntityFuncs.Remove(node);
		}
		for (uint i = 0; i < bushes.length(); i++)
			g_EntityFuncs.Remove(bushes[i]);
		nodes.resize(0);
		animals.resize(0);
		bushes.resize(0);
		
		spawnDelay = 0;
		nextSpawn = g_Engine.time;
	}
	
	void Use(CBaseEntity@ pActivator, CBaseEntity@ pCaller, USE_TYPE useType, float flValue = 0.0f)
	{
		//println("USED BY " + pCaller.pev.classname);
	}
	
	bool canSpawn(Vector pos, float radius, Vector&out ground, bool isTree)
	{
		TraceResult tr;
		Vector vecEnd = pos + Vector(0,0,-65536);
		g_Utility.TraceHull( pos, vecEnd, dont_ignore_monsters, human_hull, null, tr );
		CBaseEntity@ phit = g_EntityFuncs.Instance( tr.pHit );
		ground = tr.vecEndPos + Vector(0,0,-36);
		ground.z -= Math.min(0.05f, 1.0f-tr.vecPlaneNormal.z)*(isTree ? 512 : 256); // sink into the ground if on a slope
		
		if (phit.pev.classname != "worldspawn")
			return false;

		if (tr.vecPlaneNormal.z < 0.7f)
			return false;
			
		// check radius around node for collisions
		for (float r = 0.5f; r < 1.01f; r += 0.5f)
		{
			for (float i = 0; i < 2*3.1415f; i += 0.4f)
			{
				Vector offset(cos(i)*radius*r, sin(i)*radius*r, 0);
				g_Utility.TraceHull( pos + offset, vecEnd + offset, dont_ignore_monsters, human_hull, null, tr );
				@phit = g_EntityFuncs.Instance( tr.pHit );
				if (phit.pev.classname != "worldspawn" and (phit.pev.message != "node" or !isTree))
					return false;
			}
		}

		return true;
	}
	
	bool IntersectsZone(CBaseEntity@ ent)
	{
		if (self.Intersects(ent))
			return true;
			
		for (uint i = 0; i < subZones.length(); i++)
			if (subZones[i].IsValid() and subZones[i].GetEntity().Intersects(ent))
				return true;
				
		return false;
	}
	
	Vector getRandomPosition()
	{
		CBaseEntity@ brush = getRandomBrush();
		Vector ori = getCentroid(brush);
		ori.z = brush.pev.absmax.z;
		Vector min = brush.pev.absmin;
		Vector max = brush.pev.absmax;
		Vector offset = Vector(((max.x - min.x) / 2) * Math.RandomFloat(-1, 1), 
							   ((max.y - min.y) / 2 )* Math.RandomFloat(-1, 1), 0);
		return ori + offset;
	}
	
	// brushes with a greater size are more likley to be chosen
	CBaseEntity@ getRandomBrush()
	{
		array<CBaseEntity@> brushes;
		array<float> areas;
		array<float> ratios;
		
		brushes.insertLast(self);
		for (uint i = 0; i < subZones.length(); i++)
		{
			if (subZones[i])
			{
				func_build_zone@ subZone = cast<func_build_zone@>(CastToScriptClass(subZones[i].GetEntity()));
				if (!subZone.nodes_disabled)
					brushes.insertLast(subZones[i].GetEntity());
			}
		}
		
		float total = 0;
		for (uint i = 0; i < brushes.length(); i++)
		{
			CBaseEntity@ e = brushes[i];
			float width = e.pev.absmax.x - e.pev.absmin.x;
			float length = e.pev.absmax.y - e.pev.absmin.y;
			float area = width*length;
			total += area;
			areas.insertLast(width*length);
		}
		
		
		float r = Math.RandomFloat(0, total);
		float a = 0;
		for (uint i = 0; i < areas.length(); i++)
		{
			a += areas[i];
			if (r <= a)
				return brushes[i];
		}
		return brushes[0];
	}
	
	float SpawnInvasionWave(string monsterClass)
	{
		wave_extra_health = 0;
		DeleteNullNodes();
		
		for (uint i = 0; i < animals.size(); i++)
		{
			CBaseEntity@ ent = animals[i];
			if (ent.IsAlive())
			{
				CBaseMonster@ mon = cast<CBaseMonster@>(ent);
				wave_extra_health += ent.pev.health;
				mon.GibMonster();
				mon.pev.button = -1234; // prevent race conditions later when counting monsters
			}
		}
		
		DeleteNullNodes();
		
		wave_extra_health = (wave_extra_health / maxMonsters);
		wave_extra_health = (int(wave_extra_health)/10)*10;
		
		spawning_wave = true;
		spawnDelay = 0;
		wave_spawner = monsterClass;
		
		return wave_extra_health;
	}
	
	void ZoneThink()
	{
		if (think_disabled)
		{
			return;
		}
		if (saveLoadInProgress) 
		{
			pev.nextthink = g_Engine.time + 0.05f;
			return;
		}
		
		if (buildZone !is null)
		{
			maxNodes = g_maxZoneNodes.GetInt();
			maxBushes = g_maxZoneBushes.GetInt();
			if (maxNodes + buildZone.numRaiderParts > g_maxZoneSolids.GetInt())
			{
				maxNodes = g_maxZoneSolids.GetInt() - buildZone.numRaiderParts;
			}
			if (maxBushes + maxNodes + buildZone.numRaiderParts > MAX_VISIBLE_ZONE_ENTS)
			{
				maxBushes = MAX_VISIBLE_ZONE_ENTS - (maxNodes + buildZone.numRaiderParts);
			}
			if (int(nodes.length()) > maxNodes)
			{
				DeleteNullNodes();
				for (uint i = 0; i < nodes.size(); i++)
				{
					CBaseEntity@ ent = nodes[i];
					if (ent.pev.classname == "func_breakable_custom")
					{
						ent.TakeDamage(ent.pev, ent.pev, ent.pev.health, DMG_DROWNRECOVER);
						nodes.removeAt(i);
						break;
					}
				}
			}
			if (int(bushes.length()) > maxBushes)
			{
				DeleteNullNodes();
				if (int(bushes.length()) > maxBushes and bushes.length() > 0)
				{
					g_EntityFuncs.Remove(bushes[0]);
					bushes.removeAt(0);
				}
			}
		}
		else
			@buildZone = @getBuildZone(id);
		
		
		for (uint i = 0; i < animals.size(); i++)
		{
			if (!animals[i].IsValid())
			{
				animals.removeAt(i);
				i--;
				continue;
			}
			CBaseEntity@ node = animals[i];
			if (node.IsAlive())
			{
				CBaseMonster@ mon = cast<CBaseMonster@>(node);
				
				bool isAgro = mon.GetClassification(0) != CLASS_NONE or mon.m_hEnemy.IsValid();
				
				if (!isAgro and mon.HasConditions(bits_COND_LIGHT_DAMAGE | bits_COND_HEAVY_DAMAGE) and @mon.m_hEnemy.GetEntity() == null)
				{
					CBaseEntity@ ent = null;
					do {
						@ent = g_EntityFuncs.FindEntityInSphere(ent, mon.m_vecEnemyLKP, 32.0f, "player", "classname");
						if (ent !is null)
						{
							mon.PushEnemy(ent, ent.pev.origin);
							mon.KeyValue("classify", CLASS_HUMAN_MILITARY); // Hate players, dislike player allies
							mon.m_FormattedName = "" + mon.pev.noise3 + " (angry)";
							mon.pev.teleport_time = g_Engine.time;
							isAgro = true;
							break;
						}
					} while (ent !is null);
				}
				
				if (mon.pev.armorvalue < g_Engine.time)
				{
					mon.pev.armorvalue = g_Engine.time + 1.0f;
					CBaseEntity@ ent = null;
					do {
						float radius = isAgro ? mon.m_flDistLook : g_xen_agro_dist;
						@ent = g_EntityFuncs.FindEntityInSphere(ent, mon.pev.origin, radius, "player", "classname");
						if (ent !is null)
						{								
							// check line-of-sight
							TraceResult tr;
							g_Utility.TraceLine( mon.EyePosition(), ent.pev.origin, dont_ignore_monsters, mon.edict(), tr );
							CBaseEntity@ pHit = g_EntityFuncs.Instance( tr.pHit );
							if (pHit !is null and pHit.entindex() == ent.entindex())
							{
								if (!isAgro)
								{
									mon.KeyValue("classify", CLASS_HUMAN_MILITARY); // Hate players, dislike player allies
									mon.m_FormattedName = "" + mon.pev.noise3 + " (angry)";
									mon.MonsterUse(ent, ent, USE_TOGGLE, 0);
									//mon.PushEnemy(ent, ent.pev.origin);
									//mon.m_flDistLook = 32;
								}
								mon.pev.teleport_time = g_Engine.time; // save last time player was seen
							}
						}
					} while (ent !is null);
					
					if (g_invasion_mode and @mon.m_hEnemy.GetEntity() == null)
					{
						CBasePlayer@ plr = getRandomLivingPlayer();
						if (plr !is null and (plr.pev.flags & FL_NOTARGET == 0))
							mon.PushEnemy(plr, plr.pev.origin);
						else
						{
							CBaseEntity@ part = getRandomBasePart();
							if (part !is null) {
								mon.PushEnemy(part, part.pev.origin);
							}
						}
					}
				}	
				if (isAgro and mon.pev.teleport_time + g_monster_forget_time < g_Engine.time and !g_invasion_mode)
				{
					mon.KeyValue("classify", CLASS_FORCE_NONE);
					mon.ClearEnemyList();
					mon.ClearSchedule();
					if (string(mon.pev.noise3).Length() > 0)
						mon.m_FormattedName = mon.pev.noise3;
				}
				/*
				if (mon.GetClassification(0) == CLASS_NONE and mon.pev.armortype < g_Engine.time)
				{
					mon.pev.armortype = g_Engine.time + 10.0f;
					println("SEQUENCE BEGINS NOW");
					
					Vector sequencePos;
					if (ainodes.length() > 0)
						sequencePos = ainodes[Math.RandomLong(0, ainodes.length()-1)];
					else
						println("Zone " + id + " has no ainodes");
					
					sequencePos.z -= 96;
					
					dictionary keys;
					keys["origin"] = sequencePos.ToString();
					keys["targetname"] = "" + mon.pev.targetname + "_sequence";
					keys["m_iszEntity"] = "" + mon.pev.targetname;
					keys["m_fMoveTo"] = "2";
					keys["moveto_radius"] = "128";
					keys["spawnflags"] = "320";
					
					CBaseEntity@ seq = g_EntityFuncs.CreateEntity("scripted_sequence", keys, true);
					g_EntityFuncs.FireTargets(seq.pev.targetname, null, null, USE_TOGGLE);
					te_beampoints(mon.pev.origin, seq.pev.origin);
				}
				*/
			}
		}
		
		if (g_Engine.time > nextSpawn or g_Engine.time > nextBush)
		{
			DeleteNullNodes();
			
			nextBush = g_Engine.time + 5;
			
			if (int(bushes.size()) < maxBushes)
			{
				Vector ori = getRandomPosition();
				Vector ground;
				float radius = 32;
				if (canSpawn(ori, radius, ground, false))
				{
					array<string> bush_models = {"models/rust/bush.mdl", "models/rust/arc_bush.mdl"};
					ori = ground;
					dictionary keys;
					keys["origin"] = ori.ToString();
					keys["angles"] = Vector(0, Math.RandomLong(-180, 180), 0).ToString();
					keys["model"] = bush_models[Math.RandomLong(0, bush_models.length()-1)];
					keys["colormap"] = "-1";
					keys["movetype"] = "5";
					keys["scale"] = "2";
					keys["sequencename"] = "idle";
					keys["targetname"] = "bush";
					CBaseEntity@ ent = g_EntityFuncs.CreateEntity("item_generic", keys, true);
					ent.pev.movetype = MOVETYPE_NONE; // epic lag without this
					ent.pev.solid = SOLID_NOT;
					
					bushes.insertLast(EHandle(ent));
				}
			}
		}
		
		if (g_Engine.time > nextSpawn or spawning_wave)
		{
			int numTrees = 0;
			int numRocks = 0;
			int numBarrels = 0;
			int numMonsters = 0;
		
			DeleteNullNodes();
			for (uint i = 0; i < nodes.size(); i++)
			{
				CBaseEntity@ node = nodes[i];
				if (node.IsMonster() and node.IsAlive() and node.pev.button != -1234)
				{
					numMonsters++;
				}
				else if (node.pev.classname == "func_breakable_custom")
				{
					func_breakable_custom@ bnode = cast<func_breakable_custom@>(CastToScriptClass(node));
					switch(bnode.nodeType)
					{
						case NODE_TREE: numTrees++; break;
						case NODE_ROCK: numRocks++; break;
						case NODE_BARREL: numBarrels++; break;
					}
				}
			}
		
			array<int> choices;
			if (numTrees < maxTrees) choices.insertLast(NODE_TREE);
			if (numRocks < maxRocks) choices.insertLast(NODE_ROCK);
			if (numBarrels < maxBarrels) choices.insertLast(NODE_BARREL);
			if (numMonsters < maxMonsters and !g_invasion_mode) choices.insertLast(NODE_XEN);
			
			if (spawning_wave) 
			{
				if (numMonsters < maxMonsters)
				{
					choices.resize(0);
					choices.insertLast(NODE_XEN);
				}
			}
			
			if (!g_disable_ents and int(nodes.size()) < maxNodes and choices.length() > 0)
			{
				string brushModel;
				string itemModel;
				float itemHeight = 0;
				float radius = 64;
				int health = 400;
				bool isTree = false;
				
				int nextNodeSpawn = choices[ Math.RandomLong(0,choices.length()-1) ];
				
				if (nextNodeSpawn == NODE_TREE)
				{
					brushModel = getModelFromName("e_tree");
					itemModel = "models/rust/pine_tree.mdl";
					radius = 224.0f;
					itemHeight = 512; // prevents trees from disappearing across hills
					isTree = true;
				}
				else if (nextNodeSpawn == NODE_BARREL)
				{
					brushModel = getModelFromName("e_barrel");
					itemModel = "models/rust/tr_barrel.mdl";
					radius = 18.0f;
					health = 80;
					itemHeight = 32;
				}
				else if (nextNodeSpawn == NODE_XEN)
				{
					brushModel = getModelFromName("e_barrel");
					itemModel = "models/rust/tr_barrel.mdl";
					radius = 18.0f;
				}
				else if (nextNodeSpawn == NODE_ROCK)
				{
					brushModel = getModelFromName("e_rock");
					itemModel = "models/rust/rock.mdl";
					radius = 60.0f;
					itemHeight = 64;
				}
				else
					println("Build Zone: bad node type: " + nextNodeSpawn);
				
				Vector ori = getRandomPosition();
				
				Vector ground;
				if (canSpawn(ori, radius, ground, isTree))
				{								
					ori = ground;
					string name = "node" + g_node_id++;
					
					if (nextNodeSpawn == NODE_XEN)
					{
						string spawnerName = monster_spawners[Math.RandomLong(0, monster_spawners.length()-1)];
						if (spawning_wave)
							spawnerName = wave_spawner;
						CBaseEntity@ spawner = g_EntityFuncs.FindEntityByTargetname(null, spawnerName);
						if (spawner !is null)
						{
							spawner.pev.origin = ori;
							spawner.pev.origin.z += 16; // big monsters get stuck on steep slopes without this
							if (spawnerName == "controller_spawner")
								spawner.pev.origin.z += 512;
							spawner.pev.angles = Vector(0, Math.RandomLong(-180, 180), 0);
							spawner.pev.netname = "xen_node_zone_" + id;
							g_EntityFuncs.FireTargets(spawner.pev.targetname, null, null, USE_TOGGLE);
							
							CBaseEntity@ ent = null;
							do {
								@ent = g_EntityFuncs.FindEntityByTargetname(ent, spawner.pev.netname);
								if (ent !is null)
								{
									ent.pev.targetname = "node_xen";
									ent.pev.armortype = g_Engine.time + 10.0f;
									CBaseMonster@ mon = cast<CBaseMonster@>(ent);
									ent.pev.noise3 = mon.m_FormattedName;
									nodes.insertLast(EHandle(ent));
									animals.insertLast(EHandle(ent));
									if (spawning_wave)
									{
										if (ent.pev.classname == "monster_alien_voltigore")
											ent.pev.health = 250;
										if (ent.pev.classname == "monster_shocktrooper")
											ent.pev.health = 150;
										if (ent.pev.classname == "monster_gargantua")
											ent.pev.health = 200;
										if (ent.pev.classname == "monster_kingpin")
											ent.pev.health = 2;
										ent.pev.health += wave_extra_health;
										ent.KeyValue("classify", CLASS_ALIEN_MILITARY);
									}
								}
							} while (ent !is null);
						}
					}
					else
					{
						dictionary keys;
						keys["origin"] = ori.ToString();
						keys["angles"] = Vector(0, Math.RandomLong(-180, 180), 0).ToString();
						keys["model"] = brushModel;
						keys["material"] = "1";
						keys["killtarget"] = name;
						keys["health"] = "" + health;
						keys["colormap"] = "-1";
						keys["message"] = "node";
						keys["nodetype"] = "" + nextNodeSpawn;
						
						CBaseEntity@ ent = g_EntityFuncs.CreateEntity("func_breakable_custom", keys, true);
						nodes.insertLast(EHandle(ent));
						
						ori.z += itemHeight;
						keys["origin"] = ori.ToString();
						keys["model"] = itemModel;
						keys["movetype"] = "5";
						keys["scale"] = "1";
						keys["sequencename"] = "idle";
						keys["targetname"] = name;
						CBaseEntity@ ent2 = g_EntityFuncs.CreateEntity("item_generic", keys, true);
						ent2.pev.movetype = MOVETYPE_NONE; // epic lag without this
						ent2.pev.solid = SOLID_NOT;
					}
					
					if (int(nodes.size()) >= maxNodes)
					{
						if (debug_mode)
							println("Zone " + id + " populated");
						spawnDelay = g_invasion_mode ? g_node_spawn_time_invasion : g_node_spawn_time;
					}
					if (spawning_wave and numMonsters >= maxMonsters-1)
					{
						spawning_wave = false;
						spawnDelay = g_node_spawn_time_invasion;
						if (debug_mode)
							println("Wave spawn complete");
					}
					if (spawning_wave) {
						spawnDelay = 0;
					}
					nextSpawn = g_Engine.time + spawnDelay;
				}
				else
				{
					//println("HIT SOMETHING ELSE");
				}
			}
		}

		pev.nextthink = g_Engine.time + 0.05f;
	}
};