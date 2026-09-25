# ADR 0001 — Composer les moteurs, ne pas les fusionner

- **Date** : 2026-09-25
- **Statut** : accepté

## Contexte

L'objectif est un SaaS LMS ivoirien complet, bâti sur Open LMS / Moodle, Open edX
et BigBlueButton. L'intention initiale était de fusionner ces bases de code en un
seul projet.

Ce que sont réellement ces trois bases :

- **Moodle** : PHP 8, MySQL/PostgreSQL, architecture à plugins, rendu serveur.
  ~500 plugins cœur. Modèle pédagogique : cours-activités, très riche en évaluation.
- **Open edX** : Python 3 / Django (`lms`, `cms`, `xmodule`) + une constellation de
  micro-frontends React (MFE) + services satellites (recherche, notes, forum,
  notifier). Modèle pédagogique : MOOC, parcours linéaire, passage à l'échelle.
- **BigBlueButton** : Scala/Akka (`akka-bbb-apps`), Java (`bigbluebutton-web`),
  Node/React (`bigbluebutton-html5`), GraphQL (Hasura), FreeSWITCH, LiveKit/WebRTC.
  Installation étroitement liée à une version précise d'Ubuntu.

## Décision

Ivoire-LMS est une **plateforme de composition**, pas un fork fusionné.

```
                    ┌──────────────────────────────┐
                    │   platform/shell-ui          │  UI unifiée, marque Ivoire-LMS
                    └──────────────┬───────────────┘
                                   │
                    ┌──────────────▼───────────────┐
                    │   platform/gateway           │  routage multi-tenant, TLS, WAF
                    └──────────────┬───────────────┘
        ┌──────────────────────────┼──────────────────────────┐
        │                          │                          │
┌───────▼────────┐      ┌──────────▼─────────┐      ┌─────────▼────────┐
│ control-plane  │      │  identity (OIDC)   │      │  billing         │
│ tenants,       │      │  SSO unique        │      │  Mobile Money CI │
│ provisioning   │      └──────────┬─────────┘      └──────────────────┘
└───────┬────────┘                 │
        │  pilote par API          │  authentifie
        ▼                          ▼
┌───────────────────────────────────────────────────────────────────┐
│  engines/ (programmes séparés, sous copyleft, non modifiés ou     │
│            modifiés par patchs versionnés uniquement)             │
│   • Moodle            • Open edX           • BigBlueButton        │
└───────────────────────────────────────────────────────────────────┘
```

Chaque moteur reste lui-même, mis à jour depuis l'amont. Notre code les orchestre.

## Justification

1. **Juridique.** L'AGPL-3.0 d'Open edX contaminerait tout notre SaaS si nous
   fusionnions. En composant, notre valeur ajoutée reste la nôtre.
   Voir `docs/legal/licences-upstream.md`.
2. **Technique.** PHP et Python/Django ne fusionnent pas. « Fusionner » signifierait
   réécrire l'un des deux — plusieurs années-hommes pour retrouver l'existant.
3. **Maintenance.** Un fork fusionné cesse de recevoir les correctifs de sécurité
   amont. Moodle et Open edX publient des correctifs de sécurité en continu ; un
   LMS qui les rate devient un risque. C'est précisément l'un des reproches faits
   aux déploiements LMS mal maintenus en Côte d'Ivoire.
4. **Rythme de livraison.** Composer donne une première version démontrable en
   semaines, pas en années.

## Répartition des rôles entre moteurs

| Besoin | Moteur | Pourquoi |
|---|---|---|
| Formation diplômante, évaluation fine, carnet de notes, présences | **Moodle** | Le plus riche en outils d'évaluation et en gestion de classe |
| MOOC, catalogue ouvert, parcours à grande échelle, certificats de masse | **Open edX** | Conçu pour la montée en charge et le catalogue public |
| Classe virtuelle, enregistrement, tableau blanc | **BigBlueButton** | Le seul des trois qui fait de la visioconférence pédagogique |

Un établissement client n'a pas besoin des deux LMS : le plan de service décide
quel(s) moteur(s) sont provisionnés pour son tenant. Le `control-plane` rend ce
choix invisible pour l'utilisateur final, qui ne voit que l'interface Ivoire-LMS.

## Conséquences

- Il faut construire une couche d'identité unique (OIDC) — sinon l'utilisateur voit
  la couture entre les moteurs. C'est le premier chantier technique.
- Il faut un modèle de données de référence côté `control-plane` (utilisateur,
  établissement, cours, inscription, résultat) et une synchronisation vers les
  moteurs. C'est le deuxième chantier.
- Nous assumons le coût d'exploitation de trois piles techniques distinctes.
  Kubernetes et l'automatisation du provisionnement ne sont pas optionnels.
