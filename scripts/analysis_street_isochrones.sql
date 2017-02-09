-- street network isochrone analysis of study area, from stations

-- prepare just relevant network for isochrones, based on TOP10nl
-- DROP TABLE street_isochrone_analysis.wegen CASCADE;
CREATE TABLE street_isochrone_analysis.wegen AS
	SELECT DISTINCT(weg.*) 
	FROM study.t10_wegen weg, study.stations_maakplaats stat
	WHERE (fiets = TRUE OR fiets IS NULL OR voetganger = TRUE OR voetganger IS NULL)
	AND ST_DWithin(weg.geom,stat.geom,3000)
;
-- prepare topology
-- ALTER TABLE street_isochrone_analysis.wegen DROP COLUMN source, DROP COLUMN target;
ALTER TABLE street_isochrone_analysis.wegen ADD COLUMN source integer, ADD COLUMN target integer;
-- build the network topology
SELECT pgr_createTopology('street_isochrone_analysis.wegen', 0.01, 'geom', 'sid');
SELECT pgr_analyzeGraph('street_isochrone_analysis.wegen', 0.01, 'geom', 'sid');
-- connect Amsterdam Centraal ferries to the road network, by assigning new source/target ids
-- DROP TABLE free_ferry CASCADE;
CREATE TEMP TABLE free_ferry AS
	SELECT * FROM street_isochrone_analysis.wegen
	WHERE type_weg = 'veerverbinding' AND ST_DWithin(geom,
		(SELECT geom FROM study.stations_maakplaats WHERE naam = 'AMSTERDAM CENTRAAL'),3000)
;
-- DROP TABLE new_ferry_nodes CASCADE;
CREATE TEMP TABLE new_ferry_nodes AS (
	SELECT DISTINCT ON (ferry_nodes.id) ferry_nodes.id, road_nodes.id road_node, 
		ST_Distance(ferry_nodes.the_geom, road_nodes.the_geom) dist
	FROM (
		SELECT * FROM street_isochrone_analysis.wegen_vertices_pgr vert
		WHERE NOT EXISTS 
			(SELECT 1 FROM free_ferry f WHERE f.source=vert.id OR f.target=vert.id)
	) road_nodes, (
		SELECT * FROM street_isochrone_analysis.wegen_vertices_pgr vert, free_ferry f
		WHERE f.source=vert.id OR f.target=vert.id
	) ferry_nodes
	WHERE ST_DWithin(ferry_nodes.the_geom, road_nodes.the_geom,200) 
	ORDER BY ferry_nodes.id, dist
);
UPDATE street_isochrone_analysis.wegen ferry SET
	source = road_node
	FROM new_ferry_nodes
	WHERE ferry.t10_id in (SELECT t10_id FROM free_ferry)
	AND ferry.source = new_ferry_nodes.id
;
UPDATE street_isochrone_analysis.wegen ferry SET
	target = road_node
	FROM new_ferry_nodes
	WHERE ferry.t10_id in (SELECT t10_id FROM free_ferry)
	AND ferry.target = new_ferry_nodes.id
;
-- DROP INDEX nwb_wegen_geom_idx CASCADE;
CREATE INDEX wegen_geom_idx ON street_isochrone_analysis.wegen USING GIST (geom);
-- DROP INDEX nwb_wegen_geom_idx CASCADE;
CREATE INDEX wegen_vertices_geom_idx ON street_isochrone_analysis.wegen_vertices_pgr USING GIST (the_geom);

/*
-- prepare just relevant network for isochrones, based on NWB
-- DROP TABLE street_isochrone_analysis.nwb_wegen CASCADE;
CREATE TABLE street_isochrone_analysis.nwb_wegen AS
	SELECT DISTINCT(weg.*) FROM study.nwb_wegen weg, study.stations_maakplaats stat
	WHERE ST_DWithin(weg.geom,stat.geom,3500)
;
-- prepare topology
-- ALTER TABLE street_isochrone_analysis.nwb_wegen DROP COLUMN source, DROP COLUMN target;
ALTER TABLE street_isochrone_analysis.nwb_wegen ADD COLUMN source integer, ADD COLUMN target integer;
-- build the network topology
SELECT pgr_createTopology('street_isochrone_analysis.nwb_wegen', 0.01, 'geom', 'sid');
SELECT pgr_analyzeGraph('street_isochrone_analysis.nwb_wegen', 0.01, 'geom', 'sid');
*/

-----
-- link stations to 2 nearest (non connected) streets
-- DROP TABLE street_isochrone_analysis.origin_stations CASCADE;
CREATE TABLE street_isochrone_analysis.origin_stations (
	sid serial NOT NULL PRIMARY KEY,
	geom geometry(Point,28992),
	station_sid integer,
	station_id character varying,
	station_naam character varying,
	weg_sid integer,
	weg_dist double precision,
	weg_length double precision,
	weg_point_location double precision,
	source_id integer,
	target_id integer
);
-- add closest weg
INSERT INTO street_isochrone_analysis.origin_stations (station_sid, geom, station_id, station_naam, 
	weg_sid, weg_length, weg_dist, weg_point_location, source_id, target_id)
	SELECT DISTINCT ON(stat.sid) stat.sid, 
		ST_ClosestPoint(weg.geom, stat.geom), stat.id, stat.naam, weg.sid, weg.length,
		ST_Distance(stat.geom, weg.geom) dist, 
		ST_LineLocatePoint(weg.geom, ST_GeometryN(stat.geom, 1)),
		weg.source, weg.target
	FROM study.stations_maakplaats stat, street_isochrone_analysis.wegen weg
	WHERE ST_DWithin(stat.geom, weg.geom, 200)
	ORDER BY stat.sid, dist ASC
;
-- add second closest weg, not in the list, nor connected to one already in the list
INSERT INTO street_isochrone_analysis.origin_stations (station_sid, geom, station_id, station_naam, 
	weg_sid, weg_length, weg_dist, weg_point_location, source_id, target_id)
	SELECT DISTINCT ON(stat.sid) stat.sid, 
		ST_ClosestPoint(weg.geom, stat.geom), stat.id, stat.naam, weg.sid, weg.length,
		ST_Distance(stat.geom, weg.geom) dist, 
		ST_LineLocatePoint(weg.geom, ST_GeometryN(stat.geom, 1)),
		weg.source, weg.target
	FROM study.stations_maakplaats stat, street_isochrone_analysis.wegen weg
	WHERE ST_DWithin(stat.geom, weg.geom, 200)
	AND weg.sid NOT IN (SELECT weg_sid FROM street_isochrone_analysis.origin_stations a WHERE a.station_sid = stat.sid)
	AND weg.target NOT IN (SELECT source_id FROM street_isochrone_analysis.origin_stations a WHERE a.station_sid = stat.sid)
	AND weg.source NOT IN (SELECT source_id FROM street_isochrone_analysis.origin_stations a WHERE a.station_sid = stat.sid)
	AND weg.target NOT IN (SELECT target_id FROM street_isochrone_analysis.origin_stations a WHERE a.station_sid = stat.sid)
	AND weg.source NOT IN (SELECT target_id FROM street_isochrone_analysis.origin_stations a WHERE a.station_sid = stat.sid)
	-- AND line between two points does cross the railway
	ORDER BY stat.sid, dist ASC
;
CREATE INDEX establishments_origins_station_idx ON street_isochrone_analysis.origin_stations (station_sid);
CREATE INDEX establishments_origins_weg_idx ON street_isochrone_analysis.origin_stations (weg_sid);
CREATE INDEX establishments_origins_source_idx ON street_isochrone_analysis.origin_stations (source_id);
CREATE INDEX establishments_origins_target_idx ON street_isochrone_analysis.origin_stations (target_id);


-----
-- calculate street network isochrones for 800m walking, 3000m cycling
-- DROP TABLE street_isochrone_analysis.isochrone_nodes CASCADE;
CREATE TABLE street_isochrone_analysis.isochrone_nodes(
	sid bigserial NOT NULL PRIMARY KEY,
	origin_id integer,
	travel_mode varchar,
	node_id integer,
	node_distance double precision
);
-- fiets for 3000m
-- DROP TABLE wegen_fiets CASCADE;
CREATE TEMP TABLE wegen_fiets AS (
	SELECT * FROM street_isochrone_analysis.wegen WHERE fiets IS NULL OR fiets = True
);
-- DELETE FROM analysis.isochrone_nodes WHERE travel_mode = 'fiets';
INSERT INTO street_isochrone_analysis.isochrone_nodes (origin_id, travel_mode, node_id, node_distance)
	SELECT origin.id, 'fiets', (origin.catchment).id1, (origin.catchment).cost
		FROM (
			SELECT a.id, pgr_drivingDistance(
				'SELECT sid AS id, source, target, length AS cost FROM wegen_fiets',
				a.id::integer, 2900.0, false, false
			) catchment
			FROM (
				SELECT * FROM street_isochrone_analysis.wegen_vertices_pgr v
				WHERE EXISTS (SELECT 1 FROM wegen_fiets WHERE source=v.id OR target=v.id)
				AND EXISTS (SELECT 1 FROM street_isochrone_analysis.origin_stations 
				WHERE source_id=v.id OR target_id=v.id) 
			) a
		) origin
;
-- voetganger for 800m
-- DROP TABLE wegen_voetganger CASCADE;
CREATE TEMP TABLE wegen_voetganger AS (
	SELECT * FROM street_isochrone_analysis.wegen WHERE voetganger IS NULL OR voetganger = True
);
-- DELETE FROM street_isochrone_analysis.isochrone_nodes WHERE travel_mode = 'voetganger';
INSERT INTO street_isochrone_analysis.isochrone_nodes (origin_id, travel_mode, node_id, node_distance)
	SELECT origin.id, 'voetganger', (origin.catchment).id1, (origin.catchment).cost
		FROM (
			SELECT a.id, pgr_drivingDistance(
				'SELECT sid AS id, source, target, length AS cost FROM wegen_voetganger',
				a.id::integer, 700.0, false, false
			) catchment
			FROM (
				SELECT * FROM street_isochrone_analysis.wegen_vertices_pgr v
				WHERE EXISTS (SELECT 1 FROM wegen_voetganger WHERE source=v.id OR target=v.id)
				AND EXISTS (SELECT 1 FROM street_isochrone_analysis.origin_stations 
				WHERE source_id=v.id OR target_id=v.id) 
			) a
		) origin
;
-- DROP INDEX street_isochrone_analysis.isochrone_nodes_node_distance_idx;
CREATE INDEX isochrone_nodes_node_distance_idx ON street_isochrone_analysis.isochrone_nodes (node_distance);

-----
-- identify isochrone nodes per station
-- DROP TABLE street_isochrone_analysis.station_isochrone_nodes CASCADE;
CREATE TABLE street_isochrone_analysis.station_isochrone_nodes (
	sid serial NOT NULL PRIMARY KEY,
	geom geometry(Point, 28992),
	station_sid integer,
	station_id varchar,
	station_naam varchar,
	travel_mode varchar,
	node_id integer,
	node_distance double precision
);
-- insert fiets nodes
-- DROP TABLE fiets_isochrone_nodes CASCADE;
CREATE TEMP TABLE fiets_isochrone_nodes AS
	SELECT stat.station_sid, stat.station_id, stat.station_naam, nodes.travel_mode, nodes.node_id,
		(nodes.node_distance + (stat.weg_length*stat.weg_point_location)) node_distance
		FROM street_isochrone_analysis.origin_stations stat, (
			SELECT * FROM street_isochrone_analysis.isochrone_nodes WHERE travel_mode = 'fiets'
		) nodes
		WHERE stat.source_id = nodes.origin_id 
		AND (nodes.node_distance + (stat.weg_length*stat.weg_point_location)) <= 2900
;
INSERT INTO fiets_isochrone_nodes
	SELECT stat.station_sid, stat.station_id, stat.station_naam, nodes.travel_mode, nodes.node_id,
		(nodes.node_distance + (stat.weg_length*(1-stat.weg_point_location))) node_distance		
		FROM street_isochrone_analysis.origin_stations stat, (
			SELECT * FROM street_isochrone_analysis.isochrone_nodes WHERE travel_mode = 'fiets'
		) nodes
		WHERE stat.target_id = nodes.origin_id 
		AND (nodes.node_distance + (stat.weg_length*(1-stat.weg_point_location))) <= 2900
;
-- group the above by station keeping only the minimum node_distance
-- DELETE FROM street_isochrone_analysis.station_isochrone_nodes WHERE travel_mode = 'fiets';
INSERT INTO street_isochrone_analysis.station_isochrone_nodes (station_sid, station_id, station_naam, 
		travel_mode, node_id, node_distance)
	SELECT station_sid, station_id, station_naam, travel_mode, node_id, min(node_distance)
	FROM fiets_isochrone_nodes
	GROUP BY station_sid, station_id, station_naam, travel_mode, node_id
;
-- insert voetganger nodes
-- DROP TABLE voetganger_isochrone_nodes CASCADE;
CREATE TEMP TABLE voetganger_isochrone_nodes AS
	SELECT stat.station_sid, stat.station_id, stat.station_naam, nodes.travel_mode, nodes.node_id,
		(nodes.node_distance + (stat.weg_length*stat.weg_point_location)) node_distance
		FROM street_isochrone_analysis.origin_stations stat, (
			SELECT * FROM street_isochrone_analysis.isochrone_nodes WHERE travel_mode = 'voetganger'
		) nodes
		WHERE stat.source_id = nodes.origin_id 
		AND (nodes.node_distance + (stat.weg_length*stat.weg_point_location)) <= 700
;
INSERT INTO voetganger_isochrone_nodes
	SELECT stat.station_sid, stat.station_id, stat.station_naam, nodes.travel_mode, nodes.node_id,
		(nodes.node_distance + (stat.weg_length*(1-stat.weg_point_location))) node_distance		
		FROM street_isochrone_analysis.origin_stations stat, (
			SELECT * FROM street_isochrone_analysis.isochrone_nodes WHERE travel_mode = 'voetganger'
		) nodes
		WHERE stat.target_id = nodes.origin_id 
		AND (nodes.node_distance + (stat.weg_length*(1-stat.weg_point_location))) <= 700
;
-- group the above by station keeping only the minimum node_distance
-- DELETE FROM street_isochrone_analysis.station_isochrone_nodes WHERE travel_mode = 'voetganger';
INSERT INTO street_isochrone_analysis.station_isochrone_nodes (station_sid, station_id, station_naam, 
		travel_mode, node_id, node_distance)
	SELECT station_sid, station_id, station_naam, travel_mode, node_id, min(node_distance)
	FROM voetganger_isochrone_nodes
	GROUP BY station_sid, station_id, station_naam, travel_mode, node_id
;
-- add geometry
UPDATE street_isochrone_analysis.station_isochrone_nodes stat SET geom=vrt.the_geom
	FROM street_isochrone_analysis.wegen_vertices_pgr vrt
	WHERE stat.node_id = vrt.id
;
-- DROP INDEX isochrone_nodes_geom_idx;
CREATE INDEX station_isochrone_nodes_geom_idx ON street_isochrone_analysis.station_isochrone_nodes USING GIST (geom);
CREATE INDEX station_isochrone_nodes_station_sid_idx ON street_isochrone_analysis.station_isochrone_nodes (station_sid);
CREATE INDEX station_isochrone_nodes_node_id_idx ON street_isochrone_analysis.station_isochrone_nodes (node_id);


-----
-- create road network based on isochrone distances
-- DROP TABLE street_isochrone_analysis.station_isochrone_wegen CASCADE;
CREATE TABLE street_isochrone_analysis.station_isochrone_wegen (
	sid serial NOT NULL PRIMARY KEY,
	geom geometry(Linestring, 28992),
	weg_sid integer,
	station_sid integer,
	station_id varchar,
	station_naam varchar,
	travel_mode varchar,
	travel_distance integer
);
-----
-- add intersecting wegen network based on isochrone distances
-- DELETE FROM street_isochrone_analysis.station_isochrone_wegen;
INSERT INTO street_isochrone_analysis.station_isochrone_wegen (geom, weg_sid, station_sid, station_id, 
	station_naam, travel_mode, travel_distance)
	SELECT weg.geom, weg.sid, stat.sid, stat.id, stat.naam, 'fiets', 3000
	FROM study.stations_maakplaats stat, street_isochrone_analysis.wegen weg 
	WHERE EXISTS (SELECT 1 FROM street_isochrone_analysis.station_isochrone_nodes f 
		WHERE travel_mode = 'fiets' AND node_distance <= 2900 AND f.station_sid = stat.sid
		AND f.node_id = weg.source)
	OR EXISTS (SELECT 1 FROM street_isochrone_analysis.station_isochrone_nodes f 	
		WHERE travel_mode = 'fiets' AND node_distance <= 2900 AND f.station_sid = stat.sid
		AND f.node_id = weg.target)
;
INSERT INTO street_isochrone_analysis.station_isochrone_wegen (geom, weg_sid, station_sid, station_id, 
	station_naam, travel_mode, travel_distance)
	SELECT weg.geom, weg.sid, stat.sid, stat.id, stat.naam, 'voetganger', 800
	FROM study.stations_maakplaats stat, street_isochrone_analysis.wegen weg 
	WHERE EXISTS (SELECT 1 FROM street_isochrone_analysis.station_isochrone_nodes f 
		WHERE travel_mode = 'voetganger' AND node_distance <= 700 AND f.station_sid = stat.sid
		AND f.node_id = weg.source)
	OR EXISTS (SELECT 1 FROM street_isochrone_analysis.station_isochrone_nodes f 	
		WHERE travel_mode = 'voetganger' AND node_distance <= 700 AND f.station_sid = stat.sid
		AND f.node_id = weg.target)
;
CREATE INDEX station_isochrone_wegen_geom_idx ON street_isochrone_analysis.station_isochrone_wegen USING GIST (geom);
CREATE INDEX station_isochrone_wegen_idx ON street_isochrone_analysis.station_isochrone_wegen (station_id, travel_mode, travel_distance);

-- create buffers for isochrones
-- DROP TABLE street_isochrone_analysis.station_isochrone_buffers CASCADE;
CREATE TABLE street_isochrone_analysis.station_isochrone_buffers (
	sid serial NOT NULL PRIMARY KEY,
	geom geometry(MultiPolygon,28992),
	station_id character varying,
	station_naam character varying,
	travel_mode character varying, 
	travel_distance integer
);
INSERT INTO street_isochrone_analysis.station_isochrone_buffers (geom, station_id, station_naam, travel_mode, travel_distance)
	SELECT ST_Multi(ST_Union(ST_Buffer(ST_Simplify(geom,5),100,2))), station_id, min(station_naam), 
		travel_mode, travel_distance
	FROM street_isochrone_analysis.station_isochrone_wegen
	GROUP BY station_id, travel_mode, travel_distance
;
-- create polygons for isochrones
-- DROP TABLE street_isochrone_analysis.station_isochrone_polygons CASCADE;
CREATE TABLE street_isochrone_analysis.station_isochrone_polygons (
	sid serial NOT NULL PRIMARY KEY,
	geom geometry(Polygon,28992),
	station_id character varying,
	station_naam character varying,
	travel_mode character varying, 
	travel_distance integer
);
INSERT INTO street_isochrone_analysis.station_isochrone_polygons (geom, station_id, station_naam, travel_mode, travel_distance)
	SELECT ST_MakePolygon(ST_ExteriorRing((ST_Dump(ST_Union(ST_Buffer(ST_Simplify(geom,5),100,2)))).geom)), 
		station_id, min(station_naam), travel_mode, travel_distance
	FROM street_isochrone_analysis.station_isochrone_wegen
	GROUP BY station_id, travel_mode, travel_distance
;


-----
-- add wegen network entirely within isochrone distances
-- DROP TABLE street_isochrone_analysis.station_isochrone_wegen_full CASCADE;
CREATE TABLE street_isochrone_analysis.station_isochrone_wegen_full (
	sid serial NOT NULL PRIMARY KEY,
	geom geometry(Linestring, 28992),
	weg_sid integer,
	station_sid integer,
	station_id varchar,
	station_naam varchar,
	travel_mode varchar,
	travel_distance integer,
	new_node double precision
);
INSERT INTO street_isochrone_analysis.station_isochrone_wegen_full (geom, weg_sid, station_sid, station_id, 
	station_naam, travel_mode, travel_distance)
	SELECT weg.geom, weg.sid, stat.sid, stat.id, stat.naam, 'fiets', 3000
	FROM study.stations_maakplaats stat, street_isochrone_analysis.wegen weg 
	WHERE EXISTS (SELECT 1 FROM street_isochrone_analysis.station_isochrone_nodes f 
		WHERE travel_mode = 'fiets' AND node_distance <= 2900 AND f.station_sid = stat.sid
		AND f.node_id = weg.source)
	AND EXISTS (SELECT 1 FROM street_isochrone_analysis.station_isochrone_nodes f 	
		WHERE travel_mode = 'fiets' AND node_distance <= 2900 AND f.station_sid = stat.sid
		AND f.node_id = weg.target)
;
INSERT INTO street_isochrone_analysis.station_isochrone_wegen_full (geom, weg_sid, station_sid, station_id, 
	station_naam, travel_mode, travel_distance)
	SELECT weg.geom, weg.sid, stat.sid, stat.id, stat.naam, 'voetganger', 800
	FROM study.stations_maakplaats stat, street_isochrone_analysis.wegen weg 
	WHERE EXISTS (SELECT 1 FROM street_isochrone_analysis.station_isochrone_nodes f 
		WHERE travel_mode = 'voetganger' AND node_distance <= 700 AND f.station_sid = stat.sid
		AND f.node_id = weg.source)
	AND EXISTS (SELECT 1 FROM street_isochrone_analysis.station_isochrone_nodes f 	
		WHERE travel_mode = 'voetganger' AND node_distance <= 700 AND f.station_sid = stat.sid
		AND f.node_id = weg.target)
;
CREATE INDEX station_isochrone_wegen_full_geom_idx ON street_isochrone_analysis.station_isochrone_wegen_full USING GIST (geom);
CREATE INDEX station_isochrone_wegen_full_idx ON street_isochrone_analysis.station_isochrone_wegen_full (station_id, travel_mode, travel_distance);
-----
-- add weg segments calculated with linear referencing
-- DROP TABLE half_segments CASCADE;
CREATE TEMP TABLE half_segments AS (
	SELECT iso.*, weg.length, weg.source, weg.target 
	FROM (
		SELECT * FROM street_isochrone_analysis.station_isochrone_wegen w 
		WHERE NOT EXISTS (
			SELECT 1 FROM street_isochrone_analysis.station_isochrone_wegen_full a
			WHERE a.weg_sid=w.weg_sid 
			AND a.station_sid=w.station_sid
			AND a.travel_mode=w.travel_mode
			AND a.travel_distance=w.travel_distance
		)
	) iso JOIN street_isochrone_analysis.wegen weg ON (iso.weg_sid=weg.sid)
);
-- fiets from source
INSERT INTO street_isochrone_analysis.station_isochrone_wegen_full (geom, weg_sid, station_sid, station_id, 
	station_naam, travel_mode, travel_distance, new_node)
	SELECT CASE WHEN ((2900-stat.node_distance)/weg.length) <= 1
		THEN ST_LineSubstring(weg.geom,0,((2900-stat.node_distance)/weg.length))
		ELSE weg.geom END,
		weg.weg_sid, stat.station_sid, stat.station_id, stat.station_naam, 
		'fiets', 3000, ((2900-stat.node_distance)/weg.length) 
	FROM
		(SELECT * FROM half_segments h WHERE travel_mode = 'fiets' AND travel_distance = 3000) weg,
		(SELECT * FROM street_isochrone_analysis.station_isochrone_nodes 
		WHERE travel_mode = 'fiets' AND node_distance <= 2900 ORDER BY node_distance DESC) stat
	WHERE weg.station_sid = stat.station_sid AND weg.source = stat.node_id
;
-- fiets from target
INSERT INTO street_isochrone_analysis.station_isochrone_wegen_full (geom, weg_sid, station_sid, station_id, 
	station_naam, travel_mode, travel_distance, new_node)
	SELECT CASE WHEN ((2900-stat.node_distance)/weg.length) <= 1 
		THEN ST_LineSubstring(weg.geom,1-((2900-stat.node_distance)/weg.length),1)
		ELSE weg.geom END,
		weg.weg_sid, stat.station_sid, stat.station_id, stat.station_naam, 
		'fiets', 3000, ((2900-stat.node_distance)/weg.length)-1 
	FROM
		(SELECT * FROM half_segments h WHERE travel_mode = 'fiets' AND travel_distance=3000) weg,
		(SELECT * FROM street_isochrone_analysis.station_isochrone_nodes 
		WHERE travel_mode = 'fiets' AND node_distance <= 2900) stat
	WHERE weg.station_sid = stat.station_sid AND weg.target = stat.node_id
;
-- voetganger from source
INSERT INTO street_isochrone_analysis.station_isochrone_wegen_full (geom, weg_sid, station_sid, station_id, 
	station_naam, travel_mode, travel_distance, new_node)
	SELECT CASE WHEN ((700-stat.node_distance)/weg.length) <= 1 
		THEN ST_LineSubstring(weg.geom,0,((700-stat.node_distance)/weg.length))
		ELSE weg.geom END,
		weg.weg_sid, stat.station_sid, stat.station_id, stat.station_naam, 
		'voetganger', 800, ((700-stat.node_distance)/weg.length) 
	FROM
		(SELECT * FROM half_segments h WHERE travel_mode = 'voetganger' AND travel_distance=800) weg,
		(SELECT * FROM street_isochrone_analysis.station_isochrone_nodes 
		WHERE travel_mode = 'voetganger' AND node_distance <= 700) stat
	WHERE weg.station_sid = stat.station_sid AND weg.source = stat.node_id
;
-- voetganger from target
INSERT INTO street_isochrone_analysis.station_isochrone_wegen_full (geom, weg_sid, station_sid, station_id, 
	station_naam, travel_mode, travel_distance, new_node)
	SELECT CASE WHEN ((700-stat.node_distance)/weg.length) <= 1 
		THEN ST_LineSubstring(weg.geom,1-((700-stat.node_distance)/weg.length),1)
		ELSE weg.geom END,
		weg.weg_sid, stat.station_sid, stat.station_id, stat.station_naam, 
		'voetganger', 800, ((700-stat.node_distance)/weg.length)-1
	FROM
		(SELECT * FROM half_segments h WHERE travel_mode = 'voetganger' AND travel_distance=800) weg,
		(SELECT * FROM street_isochrone_analysis.station_isochrone_nodes 
		WHERE travel_mode = 'voetganger' AND node_distance <= 700) stat
	WHERE weg.station_sid = stat.station_sid AND weg.target = stat.node_id
;
-- create buffers for isochrones
-- DROP TABLE street_isochrone_analysis.station_isochrone_buffers_full CASCADE;
CREATE TABLE street_isochrone_analysis.station_isochrone_buffers_full (
	sid serial NOT NULL PRIMARY KEY,
	geom geometry(MultiPolygon,28992),
	station_id character varying,
	station_naam character varying,
	travel_mode character varying, 
	travel_distance integer
);
INSERT INTO street_isochrone_analysis.station_isochrone_buffers_full (geom, station_id, station_naam, 
	travel_mode, travel_distance)
	SELECT ST_Multi(ST_Simplify(ST_Union(ST_Buffer(ST_Simplify(geom,10),100,'quad_segs=2')),20)), 
		station_id, min(station_naam), travel_mode, travel_distance
	FROM street_isochrone_analysis.station_isochrone_wegen_full
	GROUP BY station_id, travel_mode, travel_distance
;
-- create polygons for isochrones
-- DROP TABLE street_isochrone_analysis.station_isochrone_polygons_full CASCADE;
CREATE TABLE street_isochrone_analysis.station_isochrone_polygons_full (
	sid serial NOT NULL PRIMARY KEY,
	geom geometry(Polygon,28992),
	station_id character varying,
	station_naam character varying,
	travel_mode character varying, 
	travel_distance integer
);
INSERT INTO street_isochrone_analysis.station_isochrone_polygons_full (geom, station_id, station_naam, 
	travel_mode, travel_distance)
	SELECT ST_MakePolygon(ST_ExteriorRing((ST_Dump(
		ST_Simplify(ST_Union(ST_Buffer(ST_Simplify(geom,10),100,'quad_segs=2')),20)
	)).geom)), 
		station_id, min(station_naam), travel_mode, travel_distance
	FROM street_isochrone_analysis.station_isochrone_wegen_full
	GROUP BY station_id, travel_mode, travel_distance
;

-- function to remove small holes (inner rings) from polygons.
-- Didn't work on some large ones, and removed the outer polygon.
-- https://geospatial.commons.gc.cuny.edu/2013/11/04/filling-in-holes-with-postgis/
-- https://spatialdbadvisor.com/postgis_tips_tricks/92/filtering-rings-in-polygon-postgis
CREATE OR REPLACE FUNCTION filter_rings(geometry, DOUBLE PRECISION)
  RETURNS geometry AS
$BODY$
SELECT ST_BuildArea(ST_Collect(b.final_geom)) AS filtered_geom
  FROM (SELECT ST_MakePolygon((/* Get outer ring of polygon */
    SELECT ST_ExteriorRing(a.the_geom) AS outer_ring /* ie the outer ring */
    ),  ARRAY(/* Get all inner rings > a particular area */
     SELECT ST_ExteriorRing(b.geom) AS inner_ring
       FROM (SELECT (ST_DumpRings(a.the_geom)).*) b
      WHERE b.path[1] > 0 /* ie not the outer ring */
        AND ST_Area(b.geom) > $2
    ) ) AS final_geom
         FROM (SELECT ST_GeometryN(ST_Multi($1),/*ST_Multi converts any Single Polygons to MultiPolygons */
                                   generate_series(1,ST_NumGeometries(ST_Multi($1)))
                                   ) AS the_geom
               ) a
       ) b
$BODY$
  LANGUAGE 'sql' IMMUTABLE;

