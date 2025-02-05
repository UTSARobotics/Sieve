CC=clang-15
CXX=clang++-15
LIBCXXFLAGS=-fstack-protector-all -D_FORTIFY_SOURCE=2 -ffunction-sections -fdata-sections -fvisibility-inlines-hidden -Oz
LIBCFLAGS=-fstack-protector-all -D_FORTIFY_SOURCE=2 -ffunction-sections -fdata-sections -fvisibility-inlines-hidden -Os
VENDOR=$(shell realpath vendor)
dependencies: build/libheif.a

build/libheif.a: build/libtiff.a build/libpng.a build/libjpeg.a build/libde265.a build/libx265.a
	mkdir -p build
	mkdir -p vendor/libheif/dbuild
	cd vendor/libheif/dbuild && cmake .. -DBUILD_SHARED_LIBS=OFF -DCMAKE_C_COMPILER=$(CC) -DCMAKE_CXX_COMPILER=$(CXX) -DCMAKE_LINKER=lld \
	-DCMAKE_CXX_FLAGS="-I$(VENDOR)/libjpeg/src -I$(VENDOR)/libx265/dbuild -I$(VENDOR)/libde265/dbuild -I$(VENDOR)/libtiff/dbuild/libtiff ${LIBCXXFLAGS}" \
	-DCMAKE_C_FLAGS="-I$(VENDOR)/libjpeg/src -I$(VENDOR)/libx265/dbuild -I$(VENDOR)/libde265/dbuild -I$(VENDOR)/libtiff/dbuild/libtiff  $(LIBCFLAGS)" \
	-DX265_INCLUDE_DIR="$(VENDOR)/libx265/source" \
	-DX265_LIBRARY=$(VENDOR)/libx265/dbuild/libx265.a \
	-DLIBDE265_INCLUDE_DIR="$(VENDOR)/libde265" \
	-DLIBDE265_LIBRARY=$(VENDOR)/libde265/dbuild/libde265/libde265.a \
	-DWITH_JPEG_DECODER=ON \
	-DWITH_JPEG_ENCODER=ON \
	-DHAVE_JPEG_WRITE_ICC_PROFILE=On \
	-DJPEG_INCLUDE_DIR=$(VENDOR)/libjpeg/dbuild/ \
	-DJPEG_LIBRARY=$(VENDOR)/libjpeg/dbuild/libjpeg.a \
	-DPNG_PNG_INCLUDE_DIR=$(VENDOR)/libpng/dbuild/ \
	-DPNG_LIBRARY=$(VENDOR)/libpng/dbuild/libpng.a
# 		-DTIFF_ROOT=$(VENDOR)/libtiff/dbuild \
# 	-DTIFF_INCLUDE_DIR=$(VENDOR)/libtiff/libtiff \
# 	-DTIFF_LIBRARY=$(VENDOR)/libtiff/dbuild/libtiff/libtiff.a
	make -C vendor/libheif/dbuild -j$(shell nproc)


build/libde265.a: vendor/libde265/
	mkdir -p build
	mkdir -p vendor/libde265/dbuild
	cd vendor/libde265/dbuild && cmake .. -DBUILD_SHARED_LIBS=OFF -DCMAKE_C_COMPILER=$(CC) -DCMAKE_CXX_COMPILER=$(CXX)  -DCMAKE_LINKER=lld \
		-DENABLE_SDL=OFF \
		-DCMAKE_CXX_FLAGS="$(LIBCXXFLAGS)" \
		-DCMAKE_C_FLAGS="$(LIBCFLAGS)"
	make -C vendor/libde265/dbuild -j2
	cp vendor/libde265/dbuild/libde265/libde265.a build

build/libx265.a: vendor/libx265/
	mkdir -p build
	mkdir -p vendor/libx265/dbuild
	cd vendor/libx265/dbuild && cmake ../source -DENABLE_SHARED=OFF -DCMAKE_C_COMPILER=$(CC) -DCMAKE_CXX_COMPILER=$(CXX)  -DCMAKE_LINKER=lld \
		-DCMAKE_CXX_FLAGS="$(LIBCXXFLAGS)" \
		-DCMAKE_C_FLAGS="$(LIBCFLAGS)"
	make -C vendor/libx265/dbuild -j2
	cp vendor/libx265/dbuild/libx265.a build

build/libjpeg.a: vendor/libjpeg/
	mkdir -p build
	mkdir -p vendor/libjpeg/dbuild
	cd vendor/libjpeg/dbuild && cmake .. -DBUILD_SHARED_LIBS=OFF -DCMAKE_C_COMPILER=$(CC) -DCMAKE_CXX_COMPILER=$(CXX)  -DCMAKE_LINKER=lld \
		-DCMAKE_CXX_FLAGS="$(LIBCXXFLAGS)" \
		-DCMAKE_C_FLAGS="$(LIBCFLAGS)"
	make -C vendor/libjpeg/dbuild -j2
	cp vendor/libjpeg/dbuild/libjpeg.a build

build/libpng.a: vendor/libpng/
	mkdir -p build
	mkdir -p vendor/libpng/dbuild
	cd vendor/libpng/dbuild && cmake .. -DBUILD_SHARED_LIBS=OFF -DCMAKE_C_COMPILER=$(CC) -DCMAKE_CXX_COMPILER=$(CXX) -DCMAKE_LINKER=lld \
		-DCMAKE_CXX_FLAGS="$(LIBCXXFLAGS)" \
		-DCMAKE_C_FLAGS="$(LIBCFLAGS)"
	make -C vendor/libpng/dbuild -j2
	cp vendor/libpng/dbuild/libpng.a build

build/libtiff.a: vendor/libtiff/
	mkdir -p build
	mkdir -p vendor/libtiff/dbuild
	cd vendor/libtiff/dbuild && cmake .. -DBUILD_SHARED_LIBS=OFF -DCMAKE_C_COMPILER=$(CC) -DCMAKE_CXX_COMPILER=$(CXX) -DCMAKE_LINKER=lld \
		-DCMAKE_CXX_FLAGS="$(LIBCXXFLAGS)" \
		-DCMAKE_C_FLAGS="$(LIBCFLAGS)"
	make -C vendor/libtiff/dbuild -j2
	cp vendor/libtiff/dbuild/libtiff/libtiff.a build

clean: 
	rm -rf build
	rm -rf vendor/*/dbuild

.PHONY: clean dependencies