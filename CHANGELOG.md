# Changelog — Lumen

## 0.40.0 — Drink Menu taskbar button

**Safety status: unchanged. No settings writes added; no database, no history files.**

Adds a Drink Menu taskbar button; water readout shifted left by 72 px; no other changes.

- Fifth tappable in the taskbar's right-hand group, leftmost at design
  x 980 (56x48 on the 72 pitch): FA6 `mug-hot` (`[format %c 0xF7B6]`)
  in `font_bt`, text fallback "CUP" through the same mechanism as the
  other four. Tap runs `::lumen::act::open_drinkmenu`, the exact
  `catch` + `info procs` gate + `msg -ERROR` shape of the Maintenance
  shortcut, calling `::plugins::DrinkMenu::open_page DrinkMenu_main`;
  the plugin's page captures "off" as its return target so Done lands
  back here.
- `bar_water_x` 1028 -> 956: the widest readout ("1500 ml", 7 glyphs at
  ~15.5 px in the 26 px mono face) spans 847..956, one lg clear of the
  mug zone and ~150 px clear of the wordmark.
- Housekeeping: the file banner's version line (stuck at 0.35.0 since
  0.35.0) now tracks `variable version`; the taskbar comment counts five
  tappables and drops the pre-0.32.0 "side panel duplicates" note.

## 0.39.1 — the material adds `bg`, the plain page background — TABLET-VERIFIED 2026-09-01 (with GrindAdvisor 3.14.5)

**Safety status: unchanged. One dict key in `glass_material`.**

The consumer's card boundary read as a hard cliff no matter what blend
color it guessed (GrindAdvisor 3.14.1–3.14.3, owner reports). Its
3.14.4 fix rings the card with a crop of the page's own art, so the
overlay boundary lands on pixel-identical pixels — and the material now
carries `bg`, the path to `lumen_home[_light].png`, the very file the
page is built on. Required alongside `glass`/`dim`; all three checked
for existence. Harness H2 updated.

## 0.39.0 — glass material provider for plugin overlays — TABLET-VERIFIED 2026-09-01 (via 0.39.1 + GrindAdvisor 3.14.5)

**Safety status: unchanged. Nothing visible changes in Lumen itself — one
new public proc and eight baked PNGs; no settings writes, no page edits.**

First half of the iOS-style "liquid glass" popup feature (owner request,
2026-09-01): GrindAdvisor's after-shot popup will render as a frosted
translucent card showing the Lumen home screen through it — but only when
this skin offers the material, so other skins keep the opaque popup.

- Tk has no runtime blur/alpha, so `tools/make_backgrounds.py` now bakes
  the material from the home background it already renders:
  `lumen_home_glass[_light].png` (full-screen blur+tint slab the consumer
  crops its card from) and `lumen_home_dim[_light].png` (the home art
  dimmed, for the modal scrim) — both themes, both resolution folders,
  ~730 KB total. Recipe = the owner-approved "variant C" mockup as a
  base, tuned on-tablet 2026-09-01 for "more see-through": dark slab
  blur 16@1340w, tint 16/18/24 @20%, saturation ×1.50, brightness ×1.28
  (hotter than the mock because baked art has no live screen content
  doing half the glowing); light slab blur 20, tint @38%, no boost (a
  boosted near-white page clips to a blank sheet). The consumer
  (GrindAdvisor 3.14.x) settled on a card-only overlay with the live
  page around it, so the `dim` scrim assets are baked and contract-valid
  but currently unconsumed.
- **`::lumen::glass_material`** (new public proc) hands a consumer
  `{ok 1 page off theme dark|light radius 26 glass <path> dim <path>}` —
  and `{}` unless the current page is home AND both files exist for the
  screen's exact physical WxH (consumers draw in physical pixels and
  never rescale; a 1280x800 tablet simply gets no glass). Plugins guard
  with `[info procs]`, so on any other skin the proc is absent and
  nothing changes — the owner's explicit no-glass-off-skin requirement.
  Called once per popup open, never per-tick (it touches the filesystem).
- Harness section H2: material served on home in both themes with
  existing files, refused off-home / for unknown resolutions, and quiet
  with no page context. Regenerating the backgrounds was byte-identical
  for all existing PNGs — only the eight new assets are new.
- Known honest limit, stated up front: the glass shows the skin's baked
  *art* through it. Live values (tile numbers, chart traces) are drawn by
  the app above the bake and do not bleed through the slab; the on-device
  look is therefore a touch subtler than the screenshot-sourced mockups.

Next half: the GrindAdvisor consumer pass (opaque fallback everywhere the
material is absent), then Lumen's own settings/flow pages later.

## 0.38.0 — the grind tile shows GrindAdvisor's new-bag starting estimate — TABLET-VERIFIED 2026-08-29

**Safety status: unchanged. Read-only accessors; no bake, no settings
writes. The one new plugin call reads SDB through GrindAdvisor's own
public, SELECT-only path.**

GrindAdvisor 3.13.0 (tablet-verified today) added `starting_estimate`: a
display-only starting grind for a bag with **no shots yet**, borrowed from
already-calibrated bags (same coffee → same roaster → same profile, median
of converged ideals). Until now the tile could only show `--` and "pull a
shot" for a fresh bag; this pass is the skin half of the feature, the
expose-only follow-up the plugin's pass planned.

- **`::lumen::data::grind_est`** — the cached bridge. GrindAdvisor's
  contract says `starting_estimate` must never run on a per-tick path (it
  reads SDB, unmemoized), so the skin caches the result **per bag key**:
  `current_bag_key` (tick-safe by design, GA v3.7.0) is compared each
  tick, and the one SDB read happens on the first tick after the key
  changes — misses ({}) are cached too. No invalidation needed beyond the
  key change: after the bag's first shot,
  `recommendation_for_current_bag` returns a real rec and every accessor
  prefers it. Guarded for older GrindAdvisors (`info procs`), throwing
  plugins, and junk dicts — all degrade to the plain new-bag tile.
- **Tile in the estimate state**: header **STARTING ESTIMATE** (the
  header label is a live accessor now, `grind_header`, because
  GrindAdvisor's display contract forbids captioning an estimate
  "Recommended"), hero **~13.5** (the `~` marks the borrowed number),
  method chip **Estimate**, band = GrindAdvisor's reason string
  ("Starting estimate: same roaster (4 bags)"), note =
  "Start ~13.5 (est. from 4 bags) - pull a shot to calibrate" (57 chars
  worst case — single line in the note's 560px budget).
- With a recommendation present, with no candidates, on older
  GrindAdvisor builds, or with the plugin absent, every accessor renders
  exactly what 0.37.1 rendered — byte-for-byte, pinned by the harness.
- `tools/check_skin.tcl` gained section **H**: the five accessors in the
  estimate state, the no-"Recommended" sweep, cache behavior (one SDB
  read per bag key, one recompute per key change, misses cached), the
  pre-3.13.0 / throwing / hostile-dict degradations, and rec-beats-
  estimate. Also fixed a harness self-parse trap: a literal `{{{` junk
  string inside a braced list breaks the file's own brace balance — the
  junk is built with `string repeat` now.

## 0.37.1 — the chip stays inside the button and matches its corners

**Safety status: unchanged. Two numbers in press_flash.**

Owner report on 0.37.0: the zone chip read slightly larger than the
pill with sharper corners, overlapping the button's rounded edge. Root
cause: a `-smooth 1` canvas polygon renders roughly HALF the curvature
of its control-point radius, so the chip's nominal 16-design-px corners
rendered sharper than the pills' true 16px arcs — and at a 1px inset
the sharp corners poked outside. Fixes: inset 1 → 3 design px (the
chip now sits inside the control) and the corner control radius
over-provisioned to ~28 design px so the RENDERED curve matches the
pills (the half-size clamp keeps small chips pill-ended). The card
ring got the same correction (48 → 96 virtual control radius for its
24px baked corners). Lesson for any future smoothed-polygon "rounded
rect": feed ~double the target radius.

## 0.37.0 — press flash Option B: a chip that fits what you see

**Safety status: unchanged. Flash mechanics only; no bake, no settings
writes.**

Owner reviewed the 0.36.0 flash on-device ("still a yellow rectangle
that don't fit"), picked Option B from the interactive sample page. The
root problem was that the flash painted the TAP ZONE, which on the grind
card and the text links is far bigger than the visible control.

- `::lumen::tap` gains a per-zone STYLE (default `zone`), passed through
  to `press_flash`:
  - **zone** — neutral chip over the whole zone: `glass_2` fill,
    `glass_brd` hairline, lowered beneath the control's label, stepped
    to `glass` at 90 ms. Right for every control whose zone IS its
    drawn bounds: baked pills, steppers, taskbar glyphs, Done, THEME,
    CLOCK... (all 30 of them keep the default).
  - **label** — chip fitted to the control's VISIBLE text: the visible
    text items inside the zone are unioned via `.can bbox`, padded
    10x6 design px, clamped to the zone. Applied to the five text-y
    zones: Shot history, Curve, Shot analysis, the PROFILE identity
    row, and the steam/water mode line. Falls back to the zone chip if
    no text is found.
  - **ring x y w h** — hollow crema hairline around the CONTAINER the
    zone belongs to, in design px. Applied to the grind card's two
    body zones, which now ring the whole card (its real drawn edge, 24
    design-px corners) instead of flooding it.
- The crema-filled zone chip of 0.36.0 is gone; crema now appears only
  as the card ring. Chip corners stay the pills' RADIUS_S.
- Harness section L rewritten: the coords-match pattern accepts the
  style word, and `_flash_case` drives all three styles against a
  context-aware canvas stub (bbox/type/state), asserting the zone chip
  fills the zone, the label chip hugs the stubbed text bbox, the ring
  is hollow on the exact card rect, and all three keep the shared tag,
  the clear-first rule and the 150 ms delete. Both harnesses green.

## 0.36.0 — chart pills gone, press flash is a chip, grind card opens Grind Advisor

**Safety status: unchanged — Lumen still opens no database and writes
no history file. This version REMOVES two settings writes (the
smoothing and stages toggles are gone). Home + settings backgrounds
re-baked.**

Owner's three fixes, one pass:

- **Stages and Raw/Smooth pills removed from the chart** (both the tap
  zones and the baked pills). The chart is now always smooth
  (Catmull-Rom) with stage separators shown — `chart_smoothing` /
  `stages_shown` became the fixed policy both chart builders read.
  Deleted with them: the two toggle actions, the smoothing/stages label
  accessors, the orphaned `smoothing_note`, `chart_apply_smoothing` /
  `chart_apply_stages` and the `chart_widgets` registry they iterated.
  `live_graph_smoothing_technique` and `lumen_chart_stages` are no
  longer read or written (a stock-skin smoothing preference no longer
  affects Lumen's charts).
- **Press flash is a filled chip now, not a ring.** The 0.29.1 ring
  looked right on baked pills but drew a floating empty rectangle
  around text links (Shot history, Curve — owner report). The flash is
  a crema-tinted filled rounded chip with a thin crema border, LOWERED
  beneath the control's own label: canvas items stack in creation
  order, so the fresh flash is slid to just below the lowest visible
  text item overlapping the zone — above the baked background and
  pills, below every label. A chip materialises behind the text like a
  real pressed button, on pills and text links alike. Border thinned
  6 → 3 design px; 150ms lifetime and the one-shared-tag rule
  unchanged.
- **The grind card opens Grind Advisor's settings.** Tap zones A and B
  (the card body and the bottom row left of Curve) now call
  `open_grind_advisor`; the "Shot analysis" text link (zone C) keeps
  the result popup and Curve is unchanged. The Lumen settings page's
  GRIND ADVISOR row is REMOVED — CLOCK moved up into its slot, the
  right column is three rows (THEME / BAGS TO CYCLE / CLOCK), and
  `settings_button_row` went with its last caller.
- Re-bake: the 8 home + settings images changed (both themes, both
  resolutions), the 8 flow images byte-identical, chart_bg samples
  unchanged (#151618/#DEE0E4 home, #171719/#DEE1E4 flow) so no palette
  edits. Both harnesses green: 38 zones flash with their own
  coordinates (down 2 for the pills), section-L glow behaviour passes
  on the new chip, sections M/N untouched.

## 0.35.0 — NEXT SHOT card: PROFILE stacked under the label

**Safety status: unchanged. Text and tap-zone geometry only; no bake.**

Owner request: the NEXT SHOT card's "PROFILE Gentle and sweet" moves to
its own row under NEXT SHOT, matching the LAST SHOT card's stacked order
(label / PROFILE / roaster / hero) so the two cards read as a pair again.

- This reverses half of 0.27.0 (which merged PROFILE into the label row
  to buy even 11px gaps). Six rows in the block's 148px cannot keep 10px
  gaps, so the block re-spaces to a UNIFORM 7px gap with a 10px top pad:
  label 584, PROFILE 606, roaster 629, hero 652 (→692), notes 699
  (→715), action row untouched at 722. Evenness was the other half of
  the 0.27.0 lesson — nothing is singled out as wedged.
- The PROFILE value gets the block's full width (was 255 sharing the
  label row), and the profile tap zone moves onto its row (40,592
  460x44 — contains the row, ends above the hero).
- Harness: id_prof_y back in the row-order check; the identity gap floor
  is 7 for this six-row layout (comment documents the escape hatches if
  it reads cramped on the tablet); profile-zone assertions reworked.
  Both harnesses green.

## 0.34.1 — spacing fixes (owner report on 0.34.0)

**Safety status: unchanged. Geometry only.**

- The taskbar day label touched the 12-hour time's "AM": the 0.34.0
  position was placed on a 13px/glyph estimate, but the tablet's 26px
  mono advances ~15.5px. Day moved 130 → 170 (~30px clear of the widest
  zero-padded time); the harness estimate corrected to 16px/glyph.
- The tiles' bottom text rows (Fair/Curve/Shot analysis, Shot history)
  crowded the card border: the 8px the top cards gave the 0.31.0 taskbar
  was too much (flagged then as a watch-item, now owner-confirmed).
  Cards back to h 190 (ends 254), the chart pays instead (270..558,
  h 288). Every internal row keeps its original clearance with zero row
  edits — the grind tile's rows are grind_y-relative and the last-shot
  card's absolute rows now simply have their 14-18px back.
- Re-bake: only the four `lumen_home*` PNGs changed; `chart_bg` samples
  unchanged. Both harnesses green.

## 0.34.0 — taskbar wordmark + water readout; CLOCK formats row

**Safety status: unchanged. No new reads or writes beyond two new
`lumen_*` preference keys saved through the standard `save_settings`
path.**

Four owner requests in one pass:

- **Water level moved to the taskbar** (from the last-shot card's
  corner): machine status belongs on the status bar. Same accessor, same
  blue mono, anchored right of centre one gap clear of the wrench zone;
  blank whenever the machine has not reported in 10s. The card corner is
  empty again.
- **"Lumen" wordmark** dead-centre on the bar — passive, muted, not a
  tap target.
- **DECENT APP removed from Lumen settings** — redundant since the
  taskbar's sliders icon (0.32.0, tablet-verified) opens the same
  place. Its bottom-right row is now **CLOCK**.
- **Time and date format options** on the CLOCK row: a 24H/12H toggle
  and a date toggle showing a live sample ("26 Aug" ↔ "Aug 26"). New
  settings `lumen_time_format` / `lumen_date_format`, defaults matching
  0.31.0 exactly (24h, day-month); the bar picks changes up on the next
  200 ms tick — no restart. The 12-hour time is zero-padded on purpose
  ("08:05 AM") so the widest time is constant-width, and the day label's
  fixed x moved 110 → 130 to clear it.
- Re-bake: only the four `lumen_settings*` PNGs changed (DECENT APP's
  accent pill out, two raised CLOCK pills in); home and flow images
  MD5-identical.
- Harness: section E updated for the moved readout (and asserts
  water_label stays deleted), section N added (all four format
  combinations by regexp, toggle persistence, live button labels),
  settings-page bottom-right assertions now expect the two CLOCK
  toggles, new taskbar spacing checks (water vs wordmark vs wrench, 12h
  time vs day label). Both harnesses green.

## 0.33.0 — taskbar pass 3 of 3: side panel absorbed, full-width strip

**Safety status: unchanged. No new reads or writes; Profile's tap calls
the same `open_profiles` the deleted panel button called.**

The owner's Layout 2 end state, landed only after the 0.32.0 taskbar was
tablet-verified carrying Settings and Sleep — the skin was never left
without a way back to the skin picker.

- Side panel deleted (panel, three pills, three tap zones). The bean
  strip takes its 184px: full content width, 16..1324.
- Stepper columns re-spread on the wider strip: 270 pitch (was 210),
  value spans 140 (was 76) — "38.0 (1:2.0)"-class strings finally fit —
  groups 240 wide, flush at the 1300 inner edge. Bottom row (readout /
  Set dose / Scan bag) widened to 240 on the same grid, ending flush and
  staying LEVEL with the identity block's action row.
- Profile is now a tap on the identity row's PROFILE label+value
  (zone 170..500, 48 tall, hanging into the chart-strip gap so it clears
  the roaster line — zones may not overlap each other, and nothing else
  taps there). Same `open_profiles` → stock settings_1 tab as before.
- Second re-bake: only the four `lumen_home*` PNGs changed, all twelve
  others MD5-identical; `chart_bg` samples unchanged (the chart did not
  move).
- Harness: side-panel checks replaced by PROFILE-zone checks (floor,
  label+value coverage, roaster clearance, full-width strip); 40 zones
  flash-covered (−3 panel, +1 profile). Both harnesses green.

## 0.32.0 — taskbar pass 2 of 3: tappables + maintenance dot

**Safety status: read access widens by one guarded case — the taskbar dot
reads `::plugins::MaintenanceTracker::status_summary` (cache-backed on the
plugin side) through the standard info-procs + catch + degrade guard.
Nothing written; the wrench opens the plugin's own page via its public
`open_page`, same contract as the Shot History and Grind Advisor
shortcuts.**

- Four tap zones on the bar, right-aligned in escalating consequence
  toward the corner: wrench (Maintenance Tracker), gear (Lumen settings),
  sliders (app settings), moon (Sleep). 56x48 each on a 72 pitch, ending
  flush at the 1324 margin; all through `::lumen::tap`, so press flash
  and sound come free. Glyphs from the app's own FA6 Pro font
  (`F(symbol)`, the BT-glyph precedent) as `[format %c ...]` escapes,
  with letter fallbacks (MNT/SET/APP/ZZZ) if the font failed to register.
- Maintenance state dot at the wrench zone's top-right corner: amber for
  "due soon", red for "overdue", nothing when all is well, when the
  plugin is absent, or when anything about the read is off. Two stacked
  fixed-colour items (the settings mode-line pattern); accessors ride the
  200 ms tick against the plugin's own cache.
- New palette token `C(danger)` (#DA515E dark / #B23641 light) — the
  palette had no red that wasn't a chart series colour.
- New guarded action `::lumen::act::open_maintenance` on the
  shot_history template; Sleep calls the app's `start_sleep` exactly as
  the side panel does. The side panel still duplicates Settings/Sleep
  deliberately — it is removed in pass 3, after this bar is
  tablet-verified.
- No bake: icons and dot are text on the gradient; all sixteen PNGs
  untouched.
- Harness: taskbar zone budget checks (order/pitch/flush/floor, dot over
  the wrench) and a new section M driving the dot accessors through
  absent / ok / amber / red / failed / malformed / throwing plugin states.
  42 zones now covered by the flash check (was 38). Both harnesses green.

## 0.31.0 — taskbar pass 1 of 3: geometry, re-bake, live time

**Safety status: unchanged. No new reads, no writes, no plugin calls. The
two new accessors (`bar_time` / `bar_day`) call only `clock`, on the app's
existing 200 ms variable tick.**

First of three passes building the top taskbar (owner picked Layout 2 —
"panel absorbed" — from the discovery report; the panel work lands in pass
3). This pass carves the bar's space and puts the passive time/day on it;
tappables (maintenance dot, gear, app settings, sleep) come next pass, so
the side panel keeps Settings/Sleep for now — the unverified bar must
never be their only home.

- New geometry: taskbar 0..48; top cards 64..246 (h 182, −8); chart
  262..558 (h 296, −40); bean strip and side panel untouched at 574..784.
  The donors follow the discovery pass: the chart plot is the least
  information-dense loss on the page, the cards' 0.23.0 budget had ~14 px
  genuinely spare. The last-shot tile's absolute row tokens all moved
  +48; the grind tile's rows hang off `grind_y` and moved for free.
- Time (mono, `%H:%M`) and day (`%a %d %b`, caption) sit naked on the
  baked gradient at the bar's left — the bar itself bakes nothing. They
  ride the 200 ms onscreen-variable tick like every other live label
  (dui only reconfigures on change, so the canvas redraws once per
  minute).
- All four `lumen_home*` PNGs re-baked (both themes, both resolutions);
  the generator's `HOME_PANELS`/`HOME_INNER`, home bloom, and `chart_bg`
  sample point (now y 410) mirror the new tokens. The twelve settings and
  flow images came back **byte-identical** (MD5-verified) per the
  image-diff discipline. Light `chart_bg` re-sampled: #DEE0E5 → #DEE0E4;
  dark unchanged.
- Harness: new taskbar budget checks (bar ≥ 44, bar→tiles gap ≥ md, top
  cards level); fixed a latent harness fault the clock exposed — `clock
  format`'s lazy autoload dies under the stubbed `source`/`package`, so
  the harness now pre-warms it before installing the stubs. Both
  harnesses pass: ALL CHECKS PASSED / LAST-SHOT LOADER CHECKS PASSED.

## 0.30.0 — the chart follows the bag cycler; the flash ring hugs the control

**Safety status: unchanged. Read access widens by one case: the loader can
be pointed at a SPECIFIC `history/*.shot` file (the cycled bag's newest)
instead of only the newest overall. Same single-file read, same local
parse, same `history_saved` guard. Nothing written.**

Two owner requests:

**The chart and LAST SHOT card follow the bag cycler.** Since 0.22.0 the
grind tile has shown the cycled-to bag's own recommendation — but the chart
and card stayed on the globally newest shot. Now `cycle_bag` resolves the
bag's newest shot FILE and loads it: chart, card, profile, all describing
the bag on screen. Mechanics worth keeping in mind:

* No new SDB API: shot filenames ARE clocks (`%Y%m%dT%H%M%S`), the same
  matching rule SDB itself uses, so the clocks the cycler already has
  resolve to paths directly (`_bag_last_shot_file`).
* A clock whose file is soft-deleted is skipped — the bag falls back to
  its next-newest shot still on disk; a fully-trashed bag leaves the chart
  as-is with a NOTICE.
* A failure to load never undoes the cycle itself, which has already
  succeeded by then.
* `load_last_shot_curves` gained an explicit-path mode (third argument);
  the plain and force behaviours are byte-identical without it.

**The flash ring matches the control (0.29.1 feedback).** Inset drops from
5px to 1px — stepper pill tap zones ARE their drawn bounds, so the ring now
sits on the pill's edge instead of floating inside it — and the corner
radius is the baked pills' own `RADIUS_S` (16 design px), so the ring's
corners follow the pill's corners exactly.

`check_last_shot.tcl` section J covers the new loader paths: explicit file
loads over a newer one, a missing path refuses without clobbering the
latch, the resolver skips trashed files, and clock and filename in the
fixture derive from ONE `clock scan` — hand-typing both is how a fixture
silently stops testing anything.

## 0.29.1 — the press flash is a clean accent ring, not a stipple

**Safety status: unchanged — drawing options inside `press_flash` only.**

Owner-reported within minutes of 0.29.0 going live: the flash "looks like a
graphics bug". It did. `-stipple gray25` is a raw 4x4 pixel checkerboard —
Tk's only stand-in for alpha — and on a high-DPI panel a pixel mesh laid
over a button reads as rendering corruption, not as a glow.

The flash is now a **hollow crema ring**: a crisp 3px+ accent outline in the
control's rounded shape, inset a few px so the stroke sits inside the
control's visible edge, no fill at all. Reads as a deliberate focus ring,
and the button's own label stays fully visible under it. Same 150ms life,
same shared-tag lifecycle, same structural coverage in section L (the inset
ring still satisfies the points-inside-the-zone assertion by construction).

## 0.29.0 — every tap gets a visual press flash

**Safety status: unchanged. One new drawing helper and one line in `tap`.
Nothing written, no file handling, no page structure changes.**

Owner request: the buttons felt "flat and dead". They are — every control
is pixels baked into the background image with an invisible zone on top,
so nothing could react natively. There was sound feedback (`tap` already
plays `sound_button_in`) but nothing visual.

* **`::lumen::press_flash`** draws a brief crema glow in the tapped zone's
  own rounded shape — `-stipple gray25` fakes a 25% glow, since Tk canvas
  has no alpha — outlined in the accent, gone after 150ms. It reads
  correctly on both themes because it is built from the palette.
* **Wired inside `tap`**, so all 38 interactive zones got it in one line:
  cards, pills, steppers, links, toolbar, settings rows. `update idletasks`
  fires before the button's command runs, so the glow paints even when the
  command opens a page or queries a plugin — feedback after the fact is no
  feedback.
* **The five full-screen flow-stop zones deliberately do not flash** — they
  bypass `tap` (they are the core's verbatim stop bindings), and a
  whole-screen strobe mid-shot is not feedback; the page change is.
* A new press clears the previous glow first, so drumming on a stepper
  reads as one live glow rather than a stack; a glow that outlives an
  instant page switch dies on its own 150ms timer.

`tools/check_skin.tcl` section L asserts all of it structurally: every
recorded button either carries a flash with **its own zone coordinates** or
is a full-screen stop; and the glow itself clears its predecessor, stays
inside the zone, carries the shared tag, and schedules its 150ms clear.

## 0.28.1 — stepper acceleration only on genuinely rapid taps

**Safety status: unchanged — one timing constant in the stepper
acceleration. No file handling, no page changes, nothing written.**

Owner-reported on the grind stepper: tapping **+** at a careful pace was
counted as fast tapping, so deliberate 0.1 nudges escalated to 0.5
mid-adjustment.

The shipped window was 700ms — and a measured step-step-step pace is
roughly 500–700ms per tap, so it landed inside. The window is now
**350ms**: escalation requires drumming on the button (3+ taps a second),
and any measured pace stays at 0.1 no matter how many taps it runs to.
Thresholds unchanged (0.5 after three rapid taps, 1.0 after six; pause or
direction change resets).

`tools/check_skin.tcl` section K drives `_accel_step` on a fake clock:
10 taps at 600ms (the reported pace) and at 400ms stay 0.1 throughout,
250ms drumming escalates on schedule, and both resets hold. Verified
against the old 700ms window, where the 600ms case escalates exactly as
reported — the complaint, reproduced.

## 0.28.0 — the home page follows Shot History Editor changes — TABLET-VERIFIED 2026-08-24

**Safety status: unchanged. No database is opened, and nothing in `history/`
or `history_v2/` is written, renamed or deleted. This version adds a REREAD
of the newest shot file — the same single-file read the skin has done at
startup since 0.24.1 — triggered by ShotHistoryEditor instead of only by
startup.**

Owner goal: edit or delete a shot in ShotHistoryEditor, return to the home
screen, and see everything updated — the Grind Advisor card, the chart, and
the LAST SHOT card. The Grind Advisor card already followed (SHE v0.6.3 +
polled bindings); the chart and card did not, because
`load_last_shot_curves` only ever ran at startup: its guard refuses whenever
the vectors hold samples, and after startup they always do.

* **`load_last_shot_curves` grows a `force` reload path.** The plain call is
  byte-identical (same guard, same everything) — proven by the harness, whose
  first reload case shows the plain call still refusing. Force swaps the
  guard for the real "shot in progress" signal: `history_saved`, zeroed at
  shot start (machine.tcl:846) and set on save — and set by our own startup
  load. Force with `history_saved 0` refuses, loudly.
* **`last_shot_rec` is cleared before repopulating.** It was add-only, which
  was invisible at startup (empty array) but wrong on reload: delete the
  newest shot, and if the previous shot's file lacks a value the deleted
  shot's number lingered on the card. The harness traps this with a
  yield-less file.
* **`::lumen::refresh_after_history_change`** is the public entry point SHE
  v0.7.0 calls: force reload + `refresh_bag_list` (SDB has just been
  resynced by Grind Advisor's step, so a bag whose only shot was deleted
  leaves the cycler). Callers guard on `info procs`, so other skins skip it.
* **The chart and card need nothing else**: chart elements are bound to the
  BLT vectors, so refilling redraws; the card reads `last_shot_rec` through
  polled `var` bindings.
* **The 0.27.1 flush trap stays closed**: every reload path ends with
  `history_saved 1`, asserted by the harness after each reload case.

`tools/check_last_shot.tcl` section I drives all of it against real files:
plain call refused, force refused mid-shot, delete-the-newest lands the card
on the previous shot, sparse file drops the stale yield, flush trap closed.

## 0.27.2 — the method chip showed a raw GrindAdvisor key — NOT YET TABLET-TESTED

**Safety status: unchanged. No database is opened, and nothing in `history/`
or `history_v2/` is written, renamed or deleted. This version changes one
label map and one character budget; it touches no file and no shot data.**

Spotted on the tablet: the method chip on the RECOMMENDED GRIND card read
**`regression_unt...`** — an internal dict key, truncated, ink to the rounded
ends of the chip.

GrindAdvisor 3.10.0 added a fifth forecast rung, `regression_untrusted` (the
R² guard: the times are not tracking grind on this bag, so the fitted line is
discarded and the ladder answers instead). `::lumen::data::grind_method` keeps
its own short-label map for the 150px chip, and it still had four arms, so the
new rung fell through to the fallback that shows the raw method name.

* **`regression_untrusted` → "Weak fit"**, in the terse register of the other
  chips ("2-shot", "Regression", "Pairwise"). The card already carries the
  full sentence underneath — *"Shot times are not tracking grind on this
  bag"* — so the chip only has to name the rung.
* **The fallback budget drops from 16 characters to 12.** 16 was picked
  without measuring. Measured off the tablet screenshot it is ~134px of text
  in a 150px chip — no margin at either end. `font_label` is 16px Inter
  SemiBold, ~8.4px per character, so 12 characters is ~100px and sits inside
  the chip properly. The fallback is still there: an unknown rung shows
  something rather than blanking the chip.
* **`tools/check_skin.tcl` section G** now proves every rung has a chip label.
  Not from a hand-written list — a stale hand-written list is exactly what
  failed twice here. Where the workspace has the plugin, it reads the rung
  names out of `GrindAdvisor.tcl` (every literal assigned to `method`) and
  runs each through the real accessor, asserting the chip is non-empty, is
  not the key, has no underscore, and fits 12 characters. Away from the
  workspace it falls back to the rungs known as of GrindAdvisor 3.10.1.
  Negative-tested against the 0.27.1 map, where it reproduces
  `regression_unt...` and fails.

GrindAdvisor 3.10.1 fixes the same gap in its own map, which is what the Why?
dialog and the diagnostics use. The two maps are separate on purpose — the
plugin can spell the rung out, the chip has 150px — but they have now gone out
of step twice, which is what section G is for.

## 0.27.1 — a flush could overwrite the last shot's file — NOT YET TABLET-TESTED

**This one destroyed real data on the tablet, and the exposure was ours.**

### What happened

The 18 August shot file was rewritten by a **flush** the next morning:

| | before | after |
|---|---|---|
| `grinder_setting` | 8 (corrected in Shot History) | 7.5 (the live setting) |
| `drink_weight` | 37.8 | 0 |
| file size | 29,948 bytes | 21,506 bytes |

From the tablet's own log:

```
01:39:30  Lumen: loaded last shot curves from 20260818T164430.shot
11:42:28  DE1 major state change: Idle => HotWaterRinse, pouring
11:42:38  Saved this espresso to history        <-- the flush did this
```

No espresso ran between those lines. The file's mtime is 11:42:38 to the
second, and Shot History Editor's log has no entry there — it was not an edit.

### Why

The core registers its save on **`after_flow_complete`**, which fires after
*any* flow — flush and steam included (`vars.tcl:3440`). Its entire guard is:

```tcl
!$::settings(history_saved) && [espresso_elapsed length] > 5
                            && [espresso_pressure length] > 5
```

and the filename is built from `::settings(espresso_clock)` — still pointing
at the *previous* espresso (`vars.tcl:3452-3457`). It never checks that the
flow which just completed was an espresso, nor that the samples in the vectors
belong to this session.

**`load_last_shot_curves` fills exactly those vectors at startup**, so the
home chart can show your last shot. That is what makes the guard pass. The
write is the core's; the condition is ours.

### The fix

One line, after the vectors are loaded:

```tcl
set ::settings(history_saved) 1
```

`history_saved` means "the samples currently in the vectors have been written
to history". Having just read them *out* of history, that is exactly true —
this is not a workaround, it is the flag telling the truth.
`reset_gui_starting_espresso` sets it back to 0 when a real shot starts
(`machine.tcl:846`), so genuine shots still save normally.

### Recovering the damaged file

Shot History Editor's own backups have it intact:
`backups/20260819T002956_0d17/20260818T164430.shot` — 29,948 bytes,
`grinder_setting 8`, `drink_weight 37.8`.

### Harness

`check_last_shot.tcl` now sets `history_saved` to 0 before calling the loader
— the state that caused the loss — and asserts it comes back 1. The failure
message names the consequence rather than the symptom: *"a flush would
overwrite it"*.

## 0.27.0 — the bag cycler gets a page indicator, and room to breathe — NOT YET TABLET-TESTED

**Safety: display only. No new writes; the cycler still hands the bag change
to DYE's own `source_next_from`, as before.**

Four owner requests, all on the next-shot card.

### The arrows are a stepper pill's size

They were 120x48; they are 44x48 now, the same as a `-` / `+` pill. **Edit
stays between them**, which is the arrangement 0.23.0 introduced precisely so
a mis-tap on one arrow cannot land on the other and send you the wrong way
through the bags.

A first cut moved them up to flank the bag name at the identity block's two
edges. **The preview killed it before anything was baked:** the right arrow
landed 20px from the GRIND column's minus pill, at the same size, the same
shape and the same height — it read as one of GRIND's controls. There is now
an assertion that the arrows never share the stepper pills' row.

### The minus sits where the plus sits

Measured on a tablet screenshot rather than guessed. Against a pill centre of
y=666, the ink was:

| glyph | ink centre | offset |
|---|---|---|
| `-` | 668.5 | **+2.5** |
| `+` | 666.5 | +0.5 |

Tk centres the text *bounding box*, and a hyphen's ink is not centred inside
that box the way a plus sign's is. Every stepper in the skin now lifts the
minus by 2 design px (`L(step_minus_dy)`), which puts the two glyphs on the
same line as each other. Four drawing sites, one token.

### A page indicator, and no more wrap-around

One dot per reachable bag, filled for the one loaded, leftmost being the most
recent — the direction the left arrow moves in.

**The cycler no longer wraps.** Running off either end does nothing now.
Wrapping made every bag look alike; you could not tell the newest from the
oldest, which is exactly what the owner wanted to see at a glance.

Two implementation notes worth keeping:

* The dots are **text, not canvas ovals**. A canvas item's `-fill` is fixed at
  creation, so N ovals would need retagging and reconfiguring on every cycle,
  while a text item is re-evaluated on the refresh tick for free. Both glyphs
  (U+25CF, U+25CB) were verified present in the shipped Inter faces before
  being used, and go through `[format %c]` rather than literal UTF-8.
* The **bag list is cached** (`::lumen::bag_list`, refreshed on the home
  page's `show` and once at startup). The indicator needs to know how many
  bags there are on every 200 ms tick, and asking SDB that often is exactly
  what the accessor rules forbid. Only the index is computed live — an
  `lsearch` over at most 10 strings already in `::settings`.

### The card was too tight

Owner: *"now the space will be very tight, improvise and better rearrange the
next shot card"*. The gaps around the 40px hero name were 4px above the notes
and 9px below them. They are an even **11px everywhere** now.

The row that paid for it is the old dedicated PROFILE line: `NEXT SHOT` only
ever used the left third of its row, so PROFILE moved up beside it — a whole
24px row recovered without dropping anything. The bag name also gets the
block's full 460px back, since the arrows no longer flank it.

There is a check that every gap in the block is at least `sm`, so the next
thing added here cannot quietly re-crowd it.

### Harness

New section **J**: the indicator across six states (newest / middle / oldest
loaded, a bag outside the window, a single bag, no bags), and the end stops —
that the cycler refuses to run off either end, still moves in the middle, and
still recovers to the newest bag from a bag outside the window.

## 0.26.1 — the last shot is the newest SHOT, not the newest FILE

**Safety unchanged: one file read, nothing written.**

Caught in the tablet log minutes after 0.26.0 went on:

```
Lumen: loaded last shot curves from 20260715T170133.shot
```

A shot from **15 July** was being presented as the last one — its curves on
the home chart, its grind, dose and yield on the LAST SHOT card — because
`load_last_shot_curves` picked the file with the newest **mtime**.

mtime is "when did anything last touch this file", not "when was this shot
pulled". Correcting a shot's metadata in the Shot History Editor touches it,
and as of ShotHistoryEditor v0.6.0 it deliberately stamps the time so SDB will
re-read it. So **every metadata edit promoted that shot to "last shot" on the
home page** until the next real shot was pulled. In this case the trigger was
the restamp of that July file, done an hour earlier to make an old correction
visible to SDB.

The app names every shot file `YYYYMMDDTHHMMSS.shot`, so sorting the names is
sorting by shot time. That is what the loader does now. mtime survives only as
a fallback for a file whose name is not a timestamp, and only when no file has
a parseable one.

**The fix in one line: the two plugins are right to touch mtime — the skin was
wrong to read it as a clock.**

### Harness

`tools/check_last_shot.tcl` builds two shots now, and sets the OLDER one's
mtime a day AHEAD of the newer one — exactly the state an edit leaves behind.
The existing assertions do the rest: an mtime-based loader latches "Old
profile" and 8.5, and the test fails.

It also asserts the trap itself is live (`older shot 86400s NEWER on disk`)
before relying on it. Without that check, a fixture whose mtimes silently
stopped differing would pass whether or not the bug was present — a test that
proves nothing while looking green.

## 0.26.0 — STEAM and HOT WATER alternate between two settings — NOT YET TABLET-TESTED

**Safety: display and machine preferences only. No database is opened; the
only file read is the newest `history/*.shot`, as since 0.9.0. The two new
steppers write `::settings(steam_flow)` and `::settings(water_temperature)`,
both clamped, both saved and sent through the same debounced
`save_settings` + `save_settings_to_de1` path the other machine steppers
already use.**

Owner request, from a mockup: one `-/+` group per row, driving whichever half
of the row is selected.

* **STEAM** alternates **TIME** (`steam_timeout`, ±5s) and **FLOW**
  (`steam_flow`, ±0.1 mL/s).
* **HOT WATER** alternates **TEMP** (`water_temperature`, ±1°C) and **VOL**
  (`water_volume`, ±10 ml).

Tap the mode line under the row's label to switch. The choice is a Lumen
preference (`lumen_steam_mode`, `lumen_water_mode`) and persists, so whichever
half you last steered is the one waiting next time.

### How it renders

The selected setting is the 26px value on the pill band's upper line, the
other sits at 16px beneath it — the same two-line arrangement the home strip's
YIELD column already uses for its ratio, so nothing new had to be invented.

The mode line is **two text items, not one**: a canvas text item's `-fill` is
fixed at creation, so the words move between a crema item and a dim one rather
than the colours moving between fixed words. The second item starts at a fixed
offset (`set_mode_dx` 70) so the pair never reflows; the longest first word,
TEMP, is about 40px.

One tap target covers both words. With two modes, "tap the other one" and
"toggle" are the same action, and a single 180x48 target cannot be mis-hit the
way two 60px ones side by side can. It ends at x=374 against a stepper group
starting at 402.

**No background was re-baked.** The panels, the pills and every x coordinate
are identical to `settings_stepper_row`; only what is drawn inside the row
changed.

### The two new steppers

Bounds and steps come from Streamline's own controls for the same fields, not
from guesswork:

* `steam_flow` — 10 per tap and a ceiling of 250, from its steam stepper
  (`Streamline/skin.tcl:2707-2716`). The floor is 40 rather than its 0,
  because 0.4 mL/s is the minimum its own data-entry dialog for this field
  declares (`skin.tcl:1913`) and a tenth of a mL/s is not a steam setting
  anyone should be able to reach by holding a button.
* `water_temperature` — 1 per tap, ceiling 100, from `skin.tcl:2657-2668`. The
  floor is 20 for the same reason.

### Harness

New section **I**: the four display states (each mode of each row, asserting
the mode line and both values), the fallbacks for an unknown or missing mode,
and — the case that actually matters — that a `+` tap moves the **selected**
setting and leaves the other untouched, in all four combinations. Plus both
clamps driven 400 taps in each direction, and a toggle round trip. The
existing bottom-left-card assertion was updated: those pills carry a
direction now (`adjust_water -1` / `1`), not a fixed delta, and it was
printing a warning without failing the run.

## 0.25.0 — the LAST SHOT card reports the shot's own record — NOT YET TABLET-TESTED

**Safety: display only. No database is opened. Nothing in `history/` or
`history_v2/` is written, renamed or deleted — no version of this skin ever
has. Read access is one file: the newest `history/*.shot`, which
`load_last_shot_curves` has opened at startup since 0.9.0; this version takes
three more fields out of the copy it had already parsed.**

**The header's SAFETY STATUS block was wrong** and is corrected here. It
claimed nothing in `history/` was read at all, which stopped being true when
the curve loader was added. A safety note that overstates the case is worse
than none, because the next person trusts it.

### What changed

The card read `::settings(grinder_setting)`, `(grinder_dose_weight)` and
`(drink_weight)` — the machine's **current** settings. Those are the same
fields `shot.tcl` writes into the shot file, so for a shot pulled in this
session the two agree and the distinction is invisible. It stops being
invisible in exactly the case the owner hit:

> *"After I edited the grind setting from Shot History it worked, but it
> didn't update the Grind Advisor recommended value and the last shot card
> grind size."*

The edit **had** worked. The Shot History Editor writes the `.shot` file and
nothing else, by its own design — so the file said `grinder_setting 8` while
the card, reading the live setting, kept insisting on `7.5`. Both numbers were
real; the card was answering a different question than its label promised.

So the LAST SHOT card now prefers what the shot **recorded**:

* `::lumen::last_shot_rec(grind|dose|yield)` is latched from the newest shot
  file's settings block at startup, beside the profile name that was already
  being taken from it.
* Those win over the live `::settings` while they exist.
* They are **dropped when a shot starts** (`latch_shot_profile`, already on
  the espresso page's `show`). From that moment the file is not about the
  last shot any more, and the live settings are precisely what the running
  shot is recording — so they become the better source, not a fallback.

One rule, stated once: **while no shot has run this session the card reports
the file; once one has, it reports the live values that shot recorded.**

The **NEXT SHOT card is untouched** and still reads the live and DYE-staged
values. That is the point of the split: one card is the record, the other is
the plan. There is a harness check that the latch cannot leak into it.

`last_ratio` was reading `::settings(grinder_dose_weight)` directly while the
yield came from the new chain, so it could have derived a ratio from a dose
the card was not showing. It uses the same two accessors as the numbers it
sits between now.

Grind deliberately does **not** go through `_is_pos`: grinder settings are
free text and plenty of grinders are labelled in clicks, letters or
half-steps. Anything non-empty is a real setting. The two weights must be
positive numbers or they are noise.

### What this does NOT fix

**Grind Advisor still will not follow a Shot History edit.** It reads SDB, not
the shot files; the Shot History Editor never writes SDB; `sync_on_startup` is
`0` on this tablet so SDB does not re-read the changed file; and even after a
resync Grind Advisor prefers its saved recommendation while that matches the
loaded bag. Four blocks, none of them in this skin. That is a Grind Advisor
pass.

### Harness

* **G** (yield) gained the case that decides the new precedence: a file value
  and a live value both present, file wins.
* **G2** (new) covers grind and dose across five states — corrected in Shot
  History, live only, file grind only, a non-numeric grind, and nothing at
  all — plus that a starting shot drops the whole latch and that none of it
  leaks into the next-shot card.
* `tools/check_last_shot.tcl` now reproduces the tablet state exactly: file
  `grinder_setting 8` / `drink_weight 37.8`, live `7.5` / `0`, card must
  render `8 19.1 37.8 (1:1.98)`.

## 0.24.1 — the last shot's yield survives a restart — NOT YET TABLET-TESTED

**Safety: display only. No database is opened; the only file read is the
newest `history/*.shot`, which `load_last_shot_curves` was already reading for
the chart and the profile name — one more field is taken from the copy it
already has in memory. Nothing in `history/` or `history_v2/` is written,
renamed or deleted, and no version of this skin has ever written to them.**

Spotted on the tablet in the 0.24.0 screenshot: the LAST SHOT card read
**`YIELD 0.0`** while the grind tile, two inches to its left, described the
same shot as *"yield: actual 37.8g"*. The shot file confirms it —
`20260818T164430.shot` has `drink_weight 37.8`.

Two faults, one line apart:

**1. `::settings(drink_weight)` does not survive a restart.** It is a live
value the app fills at the end of a shot. Force-stopping the app to load a new
skin — exactly what had just happened — brings it back as 0 while the shot
file still holds the real figure. `load_last_shot_curves` already opens that
file at startup for the chart vectors and the profile name, so it latches the
yield too now (`::lumen::last_shot_yield`). No new file access: the field
comes from the settings block it had already parsed into a local array.

The latch is **dropped when a shot starts** (`latch_shot_profile`, already
hooked to the espresso page's `show`). From that moment the file it came from
is not the last shot any more, and quoting its yield for the new one would be
a worse lie than showing nothing.

**2. A missing yield was formatted as a reading.** `_yield_raw` fell through
to `::de1(pour_volume)` and returned whatever it held — including 0 — and
`_num` duly printed `0.0`. It returns `""` now when no source is positive, so
`_num` yields `--`. A shot pulled without a scale has no yield; `--` says so
and `0.0` does not. `last_ratio` reads the same accessor, so the ratio caption
blanks with it instead of deriving `1:0.00`.

The source order is `::settings(drink_weight)` → `::de1(pour_volume)` → the
file latch, i.e. most authoritative first, with the restart-proof one last.

### Harness

New section **G**, five yield states — this session's scale weight, the
volumetric fallback, the post-restart file latch, nothing at all, and junk —
each asserted on both the yield and the derived ratio caption, plus explicit
guards that a zero is never printed as `0.0` and that a starting shot clears
the latch. `tools/` also gained an off-tablet test of
`load_last_shot_curves` against a real `.shot` file on disk (previously only
byte-compiled, never executed off-device), which reproduces the tablet case:
`drink_weight` 0 in settings, 37.8 in the file, card renders `37.8 (1:1.98)`.

## 0.24.0 — water level, Profile shortcut, settings shuffle, flow-timer fix — NOT YET TABLET-TESTED

**Safety: display and preferences only. No database is opened, no file in
`history/` or `history_v2/` is read, written, renamed or deleted, and this
version adds no write of any kind — the Profile button hands off to the app's
own profile page and the app owns everything that happens there.**

Four owner requests, three of them layout.

### Water tank level on the home screen

`WATER` and a millilitre figure in blue, in the top-right corner of the LAST
SHOT card — the one empty region on the page, and where every other skin puts
its tank indicator. Blue (`C(c_flow)`), not the ink scale: it is machine
status, and in ink at that size it read as a fifth shot metric.

`::de1(water_level)` is **millimetres**, already corrected by
`::de1(water_level_mm_correction)` where the notification is parsed
(`de1_comms.tcl:467`). The mm → mL curve comes from the machine's CAD and
lives in the core as `water_tank_level_to_milliliters` (`vars.tcl:3924`), so
that is what converts it — the same call DSx2 makes
(`procs_vars.tcl:470`). The table is never reimplemented here.

The reading is suppressed unless the machine is actually talking to us. The
core seeds `water_level` to 20 before anything has connected
(`machine.tcl:137`), which would render as a confident "537 ml" with no
machine plugged in. `::de1(last_ping)` is the app's liveness stamp and the
water-level notification is one of the things that refreshes it
(`bluetooth.tcl:2640-2645`), so it stays fresh for exactly as long as there is
a reading to show — including while the machine sits idle. The threshold is
the core's own 10 s (`bluetooth.tcl:1693`). The `WATER` label blanks with the
value, so the card never carries a heading with nothing under it.

### Profile shortcut in the side panel

`Profile` joins `Settings` and `Sleep` in the panel right of the next-shot
strip, on top — it is the one you tap during a session, and Sleep stays at the
bottom furthest from a stray thumb. Three 60-tall buttons do not fit the
210-tall panel, so they are 56 now: still well over the 44px touch floor the
cycler arrows are held to, and the same height as the settings page's THEME
button.

It calls `show_settings settings_1` — the stock profile tab, with the profiles
listbox and the explanation chart
(`skins/default/de1_skin_settings.tcl:192, 934`). That is Streamline's own
home-page shortcut (`Streamline/skin.tcl:607`) minus its zoomed-page
bookkeeping. **No custom navigation of Lumen's own**: `show_settings` sets the
next page and sizes the profile scrollbar itself (`gui.tcl:1403-1425`), so
Done returns the same way it already does from DECENT APP, which is
tablet-proven.

### DECENT APP is the bottom-right card

Owner request. It was the second row of the right column; THEME and BAGS TO
CYCLE moved up to take its place and GRIND ADVISOR sits directly above it, so
the page ends on the two "Open" doors with the emphasised one in the corner.

**The left column is untouched** — it is the machine column, and all four of
its steppers (BREW / STEAM / FLUSH / HOT WATER) stay together.

An intermediate build of this version put DECENT APP bottom-**left** and had
to equalise the columns to 492 to fit it: its 200-wide button misses the
caption beside it by 4px inside a 460-wide row. With the button back in the
wide column that is reverted, and the columns are the tablet-verified 460 /
500 again. `_init_layout` says so in as many words, because "tidy the columns
to equal widths" is exactly the kind of change that looks safe and is not.

The rows are drawn through `settings_stepper_row` / `settings_button_row` now.
Re-dealing them between the columns meant the row bodies had to move, and
inline copies would have been several versions of the same row that could
drift apart.

### The timer flashing a high number at the start of a shot

Reported as: *"the timer in the first milliseconds when pulling a shot showed
a high number like 450, then 0, and counted normally."*

`espresso_timer` is `([clock milliseconds] - $::timers(espresso_start))/1000`,
and `start_espresso_timers` — the only thing that resets `espresso_start` —
runs when the machine reaches the flow phase `during`
(`binary.tcl:1507-1527`). The page opens as soon as the machine enters the
Espresso **state**, which is earlier: heating, then preinfusion. In that
window the timer still describes the **previous** shot, so the page reported
the seconds since that shot began. 450 is 7½ minutes since the last coffee —
and `_sane_secs` cannot help, because 450 is a perfectly plausible shot
duration. The same hole exists on steam, water and flush: each would show the
previous flow's frozen total until the new one started pouring.

The accessors now read `::timers` directly through one helper,
`::lumen::data::_flow_secs`, which knows whether the flow it is looking at
belongs to **this** page visit:

* **stop unset, 0, or before start** → the flow is running, count from start.
  Deliberately *not* gated on the open time: a page shown mid-flow (the skin
  reloading, a dialog closing over it) must not blank its timer.
* **stop after start** → the flow has finished. Show its total only if it
  started after this page was last shown, so the final time stays on screen
  after a shot while a flow from an earlier visit reads 0.

`::lumen::latch_flow_open`, hooked to each flow page's `show` action, is what
stamps "last shown". Integer division throughout, matching the core's own
timer procs, so the display truncates rather than rounding up at the half
second.

`_sane_secs` also normalises `-0` now. `flush_pour_timer` returns the literal
strings `"-0"` and `"-1"` when its timer has never been started
(`vars.tcl:504-512`), and `format %.0f` of `"-0"` prints `-0` — so the flush
page could show `-0s`. Reading `::timers` directly retires that path, and the
guard covers anything else that hands the formatter a negative zero.

### Harness

`tools/check_skin.tcl` gained four sections and lost its last hardcoded
settings-page numbers:

* **D — flow timers.** Seven scenarios against `espresso_secs`, including the
  reported bug itself (page opened now, timers holding a shot that started
  450s ago → must read `0s`), a shot running, this visit's finished shot, a
  page shown mid-shot, junk, and negative zero. Then all four accessors
  against four simultaneous distinct flows, which is the 0.23.2 regression.
* **E — water level.** Connected, empty tank, no machine, junk. Asserts the
  label blanks with the value.
* **F — profile shortcut.** `show_settings` is stubbed and recorded, so the
  check is that the button asks for `settings_1` — not merely that it runs.
* The settings-page geometry checks read `L(set_*)` tokens instead of
  restating literals, walk the actual (column, row, control, caption) set
  rather than assuming one control width per column, and assert that the
  bottom-**right** card's tap target really is `open_app_settings` while the
  bottom-left one is still the Hot Water stepper. The row order is the whole
  point of the change, and the background bakes each pill wherever the code
  says it is — so it has to be checked, not eyeballed.
* The side-panel check covers three buttons: order, no overlap, the 44px
  touch floor, and that they still end inside the panel.

The settings row geometry moved out of `build_settings` into
`::lumen::_init_layout` as `L(set_col_l/set_col_r/set_col_w/set_rows/...)`, so
the skin and the harness can no longer disagree about it.
`tools/make_backgrounds.py` still mirrors those numbers by hand — it is
Python — and **was re-run**: the home and settings backgrounds are baked with
the third side button and the re-dealt settings cards. Both chart sample
tokens came back unchanged (`#151618` / `#DEE0E5`, `#171719` / `#DEE1E4`), so
the palette needed no edit.

## 0.23.2 — water and flush pages read their own timers — TABLET-VERIFIED 2026-08-15

Display only, no new writes.

Owner reported the steam / water / flush pages "stuck at 0s", then that it
worked. It did not: **water and flush were both reading `espresso_secs`**,
which is

```tcl
([clock milliseconds] - $::timers(espresso_start)) / 1000
```

— time since the last **espresso** started, not the duration of the current
flow. Right after a shot that produces a number that ticks up and looks
correct, which is why it seemed fine on a retest; more than an hour after the
last espresso it exceeds `_sane_secs`' 3600 ceiling and reads 0. That is the
originally reported symptom. Steam was never affected because it was already
wired to `steam_pour_timer`.

The core provides one timer per flow and starts each on its own state's
"during" phase (`de1app-core/binary.tcl:1509-1527`): `espresso_timer`,
`steam_pour_timer`, `water_pour_timer`, `flush_pour_timer`. New
`data::water_secs` and `data::flush_secs` use the right two.

### Two harness defects this exposed

**1. `espresso_timer` was never stubbed.** The accessors wrap the timer call
in `catch`, so an unstubbed proc silently returned 0 and looked exactly like a
working one. All four timers are stubbed now with *distinct* values.

**2. The harness hardcoded an absolute path to the workspace `skin.tcl`.**
Copying the harness elsewhere to test a modified skin silently re-ran against
the original — so a regression test could "pass" without ever seeing the
change it was meant to exercise. Three attempts at testing this fix were
meaningless before it was spotted. The path is derived from `[info script]`
now, and the harness prints which file it sourced.

### The new check

The first attempt asserted the four accessors return different values, which
proves nothing about **which page uses which** — and the wiring was the bug.
The check now inspects the recorded `dui add variable` calls per page (the
stub keeps the page name for this) and asserts each flow page is wired to its
own accessor. Verified by restoring the old wiring in a copy: it reports

```
*** water IS NOT WIRED TO water_secs ***
*** hotwaterrinse IS NOT WIRED TO flush_secs ***
```

## 0.23.1 — strip rows levelled, even vertical rhythm — TABLET-VERIFIED 2026-08-15

Display only. Two token values.

The strip's bottom row (Connect / Set dose / Scan bag) sat 6px above the
identity block's action row (arrows / Edit) and it showed. `scale_y` 716 ->
**722**, which is `id_act_y`, so all six controls share one baseline and both
columns end together at 770.

The right column is now evenly distributed as well: content 594..770, items
16 + 48 + 48 = 112, leaving 64 as **32 above the steppers and 32 below**
(previously 35 and 24). `step_y` 644 -> **642**.

Measured on the baked asset to confirm rather than eyeballed: the arrows,
Edit, scale readout and Set dose all span y 722..769 at 48 tall, and the
stepper pills span 642..689 — so both gaps are exactly 32.

Three harness assertions added so these cannot drift again: the two rows must
share a y, they must share a height, and the right column's two gaps must be
equal.

## 0.23.0 — re-proportioned home, bean details on both cards — NOT YET TABLET-VERIFIED

**Safety status: no new writes and no new settings.** Layout and display only.

Owner mockup. The two top cards were taller than their content needed while
the next-shot card — the one you actually operate — was the most cramped.

| | before | after |
|---|---|---|
| top cards | 16..252 (h 236) | **16..206 (h 190)** |
| chart | 268..600 | **222..558 (h 336)** |
| bottom row | 616..784 (h 168) | **574..784 (h 210)** |

Every gap is still `md` (16) and the bottom margin is still 16.

### Both cards read the same way

`LABEL → PROFILE → roaster → bean type`, on the last-shot card and the
next-shot card alike, so the two can be compared at a glance — which is the
point, since a differing profile means Grind Advisor has started a fresh
calibration.

**The roaster is the small line and the bean type is the hero**, not the other
way round. "MAN VERSUS MACHINE Specialty Coffee Roasters" is 44 characters and
was being cut to 13; "Sure Shot" is what actually distinguishes bags on the
counter and never truncates. The widened identity block (280 → 460) holds a
46-character roaster in full.

### Tasting notes

`bean_notes` now appears on the next-shot card — the best-populated optional
bean field (42% of shots; the current bag reads "Sweet, Creamy, Cocoa &
Nuts"). Rendered only when non-empty, so a bag without notes leaves no gap.

### Card details

*Last shot* gained **GRIND** alongside dose/yield/time, with the derived ratio
under YIELD exactly as the next-shot card does it. **Shot history** became a
text link beside the Curve / Shot analysis styling — it was the only button on
the card, which gave a history shortcut more weight than it deserves.

*Next shot* — PROFILE left the stepper row for the identity block, so three
stepper columns now span 520..1116 on a 210 pitch instead of four on 206.
**Edit** moved onto the identity block's action row beside the cycler arrows,
so the bag's controls sit with the bag.

The identity block's full-height DYE tap is gone: with the arrows and Edit on
its action row a block-wide tap would have overlapped them, and tap targets
may never overlap. Edit is the single way in, which is clearer than a large
invisible region that did the same thing.

### C(chart_bg) changed to #151618 / #DEE0E5

The generator's sample point is an **absolute page coordinate**, and the chart
panel moved, so (700, 450) was no longer its centre. Corrected to (700, 390)
and the palette updated to match — the graph is an opaque Tk widget and a
stale value would read as a box cut into the panel. Worth remembering: this
token must be re-sampled whenever the chart panel moves.

### Four text bugs found on the tablet and fixed in the same version

1. **The last shot's profile rendered inside the grind tile.** Its value was
   drawn at `id_val_x` (130) — the *next-shot* card's coordinate — so it
   landed in the neighbouring card and left LAST SHOT's own PROFILE label
   with nothing beside it. It has its own `last_val_x` (796) now. Lesson: a
   token named for one card must not be reused on another.
2. **"Curve" fell out of the shortened grind tile.** The offsets were moved
   from `gy + 170` to `gy + 140` with a replace-all that only matched the
   occurrences starting a line; Curve's is inline after `$gcv_r` and kept the
   old value, which now sits past the card's edge.
3. **The last shot's bean name was cut to "Jorge Dia...".** 274px holds ~11
   characters at the 40px hero. It uses `font_primary` (22px) and a 24-char
   cap — which also matches the owner's mockup, where this name is smaller
   than the next-shot one. This card is a summary; that one is the control.
4. **Tasting notes ran through the cycler arrows and Edit.** `bean_notes` is
   genuinely MULTI-LINE in real data — the Morgon bag holds "Peru | Washed |
   Bourbon\nJuicy, Forest Berries, Cacao" — and the row budget assumed one
   line. Newlines and whitespace runs now collapse to a single separated
   line, capped to what the block holds. **The offline harness could not have
   caught this: it has no way to know a data field contains a newline.**

### Action row

`[ < ] [ Edit ] [ > ]` across the identity block's full 460px, all 48 tall.
The arrows were 40x34 and the owner reported them as tiny — well under the
touch floor, and adjacent, so a mis-tap on one hit the other. Edit sits
BETWEEN them (owner request), which separates them as well as filling the
row. The harness now fails anything in this row under 44px.

### Verified

Harness clean in all three states, 40 tap targets with no overlap, and new
budget checks for the identity rows (order, hero clear of the notes, block
clear of the steppers, last-shot identity clear of the metrics, metrics inside
the tile). Two harness checks were stale from the old layout — arrows-above-
the-name and a PROFILE tile that no longer exists — and were rewritten to the
new invariants rather than deleted. Image diff confirms only the four home
images changed; settings and both flow images are byte-identical.

## 0.22.0 — the grind tile follows the cycled bag — NOT YET TABLET-VERIFIED

**Safety status: no new writes, no new settings, no asset change.** No layout
change either, so nothing was re-baked.

Owner-reported after 0.21.0: cycling a bag changed the bean fields but the
Recommended Grind card kept its old number.

Two causes, and the second was the real one:

1. The recommendation saved on the tablet predated Grind Advisor 3.7.0 and
   carried no `bag_key`, so `last_recommendation_is_current` hit its fail-safe
   and reported "current". That alone would have cleared after one shot.
2. **More importantly, blanking was the wrong design.** Even working
   perfectly, 0.21.0 would only have emptied the tile. A bag you cycle back to
   already has its own shots and its own regression, and discarding that is a
   worse answer than showing it.

`grind_rec` now calls Grind Advisor 3.8.0's
`recommendation_for_current_bag`, which computes from the loaded bag's own
history (memoized per bag, so the 200 ms refresh tick costs nothing) and
prefers the saved recommendation whenever that already describes this bag.

The older paths are kept behind `[info procs]` checks, in descending order of
capability: 3.7.x can still report whether the saved rec is current, and
3.6.x and earlier just hand over the last saved one — so the skin degrades
cleanly instead of blanking the tile for anyone on an older plugin.

A bag with no shots yet still shows the "pull a shot" note. The owner's
"reset only, no seeded number" decision is untouched: nothing here invents a
grind, it only surfaces numbers a bag's own shots already justify.

## 0.21.0 — bag cycler, profile on the strip and the last-shot card — NOT YET TABLET-VERIFIED

**Safety status: no new write class, and Lumen still opens no database.** The
bag cycler reads through SDB's public API and writes through DYE's own
`::plugins::DYE::shots::source_next_from` — the same path Bean Scanner uses.
Lumen issues no SQL and holds no database handle. No file in `history/` or
`history_v2/` is read, written, renamed or deleted.

### Bag cycler

Two arrows on the NEXT SHOT label row step the next shot's bean bag through
the most recently used bags. Depth comes from `::settings(lumen_bag_count)`
(the BAGS TO CYCLE row added in 0.20.0, default 5).

They sit **just after the NEXT SHOT label**, not right-aligned to the identity
block. Right-aligned was the first build and it was wrong on the tablet: the
block ends at 320 and the GRIND column starts at exactly 320, so the arrows
touched it with zero gap and read as GRIND's controls rather than the bag's.
The harness now asserts at least `md` (16) between the two — it is 84.

* list — `::plugins::SDB::available_categories bean_desc 1 {} 0`. That
  trailing `0` is `use_lookup_table` and it earns its place three times: it
  selects the branch ordering by `MAX(shot.clock) DESC` (most recently used
  bag first, which is the entire point), it is the only branch that applies
  the `removed=0` filter, and it avoids the lookup-table branch, which reads
  an undefined `lookup_order_by` (`SDB.tcl:2723`; its assignment is commented
  out at 2657).
* clock — `::plugins::SDB::shots_using_category bean_desc <value> t.clock`,
  newest first. **The `t.` qualifier works around an SDB defect, found on the
  tablet.** For `bean_desc` the data dictionary gives `db_table = V_shot`
  rather than `shot`, so `shots_using_category` takes its aliased branch and
  builds `SELECT DISTINCT clock FROM V_shot t INNER JOIN V_shot s ON
  t.clock=s.clock` — a bare `clock` that SQLite rejects with *"ambiguous
  column name: clock"*, and the cycler could never resolve a clock.
  `act::_bag_clocks` tries the qualified spelling first and the bare one
  second (correct if a future SDB maps `bean_desc` onto the plain `shot`
  table), and returns nothing rather than throwing if both fail.

  The first offline stub accepted `clock` happily, which is exactly why this
  reached the tablet. The stub now reproduces the ambiguity, and the SQL was
  re-verified against the real database: `clock` fails, `t.clock` returns all
  13 clocks for the test bag, and all 7 bags resolve.
* apply — `::plugins::DYE::shots::source_next_from <clock> {} beans`. DYE
  expands `beans` through `metadata fields -domain shot -section beans`, so
  the whole bean section travels: brand, type, roast date, level, notes.

A bag not in the window (hand-typed, or older than the last N) steps onto the
most recent bag rather than doing nothing. Blank `bean_desc` values are
dropped so cycling can never land on "no bag". Missing SDB or DYE logs and
does nothing instead of throwing inside a button handler.

### PROFILE replaces the RATIO stepper

The strip's four columns are full: 176px each on a 206 pitch from x=320,
ending at 1114 against a 1116 inner edge. A fifth column would have forced
every control down to ~143px and the value span to ~43px, which will not hold
"1:2.0". So RATIO gave up its slot.

Nothing is lost. Ratio was never independent — its stepper only ever wrote
`final_desired_shot_weight`, exactly as the yield stepper does. It is now a
derived caption **under** the yield value, in the owner-supplied style
("36g" with "(1:2.4)" beneath). It stacks *inside* the 662..710 pill band, not
below it: the strip's bottom row starts at 722 and 12px is not a line of text.
`::lumen::act::adjust_ratio` is deleted.

The freed column (x=938) is a read-only PROFILE tile. Read-only on purpose —
profiles are chosen in the app's own picker, and a stepper over a list of
profiles is a different feature. It belongs on the strip because a profile
change now starts a fresh calibration (Grind Advisor 3.7.0).

### Profile on the last-shot card

The LAST SHOT tile names the profile that shot actually ran on.

Deliberately **not** `::settings(profile_title)`: that is the profile loaded
right now, and it stops describing the last shot the moment you switch — which
is precisely the case this line exists to show. `::lumen::last_shot_profile`
is latched when the espresso page opens (a shot is starting, so the loaded
profile is the one it will use) and seeded at startup from the newest history
file, which `load_last_shot_curves` already parses.

Latching on flow *complete* would have been subtly wrong: `after_flow_complete`
fires for steam, hot water and flush too, any of which can land after you have
already switched profiles for the next coffee.

The seed reads the shot file's `settings` block into a **local** array. Never
`array set ::settings $props(settings)` — that is the stock `preview_history`
behaviour and it would replace your entire live configuration with a stale one.

### The grind tile resets on a bag or profile change

Every grind accessor funnels through `::lumen::data::grind_rec`, so one guard
there resets the tile coherently: hero to "--", delta, method chip and
confidence band blank, and the note explains why.

Before this, switching bags left the **previous** bag's recommendation on
screen until the next shot was pulled — a calibration for a different coffee,
presented as if it were current.

Uses Grind Advisor 3.7.0's `last_recommendation_is_current`, which fails safe
on its own side. The `[info procs]` guard here is for **older** Grind Advisor
builds where the proc does not exist: those behave exactly as 0.20.0 did
rather than blanking the tile for everyone still on 3.6.x.

### Tap target carve

The cycler arrows sit inside the identity block's DYE tap, and two tap targets
may never overlap. The DYE target now starts below the arrows — the same carve
the grind tile does around its Curve control. What is given up is the label
strip; the bean name and sub-line, which is what anyone actually aims at, stay
tappable. The harness caught this: it reported two overlaps on the home page
on the first run.

### Assets and harness

Home re-baked: the RATIO pills are gone and the two cycler pills are in.
**Verified by image diff that only the four home images changed** — settings
and both flow images are byte-identical, and the change is confined to the
strip (design-px bbox 219,614–1131,735). Palette tokens unchanged.

Harness gained a cycler/profile budget block (arrows inside the identity
block, arrows clear of the bean name, profile tile inside the strip, pill band
clear of the bottom row).

Verified offline: harness clean in all three states with no warnings; the new
procs byte-compile; the cycler's index arithmetic tested for wrap-around in
both directions, a bag outside the window, an empty list, an all-blank list, a
single bag, a bag with no shots, and both plugins missing.

## 0.20.0 — every page baked; settings right column filled — TABLET-VERIFIED 2026-08-15

Verified on the tablet: the settings page renders with its baked background,
all four right-column rows present, Done returns to a correct home page, and
the log reads `Lumen skin v0.20.0 loaded (dark)` with no missing-image
warnings. **The four flow pages (espresso / steam / water / flush) were
confirmed by the owner on 2026-08-15**, which also validates
`C(chart_bg_flow)` — the separate token for the espresso page's chart panel,
the one value in this work that could not be tested off-device.

**Safety status: one new setting, no new write class.**
`::settings(lumen_bag_count)` (3–10, default 5) is written only on an
explicit stepper tap and saved with plain `save_settings` — it is a skin
preference and deliberately never goes near `save_settings_to_de1`. No
database is opened; no file in `history/` or `history_v2/` is read, written,
renamed or deleted. Everything else in this version is display-only.

### The settings and flow pages no longer look a generation behind

Only the home page was baked. Everything else fell through to the vector
`glass` primitive, which Tk cannot make translucent: flat fills, a hard
1px line along the **top edge only**, no shadow, no gradient, and a flat
brown-ish accent instead of the crema bloom. Side by side with home the
difference is not subtle.

Faking depth with stacked canvas shapes was tried in 0.6.0 and reverted — on
a near-black ground the shadow tones span about two RGB values. So the fix is
the proven mechanism: bake them.

`tools/make_home_bg.py` is now `tools/make_backgrounds.py`, generalized from
one hardcoded page to a `PAGES` table. Four images cover five pages:

| Image | Page |
|---|---|
| `lumen_home` | home (`off`) |
| `lumen_settings` | Lumen settings |
| `lumen_flow_chart` | espresso (compact layout, live chart) |
| `lumen_flow` | steam, water, hotwaterrinse |

The three roomy flow pages share one image: `build_flow_page` draws identical
panels for all three and only the label text differs, and text is not baked.
That is why this is 4 images and not 5. Assets grew by ~1.1 MB.

**The home backgrounds regenerate BYTE-identical** to the committed ones —
same SHA256 and same byte length across both themes and both resolutions, on
top of a pixel-level image diff. The refactor is proven non-destructive.

`::lumen::baked_pages` now lists all five pages, so `glass` no-ops on them,
and each page is registered with its own `-bg_img` instead of `-bg_color`.

### C(chart_bg_flow)

New palette token. The espresso page's chart panel sits at y 186..504 while
the home one sits at 268..600, and the backdrop is a vertical gradient — so
the correct tone at those two heights genuinely differs (`#171719` vs
`#141517` on dark). A BLT graph is an opaque Tk widget that takes exactly one
background colour, so sharing a single token would have read as a box cut
into the espresso panel. The generator prints both.

### Settings page right column

The column stopped after DECENT APP and left ~440px empty against four rows
on the left. It now runs four rows like the left one, both ending at y=630
with 60 clear above Done:

* **BAGS TO CYCLE** — how many recent bean bags the home strip's cycler
  offers, 3–10, default 5. **This version ships the preference and its row
  only; the cycler that consumes it lands in 0.21.0.** The row has to exist
  now because the page background is baked, and a baked page cannot grow a
  row later without regenerating every asset.
* **GRIND ADVISOR** — opens the plugin's settings via its public
  `open_settings_dialog`, guarded exactly like the existing Shot History
  shortcut. Grind Advisor's own page captures the page it was opened from
  (v1.8.8), so Done returns here with no bookkeeping in Lumen. Drawn with the
  raised fill rather than the accent one: DECENT APP is the single emphasised
  door on this page and two accent buttons in one column compete.

The THEME button is baked with the **raised** fill to match what
`build_settings` actually draws (`-fill $C(glass_2)`); a first pass baked it
plain and it would have rendered flatter than the code intended. Still not
accent-coloured, per the 0.18.0 requirement that the button itself show the
theme.

The `-` / `+` stepper glyphs stay ASCII. The `-` does render lighter than the
`+`, but ASCII-only is a recorded design rule and this is a restyle pass, not
the place to overturn it.

### Harness

`tools/check_skin.tcl` gained a settings-page budget check (row spacing, both
columns' clearance to their steppers, Done clearance, page-edge symmetry) and
a baked-background check that every page in `baked_pages` has an image on
disk for both themes at both resolutions — a declared page with no background
renders blank, which was the very first tablet test's failure mode.

The column-clearance check found a bug in itself on the first run: it applied
the right column's `-width 220` caption bound to the left column too, which
draws bare short labels with no `-width` at all, and reported a phantom
12px overlap. The bound is now per column.

Verified offline: harness clean in all three states with no warnings; the
four new procs byte-compile; `bag_count` clamps correctly for empty,
negative, non-numeric, float and out-of-range input; `open_grind_advisor`
logs rather than throws when the plugin is absent.

## 0.19.0 — tap-rate acceleration on the grind / dose / yield steppers — TABLET-VERIFIED 2026-08-14

**Safety status: no new settings and no new writes.** Same fields as 0.18.0,
same clamps; only the per-tap step size changed.

A slow tap on the GRIND, DOSE or YIELD stepper moves **0.1**. Taps in quick
succession — each within 700 ms of the last — escalate to **0.5** after
three and **1.0** after six, so a big adjustment does not take forty taps.
A pause or a direction change drops straight back to 0.1 (so correcting an
overshoot is always fine-grained). RATIO keeps its fixed 0.1, and the
machine steppers on the settings page keep their own increments.

The app's legacy canvas buttons fire once per press — there is no
press-and-hold event to hook — so "hold to repeat" is not possible; the
fast-tap ladder is the acceleration mechanism.

## 0.18.0 — rail removed, next-shot steppers, steam heater labelled honestly — TABLET-VERIFIED 2026-08-14

**Safety status: this version adds settings writes in two groups, each only
on an explicit tap and each clamped.**

*Next-shot steppers (home strip):* `grinder_dose_weight` (Set dose, and the
±0.5 dose stepper clamped 2..40), `grinder_setting` (grind stepper,
0..100), `final_desired_shot_weight` / `final_desired_shot_weight_advanced`
(yield and ratio steppers, 0..200; the `_advanced` variant only for
`settings_2c` profiles, mirroring DSx2's saw stepper). When DYE is loaded,
its staged `next_grinder_setting` / `next_grinder_dose_weight` are kept in
step — the exact pairing DYE's own DSx2 stepper performs
(`setup_DSx2.tcl change_grinder_setting`).

*Machine steppers (Lumen settings page, mirroring Streamline's settings
column):* `espresso_temperature` (Brew ±0.5°C, guarded 70..110, via the
core's `change_espresso_temperature` so step-temperature and advanced
profile frames follow), `steam_timeout` + `steam_disabled` (Steam ±5 s,
0..255, 0 = off), `flush_seconds` (Flush ±1 s, 3..254), `water_volume`
(Hot Water ±10 ml, 10..250). Applied with `save_settings` + the core's own
`save_settings_to_de1`, debounced by 1 s (Streamline's
`save_profile_and_update_de1_soon` pattern) so a run of taps lands as one
save and one BLE update.

*Preferences:* `lumen_theme`, `live_graph_smoothing_technique`, and the new
`lumen_chart_stages` (Stages toggle, boolean).

The Shot history button only opens the Shot History Editor; any edits or
deletions there are that plugin's own, behind its own preview/confirm flow.
No database is opened and no file in `history/` or `history_v2/` is
written, renamed or deleted by Lumen itself.

### Steam page: 158°C explained, not hidden

The reported "incorrect steam temp reaching 158°C" is a real sensor reading:
the steam page showed `steamtemp_text`, which is the **steam heater**
(`ShotSample(SteamTemp)`), and this machine's steam set point is 160°C — the
heater idling at its set point, the same value every stock skin displays. It
was mislabelled, not miscomputed. The column is now labelled **STEAM
HEATER**, shows an integer value, and states `target 160°C` beneath it, so
the number reads as intentional rather than absurd.

### Action rail removed; steppers added to the next-shot strip

* The Espresso/Steam/Water/Flush rail is gone (owner request — the machine's
  GHC covers those). The top tiles and chart span the full 16..1324 width.
* **Settings and Sleep survive** in their own small side panel to the right
  of the next-shot strip (owner's layout) — without them the skin would be
  a dead end with no way to change skins.
* The next-shot strip gains **Streamline-style stepper groups** — the live
  value sits BETWEEN the − and + pills — for all four facts: GRIND (±0.1),
  DOSE (±0.5 g, clamped 2..40 like DSx2's dose stepper, DYE's staged
  `next_grinder_dose_weight` kept in step), YIELD (±0.5 g) and RATIO (±0.1).
  No DYE trip needed. The strip's RATIO now shows one decimal, matching its
  0.1 increment.
* The strip's bottom row is one 48-high rhythm: **scale readout, Set dose
  (under DOSE), Scan bag (under YIELD) and Edit (under RATIO)** — the scale
  controls belong with the next shot, not the Last shot card (owner note).
  The readout still taps to force a scale reconnect.
* The Last shot tile gains a **Shot history** shortcut opening the Shot
  History Editor's card list (edit and soft-delete past shots) via its
  public `open_page`; the editor captures the return page itself, so Done
  comes straight back home. If the plugin is not loaded the tap logs an
  ERROR line rather than failing silently.
* **Stage separators on the chart**: a dashed vertical line at every frame
  change (preinfusion → extraction → decline...), the same
  `espresso_state_change` element every stock skin draws (mechanism from
  Streamline skin.tcl:3915). A **Stages / No stages** pill sits beside
  Raw/Smooth and toggles them via `element configure -hide` (Insight's
  mechanism), persisted in `lumen_chart_stages`. The element is never
  smoothed — a spline would bend the spikes.
* **The vertical-line-at-0s artifact on the loaded last shot is gone**: a
  saved shot's first samples repeat elapsed = 0.0 while the y-values move,
  which plotted as a vertical line ending in a stray point. The loader now
  slices every series from the first strictly positive elapsed value (all
  series are appended per-sample, so one index aligns them all).
* **The Lumen settings page gained a machine column** (owner request,
  Streamline-style): BREW temperature, STEAM time (steam flow shown
  beneath), FLUSH time and HOT WATER volume (water temperature shown
  beneath), each with the same − value + stepper group as the home strip.
  The right column keeps THEME (its button is plain glass, so it renders
  dark in the dark theme and light in the light theme) and DECENT APP
  (bigger accent Open button). The Chart lines row was removed — the
  chart's own pills already cover it. Columns are 460/500 wide with 170
  clear on both page edges; Done stays centred at the bottom.
* Home background PNGs regenerated (`tools/make_home_bg.py` layout mirrors
  `_init_layout`). `chart_bg` samples are unchanged (#141517 / #DDE0E4).

Verified off-device: `tools/check_skin.tcl` passes in all three data states,
no two tap targets intersect, and the new stepper procs byte-compile.
**Not yet tablet-verified.**

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
