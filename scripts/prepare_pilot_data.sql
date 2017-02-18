-- KPO data system
-- author: Jorge Gil, 2017


-- Prepare the pilot data set based on the data model
-- this gets distributed with the plug-in

-----
-- Background layers

-- pilot study boundary
-- Includes Province Noord Holland and Metropolitan Region Amsterdam
-- DROP TABLE datasysteem.boundary CASCADE;
CREATE TABLE datasysteem.boundary (
	sid serial NOT NULL PRIMARY KEY,
	geom geometry(Polygon,28992)
);
INSERT INTO datasysteem.boundary (geom) 
	SELECT ST_Union(prov.geom, mra.geom)
	FROM (SELECT * 
		FROM sources.cbs_bestuurlijke_grenzen_provincie 
		WHERE provincie_naam = 'Noord-Holland'
	) prov,
	(SELECT * FROM sources.metropoolregio_mra) mra
;
CREATE INDEX datasysteem_boundary_idx ON datasysteem.boundary USING GIST (geom);
-- rail and metro tracks
-- DROP TABLE datasysteem.spoorwegen CASCADE;
CREATE TABLE datasysteem.spoorwegen (
	sid serial NOT NULL PRIMARY KEY,
	geom geometry(LineString,28992),
	fid integer,
	type_spoorbaan character varying
);
INSERT INTO datasysteem.spoorwegen (geom, fid, type_spoorbaan)
	SELECT spoor.wkb_geometry, spoor.fid, spoor.typespoorbaan
	FROM (SELECT * FROM sources.t10nl_spoorwegen
		WHERE "vervoerfunctie" in ('personenvervoer','gemengd gebruik') 
		AND "status" = 'in gebruik'
	) spoor,
	(SELECT ST_Buffer(geom,5000) geom FROM datasysteem.boundary LIMIT 1) pilot
	WHERE ST_Intersects(spoor.wkb_geometry, pilot.geom)
;
-- water
-- DROP TABLE datasysteem.water CASCADE;
CREATE TABLE datasysteem.water (
	sid serial NOT NULL PRIMARY KEY,
	geom geometry(MultiPolygon,28992)
);
INSERT INTO datasysteem.water (geom)
	SELECT ST_MakeValid(water.geom)
	FROM sources.nl_water_simpel water,
	(SELECT ST_Buffer(geom,5000) geom FROM datasysteem.boundary LIMIT 1) pilot
	WHERE ST_Intersects(ST_MakeValid(water.geom),pilot.geom)
;
-- municipal borders
-- DROP TABLE datasysteem.gemeenten CASCADE;
CREATE TABLE datasysteem.gemeenten (
	sid serial NOT NULL PRIMARY KEY,
	geom geometry(MultiPolygon,28992),
	code character varying,
	gemeente_naam character varying
);
INSERT INTO datasysteem.gemeenten (geom, code, gemeente_naam)
	SELECT geom, code, gemeentena
	FROM sources.cbs_bestuurlijke_grenzen_gemeenten
;
-- urbanised areas
-- DROP TABLE datasysteem.bebouwdgebieden CASCADE;
CREATE TABLE datasysteem.bebouwdgebieden (
	sid serial NOT NULL PRIMARY KEY,
	geom geometry(MultiPolygon,28992)
);
INSERT INTO datasysteem.bebouwdgebieden (geom)
	SELECT bbg.geom
	FROM sources.sv_ag_huisv_bbg_detail bbg,
	(SELECT geom FROM datasysteem.boundary LIMIT 1) pilot
	WHERE ST_Intersects(bbg.geom, pilot.geom)
;

----
-- Woonscenarios
-- DELETE FROM datasysteem.woonscenarios;
INSERT INTO datasysteem.woonscenarios(
		geom, code, plaatsnaam, scenario_naam, huishoudens,
		op_loopafstand, op_fietsafstand, area, 
		nieuwe_huishoudens, procentuele_verandering
	)
	SELECT huidig.geom, huidig.zone_id, huidig.woonplaats, 'Huidige situatie',
		huidig.huish, FALSE, FALSE, ST_Area(huidig.geom), 0, 0
	FROM sources.w_2010_versie_17_feb_2014 huidig,
	(SELECT geom FROM datasysteem.boundary LIMIT 1) pilot
	WHERE ST_Intersects(huidig.geom, pilot.geom)
;
INSERT INTO datasysteem.woonscenarios(
		geom, code, plaatsnaam, scenario_naam, huishoudens,
		op_loopafstand, op_fietsafstand, area, nieuwe_huishoudens
	)
	SELECT wlo.geom, wlo.zone_id, wlo.woonplaats, 'WLO 2040 Laag',
		wlo.huish, FALSE, FALSE, ST_Area(wlo.geom), (wlo.huish-huidig.huish)
	FROM (
		SELECT * FROM datasysteem.woonscenarios WHERE scenario_naam = 'Huidige situatie'
	) huidig
	JOIN sources.w_2040_laag_versie_22_januari_2016 wlo
	USING(zone_id)
;
INSERT INTO datasysteem.woonscenarios(
		geom, code, plaatsnaam, scenario_naam, huishoudens,
		op_loopafstand, op_fietsafstand, area, nieuwe_huishoudens
	)
	SELECT wlo.geom, wlo.zone_id, wlo.woonplaats, 'WLO 2040 Hoog',
		wlo.huish, FALSE, FALSE, ST_Area(wlo.geom), (wlo.huish-huidig.huish)
	FROM (
		SELECT * FROM datasysteem.woonscenarios WHERE scenario_naam = 'Huidige situatie'
	) huidig
	JOIN sources.w_2040_hoog_versie_22_januari_2016 wlo
	USING(zone_id)
;
-- set density per hectar
UPDATE datasysteem.woonscenarios SET dichtheid=huishoudens/area*10000.0;
UPDATE datasysteem.woonscenarios 
	SET procentuele_verandering = CASE
		WHEN huishoudens-nieuwe_huishoudens = 0 THEN nieuwe_huishoudens
		ELSE nieuwe_huishoudens::float/(huishoudens-nieuwe_huishoudens)::float
	END
;


----
-- Street Isochrones
-- create polygons for isochrones
-- DELETE FROM datasysteem.isochronen WHERE halte_modaliteit = 'trein';
INSERT INTO datasysteem.isochronen(geom, halte_id, halte_naam, halte_modaliteit, 
	modaliteit, isochroon_afstand)
	SELECT ST_Multi(ST_MakePolygon(ST_ExteriorRing((ST_Dump(
		ST_Simplify(ST_Union(ST_Buffer(ST_Simplify(geom,10),100,'quad_segs=2')),20))).geom))), 
		station_id, min(station_name), min(station_mode), travel_mode, min(travel_distance)
	FROM isochrone_analysis.station_isochrone_wegen
	GROUP BY station_id, travel_mode
;


----
-- Spatial characteristics
-- DELETE FROM datasysteem.ruimtelijke_kenmerken;
-- add basic CBS characteristics
INSERT INTO datasysteem.ruimtelijke_kenmerken(geom, cell_id, huishoudens, inwoners,
		intensiteit, woz_waarde)
	SELECT cbs.geom, cbs.c28992r100, CASE WHEN cbs.won2012 >= 0 THEN cbs.won2012 ELSE 0 END, 
		CASE WHEN cbs.inw2014 >= 0 THEN cbs.inw2014 ELSE 0 END, lisa.sum_banen,
		CASE WHEN cbs.wozwon2012 >= 0 THEN cbs.wozwon2012 ELSE 0 END
	FROM sources.cbs_vierkant100m_2014 cbs
	JOIN sources.vdm_vierkant_2014_pnh_lisa lisa
	ON(cbs.c28992r100=lisa.c28992r100)	
;
-- add students estimated from LISA
UPDATE datasysteem.ruimtelijke_kenmerken AS a 
	SET intensiteit = a.intensiteit + b.leerlingen
	FROM (SELECT cbs.c28992r100 AS cell_id, SUM(lisa.vdm_leer) AS leerlingen
		FROM sources.cbs_vierkant100m_2014 cbs, sources.pnh_lisa_2016_selectie_onderwijs lisa
		WHERE ST_Contains(cbs.geom, lisa.geom)
		GROUP BY cbs.c28992r100
		) b
	WHERE a.cell_id = b.cell_id
;
-- add built density from PBL data
UPDATE datasysteem.ruimtelijke_kenmerken AS a
	SET fysieke_dichtheid = b.fsi
	FROM (SELECT cbs.c28992r100 AS cell_id, SUM(ST_Area(ST_Intersection(cbs.geom, pbl.geom))*pbl.fsi)/10000.0 AS fsi
		FROM sources.cbs_vierkant100m_2014 cbs, sources.pbl_bouwvlak_fsi pbl
		WHERE ST_Intersects(cbs.geom, pbl.geom)
		GROUP BY cbs.c28992r100
		) b
	WHERE a.cell_id = b.cell_id
;







-- DELETE FROM datasysteem.development_locations;
INSERT INTO datasysteem.development_locations(geom,locations_set,site_id,municipality,site_name,
		address,built_dwellings,planned_dwellings,net_dwellings,area,density,nearest_station,
		within_walking_dist,within_cycling_dist,within_ov_dist)
	SELECT ST_Force2D(plan.geom), 'plancapaciteit', plan.planid, plan.gemnaam, plan.naamplan, plan.straat, 
		plan.te_slopen, (plan.wtypapp+plan.wtypggb), (plan.wtypapp+plan.wtypggb-plan.te_slopen), 
		ST_Area(plan.geom), ((plan.wtypapp+plan.wtypggb)::double precision/ST_Area(plan.geom))*10000, stat.station_name,
		FALSE, FALSE, FALSE
	FROM sources.vdm_plancapaciteit_2016_update plan,
		(SELECT DISTINCT ON(a.sid) a.sid, b.station_id station_sid, b.station_naam station_name, 
			ST_Distance(a.geom, b.geom) dist 
		FROM sources.vdm_plancapaciteit_2016_update a, 
			(SELECT * FROM street_isochrone_analysis.station_isochrone_polygons_full
				WHERE travel_mode = 'fiets'
			) b
		ORDER BY a.sid, dist ASC
		) stat
	WHERE plan.sid = stat.sid
;
INSERT INTO datasysteem.development_locations(geom,locations_set,site_id,municipality,site_name,
		address,built_dwellings,planned_dwellings,net_dwellings,area,density,nearest_station)
	SELECT plan.geom, 'leegstanden', plan.rinnummer, plan.gemeente, plan.plannaam, plan.ookbekend,
		0,0,0,ST_Area(plan.geom),(plan.planm2::double precision/ST_Area(plan.geom)), stat.station_name
	FROM sources.pnh_werklocaties_kantoren_leegstanden plan,
		(SELECT DISTINCT ON(a.sid) a.sid, b.station_id station_sid, b.station_naam station_name, 
			ST_Distance(a.geom, b.geom) dist 
		FROM sources.pnh_werklocaties_kantoren_leegstanden a, 
			(SELECT * FROM street_isochrone_analysis.station_isochrone_polygons_full
				WHERE travel_mode = 'fiets'
			) b
		ORDER BY a.sid, dist ASC
		) stat
	WHERE plan.sid = stat.sid
;
CREATE INDEX development_locations_gidx ON datasysteem.development_locations USING GIST (geom);
--
UPDATE datasysteem.development_locations dev SET
	mean_accessibility = acc.mean,
	max_accessibility = acc.max
	FROM (SELECT loc.sid, max(spat.ptal_index) AS max, avg(spat.ptal_index) AS mean
		FROM datasysteem.development_locations loc,
		(SELECT ST_Centroid(geom) AS geom, ptal_index 
			FROM datasysteem.spatial_characteristics
			WHERE ptal_index > 0
		) spat
		WHERE ST_Intersects(loc.geom,spat.geom)
		GROUP BY loc.sid
	)acc
	WHERE dev.sid = acc.sid
;
UPDATE datasysteem.development_locations dev SET 
	within_walking_dist = TRUE
	FROM (SELECT DISTINCT ON(a.sid) a.sid
		FROM datasysteem.development_locations a,
		(SELECT * FROM street_isochrone_analysis.station_isochrone_polygons_full
			WHERE travel_mode = 'voetganger') b
		WHERE ST_Intersects(a.geom,b.geom)
		) intersects
	WHERE dev.sid=intersects.sid
;
UPDATE datasysteem.development_locations dev SET 
	within_cycling_dist = TRUE
	FROM (SELECT DISTINCT ON(a.sid) a.sid
		FROM datasysteem.development_locations a,
		(SELECT * FROM street_isochrone_analysis.station_isochrone_polygons_full
			WHERE travel_mode = 'fiets') b
		WHERE ST_Intersects(a.geom,b.geom)
		) intersects
	WHERE dev.sid=intersects.sid
;
UPDATE datasysteem.development_locations dev SET 
	within_ov_dist = TRUE
	FROM (SELECT DISTINCT ON(a.sid) a.sid
		FROM datasysteem.development_locations a,
		(SELECT * FROM street_isochrone_analysis.station_isochrone_polygons_full
			WHERE travel_mode = 'fiets') b
		WHERE ST_Intersects(a.geom,b.geom)
		) intersects
	WHERE dev.sid=intersects.sid
;

-- DELETE FROM datasysteem.development_locations_summary;
INSERT INTO datasysteem.development_locations_summary(locations_set,new_households)
	SELECT locations_set, sum(net_dwellings)
	FROM datasysteem.development_locations
	GROUP BY locations_set
;
UPDATE datasysteem.development_locations_summary a SET
	within_walking_dist = sum
	FROM (SELECT locations_set, sum(net_dwellings) sum
		FROM datasysteem.development_locations
		WHERE within_walking_dist = TRUE
		GROUP BY locations_set
	) b
	WHERE a.locations_set = b.locations_set
;
UPDATE datasysteem.development_locations_summary a SET
	within_cycling_dist = sum
	FROM (SELECT locations_set, sum(net_dwellings) sum
		FROM datasysteem.development_locations
		WHERE within_walking_dist = FALSE
		AND within_cycling_dist = TRUE
		GROUP BY locations_set
	) b
	WHERE a.locations_set = b.locations_set
;
UPDATE datasysteem.development_locations_summary a SET
	within_ov_dist = sum
	FROM (SELECT locations_set, sum(net_dwellings) sum
		FROM datasysteem.development_locations
		WHERE within_walking_dist = FALSE
		AND within_cycling_dist = FALSE
		AND within_ov_dist = TRUE
		GROUP BY locations_set
	) b
	WHERE a.locations_set = b.locations_set
;
UPDATE datasysteem.development_locations_summary a SET
	outside_influence = sum
	FROM (SELECT locations_set, sum(net_dwellings) sum
		FROM datasysteem.development_locations
		WHERE within_walking_dist = FALSE
		AND within_cycling_dist = FALSE
		AND within_ov_dist = FALSE
		GROUP BY locations_set
	) b
	WHERE a.locations_set = b.locations_set
;

-- DELETE FROM datasysteem.ov_routes;
INSERT INTO datasysteem.ov_routes(geom,route_id,route_name,route_mode,trein_type,mean_duration)
	SELECT rt.geom, rt.route_id, rt.route_name, rt.route_mode, trip.route_long_name, rt.route_duration
	FROM networks.ov_routes AS rt
	LEFT JOIN (SELECT route_id, min(route_long_name) AS route_long_name
		FROM networks.ov_trips
		WHERE day_of_week = ANY(ARRAY['monday','tuesday','wednesday','thursday','friday'])
		GROUP BY route_id
	)AS trip
	USING(route_id)
;
UPDATE datasysteem.ov_routes route SET ochtendspits = trip.route_frequency
	FROM (
		SELECT trip.route_id, round(count(*)::numeric/2.5,2) AS route_frequency
		FROM networks.ov_trips trip
		WHERE day_of_week = ANY(ARRAY['monday','tuesday','wednesday','thursday','friday'])
		AND trip_id IN (SELECT trip_id 
			FROM networks.ov_stop_times
			WHERE (pickup_type = 0 OR pickup_type IS NULL)
			AND (departure_in_secs >= FLOOR(EXTRACT(EPOCH FROM '06:30:00'::time)) 
			AND departure_in_secs <= FLOOR(EXTRACT(EPOCH FROM '09:00:00'::time)))
			)
		GROUP BY route_id
	)AS trip
	WHERE route.route_id = trip.route_id
;
UPDATE datasysteem.ov_routes route SET middagdal = trip.route_frequency
	FROM (
		SELECT trip.route_id, round(count(*)::numeric/2.5,2) AS route_frequency
		FROM networks.ov_trips trip
		WHERE day_of_week = ANY(ARRAY['monday','tuesday','wednesday','thursday','friday'])
		AND trip_id IN (SELECT trip_id 
			FROM networks.ov_stop_times
			WHERE (pickup_type = 0 OR pickup_type IS NULL)
			AND (departure_in_secs >= FLOOR(EXTRACT(EPOCH FROM '11:30:00'::time)) 
			AND departure_in_secs <= FLOOR(EXTRACT(EPOCH FROM '14:00:00'::time)))
			)
		GROUP BY route_id
	)AS trip
	WHERE route.route_id = trip.route_id
;
UPDATE datasysteem.ov_routes route SET avondspits = trip.route_frequency
	FROM (
		SELECT trip.route_id, round(count(*)::numeric/2.5,2) AS route_frequency
		FROM networks.ov_trips trip
		WHERE day_of_week = ANY(ARRAY['monday','tuesday','wednesday','thursday','friday'])
		AND trip_id IN (SELECT trip_id 
			FROM networks.ov_stop_times
			WHERE (pickup_type = 0 OR pickup_type IS NULL)
			AND (departure_in_secs >= FLOOR(EXTRACT(EPOCH FROM '16:00:00'::time)) 
			AND departure_in_secs <= FLOOR(EXTRACT(EPOCH FROM '18:30:00'::time)))
			)
		GROUP BY route_id
	)AS trip
	WHERE route.route_id = trip.route_id
;
DELETE FROM datasysteem.ov_routes WHERE ochtendspits IS NULL AND middagdal IS NULL AND avondspits IS NULL;

-- DELETE FROM datasysteem.isochrones;
INSERT INTO datasysteem.isochrones(geom,stop_id,stop_name,travel_mode,distance)
	SELECT ST_Multi(geom), station_id, station_naam, travel_mode, travel_distance
	FROM street_isochrone_analysis.station_isochrone_polygons_full
;

-- DELETE FROM datasysteem.ov_stops;
INSERT INTO datasysteem.ov_stops(geom,stop_id,stop_area,stop_name,stop_location,tram,metro,trein,
		bus,veerboot,bus_ochtendspits,bus_middagdal,bus_avondspits,tram_ochtendspits,
		tram_middagdal,tram_avondspits,metro_ochtendspits,metro_middagdal,metro_avondspits,
		veer_ochtendspits,veer_middagdal,veer_avondspits,trein_ochtendspits,trein_middagdal,
		trein_avondspits,hsl_ochtendspits,hsl_middagdal,hsl_avondspits,ic_ochtendspits,
		ic_middagdal,ic_avondspits,spr_ochtendspits,spr_middagdal,spr_avondspits)
	SELECT geom,stop_id,stop_area,stop_name,stop_descr,tram,metro,trein,
		bus,veerboot,bus_ochtendspits,bus_middagdal,bus_avondspits,tram_ochtendspits,
		tram_middagdal,tram_avondspits,metro_ochtendspits,metro_middagdal,metro_avondspits,
		veer_ochtendspits,veer_middagdal,veer_avondspits,trein_ochtendspits,trein_middagdal,
		trein_avondspits,hsl_ochtendspits,hsl_middagdal,hsl_avondspits,ic_ochtendspits,
		ic_middagdal,ic_avondspits,spr_ochtendspits,spr_middagdal,spr_avondspits
	FROM ov_network_analysis.ov_frequency
;

-- DELETE FROM datasysteem.ov_links;
INSERT INTO datasysteem.ov_links(geom,origin_stop_id,destination_stop_id,link_mode,trein_type,
		ochtendspits,middagdal,avondspits,mean_duration)
	SELECT geom, start_stop_id, end_stop_id, trip_mode, '', 
		freq_spits_morgen, freq_dal_middag, freq_spits_avond, mean_duration_in_secs
	FROM ov_network_analysis_2016.links_frequency
;

-- DELETE FROM datasysteem.important_locations;
INSERT INTO datasysteem.important_locations(geom,location_type,location_id,location_name,ov_routes)
	SELECT
	FROM
;

-- DELETE FROM datasysteem.station_influence_overlap;
INSERT INTO datasysteem.station_influence_overlap(geom,residents,workers,students,total_stations,station_names)
	SELECT ST_Multi(ST_Union(spaces.geom)),sum(spaces.residents),sum(spaces.workers),sum(spaces.students),
		spaces.total,spaces.station_names
	FROM (
		SELECT min(a.geom) AS geom, a.cell_id, count(*) AS total, 
			string_agg(b.stop_name,',' ORDER BY b.stop_name) AS station_names,
			min(residents) AS residents, min(workers) AS workers, min(students) AS students
		FROM (SELECT * FROM datasysteem.spatial_characteristics) a,
		(SELECT * FROM datasysteem.isochrones WHERE travel_mode = 'fiets') b
		WHERE ST_Intersects(ST_Centroid(a.geom),b.geom)
		GROUP BY a.cell_id
	) spaces
	WHERE spaces.total > 1
	GROUP BY spaces.total,spaces.station_names
;

-- DELETE FROM datasysteem.cycle_routes;
INSERT INTO datasysteem.cycle_routes(geom,route_id,route_name,link_frequency)
	SELECT
	FROM 
;
--select count(*) from (select distinct(routeid) routeid from sources.fietstelweek_routes2016) as foo

-- Some background layers
CREATE TABLE datasysteem.spoor_wegen AS SELECT a.* FROM sources.nwb_spoor_spoorvakken a, networks.boundary b
	WHERE ST_Intersects(a.geom,b.geom);
ALTER TABLE datasysteem.spoor_wegen ADD CONSTRAINT spoor_wegen_pkey PRIMARY KEY (sid);
-- DROP TABLE datasysteem.gemeente CASCADE;
CREATE TABLE datasysteem.gemeente AS SELECT a.* FROM sources.cbs_gem_2016 a, networks.boundary b
	WHERE ST_Intersects(a.geom,b.geom) AND a.water='NEE';
ALTER TABLE datasysteem.gemeente ADD CONSTRAINT gemeente_pkey PRIMARY KEY (sid);
