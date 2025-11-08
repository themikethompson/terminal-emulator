# macOS Terminal Emulator

A high-performance, full-featured terminal emulator for macOS built with Rust core and Swift/AppKit frontend.

## Architecture

```
┌─────────────────────────────────────┐
│   Swift/AppKit Frontend (macOS)     │
│  - NSWindow & NSViewController      │
│  - Metal Rendering Pipeline         │
│  - Event Handling                   │
│  - UI Controls                      │
└──────────────┬──────────────────────┘
               │ FFI Bridge (C ABI)
┌──────────────┴──────────────────────┐
│   Rust Core Library (terminal_core) │
│  - Terminal State Machine           │
│  - PTY Management                   │
│  - ANSI/VTE Parser                  │
│  - Grid & Cell Management           │
└─────────────────────────────────────┘
```

## Project Status

### ✅ Phase 1: Core Foundation (COMPLETE)

The Rust core library is fully implemented and tested with the following features:

**Implemented:**
- ✅ PTY (Pseudoterminal) handling with process spawning
- ✅ ANSI escape sequence parsing (vte parser)
- ✅ Terminal grid and cell management
- ✅ Cursor positioning and movement
- ✅ Text attributes (bold, italic, underline, etc.)
- ✅ 16 named colors (ANSI)
- ✅ 256 color palette support
- ✅ True color (24-bit RGB) support
- ✅ Screen clearing and scrolling
- ✅ Scrollback buffer (10,000 lines)
- ✅ Terminal resizing
- ✅ C FFI bindings for Swift
- ✅ Damage tracking (dirty rows optimization)
- ✅ All core tests passing

### ✅ Phase 2: Swift Frontend (COMPLETE)

The macOS native application is fully scaffolded and functional:

**Implemented:**
- ✅ Xcode project with build configuration
- ✅ Swift FFI wrapper around Rust core (`TerminalCore.swift`)
- ✅ AppDelegate and WindowController
- ✅ TerminalViewController with lifecycle management
- ✅ TerminalView with text rendering (NSAttributedString)
- ✅ Keyboard input handling (arrows, control keys, special keys)
- ✅ Async PTY monitoring with GCD DispatchSource
- ✅ Automatic terminal resizing
- ✅ Blinking cursor
- ✅ Paste support (Cmd+V)
- ✅ Color rendering (16 named + 256 + true color)
- ✅ Text attributes (bold, italic, underline)
- ✅ Automated Rust library build integration

**App is functional!** You can:
- Open terminal window
- Type commands and see output
- Use arrows and control keys
- Resize the window
- Paste text
- See colored output

### 🚧 Phase 3-10: Planned

The following phases are next:

3. **Metal Rendering** - GPU pipeline, glyph cache, shaders
4. **Advanced Graphics** - Ligatures, blur/transparency
5. **Window Management** - Tabs, splits, selection/copy
6. **Session Persistence** - Save/restore terminal state
7. **Plugin System** - WASM runtime, plugin API
8. **AI Integration** - LLM client, command suggestions
9. **Configuration** - Settings UI, themes, keybindings
10. **Polish & Testing** - Performance, docs, release

## Building the Project

### Requirements

- **Rust** 1.91+ (installed via rustup)
- **macOS** 13.0+
- **Xcode** 14.0+
- **Command Line Tools** for Xcode

### Build Core Library

```bash
cd core
cargo build --release
```

### Build macOS App

**Option 1: Using Xcode**
```bash
cd macos/TerminalEmulator
open TerminalEmulator.xcodeproj
# Press Cmd+R to build and run
```

**Option 2: Command Line**
```bash
cd macos/TerminalEmulator
xcodebuild -project TerminalEmulator.xcodeproj -scheme TerminalEmulator build
```

The Xcode build will automatically compile the Rust library via `build_rust.sh`.

See [macos/BUILD_GUIDE.md](macos/BUILD_GUIDE.md) for detailed instructions.

### Run Tests

```bash
cd core
cargo test
cargo run --example basic_test
```

## Core Library API

The core library exposes a C-compatible API that can be used from Swift:

```c
// Create terminal with PTY
Terminal* term = terminal_new_with_pty(24, 80);

// Read from PTY
uint8_t buffer[4096];
ssize_t n = terminal_read_pty(term, buffer, sizeof(buffer));

// Process output
terminal_process_bytes(term, buffer, n);

// Get cell for rendering
CCell cell = terminal_get_cell(term, row, col);

// Send keyboard input
const char* input = "ls\n";
terminal_send_input(term, input, strlen(input));

// Clean up
terminal_free(term);
```

## Key Technologies

### Rust Core
- **vte** (0.13) - ANSI parser state machine
- **nix** (0.29) - Unix PTY syscalls
- **tokio** (1.0) - Async runtime (future use)
- **parking_lot** - High-performance locks
- **serde** - Serialization for session management

### Swift Frontend (Planned)
- **AppKit** - Native macOS UI
- **Metal** - GPU-accelerated rendering
- **MetalKit** - Metal view helpers
- **CoreText** - Font loading
- **HarfBuzz** - Text shaping for ligatures

## Features

### Current (Phase 1)
- Full ANSI escape sequence support
- PTY management with shell spawning
- True color (24-bit) rendering
- Efficient grid updates with damage tracking
- Terminal resizing
- Scrollback buffer

### Planned
- Metal GPU rendering with glyph atlas
- Ligature support (programming fonts)
- Background blur/transparency effects
- Tabs and split panes
- Session persistence and restoration
- WASM plugin system
- AI-powered command suggestions
- Customizable themes and keybindings
- Search and selection
- Image rendering (iTerm2/Sixel protocols)

## Project Structure

```
terminal-emulator/
├── core/                          # Rust library
│   ├── src/
│   │   ├── lib.rs                # Module exports
│   │   ├── terminal.rs           # Main terminal state machine
│   │   ├── pty.rs                # PTY management
│   │   ├── parser.rs             # ANSI parser wrapper
│   │   ├── grid.rs               # Grid/cell structures
│   │   └── ffi.rs                # C FFI bindings
│   ├── examples/
│   │   └── basic_test.rs         # Functionality tests
│   ├── Cargo.toml
│   └── terminal_core.h           # C header for Swift
├── macos/                         # Swift/AppKit frontend (TODO)
├── plugins/                       # Plugin system (TODO)
└── README.md                      # This file
```

## Development Roadmap

| Phase | Description | Status | Duration |
|-------|-------------|--------|----------|
| 1 | Core Foundation | ✅ Complete | Week 1 |
| 2 | Swift Frontend | 🔄 Next | Weeks 2-3 |
| 3 | Metal Rendering | 📋 Planned | Weeks 4-8 |
| 4 | Advanced Graphics | 📋 Planned | Weeks 9-12 |
| 5 | Window Management | 📋 Planned | Weeks 13-15 |
| 6 | Session Persistence | 📋 Planned | Weeks 16-17 |
| 7 | Plugin System | 📋 Planned | Weeks 18-20 |
| 8 | AI Integration | 📋 Planned | Weeks 21-23 |
| 9 | Configuration | 📋 Planned | Weeks 24-26 |
| 10 | Polish & Release | 📋 Planned | Weeks 27-30 |

## Performance Targets

- **Latency:** < 5ms input-to-screen
- **Throughput:** > 50MB/s PTY processing
- **Memory:** < 100MB for typical session
- **FPS:** Solid 60 FPS rendering

## Testing

The core library includes comprehensive tests:

```bash
# Run all tests
cargo test

# Run example tests
cargo run --example basic_test
```

Current test coverage:
- Grid operations
- Cell access and modification
- Scrolling behavior
- ANSI sequence parsing
- Color handling (16, 256, and true color)
- Cursor movement
- Screen clearing
- Terminal resizing

## Next Steps

1. **Create Swift/AppKit project** in `macos/`
2. **Link Rust library** to Swift via FFI bridge
3. **Implement basic window** and input handling
4. **Add simple text rendering** (pre-Metal)
5. **Test end-to-end** PTY → Parser → Renderer

## Contributing

This is currently a solo project for building a production-quality terminal emulator. Future contributions welcome once core architecture is stable.

## License

TBD

## References

- **Ghostty** - Zig + Swift architecture inspiration
- **Alacritty** - Rust terminal implementation
- **WezTerm** - Feature-complete Rust terminal
- **iTerm2** - macOS native features
- **Kitty** - GPU rendering techniques

---

**Built with ❤️ for macOS developers who want a blazing-fast, native terminal experience.**
