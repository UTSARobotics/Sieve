use fmt;
use hac;
use vacui;
use time;
use os;
use io;
use fs;

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
	let pixels_disp:[]u8 = alloc([255u8...], 2048 * 2048 * 4)!;
	let alloctime = hac::count();

	vacui::init("labeler", 640, 480, 640)!;

	for(vacui::ok()) {
		let (vw, vh) = vacui::readsize();
		fmt::printfln("size: ({}, {})", vw, vh)!;
		// Calculate scaling factors
		let scale_x = width:f32 / vw:f32;
		let scale_y = height:f32 / vh:f32;

		// Scale using two loops for x,y coordinates
		for (let y = 0z; y < vh; y += 1) {
		for (let x = 0z; x < vw; x += 1) {
			// Calculate source and destination pixel positions
			let src_x = (x:f32 * scale_x):size;
			let src_y = (y:f32 * scale_y):size;

			// Calculate array indices
			let dst_idx = ((vh-y) * vw + x) * 4;
			let src_idx = (src_y * width:size + src_x) * 4;

			// Copy RGBA values
			let src = pixels: *[*]u8;
			(pixels_disp: *[*]u8)[dst_idx + 0] = src[src_idx + 0];
			(pixels_disp: *[*]u8)[dst_idx + 1] = src[src_idx + 1];
			(pixels_disp: *[*]u8)[dst_idx + 2] = src[src_idx + 2];
			(pixels_disp: *[*]u8)[dst_idx + 3] = src[src_idx + 3];
		};
		};
		vacui::draw(pixels_disp[..(vw * vh * 4)])!;
		// time::sleep(100 * time::MILLISECOND);
		vacui::checkevents();
	};

	fmt::printfln("labeler")!;
	fmt::printfln("... took {} ns", hac::ns(start))!;
};
