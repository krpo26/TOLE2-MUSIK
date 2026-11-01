"""Arregla plugins viejos sin 'namespace' (error: A problem occurred configuring project ':plugin')."""
import json, os, re, glob
from urllib.parse import unquote, urlparse

cfg = json.load(open(".dart_tool/package_config.json", encoding="utf-8"))
base = os.path.abspath(".dart_tool")
for pkg in cfg["packages"]:
    root = urlparse(pkg["rootUri"])
    path = unquote(root.path) if root.scheme == "file" else os.path.normpath(os.path.join(base, unquote(pkg["rootUri"])))
    adir = os.path.join(path, "android")
    gradle = os.path.join(adir, "build.gradle")
    manifest = os.path.join(adir, "src", "main", "AndroidManifest.xml")
    if not (os.path.exists(gradle) and os.path.exists(manifest)):
        continue
    g = open(gradle, encoding="utf-8").read()
    m = re.search(r'package="([^"]+)"', open(manifest, encoding="utf-8").read())
    changed = False
    if "namespace" not in g and m:
        g, n = re.subn(r"(\n\s*android\s*\{)", r'\1\n    namespace "%s"' % m.group(1), g, count=1)
        changed = n > 0
    g2 = re.sub(r"compileSdkVersion\s+\d+", "compileSdkVersion 35", g)
    g2 = re.sub(r"compileSdk\s*=?\s*\d+", "compileSdk 35", g2)
    if g2 != g:
        g, changed = g2, True
    if changed:
        open(gradle, "w", encoding="utf-8").write(g)
        print("Parcheado:", pkg["name"])
