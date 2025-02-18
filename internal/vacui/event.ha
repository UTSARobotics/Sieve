// Mouse button event
// `button` is vacui::MOUSE_BUTTON_(LEFT | RIGHT | MIDDLE | 3 | 4 | 5 | 6 | 7)
// `action` is vacui::(PRESS | RELEASE | REPEAT)
// `mods` is vacui::MOD_(SHIFT | CONTROL | ALT | SUPER | CAPS_LOCK | NUM_LOCK)
export type mousebutton = struct {
	button: int,
	action: int,
	mods: int
};

// Mouse move event.
// x and y are fraction of window width and height respectively
export type mousemove = struct {
	x: f32,
	y: f32
};

// Keypress event.
// `key` is one of vacui::KEY_....
// `action` is vacui::(PRESS | RELEASE | REPEAT)
// `mods` is vacui::MOD_(SHIFT | CONTROL | ALT | SUPER | CAPS_LOCK | NUM_LOCK)
// `scancode` is platform-specific but consistent
export type keypress = struct {
	key: int,
	action: int,
	mods: int,
	scancode: int
};

// Scroll event. x is usually -1 or +1. y is 0 for most mice.
export type scroll = struct {
	x: f32,
	y: f32
};

// No event. Nothing happened.
export type noevent = void;

export type uievent = (mousebutton | mousemove | keypress | scroll | noevent);

// Action
export def RELEASE:int = 0;
export def PRESS:int = 1;
export def REPEAT:int = 2;

// Mouse buttons
export def MOUSE_BUTTON_1:int = 0;
export def MOUSE_BUTTON_2:int = 1;
export def MOUSE_BUTTON_3:int = 2;
export def MOUSE_BUTTON_4:int = 3;
export def MOUSE_BUTTON_5:int = 4;
export def MOUSE_BUTTON_6:int = 5;
export def MOUSE_BUTTON_7:int = 6;
export def MOUSE_BUTTON_8:int = 7;
export def MOUSE_BUTTON_LEFT:int = MOUSE_BUTTON_1;
export def MOUSE_BUTTON_RIGHT:int = MOUSE_BUTTON_2;
export def MOUSE_BUTTON_MIDDLE:int = MOUSE_BUTTON_3;
export def MOUSE_BUTTON_LAST:int = MOUSE_BUTTON_8;

// Modifier Keys
export def MOD_SHIFT:int = 0x0001;
export def MOD_CONTROL:int = 0x0002;
export def MOD_ALT:int = 0x0004;
export def MOD_SUPER:int = 0x0008;
export def MOD_CAPS_LOCK:int = 0x0010;
export def MOD_NUM_LOCK:int = 0x0020;

// Printable keys */
export def KEY_SPACE:int = 32;
export def KEY_APOSTROPHE:int = 39;  // ' */
export def KEY_COMMA:int = 44;  // , */
export def KEY_MINUS:int = 45;  // - */
export def KEY_PERIOD:int = 46;  // . */
export def KEY_SLASH:int = 47;  // / */
export def KEY_0:int = 48;
export def KEY_1:int = 49;
export def KEY_2:int = 50;
export def KEY_3:int = 51;
export def KEY_4:int = 52;
export def KEY_5:int = 53;
export def KEY_6:int = 54;
export def KEY_7:int = 55;
export def KEY_8:int = 56;
export def KEY_9:int = 57;
export def KEY_SEMICOLON:int = 59;  // ; */
export def KEY_EQUAL:int = 61;  // = */
export def KEY_A:int = 65;
export def KEY_B:int = 66;
export def KEY_C:int = 67;
export def KEY_D:int = 68;
export def KEY_E:int = 69;
export def KEY_F:int = 70;
export def KEY_G:int = 71;
export def KEY_H:int = 72;
export def KEY_I:int = 73;
export def KEY_J:int = 74;
export def KEY_K:int = 75;
export def KEY_L:int = 76;
export def KEY_M:int = 77;
export def KEY_N:int = 78;
export def KEY_O:int = 79;
export def KEY_P:int = 80;
export def KEY_Q:int = 81;
export def KEY_R:int = 82;
export def KEY_S:int = 83;
export def KEY_T:int = 84;
export def KEY_U:int = 85;
export def KEY_V:int = 86;
export def KEY_W:int = 87;
export def KEY_X:int = 88;
export def KEY_Y:int = 89;
export def KEY_Z:int = 90;
export def KEY_LEFT_BRACKET:int = 91;  // [
export def KEY_BACKSLASH:int = 92;  // \
export def KEY_RIGHT_BRACKET:int = 93;  // ]
export def KEY_GRAVE_ACCENT:int = 96;  // `
export def KEY_WORLD_1:int = 161; // non-US #1
export def KEY_WORLD_2:int = 162; // non-US #2

// Function keys
export def KEY_ESCAPE:int = 256;
export def KEY_ENTER:int = 257;
export def KEY_TAB:int = 258;
export def KEY_BACKSPACE:int = 259;
export def KEY_INSERT:int = 260;
export def KEY_DELETE:int = 261;
export def KEY_RIGHT:int = 262;
export def KEY_LEFT:int = 263;
export def KEY_DOWN:int = 264;
export def KEY_UP:int = 265;
export def KEY_PAGE_UP:int = 266;
export def KEY_PAGE_DOWN:int = 267;
export def KEY_HOME:int = 268;
export def KEY_END:int = 269;
export def KEY_CAPS_LOCK:int = 280;
export def KEY_SCROLL_LOCK:int = 281;
export def KEY_NUM_LOCK:int = 282;
export def KEY_PRINT_SCREEN:int = 283;
export def KEY_PAUSE:int = 284;
export def KEY_F1:int = 290;
export def KEY_F2:int = 291;
export def KEY_F3:int = 292;
export def KEY_F4:int = 293;
export def KEY_F5:int = 294;
export def KEY_F6:int = 295;
export def KEY_F7:int = 296;
export def KEY_F8:int = 297;
export def KEY_F9:int = 298;
export def KEY_F10:int = 299;
export def KEY_F11:int = 300;
export def KEY_F12:int = 301;
export def KEY_F13:int = 302;
export def KEY_F14:int = 303;
export def KEY_F15:int = 304;
export def KEY_F16:int = 305;
export def KEY_F17:int = 306;
export def KEY_F18:int = 307;
export def KEY_F19:int = 308;
export def KEY_F20:int = 309;
export def KEY_F21:int = 310;
export def KEY_F22:int = 311;
export def KEY_F23:int = 312;
export def KEY_F24:int = 313;
export def KEY_F25:int = 314;
export def KEY_KP_0:int = 320;
export def KEY_KP_1:int = 321;
export def KEY_KP_2:int = 322;
export def KEY_KP_3:int = 323;
export def KEY_KP_4:int = 324;
export def KEY_KP_5:int = 325;
export def KEY_KP_6:int = 326;
export def KEY_KP_7:int = 327;
export def KEY_KP_8:int = 328;
export def KEY_KP_9:int = 329;
export def KEY_KP_DECIMAL:int = 330;
export def KEY_KP_DIVIDE:int = 331;
export def KEY_KP_MULTIPLY:int = 332;
export def KEY_KP_SUBTRACT:int = 333;
export def KEY_KP_ADD:int = 334;
export def KEY_KP_ENTER:int = 335;
export def KEY_KP_EQUAL:int = 336;
export def KEY_LEFT_SHIFT:int = 340;
export def KEY_LEFT_CONTROL:int = 341;
export def KEY_LEFT_ALT:int = 342;
export def KEY_LEFT_SUPER:int = 343;
export def KEY_RIGHT_SHIFT:int = 344;
export def KEY_RIGHT_CONTROL:int = 345;
export def KEY_RIGHT_ALT:int = 346;
export def KEY_RIGHT_SUPER:int = 347;
export def KEY_MENU:int = 348;
