#!/usr/bin/env python3
import sys

import gi

gi.require_version("Gtk", "3.0")
gi.require_version("GtkLayerShell", "0.1")
from gi.repository import GLib, Gtk, GtkLayerShell


label = sys.argv[1] if len(sys.argv) > 1 else "--"
subtitle = sys.argv[2] if len(sys.argv) > 2 else "Keyboard layout"

app = Gtk.Application(application_id="local.keyboard-layout-osd")


def on_activate(application):
    window = Gtk.ApplicationWindow(application=application)
    window.set_decorated(False)
    window.set_resizable(False)
    window.set_app_paintable(True)
    window.set_accept_focus(False)
    window.set_focus_on_map(False)
    window.set_skip_taskbar_hint(True)
    window.set_skip_pager_hint(True)
    window.set_visual(window.get_screen().get_rgba_visual())

    GtkLayerShell.init_for_window(window)
    GtkLayerShell.set_namespace(window, "keyboard-layout-osd")
    GtkLayerShell.set_layer(window, GtkLayerShell.Layer.OVERLAY)
    GtkLayerShell.set_keyboard_interactivity(window, False)

    css = b"""
    window {
      background: transparent;
    }

    .bubble {
      background: rgba(30, 30, 46, 0.94);
      border: 1px solid rgba(166, 173, 200, 0.45);
      border-radius: 18px;
      box-shadow: 0 18px 42px rgba(0, 0, 0, 0.35);
      padding: 20px 36px;
    }

    .layout {
      color: #cdd6f4;
      font-family: "JetBrainsMono Nerd Font", monospace;
      font-size: 42px;
      font-weight: 800;
      letter-spacing: 0;
    }

    .subtitle {
      color: #a6adc8;
      font-family: "JetBrainsMono Nerd Font", monospace;
      font-size: 13px;
      font-weight: 700;
      margin-top: 2px;
    }
    """

    provider = Gtk.CssProvider()
    provider.load_from_data(css)
    Gtk.StyleContext.add_provider_for_screen(
        window.get_screen(),
        provider,
        Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION,
    )

    box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
    box.get_style_context().add_class("bubble")

    layout_label = Gtk.Label(label=f"󰌌 {label}")
    layout_label.get_style_context().add_class("layout")

    subtitle_label = Gtk.Label(label=subtitle)
    subtitle_label.get_style_context().add_class("subtitle")

    box.pack_start(layout_label, False, False, 0)
    box.pack_start(subtitle_label, False, False, 0)

    window.add(box)
    window.show_all()

    GLib.timeout_add(900, application.quit)


app.connect("activate", on_activate)
raise SystemExit(app.run([]))
