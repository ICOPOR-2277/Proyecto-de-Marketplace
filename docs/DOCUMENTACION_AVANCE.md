# Documento de Avance y Estado del Proyecto
## Marketplace Universitario UTB — Ingeniería de Software (2026-2)

**Integrantes:**
- Jesús Andrés Pérez Fuentes
- Juan Francisco De Ávila Alfaro
- Jorge Isaac Hincapié Pautt

**Docente:** Aisner José Marrugo Juliao  
**Semestre:** 2 / 2026  
**Repositorio GitHub:** [https://github.com/ICOPOR-2277/Proyecto-de-Marketplace](https://github.com/ICOPOR-2277/Proyecto-de-Marketplace)  
**Gestión Jira:** [Tablero Scrum Marketplace](https://jesusandresperez123456.atlassian.net/jira/software/projects/SCRUM/boards/1)

---

## 1. Descripción del Proyecto y Alcance del MVP

Plataforma tipo Marketplace orientada a la comunidad estudiantil de la **Universidad Tecnológica de Bolívar (UTB)** para publicar, buscar, adquirir y calificar productos y servicios académicos/personales (libros, apuntes, calculadoras, tutorías, componentes y transporte/rides), reemplazando los canales informales (WhatsApp, grupos de redes sociales).

### Requerimientos Funcionales y No Funcionales Implementados (MVP)
- **RF-01 (Registro e Inicio de Sesión Institucional):** Restringido a correos con dominio `@utb.edu.co` y contraseñas seguras con hash bcrypt. Mensajes comprensibles en español ante errores de validación.
- **RF-02 (Publicar Servicio / Artículo Asociado al Usuario Real):** Creación de ofertas vinculadas directamente al usuario autenticado (sin usuarios ficticios), con título, precio, categoría y subida de imágenes locales a `backend/uploads/`.
- **RF-03 & RF-07 (Moderación y Control de Publicaciones):** Panel de Moderador en tiempo real con estadísticas y acciones de bloqueo, reactivación y eliminación permanente.
- **RF-04 (Búsqueda y Filtros Flexibles):** Búsqueda por palabras clave tolerante y navegación organizada por pestañas de categorías con conteo dinámico real de artículos.
- **RF-05 (Compras con Validación de Seguridad):** Carrito de compras que exige inicio de sesión institucional obligatorio y bloquea de inmediato la compra de cualquier publicación que haya sido bloqueada por moderación.
- **RF-06 (Calificaciones y Reseñas):** Sistema de retroalimentación y puntuación (1 a 5 estrellas) con comentarios.
- **RF-08 (Chat Interactivo Bidireccional Real Comprador-Vendedor):** Sistema de mensajería instantánea en base de datos real con auto-sondeo que comunica directamente al comprador con el vendedor del artículo (mostrando su identidad real, p. ej. Moderador UTB, Estudiante UTB) para coordinar la entrega en campus Ternera.
- **RF-09 (Gestión de Publicaciones Propias y Control de Estado 'Vendido'):** Módulo "Mis Publicaciones" para que el estudiante vendedor gestione sus artículos (editar detalles, pausar oferta, reactivar, eliminar). Tras completarse una compra en el carrito, la publicación pasa automáticamente a estado `"vendida"`, impidiendo compras duplicadas y mostrando un distintivo visual en el catálogo.
- **RNF-01 (Usabilidad y Responsive):** Interfaz adaptativa en Flutter Web, solucionando desbordamientos de pantalla (*Right Overflow*) en métricas.
- **RNF-02 (Seguridad y Persistencia):** Autenticación basada en JWT (JSON Web Tokens), contraseñas hasheadas y protección de base de datos aislada contra ejecuciones de suites de pruebas.
- **RNF-03 (Integración Continua - CI/CD):** Pipeline automatizado con GitHub Actions (`.github/workflows/ci.yml`) que compila y ejecuta todas las suites de pruebas de backend y frontend en cada commit y Pull Request.

---

## 2. Arquitectura de Software Implementada

El sistema se divide limpiamente en dos componentes:

```
Proyecto-de-Marketplace/
├── backend/                  # API REST en Python / FastAPI
│   ├── app/
│   │   ├── models/           # Modelos ORM (Usuario, Publicacion, Categoria, Resena)
│   │   ├── routers/          # Endpoints (usuarios, publicaciones, listings, busqueda, moderacion, resenas)
│   │   ├── schemas/          # Validación y serialización con Pydantic
│   │   ├── database.py       # Conexión SQLAlchemy y Engine SQLite/Postgres
│   │   └── main.py           # Configuración de CORS, archivos estáticos (/uploads) y rutas
│   ├── uploads/              # Servidor local de imágenes de publicaciones
│   ├── tests/                # Pruebas automatizadas de Backend con Pytest
│   └── requirements.txt      # Dependencias del backend
│
├── frontend/                 # Aplicación Web en Flutter / Dart
│   ├── lib/
│   │   ├── constants/        # Colores institucionales oficiales UTB
│   │   ├── models/           # Modelos de datos (CurrentUser, Listing, CartItem, etc.)
│   │   ├── services/         # Consumo API REST y Estado global (Carrito / Notificaciones)
│   │   ├── screens/          # Vistas modulares (Login, Register, Dashboard, Cart, Notifications)
│   │   └── main.dart         # Punto de entrada y HomePage de navegación
│   └── test/                 # Pruebas de Frontend (Unitarias y de Widgets)
│
└── docs/                     # Documentación, diagramas de arquitectura y evidencias
    ├── DOCUMENTACION_AVANCE.md
    └── diagramas/
        └── DIAGRAMAS_SISTEMA.md  # Diagramas C4, DER, UML, Secuencia y Estados

---

## 2.1. Diagramas de Diseño y Especificación Formal
Se encuentra disponible la documentación visual completa del sistema con diagramas estándar Mermaid en [DIAGRAMAS_SISTEMA.md](file:///c:/Users/jesus/Universidad/Materias/2026-2/Ingenieria-de-software/proyecto/repositorio/Proyecto-de-Marketplace/docs/diagramas/DIAGRAMAS_SISTEMA.md):
- **Diagrama de Arquitectura y Componentes (C4 / Capas)**
- **Diagrama Entidad-Relación (DER) de Base de Datos**
- **Diagrama de Casos de Uso (UML)**
- **Diagrama de Secuencia de Autenticación JWT (@utb.edu.co)**
- **Diagrama de Secuencia de Compra Segura y Moderación**
- **Diagrama de Estados del Ciclo de Vida de Publicaciones**

---

## 3. Plan y Evidencia de Pruebas Automatizadas y CI/CD

El proyecto cuenta con suites de pruebas automatizadas para garantizar la calidad del software:

### 3.1. Pruebas de Backend (`backend/tests/`)
Ejecutadas con **Pytest** y **FastAPI TestClient**:
- `test_usuarios.py`: Verifica el registro con `@utb.edu.co` y generación de tokens JWT.
- `test_publicaciones.py`: Valida creación y consulta de publicaciones.
- `test_listings.py`: Valida parsing de precios, categorías y subida de imágenes.
- `test_busqueda.py`: Valida filtros y búsqueda por coincidencias de texto.
- `test_resenas.py`: Valida creación de puntuaciones entre usuarios.
- `test_moderacion.py`: Valida protección de rutas con token de administrador y cálculo de métricas en tiempo real.
- `test_compras_chat.py`: Valida bloqueo de compras si moderador bloqueó producto, rechazo de compras anónimas, y flujo completo de mensajería interactiva comprador-vendedor.

> **Resultado Backend:** 14 pruebas automatizadas pasadas exitosamente (100%).

### 3.2. Pruebas de Frontend (`frontend/test/`)
Ejecutadas con el framework de testing de Flutter:
- `test/unit_test.dart`: Prueba el parser de moneda colombiana en `CartItem`, operaciones del carrito (agregar, actualizar cantidad, vaciar) y ciclo de vida de notificaciones.
- `test/requirements_test.dart`: Valida requerimientos funcionales de compras (detección de bloqueos), sesión activa para compras, serialización de chat y estados de publicación (`isVendida`, `isPausada`).
- `test/widget_test.dart`: Prueba de renderizado de la estructura visual básica de UTB Market.

> **Resultado Frontend:** 8 pruebas de widgets y requerimientos pasadas exitosamente (100%).

---

## 4. Comandos de Ejecución y Pruebas

### Correr la API (Backend):
```powershell
cd backend
uvicorn app.main:app --reload --port 8000
```

### Ejecutar pruebas de Backend:
```powershell
pytest backend/tests
```

### Correr la App Web (Frontend):
```powershell
cd frontend
flutter pub get
flutter run -d chrome
```

### Ejecutar pruebas de Frontend:
```powershell
cd frontend
flutter test
```
