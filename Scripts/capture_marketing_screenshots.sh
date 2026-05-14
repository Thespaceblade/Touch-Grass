#!/usr/bin/env bash
#
# capture_marketing_screenshots.sh
#
# Runs the `MarketingScreenshotUITests` XCTest target on the iOS Simulator,
# exports every `XCTAttachment` produced by the tests, and copies the named
# attachments into the marketing assets folder.
#
# Output:
#   DesignSystem/project/marketing/assets/screenshots/<scenario>.png
#
# Usage:
#   Scripts/capture_marketing_screenshots.sh                      # default device
#   SIM_DEVICE='iPhone 16 Pro' Scripts/capture_marketing_screenshots.sh
#

set -euo pipefail

# Resolve repo root by walking up from this script.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${REPO_ROOT}"

SCHEME="${SCHEME:-Touch-Grass}"
SIM_DEVICE="${SIM_DEVICE:-iPhone 17 Pro Max}"
DESTINATION="platform=iOS Simulator,name=${SIM_DEVICE}"

RESULT_BUNDLE_DIR="${REPO_ROOT}/.screenshot-results"
RESULT_BUNDLE="${RESULT_BUNDLE_DIR}/MarketingScreenshots.xcresult"
EXPORT_DIR="${RESULT_BUNDLE_DIR}/export"
OUTPUT_DIR="${REPO_ROOT}/DesignSystem/project/marketing/assets/screenshots"

SCENARIOS=(
  "gameSelection"
  "ctfLobby"
  "ctfActive"
  "zombieActive"
  "manhuntActive"
  "resultsShare"
)

# CTF lobby is tall under the status bar; Simulator often leaves a system tip
# (e.g. Apple Intelligence) in the top strip. After export, crop a small top
# band using `sips` (offset is horizontal, vertical from top-left per sips).
strip_ctf_lobby_top_tip() {
  local file="$1"
  [[ -f "${file}" ]] || return 0
  local h w crop nh tmp
  h=$(sips -g pixelHeight "${file}" 2>/dev/null | awk '/pixelHeight/{print $2}')
  w=$(sips -g pixelWidth "${file}" 2>/dev/null | awk '/pixelWidth/{print $2}')
  [[ -n "${h}" && -n "${w}" ]] || return 0
  # Shave only the status-bar / system-tip band (~5% height, clamped) so lobby UI stays intact.
  crop=$(( (h * 5) / 100 ))
  if [[ ${crop} -lt 100 ]]; then crop=100; fi
  if [[ ${crop} -gt 180 ]]; then crop=180; fi
  nh=$(( h - crop ))
  tmp="${file}.croptmp.png"
  sips -c "${nh}" "${w}" --cropOffset 0 "${crop}" "${file}" --out "${tmp}" >/dev/null
  mv "${tmp}" "${file}"
  echo "   (ctfLobby: cropped top ${crop}px to reduce system tip overlap)"
}

echo "==> Repo root:        ${REPO_ROOT}"
echo "==> Scheme:           ${SCHEME}"
echo "==> Destination:      ${DESTINATION}"
echo "==> Result bundle:    ${RESULT_BUNDLE}"
echo "==> Output directory: ${OUTPUT_DIR}"

mkdir -p "${OUTPUT_DIR}"
rm -rf "${RESULT_BUNDLE_DIR}"
mkdir -p "${RESULT_BUNDLE_DIR}"

echo
echo "==> Running XCTest UI tests (this builds the app and boots the Simulator)..."
set +e
xcodebuild test \
  -scheme "${SCHEME}" \
  -destination "${DESTINATION}" \
  -only-testing:"Touch-GrassUITests/MarketingScreenshotUITests" \
  -resultBundlePath "${RESULT_BUNDLE}" \
  -quiet
TEST_STATUS=$?
set -e

if [[ ${TEST_STATUS} -ne 0 ]]; then
  echo "!! xcodebuild test exited with status ${TEST_STATUS}."
  echo "   Continuing anyway because individual scenario failures should not"
  echo "   block exporting successful attachments. Check the xcresult for details."
fi

echo
echo "==> Exporting attachments from ${RESULT_BUNDLE}..."
mkdir -p "${EXPORT_DIR}"
xcrun xcresulttool export attachments \
  --path "${RESULT_BUNDLE}" \
  --output-path "${EXPORT_DIR}"

MANIFEST="${EXPORT_DIR}/manifest.json"
if [[ ! -f "${MANIFEST}" ]]; then
  echo "!! Manifest not found at ${MANIFEST}"
  exit 1
fi

echo
echo "==> Copying named attachments into ${OUTPUT_DIR}..."

# The manifest is a list of test runs; each run has an `attachments` array.
# Each attachment carries a `suggestedHumanReadableName` that starts with the
# name we set in Swift (xcresulttool appends `_0_<UUID>.png`) and an
# `exportedFileName` pointing to the actual PNG inside EXPORT_DIR.
copy_count=0
for scenario in "${SCENARIOS[@]}"; do
  # Find the most recent attachment whose human-readable name starts with the
  # scenario id and exports a PNG (matches across re-runs of the same test).
  exported=$(
    jq -r --arg prefix "${scenario}_" '
      [
        .[]
        | .attachments[]?
        | select(
            (.suggestedHumanReadableName | startswith($prefix))
            and (.exportedFileName | test("\\.png$"))
          )
        | .exportedFileName
      ]
      | last // empty
    ' "${MANIFEST}"
  )

  if [[ -z "${exported}" ]]; then
    echo "   - ${scenario}: no attachment found (test may have failed)"
    continue
  fi

  src="${EXPORT_DIR}/${exported}"
  dst="${OUTPUT_DIR}/${scenario}.png"
  if [[ ! -f "${src}" ]]; then
    echo "   - ${scenario}: exported file missing at ${src}"
    continue
  fi

  cp "${src}" "${dst}"
  if [[ "${scenario}" == "ctfLobby" ]]; then
    strip_ctf_lobby_top_tip "${dst}"
  fi
  echo "   + ${scenario}.png  <-  ${exported}"
  copy_count=$((copy_count + 1))
done

echo
echo "==> Copied ${copy_count} screenshot(s) into ${OUTPUT_DIR}"

if [[ ${copy_count} -lt ${#SCENARIOS[@]} ]]; then
  echo "!! Not every scenario was captured. Review the xcresult bundle:"
  echo "     open ${RESULT_BUNDLE}"
  exit 2
fi

echo "==> Done."
