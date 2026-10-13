# Image de l'application Olympic Participation Tracker (Angular 20, servie par Nginx).
# Build : docker compose build
# Build multi-stage : Node et node_modules restent dans l'étape "build",
# seuls les fichiers statiques sont copiés dans l'image finale (plus légère, moins de surface d'attaque).

# ---------- Étape 1 : build Angular ----------
# Angular 20 exige Node >= 20.19 ou >= 22.12 : la version 20.11 du README est trop ancienne.
# Node 24 (LTS active) : Node 20 est en fin de vie. La version mineure flottante apporte les correctifs.
FROM node:24-alpine AS build
WORKDIR /usr/src/app

# Les fichiers de dépendances d'abord : tant qu'ils ne changent pas, la couche
# npm ci reste en cache et n'est pas retéléchargée à chaque modification du code.
# "npm ci" (et non "npm i") installe exactement les versions du package-lock.json.
COPY package.json package-lock.json ./
RUN npm ci --cache .npm --prefer-offline

# Les sources ensuite (node_modules, dist, etc. sont exclus par .dockerignore).
COPY . .
RUN npm run build

# ---------- Étape 2 : image d'exécution ----------
FROM nginx:1.27-alpine

# La config définit "root /app" ; les fichiers temporaires et le pid sont dans /tmp
# et le port est 8080, ce qui permet à Nginx de tourner sans être root.
COPY nginx/nginx.conf /etc/nginx/nginx.conf

# Angular 17+ (builder "application") place les fichiers statiques dans le sous-dossier "browser".
# Pas de --chown : les fichiers restent propriétaires root, donc en lecture seule pour "app".
COPY --from=build /usr/src/app/dist/olympic-games-starter/browser /app

# Utilisateur non-root avec UID/GID fixes (10002), sans mot de passe (-D), sans home (-H)
# et sans shell (nologin). UID fixe = droits prévisibles (runAsUser dans Kubernetes).
# Convention : 10001 = workshop (java), 10002 = application Angular.
RUN addgroup -g 10002 app \
 && adduser -D -H -u 10002 -G app -s /sbin/nologin app

# UID numérique (et non le nom) pour que Kubernetes puisse vérifier runAsNonRoot.
USER 10002:10002

# Documentation du port d'écoute (la publication se fait dans docker-compose.yml / k8s).
# 8080 car un utilisateur non-root ne peut pas écouter sur un port < 1024.
EXPOSE 8080

# Déjà défini dans l'image nginx:1.27-alpine, réécrit pour être explicite.
# "daemon off" garde Nginx au premier plan (PID 1), sinon le conteneur s'arrête aussitôt.
CMD ["nginx", "-g", "daemon off;"]
