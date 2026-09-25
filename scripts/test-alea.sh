#!/usr/bin/env bash
# Vérifie la génération de secrets DANS LES MÊMES CONDITIONS que bootstrap.sh.
# C'est le point essentiel : le bogue corrigé ici ne se manifestait qu'avec
# pipefail actif, et un test sans pipefail l'aurait laissé passer.
set -euo pipefail

cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/lib/alea.sh
. scripts/lib/alea.sh

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
if [ "$echecs" -gt 0 ]; then
  echo "ÉCHEC : $echecs cas en erreur."; exit 1
fi
echo "Génération de secrets : tous les cas passent."
