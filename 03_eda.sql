PRAGMA foreign_keys = ON;

/*═══════════════════════════════════════════════════════════════════
0) SANITY CHECKS
═══════════════════════════════════════════════════════════════════*/
SELECT 'dim_miembro' AS table_name, COUNT(*) AS n FROM dim_miembro
UNION ALL SELECT 'dim_tipo_entrenamiento', COUNT(*) FROM dim_tipo_entrenamiento
UNION ALL SELECT 'dim_nivel_experiencia', COUNT(*) FROM dim_nivel_experiencia
UNION ALL SELECT 'dim_categoria_imc', COUNT(*) FROM dim_categoria_imc
UNION ALL SELECT 'dim_calendario', COUNT(*) FROM dim_calendario
UNION ALL SELECT 'fact_sesion_entrenamiento', COUNT(*) FROM fact_sesion_entrenamiento;

/*═══════════════════════════════════════════════════════════════════
1) KPI global: sesiones, calorías, duración
Insight: visión rápida del “tamaño” de todos los datos recopilados.
═══════════════════════════════════════════════════════════════════*/
SELECT
  COUNT(*) AS sessions,
  ROUND(SUM(calorias_quemadas), 2) AS total_calories,
  ROUND(AVG(calorias_quemadas), 2) AS avg_calories,
  ROUND(AVG(duracion_sesion_horas), 2) AS avg_duration_hours
FROM fact_sesion_entrenamiento;

/*═══════════════════════════════════════════════════════════════════
2) JOIN (INNER): calorías y duración por tipo de entrenamiento
Insight: qué tipo aporta más al objetivo (quemar calorías) y cuál dura más.
═══════════════════════════════════════════════════════════════════*/
SELECT
  wt.nombre_tipo_entrenamiento,
  COUNT(*) AS sessions,
  ROUND(AVG(f.calorias_quemadas), 2) AS avg_calories,
  ROUND(AVG(f.duracion_sesion_horas), 2) AS avg_duration_hours,
  ROUND(AVG(f.avg_bpm), 1) AS avg_bpm
FROM fact_sesion_entrenamiento f
JOIN dim_tipo_entrenamiento wt ON wt.tipo_entrenamiento_id = f.tipo_entrenamiento_id
GROUP BY wt.nombre_tipo_entrenamiento
ORDER BY avg_calories DESC;

/*═══════════════════════════════════════════════════════════════════
3) LEFT JOIN: distribución de categoría BMI vs tipo de entrenamiento
Insight: segmentación (producto/marketing): qué entrenos predominan por categoría BMI.
═══════════════════════════════════════════════════════════════════*/
SELECT
  bc.nombre_categoria,
  wt.nombre_tipo_entrenamiento,
  COUNT(*) AS sessions,
  ROUND(AVG(f.calorias_quemadas), 2) AS avg_calories
FROM fact_sesion_entrenamiento f
LEFT JOIN dim_categoria_imc bc ON bc.categoria_imc_id = f.categoria_imc_id
LEFT JOIN dim_tipo_entrenamiento wt ON wt.tipo_entrenamiento_id = f.tipo_entrenamiento_id
GROUP BY bc.nombre_categoria, wt.nombre_tipo_entrenamiento
ORDER BY bc.nombre_categoria, sessions DESC;

/*═══════════════════════════════════════════════════════════════════
4) CASE: clasificación de intensidad por avg_bpm
Insight: podemos definir reglas para intensidad y ver qué entrenos son más intensos.
═══════════════════════════════════════════════════════════════════*/
WITH base AS (
  SELECT
    f.*,
    wt.nombre_tipo_entrenamiento,
    CASE
      WHEN f.avg_bpm < 120 THEN 'Low'
      WHEN f.avg_bpm < 150 THEN 'Moderate'
      ELSE 'High'
    END AS intensity
  FROM fact_sesion_entrenamiento f
  JOIN dim_tipo_entrenamiento wt ON wt.tipo_entrenamiento_id = f.tipo_entrenamiento_id
)
SELECT
  nombre_tipo_entrenamiento,
  intensity,
  COUNT(*) AS sessions,
  ROUND(AVG(calorias_quemadas), 2) AS avg_calories
FROM base
GROUP BY nombre_tipo_entrenamiento, intensity
ORDER BY nombre_tipo_entrenamiento, sessions DESC;

/*═══════════════════════════════════════════════════════════════════
5) CTEs encadenadas + Window function: ranking por calorías dentro de cada tipo
Insight: identifica “top sesiones” por tipo. Nos sirve para outliers / calidad del dato.
═══════════════════════════════════════════════════════════════════*/
WITH base AS (
  SELECT
    f.sesion_id,
    wt.nombre_tipo_entrenamiento,
    f.calorias_quemadas,
    f.duracion_sesion_horas
  FROM fact_sesion_entrenamiento f
  JOIN dim_tipo_entrenamiento wt ON wt.tipo_entrenamiento_id = f.tipo_entrenamiento_id
),
ranked AS (
  SELECT
    *,
    RANK() OVER (PARTITION BY nombre_tipo_entrenamiento ORDER BY calorias_quemadas DESC) AS rnk
  FROM base
)
SELECT *
FROM ranked
WHERE rnk <= 5
ORDER BY nombre_tipo_entrenamiento, rnk;

/*═══════════════════════════════════════════════════════════════════
6) Calendario + agregación mensual (usando la vista)
Insight: detectar tendencias mensuales en calorías quemadas por tipo de entrenamiento (en este caso no obtendríamos información real pues son fechas sintéticas).
═══════════════════════════════════════════════════════════════════*/
SELECT *
FROM vw_kpi_tipo_entrenamiento_mes
ORDER BY anio, mes, total_calories DESC;

/*═══════════════════════════════════════════════════════════════════
7) Subquery: comparar cada sesión contra la media de su tipo de workout
Insight: detectar sesiones por encima/debajo de la media (rendimiento / anomalías).
═══════════════════════════════════════════════════════════════════*/
SELECT
  f.sesion_id,
  wt.nombre_tipo_entrenamiento,
  f.calorias_quemadas,
  ROUND(( -- subconsulta para avg por tipo
    SELECT AVG(f2.calorias_quemadas)
    FROM fact_sesion_entrenamiento f2
    WHERE f2.tipo_entrenamiento_id = f.tipo_entrenamiento_id
  ), 2) AS avg_calories_same_type,
  ROUND(f.calorias_quemadas - ( -- diferencia vs avg por tipo
    SELECT AVG(f2.calorias_quemadas)
    FROM fact_sesion_entrenamiento f2
    WHERE f2.tipo_entrenamiento_id = f.tipo_entrenamiento_id
  ), 2) AS diff_vs_avg
FROM fact_sesion_entrenamiento f
JOIN dim_tipo_entrenamiento wt ON wt.tipo_entrenamiento_id = f.tipo_entrenamiento_id
ORDER BY diff_vs_avg DESC
LIMIT 20;

/*═══════════════════════════════════════════════════════════════════
8) Vista: KPIs por miembro (al igual que anteriormente, usamos una vista
Insight: consulta por usuario. Ejemplo de consulta reutilizable.
═══════════════════════════════════════════════════════════════════*/
SELECT *
FROM vw_kpis_miembro
WHERE miembro_id = 1;

/*═══════════════════════════════════════════════════════════════════
9) WORKOUTS DISPONIBLES POR GIMNASIO
═══════════════════════════════════════════════════════════════════*/
SELECT
  g.gimnasio_id,
  g.nombre_gimnasio,
  GROUP_CONCAT(wt.nombre_tipo_entrenamiento, ', ') AS workout_types_offered_norm
FROM puente_gimnasio_tipo_entrenamiento bg
JOIN dim_gimnasio g           ON g.gimnasio_id = bg.gimnasio_id
JOIN dim_tipo_entrenamiento wt ON wt.tipo_entrenamiento_id = bg.tipo_entrenamiento_id
GROUP BY g.gimnasio_id, g.nombre_gimnasio
ORDER BY g.gimnasio_id;


/*═══════════════════════════════════════════════════════════════════
10) VALIDACIÓN: NO HAY SESIONES CON WORKOUT NO OFRECIDO
═══════════════════════════════════════════════════════════════════*/
SELECT
  COUNT(*) AS invalid_sessions
FROM fact_sesion_entrenamiento f
JOIN dim_miembro m ON m.miembro_id = f.miembro_id
LEFT JOIN puente_gimnasio_tipo_entrenamiento bg -- verificar si el workout está ofrecido
  ON bg.gimnasio_id = m.gimnasio_id
 AND bg.tipo_entrenamiento_id = f.tipo_entrenamiento_id
WHERE bg.tipo_entrenamiento_id IS NULL;


/*═══════════════════════════════════════════════════════════════════
11) VISTA: KPIs POR GIMNASIO Y TIPO (vw_kpis_gimnasio)
═══════════════════════════════════════════════════════════════════*/
SELECT *
FROM vw_kpis_gimnasio
ORDER BY nombre_tipo_entrenamiento, rnk_total_calories_in_type, nombre_gimnasio;