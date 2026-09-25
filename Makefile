SHELL := /bin/bash
.DEFAULT_GOAL := help

.PHONY: help hooks engines engines-shallow engines-status engines-update verify-authors up down logs

help: ## Affiche cette aide
	@grep -hE '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) \
		| awk 'BEGIN{FS=":.*?## "}{printf "  \033[36m%-18s\033[0m %s\n", $$1, $$2}'

hooks: ## Installe les garde-fous de commit (à faire après tout clone)
	@./scripts/install-hooks.sh

engines: ## Récupère les moteurs amont (sous-modules, historique complet)
	@git submodule update --init --recursive

engines-shallow: ## Récupère les moteurs amont en clone superficiel (plus rapide, ~1,3 Go)
	@git submodule update --init --recursive --depth 1

engines-status: ## Affiche la version figée de chaque moteur
	@git submodule status --recursive

engines-update: ## Avance les moteurs sur leur branche suivie (à relire avant commit)
	@git submodule update --remote --merge
	@echo "Relis 'git diff' puis committe la montée de version avec un message explicite."

verify-authors: ## Vérifie qu'aucune attribution d'outil IA ne traîne dans l'historique
	@if git log --format='%an <%ae>%n%b' \
		| grep -inE 'claude|anthropic|copilot|chatgpt|openai' ; then \
		echo "ÉCHEC : attribution d'outil IA détectée." ; exit 1 ; \
	else echo "OK : historique propre." ; fi

up: ## Démarre l'environnement de développement (jalon 1)
	@echo "Pas encore implémenté — voir docs/roadmap.md, jalon 1."
	@exit 1

down: ## Arrête l'environnement de développement
	@echo "Pas encore implémenté — voir docs/roadmap.md, jalon 1."
	@exit 1
