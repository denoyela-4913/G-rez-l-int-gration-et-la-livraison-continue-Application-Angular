# Olympic Participation Tracker

## Context

The **Olympic Participation Tracker** is an application designed to record and analyze countries' participation in the Olympic Games. It provides statistics on medals obtained by each country, helping users gain insights into historical performance. Although the application is currently in its early development stages, we aim to create a robust and user-friendly tool for Olympic enthusiasts.

## Technical Context

The application is built using **Angular 14.1** and relies on **npm** for package management. Angular offers a powerful framework for creating dynamic web applications, and npm simplifies the process of managing dependencies and scripts.

Summary:

- **NodeJS**: Tested with version 20.11.0
- **NPM**: Tested with version 10.2.4
- **NGINX**: Tested with version 1.27

## Getting Started

### Install dependencies

Run `npm i` in local development to install NodeJS dependencies. If you are installing the app on a CI environment prefer to use `npm ci`. you can also change npm cache directory to your working directory as following

```bash
npm ci --cache .npm --prefer-offline
```

## Development server

Run `ng serve` for a dev server. Navigate to `http://localhost:4200/`. The application will automatically reload if you change any of the source files.

### Build

Run `npm run build` to build the project. The build artifacts will be stored in the `dist/` directory.

### Test

To run tests and ensure the application's functionality, use the following command:

```bash
npm test
```

Our test suite covers critical components, ensuring stability and reliability.

### Packaging

To package the application for distribution, run:

```bash
npm pack
```

This will create a distributable package containing the compiled code and necessary assets.

### Deploy on nginx

To deploy application on nginx web server with docker you can use nginx config located in the `nginx` folder. This one configure the root application folder in the `/app` folder.

After building the app copy the `dist/olympic-games-starter` folder to the root application folder in the docker image.

### Publishing to GitLab Registry

To publish the application to a GitLab registry, follow these steps:

1. **Change Application Scope**:
   - Change the application scope for your new gitlab group. For example, if your repository url is `https://gitlab.com/your-gitlab-group-slug/olympic-games-starter` change the application name to `@your-gitlab-group-slug/olympic-games-starter`
   ```json
   {
      "name": "@your-gitlab-group-slug/olympic-games-starter",
      ...
   }
   ```
2. To publish, you need to create a file named `.npmrc` with the following content :

   ```ini
   @your-gitlab-group-slug:registry=https://gitlab.com/api/v4/projects/${GITLAB_PROJECT_ID}/packages/npm/
   //gitlab.com/api/v4/projects/${GITLAB_PROJECT_ID}/packages/npm/:_authToken="${GITLAB_TOKEN}"
   ```

3. **Set Environment Variables**:
   - Ensure that the following environment variables are specified:
     - `GITLAB_PROJECT_ID`: The ID of your GitLab project.
     - `GITLAB_TOKEN`: Your GitLab deploy token.
4. **Execute the Publish Command**:
   ```bash
   npm publish
   ```
   This will publish the package to your GitLab registry.

## CI : build et publication de l'image Docker

Le workflow `.github/workflows/ci.yml` comporte trois jobs : `test` (tests unitaires), `release`
(calcul de la version, voir « Releases et versions » plus bas) puis `build` (construction, test de
fonctionnement et publication de l'image sur GHCR, le GitHub Container Registry). Les jobs `release` et
`build` ne tournent que sur un `push` de branche (et `release` uniquement sur `main`), après la réussite
de `test`. Les pushs de tags git (`vX.Y.Z`) ne déclenchent pas la CI.

Chaque image reçoit deux tags : `<branche>` (mobile : dernier commit de la branche) et
`<branche>-<sha7>` (immuable : commit exact). Les caractères interdits d'un tag Docker sont remplacés
(`feature/Ma-Branche` devient `feature-ma-branche`). Exemple :
`ghcr.io/<utilisateur>/<dépôt>:main-2f0ba4c`.

Configuration : la variable de dépôt `IMAGE_NAME` (Settings > Secrets and variables > Actions >
Variables) remplace le nom d'image par défaut (le nom du dépôt). Aucun secret à créer : le job utilise
le `GITHUB_TOKEN` avec la permission `packages: write`.

Pour valider le pipeline sans toucher à `main`, pousser une branche de test : l'image est publiée avec
le tag de cette branche.

### Différences entre les projets Angular et Java

| | Angular (Olympic Tracker) | Java (Workshop Organizer) |
|---|---|---|
| Image finale | `nginx:1.27-alpine` + fichiers statiques | `eclipse-temurin:21-jre-alpine` + jar Spring Boot |
| Étape de build dans le Dockerfile | `npm ci` puis `npm run build` | `./gradlew bootJar` |
| Port du conteneur | 8080 (Nginx) | 8080 (Spring Boot) |
| Utilisateur non-root (UID) | 10002 | 10001 |
| Dépendance au runtime | aucune | PostgreSQL (service `db`) |
| Test de fonctionnement en CI | `docker run`, puis `curl` sur `/`, sur une route inconnue (repli vers `index.html`) et sur `/assets/mock/olympic.json`, et contrôle de l'UID | `docker compose up --no-build --wait` (app + db) puis `curl` sur `/` et contrôle de l'UID |
| Version applicative | `version` de `package.json` (mise à jour par la CI) ; l'image reçoit le tag `X.Y.Z` | `ARG APP_VERSION` du Dockerfile (jar nommé d'après `build.gradle`) |

### Local et CI : ce qui diffère

- La CI part d'un runner vierge : aucun cache de couches Docker, donc la première construction est plus
  longue qu'en local.
- Le nom d'image est calculé à partir du dépôt et mis en minuscules (GHCR l'exige). En local,
  `docker compose` utilise un nom court (`olympic-games-tracker`, `workshop-organizer`).
- Le test de la CI exécute l'image qui sera publiée (et non une reconstruction) : ce qui est testé est
  ce qui est livré.

## Releases et versions

La version de l'application est calculée automatiquement par
[semantic-release](https://semantic-release.org/) à chaque push sur `main`, à partir des messages de
commit. Elle n'est plus modifiée à la main : `version` dans `package.json` et `package-lock.json` est mise
à jour par la CI.

### Écrire ses messages de commit

Le format est `type: description` (Conventional Commits). Le type décide de la version suivante :

| Message de commit | Effet | Exemple (depuis 0.1.3) |
|---|---|---|
| `fix: ...` | version corrective (patch) | 0.1.4 |
| `feat: ...` | nouvelle fonctionnalité (minor) | 0.2.0 |
| `feat!: ...` ou `BREAKING CHANGE:` dans le corps | changement cassant (major) | 1.0.0 |
| `docs:`, `ci:`, `chore:`, `test:`, `build:`, `refactor:` | aucune release | inchangée |

Un push sur `main` sans `feat:` ni `fix:` depuis le dernier tag ne crée donc aucune version. Attention : un
changement de CI qui ne touche pas à l'application doit être commité en `ci:`, pas en `fix(ci):`, sinon il
publie une nouvelle version.

### Ce que fait la CI à chaque release

1. Le job `release` crée le commit `chore(release): X.Y.Z [skip ci]` (mise à jour de `package.json` et
   `package-lock.json`), le tag `vX.Y.Z` et la release GitHub avec ses notes. Rien n'est publié sur npm.
2. Le job `build` construit ce tag et publie l'image avec ses tags habituels et le tag `X.Y.Z`.

Le `[skip ci]` empêche la CI de se relancer sur le commit de version. Après une release, penser à faire
`git pull` avant de pousser : la CI a ajouté un commit sur `main`.

### Simuler une release sans rien créer

```bash
GITHUB_TOKEN=$(gh auth token) npx --yes -p semantic-release@25.0.9 \
  -p @semantic-release/commit-analyzer@13.0.1 -p @semantic-release/release-notes-generator@14.1.1 \
  -p @semantic-release/npm@13.2.0 -p @semantic-release/exec@7.1.0 \
  -p @semantic-release/git@11.0.1 -p @semantic-release/github@12.0.10 \
  -p conventional-changelog-conventionalcommits@9.3.1 \
  semantic-release --dry-run --no-ci
```

Il affiche la version qui serait créée (ou « no release »). Il doit être lancé depuis `main`.

## Déploiement sur Kubernetes (Minikube) et Helm

Deux façons de déployer l'application, qui donnent le même résultat en environnement de développement :

| | Dossier | Quand l'utiliser |
|---|---|---|
| Manifestes | `k8s/` | déploiement direct : `kubectl apply -f k8s/` |
| Chart Helm | `charts/olympic-games/` | plusieurs environnements (dev, staging) avec des valeurs différentes |

Le rendu du chart avec `values-dev.yaml` est identique aux manifestes de `k8s/` (hors étiquettes).

### Le chart Helm

Le schéma des valeurs reprend celui de `values.tpl.yaml` (`app.image`, `app.port`, `app.imagePullSecret`),
complété par `app.replicas` et `service.*`.

| Valeur | `values-dev.yaml` | `values-staging.yaml` | Rôle |
|---|---|---|---|
| `app.image` | `...:0.2.0` | `...:0.2.0` | image complète, **tag compris** ; obligatoire (le chart refuse de s'installer sans) |
| `app.replicas` | 1 | 2 | nombre de pods |
| `service.port` | 80 | 8081 | port du Service sur la machine |
| `app.imagePullSecret` | (vide) | (vide) | Secret de type docker-registry, pour un registre **privé** ; le paquet GHCR étant public, il n'est pas utilisé |

Staging est sur le port **8081** pour que dev et staging puissent être installés et joignables en même
temps : avec `minikube tunnel`, deux Services sur le même port se partagent le même port de la machine,
et l'un masque l'autre.

```bash
helm install olympic charts/olympic-games -f charts/olympic-games/values-dev.yaml -n olympic-dev --create-namespace
helm install olympic charts/olympic-games -f charts/olympic-games/values-staging.yaml -n olympic-staging --create-namespace
helm list -A                                  # releases installées
helm upgrade olympic charts/olympic-games -f charts/olympic-games/values-staging.yaml -n olympic-staging --set app.replicas=3
helm history olympic -n olympic-staging       # révisions
helm rollback olympic 1 -n olympic-staging    # retour à la révision 1
helm uninstall olympic -n olympic-dev
```

Vérifier un chart sans rien installer : `helm lint charts/olympic-games -f charts/olympic-games/values-dev.yaml`
(syntaxe) et `helm template olympic charts/olympic-games -f charts/olympic-games/values-dev.yaml` (rendu).

### Mettre à jour la version déployée

Le tag de l'image est écrit **à la main** dans `app.image` de chaque fichier de valeurs (et `appVersion` dans
`Chart.yaml`, à titre informatif). Une release de l'application (semantic-release) publie une nouvelle image
mais ne modifie pas ces fichiers : après une release, éditer `values-dev.yaml` (et `values-staging.yaml` quand
on décide de promouvoir la version), puis `helm upgrade`. Tant que ce n'est pas fait, le cluster continue de
faire tourner l'ancienne version.

### Accès avec `minikube tunnel`

Lancer `minikube tunnel` dans un autre terminal et le laisser ouvert. Le port 80 est **privilégié** (< 1024) :
le tunnel demande le mot de passe `sudo` et il faut le saisir, sinon le Service reçoit une adresse mais rien
ne répond (le mot de passe est redemandé quand le cache `sudo` expire). Un Ingress existant dans le cluster
est lui aussi publié sur les ports 80 et 443 : tant que le Service de l'application existe sur le port 80, il
le masque.

### Tester le déploiement

```bash
scripts/test-k8s-deploy.sh                    # manifestes de k8s/
scripts/test-k8s-deploy.sh --helm dev         # chart Helm, environnement dev (port 80, sudo)
scripts/test-k8s-deploy.sh --helm staging     # chart Helm, environnement staging (port 8081)
```

Le script vérifie les prérequis (affiche les commandes à lancer s'il en manque), déploie dans un namespace
jetable, teste l'application par le Service et la suppression d'un pod, puis supprime le namespace
(`--keep` le conserve, `--pause` attend Entrée entre les étapes).
