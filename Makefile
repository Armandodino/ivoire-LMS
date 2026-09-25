SHELL := /bin/bash
.DEFAULT_GOAL := help

COMPOSE := docker compose -f infra/compose/docker-compose.yml --env-file .env
SERVICE  ?=

.PHONY: help bootstrap hooks up down restart stop logs ps shell psql cron purge \
        engines engines-shallow engines-status engines-update verify-authors \
        up-openedx check

help: ## Affiche cette aide
	@echo "Ivoire-LMS — commandes disponibles"
	@echo
	@grep -hE '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) \
		| awk 'BEGIN{FS=":.*?## "}{printf "  \033[36m%-18s\033[0m %s\n", $$1, $$2}'
	@echo
	@echo "  Premier démarrage sur un poste neuf :  make bootstrap"

# ───────────────────────── Mise en route ─────────────────────────────────
bootstrap: ## Amorce tout l'environnement depuis zéro (à faire en premier)
	@./scripts/bootstrap.sh

hooks: ## Installe les garde-fous de commit (inclus dans bootstrap)
	@./scripts/install-hooks.sh

check: ## Vérifie la cohérence de la pile sans rien démarrer
	@test -f .env || { echo "Fichier .env absent — lance 'make bootstrap'." ; exit 1 ; }
	@test -f engines/moodle/config-dist.php || { echo "Sous-modules absents — lance 'make engines-shallow'." ; exit 1 ; }
	@$(COMPOSE) config --quiet && echo "Configuration Compose valide."
	@php -l infra/docker/moodle/config.php >/dev/null 2>&1 \
		&& echo "config.php Moodle : syntaxe valide" \
		|| echo "config.php Moodle : contrôle ignoré (php absent du poste)"

# ─────────────────────────── Exploitation ────────────────────────────────
up: ## Démarre la pile de développement (phase 1 : Moodle + Keycloak + outils)
	@$(COMPOSE) up -d
	@$(MAKE) --no-print-directory ps

up-openedx: ## Démarre en plus Open edX (phase 2 — voir ADR 0004)
	@echo "Open edX n'est pas encore branché sur cette pile."
	@echo "Voir docs/adr/0004-phasage-des-moteurs.md et docs/roadmap.md (jalon 1)."
	@exit 1

down: ## Arrête la pile (les données sont conservées)
	@$(COMPOSE) down

stop: ## Met la pile en pause sans supprimer les conteneurs
	@$(COMPOSE) stop

restart: ## Redémarre la pile
	@$(COMPOSE) restart $(SERVICE)

ps: ## Affiche l'état des services
	@$(COMPOSE) ps

logs: ## Suit les journaux (make logs SERVICE=moodle-php pour un seul service)
	@$(COMPOSE) logs -f --tail=100 $(SERVICE)

shell: ## Ouvre un shell dans le conteneur PHP de Moodle
	@$(COMPOSE) exec moodle-php bash

psql: ## Ouvre une console PostgreSQL
	@$(COMPOSE) exec postgres psql -U $$(grep '^MOODLE_DB_USER=' .env | cut -d= -f2) \
		-d $$(grep '^MOODLE_DB_NAME=' .env | cut -d= -f2)

cron: ## Force une exécution immédiate du cron Moodle
	@$(COMPOSE) exec moodle-php php /var/www/html/admin/cli/cron.php

purge: ## DESTRUCTIF : supprime conteneurs ET volumes (toutes les données locales)
	@read -p "Supprimer définitivement toutes les données locales ? [oui/N] " r ; \
	 if [ "$$r" = "oui" ]; then $(COMPOSE) down -v ; echo "Volumes supprimés." ; \
	 else echo "Annulé." ; fi

# ──────────────────────────── Moteurs ────────────────────────────────────
engines: ## Récupère les moteurs amont (historique complet, long)
	@git submodule update --init --recursive

engines-shallow: ## Récupère les moteurs amont, dernier commit seulement (~1,3 Go)
	@git submodule update --init --recursive --depth 1

engines-status: ## Affiche la version figée de chaque moteur
	@git submodule status --recursive

engines-update: ## Avance les moteurs sur leur branche suivie (à relire avant commit)
	@git submodule update --remote --merge
	@echo "Relis 'git diff' puis committe la montée de version avec un message explicite."

# ─────────────────────────── Conformité ──────────────────────────────────
verify-authors: ## Vérifie qu'aucune attribution d'outil IA ne traîne dans l'historique
	@if git log --format='%an <%ae>%n%b' \
		| grep -inE 'claude|anthropic|copilot|chatgpt|openai' ; then \
		echo "ÉCHEC : attribution d'outil IA détectée." ; exit 1 ; \
	else echo "OK : historique propre." ; fi
