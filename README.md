# Ivoire-LMS

Plateforme LMS en mode SaaS conçue pour l'enseignement en Côte d'Ivoire.

Ivoire-LMS ne réécrit pas un LMS : elle orchestre les meilleurs moteurs pédagogiques
libres derrière une seule identité, une seule interface et une seule facturation, et
ajoute la couche qui manque systématiquement aux déploiements locaux — mobile money,
fonctionnement en réseau dégradé, canaux SMS/USSD, et règles de scolarité ivoiriennes.

## Composition

| Rôle | Moteur | Version suivie | Phase |
|---|---|---|---|
| LMS diplômant, évaluation, gestion de classe | Moodle | `MOODLE_502_STABLE` (5.2.3+) | **1** |
| Classe virtuelle, enregistrement, tableau blanc | BigBlueButton | `v3.0.x-develop` | **1** |
| MOOC, catalogue ouvert, grande échelle | Open edX | `master` | 2 |

La phase 1 s'appuie sur Moodle et BigBlueButton seuls. Ce n'est pas un renoncement :
c'est ce qui correspond au marché du diplôme visé, et cela **supprime toute
obligation de publier notre propre code**, l'AGPL venant exclusivement d'Open edX.
Le sous-module Open edX reste figé dans le dépôt, prêt pour la phase 2.
Voir `docs/adr/0004-phasage-des-moteurs.md`.

Ces moteurs sont des **sous-modules Git** dans `engines/`, non modifiés. Nos
modifications éventuelles sont des patchs versionnés dans `patches/`.
Le raisonnement est dans `docs/adr/0001-composition-plutot-que-fusion.md`.

> **Note sur Open LMS** — le dépôt `open-lms-open-source/moodle` s'arrête à
> Moodle 2.2 (janvier 2012) et n'est plus maintenu. Il ne peut pas servir de base.
> Nous partons de l'amont officiel `moodle/moodle`.
> Détail et preuves : `docs/adr/0002-base-moodle.md`.

## Structure

```
platform/          Notre code — la valeur du produit
  control-plane/   Tenants, provisionnement, référentiel, quotas, scolarité
  identity/        OIDC unique (Keycloak) pour tous les moteurs
  gateway/         Routage multi-tenant, TLS, limitation de débit
  shell-ui/        Interface unifiée Ivoire-LMS (PWA, hors-ligne)
  billing/         Mobile Money : Orange, MTN, Moov, Wave
  integrations/    BBB, LTI 1.3, xAPI, SMS, USSD
  analytics/       Suivi pédagogique, décrochage, tableaux de bord
engines/           Moteurs amont (sous-modules, non modifiés)
plugins/           Nos plugins Moodle et XBlocks Open edX (glue minimale)
infra/             Compose (dev), Helm/K8s et Terraform (prod)
docs/              Architecture, ADR, licences, feuille de route
```

## Démarrer

Prérequis : Docker avec le greffon Compose v2, et Git.

```bash
git clone https://github.com/Armandodino/ivoire-LMS.git
cd ivoire-LMS
make bootstrap
```

`make bootstrap` est idempotent et fait tout : vérification des prérequis,
installation des garde-fous de commit, récupération des moteurs (~1,3 Go en clone
superficiel), génération d'un `.env` avec des mots de passe aléatoires, construction
de l'image PHP 8.3, installation de la base Moodle en français, démarrage de la pile.

À l'arrivée :

| Service | Adresse |
|---|---|
| Moodle | http://localhost:8080 |
| Keycloak (identité unique) | http://localhost:8081 |
| Mailpit (courriels interceptés) | http://localhost:8025 |
| Garage (stockage objet S3) | http://localhost:3900 |

Les identifiants sont dans `.env`, qui n'est jamais committé.
`make help` liste toutes les commandes. Détails et points de conception :
`infra/compose/README.md`.

## Licences

Notre code (`platform/`, `infra/`, `docs/`, `scripts/`) est sous licence AGPL-3.0.
Les moteurs amont conservent la leur : Moodle GPL-3.0, Open edX AGPL-3.0,
BigBlueButton LGPL-3.0.

**À lire avant toute décision commerciale** : `docs/legal/licences-upstream.md`.
Le choix de licence n'est pas neutre ici — l'AGPL d'Open edX impose des obligations
de publication qui conditionnent le modèle économique.

« Moodle », « Open edX » et « BigBlueButton » sont des marques de leurs détenteurs
respectifs. Ivoire-LMS n'y est pas affiliée.

## Contribuer

- Langue de travail : français.
- Conventional Commits.
- Aucune mention d'assistant IA dans l'historique, les PR ou le code
  (voir `CONTRIBUTING.md`) — vérifié automatiquement par le hook `commit-msg` et par la CI.
