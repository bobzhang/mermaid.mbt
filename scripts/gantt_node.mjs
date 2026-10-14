#!/usr/bin/env node
// Evaluate dayjs and d3 time operations with the very code mermaid bundles:
// the reference for internal/dayjs and the time parts of internal/d3.
//
// The libraries are imported from the chunks of the mermaid bundle that
// scripts/oracle.py uses (dayjs with the plugins the Gantt chart loads).
// They are pure JavaScript on top of `Date`, which scripts/check_dates.py
// checks against Chrome separately; Node must run in the reference time
// zone (TZ=Asia/Shanghai is set by scripts/check_time.py).
//
// Usage: node scripts/gantt_node.mjs cases.json   (prints a JSON array)

import fs from 'node:fs';
import path from 'node:path';
import url from 'node:url';

// "Now" is whatever a case says it is.
const RealDate = Date;
let now = 0;
function FakeDate(...args) {
  if (!new.target) return new RealDate(now).toString();
  return args.length === 0 ? new RealDate(now) : new RealDate(...args);
}
FakeDate.prototype = RealDate.prototype;
FakeDate.now = () => now;
FakeDate.UTC = RealDate.UTC;
FakeDate.parse = RealDate.parse;
globalThis.Date = FakeDate;

const here = path.dirname(url.fileURLToPath(import.meta.url));
const chunks = path.resolve(here, '..', '.repos', 'oracle', 'package', 'dist', 'chunks', 'mermaid.esm');
const find = (pattern) => path.join(chunks, fs.readdirSync(chunks).find((name) => pattern.test(name)));
// Importing the Gantt chunk extends dayjs with its plugins.
await import(find(/^ganttDiagram-.*\.mjs$/));
const d3 = await import(fs.readdirSync(chunks)
  .map((name) => path.join(chunks, name))
  .find((file) => file.endsWith('.mjs') && fs.readFileSync(file, 'utf8').includes('dayjs.min.js"(exports, module)')));
const dayjs = d3.require_dayjs_min();

const clean = (value) => (typeof value === 'number' && Number.isNaN(value) ? null : value);
const date = (time) => new RealDate(time === null ? NaN : time);
const intervals = {
  millisecond: d3.millisecond, second: d3.second, minute: d3.timeMinute, hour: d3.timeHour, day: d3.timeDay,
  month: d3.timeMonth, sunday: d3.timeSunday, monday: d3.timeMonday, tuesday: d3.timeTuesday,
  wednesday: d3.timeWednesday, thursday: d3.timeThursday, friday: d3.timeFriday, saturday: d3.timeSaturday,
};

function evaluate(c) {
  now = c.now ?? 0;
  switch (c.op) {
    case 'parse':
      return clean(dayjs(c.text, c.format, true).valueOf());
    case 'format':
      return dayjs(date(c.time)).format(c.format);
    case 'add':
      return clean(dayjs(date(c.time)).add(c.amount, c.unit).valueOf());
    case 'startOfDay':
      return clean(dayjs(date(c.time)).startOf('day').valueOf());
    case 'endOfDay':
      return clean(dayjs(date(c.time)).endOf('day').valueOf());
    case 'diffYears':
      return clean(dayjs(date(c.a)).diff(dayjs(date(c.b)), 'year'));
    case 'isoWeekday':
      return clean(dayjs(date(c.time)).isoWeekday());
    case 'duration':
      return clean(dayjs.duration({ [c.unit]: c.amount }).asMilliseconds());
    case 'ticks': {
      const scale = d3.time().domain([date(c.start), date(c.stop)]);
      const interval = c.interval ? intervals[c.interval[0]].every(c.interval[1]) : undefined;
      return (interval ? scale.ticks(interval) : scale.ticks()).map((tick) => +tick);
    }
    case 'timeFormat':
      return String(d3.timeFormat(c.specifier)(date(c.time)));
    case 'scale': {
      const scale = d3.time().domain([date(c.domain[0]), date(c.domain[1])]).rangeRound(c.range);
      return c.values.map((value) => clean(scale(date(value))));
    }
    default:
      throw new Error(`unknown op ${c.op}`);
  }
}

const results = JSON.parse(fs.readFileSync(process.argv[2], 'utf8')).map((c) => {
  try {
    return evaluate(c);
  } catch (error) {
    return { error: String(error && error.message || error) };
  }
});
console.log(JSON.stringify(results));
