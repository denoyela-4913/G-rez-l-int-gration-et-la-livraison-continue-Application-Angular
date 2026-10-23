#!/bin/bash
# Raccourci : install de staging. Voir helm-deploy.sh pour le détail et les paramètres.
exec "$(dirname "$0")/helm-deploy.sh" install staging
