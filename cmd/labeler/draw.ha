use math;

fn draw_line(image:*[*]u8, image_height:size, image_width:size,
		x0:f32, y0:f32, x1:f32, y1:f32,
		r:u8=0, g:u8=255, b:u8=255) void = {
	// Compute maximum line distance
	let distx = math::absf32((x1-x0)*image_width:f32):i32;
	let disty = math::absf32((y1-y0)*image_height:f32):i32;
	let x_larger = if (distx < disty) -1i32 else 0i32;
	let dist:i32 = (distx & ~x_larger) | (disty & (x_larger));

	// Compute step size
	let xf = x0;
	let yf = y0;
	let dx = (x1-x0) / dist:f32;
	let dy = (y1-y0) / dist:f32;

	for(let i=0i32; i < dist; i += 1) {
		let x = (xf * image_width:f32):i32;
		if (x > image_width:i32) x = image_width:i32;
		if (x < 0i32) x = 0;
		let y = image_height:i32 - (yf * image_height:f32):i32;
		if (y > image_height:i32) y = image_height:i32;
		if (y < 0i32) y = 0;
		let dst_idx = ((y * image_width:i32 + x) << 2):size;
		image[dst_idx + 0] = r;
		image[dst_idx + 1] = g;
		image[dst_idx + 2] = b;
		image[dst_idx + 3] = 255;
		xf += dx;
		yf += dy;
	};
};
