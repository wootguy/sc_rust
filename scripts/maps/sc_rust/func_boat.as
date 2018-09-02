/*
*	This file defines the custom entity named func_vehicle_custom
*	This is a simple, player controllable vehicle
*
*	DO NOT ALTER THIS FILE
*/

const double VEHICLE_SPEED0_ACCELERATION = 0.005000000000000000;
const double VEHICLE_SPEED1_ACCELERATION = 0.002142857142857143;
const double VEHICLE_SPEED2_ACCELERATION = 0.003333333333333334;
const double VEHICLE_SPEED3_ACCELERATION = 0.004166666666666667;
const double VEHICLE_SPEED4_ACCELERATION = 0.004000000000000000;
const double VEHICLE_SPEED5_ACCELERATION = 0.003800000000000000;
const double VEHICLE_SPEED6_ACCELERATION = 0.004500000000000000;
const double VEHICLE_SPEED7_ACCELERATION = 0.004250000000000000;
const double VEHICLE_SPEED8_ACCELERATION = 0.002666666666666667;
const double VEHICLE_SPEED9_ACCELERATION = 0.002285714285714286;
const double VEHICLE_SPEED10_ACCELERATION = 0.001875000000000000;
const double VEHICLE_SPEED11_ACCELERATION = 0.001444444444444444;
const double VEHICLE_SPEED12_ACCELERATION = 0.001200000000000000;
const double VEHICLE_SPEED13_ACCELERATION = 0.000916666666666666;
const double VEHICLE_SPEED14_ACCELERATION = 0.001444444444444444;

const int VEHICLE_STARTPITCH = 60;
const int VEHICLE_MAXPITCH = 200;
const int VEHICLE_MAXSPEED = 1500;

enum FuncVehicleFlags
{
	SF_VEHICLE_NODEFAULTCONTROLS = 1 << 0 //Don't make a controls volume by default
}

class func_vehicle_custom : ScriptBaseEntity
{
	bool KeyValue( const string& in szKey, const string& in szValue )
	{
		if (szKey == "length")
		{
			m_length = atof(szValue);
			return true;
		}
		else if (szKey == "width")
		{
			m_width = atof(szValue);
			return true;
		}
		else if (szKey == "height")
		{
			m_height = atof(szValue);
			return true;
		}
		else if (szKey == "startspeed")
		{
			m_startSpeed = atof(szValue);
			return true;
		}
		else if (szKey == "sounds")
		{
			m_sounds = atoi(szValue);
			return true;
		}
		else if (szKey == "volume")
		{
			m_flVolume = float(atoi(szValue));
			m_flVolume *= 0.1;
			return true;
		}
		else if (szKey == "bank")
		{
			m_flBank = atof(szValue);
			return true;
		}
		else if (szKey == "acceleration")
		{
			m_acceleration = atoi(szValue);

			if (m_acceleration < 1)
				m_acceleration = 1;
			else if (m_acceleration > 10)
				m_acceleration = 10;

			return true;
		}
		else
			return BaseClass.KeyValue( szKey, szValue );
	}
	
	void NextThink(float thinkTime, const bool alwaysThink)
	{
		if (alwaysThink)
			self.pev.flags |= FL_ALWAYSTHINK;
		else
			self.pev.flags &= ~FL_ALWAYSTHINK;

		self.pev.nextthink = thinkTime;
	}
	
	void Blocked(CBaseEntity@ pOther)
	{
		entvars_t@ pevOther = pOther.pev;

		if (pevOther.FlagBitSet(FL_ONGROUND) && pevOther.groundentity !is null && pevOther.groundentity.vars is self.pev)
		{
			pevOther.velocity = self.pev.velocity;
			return;
		}
		else
		{
			pevOther.velocity = (pevOther.origin - self.pev.origin).Normalize() * self.pev.dmg;
			pevOther.velocity.z += 300;
			self.pev.velocity = self.pev.velocity * 0.85;
		}

		g_Game.AlertMessage(at_aiconsole, "TRAIN(%1): Blocked by %2 (dmg:%3)\n", self.pev.targetname, pOther.pev.classname, self.pev.dmg);
		Math.MakeVectors(self.pev.angles);

		Vector vFrontLeft = (g_Engine.v_forward * -1) * (m_length * 0.5);
		Vector vFrontRight = (g_Engine.v_right * -1) * (m_width * 0.5);
		Vector vBackLeft = self.pev.origin + vFrontLeft - vFrontRight;
		Vector vBackRight = self.pev.origin - vFrontLeft + vFrontRight;
		float minx = Math.min(vBackLeft.x, vBackRight.x);
		float maxx = Math.max(vBackLeft.x, vBackRight.x);
		float miny = Math.min(vBackLeft.y, vBackRight.y);
		float maxy = Math.max(vBackLeft.y, vBackRight.y);
		float minz = self.pev.origin.z;
		float maxz = self.pev.origin.z + (2 * abs(int(self.pev.mins.z - self.pev.maxs.z)));

		if (pOther.pev.origin.x < minx || pOther.pev.origin.x > maxx || pOther.pev.origin.y < miny || pOther.pev.origin.y > maxy || pOther.pev.origin.z < minz || pOther.pev.origin.z > maxz)
			pOther.TakeDamage(self.pev, self.pev, 150, DMG_CRUSH);
	}

	void Spawn()
	{
		if (self.pev.speed == 0)
			m_speed = 165;
		else
			m_speed = self.pev.speed;

		if (m_sounds == 0)
			m_sounds = 3;

		g_Game.AlertMessage(at_console, "M_speed = %1\n", m_speed);

		self.pev.speed = 0;
		self.pev.velocity = g_vecZero;
		self.pev.avelocity = g_vecZero;
		self.pev.impulse = int(m_speed);
		m_acceleration = 5;
		m_dir = 1;
		m_flTurnStartTime = -1;

		if( string( self.pev.target ).IsEmpty() )
			g_Game.AlertMessage(at_console, "Vehicle with no target\n");

		/*
		if (self.pev.spawnflags & SF_TRACKTRAIN_PASSABLE)
			self.pev.solid = SOLID_NOT;
		else
		*/
			self.pev.solid = SOLID_BSP;

		self.pev.movetype = MOVETYPE_PUSH;

		g_EntityFuncs.SetModel(self, self.pev.model);
		g_EntityFuncs.SetSize(self.pev, self.pev.mins, self.pev.maxs);
		g_EntityFuncs.SetOrigin(self, self.pev.origin);

		self.pev.oldorigin = self.pev.origin;
		
		if( !self.pev.SpawnFlagBitSet( SF_VEHICLE_NODEFAULTCONTROLS ) )
		{
			m_controlMins = self.pev.mins;
			m_controlMaxs = self.pev.maxs;
			m_controlMaxs.z += 72;
		}

		NextThink(self.pev.ltime + 0.1, false);
		SetThink(ThinkFunction(this.Find));
		Precache();
	}

	void Restart()
	{
		g_Game.AlertMessage(at_console, "M_speed = %1\n", m_speed);

		self.pev.speed = 0;
		self.pev.velocity = g_vecZero;
		self.pev.avelocity = g_vecZero;
		self.pev.impulse = int(m_speed);
		m_flTurnStartTime = -1;
		m_flUpdateSound = -1;
		m_dir = 1;
		@m_pDriver = null;

		if( string( self.pev.target ).IsEmpty() )
			g_Game.AlertMessage(at_console, "Vehicle with no target\n");

		g_EntityFuncs.SetOrigin(self, self.pev.oldorigin);
		NextThink(self.pev.ltime + 0.1, false);
		SetThink(ThinkFunction(this.Find));
	}
	
	void Precache()
	{
		if (m_flVolume == 0)
			m_flVolume = 1;

		switch (m_sounds)
		{
			case 1: g_SoundSystem.PrecacheSound("plats/vehicle1.wav"); self.pev.noise = "plats/vehicle1.wav"; break;
			case 2: g_SoundSystem.PrecacheSound("plats/vehicle2.wav"); self.pev.noise = "plats/vehicle2.wav"; break;
			case 3: g_SoundSystem.PrecacheSound("plats/vehicle3.wav"); self.pev.noise = "plats/vehicle3.wav"; break;
			case 4: g_SoundSystem.PrecacheSound("plats/vehicle4.wav"); self.pev.noise = "plats/vehicle4.wav"; break;
			case 5: g_SoundSystem.PrecacheSound("plats/vehicle6.wav"); self.pev.noise = "plats/vehicle6.wav"; break;
			case 6: g_SoundSystem.PrecacheSound("plats/vehicle7.wav"); self.pev.noise = "plats/vehicle7.wav"; break;
		}

		g_SoundSystem.PrecacheSound("plats/vehicle_brake1.wav");
		g_SoundSystem.PrecacheSound("plats/vehicle_start1.wav");
		g_SoundSystem.PrecacheSound( "plats/vehicle_ignition.wav" );
	}

	void Use(CBaseEntity@ pActivator, CBaseEntity@ pCaller, USE_TYPE useType, float value)
	{
		float delta = value;

		if (useType != USE_SET)
		{
			if( !self.ShouldToggle( useType, self.pev.speed != 0 ))
				return;

			if (self.pev.speed == 0)
			{
				self.pev.speed = m_speed * m_dir;
				Next();
			}
			else
			{
				self.pev.speed = 0;
				self.pev.velocity = g_vecZero;
				self.pev.avelocity = g_vecZero;
				StopSound();
				SetThink(null);
			}
		}

		if (delta < 10)
		{
			if (delta < 0 && self.pev.speed > 145)
				StopSound();

			float flSpeedRatio = delta;

			if (delta > 0)
			{
				flSpeedRatio = self.pev.speed / m_speed;

				if (self.pev.speed < 0)
					flSpeedRatio = m_acceleration * 0.0005 + flSpeedRatio + VEHICLE_SPEED0_ACCELERATION;
				else if (self.pev.speed < 10)
					flSpeedRatio = m_acceleration * 0.0006 + flSpeedRatio + VEHICLE_SPEED1_ACCELERATION;
				else if (self.pev.speed < 20)
					flSpeedRatio = m_acceleration * 0.0007 + flSpeedRatio + VEHICLE_SPEED2_ACCELERATION;
				else if (self.pev.speed < 30)
					flSpeedRatio = m_acceleration * 0.0007 + flSpeedRatio + VEHICLE_SPEED3_ACCELERATION;
				else if (self.pev.speed < 45)
					flSpeedRatio = m_acceleration * 0.0007 + flSpeedRatio + VEHICLE_SPEED4_ACCELERATION;
				else if (self.pev.speed < 60)
					flSpeedRatio = m_acceleration * 0.0008 + flSpeedRatio + VEHICLE_SPEED5_ACCELERATION;
				else if (self.pev.speed < 80)
					flSpeedRatio = m_acceleration * 0.0008 + flSpeedRatio + VEHICLE_SPEED6_ACCELERATION;
				else if (self.pev.speed < 100)
					flSpeedRatio = m_acceleration * 0.0009 + flSpeedRatio + VEHICLE_SPEED7_ACCELERATION;
				else if (self.pev.speed < 150)
					flSpeedRatio = m_acceleration * 0.0008 + flSpeedRatio + VEHICLE_SPEED8_ACCELERATION;
				else if (self.pev.speed < 225)
					flSpeedRatio = m_acceleration * 0.0007 + flSpeedRatio + VEHICLE_SPEED9_ACCELERATION;
				else if (self.pev.speed < 300)
					flSpeedRatio = m_acceleration * 0.0006 + flSpeedRatio + VEHICLE_SPEED10_ACCELERATION;
				else if (self.pev.speed < 400)
					flSpeedRatio = m_acceleration * 0.0005 + flSpeedRatio + VEHICLE_SPEED11_ACCELERATION;
				else if (self.pev.speed < 550)
					flSpeedRatio = m_acceleration * 0.0005 + flSpeedRatio + VEHICLE_SPEED12_ACCELERATION;
				else if (self.pev.speed < 800)
					flSpeedRatio = m_acceleration * 0.0005 + flSpeedRatio + VEHICLE_SPEED13_ACCELERATION;
				else
					flSpeedRatio = m_acceleration * 0.0005 + flSpeedRatio + VEHICLE_SPEED14_ACCELERATION;
			}
			else if (delta < 0)
			{
				flSpeedRatio = self.pev.speed / m_speed;

				if (flSpeedRatio > 0)
					flSpeedRatio -= 0.0125;
				else if (flSpeedRatio <= 0 && flSpeedRatio > -0.05)
					flSpeedRatio -= 0.0075;
				else if (flSpeedRatio <= 0.05 && flSpeedRatio > -0.1)
					flSpeedRatio -= 0.01;
				else if (flSpeedRatio <= 0.15 && flSpeedRatio > -0.15)
					flSpeedRatio -= 0.0125;
				else if (flSpeedRatio <= 0.15 && flSpeedRatio > -0.22)
					flSpeedRatio -= 0.01375;
				else if (flSpeedRatio <= 0.22 && flSpeedRatio > -0.3)
					flSpeedRatio -= - 0.0175;
				else if (flSpeedRatio <= 0.3)
					flSpeedRatio -= 0.0125;
			}

			if (flSpeedRatio > 1)
				flSpeedRatio = 1;
			else if (flSpeedRatio < -0.35)
				flSpeedRatio = -0.35;

			self.pev.speed = m_speed * flSpeedRatio;
			Next();
			m_flAcceleratorDecay = g_Engine.time + 0.25;
		}
		else
		{
			if (g_Engine.time > m_flCanTurnNow)
			{
				if (delta == 20)
				{
					m_iTurnAngle++;
					m_flSteeringWheelDecay = g_Engine.time + 0.075;

					if (m_iTurnAngle > 8)
						m_iTurnAngle = 8;
				}
				else if (delta == 30)
				{
					m_iTurnAngle--;
					m_flSteeringWheelDecay = g_Engine.time + 0.075;

					if (m_iTurnAngle < -8)
						m_iTurnAngle = -8;
				}

				m_flCanTurnNow = g_Engine.time + 0.05;
			}
		}
	}
	
	int ObjectCaps() { return (BaseClass.ObjectCaps() & ~FCAP_ACROSS_TRANSITION) | FCAP_DIRECTIONAL_USE; }
	
	void OverrideReset()
	{
		NextThink(self.pev.ltime + 0.1, false);
		SetThink(ThinkFunction(this.NearestPath));
	}
	
	void CheckTurning()
	{
		TraceResult tr;
		Vector vecStart, vecEnd;

		if (m_iTurnAngle < 0)
		{
			if (self.pev.speed > 0)
			{
				vecStart = m_vFrontLeft;
				vecEnd = vecStart - g_Engine.v_right * 16;
			}
			else if (self.pev.speed < 0)
			{
				vecStart = m_vBackLeft;
				vecEnd = vecStart + g_Engine.v_right * 16;
			}

			g_Utility.TraceLine(vecStart, vecEnd, ignore_monsters, dont_ignore_glass, self.edict(), tr);

			if (tr.flFraction != 1)
				m_iTurnAngle = 1;
		}
		else if (m_iTurnAngle > 0)
		{
			if (self.pev.speed > 0)
			{
				vecStart = m_vFrontRight;
				vecEnd = vecStart + g_Engine.v_right * 16;
			}
			else if (self.pev.speed < 0)
			{
				vecStart = m_vBackRight;
				vecEnd = vecStart - g_Engine.v_right * 16;
			}

			g_Utility.TraceLine(vecStart, vecEnd, ignore_monsters, dont_ignore_glass, self.edict(), tr);

			if (tr.flFraction != 1)
				m_iTurnAngle = -1;
		}

		if (self.pev.speed <= 0)
			return;

		float speed;
		int turning = int(abs(m_iTurnAngle));

		if (turning > 4)
		{
			if (m_flTurnStartTime != -1)
			{
				float time = g_Engine.time - m_flTurnStartTime;

				if (time >= 0)
					speed = m_speed * 0.98;
				else if (time > 0.3)
					speed = m_speed * 0.95;
				else if (time > 0.6)
					speed = m_speed * 0.9;
				else if (time > 0.8)
					speed = m_speed * 0.8;
				else if (time > 1)
					speed = m_speed * 0.7;
				else if (time > 1.2)
					speed = m_speed * 0.5;
				else
					speed = time;
			}
			else
			{
				m_flTurnStartTime = g_Engine.time;
				speed = m_speed;
			}
		}
		else
		{
			m_flTurnStartTime = -1;

			if (turning > 2)
				speed = m_speed * 0.9;
			else
				speed = m_speed;
		}

		if (speed < self.pev.speed)
			self.pev.speed -= m_speed * 0.1;
	}
	
	void CollisionDetection()
	{
		TraceResult tr;
		Vector vecStart, vecEnd;
		float flDot;

		if (self.pev.speed < 0)
		{
			vecStart = m_vBackLeft;
			vecEnd = vecStart + (g_Engine.v_forward * 16);
			g_Utility.TraceLine(vecStart, vecEnd, ignore_monsters, dont_ignore_glass, self.edict(), tr);

			if (tr.flFraction != 1)
			{
				flDot = DotProduct(g_Engine.v_forward, tr.vecPlaneNormal * -1);

				if (flDot < 0.7 && tr.vecPlaneNormal.z < 0.1)
				{
					m_vSurfaceNormal = tr.vecPlaneNormal;
					m_vSurfaceNormal.z = 0;
					self.pev.speed *= 0.99;
				}
				else if (tr.vecPlaneNormal.z < 0.65 || tr.fStartSolid != 0)
					self.pev.speed *= -1;
				else
					m_vSurfaceNormal = tr.vecPlaneNormal;

				/*
				CBaseEntity@ pHit = g_EntityFuncs.Instance(tr.pHit);

				if (pHit !is null && pHit.Classify() == CLASS_VEHICLE)
					ALERT(at_console, "I hit another vehicle\n");
					*/
			}

			vecStart = m_vBackRight;
			vecEnd = vecStart + (g_Engine.v_forward * 16);
			g_Utility.TraceLine(vecStart, vecEnd, ignore_monsters, dont_ignore_glass, self.edict(), tr);

			if (tr.flFraction == 1)
			{
				vecStart = m_vBack;
				vecEnd = vecStart + (g_Engine.v_forward * 16);
				g_Utility.TraceLine(vecStart, vecEnd, ignore_monsters, dont_ignore_glass, self.edict(), tr);

				if (tr.flFraction == 1)
					return;
			}

			flDot = DotProduct(g_Engine.v_forward, tr.vecPlaneNormal * -1);

			if (flDot >= 0.7)
			{
				if (tr.vecPlaneNormal.z < 0.65 || tr.fStartSolid != 0)
					self.pev.speed *= -1;
				else
					m_vSurfaceNormal = tr.vecPlaneNormal;
			}
			else if (tr.vecPlaneNormal.z < 0.1)
			{
				m_vSurfaceNormal = tr.vecPlaneNormal;
				m_vSurfaceNormal.z = 0;
				self.pev.speed *= 0.99;
			}
			else if (tr.vecPlaneNormal.z < 0.65 || tr.fStartSolid != 0)
				self.pev.speed *= -1;
			else
				m_vSurfaceNormal = tr.vecPlaneNormal;
		}
		else if (self.pev.speed > 0)
		{
			vecStart = m_vFrontRight;
			vecEnd = vecStart - (g_Engine.v_forward * 16);
			g_Utility.TraceLine(vecStart, vecEnd, dont_ignore_monsters, dont_ignore_glass, self.edict(), tr);

			if (tr.flFraction == 1)
			{
				vecStart = m_vFrontLeft;
				vecEnd = vecStart - (g_Engine.v_forward * 16);
				g_Utility.TraceLine(vecStart, vecEnd, ignore_monsters, dont_ignore_glass, self.edict(), tr);

				if (tr.flFraction == 1)
				{
					vecStart = m_vFront;
					vecEnd = vecStart - (g_Engine.v_forward * 16);
					g_Utility.TraceLine(vecStart, vecEnd, ignore_monsters, dont_ignore_glass, self.edict(), tr);

					if (tr.flFraction == 1)
						return;
				}
			}

			flDot = DotProduct(g_Engine.v_forward, tr.vecPlaneNormal * -1);

			if (flDot <= -0.7)
			{
				if (tr.vecPlaneNormal.z < 0.65 || tr.fStartSolid != 0)
					self.pev.speed *= -1;
				else
					m_vSurfaceNormal = tr.vecPlaneNormal;
			}
			else if (tr.vecPlaneNormal.z < 0.1)
			{
				m_vSurfaceNormal = tr.vecPlaneNormal;
				m_vSurfaceNormal.z = 0;
				self.pev.speed *= 0.99;
			}
			else if (tr.vecPlaneNormal.z < 0.65 || tr.fStartSolid != 0)
				self.pev.speed *= -1;
			else
				m_vSurfaceNormal = tr.vecPlaneNormal;
		}
	}

	void TerrainFollowing()
	{
		TraceResult tr;
		g_Utility.TraceLine(self.pev.origin, self.pev.origin + Vector(0, 0, (m_height + 48) * -1), ignore_monsters, dont_ignore_glass, self.edict(), tr);

		if (tr.flFraction != 1)
			m_vSurfaceNormal = tr.vecPlaneNormal;
		else if( tr.fInWater != 0 )
			m_vSurfaceNormal = Vector(0, 0, 1);
	}

	void Next()
	{
		Vector vGravityVector = g_vecZero;
		Math.MakeVectors(self.pev.angles);

		Vector forward = (g_Engine.v_forward * -1) * (m_length * 0.5);
		Vector right = (g_Engine.v_right * -1) * (m_width * 0.5);
		Vector up = g_Engine.v_up * 16;

		m_vFrontRight = self.pev.origin + forward - right + up;
		m_vFrontLeft = self.pev.origin + forward + right + up;
		m_vFront = self.pev.origin + forward + up;
		m_vBackLeft = self.pev.origin - forward - right + up;
		m_vBackRight = self.pev.origin - forward + right + up;
		m_vBack = self.pev.origin - forward + up;
		m_vSurfaceNormal = g_vecZero;

		CheckTurning();

		if (g_Engine.time > m_flSteeringWheelDecay)
		{
			m_flSteeringWheelDecay = g_Engine.time + 0.1;

			if (m_iTurnAngle < 0)
				m_iTurnAngle++;
			else if (m_iTurnAngle > 0)
				m_iTurnAngle--;
		}

		if (g_Engine.time > m_flAcceleratorDecay and m_flLaunchTime == -1)
		{
			if (self.pev.speed < 0)
			{
				self.pev.speed += 20;

				if (self.pev.speed > 0)
					self.pev.speed = 0;
			}
			else if (self.pev.speed > 0)
			{
				self.pev.speed -= 20;

				if (self.pev.speed < 0)
					self.pev.speed = 0;
			}
		}
		
		//Moved here to make sure sounds are always handled correctly
		if (g_Engine.time > m_flUpdateSound)
		{
			UpdateSound();
			m_flUpdateSound = g_Engine.time + 1;
		}

		if (self.pev.speed == 0)
		{
			m_iTurnAngle = 0;
			self.pev.avelocity = g_vecZero;
			self.pev.velocity = g_vecZero;
			SetThink(ThinkFunction(this.Next));
			NextThink(self.pev.ltime + 0.1, true);
			return;
		}

		TerrainFollowing();
		CollisionDetection();

		if (m_vSurfaceNormal == g_vecZero)
		{
			if (m_flLaunchTime != -1)
			{
				vGravityVector = Vector(0, 0, 0);
				vGravityVector.z = (g_Engine.time - m_flLaunchTime) * -35;

				if (vGravityVector.z < -400)
					vGravityVector.z = -400;
			}
			else
			{
				m_flLaunchTime = g_Engine.time;
				vGravityVector = Vector(0, 0, 0);
				self.pev.velocity = self.pev.velocity * 1.5;
			}

			m_vVehicleDirection = g_Engine.v_forward * -1;
		}
		else
		{
			m_vVehicleDirection = CrossProduct(m_vSurfaceNormal, g_Engine.v_forward);
			m_vVehicleDirection = CrossProduct(m_vSurfaceNormal, m_vVehicleDirection);

			Vector angles = Math.VecToAngles(m_vVehicleDirection);
			angles.y += 180;

			if (m_iTurnAngle != 0)
				angles.y += m_iTurnAngle;

			angles = FixupAngles(angles);
			self.pev.angles = FixupAngles(self.pev.angles);

			float vx = Math.AngleDistance(angles.x, self.pev.angles.x);
			float vy = Math.AngleDistance(angles.y, self.pev.angles.y);

			if (vx > 10)
				vx = 10;
			else if (vx < -10)
				vx = -10;

			if (vy > 10)
				vy = 10;
			else if (vy < -10)
				vy = -10;

			self.pev.avelocity.y = int(vy * 10);
			self.pev.avelocity.x = int(vx * 10);
			m_flLaunchTime = -1;
			m_flLastNormalZ = m_vSurfaceNormal.z;
		}

		Math.VecToAngles(m_vVehicleDirection);

		/*
		if (g_Engine.time > m_flUpdateSound)
		{
			UpdateSound();
			m_flUpdateSound = g_Engine.time + 1;
		}
		*/

		if (m_vSurfaceNormal == g_vecZero)
			self.pev.velocity = self.pev.velocity + vGravityVector;
		else
			self.pev.velocity = m_vVehicleDirection.Normalize() * self.pev.speed;

		SetThink(ThinkFunction(this.Next));
		NextThink(self.pev.ltime + 0.1, true);
	}

	void Find()
	{
		@m_ppath = cast<CPathTrack@>( g_EntityFuncs.FindEntityByTargetname( null, self.pev.target ) );

		if (m_ppath is null)
			return;

		entvars_t@ pevTarget = m_ppath.pev;

		if (!pevTarget.ClassNameIs( "path_track" ))
		{
			g_Game.AlertMessage(at_error, "func_vehicle_custom must be on a path of path_track\n");
			@m_ppath = null;
			return;
		}

		Vector nextPos = pevTarget.origin;
		nextPos.z += m_height;

		Vector look = nextPos;
		look.z -= m_height;
		m_ppath.LookAhead(look, look, m_length, true);
		look.z += m_height;

		self.pev.angles = Math.VecToAngles(look - nextPos);
		self.pev.angles.y += 180;

		/*
		if (self.pev.spawnflags & SF_TRACKTRAIN_NOPITCH)
			self.pev.angles.x = 0;
			*/

		g_EntityFuncs.SetOrigin(self, nextPos);
		NextThink(self.pev.ltime + 0.1, false);
		SetThink(ThinkFunction(this.Next));
		self.pev.speed = m_startSpeed;
		UpdateSound();
	}

	void NearestPath()
	{
		CBaseEntity@ pTrack = null;
		CBaseEntity@ pNearest = null;
		float dist = 0.0f;
		float closest = 1024;

		while ((@pTrack = @g_EntityFuncs.FindEntityInSphere(pTrack, self.pev.origin, 1024)) !is null)
		{
			if ((pTrack.pev.flags & (FL_CLIENT | FL_MONSTER)) == 0 && pTrack.pev.ClassNameIs( "path_track" ))
			{
				dist = (self.pev.origin - pTrack.pev.origin).Length();

				if (dist < closest)
				{
					closest = dist;
					@pNearest = @pTrack;
				}
			}
		}

		if (pNearest is null)
		{
			g_Game.AlertMessage(at_console, "Can't find a nearby track !!!\n");
			SetThink(null);
			return;
		}

		g_Game.AlertMessage(at_aiconsole, "TRAIN: %1, Nearest track is %2\n", self.pev.targetname, pNearest.pev.targetname);
		@pTrack = cast<CPathTrack@>(pNearest).GetNext();

		if (pTrack !is null)
		{
			if ((self.pev.origin - pTrack.pev.origin).Length() < (self.pev.origin - pNearest.pev.origin).Length())
				@pNearest = pTrack;
		}

		@m_ppath = cast<CPathTrack@>(pNearest);

		if (self.pev.speed != 0)
		{
			NextThink(self.pev.ltime + 0.1, false);
			SetThink(ThinkFunction(this.Next));
		}
	}

	void SetTrack(CPathTrack@ track) { @m_ppath = @track.Nearest(self.pev.origin); }
	
	void SetControls(entvars_t@ pevControls)
	{
		Vector offset = pevControls.origin - self.pev.oldorigin;
		m_controlMins = pevControls.mins + offset;
		m_controlMaxs = pevControls.maxs + offset;
	}

	bool OnControls(entvars_t@ pevTest)
	{
		Vector offset = pevTest.origin - self.pev.origin;

		/*
		if (self.pev.spawnflags & SF_TRACKTRAIN_NOCONTROL)
			return false;
		*/

		Math.MakeVectors(self.pev.angles);
		
		Vector local;
		local.x = DotProduct(offset, g_Engine.v_forward);
		local.y = -DotProduct(offset, g_Engine.v_right);
		local.z = DotProduct(offset, g_Engine.v_up);

		if (local.x >= m_controlMins.x && local.y >= m_controlMins.y && local.z >= m_controlMins.z && local.x <= m_controlMaxs.x && local.y <= m_controlMaxs.y && local.z <= m_controlMaxs.z)
			return true;

		return false;
	}
	
	void StopSound()
	{
		if (m_soundPlaying != 0 && !string( self.pev.noise ).IsEmpty())
		{
			g_SoundSystem.StopSound(self.edict(), CHAN_STATIC, self.pev.noise);
			if (m_sounds < 5)
				g_SoundSystem.EmitSoundDyn( self.edict(), CHAN_ITEM, "plats/vehicle_brake1.wav", m_flVolume, ATTN_NORM, 0, 100 );
		}

		m_soundPlaying = 0;
	}

	void UpdateSound()
	{
		if (string( self.pev.noise ).IsEmpty())
			return;

		float flpitch = VEHICLE_STARTPITCH + (abs(int(self.pev.speed)) * (VEHICLE_MAXPITCH - VEHICLE_STARTPITCH) / VEHICLE_MAXSPEED);

		if (flpitch > 200)
			flpitch = 200;

		if (m_soundPlaying == 0)
		{
			if (m_sounds < 5)
				g_SoundSystem.EmitSoundDyn( self.edict(), CHAN_ITEM, "plats/vehicle_brake1.wav", m_flVolume, ATTN_NORM, 0, 100 );

			g_SoundSystem.EmitSoundDyn(self.edict(), CHAN_STATIC, self.pev.noise, m_flVolume, ATTN_NORM, 0, int(flpitch));
			m_soundPlaying = 1;
		}
		else
		{
			g_SoundSystem.EmitSoundDyn(self.edict(), CHAN_STATIC, self.pev.noise, m_flVolume, ATTN_NORM, SND_CHANGE_PITCH, int(flpitch));
		}
	}
	
	CBasePlayer@ GetDriver()
	{
		return m_pDriver;
	}
	
	void SetDriver( CBasePlayer@ pDriver )
	{
		@m_pDriver = @pDriver;

		if( pDriver !is null )
			g_SoundSystem.EmitSoundDyn( self.edict(), CHAN_ITEM, "plats/vehicle_ignition.wav", 0.8, ATTN_NORM, 0, PITCH_NORM );
	}

	CPathTrack@ m_ppath;
	float m_length;
	float m_width;
	float m_height;
	float m_speed;
	float m_dir;
	float m_startSpeed;
	Vector m_controlMins;
	Vector m_controlMaxs;
	int m_soundPlaying;
	int m_sounds;
	int m_acceleration;
	float m_flVolume;
	float m_flBank;
	float m_oldSpeed;
	int m_iTurnAngle;
	float m_flSteeringWheelDecay;
	float m_flAcceleratorDecay;
	float m_flTurnStartTime;
	float m_flLaunchTime;
	float m_flLastNormalZ;
	float m_flCanTurnNow;
	float m_flUpdateSound;
	Vector m_vFrontLeft;
	Vector m_vFront;
	Vector m_vFrontRight;
	Vector m_vBackLeft;
	Vector m_vBack;
	Vector m_vBackRight;
	Vector m_vSurfaceNormal;
	Vector m_vVehicleDirection;
	CBasePlayer@ m_pDriver;
}

const string VEHICLE_RC_EHANDLE_KEY = "VEHICLE_RC_EHANDLE_KEY"; //Key into player user data used to keep track of vehicle RC state

void TurnVehicleRCControlOff( CBasePlayer@ pPlayer )
{
	EHandle train = EHandle( pPlayer.GetUserData()[ VEHICLE_RC_EHANDLE_KEY ] );
				
	if( train.IsValid() )
	{
		func_vehicle_custom@ ptrain = func_vehicle_custom_Instance( train.GetEntity() );
		
		if( ptrain !is null )
			ptrain.SetDriver( null );
	}
			
	pPlayer.GetUserData()[ VEHICLE_RC_EHANDLE_KEY ] = EHandle();
							
	pPlayer.m_afPhysicsFlags &= ~PFLAG_ONTRAIN;
	pPlayer.m_iTrain = TRAIN_NEW|TRAIN_OFF;
}

enum FuncVehicleControlsFlags
{
	SF_VEHICLE_RC = 1 << 0, //This func_vehiclecontrols is a remote control, not driver control
}

class func_vehiclecontrols : ScriptBaseEntity
{
	int ObjectCaps()
	{
		return ( BaseClass.ObjectCaps() & ~FCAP_ACROSS_TRANSITION ) | 
		( self.pev.SpawnFlagBitSet( SF_VEHICLE_RC ) ? int( FCAP_IMPULSE_USE ) : 0 );
	}
	
	//Overriden because the default rules don't work correctly here
	bool IsBSPModel()
	{
		return true;
	}
	
	void Spawn()
	{
		if( self.pev.SpawnFlagBitSet( SF_VEHICLE_RC ) )
		{
			self.pev.solid = SOLID_BSP;
			self.pev.movetype = MOVETYPE_PUSH;
		}
		else
		{
			self.pev.solid = SOLID_NOT;
			self.pev.movetype = MOVETYPE_NONE;
		}
		
		g_EntityFuncs.SetModel( self, self.pev.model );

		g_EntityFuncs.SetSize( self.pev, self.pev.mins, self.pev.maxs );
		g_EntityFuncs.SetOrigin( self, self.pev.origin );

		SetThink( ThinkFunction( Find ) );
		self.pev.nextthink = g_Engine.time;
	}
	
	void Find()
	{
		CBaseEntity@ pTarget = null;
		
		do
		{
			@pTarget = @g_EntityFuncs.FindEntityByTargetname(pTarget, self.pev.target);
		}
		while (pTarget !is null && !pTarget.pev.ClassNameIs( "func_vehicle_custom" ) );
		
		func_vehicle_custom@ ptrain = null;

		if( pTarget !is null )
		{
			@ptrain = @func_vehicle_custom_Instance( pTarget );
			
			//Only set controls if this is a non-RC control
			if( ptrain !is null && !self.pev.SpawnFlagBitSet( SF_VEHICLE_RC ) )
				ptrain.SetControls( self.pev );
		}
		else
			g_Game.AlertMessage( at_console, "No func_vehicle_custom %1\n", self.pev.target );

		if( !self.pev.SpawnFlagBitSet( SF_VEHICLE_RC ) || ptrain is null )
			g_EntityFuncs.Remove( self );
		else
			m_hVehicle = pTarget;
	}
	
	void Use( CBaseEntity@ pActivator, CBaseEntity@ pCaller, USE_TYPE useType, float flValue )
	{
		if( pActivator is null || !pActivator.IsPlayer() )
			return;
			
		if( !m_hVehicle.IsValid() )
		{
			g_EntityFuncs.Remove( self );
			return;
		}
			
		func_vehicle_custom@ ptrain = func_vehicle_custom_Instance( m_hVehicle.GetEntity() );
		
		if( ptrain !is null )
		{
		CBasePlayer@ pPlayer = cast<CBasePlayer@>( pActivator );
		
			bool fisInControl = EHandle( pPlayer.GetUserData()[ VEHICLE_RC_EHANDLE_KEY ] ).IsValid();
			
			{
				CBasePlayer@ pDriver = ptrain.GetDriver();
				
				if( pDriver !is null )
				{
					TurnVehicleRCControlOff( pDriver );
					
					ptrain.SetDriver( null );
				}
			}
			
			if( !fisInControl )
			{
				pPlayer.m_afPhysicsFlags |= PFLAG_ONTRAIN;
				pPlayer.m_iTrain = TrainSpeed(int(ptrain.self.pev.speed), ptrain.self.pev.impulse);
				pPlayer.m_iTrain |= TRAIN_NEW;
				
				CBaseEntity@ pDriver = ptrain.GetDriver();
				
				if( pDriver !is null )
				{
					CBasePlayer@ pPlayerDriver = cast<CBasePlayer@>( pDriver );
					
					if( pPlayerDriver !is null )
					{
						TurnVehicleRCControlOff( pPlayerDriver );
					}
				}
				
				ptrain.SetDriver( pPlayer );
				
				pPlayer.GetUserData()[ VEHICLE_RC_EHANDLE_KEY ] = m_hVehicle;
			}
		}
		else
			g_EntityFuncs.Remove( self );
	}
	
	EHandle m_hVehicle;
}

func_vehicle_custom@ func_vehicle_custom_Instance( CBaseEntity@ pEntity )
{
	if(	pEntity.pev.ClassNameIs( "func_vehicle_custom" ) )
		return cast<func_vehicle_custom@>( CastToScriptClass( pEntity ) );

	return null;
}

float Fix(float angle)
{
	while (angle < 0)
		angle += 360;
	while (angle > 360)
		angle -= 360;

	return angle;
}

Vector FixupAngles(Vector v)
{
	v.x = Fix(v.x);
	v.y = Fix(v.y);
	v.z = Fix(v.z);
	
	return v;
}

/*
*	Call this to init func_vehicle_custom
*	If you want debugging code accessible through chat, set fAddDebugCode to true
*/
void VehicleMapInit( bool fRegisterHooks, bool fAddDebugCode = false )
{
	if( fRegisterHooks )
	{
		if( fAddDebugCode )
		{
			g_Hooks.RegisterHook( Hooks::Player::ClientSay, @VehicleClientSay );
		}
		
		g_Hooks.RegisterHook( Hooks::Player::PlayerUse, @VehiclePlayerUse );
		g_Hooks.RegisterHook( Hooks::Player::PlayerPreThink, @VehiclePlayerPreThink );
		g_Hooks.RegisterHook( Hooks::Player::ClientPutInServer, @VehicleClientPutInServer );
	}
	
	g_CustomEntityFuncs.RegisterCustomEntity( "func_vehicle_custom", "func_vehicle_custom" );
	g_CustomEntityFuncs.RegisterCustomEntity( "func_vehiclecontrols", "func_vehiclecontrols" );
	
	//Create beams between all func_vehicle_custom entities
	/*
	const string szSprite = "sprites/xbeam1.spr";
	
	g_Game.PrecacheModel( szSprite );
	
	CBaseEntity@ pPrevEntity = null;
	CBaseEntity@ pEntity = null;
	
	array<EHandle>@ pBeams = array<EHandle>();
	
	while( ( @pEntity = g_EntityFuncs.FindEntityByClassname( pEntity, "func_vehicle_custom" ) ) !is null )
	{
		if( pPrevEntity !is null )
		{
			CBeam@ pBeam = g_EntityFuncs.CreateBeam( szSprite, 40 );
			
			pBeam.EntsInit( pPrevEntity, pEntity );
			pBeam.SetFlags( BEAM_FSINE );
			//pBeam.SetEndAttachment( 1 );
			//pBeam.pev.spawnflags |= SF_BEAM_TEMPORARY;
			
			pBeams.insertLast( EHandle( pBeam ) );
		}
		
		@pPrevEntity = @pEntity;
	}
	
	if( !pBeams.isEmpty() )
	{
		g_Scheduler.SetInterval( "UpdateBeams", 0.1, ( 1 / 0.1 ) * 60, pBeams );
		g_Scheduler.SetTimeout( "CleanupBeams", 60, pBeams );
	}
	*/
}

void UpdateBeams( array<EHandle>@ pBeams )
{
	for( uint uiIndex = 0; uiIndex < pBeams.length(); ++uiIndex )
	{
		if( pBeams[ uiIndex ].IsValid() )
		{
			cast<CBeam@>( pBeams[ uiIndex ].GetEntity() ).RelinkBeam();
		}
	}
}

void CleanupBeams( array<EHandle>@ pBeams )
{
	for( uint uiIndex = 0; uiIndex < pBeams.length(); ++uiIndex )
	{
		g_EntityFuncs.Remove( pBeams[ uiIndex ].GetEntity() );
	}
	
	pBeams.resize(0);
}

HookReturnCode VehicleClientPutInServer( CBasePlayer@ pPlayer )
{
	dictionary@ userData = pPlayer.GetUserData();
	
	userData.set( VEHICLE_RC_EHANDLE_KEY, EHandle() );
	
	return HOOK_CONTINUE;
}

HookReturnCode VehiclePlayerUse( CBasePlayer@ pPlayer, uint& out uiFlags )
{
	if ( ( pPlayer.m_afButtonPressed & IN_USE ) != 0 )
	{
		if( EHandle( pPlayer.GetUserData()[ VEHICLE_RC_EHANDLE_KEY ] ).IsValid() )
		{
			uiFlags |= PlrHook_SkipUse;
			
			TurnVehicleRCControlOff( pPlayer );
			
			return HOOK_CONTINUE;
		}
		
		if ( !pPlayer.m_hTank.IsValid() )
		{
			if ( ( pPlayer.m_afPhysicsFlags & PFLAG_ONTRAIN ) != 0 )
			{
				pPlayer.m_afPhysicsFlags &= ~PFLAG_ONTRAIN;
				pPlayer.m_iTrain = TRAIN_NEW|TRAIN_OFF;

				CBaseEntity@ pTrain = g_EntityFuncs.Instance( pPlayer.pev.groundentity );

				//Stop driving this vehicle if +use again
				if( pTrain !is null )
				{
					func_vehicle_custom@ pVehicle = cast<func_vehicle_custom@>( CastToScriptClass( pTrain ) );
					
					if( pVehicle !is null )
						pVehicle.SetDriver( null );
				}

				uiFlags |= PlrHook_SkipUse;
				
				return HOOK_CONTINUE;
			}
			else
			{	// Start controlling the train!
				CBaseEntity@ pTrain = g_EntityFuncs.Instance( pPlayer.pev.groundentity );
				
				if ( pTrain !is null && (pPlayer.pev.button & IN_JUMP) == 0 && pPlayer.pev.FlagBitSet( FL_ONGROUND ) && (pTrain.ObjectCaps() & FCAP_DIRECTIONAL_USE) != 0 && pTrain.OnControls(pPlayer.pev) )
				{
					pPlayer.m_afPhysicsFlags |= PFLAG_ONTRAIN;
					pPlayer.m_iTrain = TrainSpeed(int(pTrain.pev.speed), pTrain.pev.impulse);
					pPlayer.m_iTrain |= TRAIN_NEW;

					//Start driving this vehicle
					func_vehicle_custom@ pVehicle = cast<func_vehicle_custom@>( CastToScriptClass( pTrain ) );
						
					if( pVehicle !is null )
						pVehicle.SetDriver( pPlayer );
						
					uiFlags |= PlrHook_SkipUse;
					return HOOK_CONTINUE;
				}
			}
		}
	}
	
	return HOOK_CONTINUE;
}

//If player in air, disable control of train
bool HandlePlayerInAir( CBasePlayer@ pPlayer, CBaseEntity@ pTrain )
{
	if ( !pPlayer.pev.FlagBitSet( FL_ONGROUND ) )
	{
		// Turn off the train if you jump, strafe, or the train controls go dead
		pPlayer.m_afPhysicsFlags &= ~PFLAG_ONTRAIN;
		pPlayer.m_iTrain = TRAIN_NEW|TRAIN_OFF;

		//Set driver to NULL if we stop driving the vehicle
		if( pTrain !is null )
		{
			func_vehicle_custom@ pVehicle = cast<func_vehicle_custom@>( CastToScriptClass( pTrain ) );
			
			if( pVehicle !is null )
				pVehicle.SetDriver( null );
		}
		
		if( EHandle( pPlayer.GetUserData()[ VEHICLE_RC_EHANDLE_KEY ] ).IsValid() )
		{
			TurnVehicleRCControlOff( pPlayer );
		}
		
		return true;
	}
	
	return false;
}

HookReturnCode VehiclePlayerPreThink( CBasePlayer@ pPlayer, uint& out uiFlags )
{
	CBaseEntity@ pTrain = null;
	
	bool fUsingRC = EHandle( pPlayer.GetUserData()[ VEHICLE_RC_EHANDLE_KEY ] ).IsValid();
	
	if ( ( pPlayer.m_afPhysicsFlags & PFLAG_ONTRAIN ) != 0 || fUsingRC )
	{
		pPlayer.pev.flags |= FL_ONTRAIN;
	
		@pTrain = @g_EntityFuncs.Instance( pPlayer.pev.groundentity );
		
		if ( pTrain is null )
		{
			TraceResult trainTrace;
			// Maybe this is on the other side of a level transition
			g_Utility.TraceLine( pPlayer.pev.origin, pPlayer.pev.origin + Vector(0,0,-38), ignore_monsters, pPlayer.edict(), trainTrace );

			// HACKHACK - Just look for the func_tracktrain classname
			if ( trainTrace.flFraction != 1.0 && trainTrace.pHit !is null )
				@pTrain = @g_EntityFuncs.Instance( trainTrace.pHit );

			if ( pTrain is null || (pTrain.ObjectCaps() & FCAP_DIRECTIONAL_USE) == 0 || !pTrain.OnControls(pPlayer.pev) )
			{
				//ALERT( at_error, "In train mode with no train!\n" );
				pPlayer.m_afPhysicsFlags &= ~PFLAG_ONTRAIN;
				pPlayer.m_iTrain = TRAIN_NEW|TRAIN_OFF;

				//Set driver to NULL if we stop driving the vehicle
				if( pTrain !is null )
				{
					func_vehicle_custom@ pVehicle = cast<func_vehicle_custom@>( CastToScriptClass( pTrain ) );
					
					if( pVehicle !is null )
						pVehicle.SetDriver( null );
				}
				
				uiFlags |= PlrHook_SkipVehicles;
				return HOOK_CONTINUE;
			}
		}
		else if ( HandlePlayerInAir( pPlayer, pTrain ) )
		{
			uiFlags |= PlrHook_SkipVehicles;
			return HOOK_CONTINUE;
		}

		float vel = 0;

		//Check if it's a func_vehicle - Solokiller 2014-10-24
		if( fUsingRC )
		{
			@pTrain = EHandle(pPlayer.GetUserData()[ VEHICLE_RC_EHANDLE_KEY ]).GetEntity();
			
			//fContinue = false;
		}
		
		if( pTrain is null )
			return HOOK_CONTINUE;
			
		func_vehicle_custom@ pVehicle = cast<func_vehicle_custom@>( CastToScriptClass( pTrain ) );
		
		if( pVehicle is null )
			return HOOK_CONTINUE;
			
		int buttons = pPlayer.pev.button;
		
		if( ( buttons & IN_FORWARD ) != 0 )
		{
			vel = 1;
			pTrain.Use( pPlayer, pPlayer, USE_SET, vel );
		}

		if( ( buttons & IN_BACK ) != 0 )
		{
			vel = -1;
			pTrain.Use( pPlayer, pPlayer, USE_SET, vel );
		}

		if( ( buttons & IN_MOVELEFT ) != 0 )
		{
			vel = 20;
			pTrain.Use( pPlayer, pPlayer, USE_SET, vel );
		}

		if( ( buttons & IN_MOVERIGHT ) != 0 )
		{
			vel = 30;
			pTrain.Use( pPlayer, pPlayer, USE_SET, vel );
		}

		if (vel != 0)
		{
			pPlayer.m_iTrain = TrainSpeed(int(pTrain.pev.speed), pTrain.pev.impulse);
			pPlayer.m_iTrain |= TRAIN_ACTIVE|TRAIN_NEW;
		}
	}
	else 
		pPlayer.pev.flags &= ~FL_ONTRAIN;
	
	return HOOK_CONTINUE;
}

HookReturnCode VehicleClientSay( SayParameters@ pParams )
{
	const CCommand@ pArguments = pParams.GetArguments();
	
	bool fHandled = false;
	
	if( pArguments.ArgC() >= 3 )
	{
		CBaseEntity@ pTrain = g_EntityFuncs.FindEntityByTargetname( null, pArguments[ 1 ] );
			
		if( pTrain !is null )
		{
			func_vehicle_custom@ pVehicle = cast<func_vehicle_custom@>( CastToScriptClass( pTrain ) );
			
			if( pVehicle !is null )
			{
				float flNewValue = atof( pArguments[ 2 ] );

				if( pArguments[ 0 ] == "vehicle_speed" )
				{
					pVehicle.m_speed = flNewValue;
					g_Game.AlertMessage( at_console, "changing speed to %1\n", flNewValue );
					
					fHandled = true;
				}
				else if( pArguments[ 0 ] == "vehicle_accel" )
				{
					pVehicle.m_acceleration = int(flNewValue);
					g_Game.AlertMessage( at_console, "changing acceleration to %1\n", flNewValue );
					
					fHandled = true;
				}
			}
		}
	}
	else if( pArguments.ArgC() >= 2 )
	{
		CBaseEntity@ pTrain = g_EntityFuncs.FindEntityByTargetname( null, pArguments[ 1 ] );
			
		if( pTrain !is null )
		{
			func_vehicle_custom@ pVehicle = cast<func_vehicle_custom@>( CastToScriptClass( pTrain ) );
			
			if( pVehicle !is null )
			{
				if( pArguments[ 0 ] == "vehicle_restart" )
				{
					pVehicle.Restart();
					g_Game.AlertMessage( at_console, "restarting vehicle\n" );
					
					fHandled = true;
				}
			}
		}
	}
	
	if( !fHandled )
		g_Game.AlertMessage( at_console, "not changing anything\n" );

	return HOOK_CONTINUE;
}