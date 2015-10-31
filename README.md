# winmmtaskbar

Windows 7+ taskbar thumb buttons for multimedia apps.

![Screenshot](https://cloud.githubusercontent.com/assets/8440927/10864106/5bbdc16c-802e-11e5-987b-be3526d0cc27.png)


## Building

1. Install [Microsoft Visual C++ Compiler for Python 2.7](https://www.microsoft.com/en-us/download/details.aspx?id=44266).
1. Install [Cython](http://cython.org/#download).
1. `setup.py build_ext`

You'll get a `.pyd` file somewhere in the `build` directory.


## Runtime dependencies

winmmtaskbar depends on GTK+ 3 to create the button icons, but it's pretty easy to modify the code to use other ways of creating these icons.
Patches to make this more general are welcome.


## Usage

Assume you have a `PLAYER` variable containing a media player with a few media-playery methods, a GObject-like signal system, and a `hwnd` attribute storing the main window handle.

```py
import winmmtaskbar

def on_taskbar_button_clicked(button, player):
    if button == 0:
        player.prev()
    elif button == 1:
        player.playpause()
    else:
        player.next()

winmmtaskbar.create_buttons(PLAYER.hwnd,
    u"Previous", u"Play", u"Pause", u"Next",
    on_taskbar_button_clicked, PLAYER)

PLAYER.connect('state-change', lambda is_playing:
    winmmtaskbar.set_playing(PLAYER.hwnd, is_playing))
```

The Windows API ([ITaskbarList3](https://msdn.microsoft.com/en-us/library/windows/desktop/dd391692(v=vs.85).aspx)) does not allow adding or removing taskbar buttons once they are set.
