CC=clang-15
CXX=clang++-15
LIBCFLAGS=-fstack-protector-all -D_FORTIFY_SOURCE=2 -ffunction-sections -fdata-sections -fvisibility-inlines-hidden -O2 -msse4.2 -mavx
CMAKEOPTS=-DCMAKE_BUILD_TYPE=MinSizeRel -DBUILD_SHARED_LIBS=OFF -DBUILD_TESTING=OFF \
	-DCMAKE_C_COMPILER=$(CC) -DCMAKE_CXX_COMPILER=$(CXX) -DCMAKE_LINKER=lld \
	-DCMAKE_C_FLAGS="$(LIBCFLAGS)" -DCMAKE_CXX_FLAGS="$(LIBCFLAGS)" \
	-DCMAKE_C_FLAGS_MINSIZEREL="$(LIBCFLAGS)" -DCMAKE_CXX_FLAGS_MINSIZEREL="$(LIBCFLAGS)"
VENDOR=$(shell realpath vendor)
BUILD=$(shell realpath build)

dependencies: build/libheif.a build/libglfw3.a build/libwuffs.a

build/libheif.a: build/libjpeg.a build/libde265.a build/libx265.a \
		build/libopenjp2.a build/libopenjph.a
	mkdir -p build
	mkdir -p vendor/libheif/tmpbuild
	cd vendor/libheif/tmpbuild && cmake .. $(CMAKEOPTS) \
	-DCMAKE_CXX_FLAGS="-I $(VENDOR)/openjph/tmpbuild/install/include" \
	-DENABLE_PLUGIN_LOADING=OFF \
	-DWITH_JPEG_ENCODER=ON \
	-DWITH_JPEG_DECODER=ON \
	-DWITH_OpenJPEG_ENCODER=ON \
	-DWITH_OpenJPEG_DECODER=ON \
	-DWITH_OPENJPH_ENCODER=ON \
	-DWITH_OPENJPH_DECODER=ON \
	-DHAVE_JPEG_WRITE_ICC_PROFILE=On \
	-DLIBDE265_INCLUDE_DIR="$(VENDOR)/libde265/tmpbuild/install/include" \
	-DLIBDE265_LIBRARY=$(BUILD)/libde265.a \
	-DX265_INCLUDE_DIR="$(VENDOR)/libx265/tmpbuild/install/include" \
	-DX265_LIBRARY=$(BUILD)/libx265.a \
	-DJPEG_INCLUDE_DIR=$(VENDOR)/libjpeg/tmpbuild/install/include \
	-DJPEG_LIBRARY=$(BUILD)/libjpeg.a \
	-DOpenJPEG_INCLUDE_DIR=$(VENDOR)/openjpeg/tmpbuild/install/include \
	-DOpenJPEG_LIBRARY=$(BUILD)/libopenjp2.a \
	-DOpenJPEG_DIR=$(VENDOR)/openjpeg/tmpbuild/install/lib/cmake/openjpeg-2.5/ \
	-DOPENJPH_INCLUDE_DIR==$(VENDOR)/openjph/tmpbuild/install/include \
	-DOPENJPH_LIBRARY=$(BUILD)/libopenjph.a \
	-DOPENJPH_DIR=$(VENDOR)/openjph/tmpbuild
	make -C vendor/libheif/tmpbuild -j$$(( $$(nproc) * 2 ))
	cp vendor/libheif/tmpbuild/libheif/libheif.a build

build/libde265.a: vendor/libde265/
	mkdir -p build
	mkdir -p vendor/libde265/tmpbuild/install
	cd vendor/libde265/tmpbuild && cmake .. $(CMAKEOPTS) \
		-DENABLE_SDL=OFF \
		-DCMAKE_INSTALL_PREFIX=$(VENDOR)/libde265/tmpbuild/install
	make -C vendor/libde265/tmpbuild -j$$(nproc) install
	cp vendor/libde265/tmpbuild/install/lib/libde265.a build

build/libx265.a: vendor/libx265/
	mkdir -p build
	mkdir -p vendor/libx265/tmpbuild/install
	cd vendor/libx265/tmpbuild && cmake ../source $(CMAKEOPTS) \
		-DENABLE_SHARED=OFF \
		-DCMAKE_INSTALL_PREFIX=$(VENDOR)/libx265/tmpbuild/install
	make -C vendor/libx265/tmpbuild -j$$(nproc) install
	cp vendor/libx265/tmpbuild/install/lib/libx265.a build

build/libjpeg.a: vendor/libjpeg/
	mkdir -p build
	mkdir -p vendor/libjpeg/tmpbuild/install
	cd vendor/libjpeg/tmpbuild && cmake .. $(CMAKEOPTS) \
		-DCMAKE_INSTALL_PREFIX=$(VENDOR)/libjpeg/tmpbuild/install
	make -C vendor/libjpeg/tmpbuild -j$$(( $$(nproc) * 2 )) install
	cp vendor/libjpeg/tmpbuild/install/lib/libjpeg.a build

build/libglfw3.a: vendor/glfw/
	mkdir -p build
	mkdir -p vendor/glfw/tmpbuild/install
	cd vendor/glfw/tmpbuild && cmake .. $(CMAKEOPTS) \
		-DGLFW_BUILD_EXAMPLES=False -DGLFW_BUILD_TESTS=False -DGLFW_BUILD_DOCS=False \
		-DCMAKE_INSTALL_PREFIX=$(VENDOR)/glfw/tmpbuild/install
	make -C vendor/glfw/tmpbuild -j$$(nproc) install
	cp vendor/glfw/tmpbuild/install/lib/libglfw3.a build

build/libopenjp2.a: vendor/openjpeg/
	mkdir -p build
	mkdir -p vendor/openjpeg/tmpbuild/install
	cd vendor/openjpeg/tmpbuild && cmake .. $(CMAKEOPTS) \
		-DCMAKE_INSTALL_PREFIX=$(VENDOR)/openjpeg/tmpbuild/install
	make -C vendor/openjpeg/tmpbuild -j$$(nproc) install
	cp vendor/openjpeg/tmpbuild/install/lib/libopenjp2.a build

build/libopenjph.a: vendor/openjph/
	mkdir -p build
	mkdir -p vendor/openjph/tmpbuild/install
	cd vendor/openjph/tmpbuild && cmake .. $(CMAKEOPTS) \
		-DCMAKE_INSTALL_PREFIX=$(VENDOR)/openjph/tmpbuild/install
	make -C vendor/openjph/tmpbuild -j$$(nproc) install
	cp vendor/openjph/tmpbuild/install/lib/libopenjph.a build


build/libwuffs.a: vendor/wuffs/release/c/wuffs-v0.4.c
	mkdir -p build
	$(CC) $(LIBCFLAGS) -c -o build/wuffs.o $^ -DWUFFS_IMPLEMENTATION \
	-DWUFFS_CONFIG__MODULES \
	-DWUFFS_CONFIG__MODULES \
	-DWUFFS_CONFIG__MODULE__BASE \
	-DWUFFS_CONFIG__MODULE__JPEG \
	-DWUFFS_CONFIG__MODULE__ADLER32 \
	-DWUFFS_CONFIG__MODULE__BMP \
	-DWUFFS_CONFIG__MODULE__CRC32 \
	-DWUFFS_CONFIG__MODULE__DEFLATE \
	-DWUFFS_CONFIG__MODULE__ETC2 \
	-DWUFFS_CONFIG__MODULE__GIF \
	-DWUFFS_CONFIG__MODULE__NETPBM \
	-DWUFFS_CONFIG__MODULE__NIE \
	-DWUFFS_CONFIG__MODULE__PNG \
	-DWUFFS_CONFIG__MODULE__QOI \
	-DWUFFS_CONFIG__MODULE__TARGA \
	-DWUFFS_CONFIG__MODULE__THUMBHASH \
	-DWUFFS_CONFIG__MODULE__VP8 \
	-DWUFFS_CONFIG__MODULE__WBMP \
	-DWUFFS_CONFIG__MODULE__WEBP \
	-DWUFFS_CONFIG__MODULE__ZLIB \
	-DWUFFS_CONFIG__DST_PIXEL_FORMAT__ENABLE_ALLOWLIST \
	-DWUFFS_CONFIG__DST_PIXEL_FORMAT__ALLOW_Y \
	-DWUFFS_CONFIG__DST_PIXEL_FORMAT__ALLOW_RGB \
	-DWUFFS_CONFIG__DST_PIXEL_FORMAT__ALLOW_RGBA_NONPREMUL \
	-DWUFFS_CONFIG__ENABLE_DROP_IN_REPLACEMENT__STB \
	-DSTBI_NO_STDIO
	ar rcs build/libwuffs.a build/wuffs.o

clean: 
	rm -rf build
	rm -rf vendor/*/tmpbuild

.PHONY: clean dependencies