
string guitar_song_path = "scripts/maps/sc_rust/guitar_songs/";
array<Song> g_songs = {
	Song("greenhill.txt", "Sonic 1 - Green Hill Zone", 11.0f),
	Song("starlight_zone.txt", "Sonic 1 - Starlight Zone", 8.0f),
	Song("mysticcave.txt", "Sonic 2 - Mystic Cave Zone", 10.0f),
	Song("endless_mine_2p.txt", "Sonic 2 - Endless Mine (2P)", 17.0f),
	Song("emerald_hill_2p.txt", "Sonic 2 - Emerald Hill Zone (2P)", 7.0f),
	Song("flyingbattery.txt", "Sonic 3 - Flying Battery Zone (Act 2)", 10.0f),
	Song("wily_stage_1.txt", "Megaman 2 - Dr. Wily Stage 1", 11.5f),
	Song("kuwanger.txt", "Megaman X - Boomer Kuwanger", 10.0f),
	Song("storm_eagle.txt", "Megaman X - Storm Eagle", 12.0f),
	Song("puyopuyo.txt", "Puyo Puyo - Final of Puyo Puyo", 11.0f),
	Song("pokemon_battle.txt", "Pokemon - Red Battle", 12.0f),
	Song("together_we_ride.txt", "Fire Emblem - Together, We Ride!", 15.0f),
	Song("zelda2_palace.txt", "Zelda II - Palace", 10.5f)
};

class SongRow
{
	array<int> channels;
	
	SongRow() {}
	
	SongRow(int channel1)
	{
		channels.insertLast(channel1);
	}
	
	SongRow(int channel1, int channel2)
	{
		channels.insertLast(channel1);
		channels.insertLast(channel2);
	}
	
	SongRow(array<int> channels)
	{
		for (uint i = 0; i < channels.length(); i++)
			this.channels.insertLast(channels[i]);
	}
	
	bool play(CBaseEntity@ ent, string sampleLow, string sampleHigh)
	{
		array<SOUND_CHANNEL> s_channels = { CHAN_WEAPON, CHAN_ITEM, CHAN_VOICE, CHAN_STATIC };
		bool playedAnything = false;
		for (uint i = 0; i < channels.size() and i < s_channels.length(); i++)
		{
			if (channels[i] == -1)
				continue;
			int pitch = channels[i];
			string sample = sampleLow;
			if (pitch >= 224)
			{
				pitch -= 124;
				sample = sampleHigh;
			}
			playedAnything = true;
			g_SoundSystem.PlaySound(ent.edict(), s_channels[i], sample, 1.0f, 0.5f, 0, int(pitch));
		}
		return playedAnything;
	}
}

class Song
{
	float tempo = 1;
	array<SongRow> rows;
	int loopPoint = 0;
	int startPoint = 0;
	string title;
	
	// ~4 octaves, from a low C to a high A
	// E F F# G G# A A# B C C# D D# (repeating)
	array<int> notes = {
		44, 47, 50, 53, 56, 59, 63, 67, 71, 75, 79, 84, 
		89, 94, 100, 106, 112, 119, 126, 133, 141, 150, 159, 167, 
		178, 188, 200, 211, 224, 230, 236, 243, 250, 257, 265, 273, 
		282, 292, 302, 312, 325, 335, 348, 361, 375   // highest A
	};
	
	Song() {}
	
	Song(string fname, string title, float tempo)
	{
		this.title = title;
		this.tempo = 1.0f / tempo;
		
		string path = guitar_song_path + fname;
		File@ f = g_FileSystem.OpenFile( path, OpenFile::READ);
		
		if( f !is null && f.IsOpen() )
		{
			println("Loading guitar song: " + fname);
			
			dictionary octave_offsets;
			dictionary volumes;
			dictionary use_channels;
			use_channels[1] = true;
			use_channels[2] = true;
			use_channels[3] = true;
			use_channels[4] = true;
			int songPos = 0;
			int repeatStart = 0;
			int numRepeats = 0;
			while (!f.EOFReached())
			{
				string line;
				f.ReadLine(line);
				
				line.Trim();
				if (line.Find("!repeat=") == 0)
				{
					repeatStart = songPos;
					string prefix = "!repeat=";
					numRepeats = atoi( line.SubString(prefix.Length()) );
				}
				if (line.Find("!repeatend") == 0)
				{
					int repeatEnd = songPos;
					for (int k = 0; k < numRepeats; k++)
						for (int i = repeatStart; i < repeatEnd; i++, songPos++)
							rows.insertLast(SongRow(rows[i].channels));
				}
				if (line.Find("!test") == 0)
				{
					startPoint = songPos;
					loopPoint = songPos;
				}
				if (line.Find("!loop") == 0)
				{
					loopPoint = songPos;
				}
				if (line.Find("!channels=") == 0)
				{
					string prefix = "!channels="; // do not try string("!channels").Length() - you will crash. WTF WHY?!?!?
					line = line.SubString(prefix.Length());
					array<string>@ newChans = line.Split("+");
					use_channels.deleteAll();
					for (uint i = 0; i < newChans.length(); i++)
						use_channels[atoi(newChans[i])] = true;

					continue;
				}
				if (line.Find("!octaves=") == 0)
				{
					string prefix = "!octaves=";
					line = line.SubString(prefix.Length());
					array<string>@ newOct = line.Split("+");
					octave_offsets.deleteAll();
					for (uint i = 0; i < newOct.length(); i++)
						octave_offsets["" + i] = atoi(newOct[i]);

					continue;
				}
				if (line.Find("!volumes=") == 0)
				{
					string prefix = "!volumes=";
					line = line.SubString(prefix.Length());
					array<string>@ newOct = line.Split("+");
					volumes.deleteAll();
					for (uint i = 0; i < newOct.length(); i++)
						volumes["" + i] = atoi(newOct[i]);

					continue;
				}
				if (line.Length() == 0 or line[0] != '|')
					continue;
					
				songPos++;
				
				array<int> channels;
				array<string>@ chan_split = line.Split("|");
				string rnotes;
				for (uint i = 1, k = 0; i < chan_split.length(); i++)
				{
					//println("SCHAN " + i + " :" + chan_split[i]);
					if (!use_channels.exists(i))
						continue;
						
					int octave_offset = 0;
					if (octave_offsets.exists("" + k))
						octave_offsets.get("" + k, octave_offset);
						
					k++;
						
					string s_split = chan_split[i];
					string note = s_split.SubString(0,2);					
					int octave = atoi(string(s_split[2])) + octave_offset;
					if (note != ".." and note != "==") // pause
					{
						//int n = getNoteIdx(note) + (octave%4)*12;						
						//rnotes += "" + note + octave + " (" + n + ": " + notes[n] + ") ";
						channels.insertLast(get_pitch(note, octave));
						//println(note + octave + "[" + (getNoteIdx(note)) +"] (" + line + ")");
					}
					else
						channels.insertLast(-1);
				}
				if (rnotes.Length() > 0)
					println("PLAY " + rnotes);
				
				//println(line);
				rows.insertLast(SongRow(channels));
			}				
		}
		else
		{
			println("Guitar song not found: " + guitar_song_path + fname);
		}
	}
	
	int getNoteIdx(string note)
	{
		if (note == "C-") return 0;
		else if (note == "C#") return 1;
		else if (note == "D-") return 2;
		else if (note == "D#") return 3;
		else if (note == "E-") return 4;
		else if (note == "F-") return 5;
		else if (note == "F#") return 6;
		else if (note == "G-") return 7;
		else if (note == "G#") return 8;
		else if (note == "A-") return 9;
		else if (note == "A#") return 10;
		else if (note == "B-") return 11;
		else println("Bad note: " + note);
		return 0;
	}
	
	int get_pitch(string note, int octave)
	{
		int n = getNoteIdx(note);
		n += (octave % 4) * 12;
		while (n >= int(notes.length()))
			n -= 36;
		while (n < 0)
			n += 36;
		
		return notes[n];
	}
	
	float play(CBaseEntity@ ent, float position, float lastNote, bool&out notePlayed)
	{
		notePlayed = false;
		if (rows.size() == 0)
			return 0;
		
		if (lastNote != 0)
		{
			float delta = g_Engine.time - lastNote;
			int oldPosition = int(position);
			position += (delta / tempo);
			if (oldPosition == int(position))
				return position;
		}
		
		if (int(position) < startPoint)
			position = startPoint;
		if (int(position) >= int(rows.size()))
			position = loopPoint;

		notePlayed = rows[int(position)].play(ent, fixPath("sc_rust/guitar.ogg"), fixPath("sc_rust/guitar2.ogg"));
		return position;
	}
}

void guitar_play_loop(EHandle h_plr)
{
	if (!h_plr.IsValid())
		return;
	CBasePlayer@ plr = cast<CBasePlayer@>(h_plr.GetEntity());
	PlayerState@ state = getPlayerState(plr);
	
	CBasePlayerWeapon@ activeWep = cast<CBasePlayerWeapon@>(plr.m_hActiveItem.GetEntity());
	if (!plr.IsAlive() or activeWep is null or activeWep.pev.classname != "weapon_guitar")
	{
		state.playingSong = false;
		return;
	}
	
	if (state.playingSong)
	{
		bool notePlayed = false;
		state.songPosition = g_songs[state.songId].play(plr, state.songPosition, state.lastNote, notePlayed);
		state.lastNote = g_Engine.time;
		if (notePlayed)
		{
			plr.SetAnimation( PLAYER_ATTACK1 );
			activeWep.SendWeaponAnim( 1, 0, 0 );
		}
	}
		
	g_Scheduler.SetTimeout("guitar_play_loop", 0.0, EHandle(plr));
}

void guitarMenuCallback(CTextMenu@ menu, CBasePlayer@ plr, int page, const CTextMenuItem@ item)
{
	if (item is null)
		return;
	string action;
	item.m_pUserData.retrieve(action);
	PlayerState@ state = getPlayerState(plr);
	
	state.songId = atoi(action);
	state.songPosition = 0;
	state.lastNote = 0;
	state.playingSong = false;
	g_PlayerFuncs.PrintKeyBindingString(plr, g_songs[state.songId].title);
}

void guitar_song_menu(CBaseEntity@ pActivator, CBaseEntity@ pCaller, USE_TYPE useType, float flValue)
{
	CBasePlayer@ plr = cast<CBasePlayer@>(pActivator);
	PlayerState@ state = getPlayerState(plr);
	
	state.initMenu(plr, guitarMenuCallback);
	state.menu.SetTitle("Song Select:\n");
	for (uint i = 0; i < g_songs.size(); i++)
		state.menu.AddItem(g_songs[i].title, any("" + i));
	state.openMenu(plr);
}

void guitar_note_play2(CBaseEntity@ pActivator, CBaseEntity@ pCaller, USE_TYPE useType, float flValue)
{
	CBasePlayer@ plr = cast<CBasePlayer@>(pActivator);
	PlayerState@ state = getPlayerState(plr);
	float pitchShift = 44 + ((pActivator.pev.angles.x + 29.664917) / 59.329834) * (179.0f + 155.0f); // high E at 224
	
	state.playingSong = !state.playingSong;
	if (state.playingSong)
	{
		state.songPosition = 0;
		state.lastNote = 0;
		guitar_play_loop(EHandle(plr));
	}
}

void guitar_note_play(CBaseEntity@ pActivator, CBaseEntity@ pCaller, USE_TYPE useType, float flValue)
{	
	string sample = fixPath("sc_rust/guitar.ogg");
	float pitch = 44 + ((pActivator.pev.angles.x + 29.664917) / 59.329834) * (179.0f + 155.0f); // high E at 224
	if (pitch >= 224)
	{
		pitch -= 124;
		sample = fixPath("sc_rust/guitar2.ogg");
	}
	
	g_SoundSystem.PlaySound(pActivator.edict(), CHAN_STATIC, sample, 1.0f, 0.5f, 0, int(pitch));
}