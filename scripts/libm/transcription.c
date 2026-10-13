// Transcription of the arm64 assembly of sinf, cosf, __sincosf_stret, tanf and
// atan2f in macOS's libsystem_m, to check it bit for bit against the library.
#include <math.h>
#include <stdint.h>
#include <string.h>
// The constants, read from the library.
static const double SC[15] = {0x1.45f306dc9c883p-1, 0x1.921fb54442d18p+0, 0x1.1a62633145c07p-54, 0x1.99169fc938f4ap-16, -0x1.6c07f16945df4p-10, 0x1.55553c7899699p-5, -0x1.ffffffcb82e97p-2, -0x1.9943e0fc4818fp-13, 0x1.11073afd145ebp-7, -0x1.555545268a02ap-3, -0x1.0a8b9fc97b22cp+2, -0x1.d31f4a0a55230p+1, 0x1.ef88f0b1250c1p+3, 0x1.537b6744fa779p+1, 0x1.39502de83d49cp-4};
static const double SCT[128] = {0x1.45f306e000000p-2, -0x1.b1bbead603d8bp-33, 0x1.45f306e000000p-2, -0x1.b1bbead603d8bp-33, 0x1.45f306e000000p-2, -0x1.b1bbead603d8bp-33, 0x1.45f306e000000p-2, -0x1.b1bbead603d8bp-33, 0x1.45f306e000000p-2, -0x1.b1bbead603d8bp-33, 0x1.45f306e000000p-2, -0x1.b1bbead603d8bp-33, 0x1.45f306e000000p-2, -0x1.b1bbead603d8bp-33, 0x1.45f306e000000p-2, -0x1.b1bbead603d8bp-33, 0x1.45f306e000000p-2, -0x1.b1bbead603d8bp-33, 0x1.45f306e000000p-2, -0x1.b1bbead603d8bp-33, 0x1.45f306e000000p-2, -0x1.b1bbead603d8bp-33, 0x1.45f306e000000p-2, -0x1.b1bbead603d8bp-33, -0x1.7419f24000000p-3, -0x1.b1bbead603d8bp-33, -0x1.d067c92000000p-5, 0x1.391054a7f09d6p-35, 0x1.7cc1b72000000p-8, 0x1.c882a53f84eb0p-38, -0x1.067c91b000000p-9, -0x1.bbead603d8a83p-41, -0x1.9f246c7000000p-15, 0x1.054a7f09d5f48p-47, -0x1.9f246c7000000p-15, 0x1.054a7f09d5f48p-47, -0x1.9f246c7000000p-15, 0x1.054a7f09d5f48p-47, 0x1.836e4e4000000p-17, 0x1.054a7f09d5f48p-47, -0x1.f246c6f000000p-19, 0x1.529fc2757d1f5p-53, 0x1.b727221000000p-24, -0x1.5ac07b1505c16p-54, 0x1.b727221000000p-24, -0x1.5ac07b1505c16p-54, -0x1.236377d000000p-26, -0x1.6b01ec5417056p-56, 0x1.b939105000000p-27, 0x1.29fc2757d1f53p-57, -0x1.1b1bbeb000000p-29, 0x1.4fe13abe8fa9ap-60, -0x1.b1bbead000000p-33, -0x1.80f62a0b82b2dp-63, -0x1.b1bbead000000p-33, -0x1.80f62a0b82b2dp-63, 0x1.391054a000000p-35, 0x1.fc2757d1f534ep-65, 0x1.c882a54000000p-38, -0x1.ec54170565912p-72, -0x1.bbead60000000p-41, -0x1.ec54170565912p-72, -0x1.bbead60000000p-41, -0x1.ec54170565912p-72, 0x1.1054a7f000000p-43, 0x1.3abe8fa9a6ee0p-76, 0x1.054a7f1000000p-47, -0x1.8a82e0acb223fp-77, 0x1.054a7f1000000p-47, -0x1.8a82e0acb223fp-77, 0x1.529fc27000000p-53, 0x1.5f47d4d377037p-83, 0x1.529fc27000000p-53, 0x1.5f47d4d377037p-83, 0x1.529fc27000000p-53, 0x1.5f47d4d377037p-83, 0x1.4a7f09d000000p-55, 0x1.7d1f534ddc0dbp-85, 0x1.29fc275000000p-57, 0x1.f47d4d377036ep-87, 0x1.4fe13ac000000p-60, -0x1.70565911f924fp-92, -0x1.603d8a8000000p-61, -0x1.70565911f924fp-92, -0x1.80f62a1000000p-63, 0x1.1f534ddc0db63p-93, 0x1.fc2757d000000p-65, 0x1.f534ddc0db629p-97, -0x1.ec54170000000p-72, -0x1.596447e493ad5p-102, -0x1.ec54170000000p-72, -0x1.596447e493ad5p-102, -0x1.ec54170000000p-72, -0x1.596447e493ad5p-102, 0x1.3abe8fb000000p-76, -0x1.96447e493ad4dp-106, 0x1.3abe8fb000000p-76, -0x1.96447e493ad4dp-106, -0x1.8a82e0b000000p-77, 0x1.a6ee06db14acdp-108, 0x1.d5f47d5000000p-79, -0x1.6447e493ad4cep-110, -0x1.505c159000000p-82, -0x1.911f924eb5336p-112, 0x1.5f47d4d000000p-83, 0x1.bb81b6c52b328p-114, 0x1.7d1f535000000p-85, -0x1.11f924eb53362p-116, 0x1.f47d4d3000000p-87, 0x1.dc0db6295993cp-117, -0x1.7056591000000p-92, -0x1.f924eb53361dep-124, -0x1.7056591000000p-92, -0x1.f924eb53361dep-124, 0x1.1f534de000000p-93, -0x1.f924eb53361dep-124, 0x1.f534ddc000000p-97, 0x1.b6c52b3278872p-130, 0x1.f534ddc000000p-97, 0x1.b6c52b3278872p-130, -0x1.596447e000000p-102, -0x1.24eb53361de38p-132, -0x1.596447e000000p-102, -0x1.24eb53361de38p-132, 0x1.4d37703000000p-103, 0x1.b6295993c4390p-133, 0x1.34ddc0e000000p-105, -0x1.275a99b0ef1bfp-135};
static const double ST[10] = {-0x1.c3d3ee4f8713fp+3, -0x1.0bc0396540c13p+3, -0x1.ef09ab49e3a5bp+3, -0x1.d6f5ade6c8c37p+3, 0x1.4bc899499342cp-13, 0x1.d9c364e9721d5p-11, 0x1.44921a30f0d80p+5, 0x1.d78212789bc11p+2, 0x1.e97264e36bd93p+7, 0x1.2c6b9c7f88fa0p+7};
static const double TN[20] = {0x1.8000000000000p+52, -0x1.0000000000000p+0, 0x1.45f306e000000p-1, -0x1.b1bbead603d8bp-32, 0x1.fe5da804efbdcp-9, 0x1.1e9c887f6c8a1p-10, 0x1.487da95c9f173p-7, 0x1.61eb51f86747cp-6, 0x1.ba586a7f44ae7p-5, 0x1.1110746e09b07p-3, 0x1.555555d8d8930p-2, 0x0.0p+0, 0x1.51d4a014005d8p+2, 0x1.e91f74c2eeaabp+1, -0x1.609394a49adf1p-2, -0x1.88f856cde0b64p+0, 0x1.d3764811481d2p-1, 0x1.81ba4203c502dp-1, 0x1.db0d5be6b368bp-1, 0x1.2d17a5cc6b70bp-1};
static const double TNT[106] = {0x1.45f306e000000p-1, -0x1.b1bbead603d8bp-32, 0x1.17cc1b7000000p-3, 0x1.391054a7f09d6p-34, 0x1.7cc1b72000000p-7, 0x1.c882a53f84eb0p-37, 0x1.7cc1b72000000p-7, 0x1.c882a53f84eb0p-37, 0x1.f306dca000000p-9, -0x1.bbead603d8a83p-40, -0x1.9f246c7000000p-14, 0x1.054a7f09d5f48p-46, -0x1.9f246c7000000p-14, 0x1.054a7f09d5f48p-46, 0x1.836e4e4000000p-16, 0x1.054a7f09d5f48p-46, -0x1.f246c6f000000p-18, 0x1.529fc2757d1f5p-52, 0x1.b727221000000p-23, -0x1.5ac07b1505c16p-53, 0x1.b727221000000p-23, -0x1.5ac07b1505c16p-53, 0x1.b727221000000p-23, -0x1.5ac07b1505c16p-53, -0x1.236377d000000p-25, -0x1.6b01ec5417056p-55, -0x1.1b1bbeb000000p-28, 0x1.4fe13abe8fa9ap-59, 0x1.c9c882a000000p-29, 0x1.4fe13abe8fa9ap-59, -0x1.b1bbead000000p-32, -0x1.80f62a0b82b2dp-62, 0x1.391054a000000p-34, 0x1.fc2757d1f534ep-64, -0x1.8ddf56b000000p-35, -0x1.ec54170565912p-71, 0x1.c882a54000000p-37, -0x1.ec54170565912p-71, -0x1.bbead60000000p-40, -0x1.ec54170565912p-71, 0x1.1054a7f000000p-42, 0x1.3abe8fa9a6ee0p-75, -0x1.df56b02000000p-43, 0x1.3abe8fa9a6ee0p-75, 0x1.054a7f1000000p-46, -0x1.8a82e0acb223fp-76, -0x1.f56b01f000000p-47, 0x1.d5f47d4d37703p-78, 0x1.529fc27000000p-52, 0x1.5f47d4d377037p-82, 0x1.529fc27000000p-52, 0x1.5f47d4d377037p-82, -0x1.5ac07b1000000p-53, -0x1.4170565911f92p-83, -0x1.6b01ec5000000p-55, -0x1.05c1596447e49p-85, -0x1.ac07b15000000p-57, -0x1.70565911f924fp-91, 0x1.4fe13ac000000p-59, -0x1.70565911f924fp-91, 0x1.3f84eb0000000p-61, -0x1.70565911f924fp-91, 0x1.fc2757d000000p-64, 0x1.f534ddc0db629p-96, -0x1.ec54170000000p-71, -0x1.596447e493ad5p-101, -0x1.ec54170000000p-71, -0x1.596447e493ad5p-101, -0x1.ec54170000000p-71, -0x1.596447e493ad5p-101, -0x1.ec54170000000p-71, -0x1.596447e493ad5p-101, 0x1.3abe8fb000000p-75, -0x1.96447e493ad4dp-105, 0x1.3abe8fb000000p-75, -0x1.96447e493ad4dp-105, 0x1.d5f47d5000000p-78, -0x1.6447e493ad4cep-109, -0x1.505c159000000p-81, -0x1.911f924eb5336p-111, -0x1.505c159000000p-81, -0x1.911f924eb5336p-111, -0x1.4170566000000p-83, 0x1.bb81b6c52b328p-113, -0x1.05c1596000000p-85, -0x1.11f924eb53362p-115, -0x1.7056591000000p-91, -0x1.f924eb53361dep-123, -0x1.7056591000000p-91, -0x1.f924eb53361dep-123, -0x1.7056591000000p-91, -0x1.f924eb53361dep-123, -0x1.c159644000000p-93, -0x1.f924eb53361dep-123, 0x1.f534ddc000000p-96, 0x1.b6c52b3278872p-129, -0x1.596447e000000p-101, -0x1.24eb53361de38p-131, -0x1.596447e000000p-101, -0x1.24eb53361de38p-131, -0x1.596447e000000p-101, -0x1.24eb53361de38p-131, -0x1.65911f9000000p-103, -0x1.275a99b0ef1bfp-134, -0x1.96447e5000000p-105, 0x1.b14acc9e21c82p-135};
static const double AT[19] = {0x1.2609372076e2cp+1, -0x1.792d5bf17c0bcp+1, 0x1.38f4c070b63c1p+1, 0x1.5e43168d7c2b6p+2, 0x1.53db49b9fcf6bp-6, -0x1.3e370146726b3p+2, 0x1.e4fa479729042p+1, 0x1.ae0fb08f2dc00p+2, 0x1.80bc0fe23203dp-9, 0x1.0000000000000p-22, 0x1.921fb54442d18p+1, -0x1.921fb54442d18p+1, 0x1.921fb54442d18p+0, -0x1.921fb54442d18p+0, 0x1.921fb40080000p+1, 0x1.2d97c7f3321d2p+1, -0x1.2d97c7f3321d2p+1, 0x1.921fb54442d18p-1, -0x1.921fb54442d18p-1};
static inline uint32_t fbits(float x) { uint32_t u; memcpy(&u, &x, 4); return u; }
static inline uint64_t dbits(double x) { uint64_t u; memcpy(&u, &x, 8); return u; }
static inline double dfrom(uint64_t u) { double x; memcpy(&x, &u, 8); return x; }
// fmadd d,n,m,a = a + n*m ; fmsub = a - n*m
#define FMADD(n, m, a) fma((n), (m), (a))
#define FMSUB(n, m, a) fma(-(n), (m), (a))
static inline int64_t rne_i(double x) { return (int64_t)nearbyint(x); } // default rounding: to nearest even
static double sin_poly(double r) {
  double z = r * r, r3 = r * z;
  double a = FMADD(z, SC[7], SC[8]);
  double r5 = z * r3;
  double b = FMADD(r3, SC[9], r);
  return FMADD(r5, a, b);
}
static double cos_poly(double r) {
  double z = r * r;
  double a = FMADD(z, SC[3], SC[4]);
  double b = FMADD(z, SC[5], SC[6]);
  double z2 = z * z;
  a = FMADD(z2, a, b);
  return FMADD(z, a, 1.0);
}
// The common tail of sinf and cosf for medium arguments: n quarter turns, remainder r.
static float sincos_tail(int64_t n, double r) {
  uint64_t sign = ((uint64_t)n >> 1) << 63;
  double v = (n & 1) ? cos_poly(r) : sin_poly(r);
  return (float)dfrom(dbits(v) ^ sign);
}
// Large arguments: d4 = x*T0 (+0.5 for cosine), d5 = x*T1.
static float sincos_big(double d4, double d5) {
  int64_t n = rne_i(d4);
  double d1 = nearbyint(d4);
  uint64_t sign = (uint64_t)n << 63;
  d4 = d4 - d1;
  double d0 = d4 + d5;
  double d3 = dfrom(dbits(d0) ^ sign);
  d0 = d0 * d0;
  double a = d0 + SC[10], b = d0 + SC[11];
  double d6 = FMADD(d0, a, SC[12]);
  double d7 = FMADD(d0, b, SC[13]);
  d6 = d3 * d6;
  d7 = SC[14] * d7;
  return (float)(d6 * d7);
}
float my_sinf(float x) {
  uint32_t w = fbits(x) & 0x7fffffff;
  if (w >= 0x42f00000) {
    if (w >= 0x7f800000) return x - x;
    double d0 = (double)x;
    int i = (int)(w >> 24) - 0x40;
    return sincos_big(d0 * SCT[2 * i], d0 * SCT[2 * i + 1]);
  }
  if (w < 0x3f490fdb) {
    if (w < 0x39800000) return fmaf(x, 67108864.0f, x) * 1.4901161193847656e-08f;
    return (float)sin_poly((double)x);
  }
  double d0 = (double)x;
  double d2 = d0 * SC[0];
  int64_t n = rne_i(d2);
  d2 = nearbyint(d2);
  double r = FMSUB(d2, SC[1], d0);
  return sincos_tail(n, r);
}
float my_cosf(float x) {
  x = fabsf(x);
  uint32_t w = fbits(x);
  if (w >= 0x42f00000) {
    if (w >= 0x4c800000) {
      if (w >= 0x7f800000) return x - x;
      double d0 = (double)x;
      int i = (int)(w >> 24) - 0x40;
      return sincos_big(d0 * SCT[2 * i] + 0.5, d0 * SCT[2 * i + 1]);
    }
    double d0 = (double)x;
    double d2 = d0 * SC[0];
    int64_t n = rne_i(d2);
    d2 = nearbyint(d2);
    n += 1;
    double r = FMSUB(d2, SC[1], d0);
    r = FMSUB(d2, SC[2], r);
    return sincos_tail(n, r);
  }
  if (w < 0x3f490fdb) {
    if (w < 0x39800000) return (67108864.0f - x) * 1.4901161193847656e-08f;
    return (float)cos_poly((double)x);
  }
  double d0 = (double)x;
  double d2 = d0 * SC[0];
  int64_t n = rne_i(d2);
  d2 = nearbyint(d2);
  n += 1;
  double r = FMSUB(d2, SC[1], d0);
  return sincos_tail(n, r);
}
void my_sincosf(float x, float *s, float *c) {
  uint32_t w = fbits(x) & 0x7fffffff;
  int64_t n;
  double r;
  if (w >= 0x42f00000) {
    if (w >= 0x7f800000) { *s = x - x; *c = *s; return; }
    double d0 = (double)x;
    d0 = d0 + d0;
    int i = (int)(w >> 24) - 0x40;
    double d4 = d0 * SCT[2 * i], d5 = d0 * SCT[2 * i + 1];
    n = rne_i(d4);
    double d1 = nearbyint(d4);
    d4 = d4 - d1;
    r = d4 + d5;
  } else if (w < 0x39800000) {
    *c = (67108864.0f - fabsf(x)) * 1.4901161193847656e-08f;
    *s = fmaf(x, 67108864.0f, x) * 1.4901161193847656e-08f;
    return;
  } else {
    double d2 = (double)x * SC[0];
    n = rne_i(d2);
    r = d2 - nearbyint(d2);
  }
  double z = r * r;
  double v2a = z + ST[0], v2b = z + ST[1];
  double v3a = z + ST[2], v3b = z + ST[3];
  double v1a = r * ST[4], v1b = ST[5];
  double v5a = fma(z, v2a, ST[6]), v5b = fma(z, v2b, ST[7]);
  double v6a = fma(z, v3a, ST[8]), v6b = fma(z, v3b, ST[9]);
  double v0a = v1a * v5a, v0b = v1b * v5b;
  v0a = v0a * v6a; v0b = v0b * v6b;
  float fa = (float)v0a, fb = (float)v0b;
  if (n & 2) { fa = -fa; fb = -fb; }
  if (n & 1) { *s = fb; *c = -fa; } else { *s = fa; *c = fb; }
}
float my_tanf(float x) {
  uint32_t w0 = fbits(x), w1 = w0 & 0x7fffffff;
  double d0;
  uint32_t par;
  if (w1 >= 0x4c800000) {
    if (w1 >= 0x7f800000) return x - x;
    d0 = (double)x;
    int i = (int)(w1 >> 24) - 0x4b;
    if (i < 0) i = 0;
    double d4 = d0 * TNT[2 * i], d5 = d0 * TNT[2 * i + 1];
    double d1 = d4 + TN[0];
    par = (uint32_t)dbits(d1);
    d1 = d1 - TN[0];
    d4 = d4 - d1;
    d0 = d4 + d5;
  } else if (w1 < 0x3f490fdb) {
    if (w1 < 0x39800000) return fmaf(x, 67108864.0f, x) * 1.4901161193847656e-08f;
    d0 = (double)x;
    const double *P = TN + 4; // b80..
    double d1 = d0 * d0;
    double d6 = fma(d1, P[1], P[2]);
    double d16 = fma(d1, P[3], P[4]);
    double d18 = fma(d1, P[5], P[6]);
    double d2 = d1 * d1;
    d6 = fma(d2, P[0], d6);
    d18 = fma(d2, d16, d18);
    d2 = d2 * d2;
    d18 = fma(d2, d6, d18);
    d1 = d1 * d18;
    d0 = fma(d0, d1, d0);
    return (float)d0;
  } else {
    d0 = (double)x;
    double d2 = d0 * TN[2];
    par = (uint32_t)(uint64_t)rne_i(d2);
    double d1 = nearbyint(d2);
    d2 = d2 - d1;
    d0 = fma(d0, TN[3], d2);
  }
  const double *Q = TN + 12; // bc0..
  double d1 = d0 * d0;
  double d5 = fma(d1, Q[0], Q[1]);
  double d6 = d1 + Q[2], d7 = d1 + Q[3], d16 = d1 + Q[4];
  d5 = d0 * d5;
  double d17 = fma(d1, d6, Q[5]);
  double d18 = fma(d1, d7, Q[6]);
  double d19 = fma(d1, d16, Q[7]);
  d5 = d5 * d17;
  d18 = d18 * d19;
  d0 = d5 * d18;
  if (par & 1) d0 = TN[1] / d0;
  return (float)d0;
}
static double atan_poly(double q) {
  double z = q * q;
  double v3a = z + AT[0], v3b = z + AT[1];
  double v4a = fma(v3a, z, AT[2]), v4b = fma(v3b, z, AT[3]);
  double v2a = z + AT[4], v2b = z + AT[5];
  double w3a = fma(v2a, z, AT[6]), w3b = fma(v2b, z, AT[7]);
  double pa = v4a * w3a, pb = v4b * w3b;
  double ra = pa * AT[8], rb = pb * q;
  return ra * rb;
}
float my_atan2f(float y, float x) {
  double d0;
  if (y < x) {
    if (-x < y) {
      d0 = atan_poly((double)y / (double)x);
    } else if (-x == y) {
      d0 = AT[18];
    } else {
      d0 = AT[13] - atan_poly((double)x / (double)y);
    }
  } else if (y == x) {
    if (y < 0.0f) d0 = AT[16];
    else if (y != 0.0f) d0 = AT[17];
    else {
      if (!(fbits(x) >> 31)) return y;
      d0 = (fbits(y) >> 31) ? -AT[14] : AT[14];
    }
  } else if (y != y || x != x) {
    return y + x;
  } else if (-x < y) {
    d0 = AT[12] - atan_poly((double)x / (double)y);
  } else if (-x == y) {
    d0 = AT[15];
  } else {
    double q = (double)y / (double)x;
    if (fabs(q) < AT[9]) d0 = (fbits(y) >> 31) ? -AT[14] : AT[14];
    else d0 = atan_poly(q) + ((fbits(y) >> 31) ? AT[11] : AT[10]);
  }
  return (float)d0;
}
