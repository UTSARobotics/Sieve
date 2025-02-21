# SMART: Soil Microscopy Augmented Reporting Tool
SMART is the smart way to log data and generate soil microscopy reports.

## install

```
sudo apt install git build-essential lld clang llvm nasm libxcursor-dev libxinerama-dev libxrandr-dev libxi-dev libgles-mesa-dev
```

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
- [x] makefile for project (build dep. static libraries, link hare program)
- [x] hare tocktick, cross-platform tocktick program counter
- [x] hare image opening
- [x] vacui opengl (for macos/desktop linux/wsl2)
- [x] vacui opengles
- [ ] Test different image compression
- [ ] hare glfw/vulkan (link to c graphics framebuffer lib)
- [ ] hex array header gen for the fragment/vertex spirv (write hare program for this)
- [x] display image
- [ ] draw squares on framebuffer
- [ ] draw text on framebuffer
- [x] draw lines on framebuffer image
- [x] draw lines when keypress, parallel line expand on keypress
- [~] navigation
- [x] save line data files as wxf
- [ ] AVX on x86, neon on arm
- [ ] hare warren (ravenring) ipc and launch (spawn?) system, C, Python, R bindings
- [ ] breed metacompiler for windows C gen from hare.

Note:
- This repository has amassed considerable bloat. Consider removing everything but wuffs and libheif with j2k-ht support. (".j2ki", apparently). If it's good enough for the NSA... Write a benchmark program that tests the compression and file size of each format if you really want to be sure.

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


## Build settings
`-Oz`:

    2.3M libde265.a  472K libglfw3.a  6.4M libheif.a  804K libjpeg.a  664K libopenjp2.a  860K libopenjph.a  576K libwuffs.a  2.2M libx265.a  556K wuffs.o

`-Os` in cmake:

    1.8M libde265.a  436K libglfw3.a  4.3M libheif.a  820K libjpeg.a  568K libopenjp2.a  664K libopenjph.a  576K libwuffs.a  2.2M libx265.a  556K wuffs.o

`-O2 -mavx -msse4.2`:

    2.0M libde265.a   496K libglfw3.a   4.4M libheif.a  1016K libjpeg.a   756K libopenjp2.a   880K libopenjph.a   652K libwuffs.a   2.7M libx265.a   632K wuffs.o

`-Os -mavx -msse4.2`:

    1.9M libde265.a  472K libglfw3.a  4.3M libheif.a  828K libjpeg.a  676K libopenjp2.a  844K libopenjph.a  568K libwuffs.a  2.2M libx265.a  548K wuffs.o
