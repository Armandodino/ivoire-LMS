# Ivoire-LMS — vue d'ensemble de l'architecture

## Ce que nous construisons

Un LMS en mode SaaS multi-établissements, pensé pour les conditions réelles de la
Côte d'Ivoire : connexion intermittente, paiement par mobile money, effectifs
importants, parc d'appareils majoritairement mobiles et d'entrée de gamme.

La brique pédagogique n'est pas ce qui nous différencie : Moodle et Open edX font
déjà cela mieux que ce que nous pourrions écrire. Ce qui nous différencie est la
couche qui manque à tous les déploiements LMS observés localement.

## Les trois plans

### 1. Plan de contrôle — `platform/control-plane`

Le cerveau du SaaS. Il détient la vérité sur :

- **Tenants** : un établissement = un tenant (sous-domaine, marque, plan, quotas).
- **Provisionnement** : créer/détruire l'instance de moteur d'un tenant, migrer,
  sauvegarder, restaurer. Entièrement automatisé — un établissement doit pouvoir
  être opérationnel en minutes, pas en semaines de prestation.
- **Référentiel** : utilisateurs, structures (UFR, filières, promotions), cours,
  inscriptions, résultats. Les moteurs sont alimentés depuis ce référentiel, jamais
  l'inverse.
- **Quotas et mesure d'usage** : stockage, minutes de classe virtuelle, comptes
  actifs. C'est la base de la facturation.

### 2. Plan d'expérience — `platform/shell-ui`, `platform/gateway`, `platform/identity`

Ce que l'utilisateur voit et traverse.

- **`identity`** : un fournisseur OIDC unique (Keycloak) source de vérité de
  l'authentification. Moodle et Open edX sont configurés comme clients OIDC : un
  étudiant se connecte une fois et circule entre les moteurs sans le savoir.
  Support des rattachements par établissement, MFA pour les rôles administratifs.
- **`gateway`** : résolution du tenant par domaine/sous-domaine, terminaison TLS,
  limitation de débit, filtrage applicatif, routage vers le bon moteur.
- **`shell-ui`** : la coquille Ivoire-LMS — tableau de bord, catalogue, emploi du
  temps, notifications, scolarité. Les vues profondes d'un moteur sont intégrées
  dans cette coquille, avec notre identité visuelle. L'utilisateur ne doit jamais
  voir « Moodle » ou « Open edX » dans l'interface.

### 3. Plan pédagogique — `engines/`

Moteurs amont, programmes séparés, suivis par sous-modules Git.
Voir `docs/adr/0001-composition-plutot-que-fusion.md`.

## Les différenciateurs — là où se joue la valeur du produit

Ce sont les manques constatés des LMS utilisés localement. Chacun devient un module
de `platform/`.

### Paiement — `platform/billing`

Aucun LMS généraliste n'intègre correctement le mobile money. Sans cela, un
établissement ivoirien ne peut pas encaisser en ligne, et un apprenant individuel
encore moins. Cible : **Orange Money, MTN MoMo, Moov Money, Wave**, plus carte
bancaire et virement pour les institutions.

Cas d'usage à couvrir au-delà du simple paiement :
- frais d'inscription et de scolarité, avec **paiement échelonné** et suivi des
  échéances — c'est la norme, pas l'exception ;
- blocage/déblocage automatique d'accès selon l'état du compte, avec période de
  grâce paramétrable ;
- reçus et attestations de paiement conformes aux usages administratifs ;
- réconciliation comptable exportable.

### Réseau contraint — `platform/shell-ui` (PWA) et `platform/integrations/bbb`

- **Hors-ligne d'abord** : application web installable, cours et médias
  téléchargeables, devoirs rédigés hors connexion et synchronisés au retour du
  réseau. Un étudiant doit pouvoir travailler dans le train ou au village.
- **Budget de données affiché** : l'interface indique le poids d'un téléchargement
  avant de le lancer. La donnée mobile coûte cher, l'utilisateur doit décider.
- **Dégradation volontaire** : mode économie qui coupe vidéos et images lourdes.
- **Classe virtuelle basse consommation** : voir ADR 0003.

### Canaux hors-web — `platform/integrations`

Tous les apprenants n'ont pas un smartphone connecté en permanence.
- **SMS** : convocations, notes publiées, rappels d'échéance, alertes d'absence.
- **USSD** : consultation des notes et du solde sans internet.
- **WhatsApp** : canal de diffusion principal dans les faits ; à intégrer
  officiellement plutôt que de le laisser se faire en marge de la plateforme.

### Conformité et scolarité ivoiriennes — `platform/control-plane`

C'est ce qui fait qu'un établissement adopte ou rejette un LMS.
- **Notation et délibération** : moyennes pondérées par coefficient, compensation,
  crédits ECTS/LMD, sessions de rattrapage, mentions, conseils de classe.
- **Documents officiels** : bulletins, relevés de notes, attestations de réussite,
  procès-verbaux de délibération, aux formats attendus par le MENA et le MESRS.
- **Assiduité** : registre d'appel, calcul des absences justifiées/injustifiées,
  seuils d'exclusion d'examen.
- **Protection des données** : traitement conforme à la loi ivoirienne sur la
  protection des données à caractère personnel et aux obligations déclaratives
  auprès de l'ARTCI. Résidence des données documentée et maîtrisée.

### Langues — transverse

Français comme langue de base, y compris dans l'interface d'administration.
Architecture i18n prête pour l'ajout de langues nationales sur les parcours
d'alphabétisation et de formation professionnelle.

## Vue de déploiement

| Composant | Où il tourne | Pourquoi |
|---|---|---|
| `gateway`, `shell-ui`, `control-plane`, `identity`, `billing` | Kubernetes | Sans état ou presque, mise à l'échelle horizontale |
| Moodle (PHP-FPM + nginx) | Kubernetes, un déploiement par tenant ou par grappe de tenants | Isolation des données par tenant |
| Open edX | Kubernetes via Tutor | Tutor est le mode de déploiement de référence de l'amont |
| PostgreSQL, Valkey, Garage (S3) | Services gérés ou opérateurs | Sauvegarde et restauration éprouvées |
| BigBlueButton | Machines dédiées hors cluster, derrière un répartiteur | Exige un OS précis et l'accès direct au réseau média |

## Ordre de construction

L'identité unique d'abord : sans elle, il n'y a pas de plateforme, seulement trois
sites côte à côte. Ensuite le plan de contrôle et le provisionnement, puis la
facturation mobile money, puis le hors-ligne. Détail dans `docs/roadmap.md`.
