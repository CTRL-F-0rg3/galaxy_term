using Gtk;
using Vte;

// ============================================================
//  Galaxy Terminal — półprzezroczysty terminal z tłem galaktyki
//  Kompilacja:
//    valac --pkg gtk+-3.0 --pkg vte-2.91 -X -lm main.vala -o galaxy-term
// ============================================================

const string CSS = """
window, window.csd {
    background-color: transparent;
    background-image: none;
    box-shadow: none;
    border: none;
    margin: 0;
}
decoration, window.csd decoration, window.csd.popup decoration {
    box-shadow: none;
    border: none;
    margin: 0;
    padding: 0;
    border-radius: 0;
    background: transparent;
}
headerbar {
    background-color: transparent;
    background-image: none;
    box-shadow: none;
    border: none;
    padding: 0;
    margin: 0;
    min-height: 0;
}
.header {
    padding: 10px 14px;
    background: transparent;
}
.traffic {
    min-width: 12px;
    min-height: 12px;
    padding: 0;
    margin: 0;
    border: none;
    border-radius: 6px;
    box-shadow: none;
    background-image: none;
    transition: background-color 150ms ease;
}
.traffic-close { background-color: #ff5f57; }
.traffic-close:hover { background-color: #ff8f88; }
.traffic-min   { background-color: #febc2e; }
.traffic-min:hover   { background-color: #ffd05b; }
.traffic-max   { background-color: #28c840; }
.traffic-max:hover   { background-color: #5fd875; }
.title {
    color: rgba(255, 255, 255, 0.55);
    font-weight: 600;
    font-size: 13px;
}
vte-terminal {
    padding: 6px 14px 12px 14px;
}
menu, .menu, .popup {
    border-radius: 10px;
}
""";

// ------------------------------------------------------------
//  Ustawienia (zmieniane z menu kontekstowego)
// ------------------------------------------------------------
double bg_opacity     = 0.86;   // krycie ciemnego tła okna
bool   show_galaxy    = true;
double galaxy_strength = 0.55;  // jak mocno widać galaktykę
double font_scale     = 1.0;

Cairo.ImageSurface? galaxy_surface = null;

// ------------------------------------------------------------
//  Generowanie tła galaktyki (proceduralnie, raz na start)
//  Jeśli istnieje plik ~/.config/galaxy-term/background.png|jpg,
//  zostanie użyty zamiast generowanego tła.
// ------------------------------------------------------------
const int GW = 1800;
const int GH = 1200;

void soft_blob(Cairo.Context cr, double x, double y, double r,
               double cr_, double cg, double cb, double a) {
    var g = new Cairo.Pattern.radial(x, y, 0, x, y, r);
    g.add_color_stop_rgba(0.0, cr_, cg, cb, a);
    g.add_color_stop_rgba(0.5, cr_, cg, cb, a * 0.35);
    g.add_color_stop_rgba(1.0, cr_, cg, cb, 0.0);
    cr.set_source(g);
    cr.arc(x, y, r, 0, 2 * Math.PI);
    cr.fill();
}

Cairo.ImageSurface? load_custom_background() {
    string dir = Path.build_filename(Environment.get_user_config_dir(), "galaxy-term");
    string[] names = { "background.png", "background.jpg", "background.jpeg", "background.webp" };
    foreach (var n in names) {
        string path = Path.build_filename(dir, n);
        if (!FileUtils.test(path, FileTest.EXISTS)) continue;
        try {
            var pb = new Gdk.Pixbuf.from_file(path);
            var s = new Cairo.ImageSurface(Cairo.Format.ARGB32, pb.width, pb.height);
            var cr = new Cairo.Context(s);
            Gdk.cairo_set_source_pixbuf(cr, pb, 0, 0);
            cr.paint();
            return s;
        } catch (Error e) {
            stderr.printf("Tło: %s\n", e.message);
        }
    }
    return null;
}

Cairo.ImageSurface build_galaxy() {
    var custom = load_custom_background();
    if (custom != null) return custom;

    var s = new Cairo.ImageSurface(Cairo.Format.ARGB32, GW, GH);
    var cr = new Cairo.Context(s);
    var rnd = new Rand.with_seed(20260);   // stałe ziarno = zawsze ta sama galaktyka

    // 1. Głęboki kosmos
    var bg = new Cairo.Pattern.linear(0, 0, GW, GH);
    bg.add_color_stop_rgb(0.0, 0.03, 0.03, 0.10);
    bg.add_color_stop_rgb(0.5, 0.05, 0.03, 0.12);
    bg.add_color_stop_rgb(1.0, 0.02, 0.05, 0.13);
    cr.set_source(bg);
    cr.paint();

    // 2. Delikatne mgławice
    soft_blob(cr, GW * 0.20, GH * 0.25, 520, 0.45, 0.20, 0.75, 0.30);
    soft_blob(cr, GW * 0.80, GH * 0.20, 460, 0.15, 0.35, 0.85, 0.25);
    soft_blob(cr, GW * 0.35, GH * 0.85, 520, 0.80, 0.20, 0.55, 0.22);
    soft_blob(cr, GW * 0.90, GH * 0.80, 420, 0.20, 0.55, 0.80, 0.20);
    soft_blob(cr, GW * 0.55, GH * 0.45, 600, 0.30, 0.15, 0.55, 0.18);

    // 3. Galaktyka spiralna (po prawej, lekko odchylona)
    double cx = GW * 0.70, cy = GH * 0.52;
    double tilt = -0.55;          // obrót
    double squash = 0.46;         // "spłaszczenie" (widok pod kątem)
    double ct = Math.cos(tilt), st = Math.sin(tilt);

    // poświata halo
    cr.save();
    cr.translate(cx, cy);
    cr.rotate(tilt);
    cr.scale(1.0, squash);
    soft_blob(cr, 0, 0, 420, 0.55, 0.45, 0.95, 0.20);
    soft_blob(cr, 0, 0, 170, 1.00, 0.85, 0.65, 0.35);
    cr.restore();

    int arms = 2;
    int dots = 9000;
    for (int i = 0; i < dots; i++) {
        double t = rnd.next_double();                 // 0..1 wzdłuż ramienia
        double r = 40 + t * 360;
        int arm = rnd.int_range(0, arms);
        double ang = arm * (2 * Math.PI / arms) + t * 4.2 * Math.PI * 0.5 * 1.6;
        // rozrzut gaussowski (suma losowych ≈ rozkład normalny)
        double spread = 6 + t * 38;
        double nx = (rnd.next_double() + rnd.next_double() + rnd.next_double() - 1.5) * spread;
        double ny = (rnd.next_double() + rnd.next_double() + rnd.next_double() - 1.5) * spread;
        double px = Math.cos(ang) * r + nx;
        double py = Math.sin(ang) * r + ny;
        // obrót + spłaszczenie
        double X = cx + px * ct - py * squash * st * 1.0;
        double Y = cy + px * st + py * squash * ct * 1.0;

        // kolor: ciepły środek -> niebiesko-fioletowe ramiona
        double rr = 1.0 - t * 0.60;
        double gg = 0.78 - t * 0.28;
        double bb = 0.60 + t * 0.40;
        double a = (0.10 + rnd.next_double() * 0.22) * (1.0 - t * 0.5);
        double size = 0.6 + rnd.next_double() * 1.4;

        cr.set_source_rgba(rr, gg, bb, a);
        cr.arc(X, Y, size, 0, 2 * Math.PI);
        cr.fill();
    }

    // jasne jądro
    cr.save();
    cr.translate(cx, cy);
    cr.rotate(tilt);
    cr.scale(1.0, squash);
    soft_blob(cr, 0, 0, 80, 1.0, 0.95, 0.85, 0.55);
    cr.restore();

    // 4. Gwiazdy
    for (int i = 0; i < 700; i++) {
        double x = rnd.next_double() * GW;
        double y = rnd.next_double() * GH;
        double m = rnd.next_double();
        double a = 0.25 + m * 0.65;
        double size = 0.5 + m * m * 1.4;
        // lekko kolorowe gwiazdy
        double tone = rnd.next_double();
        double r = tone < 0.2 ? 1.0 : 0.85 + 0.15 * tone;
        double g = 0.85 + 0.1 * tone;
        double b = tone > 0.7 ? 1.0 : 0.85;
        cr.set_source_rgba(r, g, b, a);
        cr.arc(x, y, size, 0, 2 * Math.PI);
        cr.fill();

        // blask na największych
        if (m > 0.97) {
            soft_blob(cr, x, y, 9 + m * 8, 0.8, 0.85, 1.0, 0.35);
        }
    }

    return s;
}

delegate void DoubleFn(double v);

// Cienki, niewidoczny uchwyt do zmiany rozmiaru okna
Gtk.EventBox make_grip(Gtk.Window win, Gdk.WindowEdge edge, Gtk.Align ha, Gtk.Align va,
                       int w, int h, string cursor_name) {
    var g = new Gtk.EventBox();
    g.set_visible_window(false);
    g.set_halign(ha);
    g.set_valign(va);
    g.set_size_request(w, h);
    g.add_events(Gdk.EventMask.BUTTON_PRESS_MASK);
    g.realize.connect(() => {
        var cur = new Gdk.Cursor.from_name(g.get_display(), cursor_name);
        g.get_window().set_cursor(cur);
    });
    g.button_press_event.connect((ev) => {
        if (ev.button != 1) return false;
        win.begin_resize_drag(edge, (int) ev.button, (int) ev.x_root, (int) ev.y_root, ev.time);
        return true;
    });
    return g;
}

void add_item(Gtk.Menu m, Gtk.Widget item) {
    m.add(item);
}

// ------------------------------------------------------------
//  Ścieżka zaokrąglonego prostokąta
// ------------------------------------------------------------
void round_rect(Cairo.Context cr, double w, double h, double radius) {
    cr.new_sub_path();
    cr.arc(w - radius, radius,     radius, -Math.PI / 2, 0);
    cr.arc(w - radius, h - radius, radius, 0,             Math.PI / 2);
    cr.arc(radius,     h - radius, radius, Math.PI / 2,   Math.PI);
    cr.arc(radius,     radius,     radius, Math.PI,       3 * Math.PI / 2);
    cr.close_path();
}

// ------------------------------------------------------------
//  Przyciski "sygnalizacji" w stylu macOS
// ------------------------------------------------------------
Gtk.Button make_traffic(string cls, string tip) {
    var b = new Gtk.Button();
    b.set_relief(Gtk.ReliefStyle.NONE);
    b.set_size_request(12, 12);
    b.set_valign(Gtk.Align.CENTER);
    b.set_tooltip_text(tip);
    b.set_can_focus(false);   // nie kradnie fokusu terminalowi (ważne dla neovima)
    b.get_style_context().add_class("traffic");
    b.get_style_context().add_class(cls);
    return b;
}

// ------------------------------------------------------------
//  Paleta kolorów (Tokyo Night)
// ------------------------------------------------------------
Gdk.RGBA rgba(string s) {
    var c = Gdk.RGBA();
    c.parse(s);
    return c;
}

void apply_theme(Vte.Terminal t) {
    Gdk.RGBA[] palette = {
        rgba("#15161e"), rgba("#f7768e"), rgba("#9ece6a"), rgba("#e0af68"),
        rgba("#7aa2f7"), rgba("#bb9af7"), rgba("#7dcfff"), rgba("#a9b1d6"),
        rgba("#414868"), rgba("#ff899d"), rgba("#9fe044"), rgba("#faba4a"),
        rgba("#8db0ff"), rgba("#c7a9ff"), rgba("#a4daff"), rgba("#c0caf5")
    };
    t.set_colors(rgba("#c0caf5"), rgba("rgba(0,0,0,0)"), palette);
    t.set_color_cursor(rgba("#c0caf5"));
    t.set_color_cursor_foreground(rgba("#1a1b26"));
    t.set_color_highlight(rgba("rgba(122,162,247,0.35)"));
    t.set_color_highlight_foreground(rgba("#ffffff"));
}

// ------------------------------------------------------------
//  main
// ------------------------------------------------------------
int main(string[] args) {
    Gtk.init(ref args);

    var provider = new Gtk.CssProvider();
    try {
        provider.load_from_data(CSS, CSS.length);
    } catch (Error e) {
        stderr.printf("CSS: %s\n", e.message);
    }
    Gtk.StyleContext.add_provider_for_screen(
        Gdk.Screen.get_default(), provider,
        Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
    );

    galaxy_surface = build_galaxy();

    var window = new Gtk.Window();
    window.title = "Galaxy Terminal";
    window.set_default_size(960, 620);
    window.set_position(Gtk.WindowPosition.CENTER);
    window.set_app_paintable(true);

    var screen = window.get_screen();
    var visual = screen.get_rgba_visual();
    if (visual != null && screen.is_composited())
        window.set_visual(visual);

    window.destroy.connect(Gtk.main_quit);

    // ---- Rysowanie tła okna: ciemna szyba + galaktyka ----
    window.draw.connect((cr) => {
        int w = window.get_allocated_width();
        int h = window.get_allocated_height();
        bool flat = window.is_maximized || (window.get_window().get_state() & Gdk.WindowState.FULLSCREEN) != 0;
        double radius = flat ? 0.0 : 14.0;

        cr.set_operator(Cairo.Operator.CLEAR);
        cr.paint();
        cr.set_operator(Cairo.Operator.OVER);

        round_rect(cr, w, h, radius);
        cr.save();
        cr.clip_preserve();

        // ciemna, półprzezroczysta szyba
        cr.set_source_rgba(0.06, 0.06, 0.09, bg_opacity);
        cr.paint();

        // galaktyka (skalowanie "cover" – wypełnia całe okno)
        if (show_galaxy && galaxy_surface != null) {
            double iw = galaxy_surface.get_width();
            double ih = galaxy_surface.get_height();
            double sc = double.max(w / iw, h / ih);
            cr.save();
            cr.translate((w - iw * sc) / 2, (h - ih * sc) / 2);
            cr.scale(sc, sc);
            cr.set_source_surface(galaxy_surface, 0, 0);
            cr.paint_with_alpha(galaxy_strength * double.min(1.0, bg_opacity + 0.15));
            cr.restore();
        }

        // delikatne przyciemnienie od dołu dla czytelności tekstu
        var shade = new Cairo.Pattern.linear(0, 0, 0, h);
        shade.add_color_stop_rgba(0.0, 0, 0, 0, 0.05);
        shade.add_color_stop_rgba(1.0, 0, 0, 0, 0.30);
        cr.set_source(shade);
        cr.paint();
        cr.restore();

        // subtelna ramka
        round_rect(cr, w, h, radius);
        cr.set_source_rgba(1.0, 1.0, 1.0, 0.10);
        cr.set_line_width(1.0);
        cr.stroke();

        return false;
    });

    // ---- Pasek tytułu (macOS) ----
    var header_overlay = new Gtk.Overlay();
    var header_box = new Gtk.Box(Orientation.HORIZONTAL, 0);
    header_box.get_style_context().add_class("header");

    var btn_box = new Gtk.Box(Orientation.HORIZONTAL, 8);
    btn_box.set_valign(Gtk.Align.CENTER);

    var btn_close = make_traffic("traffic-close", "Zamknij");
    btn_close.clicked.connect(() => window.destroy());

    var btn_min = make_traffic("traffic-min", "Minimalizuj");
    btn_min.clicked.connect(() => window.iconify());

    var btn_max = make_traffic("traffic-max", "Maksymalizuj");
    btn_max.clicked.connect(() => {
        if (window.is_maximized) window.unmaximize();
        else window.maximize();
    });

    btn_box.pack_start(btn_close, false, false, 0);
    btn_box.pack_start(btn_min,   false, false, 0);
    btn_box.pack_start(btn_max,   false, false, 0);
    header_box.pack_start(btn_box, false, false, 0);

    var spacer = new Gtk.Box(Orientation.HORIZONTAL, 0);
    spacer.set_hexpand(true);
    header_box.pack_start(spacer, true, true, 0);

    var title = new Gtk.Label(window.title);
    title.get_style_context().add_class("title");
    title.set_halign(Gtk.Align.CENTER);
    title.set_valign(Gtk.Align.CENTER);
    title.set_ellipsize(Pango.EllipsizeMode.END);
    title.set_max_width_chars(60);

    header_overlay.add(header_box);
    header_overlay.add_overlay(title);
    header_overlay.set_overlay_pass_through(title, true);

    header_overlay.add_events(Gdk.EventMask.BUTTON_PRESS_MASK);
    header_overlay.button_press_event.connect((event) => {
        if (event.button != 1) return false;
        if (event.type == Gdk.EventType.DOUBLE_BUTTON_PRESS) {
            if (window.is_maximized) window.unmaximize();
            else window.maximize();
            return true;
        }
        window.begin_move_drag(
            (int) event.button,
            (int) event.x_root,
            (int) event.y_root,
            event.time
        );
        return false;
    });

    const int E = 5;   // grubość krawędzi
    const int C = 12;  // rozmiar rogu
    header_overlay.add_overlay(make_grip(window, Gdk.WindowEdge.NORTH, Gtk.Align.FILL, Gtk.Align.START, -1, E, "n-resize"));
    header_overlay.add_overlay(make_grip(window, Gdk.WindowEdge.NORTH_WEST, Gtk.Align.START, Gtk.Align.START, C, C, "nw-resize"));
    header_overlay.add_overlay(make_grip(window, Gdk.WindowEdge.NORTH_EAST, Gtk.Align.END, Gtk.Align.START, C, C, "ne-resize"));

    window.set_titlebar(header_overlay);

    // ---- Kontener + terminal ----
    var vbox = new Gtk.Box(Orientation.VERTICAL, 0);
    var content = new Gtk.Overlay();
    content.add(vbox);
    window.add(content);
    content.add_overlay(make_grip(window, Gdk.WindowEdge.WEST,  Gtk.Align.START, Gtk.Align.FILL, E, -1, "w-resize"));
    content.add_overlay(make_grip(window, Gdk.WindowEdge.EAST,  Gtk.Align.END,   Gtk.Align.FILL, E, -1, "e-resize"));
    content.add_overlay(make_grip(window, Gdk.WindowEdge.SOUTH, Gtk.Align.FILL,  Gtk.Align.END, -1, E, "s-resize"));
    content.add_overlay(make_grip(window, Gdk.WindowEdge.SOUTH_WEST, Gtk.Align.START, Gtk.Align.END, C, C, "sw-resize"));
    content.add_overlay(make_grip(window, Gdk.WindowEdge.SOUTH_EAST, Gtk.Align.END,   Gtk.Align.END, C, C, "se-resize"));

    var terminal = new Vte.Terminal();
    terminal.set_scrollback_lines(10000);
    terminal.set_clear_background(false);
    terminal.set_font(Pango.FontDescription.from_string("Monospace 11"));
    terminal.set_cursor_blink_mode(Vte.CursorBlinkMode.OFF);
    terminal.set_cursor_shape(Vte.CursorShape.BLOCK);
    terminal.set_scroll_on_output(false);
    terminal.set_scroll_on_keystroke(true);
    terminal.set_allow_hyperlink(true);
    terminal.set_mouse_autohide(true);
    terminal.set_bold_is_bright(false);
    apply_theme(terminal);

    // tytuł okna = tytuł z terminala (np. "nvim main.vala")
    terminal.window_title_changed.connect(() => {
        string? t = terminal.get_window_title();
        title.set_text((t != null && t != "") ? t : "Galaxy Terminal");
    });

    // zamknięcie okna, gdy powłoka się zakończy
    terminal.child_exited.connect((status) => {
        window.destroy();
    });

    // ---- Uruchomienie powłoki ----
    try {
        string shell = Environment.get_variable("SHELL") ?? "/bin/bash";
        string[] command = { shell };
        // truecolor dla neovima (set termguicolors)
        string[] env = Environ.set_variable(Environ.get(), "COLORTERM", "truecolor");
        terminal.spawn_sync(
            Vte.PtyFlags.DEFAULT, null, command, env,
            (GLib.SpawnFlags) 0, null, null, null
        );
    } catch (Error e) {
        stderr.printf("Błąd: %s\n", e.message);
        string msg = "Nie można uruchomić powłoki: " + e.message + "\r\n";
        terminal.feed(msg.data);
    }

    // ---- Funkcje pomocnicze (zoom / krycie) ----
    DoubleFn set_zoom = (v) => {
        font_scale = double.max(0.5, double.min(3.0, v));
        terminal.set_font_scale(font_scale);
    };
    DoubleFn set_opacity = (v) => {
        bg_opacity = double.max(0.15, double.min(1.0, v));
        window.queue_draw();
    };

    // ---- Menu kontekstowe ----
    var menu = new Gtk.Menu();

    var mi_copy = new Gtk.MenuItem.with_label("Kopiuj");
    mi_copy.activate.connect(() => terminal.copy_clipboard_format(Vte.Format.TEXT));
    var mi_paste = new Gtk.MenuItem.with_label("Wklej");
    mi_paste.activate.connect(() => terminal.paste_clipboard());
    var mi_select = new Gtk.MenuItem.with_label("Zaznacz wszystko");
    mi_select.activate.connect(() => terminal.select_all());

    var mi_zoom_in = new Gtk.MenuItem.with_label("Powiększ czcionkę");
    mi_zoom_in.activate.connect(() => set_zoom(font_scale + 0.1));
    var mi_zoom_out = new Gtk.MenuItem.with_label("Pomniejsz czcionkę");
    mi_zoom_out.activate.connect(() => set_zoom(font_scale - 0.1));
    var mi_zoom_reset = new Gtk.MenuItem.with_label("Domyślny rozmiar czcionki");
    mi_zoom_reset.activate.connect(() => set_zoom(1.0));

    var mi_op_up = new Gtk.MenuItem.with_label("Mniej przezroczyste");
    mi_op_up.activate.connect(() => set_opacity(bg_opacity + 0.05));
    var mi_op_down = new Gtk.MenuItem.with_label("Bardziej przezroczyste");
    mi_op_down.activate.connect(() => set_opacity(bg_opacity - 0.05));

    var mi_galaxy = new Gtk.CheckMenuItem.with_label("Tło galaktyki");
    mi_galaxy.active = show_galaxy;
    mi_galaxy.toggled.connect(() => {
        show_galaxy = mi_galaxy.active;
        window.queue_draw();
    });

    var mi_gal_up = new Gtk.MenuItem.with_label("Wyraźniejsza galaktyka");
    mi_gal_up.activate.connect(() => {
        galaxy_strength = double.min(1.0, galaxy_strength + 0.1);
        window.queue_draw();
    });
    var mi_gal_down = new Gtk.MenuItem.with_label("Subtelniejsza galaktyka");
    mi_gal_down.activate.connect(() => {
        galaxy_strength = double.max(0.1, galaxy_strength - 0.1);
        window.queue_draw();
    });

    var mi_clear = new Gtk.MenuItem.with_label("Wyczyść terminal");
    mi_clear.activate.connect(() => terminal.reset(true, true));

    var mi_full = new Gtk.MenuItem.with_label("Pełny ekran (przełącz)");
    mi_full.activate.connect(() => {
        if ((window.get_window().get_state() & Gdk.WindowState.FULLSCREEN) != 0)
            window.unfullscreen();
        else
            window.fullscreen();
    });

    var mi_quit = new Gtk.MenuItem.with_label("Zamknij");
    mi_quit.activate.connect(() => window.destroy());

    add_item(menu, mi_copy);
    add_item(menu, mi_paste);
    add_item(menu, mi_select);
    add_item(menu, new Gtk.SeparatorMenuItem());
    add_item(menu, mi_zoom_in);
    add_item(menu, mi_zoom_out);
    add_item(menu, mi_zoom_reset);
    add_item(menu, new Gtk.SeparatorMenuItem());
    add_item(menu, mi_op_up);
    add_item(menu, mi_op_down);
    add_item(menu, mi_galaxy);
    add_item(menu, mi_gal_up);
    add_item(menu, mi_gal_down);
    add_item(menu, new Gtk.SeparatorMenuItem());
    add_item(menu, mi_clear);
    add_item(menu, mi_full);
    add_item(menu, new Gtk.SeparatorMenuItem());
    add_item(menu, mi_quit);
    menu.show_all();

    // Prawy przycisk -> menu. Przytrzymaj Shift, jeśli chcesz, by w neovimie
    // prawy klik trafił do samej aplikacji.
    terminal.button_press_event.connect((ev) => {
        if (ev.button == 3 && (ev.state & Gdk.ModifierType.SHIFT_MASK) == 0) {
            mi_copy.sensitive = terminal.get_has_selection();
            mi_galaxy.active = show_galaxy;
            menu.popup_at_pointer(ev);
            return true;
        }
        return false;
    });

    // ---- Skróty klawiszowe ----
    terminal.key_press_event.connect((ev) => {
        var mods = ev.state & Gtk.accelerator_get_default_mod_mask();
        var ctrl_shift = Gdk.ModifierType.CONTROL_MASK | Gdk.ModifierType.SHIFT_MASK;
        if (mods == ctrl_shift) {
            switch (ev.keyval) {
                case Gdk.Key.C: case Gdk.Key.c:
                    terminal.copy_clipboard_format(Vte.Format.TEXT);
                    return true;
                case Gdk.Key.V: case Gdk.Key.v:
                    terminal.paste_clipboard();
                    return true;
                case Gdk.Key.plus: case Gdk.Key.equal:
                    set_zoom(font_scale + 0.1);
                    return true;
                case Gdk.Key.underscore: case Gdk.Key.minus:
                    set_zoom(font_scale - 0.1);
                    return true;
                case Gdk.Key.F11:
                    mi_full.activate();
                    return true;
            }
        }
        return false;
    });

    // Ctrl + kółko myszy = zoom czcionki
    terminal.add_events(Gdk.EventMask.SCROLL_MASK | Gdk.EventMask.SMOOTH_SCROLL_MASK);
    terminal.scroll_event.connect((ev) => {
        if ((ev.state & Gdk.ModifierType.CONTROL_MASK) == 0) return false;
        if (ev.direction == Gdk.ScrollDirection.UP) set_zoom(font_scale + 0.1);
        else if (ev.direction == Gdk.ScrollDirection.DOWN) set_zoom(font_scale - 0.1);
        else if (ev.direction == Gdk.ScrollDirection.SMOOTH)
            set_zoom(font_scale - ev.delta_y * 0.1);
        return true;
    });

    vbox.pack_start(terminal, true, true, 0);

    window.show_all();
    terminal.grab_focus();
    Gtk.main();
    return 0;
}
