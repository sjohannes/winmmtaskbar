==============
 winmmtaskbar
==============

Windows 7+ taskbar thumb buttons for multimedia apps.

.. image::
   https://cloud.githubusercontent.com/assets/8440927/10864106/5bbdc16c-802e-11e5-987b-be3526d0cc27.png


Download
========

`Development builds <https://ci.appveyor.com/project/sjohannes/winmmtaskbar/build/artifacts>`_


Building
========

1. Install the right compiler for your Python version. For example:

   - For Python 2.7, install `Microsoft Visual C++ Compiler for Python 2.7`_.
   - For Python 3.5, install `Visual Studio Community 2015`_.

2. Install Cython_ (``pip install Cython`` works).

3. ``setup.py build_ext``

You'll get a ``.pyd`` file somewhere in the ``build`` directory.

.. _Microsoft Visual C++ Compiler for Python 2.7:
   https://download.microsoft.com/download/7/9/6/796EF2E4-801B-4FC4-AB28-B59FBF6D907B/VCForPython27.msi
.. _Visual Studio Community 2015:
   http://download.microsoft.com/download/0/B/C/0BC321A4-013F-479C-84E6-4A2F90B11269/vs_community.exe
.. _Cython: http://cython.org/#download


Runtime dependencies
====================

winmmtaskbar depends on GTK+ 3 to create the button icons, but it's pretty easy
to modify the code to use other ways of creating these icons.
Patches to make this more general are welcome.


Usage
=====

Assume you have a ``PLAYER`` variable containing a media player with a few
media-playery methods, a GObject-like signal system, and a ``hwnd`` attribute
storing the main window handle. ::

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

The Windows API (ITaskbarList3_) does not allow adding or removing taskbar
buttons once they are set.

.. _ITaskbarList3:
   https://msdn.microsoft.com/en-us/library/windows/desktop/dd391692(v=vs.85).aspx
