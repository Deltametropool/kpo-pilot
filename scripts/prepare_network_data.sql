-- KPO data system
-- author: Jorge Gil, 2017


-- prepare network data used in analysis and calculations
-- DROP SCHEMA IF EXISTS networks CASCADE;
CREATE SCHEMA networks;
ALTER SCHEMA networks OWNER TO postgres;

----
-- TOP10NL road network
----
-- DROP TABLE networks.t10_wegen CASCADE;
CREATE TABLE networks.t10_wegen(
	sid serial NOT NULL PRIMARY KEY,
	geom geometry(LineString,28992),
	length double precision,
	t10_id varchar,
	type_weg varchar,
	verkeer varchar,
	fysiek varchar,
	breedte varchar,
	gescheiden boolean,
	verharding varchar,
	aantal_rij integer,
	niveau integer,
	a_weg varchar,
	n_weg varchar,
	e_weg varchar,
	s_weg varchar,
	auto boolean,
	fiets boolean,
	voetganger boolean
);
INSERT INTO networks.t10_wegen(geom, length, t10_id, type_weg, verkeer, fysiek, breedte, gescheiden, verharding,
	aantal_rij, niveau, a_weg, n_weg, e_weg, s_weg)
	SELECT weg.wkb_geometry, ST_Length(weg.wkb_geometry), lokaalid, 
		substring(typeweg from 4 for (char_length(typeweg)-4)), 
		substring(hoofdverkeersgebruik from 4 for (char_length(hoofdverkeersgebruik)-4)), 
		substring(fysiekvoorkomen from 4 for (char_length(fysiekvoorkomen)-4)),
		verhardingsbreedteklasse, CASE gescheidenrijbaan WHEN 'ja' THEN TRUE ELSE FALSE END,
		verhardingstype, aantalrijstroken, hoogteniveau,
		substring(awegnummer from 4 for (char_length(awegnummer)-4)), 
		substring(nwegnummer from 4 for (char_length(nwegnummer)-4)), 
		substring(ewegnummer from 4 for (char_length(ewegnummer)-4)), 
		substring(swegnummer from 4 for (char_length(swegnummer)-4))
	FROM (SELECT * FROM sources.t10nl_wegdeel_hartlijn 
		WHERE eindregistratie IS NULL
		AND status IN ('in gebruik', 'onbekend')
		AND hoofdverkeersgebruik NOT IN ('(1:vliegverkeer)','(1:busverkeer)')
		AND verhardingstype != 'onverhard'
		AND typeweg NOT IN ('(1:startbaan, landingsbaan)','(1:rolbaan, platform)')
	) weg,
	(SELECT geom FROM datasysteem.boundary LIMIT 1) pilot
	WHERE ST_Intersects(weg.wkb_geometry, pilot.geom)
;
-- update mode columns
-- UPDATE networks.t10_wegen SET auto=NULL, fiets=NULL, voetganger=NULL;
UPDATE networks.t10_wegen SET auto=True, fiets=False, voetganger=False WHERE verkeer = 'snelverkeer';
UPDATE networks.t10_wegen SET auto=False, fiets=True WHERE verkeer = 'fietsers, bromfietsers';
UPDATE networks.t10_wegen SET auto=False, voetganger=True WHERE verkeer = 'voetgangers';
-- DROP INDEX t10_wegen_geom_idx CASCADE;
CREATE INDEX t10_wegen_geom_idx ON networks.t10_wegen USING GIST (geom);

----
-- 9292 GTFS public transport network
----
-- stops
-- DROP TABLE networks.ov_stops CASCADE;
CREATE TABLE networks.ov_stops (
	geom geometry(Point,28992),
	stop_id character varying NOT NULL PRIMARY KEY,
	stop_code character varying,
	stop_name character varying,
	stop_descr character varying,
	platform_code character varying,
	location_type integer,
	parent_station character varying,
	stop_area integer,
	tram boolean,
	metro boolean,
	trein boolean,
	bus boolean,
	veerboot boolean
);
INSERT INTO networks.ov_stops(geom, stop_id, stop_code, stop_name, stop_descr, platform_code, 
		location_type, parent_station)
	SELECT gtfs.geom, gtfs.stop_id, gtfs.stop_code, gtfs.stop_name, gtfs.stop_descr,
		gtfs.platform_code, gtfs.location_type, gtfs.parent_station
	FROM (SELECT ST_Transform(ST_SetSRID(ST_Point(stop_lon,stop_lat),4326),28992) geom, 
		stop_id, 
		CASE WHEN stop_code='' THEN NULL
		ELSE stop_code END AS stop_code, 
		CASE WHEN strpos(stop_name,',') > 0 
			THEN ltrim(split_part(stop_name,',',2)) 
			ELSE stop_name 
		END AS stop_name, 
		CASE WHEN strpos(stop_name,',') > 0 
			THEN split_part(stop_name,',',1) 
		END AS stop_descr, 
		CASE WHEN platform_code='' THEN NULL
		ELSE  platform_code END AS platform_code, location_type, 
		CASE WHEN parent_station='' THEN NULL 
		ELSE parent_station END AS parent_station 
		FROM gtfs.stops) gtfs,
	(SELECT geom geom FROM networks.boundary LIMIT 1) study
	WHERE ST_Intersects(gtfs.geom,study.geom)
;
CREATE INDEX ov_stops_geom_idx ON networks.ov_stops USING GIST (geom);

-- stop times
-- DROP TABLE networks.ov_stop_times CASCADE;
CREATE TABLE networks.ov_stop_times (
	sid serial NOT NULL PRIMARY KEY,
	trip_id character varying,
	arrival_time character varying,
	departure_time character varying,
	stop_id character varying,
	stop_sequence integer,
	pickup_type integer,
	drop_off_type integer,
	arrival_in_secs integer,
	departure_in_secs integer
);
INSERT INTO networks.ov_stop_times ( trip_id, arrival_time, departure_time, stop_id, stop_sequence, pickup_type, drop_off_type,
	arrival_in_secs, departure_in_secs)
	SELECT trip_id, arrival_time, departure_time, 
		stop_id, stop_sequence, pickup_type, drop_off_type,
		(CAST((substring(arrival_time for 2)) as integer)*3600+
		CAST((substring(arrival_time from 4 for 2)) as integer)*60+
		CAST((substring(arrival_time from 7 for 2)) as integer)),
		(CAST((substring(departure_time for 2)) as integer)*3600+
		CAST((substring(departure_time from 4 for 2)) as integer)*60+
		CAST((substring(departure_time from 7 for 2)) as integer))	
	FROM gtfs.stop_times
	WHERE stop_id IN (SELECT stop_id FROM networks.ov_stops)
;
CREATE INDEX stop_times_stopid_idx ON networks.ov_stop_times (stop_id);
CREATE INDEX stop_times_tripid_idx ON networks.ov_stop_times (trip_id);

-- trips
-- DROP TABLE networks.ov_trips CASCADE;
CREATE TABLE networks.ov_trips(
	trip_id character varying NOT NULL PRIMARY KEY,
	trip_headsign character varying,
	direction_id integer,
	agency_name character varying,
	route_id character varying,
	route_short_name character varying,
	route_long_name character varying,
	route_desc character varying,
	route_type character varying,
	service_id character varying,
	day_of_week character varying
);
INSERT INTO networks.ov_trips (trip_id, trip_headsign, direction_id, agency_name, route_id,
	route_short_name, route_long_name, route_desc, route_type, service_id, day_of_week)
	SELECT trips.trip_id, trips.trip_headsign, trips.direction_id, agency.agency_name, routes.route_id,
		routes.route_short_name, routes.route_long_name, routes.route_desc, 
		CASE
			WHEN routes.route_type = 0 THEN 'tram'
			WHEN routes.route_type = 1 THEN 'metro'
			WHEN routes.route_type = 2 THEN 'trein'
			WHEN routes.route_type = 3 THEN 'bus'
			WHEN routes.route_type = 4 THEN 'ferry'
		END, trips.service_id, 
		CASE
			WHEN calendar.dow = 0 THEN 'sunday'
			WHEN calendar.dow = 1 THEN 'monday'
			WHEN calendar.dow = 2 THEN 'tuesday'
			WHEN calendar.dow = 3 THEN 'wednesday'
			WHEN calendar.dow = 4 THEN 'thursday'
			WHEN calendar.dow = 5 THEN 'friday'
			WHEN calendar.dow = 6 THEN 'saturday'
		END
	FROM (SELECT * FROM gtfs.trips 
		WHERE trip_id IN (SELECT trip_id FROM networks.ov_stop_times)) trips 
	LEFT JOIN gtfs.routes routes
	USING (route_id)
	LEFT JOIN gtfs.agency agency
	USING (agency_id)
	LEFT JOIN (SELECT service_id, extract(dow from min(exception_date)) dow
		FROM gtfs.calendar_dates GROUP BY service_id) calendar
	USING (service_id)
;

-- update stops mode
-- DROP TABLE ov_stop_modes CASCADE;
CREATE TEMP TABLE ov_stop_modes AS
	SELECT a.stop_id, min(b.route_type) route_type
	FROM networks.ov_stop_times a 
	JOIN networks.ov_trips b 
	USING(trip_id)
	GROUP BY a.stop_id, b.route_type 
	ORDER BY a.stop_id, b.route_type
;
UPDATE networks.ov_stops stp SET tram = True
	FROM (SELECT * FROM ov_stop_modes WHERE route_type='tram') mod
	WHERE stp.stop_id = mod.stop_id
;
UPDATE networks.ov_stops stp SET metro = True
	FROM (SELECT * FROM ov_stop_modes WHERE route_type='metro') mod
	WHERE stp.stop_id = mod.stop_id
;
UPDATE networks.ov_stops stp SET bus = True
	FROM (SELECT * FROM ov_stop_modes WHERE route_type='bus') mod
	WHERE stp.stop_id = mod.stop_id
;
UPDATE networks.ov_stops stp SET veerboot = True
	FROM (SELECT * FROM ov_stop_modes WHERE route_type='veerboot') mod
	WHERE stp.stop_id = mod.stop_id
;
UPDATE networks.ov_stops stp SET trein = True
	FROM (SELECT * FROM ov_stop_modes WHERE route_type='trein') mod
	WHERE stp.stop_id = mod.stop_id
;
UPDATE networks.ov_stops SET trein = TRUE WHERE location_type = 1;

-- update metro stops name
UPDATE networks.ov_stops SET
	stop_name = stop_descr,
	stop_descr = 'Amsterdam'
	WHERE metro = TRUE and stop_name = 'Amsterdam'
;
UPDATE networks.ov_stops SET
	stop_name = stop_descr,
	stop_descr = 'Amstelveen'
	WHERE metro = TRUE and stop_name = 'Amstelveen'
;
-- update train stations with VDM code from Maakplaats (for matching data)
UPDATE networks.ov_stops AS stops SET
	stop_code = vdm.code
	FROM sources.rws_treinstations_2015_pnh AS vdm 
	WHERE trein = TRUE 
	AND (lower(stop_name) = lower(vdm.station)
	OR lower(stop_name) = lower(vdm.naam)
	OR replace(lower(stop_name), '-', ' ') = lower(vdm.station))
;
UPDATE networks.ov_stops AS stops SET
	stop_code = vdm.code
	FROM sources.rws_treinstations_2015_pnh AS vdm 
	WHERE trein = TRUE
	AND stop_name = 'Hilversum Media Park'
	AND initcap(vdm.naam) = 'Hilversum-Noord'
;
UPDATE networks.ov_stops AS stops SET
	stop_code = vdm.code
	FROM sources.rws_treinstations_2015_pnh AS vdm 
	WHERE trein = TRUE
	AND stop_name = 'Zandvoort aan Zee'
	AND initcap(vdm.naam) = 'Zandvoort'
;
UPDATE networks.ov_stops AS stops SET
	stop_code = vdm.code
	FROM sources.rws_treinstations_2015_pnh AS vdm 
	WHERE trein = TRUE
	AND stop_name = 'Koog aan de Zaan'
	AND initcap(vdm.naam) = 'Koog Bloemwijk'
;
UPDATE networks.ov_stops AS stops SET
	stop_code = vdm.code
	FROM sources.rws_treinstations_2015_pnh AS vdm 
	WHERE trein = TRUE
	AND stop_name = 'Zaanse Schans'
	AND initcap(vdm.naam) = 'Koog-Zaandijk'
;

-- this is a useful function to find the index of an element in an array
CREATE OR REPLACE FUNCTION array_search(needle ANYELEMENT, haystack ANYARRAY)
RETURNS INT AS $$
    SELECT i
      FROM generate_subscripts($2, 1) AS i
     WHERE $2[i] = $1
  ORDER BY i
$$ LANGUAGE sql STABLE;

-- create groups of stop with the same name and of the same mode
-- this is used for aggregation of links and added to the stops parent_station column
-- DROP TABLE stop_groups CASCADE;
CREATE TEMP TABLE stop_groups (
	sid serial NOT NULL PRIMARY KEY,
	geom geometry(Point,28992),
	group_id character varying,
	stop_ids character varying[],
	stop_name character varying,
	stop_descr character varying,
	location_type integer,
	tram boolean,
	metro boolean,
	trein boolean,
	bus boolean,
	veerboot boolean
);
INSERT INTO stop_groups (geom, group_id, stop_ids, stop_name, stop_descr, location_type, 
	tram, metro, trein, bus, veerboot)
	SELECT ST_Centroid(ST_Collect(geom)) , min(stop_id), array_agg(stop_id), stop_name, stop_descr, 
		1, tram, metro, trein, bus, veerboot
	FROM networks.ov_stops WHERE parent_station IS NULL AND location_type = 0
	GROUP BY stop_name, stop_descr, tram, metro, trein, bus, veerboot
;
-- remove single stop groups
DELETE FROM stop_groups WHERE array_length(stop_ids,1) = 1;
-- update info about groups on stops before inserting
UPDATE networks.ov_stops stop SET
	platform_code = stop_id,
	parent_station = stop_groups.group_id
	FROM stop_groups
	WHERE stop.stop_id = ANY(stop_groups.stop_ids)
;
-- update id of stops in groups
UPDATE networks.ov_stops stop SET
	stop_id = stop_groups.group_id||'_'||array_search(stop.platform_code, stop_groups.stop_ids)::text 
	FROM stop_groups
	WHERE stop.stop_id = ANY(stop_groups.stop_ids)
;
-- insert stop groups in stops table
INSERT INTO networks.ov_stops (geom, stop_id, stop_name, stop_descr, location_type, 
	tram, metro, trein, bus, veerboot)
	SELECT geom, group_id, stop_name, stop_descr, location_type, tram, metro, trein, bus, veerboot
	FROM stop_groups
;
-- update stop_id of stop_times
UPDATE networks.ov_stop_times AS times SET
	stop_id = stops.stop_id
	FROM (SELECT * FROM networks.ov_stops WHERE parent_station IS NOT NULL AND trein IS NULL) AS stops
	WHERE times.stop_id = stops.platform_code
;
-- add stop groups to stop_times
UPDATE networks.ov_stop_times AS times SET 
	group_id = CASE 
		WHEN stops.parent_station IS NULL THEN times.stop_id
		ELSE stops.parent_station
		END
	FROM networks.ov_stops AS stops
	WHERE times.stop_id = stops.stop_id
;

-- links
-- important to get the topology in terms of links, as pairs of stops that are connected by a given trip/mode
-- DROP TABLE networks.ov_all_links CASCADE;
CREATE TABLE networks.ov_all_links(
	sid serial NOT NULL PRIMARY KEY,
	geom geometry(Linestring, 28992),
	trip_id character varying,
	trip_mode character varying,
	route_number character varying,
	trip_sequence integer,
	start_stop_id character varying,
	end_stop_id character varying,
	start_stop_time integer,
	end_stop_time integer,
	duration_in_secs integer
);
INSERT INTO networks.ov_all_links(geom, trip_id, trip_mode, route_number, trip_sequence, 
		start_stop_id, end_stop_id, 
		start_stop_time, end_stop_time, duration_in_secs)
	SELECT ST_MAKELINE(geom,geom2), trip_id, trip_mode, route_number, trip_sequence, 
		start_stop_id, end_stop_id, 
		stop1_time, stop2_time, stop2_time-stop1_time
	FROM (
		SELECT 
			times.trip_id, trips.route_type trip_mode, trips.route_short_name route_number,
			row_number() OVER w AS trip_sequence, 
			stops.geom, lead(stops.geom) OVER w AS geom2,
			times.stop_id AS start_stop_id,
			lead(times.stop_id) OVER w AS end_stop_id, 
			times.departure_in_secs AS stop1_time,
			lead(times.arrival_in_secs) OVER w AS stop2_time
		FROM (SELECT * FROM networks.ov_stop_times 
			WHERE (pickup_type IS NULL OR pickup_type < 2) 
			AND (drop_off_type IS NULL OR drop_off_type < 2)) times
		JOIN (SELECT trip_id, route_short_name, route_type FROM networks.ov_trips) trips
		USING (trip_id)
		JOIN (SELECT stop_id, geom FROM networks.ov_stops) stops
		USING (stop_id)
		WINDOW w AS (PARTITION BY times.trip_id ORDER BY times.stop_sequence)
	  ) as stop_times
	WHERE geom2 IS NOT NULL
;
CREATE INDEX ov_all_links_geom_idx ON networks.ov_all_links USING GIST(geom);

--
-- links, using stop groups where available
-- DROP TABLE networks.ov_links CASCADE;
CREATE TABLE networks.ov_links(
	sid serial NOT NULL PRIMARY KEY,
	geom geometry(Linestring, 28992),
	trip_id character varying,
	trip_mode character varying,
	route_number character varying,
	trip_sequence integer,
	start_stop_id character varying,
	end_stop_id character varying,
	start_stop_time integer,
	end_stop_time integer,
	duration_in_secs integer
);
INSERT INTO networks.ov_links(geom, trip_id, trip_mode, route_number, trip_sequence, 
		start_stop_id, end_stop_id, 
		start_stop_time, end_stop_time, duration_in_secs)
	SELECT ST_MAKELINE(geom,geom2), trip_id, trip_mode, route_number, trip_sequence, 
		start_stop_id, end_stop_id, 
		stop1_time, stop2_time, stop2_time-stop1_time
	FROM (
		SELECT 
			times.trip_id, trips.route_type trip_mode, trips.route_short_name route_number,
			row_number() OVER w AS trip_sequence, 
			stops.geom, lead(stops.geom) OVER w AS geom2,
			times.stop_id AS start_stop_id,
			lead(times.stop_id) OVER w AS end_stop_id, 
			times.departure_in_secs AS stop1_time,
			lead(times.arrival_in_secs) OVER w AS stop2_time
		FROM (SELECT * FROM networks.ov_stop_times 
			WHERE (pickup_type IS NULL OR pickup_type < 2) 
			AND (drop_off_type IS NULL OR drop_off_type < 2)) times
		JOIN (SELECT trip_id, route_short_name, route_type FROM networks.ov_trips) trips
		USING (trip_id)
		JOIN (SELECT stop_id, geom FROM networks.ov_stops) stops
		ON (stops.stop_id = times.group_id)
		WINDOW w AS (PARTITION BY times.trip_id ORDER BY times.stop_sequence)
	  ) as stop_times
	WHERE geom2 IS NOT NULL
;
CREATE INDEX ov_links_geom_idx ON networks.ov_links USING GIST(geom);
-- these are complete trips' geometries
-- DROP TABLE networks.ov_routes CASCADE;
CREATE TABLE networks.ov_routes(
	sid serial NOT NULL PRIMARY KEY,
	geom geometry(Linestring, 28992),
	route_id character varying,
	route_name character varying,
	route_mode character varying,
	route_duration varchar
);
INSERT INTO networks.ov_routes(geom, route_id, route_name, route_mode, route_duration)
	SELECT geom, routes.route_id, min(routes.route_short_name), min(trips.trip_mode),
		(to_char(floor(avg(trips.trip_duration)/3600),'fm00')||':'||
		to_char(floor(avg(trips.trip_duration)/60 % 60),'fm00')||':'||
		to_char(floor(avg(trips.trip_duration) % 60),'fm00'))
	FROM (
		SELECT ST_MakeLine(links.geom) geom, links.trip_id, min(links.trip_mode) AS trip_mode, 
			sum(links.duration_in_secs) AS trip_duration
		FROM (SELECT geom, trip_id, trip_mode, trip_sequence, duration_in_secs
			FROM networks.ov_links
			ORDER BY trip_id, trip_sequence
		) links
		GROUP BY links.trip_id
	) AS trips
	JOIN networks.ov_trips as routes
	USING(trip_id)
	GROUP BY geom, routes.route_id, trip_mode
;
CREATE INDEX ov_routes_geom_idx ON networks.ov_routes USING GIST(geom);

--
-- create stop areas based on name
-- useful for aggregating stops groups and stops of different modes for transfers
-- the results are added to a stop_area column in the stops table
-- DROP TABLE networks.ov_stop_areas CASCADE;
CREATE TABLE networks.ov_stop_areas (
	sid serial NOT NULL PRIMARY KEY,
	geom geometry(MultiPoint, 28992),
	area_name character varying,
	alt_name character varying,
	area_location character varying
);
-- areas of different modes (non rail)
INSERT INTO networks.ov_stop_areas (geom, area_name, alt_name, area_location)
	SELECT ST_Multi(ST_Centroid(area.geom)), area.stop_name, area.stop_name, area.stop_descr
	FROM (
		SELECT ST_Collect(geom) geom, stop_name, stop_descr, count(*) count
		FROM networks.ov_stops 
		WHERE parent_station IS NULL
		GROUP BY stop_name, stop_descr
	) area
	WHERE area.count > 1
;
-- areas around rail stations (use the name and geometry from the Maakplaats set of stations)
INSERT INTO networks.ov_stop_areas (geom, area_name, alt_name, area_location)
	SELECT vdm.geom, stops.stop_name, vdm.station, stops.stop_descr
	FROM (
		SELECT * FROM networks.ov_stops
		WHERE stop_code IS NOT NULL 
		AND parent_station IS NULL 
		AND trein = True
		) stops
	JOIN sources.rws_treinstations_2015_pnh vdm
	ON (stops.stop_code = vdm.code) 
;
-- update stops with corresponding stop area
-- UPDATE networks.ov_stops SET stop_area=NULL;
-- stations and platforms
UPDATE networks.ov_stops AS stop SET stop_area=areas.sid
	FROM networks.ov_stop_areas AS areas
	WHERE trein = TRUE --AND parent_station IS NULL
	AND stop.stop_name = areas.area_name
;
-- stops that have same name and location as stop area
UPDATE networks.ov_stops AS stop SET stop_area=areas.sid
	FROM networks.ov_stop_areas AS areas
	WHERE stop.trein IS NULL
	AND stop.stop_name = areas.area_name
	AND stop.stop_descr = areas.area_location
;
-- stops that are in station areas with different name
-- Station is appended
UPDATE networks.ov_stops AS stop SET stop_area=areas.sid
	FROM networks.ov_stop_areas AS areas
	WHERE stop.trein IS NULL AND stop.stop_area IS NULL
	AND stop.stop_name = 'Station '||areas.area_name
;
UPDATE networks.ov_stops AS stop SET stop_area=areas.sid
	FROM networks.ov_stop_areas AS areas
	WHERE stop.trein IS NULL AND stop.stop_area IS NULL
	AND stop.stop_name||' '||stop.stop_descr = 'Station '||areas.area_name
;
-- station name has city at the start, plus common name
UPDATE networks.ov_stops AS stop SET stop_area=areas.sid
	FROM networks.ov_stop_areas AS areas
	WHERE stop.trein IS NULL AND stop.stop_area IS NULL
	AND position('Station ' in stop.stop_name) > 0
	AND stop_descr||' '||substring(stop.stop_name from 9) = areas.area_name
;
-- other exceptions
UPDATE networks.ov_stops AS stop SET stop_area=areas.sid
	FROM networks.ov_stop_areas AS areas
	WHERE stop.trein IS NULL AND stop.stop_area IS NULL
	AND split_part(stop.stop_descr,' ',1)||' '||stop.stop_name = areas.area_name||' Station'
;
UPDATE networks.ov_stops AS stop SET stop_area=areas.sid
	FROM networks.ov_stop_areas AS areas
	WHERE stop.trein IS NULL AND stop.stop_area IS NULL
	AND stop.stop_name = 'Station '||replace(areas.area_name, '-', ' ') 
;
UPDATE networks.ov_stops AS stop SET stop_area=areas.sid
	FROM networks.ov_stop_areas AS areas
	WHERE stop.trein IS NULL AND stop.stop_area IS NULL
	AND (position('CS' in stop.stop_name) > 0 
		AND stop.stop_descr = 'Amsterdam' 
		AND areas.area_name = 'Amsterdam Centraal')
; 
-- unique cases
UPDATE networks.ov_stops AS stop SET stop_area=areas.sid
	FROM networks.ov_stop_areas AS areas
	WHERE stop.trein IS NULL AND stop.stop_area IS NULL
	AND (stop.stop_name='Airport'AND areas.area_name = 'Schiphol')
	OR (stop.stop_name='Station Zuid'
		AND stop.stop_descr = 'Santpoort Zuid'
		AND  areas.area_name = 'Santpoort Zuid')
	OR (stop.stop_name='Station'
		AND stop.stop_descr = 'Zandvoort'
		AND  areas.area_name = 'Zandvoort aan Zee')
	OR (stop.stop_name='Station Boven'
		AND stop.stop_descr = 'Hoofddorp'
		AND  areas.area_name = 'Hoofddorp')
	OR (stop.stop_name='Station Beneden'
		AND stop.stop_descr = 'Hoofddorp'
		AND  areas.area_name = 'Hoofddorp')
	OR (stop.stop_name='Mediapark'
		AND stop.stop_descr = 'Hilversum'
		AND  areas.area_name = 'Hilversum Media Park')
	OR (stop.stop_name='Veer Centraal Station'
		AND stop.stop_descr = 'Amsterdam'
		AND  areas.area_name = 'Amsterdam Centraal')
	OR (stop.stop_name='Station'
		AND stop.stop_descr = 'Bovenkarspel'
		AND  areas.area_name = 'Bovenkarspel-Grootebroek')
	OR (stop.stop_name='Station NS Zuid Westzijde'
		AND stop.stop_descr = 'Den Helder'
		AND  areas.area_name = 'Den Helder Zuid')
	OR (stop.stop_name='Station Krommenie-Assendelft (Provincialeweg)'
		AND  areas.area_name = 'Krommenie-Assendelft')
	OR (stop.stop_name='Station Koog Zaandijk'
		AND  areas.area_name = 'Zaanse Schans')
;
