use crate::grid::{CellFlags, Color, Grid, NamedColor, Rgb};
use crate::parser::{params_to_vec, AnsiParser};
use crate::pty::Pty;
use vte::{Params, Perform};

/// Cursor position and style
#[derive(Debug, Clone)]
pub struct Cursor {
    pub row: usize,
    pub col: usize,
    pub fg: Color,
    pub bg: Color,
    pub flags: CellFlags,
}

impl Cursor {
    pub fn new() -> Self {
        Self {
            row: 0,
            col: 0,
            fg: Color::Named(NamedColor::Foreground),
            bg: Color::Named(NamedColor::Background),
            flags: CellFlags::new(),
        }
    }

    pub fn reset_style(&mut self) {
        self.fg = Color::Named(NamedColor::Foreground);
        self.bg = Color::Named(NamedColor::Background);
        self.flags = CellFlags::new();
    }
}

impl Default for Cursor {
    fn default() -> Self {
        Self::new()
    }
}

/// Terminal emulator state
pub struct Terminal {
    pub grid: Grid,
    pub cursor: Cursor,
    pub saved_cursor: Option<Cursor>,
    parser: AnsiParser,
    pub pty: Option<Pty>,
    pub rows: usize,
    pub cols: usize,
}

impl Terminal {
    pub fn new(rows: usize, cols: usize) -> Self {
        Self {
            grid: Grid::new(rows, cols, 10000),
            cursor: Cursor::new(),
            saved_cursor: None,
            parser: AnsiParser::new(),
            pty: None,
            rows,
            cols,
        }
    }

    /// Initialize with PTY
    pub fn with_pty(rows: usize, cols: usize) -> std::io::Result<Self> {
        let mut pty = Pty::new(cols as u16, rows as u16)?;
        pty.spawn_shell(None)?;

        Ok(Self {
            grid: Grid::new(rows, cols, 10000),
            cursor: Cursor::new(),
            saved_cursor: None,
            parser: AnsiParser::new(),
            pty: Some(pty),
            rows,
            cols,
        })
    }

    /// Process incoming bytes from PTY
    pub fn process_bytes(&mut self, bytes: &[u8]) {
        let mut parser = std::mem::replace(&mut self.parser, AnsiParser::new());
        for &byte in bytes {
            parser.advance(self, byte);
        }
        self.parser = parser;
    }

    /// Write a character at the current cursor position
    fn write_char(&mut self, c: char) {
        // Handle special characters
        match c {
            '\r' => {
                self.cursor.col = 0;
                return;
            }
            '\n' => {
                self.newline();
                return;
            }
            '\t' => {
                // Tab to next 8-column boundary
                self.cursor.col = ((self.cursor.col / 8) + 1) * 8;
                if self.cursor.col >= self.cols {
                    self.cursor.col = self.cols - 1;
                }
                return;
            }
            '\x08' => {
                // Backspace
                if self.cursor.col > 0 {
                    self.cursor.col -= 1;
                }
                return;
            }
            _ => {}
        }

        // Write printable character
        if let Some(cell) = self.grid.get_cell_mut(self.cursor.row, self.cursor.col) {
            cell.c = c;
            cell.fg = self.cursor.fg;
            cell.bg = self.cursor.bg;
            cell.flags = self.cursor.flags;
        }

        // Advance cursor
        self.cursor.col += 1;

        // Wrap to next line if needed
        if self.cursor.col >= self.cols {
            self.newline();
        }
    }

    /// Move to new line
    fn newline(&mut self) {
        self.cursor.col = 0;
        self.cursor.row += 1;

        // Scroll if at bottom
        if self.cursor.row >= self.rows {
            self.grid.scroll_up();
            self.cursor.row = self.rows - 1;
        }
    }

    /// Handle SGR (Select Graphic Rendition) parameters
    fn handle_sgr(&mut self, params: &[i64]) {
        if params.is_empty() {
            // Reset
            self.cursor.reset_style();
            return;
        }

        let mut i = 0;
        while i < params.len() {
            match params[i] {
                0 => self.cursor.reset_style(),
                1 => self.cursor.flags.set(CellFlags::BOLD, true),
                3 => self.cursor.flags.set(CellFlags::ITALIC, true),
                4 => self.cursor.flags.set(CellFlags::UNDERLINE, true),
                5 => self.cursor.flags.set(CellFlags::BLINK, true),
                7 => self.cursor.flags.set(CellFlags::INVERSE, true),
                9 => self.cursor.flags.set(CellFlags::STRIKETHROUGH, true),
                22 => self.cursor.flags.set(CellFlags::BOLD, false),
                23 => self.cursor.flags.set(CellFlags::ITALIC, false),
                24 => self.cursor.flags.set(CellFlags::UNDERLINE, false),
                25 => self.cursor.flags.set(CellFlags::BLINK, false),
                27 => self.cursor.flags.set(CellFlags::INVERSE, false),
                29 => self.cursor.flags.set(CellFlags::STRIKETHROUGH, false),
                // Foreground colors (30-37)
                30..=37 => {
                    let color = match params[i] - 30 {
                        0 => NamedColor::Black,
                        1 => NamedColor::Red,
                        2 => NamedColor::Green,
                        3 => NamedColor::Yellow,
                        4 => NamedColor::Blue,
                        5 => NamedColor::Magenta,
                        6 => NamedColor::Cyan,
                        7 => NamedColor::White,
                        _ => NamedColor::Foreground,
                    };
                    self.cursor.fg = Color::Named(color);
                }
                // Background colors (40-47)
                40..=47 => {
                    let color = match params[i] - 40 {
                        0 => NamedColor::Black,
                        1 => NamedColor::Red,
                        2 => NamedColor::Green,
                        3 => NamedColor::Yellow,
                        4 => NamedColor::Blue,
                        5 => NamedColor::Magenta,
                        6 => NamedColor::Cyan,
                        7 => NamedColor::White,
                        _ => NamedColor::Background,
                    };
                    self.cursor.bg = Color::Named(color);
                }
                // 256 color or true color
                38 => {
                    // Foreground
                    if i + 2 < params.len() && params[i + 1] == 5 {
                        // 256 color: ESC[38;5;<n>m
                        self.cursor.fg = Color::Spec256(params[i + 2] as u8);
                        i += 2;
                    } else if i + 4 < params.len() && params[i + 1] == 2 {
                        // True color: ESC[38;2;<r>;<g>;<b>m
                        let r = params[i + 2] as u8;
                        let g = params[i + 3] as u8;
                        let b = params[i + 4] as u8;
                        self.cursor.fg = Color::Spec(Rgb::new(r, g, b));
                        i += 4;
                    }
                }
                48 => {
                    // Background
                    if i + 2 < params.len() && params[i + 1] == 5 {
                        // 256 color
                        self.cursor.bg = Color::Spec256(params[i + 2] as u8);
                        i += 2;
                    } else if i + 4 < params.len() && params[i + 1] == 2 {
                        // True color
                        let r = params[i + 2] as u8;
                        let g = params[i + 3] as u8;
                        let b = params[i + 4] as u8;
                        self.cursor.bg = Color::Spec(Rgb::new(r, g, b));
                        i += 4;
                    }
                }
                // Bright foreground colors (90-97)
                90..=97 => {
                    let color = match params[i] - 90 {
                        0 => NamedColor::BrightBlack,
                        1 => NamedColor::BrightRed,
                        2 => NamedColor::BrightGreen,
                        3 => NamedColor::BrightYellow,
                        4 => NamedColor::BrightBlue,
                        5 => NamedColor::BrightMagenta,
                        6 => NamedColor::BrightCyan,
                        7 => NamedColor::BrightWhite,
                        _ => NamedColor::Foreground,
                    };
                    self.cursor.fg = Color::Named(color);
                }
                // Bright background colors (100-107)
                100..=107 => {
                    let color = match params[i] - 100 {
                        0 => NamedColor::BrightBlack,
                        1 => NamedColor::BrightRed,
                        2 => NamedColor::BrightGreen,
                        3 => NamedColor::BrightYellow,
                        4 => NamedColor::BrightBlue,
                        5 => NamedColor::BrightMagenta,
                        6 => NamedColor::BrightCyan,
                        7 => NamedColor::BrightWhite,
                        _ => NamedColor::Background,
                    };
                    self.cursor.bg = Color::Named(color);
                }
                _ => {
                    // Unknown SGR parameter
                }
            }
            i += 1;
        }
    }

    /// Resize the terminal
    pub fn resize(&mut self, rows: usize, cols: usize) {
        self.rows = rows;
        self.cols = cols;
        self.grid.resize(rows, cols);

        // Resize PTY if present
        if let Some(ref pty) = self.pty {
            let _ = pty.resize(cols as u16, rows as u16);
        }

        // Ensure cursor is in bounds
        if self.cursor.row >= rows {
            self.cursor.row = rows - 1;
        }
        if self.cursor.col >= cols {
            self.cursor.col = cols - 1;
        }
    }

    /// Get the current grid state
    pub fn get_grid(&self) -> &Grid {
        &self.grid
    }

    /// Send input to the PTY
    pub fn send_input(&self, data: &[u8]) -> std::io::Result<()> {
        if let Some(ref pty) = self.pty {
            pty.write(data)?;
        }
        Ok(())
    }
}

impl Perform for Terminal {
    fn print(&mut self, c: char) {
        self.write_char(c);
    }

    fn execute(&mut self, byte: u8) {
        match byte {
            b'\n' => self.newline(),
            b'\r' => self.cursor.col = 0,
            b'\t' => self.write_char('\t'),
            b'\x08' => self.write_char('\x08'),
            _ => {}
        }
    }

    fn hook(&mut self, _params: &Params, _intermediates: &[u8], _ignore: bool, _c: char) {}

    fn put(&mut self, _byte: u8) {}

    fn unhook(&mut self) {}

    fn osc_dispatch(&mut self, _params: &[&[u8]], _bell_terminated: bool) {
        // Handle OSC sequences (window title, etc.)
    }

    fn csi_dispatch(&mut self, params: &Params, _intermediates: &[u8], _ignore: bool, c: char) {
        let params = params_to_vec(params);

        match c {
            'A' => {
                // Cursor Up
                let n = params.get(0).copied().unwrap_or(1).max(1) as usize;
                self.cursor.row = self.cursor.row.saturating_sub(n);
            }
            'B' => {
                // Cursor Down
                let n = params.get(0).copied().unwrap_or(1).max(1) as usize;
                self.cursor.row = (self.cursor.row + n).min(self.rows - 1);
            }
            'C' => {
                // Cursor Forward
                let n = params.get(0).copied().unwrap_or(1).max(1) as usize;
                self.cursor.col = (self.cursor.col + n).min(self.cols - 1);
            }
            'D' => {
                // Cursor Backward
                let n = params.get(0).copied().unwrap_or(1).max(1) as usize;
                self.cursor.col = self.cursor.col.saturating_sub(n);
            }
            'H' | 'f' => {
                // Cursor Position
                let row = params.get(0).copied().unwrap_or(1).max(1) as usize - 1;
                let col = params.get(1).copied().unwrap_or(1).max(1) as usize - 1;
                self.cursor.row = row.min(self.rows - 1);
                self.cursor.col = col.min(self.cols - 1);
            }
            'J' => {
                // Erase in Display
                let mode = params.get(0).copied().unwrap_or(0);
                match mode {
                    0 => {
                        // Clear from cursor to end
                        self.grid.clear_to_end(self.cursor.row, self.cursor.col);
                    }
                    1 => {
                        // Clear from start to cursor
                        self.grid.clear_from_start(self.cursor.row, self.cursor.col);
                    }
                    2 | 3 => {
                        // Clear entire screen
                        self.grid.clear();
                    }
                    _ => {}
                }
            }
            'K' => {
                // Erase in Line
                let mode = params.get(0).copied().unwrap_or(0);
                if let Some(row) = self.grid.rows.get_mut(self.cursor.row) {
                    match mode {
                        0 => {
                            // Clear from cursor to end of line
                            for col in self.cursor.col..self.cols {
                                if let Some(cell) = row.cells.get_mut(col) {
                                    cell.reset();
                                }
                            }
                        }
                        1 => {
                            // Clear from start of line to cursor
                            for col in 0..=self.cursor.col {
                                if let Some(cell) = row.cells.get_mut(col) {
                                    cell.reset();
                                }
                            }
                        }
                        2 => {
                            // Clear entire line
                            row.clear();
                        }
                        _ => {}
                    }
                    row.dirty = true;
                }
            }
            'm' => {
                // SGR - Select Graphic Rendition
                self.handle_sgr(&params);
            }
            's' => {
                // Save cursor position
                self.saved_cursor = Some(self.cursor.clone());
            }
            'u' => {
                // Restore cursor position
                if let Some(saved) = &self.saved_cursor {
                    self.cursor = saved.clone();
                }
            }
            _ => {
                // Unhandled CSI sequence
            }
        }
    }

    fn esc_dispatch(&mut self, _intermediates: &[u8], _ignore: bool, _byte: u8) {
        // Handle ESC sequences
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_terminal_creation() {
        let term = Terminal::new(24, 80);
        assert_eq!(term.rows, 24);
        assert_eq!(term.cols, 80);
    }

    #[test]
    fn test_write_text() {
        let mut term = Terminal::new(24, 80);
        term.process_bytes(b"Hello");

        assert_eq!(term.grid.get_cell(0, 0).unwrap().c, 'H');
        assert_eq!(term.grid.get_cell(0, 4).unwrap().c, 'o');
    }

    #[test]
    fn test_color_codes() {
        let mut term = Terminal::new(24, 80);
        // Red text
        term.process_bytes(b"\x1b[31mRed\x1b[0m");

        assert_eq!(term.grid.get_cell(0, 0).unwrap().c, 'R');
        assert_eq!(
            term.grid.get_cell(0, 0).unwrap().fg,
            Color::Named(NamedColor::Red)
        );
    }
}
