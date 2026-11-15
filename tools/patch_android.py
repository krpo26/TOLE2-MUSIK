"""Ajusta el proyecto Android generado por `flutter create` (idempotente y verificado).
Si falta algo imprescindible para la notificación / segundo plano, el paso FALLA a propósito."""
import glob, os, re, shutil, sys

MF = "android/app/src/main/AndroidManifest.xml"
s = open(MF, encoding="utf-8").read()

# --- xmlns:tools ---
if "xmlns:tools" not in s:
    s = s.replace("<manifest ", '<manifest xmlns:tools="http://schemas.android.com/tools" ', 1)

# --- permisos (cada uno por separado) ---
PERMS = [
    "android.permission.INTERNET",
    "android.permission.READ_MEDIA_AUDIO",
    "android.permission.WAKE_LOCK",
    "android.permission.FOREGROUND_SERVICE",
    "android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK",
    "android.permission.POST_NOTIFICATIONS",
    "android.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS",
]
lines = ""
for p in PERMS:
    if f'"{p}"' not in s:
        lines += f'    <uses-permission android:name="{p}"/>\n'
if "android.permission.READ_EXTERNAL_STORAGE" not in s:
    lines += ('    <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" '
              'android:maxSdkVersion="32"/>\n')
if lines:
    s = s.replace("<application", lines + "    <application", 1)

# --- servicio y receiver de audio_service (notificación con controles) ---
SERVICE = """        <service android:name="com.ryanheise.audioservice.AudioService"
            android:foregroundServiceType="mediaPlayback"
            android:exported="true" tools:ignore="Instantiatable">
            <intent-filter>
                <action android:name="android.media.browse.MediaBrowserService"/>
            </intent-filter>
        </service>
"""
RECEIVER = """        <receiver android:name="com.ryanheise.audioservice.MediaButtonReceiver"
            android:exported="true" tools:ignore="Instantiatable">
            <intent-filter>
                <action android:name="android.intent.action.MEDIA_BUTTON"/>
            </intent-filter>
        </receiver>
"""
add = ""
if "com.ryanheise.audioservice.AudioService" not in s:
    add += SERVICE
if "com.ryanheise.audioservice.MediaButtonReceiver" not in s:
    add += RECEIVER
if add:
    s = s.replace("</application>", add + "    </application>", 1)

# --- nombre de la app ---
s = re.sub(r'android:label="[^"]*"', 'android:label="TOLE2"', s, count=1)
open(MF, "w", encoding="utf-8").write(s)

# --- MainActivity: se reescribe completa como AudioServiceActivity ---
found = glob.glob("android/app/src/main/**/MainActivity.*", recursive=True)
if not found:
    print("ERROR: no se encontró MainActivity")
    sys.exit(1)
for f in found:
    t = open(f, encoding="utf-8").read()
    m = re.search(r"^\s*package\s+([\w.]+)", t, re.M)
    pkg = m.group(1) if m else "com.example.audio_player"
    if f.endswith(".kt"):
        new = (f"package {pkg}\n\n"
               "import com.ryanheise.audioservice.AudioServiceActivity\n\n"
               "class MainActivity : AudioServiceActivity()\n")
    else:
        new = (f"package {pkg};\n\n"
               "import com.ryanheise.audioservice.AudioServiceActivity;\n\n"
               "public class MainActivity extends AudioServiceActivity {\n}\n")
    open(f, "w", encoding="utf-8").write(new)
    print("MainActivity reescrita:", f)

# --- minSdk 24 (requerido por Firebase) ---
for f in glob.glob("android/app/build.gradle*"):
    t = open(f, encoding="utf-8").read()
    kts = f.endswith(".kts")
    t = re.sub(r"minSdk(Version)?\s*=?\s*flutter\.minSdkVersion",
               "minSdk = 24" if kts else "minSdkVersion 24", t)
    open(f, "w", encoding="utf-8").write(t)

# --- ícono pequeño (monocromo) para la barra de notificaciones ---
os.makedirs("android/app/src/main/res/drawable", exist_ok=True)
open("android/app/src/main/res/drawable/ic_stat_tole2.xml", "w", encoding="utf-8").write(
    '<vector xmlns:android="http://schemas.android.com/apk/res/android"\n'
    '    android:width="24dp" android:height="24dp"\n'
    '    android:viewportWidth="24" android:viewportHeight="24">\n'
    '    <path android:fillColor="#FFFFFFFF"\n'
    '        android:pathData="M12,3v10.55c-0.59,-0.34 -1.27,-0.55 -2,-0.55 -2.21,0 -4,1.79 -4,4s1.79,4 4,4 4,-1.79 4,-4V7h4V3h-6z"/>\n'
    '</vector>\n')

# --- ícono de la app ---
for d in glob.glob("tools/icons/mipmap-*"):
    dst = os.path.join("android/app/src/main/res", os.path.basename(d))
    os.makedirs(dst, exist_ok=True)
    shutil.copy(os.path.join(d, "ic_launcher.png"), os.path.join(dst, "ic_launcher.png"))
for f in glob.glob("android/app/src/main/res/mipmap-anydpi*/ic_launcher*.xml"):
    os.remove(f)

# --- verificación final (el log de Codemagic muestra el manifest resultante) ---
final = open(MF, encoding="utf-8").read()
need = ["com.ryanheise.audioservice.AudioService",
        "com.ryanheise.audioservice.MediaButtonReceiver",
        "FOREGROUND_SERVICE_MEDIA_PLAYBACK", "POST_NOTIFICATIONS"]
missing = [n for n in need if n not in final]
print("----- AndroidManifest.xml final -----")
print(final)
if missing:
    print("ERROR: falta en el manifest:", missing)
    sys.exit(1)
print("Android parcheado y verificado")
