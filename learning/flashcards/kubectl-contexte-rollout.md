# Flashcards — kubectl : contextes, hiérarchie des objets et `rollout`

Fiche associée : [kubectl-contexte-rollout](../fiches/kubectl-contexte-rollout.md)

Q: Qu'est-ce qu'un contexte kubectl ?
R: Un triplet de références stocké dans `~/.kube/config` : un cluster (adresse et certificat), un user (identifiants) et un namespace par défaut. Il indique à `kubectl` où envoyer ses commandes.

---

Q: Où est stocké le contexte et que contient ce fichier ?
R: Dans `~/.kube/config` (le kubeconfig), qui contient trois listes : `clusters`, `users` et `contexts`. Un contexte pointe vers une entrée de chacune.

---

Q: Qu'est-ce que le contexte courant ?
R: Celui indiqué par `current-context` dans le kubeconfig : c'est lui que toute commande `kubectl` utilise si on ne passe pas `--context`.

---

Q: Que fait `kubectl config use-context minikube` ?
R: Elle réécrit uniquement `current-context` dans `~/.kube/config`. Le cluster n'est pas touché, et le changement vaut pour tous les terminaux.

---

Q: Que contient le contexte `minikube` ?
R: Le cluster `minikube` (serveur `https://127.0.0.1:<port>`, CA `~/.minikube/ca.crt`), le user `minikube` (certificat et clé client dans `~/.minikube/profiles/minikube/`) et le namespace `default`.

---

Q: Pourquoi l'adresse du cluster Minikube est-elle `127.0.0.1` ?
R: Avec le driver `docker`, le nœud est un conteneur Docker et l'API server est joint par un port local redirigé. Ce port peut changer à chaque `minikube start`, et Minikube met le kubeconfig à jour.

---

Q: Le contexte contient-il des ressources Kubernetes (pods, namespaces) ?
R: Non. Il ne fait que désigner un cluster, un user et un namespace par défaut, et il existe dans un fichier local, pas dans le cluster.

---

Q: Que se passe-t-il avec `kubectl config delete-context` ? Et avec `kubectl delete namespace` ?
R: `delete-context` supprime seulement le raccourci local, rien n'est détruit dans le cluster. `delete namespace` supprime tout le contenu du namespace (pods, Deployments, Services, PVC) sans modifier le contexte.

---

Q: Quelle est la hiérarchie des objets côté cluster ?
R: Cluster › Namespace › Deployment › ReplicaSet › Pod › conteneur. L'« application » n'est pas un objet : c'est un ensemble de ressources regroupées par namespace et par labels.

---

Q: Quels objets ne sont pas rattachés à un namespace ?
R: Les nœuds, les namespaces eux-mêmes et les PersistentVolumes sont au niveau du cluster. Le PVC, lui, est dans un namespace.

---

Q: Que signifie PVC ?
R: PersistentVolumeClaim : la demande de stockage persistant faite par une application, liée à un PersistentVolume du cluster. Elle appartient à un namespace.

---

Q: Que fait `kubectl rollout status` ?
R: Elle suit l'avancement d'un rollout et bloque jusqu'à sa fin. Elle ne modifie rien. Son code de sortie est `0` en cas de succès, non nul en cas d'échec ou de dépassement de `--timeout`.

---

Q: Que fait `kubectl rollout restart` et comment ?
R: Elle redémarre les pods d'un Deployment sans changer le manifeste : elle ajoute l'annotation `kubectl.kubernetes.io/restartedAt` au modèle de pod, ce qui change sa spec et force un remplacement progressif.

---

Q: Dans quels cas utilise-t-on `rollout restart` ?
R: Après un changement de ConfigMap ou de Secret (les variables d'environnement ne se rechargent pas seules), après le push d'une image à tag mutable comme `latest`, ou pour relancer des pods bloqués.

---

Q: Pourquoi `scripts/test-k8s-deploy.sh` vérifie-t-il le contexte sans en changer ?
R: Le script crée et supprime des ressources (`kubectl delete namespace`) : sur un autre cluster il agirait au mauvais endroit. Il s'arrête donc (code 2) et affiche `kubectl config use-context minikube`, car changer le contexte modifierait la configuration globale de l'utilisateur à son insu.

---

Q: Pourquoi le script de test utilise-t-il un namespace `workshop-test-$RANDOM` plutôt que `default` ?
R: Pour ne pas interférer avec ce qui est déployé dans `default` : chaque commande reçoit `-n "$NS"`, et le `cleanup` supprime le namespace, donc aussi le PVC et le volume de la base.

---

Q: Comment le script utilise-t-il `kubectl rollout status` ?
R: Comme assertion : `check "..." kubectl rollout status -n "$NS" "$DB" --timeout=120s` compte un succès ou un échec selon le code de sortie. Il est aussi relancé après la suppression d'un pod pour attendre sa recréation.
