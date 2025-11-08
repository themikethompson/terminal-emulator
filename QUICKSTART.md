# Terminal Emulator - Quick Start Guide

## TL;DR

```bash
# Clone/navigate to project
cd terminal-emulator

# Build Rust core
cd core
/Users/mikethompson/.cargo/bin/cargo build --release
cd ..

# Open Xcode and run
cd macos/TerminalEmulator
open TerminalEmulator.xcodeproj
# Press Cmd+R
```

## What You Get

A fully functional macOS terminal emulator with:
- Real shell integration (zsh/bash)
- ANSI color support
- Keyboard input (arrows, ctrl keys, etc.)
- Text attributes (bold, italic, underline)
- Blinking cursor
- Window resizing
- Paste support

## Project Structure

```
terminal-emulator/
├── core/                   # Rust library (terminal logic)
├── macos/                  # Swift app (macOS UI)
├── README.md              # Full documentation
├── QUICKSTART.md          # This file
├── PHASE2_COMPLETE.md     # Implementation details
└── BUILD_GUIDE.md         # Detailed build instructions
```

## Key Files

**Rust Core:**
- `core/src/terminal.rs` - Terminal state machine
- `core/src/pty.rs` - Pseudoterminal handling
- `core/src/grid.rs` - Cell grid & colors
- `core/src/ffi.rs` - C FFI bindings

**Swift App:**
- `macos/.../TerminalCore.swift` - FFI wrapper
- `macos/.../TerminalView.swift` - Rendering & input
- `macos/.../TerminalViewController.swift` - Lifecycle

## Quick Commands

```bash
# Test Rust core
cd core
cargo test
cargo run --example basic_test

# Build macOS app (command line)
cd macos/TerminalEmulator
xcodebuild -project TerminalEmulator.xcodeproj -scheme TerminalEmulator build

# Clean build
cargo clean
xcodebuild clean
```

## Architecture

```
┌────────────────────┐
│  Swift/AppKit UI   │  ← You interact here
├────────────────────┤
│  FFI Bridge (C)    │
├────────────────────┤
│  Rust Core         │  ← Terminal logic
│  - PTY            │
│  - Parser         │
│  - Grid           │
└────────────────────┘
```

## Current Status

✅ Phase 1: Rust Core - **COMPLETE**
✅ Phase 2: Swift Frontend - **COMPLETE**
🔄 Phase 3: Metal Rendering - **Next**

**App is functional and usable for basic terminal work!**

## Common Issues

**"Library not loaded"**
→ Build Rust first: `cd core && cargo build --release`

**"Cannot find terminal_core.h"**
→ Check bridging header path in Xcode build settings

**Terminal doesn't respond**
→ Check PTY file descriptor is valid (>= 0)

## Next Steps

1. **Try it:** Open the app and run some commands
2. **Customize:** Modify font size in `TerminalView.swift`
3. **Extend:** Add features from TODO below

## TODO (Future Phases)

- [ ] Metal GPU rendering (60 FPS)
- [ ] Text selection & copy
- [ ] Scrollback scrolling
- [ ] Ligature support
- [ ] Tabs & splits
- [ ] Configuration UI
- [ ] Themes
- [ ] Search
- [ ] Background blur
- [ ] AI integration

## Resources

- [Full README](README.md)
- [Build Guide](macos/BUILD_GUIDE.md)
- [Phase 2 Summary](PHASE2_COMPLETE.md)
- [vte Parser Docs](https://docs.rs/vte/)
- [Metal Guide](https://developer.apple.com/metal/)

## Performance

**Current:** 30-40 FPS, ~15ms latency
**Target:** 60 FPS, <5ms latency (after Metal)

---

**Questions?** Check README.md or review the code comments.

**Want to contribute?** Start with Phase 3 (Metal Rendering)!
