(() => {
  // venn.js draws the starting points of one of its initial layouts from
  // Math.random() when a diagram has eight areas or more (four sets).
  // The port draws them from mulberry32 seeded with 0 (see
  // diagrams/venn/layout.mbt); this gives the page the same generator,
  // restarted for every diagram.
  let state = 0;
  Math.random = () => {
    state = (state + 0x6d2b79f5) | 0;
    let t = Math.imul(state ^ (state >>> 15), state | 1);
    t = (t + Math.imul(t ^ (t >>> 7), t | 61)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
  const render = mermaid.render.bind(mermaid);
  mermaid.render = (...args) => {
    state = 0;
    return render(...args);
  };
  return 'venn layouts are reproducible';
})()
