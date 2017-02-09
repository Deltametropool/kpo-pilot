-- KPO data system
-- Jorge Gil, 2017

-- Prepare the sample data set based on the data model
-- this gets distributed with the plug-in

-- DELETE FROM datasysteem.transit_nodes;
INSERT INTO datasysteem.transit_nodes (geom, station_name, scenario_name, passengers, passengers_diff, passengers_change,
				bicycle_parking, bicycle_occupation, bicycle_occupation_percent, bicycle_occupation_diff,
				platform, platform_diff, stairs, stairs_diff, pedestrian_flows, pedestrian_flows_diff)
	SELECT geom,station,'current scenario',in_uit_15,0,0,aantal_fie,aantal_geb,bezettings,0,
		trunc(random()*2+1),trunc(random()*2+1),trunc(random()*2+1),trunc(random()*2+1),trunc(random()*2+1),
		trunc(random()*2+1)
	FROM sources.rws_treinstations_2015_pnh_fietstallingen_inuit
;

-- DELETE FROM datasysteem.housing_demand_scenarios;
INSERT INTO datasysteem.housing_demand_scenarios(geom, postcode, place_name, scenario_name, nearest_station, total_households, 		within_walking_dist, within_cycling_dist, area, density, new_households, percent_change)
	SELECT wlo.geom, wlo.pc4, wlo.woonplaats, 'WLO 40 laag', stat.station_name, wlo.huish_1, FALSE, FALSE, wlo.area,
		wlo.vdm_d_40, wlo.vdm_wo_toe, CASE
			WHEN wlo.huish = 0 THEN NULL
			WHEN wlo.vdm_wo_toe > wlo.huish THEN 100
			ELSE wlo.vdm_wo_toe::numeric/wlo.huish::numeric*100.0
			END
	FROM sources.vdm_wlo_40_laag_mra wlo,
		(SELECT DISTINCT ON(a.sid) a.sid, b.station_id station_sid, b.station_naam station_name, 
			ST_Distance(a.geom, b.geom) dist 
		FROM sources.vdm_wlo_40_laag_mra a, 
			(SELECT * FROM street_isochrone_analysis.station_isochrone_polygons_full
				WHERE travel_mode = 'fiets'
			) b
		ORDER BY a.sid, dist ASC
		) stat
	WHERE wlo.sid = stat.sid
;
UPDATE datasysteem.housing_demand_scenarios sce SET 
	within_walking_dist = TRUE
	FROM (SELECT DISTINCT ON(a.sid) a.sid, a.pc4
		FROM sources.vdm_wlo_40_laag_mra a,
		(SELECT * FROM street_isochrone_analysis.station_isochrone_polygons_full
			WHERE travel_mode = 'voetganger') b
		WHERE ST_Intersects(a.geom,b.geom)
		) intersects
	WHERE sce.postcode=intersects.pc4::text
;
UPDATE datasysteem.housing_demand_scenarios sce SET 
	within_cycling_dist = TRUE
	FROM (SELECT DISTINCT ON(a.sid) a.sid, a.pc4
		FROM sources.vdm_wlo_40_laag_mra a,
		(SELECT * FROM street_isochrone_analysis.station_isochrone_polygons_full
			WHERE travel_mode = 'fiets') b
		WHERE ST_Intersects(a.geom,b.geom)
		) intersects
	WHERE sce.postcode=intersects.pc4::text
;

-- DELETE FROM datasysteem.housing_demand_summary;
INSERT INTO datasysteem.housing_demand_summary(scenario_name,new_households)
	SELECT scenario_name, sum(new_households)
	FROM datasysteem.housing_demand_scenarios
	GROUP BY scenario_name
;
UPDATE datasysteem.housing_demand_summary a SET
	within_walking_dist = sum
	FROM (SELECT scenario_name, sum(new_households) sum
		FROM datasysteem.housing_demand_scenarios
		WHERE within_walking_dist = TRUE
		GROUP BY scenario_name
	) b
	WHERE a.scenario_name = b.scenario_name
;
UPDATE datasysteem.housing_demand_summary a SET
	within_cycling_dist = sum
	FROM (SELECT scenario_name, sum(new_households) sum
		FROM datasysteem.housing_demand_scenarios
		WHERE within_walking_dist = FALSE
		AND within_cycling_dist = TRUE
		GROUP BY scenario_name
	) b
	WHERE a.scenario_name = b.scenario_name
;
UPDATE datasysteem.housing_demand_summary a SET
	outside_influence = sum
	FROM (SELECT scenario_name, sum(new_households) sum
		FROM datasysteem.housing_demand_scenarios
		WHERE within_walking_dist = FALSE
		AND within_cycling_dist = FALSE
		GROUP BY scenario_name
	) b
	WHERE a.scenario_name = b.scenario_name
;

-- DELETE FROM datasysteem.spatial_characteristics;
INSERT INTO datasysteem.spatial_characteristics(geom,cell_id,households,residents,workers,--students,
		property_value,ptal_level,ptal_index)
	SELECT cbs.geom, cbs.c28992r100, CASE WHEN cbs.won2012 >= 0 THEN cbs.won2012 ELSE 0 END, 
		CASE WHEN cbs.inw2014 >= 0 THEN cbs.inw2014 ELSE 0 END, cbs.sum_banen,
		CASE WHEN cbs.wozwon2012 >= 0 THEN cbs.wozwon2012 ELSE 0 END, ptal.ptal_pnh, ptal.ptai_pnh
	FROM sources.cbs_vierkant_2014_pnh_lisa cbs
	JOIN ptal_analysis_2016.ptal_poi_pnh ptal
	ON(cbs.c28992r100=ptal.poi_id)	
;
UPDATE datasysteem.spatial_characteristics SET population=(residents+workers);--+students
UPDATE datasysteem.spatial_characteristics a SET intensity=b.intensity
	FROM (SELECT t.cell_id,
		(t.population - avg(t.population) over()) / stddev(t.population) over() as intensity
		FROM datasysteem.spatial_characteristics as t
		) b
	WHERE a.cell_id=b.cell_id
;
UPDATE datasysteem.spatial_characteristics SET built_density=0;
CREATE INDEX spatial_characteristics_gidx ON datasysteem.spatial_characteristics USING GIST (geom);

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
