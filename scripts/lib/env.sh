#!/usr/bin/env bash
# Lecture d'un fichier .env SANS l'interpréter comme du shell.
#
# Le piège évité ici : `set -a; . ./.env; set +a` traite le .env comme un
# script. Or un .env est un format Docker Compose, où une valeur peut contenir
# des parenthèses, des espaces ou des apostrophes sans être quotée :
#
#     MOODLE_SITE_FULLNAME=Ivoire-LMS (développement)
#
# bash répond alors « syntax error near unexpected token `(' » et sort avec le
# code 2. Compose, lui, l'accepte : il a son propre analyseur. Traiter un .env
# comme du shell est donc une erreur de fond, pas un cas particulier à quoter.
#
# La parade : découper sur le premier « = » et exporter la valeur telle quelle,
# sans aucune évaluation. Aucune substitution de commande n'est possible, ce qui
# est aussi plus sûr : un .env n'a pas à pouvoir exécuter du code.

# charger_env [chemin]
# Exporte chaque clé du fichier. Ignore commentaires et lignes vides, retire un
# éventuel « export » en tête et les guillemets encadrants.
charger_env() {
  local fichier="${1:-.env}"
  local ligne cle valeur

  if [ ! -f "$fichier" ]; then
    echo "charger_env : fichier introuvable : $fichier" >&2
    return 1
  fi

  while IFS= read -r ligne || [ -n "$ligne" ]; do
    # Commentaires et lignes vides.
    case "$ligne" in
      ''|'#'*) continue ;;
    esac
    # Seules les lignes de la forme CLE=... nous intéressent.
    case "$ligne" in
      *=*) ;;
      *) continue ;;
    esac

    cle="${ligne%%=*}"
    valeur="${ligne#*=}"

    # « export CLE=... » est accepté par tolérance.
    cle="${cle#export }"
    # Espaces autour du nom de clé.
    cle="${cle#"${cle%%[![:space:]]*}"}"
    cle="${cle%"${cle##*[![:space:]]}"}"

    # Un nom de variable shell valide, sinon on ignore la ligne.
    case "$cle" in
      [A-Za-z_]*) ;;
      *) continue ;;
    esac
    if [ -n "${cle//[A-Za-z0-9_]/}" ]; then
      continue
    fi

    # Guillemets encadrants éventuels.
    if [ ${#valeur} -ge 2 ]; then
      case "$valeur" in
        '"'*'"') valeur="${valeur#\"}"; valeur="${valeur%\"}" ;;
        "'"*"'") valeur="${valeur#\'}"; valeur="${valeur%\'}" ;;
      esac
    fi

    # Export sans évaluation : la valeur n'est jamais interprétée.
    export "$cle=$valeur"
  done < "$fichier"
}
