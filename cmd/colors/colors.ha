use fmt;
use hac;
use vacui;
use time;
use math::random;

export fn main() void = {
	let start = hac::count();
	// let pixels:*[2048*2048*4]u8 = alloc([255u8...])!;
	let pixels:[]u8 = alloc([255u8...], 2048 * 2048 * 4)!;
	let alloctime = hac::count();

	vacui::init("colors", 640, 480, 2048)!;

	let r = random::init(1234567);
	for(vacui::ok()) {
		let (width, height) = vacui::readsize();
		for (let i = 0z; i < width * height * 4; i += 4) {
			let r = random::next(&r);
			pixels[i + 0] = (r & 255): u8;
			pixels[i + 1] = ((r * r) & 255): u8;
			pixels[i + 2] = ((r + 17) & 255): u8;
			pixels[i + 3] = 255;
		};

		fmt::printfln("size: ({}, {})", width, height)!;
		vacui::draw(pixels[..(width * height * 4)])!;
		time::sleep(1000 * time::MICROSECOND);
		vacui::checkevents();
	};

	fmt::printfln("hello")!;
	fmt::printfln("... took {} ns", hac::ns(start))!;
};
