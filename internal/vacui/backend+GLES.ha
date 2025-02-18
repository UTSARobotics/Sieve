fn init_glfw_backend() void = {
	glfwWindowHint(GLFW_CLIENT_API, GLFW_OPENGL_ES_API);
	glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 2);
	glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 0);
};

def VERTEX_SHADER:str = "
attribute vec2 position;
attribute vec2 tex_coord;
varying vec2 v_tex_coord;
void main() {
  gl_Position = vec4(position, 0.0, 1.0);
  v_tex_coord = tex_coord;
};
\0";

def FRAGMENT_SHADER:str = "
precision mediump float;
varying vec2 v_tex_coord;
uniform sampler2D u_texture;
void main() {
  gl_FragColor = texture2D(u_texture, v_tex_coord);
}
\0";
