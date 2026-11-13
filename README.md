# TOLE2 (Flutter)

Reproductor de audio del celular y de la nube (Firebase), estilo Poweramp, con modo Winamp y DJ virtual.

## Pasos, todo desde la nube
1. **GitHub**: subir todo este contenido (Add file > Upload files).
2. **Firebase** (console.firebase.google.com):
   - Crear proyecto. Agregar app Android con paquete `com.example.audio_player`.
   - Authentication > Sign-in method > activar **Anónimo**.
   - Firestore Database y Storage (modo prueba para empezar).
   - Copiar apiKey, appId, senderId, projectId a `lib/firebase_options.dart`.
3. **Codemagic**: conectar el repo, usar `codemagic.yaml`, cambiar el correo y ejecutar el build.

## Reglas sugeridas de Firestore
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
