
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
	
	void Activate()
	{
		if (active)
			return;
			
		active = true;
		expireTime = g_Engine.time + g_corpse_time;
		pev.effects = 0;
		
		if (!owner)
		{
			println("corpse has no owner!");
			return;
		}
		
		CBasePlayer@ plr = cast<CBasePlayer@>(owner.GetEntity());
		InventoryList@ inv = plr.get_m_pInventory();
		while (inv !is null)
		{
			CItemInventory@ item = cast<CItemInventory@>(inv.hItem.GetEntity());
			@inv = inv.pNext;
			if (item !is null)
			{
				int amt = item.pev.button > 0 ? item.pev.button : 1;
				CBaseEntity@ newItem = spawnItem(pev.origin, item.pev.colormap-1, amt);
				newItem.pev.effects = EF_NODRAW;
				items.insertLast(EHandle(newItem));
				item.pev.renderfx = -9999;
				g_Scheduler.SetTimeout("delay_remove", 0, EHandle(item));
			}
		}
		
		// add weapons
		for (uint i = 0; i < MAX_ITEM_TYPES; i++)
		{
			CBasePlayerItem@ wep = plr.m_rgpPlayerItems(i);
			while (wep !is null)
			{
				Item@ wepItem = getItemByClassname(wep.pev.classname);
				
				if (wepItem !is null)
				{
					int amt = wep.pev.button > 0 ? wep.pev.button : 1;
					CBaseEntity@ newItem = spawnItem(pev.origin, wepItem.type, amt);
					newItem.pev.effects = EF_NODRAW;
					items.insertLast(EHandle(newItem));
				}
				
				
				@wep = cast<CBasePlayerItem@>(wep.m_hNextItem.GetEntity());				
			}
		}
		
		// add ammo
		for (uint i = 0; i < g_ammo_types.size(); i++)
		{
			int ammo = plr.m_rgAmmo(g_PlayerFuncs.GetAmmoIndex(g_ammo_types[i]));
			if (ammo > 0)
			{
				Item@ item = getItemByClassname(g_ammo_types[i]);
				
				CBaseEntity@ newItem = spawnItem(pev.origin, item.type, ammo);
				newItem.pev.effects = EF_NODRAW;
				items.insertLast(EHandle(newItem));
			}
		}
		
		// remove other corpses (prevent corpse spam)
		for (uint i = 0; i < g_corpses.size(); i++)
		{
			if (!g_corpses[i])
				continue;
				
			player_corpse@ corpse = cast<player_corpse@>(CastToScriptClass(g_corpses[i]));
			if (corpse.owner.IsValid() and corpse.owner.GetEntity().entindex() == plr.entindex() 
				and corpse.entindex() != self.entindex())
			{
				println("Removed an older corpse");
				corpse.Destroy();
			}
		}
		
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
			self.pev.origin = plr.pev.origin + Vector(0,0,-36);
			self.pev.angles = plr.pev.angles;
			
			if (plr.pev.effects & EF_NODRAW != 0)
			{
				// player was gibbed
				Activate();
				g_PlayerFuncs.ScreenFade(plr, Vector(0,0,0), 1.0f, 2.0f, 255, FFADE_OUT);
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
	}
};