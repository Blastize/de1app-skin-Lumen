# Changelog — Lumen

## 0.17.0 — Curve opens from the grind tile — TABLET-VERIFIED 2026-08-02

**Safety status: unchanged.** Still exactly three settings written, each only
on an explicit tap (`lumen_theme`, `live_graph_smoothing_technique`,
`grinder_dose_weight`). No database is opened and no file in `history/` or
`history_v2/` is written, renamed or deleted. The new control calls
GrindAdvisor's own read-only viewer and writes nothing.

A **Curve** control sits on the grind tile's bottom row, one `lg` gap left of
**Shot analysis**, and opens GrindAdvisor's Calibration Curve directly —
scatter, fitted line, residuals and the labelled grind axis — without the
after-shot popup having to be on screen first. Its Back button lands on the
normal popup.

It calls `::plugins::GrindAdvisor::show_calibration_curve`, the public entry
point added in GrindAdvisor v3.3.0 for exactly this, rather than reaching into
the overlay internals. On an older GrindAdvisor that proc is absent, so
`::lumen::act::grind_curve` logs a NOTICE and falls back to the result popup —
a control that quietly does the wrong thing is worse than one that says why.

### Tap targets

The tile used to be one full-tile tap. It is now **carved into three
rectangles around the Curve target**, per the design-system rule that no two
tap targets may overlap:

* A — the whole tile above the bottom row (16..184 design px)
* B — bottom row left of Curve (184..506)
* C — bottom row right of Curve (596..744)
* Curve — 506..596, y 190..252 (90x62 design px)

All three still open the result popup, so every part of the tile that used to
respond still does, and the four rectangles are contiguous with no overlap.

## 0.16.0 — method chip shows the first two shots; scale readout reconnects

Two fixes reported from the tablet.

**Safety status: no new write behaviour.** Still exactly three settings
written, each only on an explicit tap (`lumen_theme`,
`live_graph_smoothing_technique`, `grinder_dose_weight`). No database is
opened and no file in `history/` or `history_v2/` is written, renamed or
deleted. The scale reconnect calls the app's own `ble_connect_to_scale` and
resets one in-memory `::de1()` counter — nothing is persisted.

### Fixed: the grind method chip was blank for the first two shots of a bag

`::lumen::data::grind_method` mapped only `regression` and
`regression_fallback`. GrindAdvisor v3's ladder actually has **four** rungs
(`plugins/GrindAdvisor/GrindAdvisor.tcl:1441`): `first_shot` at n=1,
`two_shot` at n=2, `regression` at n>=3, and `regression_fallback` when the
fitted slope is too flat to solve. Shots 1 and 2 fell through to `return ""`,
so the chip rendered empty exactly when a new bag was being dialled in.

All four rungs are now mapped, shortened to fit the 150px chip: **First
shot**, **2-shot**, **Regression**, **Pairwise**. An unrecognised rung from a
future GrindAdvisor is shown verbatim (ellipsised at 16 chars) rather than
blanking the chip again. The Why? popup still carries GrindAdvisor's own
longer wording.

### Fixed: the scale readout looked random, with no way to reconnect

**The skin was missing an affordance every other skin has.** Insight
(`skin.tcl:904`), DSx, DSx2, Streamline (`skin.tcl:696`) and SWDark4 all make
their weight display tappable to force a scale reconnect. Lumen's readout was
a dead zone, so once the app stopped trying there was nothing to tap.

Why that matters — read from `de1app-core`, not assumed. On each scale
disconnect, `scale_disconnect_handler` (`de1_comms.tcl:587`) calls
`ble_connect_to_scale` up to `scale_max_connection_retry_attempts` (20,
`machine.tcl:40`) times, roughly 10 seconds apart. After the 20th it runs
only `after 300000 "set ::de1(bluetooth_scale_connection_attempts_tried) 0"`
— it resets the counter and **never retries**. Also,
`bluetooth_connect_to_devices` has its scale branch commented out
(`bluetooth.tcl:1880`), and the startup BLE scanner is stopped after 10
seconds (`stop_scanner`). So a scale switched on more than ~3.5 minutes after
it dropped is not reconnected by anything until the DE1 leaves Sleep
(`binary.tcl:1637`) or an espresso starts (`binary.tcl:1608`) — which is why
it felt inconsistent and random, and why detouring through the settings page
appeared to fix it.

Confirmed against the tablet log for 2026-07-31: connect succeeded on attempt
7 at 16:44:36, the scale watchdog timed out at 16:49:39, and the 10-second
retry cycle then ran on with nothing else able to intervene.

Two changes, both in the skin:

* **The readout is now a tap target.** Tapping it runs
  `::lumen::act::reconnect_scale`, copied verbatim from Insight: clear
  `::de1(bluetooth_scale_connection_attempts_tried)`, then
  `ble_connect_to_scale`. The counter must be cleared first or the 20 spent
  attempts stay spent. Errors are logged, never swallowed. It sits inside the
  readout box only — the bean-identity target above stops at `scale_y - xs`
  and Set dose starts at 710 against the readout's right edge at 694, so no
  two tap targets overlap.
* **The readout states which of three things is true**, instead of collapsing
  two of them into "no scale": `no scale` when no scale is paired at all,
  `Connecting` while a `ble connect` is genuinely in flight
  (`::currently_connecting_scale_handle`), and `Connect` when a scale is
  paired but disconnected — which is also the hint that the box is tappable.

## 0.15.0 — Done restarts the app when the theme changed

Switching Dark/Light and tapping **Done** now quits the app through the app's
own restart-on-skin-change path, instead of leaving a note asking you to
restart it yourself. **Tablet-verified: the theme switches and the app quits.**

**The app does not reopen by itself** — you relaunch it, and it comes up in
the new theme. See "Why it cannot reopen itself" below.

**Safety status: unchanged.** Still exactly three settings written, each only
on an explicit tap (`lumen_theme`, `live_graph_smoothing_technique`,
`grinder_dose_weight`). No database is opened and no file in `history/` or
`history_v2/` is written, renamed or deleted. The restart path adds one
`save_settings` — the same call the toggle already made — and no new write.

### How

`::lumen::act::restart_for_theme` copies the app's own restart-on-skin-change
sequence verbatim from `skins/default/de1_skin_settings.tcl:65-71`: set the
stock message page's text, `set_next_page off message`, `page_show message`,
then `after 200 app_exit`. That is what the app does when you change skin,
language or orientation, so this behaves exactly like picking a different
skin.

### Why it cannot reopen itself

Measured on the target tablet (Samsung Tab A9, Android 16 / SDK 36), not
assumed:

- `exec am start -n tk.tcl.wish/.AndroWishLauncher` from the app's own uid
  throws `SecurityException: package=com.android.shell does not belong to
  uid=10260`. The `am` shell command hardcodes its calling package, and the
  platform asserts that package belongs to the caller — so this fails before
  Android's background-activity-start rules are even reached. Granting
  "display over other apps" would not change it.
- `borg activity` uses the app's real context and would be allowed, but it
  starts the activity in the very process that `app_exit` then kills.
- A relaunch therefore has to come from a process that outlives the app, and
  the only one the app can spawn is a shell child running `am` — see above.

The stock skin-change path has the same limitation, which is why the app's
own message reads "please quit and restart" rather than promising a restart.

No custom exit or relaunch machinery was written. `app_exit` already closes
BLE cleanly, forces the USB charger back on and closes the log files;
anything hand-rolled would skip that.

`::lumen::act::close_settings` restarts only when `pending_theme` is set
**and** differs from the loaded `theme_mode` — so toggling twice back to the
theme you started in just returns home, with no pointless restart. The
message page failing is logged, never swallowed, and the exit still happens.

### Changed

- `::lumen::data::theme_note` now says the app restarts to apply the change,
  and once a change is pending, "Tap Done and the app will restart."

---

## 0.13.0 — the last shot loads at startup

The home chart is no longer blank until you pull a shot. **Tablet-verified.**

**Safety status: unchanged.** Three settings written, each only on an
explicit tap (`live_graph_smoothing_technique`, `lumen_theme`,
`grinder_dose_weight`). This version adds a **read** of one history file and
writes nothing.

### Added

- `::lumen::load_last_shot_curves` — finds the newest `history/*.shot`,
  reads it, and fills the chart vectors. Deferred 5s after load because the
  BLT vectors are created during app setup, which has not finished while the
  skin is being sourced. Skips entirely if a shot is already running.

Two of the vectors are **derived**, because the app scales them at capture
time and does not store the scaled forms:
`espresso_weight_chartable` = `0.10 * espresso_weight`, and
`espresso_temperature_basket10th` = `espresso_temperature_basket / 10`.

### The trap in the proc this was adapted from

`preview_history` (`vars.tcl`) loads the same vectors, but also does
`array set ::settings $props(settings)` — which would replace the entire
current configuration (grinder, dose, profile) with whatever was saved in
that old shot, on every launch. Only the vector half was taken, and the test
asserts `::settings` is untouched.

---

## 0.12.4 — long bean names no longer wrap into the line below

The brand is drawn at 40px in a 272px column with `-width`, so a longer name
wrapped and its second line landed on top of the type/roast line beneath.
Now truncated to 13 characters, which is what fits one line.

Auto-scaling the font was considered and rejected: a canvas item's font is
fixed at creation, so fitting a runtime value means measuring and
re-configuring on every refresh tick, and a name that renders at a different
size each session breaks the fixed type scale the rest of the layout is
built on.

---

## 0.12.3 — chart panel flat and padded, scale readout centred

- **Chart panel rendered flat** (new per-panel `flat` flag in the generator).
  A BLT graph is an opaque Tk widget taking one solid background colour;
  against a gradient panel that matches at exactly one height and reads as a
  box cut into the panel everywhere else. A flat panel lets it match exactly.
  `chart_bg` re-sampled: `#141517` dark, `#DDE0E4` light.
- **`plotpadx 18 / plotpady 8`** on both charts. With zero padding BLT
  centres the outermost tick label on its tick, so it hung off the plot edge
  and was clipped.
- **Scale readout text centred** on its box. It had been nudged +14px to
  clear the Bluetooth icon, which threw "no scale" off centre exactly when
  it was the only thing showing.
- `::lumen::version` corrected to match the archive; 0.12.1 and 0.12.2 had
  bumped the header comment and archive name but not the constant.

---


## 0.6.0 — Pass 3b: depth

The skin read flat next to the design mockup. This adds back the depth cues
the mockup had, all built from stacked solid shapes in interpolated colours —
Tk canvas has neither gradients nor alpha. Everything is drawn once at page
build, so there is no runtime cost.

**Safety status: unchanged** — one setting written
(`live_graph_smoothing_technique`), no database, no history files.

### Added

- `::lumen::mix` — linear interpolation between two `#RRGGBB` colours.
- `::lumen::paint_backdrop` — a 32-band vertical gradient wash plus a warm
  crema bloom built from 14 concentric ovals. Bands overlap by a pixel so no
  seam shows. Applied to the home page (bloom behind the grind tile) and all
  four flow pages (bloom behind the timer).
- **Soft drop shadows** on every glass panel: four concentric rounded rects
  behind it, spreading outward and offset slightly down, each closer to the
  page tone than the last.
- New palette tokens for both themes: `bg_top`, `bg_bot`, `shadow`, `bloom`.

### Deliberately not done

A gradient *inside* each panel. Bands clipped to a rounded rectangle need
either clipping — which Tk canvas does not have — or bands carrying the
panel's own 26px corner radius, whose rounded bottom edges read as a stack of
pills rather than a gradient. The backdrop, bloom and shadow carry the depth
without that artefact. This is the one mockup cue that is not reproduced.

### Fixed

- **Shot timer flashed a colossal number** for the first tick of a shot.
  `espresso_timer` computes
  `([clock milliseconds] - $::timers(espresso_start)) / 1000`, and before
  `espresso_start` is assigned that subtracts from zero and yields epoch
  time. All four flow pages now route through a guard that treats anything
  outside 0..3600s as the glitch and shows `0s`. Verified against the exact
  value reported from the tablet.

---

## 0.5.1 — Empty-chart state

- **"No shot data yet - pull a shot"**, centred in the chart panel, blanking
  itself once data arrives. The live vectors start empty at every app launch
  and are only filled during a shot, so the chart is legitimately blank until
  you pull one — but an empty BLT graph autoscales x to -0.1..0.1, which
  reads as broken rather than empty. Threshold is `length > 1`, because the
  app appends a leading `0` at shot start.
- x-axis pinned to `-min 0`.

---

## 0.5.0 — Pass 3: the shot chart

The empty panel on the home screen is now a live chart, with the Raw/Smooth
toggle.

**Safety status: this version writes exactly one value** —
`::settings(live_graph_smoothing_technique)`, a stock DE1app display
preference, and only when you tap the toggle. No database is opened and no
`history/` or `history_v2/` file is read, written, renamed or deleted.
Earlier versions wrote nothing at all; this is the change.

### Added

- **Shot chart** on the home panel: pressure, flow, cumulative weight and
  basket temperature. It is a BLT/RBC `graph` bound to the app's live
  vectors, so it draws during a shot and keeps the curves afterwards.
  Element creation follows the proven pattern in `skins/Streamline/skin.tcl`.
- **Raw / Smooth toggle** in the chart header. Flips
  `live_graph_smoothing_technique` between `linear` and `catrom` — the same
  samples, Catmull-Rom interpolated — then reconfigures the existing elements
  rather than rebuilding the widget, and saves the preference.

### Notes on the implementation

- All four series share one 0..10 y axis, which is why two vectors are the
  app's pre-scaled ones: `espresso_temperature_basket10th` is degrees/10 and
  `espresso_weight_chartable` is `0.10 * scale_weight` (38g plots as 3.8).
  Using the raw vectors would flatten everything else against the axis.
- Line widths are set in **physical** pixels. The graph is a Tk widget, not a
  canvas item, so it never goes through the coordinate rescale that the rest
  of the layout uses.
- The widget is created via `dui add graph`, which routes `-width`/`-height`
  through `calc_width`/`calc_height`, so those are passed in virtual units
  like every other measurement in this file.
- `-tclcode` uses the documented `%W` substitution rather than the legacy
  `$widget` local, which `dui.tcl` itself flags as unsafe.
- Goal/target lines are deliberately not drawn. Four solid series read
  cleanly at this panel size; adding four dashed goal lines did not.

### Known gap

The chart is on the home screen only. During a shot the machine switches to
the espresso page, so you do not see it live — the flow pages still show
state, timer and metrics. Putting a live chart there means restyling a page
that was just confirmed working, so it is deliberately held for its own pass.

---

## 0.4.1 — Scan bag goes straight to the camera again

0.4.0 fixed the Bean Scanner dead end by routing through the plugin's own
settings page, which cost the one-tap camera. This restores the direct jump
and keeps the exit working.

**Safety status: no write behavior exists in this version.**

### The actual root cause

`::plugins::BeanScanner::_settings_return_page` is declared with `variable`
inside the procs that use it but is **never initialised at namespace level**,
and `_exit_settings` reads it without a catch:

```tcl
proc _exit_settings {} {
    variable _settings_return_page
    _navigate_done $_settings_return_page
}
```

Entering at a sub-page meant nothing ever assigned it, so Done threw
`can't read "_settings_return_page": no such variable` and silently did
nothing. Not a loop — a button that does nothing at all.

### Fix

**Scan bag** jumps to `BeanScanner_capture` again, seeding
`_settings_return_page` with the page it came from first — exactly the value
entering via the settings page would have produced. The plugin's own
navigation then works unmodified.

Guarded and logged: if BeanScanner ever renames that variable, this fails
loudly in the log instead of trapping the user again. Verified both paths —
plugin absent (logs, no crash) and plugin present (camera opens, return page
set).

### Known limitation

Cancel from the camera still lands on Bean Scanner's own page, and Done from
there returns home — two taps out, because every BeanScanner sub-page exits
through `_exit_subpage`, which is hardcoded to `BeanScanner_settings`.

Making Cancel return straight home requires a small change **inside
BeanScanner** (have `_exit_subpage` prefer `_settings_return_page` when the
plugin was entered directly at a sub-page, and give the variable a default so
it can never be unset). That belongs in a BeanScanner pass, not a skin pass.

---

## 0.4.0 — Flow pages, and fixes from the first tablet test

First version actually run on the tablet. It rendered correctly — both scale
sources are confirmed right, panels fill the screen and Inter is legible —
but the test found four bugs and one missing feature.

**Safety status: no write behavior exists in this version.** No database is
opened, no `history/` or `history_v2/` file is read or written, and no
`::settings` value is modified.

### Added — flow pages (the serious gap)

Espresso, steam, water and flush showed a **blank black screen**. Lumen
declares its pages with a background colour, but the stock skin keeps all of
that content inside its background JPGs (`espresso_on.png` and friends), so
declining to inherit those meant declining the content too. Nothing was ever
drawn on those pages.

Each flow page now shows what the machine is doing, a large elapsed timer,
and a glass panel of live pressure / flow / weight / temperature, plus a
"Tap anywhere to stop" hint.

Flush also gets a tap-to-stop button. The stock skin has none, because its
flush is time-limited — but Lumen gives flush a full page, and being unable
to stop a running flush is worse than the inconsistency. Deliberate
deviation, marked as such in the source.

### Fixed

- **Bold text was not bold.** The log showed `Inter-Bold.ttf` registering
  under family name `Inter` — byte-identical to what `Inter-Regular.ttf`
  reports. Naming the family therefore could not select the bold face, and
  every "bold" role silently rendered regular. The loader now detects when
  two faces claim one family name and asks Tk for the weight explicitly.
  `NotoSansMono-ExtraBold` owns its own family name and is unaffected.
- **Text overlap on the grind tile.** GrindAdvisor states its working in
  parentheses — "Regression over 8 shots (slope -29.16 s/grind, predicts
  26.8s at 8.1). (dose: ...)" — which wrapped to three lines and collided
  with the confidence row. The tile now shows the summary before the first
  parenthesis, capped at 88 characters; the full text is one tap away in the
  popup. The tile's vertical budget is also written out explicitly in the
  source so the next edit does not silently re-break it.
- **Bean Scanner trapped you.** Opening `BeanScanner_capture` directly was
  wrong: the plugin only records its return page in
  `BeanScanner_settings::show`, and every sub-page exits via `_exit_subpage`,
  which is hardcoded back to `BeanScanner_settings`. Deep-linking left the
  return page unset, so Cancel went to the settings page and Done from there
  had nowhere to go. **Scan bag** now opens `BeanScanner_settings`, the
  plugin's designed entry point, which records `off` as the return page. One
  extra tap, no dead end.
- **Last shot time read `0.0`** when no shot had been pulled, because a
  cleared series reads zero. It now reads `--`.

### Verified

Harness extended to cover the flow pages and to use the **exact** font family
names the tablet reported, rather than invented ones — without that, the
family-collision bug could not have been reproduced off-device.

All variable codes still evaluate cleanly in all three states (cold,
populated, hostile). The harness also caught a regression introduced while
making these very fixes: the `last_time` edit deleted the line that assigned
its own variable.

---

## 0.3.0 — Pass 2: live plugin data

The home screen now shows real values instead of placeholders, and the tiles
are tappable. Still not tested on the tablet.

**Safety status: no write behavior exists in this version.** No database is
opened, no `history/` or `history_v2/` file is read or written, and no
`::settings` value is modified — the skin reads globals and draws. It hands
off to GrindAdvisor's result popup, DYE's next-shot editor and Bean Scanner's
capture page; any writing those perform is their own, behind their own
confirmation.

### Added

- `::lumen::data` — accessors for every live value, all failure-tolerant.
- `::lumen::act` — guarded entry points into the three plugins.
- `::lumen::var` and `::lumen::tap` helpers.
- **Grind tile**: recommendation, signed delta, method, confidence band and
  shot count, plus the reason line. Tapping anywhere on the tile opens
  GrindAdvisor's own result popup — no trip through Settings.
- **Last shot tile**: dose, yield, time and ratio.
- **Bean strip**: brand, type and roast date, grind, dose, target yield and
  ratio; a live scale reading under Dose; and **Scan bag** / **Edit**
  buttons.

### How the live values work

Values go through `dui add variable`, which dui re-substitutes every
`::settings(timer_interval)` ms (200 here) — but only for the page that is
currently showing, and it only touches the canvas when a value actually
changed.

So every accessor is cheap and **none of them touch the filesystem**. In
particular GrindAdvisor's `load_last_recommendation` reads a file and is
never called from here: its `plugin.tcl` already calls it once at load, and
`save_last_recommendation` keeps the in-memory dict current, so reading the
namespace variable directly is free.

### Where the numbers come from

- **Grind**: `::plugins::GrindAdvisor::last_recommendation`. Only the two
  methods that exist in v3.0.0 are recognised — `regression` and
  `regression_fallback`. When the model has fewer than 3 shots on a bag and
  falls back, the tile says so instead of showing a number it cannot justify.
- **Last shot**: the same sources `shot.tcl` uses when it writes the shot
  file — `::settings(grinder_dose_weight)`, `::settings(drink_weight)`
  falling back to `::de1(pour_volume)`, and `espresso_elapsed range end end`.
  So the tile and the saved record always agree.
- **Next shot**: `::plugins::DYE::settings(next_*)` when DYE is enabled,
  falling back to core `::settings`, mirroring DYE's own `get_next`. The
  strip still works with DYE disabled.
- **Scale**: `::de1(scale_weight)`, blank unless a scale is actually
  reporting, so the strip never carries a permanent "0.0 g".

Note dose and grinder setting persist across shots in the DE1app, so "last
shot" and "next shot" read the same until you change them. That is the app's
own behaviour, not a bug in the tile.

### Fixed

- The file is now pure ASCII. A literal `·` separator was replaced with a
  plain `-`; per the project rules Unicode belongs in `\uXXXX` escapes with a
  text fallback, and a decorative separator is not worth the encoding risk on
  Android.

### Verified

Executed under `tclsh` with the framework stubbed, in three states: cold
start with no plugins and no shot, fully populated, and hostile (a corrupt
recommendation dict and non-numeric values in every setting). All 16 live
variables evaluate without error in all three. No two of the 14 tap targets
intersect.

None of this says anything about how it looks on the tablet.

---

## 0.2.0 — Inter typography

Still Pass 1, still untested on the tablet. Replaces the placeholder
Helvetica type with the real typeface set.

**Safety status: no write behavior exists in this version.** No database is
opened, no `history/` or `history_v2/` file is read or written, and no
`::settings` value is modified. The skin only draws.

### Added

- `fonts/` — Inter Regular, SemiBold and Bold for UI text; NotoSansMono
  SemiBold and ExtraBold for numbers. Both families are already proven on
  this tablet (DSx2 and Streamline ship them).
- `::lumen::_load_font_families` resolves each TTF to a real family name via
  `::dui::font::add_or_get_familyname`, with per-face fallback to
  Helvetica/Courier if registration fails.
- New `font_data` role (mono, 26px) for tabular values.

### Changed

- Numbers now render in NotoSansMono, UI text in Inter. Doses, yields, times
  and grind settings sit in columns, and a proportional face makes those
  columns ragged.
- Bean-strip values moved from `font_primary` to `font_data`.

### Why not `load_font`

The app's own `load_font` routes through `dui font load`, which computes
`int([dui cget fontm] * size)` and passes a **positive** size to
`font create` — i.e. points, which scale unpredictably with Android DPI.
`fontm` is `::settings(default_font_calibration)`, and this tablet's shot
files record it as **0.5**, so a requested 19 would become a 9pt font.

Lumen instead takes only the *family name* from the loader and creates every
font itself at **negative (pixel)** sizes derived from the detected screen
height, with a 16px floor. Verified both paths under `tclsh`: with the TTFs
registering, and with registration failing.

Weight comes from the file — each weight is loaded from its own TTF and
created with `-weight normal`. `-weight bold` is used only on the
Helvetica/Courier fallback, where there is no separate bold face to name.

---

## 0.1.0 — Pass 1: skeleton and static home page

First version. The skin loads, draws the home dashboard, and can operate the
machine. All tile values are placeholders (`--`); no plugin data is read yet.

**Safety status: no write behavior exists in this version.** No database is
opened, no `history/` or `history_v2/` file is read or written, and no
`::settings` value is modified. The skin only draws.

### Added

- `skin.tcl` — the whole skin, in one file.
- Dark and light palettes, pre-composited by hand because Tk canvas shapes
  have no alpha channel. Mode is read from `::settings(lumen_theme)`,
  defaulting to dark.
- Layout token block `::lumen::_init_layout`, authored in design pixels on a
  1340x800 basis. `::lumen::X` / `::lumen::Y` convert to the 2560x1600
  virtual canvas using separate x and y factors (1.9104 and 2.0), because a
  single shared factor drifts the layout horizontally.
- Font helper creating `LUMEN_*` named Tk fonts at negative (pixel) sizes
  from the detected physical screen height, with a 16px floor. Every piece of
  text on the skin routes through these names, and the family is set in one
  place so a shipped TTF can be swapped in later.
- `::lumen::glass` panel primitive — a smoothed rounded polygon plus a bright
  hairline along the top edge. The rounded-rectangle mechanism is copied
  verbatim from the proven `rounded_rect` in the GrindAdvisor plugin.
- Home page: left action rail (Espresso, Steam, Water, Flush, plus Settings
  and Sleep), grind recommendation tile, last shot tile, chart panel and
  next-shot bean strip.
- Flow pages (`off`, `espresso`, `steam`, `water`, `hotwaterrinse`) declared
  with `-bg_color`, so the skin ships no image assets at all.

### Notes

- `skins/default/standard_stop_buttons.tcl` is deliberately **not** sourced:
  it re-declares these same pages with the default skin's background JPGs,
  which would paint over the glass. Its stop-button bindings are reproduced
  verbatim instead.
- `skins/default/standard_includes.tcl` **is** sourced, so the stock
  settings, firmware, descale and profile-editor pages keep working
  untouched. This is the same approach DSx2 takes.
- Settings and Sleep are on the rail on purpose. Without them the skin would
  be a dead end with no way back out to change skins.

### Known limitations

- Tile values are static placeholders. GrindAdvisor, DYE, Bean Scanner and
  shot history are wired up in Pass 2.
- The chart panel is an empty frame; the real graph widget and the
  smooth/raw toggle come in Pass 3.
- The page background is a flat colour, not a gradient. Tk canvas has no
  gradient primitive, so a gradient would have to be faked with stacked
  bands; deferred until the flat version has been seen on the tablet.
- Not yet tested on the tablet.
