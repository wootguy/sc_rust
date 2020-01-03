
string g_translation_config_path = "scripts/maps/rust/translations/";
dictionary g_languages;
string g_default_language = "english";

void loadTranslations() {
	string fpath = g_translation_config_path + "languages.cfg";
	File@ f = g_FileSystem.OpenFile(fpath, OpenFile::READ );
	if (f is null or !f.IsOpen())
	{
		println("Failed to open translation file: " + fpath);
		return;
	}
	
	string line;
	while( !f.EOFReached() )
	{
		f.ReadLine(line);
		line.Trim();
		line.Trim("\t");
		if (line.Length() == 0 or line.Find("//") == 0)
			continue;
		println("Loading language: " + line);
		loadLanguageFile(line);
	}
}

void loadLanguageFile(string language) {
	dictionary translations;
	
	string fpath = g_translation_config_path + language + ".cfg";
	File@ f = g_FileSystem.OpenFile( fpath, OpenFile::READ );
	if (f is null or !f.IsOpen())
	{
		println("Failed to open language file: " + fpath);
		return;
	}
	
	string line;
	while( !f.EOFReached() )
	{
		f.ReadLine(line);
		line.Trim();
		line.Trim("\t");
		if (line.Length() == 0 or line.Find("//") == 0)
			continue;
		int firstEquals = line.Find("=");
		
		string key = line.SubString(0, firstEquals);
		string value = line.SubString(firstEquals+1);
		value = value.SubString(value.Find("\"")+1);
		value = value.SubString(0, value.FindLastOf("\""));
		key.Trim();
		key.Trim("\t");
		value.Trim("\t");
		value.Trim("\t");
		
		translations[key] = value;
		
		//println(key + " = \"" + value + "\"");
	}
	
	g_languages[language] = translations;
}

string getTranslation(string language, string key) {
	
	dictionary translations;
	if (!g_languages.exists(language)) {
		println("Missing language: " + language);
		return key;
	}
	g_languages.get(language, translations);
	
	string value;
	if (!translations.exists(key)) {
		println("Missing translation for " + key + " in " + language);
		return key;
	}
	translations.get(key, value);
	
	return value;
}

string translate(CBasePlayer@ plr, string msg, string replace0="", string replace1="", string replace2="", string replace3="", string replace4="", string replace5="")
{
	string language = getPlayerState(plr).language;
	
	for (int i = 0; i < 10; i++) {
		string key = msg;
		
		if (key.Find("{") == String::INVALID_INDEX) {
			break;
		}
		
		key = key.SubString(key.Find("{")+1);
		key = key.SubString(0, key.Find("}"));
		string value = getTranslation(language, key);
		
		msg = msg.Replace("{" + key + "}", value);		
	}
	
	bool hadReplacements = false;
	if (replace0.Length() > 0) {
		msg = msg.Replace("[0]", replace0);
		hadReplacements = true;
	}
	if (replace1.Length() > 0) {
		msg = msg.Replace("[1]", replace1);
		hadReplacements = true;
	}
	if (replace2.Length() > 0) {
		msg = msg.Replace("[2]", replace2);
		hadReplacements = true;
	}
	if (replace3.Length() > 0) {
		msg = msg.Replace("[3]", replace3);
		hadReplacements = true;
	}
	if (replace3.Length() > 0) {
		msg = msg.Replace("[4]", replace3);
		hadReplacements = true;
	}
	if (replace3.Length() > 0) {
		msg = msg.Replace("[5]", replace3);
		hadReplacements = true;
	}
	
	if (hadReplacements) {
		// replacements can also contain translation placeholders
		msg = translate(plr, msg);
	}

	// unescape special characters
	msg = msg.Replace("\\n", "\n");
	
	return msg;
}

void SayTextAll(string text, string replace0="", string replace1="", string replace2="", string replace3="")
{
	CBaseEntity@ ent = null;
	do {
		@ent = g_EntityFuncs.FindEntityByClassname(ent, "player");
		if (ent !is null) {
			CBasePlayer@ plr = cast<CBasePlayer@>(ent);
			SayText(plr, text, replace0, replace1, replace2, replace3);
		}
	} while (ent !is null);
}

void PrintKeyBindingStringAll(string text)
{
	CBaseEntity@ ent = null;
	do {
		@ent = g_EntityFuncs.FindEntityByClassname(ent, "player");
		if (ent !is null) {
			CBasePlayer@ plr = cast<CBasePlayer@>(ent);
			PrintKeyBindingString(plr, text);
		}
	} while (ent !is null);
}

void PrintKeyBindingString(CBasePlayer@ plr, string text, 
	string replace0="", string replace1="", string replace2="", string replace3="", string replace4="", string replace5="")
{
	g_PlayerFuncs.PrintKeyBindingString(plr, translate(plr, text, replace0, replace1, replace2, replace3, replace4, replace5));
}

void SayText(CBasePlayer@ plr, string text, string replace0="", string replace1="", string replace2="", string replace3="")
{
	g_PlayerFuncs.SayText(plr, translate(plr, text, replace0, replace1, replace2, replace3));
}

void HudMessage(CBasePlayer@ plr, const HUDTextParams& in textParams, string msg, string replace0="", string replace1="", string replace2="", string replace3="")
{
	g_PlayerFuncs.HudMessage(plr, textParams, translate(plr, msg, replace0, replace1, replace2, replace3));
}