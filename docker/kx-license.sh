#!/bin/bash
# KX License Setup Script
# Place in /etc/profile.d/ for interactive shells
# Source from tick.sh for container startup
#
# If KX_LICENSE_B64 environment variable is set, decode it and write to kc.lic
# This allows overriding the build-time license at runtime

# Determine the KX home directory
KX_HOME="${QLIC:-$HOME/.kx}"

# Function to setup license from base64 encoded string
setup_kx_license() {
    local license_b64="$1"
    local kx_home="$2"

    if [[ -z "$license_b64" ]]; then
        return 0
    fi

    # Create directory if it doesn't exist
    mkdir -p "$kx_home"

    # Decode and write the license file
    if echo "$license_b64" | base64 -d > "$kx_home/kc.lic" 2>/dev/null; then
        echo "KX license updated from KX_LICENSE_B64 environment variable"
        chmod 600 "$kx_home/kc.lic"
        return 0
    else
        echo "Warning: Failed to decode KX_LICENSE_B64 - using existing license" >&2
        return 1
    fi
}

# Only run if KX_LICENSE_B64 is set and non-empty
if [[ -n "${KX_LICENSE_B64:-}" ]]; then
    setup_kx_license "$KX_LICENSE_B64" "$KX_HOME"
fi

# Ensure QLIC is set correctly
export QLIC="$KX_HOME"
