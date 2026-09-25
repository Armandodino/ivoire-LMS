# engines/ — moteurs pédagogiques amont

Ce dossier ne contient **aucun code écrit par nous**. Ce sont trois sous-modules Git
pointant vers les dépôts amont officiels, figés sur un commit précis.

| Sous-module | Amont | Branche suivie | Licence |
|---|---|---|---|
| `moodle` | `moodle/moodle` | `MOODLE_502_STABLE` | GPL-3.0 |
| `edx-platform` | `openedx/edx-platform` | `master` | AGPL-3.0 |
| `bigbluebutton` | `bigbluebutton/bigbluebutton` | `v3.0.x-develop` | LGPL-3.0 |

## Règles

1. **Ne jamais modifier un sous-module en place.** Toute modification nécessaire vit
   dans `patches/<moteur>/` sous forme de patch versionné, appliqué au déploiement.
   Sans cela, chaque montée de version amont écrase silencieusement notre travail et
   nous perdons la trace de nos obligations de publication (AGPL).
2. **Ne jamais copier de code d'ici vers `platform/`.** La contamination par copyleft
   est le risque numéro un du projet. Voir `docs/legal/licences-upstream.md`.
3. **Étendre un moteur se fait par son système d'extension**, pas par modification du
   cœur : plugin Moodle ou XBlock Open edX, rangés dans `plugins/`.

## Récupérer les moteurs

```bash
make engines            # historique complet (long)
make engines-shallow    # dernier commit seulement (~1,3 Go)
make engines-status     # versions actuellement figées
```

## Monter de version

```bash
make engines-update     # avance chaque sous-module sur sa branche
git diff                # à relire : le diff affiche l'ancien et le nouveau commit
```

Avant de committer une montée de version : lire les notes de version amont, vérifier
que les patchs de `patches/` s'appliquent toujours, et faire tourner la recette.
Les correctifs de sécurité de Moodle et d'Open edX sont à suivre en continu — c'est
la raison d'être de ce mécanisme.

## Pourquoi pas Open LMS comme base Moodle

`open-lms-open-source/moodle` s'arrête à Moodle 2.2 (janvier 2012) et n'est plus
maintenu. Voir `docs/adr/0002-base-moodle.md`.
