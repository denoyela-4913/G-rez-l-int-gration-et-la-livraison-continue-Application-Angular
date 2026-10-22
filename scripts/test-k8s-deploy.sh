#!/bin/bash
# Teste le déploiement Kubernetes (k8s/) sur Minikube : déploie l'application dans un namespace
# jetable, vérifie qu'elle répond par le Service LoadBalancer (page d'accueil, repli vers index.html,
# fichier de données), qu'elle ne tourne pas en root et que Kubernetes recrée son pod s'il est supprimé,
# puis supprime le namespace.
# Usage : scripts/test-k8s-deploy.sh [--pause] [--keep] [--helm dev|staging]
#   --pause : attend la touche Entrée entre chaque étape (pour suivre pas à pas).
#   --keep  : ne supprime pas le namespace à la fin (pour inspecter le cluster à la main).
#   --helm  : déploie avec le chart Helm (charts/olympic-games) et le fichier de valeurs de l'environnement
#             donné (values-dev.yaml ou values-staging.yaml), au lieu des manifestes de k8s/.
#             Le Service de staging est sur le port 8081 (non privilégié : pas de sudo pour le tunnel).
# Prérequis : kubectl, Minikube démarré et "minikube tunnel" lancé dans un autre terminal (sans le
# tunnel, le Service LoadBalancer n'a pas d'adresse externe). Le script les vérifie et, s'il manque
# quelque chose, affiche les commandes à lancer.
# Avec k8s/ ou --helm dev, le Service est sur le port 80 de la machine, un port privilégié (< 1024) : au
# lancement, le tunnel demande le mot de passe sudo, il faut le saisir (sinon le port n'est pas publié).
# Le mot de passe est redemandé quand le cache sudo expire et qu'une nouvelle redirection du port 80 est ouverte.
# Attention : si un Ingress existe dans le cluster (addon ingress), il est lui aussi publié sur le
# port 80 ; pendant le test, le Service de l'application le masque, puis il redevient joignable.
# Codes de sortie : 0 = tout est bon, 1 = usage incorrect, 2 = prérequis manquant, 3 = un test a échoué.
set -euo pipefail
cd "$(dirname "$0")/.."

PAUSE=false
KEEP=false
HELM_ENV=""
while [ $# -gt 0 ]; do
	case "$1" in
		--pause) PAUSE=true ;;
		--keep) KEEP=true ;;
		--helm)
			# L'option exige une valeur : sans elle, le script se rabattrait en silence sur k8s/.
			if [ $# -lt 2 ] || [ -z "$2" ]; then
				echo "L'option --helm demande un environnement (dev ou staging)." >&2
				echo "Usage : $0 [--pause] [--keep] [--helm dev|staging]" >&2
				exit 1
			fi
			HELM_ENV="$2"
			shift
			;;
		*)
			echo "Usage : $0 [--pause] [--keep] [--helm dev|staging]" >&2
			exit 1
			;;
	esac
	shift
done
CHART="charts/olympic-games"
if [ -n "$HELM_ENV" ] && [ ! -f "$CHART/values-$HELM_ENV.yaml" ]; then
	echo "Environnement Helm inconnu : \"$HELM_ENV\" (pas de fichier $CHART/values-$HELM_ENV.yaml)." >&2
	echo "Usage : $0 [--pause] [--keep] [--helm dev|staging]" >&2
	exit 1
fi

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
if [ -n "$HELM_ENV" ] && ! command -v helm >/dev/null 2>&1; then
	MISSING+=("helm est absent. Installation : https://helm.sh/docs/intro/install/")
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
	MISSING+=("Le tunnel Minikube n'est pas lancé. Dans un AUTRE terminal, lancer et laisser ouvert :  minikube tunnel
      Le Service est sur le port 80 (privilégié) : le tunnel demande le mot de passe sudo, le saisir dans ce terminal.")
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

# Information : un Ingress existant partage le port 80 de la machine avec ce Service (voir l'en-tête).
if kubectl get ingress -A --no-headers 2>/dev/null | grep -q .; then
	echo "NOTE : un Ingress existe dans le cluster ($(kubectl get ingress -A --no-headers | awk '{print $2}' | paste -sd, -))."
	echo "       Pendant le test il est masqué par le Service de l'application sur le port 80, puis il redevient joignable."
fi

# ---------- Déploiement ----------
if [ -n "$HELM_ENV" ]; then
	step "Déploiement du chart Helm ($HELM_ENV) dans le namespace $NS"
	kubectl create namespace "$NS" >/dev/null
	# --wait : helm attend que les ressources soient prêtes avant de rendre la main.
	helm install olympic "$CHART" -f "$CHART/values-$HELM_ENV.yaml" -n "$NS" --wait --timeout 3m | grep -E "^(NAME|STATUS|REVISION)"
	check "la release Helm est en état \"deployed\"" \
		test "$(helm status olympic -n "$NS" -o json | python3 -c 'import sys, json; print(json.load(sys.stdin)["info"]["status"])')" = "deployed"
else
	step "Déploiement de k8s/ dans le namespace $NS"
	kubectl create namespace "$NS" >/dev/null
	kubectl apply -n "$NS" -f k8s/
fi
check "l'application est prête (rollout)" kubectl rollout status -n "$NS" "$APP" --timeout=180s
check "tous les réplicas sont prêts" \
	test "$(kubectl get "$APP" -n "$NS" -o jsonpath='{.status.readyReplicas}')" = "$(kubectl get "$APP" -n "$NS" -o jsonpath='{.spec.replicas}')"

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

# diagnose : à appeler quand l'application ne répond pas comme attendu. Une adresse externe ne prouve pas
# que le port est réellement publié sur la machine : le tunnel peut l'attribuer sans pouvoir le lier.
diagnose() {
	echo "  Diagnostic :"
	if [ "$(http_code "$URL/")" = "000" ]; then
		echo "    - Rien ne répond sur $IP:$PORT. Causes possibles :"
		echo "      * port < 1024 et tunnel sans droits : l'arrêter (Ctrl+C), le relancer (minikube tunnel) et saisir"
		echo "        le mot de passe sudo quand il le demande ;"
		echo "      * le Service vise un port où le conteneur n'écoute pas (targetPort) : kubectl get endpoints -n $NS"
	else
		echo "    - Quelque chose répond sur $IP:$PORT, mais ce n'est pas l'application (pas de <app-root>) :"
		echo "      soit un autre service occupe ce port (Ingress, autre Service LoadBalancer...), voir :  ss -ltnp | grep ':$PORT '"
		echo "      soit l'image déployée n'est pas la bonne, voir :  kubectl describe pod -n $NS -l app=olympic-games-app"
	fi
}

# ---------- Tests fonctionnels ----------
step "L'application répond par le LoadBalancer"
check "GET / répond 200" wait_http_200 "$URL/"
check "GET / renvoie bien la page de l'application Angular (<app-root>)" \
	bash -c "curl -s --max-time 5 '$URL/' | grep -q '<app-root'"
# Si la page n'est pas celle de l'application, on explique pourquoi (tunnel sans sudo, port occupé).
if ! curl -s --max-time 5 "$URL/" | grep -q '<app-root'; then
	diagnose
fi
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
# Avec plusieurs réplicas, un autre pod encore en place ne prouve rien : on attend que l'ANCIEN ait disparu.
pod_gone() {
	local i
	for i in $(seq 1 30); do
		kubectl get pod -n "$NS" "$OLD_POD" >/dev/null 2>&1 || return 0
		sleep 2
	done
	return 1
}
check "l'ancien pod a bien disparu (remplacé par un nouveau)" pod_gone
check "l'application répond de nouveau 200" wait_http_200 "$URL/"

# ---------- Résultat ----------
echo
echo "Résultat : $PASS réussi(s), $FAIL échec(s)"
if [ "$FAIL" -gt 0 ]; then
	echo "Pour diagnostiquer : relancer avec --keep, puis  kubectl logs -n <namespace> $APP" >&2
	exit 3
fi
