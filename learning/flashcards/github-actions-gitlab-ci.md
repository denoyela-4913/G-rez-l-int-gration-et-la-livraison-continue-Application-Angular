# Flashcards — GitHub Actions et GitLab CI

Fiche associée : [github-actions-gitlab-ci](../fiches/github-actions-gitlab-ci.md)

Q: Que signifie CI/CD ?
R: Continuous Integration / Continuous Delivery : exécuter automatiquement, à chaque modification du code, la construction, les tests puis la livraison ou le déploiement.

---

Q: Que signifie YAML ?
R: YAML Ain't Markup Language : un format de données lisible, basé sur l'indentation, utilisé pour décrire les workflows CI/CD et les manifestes Kubernetes.

---

Q: Où se trouve la configuration dans GitHub Actions et dans GitLab CI ?
R: GitHub : `.github/workflows/*.yml` (plusieurs fichiers possibles). GitLab : un seul `.gitlab-ci.yml` à la racine, qu'on peut découper avec `include:`.

---

Q: Comment les jobs s'enchaînent-ils dans GitHub Actions et dans GitLab CI ?
R: GitHub : jobs en parallèle par défaut, on les ordonne avec `needs:`. GitLab : des `stages:` séquentiels, avec les jobs d'un même stage en parallèle (et `needs:` pour sauter des stages).

---

Q: Quelle est la différence entre `steps` (GitHub) et `script` (GitLab) ?
R: Un `step` est une action réutilisable (`uses:`) ou une commande (`run:`). Un `script` est une simple liste de commandes shell ; la réutilisation passe par `include:` ou `extends:`.

---

Q: Quelle différence de fond sur le système de fichiers entre un job GitHub et un job GitLab ?
R: Sur GitHub, les étapes d'un job partagent la même machine et le même dossier. Sur GitLab, chaque job démarre dans un environnement vierge : les fichiers passent d'un job à l'autre par `artifacts:`.

---

Q: Quelle différence entre un artefact et un cache ?
R: L'artefact transmet le résultat d'un job (rapports, binaires) et se télécharge. Le cache réutilise des dépendances (`node_modules`, `~/.npm`) d'une exécution à l'autre pour gagner du temps ; il n'est pas garanti.

---

Q: Que fait `if: always()` dans un step GitHub Actions ?
R: Il exécute l'étape même si une étape précédente a échoué. Dans ce dépôt, c'est ce qui publie le rapport de tests quand les tests échouent. En GitLab, l'équivalent pour les fichiers est `artifacts: when: always`.

---

Q: Pourquoi limiter les `permissions` du `GITHUB_TOKEN` ?
R: Principe du moindre privilège : si une étape ou une action tierce est compromise, elle ne peut faire que ce que le jeton autorise. Ici : `contents: read` et `checks: write` seulement.

---

Q: Pourquoi fixer une action sur un SHA plutôt que sur un tag ?
R: Un tag (`v7`) peut être déplacé vers un autre code, donc une action tierce compromise s'exécuterait chez vous. Un SHA (Secure Hash Algorithm) désigne un commit précis et immuable. Le commentaire `# v7.0.1` garde la version lisible.

---

Q: À quoi sert `concurrency` avec `cancel-in-progress: true` ?
R: À annuler l'exécution précédente encore en cours sur la même branche quand une nouvelle arrive, pour économiser des minutes et éviter les résultats obsolètes. En GitLab : `interruptible: true`.

---

Q: Pourquoi `ci.yml` appelle-t-il `./run-tests.sh` plutôt que de mettre les commandes dans le YAML ?
R: La logique de test est dans un script versionné, rejouable en local et identique dans le projet Java. Le pipeline devient portable : seul le YAML d'enveloppe change d'une plateforme à l'autre.

---

Q: Comment `ci.yml` met-il en cache les dépendances npm ?
R: Avec `cache: npm` dans `actions/setup-node` : le dossier `~/.npm` est mis en cache avec une clé calculée à partir de `package-lock.json`.

---

Q: Quel équivalent GitLab pour le rapport de tests JUnit publié par `ci.yml` ?
R: `artifacts:reports:junit` : GitLab lit le XML nativement, sans action tierce comme `action-junit-report` côté GitHub.

---

Q: Le projet a choisi GitHub : quel registre d'images remplace celui de GitLab visé par les `TODO` de `k8s/` ?
R: GHCR (GitHub Container Registry, `ghcr.io/<utilisateur>/<dépôt>:<tag>`). Chez GitLab, le registre se référence par `$CI_REGISTRY_IMAGE`. Pour tirer l'image depuis Kubernetes, il faut un secret `imagePullSecrets` avec un Personal Access Token (`read:packages`), car le `GITHUB_TOKEN` expire avec le job.
