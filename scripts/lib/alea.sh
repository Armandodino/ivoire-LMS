#!/usr/bin/env bash
# Génération de secrets aléatoires, sûre sous `set -euo pipefail`.
#
# Le piège évité ici : `tr -dc ... < /dev/urandom | head -c N` fait fermer le
# tube par head dès qu'il a ses N octets. tr reçoit alors un SIGPIPE, écrit
# « write error: Broken pipe » et sort en erreur — ce que pipefail transforme en
# échec du script entier. Le symptôme est intermittent selon la machine, donc
# particulièrement traître.
#
# La parade : donner à tr une entrée FINIE (substitution de processus sur un
# head borné), et couper à la longueur voulue avec l'expansion de paramètre de
# bash, sans aucun tube en aval.

# alea <longueur> [jeu de caractères]
# Écrit sur la sortie standard exactement <longueur> caractères du jeu donné.
alea() {
  local longueur="${1:?alea : longueur manquante}"
  local jeu="${2:-A-Za-z0-9}"
  local brut=""
  local garde=0

  while [ "${#brut}" -lt "$longueur" ]; do
    brut+="$(LC_ALL=C tr -dc "$jeu" < <(head -c 4096 /dev/urandom))"
    garde=$((garde + 1))
    if [ "$garde" -gt 64 ]; then
      echo "alea : impossible de produire $longueur caractères du jeu '$jeu'" >&2
      return 1
    fi
  done

  printf '%s' "${brut:0:longueur}"
}

# Secret RPC de Garage : exactement 64 caractères hexadécimaux minuscules.
alea_hex64() { alea 64 'a-f0-9'; }

# Mot de passe de service : 28 caractères alphanumériques.
alea_motdepasse() { alea 28 'A-Za-z0-9'; }
