#!/usr/bin/env bash
# Amorce un environnement de développement Ivoire-LMS complet, de zéro.
# Idempotent : relançable sans casser un environnement existant.
set -euo pipefail

RACINE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$RACINE"

# shellcheck source=scripts/lib/alea.sh
. "$RACINE/scripts/lib/alea.sh"
# shellcheck source=scripts/lib/env.sh
. "$RACINE/scripts/lib/env.sh"
COMPOSE=(docker compose -f infra/compose/docker-compose.yml --env-file .env)

vert()  { printf '\033[32m%s\033[0m\n' "$*"; }
jaune() { printf '\033[33m%s\033[0m\n' "$*"; }
rouge() { printf '\033[31m%s\033[0m\n' "$*" >&2; }
etape() { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }

# ─────────────────────────── 1. Prérequis ────────────────────────────────
etape "Vérification des prérequis"

manquant=0
for outil in docker git; do
  if ! command -v "$outil" >/dev/null 2>&1; then
    rouge "  $outil est absent."
    manquant=1
  else
    vert "  $outil présent"
  fi
done

if ! docker compose version >/dev/null 2>&1; then
  rouge "  Le greffon 'docker compose' est absent (Docker Compose v2 requis)."
  manquant=1
else
  vert "  docker compose présent : $(docker compose version --short 2>/dev/null || echo v2)"
fi

if ! docker info >/dev/null 2>&1; then
  rouge "  Le démon Docker n'est pas joignable. Démarre Docker Desktop ou le service dockerd."
  manquant=1
fi

[ "$manquant" -eq 0 ] || { rouge "Prérequis manquants, arrêt."; exit 1; }

# ─────────────────────── 2. Garde-fous de commit ─────────────────────────
etape "Installation des garde-fous de commit"
./scripts/install-hooks.sh

# ──────────────────────────── 3. Moteurs ─────────────────────────────────
etape "Récupération des moteurs (sous-modules)"
if [ ! -f engines/moodle/config-dist.php ]; then
  jaune "  Sous-modules absents — récupération en clone superficiel (~1,3 Go)..."
  git submodule update --init --recursive --depth 1
else
  vert "  engines/moodle déjà présent"
fi
git submodule status | sed 's/^/  /'

# ───────────────────── 4. Fichier .env et secrets ────────────────────────
etape "Configuration (.env)"

if [ -f .env ]; then
  vert "  .env existe déjà — conservé tel quel"
else
  cp .env.example .env
  # Garage impose un secret RPC de 64 caractères hexadécimaux, format distinct
  # des autres mots de passe : on le traite avant la boucle générique.
  hex64="$(alea_hex64)"
  awk -v s="$hex64" '{sub(/CHANGE_ME_HEX64/, s); print}' .env > .env.tmp && mv .env.tmp .env
  # Remplace chaque CHANGE_ME par un secret distinct.
  while grep -q 'CHANGE_ME' .env; do
    secret="$(alea_motdepasse)"
    # -i portable macOS/Linux : on passe par un fichier temporaire.
    awk -v s="$secret" 'BEGIN{done=0} { if (!done && index($0,"CHANGE_ME")) { sub(/CHANGE_ME/, s); done=1 } print }' .env > .env.tmp
    mv .env.tmp .env
  done
  chmod 600 .env
  vert "  .env créé avec des mots de passe aléatoires (droits 600)"
  jaune "  Le mot de passe administrateur Moodle est dans .env (MOODLE_ADMIN_PASSWORD)."
fi

# On NE source PAS le .env : c'est un format Compose, pas un script shell.
# Une valeur comme « Ivoire-LMS (développement) » ferait échouer bash.
charger_env .env

# ───────────────────────── 5. Construction ───────────────────────────────
etape "Construction des images"
"${COMPOSE[@]}" build moodle-php

# ──────────────────────── 6. Données d'abord ─────────────────────────────
etape "Démarrage de PostgreSQL et Valkey"
"${COMPOSE[@]}" up -d postgres valkey

printf '  Attente de PostgreSQL'
for _ in $(seq 1 60); do
  if "${COMPOSE[@]}" exec -T postgres pg_isready -U "${MOODLE_DB_USER}" -d "${MOODLE_DB_NAME}" >/dev/null 2>&1; then
    echo; vert "  PostgreSQL prêt"; break
  fi
  printf '.'; sleep 2
done

# ───────────────────── 7. Installation de Moodle ──────────────────────────
etape "Installation de la base Moodle"
# On interroge directement la base plutôt qu'un script Moodle : la présence de
# la table mdl_config est le marqueur fiable d'une installation aboutie.
deja_installe="$("${COMPOSE[@]}" exec -T postgres psql -U "${MOODLE_DB_USER}" \
  -d "${MOODLE_DB_NAME}" -tAc \
  "SELECT 1 FROM information_schema.tables WHERE table_name = 'mdl_config'" 2>/dev/null || true)"

if [ "${deja_installe//[[:space:]]/}" = "1" ]; then
  vert "  Moodle est déjà installé — étape ignorée"
else
  # Moodle 5 : les scripts CLI sont à la racine (admin/cli/), pas sous public/.
  if "${COMPOSE[@]}" run --rm -T \
        -e MOODLE_DEBUG=false \
        moodle-php php /var/www/html/admin/cli/install_database.php \
          --agree-license \
          --adminuser="${MOODLE_ADMIN_USER}" \
          --adminpass="${MOODLE_ADMIN_PASSWORD}" \
          --adminemail="${MOODLE_ADMIN_EMAIL}" \
          --fullname="${MOODLE_SITE_FULLNAME}" \
          --shortname="${MOODLE_SITE_SHORTNAME}" \
          --lang=fr; then
    vert "  Base Moodle installée, interface en français"
  else
    rouge "  L'installation de la base a échoué. Diagnostic :"
    rouge "    make logs SERVICE=moodle-php"
    exit 1
  fi
fi

# ───────────────────── 8. Le reste de la pile ─────────────────────────────
etape "Démarrage de la pile complète"
"${COMPOSE[@]}" up -d

# ─────────────────── 9. Initialisation de Garage ──────────────────────────
# Un nœud Garage neuf refuse toute écriture tant qu'aucune disposition
# (layout) ne lui a été assignée. C'est une étape unique, idempotente.
etape "Initialisation du stockage objet Garage"
printf '  Attente de Garage'
for _ in $(seq 1 30); do
  if "${COMPOSE[@]}" exec -T garage /garage status >/dev/null 2>&1; then
    echo; break
  fi
  printf '.'; sleep 2
done

if "${COMPOSE[@]}" exec -T garage /garage layout show 2>/dev/null | grep -q 'NO ROLE\|No nodes'; then
  noeud="$("${COMPOSE[@]}" exec -T garage /garage node id -q 2>/dev/null | cut -d'@' -f1 | tr -d '\r')"
  if [ -n "$noeud" ]; then
    "${COMPOSE[@]}" exec -T garage /garage layout assign -z ivoire -c 10G "$noeud" >/dev/null 2>&1 || true
    "${COMPOSE[@]}" exec -T garage /garage layout apply --version 1   >/dev/null 2>&1 || true
    vert "  Grappe Garage initialisée (1 nœud, zone ivoire)"
  else
    jaune "  Identifiant de nœud Garage introuvable — initialise à la main :"
    jaune "    make garage-init"
  fi
else
  vert "  Grappe Garage déjà initialisée"
fi

etape "État des services"
"${COMPOSE[@]}" ps

cat <<FIN

$(vert "Environnement Ivoire-LMS prêt.")

  Moodle                 ${MOODLE_WWWROOT}
    identifiant          ${MOODLE_ADMIN_USER}
    mot de passe         voir MOODLE_ADMIN_PASSWORD dans .env

  Keycloak (identité)    http://localhost:${KEYCLOAK_PORT:-8081}
    identifiant          ${KEYCLOAK_ADMIN:-admin}
    mot de passe         voir KEYCLOAK_ADMIN_PASSWORD dans .env

  Mailpit (courriels)    http://localhost:${MAILPIT_UI_PORT:-8025}
  Garage (stockage S3)   http://localhost:${GARAGE_S3_PORT:-3900}  (API S3, pas d'interface web)

  Journaux               make logs
  Arrêt                  make down
  Console Moodle         make shell

$(jaune "BigBlueButton n'est pas dans cette pile : il exige une machine dédiée sous")
$(jaune "Ubuntu et l'accès direct au réseau média. Voir docs/adr/0003-bigbluebutton-auto-heberge.md.")
FIN
