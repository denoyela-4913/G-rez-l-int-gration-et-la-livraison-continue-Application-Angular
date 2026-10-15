# Backlog / éléments différés

Ce qui a été repéré mais pas traité, avec le contexte, pour ne pas le perdre.

## Manifestes Kubernetes : `TODO` à compléter

**Choix retenu : GitHub et GitHub Actions** pour le dépôt, la CI et le registre d'images (GitHub
Container Registry, `ghcr.io`). Les commentaires `TODO` des manifestes parlent de GitLab : ils
viennent du modèle d'exercice et sont à lire comme « registre d'images ». GitLab CI reste
uniquement un sujet de comparaison dans [learning/](learning/README.md).

- [k8s/deployment-app.yaml:17](k8s/deployment-app.yaml#L17) : renseigner l'image tirée de GHCR
  (`ghcr.io/<utilisateur>/<dépôt>:<tag>`). Elle doit d'abord être construite et poussée par un
  job de [ci.yml](.github/workflows/ci.yml) (job `build` ajouté, avec `permissions: packages: write`).
- [k8s/deployment-app.yaml:20](k8s/deployment-app.yaml#L20) : définir `imagePullSecrets` (secret
  de type `docker-registry`) pour autoriser Kubernetes à tirer l'image d'un registre privé. Le
  `GITHUB_TOKEN` expire avec le job : il faut un Personal Access Token avec le droit
  `read:packages`. Inutile si le paquet GHCR est public.
- [values.tpl.yaml](values.tpl.yaml) : valeurs `image`, `port` et `imagePullSecret` vides,
  à renseigner (le port est 8080, déjà aligné dans `k8s/`).
