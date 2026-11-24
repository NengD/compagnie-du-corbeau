#!/usr/bin/env python3
"""Fabrique les archives de publication (Windows et Linux) à partir des exports de `build/`.

Utilisé à la main et par le workflow GitHub (.github/workflows/release.yml) :
    python tools/package_release.py                    # version lue dans project.godot
    python tools/package_release.py --version 0.4.1 --build build --out build

Chaque archive contient l'exécutable, LISEZ-MOI.txt, README.md, CREDITS.md et LICENSE.
L'exécutable Linux est marqué exécutable (0755) DANS l'archive : aucun `chmod` n'est nécessaire à la décompression.
"""
import argparse
import re
import sys
import time
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

TARGETS = (
    ("windows", "CompagnieDuCorbeau.exe"),
    ("linux", "CompagnieDuCorbeau.x86_64"),
)


def project_version() -> str:
    text = (ROOT / "project.godot").read_text(encoding="utf-8")
    m = re.search(r'config/version="([^"]+)"', text)
    if not m:
        sys.exit("Version introuvable dans project.godot")
    return m.group(1)


def lisez_moi(version: str, platform: str) -> bytes:
    if platform == "windows":
        how = (
            "Windows : décompressez l'archive, puis double-cliquez sur CompagnieDuCorbeau.exe.\r\n"
            "(Si Windows SmartScreen s'affiche : « Informations complémentaires » puis « Exécuter quand même » ;\r\n"
            "le jeu n'est pas signé.)\r\n"
        )
    else:
        how = (
            "Linux (64 bits) : décompressez l'archive, puis lancez CompagnieDuCorbeau.x86_64\r\n"
            "(double-clic dans votre gestionnaire de fichiers, ou ./CompagnieDuCorbeau.x86_64 dans un terminal).\r\n"
            "Le fichier est déjà marqué exécutable dans l'archive.\r\n\r\n"
            "Si votre outil de décompression a perdu ce droit (rare), exécutez une seule fois :\r\n"
            "  chmod +x CompagnieDuCorbeau.x86_64\r\n"
        )
    text = (
        f"Compagnie du Corbeau {version}\r\n\r\n{how}\r\n"
        "Aucune installation nécessaire (Godot est intégré au fichier).\r\n"
        "Les sauvegardes sont écrites dans le dossier de données de l'utilisateur.\r\n"
        "Commandes, options et règles : menu Options et aide « ? » en jeu ; README.md décrit le projet.\r\n"
    )
    return text.encode("utf-8")


def build_zip(version: str, platform: str, exe: str, build_dir: Path, out_dir: Path) -> Path:
    exe_path = build_dir / exe
    if not exe_path.is_file():
        sys.exit(f"Export manquant : {exe_path} (lancez d'abord l'export {platform})")
    out_dir.mkdir(parents=True, exist_ok=True)
    zip_path = out_dir / f"CompagnieDuCorbeau-{version}-{platform}.zip"
    if zip_path.exists():
        zip_path.unlink()
    now = time.localtime()[:6]
    extras = (
        ("LISEZ-MOI.txt", lisez_moi(version, platform)),
        ("README.md", (ROOT / "README.md").read_bytes()),
        ("CREDITS.md", (ROOT / "assets" / "CREDITS.md").read_bytes()),
        ("LICENSE", (ROOT / "LICENSE").read_bytes()),
    )
    with zipfile.ZipFile(zip_path, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as z:
        for name, data, mode in [(exe, exe_path.read_bytes(), 0o100755)] + [(n, d, 0o100644) for n, d in extras]:
            info = zipfile.ZipInfo(name, date_time=now)
            info.compress_type = zipfile.ZIP_DEFLATED
            info.create_system = 3  # Unix : les droits sont lus à la décompression
            info.external_attr = mode << 16
            z.writestr(info, data)
    with zipfile.ZipFile(zip_path) as z:
        if z.testzip() is not None:
            sys.exit(f"Archive corrompue : {zip_path}")
    return zip_path


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--version", default=None, help="numéro de version (défaut : celui de project.godot)")
    ap.add_argument("--build", default=str(ROOT / "build"), help="dossier des exports")
    ap.add_argument("--out", default=None, help="dossier de sortie des zips (défaut : le dossier des exports)")
    args = ap.parse_args()
    version = (args.version or project_version()).lstrip("v")
    build_dir = Path(args.build)
    out_dir = Path(args.out) if args.out else build_dir
    for platform, exe in TARGETS:
        z = build_zip(version, platform, exe, build_dir, out_dir)
        print(f"{z.name} : {z.stat().st_size / 1_048_576:.1f} Mo")


if __name__ == "__main__":
    main()
