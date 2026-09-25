# Licences des moteurs amont — contrainte n°1 du projet

C'est le point le plus important à comprendre avant d'écrire une ligne de code,
parce qu'il détermine ce que nous pouvons vendre et ce que nous devons publier.

| Moteur | Dépôt | Licence | Effet sur un SaaS |
|---|---|---|---|
| Moodle (base LMS) | `moodle/moodle` | **GPL-3.0** | Copyleft à la *distribution*. Un SaaS ne distribue pas le binaire → pas d'obligation de publier, mais tout plugin Moodle que nous écrivons est un travail dérivé et doit être GPL-3.0. |
| Open edX | `openedx/edx-platform` | **AGPL-3.0** | Copyleft **réseau**. Si nous modifions `edx-platform` et le servons à des utilisateurs, nous **devons** proposer le code source modifié à ces utilisateurs. |
| BigBlueButton | `bigbluebutton/bigbluebutton` | **LGPL-3.0** | Copyleft *faible*. Utilisable comme service externe sans contaminer notre code. Si nous modifions BBB lui-même, ces modifications doivent être publiées sous LGPL-3.0. |

## Conséquence architecturale (non négociable)

L'AGPL-3.0 d'Open edX est la contrainte qui structure tout. Deux stratégies possibles :

1. **Fusionner** notre code dans `edx-platform` → tout notre SaaS devient AGPL-3.0,
   donc publiable et réutilisable par n'importe quel concurrent. Inacceptable
   commercialement.
2. **Composer** : garder les moteurs comme des *programmes séparés* que nous
   déployons et pilotons par API réseau. Notre valeur ajoutée (`platform/`) reste
   notre propriété. C'est la voie retenue — voir `docs/adr/0001-composition-plutot-que-fusion.md`.

### Règles pratiques qui en découlent

- **Jamais** de code copié depuis `engines/` vers `platform/`.
- **Jamais** d'import direct de modules Python d'`edx-platform` depuis `platform/`.
- Nos extensions *dans* un moteur (plugin Moodle, XBlock Open edX) vivent dans
  `plugins/` et sont livrées sous la licence du moteur concerné (GPL-3.0 / AGPL-3.0).
  Elles restent volontairement minces : de la glue, pas de logique métier.
- La logique métier qui fait notre différence (multi-tenant, facturation Mobile Money,
  hors-ligne, conformité ivoirienne) vit dans `platform/` et n'est jamais liée
  statiquement à un moteur.
- Toute modification d'un moteur est un **patch versionné** dans `patches/`, jamais
  une édition directe du sous-module. Cela garde nos obligations de publication
  identifiables et limitées à un périmètre connu.

## Obligation de conformité à assumer dès le départ

Puisque nous servirons du Open edX (AGPL) à des utilisateurs, nous devons publier
les modifications que nous y apportons. Le dossier `patches/openedx/` est donc
**public par construction** : il constitue notre offre de code source. Ce n'est
pas une fuite de propriété intellectuelle, c'est le prix d'entrée — et il est
faible tant que les patchs restent de la glue.

## Marques

« Moodle », « Open edX » et « BigBlueButton » sont des marques déposées de leurs
détenteurs respectifs. Nous ne pouvons pas nommer notre produit d'après elles ni
laisser croire à une affiliation. Une page « Technologies » mentionnant
« propulsé par Moodle, Open edX et BigBlueButton » est correcte et honnête.
Le programme Open edX impose en plus des règles d'usage de la marque pour
revendiquer la compatibilité : à vérifier avant tout marketing.
