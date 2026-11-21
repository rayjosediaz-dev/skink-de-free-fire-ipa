#include <stddef.h>
#include <stdint.h>

int panther_lzma(const uint8_t *source, size_t sourceSize, uint8_t *output, size_t outputSize);
int panther_lz4(const uint8_t *source, size_t sourceSize, uint8_t *output, size_t outputSize);
