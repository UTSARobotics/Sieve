use fmt;
use hac;
use vacui;
use time;
use math::random;

export fn main() void = {
	let start = hac::count();
	// let pixels:*[2048*2048*4]u8 = alloc([255u8...])!;
	let pixels:[]u8 = alloc([128u8...], 2048 * 2048 * 4)!;

	let alloctime = hac::count();
	vacui::init("labeler", 640, 480, 2048)!;
	assert(vacui::glGetError()==0);


	let r = random::init(1234567);
	for(vacui::ok()) {
		assert(vacui::glGetError()==0);
		let (width, height) = vacui::readsize();
		for (let i = 0z; i < len(pixels); i += 4) {
		    pixels[i + 0] = 255u8; // R
		    pixels[i + 1] = 0u8;   // G
		    pixels[i + 2] = 0u8;   // B
		    pixels[i + 3] = 255u8; // A
		};
		// for (let i = 0z; i < width * height * 4; i += 4) {
		// 	let r = random::next(&r);
		// 	pixels[i + 0] = (r & 255): u8;
		// 	pixels[i + 1] = ((r * r) & 255): u8;
		// 	pixels[i + 2] = ((r + 17) & 255): u8;
		// 	pixels[i + 3] = 255;
		// };

		fmt::printfln("size: ({}, {})", width, height)!;
		vacui::draw(pixels[..(width * height * 4)])!;
		time::sleep(1000 * time::MICROSECOND);
		vacui::checkevents();
	};

	fmt::printfln("labeler")!;
	fmt::printfln("... took {} ns", hac::ns(start))!;
};
