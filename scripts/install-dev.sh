#!/bin/bash
# Raccourci : install de dev. Voir helm-deploy.sh pour le détail et les paramètres.
exec "$(dirname "$0")/helm-deploy.sh" install dev
