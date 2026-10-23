# Flashcards — Bash : `set -euo pipefail`

Fiche associée : [bash-set-euo-pipefail](../fiches/bash-set-euo-pipefail.md)

Q: Que fait `set -euo pipefail` en début de script Bash ?
R: Il rend le script strict : arrêt à la première commande en échec (`-e`), erreur sur variable non définie (`-u`) et échec d'un pipe si l'un de ses maillons échoue (`-o pipefail`).

---

Q: Que fait l'option `-e` (errexit) ?
R: Le script s'arrête dès qu'une commande renvoie un code de sortie différent de 0, avec ce code.

---

Q: Quelles commandes ne déclenchent pas l'arrêt de `set -e` ?
R: Celles qui sont testées : dans un `if` ou un `while`, ou suivies de `&&` / `||`. L'échec y est prévu par le script.

---

Q: Que fait l'option `-u` (nounset) et quel risque évite-t-elle ?
R: Elle transforme l'usage d'une variable non définie en erreur. Sans elle, la variable vaut `""` : `rm -rf "$DOSSIER/"` deviendrait `rm -rf "/"`.

---

Q: Comment tolérer une variable absente avec `set -u` ?
R: Avec une valeur par défaut : `${VAR:-défaut}`, ou `${VAR:-}` pour « vide ». Exemple dans `helm-deploy.sh` : `ACTION=${1:-}`.

---

Q: Quel est le code de sortie d'un pipe par défaut, sans `pipefail` ?
R: Celui de la dernière commande seulement. `cat fichier_inexistant | sort` renvoie 0 car `sort` réussit.

---

Q: Que change `-o pipefail` ?
R: Le pipe renvoie le code du dernier maillon en échec : `cat fichier_inexistant | sort` renvoie alors 1, et `-e` peut s'appliquer.

---

Q: Pourquoi `-e` et `pipefail` vont-ils ensemble ?
R: Sans `pipefail`, une erreur au milieu d'un pipe est invisible (le code vient du dernier maillon), donc `-e` n'a rien à intercepter.

---

Q: Comment ignorer volontairement l'échec d'une commande avec `set -e` ?
R: `commande || true`, ou la placer dans un `if`. Exemple : `grep` renvoie 1 quand il ne trouve rien, ce qui n'est pas une panne.

---

Q: `set -euo pipefail` garantit-il qu'aucune erreur ne passe ?
R: Non. `-e` est ignoré dans les contextes testés (`if`, `&&`, `||`), l'échec d'une substitution `$(...)` passée en argument n'est pas détecté, et les erreurs de logique restent à tester.

---

Q: Pourquoi `test-k8s-deploy.sh` écrit-il `kubectl delete namespace "$NS" ... || true` dans `cleanup` ?
R: Le nettoyage, branché par `trap cleanup EXIT`, doit tolérer un échec (namespace déjà supprimé) : il ne doit ni masquer l'erreur d'origine ni s'interrompre sous `set -e`.

---

Q: Pourquoi `helm-deploy.sh` écrit-il `${ACTION_ARGS[@]+"${ACTION_ARGS[@]}"}` ?
R: Pour `upgrade`, le tableau `ACTION_ARGS` est vide. Avec `-u`, les anciens Bash traitent un tableau vide comme non défini ; cette écriture ne le développe que s'il est défini.

---

Q: Quels scripts de DataShare (dépôt Angular) utilisent `set -euo pipefail` ?
R: `scripts/helm-deploy.sh`, `scripts/test-ghcr-image.sh`, `scripts/test-k8s-deploy.sh`, `update_version.sh` et `learning/build.sh` (le hook `.githooks/pre-commit` aussi).

---

Q: Que signifie `EXIT` dans `trap cleanup EXIT` ?
R: Le signal pseudo `EXIT` : `cleanup` s'exécute à la sortie du script, qu'elle soit normale ou causée par une erreur sous `set -e`.
