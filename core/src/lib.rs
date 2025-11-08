pub mod ffi;
pub mod grid;
pub mod parser;
pub mod pty;
pub mod terminal;

// Re-export main types for convenience
pub use grid::{Cell, Color, Grid, NamedColor, Rgb};
pub use terminal::Terminal;
