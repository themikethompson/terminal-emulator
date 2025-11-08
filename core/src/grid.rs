use serde::{Deserialize, Serialize};

/// RGB color representation
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub struct Rgb {
    pub r: u8,
    pub g: u8,
    pub b: u8,
}

impl Rgb {
    pub fn new(r: u8, g: u8, b: u8) -> Self {
        Self { r, g, b }
    }
}

/// Named ANSI colors (0-15)
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum NamedColor {
    Black = 0,
    Red,
    Green,
    Yellow,
    Blue,
    Magenta,
    Cyan,
    White,
    BrightBlack,
    BrightRed,
    BrightGreen,
    BrightYellow,
    BrightBlue,
    BrightMagenta,
    BrightCyan,
    BrightWhite,
    Foreground,
    Background,
}

/// Terminal color specification
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum Color {
    Named(NamedColor),
    Spec256(u8),
    Spec(Rgb),
}

impl Default for Color {
    fn default() -> Self {
        Color::Named(NamedColor::Foreground)
    }
}

/// Cell flags for text attributes
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub struct CellFlags(pub u8);

impl CellFlags {
    pub const BOLD: u8 = 0b0000_0001;
    pub const ITALIC: u8 = 0b0000_0010;
    pub const UNDERLINE: u8 = 0b0000_0100;
    pub const BLINK: u8 = 0b0000_1000;
    pub const INVERSE: u8 = 0b0001_0000;
    pub const STRIKETHROUGH: u8 = 0b0010_0000;

    pub fn new() -> Self {
        Self(0)
    }

    pub fn set(&mut self, flag: u8, enabled: bool) {
        if enabled {
            self.0 |= flag;
        } else {
            self.0 &= !flag;
        }
    }

    pub fn contains(&self, flag: u8) -> bool {
        self.0 & flag != 0
    }

    pub fn is_bold(&self) -> bool {
        self.contains(Self::BOLD)
    }

    pub fn is_italic(&self) -> bool {
        self.contains(Self::ITALIC)
    }

    pub fn is_underline(&self) -> bool {
        self.contains(Self::UNDERLINE)
    }
}

impl Default for CellFlags {
    fn default() -> Self {
        Self::new()
    }
}

/// A single cell in the terminal grid
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct Cell {
    pub c: char,
    pub fg: Color,
    pub bg: Color,
    pub flags: CellFlags,
}

impl Cell {
    pub fn new(c: char) -> Self {
        Self {
            c,
            fg: Color::default(),
            bg: Color::Named(NamedColor::Background),
            flags: CellFlags::new(),
        }
    }

    pub fn reset(&mut self) {
        self.c = ' ';
        self.fg = Color::default();
        self.bg = Color::Named(NamedColor::Background);
        self.flags = CellFlags::new();
    }
}

impl Default for Cell {
    fn default() -> Self {
        Self::new(' ')
    }
}

/// A row of cells
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Row {
    pub cells: Vec<Cell>,
    pub dirty: bool,
}

impl Row {
    pub fn new(cols: usize) -> Self {
        Self {
            cells: vec![Cell::default(); cols],
            dirty: true,
        }
    }

    pub fn clear(&mut self) {
        for cell in &mut self.cells {
            cell.reset();
        }
        self.dirty = true;
    }

    pub fn resize(&mut self, cols: usize) {
        self.cells.resize(cols, Cell::default());
        self.dirty = true;
    }
}

/// The terminal grid
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Grid {
    pub rows: Vec<Row>,
    pub cols: usize,
    pub scrollback: Vec<Row>,
    pub max_scrollback: usize,
}

impl Grid {
    pub fn new(rows: usize, cols: usize, max_scrollback: usize) -> Self {
        Self {
            rows: (0..rows).map(|_| Row::new(cols)).collect(),
            cols,
            scrollback: Vec::new(),
            max_scrollback,
        }
    }

    /// Get a cell at the specified position
    pub fn get_cell(&self, row: usize, col: usize) -> Option<&Cell> {
        self.rows.get(row).and_then(|r| r.cells.get(col))
    }

    /// Get a mutable cell at the specified position
    pub fn get_cell_mut(&mut self, row: usize, col: usize) -> Option<&mut Cell> {
        if let Some(r) = self.rows.get_mut(row) {
            r.dirty = true;
            r.cells.get_mut(col)
        } else {
            None
        }
    }

    /// Scroll up by one line (move top line to scrollback)
    pub fn scroll_up(&mut self) {
        if let Some(row) = self.rows.first() {
            // Add to scrollback
            self.scrollback.push(row.clone());

            // Limit scrollback size
            if self.scrollback.len() > self.max_scrollback {
                self.scrollback.remove(0);
            }
        }

        // Shift all rows up
        self.rows.remove(0);
        self.rows.push(Row::new(self.cols));
    }

    /// Scroll down by one line
    pub fn scroll_down(&mut self) {
        if let Some(row) = self.scrollback.pop() {
            self.rows.insert(0, row);
            self.rows.pop();
        }
    }

    /// Clear the entire grid
    pub fn clear(&mut self) {
        for row in &mut self.rows {
            row.clear();
        }
    }

    /// Clear from cursor to end of screen
    pub fn clear_to_end(&mut self, start_row: usize, start_col: usize) {
        // Clear from cursor to end of current row
        if let Some(row) = self.rows.get_mut(start_row) {
            for col in start_col..self.cols {
                if let Some(cell) = row.cells.get_mut(col) {
                    cell.reset();
                }
            }
            row.dirty = true;
        }

        // Clear all rows below
        for row_idx in (start_row + 1)..self.rows.len() {
            self.rows[row_idx].clear();
        }
    }

    /// Clear from beginning of screen to cursor
    pub fn clear_from_start(&mut self, end_row: usize, end_col: usize) {
        // Clear all rows before
        for row_idx in 0..end_row {
            self.rows[row_idx].clear();
        }

        // Clear from start of current row to cursor
        if let Some(row) = self.rows.get_mut(end_row) {
            for col in 0..=end_col.min(self.cols - 1) {
                if let Some(cell) = row.cells.get_mut(col) {
                    cell.reset();
                }
            }
            row.dirty = true;
        }
    }

    /// Resize the grid
    pub fn resize(&mut self, new_rows: usize, new_cols: usize) {
        // Resize columns first
        if new_cols != self.cols {
            for row in &mut self.rows {
                row.resize(new_cols);
            }
            self.cols = new_cols;
        }

        // Resize rows
        if new_rows > self.rows.len() {
            // Add rows
            while self.rows.len() < new_rows {
                self.rows.push(Row::new(self.cols));
            }
        } else if new_rows < self.rows.len() {
            // Remove rows (move to scrollback)
            while self.rows.len() > new_rows {
                if let Some(row) = self.rows.first() {
                    self.scrollback.push(row.clone());
                }
                self.rows.remove(0);
            }
        }
    }

    /// Mark all cells as clean (not dirty)
    pub fn mark_clean(&mut self) {
        for row in &mut self.rows {
            row.dirty = false;
        }
    }

    /// Get dirty rows (rows that have changed)
    pub fn dirty_rows(&self) -> Vec<usize> {
        self.rows
            .iter()
            .enumerate()
            .filter_map(|(idx, row)| if row.dirty { Some(idx) } else { None })
            .collect()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_grid_creation() {
        let grid = Grid::new(24, 80, 1000);
        assert_eq!(grid.rows.len(), 24);
        assert_eq!(grid.cols, 80);
    }

    #[test]
    fn test_cell_access() {
        let mut grid = Grid::new(24, 80, 1000);
        if let Some(cell) = grid.get_cell_mut(0, 0) {
            cell.c = 'A';
        }
        assert_eq!(grid.get_cell(0, 0).unwrap().c, 'A');
    }

    #[test]
    fn test_scroll_up() {
        let mut grid = Grid::new(3, 10, 1000);
        if let Some(cell) = grid.get_cell_mut(0, 0) {
            cell.c = 'X';
        }

        grid.scroll_up();

        assert_eq!(grid.scrollback.len(), 1);
        assert_eq!(grid.scrollback[0].cells[0].c, 'X');
    }
}
