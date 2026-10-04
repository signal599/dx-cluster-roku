# DX Cluster for Roku — Specification

Status: Draft v0.1 (2026-10-04)
Owner: Ross Keatinge, KT1F
Repository: `signal599/dx-cluster-roku`

## 1. Summary

A Roku channel (sideloaded in developer mode) that connects to an amateur radio
DX cluster node and shows its output as a full-screen "glass teletype": plain
text, new lines appear at the bottom and everything scrolls up. There are no
graphics and, for now, no user controls beyond what Roku gives every app
(Home/Back to exit).

This is a hobby project and a way to re-learn current Roku development
(BrightScript + SceneGraph).

## 2. Goals and non-goals

### Goals (v1)

- Connect over raw TCP to a DX cluster node (e.g. `nc7j.com:7300`, DXSpider).
- Log in with a callsign (`KT1F`), no password.
- Display every received line, scrolling, in a monospaced font so the spot
  columns line up.
- Keep running unattended: survive disconnects and reconnect on its own.
- Make the connection settings (host, port, callsign, login mode) easy to
  change, so the app can later point at a relay instead of a node.

### Non-goals (v1)

- Sending commands to the cluster (filters, `set/...`, posting spots).
- Settings screens or any on-screen input.
- Parsing spots into structured data, colouring, filtering, sorting.
- Publishing to the Roku Channel Store.
- The relay server (separate project, see §9).

## 3. Background: what the cluster sends

Captured from a real session (`telnet nc7j.com 7300`):

1. A banner and a `login: ` prompt (no trailing newline).
2. After the client sends the callsign, a welcome message (MOTD), then a
   prompt line such as `KT1F de NG7M-1  4-Oct-2026 2141Z dxspider >`.
3. A continuous stream of spot lines, for example:

```
DX de K7GS:      14004.0  C5R          op2                            2141Z
DX de N5YS:      14225.0  N6O          CA QSO Party: Contra Costa     2141Z
```

Spot lines are fixed-format and about 75 characters wide. Other things can
show up in the stream: announcements (`To ALL de ...`), WWV/WCY propagation
lines, talk messages, and, if enabled, RBN spots.

Protocol details that matter:

- Line endings are usually `\r\n`, but the client should accept `\n`, `\r\n`
  and `\r\n\r`.
- The server may send telnet negotiation bytes (IAC = `0xFF` followed by
  1–2 bytes, or `IAC SB ... IAC SE` subnegotiations). These must be removed
  and never displayed. The client does not need to negotiate; it ignores them.
- The server may send BEL (`0x07`) and other control characters. Strip them.
- Text is effectively ASCII. Bytes ≥ 0x80 should be shown as `?` (or dropped)
  rather than breaking the display.
- The `login:` prompt arrives without a newline, so the client must check the
  partial (not yet terminated) buffer for the prompt.

## 4. User experience

### 4.1 Launch

1. The splash screen shows briefly.
2. The terminal screen appears with a status line, e.g.
   `Connecting to nc7j.com:7300 ...`.
3. Received text starts scrolling in as soon as it arrives, including the
   banner and MOTD (the same thing you see in telnet).

### 4.2 Terminal screen

- Full screen, **green text on a black background** (classic terminal look).
  Use a phosphor green such as `#33FF33` for the text and `#000000` for the
  background. Define the colours as named constants in one place, so they can
  become a user setting later. The status line uses a dimmer or inverted green
  to set it apart.
- Monospaced font, sized for **80 columns** across a 1920-pixel-wide FHD
  layout, inside the action-safe area (1728 × 972 px). The font size is
  chosen at runtime to fit 80 columns; on the dev Roku that is size 36,
  giving 80 × 19.
- New lines are added at the bottom; the oldest line drops off the top.
- Lines longer than 80 columns wrap at the last space that fits; a word
  longer than 80 characters is split. The partial (unterminated) line is
  truncated instead of wrapped.
- Scrolling is instant (no animation) in v1.

### 4.3 Status line

One line, visually separate from the scrolling area (top or bottom, different
colour), showing:

- Connection state: `Connecting`, `Connected`, `Disconnected — retrying in Ns`,
  `Error: <message>`.
- Host and port.
- Current UTC time (`HHMMZ`), since spot times are in UTC.

### 4.4 Remote control

- **Back**: exits the app (normal Roku behaviour).
- **Home**: Roku handles it.
- All other keys are ignored in v1.

## 5. Functional requirements

| ID | Requirement |
|----|-------------|
| F1 | Open a TCP connection to the configured host and port. |
| F2 | In `telnet-login` mode, when `login:` is seen in the incoming buffer, send `<callsign>\r\n` once per connection. The server does not echo, so complete the prompt line locally as `login: <callsign>`, as telnet does. |
| F3 | In `raw` mode (for the future relay), send nothing and just display what arrives. |
| F4 | Split the incoming bytes into lines, removing telnet IAC sequences and control characters. |
| F5 | Display every complete line. Show the pending partial line (e.g. `login: `) as the bottom line until it is completed. |
| F6 | Keep a scrollback buffer of the last N lines (N = visible rows; a larger buffer is optional in v1). |
| F7 | When the connection drops or fails, show it in the status line and reconnect with backoff (5 s, 10 s, 20 s ... capped at 60 s). Reset the backoff after a connection that lasted longer than 60 s. |
| F8 | Write a short marker line into the scrolling area on connect and disconnect (e.g. `*** Connected to nc7j.com:7300 ***`) so gaps are visible. |
| F9 | Show the UTC clock in the status line, updated every minute (or every second). |
| F10 | Log connection events and errors to the BrightScript debug console (port 8085). |

## 6. Non-functional requirements

- **Runs unattended for hours.** No unbounded memory growth: line buffers are
  capped and partial-line buffers have a size limit (e.g. 4 KB, then force a
  line break).
- **The UI never blocks.** All network I/O happens off the render thread.
- **Polite to the node.** One connection at a time; never reconnect faster than
  the backoff allows; never connect more than once from a single app instance.
- **Target platform.** Any current Roku OS device; FHD (1920×1080) UI
  resolution, which the OS scales on HD devices.

## 7. Technical design

### 7.1 Platform notes

- Language: BrightScript, with the UI in SceneGraph (XML components +
  `.brs`).
- Raw TCP: `roStreamSocket` + `roSocketAddress`, driven by a `roMessagePort`
  and `roSocketEvent`s. Socket work must run in a SceneGraph **Task** node,
  because the render thread must not do blocking I/O.
- Fonts: Roku's built-in system fonts are proportional, so a monospaced
  TrueType font is bundled in the package (`pkg:/fonts/`) and used through a
  `Font` node with `uri`. Use a freely licensed font, such as JetBrains Mono,
  IBM Plex Mono or DejaVu Sans Mono, and include its licence file.
- Check all of the above against the current Roku developer docs when
  implementing; APIs and manifest requirements may have changed since the
  earlier prototype.

### 7.2 Components

```
main.brs            Creates roSGScreen, shows MainScene, runs the event loop
                    until the screen closes.

MainScene (Scene)   Owns the layout: status line + terminal view.
                    Creates and starts ClusterTask, observes its fields,
                    updates the display. Handles the clock Timer.

TerminalView        A Group containing a fixed pool of Label nodes, one per
  (Group)           visible row. Holds a ring buffer of line strings.
                    appendLines(lines) shifts the text up and redraws the
                    rows. One Label per row keeps per-line colouring
                    simple later.

ClusterTask (Task)  Connects, reads, decodes, logs in, reconnects.
                    Pushes results to the scene through interface fields.
```

### 7.3 ClusterTask interface

Inputs (set by the scene before `control = "RUN"`):

| Field | Type | Example |
|-------|------|---------|
| `host` | string | `nc7j.com` |
| `port` | integer | `7300` |
| `callsign` | string | `KT1F` |
| `mode` | string | `telnet-login` or `raw` |

Outputs (observed by the scene):

| Field | Type | Meaning |
|-------|------|---------|
| `lines` | array of strings | Batch of new complete lines. Set once per socket read so rapid traffic is not lost to per-field-set overhead. |
| `partial` | string | Current unterminated text (e.g. `login: `), or `""`. |
| `status` | string | `connecting`, `connected`, `disconnected`, `error`. |
| `statusText` | string | Human-readable detail for the status line. |

### 7.4 ClusterTask loop (outline)

```
loop forever:
    status = connecting
    open socket (non-blocking connect, ~15 s timeout)
    if failed: status = error, wait backoff, continue
    status = connected; loggedIn = false
    while connected:
        wait on port for roSocketEvent (timeout ~1 s)
        read available bytes into roByteArray
        if 0 bytes read on a readable event -> remote closed; break
        decoder.feed(bytes) -> completeLines, partial
        if mode = telnet-login and not loggedIn and partial/lines contain "login:":
            send callsign + CR LF; loggedIn = true
        if completeLines not empty: m.top.lines = completeLines
        m.top.partial = partial
    close socket; status = disconnected; wait backoff
```

### 7.5 Decoder (pure function, easy to unit test)

A small state machine over bytes:

- States: `DATA`, `IAC`, `IAC_OPT` (after WILL/WONT/DO/DONT), `SB`, `SB_IAC`.
- `IAC IAC` → literal `0xFF` (then replaced with `?`).
- In `DATA`: `\n` ends a line; `\r` is ignored; `\t` is expanded to spaces
  (8-column tab stops); other bytes < 0x20 and `0x7F` are dropped; bytes
  ≥ 0x80 become `?`.
- Keeps decoder state between reads, because an IAC sequence or a line can be
  split across two reads.

### 7.6 Configuration

The connection settings are **not hard-coded and not committed**. They live
in a git-ignored `.env` file at the repo root. The deploy script puts them into
the package at build time.

`.env` (git-ignored; a committed `.env.example` shows the keys with
placeholder values):

```sh
# Cluster connection (baked into the package at build time)
CLUSTER_HOST=nc7j.com
CLUSTER_PORT=7300
CLUSTER_CALLSIGN=KT1F
CLUSTER_MODE=telnet-login      # or: raw

# Dev Roku (used by deploy.sh only; never packaged)
ROKU_IP=192.168.x.x
ROKU_PASSWORD=...
```

How it gets into the app:

- `deploy.sh` copies `app/` to a staging directory (`build/stage/`). It writes
  `build/stage/config.json` from the `CLUSTER_*` values and zips the staging
  directory. The `app/` source tree never contains the real values.
- Only `CLUSTER_*` keys are written into the package. `ROKU_*` keys never are.
- At startup the app reads the file with
  `ParseJson(ReadAsciiFile("pkg:/config.json"))`:

```json
{ "host": "nc7j.com", "port": 7300, "callsign": "KT1F", "mode": "telnet-login" }
```

- If `config.json` is missing or invalid, or `host`/`port` are empty, the
  status line shows `Error: no configuration — build with tools/deploy.sh` and
  the app does not try to connect.
- The script fails with a clear message if `.env` is missing or a required
  `CLUSTER_*` key is empty. In `telnet-login` mode the callsign is required; in
  `raw` mode it is not.
- Environment variables that are already set override `.env`, so a one-off
  build can do `CLUSTER_HOST=localhost tools/deploy.sh` (for example, to point
  at the fake node).

Note: the values are still in plain text inside the `.zip` and on the device.
This keeps them out of git; it does not make them secret. That is fine for a
callsign and hostname.

Later: allow overrides from `roRegistrySection` with a simple settings screen,
and point the defaults at the relay.

## 8. Project layout and tooling

```
dx-cluster/
├── README.md
├── .env.example                # committed template
├── .env                        # git-ignored: cluster + Roku settings
├── .gitignore                  # .env, build/, out/
├── docs/
│   └── SPEC.md
├── app/                        # Everything here gets zipped and sideloaded
│   ├── manifest
│   ├── source/
│   │   ├── main.brs
│   │   ├── config.brs          # loads pkg:/config.json
│   │   └── theme.brs           # colour constants
│   ├── components/
│   │   ├── MainScene.xml / .brs
│   │   ├── TerminalView.xml / .brs
│   │   ├── ClusterTask.xml / .brs
│   │   └── TelnetDecoder.brs
│   ├── fonts/
│   │   ├── <Mono>-Regular.ttf
│   │   └── OFL.txt (or the font's licence)
│   └── images/                 # channel icons + splash (generated)
├── build/                      # git-ignored staging dir (app/ + config.json)
├── out/                        # git-ignored built zip
├── tools/
│   ├── deploy.sh               # stage, inject config, zip, install on the dev Roku
│   ├── make-images.py          # generates app/images/ (no dependencies)
│   └── fake-node.js            # local test server (see below)
└── test/
    └── fixtures/session-2026-10-04.txt   # the captured telnet session
```

### 8.1 Manifest (starting point)

```
title=DX Cluster
major_version=0
minor_version=1
build_version=1
rsg_version=1.3
ui_resolutions=fhd
mm_icon_focus_hd=pkg:/images/icon_hd.png
mm_icon_focus_fhd=pkg:/images/icon_fhd.png
splash_screen_sd=pkg:/images/splash_sd.png
splash_screen_hd=pkg:/images/splash_hd.png
splash_screen_fhd=pkg:/images/splash_fhd.png
splash_color=#000000
splash_min_time=500
```

Image sizes: icons 290×218 (HD) and 540×405 (FHD); splash screens 720×480
(SD), 1280×720 (HD) and 1920×1080 (FHD). Roku requires `rsg_version=1.3` for
certification from 1 October 2026.

### 8.2 Deploy script

`tools/deploy.sh`:

- Loads `.env` (environment variables already set take precedence) and checks
  the required keys.
- Copies `app/` to `build/stage/`, writes `build/stage/config.json` (see §7.6),
  and zips the contents of the staging directory (not the folder itself) into
  `out/dx-cluster.zip`.
- Has a `--package-only` flag that builds the zip without installing it.
- POSTs the zip to `http://$ROKU_IP/plugin_install` using digest auth (user
  `rokudev`, password from `$ROKU_PASSWORD`), with `mysubmit=Install`.
- Reads `ROKU_IP` and `ROKU_PASSWORD` from the same `.env`. **Never commit
  `.env`.**

The debug console is reached with `telnet $ROKU_IP 8085`.

### 8.3 Fake node for local testing

`tools/fake-node.js` (Node.js, no dependencies) listens on a local port (e.g.
7300) and:

1. Sends a banner and `login: ` with no newline.
2. Waits for a line, then plays back the fixture file (MOTD plus spots) with a
   configurable delay per line.
3. Options for robustness tests: insert telnet IAC sequences, split writes at
   random byte boundaries, send BEL characters, send very long lines, and drop
   the connection after N seconds.

Point the app at the Mac's LAN IP to test reconnect and decoding without
loading the real node. This also gives the relay project a head start.

## 9. Future: relay server (separate project)

Expected shape, so the Roku app is ready for it:

- Node.js service holding **one** telnet session to the upstream node under the
  owner's callsign, and fanning lines out to many Roku clients.
- Easiest for the Roku app: the relay speaks plain TCP, one line per `\n`, with
  no login. That is the `mode = "raw"` path, and no code changes are needed.
- Possible additions: send the last N lines to a client when it connects
  (so the screen fills straight away), a heartbeat line, and per-client
  filtering.
- Using HTTP/WebSocket instead would need a different transport in the Roku
  app, so stay with raw TCP unless there is a reason to change.
- The upstream node's rules ("Radio Amateurs using their real callsigns") will
  affect how a public relay identifies itself and its users. Decide this
  before releasing to others.

## 10. Milestones

| # | Milestone | Done when |
|---|-----------|-----------|
| M0 | Toolchain | `app/` skeleton with manifest, icons, empty scene; `.gitignore` and `.env.example`; `deploy.sh` injects `config.json` and installs; debug console logs the loaded config. |
| M1 | Glass teletype | TerminalView with the monospaced font, fed by a Timer that adds a fake spot line every second; it scrolls correctly and the columns line up. |
| M2 | Socket task | ClusterTask connects to `fake-node.js`, logs in, and lines appear on screen. |
| M3 | Real node | Connects to `nc7j.com:7300`, logs in as KT1F, displays the live stream. |
| M4 | Robustness | IAC/control-character stripping verified with the fake node; reconnect with backoff; status line and UTC clock; runs overnight without problems. |
| M5 | Relay-ready | `raw` mode tested against a fake relay by switching `CLUSTER_MODE`/`CLUSTER_HOST` in `.env`. |

## 11. Future enhancements (backlog)

- Colour by type: spots, announcements, WWV, talk, and highlighting of chosen
  callsigns, bands or DXCC entities.
- Parse spot lines into fields; show band/mode columns; frequency → band.
- A settings screen (host, callsign, colour scheme such as green / amber /
  grey, font size) stored in the
  registry.
- Scrollback with the Up/Down keys; pause with OK.
- Send DXSpider commands on login (`set/wantrbn`, filters) from configuration.
- Channel Store release (needs the relay, privacy/terms review, and Roku
  certification requirements such as deep linking and screensaver behaviour).

## 12. Open questions and risks

### Open

1. **Field-update throughput.** Check that batching lines per read (§7.3)
   keeps up during contest-weekend spot bursts.
2. **Font sizing on 720p.** FHD is settled (size 36, 80 × 19); check
   readability on a 720p device.
3. **Partial-line display.** Showing the unterminated `login:` prompt is
   faithful to telnet but optional. Keep it or drop it?

### Deferred / decided (2026-10-04)

- **Screensaver / idle sleep:** deferred. A passive, non-video app may trigger
  the Roku screensaver or power-saving standby. Do nothing now; look into it
  if it turns out to be a problem in use.
- **Idle disconnects / keepalive:** deferred to the relay project. v1 relies
  on the reconnect-with-backoff logic (F7) if a connection is dropped.
- **Colour scheme:** decided: green on black (§4.2). Other schemes are a
  future user setting (§11).
