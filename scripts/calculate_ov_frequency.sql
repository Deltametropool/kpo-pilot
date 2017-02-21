-- KPO data system
-- author: Jorge Gil, 2017


-- ov frequency calculation, for every stop of every mode
/* number of services in stop groups, and stop areas in the case of railway stations, 
aggregating platforms/sides of road. frequency per hour on:
 ochtendspits (06:30 to 09:00), daluren (10:00 to 15:00) and avondspits (16:00 to 18:30)
*/

----
-- insert base stop informaiton
-- DELETE FROM datasysteem.ov_haltes;
INSERT INTO datasysteem.ov_haltes(geom, halte_id, halte_zone, halte_naam, halte_gemeente, 
	tram, metro, trein, bus, veerboot)
	SELECT geom, stop_id, stop_area, stop_name, stop_descr, tram, metro, trein, bus, veerboot
	FROM networks.ov_stops
	WHERE parent_station IS NULL
;

----
-- setup general functions to calculate frequency
-- must get value for any weekday, as services only record one day of the week
-- cannot have double count times for same trip on same day of the week (e.g. different dates)
-- this function calculates the frequency given a time period (times in seconds) and transport mode
-- it aggregates the trips at parent station level (station or group of stops)
CREATE OR REPLACE FUNCTION ov_group_frequency(
	start_time_in_secs integer, 
	end_time_in_secs integer, 
	transport_mode varchar[],
	transport_type varchar[] DEFAULT ARRAY[NULL,''],
	day_of_week varchar[] DEFAULT ARRAY['monday','tuesday','wednesday','thursday','friday'],
	OUT stop_id varchar,
	OUT frequency numeric)
	RETURNS SETOF record AS
$$
		SELECT a.group_id AS stop_id, round(count(*)::numeric/(($2-$1)/3600::numeric),2) AS frequency 
		FROM (SELECT DISTINCT ON (group_id, departure_time) group_id, departure_time 
			FROM networks.ov_stop_times
			WHERE (pickup_type = 0 OR pickup_type IS NULL)
			AND (departure_in_secs >= $1 AND departure_in_secs <= $2)
			AND trip_id IN 
				(SELECT trip_id 
				FROM networks.ov_trips 
				WHERE route_type = ANY($3) AND route_long_name = ANY($4)
				AND day_of_week = ANY($5)
				)
			) a
		GROUP BY a.group_id
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
		FROM (SELECT c.group_id, round(count(*)::numeric/(($2-$1)/3600::numeric),2) total 
			FROM (SELECT DISTINCT ON (group_id, departure_time) group_id, departure_time 
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
			GROUP BY c.group_id
		) a,
		(SELECT stop_id, stop_area 
			FROM networks.ov_stops 
			WHERE stop_area IS NOT NULL
			AND parent_station IS NULL
		) b
		WHERE a.group_id=b.stop_id
		GROUP BY b.stop_area
$$ LANGUAGE sql IMMUTABLE STRICT;
----
-- calculate frequency at stops (group and solo)
--ochtend_spits
UPDATE datasysteem.ov_haltes freq SET
	bus_ochtendspits = trips.frequency
	FROM ov_group_frequency(
		EXTRACT(EPOCH FROM INTERVAL '06:30:00'::interval)::integer,
		EXTRACT(EPOCH FROM INTERVAL '09:00:00'::interval)::integer,
		ARRAY['bus']
	) AS trips
	WHERE freq.halte_id = trips.stop_id
;
UPDATE datasysteem.ov_haltes freq SET
	tram_ochtendspits = trips.frequency
	FROM ov_group_frequency(
		EXTRACT(EPOCH FROM INTERVAL '06:30:00'::interval)::integer,
		EXTRACT(EPOCH FROM INTERVAL '09:00:00'::interval)::integer,
		ARRAY['tram']
	) AS trips
	WHERE freq.halte_id = trips.stop_id
;
UPDATE datasysteem.ov_haltes freq SET
	metro_ochtendspits = trips.frequency
	FROM ov_group_frequency(
		EXTRACT(EPOCH FROM INTERVAL '06:30:00'::interval)::integer,
		EXTRACT(EPOCH FROM INTERVAL '09:00:00'::interval)::integer,
		ARRAY['metro']
	) AS trips
	WHERE freq.halte_id = trips.stop_id
;
UPDATE datasysteem.ov_haltes freq SET
	veerboot_ochtendspits = trips.frequency
	FROM ov_group_frequency(
		EXTRACT(EPOCH FROM INTERVAL '06:30:00'::interval)::integer,
		EXTRACT(EPOCH FROM INTERVAL '09:00:00'::interval)::integer,
		ARRAY['veerboot']
	) AS trips
	WHERE freq.halte_id = trips.stop_id
;
UPDATE datasysteem.ov_haltes freq SET
	trein_ochtendspits = trips.frequency
	FROM ov_group_frequency(
		EXTRACT(EPOCH FROM INTERVAL '06:30:00'::interval)::integer,
		EXTRACT(EPOCH FROM INTERVAL '09:00:00'::interval)::integer,
		ARRAY['trein'], ARRAY['Thalys','ICE','Intercity direct','Intercity',
		'Sprinter','Snelbus i.p.v trein','Stopbus i.p.v trein','']
	) AS trips
	WHERE freq.halte_id = trips.stop_id
;
-- daluren
UPDATE datasysteem.ov_haltes freq SET
	bus_daluren = trips.frequency
	FROM ov_group_frequency(
		EXTRACT(EPOCH FROM INTERVAL '10:00:00'::interval)::integer,
		EXTRACT(EPOCH FROM INTERVAL '15:00:00'::interval)::integer,
		ARRAY['bus']
	) AS trips
	WHERE freq.halte_id = trips.stop_id
;
UPDATE datasysteem.ov_haltes freq SET
	tram_daluren = trips.frequency
	FROM ov_group_frequency(
		EXTRACT(EPOCH FROM INTERVAL '10:00:00'::interval)::integer,
		EXTRACT(EPOCH FROM INTERVAL '15:00:00'::interval)::integer,
		ARRAY['tram']
	) AS trips
	WHERE freq.halte_id = trips.stop_id
;
UPDATE datasysteem.ov_haltes freq SET
	metro_daluren = trips.frequency
	FROM ov_group_frequency(
		EXTRACT(EPOCH FROM INTERVAL '10:00:00'::interval)::integer,
		EXTRACT(EPOCH FROM INTERVAL '15:00:00'::interval)::integer,
		ARRAY['metro']
	) AS trips
	WHERE freq.halte_id = trips.stop_id
;
UPDATE datasysteem.ov_haltes freq SET
	veerboot_daluren = trips.frequency
	FROM ov_group_frequency(
		EXTRACT(EPOCH FROM INTERVAL '10:00:00'::interval)::integer,
		EXTRACT(EPOCH FROM INTERVAL '15:00:00'::interval)::integer,
		ARRAY['veerboot']
	) AS trips
	WHERE freq.halte_id = trips.stop_id
;
UPDATE datasysteem.ov_haltes freq SET
	trein_daluren = trips.frequency
	FROM ov_group_frequency(
		EXTRACT(EPOCH FROM INTERVAL '10:00:00'::interval)::integer,
		EXTRACT(EPOCH FROM INTERVAL '15:00:00'::interval)::integer,
		ARRAY['trein'], ARRAY['Thalys','ICE','Intercity direct','Intercity',
		'Sprinter','Snelbus i.p.v trein','Stopbus i.p.v trein','']
	) AS trips
	WHERE freq.halte_id = trips.stop_id
;
-- avond_spits
UPDATE datasysteem.ov_haltes freq SET
	bus_avondspits = trips.frequency
	FROM ov_group_frequency(
		EXTRACT(EPOCH FROM INTERVAL '16:00:00'::interval)::integer,
		EXTRACT(EPOCH FROM INTERVAL '18:30:00'::interval)::integer,
		ARRAY['bus']
	) AS trips
	WHERE freq.halte_id = trips.stop_id
;
UPDATE datasysteem.ov_haltes freq SET
	tram_avondspits = trips.frequency
	FROM ov_group_frequency(
		EXTRACT(EPOCH FROM INTERVAL '16:00:00'::interval)::integer,
		EXTRACT(EPOCH FROM INTERVAL '18:30:00'::interval)::integer,
		ARRAY['tram']
	) AS trips
	WHERE freq.halte_id = trips.stop_id
;
UPDATE datasysteem.ov_haltes freq SET
	metro_avondspits = trips.frequency
	FROM ov_group_frequency(
		EXTRACT(EPOCH FROM INTERVAL '16:00:00'::interval)::integer,
		EXTRACT(EPOCH FROM INTERVAL '18:30:00'::interval)::integer,
		ARRAY['metro']
	) AS trips
	WHERE freq.halte_id = trips.stop_id
;
UPDATE datasysteem.ov_haltes freq SET
	veerboot_avondspits = trips.frequency
	FROM ov_group_frequency(
		EXTRACT(EPOCH FROM INTERVAL '16:00:00'::interval)::integer,
		EXTRACT(EPOCH FROM INTERVAL '18:30:00'::interval)::integer,
		ARRAY['veerboot']
	) AS trips
	WHERE freq.halte_id = trips.stop_id
;
UPDATE datasysteem.ov_haltes freq SET
	trein_avondspits = trips.frequency
	FROM ov_group_frequency(
		EXTRACT(EPOCH FROM INTERVAL '16:00:00'::interval)::integer,
		EXTRACT(EPOCH FROM INTERVAL '18:30:00'::interval)::integer,
		ARRAY['trein'], ARRAY['Thalys','ICE','Intercity direct','Intercity',
		'Sprinter','Snelbus i.p.v trein','Stopbus i.p.v trein','']
	) AS trips
	WHERE freq.halte_id = trips.stop_id
;
-- for hsl
UPDATE datasysteem.ov_haltes freq SET
	hsl_ochtendspits = trips.frequency
	FROM ov_group_frequency(
		EXTRACT(EPOCH FROM INTERVAL '06:30:00'::interval)::integer,
		EXTRACT(EPOCH FROM INTERVAL '09:00:00'::interval)::integer,
		ARRAY['trein'], ARRAY['Thalys','ICE','Intercity direct']
	) AS trips
	WHERE freq.halte_id = trips.stop_id
;
UPDATE datasysteem.ov_haltes freq SET
	hsl_daluren = trips.frequency
	FROM ov_group_frequency(
		EXTRACT(EPOCH FROM INTERVAL '10:00:00'::interval)::integer,
		EXTRACT(EPOCH FROM INTERVAL '15:00:00'::interval)::integer,
		ARRAY['trein'], ARRAY['Thalys','ICE','Intercity direct']
	) AS trips
	WHERE freq.halte_id = trips.stop_id
;
UPDATE datasysteem.ov_haltes freq SET
	hsl_avondspits = trips.frequency
	FROM ov_group_frequency(
		EXTRACT(EPOCH FROM INTERVAL '16:00:00'::interval)::integer,
		EXTRACT(EPOCH FROM INTERVAL '18:30:00'::interval)::integer,
		ARRAY['trein'], ARRAY['Thalys','ICE','Intercity direct']
	) AS trips
	WHERE freq.halte_id = trips.stop_id
;
-- for intercity
UPDATE datasysteem.ov_haltes freq SET
	ic_ochtendspits = trips.frequency
	FROM ov_group_frequency(
		EXTRACT(EPOCH FROM INTERVAL '06:30:00'::interval)::integer,
		EXTRACT(EPOCH FROM INTERVAL '09:00:00'::interval)::integer,
		ARRAY['trein'], ARRAY['Intercity']
	) AS trips
	WHERE freq.halte_id = trips.stop_id
;
UPDATE datasysteem.ov_haltes freq SET
	ic_daluren = trips.frequency
	FROM ov_group_frequency(
		EXTRACT(EPOCH FROM INTERVAL '10:00:00'::interval)::integer,
		EXTRACT(EPOCH FROM INTERVAL '15:00:00'::interval)::integer,
		ARRAY['trein'], ARRAY['Intercity']
	) AS trips
	WHERE freq.halte_id = trips.stop_id
;
UPDATE datasysteem.ov_haltes freq SET
	ic_avondspits = trips.frequency
	FROM ov_group_frequency(
		EXTRACT(EPOCH FROM INTERVAL '16:00:00'::interval)::integer,
		EXTRACT(EPOCH FROM INTERVAL '18:30:00'::interval)::integer,
		ARRAY['trein'], ARRAY['Intercity']
	) AS trips
	WHERE freq.halte_id = trips.stop_id
;
-- for sprinter
UPDATE datasysteem.ov_haltes freq SET
	spr_ochtendspits = trips.frequency
	FROM ov_group_frequency(
		EXTRACT(EPOCH FROM INTERVAL '06:30:00'::interval)::integer,
		EXTRACT(EPOCH FROM INTERVAL '09:00:00'::interval)::integer,
		ARRAY['trein'], ARRAY['Sprinter','Snelbus i.p.v trein','Stopbus i.p.v trein']
	) AS trips
	WHERE freq.halte_id = trips.stop_id
;
UPDATE datasysteem.ov_haltes freq SET
	spr_daluren = trips.frequency
	FROM ov_group_frequency(
		EXTRACT(EPOCH FROM INTERVAL '10:00:00'::interval)::integer,
		EXTRACT(EPOCH FROM INTERVAL '15:00:00'::interval)::integer,
		ARRAY['trein'], ARRAY['Sprinter','Snelbus i.p.v trein','Stopbus i.p.v trein']
	) AS trips
	WHERE freq.halte_id = trips.stop_id
;
UPDATE datasysteem.ov_haltes freq SET
	spr_avondspits = trips.frequency
	FROM ov_group_frequency(
		EXTRACT(EPOCH FROM INTERVAL '16:00:00'::interval)::integer,
		EXTRACT(EPOCH FROM INTERVAL '18:30:00'::interval)::integer,
		ARRAY['trein'], ARRAY['Sprinter','Snelbus i.p.v trein','Stopbus i.p.v trein']
	) AS trips
	WHERE freq.halte_id = trips.stop_id
;
----
-- for multimodal station areas
--ochtend_spits
UPDATE datasysteem.ov_haltes freq SET
	bus_ochtendspits = trips.frequency
	FROM ov_area_frequency(
		EXTRACT(EPOCH FROM INTERVAL '06:30:00'::interval)::integer,
		EXTRACT(EPOCH FROM INTERVAL '09:00:00'::interval)::integer,
		ARRAY['bus']
	) AS trips
	WHERE freq.trein = TRUE AND freq.halte_zone = trips.area_id
;
UPDATE datasysteem.ov_haltes freq SET
	tram_ochtendspits = trips.frequency
	FROM ov_area_frequency(
		EXTRACT(EPOCH FROM INTERVAL '06:30:00'::interval)::integer,
		EXTRACT(EPOCH FROM INTERVAL '09:00:00'::interval)::integer,
		ARRAY['tram']
	) AS trips
	WHERE freq.trein = TRUE AND freq.halte_zone = trips.area_id
;
UPDATE datasysteem.ov_haltes freq SET
	metro_ochtendspits = trips.frequency
	FROM ov_area_frequency(
		EXTRACT(EPOCH FROM INTERVAL '06:30:00'::interval)::integer,
		EXTRACT(EPOCH FROM INTERVAL '09:00:00'::interval)::integer,
		ARRAY['metro']
	) AS trips
	WHERE freq.trein = TRUE AND freq.halte_zone = trips.area_id
;
UPDATE datasysteem.ov_haltes freq SET
	veerboot_ochtendspits = trips.frequency
	FROM ov_area_frequency(
		EXTRACT(EPOCH FROM INTERVAL '06:30:00'::interval)::integer,
		EXTRACT(EPOCH FROM INTERVAL '09:00:00'::interval)::integer,
		ARRAY['veerboot']
	) AS trips
	WHERE freq.trein = TRUE AND freq.halte_zone = trips.area_id
;
-- daluren
UPDATE datasysteem.ov_haltes freq SET
	bus_daluren = trips.frequency
	FROM ov_area_frequency(
		EXTRACT(EPOCH FROM INTERVAL '10:00:00'::interval)::integer,
		EXTRACT(EPOCH FROM INTERVAL '15:00:00'::interval)::integer,
		ARRAY['bus']
	) AS trips
	WHERE freq.trein = TRUE AND freq.halte_zone = trips.area_id
;
UPDATE datasysteem.ov_haltes freq SET
	tram_daluren = trips.frequency
	FROM ov_area_frequency(
		EXTRACT(EPOCH FROM INTERVAL '10:00:00'::interval)::integer,
		EXTRACT(EPOCH FROM INTERVAL '15:00:00'::interval)::integer,
		ARRAY['tram']
	) AS trips
	WHERE freq.trein = TRUE AND freq.halte_zone = trips.area_id
;
UPDATE datasysteem.ov_haltes freq SET
	metro_daluren = trips.frequency
	FROM ov_area_frequency(
		EXTRACT(EPOCH FROM INTERVAL '10:00:00'::interval)::integer,
		EXTRACT(EPOCH FROM INTERVAL '15:00:00'::interval)::integer,
		ARRAY['metro']
	) AS trips
	WHERE freq.trein = TRUE AND freq.halte_zone = trips.area_id
;
UPDATE datasysteem.ov_haltes freq SET
	veerboot_daluren = trips.frequency
	FROM ov_area_frequency(
		EXTRACT(EPOCH FROM INTERVAL '10:00:00'::interval)::integer,
		EXTRACT(EPOCH FROM INTERVAL '15:00:00'::interval)::integer,
		ARRAY['veerboot']
	) AS trips
	WHERE freq.trein = TRUE AND freq.halte_zone = trips.area_id
;
-- avond_spits
UPDATE datasysteem.ov_haltes freq SET
	bus_avondspits = trips.frequency
	FROM ov_area_frequency(
		EXTRACT(EPOCH FROM INTERVAL '16:00:00'::interval)::integer,
		EXTRACT(EPOCH FROM INTERVAL '18:30:00'::interval)::integer,
		ARRAY['bus']
	) AS trips
	WHERE freq.trein = TRUE AND freq.halte_zone = trips.area_id
;
UPDATE datasysteem.ov_haltes freq SET
	tram_avondspits = trips.frequency
	FROM ov_area_frequency(
		EXTRACT(EPOCH FROM INTERVAL '16:00:00'::interval)::integer,
		EXTRACT(EPOCH FROM INTERVAL '18:30:00'::interval)::integer,
		ARRAY['tram']
	) AS trips
	WHERE freq.trein = TRUE AND freq.halte_zone = trips.area_id
;
UPDATE datasysteem.ov_haltes freq SET
	metro_avondspits = trips.frequency
	FROM ov_area_frequency(
		EXTRACT(EPOCH FROM INTERVAL '16:00:00'::interval)::integer,
		EXTRACT(EPOCH FROM INTERVAL '18:30:00'::interval)::integer,
		ARRAY['metro']
	) AS trips
	WHERE freq.trein = TRUE AND freq.halte_zone = trips.area_id
;
UPDATE datasysteem.ov_haltes freq SET
	veerboot_avondspits = trips.frequency
	FROM ov_area_frequency(
		EXTRACT(EPOCH FROM INTERVAL '16:00:00'::interval)::integer,
		EXTRACT(EPOCH FROM INTERVAL '18:30:00'::interval)::integer,
		ARRAY['veerboot']
	) AS trips
	WHERE freq.trein = TRUE AND freq.halte_zone = trips.area_id
;

----
/* ov frequency calculation, for every LINK of every route (and train type)
frequency per hour on:  ochtendspits (06:30 to 09:00), daluren (10:00 to 15:00) and avondspits (16:00 to 18:30)
*/
-- links frequency
-- DROP TABLE ov_analysis.ov_links_frequency CASCADE;
CREATE TABLE ov_analysis.ov_links_frequency(
	sid serial NOT NULL PRIMARY KEY,
	geom geometry(Linestring, 28992),
	trip_mode character varying,
	route_id character varying,
	route_name character varying,
	start_stop_id character varying,
	end_stop_id character varying,
	mean_duration_in_secs integer,
	freq_ochtendspits double precision,
	freq_daluren double precision,
	freq_avondspits double precision
);
INSERT INTO ov_analysis.ov_links_frequency (geom, trip_mode, route_id, route_name, 
		start_stop_id, end_stop_id, mean_duration_in_secs)
	SELECT geom, trip_mode, route_id, route_name, start_stop_id, end_stop_id, avg(duration_in_secs)
	FROM networks.ov_links
	GROUP BY geom, trip_mode, route_id, route_name, start_stop_id, end_stop_id
;
-- frequency ochtendspits
UPDATE ov_analysis.ov_links_frequency freq SET
	freq_ochtendspits = trips.freq
	FROM (SELECT a.trip_mode, a.route_id, a.route_name, a.start_stop_id, a.end_stop_id, round(count(*)::numeric/2.5,2) freq 
		FROM (SELECT trip_mode, route_id, route_name, start_stop_id, end_stop_id FROM networks.ov_links
			WHERE (start_stop_time >= EXTRACT(EPOCH FROM INTERVAL '06:30:00') 
			AND start_stop_time <= EXTRACT(EPOCH FROM INTERVAL '09:00:00'))
			AND trip_id IN (SELECT trip_id FROM networks.ov_trips WHERE day_of_week not in ('saturday','sunday'))
			GROUP BY trip_mode, route_id, route_name, start_stop_id, end_stop_id, start_stop_time
		) a
		GROUP BY trip_mode, route_id, route_name, start_stop_id, end_stop_id
	) trips
	WHERE freq.trip_mode = trips.trip_mode
	AND freq.route_id = trips.route_id
	AND freq.route_name = trips.route_name
	AND freq.start_stop_id = trips.start_stop_id
	AND freq.end_stop_id = trips.end_stop_id
;
UPDATE ov_analysis.ov_links_frequency SET freq_ochtendspits = 0 WHERE freq_ochtendspits IS NULL;
-- frequency daluren
UPDATE ov_analysis.ov_links_frequency freq SET
	freq_daluren = trips.freq
	FROM (SELECT a.trip_mode, a.route_id, a.route_name, a.start_stop_id, a.end_stop_id, round(count(*)::numeric/5.0,2) freq 
		FROM (SELECT trip_mode, route_id, route_name, start_stop_id, end_stop_id FROM networks.ov_links
			WHERE (start_stop_time >= EXTRACT(EPOCH FROM INTERVAL '10:00:00') 
			AND start_stop_time <= EXTRACT(EPOCH FROM INTERVAL '15:00:00'))
			AND trip_id IN (SELECT trip_id FROM networks.ov_trips WHERE day_of_week not in ('saturday','sunday'))
			GROUP BY trip_mode, route_id, route_name, start_stop_id, end_stop_id, start_stop_time
		) a
		GROUP BY trip_mode, route_id, route_name, start_stop_id, end_stop_id
	) trips
	WHERE freq.trip_mode = trips.trip_mode
	AND freq.route_id = trips.route_id
	AND freq.route_name = trips.route_name
	AND freq.start_stop_id = trips.start_stop_id
	AND freq.end_stop_id = trips.end_stop_id
;
UPDATE ov_analysis.ov_links_frequency SET freq_daluren = 0 WHERE freq_daluren IS NULL;
-- freq_avondspits
UPDATE ov_analysis.ov_links_frequency freq SET
	freq_avondspits = trips.freq
	FROM (SELECT a.trip_mode, a.route_id, a.route_name, a.start_stop_id, a.end_stop_id, round(count(*)::numeric/2.5,2) freq 
		FROM (SELECT trip_mode, route_id, route_name, start_stop_id, end_stop_id FROM networks.ov_links
			WHERE (start_stop_time >= EXTRACT(EPOCH FROM INTERVAL '16:00:00') 
			AND start_stop_time <= EXTRACT(EPOCH FROM INTERVAL '18:30:00'))
			AND trip_id IN (SELECT trip_id FROM networks.ov_trips WHERE day_of_week not in ('saturday','sunday'))
			GROUP BY trip_mode, route_id, route_name, start_stop_id, end_stop_id, start_stop_time
		) a
		GROUP BY trip_mode, route_id, route_name, start_stop_id, end_stop_id
	) trips
	WHERE freq.trip_mode = trips.trip_mode
	AND freq.route_id = trips.route_id
	AND freq.route_name = trips.route_name
	AND freq.start_stop_id = trips.start_stop_id
	AND freq.end_stop_id = trips.end_stop_id
;
UPDATE ov_analysis.ov_links_frequency SET freq_avondspits = 0 WHERE freq_avondspits IS NULL;
-- remove links that are not used
DELETE FROM ov_analysis.ov_links_frequency WHERE freq_ochtendspits = 0 AND freq_daluren = 0 AND freq_avondspits = 0;

