#!/usr/bin/env python3
"""Harmonise les icônes d'objets (assets/icons_items/*.svg) : même épaisseur de contour (24) et petit fond encadré par catégorie
(arme brun, armure acier, consommable vert, unique or, divers parchemin sombre), dans la palette « cuir et parchemin ».
Aucune ressource externe ajoutée ; les fichiers gardent leur nom. Appelé en fin de gen_item_icons.py ; relançable seul (idempotent).

    py tools/harmonize_item_icons.py   puis   godot --headless --import
"""
import os
import re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "icons_items")
MARK = "<!--plaque-->"
OUTLINE_W = 24
PLAQUES = {  # catégorie -> (fond, liseré)
    "weapon": ("#5e4730", "#a98a5a"),
    "armor": ("#4a5258", "#93a0a8"),
    "consumable": ("#46532f", "#93a265"),
    "unique": ("#6e4e14", "#e8b93a"),
    "misc": ("#54483a", "#b7a57c"),
}


def category(name: str) -> str:
    if name == "unknown":
        return "misc"
    if "_u_" in name:
        return "unique"
    kind = name.split("_", 1)[0]
    if kind in ("weapon", "ammo"):
        return "weapon"
    if kind in ("head", "body", "arms", "legs", "shield"):
        return "armor"
    if kind in ("tool", "food"):
        return "consumable"
    return "misc"


def harmonize(name: str, svg: str) -> str:
    if MARK in svg:
        return svg
    svg = re.sub(r'(<g fill="#17100a" stroke="#17100a" stroke-width=")\d+(")', r"\g<1>%d\g<2>" % OUTLINE_W, svg)
    m = re.match(r"(<svg[^>]*>)(.*)</svg>\s*$", svg, re.S)
    if not m:
        return svg
    bg, edge = PLAQUES[category(name)]
    plaque = ('%s<rect x="14" y="14" width="484" height="484" rx="76" fill="#17100a"/>'
              '<rect x="30" y="30" width="452" height="452" rx="62" fill="%s"/>'
              '<rect x="40" y="40" width="432" height="432" rx="54" fill="none" stroke="%s" stroke-opacity="0.55" stroke-width="6"/>'
              '<path d="M60 150 Q60 60 150 60" fill="none" stroke="#fff" stroke-opacity="0.12" stroke-width="10" stroke-linecap="round"/>') % (MARK, bg, edge)
    return m.group(1) + plaque + '<g transform="translate(54 54) scale(0.79)">' + m.group(2) + "</g></svg>"


def main() -> int:
    n = 0
    for f in sorted(os.listdir(OUT)):
        if not f.endswith(".svg"):
            continue
        p = os.path.join(OUT, f)
        with open(p, encoding="utf-8") as fh:
            txt = fh.read()
        new = harmonize(f[:-4], txt)
        if new != txt:
            with open(p, "w", encoding="utf-8") as fh:
                fh.write(new)
            n += 1
    print("%d icônes harmonisées" % n)
    return n


if __name__ == "__main__":
    main()
