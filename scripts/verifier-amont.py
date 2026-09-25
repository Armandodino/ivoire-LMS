#!/usr/bin/env python3
"""Vérifie que toutes les briques amont d'Ivoire-LMS sont encore vivantes.

Une dépendance morte est une dette de sécurité qui ne se signale pas toute
seule : MinIO a été archivé en avril 2026 sans que rien ne le dise à ceux qui
l'avaient déjà déployé. Ce script refuse de laisser passer ce cas.

Trois signaux, par ordre de gravité :
  MORTE    le dépôt amont est archivé, ou l'éditeur annonce la fin de vie
  DORMANTE aucun commit depuis le seuil configuré
  VIVANTE  activité récente

Sortie : 1 si au moins une brique est MORTE, 0 sinon.
Usage   : python3 scripts/verifier-amont.py [--seuil-jours 270] [--json]
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import os
import pathlib
import sys
import urllib.error
import urllib.request

# Briques suivies. 'github' = dépôt de référence ; 'eol' = produit sur
# endoflife.date pour ce qui n'est pas piloté par un dépôt GitHub.
BRIQUES: list[dict] = [
    # Moteurs pédagogiques
    {"nom": "Moodle",          "github": "moodle/moodle",                 "role": "moteur LMS"},
    {"nom": "Open edX",        "github": "openedx/edx-platform",          "role": "moteur MOOC (phase 2)"},
    {"nom": "BigBlueButton",   "github": "bigbluebutton/bigbluebutton",   "role": "classe virtuelle"},
    # Socle d'exécution
    {"nom": "Keycloak",        "github": "keycloak/keycloak",             "role": "identité unique"},
    {"nom": "Valkey",          "github": "valkey-io/valkey",              "role": "sessions et cache"},
    {"nom": "Garage",          "github": "deuxfleurs-org/garage",         "role": "stockage objet S3"},
    {"nom": "Mailpit",         "github": "axllent/mailpit",               "role": "courriels en dev"},
    # Socle commerce et certificats (ADR 0006)
    {"nom": "Joanie",          "github": "openfun/joanie",                "role": "commerce, contrats, certificats"},
    {"nom": "Ralph",           "github": "openfun/ralph",                 "role": "LRS xAPI (candidat, jalon 8)"},
    # Produits suivis par cycle de vie plutôt que par dépôt
    {"nom": "PostgreSQL",      "eol": "postgresql", "cycle": "17",        "role": "base de données"},
    {"nom": "PHP",             "eol": "php",        "cycle": "8.3",       "role": "exécution Moodle"},
    {"nom": "nginx",           "eol": "nginx",      "cycle": "1.30",      "role": "serveur web"},
    # Joanie épingle Django<5 : réserve consignée dans l'ADR 0006.
    {"nom": "Django (Joanie)", "eol": "django",     "cycle": "4.2",       "role": "socle de Joanie"},
]

MORTE, DORMANTE, VIVANTE, INCONNU = "MORTE", "DORMANTE", "VIVANTE", "INCONNU"
DEROGEE = "DEROGEE"

# Dérogations : une brique morte que nous ne pouvons pas remplacer nous-mêmes
# aujourd'hui, avec une échéance et une action nommée. Ce n'est PAS un moyen de
# faire taire le détecteur : passé l'échéance, la dérogation expire et l'échec
# revient. Une dérogation sans date ni action n'a pas sa place ici.
DEROGATIONS: dict[str, dict[str, str]] = {
    "Django (Joanie)": {
        "jusqu_au": "2026-12-31",
        "motif": "Dépendance interne de Joanie, qui épingle Django<5 "
                 "(src/backend/pyproject.toml). Nous ne pouvons pas la changer "
                 "sans l'amont. Aucune mise en production avec cette version.",
        "action": "Vérifier si l'amont a migré vers Django 5 ; sinon proposer le "
                  "portage en amont. Voir ADR 0006, section Réserve à surveiller.",
    },
}

# Date de référence des cas de test, pour que --autotest soit reproductible.
DATE_TEST = dt.date(2026, 9, 25)


def _get(url: str) -> dict | list | None:
    req = urllib.request.Request(url, headers={
        "Accept": "application/json",
        "User-Agent": "ivoire-lms-veille",
    })
    jeton = os.environ.get("GITHUB_TOKEN")
    if jeton and "api.github.com" in url:
        req.add_header("Authorization", f"Bearer {jeton}")
    try:
        with urllib.request.urlopen(req, timeout=20) as r:
            return json.loads(r.read().decode())
    except (urllib.error.URLError, urllib.error.HTTPError, TimeoutError, ValueError):
        return None


def _jours_depuis(horodatage: str | None) -> int | None:
    if not horodatage:
        return None
    try:
        quand = dt.datetime.fromisoformat(horodatage.replace("Z", "+00:00"))
    except ValueError:
        return None
    return (dt.datetime.now(dt.timezone.utc) - quand).days


def classer_depot(depot: dict, age: int | None, seuil: int) -> tuple[str, str]:
    """Classe un dépôt GitHub. Séparé du réseau pour être testable (--autotest)."""
    if depot.get("archived"):
        return MORTE, "dépôt ARCHIVÉ par son propriétaire"
    if age is not None and age > seuil:
        return DORMANTE, f"aucun commit depuis {age} jours"
    if age is None:
        return VIVANTE, "actif"
    return VIVANTE, f"dernier commit il y a {age} jours"


def classer_cycle(infos: dict, cycle: str, aujourdhui: dt.date) -> tuple[str, str]:
    """Classe un cycle de vie endoflife.date. Séparé du réseau pour être testable."""
    eol = infos.get("eol")
    if eol is True:
        return MORTE, f"la version {cycle} est en fin de vie"
    if isinstance(eol, str):
        restant = (dt.date.fromisoformat(eol) - aujourdhui).days
        if restant < 0:
            return MORTE, f"fin de vie dépassée depuis le {eol}"
        if restant < 180:
            return DORMANTE, f"fin de vie le {eol}, dans {restant} jours"
        return VIVANTE, f"soutenue jusqu'au {eol}"
    return VIVANTE, "aucune fin de vie annoncée"


def appliquer_derogation(resultat: dict, aujourdhui: dt.date) -> dict:
    """Requalifie une brique MORTE couverte par une dérogation non expirée."""
    if resultat["etat"] != MORTE:
        return resultat
    derogation = DEROGATIONS.get(resultat["nom"])
    if not derogation:
        return resultat
    echeance = dt.date.fromisoformat(derogation["jusqu_au"])
    if aujourdhui > echeance:
        resultat["detail"] += f" — DÉROGATION EXPIRÉE le {derogation['jusqu_au']}"
        return resultat
    resultat["etat"] = DEROGEE
    resultat["derogation"] = derogation
    resultat["detail"] += f" — dérogation jusqu'au {derogation['jusqu_au']}"
    return resultat


def examiner(brique: dict, seuil: int) -> dict:
    resultat = {"nom": brique["nom"], "role": brique["role"], "etat": INCONNU, "detail": ""}

    if "github" in brique:
        resultat["source"] = brique["github"]
        depot = _get(f"https://api.github.com/repos/{brique['github']}")
        if depot is None:
            resultat["detail"] = "dépôt injoignable (réseau ou quota d'API)"
            return resultat
        age = _jours_depuis(depot.get("pushed_at"))
        resultat["jours"] = age
        resultat["etat"], resultat["detail"] = classer_depot(depot, age, seuil)
        return appliquer_derogation(resultat, dt.date.today())

    produit, cycle = brique["eol"], brique["cycle"]
    resultat["source"] = f"endoflife.date/{produit}#{cycle}"
    infos = _get(f"https://endoflife.date/api/{produit}/{cycle}.json")
    if infos is None:
        resultat["detail"] = "cycle de vie injoignable"
        return resultat
    resultat["etat"], resultat["detail"] = classer_cycle(infos, cycle, dt.date.today())
    return appliquer_derogation(resultat, dt.date.today())


def autotest() -> int:
    """Vérifie la logique de classement sans aucun accès réseau."""
    cas = [
        ("dépôt archivé (cas MinIO)",       classer_depot({"archived": True}, 3, 270),        MORTE),
        ("dépôt actif",                     classer_depot({"archived": False}, 3, 270),       VIVANTE),
        ("dépôt sans commit depuis 2 ans",  classer_depot({"archived": False}, 730, 270),     DORMANTE),
        ("dépôt pile sur le seuil",         classer_depot({"archived": False}, 270, 270),     VIVANTE),
        ("cycle en fin de vie (booléen)",   classer_cycle({"eol": True}, "9", DATE_TEST),     MORTE),
        ("cycle fin de vie dépassée",       classer_cycle({"eol": "2020-01-01"}, "9", DATE_TEST), MORTE),
        ("cycle fin de vie dans 30 jours",  classer_cycle({"eol": "2026-10-25"}, "9", DATE_TEST), DORMANTE),
        ("cycle fin de vie dans 3 ans",     classer_cycle({"eol": "2029-11-01"}, "17", DATE_TEST), VIVANTE),
        ("cycle sans fin de vie annoncée",  classer_cycle({}, "1", DATE_TEST),                VIVANTE),
    ]

    # La dérogation ne doit couvrir qu'une brique morte, et seulement avant son échéance.
    derog = {"jusqu_au": "2026-12-31", "motif": "m", "action": "a"}
    DEROGATIONS["__test__"] = derog
    cas_derog = [
        ("dérogation avant échéance",
         appliquer_derogation({"nom": "__test__", "etat": MORTE, "detail": "x"}, DATE_TEST),
         DEROGEE),
        ("dérogation expirée",
         appliquer_derogation({"nom": "__test__", "etat": MORTE, "detail": "x"},
                              dt.date(2027, 1, 1)),
         MORTE),
        ("brique sans dérogation",
         appliquer_derogation({"nom": "__inconnue__", "etat": MORTE, "detail": "x"}, DATE_TEST),
         MORTE),
        ("dérogation ne requalifie pas une brique vivante",
         appliquer_derogation({"nom": "__test__", "etat": VIVANTE, "detail": "x"}, DATE_TEST),
         VIVANTE),
    ]
    del DEROGATIONS["__test__"]
    for libelle, res, attendu in cas_derog:
        cas.append((libelle, (res["etat"], res["detail"]), attendu))
    echecs = 0
    for libelle, (etat, detail), attendu in cas:
        ok = etat == attendu
        echecs += 0 if ok else 1
        print(f"  [{'ok' if ok else 'ECHEC'}] {libelle:<34} -> {etat:<8} ({detail})")
    print()
    if echecs:
        print(f"ÉCHEC : {echecs} cas de classement incorrect(s).")
    else:
        print(f"Les {len(cas)} cas de classement sont corrects.")
    return 1 if echecs else 0


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--seuil-jours", type=int, default=270,
                    help="nombre de jours sans commit à partir duquel une brique est dite dormante")
    ap.add_argument("--json", action="store_true", help="sortie lisible par une machine")
    ap.add_argument("--autotest", action="store_true",
                    help="vérifie la logique de classement sans réseau, puis quitte")
    ap.add_argument("--json-vers", metavar="FICHIER",
                    help="écrit aussi le rapport JSON dans ce fichier "
                         "(évite une seconde exécution, donc un second appel réseau)")
    args = ap.parse_args()

    if args.autotest:
        return autotest()

    resultats = [examiner(b, args.seuil_jours) for b in BRIQUES]

    if args.json_vers:
        pathlib.Path(args.json_vers).write_text(
            json.dumps(resultats, ensure_ascii=False, indent=2), encoding="utf-8")

    if args.json:
        print(json.dumps(resultats, ensure_ascii=False, indent=2))
    else:
        symbole = {VIVANTE: "  ok  ", DORMANTE: " ATTN ", MORTE: " MORTE",
                   DEROGEE: " DEROG", INCONNU: "  ??  "}
        print(f"{'état':^7} {'brique':<16} {'rôle':<26} détail")
        print("-" * 96)
        for r in resultats:
            print(f"[{symbole[r['etat']]}] {r['nom']:<16} {r['role']:<26} {r['detail']}")

    mortes = [r for r in resultats if r["etat"] == MORTE]
    dormantes = [r for r in resultats if r["etat"] == DORMANTE]
    derogees = [r for r in resultats if r["etat"] == DEROGEE]
    inconnues = [r for r in resultats if r["etat"] == INCONNU]

    if not args.json:
        print()
        if mortes:
            print(f"ÉCHEC : {len(mortes)} brique(s) morte(s) — il faut les remplacer, pas les tolérer :")
            for r in mortes:
                print(f"  - {r['nom']} ({r['role']}) : {r['detail']}")
        if derogees:
            print(f"Dérogations en cours : {len(derogees)} — mortes mais tolérées "
                  f"temporairement, jamais en production :")
            for r in derogees:
                d = r["derogation"]
                print(f"  - {r['nom']} jusqu'au {d['jusqu_au']}")
                print(f"      motif  : {d['motif']}")
                print(f"      action : {d['action']}")
        if dormantes:
            print(f"Vigilance : {len(dormantes)} brique(s) dormante(s), à surveiller.")
        if inconnues:
            print(f"Non vérifiées : {len(inconnues)} (réseau, quota d'API ou source indisponible).")
        if not mortes and not dormantes and not inconnues and not derogees:
            print("Toutes les briques amont sont vivantes.")

    # Ne jamais annoncer un succès quand rien n'a pu être vérifié : une panne
    # réseau qui passe pour un feu vert est plus dangereuse qu'un échec franc.
    if mortes:
        return 1
    if len(inconnues) == len(resultats):
        if not args.json:
            print("Aucune brique n'a pu être vérifiée : résultat non concluant, pas un succès.")
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
