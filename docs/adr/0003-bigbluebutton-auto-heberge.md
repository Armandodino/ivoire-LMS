# ADR 0003 — Un seul BigBlueButton, auto-hébergé, partagé par les deux moteurs

- **Date** : 2026-09-25
- **Statut** : accepté

## Contexte

Chaque moteur arrive avec sa propre façon d'atteindre une visioconférence, et
aucune ne convient à un SaaS souverain :

- **Open edX** : `openedx/core/djangoapps/course_live/providers.py` définit une classe
  `BigBlueButton(LiveProvider, HasGlobalCredentials)` avec un *free tier*
  (`has_free_tier`) branché sur des identifiants globaux. Ce niveau gratuit pointe
  vers une instance BBB tierce hébergée hors de Côte d'Ivoire : limitée en durée,
  sans enregistrement fiable, et les données de classe sortent du pays.
- **Moodle 5.x** : livre le module `public/mod/bigbluebuttonbn`, dont
  `classes/local/config.php` fixe
  `DEFAULT_SERVER_URL = 'https://test-moodle.blindsidenetworks.com/bigbluebutton/'`,
  c'est-à-dire le serveur d'essai public de l'éditeur de BBB : réunions bridées,
  aucune garantie de disponibilité, données hors du pays.
  (Le miroir Moodle 2.2 d'Open LMS, lui, ne contient aucune intégration BBB.)

## Décision

Nous déployons **notre propre grappe BigBlueButton**, et les deux moteurs y sont
repointés.

1. `engines/bigbluebutton` suit l'amont `bigbluebutton/bigbluebutton`
   (branche `v3.0.x-develop` à ce stade, à figer sur une version publiée avant
   la mise en production).
2. `platform/integrations/bbb` est **notre** service : il détient les identifiants
   BBB, applique les quotas par tenant, crée les réunions, récupère les
   enregistrements, et expose une API interne unique. Les moteurs ne parlent
   jamais directement à BBB.
3. Côté Open edX : le *free tier* est désactivé et le fournisseur BBB est reconfiguré
   sur nos URL/clé/secret via la configuration du tenant. Aucun code amont supprimé —
   c'est de la configuration, donc rien à re-patcher à chaque montée de version.
4. Côté Moodle : `public/mod/bigbluebuttonbn` est conservé mais son serveur par défaut est
   forcé sur notre grappe, et la configuration est verrouillée par le
   `control-plane` pour qu'un administrateur d'établissement ne puisse pas la
   détourner vers un serveur tiers.

## Adaptations propres au contexte ivoirien

Ce sont elles qui justifient l'auto-hébergement, au-delà de la souveraineté :

- **Profils basse bande passante** : audio seul par défaut, vidéo sur demande,
  débits vidéo plafonnés, désactivation du partage d'écran sous un certain débit.
  Une classe doit rester suivable sur une connexion mobile instable.
- **Rattrapage asynchrone** : enregistrement systématique, transcodage en fichier
  léger téléchargeable, pour l'étudiant qui n'a pas pu se connecter en direct.
- **Hébergement de proximité** : serveurs au plus près des utilisateurs pour réduire
  la latence, et données de classe qui ne quittent pas le périmètre choisi.
- **Quotas par tenant** : nombre de salles simultanées et de participants adossés au
  plan de service, mesurés pour la facturation.

## Conséquences

- BBB impose une version d'Ubuntu précise et une machine dédiée par nœud média :
  il ne se conteneurise pas proprement. Il vit donc hors du cluster applicatif,
  sur son propre parc, avec un répartiteur de charge (`bbb-lb`) devant.
- Le dimensionnement média est le principal poste de coût variable de la plateforme.
  À modéliser avant toute grille tarifaire.
