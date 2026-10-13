#!/bin/bash
# Exécute les tests unitaires du projet courant et génère un rapport JUnit XML.
# Le même script sert aux projets Spring Boot (Gradle) et Angular (npm) : le type est détecté
# à la racine du projet.
#
# Usage : ./run-tests.sh
# Rapports : test-results/xml/ (JUnit XML, lu par la CI) ; test-results/html/ en plus pour Gradle
# Codes de sortie : 0 = tests OK, 2 = projet ou dépendance introuvable, autre = échec des tests
set -u
cd "$(dirname "$0")"

RESULTS_DIR="test-results"

die() {
	echo "$*" >&2
	exit 2
}

require_cmd() {
	command -v "$1" > /dev/null || die "Dépendance manquante : '$1' n'est pas installé ou pas dans le PATH."
}

detect_project() {
	if [ -f build.gradle ] || [ -f build.gradle.kts ]; then
		echo "gradle"
	elif [ -f angular.json ]; then
		echo "angular"
	else
		return 1
	fi
}

# --- Spring Boot / Gradle ---

# La version est déclarée dans build.gradle et dans le Dockerfile : elles doivent être identiques.
# Pour la modifier, utiliser ./update_version.sh
check_version() {
	local gradle_version docker_version
	gradle_version=$(sed -n -E "s/^version = '([^']*)'.*/\1/p" build.gradle)
	docker_version=$(sed -n -E 's/^ARG APP_VERSION=(.*)/\1/p' Dockerfile)

	if [ -z "$gradle_version" ] || [ "$gradle_version" != "$docker_version" ]; then
		echo "Versions incohérentes : build.gradle='${gradle_version}', Dockerfile='${docker_version}'" >&2
		echo "Utilisez ./update_version.sh X.Y.Z pour les remettre d'accord." >&2
		return 1
	fi
}

test_gradle() {
	require_cmd java
	[ -x ./gradlew ] || die "Dépendance manquante : ./gradlew introuvable ou non exécutable."
	check_version || exit 1

	./gradlew clean test
}

# --- Angular / npm ---

# Karma lance Chrome en mode headless : on repère un navigateur si CHROME_BIN n'est pas défini.
find_browser() {
	local candidate
	if [ -n "${CHROME_BIN:-}" ]; then
		[ -x "$CHROME_BIN" ] || die "CHROME_BIN='$CHROME_BIN' n'est pas exécutable."
		return
	fi
	for candidate in google-chrome google-chrome-stable chromium chromium-browser; do
		if command -v "$candidate" > /dev/null; then
			export CHROME_BIN
			CHROME_BIN="$(command -v "$candidate")"
			return
		fi
	done
	die "Dépendance manquante : aucun navigateur Chrome/Chromium trouvé (définir CHROME_BIN)."
}

test_angular() {
	require_cmd node
	require_cmd npm
	find_browser

	# npm ci : installation reproductible depuis package-lock.json (recommandée en CI)
	if [ ! -d node_modules ]; then
		echo "node_modules absent : npm ci"
		npm ci || die "Échec de npm ci."
	fi

	npm test
}

# --- Programme principal ---

TYPE=$(detect_project) || die "Type de projet inconnu : ni build.gradle ni angular.json à la racine."
echo "Projet détecté : ${TYPE}"

# Nettoyage des rapports précédents
rm -rf "$RESULTS_DIR"

"test_${TYPE}"
RES=$?

if [ "$RES" -eq 0 ]; then
	echo "Tous les tests sont passés (rapports : ${RESULTS_DIR}/)"
else
	echo "Échec des tests (code $RES)" >&2
fi

exit "$RES"
