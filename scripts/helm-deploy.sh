#!/bin/bash
# Installe ou met à jour l'environnement dev ou staging (olympic-games) avec Helm.
# Usage : scripts/helm-deploy.sh <install|upgrade> <dev|staging>
#   install : première installation ; --create-namespace crée le namespace, qui n'existe pas encore.
#   upgrade : applique un nouveau tag d'image ou de nouvelles valeurs à une release déjà installée.
# Raccourcis : install-dev.sh, upgrade-dev.sh, install-staging.sh, upgrade-staging.sh.
# Le tag de l'image dans values-dev.yaml suit chaque release (mis à jour par la CI) ; celui de
# values-staging.yaml est promu à la main.
# À lancer depuis n'importe où : le script se place à la racine du dépôt.
set -euo pipefail
cd "$(dirname "$0")/.."

ACTION=${1:-}
ENVIRONMENT=${2:-}

# Paramètres propres à chaque environnement : le seul endroit où dev et staging diffèrent.
RELEASE=olympic
CHART=charts/olympic-games
case "$ENVIRONMENT" in
  dev)     NAMESPACE=olympic-dev ;;
  staging) NAMESPACE=olympic-staging ;;
  *)
    echo "Usage : $0 <install|upgrade> <dev|staging>" >&2
    exit 1
    ;;
esac
VALUES=$CHART/values-$ENVIRONMENT.yaml

# Options propres à chaque action.
case "$ACTION" in
  install) LABEL="Installation"; ACTION_ARGS=(--create-namespace) ;;
  upgrade) LABEL="Mise à jour";  ACTION_ARGS=() ;;
  *)
    echo "Usage : $0 <install|upgrade> <dev|staging>" >&2
    exit 1
    ;;
esac

echo "$LABEL de $RELEASE dans le namespace $NAMESPACE (valeurs : $VALUES)..."
helm "$ACTION" "$RELEASE" "$CHART" \
  -f "$VALUES" \
  -n "$NAMESPACE" \
  ${ACTION_ARGS[@]+"${ACTION_ARGS[@]}"}

echo
echo "$LABEL terminée. Suivre le démarrage : kubectl get pods -n $NAMESPACE -w"
