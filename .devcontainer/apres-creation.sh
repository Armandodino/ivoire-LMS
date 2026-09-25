#!/usr/bin/env bash
# Préparation du conteneur de développement. Volontairement court : il installe
# les garde-fous et récupère le moteur Moodle, mais ne démarre pas la pile.
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

echo "==> Garde-fous de commit"
./scripts/install-hooks.sh

echo
echo "==> Moteur Moodle (clone superficiel, ~150 Mo)"
if [ -f engines/moodle/config-dist.php ]; then
  echo "    déjà présent"
else
  git submodule update --init --depth 1 engines/moodle
fi
grep -E '\$release' engines/moodle/public/version.php || true

echo
cat <<'FIN'
=========================================================================
 Environnement Ivoire-LMS prêt.

   make bootstrap     démarre toute la pile (plusieurs minutes la 1re fois)
   make help          liste les commandes
   make veille        vérifie qu'aucune brique amont n'est morte

 Une fois la pile démarrée, les ports sont redirigés automatiquement :
 Moodle sur 8080, Keycloak sur 8081, Mailpit sur 8025.

 Open edX et BigBlueButton ne sont pas dans cette pile : voir
 docs/adr/0004-phasage-des-moteurs.md et
 docs/adr/0003-bigbluebutton-auto-heberge.md.
=========================================================================
FIN
