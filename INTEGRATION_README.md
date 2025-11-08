# Xcode Integration Scripts

Two scripts are provided to help integrate the 19 new files from Phases 3-10 into the Xcode project.

## Option 1: Automated Integration (Recommended)

**Script:** `add_files_to_xcode.rb`

This Ruby script uses the `xcodeproj` gem to automatically add all files to the Xcode project.

### Prerequisites

Install the xcodeproj gem:

```bash
gem install xcodeproj
```

Or with sudo if needed:

```bash
sudo gem install xcodeproj
```

### Usage

```bash
ruby add_files_to_xcode.rb
```

The script will:
- ✓ Open the Xcode project
- ✓ Add all 19 files to the TerminalEmulator group
- ✓ Add files to the appropriate build phases
- ✓ Save the project
- ✓ Display a summary

### Expected Output

```
============================================================
Xcode Project Integration Script
============================================================

Opening Xcode project: macos/TerminalEmulator/TerminalEmulator.xcodeproj
Found target: TerminalEmulator

Adding files to group: TerminalEmulator

Phase 3: Metal Rendering:
  ✓ MetalRenderer.swift - Added successfully
  ✓ GlyphCache.swift - Added successfully
  ✓ Shaders.metal - Added successfully

[... continues for all phases ...]

============================================================
Integration Complete!
============================================================

Summary:
  Added:   19 files
  Skipped: 0 files (already in project)
  Errors:  0 files

Total files processed: 19

✓ Files successfully added to Xcode project!

Next steps:
  1. Open Xcode: open macos/TerminalEmulator/TerminalEmulator.xcodeproj
  2. Build project: Cmd+B
  3. Run and test: Cmd+R

Expected: Metal renderer initialized successfully
```

---

## Option 2: Verification + Manual Integration

**Script:** `add_files_simple.sh`

This shell script verifies all files exist and provides step-by-step manual integration instructions.

### Usage

```bash
./add_files_simple.sh
```

The script will:
- ✓ Verify all 19 files exist on disk
- ✓ Display manual integration steps

Then follow the on-screen instructions to add files manually in Xcode.

---

## Files to be Added (19 total)

### Phase 3: Metal Rendering (3 files)
- MetalRenderer.swift
- GlyphCache.swift
- Shaders.metal

### Phase 4: Advanced Graphics (4 files)
- CursorRenderer.swift
- ScrollAnimator.swift
- VisualEffectsManager.swift
- LigatureHandler.swift

### Phase 5: Window Management (5 files)
- TextSelection.swift
- ClipboardManager.swift
- TabManager.swift
- SplitPaneManager.swift
- SearchManager.swift

### Phase 6: Session Persistence (2 files)
- SessionManager.swift
- WorkingDirectoryTracker.swift

### Phase 7: Plugin System (1 file)
- PluginManager.swift

### Phase 8: AI Integration (1 file)
- AIAssistant.swift

### Phase 9: Configuration (2 files)
- ThemeManager.swift
- SettingsManager.swift

### Phase 10: Polish & Testing (1 file)
- PerformanceMonitor.swift

---

## After Integration

Once files are added to Xcode:

### 1. Build the Project

```bash
cd macos/TerminalEmulator
xcodebuild -project TerminalEmulator.xcodeproj -scheme TerminalEmulator build
```

Or in Xcode: **Cmd+B**

### 2. Run the Application

In Xcode: **Cmd+R**

### 3. Expected Console Output

```
Metal renderer initialized successfully
```

### 4. Verify Features

- **60 FPS rendering** - Check performance monitor
- **GPU acceleration** - Metal renderer active
- **Cursor rendering** - Blinking cursor visible
- **Visual effects** - Transparency/blur available
- **All 10 phases** - Complete feature set

---

## Troubleshooting

### xcodeproj gem installation fails

If `gem install xcodeproj` fails, try:

```bash
# Update RubyGems first
gem update --system

# Then install
gem install xcodeproj
```

Or use system Ruby:

```bash
sudo gem install xcodeproj
```

### Files already in project

If the script reports files are already in the project, you can skip this step and proceed directly to building.

### Build errors after integration

If you encounter build errors:

1. Clean build folder: **Cmd+Shift+K**
2. Rebuild Rust core: `cd core && cargo build --release`
3. Build again: **Cmd+B**

### Missing Metal framework

If you get Metal framework errors, ensure your project has:
- Metal framework linked
- MetalKit framework linked
- Deployment target set to macOS 13.0+

---

## Quick Start

**Fastest path to building:**

```bash
# 1. Install xcodeproj gem
gem install xcodeproj

# 2. Run automated integration
ruby add_files_to_xcode.rb

# 3. Open Xcode
cd macos/TerminalEmulator
open TerminalEmulator.xcodeproj

# 4. Build and run (Cmd+B, then Cmd+R)
```

---

## Support

See comprehensive documentation:
- [IMPLEMENTATION_COMPLETE.md](IMPLEMENTATION_COMPLETE.md) - Full implementation details
- [XCODE_INTEGRATION_STEPS.md](XCODE_INTEGRATION_STEPS.md) - Manual integration guide
- [FILES_TO_ADD.md](FILES_TO_ADD.md) - File reference
- [README.md](README.md) - Project overview
