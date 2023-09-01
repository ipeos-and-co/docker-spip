#!/bin/bash
set -euo pipefail

declare -A spipVersions=(
  [0]='4.1'
  [1]='4.2'
)
declare -A phpVersions=(
  [4.1]='7.4'
  [4.2]='8.1'
)
declare -A spipPackages=(
	[4.1]='4.1.12'
	[4.2]='4.2.5'
)
declare -A mysqlPackages=(
  [4.1]='mysqli'
  [4.2]='mysqli'
)

for spipVersion in "${spipVersions[@]}"; do
  mkdir -p "./${spipVersion}"

  (
    set -x

    sed -r \
      -e 's!%%PHP_VERSION%%!'"${phpVersions[$spipVersion]}"'!g' \
      -e 's!%%SPIP_VERSION%%!'"${spipVersion}"'!g' \
      -e 's!%%SPIP_PACKAGE%%!'"${spipPackages[$spipVersion]}"'!g' \
      -e 's!%%MYSQL_PACKAGE%%!'"${mysqlPackages[$spipVersion]}"'!g' \
      "Dockerfile.tpl" > "./${spipVersion}/Dockerfile"

    cp -a ./docker-entrypoint.sh "./${spipVersion}/docker-entrypoint.sh"
    chmod +x "./${spipVersion}/docker-entrypoint.sh"
  )
done
