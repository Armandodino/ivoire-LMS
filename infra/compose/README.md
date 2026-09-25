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
make veille        # vérifier qu'aucune brique amont n'est morte
make down          # arrêter (les données restent)
make purge         # DESTRUCTIF : supprime aussi les volumes
```

## Services

| Service | Port | Rôle |
|---|---|---|
| `moodle-web` | 8080 | nginx, racine web sur `engines/moodle/public` |
| `moodle-php` | — | PHP 8.3-FPM, code monté depuis le sous-module |
| `moodle-cron` | — | boucle le cron Moodle toutes les 60 s |
| `postgres` | 5432 | PostgreSQL 17, bases `moodle` et `keycloak` |
| `valkey` | — | sessions et cache Moodle (fork BSD-3 de Redis) |
| `keycloak` | 8081 | identité unique, realm `ivoire-lms` importé au démarrage |
| `mailpit` | 8025 | intercepte les courriels sortants |
| `garage` | 3900 / 3903 | stockage objet compatible S3 (remplace MinIO, archivé) |

## Points de conception à connaître

**Le code Moodle n'est pas copié dans l'image.** Il est monté depuis
`engines/moodle`, qui est un sous-module figé. On modifie donc du code Moodle en
modifiant le sous-module — ce qui est interdit (cf. `engines/README.md`). Nos
développements passeront par `plugins/moodle`, greffé dans `public/local/`.

Ce montage n'est **pas encore actif** : Moodle lit `version.php` pour chaque
plugin qu'il détecte, et un répertoire dans `public/local/` sans `version.php`
n'est pas un plugin valide. Tant qu'aucun plugin n'existe, le montage
n'apporterait rien et pourrait faire échouer l'installation. Le
`docker-compose.yml` contient la ligne à décommenter, par plugin, le jour où
le premier est écrit.

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

## Garage demande une initialisation

Un nœud Garage neuf refuse toute écriture tant qu'aucune disposition (*layout*) ne
lui a été assignée. `make bootstrap` le fait ; `make garage-init` le rejoue si
besoin. La configuration de développement est à **un seul nœud, réplication 1** :
en production il faut au moins trois nœuds sur des sites distincts et
`replication_factor = 3`.

Garage n'a pas d'interface web d'administration — c'est une API S3 et une API
d'administration. C'est un choix assumé de l'éditeur, et l'une des raisons pour
lesquelles il reste léger.

## Pourquoi Valkey et pas Redis

Licence : Valkey est en BSD-3-Clause sous gouvernance Linux Foundation, Redis 8 est
en AGPLv3. Cohérent avec notre stratégie de limiter l'exposition au copyleft
(ADR 0004). Compatible au niveau protocole : l'extension phpredis et le
gestionnaire de sessions de Moodle fonctionnent sans modification. Détails dans
`docs/architecture/02-briques-open-source.md`.
