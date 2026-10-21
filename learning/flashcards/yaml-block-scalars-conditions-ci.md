# Flashcards — YAML : block scalars et conditions `if:` de GitHub Actions

Fiche associée : [yaml-block-scalars-conditions-ci](../fiches/yaml-block-scalars-conditions-ci.md)

Q: Que signifie YAML ?
R: YAML Ain't Markup Language : un format de données lisible, basé sur l'indentation, utilisé pour décrire les workflows CI/CD et les manifestes Kubernetes.

---

Q: Qu'est-ce qu'un block scalar YAML ?
R: Une chaîne de texte écrite sur plusieurs lignes indentées, réglée par un style (`|` ou `>`) et un indicateur de chomping (`-`, `+` ou rien).

---

Q: Quelle différence entre `|` et `>` en YAML ?
R: `|` (literal) conserve les retours à la ligne tels quels. `>` (folded) remplace les retours simples par des espaces ; une ligne vide produit un vrai retour à la ligne.

---

Q: Que fait le `-` dans `>-` ?
R: C'est le chomping « strip » : il supprime tous les retours à la ligne finaux. Sans lui (clip), un seul `\n` final est conservé ; avec `+` (keep), tous sont conservés.

---

Q: Quelle chaîne produit `texte` avec `>-`, et avec `>` ?
R: `>-` donne `"texte"` (aucun `\n` final). `>` donne `"texte\n"` (un `\n` final conservé).

---

Q: Quel style YAML choisir pour un script shell multi-lignes, et pour une condition longue ?
R: `|` pour un script (une commande par ligne, retours conservés). `>-` pour une condition ou expression longue (repliée sur une ligne, sans `\n` final).

---

Q: Pourquoi utiliser `>-` plutôt qu'un scalar sur plusieurs lignes sans indicateur ?
R: Un scalar plain se heurte aux caractères spéciaux YAML : un `!` initial est lu comme un tag, `: ` et ` #` changent le sens. Un block scalar traite tout comme du texte brut.

---

Q: Que se passe-t-il dans un `if:` GitHub Actions s'il n'y a aucune fonction de statut ?
R: GitHub ajoute un `success()` implicite : le job est ignoré si un job dont il dépend (`needs:`) a échoué ou a été ignoré (`skipped`).

---

Q: Quelles sont les fonctions de statut de GitHub Actions ?
R: `success()` (implicite), `failure()`, `cancelled()` et `always()`. Dès que l'une d'elles apparaît dans le `if:`, le `success()` implicite disparaît.

---

Q: Pourquoi `!cancelled()` plutôt que `always()` dans le `if:` de `build` ?
R: Les deux retirent le `success()` implicite, mais `always()` exécute le job même si le workflow est annulé à la main. `!cancelled()` respecte l'annulation.

---

Q: Quelles valeurs peut prendre `needs.<job>.result` ?
R: `success`, `failure`, `cancelled` ou `skipped`.

---

Q: Pourquoi le `if:` du job `build` accepte-t-il `needs.release.result == 'skipped'` ?
R: Parce que `release` n'a lieu que sur `main` et est ignoré ailleurs. Sans cette tolérance, `build` serait ignoré sur toutes les branches autres que `main`. Un `failure` de `release`, lui, bloque bien le build.

---

Q: Pourquoi des parenthèses autour de `(needs.release.result == 'success' || needs.release.result == 'skipped')` ?
R: `&&` est prioritaire sur `||`. Sans parenthèses, le `||` ne porterait que sur ses voisins immédiats et la condition changerait de sens.

---

Q: Où est le `if: >-` étudié, et que garantit-il dans DataShare ?
R: Dans le job `build` du `ci.yml` des dépôts Java (lignes 120-122) et Angular (lignes 124-126), où il est identique (`.github/workflows/ci.yml`). Il garantit qu'on construit et publie l'image seulement sur un `push`, après des tests réussis et une release réussie ou ignorée, jamais si le workflow est annulé.
