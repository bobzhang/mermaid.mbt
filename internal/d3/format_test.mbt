// Expected values are those of d3-format 3.1.0 in the reference browser's
// JavaScript engine; `scripts`-style bulk comparison lives in the CLI's
// `format` command.

///|
fn formatted(specifier : String, value : Double) -> String {
  let format = @d3.format(specifier) catch {
    @d3.InvalidFormat(message) => return message
  }
  format.apply(value)
}

///|
test "the default format groups thousands and trims zeros" {
  inspect(formatted(",", 70.0), content="70")
  inspect(formatted(",", 1234567.891), content="1,234,567.891")
  inspect(formatted(",", 0.1 + 0.2), content="0.3")
  inspect(formatted("", 1.0e21), content="1e+21")
  inspect(formatted(",", -1234.5), content="−1,234.5")
}

///|
test "fixed, exponent, rounded, percent and SI types" {
  inspect(formatted(".2f", 1.005), content="1.00")
  inspect(formatted(",.2f", 1234567.891), content="1,234,567.89")
  inspect(formatted(".0f", 2.5), content="3")
  inspect(formatted(".3e", 12345.678), content="1.235e+4")
  inspect(formatted(".2r", 0.000123456), content="0.00012")
  inspect(formatted(".1%", 0.1234), content="12.3%")
  inspect(formatted(".0%", 0.125), content="13%")
  inspect(formatted(".3s", 1234567.891), content="1.23M")
  inspect(formatted("s", 0.000042), content="42.0000µ")
  inspect(formatted(".2~s", 1500.0), content="1.5k")
  inspect(formatted("d", 2.5), content="3")
  inspect(formatted("d", 1.5e22), content="15000000000000000000000")
}

///|
test "sign, symbol, padding and alignment" {
  inspect(formatted("+,", 1000.0), content="+1,000")
  inspect(formatted("(.1f", -3.14), content="(3.1)")
  inspect(formatted("$,.2f", 1234.5), content="$1,234.50")
  inspect(formatted("#x", 255.0), content="0xff")
  inspect(formatted("X", 255.0), content="FF")
  inspect(formatted("b", 5.0), content="101")
  inspect(formatted("010,.1f", 1234.56), content="0,001,234.6")
  inspect(formatted("*^12.1f", 3.14159), content="****3.1*****")
  inspect(formatted("x<8d", 42.0), content="42xxxxxx")
  inspect(formatted("c", 65.5), content="65.5")
}

///|
test "an invalid specifier is refused" {
  inspect(formatted("bogus!", 1.0), content="invalid format: bogus!")
  inspect(formatted(".2~f", 1.5), content="1.5")
}

///|
test "toFixed, toExponential and toPrecision round the exact binary value" {
  inspect(@d3.to_fixed(1.005, 2), content="1.00")
  inspect(@d3.to_fixed(0.5, 0), content="1")
  inspect(@d3.to_fixed(1.45, 1), content="1.4")
  inspect(@d3.to_fixed(8.345, 2), content="8.35")
  inspect(@d3.to_fixed(-0.0001, 2), content="-0.00")
  inspect(@d3.to_fixed(1.0e21, 2), content="1e+21")
  inspect(@d3.to_exponential(0.0, digits=2), content="0.00e+0")
  inspect(@d3.to_exponential(123456.0, digits=2), content="1.23e+5")
  inspect(@d3.to_exponential(0.00015), content="1.5e-4")
  inspect(@d3.to_exponential(99.99, digits=1), content="1.0e+2")
  inspect(@d3.to_precision(123.456, 4), content="123.5")
  inspect(@d3.to_precision(0.000001234, 2), content="0.0000012")
  inspect(@d3.to_precision(0.0000001234, 2), content="1.2e-7")
  inspect(@d3.to_precision(1234567.0, 3), content="1.23e+6")
  inspect(@d3.to_precision(0.0, 3), content="0.00")
}
