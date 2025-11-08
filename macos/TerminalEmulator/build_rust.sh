#!/bin/bash
set -e

# Build script for Rust terminal core library
# This script is called from Xcode build phases

echo "Building Rust terminal core library..."

# Navigate to core directory
cd "$SRCROOT/../../core"

# Build in release mode for better performance
/Users/mikethompson/.cargo/bin/cargo build --release

# Copy the dynamic library to the build products directory
cp target/release/libterminal_core.dylib "$BUILT_PRODUCTS_DIR/$PRODUCT_NAME.app/Contents/MacOS/"

echo "Rust library built successfully"
