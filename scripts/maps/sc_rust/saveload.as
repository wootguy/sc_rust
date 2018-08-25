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
		if (g_build_parts.length() > 0 or g_build_zone_ents.length() > 0)
		{
			ByteBuffer buf;
			buf.Write(uint32(g_build_parts.length()));
			for (uint i = 0; i < g_build_parts.length(); i++)
			{
				func_breakable_custom@ ent = cast<func_breakable_custom@>(CastToScriptClass(g_build_parts[i].GetEntity()));
				buf.Write(ent.serialize());
			}
			
			buf.Write(uint16(g_build_zone_ents.length()));
			for (uint i = 0; i < g_build_zone_ents.size(); i++)
			{
				func_build_zone@ zone = cast<func_build_zone@>(CastToScriptClass(g_build_zone_ents[i].GetEntity()));
				
				zone.DeleteNullNodes();
				buf.Write(uint16(zone.nodes.size()));
				if (debug_mode)
					println("prepare to save " + zone.nodes.size() + " nodes");
				for (uint k = 0; k < zone.nodes.size(); k++) 
				{
					CBaseEntity@ node = zone.nodes[k];
					if (@node == null)
						continue;
					uint8 nodeType = NODE_XEN;
					if (node.pev.classname == "func_breakable_custom")
					{
						func_breakable_custom@ nodeBreak = cast<func_breakable_custom@>(CastToScriptClass(node));
						nodeType = nodeBreak.nodeType;
					}
					else if (!node.IsMonster())
						println("Unexpected node type: " + node.pev.classname);
						
					buf.Write(uint8(nodeType));
					if (nodeType == NODE_XEN)
						buf.Write(string(node.pev.classname));
					buf.Write(node.pev.origin.x);
					buf.Write(node.pev.origin.y);
					buf.Write(node.pev.origin.z);
					buf.Write(node.pev.angles.x);
					buf.Write(node.pev.angles.y);
					buf.Write(node.pev.angles.z);
					buf.Write(node.pev.health);
				}
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
		
	saveLoadInProgress = false;
	
	g_PlayerFuncs.SayTextAll(getAnyPlayer(), "Save complete\n");
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

void loadNodesPartial(ByteBuffer@ buf, int zonesLoaded, int numZones, int nodesLoaded, int numNodes)
{
	func_build_zone@ zone = cast<func_build_zone@>(CastToScriptClass(g_build_zone_ents[zonesLoaded].GetEntity()));
	
	for (int nodeIdx = 0; nodeIdx < 1 and nodesLoaded < numNodes and buf.readPos < buf.data.size(); nodeIdx++, nodesLoaded++)
	{
		int nodeType = buf.ReadByte();
		string classname = "func_breakable_custom";
		if (nodeType == NODE_XEN)
			classname = buf.ReadString();
		float x = buf.ReadFloat();
		float y = buf.ReadFloat();
		float z = buf.ReadFloat();
		float ax = buf.ReadFloat();
		float ay = buf.ReadFloat();
		float az = buf.ReadFloat();
		Vector origin(x, y, z);
		Vector angles(ax, ay, az);
		float health = buf.ReadFloat();
		
		if (nodeType == NODE_XEN)
		{
			dictionary keys;
			Vector ori = origin;
			keys["origin"] = ori.ToString();
			keys["angles"] = angles.ToString();
			keys["health"] = "" + health;
			if (g_max_zone_monsters != 0) {
				CBaseEntity@ ent = g_EntityFuncs.CreateEntity(classname, keys, true);
				ent.pev.armortype = g_Engine.time + 10.0f;

				zone.nodes.insertLast(EHandle(ent));
			}
		}
		else
		{
			string brushModel = "";
			string itemModel = "";
			float itemHeight = 0;
			if (nodeType == NODE_TREE)
			{
				brushModel = getModelFromName("e_tree");
				itemModel = "models/sc_rust/pine_tree.mdl";
				itemHeight = 512; // prevents trees from disappearing across hills
			}
			else if (nodeType == NODE_BARREL)
			{
				brushModel = getModelFromName("e_barrel");
				itemModel = "models/sc_rust/tr_barrel.mdl";
				itemHeight = 32;
			}
			else if (nodeType == NODE_ROCK)
			{
				brushModel = getModelFromName("e_rock");
				itemModel = "models/sc_rust/rock.mdl";
				itemHeight = 64;
			}
			else
				println("Build Zone: bad node type: " + nodeType);
		
			string name = "node" + g_node_id++;
			Vector ori = origin;
			
			dictionary keys;
			keys["origin"] = ori.ToString();
			keys["angles"] = angles.ToString();
			keys["model"] = brushModel;
			keys["material"] = "1";
			keys["killtarget"] = name;
			keys["health"] = "" + health;
			keys["colormap"] = "-1";
			keys["message"] = "node";
			keys["nodetype"] = "" + nodeType;
			
			CBaseEntity@ ent = g_EntityFuncs.CreateEntity("func_breakable_custom", keys, true);
			zone.nodes.insertLast(EHandle(ent));
			
			ori.z += itemHeight;
			keys["origin"] = ori.ToString();
			keys["model"] = fixPath(itemModel);
			keys["movetype"] = "5";
			keys["scale"] = "1";
			keys["sequencename"] = "idle";
			keys["targetname"] = name;
			CBaseEntity@ ent2 = g_EntityFuncs.CreateEntity("item_generic", keys, true);
			ent2.pev.movetype = MOVETYPE_NONE; // epic lag without this
		}
		
		if (buf.err != 0)
		{
			println("Rust: Failed to load. Unexpected end of file.");
			return;
		}
	}
	
	if (buf.readPos < buf.data.size())
	{
		if (nodesLoaded >= numNodes) {
			println("loaded " + numNodes + " into zone idx " + zonesLoaded);
			nodesLoaded = 0;
			numNodes = buf.ReadUInt16();
			zonesLoaded++;
			zone.Enable();
			//println("Prepare to load " + numNodes + " nodes from zone " + zonesLoaded);
		}
		if (zonesLoaded < numZones)
			g_Scheduler.SetTimeout("loadNodesPartial", 0.0, @buf, zonesLoaded, numZones, nodesLoaded, numNodes);
		else
		{
			saveLoadInProgress = false;
			g_PlayerFuncs.SayTextAll(getAnyPlayer(), "Load complete\n");
		}
	}
	else
	{
		saveLoadInProgress = false;
		g_PlayerFuncs.SayTextAll(getAnyPlayer(), "Load complete\n");
	}
}

void loadMapPartial(ByteBuffer@ buf, int partsLoaded, int numParts)
{
	for (int partIdx = 0; partIdx < 1 and partsLoaded < numParts and buf.readPos < buf.data.size(); partIdx++, partsLoaded++)
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
		float max_health = buf.ReadFloat();
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
		keys["material"] = "1";
		keys["target"] = "break_part_script";
		keys["fireonbreak"] = "break_part_script";
		keys["health"] = "" + health;
		keys["max_health"] = "" + max_health;
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
		
		int authCount = buf.ReadByte();
		for (int i = 0; i < authCount; i++) {
			string authid = buf.ReadString();
			PlayerState@ state = getPlayerStateBySteamID(authid, authid);
			if (state !is null)
				state.authedLocks.insertLast(EHandle(ent));
		}
		
		
		//g_EntityFuncs.SetSize(ent.pev, ent.pev.mins, ent.pev.maxs);
		//g_EntityFuncs.SetOrigin(ent, ent.pev.origin);
		if (effects & EF_NODRAW != 0)
		{
			ent.pev.solid = SOLID_NOT;
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
	{
		if (partsLoaded < numParts)
			g_Scheduler.SetTimeout("loadMapPartial", 0.0, @buf, partsLoaded, numParts);
		else
		{
			uint32 numZones = buf.ReadUInt16();
			uint32 numNodes = buf.ReadUInt16();
			println("Loading " + numZones + " zones");
			g_Scheduler.SetTimeout("loadNodesPartial", 0.0, @buf, 0, numZones, 0, numNodes);
		}
	}
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
		
		for (uint i = 0; i < g_build_zone_ents.size(); i++)
		{
			func_build_zone@ zone = cast<func_build_zone@>(CastToScriptClass(g_build_zone_ents[i].GetEntity()));
			zone.Clear();
			zone.Disable();
		}
		
		// load parts
		ByteBuffer buf(f);
		uint32 numParts = buf.ReadUInt32();
		
		println("Loading " + numParts + " parts from " + path);
		
		loadMapPartial(buf, 0, numParts);
	}
	else
	{
		println("PortalSpawner: No portal data found for this map");
	}
}
