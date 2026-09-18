# Marketplace de Servicios entre Estudiantes (UTB)

Proyecto de aula de la asignatura Ingeniería de Software — Universidad Tecnológica de Bolívar.

## Integrantes
- Jorge Isaac Hincapié Pautt
- Juan Francisco De Ávila Alfaro
- Jesús Andrés Pérez Fuentes

## Descripción
Plataforma tipo marketplace que permite a los estudiantes publicar, buscar, contactar y calificar
servicios ofrecidos por otros estudiantes (tutorías, venta de apuntes, diseño, entre otros),
centralizando lo que hoy se gestiona informalmente por grupos de WhatsApp.

## Tecnologías
- Backend: FastAPI (Python)
- Frontend: Flutter Web
- Base de datos: PostgreSQL / SQLite

## Estructura del repositorio
- `backend/` — API REST en FastAPI
- `frontend/` — Aplicación en Flutter Web
- `docs/` — Documento del proyecto de aula, diagramas y evidencias

## Cómo correr el proyecto

### Backend
```bash
cd backend
python -m venv venv
source venv/bin/activate
pip install -r requirements.txt
uvicorn app.main:app --reload
```

### Frontend
```bash
cd frontend
flutter pub get
flutter run -d chrome
```

## Gestión del proyecto
- Tablero Jira: [enlace al tablero]
- Metodología: Scrum (sprints de 1-2 semanas)
