
class BMaterial
{
	array<string> hitSounds;
	array<string> breakSounds;
	
	BMaterial() {}
	
	BMaterial(array<string> hitSounds, array<string> breakSounds)
	{
		this.hitSounds = hitSounds;
		this.breakSounds = breakSounds;
	}
}

array< array<string> > g_material_damage_sounds = {
	{"sc_rust/damage_wood.ogg", "sc_rust/damage_wood2.ogg"},
	{"sc_rust/damage_stone.ogg", "sc_rust/damage_stone2.ogg", "sc_rust/damage_stone3.ogg"},
	{"sc_rust/damage_metal.ogg", "sc_rust/damage_metal2.ogg", "sc_rust/damage_metal3.ogg"}
};

array< array<string> > g_material_break_sounds = {
	{"sc_rust/break_wood.ogg", "sc_rust/break_wood2.ogg", "sc_rust/break_wood3.ogg", "sc_rust/break_wood4.ogg"},
	{"sc_rust/break_stone.ogg", "sc_rust/break_stone2.ogg", "sc_rust/break_stone3.ogg", "sc_rust/break_stone4.ogg"},
	{"sc_rust/break_metal.ogg", "sc_rust/break_metal2.ogg", "sc_rust/break_metal3.ogg", "sc_rust/break_metal4.ogg"},
};

array<BMaterial> g_materials = {
	BMaterial(g_material_damage_sounds[0], g_material_break_sounds[0]),
	BMaterial(g_material_damage_sounds[1], g_material_break_sounds[1]),
	BMaterial(g_material_damage_sounds[2], g_material_break_sounds[2])
};


class func_breakable_custom : ScriptBaseEntity
{
	BMaterial material;
	int id = -1;
	int zoneid = -1; // which zone this part belongs in
	int parent = -1; // part id
	bool dead = false; // in the process of dieing?
	bool isDoor = false;
	bool isLadder = false;
	bool supported = false; // is connected to a foundation somehow?
	
	array<EHandle> children;
	array<EHandle> connections; // all parts that are supported by or support this part
	
	string serialize()
	{
		return pev.origin.ToString() + '"' + pev.angles.ToString() + '"' + pev.colormap + '"' +
			   id + '"' + parent  + '"' + pev.button + '"' + pev.body + '"' + pev.vuser1.ToString() + '"' + 
			   pev.vuser2.ToString() + '"' + pev.health + '"' + pev.classname + '"' + pev.model + '"' +
			   pev.groupinfo + '"' + pev.noise1 + '"' + pev.noise2 + '"' + pev.noise3 + '"' + pev.effects;
	}

	bool KeyValue( const string& in szKey, const string& in szValue )
	{		
		if (szKey == "id") id = atoi(szValue);
		else if (szKey == "parent") parent = atoi(szValue);
		else if (szKey == "zoneid") zoneid = atoi(szValue);
		else return BaseClass.KeyValue( szKey, szValue );
		
		return true;
	}
	
	void Spawn()
	{				
		self.pev.solid = SOLID_BSP;
		self.pev.movetype = MOVETYPE_PUSH;
		self.pev.takedamage = DAMAGE_YES;
		self.pev.team = id;
		self.pev.effects = EF_NODECALS;
		//self.pev.effects = EF_FRAMEANIMTEXTURES;
		//self.pev.frame = 1;
		isDoor = self.pev.targetname != "";
		isLadder = self.pev.colormap == B_LADDER;
		//println("CREATE PART " + id + " WITH PARENT " + parent);
		
		g_EntityFuncs.SetModel(self, self.pev.model);
		//g_EntityFuncs.SetSize(self.pev, self.pev.mins, self.pev.maxs);
		g_EntityFuncs.SetOrigin(self, self.pev.origin);
		
		material = g_materials[0];
		
		SetThink( ThinkFunction( DoorThink ) );
		pev.nextthink = g_Engine.time;
		
		updateConnections();
	}
	
	void DoorThink()
	{
		//self.pev.angles = self.pev.angles + self.pev.avelocity;
		pev.nextthink = g_Engine.time;
	}
	
	void Touch( CBaseEntity@ pOther )
	{
		//println("TOUCHED BY " + pOther.pev.classname);
	}
	
	void Use(CBaseEntity@ pActivator, CBaseEntity@ pCaller, USE_TYPE useType, float flValue = 0.0f)
	{
		//println("USED BY " + pCaller.pev.classname);
	}
	
	int entindex()
	{
		return self.entindex();
	}
	
	void addConnection(CBaseEntity@ part)
	{
		for (uint i = 0; i < connections.length(); i++)
		{
			if (!connections[i])
				continue;
			if (connections[i].GetEntity().entindex() == part.entindex())
				return; // already in the list
		}
		connections.insertLast(EHandle(part));
	}
	
	void removeConnection(CBaseEntity@ part)
	{
		for (uint i = 0; i < connections.length(); i++)
		{
			if (!connections[i])
				continue;
			if (connections[i].GetEntity().entindex() == part.entindex())
			{
				connections.removeAt(i);
				return; // already in the list
			}
		}
	}
	
	void removeAllConnections()
	{
		for (uint i = 0; i < connections.length(); i++)
		{
			if (connections[i])
			{
				func_breakable_custom@ bpart = cast<func_breakable_custom@>(CastToScriptClass(connections[i].GetEntity()));
				bpart.removeConnection(self);
			}
		} 
	}
	
	void updateConnections()
	{
		connections.resize(0);
		
		g_EngineFuncs.MakeVectors(self.pev.angles);
		Vector v_forward = g_Engine.v_forward;
		Vector v_right = g_Engine.v_right;
		array<Vector> checks;
		int type = self.pev.colormap;
		
		if (isFloorPiece(self))
		{
			if (isTriangular(self))
			{
				// walls above/below at right/back/left
				checks.insertLast(v_right*-32 + v_forward*18.476);
				checks.insertLast(v_right*32 + v_forward*18.476);
				checks.insertLast(v_forward*-36.95);
				checks.insertLast(Vector(0,0,-128) + v_right*-32 + v_forward*18.476);
				checks.insertLast(Vector(0,0,-128) + v_right*32 + v_forward*18.476);
				checks.insertLast(Vector(0,0,-128) + v_forward*-36.95);
				// tri floors right/back/left
				checks.insertLast(v_forward*-73.9);
				checks.insertLast(v_right*64 + v_forward*36.95);
				checks.insertLast(v_right*-64 + v_forward*36.95);
				// square floors right/back/ left
				checks.insertLast(v_forward*-(36.95+64));
				checks.insertLast(v_right*87 + v_forward*51);
				checks.insertLast(v_right*-87 + v_forward*51);
			}
			else
			{
				// walls above/below at front/right/back/left
				checks.insertLast(v_forward*64);
				checks.insertLast(v_forward*-64);
				checks.insertLast(v_right*64);
				checks.insertLast(v_right*-64);
				checks.insertLast(v_forward*64 + Vector(0,0,-128));
				checks.insertLast(v_forward*-64 + Vector(0,0,-128));
				checks.insertLast(v_right*64 + Vector(0,0,-128));
				checks.insertLast(v_right*-64 + Vector(0,0,-128));
				// square floors front/right/back/left
				checks.insertLast(v_forward*128);
				checks.insertLast(v_forward*-128);
				checks.insertLast(v_right*128);
				checks.insertLast(v_right*-128);
				// tri floors front/right/back/left
				checks.insertLast(v_forward*(64+36.95));
				checks.insertLast(v_forward*-(64+36.95));
				checks.insertLast(v_right*(64+36.95));
				checks.insertLast(v_right*-(64+36.95));
			}
			
		}
		else if (socketType(self.pev.colormap) == SOCKET_WALL)
		{
			// square floors above/below at front/back
			checks.insertLast(v_forward*64);
			checks.insertLast(v_forward*-64);
			checks.insertLast(v_forward*64 + Vector(0,0,128));
			checks.insertLast(v_forward*-64 + Vector(0,0,128));
			// walls above/below/right/left
			checks.insertLast(Vector(0,0,-128));
			checks.insertLast(Vector(0,0,128));
			checks.insertLast(v_right*128);
			checks.insertLast(v_right*-128);
			// walls connected by edges at 90 degree angles
			checks.insertLast(v_right*64 + v_forward*64);
			checks.insertLast(v_right*64 + v_forward*-64);
			checks.insertLast(v_right*-64 + v_forward*64);
			checks.insertLast(v_right*-64 + v_forward*-64);
			// triangle floors above/below at front/back
			checks.insertLast(v_forward*36.95);
			checks.insertLast(v_forward*-36.95);
			checks.insertLast(v_forward*36.95 + Vector(0,0,128));
			checks.insertLast(v_forward*-36.95 + Vector(0,0,128));
			// walls connected by edges at 120 degree angles
			checks.insertLast(v_right*96 + v_forward*55.43);
			checks.insertLast(v_right*96 + v_forward*-55.43);
			checks.insertLast(v_right*-96 + v_forward*55.43);
			checks.insertLast(v_right*-96 + v_forward*-55.43); 
			// TODO: 60 deg angles?
		}
		else if (type == B_FOUNDATION_STEPS)
		{
			checks.insertLast(v_forward*128);
		}
		else if (type == B_STAIRS or type == B_STAIRS_L)
		{
			checks.insertLast(Vector(0,0,-64));
		}
		else if (type == B_ROOF)
		{
			checks.insertLast(v_forward*64 + Vector(0,0,-192));
		}
		
		for (uint i = 0; i < checks.length(); i++)
		{
			CBaseEntity@ part = getPartAtPos(self.pev.origin + checks[i]);
			
			if (part !is null)
			{
				func_breakable_custom@ bpart = cast<func_breakable_custom@>(CastToScriptClass(part));
				
				bpart.addConnection(self);
				connections.insertLast(EHandle(part));
			}
		}
		
		//println("Found " + connections.length() + " connections");
	}
	
	int TakeDamage( entvars_t@ pevInflictor, entvars_t@ pevAttacker, float flDamage, int bitsDamageType )
	{
		if (dead)
			return 0;
		
		if (pevAttacker.classname != "func_breakable_custom" and !isDoor and !isLadder and parent != -1)
		{
			println("APPLY DAMAGE TO PARENT INSTEAD");
			func_breakable_custom@ ent = getBuildPartByID(parent);
			if (ent is null)
				println("parent not found!");
			else
				ent.TakeDamage(pevInflictor, pevAttacker, flDamage, bitsDamageType);
			return 0;
		}
		
		/*
		if (pevAttacker.classname != "func_breakable_custom")
		{
			decalFix();
		}
		*/	
		
		pev.health -= flDamage;
		
		if (pev.health <= 0)
		{
			dead = true;
			removeAllConnections();
			part_broken(self, self, USE_TOGGLE, 0);
			string sound = material.breakSounds[ Math.RandomLong(0, material.breakSounds.length()-1) ];
			g_SoundSystem.PlaySound(self.edict(), CHAN_STATIC, sound, 1.0f, 1.0f, 0, 90 + Math.RandomLong(0, 20));
			
			Vector center = getCentroid(self);
			Vector mins = self.pev.mins;
			if (isFoundation(self))
			{
				mins.z = -8;
				center = self.pev.origin;
			}
			te_breakmodel(center, self.pev.maxs - mins, Vector(0,0,0), 4, "models/woodgibs.mdl", 8, 0, 8);
			
			g_EntityFuncs.Remove(self);
		}
		else
		{
			string sound = material.hitSounds[ Math.RandomLong(0, material.hitSounds.length()-1) ];
			g_SoundSystem.PlaySound(self.edict(), CHAN_STATIC, sound, 1.0f, 1.0f, 0, 90 + Math.RandomLong(0, 20));
		}
		return 0;
	}
};

void te_breakmodel(Vector pos, Vector size, Vector velocity, 
	uint8 speedNoise=16, string model="models/hgibs.mdl", 
	uint8 count=8, uint8 life=0, uint8 flags=20,
	NetworkMessageDest msgType=MSG_BROADCAST, edict_t@ dest=null)
{
	NetworkMessage m(msgType, NetworkMessages::SVC_TEMPENTITY, dest);
	m.WriteByte(TE_BREAKMODEL);
	m.WriteCoord(pos.x);
	m.WriteCoord(pos.y);
	m.WriteCoord(pos.z);
	m.WriteCoord(size.x);
	m.WriteCoord(size.y);
	m.WriteCoord(size.z);
	m.WriteCoord(velocity.x);
	m.WriteCoord(velocity.y);
	m.WriteCoord(velocity.z);
	m.WriteByte(speedNoise);
	m.WriteShort(g_EngineFuncs.ModelIndex(model));
	m.WriteByte(count);
	m.WriteByte(life);
	m.WriteByte(flags);
	m.End();
}