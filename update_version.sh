#!/bin/bash
# Met à jour le tag de l'image dans values-dev.yaml : dev suit chaque release, staging reste promu à la main.
# (La version de package.json et package-lock.json est mise à jour par le plugin npm de semantic-release.)
# Usage : ./update_version.sh 0.3.0
set -euo pipefail
cd "$(dirname "$0")"

if [ $# -ne 1 ] || ! [[ "$1" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
	echo "Usage : $0 X.Y.Z   (exemple : $0 0.3.0)" >&2
	exit 1
fi
VERSION="$1"

sed -i -E "s#^(  image: .*:)[0-9]+\.[0-9]+\.[0-9]+\$#\1${VERSION}#" charts/olympic-games/values-dev.yaml

echo "Version mise à jour :"
grep -n "^  image: " charts/olympic-games/values-dev.yaml
