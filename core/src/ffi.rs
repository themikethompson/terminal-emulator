use crate::grid::{Cell, Color, NamedColor, Rgb};
use crate::terminal::Terminal;
use std::ffi::CStr;
use std::os::raw::c_char;
use std::slice;

/// C-compatible cell structure for FFI
#[repr(C)]
pub struct CCell {
    pub ch: u32, // Unicode codepoint
    pub fg_r: u8,
    pub fg_g: u8,
    pub fg_b: u8,
    pub bg_r: u8,
    pub bg_g: u8,
    pub bg_b: u8,
    pub flags: u8,
}

impl From<&Cell> for CCell {
    fn from(cell: &Cell) -> Self {
        let (fg_r, fg_g, fg_b) = color_to_rgb(&cell.fg);
        let (bg_r, bg_g, bg_b) = color_to_rgb(&cell.bg);

        CCell {
            ch: cell.c as u32,
            fg_r,
            fg_g,
            fg_b,
            bg_r,
            bg_g,
            bg_b,
            flags: cell.flags.0,
        }
    }
}

/// Convert Color to RGB tuple
fn color_to_rgb(color: &Color) -> (u8, u8, u8) {
    match color {
        Color::Spec(rgb) => (rgb.r, rgb.g, rgb.b),
        Color::Spec256(idx) => {
            // Convert 256 color palette to RGB (simplified)
            // This should use a proper color palette lookup
            let idx = *idx;
            if idx < 16 {
                // Standard colors
                named_color_to_rgb(idx as usize)
            } else if idx < 232 {
                // 216 color cube
                let idx = idx - 16;
                let r = ((idx / 36) * 51) as u8;
                let g = (((idx % 36) / 6) * 51) as u8;
                let b = ((idx % 6) * 51) as u8;
                (r, g, b)
            } else {
                // Grayscale
                let gray = ((idx - 232) * 10 + 8) as u8;
                (gray, gray, gray)
            }
        }
        Color::Named(named) => named_color_to_rgb(*named as usize),
    }
}

/// Convert named color to RGB
fn named_color_to_rgb(color: usize) -> (u8, u8, u8) {
    match color {
        0 => (0, 0, 0),         // Black
        1 => (205, 49, 49),     // Red
        2 => (13, 188, 121),    // Green
        3 => (229, 229, 16),    // Yellow
        4 => (36, 114, 200),    // Blue
        5 => (188, 63, 188),    // Magenta
        6 => (17, 168, 205),    // Cyan
        7 => (229, 229, 229),   // White
        8 => (102, 102, 102),   // Bright Black
        9 => (241, 76, 76),     // Bright Red
        10 => (35, 209, 139),   // Bright Green
        11 => (245, 245, 67),   // Bright Yellow
        12 => (59, 142, 234),   // Bright Blue
        13 => (214, 112, 214),  // Bright Magenta
        14 => (41, 184, 219),   // Bright Cyan
        15 => (255, 255, 255),  // Bright White
        16 => (200, 200, 200),  // Foreground
        17 => (20, 20, 20),     // Background
        _ => (200, 200, 200),
    }
}

/// Create a new terminal
#[unsafe(no_mangle)]
pub extern "C" fn terminal_new(rows: u16, cols: u16) -> *mut Terminal {
    let terminal = Terminal::new(rows as usize, cols as usize);
    Box::into_raw(Box::new(terminal))
}

/// Create a new terminal with PTY
#[unsafe(no_mangle)]
pub extern "C" fn terminal_new_with_pty(rows: u16, cols: u16) -> *mut Terminal {
    match Terminal::with_pty(rows as usize, cols as usize) {
        Ok(terminal) => Box::into_raw(Box::new(terminal)),
        Err(_) => std::ptr::null_mut(),
    }
}

/// Free a terminal
#[unsafe(no_mangle)]
pub extern "C" fn terminal_free(term: *mut Terminal) {
    if !term.is_null() {
        unsafe {
            let _ = Box::from_raw(term);
        }
    }
}

/// Process input bytes from PTY
#[unsafe(no_mangle)]
pub extern "C" fn terminal_process_bytes(term: *mut Terminal, data: *const u8, len: usize) {
    if term.is_null() || data.is_null() {
        return;
    }

    unsafe {
        let terminal = &mut *term;
        let bytes = slice::from_raw_parts(data, len);
        terminal.process_bytes(bytes);
    }
}

/// Send input to the PTY
#[unsafe(no_mangle)]
pub extern "C" fn terminal_send_input(term: *mut Terminal, data: *const u8, len: usize) -> i32 {
    if term.is_null() || data.is_null() {
        return -1;
    }

    unsafe {
        let terminal = &*term;
        let bytes = slice::from_raw_parts(data, len);
        match terminal.send_input(bytes) {
            Ok(_) => 0,
            Err(_) => -1,
        }
    }
}

/// Get a cell at the specified position
#[unsafe(no_mangle)]
pub extern "C" fn terminal_get_cell(term: *const Terminal, row: u16, col: u16) -> CCell {
    if term.is_null() {
        return CCell {
            ch: ' ' as u32,
            fg_r: 200,
            fg_g: 200,
            fg_b: 200,
            bg_r: 0,
            bg_g: 0,
            bg_b: 0,
            flags: 0,
        };
    }

    unsafe {
        let terminal = &*term;
        if let Some(cell) = terminal.grid.get_cell(row as usize, col as usize) {
            CCell::from(cell)
        } else {
            CCell {
                ch: ' ' as u32,
                fg_r: 200,
                fg_g: 200,
                fg_b: 200,
                bg_r: 0,
                bg_g: 0,
                bg_b: 0,
                flags: 0,
            }
        }
    }
}

/// Get all cells in a row (bulk operation for performance)
#[unsafe(no_mangle)]
pub extern "C" fn terminal_get_row(
    term: *const Terminal,
    row: u16,
    buffer: *mut CCell,
    buffer_len: usize,
) -> usize {
    if term.is_null() || buffer.is_null() {
        return 0;
    }

    unsafe {
        let terminal = &*term;
        let cells_buffer = slice::from_raw_parts_mut(buffer, buffer_len);

        if let Some(grid_row) = terminal.grid.rows.get(row as usize) {
            let count = grid_row.cells.len().min(buffer_len);
            for (i, cell) in grid_row.cells.iter().take(count).enumerate() {
                cells_buffer[i] = CCell::from(cell);
            }
            count
        } else {
            0
        }
    }
}

/// Get cursor position
#[unsafe(no_mangle)]
pub extern "C" fn terminal_get_cursor_row(term: *const Terminal) -> u16 {
    if term.is_null() {
        return 0;
    }
    unsafe { (*term).cursor.row as u16 }
}

#[unsafe(no_mangle)]
pub extern "C" fn terminal_get_cursor_col(term: *const Terminal) -> u16 {
    if term.is_null() {
        return 0;
    }
    unsafe { (*term).cursor.col as u16 }
}

/// Resize the terminal
#[unsafe(no_mangle)]
pub extern "C" fn terminal_resize(term: *mut Terminal, rows: u16, cols: u16) {
    if term.is_null() {
        return;
    }

    unsafe {
        let terminal = &mut *term;
        terminal.resize(rows as usize, cols as usize);
    }
}

/// Get dirty rows (rows that have changed)
#[unsafe(no_mangle)]
pub extern "C" fn terminal_get_dirty_rows(
    term: *const Terminal,
    buffer: *mut u16,
    buffer_len: usize,
) -> usize {
    if term.is_null() || buffer.is_null() {
        return 0;
    }

    unsafe {
        let terminal = &*term;
        let dirty_rows = terminal.grid.dirty_rows();
        let rows_buffer = slice::from_raw_parts_mut(buffer, buffer_len);

        let count = dirty_rows.len().min(buffer_len);
        for (i, &row) in dirty_rows.iter().take(count).enumerate() {
            rows_buffer[i] = row as u16;
        }
        count
    }
}

/// Mark all cells as clean
#[unsafe(no_mangle)]
pub extern "C" fn terminal_mark_clean(term: *mut Terminal) {
    if term.is_null() {
        return;
    }

    unsafe {
        let terminal = &mut *term;
        terminal.grid.mark_clean();
    }
}

/// Read from PTY (non-blocking)
#[unsafe(no_mangle)]
pub extern "C" fn terminal_read_pty(term: *mut Terminal, buffer: *mut u8, buffer_len: usize) -> isize {
    if term.is_null() || buffer.is_null() {
        return -1;
    }

    unsafe {
        let terminal = &mut *term;
        if let Some(ref pty) = terminal.pty {
            let buf = slice::from_raw_parts_mut(buffer, buffer_len);
            match pty.read(buf) {
                Ok(n) => n as isize,
                Err(_) => -1,
            }
        } else {
            -1
        }
    }
}

/// Get PTY master file descriptor (for select/poll)
#[unsafe(no_mangle)]
pub extern "C" fn terminal_get_pty_fd(term: *const Terminal) -> i32 {
    if term.is_null() {
        return -1;
    }

    unsafe {
        let terminal = &*term;
        if let Some(ref pty) = terminal.pty {
            pty.master_fd()
        } else {
            -1
        }
    }
}
