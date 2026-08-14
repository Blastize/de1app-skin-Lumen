package require de1plus 1.0

#############################################################################
#
#  LUMEN  --  a glass dashboard skin for the Decent DE1
#
#  Author:  Blastize
#  Version: 0.19.0  (tap-rate acceleration on the grind/dose/yield steppers)
#
#  SAFETY STATUS: no database is opened, and no file in history/ or
#  history_v2/ is read, written, renamed or deleted.
#
#  Every ::settings write happens only on an explicit tap, and every stepper
#  clamps its value so a runaway tap cannot write junk.
#
#  Preferences (home chart pills + Lumen settings page):
#    live_graph_smoothing_technique  -- Raw/Smooth toggle
#    lumen_chart_stages              -- Stages toggle
#    lumen_theme                     -- Dark/Light toggle
#
#  Next-shot steppers (home strip):
#    grinder_dose_weight             -- "Set dose" from the scale reading,
#                                       and the -/+ dose stepper (2..40)
#    grinder_setting                 -- the -/+ grind stepper (0..100)
#    final_desired_shot_weight       -- the -/+ yield and ratio steppers
#    final_desired_shot_weight_advanced -- same, when the profile is 2c
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
    variable version "0.19.0"

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
    # Regenerate with tools/make_home_bg.py after ANY layout change.
    variable baked_pages [list off]

    variable theme_mode   "dark"
    variable pending_theme ""   ;# set when a theme change needs a restart

    # after-id of the debounced machine-settings save/send (settings page).
    variable machine_apply_id ""
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
        set C(chart_bg)    "#DDE0E4"

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
        set C(chart_bg)    "#141517"

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

    set L(grind_x)   16 ; set L(grind_y)  16
    set L(grind_w)  650 ; set L(grind_h) 236

    set L(last_x)   682 ; set L(last_y)   16
    set L(last_w)   642 ; set L(last_h)  236

    set L(chart_x)   16 ; set L(chart_y) 268
    set L(chart_w) 1308 ; set L(chart_h) 332

    set L(bean_x)    16 ; set L(bean_y)  616
    set L(bean_w)  1124 ; set L(bean_h)  168

    # Side panel to the strip's right: Settings and Sleep, stacked. Its own
    # glass panel so the system actions read as separate from shot prep.
    set L(side_x)  1156 ; set L(side_w)   168
    set L(side_btn_x) 1170 ; set L(side_btn_w) 140 ; set L(side_btn_h) 60
    set L(side_y1)  634 ; set L(side_y2)  706

    # Bean strip internals: identity block, then four Streamline-style
    # stepper groups ( [-]  value  [+] with the value BETWEEN the pills ),
    # a scale row beneath, and a 2x2 action grid on the right.
    set L(bean_id_x)    40
    set L(bean_id_w)    280

    # Four columns spread EVENLY across the strip content (320..1116):
    # every control is 176 wide on a 206 pitch, so both the stepper row and
    # the bottom row share one grid with equal 30px gaps, ending flush at
    # the strip's inner edge (938 + 176 = 1114).
    set L(bean_fact_x)  320
    set L(bean_fact_w)  206        ;# column pitch

    # Stepper group internals: pill, gap, value span, gap, pill = 176.
    # Label row sits above at 636; pills 662..710.
    set L(step_w)       44
    set L(step_gap)      6
    set L(step_val_w)   76
    set L(step_y)      662
    set L(step_h)       48

    # Bottom row of the strip, y 722..770 (14 clear to the strip edge):
    # scale readout, Set dose, Scan bag, Edit -- on the SAME 206-pitch
    # grid as the stepper groups above, one control per column.
    set L(scale_y)      722
    set L(scale_h)       48
    set L(scale_read_x) 320 ; set L(scale_read_w) 176   ;# live readout
    set L(scale_set_x)  526 ; set L(scale_set_w)  176   ;# Set dose button
    set L(act_scan_x)   732 ; set L(act_edit_x)   938   ;# Scan bag / Edit
    set L(act_w)        176 ; set L(act_h)         48

    # Shot history shortcut, bottom row of the LAST SHOT tile, centred in
    # the tile: 682 + (642-200)/2 = 903. (Values end ~150; 180..228 in a
    # tile that ends at 252, so 24 clear below.)
    set L(hist_x)   903 ; set L(hist_y)  180
    set L(hist_w)   200 ; set L(hist_h)   48

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

# The recommendation dict, or {} if unavailable/not ok.
proc ::lumen::data::grind_rec {} {
    if { ![info exists ::plugins::GrindAdvisor::last_recommendation] } { return {} }
    set rec $::plugins::GrindAdvisor::last_recommendation
    if { $rec eq "" } { return {} }
    if { [catch { dict size $rec }] } { return {} }
    if { ![dict exists $rec ok] || ![dict get $rec ok] } { return {} }
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

# GrindAdvisor v3's ladder has FOUR rungs, not two -- see its own
# _forecast_method_label in plugins/GrindAdvisor/GrindAdvisor.tcl:1441:
#   first_shot  (n=1)  two_shot  (n=2)  regression  (n>=3)
#   regression_fallback  (n>=3 but the fitted slope is too flat to solve)
# Only the last two were mapped here, so the chip sat empty for the first two
# shots of every bag. Labels are shortened to fit the 150px chip; the Why?
# popup carries GrindAdvisor's own full wording.
proc ::lumen::data::grind_method {} {
    set rec [grind_rec]
    if { $rec eq "" } { return "" }
    set m [_g $rec method]
    switch -exact -- $m {
        first_shot          { return [translate "First shot"] }
        two_shot            { return [translate "2-shot"] }
        regression          { return [translate "Regression"] }
        regression_fallback { return [translate "Pairwise"] }
    }
    # A rung added by a newer GrindAdvisor: show it rather than nothing, so
    # the chip never silently goes blank again.
    return [_ellipsis $m 16]
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
# Same sources shot.tcl uses when it writes the shot file, so the tile and
# the saved record always agree. Note dose and grind setting persist across
# shots, so they read the same for "last" and "next" until you change them.

proc ::lumen::data::last_dose {} {
    return [_num [_s ::settings(grinder_dose_weight)] 1]
}

proc ::lumen::data::_yield_raw {} {
    set out [_s ::settings(drink_weight)]
    if { ![_is_pos $out] } { set out [_s ::de1(pour_volume)] }
    return $out
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
    set d [_s ::settings(grinder_dose_weight)]
    set y [_yield_raw]
    if { ![_is_pos $d] || ![_is_pos $y] } { return "--" }
    if { [catch { set r [expr {double($y) / double($d)}] }] } { return "--" }
    return [format "1:%.2f" $r]
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

# Live scale weight for the flow pages. Shows "--" rather than blank here,
# because on those pages the column always needs to read as a value.
# Blank once the chart has data. An empty BLT graph autoscales x to
# -0.1..0.1, which reads as a broken chart rather than an empty one.
proc ::lumen::data::chart_empty_note {} {
    if { [catch { set n [espresso_elapsed length] }] } { return "" }
    if { $n > 1 } { return "" }
    return [translate "No shot data yet - pull a shot"]
}

# espresso_timer is ([clock milliseconds] - $::timers(espresso_start))/1000.
# For the first tick of a shot, before espresso_start has been assigned, that
# subtracts from zero and yields epoch time -- a colossal number flashing on
# screen before the count starts. Anything outside a plausible shot duration
# is that glitch, not a reading.
proc ::lumen::data::_sane_secs { v } {
    if { ![string is double -strict $v] } { return 0 }
    if { $v < 0 || $v > 3600 } { return 0 }
    return $v
}

proc ::lumen::data::espresso_secs {} {
    set t 0
    catch { set t [espresso_timer] }
    return "[format %.0f [_sane_secs $t]]s"
}

proc ::lumen::data::steam_secs {} {
    set t 0
    catch { set t [steam_pour_timer] }
    return "[format %.0f [_sane_secs $t]]s"
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
proc ::lumen::load_last_shot_curves {} {
    # Never clobber a shot in progress.
    if { ![catch { set n [espresso_elapsed length] }] && $n > 1 } { return }

    set dir "[homedir]/history"
    if { ![file isdirectory $dir] } { return }

    set newest "" ; set newest_t 0
    foreach f [glob -nocomplain -directory $dir *.shot] {
        if { [catch { set t [file mtime $f] }] } { continue }
        if { $t > $newest_t } { set newest_t $t ; set newest $f }
    }
    if { $newest eq "" } { return }

    if { [catch {
        array set props [encoding convertfrom utf-8 [read_binary_file $newest]]
    } err] } {
        msg -ERROR "Lumen: could not read $newest: $err"
        return
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

    msg -INFO "Lumen: loaded last shot curves from [file tail $newest]"
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
# request): a slow tap moves 0.1; taps in quick succession (each within
# 700ms of the last) escalate to 0.5 after three and 1.0 after six, so a
# big adjustment does not take forty taps. A pause or a direction change
# drops straight back to 0.1. The app's legacy buttons fire once per press
# (there is no hold event), so holding registers as its taps do.
proc ::lumen::act::_accel_step { key dir } {
    variable accel
    set now [clock milliseconds]
    set last 0 ; set streak 0 ; set lastdir 0
    catch { lassign $accel($key) last streak lastdir }
    if { $dir == $lastdir && ($now - $last) < 700 } {
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

proc ::lumen::act::adjust_ratio { delta } {
    set d [::lumen::data::_s ::settings(grinder_dose_weight)]
    if { ![::lumen::data::_is_pos $d] } {
        msg -NOTICE "Lumen: no dose set, cannot step the ratio"
        return
    }
    set y [::lumen::data::_target_raw]
    if { ![string is double -strict $y] || $y <= 0 } {
        set y [expr {double($d) * 2.0}]
    }
    # Step the DISPLAYED (rounded) ratio, exactly like DSx2's "er" stepper,
    # so one tap always moves the visible number by one increment.
    set r [expr {round(double($y) / double($d) * 10.0) / 10.0 + $delta}]
    if { $r < 1.0 } { set r 1.0 } elseif { $r > 5.0 } { set r 5.0 }
    _write_yield [expr {double($d) * $r}]
}

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
proc ::lumen::tap { page x y w h command label } {
    add_de1_button $page \
        "say \[translate {$label}\] \$::settings(sound_button_in); $command" \
        [X $x] [Y $y] [X [expr {$x + $w}]] [Y [expr {$y + $h}]]
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

# Flow pages are declared here with a background COLOUR, not an image, which
# is why the skin ships no graphics. We deliberately do not source
# skins/default/standard_stop_buttons.tcl: it would re-declare these same
# pages with the default skin's background JPGs and paint over the glass.
# Its stop-button bindings are reproduced verbatim further down.
set ::lumen::pages [list espresso steam water hotwaterrinse]
dui page add $::lumen::pages -bg_color $::lumen::C(bg)

# The home page uses a pre-rendered background instead of a flat colour. Tk
# canvas has no alpha and no blur, so the frosted panels, their blurred
# backdrops, the soft shadows and the crema bloom are composited offline by
# tools/make_home_bg.py and loaded here as one image. dui resolves the file
# from the resolution folder that matches the screen (1340x800 / 2560x1600).
#
if { $::lumen::theme_mode eq "dark" } {
    dui page add off -bg_img "lumen_home.png"
} else {
    dui page add off -bg_img "lumen_home_light.png"
}

dui page add lumen_settings -bg_color $::lumen::C(bg)

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

    # Vertical budget inside the tile (content runs 36..232 in design px):
    #   label  36..56      hero 60..144     note 150..202     row 206..222
    # Hero and note are CENTRED on the tile (owner request); the delta sits
    # to the right of the widest hero the grind range allows ("50.0" is
    # ~101px half-width at the 84px mono size, so +120 clears it).
    set gmid [expr {$L(grind_x) + $L(grind_w) / 2.0}]
    var $p $gmid [expr {$gy + 24}] {[::lumen::data::grind_next]} \
        -font $L(font_hero) -fill $C(crema) -anchor n -justify center
    var $p [expr {$gmid + 120}] [expr {$gy + 76}] {[::lumen::data::grind_delta]} \
        -font $L(font_primary) -fill $C(good)

    var $p $gmid [expr {$gy + 114}] {[::lumen::data::grind_note]} \
        -font $L(font_body) -fill $C(ink_2) -width 560 \
        -anchor n -justify center

    # Method chip, top right. Blank until there is a recommendation.
    set mchip_x [expr {$L(grind_x) + $L(grind_w) - $L(pad_x) - 150}]
    glass $p $mchip_x $gy 150 26 -radius 13 \
        -fill $C(crema_lo) -outline $C(crema_brd) -spec 0
    var $p [expr {$mchip_x + 75}] [expr {$gy + 13}] {[::lumen::data::grind_method]} \
        -font $L(font_label) -fill $C(crema) -anchor center -justify center

    var $p $gx [expr {$gy + 170}] {[::lumen::data::grind_band]} \
        -font $L(font_caption) -fill $C(good)

    txt $p [expr {$L(grind_x) + $L(grind_w) - $L(pad_x)}] \
        [expr {$gy + 170}] \
        [translate "Shot analysis"] -font $L(font_caption) -fill $C(crema) \
        -anchor ne -justify right

    # "Curve" sits on the same baseline as "Shot analysis", one lg gap to its
    # left, and opens GrindAdvisor's calibration plot directly.
    set gcv_r [expr {$L(grind_x) + $L(grind_w) - $L(pad_x) - 130}]
    txt $p $gcv_r [expr {$gy + 170}] \
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

    set lx [expr {$L(last_x) + $L(pad_x)}]
    set ly [expr {$L(last_y) + $L(pad_y)}]

    txt $p $lx $ly [translate "LAST SHOT"] \
        -font $L(font_label) -fill $C(ink_3)

    set cw [expr {($L(last_w) - 2 * $L(pad_x)) / 4.0}]
    set i 0
    foreach {k code} [list \
        [translate "DOSE"]  {[::lumen::data::last_dose]} \
        [translate "YIELD"] {[::lumen::data::last_yield]} \
        [translate "TIME"]  {[::lumen::data::last_time]} \
        [translate "RATIO"] {[::lumen::data::last_ratio]} ] {
        set cx [expr {$lx + $i * $cw}]
        txt $p $cx [expr {$ly + 58}] $k -font $L(font_label) -fill $C(ink_3)
        var $p $cx [expr {$ly + 82}] $code -font $L(font_section) -fill $C(ink)
        incr i
    }

    # --- Shot history shortcut, bottom of the tile: opens the Shot History
    # Editor's card list (edit and soft-delete past shots). Lives here
    # because this is the card about past shots; next-shot controls do not.
    glass $p $L(hist_x) $L(hist_y) $L(hist_w) $L(hist_h) \
        -radius $L(radius_sm) -spec 0
    txt $p [expr {$L(hist_x) + $L(hist_w) / 2.0}] \
        [expr {$L(hist_y) + $L(hist_h) / 2.0}] \
        [translate "Shot history"] -font $L(font_button) -fill $C(ink_2) \
        -anchor center -justify center
    tap $p $L(hist_x) $L(hist_y) $L(hist_w) $L(hist_h) \
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

    txt $p $bx2 $by2 [translate "NEXT SHOT"] \
        -font $L(font_label) -fill $C(ink_3)
    var $p $bx2 [expr {$by2 + 26}] {[::lumen::data::bean_brand]} \
        -font $L(font_title) -fill $C(ink) -width $L(bean_id_w)
    var $p $bx2 [expr {$by2 + 72}] {[::lumen::data::bean_sub]} \
        -font $L(font_caption) -fill $C(ink_2) -width $L(bean_id_w)

    # --- four Streamline-style stepper groups: label above, then
    # [-]  value  [+] with the live value BETWEEN the pills. ASCII glyphs
    # only (design rule); the mono face renders them cleanly.
    set i 0
    foreach {k code minus_code plus_code what} [list \
        [translate "GRIND"]  {[::lumen::data::next_grind]} \
            {::lumen::act::adjust_grind -0.1} {::lumen::act::adjust_grind 0.1} "Grind" \
        [translate "DOSE"]   {[::lumen::data::next_dose]} \
            {::lumen::act::adjust_dose -0.1}  {::lumen::act::adjust_dose 0.1}  "Dose" \
        [translate "YIELD"]  {[::lumen::data::next_yield]} \
            {::lumen::act::adjust_yield -0.1} {::lumen::act::adjust_yield 0.1} "Yield" \
        [translate "RATIO"]  {[::lumen::data::next_ratio]} \
            {::lumen::act::adjust_ratio -0.1} {::lumen::act::adjust_ratio 0.1} "Ratio" ] {
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
            txt $p [expr {$sx + $L(step_w) / 2.0}] $mid_y $glyph \
                -font $L(font_section) -fill $C(crema) \
                -anchor center -justify center
            tap $p $sx $L(step_y) $L(step_w) $L(step_h) $scode $lbl
        }

        # The value, centred between the pills.
        var $p [expr {$kx + $L(step_w) + $L(step_gap) + $L(step_val_w) / 2.0}] \
            $mid_y $code -font $L(font_data) -fill $C(ink) \
            -anchor center -justify center

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

    # --- Scan bag and Edit complete the bottom row, under the YIELD and
    # RATIO groups, sharing the row's 48-high rhythm.
    foreach {gx label action accent} [list \
        $L(act_scan_x) "Scan bag" {::lumen::act::scan_bag} 1 \
        $L(act_edit_x) "Edit"     {::lumen::act::dye_next} 0 ] {
        if { $accent } {
            glass $p $gx $L(scale_y) $L(act_w) $L(act_h) \
                -radius $L(radius_sm) -fill $C(crema_lo) -outline $C(crema_brd)
            set ink $C(crema)
        } else {
            glass $p $gx $L(scale_y) $L(act_w) $L(act_h) \
                -radius $L(radius_sm) -spec 0
            set ink $C(ink_2)
        }
        txt $p [expr {$gx + $L(act_w) / 2.0}] \
            [expr {$L(scale_y) + $L(act_h) / 2.0}] \
            [translate $label] -font $L(font_button) -fill $ink \
            -anchor center -justify center
        tap $p $gx $L(scale_y) $L(act_w) $L(act_h) $action $label
    }

    # Identity opens DYE. Stops one md short of the stepper columns; the
    # fact area is all controls now, so DYE editing goes through Edit.
    tap $p $L(bean_x) $L(bean_y) \
        [expr {$L(bean_fact_x) - $L(bean_x) - $L(md)}] \
        $L(bean_h) \
        {::lumen::act::dye_next} "Next shot"

    ####################################################################
    #  Side panel: Settings and Sleep, in their own panel right of the
    #  strip. They moved here from the removed rail; without them the skin
    #  is a dead end with no way back to the skin picker.
    ####################################################################
    glass $p $L(side_x) $L(bean_y) $L(side_w) $L(bean_h)

    foreach {gy label action} [list \
        $L(side_y1) "Settings" {::lumen::act::open_settings} \
        $L(side_y2) "Sleep"    {start_sleep} ] {
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
                -background $C(chart_bg) -plotbackground $C(chart_bg) \
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

proc ::lumen::build_settings {} {
    variable C
    variable L
    set p "lumen_settings"

    txt $p $L(center_x) 24 [translate "Lumen"] \
        -font $L(font_title) -fill $C(ink) -anchor n -justify center
    var $p $L(center_x) 72 {[::lumen::data::version_line]} \
        -font $L(font_caption) -fill $C(ink_3) -anchor n -justify center

    ####################################################################
    #  Left column: machine adjustments, the same -/+ stepper groups as
    #  the home strip (owner request, mirroring Streamline's settings
    #  column). Value sits between the pills; changes are saved and sent
    #  to the machine, debounced by a second.
    #
    #  Column geometry: left 170..630 (460 wide), right 670..1170 (500
    #  wide) -- 170 clear on BOTH page edges, one 16 gap between rows.
    ####################################################################
    set rx 170 ; set rw 460 ; set rh 118 ; set ry 110
    set sw 44 ; set sg 8 ; set svw 100 ; set sh 48

    foreach {label notecode valcode minus_code plus_code what} [list \
        [translate "BREW"] "" {[::lumen::data::brew_temp_value]} \
            {::lumen::act::adjust_brew_temp -0.5} {::lumen::act::adjust_brew_temp 0.5} "Brew" \
        [translate "STEAM"] {[::lumen::data::steam_flow_note]} {[::lumen::data::steam_time_value]} \
            {::lumen::act::adjust_steam_time -5} {::lumen::act::adjust_steam_time 5} "Steam" \
        [translate "FLUSH"] "" {[::lumen::data::flush_time_value]} \
            {::lumen::act::adjust_flush_time -1} {::lumen::act::adjust_flush_time 1} "Flush" \
        [translate "HOT WATER"] {[::lumen::data::water_temp_note]} {[::lumen::data::water_volume_value]} \
            {::lumen::act::adjust_water_volume -10} {::lumen::act::adjust_water_volume 10} "Hot water" ] {

        glass $p $rx $ry $rw $rh
        txt $p [expr {$rx + $L(pad_x)}] [expr {$ry + 26}] $label \
            -font $L(font_label) -fill $C(ink_3)
        if { $notecode ne "" } {
            var $p [expr {$rx + $L(pad_x)}] [expr {$ry + 56}] $notecode \
                -font $L(font_caption) -fill $C(ink_2)
        }

        # [-] value [+], right-aligned in the row.
        set gx [expr {$rx + $rw - $L(pad_x) - (2 * $sw + 2 * $sg + $svw)}]
        set gy [expr {$ry + ($rh - $sh) / 2}]
        set gmid_y [expr {$gy + $sh / 2.0}]
        foreach sx [list $gx [expr {$gx + $sw + $sg + $svw + $sg}]] \
                glyph [list "-" "+"] scode [list $minus_code $plus_code] \
                lbl [list "$what down" "$what up"] {
            glass $p $sx $gy $sw $sh -radius $L(radius_sm) -spec 0
            txt $p [expr {$sx + $sw / 2.0}] $gmid_y $glyph \
                -font $L(font_section) -fill $C(crema) \
                -anchor center -justify center
            tap $p $sx $gy $sw $sh $scode $lbl
        }
        var $p [expr {$gx + $sw + $sg + $svw / 2.0}] $gmid_y $valcode \
            -font $L(font_data) -fill $C(ink) -anchor center -justify center

        set ry [expr {$ry + $rh + $L(md)}]
    }

    ####################################################################
    #  Right column: theme and the stock settings. No Chart lines row --
    #  the chart's own Stages / Raw pills already cover that (owner note).
    ####################################################################
    set rx 670 ; set rw 500 ; set rh 118
    set ry 110

    # THEME. The button deliberately is NOT accent-coloured: it is plain
    # glass, so it renders dark in the dark theme and light in the light
    # theme -- the button itself shows the theme (owner request).
    set bw 150 ; set bh 56
    glass $p $rx $ry $rw $rh
    txt $p [expr {$rx + $L(pad_x)}] [expr {$ry + 26}] [translate "THEME"] \
        -font $L(font_label) -fill $C(ink_3)
    var $p [expr {$rx + $L(pad_x)}] [expr {$ry + 56}] \
        {[::lumen::data::theme_note]} \
        -font $L(font_caption) -fill $C(ink_2) -width 290
    set bx [expr {$rx + $rw - $L(pad_x) - $bw}]
    set by [expr {$ry + ($rh - $bh) / 2}]
    glass $p $bx $by $bw $bh -radius $L(radius_sm) -fill $C(glass_2)
    var $p [expr {$bx + $bw / 2.0}] [expr {$by + $bh / 2.0}] \
        {[::lumen::data::theme_label]} \
        -font $L(font_button) -fill $C(ink) -anchor center -justify center
    tap $p $bx $by $bw $bh {::lumen::act::toggle_theme} "Theme"

    # DECENT APP, with a bigger accent button (owner request) -- this is
    # the door to everything else, so it earns the emphasis.
    set ry [expr {$ry + $rh + $L(md)}]
    set bw 200 ; set bh 64
    glass $p $rx $ry $rw $rh
    txt $p [expr {$rx + $L(pad_x)}] [expr {$ry + 26}] [translate "DECENT APP"] \
        -font $L(font_label) -fill $C(ink_3)
    txt $p [expr {$rx + $L(pad_x)}] [expr {$ry + 56}] \
        [translate "Machine, profiles, plugins, firmware and everything else."] \
        -font $L(font_caption) -fill $C(ink_2) -width 240
    set bx [expr {$rx + $rw - $L(pad_x) - $bw}]
    set by [expr {$ry + ($rh - $bh) / 2}]
    glass $p $bx $by $bw $bh -radius $L(radius_sm) \
        -fill $C(crema_lo) -outline $C(crema_brd)
    txt $p [expr {$bx + $bw / 2.0}] [expr {$by + $bh / 2.0}] \
        [translate "Open"] -font $L(font_button) -fill $C(crema) \
        -anchor center -justify center
    tap $p $bx $by $bw $bh {::lumen::act::open_app_settings} "App settings"

    set dw 240 ; set dh 72
    set dx [expr {$L(center_x) - $dw / 2}]
    set dy 690
    glass $p $dx $dy $dw $dh -radius $L(radius_sm) \
        -fill $C(crema_lo) -outline $C(crema_brd)
    txt $p [expr {$dx + $dw / 2.0}] [expr {$dy + $dh / 2.0}] \
        [translate "Done"] -font $L(font_button) -fill $C(crema) \
        -anchor center -justify center
    tap $p $dx $dy $dw $dh {::lumen::act::close_settings} "Done"
}

::lumen::build_home
::lumen::build_settings

::lumen::build_flow_page espresso      {[::lumen::data::espresso_secs]} {[watertemp_text]} 1
::lumen::build_flow_page hotwaterrinse {[::lumen::data::espresso_secs]} {[watertemp_text]}
::lumen::build_flow_page water         {[::lumen::data::espresso_secs]} {[watertemp_text]}
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

msg -INFO "Lumen skin v$::lumen::version loaded ($::lumen::theme_mode)"

