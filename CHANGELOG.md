# Changelog - Lumen

Entries follow a documentation cap (about 15 lines each; longer only where a
version added or changed a write capability). The original long-form entries
survive unchanged in the archive snapshot of each version.

## 0.40.0 - Drink Menu taskbar button

Base: 0.39.1.

**Safety status: unchanged. No settings writes added; no database, no history files.**

- Fifth taskbar tappable, leftmost of the right-hand group at design x 980
  (56x48 on the 72 pitch): FA6 `mug-hot` (`[format %c 0xF7B6]`) in `font_bt`,
  text fallback "CUP" through the same mechanism as the other four.
- Tap runs `::lumen::act::open_drinkmenu` (the Maintenance shortcut's
  `catch` + `info procs` + `msg -ERROR` shape) calling
  `::plugins::DrinkMenu::open_page DrinkMenu_main`; the plugin captures "off"
  as its return page, so Done lands back home.
- `bar_water_x` 1028 -> 956 so the widest readout ("1500 ml") stays one lg
  clear of the mug zone. Banner version line now tracks `variable version`.

Files: skin.tcl.

## 0.39.1 - the material adds `bg`, the plain page background - TABLET-VERIFIED 2026-09-01 (with GrindAdvisor 3.14.5)

Base: 0.39.0.

**Safety status: unchanged. One dict key in `glass_material`.**

- GrindAdvisor 3.14.1-3.14.3 could not hide the card boundary with any
  guessed blend colour; 3.14.4 rings the card with a crop of the page's own
  art, so the material now carries `bg` = the path to `lumen_home[_light].png`,
  required alongside `glass`/`dim` and existence-checked like them.
- Dark slab retuned the same day for more see-through (tint 0.20, blur 16,
  brightness 1.28); harness H2 checks all three files.
- Owner confirmed the glass popup on the tablet: both themes, grab modality,
  live page around the card, seamless edges.

Files: skin.tcl, tools/make_backgrounds.py, tools/check_skin.tcl, glass PNGs.

## 0.39.0 - glass material provider for plugin overlays - TABLET-VERIFIED 2026-09-01 (via 0.39.1 + GrindAdvisor 3.14.5)

Base: 0.38.0.

**Safety status: unchanged. Nothing visible changes in Lumen itself - one
new public proc and eight baked PNGs; no settings writes, no page edits.**

- First half of the iOS-style "liquid glass" popup (owner mockup "variant C").
  Tk has no runtime blur/alpha, so `make_backgrounds.py` bakes
  `lumen_home_glass[_light].png` (blurred, tinted, saturated slab) and
  `lumen_home_dim[_light].png` (scrim) for both themes and both resolution
  folders (~730 KB); all existing PNGs regenerate byte-identical.
- New public `::lumen::glass_material`: returns
  `{ok 1 page off theme dark|light radius 26 glass <path> dim <path>}` only
  when the current page is home AND the files exist for the screen's exact
  physical WxH; otherwise `{}`. Consumers guard with `[info procs]` (no glass
  off-skin, owner requirement) and call it once per popup open, never per tick.
- Honest limit: the slab shows the baked art; live values do not bleed through.
- Harness section H2: served on home in both themes, refused off-home and for
  unknown resolutions, quiet with no page context.

Files: skin.tcl, tools/make_backgrounds.py, tools/check_skin.tcl, 8 new PNGs.

## 0.38.0 - the grind tile shows GrindAdvisor's new-bag starting estimate - TABLET-VERIFIED 2026-08-29

Base: 0.37.1.

**Safety status: unchanged. Read-only accessors; no bake, no settings
writes. The one new plugin call reads SDB through GrindAdvisor's own
public, SELECT-only path.**

- GrindAdvisor 3.13.0's `starting_estimate` (display-only grind borrowed from
  calibrated bags) is shown for a bag with no shots: header STARTING ESTIMATE
  (live accessor `grind_header`; an estimate is never captioned
  "Recommended"), hero `~13.5`, chip "Estimate", GA's reason band, and a
  "Start ~13.5 (est. from 4 bags) - pull a shot to calibrate" note.
- `::lumen::data::grind_est` caches the result PER BAG KEY: `current_bag_key`
  is compared each 200 ms tick and the single unmemoized SDB read runs only on
  a key change (misses cached too). A real recommendation always wins.
- Older, absent, throwing or junk GrindAdvisor degrades byte-for-byte to the
  0.37.1 tile (harness-pinned). Harness section H added; a `{{{` self-parse
  trap in the harness fixed with `string repeat`.

Files: skin.tcl, tools/check_skin.tcl.

## 0.37.1 - the chip stays inside the button and matches its corners

Base: 0.37.0.

**Safety status: unchanged. Two numbers in press_flash.**

- Owner report: the zone chip read larger than the pill with sharper corners.
  Root cause: a `-smooth 1` canvas polygon renders roughly HALF the curvature
  of its control-point radius, so nominal 16 px corners poked past the pills'
  true 16 px arcs at a 1 px inset.
- Inset 1 -> 3 design px; corner control radius over-provisioned to ~28 design
  px so the RENDERED curve matches; card ring 48 -> 96 virtual for its 24 px
  baked corners. Rule: feed a smoothed-polygon rounded rect ~double the target
  radius.

Files: skin.tcl.

## 0.37.0 - press flash Option B: a chip that fits what you see

Base: 0.36.0.

**Safety status: unchanged. Flash mechanics only; no bake, no settings
writes.**

- Owner picked "Option B" after the 0.36.0 flash still read as a yellow
  rectangle: the flash had painted the TAP ZONE, far bigger than the visible
  control on the grind card and text links.
- `::lumen::tap` gains a per-zone style passed to `press_flash`: `zone`
  (default; neutral `glass_2` chip + `glass_brd` hairline lowered under the
  label, stepped to `glass` at 90 ms) for pill-backed controls; `label` (chip
  fitted to the union of visible text bboxes, padded 10x6, clamped to the
  zone) for Shot history / Curve / Shot analysis / PROFILE row / steam+water
  mode line; `ring x y w h` (hollow crema hairline on the card rect) for the
  grind card's two body zones. The 0.36.0 crema-filled chip is gone.
- Harness section L rewritten with `_flash_case` per style against a
  context-aware canvas stub.

Files: skin.tcl, tools/check_skin.tcl.

## 0.36.0 - chart pills gone, press flash is a chip, grind card opens Grind Advisor

Base: 0.35.0.

**Safety status: unchanged - Lumen still opens no database and writes
no history file. This version REMOVES two settings writes (the
smoothing and stages toggles are gone). Home + settings backgrounds
re-baked.**

- Stages and Raw/Smooth pills removed from the chart; always smooth
  (Catmull-Rom) with stage separators (`chart_smoothing` / `stages_shown` are
  fixed policy). Deleted: both toggle actions, their label accessors,
  `chart_apply_smoothing` / `chart_apply_stages`, the `chart_widgets`
  registry. `live_graph_smoothing_technique` and `lumen_chart_stages` are no
  longer read or written.
- Press flash became a crema-tinted filled chip with a thin border, lowered
  beneath the control's own label (find-overlapping + lower below the lowest
  visible text), so text links get a real pressed look.
- Grind card zones A+B open Grind Advisor's settings; "Shot analysis" keeps
  the popup, Curve unchanged. Settings page GRIND ADVISOR row removed, CLOCK
  moved up to row 3, `settings_button_row` deleted with its last caller.
- Re-bake changed only the 8 home + settings PNGs; chart_bg samples unchanged.

Files: skin.tcl, tools/make_backgrounds.py, tools/check_skin.tcl, 8 PNGs.

## 0.35.0 - NEXT SHOT card: PROFILE stacked under the label

Base: 0.34.1.

**Safety status: unchanged. Text and tap-zone geometry only; no bake.**

- Owner request: PROFILE moves to its own row under NEXT SHOT, matching the
  LAST SHOT card's stacked order (label / PROFILE / roaster / hero). This
  reverses half of 0.27.0.
- Six rows in 148 px cannot keep 10 px gaps, so the block re-spaces to a
  uniform 7 px gap with a 10 px top pad: label 584, PROFILE 606, roaster 629,
  hero 652, notes 699, action row 722 unchanged. PROFILE value width 255 ->
  370; profile tap zone moved onto its row (40,592 460x44).
- Harness: identity gap floor 7 for this layout (escape hatches documented);
  profile-zone assertions reworked.

Files: skin.tcl, tools/check_skin.tcl.

## 0.34.1 - spacing fixes (owner report on 0.34.0)

Base: 0.34.0.

**Safety status: unchanged. Geometry only.**

- Taskbar day label touched the 12-hour time's "AM": the tablet's 26 px mono
  advances ~15.5 px/glyph, not the 13 estimated. Day moved 130 -> 170; the
  harness estimate corrected to 16 px/glyph.
- Tiles' bottom text rows crowded the card border after 0.31.0 took 8 px from
  the cards. Cards back to h 190 (ends 254), the chart pays (270..558, h 288);
  every internal row keeps its clearance with zero row edits.
- Re-bake: only the four `lumen_home*` PNGs changed; `chart_bg` unchanged.

Files: skin.tcl, tools/make_backgrounds.py, tools/check_skin.tcl, 4 PNGs.

## 0.34.0 - taskbar wordmark + water readout; CLOCK formats row

Base: 0.33.0.

**Safety status: unchanged. No new reads or writes beyond two new
`lumen_*` preference keys saved through the standard `save_settings`
path.**

- Water level moved from the last-shot card corner to the taskbar (same
  accessor, blue mono, anchored right of centre, blank when the machine has
  not reported in 10 s). "Lumen" wordmark dead-centre, passive.
- DECENT APP removed from Lumen settings (the taskbar's sliders icon opens the
  same place); its bottom-right row is now CLOCK with a 24H/12H toggle and a
  date toggle ("26 Aug" vs "Aug 26"). New settings `lumen_time_format`
  (24|12) / `lumen_date_format` (dmy|mdy), defaults identical to 0.31.0,
  written only on a tap via `save_settings`, picked up on the next 200 ms tick.
  12-hour time is zero-padded so the widest time is constant-width; day label
  110 -> 130.
- Re-bake: only the four `lumen_settings*` PNGs changed. Harness: section E
  updated, section N added (format matrix, toggles, labels), taskbar spacing.

Files: skin.tcl, tools/make_backgrounds.py, tools/check_skin.tcl, 4 PNGs.

## 0.33.0 - taskbar pass 3 of 3: side panel absorbed, full-width strip

Base: 0.32.0.

**Safety status: unchanged. No new reads or writes; Profile's tap calls
the same `open_profiles` the deleted panel button called.**

- Owner's Layout 2 end state, landed only after the 0.32.0 taskbar was
  tablet-verified carrying Settings and Sleep.
- Side panel deleted (panel, three pills, three tap zones); the bean strip is
  full width, 16..1324. Stepper columns on a 270 pitch, value spans 140 (so
  "38.0 (1:2.0)" fits), groups 240 wide flush at 1300; bottom row on the same
  grid, level with the identity block's action row.
- Profile is a tap on the identity row's PROFILE label+value (170..500, 48
  tall), same `open_profiles` -> stock settings_1 tab.
- Second re-bake: only the four `lumen_home*` PNGs changed; chart_bg
  unchanged. Harness: PROFILE-zone checks replace side-panel checks; 40 zones
  flash-covered.

Files: skin.tcl, tools/make_backgrounds.py, tools/check_skin.tcl, 4 PNGs.

## 0.32.0 - taskbar pass 2 of 3: tappables + maintenance dot

Base: 0.31.0.

**Safety status: read access widens by one guarded case - the taskbar dot
reads `::plugins::MaintenanceTracker::status_summary` (cache-backed on the
plugin side) through the standard info-procs + catch + degrade guard.
Nothing written; the wrench opens the plugin's own page via its public
`open_page`, same contract as the Shot History and Grind Advisor
shortcuts.**

- Four tap zones on the bar, 56x48 on a 72 pitch, flush at 1324: wrench
  (Maintenance Tracker), gear (Lumen settings), sliders (app settings), moon
  (Sleep, the app's own `start_sleep`). FA6 glyphs via `F(symbol)` as
  `[format %c]` escapes with letter fallbacks MNT/SET/APP/ZZZ.
- Maintenance dot at the wrench corner: amber "due soon", red "overdue",
  nothing when fine, absent, or when anything about the read is off. New
  palette token `C(danger)` (#DA515E dark / #B23641 light).
- New guarded `::lumen::act::open_maintenance`. The side panel still
  duplicates Settings/Sleep on purpose until this bar is verified.
- No bake. Harness: taskbar budget checks and section M (dot through absent /
  ok / amber / red / failed / malformed / throwing plugin); 42 zones covered.

Files: skin.tcl, tools/check_skin.tcl.

## 0.31.0 - taskbar pass 1 of 3: geometry, re-bake, live time

Base: 0.30.0.

**Safety status: unchanged. No new reads, no writes, no plugin calls. The
two new accessors (`bar_time` / `bar_day`) call only `clock`, on the app's
existing 200 ms variable tick.**

- Owner picked Layout 2 ("panel absorbed") from the discovery report; this
  pass carves the bar and puts passive time/day on it. Taskbar 0..48; top
  cards 64..246 (h 182); chart 262..558 (h 296); strip and side panel
  untouched. Last-shot tile absolute row tokens +48; grind tile rows are
  `grind_y`-relative.
- Time (`%H:%M`, mono) and day (`%a %d %b`) ride the 200 ms tick; dui
  reconfigures on change only, so one redraw per minute.
- All four `lumen_home*` PNGs re-baked; the twelve others MD5-identical.
  Light `chart_bg` re-sampled #DEE0E5 -> #DEE0E4.
- Harness: taskbar budget block; fixed a latent fault where `clock format`'s
  lazy autoload died under the stubbed `source`/`package` (pre-warm added).

Files: skin.tcl, tools/make_backgrounds.py, tools/check_skin.tcl, 4 PNGs.

## 0.30.0 - the chart follows the bag cycler; the flash ring hugs the control

Base: 0.29.1.

**Safety status: unchanged. Read access widens by one case: the loader can
be pointed at a SPECIFIC `history/*.shot` file (the cycled bag's newest)
instead of only the newest overall. Same single-file read, same local
parse, same `history_saved` guard. Nothing written.**

- `cycle_bag` resolves the bag's newest shot file (`_bag_last_shot_file`:
  filenames ARE clocks, `%Y%m%dT%H%M%S`) and calls
  `load_last_shot_curves 1 <path>`, so chart, LAST SHOT card and profile all
  describe the bag on screen. A soft-deleted newest shot falls back to the
  next on disk; a fully trashed bag leaves the chart alone with a NOTICE; a
  load failure never undoes the cycle.
- Flash ring inset 5 -> 1 px (pill zones ARE their drawn bounds), radius =
  the baked pills' RADIUS_S (16 design px).
- Accepted asymmetry: an SHE reload loads the GLOBAL newest and snaps a
  cycled view back to the newest bag.
- `check_last_shot.tcl` section J covers the explicit-path loads.

Files: skin.tcl, tools/check_last_shot.tcl.

## 0.29.1 - the press flash is a clean accent ring, not a stipple

Base: 0.29.0.

**Safety status: unchanged - drawing options inside `press_flash` only.**

- Owner: the 0.29.0 flash "looks like a graphics bug". `-stipple gray25` is a
  raw 4x4 checkerboard and reads as pixel corruption at tablet DPI.
- The flash is now a hollow crema ring: >= 3 px accent outline in the
  control's rounded shape, inset a few px, no fill, label fully visible; same
  150 ms life and shared-tag lifecycle.
- Rule: never fake alpha with `-stipple` on this panel.

Files: skin.tcl.

## 0.29.0 - every tap gets a visual press flash

Base: 0.28.1.

**Safety status: unchanged. One new drawing helper and one line in `tap`.
Nothing written, no file handling, no page structure changes.**

- Owner: buttons felt "flat and dead" (every control is baked pixels with an
  invisible zone). `::lumen::press_flash` draws a 150 ms crema glow in the
  zone's rounded shape; wired inside `tap`, so all 38 zones got it at once.
- Rules baked in: transient items go straight on `.can`, never through dui;
  direct `.can` drawing needs `rescale_x/y_skin`; `update idletasks` before
  the button's command; a new press clears the previous glow; the five
  full-screen flow-stop zones deliberately do not flash.
- Harness section L: every button either flashes with its own zone
  coordinates or is a full-screen stop.

Files: skin.tcl, tools/check_skin.tcl.

## 0.28.1 - stepper acceleration only on genuinely rapid taps

Base: 0.28.0.

**Safety status: unchanged - one timing constant in the stepper
acceleration. No file handling, no page changes, nothing written.**

- Owner report: careful tapping on the grind stepper escalated to 0.5 steps.
  The 700 ms window contained a measured step-step-step pace (~500-700 ms).
- Window now 350 ms: escalation needs drumming (3+ taps a second);
  thresholds (0.5 after three, 1.0 after six) and resets unchanged.
- Harness section K drives `_accel_step` on a fake clock: 600 and 400 ms
  paces stay 0.1, 250 ms drumming escalates, pause and direction reset;
  negative-tested against the old window, which reproduces the report.

Files: skin.tcl, tools/check_skin.tcl.

## 0.28.0 - the home page follows Shot History Editor changes - TABLET-VERIFIED 2026-08-24

Base: 0.27.2.

**Safety status: unchanged. No database is opened, and nothing in `history/`
or `history_v2/` is written, renamed or deleted. This version adds a REREAD
of the newest shot file - the same single-file read the skin has done at
startup since 0.24.1 - triggered by ShotHistoryEditor instead of only by
startup.**

- `load_last_shot_curves {force 0}`: the plain call is byte-identical; force
  guards on `history_saved` (0 = live unsaved samples = refuse loudly) instead
  of the vector-length startup guard. Do not merge the two guards.
- `last_shot_rec` is cleared before repopulating so a deleted shot's values
  cannot linger on the previous shot's card.
- `::lumen::refresh_after_history_change` is the ONE public entry point (SHE
  v0.7.0 calls it guarded on `info procs`): force reload + `refresh_bag_list`.
  Every reload path ends `history_saved 1`, so the 0.27.1 flush trap stays
  closed (harness-asserted after each case).
- Verified on the tablet by driving a real SHE delete + restore: grind card,
  LAST SHOT yield and chart all followed with no shot and no restart.
- `check_last_shot.tcl` section I: plain refused, force refused mid-shot,
  delete-newest, sparse-file carry-over, flush trap.

Files: skin.tcl, tools/check_last_shot.tcl.

## 0.27.2 - the method chip showed a raw GrindAdvisor key - NOT YET TABLET-TESTED

Base: 0.27.1.

**Safety status: unchanged. No database is opened, and nothing in `history/`
or `history_v2/` is written, renamed or deleted. This version changes one
label map and one character budget; it touches no file and no shot data.**

- The chip read `regression_unt...`: GrindAdvisor 3.10.0 added a fifth rung,
  `regression_untrusted`, and `::lumen::data::grind_method` fell through to
  the raw-key fallback. Mapped to "Weak fit".
- Fallback budget 16 -> 12 characters (16 was ~134 px of 16 px Inter SemiBold
  in a 150 px chip).
- Harness section G reads the rung names out of `GrindAdvisor.tcl` (never a
  hand-written list) and asserts every rung has a short, underscore-free chip
  label that fits 12 characters.

Files: skin.tcl, tools/check_skin.tcl.

## 0.27.1 - a flush could overwrite the last shot's file - NOT YET TABLET-TESTED

Base: 0.27.0.

**This one destroyed real data on the tablet, and the exposure was ours.
Lumen writes no shot file; the fix is one settings flag that stops the core's
own save from firing on samples the skin loaded.**

- What happened: the 18 August shot file was rewritten by a FLUSH the next
  morning (`grinder_setting` 8 -> 7.5, `drink_weight` 37.8 -> 0, 29,948 ->
  21,506 bytes). The log shows `Idle => HotWaterRinse` followed by "Saved this
  espresso to history" with no espresso in between.
- Why: the core saves on `after_flow_complete`, which fires after ANY flow,
  guarded only by `!history_saved` plus the vector lengths, and writes to the
  filename from the PREVIOUS espresso's clock (`vars.tcl:3440-3457`).
  `load_last_shot_curves` fills exactly those vectors at startup for the home
  chart, which is what lets that guard pass. The write is the core's; the
  condition was ours.
- Fix: `set ::settings(history_saved) 1` after the vectors are loaded. The
  flag then states the truth (the samples were read out of history).
  `reset_gui_starting_espresso` clears it at a real espresso start
  (`machine.tcl:846`), so genuine shots still save. Anything that loads past
  shot vectors (the stock `preview_history` included) has this exposure.
- Recovery: ShotHistoryEditor's backup `20260819T002956_0d17` holds the intact
  file. `check_last_shot.tcl` sets `history_saved` 0 before the load and
  asserts it comes back 1 ("a flush would overwrite it").

Files: skin.tcl, tools/check_last_shot.tcl.

## 0.27.0 - the bag cycler gets a page indicator, and room to breathe - NOT YET TABLET-TESTED

Base: 0.26.1.

**Safety: display only. No new writes; the cycler still hands the bag change
to DYE's own `source_next_from`, as before.**

- Arrows shrunk from 120x48 to a stepper pill's 44x48 with Edit still between
  them. A draft that flanked the bag name was killed by the preview: the right
  arrow read as one of GRIND's controls. Assertion: arrows never share the
  stepper pills' row.
- Minus glyph lifted 2 design px in every stepper (`L(step_minus_dy)`),
  measured on a tablet screenshot (ink +2.5 vs +0.5 for plus).
- Dot-per-bag page indicator (text items U+25CF / U+25CB via `format %c`, not
  ovals, so the tick re-evaluates them free); the cycler no longer wraps.
  Bag list cached in `::lumen::bag_list` (refreshed on home `show` and at
  startup) so no SDB call rides the 200 ms tick.
- Identity block re-spaced to even 11 px gaps by moving PROFILE up beside
  NEXT SHOT; bag name gets the full 460 px. Backgrounds re-baked (three action
  row pills changed size). Harness section J: indicator states and end stops.

Files: skin.tcl, tools/make_backgrounds.py, tools/check_skin.tcl, home PNGs.

## 0.26.1 - the last shot is the newest SHOT, not the newest FILE

Base: 0.26.0.

**Safety unchanged: one file read, nothing written.**

- Caught in the tablet log minutes after 0.26.0: `loaded last shot curves from
  20260715T170133.shot`, a July shot, because the loader picked by mtime.
  ShotHistoryEditor v0.6.0 deliberately stamps mtime on a metadata edit so SDB
  re-reads the file, which promoted that shot to "last shot".
- The loader now sorts by FILENAME (`YYYYMMDDTHHMMSS.shot` is shot time);
  mtime survives only as a fallback for a name that is not a timestamp.
- Rule: the plugins are right to touch mtime; the skin was wrong to read it as
  a clock. `check_last_shot.tcl` builds two shots with the older one's mtime a
  day ahead and asserts the trap is live before relying on it.

Files: skin.tcl, tools/check_last_shot.tcl.

## 0.26.0 - STEAM and HOT WATER alternate between two settings - NOT YET TABLET-TESTED

Base: 0.25.0.

**Safety: display and machine preferences only. No database is opened; the
only file read is the newest `history/*.shot`, as since 0.9.0. The two new
steppers write `::settings(steam_flow)` and `::settings(water_temperature)`,
both clamped, both saved and sent through the same debounced
`save_settings` + `save_settings_to_de1` path the other machine steppers
already use.**

- One -/+ group per settings row drives whichever half is selected: STEAM
  alternates TIME (`steam_timeout`, +/-5 s) and FLOW (`steam_flow`, +/-0.1
  mL/s); HOT WATER alternates TEMP (`water_temperature`, +/-1 C) and VOL
  (`water_volume`, +/-10 ml). The mode line under the label is one 180x48 tap;
  the choice persists in `lumen_steam_mode` / `lumen_water_mode` (Lumen
  preferences, saved with `save_settings`).
- Clamps come from Streamline's own controls for the same fields:
  `steam_flow` 40..250 (floor from its data-entry dialog), `water_temperature`
  20..100.
- Rendering: selected value 26 px on the pill band's upper line, the other
  16 px beneath (the YIELD/ratio arrangement); mode line is two text items
  because a canvas item's `-fill` is fixed at creation. No re-bake.
- Harness section I: four display states, mode fallbacks, a tap moves only the
  selected setting, both clamps, toggle round trip.

Files: skin.tcl, tools/check_skin.tcl.

## 0.25.0 - the LAST SHOT card reports the shot's own record - NOT YET TABLET-TESTED

Base: 0.24.1.

**Safety: display only. No database is opened. Nothing in `history/` or
`history_v2/` is written, renamed or deleted - no version of this skin ever
has. Read access is one file: the newest `history/*.shot`, which
`load_last_shot_curves` has opened at startup since 0.9.0; this version takes
three more fields out of the copy it had already parsed. The header's SAFETY
STATUS block was corrected: it had claimed nothing in `history/` was read.**

- Owner case: a Shot History edit set `grinder_setting 8` in the file while the
  card kept showing the live `7.5`. The card now prefers the record:
  `::lumen::last_shot_rec(grind|dose|yield)` latched from the newest shot
  file's settings block at startup, winning over live `::settings` until a
  shot starts (`latch_shot_profile` drops the latch). The NEXT SHOT card is
  untouched: one card is the record, the other the plan.
- `last_ratio` now uses the same two accessors as the numbers it sits between.
  Grind is free text (not `_is_pos`); the weights must be positive.
- Not fixed here: Grind Advisor following a Shot History edit (it reads SDB;
  SHE never writes SDB; `sync_on_startup` is 0) - a Grind Advisor pass.
- Harness: G gains file-beats-live; G2 covers grind/dose across five states;
  `check_last_shot.tcl` reproduces the tablet state exactly.

Files: skin.tcl, tools/check_skin.tcl, tools/check_last_shot.tcl.

## 0.24.1 - the last shot's yield survives a restart - NOT YET TABLET-TESTED

Base: 0.24.0.

**Safety: display only. No database is opened; the only file read is the
newest `history/*.shot`, which `load_last_shot_curves` was already reading for
the chart and the profile name - one more field is taken from the copy it
already has in memory. Nothing in `history/` or `history_v2/` is written,
renamed or deleted, and no version of this skin has ever written to them.**

- The LAST SHOT card read `YIELD 0.0` while the grind tile called the same
  shot 37.8 g: `::settings(drink_weight)` does not survive a restart. The
  yield is now latched from the newest shot file (`::lumen::last_shot_yield`)
  and dropped when a shot starts.
- A missing yield was formatted as a reading: `_yield_raw` returns `""` when
  no source is positive, so the card shows `--` and the ratio blanks instead of
  `1:0.00`. Source order: `drink_weight` -> `pour_volume` -> file latch.
- Harness section G (five yield states); `tools/check_last_shot.tcl` added,
  running the loader against a real `.shot` file off-device.

Files: skin.tcl, tools/check_skin.tcl, tools/check_last_shot.tcl.

## 0.24.0 - water level, Profile shortcut, settings shuffle, flow-timer fix - NOT YET TABLET-TESTED

Base: 0.23.2.

**Safety: display and preferences only. No database is opened, no file in
`history/` or `history_v2/` is read, written, renamed or deleted, and this
version adds no write of any kind - the Profile button hands off to the app's
own profile page and the app owns everything that happens there.**

- Water tank level (blue, mL) top-right of the LAST SHOT card, converted by
  the core's `water_tank_level_to_milliliters`; suppressed unless
  `::de1(last_ping)` is within the core's 10 s (the core seeds `water_level`
  to 20 with no machine).
- Profile button in the side panel (Profile / Settings / Sleep, 56 tall) via
  `show_settings settings_1`, Streamline's own shortcut, no custom navigation.
- DECENT APP is the bottom-right settings card; THEME and BAGS TO CYCLE moved
  up, GRIND ADVISOR above it. Columns stay 460/500 (an intermediate 492/492
  build was reverted; `_init_layout` warns against equalising them).
- Flow timers gated to the current page visit: `::lumen::data::_flow_secs`
  reads `::timers` and reports a finished flow only if it started after the
  page was last shown (`::lumen::latch_flow_open` on each flow page's `show`),
  fixing the ~450 s flash at shot start. `_sane_secs` normalises `-0`.
- Settings row geometry moved into `_init_layout` tokens; backgrounds
  re-baked (home + settings); chart sample tokens unchanged. Harness sections
  D, E, F added.

Files: skin.tcl, tools/make_backgrounds.py, tools/check_skin.tcl, PNGs.

## 0.23.2 - water and flush pages read their own timers - TABLET-VERIFIED 2026-08-15

Base: 0.23.1.

**Safety status: display only, no new writes.**

- Water and flush were both reading `espresso_secs` (time since the last
  espresso), which looked right shortly after a shot and read 0 an hour later.
  New `data::water_secs` / `data::flush_secs` use the core's
  `water_pour_timer` / `flush_pour_timer`.
- Two harness defects exposed: `espresso_timer` was never stubbed (the
  accessors' `catch` hid it) and the harness hardcoded an absolute path to the
  workspace skin, so a modified copy silently re-ran the original. Path now
  from `[info script]`, printed at start; all four timers stubbed distinctly.
- The new check inspects the recorded `dui add variable` calls per page and
  asserts each flow page is wired to its own accessor.

Files: skin.tcl, tools/check_skin.tcl.

## 0.23.1 - strip rows levelled, even vertical rhythm - TABLET-VERIFIED 2026-08-15

Base: 0.23.0.

**Safety status: display only. Two token values.**

- The strip's bottom row sat 6 px above the identity block's action row:
  `scale_y` 716 -> 722 (= `id_act_y`), so all six controls share one baseline
  ending at 770.
- Right column evenly distributed: `step_y` 644 -> 642, giving exactly 32 px
  above and below the stepper pills (measured on the baked asset).
- Three harness assertions: rows share y and height; the two gaps are equal.

Files: skin.tcl, tools/check_skin.tcl.

## 0.23.0 - re-proportioned home, bean details on both cards - NOT YET TABLET-VERIFIED

Base: 0.22.0.

**Safety status: no new writes and no new settings.** Layout and display only.

- Owner mockup: top cards 16..206 (h 190), chart 222..558 (h 336), bottom row
  574..784 (h 210); every gap md.
- Both cards read LABEL -> PROFILE -> roaster (small) -> bean type (hero);
  identity block widened 280 -> 460 so a 44-character roaster fits. Tasting
  notes (`bean_notes`) on the next-shot card when non-empty.
- Last shot gained GRIND and the ratio note; Shot history became a text link.
  PROFILE left the stepper row (three columns on a 210 pitch); Edit moved to
  the action row between the cycler arrows (all 48 tall); the identity block's
  full-height DYE tap is gone (Edit is the single entry point).
- `C(chart_bg)` -> #151618 / #DEE0E5: the generator's sample point is absolute
  and the panel moved; re-sample whenever the chart panel moves.
- Four tablet text bugs fixed: last-shot profile drawn at the next-shot x,
  Curve left outside the shortened tile, last-shot bean name truncated (now
  `font_primary`, 24 chars), multi-line `bean_notes` collapsed to one line.

Files: skin.tcl, tools/make_backgrounds.py, tools/check_skin.tcl, home PNGs.

## 0.22.0 - the grind tile follows the cycled bag - NOT YET TABLET-VERIFIED

Base: 0.21.0.

**Safety status: no new writes, no new settings, no asset change.** No layout
change either, so nothing was re-baked.

- Owner report: cycling a bag changed the bean fields but the grind card kept
  its old number. Blanking (0.21.0's design) was wrong anyway - a bag you
  cycle back to has its own regression.
- `grind_rec` calls Grind Advisor 3.8.0's `recommendation_for_current_bag`
  (memoized per bag, so the 200 ms tick costs nothing). Older plugin builds
  are handled behind `[info procs]` in descending order of capability.
- A bag with no shots still shows the "pull a shot" note; nothing invents a
  grind.

Files: skin.tcl.

## 0.21.0 - bag cycler, profile on the strip and the last-shot card - NOT YET TABLET-VERIFIED

Base: 0.20.0.

**Safety status: no new write class, and Lumen still opens no database.** The
bag cycler reads through SDB's public API and writes through DYE's own
`::plugins::DYE::shots::source_next_from` - the same path Bean Scanner uses.
Lumen issues no SQL and holds no database handle. No file in `history/` or
`history_v2/` is read, written, renamed or deleted.

- Bag cycler on the NEXT SHOT label row, depth from `lumen_bag_count`. List:
  `::plugins::SDB::available_categories bean_desc 1 {} 0` (the trailing 0
  picks the `MAX(shot.clock) DESC` branch, the only one applying `removed=0`,
  and avoids the lookup branch's undefined `lookup_order_by`). Clock:
  `shots_using_category bean_desc <value> t.clock` - the `t.` works around an
  SDB "ambiguous column name" defect found on the tablet; `_bag_clocks` tries
  qualified then bare, returns {} rather than throwing. Apply:
  `source_next_from <clock> {} beans` (DYE expands the whole bean section).
- Arrows sit just after the label at x 150/196, NOT right-aligned (that touched
  the GRIND column at 320 and read as its controls); harness asserts >= md.
- RATIO's stepper became a read-only PROFILE tile; ratio is a derived caption
  inside the pill band. `act::adjust_ratio` deleted.
- LAST SHOT names the profile the shot ran on: `::lumen::last_shot_profile`
  latched on the espresso page's `show`, seeded from the newest `.shot` file
  into a LOCAL array (never `array set ::settings`).
- Grind tile resets on a bag/profile change via GA 3.7.0's
  `last_recommendation_is_current` (guarded for older builds). DYE tap starts
  below the arrows. Home re-baked (RATIO pills out, cycler pills in).

Files: skin.tcl, tools/make_backgrounds.py, tools/check_skin.tcl, home PNGs.

## 0.20.0 - every page baked; settings right column filled - TABLET-VERIFIED 2026-08-15

Base: 0.19.0.

**Safety status: one new setting, no new write class.**
`::settings(lumen_bag_count)` (3-10, default 5) is written only on an
explicit stepper tap and saved with plain `save_settings` - it is a skin
preference and deliberately never goes near `save_settings_to_de1`. No
database is opened; no file in `history/` or `history_v2/` is read, written,
renamed or deleted. Everything else in this version is display-only.

- Only `off` was baked; every other page fell through to the flat vector
  `glass`. `tools/make_home_bg.py` became `tools/make_backgrounds.py` with a
  `PAGES` table: `lumen_home`, `lumen_settings`, `lumen_flow_chart`
  (espresso), `lumen_flow` (steam/water/hotwaterrinse share one image). Home
  PNGs regenerate byte-identical (SHA256), proving the refactor safe.
- New token `C(chart_bg_flow)` (#171719 / #DEE1E4), separate from
  `C(chart_bg)`: the espresso chart panel sits at a different gradient height.
- Settings right column gains BAGS TO CYCLE (ships inert; the cycler is
  0.21.0) and GRIND ADVISOR (`open_settings_dialog`, guarded). THEME baked
  with the raised fill to match `build_settings`.
- Harness: settings-page budget check; every `baked_pages` entry must have an
  image for both themes at both resolutions.
- Verified on the tablet including all four flow pages (owner, 2026-08-15).

Files: skin.tcl, tools/make_backgrounds.py (renamed), tools/check_skin.tcl, PNGs.

## 0.19.0 - tap-rate acceleration on the grind / dose / yield steppers - TABLET-VERIFIED 2026-08-14

Base: 0.18.0.

**Safety status: no new settings and no new writes.** Same fields as 0.18.0,
same clamps; only the per-tap step size changed.

- Slow tap moves 0.1; taps within 700 ms of each other escalate to 0.5 after
  three and 1.0 after six; a pause or direction change resets to 0.1. RATIO
  and the settings-page machine steppers keep fixed increments.
- "Hold to repeat" is impossible: legacy canvas buttons fire once per press
  with no hold event, so the fast-tap ladder is the mechanism.

Files: skin.tcl.

## 0.18.0 - rail removed, next-shot steppers, steam heater labelled honestly - TABLET-VERIFIED 2026-08-14

Base: 0.17.0.

**Safety status: this version adds settings writes in two groups, each only
on an explicit tap and each clamped.**

- Next-shot steppers (home strip): `grinder_dose_weight` (Set dose, and the
  +/-0.5 dose stepper clamped 2..40), `grinder_setting` (grind stepper,
  0..100), `final_desired_shot_weight` / `final_desired_shot_weight_advanced`
  (yield and ratio steppers, 0..200; `_advanced` only for `settings_2c`
  profiles, mirroring DSx2's saw stepper). With DYE loaded its staged
  `next_grinder_setting` / `next_grinder_dose_weight` are kept in step (DYE's
  own `setup_DSx2.tcl change_grinder_setting` pairing).
- Machine steppers (Lumen settings page, mirroring Streamline):
  `espresso_temperature` (Brew +/-0.5 C, 70..110, via the core's
  `change_espresso_temperature`), `steam_timeout` + `steam_disabled` (Steam
  +/-5 s, 0..255, 0 = off), `flush_seconds` (Flush +/-1 s, 3..254),
  `water_volume` (Hot Water +/-10 ml, 10..250). Applied with `save_settings` +
  the core's `save_settings_to_de1`, debounced 1 s (Streamline's
  `save_profile_and_update_de1_soon` pattern); the profile file is NOT saved.
- Preferences: `lumen_theme`, `live_graph_smoothing_technique`, and the new
  `lumen_chart_stages` (Stages toggle). The Shot history button only opens
  ShotHistoryEditor; no database is opened and no history file is written,
  renamed or deleted by Lumen.
- Steam page "158 C" is the steam HEATER at its 160 set point (the same value
  every stock skin shows): relabelled STEAM HEATER with a `target 160 C` note.
- Action rail removed (the GHC covers it); tiles span 16..1324. Settings and
  Sleep survive in a side panel (never to be dropped - the skin would be a dead
  end). Streamline-style stepper groups for GRIND / DOSE / YIELD / RATIO on one
  even grid; bottom row: scale readout, Set dose, Scan bag, Edit.
- Shot history shortcut on the Last shot tile (`open_page
  ShotHistoryEditor_settings`); stage separators on the chart with a Stages
  pill; loaded-shot 0 s artifact fixed by slicing from the first positive
  elapsed value. Settings page is two columns (machine steppers left; THEME as
  plain glass and DECENT APP right). Home PNGs regenerated; chart_bg unchanged.

Files: skin.tcl, tools/make_home_bg.py, tools/check_skin.tcl, home PNGs.

## 0.17.0 - Curve opens from the grind tile - TABLET-VERIFIED 2026-08-02

Base: 0.16.0.

**Safety status: unchanged.** Still exactly three settings written, each only
on an explicit tap (`lumen_theme`, `live_graph_smoothing_technique`,
`grinder_dose_weight`). No database is opened and no file in `history/` or
`history_v2/` is written, renamed or deleted. The new control calls
GrindAdvisor's own read-only viewer and writes nothing.

- A Curve control on the grind tile's bottom row opens GrindAdvisor's
  Calibration Curve via its public `show_calibration_curve` (v3.3.0+); on an
  older plugin `::lumen::act::grind_curve` logs a NOTICE and falls back to the
  result popup.
- The tile's single tap is carved into three rectangles around Curve (A above
  the bottom row, B left, C right; Curve 506..596 x 190..252), contiguous and
  non-overlapping, all still opening the result popup.

Files: skin.tcl.

## 0.16.0 - method chip shows the first two shots; scale readout reconnects

Base: 0.15.0.

**Safety status: no new write behaviour.** Still exactly three settings
written, each only on an explicit tap (`lumen_theme`,
`live_graph_smoothing_technique`, `grinder_dose_weight`). No database is
opened and no file in `history/` or `history_v2/` is written, renamed or
deleted. The scale reconnect calls the app's own `ble_connect_to_scale` and
resets one in-memory `::de1()` counter - nothing is persisted.

- The method chip was blank for the first two shots of a bag: only 2 of
  GrindAdvisor v3's 4 ladder rungs were mapped. Now First shot / 2-shot /
  Regression / Pairwise; an unknown rung shows verbatim (16 chars).
- The scale readout is a tap target that forces a reconnect
  (`::lumen::act::reconnect_scale`, copied from Insight: clear
  `bluetooth_scale_connection_attempts_tried`, then `ble_connect_to_scale`).
  Core cause, read from `de1_comms.tcl:587` / `bluetooth.tcl:1880`: after 20
  failed attempts the core resets its counter and never retries. The readout
  now distinguishes `no scale` / `Connecting` / `Connect`.

Files: skin.tcl.

## 0.15.0 - Done restarts the app when the theme changed

Base: 0.14.1.

**Safety status: unchanged.** Still exactly three settings written, each only
on an explicit tap (`lumen_theme`, `live_graph_smoothing_technique`,
`grinder_dose_weight`). No database is opened and no file in `history/` or
`history_v2/` is written, renamed or deleted. The restart path adds one
`save_settings` - the same call the toggle already made - and no new write.

- `::lumen::act::restart_for_theme` copies the app's restart-on-skin-change
  sequence verbatim (`skins/default/de1_skin_settings.tcl:65-71`): message
  page, `set_next_page off message`, `page_show message`, `after 200
  app_exit`. Tablet-verified: the theme switches and the app quits.
- The app cannot reopen itself (measured on Android 16): `am start` from the
  app's uid throws a SecurityException; `borg activity` starts inside the
  dying process. You relaunch by hand; no custom exit machinery written.
- `close_settings` restarts only when `pending_theme` differs from the loaded
  `theme_mode`; `theme_note` says the app will restart.

Files: skin.tcl.

## 0.13.0 - the last shot loads at startup

Base: 0.12.4.

**Safety status: unchanged.** Three settings written, each only on an
explicit tap (`live_graph_smoothing_technique`, `lumen_theme`,
`grinder_dose_weight`). This version adds a **read** of one history file and
writes nothing.

- `::lumen::load_last_shot_curves` finds the newest `history/*.shot`, reads
  it and fills the chart vectors, deferred 5 s after load (the BLT vectors are
  created during app setup); skips if a shot is running. Tablet-verified.
- `espresso_weight_chartable` and `espresso_temperature_basket10th` are
  derived (0.10 x weight, temperature / 10) because the app does not store
  the scaled forms.
- Trap avoided: `preview_history` also does `array set ::settings
  $props(settings)`, which would replace the live configuration on every
  launch. Only the vector half was taken; the test asserts `::settings` is
  untouched.

Files: skin.tcl.

## 0.12.4 - long bean names no longer wrap into the line below

Base: 0.12.3.

**Safety status: unchanged (display only).**

- The brand at 40 px in a 272 px column with `-width` wrapped onto the
  type/roast line beneath. Truncated to 13 characters.
- Auto-scaling the font was rejected: a canvas item's font is fixed at
  creation, and a name rendering at a different size each session breaks the
  fixed type scale.

Files: skin.tcl.

## 0.12.3 - chart panel flat and padded, scale readout centred

Base: 0.12.2.

**Safety status: unchanged (display only).**

- Chart panel rendered flat (new per-panel `flat` flag in the generator): a
  BLT graph is an opaque widget with one background colour, so a gradient
  panel showed it as a box. `chart_bg` re-sampled #141517 dark / #DDE0E4
  light.
- `plotpadx 18 / plotpady 8` on both charts so the outermost tick label is
  not clipped. Scale readout text centred on its box.
- `::lumen::version` corrected to match the archive (0.12.1 and 0.12.2 had
  bumped the header and archive name but not the constant).

Files: skin.tcl, tools/make_home_bg.py, home PNGs.

## 0.6.0 - Pass 3b: depth

Base: 0.5.1.

**Safety status: unchanged** - one setting written
(`live_graph_smoothing_technique`), no database, no history files.

- Depth cues built from stacked solid shapes in interpolated colours (Tk
  canvas has neither gradients nor alpha), drawn once at page build:
  `::lumen::mix`, `::lumen::paint_backdrop` (32-band vertical wash plus a
  crema bloom of 14 ovals), soft drop shadows (four concentric rounded rects)
  on every glass panel; palette tokens `bg_top`, `bg_bot`, `shadow`, `bloom`.
- Deliberately not done: a gradient inside each panel (no clipping in Tk
  canvas). Later reverted in favour of the baked PNG background.
- Fixed: the shot timer flashed a colossal number on the first tick
  (`espresso_start` unset); all four flow pages guard 0..3600 s and show `0s`.

Files: skin.tcl.

## 0.5.1 - Empty-chart state

Base: 0.5.0.

**Safety status: unchanged (display only).**

- "No shot data yet - pull a shot" centred in the chart panel, blanking once
  data arrives (threshold `length > 1` because the app appends a leading 0 at
  shot start); an empty BLT graph otherwise autoscales to -0.1..0.1 and reads
  as broken.
- x-axis pinned to `-min 0`.

Files: skin.tcl.

## 0.5.0 - Pass 3: the shot chart

Base: 0.4.1.

**Safety status: this version writes exactly one value** -
`::settings(live_graph_smoothing_technique)`, a stock DE1app display
preference, and only when you tap the toggle. No database is opened and no
`history/` or `history_v2/` file is read, written, renamed or deleted.
Earlier versions wrote nothing at all; this is the change.

- Shot chart on the home panel: pressure, flow, cumulative weight and basket
  temperature, a BLT/RBC `graph` bound to the app's live vectors (element
  pattern from Streamline). Raw / Smooth toggle flips
  `live_graph_smoothing_technique` between `linear` and `catrom`, reconfigures
  the existing elements and saves the preference.
- All four series share one 0..10 y axis, so the app's pre-scaled vectors
  (`espresso_temperature_basket10th`, `espresso_weight_chartable`) are used.
  Line widths are physical pixels (a Tk widget, not a canvas item); the
  widget is created via `dui add graph` with virtual `-width`/`-height`;
  `-tclcode` uses `%W`. Goal lines deliberately not drawn.
- Known gap: chart on the home screen only; the flow pages get theirs later.

Files: skin.tcl.

## 0.4.1 - Scan bag goes straight to the camera again

Base: 0.4.0.

**Safety status: no write behavior exists in this version.**

- Root cause of the 0.4.0 dead end: BeanScanner's `_settings_return_page` is
  declared with `variable` inside procs but never initialised at namespace
  level, and `_exit_settings` reads it without a catch, so entering at a
  sub-page made Done throw "no such variable" and do nothing.
- Scan bag jumps to `BeanScanner_capture` again, seeding
  `_settings_return_page` first with the page it came from. Guarded and
  logged; verified with the plugin absent and present.
- Known limitation: Cancel from the camera lands on Bean Scanner's own page
  (two taps out) because `_exit_subpage` is hardcoded; fixing that is a
  BeanScanner pass.

Files: skin.tcl.

## 0.4.0 - Flow pages, and fixes from the first tablet test

Base: 0.3.0.

**Safety status: no write behavior exists in this version.** No database is
opened, no `history/` or `history_v2/` file is read or written, and no
`::settings` value is modified.

- First version run on the tablet: both scale sources confirmed right, panels
  fill the screen, Inter legible.
- Added the flow pages (espresso / steam / water / flush were blank black):
  machine state, a large elapsed timer, a glass panel of live pressure / flow
  / weight / temperature, "Tap anywhere to stop"; flush gets a tap-to-stop
  button (deliberate deviation from the stock skin).
- Fixed: bold text was not bold (`Inter-Bold.ttf` registered under the same
  family name as Regular; the loader now asks Tk for the weight explicitly
  when two faces collide); grind tile reason text overlapped the confidence
  row (summary before the first parenthesis, 88 chars); Bean Scanner trapped
  the user (entry via `BeanScanner_settings`); last shot time read `0.0`
  instead of `--`.
- Harness extended to the flow pages using the tablet's exact font family
  names; it caught a self-inflicted `last_time` regression.

Files: skin.tcl, tools/check_skin.tcl.

## 0.3.0 - Pass 2: live plugin data

Base: 0.2.0.

**Safety status: no write behavior exists in this version.** No database is
opened, no `history/` or `history_v2/` file is read or written, and no
`::settings` value is modified - the skin reads globals and draws. It hands
off to GrindAdvisor's result popup, DYE's next-shot editor and Bean Scanner's
capture page; any writing those perform is their own, behind their own
confirmation.

- `::lumen::data` accessors (failure-tolerant), `::lumen::act` guarded plugin
  entry points, `::lumen::var` / `::lumen::tap` helpers.
- Grind tile (recommendation, delta, method, confidence, reason; tap opens
  GrindAdvisor's popup), Last shot tile (dose, yield, time, ratio), Bean strip
  (bag identity, grind, dose, yield, ratio, live scale, Scan bag / Edit).
- Values go through `dui add variable` on the 200 ms tick, current page only;
  no accessor touches the filesystem (GrindAdvisor's in-memory
  `last_recommendation` is read directly, never the loader).
- Sources: GrindAdvisor `last_recommendation`; the same `::settings` fields
  `shot.tcl` writes; DYE `next_*` with core fallback; `::de1(scale_weight)`.
- File made pure ASCII. Verified under `tclsh` in cold, populated and hostile
  states; 14 tap targets, none intersecting.

Files: skin.tcl, tools/check_skin.tcl.

## 0.2.0 - Inter typography

Base: 0.1.0.

**Safety status: no write behavior exists in this version.** No database is
opened, no `history/` or `history_v2/` file is read or written, and no
`::settings` value is modified. The skin only draws.

- `fonts/`: Inter Regular / SemiBold / Bold for UI text, NotoSansMono
  SemiBold / ExtraBold for numbers (both proven on this tablet by DSx2 and
  Streamline). New `font_data` role (mono, 26 px) for tabular values.
- `::lumen::_load_font_families` resolves each TTF to a family name via
  `::dui::font::add_or_get_familyname`, with Helvetica/Courier fallback.
- Why not `load_font`: it computes `int(fontm * size)` in points and this
  tablet's `default_font_calibration` is 0.5, so 19 would become 9 pt. Lumen
  takes only the family name and creates fonts at negative pixel sizes with a
  16 px floor; weight comes from the file, `-weight bold` only on the fallback.

Files: skin.tcl, fonts/.

## 0.1.0 - Pass 1: skeleton and static home page

First version.

**Safety status: no write behavior exists in this version.** No database is
opened, no `history/` or `history_v2/` file is read or written, and no
`::settings` value is modified. The skin only draws.

- `skin.tcl`, the whole skin in one file: dark and light palettes
  pre-composited by hand (mode from `::settings(lumen_theme)`, default dark);
  layout token block `_init_layout` in 1340x800 design px with `X`/`Y`
  converting to the 2560x1600 virtual canvas by separate factors (1.9104 /
  2.0); `LUMEN_*` fonts at negative pixel sizes with a 16 px floor;
  `::lumen::glass` rounded panel (mechanism from GrindAdvisor's
  `rounded_rect`).
- Home page: action rail (Espresso, Steam, Water, Flush, Settings, Sleep),
  grind tile, last shot tile, chart panel, next-shot bean strip. Pages
  declared with `-bg_color`, no image assets.
- `standard_stop_buttons.tcl` deliberately not sourced (its stop bindings are
  reproduced verbatim); `standard_includes.tcl` is sourced so the stock
  settings, firmware, descale and profile pages keep working (DSx2's approach).
- Known limitations: placeholder values, empty chart frame, flat background,
  untested on the tablet.

Files: skin.tcl.
