use fmt;
use hac;

export fn main() void = {
	let start = hac::count();
	fmt::printfln("labeler")!;
	fmt::printfln("... took {} ns", hac::ns(start))!;
};
