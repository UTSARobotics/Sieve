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
use sort;
use sort::cmp;

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
let N_IMAGES=0;
let image_idx=0;
let DIRECTION = 1;

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
	let UI = vacui::init("labeler", 640, 480, 1440)!;
	vacui::glfwSetCursorPosCallback(UI.gles_window:*opaque, &mouse_callback);
	vacui::glfwSetMouseButtonCallback(UI.gles_window:*opaque, &click_callback);
	vacui::glfwSetKeyCallback(UI.gles_window:*opaque, &key_callback);

	// Process each directory entry...
	let buf = path::init(os::args[1])!;
	let iter = os::iter(path::string(&buf))!;

	let FILENAMES:[1024]str = [""...];
	// = alloc(????, 1024)!; // up to 512 images + .wxf

	let file_index = 0z;
	for (const current_image => fs::next(iter)!) {
		path::push(&buf, current_image.name)!;
		defer path::pop(&buf);

		let ext = match(path::pop_ext(&buf)) {
		case void =>
			continue;
		case let e:str =>
			yield e;
		};

		if (ext == "txt" || ext == "csv" || ext == "wxf") {
			continue;
		};

		FILENAMES[file_index] = strings::dup(current_image.name)!;
		file_index += 1;

		// fmt::printfln("idx: {}", file_index)!;
		if(file_index > 1024) {
			fmt::printfln("Warning: Skipping some images because there are over 1024 in the directory!")!;
			break;
		};
		// fmt::printfln("EXTENSION: {}", ext)!;
		// fmt::printfln("file name: {}", current_image.name)!;
		// fmt::printfln("file name: {}", FILENAMES[file_index-1])!;
	};
	defer fs::finish(iter); // doing now would only add delay?

	N_IMAGES = file_index:int;

	sort::sort(FILENAMES[..N_IMAGES], size(str), &cmp::strs);

	// Print filenames:
	// for (let i = 0z; i < file_index; i+=1) {
	// 	fmt::printfln("file name: {}", FILENAMES[i])!;
	// };

	// loop through file names
	image_idx=0;
	for (true) {
	if(image_idx < 0) image_idx = 0;
	if(image_idx >= N_IMAGES) {
		fmt::printfln("Folder Complete! Good Job 😁")!;
		break;
	};

	fmt::printfln("file name: {}", FILENAMES[image_idx])!;
	path::push(&buf, FILENAMES[image_idx])!;
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

		// TODO (Alec, 2024) only copy from original image after resize
		//   = maintain second buffer.
		// Scale using two loops for x,y coordinates
		for (let y = 0z; y < HEIGHT; y += 1) {
			for (let x = 0z; x < WIDTH; x += 1) {
				// Calculate source and destination pixel
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
		}; // DRAW IMAGE

		if(SKIP) { // draw an 'X' in red across the screen
			// (x0, y0), (x1, y1)
			draw_line(disp, HEIGHT, WIDTH, 0.0, 0.0, 1.0, 1.0,
				255, 0, 0);
			draw_line(disp, HEIGHT, WIDTH, 1.0, 0.0, 0.0, 1.0,
				255, 0, 0);
		} else { // draw the actual image
		if (WIDTHSELECT) { // draw offset lines
		let x0 = CLICKS[idx-2]:f32;
		let y0 = CLICKS[idx-1]:f32;
		let x1 = X;
		let y1 = Y;

		draw_line(disp, HEIGHT, WIDTH, x0, y0, x1, y1,
			0, 255, 255);

		// draw strand width
		// COMPUTE PROJECTION of last (width) line
		let vxw0 = (x1-x0);
		let vyw0 = (y1-y0);

		let x0 = CLICKS[idx-4]:f32;
		let y0 = CLICKS[idx-3]:f32;
		let x1 = CLICKS[idx-2]:f32;
		let y1 = CLICKS[idx-1]:f32;

		// Get vector direction of the last hypha line
		let vx0 = x1 - x0;
		let vy0 = y1 - y0;
		let norm0 = math::sqrtf64(
			math::powf64(vx0:f64, 2.0)
			+ math::powf64(vy0:f64, 2.0)):f32;
		let vxn0 = vx0/norm0;
		let vyn0 = vy0/norm0;
		let offsetx0 = -vy0/norm0; // 90 deg rotation
		let offsety0 = vx0/norm0;
		// projected length:
		fungi_width = math::absf32(vxw0 * offsetx0 + vyw0 * offsety0);
		if (fungi_width > 0.05) fungi_width=0.05;

		// Draw offset lines for each segment
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

				let offsetx = -vy/norm*dir; // 90 deg rotation matrix
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

				draw_line(disp, HEIGHT, WIDTH, x0, y0, x1, y1,
					255, 0, 0);
			};
		};
		} else { // Draw active hyphal strand segments
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
				draw_line(disp, HEIGHT, WIDTH, x0, y0, x1, y1,
					0, 255, 255);
			};
		}; // DRAW ACTIVE STRAND

		// Draw previous strands
		for (let s = 0z; s < (strand); s += 1) {
			let idx = lengths[s];
			let CLICKS = allstrands[s*STRANDSIZE..s*STRANDSIZE+idx];
			for (let click = 3z; click < idx; click += 2) {
				// draw last point
				let x0 = CLICKS[click-3]:f32;
				let y0 = CLICKS[click-2]:f32;
				let x1 = CLICKS[click-1]:f32;
				let y1 = CLICKS[click-0]:f32;
				draw_line(disp, HEIGHT, WIDTH, x0, y0, x1, y1,
					255, 121, 0);
			}; // draw line
		}; // DRAW PREVIOUS STRANDS
		}; // NOT SKIP

		vacui::draw(pixels_disp[..(WIDTH * HEIGHT * 4)])!;
		time::sleep(15 * time::MILLISECOND);
		vacui::checkevents(); // run callbacks

		if (!vacui::ok()) {
			return;
		};
		if (NEXT_IMAGE) {
			image_idx += DIRECTION;
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
	if ((key==vacui::KEY_RIGHT || key==vacui::KEY_SPACE) && act == vacui::PRESS) {
		fmt::printfln("NEXT")!;
		DIRECTION = 1;
		NEXT_IMAGE = true;
	};

	if (key==vacui::KEY_LEFT && act == vacui::PRESS) {
		fmt::printfln("PREV")!;
		DIRECTION = -1;
		NEXT_IMAGE = true;
	};

	// complete strand from enter
	if (key==vacui::KEY_S && act == vacui::PRESS && (mods&vacui::MOD_CONTROL == 0)) {
		SKIP = !SKIP;
	};
};
