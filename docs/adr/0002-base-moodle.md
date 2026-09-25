# ADR 0002 — Base Moodle : `moodle/moodle` 5.2, pas `open-lms-open-source/moodle`

- **Date** : 2026-09-25
- **Statut** : accepté

## Contexte

Le dépôt `github.com/open-lms-open-source/moodle` a été désigné comme base de départ.
Inspection faite le 2026-09-25 :

- La branche `master` est à `2.3dev (Build: 20120105)` — **janvier 2012**.
- Dernier commit sur `master` : `0e84b16`, **5 janvier 2012**.
- Branche stable la plus récente : `MOODLE_22_STABLE` (Moodle 2.2).
- Tags : s'arrêtent à `v2.2.0`.
- 89 branches, presque toutes des branches de correctifs `MDL-*` de l'époque
  Moodlerooms (2012-2016).

C'est un **miroir historique abandonné depuis 14 ans**. Moodle 2.2 exige PHP 5.3,
ne connaît ni les API REST modernes, ni LTI 1.3, ni le mode hors-ligne, ni RGPD,
et cumule plus d'une décennie de vulnérabilités corrigées depuis.

Le vrai apport open source d'Open LMS n'est pas ce miroir : ce sont les **plugins**
publiés séparément dans la même organisation (modules, blocs, rapports, thèmes).

## Décision

1. Le moteur Moodle d'Ivoire-LMS est **`moodle/moodle`, branche `MOODLE_502_STABLE`**
   (Moodle 5.2, amont officiel, correctifs de sécurité en continu).
2. Le clone d'`open-lms-open-source/moodle` est conservé **hors du dépôt** comme
   référence de lecture seule, pas comme base de code.
3. Les plugins intéressants de l'organisation `open-lms-open-source` seront évalués
   un par un et intégrés dans `plugins/moodle/` uniquement s'ils sont compatibles
   Moodle 5.x — la plupart ne le seront pas et servent surtout d'inspiration
   fonctionnelle.

## Alternative écartée

`MOODLE_405_STABLE` (4.5 LTS, support jusqu'à fin 2027) serait le choix le plus
conservateur. Écarté au profit de 5.2 : projet neuf, aucune dette de migration à
porter, et une fenêtre de support plus longue devant nous. À rediscuter si un
plugin indispensable n'existe qu'en 4.x.
