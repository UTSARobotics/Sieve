use fmt;
use hac;
use rt;

export fn main() void = {
	let start = hac::count();
	fmt::printfln("hello")!;
	fmt::printfln("... took {} ns", hac::ns(start))!;
};
