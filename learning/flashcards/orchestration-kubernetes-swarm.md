# Flashcards — Orchestration de conteneurs : Kubernetes et Docker Swarm

Fiche associée : [orchestration-kubernetes-swarm](../fiches/orchestration-kubernetes-swarm.md)

Q: Qu'est-ce qu'un orchestrateur de conteneurs et pourquoi en a-t-on besoin ?
R: Un outil qui place, surveille, met à l'échelle et met à jour des conteneurs sur plusieurs machines. Docker ou Compose seuls gèrent une seule machine, sans autoréparation ni haute disponibilité.

---

Q: Qu'est-ce que le modèle déclaratif ?
R: On décrit l'état voulu dans un fichier YAML (ex. 3 réplicas de telle image) et une boucle de contrôle compare en continu l'état réel à cet état pour corriger l'écart, au lieu d'exécuter des commandes une par une (impératif).

---

Q: Que signifie K8s ?
R: C'est une abréviation de Kubernetes : K, 8 lettres omises, puis s.

---

Q: Qu'est-ce qu'un Pod ?
R: La plus petite unité déployable de Kubernetes : un ou plusieurs conteneurs qui partagent réseau et stockage. Il est éphémère, on le crée via un Deployment.

---

Q: Quel est le rôle d'un Deployment ?
R: Il décrit un modèle de Pod et le nombre de réplicas voulu, et gère les mises à jour progressives et le retour arrière (rollback).

---

Q: Quel est le rôle d'un Service Kubernetes ?
R: Donner une adresse stable (et un nom DNS) devant un groupe de Pods, qui sont éphémères et changent d'adresse.

---

Q: Que signifie DNS ?
R: Domain Name System : le système qui traduit un nom (ex. un nom de Service) en adresse réseau.

---

Q: Comment un Service retrouve-t-il ses Pods ?
R: Par les labels : le `selector` du Service doit correspondre aux labels du Pod. Ici, `app: olympic-games-app` des deux côtés.

---

Q: Quelle est la différence entre `ClusterIP`, `NodePort` et `LoadBalancer` ?
R: `ClusterIP` : visible dans le cluster seulement (défaut). `NodePort` : un port ouvert sur chaque nœud. `LoadBalancer` : exposé à l'extérieur via l'équilibreur du fournisseur cloud.

---

Q: Pourquoi un Secret Kubernetes n'est-il pas forcément sûr ?
R: Par défaut il est seulement encodé en base64, pas chiffré : n'importe qui avec accès en lecture peut le décoder. Il faut restreindre les droits et activer le chiffrement au repos.

---

Q: Que fait `docker swarm init` ?
R: Transforme la machine en manager d'un cluster Swarm. C'est l'orchestrateur intégré à Docker, sans installation supplémentaire.

---

Q: Que signifie Raft dans Swarm ?
R: Un algorithme de consensus qui synchronise l'état entre les managers : le cluster reste cohérent tant que la majorité des managers est disponible.

---

Q: Comment déploie-t-on un fichier Compose sur Swarm, et que devient la clé `build:` ?
R: Avec `docker stack deploy -c docker-compose.yml <nom>`. `build:` est ignorée : l'image doit déjà être dans un registre. La clé `deploy:` (replicas, mises à jour) n'a de sens que dans ce mode.

---

Q: Quand choisir Swarm plutôt que Kubernetes ?
R: Pour un petit cluster aux besoins simples, quand on connaît déjà Compose. Kubernetes est préférable en production à grande échelle (autoscaling, écosystème, offres cloud gérées).

---

Q: Que contiennent les manifestes `k8s/` de ce dépôt ?
R: Un `Deployment` (`replicas: 1`, label `app: olympic-games-app`) et un `Service` de type `LoadBalancer`. L'image et les `imagePullSecrets` sont encore des `TODO` (registre d'images privé : GHCR, le registre de GitHub).

---

Q: Pourquoi faut-il passer les ports `80` à `8080` dans `k8s/` ?
R: L'image tourne désormais sans root, et un utilisateur non-root ne peut pas écouter sur un port inférieur à 1024. Nginx écoute sur `8080`, donc `containerPort` et `targetPort` doivent suivre.
