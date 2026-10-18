// Renders off the main thread, so a large diagram never freezes the editor.
import { render_svg } from './mermaid-port.js';

self.onmessage = (event) => {
  const { seq, text, config, id } = event.data;
  const start = performance.now();
  let result;
  try {
    result = JSON.parse(render_svg(text, config, id));
  } catch (error) {
    result = { error: String(error && error.message || error), kind: 'crash' };
  }
  result.ms = performance.now() - start;
  self.postMessage({ seq, ...result });
};
