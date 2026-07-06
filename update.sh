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
	[4.4]='4.4.16'
)

for spipVersion in "${spipVersions[@]}"; do
  mkdir -p "./${spipVersion}"

  (
    set -x

    sed -r \
      -e 's!%%PHP_VERSION%%!'"${phpVersions[$spipVersion]}"'!g' \
      -e 's!%%OS_VERSION%%!'"${osVersions[$spipVersion]}"'!g' \
      -e 's!%%SPIP_VERSION%%!'"${spipVersion}"'!g' \
      -e 's!%%SPIP_PACKAGE%%!'"${spipPackages[$spipVersion]}"'!g' \
      "Dockerfile.tpl" > "./${spipVersion}/Dockerfile"

    cp -a ./docker-entrypoint.sh "./${spipVersion}/docker-entrypoint.sh"
    chmod +x "./${spipVersion}/docker-entrypoint.sh"
  )
done
