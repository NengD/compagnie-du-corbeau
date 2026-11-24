"""Dessine les icônes des consommables (onguents, potions, fiole de venin) : assets/icons_items/tool_<clé>.svg.
Œuvre originale (formes simples, contour sombre épais comme les icônes existantes) : aucune source externe.
Usage : py tools/gen_consumable_icons.py   puis   godot --headless --import
"""
import os

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "icons_items")
OL = "#17100a"


def svg(body: str) -> str:
    return ('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512">'
            f'<g stroke="{OL}" stroke-width="22" stroke-linejoin="round" stroke-linecap="round">{body}</g></svg>')


def flask(liquid: str, glass: str = "#d9cfae", neck: bool = True, extra: str = "") -> str:
    return (f'<path d="M210 70h92v70l86 170c18 36-8 82-50 82H174c-42 0-68-46-50-82l86-170z" fill="{glass}"/>'
            f'<path d="M158 330h196l18 20c14 30-6 62-40 62H180c-34 0-54-32-40-62z" fill="{liquid}"/>'
            f'<rect x="198" y="48" width="116" height="40" rx="10" fill="#8a5a2b"/>' + extra)


ICONS = {
    "bandage": svg(
        '<rect x="100" y="190" width="312" height="132" rx="20" fill="#e8e0c8"/>'
        '<path d="M170 190v132M256 190v132M342 190v132" fill="none" stroke="#b9ab86" stroke-width="14"/>'
        '<path d="M236 236h40M256 216v40" fill="none" stroke="#b03a2e" stroke-width="22"/>'
        '<rect x="100" y="190" width="312" height="132" rx="20" fill="none"/>'),
    "antidote": svg(flask("#6fa84a") + '<path d="M256 200v90M211 245h90" fill="none" stroke="#f3e6c0" stroke-width="20"/>'),
    "onguent": svg(
        '<ellipse cx="256" cy="340" rx="150" ry="62" fill="#a46a34"/>'
        '<path d="M106 340v-70c0-34 68-62 150-62s150 28 150 62v70" fill="#a46a34"/>'
        '<ellipse cx="256" cy="270" rx="150" ry="58" fill="#e08b2e"/>'
        '<ellipse cx="256" cy="262" rx="92" ry="30" fill="#f4c25a" stroke-width="14"/>'
        '<path d="M256 140c28 36 38 52 38 72a38 38 0 0 1-76 0c0-20 10-36 38-72z" fill="#e8892b"/>'),
    "tonique": svg(flask("#d6a437") + '<path d="M236 140h40M256 120v40" fill="none" stroke="#f6e7a4" stroke-width="16"/>'
                   '<path d="M226 276l30 40 30-40z" fill="#f6e7a4" stroke-width="12"/>'),
    "fiole_courage": svg(flask("#c0392b") +
                         '<path d="M256 205l26 52 58 8-42 40 10 58-52-28-52 28 10-58-42-40 58-8z" fill="#f3d27a" stroke-width="14"/>'),
    "venin": svg(flask("#4e8a2e", glass="#cfd8b6") +
                 '<path d="M256 200c-40 0-64 30-64 62 0 20 12 34 28 40v28h72v-28c16-6 28-20 28-40 0-32-24-62-64-62z" fill="#e8e6cf" stroke-width="12"/>'
                 '<circle cx="232" cy="262" r="12" fill="#17100a"/><circle cx="280" cy="262" r="12" fill="#17100a"/>'),
}

for key, body in ICONS.items():
    path = os.path.join(OUT, f"tool_{key}.svg")
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write(body)
    print("écrit", path)
