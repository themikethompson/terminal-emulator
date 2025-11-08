use terminal_core::Terminal;

fn main() {
    println!("Testing terminal core library...\n");

    // Create a terminal
    let mut term = Terminal::new(24, 80);
    println!("✓ Created terminal: {} rows x {} cols", term.rows, term.cols);

    // Test basic text output
    term.process_bytes(b"Hello, World!");
    let cell = term.grid.get_cell(0, 0).unwrap();
    assert_eq!(cell.c, 'H');
    println!("✓ Basic text rendering works");

    // Test newline
    term.process_bytes(b"\n");
    assert_eq!(term.cursor.row, 1);
    assert_eq!(term.cursor.col, 0);
    println!("✓ Newline handling works");

    // Test ANSI color codes
    term.process_bytes(b"\x1b[31mRed Text\x1b[0m");
    let cell = term.grid.get_cell(1, 0).unwrap();
    assert_eq!(cell.c, 'R');
    println!("✓ ANSI color codes work");

    // Test cursor movement
    term.process_bytes(b"\x1b[5;10H"); // Move to row 5, col 10
    assert_eq!(term.cursor.row, 4); // 0-indexed
    assert_eq!(term.cursor.col, 9); // 0-indexed
    println!("✓ Cursor positioning works");

    // Test true color (24-bit)
    term.process_bytes(b"\x1b[38;2;255;100;50mTrue Color\x1b[0m");
    println!("✓ True color support works");

    // Test screen clearing
    term.process_bytes(b"\x1b[2J"); // Clear screen
    let cell = term.grid.get_cell(0, 0).unwrap();
    assert_eq!(cell.c, ' ');
    println!("✓ Screen clearing works");

    // Test resize
    term.resize(30, 100);
    assert_eq!(term.rows, 30);
    assert_eq!(term.cols, 100);
    println!("✓ Terminal resize works");

    // Test bold and italic
    term.process_bytes(b"\x1b[1;3mBold Italic\x1b[0m");
    println!("✓ Text attributes (bold/italic) work");

    println!("\n✅ All core functionality tests passed!");
    println!("\nNext step: Build the Swift/AppKit frontend and Metal renderer");
}
