
class monster_c4 : ScriptBaseEntity
{
	int life = 10;
	
	bool KeyValue( const string& in szKey, const string& in szValue )
	{
		return BaseClass.KeyValue( szKey, szValue );
	}
	
	void Spawn()
	{		
		pev.movetype = MOVETYPE_FLY;
		pev.solid = SOLID_NOT;
		
		g_EntityFuncs.SetModel(self, "models/sc_rust/w_c4.mdl");
		g_EntityFuncs.SetSize(self.pev, Vector( -8, -8, -8), Vector(8, 8, 8));
		
		// attach to surface
		pev.angles.x *= -1;
		g_EngineFuncs.MakeVectors(self.pev.angles);
		pev.angles.x *= -1;
		TraceResult tr;
		g_Utility.TraceLine( self.pev.origin, self.pev.origin - g_Engine.v_forward*16, ignore_monsters, self.edict(), tr );
		
		g_EntityFuncs.SetOrigin( self, tr.vecEndPos);

		SetThink( ThinkFunction( Think ) );
		pev.nextthink = g_Engine.time + 1;

		pev.takedamage = DAMAGE_NO;
		pev.health = 1;
	}
	
	void Think()
	{
		life--;
		
		if (life <= 0)
		{
			pev.angles.x *= -1;
			g_EngineFuncs.MakeVectors(self.pev.angles);
			pev.angles.x *= -1;
			
			TraceResult tr;
			g_Utility.TraceLine( self.pev.origin, self.pev.origin - g_Engine.v_forward*8, ignore_monsters, self.edict(), tr );
			
			CBaseEntity@ phit = g_EntityFuncs.Instance( tr.pHit );
			if (phit !is null and phit.pev.classname != "worldspawn")
				phit.TakeDamage(self.pev, self.pev, 185.0f, DMG_BLAST);
			
			g_EntityFuncs.CreateExplosion(self.pev.origin, self.pev.angles, @self.pev.owner, 150, true);
			//g_SoundSystem.PlaySound(self.edict(), CHAN_WEAPON, "sc_rust/c4_explode1.wav", 1.0f, 1.0f, 0, 100);
			g_EntityFuncs.Remove(self);
		}
		else
			g_SoundSystem.PlaySound(self.edict(), CHAN_WEAPON, "sc_rust/c4_beep.wav", 1.0f, 1.0f, 0, 100);
		
		pev.nextthink = g_Engine.time + 1;
	}
};


class monster_satchel_charge : ScriptBaseEntity
{
	float deathTime = 0;
	Vector sparkPos;
	
	bool KeyValue( const string& in szKey, const string& in szValue )
	{
		return BaseClass.KeyValue( szKey, szValue );
	}
	
	void Spawn()
	{		
		pev.movetype = MOVETYPE_FLY;
		pev.solid = SOLID_NOT;
		
		g_EntityFuncs.SetModel(self, "models/w_satchel.mdl");		
		g_EntityFuncs.SetSize(self.pev, Vector( -8, -8, -8), Vector(8, 8, 8));
		g_EntityFuncs.SetOrigin( self, pev.origin);
		
		// attach to surface
		pev.angles.x *= -1;
		g_EngineFuncs.MakeVectors(self.pev.angles);
		pev.angles.x *= -1;
		TraceResult tr;
		g_Utility.TraceLine( self.pev.origin, self.pev.origin - g_Engine.v_forward*16, ignore_monsters, self.edict(), tr );
		
		g_EntityFuncs.SetOrigin( self, tr.vecEndPos);

		g_SoundSystem.PlaySound(self.edict(), CHAN_WEAPON, "sc_rust/fuse.ogg", 1.0f, 1.0f, 0, 100);
		sparkPos = pev.origin + g_Engine.v_up*18 + g_Engine.v_right*-4 + g_Engine.v_forward*3;
		deathTime = g_Engine.time + Math.RandomFloat(4, 20);
		SetThink( ThinkFunction( Think ) );
		pev.nextthink = g_Engine.time + 0.1;

		pev.takedamage = DAMAGE_NO;
		pev.health = 1;
	}
	
	void Think()
	{		
		if (g_Engine.time > deathTime)
		{			
			g_SoundSystem.StopSound(self.edict(), CHAN_WEAPON, "sc_rust/fuse.ogg");
			g_EntityFuncs.CreateExplosion(self.pev.origin, self.pev.angles, self.edict(), 126, true);
			g_EntityFuncs.Remove(self);
		}
		else
			te_sparks(sparkPos);
		
		pev.nextthink = g_Engine.time + 0.1;
	}
};