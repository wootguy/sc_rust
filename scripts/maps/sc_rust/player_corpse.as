
void teleport_dead(EHandle h_plr)
{
	if (h_plr)
	{
		if (h_plr.GetEntity().pev.deadflag > 0)
			h_plr.GetEntity().pev.origin = g_dead_zone;
	}
}

class player_corpse : ScriptBaseMonsterEntity
{
	array<EHandle> items;
	float expireTime;
	EHandle owner;
	bool active = false;
	int removeCounter = 0; 
	
	bool KeyValue( const string& in szKey, const string& in szValue )
	{
		return BaseClass.KeyValue( szKey, szValue );
	}
	
	void Spawn()
	{
		self.pev.solid = SOLID_BBOX;
		self.pev.movetype = MOVETYPE_NONE;
		self.pev.effects = EF_NODRAW;
		self.pev.health = 10.0f;
		self.pev.takedamage = DAMAGE_YES;
		self.m_bloodColor = BLOOD_COLOR_RED;
		
		g_EntityFuncs.SetModel(self, self.pev.model);
		g_EntityFuncs.SetOrigin(self, self.pev.origin);
		g_EntityFuncs.SetSize(self.pev, Vector(-16, -16, 0), Vector(16, 16, 8));
		
		SetThink( ThinkFunction( Think ) );
		SetUse( UseFunction( Use ) ); // doesn't work...
		
		pev.nextthink = g_Engine.time;
	}
	
	void Use(CBaseEntity@ pActivator, CBaseEntity@ pCaller, USE_TYPE useType, float flValue = 0.0f)
	{
		println("USED BY " + pCaller.pev.classname);
	}
	
	void Update()
	{
		if (!owner)
		{
			println("corpse has no owner!");
			return;
		}
		
		RemoveItems();
		
		array<RawItem> raw_items = getPlayerState(cast<CBasePlayer@>(owner.GetEntity())).allItems;
		for (uint i = 0; i < raw_items.size(); i++)
		{
			CBaseEntity@ newItem = spawnItem(pev.origin, raw_items[i].type, raw_items[i].amt);
			if (newItem is null)
			{
				println("Failed to create item type " + raw_items[i].type + " x" + raw_items[i].amt);
				continue;
			}
			newItem.pev.effects = EF_NODRAW;
			items.insertLast(EHandle(newItem));
		}
	}
	
	void Activate()
	{
		if (active)
			return;
			
		removeCounter = 0;
		active = true;
		expireTime = g_Engine.time + g_corpse_time;
		pev.effects = 0;
		
		// remove unvaluable corpses to:
		// 1) prevent corpse spam
		// 2) prevent despawning valuable items (despawning the corpse before killer/you can loot the corpse)
		player_corpse@ best_corpse = null;
		float worst_value = 9e99;
		int corpseCount = 0;
		for (uint i = 0; i < g_corpses.size(); i++)
		{
			if (!g_corpses[i])
				continue;
				
			string steamid = g_corpses[i].GetEntity().pev.noise1;
			string netname = g_corpses[i].GetEntity().pev.noise2;
			PlayerState@ state = getPlayerStateBySteamID(steamid, netname);
			if (state.plr.GetEntity().entindex() == owner.GetEntity().entindex() and 
				g_corpses[i].GetEntity().entindex() != self.entindex())
			{
				player_corpse@ corpse = cast<player_corpse@>(CastToScriptClass(g_corpses[i]));
				corpseCount++;
				if (int(corpse.items.size()) < worst_value)
				{
					worst_value = corpse.items.size();
					@best_corpse = @corpse;
				}
			}
		}
		if (corpseCount >= g_max_corpses and best_corpse !is null)
			best_corpse.Destroy();
			
		self.pev.movetype = MOVETYPE_TOSS;
		
		println("Corpse activated");
	}
	
	int entindex()
	{
		return self.entindex();
	}
	
	void Think()
	{
		if (owner.IsValid() and !active)
		{
			if (owner.GetEntity().pev.deadflag == DEAD_NO and removeCounter++ > 2)
			{
				println("Removed corpse because player was revived");
				Destroy();
			}
		}
		if (active and g_Engine.time > expireTime)
			Destroy();
		if (!active and owner.IsValid())
		{
			CBaseEntity@ plr = owner;
			if (!plr.IsAlive())
			{
				self.pev.origin = plr.pev.origin + Vector(0,0,-36);
				self.pev.angles = plr.pev.angles;
			}
			
			if (plr.pev.effects & EF_NODRAW != 0)
			{
				// player was gibbed
				Activate();
				g_PlayerFuncs.ScreenFade(plr, Vector(0,0,0), 1.0f, 1.0f, 255, FFADE_OUT);
				g_Scheduler.SetTimeout("teleport_dead", 1.5f, EHandle(plr));
			}
		}
		pev.nextthink = g_Engine.time + 0.1f;
	}
	
	int TakeDamage( entvars_t@ pevInflictor, entvars_t@ pevAttacker, float flDamage, int bitsDamageType )
	{
		pev.health -= flDamage;
		
		if (pev.health < 0)
		{
			if (owner and !active)
			{
				CBaseEntity@ plr = owner;
				g_PlayerFuncs.ScreenFade(plr, Vector(0,0,0), 1.0f, 2.0f, 255, FFADE_OUT);
				plr.pev.effects |= EF_NODRAW;
				g_Scheduler.SetTimeout("teleport_dead", 1.5f, EHandle(plr));
			}
			
			self.Killed(self.pev, GIB_ALWAYS);
			Destroy();
		}
		
		return 0;
	}	
	
	void Destroy()
	{
		RemoveItems();
		g_EntityFuncs.Remove(self);
	}
	
	void RemoveItems() 
	{
		for (uint i = 0; i < items.size(); i++)
		{
			if (items[i])
			{
				g_EntityFuncs.Remove(items[i]);
			}
		}
		items.resize(0);
	}
};