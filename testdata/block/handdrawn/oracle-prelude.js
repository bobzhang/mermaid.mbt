(async () => {
  // mermaid names a block the text does not name (a `space`, a composite
  // opened with a bare `block`) `id-<Math.random() in base 36>-<count>`,
  // counting over the lifetime of the page. The port takes every draw to
  // be 0.5 (`i` in base 36) and counts per diagram (see
  // diagrams/block/db.mbt); this gives the page's block database the same
  // generator, restarted for every diagram.
  const diagram = await mermaid.mermaidAPI.getDiagramFromText('block-beta\n  a');
  let count = 0;
  diagram.db.generateId = () => 'id-i-' + ++count;
  const render = mermaid.render.bind(mermaid);
  mermaid.render = (...args) => {
    count = 0;
    return render(...args);
  };
  return 'block ids are reproducible';
})()
