PRAGMA foreign_keys = ON;

/*═══════════════════════════════════════════════════════════════════
LIMPIEZA
═══════════════════════════════════════════════════════════════════*/

DROP VIEW  IF EXISTS vw_kpis_gimnasio;
DROP VIEW  IF EXISTS vw_kpis_miembro;
DROP VIEW  IF EXISTS vw_kpi_tipo_entrenamiento_mes;

DROP TABLE IF EXISTS fact_sesion_entrenamiento;
DROP TABLE IF EXISTS dim_calendario;
DROP TABLE IF EXISTS dim_categoria_imc;
DROP TABLE IF EXISTS dim_nivel_experiencia;
DROP TABLE IF EXISTS puente_gimnasio_tipo_entrenamiento;
DROP TABLE IF EXISTS dim_tipo_entrenamiento;
DROP TABLE IF EXISTS dim_miembro;
DROP TABLE IF EXISTS dim_gimnasio;

/*═══════════════════════════════════════════════════════════════════
DIMENSIONES
═══════════════════════════════════════════════════════════════════*/

-- DIM_GYM: catálogo de gimnasios. Sintético conseguir una bbdd más interesante.
CREATE TABLE IF NOT EXISTS dim_gimnasio (
  gimnasio_id               INTEGER PRIMARY KEY,
  nombre_gimnasio             TEXT NOT NULL UNIQUE,
  tipos_entrenamiento_ofrecidos TEXT NOT NULL -- Lista de tipos pertenecientes a dim_tipo_entrenamiento
);

-- DIM_WORKOUT_TYPE: catálogo de tipos de entrenamiento.
CREATE TABLE IF NOT EXISTS dim_tipo_entrenamiento (
  tipo_entrenamiento_id   INTEGER PRIMARY KEY,
  nombre_tipo_entrenamiento TEXT NOT NULL UNIQUE
);

-- BRIDGE_GYM_WORKOUT_TYPE: relación N..N gimnasio con tipo de entrenamiento permitido.
CREATE TABLE IF NOT EXISTS puente_gimnasio_tipo_entrenamiento (
  gimnasio_id          INTEGER NOT NULL,
  tipo_entrenamiento_id INTEGER NOT NULL,
  PRIMARY KEY (gimnasio_id, tipo_entrenamiento_id), -- Tenemos un PK compuesto, el par de cada gimnasio-tipo debe ser único.
  FOREIGN KEY (gimnasio_id)          REFERENCES dim_gimnasio(gimnasio_id),
  FOREIGN KEY (tipo_entrenamiento_id) REFERENCES dim_tipo_entrenamiento(tipo_entrenamiento_id)
);

-- DIM_MEMBER: atributos del “miembro” (en este dataset no existe miembro_id real, usamos una PK inventada).
CREATE TABLE IF NOT EXISTS dim_miembro (
  miembro_id      INTEGER PRIMARY KEY,
  gimnasio_id         INTEGER NOT NULL,

  genero         TEXT    NOT NULL CHECK (genero IN ('Male','Female')),
  edad            INTEGER NOT NULL CHECK (edad BETWEEN 10 AND 90),
  altura_m       REAL    NOT NULL CHECK (altura_m > 0.5 AND altura_m < 2.5),
  peso_kg      REAL    NOT NULL CHECK (peso_kg > 20 AND peso_kg < 250),
  porcentaje_grasa REAL    NOT NULL CHECK (porcentaje_grasa >= 0 AND porcentaje_grasa <= 60),
  imc            REAL    NOT NULL CHECK (imc > 0 AND imc < 100),

  FOREIGN KEY (gimnasio_id) REFERENCES dim_gimnasio(gimnasio_id)
);

-- DIM_EXPERIENCE_LEVEL: catálogo 1..3 con etiqueta legible.
-- Nota: nivel_experiencia_id ES el propio nivel (1..3).
CREATE TABLE IF NOT EXISTS dim_nivel_experiencia (
  nivel_experiencia_id INTEGER PRIMARY KEY CHECK (nivel_experiencia_id BETWEEN 1 AND 3),
  etiqueta               TEXT    NOT NULL CHECK (etiqueta IN ('Beginner', 'Intermediate', 'Advanced')) UNIQUE 
);

-- DIM_BMI_CATEGORY: clasificación por rangos estándar de BMI.
CREATE TABLE IF NOT EXISTS dim_categoria_imc (
  categoria_imc_id INTEGER PRIMARY KEY,
  nombre_categoria   TEXT NOT NULL CHECK (nombre_categoria IN ('Underweight', 'Normal', 'Overweight', 'Obese')) UNIQUE,
  imc_min         REAL NOT NULL CHECK (imc_min >= 0),
  imc_max         REAL NOT NULL CHECK (imc_max > imc_min)
);

-- DIM_CALENDAR: calendario sintético para análisis temporal (el dataset no trae fecha real). Se añade para poder hacer operaciones temporales.
CREATE TABLE IF NOT EXISTS dim_calendario (
  fecha_iso     TEXT PRIMARY KEY, -- 'YYYY-MM-DD'
  fecha_mostrar TEXT NOT NULL,    -- 'DD/MM/YYYY'
  dia          INTEGER NOT NULL CHECK (dia BETWEEN 1 AND 31),
  mes        INTEGER NOT NULL CHECK (mes BETWEEN 1 AND 12),
  anio         INTEGER NOT NULL CHECK (anio BETWEEN 1900 AND 2100),
  dia_semana      INTEGER NOT NULL CHECK (dia_semana BETWEEN 0 AND 6) 
);

/*═══════════════════════════════════════════════════════════════════
HECHOS
═══════════════════════════════════════════════════════════════════*/

-- FACT_WORKOUT_SESSION: 1 fila = 1 registro/sesión del CSV.
-- Contiene medidas (calorías, duración, BPM, agua) y FKs a dimensiones.
CREATE TABLE IF NOT EXISTS fact_sesion_entrenamiento (
  sesion_id  INTEGER PRIMARY KEY,

  -- FKs (dimensiones)
  fecha_iso            TEXT    NOT NULL,
  miembro_id           INTEGER NOT NULL,
  tipo_entrenamiento_id     INTEGER NOT NULL,
  nivel_experiencia_id INTEGER NOT NULL,
  categoria_imc_id     INTEGER NOT NULL,

  -- Medidas 
  max_bpm                    INTEGER NOT NULL CHECK (max_bpm BETWEEN 60 AND 250),
  avg_bpm                    INTEGER NOT NULL CHECK (avg_bpm BETWEEN 40 AND 220),
  bpm_reposo                INTEGER NOT NULL CHECK (bpm_reposo BETWEEN 30 AND 120),
  duracion_sesion_horas     REAL    NOT NULL CHECK (duracion_sesion_horas > 0 AND duracion_sesion_horas <= 5),
  calorias_quemadas            REAL    NOT NULL CHECK (calorias_quemadas >= 0),
  agua_litros        REAL    NOT NULL CHECK (agua_litros >= 0 AND agua_litros <= 10),
  frecuencia_entrenamiento_dias_semana INTEGER NOT NULL CHECK (frecuencia_entrenamiento_dias_semana BETWEEN 0 AND 7),

  -- Integridad referencial
  FOREIGN KEY (fecha_iso)            REFERENCES dim_calendario(fecha_iso),
  FOREIGN KEY (miembro_id)           REFERENCES dim_miembro(miembro_id),
  FOREIGN KEY (tipo_entrenamiento_id)     REFERENCES dim_tipo_entrenamiento(tipo_entrenamiento_id),
  FOREIGN KEY (nivel_experiencia_id) REFERENCES dim_nivel_experiencia(nivel_experiencia_id),
  FOREIGN KEY (categoria_imc_id)     REFERENCES dim_categoria_imc(categoria_imc_id)
);

/*═══════════════════════════════════════════════════════════════════
ÍNDICES
═══════════════════════════════════════════════════════════════════*/

CREATE INDEX IF NOT EXISTS idx_fact_member       ON fact_sesion_entrenamiento(miembro_id);
CREATE INDEX IF NOT EXISTS idx_fact_workout_type ON fact_sesion_entrenamiento(tipo_entrenamiento_id);

CREATE INDEX IF NOT EXISTS idx_member_gym        ON dim_miembro(gimnasio_id);
CREATE INDEX IF NOT EXISTS idx_bridge_gym        ON puente_gimnasio_tipo_entrenamiento(gimnasio_id);
CREATE INDEX IF NOT EXISTS idx_bridge_workout    ON puente_gimnasio_tipo_entrenamiento(tipo_entrenamiento_id);

/*═══════════════════════════════════════════════════════════════════
VIEWS 
═══════════════════════════════════════════════════════════════════*/

-- VIEW 1: KPI mensual por tipo de entrenamiento (tabla resumen)
CREATE VIEW IF NOT EXISTS vw_kpi_tipo_entrenamiento_mes AS
SELECT
  c.anio,
  c.mes,
  wt.nombre_tipo_entrenamiento,
  COUNT(*)                                  AS sessions,
  ROUND(SUM(f.calorias_quemadas), 2)          AS total_calories,
  ROUND(AVG(f.calorias_quemadas), 2)          AS avg_calories_per_session,
  ROUND(AVG(f.duracion_sesion_horas), 2)   AS avg_duration_hours,
  ROUND(AVG(f.avg_bpm), 1)                  AS avg_bpm
FROM fact_sesion_entrenamiento f
JOIN dim_calendario c       ON c.fecha_iso = f.fecha_iso
JOIN dim_tipo_entrenamiento wt  ON wt.tipo_entrenamiento_id = f.tipo_entrenamiento_id
GROUP BY c.anio, c.mes, wt.nombre_tipo_entrenamiento;

-- VIEW 2: KPIs por gimnasio y tipo (comparativa + ranking dentro del tipo)
-- Cada fila = (gimnasio, tipo permitido) con métricas y ranking dentro de cada tipo.
-- Incluye combinaciones con 0 sesiones (LEFT JOIN a agregación), siempre que estén permitidas por el puente.
CREATE VIEW IF NOT EXISTS vw_kpis_gimnasio AS
WITH allowed AS (
  SELECT -- en allowed guardamos todas las combinaciones gimnasio-tipo permitidas
    g.gimnasio_id,
    g.nombre_gimnasio,
    g.tipos_entrenamiento_ofrecidos,
    wt.tipo_entrenamiento_id,
    wt.nombre_tipo_entrenamiento
  FROM puente_gimnasio_tipo_entrenamiento bg
  JOIN dim_gimnasio g           ON g.gimnasio_id = bg.gimnasio_id
  JOIN dim_tipo_entrenamiento wt ON wt.tipo_entrenamiento_id = bg.tipo_entrenamiento_id
),
agg AS (
  SELECT -- en agg guardamos las métricas agregadas por gimnasio-tipo
    m.gimnasio_id,
    f.tipo_entrenamiento_id,
    COUNT(*)                                AS sessions,
    COUNT(DISTINCT f.miembro_id)             AS members,
    ROUND(SUM(f.calorias_quemadas), 2)        AS total_calories,
    ROUND(AVG(f.calorias_quemadas), 2)        AS avg_calories_per_session,
    ROUND(AVG(f.duracion_sesion_horas), 2) AS avg_duration_hours,
    ROUND(AVG(f.avg_bpm), 1)                AS avg_bpm
  FROM fact_sesion_entrenamiento f
  JOIN dim_miembro m ON m.miembro_id = f.miembro_id
  GROUP BY m.gimnasio_id, f.tipo_entrenamiento_id
)
SELECT -- final: combinamos allowed + agg con LEFT JOIN y calculamos rankings
  a.gimnasio_id,
  a.nombre_gimnasio,
  a.tipos_entrenamiento_ofrecidos,
  a.nombre_tipo_entrenamiento,
  COALESCE(agg.sessions, 0)        AS sessions,
  COALESCE(agg.members, 0)         AS members,
  COALESCE(agg.total_calories, 0)  AS total_calories,
  agg.avg_calories_per_session,
  agg.avg_duration_hours,
  agg.avg_bpm,
  RANK() OVER (PARTITION BY a.nombre_tipo_entrenamiento ORDER BY COALESCE(agg.total_calories, 0) DESC) AS rnk_total_calories_in_type,
  RANK() OVER (PARTITION BY a.nombre_tipo_entrenamiento ORDER BY COALESCE(agg.sessions, 0) DESC)       AS rnk_sessions_in_type
FROM allowed a
LEFT JOIN agg
  ON agg.gimnasio_id = a.gimnasio_id
 AND agg.tipo_entrenamiento_id = a.tipo_entrenamiento_id;

-- VIEW 3: KPIs por miembro 
CREATE VIEW IF NOT EXISTS vw_kpis_miembro AS
SELECT
  m.miembro_id,
  m.gimnasio_id,
  g.nombre_gimnasio,
  g.tipos_entrenamiento_ofrecidos,
  m.genero,
  m.edad,
  m.imc,
  COUNT(*)                                AS sessions,
  ROUND(SUM(f.calorias_quemadas), 2)        AS total_calories,
  ROUND(AVG(f.calorias_quemadas), 2)        AS avg_calories,
  ROUND(AVG(f.duracion_sesion_horas), 2) AS avg_duration_hours,
  ROUND(AVG(f.avg_bpm), 1)                AS avg_avg_bpm
FROM fact_sesion_entrenamiento f
JOIN dim_miembro m ON m.miembro_id = f.miembro_id
JOIN dim_gimnasio g    ON g.gimnasio_id = m.gimnasio_id
GROUP BY m.miembro_id, m.gimnasio_id, g.nombre_gimnasio, g.tipos_entrenamiento_ofrecidos, m.genero, m.edad, m.imc;
