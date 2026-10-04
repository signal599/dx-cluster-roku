#!/usr/bin/env node
// Fake DX cluster node for testing the Roku app without loading a real node.
// Replays a captured session: banner, "login: " prompt (no newline), then the
// MOTD and spot lines, then loops the spots forever with the current UTC time.
//
//   node tools/fake-node.js [options]
//
//   --port N        listen port (default 7300)
//   --delay MS      delay between spot lines (default 1000)
//   --iac           send telnet negotiation (IAC) sequences, including mid-line
//   --split         split writes at random byte boundaries
//   --bel           put BEL characters in some lines
//   --long          send an over-long announcement every 15 spots
//   --drop SECONDS  close each connection after this many seconds
//   --fixture FILE  transcript to replay (default test/fixtures/session-2026-10-04.txt)

'use strict';

const fs = require('node:fs');
const net = require('node:net');
const os = require('node:os');
const path = require('node:path');
const { parseArgs } = require('node:util');

const { values: opts } = parseArgs({
  options: {
    port: { type: 'string', default: '7300' },
    delay: { type: 'string', default: '1000' },
    iac: { type: 'boolean', default: false },
    split: { type: 'boolean', default: false },
    bel: { type: 'boolean', default: false },
    long: { type: 'boolean', default: false },
    drop: { type: 'string' },
    fixture: { type: 'string', default: path.join(__dirname, '..', 'test', 'fixtures', 'session-2026-10-04.txt') },
    help: { type: 'boolean', short: 'h', default: false },
  },
});

if (opts.help) {
  const usage = fs.readFileSync(__filename, 'utf8').split('\n').slice(1, 16);
  console.log(usage.map((l) => l.replace(/^\/\/ ?/, '')).join('\n'));
  process.exit(0);
}

const port = Number(opts.port);
const delay = Number(opts.delay);
const dropAfter = opts.drop ? Number(opts.drop) : 0;

// --- Fixture ------------------------------------------------------------------

const transcript = fs.readFileSync(opts.fixture, 'utf8').replace(/\r/g, '').split('\n');
if (transcript.at(-1) === '') transcript.pop();

const loginIndex = transcript.findIndex((l) => l.startsWith('login:'));
if (loginIndex < 0) throw new Error(`${opts.fixture}: no "login:" line`);
const banner = transcript.slice(0, loginIndex);
const afterLogin = transcript.slice(loginIndex + 1);
const motd = afterLogin.filter((l) => !l.startsWith('DX de '));
const spots = afterLogin.filter((l) => l.startsWith('DX de '));
// The callsign used in the capture, replaced with whoever logs in.
const fixtureCall = (afterLogin.join('\n').match(/^Hello (\S+),/m) || [])[1];

// --- Telnet bytes ---------------------------------------------------------------

const IAC = 255;
const NEGOTIATION = Buffer.from([
  IAC, 251, 1, //            WILL ECHO
  IAC, 253, 31, //           DO NAWS
  IAC, 250, 24, 1, IAC, 240, // SB TERMINAL-TYPE SEND SE
]);
const IAC_NOP = Buffer.from([IAC, 241]);

// --- Helpers ----------------------------------------------------------------------

const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));
const log = (msg) => console.log(`${new Date().toISOString().slice(11, 19)} ${msg}`);

function utcTimeZ() {
  const now = new Date();
  return String(now.getUTCHours()).padStart(2, '0') + String(now.getUTCMinutes()).padStart(2, '0') + 'Z';
}

function lanAddresses() {
  return Object.values(os.networkInterfaces())
    .flat()
    .filter((a) => a && a.family === 'IPv4' && !a.internal)
    .map((a) => a.address);
}

// --- Server ---------------------------------------------------------------------

const server = net.createServer((socket) => {
  const who = `${socket.remoteAddress}:${socket.remotePort}`;
  let closed = false;
  let queue = Promise.resolve();
  log(`${who} connected`);

  // Writes are queued so --split pieces never interleave.
  const send = (data) => {
    const buf = Buffer.isBuffer(data) ? data : Buffer.from(data, 'latin1');
    queue = queue.then(() => write(buf));
  };
  const sendLine = (text) => send(text + '\r\n');

  async function write(buf) {
    if (closed) return;
    if (!opts.split) {
      socket.write(buf);
      return;
    }
    for (let i = 0; i < buf.length && !closed; ) {
      const n = 1 + Math.floor(Math.random() * Math.min(16, buf.length - i));
      socket.write(buf.subarray(i, i + n));
      i += n;
      if (Math.random() < 0.2) await sleep(Math.random() * 10);
    }
  }

  async function play(call) {
    for (const line of motd) sendLine(fixtureCall ? line.replaceAll(fixtureCall, call) : line);
    for (let n = 1; !closed; n++) {
      await sleep(delay);
      if (closed) break;

      let spot = spots[(n - 1) % spots.length].slice(0, -5) + utcTimeZ();
      if (opts.bel && n % 5 === 0) spot = '\x07' + spot;
      if (opts.iac && n % 4 === 0) {
        // A telnet NOP in the middle of a line: must not show on screen.
        send(Buffer.concat([Buffer.from(spot.slice(0, 20), 'latin1'), IAC_NOP, Buffer.from(spot.slice(20) + '\r\n', 'latin1')]));
      } else {
        sendLine(spot);
      }
      if (opts.long && n % 15 === 0) {
        sendLine(`To ALL de W1AW: Fake node test announcement number ${n / 15}. This line is deliberately much longer than eighty columns so that the Roku display has to wrap it onto more than one row.`);
      }
    }
  }

  const dropTimer = dropAfter
    ? setTimeout(() => {
        log(`${who} dropping connection (--drop ${dropAfter})`);
        socket.destroy();
      }, dropAfter * 1000)
    : undefined;

  let input = '';
  let loggedIn = false;
  socket.on('data', (data) => {
    input += data.toString('latin1');
    let nl;
    while ((nl = input.indexOf('\n')) >= 0) {
      const text = input.slice(0, nl).replace(/\r/g, '').trim();
      input = input.slice(nl + 1);
      if (!loggedIn) {
        loggedIn = true;
        log(`${who} logged in as ${text || '(blank)'}`);
        play(text || 'N0CALL');
      } else {
        log(`${who} sent: ${text}`);
      }
    }
  });

  socket.on('close', () => {
    closed = true;
    clearTimeout(dropTimer);
    log(`${who} disconnected`);
  });
  socket.on('error', (err) => log(`${who} error: ${err.message}`));

  if (opts.iac) send(NEGOTIATION);
  banner.forEach(sendLine);
  send('login: ');
});

server.listen(port, () => {
  const flags = ['iac', 'split', 'bel', 'long'].filter((f) => opts[f]);
  if (dropAfter) flags.push(`drop ${dropAfter}s`);
  log(`fake node listening on port ${port}, ${spots.length} spots, ${delay} ms apart${flags.length ? ` [${flags.join(', ')}]` : ''}`);
  log(`point the Roku at: ${lanAddresses().map((a) => `${a}:${port}`).join(' or ') || '(no LAN address found)'}`);
});
