
void inventoryCheck()
{
	for (uint i = 0; i < g_item_drops.size(); i++)
	{
		if (!g_item_drops[i].IsValid())
			continue;
		if (g_item_drops[i].GetEntity().pev.teleport_time < g_Engine.time)
		{
			CBaseEntity@ item = g_item_drops[i];
			item.pev.renderfx = -9999;
			remove_item_from_drops(item);
			g_EntityFuncs.Remove(item);
			i--;
		}
		else
			g_item_drops[i].GetEntity().pev.renderfx = 0;
	}
	for (uint i = 0; i < g_corpses.size(); i++)
	{
		if (!g_corpses[i].IsValid())
			continue;
		g_corpses[i].GetEntity().pev.renderfx = 0;
	}
	CBaseEntity@ ent = null;
	do {
		@ent = g_EntityFuncs.FindEntityByClassname(ent, "player");
		if (ent !is null and ent.pev.deadflag > 0)
		{
			ent.pev.renderfx = 0;
			if (ent.pev.sequence != 13)
			{
				ent.pev.frame = 0;
				ent.pev.sequence = 13;
			}
		}
	} while (ent !is null);
	
	/*
	// check for dropped weapons
	CBaseEntity@ wep = null;
	do {
		@wep = g_EntityFuncs.FindEntityByClassname(wep, "weaponbox");
		if (wep !is null and wep.pev.noise3 == "")
		{
			CBaseEntity@ owner = g_EntityFuncs.Instance(wep.pev.owner);
			if (owner !is null and owner.IsPlayer())
			{
				CBasePlayer@ plr = cast<CBasePlayer@>(owner);
				PlayerState@ state = getPlayerState(plr);
				
				if (plr.pev.deadflag > 0)
				{
					// don't drop weapons on death
					wep.Touch(plr);
					wep.pev.effects = EF_NODRAW;
					wep.pev.movetype = MOVETYPE_NONE;
				}
				
				if (state.droppedItems >= g_max_item_drops)
				{
					wep.Touch(plr);
					wep.pev.effects = EF_NODRAW;
					wep.pev.movetype = MOVETYPE_NONE;
					g_PlayerFuncs.PrintKeyBindingString(plr, "Can't drop more than " + g_max_item_drops + " item" + (g_max_item_drops > 1 ? "s" : ""));
				}
				else
				{
					state.droppedItems++;
					wep.pev.noise3 = getPlayerUniqueId(plr);
					state.droppedWeapons.insertLast(EHandle(wep));
				}
			}
		}
	} while(wep !is null);
	*/
	
	CBaseEntity@ e_plr = null;
	do {
		@e_plr = g_EntityFuncs.FindEntityByClassname(e_plr, "player");
		if (e_plr !is null)
		{
			CBasePlayer@ plr = cast<CBasePlayer@>(e_plr);
			PlayerState@ state = getPlayerState(plr);
			if (!state.inGame)
				continue;
			state.updateDroppedWeapons();
			
			// TODO: prevent nearby players from getting the same class (or just use custom weapons)
			//plr.SetClassification(Math.RandomLong(-1, 13));
			
			state.oldDead = plr.pev.deadflag;
			
			if (plr.pev.deadflag > 0)
				continue;
			
			if (plr.FlashlightIsOn()) {
				openPlayerMenu(plr, "");
				plr.FlashlightTurnOff();
			}
			
			TraceResult tr = TraceLook(plr, 96, true);
			CBaseEntity@ phit = g_EntityFuncs.Instance( tr.pHit );
			
			// keep item list up-to-date (will be stale after firing weapon/reloading/etc.
			// TODO: This isn't perfect. "+attack;wait;-attack;retry" will give you free ammo sometimes
			// but increasing poll rate might be too cpu intensive...
			CBasePlayerWeapon@ activeWep = cast<CBasePlayerWeapon@>(plr.m_hActiveItem.GetEntity());
			if (activeWep !is null)
			{
				Item@ item = getItemByClassname(activeWep.pev.classname);
				if (item !is null)
					state.updateItemListQuick(item.type, activeWep.m_iClip);
			}
			state.oldAngles = plr.pev.v_angle;
			state.oldHealth = plr.pev.health;
			state.oldArmor = plr.pev.armorvalue;
			
			if (state.currentChest)
			{
				float touchDist = 96;
				if (state.currentChest.GetEntity().pev.colormap == E_SUPPLY_CRATE)
					touchDist = 160;
				if ((state.currentChest.GetEntity().pev.origin - plr.pev.origin).Length() > touchDist)
				{
					state.currentChest = null;
					g_PlayerFuncs.PrintKeyBindingString(plr, "Loot target too far away");
					state.closeMenus();
				}
			}
			
			HUDTextParams params;
			params.effect = 0;
			params.fadeinTime = 0;
			params.fadeoutTime = 0;
			params.holdTime = 0.2f;
			params.r1 = 255;
			params.g1 = 255;
			params.b1 = 255;
			params.x = -1;
			params.y = 0.7;
			params.channel = 1;
			
			// highlight items on ground (and see what they are)
			CBaseEntity@ closestItem = getLookItem(plr, tr.vecEndPos);
			
			//println("CLOSE TO  " + g_item_drops.size());
			
			if (closestItem !is null)
			{
				closestItem.pev.renderfx = kRenderFxGlowShell;
				closestItem.pev.renderamt = 1;
				closestItem.pev.rendercolor = Vector(200, 200, 200);
				
				if (closestItem.IsPlayer() and (plr.pev.button & IN_USE) != 0)
				{
					if (state.reviving)
					{
						float time = g_Engine.time - state.reviveStart;
						float t = time / g_revive_time;
						string progress = "\n\n[";
						for (float i = 0; i < 1.0f; i += 0.03f)
						{
							progress += t > i ? "|||" : "__";
						}
						progress += "]";
						
						if (time > 0.5f)
							g_PlayerFuncs.HudMessage(plr, params, "Reviving " + closestItem.pev.netname + progress);
						
						if (time > g_revive_time)
						{
							closestItem.EndRevive(0);
							revive_finish(EHandle(closestItem));
						}
					}
					else
					{
						state.reviving = true;
						state.reviveStart = g_Engine.time;
					}
				}
				else
				{
					state.reviving = false;
					g_PlayerFuncs.HudMessage(plr, params, getItemDisplayName(closestItem));
				}
				continue;
			}
			else
			{
				state.reviving = false;
			}
			
			if (phit is null or phit.pev.classname == "worldspawn" or phit.pev.colormap == -1)
				continue;
			
			g_PlayerFuncs.HudMessage(plr, params, 
				string(prettyPartName(phit)) + "\n" + int(phit.pev.health) + " / " + int(phit.pev.max_health));
		}
	} while(e_plr !is null);

}

void item_dropped(CBaseEntity@ pActivator, CBaseEntity@ pCaller, USE_TYPE useType, float flValue)
{
	if (pCaller.pev.classname != "item_inventory" and !pActivator.IsPlayer())
		return;
		
	CBasePlayer@ plr = cast<CBasePlayer@>(pActivator);
	CItemInventory@ item = cast<CItemInventory@>(pCaller);
	if (item.pev.renderfx == -9999)
		return; // this was just a stackable item that was replaced with a larger stack, ignore it
	
	PlayerState@ state = getPlayerState(plr);
	if (state.droppedItems >= g_max_item_drops)
	{
		g_PlayerFuncs.PrintKeyBindingString(plr, "Can't drop more than " + g_max_item_drops + " item" + (g_max_item_drops > 1 ? "s" : ""));
		// timeout prevents repeating item_dropped over and over (SC bug)
		g_Scheduler.SetTimeout("undo_drop", 0.0f, EHandle(item), EHandle(plr)); 
		return;
	}
	state.updateItemList();
	
	item.pev.teleport_time = g_Engine.time + g_item_time;
	
	state.droppedItems++;
	item.pev.noise1 = getPlayerUniqueId(plr);
	
	g_item_drops.insertLast(EHandle(item));
	item.pev.team = 0; // trigger item_collect callback
}

void remove_item_from_drops(CBaseEntity@ item)
{
	for (uint i = 0; i < g_item_drops.size(); i++)
	{
		if (!g_item_drops[i].IsValid() or g_item_drops[i].GetEntity().entindex() == item.entindex())
		{
			if (g_item_drops[i].IsValid())
			{
				CBasePlayer@ owner = getPlayerByName(null, g_item_drops[i].GetEntity().pev.noise1, true);
				if (owner !is null)
					getPlayerState(owner).droppedItems--;
			}
			
			g_item_drops.removeAt(i);
			i--;
			break;
		}
	}
}

void item_collected(CBaseEntity@ pActivator, CBaseEntity@ pCaller, USE_TYPE useType, float flValue)
{
	if (pCaller.pev.classname != "item_inventory" or !pActivator.IsPlayer())
		return;
		
	CBasePlayer@ plr = cast<CBasePlayer@>(pActivator);
	int type = pCaller.pev.colormap-1;
	int amount = pCaller.pev.button;
	if (amount <= 0)
		amount = 1;
	
	if (pCaller.pev.team != 1)
	{
		g_PlayerFuncs.PrintKeyBindingString(plr, "" + amount + "x " + g_items[type].title);
		if (g_items[type].stackSize > 1)
		{
			Vector oldOri = pCaller.pev.origin;
			string oldOwner = pCaller.pev.noise1;
			int barf = combineItemStacks(plr, type);
			if (barf > 0)
			{
				CBaseEntity@ item = spawnItem(oldOri, type, barf);
				item.pev.noise1 = oldOwner;
				g_item_drops.insertLast(EHandle(item));
				println("Couldn't hold " + barf + " of that");
				return;
			}
		}
			
		remove_item_from_drops(pCaller);
	}
}

void item_cant_collect(CBaseEntity@ pActivator, CBaseEntity@ pCaller, USE_TYPE useType, float flValue)
{
	if (!pActivator.IsPlayer())
		return;
	g_PlayerFuncs.PrintKeyBindingString(cast<CBasePlayer@>(pActivator), "Your inventory is full");
}

void delay_remove(EHandle ent)
{
	if (ent)
		g_EntityFuncs.Remove(ent);
}

void undo_drop(EHandle h_item, EHandle h_plr)
{
	if (h_item.IsValid() and h_plr.IsValid())
	{
		CBaseEntity@ item = h_item.GetEntity();
		CBasePlayer@ plr = cast<CBasePlayer@>(h_plr.GetEntity());
		int amt = item.pev.button > 0 ? item.pev.button : 1;
		giveItem(plr, item.pev.colormap-1, amt, false);
		g_EntityFuncs.Remove(item);
	}
}

CBaseEntity@ getLookItem(CBasePlayer@ plr, Vector lookPos)
{
	// highlight items on ground (and see what they are)
	float closestDist = 9e99;
	CBaseEntity@ closestItem = null;
	for (uint i = 0; i < g_item_drops.size(); i++)
	{
		if (!g_item_drops[i].IsValid())
			continue;
	
		CBaseEntity@ item = g_item_drops[i];				
		float dist = (item.pev.origin - lookPos).Length();
		if (dist < 32 and dist < closestDist)
		{
			@closestItem = @item;
			closestDist = dist;
		}
	}
	for (uint i = 0; i < g_corpses.size(); i++)
	{
		if (!g_corpses[i].IsValid())
			continue;
	
		CBaseEntity@ item = g_corpses[i];				
		float dist = (item.pev.origin - lookPos).Length();
		if (item.pev.effects != EF_NODRAW and dist < 32 and dist < closestDist)
		{
			@closestItem = @item;
			closestDist = dist;
		}
	}
	
	CBaseEntity@ ent = null;
	do {
		@ent = g_EntityFuncs.FindEntityByClassname(ent, "player");
		if (ent !is null and ent.pev.deadflag > 0 and (ent.pev.effects & EF_NODRAW) == 0)
		{
			float dist = (ent.pev.origin - lookPos).Length();
			if (dist < 32 and dist < closestDist)
			{
				@closestItem = @ent;
				closestDist = dist;
			}
		}
	} while (ent !is null);
	
	//println("CLOSE TO  " + g_item_drops.size());
	return closestItem;
}

int combineItemStacks(CBasePlayer@ plr, int addedType)
{
	InventoryList@ inv = plr.get_m_pInventory();
	
	dictionary totals;
	while(inv !is null)
	{
		CItemInventory@ item = cast<CItemInventory@>(inv.hItem.GetEntity());
		@inv = inv.pNext;
		if (item !is null)
		{
			int type = item.pev.colormap-1;
			if (g_items[type].stackSize > 1 and type >= 0 and item.pev.button != g_items[type].stackSize)
			{
				int newTotal = 0;
				if (totals.exists(type))
					totals.get(type, newTotal);
				newTotal += item.pev.button;
				totals[type] = newTotal;
				
				item.pev.renderfx = -9999;
				
				g_EntityFuncs.Remove(item);
			}
		}
	}
	
	int spaceLeft = getInventorySpace(plr);
	array<string>@ totalKeys = totals.getKeys();
	
	for (uint i = 0; i < totalKeys.length(); i++)
	{
		if (atoi(totalKeys[i]) == addedType)
		{
			// newly added item should be stacked last in case there is overflow
			// e.g. if you collect too much wood, you shouldn't drop your stack of stone
			totalKeys.removeAt(i);
			totalKeys.insertLast(addedType);
			break;
		}
	}
	
	for (uint i = 0; i < totalKeys.length(); i++)
	{
		int type = atoi(totalKeys[i]);
		int total = 0;
		totals.get(totalKeys[i], total);
		
		if (total < 0)
		{
			// remove stacks
			@inv = plr.get_m_pInventory();
			while(inv !is null and total < 0)
			{
				CItemInventory@ item = cast<CItemInventory@>(inv.hItem.GetEntity());
				@inv = inv.pNext;
				if (item !is null)
				{
					if (item.pev.colormap-1 == type)
					{
						if (item.pev.button > -total)
						{
							giveItem(plr, type, item.pev.button + total, false, false);
							total = 0;
						}
						else
							total += item.pev.button;
						
						item.pev.renderfx = -9999;
						g_Scheduler.SetTimeout("delay_remove", 0, EHandle(item));
					}
				}
			}
		}
		while (total > 0)
		{
			if (spaceLeft-- > 0)
				giveItem(plr, type, Math.min(total, g_items[type].stackSize), false, false);
			else
			{
				g_PlayerFuncs.PrintKeyBindingString(plr, "Your inventory is full");
				return total;
			}
			total -= g_items[type].stackSize;
		}
	}
	
	return 0;
}

CBaseEntity@ spawnItem(Vector origin, int type, int amt)
{
	dictionary keys;
	keys["origin"] = origin.ToString();
	keys["model"] = "models/w_weaponbox.mdl";
	keys["weight"] = "0";
	keys["spawnflags"] = "" + (256 + 512 + 128);
	keys["solid"] = "0";
	keys["return_timelimit"] = "-1";
	keys["holder_can_drop"] = "1";
	keys["carried_hidden"] = "1";
	keys["target_on_drop"] = "item_dropped";
	keys["target_on_collect"] = "item_collected";
	keys["target_cant_collect"] = "item_cant_collect";
	
	if (type < 0 or type > ITEM_TYPES)
	{
		println("spawnItem: bad type " + type);
		return null;
	}
	Item@ item = g_items[type];
	
	keys["netname"] = item.title; // because m_szItemName doesn't work...
	keys["colormap"] = "" + (type+1); // +1 so that normal items don't appear as my custom ones
	keys["team"] = "0"; // so we ignore this in the item_collected callback
	
	keys["display_name"] = item.title;
	keys["description"] =  item.desc;
	
	if (item.stackSize == 1)
	{
		if (item.isWeapon)
		{
			if (amt >= 1)
				keys["button"] = "" + amt;
			amt = 1;
			
		}
		CBaseEntity@ lastSpawn = null;
		for (int i = 0; i < amt; i++)
		{
			@lastSpawn = g_EntityFuncs.CreateEntity("item_inventory", keys, true);
			lastSpawn.pev.origin = origin;
		}
		return lastSpawn;
	}
	else
	{
		keys["button"] = "" + amt;
		keys["display_name"] = g_items[type].title + "  (" + prettyNumber(amt) + ")";
		
		return g_EntityFuncs.CreateEntity("item_inventory", keys, true);
	}
}

// try to equip a weapon/item/ammo. Returns amount that couldn't be equipped
int equipItem(CBasePlayer@ plr, int type, int amt)
{
	if (type < 0 or type > ITEM_TYPES)
	{
		println("equipItem: bad type");
		return amt;
	}
	Item@ item = g_items[type];
	
	int barf = amt;
	if (item.isWeapon and item.stackSize > 1)
	{
		if (@plr.HasNamedPlayerItem(item.classname) == null)
		{
			plr.SetItemPickupTimes(0);
			plr.GiveNamedItem(item.classname);
		}
	
		int amtGiven = giveAmmo(plr, amt, item.ammoName);
		barf = amt - amtGiven;
		
		if (amtGiven > 0)
			g_SoundSystem.PlaySound(plr.edict(), CHAN_ITEM, "items/9mmclip1.wav", 1.0f, 1.0f, 0, 100);
	}
	else if (item.isWeapon and @plr.HasNamedPlayerItem(item.classname) == null)
	{
		plr.SetItemPickupTimes(0);
		plr.GiveNamedItem(item.classname);
		CBasePlayerWeapon@ wep = cast<CBasePlayerWeapon@>(@plr.HasNamedPlayerItem(item.classname));
		if (amt != -1)
			wep.m_iClip = amt;
		barf = -2;
	}
	else if (item.isAmmo)
	{
		int amtGiven = giveAmmo(plr, amt, item.classname);
		barf = amt - amtGiven;
		
		if (amtGiven > 0)
			g_SoundSystem.PlaySound(plr.edict(), CHAN_ITEM, "items/9mmclip1.wav", 1.0f, 1.0f, 0, 100);
	}
	else if (item.type == I_ARMOR)
	{
		if (plr.pev.armorvalue < 100)
		{
			plr.pev.armorvalue += ARMOR_VALUE;
			if (plr.pev.armorvalue > 100)
				plr.pev.armorvalue = 100;
			g_SoundSystem.PlaySound(plr.edict(), CHAN_ITEM, "items/ammopickup2.wav", 1.0f, 1.0f, 0, 100);
			amt -= 1;
		}
		barf = amt;
		//else
		//	g_PlayerFuncs.PrintKeyBindingString(plr, "Maximum armor equipped");
	}
	
	getPlayerState(plr).updateItemList();
	return barf;
}

int pickupItem(CBasePlayer@ plr, CBaseEntity@ item)
{
	int type = item.pev.colormap-1;
	if (type < 0 or type > ITEM_TYPES)
	{
		println("pickupItem: bad type");
		return item.pev.button > 0 ? item.pev.button : 1;
	}
	Item@ itemDef = g_items[type];
	
	return giveItem(plr, type, item.pev.button, false, true, true);
}

// returns # of items that couldn't be stored (e.g. could stack 100 more but was given 300: return 200)
int giveItem(CBasePlayer@ plr, int type, int amt, bool drop=false, bool combineStacks=true, bool tryToEquip=false)
{
	dictionary keys;
	keys["origin"] = plr.pev.origin.ToString();
	keys["model"] = "models/w_weaponbox.mdl";
	keys["weight"] = "0";
	keys["spawnflags"] = "" + (256 + 512 + 128);
	keys["solid"] = "0";
	keys["return_timelimit"] = "-1";
	keys["holder_can_drop"] = "1";
	keys["carried_hidden"] = "1";
	keys["target_on_drop"] = "item_dropped";
	keys["target_on_collect"] = "item_collected";
	keys["target_cant_collect"] = "item_cant_collect";
	keys["holder_keep_on_death"] = "1";
	keys["holder_keep_on_respawn"] = "1";
	
	plr.SetItemPickupTimes(0);
	
	if (type < 0 or type > ITEM_TYPES)
	{
		println("giveItem: bad type");
		return amt;
	}
	Item@ item = g_items[type];
	
	if (tryToEquip)
	{
		int barf = equipItem(plr, type, amt);
		if ((item.isWeapon and item.stackSize == 1 and barf == -2) or (item.stackSize > 1 and barf == 0))
			return 0;
		amt = barf;
	}
	
	keys["button"] = "1"; // will be giving at least 1x of something
	keys["netname"] = g_items[type].title; // because m_szItemName doesn't work...
	keys["colormap"] = "" + (type+1); // +1 so that normal items don't appear as my custom ones
	keys["team"] = drop ? "0" : "1"; // so we ignore this in the item_collected callback
	
	keys["display_name"] = g_items[type].title;
	keys["description"] =  g_items[type].desc;
	
	//if (showText)
	//	g_PlayerFuncs.PrintKeyBindingString(plr, "" + amt + "x " + g_items[type].title);
	
	int dropSpeed = Math.RandomLong(250, 400);
	int spaceLeft = getInventorySpace(plr);
	
	if (item.stackSize == 1)
	{
		if (!item.isWeapon)
		{
			for (int i = 0; i < amt; i++)
			{
				if (spaceLeft-- <= 0 and !drop)
				{
					g_PlayerFuncs.PrintKeyBindingString(plr, "Your inventory is full");
					getPlayerState(plr).updateItemList();
					return amt - i;
				}
				CBaseEntity@ ent = g_EntityFuncs.CreateEntity("item_inventory", keys, true);
				if (drop)
				{
					g_EngineFuncs.MakeVectors(plr.pev.angles);
					ent.pev.velocity = g_Engine.v_forward*dropSpeed;
					ent.pev.origin = plr.pev.origin;
				}
				else
					ent.Use(@plr, @plr, USE_ON, 0.0F);
			}
			if (amt < 0)
			{
				// inventory items
				InventoryList@ inv = plr.get_m_pInventory();
				while(inv !is null and amt < 0)
				{
					CItemInventory@ citem = cast<CItemInventory@>(inv.hItem.GetEntity());
					if (citem !is null and citem.pev.colormap-1 == type)
					{
						citem.pev.renderfx = -9999;
						g_Scheduler.SetTimeout("delay_remove", 0, EHandle(citem));
						amt++;
					}
					@inv = inv.pNext;
				}
			}
		}
		else
		{
			keys["button"] = "" + amt; // now button = ammo in clip
			if (spaceLeft <= 0 and !drop)
			{
				g_PlayerFuncs.PrintKeyBindingString(plr, "Your inventory is full");
				getPlayerState(plr).updateItemList();
				return 1;
			}
			CBaseEntity@ ent = g_EntityFuncs.CreateEntity("item_inventory", keys, true);
			if (drop)
			{
				g_EngineFuncs.MakeVectors(plr.pev.angles);
				ent.pev.origin = plr.pev.origin;
				ent.pev.velocity = g_Engine.v_forward*dropSpeed;
			}
			else
				ent.Use(@plr, @plr, USE_ON, 0.0F);
		}
	}
	else
	{
		keys["button"] = "" + amt;
		keys["display_name"] = item.title + "  (" + prettyNumber(amt) + ")";
		
		CBaseEntity@ ent = g_EntityFuncs.CreateEntity("item_inventory", keys, true);
		if (drop)
		{
			g_EngineFuncs.MakeVectors(Vector(0, plr.pev.angles.y, 0));
			ent.pev.velocity = g_Engine.v_forward*dropSpeed;
			item_dropped(plr, ent, USE_TOGGLE, 0);
		}
		else
			ent.Use(@plr, @plr, USE_ON, 0.0F);
		
		if (combineStacks)
		{
			int ret = combineItemStacks(plr, type);
			getPlayerState(plr).updateItemList();
			return ret;
		}
	}
	
	getPlayerState(plr).updateItemList();
	return 0;
}

array<string> getStackOptions(CBasePlayer@ plr, int itemId)
{
	array<string> options;
	Item@ invItem = g_items[itemId];
	
	string displayName = invItem.title;
	int amount = getItemCount(plr, itemId);
	int stackSize = Math.min(invItem.stackSize, amount);
	
	if (amount > 0)
		displayName += " (" + amount + ")";
	else
		return options;
	
	options.insertLast(displayName); // not an option but yolo
	
	for (int i = stackSize, k = 0; i >= Math.min(stackSize, 5) and k < 8; i /= 2, k++)
	{
		if (i != stackSize)
		{
			if (i > 10)
				i = (i / 10) * 10;
			else if (i < 10)
				i = 5;
		}
			
		string stackString = i;
		if (i < 10) stackString = "0" + stackString;
		if (i < 100) stackString = "0" + stackString;
		if (i < 1000) stackString = "0" + stackString;
		if (i < 10000) stackString = "0" + stackString;
		if (i < 100000) stackString = "0" + stackString;
		if (amount >= i and stackSize >= i) 
			options.insertLast(stackString);
	}
	if (stackSize != 1)
		options.insertLast("000001");
		
	return options;
}

// Player Menus

void playerMenuCallback(CTextMenu@ menu, CBasePlayer@ plr, int page, const CTextMenuItem@ item)
{
	if (item is null)
		return;
	string action;
	item.m_pUserData.retrieve(action);
	PlayerState@ state = getPlayerState(plr);
	
	if (int(action.Find("-menu")) != -1)
	{
		g_Scheduler.SetTimeout("openPlayerMenu", 0, @plr, action);
	}
	else if (action.Find("unequip-") == 0)
	{
		string name = action.SubString(8);
		if (name == "health")
			name = "weapon_syringe";
		if (name == "item_battery")
			name = "armor";
		
		CBasePlayerItem@ wep = plr.HasNamedPlayerItem(name);
		if (wep !is null)
		{
			CBasePlayerWeapon@ cwep = cast<CBasePlayerWeapon@>(wep);
			
			Item@ invItem = getItemByClassname(name);
			if (invItem !is null)
			{
				int clip = cwep.m_iClip;
				
				if (invItem.stackSize > 1)
					clip = plr.m_rgAmmo(g_PlayerFuncs.GetAmmoIndex(invItem.ammoName));
				
				if (giveItem(plr, invItem.type, clip) == 0)
				{					
					plr.RemovePlayerItem(wep);
					if (!invItem.isAmmo and invItem.stackSize > 1)
						plr.m_rgAmmo(g_PlayerFuncs.GetAmmoIndex(invItem.ammoName), 0);
					g_PlayerFuncs.PrintKeyBindingString(plr, invItem.title + " was moved your inventory");
				}
			}
			else
				println("Unknown weapon: " + name);		
		}
		else if (name == "armor")
		{
			if (plr.pev.armorvalue >= ARMOR_VALUE and giveItem(plr, I_ARMOR, 1) == 0)
			{
				plr.pev.armorvalue -= ARMOR_VALUE;
				g_SoundSystem.PlaySound(plr.edict(), CHAN_ITEM, "items/ammopickup1.wav", 1.0f, 1.0f, 0, 100);
			}
		}
		else
		{
			int ammoIdx = g_PlayerFuncs.GetAmmoIndex(name);
			int ammo = plr.m_rgAmmo(ammoIdx);
			if (ammo > 0)
			{
				Item@ ammoItem = getItemByClassname(name);
				
				if (ammoItem !is null)
				{
					int ammoLeft = giveItem(plr, ammoItem.type, ammo);
					plr.m_rgAmmo(ammoIdx, ammoLeft);
				}
				else
					println("Unknown ammo: " + name);
			}
		}

		g_Scheduler.SetTimeout("openPlayerMenu", 0, @plr, "unequip-menu");
	}
	else if (action.Find("equip-") == 0)
	{
		int itemId = atoi(action.SubString(6));
		Item@ invItem = g_items[itemId];
		
		if (invItem.stackSize > 1)
		{
			int amt = getItemCount(plr, invItem.type, false, true);
			int barf = equipItem(plr, invItem.type, amt);
			int given = amt-barf;
			if (given > 0)
				giveItem(plr, invItem.type, -given);
		}
		else if (invItem.isWeapon)
		{
			CItemInventory@ wep = getInventoryItem(plr, invItem.type);
			if (equipItem(plr, invItem.type, wep.pev.button) == 0)
				g_Scheduler.SetTimeout("delay_remove", 0, EHandle(wep));
		}
		
		g_Scheduler.SetTimeout("openPlayerMenu", 0.05, @plr, "equip-menu");
	}
	else if (action.Find("unstack-") == 0)
	{
		g_Scheduler.SetTimeout("openPlayerMenu", 0, @plr, action);
	}
	else if (action.Find("drop-") == 0)
	{
		int dropAmt = atoi(action.SubString(5,6));
		int dropType = atoi(action.SubString(12));
		
		if (dropType >= 0 and dropType < int(g_items.size()))
		{
			Item@ dropItem = g_items[dropType];
			
			int hasAmt = getItemCount(plr, dropItem.type, false);
			int giveInvAmt = Math.min(dropAmt, hasAmt);
			int dropLeft = dropAmt;
			
			int overflow = 0;
			if (giveInvAmt > 0)
			{
				giveItem(plr, dropType, -dropAmt); // decrease stack size
				dropLeft -= giveInvAmt;
			}
			
			bool noMoreAmmo = false;
			if (dropLeft > 0 and (dropItem.isAmmo or dropItem.stackSize > 1))
			{
				string cname = dropItem.isAmmo ? dropItem.classname : dropItem.ammoName;
				int ammoIdx = g_PlayerFuncs.GetAmmoIndex(cname);
				int ammo = plr.m_rgAmmo(ammoIdx);
				int giveAmmo = Math.min(ammo, dropLeft);
				
				noMoreAmmo = ammo <= giveAmmo;
				
				if (giveAmmo > 0)
				{
					plr.m_rgAmmo(ammoIdx, ammo - giveAmmo);
					dropLeft -= giveAmmo;
				}
			}
			
			giveItem(plr, dropType, dropAmt - dropLeft, true); // drop selected/max amount
			if (!dropItem.isAmmo and dropItem.stackSize > 1 and noMoreAmmo)
			{
				g_EntityFuncs.Remove(@plr.HasNamedPlayerItem(dropItem.classname));
			}
			
			g_Scheduler.SetTimeout("openPlayerMenu", 0, @plr, "unstack-" + dropType);
		}
	}
	else if (action.Find("craft-") == 0)
	{
		int imenu = atoi(action.SubString(6,1));
		int itemType = atoi(action.SubString(8));
		if (itemType >= 0 and itemType < int(g_items.size()))
		{
			Item@ craftItem = g_items[itemType];
			
			bool canCraft = true;
			string needMore = "";
			if (!g_free_build)
			{
				for (uint i = 0; i < craftItem.costs.size(); i++)
				{
					int costType = craftItem.costs[i].type;
					if (getItemCount(plr, costType, true, true) < craftItem.costs[i].amt)
					{
						needMore = needMore.Length() > 0 ? needMore + " and " + g_items[costType].title : g_items[costType].title;
						canCraft = false;
					}
				}
			}
			if (canCraft)
			{
				int amt = craftItem.isWeapon and craftItem.stackSize == 1 ? 0 : 1;
				if (craftItem.type == I_9MM) amt = 5;
				if (craftItem.type == I_556) amt = 5;
				if (craftItem.type == I_ARROW) amt = 2;
				if (!g_free_build)
				{
					for (uint i = 0; i < craftItem.costs.size(); i++)
					{
						println("Subtract cost: " + g_items[craftItem.costs[i].type].title + " " + (-craftItem.costs[i].amt));
						giveItem(plr, craftItem.costs[i].type, -craftItem.costs[i].amt);
					}
				}
				int barf = giveItem(plr, itemType, amt, false, true, true);
				if (barf == 0)
				{
					g_SoundSystem.PlaySound(plr.edict(), CHAN_ITEM, "sc_rust/build1.ogg", 1.0f, 1.0f, 0, Math.RandomLong(140, 160));
				}
				else
				{
					println("Barfed " + barf + " of " + amt);
					g_PlayerFuncs.PrintKeyBindingString(plr, "Inventory is full");
					// undo cost
					if (!g_free_build)
					{
						for (uint i = 0; i < craftItem.costs.size(); i++)
							giveItem(plr, craftItem.costs[i].type, craftItem.costs[i].amt);
					}
				}
			}
			else
				g_PlayerFuncs.PrintKeyBindingString(plr, "You need more " + needMore);			
		}
		
		string submenu;
		switch(imenu)
		{
			case 0: submenu = "build-menu"; break;
			case 1: submenu = "item-menu"; break;
			case 2: submenu = "tool-menu"; break;
			case 3: submenu = "medical-menu"; break;
			case 4: submenu = "weapon-menu"; break;
			case 5: submenu = "explode-menu"; break;
			case 6: submenu = "ammo-menu"; break;
			default: submenu = "craft-menu"; break;
		}
		
		g_Scheduler.SetTimeout("openPlayerMenu", 0, @plr, submenu);
	}
	
	menu.Unregister();
	@menu = null;
}

void openPlayerMenu(CBasePlayer@ plr, string subMenu)
{
	PlayerState@ state = getPlayerState(plr);
	state.initMenu(plr, playerMenuCallback);
	
	if (subMenu == "build-menu") 
	{
		state.menu.SetTitle("Actions -> Craft -> Exterior Items:\n");
		state.menu.AddItem("Back\n", any("craft-menu"));
		state.menu.AddItem(g_items[I_WOOD_DOOR].getCraftText(), any("craft-0-" + I_WOOD_DOOR));
		state.menu.AddItem(g_items[I_METAL_DOOR].getCraftText(), any("craft-0-" + I_METAL_DOOR));
		state.menu.AddItem(g_items[I_WOOD_BARS].getCraftText(), any("craft-0-" + I_WOOD_BARS));
		state.menu.AddItem(g_items[I_METAL_BARS].getCraftText(), any("craft-0-" + I_METAL_BARS));
		state.menu.AddItem(g_items[I_WOOD_SHUTTERS].getCraftText(), any("craft-0-" + I_WOOD_SHUTTERS));
		state.menu.AddItem(g_items[I_HIGH_WOOD_WALL].getCraftText(), any("craft-0-" + I_HIGH_WOOD_WALL));
		state.menu.AddItem(g_items[I_HIGH_STONE_WALL].getCraftText(), any("craft-0-" + I_HIGH_STONE_WALL));
	}
	else if (subMenu == "item-menu") 
	{
		state.menu.SetTitle("Actions -> Craft -> Interior Items:\n");
		state.menu.AddItem("Back\n", any("craft-menu"));
		state.menu.AddItem(g_items[I_CODE_LOCK].getCraftText(), any("craft-1-" + I_CODE_LOCK));
		state.menu.AddItem(g_items[I_SMALL_CHEST].getCraftText(), any("craft-1-" + I_SMALL_CHEST));
		state.menu.AddItem(g_items[I_LARGE_CHEST].getCraftText(), any("craft-1-" + I_LARGE_CHEST));
		//state.menu.AddItem("Camp Fire", any("fire")); // let's keep things simple and not have a hunger/thirst system
		state.menu.AddItem(g_items[I_FURNACE].getCraftText(), any("craft-1-" + I_FURNACE));
		state.menu.AddItem(g_items[I_LADDER].getCraftText(), any("craft-1-" + I_LADDER));
		state.menu.AddItem(g_items[I_LADDER_HATCH].getCraftText(), any("craft-1-" + I_LADDER_HATCH));
		state.menu.AddItem(g_items[I_TOOL_CUPBOARD].getCraftText(), any("craft-1-" + I_TOOL_CUPBOARD));
		//state.menu.AddItem("Large Furnace", any("large-furnace"));
		//state.menu.AddItem("Stash", any("stash"));
		//state.menu.AddItem("Sleeping Bag", any("sleeping-bag"));
	}
	else if (subMenu == "tool-menu")
	{
		state.menu.SetTitle("Actions -> Craft -> Tools:\n");
		state.menu.AddItem("Back\n", any("craft-menu"));
		state.menu.AddItem(g_items[I_ROCK].getCraftText(), any("craft-2-" + I_ROCK));
		//state.menu.AddItem("Torch", any("craft-" + I_TORCH)); // no night time due to sc bug
		state.menu.AddItem(g_items[I_BUILDING_PLAN].getCraftText(), any("craft-2-" + I_BUILDING_PLAN));
		state.menu.AddItem(g_items[I_HAMMER].getCraftText(), any("craft-2-" + I_HAMMER));
		state.menu.AddItem(g_items[I_STONE_HATCHET].getCraftText(), any("craft-2-" + I_STONE_HATCHET));
		state.menu.AddItem(g_items[I_STONE_PICKAXE].getCraftText(), any("craft-2-" + I_STONE_PICKAXE));
		state.menu.AddItem(g_items[I_METAL_HATCHET].getCraftText(), any("craft-2-" + I_METAL_HATCHET));
		state.menu.AddItem(g_items[I_METAL_PICKAXE].getCraftText(), any("craft-2-" + I_METAL_PICKAXE));
	}
	else if (subMenu == "medical-menu")
	{
		state.menu.SetTitle("Actions -> Craft -> Medical:\n");
		
		state.menu.AddItem("Back\n", any("craft-menu"));
		//state.menu.AddItem("Bandage", any("bandage"));
		state.menu.AddItem(g_items[I_SYRINGE].getCraftText(), any("craft-3-" + I_SYRINGE));
		//state.menu.AddItem("Medkit", any("small-medkit"));
		state.menu.AddItem(g_items[I_ARMOR].getCraftText(), any("craft-3-" + I_ARMOR));
		//state.menu.AddItem("Large Medkit", any("large-medkit"));
		state.menu.AddItem("Guitar", any("craft-3-" + I_GUITAR));
		
	}
	else if (subMenu == "weapon-menu")
	{
		state.menu.SetTitle("Actions -> Craft -> Weapons:\n");
		state.menu.AddItem("Back\n", any("craft-menu"));
		state.menu.AddItem(g_items[I_CROWBAR].getCraftText(), any("craft-4-" + I_CROWBAR));
		state.menu.AddItem(g_items[I_BOW].getCraftText(), any("craft-4-" + I_BOW));
		state.menu.AddItem(g_items[I_DEAGLE].getCraftText(), any("craft-4-" + I_DEAGLE));
		state.menu.AddItem(g_items[I_SHOTGUN].getCraftText(), any("craft-4-" + I_SHOTGUN));
		state.menu.AddItem(g_items[I_SNIPER].getCraftText(), any("craft-4-" + I_SNIPER));
		state.menu.AddItem(g_items[I_UZI].getCraftText(), any("craft-4-" + I_UZI));
		state.menu.AddItem(g_items[I_SAW].getCraftText(), any("craft-4-" + I_SAW));
	}
	else if (subMenu == "explode-menu")
	{
		state.menu.SetTitle("Actions -> Craft -> Explosives:\n");
		state.menu.AddItem("Back\n", any("craft-menu"));
		state.menu.AddItem(g_items[I_FLAMETHROWER].getCraftText(), any("craft-5-" + I_FLAMETHROWER));
		state.menu.AddItem(g_items[I_RPG].getCraftText(), any("craft-5-" + I_RPG));
		state.menu.AddItem(g_items[I_GRENADE].getCraftText(), any("craft-5-" + I_GRENADE));
		state.menu.AddItem(g_items[I_SATCHEL].getCraftText(), any("craft-5-" + I_SATCHEL));
		state.menu.AddItem(g_items[I_C4].getCraftText() + "\n", any("craft-5-" + I_C4));
	}
	else if (subMenu == "ammo-menu")
	{
		state.menu.SetTitle("Actions -> Craft -> Ammo:\n");
		state.menu.AddItem("Back\n", any("craft-menu"));
		state.menu.AddItem(g_items[I_ARROW].getCraftText(), any("craft-6-" + I_ARROW));
		state.menu.AddItem(g_items[I_9MM].getCraftText(), any("craft-6-" + I_9MM));
		state.menu.AddItem(g_items[I_556].getCraftText(), any("craft-6-" + I_556));
		state.menu.AddItem(g_items[I_BUCKSHOT].getCraftText(), any("craft-6-" + I_BUCKSHOT));
		state.menu.AddItem(g_items[I_ROCKET].getCraftText(), any("craft-6-" + I_ROCKET));
		//state.menu.AddItem(g_items[I_FUEL].getCraftText() + "\n", any("craft-6-" + I_FUEL));
	}
	else if (subMenu == "craft-menu")
	{
		state.menu.SetTitle("Actions -> Craft:\n");
		state.menu.AddItem("Exterior Items", any("build-menu"));
		state.menu.AddItem("Interior Items", any("item-menu"));
		state.menu.AddItem("Tools", any("tool-menu"));
		state.menu.AddItem("Medical / Armor", any("medical-menu"));
		state.menu.AddItem("Weapons", any("weapon-menu"));
		state.menu.AddItem("Explosives", any("explode-menu"));
		state.menu.AddItem("Ammo\n\n", any("ammo-menu"));
	}
	else if (subMenu == "equip-menu")
	{
		state.menu.SetTitle("Actions -> Equip:\n");
		
		array<Item@> all_items = getAllItems(plr);
		int options = 0;
		
		for (uint i = 0; i < all_items.size(); i++)
		{
			Item@ item = all_items[i];
			if (!item.isWeapon and !item.isAmmo and item.type != I_ARMOR)
				continue;
			int count = getItemCount(plr, item.type, false, true);
			if (count <= 0)
				continue;
				
			options++;
			string displayName = item.title;
			if (item.stackSize > 1)
				displayName += " (" + count + ")";
			state.menu.AddItem(displayName, any("equip-" + item.type));
		}
		
		if (options == 0)
		{
			g_PlayerFuncs.PrintKeyBindingString(plr, "You don't have any equippable items");
			openPlayerMenu(plr, "");
			return;
		}
	}
	else if (subMenu == "unequip-menu")
	{
		state.menu.SetTitle("Actions -> Unequip:\n");
		
		array<Item@> all_items = getAllItems(plr);
		int options = 0;
		
		for (uint i = 0; i < all_items.size(); i++)
		{
			Item@ item = all_items[i];
			int count = getItemCount(plr, item.type, true, false);
			if (count <= 0)
				continue;
				
			options++;
			string displayName = item.title;
			if (item.stackSize > 1)
				displayName += " (" + count + ")";
			state.menu.AddItem(displayName, any("unequip-" + item.classname));
		}
		
		if (options == 0)
		{
			g_PlayerFuncs.PrintKeyBindingString(plr, "You don't have any items equipped");
			openPlayerMenu(plr, "");
			return;
		}
	}
	else if (subMenu == "drop-stack-menu")
	{
		state.menu.SetTitle("Actions -> Drop Stackables:\n");
		
		array<Item@> all_items = getAllItems(plr);
		int options = 0;
		
		for (uint i = 0; i < all_items.size(); i++)
		{
			Item@ item = all_items[i];
			if (item.stackSize <= 1)
				continue;
			int count = getItemCount(plr, item.type, true, true);
			if (count <= 0)
				continue;
				
			options++;
			string displayName = item.title;
			if (item.stackSize > 1)
				displayName += " (" + count + ")";
			state.menu.AddItem(displayName, any("unstack-" + item.type));
		}
		
		if (options == 0)
		{
			g_PlayerFuncs.PrintKeyBindingString(plr, "You don't have any stackable items");
			openPlayerMenu(plr, "");
			return;
		}
	}
	else if (subMenu.Find("unstack-") == 0)
	{
		int itemId = atoi(subMenu.SubString(8));
		array<string> stackOptions = getStackOptions(plr, itemId);
		if (stackOptions.size() == 0)
		{
			openPlayerMenu(plr, "drop-stack-menu");
			return;
		}
		
		state.menu.SetTitle("Actions -> Drop " + stackOptions[0] + ":\n");
		for (uint i = 1; i < stackOptions.size(); i++)
		{
			int count = atoi(stackOptions[i]);
			state.menu.AddItem("Drop " + prettyNumber(count), any("drop-" + stackOptions[i] + "-" + itemId));
		}
	}
	else
	{
		state.menu.SetTitle("Actions:\n");
		state.menu.AddItem("Craft", any("craft-menu"));
		state.menu.AddItem("Equip", any("equip-menu"));
		state.menu.AddItem("Unequip", any("unequip-menu"));
		state.menu.AddItem("Drop Stackables", any("drop-stack-menu"));
	}
	
	state.openMenu(plr);
}

void lootMenuCallback(CTextMenu@ menu, CBasePlayer@ plr, int page, const CTextMenuItem@ mitem)
{
	if (mitem is null)
		return;
	string action;
	mitem.m_pUserData.retrieve(action);
	PlayerState@ state = getPlayerState(plr);
	CBaseEntity@ chest = state.currentChest;
	if (chest is null)
		return;
	func_breakable_custom@ c_chest = cast<func_breakable_custom@>(CastToScriptClass(chest));
	string chestName = chest.pev.colormap == B_FURNACE ? "Furnace" : "Chest";
	
	string submenu = "";
	
	if (action == "do-give")
	{
		submenu = "give";
	}
	else if (action == "do-take")
	{
		submenu = "take";
	}
	else if (action.Find("givestack-") == 0)
	{
		int amt = atoi(action.SubString(10,6));
		int giveType = atoi(action.SubString(17));
		
		submenu = "givestack-" + giveType;
		
		if (giveType >= 0 and giveType < int(g_items.size()))
		{
			Item@ depositItem = g_items[giveType];
			
			int hasAmt = getItemCount(plr, depositItem.type, false);
			int giveInvAmt = Math.min(amt, hasAmt);
			
			int overflow = 0;
			if (giveInvAmt > 0)
			{			
				CBaseEntity@ newItem = spawnItem(chest.pev.origin, depositItem.type, giveInvAmt);
				newItem.pev.effects = EF_NODRAW;
				overflow = c_chest.depositItem(EHandle(newItem));
				giveInvAmt -= overflow;
				
				giveItem(plr, depositItem.type, -giveInvAmt);
			}
			
			if (overflow == 0 and depositItem.isAmmo or (depositItem.isWeapon and depositItem.stackSize > 1))
			{
				amt -= giveInvAmt; // now give from equipped ammo if not enough was in inventory
				
				string ammoName = depositItem.classname;
				if (!depositItem.isAmmo and depositItem.stackSize > 1)
					ammoName = depositItem.ammoName;
				int ammoIdx = g_PlayerFuncs.GetAmmoIndex(ammoName);
				int ammo = plr.m_rgAmmo(ammoIdx);
				int giveAmmo = Math.min(ammo, amt);
				
				if (giveAmmo > 0)
				{			
					CBaseEntity@ newItem = spawnItem(chest.pev.origin, depositItem.type, giveAmmo);
					newItem.pev.effects = EF_NODRAW;
					newItem.pev.renderfx = -9999;
					overflow = c_chest.depositItem(EHandle(newItem));
					giveAmmo -= overflow;
					
					giveItem(plr, depositItem.type, -giveAmmo);
					plr.m_rgAmmo(ammoIdx, ammo - giveAmmo);
				}
				
				if (giveAmmo >= ammo and depositItem.type == I_SYRINGE)
					g_EntityFuncs.Remove(plr.HasNamedPlayerItem("weapon_syringe"));
			}
			
			if (overflow > 0)
				g_PlayerFuncs.PrintKeyBindingString(plr, chestName + " is full");
			
			if (overflow < amt)
			{
				g_SoundSystem.PlaySound(plr.edict(), CHAN_ITEM, "player/pl_jump2.wav", 1.0f, 1.0f, 0, Math.RandomLong(80,100));
				g_PlayerFuncs.PrintKeyBindingString(plr, depositItem.title + " (" + (amt - overflow) + ") was put into the " 
																+ chestName + "\n\n" + chestName + " capacity: " + 
																c_chest.items.size() + " / " + c_chest.capacity());
			}
		}
	}
	else if (action.Find("give-") == 0)
	{
		string itemName = action.SubString(5);
		int giveType = atoi(itemName);
		
		submenu = "give";
		
		if (giveType >= 0 and giveType < int(g_items.size()))
		{
			Item@ depositItem = g_items[giveType];
			
			if (depositItem.stackSize > 1)
				submenu = "givestack-" + depositItem.type;
			else if (c_chest.spaceLeft() > 0)
			{
				// currently held item/weapon/ammo
				CBasePlayerItem@ wep = plr.HasNamedPlayerItem(depositItem.classname);
				if (wep !is null)
				{
					int amt = depositItem.stackSize > 1 ? wep.pev.button : 1;
					CBaseEntity@ newItem = spawnItem(chest.pev.origin, depositItem.type, amt);
					newItem.pev.button = cast<CBasePlayerWeapon@>(wep).m_iClip;
					newItem.pev.effects = EF_NODRAW;
					c_chest.depositItem(EHandle(newItem));
					
					plr.RemovePlayerItem(wep);
					g_PlayerFuncs.PrintKeyBindingString(plr, depositItem.title + " was put into the " + chestName + "\n\n" + 
															chestName + " capacity: " + 
															c_chest.items.size() + " / " + c_chest.capacity());
				}
				else
				{
					InventoryList@ inv = plr.get_m_pInventory();
					while(inv !is null)
					{
						CItemInventory@ item = cast<CItemInventory@>(inv.hItem.GetEntity());
						if (item !is null and item.pev.colormap == giveType+1)
						{
							CBaseEntity@ newItem = spawnItem(chest.pev.origin, depositItem.type, 1);
							newItem.pev.effects = EF_NODRAW;
							newItem.pev.renderfx = -9999;
							c_chest.depositItem(EHandle(newItem));
							
							g_Scheduler.SetTimeout("delay_remove", 0, EHandle(item));
							break;
						}
						@inv = inv.pNext;
					}
				}
				g_SoundSystem.PlaySound(plr.edict(), CHAN_ITEM, "player/pl_jump2.wav", 1.0f, 1.0f, 0, Math.RandomLong(80,100));
			}
			else
				g_PlayerFuncs.PrintKeyBindingString(plr, chestName + " is full");
		}			
	}
	else if (action.Find("loot-") == 0)
	{
		string itemDesc = action.SubString(5);
		
		int sep = int(itemDesc.Find(","));
		int type = atoi( itemDesc.SubString(0, sep) );
		int amt = atoi( itemDesc.SubString(sep+1) );
		
		bool found = false;
		if (chest.IsPlayer() and chest.pev.deadflag > 0)
		{
			Item@ gItem = getItemByClassname(itemDesc);
			CBasePlayer@ corpse = cast<CBasePlayer@>(chest);
			
			InventoryList@ inv = corpse.get_m_pInventory();
			while (inv !is null)
			{
				CItemInventory@ item = cast<CItemInventory@>(inv.hItem.GetEntity());
				@inv = inv.pNext;
				if (item !is null and item.pev.colormap == gItem.type)
				{
					if (giveItem(plr, gItem.type, gItem.stackSize > 1 ? item.pev.button : 1) == 0)
					{
						item.pev.renderfx = -9999;
						g_Scheduler.SetTimeout("delay_remove", 0, EHandle(item));
					}
					
					found = true;
					break;
				}
			}
			
			if (!found)
			{
				CBasePlayerItem@ hasItem = corpse.HasNamedPlayerItem(itemDesc);
				if (hasItem !is null and gItem !is null)
				{
					if (plr.HasNamedPlayerItem(itemDesc) is null)
					{
						plr.SetItemPickupTimes(0);
						plr.GiveNamedItem(itemDesc);
						corpse.RemovePlayerItem(hasItem);
					}
					else if (giveItem(plr, gItem.type, 1) == 0)
						corpse.RemovePlayerItem(hasItem);
						
					found = true;
				}
			}
			
			if (!found)
			{
				int ammoIdx = g_PlayerFuncs.GetAmmoIndex(itemDesc);
				int ammo = corpse.m_rgAmmo(ammoIdx);
				if (ammo > 0)
				{
					int amtGiven = giveAmmo(plr, ammo, itemDesc);
					
					int ammoLeft = ammo - amtGiven;
					Item@ ammoItem = getItemByClassname(itemDesc);
					
					if (ammoItem !is null)
					{
						ammoLeft = giveItem(plr, ammoItem.type, ammoLeft);
						
						if (ammoLeft < ammo)
							g_SoundSystem.PlaySound(plr.edict(), CHAN_ITEM, "items/9mmclip1.wav", 1.0f, 1.0f, 0, 100);
						
						corpse.m_rgAmmo(ammoIdx, ammoLeft);
					}
					else
						println("Unknown ammo: " + itemDesc);
						
					found = true;
				}
			}
			
			if (found)
			{
				// update items in corpse
				for (uint i = 0; i < g_corpses.size(); i++)
				{
					if (!g_corpses[i])
						continue;
						
					player_corpse@ skeleton = cast<player_corpse@>(CastToScriptClass(g_corpses[i]));
					if (skeleton.owner.IsValid() and skeleton.owner.GetEntity().entindex() == corpse.entindex())
						skeleton.Update();
				}
			}
		}
		else if (chest.pev.classname == "player_corpse" or chest.pev.classname == "func_breakable_custom")
		{
			bool is_corpse = chest.pev.classname == "player_corpse";
			array<EHandle>@ items = is_corpse ? @cast<player_corpse@>(CastToScriptClass(chest)).items :
												@cast<func_breakable_custom@>(CastToScriptClass(chest)).items;
		
			for (uint i = 0; i < items.size(); i++)
			{
				if (!items[i])
					continue;
				CBaseEntity@ item = items[i];
				int takeType = item.pev.colormap-1;
				if (takeType < 0 or takeType >= int(g_items.size()))
					continue;
				int oldAmt = getItemCount(plr, type);
				Item@ takeItem = g_items[takeType];

				if (item.pev.colormap == type and item.pev.button == amt)
				{
					// try equipping immediately
					int amtLeft = pickupItem(plr, item);
						
					if (amtLeft > 0)
						item.pev.button = amtLeft;
					else
					{
						g_EntityFuncs.Remove(item);
						items.removeAt(i);
						i--;
						if (items.size() == 0 and chest.pev.colormap == E_SUPPLY_CRATE)
						{
							func_breakable_custom@ crate = cast<func_breakable_custom@>(CastToScriptClass(chest));
							crate.Destroy();
						}
					}
					
					found = true;
					break;
				}
			}
			
			submenu = "take";
		}
		if (!found)
		{
			g_PlayerFuncs.PrintKeyBindingString(plr, "Item no longer exists");
		}
		else
		{
			g_SoundSystem.PlaySound(plr.edict(), CHAN_BODY, "player/pl_jump2.wav", 1.0f, 1.0f, 0, Math.RandomLong(120,140));
		}
	}
	
	g_Scheduler.SetTimeout("openLootMenu", 0.05, @plr, @chest, submenu);
}

void openLootMenu(CBasePlayer@ plr, CBaseEntity@ corpse, string submenu="")
{
	PlayerState@ state = getPlayerState(plr);
	state.initMenu(plr, lootMenuCallback);
	state.currentChest = corpse;
	
	string title = "Loot " + corpse.pev.netname + "'s corpse:\n";
	
	int numItems = 0;
	if (corpse.IsPlayer())
	{
		CBasePlayer@ pcorpse = cast<CBasePlayer@>(corpse);
		
		array<Item@> all_items = getAllItems(pcorpse);
		
		for (uint i = 0; i < all_items.size(); i++)
		{
			Item@ item = all_items[i];
			int count = getItemCount(pcorpse, item.type, true, true);
			if (count <= 0)
				continue;
				
			numItems++;
			string displayName = item.title;
			if (item.stackSize > 1)
				displayName += " (" + count + ")";
			state.menu.AddItem(displayName, any("loot-" + item.classname));
		}
	}
	else if (corpse.pev.classname == "player_corpse")
	{
		player_corpse@ pcorpse = cast<player_corpse@>(CastToScriptClass(corpse));
		for (uint i = 0; i < pcorpse.items.size(); i++)
		{
			if (!pcorpse.items[i])
				continue;
				
			CBaseEntity@ item = pcorpse.items[i];
			state.menu.AddItem(getItemDisplayName(item), any("loot-" + item.pev.colormap + "," + item.pev.button));
		}
		numItems = pcorpse.items.size();
	}
	else if (corpse.IsBSPModel()) // chest
	{
		numItems++;
		
		switch(corpse.pev.colormap)
		{
			case B_SMALL_CHEST:
				title = "Small Chest:";
				break;
			case B_LARGE_CHEST:
				title = "Large Chest:";
				break;
			case B_FURNACE:
				title = "Furnace:";
			case E_SUPPLY_CRATE:
				title = "Supply Crate:";
				break;
		}
		
		bool isAirdrop = corpse.pev.colormap == E_SUPPLY_CRATE;
		
		if (submenu == "give")
		{			
			title += " -> Give";
			bool isFurnace = corpse.pev.colormap == B_FURNACE;
		
			array<Item@> all_items = getAllItems(plr);
			int options = 0;
			
			for (uint i = 0; i < all_items.size(); i++)
			{
				Item@ item = all_items[i];
				if (isFurnace)
				{
					if (item.type != I_WOOD and item.type != I_METAL_ORE and item.type != I_HQMETAL_ORE)
						continue;
				}
				int count = getItemCount(plr, item.type, true, true);
				if (count <= 0)
					continue;
					
				options++;
				string displayName = item.title;
				if (item.stackSize > 1)
					displayName += " (" + count + ")";
				state.menu.AddItem(displayName, any("give-" + item.type));
			}
			
			if (options == 0)
				state.menu.AddItem("(no items to gives)", any(""));
		}
		else if (submenu.Find("givestack-") == 0)
		{
			int itemId = atoi(submenu.SubString(10));
			array<string> stackOptions = getStackOptions(plr, itemId);
			if (stackOptions.size() == 0)
			{
				openLootMenu(plr, corpse, "give");
				return;
			}
			
			title += " -> Give " + stackOptions[0];
			for (uint i = 1; i < stackOptions.size(); i++)
			{
				int count = atoi(stackOptions[i]);
				state.menu.AddItem("Give " + prettyNumber(count), any("givestack-" + stackOptions[i] + "-" + itemId));
			}
		}
		else if (submenu == "take" or isAirdrop)
		{
			if (!isAirdrop)
				title += " -> Take";
			
			func_breakable_custom@ c_chest = cast<func_breakable_custom@>(CastToScriptClass(corpse));
			
			for (uint i = 0; i < c_chest.items.size(); i++)
			{
				CBaseEntity@ item = c_chest.items[i];
				state.menu.AddItem(getItemDisplayName(item), any("loot-" + item.pev.colormap + "," + item.pev.button));
			}
			
			if (c_chest.items.size() == 0)
				state.menu.AddItem("(empty)", any(""));
		}
		else
		{
			state.menu.AddItem("Give", any("do-give"));
			state.menu.AddItem("Take", any("do-take"));
		}
		
	}
	
	state.menu.SetTitle(title + "\n");
	
	if (numItems == 0)
	{
		g_PlayerFuncs.PrintKeyBindingString(plr, "Nothing left to loot");
		state.currentChest = null;
		return;
	}
	
	
	state.openMenu(plr);
}

// Usable items

void rotate_door(CBaseEntity@ door, bool playSound)
{	
	if (door.pev.iuser1 == 1) // currently moving?
		return;
		
	bool opening = door.pev.groupinfo == 0;
	Vector dest = opening ? door.pev.vuser2 : door.pev.vuser1;
	
	float speed = 280;
	
	string soundFile = "";
	if (door.pev.colormap == B_WOOD_DOOR) {
		soundFile = opening ? "sc_rust/door_wood_open.ogg" : "sc_rust/door_wood_close.ogg";
	}
	if (door.pev.colormap == B_METAL_DOOR or door.pev.colormap == B_LADDER_HATCH) {
		soundFile = opening ? "sc_rust/door_metal_open.ogg" : "sc_rust/door_metal_close.ogg";
	}
	if (door.pev.colormap == B_LADDER_HATCH) {
		soundFile = opening ? "sc_rust/door_metal_open.ogg" : "sc_rust/door_metal_close2.ogg";
		speed = 200;
	}
	if (door.pev.colormap == B_WOOD_SHUTTERS) {
		soundFile = opening ? "sc_rust/shutters_wood_open.ogg" : "sc_rust/shutters_wood_close.ogg";
		speed = 128;
	}
	
	if (playSound) {
		g_SoundSystem.PlaySound(door.edict(), CHAN_ITEM, soundFile, 1.0f, 1.0f, 0, 90 + Math.RandomLong(0, 20));
	}	
	
	if (dest != door.pev.angles) {
		AngularMove(door, dest, speed);
		
		if (door.pev.colormap == B_LADDER_HATCH) {
			CBaseEntity@ ladder = g_EntityFuncs.FindEntityByTargetname(null, "ladder_hatch" + door.pev.team);
			
			if (ladder !is null)
			{
				int oldcolormap = ladder.pev.colormap;
				ladder.Use(@ladder, @ladder, USE_TOGGLE, 0.0F);
				ladder.pev.colormap = oldcolormap;
			}
			else
				println("ladder_hatch" + door.pev.team + " not found!");
			
		}
	}
	
	door.pev.groupinfo = 1 - door.pev.groupinfo;
}

void lock_object(CBaseEntity@ obj, string code, bool unlock)
{
	string newModel = "";
	if (obj.pev.colormap == B_WOOD_DOOR)
		newModel = "b_wood_door";
	if (obj.pev.colormap == B_METAL_DOOR)
		newModel = "b_metal_door";
	if (obj.pev.colormap == B_LADDER_HATCH)
		newModel = "b_ladder_hatch_door";
	newModel += unlock ? "_unlock" : "_lock";
	
	if (code.Length() > 0)
		obj.pev.noise3 = code;
	
	if (newModel.Length() > 0)
	{
		int oldcolormap = obj.pev.colormap;
		g_EntityFuncs.SetModel(obj, getModelFromName(newModel));
		obj.pev.colormap = oldcolormap;
	}
	
	obj.pev.body = unlock ? 0 : 1;
}

void waitForCode(CBasePlayer@ plr)
{
	PlayerState@ state = getPlayerState(plr);
	if (state.codeTime > 0)
	{
		state.codeTime = 0;
		g_PlayerFuncs.PrintKeyBindingString(plr, "Time expired");
	}
}

void codeLockMenuCallback(CTextMenu@ menu, CBasePlayer@ plr, int page, const CTextMenuItem@ item)
{
	if (item is null)
		return;
	string action;
	item.m_pUserData.retrieve(action);
	PlayerState@ state = getPlayerState(plr);
	CBaseEntity@ lock = state.currentLock;

	if (action == "code" or action == "unlock-code") {
		state.codeTime = 1;
		string msg = "Type the 4-digit code into chat now";
		PrintKeyBindingStringLong(plr, msg);
	}
	if (action == "unlock") {
		lock_object(state.currentLock, "", true);
		g_SoundSystem.PlaySound(lock.edict(), CHAN_ITEM, "sc_rust/code_lock_beep.ogg", 1.0f, 1.0f, 0, 100);
	}
	if (action == "lock") {
		lock_object(state.currentLock, "", false);
		g_SoundSystem.PlaySound(lock.edict(), CHAN_ITEM, "sc_rust/code_lock_beep.ogg", 1.0f, 1.0f, 0, 55);
	}
	if (action == "remove")
	{	
		string newModel = "";
		if (lock.pev.colormap == B_WOOD_DOOR)
			newModel = "b_wood_door";
		if (lock.pev.colormap == B_METAL_DOOR)
			newModel = "b_metal_door";
		if (lock.pev.colormap == B_LADDER_HATCH)
			newModel = "b_ladder_hatch_door";
		int oldcolormap = lock.pev.colormap;
		g_EntityFuncs.SetModel(lock, getModelFromName(newModel));
		lock.pev.colormap = oldcolormap;
		g_SoundSystem.PlaySound(lock.edict(), CHAN_ITEM, "sc_rust/code_lock_place.ogg", 1.0f, 1.0f, 0, 100);		
		giveItem(@plr, I_CODE_LOCK, 1);
		
		lock.pev.button = 0;
		lock.pev.body = 0;
		lock.pev.noise3 = "";
	}
	
	menu.Unregister();
	@menu = null;
}

void openCodeLockMenu(CBasePlayer@ plr, CBaseEntity@ door)
{
	PlayerState@ state = getPlayerState(plr);
	state.initMenu(plr, codeLockMenuCallback);
	
	state.menu.SetTitle("Code Lock:\n\n");
	
	bool authed = state.isAuthed(door);
	
	if (door.pev.body == 1) // locked
	{
		if (authed)
		{
			state.menu.AddItem("Change Code\n", any("code"));
			state.menu.AddItem("Unlock\n", any("unlock"));
			state.menu.AddItem("Remove Lock\n", any("remove"));
		}
		else
		{
			state.menu.AddItem("Unlock with code\n", any("unlock-code"));
		}
		
	}
	else // unlocked
	{
		state.menu.AddItem("Change Code\n", any("code"));
		if (string(door.pev.noise3).Length() > 0) {
			state.menu.AddItem("Lock\n", any("lock"));
		}
		state.menu.AddItem("Remove Lock\n", any("remove"));
	}
	
	state.openMenu(plr);
}

HookReturnCode PlayerUse( CBasePlayer@ plr, uint& out )
{
	PlayerState@ state = getPlayerState(plr);
	bool useit = plr.m_afButtonReleased & IN_USE != 0 and state.useState < 50 and state.useState != -1;
	bool heldUse = state.useState == 50;
	
	if (plr.m_afButtonPressed & IN_USE != 0)
	{
		state.useState = 0;
	}
	else if (plr.pev.button & IN_USE != 0) 
	{
		if (state.useState >= 0)
			state.useState += 1;
		if (heldUse)
		{
			useit = true;
			state.useState = -1;
		}
	}
	if (useit)
	{
		TraceResult tr = TraceLook(plr, 256);
		CBaseEntity@ phit = g_EntityFuncs.Instance( tr.pHit );
		
		bool didAction = false;
		if (phit !is null and (phit.pev.classname == "func_door_rotating" or phit.pev.classname == "func_breakable_custom"))
		{
			didAction = true;
			int socket = socketType(phit.pev.colormap);
			if (socket == SOCKET_DOORWAY or (phit.pev.colormap == B_LADDER_HATCH and phit.pev.targetname != ""))
			{
				if (heldUse)
				{
					if (phit.pev.button != 0) // door has lock?
					{
						openCodeLockMenu(plr, phit);
						state.currentLock = phit;
					}
				}
				else
				{
					bool locked = phit.pev.button == 1 and phit.pev.body == 1;
					bool authed = state.isAuthed(phit);
					if (!locked or authed)
					{
						rotate_door(phit, true);
						if (locked) {
							g_SoundSystem.PlaySound(phit.edict(), CHAN_WEAPON, "sc_rust/code_lock_beep.ogg", 1.0f, 1.0f, 0, 100);
						}
					}
					if (locked and !authed)
						g_SoundSystem.PlaySound(phit.edict(), CHAN_WEAPON, "sc_rust/code_lock_denied.ogg", 1.0f, 1.0f, 0, 100);
				}
			}
			else if (phit.pev.colormap == B_WOOD_SHUTTERS)
			{
				rotate_door(phit, true);
				
				// open adjacent shutter
				g_EngineFuncs.MakeVectors(phit.pev.vuser1);
				CBaseEntity@ right = getPartAtPos(phit.pev.origin + g_Engine.v_right*94);
				if (right !is null and right.pev.colormap == B_WOOD_SHUTTERS) {
					rotate_door(right, false);
				}
				
				CBaseEntity@ left = getPartAtPos(phit.pev.origin + g_Engine.v_right*-94);
				if (left !is null and left.pev.colormap == B_WOOD_SHUTTERS) {
					rotate_door(left, false);
				}
			}
			else if (phit.pev.colormap == B_TOOL_CUPBOARD)
			{
				bool authed = state.isAuthed(phit);
				if (heldUse)
				{
					clearDoorAuths(phit);
					g_PlayerFuncs.PrintKeyBindingString(plr, "Authorization List Cleared");
				}
				else if (authed)
				{
					// deauth
					for (uint k = 0; k < state.authedLocks.length(); k++)
					{
						if (!state.authedLocks[k] or state.authedLocks[k].GetEntity().entindex() == phit.entindex())
						{
							state.authedLocks.removeAt(k);
							k--;
						}
					}
					g_PlayerFuncs.PrintKeyBindingString(plr, "You are no longer authorized to build");
				} 
				else 
				{
					EHandle h_phit = phit;
					state.authedLocks.insertLast(h_phit);
					g_PlayerFuncs.PrintKeyBindingString(plr, "You are now authorized to build");
				}
			}
			else if (phit.pev.colormap == B_LARGE_CHEST or phit.pev.colormap == B_SMALL_CHEST or phit.pev.colormap == B_FURNACE
					or phit.pev.colormap == E_SUPPLY_CRATE)
			{
				state.currentChest = phit;
				openLootMenu(plr, phit);
			}
			else
				didAction = false;
		}
		if (!didAction)
		{			
			TraceResult tr2 = TraceLook(plr, 96, true);
			CBaseEntity@ lookItem = getLookItem(plr, tr2.vecEndPos);
			
			if (lookItem !is null)
			{
				if (lookItem.pev.classname == "item_inventory")
				{
					// I do my own pickup logic to bypass the 3 second drop wait in SC
					int barf = pickupItem(plr, lookItem);

					if (barf > 0)
					{
						lookItem.pev.button = barf;
						println("Couldn't hold " + barf + " of that");
					}
					else
					{
						item_collected(plr, lookItem, USE_TOGGLE, 0);
						lookItem.pev.renderfx = -9999;
						g_Scheduler.SetTimeout("delay_remove", 0, EHandle(lookItem));
					}
				}
				if (lookItem.pev.classname == "player_corpse" or lookItem.IsPlayer())
				{
					openLootMenu(plr, lookItem);
				}
			}
		}
	}
	return HOOK_CONTINUE;
}

void clearDoorAuths(CBaseEntity@ door)
{
	array<string>@ stateKeys = player_states.getKeys();
	for (uint i = 0; i < stateKeys.length(); i++)
	{
		PlayerState@ state = cast<PlayerState@>( player_states[stateKeys[i]] );
		for (uint k = 0; k < state.authedLocks.length(); k++)
		{
			if (!state.authedLocks[k] or state.authedLocks[k].GetEntity().entindex() == door.entindex())
			{
				state.authedLocks.removeAt(k);
				k--;
			}
		}
	}
}
