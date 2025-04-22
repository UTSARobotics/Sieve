use os;
use io;
use fmt;
use fs;

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

// WUFFS / stbi functions
@symbol("stbi_load_from_memory") fn stbi_load_from_memory(
	buffer: *u8,
	length: int,
	x: *int,
	y: *int,
	channels: *int,
	desired_channels: int,
) nullable *u8;

@symbol("stbi_image_free") fn stbi_image_free(pixels: nullable *u8) void;
