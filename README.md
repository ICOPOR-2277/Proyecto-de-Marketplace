# Marketplace de Servicios entre Estudiantes (UTB)

Proyecto de aula de la asignatura **Ingeniería de Software** — Universidad Tecnológica de Bolívar (2026-2).

## Integrantes
- Jorge Isaac Hincapié Pautt
- Juan Francisco De Ávila Alfaro
- Jesús Andrés Pérez Fuentes

**Docente:** Aisner José Marrugo Juliao

---

## Descripción del Proyecto
Plataforma web tipo Marketplace que permite a los estudiantes de la UTB publicar, buscar, contactar y calificar productos y servicios (tutorías, venta de apuntes, libros, electrónica, transporte/rides, entre otros), centralizando de manera segura y confiable lo que actualmente se gestiona de manera informal por grupos de WhatsApp.

---

## Tecnologías Utilizadas
- **Backend:** FastAPI (Python 3.12) + SQLAlchemy + SQLite / PostgreSQL
- **Frontend:** Flutter Web (Dart) con diseño institucional UTB
- **Almacenamiento Estático:** Directorio de uploads servido por FastAPI
- **Seguridad:** Autenticación JWT + encriptación de contraseñas con Bcrypt
- **Pruebas:** Pytest (Backend) y Flutter Test (Frontend)
- **Gestión Ágil:** Jira (Scrum) y GitHub

---

## Estructura del Repositorio
```text
├── backend/
│   ├── app/                 # Código fuente de la API (routers, models, schemas, config)
│   ├── uploads/             # Directorio estático para imágenes de publicaciones
│   ├── tests/               # Pruebas automatizadas (pytest)
│   └── requirements.txt     # Dependencias de Python
│
├── frontend/
│   ├── lib/
│   │   ├── constants/       # Colores institucionales oficiales UTB
│   │   ├── models/          # Modelos de datos (CurrentUser, Listing, CartItem, etc.)
│   │   ├── services/        # Cliente API HTTP y estado global (Carrito / Notificaciones)
│   │   ├── screens/         # Vistas modulares (Login, Register, Dashboard, Cart, etc.)
│   │   └── main.dart        # Entrypoint y Home principal
│   └── test/                # Pruebas unitarias y de widgets en Flutter
│
└── docs/                    # Documentación formal, diagramas y evidencias de avance
    └── DOCUMENTACION_AVANCE.md
```

---

## Cómo Ejecutar el Proyecto

### 1. Backend (API FastAPI)
```powershell
cd backend
pip install -r requirements.txt
uvicorn app.main:app --reload --port 8000
```
- API activa en: `http://127.0.0.1:8000`
- Documentación interactiva Swagger: `http://127.0.0.1:8000/docs`

### 2. Frontend (Flutter Web)
```powershell
cd frontend
flutter pub get
flutter run -d chrome
```

---

## Cómo Ejecutar las Pruebas Automatizadas

### Pruebas de Backend (Pytest):
```powershell
pytest backend/tests
```

### Pruebas de Frontend (Flutter Test):
```powershell
cd frontend
flutter test
```

---

## Gestión del Proyecto
- **Tablero Jira:** [https://jesusandresperez123456.atlassian.net/jira/software/projects/SCRUM/boards/1](https://jesusandresperez123456.atlassian.net/jira/software/projects/SCRUM/boards/1)
- **Repositorio GitHub:** [https://github.com/ICOPOR-2277/Proyecto-de-Marketplace](https://github.com/ICOPOR-2277/Proyecto-de-Marketplace)
