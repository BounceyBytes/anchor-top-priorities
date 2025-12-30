#!/bin/bash

# Script to add Google Sign-In URL scheme to Info.plist
# This runs after Info.plist is generated

# Don't use set -e, we want to handle errors gracefully
set +e

# Try multiple possible paths for Info.plist
INFO_PLIST=""

# First try INFOPLIST_PATH
if [ -n "$INFOPLIST_PATH" ] && [ -f "${BUILT_PRODUCTS_DIR}/${INFOPLIST_PATH}" ]; then
    INFO_PLIST="${BUILT_PRODUCTS_DIR}/${INFOPLIST_PATH}"
# Then try INFOPLIST_FILE
elif [ -n "$INFOPLIST_FILE" ] && [ -f "${BUILT_PRODUCTS_DIR}/${INFOPLIST_FILE}" ]; then
    INFO_PLIST="${BUILT_PRODUCTS_DIR}/${INFOPLIST_FILE}"
# Then try the wrapper name
elif [ -n "$WRAPPER_NAME" ] && [ -f "${BUILT_PRODUCTS_DIR}/${WRAPPER_NAME}/Info.plist" ]; then
    INFO_PLIST="${BUILT_PRODUCTS_DIR}/${WRAPPER_NAME}/Info.plist"
# Last resort: look for Info.plist in the built products
else
    INFO_PLIST=$(find "${BUILT_PRODUCTS_DIR}" -name "Info.plist" -type f | head -1)
fi

if [ -z "$INFO_PLIST" ] || [ ! -f "$INFO_PLIST" ]; then
    echo "Warning: Info.plist not found. Searched in:"
    echo "  - ${BUILT_PRODUCTS_DIR}/${INFOPLIST_PATH:-<not set>}"
    echo "  - ${BUILT_PRODUCTS_DIR}/${INFOPLIST_FILE:-<not set>}"
    echo "  - ${BUILT_PRODUCTS_DIR}/${WRAPPER_NAME:-<not set>}/Info.plist"
    echo "Info.plist may be generated later in the build process. Skipping URL scheme addition."
    exit 0  # Don't fail the build, just skip
fi

echo "Found Info.plist at: $INFO_PLIST"

# URL scheme for Google Sign-In
URL_SCHEME="com.googleusercontent.apps.485267448887-lbv2as73km55nh4pshqouo54fusaufel"

# Use PlistBuddy to add URL scheme if it doesn't exist
# Don't exit on error for PlistBuddy commands - handle gracefully
/usr/libexec/PlistBuddy -c "Print :CFBundleURLTypes" "$INFO_PLIST" > /dev/null 2>&1
if [ $? -ne 0 ]; then
    # CFBundleURLTypes doesn't exist, create it
    if ! /usr/libexec/PlistBuddy -c "Add :CFBundleURLTypes array" "$INFO_PLIST" 2>/dev/null; then
        echo "Warning: Failed to create CFBundleURLTypes array. Info.plist may be read-only or corrupted."
        exit 0  # Don't fail the build
    fi
fi

# Check if the URL scheme already exists at index 0
SCHEME_EXISTS=$(/usr/libexec/PlistBuddy -c "Print :CFBundleURLTypes:0:CFBundleURLSchemes:0" "$INFO_PLIST" 2>/dev/null)

if [ "$SCHEME_EXISTS" != "$URL_SCHEME" ]; then
    # Check if index 0 exists, if not create it
    /usr/libexec/PlistBuddy -c "Print :CFBundleURLTypes:0" "$INFO_PLIST" > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        if ! /usr/libexec/PlistBuddy -c "Add :CFBundleURLTypes:0 dict" "$INFO_PLIST" 2>/dev/null; then
            echo "Warning: Failed to create URL type dict. Skipping URL scheme addition."
            exit 0  # Don't fail the build
        fi
    fi
    
    # Add the URL type entry (use Set if Add fails, meaning it already exists)
    /usr/libexec/PlistBuddy -c "Add :CFBundleURLTypes:0:CFBundleTypeRole string Editor" "$INFO_PLIST" 2>/dev/null || \
    /usr/libexec/PlistBuddy -c "Set :CFBundleURLTypes:0:CFBundleTypeRole Editor" "$INFO_PLIST" 2>/dev/null || true
    
    /usr/libexec/PlistBuddy -c "Add :CFBundleURLTypes:0:CFBundleURLSchemes array" "$INFO_PLIST" 2>/dev/null || true
    
    if /usr/libexec/PlistBuddy -c "Add :CFBundleURLTypes:0:CFBundleURLSchemes:0 string $URL_SCHEME" "$INFO_PLIST" 2>/dev/null; then
        echo "Successfully added URL scheme $URL_SCHEME to Info.plist"
    elif /usr/libexec/PlistBuddy -c "Set :CFBundleURLTypes:0:CFBundleURLSchemes:0 $URL_SCHEME" "$INFO_PLIST" 2>/dev/null; then
        echo "Successfully set URL scheme $URL_SCHEME in Info.plist"
    else
        echo "Warning: Could not add URL scheme. It may already exist or Info.plist may be read-only."
        # Don't exit with error - the scheme might already be there
    fi
else
    echo "URL scheme $URL_SCHEME already exists in Info.plist"
fi

# Always exit successfully
exit 0

