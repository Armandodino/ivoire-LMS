<?php
// Configuration Moodle pour Ivoire-LMS — lue depuis l'environnement.
//
// En Moodle 5.x ce fichier vit à la RACINE du code (/var/www/html/config.php).
// public/config.php n'est qu'un chargeur qui fait require de ../config.php.
//
// Ce fichier est monté en lecture seule dans le conteneur : il ne contient aucun
// secret en dur, tout vient de .env via l'environnement du conteneur.

unset($CFG);
global $CFG;
$CFG = new stdClass();

/**
 * Lit une variable d'environnement, avec valeur de repli.
 * Échoue bruyamment si une variable obligatoire manque : mieux vaut un message
 * clair au démarrage qu'une base de données inaccessible sans explication.
 */
function ivoire_env(string $name, ?string $default = null): string {
    $value = getenv($name);
    if ($value === false || $value === '') {
        if ($default === null) {
            fwrite(STDERR, "Ivoire-LMS : variable d'environnement obligatoire manquante : {$name}\n");
            throw new RuntimeException("Variable d'environnement manquante : {$name}");
        }
        return $default;
    }
    return $value;
}

// ── Base de données ──────────────────────────────────────────────────────
$CFG->dbtype    = 'pgsql';
$CFG->dblibrary = 'native';
$CFG->dbhost    = ivoire_env('MOODLE_DB_HOST', 'postgres');
$CFG->dbname    = ivoire_env('MOODLE_DB_NAME', 'moodle');
$CFG->dbuser    = ivoire_env('MOODLE_DB_USER', 'moodle');
$CFG->dbpass    = ivoire_env('MOODLE_DB_PASSWORD');
$CFG->prefix    = 'mdl_';
$CFG->dboptions = [
    'dbpersist' => false,
    'dbport'    => 5432,
    'dbsocket'  => '',
    'dbcollation' => 'utf8mb4_unicode_ci',
];

// ── Emplacements ─────────────────────────────────────────────────────────
$CFG->wwwroot   = rtrim(ivoire_env('MOODLE_WWWROOT', 'http://localhost:8080'), '/');
$CFG->dataroot  = '/var/www/moodledata';
$CFG->admin     = 'admin';
$CFG->directorypermissions = 0o2777;

// ── Derrière la passerelle Ivoire-LMS ────────────────────────────────────
// La passerelle termine TLS ; Moodle doit savoir qu'il est en HTTPS côté client,
// sinon il génère des URL en http et casse les ressources sur les pages chiffrées.
if (str_starts_with($CFG->wwwroot, 'https://')) {
    $CFG->sslproxy = true;
}
$CFG->reverseproxy = filter_var(
    getenv('MOODLE_REVERSE_PROXY') ?: 'false', FILTER_VALIDATE_BOOLEAN
);

// ── Cache et sessions dans Redis ─────────────────────────────────────────
// Indispensable dès qu'il y a plus d'un conteneur PHP : sans cela, un utilisateur
// perd sa session en changeant de conteneur.
$redishost = getenv('MOODLE_REDIS_HOST');
if ($redishost) {
    $CFG->session_handler_class = '\core\session\redis';
    $CFG->session_redis_host    = $redishost;
    $CFG->session_redis_port    = 6379;
    $CFG->session_redis_database = 0;
    $CFG->session_redis_prefix  = 'ivoire_sess_';
    $CFG->session_redis_acquire_lock_timeout = 120;
    $CFG->session_redis_lock_expire = 7200;
}

// ── Courriel : intercepté par Mailpit en développement ───────────────────
$smtphost = getenv('MOODLE_SMTP_HOST');
if ($smtphost) {
    $CFG->smtphosts  = $smtphost;
    $CFG->smtpsecure = '';
    $CFG->noreplyaddress = getenv('MOODLE_NOREPLY_ADDRESS') ?: 'no-reply@ivoire-lms.localhost';
}

// ── BigBlueButton : verrouillé sur notre grappe ──────────────────────────
// Empêche un administrateur d'établissement de rebasculer sur un serveur tiers.
// Voir docs/adr/0003-bigbluebutton-auto-heberge.md.
$bbburl = getenv('BBB_SERVER_URL');
if ($bbburl) {
    $CFG->forced_plugin_settings['mod_bigbluebuttonbn'] = [
        'server_url'    => $bbburl,
        'shared_secret' => ivoire_env('BBB_SHARED_SECRET'),
    ];
}

// ── Réglages de développement ────────────────────────────────────────────
if (filter_var(getenv('MOODLE_DEBUG') ?: 'false', FILTER_VALIDATE_BOOLEAN)) {
    $CFG->debug = (E_ALL | E_STRICT);
    $CFG->debugdisplay = 1;
    $CFG->cachejs = false;
    $CFG->themedesignermode = true;
}

// ── Performance ──────────────────────────────────────────────────────────
// Le cron tourne dans son propre conteneur (service moodle-cron) : on interdit
// le déclenchement du cron par une requête web, qui ralentirait les utilisateurs.
$CFG->cronclionly = true;

require_once(__DIR__ . '/lib/setup.php');
