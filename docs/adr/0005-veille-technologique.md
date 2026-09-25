# ADR 0005 — Une brique morte se remplace, elle ne se tolère pas

- **Date** : 2026-09-25
- **Statut** : accepté

## Contexte

En écrivant la pile de développement du jalon 1, MinIO a été retenu comme stockage
objet. Or le dépôt `minio/minio` avait été **archivé le 25 avril 2026** — cinq mois
plus tôt — avec la mention « THIS REPOSITORY IS NO LONGER MAINTAINED ». Rien dans
l'image Docker, le nom du projet ou sa réputation ne le signalait.

La même revue a mis au jour deux autres écarts dans une pile écrite le jour même :

- **Keycloak épinglé en 26.0** alors que seule la ligne 26.7 est maintenue, et que
  la 26.7.4 du 16/09/2026 corrigeait des CVE dont une élévation de privilèges.
- **Redis** retenu par habitude, alors que sa licence est passée par RSALv2/SSPLv1
  puis AGPLv3, quand Valkey offre le même service en BSD-3-Clause sous gouvernance
  Linux Foundation.

Trois erreurs sur une pile de huit services, écrite par quelqu'un qui croyait
connaître ces outils. La réputation d'un projet survit à son abandon : c'est
précisément ce qui rend le problème dangereux.

## Décision

**Aucune brique amont n'entre ni ne reste dans Ivoire-LMS sans preuve de vie
datée.** Concrètement :

1. **À l'adoption**, toute brique est inscrite dans
   `docs/architecture/02-briques-open-source.md` avec son statut vérifié, sa date
   de vérification, et une décision explicite : adoptée, candidate, ou écartée
   avec motif.
2. **En continu**, `scripts/verifier-amont.py` interroge pour chaque brique le
   drapeau d'archivage et la date du dernier commit côté GitHub, ou la date de fin
   de vie annoncée pour les produits suivis par cycle (PostgreSQL, PHP, nginx).
   Trois états : **MORTE** (archivée ou fin de vie dépassée), **DORMANTE** (sans
   commit au-delà du seuil, 270 jours par défaut), **VIVANTE**.
3. **Le contrôle est automatique et bruyant** : `.github/workflows/veille-amont.yml`
   s'exécute chaque lundi, ouvre une issue dès qu'une brique est morte, et fait
   échouer l'exécution.
4. **Aucune image en tag flottant.** Pas de `latest`, pas de tag mouvant : une
   version précise, montée volontairement. Une pile ne doit jamais changer sans
   qu'on l'ait décidé.
5. **Une brique morte est remplacée, pas contournée.** Pas de fork de complaisance,
   pas de « ça marche encore ». Une dépendance non maintenue ne reçoit plus de
   correctif de sécurité ; dans un LMS qui détient les données personnelles
   d'étudiants et des mouvements financiers, c'est inacceptable.

## Dérogations : datées, motivées, et jamais silencieuses

Le premier vrai signal du détecteur a été **Django 4.2, en fin de vie depuis le
7 avril 2026** — la dépendance interne de Joanie (ADR 0006), que nous ne pouvons pas
changer sans l'amont. Ce cas révèle qu'une règle « une brique morte fait échouer la
CI » se heurte à la réalité : une CI rouge en permanence pour une cause qu'on ne
peut pas corriger dans la journée finit ignorée, et le détecteur perd toute valeur.

D'où le registre `DEROGATIONS` dans `scripts/verifier-amont.py`. Une dérogation
comporte obligatoirement trois choses :

- une **échéance** (`jusqu_au`) — passée cette date, la dérogation expire et l'échec
  revient, sans intervention ;
- un **motif** — pourquoi nous ne pouvons pas corriger maintenant ;
- une **action** — ce qui doit être fait, nommément.

Une brique dérogée est affichée `DEROG`, avec son motif et son action à chaque
exécution. Ce n'est pas une mise sous silence : c'est une dette inscrite avec sa
date d'exigibilité. **Aucune dérogation ne couvre une mise en production** — c'est
une tolérance de développement, pas un permis d'exploiter.

Une dérogation sans date ni action nommée n'a pas sa place dans ce registre.

## Le contrôle doit se méfier de lui-même

Le même épisode a mis au jour un **bogue dans le contrôle** : le workflow faisait

```bash
python3 scripts/verifier-amont.py | tee rapport.txt
echo "code=$?" >> "$GITHUB_OUTPUT"
```

`$?` après un tube renvoie le code du **dernier** élément — celui de `tee`, donc
toujours 0. Le détecteur signalait correctement une brique morte, et la CI passait
au vert en sautant l'ouverture d'issue. Un outil de surveillance qui échoue en
silence est pire que pas d'outil du tout, parce qu'il inspire une confiance qu'il ne
mérite pas.

Deux règles en découlent :

1. **Ne jamais relever un code de sortie derrière un tube.** On redirige, on relève
   le code, puis on affiche.
2. **La logique du détecteur est testée** (`make veille-logique`, 13 cas hors
   réseau, dérogations comprises) et le workflow affiche explicitement le code
   relevé, pour qu'un enchaînement muet redevienne visible.

Le détecteur ne doit **jamais** annoncer un succès quand il n'a rien pu vérifier :
une panne réseau prise pour un feu vert est plus dangereuse qu'un échec franc. Il
renvoie donc un code distinct (2) quand aucune brique n'a pu être examinée, et sa
logique de classement est couverte par un autotest hors réseau
(`make veille-logique`) pour que l'outil de contrôle soit lui-même contrôlé.

## Ce que la décision ne dit pas

**Dormante ne veut pas dire morte.** Un projet mature et stable peut rester des
mois sans commit sans être abandonné. L'état DORMANTE déclenche un examen humain,
pas un remplacement automatique.

**Récent ne veut pas dire bon.** La revue du Mobile Money a remonté un même dépôt
dupliqué sur sept comptes, tous actifs, tous se déclarant « production-ready », et
tous sans valeur. L'activité est un signal nécessaire, jamais suffisant :
qui maintient, pour quels utilisateurs, depuis combien de temps, sous quelle
gouvernance. Voir la section 5 du catalogue.

## Conséquences

- Coût : quelques minutes de calcul par semaine, et une revue humaine quand le
  détecteur parle. Sans commune mesure avec une migration de stockage objet subie
  en production.
- Le catalogue devient un document vivant qui doit être daté à chaque revue. Un
  catalogue non daté ne vaut rien.
- Les briques que nous adopterons plus tard (Joanie, Ralph, Kolibri, RapidPro)
  doivent être ajoutées à `BRIQUES` dans le détecteur **au moment de l'adoption**,
  pas après.
