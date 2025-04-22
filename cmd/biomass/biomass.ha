use fmt;
use hac;


fn main() void = {
	let start = hac::count();
	if (len(os::args) != 2) {
		// 350 200
		// 1320 1380
		fmt::fatalf("Usage: {} <x_um> <y_um> <image_folder>", os::args[0]);
	};
};

fn load_fungi(wxf_path: *path::buffer) void = {
	const file = match (os::open(wxf_path)) {
	case let file: io::file =>
		yield file;
	case let err: fs::error =>
		printfln("Error opening file!")!;
		// fmt::printfln("Error opening {}: {}", os::args[1], fs::strerror(err))!;
		return; // no file
	};
	defer io::close(file)!;

	const buf = match (io::drain(file)) {
	case let b: []u8 =>
		yield b;
	case let err: io::error =>
		return; // could not open file
	};
	defer free(buf);
	// read fungi

	let i = 0z;
	// check header
	if (buf[0]!='8' || buf[1] != ':') {
		fmt::printfln("INVALID HEADER")!;
		return;
	};
	i+= 2;

	let error = false;
	// read list size
	error = (buf[i]!='f'); i += 1; // 'f' <count> <List> <hypha> <hypha> ...
	if(error) return;
	strand = buf[i]:size; i+= 1;
	if(strand == 0 && buf[i+1]=='s') {
		// SKIP images have 0 hyphae and are labeled as skip.
		fmt::printfln("SKIP LOADED")!;
		SKIP=true;
		return;
	};
	fmt::printfln("count is {}", strand)!;
	assert(buf[i] == 4);
	i += 5; // [<4>, L, i, s, t]

	for (let s=0z; s < strand; s += 1) {
		assert(buf[i] == 'f');
		i += 1; // f
		let length = buf[i]:size - 1; i+= 1;
		lengths[s] = length;
		fmt::printfln("length of strand {} is {}", s, length)!;
		assert(buf[i] == 5); i += 6; // [<5>, h, y, p, h, a]
		assert(buf[i] == 'j'); // j
		let width:u16 = (buf[i+1]:u16);
		width |= ((buf[i+2]:u16)) << 8;
		widths[s] = decode_fraci16(width:i16);
		fmt::printfln("width of strand {} is {}", s, width)!;
		i += 3;
		let st = allstrands[s*STRANDSIZE..s*STRANDSIZE+length];
		for(let p:size = 0z; p < length; p += 1) {
			fmt::printfln("point {} is {}", p, buf[i])!;
			assert(buf[i] == 'j'); // j
			let pointxy:u16 = buf[i+1]:u16;
			pointxy |= (buf[i+2]:u16) << 8;
			st[p] = decode_fraci16(pointxy:i16);
			i += 3;
		};
	};
};

// decode a fraction from an i16
fn decode_fraci16(x:i16) f32 = {
	if (x < 0) x = 0;
	return (x:f64 / 32767:f64):f32;
};
