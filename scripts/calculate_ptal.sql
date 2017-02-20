-- KPO data system
-- author: Jorge Gil, 2017


-- PTAL calculation,based on 100m grid cells, for all OV modes

-- STEP 0: Get the POIs and corresponding network nodes
-- STEP 1: Identify candidate SAPs from isochrone nodes
-- STEP 2: Identify candidate journeys (routes)
-- STEP 3: Identify valid routes at each SAP
-- STEP 4: Calculating Total Access Time and EDF
-- STEP 5: Calculate accessibility index
-- STEP 6: Calculate PTAI and PTAL for the POIs


--
-- STEP 0: Get the POIs and corresponding network nodes
--
-- DROP SCHEMA ov_analysis CASCADE;
CREATE SCHEMA ov_analysis;
-- DROP TABLE ov_analysis.ptal_poi CASCADE;
CREATE TABLE ov_analysis.ptal_poi (
	sid serial NOT NULL PRIMARY KEY,
	geom geometry(Point, 28992),
	cell_id character varying,
	weg_sid integer,
	weg_length double precision,
	weg_point_location double precision,
	source_id integer,
	target_id integer
);
INSERT INTO ov_analysis.ptal_poi (cell_id, geom, weg_sid, weg_length, weg_point_location, source_id, target_id) 
	SELECT DISTINCT ON (grid.c28992r100) grid.c28992r100, ST_ClosestPoint(weg.geom, grid.geom),
		weg.sid, weg.length, ST_LineLocatePoint(weg.geom, grid.geom), weg.source, weg.target
	FROM (SELECT ST_Centroid(geom) geom, c28992r100
		FROM sources.vdm_vierkant_2014_pnh_lisa
	) AS grid, isochrone_analysis.wegen weg
	WHERE ST_DWithin(grid.geom,weg.geom,100)
	ORDER BY grid.c28992r100, grid.geom <-> weg.geom
;
-- remove POIs that are not reachable from any OV stop: PTAL and PTAI is 0 in those cases
DELETE FROM ov_analysis.ptal_poi AS poi
	WHERE NOT EXISTS (SELECT 1 FROM isochrone_analysis.isochrone_nodes AS node WHERE node.node_id = poi.source_id)
	AND NOT EXISTS (SELECT 1 FROM isochrone_analysis.isochrone_nodes AS node WHERE node.node_id = poi.target_id)
;
-- create indices to speed up queries
CREATE INDEX ptal_poi_cell_idx ON ov_analysis.ptal_poi (cell_id);
CREATE INDEX ptal_poi_source_idx ON ov_analysis.ptal_poi (source_id);
CREATE INDEX ptal_poi_target_idx ON ov_analysis.ptal_poi (target_id);


--
-- STEP 1: Identify candidate SAPs from isochrone nodes
-- SAPs (Service Access Point) are entrances, groups of stops, or individual stops
--
-- create valid saps table
-- DROP TABLE ov_analysis.valid_saps CASCADE;
CREATE TABLE ov_analysis.valid_saps (
	sid serial NOT NULL PRIMARY KEY,
	poi_id character varying,
	sap_id character varying,
	transport_mode character varying,
	distance_to_sap double precision
);
-- prepare some indices
CREATE INDEX origin_stops_stop_idx ON isochrone_analysis.origin_stops (stop_id);
CREATE INDEX origin_stops_source_idx ON isochrone_analysis.origin_stops (source_id);
CREATE INDEX origin_stops_target_idx ON isochrone_analysis.origin_stops (target_id);
CREATE INDEX isochrone_nodes_origin_idx ON isochrone_analysis.isochrone_nodes (origin_id);
CREATE INDEX isochrone_nodes_node_idx ON isochrone_analysis.isochrone_nodes (node_id);
--
-- identify nodes within 3000m fiets of train stations
-- DROP TABLE sap_isochrone_nodes CASCADE;
CREATE TEMP TABLE sap_isochrone_nodes AS
	SELECT node.*
	FROM (
		SELECT * FROM isochrone_analysis.isochrone_nodes 
		WHERE travel_mode = 'fiets'
	) AS node
	WHERE (node.origin_id IN (SELECT target_id FROM isochrone_analysis.origin_stops WHERE stop_mode = 'trein')
	OR node.origin_id IN (SELECT source_id FROM isochrone_analysis.origin_stops WHERE stop_mode = 'trein'))
	AND node.node_distance <= 3000	
;
-- identify pois with saps within 3000m
-- DROP TABLE saps_within_poi_nodes CASCADE;
CREATE TEMP TABLE saps_within_poi_nodes AS
	SELECT poi.cell_id, stop.stop_id, stop.stop_mode, 
	CASE
	WHEN stop.source_id = node.origin_id AND node.node_id = poi.source_id
	THEN (node.node_distance + (stop.weg_length*stop.weg_point_location) + (poi.weg_length*poi.weg_point_location))
	WHEN stop.source_id = node.origin_id AND node.node_id = poi.target_id
	THEN (node.node_distance + (stop.weg_length*stop.weg_point_location) + (poi.weg_length*(1-poi.weg_point_location)))
	WHEN stop.target_id = node.origin_id AND node.node_id = poi.source_id
	THEN (node.node_distance + (stop.weg_length*(1-stop.weg_point_location)) + (poi.weg_length*poi.weg_point_location))
	WHEN stop.target_id = node.origin_id AND node.node_id = poi.target_id
	THEN (node.node_distance + (stop.weg_length*(1-stop.weg_point_location)) + (poi.weg_length*(1-poi.weg_point_location)))
	END AS distance
	FROM (SELECT * FROM isochrone_analysis.origin_stops WHERE stop_mode = 'trein') AS stop,
	sap_isochrone_nodes AS node,
	ov_analysis.ptal_poi AS poi
	WHERE (stop.source_id = node.origin_id AND node.node_id = poi.source_id 
		AND (node.node_distance + (stop.weg_length*stop.weg_point_location) + 
		(poi.weg_length*poi.weg_point_location)) <= 3000
	) OR (stop.source_id = node.origin_id AND node.node_id = poi.target_id
		AND (node.node_distance + (stop.weg_length*stop.weg_point_location) + 
		(poi.weg_length*(1-poi.weg_point_location))) <= 3000
	) OR (stop.target_id = node.origin_id AND node.node_id = poi.source_id
		AND (node.node_distance + (stop.weg_length*(1-stop.weg_point_location)) + 
		(poi.weg_length*poi.weg_point_location)) <= 3000
	) OR (stop.target_id = node.origin_id AND node.node_id = poi.target_id
		AND (node.node_distance + (stop.weg_length*(1-stop.weg_point_location)) + 
		(poi.weg_length*(1-poi.weg_point_location))) <= 3000
	)
;
-- get minimum distance from poi to sap
-- DELETE FROM ov_analysis.valid_saps WHERE stop_mode = 'trein';
INSERT INTO ov_analysis.valid_saps (poi_id, sap_id, transport_mode, distance_to_sap)
	SELECT cell_id, stop_id, stop_mode, min(distance)
	FROM saps_within_poi_nodes
	GROUP BY cell_id, stop_id, stop_mode
;
--
-- identify nodes within 800m walk of metro stations
DROP TABLE sap_isochrone_nodes CASCADE;
CREATE TEMP TABLE sap_isochrone_nodes AS
	SELECT node.*
	FROM (
		SELECT * FROM isochrone_analysis.isochrone_nodes 
		WHERE travel_mode = 'walk'
	) AS node
	WHERE (node.origin_id IN (SELECT target_id FROM isochrone_analysis.origin_stops WHERE stop_mode = 'metro')
	OR node.origin_id IN (SELECT source_id FROM isochrone_analysis.origin_stops WHERE stop_mode = 'metro'))
	AND node.node_distance <= 800	
;
-- identify pois with saps within 800m
DROP TABLE saps_within_poi_nodes CASCADE;
CREATE TEMP TABLE saps_within_poi_nodes AS
	SELECT poi.cell_id, stop.stop_id, stop.stop_mode, 
	CASE
	WHEN stop.source_id = node.origin_id AND node.node_id = poi.source_id
	THEN (node.node_distance + (stop.weg_length*stop.weg_point_location) + (poi.weg_length*poi.weg_point_location))
	WHEN stop.source_id = node.origin_id AND node.node_id = poi.target_id
	THEN (node.node_distance + (stop.weg_length*stop.weg_point_location) + (poi.weg_length*(1-poi.weg_point_location)))
	WHEN stop.target_id = node.origin_id AND node.node_id = poi.source_id
	THEN (node.node_distance + (stop.weg_length*(1-stop.weg_point_location)) + (poi.weg_length*poi.weg_point_location))
	WHEN stop.target_id = node.origin_id AND node.node_id = poi.target_id
	THEN (node.node_distance + (stop.weg_length*(1-stop.weg_point_location)) + (poi.weg_length*(1-poi.weg_point_location)))
	END AS distance
	FROM (SELECT * FROM isochrone_analysis.origin_stops WHERE stop_mode = 'metro') AS stop,
	sap_isochrone_nodes AS node,
	ov_analysis.ptal_poi AS poi
	WHERE (stop.source_id = node.origin_id AND node.node_id = poi.source_id 
		AND (node.node_distance + (stop.weg_length*stop.weg_point_location) + 
		(poi.weg_length*poi.weg_point_location)) <= 800
	) OR (stop.source_id = node.origin_id AND node.node_id = poi.target_id
		AND (node.node_distance + (stop.weg_length*stop.weg_point_location) + 
		(poi.weg_length*(1-poi.weg_point_location))) <= 800
	) OR (stop.target_id = node.origin_id AND node.node_id = poi.source_id
		AND (node.node_distance + (stop.weg_length*(1-stop.weg_point_location)) + 
		(poi.weg_length*poi.weg_point_location)) <= 800
	) OR (stop.target_id = node.origin_id AND node.node_id = poi.target_id
		AND (node.node_distance + (stop.weg_length*(1-stop.weg_point_location)) + 
		(poi.weg_length*(1-poi.weg_point_location))) <= 800
	)
;
-- get minimum distance from poi to sap
-- DELETE FROM ov_analysis.valid_saps WHERE stop_mode = 'metro';
INSERT INTO ov_analysis.valid_saps (poi_id, sap_id, transport_mode, distance_to_sap)
	SELECT cell_id, stop_id, stop_mode, min(distance)
	FROM saps_within_poi_nodes
	GROUP BY cell_id, stop_id, stop_mode
;
--
-- identify nodes within 400m walk of tram and bus stops
DROP TABLE sap_isochrone_nodes CASCADE;
CREATE TEMP TABLE sap_isochrone_nodes AS
	SELECT node.*
	FROM (
		SELECT * FROM isochrone_analysis.isochrone_nodes 
		WHERE travel_mode = 'walk'
	) AS node
	WHERE (node.origin_id IN (SELECT target_id FROM isochrone_analysis.origin_stops WHERE stop_mode IN ('tram','bus'))
	OR node.origin_id IN (SELECT source_id FROM isochrone_analysis.origin_stops WHERE stop_mode IN ('tram','bus')))
	AND node.node_distance <= 400	
;
-- identify pois with saps within 800m
DROP TABLE saps_within_poi_nodes CASCADE;
CREATE TEMP TABLE saps_within_poi_nodes AS
	SELECT poi.cell_id, stop.stop_id, stop.stop_mode, 
	CASE
	WHEN stop.source_id = node.origin_id AND node.node_id = poi.source_id
	THEN (node.node_distance + (stop.weg_length*stop.weg_point_location) + (poi.weg_length*poi.weg_point_location))
	WHEN stop.source_id = node.origin_id AND node.node_id = poi.target_id
	THEN (node.node_distance + (stop.weg_length*stop.weg_point_location) + (poi.weg_length*(1-poi.weg_point_location)))
	WHEN stop.target_id = node.origin_id AND node.node_id = poi.source_id
	THEN (node.node_distance + (stop.weg_length*(1-stop.weg_point_location)) + (poi.weg_length*poi.weg_point_location))
	WHEN stop.target_id = node.origin_id AND node.node_id = poi.target_id
	THEN (node.node_distance + (stop.weg_length*(1-stop.weg_point_location)) + (poi.weg_length*(1-poi.weg_point_location)))
	END AS distance
	FROM (SELECT * FROM isochrone_analysis.origin_stops WHERE stop_mode IN ('tram','bus')) AS stop,
	sap_isochrone_nodes AS node,
	ov_analysis.ptal_poi AS poi
	WHERE (stop.source_id = node.origin_id AND node.node_id = poi.source_id 
		AND (node.node_distance + (stop.weg_length*stop.weg_point_location) + 
		(poi.weg_length*poi.weg_point_location)) <= 400
	) OR (stop.source_id = node.origin_id AND node.node_id = poi.target_id
		AND (node.node_distance + (stop.weg_length*stop.weg_point_location) + 
		(poi.weg_length*(1-poi.weg_point_location))) <= 400
	) OR (stop.target_id = node.origin_id AND node.node_id = poi.source_id
		AND (node.node_distance + (stop.weg_length*(1-stop.weg_point_location)) + 
		(poi.weg_length*poi.weg_point_location)) <= 400
	) OR (stop.target_id = node.origin_id AND node.node_id = poi.target_id
		AND (node.node_distance + (stop.weg_length*(1-stop.weg_point_location)) + 
		(poi.weg_length*(1-poi.weg_point_location))) <= 400
	)
;
-- get minimum distance from poi to sap
-- DELETE FROM ov_analysis.valid_saps WHERE stop_mode IN ('tram','bus');
INSERT INTO ov_analysis.valid_saps (poi_id, sap_id, transport_mode, distance_to_sap)
	SELECT cell_id, stop_id, stop_mode, min(distance)
	FROM saps_within_poi_nodes
	GROUP BY cell_id, stop_id, stop_mode
;
-- add indices for faster querying
CREATE INDEX valid_saps_idx ON ov_analysis.valid_saps (sap_id);


--
-- STEP 2: Identify candidate routes
--
-- candidate links with start and stop within the analysis region: networks.ov_links
-- if we have a Netherlands map and wanted to study a region, we would have to filter

-- create candidate routes temp table:
-- only those at weekday afternoon afternoon peak time, that one can board, and have valid link
-- peak time is 17.00 to 18.00 to have a 1 hour period as in London. Otherwise we have to adjust the method.
-- DROP TABLE temp_candidate_routes CASCADE;
CREATE TEMP TABLE temp_candidate_routes (
	sid serial NOT NULL PRIMARY KEY,
	sap_id character varying,
	route_name character varying,
	trip_headsign character varying,
	direction integer,
	transport_mode character varying,
	frequency integer
);
INSERT INTO temp_candidate_routes (sap_id, route_name, trip_headsign, direction, transport_mode, frequency)
	SELECT routes.sap_id, routes.route_name, routes.trip_headsign, 
		routes.direction_id, routes.route_type, count(*)
	FROM (
		SELECT stops.sap_id,
			CASE WHEN patterns.route_short_name IS NULL THEN patterns.route_long_name
			ELSE patterns.route_short_name END AS route_name,
			patterns.trip_headsign, patterns.direction_id, 
			patterns.route_type
		FROM (
			SELECT sap_id FROM ov_analysis.valid_saps 
			GROUP BY sap_id
		) AS stops
		JOIN (
			SELECT * FROM networks.ov_links link
			WHERE (start_stop_time >= EXTRACT(EPOCH FROM INTERVAL '17:00:00') 
			AND start_stop_time <= EXTRACT(EPOCH FROM INTERVAL '18:00:00'))
			AND trip_id IN (
				SELECT trip_id FROM networks.ov_trips 
				WHERE day_of_week not in ('saturday','sunday')
			)
		) AS times
		ON(stops.sap_id=times.start_stop_id)
		JOIN networks.ov_trips AS patterns
		USING(trip_id)
	) routes
	GROUP BY routes.sap_id, routes.route_name, routes.trip_headsign, 
		routes.direction_id, routes.route_type
;
CREATE INDEX temp_candidate_routes_idx ON temp_candidate_routes (sap_id);

-- eliminate bi-directional routes, selecting highest frequency
DELETE FROM temp_candidate_routes WHERE sid IN (
		SELECT DISTINCT ON(a.sap_id, a.route_name, a.transport_mode) a.sid
		FROM temp_candidate_routes a, temp_candidate_routes b
		WHERE a.sap_id=b.sap_id 
		AND a.route_name=b.route_name
		--AND a.trip_headsign=b.trip_headsign
		AND a.transport_mode=b.transport_mode
		AND (a.direction!=b.direction)
		ORDER BY a.sap_id, a.route_name, a.transport_mode, a.frequency ASC
	)
;


--
-- STEP 3: Identify valid routes at each SAP
--
-- DROP TABLE ov_analysis.valid_routes CASCADE;
CREATE TABLE ov_analysis.valid_routes(
	sid serial NOT NULL PRIMARY KEY, 
	poi_id character varying,
	sap_id character varying,
	transport_mode character varying, 
	distance_to_sap double precision,
	pattern_id integer,
	pattern_frequency integer
);
INSERT INTO ov_analysis.valid_routes
	(poi_id, sap_id, transport_mode, distance_to_sap, pattern_id, pattern_frequency)
	SELECT 
		DISTINCT ON (saps.poi_id, routes.sid)
		saps.poi_id, 
		saps.sap_id,
		saps.transport_mode,
		saps.distance_to_sap,
		routes.sid,
		routes.frequency AS pattern_frequency
	FROM ov_analysis.valid_saps AS saps
	JOIN temp_candidate_routes AS routes
	USING (sap_id)
	ORDER BY saps.poi_id, routes.sid, saps.distance_to_sap ASC
;


--
-- STEP 4: Calculating Total Access Time and EDF
--
ALTER TABLE ov_analysis.valid_routes 
	ADD COLUMN travel_time double precision,
	ADD COLUMN swt double precision,
	ADD COLUMN access_time double precision,
	ADD COLUMN edf double precision,
	ADD COLUMN weight double precision,
	ADD COLUMN accessibility_index double precision
;
-- update travel time in minutes based on walk speed of 80m/minute
UPDATE ov_analysis.valid_routes 
	SET travel_time = distance_to_sap/80.0
	WHERE transport_mode IN ('metro','tram','bus')
;
-- update travel time in minutes based on cycle speed of 300m/minute
UPDATE ov_analysis.valid_routes 
	SET travel_time = distance_to_sap/300.0
	WHERE transport_mode IN ('trein')
;
-- update wait time (with added 2 minute delay for most modes, and 0.75 minute delay for rail)
UPDATE ov_analysis.valid_routes 
	SET swt = CASE
		WHEN transport_mode IN ('trein','metro')
			THEN (0.5*(60.0/pattern_frequency::double precision)) + 0.75
		ELSE (0.5*(60.0/pattern_frequency::double precision)) + 2.0
	END
;
-- calculate access time
UPDATE ov_analysis.valid_routes SET access_time = travel_time + swt;
-- calculate edf
UPDATE ov_analysis.valid_routes SET edf = 30.0/access_time;



--
-- STEP 5: Calculate accessibility index
--
-- update weight
UPDATE ov_analysis.valid_routes SET weight = 1.0
	WHERE sid IN (
		SELECT DISTINCT ON (poi_id, transport_mode) sid 
		FROM ov_analysis.valid_routes
		ORDER BY poi_id, transport_mode, edf DESC
	)
;
UPDATE ov_analysis.valid_routes SET weight = 0.5 WHERE weight IS NULL;
-- update accessibility index
UPDATE ov_analysis.valid_routes SET accessibility_index = weight * edf;
-- create index
CREATE INDEX valid_routes_idx ON ov_analysis.valid_routes (poi_id);


--
-- STEP 6: Calculate PTAI and PTAL for the POIs
--
ALTER TABLE ov_analysis.ptal_poi 
	ADD COLUMN ptai double precision,
	ADD COLUMN ptal character varying
;
-- PTAI: accessibility index
UPDATE ov_analysis.ptal_poi AS poi
	SET ptai = routes.accessibility_index
	FROM (
		SELECT poi_id, round(sum(accessibility_index)::numeric,2) accessibility_index
		FROM ov_analysis.valid_routes
		GROUP BY poi_id
	) AS routes
	WHERE poi.cell_id = routes.poi_id
;
-- UPDATE ov_analysis.ptal_poi SET ptai = 0 WHERE ptai IS NULL;
-- PTAL
UPDATE ov_analysis.ptal_poi SET ptal = CASE
	--WHEN ptai = 0 THEN '0'
	WHEN ptai > 0 AND ptai <= 2.5 THEN '1a'
	WHEN ptai > 2.5 AND ptai <= 5 THEN '1b'
	WHEN ptai > 5 AND ptai <= 10 THEN '2'
	WHEN ptai > 10 AND ptai <= 15 THEN '3'
	WHEN ptai > 15 AND ptai <= 20 THEN '4'
	WHEN ptai > 20 AND ptai <= 25 THEN '5'
	WHEN ptai > 25 AND ptai <= 40 THEN '6a'
	WHEN ptai > 40 THEN '6b'
	END
	WHERE ptai IS NOT NULL
;
