///|
/// Under the sandbox security level upstream hands back an `<iframe>`, not
/// the SVG; the port refuses rather than drawing the SVG alone. Frontmatter
/// cannot set it (it is a secure key), so it stays an ordinary render.
test "sandbox security level" {
  let site = Json::object({ "securityLevel": Json::string("sandbox") })
  let refused = try @mermaid.render("pie\n\"a\": 1\n", config=site) catch {
    @mermaid.Unsupported(message) => message
    _ => "another error"
  } noraise {
    _ => "rendered"
  }
  inspect(refused, content="the sandbox security level")
  let from_frontmatter = try
    @mermaid.render(
      "---\nconfig:\n  securityLevel: sandbox\n---\npie\n\"a\": 1\n",
    )
  catch {
    _ => "failed"
  } noraise {
    svg => svg[:4].to_owned()
  }
  inspect(from_frontmatter, content="<svg")
}
