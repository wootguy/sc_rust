#include "ByteBuffer"

bool saveLoadInProgress = false;
string rust_save_path = "scripts/maps/store/";

string loadMapKeyvalue(string label)
{
	dictionary keyvalues;
	string ent_name = 'rust_load_ent_' + label; 
	keyvalues["targetname"] = ent_name;
	keyvalues["target"] = ent_name;
	keyvalues["netname"] = label;
	keyvalues["message"] = "noise3";
	
	// Create and trigger it
	CBaseEntity@ ent = g_EntityFuncs.CreateEntity( "trigger_load", keyvalues, true );
	g_EntityFuncs.FireTargets(ent_name, null, null, USE_ON);
	
	// For some reason we have to run a Find in order to get the updated entity data.
	// It seems the load happens instantly, but the entity reference isn't updated that fast.
	string data;
	CBaseEntity@ updated_ent = g_EntityFuncs.FindEntityByTargetname(null, ent_name);
	if (updated_ent !is null)
		data = updated_ent.pev.noise3;
	else
		println("Failed to load '" + label + "' from map save file");
	
	if (ent !is null)
		g_EntityFuncs.Remove(ent);
	
	return data;
}

string numPartsKeyname = "RustNumParts";
void saveMapData()
{		
	println("Saving " + g_build_parts.length() + " build parts");

	string path = rust_save_path + g_Engine.mapname + ".dat";
	File@ f = g_FileSystem.OpenFile( path, OpenFile::WRITE);
	
	if( f.IsOpen() )
	{
		if (g_build_parts.length() > 0)
		{
			ByteBuffer buf;
			buf.Write(uint32(g_build_parts.length()));
			for (uint i = 0; i < g_build_parts.length(); i++)
			{
				func_breakable_custom@ ent = cast<func_breakable_custom@>(CastToScriptClass(g_build_parts[i].GetEntity()));
				buf.Write(ent.serialize());
			}
			
			string dataString = buf.base128encode();
			f.Write(dataString);
			println("Rust: Wrote '" + path + "' (" + dataString.Length() + " bytes)");
		}
		else
		{
			f.Remove();
			println("Rust: Deleted " + path);
		}
	}
	else if (g_build_parts.length() > 0)
		println("Failed to open file: " + path);
}

void unlockSaveLoad()
{
	saveLoadInProgress = false;
	for (uint i = 0; i < g_build_parts.length(); i++)
	{
		func_breakable_custom@ ent = cast<func_breakable_custom@>(CastToScriptClass(g_build_parts[i].GetEntity()));
		ent.updateConnections();
	}
}

void loadMapPartial(ByteBuffer@ buf)
{
	for (int partIdx = 0; partIdx < 4 and buf.readPos < buf.data.size(); partIdx++)
	{
		float x = buf.ReadFloat();
		float y = buf.ReadFloat();
		float z = buf.ReadFloat();
		float ax = buf.ReadFloat();
		float ay = buf.ReadFloat();
		float az = buf.ReadFloat();
		Vector origin(x, y, z);
		Vector angles(ax, ay, az);
		int type = buf.ReadInt16();
		int id = buf.ReadInt16();
		int parent = buf.ReadInt16();
		int button = buf.ReadInt16();
		int body = buf.ReadInt16();
		float v1x = buf.ReadFloat();
		float v1y = buf.ReadFloat();
		float v1z = buf.ReadFloat();
		float v2x = buf.ReadFloat();
		float v2y = buf.ReadFloat();
		float v2z = buf.ReadFloat();
		Vector vuser1(v1x, v1y, v1z);
		Vector vuser2(v2x, v2y, v2z);
		float health = buf.ReadFloat();
		string classname = buf.ReadString();
		string model = buf.ReadString();
		int groupinfo = buf.ReadInt16();
		string steamid = buf.ReadString();
		string netname = buf.ReadString();
		string code = buf.ReadString();
		int effects = buf.ReadInt16();
		int itemCount = buf.ReadByte();
		
		if (buf.err != 0)
		{
			println("Rust: Failed to load. Unexpected end of file.");
			return;
		}
		
		dictionary keys;
		keys["origin"] = origin.ToString();
		keys["angles"] = angles.ToString();
		keys["model"] = model;
		keys["health"] = "health";
		keys["material"] = "1";
		keys["target"] = "break_part_script";
		keys["fireonbreak"] = "break_part_script";
		keys["health"] = "100";
		keys["rendermode"] = "4";
		keys["renderamt"] = "255";
		keys["id"] = "" + id;
		keys["parent"] = "" + parent;
		keys["colormap"] = "" + type;
		
		int socket = socketType(type);
		if (socket == SOCKET_DOORWAY or type == B_WOOD_SHUTTERS or type == B_LADDER_HATCH)
		{
			keys["distance"] = "9999";
			keys["speed"] = "0.00000001";
			keys["breakable"] = "1";
			keys["targetname"] = "locked" + id;
			
		}
		if (type == "func_ladder")
		{
			keys["spawnflags"] = "1";
		}
		if (type == B_LADDER)
		{
			keys["rendermode"] = "4";
			keys["renderamt"] = "255";
		}
		
		CBaseEntity@ ent = g_EntityFuncs.CreateEntity(classname, keys, true);
		int zoneid = getBuildZone(ent);
		ent.KeyValue("zoneid", "" + zoneid);
		ent.pev.button = button;
		ent.pev.body = body;
		ent.pev.vuser1 = vuser1;
		ent.pev.vuser2 = vuser2;
		ent.pev.groupinfo = groupinfo;
		ent.pev.noise1 = steamid;
		ent.pev.noise2 = netname;
		ent.pev.noise3 = code;
		ent.pev.team = id;
		ent.pev.effects = effects | EF_NODECALS;
		
		for (int i = 0; i < itemCount; i++)
		{
			int itemType = buf.ReadInt16();
			int itemAmt = buf.ReadInt16();
			if (classname == "func_breakable_custom")
			{
				func_breakable_custom@ chest = cast<func_breakable_custom@>(CastToScriptClass(ent));
				chest.depositItem(itemType, itemAmt);
			}
		}
		
		//g_EntityFuncs.SetSize(ent.pev, ent.pev.mins, ent.pev.maxs);
		//g_EntityFuncs.SetOrigin(ent, ent.pev.origin);
		if (effects & EF_NODRAW != 0)
		{
			ent.pev.solid = SOLID_NOT;
			println("ITS A NODRAW");
		}
		else
		{
			PlayerState@ state = getPlayerStateBySteamID(steamid, netname);
			if (state !is null)
				state.addPart(ent, zoneid);
		}
		
		g_build_parts.insertLast(EHandle(ent));
		
		if (id >= g_part_id)
			g_part_id = id+1;
	}
		
	if (buf.readPos < buf.data.size())
		g_Scheduler.SetTimeout("loadMapPartial", 0.05, @buf);
}

void loadMapData()
{	
	string path = rust_save_path + g_Engine.mapname + ".dat";
	File@ f = g_FileSystem.OpenFile( path, OpenFile::READ);
	
	if( f !is null && f.IsOpen() )
	{
		// clear previous data
		player_states.deleteAll();
		for (uint i = 0; i < g_build_parts.length(); i++)
			g_EntityFuncs.Remove(g_build_parts[i]);
		
		// load parts
		ByteBuffer buf(f);
		uint32 numParts = buf.ReadUInt32();
		if (numParts > 900)
			numParts = 900;
		
		println("Loading " + numParts + " parts");
		
		loadMapPartial(buf);
	}
	else
	{
		println("PortalSpawner: No portal data found for this map");
	}
}
