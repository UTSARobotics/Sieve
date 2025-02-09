CC=clang-15
CXX=clang++-15
LIBCXXFLAGS=-fstack-protector-all -D_FORTIFY_SOURCE=2 -ffunction-sections -fdata-sections -fvisibility-inlines-hidden -Os
LIBCFLAGS=-fstack-protector-all -D_FORTIFY_SOURCE=2 -ffunction-sections -fdata-sections -fvisibility-inlines-hidden -Os
CMAKEOPTS=-DCMAKE_BUILD_TYPE=MinSizeRel -DBUILD_SHARED_LIBS=OFF -DBUILD_TESTING=OFF -DCMAKE_C_COMPILER=$(CC) -DCMAKE_CXX_COMPILER=$(CXX) -DCMAKE_LINKER=lld
VENDOR=$(shell realpath vendor)

dependencies: build/libheif.a build/libglfw3.a build/libwuffs.a

build/libheif.a: build/libjpeg.a build/libde265.a build/libx265.a
	mkdir -p build
	mkdir -p vendor/libheif/tmpbuild
	cd vendor/libheif/tmpbuild && cmake .. $(CMAKEOPTS) \
	-DCMAKE_CXX_FLAGS="-I$(VENDOR)/libjpeg/tmpbuild -I$(VENDOR)/libx265/tmpbuild -I$(VENDOR)/libde265/tmpbuild ${LIBCXXFLAGS}" \
	-DWITH_JPEG_ENCODER=ON \
	-DWITH_JPEG_DECODER=ON \
	-DHAVE_JPEG_WRITE_ICC_PROFILE=On \
	-DLIBDE265_INCLUDE_DIR="$(VENDOR)/libde265" \
	-DLIBDE265_LIBRARY=$(VENDOR)/libde265/tmpbuild/libde265/libde265.a \
	-DX265_INCLUDE_DIR="$(VENDOR)/libx265/source" \
	-DX265_LIBRARY=$(VENDOR)/libx265/tmpbuild/libx265.a \
	-DJPEG_INCLUDE_DIR=$(VENDOR)/libjpeg/src/ \
	-DJPEG_LIBRARY=$(VENDOR)/libjpeg/tmpbuild/libjpeg.a
	make -C vendor/libheif/tmpbuild -j$$(( $$(nproc) * 2 ))
	cp vendor/libheif/tmpbuild/libheif/libheif.a build

build/libde265.a: vendor/libde265/
	mkdir -p build
	mkdir -p vendor/libde265/tmpbuild
	cd vendor/libde265/tmpbuild && cmake .. $(CMAKEOPTS) \
		-DENABLE_SDL=OFF \
		-DCMAKE_CXX_FLAGS="$(LIBCXXFLAGS)" \
		-DCMAKE_C_FLAGS="$(LIBCFLAGS)"
	make -C vendor/libde265/tmpbuild -j$$(nproc)
	cp vendor/libde265/tmpbuild/libde265/libde265.a build

build/libx265.a: vendor/libx265/
	mkdir -p build
	mkdir -p vendor/libx265/tmpbuild
	cd vendor/libx265/tmpbuild && cmake ../source $(CMAKEOPTS) \
		-DENABLE_SHARED=OFF \
		-DCMAKE_CXX_FLAGS="$(LIBCXXFLAGS)" \
		-DCMAKE_C_FLAGS="$(LIBCFLAGS)"
	make -C vendor/libx265/tmpbuild -j$$(nproc)
	cp vendor/libx265/tmpbuild/libx265.a build

build/libjpeg.a: vendor/libjpeg/
	mkdir -p build
	mkdir -p vendor/libjpeg/tmpbuild
	cd vendor/libjpeg/tmpbuild && cmake .. $(CMAKEOPTS) \
		-DCMAKE_CXX_FLAGS="$(LIBCXXFLAGS)" \
		-DCMAKE_C_FLAGS="$(LIBCFLAGS)"
	make -C vendor/libjpeg/tmpbuild -j$$(( $$(nproc) * 2 ))
	cp vendor/libjpeg/tmpbuild/libjpeg.a build

build/libglfw3.a: vendor/glfw/
	mkdir -p build
	mkdir -p vendor/glfw/tmpbuild
	cd vendor/glfw/tmpbuild && cmake .. $(CMAKEOPTS) \
		-DCMAKE_CXX_FLAGS="$(LIBCXXFLAGS)" \
		-DCMAKE_C_FLAGS="$(LIBCFLAGS)" \
		-DGLFW_BUILD_EXAMPLES=False -DGLFW_BUILD_TESTS=False -DGLFW_BUILD_DOCS=False
	make -C vendor/glfw/tmpbuild -j$$(nproc)
	cp vendor/glfw/tmpbuild/src/libglfw3.a build

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