#!/usr/bin/env bash
# Installe les garde-fous de commit du projet Ivoire-LMS.
# À exécuter sur chaque poste de travail et après chaque nouveau clone.
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

git config --local core.hooksPath .githooks
git config --local commit.gpgsign false

# Identité du projet : aucun commit ne doit être attribué à un outil.
CURRENT_NAME="$(git config --local user.name || true)"
if [ -z "$CURRENT_NAME" ] || [ "$CURRENT_NAME" = "Claude" ]; then
  git config --local user.name "Armandodino"
  git config --local user.email "anzanarmando@gmail.com"
fi

# Neutralise une configuration globale héritée d'un outil.
GLOBAL_NAME="$(git config --global user.name || true)"
case "$GLOBAL_NAME" in
  Claude*|claude*)
    git config --global user.name "Armandodino"
    git config --global user.email "anzanarmando@gmail.com"
    ;;
esac
GLOBAL_KEY="$(git config --global user.signingkey || true)"
case "$GLOBAL_KEY" in
  *claude*|*anthropic*)
    git config --global --unset user.signingkey || true
    git config --global --unset commit.gpgsign || true
    git config --global --unset gpg.ssh.program || true
    ;;
esac

chmod +x .githooks/* 2>/dev/null || true

echo "Garde-fous installés."
echo "  hooksPath  : $(git config --local core.hooksPath)"
echo "  auteur     : $(git config user.name) <$(git config user.email)>"
