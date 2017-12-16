int MAX_VISIBLE_ENTS = 500;
uint NODES_PER_ZONE = 32;
float g_node_spawn_time = 20.0f;
float xen_agro_dist = 400.0f;

class BuildZone
{
	int numRaiderParts = 0; // number of total build parts in this zone
	int numSettlers = 0; // number of players building bases here
	int maxSettlers = 0;
	int id = -1;
	string name = "???";
	
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
	float spawnDelay = 0.05f; // fill up quickly when map loads, then slowly replace stuff
	float nextSpawn = 0;
	
	float treeRatio = 0.68f;
	float rockRatio = 0.12f;
	float barrelRatio = 0.1f;
	float monsterRatio = 0.1f;
	
	int maxTrees = 0;
	int maxRocks = 0;
	int maxBarrels = 0;
	int maxMonsters = 0;
	
	array<EHandle> nodes; // trees & rocks
	array<EHandle> animals;
	array<EHandle> subZones;
	
	array<string> monster_spawners = {"houndeye_spawner", "gonome_spawner", "bullsquid_spawner", "headcrab_spawner",
									  "slave_spawner", "agrunt_spawner", "babygarg_spawner", "babyvolt_spawner",
									  "pitdrone_spawner"};
	
	bool KeyValue( const string& in szKey, const string& in szValue )
	{		
		if (szKey == "id") id = atoi(szValue);
		else if (szKey == "tree_ratio") treeRatio = atof(szValue);
		else if (szKey == "rock_ratio") rockRatio = atof(szValue);
		else if (szKey == "barrel_ratio") barrelRatio = atof(szValue);
		else if (szKey == "monster_ratio") monsterRatio = atof(szValue);
		else return BaseClass.KeyValue( szKey, szValue );
		
		return true;
	}
	
	void Spawn()
	{
		self.pev.solid = SOLID_TRIGGER;
		self.pev.movetype = MOVETYPE_NONE;
		self.pev.team = id;
		
		//self.pev.effects = EF_NODRAW;
		self.pev.rendermode = 2;
		self.pev.renderamt = 200;
		
		g_EntityFuncs.SetModel(self, self.pev.model);
		g_EntityFuncs.SetOrigin(self, self.pev.origin);
		
		UpdateNodeRatios();
	}
	
	void Enable()
	{
		SetThink( ThinkFunction( ZoneThink ) );
		pev.nextthink = g_Engine.time;
	}
	
	void UpdateNodeRatios()
	{
		float total = treeRatio + rockRatio + barrelRatio + monsterRatio;
		if (abs(total - 1) > 0.01f)
			println("Ratios for zone " + id +  " (" + total + ") do not add up to 1.0! Nodes will not spawn as expected.");
			
		maxTrees = int(Math.Floor(NODES_PER_ZONE*treeRatio + 0.5f));
		maxRocks = int(Math.Floor(NODES_PER_ZONE*rockRatio + 0.5f));
		maxBarrels = int(Math.Floor(NODES_PER_ZONE*barrelRatio + 0.5f));
		maxMonsters = int(Math.Floor(NODES_PER_ZONE*monsterRatio + 0.5f));
		if (maxMonsters > g_max_zone_monsters)
			maxMonsters = g_max_zone_monsters;
		
		int maxTotal = maxTrees + maxRocks + maxBarrels + maxMonsters;
		int diff = int(NODES_PER_ZONE) - maxTotal;
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
		
		println("Zone " + id + " maxs: " + maxTrees + " trees + " + maxRocks + " rocks + " + maxBarrels + " barrels + " + 
				maxMonsters + " monsters");
	}
	
	void Use(CBaseEntity@ pActivator, CBaseEntity@ pCaller, USE_TYPE useType, float flValue = 0.0f)
	{
		//println("USED BY " + pCaller.pev.classname);
	}
	
	bool canSpawn(Vector pos, float radius, Vector&out ground, bool isTree)
	{
		TraceResult tr;
		Vector vecEnd = pos + Vector(0,0,-4096);
		g_Utility.TraceHull( pos, vecEnd, dont_ignore_monsters, human_hull, null, tr );
		CBaseEntity@ phit = g_EntityFuncs.Instance( tr.pHit );
		ground = tr.vecEndPos + Vector(0,0,-36);
		
		if (phit.pev.classname != "worldspawn")
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
			if (subZones[i])
				brushes.insertLast(subZones[i].GetEntity());
		
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
	
	void ZoneThink()
	{
		int numTrees = 0;
		int numRocks = 0;
		int numBarrels = 0;
		int numMonsters = 0;
		
		for (uint i = 0; i < nodes.size(); i++)
		{
			if (!nodes[i].IsValid())
			{
				nodes.removeAt(i);
				i--;
				continue;
			}
			CBaseEntity@ node = nodes[i];
			if (node.IsMonster())
			{
				numMonsters++;
				if (node.GetClassification(0) != CLASS_ALIEN_MONSTER)
				{
					CBaseMonster@ mon = cast<CBaseMonster@>(node);
					if (mon.pev.armorvalue < g_Engine.time)
					{
						mon.pev.armorvalue = g_Engine.time + 1.0f;
						CBaseEntity@ ent = null;
						do {
							@ent = g_EntityFuncs.FindEntityInSphere(ent, mon.pev.origin, xen_agro_dist, "player", "classname");
							if (ent !is null)
							{								
								// check line-of-sight
								TraceResult tr;
								g_Utility.TraceLine( mon.EyePosition(), ent.pev.origin, dont_ignore_monsters, mon.edict(), tr );
								CBaseEntity@ pHit = g_EntityFuncs.Instance( tr.pHit );
								if (pHit !is null and pHit.entindex() == ent.entindex())
								{
									mon.SetClassification(CLASS_ALIEN_MONSTER);
									mon.m_FormattedName = "" + mon.m_FormattedName + " (angry)";
									//mon.MonsterUse(ent, ent, USE_TOGGLE, 0);
									mon.PushEnemy(ent, ent.pev.origin);
									//mon.m_flDistLook = 32;
								}
							}
						} while (ent !is null);
					}		
				}
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
		if (g_Engine.time > nextSpawn)
		{
			array<int> choices;
			if (numTrees < maxTrees) choices.insertLast(NODE_TREE);
			if (numRocks < maxRocks) choices.insertLast(NODE_ROCK);
			if (numBarrels < maxBarrels) choices.insertLast(NODE_BARREL);
			if (numMonsters < maxMonsters) choices.insertLast(NODE_XEN);
				
				
			if (!g_disable_ents and nodes.size() < NODES_PER_ZONE and choices.length() > 0)
			{
				string brushModel;
				string itemModel;
				float radius = 64;
				int health = 400;
				bool isTree = false;
				
				int nextNodeSpawn = choices[ Math.RandomLong(0,choices.length()-1) ];
				
				if (nextNodeSpawn == NODE_TREE)
				{
					brushModel = getModelFromName("e_tree");
					itemModel = "models/sc_rust/pine_tree.mdl";
					radius = 224.0f;
					isTree = true;
				}
				else if (nextNodeSpawn == NODE_BARREL)
				{
					brushModel = getModelFromName("e_barrel");
					itemModel = "models/sc_rust/tr_barrel_blu1.mdl";
					radius = 18.0f;
					health = 80;
				}
				else if (nextNodeSpawn == NODE_XEN)
				{
					brushModel = getModelFromName("e_barrel");
					itemModel = "models/sc_rust/tr_barrel_blu1.mdl";
					radius = 18.0f;
				}
				else if (nextNodeSpawn == NODE_ROCK)
				{
					brushModel = getModelFromName("e_rock");
					itemModel = "models/sc_rust/rock.mdl";
					radius = 60.0f;
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
						CBaseEntity@ spawner = g_EntityFuncs.FindEntityByTargetname(null, spawnerName);
						if (spawner !is null)
						{
							spawner.pev.origin = ori;
							spawner.pev.angles = Vector(0, Math.RandomLong(-180, 180), 0);
							spawner.pev.netname = "xen_node_zone_" + id;
							g_EntityFuncs.FireTargets(spawner.pev.targetname, null, null, USE_TOGGLE);
							
							CBaseEntity@ ent = null;
							do {
								@ent = g_EntityFuncs.FindEntityByTargetname(ent, spawner.pev.netname);
								if (ent !is null)
								{
									ent.pev.targetname = "node_xen";
									nodes.insertLast(EHandle(ent));
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
						
						keys["model"] = itemModel;
						keys["movetype"] = "5";
						keys["scale"] = "1";
						keys["sequencename"] = "idle";
						keys["targetname"] = name;
						CBaseEntity@ ent2 = g_EntityFuncs.CreateEntity("item_generic", keys, true);
					}
					
					nextSpawn = g_Engine.time + spawnDelay;
				}
				else
				{
					//println("HIT SOMETHING ELSE");
				}
			}
		}
		else
		{
			if (spawnDelay != g_node_spawn_time and nodes.size() == NODES_PER_ZONE)
			{
				println("Zone " + id + " populated");
				spawnDelay = g_node_spawn_time;
			}
		}

		pev.nextthink = g_Engine.time + 0.05;
	}
};