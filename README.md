# Process Monitor — Plasma 6 Widget

A panel widget for KDE Plasma 6 (Qt6/KF6) that shows a live table of your
running applications with CPU %, memory %, and a per-row Kill (SIGTERM)
button. The panel itself only shows a small tinted icon — click it to open
the popup.

Widget ID: `local.widget.precessmonitor-icon`

## Why the `executable` data engine instead of the System Monitor sensor framework

Plasma 6's System Monitor QML framework (`org.kde.plasma.private.systemmonitor`,
`org.kde.ksystemstats`) is built around **numeric sensor faces** (e.g.
`cpu/all/usage`, `memory/physical/used`) that are great for gauges/graphs, but
it does not expose a ready-made, sortable **list of individual processes** to
QML — enumerating processes as a live model is done in KSysGuard's C++
`Processes` model, which isn't reachable from a pure-QML plasmoid without
writing/bundling a custom C++ data engine plugin.

Shelling out to `ps` via `org.kde.plasma.plasma5support`'s `DataSource`
(`engine: "executable"`) is the idiomatic, low-effort Plasma 6 approach for
this: it's a single cheap fork+exec per refresh, needs no compiled plugin,
and is exactly what many maintained Plasma 6 widgets do when they need
process/command output. `kill -TERM <pid>` is issued the same way. This
keeps the whole widget pure QML/JS, installable with just
`kpackagetool6 --install`.

## Files

```
local.widget.precessmonitor-icon/
├── metadata.json                     # KPlugin metadata (Plasma 6 format)
├── contents/
│   ├── ui/
│   │   ├── main.qml                  # Applet root: data source, sorting,
│   │   │                             # kill logic, compact representation
│   │   └── FullRepresentation.qml    # Popup: sortable table + kill dialog
│   ├── config/
│   │   ├── main.xml                  # KConfigXT schema (colors, thresholds,
│   │   │                             # refresh interval, show-count toggle)
│   │   ├── config.qml                # Config page registration
│   │   └── configGeneral.qml         # Settings UI (General page)
│   └── icons/
│       └── monitor-mask.svg          # Custom solid-fill monitor glyph
```

## How it works

* **Data**: every `refreshInterval` seconds (default 3s), runs
  `ps -u $(id -u) --no-headers -eo pid,comm,%cpu,%mem --sort=-%cpu`, i.e.
  only processes owned by the logged-in user — this is what shows up as
  "applications" (your desktop apps + session helpers) rather than every
  root-owned daemon/kernel thread on the system. Output is parsed into a JS
  array and used to rebuild a `ListModel` after applying the current sort.
* **Sorting**: click any column header (PID / Name / CPU % / Mem %) to sort;
  clicking the active column again reverses direction. Defaults to CPU %,
  descending.
* **Kill**: clicking the kill icon on a row opens a `Kirigami.PromptDialog`
  confirming the process name + PID; on confirm, runs `kill -TERM <pid>`.
  Failures (e.g. `Operation not permitted` for a root-owned process) are
  shown as an inline dismissible error banner in the popup instead of
  crashing the widget.
* **Panel icon (compact representation)**: the panel shows **only** the
  icon — no text, no counter. Clicking it toggles the popup. It's a custom
  solid-fill monitor glyph (screen + stand, no waveform), rendered with
  `Kirigami.Icon { isMask: true }` so it can be tinted:
  * The color is **static** — it never changes automatically based on CPU
    load or any other system state.
  * It **is** user-changeable in Settings → General: choose Magenta
    (default), Light Gray, Coral, or Teal.
* **Popup sizing**: sized at ~30×26 grid units (comfortably 15-20 rows
  visible without excess scrolling), with sensible minimums, following
  standard Plasma popup layout conventions. No aggregate summary (app
  count / total CPU) is shown — just the sortable table.

## Install

```bash
kpackagetool6 --type Plasma/Applet --install local.widget.precessmonitor-icon
```

Or copy manually:

```bash
mkdir -p ~/.local/share/plasma/plasmoids
cp -r local.widget.precessmonitor-icon ~/.local/share/plasma/plasmoids/local.widget.precessmonitor-icon
```

To update after making changes (instead of `--install`, use `--upgrade`):

```bash
kpackagetool6 --type Plasma/Applet --upgrade local.widget.precessmonitor-icon
```

Then reload Plasma so the widget picker picks up changes:

```bash
kbuildsycoca6 --noincremental
plasmashell --replace &
```

(Alternatively, log out/in, or on Wayland use `kquitapp6 plasmashell && kstart plasmashell`.)

Add it to a panel via: right-click panel → **Add or Manage Widgets…** →
search "Process Monitor".

## Troubleshooting: popup table showed nothing

If the panel icon rendered/tinted fine but the popup table was empty, the
cause was a genuine QML bug (now fixed):

1. **Self-referencing property binding** (fixed): `main.qml` did
   `FullRepresentation { processModel: processModel }` where the outer
   `ListModel`'s `id` was *also* `processModel`. In QML, a property
   assignment's right-hand side resolves against the object's own
   properties before outer scope, so `processModel` bound to *itself*
   (the alias) instead of the real list — the table's model was always
   empty. Fixed by renaming the `ListModel`'s id to `processListModel`.
2. **Off-by-one row parsing bug** (fixed): the `ps` command used
   `--no-headers` (no header line printed), but the parser still skipped
   line 0 assuming it was a header, silently dropping the highest-CPU
   row every refresh.
3. **Dangling config alias** (fixed): `configGeneral.qml` had
   `property alias cfg_showProcessCount: showCountCheck.checked` pointing
   at a checkbox that had already been removed, which would break the
   Settings page. Removed.

If the panel icon and/or popup still appears blank/empty, also check:

1. **Stale plasmoid cache** — after copying files in manually, run
   `kbuildsycoca6 --noincremental` and restart `plasmashell` (see above); a
   plain widget-picker refresh isn't always enough.
2. **`plasma5support` not installed** — the widget checks
   `executable.valid` on startup and will show an inline error in the popup
   ("plasma5support is unavailable...") instead of failing silently if the
   `executable` data engine can't be loaded. Install `plasma5support` (Fedora/
   Nobara package `kf6-plasma5support`) if you see that message.

## Notes / limitations

* Killing a process you don't own will fail with a permission error shown
  inline in the popup — the widget itself never runs as root and does not
  attempt privilege escalation.
* `comm` (via `ps`) is used for the process name (short command name,
  ≤15 chars typically) rather than the full command line, to keep parsing
  robust and cheap; this matches "Process/application name" from the spec.
