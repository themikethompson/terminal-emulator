# Building the Terminal Emulator macOS App

This guide explains how to build and run the terminal emulator application.

## Prerequisites

1. **macOS** 13.0 or later
2. **Xcode** 14.0 or later
3. **Rust** 1.91+ (already installed)
4. **Command Line Tools** for Xcode

## Project Structure

```
macos/
├── TerminalEmulator/
│   ├── TerminalEmulator.xcodeproj/     # Xcode project
│   ├── TerminalEmulator/               # Swift source files
│   │   ├── AppDelegate.swift
│   │   ├── TerminalCore.swift          # Rust FFI wrapper
│   │   ├── TerminalWindowController.swift
│   │   ├── TerminalViewController.swift
│   │   ├── TerminalView.swift          # Rendering & input
│   │   ├── Info.plist
│   │   ├── TerminalEmulator.entitlements
│   │   └── TerminalEmulator-Bridging-Header.h
│   └── build_rust.sh                   # Rust build script
└── BUILD_GUIDE.md                      # This file
```

## Building from Command Line

### Step 1: Build Rust Library

```bash
cd ../../core
/Users/mikethompson/.cargo/bin/cargo build --release
```

This creates `libterminal_core.dylib` in `core/target/release/`.

### Step 2: Build macOS App

```bash
cd ../macos/TerminalEmulator
xcodebuild -project TerminalEmulator.xcodeproj -scheme TerminalEmulator -configuration Release build
```

## Building from Xcode

### Step 1: Open Project

```bash
open TerminalEmulator.xcodeproj
```

### Step 2: Configure Build Settings (if needed)

The project is pre-configured with:
- Swift bridging header pointing to `terminal_core.h`
- Library search path to Rust build output
- Build script to compile Rust library automatically

### Step 3: Build and Run

1. Select the **TerminalEmulator** scheme
2. Press **Cmd+R** to build and run
3. Or **Cmd+B** to just build

The build process will:
1. Run `build_rust.sh` to compile the Rust library
2. Compile Swift sources
3. Link everything together
4. Copy the dylib into the app bundle

## Running the App

After building, the app will be located at:
```
~/Library/Developer/Xcode/DerivedData/TerminalEmulator-*/Build/Products/Debug/TerminalEmulator.app
```

Double-click to run, or use:
```bash
open build/TerminalEmulator.app
```

## Features Implemented

### ✅ Core Functionality
- [x] Rust core library integration via FFI
- [x] PTY (pseudoterminal) with shell spawning
- [x] ANSI escape sequence parsing
- [x] Text rendering with colors
- [x] Cursor display (blinking)
- [x] Keyboard input handling
- [x] Async PTY output reading
- [x] Terminal resizing
- [x] Paste support (Cmd+V)

### ⚠️ Partially Implemented
- [ ] Copy support (selection not yet implemented)
- [ ] Scrollback scrolling (grid has buffer, UI needs scroll view)

### 🚧 Not Yet Implemented
- [ ] Metal GPU rendering (currently using NSAttributedString)
- [ ] Ligature support
- [ ] Background blur/transparency
- [ ] Tabs and splits
- [ ] Search
- [ ] Configuration UI

## Architecture

```
┌──────────────────────────────────────┐
│  AppDelegate                         │
│  └─ TerminalWindowController         │
│      └─ TerminalViewController       │
│          └─ TerminalView              │
│              │                        │
│              ├─ Draw loop             │
│              ├─ Keyboard events       │
│              └─ Mouse events          │
└──────────────┬───────────────────────┘
               │ Swift FFI Wrapper
┌──────────────┴───────────────────────┐
│  TerminalCore (Swift wrapper)        │
│   - terminal_new_with_pty()          │
│   - terminal_process_bytes()         │
│   - terminal_get_row()               │
│   - terminal_send_input()            │
└──────────────┬───────────────────────┘
               │ C FFI (dylib)
┌──────────────┴───────────────────────┐
│  Rust Core (libterminal_core.dylib)  │
│   - Terminal state machine           │
│   - PTY management                   │
│   - ANSI parser                      │
│   - Grid & cells                     │
└──────────────────────────────────────┘
```

## How It Works

1. **App Launch**
   - `AppDelegate` creates `TerminalWindowController`
   - Controller creates `TerminalViewController`
   - ViewController creates `TerminalView`

2. **Terminal Initialization**
   - ViewController calls `TerminalCore(rows: 24, cols: 80)`
   - Rust creates PTY and spawns `/bin/zsh`
   - Returns PTY file descriptor for monitoring

3. **PTY Monitoring** (GCD DispatchSource)
   - `DispatchSource.makeReadSource` watches PTY fd
   - When data available, reads into buffer
   - Calls `terminal.processBytes()` to parse ANSI
   - Triggers view redraw

4. **Rendering**
   - `TerminalView.draw()` called on main thread
   - Fetches each row via `terminal.getRow()`
   - Draws background colors as rects
   - Draws text with `NSAttributedString`
   - Draws blinking cursor

5. **Input Handling**
   - `keyDown()` captures keyboard events
   - Converts special keys to ANSI sequences
   - Sends to PTY via `terminal.sendInput()`
   - Shell receives input and produces output
   - Output goes back through PTY monitoring loop

## Troubleshooting

### "Library not loaded: libterminal_core.dylib"

Build the Rust library first:
```bash
cd ../../core
cargo build --release
```

### "Undefined symbols for architecture arm64"

Make sure bridging header path is correct and Rust library is built for the right architecture.

### Terminal doesn't respond to input

Check that:
1. PTY was created successfully (check terminal pointer not nil)
2. PTY file descriptor is valid (>= 0)
3. GCD dispatch source is running

### Garbled text or colors

This usually means ANSI parsing issue in Rust core. Check:
```bash
cd ../../core
cargo test
```

## Next Steps

To continue development:

1. **Metal Rendering** (Phase 3)
   - Replace `TerminalView` draw method with Metal
   - Implement glyph atlas
   - Write Metal shaders

2. **Selection & Copy** (Phase 5)
   - Add mouse drag tracking
   - Implement text selection
   - Copy to pasteboard

3. **Tabs & Splits** (Phase 5)
   - Multiple terminal instances
   - Layout management
   - Tab bar UI

4. **Configuration** (Phase 9)
   - Settings window
   - Theme support
   - Custom keybindings

## Performance Notes

**Current (NSAttributedString):**
- ~30-40 FPS for full screen updates
- CPU-bound (text layout is slow)
- Acceptable for light use

**Target (Metal):**
- 60 FPS sustained
- GPU-accelerated
- Sub-5ms latency

## Resources

- [Apple PTY Programming Guide](https://developer.apple.com/library/archive/samplecode/SimpleXMLParsing/)
- [ANSI Escape Codes](https://en.wikipedia.org/wiki/ANSI_escape_code)
- [vte Documentation](https://docs.rs/vte/latest/vte/)
- [Metal Programming Guide](https://developer.apple.com/metal/)

---

**Questions?** Check the main README.md or review the Rust core tests.
