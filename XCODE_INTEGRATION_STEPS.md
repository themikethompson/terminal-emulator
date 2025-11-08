# Xcode Integration Steps for Phase 3 Metal Rendering

## Quick Integration Guide

### Step 1: Open the Xcode Project

```bash
cd /Users/mikethompson/Desktop/terminal-emulator/macos/TerminalEmulator
open TerminalEmulator.xcodeproj
```

### Step 2: Add New Files to Project

In Xcode:

1. **Select the TerminalEmulator group** (folder icon in the left sidebar)

2. **Right-click → "Add Files to 'TerminalEmulator'..."**

3. **Navigate to:** `/Users/mikethompson/Desktop/terminal-emulator/macos/TerminalEmulator/TerminalEmulator/`

4. **Select these 3 files:**
   - `MetalRenderer.swift`
   - `GlyphCache.swift`
   - `Shaders.metal`

5. **Important options:**
   - ✅ **CHECK:** "TerminalEmulator" target
   - ❌ **UNCHECK:** "Copy items if needed" (files are already in the right place)
   - **Added folders:** "Create groups"

6. **Click "Add"**

### Step 3: Verify Build Settings

The Metal framework should automatically be linked, but verify:

1. **Select project** in navigator (blue icon at top)
2. **Select TerminalEmulator target**
3. **Build Phases tab**
4. **Expand "Link Binary With Libraries"**
5. **Verify these frameworks exist:**
   - `Metal.framework`
   - `MetalKit.framework`
   - `AppKit.framework`
   - `Foundation.framework`

If Metal/MetalKit are missing:
- Click the "+" button
- Search for "Metal.framework"
- Add it
- Repeat for "MetalKit.framework"

### Step 4: Verify Shaders Are Compiled

1. Still in **Build Phases**
2. **Expand "Compile Sources"**
3. **Verify `Shaders.metal` is listed**
   - If not listed, click "+" and add it

Files should look like:
```
AppDelegate.swift
TerminalCore.swift
TerminalWindowController.swift
TerminalViewController.swift
TerminalView.swift
MetalRenderer.swift          ← NEW
GlyphCache.swift             ← NEW
Shaders.metal               ← NEW
```

### Step 5: Build the Project

Press **Cmd+B** to build.

**Expected output in console:**
- Rust library builds successfully
- No Swift compilation errors
- No Metal shader compilation errors

### Step 6: Run the Application

Press **Cmd+R** to run.

**Expected console output:**
```
Metal renderer initialized successfully
```

**Expected behavior:**
- Terminal window opens
- Text renders with GPU acceleration
- Smooth 60 FPS rendering
- All keyboard input works
- Colors display correctly

## Troubleshooting

### Build Error: "Cannot find 'MetalRenderer' in scope"

**Solution:** Make sure `MetalRenderer.swift` is:
- Listed in Project Navigator (left sidebar)
- Checked for "TerminalEmulator" target
- Listed in Build Phases → Compile Sources

### Build Error: "Use of undeclared type 'MTLDevice'"

**Solution:** Metal framework not linked
- Project → Target → Build Phases
- Link Binary With Libraries → Add Metal.framework

### Build Error: Shader compilation failed

**Solution:** Check `Shaders.metal` syntax
- Look at the error message in build log
- Metal shaders are C++-based, check syntax

### Runtime Error: "Failed to initialize Metal renderer"

**Possible causes:**
1. Metal not supported (very unlikely on modern Macs)
2. Shader failed to load
3. Check console for detailed error message

**Debug:**
- Check that `Shaders.metal` is in the app bundle
- Verify Metal device creation succeeds

### Black Screen / No Text

**Possible causes:**
1. Glyph cache failed to initialize
2. Font loading issue
3. Texture atlas issue

**Debug:**
- Uncomment FPS logging in `TerminalView.swift:131`
- Check console for warnings
- Verify draw() is being called

## Verification Tests

Once running, test these commands:

```bash
# Basic text
echo "Hello, Metal!"

# Colors
ls -la

# Unicode box drawing
echo "╔═══════╗"
echo "║ TEST  ║"
echo "╚═══════╝"

# Text attributes
echo -e "\e[1mBold\e[0m \e[3mItalic\e[0m \e[4mUnderline\e[0m"

# 256 colors
for i in {0..15}; do echo -e "\e[48;5;${i}m  \e[0m"; done

# Heavy output (test performance)
ls -laR /usr | head -n 500

# Interactive (test input handling)
vim
```

## Performance Verification

To check FPS:

1. Open `TerminalView.swift`
2. Go to line ~131
3. Uncomment the print statement:
   ```swift
   print("FPS: \(String(format: "%.1f", fps))")
   ```
4. Rebuild and run
5. Watch console for FPS readout
6. **Expected:** 60 FPS sustained

## File Locations

All files are already in the correct location:

```
/Users/mikethompson/Desktop/terminal-emulator/macos/TerminalEmulator/TerminalEmulator/
├── AppDelegate.swift                    [existing]
├── TerminalCore.swift                   [existing]
├── TerminalWindowController.swift       [existing]
├── TerminalViewController.swift         [modified]
├── TerminalView.swift                   [modified]
├── MetalRenderer.swift                  [NEW - ADD TO XCODE]
├── GlyphCache.swift                     [NEW - ADD TO XCODE]
└── Shaders.metal                        [NEW - ADD TO XCODE]
```

## Success Criteria

✅ Project builds without errors
✅ App launches without crashes
✅ Console shows "Metal renderer initialized successfully"
✅ Terminal text renders correctly
✅ Colors display properly
✅ Keyboard input works
✅ Window resizing works
✅ 60 FPS rendering (check with FPS logging)
✅ Smooth scrolling during heavy output

## Next Steps After Integration

Once Phase 3 is verified working:

1. **Profile performance**
   - Use Xcode Instruments
   - Verify < 5ms latency
   - Check GPU utilization

2. **Optimize if needed**
   - Adjust texture atlas size if needed
   - Fine-tune glyph caching

3. **Move to Phase 4**
   - Begin implementing ligatures
   - Add transparency/blur effects
   - Implement image rendering protocols

## Need Help?

If you encounter issues:

1. **Check the build log** in Xcode (View → Navigators → Reports)
2. **Check the console** output when running
3. **Verify file paths** are correct
4. **Clean build folder** (Product → Clean Build Folder, then Cmd+B)

## Summary

**Files to add:** 3 files (MetalRenderer.swift, GlyphCache.swift, Shaders.metal)
**Modified files:** 2 files (already updated in project)
**Frameworks needed:** Metal, MetalKit (should auto-link)
**Expected result:** 60 FPS GPU-accelerated terminal rendering
