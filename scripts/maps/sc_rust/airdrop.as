
// items are randomly chosen from this list when filling the crate
array<RawItem> supply_items = {
	RawItem(I_SCRAP,int(10*g_gather_multiplier)),
	RawItem(I_SCRAP,int(20*g_gather_multiplier)),
	RawItem(I_HQMETAL,int(10*g_gather_multiplier)),
	RawItem(I_HQMETAL,int(20*g_gather_multiplier)),
	RawItem(I_FUEL,int(50*g_gather_multiplier)),
	RawItem(I_FUEL,int(100*g_gather_multiplier)),
	
	RawItem(I_METAL_HATCHET,1),
	RawItem(I_METAL_PICKAXE,1),
	RawItem(I_CROWBAR,0),
	
	RawItem(I_SYRINGE,5),
	RawItem(I_SYRINGE,10),
	RawItem(I_ARMOR,2),
	RawItem(I_ARMOR,5),
	
	RawItem(I_FLAMETHROWER,0),
	RawItem(I_RPG,0),
	RawItem(I_GRENADE,5),
	RawItem(I_DEAGLE,0),
	RawItem(I_SHOTGUN,0),
	RawItem(I_SNIPER,0),
	RawItem(I_UZI,0),
	RawItem(I_SAW,0),
	RawItem(I_C4,1),
	
	RawItem(I_556,50),
	RawItem(I_9MM,50),
	RawItem(I_BUCKSHOT,12),
	RawItem(I_ROCKET,1)
};

void spawn_airdrop()
{
	dictionary keys;
	keys["origin"] = getRandomPosition().ToString();
	CBaseEntity@ ent = g_EntityFuncs.CreateEntity("monster_b17", keys, true);
	
	g_Scheduler.SetTimeout("spawn_airdrop", Math.RandomFloat(g_airdrop_min_delay*60.0f, g_airdrop_max_delay*60.0f));
}

class item_parachute : ScriptBaseAnimating
{
	bool KeyValue( const string& in szKey, const string& in szValue )
	{
		return BaseClass.KeyValue( szKey, szValue );
	}
	
	void Spawn()
	{
		pev.movetype = MOVETYPE_FLY;
		pev.solid = SOLID_BBOX;
		pev.scale = 1.5f;
		
		g_EntityFuncs.SetOrigin(self, self.pev.origin);
		g_EntityFuncs.SetModel(self, fixPath("models/sc_rust/parachute.mdl"));
		g_EntityFuncs.SetSize(self.pev,  Vector(-48,-48,-33), Vector(48,48,-32));
		
		pev.frame = 0;
		pev.sequence = 0;
		self.ResetSequenceInfo();
		
		SetThink( ThinkFunction( Think ) );
		pev.nextthink = g_Engine.time;
	}
	
	void Think()
	{
		// for some reason the animation spazzes out when it gets pushed by a func_train-like object
		// calling this fixes it
		self.StudioFrameAdvance(0.0f);
		if (self.m_fSequenceFinished and pev.sequence == 0)
		{
			pev.sequence = 1;
			pev.frame = 0;
			self.ResetSequenceInfo();
		}
		pev.nextthink = g_Engine.time;
	}
}

class monster_b17 : ScriptBaseAnimating
{
	Vector airDropPos;
	float lastDist = 0;
	bool dropped = false;
	float moveSpeed = 1200;
	//float moveSpeed = 4000;
	float dropSpeed = 200;
	Vector v_forward;
	dictionary nearPlayers;
	
	bool KeyValue( const string& in szKey, const string& in szValue )
	{
		return BaseClass.KeyValue( szKey, szValue );
	}
	
	void Spawn()
	{		
		pev.movetype = MOVETYPE_FLY;
		pev.solid = SOLID_NOT;
		
		g_EntityFuncs.SetModel(self, fixPath("models/sc_rust/b17.mdl"));		
		
		pev.frame = 0;
		pev.sequence = 0;
		pev.scale = 1.0f;
		self.ResetSequenceInfo();
		
		//pev.velocity = g_Engine.v_forward*600;

		airDropPos = pev.origin;
		airDropPos.z = g_airdrop_height;
		g_EngineFuncs.MakeVectors(Vector(0,Math.RandomFloat(-180,180),0));
		TraceResult tr;
		g_Utility.TraceLine( airDropPos, airDropPos - g_Engine.v_forward*65536, ignore_monsters, self.edict(), tr );
		
		g_EntityFuncs.SetOrigin( self, tr.vecEndPos);
		pev.velocity = g_Engine.v_forward*moveSpeed;
		g_EngineFuncs.VecToAngles(g_Engine.v_forward, pev.angles);
		v_forward = g_Engine.v_forward;
		
		//te_beampoints(airDropPos, tr.vecEndPos);
		
		
		g_SoundSystem.PlaySound(self.edict(), CHAN_WEAPON, fixPath("sc_rust/b17.ogg"), 1.0f, 0.04f, SND_FORCE_LOOP, 102);
		g_SoundSystem.PlaySound(self.edict(), CHAN_STATIC, fixPath("sc_rust/b17.ogg"), 1.0f, 0.04f, SND_FORCE_LOOP, 98);
		g_SoundSystem.PlaySound(self.edict(), CHAN_BODY, fixPath("sc_rust/b17.ogg"), 1.0f, 0.04f, SND_FORCE_LOOP, 100);
		g_SoundSystem.PlaySound(self.edict(), CHAN_ITEM, fixPath("sc_rust/b17_far.ogg"), 0.7f, 0.02f, SND_FORCE_LOOP, 95);
		
		lastDist = (airDropPos - pev.origin).Length();
		SetThink( ThinkFunction( Think ) );
		pev.nextthink = g_Engine.time + 0.1;
		
		pev.takedamage = DAMAGE_NO;
		pev.health = 1;
	}
	
	void Think()
	{
		if (pev.velocity.Length() < moveSpeed - 10)
		{
			g_SoundSystem.StopSound(self.edict(), CHAN_WEAPON, fixPath("sc_rust/b17.ogg"));
			g_SoundSystem.StopSound(self.edict(), CHAN_STATIC, fixPath("sc_rust/b17.ogg"));
			g_SoundSystem.StopSound(self.edict(), CHAN_BODY, fixPath("sc_rust/b17.ogg"));
			g_SoundSystem.StopSound(self.edict(), CHAN_ITEM, fixPath("sc_rust/b17_far.ogg"));
			g_EntityFuncs.Remove(self);
			return;
		}
		
		// enable trail only as players enter the PVS
		// otherwise they'll never see the trail if the plane wasn't visible at spawn (MSG_BROADCAST ignored?)
		edict_t@ edt = g_EngineFuncs.FindClientInPVS(self.edict());
		while (edt !is null)
		{
			CBasePlayer@ plr = cast<CBasePlayer@>(g_EntityFuncs.Instance( edt ));
			if (plr !is null)
			{
				string id = getPlayerUniqueId(plr);
				if (!nearPlayers.exists(id))
				{
					nearPlayers[id] = true;
					te_trail(self, "sprites/xbeam4.spr", 255, 64, Color(255, 255, 255, 128), MSG_ONE, @plr.edict());
				}
				@edt = @plr.pev.chain;
			}
			else
				break;
		}
		
		if (!dropped)
		{
			float dist = (airDropPos - pev.origin).Length();
		
			if (lastDist < dist)
			{
				dropped = true;
				Vector dropPos = pev.origin + v_forward*80 + Vector(0,0,-32);
				
				dictionary keys;
				keys["origin"] = (dropPos + Vector(0,0,-64)).ToString();
				keys["angles"] = Vector(0,0,0).ToString();
				keys["model"] = getModelFromName("e_supply_crate");
				keys["health"] = "10000";
				keys["max_health"] = "10000";
				keys["colormap"] = "" + E_SUPPLY_CRATE;
				CBaseEntity@ crate = g_EntityFuncs.CreateEntity("func_breakable_custom", keys, true);
				crate.pev.velocity = Vector(0,0,-dropSpeed);
				crate.pev.scale = 0.1f;
				
				// parachute also acts as a ground detecter (calls Block() for the crate if squished)
				keys["origin"] = (dropPos - Vector(0,0,130)).ToString();
				CBaseEntity@ chute = g_EntityFuncs.CreateEntity("item_parachute", keys, true);
				
				func_breakable_custom@ c_crate = cast<func_breakable_custom@>(CastToScriptClass(crate));
				c_crate.chute = EHandle(chute);
				
				int numItems = Math.RandomLong(4, 9);
				for (int i = 0; i < numItems; i++)
				{
					RawItem item = supply_items[Math.RandomLong(0, supply_items.length()-1)];
					c_crate.depositItem(item.type, item.amt);
				}
				
			}
			
			lastDist = dist;
		}
		
		
		pev.nextthink = g_Engine.time + 0.1;
	}
};
