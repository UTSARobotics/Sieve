# SMART: Soil Microscopy Augmented Reporting Tool
SMART is the smart way to log data and generate soil microscopy reports.

## Features
- Load images and display from a sample
- Label fungi
- Save data file of annotations
- Skip repeat (multiple focal plane) images
- Display progress
- Load parameters from file (magnification, dilution, fov, droplet size)
- Generate csv, html reports from folder.

## Future Features
- Label protozoa, nematodes, bacteria, microarthropods, rotifer  
- Zoom
- Image enhancement (softHDR, sharpen, etc.)
- Video import
- USB microscope camera support, biovid driver, motic driver
- Graphics Reports (PDF, R, openstreetmap, opentopography)
- Geographic information
- Mobile app for data collection, labeling, reports, etc.
- database upload
- GPU rendering
- Hardware accelerated ai labeling
- Bounding box counts
- Bacteria click to count
- Worldwide soil microscopy database

## Technical TODO
- [ ] makefile for project (build dep. static libraries, link hare program)
- [ ] hare tocktick, cross-platform tocktick program counter
- [ ] hare image opening
- [ ] hare glfw/vulkan (link to c graphics framebuffer lib)
- [ ] hex array header gen for the fragment/vertex spirv (write hare program for this)
- [ ] display image
- [ ] draw squares on framebuffer
- [ ] draw text on framebuffer
- [ ] draw lines on framebuffer image
- [ ] draw lines when keypress, parallel line expand on keypress
- [ ] navigation
- [ ] save line data files as wxf
- [ ] AVX on x86, neon on arm
- [ ] hare warren (ravenring)
- [ ] breed metacompiler for windows C gen from hare.

## Dependencies
This program vendors dependencies, or includes a copy of the dependency used in building. This is done for reliability and stability reasons, and partially for performance. It also discourages the proliferation of complex dependencies.

This is how you add dependencies (clean/stash all changes first):
```
# First add the remote
git remote add -f <remote_name> <repository_url>

# Then add the subtree (squashed into single commit)
git subtree add --prefix=<destination_directory> <remote_name> <branch/tag> --squash
```

This is how you update dependencies that you have added (clean/stash all changes first):
```
git subtree pull --prefix=<destination_directory> <remote_name> <branch/tag> --squash
```

some initial dependencies:
- libheif
	- libde265
	- x265
	- libjpeg
	- libpng
	- libtiff
- glfw 3.3
- vulkan1 1.3.204.1-2 amd64 (tested, use sys. Or Moltenvk.) - framebuffer

future dependencies under consideration:
- gstreamer-1 agpl (ipc)
- platform-specific camera libraries
- metal - apple graphics
- OpenGL ES - embedded graphics
- OpenGL - old graphics
- R for reports / pdf

## Infrastructure (more dependencies)
This program depends on Hare and QBE. The following versions work:
```
scdoc: 29306d8dde650f5ac2bcc067f3c1d3bcfcac7a1d
qbe: 327736b3a6e77b201fffebd3cc207662e823d3a5
harec: 0b339b3102bd3a9fd9f874296900de6da9b21e70
hare: b420d9ab896528e8fecffd79659e9791e6ad2727
```

This project also uses clang, clang++, llvm-bolt:
```
$ clang-15 --version
Ubuntu clang version 15.0.7
Target: x86_64-pc-linux-gnu
Thread model: posix
```

Consider using the following flags:
- compilation of a c program
```
clang -c -std=c11 -Wall -Wextra -Wpedantic -Werror \
-fsanitize=address,undefined \
-fno-omit-frame-pointer \ # easier debugging
-fstack-protector-all -D_FORTIFY_SOURCE=2 \
-fvisibility=hidden -fvisibility-inlines-hidden \
-Os \ # or -Oz for tiny
-ffunction-sections -fdata-sections -Wl,--gc-sections,--icf=safe \
-flto
```
- compilation of library `-DCMAKE_C_COMPILER=clang-15 -DCMAKE_CXX_COMPILER=clang++-15`
```
-Wall -Wextra -Wpedantic -Werror \
-fstack-protector-all -D_FORTIFY_SOURCE=2 \
-ffunction-sections -fdata-sections \
-fvisibility=hidden -fvisibility-inlines-hidden \
-Os # or -Oz for tiny
```
- assembler
```
clang -c --integrated-as \
    -ffunction-sections -fdata-sections \
    file.s -o file.o
```
- linker
```
ld.lld --icf=safe --gc-sections --print-gc-sections *.o -o executable
```

And GLSL compiler for spirv generation:
```
$ glslangValidator --version
Glslang Version: 10:11.8.0
ESSL Version: OpenGL ES GLSL 3.20 glslang Khronos. 11.8.0
GLSL Version: 4.60 glslang Khronos. 11.8.0
SPIR-V Version 0x00010600, Revision 1
GLSL.std.450 Version 100, Revision 1
Khronos Tool ID 8
SPIR-V Generator Version 10
GL_KHR_vulkan_glsl version 100
ARB_GL_gl_spirv version 100
```

## Tools
- `valgrind --leak-check=full ./my_program` - help find memory leaks
- Intel VTune - get detailed performance metrics for your program
- `scan-build make` - clang 
- `clang-format` - format your C source code to follow a standard style
- `perf record ./my_program` and `perf report` - get performance metrics on Linux
- `bolt` - LLVM-project binary optimizer (only for Linux right now). Used with perf2bolt to convert recorded perf data to bolt format, then llvm-bolt to optimize the executable
	- `sudo perf record -F 99 ./vulkan_test`
	- `llvm-bolt-15 -data perf.data vulkan_test -o vulkan_test_o2`
- upx - compress executables, or just zip it have a script that unzips to tmp to execute.
- `strip`
