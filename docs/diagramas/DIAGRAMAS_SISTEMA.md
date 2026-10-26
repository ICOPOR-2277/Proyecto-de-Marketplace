# Diagramas de Arquitectura, Diseño y Modelado del Sistema
## Marketplace Universitario UTB — Ingeniería de Software (2026-2)

Este documento contiene la especificación formal y visual del sistema mediante diagramas estándar (C4, UML, DER, Secuencia y Estados) implementados en **Mermaid**, facilitando su renderizado directo en GitHub, Visual Studio Code y herramientas de documentación.

---

## 1. Diagrama de Arquitectura y Componentes (C4 / Capas)

Muestra la separación de responsabilidades entre el cliente Flutter Web, el servidor FastAPI, el sistema de persistencia y el almacenamiento estático.

```mermaid
graph TD
    subgraph Cliente ["Cliente (Frontend Web)"]
        FW[Flutter Web - Dart]
        State[App State / ValueNotifiers / CartState]
        APIClient[ApiService - HTTP Client]
        FW --> State
        State --> APIClient
    end

    subgraph Servidor ["Servidor Backend (FastAPI / Python 3.12)"]
        CORS[CORS Middleware]
        AuthJWT[Módulo de Seguridad & JWT]
        StaticFiles[StaticFiles Mount: /uploads]
        
        subgraph Routers ["Controladores / Routers API REST"]
            R_Auth[usuarios: /usuarios]
            R_Listings[listings & publicaciones: /listings, /publicaciones]
            R_Compras[compras: /compras]
            R_Chat[chat: /chat]
            R_Mod[moderacion: /moderacion]
            R_Resenas[resenas: /resenas]
            R_Busqueda[busqueda: /busqueda]
        end
        
        ORM[SQLAlchemy ORM Engine]
    end

    subgraph Persistencia ["Capa de Datos y Archivos"]
        DB[(SQLite / PostgreSQL: marketplace.db)]
        DiskUploads[Directorio Local: backend/uploads/]
    end

    APIClient -->|HTTPS / REST JSON| CORS
    CORS --> Routers
    Routers --> AuthJWT
    Routers --> ORM
    R_Listings -->|Guarda imágenes de publicaciones| DiskUploads
    StaticFiles -->|Sirve imágenes estáticas| FW
    ORM -->|Consultas y Transacciones ACID| DB
```

---

## 2. Diagrama Entidad-Relación (DER / Modelo de Base de Datos)

Representación física y relacional de los modelos ORM de la base de datos `marketplace.db`:

```mermaid
erDiagram
    USUARIOS ||--o{ PUBLICACIONES : "publica / vende"
    USUARIOS ||--o{ COMPRAS : "compra"
    USUARIOS ||--o{ MENSAJES : "envía / recibe"
    USUARIOS ||--o{ RESENAS : "escribe / califica"
    CATEGORIAS ||--o{ PUBLICACIONES : "clasifica"
    PUBLICACIONES ||--o{ COMPRAS : "es adquirida en"
    PUBLICACIONES ||--o{ MENSAJES : "contexto de chat"

    USUARIOS {
        int id PK
        string nombre
        string correo UK "restringido @utb.edu.co"
        string password_hash "bcrypt"
        boolean es_administrador "Rol Moderador"
    }

    CATEGORIAS {
        int id PK
        string nombre UK
    }

    PUBLICACIONES {
        int id PK
        string titulo
        string descripcion
        float precio
        string estado "'activa' | 'bloqueada' | 'pausada' | 'vendida'"
        int usuario_id FK
        int categoria_id FK
        string imagen_url
    }

    COMPRAS {
        int id PK
        int comprador_id FK
        int publicacion_id FK
        int cantidad
        float precio_unitario
        float total
        datetime fecha_compra
        string estado "'completada' | 'pendiente' | 'cancelada'"
    }

    MENSAJES {
        int id PK
        int remitente_id FK
        int destinatario_id FK
        int publicacion_id FK
        string contenido
        datetime fecha_envio
        boolean leido
    }

    RESENAS {
        int id PK
        int usuario_id FK "autor de la reseña"
        int calificacion "1 a 5 estrellas"
        string comentario
    }
```

---

## 3. Diagrama de Casos de Uso (UML)

Muestra las funcionalidades disponibles según el rol del actor en la plataforma universitaria.

```mermaid
flowchart LR
    EstudianteComprador((Estudiante Comprador))
    EstudianteVendedor((Estudiante Vendedor))
    Moderador((Moderador UTB))

    subgraph Marketplace ["Plataforma Marketplace Universitario UTB"]
        UC1([Registrarse con @utb.edu.co])
        UC2([Iniciar Sesión JWT])
        UC3([Buscar y Filtrar Artículos / Servicios])
        UC4([Gestionar Carrito de Compras])
        UC5([Realizar Compra Segura])
        UC6([Chatear con el Vendedor / Comprador])
        UC7([Calificar y Dejar Reseña])
        
        UC8([Publicar Artículo o Servicio con Fotos])
        UC9([Gestionar Mis Publicaciones - Editar/Pausar/Vendido])
        
        UC10([Visualizar Métricas del Campus en Tiempo Real])
        UC11([Bloquear / Reactivar Publicaciones Infractoras])
        UC12([Eliminar Publicaciones Definitivamente])
    end

    EstudianteComprador --> UC1
    EstudianteComprador --> UC2
    EstudianteComprador --> UC3
    EstudianteComprador --> UC4
    EstudianteComprador --> UC5
    EstudianteComprador --> UC6
    EstudianteComprador --> UC7

    EstudianteVendedor --> UC1
    EstudianteVendedor --> UC2
    EstudianteVendedor --> UC8
    EstudianteVendedor --> UC9
    EstudianteVendedor --> UC6

    Moderador --> UC2
    Moderador --> UC10
    Moderador --> UC11
    Moderador --> UC12
```

---

## 4. Diagrama de Secuencia: Registro y Autenticación Segura (RF-01)

Validación estricta de correo institucional y emisión de token JWT cifrado con clave secreta:

```mermaid
sequenceDiagram
    autonumber
    actor Estudiante as Estudiante UTB
    participant Front as Frontend (Flutter Web)
    participant AuthRouter as Router /usuarios
    participant DB as Base de Datos (SQLite)

    Estudiante->>Front: Ingresa nombre, correo (@utb.edu.co) y contraseña
    Front->>AuthRouter: POST /usuarios/registro {nombre, correo, password}
    alt Correo no termina en @utb.edu.co
        AuthRouter-->>Front: HTTP 400 Bad Request ("Debe ser @utb.edu.co")
        Front-->>Estudiante: Muestra alerta en español
    else Correo ya registrado
        AuthRouter->>DB: Consultar existencia de correo
        DB-->>AuthRouter: Usuario existente
        AuthRouter-->>Front: HTTP 400 Bad Request ("El correo ya está registrado")
        Front-->>Estudiante: Notificación de error
    else Datos válidos
        AuthRouter->>AuthRouter: Hashear contraseña con bcrypt
        AuthRouter->>DB: INSERT INTO usuarios (nombre, correo, password_hash)
        DB-->>AuthRouter: Usuario creado con ID
        AuthRouter-->>Front: HTTP 201 Created
        Front-->>Estudiante: Registro exitoso, redirige a Login
    end

    Estudiante->>Front: Ingresa credenciales en Login
    Front->>AuthRouter: POST /usuarios/login {correo, password}
    AuthRouter->>DB: Buscar usuario por correo
    DB-->>AuthRouter: Registro de usuario
    AuthRouter->>AuthRouter: Verificar bcrypt(password, hash)
    AuthRouter->>AuthRouter: Generar JWT Token (sub=correo, exp=1h)
    AuthRouter-->>Front: HTTP 200 OK {access_token, token_type: bearer, user}
    Front->>Front: Almacena sesión activa en estado global
    Front-->>Estudiante: Acceso concedido al Marketplace
```

---

## 5. Diagrama de Secuencia: Compra Segura y Validación de Moderación (RF-05 & RF-08)

Proceso que garantiza que artículos bloqueados por moderación no sean adquiridos, registra la transacción y abre la coordinación en el chat:

```mermaid
sequenceDiagram
    autonumber
    actor Comprador as Estudiante Comprador
    participant Front as Frontend (Flutter Web)
    participant ComprasRouter as Router /compras
    participant DB as Base de Datos (SQLite)
    actor Vendedor as Estudiante Vendedor

    Comprador->>Front: Presiona "Pagar / Finalizar Pedido" desde Carrito
    Front->>ComprasRouter: POST /compras/ con items [{publicacion_id, cantidad}] + Header Authorization Bearer
    ComprasRouter->>ComprasRouter: Validar token JWT (identifica comprador)
    
    loop Por cada artículo del carrito
        ComprasRouter->>DB: Consultar estado de publicacion_id
        DB-->>ComprasRouter: Registro (estado: 'activa' | 'bloqueada' | 'vendida')
        alt Estado == 'bloqueada' o 'vendida'
            ComprasRouter-->>Front: HTTP 400 Bad Request ("Artículo no disponible")
            Front-->>Comprador: Alerta: El artículo no está disponible para compra
        end
    end

    ComprasRouter->>DB: INSERT INTO compras (comprador_id, publicacion_id, total, estado='completada')
    ComprasRouter->>DB: UPDATE publicaciones SET estado='vendida' WHERE id = publicacion_id
    ComprasRouter->>DB: INSERT INTO mensajes (remitente_id, destinatario_id, contenido="Coordinemos entrega...")
    DB-->>ComprasRouter: Transacción confirmada
    ComprasRouter-->>Front: HTTP 201 Created (Detalle de la compra)
    Front-->>Comprador: Diálogo de éxito con resumen de compra
    Front->>Front: Limpiar carrito de compras
    Vendedor->>Front: Recibe mensaje automático de compra en el chat
```

---

## 6. Diagrama de Estados: Ciclo de Vida de una Publicación

```mermaid
stateDiagram-v2
    [*] --> Activa : Estudiante publica artículo/servicio
    
    Activa --> Vendida : Estudiante adquiere el artículo
    Activa --> Pausada : Vendedor pausa temporalmente la oferta
    Pausada --> Activa : Vendedor reactiva su publicación
    
    Activa --> Bloqueada : Moderador detecta infracción
    Bloqueada --> Activa : Moderador aprueba tras revisión
    
    Activa --> Eliminada : Vendedor o Moderador elimina definitivamente
    Bloqueada --> Eliminada : Moderador elimina permanentemente
    Pausada --> Eliminada : Vendedor elimina su publicación
    Vendida --> Eliminada : Vendedor elimina historial
    
    Eliminada --> [*]
```
