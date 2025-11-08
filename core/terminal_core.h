#ifndef TERMINAL_CORE_H
#define TERMINAL_CORE_H

#include <stdint.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

// Opaque terminal handle
typedef struct Terminal Terminal;

// Cell structure for FFI
typedef struct {
    uint32_t ch;      // Unicode codepoint
    uint8_t fg_r;     // Foreground red
    uint8_t fg_g;     // Foreground green
    uint8_t fg_b;     // Foreground blue
    uint8_t bg_r;     // Background red
    uint8_t bg_g;     // Background green
    uint8_t bg_b;     // Background blue
    uint8_t flags;    // Text attributes (bold, italic, etc.)
} CCell;

// Cell flag constants
#define CELL_FLAG_BOLD          0x01
#define CELL_FLAG_ITALIC        0x02
#define CELL_FLAG_UNDERLINE     0x04
#define CELL_FLAG_BLINK         0x08
#define CELL_FLAG_INVERSE       0x10
#define CELL_FLAG_STRIKETHROUGH 0x20

// Create a new terminal
Terminal* terminal_new(uint16_t rows, uint16_t cols);

// Create a new terminal with PTY (spawns shell)
Terminal* terminal_new_with_pty(uint16_t rows, uint16_t cols);

// Free a terminal
void terminal_free(Terminal* term);

// Process bytes from PTY (parse ANSI sequences and update grid)
void terminal_process_bytes(Terminal* term, const uint8_t* data, size_t len);

// Send input to the PTY (keyboard input, etc.)
int terminal_send_input(Terminal* term, const uint8_t* data, size_t len);

// Get a single cell at position
CCell terminal_get_cell(const Terminal* term, uint16_t row, uint16_t col);

// Get all cells in a row (bulk operation for performance)
size_t terminal_get_row(const Terminal* term, uint16_t row, CCell* buffer, size_t buffer_len);

// Get cursor position
uint16_t terminal_get_cursor_row(const Terminal* term);
uint16_t terminal_get_cursor_col(const Terminal* term);

// Resize the terminal
void terminal_resize(Terminal* term, uint16_t rows, uint16_t cols);

// Get dirty rows (rows that have changed since last mark_clean)
size_t terminal_get_dirty_rows(const Terminal* term, uint16_t* buffer, size_t buffer_len);

// Mark all cells as clean (call after rendering)
void terminal_mark_clean(Terminal* term);

// Read from PTY (non-blocking, returns -1 on error, bytes read otherwise)
ssize_t terminal_read_pty(Terminal* term, uint8_t* buffer, size_t buffer_len);

// Get PTY master file descriptor (for select/poll)
int terminal_get_pty_fd(const Terminal* term);

#ifdef __cplusplus
}
#endif

#endif // TERMINAL_CORE_H
