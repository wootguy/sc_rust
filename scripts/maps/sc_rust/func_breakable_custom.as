
class BMaterial
{
	array<string> hitSounds;
	array<string> breakSounds;
	string gibs;
	int gibsnd;
	
	BMaterial() {}
	
	BMaterial(array<string> hitSounds, array<string> breakSounds, string gibs, int gibsnd)
	{
		this.hitSounds = hitSounds;
		this.breakSounds = breakSounds;
		this.gibs = gibs;
		this.gibsnd = gibsnd;
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
	{"sc_rust/break_metal.ogg", "sc_rust/break_metal3.ogg", "sc_rust/break_metal4.ogg"},
};

array<BMaterial> g_materials = {
	BMaterial(g_material_damage_sounds[0], g_material_break_sounds[0], "models/woodgibs.mdl", 8),
	BMaterial(g_material_damage_sounds[1], g_material_break_sounds[1], "models/concrete_gibs.mdl", 64),
	BMaterial(g_material_damage_sounds[2], g_material_break_sounds[2], "models/metalplategibs.mdl", 2)
};

array<string> fleshSounds = {"sc_rust/flesh1.ogg", "sc_rust/flesh2.ogg", "sc_rust/flesh3.ogg"};

// The think function won't let me set nextthink (it's always ~5 seconds or so) for this entity
void weird_think_bug_workaround(EHandle h_ent)
{
	if (!h_ent.IsValid())
		return;
	func_breakable_custom@ ent = cast<func_breakable_custom@>(CastToScriptClass(h_ent.GetEntity()));
	if (ent.dead)
		return;
	
	if (ent.isFurnace)
	{
		ent.FurnaceThink();
	}
	else if (ent.nodeType == NODE_XEN)
	{
		ent.MonsterThink();
	}
}

class func_breakable_custom : ScriptBaseEntity
{
	int id = -1;
	int zoneid = -1; // which zone this part belongs in
	int parent = -1; // part id
	bool dead = false; // in the process of dieing?
	bool isDoor = false;
	bool isLadder = false;
	bool isNode = false;
	bool isFurnace = false;
	bool isWindowBars = false;
	bool isCupboard = false;
	bool isAirdrop = false;
	bool isHatch = false;
	bool isItem = false;
	bool supported = false; // is connected to a foundation somehow?
	bool smelting = false; // true if this is a furnace with wood and ore inside
	float lastSmelt = 0;
	float lastWoodBurn = 0;
	float lastThink = 0;
	float deathTime = 0;
	string killtarget;
	Vector mins;
	Vector maxs;
	
	int nodeType = -1;
	
	EHandle monster; // points to the monster that spawned this object (if we are a NODE_XEN)
	EHandle chute; // airdrop
	float monsterDespawnTime = 0;
	array<EHandle> children;
	array<EHandle> connections; // all parts that are supported by or support this part
	array<EHandle> items; // chests only
	int maxItems;
	
	ByteBuffer serialize()
	{
		ByteBuffer buf;
		
		buf.Write(pev.origin.x);
		buf.Write(pev.origin.y);
		buf.Write(pev.origin.z);
		buf.Write(pev.angles.x);
		buf.Write(pev.angles.y);
		buf.Write(pev.angles.z);
		buf.Write(int16(pev.colormap));
		buf.Write(int16(id));
		buf.Write(int16(parent));
		buf.Write(int16(pev.button));
		buf.Write(int16(pev.body));
		buf.Write(pev.vuser1.x);
		buf.Write(pev.vuser1.y);
		buf.Write(pev.vuser1.z);
		buf.Write(pev.vuser2.x);
		buf.Write(pev.vuser2.y);
		buf.Write(pev.vuser2.z);
		buf.Write(float(pev.health));
		buf.Write(float(pev.max_health));
		buf.Write(string(pev.classname));
		buf.Write(string(pev.model));
		buf.Write(int16(pev.groupinfo));
		buf.Write(string(pev.noise1));
		buf.Write(string(pev.noise2));
		buf.Write(string(pev.noise3));
		buf.Write(int16(pev.effects));
		
		// write chest items
		buf.Write(uint8(items.size()));
		for (uint i = 0; i < items.size(); i++)
		{
			if (items[i])
			{
				buf.Write(int16(items[i].GetEntity().pev.colormap-1));
				buf.Write(int16(items[i].GetEntity().pev.button));
			}
			else
			{
				buf.Write(0);
				buf.Write(0);
			}
		}
		
		// write authed players
		array<string> authed_players;
		array<string>@ stateKeys = player_states.getKeys();
		for (uint i = 0; i < stateKeys.length(); i++)
		{
			PlayerState@ state = cast<PlayerState@>( player_states[stateKeys[i]] );
			for (uint k = 0; k < state.authedLocks.length(); k++)
			{
				if (!state.authedLocks[k] or state.authedLocks[k].GetEntity().entindex() == self.entindex())
				{
					string authid = getPlayerUniqueId(cast<CBasePlayer@>(state.plr.GetEntity()));
					authed_players.insertLast(authid);
				}
			}
		}
		
		buf.Write(uint8(authed_players.size()));
		for (uint i = 0; i < authed_players.length(); i++) {
			buf.Write(authed_players[i]);
		}
		
		return buf;
	}
	
	bool KeyValue( const string& in szKey, const string& in szValue )
	{
		if (szKey == "id") id = atoi(szValue);
		else if (szKey == "parent") parent = atoi(szValue);
		else if (szKey == "zoneid") zoneid = atoi(szValue);
		else if (szKey == "killtarget") killtarget = szValue;
		else if (szKey == "nodetype") nodeType = atoi(szValue);
		else if (szKey == "min") mins = parseVector(szValue);
		else if (szKey == "max") maxs = parseVector(szValue);
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
		isNode = self.pev.colormap == -1;
		isFurnace = self.pev.colormap == B_FURNACE;
		isCupboard = self.pev.colormap == B_TOOL_CUPBOARD;
		isWindowBars = self.pev.colormap == B_WOOD_BARS or self.pev.colormap == B_METAL_BARS;
		isAirdrop = self.pev.colormap == E_SUPPLY_CRATE;
		isHatch = self.pev.colormap == B_LADDER_HATCH and isDoor;
		isItem = isFloorItem(self);
		if (!isNode and debug_mode)
			println("CREATE PART " + id + " WITH PARENT " + parent);
		
		if (isNode)
		{
			self.pev.effects = EF_NODRAW;
		}
		else
			self.SetClassification(CLASS_PLAYER);
		
		g_EntityFuncs.SetModel(self, self.pev.model);
		//g_EntityFuncs.SetSize(self.pev, self.pev.mins, self.pev.maxs);
		g_EntityFuncs.SetOrigin(self, self.pev.origin);
		
		if (nodeType == NODE_XEN)
		{
			self.pev.solid = SOLID_BBOX;
			
			monsterDespawnTime = g_Engine.time + (g_corpse_time - 1); // -1 for fadeout delay
			g_EntityFuncs.SetSize(self.pev, mins, maxs);
		}

		if (!isNode)
			updateConnections();
		
		if (isDoor)
		{
			SetThink( ThinkFunction( DoorThink ) );
			pev.nextthink = g_Engine.time;
		}
		else if (isAirdrop)
		{
			deathTime = g_Engine.time + g_supply_time;
			SetThink( ThinkFunction( AirdropThink ) );
			pev.nextthink = g_Engine.time;
		}
		else if (isFurnace)
		{
			FurnaceThink();
		}
		else if (nodeType == NODE_XEN)
		{
			MonsterThink();
		}
	}
	
	BMaterial@ getMaterial()
	{
		int matid = getMaterialTypeInt(self);
		if (matid < 0) matid = 0;
		if (matid >= 3) matid = 2;
		if (nodeType == NODE_ROCK)
			matid = 1;
		if (nodeType == NODE_BARREL)
			matid = 2;
		return @g_materials[matid];
	}
	
	void Blocked(CBaseEntity@ pOther)
	{
		if (isAirdrop)
		{
			pev.velocity = Vector(0,0,0);
			if (chute)
			{
				CBaseAnimating@ ent = cast<CBaseAnimating@>(chute.GetEntity());
				pev.origin.z = ent.pev.origin.z - ent.pev.mins.z;
				ent.pev.frame = 0;
				ent.pev.sequence = 2;
				ent.ResetSequenceInfo();
				g_Scheduler.SetTimeout("delay_remove", 2, chute);
			}
		}
	}
	
	void MonsterThink()
	{
		if (!monster.IsValid())
		{
			//println("The monster died! *kms*");
			g_EntityFuncs.Remove(self);
			return;
		}
		
		CBaseMonster@ mon = cast<CBaseMonster@>(monster.GetEntity());
		
		if (g_Engine.time > monsterDespawnTime)
		{
			mon.m_fCanFadeStart = true;
			if (g_Engine.time > monsterDespawnTime + 1.0f)
			{
				// wait for the fade effect
				g_EntityFuncs.Remove(self);
				return;
			}
		}
		else
			mon.BeginRevive(1.0f); // prevent corpse fadeout
		g_Scheduler.SetTimeout("weird_think_bug_workaround", 0.1, EHandle(self));
	}
	
	void FurnaceThink()
	{
		// EF_FRAMEANIMTEXTURES doesn't work so I have to constantly set the frame (possible net lag)
		pev.frame = smelting ? 1 : 0;
		if (lastThink + 1.0f > g_Engine.time)
		{
			if (!dead)
				g_Scheduler.SetTimeout("weird_think_bug_workaround", 0, EHandle(self));
			return;
		}
			
		lastThink = g_Engine.time;
		bool hasWood = false;
		bool hasOre = false;
		int oreType = -1;
		int outputType = -1;
		for (uint i = 0; i < items.size(); i++)
		{
			if (!items[i].IsValid())
				continue;
			int itemType = items[i].GetEntity().pev.colormap-1;
			if (itemType == I_WOOD)
				hasWood = true;
			if (itemType == I_METAL_ORE or itemType == I_HQMETAL_ORE)
			{
				hasOre = true;
				oreType = itemType;
				outputType = itemType == I_METAL_ORE ? I_METAL : I_HQMETAL;
			}
		}
		
		bool roomForOutput = items.size() < CHEST_ITEM_MAX_FURNACE;
		if (!roomForOutput)
		{
			for (uint i = 0; i < items.size(); i++)
			{
				if (!items[i].IsValid())
					continue;
				int itemType = items[i].GetEntity().pev.colormap-1;
				if (itemType < 0 and itemType >= int(g_items.size()))
					continue;
				Item@ itemDef = g_items[itemType];
				if (itemType == I_METAL and oreType == I_METAL_ORE or itemType == I_HQMETAL and oreType == I_HQMETAL_ORE)
				{
					outputType = itemType;
					if (items[i].GetEntity().pev.button < itemDef.stackSize)
						roomForOutput = true;
				}
			}
		}
		
		bool canSmelt = hasWood and hasOre and roomForOutput;
		
		if (canSmelt)
		{
			if (!smelting)
			{
				lastSmelt = g_Engine.time;
				g_SoundSystem.PlaySound(self.edict(), CHAN_BODY, "ambience/burning3.wav", 0.5f, 1.0f, 0, 80);
			}
			pev.frame = 1;
			smelting = true;
			
			if (smelting)
			{
				float smeltTime = outputType == I_HQMETAL_ORE ? COOK_TIME_HQMETAL : COOK_TIME_METAL; 
				if (lastSmelt + smeltTime < g_Engine.time)
				{
					lastSmelt = g_Engine.time;
					bool hasOutput = false;
					for (uint i = 0; i < items.size(); i++)
					{
						if (!items[i].IsValid())
						continue;
						int itemType = items[i].GetEntity().pev.colormap-1;
						if (itemType == oreType)
						{
							if (--items[i].GetEntity().pev.button <= 0)
							{
								g_Scheduler.SetTimeout("delay_remove", 0, items[i]);
								items.removeAt(i);
								i--;
							}
						}
						if (itemType == outputType)
						{
							items[i].GetEntity().pev.button++;
							hasOutput = true;
						}
					}
					if (!hasOutput)
					{
						println("TRY TO SPAWN: " + outputType);
						CBaseEntity@ newItem = spawnItem(pev.origin, outputType, 1);
						newItem.pev.effects = EF_NODRAW;
						depositItem(EHandle(newItem));
					}
				}
				if (lastWoodBurn + COOK_TIME_WOOD < g_Engine.time)
				{
					lastWoodBurn = g_Engine.time;
					for (uint i = 0; i < items.size(); i++)
					{
						if (!items[i].IsValid())
							continue;
						int itemType = items[i].GetEntity().pev.colormap-1;
						if (itemType == I_WOOD)
						{
							if (--items[i].GetEntity().pev.button <= 0)
							{
								g_Scheduler.SetTimeout("delay_remove", 0, items[i]);
								items.removeAt(i);
								i--;
							}
						}
					}
				}
			}
		}
		else
		{
			if (smelting)
			{
				pev.frame = 0;
				g_SoundSystem.StopSound(self.edict(), CHAN_BODY, "ambience/burning3.wav");
			}
			smelting = false;
		}
			
		g_Scheduler.SetTimeout("weird_think_bug_workaround", 0, EHandle(self));
	}
	
	void AirdropThink()
	{
		//self.pev.angles = self.pev.angles + self.pev.avelocity;
		//pev.origin = pev.origin + pev.velocity;
		if (g_Engine.time > deathTime)
			Destroy();
		pev.nextthink = g_Engine.time;
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
	
	int spaceLeft()
	{
		return capacity() - items.size();
	}
	
	int capacity()
	{
		switch(pev.colormap)
		{
			case B_LARGE_CHEST: return CHEST_ITEM_MAX_LARGE;
			case B_SMALL_CHEST: return CHEST_ITEM_MAX_SMALL;
			case B_FURNACE: return CHEST_ITEM_MAX_FURNACE;
			case E_SUPPLY_CRATE: return 64; // no limit, essentially
		}
		return 0;
	}
	
	int depositItem(int type, int amt)
	{
		CBaseEntity@ newItem = spawnItem(g_void_spawn, type, amt);
		if (newItem is null)
		{
			println("Failed to create item type " + type + " x" + amt);
			return 0;
		}
		newItem.pev.effects = EF_NODRAW;
		return depositItem(EHandle(newItem));
	}
	
	int depositItem(EHandle item)
	{
		if (!item.IsValid())
			return 0;
		
		int type = item.GetEntity().pev.colormap-1;
		if (type >= 0 and type < int(g_items.size()))
		{
			Item@ giveItem = g_items[type];
			if (giveItem.stackSize > 1)
			{
				int giveLeft = item.GetEntity().pev.button;
				for (uint i = 0; i < items.size(); i++)
				{
					if (!items[i].IsValid())
						continue;
					CBaseEntity@ stack = items[i].GetEntity();
						
					if (stack.pev.colormap == giveItem.type+1 and stack.pev.button < giveItem.stackSize)
					{
						int addAmt = Math.min(giveItem.stackSize - stack.pev.button, giveLeft);
						stack.pev.button += addAmt;
						item.GetEntity().pev.button -= addAmt;
						giveLeft -= addAmt;
					}
				}
				
				if (giveLeft <= 0)
				{
					g_Scheduler.SetTimeout("delay_remove", 0, item);
					return 0;
				}
			}
		}
		
		if (int(items.size()) >= capacity())
		{
			g_Scheduler.SetTimeout("delay_remove", 0, item);
			return item.GetEntity().pev.button;
		}
		
		items.insertLast(item);
			
		return 0;
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
		
		if (isFloorPiece(self) and !isHatch)
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
		
		if (pevAttacker.classname == "monster_kingpin") {
			flDamage *= 4;
		}
		if (g_invasion_mode and string(pevAttacker.classname).StartsWith("monster_")) {
			flDamage *= 2;
			if (!isItem)
			{
				if (g_difficulty == 0)
					flDamage *= 4;
				else if (g_difficulty == 1)
					flDamage *= 8;
				else if (g_difficulty == 2)
					flDamage *= 16;
			}
		}
		
		
		if (pevInflictor.classname != "func_breakable_custom" and !isDoor and !isLadder and !isWindowBars and !isItem and parent != -1 and !isAirdrop)
		{
			func_breakable_custom@ ent = getBuildPartByID(parent);
			if (ent is null)
				println("parent not found!");
			else
				ent.TakeDamage(pevInflictor, pevAttacker, flDamage, bitsDamageType);
			return 0;
		}
		
		if (isNode and pevInflictor.classname == "player")
		{
			// harvest resources
			CBasePlayer@ plr = cast<CBasePlayer@>( g_EntityFuncs.Instance(pevInflictor.get_pContainingEntity()) );
			CBaseEntity@ weapon = plr.m_hActiveItem;
			string weaponName = weapon.pev.classname;
			
			if (isMeleeWeapon(weapon.pev.classname))
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
				
				bool hasSpace = getInventorySpace(plr) > 0;
				int giveAmount = 0;
				int giveType = I_WOOD;
				if (nodeType == NODE_TREE)
				{
					if (weaponName == "weapon_rock" or weaponName == "weapon_custom_crowbar") giveAmount = 10;
					if (weaponName == "weapon_stone_hatchet") giveAmount = 20;
					if (weaponName == "weapon_metal_hatchet") giveAmount = 30;
					if (weaponName == "weapon_stone_pickaxe") giveAmount = 10;
					if (weaponName == "weapon_metal_pickaxe") giveAmount = 15;
					
					giveType = I_WOOD;
				}
				if (nodeType == NODE_ROCK)
				{
					if (weaponName == "weapon_rock" or weaponName == "weapon_custom_crowbar") giveAmount = 5;
					if (weaponName == "weapon_stone_hatchet") giveAmount = 10;
					if (weaponName == "weapon_metal_hatchet") giveAmount = 15;
					if (weaponName == "weapon_stone_pickaxe") giveAmount = 20;
					if (weaponName == "weapon_metal_pickaxe") giveAmount = 50;
					
					giveType = I_STONE;
					if (Math.RandomLong(0,5) <= 1)
					{
						if (Math.RandomLong(0, 3) == 0)
						{
							giveType = I_HQMETAL_ORE;
							giveAmount /= 5;
						}
						else
						{
							giveType = I_METAL_ORE;
							giveAmount /= 2;
						}
						
					}
				}
				
				// TODO: Only give if using a melee weapon
				if (nodeType == NODE_BARREL)
				{
					if (pev.health - flDamage <= 0)
						giveAmount = Math.RandomLong(1,2);
					else
						giveAmount = 0;
					giveType = I_SCRAP;
				}
				if (nodeType == NODE_XEN)
				{
					giveAmount = Math.RandomLong(1,2);
					giveType = I_FUEL;
				}
				
				giveAmount = int(giveAmount*g_gather_multiplier);
				
				if (hasSpace and giveAmount > 0)
					g_PlayerFuncs.HudMessage(plr, params, "+" + int(giveAmount) + " " + g_items[giveType].title);
				
				giveItem(plr, giveType, giveAmount, false, true);
				
				if (nodeType != NODE_BARREL)
					flDamage = giveAmount > 0 ? 10 : 0;
			}
			else
			{
				if (nodeType == NODE_ROCK)
					flDamage /= 10;
				if (nodeType == NODE_XEN)
					flDamage = 10;
			}
		}
		
		if (!isNode)
		{
			if (bitsDamageType & DMG_BLAST != 0)
			{
				if (pevAttacker.classname == "monster_satchel_charge")
					flDamage *= 6;
				else
					flDamage *= 10;
			}
			else if (bitsDamageType & DMG_SONIC != 0)
			{
				flDamage *= 5;
			}
			else if (bitsDamageType & DMG_BURN != 0)
			{
				string mat = getMaterialType(self);
				if (mat == "_twig" or mat == "_wood")
					flDamage *= 2;
				else
					flDamage = 0;
			}
			else if (pevInflictor.classname == "player")
			{
				flDamage *= 0.5f;
			}
		}
		
		pev.health -= flDamage;
		
		BMaterial@ material = getMaterial();
		float attn = 0.4f;
		if (pev.health <= 0)
		{
			dead = true;
			if (!isNode)
			{
				if (!isAirdrop)
				{
					removeAllConnections();
					part_broken(self, self, USE_TOGGLE, 0);
				}
				
				if (pev.effects & EF_NODRAW != 0)
				{
					func_breakable_custom@ parentPart = getBuildPartByID(parent);
					if (parentPart !is null)
						@material = parentPart.getMaterial();
				}

				string sound = material.breakSounds[ Math.RandomLong(0, material.breakSounds.length()-1) ];
				g_SoundSystem.PlaySound(self.edict(), CHAN_STATIC, fixPath(sound), 1.0f, attn, 0, Math.RandomLong(85, 115));
				
				Vector center = getCentroid(self);
				Vector mins = self.pev.mins;
				if (isFoundation(self))
				{
					mins.z = -8;
					center = self.pev.origin;
				}
				te_breakmodel(center, self.pev.maxs - mins, Vector(0,0,0), 4, material.gibs, 8, 0, material.gibsnd);
			}
			else if (monster)
			{
				if (monster)
				{
					CBaseMonster@ mon = cast<CBaseMonster@>(monster.GetEntity());
					mon.GibMonster();
				}
			}
			else
			{
				g_SoundSystem.PlaySound(self.edict(), CHAN_STATIC, fixPath("sc_rust/stone_tree.ogg"), 1.0f, attn, 0, 90 + Math.RandomLong(0, 20));
			}

			g_EntityFuncs.Remove(self);
			
			if (killtarget.Length() > 0)
			{
				CBaseEntity@ kill = g_EntityFuncs.FindEntityByTargetname(null, killtarget);
				if (kill !is null)
					g_EntityFuncs.Remove(kill);
			}
		}
		else
		{
			if (monster)
			{
				CBaseEntity@ mon = monster;
				Vector vel = Vector(Math.RandomFloat(-64, 64), Math.RandomFloat(-64, 64), 160);
				te_model(mon.pev.origin + Vector(0,0,0), vel, Math.RandomFloat(-180, 180), "models/agibs.mdl", 0, 10);
				te_bloodsprite(mon.pev.origin + Vector(0,0,16), "sprites/bloodspray.spr", "sprites/blood.spr", BLOOD_COLOR_YELLOW);
				
				string sound = fleshSounds[ Math.RandomLong(0, fleshSounds.length()-1) ];
				g_SoundSystem.PlaySound(self.edict(), CHAN_STATIC, fixPath(sound), 0.8f, attn, 0, Math.RandomLong(90, 110));
			}
			else
			{
				float dmgVolume = bitsDamageType & DMG_BURN != 0 ? 0.0f : 0.8f;
				string sound = material.hitSounds[ Math.RandomLong(0, material.hitSounds.length()-1) ];
				g_SoundSystem.PlaySound(self.edict(), CHAN_STATIC, fixPath(sound), dmgVolume, attn, 0, Math.RandomLong(90, 110));
			}
		}
		return 0;
	}

	void Destroy()
	{
		g_EntityFuncs.Remove(monster);
		g_EntityFuncs.Remove(chute);
		g_EntityFuncs.Remove(self);
	}
};
