#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include "patches.h"

int32_t detectFirmware(int32_t data_len);
int32_t patch_firmare(int32_t select_len);
uint8_t* getInFilePtr(void);
uint8_t* getOutFilePtr(void);
uint32_t* getSelectPtr(void);
char* getJsonPtr(void);
int32_t getMaxFileSize(void);

static long read_bytes(const char* path, uint8_t* dst, long max) {
    FILE* f = fopen(path, "rb");
    if (!f) return -1;
    long n = (long)fread(dst, 1, (size_t)max, f);
    fclose(f);
    return n;
}

int main(int argc, char** argv) {
    if (argc < 3) {
        fprintf(stderr, "usage:\n  nfpatch list  <firmware.bin>\n  nfpatch apply <firmware.bin> <out.bin> <patch_id> [patch_id...]\n");
        return 2;
    }
    const char* mode = argv[1];
    const char* inpath = argv[2];

    uint8_t* in = getInFilePtr();
    long len = read_bytes(inpath, in, getMaxFileSize());
    if (len <= 0) { fprintf(stderr, "cannot read %s\n", inpath); return 1; }

    int32_t n = detectFirmware((int32_t)len);
    if (n <= 0) { fprintf(stderr, "unknown firmware (md5 not in patch database)\n"); return 1; }

    if (strcmp(mode, "list") == 0) {
        printf("%s\n", getJsonPtr());
        return 0;
    }

    if (strcmp(mode, "apply") == 0) {
        if (argc < 5) { fprintf(stderr, "apply needs at least one patch id\n"); return 2; }
        const char* outpath = argv[3];
        uint32_t* sel = getSelectPtr();
        int cnt = 0;
        for (int i = 4; i < argc; i++) sel[cnt++] = (uint32_t)atoi(argv[i]);
        int32_t res = patch_firmare(cnt);
        if (res <= 0) { fprintf(stderr, "patch failed (patch ids invalid or source bytes mismatch)\n"); return 1; }
        FILE* f = fopen(outpath, "wb");
        if (!f) { fprintf(stderr, "cannot write %s\n", outpath); return 1; }
        fwrite(getOutFilePtr(), 1, (size_t)res, f);
        fclose(f);
        printf("wrote %s (%d bytes)\n", outpath, res);
        return 0;
    }

    fprintf(stderr, "unknown mode %s\n", mode);
    return 2;
}
