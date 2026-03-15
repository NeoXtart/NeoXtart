module windows

$if windows {
    #include <windows.h>
}

pub struct WindowsLib {}

fn C.Beep(freq u32, duration u32) bool

pub fn (wl WindowsLib) beep(freq u32, duration u32) bool {
    return C.Beep(freq, duration)
}