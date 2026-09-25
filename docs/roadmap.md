# Feuille de route

## Jalon 0 — Fondations (fait)

- [x] Dépôt initialisé, attribution IA désactivée (hook `commit-msg` + identité Git)
- [x] Audit des trois bases amont
- [x] Décisions d'architecture tranchées (ADR 0001, 0002, 0003)
- [x] Analyse des licences et de ses conséquences commerciales
- [x] Moteurs référencés en sous-modules Git, versions figées

## Jalon 1 — Socle exploitable en local

Objectif : `make up` démarre Moodle, Open edX et un BBB accessible, sur une machine
de développement.

- [ ] `infra/compose` : Moodle 5.2 (PHP 8.3 + PostgreSQL + Redis)
- [ ] `infra/compose` : Open edX via Tutor, en configuration de développement
- [ ] BBB : instance de développement distante partagée (BBB ne se conteneurise pas)
- [ ] `platform/identity` : Keycloak amorcé, realm `ivoire-lms`
- [ ] `scripts/bootstrap.sh` : un seul point d'entrée pour un poste neuf

## Jalon 2 — Identité unique

C'est le jalon qui transforme trois sites en une plateforme.

- [ ] Moodle client OIDC de Keycloak, mise en correspondance des rôles
- [ ] Open edX client OIDC de Keycloak (backend `third_party_auth`)
- [ ] BBB : accès aux salles par jeton signé émis par `integrations/bbb`
- [ ] Cycle de vie des comptes : création, suspension, suppression propagées
- [ ] MFA obligatoire pour les rôles d'administration

## Jalon 3 — Plan de contrôle et multi-tenant

- [ ] Modèle de données : tenant, établissement, structure, utilisateur, cours,
      inscription, résultat
- [ ] API de provisionnement : créer un tenant de bout en bout, automatiquement
- [ ] Résolution du tenant par sous-domaine dans `gateway`
- [ ] Synchronisation référentiel → moteurs (idempotente, réconciliable)
- [ ] Sauvegarde/restauration par tenant, testée par une restauration réelle

## Jalon 4 — Classe virtuelle Ivoire-LMS

- [ ] `integrations/bbb` : API interne de réunions, quotas, jetons
- [ ] Moodle et Open edX repointés sur notre grappe, configuration verrouillée
- [ ] Profils basse bande passante
- [ ] Enregistrement, transcodage léger, mise à disposition en différé
- [ ] Comptage des minutes pour la facturation

## Jalon 5 — Facturation Mobile Money

- [ ] Abstraction `billing` : intention de paiement, webhook, réconciliation,
      idempotence, reprise sur incident
- [ ] Connecteurs Orange Money, MTN MoMo, Moov Money, Wave
- [ ] Échéanciers, période de grâce, blocage/déblocage d'accès automatique
- [ ] Reçus et export comptable
- [ ] Journal d'audit inaltérable sur tout mouvement financier

## Jalon 6 — Réseau contraint

- [ ] PWA installable, coquille hors-ligne
- [ ] Téléchargement de cours et de médias, budget de données affiché
- [ ] Devoirs hors connexion, synchronisation différée avec résolution de conflits
- [ ] Mode économie de données
- [ ] Passerelles SMS et USSD (notes, solde, convocations)

## Jalon 7 — Scolarité et conformité ivoiriennes

- [ ] Moteur de notation : coefficients, compensation, crédits, rattrapage, mentions
- [ ] Délibérations et procès-verbaux
- [ ] Bulletins et relevés aux formats MENA / MESRS
- [ ] Registre d'appel et seuils d'exclusion d'examen
- [ ] Dossier de conformité ARTCI, registre des traitements

## Jalon 8 — Exploitation

- [ ] Helm/Terraform, environnements de recette et de production
- [ ] Observabilité : métriques, traces, journaux, alertes
- [ ] Plan de reprise d'activité, objectifs de RPO/RTO annoncés
- [ ] Revue de sécurité indépendante avant la première mise en production
