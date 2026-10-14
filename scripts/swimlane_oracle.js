#!/usr/bin/env node
// Run upstream's swimlane layout engine (the published bundle's chunk) on a
// captured layout input, outside the browser, and print the layout as JSON.
//
//   node scripts/swimlane_oracle.js capture.json [--stages]
//
// `capture.json` is what `scripts/swimlane_capture.py` writes: the layout data
// the flowchart renderer hands to `render` and the measured node sizes. The
// chunk is loaded as text with its imports replaced by stubs (the layout core
// draws nothing), so every internal function is reachable. The steps of
// `index.ts`/`layoutCore.ts`/`postProcessing.ts` are repeated here with a
// snapshot after each one when `--stages` is given; the output is
//
//   {"stages": [{"name": ..., "nodes": [...], "edges": [...]}, ...]}
//
// and without `--stages` only the last snapshot, `{"nodes": ..., "edges": ...}`.
//
//   node scripts/swimlane_oracle.js --from snapshot.json --run STEP [--direction D]
//
// runs one step of the post-processing (named as in the stage list) on the
// layout a snapshot shows and prints the snapshot after it.
// `cmd/mermaid swimlane` does the same for the port.

'use strict';
const fs = require('fs');
const path = require('path');

const CHUNK = path.join(
  __dirname,
  '..',
  '.repos/oracle/package/dist/chunks/mermaid.esm/swimlanes-7KI25NP3.mjs'
);

function loadEngine() {
  let source = fs.readFileSync(CHUNK, 'utf8');
  // Drop the import statements (single- and multi-line) and the export.
  source = source.replace(/^import\s*\{[^}]*\}\s*from\s*"[^"]*";\s*$/gm, '');
  source = source.replace(/^import\s*"[^"]*";\s*$/gm, '');
  source = source.replace(/^export\s*\{[^}]*\};?\s*$/gm, '');
  const names = [...source.matchAll(/^(?:async )?function ([A-Za-z0-9_]+)/gm)].map((m) => m[1]);
  const prelude = `
    const __name = (f) => f;
    const log = { debug() {}, info() {}, warn() {}, error() {}, trace() {} };
    const applyLineJumpsToSvg = () => {};
    const createCommonLayoutRenderer = () => () => {};
  `;
  const body = `${prelude}\n${source}\nreturn { ${names.join(', ')}, PRECISION, LAYERING, COORDINATES };`;
  return new Function(body)();
}

const NODE_FIELDS = [
  'id', 'x', 'y', 'width', 'height', 'layer', 'order', 'parentId', 'shape', 'direction',
  'isGroup', 'isEdgeLabel', 'swimlaneContentTop', 'groupTitleRect', 'colorIndex', 'padding',
];
const EDGE_FIELDS = ['id', 'start', 'end', 'points', 'curve', 'labelNodeId', 'isLayoutOnly', 'label'];

function pick(object, fields) {
  const out = {};
  for (const field of fields) {
    const value = object[field];
    if (value === undefined || value === null) continue;
    if (field === 'points') {
      out.points = value.map((p) => [p.x, p.y]);
    } else if (field === 'groupTitleRect') {
      out.groupTitleRect = [value.left, value.right, value.top, value.bottom];
    } else {
      out[field] = value;
    }
  }
  return out;
}

function snapshot(data, name) {
  return {
    name,
    nodes: (data.nodes ?? []).map((n) => pick(n, NODE_FIELDS)),
    edges: (data.edges ?? []).map((e) => pick(e, EDGE_FIELDS)),
  };
}

function snapshot_(layout) {
  const s = snapshot(layout, 'step');
  return { nodes: s.nodes, edges: s.edges };
}

function run(capture, wantStages) {
  const E = loadEngine();
  const data = capture.data;
  const stages = [];
  const dump = (name) => {
    if (wantStages) stages.push(snapshot(data, name));
  };
  // index.ts: prepareSwimlaneLayout
  E.prepareLayoutForSwimlanes(data);
  const transformed = E.createEdgeLabelNodes(data);
  data.nodes = transformed.nodes;
  data.edges = transformed.edges;
  // The measurement: every node that is not a group is drawn and sized.
  for (const node of data.nodes) {
    const size = capture.sizes[node.id];
    if (!node.isGroup && size) {
      node.width = size[0];
      node.height = size[1];
    }
  }
  dump('prepare');
  // layoutCore.ts: runSwimlaneLayoutCore
  const g = E.toGraphView(data);
  const nodeGap = data.config.flowchart?.nodeSpacing ?? 40;
  const layerGap = data.config.flowchart?.rankSpacing ?? 100;
  const direction = E.getSwimlaneDirection(data);
  const { ordered, coordinates } = E.sugiyamaLayout(g, {
    nodeGap,
    layerGap,
    ignoreCrossLaneEdges: data.config.swimlane?.ignoreCrossLaneEdges ?? true,
    optimizeRanksByCrossings: data.config.swimlane?.optimizeRanksByCrossings ?? true,
    automaticLaneOrdering: data.config.swimlane?.automaticLaneOrdering ?? false,
    direction,
  });
  E.writeBackToLayoutData(g, ordered, coordinates, { nodeGap, layerGap });
  for (const edge of data.edges ?? []) {
    delete edge.points;
  }
  dump('sugiyama');
  E.routeEdgesOrthogonal(data, direction);
  for (const edge of data.edges ?? []) {
    if (!edge.curve || edge.curve === 'basis') {
      edge.curve = 'rounded';
    }
  }
  dump('route');
  // postProcessing.ts: postProcessSwimlaneLayout
  const layout = data;
  const nodes = layout.nodes ?? [];
  const edges = layout.edges ?? [];
  const contentNodes = nodes.filter((n) => !n.isGroup);
  let stop = false;
  if ((direction === 'LR' || direction === 'RL') && contentNodes.length > 0 &&
      !E.applyLrDirectionTransform(layout, direction)) {
    stop = true;
  }
  if (!stop && direction === 'BT' && contentNodes.length > 0 && !E.applyBtDirectionTransform(layout)) {
    stop = true;
  }
  if (!stop) {
    dump('direction');
    for (const edge of edges) {
      if (edge.isLayoutOnly) continue;
      const pts = edge.points;
      if (!pts || pts.length < 2) continue;
      edge.points = E.simplifyPolyline(E.orthogonalizePolyline(pts));
    }
    dump('simplify');
    const step = (name, f) => {
      f();
      dump(name);
    };
    step('simplifyDetouredEdges', () => E.simplifyDetouredEdges(edges, nodes));
    step('straightenCollinearSiblingDetours', () => E.straightenCollinearSiblingDetours(edges, nodes));
    step('portSwapToLShape', () => E.portSwapToLShape(edges, nodes));
    const nodeByIdMap = new Map();
    for (const n of nodes) nodeByIdMap.set(String(n.id), n);
    step('anchorLabelsToPolyline', () => E.anchorLabelsToPolyline(edges, nodeByIdMap));
    step('clipEdgeEndpointsToNodeBoundaries', () => E.clipEdgeEndpointsToNodeBoundaries(edges, nodeByIdMap));
    step('collapseShortTerminalStub', () => E.collapseShortTerminalStub(edges, nodeByIdMap));
    step('nudgeSharedInteriorSubpaths', () => E.nudgeSharedInteriorSubpaths(edges, nodeByIdMap));
    step('separateSharedRenderedTerminalLanes', () => E.separateSharedRenderedTerminalLanes(edges, nodeByIdMap));
    step('collapseRedundantRectangularDoglegs', () => E.collapseRedundantRectangularDoglegs(edges, nodeByIdMap));
    step('liftObstacleHuggingSameSideRails', () => E.liftObstacleHuggingSameSideRails(edges, nodeByIdMap));
    step('swapDestinationTerminalTailsToReduceCrossings', () =>
      E.swapDestinationTerminalTailsToReduceCrossings(edges, nodeByIdMap));
    const finalize = (round) => {
      const s = (name, f) => step(`${round}.${name}`, f);
      s('resolveRenderedOrthogonalCrossings', () => E.resolveRenderedOrthogonalCrossings(edges, nodeByIdMap));
      s('separateSharedRenderedTerminalLanes', () => E.separateSharedRenderedTerminalLanes(edges, nodeByIdMap));
      s('reassignCrossingExternalRailChannels', () => E.reassignCrossingExternalRailChannels(edges, nodeByIdMap));
      s('shortcutRedundantOrthogonalJogs', () => E.shortcutRedundantOrthogonalJogs(edges, nodeByIdMap));
      s('anchorLabelsToPolyline', () => E.anchorLabelsToPolyline(edges, nodeByIdMap));
      s('prepareEdgeEndpointsForRenderer', () => E.prepareEdgeEndpointsForRenderer(edges, nodeByIdMap));
      s('liftObstacleHuggingSameSideRails', () => E.liftObstacleHuggingSameSideRails(edges, nodeByIdMap));
      s('anchorLabelsToPolyline2', () => E.anchorLabelsToPolyline(edges, nodeByIdMap));
      s('prepareEdgeEndpointsForRenderer2', () => E.prepareEdgeEndpointsForRenderer(edges, nodeByIdMap));
    };
    finalize('f1');
    step('nudgeSharedInteriorSubpaths2', () => E.nudgeSharedInteriorSubpaths(edges, nodeByIdMap));
    finalize('f2');
    step('liftTopLaneTitleBandsAboveRails', () => E.liftTopLaneTitleBandsAboveRails(edges, nodeByIdMap, direction));
    step('shiftLeftLaneTitleBandsLeftOfRails', () => E.shiftLeftLaneTitleBandsLeftOfRails(edges, nodeByIdMap, direction));
    step('liftTopLaneTitleBandsAboveRails2', () => E.liftTopLaneTitleBandsAboveRails(edges, nodeByIdMap, direction));
    step('shiftLeftLaneTitleBandsLeftOfRails2', () =>
      E.shiftLeftLaneTitleBandsLeftOfRails(edges, nodeByIdMap, direction));
  }
  if (wantStages) {
    return { stages };
  }
  const last = snapshot(data, 'final');
  return { nodes: last.nodes, edges: last.edges };
}

function fromSnapshot(snapshot) {
  const nodes = snapshot.nodes.map((n) => {
    const node = { ...n };
    if (n.groupTitleRect) {
      const [left, right, top, bottom] = n.groupTitleRect;
      node.groupTitleRect = { left, right, top, bottom };
    }
    return node;
  });
  const edges = snapshot.edges.map((e) => {
    const edge = { ...e };
    if (e.points) edge.points = e.points.map(([x, y]) => ({ x, y }));
    return edge;
  });
  return { nodes, edges };
}

// The steps `--run` knows: a stage name (without the `f1.` prefix and the
// trailing `2` of repeated steps) and how to run it.
function runStep(E, layout, step, direction) {
  const { nodes, edges } = layout;
  const nodeByIdMap = new Map();
  for (const n of nodes) nodeByIdMap.set(String(n.id), n);
  const steps = {
    route: () => {
      E.routeEdgesOrthogonal(layout, direction);
      for (const edge of edges) {
        if (!edge.curve || edge.curve === 'basis') edge.curve = 'rounded';
      }
    },
    direction: () => {
      if (direction === 'LR' || direction === 'RL') E.applyLrDirectionTransform(layout, direction);
      if (direction === 'BT') E.applyBtDirectionTransform(layout);
    },
    simplify: () => {
      for (const edge of edges) {
        if (edge.isLayoutOnly) continue;
        const pts = edge.points;
        if (!pts || pts.length < 2) continue;
        edge.points = E.simplifyPolyline(E.orthogonalizePolyline(pts));
      }
    },
    simplifyDetouredEdges: () => E.simplifyDetouredEdges(edges, nodes),
    straightenCollinearSiblingDetours: () => E.straightenCollinearSiblingDetours(edges, nodes),
    portSwapToLShape: () => E.portSwapToLShape(edges, nodes),
    liftTopLaneTitleBandsAboveRails: () => E.liftTopLaneTitleBandsAboveRails(edges, nodeByIdMap, direction),
    shiftLeftLaneTitleBandsLeftOfRails: () => E.shiftLeftLaneTitleBandsLeftOfRails(edges, nodeByIdMap, direction),
  };
  const run = steps[step] ?? (() => {
    if (typeof E[step] !== 'function') throw new Error(`unknown step ${step}`);
    E[step](edges, nodeByIdMap);
  });
  run();
}

function main() {
  const args = process.argv.slice(2);
  const option = (name) => {
    const i = args.indexOf(name);
    return i >= 0 ? args[i + 1] : undefined;
  };
  if (option('--from')) {
    const snapshot = JSON.parse(fs.readFileSync(option('--from'), 'utf8'));
    const layout = fromSnapshot(snapshot);
    runStep(loadEngine(), layout, option('--run'), option('--direction') ?? 'TB');
    process.stdout.write(JSON.stringify(snapshot_(layout)) + '\n');
    return;
  }
  const wantStages = args.includes('--stages');
  const files = args.filter((a) => !a.startsWith('--'));
  if (files.length !== 1) {
    console.error('usage: node scripts/swimlane_oracle.js capture.json [--stages]');
    process.exit(2);
  }
  const capture = JSON.parse(fs.readFileSync(files[0], 'utf8'));
  process.stdout.write(JSON.stringify(run(capture, wantStages)) + '\n');
}

main();
