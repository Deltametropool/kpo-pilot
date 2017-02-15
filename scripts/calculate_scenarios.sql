-- KPO data system data model
-- author: Jorge Gil, 2017


-- calculation 4 Dichtstbijzijnde Station
INSERT INTO datasysteem.woonscenarios(
	op_loopafstand ,
	op_fietsafstand ,
	dichtstbijzijnde_station ,


	place_name, scenario_name, nearest_station, total_households, 		within_walking_dist, within_cycling_dist, area, density, new_households, percent_change)
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