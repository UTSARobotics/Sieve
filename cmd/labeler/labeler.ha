use fmt;
use hac;
use vacui;
use time;
use os;
use io;
use fs;
use math;
use path;
use strings;
use fs::{flag};
use errors;

let WIDTH:size=0;
let HEIGHT:size=0;
let WINWIDTH:size = 0;
let WINHEIGHT:size = 0;
let X:f32=0.0;
let Y:f32=0.0;
def STRANDSIZE = 126z; // max points = 63
let CLICKS:[STRANDSIZE]f32= [0.0...];
let idx:size=0;

// STORE multiple strands of fungi
let allstrands: [127*STRANDSIZE]f32 = [0.0...];
let lengths: [127]size = [0...]; // num points
let widths: [127]f32 = [0.0...];
let strand:size = 0;


let SKIP = false;
let WIDTHSELECT:bool = false;
let NEXT_IMAGE:bool = false;
let fungi_width:f32 = 0.0;

@symbol("stbi_load_from_memory") fn stbi_load_from_memory(
	buffer: *u8,
	length: int,
	x: *int,
	y: *int,
	channels: *int,
	desired_channels: int,
) nullable *u8;

@symbol("stbi_image_free") fn stbi_image_free(pixels: nullable *u8) void;

fn load_image(filepath: str) (nullable *u8, int, int, int) = {
	// 1. Open and read the file into memory
	const file = match (os::open(filepath)) {
	case let file: io::file =>
		yield file;
	case let err: fs::error =>
		fmt::fatalf("Error opening {}: {}", os::args[1], fs::strerror(err));
	};
	defer io::close(file)!;

	// Read entire file into memory
	const filebuf = match (io::drain(file)) {
	case let buf: []u8 =>
		yield buf;
	case let err: io::error =>
		fmt::fatalf("Error reading file: {}", io::strerror(err));
	};
	defer free(filebuf);
	fmt::printfln("buffer len: {}", len(filebuf))!;

	// 2. Use stb_image to decode
	let width: int = 0;
	let height: int = 0;
	let channels: int = 0;
	const desired_channels = 4; // We want RGBA output

	let pixels = stbi_load_from_memory(
		&filebuf[0],
		len(filebuf): int,
		&width,
		&height,
		&channels,
		desired_channels,
	);

	if (pixels == null) {
		fmt::printfln("Failed to load image {}", filepath)!;
	};
	fmt::printfln("Loaded!")!;
	return (pixels, width, height, channels);
};

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


fn save_fungi(image_path: *path::buffer) void = {
	// skip write if no fungi labeled.
	// if(strand == 0 && !SKIP) {
	// 	return;
	// };
	// get data file path
	let img_ext = path::pop_ext(image_path);
	path::push_ext(image_path, "wxf")!;
	let data_path = path::string(image_path);

	// reset
	path::pop_ext(image_path);
	path::push_ext(image_path, img_ext:str)!;

	let buffer:[]u8 = alloc([0u8...], strand*STRANDSIZE*4+16)!; // Preallocate and use arenas.
	defer free(buffer);
	let i = 0z;
	// save clicks as i16 fractions (e.g. click = x_i16:f64 / 32767:f64)
	// note I16_MAX = 32767
	// go through strands

	// write wxf header
	buffer[i] = '8';
	buffer[i+1] = ':';
	i += 2;

	if(SKIP){
		write_function(buffer, &i, "skip", 0);
	} else {
		// write list of strands
		write_function(buffer, &i, "List", strand);

		// write each strand
		for (let s=0z; s < strand; s += 1) {
			let length = lengths[s];
			// write hypha
			write_function(buffer, &i, "hypha", 1+length);
			// write width as i16
			let width:f32 = widths[s];
			let widthi = encode_fraci16(width);
			buffer[i] = 'j';
			buffer [i+1] = widthi:u8;
			buffer [i+2] = (widthi >> 8):u8;
			i += 3;

			// go through each point on the strand and save as i16
			let st = allstrands[s*STRANDSIZE..s*STRANDSIZE+length];
			for (let p = 0z; p < length; p+=2) {
				//x
				let x = encode_fraci16(st[p]);
				buffer[i] = 'j';
				buffer[i+1] = x:u8;
				buffer[i+2] = (x >> 8):u8;
				//y
				let y = encode_fraci16(st[p+1]);
				buffer[i+3] = 'j';
				buffer[i+4] = y:u8;
				buffer[i+5] = (y >> 8):u8;
				i += 6;
			};
		};
	};

	//write
	const file = match (os::create(data_path, 0o644, flag::WRONLY | flag::TRUNC)) {
	case let file: io::file =>
		yield file;
	case errors::noaccess =>
		fmt::fatalf("Error opening {}: Access denied.", data_path);
	case let err: fs::error =>
		fmt::fatalf("Error opening {}: {}", data_path, fs::strerror(err));
	};

	match (io::write(file, buffer[..i])) {
	case let err: io::error =>
		fmt::fatalf("Error writing file: {}", io::strerror(err));
	case let z: size =>
		assert(z == i, "Unexpected short write");

	};
};

fn load_fungi(image_path: *path::buffer) void = {
	// get data file path
	let img_ext = path::pop_ext(image_path);
	path::push_ext(image_path, "wxf")!;
	let data_path = path::string(image_path);

	// reset
	path::pop_ext(image_path);
	path::push_ext(image_path, img_ext:str)!;

	const file = match (os::open(data_path)) {
	case let file: io::file =>
		yield file;
	case let err: fs::error =>
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

export fn main() void = {
	let start = hac::count();
	if (len(os::args) != 2) {
		fmt::fatalf("Usage: {} <image_folder>", os::args[0]);
	};

	// initialize GUI window
	let pixels_disp:[]u8 = alloc([0u8...], 4096 * 4096 * 4)!;
	let alloctime = hac::count();
	let UI = vacui::init("labeler", 640, 480, 4096)!;
	glfwSetCursorPosCallback(UI.gles_window:*opaque, &mouse_callback);
	glfwSetMouseButtonCallback(UI.gles_window:*opaque, &click_callback);
	glfwSetKeyCallback(UI.gles_window:*opaque, &key_callback);

	// Process each directory entry...
	let buf = path::init(os::args[1])!;
	let iter = os::iter(path::string(&buf))!;
	for (const d => fs::next(iter)!) {
	if (d.name == "." || d.name == "..") {
		continue;
	};

	fmt::printfln("file name: {}", d.name)!;
	path::push(&buf, d.name)!;
	defer path::pop(&buf);

	// check the extension, skip common non-images.
	let ext = match(path::pop_ext(&buf)) {
	case void =>
		continue;
	case let e:str =>
		yield e;
	};
	if (ext == ".txt" || ext == ".csv" || ext == ".wxf") {
		continue;
	};

	path::push_ext(&buf, ext:str)!;

	// try to load image
	fmt::printfln("Trying to load {}", path::string(&buf))!;
	let (pixels, width, height, channels) = load_image(path::string(&buf));
	if(pixels == null) {
		continue;
	};

	idx = 0;
	strand = 0;
	SKIP = false;
	load_fungi(&buf);

	for(vacui::ok() && !NEXT_IMAGE) {
		WIDTH = UI.draw_width:size;
		HEIGHT = UI.draw_height:size;
		WINWIDTH = UI.window_width:size;
		WINHEIGHT = UI.window_height:size;
		// fmt::printfln("size: ({}, {})", WIDTH, HEIGHT)!;
		// Calculate scaling factors
		let scale_x = width:f32 / WIDTH:f32;
		let scale_y = height:f32 / HEIGHT:f32;

		let src = pixels: *[*]u8;
		let disp = pixels_disp: *[*]u8;

		// TODO only copy from original image after resize
		//   = maintain second buffer.
		// Scale using two loops for x,y coordinates
		for (let y = 0z; y < HEIGHT; y += 1) {
		for (let x = 0z; x < WIDTH; x += 1) {
			// Calculate source and destination pixel positions
			let src_x = (x:f32 * scale_x):size;
			let src_y = (y:f32 * scale_y):size;

			// Calculate array indices
			let dst_idx = ((HEIGHT-y) * WIDTH + x) * 4;
			let src_idx = (src_y * width:size + src_x) * 4;

			// Copy RGBA values
			disp[dst_idx + 0] = src[src_idx + 0];
			disp[dst_idx + 1] = src[src_idx + 1];
			disp[dst_idx + 2] = src[src_idx + 2];
			disp[dst_idx + 3] = src[src_idx + 3];
		};
		}; //DRAW IMAGE


		if(SKIP) {
			let x0 = 0:f32;
			let y0 = 0:f32;
			let x1 = 1:f32;
			let y1 = 1:f32;

			// compute number of steps
			let distx = math::absf32((x1-x0)*WIDTH:f32);
			let disty = math::absf32((y1-y0)*WIDTH:f32);
			let dist:i32 = if(distx > disty) distx:i32 else disty:i32;

			let xf = x0;
			let yf = y0;
			let dx = (x1-x0) / dist:f32;
			let dy = (y1-y0) / dist:f32;

			// fmt::printfln("({}, {}), ({}, {})", x0, y0, x1, y1)!;
			// consider avoiding redraws.
			let lastx:i32 = -1;
			let lasty:i32 = -1;
			for(let i=0i32; i < dist; i += 1) {
				let x = (xf * WIDTH:f32):i32;
				if (x > WIDTH:i32) x = WIDTH:i32;
				if (x < 0i32) x = 0;
				let y = HEIGHT:i32 - (yf * HEIGHT:f32):i32;
				if (y > HEIGHT:i32) y = HEIGHT:i32;
				if (y < 0i32) y = 0;
				let dst_idx = ((y * WIDTH:i32 + x) << 2):size;
				disp[dst_idx + 0] = 255;
				disp[dst_idx + 1] = 0;
				disp[dst_idx + 2] = 0;
				disp[dst_idx + 3] = 255;
				xf += dx;
				yf += dy;
			};

			let x0 = 1:f32;
			let y0 = 0:f32;
			let x1 = 0:f32;
			let y1 = 1:f32;

			// compute number of steps
			let distx = math::absf32((x1-x0)*WIDTH:f32);
			let disty = math::absf32((y1-y0)*WIDTH:f32);
			let dist:i32 = if(distx > disty) distx:i32 else disty:i32;

			let xf = x0;
			let yf = y0;
			let dx = (x1-x0) / dist:f32;
			let dy = (y1-y0) / dist:f32;

			// fmt::printfln("({}, {}), ({}, {})", x0, y0, x1, y1)!;
			// consider avoiding redraws.
			let lastx:i32 = -1;
			let lasty:i32 = -1;
			for(let i=0i32; i < dist; i += 1) {
				let x = (xf * WIDTH:f32):i32;
				if (x > WIDTH:i32) x = WIDTH:i32;
				if (x < 0i32) x = 0;
				let y = HEIGHT:i32 - (yf * HEIGHT:f32):i32;
				if (y > HEIGHT:i32) y = HEIGHT:i32;
				if (y < 0i32) y = 0;
				let dst_idx = ((y * WIDTH:i32 + x) << 2):size;
				disp[dst_idx + 0] = 255;
				disp[dst_idx + 1] = 0;
				disp[dst_idx + 2] = 0;
				disp[dst_idx + 3] = 255;
				xf += dx;
				yf += dy;
			};
		} else {
		if (WIDTHSELECT) {
		// draw offset
		let x0 = CLICKS[idx-2]:f32;
		let y0 = CLICKS[idx-1]:f32;
		let x1 = X;
		let y1 = Y;

		// compute number of steps
		let distx = math::absf32((x1-x0)*WIDTH:f32);
		let disty = math::absf32((y1-y0)*WIDTH:f32);
		let dist:i32 = if(distx > disty) distx:i32 else disty:i32;

		let xf = x0;
		let yf = y0;
		let dx = (x1-x0) / dist:f32;
		let dy = (y1-y0) / dist:f32;

		for(let i=0i32; i < dist; i += 1) {
			let x = (xf * WIDTH:f32):i32;
			if (x > WIDTH:i32) x = WIDTH:i32;
			if (x < 0i32) x = 0;
			let y = HEIGHT:i32 - (yf * HEIGHT:f32):i32;
			if (y > HEIGHT:i32) y = HEIGHT:i32;
			if (y < 0i32) y = 0;
			let dst_idx = ((y * WIDTH:i32 + x) << 2):size;
			disp[dst_idx + 0] = 0;
			disp[dst_idx + 1] = 255;
			disp[dst_idx + 2] = 255;
			disp[dst_idx + 3] = 255;
			xf += dx;
			yf += dy;
		};

		// draw strand width
		// COMPUTE PROJECTION of last line
		let vx0 = (x1-x0);
		let vy0 = (y1-y0);

		let x0 = CLICKS[idx-4]:f32;
		let y0 = CLICKS[idx-3]:f32;
		let x1 = CLICKS[idx-2]:f32;
		let y1 = CLICKS[idx-1]:f32;

		let vx = x1 - x0;
		let vy = y1 - y0;
		let norm = math::sqrtf64(
			math::powf64(vx:f64, 2.0)
			+ math::powf64(vy:f64, 2.0)):f32;
		let offsetx = -vy/norm;
		let offsety = vx/norm;
		fungi_width = math::absf32(vx0 * offsetx + vy0 * offsety);
		if (fungi_width > 0.05) fungi_width=0.05;
		for (let click = 3z; click < idx; click += 2) {
		// draw offset points
		for (let dir:f32=-1f32; dir < 2f32; dir += 2f32) {
			let x0 = CLICKS[click-3]:f32;
			let y0 = CLICKS[click-2]:f32;
			let x1 = CLICKS[click-1]:f32;
			let y1 = CLICKS[click-0]:f32;

			let vx = x1 - x0;
			let vy = y1 - y0;
			let norm = math::sqrtf64(
				math::powf64(vx:f64, 2.0)
				+ math::powf64(vy:f64, 2.0)):f32;
			let offsetx = -vy/norm*dir;
			let offsety = vx/norm*dir;
			x0 += offsetx*fungi_width;
			x1 += offsetx*fungi_width;
			y0 += offsety*fungi_width;
			y1 += offsety*fungi_width;

			// hack, draw point to current mouse position.
			if (click >= idx) {
				x1 = X:f32;
				y1 = Y:f32;
			};

			// compute number of steps
			let distx = math::absf32((x1-x0)*WIDTH:f32);
			let disty = math::absf32((y1-y0)*WIDTH:f32);
			let dist:i32 = if(distx > disty) distx:i32 else disty:i32;

			let xf = x0;
			let yf = y0;
			let dx = (x1-x0) / dist:f32;
			let dy = (y1-y0) / dist:f32;

			for(let i=0i32; i < dist; i += 1) {
				let x = (xf * WIDTH:f32):i32;
				if (x > WIDTH:i32) x = WIDTH:i32;
				if (x < 0i32) x = 0;
				let y = HEIGHT:i32 - (yf * HEIGHT:f32):i32;
				if (y > HEIGHT:i32) y = HEIGHT:i32;
				if (y < 0i32) y = 0;
				let dst_idx = ((y * WIDTH:i32 + x) << 2):size;
				disp[dst_idx + 0] = 255;
				disp[dst_idx + 1] = 0;
				disp[dst_idx + 2] = 0;
				disp[dst_idx + 3] = 255;
				xf += dx;
				yf += dy;
			};
		};
		};
		} else {
		// draw active strand
		for (let click = 3z; click < (idx + 2); click += 2) {
			// draw last point
			let x0 = CLICKS[click-3]:f32;
			let y0 = CLICKS[click-2]:f32;
			let x1 = CLICKS[click-1]:f32;
			let y1 = CLICKS[click-0]:f32;
			if (click >= idx) {
				x1 = X:f32;
				y1 = Y:f32;
			};

			// compute number of steps
			let distx = math::absf32((x1-x0)*WIDTH:f32);
			let disty = math::absf32((y1-y0)*WIDTH:f32);
			let dist:i32 = if(distx > disty) distx:i32 else disty:i32;

			let xf = x0;
			let yf = y0;
			let dx = (x1-x0) / dist:f32;
			let dy = (y1-y0) / dist:f32;

			for(let i=0i32; i < dist; i += 1) {
				let x = (xf * WIDTH:f32):i32;
				if (x > WIDTH:i32) x = WIDTH:i32;
				if (x < 0i32) x = 0;
				let y = HEIGHT:i32 - (yf * HEIGHT:f32):i32;
				if (y > HEIGHT:i32) y = HEIGHT:i32;
				if (y < 0i32) y = 0;
				let dst_idx = ((y * WIDTH:i32 + x) << 2):size;
				disp[dst_idx + 0] = 0;
				disp[dst_idx + 1] = 255;
				disp[dst_idx + 2] = 255;
				disp[dst_idx + 3] = 255;
				xf += dx;
				yf += dy;
			};
		};
		}; // DRAW ACTIVE STRAND

		// draw previous strands
		for (let s = 0z; s < (strand); s += 1) {
			let idx = lengths[s];
			let CLICKS = allstrands[s*STRANDSIZE..s*STRANDSIZE+idx];
		for (let click = 3z; click < idx; click += 2) {
			// draw last point
			let x0 = CLICKS[click-3]:f32;
			let y0 = CLICKS[click-2]:f32;
			let x1 = CLICKS[click-1]:f32;
			let y1 = CLICKS[click-0]:f32;

			// compute number of steps
			let distx = math::absf32((x1-x0)*WIDTH:f32);
			let disty = math::absf32((y1-y0)*WIDTH:f32);
			let dist:i32 = if(distx > disty) distx:i32 else disty:i32;

			let xf = x0;
			let yf = y0;
			let dx = (x1-x0) / dist:f32;
			let dy = (y1-y0) / dist:f32;

			// fmt::printfln("({}, {}), ({}, {})", x0, y0, x1, y1)!;
			// consider avoiding redraws.
			let lastx:i32 = -1;
			let lasty:i32 = -1;
			for(let i=0i32; i < dist; i += 1) {
				let x = (xf * WIDTH:f32):i32;
				if (x > WIDTH:i32) x = WIDTH:i32;
				if (x < 0i32) x = 0;
				let y = HEIGHT:i32 - (yf * HEIGHT:f32):i32;
				if (y > HEIGHT:i32) y = HEIGHT:i32;
				if (y < 0i32) y = 0;
				let dst_idx = ((y * WIDTH:i32 + x) << 2):size;
				disp[dst_idx + 0] = 255;
				disp[dst_idx + 1] = 121;
				disp[dst_idx + 2] = 0;
				disp[dst_idx + 3] = 255;
				xf += dx;
				yf += dy;
			};
		}; // draw line
		}; // DRAW PREVIOUS STRANDS
		}; // SKIP

		vacui::draw(pixels_disp[..(WIDTH * HEIGHT * 4)])!;
		time::sleep(15 * time::MILLISECOND);
		vacui::checkevents(); // run callbacks


		if (!vacui::ok()) {
			return;
		};
		if (NEXT_IMAGE) {
			NEXT_IMAGE = false;
			save_fungi(&buf);
			stbi_image_free(pixels);
			break;
		};
		}; /// RENDER LOOP

	};

	fmt::printfln("labeler")!;
	fmt::printfln("... took {} ns", hac::ns(start))!;
};

export @symbol("glfwSetCursorPosCallback") fn glfwSetCursorPosCallback(
	window: *opaque,
	callback: *fn(win:*opaque, x:f64, y:f64) void
) void;

export @symbol("glfwSetMouseButtonCallback") fn glfwSetMouseButtonCallback(
	window: *opaque,
	callback: *fn(win:*opaque, button:int, act:int, mods:int) void
) void;

export @symbol("glfwSetKeyCallback") fn glfwSetKeyCallback(
	window: *opaque,
	callback: *fn(win:*opaque, key:int, scan:int, act:int, mods:int) void
) void;


fn mouse_callback(win:*opaque, x:f64, y:f64) void = {
	// fmt::printfln("x: {}, y {}", x/WIDTH:f64, y/HEIGHT:f64)!;
	// fmt::printfln("WIDTH: {}, HEIGHT {}", WIDTH:f64, HEIGHT:f64)!;
	X=(x/WINWIDTH: f64):f32;
	Y=(y/WINHEIGHT: f64):f32;
};

fn click_callback(win:*opaque, button:int, act:int, mods:int) void = {
	if(act == vacui::RELEASE) {
		// handle repeat click (ignore or save)
		if(WIDTHSELECT) {
			if(idx < 4) {
				return; // not enough points to add strand
			};
			if (strand > 127) {
				return; // too many strands added
			};
			if (math::absf32(X-CLICKS[idx-2]) < 0.001 &&
				math::absf32(Y-CLICKS[idx-1]) < 0.001) {
				return; // ignore duplicate click
			};
			allstrands[strand*STRANDSIZE..strand*STRANDSIZE+idx]
				= CLICKS[..idx];
			lengths[strand] = idx;
			widths[strand] = fungi_width;
			strand += 1;
			idx = 0;
			WIDTHSELECT=false;
			fmt::printfln("DOUBLE-CLICK Strands {}", strand)!;
			return;
		};
		if (idx > 2 &&
		math::absf32(X-CLICKS[idx-2]) < 0.01 &&
		math::absf32(Y-CLICKS[idx-1]) < 0.01) {
			WIDTHSELECT = true;
			return;
		} else { // add mew click to current strand
			fmt::printfln("CLICK Selected {},{}", X, Y)!;
			CLICKS[idx] = X;
			CLICKS[idx + 1] = Y;
			idx += 2;
		};
	};
};


fn key_callback(win:*opaque, key:int, scan:int, act:int, mods:int) void = {
	if (key==vacui::KEY_BACKSPACE &&
			(act == vacui::PRESS || act == vacui::REPEAT) &&
			idx >= 2) {
		if(WIDTHSELECT) {
			// get out of widthselect
			WIDTHSELECT = false;
			return;
		};
		idx -= 2;
		fmt::printfln("BACKSPACE, IDX {}", idx)!;
		return;
	};
	if (key==vacui::KEY_ESCAPE &&
			(act == vacui::PRESS || act == vacui::REPEAT)) {
		if(WIDTHSELECT) {
			// get out of widthselect.
			WIDTHSELECT = false;
			return;
		};
		idx = 0;
		fmt::printfln("ESCAPE, IDX {}", idx)!;
		return;
	};

	// delete last strand if index is zero
	if (key==vacui::KEY_BACKSPACE && act == vacui::PRESS && idx == 0) {
		fmt::printfln("BACKSPACE DELETE STRAND, strand {}", strand)!;
		if (strand > 0) {
			strand -= 1;
		};
		return;
	};

	// complete strand from enter
	if (key==vacui::KEY_ENTER && act == vacui::PRESS) {
		fmt::printfln("ENTER")!;
		if (idx > 2) {
			WIDTHSELECT=true;
		};
	};

	// complete strand from enter
	if (key==vacui::KEY_RIGHT && act == vacui::PRESS) {
		fmt::printfln("NEXT")!;
		NEXT_IMAGE = true;
	};

	// complete strand from enter
	if (key==vacui::KEY_S && act == vacui::PRESS && (mods&vacui::MOD_CONTROL == 0)) {
		SKIP = !SKIP;
	};
};
