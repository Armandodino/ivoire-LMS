# Ivoire-LMS

Plateforme LMS en mode SaaS conçue pour l'enseignement en Côte d'Ivoire.

Ivoire-LMS ne réécrit pas un LMS : elle orchestre les meilleurs moteurs pédagogiques
libres derrière une seule identité, une seule interface et une seule facturation, et
ajoute la couche qui manque systématiquement aux déploiements locaux — mobile money,
fonctionnement en réseau dégradé, canaux SMS/USSD, et règles de scolarité ivoiriennes.

## Composition

| Rôle | Moteur | Version suivie |
|---|---|---|
| LMS diplômant, évaluation, gestion de classe | Moodle | `MOODLE_502_STABLE` (5.2.3+) |
| MOOC, catalogue ouvert, grande échelle | Open edX | `master` |
| Classe virtuelle, enregistrement, tableau blanc | BigBlueButton | `v3.0.x-develop` |

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

```bash
git clone --recurse-submodules https://github.com/Armandodino/ivoire-LMS.git
cd ivoire-LMS
./scripts/install-hooks.sh     # obligatoire : garde-fous de commit
make help
```

Si le dépôt est déjà cloné sans les sous-modules :

```bash
make engines
```

Les moteurs pèsent environ 1,3 Go au total. `make engines-shallow` ne récupère que
le dernier commit de chacun.

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
