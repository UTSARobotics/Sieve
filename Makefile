CC=clang-15
CXX=clang++-15
LIBCXXFLAGS=-fstack-protector-all -D_FORTIFY_SOURCE=2 -ffunction-sections -fdata-sections -fvisibility-inlines-hidden -Os
LIBCFLAGS=-fstack-protector-all -D_FORTIFY_SOURCE=2 -ffunction-sections -fdata-sections -fvisibility-inlines-hidden -Os
CMAKEOPTS=-DCMAKE_BUILD_TYPE=MinSizeRel -DBUILD_SHARED_LIBS=OFF -DCMAKE_C_COMPILER=$(CC) -DCMAKE_CXX_COMPILER=$(CXX) -DCMAKE_LINKER=lld
VENDOR=$(shell realpath vendor)
dependencies: build/libheif.a

build/libheif.a: build/libpng.a build/libjpeg.a build/libde265.a build/libx265.a
	mkdir -p build
	mkdir -p vendor/libheif/build
	cd vendor/libheif/build && cmake .. $(CMAKEOPTS) \
	-DCMAKE_CXX_FLAGS="-I$(VENDOR)/libjpeg/build -I$(VENDOR)/libx265/mybuild -I$(VENDOR)/libde265/build ${LIBCXXFLAGS}" \
	-DCMAKE_C_FLAGS="-I$(VENDOR)/libjpeg/build -I$(VENDOR)/libx265/mybuild -I$(VENDOR)/libde265/build ${LIBCFLAGS}" \
	-DWITH_JPEG_DECODER=ON \
	-DWITH_JPEG_ENCODER=ON \
	-DLIBDE265_INCLUDE_DIR="$(VENDOR)/libde265" \
	-DLIBDE265_LIBRARY=$(VENDOR)/libde265/build/libde265/libde265.a \
	-DX265_INCLUDE_DIR="$(VENDOR)/libx265/source" \
	-DX265_LIBRARY=$(VENDOR)/libx265/mybuild/libx265.a \
	-DHAVE_JPEG_WRITE_ICC_PROFILE=On \
	-DJPEG_INCLUDE_DIR=$(VENDOR)/libjpeg/src/ \
	-DJPEG_LIBRARY=$(VENDOR)/libjpeg/build/libjpeg.a \
	-DPNG_PNG_INCLUDE_DIR=$(VENDOR)/libpng/build/ \
	-DPNG_LIBRARY=$(VENDOR)/libpng/build/libpng.a
	make -C vendor/libheif/build -j$(shell nproc)
	cp vendor/libheif/build/libheif/libheif.a build

build/libde265.a: vendor/libde265/
	mkdir -p build
	mkdir -p vendor/libde265/build
	cd vendor/libde265/build && cmake .. $(CMAKEOPTS) \
		-DENABLE_SDL=OFF \
		-DCMAKE_CXX_FLAGS="$(LIBCXXFLAGS)" \
		-DCMAKE_C_FLAGS="$(LIBCFLAGS)"
	make -C vendor/libde265/build -j2
	cp vendor/libde265/build/libde265/libde265.a build

build/libx265.a: vendor/libx265/
	mkdir -p build
	mkdir -p vendor/libx265/mybuild
	cd vendor/libx265/mybuild && cmake ../source $(CMAKEOPTS) \
		-DENABLE_SHARED=OFF \
		-DCMAKE_CXX_FLAGS="$(LIBCXXFLAGS)" \
		-DCMAKE_C_FLAGS="$(LIBCFLAGS)"
	make -C vendor/libx265/build -j2
	cp vendor/libx265/mybuild/libx265.a build

build/libjpeg.a: vendor/libjpeg/
	mkdir -p build
	mkdir -p vendor/libjpeg/build
	cd vendor/libjpeg/build && cmake .. $(CMAKEOPTS) \
		-DCMAKE_CXX_FLAGS="$(LIBCXXFLAGS)" \
		-DCMAKE_C_FLAGS="$(LIBCFLAGS)"
	make -C vendor/libjpeg/build -j2
	cp vendor/libjpeg/build/libjpeg.a build

build/libpng.a: vendor/libpng/
	mkdir -p build
	mkdir -p vendor/libpng/build
	cd vendor/libpng/build && cmake .. $(CMAKEOPTS) \
		-DCMAKE_CXX_FLAGS="$(LIBCXXFLAGS)" \
		-DCMAKE_C_FLAGS="$(LIBCFLAGS)"
	make -C vendor/libpng/build -j2
	cp vendor/libpng/build/libpng.a build

build/libglfw3.a: vendor/glfw/
	mkdir -p build
	mkdir -p vendor/glfw/build
	cd vendor/glfw/build && cmake .. $(CMAKEOPTS) \
		-DCMAKE_CXX_FLAGS="$(LIBCXXFLAGS)" \
		-DCMAKE_C_FLAGS="$(LIBCFLAGS)" \
		-DGLFW_LIBRARY_TYPE=STATIC \
		-DGLFW_BUILD_EXAMPLES=False -DGLFW_BUILD_TESTS=False -DGLFW_BUILD_DOCS=False
	make -C vendor/glfw/build -j2
	cp vendor/glfw/build/src/libglfw3.a build

clean: 
	rm -rf build
	rm -rf vendor/*/build

.PHONY: clean dependencies