// `render --fetch-images`: the image loader of the command line. The
// renderer is pure and asks for images synchronously; the command renders,
// collects the URLs the loader was asked for and could not answer yet,
// fetches them (`http:` and `https:` with moonbitlang/async's HTTP client,
// `file:` from the disk), and renders again until no new URL is asked for.

///|
/// The longest one request may take, in milliseconds.
const FETCH_TIMEOUT : Int32 = 20000

///|
/// The redirects followed before giving up, as many as Chrome follows.
const MAX_REDIRECTS : Int32 = 20

///|
/// The scheme of a URL, in lower case, with its colon.
fn url_scheme(url : String) -> String {
  match url.find(":") {
    Some(at) => url[:at + 1].to_lower().to_owned()
    None => ""
  }
}

///|
/// `%XX` escapes decoded, as in the path of a `file:` URL.
fn percent_decoded(text : StringView) -> String {
  let bytes = @utf8.encode(text)
  let out : Array[Byte] = []
  let hex = (b : Byte) => {
    match b {
      b'0'..<=b'9' => Some(b.to_int() - 0x30)
      b'a'..<=b'f' => Some(b.to_int() - 0x61 + 10)
      b'A'..<=b'F' => Some(b.to_int() - 0x41 + 10)
      _ => None
    }
  }
  let mut i = 0
  while i < bytes.length() {
    if bytes[i] == b'%' &&
      i + 2 < bytes.length() &&
      hex(bytes[i + 1]) is Some(high) &&
      hex(bytes[i + 2]) is Some(low) {
      out.push((high * 16 + low).to_byte())
      i += 3
    } else {
      out.push(bytes[i])
      i += 1
    }
  }
  @utf8.decode_lossy(Bytes::from_array(out))
}

///|
/// The path a `file:` URL names on this machine (`file:///path`,
/// `file://localhost/path` or `file:/path`).
fn file_url_path(url : String) -> String? {
  let rest = url[5:]
  let rest = match rest.strip_prefix("//") {
    Some(authority) =>
      match authority.find("/") {
        Some(0) => authority
        Some(at) if authority[:at] == "localhost" => authority[at:]
        _ => return None
      }
    None => rest
  }
  guard rest.has_prefix("/") else { return None }
  let path = match rest.find("?") {
    Some(at) => rest[:at]
    None => rest
  }
  let path = match path.find("#") {
    Some(at) => path[:at]
    None => path
  }
  Some(percent_decoded(path))
}

///|
/// Where a redirect from `base` to `location` goes.
fn resolve_location(base : String, location : String) -> String {
  if url_scheme(location) is ("http:" | "https:") {
    return location
  }
  let scheme = url_scheme(base)
  let after_scheme = base[scheme.length() + 2:]
  let origin_end = after_scheme.find("/").unwrap_or(after_scheme.length())
  let origin = base[:scheme.length() + 2 + origin_end].to_owned()
  if location.has_prefix("//") {
    scheme + location
  } else if location.has_prefix("/") {
    origin + location
  } else {
    let path = after_scheme[origin_end:]
    let path = match path.find("?") {
      Some(at) => path[:at]
      None => path
    }
    let directory = match path.rev_find("/") {
      Some(at) => path[:at + 1].to_owned()
      None => "/"
    }
    origin + directory + location
  }
}

///|
/// The bytes of the image at `url`, or `None` when nothing came back. The
/// body of a response counts whatever its status, as a browser decodes the
/// body of an error response too.
async fn fetch_image(url : String) -> Bytes? {
  match url_scheme(url) {
    "file:" =>
      file_url_path(url).bind(path => {
        try @fs.read_file_to_bytes(path) catch {
          _ => None
        } noraise {
          data => Some(data)
        }
      })
    "http:" | "https:" => {
      let mut current = url
      for _ in 0..<MAX_REDIRECTS {
        let target = current
        let result = @async.with_timeout_opt(FETCH_TIMEOUT, () => {
          @http.get(target)
        }) catch {
          _ => return None
        }
        guard result is Some((response, body)) else { return None }
        if response.code is (301 | 302 | 303 | 307 | 308) &&
          response.headers.get(@http.CaseInsensitiveString("location"))
          is Some(location) {
          current = resolve_location(current, location)
          continue
        }
        return Some(body.binary())
      }
      None
    }
    _ => None
  }
}

///|
/// Render with images fetched as the renderer asks for them.
async fn render_fetching(
  text : String,
  id : String,
  site : Json,
  now : Double?,
  page : @diagram.Page,
) -> String raise @lib.MermaidError {
  let fetched : Map[String, Bytes?] = Map([])
  while true {
    let wanted : Array[String] = []
    let loader = (url : String) => {
      match fetched.get(url) {
        Some(data) => data
        None => {
          if !wanted.contains(url) {
            wanted.push(url)
          }
          None
        }
      }
    }
    let result : Result[String, @lib.MermaidError] = Ok(
      @lib.render(text, id~, config=site, now?, page~, image_loader=loader),
    ) catch {
      error => Err(error)
    }
    if wanted.is_empty() {
      match result {
        Ok(svg) => return svg
        Err(error) => raise error
      }
    }
    for url in wanted {
      fetched[url] = fetch_image(url) catch { _ => None }
    }
  }
  abort("unreachable")
}
