#!/bin/bash
# Teste une image publiée sur GHCR : la télécharge, la lance (Nginx sur le port 8080), vérifie qu'elle
# répond, que le repli vers index.html fonctionne et qu'elle ne tourne pas en root, puis nettoie.
# Usage : scripts/test-ghcr-image.sh [--pause] ghcr.io/<utilisateur>/<image>:<tag>
#   --pause : attend la touche Entrée entre chaque étape (pour suivre pas à pas).
# Attention : à la fin, le conteneur est supprimé et l'image locale est supprimée (docker rmi).
set -euo pipefail

PAUSE=false
if [ "${1:-}" = "--pause" ]; then
	PAUSE=true
	shift
fi

IMAGE="${1:-}"
if [ -z "$IMAGE" ]; then
	echo "Usage : $0 [--pause] <IMAGE>   (exemple : ghcr.io/user/image:main)" >&2
	exit 1
fi
if [[ "$IMAGE" != ghcr.io/* ]]; then
	echo "Ce n'est pas une image GHCR (elle doit commencer par ghcr.io/) : $IMAGE" >&2
	exit 2
fi

CONTAINER=front

pause() {
	if $PAUSE; then
		read -r -p "Entrée pour continuer... "
	fi
}

# Quoi qu'il arrive (succès ou échec), le conteneur de test est supprimé à la sortie.
cleanup() {
	docker rm -f "$CONTAINER" >/dev/null 2>&1 || true
}
trap cleanup EXIT

echo "Téléchargement de l'image depuis GHCR..."
pause
if ! docker pull "$IMAGE"; then
	echo "Image introuvable : $IMAGE" >&2
	exit 3
fi

echo "Lancement du conteneur..."
pause
docker run -d --name "$CONTAINER" -p 8080:8080 "$IMAGE"
docker ps --filter "name=$CONTAINER"

echo "Tests..."
pause
curl -fsS --retry 10 --retry-connrefused --retry-delay 2 -I http://localhost:8080/
# Une route inconnue doit aussi répondre 200 : Nginx renvoie index.html et Angular gère le routage.
curl -fsS -o /dev/null -w "route inconnue : HTTP %{http_code}\n" http://localhost:8080/route-bidon
test "$(docker exec "$CONTAINER" id -u)" = "10002" && echo "OK : le conteneur ne tourne pas en root (UID 10002)"

echo "Nettoyage..."
pause
docker rm -f "$CONTAINER"
docker rmi "$IMAGE"
