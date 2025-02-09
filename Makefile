CC=clang-15
CXX=clang++-15
LIBCXXFLAGS=-fstack-protector-all -D_FORTIFY_SOURCE=2 -ffunction-sections -fdata-sections -fvisibility-inlines-hidden -Os
LIBCFLAGS=-fstack-protector-all -D_FORTIFY_SOURCE=2 -ffunction-sections -fdata-sections -fvisibility-inlines-hidden -Os
CMAKEOPTS=-DCMAKE_BUILD_TYPE=MinSizeRel -DBUILD_SHARED_LIBS=OFF -DBUILD_TESTING=OFF -DCMAKE_C_COMPILER=$(CC) -DCMAKE_CXX_COMPILER=$(CXX) -DCMAKE_LINKER=lld
VENDOR=$(shell realpath vendor)

dependencies: build/libheif.a build/libglfw3.a

build/libheif.a: build/libjpeg.a build/libde265.a build/libx265.a
	mkdir -p build
	mkdir -p vendor/libheif/tmpbuild
# 	-DCMAKE_C_FLAGS="-I$(VENDOR)/libjpeg/tmpbuild -I$(VENDOR)/libx265/tmpbuild -I$(VENDOR)/libde265/tmpbuild ${LIBCFLAGS}"
	cd vendor/libheif/tmpbuild && cmake .. $(CMAKEOPTS) \
	-DCMAKE_CXX_FLAGS="-I$(VENDOR)/libjpeg/tmpbuild -I$(VENDOR)/libx265/tmpbuild -I$(VENDOR)/libde265/tmpbuild ${LIBCXXFLAGS}" \
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

clean: 
	rm -rf build
	rm -rf vendor/*/tmpbuild

.PHONY: clean dependencies