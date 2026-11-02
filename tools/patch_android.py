"""Ajusta el proyecto Android generado por `flutter create` (idempotente)."""
import glob, re

# 1) Manifest: permisos + servicio de audio en segundo plano
mf = "android/app/src/main/AndroidManifest.xml"
s = open(mf, encoding="utf-8").read()
if "READ_MEDIA_AUDIO" not in s:
    perms = """    <uses-permission android:name="android.permission.INTERNET"/>
    <uses-permission android:name="android.permission.READ_MEDIA_AUDIO"/>
    <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" android:maxSdkVersion="32"/>
    <uses-permission android:name="android.permission.WAKE_LOCK"/>
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK"/>
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
"""
    s = s.replace("<application", perms + "    <application", 1)
    svc = """        <service android:name="com.ryanheise.audioservice.AudioService"
            android:foregroundServiceType="mediaPlayback"
            android:exported="true" tools:ignore="Instantiatable">
            <intent-filter>
                <action android:name="android.media.browse.MediaBrowserService"/>
            </intent-filter>
        </service>
        <receiver android:name="com.ryanheise.audioservice.MediaButtonReceiver"
            android:exported="true" tools:ignore="Instantiatable">
            <intent-filter>
                <action android:name="android.intent.action.MEDIA_BUTTON"/>
            </intent-filter>
        </receiver>
    </application>"""
    s = s.replace("</application>", svc, 1)
    if "xmlns:tools" not in s:
        s = s.replace("<manifest ", '<manifest xmlns:tools="http://schemas.android.com/tools" ', 1)
    s = re.sub(r'android:label="[^"]*"', 'android:label="TOLE2"', s, count=1)
    open(mf, "w", encoding="utf-8").write(s)

# 2) MainActivity -> AudioServiceActivity
for f in glob.glob("android/app/src/main/**/MainActivity.*", recursive=True):
    t = open(f, encoding="utf-8").read()
    if "AudioServiceActivity" not in t:
        t = t.replace("import io.flutter.embedding.android.FlutterActivity",
                      "import com.ryanheise.audioservice.AudioServiceActivity")
        t = t.replace("FlutterActivity()", "AudioServiceActivity()")
        open(f, "w", encoding="utf-8").write(t)

# 3) minSdk 24 (requerido por Firebase)
for f in glob.glob("android/app/build.gradle*"):
    t = open(f, encoding="utf-8").read()
    kts = f.endswith(".kts")
    t = re.sub(r"minSdk(Version)?\s*=?\s*flutter\.minSdkVersion",
               "minSdk = 24" if kts else "minSdkVersion 24", t)
    open(f, "w", encoding="utf-8").write(t)
# 4) Ícono de la app (TOLE2) y nombre aunque el manifest ya tuviera permisos
import shutil, os
s2 = open(mf, encoding="utf-8").read()
s2 = re.sub(r'android:label="[^"]*"', 'android:label="TOLE2"', s2, count=1)
open(mf, "w", encoding="utf-8").write(s2)
for d in glob.glob("tools/icons/mipmap-*"):
    dst = os.path.join("android/app/src/main/res", os.path.basename(d))
    os.makedirs(dst, exist_ok=True)
    shutil.copy(os.path.join(d, "ic_launcher.png"), os.path.join(dst, "ic_launcher.png"))
for f in glob.glob("android/app/src/main/res/mipmap-anydpi*/ic_launcher*.xml"):
    os.remove(f)
print("Android parcheado")
