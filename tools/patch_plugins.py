"""Arregla plugins Android viejos: falta de 'namespace' y JVM target inconsistente Java/Kotlin."""
import json, os, re
from urllib.parse import unquote, urlparse

JVM = "17"
cfg = json.load(open(".dart_tool/package_config.json", encoding="utf-8"))
base = os.path.abspath(".dart_tool")

for pkg in cfg["packages"]:
    root = urlparse(pkg["rootUri"])
    path = unquote(root.path) if root.scheme == "file" else os.path.normpath(
        os.path.join(base, unquote(pkg["rootUri"])))
    adir = os.path.join(path, "android")
    gradle = os.path.join(adir, "build.gradle")
    manifest = os.path.join(adir, "src", "main", "AndroidManifest.xml")
    if not (os.path.exists(gradle) and os.path.exists(manifest)):
        continue
    g = orig = open(gradle, encoding="utf-8").read()
    m = re.search(r'package="([^"]+)"', open(manifest, encoding="utf-8").read())
    old_plugin = "namespace" not in g  # plugin viejo, sin soporte de AGP 8

    if old_plugin and m:
        g = re.sub(r"(\n\s*android\s*\{)", r'\1\n    namespace "%s"' % m.group(1), g, count=1)

    # SDK
    g = re.sub(r"compileSdkVersion\s+\d+", "compileSdkVersion 35", g)
    g = re.sub(r"compileSdk\s*=?\s*\d+", "compileSdk 35", g)

    if old_plugin:
        # Java y Kotlin al mismo JVM target
        g = re.sub(r"JavaVersion\.VERSION_[\d_]+", "JavaVersion.VERSION_%s" % JVM, g)
        g = re.sub(r"jvmTarget\s*=?\s*['\"][\d.]+['\"]", "jvmTarget = '%s'" % JVM, g)
        if "compileOptions" not in g:
            g = re.sub(r"(\n\s*android\s*\{)", r"\1\n    compileOptions {\n"
                       r"        sourceCompatibility JavaVersion.VERSION_%s\n"
                       r"        targetCompatibility JavaVersion.VERSION_%s\n    }" % (JVM, JVM), g, count=1)
        if "kotlinOptions" not in g and "kotlin" in g:
            g = re.sub(r"(\n\s*android\s*\{)", r"\1\n    kotlinOptions {\n"
                       r"        jvmTarget = '%s'\n    }" % JVM, g, count=1)

    if g != orig:
        open(gradle, "w", encoding="utf-8").write(g)
        print("Parcheado:", pkg["name"])
