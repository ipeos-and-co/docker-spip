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
	[4.4]='4.4.28'
)
declare -A spipCliVersions=(
	[4.4]='2.0.1'
)

for spipVersion in "${spipVersions[@]}"; do
  mkdir -p "./${spipVersion}"

  spipPackage="${spipPackages[$spipVersion]}"
  phpVersion="${phpVersions[$spipVersion]}"
  osVersion="${osVersions[$spipVersion]}"
  spipCliVersion="${spipCliVersions[$spipVersion]}"

  # Epingle l'image de base par empreinte : le tag est une reference mutable.
  baseRef="php:${phpVersion}-apache-${osVersion}"
  echo "Resolving digest of ${baseRef}..."
  # NB: --format est ignore par certaines versions de Docker, qui deversent le manifeste
  # entier ; on lit la ligne Digest: et on valide la forme.
  baseDigest="$(docker buildx imagetools inspect "${baseRef}" 2>/dev/null \
    | awk '/^Digest:/ { print $2; exit }' || true)"
  if [[ ! "${baseDigest}" =~ ^sha256:[0-9a-f]{64}$ ]]; then
    baseDigest=""
  fi
  if [[ -z "${baseDigest}" ]]; then
    echo >&2 "WARNING: could not resolve the digest of ${baseRef} (docker buildx unavailable?)."
    echo >&2 "         The generated Dockerfile will use the mutable tag."
    baseImage="${baseRef}"
  else
    baseImage="${baseRef}@${baseDigest}"
  fi
  echo "Base image: ${baseImage}"

  # Idem pour spip-cli : le Dockerfile verifie apres clonage qu'il obtient ce commit.
  echo "Resolving commit of spip-cli ${spipCliVersion}..."
  # Sur un tag annote, `refs/tags/X` designe l'objet-tag et `refs/tags/X^{}` le commit :
  # c'est le second que `git rev-parse HEAD` renvoie dans le clone.
  spipCliCommit="$(git ls-remote https://git.spip.net/spip-contrib-outils/spip-cli.git \
    "refs/tags/${spipCliVersion}^{}" "refs/tags/${spipCliVersion}" \
    | awk '$2 ~ /\^\{\}$/ { peeled = $1 } $2 !~ /\^\{\}$/ { plain = $1 } \
           END { print (peeled != "" ? peeled : plain) }')"
  if [[ ! "${spipCliCommit}" =~ ^[0-9a-f]{40}$ ]]; then
    echo >&2 "ERROR: unable to resolve tag ${spipCliVersion} of spip-cli (got '${spipCliCommit}')."
    exit 1
  fi
  echo "spip-cli ${spipCliVersion} -> ${spipCliCommit}"

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
      -e 's!%%BASE_IMAGE%%!'"${baseImage}"'!g' \
      -e 's!%%PHP_VERSION%%!'"${phpVersion}"'!g' \
      -e 's!%%OS_VERSION%%!'"${osVersion}"'!g' \
      -e 's!%%SPIP_VERSION%%!'"${spipVersion}"'!g' \
      -e 's!%%SPIP_PACKAGE%%!'"${spipPackage}"'!g' \
      -e 's!%%SPIP_SHA256%%!'"${spipSha256}"'!g' \
      -e 's!%%SPIP_CLI_VERSION%%!'"${spipCliVersion}"'!g' \
      -e 's!%%SPIP_CLI_COMMIT%%!'"${spipCliCommit}"'!g' \
      "Dockerfile.tpl" > "./${spipVersion}/Dockerfile"

    cp -a ./docker-entrypoint.sh "./${spipVersion}/docker-entrypoint.sh"
    chmod +x "./${spipVersion}/docker-entrypoint.sh"
    cp -a ./spip-hardening.conf "./${spipVersion}/spip-hardening.conf"

    # Keep the README supported-tags line in sync with the package version
    sed -i -E 's!'"${spipVersion//./\\.}"'\.[0-9]+!'"${spipPackage}"'!g' README.md
  )
done
