# Feuille de route

## Jalon 0 — Fondations (fait)

- [x] Dépôt initialisé, attribution IA désactivée (hook `commit-msg` + identité Git)
- [x] Audit des trois bases amont
- [x] Décisions d'architecture tranchées (ADR 0001, 0002, 0003)
- [x] Analyse des licences et de ses conséquences commerciales
- [x] Moteurs référencés en sous-modules Git, versions figées

## Jalon 1 — Socle exploitable en local (écrit, reste à valider sur un poste avec Docker)

Objectif : `make bootstrap` suffit sur une machine neuve.

- [x] `infra/compose` : Moodle 5.2 (PHP 8.3 + PostgreSQL 17 + Valkey), conforme aux
      exigences lues dans `public/admin/environment.xml`
- [x] `infra/docker/moodle` : image PHP 8.3 avec contrôle bloquant des 20 extensions requises
- [x] `config.php` piloté par l'environnement, sans secret en dur, monté en lecture seule
- [x] Conteneur de cron séparé, cron web interdit (`$CFG->cronclionly`)
- [x] `platform/identity` : Keycloak 26 amorcé, realm `ivoire-lms` (rôles métier,
      clients `moodle` / `shell-ui` / `control-plane`, revendication `tenant_id`)
- [x] Mailpit et Garage pour travailler sur le courriel et le stockage objet dès le début
- [x] Revue des briques amont : MinIO retiré (dépôt archivé), Redis remplacé par
      Valkey, Keycloak remonté en 26.7.4, extension phpredis ajoutée au Dockerfile
      (son absence aurait fait échouer les sessions au premier affichage)
- [x] Détecteur de briques mortes (`make veille`) et contrôle hebdomadaire en CI
      — ADR 0005, catalogue dans `docs/architecture/02-briques-open-source.md`
- [x] `scripts/bootstrap.sh` : point d'entrée unique, idempotent, secrets aléatoires
- [x] ADR 0004 : phasage des moteurs, Open edX reporté en phase 2
- [ ] **Validation réelle** : `make bootstrap` exécuté de bout en bout sur un poste
      doté d'un démon Docker (impossible dans l'environnement où la pile a été écrite)
- [ ] BBB : instance de développement partagée à pourvoir, puis renseigner
      `BBB_SERVER_URL` / `BBB_SHARED_SECRET`
- [ ] Open edX via Tutor — phase 2, cf. ADR 0004

## Jalon 2 — Identité unique

C'est le jalon qui transforme trois sites en une plateforme.

- [ ] Moodle client OIDC de Keycloak, mise en correspondance des rôles
- [ ] Open edX client OIDC de Keycloak (backend `third_party_auth`)
- [ ] BBB : accès aux salles par jeton signé émis par `integrations/bbb`
- [ ] Cycle de vie des comptes : création, suspension, suppression propagées
- [ ] MFA obligatoire pour les rôles d'administration

## Jalon 3 — Plan de contrôle et multi-tenant

Périmètre réduit par l'adoption de Joanie (ADR 0006) : le référentiel commerce,
les contrats, les devis et les certificats ne sont plus à écrire.

- [x] Décision : Joanie (MIT) comme socle commerce, contrats et certificats,
      déployé non modifié, une instance par tenant — ADR 0006
- [ ] Joanie dans la pile de développement, branché sur Moodle via son
      `MoodleLMSBackend` (services web Moodle)
- [ ] Cloisonnement multi-tenant : **reste entièrement notre travail**, Joanie
      étant mono-site (`SITE_ID = 1`)
- [ ] API de provisionnement : créer un tenant de bout en bout, automatiquement
      (Moodle + Joanie + realm Keycloak)
- [ ] Résolution du tenant par sous-domaine dans `gateway`
- [ ] Correspondance des identités entre Keycloak, Moodle et Joanie
- [ ] Sauvegarde/restauration par tenant, testée par une restauration réelle
- [ ] Vérifier la réserve Django de l'ADR 0006 avant toute mise en production

## Jalon 4 — Classe virtuelle Ivoire-LMS

- [ ] `integrations/bbb` : API interne de réunions, quotas, jetons
- [ ] Moodle et Open edX repointés sur notre grappe, configuration verrouillée
- [ ] Profils basse bande passante
- [ ] Enregistrement, transcodage léger, mise à disposition en différé
- [ ] Comptage des minutes pour la facturation

## Jalon 5 — Facturation Mobile Money

Réécrit après l'ADR 0006 : Joanie apporte l'échéancier, la facturation et les
relances, mais son prélèvement automatique suppose une carte enregistrée, ce que
le Mobile Money ne permet pas.

- [ ] `MobileMoneyBackend`, sous-classe de `BasePaymentBackend` de Joanie, branchée
      par `JOANIE_PAYMENT_BACKEND` — aucun fork de Joanie
- [ ] Connecteurs Orange Money, MTN MoMo, Moov Money, Wave derrière ce backend
- [ ] **Orchestrateur pousser-pour-payer** remplaçant `process_payment_schedules` :
      à l'échéance, notifier (SMS/USSD), attendre la validation du client,
      appliquer la période de grâce, puis bloquer l'accès
- [ ] Calendrier des jours fériés ivoiriens, branché par `JOANIE_CALENDAR`
- [ ] ADR : intégration directe aux API opérateurs ou agrégateur sous contrat
      (décision d'entreprise autant que technique — demande des devis)
- [ ] Idempotence stricte, réconciliation, reprise sur incident
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
