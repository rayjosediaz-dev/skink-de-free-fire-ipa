#include "PantherCompression.h"
#include "LzmaDec.h"
#include <stdlib.h>
#include <string.h>

static void *allocate(ISzAllocPtr allocator, size_t size) {
    (void)allocator;
    return malloc(size);
}

static void release(ISzAllocPtr allocator, void *pointer) {
    (void)allocator;
    free(pointer);
}

int panther_lzma(const uint8_t *source, size_t sourceSize, uint8_t *output, size_t outputSize) {
    if (sourceSize < LZMA_PROPS_SIZE) return 0;
    const ISzAlloc allocator = {allocate, release};
    SizeT consumed = sourceSize - LZMA_PROPS_SIZE;
    SizeT written = outputSize;
    ELzmaStatus status;
    const SRes result = LzmaDecode(output, &written, source + LZMA_PROPS_SIZE,
        &consumed, source, LZMA_PROPS_SIZE, LZMA_FINISH_ANY, &status, &allocator);
    return result == SZ_OK && written == outputSize;
}

static int extend_length(const uint8_t **input, const uint8_t *end, size_t *length) {
    uint8_t byte;
    do {
        if (*input == end || *length > SIZE_MAX - 255) return 0;
        byte = *(*input)++;
        *length += byte;
    } while (byte == 255);
    return 1;
}

int panther_lz4(const uint8_t *input, size_t inputSize, uint8_t *output, size_t outputSize) {
    const uint8_t *end = input + inputSize;
    size_t written = 0;
    while (input < end) {
        uint8_t token = *input++;
        size_t literals = token >> 4;
        if (literals == 15 && !extend_length(&input, end, &literals)) return 0;
        if (literals > (size_t)(end - input) || literals > outputSize - written) return 0;
        memcpy(output + written, input, literals);
        input += literals;
        written += literals;
        if (input == end) return written == outputSize;
        if (end - input < 2) return 0;
        size_t distance = (size_t)input[0] | ((size_t)input[1] << 8);
        input += 2;
        if (distance == 0 || distance > written) return 0;
        size_t match = token & 15;
        if (match == 15 && !extend_length(&input, end, &match)) return 0;
        match += 4;
        if (match > outputSize - written) return 0;
        for (size_t i = 0; i < match; i++, written++) {
            output[written] = output[written - distance];
        }
    }
    return written == outputSize;
}
