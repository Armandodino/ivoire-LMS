# ADR 0006 — Adopter Joanie comme socle commerce, contrats et certificats

- **Date** : 2026-09-25
- **Statut** : accepté
- **Méthode** : évaluation par lecture du code (`openfun/joanie`, pointe de `main`
  au commit `f9135d4`, daté du 04/09/2026), et non sur la base de sa documentation.

## Contexte

Le jalon 3 prévoyait d'écrire de zéro, dans `platform/control-plane`, le référentiel
des inscriptions, le paiement, les échéanciers et la délivrance de certificats.
La revue des briques open source (ADR 0005) a mis au jour **Joanie**, publié par
France Université Numérique, décrit comme « un ERP sans interface pour l'éducation ».
Avant d'écrire une ligne, il fallait savoir s'il nous épargnait ce travail.

## Ce que l'examen du code a établi

### Licence : MIT

`LICENSE` : « MIT License, Copyright (c) 2021 France Université Numérique ».
Aucun copyleft. Nous pouvons l'utiliser, le modifier et **garder nos ajouts privés**.
C'est la licence la plus favorable possible pour nous, et elle est parfaitement
alignée sur la stratégie de l'ADR 0004.

### Il n'est pas couplé à Open edX

C'était le doute principal, et il est levé.
`src/backend/joanie/lms_handler/backends/` contient `openedx.py` **et `moodle.py`**,
ce dernier accompagné de sa suite de tests. Le backend Moodle dialogue par les
services web Moodle (`wstoken`, `wsfunction`) et expose `create_user`,
`get_user_id`, `get_enrollment(s)`, `set_enrollment` et `get_grades` — exactement
ce dont notre plan de contrôle a besoin pour piloter Moodle.

Joanie + Moodle est donc une combinaison **soutenue en amont**, pas un détournement.

### Tout ce qui compte est branchable par configuration

`joanie/payment/__init__.py` instancie le prestataire de paiement par
`import_string(settings.JOANIE_PAYMENT_BACKEND["backend"])`. Même mécanisme pour
`JOANIE_LMS_BACKENDS` et pour `JOANIE_CALENDAR`, le calendrier des jours fériés qui
sert au calcul des délais contractuels.

**Conséquence majeure : aucun fork n'est nécessaire.** Nous livrons notre propre
prestataire Mobile Money et notre calendrier ivoirien dans un paquet Python à nous,
et nous pointons la configuration dessus. Joanie reste l'amont, non modifié.

### Le modèle de données couvre bien plus que prévu

`Order`, `Product`, `Enrollment`, `CourseRun`, `Organization`, `Certificate` et
`CertificateDefinition`, mais aussi `Contract` et `ContractDefinition` (conventions
signées), `Quote` et `QuoteDefinition` (devis), `BatchOrder` (achat groupé de
places par un établissement), `Discount`, `Voucher`, `Skill`, `Teacher`,
`ActivityLog`. Environ 37 000 lignes de Python hors tests et migrations, sur
Django 4, DRF et Celery, avec une API d'administration et une API client.

`Organization` porte `representative`, `signature` (pour signer les certificats),
`logo`, `country`, plus un code d'entreprise et un code d'activité — en France
SIRET et APE, chez nous RCCM et numéro de contribuable. C'est exactement la fiche
d'un établissement client.

Devis, convention et achat groupé sont précisément ce qu'exige la vente à un
établissement ivoirien. Nous ne l'aurions pas écrit avant des mois.

### Activité

180 commits sur `main` depuis janvier 2026, 23 en août, les derniers datés du
4 septembre 2026. Projet vivant, porté par un opérateur public qui l'exploite.

## La limite décisive : l'échéancier suppose une carte enregistrée

C'est le résultat le plus important de l'évaluation, et il aurait coûté cher
découvert tard. `core/tasks/payment_schedule.py` :

```python
if not order.credit_card or not order.credit_card.token:
    order.set_installment_refused(installment["id"])
    continue
...
payment_backend.create_zero_click_payment(
    order=order, credit_card_token=order.credit_card.token, installment=installment,
)
```

Le prélèvement des échéances est **à l'initiative du marchand, sur un jeton de carte
enregistré** (*zero-click*). C'est le modèle européen, cohérent avec ses deux
prestataires existants, Lyra et PayPlug.

**Le Mobile Money ne fonctionne pas ainsi.** Il n'y a ni jeton conservé, ni
prélèvement possible sans le client : chaque paiement exige une validation sur le
téléphone, par application ou par USSD. En l'état, `debit_pending_installment`
marquerait **chaque échéance comme refusée**.

Ce n'est pas un obstacle à l'adoption, mais c'est du travail qui nous revient, et
qui nous serait revenu de toute façon : un enchaînement *pousser-pour-payer*.
À l'échéance, on notifie le client (SMS, USSD, notification), on attend sa
validation, on applique une période de grâce, puis on bloque l'accès. La
notification préalable existe déjà côté Joanie
(`send_mail_upcoming_debit`, `send_mail_reminder_installment_debit_task`) : c'est le
déclencheur du prélèvement automatique qu'il faut remplacer, pas tout le mécanisme.

## Décision

**Joanie devient le socle de `platform/control-plane` pour le commerce, les
contrats et les certificats.** Il est déployé comme un service à part, non modifié,
piloté par son API.

Ce que nous écrivons, dans notre propre paquet, sans toucher à l'amont :

1. **`ivoire_paiement.backends.MobileMoneyBackend`** — sous-classe de
   `BasePaymentBackend`, branchée par `JOANIE_PAYMENT_BACKEND`. Le cycle
   `create_payment` puis `handle_notification` (rappel du prestataire) épouse bien
   le Mobile Money : on initie, le client valide sur son téléphone, l'opérateur
   nous rappelle. Les méthodes propres à la carte
   (`tokenize_card`, `delete_credit_card`, `create_zero_click_payment`) lèveront
   une exception explicite plutôt que d'échouer silencieusement.
2. **Un orchestrateur d'échéances pousser-pour-payer**, qui remplace
   `process_payment_schedules`. La tâche Celery amont est désactivée, pas corrigée.
3. **`ivoire_calendrier`** — jours fériés ivoiriens, branché par `JOANIE_CALENDAR`.
4. **Le cloisonnement multi-tenant**, qui reste entièrement à notre charge : voir
   ci-dessous.

## Ce que Joanie ne fait pas, et qui reste notre travail

Il faut être net là-dessus pour ne pas se raconter d'histoires.

**Il n'est pas multi-tenant.** `SITE_ID = 1` et un seul jeu de données : son
`Organization` désigne *l'organisme qui dispense la formation*, pas un locataire
au sens d'un SaaS, et n'a jamais été conçu comme une frontière de sécurité. Nous
déployons donc **une instance Joanie par tenant**, cohérent avec le
provisionnement par tenant que Moodle nous impose déjà, et seule option défendable
au regard de nos obligations de protection des données. Un Joanie partagé entre
établissements serait plus léger et constituerait un risque que nous n'assumons pas.

**Il ne gère pas la scolarité ivoirienne.** Joanie est du commerce et de la
certification, pas de la tenue de dossier académique. Coefficients, compensation,
crédits, délibérations, procès-verbaux, bulletins aux formats MENA et MESRS,
registre d'appel et seuils d'exclusion d'examen : cela reste le jalon 7, adossé au
carnet de notes de Moodle et à notre couche métier.

**Il ne règle rien du hors-ligne, du SMS/USSD, de BigBlueButton, ni de la
conformité ARTCI.**

## Réserve à surveiller

`src/backend/pyproject.toml` épingle `Django<5`, donc Django 4.2 LTS, dont le
support étendu s'est achevé en avril 2026. Un ERP qui manipule des données
personnelles et des mouvements financiers sur un Django en fin de vie n'est pas
acceptable en production. À vérifier avant toute mise en service, et à porter en
amont le cas échéant — c'est une contribution utile à un projet dont nous allons
dépendre. Joanie et Django sont ajoutés à la veille de l'ADR 0005 dès maintenant.

## Ce que la décision fait gagner

Le jalon 3 passait par l'écriture d'un référentiel commerce complet. Il se réduit
à : déployer Joanie, écrire un prestataire de paiement, un orchestrateur
d'échéances et un calendrier, et construire le cloisonnement multi-tenant par
dessus. Devis, conventions, achats groupés, remises, bons, certificats signés et
facturation arrivent gratuitement, en français, testés, sous licence MIT.

## Alternatives écartées

- **Tout écrire** : plusieurs mois pour atteindre un périmètre inférieur.
- **Forker Joanie** : inutile, puisque tous les points d'extension nécessaires sont
  branchables par configuration. Forker nous priverait des correctifs amont — la
  faute exacte que l'ADR 0001 nous interdit de commettre sur les moteurs.
- **Un ERP généraliste** (Odoo, Dolibarr) : aucune notion de cours, de session, de
  certificat ni de LMS. Il faudrait écrire le métier éducatif, c'est-à-dire
  précisément ce que Joanie apporte.
