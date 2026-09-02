#!/usr/bin/env bash
# Prepare GitHub Actions secrets for installable iOS IPA builds.
# Run on a Mac where Xcode is signed in with team 94R4J2QHW5.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT_DIR="${ROOT}/.ios-secrets"
BUNDLE_ID="com.app.chatapp"

echo "=== iOS signing secret helper ==="
echo ""
echo "This creates base64 files you paste into GitHub → Settings → Secrets → Actions:"
echo "  APPLE_CERTIFICATE_BASE64"
echo "  APPLE_CERTIFICATE_PASSWORD"
echo "  APPLE_PROVISIONING_PROFILE_BASE64"
echo ""
echo "Before running:"
echo "  1. Open Xcode → Settings → Accounts → your Apple ID → team 94R4J2QHW5"
echo "  2. Register your iPhone at https://developer.apple.com/account/resources/devices/list"
echo "  3. Create an iOS Development profile for ${BUNDLE_ID} including your iPhone"
echo "  4. Export an .p12 from Keychain Access (Apple Development certificate)"
echo ""

mkdir -p "$OUT_DIR"

read -r -p "Path to your exported .p12 certificate: " P12_PATH
if [[ ! -f "$P12_PATH" ]]; then
  echo "File not found: $P12_PATH" >&2
  exit 1
fi

read -r -s -p "Password for the .p12 file: " P12_PASSWORD
echo ""

read -r -p "Path to your .mobileprovision file: " PP_PATH
if [[ ! -f "$PP_PATH" ]]; then
  echo "File not found: $PP_PATH" >&2
  exit 1
fi

base64 -i "$P12_PATH" -o "${OUT_DIR}/APPLE_CERTIFICATE_BASE64.txt"
printf '%s' "$P12_PASSWORD" > "${OUT_DIR}/APPLE_CERTIFICATE_PASSWORD.txt"
base64 -i "$PP_PATH" -o "${OUT_DIR}/APPLE_PROVISIONING_PROFILE_BASE64.txt"

echo ""
echo "Created secret files in ${OUT_DIR}/"
echo "Copy each file's contents into the matching GitHub secret, then delete ${OUT_DIR}/"
echo ""
echo "After pushing and CI completes:"
echo "  • Install the signed IPA from GitHub Releases"
echo "  • On iPhone: Settings → General → VPN & Device Management → Trust your developer cert"
