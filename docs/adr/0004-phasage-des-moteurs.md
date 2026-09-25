# ADR 0004 — Un seul moteur en phase 1 : Moodle. Open edX en phase 2.

- **Date** : 2026-09-25
- **Statut** : accepté

## Contexte

L'ADR 0001 a retenu une architecture de composition capable d'accueillir Moodle et
Open edX. La question restée ouverte est celle du **calendrier** : faut-il exploiter
les deux dès la première version ?

Ce que coûte réellement « les deux dès le départ » :

- **Trois piles à exploiter** au lieu de deux (PHP, Python/Django + une vingtaine de
  micro-frontends React, Scala/Java/WebRTC). Open edX seul demande Tutor, un
  registre d'images, Elasticsearch/Meilisearch, MongoDB, un service de forum, un
  service de notes, un notifier.
- **Deux modèles pédagogiques à réconcilier** dans le référentiel du plan de
  contrôle, alors que le référentiel n'existe pas encore.
- **Deux fois la surface de sécurité** à suivre en correctifs.
- **La contrainte AGPL-3.0**, qui vient exclusivement d'Open edX.

## Décision

La version 1 d'Ivoire-LMS repose sur **Moodle 5.2 + BigBlueButton + notre couche
`platform/`**. Open edX reste dans le dépôt en sous-module, derrière un profil
Docker Compose désactivé par défaut (`--profile openedx`), et sera activé en phase 2
quand le catalogue public de MOOC deviendra une priorité commerciale.

Rien n'est perdu : le sous-module est figé, l'architecture de composition est déjà
celle qui permettra de le brancher, et l'identité unique construite au jalon 2 est
la même passerelle pour les deux moteurs.

## Justification

### 1. Le marché visé est celui du diplôme, pas du MOOC

Universités, grandes écoles, lycées et centres de formation professionnelle
ivoiriens ont besoin de notation par coefficients, de délibérations, de bulletins,
de registres d'appel et de gestion de scolarité. C'est le terrain de Moodle. Open edX
excelle sur le catalogue ouvert à très grande échelle — un besoin réel mais qui vient
après, et qui concerne d'autres clients (ministères, bailleurs, programmes de
formation de masse).

### 2. Retirer Open edX de la phase 1 supprime la contrainte AGPL

C'est l'argument décisif, et il est commercial avant d'être technique.

| Périmètre phase 1 | Licence | Obligation sur **notre** code |
|---|---|---|
| Moodle | GPL-3.0 | Copyleft à la *distribution* seulement. Un SaaS ne distribue pas de binaire → **aucune obligation de publier `platform/`**. Seuls nos plugins Moodle sont dérivés et restent GPL-3.0. |
| BigBlueButton | LGPL-3.0 | Copyleft *faible*, utilisé comme service réseau externe → **aucune contamination**. |

Sans Open edX, il n'existe **aucune obligation de publier la couche qui fait la
valeur du produit** : multi-tenant, provisionnement, facturation Mobile Money,
hors-ligne, moteur de scolarité ivoirien. C'est un levier direct sur la valorisation
de l'entreprise, obtenu par une décision de calendrier et non par un compromis
technique.

Le jour où Open edX est activé, l'obligation réapparaît — mais limitée aux patchs de
`patches/openedx/`, périmètre connu et volontairement mince (cf. ADR 0001).
Cette décision est donc **réversible à coût maîtrisé**, ce qui est exactement la
propriété recherchée.

### 3. Livrer tôt vaut mieux que livrer complet

Un socle Moodle + BBB + SSO + Mobile Money démontrable devant un établissement
vaut plus que deux moteurs à moitié intégrés. Et c'est le retour de ces premiers
établissements qui doit dicter la suite, pas un plan écrit d'avance.

## Conséquences

- `make up` démarre la pile phase 1. `make up-openedx` ajoute Open edX pour ceux qui
  travaillent dessus.
- La licence du dépôt reste AGPL-3.0 : elle est compatible avec cette phase, ne nous
  contraint pas (nous sommes les détenteurs des droits sur `platform/`), et évite
  d'avoir à changer de licence en phase 2. **Si l'objectif devient de garder
  `platform/` propriétaire, c'est maintenant qu'il faut en décider** — voir la note
  ci-dessous.
- Le référentiel du plan de contrôle doit rester agnostique du moteur dès sa
  conception, même s'il ne pilote que Moodle au départ.

## Note ouverte — licence de notre propre code

Le dépôt est publié sous AGPL-3.0 par prudence initiale. Trois options, à trancher
avant la première mise en production :

1. **Tout en AGPL-3.0** : cohérent avec l'écosystème, mais un concurrent peut
   reprendre `platform/`.
2. **`platform/` propriétaire, le reste libre** : possible en phase 1 puisque aucune
   obligation ne s'y oppose. C'est le choix qui protège la valeur.
3. **Double licence** : AGPL pour la communauté, licence commerciale pour les
   établissements. Modèle éprouvé, mais demande une gestion juridique réelle.

Ce choix est une décision d'entreprise, pas d'ingénierie. Il mérite un avis
juridique avant d'être figé.
