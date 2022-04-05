#!/bin/bash
set -euo pipefail

declare -A spipVersions=(
  [0]='3.2'
  [1]='4.0'
)
declare -A phpVersions=(
  [3.2]='7.4'
  [4.0]='7.4'
)
declare -A spipPackages=(
	[3.2]='3.2.14'
	[4.0]='4.0.6'
)
declare -A mysqlPackages=(
  [3.2]='mysqli'
  [4.0]='mysqli'
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
      "Dockerfile${phpVersions[$spipVersion]}.tpl" > "./${spipVersion}/Dockerfile"

    cp -a ./docker-entrypoint.sh "./${spipVersion}/docker-entrypoint.sh"
    chmod +x "./${spipVersion}/docker-entrypoint.sh"
  )
done
