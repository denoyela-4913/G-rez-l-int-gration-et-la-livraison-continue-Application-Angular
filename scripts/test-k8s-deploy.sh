#!/bin/bash
# Teste le déploiement Kubernetes (k8s/) sur Minikube : déploie l'application dans un namespace
# jetable, vérifie qu'elle répond par le Service LoadBalancer (page d'accueil, repli vers index.html,
# fichier de données), qu'elle ne tourne pas en root et que Kubernetes recrée son pod s'il est supprimé,
# puis supprime le namespace.
# Usage : scripts/test-k8s-deploy.sh [--pause] [--keep]
#   --pause : attend la touche Entrée entre chaque étape (pour suivre pas à pas).
#   --keep  : ne supprime pas le namespace à la fin (pour inspecter le cluster à la main).
# Prérequis : kubectl, Minikube démarré et "minikube tunnel" lancé dans un autre terminal (sans le
# tunnel, le Service LoadBalancer n'a pas d'adresse externe). Le script les vérifie et, s'il manque
# quelque chose, affiche les commandes à lancer.
# Le port du Service (8080) doit être libre sur la machine : le tunnel l'y publie.
# Codes de sortie : 0 = tout est bon, 1 = usage incorrect, 2 = prérequis manquant, 3 = un test a échoué.
set -euo pipefail
cd "$(dirname "$0")/.."

PAUSE=false
KEEP=false
for arg in "$@"; do
	case "$arg" in
		--pause) PAUSE=true ;;
		--keep) KEEP=true ;;
		*)
			echo "Usage : $0 [--pause] [--keep]" >&2
			exit 1
			;;
	esac
done

NS="olympic-test-$RANDOM"
APP="deploy/olympic-games-app-deployment"
SVC="olympic-games-app-service"
PASS=0
FAIL=0

pause() {
	if $PAUSE; then
		read -r -p "Entrée pour continuer... "
	fi
}

step() {
	echo
	echo "== $*"
	pause
}

ok() {
	echo "  OK     $*"
	PASS=$((PASS + 1))
}

ko() {
	echo "  ECHEC  $*"
	FAIL=$((FAIL + 1))
}

# check "description" commande... : OK si la commande réussit, ECHEC sinon.
check() {
	local description="$1"
	shift
	if "$@" >/dev/null 2>&1; then
		ok "$description"
	else
		ko "$description"
	fi
}

# ---------- Prérequis ----------
# On accumule les manques pour les afficher tous d'un coup, puis on s'arrête avant de toucher au cluster.
MISSING=()

if ! command -v kubectl >/dev/null 2>&1; then
	MISSING+=("kubectl est absent. Installation : https://kubernetes.io/docs/tasks/tools/")
fi
if ! command -v minikube >/dev/null 2>&1; then
	MISSING+=("minikube est absent. Installation : https://minikube.sigs.k8s.io/docs/start/")
elif ! minikube status >/dev/null 2>&1; then
	MISSING+=("Minikube n'est pas démarré. Lancer :  minikube start")
elif command -v kubectl >/dev/null 2>&1 && [ "$(kubectl config current-context 2>/dev/null)" != "minikube" ]; then
	# Garde-fou : ce script crée et supprime des ressources, il ne doit viser que Minikube.
	MISSING+=("Le contexte kubectl actuel n'est pas \"minikube\" (c'est \"$(kubectl config current-context 2>/dev/null)\"). Lancer :  kubectl config use-context minikube")
fi
# Le motif est ancré sur le DÉBUT de la ligne de commande : sans cela, tout processus dont la ligne de
# commande contient seulement le texte "minikube tunnel" (un shell, un éditeur...) serait pris pour le tunnel.
if command -v minikube >/dev/null 2>&1 && ! pgrep -f "^(/[^ ]*/)?minikube tunnel" >/dev/null 2>&1; then
	MISSING+=("Le tunnel Minikube n'est pas lancé. Dans un AUTRE terminal, lancer et laisser ouvert :  minikube tunnel")
fi

if [ ${#MISSING[@]} -gt 0 ]; then
	echo "Prérequis manquants :" >&2
	for message in "${MISSING[@]}"; do
		echo "  - $message" >&2
	done
	echo "Puis relancer : $0" >&2
	exit 2
fi

# Quoi qu'il arrive (succès ou échec), le namespace de test est supprimé à la sortie, sauf avec --keep.
cleanup() {
	if $KEEP; then
		echo
		echo "Namespace conservé : $NS   (suppression : kubectl delete namespace $NS)"
	else
		echo
		echo "Nettoyage : suppression du namespace $NS..."
		kubectl delete namespace "$NS" --wait=true >/dev/null 2>&1 || true
	fi
}
trap cleanup EXIT

# http_code URL [options curl] : affiche le code HTTP de la réponse (000 si pas de réponse).
http_code() {
	curl -s -o /dev/null -w '%{http_code}' --max-time 5 "$@" 2>/dev/null || true
}

# wait_http_200 URL : attend jusqu'à 60 s que l'URL réponde 200.
wait_http_200() {
	local i
	for i in $(seq 1 30); do
		[ "$(http_code "$1")" = "200" ] && return 0
		sleep 2
	done
	return 1
}

# ---------- Déploiement ----------
step "Déploiement de k8s/ dans le namespace $NS"
kubectl create namespace "$NS" >/dev/null
kubectl apply -n "$NS" -f k8s/
check "l'application est prête (rollout)" kubectl rollout status -n "$NS" "$APP" --timeout=180s

# ---------- Accès par le LoadBalancer ----------
step "Adresse externe du Service (fournie par minikube tunnel)"
IP=""
for _ in $(seq 1 30); do
	IP=$(kubectl get svc -n "$NS" "$SVC" -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
	[ -n "$IP" ] && break
	sleep 2
done
if [ -z "$IP" ]; then
	ko "le Service n'a pas d'adresse externe : le tunnel ne fonctionne pas (relancer : minikube tunnel)"
	echo
	echo "Résultat : $PASS réussi(s), $FAIL échec(s)" >&2
	exit 3
fi
PORT=$(kubectl get svc -n "$NS" "$SVC" -o jsonpath='{.spec.ports[0].port}')
ok "adresse externe : $IP:$PORT"
URL="http://$IP:$PORT"

# ---------- Tests fonctionnels ----------
step "L'application répond par le LoadBalancer"
check "GET / répond 200" wait_http_200 "$URL/"
check "GET / renvoie bien la page de l'application Angular (<app-root>)" \
	bash -c "curl -s --max-time 5 '$URL/' | grep -q '<app-root'"
# Une adresse qui n'est pas un fichier doit aussi répondre 200 : Nginx renvoie index.html (try_files)
# et c'est ensuite Angular, dans le navigateur, qui décide quelle page afficher.
check "une route inconnue répond 200 (repli vers index.html)" \
	test "$(http_code "$URL/une-route-angular-quelconque")" = "200"
# L'application n'a ni base ni API : elle lit ce fichier JSON, qui doit donc être servi par l'image.
check "GET /assets/mock/olympic.json répond 200 et contient du JSON" \
	bash -c "curl -s --max-time 5 '$URL/assets/mock/olympic.json' | python3 -c 'import sys, json; json.load(sys.stdin)'"

step "Sécurité : le conteneur ne doit pas tourner en root"
check "l'UID du conteneur est 10002 (utilisateur \"app\" du Dockerfile)" \
	test "$(kubectl exec -n "$NS" "$APP" -- id -u)" = "10002"

# ---------- Résilience ----------
step "Suppression du pod : Kubernetes doit le recréer"
OLD_POD=$(kubectl get pod -n "$NS" -l app=olympic-games-app -o jsonpath='{.items[0].metadata.name}')
kubectl delete pod -n "$NS" "$OLD_POD" >/dev/null
check "l'application est de nouveau prête" kubectl rollout status -n "$NS" "$APP" --timeout=120s
check "le pod a bien été remplacé par un nouveau" \
	test "$(kubectl get pod -n "$NS" -l app=olympic-games-app --field-selector=status.phase=Running -o jsonpath='{.items[0].metadata.name}')" != "$OLD_POD"
check "l'application répond de nouveau 200" wait_http_200 "$URL/"

# ---------- Résultat ----------
echo
echo "Résultat : $PASS réussi(s), $FAIL échec(s)"
if [ "$FAIL" -gt 0 ]; then
	echo "Pour diagnostiquer : relancer avec --keep, puis  kubectl logs -n <namespace> $APP" >&2
	exit 3
fi
