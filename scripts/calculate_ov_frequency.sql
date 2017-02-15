-- ov frequency analysis, for every stop of every mode
CREATE SCHEMA ov_network_analysis;

/* number of services in stop groups, and stop areas in the case of railway stations, 
aggregating platforms/sides of road. frequency per hour on:
 ochtendspits (06:30 to 09:00), middagdal (11:00 to 14:00) and avondspits (16:00 to 18:30)
*/
-- DROP TABLE ov_network_analysis.ov_frequency CASCADE;
CREATE TABLE ov_network_analysis.ov_frequency(
	sid serial NOT NULL PRIMARY KEY,
	geom geometry(Point, 28992),
	stop_id character varying,
	stop_area integer,
	stop_name character varying,
	stop_descr character varying,
	tram boolean,
	metro boolean,
	trein boolean,
	bus boolean,
	veerboot boolean,
	bus_ochtendspits double precision,
	bus_middagdal double precision,
	bus_avondspits double precision,
	tram_ochtendspits double precision,
	tram_middagdal double precision,
	tram_avondspits double precision,
	metro_ochtendspits double precision,
	metro_middagdal double precision,
	metro_avondspits double precision,
	veer_ochtendspits double precision,
	veer_middagdal double precision,
	veer_avondspits double precision,
	trein_ochtendspits double precision,
	trein_middagdal double precision,
	trein_avondspits double precision,
	hsl_ochtendspits double precision,
	hsl_middagdal double precision,
	hsl_avondspits double precision,
	ic_ochtendspits double precision,
	ic_middagdal double precision,
	ic_avondspits double precision,
	spr_ochtendspits double precision,
	spr_middagdal double precision,
	spr_avondspits double precision
);
INSERT INTO ov_network_analysis.ov_frequency(geom, stop_id, stop_area, stop_name, stop_descr, 
	tram, metro, trein, bus, veerboot)
	SELECT geom, stop_id, stop_area, stop_name, stop_descr, tram, metro, trein, bus, veerboot
	FROM networks.ov_stops
	WHERE parent_station IS NULL
;

-- must get value for any weekday, as services only record one day of the week
-- cannot have double count times for same trip on same day of the week (e.g. different dates)
-- this function calculates the frequency given a time period (times in seconds) and transport mode
-- it aggregates the trips at parent station level (station or group of stops)
CREATE OR REPLACE FUNCTION ov_group_frequency(
	start_time_in_secs integer, 
	end_time_in_secs integer, 
	transport_mode varchar[],
	transport_type varchar[] DEFAULT ARRAY[''],
	day_of_week varchar[] DEFAULT ARRAY['monday','tuesday','wednesday','thursday','friday'],
	OUT stop_id varchar,
	OUT frequency numeric)
	RETURNS SETOF record AS
$$
	SELECT b.parent_station AS stop_id, sum(a.total) AS frequency
		FROM (SELECT c.stop_id, round(count(*)::numeric/(($2-$1)/3600::numeric),2) total 
			FROM (SELECT DISTINCT ON (stop_id, departure_time) stop_id, departure_time 
				FROM networks.ov_stop_times
				WHERE (pickup_type = 0 OR pickup_type IS NULL)
				AND (departure_in_secs >= $1 AND departure_in_secs <= $2)
				AND trip_id IN 
					(SELECT trip_id 
					FROM networks.ov_trips 
					WHERE route_type = ANY($3) AND route_long_name = ANY($4)
					AND day_of_week = ANY($5)
					)
				) c
			GROUP BY c.stop_id
		) a,
		(SELECT stop_id, parent_station 
			FROM networks.ov_stops 
			WHERE parent_station IS NOT NULL
		) b
		WHERE a.stop_id=b.stop_id
		GROUP BY b.parent_station
$$ LANGUAGE sql IMMUTABLE STRICT;
-- this function calculates the frequency given a time period (times in seconds) and transport mode
-- it aggregates the trips at stop area level (group of stations and stop groups)
CREATE OR REPLACE FUNCTION ov_area_frequency(
	start_time_in_secs integer, 
	end_time_in_secs integer, 
	transport_mode varchar[],
	transport_type varchar[] DEFAULT ARRAY[''],
	day_of_week varchar[] DEFAULT ARRAY['monday','tuesday','wednesday','thursday','friday'],
	OUT area_id integer,
	OUT frequency numeric)
	RETURNS SETOF record AS
$$
	SELECT b.stop_area AS area_id, sum(a.total) AS frequency
		FROM (SELECT c.stop_id, round(count(*)::numeric/(($2-$1)/3600::numeric),2) total 
			FROM (SELECT DISTINCT ON (stop_id, departure_time) stop_id, departure_time 
				FROM networks.ov_stop_times
				WHERE (pickup_type = 0 OR pickup_type IS NULL)
				AND (departure_in_secs >= $1 AND departure_in_secs <= $2)
				AND trip_id IN 
					(SELECT trip_id 
					FROM networks.ov_trips 
					WHERE route_type = ANY($3) AND route_long_name = ANY($4)
					AND day_of_week = ANY($5)
					)
				) c
			GROUP BY c.stop_id
		) a,
		(SELECT stop_id, stop_area 
			FROM networks.ov_stops 
			WHERE stop_area IS NOT NULL
			AND parent_station IS NOT NULL
		) b
		WHERE a.stop_id=b.stop_id
		GROUP BY b.stop_area
$$ LANGUAGE sql IMMUTABLE STRICT;
--ochtend_spits
UPDATE ov_network_analysis.ov_frequency freq SET
	bus_ochtendspits = trips.frequency
	FROM ov_group_frequency(
		EXTRACT(EPOCH FROM INTERVAL '06:30:00'::interval)::integer,
		EXTRACT(EPOCH FROM INTERVAL '09:00:00'::interval)::integer,
		ARRAY['bus']
	) AS trips
	WHERE freq.stop_id = trips.stop_id
;
UPDATE ov_network_analysis.ov_frequency freq SET
	tram_ochtendspits = trips.frequency
	FROM ov_group_frequency(
		EXTRACT(EPOCH FROM INTERVAL '06:30:00'::interval)::integer,
		EXTRACT(EPOCH FROM INTERVAL '09:00:00'::interval)::integer,
		ARRAY['tram']
	) AS trips
	WHERE freq.stop_id = trips.stop_id
;
UPDATE ov_network_analysis.ov_frequency freq SET
	metro_ochtendspits = trips.frequency
	FROM ov_group_frequency(
		EXTRACT(EPOCH FROM INTERVAL '06:30:00'::interval)::integer,
		EXTRACT(EPOCH FROM INTERVAL '09:00:00'::interval)::integer,
		ARRAY['metro']
	) AS trips
	WHERE freq.stop_id = trips.stop_id
;
UPDATE ov_network_analysis.ov_frequency freq SET
	veer_ochtendspits = trips.frequency
	FROM ov_group_frequency(
		EXTRACT(EPOCH FROM INTERVAL '06:30:00'::interval)::integer,
		EXTRACT(EPOCH FROM INTERVAL '09:00:00'::interval)::integer,
		ARRAY['veerboot']
	) AS trips
	WHERE freq.stop_id = trips.stop_id
;
UPDATE ov_network_analysis.ov_frequency freq SET
	trein_ochtendspits = trips.frequency
	FROM ov_group_frequency(
		EXTRACT(EPOCH FROM INTERVAL '06:30:00'::interval)::integer,
		EXTRACT(EPOCH FROM INTERVAL '09:00:00'::interval)::integer,
		ARRAY['trein'], ARRAY['Thalys','ICE','Intercity direct','Intercity',
		'Sprinter','Snelbus i.p.v trein','Stopbus i.p.v trein','']
	) AS trips
	WHERE freq.stop_id = trips.stop_id
;
-- middag_dal
UPDATE ov_network_analysis.ov_frequency freq SET
	bus_middagdal = trips.frequency
	FROM ov_group_frequency(
		EXTRACT(EPOCH FROM INTERVAL '11:30:00'::interval)::integer,
		EXTRACT(EPOCH FROM INTERVAL '14:00:00'::interval)::integer,
		ARRAY['bus']
	) AS trips
	WHERE freq.stop_id = trips.stop_id
;
UPDATE ov_network_analysis.ov_frequency freq SET
	tram_middagdal = trips.frequency
	FROM ov_group_frequency(
		EXTRACT(EPOCH FROM INTERVAL '11:30:00'::interval)::integer,
		EXTRACT(EPOCH FROM INTERVAL '14:00:00'::interval)::integer,
		ARRAY['tram']
	) AS trips
	WHERE freq.stop_id = trips.stop_id
;
UPDATE ov_network_analysis.ov_frequency freq SET
	metro_middagdal = trips.frequency
	FROM ov_group_frequency(
		EXTRACT(EPOCH FROM INTERVAL '11:30:00'::interval)::integer,
		EXTRACT(EPOCH FROM INTERVAL '14:00:00'::interval)::integer,
		ARRAY['metro']
	) AS trips
	WHERE freq.stop_id = trips.stop_id
;
UPDATE ov_network_analysis.ov_frequency freq SET
	veer_middagdal = trips.frequency
	FROM ov_group_frequency(
		EXTRACT(EPOCH FROM INTERVAL '11:30:00'::interval)::integer,
		EXTRACT(EPOCH FROM INTERVAL '14:00:00'::interval)::integer,
		ARRAY['veerboot']
	) AS trips
	WHERE freq.stop_id = trips.stop_id
;
UPDATE ov_network_analysis.ov_frequency freq SET
	trein_middagdal = trips.frequency
	FROM ov_group_frequency(
		EXTRACT(EPOCH FROM INTERVAL '11:30:00'::interval)::integer,
		EXTRACT(EPOCH FROM INTERVAL '14:00:00'::interval)::integer,
		ARRAY['trein'], ARRAY['Thalys','ICE','Intercity direct','Intercity',
		'Sprinter','Snelbus i.p.v trein','Stopbus i.p.v trein','']
	) AS trips
	WHERE freq.stop_id = trips.stop_id
;
-- avond_spits
UPDATE ov_network_analysis.ov_frequency freq SET
	bus_avondspits = trips.frequency
	FROM ov_group_frequency(
		EXTRACT(EPOCH FROM INTERVAL '16:00:00'::interval)::integer,
		EXTRACT(EPOCH FROM INTERVAL '18:30:00'::interval)::integer,
		ARRAY['bus']
	) AS trips
	WHERE freq.stop_id = trips.stop_id
;
UPDATE ov_network_analysis.ov_frequency freq SET
	tram_avondspits = trips.frequency
	FROM ov_group_frequency(
		EXTRACT(EPOCH FROM INTERVAL '16:00:00'::interval)::integer,
		EXTRACT(EPOCH FROM INTERVAL '18:30:00'::interval)::integer,
		ARRAY['tram']
	) AS trips
	WHERE freq.stop_id = trips.stop_id
;
UPDATE ov_network_analysis.ov_frequency freq SET
	metro_avondspits = trips.frequency
	FROM ov_group_frequency(
		EXTRACT(EPOCH FROM INTERVAL '16:00:00'::interval)::integer,
		EXTRACT(EPOCH FROM INTERVAL '18:30:00'::interval)::integer,
		ARRAY['metro']
	) AS trips
	WHERE freq.stop_id = trips.stop_id
;
UPDATE ov_network_analysis.ov_frequency freq SET
	veer_avondspits = trips.frequency
	FROM ov_group_frequency(
		EXTRACT(EPOCH FROM INTERVAL '16:00:00'::interval)::integer,
		EXTRACT(EPOCH FROM INTERVAL '18:30:00'::interval)::integer,
		ARRAY['veerboot']
	) AS trips
	WHERE freq.stop_id = trips.stop_id
;
UPDATE ov_network_analysis.ov_frequency freq SET
	trein_avondspits = trips.frequency
	FROM ov_group_frequency(
		EXTRACT(EPOCH FROM INTERVAL '16:00:00'::interval)::integer,
		EXTRACT(EPOCH FROM INTERVAL '18:30:00'::interval)::integer,
		ARRAY['trein'], ARRAY['Thalys','ICE','Intercity direct','Intercity',
		'Sprinter','Snelbus i.p.v trein','Stopbus i.p.v trein','']
	) AS trips
	WHERE freq.stop_id = trips.stop_id
;
-- for hsl
UPDATE ov_network_analysis.ov_frequency freq SET
	hsl_ochtendspits = trips.frequency
	FROM ov_group_frequency(
		EXTRACT(EPOCH FROM INTERVAL '06:30:00'::interval)::integer,
		EXTRACT(EPOCH FROM INTERVAL '09:00:00'::interval)::integer,
		ARRAY['trein'], ARRAY['Thalys','ICE','Intercity direct']
	) AS trips
	WHERE freq.stop_id = trips.stop_id
;
UPDATE ov_network_analysis.ov_frequency freq SET
	hsl_middagdal = trips.frequency
	FROM ov_group_frequency(
		EXTRACT(EPOCH FROM INTERVAL '11:30:00'::interval)::integer,
		EXTRACT(EPOCH FROM INTERVAL '14:00:00'::interval)::integer,
		ARRAY['trein'], ARRAY['Thalys','ICE','Intercity direct']
	) AS trips
	WHERE freq.stop_id = trips.stop_id
;
UPDATE ov_network_analysis.ov_frequency freq SET
	hsl_avondspits = trips.frequency
	FROM ov_group_frequency(
		EXTRACT(EPOCH FROM INTERVAL '16:00:00'::interval)::integer,
		EXTRACT(EPOCH FROM INTERVAL '18:30:00'::interval)::integer,
		ARRAY['trein'], ARRAY['Thalys','ICE','Intercity direct']
	) AS trips
	WHERE freq.stop_id = trips.stop_id
;
-- for intercity
UPDATE ov_network_analysis.ov_frequency freq SET
	ic_ochtendspits = trips.frequency
	FROM ov_group_frequency(
		EXTRACT(EPOCH FROM INTERVAL '06:30:00'::interval)::integer,
		EXTRACT(EPOCH FROM INTERVAL '09:00:00'::interval)::integer,
		ARRAY['trein'], ARRAY['Intercity']
	) AS trips
	WHERE freq.stop_id = trips.stop_id
;
UPDATE ov_network_analysis.ov_frequency freq SET
	ic_middagdal = trips.frequency
	FROM ov_group_frequency(
		EXTRACT(EPOCH FROM INTERVAL '11:30:00'::interval)::integer,
		EXTRACT(EPOCH FROM INTERVAL '14:00:00'::interval)::integer,
		ARRAY['trein'], ARRAY['Intercity']
	) AS trips
	WHERE freq.stop_id = trips.stop_id
;
UPDATE ov_network_analysis.ov_frequency freq SET
	ic_avondspits = trips.frequency
	FROM ov_group_frequency(
		EXTRACT(EPOCH FROM INTERVAL '16:00:00'::interval)::integer,
		EXTRACT(EPOCH FROM INTERVAL '18:30:00'::interval)::integer,
		ARRAY['trein'], ARRAY['Intercity']
	) AS trips
	WHERE freq.stop_id = trips.stop_id
;
-- for sprinter
UPDATE ov_network_analysis.ov_frequency freq SET
	spr_ochtendspits = trips.frequency
	FROM ov_group_frequency(
		EXTRACT(EPOCH FROM INTERVAL '06:30:00'::interval)::integer,
		EXTRACT(EPOCH FROM INTERVAL '09:00:00'::interval)::integer,
		ARRAY['trein'], ARRAY['Sprinter','Snelbus i.p.v trein','Stopbus i.p.v trein']
	) AS trips
	WHERE freq.stop_id = trips.stop_id
;
UPDATE ov_network_analysis.ov_frequency freq SET
	spr_middagdal = trips.frequency
	FROM ov_group_frequency(
		EXTRACT(EPOCH FROM INTERVAL '11:30:00'::interval)::integer,
		EXTRACT(EPOCH FROM INTERVAL '14:00:00'::interval)::integer,
		ARRAY['trein'], ARRAY['Sprinter','Snelbus i.p.v trein','Stopbus i.p.v trein']
	) AS trips
	WHERE freq.stop_id = trips.stop_id
;
UPDATE ov_network_analysis.ov_frequency freq SET
	spr_avondspits = trips.frequency
	FROM ov_group_frequency(
		EXTRACT(EPOCH FROM INTERVAL '16:00:00'::interval)::integer,
		EXTRACT(EPOCH FROM INTERVAL '18:30:00'::interval)::integer,
		ARRAY['trein'], ARRAY['Sprinter','Snelbus i.p.v trein','Stopbus i.p.v trein']
	) AS trips
	WHERE freq.stop_id = trips.stop_id
;
-- for trein stop areas
--ochtend_spits
UPDATE ov_network_analysis.ov_frequency freq SET
	bus_ochtendspits = trips.frequency
	FROM ov_area_frequency(
		EXTRACT(EPOCH FROM INTERVAL '06:30:00'::interval)::integer,
		EXTRACT(EPOCH FROM INTERVAL '09:00:00'::interval)::integer,
		ARRAY['bus']
	) AS trips
	WHERE freq.trein = TRUE AND freq.stop_area = trips.area_id
;
UPDATE ov_network_analysis.ov_frequency freq SET
	tram_ochtendspits = trips.frequency
	FROM ov_area_frequency(
		EXTRACT(EPOCH FROM INTERVAL '06:30:00'::interval)::integer,
		EXTRACT(EPOCH FROM INTERVAL '09:00:00'::interval)::integer,
		ARRAY['tram']
	) AS trips
	WHERE freq.trein = TRUE AND freq.stop_area = trips.area_id
;
UPDATE ov_network_analysis.ov_frequency freq SET
	metro_ochtendspits = trips.frequency
	FROM ov_area_frequency(
		EXTRACT(EPOCH FROM INTERVAL '06:30:00'::interval)::integer,
		EXTRACT(EPOCH FROM INTERVAL '09:00:00'::interval)::integer,
		ARRAY['metro']
	) AS trips
	WHERE freq.trein = TRUE AND freq.stop_area = trips.area_id
;
UPDATE ov_network_analysis.ov_frequency freq SET
	veer_ochtendspits = trips.frequency
	FROM ov_area_frequency(
		EXTRACT(EPOCH FROM INTERVAL '06:30:00'::interval)::integer,
		EXTRACT(EPOCH FROM INTERVAL '09:00:00'::interval)::integer,
		ARRAY['veerboot']
	) AS trips
	WHERE freq.trein = TRUE AND freq.stop_area = trips.area_id
;
-- middag_dal
UPDATE ov_network_analysis.ov_frequency freq SET
	bus_middagdal = trips.frequency
	FROM ov_area_frequency(
		EXTRACT(EPOCH FROM INTERVAL '11:30:00'::interval)::integer,
		EXTRACT(EPOCH FROM INTERVAL '14:00:00'::interval)::integer,
		ARRAY['bus']
	) AS trips
	WHERE freq.trein = TRUE AND freq.stop_area = trips.area_id
;
UPDATE ov_network_analysis.ov_frequency freq SET
	tram_middagdal = trips.frequency
	FROM ov_area_frequency(
		EXTRACT(EPOCH FROM INTERVAL '11:30:00'::interval)::integer,
		EXTRACT(EPOCH FROM INTERVAL '14:00:00'::interval)::integer,
		ARRAY['tram']
	) AS trips
	WHERE freq.trein = TRUE AND freq.stop_area = trips.area_id
;
UPDATE ov_network_analysis.ov_frequency freq SET
	metro_middagdal = trips.frequency
	FROM ov_area_frequency(
		EXTRACT(EPOCH FROM INTERVAL '11:30:00'::interval)::integer,
		EXTRACT(EPOCH FROM INTERVAL '14:00:00'::interval)::integer,
		ARRAY['metro']
	) AS trips
	WHERE freq.trein = TRUE AND freq.stop_area = trips.area_id
;
UPDATE ov_network_analysis.ov_frequency freq SET
	veer_middagdal = trips.frequency
	FROM ov_area_frequency(
		EXTRACT(EPOCH FROM INTERVAL '11:30:00'::interval)::integer,
		EXTRACT(EPOCH FROM INTERVAL '14:00:00'::interval)::integer,
		ARRAY['veerboot']
	) AS trips
	WHERE freq.trein = TRUE AND freq.stop_area = trips.area_id
;
-- avond_spits
UPDATE ov_network_analysis.ov_frequency freq SET
	bus_avondspits = trips.frequency
	FROM ov_area_frequency(
		EXTRACT(EPOCH FROM INTERVAL '16:00:00'::interval)::integer,
		EXTRACT(EPOCH FROM INTERVAL '18:30:00'::interval)::integer,
		ARRAY['bus']
	) AS trips
	WHERE freq.trein = TRUE AND freq.stop_area = trips.area_id
;
UPDATE ov_network_analysis.ov_frequency freq SET
	tram_avondspits = trips.frequency
	FROM ov_area_frequency(
		EXTRACT(EPOCH FROM INTERVAL '16:00:00'::interval)::integer,
		EXTRACT(EPOCH FROM INTERVAL '18:30:00'::interval)::integer,
		ARRAY['tram']
	) AS trips
	WHERE freq.trein = TRUE AND freq.stop_area = trips.area_id
;
UPDATE ov_network_analysis.ov_frequency freq SET
	metro_avondspits = trips.frequency
	FROM ov_area_frequency(
		EXTRACT(EPOCH FROM INTERVAL '16:00:00'::interval)::integer,
		EXTRACT(EPOCH FROM INTERVAL '18:30:00'::interval)::integer,
		ARRAY['metro']
	) AS trips
	WHERE freq.trein = TRUE AND freq.stop_area = trips.area_id
;
UPDATE ov_network_analysis.ov_frequency freq SET
	veer_avondspits = trips.frequency
	FROM ov_area_frequency(
		EXTRACT(EPOCH FROM INTERVAL '16:00:00'::interval)::integer,
		EXTRACT(EPOCH FROM INTERVAL '18:30:00'::interval)::integer,
		ARRAY['veerboot']
	) AS trips
	WHERE freq.trein = TRUE AND freq.stop_area = trips.area_id
;


-- number of services on avond spits along each link
-- links frequency
-- DROP TABLE ov_network_analysis.links_frequency CASCADE;
CREATE TABLE ov_network_analysis.links_frequency(
	sid serial NOT NULL PRIMARY KEY,
	geom geometry(Linestring, 28992),
	trip_mode character varying,
	start_stop_id character varying,
	end_stop_id character varying,
	mean_duration_in_secs integer,
	totaal_week integer,
	totaal_weekend integer,
	freq_spits_morgen double precision,
	freq_dal_middag double precision,
	freq_spits_avond double precision
);
INSERT INTO ov_network_analysis.links_frequency (geom, trip_mode, start_stop_id, end_stop_id, mean_duration_in_secs)
	SELECT geom, trip_mode, start_stop_id, end_stop_id, avg(duration_in_secs)
	FROM study.ov_links
	GROUP BY geom, trip_mode, start_stop_id, end_stop_id
;
-- week
UPDATE ov_network_analysis.links_frequency freq SET
	totaal_week = trips.total
	FROM (SELECT a.trip_mode, a.start_stop_id, a.end_stop_id, count(*) total 
		FROM (SELECT trip_mode, start_stop_id, end_stop_id FROM study.ov_links
			WHERE trip_id IN (SELECT trip_id FROM study.ov_trips WHERE day_of_week not in ('saturday','sunday'))
			GROUP BY trip_mode, start_stop_id, end_stop_id, start_stop_time
		) a
		GROUP BY trip_mode, start_stop_id, end_stop_id
	) trips
	WHERE freq.trip_mode = trips.trip_mode
	AND freq.start_stop_id = trips.start_stop_id
	AND freq.end_stop_id = trips.end_stop_id
;
UPDATE ov_network_analysis.links_frequency SET totaal_week = 0 WHERE totaal_week IS NULL;
-- weekend
UPDATE ov_network_analysis.links_frequency freq SET
	totaal_weekend = trips.total
	FROM (SELECT a.trip_mode, a.start_stop_id, a.end_stop_id, count(*) total 
		FROM (SELECT trip_mode, start_stop_id, end_stop_id FROM study.ov_links
			WHERE trip_id IN (SELECT trip_id FROM study.ov_trips WHERE day_of_week ='saturday')
			GROUP BY trip_mode, start_stop_id, end_stop_id, start_stop_time
		) a
		GROUP BY trip_mode, start_stop_id, end_stop_id
	) trips
	WHERE freq.trip_mode = trips.trip_mode
	AND freq.start_stop_id = trips.start_stop_id
	AND freq.end_stop_id = trips.end_stop_id
;
UPDATE ov_network_analysis.links_frequency SET totaal_weekend = 0 WHERE totaal_weekend IS NULL;
-- freq_spits_morgen
UPDATE ov_network_analysis.links_frequency freq SET
	freq_spits_morgen = trips.total
	FROM (SELECT a.trip_mode, a.start_stop_id, a.end_stop_id, round(count(*)::numeric/2.5::numeric,2) total 
		FROM (SELECT trip_mode, start_stop_id, end_stop_id FROM study.ov_links
			WHERE (start_stop_time >= EXTRACT(EPOCH FROM INTERVAL '06:30:00') 
			AND start_stop_time <= EXTRACT(EPOCH FROM INTERVAL '09:00:00'))
			AND trip_id IN (SELECT trip_id FROM study.ov_trips WHERE day_of_week not in ('saturday','sunday'))
			GROUP BY trip_mode, start_stop_id, end_stop_id, start_stop_time
		) a
		GROUP BY trip_mode, start_stop_id, end_stop_id
	) trips
	WHERE freq.trip_mode = trips.trip_mode
	AND freq.start_stop_id = trips.start_stop_id
	AND freq.end_stop_id = trips.end_stop_id
;
UPDATE ov_network_analysis.links_frequency SET freq_spits_morgen = 0 WHERE freq_spits_morgen IS NULL;
-- freq_dal_middag
UPDATE ov_network_analysis.links_frequency freq SET
	freq_dal_middag = trips.total
	FROM (SELECT a.trip_mode, a.start_stop_id, a.end_stop_id, round(count(*)::numeric/2.5::numeric,2) total 
		FROM (SELECT trip_mode, start_stop_id, end_stop_id FROM study.ov_links
			WHERE (start_stop_time >= EXTRACT(EPOCH FROM INTERVAL '11:00:00') 
			AND start_stop_time <= EXTRACT(EPOCH FROM INTERVAL '14:00:00'))
			AND trip_id IN (SELECT trip_id FROM study.ov_trips WHERE day_of_week not in ('saturday','sunday'))
			GROUP BY trip_mode, start_stop_id, end_stop_id, start_stop_time
		) a
		GROUP BY trip_mode, start_stop_id, end_stop_id
	) trips
	WHERE freq.trip_mode = trips.trip_mode
	AND freq.start_stop_id = trips.start_stop_id
	AND freq.end_stop_id = trips.end_stop_id
;
UPDATE ov_network_analysis.links_frequency SET freq_dal_middag = 0 WHERE freq_dal_middag IS NULL;
-- freq_spits_avond
UPDATE ov_network_analysis.links_frequency freq SET
	freq_spits_avond = trips.total
	FROM (SELECT a.trip_mode, a.start_stop_id, a.end_stop_id, round(count(*)::numeric/2.5::numeric,2) total 
		FROM (SELECT trip_mode, start_stop_id, end_stop_id FROM study.ov_links
			WHERE (start_stop_time >= EXTRACT(EPOCH FROM INTERVAL '16:00:00') 
			AND start_stop_time <= EXTRACT(EPOCH FROM INTERVAL '18:30:00'))
			AND trip_id IN (SELECT trip_id FROM study.ov_trips WHERE day_of_week not in ('saturday','sunday'))
			GROUP BY trip_mode, start_stop_id, end_stop_id, start_stop_time
		) a
		GROUP BY trip_mode, start_stop_id, end_stop_id
	) trips
	WHERE freq.trip_mode = trips.trip_mode
	AND freq.start_stop_id = trips.start_stop_id
	AND freq.end_stop_id = trips.end_stop_id
;
UPDATE ov_network_analysis.links_frequency SET freq_spits_avond = 0 WHERE freq_spits_avond IS NULL;
