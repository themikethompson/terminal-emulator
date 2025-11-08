#!/bin/bash

# Simple script to verify files and guide through Xcode integration
# Usage: ./add_files_simple.sh

set -e

echo "============================================================"
echo "Xcode Integration Helper Script"
echo "============================================================"
echo

# Configuration
PROJECT_DIR="macos/TerminalEmulator/TerminalEmulator"
PROJECT_FILE="macos/TerminalEmulator/TerminalEmulator.xcodeproj"

# Files to add
declare -a FILES=(
    # Phase 3: Metal Rendering
    "MetalRenderer.swift"
    "GlyphCache.swift"
    "Shaders.metal"
    # Phase 4: Advanced Graphics
    "CursorRenderer.swift"
    "ScrollAnimator.swift"
    "VisualEffectsManager.swift"
    "LigatureHandler.swift"
    # Phase 5: Window Management
    "TextSelection.swift"
    "ClipboardManager.swift"
    "TabManager.swift"
    "SplitPaneManager.swift"
    "SearchManager.swift"
    # Phase 6: Session Persistence
    "SessionManager.swift"
    "WorkingDirectoryTracker.swift"
    # Phase 7: Plugin System
    "PluginManager.swift"
    # Phase 8: AI Integration
    "AIAssistant.swift"
    # Phase 9: Configuration
    "ThemeManager.swift"
    "SettingsManager.swift"
    # Phase 10: Polish & Testing
    "PerformanceMonitor.swift"
)

echo "Verifying files exist on disk..."
echo

FOUND=0
MISSING=0

for file in "${FILES[@]}"; do
    if [ -f "$PROJECT_DIR/$file" ]; then
        echo "  ✓ $file"
        ((FOUND++))
    else
        echo "  ✗ $file - MISSING!"
        ((MISSING++))
    fi
done

echo
echo "Summary: $FOUND found, $MISSING missing"
echo

if [ $MISSING -gt 0 ]; then
    echo "ERROR: Some files are missing!"
    exit 1
fi

echo "All files verified successfully!"
echo
echo "============================================================"
echo "Manual Integration Steps"
echo "============================================================"
echo
echo "1. Open Xcode project:"
echo "   cd macos/TerminalEmulator"
echo "   open TerminalEmulator.xcodeproj"
echo
echo "2. In Xcode, select 'TerminalEmulator' group in Project Navigator"
echo
echo "3. Right-click → 'Add Files to \"TerminalEmulator\"...'"
echo
echo "4. Navigate to: $PWD/$PROJECT_DIR"
echo
echo "5. Select all 19 files:"
for file in "${FILES[@]}"; do
    echo "   - $file"
done
echo
echo "6. IMPORTANT: Uncheck 'Copy items if needed' (files already in place)"
echo
echo "7. Check 'TerminalEmulator' target"
echo
echo "8. Click 'Add'"
echo
echo "9. Build project: Cmd+B"
echo
echo "10. Run: Cmd+R"
echo
echo "============================================================"
echo "Automated Integration"
echo "============================================================"
echo
echo "For automated integration, use the Ruby script:"
echo "  ruby add_files_to_xcode.rb"
echo
echo "If xcodeproj gem is not installed:"
echo "  gem install xcodeproj"
echo "  (or: sudo gem install xcodeproj)"
echo
