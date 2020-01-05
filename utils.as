class Color
{ 
	uint8 r, g, b, a;
	Color() { r = g = b = a = 0; }
	Color(uint8 r, uint8 g, uint8 b) { this.r = r; this.g = g; this.b = b; this.a = 255; }
	Color(uint8 r, uint8 g, uint8 b, uint8 a) { this.r = r; this.g = g; this.b = b; this.a = a; }
	Color(float r, float g, float b, float a) { this.r = uint8(r); this.g = uint8(g); this.b = uint8(b); this.a = uint8(a); }
	Color (Vector v) { this.r = uint8(v.x); this.g = uint8(v.y); this.b = uint8(v.z); this.a = 255; }
	string ToString() { return "" + r + " " + g + " " + b + " " + a; }
	Vector getRGB() { return Vector(r, g, b); }
}

Color RED    = Color(255,0,0);
Color GREEN  = Color(0,255,0);
Color BLUE   = Color(0,0,255);
Color YELLOW = Color(255,255,0);
Color ORANGE = Color(255,127,0);
Color PURPLE = Color(127,0,255);
Color PINK   = Color(255,0,127);
Color TEAL   = Color(0,255,255);
Color WHITE  = Color(255,255,255);
Color BLACK  = Color(0,0,0);
Color GRAY  = Color(127,127,127);

void print(string text) { g_Game.AlertMessage( at_console, text); }
void println(string text) { print(text + "\n"); }

void debug(string text) { if (debug_mode) print(text); }
void debugln(string text) { if (debug_mode) println(text); }

void te_projectile(Vector pos, Vector velocity, CBaseEntity@ owner=null, 
	string model="models/grenade.mdl", uint8 life=1, 
	NetworkMessageDest msgType=MSG_BROADCAST, edict_t@ dest=null)
{
	int ownerId = owner is null ? 0 : owner.entindex();
	NetworkMessage m(msgType, NetworkMessages::SVC_TEMPENTITY, dest);
	m.WriteByte(TE_PROJECTILE);
	m.WriteCoord(pos.x);
	m.WriteCoord(pos.y);
	m.WriteCoord(pos.z);
	m.WriteCoord(velocity.x);
	m.WriteCoord(velocity.y);
	m.WriteCoord(velocity.z);
	m.WriteShort(g_EngineFuncs.ModelIndex(model));
	m.WriteByte(life);
	m.WriteByte(ownerId);
	m.End();
}
void te_model(Vector pos, Vector velocity, float yaw=0, 
	string model="models/agibs.mdl", uint8 bounceSound=2, uint8 life=32,
	NetworkMessageDest msgType=MSG_BROADCAST, edict_t@ dest=null)
{

	NetworkMessage m(msgType, NetworkMessages::SVC_TEMPENTITY, dest);
	m.WriteByte(TE_MODEL);
	m.WriteCoord(pos.x);
	m.WriteCoord(pos.y);
	m.WriteCoord(pos.z);
	m.WriteCoord(velocity.x);
	m.WriteCoord(velocity.y);
	m.WriteCoord(velocity.z);
	m.WriteAngle(yaw);
	m.WriteShort(g_EngineFuncs.ModelIndex(model));
	m.WriteByte(bounceSound);
	m.WriteByte(life);
	m.End();
}
void te_blood(Vector pos, Vector dir, uint8 color=70, uint8 speed=16,
	NetworkMessageDest msgType=MSG_BROADCAST, edict_t@ dest=null)
{
	NetworkMessage m(msgType, NetworkMessages::SVC_TEMPENTITY, dest);
	m.WriteByte(TE_BLOOD);
	m.WriteCoord(pos.x);
	m.WriteCoord(pos.y);
	m.WriteCoord(pos.z);
	m.WriteCoord(dir.x);
	m.WriteCoord(dir.y);
	m.WriteCoord(dir.z);
	m.WriteByte(color);
	m.WriteByte(speed);
	m.End();
}
void te_trail(CBaseEntity@ target, string sprite="sprites/laserbeam.spr", 
	uint8 life=100, uint8 width=2, Color c=PURPLE,
	NetworkMessageDest msgType=MSG_BROADCAST, edict_t@ dest=null)
{
	NetworkMessage m(msgType, NetworkMessages::SVC_TEMPENTITY, dest);
	m.WriteByte(TE_BEAMFOLLOW);
	m.WriteShort(target.entindex());
	m.WriteShort(g_EngineFuncs.ModelIndex(sprite));
	m.WriteByte(life);
	m.WriteByte(width);
	m.WriteByte(c.r);
	m.WriteByte(c.g);
	m.WriteByte(c.b);
	m.WriteByte(c.a);
	m.End();
}
void te_killbeam(CBaseEntity@ target, 
	NetworkMessageDest msgType=MSG_BROADCAST, edict_t@ dest=null)
{
	NetworkMessage m(msgType, NetworkMessages::SVC_TEMPENTITY, dest);
	m.WriteByte(TE_KILLBEAM);
	m.WriteShort(target.entindex());
	m.End();
}
void te_beampoints(Vector start, Vector end, string sprite="sprites/laserbeam.spr", uint8 frameStart=0, uint8 frameRate=100, uint8 life=20, uint8 width=2, uint8 noise=0, Color c=GREEN, uint8 scroll=32, NetworkMessageDest msgType=MSG_BROADCAST, edict_t@ dest=null) { NetworkMessage m(msgType, NetworkMessages::SVC_TEMPENTITY, dest);m.WriteByte(TE_BEAMPOINTS);m.WriteCoord(start.x);m.WriteCoord(start.y);m.WriteCoord(start.z);m.WriteCoord(end.x);m.WriteCoord(end.y);m.WriteCoord(end.z);m.WriteShort(g_EngineFuncs.ModelIndex(sprite));m.WriteByte(frameStart);m.WriteByte(frameRate);m.WriteByte(life);m.WriteByte(width);m.WriteByte(noise);m.WriteByte(c.r);m.WriteByte(c.g);m.WriteByte(c.b);m.WriteByte(c.a);m.WriteByte(scroll);m.End(); }
void te_breakmodel(Vector pos, Vector size, Vector velocity, uint8 speedNoise=16, string model="models/hgibs.mdl", uint8 count=8, uint8 life=0, uint8 flags=20, NetworkMessageDest msgType=MSG_BROADCAST, edict_t@ dest=null) { NetworkMessage m(msgType, NetworkMessages::SVC_TEMPENTITY, dest);m.WriteByte(TE_BREAKMODEL);m.WriteCoord(pos.x);m.WriteCoord(pos.y);m.WriteCoord(pos.z);m.WriteCoord(size.x);m.WriteCoord(size.y);m.WriteCoord(size.z);m.WriteCoord(velocity.x);m.WriteCoord(velocity.y);m.WriteCoord(velocity.z);m.WriteByte(speedNoise);m.WriteShort(g_EngineFuncs.ModelIndex(model));m.WriteByte(count);m.WriteByte(life);m.WriteByte(flags);m.End(); }
void te_bloodsprite(Vector pos, string sprite1="sprites/bloodspray.spr", string sprite2="sprites/blood.spr", uint8 color=70, uint8 scale=3, NetworkMessageDest msgType=MSG_BROADCAST, edict_t@ dest=null) { NetworkMessage m(msgType, NetworkMessages::SVC_TEMPENTITY, dest);m.WriteByte(TE_BLOODSPRITE);m.WriteCoord(pos.x);m.WriteCoord(pos.y);m.WriteCoord(pos.z);m.WriteShort(g_EngineFuncs.ModelIndex(sprite1));m.WriteShort(g_EngineFuncs.ModelIndex(sprite2));m.WriteByte(color);m.WriteByte(scale);m.End(); }
void te_smoke(Vector pos, string sprite="sprites/steam1.spr", int scale=10, int frameRate=15, NetworkMessageDest msgType=MSG_BROADCAST, edict_t@ dest=null) { NetworkMessage m(msgType, NetworkMessages::SVC_TEMPENTITY, dest);m.WriteByte(TE_SMOKE);m.WriteCoord(pos.x);m.WriteCoord(pos.y);m.WriteCoord(pos.z);m.WriteShort(g_EngineFuncs.ModelIndex(sprite));m.WriteByte(scale);m.WriteByte(frameRate);m.End(); }
void te_sparks(Vector pos, NetworkMessageDest msgType=MSG_BROADCAST, edict_t@ dest=null) { _te_pointeffect(pos, msgType, dest, TE_SPARKS); }
void _te_pointeffect(Vector pos, NetworkMessageDest msgType=MSG_BROADCAST, edict_t@ dest=null, int effect=TE_SPARKS) { NetworkMessage m(msgType, NetworkMessages::SVC_TEMPENTITY, dest);m.WriteByte(effect);m.WriteCoord(pos.x);m.WriteCoord(pos.y);m.WriteCoord(pos.z);m.End(); }
void te_sprite(Vector pos, string sprite="sprites/zerogxplode.spr", 
	uint8 scale=10, uint8 alpha=200, 
	NetworkMessageDest msgType=MSG_BROADCAST, edict_t@ dest=null)
{
	NetworkMessage m(msgType, NetworkMessages::SVC_TEMPENTITY, dest);
	m.WriteByte(TE_SPRITE);
	m.WriteCoord(pos.x);
	m.WriteCoord(pos.y);
	m.WriteCoord(pos.z);
	m.WriteShort(g_EngineFuncs.ModelIndex(sprite));
	m.WriteByte(scale);
	m.WriteByte(alpha);
	m.End();
}
void te_dlight(Vector pos, uint8 radius=16, Color c=PURPLE, uint8 life=255, uint8 decayRate=4, NetworkMessageDest msgType=MSG_BROADCAST, edict_t@ dest=null) { NetworkMessage m(msgType, NetworkMessages::SVC_TEMPENTITY, dest);m.WriteByte(TE_DLIGHT);m.WriteCoord(pos.x);m.WriteCoord(pos.y);m.WriteCoord(pos.z);m.WriteByte(radius);m.WriteByte(c.r);m.WriteByte(c.g);m.WriteByte(c.b);m.WriteByte(life);m.WriteByte(decayRate);m.End(); }
void te_elight(CBaseEntity@ target, Vector pos, float radius=1024.0f, 
	Color c=PURPLE, uint8 life=16, float decayRate=2000.0f, 
	NetworkMessageDest msgType=MSG_BROADCAST, edict_t@ dest=null)
{
	NetworkMessage m(msgType, NetworkMessages::SVC_TEMPENTITY, dest);
	m.WriteByte(TE_ELIGHT);
	m.WriteShort(target.entindex());
	m.WriteCoord(pos.x);
	m.WriteCoord(pos.y);
	m.WriteCoord(pos.z);
	m.WriteCoord(radius);
	m.WriteByte(c.r);
	m.WriteByte(c.g);
	m.WriteByte(c.b);
	m.WriteByte(life);
	m.WriteCoord(decayRate);
	m.End();
}

// convert output from Vector.ToString() back into a Vector
Vector parseVector(string s) {
	array<string> values = s.Split(" ");
	Vector v(0,0,0);
	if (values.length() > 0) v.x = atof( values[0] );
	if (values.length() > 1) v.y = atof( values[1] );
	if (values.length() > 2) v.z = atof( values[2] );
	return v;
}

void build_effect(Vector origin) {
	te_smoke(origin, "sprites/black_smoke3.spr", 10, 50);
				
	float j = 48;
	for (uint z = 0; z < 8; z++) {
		Vector jitter = Vector(Math.RandomFloat(-j, j), Math.RandomFloat(-j, j), Math.RandomFloat(-j, j));
		te_smoke(origin + jitter, g_puff_sprites[Math.RandomLong(0,g_puff_sprites.size()-1)], 20, 50);
	}
}

Vector2D getPerp(Vector2D v) {
	return Vector2D(-v.y, v.x);
}

bool vecEqual(Vector v1, Vector v2)
{
	return abs(v1.x - v2.x) < EPSILON and abs(v1.y - v2.y) < EPSILON and abs(v1.z - v2.z) < EPSILON;
}

CBaseEntity@ getPartAtPos(Vector pos, float dist=2)
{
	CBaseEntity@ ent = null;
	do {
		@ent = g_EntityFuncs.FindEntityInSphere(ent, pos, dist, "func_breakable_custom", "classname");
		if (ent !is null)
		{
			return ent;
		}
	} while (ent !is null);
	return null;
	/*
	// slower even without sqrt
	float d = dist*dist;
	for (uint i = 0; i < g_build_parts.length(); i++)
	{
		if (g_build_parts[i].ent)
		{
			CBaseEntity@ ent = g_build_parts[i].ent;
			
			if ((ent.pev.origin - pos).Length() < dist)
			{
				return ent;
			}
		}
	}
	return null;
	*/
}

func_breakable_custom@ castToPart(EHandle h_ent)
{
	return cast<func_breakable_custom@>(CastToScriptClass(h_ent.GetEntity()));
}

func_breakable_custom@ getBuildPartByID(int id)
{
	for (uint i = 0; i < g_build_parts.size(); i++)
	{
		if (!g_build_parts[i].IsValid())
			continue;
		func_breakable_custom@ part = cast<func_breakable_custom@>(CastToScriptClass(g_build_parts[i].GetEntity()));
		if (part !is null and part.id == id)
		{
			return @part;
		}
	}
	return null;
}

int getBuildZone(CBaseEntity@ ent)
{
	for (uint i = 0; i < g_build_zone_ents.length(); i++)
	{
		if (!g_build_zone_ents[i])
			continue;
			
		CBaseEntity@ zone = g_build_zone_ents[i];
		func_build_zone@ zoneent = cast<func_build_zone@>(CastToScriptClass(zone));
		if (zoneent.IntersectsZone(ent))
			return zoneent.id;
	}
	return -1;
}

// any valid point in a build zone
Vector getRandomPosition()
{	
	CBaseEntity@ zone = g_build_zone_ents[Math.RandomLong(0,  g_build_zone_ents.length()-1)];
	if (g_invasion_mode)
		@zone = g_invasion_zone.GetEntity();
	
	func_build_zone@ zoneent = cast<func_build_zone@>(CastToScriptClass(zone));
	
	return zoneent.getRandomPosition();
}

BuildZone@ getBuildZone(int id)
{
	for (uint i = 0; i < g_build_zones.length(); i++)
	{
		if (g_build_zones[i].id == id)
			return @g_build_zones[i];
	}
	return null;
}

void printVisibleEnts(CBaseEntity@ ent)
{
	int count = 0;
	edict_t@ edt = g_EngineFuncs.EntitiesInPVS(ent.edict());
	while (edt !is null)
	{
		CBaseEntity@ next = g_EntityFuncs.Instance( edt );
		if (next !is null)
		{
			@edt = @next.pev.chain;
			if (next.pev.effects & EF_NODRAW == 0 and string(next.pev.model).Length() > 0)
			{
				println("" + next.pev.classname + " " + next.pev.targetname);
				count++;
			}
		}
	}
	println("Total Visible Ents: " + count);
}

array<EHandle> getPartsByID(int id)
{
	array<EHandle> ents;
	for (uint i = 0; i < g_build_parts.size(); i++)
	{	
		func_breakable_custom@ part = cast<func_breakable_custom@>(CastToScriptClass(g_build_parts[i].GetEntity()));
		if (part !is null and part.id == id) 
			ents.insertLast(g_build_parts[i]);
	}
	for (uint i = 0; i < g_build_items.size(); i++)
	{	
		CBaseEntity@ part = g_build_items[i].GetEntity();
		if (part !is null and part.pev.team == id) 
			ents.insertLast(g_build_items[i]);
	}
	return ents;
}

array<EHandle> getPartsByOwner(CBasePlayer@ plr)
{		
	string authid = g_EngineFuncs.GetPlayerAuthId( plr.edict() );
	string netname = plr.pev.netname;
		
	array<EHandle> ents;
	for (uint i = 0; i < g_build_parts.size(); i++)
	{	
		func_breakable_custom@ part = cast<func_breakable_custom@>(CastToScriptClass(g_build_parts[i].GetEntity()));
		if (part !is null and ((authid == part.pev.noise1 and authid != "STEAM_ID_LAN") or (authid == "STEAM_ID_LAN" and netname == part.pev.noise2)) ) 
			ents.insertLast(g_build_parts[i]);
	}
	for (uint i = 0; i < g_build_items.size(); i++)
	{	
		CBaseEntity@ part = g_build_items[i].GetEntity();
		if (part !is null and ((authid == part.pev.noise1 and authid != "STEAM_ID_LAN") or (authid == "STEAM_ID_LAN" and netname == part.pev.noise2)) ) 
			ents.insertLast(g_build_items[i]);
	}
	return ents;
}

array<EHandle> getPartsByParent(int parent)
{
	array<EHandle> ents;
	for (uint i = 0; i < g_build_parts.size(); i++)
	{	
		func_breakable_custom@ part = cast<func_breakable_custom@>(CastToScriptClass(g_build_parts[i].GetEntity()));
		if (part !is null and part.parent == parent)
			ents.insertLast(g_build_parts[i]);
	}
	return ents;
}

void deleteNullBoats()
{
	for (uint i = 0; i < g_boats.size(); i++)
	{
		if (!g_boats[i].IsValid())
		{
			g_boats.removeAt(i);
			i--;
		}
	}
}

void deleteExtraBoats()
{
	deleteNullBoats();
	if (g_boats.size() < 32)
		return; // no need to clean up yet
		
	for (uint i = 0; i < g_boats.size(); i++)
	{
		CBaseEntity@ boat = g_boats[i].GetEntity();
		PlayerState@ state = getPlayerStateBySteamID(boat.pev.noise1, boat.pev.noise2);
		if (state is null or state.inGame == false)
		{
			boat.TakeDamage(boat.pev, boat.pev, boat.pev.health, DMG_GENERIC);
		}
	}
}

CBaseEntity@ getBoatByOwner(CBasePlayer@ plr)
{
	string authid = g_EngineFuncs.GetPlayerAuthId( plr.edict() );
	string netname = plr.pev.netname;
	
	deleteNullBoats();
	
	array<EHandle> ents;
	for (uint i = 0; i < g_boats.size(); i++)
	{
		CBaseEntity@ boat = g_boats[i].GetEntity();
		if (boat !is null and ((authid == boat.pev.noise1 and authid != "STEAM_ID_LAN") or (authid == "STEAM_ID_LAN" and netname == boat.pev.noise2)) ) 
			return boat;
	}
	return null;
}

string getModelName(CBaseEntity@ part)
{
	if (part is null)
		return "NULL";
	string name;
	g_partname_to_model.get(string(part.pev.model), name);
	return name;
}

string prettyPartName(CBaseEntity@ part)
{
	if (part is null)
		return "NULL";
	string modelName = getModelName(part);
		
	string size = "";
	if (int(modelName.Find("_1x2")) > 0) size = " (1x2)";
	if (int(modelName.Find("_1x3")) > 0) size = " (1x3)";
	if (int(modelName.Find("_1x4")) > 0) size = " (1x4)";
	if (int(modelName.Find("_2x1")) > 0) size = " (2x1)";
	if (int(modelName.Find("_2x2")) > 0) size = " (2x2)";
	if (int(modelName.Find("_3x1")) > 0) size = " (3x1)";
	if (int(modelName.Find("_4x1")) > 0) size = " (4x1)";
	
	string bestTitle = "";
	int bestLen = 0;
	for (uint i = 0; i < g_part_info.length(); i++)
	{
		if (modelName.Find(g_part_info[i].copy_ent) == 0 and int(g_part_info[i].copy_ent.Length()) > bestLen)
		{
			bestTitle = g_part_info[i].title;
			bestLen = g_part_info[i].copy_ent.Length();
		}
	}
	
	if (int(modelName.Find("shutter")) != -1)
		bestTitle = g_part_info[B_WOOD_SHUTTERS].title;
	
	string owner = "";

	if (part.pev.colormap == B_BED or part.pev.colormap == E_BOAT_WOOD or part.pev.colormap == E_BOAT_METAL)
	{
		PlayerState@ state = getPlayerStateBySteamID(part.pev.noise1, part.pev.noise2);
		if (state !is null and state.plr.IsValid())
			owner = " (" + state.plr.GetEntity().pev.netname + ")";
	}
	
	return bestTitle + size + owner;
}

string getModelFromName(string partName)
{
	string model;
	g_model_to_partname.get(partName, model);
	return model;
}

bool isMeleeWeapon(string wepName)
{
	if (wepName == "weapon_rock") return true;
	if (wepName == "weapon_stone_hatchet") return true;
	if (wepName == "weapon_metal_hatchet") return true;
	if (wepName == "weapon_stone_pickaxe") return true;
	if (wepName == "weapon_metal_pickaxe") return true;
	if (wepName == "weapon_crowbar") return true;
	if (wepName == "weapon_custom_crowbar") return true;
	if (wepName == "weapon_wrench") return true;
	if (wepName == "weapon_grapple") return true;
	
	return false;
}

Item@ getItemByClassname(string cname)
{
	for (uint i = 0; i < g_items.size(); i++)
	{
		if (cname == g_items[i].classname or cname == g_items[i].ammoName)
			return @g_items[i];
	}
	return null;
}

void printItemCost(CBasePlayer@ plr, int type, int amt, float duration=0.5f)
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
	params.holdTime = duration;
	params.channel = 2;
	HudMessage(plr, params, "" + amt + " " + g_items[type].title);
}

void clearInventory(CBasePlayer@ plr)
{	
	CBaseEntity@ ent = null;
	do {
		@ent = g_EntityFuncs.FindEntityByClassname(ent, "item_inventory");
		if (ent !is null) {
			CBaseEntity@ owner = g_EntityFuncs.Instance( ent.pev.owner );
			if (owner !is null and owner.entindex() == plr.entindex())
			{
				//println("OWNER IS " + owner.pev.netname);
				ent.pev.renderfx = -9999;
				g_Scheduler.SetTimeout("delay_remove", 0, EHandle(ent));
			}			
		}
	} while (ent !is null);
}

int getItemCount(CBasePlayer@ plr, int itemType, bool includeEquipment = true, bool includeInventory = true)
{
	if (itemType < 0 or itemType >= int(g_items.size()))
		return 0;
		
	Item@ checkItem = g_items[itemType];
	int count = 0;
	
	if (includeInventory)
	{
		InventoryList@ inv = plr.get_m_pInventory();
		while (inv !is null)
		{
			CItemInventory@ item = cast<CItemInventory@>(inv.hItem.GetEntity());
			if (item !is null and item.pev.colormap-1 == itemType and item.pev.renderfx != -9999)
				count += checkItem.stackSize > 1 ? item.pev.button : 1;
			@inv = inv.pNext;
		}
	}
	
	if (includeEquipment and (checkItem.isWeapon or checkItem.isAmmo or checkItem.type == I_ARMOR))
	{
		if (checkItem.type == I_ARMOR)
			count += int(plr.pev.armorvalue / ARMOR_VALUE);
		else if (checkItem.isAmmo or checkItem.stackSize > 1)
		{
			string ammoName = checkItem.classname;
			if (checkItem.stackSize > 1 and !checkItem.isAmmo)
				ammoName = checkItem.ammoName;
			count += plr.m_rgAmmo(g_PlayerFuncs.GetAmmoIndex(ammoName));
		}
		else if (checkItem.isWeapon)
		{
			if (@plr.HasNamedPlayerItem(checkItem.classname) !is null)
				count += 1;
		}
	}
	
	return count;
}

array<Item@> getAllItems(CBasePlayer@ plr)
{
	array<Item@> all_items;
	
	array<RawItem> raw_items = getAllItemsRaw(plr);
	for (uint i = 0; i < raw_items.size(); i++)
		all_items.insertLast(g_items[raw_items[i].type]);
	
	// remove duplicates
	array<Item@> ret_items;
	dictionary unique_items;
	for (uint i = 0; i < all_items.size(); i++)
	{
		if (unique_items.exists(all_items[i].type))
			continue;
		unique_items[all_items[i].type] = true;
		ret_items.insertLast(all_items[i]);
	}
	
	return ret_items;
}

array<RawItem> getAllItemsRaw(CBasePlayer@ plr)
{
	array<RawItem> all_items;
	
	// held weapons/items
	for (uint i = 0; i < MAX_ITEM_TYPES; i++)
	{
		CBasePlayerItem@ item = plr.m_rgpPlayerItems(i);
		while (item !is null)
		{
			Item@ invItem = getItemByClassname(item.pev.classname);
			if (invItem !is null)
			{
				int amt = 1;
				if (invItem.isWeapon) {
					amt = cast<CBasePlayerWeapon@>(item).m_iClip;
					if (invItem.type == I_SYRINGE or invItem.type == I_C4 or invItem.type == I_SATCHEL or invItem.type == I_GRENADE) {
						amt = plr.m_rgAmmo(g_PlayerFuncs.GetAmmoIndex(invItem.ammoName));
					}
				}
				all_items.insertLast(RawItem(invItem.type, amt));
			}
			@item = cast<CBasePlayerItem@>(item.m_hNextItem.GetEntity());		
		}
	}
	
	// held ammo
	dictionary stacks;
	for (uint i = 0; i < WeaponCustom::g_ammo_types.size(); i++)
	{
		bool dont_show = false;
		for (uint k = 0; k < g_items.size(); k++) // unequip as a weapon only, not as ammo
		{
			if (g_items[k].ammoName == WeaponCustom::g_ammo_types[i])
			{
				dont_show = true;
				break;
			}
		}
		if (dont_show)
			continue;
		
		int ammoIdx = g_PlayerFuncs.GetAmmoIndex(WeaponCustom::g_ammo_types[i]);
		if (ammoIdx == -1)
			continue;
		int ammo = plr.m_rgAmmo(ammoIdx);
		if (ammo > 0)
		{
			Item@ item = getItemByClassname(WeaponCustom::g_ammo_types[i]);
			if (item !is null)
				stacks[item.type] = ammo;
		}
	}
	
	// equipped armor
	if (plr.pev.armorvalue >= ARMOR_VALUE)
		stacks[I_ARMOR] = plr.pev.armorvalue / ARMOR_VALUE;
	
	// inventory items
	InventoryList@ inv = plr.get_m_pInventory();
	while(inv !is null)
	{
		CItemInventory@ item = cast<CItemInventory@>(inv.hItem.GetEntity());
		if (item !is null and item.pev.colormap > 0)
		{
			Item@ wep = g_items[item.pev.colormap-1];
			if (wep !is null)
			{
				if (wep.stackSize > 1)
				{
					if (stacks.exists(wep.type))
					{
						int oldCount = 0;
						stacks.get(wep.type, oldCount);
						stacks[wep.type] = oldCount + item.pev.button;
					}
					else
						stacks[wep.type] = item.pev.button;	
				}
				else
					all_items.insertLast(RawItem(wep.type, 1));
			}
		}
		@inv = inv.pNext;
	}
	
	array<string>@ stackKeys = stacks.getKeys();
	for (uint i = 0; i < stackKeys.size(); i++)
	{
		Item@ item = g_items[ atoi(stackKeys[i]) ];
		int amt = 1;
		stacks.get(stackKeys[i], amt);
		all_items.insertLast(RawItem(item.type, amt));
	}
	
	return all_items;
}

// get the first item of this type
CItemInventory@ getInventoryItem(CBasePlayer@ plr, int type)
{
	InventoryList@ inv = plr.get_m_pInventory();
	while (inv !is null)
	{
		CItemInventory@ wep = cast<CItemInventory@>(inv.hItem.GetEntity());
		@inv = inv.pNext;
		if (wep.pev.colormap-1 == type)
			return @wep;
	}
	return null;
}

int getInventorySpace(CBasePlayer@ plr)
{
	InventoryList@ inv = plr.get_m_pInventory();
	int slotsUsed = 0;
	while (inv !is null)
	{
		CItemInventory@ item = cast<CItemInventory@>(inv.hItem.GetEntity());
		@inv = inv.pNext;
		if (item !is null and item.pev.renderfx != -9999)
			slotsUsed++;
	}
	return g_inventory_size - slotsUsed;
}

string prettyNumber(int number)
{
	string pretty = "";
	int i = 0;
	while (number > 0)
	{
		int tens = number % 10;
		number /= 10;
		pretty = "" + tens + pretty;
		if (i++ % 3 == 2 and number > 0)
			pretty = "," + pretty;
	}
	return pretty;
}

string getItemDisplayName(CBasePlayer@ plr, CBaseEntity@ item)
{
	if (item.pev.classname == "player_corpse" or item.IsPlayer())
	{
		return translate(plr, "{player_corpse}", item.pev.netname);
	}
	int type = item.pev.colormap-1;
	if (type >= 0 and type < ITEM_TYPES)
	{
		string name = g_items[type].title;
		if (g_items[type].stackSize > 1)
			name += "  (" + prettyNumber(item.pev.button) + ")";
		return translate(plr, name);	
	}
	else
	{
		for (uint i = 0; i < ITEM_TYPES; i++)
		{
			if (g_items[i].classname == item.pev.classname)
				return translate(plr, g_items[i].title);
		}
	}
	return item.pev.classname;
}

string getModelSize(CBaseEntity@ part)
{
	string modelName = getModelName(part);
	if (int(modelName.Find("_1x2")) > 0) return "_1x2";
	if (int(modelName.Find("_1x3")) > 0) return "_1x3";
	if (int(modelName.Find("_1x4")) > 0) return "_1x4";
	if (int(modelName.Find("_2x1")) > 0) return "_2x1";
	if (int(modelName.Find("_2x2")) > 0) return "_2x2";
	if (int(modelName.Find("_3x1")) > 0) return "_3x1";
	if (int(modelName.Find("_4x1")) > 0) return "_4x1";
	
	return "_1x1";
}

string getMaterialType(CBaseEntity@ ent)
{
	string material = "_twig";
	string modelName = getModelName(ent);
	if (int(modelName.Find("_wood")) > 0)
		material = "_wood";
	if (int(modelName.Find("_stone")) > 0 or
		int(modelName.Find("furnace")) > 0)
		material = "_stone";
	if (int(modelName.Find("_metal")) > 0 or 
		int(modelName.Find("ladder_hatch")) > 0)
		material = "_metal";
	if (int(modelName.Find("_armor")) > 0)
		material = "_armor";
		
	return material;
}

int getMaterialTypeInt(CBaseEntity@ ent)
{
	string smat = getMaterialType(ent);
	int mat = -1;
	if (smat == "_wood") mat = 0;
	if (smat == "_stone") mat = 1;
	if (smat == "_metal") mat = 2;
	if (smat == "_armor") mat = 3;
	return mat;
}

int getModelSizei(CBaseEntity@ part)
{
	string modelName = getModelName(part);
	if (int(modelName.Find("_1x2")) > 0) return 2;
	if (int(modelName.Find("_1x3")) > 0) return 3;
	if (int(modelName.Find("_1x4")) > 0) return 4;
	if (int(modelName.Find("_2x1")) > 0) return 2;
	if (int(modelName.Find("_2x2")) > 0) return 4;
	if (int(modelName.Find("_3x1")) > 0) return 3;
	if (int(modelName.Find("_4x1")) > 0) return 4;
	return 1;
}

CBaseEntity@ respawnPart(int id)
{
	CBaseEntity@ lastEnt = null;
	for (uint i = 0; i < g_build_parts.size(); i++)
	{	
		func_breakable_custom@ part = cast<func_breakable_custom@>(CastToScriptClass(g_build_parts[i].GetEntity()));
		if (part !is null and part.id == id) 
		{
			dictionary keys;
			keys["origin"] = part.pev.origin.ToString();
			keys["model"] = string(part.pev.model);
			keys["material"] = "1";
			keys["target"] = "break_part_script";
			keys["fireonbreak"] = "break_part_script";
			keys["rendermode"] = "" + part.pev.rendermode;
			keys["renderamt"] = "" + part.pev.renderamt;
			keys["id"] = "" + id;
			keys["parent"] = "" + part.parent;
			keys["zoneid"] = "" + part.zoneid;
			keys["spawnflags"] = "" + part.pev.spawnflags;
			
			int type = part.pev.colormap;
			int socket = socketType(type);
			if (socket == SOCKET_DOORWAY or type == B_WOOD_SHUTTERS or type == B_LADDER_HATCH)
			{
				keys["distance"] = "9999";
				keys["speed"] = "0.00000001";
				keys["breakable"] = "1";
				if (type == B_LADDER_HATCH)
					keys["targetname"] = string(part.pev.targetname); // probably can just always do this but too afraid to break something
				else
					keys["targetname"] = "locked" + id;
			}
			
			CBaseEntity@ ent = g_EntityFuncs.CreateEntity(part.pev.classname, keys, true);
			ent.pev.angles = part.pev.angles;
			ent.pev.team = part.pev.team;
			ent.pev.button = part.pev.button;
			ent.pev.body = part.pev.body;
			ent.pev.vuser1 = part.pev.vuser1;
			ent.pev.vuser2 = part.pev.vuser2;
			ent.pev.groupinfo = part.pev.groupinfo;
			ent.pev.noise1 = part.pev.noise1;
			ent.pev.noise2 = part.pev.noise2;
			ent.pev.noise3 = part.pev.noise3;
			ent.pev.health = part.pev.health;
			ent.pev.max_health = part.pev.max_health;
			ent.pev.colormap = part.pev.colormap;
			
			//g_EntityFuncs.SetSize(ent.pev, ent.pev.mins, ent.pev.maxs); // fixes collision somehow :S
			
			g_EntityFuncs.Remove(g_build_parts[i]);
			g_build_parts[i] = ent;
			@lastEnt = @ent;
		}
	}
	
	return lastEnt;
}

void breakPart(EHandle h_ent)
{
	if (!h_ent)
		return;
	CBaseEntity@ ent = h_ent;
	ent.TakeDamage(ent.pev, ent.pev, ent.pev.health, 0);
}

// which type of part does this part attach to?
int socketType(int partType)
{				
	switch(partType)
	{
		case B_FOUNDATION: case B_FOUNDATION_STEPS: case B_FOUNDATION_TRI:
			return SOCKET_FOUNDATION;
			
		case B_WALL: case B_WINDOW: case B_DOORWAY: case B_LOW_WALL:
			return SOCKET_WALL;
		
		case B_STAIRS: case B_STAIRS_L:
			return SOCKET_MIDDLE;
		
		case B_WOOD_DOOR: case B_METAL_DOOR:
			return SOCKET_DOORWAY;
			
		case B_WOOD_BARS: case B_METAL_BARS: case B_WOOD_SHUTTERS:
			return SOCKET_WINDOW;
		
		case B_CODE_LOCK:
			return SOCKET_DOOR;
			
		case B_HIGH_WOOD_WALL: case B_HIGH_STONE_WALL:
			return SOCKET_HIGH_WALL;
	}
	return -1;
}

bool isFoundation(CBaseEntity@ ent)
{
	int type = ent.pev.colormap;
	return type == B_FOUNDATION or type == B_FOUNDATION_TRI;
}

bool isTriangular(CBaseEntity@ ent)
{
	int type = ent.pev.colormap;
	return (ent.pev.classname == "func_breakable_custom" or ent.pev.classname == "func_illusionary") and type == B_FOUNDATION_TRI or type == B_FLOOR_TRI;
}

bool isFloorPiece(CBaseEntity@ ent)
{
	int type = ent.pev.colormap;
	return type == B_FOUNDATION or type == B_FLOOR or type == B_FOUNDATION_TRI or type == B_FLOOR_TRI or
			(type == B_LADDER_HATCH and ent.pev.classname == "func_breakable_custom");
}

bool isFloorItem(CBaseEntity@ ent)
{
	switch(ent.pev.colormap)
	{
		case B_TOOL_CUPBOARD:
		case B_SMALL_CHEST:
		case B_LARGE_CHEST:
		case B_FURNACE:
		case B_BED:
			return true;
	}
	return false;
}

bool isUpgradable(CBaseEntity@ ent)
{
	int type = ent.pev.colormap;
	int socket = socketType(type);
	return ent.pev.classname == "func_breakable_custom" and socket != SOCKET_WINDOW and type != B_LADDER_HATCH and
			socket != SOCKET_DOORWAY and type != B_FIRE and
			type != B_LADDER and type != E_SUPPLY_CRATE and socket != SOCKET_HIGH_WALL and !isFloorItem(ent) and type != -1;
}

bool canPlaceOnTerrain(int partType)
{
	return partType == B_HIGH_WOOD_WALL or partType == B_HIGH_STONE_WALL or partType == B_FOUNDATION;
}

void updateRoofWalls(CBaseEntity@ roof)
{
	if (roof is null)
		return;
	// put walls under roofs when there are no adjacent roofs and there is a wall underneath one/both edges
	string brushModel = roof.pev.model;
	g_EngineFuncs.MakeVectors(roof.pev.angles);
	Vector roofCheckR = roof.pev.origin + g_Engine.v_right*128;
	Vector roofCheckL = roof.pev.origin + g_Engine.v_right*-128;
	Vector wallCheckR = roof.pev.origin + g_Engine.v_right*64 + Vector(0,0,-192);
	Vector wallCheckL = roof.pev.origin + g_Engine.v_right*-64 + Vector(0,0,-192);
	
	CBaseEntity@ wallR = getPartAtPos(wallCheckR);
	bool hasWallR = wallR !is null and 
				(wallR.pev.colormap == B_WALL or wallR.pev.colormap == B_WINDOW or wallR.pev.colormap == B_DOORWAY);

	CBaseEntity@ wallL = getPartAtPos(wallCheckL);
	bool hasWallL = wallL !is null and 
				(wallL.pev.colormap == B_WALL or wallL.pev.colormap == B_WINDOW or wallL.pev.colormap == B_DOORWAY);

	CBaseEntity@ roofR = getPartAtPos(roofCheckR);
	bool hasRoofR = roofR !is null and roofR.pev.colormap == B_ROOF;
		
	CBaseEntity@ roofL = getPartAtPos(roofCheckL);
	bool hasRoofL = roofL !is null and roofL.pev.colormap == B_ROOF;
	
	string material = getMaterialType(roof);
	
	if (hasWallL and hasWallR and !hasRoofL and !hasRoofR) {
		brushModel = "b_roof_wall_both";
	} else if (hasWallL and !hasRoofL) {
		brushModel = "b_roof_wall_left";
	} else if (hasWallR and !hasRoofR) {
		brushModel = "b_roof_wall_right";
	} else {
		brushModel = "b_roof";
	}
	
	int oldcolormap = roof.pev.colormap;
	g_EntityFuncs.SetModel(roof, getModelFromName(brushModel + material));
	roof.pev.colormap = oldcolormap;
}
	
bool forbiddenByCupboard(CBasePlayer@ plr, Vector buildPos, bool buildingCupboard=false)
{
	for (uint i = 0; i < g_tool_cupboards.length(); i++)
	{
		if (g_tool_cupboards[i])
		{
			CBaseEntity@ ent = g_tool_cupboards[i];
			if ((ent.pev.origin - buildPos).Length() < g_tool_cupboard_radius)
			{
				if (buildingCupboard or !getPlayerState(plr).isAuthed(ent))
					return true;
			}
		}
		else
		{
			g_tool_cupboards.removeAt(i);
			i--;
		}
	}
	return false;
}

TraceResult TraceLook(CBasePlayer@ plr, float dist=128, bool bigHull=false)
{
	Vector vecSrc = plr.GetGunPosition();
	Math.MakeVectors( plr.pev.v_angle ); // todo: monster angles
	
	TraceResult tr;
	Vector vecEnd = vecSrc + g_Engine.v_forward * dist;
	if (bigHull)
		g_Utility.TraceHull( vecSrc, vecEnd, dont_ignore_monsters, head_hull, plr.edict(), tr );
	else
		g_Utility.TraceLine( vecSrc, vecEnd, dont_ignore_monsters, plr.edict(), tr );
	return tr;
}

float getUseDistance(CBaseEntity@ ent)
{
	float touchDist = 96;
	if (ent.pev.colormap == E_SUPPLY_CRATE)
		touchDist = 160;
	return touchDist;
}

// returns amount that was actually given
int giveAmmo(CBasePlayer@ plr, int amt, string type)
{
	int ammoIdx = g_PlayerFuncs.GetAmmoIndex(type);
	int beforeAmmo = plr.m_rgAmmo(ammoIdx);
	plr.GiveAmmo(amt, type, 9999); // TODO: set proper max?
	return plr.m_rgAmmo(ammoIdx) - beforeAmmo;
}

// display the text for a second longer
void PrintKeyBindingStringLong(CBasePlayer@ plr, string text)
{
	PrintKeyBindingString(plr, text);
	g_Scheduler.SetTimeout("PrintKeyBindingString", 1, @plr, text);
}

void PrintKeyBindingStringXLong(CBasePlayer@ plr, string text)
{
	PrintKeyBindingString(plr, text);
	g_Scheduler.SetTimeout("PrintKeyBindingString", 1, @plr, text, "", "", "", "", "", "");
	g_Scheduler.SetTimeout("PrintKeyBindingString", 2, @plr, text, "", "", "", "", "", "");
	g_Scheduler.SetTimeout("PrintKeyBindingString", 3, @plr, text, "", "", "", "", "", "");
	g_Scheduler.SetTimeout("PrintKeyBindingString", 4, @plr, text, "", "", "", "", "", "");
	g_Scheduler.SetTimeout("PrintKeyBindingString", 5, @plr, text, "", "", "", "", "", "");
	g_Scheduler.SetTimeout("PrintKeyBindingString", 6, @plr, text, "", "", "", "", "", "");
}

void PrintKeyBindingStringAllLong(string text)
{
	PrintKeyBindingStringAll(text);
	g_Scheduler.SetTimeout("PrintKeyBindingStringAll", 1, text);
	g_Scheduler.SetTimeout("PrintKeyBindingStringAll", 2, text);
	g_Scheduler.SetTimeout("PrintKeyBindingStringAll", 3, text);
	g_Scheduler.SetTimeout("PrintKeyBindingStringAll", 4, text);
}

string format_float(float f)
{
	uint decimal = uint(((f - int(f)) * 10)) % 10;
	return "" + int(f) + "." + decimal;
}

void showTip(EHandle h_plr, int tipType)
{
	if (!h_plr.IsValid() or !h_plr.GetEntity().IsPlayer())
		return;
	
	CBasePlayer@ plr = cast<CBasePlayer@>(h_plr.GetEntity());
	PlayerState@ state = getPlayerState(plr);
	state.showTip(tipType);
}

void showTipAll(int tipType)
{
	CBaseEntity@ ent = null;
	do {
		@ent = g_EntityFuncs.FindEntityByClassname(ent, "player");
		if (ent !is null) {
			CBasePlayer@ plr = cast<CBasePlayer@>(ent);
			showTip(EHandle(plr), tipType);
		}
	} while (ent !is null);
}

void sayPlayer(EHandle h_plr, string text)
{
	if (!h_plr) {
		return;
	}
	CBasePlayer@ plr = cast<CBasePlayer@>(h_plr.GetEntity());
	SayText(plr, text);
}

// actual center of the part, not the origin
Vector getCentroid(CBaseEntity@ ent)
{
	array<Vector2D> verts = getBoundingVerts2D(ent, Vector2D(0,0));
	Vector2D centroid2D;
	for (uint i = 0; i < verts.length(); i++)
	{
		centroid2D = centroid2D + verts[i];
	}
	centroid2D = centroid2D / verts.length();
	Vector centroid = Vector(centroid2D.x, centroid2D.y, 0);
	centroid.z = ent.pev.origin.z + ((ent.pev.mins.z + ent.pev.maxs.z) / 2);
	return centroid;
	
}

array<Vector2D> getBoundingVerts2D(CBaseEntity@ ent, Vector2D offset)
{
	Vector angles = ent.pev.angles;
	if (ent.pev.classname == "func_door_rotating")
		angles.y += 180;
		
	// counter-clockwise starting at back right vertex
	array<Vector2D> verts;
	g_EngineFuncs.MakeVectors(angles);
	Vector2D ori = Vector2D(ent.pev.origin.x + offset.x, ent.pev.origin.y + offset.y);
	Vector2D v_forward = Vector2D(g_Engine.v_forward.x, g_Engine.v_forward.y);
	Vector2D v_right = Vector2D(g_Engine.v_right.x, g_Engine.v_right.y);
	verts.insertLast(ori + v_right*-ent.pev.maxs.y + v_forward*ent.pev.mins.x);
	verts.insertLast(ori + v_right*-ent.pev.mins.y + v_forward*ent.pev.mins.x);
	if (isTriangular(ent))
	{
		string size = getModelSize(ent);
		if (size == "_1x1")
		{
			verts.insertLast(ori + v_forward*ent.pev.maxs.x + v_right*-(ent.pev.maxs.y + ent.pev.mins.y));
		}
		else if (size == "_2x2")
		{
			verts.insertLast(ori + v_forward*ent.pev.maxs.x + v_right*64);
		}
		else if (size == "_2x1")
		{
			verts[1] = ori + v_forward*ent.pev.mins.x + v_right*64;
			verts.insertLast(ori + v_forward*ent.pev.maxs.x + v_right*128);
			verts.insertLast(ori + v_forward*ent.pev.maxs.x);
		}
		else if (size == "_3x1")
		{
			verts[1] = ori + v_forward*ent.pev.mins.x + v_right*192;
			verts.insertLast(ori + v_forward*ent.pev.maxs.x + v_right*128);
			verts.insertLast(ori + v_forward*ent.pev.maxs.x);
		}
		else if (size == "_4x1")
		{
			verts[1] = ori + v_forward*ent.pev.mins.x + v_right*192;
			verts.insertLast(ori + v_forward*ent.pev.maxs.x + v_right*256);
			verts.insertLast(ori + v_forward*ent.pev.maxs.x);
		}
		else if (size == "_1x4")
		{
			verts[0] = ori + v_forward*ent.pev.mins.x + v_right*-192;
			verts[1] = ori + v_forward*ent.pev.mins.x + v_right*64;
			verts.insertLast(ori + v_forward*ent.pev.maxs.x);
			verts.insertLast(ori + v_forward*ent.pev.maxs.x + v_right*-256);
		}
	}
	else
	{
		//if (ent)asdf; // TODO: Special outline for stairs so I can put chests underneath
		verts.insertLast(ori + v_right*-ent.pev.mins.y + v_forward*ent.pev.maxs.x);
		verts.insertLast(ori + v_right*-ent.pev.maxs.y + v_forward*ent.pev.maxs.x);
	}
	return verts;
}

// collision between 2 oriented 2D boxes using the separating axis theorem 
float collisionSA(CBaseEntity@ b1, CBaseEntity@ b2)
{
	Vector2D b1Ori = Vector2D(b1.pev.origin.x, b1.pev.origin.y);
	Vector2D b2Ori = Vector2D(b2.pev.origin.x, b2.pev.origin.y);
	
	array<Vector2D> b1Verts = getBoundingVerts2D(b1, b1Ori*-1);
	array<Vector2D> b2Verts = getBoundingVerts2D(b2, b1Ori*-1);
	
	int b1NumVerts = b1Verts.length();
	int b2NumVerts = b2Verts.length();
	array<Vector2D> axes(b1NumVerts + b2NumVerts);
	int idx = 0;
	
	for (int i = 1; i < b1NumVerts; i++)
		axes[idx++] = getPerp(b1Verts[i] - b1Verts[i-1]);
	axes[idx++] = getPerp(b1Verts[0] - b1Verts[b1NumVerts-1]);

	for (int i = 1; i < b2NumVerts; i++)
		axes[idx++] = getPerp(b2Verts[i] - b2Verts[i-1]);
	axes[idx++] = getPerp(b2Verts[0] - b2Verts[b2NumVerts-1]);

	float minPen = 1E9; // minimum penetration vector;
	Vector2D fix; // vector for fixing the collision
	float ba1_min = 0;
	float ba1_max = 0;
	float ba2_min = 0;
	float ba2_max = 0;
	
	for (uint a = 0; a < axes.length(); a++)
	{
		fix = axes[a].Normalize();
		
		// project verts on this axis
		ba1_min = 1E9;
		ba1_max = -1E9;
		ba2_min = 1E9;
		ba2_max = -1E9;
		for (int i = 0; i < b1NumVerts; i++)
		{
			float dist = b1Verts[i].x*fix.x + b1Verts[i].y*fix.y; // relative to our origin
			ba1_min = Math.min(ba1_min, dist);
			ba1_max = Math.max(ba1_max, dist);
		}
		for (int i = 0; i < b2NumVerts; i++)
		{
			float dist = b2Verts[i].x*fix.x + b2Verts[i].y*fix.y;
			ba2_min = Math.min(ba2_min, dist);
			ba2_max = Math.max(ba2_max, dist);
		}
		
		if (ba1_min < ba2_max and ba2_min < ba1_max) // collision along this axis!
		{
			if (ba2_max-ba1_min > ba1_max-ba2_min)
			{
				float pen = ba2_min-ba1_max;
				if (abs(pen) < abs(minPen))
					minPen = pen;
			}
			else
			{
				float pen = ba2_max-ba1_min;
				if (abs(pen) < abs(minPen))
					minPen = pen;
			}
		}
		else
		{
			// this is the separating axis!
			return 0;
		}
	}
	
	float overlap = minPen / fix.Length();
	
	if (debug_mode and abs(overlap) > 9.9f)
	{
		for (uint i = 0; i < b1Verts.length(); i++)
			b1Verts[i] = b1Verts[i] + b1Ori;
		for (uint i = 0; i < b2Verts.length(); i++)
			b2Verts[i] = b2Verts[i] + b1Ori;
		
		Vector fix3 = Vector(fix.x, fix.y, 0);
		
		for (uint i = 0; i < b1Verts.length(); i++)
		{
			uint k = (i+1) % b1Verts.length();
			//te_beampoints(Vector(b1Verts[i].x, b1Verts[i].y, b1.pev.origin.z + 64), Vector(b1Verts[k].x, b1Verts[k].y, b1.pev.origin.z + 64));
		}
		for (uint i = 0; i < b2Verts.length(); i++)
		{
			uint k = (i+1) % b2Verts.length();
			//te_beampoints(Vector(b2Verts[i].x, b2Verts[i].y, b2.pev.origin.z + 64), Vector(b2Verts[k].x, b2Verts[k].y, b2.pev.origin.z + 64));
		}
		
		//te_beampoints(b1.pev.origin + Vector(0,0,64), b1.pev.origin + Vector(0,0,64) + fix3.Normalize()*overlap);
		//te_beampoints(b1.pev.origin, b2.pev.origin);
	}
	
	return overlap;
}

// special roof collision
bool objectThroughRoof(CBaseEntity@ roof, CBaseEntity@ obj)
{
	Vector pos = obj.pev.origin;
	Vector mins = obj.pev.mins;
	Vector maxs = obj.pev.maxs;
	
	g_EngineFuncs.MakeVectors(obj.pev.angles);
	
	array<Vector> verts;
	verts.insertLast(pos + g_Engine.v_forward*mins.x + g_Engine.v_right*mins.y + g_Engine.v_up*mins.z);
	verts.insertLast(pos + g_Engine.v_forward*mins.x + g_Engine.v_right*mins.y + g_Engine.v_up*maxs.z);
	verts.insertLast(pos + g_Engine.v_forward*mins.x + g_Engine.v_right*maxs.y + g_Engine.v_up*mins.z);
	verts.insertLast(pos + g_Engine.v_forward*mins.x + g_Engine.v_right*maxs.y + g_Engine.v_up*maxs.z);
	verts.insertLast(pos + g_Engine.v_forward*maxs.x + g_Engine.v_right*mins.y + g_Engine.v_up*mins.z);
	verts.insertLast(pos + g_Engine.v_forward*maxs.x + g_Engine.v_right*mins.y + g_Engine.v_up*maxs.z);
	verts.insertLast(pos + g_Engine.v_forward*maxs.x + g_Engine.v_right*maxs.y + g_Engine.v_up*mins.z);
	verts.insertLast(pos + g_Engine.v_forward*maxs.x + g_Engine.v_right*maxs.y + g_Engine.v_up*maxs.z);
	
	g_EngineFuncs.MakeVectors(roof.pev.angles);
	Vector plane = roof.pev.origin;
	Vector ndir = roof.pev.colormap == B_ROOF ? g_Engine.v_forward : -g_Engine.v_forward;
	Vector normal = (ndir + g_Engine.v_up).Normalize(); // roof is at perfectly 45 deg angle
	
	//te_beampoints(plane + normal*-64, plane + normal*64, "sprites/laserbeam.spr", 0, 100, 1, 1, 0, PURPLE);
	 
	int sign = 0;
	for (int i = 0; i < int(verts.length()); i++)
	{
		float dist = DotProduct(normal, verts[i] - plane);
		sign += dist >= 0 ? 1 : -1;
	}
		
	// were all points on one side of the plane?
	if (abs(sign) != int(verts.length()))
		return true;
		
	// now check against roof side walls, if any exist
	string model = getModelName(roof);
	if (model.Find("roof_wall_left") >= 0 or model.Find("roof_wall_both") >= 0)
	{
		plane = roof.pev.origin + g_Engine.v_right*64;
		normal = (g_Engine.v_right).Normalize();
		sign = 0;
		for (int i = 0; i < int(verts.length()); i++)
		{
			float dist = DotProduct(normal, verts[i] - plane);
			sign += dist >= 0 ? 1 : -1;
		}
		if (abs(sign) != int(verts.length()))
			return true;
	}
	if (model.Find("roof_wall_right") >= 0 or model.Find("roof_wall_both") >= 0)
	{
		plane = roof.pev.origin + g_Engine.v_right*-64;
		normal = (-g_Engine.v_right).Normalize();
		sign = 0;
		for (int i = 0; i < int(verts.length()); i++)
		{
			float dist = DotProduct(normal, verts[i] - plane);
			sign += dist >= 0 ? 1 : -1;
		}
		if (abs(sign) != int(verts.length()))
			return true;
	}
	
	return false;
}

// collision between 2 oriented 3D boxes. Only boxes rotated on the yaw axis are allowed
float collisionBoxesYaw(CBaseEntity@ b1, CBaseEntity@ b2) 
{
	// check vertical collision first
	float min1 = b1.pev.origin.z + b1.pev.mins.z;
	float min2 = b2.pev.origin.z + b2.pev.mins.z;
	float max1 = b1.pev.origin.z + b1.pev.maxs.z;
	float max2 = b2.pev.origin.z + b2.pev.maxs.z;
	
	if (b1.pev.colormap == B_LADDER_HATCH)
		min1 = b1.pev.origin.z - 4;
	
	if (b1.pev.colormap == B_ROOF)
	{
		min1 = b1.pev.origin.z - 60;
		max1 = b1.pev.origin.z + 60;
	}
	if (b2.pev.colormap == B_ROOF)
	{
		min2 = b2.pev.origin.z - 60;
		max2 = b2.pev.origin.z + 60;
	}
	
	if (max1 > min2 and min1 < max2)
	{
		float overlapXY = collisionSA(b1, b2);
		float overlapZ = Math.max(0, Math.min(max1, max2) - Math.max(min1, min2));
		// check 2D top-down collision
		float overlapMin = Math.min(abs(overlapZ), abs(overlapXY));
		
		if (overlapMin > 0)
		{
			if (b1.pev.colormap == B_ROOF and isFloorItem(b2))
				return objectThroughRoof(b1, b2) ? 1000 : 0;
			if (b2.pev.colormap == B_ROOF and isFloorItem(b1))
				return objectThroughRoof(b2, b1) ? 1000 : 0;

			if ((b1.pev.colormap == B_STAIRS or b1.pev.colormap == B_STAIRS_L) and isFloorItem(b2))
				return objectThroughRoof(b1, b2) ? 1000 : 0;
			if ((b2.pev.colormap == B_STAIRS or b2.pev.colormap == B_STAIRS_L) and isFloorItem(b1))
				return objectThroughRoof(b2, b1) ? 1000 : 0;
		}
		
		return overlapMin;
	}
	return 0;
}

// ported from HLSDK with minor adjustments
void AngularMove( CBaseEntity@ ent, Vector vecDestAngle, float flSpeed )
{	
	Vector m_vecFinalAngle = vecDestAngle;
	
	EHandle h_ent = ent;
	ent.pev.iuser1 = 1;

	// Already there?
	if (vecDestAngle == ent.pev.angles)
	{
		AngularMoveDone(h_ent, m_vecFinalAngle);
		return;
	}
	
	// set destdelta to the vector needed to move
	Vector vecDestDelta = vecDestAngle - ent.pev.angles;
	
	// divide by speed to get time to reach dest
	float flTravelTime = vecDestDelta.Length() / flSpeed;

	// set nextthink to trigger a call to AngularMoveDone when dest is reached
	g_Scheduler.SetTimeout("AngularMoveDone", flTravelTime, h_ent, m_vecFinalAngle);

	// scale the destdelta vector by the time spent traveling to get velocity
	ent.pev.avelocity = vecDestDelta / flTravelTime;
	ent.pev.fixangle = FAM_ADDAVELOCITY;
}

// ported from HLSDK with minor adjustments
void AngularMoveDone( EHandle h_ent, Vector finalAngle )
{
	if (h_ent)
	{
		CBaseEntity@ ent = h_ent;
		ent.pev.iuser1 = 0;
		ent.pev.angles = finalAngle;
		ent.pev.avelocity = g_vecZero;
	}
}

// Will create a new state if the requested one does not exit
PlayerState@ getPlayerState(CBasePlayer@ plr)
{
	string steamId = g_EngineFuncs.GetPlayerAuthId( plr.edict() );
	if (steamId == 'STEAM_ID_LAN') {
		steamId = plr.pev.netname;
	}
	
	if ( !player_states.exists(steamId) )
	{
		PlayerState state;
		state.plr = plr;
		player_states[steamId] = state;
	}
	
	PlayerState@ state = cast<PlayerState@>( player_states[steamId] );
	
	bool isConnected = g_EngineFuncs.GetPlayerUserId(plr.edict()) != -1;
	if (state.inGame and !isConnected) {
		println("Player crashed or something. Setting inGame state to false");
		state.inGame = false;
		g_Scheduler.SetTimeout("cleanup_map", 1);
	}
	
	return state;
}

PlayerState@ getPlayerStateBySteamID(string steamId, string netname)
{
	if (steamId == 'STEAM_ID_LAN') {
		steamId = netname;
	}
	
	if ( player_states.exists(steamId) )
	{
		return cast<PlayerState@>( player_states[steamId] );
	}
	return null;
}

string getPlayerUniqueId(CBasePlayer@ plr)
{
	string steamId = g_EngineFuncs.GetPlayerAuthId( plr.edict() );
	if (steamId == 'STEAM_ID_LAN') {
		steamId = plr.pev.netname;
	}
	return steamId;
}

// get player by name, partial name, or steamId
CBasePlayer@ getPlayerByName(CBasePlayer@ caller, string name, bool quiet=false)
{
	name = name.ToLowercase();
	int partialMatches = 0;
	CBasePlayer@ partialMatch;
	CBaseEntity@ ent = null;
	do {
		@ent = g_EntityFuncs.FindEntityByClassname(ent, "player");
		if (ent !is null) {
			CBasePlayer@ plr = cast<CBasePlayer@>(ent);
			string plrName = string(plr.pev.netname).ToLowercase();
			string plrId = getPlayerUniqueId(plr).ToLowercase();
			if (plrName == name)
				return plr;
			else if (plrId == name)
				return plr;
			else if (plrName.Find(name) != uint(-1))
			{
				@partialMatch = plr;
				partialMatches++;
			}
		}
	} while (ent !is null);
	
	if (partialMatches == 1) {
		return partialMatch;
	} else if (partialMatches > 1) {
		SayText(caller, "{cmd_name_error}", partialMatches, name);
	} else {
		SayText(caller, "{cmd_name_error2}", name);
	}
	
	return null;
}

Team@ getPlayerTeam(CBasePlayer@ plr)
{
	string id = getPlayerUniqueId(plr);
	for (uint i = 0; i < g_teams.size(); i++)
	{
		for (uint k = 0; k < g_teams[i].members.size(); k++)
		{
			if (g_teams[i].members[k] == id)
			{
				return g_teams[i];
			}
		}
	}
	return null;
}

CBasePlayer@ getAnyPlayer() 
{
	CBaseEntity@ ent = null;
	do {
		@ent = g_EntityFuncs.FindEntityByClassname(ent, "player");
		if (ent !is null) {
			CBasePlayer@ plr = cast<CBasePlayer@>(ent);
			return plr;
		}
	} while (ent !is null);
	return null;
}

CBasePlayer@ getRandomLivingPlayer() 
{
	CBaseEntity@ ent = null;
	array<CBasePlayer@> choices;
	do {
		@ent = g_EntityFuncs.FindEntityByClassname(ent, "player");
		if (ent !is null and ent.IsAlive()) {
			CBasePlayer@ plr = cast<CBasePlayer@>(ent);
			choices.insertLast(plr);
		}
	} while (ent !is null);
	
	if (choices.size() > 0)
		return choices[Math.RandomLong(0, choices.size()-1)];
	
	return null;
}

CBaseEntity@ getRandomBasePart()
{
	CBaseEntity@ ent = null;
	array<CBaseEntity@> choices;
	do {
		@ent = g_EntityFuncs.FindEntityByClassname(ent, "func_breakable_custom");
		if (ent !is null and ent.IsAlive()) 
		{
			func_breakable_custom@ part = castToPart(EHandle(ent));
			if (!part.isNode)
				choices.insertLast(ent);
		}
	} while (ent !is null);
	
	if (choices.size() > 0)
		return choices[Math.RandomLong(0, choices.size()-1)];
	
	return null;
}

void PrecacheSound(string snd)
{		
	g_SoundSystem.PrecacheSound(snd);
	g_Game.PrecacheGeneric("sound/" + snd);
}

void PrecacheModel(string mdl)
{
	g_Game.PrecacheModel(mdl);
}