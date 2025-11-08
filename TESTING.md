# Terminal Emulator - Testing Guide

This document outlines the testing strategy for the Terminal Emulator project.

## Test Branch

This branch (`test`) is dedicated to testing and validation of all implemented features.

## Prerequisites

### System Requirements
- **macOS**: 13.0 (Ventura) or later
- **Xcode**: 14.0 or later
- **Hardware**: Mac with Apple Silicon (M1/M2/M3) or Intel with Metal support
- **Rust**: 1.91.0 or later (installed via rustup)

### Build Requirements
- Command Line Tools for Xcode installed
- Minimum 2GB RAM available
- 1GB free disk space

### Test Environment Setup
```bash
# Verify Xcode installation
xcodebuild -version

# Verify Rust installation
rustc --version
cargo --version

# Build the project
cd /Users/mikethompson/Desktop/terminal-emulator
cd core && cargo build --release
cd ../macos/TerminalEmulator
xcodebuild -scheme TerminalEmulator build
```

## Related Documentation

This testing guide complements other project documentation:

- [BUILD_STATUS.md](BUILD_STATUS.md) - Current build status and blockers
- [IMPLEMENTATION_COMPLETE.md](IMPLEMENTATION_COMPLETE.md) - Complete implementation details
- [README.md](README.md) - Project overview and architecture
- [INTEGRATION_README.md](INTEGRATION_README.md) - Integration script documentation
- [PHASE3_SUMMARY.md](PHASE3_SUMMARY.md) - Metal rendering implementation
- [PHASE4_SUMMARY.md](PHASE4_SUMMARY.md) - Advanced graphics features

## Pass/Fail Criteria

### Critical (Must Pass)
- **Application launches** without crashing
- **Terminal I/O** works (can type and see output)
- **PTY communication** functional
- **Basic rendering** displays text correctly
- **Memory safety** - no crashes or leaks during 10-minute session

### High Priority (Should Pass)
- **60 FPS rendering** sustained during normal use
- **Input latency** < 10ms (target: <5ms)
- **Memory usage** < 150 MB (target: <100 MB)
- **ANSI colors** render correctly
- **Text selection** works in character mode

### Medium Priority (Nice to Have)
- All cursor styles functional
- Smooth scrolling at 60 FPS
- Theme switching works
- Tab management functional
- Split panes operational

### Low Priority (Enhancement)
- Plugin system operational
- AI integration functional
- All 7 themes render correctly
- Advanced selection modes (word, line, block)

## Testing Checklist

### Phase 1-2: Core Functionality ✅
- [x] Rust core library built
- [x] PTY management working
- [x] ANSI escape sequence parsing
- [x] Swift frontend scaffolded
- [ ] Basic terminal I/O verification
- [ ] Run existing Rust tests: `cd core && cargo test`
- [ ] Run basic example: `cd core && cargo run --example basic_test`

### Phase 3: Metal Rendering
- [ ] Metal renderer initializes successfully
- [ ] 60 FPS sustained rendering
- [ ] Sub-5ms input latency
- [ ] Glyph cache functioning
- [ ] Texture atlas correctly populated
- [ ] Single draw call per frame verified

### Phase 4: Advanced Graphics
- [ ] All 5 cursor styles render correctly
- [ ] Smooth scrolling works at 60 FPS
- [ ] Background blur effects apply
- [ ] Ligatures render for programming fonts
- [ ] Visual effects transitions smooth
- [ ] Cursor blinking works

### Phase 5: Window Management
- [ ] Text selection works (all modes)
- [ ] Copy/paste functions correctly
- [ ] Multiple tabs can be created
- [ ] Split panes (horizontal/vertical)
- [ ] Search finds text correctly
- [ ] Regex search works
- [ ] Keyboard shortcuts work

### Phase 6: Session Persistence
- [ ] Sessions save correctly
- [ ] Sessions restore on launch
- [ ] Auto-save triggers appropriately
- [ ] Working directory tracked
- [ ] Grid state preserved

### Phase 7: Plugin System
- [ ] Plugins can be loaded
- [ ] Hooks execute at correct times
- [ ] Plugin sandbox enforced
- [ ] WASM runtime functional (if implemented)

### Phase 8: AI Integration
- [ ] LLM providers connect (if API keys provided)
- [ ] Command suggestions work
- [ ] Error explanations generated
- [ ] Output summarization functional

### Phase 9: Configuration
- [ ] All 7 themes apply correctly
- [ ] Settings persist between sessions
- [ ] Settings can be exported
- [ ] Settings can be imported
- [ ] Theme switching works

### Phase 10: Performance Monitoring
- [ ] FPS counter accurate
- [ ] Latency measurements correct
- [ ] Memory usage reported
- [ ] CPU usage tracked
- [ ] Performance reports generated

## Performance Targets

Verify these targets are met:

| Metric | Target | Baseline | Status |
|--------|--------|----------|--------|
| FPS | 60 FPS sustained | Measure at startup | ⏳ To be tested |
| Input Latency | < 5ms | Measure with typing | ⏳ To be tested |
| Memory Usage | < 100 MB | Check in Activity Monitor | ⏳ To be tested |
| Startup Time | < 1 second | Measure with timer | ⏳ To be tested |
| GPU Utilization | < 30% | Check in Activity Monitor | ⏳ To be tested |
| Battery Impact | Low | Run on battery for 1 hour | ⏳ To be tested |

## Manual Testing Procedures

### 1. Basic Terminal Functionality
```bash
# Open the app
open TerminalEmulator.app

# Type basic commands
ls
pwd
echo "Hello World"
cat README.md

# Test keyboard shortcuts
# Cmd+T - New tab
# Cmd+W - Close tab
# Cmd+V - Paste
# Cmd+C - Copy (with selection)

# Test ANSI colors
ls -G
echo -e "\033[31mRed\033[0m \033[32mGreen\033[0m \033[34mBlue\033[0m"
```

### 2. Visual Effects Testing
- Switch between all 7 themes
- Test each cursor style
- Enable/disable blur effects
- Test ligatures with programming fonts
- Verify smooth scrolling

### 3. Multi-Pane Testing
- Create horizontal split
- Create vertical split
- Navigate between panes
- Resize panes
- Close panes

### 4. Performance Testing with Xcode Instruments

#### FPS Profiling
```bash
# Launch app with Instruments
open -a Instruments

# Select "Core Animation" template
# Attach to TerminalEmulator process
# Record for 60 seconds while:
#   - Scrolling through large file
#   - Typing rapidly
#   - Switching themes
```

#### Memory Profiling
```bash
# Use "Allocations" template
# Monitor:
#   - Persistent allocations
#   - Growth over time
#   - Leak detection
```

#### Time Profiler
```bash
# Use "Time Profiler" template
# Identify:
#   - Hot paths
#   - Rendering bottlenecks
#   - Frame time breakdown
```

### 5. Stress Testing
```bash
# Generate large output
seq 1 10000

# Test rapid scrolling
cat /usr/share/dict/words

# Test color rendering
for i in {0..255}; do echo -e "\033[38;5;${i}mColor $i\033[0m"; done

# Test memory with long session
# Leave terminal open for 1 hour with periodic output
```

## Automated Testing

### Unit Tests

#### Rust Core Tests
Existing tests in `core/`:
```bash
# Run all Rust unit tests
cd core
cargo test

# Run specific test module
cargo test grid

# Run with output
cargo test -- --nocapture

# Run example test
cargo run --example basic_test
```

#### Swift Unit Tests (To Be Created)
**File**: `macos/TerminalEmulatorTests/TerminalEmulatorTests.swift`
```swift
// Test TerminalCore wrapper
// Test color conversion
// Test grid size calculations
// Test keyboard input mapping
```

**Create test target**:
```bash
# In Xcode: File → New → Target → macOS Unit Testing Bundle
# Name: TerminalEmulatorTests
```

### Integration Tests (To Be Created)

**File**: `macos/TerminalEmulatorTests/IntegrationTests.swift`
```swift
// Test Rust-Swift FFI boundary
// Test PTY communication
// Test session save/restore
// Test Metal rendering initialization
```

### UI Tests (To Be Created)

**File**: `macos/TerminalEmulatorUITests/TerminalEmulatorUITests.swift`
```swift
// Test app launch
// Test menu interactions
// Test keyboard shortcuts
// Test window management
```

**Create UI test target**:
```bash
# In Xcode: File → New → Target → macOS UI Testing Bundle
# Name: TerminalEmulatorUITests
```

### Continuous Integration (To Be Created)

**File**: `.github/workflows/test.yml`
```yaml
name: Tests
on: [push, pull_request]
jobs:
  test:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v3
      - name: Install Rust
        run: curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
      - name: Run Rust tests
        run: cd core && cargo test
      - name: Build Xcode project
        run: cd macos/TerminalEmulator && xcodebuild test -scheme TerminalEmulator
```

## Troubleshooting

### Common Issues

#### App Doesn't Launch
**Symptom**: Application crashes immediately on launch

**Possible Causes**:
- Rust library not built or not found
- Metal device initialization failure
- Entitlements misconfigured

**Solutions**:
```bash
# Rebuild Rust library
cd core && cargo clean && cargo build --release

# Check library exists
ls -lh core/target/release/libterminal_core.a

# Check console logs
log show --predicate 'process == "TerminalEmulator"' --last 1m
```

#### No Text Appears
**Symptom**: Window opens but typing doesn't show any output

**Possible Causes**:
- PTY not created
- Terminal core not initialized
- Rendering pipeline broken

**Solutions**:
- Check console for error messages
- Verify `terminal_new_with_pty` returns valid pointer
- Check Metal device is available

#### Poor Performance
**Symptom**: FPS < 30, sluggish response

**Possible Causes**:
- Running on integrated GPU
- Debug build instead of release
- Glyph cache not working

**Solutions**:
```bash
# Build release version
xcodebuild -configuration Release

# Check GPU in Activity Monitor → GPU tab
# Force discrete GPU usage in Energy preferences
```

#### Memory Leak
**Symptom**: Memory usage grows continuously

**Possible Causes**:
- Not cleaning up Metal resources
- Scrollback buffer growing unbounded
- Terminal instances not freed

**Solutions**:
- Run Instruments "Leaks" template
- Check scrollback buffer size limit
- Verify `terminal_free` is called on deinit

#### Segmentation Fault
**Symptom**: Crash with `EXC_BAD_ACCESS`

**Possible Causes**:
- FFI boundary issue
- Null pointer dereference
- Buffer overflow

**Solutions**:
- Enable Address Sanitizer in Xcode
- Check all FFI calls for null pointers
- Run under debugger: `lldb TerminalEmulator.app`

## Known Issues

Document any issues found during testing here:

- [ ] None yet

## Test Results

Date:
Tester:
Build:
macOS Version:
Hardware:

| Test Category | Pass/Fail | Notes |
|---------------|-----------|-------|
| Core Terminal | ⏳ Pending | |
| Metal Rendering | ⏳ Pending | |
| Advanced Graphics | ⏳ Pending | |
| Window Management | ⏳ Pending | |
| Session Persistence | ⏳ Pending | |
| Plugin System | ⏳ Pending | |
| AI Integration | ⏳ Pending | |
| Configuration | ⏳ Pending | |
| Performance | ⏳ Pending | |

## Notes

- Application built successfully on 2025-11-08
- All 10 phases implemented (~8,500 lines of code)
- Ready for comprehensive testing

---

## Next Steps

### Immediate (High Priority)
1. Create Swift unit test target in Xcode
2. Run all existing Rust tests (`cargo test`)
3. Verify basic terminal functionality
4. Measure baseline performance metrics
5. Document any critical issues

### Short-term (This Week)
1. Complete all manual testing procedures
2. Run performance profiling with Instruments
3. Create automated test targets (Unit + UI)
4. Set up GitHub Actions CI/CD
5. Fix any high-priority issues found

### Medium-term (This Month)
1. Expand Rust test coverage
2. Add comprehensive Swift unit tests
3. Create regression test suite
4. Performance optimization based on profiling
5. Beta testing with real-world usage

### Long-term (Next Quarter)
1. Implement missing features from Phase 7-8
2. Add integration tests for all major features
3. Create automated performance benchmarking
4. Establish release criteria and QA process
