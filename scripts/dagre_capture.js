// Evaluated in the oracle page (scripts/oracle.py --eval) before diagrams
// are rendered: every graph mermaid hands to dagre's `layout` is written to
// the console as `DAGRE_GRAPH <json>`, in the format scripts/dagre_oracle.js
// reads. scripts/dagre_corpus.py collects them.
//
// dagre is private to the bundle. Its `Graph` class is reached through a
// first, throw-away render: dagre binds methods of the graph it lays out
// (`g.successors.bind(g)`), which hands a graph to `Function.prototype.bind`.
// With the prototype in hand, the start of a layout is recognised by what
// `buildLayoutGraph` does first: it reads the label of the input graph and
// sets a freshly merged label, the only kind that has `edgesep`, on a new
// graph.
(async () => {
  let proto = null;
  const realBind = Function.prototype.bind;
  Function.prototype.bind = function (self, ...rest) {
    if (
      proto === null &&
      self !== null &&
      typeof self === 'object' &&
      typeof self.setGraph === 'function' &&
      typeof self.setEdge === 'function'
    ) {
      proto = Object.getPrototypeOf(self);
    }
    return realBind.call(this, self, ...rest);
  };
  try {
    await mermaid.render('dagre-probe', '---\nconfig:\n  layout: dagre\n---\nflowchart TD\n  a --> b\n');
  } finally {
    Function.prototype.bind = realBind;
  }
  if (proto === null) {
    return 'dagre graph class not found';
  }
  const encode = (value) => {
    const number = Number(value);
    return Number.isFinite(number) ? number : String(number);
  };
  // What `buildLayoutGraph` picks of a label: keys in lower case, the
  // numeric ones through `Number`.
  const pick = (label, numbers, texts) => {
    const out = {};
    for (const [key, value] of Object.entries(label || {})) {
      const name = key.toLowerCase();
      if (numbers.includes(name)) {
        out[name] = encode(value);
      } else if (texts.includes(name) && value !== undefined) {
        out[name] = value;
      }
    }
    return out;
  };
  const dump = (graph) => ({
    graph: pick(
      graph.graph(),
      ['nodesep', 'edgesep', 'ranksep', 'marginx', 'marginy'],
      ['acyclicer', 'ranker', 'rankdir', 'align']
    ),
    nodes: graph.nodes().map((v) => {
      const node = { id: v, ...pick(graph.node(v), ['width', 'height'], []) };
      const parent = graph.parent(v);
      if (parent !== undefined) {
        node.parent = parent;
      }
      return node;
    }),
    edges: graph.edges().map((e) => ({
      ...e,
      ...pick(graph.edge(e), ['minlen', 'weight', 'width', 'height', 'labeloffset'], ['labelpos']),
    })),
  });
  const { graph, setGraph } = proto;
  const seen = new WeakSet();
  let last = null;
  proto.graph = function () {
    last = this;
    return graph.call(this);
  };
  proto.setGraph = function (label) {
    if (label !== null && typeof label === 'object' && Object.hasOwn(label, 'edgesep') && !seen.has(label)) {
      seen.add(label);
      if (last !== null && last !== this) {
        console.log('DAGRE_GRAPH', JSON.stringify(dump(last)));
      }
    }
    return setGraph.call(this, label);
  };
  return 'capturing dagre graphs';
})()
