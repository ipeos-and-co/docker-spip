#!/bin/bash
set -euo pipefail

declare -A spipVersions=(
  [0]='3.1'
  [1]='3.2'
)
declare -A phpVersions=(
  [3.1]='7.2'
  [3.2]='7.4'
)
declare -A spipPackages=(
  [3.1]='3.1.15'
  [3.2]='3.2.11'
)
declare -A mysqlPackages=(
  [3.1]='mysqli'
  [3.2]='mysqli'
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
