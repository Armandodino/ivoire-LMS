#!/usr/bin/env bash
# Teste les briques shell de bootstrap.sh DANS LES MÊMES CONDITIONS que lui
# (set -euo pipefail). C'est le point essentiel : les deux bogues trouvés en
# intégration continue ne se manifestaient que sous ces options, et un test
# lancé sans elles les aurait laissés passer tous les deux.
set -euo pipefail

cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/lib/alea.sh
. scripts/lib/alea.sh
# shellcheck source=scripts/lib/env.sh
. scripts/lib/env.sh

echecs=0
verifier() {
  local libelle="$1" attendu="$2" obtenu="$3"
  if [ "$attendu" = "$obtenu" ]; then
    printf '  [ok] %-52s %s\n' "$libelle" "$obtenu"
  else
    printf '  [ECHEC] %-49s attendu %s, obtenu %s\n' "$libelle" "$attendu" "$obtenu"
    echecs=$((echecs + 1))
  fi
}

echo "Génération de secrets, sous set -euo pipefail :"

for n in 1 8 28 64 100; do
  verifier "longueur demandée $n" "$n" "$(alea "$n" | wc -c | tr -d ' ')"
done

verifier "alea_hex64 fait 64 caractères" "64" "$(alea_hex64 | wc -c | tr -d ' ')"
verifier "alea_motdepasse fait 28 caractères" "28" "$(alea_motdepasse | wc -c | tr -d ' ')"

hex="$(alea_hex64)"
if [[ "$hex" =~ ^[a-f0-9]{64}$ ]]; then
  printf '  [ok] %-52s %s\n' "alea_hex64 respecte le jeu [a-f0-9]" "${hex:0:16}…"
else
  printf '  [ECHEC] alea_hex64 hors jeu : %s\n' "$hex"; echecs=$((echecs + 1))
fi

mdp="$(alea_motdepasse)"
if [[ "$mdp" =~ ^[A-Za-z0-9]{28}$ ]]; then
  printf '  [ok] %-52s %s\n' "alea_motdepasse respecte le jeu alphanumérique" "${mdp:0:8}…"
else
  printf '  [ECHEC] alea_motdepasse hors jeu : %s\n' "$mdp"; echecs=$((echecs + 1))
fi

# Deux appels consécutifs ne doivent pas rendre la même valeur.
if [ "$(alea_motdepasse)" != "$(alea_motdepasse)" ]; then
  printf '  [ok] %-52s\n' "deux appels donnent des valeurs différentes"
else
  printf '  [ECHEC] deux appels ont rendu la même valeur\n'; echecs=$((echecs + 1))
fi

# 40 générations d'affilée : le bogue du tube cassé était intermittent.
for _ in $(seq 1 40); do alea_motdepasse >/dev/null; alea_hex64 >/dev/null; done
printf '  [ok] %-52s\n' "80 générations d'affilée sans erreur de tube"

echo
echo "Lecture du .env, sans l'interpréter comme du shell :"

essai="$(mktemp)"
cat > "$essai" <<'FIN'
# un commentaire

SIMPLE=valeur
AVEC_PARENTHESES=Ivoire-LMS (développement)
AVEC_ESPACES=Institut National Polytechnique
AVEC_APOSTROPHE=Côte d'Ivoire
ENTRE_GUILLEMETS="valeur quotée"
ENTRE_APOSTROPHES='autre valeur'
VIDE=
AVEC_EGAL=cle=valeur=suite
export AVEC_EXPORT=exportee
  ESPACE_AVANT_CLE=ok
PAS_UNE_LIGNE_CLE_VALEUR
CLE-INVALIDE=ignoree
DANGEREUX=$(touch /tmp/ivoire-lms-injection-shell)
FIN

rm -f /tmp/ivoire-lms-injection-shell
charger_env "$essai"

verifier "valeur simple"                      "valeur"                            "$SIMPLE"
verifier "valeur avec parenthèses"            "Ivoire-LMS (développement)"        "$AVEC_PARENTHESES"
verifier "valeur avec espaces"                "Institut National Polytechnique"   "$AVEC_ESPACES"
verifier "valeur avec apostrophe"             "Côte d'Ivoire"                     "$AVEC_APOSTROPHE"
verifier "guillemets encadrants retirés"      "valeur quotée"                     "$ENTRE_GUILLEMETS"
verifier "apostrophes encadrantes retirées"   "autre valeur"                      "$ENTRE_APOSTROPHES"
verifier "valeur vide"                        ""                                  "${VIDE-absente}"
verifier "signes égal dans la valeur"         "cle=valeur=suite"                  "$AVEC_EGAL"
verifier "préfixe export toléré"              "exportee"                          "$AVEC_EXPORT"
verifier "espaces avant la clé"               "ok"                                "$ESPACE_AVANT_CLE"
verifier "clé au nom invalide ignorée"        "absente"                           "${CLE_INVALIDE-absente}"

# Le point le plus important : une valeur ne doit JAMAIS être évaluée.
verifier "substitution de commande non évaluée" \
         '$(touch /tmp/ivoire-lms-injection-shell)' "$DANGEREUX"
if [ -e /tmp/ivoire-lms-injection-shell ]; then
  printf '  [ECHEC] %s\n' "une valeur du .env a été exécutée : faille d'injection"
  echecs=$((echecs + 1))
else
  printf '  [ok] %-52s\n' "aucune commande exécutée depuis le .env"
fi
rm -f "$essai" /tmp/ivoire-lms-injection-shell

echo
echo "Non-régression du cas exact rencontré en intégration continue :"
reel="$(mktemp)"
printf 'MOODLE_SITE_FULLNAME=Ivoire-LMS (développement)\n' > "$reel"
if ( . "$reel" ) 2>/dev/null; then
  printf '  [ECHEC] %s\n' "sourcer ce .env aurait dû échouer ; le test ne prouve rien"
  echecs=$((echecs + 1))
else
  printf '  [ok] %-52s\n' "sourcer ce .env échoue bien (code $?)"
fi
charger_env "$reel"
verifier "charger_env le lit sans broncher" "Ivoire-LMS (développement)" "$MOODLE_SITE_FULLNAME"
rm -f "$reel"

echo
echo "Contrôle des extensions PHP (hors Docker, sur des listes témoins) :"

VERIF=infra/docker/moodle/verifier-extensions.sh
modules="$(mktemp)"

# Liste relevée telle quelle sur un runner GitHub, image php:8.3-fpm-bookworm.
# Le point important : OPcache y apparaît sous « Zend OPcache ».
cat > "$modules" <<'FIN'
[PHP Modules]
Core
ctype
curl
date
dom
exif
fileinfo
filter
gd
hash
iconv
intl
json
libxml
mbstring
mysqlnd
openssl
pcre
PDO
pdo_pgsql
pdo_sqlite
pgsql
Phar
posix
random
readline
redis
Reflection
session
SimpleXML
soap
sodium
SPL
sqlite3
standard
tokenizer
xml
xmlreader
xmlwriter
Zend OPcache
zip
zlib

[Zend Modules]
Zend OPcache

FIN

# Pas de tube ici : on veut le code de sortie du script, pas celui d'un head.
if "$VERIF" "$modules" >/dev/null 2>&1; then
  printf '  [ok] %-52s\n' "liste réelle du runner acceptée (Zend OPcache reconnu)"
else
  printf '  [ECHEC] %s\n' "la liste réelle du runner est refusée"
  "$VERIF" "$modules" 2>&1 | sed 's/^/          /' || true
  echecs=$((echecs + 1))
fi

# Chaque absence doit être détectée, y compris celle d'OPcache.
for absente in intl gd redis pgsql sodium; do
  sans="$(mktemp)"
  grep -vix "$absente" "$modules" > "$sans"
  if "$VERIF" "$sans" >/dev/null 2>&1; then
    printf '  [ECHEC] %s\n' "absence de '$absente' non détectée"
    echecs=$((echecs + 1))
  else
    printf '  [ok] %-52s\n' "absence de '$absente' détectée"
  fi
  rm -f "$sans"
done

sans_opcache="$(mktemp)"
grep -v 'OPcache' "$modules" > "$sans_opcache"
if "$VERIF" "$sans_opcache" >/dev/null 2>&1; then
  printf '  [ECHEC] %s\n' "absence d'OPcache non détectée"
  echecs=$((echecs + 1))
else
  printf '  [ok] %-52s\n' "absence d'OPcache détectée"
fi
rm -f "$sans_opcache" "$modules"

echo
if [ "$echecs" -gt 0 ]; then
  echo "ÉCHEC : $echecs cas en erreur."; exit 1
fi
echo "Tous les cas passent : secrets, lecture du .env, extensions PHP."
