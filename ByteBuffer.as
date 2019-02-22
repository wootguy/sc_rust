class ByteBuffer
{
	array<uint8> data; // output encoded in escape characters ("\xFF")
	uint readPos = 0; // read position
	int err = 0; // non-zero if read error occurred
	
	// Starts at \x01 since null characters aren't allowed in the base128 output
	// Unrelated note: You can't append \x00 or \0 to a string
	// Codes that were replaced because they cause read failures:
	// \x1A -> \x81
	array<char> HexCodes = {
		'\x01','\x02','\x03','\x04','\x05','\x06','\x07','\x08','\x09','\x0A','\x0B','\x0C','\x0D','\x0E','\x0F',
		'\x10','\x11','\x12','\x13','\x14','\x15','\x16','\x17','\x18','\x19','\x81','\x1B','\x1C','\x1D','\x1E','\x1F',
		'\x20','\x21','\x22','\x23','\x24','\x25','\x26','\x27','\x28','\x29','\x2A','\x2B','\x2C','\x2D','\x2E','\x2F',
		'\x30','\x31','\x32','\x33','\x34','\x35','\x36','\x37','\x38','\x39','\x3A','\x3B','\x3C','\x3D','\x3E','\x3F',
		'\x40','\x41','\x42','\x43','\x44','\x45','\x46','\x47','\x48','\x49','\x4A','\x4B','\x4C','\x4D','\x4E','\x4F',
		'\x50','\x51','\x52','\x53','\x54','\x55','\x56','\x57','\x58','\x59','\x5A','\x5B','\x5C','\x5D','\x5E','\x5F',
		'\x60','\x61','\x62','\x63','\x64','\x65','\x66','\x67','\x68','\x69','\x6A','\x6B','\x6C','\x6D','\x6E','\x6F',
		'\x70','\x71','\x72','\x73','\x74','\x75','\x76','\x77','\x78','\x79','\x7A','\x7B','\x7C','\x7D','\x7E','\x7F',
		'\x80',
	};
	
	ByteBuffer() {}
	
	ByteBuffer(File& f)
	{
		string base128Data;
		f.ReadLine(base128Data, "\xFF");
		base128decode(base128Data);
	}
	
	// convert a float to a fixed-point 18.14 integer
	// Max range of +/-131,071 with 16383 steps (~0.000061) between whole numbers 
	int32 floatToFixed14(float f)
	{
		return int32(f * 16384.0f);
	}
	
	float fixed14ToFloat(int32 fixed)
	{
		return float(fixed) / 16384.0f;
	}
	
	// convert a double to a fixed-point 32.32 integer
	// Max range of +/-2.1 billion with 4.3 billion steps (~0.0000000002) between whole numbers 
	int64 doubleToFixed32(double f)
	{
		return int64(f * 2147483648.0);
	}
	
	double fixed32ToDouble(int64 fixed)
	{
		return double(fixed) / 2147483648.0;
	}
	
	void WriteByte(uint8 byte)
	{
		data.insertLast(byte);
	}
	
	void Write(uint8 num)
	{
		WriteByte(num);
	}
	
	void Write(uint16 num)
	{
		WriteByte((num >> 8) & 0xff);
		WriteByte(num & 0xff);
	}
	
	void Write(uint32 num)
	{
		WriteByte(num >> 24);
		WriteByte((num >> 16) & 0xff);
		WriteByte((num >> 8) & 0xff);
		WriteByte(num & 0xff);
	}
	
	void Write(uint64 num)
	{
		WriteByte(num >> 56);
		WriteByte((num >> 48) & 0xff);
		WriteByte((num >> 40) & 0xff);
		WriteByte((num >> 32) & 0xff);
		WriteByte((num >> 24) & 0xff);
		WriteByte((num >> 16) & 0xff);
		WriteByte((num >> 8) & 0xff);
		WriteByte(num & 0xff);
	}
	
	void Write(int8 num) { Write(uint8(num)); }
	void Write(int16 num) { Write(uint16(num)); }
	void Write(int32 num) { Write(uint32(num)); }
	void Write(int64 num) { Write(uint64(num)); }
	
	void Write(float num)
	{
		// Can't interpret float as bytes, so we have to convert to an int first (loses some precision)
		Write(uint32(floatToFixed14(num)));
	}
	
	void Write(double num)
	{
		// Can't interpret float as bytes, so we have to convert to an int first (loses some precision)
		Write(uint64(doubleToFixed32(num)));
	}
	
	void Write(ByteBuffer&in buf)
	{
		for (uint i = 0; i < buf.data.length(); i++)
			data.insertLast(buf.data[i]);
	}
	
	void Write(string&in s, uint size)
	{
		for (uint i = 0; i < size; i++)
		{
			if (i < s.Length())
				WriteByte(uint8(s[i]));
			else
				WriteByte(0);
		}
	}
	
	void Write(string&in s)
	{
		for (uint i = 0; i < s.Length(); i++)
			WriteByte(uint8(s[i]));
		WriteByte(0);
	}
	
	uint64 ReadByte()
	{
		if (readPos >= data.length())
		{
			println("ByteBuffer: Read overflow (" + (readPos+1) + " / " + data.length() + ")");
			err++;
			return 0;
		}
		return uint8(data[readPos++]);
	}
	
	uint8 ReadUInt8()
	{
		return ReadByte();
	}
	
	uint16 ReadUInt16()
	{
		return (ReadByte() << 8) + ReadByte();
	}
	
	uint32 ReadUInt32()
	{
		return (ReadByte() << 24) + (ReadByte() << 16) + (ReadByte() << 8) + ReadByte();
	}
	
	uint64 ReadUInt64()
	{
		return	(ReadByte() << 56) + (ReadByte() << 48) + (ReadByte() << 40) + (ReadByte() << 32) +
				(ReadByte() << 24) + (ReadByte() << 16) + (ReadByte() << 8) + ReadByte();
	}
	
	int8 ReadInt8() { return ReadUInt8(); }
	int16 ReadInt16() { return ReadUInt16(); }
	int32 ReadInt32() { return ReadUInt32(); }
	int64 ReadInt64() { return ReadUInt64(); }
	
	float ReadFloat()
	{
		return fixed14ToFloat(ReadUInt32());
	}
	
	float ReadDouble()
	{
		return fixed32ToDouble(ReadUInt64());
	}
	
	string ReadString(uint size)
	{
		string ret;
		for (uint i = 0; i < size; i++)
		{
			uint8 b = ReadByte();
			if (b > 0)
				ret += HexCodes[b-1];
		}
		return ret;
	}
	
	string ReadString()
	{
		string ret;
		while (true)
		{
			uint8 byte = ReadByte();
			if (byte == 0) // null char or reached end of buffer
				break;
			if (byte > 0)
				ret += HexCodes[byte-1];
		}
		return ret;
	}
	
	string base128encode()
	{
		// https://github.com/seizu/base128/blob/master/base128.php
		
		data.insertLast(0);
		int size = data.length();
		uint ls = 0;
		uint rs = 7;
		uint r = 0;
		string ret;
		for(int inx = 0; inx < size; inx++)
		{
			if (ls > 7)
			{
				inx--;
				ls = 0;
				rs = 7;
			}
			uint8 nc = data[inx];
			uint8 r1 = nc;                 // save nc
			nc = nc << ls;            // shift left for rs
			nc = (nc & 0x7f) | r;      // OR carry bits
			r = (r1 >> rs) & 0x7F;     // shift right and save carry bits
			ls++;
			rs--;
			ret += HexCodes[nc];
		}
		return ret;
	}
	
	void base128decode(string input)
	{
		int size = input.Length();
		uint rs = 8;
		uint ls = 7;
		uint r = 0;
		for(int inx = 0; inx < size; inx++)
		{
			uint8 nc = input[inx];
			if (nc == 0x81) // special case for hex code that couldn't be written to file
				nc = 0x1A;
			nc--;
			
			if (rs > 7)
			{
				rs = 1;
				ls = 7;
				r = nc;
				continue;
			}
			uint8 r1 = nc;
			nc = (nc << ls) & 0xFF;
			nc = nc | r;
			r = r1 >> rs;
			rs++;
			ls--;
			
			data.insertLast(nc);
		}
	}
}
