#!/bin/bash
# Raccourci : upgrade de dev. Voir helm-deploy.sh pour le détail et les paramètres.
exec "$(dirname "$0")/helm-deploy.sh" upgrade dev
