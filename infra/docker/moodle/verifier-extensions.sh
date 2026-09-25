#!/bin/sh
# Vérifie que toutes les extensions PHP exigées par Moodle 5.2 sont chargées.
# Source de vérité : engines/moodle/public/admin/environment.xml, bloc MOODLE 5.2.
#
# Exécuté pendant la construction de l'image : une extension manquante fait
# échouer le build, plutôt que de livrer une image qui tombe en panne devant un
# utilisateur.
#
# Le piège traité ici : « php -m » n'affiche PAS toujours le nom court de
# l'extension. OPcache y apparaît sous « Zend OPcache ». Une comparaison exacte
# sur « opcache » échoue donc alors que l'extension est bien chargée. On
# normalise : minuscules, retrait du préfixe « zend », suppression des en-têtes
# entre crochets.
#
# Usage :
#   verifier-extensions.sh              interroge php -m
#   verifier-extensions.sh FICHIER      lit la liste depuis un fichier (tests)
set -eu

# Les 20 exigées par Moodle 5.2 (environment.xml, niveau « required ») :
MOODLE_REQUISES="ctype curl dom fileinfo filter gd hash iconv intl json
mbstring openssl pcre simplexml sodium spl xml xmlreader zip zlib"

# Les 4 que NOTRE pile impose en plus :
#   pgsql   : PostgreSQL est notre base (ADR de la pile de développement)
#   opcache : indispensable au volume de fichiers PHP de Moodle
#   redis   : exigé par le gestionnaire de sessions, vers Valkey
#   exif    : recommandé par Moodle, utile au traitement des images
NOTRE_PILE="pgsql opcache redis exif"

REQUISES="$MOODLE_REQUISES $NOTRE_PILE"

if [ "${1:-}" != "" ]; then
  brut="$(cat "$1")"
else
  brut="$(php -m)"
fi

presentes="$(
  printf '%s\n' "$brut" \
    | tr 'A-Z' 'a-z' \
    | sed -e 's/^zend //' -e 's/[[:space:]]*$//' \
    | grep -vE '^\[|^$' \
    | sort -u
)"

absentes=""
for ext in $REQUISES; do
  printf '%s\n' "$presentes" | grep -qx "$ext" || absentes="$absentes $ext"
done

if [ -n "$absentes" ]; then
  echo "ERREUR : extensions PHP requises par Moodle 5.2 absentes :$absentes" >&2
  echo "Extensions détectées après normalisation :" >&2
  printf '%s\n' "$presentes" | sed 's/^/  /' >&2
  exit 1
fi

nb_moodle=$(printf '%s\n' $MOODLE_REQUISES | wc -l | tr -d ' ')
nb_pile=$(printf '%s\n' $NOTRE_PILE | wc -l | tr -d ' ')
echo "Extensions PHP vérifiées : $nb_moodle exigées par Moodle 5.2, $nb_pile par notre pile. Toutes présentes."
