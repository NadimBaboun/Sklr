#!/bin/bash

# Get the absolute directory path of this script
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Path to the sign_in_with_apple Swift file
SIGN_IN_FILE="${HOME}/.pub-cache/hosted/pub.dev/sign_in_with_apple-6.1.4/ios/Classes/SignInWithAppleError.swift"

echo "Applying patches to fix build issues..."

if [ -f "$SIGN_IN_FILE" ]; then
  echo "Patching SignInWithAppleError.swift..."
  patch -N "$SIGN_IN_FILE" "$SCRIPT_DIR/SignInWithAppleError.swift.patch"
  if [ $? -eq 0 ]; then
    echo "Successfully patched SignInWithAppleError.swift"
  else
    echo "Failed to patch SignInWithAppleError.swift"
  fi
else
  echo "File not found: $SIGN_IN_FILE"
fi

echo "Patch application complete." 