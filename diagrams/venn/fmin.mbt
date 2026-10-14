// The optimisers of the `fmin` library as bundled in @upsetjs/venn.js,
// transcribed operation by operation: the layout is what iterating them
// in floating point arrives at, so the order of every sum and product is
// that of the JavaScript.

///|
/// `Math.max` of two numbers.
fn js_max(a : Double, b : Double) -> Double {
  if a.is_nan() || b.is_nan() {
    @double.not_a_number
  } else if a > b {
    a
  } else if b > a {
    b
  } else if a == 0.0 {
    // Of two zeros the positive one.
    a + b
  } else {
    a
  }
}

///|
/// `Math.min` of two numbers.
fn js_min(a : Double, b : Double) -> Double {
  if a.is_nan() || b.is_nan() {
    @double.not_a_number
  } else if a < b {
    a
  } else if b < a {
    b
  } else if a == 0.0 {
    // Of two zeros the negative one.
    -(-a + -b)
  } else {
    a
  }
}

///|
/// Whether a number is truthy in JavaScript.
fn truthy(value : Double) -> Bool {
  value != 0.0 && !value.is_nan()
}

///|
/// `bisect`: a root of `f` between `a` and `b`, with the default
/// parameters.
fn bisect(
  f : (Double) -> Double,
  a : Double,
  b : Double,
) -> Double raise VennError {
  let max_iterations = 100
  let tolerance = 1.0e-10
  let mut a = a
  let f_a = f(a)
  let f_b = f(b)
  let mut delta = b - a
  if f_a * f_b > 0.0 {
    // venn.js throws this string.
    raise Invalid("Initial bisect points must have opposite signs")
  }
  if f_a == 0.0 {
    return a
  }
  if f_b == 0.0 {
    return b
  }
  for _ in 0..<max_iterations {
    delta /= 2.0
    let mid = a + delta
    let f_mid = f(mid)
    if f_mid * f_a >= 0.0 {
      a = mid
    }
    if delta.abs() < tolerance || f_mid == 0.0 {
      return mid
    }
  }
  a + delta
}

///|
fn zeros(n : Int32) -> Array[Double] {
  Array::make(n, 0.0)
}

///|
fn dot(a : Array[Double], b : Array[Double]) -> Double {
  let mut ret = 0.0
  for i in 0..<a.length() {
    ret += a[i] * b[i]
  }
  ret
}

///|
fn norm2(a : Array[Double]) -> Double {
  dot(a, a).sqrt()
}

///|
/// `scale(ret, value, c)`
fn scale_into(ret : Array[Double], value : Array[Double], c : Double) -> Unit {
  for i in 0..<value.length() {
    ret[i] = value[i] * c
  }
}

///|
/// `weightedSum(ret, w1, v1, w2, v2)`
fn weighted_sum(
  ret : Array[Double],
  w1 : Double,
  v1 : Array[Double],
  w2 : Double,
  v2 : Array[Double],
) -> Unit {
  for j in 0..<ret.length() {
    ret[j] = w1 * v1[j] + w2 * v2[j]
  }
}

///|
/// A point of a simplex: a JavaScript array with an `fx` property.
priv struct Vertex {
  x : Array[Double]
  mut fx : Double
}

///|
/// `nelderMead(f, x0, { maxIterations, minErrorDelta })`. Without a
/// `min_error_delta` the function values must agree to 1e-6 and the
/// points to 1e-5; with one, both to it.
fn nelder_mead(
  f : (Array[Double]) -> Double,
  x0 : Array[Double],
  max_iterations~ : Int32,
  min_error_delta? : Double,
) -> Vertex {
  let non_zero_delta = 1.05
  let zero_delta = 0.001
  let min_tolerance = min_error_delta.unwrap_or(1.0e-5)
  let min_error_delta = min_error_delta.unwrap_or(1.0e-6)
  let rho = 1.0
  let chi = 2.0
  let psi = -0.5
  let sigma = 0.5
  let n = x0.length()
  let simplex : Array[Vertex] = [{ x: x0, fx: f(x0), }]
  for i in 0..<n {
    let point = x0.copy()
    point[i] = if truthy(point[i]) {
      point[i] * non_zero_delta
    } else {
      zero_delta
    }
    simplex.push({ x: point, fx: f(point), })
  }
  let update_simplex = (value : Vertex) => {
    for i in 0..<value.x.length() {
      simplex[n].x[i] = value.x[i]
    }
    simplex[n].fx = value.fx
  }
  let sort_order = (a : Vertex, b : Vertex) => a.fx - b.fx
  let centroid = x0.copy()
  let reflected : Vertex = { x: x0.copy(), fx: 0.0, }
  let contracted : Vertex = { x: x0.copy(), fx: 0.0, }
  let expanded : Vertex = { x: x0.copy(), fx: 0.0, }
  for _ in 0..<max_iterations {
    @d3.js_sort(simplex, sort_order)
    let mut max_diff = 0.0
    for i in 0..<n {
      max_diff = js_max(max_diff, (simplex[0].x[i] - simplex[1].x[i]).abs())
    }
    if (simplex[0].fx - simplex[n].fx).abs() < min_error_delta &&
      max_diff < min_tolerance {
      break
    }
    for i in 0..<n {
      centroid[i] = 0.0
      for j in 0..<n {
        centroid[i] += simplex[j].x[i]
      }
      centroid[i] /= n.to_double()
    }
    let worst = simplex[n]
    weighted_sum(reflected.x, 1.0 + rho, centroid, -rho, worst.x)
    reflected.fx = f(reflected.x)
    if reflected.fx < simplex[0].fx {
      weighted_sum(expanded.x, 1.0 + chi, centroid, -chi, worst.x)
      expanded.fx = f(expanded.x)
      if expanded.fx < reflected.fx {
        update_simplex(expanded)
      } else {
        update_simplex(reflected)
      }
    } else if reflected.fx >= simplex[n - 1].fx {
      let mut should_reduce = false
      if reflected.fx > worst.fx {
        weighted_sum(contracted.x, 1.0 + psi, centroid, -psi, worst.x)
        contracted.fx = f(contracted.x)
        if contracted.fx < worst.fx {
          update_simplex(contracted)
        } else {
          should_reduce = true
        }
      } else {
        weighted_sum(
          contracted.x,
          1.0 - psi * rho,
          centroid,
          psi * rho,
          worst.x,
        )
        contracted.fx = f(contracted.x)
        if contracted.fx < reflected.fx {
          update_simplex(contracted)
        } else {
          should_reduce = true
        }
      }
      if should_reduce {
        if sigma >= 1.0 {
          break
        }
        for i in 1..<simplex.length() {
          weighted_sum(
            simplex[i].x,
            1.0 - sigma,
            simplex[0].x,
            sigma,
            simplex[i].x,
          )
          simplex[i].fx = f(simplex[i].x)
        }
      }
    } else {
      update_simplex(reflected)
    }
  }
  @d3.js_sort(simplex, sort_order)
  simplex[0]
}

///|
/// A point of a descent: where, the value there and the gradient.
priv struct Descent {
  x : Array[Double]
  mut fx : Double
  fxprime : Array[Double]
}

///|
/// `wolfeLineSearch(f, pk, current, next, a)`: a step along `pk` that
/// satisfies the strong Wolfe conditions, leaving the point reached in
/// `next`. Zero when none was found.
fn wolfe_line_search(
  f : (Array[Double], Array[Double]) -> Double,
  pk : Array[Double],
  current : Descent,
  next : Descent,
  a : Double,
) -> Double {
  let phi0 = current.fx
  let phi_prime0 = dot(current.fxprime, pk)
  let mut phi = phi0
  let mut phi_old = phi0
  let mut phi_prime = phi_prime0
  let mut a0 = 0.0
  let mut a = if truthy(a) { a } else { 1.0 }
  let c1 = 1.0e-6
  let c2 = 0.1
  let zoom = (a_lo : Double, a_high : Double, phi_lo : Double) => {
    let mut a_lo = a_lo
    let mut a_high = a_high
    let mut phi_lo = phi_lo
    for _ in 0..<16 {
      a = (a_lo + a_high) / 2.0
      weighted_sum(next.x, 1.0, current.x, a, pk)
      next.fx = f(next.x, next.fxprime)
      phi = next.fx
      phi_prime = dot(next.fxprime, pk)
      if phi > phi0 + c1 * a * phi_prime0 || phi >= phi_lo {
        a_high = a
      } else {
        if phi_prime.abs() <= -c2 * phi_prime0 {
          return a
        }
        if phi_prime * (a_high - a_lo) >= 0.0 {
          a_high = a_lo
        }
        a_lo = a
        phi_lo = phi
      }
    }
    0.0
  }
  for iteration in 0..<10 {
    weighted_sum(next.x, 1.0, current.x, a, pk)
    next.fx = f(next.x, next.fxprime)
    phi = next.fx
    phi_prime = dot(next.fxprime, pk)
    if phi > phi0 + c1 * a * phi_prime0 || (iteration != 0 && phi >= phi_old) {
      return zoom(a0, a, phi_old)
    }
    if phi_prime.abs() <= -c2 * phi_prime0 {
      return a
    }
    if phi_prime >= 0.0 {
      return zoom(a, a0, phi)
    }
    phi_old = phi
    a0 = a
    a *= 2.0
  }
  a
}

///|
/// `conjugateGradient(f, initial, { maxIterations })`, where `f` returns
/// the value at a point and writes the gradient there into its second
/// argument.
fn conjugate_gradient(
  f : (Array[Double], Array[Double]) -> Double,
  initial : Array[Double],
  max_iterations : Int32,
) -> Descent {
  let mut current : Descent = {
    x: initial.copy(),
    fx: 0.0,
    fxprime: initial.copy(),
  }
  let mut next : Descent = {
    x: initial.copy(),
    fx: 0.0,
    fxprime: initial.copy(),
  }
  let yk = initial.copy()
  let mut a = 1.0
  current.fx = f(current.x, current.fxprime)
  let pk = current.fxprime.copy()
  scale_into(pk, current.fxprime, -1.0)
  for _ in 0..<max_iterations {
    a = wolfe_line_search(f, pk, current, next, a)
    if !truthy(a) {
      // No step: start over along the steepest descent.
      scale_into(pk, current.fxprime, -1.0)
    } else {
      // Polak–Ribière.
      weighted_sum(yk, 1.0, next.fxprime, -1.0, current.fxprime)
      let delta_k = dot(current.fxprime, current.fxprime)
      let beta_k = js_max(0.0, dot(yk, next.fxprime) / delta_k)
      weighted_sum(pk, beta_k, pk, -1.0, next.fxprime)
      let temp = current
      current = next
      next = temp
    }
    if norm2(current.fxprime) <= 1.0e-5 {
      break
    }
  }
  current
}
