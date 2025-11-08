#!/bin/bash

# All-in-one integration script
# Installs dependencies if needed, then integrates files into Xcode

set -e

echo "============================================================"
echo "Terminal Emulator - Xcode Integration"
echo "============================================================"
echo

# Check if xcodeproj gem is installed
echo "Checking for xcodeproj gem..."
if ruby -e "require 'xcodeproj'" 2>/dev/null; then
    echo "✓ xcodeproj gem is installed"
    echo
else
    echo "✗ xcodeproj gem not found"
    echo
    echo "Installing xcodeproj gem..."
    echo

    # Try without sudo first
    if gem install xcodeproj 2>/dev/null; then
        echo "✓ xcodeproj gem installed successfully"
    else
        echo "Installation without sudo failed. Trying with sudo..."
        echo "You may be prompted for your password."
        echo
        sudo gem install xcodeproj
        echo "✓ xcodeproj gem installed successfully"
    fi
    echo
fi

# Run the integration script
echo "Running automated integration..."
echo
ruby add_files_to_xcode.rb

echo
echo "============================================================"
echo "Integration script completed!"
echo "============================================================"
echo
echo "You can now:"
echo "  1. Open Xcode: open macos/TerminalEmulator/TerminalEmulator.xcodeproj"
echo "  2. Build: Cmd+B"
echo "  3. Run: Cmd+R"
echo
