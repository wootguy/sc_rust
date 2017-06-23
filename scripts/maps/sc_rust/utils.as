void print(string text) { g_Game.AlertMessage( at_console, text); }
void println(string text) { print(text + "\n"); }

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

void te_beampoints(Vector start, Vector end, string sprite="sprites/laserbeam.spr", uint8 frameStart=0, uint8 frameRate=100, uint8 life=1, uint8 width=1, uint8 noise=0, Color c=GREEN, uint8 scroll=32, NetworkMessageDest msgType=MSG_BROADCAST, edict_t@ dest=null) { NetworkMessage m(msgType, NetworkMessages::SVC_TEMPENTITY, dest);m.WriteByte(TE_BEAMPOINTS);m.WriteCoord(start.x);m.WriteCoord(start.y);m.WriteCoord(start.z);m.WriteCoord(end.x);m.WriteCoord(end.y);m.WriteCoord(end.z);m.WriteShort(g_EngineFuncs.ModelIndex(sprite));m.WriteByte(frameStart);m.WriteByte(frameRate);m.WriteByte(life);m.WriteByte(width);m.WriteByte(noise);m.WriteByte(c.r);m.WriteByte(c.g);m.WriteByte(c.b);m.WriteByte(c.a);m.WriteByte(scroll);m.End(); }
void te_smoke(Vector pos, string sprite="sprites/steam1.spr", int scale=10, int frameRate=15, NetworkMessageDest msgType=MSG_BROADCAST, edict_t@ dest=null) { NetworkMessage m(msgType, NetworkMessages::SVC_TEMPENTITY, dest);m.WriteByte(TE_SMOKE);m.WriteCoord(pos.x);m.WriteCoord(pos.y);m.WriteCoord(pos.z);m.WriteShort(g_EngineFuncs.ModelIndex(sprite));m.WriteByte(scale);m.WriteByte(frameRate);m.End(); }
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


Vector2D getPerp(Vector2D v) {
	return Vector2D(-v.y, v.x);
}

float dotProduct( Vector2D v1, Vector2D v2 )
{
	return v1.x*v2.x + v1.y*v2.y;
}

bool vecEqual(Vector v1, Vector v2)
{
	return abs(v1.x - v2.x) < EPSILON and abs(v1.y - v2.y) < EPSILON and abs(v1.z - v2.z) < EPSILON;
}

// convert output from Vector.ToString() back into a Vector
Vector parseVector(string s) {
	array<string> values = s.Split(",");
	Vector v(0,0,0);
	if (values.length() > 0) v.x = atof( values[0] );
	if (values.length() > 1) v.y = atof( values[1] );
	if (values.length() > 2) v.z = atof( values[2] );
	return v;
}

BodyAxis calcExtents( array<Vector2D>& verts, Vector2D offset, Vector2D axis )
{
	BodyAxis result;

	result.min = 1E9;
	result.max = -1E9;
	result.minIdx = -1;
	result.maxIdx = -1;

	// project body's verts on this axis
	for (uint i = 0; i < verts.length(); i++)
	{
		float dist = dotProduct(verts[i]-offset, axis); // relative to our origin
		if (dist < result.min)
		{
			result.min = dist;
			result.minIdx = i;
		}
		if (dist > result.max)
		{
			result.max = dist;
			result.maxIdx = i;
		}
	}

	return result;
}

class BodyAxis // body projected on an axis
{
	float min, max; // the min/max dot products for the 1D projection of the 2D body on the axis
	int minIdx, maxIdx; // the vertex indicies of the above min/max values
};

int findEdge( array<Vector2D>& verts, int idx, float target, Vector2D axis, Vector2D offset )
{
	float dist;
	int next = 0;
	int numVerts = verts.length();

	next = idx+1; // check the vertex preceeding the given one
	if (next >= numVerts)
		next = 0;
	dist = dotProduct(verts[next]-offset, axis);

	if (dist <= target + EPSILON && dist >= target - EPSILON)
		return next; // yes, it is an edge!

	next = idx-1; // check the vertex preceeding the given one
	if (next < 0)
		next = numVerts-1;
	dist = dotProduct(verts[next]-offset, axis);

	if (dist <= target + EPSILON && dist >= target - EPSILON)
		return next; // yes, it is an edge!

	return -1; // no edge found, this point really is just a point
}

Vector2D findEdgeContact(array<Vector2D>& points, Vector2D offset, Vector2D axis)
{
	float min = 1E9;
	float max = -1E9;
	int minidx = -1;
	int maxidx = -1;

	for (int i = 0; i < 4; i++)
	{
		float dist = dotProduct(points[i]-offset, axis);
		if (dist < min)
		{
			min = dist;
			minidx = i;
		}
		if (dist > max)
		{
			max = dist;
			maxidx = i;
		}
	}

	array<int> center;
	center.resize(2);
	int idx = 0;
	for (int i = 0; i < 4; i++)
	{
		if (i != minidx && i != maxidx)
			center[idx++] = i;
	}

	return (points[center[0]] + points[center[1]]) / 2.0f;
}

array<float> rotationMatrix(Vector axis, float angle)
{
	axis = axis.Normalize();
    float s = sin(angle);
    float c = cos(angle);
    float oc = 1.0 - c;
 
	array<float> mat = {
		oc * axis.x * axis.x + c,          oc * axis.x * axis.y - axis.z * s, oc * axis.z * axis.x + axis.y * s, 0.0,
		oc * axis.x * axis.y + axis.z * s, oc * axis.y * axis.y + c,          oc * axis.y * axis.z - axis.x * s, 0.0,
		oc * axis.z * axis.x - axis.y * s, oc * axis.y * axis.z + axis.x * s, oc * axis.z * axis.z + c,			 0.0,
		0.0,                               0.0,                               0.0,								 1.0
	};
	return mat;
}

// multiply a matrix with a vector (assumes w component of vector is 1.0f) 
Vector matMultVector(array<float> rotMat, Vector v)
{
	Vector outv;
	outv.x = rotMat[0]*v.x + rotMat[4]*v.y + rotMat[8]*v.z  + rotMat[12];
	outv.y = rotMat[1]*v.x + rotMat[5]*v.y + rotMat[9]*v.z  + rotMat[13];
	outv.z = rotMat[2]*v.x + rotMat[6]*v.y + rotMat[10]*v.z + rotMat[14];
	return outv;
}

CBaseEntity@ getPartAtPos(Vector pos, float dist=2)
{
	CBaseEntity@ ent = null;
	do {
		@ent = g_EntityFuncs.FindEntityInSphere(ent, pos, dist, "*", "classname"); // faster than dist^2 checks in AS
		if (ent !is null and ent.IsBSPModel())
		{
			return ent;
		}
	} while (ent !is null);
	return null;
}

array<EHandle> getPartsByID(int id)
{
	array<EHandle> ents;
	for (uint i = 0; i < g_build_parts.size(); i++)
	{	
		CBaseEntity@ part = g_build_parts[i].ent;
		if (part !is null and g_build_parts[i].id == id) 
		{
			EHandle h_part = part;
			ents.insertLast(h_part);
		}
	}
	return ents;
}

array<EHandle> getPartsByParent(int parent)
{
	array<EHandle> ents;
	for (uint i = 0; i < g_build_parts.size(); i++)
	{	
		CBaseEntity@ part = g_build_parts[i].ent;
		if (part !is null and g_build_parts[i].parent == parent) 
		{
			EHandle h_part = part;
			ents.insertLast(h_part);
		}
	}
	return ents;
}


// which type of part does this part attach to?
int socketType(int partType)
{				
	switch(partType)
	{
		case B_FOUNDATION: case B_FOUNDATION_STEPS:
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

bool isFloorPiece(CBaseEntity@ ent)
{
	int type = ent.pev.colormap;
	return type == B_FOUNDATION or type == B_FLOOR or (type == B_LADDER_HATCH and ent.pev.classname == "func_breakable");
}

bool canPlaceOnTerrain(int partType)
{
	return partType == B_HIGH_WOOD_WALL or partType == B_HIGH_STONE_WALL or partType == B_FOUNDATION;
}

bool forbiddenByCupboard(CBasePlayer@ plr, Vector buildPos)
{
	for (uint i = 0; i < g_tool_cupboards.length(); i++)
	{
		if (g_tool_cupboards[i])
		{
			CBaseEntity@ ent = g_tool_cupboards[i];
			if ((ent.pev.origin - buildPos).Length() < g_tool_cupboard_radius)
			{
				if (!getPlayerState(plr).isAuthed(ent))
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

TraceResult TraceLook(CBasePlayer@ plr, float dist)
{
	Vector vecSrc = plr.GetGunPosition();
	Math.MakeVectors( plr.pev.v_angle ); // todo: monster angles
	
	TraceResult tr;
	Vector vecEnd = vecSrc + g_Engine.v_forward * dist;
	g_Utility.TraceLine( vecSrc, vecEnd, dont_ignore_monsters, plr.edict(), tr );
	return tr;
}

// collision between 2 oriented 2D boxes using the separating axis theorem 
bool collisionSA(CBaseEntity@ b1, CBaseEntity@ b2) {

	int b1NumVerts = 4;
	int b2NumVerts = 4;
	int numAxes = b1NumVerts + b2NumVerts; // sum of verts on both objects
	array<Vector2D> axes;
	axes.resize(numAxes);
	int idx = 0;
	
	Vector2D b1Ori = Vector2D(b1.pev.origin.x, b1.pev.origin.y);
	Vector2D b2Ori = Vector2D(b2.pev.origin.x, b2.pev.origin.y);
	
	// counter-clockwise starting at back right vertex
	array<Vector2D> b1Verts;
	g_EngineFuncs.MakeVectors(b1.pev.angles);
	Vector2D v_forward = Vector2D(g_Engine.v_forward.x, g_Engine.v_forward.y);
	Vector2D v_right = Vector2D(g_Engine.v_right.x, g_Engine.v_right.y);
	b1Verts.insertLast(b1Ori + v_right*b1.pev.maxs.y + v_forward*b1.pev.mins.x);
	b1Verts.insertLast(b1Ori + v_right*b1.pev.mins.y + v_forward*b1.pev.mins.x);
	b1Verts.insertLast(b1Ori + v_right*b1.pev.mins.y + v_forward*b1.pev.maxs.x);
	b1Verts.insertLast(b1Ori + v_right*b1.pev.maxs.y + v_forward*b1.pev.maxs.x);

	// counter-clockwise starting at back right vertex
	array<Vector2D> b2Verts;
	g_EngineFuncs.MakeVectors(b2.pev.angles);
	v_forward = Vector2D(g_Engine.v_forward.x, g_Engine.v_forward.y);
	v_right = Vector2D(g_Engine.v_right.x, g_Engine.v_right.y);
	b2Verts.insertLast(b2Ori + v_right*b2.pev.maxs.y + v_forward*b2.pev.mins.x);
	b2Verts.insertLast(b2Ori + v_right*b2.pev.mins.y + v_forward*b2.pev.mins.x);
	b2Verts.insertLast(b2Ori + v_right*b2.pev.mins.y + v_forward*b2.pev.maxs.x);
	b2Verts.insertLast(b2Ori + v_right*b2.pev.maxs.y + v_forward*b2.pev.maxs.x);

	/*
	te_beampoints(Vector(b1Verts[0].x, b1Verts[0].y, b1.pev.origin.z + 64), Vector(b1Verts[1].x, b1Verts[1].y, b1.pev.origin.z + 64));
	te_beampoints(Vector(b1Verts[1].x, b1Verts[1].y, b1.pev.origin.z + 64), Vector(b1Verts[2].x, b1Verts[2].y, b1.pev.origin.z + 64));
	te_beampoints(Vector(b1Verts[2].x, b1Verts[2].y, b1.pev.origin.z + 64), Vector(b1Verts[3].x, b1Verts[3].y, b1.pev.origin.z + 64));
	te_beampoints(Vector(b1Verts[3].x, b1Verts[3].y, b1.pev.origin.z + 64), Vector(b1Verts[0].x, b1Verts[0].y, b1.pev.origin.z + 64));

	te_beampoints(Vector(b2Verts[0].x, b2Verts[0].y, b1.pev.origin.z + 64), Vector(b2Verts[1].x, b2Verts[1].y, b1.pev.origin.z + 64));
	te_beampoints(Vector(b2Verts[1].x, b2Verts[1].y, b1.pev.origin.z + 64), Vector(b2Verts[2].x, b2Verts[2].y, b1.pev.origin.z + 64));
	te_beampoints(Vector(b2Verts[2].x, b2Verts[2].y, b1.pev.origin.z + 64), Vector(b2Verts[3].x, b2Verts[3].y, b1.pev.origin.z + 64));
	te_beampoints(Vector(b2Verts[3].x, b2Verts[3].y, b1.pev.origin.z + 64), Vector(b2Verts[0].x, b2Verts[0].y, b1.pev.origin.z + 64));
	*/
	
	for (int i = 1; i < b1NumVerts; i++)
		axes[idx++] = getPerp(b1Verts[i] - b1Verts[i-1]);
	axes[idx++] = getPerp(b1Verts[0] - b1Verts[b1NumVerts-1]);

	for (int i = 1; i < b2NumVerts; i++)
		axes[idx++] = getPerp(b2Verts[i] - b2Verts[i-1]);
	axes[idx++] = getPerp(b2Verts[0] - b2Verts[b2NumVerts-1]);

	float minPen = 1E9; // minimum penetration vector;
	Vector2D fix; // vector for fixing the collision
	int b1Contact; // contact point for body 1
	int b2Contact; // contact point for body 1
	float b1ContactDot;
	float b2ContactDot;

	for (int a = 0; a < numAxes; a++)
	{
		axes[a].Normalize();

		BodyAxis ba1 = calcExtents(b1Verts, b1Ori, axes[a]);
		BodyAxis ba2 = calcExtents(b2Verts, b1Ori, axes[a]);
		if (ba1.minIdx == -1 || ba1.maxIdx == -1 || ba2.minIdx == -1 || ba2.maxIdx == -1)
		{
			// can't work with this object
			return false;
		}

		if (ba1.min < ba2.max && ba2.min < ba1.max) // collision along this axis!
		{
			if (ba2.max-ba1.min > ba1.max-ba2.min)
			{
				float pen = ba2.min-ba1.max;
				if (abs(pen) < abs(minPen))
				{
					minPen = pen;
					fix = axes[a];
					b1Contact = ba1.maxIdx;
					b2Contact = ba2.minIdx;
					b1ContactDot = ba1.max;
					b2ContactDot = ba2.min;
				}
			}
			else
			{
				float pen = ba2.max-ba1.min;
				if (abs(pen) < abs(minPen))
				{
					minPen = pen;
					fix = axes[a];
					b1Contact = ba1.minIdx;
					b2Contact = ba2.maxIdx;
					b1ContactDot = ba1.min;
					b2ContactDot = ba2.max;
				}
			}
		}
		else
		{
			// this is the separating axis!
			return false;
		}
	}

	int b1edgeidx = findEdge(b1Verts, b1Contact, b1ContactDot, fix, b1Ori);
	int b2edgeidx = findEdge(b2Verts, b2Contact, b2ContactDot, fix, b2Ori);
	Vector2D contact;

	if (b1edgeidx != -1 && b2edgeidx != -1)
	{
		// SPECIAL EDGEvEDGE CONTACT :OOO
		array<Vector2D> points;
		points.resize(4);
		points[0] = b1Verts[b1Contact];
		points[1] = b1Verts[b1edgeidx];
		points[2] = b2Verts[b2Contact];
		points[3] = b2Verts[b2edgeidx];
		contact = findEdgeContact(points, b1Ori, getPerp(fix));
	}
	else
	{
		if (b1edgeidx == -1)
			contact = b1Verts[b1Contact];
		else
			contact = b2Verts[b1Contact];
	}

	// move bodies away from each other
	/*
	//fix.normalize(minPen/fix.length());
	fix.normalize(minPen*0.5f);

	b1Ori += fix;
	if (!b2->fixed)
		b2Ori -= fix;
	else
		b1Ori += fix;

	fix.normalize(1.0f);
	b2->push(b1, contact, fix);
	*/
	return true;
}

// collision between 2 oriented 3D boxes. Only boxes rotated on the yaw axis are allows
bool collisionBoxesYaw(CBaseEntity@ b1, CBaseEntity@ b2) {
	// check vertical collision first
	
	float b1zmin = b1.pev.mins.z;
	if (b1.pev.colormap == B_LADDER_HATCH)
		b1zmin = -4;
	
	if (b1.pev.origin.z + b1.pev.maxs.z >= b2.pev.origin.z + b2.pev.mins.z and
		b1.pev.origin.z + b1zmin <= b2.pev.origin.z + b2.pev.maxs.z)
	{		
		// check 2D top-down collision
		return collisionSA(b1, b2);
	}
	return false;
}

// ported from HLSDK with minor adjustments
void AngularMove( CBaseEntity@ ent, Vector vecDestAngle, float flSpeed )
{	
	Vector m_vecFinalAngle = vecDestAngle;
	
	ent.pev.iuser1 = 1;

	// Already there?
	if (vecDestAngle == ent.pev.angles)
	{
		AngularMoveDone(ent, m_vecFinalAngle);
		return;
	}
	
	// set destdelta to the vector needed to move
	Vector vecDestDelta = vecDestAngle - ent.pev.angles;
	
	// divide by speed to get time to reach dest
	float flTravelTime = vecDestDelta.Length() / flSpeed;

	// set nextthink to trigger a call to AngularMoveDone when dest is reached
	g_Scheduler.SetTimeout("AngularMoveDone", flTravelTime, @ent, m_vecFinalAngle);

	// scale the destdelta vector by the time spent traveling to get velocity
	ent.pev.avelocity = vecDestDelta / flTravelTime;
}

// ported from HLSDK with minor adjustments
void AngularMoveDone( CBaseEntity@ ent, Vector finalAngle )
{
	ent.pev.iuser1 = 0;
	ent.pev.angles = finalAngle;
	ent.pev.avelocity = g_vecZero;
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
	return cast<PlayerState@>( player_states[steamId] );
}

void PrecacheSound(string snd)
{
	g_SoundSystem.PrecacheSound(snd);
	g_Game.PrecacheGeneric("sound/" + snd);
}