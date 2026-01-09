# Proyecto Módulo SQL — Diseño de BBDD Relacional + EDA (Modelo Estrella Extendido)

Repositorio para el proyecto del módulo SQL: **diseño, implementación y análisis exploratorio (EDA) en SQL** sobre un dataset de actividad física en gimnasio.

---

## 1) Dataset utilizado

Fuente: **Kaggle — “Gym Members Exercise Dataset”**.

Incluye registros con variables como:
- demografía / antropometría: edad, género, altura, peso, % grasa, BMI
- sesión: duración, calorías quemadas
- biometría: BPM máximo / medio / reposo
- hábitos: frecuencia semanal, agua ingerida
- contexto: tipo de entrenamiento y nivel de experiencia

> Nota: el dataset **no incluye fecha real** ni **gimnasios** por sesión.  
> Para poder hacer análisis temporal se asigna una **fecha sintética**.  
> Además se crean **10 gimnasios ficticios** con restricciones realistas de oferta de entrenamientos para poder hacer un EDA más interesante.

Referencia:
```text
https://www.kaggle.com/datasets/valakhorasani/gym-members-exercise-dataset
```

---

## 2) Alcance y decisiones de diseño

### Granularidad de la tabla de hechos
- **1 fila = 1 sesión de entrenamiento** (1 registro del CSV).

### Modelo dimensional
- 1 tabla de hechos
- 6 dimensiones
- 1 tabla puente N..N

La normalización se introduce para modelar correctamente la relación:
**Gimnasio ⇄ Tipos de entrenamiento permitidos**

### Qué queda dentro del alcance
- Integridad referencial mediante FKs
- Control de calidad del dato con constraints
- Índices analíticos
- Vistas de KPIs
- EDA reproducible en SQL

### Qué queda fuera del alcance
- Identificador natural real de miembro (el dataset no lo incluye)
- Fecha real por sesión (se usa calendario sintético)

---

## 3) Modelo de datos

### Dimensiones

#### `dim_calendario`
Calendario sintético (2025 completo):
- `fecha_iso` (PK)
- `fecha_mostrar`
- `dia`, `mes`, `anio`, `dia_semana`

#### `dim_miembro`
Perfil único por combinación de atributos:
- `genero`, `edad`, `altura_m`, `peso_kg`, `porcentaje_grasa`, `imc`
- PK surrogate: `miembro_id`
- `UNIQUE` compuesto para evitar duplicados

#### `dim_gimnasio`
Catálogo de gimnasios sintéticos:
- `nombre_gimnasio` (UNIQUE)
- `tipos_entrenamiento_ofrecidos` (campo informativo)

#### `dim_tipo_entrenamiento`
Catálogo de tipos:
- Cardio
- Strength
- HIIT
- Yoga

#### `dim_nivel_experiencia`
Niveles:
- Beginner
- Intermediate
- Advanced

#### `dim_categoria_imc`
Clasificación estándar:
- Underweight
- Normal
- Overweight
- Obese

---

### Tabla puente (normalización parcial)

#### `puente_gimnasio_tipo_entrenamiento`
Relaciona:
- `dim_gimnasio`
- `dim_tipo_entrenamiento`

Permite definir qué entrenamientos están **permitidos** en cada gimnasio.

Se utiliza para:
- Validar combinaciones en la FACT
- Evitar incoherencias de negocio
- Simular oferta realista de servicios

---

### Tabla de hechos

#### `fact_sesion_entrenamiento`
Granularidad: **1 fila = 1 sesión**

FKs:
- fecha → `dim_calendario`
- miembro → `dim_miembro`
- tipo_entrenamiento → `dim_tipo_entrenamiento`
- nivel → `dim_nivel_experiencia`
- categoría_imc → `dim_categoria_imc`

Medidas:
- duración
- calorías
- BPM (max, avg, reposo)
- agua ingerida
- frecuencia semanal

---

## 4) Oferta de entrenamientos por gimnasio (coherencia de negocio)

Regla aplicada:
- En **5 gimnasios** se ofrecen los **4 tipos**
- En los otros **5** hay restricciones:
  - Gym 6 (CostaCardio Lab): sin Yoga
  - Gym 7 (MetroStrength): sin Cardio
  - Gym 8 (Aurora HIIT Box): sin Cardio ni Yoga
  - Gym 9 (La Cúpula Wellness): sin HIIT
  - Gym 10 (Pico Alto Training): sin Strength

### Cómo se garantiza la coherencia
Durante la carga de la FACT:
- Se hace `JOIN` con `puente_gimnasio_tipo_entrenamiento`
- Se bloquean combinaciones inválidas
- Se remapean entrenamientos no permitidos

Esto resulta en que no existen sesiones con entrenamientos no ofrecidos por el gimnasio en el que se realizó.

---

## 5) Claves primarias, foráneas e índices

- Todas las tablas tienen PK
- La FACT referencia DIMs mediante FK
- Se activan FKs con `PRAGMA foreign_keys = ON`
- Se crean índices en columnas FK (joins analíticos)

Esto garantiza:
- Integridad referencial
- Rendimiento en consultas
- Calidad del dato

---

## 6) Vistas analíticas

### `vw_kpi_tipo_entrenamiento_mes`
KPIs mensuales:
- sesiones
- calorías totales y medias
- duración media
- BPM medio

### `vw_kpis_gimnasio`
KPIs por gimnasio + tipo permitido:
- sesiones
- miembros
- calorías
- rankings

### `vw_kpis_miembro`
Perfil analítico por miembro:
- sesiones
- calorías
- duración
- BPM

---

## 7) Diagrama ER
Incluido en:
```text
model.png
```
Generado con DBeaver a partir de la base de datos SQLite.

---

## 8) Ejecución del proyecto

### Requisitos
- SQLite

### Pasos
1. Crear base de datos
2. Ejecutar scripts en orden:
   1) `sql/01_schema.sql`  
   2) `sql/02_data.sql`  
   3) `sql/03_eda.sql`

---

## Autor
Carlos Checa Moreno