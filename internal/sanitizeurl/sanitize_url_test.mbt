///|
test "links are sanitized and web addresses normalized" {
  inspect(
    @sanitizeurl.sanitize_url("https://x.example"),
    content="https://x.example/",
  )
  inspect(
    @sanitizeurl.sanitize_url("HTTPS://X.Example/Path"),
    content="https://x.example/Path",
  )
  inspect(
    @sanitizeurl.sanitize_url("https://x.example/a/../b/./c"),
    content="https://x.example/b/c",
  )
  inspect(
    @sanitizeurl.sanitize_url("https://x.example/?q=a b&c='d'"),
    content="https://x.example/?q=a%20b&c=%27d%27",
  )
  inspect(
    @sanitizeurl.sanitize_url("https://x.example/{a}|b^c`d"),
    content="https://x.example/%7Ba%7D%7Cb%5Ec%60d",
  )
  inspect(
    @sanitizeurl.sanitize_url("https://x.example/caf\u{e9}"),
    content="https://x.example/caf%C3%A9",
  )
  inspect(
    @sanitizeurl.sanitize_url("https://x.example/%7Efoo"),
    content="https://x.example/~foo",
  )
  inspect(
    @sanitizeurl.sanitize_url("https:x.example"),
    content="https://x.example/",
  )
  // An address with a second colon is taken as it is.
  inspect(
    @sanitizeurl.sanitize_url("https://x.example:8080/a"),
    content="https://x.example:8080/a",
  )
  inspect(
    @sanitizeurl.sanitize_url("javascript:alert(1)"),
    content="about:blank",
  )
  inspect(
    @sanitizeurl.sanitize_url("  jav&#x09;ascript:alert(1)"),
    content="about:blank",
  )
  inspect(@sanitizeurl.sanitize_url(""), content="about:blank")
  inspect(@sanitizeurl.sanitize_url("./relative"), content="./relative")
  inspect(
    @sanitizeurl.sanitize_url("mailto:someone@example.com"),
    content="mailto:someone@example.com",
  )
}

///|
test "character references are read as JavaScript numbers" {
  // What upstream renders for these click links (checked with the oracle).
  inspect(@sanitizeurl.sanitize_url("x&#0x41-y"), content="xA-y")
  inspect(@sanitizeurl.sanitize_url("x&#4295032897-y"), content="xA-y")
  inspect(@sanitizeurl.sanitize_url("x&#1e2-y"), content="xd-y")
  inspect(
    @sanitizeurl.sanitize_url("x&#0b1000001-y&#0o101-z"),
    content="xA-yA-z",
  )
  inspect(@sanitizeurl.sanitize_url("x&#Infinity-y&#1_0-z"), content="x-y-z")
  // A lone surrogate is not reproduced.
  let result : Result[String, Error] = Ok(
    @sanitizeurl.sanitize_url("x&#55357-y"),
  ) catch {
    error => Err(error)
  }
  debug_inspect(result is Err(@sanitizeurl.Unsupported(_)), content="true")
}

///|
test "a host that decodes to a forbidden code point is no address" {
  inspect(@sanitizeurl.sanitize_url("https://a%3Ab/%ZZ"), content="about:blank")
}
