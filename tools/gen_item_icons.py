"""Génère assets/icons_items/*.svg : un jeu d'icônes cohérent pour tous les objets (contour sombre, dégradé or/parchemin).

Sources : assets/icons/*.svg (formes game-icons.net CC BY 3.0, voir assets/CREDITS.md) et tools/icon_src/*.svg
(game-icons.net, CC BY 3.0, brutes). L'icône « ? » et l'ornement des uniques sont dessinés ici.
Usage : py tools/gen_item_icons.py   puis   godot --headless --import
Nommage : <genre>_<clé>.svg (weapon_hache, head_casque, body_mailles, shield_bouclier, tool_pierre, food_pain, ...),
plus unknown.svg. Les uniques portent leur propre clé (weapon_u_epee_corbeau) et sont ornementés.
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OLD = os.path.join(ROOT, "assets", "icons")
SRC = os.path.join(ROOT, "tools", "icon_src")
OUT = os.path.join(ROOT, "assets", "icons_items")

# (genre, clé) -> source ; "old:<fichier>" = assets/icons/<fichier>.svg ; "src:<fichier>" = tools/icon_src/<fichier>.svg
ORDINARY = {
    ("weapon", "gourdin"): "old:gourdin", ("weapon", "fourche"): "old:fourche", ("weapon", "lance"): "old:lance",
    ("weapon", "hache"): "old:hache", ("weapon", "masse"): "old:masse", ("weapon", "epee"): "old:epee",
    ("weapon", "arc"): "old:arc", ("weapon", "arbalete"): "old:arbalete", ("weapon", "hallebarde"): "old:hallebarde",
    ("weapon", "fleau"): "old:fleau", ("weapon", "javelot"): "old:javelot", ("weapon", "griffes"): "old:griffes",
    ("weapon", "poings"): "old:poings", ("weapon", "griffesL"): "old:griffesL", ("weapon", "morsure"): "old:morsure",
    ("weapon", "massue_geant"): "old:massue_geant",
    ("head", "capuchon"): "old:capuchon", ("head", "casque"): "old:casque", ("head", "heaume"): "old:heaume",
    ("body", "tunique"): "old:tunique", ("body", "gambison"): "old:gambison", ("body", "mailles"): "old:mailles",
    ("body", "brigandine"): "old:brigandine",
    ("shield", ""): "old:bouclier",
    ("tool", "pierre"): "src:delapouite__stone-pile", ("tool", "huile"): "src:lorc__fire-bottle",
    ("tool", "filet"): "src:lorc__fishing-net",
    ("food", "pain"): "src:delapouite__bread", ("food", "viande"): "src:delapouite__steak",
    ("food", "fromage"): "src:lorc__cheese-wedge", ("food", "ration"): "src:lorc__knapsack",
}
# uniques : (genre, clé unique) -> (genre, clé ordinaire dont on emprunte la forme)
UNIQUES = {
    ("weapon", "u_epee_corbeau"): "epee", ("weapon", "u_hache_fendcrane"): "hache", ("weapon", "u_lance_aigle"): "lance",
    ("weapon", "u_masse_glas"): "masse", ("weapon", "u_arc_ronce"): "arc",
    ("head", "u_casque_loup"): "casque", ("head", "u_heaume_veilleur"): "heaume",
    ("body", "u_cotte_nuit"): "mailles", ("body", "u_brigandine_roi"): "brigandine",
}

DEFS = ('<defs><linearGradient id="g" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="%s"/>'
        '<stop offset="1" stop-color="%s"/></linearGradient></defs>')


def paths_of(spec: str) -> list:
    kind, name = spec.split(":")
    folder = OLD if kind == "old" else SRC
    with open(os.path.join(folder, name + ".svg"), encoding="utf-8") as f:
        txt = f.read()
    ds = re.findall(r'<path[^>]*?\sd="([^"]+)"', txt)
    if kind == "src":  # game-icons : le premier tracé est le fond noir
        ds = [d for d in ds if not d.startswith("M0 0h512v512H0z")]
    if not ds:
        raise RuntimeError("aucun tracé dans " + spec)
    return ds


def wrap(body_paths: list, top: str, bottom: str, outline: str = "#17100a", ow: int = 24, extra_under: str = "",
         extra_over: str = "") -> str:
    ps = "".join('<path d="%s"/>' % d for d in body_paths)
    return ('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512">' + DEFS % (top, bottom) + extra_under +
            '<g fill="%s" stroke="%s" stroke-width="%d" stroke-linejoin="round" stroke-linecap="round">%s</g>' % (outline, outline, ow, ps) +
            '<g fill="url(#g)">%s</g>' % ps + extra_over + '</svg>')


def sparkle(cx: int, cy: int, r: int, color: str) -> str:
    k = r * 0.22
    return ('<path fill="%s" stroke="#17100a" stroke-width="6" stroke-linejoin="round" d="M%d %dL%.1f %.1fL%d %dL%.1f %.1fL%d %dL%.1f %.1fL%d %dL%.1f %.1fZ"/>'
            % (color, cx, cy - r, cx + k, cy - k, cx + r, cy, cx + k, cy + k, cx, cy + r, cx - k, cy + k, cx - r, cy, cx - k, cy - k))


def unknown() -> str:
    q = ('<path d="M186 196C186 130 226 100 262 100C304 100 336 130 336 176C336 220 304 236 280 256C264 270 258 282 258 308" '
         'fill="none" stroke="%s" stroke-width="%d" stroke-linecap="round" stroke-linejoin="round"/>')
    dot = '<circle cx="258" cy="388" r="%d" fill="%s"%s/>'
    return ('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512">' + q % ("#17100a", 78) + dot % (40, "#17100a", ' stroke="#17100a" stroke-width="24"') +
            q % ("#b7a57c", 44) + dot % (30, "#b7a57c", "") + '</svg>')


def main() -> int:
    os.makedirs(OUT, exist_ok=True)
    for f in os.listdir(OUT):
        if f.endswith(".svg"):
            os.remove(os.path.join(OUT, f))
    n = 0
    for (genre, key), spec in ORDINARY.items():
        name = "%s_%s" % (genre, key) if key else genre + "_bouclier"
        svg = wrap(paths_of(spec), "#f3e2ad", "#c8a24c")
        if genre == "food":
            svg = wrap(paths_of(spec), "#f4dca0", "#d09a48")
        with open(os.path.join(OUT, name + ".svg"), "w", encoding="utf-8") as f:
            f.write(svg)
        n += 1
    for (genre, key), base in UNIQUES.items():
        ds = paths_of("old:" + base)
        halo = '<g fill="none" stroke="#e8b93a" stroke-opacity="0.5" stroke-width="64" stroke-linejoin="round">%s</g>' % "".join('<path d="%s"/>' % d for d in ds)
        stars = sparkle(426, 90, 72, "#fff0b8") + sparkle(86, 426, 44, "#ffe08a")
        svg = wrap(ds, "#fff3bd", "#dc9d1e", outline="#2a1a05", ow=26, extra_under=halo, extra_over=stars)
        with open(os.path.join(OUT, "%s_%s.svg" % (genre, key)), "w", encoding="utf-8") as f:
            f.write(svg)
        n += 1
    with open(os.path.join(OUT, "unknown.svg"), "w", encoding="utf-8") as f:
        f.write(unknown())
    print("%d icônes + unknown.svg écrits dans %s" % (n, OUT))
    return 0


if __name__ == "__main__":
    sys.exit(main())
