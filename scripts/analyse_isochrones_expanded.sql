-- KPO data system data model
-- author: Jorge Gil, 2017


-- isochrone analysis from public transport stops along the street network
-- this expanded version considers more origins on the road network
-- in some cases the isochrones extend beyond what seems possible without additional pedestrian links/bridges

-- DROP SCHEMA IF EXISTS isochrone_analysis_expanded CASCADE;
CREATE SCHEMA isochrone_analysis_expanded;
ALTER SCHEMA isochrone_analysis_expanded OWNER TO postgres;


---- PREPARATION
-- extract just relevant network for isochrones
-- DROP TABLE isochrone_analysis_expanded.wegen CASCADE;
CREATE TABLE isochrone_analysis_expanded.wegen AS
	SELECT *
	FROM networks.t10_wegen 
	WHERE fiets = TRUE OR fiets IS NULL 
	OR voetganger = TRUE OR voetganger IS NULL
;
-- prepare topology
-- ALTER TABLE isochrone_analysis_expanded.wegen DROP COLUMN source, DROP COLUMN target;
ALTER TABLE isochrone_analysis_expanded.wegen ADD COLUMN source integer, ADD COLUMN target integer;
-- build the network topology
SELECT pgr_createTopology('isochrone_analysis_expanded.wegen', 0.01, 'geom', 'sid');
-- connect Amsterdam Centraal ferries to the road network, by assigning new source/target ids
-- DROP TABLE free_ferry CASCADE;
CREATE TEMP TABLE free_ferry AS
	SELECT * FROM isochrone_analysis_expanded.wegen
	WHERE type_weg = 'veerverbinding' AND ST_DWithin(geom,
		(SELECT geom FROM networks.ov_stop_areas WHERE area_name = 'Amsterdam Centraal'),3000)
;
-- DROP TABLE new_ferry_nodes CASCADE;
CREATE TEMP TABLE new_ferry_nodes AS (
	SELECT DISTINCT ON (ferry_nodes.id) ferry_nodes.id, road_nodes.id road_node, 
		ST_Distance(ferry_nodes.the_geom, road_nodes.the_geom) dist
	FROM (
		SELECT * FROM isochrone_analysis_expanded.wegen_vertices_pgr vert
		WHERE NOT EXISTS 
			(SELECT 1 FROM free_ferry f WHERE f.source=vert.id OR f.target=vert.id)
	) road_nodes, (
		SELECT * FROM isochrone_analysis_expanded.wegen_vertices_pgr vert, free_ferry f
		WHERE f.source=vert.id OR f.target=vert.id
	) ferry_nodes
	WHERE ST_DWithin(ferry_nodes.the_geom, road_nodes.the_geom,200) 
	ORDER BY ferry_nodes.id, dist
);
UPDATE isochrone_analysis_expanded.wegen ferry SET
	source = road_node
	FROM new_ferry_nodes
	WHERE ferry.t10_id in (SELECT t10_id FROM free_ferry)
	AND ferry.source = new_ferry_nodes.id
;
UPDATE isochrone_analysis_expanded.wegen ferry SET
	target = road_node
	FROM new_ferry_nodes
	WHERE ferry.t10_id in (SELECT t10_id FROM free_ferry)
	AND ferry.target = new_ferry_nodes.id
;
CREATE INDEX wegen_geom_idx ON isochrone_analysis_expanded.wegen USING GIST (geom);
CREATE INDEX wegen_vertices_geom_idx ON isochrone_analysis_expanded.wegen_vertices_pgr USING GIST (the_geom);

-----
-- link stations and stops to streets
-- DROP TABLE isochrone_analysis_expanded.origin_stops CASCADE;
CREATE TABLE isochrone_analysis_expanded.origin_stops (
	sid serial NOT NULL PRIMARY KEY,
	geom geometry(Point,28992),
	stop_id character varying,
	stop_name character varying,
	stop_mode character varying,
	weg_sid integer,
	weg_dist double precision,
	weg_length double precision,
	weg_point_location double precision,
	source_id integer,
	target_id integer
);
-- train and metro stations to any node within 150m. since there's no exact entrance location this is an estimation
-- add wegen within radius
INSERT INTO isochrone_analysis_expanded.origin_stops (stop_id, geom, stop_name, stop_mode,
	weg_sid, weg_length, weg_dist, weg_point_location, source_id, target_id)
	SELECT DISTINCT ON(stops.stop_id, weg.sid, weg.source, weg.target) stops.stop_id, 
		ST_ClosestPoint(weg.geom, stops.geom), stops.stop_name, 
		CASE 
			WHEN trein = TRUE THEN 'trein'
			WHEN metro = TRUE THEN 'metro'
		END,
		weg.sid, weg.length,
		ST_Distance(stops.geom, weg.geom) dist, 
		ST_LineLocatePoint(weg.geom, ST_GeometryN(stops.geom, 1)),
		weg.source, weg.target
	FROM (
		SELECT * FROM networks.ov_stops
		WHERE parent_station IS NULL
		AND (trein = TRUE OR metro = TRUE)
	) stops, isochrone_analysis_expanded.wegen weg
	WHERE ST_DWithin(stops.geom, weg.geom, 150)
	ORDER BY stops.stop_id, weg.sid, weg.source, weg.target, dist ASC
;
-- other stops links 2 nearest (non connected) streets
-- add closest weg
INSERT INTO isochrone_analysis_expanded.origin_stops (stop_id, geom, stop_name, stop_mode,
	weg_sid, weg_length, weg_dist, weg_point_location, source_id, target_id)
	SELECT DISTINCT ON(stops.stop_id) stops.stop_id, 
		ST_ClosestPoint(weg.geom, stops.geom), stops.stop_name, 
		CASE 
			WHEN tram = TRUE THEN 'tram'
			WHEN bus = TRUE THEN 'bus'
		END,
		weg.sid, weg.length,
		ST_Distance(stops.geom, weg.geom) dist, 
		ST_LineLocatePoint(weg.geom, ST_GeometryN(stops.geom, 1)),
		weg.source, weg.target
	FROM (
		SELECT * FROM networks.ov_stops
		WHERE parent_station IS NULL
		AND (tram = TRUE OR bus = TRUE)
	) stops, isochrone_analysis.wegen weg
	WHERE ST_DWithin(stops.geom, weg.geom, 100)
	ORDER BY stops.stop_id, dist ASC
;
-- add second closest weg, not in the list, nor connected to one already in the list
INSERT INTO isochrone_analysis_expanded.origin_stops (stop_id, geom, stop_name, stop_mode,
	weg_sid, weg_length, weg_dist, weg_point_location, source_id, target_id)
	SELECT DISTINCT ON(stops.stop_id) stops.stop_id, 
		ST_ClosestPoint(weg.geom, stops.geom), stops.stop_name,
		CASE 
			WHEN tram = TRUE THEN 'tram'
			WHEN bus = TRUE THEN 'bus'
		END,
		weg.sid, weg.length,
		ST_Distance(stops.geom, weg.geom) dist, 
		ST_LineLocatePoint(weg.geom, ST_GeometryN(stops.geom, 1)),
		weg.source, weg.target
	FROM (
		SELECT * FROM networks.ov_stops
		WHERE parent_station IS NULL
		AND (tram = TRUE OR bus = TRUE)
	) stops, isochrone_analysis.wegen weg
	WHERE ST_DWithin(stops.geom, weg.geom, 100)
	AND NOT EXISTS (SELECT 1 FROM isochrone_analysis.origin_stops a 
		WHERE a.stop_id = stops.stop_id AND a.weg_sid = weg.sid)
	AND NOT EXISTS (SELECT 1 FROM isochrone_analysis.origin_stops a 
		WHERE a.stop_id = stops.stop_id AND a.source_id = weg.target)
	AND NOT EXISTS (SELECT 1 FROM isochrone_analysis.origin_stops a 
		WHERE a.stop_id = stops.stop_id AND a.source_id = weg.source)
	AND NOT EXISTS (SELECT 1 FROM isochrone_analysis.origin_stops a 
		WHERE a.stop_id = stops.stop_id AND a.target_id = weg.target)
	AND NOT EXISTS (SELECT 1 FROM isochrone_analysis.origin_stops a 
		WHERE a.stop_id = stops.stop_id AND a.target_id = weg.source)
	ORDER BY stops.stop_id, dist ASC
;
-- create indices for possibly faster searches
CREATE INDEX origins_stops_idx ON isochrone_analysis_expanded.origin_stops (stop_id);
CREATE INDEX origins_weg_idx ON isochrone_analysis_expanded.origin_stops (weg_sid);
CREATE INDEX origins_source_idx ON isochrone_analysis_expanded.origin_stops (source_id);
CREATE INDEX origins_target_idx ON isochrone_analysis_expanded.origin_stops (target_id);


----- CALCULATE street network distances to every stop
-- this is needed for walk, cycling, ov isochrones and for PTAL
-- stations - 800m walking, 3000m cycling
-- metro - 800m walking
-- bus and tram - 400m walking
-- calculated distances are 100m shorter because a 100m buffer is used at the end of the process
-- DROP TABLE isochrone_analysis_expanded.isochrone_nodes CASCADE;
CREATE TABLE isochrone_analysis_expanded.isochrone_nodes(
	sid bigserial NOT NULL PRIMARY KEY,
	origin_id integer,
	travel_mode varchar,
	node_id integer,
	node_distance double precision
);
-- cycling for 3000m
-- DROP TABLE wegen_fiets CASCADE;
CREATE TEMP TABLE wegen_fiets AS (
	SELECT * FROM isochrone_analysis_expanded.wegen WHERE fiets IS NULL OR fiets = True
);
-- DELETE FROM analysis.isochrone_nodes WHERE travel_mode = 'fiets';
INSERT INTO isochrone_analysis_expanded.isochrone_nodes (origin_id, travel_mode, node_id, node_distance)
	SELECT origin.id, 'fiets', (origin.catchment).id1, (origin.catchment).cost
		FROM (
			SELECT a.id, pgr_drivingDistance(
				'SELECT sid AS id, source, target, length AS cost FROM wegen_fiets',
				a.id::integer, 2900.0, false, false
			) catchment
			FROM (
				SELECT * FROM isochrone_analysis_expanded.wegen_vertices_pgr v
				WHERE EXISTS (SELECT 1 FROM wegen_fiets WHERE source=v.id OR target=v.id)
				AND EXISTS (SELECT 1 FROM isochrone_analysis_expanded.origin_stops 
				WHERE stop_mode = 'trein' AND (source_id=v.id OR target_id=v.id)) 
			) a
		) origin
;
-- walking for 800m
-- DROP TABLE wegen_walk CASCADE;
CREATE TEMP TABLE wegen_walk AS (
	SELECT * FROM isochrone_analysis_expanded.wegen WHERE voetganger IS NULL OR voetganger = True
);
-- DELETE FROM isochrone_analysis_expanded.isochrone_nodes WHERE travel_mode = 'walk';
INSERT INTO isochrone_analysis_expanded.isochrone_nodes (origin_id, travel_mode, node_id, node_distance)
	SELECT origin.id, 'walk', (origin.catchment).id1, (origin.catchment).cost
		FROM (
			SELECT a.id, pgr_drivingDistance(
				'SELECT sid AS id, source, target, length AS cost FROM wegen_walk',
				a.id::integer, 700.0, false, false
			) catchment
			FROM (
				SELECT * FROM isochrone_analysis_expanded.wegen_vertices_pgr v
				WHERE EXISTS (SELECT 1 FROM wegen_walk WHERE source=v.id OR target=v.id)
				AND EXISTS (SELECT 1 FROM isochrone_analysis_expanded.origin_stops 
				WHERE stop_mode IN ('trein','metro') AND (source_id=v.id OR target_id=v.id))
			) a
		) origin
;
-- walking for 400m
INSERT INTO isochrone_analysis_expanded.isochrone_nodes (origin_id, travel_mode, node_id, node_distance)
	SELECT origin.id, 'walk', (origin.catchment).id1, (origin.catchment).cost
		FROM (
			SELECT a.id, pgr_drivingDistance(
				'SELECT sid AS id, source, target, length AS cost FROM wegen_walk',
				a.id::integer, 300.0, false, false
			) catchment
			FROM (
				SELECT * FROM isochrone_analysis_expanded.wegen_vertices_pgr v
				WHERE EXISTS (SELECT 1 FROM wegen_walk WHERE source=v.id OR target=v.id)
				AND EXISTS (SELECT 1 FROM isochrone_analysis_expanded.origin_stops 
				WHERE stop_mode IN ('tram','bus') AND (source_id=v.id OR target_id=v.id))
			) a
		) origin
;
-- DROP INDEX isochrone_analysis_expanded.isochrone_nodes_node_distance_idx;
CREATE INDEX isochrone_nodes_node_distance_idx ON isochrone_analysis_expanded.isochrone_nodes (node_distance);


----- CREATE ISOCHRONES from stations
-- 800m walking, 3000m cycling
-- identify isochrone nodes per station
-- DROP TABLE isochrone_analysis_expanded.station_isochrone_nodes CASCADE;
CREATE TABLE isochrone_analysis_expanded.station_isochrone_nodes (
	sid serial NOT NULL PRIMARY KEY,
	geom geometry(Point, 28992),
	station_id varchar,
	station_name varchar,
	station_mode varchar,
	travel_mode varchar,
	node_id integer,
	node_distance double precision
);
-- insert cycling nodes
-- DROP TABLE fiets_isochrone_nodes CASCADE;
CREATE TEMP TABLE fiets_isochrone_nodes AS
	SELECT stat.stop_id, stat.stop_name, stat.stop_mode, nodes.travel_mode, nodes.node_id,
		(nodes.node_distance + (stat.weg_length*stat.weg_point_location) + stat.weg_dist) node_distance
		FROM (
			SELECT * FROM isochrone_analysis_expanded.origin_stops WHERE stop_mode = 'trein'
		) stat, (
			SELECT * FROM isochrone_analysis_expanded.isochrone_nodes WHERE travel_mode = 'fiets'
		) nodes
		WHERE stat.source_id = nodes.origin_id 
		AND (nodes.node_distance + (stat.weg_length*stat.weg_point_location) + stat.weg_dist) <= 2900
;
INSERT INTO fiets_isochrone_nodes
	SELECT stat.stop_id, stat.stop_name, stat.stop_mode, nodes.travel_mode, nodes.node_id,
		(nodes.node_distance + (stat.weg_length*(1-stat.weg_point_location)) + stat.weg_dist) node_distance		
		FROM (
			SELECT * FROM isochrone_analysis_expanded.origin_stops WHERE stop_mode = 'trein'
		) stat, (
			SELECT * FROM isochrone_analysis_expanded.isochrone_nodes WHERE travel_mode = 'fiets'
		) nodes
		WHERE stat.target_id = nodes.origin_id 
		AND (nodes.node_distance + (stat.weg_length*(1-stat.weg_point_location)) + stat.weg_dist) <= 2900
;
-- group the above by station keeping only the minimum node_distance
-- DELETE FROM isochrone_analysis_expanded.station_isochrone_nodes WHERE travel_mode = 'fiets';
INSERT INTO isochrone_analysis_expanded.station_isochrone_nodes (station_id, station_name, station_mode, 
		travel_mode, node_id, node_distance)
	SELECT stop_id, stop_name, stop_mode, travel_mode, node_id, min(node_distance)
	FROM fiets_isochrone_nodes
	GROUP BY stop_id, stop_name, stop_mode, travel_mode, node_id
;
-- insert walk nodes
-- DROP TABLE walk_isochrone_nodes CASCADE;
CREATE TEMP TABLE walk_isochrone_nodes AS
	SELECT stat.stop_id, stat.stop_name, stat.stop_mode, nodes.travel_mode, nodes.node_id,
		(nodes.node_distance + (stat.weg_length*stat.weg_point_location) + stat.weg_dist) node_distance
		FROM (
			SELECT * FROM isochrone_analysis_expanded.origin_stops WHERE stop_mode = 'trein'
		) stat, (
			SELECT * FROM isochrone_analysis_expanded.isochrone_nodes WHERE travel_mode = 'walk'
		) nodes
		WHERE stat.source_id = nodes.origin_id 
		AND (nodes.node_distance + (stat.weg_length*stat.weg_point_location) + stat.weg_dist) <= 700
;
INSERT INTO walk_isochrone_nodes
	SELECT stat.stop_id, stat.stop_name, stat.stop_mode, nodes.travel_mode, nodes.node_id,
		(nodes.node_distance + (stat.weg_length*(1-stat.weg_point_location)) + stat.weg_dist) node_distance		
		FROM (
			SELECT * FROM isochrone_analysis_expanded.origin_stops WHERE stop_mode = 'trein'
		) stat, (
			SELECT * FROM isochrone_analysis_expanded.isochrone_nodes WHERE travel_mode = 'walk'
		) nodes
		WHERE stat.target_id = nodes.origin_id 
		AND (nodes.node_distance + (stat.weg_length*(1-stat.weg_point_location)) + stat.weg_dist) <= 700
;
-- group the above by station keeping only the minimum node_distance
-- DELETE FROM isochrone_analysis_expanded.station_isochrone_nodes WHERE travel_mode = 'walk';
INSERT INTO isochrone_analysis_expanded.station_isochrone_nodes (station_id, station_name, station_mode,
		travel_mode, node_id, node_distance)
	SELECT stop_id, stop_name, stop_mode, travel_mode, node_id, min(node_distance)
	FROM walk_isochrone_nodes
	GROUP BY stop_id, stop_name, stop_mode, travel_mode, node_id
;
-- add geometry
UPDATE isochrone_analysis_expanded.station_isochrone_nodes stat SET geom=vrt.the_geom
	FROM isochrone_analysis_expanded.wegen_vertices_pgr vrt
	WHERE stat.node_id = vrt.id
;
-- DROP INDEX isochrone_nodes_geom_idx;
CREATE INDEX station_isochrone_nodes_geom_idx ON isochrone_analysis_expanded.station_isochrone_nodes USING GIST (geom);
CREATE INDEX station_isochrone_nodes_station_sid_idx ON isochrone_analysis_expanded.station_isochrone_nodes (station_id);
CREATE INDEX station_isochrone_nodes_node_id_idx ON isochrone_analysis_expanded.station_isochrone_nodes (node_id);


----- CREATE ISOCHRONES from road segments
-- add wegen entirely within isochrone distances
-- DROP TABLE isochrone_analysis_expanded.station_isochrone_wegen CASCADE;
CREATE TABLE isochrone_analysis_expanded.station_isochrone_wegen (
	sid serial NOT NULL PRIMARY KEY,
	geom geometry(Linestring, 28992),
	weg_sid integer,
	station_id varchar,
	station_name varchar,
	station_mode varchar,
	travel_mode varchar,
	travel_distance integer,
	new_node double precision
);
INSERT INTO isochrone_analysis_expanded.station_isochrone_wegen (geom, weg_sid, station_id, 
	station_name, station_mode, travel_mode, travel_distance)
	SELECT weg.geom, weg.sid, stat.stop_id, stat.stop_name, 'trein', 'fiets', 3000
	FROM (
		SELECT * FROM networks.ov_stops
		WHERE parent_station IS NULL
		AND trein = TRUE
	) stat, isochrone_analysis_expanded.wegen weg 
	WHERE EXISTS (SELECT 1 FROM isochrone_analysis_expanded.station_isochrone_nodes f 
		WHERE travel_mode = 'fiets' AND station_mode = 'trein'
		AND node_distance <= 2900 AND f.station_id = stat.stop_id
		AND f.node_id = weg.source)
	AND EXISTS (SELECT 1 FROM isochrone_analysis_expanded.station_isochrone_nodes f 	
		WHERE travel_mode = 'fiets' AND station_mode = 'trein'
		AND node_distance <= 2900 AND f.station_id = stat.stop_id
		AND f.node_id = weg.target)
;
INSERT INTO isochrone_analysis_expanded.station_isochrone_wegen (geom, weg_sid, station_id, 
	station_name, station_mode, travel_mode, travel_distance)
	SELECT weg.geom, weg.sid, stat.stop_id, stat.stop_name, 'trein', 'walk', 800
	FROM (
		SELECT * FROM networks.ov_stops
		WHERE parent_station IS NULL
		AND trein = TRUE
	) stat, isochrone_analysis_expanded.wegen weg 
	WHERE EXISTS (SELECT 1 FROM isochrone_analysis_expanded.station_isochrone_nodes f 
		WHERE travel_mode = 'walk' AND station_mode = 'trein'
		AND node_distance <= 700 AND f.station_id = stat.stop_id
		AND f.node_id = weg.source)
	AND EXISTS (SELECT 1 FROM isochrone_analysis_expanded.station_isochrone_nodes f 	
		WHERE travel_mode = 'walk' AND station_mode = 'trein'
		AND node_distance <= 700 AND f.station_id = stat.stop_id
		AND f.node_id = weg.target)
;
CREATE INDEX station_isochrone_wegen_geom_idx ON isochrone_analysis_expanded.station_isochrone_wegen USING GIST (geom);
CREATE INDEX station_isochrone_wegen_idx ON isochrone_analysis_expanded.station_isochrone_wegen (station_id, travel_mode, travel_distance);
-- add road segment chunks calculated with linear referencing
-- identify segments intersecting isochrone limits
-- DROP TABLE half_segments CASCADE;
CREATE TEMP TABLE half_segments AS SELECT
		weg.geom, weg.sid AS weg_sid, stat.stop_id AS station_id, stat.stop_name AS station_name, 
		'trein'::varchar AS station_mode, 'fiets'::varchar AS travel_mode, 3000::integer AS travel_distance,
		weg.length, weg.source, weg.target
	FROM (
		SELECT * FROM networks.ov_stops
		WHERE parent_station IS NULL
		AND trein = TRUE
	) stat, isochrone_analysis_expanded.wegen weg 
	WHERE (EXISTS (
		SELECT 1 FROM isochrone_analysis_expanded.station_isochrone_nodes f 
		WHERE travel_mode = 'fiets' AND station_mode = 'trein'
		AND node_distance <= 2900 AND f.station_id = stat.stop_id
		AND f.node_id = weg.source)
	OR EXISTS (
		SELECT 1 FROM isochrone_analysis_expanded.station_isochrone_nodes f 	
		WHERE travel_mode = 'fiets' AND station_mode = 'trein'
		AND node_distance <= 2900 AND f.station_id = stat.stop_id
		AND f.node_id = weg.target))
	AND NOT EXISTS (
		SELECT 1 FROM isochrone_analysis_expanded.station_isochrone_wegen a
		WHERE a.weg_sid = weg.sid 
		AND a.station_id = stat.stop_id
		AND a.station_mode = 'trein'
		AND a.travel_mode = 'fiets' 
		AND a.travel_distance = 3000
	)
;
INSERT INTO half_segments (geom, weg_sid, station_id, station_name, station_mode, 
		travel_mode, travel_distance, length, source, target)
	SELECT weg.geom, weg.sid, stat.stop_id, stat.stop_name, 'trein', 'walk', 800,
		weg.length, weg.source, weg.target
	FROM (
		SELECT * FROM networks.ov_stops
		WHERE parent_station IS NULL
		AND trein = TRUE
	) stat, isochrone_analysis_expanded.wegen weg 
	WHERE (EXISTS (
		SELECT 1 FROM isochrone_analysis_expanded.station_isochrone_nodes f 
		WHERE travel_mode = 'walk' AND station_mode = 'trein'
		AND node_distance <= 700 AND f.station_id = stat.stop_id
		AND f.node_id = weg.source)
	OR EXISTS (
		SELECT 1 FROM isochrone_analysis_expanded.station_isochrone_nodes f 	
		WHERE travel_mode = 'walk' AND station_mode = 'trein'
		AND node_distance <= 700 AND f.station_id = stat.stop_id
		AND f.node_id = weg.target))
	AND NOT EXISTS (
		SELECT 1 FROM isochrone_analysis_expanded.station_isochrone_wegen a
		WHERE a.weg_sid = weg.sid 
		AND a.station_id = stat.stop_id
		AND a.station_mode = 'trein'
		AND a.travel_mode = 'walk' 
		AND a.travel_distance = 800
	)
;
-- calculate partial segments with linear referencing 
-- fiets from source
INSERT INTO isochrone_analysis_expanded.station_isochrone_wegen (geom, weg_sid, station_id, station_name, 
		station_mode, travel_mode, travel_distance, new_node)
	SELECT CASE WHEN ((2900-stat.node_distance)/weg.length) <= 1
		THEN ST_LineSubstring(weg.geom,0,((2900-stat.node_distance)/weg.length))
		ELSE weg.geom END,
		weg.weg_sid, stat.station_id, stat.station_name, stat.station_mode,
		'fiets', 3000, ((2900-stat.node_distance)/weg.length) 
	FROM
		(SELECT * FROM half_segments h WHERE travel_mode = 'fiets' AND station_mode = 'trein'
		AND travel_distance = 3000) weg,
		(SELECT * FROM isochrone_analysis_expanded.station_isochrone_nodes 
		WHERE travel_mode = 'fiets' AND station_mode = 'trein' 
		AND node_distance <= 2900 ORDER BY node_distance DESC) stat
	WHERE weg.station_id = stat.station_id AND weg.source = stat.node_id
;
-- fiets from target
INSERT INTO isochrone_analysis_expanded.station_isochrone_wegen (geom, weg_sid, station_id, station_name, 
		station_mode, travel_mode, travel_distance, new_node)
	SELECT CASE WHEN ((2900-stat.node_distance)/weg.length) <= 1 
		THEN ST_LineSubstring(weg.geom,1-((2900-stat.node_distance)/weg.length),1)
		ELSE weg.geom END,
		weg.weg_sid, stat.station_id, stat.station_name, stat.station_mode, 
		'fiets', 3000, ((2900-stat.node_distance)/weg.length)-1 
	FROM
		(SELECT * FROM half_segments h WHERE travel_mode = 'fiets' AND station_mode = 'trein'
		AND travel_distance=3000) weg,
		(SELECT * FROM isochrone_analysis_expanded.station_isochrone_nodes 
		WHERE travel_mode = 'fiets' AND station_mode = 'trein'
		AND node_distance <= 2900) stat
	WHERE weg.station_id = stat.station_id AND weg.target = stat.node_id
;
-- walk from source
INSERT INTO isochrone_analysis_expanded.station_isochrone_wegen (geom, weg_sid, station_id, station_name, 
		station_mode, travel_mode, travel_distance, new_node)
	SELECT CASE WHEN ((700-stat.node_distance)/weg.length) <= 1 
		THEN ST_LineSubstring(weg.geom,0,((700-stat.node_distance)/weg.length))
		ELSE weg.geom END,
		weg.weg_sid, stat.station_id, stat.station_name, stat.station_mode, 
		'walk', 800, ((700-stat.node_distance)/weg.length) 
	FROM
		(SELECT * FROM half_segments h WHERE travel_mode = 'walk' AND station_mode = 'trein'
		AND travel_distance=800) weg,
		(SELECT * FROM isochrone_analysis_expanded.station_isochrone_nodes 
		WHERE travel_mode = 'walk' AND station_mode = 'trein' 
		AND node_distance <= 700) stat
	WHERE weg.station_id = stat.station_id AND weg.source = stat.node_id
;
-- walk from target
INSERT INTO isochrone_analysis_expanded.station_isochrone_wegen(geom, weg_sid, station_id, station_name, 
		station_mode, travel_mode, travel_distance, new_node)
	SELECT CASE WHEN ((700-stat.node_distance)/weg.length) <= 1 
		THEN ST_LineSubstring(weg.geom,1-((700-stat.node_distance)/weg.length),1)
		ELSE weg.geom END,
		weg.weg_sid, stat.station_id, stat.station_name, stat.station_mode, 
		'walk', 800, ((700-stat.node_distance)/weg.length)-1
	FROM
		(SELECT * FROM half_segments h WHERE travel_mode = 'walk' AND station_mode = 'trein'
		AND travel_distance=800) weg,
		(SELECT * FROM isochrone_analysis_expanded.station_isochrone_nodes 
		WHERE travel_mode = 'walk' AND station_mode = 'trein' 
		AND node_distance <= 700) stat
	WHERE weg.station_id = stat.station_id AND weg.target = stat.node_id
;


-----
-- OV ISOCHRONE ANALYSIS, from rail stations, using bus, tram or metro
-- bus, tram, metro + 400m walking (max)


---- PREPARATION
-- ov_analysis.ov_links_frequency has the network topology per mode, with average duration on link

-- identify origin stops part of station areas
-- DROP TABLE isochrone_analysis_expanded.ov_origins CASCADE;
CREATE TABLE isochrone_analysis_expanded.ov_origins (
	sid serial NOT NULL PRIMARY KEY,
	geom geometry(Point, 28992),
	station_sid integer,
	station_naam character varying,
	stop_id character varying,
	stop_naam character varying,
	stop_mode character varying
);
INSERT INTO isochrone_analysis_expanded.ov_origins (geom, station_sid, station_naam, stop_id,
		stop_naam, stop_mode)
	SELECT stop.geom, station.sid, station.area_name, stop.stop_id, stop.stop_name,
		CASE 
			WHEN stop.metro = TRUE THEN 'metro'
			WHEN stop.tram = TRUE THEN 'tram'
			WHEN stop.bus = TRUE THEN 'bus'
		END AS stop_mode
	FROM (
		SELECT * FROM networks.ov_stop_areas WHERE sid IN
			(SELECT stop_area FROM networks.ov_stops 
			WHERE trein IS TRUE AND parent_station IS NOT NULL
			GROUP BY stop_area ORDER BY stop_area)
	) AS station
	JOIN (
		SELECT * FROM networks.ov_stops 
		WHERE parent_station IS NULL AND stop_area IS NOT NULL 
		AND trein IS NULL AND veerboot IS NULL
	) AS stop
	ON (station.sid = stop.stop_area)
	ORDER BY alt_name
;

-- OV isochrone nodes are the destinations within 10 minutes
-- DROP TABLE isochrone_analysis_expanded.ov_isochrone_nodes CASCADE;
CREATE TABLE isochrone_analysis_expanded.ov_isochrone_nodes(
	sid serial NOT NULL PRIMARY KEY,
	station_sid integer,
	station_name character varying,
	stop_id character varying,
	travel_mode character varying,
	node_id integer,
	node_distance double precision
);
-- bus isochrones 10 minutes = 600 seconds
-- DROP TABLE network_bus CASCADE;
CREATE TEMP TABLE network_bus AS (
	SELECT * FROM ov_analysis.ov_links_frequency WHERE trip_mode = 'bus' AND freq_avondspits > 0
);
-- DELETE FROM isochrone_analysis_expanded.ov_isochrone_nodes WHERE travel_mode = 'bus';
INSERT INTO isochrone_analysis_expanded.ov_isochrone_nodes (station_sid, station_name, stop_id, travel_mode, node_id, node_distance)
	SELECT origin.station_sid, origin.station_naam, origin.stop_id, 'bus', (origin.catchment).id1, (origin.catchment).cost
		FROM (
			SELECT a.station_sid, a.station_naam, a.stop_id, pgr_drivingDistance(
				'SELECT sid AS id, start_stop_id::int AS source, end_stop_id::int AS target, 
				mean_duration_in_secs::float AS cost 
				FROM network_bus',
				a.stop_id::integer, 600.0, false, false
			) catchment
			FROM (SELECT * FROM isochrone_analysis_expanded.ov_origins s
				WHERE stop_mode = 'bus'
				AND EXISTS (SELECT 1 FROM network_bus 
				WHERE start_stop_id=s.stop_id OR end_stop_id=s.stop_id)) a
		) origin
	WHERE origin.stop_id::integer != (origin.catchment).id1
;
-- tram isochrones 10 minutes = 600 seconds
-- DROP TABLE network_tram CASCADE;
CREATE TEMP TABLE network_tram AS (
	SELECT * FROM ov_analysis.ov_links_frequency WHERE trip_mode = 'tram' AND freq_avondspits > 0
);
-- DELETE FROM isochrone_analysis_expanded.ov_isochrone_nodes WHERE travel_mode = 'tram';
INSERT INTO isochrone_analysis_expanded.ov_isochrone_nodes (station_sid, station_name, stop_id, travel_mode, node_id, node_distance)
	SELECT origin.station_sid, origin.station_naam, origin.stop_id, 'tram', (origin.catchment).id1, (origin.catchment).cost
		FROM (
			SELECT a.station_sid, a.station_naam, a.stop_id, pgr_drivingDistance(
				'SELECT sid AS id, start_stop_id::int AS source, end_stop_id::int AS target, 
				mean_duration_in_secs::float AS cost 
				FROM network_tram',
				a.stop_id::integer, 600.0, false, false
			) catchment
			FROM (SELECT * FROM isochrone_analysis_expanded.ov_origins s
				WHERE stop_mode = 'tram'
				AND EXISTS (SELECT 1 FROM network_tram 
				WHERE start_stop_id=s.stop_id OR end_stop_id=s.stop_id)) a
		) origin
	WHERE origin.stop_id::integer != (origin.catchment).id1
;
-- metro isochrones 10 minutes = 600 seconds
-- DROP TABLE network_metro CASCADE;
CREATE TEMP TABLE network_metro AS (
	SELECT * FROM ov_analysis.ov_links_frequency WHERE trip_mode = 'metro' AND freq_avondspits > 0
);
-- DELETE FROM isochrone_analysis_expanded.ov_isochrone_nodes WHERE travel_mode = 'metro';
INSERT INTO isochrone_analysis_expanded.ov_isochrone_nodes (station_sid, station_name, stop_id, travel_mode, node_id, node_distance)
	SELECT origin.station_sid, origin.station_naam, origin.stop_id, 'metro',(origin.catchment).id1, (origin.catchment).cost
		FROM (
			SELECT a.station_sid, a.station_naam, a.stop_id, pgr_drivingDistance(
				'SELECT sid AS id, start_stop_id::int AS source, end_stop_id::int AS target, 
				mean_duration_in_secs::float AS cost 
				FROM network_metro',
				a.stop_id::integer, 600.0, false, false
			) catchment
			FROM (SELECT * FROM isochrone_analysis_expanded.ov_origins s
				WHERE stop_mode = 'metro'
				AND EXISTS (SELECT 1 FROM network_metro 
				WHERE start_stop_id=s.stop_id OR end_stop_id=s.stop_id)) a
		) origin
	WHERE origin.stop_id::integer != (origin.catchment).id1
;

-- Eliminate destinations that fall within the 10 minute walk distance from a station
DELETE FROM isochrone_analysis_expanded.ov_isochrone_nodes AS ov_nodes WHERE
	ov_nodes.node_id::text IN (SELECT stop_id FROM
		isochrone_analysis_expanded.origin_stops AS origins, 
		(
			SELECT station_name, node_id
			FROM isochrone_analysis_expanded.station_isochrone_nodes
			WHERE travel_mode = 'walk'
			AND node_distance <= 800
		) AS station_nodes
		WHERE ov_nodes.station_name = station_nodes.station_name
		AND (origins.source_id = station_nodes.node_id 
		OR origins.target_id = station_nodes.node_id)
	)
;
-- Extract street isochrone nodes per destination, that are within 5 minute walk from stop
-- (and are not within 10 minute walk from station)
-- DROP TABLE isochrone_analysis_expanded.stop_isochrone_nodes CASCADE;
CREATE TABLE isochrone_analysis_expanded.stop_isochrone_nodes(
	sid serial NOT NULL PRIMARY KEY,
	geom geometry(Point, 28992),
	station_name varchar,
	stop_id varchar,
	stop_mode varchar,
	node_id integer,
	node_distance double precision
);
-- insert walk nodes
-- from source of stop
-- DROP TABLE walk_isochrone_nodes CASCADE;
CREATE TEMP TABLE walk_isochrone_nodes AS
	SELECT stops.station_name, stops.stop_id, stops.travel_mode, nodes.node_id,
		(nodes.node_distance + (stops.weg_length*stops.weg_point_location) + stops.weg_dist) node_distance
	FROM (
		SELECT ov_nodes.station_name, ov_nodes.node_id AS stop_id, ov_nodes.travel_mode,
			origins.weg_length, origins.weg_dist, origins.weg_point_location, origins.source_id, origins.target_id
		FROM isochrone_analysis_expanded.origin_stops AS origins,
		isochrone_analysis_expanded.ov_isochrone_nodes AS ov_nodes
		WHERE ov_nodes.node_id = origins.stop_id::integer
	) AS stops,
	(
		SELECT * FROM isochrone_analysis_expanded.isochrone_nodes 
		WHERE travel_mode = 'walk' AND node_distance <= 300
	) AS nodes
	WHERE nodes.origin_id = stops.source_id 
	AND (nodes.node_distance + (stops.weg_length*stops.weg_point_location) + stops.weg_dist) <= 300
;
-- from target of stop
INSERT INTO walk_isochrone_nodes 
	SELECT stops.station_name, stops.stop_id, stops.travel_mode, nodes.node_id,
		(nodes.node_distance + (stops.weg_length*(1-stops.weg_point_location)) + stops.weg_dist) node_distance
	FROM (
		SELECT ov_nodes.station_name, ov_nodes.node_id AS stop_id, ov_nodes.travel_mode,
			origins.weg_length, origins.weg_dist, origins.weg_point_location, origins.source_id, origins.target_id
		FROM isochrone_analysis_expanded.origin_stops AS origins,
		isochrone_analysis_expanded.ov_isochrone_nodes AS ov_nodes
		WHERE ov_nodes.node_id = origins.stop_id::integer
	) AS stops,
	(
		SELECT * FROM isochrone_analysis_expanded.isochrone_nodes 
		WHERE travel_mode = 'walk' AND node_distance <= 300
	) AS nodes
	WHERE nodes.origin_id = stops.target_id 
	AND (nodes.node_distance + (stops.weg_length*(1-stops.weg_point_location)) + stops.weg_dist) <= 300
;
-- group the above by station and stop keeping only the minimum node_distance
INSERT INTO isochrone_analysis_expanded.stop_isochrone_nodes (station_name, stop_id, stop_mode, node_id, node_distance)
	SELECT station_name, stop_id, travel_mode, node_id, min(node_distance)
	FROM walk_isochrone_nodes
	GROUP BY station_name, stop_id, travel_mode, node_id
;
-- add geometry
UPDATE isochrone_analysis_expanded.stop_isochrone_nodes stop SET geom=vrt.the_geom
	FROM isochrone_analysis_expanded.wegen_vertices_pgr vrt
	WHERE stop.node_id = vrt.id
;
-- remove parts within walking distance from stations
DELETE FROM isochrone_analysis_expanded.stop_isochrone_nodes AS nodes WHERE 
	ST_Intersects(nodes.geom, (SELECT geom 
		FROM datasysteem.isochronen_expanded iso
		WHERE iso.halte_modaliteit = 'trein' 
		AND iso.modaliteit = 'walk' 
		AND iso.isochroon_afstand <= 800
		AND iso.halte_naam = nodes.station_name)
	)
;


----- CREATE ISOCHRONES from road segments
-- DROP TABLE isochrone_analysis_expanded.stop_isochrone_wegen CASCADE;
CREATE TABLE isochrone_analysis_expanded.stop_isochrone_wegen (
	sid serial NOT NULL PRIMARY KEY,
	geom geometry(Linestring, 28992),
	weg_sid integer,
	station_name varchar,
	stop_mode varchar,
	travel_distance varchar,
	new_node double precision
);
INSERT INTO isochrone_analysis_expanded.stop_isochrone_wegen (geom, weg_sid, station_name, stop_mode, travel_distance)
	SELECT DISTINCT weg.geom, weg.sid, stop.station_name, stop.stop_mode, '10 minutes'
	FROM (
		SELECT DISTINCT station_name, stop_id, stop_mode
		FROM isochrone_analysis_expanded.stop_isochrone_nodes
	) AS stop, isochrone_analysis_expanded.wegen weg 
	WHERE EXISTS (SELECT 1 FROM isochrone_analysis_expanded.stop_isochrone_nodes f 
		WHERE f.station_name = stop.station_name AND f.stop_id = stop.stop_id
		AND f.node_id = weg.source)
	AND EXISTS (SELECT 1 FROM isochrone_analysis_expanded.stop_isochrone_nodes f 	
		WHERE f.station_name = stop.station_name AND f.stop_id = stop.stop_id
		AND f.node_id = weg.target)
;
CREATE INDEX stop_isochrone_wegen_geom_idx ON isochrone_analysis_expanded.stop_isochrone_wegen USING GIST (geom);
-- identify segments intersecting isochrone limits
-- DROP TABLE half_segments CASCADE;
CREATE TEMP TABLE half_segments AS 
	SELECT DISTINCT weg.geom, weg.sid AS weg_sid, stop.station_name, stop.stop_mode, '10 minutes',
		weg.length, weg.source, weg.target
	FROM (
		SELECT DISTINCT station_name, stop_mode
		FROM isochrone_analysis_expanded.stop_isochrone_nodes
	) stop, isochrone_analysis_expanded.wegen weg 
	WHERE (EXISTS (SELECT 1 FROM isochrone_analysis_expanded.stop_isochrone_nodes f 
		WHERE f.station_name = stop.station_name AND f.stop_mode = stop.stop_mode
		AND f.node_id = weg.source)
	OR EXISTS (SELECT 1 FROM isochrone_analysis_expanded.stop_isochrone_nodes f 	
		WHERE f.station_name = stop.station_name AND f.stop_mode = stop.stop_mode
		AND f.node_id = weg.target))
	AND NOT EXISTS (
		SELECT 1 FROM isochrone_analysis_expanded.stop_isochrone_wegen a
		WHERE a.weg_sid = weg.sid 
		AND a.station_name = stop.station_name
		AND a.stop_mode = stop.stop_mode
	)
;
-- calculate partial segments with linear referencing 
-- walk from source
INSERT INTO isochrone_analysis_expanded.stop_isochrone_wegen (geom, weg_sid, station_name, stop_mode, travel_distance, new_node)
	SELECT CASE WHEN ((300-stop.node_distance)/weg.length) <= 1 
		THEN ST_LineSubstring(weg.geom,0,((300-stop.node_distance)/weg.length))
		ELSE weg.geom END,
		weg.weg_sid, stop.station_name, stop.stop_mode, '10 minutes', ((300-stop.node_distance)/weg.length) 
	FROM half_segments weg, isochrone_analysis_expanded.stop_isochrone_nodes stop
	WHERE weg.station_name = stop.station_name 
	AND weg.stop_mode = stop.stop_mode
	AND weg.source = stop.node_id
;
-- walk from target
INSERT INTO isochrone_analysis_expanded.stop_isochrone_wegen (geom, weg_sid, station_name, stop_mode, travel_distance, new_node)
	SELECT CASE WHEN ((300-stop.node_distance)/weg.length) <= 1 
		THEN ST_LineSubstring(weg.geom,1-((300-stop.node_distance)/weg.length),1)
		ELSE weg.geom END,
		weg.weg_sid, stop.station_name, stop.stop_mode, '10 minutes', ((300-stop.node_distance)/weg.length)-1
	FROM half_segments weg, isochrone_analysis_expanded.stop_isochrone_nodes stop
	WHERE weg.station_name = stop.station_name 
	AND weg.stop_mode = stop.stop_mode
	AND weg.target = stop.node_id
;
