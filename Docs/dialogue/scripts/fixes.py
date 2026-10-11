"""Autogen mishearing -> canonical term. Built from analysis/variants.txt plus targeted greps."""
import re

FIXES = [
    (r"\bgaussians\b", "Gaalsien"), (r"\bgaussian\b", "Gaalsien"),
    (r"\b(?:kapisis|kabisis)\b", "Kapisi's"), (r"\b(?:kapisi|capisi|capisci|kapiti|kabisi|kapici)\b", "Kapisi"),
    (r"\b(?:sakalas)\b", "Sakala's"), (r"\b(?:sakala|tsukala|zakala|takala)\b", "Sakala"),
    (r"\b(?:kartoba|car toba|cartoba|kartopa|carte oba|cart oba)\b", "Khar-Toba"),
    (r"\bkahad sajuks?\b", "K'had Sajuuk"), (r"\bsajuks\b", "Sajuuk's"), (r"\bsajuk\b", "Sajuuk"),
    (r"\b(?:siddhim|siddim)\b", "Siidim"), (r"\b(?:jaraki|jeraki|jockey)\b", "Jaraci"),
    (r"\bkarak\b", "Kharak"), (r"\bbase runners\b", "Baserunners"), (r"\bbase runner\b", "Baserunner"),
    (r"\bhonor guard\b", "Honorguard"), (r"\bashokas\b", "Ashoka's"), (r"\bashoka\b", "Ashoka"),
    (r"\bkagon\b", "Khagaan"), (r"\b(?:mashhad|mishad)\b", "Mashaad"), (r"\b(?:haidan|taidan|taitan|tai dan)\b", "Taiidan"),
    (r"\bnabals?\b", "Naabal"), (r"\b(?:great bandit desert|grape banded desert)\b", "Great Banded Desert"),
    (r"\brachels? (?:sajet|sejet|a jet|jet)\b", "Rachel S'jet"), (r"\b(?:sajet|sujet|sejet|sea jet)\b", "S'jet"),
    (r"\b(?:keith|kith)\b", "kiith"),
    # Faction chatter videos.
    (r"\bgod (set|position|protocol|directive|established|craft|order)\b", r"guard \1"), (r"\bto god\b", "to guard"),
    (r"\b(?:face|base|space|mace) (?:runner|wire|water|running|runnner)\b", "Baserunner"),
    (r"\bhonor (?:black|guard)\b", "Honorguard"), (r"\brroo\b", "reroute"), (r"\ballet\b", "allied"),
    (r"\bstrike crap\b", "strike craft"), (r"\bgreenland\b", "green line"),
]
FIXES = [(re.compile(p, re.I), r) for p, r in FIXES]


def fix(t):
    for p, r in FIXES:
        t = p.sub(r, t)
    return t
