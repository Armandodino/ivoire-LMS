# Briques open source — catalogue évalué

Statuts vérifiés le **25 septembre 2026**. Chaque ligne indique ce que nous en
faisons : *adopté*, *candidat* (à évaluer sur un jalon nommé), ou *écarté* (avec
le motif). Une brique sans décision n'a pas sa place ici.

La vérification n'est pas un geste unique : `make veille` et le contrôle
hebdomadaire `.github/workflows/veille-amont.yml` refont ce travail tout seuls.
Voir `docs/adr/0005-veille-technologique.md`.

---

## 1. Briques mortes — retirées du projet

### MinIO — **retiré**

Le dépôt `minio/minio` a été **archivé le 25 avril 2026**. Le README affiche
« THIS REPOSITORY IS NO LONGER MAINTAINED ». L'édition communautaire n'est plus
distribuée qu'en code source, sans binaire précompilé, et l'éditeur renvoie vers
ses offres commerciales AIStor. L'historique est documenté : retrait de la console
d'administration de l'édition communautaire en mai 2025, puis passage en
« maintenance mode », puis archivage.

Remplacé par **Garage**. Aucune ligne de notre code ne dépendait encore de MinIO :
le coût du retrait a été nul parce qu'il a été détecté tôt. C'est tout l'objet de
l'ADR 0005.

### Open LMS (`open-lms-open-source/moodle`) — **écarté dès le départ**

Arrêté à Moodle 2.2, janvier 2012. Voir `docs/adr/0002-base-moodle.md`.

---

## 2. Socle d'exécution — adopté

| Brique | Rôle | Licence | Statut vérifié | Décision |
|---|---|---|---|---|
| **Garage** `v2.4.1` | stockage objet S3 | AGPL-3.0 | publié le 08/09/2026 | **adopté** |
| **Valkey** `9.0` | sessions, cache | BSD-3-Clause | maintenu, gouvernance Linux Foundation | **adopté** |
| **Keycloak** `26.7.4` | identité unique | Apache-2.0 | publié le 16/09/2026 | **adopté** |
| **PostgreSQL** `17` | base de données | PostgreSQL | soutenue | **adopté** |
| **nginx** `1.30` | serveur web | BSD-2-Clause | branche stable | **adopté** |

**Pourquoi Garage plutôt que SeaweedFS, RustFS ou Ceph.** Garage est écrit en Rust
par l'association française Deuxfleurs, et sa raison d'être est précisément notre
contexte : il tourne sur du matériel modeste (un nœud tient en 1 vCPU / 1 Go de
RAM, il fonctionne sur Raspberry Pi), il **tolère 200 ms de latence entre nœuds**,
et il réplique entre sites distants en restant disponible quand un serveur devient
injoignable. C'est la description d'une infrastructure répartie sur plusieurs villes
avec des liaisons imparfaites. Il est financé par NLnet / NGI et en production chez
son éditeur depuis 2020.

*Limite à connaître* : Garage ne gère ni le versionnement d'objets, ni le
verrouillage, ni les règles de cycle de vie. Notre politique de sauvegarde ne peut
donc pas reposer sur le versionnement S3 — il faut des instantanés côté base et une
copie hors site. À traiter au jalon 8, pas plus tard.

**Pourquoi Valkey plutôt que Redis.** Redis est passé en 2024 sous licence
RSALv2/SSPLv1, puis Redis 8 a ajouté l'AGPLv3 en 2025 — redevenant open source au
sens de l'OSI, mais sous une licence à copyleft réseau. Valkey est le fork de
Redis 7.2.4 lancé par la Linux Foundation, en **BSD-3-Clause**, soutenu par AWS,
Google Cloud, Oracle, Ericsson et Snap, et devenu le paquet par défaut de Debian 13,
Ubuntu 26.04 LTS et Fedora 42. Il est compatible au niveau protocole : l'extension
phpredis et le gestionnaire de sessions de Moodle fonctionnent sans modification.

Ce choix découle directement de l'ADR 0004 : nous limitons délibérément notre
exposition au copyleft. Prendre de l'AGPL pour un cache alors qu'un équivalent
BSD-3 existe, plus rapide et sous gouvernance neutre, serait incohérent.

---

## 3. Écosystème éducatif francophone — le meilleur gisement

C'est la découverte la plus utile de cette revue. **France Université Numérique**
(`github.com/openfun`) publie en open source une pile éducative complète, en
français, conçue pour l'enseignement supérieur public. Tous ces projets étaient
actifs au moment de la vérification.

| Projet | Ce qu'il fait | Dernière activité | Décision |
|---|---|---|---|
| **Joanie** | ERP sans interface pour l'éducation : inscriptions, **paiement échelonné**, devis, conventions, achats groupés, **certificats signés** | pointe de `main` au 04/09/2026, 180 commits en 2026 | **ADOPTÉ — MIT — voir ADR 0006** |
| **Ralph** | Learning Record Store xAPI, pour les traces d'apprentissage | 25/09/2026 | **candidat — jalon 8** |
| **Warren** | Visualisation des données d'apprentissage, adossé à xAPI | 22/08/2026 | **candidat — jalon 8** |
| **Richie** | CMS Django de portail de formation et catalogue de cours | 25/09/2026 | **candidat — phase 2** |
| **Marsha** | Gestion de contenus vidéo via LTI | 25/09/2026 | à revoir plus tard |

**Pourquoi Joanie mérite un examen sérieux.** Il couvre exactement le périmètre que
j'avais prévu d'écrire de zéro dans `platform/control-plane` et `platform/billing` :
inscriptions, abonnements, paiement, certificats. Écrit en Python/Django par un
opérateur public qui exploite une plateforme à grande échelle, en français, avec de
vrais utilisateurs. Réécrire cela nous coûterait des mois.

**Évalué par lecture du code le 25/09/2026, et adopté.** Les trois doutes sont
levés : licence **MIT** (aucun copyleft, nos ajouts restent privés), **backend
Moodle présent en amont** avec ses tests — il n'est donc pas couplé à Open edX — et
tous les points d'extension utiles (prestataire de paiement, handler LMS, calendrier
des jours fériés) sont **branchables par configuration**, donc sans fork.

Deux limites établies et assumées. Il **n'est pas multi-tenant** (`SITE_ID = 1`) :
une instance par tenant, le cloisonnement reste à notre charge. Et son échéancier
**prélève sur une carte enregistrée sans intervention du client**, ce que le Mobile
Money ne permet pas : il faut le remplacer par un enchaînement pousser-pour-payer.
Détail et preuves dans `docs/adr/0006-joanie-socle-commerce-et-certificats.md`.

**Ralph et Warren** répondent au besoin d'analyse pédagogique sans rien écrire :
un LRS xAPI plus sa couche de visualisation, déjà utilisés en production pour des
cohortes importantes. C'est la brique qui permet de détecter le décrochage — un
argument de vente réel auprès d'un établissement.

---

## 4. Réseau contraint — le cœur de notre différence

| Brique | Ce qu'elle apporte | Statut | Décision |
|---|---|---|---|
| **Kolibri** (Learning Equality) | Écosystème éducatif hors ligne, contenus en 173 langues, déployé dans 220+ pays et territoires, partenariats en Ouganda, Ghana, Tanzanie, RDC | actif | **candidat fort — jalon 6** |
| **Moodle App** | Application mobile officielle, hors-ligne intégré, même amont que notre moteur | actif | **adopté — jalon 6** |
| **RapidPro** (UNICEF / Nyaruka) | Flux SMS, **USSD**, IVR, WhatsApp, Telegram. 10 ans d'existence, Digital Public Good, utilisé dans 36 pays | actif | **candidat fort — jalon 6** |
| **faster-whisper** / **WhisperX** | Transcription et sous-titrage automatiques, français pris en charge, exécution locale sans envoi de données | actif | **candidat — jalon 4** |

**Kolibri** mérite mieux qu'une case à cocher. C'est un système complet pensé pour
les lieux sans connexion : contenus embarqués, synchronisation opportuniste,
serveur local desservant une salle de classe. Pour un lycée de l'intérieur du pays
avec quatre heures d'électricité par jour, c'est plus pertinent qu'une PWA. Deux
usages possibles : la diffusion de contenus vers les zones blanches, ou le modèle
de synchronisation dont on s'inspire pour notre propre mode hors ligne.

**RapidPro** est le bon choix pour le SMS et l'USSD : c'est un éditeur de flux, pas
une simple passerelle. Les notes consultables par USSD, les rappels d'échéance par
SMS, les convocations — tout cela se construit sans écrire de code, et se confie à
l'équipe scolarité plutôt qu'aux développeurs. Attention cependant : son
exploitation demande une vraie compétence système, ce n'est pas une brique qu'on
installe et qu'on oublie.

**faster-whisper** est le chaînon manquant de l'ADR 0003. Transcrire
automatiquement les enregistrements BigBlueButton donne trois choses d'un coup :
la lecture d'un cours sans consommer de vidéo (décisif quand la donnée mobile
coûte cher), la recherche plein texte dans les cours enregistrés, et
l'accessibilité pour les étudiants sourds ou malentendants. Le tout en local,
sans qu'un enregistrement de classe ne quitte notre infrastructure.

---

## 5. Paiement Mobile Money — avertissement

**Nous n'avons trouvé aucune bibliothèque open source crédible et maintenue** pour
le Mobile Money ouest-africain.

Les recherches remontent massivement un même dépôt « production-ready backend
bridging African mobile money with Stellar blockchain », **dupliqué à l'identique
sur au moins sept comptes GitHub différents**. C'est la signature d'un projet
d'atelier ou généré automatiquement, recopié en masse. Le mot « production-ready »
dans une description ne vaut rien.

**Décision : aucune dépendance open source sur le chemin de l'argent.**

C'est la partie du système où un bogue se traduit par des fonds perdus et une
plainte. L'abstraction `platform/billing` est écrite par nous et parle :
- soit directement aux API des opérateurs (MTN MoMo Open API, Orange Money), en
  sachant que la mise en service est par pays et demande un contrat commercial ;
- soit à un agrégateur sous contrat couvrant plusieurs opérateurs.

Le choix agrégateur contre intégration directe est une décision d'entreprise
(commissions, délais de reversement, qualité du support local) autant que
technique. Elle demande de demander des devis, pas de lire du code. Elle sera
tranchée dans un ADR au jalon 5.

Ce que nous écrivons nous-mêmes reste dicté par le métier, quelle que soit l'issue :
idempotence stricte, journal d'audit inaltérable, réconciliation, reprise sur
incident, échéanciers, période de grâce.

---

## 6. À examiner plus tard

Pas de décision à ce stade, mais à ne pas perdre de vue :

- **H5P** — contenus interactifs, s'intègre à Moodle et à Open edX.
- **Collabora Online** / **OnlyOffice** — édition de documents dans le navigateur,
  utile pour les devoirs rédigés.
- **Meilisearch** / **Typesense** — recherche rapide et peu gourmande, plus
  adaptée que Elasticsearch à notre échelle et à nos coûts.
- **CloudNativePG** — PostgreSQL géré sur Kubernetes, sauvegarde et bascule
  automatiques (jalon 8).
- **Prometheus, Grafana, Loki, OpenTelemetry** — observabilité (jalon 8).
- **Jitsi Magnify** (openfun) — gestion de salles Jitsi, à comparer à notre
  intégration BigBlueButton si un besoin de visio légère apparaît.

---

## Sources

- [minio/minio — dépôt archivé](https://github.com/minio/minio)
- [MinIO removes management features from Community Edition — Blocks & Files](https://blocksandfiles.com/2025/06/19/minio-removes-management-features-from-basic-community-edition-object-storage-code/)
- [Garage — Deuxfleurs](https://garagehq.deuxfleurs.fr/) · [objectifs et cas d'usage](https://garagehq.deuxfleurs.fr/documentation/design/goals/) · [dépôt](https://github.com/deuxfleurs-org/garage) · [financement NLnet](https://nlnet.nl/project/Garage/)
- [Self-Hosted S3 en 2026 : RustFS, SeaweedFS, Garage ou Ceph ?](https://rilavek.com/resources/self-hosted-s3-compatible-object-storage-2026)
- [Redis vs Valkey en 2026 — ce que le changement de licence a vraiment changé](https://dev.to/synsun/redis-vs-valkey-in-2026-what-the-license-fork-actually-changed-1kni)
- [Keycloak 26.7.4](https://www.keycloak.org/2026/09/keycloak-2674-released) · [cycle de vie](https://endoflife.date/keycloak)
- [France Université Numérique — dépôts](https://github.com/openfun) · [Ralph, LRS](https://github.com/openfun/ralph)
- [Kolibri — Learning Equality](https://learningequality.org/kolibri/about-kolibri/) · [dépôt](https://github.com/learningequality/kolibri) · [fiche UNESCO](https://www.unesco.org/en/dtc-financing-toolkit/kolibri-education-platform)
- [RapidPro — UNICEF](https://www.unicef.org/innovation/rapidpro) · [site](https://home.rapidpro.io/)
- [Choisir entre les variantes de Whisper — Modal](https://modal.com/blog/choosing-whisper-variants)
