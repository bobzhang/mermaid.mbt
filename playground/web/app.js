import { examples } from './examples.js';

const $ = (id) => document.getElementById(id);
const code = $('code');
const configBox = $('config');
const exampleSelect = $('example');
const themeSelect = $('theme');
const lookSelect = $('look');
const compareBox = $('compare');
const status = $('status');
const identical = $('identical');
const portView = $('port');
const upstreamView = $('upstream');
const upstreamFigure = $('upstream-figure');

const SVG_ID = 'mermaid-svg';

let latestSvg = '';
let seq = 0;

// --- state in the URL: #s=<base64url of {t, c, theme, look}> ---

function encodeState(state) {
  const bytes = new TextEncoder().encode(JSON.stringify(state));
  let binary = '';
  for (const b of bytes) binary += String.fromCharCode(b);
  return btoa(binary).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

function decodeState(text) {
  try {
    const binary = atob(text.replace(/-/g, '+').replace(/_/g, '/'));
    const bytes = Uint8Array.from(binary, (c) => c.charCodeAt(0));
    return JSON.parse(new TextDecoder().decode(bytes));
  } catch {
    return null;
  }
}

function currentState() {
  return { t: code.value, c: configBox.value, theme: themeSelect.value, look: lookSelect.value };
}

function applyState(state) {
  code.value = state.t ?? '';
  configBox.value = state.c ?? '';
  themeSelect.value = state.theme ?? '';
  lookSelect.value = state.look ?? '';
}

// --- configuration: the JSON box, with the theme and look pickers on top ---

function siteConfig() {
  let config = {};
  const raw = configBox.value.trim();
  if (raw) {
    try {
      config = JSON.parse(raw);
    } catch {
      return { error: 'The configuration is not valid JSON.' };
    }
  }
  if (themeSelect.value) config.theme = themeSelect.value;
  if (lookSelect.value) {
    config.look = lookSelect.value;
    // rough.js is random without a seed, upstream included
    if (lookSelect.value === 'handDrawn' && config.handDrawnSeed === undefined) config.handDrawnSeed = 1;
  }
  return { config };
}

// --- rendering ---

const worker = new Worker(new URL('./worker.js', import.meta.url), { type: 'module' });

worker.onmessage = (event) => {
  const result = event.data;
  if (result.seq !== seq) return; // a newer render is on its way
  if (result.svg !== undefined) {
    latestSvg = result.svg;
    portView.innerHTML = result.svg;
    setStatus(`Rendered in ${result.ms.toFixed(1)} ms`);
  } else {
    latestSvg = '';
    setStatus(describe(result), true);
  }
  compareWithUpstream(result.svg);
};

function describe(result) {
  const prefix = {
    unknown: 'No diagram type matches the text',
    syntax: 'Syntax error',
    config: 'Configuration error',
    unsupported: 'Not supported by the port',
    render: 'Rendering failed (as in mermaid)',
    crash: 'The renderer crashed',
  }[result.kind] ?? 'Error';
  return `${prefix}: ${result.error}`;
}

function setStatus(text, isError = false) {
  status.textContent = text;
  status.className = isError ? 'error' : '';
}

let timer = 0;
function scheduleRender() {
  clearTimeout(timer);
  timer = setTimeout(render, 150);
}

function render() {
  const { config, error } = siteConfig();
  seq += 1;
  if (error) {
    setStatus(error, true);
    return;
  }
  setStatus('Rendering…');
  worker.postMessage({ seq, text: code.value, config: JSON.stringify(config), id: SVG_ID });
  history.replaceState(null, '', '#s=' + encodeState(currentState()));
}

// --- side by side with mermaid.js ---

// mermaid.js runs in a blank frame the size of the reference page
// (upstream.html), so that this page's styles do not change what it measures.
// Each render gets a fresh frame, as the reference does: some diagrams
// (sequence, class, sankey, C4) count ids over the lifetime of a page.
let frame = null;

function renderUpstream(text, config) {
  frame?.remove();
  const current = document.createElement('iframe');
  frame = current;
  current.src = 'upstream.html';
  current.title = 'mermaid.js';
  current.setAttribute('aria-hidden', 'true');
  current.style.cssText = 'position:absolute;left:-10000px;top:0;width:756px;height:469px;border:0;';
  return new Promise((resolve) => {
    const listen = (event) => {
      if (event.source !== current.contentWindow) return;
      if (event.data.ready) {
        current.contentWindow.postMessage({ seq: 0, text, config, id: SVG_ID }, '*');
        return;
      }
      window.removeEventListener('message', listen);
      resolve(event.data);
    };
    window.addEventListener('message', listen);
    document.body.append(current);
  });
}

async function compareWithUpstream(portSvg) {
  identical.textContent = '';
  upstreamFigure.hidden = !compareBox.checked;
  if (!compareBox.checked) return;
  const mine = seq;
  if (!upstreamView.firstChild) upstreamView.textContent = 'Loading mermaid.js…';
  const { config } = siteConfig();
  const result = await renderUpstream(code.value, config ?? {});
  if (mine !== seq) return;
  if (result.svg !== undefined) {
    upstreamView.innerHTML = result.svg;
    if (portSvg !== undefined) {
      const same = result.svg === portSvg;
      identical.textContent = same
        ? '· byte-identical to mermaid.js'
        : '· differs from mermaid.js in this browser (the port reproduces headless Chrome on macOS at a pixel ratio of 1: other browsers, fonts and high-DPI screens change what mermaid measures and how d3 draws axes, and rough.js shapes are random without handDrawnSeed)';
      identical.className = same ? 'ok' : 'bad';
    }
  } else {
    upstreamView.textContent = 'mermaid.js: ' + result.error;
    identical.textContent = portSvg === undefined ? '· mermaid.js fails as well' : '';
    identical.className = portSvg === undefined ? 'ok' : '';
  }
}

// --- buttons ---

$('share').onclick = async () => {
  render();
  await navigator.clipboard.writeText(location.href);
  flash($('share'), 'Copied');
};

$('copysvg').onclick = async () => {
  if (!latestSvg) return;
  await navigator.clipboard.writeText(latestSvg);
  flash($('copysvg'), 'Copied');
};

$('download').onclick = () => {
  if (!latestSvg) return;
  const blob = new Blob([latestSvg], { type: 'image/svg+xml' });
  const link = document.createElement('a');
  link.href = URL.createObjectURL(blob);
  link.download = 'diagram.svg';
  link.click();
  URL.revokeObjectURL(link.href);
};

function flash(button, text) {
  const old = button.textContent;
  button.textContent = text;
  setTimeout(() => (button.textContent = old), 1200);
}

// --- start ---

for (const [index, example] of examples.entries()) {
  exampleSelect.add(new Option(example.name, String(index)));
}

exampleSelect.onchange = () => {
  code.value = examples[Number(exampleSelect.value)].text;
  render();
};

code.addEventListener('input', scheduleRender);
configBox.addEventListener('input', scheduleRender);
themeSelect.onchange = render;
lookSelect.onchange = render;
compareBox.onchange = () => compareWithUpstream(latestSvg || undefined);

code.addEventListener('keydown', (event) => {
  if (event.key === 'Tab' && !event.shiftKey) {
    event.preventDefault();
    code.setRangeText('  ', code.selectionStart, code.selectionEnd, 'end');
    scheduleRender();
  }
});

const fromUrl = location.hash.startsWith('#s=') ? decodeState(location.hash.slice(3)) : null;
if (fromUrl) {
  applyState(fromUrl);
  exampleSelect.value = '';
} else {
  code.value = examples[0].text;
}
render();
