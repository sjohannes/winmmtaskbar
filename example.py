#!/usr/bin/env python

from __future__ import print_function, unicode_literals

import ctypes

from gi.repository import GLib, Gtk
import winmmtaskbar

playing = False

def callback(button, hwnd):
    global playing
    print(button)
    if button == 1:
        playing = not playing
        winmmtaskbar.set_playing(hwnd, playing)

def main():
    Gtk.init()
    win = Gtk.Window()
    win.connect('destroy', Gtk.main_quit)
    win.show()

    hwnd = ctypes.WinDLL('libgdk-3-0.dll').gdk_win32_window_get_handle(
        hash(win.get_window()))
    winmmtaskbar.create_buttons(hwnd,
        "Previous", "Play", "Pause", "Next",
        callback, hwnd)

    Gtk.main()

if __name__ == '__main__':
    main()
