INSTALL spatial;
INSTALL httpfs;
LOAD spatial;
LOAD httpfs;


CREATE TABLE my_buildings AS
SELECT
    "id" AS osm_id,
    "building" AS building_type,
    "building:levels" AS levels,
    "addr:housenumber" AS housenumber,
    "addr:street" AS street,
    "addr:place" AS place,
    "addr:district" AS district,
    geom
FROM ST_Read('map.json')
WHERE "building" IS NOT NULL
  AND ST_GeometryType(geom) = 'POLYGON';


SELECT
    COUNT(*) AS total_buildings,
    COUNT(DISTINCT building_type) AS distinct_types
FROM my_buildings;

SELECT
    typeof(ANY_VALUE(geom)) AS geom_column_type,
    COUNT(*) AS total,
    COUNT(geom) AS non_null_geom,
    COUNT(*) FILTER (WHERE try(ST_IsValid(geom)) = true) AS valid_geom,
    COUNT(*) FILTER (WHERE try(ST_IsValid(geom)) = false) AS invalid_geom
FROM my_buildings;


CREATE TABLE partitions AS
WITH collection AS (
    SELECT *
    FROM 'https://stac.overturemaps.org/2026-04-15.0/buildings/building/collection.json'
),
raw_links AS (
    SELECT unnest(links) AS lnk
    FROM collection
),
numbered_links AS (
    SELECT row_number() OVER () AS rn, lnk.href AS href
    FROM raw_links
    WHERE lnk.type = 'application/geo+json'
),
raw_bboxes AS (
    SELECT unnest(extent.spatial.bbox) AS bb
    FROM collection
),
numbered_bboxes AS (
    SELECT
        row_number() OVER () AS rn,
        bb[1] AS lon_min,
        bb[2] AS lat_min,
        bb[3] AS lon_max,
        bb[4] AS lat_max
    FROM raw_bboxes
)
SELECT nl.href, nb.lon_min, nb.lat_min, nb.lon_max, nb.lat_max
FROM numbered_links nl
JOIN numbered_bboxes nb ON nl.rn = nb.rn;

CREATE TABLE my_bbox AS
SELECT
    MIN(ST_XMin(geom)) AS lon_min,
    MIN(ST_YMin(geom)) AS lat_min,
    MAX(ST_XMax(geom)) AS lon_max,
    MAX(ST_YMax(geom)) AS lat_max
FROM my_buildings;

SELECT * FROM my_bbox;


SET VARIABLE partition_item_url = (
    SELECT
        'https://stac.overturemaps.org/2026-04-15.0/buildings/building/' || p.href
    FROM partitions p, my_bbox b
    WHERE b.lon_min BETWEEN p.lon_min AND p.lon_max
      AND b.lat_min BETWEEN p.lat_min AND p.lat_max
    LIMIT 1
);

SET VARIABLE parquet_url = (
    SELECT assets.aws.alternate.s3.href
    FROM read_json(getvariable('partition_item_url'))
);

SELECT
    getvariable('partition_item_url') AS partition_url,
    getvariable('parquet_url') AS parquet_url;


CREATE TABLE overture_buildings AS
WITH bbox AS (SELECT * FROM my_bbox)
SELECT
    ov.id,
    ov.geometry,
    ov.names,
    ov.height,
    ov.num_floors,
    ov.class,
    ov.subtype,
    ov.sources,
    CASE
        WHEN EXISTS (
            SELECT 1 FROM my_buildings mb
            WHERE try(ST_Intersects(
                mb.geom,
                ST_SetCRS(ov.geometry, 'EPSG:4326')
            )) = true
        )
            THEN 'my'
        WHEN list_contains(
            list_transform(ov.sources, s -> s.dataset),
            'OpenStreetMap'
        )
            THEN 'osm'
        ELSE
            'ml'
    END AS source_type
FROM read_parquet(getvariable('parquet_url')) ov
JOIN bbox b 
 ON ST_XMin(ov.geometry) BETWEEN b.lon_min AND b.lon_max
 AND ST_YMin(ov.geometry) BETWEEN b.lat_min AND b.lat_max
WHERE try(ST_IsValid(ov.geometry)) = true;


SELECT source_type, COUNT(*) AS cnt
FROM overture_buildings
GROUP BY source_type
ORDER BY cnt DESC;


COPY (
    SELECT json_object(
        'type', 'FeatureCollection',
        'features', json_group_array(
            json_object(
                'type', 'Feature',
                'geometry', ST_AsGeoJSON(ST_SetCRS(geometry, 'EPSG:4326'))::JSON,
                'properties', json_object(
                    'id', id,
                    'source_type', source_type,
                    'name', names.primary,
                    'height', height,
                    'num_floors', num_floors,
                    'class', class,
                    'subtype', subtype
                )
            )
        )
    )
    FROM (
        SELECT DISTINCT ON (id) *
        FROM overture_buildings
    )
)
TO 'client/gis-2026/public/overture.json'
WITH (FORMAT CSV, HEADER false, QUOTE '');