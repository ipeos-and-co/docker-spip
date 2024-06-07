#!/bin/bash
set -euo pipefail

declare -A spipVersions=(
  [0]='4.1'
  [1]='4.2'
  [2]='4.3'
)
declare -A phpVersions=(
  [4.1]='8.1'
  [4.2]='8.2'
  [4.3]='8.3'
)
declare -A spipPackages=(
	[4.1]='4.1.17'
	[4.2]='4.2.14'
	[4.3]='4.3.0-beta'
)

for spipVersion in "${spipVersions[@]}"; do
  mkdir -p "./${spipVersion}"

  (
    set -x

    sed -r \
      -e 's!%%PHP_VERSION%%!'"${phpVersions[$spipVersion]}"'!g' \
      -e 's!%%SPIP_VERSION%%!'"${spipVersion}"'!g' \
      -e 's!%%SPIP_PACKAGE%%!'"${spipPackages[$spipVersion]}"'!g' \
      "Dockerfile.tpl" > "./${spipVersion}/Dockerfile"

    cp -a ./docker-entrypoint.sh "./${spipVersion}/docker-entrypoint.sh"
    chmod +x "./${spipVersion}/docker-entrypoint.sh"
  )
done
