# Mi Reproductor (Flutter)

Reproduce audios del celular (como Poweramp) y de la nube (Firebase). Favoritos sincronizados.

## Pasos, todo desde la nube
1. **GitHub**: crear repo nuevo, subir todo este contenido (Add file > Upload files).
2. **Firebase** (console.firebase.google.com):
   - Crear proyecto. Agregar app Android con paquete `com.example.audio_player`.
   - Authentication > Sign-in method > activar **Anónimo**.
   - Firestore Database > crear (modo prueba para empezar).
   - Storage > comenzar (modo prueba para empezar).
   - Copiar apiKey, appId, senderId, projectId a `lib/firebase_options.dart`.
3. **Codemagic**: conectar el repo de GitHub, elegir `codemagic.yaml`, cambiar el correo y ejecutar el build. El APK llega por mail y queda en Artifacts.

## Reglas de seguridad sugeridas (después de probar)
Firestore:
```
rules_version = '2';
service cloud.firestore {
  match /databases/{db}/documents {
    match /tracks/{id} { allow read, write: if request.auth != null; }
    match /users/{uid}/favorites/{id} { allow read, write: if request.auth.uid == uid; }
    match /backups/{id} { allow read, write: if request.auth != null; }
  }
}
```
