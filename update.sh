#!/bin/bash
set -euo pipefail

declare -A spipVersions=(
  [0]='4.4'
)
declare -A phpVersions=(
  [4.4]='8.4'
)
declare -A osVersions=(
  [4.4]='trixie'
)
declare -A spipPackages=(
	[4.4]='4.4.19'
)
declare -A spipCliVersions=(
	[4.4]='2.0.1'
)

for spipVersion in "${spipVersions[@]}"; do
  mkdir -p "./${spipVersion}"

  spipPackage="${spipPackages[$spipVersion]}"

  # Compute the sha256 of the official SPIP archive (SPIP publishes no checksum)
  # so the generated Dockerfile can verify its download
  echo "Fetching spip-v${spipPackage}.zip to compute its sha256..."
  tmpZip="$(mktemp)"
  curl -fsSL -o "${tmpZip}" "https://files.spip.net/spip/archives/spip-v${spipPackage}.zip"
  spipSha256="$(sha256sum "${tmpZip}" | cut -d ' ' -f 1)"
  rm -f "${tmpZip}"

  (
    set -x

    sed -r \
      -e 's!%%PHP_VERSION%%!'"${phpVersions[$spipVersion]}"'!g' \
      -e 's!%%OS_VERSION%%!'"${osVersions[$spipVersion]}"'!g' \
      -e 's!%%SPIP_VERSION%%!'"${spipVersion}"'!g' \
      -e 's!%%SPIP_PACKAGE%%!'"${spipPackage}"'!g' \
      -e 's!%%SPIP_SHA256%%!'"${spipSha256}"'!g' \
      -e 's!%%SPIP_CLI_VERSION%%!'"${spipCliVersions[$spipVersion]}"'!g' \
      "Dockerfile.tpl" > "./${spipVersion}/Dockerfile"

    cp -a ./docker-entrypoint.sh "./${spipVersion}/docker-entrypoint.sh"
    chmod +x "./${spipVersion}/docker-entrypoint.sh"

    # Keep the README supported-tags line in sync with the package version
    sed -i -E 's!'"${spipVersion//./\\.}"'\.[0-9]+!'"${spipPackage}"'!g' README.md
  )
done
