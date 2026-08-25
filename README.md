# Lumen

A glass dashboard skin for the Decent DE1, by Blastize.

Lumen replaces the home screen with a dashboard: the current grind
recommendation, the last shot, the shot graph, and the beans for the next
shot — all reachable without going into Settings. It is built to work with
GrindAdvisor, DYE, Bean Scanner, ShotHistoryEditor and SDB.

**Version 0.30.0 — every page built, baked and running on the tablet.**

0.28.0: the home page follows Shot History Editor changes — edit or delete a
shot there and the chart, the LAST SHOT card and the bag cycler reload from
what `history/` now holds, via `::lumen::refresh_after_history_change`
(called by ShotHistoryEditor v0.7.0; other skins are unaffected).

0.24.0 adds the **water tank level** in millilitres to the home screen, a
**Profile** shortcut beside Settings and Sleep, moves **DECENT APP** to the
bottom-right card of the Lumen settings page, and fixes the flow-page timers
flashing the *previous* flow's elapsed time for a moment when a page opens.
0.24.1 makes the last shot's **yield** survive an app restart — it is read
back from the shot file — and show `--` rather than `0.0` when the shot was
pulled without a scale. 0.25.0 extends that to **grind and dose**: the LAST
SHOT card reports what the shot itself recorded, so a correction made in the
Shot History Editor shows up there.

Since 0.18.0: every page uses a pre-rendered frosted background rather than
just the home screen; the next-shot strip gained a **bag cycler** that steps
through your recently used beans; both cards show the **profile** the shot
uses, because a profile change now starts a fresh grind calibration; and the
bean's **tasting notes** sit under its name. The grind tile follows the bag
you cycle to, showing that bag's own recommendation rather than the last one
you happened to pull.

## The home screen

![Lumen home screen](docs/screenshot.png)

Everything above is one page: the grind recommendation with its method and
confidence, the last shot's numbers, the full shot graph, and the next shot's
bean and targets. A light theme ships alongside this dark one — it is not an
inversion, since on a pale ground the panels have to sit *brighter* than the
backdrop and let the shadow do the separating.

## What the home screen does

| Tile | Shows | Tap |
|---|---|---|
| Grind | GrindAdvisor's next setting for the loaded bag, the change from the last one, method, confidence and shot count | Opens GrindAdvisor's result popup |
| Curve (on the grind tile) | — | Opens GrindAdvisor's Calibration Curve directly |
| Last shot | The profile it ran on, the roaster and bean, then grind, dose, yield (with the ratio beneath) and time — as **that shot recorded them**, read back from the shot file, so corrections made in the Shot History Editor appear here. `--` when the shot had no weight | — |
| Water (Last shot tile, top right) | Water left in the tank, in mL, in blue. Blank when no machine is connected | — |
| Shot history (Last shot tile) | — | Opens the Shot History Editor (edit / soft-delete past shots) |
| Graph | Pressure, flow, cumulative weight and basket temperature for the shot, plus dashed stage separators at every frame change | **Stages** and **Raw / Smooth** toggles in its header |
| Next shot | The profile, the roaster, the bean, and its tasting notes | — |
| ◀ ▶ (next-shot card) | The bag being cycled, with a dot per reachable bag beside Edit — filled for the one loaded, leftmost the most recent | Steps through your recently used beans; the grind tile, chart and LAST SHOT card all switch to that bag (0.30.0). It does not wrap: at the newest or oldest bag, that direction stops |
| Edit | — | Opens DYE's next-shot editor |
| − value + steppers | GRIND, DOSE, YIELD — the live value sits between the pills, with the derived ratio under the yield | Each tap ±0.1; drumming rapidly (3+ taps a second) escalates to ±0.5 then ±1.0. Any measured pace stays at ±0.1 (0.28.1) |
| Scale readout | Live weight, or `Connecting` / `Connect` / `no scale` | Forces a scale reconnect |
| Set dose | — | Stores the current scale weight as the dose |
| Scan bag | — | Bean Scanner |
| Profile / Settings / Sleep | Their own side panel, right of the strip | The app's profile list, Lumen settings, sleep |

The bag cycler reads your recent beans through SDB's public API and applies
the chosen one through DYE, so the skin itself opens no database. How many
bags it offers is set on the Lumen settings page (3–10, default 5).

There are no Espresso/Steam/Water/Flush buttons — the machine's GHC starts
those, and the flow pages take over the screen as soon as it does.

The Grind tile's method chip names the rung GrindAdvisor used: **First shot**
(1 shot on the bag), **2-shot**, **Regression** (3 or more), or **Pairwise**
when the regression is too flat to solve.

## If the scale does not connect

Tap the weight readout. The app only retries a dropped scale about 20 times,
roughly 10 seconds apart, and then stops for good — so a scale switched on a
few minutes late is never picked up on its own. Tapping the readout clears the
app's retry counter and starts a fresh connection attempt; it shows
`Connecting` while one is in flight.

## During a shot

Espresso, steam, water and flush each get their own page: what the machine is
doing, a large elapsed timer, and live pressure / flow / weight / temperature.
Tap anywhere to stop — including on flush, which the stock skin does not offer.

Each page reads its own timer, and only reports the flow **this** page visit
is running. The machine's timers keep describing the previous flow until the
new one starts pouring, and the page opens before that — which is why the
espresso page used to flash the seconds since the last shot began (0.24.0).

The steam page's temperature column is labelled **STEAM HEATER**, because
that is what the machine reports there: the steam heater sensor
(`ShotSample(SteamTemp)`), which idles at the steam set point — about 158°C
with the heater set to 160°C. The set point is stated right under the value.
It is not the temperature of the steam at the wand tip, and the DE1 has no
sensor that measures that.

Everything degrades gracefully: with a plugin missing or disabled the values
read `--` and the buttons log a line to the app log rather than failing
silently. Look for `Lumen:` in the log if a button seems dead.

Dose and grinder setting persist across shots in the DE1app, so "last shot"
and "next shot" show the same figures until you change them. That is the
app's own behaviour, not a quirk of the skin.

The two cards do answer different questions, though, and 0.25.0 made that
real: **LAST SHOT is the record** — grind, dose and yield as the shot file
holds them, corrections included — while **NEXT SHOT is the plan**, the live
and DYE-staged values the next shot will use. The card falls back to the live
settings once a shot has run in this session, because those are exactly what
that shot recorded.

## Typography

Inter for UI text, NotoSansMono for every number — doses, yields, times and
grind settings line up in columns, and a proportional face makes those
columns ragged. Both families ship in `fonts/` and are already proven on this
tablet.

The skin does not use the app's `load_font`, because that hands a *positive*
(point) size to `font create`, scaled by `::settings(default_font_calibration)`
— 0.5 on this tablet — which makes text size unpredictable across DPI. Lumen
takes only the family name from the font loader and creates every font itself
at negative (pixel) sizes, with a 16px floor. If the TTFs cannot be
registered, each face falls back to Helvetica or Courier.

## Install

Copy the `Lumen` folder to `de1plus/skins/` on the tablet, so you end up with:

```
de1plus/skins/Lumen/skin.tcl
de1plus/skins/Lumen/fonts/
```

Then pick it in **Settings → Tablet → (skin list)**.

### If Lumen does not appear in the skin list

The app hides unknown skins by default. `skin_directories` in
`de1app-core/vars.tcl` filters the list against a hardcoded
`most_popular_skins` set whenever `show_only_most_popular_skins` is 1 — and
1 is the default.

Turn off **"Only show most popular skins"** on that same Tablet settings
page and Lumen will appear.

## What it looks like

Tk has no runtime backdrop blur and canvas shapes have no alpha channel, so
the frosted panels are composited offline into background PNGs — real
translucency, blurred backdrops, soft shadows and specular edges — and the
skin draws only text, the chart widget and tap targets on top.

As of 0.20.0 **every** page is baked, not just home. Four images cover the
five pages:

| Image | Page |
|---|---|
| `lumen_home` | home (`off`) |
| `lumen_settings` | Lumen settings |
| `lumen_flow_chart` | espresso (compact layout, live chart) |
| `lumen_flow` | steam, water, hotwaterrinse |

The three roomy flow pages share one image because `build_flow_page` draws
identical panels for all three — only the label text differs, and text is not
baked.

The images are pre-rendered, so their panel coordinates mirror
`::lumen::_init_layout` and `::lumen::build_settings` exactly — change a
layout token and the background has to be re-rendered to match, or the text
will sit off its panel.

## Themes

Dark and light are both defined. The mode is read once at load from
`::settings(lumen_theme)` (`dark` or `light`); it defaults to dark.

The Lumen settings page carries the **machine column** on the left: Brew
temperature (±0.5°C), Steam, Flush time (±1 s) and Hot Water, each with the
same − value + steppers as the home strip. Changes are saved and sent to the
machine automatically, one second after the last tap.

**Steam and Hot Water each carry two settings** (0.26.0). Tap the mode line
under the row's label to choose which one the − / + pills drive:

| Row | Modes | Step |
|---|---|---|
| Steam | **TIME** (`steam_timeout`) / **FLOW** (`steam_flow`) | ±5 s / ±0.1 mL/s |
| Hot Water | **TEMP** (`water_temperature`) / **VOL** (`water_volume`) | ±1 °C / ±10 ml |

The selected setting is the large value between the pills; the other sits
small beneath it, so both are always readable. The choice persists — whichever
half you last steered is the one waiting next time.

The right column runs **THEME**, **BAGS TO CYCLE**, **GRIND ADVISOR** and then
**DECENT APP** — the door to the stock settings, profiles, plugins and
firmware — as the bottom-right card.

*Bags to cycle* (3–10, default 5) sets how many recent bean bags the home
strip's bag cycler offers. It is stored in `::settings(lumen_bag_count)` and
is a Lumen preference only — it never reaches the machine.

## The next-shot strip

`NEXT SHOT` names the bag, with **◀ ▶** arrows that cycle it through the most
recently used bags (as many as *Bags to cycle* allows). A bag not in that
window steps onto the most recent one. Tapping the bag name still opens DYE.

Then **GRIND**, **DOSE**, **YIELD** and **PROFILE**. Ratio is shown as a
derived caption under the yield value rather than a stepper of its own: it was
never independent — stepping it only ever wrote the target yield — and the
column was needed for the profile, which now scopes calibration (Grind Advisor
3.7.0 starts a fresh calibration when the profile changes).

The profile tile is read-only; profiles are chosen in the app's own picker,
which the side panel's **Profile** button opens directly (`show_settings
settings_1`, the stock profile tab).

The **LAST SHOT** card names the profile that shot ran on, which is not
necessarily the one loaded now — when the two differ, Grind Advisor has
started a fresh calibration.

Nothing in the cycler touches the database directly: the bag list and shot
clock come from SDB's public read API, and the write goes through DYE's own
`source_next_from`, the same path Bean Scanner uses.

*Grind Advisor* opens that plugin's settings through its public
`open_settings_dialog`; the plugin's own page captures where it was opened
from, so **Done** comes straight back here.

The **THEME** row on the Lumen settings page toggles it. Because the palette
is read once at load and every canvas item is created from it, the change
only lands when the skin is sourced again — so tapping **Done** after a theme
change quits the app, using the app's own restart-on-skin-change sequence
(`skins/default/de1_skin_settings.tcl:65-71`: message page, then `app_exit`).
Relaunch it and it comes up in the new theme. Toggling back to the theme you
started in does not quit.

**The app cannot reopen itself** on Android 16 — `am start` from the app's uid
is rejected by the platform, and `borg activity` would start the activity in
the process that is exiting. Changing skin in the stock settings behaves the
same way. The CHANGELOG entry for 0.15.0 has the measurements.

Both themes ship baked backgrounds for every page
(`1340x800/lumen_*[_light].png`, `2560x1600/...`).

## Layout basis

The whole file is authored in **design pixels on a 1340x800 basis** — the
same basis as the design mockup — and converted to the app's 2560x1600
virtual canvas through `::lumen::X` and `::lumen::Y`.

Those two factors are deliberately different: 2560/1340 is 1.9104 but
1600/800 is 2.0. Using a single factor for both axes drifts the layout
horizontally, which is why x and y convert separately.

All layout numbers live in one block, `::lumen::_init_layout`. Nothing below
it hardcodes a coordinate.

## Safety

No database is opened, and no file in `history/` or `history_v2/` is read,
written, renamed or deleted.

Every `::settings` write happens only on an explicit tap, and every stepper
clamps its value. Three groups:

* **Preferences:** `live_graph_smoothing_technique` (Raw/Smooth),
  `lumen_chart_stages` (Stages), `lumen_theme` (theme).
* **Next-shot steppers:** `grinder_dose_weight` (Set dose — refuses
  non-positive readings — and the dose stepper, 2..40), `grinder_setting`
  (grind stepper, 0..100), `final_desired_shot_weight` /
  `final_desired_shot_weight_advanced` (yield and ratio steppers, 0..200).
  With DYE loaded, its staged `next_grinder_setting` and
  `next_grinder_dose_weight` are kept in step, the same pairing DYE's own
  DSx2 stepper performs.
* **Machine steppers (settings page):** `espresso_temperature` (via the
  core's `change_espresso_temperature`, 70..110), `steam_timeout` +
  `steam_disabled` (0..255, 0 = off), `flush_seconds` (3..254),
  `water_volume` (10..250) — persisted and sent to the machine with the
  core's `save_settings_to_de1`, debounced by a second.

The Shot history button only opens the Shot History Editor; edits and
deletions there are that plugin's own, behind its own preview/confirm flow.
Nothing else is touched.

The grind tile, bean strip and Scan bag button hand off to GrindAdvisor, DYE
and Bean Scanner; any writing those perform is their own, behind their own
confirmation.

## Credits

The rounded-panel primitive is the same smoothed-polygon mechanism used in
the GrindAdvisor plugin. The stop-button bindings on the espresso, steam and
water pages are copied verbatim from `skins/default/standard_stop_buttons.tcl`.
The stock settings, firmware, descale and profile-editor pages come from
`skins/default/standard_includes.tcl` and are untouched.
