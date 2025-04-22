use math;
use strings;

// Utility functions for encoding/decoding WXF data

// everything is packaged as function
fn write_function(buffer:[]u8, i:*size, name:str, length:size) void = {
	buffer[*i] = 'f'; *i+=1;
	assert(length < 0b10000000z); // TODO (2025) varint. 127 is max. (precompute i and add at end)
	buffer[*i] = length:u8; *i+= 1;
	assert(len(name) < 0b10000000z); // TODO (2025) varint. 127 is max. (precompute i and add at end)
	buffer[*i] = len(name):u8; *i+=1;
	buffer[*i..*i+len(name)] = strings::toutf8(name); *i+=len(name);
};

// encode a fraction as an i16
fn encode_fraci16(x:f32) i16 = {
	if (x > 1.0) x = 1.0;
	if (x < 0.0) x = 0.0;
	return math::roundf64(x:f64 * 32767:f64):i16;
};

// decode a fraction from an i16
fn decode_fraci16(x:i16) f32 = {
	if (x < 0) x = 0;
	return (x:f64 / 32767:f64):f32;
};
