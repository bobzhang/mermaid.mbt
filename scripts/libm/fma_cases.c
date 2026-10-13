#include <math.h>
#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include <stdlib.h>
static uint64_t db(double x) { uint64_t u; memcpy(&u, &x, 8); return u; }
static double rnd(void) { // random double with a random exponent in a moderate range
  double m = 1.0 + drand48();
  int e = (int)(drand48() * 80) - 40;
  return (mrand48() & 1 ? -1 : 1) * ldexp(m, e);
}
int main(int argc, char **argv) {
  long n = atol(argv[1]);
  srand48(99);
  printf("///|\nlet fma_cases : Array[(Int64, Int64, Int64, Int64)] = [\n");
  for (long i = 0; i < n; i++) {
    volatile double a = rnd(), b = rnd(), c;
    switch (i % 5) {
      case 0: c = rnd(); break;
      case 1: c = -a * b * (1.0 + (drand48() - 0.5) * 1e-15); break;           // massive cancellation
      case 2: c = -a * b; break;                                                  // exact cancellation of the rounded product
      case 3: c = a * b * ldexp(1.0 + drand48(), (int)(drand48() * 110) - 55); break; // every alignment
      default: { // a tie: product exactly halfway between two neighbours of c
        a = 1.0 + ldexp((double)(mrand48() & 0x3ffffff), -26); b = ldexp(1.0, -53 + (int)(drand48() * 3) - 1);
        c = 1.0 + ldexp((double)(mrand48() & 0xfffff), -52); if (mrand48() & 1) b = -b; break; }
    }
    printf("  (0x%016llxL, 0x%016llxL, 0x%016llxL, 0x%016llxL),\n", db(a), db(b), db(c), db(fma(a, b, c)));
  }
  printf("]\n");
  return 0;
}
