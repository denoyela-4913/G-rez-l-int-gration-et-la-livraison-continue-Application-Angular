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

Le workflow `.github/workflows/ci.yml` comporte deux jobs : `test` (tests unitaires) puis `build`
(construction, test de fonctionnement et publication de l'image sur GHCR, le GitHub Container
Registry). Le job `build` ne tourne que sur un `push` et seulement si `test` a réussi.

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
| Version applicative | pas de version dans l'image | `ARG APP_VERSION` du Dockerfile (jar nommé d'après `build.gradle`) |

### Local et CI : ce qui diffère

- La CI part d'un runner vierge : aucun cache de couches Docker, donc la première construction est plus
  longue qu'en local.
- Le nom d'image est calculé à partir du dépôt et mis en minuscules (GHCR l'exige). En local,
  `docker compose` utilise un nom court (`olympic-games-tracker`, `workshop-organizer`).
- Le test de la CI exécute l'image qui sera publiée (et non une reconstruction) : ce qui est testé est
  ce qui est livré.
