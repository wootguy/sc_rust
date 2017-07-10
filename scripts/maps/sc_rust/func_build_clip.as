class func_build_clip : ScriptBaseEntity
{
	BMaterial material;
	int id;

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
		self.pev.effects = EF_NODRAW;
		println("CREATE BUILD CLIP " + id);
		
		g_EntityFuncs.SetModel(self, self.pev.model);
		g_EntityFuncs.SetOrigin(self, self.pev.origin);
	}
	
	void Touch( CBaseEntity@ pOther )
	{
		println("TOUCHED BY " + pOther.pev.classname);
		te_beampoints(self.pev.origin, pOther.pev.origin);
	}
	
	void Use(CBaseEntity@ pActivator, CBaseEntity@ pCaller, USE_TYPE useType, float flValue = 0.0f)
	{
		//println("USED BY " + pCaller.pev.classname);
	}
};