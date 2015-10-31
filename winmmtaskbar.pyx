# winmmtaskbar - Windows 7+ taskbar thumb buttons for multimedia apps
# Copyright (C) 2013-2015  Johannes Sasongko <sasongko@gmail.com>
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License as published by the Free Software Foundation; either
# version 2.1 of the License, or (at your option) any later version.
#
# This library is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public
# License along with this library; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA


# Build directives (do not remove):
#   distutils: language = c++
#   distutils: libraries = gdi32 ole32 user32

cdef extern from 'wchar.h':
    ctypedef Py_UNICODE wchar_t
    wchar_t *wcscpy(wchar_t *destination, const wchar_t *source)

cdef extern from 'windows.h':
    ctypedef bint BOOL
    ctypedef unsigned long DWORD
    ctypedef void *HANDLE
    ctypedef HANDLE HGDIOBJ
    ctypedef HANDLE HICON
    ctypedef long HRESULT
    ctypedef HANDLE HWND
    ctypedef long LONG_PTR
    ctypedef long *LPARAM
    ctypedef long LRESULT
    ctypedef Py_UNICODE WCHAR
    ctypedef unsigned short WORD
    ctypedef unsigned int *WPARAM

    BOOL DeleteObject(HGDIOBJ hObject)

    enum:
        WM_COMMAND
        WM_DESTROY
    cdef WORD LOWORD(void *l) nogil
    cdef WORD HIWORD(void *l) nogil
    ctypedef LRESULT (*WNDPROC)(HWND hwnd, unsigned int uMsg, WPARAM wParam, LPARAM lParam) nogil
    enum:
        GWLP_WNDPROC
    LONG_PTR SetWindowLongPtrW(HWND hWnd, int nIndex, LONG_PTR dwNewLong)

    enum:
        SM_CXICON
        SM_CYICON
    int GetSystemMetrics(int nIndex)

cdef extern from 'objbase.h':
    cppclass IUnknown:
        pass
    struct _GUID:
        pass
    ctypedef _GUID GUID
    HRESULT CoInitialize(void *pvReserved)
    HRESULT CoUninitialize()
    HRESULT CoCreateInstance(const GUID &rclsid, IUnknown *pUnkOuter, unsigned long dwClsContext, const GUID &riid, void **ppv)
    HRESULT CLSIDFromString(const WCHAR *lpsz, GUID *pclsid)

cdef extern from 'shobjidl.h':
    enum THUMBBUTTONMASK:
        THB_ICON
        THB_TOOLTIP
    struct THUMBBUTTON:
        THUMBBUTTONMASK dwMask
        unsigned int iId
        HICON hIcon
        WCHAR[260] szTip

    # NOTE: If using MinGW, which doesn't have this enum, replace with:
    #   DEF THBN_CLICKED = 0x1800
    enum:
        THBN_CLICKED

    cppclass ITaskbarList3:
        HRESULT HrInit()
        HRESULT ThumbBarAddButtons(HWND hwnd, unsigned int cButtons, THUMBBUTTON *pButton)
        HRESULT ThumbBarUpdateButtons(HWND hwnd, unsigned int cButtons, THUMBBUTTON *pButton)

# HACK: This fixes "uses undefined struct '_longobject'" build error, which is
# probably a Python bug.
cdef extern from 'longintrepr.h':
    pass

# HACK: VC9 doesn't have stdint.h so the following doesn't work:
#   from libc.stdint cimport intptr_t
ctypedef long long intptr_t


cdef class CoHelper:
    def __cinit__(self):
        CoInitialize(NULL)
    def __dealloc__(self):
        CoUninitialize()
cdef CoHelper co_helper = CoHelper()

cdef GUID CLSID_TaskbarList, IID_ITaskbarList3
CLSIDFromString(u'{56FDF344-FD6D-11d0-958A-006097C9A090}', &CLSID_TaskbarList)
CLSIDFromString(u'{ea1afb91-9e28-4b86-90e9-9e9f8a5eefaf}', &IID_ITaskbarList3)
DEF CLSCTX_ALL = 1 | 2 | 4 | 16

cdef ITaskbarList3 *taskbar
CoCreateInstance(CLSID_TaskbarList, NULL, CLSCTX_ALL, IID_ITaskbarList3, <void **> &taskbar)
assert(taskbar)
taskbar.HrInit()

cdef object play_icon, pause_icon
cdef dict oldwndprocs = {}
cdef dict callbacks = {}

cdef class Icon(long):
    cdef readonly unicode tooltip
    def __dealloc__(self):
        DeleteObject(<HGDIOBJ> self)

cdef tuple ICON_HELPER = None

cdef tuple icon_create_helper():
    """Return some functions and values that are constant and should be
    reused between icon_from_stock() calls"""
    import ctypes
    from gi.repository import GdkPixbuf, Gtk
    w, h = GetSystemMetrics(SM_CXICON), GetSystemMetrics(SM_CYICON)
    return (
        Gtk.IconTheme.get_default().lookup_icon,
        GdkPixbuf.Pixbuf.new_from_file_at_scale,
        # HACK: Private GDK function to convert from GdkPixbuf to HICON:
        # https://mail.gnome.org/archives/gtk-app-devel-list/2007-November/msg00055.html
        ctypes.WinDLL('libgdk-3-0.dll').gdk_win32_pixbuf_to_hicon_libgtk_only,
        w, h,
        max(w, h))

cdef Icon icon_from_stock(str name, unicode tooltip):
    global ICON_HELPER
    if ICON_HELPER is None:
        ICON_HELPER = icon_create_helper()
    lookup_icon, new_pixbuf, new_hicon, width, height, size = ICON_HELPER
    pb = new_pixbuf(
        lookup_icon(name, size, flags=0).get_filename(),
        width, height, preserve_aspect_ratio=False)
    icon = Icon(new_hicon(hash(pb)))
    if tooltip is not None:
        icon.tooltip = tooltip
    return icon

cdef do_create_buttons(HWND hwnd, unicode tooltip_prev, unicode tooltip_play, unicode tooltip_pause, unicode tooltip_next):
    global play_icon, pause_icon
    prev = icon_from_stock('media-skip-backward', None)
    play_icon = play = icon_from_stock('media-playback-start', tooltip_play)
    pause_icon = pause = icon_from_stock('media-playback-pause', tooltip_pause)
    next = icon_from_stock('media-skip-forward', None)

    # NOTE: We must use the <HICON> <intptr_t> double-cast so Cython uses the
    # numeric value stored in the Icon object rather than converting the object
    # pointer directly to HICON.
    cdef THUMBBUTTON[3] buttons
    buttons[0].iId = 0
    buttons[0].dwMask = <THUMBBUTTONMASK> (THB_ICON | THB_TOOLTIP)
    buttons[0].hIcon = <HICON> <intptr_t> prev
    wcscpy(buttons[0].szTip, tooltip_prev)
    buttons[1].iId = 1
    buttons[1].dwMask = <THUMBBUTTONMASK> (THB_ICON | THB_TOOLTIP)
    buttons[1].hIcon = <HICON> <intptr_t> play
    wcscpy(buttons[1].szTip, tooltip_play)
    buttons[2].iId = 2
    buttons[2].dwMask = <THUMBBUTTONMASK> (THB_ICON | THB_TOOLTIP)
    buttons[2].hIcon = <HICON> <intptr_t> next
    wcscpy(buttons[2].szTip, tooltip_next)

    taskbar.ThumbBarAddButtons(hwnd, 3, buttons)

cdef LRESULT wndproc(HWND hwnd, unsigned int uMsg, WPARAM wParam, LPARAM lParam) nogil:
    cdef WNDPROC oldwndproc
    with gil:
        oldwndproc = <WNDPROC> <intptr_t> oldwndprocs[<intptr_t> hwnd]
    if uMsg is WM_COMMAND:
        if HIWORD(wParam) is THBN_CLICKED:
            with gil:
                callback = callbacks.get(<intptr_t> hwnd)
                if callback:
                    callback[0](LOWORD(wParam), callback[1])
    elif uMsg is WM_DESTROY:
        with gil:
            del callbacks[<intptr_t> hwnd]
            del oldwndprocs[<intptr_t> hwnd]
    return oldwndproc(hwnd, uMsg, wParam, lParam)

def create_buttons(intptr_t hwnd,
        unicode tooltip_prev, unicode tooltip_play, unicode tooltip_pause, unicode tooltip_next,
        callback, cb_data=None):
    cdef HWND hwnd_ = <HWND> hwnd

    callbacks[hwnd] = (callback, cb_data)
    do_create_buttons(hwnd_, tooltip_prev, tooltip_play, tooltip_pause, tooltip_next)

    if hwnd not in oldwndprocs:
        oldwndprocs[hwnd] = SetWindowLongPtrW(hwnd_, GWLP_WNDPROC, <LONG_PTR> &wndproc)

def set_playing(intptr_t hwnd, bint playing):
    icon = pause_icon if playing else play_icon
    cdef THUMBBUTTON button
    button.dwMask = <THUMBBUTTONMASK> (THB_ICON | THB_TOOLTIP)
    button.iId = 1
    button.hIcon = <HICON> <intptr_t> icon
    wcscpy(button.szTip, icon.tooltip)
    taskbar.ThumbBarUpdateButtons(<HWND> hwnd, 1, &button)


# vi: et ft=python sts=4 sw=4 ts=4
