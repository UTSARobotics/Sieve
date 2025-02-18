use time;

// Get the current processor counter value
export fn count() u64;

// Calculate the elapsed nanoseconds since the start count
export fn ns(start: u64) i64 = {
	let stop = count();
	return nsdt(stop, start);
};

// Calculate the nanoseconds delta between the stop and the start count
export fn nsdt(stop:u64, start: u64) i64 = {
	static let NS_PER_COUNT:f32 = -2.0;
	if (NS_PER_COUNT < 0f32) {
		NS_PER_COUNT = calibrate();
	};
	return ((stop-start):f32 * NS_PER_COUNT) : i64;
};

fn calibrate() f32 = {
	const counter_start = count();
	const start = time::now(time::clock::MONOTONIC);
	time::sleep(65536);
	let counter_stop = count();
	let now = time::now(time::clock::MONOTONIC);
	let delta_ns: i64 = time::diff(start, now);
	for(delta_ns < 65536) {
		counter_stop = count();
		now = time::now(time::clock::MONOTONIC);
		delta_ns = time::diff(start, now);
	};
	return (delta_ns:f64 / (counter_stop-counter_start):f64):f32;
};
