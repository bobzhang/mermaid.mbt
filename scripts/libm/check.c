// How internal/libm was checked against macOS's libm (arm64).
//
//   cc -O2 -ffp-contract=off -o check check.c transcription.c -lm
//   ./check 1 1000000000     # every float, and 10^9 pairs for atan2f
//
// transcription.c is the library's assembly written out in C, with the
// processor's own fused multiply-add; internal/libm is the same code in
// MoonBit. cases.c and fma_cases.c print the test vectors of
// internal/libm/*_wbtest.mbt from the library and the processor.
#include <math.h>
#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include <stdlib.h>
float my_sinf(float), my_cosf(float), my_tanf(float), my_atan2f(float, float);
void my_sincosf(float, float *, float *);
static inline uint32_t fb(float x) { uint32_t u; memcpy(&u, &x, 4); return u; }
static inline float ff(uint32_t u) { float x; memcpy(&x, &u, 4); return x; }
int main(int argc, char **argv) {
  uint64_t bs = 0, bc = 0, bt = 0, bss = 0, bsc = 0, n = 0;
  uint32_t step = argc > 1 ? (uint32_t)atoi(argv[1]) : 1;
  // every float (both signs) below 2^31 in magnitude, plus all larger exponents by stride
  for (uint64_t u = 0; u < 0x7f800000ull; u += step) {
    for (int sgn = 0; sgn < 2; sgn++) {
      volatile float x = ff((uint32_t)u | ((uint32_t)sgn << 31));
      n++;
      if (fb(my_sinf(x)) != fb(sinf(x))) { if (bs++ < 3) printf("sinf %a: %a vs %a\n", x, my_sinf(x), sinf(x)); }
      if (fb(my_cosf(x)) != fb(cosf(x))) { if (bc++ < 3) printf("cosf %a: %a vs %a\n", x, my_cosf(x), cosf(x)); }
      if (fb(my_tanf(x)) != fb(tanf(x))) { if (bt++ < 3) printf("tanf %a: %a vs %a\n", x, my_tanf(x), tanf(x)); }
      float s, c; my_sincosf(x, &s, &c);
      struct __float2 r = __sincosf_stret(x);
      if (fb(s) != fb(r.__sinval)) { if (bss++ < 3) printf("stret sin %a: %a vs %a\n", x, s, r.__sinval); }
      if (fb(c) != fb(r.__cosval)) { if (bsc++ < 3) printf("stret cos %a: %a vs %a\n", x, c, r.__cosval); }
    }
  }
  printf("n=%llu sinf %llu cosf %llu tanf %llu stret.sin %llu stret.cos %llu\n", n, bs, bc, bt, bss, bsc);
  // atan2f: random pairs over many magnitudes plus special values
  uint64_t ba = 0, na = 0;
  srand48(4);
  float specials[] = {0.0f, -0.0f, 1.0f, -1.0f, 2.0f, -2.0f, 0.5f, -0.5f, 1e-30f, -1e-30f, 1e30f, -1e30f, INFINITY, -INFINITY, 3.5f, -3.5f, 1e-45f, -1e-45f};
  int ns = sizeof(specials) / sizeof(float);
  for (int i = 0; i < ns; i++) for (int j = 0; j < ns; j++) {
    volatile float y = specials[i], x = specials[j]; na++;
    if (fb(my_atan2f(y, x)) != fb(atan2f(y, x))) { if (ba++ < 8) printf("atan2f(%a,%a): %a vs %a\n", y, x, my_atan2f(y, x), atan2f(y, x)); }
  }
  long count = argc > 2 ? atol(argv[2]) : 200000000;
  for (long i = 0; i < count; i++) {
    volatile float y, x;
    int mode = i & 3;
    if (mode == 0) { y = (float)(drand48() * 4 - 2); x = (float)(drand48() * 4 - 2); }
    else if (mode == 1) { y = ff((uint32_t)mrand48()); x = ff((uint32_t)mrand48()); }
    else if (mode == 2) { x = (float)(drand48() * 2000 - 1000); y = x * (float)(drand48() * 2e-6 - 1e-6); }
    else { y = (float)(drand48() * 2000 - 1000); x = y * (float)(1.0 + drand48() * 2e-6 - 1e-6) * ((i & 4) ? 1 : -1); }
    na++;
    uint32_t a = fb(my_atan2f(y, x)), b = fb(atan2f(y, x));
    if (a != b && !(y != y || x != x)) { if (ba++ < 8) printf("atan2f(%a,%a): %a vs %a\n", y, x, my_atan2f(y, x), atan2f(y, x)); }
  }
  printf("atan2f n=%llu bad %llu\n", na, ba);
  return 0;
}
