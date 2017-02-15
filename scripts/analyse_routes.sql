-- ov isochrone analysis, from rail stations, using bus, tram or metro
-- ov_network_analysis.links_frequency has the network topology per mode, with average cost
-- study.ov_links has the network topology per mode for every trip, with shared nodes for transfer
-- study.ov_all_links has the network topology per mode for every trip, without transfer

-- origin stops
-- DROP TABLE ov_network_analysis.origin_stops CASCADE;
CREATE TABLE ov_network_analysis.origin_stops (
	sid serial NOT NULL PRIMARY KEY,
	geom geometry(Point, 28992),
	station_sid integer,
	station_id character varying,
	station_naam character varying,
	stop_id character varying,
	stop_naam character varying,
	stop_mode character varying
);
-- closest bus stops
INSERT INTO ov_network_analysis.origin_stops (geom, station_sid, station_id, station_naam, stop_id,
	stop_naam, stop_mode)
	SELECT stop.geom, station.sid, station.code, station.naam, stop.stop_id, stop.stop_name, 'bus'
	FROM study.stations_maakplaats AS station,
	(SELECT * FROM study.ov_stops WHERE parent_station IS NULL AND bus = TRUE) AS stop
	WHERE ST_DWithin(station.geom,stop.geom,200)
;
-- closest tram stops
INSERT INTO ov_network_analysis.origin_stops (geom, station_sid, station_id, station_naam, stop_id,
	stop_naam, stop_mode)
	SELECT stop.geom, station.sid, station.code, station.naam, stop.stop_id, stop.stop_name, 'tram'
	FROM study.stations_maakplaats AS station,
	(SELECT * FROM study.ov_stops WHERE parent_station IS NULL AND tram = TRUE) AS stop
	WHERE ST_DWithin(station.geom,stop.geom,200)
;
-- closest metro stops
INSERT INTO ov_network_analysis.origin_stops (geom, station_sid, station_id, station_naam, stop_id,
	stop_naam, stop_mode)
	SELECT stop.geom, station.sid, station.code, station.naam, stop.stop_id, stop.stop_name, 'metro'
	FROM study.stations_maakplaats AS station,
	(SELECT * FROM study.ov_stops WHERE parent_station IS NULL AND metro = TRUE) AS stop
	WHERE ST_DWithin(station.geom,stop.geom,200)
;

-- isochrone nodes
-- DROP TABLE ov_network_analysis.isochrone_nodes CASCADE;
CREATE TABLE ov_network_analysis.isochrone_nodes(
	sid bigserial NOT NULL PRIMARY KEY,
	station_sid integer,
	origin_id character varying,
	travel_mode character varying,
	node_id integer,
	node_distance double precision
);
-- bus isochrones 10 minutes = 6000 seconds
-- DROP TABLE network_bus CASCADE;
CREATE TEMP TABLE network_bus AS (
	SELECT * FROM ov_network_analysis.links_frequency WHERE trip_mode = 'bus' AND freq_spits_avond > 0
);
-- DELETE FROM ov_network_analysis.isochrone_nodes WHERE travel_mode = 'bus';
INSERT INTO ov_network_analysis.isochrone_nodes (station_sid, origin_id, travel_mode, node_id, node_distance)
	SELECT origin.station_sid, origin.stop_id, 'bus', (origin.catchment).id1, (origin.catchment).cost
		FROM (
			SELECT a.station_sid, a.stop_id, pgr_drivingDistance(
				'SELECT sid AS id, start_stop_id::int AS source, end_stop_id::int AS target, 
				mean_duration_in_secs::float AS cost 
				FROM network_bus',
				a.stop_id::integer, 600.0, false, false
			) catchment
			FROM (SELECT * FROM ov_network_analysis.origin_stops s
				WHERE stop_mode = 'bus'
				AND EXISTS (SELECT 1 FROM network_bus 
				WHERE start_stop_id=s.stop_id OR end_stop_id=s.stop_id)) a
		) origin
;
-- tram isochrones 10 minutes = 6000 seconds
-- DROP TABLE network_tram CASCADE;
CREATE TEMP TABLE network_tram AS (
	SELECT * FROM ov_network_analysis.links_frequency WHERE trip_mode = 'tram' AND freq_spits_avond > 0
);
-- DELETE FROM ov_network_analysis.isochrone_nodes WHERE travel_mode = 'tram';
INSERT INTO ov_network_analysis.isochrone_nodes (station_sid, origin_id, travel_mode, node_id, node_distance)
	SELECT origin.station_sid, origin.stop_id, 'tram', (origin.catchment).id1, (origin.catchment).cost
		FROM (
			SELECT a.station_sid, a.stop_id, pgr_drivingDistance(
				'SELECT sid AS id, start_stop_id::int AS source, end_stop_id::int AS target, 
				mean_duration_in_secs::float AS cost 
				FROM network_tram',
				a.stop_id::integer, 600.0, false, false
			) catchment
			FROM (SELECT * FROM ov_network_analysis.origin_stops s
				WHERE stop_mode = 'tram'
				AND EXISTS (SELECT 1 FROM network_tram 
				WHERE start_stop_id=s.stop_id OR end_stop_id=s.stop_id)) a
		) origin
;
-- metro isochrones 10 minutes = 6000 seconds
-- DROP TABLE network_metro CASCADE;
CREATE TEMP TABLE network_metro AS (
	SELECT * FROM ov_network_analysis.links_frequency WHERE trip_mode = 'metro' AND freq_spits_avond > 0
);
-- DELETE FROM ov_network_analysis.isochrone_nodes WHERE travel_mode = 'metro';
INSERT INTO ov_network_analysis.isochrone_nodes (station_sid, origin_id, travel_mode, node_id, node_distance)
	SELECT origin.station_sid, origin.stop_id, 'metro', (origin.catchment).id1, (origin.catchment).cost
		FROM (
			SELECT a.station_sid, a.stop_id, pgr_drivingDistance(
				'SELECT sid AS id, start_stop_id::int AS source, end_stop_id::int AS target, 
				mean_duration_in_secs::float AS cost 
				FROM network_metro',
				a.stop_id::integer, 600.0, false, false
			) catchment
			FROM (SELECT * FROM ov_network_analysis.origin_stops s
				WHERE stop_mode = 'metro'
				AND EXISTS (SELECT 1 FROM network_metro 
				WHERE start_stop_id=s.stop_id OR end_stop_id=s.stop_id)) a
		) origin
;


-- isochrone links
-- DROP TABLE ov_network_analysis.station_isochrone_links CASCADE;
CREATE TABLE ov_network_analysis.station_isochrone_links (
	sid serial NOT NULL PRIMARY KEY,
	geom geometry(Linestring, 28992),
	link_sid integer,
	station_sid integer,
	station_id varchar,
	station_naam varchar,
	travel_mode varchar,
	travel_distance integer
);
-- DELETE FROM ov_network_analysis.station_isochrone_links;
INSERT INTO ov_network_analysis.station_isochrone_links (geom, link_sid, station_sid, station_id, 
	station_naam, travel_mode, travel_distance)
	SELECT weg.geom, weg.sid, stat.sid, stat.id, stat.naam, 'bus', 600
	FROM study.stations_maakplaats AS stat, network_bus weg 
	WHERE EXISTS (SELECT 1 FROM ov_network_analysis.isochrone_nodes f 
		WHERE travel_mode = 'bus' AND node_distance <= 600 AND f.station_sid = stat.sid
		AND f.node_id::text = weg.start_stop_id)
	OR EXISTS (SELECT 1 FROM ov_network_analysis.isochrone_nodes f 	
		WHERE travel_mode = 'bus' AND node_distance <= 600 AND f.station_sid = stat.sid
		AND f.node_id::text = weg.end_stop_id)
;
INSERT INTO ov_network_analysis.station_isochrone_links (geom, link_sid, station_sid, station_id, 
	station_naam, travel_mode, travel_distance)
	SELECT weg.geom, weg.sid, stat.sid, stat.id, stat.naam, 'tram', 600
	FROM study.stations_maakplaats AS stat, network_tram weg 
	WHERE EXISTS (SELECT 1 FROM ov_network_analysis.isochrone_nodes f 
		WHERE travel_mode = 'tram' AND node_distance <= 600 AND f.station_sid = stat.sid
		AND f.node_id::text = weg.start_stop_id)
	OR EXISTS (SELECT 1 FROM ov_network_analysis.isochrone_nodes f 	
		WHERE travel_mode = 'tram' AND node_distance <= 600 AND f.station_sid = stat.sid
		AND f.node_id::text = weg.end_stop_id)
;
INSERT INTO ov_network_analysis.station_isochrone_links (geom, link_sid, station_sid, station_id, 
	station_naam, travel_mode, travel_distance)
	SELECT weg.geom, weg.sid, stat.sid, stat.id, stat.naam, 'metro', 600
	FROM study.stations_maakplaats AS stat, network_metro weg 
	WHERE EXISTS (SELECT 1 FROM ov_network_analysis.isochrone_nodes f 
		WHERE travel_mode = 'metro' AND node_distance <= 600 AND f.station_sid = stat.sid
		AND f.node_id::text = weg.start_stop_id)
	OR EXISTS (SELECT 1 FROM ov_network_analysis.isochrone_nodes f 	
		WHERE travel_mode = 'metro' AND node_distance <= 600 AND f.station_sid = stat.sid
		AND f.node_id::text = weg.end_stop_id)
;


-- create buffers for isochrones
-- DROP TABLE ov_network_analysis.station_isochrone_buffers CASCADE;
CREATE TABLE ov_network_analysis.station_isochrone_buffers (
	sid serial NOT NULL PRIMARY KEY,
	geom geometry(MultiPolygon,28992),
	station_id character varying,
	station_naam character varying,
	travel_mode character varying, 
	travel_distance integer
);
INSERT INTO ov_network_analysis.station_isochrone_buffers (geom, station_id, station_naam, travel_mode, travel_distance)
	SELECT ST_Multi(ST_Union(ST_Buffer(ST_Simplify(geom,5),100,2))), station_id, min(station_naam), 
		travel_mode, travel_distance
	FROM ov_network_analysis.station_isochrone_links
	GROUP BY station_id, travel_mode, travel_distance
;


-- create polygons for isochrones
-- DROP TABLE ov_network_analysis.station_isochrone_polygons CASCADE;
CREATE TABLE ov_network_analysis.station_isochrone_polygons (
	sid serial NOT NULL PRIMARY KEY,
	geom geometry(Polygon,28992),
	station_id character varying,
	station_naam character varying,
	travel_mode character varying, 
	travel_distance integer
);
INSERT INTO ov_network_analysis.station_isochrone_polygons (geom, station_id, station_naam, travel_mode, travel_distance)
	SELECT ST_MakePolygon(ST_ExteriorRing((ST_Dump(ST_Union(ST_Buffer(ST_Simplify(geom,5),100,2)))).geom)), 
		station_id, min(station_naam), travel_mode, travel_distance
	FROM ov_network_analysis.station_isochrone_links
	GROUP BY station_id, travel_mode, travel_distance
;
