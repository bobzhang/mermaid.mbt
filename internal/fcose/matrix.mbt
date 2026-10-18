// layout-base 2.0.1's `Matrix` and `SVD` (a transcription of JAMA's
// singular value decomposition), which the spectral layout and the
// transformation onto the constraints use.

///|
/// `Matrix.multMat`.
fn mult_mat(
  a : Array[Array[Double]],
  b : Array[Array[Double]],
) -> Array[Array[Double]] {
  let result = []
  for i in 0..<a.length() {
    let row = []
    for j in 0..<b[0].length() {
      let mut sum = 0.0
      for k in 0..<a[0].length() {
        sum += a[i][k] * b[k][j]
      }
      row.push(sum)
    }
    result.push(row)
  }
  result
}

///|
/// `Matrix.transpose`.
fn transpose(a : Array[Array[Double]]) -> Array[Array[Double]] {
  let result = []
  for i in 0..<a[0].length() {
    let row = []
    for j in 0..<a.length() {
      row.push(a[j][i])
    }
    result.push(row)
  }
  result
}

///|
/// `Matrix.multCons`.
fn mult_cons(a : Array[Double], constant : Double) -> Array[Double] {
  a.map(x => x * constant)
}

///|
/// `Matrix.minusOp`.
fn minus_op(a : Array[Double], b : Array[Double]) -> Array[Double] {
  a.mapi((i, x) => x - b[i])
}

///|
/// `Matrix.dotProduct`.
fn dot_product(a : Array[Double], b : Array[Double]) -> Double {
  let mut product = 0.0
  for i in 0..<a.length() {
    product += a[i] * b[i]
  }
  product
}

///|
/// `Matrix.normalize`.
fn normalize(a : Array[Double]) -> Array[Double] {
  let magnitude = dot_product(a, a).sqrt()
  a.map(x => x / magnitude)
}

///|
/// `Matrix.multGamma`: the vector less its mean.
fn mult_gamma(a : Array[Double]) -> Array[Double] {
  let mut sum = 0.0
  for x in a {
    sum += x
  }
  sum *= -1.0 / a.length().to_double()
  a.map(x => sum + x)
}

///|
/// `Matrix.multL`: the vector through the double centred distances, given
/// by the sample columns `c` and the pseudo-inverse of the samples' block.
fn mult_l(
  a : Array[Double],
  c : Array[Array[Double]],
  inv : Array[Array[Double]],
) -> Array[Double] {
  let temp1 = []
  for i in 0..<c[0].length() {
    let mut sum = 0.0
    for j in 0..<c.length() {
      sum += -0.5 * c[j][i] * a[j]
    }
    temp1.push(sum)
  }
  let temp2 = []
  for i in 0..<inv.length() {
    let mut sum = 0.0
    for j in 0..<inv.length() {
      sum += inv[i][j] * temp1[j]
    }
    temp2.push(sum)
  }
  let result = []
  for i in 0..<c.length() {
    let mut sum = 0.0
    for j in 0..<c[0].length() {
      sum += c[i][j] * temp2[j]
    }
    result.push(sum)
  }
  result
}

///|
/// `SVD.hypot`.
fn svd_hypot(a : Double, b : Double) -> Double {
  if a.abs() > b.abs() {
    let r = b / a
    a.abs() * (1.0 + r * r).sqrt()
  } else if b != 0.0 {
    let r = a / b
    b.abs() * (1.0 + r * r).sqrt()
  } else {
    0.0
  }
}

///|
/// What `SVD.svd` answers: `A = U S V'`.
priv struct Svd {
  u : Array[Array[Double]]
  v : Array[Array[Double]]
  s : Array[Double]
}

///|
/// `SVD.svd`, which works on `a` in place.
fn svd(a : Array[Array[Double]]) -> Svd {
  let m = a.length()
  let n = a[0].length()
  let min = (x : Int32, y : Int32) => if x < y { x } else { y }
  let max = (x : Int32, y : Int32) => if x > y { x } else { y }
  let nu = min(m, n)
  let s = Array::make(min(m + 1, n), 0.0)
  let u = Array::makei(m, _ => Array::make(nu, 0.0))
  let v = Array::makei(n, _ => Array::make(n, 0.0))
  let e = Array::make(n, 0.0)
  let work = Array::make(m, 0.0)
  let nct = min(m - 1, n)
  let nrt = max(0, min(n - 2, m))
  for k in 0..<max(nct, nrt) {
    if k < nct {
      s[k] = 0.0
      for i in k..<m {
        s[k] = svd_hypot(s[k], a[i][k])
      }
      if s[k] != 0.0 {
        if a[k][k] < 0.0 {
          s[k] = -s[k]
        }
        for i in k..<m {
          a[i][k] /= s[k]
        }
        a[k][k] += 1.0
      }
      s[k] = -s[k]
    }
    for j in (k + 1)..<n {
      if k < nct && s[k] != 0.0 {
        let mut t = 0.0
        for i in k..<m {
          t += a[i][k] * a[i][j]
        }
        t = -t / a[k][k]
        for i in k..<m {
          a[i][j] += t * a[i][k]
        }
      }
      e[j] = a[k][j]
    }
    if k < nct {
      for i in k..<m {
        u[i][k] = a[i][k]
      }
    }
    if k < nrt {
      e[k] = 0.0
      for i in (k + 1)..<n {
        e[k] = svd_hypot(e[k], e[i])
      }
      if e[k] != 0.0 {
        if e[k + 1] < 0.0 {
          e[k] = -e[k]
        }
        for i in (k + 1)..<n {
          e[i] /= e[k]
        }
        e[k + 1] += 1.0
      }
      e[k] = -e[k]
      if k + 1 < m && e[k] != 0.0 {
        for i in (k + 1)..<m {
          work[i] = 0.0
        }
        for j in (k + 1)..<n {
          for i in (k + 1)..<m {
            work[i] += e[j] * a[i][j]
          }
        }
        for j in (k + 1)..<n {
          let t = -e[j] / e[k + 1]
          for i in (k + 1)..<m {
            a[i][j] += t * work[i]
          }
        }
      }
      for i in (k + 1)..<n {
        v[i][k] = e[i]
      }
    }
  }
  let mut p = min(n, m + 1)
  if nct < n {
    s[nct] = a[nct][nct]
  }
  if m < p {
    s[p - 1] = 0.0
  }
  if nrt + 1 < p {
    e[nrt] = a[nrt][p - 1]
  }
  e[p - 1] = 0.0
  for j in nct..<nu {
    for i in 0..<m {
      u[i][j] = 0.0
    }
    u[j][j] = 1.0
  }
  for k = nct - 1; k >= 0; k = k - 1 {
    if s[k] != 0.0 {
      for j in (k + 1)..<nu {
        let mut t = 0.0
        for i in k..<m {
          t += u[i][k] * u[i][j]
        }
        t = -t / u[k][k]
        for i in k..<m {
          u[i][j] += t * u[i][k]
        }
      }
      for i in k..<m {
        u[i][k] = -u[i][k]
      }
      u[k][k] = 1.0 + u[k][k]
      // JAMA's `i < k - 1`, one short.
      for i in 0..<(k - 1) {
        u[i][k] = 0.0
      }
    } else {
      for i in 0..<m {
        u[i][k] = 0.0
      }
      u[k][k] = 1.0
    }
  }
  for k = n - 1; k >= 0; k = k - 1 {
    if k < nrt && e[k] != 0.0 {
      for j in (k + 1)..<nu {
        let mut t = 0.0
        for i in (k + 1)..<n {
          t += v[i][k] * v[i][j]
        }
        t = -t / v[k + 1][k]
        for i in (k + 1)..<n {
          v[i][j] += t * v[i][k]
        }
      }
    }
    for i in 0..<n {
      v[i][k] = 0.0
    }
    v[k][k] = 1.0
  }
  let pp = p - 1
  let eps = 2.220446049250313e-16
  // `Math.pow(2, -966)`
  let tiny = (57L << 52).reinterpret_as_double()
  while p > 0 {
    let mut k = p - 2
    while k >= -1 {
      if k == -1 {
        break
      }
      if e[k].abs() <= tiny + eps * (s[k].abs() + s[k + 1].abs()) {
        e[k] = 0.0
        break
      }
      k -= 1
    }
    let mut kase = 0
    if k == p - 2 {
      kase = 4
    } else {
      let mut ks = p - 1
      while ks >= k {
        if ks == k {
          break
        }
        let t = (if ks != p { e[ks].abs() } else { 0.0 }) +
          (if ks != k + 1 { e[ks - 1].abs() } else { 0.0 })
        if s[ks].abs() <= tiny + eps * t {
          s[ks] = 0.0
          break
        }
        ks -= 1
      }
      if ks == k {
        kase = 3
      } else if ks == p - 1 {
        kase = 1
      } else {
        kase = 2
        k = ks
      }
    }
    k += 1
    match kase {
      1 => {
        let mut f = e[p - 2]
        e[p - 2] = 0.0
        for j = p - 2; j >= k; j = j - 1 {
          let mut t = svd_hypot(s[j], f)
          let cs = s[j] / t
          let sn = f / t
          s[j] = t
          if j != k {
            f = -sn * e[j - 1]
            e[j - 1] = cs * e[j - 1]
          }
          for i in 0..<n {
            t = cs * v[i][j] + sn * v[i][p - 1]
            v[i][p - 1] = -sn * v[i][j] + cs * v[i][p - 1]
            v[i][j] = t
          }
        }
      }
      2 => {
        let mut f = e[k - 1]
        e[k - 1] = 0.0
        for j in k..<p {
          let mut t = svd_hypot(s[j], f)
          let cs = s[j] / t
          let sn = f / t
          s[j] = t
          f = -sn * e[j]
          e[j] = cs * e[j]
          for i in 0..<m {
            t = cs * u[i][j] + sn * u[i][k - 1]
            u[i][k - 1] = -sn * u[i][j] + cs * u[i][k - 1]
            u[i][j] = t
          }
        }
      }
      3 => {
        let fmax = (x : Double, y : Double) => {
          if y > x || x.is_nan() {
            if y.is_nan() || x.is_nan() {
              @double.not_a_number
            } else {
              y
            }
          } else if y.is_nan() {
            @double.not_a_number
          } else {
            x
          }
        }
        let scale = fmax(
          fmax(
            fmax(fmax(s[p - 1].abs(), s[p - 2].abs()), e[p - 2].abs()),
            s[k].abs(),
          ),
          e[k].abs(),
        )
        let sp = s[p - 1] / scale
        let spm1 = s[p - 2] / scale
        let epm1 = e[p - 2] / scale
        let sk = s[k] / scale
        let ek = e[k] / scale
        let b = ((spm1 + sp) * (spm1 - sp) + epm1 * epm1) / 2.0
        let c = sp * epm1 * (sp * epm1)
        let mut shift = 0.0
        if b != 0.0 || c != 0.0 {
          shift = (b * b + c).sqrt()
          if b < 0.0 {
            shift = -shift
          }
          shift = c / (b + shift)
        }
        let mut f = (sk + sp) * (sk - sp) + shift
        let mut g = sk * ek
        for j in k..<(p - 1) {
          let mut t = svd_hypot(f, g)
          let mut cs = f / t
          let mut sn = g / t
          if j != k {
            e[j - 1] = t
          }
          f = cs * s[j] + sn * e[j]
          e[j] = cs * e[j] - sn * s[j]
          g = sn * s[j + 1]
          s[j + 1] = cs * s[j + 1]
          for i in 0..<n {
            t = cs * v[i][j] + sn * v[i][j + 1]
            v[i][j + 1] = -sn * v[i][j] + cs * v[i][j + 1]
            v[i][j] = t
          }
          t = svd_hypot(f, g)
          cs = f / t
          sn = g / t
          s[j] = t
          f = cs * e[j] + sn * s[j + 1]
          s[j + 1] = -sn * e[j] + cs * s[j + 1]
          g = sn * e[j + 1]
          e[j + 1] = cs * e[j + 1]
          if j < m - 1 {
            for i in 0..<m {
              t = cs * u[i][j] + sn * u[i][j + 1]
              u[i][j + 1] = -sn * u[i][j] + cs * u[i][j + 1]
              u[i][j] = t
            }
          }
        }
        e[p - 2] = f
      }
      _ => {
        if s[k] <= 0.0 {
          s[k] = if s[k] < 0.0 { -s[k] } else { 0.0 }
          for i in 0..<=pp {
            v[i][k] = -v[i][k]
          }
        }
        while k < pp {
          if s[k] >= s[k + 1] {
            break
          }
          let t = s[k]
          s[k] = s[k + 1]
          s[k + 1] = t
          if k < n - 1 {
            for i in 0..<n {
              let t = v[i][k + 1]
              v[i][k + 1] = v[i][k]
              v[i][k] = t
            }
          }
          if k < m - 1 {
            for i in 0..<m {
              let t = u[i][k + 1]
              u[i][k + 1] = u[i][k]
              u[i][k] = t
            }
          }
          k += 1
        }
        p -= 1
      }
    }
  }
  { u, v, s, }
}
