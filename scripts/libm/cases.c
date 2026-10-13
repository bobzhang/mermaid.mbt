// Print test vectors from the system libm as MoonBit arrays of bit patterns.
#include <math.h>
#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include <stdlib.h>
static uint32_t fb(float x) { uint32_t u; memcpy(&u, &x, 4); return u; }
static float ff(uint32_t u) { float x; memcpy(&x, &u, 4); return x; }
static float pick(long i) {
  static const uint32_t edges[] = {0, 0x80000000, 1, 0x00800000, 0x397fffff, 0x39800000, 0x39800001, 0x3f490fda, 0x3f490fdb, 0x3f490fdc,
    0x3fc90fdb, 0x40490fdb, 0xc0490fdb, 0x40c90fdb, 0x42efffff, 0x42f00000, 0x42f00001, 0x4c7fffff, 0x4c800000, 0x4c800001,
    0x3f800000, 0xbf800000, 0x7f7fffff, 0xff7fffff, 0x5d5e0b6b, 0x7149f2ca, 0x3fc90fda, 0x3fc90fdc, 0x40490fda, 0x4096cbe4};
  int ne = sizeof(edges) / 4;
  if (i < ne) return ff(edges[i]);
  switch (i % 5) {
    case 0: return (float)(drand48() * 14 - 7);
    case 1: return (float)(drand48() * 2 - 1) * 0.8f;
    case 2: return (float)(drand48() * 400 - 200);
    case 3: { uint32_t u = (uint32_t)mrand48(); if ((u & 0x7f800000) == 0x7f800000) u &= 0xbfffffff; return ff(u); }
    default: return (float)(drand48() * 0.002 - 0.001);
  }
}
int main(int argc, char **argv) {
  long n = atol(argv[1]);
  srand48(20261014);
  printf("///|\nlet unary_cases : Array[(UInt, UInt, UInt, UInt, UInt)] = [\n");
  for (long i = 0; i < n; i++) {
    volatile float x = pick(i);
    struct __float2 r = __sincosf_stret(x);
    printf("  (0x%08x, 0x%08x, 0x%08x, 0x%08x, 0x%08x),\n", fb(x), fb(r.__sinval), fb(r.__cosval), fb(cosf(x)), fb(tanf(x)));
  }
  printf("]\n\n///|\nlet atan2_cases : Array[(UInt, UInt, UInt)] = [\n");
  float sp[] = {0.0f, -0.0f, 1.0f, -1.0f, 0.5f, -0.5f, 3.0f, -3.0f, 1e-30f, -1e-30f, 1e30f, -1e30f, 2.3841858e-07f, -2.3841858e-07f};
  int ns = sizeof(sp) / 4;
  long count = 0;
  for (int i = 0; i < ns && count < n; i++) for (int j = 0; j < ns && count < n; j++, count++) {
    volatile float y = sp[i], x = sp[j];
    printf("  (0x%08x, 0x%08x, 0x%08x),\n", fb(y), fb(x), fb(atan2f(y, x)));
  }
  for (long i = count; i < n; i++) {
    volatile float y, x;
    switch (i % 4) {
      case 0: y = (float)(drand48() * 4 - 2); x = (float)(drand48() * 4 - 2); break;
      case 1: { uint32_t a = (uint32_t)mrand48(), b = (uint32_t)mrand48(); if ((a & 0x7f800000) == 0x7f800000) a &= 0xbfffffff; if ((b & 0x7f800000) == 0x7f800000) b &= 0xbfffffff; y = ff(a); x = ff(b); break; }
      case 2: x = (float)(drand48() * 2000 - 1000); y = x * (float)(drand48() * 2e-6 - 1e-6); break;
      default: y = (float)(drand48() * 2000 - 1000); x = y * (float)(1.0 + drand48() * 2e-6 - 1e-6) * ((i & 4) ? 1 : -1); break;
    }
    printf("  (0x%08x, 0x%08x, 0x%08x),\n", fb(y), fb(x), fb(atan2f(y, x)));
  }
  printf("]\n");
  return 0;
}
