---
name: learning-card
description: Génère du matériel de révision pour la soutenance OpenClassrooms de DataShare — une fiche explicative + une série de flashcards Anki sur un sujet du projet. Utilise cette skill dès que l'utilisateur demande une fiche, des flashcards, une carte de révision ou du matériel pour préparer sa soutenance sur un sujet lié au projet (sécurité, architecture, stratégie de test, performance, CI/CD, déploiement, gestion de projet...), même formulé de façon informelle ("fais-moi une fiche sur X", "prépare des flashcards sur Y pour l'oral", "/learning-card <sujet>"). Si l'utilisateur ne donne aucun sujet précis, propose d'abord des axes de compréhension du projet et attend son choix avant de générer quoi que ce soit — ne lance jamais la génération sans un sujet validé.
---

# learning-card

Produit, pour un sujet donné, les deux mêmes livrables que ceux déjà présents dans
`learning/` : une fiche explicative (`learning/fiches/<slug>.md`) et une série de
flashcards (`learning/flashcards/<slug>.md`), ancrées sur le vrai code et la vraie doc
du projet — jamais sur des généralités apprises ailleurs. C'est ce qui distingue ce
matériel d'un cours générique : chaque affirmation doit pouvoir être vérifiée dans ce
dépôt.

## Étape 0 — si aucun sujet n'est donné

Ne génère rien tout de suite. Explore `README.md`, `DESIGN.md`, `SECURITY.md`,
`TESTING.md`, `PERF.md`, `MAINTENANCE.md`, `docs/BACKLOG.md` et `learning/README.md`
(pour voir les sujets déjà traités et ne pas les redoubler), puis propose 5 à 8 axes de
compréhension du projet, chacun avec une phrase expliquant ce qu'il couvrirait et sur
quel(s) fichier(s) réels il s'appuierait. Demande à l'utilisateur lequel lancer — un par
un, comme pour toute tâche non triviale. N'écris aucun fichier tant qu'un sujet n'est pas
choisi.

Si l'utilisateur donne un sujet directement (en argument ou en langage naturel), passe
directement à l'étape 1 pour ce sujet.

## Étape 1 — recherche ancrée dans le projet

Pour le sujet choisi, identifie les fichiers réels pertinents (docs de `docs/` et de la
racine, workflows `.github/workflows/*.yml`, code source `backend/` ou `frontend/`,
`deploy/`). Lis-les avant d'écrire quoi que ce soit. Si une affirmation ne peut pas être
rattachée à un fichier ou une ligne précise du dépôt, ne l'inclus pas ou marque-la
explicitement comme non vérifiée — ne comble jamais un manque d'information par une
généralité plausible.

Note au passage tout acronyme ou sigle technique spécifique rencontré dans ces sources
(ex. JWT, OWASP, IDOR, TTL, SAST, CVE, DTO...) : il servira à l'étape 3.

## Étape 2 — la fiche explicative

Fichier : `learning/fiches/<slug>.md`. Les deux meilleurs modèles à imiter pour le ton,
la densité et la structure exacte sont
[`learning/fiches/ci-github-actions.md`](../../../learning/fiches/ci-github-actions.md)
et
[`learning/fiches/tests-back-mockmvc-restassured-randomport.md`](../../../learning/fiches/tests-back-mockmvc-restassured-randomport.md).
Relis-les avant de rédiger : c'est le gabarit vivant, pas une description figée.

Structure attendue :

1. Titre `#` — nom du sujet.
2. Un court paragraphe d'intro qui pose la distinction ou l'enjeu central du sujet.
3. Des sections `##` : une par concept ou par notion à distinguer, avec extraits de code
   réels du dépôt entre balises de code (pas d'exemples inventés) et un tableau
   comparatif quand plusieurs notions se répondent (voir le tableau MockMvc vs
   RestAssured dans le modèle).
4. `## Dans DataShare` : ce que fait réellement ce projet sur ce sujet, avec des liens
   markdown cliquables vers les fichiers concernés (`[fichier.ext:ligne](chemin#Lligne)`
   quand c'est pertinent).
5. `## À retenir` : une liste numérotée de 3 à 5 points, les idées à ressortir à l'oral.

Écris en français, ton direct, pas de remplissage. Le but est qu'une phrase de la fiche
puisse être dite telle quelle en soutenance.

La première fois qu'un acronyme apparaît dans la fiche, développe-le entre parenthèses
(ex. « JWT (JSON Web Token) »). À l'oral, un jury peut faire trébucher sur le sigle nu
sans que le concept lui-même pose problème.

## Étape 3 — les flashcards

Fichier : `learning/flashcards/<slug>.md`, modèle exact :
[`learning/flashcards/ci-github-actions.md`](../../../learning/flashcards/ci-github-actions.md).

Format imposé par `learning/anki_csv.py`, à respecter au caractère près :

```
# Flashcards — <titre du sujet>

Fiche associée : [<slug>](../fiches/<slug>.md)

Q: <question>
R: <réponse>

---

Q: <question suivante>
R: <réponse>
```

Chaque carte teste une seule idée. Vise 10 à 15 cartes qui couvrent : les définitions
clés, les distinctions entre notions proches, le « pourquoi » d'un choix technique du
projet (pas seulement le « quoi »), et au moins une carte qui pointe vers l'implémentation
réelle dans DataShare. Du texte entre backticks devient du `<code>` à l'import Anki :
utilise les backticks pour tout nom de fichier, de variable ou de commande.

**Vocabulaire des acronymes** : pour chaque sigle technique spécifique repéré à
l'étape 1 (JWT, OWASP, IDOR, TTL, SAST, CVE, DTO, etc.), ajoute une carte dédiée qui
teste le développement du sigle et sa définition en une phrase, séparément des cartes qui
testent son usage dans le projet — par exemple :

```
Q: Que signifie JWT ?
R: JSON Web Token : un jeton signé qui transporte des informations d'identité/session de façon vérifiable sans état côté serveur.
```

Ne pas se contenter d'une carte sur l'usage (« pourquoi DataShare utilise JWT ») en
espérant que le sigle passe avec : le jury peut poser la question sur le terme seul,
indépendamment du contexte du projet, donc l'un ne dispense pas de l'autre.

## Étape 4 — nommer et brancher au tableau des sujets

Choisis un slug kebab-case cohérent avec les sujets déjà listés dans
`learning/README.md` (section `## Sujets`). La fiche et les flashcards partagent le même
slug. Ajoute une ligne au tableau, au même format que les lignes existantes :

```
| <Nom du sujet> | [fiche](fiches/<slug>.md) · [PDF](build/fiches/<slug>.pdf) | [cartes](flashcards/<slug>.md) · [CSV Anki](build/flashcards/<slug>.csv) |
```

## Étape 5 — vérifier que la génération fonctionne

Lance `learning/build.sh fiches/<slug>.md flashcards/<slug>.md` pour confirmer que le PDF
et le CSV se génèrent sans erreur (pandoc + Chrome/Edge headless pour la fiche,
`anki_csv.py` pour les flashcards). Si aucun navigateur headless n'est disponible dans
l'environnement, signale-le clairement à l'utilisateur sans bloquer le reste : le hook
`pre-commit` (`.githooks/pre-commit`) régénérera de toute façon `build/` automatiquement
au commit.

## Étape 6 — ne pas committer

Laisse les fichiers en l'état, non commités, et dis à l'utilisateur ce qui a été créé
(chemins de la fiche, des flashcards, et la ligne ajoutée au README). C'est à lui de
relire le contenu et de décider quand committer — ne lance `git add`/`git commit` que
s'il le demande explicitement pour ce sujet.
