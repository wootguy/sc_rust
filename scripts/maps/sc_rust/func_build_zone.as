int MAX_VISIBLE_ENTS = 500;

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
}

class func_build_zone : ScriptBaseEntity
{
	BMaterial material;
	int id;
	int nextNodeSpawn = NODE_TREE;
	
	array<EHandle> nodes; // trees & rocks
	array<EHandle> animals;
	
	bool KeyValue( const string& in szKey, const string& in szValue )
	{		
		if (szKey == "id") id = atoi(szValue);
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
		
		
		SetThink( ThinkFunction( ZoneThink ) );
		pev.nextthink = g_Engine.time;
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
	
	void ZoneThink()
	{
		if (!g_disable_ents and nodes.size() < 32)
		{
			string brushModel;
			string itemModel;
			float radius = 64;
			bool isTree = false;
			
			if (nextNodeSpawn == NODE_TREE)
			{
				brushModel = getModelFromName("e_tree");
				itemModel = "models/sc_rust/pine_tree.mdl";
				radius = 224.0f;
				isTree = true;
			}
			else
			{
				brushModel = getModelFromName("e_rock");
				itemModel = "models/sc_rust/rock.mdl";
				radius = 60.0f;
			}
			
			Vector ori = getCentroid(self);
			Vector min = pev.absmin;
			Vector max = pev.absmax;
			Vector offset = Vector(((max.x - min.x) / 2) * Math.RandomFloat(-1, 1), 
								   ((max.y - min.y) / 2 )* Math.RandomFloat(-1, 1), 0);
			ori = ori + offset;
			
			Vector ground;
			if (canSpawn(ori, radius, ground, isTree))
			{								
				ori = ground;
				string name = "node" + g_node_id++;
				
				dictionary keys;
				keys["origin"] = ori.ToString();
				keys["angles"] = Vector(0, Math.RandomLong(-180, 180), 0).ToString();
				keys["model"] = brushModel;
				keys["material"] = "1";
				keys["killtarget"] = name;
				keys["health"] = "400";
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
				
				int rand = Math.RandomLong(0,100);
				if (rand >= 20)
					nextNodeSpawn = NODE_TREE;
				else
					nextNodeSpawn = NODE_ROCK;
			}
			else
			{
				//println("HIT SOMETHING ELSE");
			}
		}
		
		pev.nextthink = g_Engine.time + 0.1f;
	}
};