// gcc -o jpeginfo jpeginfo.c -L ../../build -ljpeg -I ../../vendor/libjpeg/src
#include <stdio.h>
#include "jpeglib.h"

int main() {
	printf("JPEG_LIB_VERSION: %d\n", JPEG_LIB_VERSION);
	printf("decompress struct size: %d\n", (int)sizeof(struct jpeg_decompress_struct));
}
