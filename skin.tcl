package require de1plus 1.0

#############################################################################
#
#  LUMEN  --  a glass dashboard skin for the Decent DE1
#
#  Author:  Blastize
#  Version: 0.30.0  (chart follows the bag cycler; flash ring hugs the control)
#
#
#
#  SAFETY STATUS: no database is opened. Nothing in history/ or history_v2/
#  is written, renamed or deleted -- ever, in any version.
#
#  READ access is limited to ONE file: load_last_shot_curves opens the newest
#  history/*.shot at startup, for the chart vectors, the profile name and what
#  that shot was pulled with. It parses into a LOCAL array; the stock
#  preview_history does `array set ::settings $props(settings)`, which would
#  overwrite the live configuration with a stale one.
#
#  (Before 0.25.0 this block claimed nothing in history/ was read at all.
#  That was already untrue -- the curve loader has been there since 0.9.0.)
#
#  Every ::settings write happens only on an explicit tap, and every stepper
#  clamps its value so a runaway tap cannot write junk.
#
#  Preferences (home chart pills + Lumen settings page):
#    live_graph_smoothing_technique  -- Raw/Smooth toggle
#    lumen_chart_stages              -- Stages toggle
#    lumen_theme                     -- Dark/Light toggle
#    lumen_bag_count                 -- how many recent bean bags the home
#                                       strip's bag cycler offers (3..10)
#
#  Next-shot steppers (home strip):
#    grinder_dose_weight             -- "Set dose" from the scale reading,
#                                       and the -/+ dose stepper (2..40)
#    grinder_setting                 -- the -/+ grind stepper (0..100)
#    final_desired_shot_weight       -- the -/+ yield stepper
#    final_desired_shot_weight_advanced -- same, when the profile is 2c
#
#  The bag cycler writes nothing directly: it calls DYE's own
#  ::plugins::DYE::shots::source_next_from, which owns that write. Lumen
#  opens no database and issues no SQL -- the bag list and the shot clock
#  come from SDB's public read API.
#  DYE's staged next_grinder_setting / next_grinder_dose_weight are kept in
#  step when DYE is loaded -- the same pairing DYE's own DSx2 stepper
#  performs (setup_DSx2.tcl change_grinder_setting). grinder_dose_weight is
#  the field shot.tcl records as the shot's dose, so that one is real data:
#  "Set dose" refuses a zero or negative reading.
#
#  Machine steppers (Lumen settings page, mirroring Streamline's column):
#    espresso_temperature            -- Brew, via the core's
#                                       change_espresso_temperature so step
#                                       and advanced profile frames follow
#    steam_timeout, steam_disabled   -- Steam time (0 = off)
#    flush_seconds                   -- Flush time (3..254)
#    water_volume                    -- Hot water volume (10..250)
#  These are persisted with save_settings and sent to the machine with the
#  core's own save_settings_to_de1, debounced by 1s (Streamline's pattern).
#
#  It hands off to three plugins -- GrindAdvisor's result popup, DYE's
#  next-shot editor, Bean Scanner's capture page -- and any writing those do
#  is their own, behind their own confirmation.
#
#  ---------------------------------------------------------------------
#  Two scale sources (see de1app-core/dui.tcl):
#
#    Coordinates are VIRTUAL. Everything handed to `dui add ...` lives in
#    the app's 2560x1600 canvas; dui rescales to the physical screen. Never
#    feed `winfo screenwidth` into a coordinate.
#
#    Fonts are PHYSICAL. Tk font objects bypass that rescale, so they are
#    sized in real pixels from the detected screen, with negative Tk sizes
#    (negative = pixels; positive = points, which explode on Android DPI).
#
#  This file is authored entirely in DESIGN pixels on a 1340x800 basis --
#  the same basis as the design mockup -- and converts to virtual through
#  ::lumen::X and ::lumen::Y. Note 2560/1340 is 1.9104 while 1600/800 is
#  2.0, so x and y genuinely need different factors; using one factor for
#  both drifts the layout horizontally.
#
#  All layout numbers live in ::lumen::_init_layout. Nothing below it
#  hardcodes a coordinate.
#
#############################################################################

namespace eval ::lumen {
    variable version "0.30.0"

    variable C        ;# colour tokens
    array set C {}

    variable L        ;# layout + font tokens
    array set L {}

    variable F        ;# resolved font family names
    array set F {}

    # Every BLT/RBC graph the skin creates (home page, espresso page). The
    # smoothing toggle reconfigures all of them.
    variable chart_widgets [list]

    # Pages whose panels are baked into a pre-rendered background image.
    # ::lumen::glass draws nothing on these -- the panel is already in the
    # PNG, with real translucency and blur that Tk canvas cannot produce.
    # Regenerate with tools/make_backgrounds.py after ANY layout change --
    # on ANY of these pages, not just home.
    #
    # 0.20.0: every page is baked now, not just home. Before that, settings
    # and the four flow pages fell through to the vector `glass` primitive --
    # flat fills, a hard line along the top edge only, no shadow -- and read
    # a generation behind the home screen.
    variable baked_pages [list off lumen_settings \
                               espresso steam water hotwaterrinse]

    variable theme_mode   "dark"
    variable pending_theme ""   ;# set when a theme change needs a restart

    # The profile the LAST shot ran on. Latched when the espresso page opens
    # (a shot is starting, so the loaded profile is the one it will use) and
    # seeded at startup from the newest history file. NOT read live from
    # ::settings(profile_title): that is the profile loaded right now, and it
    # stops describing the last shot the moment you switch -- which is exactly
    # the case this line exists to show.
    variable last_shot_profile ""

    # What the newest shot FILE records: grind, dose and yield, read out of
    # its settings block by load_last_shot_curves at startup. Keys grind,
    # dose, yield; absent means "not recorded".
    #
    # These are what the LAST SHOT card shows, in preference to the live
    # ::settings, because the two answer different questions (0.25.0):
    #
    #   ::settings(grinder_setting) and friends are what is staged RIGHT NOW
    #   -- what the NEXT shot will use and record. The shot file is what the
    #   LAST shot actually used. They agree until you change a setting, or
    #   until you correct a shot's record in the Shot History Editor -- which
    #   writes the file and nothing else, so the live value keeps reporting
    #   the figure you just corrected away from.
    #
    # ::settings(drink_weight) additionally does not survive a restart, which
    # is how the tablet came to show "YIELD 0.0" beside a grind tile calling
    # the same shot 37.8g (0.24.1).
    #
    # CLEARED when a shot starts (latch_shot_profile): from that moment the
    # file is no longer about the last shot, and the live settings are exactly
    # what the running shot is recording, so they become the better source.
    variable last_shot_rec
    array set last_shot_rec {}

    # after-id of the debounced machine-settings save/send (settings page).
    variable machine_apply_id ""

    # The bags the cycler can reach, newest first, capped at lumen_bag_count.
    # Cached because the page indicator reads it on every refresh tick and
    # SDB must not be. See ::lumen::refresh_bag_list.
    variable bag_list [list]

    # When each flow page was last SHOWN, in clock milliseconds.
    #
    # The core's flow timers keep describing the PREVIOUS flow until the new
    # one reaches its "during" phase, so a page that reads them the moment it
    # opens reports the wrong thing (0.24.0: the espresso page flashed the
    # seconds since the last shot -- 450s -- before resetting to 0 and
    # counting properly). ::lumen::data::_flow_secs uses this to tell "this
    # visit's flow" from "the one before it".
    variable flow_opened
    array set flow_opened {}
}

#############################################################################
#  Colours
#
#  Tk canvas items have no alpha channel, so every "translucent" glass tone
#  is pre-composited against the page background by hand. That is the whole
#  trick behind the glass look: no runtime blur, no image assets.
#############################################################################

proc ::lumen::set_palette { mode } {
    variable C
    array unset C
    array set C {}

    if { $mode eq "light" } {
        set C(bg)          "#E9EDF3"
        set C(glass)       "#F8F9FB"
        set C(glass_2)     "#FBFCFD"
        set C(glass_brd)   "#CCD2DA"
        set C(spec)        "#FFFFFF"

        set C(ink)         "#121826"
        set C(ink_2)       "#4A5568"
        set C(ink_3)       "#7C8798"

        set C(crema)       "#C2761B"
        set C(crema_lo)    "#E4DDD7"
        set C(crema_brd)   "#DCC4AA"

        set C(good)        "#12805F"
        set C(warn)        "#B4761A"

        set C(c_press)     "#0E9E7C"
        set C(c_flow)      "#3F72E0"
        set C(c_temp)      "#E04F5C"
        set C(c_weight)    "#A8763F"
        set C(grid)        "#D5DBE3"
        # Sampled from the middle of the chart panel in
        # 1340x800/lumen_home_light.png -- the generator prints both.
        set C(chart_bg)    "#DEE0E5"
        # The espresso page's chart panel sits at 186..504, the home one at
        # 268..600. Same baked gradient, different height, so a shared value
        # would read as a box cut into one of them. Sampled separately from
        # 1340x800/lumen_flow_chart_light.png.
        set C(chart_bg_flow) "#DEE1E4"

    } else {
        set C(bg)          "#0A0E15"
        set C(glass)       "#191E26"
        set C(glass_2)     "#23282F"
        set C(glass_brd)   "#2B2F36"
        set C(spec)        "#75787C"

        set C(ink)         "#F0F4FA"
        set C(ink_2)       "#AFBBCC"
        set C(ink_3)       "#74829A"

        set C(crema)       "#F0A63C"
        set C(crema_lo)    "#282219"
        set C(crema_brd)   "#614824"

        set C(good)        "#2FD3A4"
        set C(warn)        "#E8B34C"

        set C(c_press)     "#17C29A"
        set C(c_flow)      "#6C9BFF"
        set C(c_temp)      "#FF7880"
        set C(c_weight)    "#E6C9A8"
        set C(grid)        "#1C2129"

        # The graph is an opaque Tk widget sitting inside a panel that is a
        # baked gradient, so a flat page-coloured background reads as a box
        # cut into the panel. Sampled from the middle of the chart panel in
        # 1340x800/lumen_home.png -- resample if the generator changes.
        set C(chart_bg)    "#151618"
        # Same reasoning, for the espresso page's chart panel: it sits at
        # 186..504 rather than 268..600, and the backdrop is a vertical
        # gradient, so the tone at that height is genuinely different.
        # Sampled from 1340x800/lumen_flow_chart.png.
        set C(chart_bg_flow) "#171719"

    }

    # The espresso chart reads these globals straight out of the skin.
    set ::pressurelinecolor        $C(c_press)
    set ::flow_line_color          $C(c_flow)
    set ::temperature_line_color   $C(c_temp)
    set ::weightlinecolor          $C(c_weight)
    set ::chart_background         $C(bg)
    set ::grid_color               $C(grid)
    set ::skin_background_colour   $C(bg)
}

#############################################################################
#  Layout
#############################################################################

# Design px (1340x800 basis) -> virtual canvas px.
proc ::lumen::X { v } { return [expr {int(round($v * 2560.0 / 1340.0))}] }
proc ::lumen::Y { v } { return [expr {int(round($v * 1600.0 /  800.0))}] }

proc ::lumen::_init_layout {} {
    variable L
    array unset L
    array set L {}

    # Real physical screen, used ONLY for font pixel sizes.
    set psh 800
    catch { set psh [winfo screenheight .] }
    if { $psh <= 1 } { set psh 800 }
    set font_scale [expr {double($psh) / 800.0}]
    set L(font_scale) $font_scale

    # ---- spacing -------------------------------------------------------
    set L(xs) 6 ; set L(sm) 10 ; set L(md) 16 ; set L(lg) 24 ; set L(xl) 32

    set L(margin)  16
    set L(radius)  26          ;# glass panel corner
    set L(radius_sm) 16

    # ---- dashboard (full width; the action rail was removed in 0.18.0:
    # the espresso/steam/water/flush buttons duplicated the machine's own
    # GHC controls and the width was needed for the next-shot steppers) ----
    set L(col_x)     16
    set L(col_w)   1308

    # 0.23.0 re-proportioned the page (owner mockup): the two top cards were
    # taller than their content needed, and the next-shot card -- the one you
    # actually operate -- was the most cramped. 46px moved from the top row
    # and 4 from the chart into the bottom row.
    #
    #   top cards   16..206   (h 190, was 236)
    #   chart      222..558   (h 336, was 268..600 / 332)
    #   bottom     574..784   (h 210, was 168)
    #
    # Every gap is md (16) and the bottom margin is 16, as before.
    set L(grind_x)   16 ; set L(grind_y)  16
    set L(grind_w)  650 ; set L(grind_h) 190

    set L(last_x)   682 ; set L(last_y)   16
    set L(last_w)   642 ; set L(last_h)  190

    set L(chart_x)   16 ; set L(chart_y) 222
    set L(chart_w) 1308 ; set L(chart_h) 336

    set L(bean_x)    16 ; set L(bean_y)  574
    set L(bean_w)  1124 ; set L(bean_h)  210

    # Side panel to the strip's right: Profile, Settings and Sleep, stacked.
    # Its own glass panel so the system actions read as separate from shot
    # prep.
    #
    # 0.24.0 squeezed PROFILE in (owner request). Three 60-tall buttons plus
    # gaps do not fit 210, so the height drops to 56 -- still above the 44px
    # touch floor the cycler arrows are held to, and the same height as the
    # settings page's own THEME button. Budget: 11 pad, 3 x 56, 2 x 10 gap,
    # 11 pad = 210, so the column ends at 773 with the panel at 784.
    set L(side_x)  1156 ; set L(side_w)   168
    set L(side_btn_x) 1170 ; set L(side_btn_w) 140 ; set L(side_btn_h) 56
    set L(side_y1)  585 ; set L(side_y2)  651 ; set L(side_y3)  717

    # ---- bean strip internals (0.23.0) ---------------------------------
    #
    # PROFILE left the stepper row for the identity block, so there are three
    # stepper groups instead of four. That freed enough width to widen the
    # identity block from 280 to 460 -- which is what makes a 44-character
    # roaster name fit without truncation.
    #
    # Identity rows. The ROASTER is the small line and the BEAN TYPE is the
    # hero, not the other way round: roasters run long ("MAN VERSUS MACHINE
    # Specialty Coffee Roasters" is 44 chars) while the bean type is short
    # and is what actually distinguishes one bag from another day to day.
    set L(bean_id_x)    40
    set L(bean_id_w)   460

    # 0.27.0 re-spaced the block (owner: "not have everything tight,
    # especially the bag name area"). The gaps were 4px above the tasting
    # notes and 9px below them; they are an even 11 everywhere now, which is
    # what a 40px hero needs to stop looking wedged between two lines.
    #
    # The row that paid for it is the old dedicated PROFILE line: NEXT SHOT
    # only ever used the left third of its row, so PROFILE moved up beside
    # it. That is a whole 24px row recovered without dropping anything.
    #
    #   590 label+profile   617 roaster   644 hero (->684)   695 notes
    #   722 action row (->770), 14 clear of the strip edge at 784
    set L(id_label_y)  590      ;# NEXT SHOT ... PROFILE <value>
    set L(id_roast_y)  617      ;# roaster, small
    set L(id_name_y)   644      ;# bean type, hero (40px -> 684)
    set L(id_notes_y)  695      ;# tasting notes, only when non-empty
    set L(id_act_y)    722      ;# action row (48 tall -> 770)

    set L(id_prof_x)   170      ;# the PROFILE label, on the NEXT SHOT row
    set L(id_val_x)    245      ;# and its value
    set L(id_val_w)    255

    # The cycler arrows are a stepper pill's size now (owner request), down
    # from 120 wide. They stay on the action row with Edit BETWEEN them: two
    # arrows side by side invite a mis-tap that sends you the wrong way
    # through the bags, which is why Edit was put between them in 0.23.0.
    #
    # A first cut of 0.27.0 moved them up to flank the bag name at the
    # block's two edges. The preview killed it: the right arrow landed 20px
    # from the GRIND column's minus pill, at the same size, shape and height
    # -- it read as one of GRIND's controls. The name row is better off with
    # the full 460 anyway.
    #
    #   40..84   96..256   268..312
    set L(cyc_w)        44 ; set L(cyc_h)  48
    set L(cyc_y)       722
    set L(cyc_prev_x)   40
    set L(cyc_next_x)  268
    set L(id_edit_x)    96 ; set L(id_edit_w) 160 ; set L(id_edit_h) 48

    # The hero name keeps the block's full width.
    set L(id_name_x)    40 ; set L(id_name_w) 460

    # iPhone-style page indicator for the bag cycler (0.27.0), centred in the
    # action row's remaining width: (312 + 500) / 2 = 406. At 10 bags -- the
    # most lumen_bag_count allows -- the row of dots is about 140 wide, so it
    # keeps ~35px clear of the right arrow and of the block's edge.
    set L(bag_dots_x)  406 ; set L(bag_dots_y) 746

    # Three columns spread evenly across 520..1116 (596 wide): 3 x 176 = 528,
    # two 34 gaps, so a 210 pitch ending flush at 940 + 176 = 1116.
    set L(bean_fact_x)  520
    set L(bean_fact_w)  210        ;# column pitch

    # The "-" glyph renders LOW inside its pill. Measured on the tablet
    # (0.27.0): against a pill centre at y=666, the minus ink sat at 668.5 and
    # the plus at 666.5 -- Tk centres the text bounding box, and a hyphen's
    # ink is not centred within that box the way a plus sign's is. Two design
    # px up puts the two glyphs on the same line as each other.
    set L(step_minus_dy) -2

    # Stepper group internals: pill, gap, value span, gap, pill = 176.
    #
    # The right column is evenly distributed and its bottom row is LEVEL with
    # the identity block's action row on the left (owner request, 0.23.1):
    #
    #   pad 20   label 594..610   gap 32   steppers 642..690
    #            gap 32           bottom 722..770   14 clear to the strip edge
    #
    # 722 is id_act_y, so Connect / Set dose / Scan bag sit on exactly the
    # same baseline as the cycler arrows and Edit. Both columns end at 770.
    set L(step_w)       44
    set L(step_gap)      6
    set L(step_val_w)   76
    set L(step_y)      642
    set L(step_h)       48

    # Bottom row of the strip, on the SAME grid as the steppers above and the
    # same y as the identity block's action row.
    set L(scale_y)      722
    set L(scale_h)       48
    set L(scale_read_x) 520 ; set L(scale_read_w) 176   ;# live readout
    set L(scale_set_x)  730 ; set L(scale_set_w)  176   ;# Set dose button
    set L(act_scan_x)   940                             ;# Scan bag
    set L(act_w)        176 ; set L(act_h)         48

    # ---- last shot tile internals (0.23.0) ------------------------------
    #
    # Identity on the left, metrics on the right, so the taller type fits in
    # a shorter card. Mirrors the next-shot card's row order exactly:
    # LABEL -> PROFILE -> roaster -> bean type.
    set L(last_id_x)   706 ; set L(last_id_w)  274
    set L(last_val_x)  796      ;# PROFILE value on THIS card -- NOT id_val_x,
                                ;# which is the next-shot card's 130 and lands
                                ;# inside the grind tile (seen on the tablet)
    set L(last_label_y) 36
    set L(last_prof_y)  60
    set L(last_roast_y) 88
    # The last shot's bean name uses font_primary (22px), not the 40px hero:
    # 274px holds ~11 characters at 40px, which cut "Jorge Diaz Campos" to
    # "Jorge Dia...". The owner's mockup also shows this name smaller than the
    # next-shot one -- this card is a summary, that one is the control.
    set L(last_name_y) 108

    # Four metrics on a 76 pitch: 996 + 3*76 + 76 = 1300, the tile's inner
    # edge (682 + 642 - 24).
    set L(last_met_x)  996 ; set L(last_met_pitch) 76
    set L(last_met_label_y) 88
    set L(last_met_val_y)  112
    set L(last_met_sub_y)  140  ;# the derived ratio, under YIELD

    # Water tank level (0.24.0), in the card's top-right corner -- the only
    # space on the page that was empty, and where every other skin puts its
    # tank indicator. It is machine status rather than shot data, so it takes
    # the blue flow colour instead of the ink scale: it must not read as one
    # of the four metrics beneath it.
    #   label 36..52, value 30..56, metric labels start at 88.
    set L(water_label_y)  36
    set L(water_val_y)    30

    # Shot history is a text link now, matching Curve / Shot analysis on the
    # grind tile rather than being the only button on the card.
    set L(hist_y)      172

    set L(pad_x)     24        ;# inner padding of a tile
    set L(pad_y)     20

    # ---- flow pages (espresso / steam / water / flush) -----------------
    set L(center_x)      670
    set L(flow_state_y)  110
    set L(flow_timer_y)  210
    set L(flow_panel_x)  170
    set L(flow_panel_y)  420
    set L(flow_panel_w) 1000
    set L(flow_panel_h)  170
    set L(flow_hint_y)   640

    # Compact variant, used on the espresso page so a live chart fits.
    set L(fc_state_y)    30
    set L(fc_timer_y)    76
    set L(fc_chart_x)    16  ; set L(fc_chart_y)  186
    set L(fc_chart_w)  1308  ; set L(fc_chart_h)  318
    set L(fc_panel_x)   170  ; set L(fc_panel_y)  520
    set L(fc_panel_w)  1000  ; set L(fc_panel_h)  150
    set L(fc_hint_y)    700

    # ---- settings page grid --------------------------------------------
    #
    # These were literals inside build_settings and restated again in
    # tools/check_skin.tcl and make_backgrounds.py, so a change had to be made
    # in three places. They are tokens now; the generator still mirrors them
    # by hand (it is Python) but the harness reads these.
    #
    # Left 170..630 (460 wide), right 670..1170 (500 wide) -- 170 clear on
    # BOTH page edges, one md gap between the columns.
    #
    # 0.24.0 briefly made them equal, for a build where DECENT APP sat in the
    # left column: its 200-wide button does not clear the caption beside it
    # inside 460. The owner then placed DECENT APP bottom-RIGHT instead, so
    # the wide column holds every button again and these are back to the
    # tablet-verified 460 / 500. Do not "tidy" them to equal widths without
    # moving a button first.
    set L(set_col_l)  170 ; set L(set_col_l_w) 460
    set L(set_col_r)  670 ; set L(set_col_r_w) 500
    set L(set_row_h)  118 ; set L(set_rows) {110 244 378 512}
    set L(set_done_y) 690 ; set L(set_done_w) 240 ; set L(set_done_h) 72

    # Stepper group inside a settings row: pill, gap, value, gap, pill.
    set L(set_step_w) 44 ; set L(set_step_gap) 8
    set L(set_val_w) 100 ; set L(set_step_h)  48

    # The alternating rows' mode line (0.26.0): "TIME | flow". The second word
    # starts at a fixed offset so the two text items never reflow -- the
    # longest first word is TEMP at ~40px, so 70 clears it.
    #
    # Its tap target is 48 tall (over the 44px floor) and wide enough to be
    # hit without aiming, while ending well clear of the stepper group: the
    # left column's group starts at 402, this ends at 170 + 24 + 180 = 374.
    set L(set_mode_dx) 70
    set L(set_mode_w) 180 ; set L(set_mode_h) 48

    # ---- fonts: physical pixels, 16px floor ----------------------------
    # Fallback names first, so every key is valid even if font creation
    # fails on an unusual build.
    set L(font_title)   Helv_20_bold
    set L(font_hero)    Helv_20_bold
    set L(font_section) Helv_18_bold
    set L(font_primary) Helv_10_bold
    set L(font_body)    Helv_9
    set L(font_caption) Helv_8
    set L(font_button)  Helv_10_bold
    set L(font_label)   Helv_8
    set L(font_data)    Helv_10_bold
    set L(font_metric)  Helv_20_bold
    set L(font_bt)      Helv_8

    _load_font_families

    # Deliberately NOT dui's own load_font here. That routes through
    # `dui font load`, which computes int([dui cget fontm] * size) and hands
    # a POSITIVE size to `font create` -- i.e. points, which scale
    # unpredictably with Android DPI. fontm is
    # ::settings(default_font_calibration), 0.5 on this tablet, so a 19 would
    # become a 9pt font. We take Inter's family name from the loader and
    # create the fonts ourselves at NEGATIVE (pixel) sizes instead.
    #
    # Weight comes from the file, not from -weight, so each weight is loaded
    # from its own TTF. -weight bold is only used on the Helvetica fallback,
    # where there is no separate bold face to point at.
    catch {
        foreach {key famkey ref bold} {
            hero    mono_bold 84 1
            title   sans_bold 40 1
            metric  mono_bold 40 1
            data    mono      26 0
            section mono      24 0
            primary sans_semi 22 1
            button  sans_semi 20 1
            body    sans      19 0
            caption sans      16 0
            label   sans_semi 15 1
            bt      symbol    22 0
        } {
            set px [expr {int(max(16, round($ref * $font_scale)))}]
            set fname "LUMEN_$key"
            set family [_font_family $famkey]
            set weight [_font_weight $famkey $bold]

            if { [lsearch -exact [font names] $fname] >= 0 } {
                font configure $fname -family $family -size [expr {-$px}] -weight $weight
            } else {
                font create $fname -family $family -size [expr {-$px}] -weight $weight
            }
            set L(font_$key) $fname
        }
    }
}

#############################################################################
#  Font families
#
#  Inter for UI text, NotoSansMono for every number. The mono faces matter:
#  doses, yields, times and grind settings all line up in columns, and a
#  proportional face makes those columns ragged.
#############################################################################

proc ::lumen::_load_font_families {} {
    variable F
    array unset F
    array set F {}

    # Fallbacks, used if the TTFs cannot be registered (e.g. off-tablet).
    set F(sans)      "Helvetica" ; set F(sans_ok)      0
    set F(sans_semi) "Helvetica" ; set F(sans_semi_ok) 0
    set F(sans_bold) "Helvetica" ; set F(sans_bold_ok) 0
    set F(mono)      "Courier"   ; set F(mono_ok)      0
    set F(mono_bold) "Courier"   ; set F(mono_bold_ok) 0
    set F(symbol)    "Helvetica" ; set F(symbol_ok)    0
    foreach k {sans sans_semi sans_bold mono mono_bold symbol} { set F(${k}_collides) 0 }

    # The app's own icon font, which carries a real Bluetooth glyph at
    # U+F293 (dui.tcl:1640). Loaded from wherever dui already has it.
    catch {
        set fam [::dui::font::add_or_get_familyname $::dui::symbol::font_filename]
        if { $fam ne "" } { set F(symbol) $fam ; set F(symbol_ok) 1 }
    }

    set dir "[homedir]/skins/Lumen/fonts"

    foreach {key file} {
        sans      Inter-Regular.ttf
        sans_semi Inter-SemiBold.ttf
        sans_bold Inter-Bold.ttf
        mono      NotoSansMono-SemiBold.ttf
        mono_bold NotoSansMono-ExtraBold.ttf
    } {
        if { [catch {
            set fam [::dui::font::add_or_get_familyname [file join $dir $file]]
        } err] } {
            msg -NOTICE "Lumen: could not register $file ($err); falling back"
            continue
        }
        if { $fam ne "" } {
            set F($key) $fam
            set F(${key}_ok) 1
        } else {
            msg -NOTICE "Lumen: no family name for $file; falling back"
        }
    }

    # Several weights of one typeface can register under a SINGLE family
    # name. On this tablet Inter-Bold.ttf reports family "Inter" -- exactly
    # what Inter-Regular.ttf reports -- so naming the family alone does not
    # select the bold face, and text asked for in "bold" would silently
    # render regular. Where that happened, ask Tk for the weight explicitly.
    foreach k {sans sans_semi sans_bold mono mono_bold} {
        foreach k2 {sans sans_semi sans_bold mono mono_bold} {
            if { $k eq $k2 } { continue }
            if { $F($k) eq $F($k2) } { set F(${k}_collides) 1 }
        }
    }
}

proc ::lumen::_font_weight { famkey bold } {
    variable F
    if { !$bold } { return "normal" }
    # Nothing real loaded: let Tk embolden the fallback face.
    if { ![_font_family_ok $famkey] } { return "bold" }
    # Family name is shared with another face, so it cannot select this one.
    if { [info exists F(${famkey}_collides)] && $F(${famkey}_collides) } { return "bold" }
    # This face owns its family name; the file already carries the weight.
    return "normal"
}

proc ::lumen::_font_family { key } {
    variable F
    if { [info exists F($key)] } { return $F($key) }
    return "Helvetica"
}

proc ::lumen::_font_family_ok { key } {
    variable F
    if { [info exists F(${key}_ok)] } { return $F(${key}_ok) }
    return 0
}

#############################################################################
#  Glass primitive
#
#  Mechanism copied verbatim from the proven rounded_rect in
#  plugins/GrindAdvisor/GrindAdvisor.tcl: a smoothed canvas polygon. The
#  specular top edge is what actually sells "glass" without a blur.
#############################################################################

#############################################################################
#  Depth
#
#  Tk canvas has no gradients and no alpha, so every soft edge here is built
#  from stacked solid shapes in interpolated colours. All of it is drawn once
#  at page build, so there is no runtime cost at all.
#
#  Deliberately NOT attempted: a gradient inside each panel. Bands clipped to
#  a rounded rectangle need either clipping (Tk has none) or bands with the
#  panel's own 26px corner radius, whose rounded bottom edges read as stacked
#  pills rather than a gradient. The backdrop, bloom and shadow carry the
#  depth without that artefact.
#############################################################################

# A vertical gradient wash and a warm radial bloom were built here in 0.6.0
# and removed in 0.6.1. Both made the screen worse, for one reason worth
# recording:
#
#   The design mockup's panels were genuinely TRANSLUCENT, so they tracked
#   whatever gradient sat behind them and kept their edges everywhere. Tk
#   canvas has no alpha, so Lumen's panels are one fixed tone. Put a gradient
#   behind them and near the top of the screen the backdrop (#151C2A) and the
#   panel fill (#191E26) are practically the same colour -- the panels
#   dissolve into the background and only the shadow ring shows, which reads
#   as a crude black outline around everything.
#
# A flat ground is not a compromise here, it is what makes the panels legible.
# Reproducing the mockup's depth honestly needs real translucency, i.e. baked
# PNG panels, which is the tooling route rejected at the start of the project.

proc ::lumen::rounded_rect { page x1 y1 x2 y2 radius args } {
    set r $radius
    if { $r * 2 > ($x2 - $x1) } { set r [expr {($x2 - $x1) / 2}] }
    if { $r * 2 > ($y2 - $y1) } { set r [expr {($y2 - $y1) / 2}] }
    set pts [list \
        [expr {$x1 + $r}] $y1 \
        [expr {$x2 - $r}] $y1 \
        $x2 $y1 \
        $x2 [expr {$y1 + $r}] \
        $x2 [expr {$y2 - $r}] \
        $x2 $y2 \
        [expr {$x2 - $r}] $y2 \
        [expr {$x1 + $r}] $y2 \
        $x1 $y2 \
        $x1 [expr {$y2 - $r}] \
        $x1 [expr {$y1 + $r}] \
        $x1 $y1]
    return [uplevel #0 [list dui add canvas_item polygon $page {*}$pts -smooth 1 {*}$args]]
}

# All arguments in DESIGN px.
proc ::lumen::glass { page x y w h args } {
    variable C
    variable L
    variable baked_pages

    # Already in the background image; drawing it again would flatten it.
    if { [lsearch -exact $baked_pages $page] >= 0 } { return }

    array set o [list \
        -radius  $L(radius) \
        -fill    $C(glass) \
        -outline $C(glass_brd) \
        -spec    1 \
        -tags    "" ]
    array set o $args

    set x1 [X $x] ; set y1 [Y $y]
    set x2 [X [expr {$x + $w}]] ; set y2 [Y [expr {$y + $h}]]

    set tagargs {}
    if { $o(-tags) ne "" } { set tagargs [list -tags $o(-tags)] }

    # NO drop shadow. Tried in 0.6.0 and reverted: on a near-black ground the
    # shadow tones (#04060A -> #020407) span about two RGB values, so the
    # "falloff" was a solid near-black ring around every panel -- a hard
    # outline, not depth. A dark theme leaves a darker shadow nowhere to go.

    rounded_rect $page $x1 $y1 $x2 $y2 [X $o(-radius)] \
        -fill $o(-fill) -outline $o(-outline) -width 2 {*}$tagargs

    if { $o(-spec) } {
        # Bright hairline inset from the corners along the top edge.
        set sx1 [X [expr {$x + $o(-radius) * 0.6}]]
        set sx2 [X [expr {$x + $w - $o(-radius) * 0.6}]]
        set sy  [expr {$y1 + 2}]
        uplevel #0 [list dui add canvas_item line $page $sx1 $sy $sx2 $sy \
            -fill $C(spec) -width 2]
    }
}

# Small pill used for status chips.
proc ::lumen::chip { page x y text args } {
    variable C
    variable L

    array set o [list -fill $C(ink_2) -outline $C(glass_brd) -bg $C(glass) -w 0]
    array set o $args

    set h 26
    set w $o(-w)
    if { $w <= 0 } { set w [expr {[string length $text] * 8 + 24}] }

    glass $page $x $y $w $h -radius 13 -fill $o(-bg) -outline $o(-outline) -spec 0
    dui add dtext $page [X [expr {$x + $w / 2.0}]] [Y [expr {$y + $h / 2.0}]] \
        -text $text -font $L(font_label) -fill $o(-fill) \
        -anchor center -justify center
}

#############################################################################
#  Live data
#
#  Every proc here is called from a -textvariable, which dui re-substitutes
#  every ::settings(timer_interval) ms (200 on this app) for the CURRENT page
#  only, and only touches the canvas when the value actually changed. So
#  these must stay cheap and must never touch the filesystem.
#
#  In particular: GrindAdvisor's own load_last_recommendation reads a file.
#  We never call it. Its plugin.tcl already calls it once at load, and
#  save_last_recommendation keeps the in-memory dict current, so reading the
#  namespace variable is free.
#
#  Everything degrades to "--" when a plugin is absent or disabled.
#############################################################################

namespace eval ::lumen::data {}

# Safe global read. Works for array elements: _s ::settings(drink_weight)
proc ::lumen::data::_s { name {default ""} } {
    upvar #0 $name v
    if { [info exists v] } { return $v }
    return $default
}

proc ::lumen::data::_is_pos { v } {
    if { $v eq "" } { return 0 }
    if { [catch { set ok [expr {double($v) > 0}] }] } { return 0 }
    return $ok
}

proc ::lumen::data::_ellipsis { s max } {
    if { [string length $s] <= $max } { return $s }
    return "[string range $s 0 [expr {$max - 3}]]..."
}

# GrindAdvisor states its working in parentheses -- "Regression over 8 shots
# (slope -29.16 s/grind, predicts 26.8s at 8.1). (dose: ...)". That is three
# wrapped lines on the tile and it collided with the row beneath. The tile
# shows the summary; the full text is one tap away in the popup.
proc ::lumen::data::_short_reason { s } {
    set i [string first " (" $s]
    if { $i > 12 } { set s [string trim [string range $s 0 [expr {$i - 1}]]] }
    return [_ellipsis $s 88]
}

proc ::lumen::data::_num { v {dp 1} {default "--"} } {
    if { $v eq "" } { return $default }
    if { [catch { set out [format "%.${dp}f" $v] }] } { return $default }
    return $out
}

# ---------------------------------------------------------------- grind ---

# The recommendation dict, or {} if unavailable/not ok/not about this bag.
#
# 0.21.0: the bag-currency check. Every grind accessor funnels through here,
# so one guard resets the whole tile coherently -- the hero goes to "--", the
# delta, method chip and confidence band blank, and grind_note explains why.
#
# Before this, the tile kept displaying the PREVIOUS bag's number after a bag
# or profile switch, right up until the next shot was pulled. That number was
# a calibration for a different coffee.
#
# last_recommendation_is_current arrived in Grind Advisor 3.7.0 and fails safe
# on its own side (unknown identity -> "current"). The [info procs] guard here
# is for OLDER Grind Advisor builds, where the proc does not exist at all: in
# that case behave exactly as 0.20.0 did rather than blanking the tile for
# everyone still on 3.6.x.
proc ::lumen::data::grind_rec {} {
    # 0.22.0 preferred path: ask for the recommendation belonging to the bag
    # that is loaded NOW. Grind Advisor 3.8.0 computes it from that bag's own
    # shots and memoizes per bag, so this is safe on the 200 ms refresh tick.
    #
    # This replaces blanking. 0.21.0 could only tell that the saved
    # recommendation was about a different bag and cleared the tile -- but a
    # bag you cycle back to has its own history and its own regression, and
    # throwing that away was the wrong call.
    if { [info procs ::plugins::GrindAdvisor::recommendation_for_current_bag] ne "" } {
        if { ![catch { set rec [::plugins::GrindAdvisor::recommendation_for_current_bag] } err] } {
            if { $rec eq "" } { return {} }
            if { ![catch { dict size $rec }] \
              && [dict exists $rec ok] && [dict get $rec ok] } {
                return $rec
            }
            return {}
        }
        msg -ERROR "Lumen: could not get the recommendation for this bag: $err"
    }

    # Fallbacks for older Grind Advisor builds, in descending order of
    # capability: 3.7.x can at least say whether the saved rec is current;
    # 3.6.x and earlier can only hand over whatever was saved last.
    if { ![info exists ::plugins::GrindAdvisor::last_recommendation] } { return {} }
    set rec $::plugins::GrindAdvisor::last_recommendation
    if { $rec eq "" } { return {} }
    if { [catch { dict size $rec }] } { return {} }
    if { ![dict exists $rec ok] || ![dict get $rec ok] } { return {} }
    if { [info procs ::plugins::GrindAdvisor::last_recommendation_is_current] ne "" } {
        if { [catch { set cur [::plugins::GrindAdvisor::last_recommendation_is_current] }] } {
            return $rec
        }
        if { !$cur } { return {} }
    }
    return $rec
}

proc ::lumen::data::_g { rec key {default ""} } {
    if { $rec ne "" && [dict exists $rec $key] } { return [dict get $rec $key] }
    return $default
}

proc ::lumen::data::grind_next {} {
    return [_num [_g [grind_rec] next] 1]
}

proc ::lumen::data::grind_delta {} {
    set rec [grind_rec]
    if { $rec eq "" } { return "" }
    set from [_g $rec grind]
    set to   [_g $rec next]
    if { $from eq "" || $to eq "" } { return "" }
    if { [catch { set d [expr {double($to) - double($from)}] }] } { return "" }
    if { abs($d) < 0.05 } { return [translate "no change"] }
    return [format "%+.1f" $d]
}

# GrindAdvisor v3's ladder has FIVE rungs, not two -- see its own
# _forecast_method_label in plugins/GrindAdvisor/GrindAdvisor.tcl:1997:
#   first_shot  (n=1)  two_shot  (n=2)  regression  (n>=3)
#   regression_fallback   (n>=3, but the fitted slope is too flat to solve)
#   regression_untrusted  (n>=3, the slope solves but R2 < 0.30 -- the times
#                          are not tracking grind, so the fit is discarded
#                          and the ladder answers instead)
# Only the first two were mapped here originally, so the chip sat empty for
# the first two shots of every bag. Then GrindAdvisor 3.10.0 added the fifth
# rung and this map was not updated with it, so the chip fell through to the
# raw dict key and read "regression_unt..." on the tablet (0.27.2).
#
# Labels are shortened to fit the 150px chip; the Why? popup carries
# GrindAdvisor's own full wording. Keep them SHORT -- see the budget on the
# fallback below.
proc ::lumen::data::grind_method {} {
    set rec [grind_rec]
    if { $rec eq "" } { return "" }
    set m [_g $rec method]
    switch -exact -- $m {
        first_shot           { return [translate "First shot"] }
        two_shot             { return [translate "2-shot"] }
        regression           { return [translate "Regression"] }
        regression_fallback  { return [translate "Pairwise"] }
        regression_untrusted { return [translate "Weak fit"] }
    }
    # A rung added by a newer GrindAdvisor: show it rather than nothing, so
    # the chip never silently goes blank again.
    #
    # 12, not the 16 this started at. 16 was picked without measuring, and
    # measured off the tablet screenshot it is ~134px of text in a 150px
    # chip -- ink to the rounded ends, no margin. font_label is 16px Inter
    # SemiBold, about 8.4px per character here, so 12 characters is ~100px
    # and sits inside the chip with room on both sides.
    return [_ellipsis $m 12]
}

proc ::lumen::data::grind_band {} {
    set rec [grind_rec]
    if { $rec eq "" } { return "" }
    set band [_g $rec confidence_band]
    set n    [_g $rec n]
    if { $band eq "" } {
        if { $n ne "" } { return "[translate {Shots}]: $n" }
        return ""
    }
    if { $n ne "" } { return "$band  -  $n [translate {shots}]" }
    return $band
}

# Regression needs 3 shots on a bag before it can forecast. Say so plainly
# rather than showing a number the model cannot justify.
proc ::lumen::data::grind_note {} {
    set rec [grind_rec]
    if { $rec eq "" } {
        return [translate "Pull a shot on this bag to get a grind recommendation."]
    }
    set reason [_g $rec reason]
    if { $reason ne "" } { return [_short_reason $reason] }
    if { [_g $rec method] eq "regression_fallback" } {
        return [translate "Not enough shots on this bag yet for a full forecast."]
    }
    return ""
}

# ------------------------------------------------------------ last shot ---
#
# 0.25.0: this card reports THE SHOT'S OWN RECORD, not the machine's current
# settings.
#
# It used to read ::settings(grinder_setting) / (grinder_dose_weight) /
# (drink_weight) directly -- the same fields shot.tcl writes into the file, so
# for a shot pulled in this session the two agree and the distinction never
# showed. It shows in two situations the owner hit:
#
#   * Correcting a shot in the Shot History Editor writes the .shot FILE and
#     nothing else -- by that plugin's design. The live setting keeps
#     reporting the figure you just corrected away from, so the card denied
#     an edit that had actually worked.
#   * ::settings(drink_weight) does not survive a restart at all (0.24.1).
#
# So while ::lumen::last_shot_rec holds the newest file's values -- i.e. until
# a shot starts in this session and the live settings become the better
# source -- they win. Cost is nil: the file was already read at startup for
# the chart and the profile name.
#
# The NEXT SHOT card is unaffected and still reads the live/DYE-staged values.
# That is the whole point: one card is the record, the other is the plan.

# One latched field, or "" when the file did not record it.
proc ::lumen::data::_rec { key } {
    if { ![info exists ::lumen::last_shot_rec($key)] } { return "" }
    return $::lumen::last_shot_rec($key)
}

proc ::lumen::data::_dose_raw {} {
    foreach src [list [_rec dose] [_s ::settings(grinder_dose_weight)]] {
        if { [_is_pos $src] } { return $src }
    }
    return ""
}

proc ::lumen::data::last_dose {} {
    return [_num [_dose_raw] 1]
}

# The last shot's yield, in descending order of authority:
#
#   the file latch            -- what the shot RECORDED, corrections included.
#   ::settings(drink_weight)  -- what the app recorded for a shot pulled in
#                                this session, and the field shot.tcl writes.
#   ::de1(pour_volume)        -- volumetric fallback when no scale reported.
#
# Returns "" rather than 0 when there is nothing: a shot pulled without a
# scale has no yield, and _num turns "" into "--". It used to fall through to
# whatever the last source held, which printed a confident "0.0" -- the tablet
# showed exactly that next to a grind tile reporting 37.8g for the same shot.
proc ::lumen::data::_yield_raw {} {
    foreach src [list [_rec yield] \
                      [_s ::settings(drink_weight)] \
                      [_s ::de1(pour_volume)]] {
        if { [_is_pos $src] } { return $src }
    }
    return ""
}

proc ::lumen::data::last_yield {} {
    return [_num [_yield_raw] 1]
}

proc ::lumen::data::last_time {} {
    if { [catch { set n [espresso_elapsed length] }] } { return "--" }
    if { $n <= 0 } { return "--" }
    if { [catch { set t [espresso_elapsed range end end] }] } { return "--" }
    # A cleared series reads 0.0 at idle; that is "no shot", not a 0.0s shot.
    if { ![_is_pos $t] } { return "--" }
    return [_num $t 1]
}

proc ::lumen::data::last_ratio {} {
    # Same sources as the DOSE and YIELD shown above it, or the caption would
    # contradict the two numbers it sits between.
    set d [_dose_raw]
    set y [_yield_raw]
    if { ![_is_pos $d] || ![_is_pos $y] } { return "--" }
    if { [catch { set r [expr {double($y) / double($d)}] }] } { return "--" }
    return [format "1:%.2f" $r]
}

# The ratio as it appears UNDER the last shot's yield (0.23.0), matching the
# next-shot card. Parenthesised so it reads as derived, and blank rather than
# "--" when there is nothing to derive.
proc ::lumen::data::last_ratio_note {} {
    set r [last_ratio]
    if { $r eq "--" } { return "" }
    return "($r)"
}

# ------------------------------------------------------------ next shot ---
#
# DYE stages next-shot values in ::plugins::DYE::settings(next_*) and falls
# back to the core ::settings. We do the same, so the strip still works with
# DYE disabled.

proc ::lumen::data::_dye { field } {
    if { ![info exists ::plugins::DYE::settings(next_$field)] } { return "" }
    return [string trim [set ::plugins::DYE::settings(next_$field)]]
}

proc ::lumen::data::_field { field } {
    set v [_dye $field]
    if { $v ne "" } { return $v }
    return [string trim [_s ::settings($field)]]
}

proc ::lumen::data::bean_brand {} {
    set v [_field bean_brand]
    if { $v eq "" } { return [translate "No bean set"] }
    # Must stay on ONE line. The item is 272px wide at 40px Inter, so a
    # longer name wraps and the second line lands on top of the type/roast
    # line below it. ~13 characters is what fits; beyond that, truncate.
    return [_ellipsis $v 13]
}

# ---- identity, 0.23.0 -----------------------------------------------------
#
# The ROASTER is the small line and the BEAN TYPE is the hero. Roasters run
# long -- "MAN VERSUS MACHINE Specialty Coffee Roasters" is 44 characters --
# while the bean type is short and is what actually tells two bags apart on
# the counter. Leading with the roaster meant every hero line was truncated.

# Roaster, small line above the hero. 460px at 16px caption holds ~52
# characters, so this almost never truncates; the cap is a backstop.
proc ::lumen::data::bean_roaster_line {} {
    set v [_field bean_brand]
    if { $v eq "" } { return "" }
    return [_ellipsis $v 46]
}

# Bean type, the hero line. 460px at 40px Inter holds ~19 characters.
proc ::lumen::data::bean_name_line {} {
    set v [_field bean_type]
    if { $v ne "" } { return [_ellipsis $v 19] }
    # No type: fall back to the roaster rather than showing nothing, since
    # a bag with only a roaster is still a bag.
    set b [_field bean_brand]
    if { $b ne "" } { return [_ellipsis $b 19] }
    return [translate "No bean set"]
}

# Tasting notes, forced onto ONE line. Blank when unset -- the row is simply
# not drawn, so an empty field never leaves a gap. This is the best-populated
# optional bean field (42% of shots) and the most informative.
#
# bean_notes is genuinely MULTI-LINE in real data: this tablet's Morgon bag
# holds "Peru | Washed | Bourbon\nJuicy, Forest Berries, Cacao". Drawn as-is
# the second line ran straight through the cycler arrows and Edit. Newlines
# (and any other whitespace runs) collapse to a separator, and the result is
# capped at what 460px holds at the 16px caption size, so it can neither wrap
# nor overflow into the stepper columns.
proc ::lumen::data::bean_notes_line {} {
    set v [_field bean_notes]
    if { $v eq "" } { return "" }
    regsub -all {\s*[\r\n]+\s*} $v " - " v
    regsub -all {[ \t]+} $v " " v
    return [_ellipsis [string trim $v] 52]
}

# The same three for the LAST shot's card. The narrower column (274px) takes
# a tighter cap.
proc ::lumen::data::last_roaster_line {} {
    set v [string trim [_s ::settings(bean_brand)]]
    if { $v eq "" } { return "" }
    return [_ellipsis $v 30]
}

proc ::lumen::data::last_name_line {} {
    # 274px at font_primary (22px) holds ~24 characters.
    set v [string trim [_s ::settings(bean_type)]]
    if { $v ne "" } { return [_ellipsis $v 24] }
    set b [string trim [_s ::settings(bean_brand)]]
    if { $b ne "" } { return [_ellipsis $b 24] }
    return "--"
}

# The grind the last shot was pulled at. ::settings(grinder_setting) persists
# across shots, so this reads the same as the next shot's grind until you
# change it -- the same caveat the dose and yield readouts already carry.
# Not routed through _is_pos: a grinder setting is not necessarily a number.
# Plenty of grinders are labelled in clicks, letters or half-steps, and the
# field is free text, so anything non-empty is a real setting.
proc ::lumen::data::last_grind {} {
    foreach src [list [_rec grind] [_s ::settings(grinder_setting)]] {
        set v [string trim $src]
        if { $v ne "" } { return $v }
    }
    return "--"
}

proc ::lumen::data::bean_sub {} {
    set parts {}
    set t [_field bean_type]
    if { $t ne "" } { lappend parts $t }
    set r [_field roast_date]
    if { $r ne "" } { lappend parts "[translate {roasted}] $r" }
    if { [llength $parts] == 0 } { return [translate "Tap to add bean details"] }
    return [join $parts "  -  "]
}

proc ::lumen::data::next_grind {} {
    set v [_field grinder_setting]
    if { $v eq "" } { return "--" }
    return $v
}

proc ::lumen::data::next_dose {} {
    return [_num [_s ::settings(grinder_dose_weight)] 1]
}

# Mirrors DYE's own get_next: the 2c profile type keeps its target in a
# separate setting.
proc ::lumen::data::_target_raw {} {
    if { [string trim [_s ::settings(settings_profile_type)]] eq "settings_2c" } {
        set v [_s ::settings(final_desired_shot_weight_advanced)]
        if { [_is_pos $v] } { return $v }
    }
    return [_s ::settings(final_desired_shot_weight)]
}

proc ::lumen::data::next_yield {} {
    return [_num [_target_raw] 1]
}

# One decimal, matching the +/- stepper's 0.1 increment (and fitting the
# 76px value span between the stepper pills).
proc ::lumen::data::next_ratio {} {
    set d [_s ::settings(grinder_dose_weight)]
    set y [_target_raw]
    if { ![_is_pos $d] || ![_is_pos $y] } { return "--" }
    if { [catch { set r [expr {double($y) / double($d)}] }] } { return "--" }
    return [format "1:%.1f" $r]
}

# The ratio as it appears UNDER the yield value (0.21.0). Parenthesised so it
# reads as a derived note rather than a second editable number, and blank --
# not "--" -- when there is nothing to derive, because an empty line under the
# yield is quieter than a placeholder.
proc ::lumen::data::next_ratio_note {} {
    set r [next_ratio]
    if { $r eq "--" } { return "" }
    return "($r)"
}

# The profile the NEXT shot will use. DYE can stage a profile for the next
# shot, so _field checks that first and falls back to the loaded one.
proc ::lumen::data::next_profile {} {
    set v [_field profile_title]
    if { $v eq "" } { return "--" }
    # The tile is 176 wide at 19px; ~18 characters fit before it wraps into
    # the row beneath.
    return [_ellipsis $v 18]
}

# The profile the LAST shot actually ran on.
#
# NOT ::settings(profile_title): that is the profile loaded RIGHT NOW, which
# stops matching the last shot the moment you switch profiles -- and showing
# the two side by side when they differ is the entire point of this line.
# ::lumen::last_shot_profile is latched at shot completion and seeded at
# startup from the newest history file.
proc ::lumen::data::last_profile {} {
    set v [string trim $::lumen::last_shot_profile]
    if { $v eq "" } { return "--" }
    return [_ellipsis $v 22]
}

# Live scale weight for the flow pages. Shows "--" rather than blank here,
# because on those pages the column always needs to read as a value.
# Blank once the chart has data. An empty BLT graph autoscales x to
# -0.1..0.1, which reads as a broken chart rather than an empty one.
proc ::lumen::data::chart_empty_note {} {
    if { [catch { set n [espresso_elapsed length] }] } { return "" }
    if { $n > 1 } { return "" }
    return [translate "No shot data yet - pull a shot"]
}

# Last line of defence on anything shown as a duration. espresso_timer is
# ([clock milliseconds] - $::timers(espresso_start))/1000, so before
# espresso_start has ever been assigned it subtracts from zero and yields
# epoch time -- a colossal number. flush_pour_timer returns the literal
# strings "-0" and "-1" when its timer has not been started, and "%.0f" of
# "-0" prints "-0". Anything outside a plausible flow duration is a glitch,
# not a reading; the +0 normalises "-0" to 0.
proc ::lumen::data::_sane_secs { v } {
    if { ![string is double -strict $v] } { return 0 }
    if { $v < 0 || $v > 3600 } { return 0 }
    return [expr {$v + 0}]
}

# Elapsed seconds of the flow THIS page visit is showing, or 0.
#
# 0.24.0. The core's four flow timers (de1app-core/vars.tcl:295-339) are only
# reset when the NEXT flow of that kind reaches its "during" phase
# (binary.tcl:1507-1527), while the page opens as soon as the machine enters
# the state. Between those two moments every timer still describes the
# PREVIOUS flow, and reading it there is what the owner saw: the espresso page
# showed ~450s -- the seconds since the last shot began -- for a few frames
# before flipping to 0 and counting normally. _sane_secs cannot catch that,
# because 450 is a perfectly plausible number.
#
# So the value is only shown when the flow it describes started after this
# page was last shown (::lumen::flow_opened, latched by latch_flow_open on
# each page's `show` action):
#
#   stop unset/0/before start -> the flow is RUNNING, count from start. Not
#       gated on the open time: if a page is shown mid-flow -- the skin
#       reloading, or a dialog closing over it -- the count must not blank.
#   stop after start          -> the flow has FINISHED. Show its total only if
#       it is the one this visit ran, so the final time stays on screen after
#       the shot; a flow from an earlier visit reads 0.
#
# Integer division throughout, matching the core's own timer procs, so the
# display truncates rather than rounding up at the half second.
proc ::lumen::data::_flow_secs { page start_key stop_key } {
    set st 0 ; set sp 0
    catch { set st $::timers($start_key) }
    catch { set sp $::timers($stop_key) }

    if { ![string is double -strict $st] || $st <= 0 } { return 0 }
    if { ![string is double -strict $sp] } { set sp 0 }

    if { $sp <= 0 || $sp < $st } {
        return [expr {([clock milliseconds] - $st) / 1000}]
    }

    set opened 0
    catch { set opened $::lumen::flow_opened($page) }
    if { $st < $opened } { return 0 }
    return [expr {($sp - $st) / 1000}]
}

proc ::lumen::data::_flow_text { page start_key stop_key } {
    set t 0
    catch { set t [_flow_secs $page $start_key $stop_key] }
    return "[format %.0f [_sane_secs $t]]s"
}

# Each page reads ITS OWN timer. They used to share espresso_secs, which is
# time since the last ESPRESSO started rather than the duration of the current
# flow: plausible shortly after a shot and 0 once more than an hour had passed
# (_sane_secs rejects > 3600). That was the "stuck at 0s" of 0.23.2.
proc ::lumen::data::espresso_secs {} {
    return [_flow_text espresso espresso_start espresso_stop]
}

proc ::lumen::data::steam_secs {} {
    return [_flow_text steam steam_pour_start steam_pour_stop]
}

proc ::lumen::data::water_secs {} {
    return [_flow_text water water_pour_start water_pour_stop]
}

proc ::lumen::data::flush_secs {} {
    return [_flow_text hotwaterrinse flush_pour_start flush_pour_stop]
}

# The steam page's temperature is the STEAM HEATER sensor
# (::de1(steam_heater_temperature) <- ShotSample(SteamTemp), de1_de1.tcl:544),
# which idles at the steam set point -- ~158C when the setting is 160. That
# is a real reading, not a glitch, but shown as plain "TEMP" it looks like a
# broken value. The column is labelled STEAM HEATER and this line states the
# set point underneath, so the number reads as intentional.
proc ::lumen::data::steam_target_note {} {
    set t [_s ::settings(steam_temperature)]
    if { ![string is double -strict $t] || $t <= 0 } { return "" }
    if { [catch { set out [return_temperature_measurement $t 1] }] } { return "" }
    return "[translate {target}] $out"
}

# ---- machine stepper readouts (Lumen settings page) -----------------------

proc ::lumen::data::brew_temp_value {} {
    set t [_s ::settings(espresso_temperature)]
    if { ![string is double -strict $t] } { return "--" }
    if { [catch { set out [return_temperature_measurement $t 0] }] } { return "--" }
    return $out
}

proc ::lumen::data::steam_time_value {} {
    set v [_s ::settings(steam_timeout)]
    if { ![string is double -strict $v] } { return "--" }
    if { $v <= 0 } { return [translate "off"] }
    return "[expr {round($v)}]s"
}

# steam_flow is stored as ml/s x 100 (Streamline steps it by 10 = 0.1 ml/s).
proc ::lumen::data::steam_flow_note {} {
    set v [_s ::settings(steam_flow)]
    if { ![string is double -strict $v] } { return "" }
    return "[format %.1f [expr {$v / 100.0}]] mL/s"
}

# The same number without the unit, for the big value in FLOW mode -- the row
# already says Flow, so "0.8 mL/s" at 26px mono only crowds the pills.
proc ::lumen::data::steam_flow_value {} {
    set v [_s ::settings(steam_flow)]
    if { ![string is double -strict $v] } { return "--" }
    return [format %.1f [expr {$v / 100.0}]]
}

# ---- alternating rows (0.26.0) --------------------------------------------
#
# STEAM shows time OR flow, HOT WATER temperature OR volume: one -/+ group per
# row driving whichever half is selected, with the other shown small beneath
# it. Owner request, from a mockup.
#
# The mode is a Lumen preference, not a machine setting, and it persists --
# whichever half you last steered is the one waiting for you next time.

proc ::lumen::data::steam_value {} {
    if { [::lumen::steam_mode] eq "flow" } { return [steam_flow_value] }
    return [steam_time_value]
}

proc ::lumen::data::steam_value_alt {} {
    if { [::lumen::steam_mode] eq "flow" } { return [steam_time_value] }
    return [steam_flow_value]
}

proc ::lumen::data::water_value {} {
    if { [::lumen::water_mode] eq "vol" } { return [water_volume_value] }
    return [water_temp_note]
}

proc ::lumen::data::water_value_alt {} {
    if { [::lumen::water_mode] eq "vol" } { return [water_temp_note] }
    return [water_volume_value]
}

# The mode line, split across TWO text items so the selected half can be the
# accent colour and the other one dim: a canvas text item's -fill is fixed at
# creation, so the words move between two fixed-colour items rather than the
# colours moving between two fixed words.
proc ::lumen::data::steam_mode_active {} {
    if { [::lumen::steam_mode] eq "flow" } { return [translate "FLOW"] }
    return [translate "TIME"]
}

proc ::lumen::data::steam_mode_other {} {
    if { [::lumen::steam_mode] eq "flow" } { return "| [translate {time}]" }
    return "| [translate {flow}]"
}

proc ::lumen::data::water_mode_active {} {
    if { [::lumen::water_mode] eq "vol" } { return [translate "VOL"] }
    return [translate "TEMP"]
}

proc ::lumen::data::water_mode_other {} {
    if { [::lumen::water_mode] eq "vol" } { return "| [translate {temp}]" }
    return "| [translate {vol}]"
}

proc ::lumen::data::flush_time_value {} {
    set v [_s ::settings(flush_seconds)]
    if { ![string is double -strict $v] } { return "--" }
    return "[expr {round($v)}]s"
}

proc ::lumen::data::water_volume_value {} {
    set v [_s ::settings(water_volume)]
    if { ![string is double -strict $v] } { return "--" }
    return "[expr {round($v)}] ml"
}

proc ::lumen::data::water_temp_note {} {
    set t [_s ::settings(water_temperature)]
    if { ![string is double -strict $t] } { return "" }
    if { [catch { set out [return_temperature_measurement $t 1] }] } { return "" }
    return $out
}

# Shows what the theme WILL be, so the button reads as a toggle rather than
# a label that never changes.
proc ::lumen::data::theme_label {} {
    set m $::lumen::theme_mode
    if { $::lumen::pending_theme ne "" } { set m $::lumen::pending_theme }
    if { $m eq "dark" } { return [translate "Dark"] }
    return [translate "Light"]
}

proc ::lumen::data::theme_note {} {
    if { $::lumen::pending_theme eq "" \
      || $::lumen::pending_theme eq $::lumen::theme_mode } {
        return [translate "Tap to switch. The app restarts to apply it."]
    }
    if { $::lumen::pending_theme eq "light" } {
        return [translate "Light selected. Tap Done and the app will restart."]
    }
    return [translate "Dark selected. Tap Done and the app will restart."]
}

proc ::lumen::data::smoothing_note {} {
    if { [::lumen::chart_smoothing] eq "linear" } {
        return [translate "Straight lines between samples, exactly as recorded."]
    }
    return [translate "Catmull-Rom curve through the same samples."]
}

proc ::lumen::data::version_line {} {
    return "Lumen v$::lumen::version"
}

proc ::lumen::data::smoothing_label {} {
    if { [::lumen::chart_smoothing] eq "linear" } { return [translate "Raw"] }
    return [translate "Smooth"]
}

proc ::lumen::data::stages_label {} {
    if { [::lumen::stages_shown] } { return [translate "Stages"] }
    return [translate "No stages"]
}

proc ::lumen::data::bag_count_value {} {
    return [::lumen::bag_count]
}

# The bag cycler's page indicator (0.27.0): one dot per reachable bag, filled
# for the one loaded. Leftmost is the most recent bag, which is the direction
# the left arrow moves in.
#
# Drawn as TEXT, not as canvas ovals, because a canvas item's -fill is fixed
# at creation: N ovals would need retagging and reconfiguring on every cycle,
# while a text item is re-evaluated on the refresh tick for free. Both glyphs
# were verified present in the shipped Inter faces before being used, and go
# through [format %c] rather than literal UTF-8 -- a literal arrow in this
# file was mangled once already (Grind Advisor v2.0.2's lesson).
proc ::lumen::data::bag_dots {} {
    set n [llength $::lumen::bag_list]
    # One bag is not a carousel, and zero means SDB has nothing to say.
    if { $n <= 1 } { return "" }
    set idx [::lumen::bag_index]
    set filled [format %c 0x25CF]
    set hollow [format %c 0x25CB]
    set out {}
    for { set i 0 } { $i < $n } { incr i } {
        lappend out [expr {$i == $idx ? $filled : $hollow}]
    }
    return [join $out "  "]
}

# Which bag of how many, for anyone who cannot read the dots at a glance.
proc ::lumen::data::bag_position {} {
    set n [llength $::lumen::bag_list]
    if { $n <= 1 } { return "" }
    set idx [::lumen::bag_index]
    if { $idx < 0 } { return "" }
    return "[expr {$idx + 1}]/$n"
}

# Water in the tank, in millilitres (0.24.0, owner request).
#
# ::de1(water_level) is the sensor reading in MILLIMETRES, already corrected
# by ::de1(water_level_mm_correction) where the notification is parsed
# (de1_comms.tcl:467). The mm -> mL curve comes from the machine's CAD and
# lives in the core as water_tank_level_to_milliliters (vars.tcl:3924), so
# that is what converts it -- exactly as DSx2 does it (procs_vars.tcl:470).
# Never reimplement that table here.
#
# The core seeds water_level to 20 before any machine has connected
# (machine.tcl:137), which would render as a confident "537 ml" with nothing
# plugged in, so the readout is suppressed unless the machine is actually
# talking to us. ::de1(last_ping) is the app's own liveness stamp and the
# water-level notification is one of the things that refreshes it
# (bluetooth.tcl:2640-2645), so it stays fresh for as long as there is a
# reading to show -- including while the machine is idle. 10s is the core's
# own staleness threshold (bluetooth.tcl:1693).
proc ::lumen::data::water_ml {} {
    set ping 0
    catch { set ping $::de1(last_ping) }
    if { ![string is double -strict $ping] || $ping <= 0 } { return "" }
    if { [expr {[clock seconds] - $ping}] > 10 } { return "" }

    set mm [_s ::de1(water_level)]
    if { ![string is double -strict $mm] || $mm <= 0 } { return "" }
    if { [catch { set ml [water_tank_level_to_milliliters $mm] }] } { return "" }
    if { ![string is double -strict $ml] } { return "" }
    return "[expr {round($ml)}] ml"
}

# Blank the label too when there is no reading, so the card does not carry a
# lone "WATER" heading with nothing under it.
proc ::lumen::data::water_label {} {
    if { [water_ml] eq "" } { return "" }
    return [translate "WATER"]
}

proc ::lumen::data::live_weight {} {
    set w [_s ::de1(scale_weight)]
    if { ![_is_pos $w] } { return "--" }
    return "[_num $w 1] g"
}

proc ::lumen::data::scale_connected {} {
    if { [catch { set c [::device::scale::is_connected] }] } { return 0 }
    if { [string is true -strict $c] || $c == 1 } { return 1 }
    return 0
}

# The real Bluetooth glyph from the app's own icon font (dui.tcl:1640 maps
# "bluetooth" to U+F293). Falls back to the letters "BT" if that font could
# not be registered, so this can never render as a tofu box.
proc ::lumen::data::scale_bt {} {
    if { ![scale_connected] } { return "" }
    if { [::lumen::_font_family_ok symbol] } { return "\uF293" }
    return "BT"
}

# True only while a `ble connect` to the scale is actually in flight
# (de1app-core/bluetooth.tcl:2018 sets it, the disconnect handler clears it).
# Without this the readout jumps straight from "no scale" to a weight with
# nothing in between, which reads as "the skin isn't noticing my scale" during
# the core's 10-second-per-attempt retry loop.
proc ::lumen::data::scale_connecting {} {
    if { ![info exists ::currently_connecting_scale_handle] } { return 0 }
    if { [catch { set c [expr {$::currently_connecting_scale_handle != 0}] }] } { return 0 }
    return $c
}

proc ::lumen::data::scale_weight_line {} {
    if { ![scale_connected] } {
        # No paired scale at all -- there is nothing to reconnect to.
        if { [_s ::settings(scale_bluetooth_address)] eq "" } {
            return [translate "no scale"]
        }
        if { [scale_connecting] } { return [translate "Connecting"] }
        return [translate "Connect"]
    }
    set w [_s ::de1(scale_weight)]
    if { $w eq "" } { return "--" }
    # An idle scale drifts a hair below zero and %.1f then prints "-0.0",
    # which looks broken. Anything inside a tenth is zero.
    if { ![catch { set n [expr {double($w)}] }] && abs($n) < 0.05 } { set w 0 }
    return "[_num $w 1] g"
}

# Live scale reading, blank unless a scale is actually reporting weight.
proc ::lumen::data::scale_line {} {
    set w [_s ::de1(scale_weight)]
    if { ![_is_pos $w] } { return "" }
    return "[_num $w 1] g [translate {on scale}]"
}

#############################################################################
#  Shot chart
#
#  The chart is a BLT/RBC `graph` widget bound to the app's live vectors, so
#  it draws itself during a shot and keeps the curves afterwards. Element
#  creation follows the proven pattern in skins/Streamline/skin.tcl.
#
#  Everything shares one 0..10 y axis, which is why two of the vectors are
#  pre-scaled by the app: espresso_temperature_basket10th is degrees/10, and
#  espresso_weight_chartable is 0.10 * scale weight (so 38g plots as 3.8).
#############################################################################

proc ::lumen::chart_smoothing {} {
    set v "linear"
    catch { set v $::settings(live_graph_smoothing_technique) }
    if { $v eq "" } { set v "linear" }
    return $v
}

# Stage separators shown? Lumen preference, default on.
proc ::lumen::stages_shown {} {
    set v 1
    catch {
        if { [info exists ::settings(lumen_chart_stages)] \
          && $::settings(lumen_chart_stages) ne "" } {
            set v $::settings(lumen_chart_stages)
        }
    }
    if { ![string is boolean -strict $v] } { set v 1 }
    return [expr {$v ? 1 : 0}]
}

# How many recent bean bags the home strip's bag cycler offers. Lumen
# preference, default 5, clamped to the same 3..10 band the stepper writes so
# a hand-edited settings file can never widen it.
#
# 0.20.0 ships the preference and its settings row only -- the cycler that
# consumes it lands in 0.21.0. The row has to exist now because the settings
# page background is baked, and a baked page cannot grow a row later without
# regenerating every asset.
# ---- the bag cycler's window (0.27.0) --------------------------------------
#
# The page indicator has to know how many bags the cycler offers and which one
# is loaded, on the 200 ms refresh tick. Asking SDB that often is exactly what
# the accessor rules forbid, so the LIST is cached here and only the index is
# computed live -- an lsearch over at most 10 strings, against values already
# in ::settings.
#
# Refreshed when the home page is shown and once at startup. That covers a new
# shot, a scan and a DYE edit without a database read per frame.

proc ::lumen::refresh_bag_list { args } {
    variable bag_list
    if { [catch {
        if { [info procs ::plugins::SDB::available_categories] eq "" } {
            set bag_list {}
            return
        }
        set bags [::plugins::SDB::available_categories bean_desc 1 {} 0]
        # Drop blanks: a shot saved with no bean fields yields an empty
        # bean_desc, and a dot for it would be a dot you cannot reach.
        set clean {}
        foreach b $bags {
            if { [string trim $b] ne "" } { lappend clean [string trim $b] }
        }
        set n [::lumen::bag_count]
        if { [llength $clean] > $n } { set clean [lrange $clean 0 [expr {$n - 1}]] }
        set bag_list $clean
    } err] } {
        msg -ERROR "Lumen: could not read the bag list: $err"
    }
}

# The loaded bag, as the string SDB builds for bean_desc: brand, type and
# roast date joined by single spaces.
proc ::lumen::current_bag {} {
    set cur [string trim "[::lumen::data::_field bean_brand] [::lumen::data::_field bean_type] [::lumen::data::_field roast_date]"]
    regsub -all { +} $cur " " cur
    return $cur
}

# Position of the loaded bag in that window, or -1 when it is not in it (a
# hand-typed bag, or one older than the window allows).
proc ::lumen::bag_index {} {
    variable bag_list
    if { [llength $bag_list] == 0 } { return -1 }
    return [lsearch -exact $bag_list [current_bag]]
}

# Which half of the STEAM row the -/+ pills drive: "time" or "flow" (0.26.0).
# A Lumen preference, stored the same way as the theme and the bag count, so
# an unknown or missing value falls back rather than throwing.
proc ::lumen::steam_mode {} {
    set v "time"
    catch {
        if { [info exists ::settings(lumen_steam_mode)] } {
            set v $::settings(lumen_steam_mode)
        }
    }
    if { $v ne "flow" } { set v "time" }
    return $v
}

# Same for HOT WATER: "temp" or "vol".
proc ::lumen::water_mode {} {
    set v "temp"
    catch {
        if { [info exists ::settings(lumen_water_mode)] } {
            set v $::settings(lumen_water_mode)
        }
    }
    if { $v ne "vol" } { set v "temp" }
    return $v
}

proc ::lumen::bag_count {} {
    set v 5
    catch {
        if { [info exists ::settings(lumen_bag_count)] \
          && $::settings(lumen_bag_count) ne "" } {
            set v $::settings(lumen_bag_count)
        }
    }
    if { ![string is integer -strict $v] } { set v 5 }
    if { $v < 3 }  { set v 3 }
    if { $v > 10 } { set v 10 }
    return $v
}

# Loads the most recent saved shot into the live chart vectors, once, at
# startup. Without this the home chart is blank every time you open the app
# until you pull a shot -- the vectors are created empty at launch and only
# filled as a shot runs; nothing in the app restores them.
#
# READ ONLY. It opens one history file and writes nothing. In particular it
# does NOT copy the shot's `settings` block: the stock preview_history does
# `array set ::settings $props(settings)`, which would replace your entire
# current configuration -- grinder, dose, profile -- with whatever was saved
# in that old shot. Only the curve vectors are taken.
# With `path` set (0.30.0), that exact file is loaded instead of the newest
# in history/ -- the bag cycler uses this so the chart and LAST SHOT card
# describe the last shot OF THE BAG being cycled to, matching what the
# grind tile has done since 0.22.0.
proc ::lumen::load_last_shot_curves { {force 0} {path ""} } {
    if { !$force } {
        # Startup path, unchanged: never clobber a shot in progress. This
        # guard also makes the plain call a no-op forever after -- once a
        # shot is loaded the vectors always hold samples -- which is fine at
        # startup and exactly why the reload path below cannot use it.
        if { ![catch { set n [espresso_elapsed length] }] && $n > 1 } { return }
    } else {
        # Reload path (0.28.0): the vectors legitimately hold the previous
        # shot, so length proves nothing. The real "shot in progress" signal
        # is history_saved: reset_gui_starting_espresso zeroes it when a shot
        # STARTS (machine.tcl:846) and the core's save sets it back to 1 --
        # and our own startup load sets it to 1 for exactly the same reason
        # (see the CRITICAL block below). So 0 here means live unsaved
        # samples, and reloading would clobber a shot mid-pull or arm the
        # 0.27.1 overwrite; refuse loudly rather than silently.
        if { ![catch { set hs $::settings(history_saved) }] && !$hs } {
            msg -INFO "Lumen: history reload skipped, a shot is in progress"
            return
        }
    }

    if { $path ne "" } {
        if { ![file isfile $path] } {
            msg -NOTICE "Lumen: requested shot file [file tail $path] does not exist"
            return
        }
        set newest $path
    } else {
    set dir "[homedir]/history"
    if { ![file isdirectory $dir] } { return }

    # "Newest" means the most recent SHOT, which is not the most recently
    # modified FILE (0.26.1).
    #
    # The app names every shot file YYYYMMDDTHHMMSS.shot, so sorting the names
    # is sorting by shot time. Sorting by mtime is sorting by "when did
    # anything last touch this file", and editing a shot's metadata in the
    # Shot History Editor touches it: a July shot corrected today would become
    # the file the home page describes, curves and all, until the next shot
    # was pulled. Seen on the tablet on 2026-08-19 -- the log said "loaded
    # last shot curves from 20260715T170133.shot" after that file was
    # restamped, and the LAST SHOT card duly described a shot from a month
    # earlier.
    #
    # mtime remains the fallback for any file whose name is not a timestamp,
    # and is used only when NO file has a parseable one.
    set named {} ; set others {}
    foreach f [glob -nocomplain -directory $dir *.shot] {
        if { [regexp {^[0-9]{8}T[0-9]{6}$} [file rootname [file tail $f]]] } {
            lappend named $f
        } else {
            lappend others $f
        }
    }
    set newest ""
    if { [llength $named] > 0 } {
        # Every path shares the same directory prefix, so sorting the paths
        # sorts the names.
        set newest [lindex [lsort $named] end]
    } else {
        set newest_t 0
        foreach f $others {
            if { [catch { set t [file mtime $f] }] } { continue }
            if { $t > $newest_t } { set newest_t $t ; set newest $f }
        }
    }
    if { $newest eq "" } { return }
    }

    if { [catch {
        array set props [encoding convertfrom utf-8 [read_binary_file $newest]]
    } err] } {
        msg -ERROR "Lumen: could not read $newest: $err"
        return
    }
    # Seed the last shot's profile from the file's own settings block. This
    # reads into a LOCAL array on purpose -- the stock preview_history does
    # `array set ::settings $props(settings)`, which would replace the entire
    # live configuration with a stale one (see the warning above).
    if { [info exists props(settings)] } {
        if { ![catch { array set _shot_settings $props(settings) }] } {
            if { [info exists _shot_settings(profile_title)] } {
                variable last_shot_profile
                set last_shot_profile [string trim $_shot_settings(profile_title)]
            }
            # ... and what the shot was pulled with (0.24.1 yield, 0.25.0
            # grind and dose). These are what the LAST SHOT card reports:
            # they carry Shot History Editor corrections, which never reach
            # the live ::settings, and the yield does not survive a restart
            # there at all. See the last_shot_rec comment at the top.
            variable last_shot_rec
            # 0.28.0: this array must describe THIS file only. It used to be
            # add-only, which was invisible at startup (the array is empty)
            # but wrong on reload: delete the newest shot and the previous
            # shot becomes newest -- if ITS file lacks a value the deleted
            # shot's number would linger on the card.
            array unset last_shot_rec
            array set last_shot_rec {}
            foreach {key field} {grind grinder_setting \
                                 dose  grinder_dose_weight \
                                 yield drink_weight} {
                if { ![info exists _shot_settings($field)] } { continue }
                set v [string trim $_shot_settings($field)]
                if { $v eq "" } { continue }
                # Grind is free text (clicks, letters, half-steps); the two
                # weights must be real positive numbers or they are noise.
                if { $key ne "grind" && ![::lumen::data::_is_pos $v] } { continue }
                set last_shot_rec($key) $v
            }
        }
        array unset _shot_settings
    }

    if { ![info exists props(espresso_elapsed)] } { return }

    # A saved shot's first samples often repeat elapsed = 0.0 while the
    # y-values already move (captured before the shot timer starts). Plotted,
    # that is a vertical line at x=0 ending in a stray point. Slice every
    # series from the first strictly positive elapsed value; all series are
    # appended per-sample by the app, so one index aligns them all.
    set skip 0
    foreach t $props(espresso_elapsed) {
        if { ![string is double -strict $t] || $t > 0.0 } { break }
        incr skip
    }
    if { $skip > 0 } {
        foreach v {espresso_elapsed espresso_pressure espresso_flow
                   espresso_flow_weight espresso_state_change
                   espresso_weight espresso_temperature_basket} {
            if { [info exists props($v)] } {
                set props($v) [lrange $props($v) $skip end]
            }
        }
    }

    # Vectors stored verbatim in the file.
    foreach v {espresso_elapsed espresso_pressure espresso_flow
               espresso_flow_weight espresso_state_change} {
        if { [info exists props($v)] } {
            catch { $v length 0 ; $v append $props($v) }
        }
    }

    # Two vectors the chart needs are DERIVED, not stored: the app scales
    # them at capture time so everything shares one 0..10 axis.
    if { [info exists props(espresso_weight)] } {
        catch {
            espresso_weight_chartable length 0
            foreach w $props(espresso_weight) {
                espresso_weight_chartable append [expr {0.10 * $w}]
            }
        }
    }
    if { [info exists props(espresso_temperature_basket)] } {
        catch {
            espresso_temperature_basket10th length 0
            foreach t $props(espresso_temperature_basket) {
                espresso_temperature_basket10th append [expr {$t / 10.0}]
            }
        }
    }

    # CRITICAL (0.27.1). Tell the app these samples are already in history.
    #
    # Without this line, loading a past shot into the live vectors ARMS THE
    # APP TO OVERWRITE THAT SHOT'S FILE. Measured on the tablet 2026-08-19,
    # from the log:
    #
    #   01:39:30  Lumen: loaded last shot curves from 20260818T164430.shot
    #   11:42:28  DE1 major state change: Idle => HotWaterRinse, pouring
    #   11:42:38  Saved this espresso to history      <-- the flush did this
    #
    # The 18 Aug shot file was rewritten by a FLUSH the next morning. Its
    # grinder_setting went from the corrected 8 back to the live 7.5, its
    # drink_weight from 37.8 to 0, and the file shrank from 29,948 bytes to
    # 21,506 -- the flush's own data, under the espresso's filename.
    #
    # The core's save is registered on after_flow_complete, which fires after
    # ANY flow, flush and steam included (vars.tcl:3440). Its only guard is
    #
    #     !$::settings(history_saved) && [espresso_elapsed length] > 5
    #                                 && [espresso_pressure length] > 5
    #
    # and the filename comes from ::settings(espresso_clock) -- still pointing
    # at the PREVIOUS shot (vars.tcl:3452-3457). It never checks that the flow
    # that just finished was an espresso, nor that the samples belong to this
    # session. Filling those vectors for the home chart is what makes that
    # guard pass, so the exposure is ours to close even though the write is
    # the core's.
    #
    # history_saved says "the samples currently in the vectors have been
    # written to history". Having just read them OUT of history, that is
    # exactly true. reset_gui_starting_espresso sets it back to 0 when a real
    # shot starts (machine.tcl:846), so a genuine shot still saves normally.
    if { [catch { set ::settings(history_saved) 1 } err] } {
        msg -ERROR "Lumen: could not mark the loaded shot as already saved: $err"
    }

    msg -INFO "Lumen: loaded last shot curves from [file tail $newest] (history_saved marked)"
}

# Public entry point for plugins that change what history/ holds (0.28.0).
#
# ShotHistoryEditor calls this after an edit, a delete or a restore, the same
# way it already tells Grind Advisor -- so the home page follows a correction
# without the user pulling a shot first. Everything downstream of the reload
# is already live: the chart's elements are bound to the BLT vectors, so
# refilling them redraws the graph, and the LAST SHOT card reads
# last_shot_rec through polled `var` bindings.
#
# The bag list is refreshed too: it is built from SDB, which the caller
# (ShotHistoryEditor via Grind Advisor's refresh_from_history) has just
# resynced -- deleting a bag's only shot removes that bag from the cycler.
#
# Callers guard on [info procs ::lumen::refresh_after_history_change], so a
# different skin simply skips this. Safe to call at any time: the loader's
# reload guard refuses while a shot is in progress.
proc ::lumen::refresh_after_history_change {} {
    if { [catch { load_last_shot_curves 1 } err] } {
        msg -ERROR "Lumen: history reload failed: $err"
    }
    if { [catch { refresh_bag_list } err] } {
        msg -ERROR "Lumen: bag list refresh failed: $err"
    }
    return ""
}

# Recolours a CORE dui dialog that the skin cannot reach through theming.
#
# Pages like dui_item_selector -- the one behind "Select the beans batch" --
# are added by dui itself with `-theme default` hardcoded (dui.tcl:405), and
# their background is painted into a canvas item at `dui page add` time,
# before any skin code runs. Setting the aspect afterwards updates the
# lookup table but never repaints an existing item, which is why doing that
# had no effect at all (tried in 0.13.2, reverted).
#
# So reconfigure the item directly. dui tags page items with the PAGE NAME
# (`-tags [list $page pages]`), and that includes the text -- so filter by
# canvas item TYPE. Polygons are the rounded background; text is relabelled
# to a lighter ink, which is safe because it is scoped to this one page
# rather than the app-wide dtext aspect.
# Records the profile a shot is about to run with.
#
# Hooked to the espresso page's `show`, which is the moment a shot starts, so
# the value captured is the profile that shot actually uses. Doing this on
# flow COMPLETE would be wrong in a subtle way: after_flow_complete fires for
# steam, hot water and flush too, and any of those could land after you have
# already switched profiles for the next coffee.
proc ::lumen::latch_shot_profile { args } {
    variable last_shot_profile
    variable last_shot_rec
    catch {
        set p [string trim [::lumen::data::_s ::settings(profile_title)]]
        if { $p ne "" } { set last_shot_profile $p }
    }
    # A shot is starting, so the file those values came from is no longer the
    # last shot. Drop them (0.24.1 yield, 0.25.0 grind and dose): the live
    # settings are precisely what this shot is about to record, and quoting
    # the previous shot's numbers as this one's would be worse than either
    # showing the live values or, for a yield that never arrives, "--".
    array unset last_shot_rec
    array set last_shot_rec {}
}

# Stamps when a flow page was last shown. See ::lumen::data::_flow_secs: the
# core's timers keep describing the previous flow until the new one reaches
# its "during" phase, and this is how the accessor tells the two apart.
#
# `args` because dui hands a show action the page names it is switching
# between.
proc ::lumen::latch_flow_open { page args } {
    variable flow_opened
    set flow_opened($page) [clock milliseconds]
}

proc ::lumen::restyle_core_dialog { page } {
    variable C
    if { [catch { set can [dui canvas] } ] } { return }
    if { [catch { set ids [$can find withtag $page] } ] } { return }
    if { [llength $ids] == 0 } { return }

    set shapes 0 ; set texts 0
    foreach id $ids {
        if { [catch { set type [$can type $id] }] } { continue }
        switch -exact -- $type {
            polygon {
                catch { $can itemconfigure $id -fill $C(glass) -outline $C(glass_brd) }
                incr shapes
            }
            rectangle {
                catch { $can itemconfigure $id -fill $C(glass) -outline $C(glass_brd) }
                incr shapes
            }
            text {
                catch { $can itemconfigure $id -fill $C(ink_2) }
                incr texts
            }
        }
    }
    msg -INFO "Lumen: restyled core dialog $page ($shapes shapes, $texts texts)"
}

proc ::lumen::chart_setup { widget } {
    variable C
    variable L
    variable chart_widgets
    if { [lsearch -exact $chart_widgets $widget] < 0 } {
        lappend chart_widgets $widget
    }

    set sm [chart_smoothing]
    # Line widths are physical pixels here: the graph is a Tk widget, not a
    # canvas item, so it never goes through the coordinate rescale.
    set lw  [expr {int(max(1, round(3 * $L(font_scale))))}]
    set lw2 [expr {int(max(1, round(2 * $L(font_scale))))}]

    foreach {name vector colour width} [list \
        l_pressure espresso_pressure                  $C(c_press)  $lw \
        l_flow     espresso_flow                      $C(c_flow)   $lw \
        l_weight   espresso_weight_chartable          $C(c_weight) $lw2 \
        l_temp     espresso_temperature_basket10th    $C(c_temp)   $lw2 ] {
        if { [catch {
            $widget element create $name -xdata espresso_elapsed -ydata $vector \
                -smooth $sm -symbol none -label "" -linewidth $width \
                -color $colour -pixels 0
        } err] } {
            msg -ERROR "Lumen: could not create chart element $name: $err"
        }
    }

    # Stage separators: espresso_state_change is 0 except at frame changes,
    # where the app appends 10000000 (gui.tcl:3487) -- clipped to the 0..10
    # axis that plots as a dashed vertical line at each transition
    # (preinfusion -> extraction -> decline...). Mechanism from Streamline
    # skin.tcl:3915; toggled via -hide, the mechanism Insight uses for its
    # optional chart lines. NOT smoothed -- a spline would bend the spikes.
    set dash [expr {int(max(2, round(8 * $L(font_scale))))}]
    if { [catch {
        $widget element create l_stages -xdata espresso_elapsed \
            -ydata espresso_state_change -symbol none -label "" \
            -linewidth $lw2 -color $C(ink_3) -pixels 0 \
            -dashes [list $dash $dash] \
            -hide [expr {[stages_shown] ? "no" : "yes"}]
    } err] } {
        msg -ERROR "Lumen: could not create the stage separators: $err"
    }

    catch { gridconfigure $widget }
    catch {
        $widget axis configure x -color $C(ink_3) -tickfont $L(font_caption) \
            -linewidth 1 -subdivisions 5 -min 0
        $widget axis configure y -color $C(ink_3) -tickfont $L(font_caption) \
            -min 0 -max 10 -subdivisions 5 -majorticks {2 4 6 8 10}
    }
}

# Re-configures the live elements rather than rebuilding the widget.
proc ::lumen::chart_apply_smoothing {} {
    variable chart_widgets
    set sm [chart_smoothing]
    foreach widget $chart_widgets {
        foreach name {l_pressure l_flow l_weight l_temp} {
            if { [catch { $widget element configure $name -smooth $sm } err] } {
                msg -ERROR "Lumen: could not set smoothing on $name: $err"
            }
        }
    }
}

proc ::lumen::chart_apply_stages {} {
    variable chart_widgets
    set hide [expr {[stages_shown] ? "no" : "yes"}]
    foreach widget $chart_widgets {
        if { [catch { $widget element configure l_stages -hide $hide } err] } {
            msg -ERROR "Lumen: could not toggle the stage separators: $err"
        }
    }
}

#############################################################################
#  Actions
#
#  Each one targets a plugin that may not be installed. Failures are logged
#  to the app log, never swallowed -- a dead button that says nothing is far
#  worse to diagnose than one that leaves a line in the log.
#############################################################################

namespace eval ::lumen::act {
    # Per-stepper tap-rate state: key -> {last_ms streak dir}.
    variable accel
    array set accel {}
}

# Tap-rate acceleration for the grind / dose / yield steppers (owner
# request): a slow tap moves 0.1; taps in RAPID succession escalate to 0.5
# after three and 1.0 after six, so a big adjustment does not take forty
# taps. A pause or a direction change drops straight back to 0.1. The app's
# legacy buttons fire once per press (there is no hold event), so holding
# registers as its taps do.
#
# The window is 350ms (0.28.1). It shipped at 700ms, and the owner's
# careful step-step-step pace -- roughly 500-700ms per tap -- landed
# inside it, so deliberate 0.1 nudges escalated to 0.5 mid-adjustment.
# Escalation is meant for drumming on the button (3+ taps a second, i.e.
# under ~350ms apart); a measured pace must stay at 0.1 no matter how many
# taps it runs to.
proc ::lumen::act::_accel_step { key dir } {
    variable accel
    set now [clock milliseconds]
    set last 0 ; set streak 0 ; set lastdir 0
    catch { lassign $accel($key) last streak lastdir }
    if { $dir == $lastdir && ($now - $last) < 350 } {
        incr streak
    } else {
        set streak 0
    }
    set accel($key) [list $now $streak $dir]
    if { $streak >= 6 } { return 1.0 }
    if { $streak >= 3 } { return 0.5 }
    return 0.1
}

proc ::lumen::act::grind_popup {} {
    if { [catch { ::plugins::GrindAdvisor::show_last_recommendation } err] } {
        msg -ERROR "Lumen: could not open the Grind Advisor result: $err"
    }
}

# GrindAdvisor >= 3.3.0 exposes show_calibration_curve for exactly this: it
# opens the Calibration Curve straight from a skin tile, without the after-shot
# popup having to be on screen first. Its Back button lands on the normal
# popup. On an older GrindAdvisor the proc is absent, so fall back to the
# result popup rather than leaving a dead button.
proc ::lumen::act::grind_curve {} {
    if { [info procs ::plugins::GrindAdvisor::show_calibration_curve] eq "" } {
        msg -NOTICE "Lumen: GrindAdvisor has no calibration curve, opening the result popup instead"
        grind_popup
        return
    }
    if { [catch { ::plugins::GrindAdvisor::show_calibration_curve } err] } {
        msg -ERROR "Lumen: could not open the calibration curve: $err"
    }
}

proc ::lumen::act::dye_next {} {
    if { [catch { ::plugins::DYE::open -which_shot next } err] } {
        msg -ERROR "Lumen: could not open DYE next shot: $err"
    }
}

# Straight to the camera, one tap.
#
# BeanScanner records its return page only in BeanScanner_settings::show, and
# ::plugins::BeanScanner::_settings_return_page is never initialised at
# namespace level. Jumping directly to a sub-page therefore left that
# variable unset, and _exit_settings reads it WITHOUT a catch:
#
#     proc _exit_settings {} {
#         variable _settings_return_page
#         _navigate_done $_settings_return_page
#     }
#
# so Done threw "no such variable" and silently did nothing -- the dead end.
#
# Seeding the variable with the page we came from is exactly what entering
# through the settings page would have done, so the plugin's own navigation
# then works unmodified. Guarded and logged: if BeanScanner ever renames it,
# this must fail loudly rather than trap the user again.
# The one place this skin writes a setting. live_graph_smoothing_technique is
# a stock DE1app preference (default "linear"); "catrom" is the Catmull-Rom
# spline the chart widget already understands. Same data, rounded corners.
# Second chart preference, alongside smoothing: show/hide the stage
# separator lines. lumen_chart_stages is a Lumen setting (like lumen_theme).
proc ::lumen::act::toggle_stages {} {
    set new [expr {[::lumen::stages_shown] ? 0 : 1}]
    if { [catch {
        set ::settings(lumen_chart_stages) $new
        save_settings
    } err] } {
        msg -ERROR "Lumen: could not save the stages preference: $err"
    }
    ::lumen::chart_apply_stages
}

proc ::lumen::act::toggle_smoothing {} {
    set new "catrom"
    if { [::lumen::chart_smoothing] ne "linear" } { set new "linear" }
    if { [catch {
        set ::settings(live_graph_smoothing_technique) $new
        save_settings
    } err] } {
        msg -ERROR "Lumen: could not save smoothing preference: $err"
    }
    ::lumen::chart_apply_smoothing
}

# Theme is read once at load and every page is built from it, so switching
# needs the app restarted. The tap only records the choice; Done performs the
# restart (::lumen::act::restart_for_theme).
proc ::lumen::act::toggle_theme {} {
    # Toggle from the PENDING value once one exists. Basing this on
    # theme_mode alone was a bug: that is fixed at load, so every tap
    # produced the same result and you could never switch back.
    set cur $::lumen::theme_mode
    if { $::lumen::pending_theme ne "" } { set cur $::lumen::pending_theme }
    set new [expr {$cur eq "dark" ? "light" : "dark"}]
    if { [catch {
        set ::settings(lumen_theme) $new
        save_settings
    } err] } {
        msg -ERROR "Lumen: could not save the theme preference: $err"
        return
    }
    set ::lumen::pending_theme $new
}

proc ::lumen::act::open_settings {} {
    if { [catch { dui page load lumen_settings } err] } {
        msg -ERROR "Lumen: could not open Lumen settings: $err"
    }
}

proc ::lumen::act::close_settings {} {
    if { $::lumen::pending_theme ne "" \
      && $::lumen::pending_theme ne $::lumen::theme_mode } {
        ::lumen::act::restart_for_theme
        return
    }
    if { [catch { dui page load off } err] } {
        msg -ERROR "Lumen: could not return to the home page: $err"
    }
}

# The palette is read once at load and every canvas item is created from it,
# so a theme change only lands when the skin is sourced again. Apply it the
# same way the app applies a skin change on leaving its own settings section
# (skins/default/de1_skin_settings.tcl:65-71): show the stock message page,
# then app_exit.
#
# The app does NOT come back by itself, and cannot: measured on Android 16
# (SDK 36), `exec am start` from the app's own uid dies with
# "package=com.android.shell does not belong to uid=..." before Android's
# background-activity-start rules even apply, and `borg activity` would start
# the activity in the process that is about to exit. A relaunch needs
# something outside the app. Changing skin in the stock settings behaves the
# same way, for the same reason.
proc ::lumen::act::restart_for_theme {} {
    msg -NOTICE "Lumen: theme set to $::lumen::pending_theme, restarting the app to apply it"
    if { [catch {
        save_settings
        .can itemconfigure $::message_label \
            -text [translate "Please quit and restart this app to apply your changes."]
        .can itemconfigure $::message_button_label -text [translate "Wait"]
        set_next_page off message
        page_show message
    } err] } {
        # Never swallow this: if the message page failed we still exit below,
        # and the log is the only place that would say why the screen looked
        # wrong on the way out.
        msg -ERROR "Lumen: could not show the restart message page: $err"
    }
    after 200 app_exit
}

proc ::lumen::act::open_app_settings {} {
    if { [catch { show_settings } err] } {
        msg -ERROR "Lumen: could not open the app settings: $err"
    }
}

# Profile chooser, straight from the home page (0.24.0, owner request).
#
# settings_1 is the stock profile page -- the profiles listbox, the explanation
# chart and the brew-temperature control (skins/default/de1_skin_settings.tcl:
# 192, 934, 1026). show_settings takes the tab to open as its first argument
# and does the rest itself, including sizing the profile scrollbar on idle
# (gui.tcl:1403-1425). This is Streamline's own home-page shortcut
# (Streamline/skin.tcl:607) minus its zoomed-page bookkeeping: no custom
# navigation of our own, so Done comes back the same way it does from the
# DECENT APP button, which is tablet-proven.
proc ::lumen::act::open_profiles {} {
    if { [catch { show_settings settings_1 } err] } {
        msg -ERROR "Lumen: could not open the profile list: $err"
    }
}


# Writes ::settings(grinder_dose_weight) -- the same field shot.tcl records
# as the shot's dose. Refuses to store a zero or negative reading, so a
# mis-tap with nothing on the scale cannot wipe your dose.
proc ::lumen::act::set_dose_from_scale {} {
    set w ""
    catch { set w $::de1(scale_weight) }
    if { ![::lumen::data::_is_pos $w] } {
        msg -NOTICE "Lumen: no positive scale weight, dose left unchanged"
        return
    }
    if { [catch {
        set ::settings(grinder_dose_weight) [format %.1f $w]
        save_settings
    } err] } {
        msg -ERROR "Lumen: could not set the dose from the scale: $err"
    }
}

# ---- next-shot steppers ---------------------------------------------------
#
# Mechanisms copied from the proven implementations, not invented here:
#   grind  -- DYE's own setup_DSx2.tcl change_grinder_setting: stage the
#             value in DYE's next_grinder_setting AND mirror it into
#             ::settings(grinder_setting), saving both.
#   yield  -- DSx2 procs_vars.tcl "saw" stepper: settings_2c profiles keep
#             their target in final_desired_shot_weight_advanced, everything
#             else in final_desired_shot_weight.
#   ratio  -- DSx2 procs_vars.tcl "er" stepper: a ratio change is just a
#             yield write of dose * new_ratio.
# Every path clamps, so holding the button cannot write junk.

proc ::lumen::act::adjust_grind { delta } {
    # Read the same source the strip displays (DYE's staged value first).
    set cur [::lumen::data::_field grinder_setting]
    if { ![string is double -strict $cur] } { set cur 0 }
    set dir [expr {$delta >= 0 ? 1 : -1}]
    set new [expr {double($cur) + $dir * [_accel_step grind $dir]}]
    if { $new < 0 } { set new 0 } elseif { $new > 100 } { set new 100 }
    set new [format %.1f $new]
    if { [catch {
        if { [info exists ::plugins::DYE::settings(next_grinder_setting)] } {
            set ::plugins::DYE::settings(next_grinder_setting) $new
            plugins save_settings DYE
        }
        set ::settings(grinder_setting) $new
        save_settings
    } err] } {
        msg -ERROR "Lumen: could not change the grind setting: $err"
        return
    }
    # DYE keeps a human-readable summary of the next shot; refresh it the way
    # its own stepper does. Absent or old DYE: nothing to refresh.
    catch { ::plugins::DYE::shots::define_next_desc }
}

# ---- machine steppers (Lumen settings page) -------------------------------
#
# Mechanism from Streamline's settings column: mutate the setting, then
# persist AND send to the machine, debounced by 1s so a run of taps lands
# as one save + one BLE update (save_profile_and_update_de1_soon's pattern).
# save_settings_to_de1 re-sends the shot frames plus the steam / hot-water /
# flush settings (de1_comms.tcl:1539), so it covers all four rows.

proc ::lumen::act::_apply_machine_settings {} {
    catch { after cancel $::lumen::machine_apply_id }
    set ::lumen::machine_apply_id [after 1000 {
        if { [catch {
            save_settings
            save_settings_to_de1
        } err] } {
            msg -ERROR "Lumen: could not send the machine settings: $err"
        }
    }]
}

# Brew temperature must go through the core's change_espresso_temperature:
# it applies the RELATIVE change to every frame of step-temperature and
# advanced profiles, not just the headline number (vars.tcl:4213).
proc ::lumen::act::adjust_brew_temp { delta } {
    set cur [::lumen::data::_s ::settings(espresso_temperature)]
    if { ![string is double -strict $cur] } { return }
    set new [expr {double($cur) + $delta}]
    # Streamline's guard rails: never below 1 or above 110.
    if { $new < 70.0 || $new > 110.0 } { return }
    if { [catch { change_espresso_temperature $delta } err] } {
        msg -ERROR "Lumen: could not change the brew temperature: $err"
        return
    }
    _apply_machine_settings
}

proc ::lumen::act::adjust_steam_time { delta } {
    set cur [::lumen::data::_s ::settings(steam_timeout)]
    if { ![string is double -strict $cur] } { set cur 0 }
    set new [expr {round(double($cur) + $delta)}]
    if { $new < 0 } { set new 0 } elseif { $new > 255 } { set new 255 }
    if { [catch {
        set ::settings(steam_timeout) $new
        # Timeout 0 means steam off; keep the flag in step the way
        # Streamline's save path does.
        set ::settings(steam_disabled) [expr {$new == 0 ? 1 : 0}]
    } err] } {
        msg -ERROR "Lumen: could not change the steam time: $err"
        return
    }
    _apply_machine_settings
}

proc ::lumen::act::adjust_flush_time { delta } {
    set cur [::lumen::data::_s ::settings(flush_seconds)]
    if { ![string is double -strict $cur] } { set cur 5 }
    set new [expr {round(double($cur) + $delta)}]
    # Streamline's bounds: 3..254.
    if { $new < 3 } { set new 3 } elseif { $new > 254 } { set new 254 }
    if { [catch { set ::settings(flush_seconds) $new } err] } {
        msg -ERROR "Lumen: could not change the flush time: $err"
        return
    }
    _apply_machine_settings
}

# steam_flow is ml/s x 100. Step and bounds copied from Streamline's own
# steam stepper (skin.tcl:2707-2716): 10 per tap, and it refuses to go past
# 250. The floor is 40 rather than Streamline's 0, because 0.4 mL/s is the
# minimum its own data-entry dialog for this field declares (skin.tcl:1913)
# and a tenth of a mL/s is not a steam setting anyone wants to reach by
# holding a button.
proc ::lumen::act::adjust_steam_flow { delta } {
    set cur [::lumen::data::_s ::settings(steam_flow)]
    if { ![string is double -strict $cur] } { set cur 0 }
    set new [expr {round(double($cur) + $delta)}]
    if { $new < 40 } { set new 40 } elseif { $new > 250 } { set new 250 }
    if { [catch { set ::settings(steam_flow) $new } err] } {
        msg -ERROR "Lumen: could not change the steam flow: $err"
        return
    }
    _apply_machine_settings
}

# Hot water temperature, in degrees C. Streamline steps this by 1 and holds it
# between 1 and 100 (skin.tcl:2657-2668); the floor here is 20, for the same
# reason as the steam floor -- nothing below it is a hot water setting, and a
# runaway tap should stop somewhere sensible.
proc ::lumen::act::adjust_water_temp { delta } {
    set cur [::lumen::data::_s ::settings(water_temperature)]
    if { ![string is double -strict $cur] } { set cur 0 }
    set new [expr {round(double($cur) + $delta)}]
    if { $new < 20 } { set new 20 } elseif { $new > 100 } { set new 100 }
    if { [catch { set ::settings(water_temperature) $new } err] } {
        msg -ERROR "Lumen: could not change the hot water temperature: $err"
        return
    }
    _apply_machine_settings
}

# The STEAM and HOT WATER pills drive whichever half of their row is selected,
# so the buttons are wired to a direction (-1 / +1) and the step belongs to
# the setting, not to the button (0.26.0).
proc ::lumen::act::adjust_steam { dir } {
    if { [::lumen::steam_mode] eq "flow" } {
        adjust_steam_flow [expr {$dir * 10}]
    } else {
        adjust_steam_time [expr {$dir * 5}]
    }
}

proc ::lumen::act::adjust_water { dir } {
    if { [::lumen::water_mode] eq "vol" } {
        adjust_water_volume [expr {$dir * 10}]
    } else {
        adjust_water_temp $dir
    }
}

proc ::lumen::act::toggle_steam_mode {} {
    set new [expr {[::lumen::steam_mode] eq "flow" ? "time" : "flow"}]
    if { [catch {
        set ::settings(lumen_steam_mode) $new
        save_settings
    } err] } {
        msg -ERROR "Lumen: could not save the steam row mode: $err"
    }
}

proc ::lumen::act::toggle_water_mode {} {
    set new [expr {[::lumen::water_mode] eq "vol" ? "temp" : "vol"}]
    if { [catch {
        set ::settings(lumen_water_mode) $new
        save_settings
    } err] } {
        msg -ERROR "Lumen: could not save the hot water row mode: $err"
    }
}

proc ::lumen::act::adjust_water_volume { delta } {
    set cur [::lumen::data::_s ::settings(water_volume)]
    if { ![string is double -strict $cur] } { set cur 0 }
    set new [expr {round(double($cur) + $delta)}]
    if { $new < 10 } { set new 10 } elseif { $new > 250 } { set new 250 }
    if { [catch { set ::settings(water_volume) $new } err] } {
        msg -ERROR "Lumen: could not change the hot water volume: $err"
        return
    }
    _apply_machine_settings
}

# Bag cycler depth. A Lumen preference, NOT a machine setting, so it saves
# with plain save_settings and never goes near save_settings_to_de1 -- the
# machine has no idea what a bean bag is.
proc ::lumen::act::adjust_bag_count { delta } {
    set new [expr {[::lumen::bag_count] + $delta}]
    if { $new < 3 }  { set new 3 } elseif { $new > 10 } { set new 10 }
    if { [catch {
        set ::settings(lumen_bag_count) $new
        save_settings
    } err] } {
        msg -ERROR "Lumen: could not save the bag count preference: $err"
    }
}

proc ::lumen::act::adjust_dose { delta } {
    set cur [::lumen::data::_s ::settings(grinder_dose_weight)]
    if { ![string is double -strict $cur] } { set cur 0 }
    set dir [expr {$delta >= 0 ? 1 : -1}]
    set new [expr {double($cur) + $dir * [_accel_step dose $dir]}]
    # DSx2's dose stepper clamps 2..40; a dose outside that is a mis-tap.
    if { $new < 2 } { set new 2 } elseif { $new > 40 } { set new 40 }
    set new [format %.1f $new]
    if { [catch {
        if { [info exists ::plugins::DYE::settings(next_grinder_dose_weight)] } {
            set ::plugins::DYE::settings(next_grinder_dose_weight) $new
            plugins save_settings DYE
        }
        set ::settings(grinder_dose_weight) $new
        save_settings
    } err] } {
        msg -ERROR "Lumen: could not change the dose: $err"
        return
    }
    catch { ::plugins::DYE::shots::define_next_desc }
}

proc ::lumen::act::_write_yield { new } {
    if { ![string is double -strict $new] } { return }
    if { $new < 0 } { set new 0 } elseif { $new > 200 } { set new 200 }
    set new [format %.1f $new]
    if { [catch {
        if { [string trim [::lumen::data::_s ::settings(settings_profile_type)]] eq "settings_2c" } {
            set ::settings(final_desired_shot_weight_advanced) $new
        } else {
            set ::settings(final_desired_shot_weight) $new
        }
        save_settings
    } err] } {
        msg -ERROR "Lumen: could not change the target yield: $err"
    }
}

proc ::lumen::act::adjust_yield { delta } {
    set cur [::lumen::data::_target_raw]
    if { ![string is double -strict $cur] } { set cur 0 }
    set dir [expr {$delta >= 0 ? 1 : -1}]
    _write_yield [expr {double($cur) + $dir * [_accel_step yield $dir]}]
}

# 0.21.0 removed ::lumen::act::adjust_ratio. The RATIO stepper gave up its
# slot to the PROFILE tile, and ratio is now shown as a derived caption under
# the YIELD value. It was never an independent quantity -- it only ever wrote
# final_desired_shot_weight, exactly like the yield stepper does -- so nothing
# is lost: stepping yield moves the ratio and vice versa.

# Kick a scale reconnect by hand.
#
# The core gives up permanently once its automatic retries are spent: on each
# disconnect scale_disconnect_handler (de1app-core/de1_comms.tcl:587) calls
# ble_connect_to_scale up to scale_max_connection_retry_attempts (20) times,
# ~10s apart. After the 20th it only schedules
#   after 300000 "set ::de1(bluetooth_scale_connection_attempts_tried) 0"
# -- it resets the counter and never retries. So a scale switched on more than
# ~3.5 minutes after it went away is never reconnected on its own. Every other
# skin covers this with a tap target (Insight skin.tcl:904, DSx2, DSx,
# Streamline skin.tcl:696, SWDark4); Lumen had none, which is why the readout
# looked random. Copied verbatim from Insight -- the counter must be cleared
# first, or the 20 already-spent attempts stay spent.
proc ::lumen::act::reconnect_scale {} {
    if { [::lumen::data::_s ::settings(scale_bluetooth_address)] eq "" } {
        msg -NOTICE "Lumen: no scale paired, nothing to reconnect"
        return
    }
    if { [catch {
        set ::de1(bluetooth_scale_connection_attempts_tried) 0
        ble_connect_to_scale
    } err] } {
        msg -ERROR "Lumen: could not reconnect the scale: $err"
    }
}

# Opens the Shot History Editor's card list -- the shortcut for editing and
# soft-deleting past shots. open_page is the plugin's public entry, and its
# settings page captures the page it was opened from by itself, so Done
# returns straight back here with no bookkeeping on our side.
proc ::lumen::act::shot_history {} {
    if { [catch {
        if { [info procs ::plugins::ShotHistoryEditor::open_page] eq "" } {
            error "the Shot History Editor plugin is not loaded"
        }
        ::plugins::ShotHistoryEditor::open_page ShotHistoryEditor_settings
    } err] } {
        msg -ERROR "Lumen: could not open the Shot History Editor: $err"
    }
}

# Opens Grind Advisor's settings. open_settings_dialog is its public entry
# (it tries open_dialog, then load, then show, and logs if all three fail),
# and its page's show{} captures the page it was opened from as its own return
# target (GrindAdvisor v1.8.8), so Done comes straight back here. Same
# contract as the Shot History shortcut above -- no bookkeeping on our side.
proc ::lumen::act::open_grind_advisor {} {
    if { [catch {
        if { [info procs ::plugins::GrindAdvisor::open_settings_dialog] eq "" } {
            error "the Grind Advisor plugin is not loaded"
        }
        ::plugins::GrindAdvisor::open_settings_dialog GrindAdvisor_settings
    } err] } {
        msg -ERROR "Lumen: could not open Grind Advisor: $err"
    }
}

# Cycles the next shot's bean bag through the most recent bags.
#
# Read and write both go through OTHER PLUGINS' public APIs. Lumen opens no
# database and writes no SQL -- that is a standing property of this skin and
# this feature does not change it:
#
#   list   ::plugins::SDB::available_categories bean_desc 1 {} 0
#          The trailing 0 is use_lookup_table and it matters three times over:
#          it selects the branch that orders by MAX(shot.clock) DESC (most
#          recently used bag first, which is the whole point), it is the only
#          branch that applies the removed=0 filter, and it avoids the
#          lookup-table branch, which reads an undefined `lookup_order_by`
#          (SDB.tcl:2723 -- its assignment is commented out at 2657).
#   clock  ::plugins::SDB::shots_using_category bean_desc <value> clock
#          Newest first, so [lindex ... 0] is that bag's most recent shot.
#   apply  ::plugins::DYE::shots::source_next_from <clock> {} beans
#          "beans" is resolved by DYE through
#          `metadata fields -domain shot -section beans`, so it copies the
#          whole bean section (brand, type, roast date, level, notes) and
#          persists it into the next shot the same way Bean Scanner does.
#
# Every call is guarded: with SDB or DYE missing this logs and does nothing
# rather than throwing inside a button handler.
# The shot clocks for one bag, newest first.
#
# WORKAROUND for a real defect in SDB, hit on the tablet in 0.21.0: for
# bean_desc the data dictionary gives db_table = V_shot rather than "shot", so
# shots_using_category takes its aliased branch and builds
#
#   SELECT DISTINCT clock FROM V_shot t INNER JOIN V_shot s ON t.clock=s.clock
#
# where the bare `clock` is ambiguous across both aliases. SQLite rejects it
# with "ambiguous column name: clock" and the cycler could never resolve a
# clock. Qualifying it as t.clock through the documented `return_what`
# parameter produces valid SQL and the ordering SDB already intends
# (ORDER BY t.clock DESC).
#
# Both spellings are tried, qualified first: t.clock is correct for the
# aliased branch that bean_desc actually takes, and the bare form is the right
# one if a future SDB maps bean_desc onto the plain `shot` table, where there
# is no `t` to qualify. Neither is assumed to work.
proc ::lumen::act::_bag_clocks { bag } {
    foreach form {t.clock clock} {
        if { ![catch {
            set c [::plugins::SDB::shots_using_category bean_desc $bag $form]
        } err] } {
            if { [llength $c] > 0 } { return $c }
        } else {
            msg -DEBUG "Lumen: bag clock lookup via '$form' failed: $err"
        }
    }
    return {}
}

# The newest shot FILE for a list of shot clocks (newest first), or "".
#
# No SDB query: the app names every shot file from its clock
# (%Y%m%dT%H%M%S), which is the same filename-matching rule SDB itself
# uses. A clock whose file is gone (soft-deleted in ShotHistoryEditor) is
# skipped, so a bag whose latest shot sits in the trash falls back to its
# next-newest -- the same tolerance the workspace rules require of SDB
# consumers.
proc ::lumen::act::_bag_last_shot_file { clocks } {
    foreach c $clocks {
        if { [catch {
            set f "[homedir]/history/[clock format $c -format %Y%m%dT%H%M%S].shot"
        }] } { continue }
        if { [file isfile $f] } { return $f }
    }
    return ""
}

proc ::lumen::act::cycle_bag { dir } {
    if { [catch {
        if { [info procs ::plugins::SDB::available_categories] eq "" } {
            error "the SDB plugin is not loaded"
        }
        if { [info procs ::plugins::DYE::shots::source_next_from] eq "" } {
            error "the DYE plugin is not loaded"
        }

        # Rebuild the window first: a shot pulled since the last refresh may
        # have added a bag, and this is a tap, so it can afford the query.
        # The page indicator reads the same cached list.
        ::lumen::refresh_bag_list
        set bags $::lumen::bag_list
        if { [llength $bags] == 0 } {
            msg -NOTICE "Lumen: no bean bags in the shot database yet"
            return
        }

        set cur [::lumen::current_bag]
        set idx [lsearch -exact $bags $cur]

        # Not in the list (a hand-typed bag, or one older than the window):
        # step onto the most recent bag rather than doing nothing.
        if { $idx < 0 } {
            set target 0
        } else {
            # 0.27.0: the ends are ENDS. Wrapping made every bag look alike --
            # you could not tell the newest from the oldest, which is exactly
            # what the owner wanted the indicator to show. Running off either
            # end now does nothing, and the dots say why.
            set target [expr {$idx + $dir}]
            if { $target < 0 || $target >= [llength $bags] } {
                msg -INFO "Lumen: already at the [expr {$dir < 0 ? {newest} : {oldest}}] bag"
                return
            }
        }
        set want [lindex $bags $target]
        if { $want eq $cur } { return }

        set clocks [_bag_clocks $want]
        if { [llength $clocks] == 0 } {
            error "no shots found for bag '$want'"
        }
        ::plugins::DYE::shots::source_next_from [lindex $clocks 0] {} beans
        msg -INFO "Lumen: next shot bag set to '$want'"

        # 0.30.0 (owner request): the chart and LAST SHOT card follow the
        # bag, like the grind tile has since 0.22.0. Load the cycled bag's
        # newest shot file; failure here must not undo the cycle itself,
        # which has already succeeded.
        set f [_bag_last_shot_file $clocks]
        if { $f ne "" } {
            if { [catch { ::lumen::load_last_shot_curves 1 $f } lerr] } {
                msg -ERROR "Lumen: could not load '$want' last shot: $lerr"
            }
        } else {
            msg -NOTICE "Lumen: no shot file on disk for bag '$want' (all in trash?); chart left as-is"
        }
    } err] } {
        msg -ERROR "Lumen: could not cycle the bean bag: $err"
    }
}

proc ::lumen::act::scan_bag {} {
    if { [catch {
        # BeanScanner >= 0.3.0 exposes set_return_page for exactly this: it
        # records where we came from AND marks that we entered at a sub-page,
        # so Cancel comes straight back here instead of via its settings
        # page. Falls back to seeding the variable directly on older builds.
        if { [info procs ::plugins::BeanScanner::set_return_page] ne "" } {
            ::plugins::BeanScanner::set_return_page "off"
        } else {
            set ::plugins::BeanScanner::_settings_return_page "off"
        }
        ::plugins::BeanScanner::open_page BeanScanner_capture
    } err] } {
        msg -ERROR "Lumen: could not open Bean Scanner camera: $err"
    }
}

proc ::lumen::txt { page x y text args } {
    variable C
    variable L
    array set o [list -font $L(font_body) -fill $C(ink) -anchor nw -justify left -width 0]
    array set o $args

    set extra {}
    if { $o(-width) > 0 } { lappend extra -width [X $o(-width)] }

    uplevel #0 [list dui add dtext $page [X $x] [Y $y] -text $text \
        -font $o(-font) -fill $o(-fill) -anchor $o(-anchor) \
        -justify $o(-justify) {*}$extra]
}

# Like txt, but the text is a Tcl snippet re-evaluated on the app's update
# tick. Goes through `dui add variable` rather than the legacy
# add_de1_variable, whose argument order depends on -textvariable being the
# very last option.
proc ::lumen::var { page x y code args } {
    variable C
    variable L
    array set o [list -font $L(font_body) -fill $C(ink) -anchor nw -justify left -width 0]
    array set o $args

    set extra {}
    if { $o(-width) > 0 } { lappend extra -width [X $o(-width)] }

    uplevel #0 [list dui add variable $page [X $x] [Y $y] -textvariable $code \
        -font $o(-font) -fill $o(-fill) -anchor $o(-anchor) \
        -justify $o(-justify) {*}$extra]
}

# Invisible tap target. Coordinates in DESIGN px.
# Visual press feedback (0.29.0, owner request: buttons felt "flat and
# dead"). The controls are pixels baked into the background image with an
# invisible zone on top, so nothing reacts natively; this draws a brief
# crema glow in the zone's own rounded shape the moment it is tapped.
#
# Mechanics, and why each choice:
#  * Drawn straight on .can, NOT through dui add canvas_item -- a press
#    flash is transient, not page state; dui would keep it in the page's
#    item list forever.
#  * Coordinates arrive VIRTUAL (2560x1600, what add_de1_button was given)
#    and are mapped to screen pixels with the core's rescale_x/y_skin --
#    the same transform the button zone itself went through, so the glow
#    lands exactly on the control.
#  * Tk canvas has no alpha, and faking it was a mistake: 0.29.0 shipped
#    -stipple gray25, a raw 4x4 checkerboard that the owner read as "a
#    graphics bug" -- on a high-DPI panel a pixel mesh over the button
#    looks like corruption, not translucency. 0.29.1 draws a hollow accent
#    RING instead: a crisp crema outline in the control's rounded shape,
#    slightly inset, like a focus ring. No fill means the button's own
#    label stays fully visible under the flash.
#  * `update idletasks` before returning, or the command that follows
#    (which may open a page or query a plugin) would run to completion
#    before the canvas ever painted the flash -- feedback after the fact
#    is no feedback.
#  * One shared tag: a new press deletes the previous glow first, so
#    drumming on a stepper reads as one live glow, not a stack of stale
#    ones. The 150ms timer clears it by item id; a flash that outlives an
#    instant page switch dies on the same timer.
proc ::lumen::press_flash { x1 y1 x2 y2 } {
    variable C
    if { [catch {
        .can delete lumen_tapflash
        set px1 [rescale_x_skin $x1] ; set py1 [rescale_y_skin $y1]
        set px2 [rescale_x_skin $x2] ; set py2 [rescale_y_skin $y2]
        # 0.30.0 (owner feedback on 0.29.1): the ring matches the CONTROL.
        # Inset is 1px -- just enough that the stroke is not clipped at the
        # zone boundary -- because the stepper pills' tap zones ARE their
        # drawn bounds, and a 5px-inset ring floated visibly inside them.
        # The radius is the baked pills' own corner radius (RADIUS_S = 16
        # design px in make_backgrounds.py, doubled to virtual, then
        # rescaled), so on a pill the ring's corners follow the pill's
        # corners exactly; the half-size clamp below keeps it sane on
        # thinner zones.
        set inset [expr {int(max(1, [rescale_y_skin 2]))}]
        set px1 [expr {$px1 + $inset}] ; set py1 [expr {$py1 + $inset}]
        set px2 [expr {$px2 - $inset}] ; set py2 [expr {$py2 - $inset}]
        set r [rescale_y_skin 32]
        if { $r * 2 > ($px2 - $px1) } { set r [expr {($px2 - $px1) / 2}] }
        if { $r * 2 > ($py2 - $py1) } { set r [expr {($py2 - $py1) / 2}] }
        set pts [list \
            [expr {$px1 + $r}] $py1 \
            [expr {$px2 - $r}] $py1 \
            $px2 $py1 \
            $px2 [expr {$py1 + $r}] \
            $px2 [expr {$py2 - $r}] \
            $px2 $py2 \
            [expr {$px2 - $r}] $py2 \
            [expr {$px1 + $r}] $py2 \
            $px1 $py2 \
            $px1 [expr {$py2 - $r}] \
            $px1 [expr {$py1 + $r}] \
            $px1 $py1]
        set lw [expr {int(max(3, [rescale_y_skin 6]))}]
        set id [.can create polygon {*}$pts -smooth 1 \
            -fill "" -outline $C(crema) -width $lw \
            -tags lumen_tapflash]
        after 150 [list catch [list .can delete $id]]
        update idletasks
    } err] } {
        msg -DEBUG "Lumen: press flash failed: $err"
    }
}

proc ::lumen::tap { page x y w h command label } {
    set x1 [X $x] ; set y1 [Y $y]
    set x2 [X [expr {$x + $w}]] ; set y2 [Y [expr {$y + $h}]]
    add_de1_button $page \
        "::lumen::press_flash $x1 $y1 $x2 $y2; say \[translate {$label}\] \$::settings(sound_button_in); $command" \
        $x1 $y1 $x2 $y2
}

#############################################################################
#  Boot
#############################################################################

# Use the stock utility pages (settings, firmware, descale, profile editors)
# rather than reimplementing them. This is the same approach DSx2 takes.
source "[homedir]/skins/default/standard_includes.tcl"

set ::lumen::theme_mode "dark"
catch {
    if { [info exists ::settings(lumen_theme)] && $::settings(lumen_theme) ne "" } {
        set ::lumen::theme_mode $::settings(lumen_theme)
    }
}
::lumen::set_palette $::lumen::theme_mode
::lumen::_init_layout

# Every page uses a pre-rendered background. Tk canvas has no alpha and no
# blur, so the frosted panels, their blurred backdrops, the soft shadows and
# the crema bloom are composited offline by tools/make_backgrounds.py and
# loaded here as images. dui resolves each file from the resolution folder
# that matches the screen (1340x800 / 2560x1600).
#
# We deliberately do not source skins/default/standard_stop_buttons.tcl: it
# would re-declare the flow pages with the default skin's background JPGs and
# paint over ours. Its stop-button bindings are reproduced verbatim further
# down.
#
# The four flow pages are NOT one dui page add call any more: espresso uses
# the compact layout (its live chart needs the middle of the screen) while
# steam, water and hotwaterrinse keep the roomier one, so they take different
# images. The three roomy ones still share a single file -- build_flow_page
# draws identical panels for all three and only the label text differs.
#
# 0.20.0: before this, everything except home was -bg_color plus vector
# glass, which is why the settings and flow pages looked a generation behind.
set ::lumen::pages [list espresso steam water hotwaterrinse]

set ::lumen::_bg_suffix [expr {$::lumen::theme_mode eq "dark" ? "" : "_light"}]

dui page add off           -bg_img "lumen_home$::lumen::_bg_suffix.png"
dui page add lumen_settings -bg_img "lumen_settings$::lumen::_bg_suffix.png"
dui page add espresso      -bg_img "lumen_flow_chart$::lumen::_bg_suffix.png"
dui page add [list steam water hotwaterrinse] \
                           -bg_img "lumen_flow$::lumen::_bg_suffix.png"

.can configure -bg $::lumen::C(bg)

#############################################################################
#  Home page ("off")
#############################################################################

proc ::lumen::build_home {} {
    variable C
    variable L
    set p "off"

    # The 0.17 action rail (Espresso/Steam/Water/Flush buttons) is gone:
    # those duplicated the machine's own GHC controls and the width was
    # needed for the next-shot steppers. Settings and Sleep -- which must
    # stay reachable or the skin is a dead end -- moved into the 2x2 action
    # grid in the next-shot strip.

    ####################################################################
    #  Grind recommendation tile  ->  GrindAdvisor result popup
    ####################################################################
    glass $p $L(grind_x) $L(grind_y) $L(grind_w) $L(grind_h) \
        -fill $C(glass) -outline $C(crema_brd)

    set gx [expr {$L(grind_x) + $L(pad_x)}]
    set gy [expr {$L(grind_y) + $L(pad_y)}]

    txt $p $gx $gy [translate "RECOMMENDED GRIND"] \
        -font $L(font_label) -fill $C(ink_3)

    # Vertical budget inside the 190-tall tile (0.23.0; content 36..192):
    #   label 36..51   hero 56..140   note 142..161   row 176..192
    # 14 clear to the tile edge at 206.
    # Hero and note are CENTRED on the tile (owner request); the delta sits
    # to the right of the widest hero the grind range allows ("50.0" is
    # ~101px half-width at the 84px mono size, so +120 clears it).
    set gmid [expr {$L(grind_x) + $L(grind_w) / 2.0}]
    var $p $gmid [expr {$gy + 20}] {[::lumen::data::grind_next]} \
        -font $L(font_hero) -fill $C(crema) -anchor n -justify center
    var $p [expr {$gmid + 120}] [expr {$gy + 60}] {[::lumen::data::grind_delta]} \
        -font $L(font_primary) -fill $C(good)

    var $p $gmid [expr {$gy + 106}] {[::lumen::data::grind_note]} \
        -font $L(font_body) -fill $C(ink_2) -width 560 \
        -anchor n -justify center

    # Method chip, top right. Blank until there is a recommendation.
    set mchip_x [expr {$L(grind_x) + $L(grind_w) - $L(pad_x) - 150}]
    glass $p $mchip_x $gy 150 26 -radius 13 \
        -fill $C(crema_lo) -outline $C(crema_brd) -spec 0
    var $p [expr {$mchip_x + 75}] [expr {$gy + 13}] {[::lumen::data::grind_method]} \
        -font $L(font_label) -fill $C(crema) -anchor center -justify center

    var $p $gx [expr {$gy + 140}] {[::lumen::data::grind_band]} \
        -font $L(font_caption) -fill $C(good)

    txt $p [expr {$L(grind_x) + $L(grind_w) - $L(pad_x)}] \
        [expr {$gy + 140}] \
        [translate "Shot analysis"] -font $L(font_caption) -fill $C(crema) \
        -anchor ne -justify right

    # "Curve" sits on the same baseline as "Shot analysis", one lg gap to its
    # left, and opens GrindAdvisor's calibration plot directly.
    set gcv_r [expr {$L(grind_x) + $L(grind_w) - $L(pad_x) - 130}]
    txt $p $gcv_r [expr {$gy + 140}] \
        [translate "Curve"] -font $L(font_caption) -fill $C(crema) \
        -anchor ne -justify right

    # The tile tap is carved into three rectangles around the Curve target, so
    # no two tap targets overlap (design-system rule) and every part of the
    # tile that used to open the popup still does.
    #   A: everything above the bottom row
    #   B: bottom row, left of Curve      C: bottom row, right of Curve
    set gcv_x [expr {$gcv_r - 84}]                  ;# Curve tap left edge
    set gcv_y [expr {$L(grind_y) + $L(grind_h) - 62}]
    set gcv_w 90
    set gcv_h 62

    tap $p $L(grind_x) $L(grind_y) $L(grind_w) \
        [expr {$gcv_y - $L(grind_y) - $L(xs)}] \
        {::lumen::act::grind_popup} "Shot analysis"
    tap $p $L(grind_x) $gcv_y [expr {$gcv_x - $L(grind_x)}] $gcv_h \
        {::lumen::act::grind_popup} "Shot analysis"
    tap $p [expr {$gcv_x + $gcv_w}] $gcv_y \
        [expr {$L(grind_x) + $L(grind_w) - $gcv_x - $gcv_w}] $gcv_h \
        {::lumen::act::grind_popup} "Shot analysis"

    tap $p $gcv_x $gcv_y $gcv_w $gcv_h {::lumen::act::grind_curve} "Curve"

    ####################################################################
    #  Last shot tile
    ####################################################################
    glass $p $L(last_x) $L(last_y) $L(last_w) $L(last_h)

    # 0.23.0: identity on the left, metrics on the right, in the SAME row
    # order as the next-shot card -- LABEL, PROFILE, roaster, bean type --
    # so the two cards read as a pair.
    set lx $L(last_id_x)

    txt $p $lx $L(last_label_y) [translate "LAST SHOT"] \
        -font $L(font_label) -fill $C(ink_3)

    # The profile that shot ran on. Directly under the card label, matching
    # the next-shot card, so the two profiles can be read against each other:
    # when they differ, Grind Advisor has started a fresh calibration.
    txt $p $lx $L(last_prof_y) [translate "PROFILE"] \
        -font $L(font_label) -fill $C(ink_3)
    var $p $L(last_val_x) $L(last_prof_y) {[::lumen::data::last_profile]} \
        -font $L(font_caption) -fill $C(ink_2) -width 190

    var $p $lx $L(last_roast_y) {[::lumen::data::last_roaster_line]} \
        -font $L(font_caption) -fill $C(ink_3) -width $L(last_id_w)
    var $p $lx $L(last_name_y) {[::lumen::data::last_name_line]} \
        -font $L(font_primary) -fill $C(ink) -width $L(last_id_w)

    # --- Water in the tank (0.24.0), above the metrics in the card's
    # top-right corner. Blue, not the ink scale: it is machine status, and at
    # this size in ink it would read as a fifth shot metric.
    var $p $L(last_met_x) $L(water_label_y) {[::lumen::data::water_label]} \
        -font $L(font_label) -fill $C(ink_3)
    var $p [expr {$L(last_x) + $L(last_w) - $L(pad_x)}] $L(water_val_y) \
        {[::lumen::data::water_ml]} \
        -font $L(font_data) -fill $C(c_flow) -anchor ne -justify right

    # Metrics: GRIND joins dose/yield/time (0.23.0), with the derived ratio
    # tucked under YIELD exactly as the next-shot card does it.
    set i 0
    foreach {k code} [list \
        [translate "GRIND"] {[::lumen::data::last_grind]} \
        [translate "DOSE"]  {[::lumen::data::last_dose]} \
        [translate "YIELD"] {[::lumen::data::last_yield]} \
        [translate "TIME"]  {[::lumen::data::last_time]} ] {
        set cx [expr {$L(last_met_x) + $i * $L(last_met_pitch)}]
        txt $p $cx $L(last_met_label_y) $k -font $L(font_label) -fill $C(ink_3)
        var $p $cx $L(last_met_val_y) $code -font $L(font_section) -fill $C(ink)
        if { $k eq [translate "YIELD"] } {
            var $p $cx $L(last_met_sub_y) {[::lumen::data::last_ratio_note]} \
                -font $L(font_caption) -fill $C(ink_3)
        }
        incr i
    }

    # --- Shot history: a text link on the tile's bottom row, matching Curve
    # and Shot analysis on the grind tile. It was the only button on this
    # card, which gave it more weight than a history shortcut deserves.
    set lh_r [expr {$L(last_x) + $L(last_w) - $L(pad_x)}]
    txt $p $lh_r $L(hist_y) [translate "Shot history"] \
        -font $L(font_caption) -fill $C(crema) -anchor ne -justify right
    tap $p [expr {$lh_r - 150}] [expr {$L(hist_y) - 8}] 150 40 \
        {::lumen::act::shot_history} "Shot history"

    ####################################################################
    #  Shot chart   (real graph widget added in Pass 3)
    ####################################################################
    glass $p $L(chart_x) $L(chart_y) $L(chart_w) $L(chart_h)

    set cx [expr {$L(chart_x) + $L(pad_x)}]
    set cy [expr {$L(chart_y) + $L(md)}]

    set i 0
    foreach {nm col} [list \
        [translate "Pressure"] $C(c_press) \
        [translate "Flow"]     $C(c_flow) \
        [translate "Weight"]   $C(c_weight) \
        [translate "Temp"]     $C(c_temp) ] {
        txt $p [expr {$cx + $i * 110}] $cy $nm \
            -font $L(font_caption) -fill $col
        incr i
    }

    # Raw / Smooth toggle top right of the chart panel, with the stage
    # separators toggle beside it -- same pill, same behaviour.
    set tw 140
    set tx [expr {$L(chart_x) + $L(chart_w) - $L(pad_x) - $tw}]
    set ty [expr {$L(chart_y) + 12}]
    glass $p $tx $ty $tw 34 -radius 17 \
        -fill $C(crema_lo) -outline $C(crema_brd) -spec 0
    var $p [expr {$tx + $tw / 2.0}] [expr {$ty + 17}] \
        {[::lumen::data::smoothing_label]} \
        -font $L(font_label) -fill $C(crema) -anchor center -justify center
    tap $p $tx $ty $tw 34 {::lumen::act::toggle_smoothing} "Smoothing"

    set tx2 [expr {$tx - $tw - 12}]
    glass $p $tx2 $ty $tw 34 -radius 17 \
        -fill $C(crema_lo) -outline $C(crema_brd) -spec 0
    var $p [expr {$tx2 + $tw / 2.0}] [expr {$ty + 17}] \
        {[::lumen::data::stages_label]} \
        -font $L(font_label) -fill $C(crema) -anchor center -justify center
    tap $p $tx2 $ty $tw 34 {::lumen::act::toggle_stages} "Stages"

    # The graph widget itself, below the legend row.
    set cgx [expr {$L(chart_x) + $L(pad_x)}]
    set cgy [expr {$L(chart_y) + 52}]
    set cgw [expr {$L(chart_w) - 2 * $L(pad_x)}]
    set cgh [expr {$L(chart_h) - 52 - $L(md)}]

    if { [catch {
        dui add graph $p [X $cgx] [Y $cgy] \
            -width [X $cgw] -height [Y $cgh] \
            -background $C(chart_bg) -plotbackground $C(chart_bg) \
            -borderwidth 0 -plotrelief flat -relief flat \
            -plotpadx 18 -plotpady 8 \
            -tclcode {::lumen::chart_setup %W}
    } err] } {
        msg -ERROR "Lumen: could not create the shot chart: $err"
    }

    # Sits over the plot area and blanks itself as soon as there is data.
    var $p [expr {$L(chart_x) + $L(chart_w) / 2.0}] \
        [expr {$L(chart_y) + $L(chart_h) / 2.0}] \
        {[::lumen::data::chart_empty_note]} \
        -font $L(font_body) -fill $C(ink_3) -anchor center -justify center

    ####################################################################
    #  Next shot / bean strip   (data wired in Pass 2)
    ####################################################################
    glass $p $L(bean_x) $L(bean_y) $L(bean_w) $L(bean_h)

    set bx2 [expr {$L(bean_x) + $L(pad_x)}]
    set by2 [expr {$L(bean_y) + $L(pad_y)}]

    set bx2 $L(bean_id_x)
    set by2 [expr {$L(bean_y) + $L(pad_y)}]

    # 0.27.0 identity block. NEXT SHOT and PROFILE share the top row -- the
    # label only ever used the left third of it -- and the 24px that frees
    # goes into even 11px gaps around the hero name, which was wedged between
    # two lines 4px away.
    txt $p $bx2 $L(id_label_y) [translate "NEXT SHOT"] \
        -font $L(font_label) -fill $C(ink_3)
    txt $p $L(id_prof_x) $L(id_label_y) [translate "PROFILE"] \
        -font $L(font_label) -fill $C(ink_3)
    var $p $L(id_val_x) $L(id_label_y) {[::lumen::data::next_profile]} \
        -font $L(font_caption) -fill $C(ink_2) -width $L(id_val_w)

    var $p $bx2 $L(id_roast_y) {[::lumen::data::bean_roaster_line]} \
        -font $L(font_caption) -fill $C(ink_3) -width $L(bean_id_w)

    # --- the bag name, on a row of its own with the block's full width.
    var $p $L(id_name_x) $L(id_name_y) {[::lumen::data::bean_name_line]} \
        -font $L(font_title) -fill $C(ink) -width $L(id_name_w)

    # Tasting notes. Blank when the field is unset, so the row costs nothing
    # on a bag that has none.
    var $p $bx2 $L(id_notes_y) {[::lumen::data::bean_notes_line]} \
        -font $L(font_caption) -fill $C(ink_2) -width $L(bean_id_w)

    # --- action row: [<] [Edit] [>], then the cycler's page indicator. The
    # arrows shrank to a stepper pill's size (owner request); the 150px that
    # frees is what the indicator sits in.
    foreach ax [list $L(cyc_prev_x) $L(cyc_next_x)] \
            glyph [list [format %c 0x25C0] [format %c 0x25B6]] \
            dir {-1 1} \
            lbl {"Previous bag" "Next bag"} {
        glass $p $ax $L(cyc_y) $L(cyc_w) $L(cyc_h) \
            -radius $L(radius_sm) -spec 0
        # Arrow glyphs via [format %c ...] -- the proven pattern; a literal
        # UTF-8 arrow in the source got mangled once already (Grind Advisor
        # v2.0.2 lesson) and there is no ASCII arrow that reads as one.
        txt $p [expr {$ax + $L(cyc_w) / 2.0}] \
            [expr {$L(cyc_y) + $L(cyc_h) / 2.0}] $glyph \
            -font $L(font_caption) -fill $C(crema) \
            -anchor center -justify center
        tap $p $ax $L(cyc_y) $L(cyc_w) $L(cyc_h) \
            "::lumen::act::cycle_bag $dir" $lbl
    }

    glass $p $L(id_edit_x) $L(id_act_y) $L(id_edit_w) $L(id_edit_h) \
        -radius $L(radius_sm) -spec 0
    txt $p [expr {$L(id_edit_x) + $L(id_edit_w) / 2.0}] \
        [expr {$L(id_act_y) + $L(id_edit_h) / 2.0}] \
        [translate "Edit"] -font $L(font_button) -fill $C(ink_2) \
        -anchor center -justify center
    tap $p $L(id_edit_x) $L(id_act_y) $L(id_edit_w) $L(id_edit_h) \
        {::lumen::act::dye_next} "Edit"

    # One dot per reachable bag, filled for the loaded one, leftmost being
    # the most recent -- which is the direction the left arrow moves in. The
    # cycler does not wrap any more, so the dots also say when you have run
    # out of bags in one direction (owner request).
    var $p $L(bag_dots_x) $L(bag_dots_y) {[::lumen::data::bag_dots]} \
        -font $L(font_caption) -fill $C(crema) -anchor center -justify center

    # --- three Streamline-style stepper groups: label above, then
    # [-]  value  [+] with the live value BETWEEN the pills. ASCII glyphs
    # only (design rule); the mono face renders them cleanly.
    #
    # 0.21.0: RATIO lost its stepper. Nothing is actually lost -- ratio is
    # fully DERIVED from dose and yield, so it is a caption under the YIELD
    # value instead of a control of its own. It sits INSIDE the pill band,
    # not under it: the strip's bottom row leaves no room between them.
    #
    # 0.23.0: PROFILE left this row for the identity block, so three columns
    # now span 520..1116 on a 210 pitch instead of four on a 206 pitch.
    set i 0
    foreach {k code minus_code plus_code what} [list \
        [translate "GRIND"]  {[::lumen::data::next_grind]} \
            {::lumen::act::adjust_grind -0.1} {::lumen::act::adjust_grind 0.1} "Grind" \
        [translate "DOSE"]   {[::lumen::data::next_dose]} \
            {::lumen::act::adjust_dose -0.1}  {::lumen::act::adjust_dose 0.1}  "Dose" \
        [translate "YIELD"]  {[::lumen::data::next_yield]} \
            {::lumen::act::adjust_yield -0.1} {::lumen::act::adjust_yield 0.1} "Yield" ] {
        set kx [expr {$L(bean_fact_x) + $i * $L(bean_fact_w)}]
        txt $p $kx $by2 $k -font $L(font_label) -fill $C(ink_3)

        set mx $kx
        set px2 [expr {$kx + $L(step_w) + $L(step_gap) + $L(step_val_w) + $L(step_gap)}]
        set mid_y [expr {$L(step_y) + $L(step_h) / 2.0}]

        foreach sx [list $mx $px2] glyph [list "-" "+"] \
                scode [list $minus_code $plus_code] \
                lbl [list "$what down" "$what up"] {
            glass $p $sx $L(step_y) $L(step_w) $L(step_h) \
                -radius $L(radius_sm) -spec 0
            txt $p [expr {$sx + $L(step_w) / 2.0}] \
                [expr {$mid_y + ($glyph eq "-" ? $L(step_minus_dy) : 0)}] $glyph \
                -font $L(font_section) -fill $C(crema) \
                -anchor center -justify center
            tap $p $sx $L(step_y) $L(step_w) $L(step_h) $scode $lbl
        }

        # The value, centred between the pills. YIELD carries the derived
        # ratio beneath it, so its value shifts up to make room and the two
        # lines share the pill band (the reference the owner supplied:
        # "36g" with "(1:2.4)" tucked under it).
        set vx [expr {$kx + $L(step_w) + $L(step_gap) + $L(step_val_w) / 2.0}]
        if { $what eq "Yield" } {
            var $p $vx [expr {$L(step_y) + 16}] $code \
                -font $L(font_data) -fill $C(ink) \
                -anchor center -justify center
            var $p $vx [expr {$L(step_y) + 38}] \
                {[::lumen::data::next_ratio_note]} \
                -font $L(font_caption) -fill $C(ink_3) \
                -anchor center -justify center
        } else {
            var $p $vx $mid_y $code -font $L(font_data) -fill $C(ink) \
                -anchor center -justify center
        }

        incr i
    }

    # --- scale row, under the stepper groups: live readout, then Set dose
    # aligned under the DOSE group (these belong with the NEXT shot).
    set mid [expr {$L(scale_y) + $L(scale_h) / 2.0}]
    glass $p $L(scale_read_x) $L(scale_y) $L(scale_read_w) $L(scale_h) \
        -radius $L(radius_sm) -spec 0
    var $p [expr {$L(scale_read_x) + 22}] $mid {[::lumen::data::scale_bt]} \
        -font $L(font_bt) -fill $C(c_flow) -anchor center -justify center
    # Centred on the box, not nudged clear of the icon: the icon is only
    # there when a scale is connected, so the nudge threw "no scale" off
    # centre exactly when it was the only thing showing.
    var $p [expr {$L(scale_read_x) + $L(scale_read_w) / 2.0}] $mid \
        {[::lumen::data::scale_weight_line]} \
        -font $L(font_data) -fill $C(ink_2) -anchor center -justify center
    # The readout was a dead zone. Tapping it forces a scale reconnect --
    # the affordance every other skin puts on its weight display, and the
    # only way back once the core has spent its automatic retries.
    tap $p $L(scale_read_x) $L(scale_y) $L(scale_read_w) $L(scale_h) \
        {::lumen::act::reconnect_scale} "Scale"

    glass $p $L(scale_set_x) $L(scale_y) $L(scale_set_w) $L(scale_h) \
        -radius $L(radius_sm) -fill $C(crema_lo) -outline $C(crema_brd)
    txt $p [expr {$L(scale_set_x) + $L(scale_set_w) / 2.0}] $mid \
        [translate "Set dose"] \
        -font $L(font_button) -fill $C(crema) -anchor center -justify center
    tap $p $L(scale_set_x) $L(scale_y) $L(scale_set_w) $L(scale_h) \
        {::lumen::act::set_dose_from_scale} "Set dose"

    # --- Scan bag completes the bottom row, under the YIELD group.
    #
    # 0.23.0: Edit left this row for the identity block, where it sits with
    # the bag it edits. The identity block no longer carries a full-height
    # DYE tap either -- with the cycler arrows and Edit both on its action
    # row, a block-wide tap would have overlapped them, and a tap target may
    # never overlap another (design-system rule). Edit is the one way in,
    # which is clearer than a large invisible region that did the same thing.
    glass $p $L(act_scan_x) $L(scale_y) $L(act_w) $L(act_h) \
        -radius $L(radius_sm) -fill $C(crema_lo) -outline $C(crema_brd)
    txt $p [expr {$L(act_scan_x) + $L(act_w) / 2.0}] \
        [expr {$L(scale_y) + $L(act_h) / 2.0}] \
        [translate "Scan bag"] -font $L(font_button) -fill $C(crema) \
        -anchor center -justify center
    tap $p $L(act_scan_x) $L(scale_y) $L(act_w) $L(act_h) \
        {::lumen::act::scan_bag} "Scan bag"

    ####################################################################
    #  Side panel: Profile, Settings and Sleep, in their own panel right of
    #  the strip. Settings and Sleep moved here from the removed rail;
    #  without them the skin is a dead end with no way back to the skin
    #  picker. Profile joined them in 0.24.0 -- it is the one thing you
    #  change between shots that the strip could not reach at all.
    #
    #  Profile is on top because it is the one you tap during a session;
    #  Sleep stays at the bottom, furthest from a stray thumb.
    ####################################################################
    glass $p $L(side_x) $L(bean_y) $L(side_w) $L(bean_h)

    foreach {gy label action} [list \
        $L(side_y1) "Profile"  {::lumen::act::open_profiles} \
        $L(side_y2) "Settings" {::lumen::act::open_settings} \
        $L(side_y3) "Sleep"    {start_sleep} ] {
        glass $p $L(side_btn_x) $gy $L(side_btn_w) $L(side_btn_h) \
            -radius $L(radius_sm) -spec 0
        txt $p [expr {$L(side_btn_x) + $L(side_btn_w) / 2.0}] \
            [expr {$gy + $L(side_btn_h) / 2.0}] \
            [translate $label] -font $L(font_button) -fill $C(ink_2) \
            -anchor center -justify center
        tap $p $L(side_btn_x) $gy $L(side_btn_w) $L(side_btn_h) \
            $action $label
    }
}

#############################################################################
#  Flow pages: espresso, steam, water, flush
#
#  These pages exist because the machine switches to them on its own during a
#  shot. The stock skin puts all of their content INSIDE its background JPGs
#  (espresso_on.png and friends); since Lumen declares its pages with a
#  background colour instead, that content has to be drawn here. Without it
#  the tablet shows a blank screen for the whole shot.
#############################################################################

proc ::lumen::build_flow_page { page timer_code temp_code {with_chart 0} {temp_label "TEMP"} {temp_note_code ""} } {
    variable C
    variable L

    # The espresso page uses a compact layout so a live chart fits above the
    # metrics; steam, water and flush keep the roomier one.
    if { $with_chart } {
        set state_y $L(fc_state_y) ; set timer_y $L(fc_timer_y)
        set panel_x $L(fc_panel_x) ; set panel_y $L(fc_panel_y)
        set panel_w $L(fc_panel_w) ; set panel_h $L(fc_panel_h)
        set hint_y  $L(fc_hint_y)
    } else {
        set state_y $L(flow_state_y) ; set timer_y $L(flow_timer_y)
        set panel_x $L(flow_panel_x) ; set panel_y $L(flow_panel_y)
        set panel_w $L(flow_panel_w) ; set panel_h $L(flow_panel_h)
        set hint_y  $L(flow_hint_y)
    }

    # What the machine is doing right now.
    var $page $L(center_x) $state_y {[translate [de1_substate_text]]} \
        -font $L(font_title) -fill $C(ink) -anchor n -justify center \
        -width $panel_w

    # Elapsed time, the thing you actually watch.
    var $page $L(center_x) $timer_y $timer_code \
        -font $L(font_hero) -fill $C(crema) -anchor n -justify center

    # Live curves, drawn as the shot runs. Same vectors and the same
    # smoothing setting as the home chart; the toggle drives both.
    if { $with_chart } {
        glass $page $L(fc_chart_x) $L(fc_chart_y) $L(fc_chart_w) $L(fc_chart_h)
        set gx [expr {$L(fc_chart_x) + $L(pad_x)}]
        set gy [expr {$L(fc_chart_y) + $L(md)}]
        set gw [expr {$L(fc_chart_w) - 2 * $L(pad_x)}]
        set gh [expr {$L(fc_chart_h) - 2 * $L(md)}]
        if { [catch {
            dui add graph $page [X $gx] [Y $gy] \
                -width [X $gw] -height [Y $gh] \
                -background $C(chart_bg_flow) -plotbackground $C(chart_bg_flow) \
                -borderwidth 0 -plotrelief flat -relief flat \
                -plotpadx 18 -plotpady 8 \
                -tclcode {::lumen::chart_setup %W}
        } err] } {
            msg -ERROR "Lumen: could not create the live chart on $page: $err"
        }
    }

    glass $page $panel_x $panel_y $panel_w $panel_h

    set px [expr {$panel_x + $L(pad_x)}]
    set cw [expr {($panel_w - 2 * $L(pad_x)) / 4.0}]

    set i 0
    foreach {label code colour} [list \
        [translate "PRESSURE"]   {[pressure_text]}              $C(c_press) \
        [translate "FLOW"]       {[waterflow_text]}             $C(c_flow) \
        [translate "WEIGHT"]     {[::lumen::data::live_weight]} $C(c_weight) \
        [translate $temp_label]  $temp_code                     $C(c_temp) ] {
        set cx [expr {$px + $i * $cw}]
        txt $page $cx [expr {$panel_y + 30}] $label \
            -font $L(font_label) -fill $C(ink_3)
        var $page $cx [expr {$panel_y + 66}] $code \
            -font $L(font_metric) -fill $colour
        incr i
    }

    # Optional caption under the temperature value (the steam page states
    # its set point there, so the heater reading reads as intentional).
    if { $temp_note_code ne "" } {
        var $page [expr {$px + 3 * $cw}] [expr {$panel_y + 112}] \
            $temp_note_code -font $L(font_caption) -fill $C(ink_3)
    }

    txt $page $L(center_x) $hint_y \
        [translate "Tap anywhere to stop"] \
        -font $L(font_body) -fill $C(ink_3) -anchor n -justify center
}

#############################################################################
#  Lumen settings page
#
#  Reached from the rail's Settings button. Lumen's own preferences live
#  here, and the app's stock settings are one tap further -- so the rail
#  keeps a single entry point and Lumen's options stay discoverable.
#############################################################################

# One settings row carrying a -/+ stepper group: the row panel, its label, an
# optional caption, and [-] value [+] right-aligned inside the row.
#
# Factored out in 0.24.0: with the rows re-dealt between the columns, inline
# copies in each column would have been two versions of the same row that
# could drift apart. All arguments in DESIGN px.
proc ::lumen::settings_stepper_row { p x y w label notecode valcode \
                                     minus_code plus_code what } {
    variable C
    variable L

    set rh  $L(set_row_h)
    set sw  $L(set_step_w)  ; set sg  $L(set_step_gap)
    set svw $L(set_val_w)   ; set sh  $L(set_step_h)

    glass $p $x $y $w $rh
    txt $p [expr {$x + $L(pad_x)}] [expr {$y + 26}] $label \
        -font $L(font_label) -fill $C(ink_3)
    if { $notecode ne "" } {
        var $p [expr {$x + $L(pad_x)}] [expr {$y + 56}] $notecode \
            -font $L(font_caption) -fill $C(ink_2)
    }

    set gx [expr {$x + $w - $L(pad_x) - (2 * $sw + 2 * $sg + $svw)}]
    set gy [expr {$y + ($rh - $sh) / 2}]
    set gmid_y [expr {$gy + $sh / 2.0}]
    foreach sx [list $gx [expr {$gx + $sw + $sg + $svw + $sg}]] \
            glyph [list "-" "+"] scode [list $minus_code $plus_code] \
            lbl [list "$what down" "$what up"] {
        glass $p $sx $gy $sw $sh -radius $L(radius_sm) -spec 0
        txt $p [expr {$sx + $sw / 2.0}] \
            [expr {$gmid_y + ($glyph eq "-" ? $L(step_minus_dy) : 0)}] $glyph \
            -font $L(font_section) -fill $C(crema) \
            -anchor center -justify center
        tap $p $sx $gy $sw $sh $scode $lbl
    }
    var $p [expr {$gx + $sw + $sg + $svw / 2.0}] $gmid_y $valcode \
        -font $L(font_data) -fill $C(ink) -anchor center -justify center
}

# A settings row whose -/+ pills drive one of TWO settings, with a tappable
# mode line choosing which (0.26.0, owner request: STEAM alternates time and
# flow, HOT WATER temperature and volume).
#
# Same panel, same pills, same x geometry as settings_stepper_row -- so the
# baked background does not change and nothing was re-rendered for this. What
# differs is inside the row:
#
#   * the caption line becomes MODE | other, in two text items. A canvas text
#     item's -fill is fixed at creation, so the words move between a crema
#     item and a dim one rather than the colours moving between fixed words.
#   * the value stacks: the selected setting at 26px on the pill band's upper
#     line, the other at 16px beneath it -- the same two-line arrangement the
#     home strip's YIELD column already uses for its ratio.
#
# All arguments in DESIGN px.
proc ::lumen::settings_dual_row { p x y w label active_code other_code \
                                  valcode altcode dir_cmd toggle_cmd what } {
    variable C
    variable L

    set rh  $L(set_row_h)
    set sw  $L(set_step_w)  ; set sg  $L(set_step_gap)
    set svw $L(set_val_w)   ; set sh  $L(set_step_h)

    glass $p $x $y $w $rh
    txt $p [expr {$x + $L(pad_x)}] [expr {$y + 26}] $label \
        -font $L(font_label) -fill $C(ink_3)

    # Mode line. The selected half is the accent colour, the other dim.
    var $p [expr {$x + $L(pad_x)}] [expr {$y + 56}] $active_code \
        -font $L(font_label) -fill $C(crema)
    var $p [expr {$x + $L(pad_x) + $L(set_mode_dx)}] [expr {$y + 56}] $other_code \
        -font $L(font_label) -fill $C(ink_3)
    # One tap over both words: with two modes, "tap the other one" and "toggle"
    # are the same action, and one target cannot be mis-hit the way two 60px
    # ones side by side can.
    tap $p [expr {$x + $L(pad_x)}] [expr {$y + 40}] \
        $L(set_mode_w) $L(set_mode_h) $toggle_cmd $what

    set gx [expr {$x + $w - $L(pad_x) - (2 * $sw + 2 * $sg + $svw)}]
    set gy [expr {$y + ($rh - $sh) / 2}]
    set gmid_y [expr {$gy + $sh / 2.0}]
    foreach sx [list $gx [expr {$gx + $sw + $sg + $svw + $sg}]] \
            glyph [list "-" "+"] d [list -1 1] \
            lbl [list "$what down" "$what up"] {
        glass $p $sx $gy $sw $sh -radius $L(radius_sm) -spec 0
        txt $p [expr {$sx + $sw / 2.0}] \
            [expr {$gmid_y + ($glyph eq "-" ? $L(step_minus_dy) : 0)}] $glyph \
            -font $L(font_section) -fill $C(crema) \
            -anchor center -justify center
        tap $p $sx $gy $sw $sh "$dir_cmd $d" $lbl
    }

    # Selected value on top, the other beneath it -- the YIELD column's
    # arrangement, on the same 48-tall band.
    set vx [expr {$gx + $sw + $sg + $svw / 2.0}]
    var $p $vx [expr {$gy + 16}] $valcode \
        -font $L(font_data) -fill $C(ink) -anchor center -justify center
    var $p $vx [expr {$gy + 38}] $altcode \
        -font $L(font_caption) -fill $C(ink_3) -anchor center -justify center
}

# One settings row whose control is a single button.
proc ::lumen::settings_button_row { p x y w label caption btn_label \
                                    command what bw bh args } {
    variable C
    variable L

    array set o [list -fill $C(glass_2) -outline $C(glass_brd) \
                      -ink $C(ink) -caption_w 220]
    array set o $args

    set rh $L(set_row_h)

    glass $p $x $y $w $rh
    txt $p [expr {$x + $L(pad_x)}] [expr {$y + 26}] $label \
        -font $L(font_label) -fill $C(ink_3)
    if { $caption ne "" } {
        txt $p [expr {$x + $L(pad_x)}] [expr {$y + 56}] $caption \
            -font $L(font_caption) -fill $C(ink_2) -width $o(-caption_w)
    }

    set bx [expr {$x + $w - $L(pad_x) - $bw}]
    set by [expr {$y + ($rh - $bh) / 2}]
    glass $p $bx $by $bw $bh -radius $L(radius_sm) \
        -fill $o(-fill) -outline $o(-outline)
    if { $btn_label ne "" } {
        txt $p [expr {$bx + $bw / 2.0}] [expr {$by + $bh / 2.0}] \
            [translate $btn_label] -font $L(font_button) -fill $o(-ink) \
            -anchor center -justify center
    }
    tap $p $bx $by $bw $bh $command $what
    return [list $bx $by]
}

proc ::lumen::build_settings {} {
    variable C
    variable L
    set p "lumen_settings"

    txt $p $L(center_x) 24 [translate "Lumen"] \
        -font $L(font_title) -fill $C(ink) -anchor n -justify center
    var $p $L(center_x) 72 {[::lumen::data::version_line]} \
        -font $L(font_caption) -fill $C(ink_3) -anchor n -justify center

    ####################################################################
    #  Two columns of four rows:
    #
    #    left  170..630 : BREW / STEAM / FLUSH / HOT WATER  (machine)
    #    right 670..1170: THEME / BAGS TO CYCLE / GRIND ADVISOR / DECENT APP
    #
    #  0.24.0 moved DECENT APP to the BOTTOM RIGHT (owner request). It was
    #  the second row of the right column; the two preference rows moved up
    #  to take its place and GRIND ADVISOR sits above it, so the page ends
    #  on the two "Open" doors with the emphasised one in the corner. The
    #  left column is untouched -- it is the machine column, and all four
    #  of its steppers stay together.
    #
    #  Rows at 110, 244, 378, 512, so both columns end at 630 -- 60 clear
    #  above Done at 690. No Chart lines row: the chart's own Stages / Raw
    #  pills already cover that (owner note).
    ####################################################################
    set lx $L(set_col_l) ; set lw $L(set_col_l_w)
    set rx $L(set_col_r) ; set rw $L(set_col_r_w)
    lassign $L(set_rows) ry1 ry2 ry3 ry4

    # ---- left column: the machine steppers ------------------------------
    #
    # BREW and FLUSH each steer one setting. STEAM and HOT WATER steer two,
    # chosen by the tappable mode line under their label (0.26.0).
    foreach {ry label notecode valcode minus_code plus_code what} [list \
        $ry1 [translate "BREW"] "" {[::lumen::data::brew_temp_value]} \
            {::lumen::act::adjust_brew_temp -0.5} {::lumen::act::adjust_brew_temp 0.5} "Brew" \
        $ry3 [translate "FLUSH"] "" {[::lumen::data::flush_time_value]} \
            {::lumen::act::adjust_flush_time -1} {::lumen::act::adjust_flush_time 1} "Flush" ] {
        settings_stepper_row $p $lx $ry $lw $label $notecode $valcode \
            $minus_code $plus_code $what
    }

    settings_dual_row $p $lx $ry2 $lw [translate "STEAM"] \
        {[::lumen::data::steam_mode_active]} {[::lumen::data::steam_mode_other]} \
        {[::lumen::data::steam_value]} {[::lumen::data::steam_value_alt]} \
        ::lumen::act::adjust_steam ::lumen::act::toggle_steam_mode "Steam"

    settings_dual_row $p $lx $ry4 $lw [translate "HOT WATER"] \
        {[::lumen::data::water_mode_active]} {[::lumen::data::water_mode_other]} \
        {[::lumen::data::water_value]} {[::lumen::data::water_value_alt]} \
        ::lumen::act::adjust_water ::lumen::act::toggle_water_mode "Hot water"

    # ---- right column ---------------------------------------------------
    #
    # THEME. The button deliberately is NOT accent-coloured: it is plain
    # glass, so it renders dark in the dark theme and light in the light
    # theme -- the button itself shows the theme (owner request). Its label
    # is live (it names the theme you will get), so the row is drawn here
    # rather than through settings_button_row.
    set bw 150 ; set bh 56
    glass $p $rx $ry1 $rw $L(set_row_h)
    txt $p [expr {$rx + $L(pad_x)}] [expr {$ry1 + 26}] [translate "THEME"] \
        -font $L(font_label) -fill $C(ink_3)
    var $p [expr {$rx + $L(pad_x)}] [expr {$ry1 + 56}] \
        {[::lumen::data::theme_note]} \
        -font $L(font_caption) -fill $C(ink_2) -width 290
    set bx [expr {$rx + $rw - $L(pad_x) - $bw}]
    set by [expr {$ry1 + ($L(set_row_h) - $bh) / 2}]
    glass $p $bx $by $bw $bh -radius $L(radius_sm) -fill $C(glass_2)
    var $p [expr {$bx + $bw / 2.0}] [expr {$by + $bh / 2.0}] \
        {[::lumen::data::theme_label]} \
        -font $L(font_button) -fill $C(ink) -anchor center -justify center
    tap $p $bx $by $bw $bh {::lumen::act::toggle_theme} "Theme"

    # BAGS TO CYCLE, with the same stepper geometry as the left column
    # mirrored to this column's inner edge: 670 + 500 - 24 = 1146, and the
    # group is 204 wide, so it starts at 942.
    glass $p $rx $ry2 $rw $L(set_row_h)
    txt $p [expr {$rx + $L(pad_x)}] [expr {$ry2 + 26}] [translate "BAGS TO CYCLE"] \
        -font $L(font_label) -fill $C(ink_3)
    txt $p [expr {$rx + $L(pad_x)}] [expr {$ry2 + 56}] \
        [translate "Recent bean bags the home strip can cycle through."] \
        -font $L(font_caption) -fill $C(ink_2) -width 220

    set sw $L(set_step_w) ; set sg $L(set_step_gap)
    set svw $L(set_val_w) ; set sh $L(set_step_h)
    set gx [expr {$rx + $rw - $L(pad_x) - (2 * $sw + 2 * $sg + $svw)}]
    set gy [expr {$ry2 + ($L(set_row_h) - $sh) / 2}]
    set gmid_y [expr {$gy + $sh / 2.0}]
    foreach sx [list $gx [expr {$gx + $sw + $sg + $svw + $sg}]] \
            glyph [list "-" "+"] \
            scode [list {::lumen::act::adjust_bag_count -1} \
                        {::lumen::act::adjust_bag_count 1}] \
            lbl [list "Bags down" "Bags up"] {
        glass $p $sx $gy $sw $sh -radius $L(radius_sm) -spec 0
        txt $p [expr {$sx + $sw / 2.0}] \
            [expr {$gmid_y + ($glyph eq "-" ? $L(step_minus_dy) : 0)}] $glyph \
            -font $L(font_section) -fill $C(crema) \
            -anchor center -justify center
        tap $p $sx $gy $sw $sh $scode $lbl
    }
    var $p [expr {$gx + $sw + $sg + $svw / 2.0}] $gmid_y \
        {[::lumen::data::bag_count_value]} \
        -font $L(font_data) -fill $C(ink) -anchor center -justify center

    # GRIND ADVISOR. Plain glass rather than accent: DECENT APP below is the
    # one emphasised door on this page and two accent buttons would compete.
    settings_button_row $p $rx $ry3 $rw [translate "GRIND ADVISOR"] \
        [translate "Target time, rounding, history and curve."] \
        "Open" {::lumen::act::open_grind_advisor} "Grind Advisor" 200 64

    # DECENT APP, bottom right (owner request) -- the door to everything
    # else, so it takes the accent and the last word on the page.
    settings_button_row $p $rx $ry4 $rw [translate "DECENT APP"] \
        [translate "Machine, profiles, plugins, firmware and everything else."] \
        "Open" {::lumen::act::open_app_settings} "App settings" 200 64 \
        -fill $C(crema_lo) -outline $C(crema_brd) -ink $C(crema) \
        -caption_w 240

    set dw $L(set_done_w) ; set dh $L(set_done_h)
    set dx [expr {$L(center_x) - $dw / 2}]
    set dy $L(set_done_y)
    glass $p $dx $dy $dw $dh -radius $L(radius_sm) \
        -fill $C(crema_lo) -outline $C(crema_brd)
    txt $p [expr {$dx + $dw / 2.0}] [expr {$dy + $dh / 2.0}] \
        [translate "Done"] -font $L(font_button) -fill $C(crema) \
        -anchor center -justify center
    tap $p $dx $dy $dw $dh {::lumen::act::close_settings} "Done"
}

::lumen::build_home
::lumen::build_settings

# Each page gets ITS OWN timer. Sharing espresso_secs across all of them
# reported time-since-the-last-espresso on the water and flush pages -- see
# water_secs / flush_secs for why that showed as 0s.
::lumen::build_flow_page espresso      {[::lumen::data::espresso_secs]} {[watertemp_text]} 1
::lumen::build_flow_page hotwaterrinse {[::lumen::data::flush_secs]}    {[watertemp_text]}
::lumen::build_flow_page water         {[::lumen::data::water_secs]}    {[watertemp_text]}
# The steam column shows the STEAM HEATER sensor (the only steam-side sensor
# the machine has), labelled as such and with the set point stated under it.
# Shown as a bare "TEMP" it read as a wrong value -- 158C with the heater
# set to 160 is the heater at its set point, not a misreading.
::lumen::build_flow_page steam         {[::lumen::data::steam_secs]}    {[steamtemp_text 1]} 0 \
    "STEAM HEATER" {[::lumen::data::steam_target_note]}

#############################################################################
#  DYE integration
#
#  DYE looks for ::plugins::DYE::setup_ui_<skin> and calls it if it exists
#  (DYE.tcl:103). The skin is sourced before `plugins init` runs in
#  ui_startup, so defining it here is enough -- DYE itself is never edited.
#
#  IMPORTANT, so nobody re-litigates this later: setup_ui_* is a THEMING
#  hook, not a page-replacement hook. Every proven example (setup_Streamline,
#  setup_DSx2) registers a dui theme and sets aspects; DYE still builds and
#  owns its own editor pages, including all the data binding and persistence
#  into shot history. Rebuilding that form in the skin would mean duplicating
#  the plugin, so what this does is restyle DYE's pages to match Lumen.
#
#  Font SIZES stay in DYE's own convention (dui units, scaled by fontm), not
#  Lumen's pixel sizes -- DYE's page geometry is laid out against those
#  numbers and substituting pixel sizes would blow its layout apart. Only the
#  family and the colours change.
#############################################################################

# The skin runs before `plugins init`, so this namespace does not exist yet
# and `proc ::plugins::DYE::...` would fail with "unknown namespace". Creating
# it here is safe and additive: DYE's own `namespace eval ::plugins::DYE`
# extends it, and the plugin framework's peek only adds variables to it.
namespace eval ::plugins::DYE {}

proc ::plugins::DYE::setup_ui_Lumen {} {
    set C_bg      $::lumen::C(bg)
    set C_panel   $::lumen::C(glass)
    set C_panel2  $::lumen::C(glass_2)
    set C_brd     $::lumen::C(glass_brd)
    set C_ink     $::lumen::C(ink)
    set C_ink2    $::lumen::C(ink_2)
    set C_ink3    $::lumen::C(ink_3)
    set C_accent  $::lumen::C(crema)
    set C_err     $::lumen::C(warn)

    set font  [::lumen::_font_family sans]
    set fontb [::lumen::_font_family sans_semi]
    set base  16

    dui theme add DYE_Lumen
    dui theme set DYE_Lumen

    dui aspect set -theme DYE_Lumen [subst {
        page.bg_img {}
        page.bg_color $C_bg
        dialog_page.bg_shape round_outline
        dialog_page.bg_color $C_panel
        dialog_page.fill $C_panel
        dialog_page.outline $C_brd
        dialog_page.width 1

        font.font_family "$font"
        font.font_size $base

        dtext.font_family "$font"
        dtext.font_size $base
        dtext.fill $C_ink
        dtext.disabledfill $C_ink3
        dtext.anchor nw
        dtext.justify left
        dtext.fill.remark $C_accent
        dtext.fill.error $C_err
        dtext.font_family.section_title "$fontb"
        dtext.font_family.page_title "$fontb"
        dtext.font_size.page_title 26
        dtext.fill.page_title $C_ink
        dtext.anchor.page_title center
        dtext.justify.page_title center

        symbol.fill $C_ink2
        symbol.disabledfill $C_ink3
        symbol.anchor nw
        symbol.justify left

        dbutton.fill $C_panel2
        dbutton.disabledfill $C_panel
        dbutton.outline $C_brd
        dbutton.disabledoutline $C_panel
        dbutton.width 1
        dbutton.radius 30

        dbutton_label.pos {0.5 0.5}
        dbutton_label.font_family "$fontb"
        dbutton_label.font_size [expr {$base + 1}]
        dbutton_label.anchor center
        dbutton_label.justify center
        dbutton_label.fill $C_ink
        dbutton_label.disabledfill $C_ink3

        entry.font_family "$font"
        entry.font_size $base
        entry.bg $C_panel2
        entry.foreground $C_ink
        entry.relief flat
        entry.borderwidth 1
        entry.highlightthickness 1
        entry.highlightcolor $C_accent
        entry.highlightbackground $C_brd
        entry.insertbackground $C_accent

        multiline_entry.font_family "$font"
        multiline_entry.font_size $base
        multiline_entry.bg $C_panel2
        multiline_entry.foreground $C_ink
        multiline_entry.relief flat
        multiline_entry.borderwidth 1
        multiline_entry.highlightthickness 1
        multiline_entry.highlightcolor $C_accent
        multiline_entry.highlightbackground $C_brd
        multiline_entry.insertbackground $C_accent

        listbox.font_family "$font"
        listbox.font_size $base
        listbox.background $C_panel2
        listbox.foreground $C_ink
        listbox.relief flat
        listbox.borderwidth 1
        listbox.selectbackground $C_accent
        listbox.selectforeground $C_bg
        listbox.disabledforeground $C_ink3

        dcheckbox.font_family "$font"
        dcheckbox.fill $C_ink
        dcheckbox.disabledfill $C_ink3
    }]

    msg -INFO "Lumen: DYE styled with the DYE_Lumen theme"
}

#############################################################################
#  Stop buttons
#
#  Copied verbatim from skins/default/standard_stop_buttons.tcl (minus its
#  add_de1_page lines, which would replace our colour backgrounds with the
#  default skin's JPGs, and minus its tankempty/refill block, which
#  standard_includes.tcl already provides).
#############################################################################

add_de1_button "steam" {say [translate {stop}] $::settings(sound_button_in); start_idle; check_if_steam_clogged} 0 0 2560 1600
add_de1_button "water" {say [translate {stop}] $::settings(sound_button_in); start_idle} 0 0 2560 1600
add_de1_button "espresso" {say [translate {stop}] $::settings(sound_button_in); start_idle} 0 0 2560 1600

# Deliberate addition, not in the stock file: the default skin has no
# tap-to-stop on the flush page because its flush is time-limited. Lumen
# gives flush a full page of its own, so it gets the same stop affordance as
# every other flow -- being unable to stop a running flush is worse than the
# inconsistency.
add_de1_button "hotwaterrinse" {say [translate {stop}] $::settings(sound_button_in); start_idle} 0 0 2560 1600

add_de1_button "saver descaling cleaning" {say [translate {awake}] $::settings(sound_button_in);start_idle; de1_send_waterlevel_settings} 0 0 2560 1600 "buttonnativepress"

add_de1_text "sleep" 2500 1450 -justify right -anchor "ne" -text [translate "Going to sleep"] -font Helv_20_bold -fill "#DDDDDD"

focus .can
bind Canvas <KeyPress> {handle_keypress %k}

# Deferred: the BLT vectors are created during app setup, which has not
# finished while the skin is being sourced. Five seconds is comfortably after
# startup and long before anyone pulls a shot.
after 5000 {
    if { [catch { ::lumen::load_last_shot_curves } err] } {
        msg -ERROR "Lumen: loading the last shot curves failed: $err"
    }
    # Same deferral, same reason: SDB is a plugin and has not finished
    # loading while the skin is being sourced.
    ::lumen::refresh_bag_list
}

# The bag cycler's window, rebuilt whenever the home page is shown -- which
# catches a new shot, a bag scan or a DYE edit without any of them needing to
# know about this skin. Once per page show, never on the refresh tick: the
# page indicator reads the cached list (0.27.0).
if { [catch { dui page add_action off show ::lumen::refresh_bag_list } err] } {
    msg -ERROR "Lumen: could not hook the bag-list refresh: $err"
}

# Core dui dialogs cannot be reached by theming, and recolouring them once at
# startup does not stick: dui repaints the page background when the page is
# SHOWN, discarding the change (measured -- the restyle reported "1 shapes"
# and the panel was still white).
#
# So hook the show event, which runs after dui has painted. add_action
# accepts a page that does not exist yet, so this can be registered here at
# skin load with no deferral.
foreach _p {dui_item_selector} {
    catch {
        dui page add_action $_p show "::lumen::restyle_core_dialog $_p"
    }
}
unset -nocomplain _p

# The espresso page opening means a shot is starting: record which profile it
# runs with, so the Last shot card can still name it after you switch. Guarded
# because add_action is a dui facility and a failure here must not stop the
# skin loading -- the value simply stays at whatever startup seeded.
if { [catch { dui page add_action espresso show ::lumen::latch_shot_profile } err] } {
    msg -ERROR "Lumen: could not hook the shot-profile latch: $err"
}

# Each flow page stamps when it was shown, so its timer can tell the flow it
# is about to run from the one before it. Without this the espresso page
# spends the moments between "the machine entered Espresso" and "the pour
# started" reading the PREVIOUS shot's timer -- the owner saw it flash 450s,
# then drop to 0 and count normally (0.24.0). See ::lumen::data::_flow_secs.
foreach _p {espresso steam water hotwaterrinse} {
    if { [catch { dui page add_action $_p show \
                    [list ::lumen::latch_flow_open $_p] } err] } {
        msg -ERROR "Lumen: could not hook the flow-timer latch for $_p: $err"
    }
}
unset -nocomplain _p

msg -INFO "Lumen skin v$::lumen::version loaded ($::lumen::theme_mode)"

