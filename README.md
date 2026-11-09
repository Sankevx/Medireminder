# MediReminder — código base

## Backend (Node + Express + MySQL)
### Con Docker (recomendado)
1. Abrir Docker Desktop.
2. Desde la carpeta `MediReminder`, ejecutar: `docker compose up --build -d`.
3. Verificar: `docker compose ps` y `http://localhost:3000`.
4. Sin SMTP configurado (modo desarrollo), solicita recuperación y consulta el código con `docker compose logs -f api`.
5. Para recibir códigos por Gmail:
   - Activa la verificación en dos pasos de la cuenta Google y crea una contraseña de aplicación en la seguridad de tu cuenta.
   - En `backend/.env`, configura `SMTP_HOST=smtp.gmail.com`, `SMTP_PORT=587`, `SMTP_SECURE=false`, `SMTP_USER` con tu dirección Gmail, `SMTP_PASS` con la contraseña de aplicación y `SMTP_FROM` con la misma dirección.
   - No uses la contraseña normal de Gmail ni compartas la contraseña de aplicación en el chat o en el repositorio. `backend/.env` es local.
   - Desde la carpeta `MediReminder`, aplica la configuración con `docker compose up --build -d api` y revisa el arranque con `docker compose logs --tail=50 api`.
6. Para otro proveedor, reemplaza el host, puerto, modo seguro y credenciales con los datos SMTP oficiales de ese proveedor. En producción define además `NODE_ENV=production`; el backend no arrancará sin SMTP válido.
7. El código vence en 10 minutos y se bloquea después de 5 intentos incorrectos. Al iniciar, el backend agrega automáticamente la columna necesaria si la base existente aún no la tiene.

### Sin Docker
1. Crear BD: `mysql -u root -p < backend/schema.sql`
2. `cd backend && cp .env.example .env` (editar credenciales y JWT_SECRET) → `npm install && npm start`

## App (Flutter)
1. `cd app && flutter create . --project-name medireminder` (genera android/ios sin tocar lib/) → `flutter pub get`
2. Emulador Android: la API ya apunta a `http://10.0.2.2:3000/api` (cambiar en `lib/api.dart` para dispositivo físico).
3. `flutter run`
4. Al iniciar sesión, permite las notificaciones para recibir avisos locales de dosis. Los próximos 30 días se programan en el dispositivo; Android puede limitar la precisión si no se concede el acceso especial de alarmas.

## Pendiente
FCM, Google Sign-In, LLM real en el asistente, pruebas Postman, repetir aviso a los 10 min.
