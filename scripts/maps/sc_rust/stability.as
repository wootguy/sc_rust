
bool g_running_stability = false;
int numSkip = 0;
int numChecks = 0;
dictionary visited_parts; // used to mark positions as already visited when doing the stability search
array<EHandle> stability_ents; // list of ents to check for stability

void checkStabilityEnt(EHandle ent)
{
	if (!ent)
		return;
	for (uint i = 0; i < stability_ents.length(); i++)
	{
		if (stability_ents[i] and stability_ents[i].GetEntity().entindex() == ent.GetEntity().entindex())
			return;
	}
	stability_ents.insertLast(ent);
}

void debug_stability(Vector start, Vector end)
{
	if (getPartAtPos(end) !is null)
		te_beampoints(start, end, "sprites/laserbeam.spr", 0, 100, 255,1,0,GREEN);
	else
		te_beampoints(start, end, "sprites/laserbeam.spr", 0, 100, 255,1,0,Color(255, 0, 0, 0));
}

bool searchFromPart(func_breakable_custom@ part)
{
	if (visited_parts.exists(part.entindex()))
	{
		numSkip++;
		return false;
	}
	visited_parts[part.entindex()] = true;
	numChecks++;
	
	if (part.pev.colormap == B_FOUNDATION or part.pev.colormap == B_FOUNDATION_TRI) {
		return true;
	}
	for (uint i = 0; i < part.connections.length(); i++)
	{
		if (part.connections[i])
		{
			if (searchFromPart(cast<func_breakable_custom@>(CastToScriptClass(part.connections[i].GetEntity()))))
				return true;
		}
		
	}
	return false;
}

void part_broken(CBaseEntity@ pActivator, CBaseEntity@ pCaller, USE_TYPE useType, float flValue)
{
	if (pCaller.pev.effects & EF_NODRAW == 0)
	{
		PlayerState@ state = getPlayerStateBySteamID(pCaller.pev.noise1, pCaller.pev.noise2);
		if (state !is null)
			state.partDestroyed(pCaller);
	}
	
	propogate_part_destruction(pCaller);
}

void propogate_part_destruction(CBaseEntity@ ent)
{	
	int type = ent.pev.colormap;
	int socket = socketType(type);
	if (ent.pev.classname == "func_breakable_custom")
	{
		func_breakable_custom@ bpart = cast<func_breakable_custom@>(CastToScriptClass(ent));
		for (uint i = 0; i < bpart.connections.length(); i++)
			checkStabilityEnt(bpart.connections[i]);
	}

	// destroy objects parented to this one
	array<EHandle> children = getPartsByParent(ent.pev.team);
	for (uint i = 0; i < children.length(); i++)
	{
		CBaseEntity@ child = children[i];
		if (child.entindex() == ent.entindex())
			continue;
		child.TakeDamage(child.pev, child.pev, 9e99, 0);
		if (child.pev.classname == "func_ladder")
		{
			g_EntityFuncs.Remove(child);
		}
	}
	
	if (type == B_LADDER_HATCH or type == B_LADDER or type == B_WOOD_SHUTTERS)
	{
		// kill tied entities (ladder, secondary door)
		array<EHandle> parents = getPartsByID(ent.pev.team);
		for (uint i = 0; i < parents.length(); i++)
		{
			CBaseEntity@ parent = parents[i].GetEntity();
			parent.TakeDamage(parent.pev, parent.pev, parent.pev.health, 0);
			if (parent.pev.classname == "func_ladder")
			{
				g_EntityFuncs.Remove(parent);
			}
		}
	}
	
	if (!g_running_stability)
		stabilityCheck();
}


void stabilityCheck()
{
	println("Stability check time!");
	g_running_stability = true;
	int numIter = 0;
	
	// check for destroyed ents
	for (uint i = 0; i < g_build_parts.length(); i++)
	{
		func_breakable_custom@ ent = cast<func_breakable_custom@>(CastToScriptClass(g_build_parts[i].GetEntity()));
		if (ent is null)
		{
			g_build_parts.removeAt(i);
			i--;
		}
		else
		{
			ent.pev.frame = 0;
			ent.pev.framerate = 0;
			if (ent.pev.team != ent.id)
			{
				println("stabilityCheck: Bad ID! " + ent.id + " != " + ent.pev.team);
				ent.pev.team = ent.id;
			}
		}
	}
	
	float check_delay = 0.5f; // default to infrequent checks to reduce CPU usage
	bool any_broken = false;
	
	while(stability_ents.length() > 0)
	{		
		visited_parts.deleteAll();
		CBaseEntity@ src_part = stability_ents[0];
		
		if (src_part is null)
		{
			stability_ents.removeAt(0);
			continue;
		}
		
		if (src_part.pev.classname != "func_breakable_custom")
		{
			println("stabilityCheck: Not a support part!");
			stability_ents.removeAt(0);
			continue;
		}
		
		func_breakable_custom@ bpart = cast<func_breakable_custom@>(CastToScriptClass(src_part));
		
		int type = src_part.pev.colormap;
		int socket = socketType(type);
		Vector pos = src_part.pev.origin;
		
		if (src_part.pev.colormap == B_FOUNDATION or socket == SOCKET_HIGH_WALL or src_part.pev.colormap == B_FOUNDATION_TRI)
		{
			stability_ents.removeAt(0);
			continue;
		}
			
		// try to find a connected path to a foundation
		// otherwise break the part
		
		numChecks = 0;
		numSkip = 0;
		
		bool supported = searchFromPart(bpart);

		//println("Stability for part " + src_part.pev.team + " finished in " + numChecks + " checks (" + numSkip + " skipped). Result is " + supported);
		
		if (!supported) {
			any_broken = true;
			check_delay = 0.05; // do fast checks while stuff is breaking
			
			propogate_part_destruction(src_part);
			src_part.TakeDamage(src_part.pev, src_part.pev, src_part.pev.health, 0);
			if (src_part.pev.classname == "func_ladder")
			{
				g_EntityFuncs.Remove(src_part);
			}
		}
		stability_ents.removeAt(0);
		break;
	}
	if (any_broken)
		g_Scheduler.SetTimeout("stabilityCheck", check_delay);
	else
		g_running_stability = false;
}
