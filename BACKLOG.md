# Backlog / éléments différés

Ce qui a été repéré mais pas traité, avec le contexte, pour ne pas le perdre.

## Manifestes Kubernetes : ports incohérents avec l'image (à corriger)

**Statut : repéré, non corrigé.** L'image Docker tourne désormais sans root et Nginx écoute sur
**8080** ([nginx/nginx.conf](nginx/nginx.conf), `EXPOSE 8080` dans le [Dockerfile](Dockerfile)),
car un utilisateur non-root ne peut pas écouter sur un port < 1024. Les manifestes déclarent
encore le port **80** :

- [k8s/deployment-app.yaml:19](k8s/deployment-app.yaml#L19) : `containerPort: 80` -> `8080`.
- [k8s/service-app.yaml:10-11](k8s/service-app.yaml#L10-L11) : `port: 80` peut rester (port
  exposé à l'extérieur), mais `targetPort: 80` doit passer à `8080`.

Conséquence si on ne corrige pas : le Service enverrait le trafic vers un port où personne
n'écoute (connexion refusée).

## Manifestes Kubernetes : `TODO` à compléter

**Choix retenu : GitHub et GitHub Actions** pour le dépôt, la CI et le registre d'images (GitHub
Container Registry, `ghcr.io`). Les commentaires `TODO` des manifestes parlent de GitLab : ils
viennent du modèle d'exercice et sont à lire comme « registre d'images ». GitLab CI reste
uniquement un sujet de comparaison dans [learning/](learning/README.md).

- [k8s/deployment-app.yaml:17](k8s/deployment-app.yaml#L17) : renseigner l'image tirée de GHCR
  (`ghcr.io/<utilisateur>/<dépôt>:<tag>`). Elle doit d'abord être construite et poussée par un
  job de [ci.yml](.github/workflows/ci.yml) (à ajouter, avec `permissions: packages: write`).
- [k8s/deployment-app.yaml:20](k8s/deployment-app.yaml#L20) : définir `imagePullSecrets` (secret
  de type `docker-registry`) pour autoriser Kubernetes à tirer l'image d'un registre privé. Le
  `GITHUB_TOKEN` expire avec le job : il faut un Personal Access Token avec le droit
  `read:packages`. Inutile si le paquet GHCR est public.
- [values.tpl.yaml](values.tpl.yaml) : valeurs `image`, `port` et `imagePullSecret` vides,
  à renseigner (le port doit être 8080, voir ci-dessus).

## À vérifier : build Docker de l'image non-root

Le build avec `node:24-alpine`, l'utilisateur UID 10002 et Nginx sur 8080 n'a pas été validé
de bout en bout : la dernière tentative a été interrompue (code 137, manque de mémoire dans
WSL2). À relancer avec `docker compose up -d`, puis vérifier `http://localhost` et
`docker exec <conteneur> id` (doit afficher `uid=10002`).
