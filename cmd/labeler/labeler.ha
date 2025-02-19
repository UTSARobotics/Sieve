use fmt;
use hac;
use vacui;
use time;
use os;
use io;
use fs;
use math;

let WIDTH:size=0;
let HEIGHT:size=0;
let WINWIDTH:size = 0;
let WINHEIGHT:size = 0;
let X:f32=0.0;
let Y:f32=0.0;
def STRANDSIZE = 128z;
let CLICKS:[STRANDSIZE]f32= [0.0...];
let idx:size=0;

// STORE multiple strands of fungi
let allstrands: [256*STRANDSIZE]f32 = [0.0...];
let lengths: [256]size = [0...]; // num points
let widths: [256]f32 = [0.0...];
let strand:size = 0;

let WIDTHSELECT:bool = false;

@symbol("stbi_load_from_memory") fn stbi_load_from_memory(
	buffer: *u8,
	length: int,
	x: *int,
	y: *int,
	channels: *int,
	desired_channels: int,
) nullable *u8;

@symbol("stbi_image_free") fn stbi_image_free(pixels: nullable *u8) void;

export fn main() void = {
	if (len(os::args) != 2) {
		fmt::fatalf("Usage: {} <image_file>", os::args[0]);
	};

	// 1. Open and read the file into memory
	const file = match (os::open(os::args[1])) {
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
	fmt::printfln("buffer len: {}", len(filebuf))!;
	defer free(filebuf);

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
		fmt::fatal("Failed to load image");
	};
	defer stbi_image_free(pixels);


	let start = hac::count();
	let pixels_disp:[]u8 = alloc([0u8...], 4096 * 4096 * 4)!;
	let alloctime = hac::count();
	let UI = vacui::init("labeler", 640, 480, 4096)!;
        // vacui::init("labeler", 640, 480, 2048)!;

	glfwSetCursorPosCallback(UI.gles_window:*opaque, &mouse_callback);
	glfwSetMouseButtonCallback(UI.gles_window:*opaque, &click_callback);
	glfwSetKeyCallback(UI.gles_window:*opaque, &key_callback);

	for(vacui::ok()) {
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
		};

		// draw active strand
		for (let click = 3z; click < (idx+2); click += 2) {
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
				xf += dx;
				yf += dy;
				if (x == lastx && y == lasty) {
					// Avoid repeat pixels
					// todo (Alec, 2024): benchmark this to see if worth.
					continue;
				};
				let dst_idx = ((y * WIDTH:i32 + x) << 2):size;
				disp[dst_idx + 0] = 0;
				disp[dst_idx + 1] = 255;
				disp[dst_idx + 2] = 255;
				disp[dst_idx + 3] = 255;
				lastx = x;
				lasty = y;
			};
		};

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
				xf += dx;
				yf += dy;
				if (x == lastx && y == lasty) {
					// Avoid repeat pixels
					// todo (Alec, 2024): benchmark this to see if worth.
					continue;
				};
				let dst_idx = ((y * WIDTH:i32 + x) << 2):size;
				disp[dst_idx + 0] = 255;
				disp[dst_idx + 1] = 121;
				disp[dst_idx + 2] = 0;
				disp[dst_idx + 3] = 255;
				lastx = x;
				lasty = y;
			};
		};
		};

		vacui::draw(pixels_disp[..(WIDTH * HEIGHT * 4)])!;
		time::sleep(15 * time::MILLISECOND);
		vacui::checkevents(); // run callbacks
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
		if (idx > 2 &&
		math::absf32(X-CLICKS[idx-2]) < 0.01 &&
		math::absf32(Y-CLICKS[idx-1]) < 0.01) {
			if(idx < 4) {
				return; // not enough points to add strand
			};
			if (strand >= 256) {
				return; // too many strands added
			};
			allstrands[strand*STRANDSIZE..strand*STRANDSIZE+idx]
				= CLICKS[..idx];
			lengths[strand] = idx;
			strand += 1;
			idx = 0;
			fmt::printfln("DOUBLE-CLICK Strands {}", strand)!;
			return;
		} else { // add mew click to current strand
			fmt::printfln("CLICK Selected {},{}", X, Y)!;
			CLICKS[idx] = X;
			CLICKS[idx + 1] = Y;
			idx += 2;
		};

		// for(let i=0z;i < idx; i+=2){
		// 	fmt::printfln("Clicked {},{}", CLICKS[i], CLICKS[1+1])!;
		// };
	};
};


fn key_callback(win:*opaque, key:int, scan:int, act:int, mods:int) void = {
	if (key==vacui::KEY_BACKSPACE &&
			(act == vacui::PRESS || act == vacui::REPEAT) &&
			idx >= 2) {
		idx -= 2;
		fmt::printfln("BACKSPACE, IDX {}", idx)!;
		return;
	};
	if (key==vacui::KEY_ESCAPE &&
			(act == vacui::PRESS || act == vacui::REPEAT)) {
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
		if(idx < 4) {
			return; // not enough points to add strand
		};
		if (strand >= 256) {
			return; // too many strands added
		};
		allstrands[strand*STRANDSIZE..strand*STRANDSIZE+idx]
			= CLICKS[..idx];
		lengths[strand] = idx;
		strand += 1;
		idx = 0;
		fmt::printfln("ENTER complete Strands {}", strand)!;
	};
};
