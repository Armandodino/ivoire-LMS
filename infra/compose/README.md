# Pile de développement

## Démarrer

Depuis la racine du dépôt, sur un poste neuf :

```bash
make bootstrap
```

Le script vérifie les prérequis, installe les garde-fous de commit, récupère les
moteurs, génère un `.env` avec des mots de passe aléatoires, construit l'image PHP,
installe la base Moodle en français, puis démarre la pile.

Ensuite, au quotidien :

```bash
make up            # démarrer
make ps            # état
make logs          # journaux (make logs SERVICE=moodle-php pour un seul)
make shell         # console dans le conteneur PHP
make cron          # forcer une exécution du cron Moodle
make down          # arrêter (les données restent)
make purge         # DESTRUCTIF : supprime aussi les volumes
```

## Services

| Service | Port | Rôle |
|---|---|---|
| `moodle-web` | 8080 | nginx, racine web sur `engines/moodle/public` |
| `moodle-php` | — | PHP 8.3-FPM, code monté depuis le sous-module |
| `moodle-cron` | — | boucle le cron Moodle toutes les 60 s |
| `postgres` | 5432 | PostgreSQL 16, bases `moodle` et `keycloak` |
| `redis` | — | sessions et cache Moodle |
| `keycloak` | 8081 | identité unique, realm `ivoire-lms` importé au démarrage |
| `mailpit` | 8025 | intercepte les courriels sortants |
| `minio` | 9000 / 9001 | stockage objet compatible S3 |

## Points de conception à connaître

**Le code Moodle n'est pas copié dans l'image.** Il est monté depuis
`engines/moodle`, qui est un sous-module figé. On modifie donc du code Moodle en
modifiant le sous-module — ce qui est interdit (cf. `engines/README.md`). Nos
développements passent par `plugins/moodle`, monté dans `public/local/ivoire`.

**`config.php` ne contient aucun secret.** Il lit l'environnement, fourni par
`.env`. Le fichier est monté en lecture seule, ce qui empêche Moodle de le réécrire.

**Le cron tourne dans son propre conteneur.** `$CFG->cronclionly = true` interdit
le déclenchement du cron par une requête web : sinon un utilisateur paie le coût
des tâches de fond dans son temps de réponse.

**Le contrôle d'extensions PHP est bloquant.** Le Dockerfile vérifie les 20
extensions exigées par `engines/moodle/public/admin/environment.xml` (bloc 5.2) et
fait échouer la construction si l'une manque. Une image PHP incomplète échoue donc
à la construction, pas à l'exécution.

## BigBlueButton n'est pas dans cette pile

BBB exige une version précise d'Ubuntu, l'accès direct au réseau média et des ports
UDP en plage large. Il ne se conteneurise pas proprement et ne doit pas être
déployé dans le cluster applicatif. En développement, on pointe `BBB_SERVER_URL` et
`BBB_SHARED_SECRET` (dans `.env`) vers une instance de développement partagée.
Voir `docs/adr/0003-bigbluebutton-auto-heberge.md`.

## Open edX n'est pas dans cette pile

Décision de calendrier, pas d'architecture : voir
`docs/adr/0004-phasage-des-moteurs.md`. Le sous-module reste figé dans `engines/`,
prêt à être activé en phase 2 via Tutor.
