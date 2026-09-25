-- Keycloak a besoin de sa propre base, distincte de celle de Moodle.
-- Exécuté une seule fois, à l'initialisation du volume PostgreSQL.
SELECT 'CREATE DATABASE keycloak'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'keycloak')\gexec
