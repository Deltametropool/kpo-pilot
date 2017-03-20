-- KPO data system
-- author: Jorge Gil, 2017


-- Prepare the pilot data set based on the data model
-- this gets distributed with the plug-in

-----
-- Background layers

-- pilot study boundary
-- Includes Province Noord Holland and Metropolitan Region Amsterdam
-- DROP TABLE datasysteem.grens CASCADE;
CREATE TABLE datasysteem.grens (
	sid serial NOT NULL PRIMARY KEY,
	geom geometry(MultiPolygon,28992),
	grens_naam character varying
);
INSERT INTO datasysteem.grens (geom, grens_naam) 
	SELECT geom, 'Noord-Holland'
	FROM sources.cbs_bestuurlijke_grenzen_provincie 
	WHERE provincie_naam = 'Noord-Holland'
;
INSERT INTO datasysteem.grens (geom, grens_naam) 
	SELECT geom, 'MRA'
	FROM sources.metropoolregio_mra
;
CREATE INDEX datasysteem_grens_idx ON datasysteem.grens USING GIST (geom);
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
	(SELECT ST_Buffer(geom,5000) geom FROM datasysteem.grens WHERE grens_naam = 'Noord-Holland') pilot
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
	(SELECT ST_Buffer(geom,5000) geom FROM datasysteem.grens WHERE grens_naam = 'Noord-Holland') pilot
	WHERE ST_Intersects(ST_MakeValid(water.geom),pilot.geom)
;
-- green
-- DROP TABLE datasysteem.groen CASCADE;
CREATE TABLE datasysteem.groen (
	sid serial NOT NULL PRIMARY KEY,
	geom geometry(Polygon,28992)
);
INSERT INTO datasysteem.groen (geom)
	SELECT groen.wkb_geometry
	FROM sources.t10nl_terrein_vlak AS groen,
	(SELECT geom FROM datasysteem.grens WHERE grens_naam = 'Noord-Holland') AS pilot
	WHERE ST_Intersects(groen.wkb_geometry,pilot.geom)
;
-- roads
-- DROP TABLE datasysteem.wegen CASCADE;
CREATE TABLE datasysteem.wegen (
	sid serial NOT NULL PRIMARY KEY,
	geom geometry(Linestring,28992)
);
INSERT INTO datasysteem.wegen (geom)
	SELECT wegen.geom
	FROM networks.t10_wegen AS wegen,
	(SELECT geom FROM datasysteem.grens WHERE grens_naam = 'Noord-Holland') AS pilot
	WHERE ST_Intersects(wegen.geom,pilot.geom)
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
	FROM sources.sv_ag_huisv_bbg_detail AS bbg,
	(SELECT geom FROM datasysteem.grens WHERE grens_naam = 'Noord-Holland') AS pilot
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
	FROM sources.w_2010_versie_17_feb_2014 AS huidig,
	(SELECT geom FROM datasysteem.grens WHERE grens_naam = 'Noord-Holland') AS pilot
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
	) AS huidig
	JOIN sources.w_2040_laag_versie_22_januari_2016 AS wlo
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
	) AS huidig
	JOIN sources.w_2040_hoog_versie_22_januari_2016 AS wlo
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
-- OV routes
-- DELETE FROM datasysteem.ov_routes;
INSERT INTO datasysteem.ov_routes(geom, route_id, route_naam, modaliteit)
	SELECT trips.geom, routes.route_id, trips.route_name, trips.trip_mode
	FROM (
		SELECT ST_MakeLine(links.geom) geom, links.trip_id, min(links.trip_mode) AS trip_mode, 
			min(links.route_name) AS route_name, sum(links.duration_in_secs) AS trip_duration
		FROM (SELECT geom, trip_id, trip_mode, route_id, route_name, trip_sequence, duration_in_secs
			FROM networks.ov_links
			WHERE trip_mode !='trein'
			ORDER BY trip_id, trip_sequence
		) links
		GROUP BY links.trip_id
	) AS trips
	JOIN networks.ov_trips as routes
	USING(trip_id)
	GROUP BY trips.geom, routes.route_id, trips.route_name, trips.trip_mode
;
-- update frequency
UPDATE datasysteem.ov_routes AS route SET
	ochtendspits = links.ochtendspits,
	daluren = links.daluren,
	avondspits = links.avondspits
	FROM (
		SELECT route_id, avg(freq_ochtendspits) ochtendspits, 
			avg(freq_daluren) daluren, avg(freq_avondspits) avondspits
		FROM ov_analysis.ov_links_frequency
		WHERE trip_mode != 'trein'
		GROUP BY route_id
	) links
	WHERE route.route_id = links.route_id
;
CREATE INDEX ov_routes_geom_idx ON datasysteem.ov_routes USING GIST(geom);	


-----
-- Kenmerken van knooppunten
-- DELETE FROM datasysteem.knooppunten;
INSERT INTO datasysteem.knooppunten (geom, station_vdm_code, station_naam, halte_id, halte_naam, huishoudens)
	SELECT areas.geom, stops.stop_code, areas.alt_name, stops.stop_id, stops.stop_name, 
		SUM(woon.huishoudens)
	FROM networks.ov_stop_areas AS areas
	JOIN (
		SELECT stop_id, stop_code, stop_name, stop_area FROM networks.ov_stops
		WHERE trein = True AND location_type = 1
	) AS stops
	ON(areas.sid = stops.stop_area)
	JOIN (
		SELECT scenario_naam, dichtstbijzijnde_station, huishoudens, nieuwe_huishoudens
		FROM datasysteem.woonscenarios
		WHERE scenario_naam = 'Huidige situatie' AND op_loopafstand = TRUE OR op_fietsafstand = TRUE
	) AS woon
	ON (stops.stop_name = woon.dichtstbijzijnde_station)
	GROUP BY areas.geom, stops.stop_code, areas.alt_name, stops.stop_id, stops.stop_name
;
-- update VDM NS data
UPDATE datasysteem.knooppunten knoop
	SET in_uit_trein = stations.in_uit_15,
	fiets_plaatsen = stations.aantal_fie,
	fiets_bezetting = CASE
		WHEN stations.aantal_fie > 0 
		THEN round((stations.aantal_geb::numeric/stations.aantal_fie::numeric)*100,0)
		ELSE 0
		END
	FROM sources.rws_treinstations_2015_pnh stations
	WHERE knoop.station_naam = stations.station
;
-- update prorail data. does not cover all stations
UPDATE datasysteem.knooppunten knoop
	SET passanten = prorail."Totaal_Passanten", 
	in_uit_trein = prorail."IN_UIT_trein", 
	overstappers = prorail."Overstappers_trein", 
	in_uit_btm = prorail."IN_UIT_BTM",
	btm_voortransport = prorail."BTM_voortransport", 
	btm_natransport = prorail."BTM_natransport", 
	lopen_voortransport = prorail."Lopen_voortransport", 
	lopen_natransport = prorail."Lopen_natransport",
	fiets_voortransport = prorail.fiets_voortransport, 
	fiets_natransport = prorail.fiets_natransport, 
	pr_voortransport = prorail."PR_voortransport", 
	pr_natransport = prorail."PR_natransport",
	ov_fietsen = prorail."OV_fiets", 
	pr_plaatsen = coalesce(prorail."PR_aantal",0) + coalesce(prorail."PR_bet_aantal",0), 
	pr_bezetting = CASE 
		WHEN coalesce(prorail."PR_aantal",0) + coalesce(prorail."PR_bet_aantal",0) = 0 THEN 0
		WHEN coalesce(prorail."PR_bet_aantal",0) > 0 THEN round((coalesce(prorail."PR_aantal",0)::numeric + 
		((coalesce(prorail."PR_bet_bezet",0)/100.0)*coalesce(prorail."PR_bet_aantal",0))::numeric)/
		(coalesce(prorail."PR_aantal",0) + coalesce(prorail."PR_bet_aantal",0))*100.0,0)
		ELSE round(((coalesce(prorail."PR_bezet",0)/100.0)*coalesce(prorail."PR_aantal",0))::numeric /
		(coalesce(prorail."PR_aantal",0))*100.0,0)
	END
	FROM sources.prorail_data AS prorail
	WHERE knoop.station_vdm_code = prorail."VDM_code"::text
;
-- update ov routes crossing the knooppunten
-- UPDATE datasysteem.knooppunten SET ov_routes = NULL;
UPDATE datasysteem.knooppunten AS knop SET 
	ov_routes = routes.ids
	FROM (SELECT c.sid, string_agg(c.route_id,',' ORDER BY c.route_id) ids
		FROM (SELECT a.sid, b.route_id
			FROM (
				SELECT route_id, ST_Multi((ST_DumpPoints(geom)).geom) geom
				FROM datasysteem.ov_routes
			) AS b, datasysteem.knooppunten a
			WHERE ST_DWithin(a.geom,b.geom,200)
			GROUP BY a.sid, b.route_id
		) c
		GROUP BY c.sid
	) routes
	WHERE knop.sid = routes.sid
;


----
-- Street Isochrones
-- create polygons for isochrones
-- DELETE FROM datasysteem.isochronen WHERE modaliteit IN ('fiets','walk');
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
INSERT INTO datasysteem.ruimtelijke_kenmerken(geom, cell_id, huishoudens, intensiteit, woz_waarde)
	SELECT vdm.geom, vdm.c28992r100, 
		CASE WHEN vdm.won2012 >= 0 THEN vdm.won2012 ELSE 0 END,
		CASE WHEN vdm.inw2014 >= 0 THEN vdm.inw2014 + vdm.sum_banen ELSE vdm.sum_banen END,
		CASE WHEN vdm.wozwon2012 > 0 THEN vdm.wozwon2012 ELSE NULL END
	FROM sources.vdm_vierkant_2014_pnh_lisa vdm
;
-- add students estimated from LISA
UPDATE datasysteem.ruimtelijke_kenmerken AS a 
	SET intensiteit = a.intensiteit + b.leerlingen
	FROM (SELECT cbs.cell_id, SUM(lisa.vdm_leer) AS leerlingen
		FROM datasysteem.ruimtelijke_kenmerken cbs, sources.pnh_lisa_2016_selectie_onderwijs lisa
		WHERE ST_Contains(cbs.geom, lisa.geom)
		GROUP BY cbs.cell_id
		) b
	WHERE a.cell_id = b.cell_id
;
-- add PTAL values
UPDATE datasysteem.ruimtelijke_kenmerken AS a 
	SET ov_bereikbaarheidsindex = ptai,
	ov_bereikbaarheidsniveau = ptal
	FROM ov_analysis.ptal_poi b
	WHERE a.cell_id = b.cell_id
;
UPDATE datasysteem.ruimtelijke_kenmerken
	SET ov_bereikbaarheidsindex = 0,
	ov_bereikbaarheidsniveau = 0
	WHERE ov_bereikbaarheidsindex IS NULL
;
-- add built density from PBL data
-- this query is extremely slow due to the geometric complexity and problems with the PBL data
-- DROP TABLE pbl_bouwblok_fsi_updated_validgeom CASCADE;
CREATE TEMP TABLE pbl_bouwblok_fsi_updated_validgeom AS
	SELECT objectid, (ST_Dump(ST_MakeValid(geom))).geom geom, fsi 
	FROM sources.pbl_bouwblok_fsi_updated
;
CREATE INDEX pbl_bouwblok_validgeom_idx ON pbl_bouwblok_fsi_updated_validgeom USING GIST(geom);
-- DROP TABLE temp_fysieke_dichtheid CASCADE;
CREATE TEMP TABLE temp_fysieke_dichtheid AS
	SELECT cbs.c28992r100 AS cell_id, pbl.objectid, pbl.fsi AS fsi
	FROM sources.vdm_vierkant_2014_pnh_lisa AS cbs, 
	pbl_bouwblok_fsi_updated_validgeom AS pbl
	WHERE ST_Contains(pbl.geom, cbs.geom)
;
-- DROP TABLE vdm_vierkant_2014_pnh_lisa_pbl CASCADE;
CREATE TEMP TABLE vdm_vierkant_2014_pnh_lisa_pbl AS
	SELECT geom, c28992r100 FROM sources.vdm_vierkant_2014_pnh_lisa a
	WHERE NOT EXISTS (SELECT 1 FROM temp_fysieke_dichtheid b WHERE a.c28992r100 = b.cell_id)
;
CREATE INDEX vdm_vierkant_lisa_pbl_idx ON vdm_vierkant_2014_pnh_lisa_pbl USING GIST(geom);
-- DELETE FROM temp_fysieke_dichtheid;
INSERT INTO temp_fysieke_dichtheid
	SELECT cbs.c28992r100 AS cell_id, pbl.objectid, 
		CASE 
			WHEN ST_Contains(cbs.geom, pbl.geom)
			THEN ST_Area(pbl.geom)*pbl.fsi/10000.0
			ELSE ST_Area(ST_Intersection(pbl.geom,cbs.geom))*pbl.fsi/10000.0 
		END AS fsi
	FROM vdm_vierkant_2014_pnh_lisa_pbl AS cbs, 
	pbl_bouwblok_fsi_updated_validgeom AS pbl
	WHERE ST_Intersects(pbl.geom, cbs.geom)
;
--
UPDATE datasysteem.ruimtelijke_kenmerken AS a
	SET fysieke_dichtheid = b.fsi
	FROM (SELECT cell_id, SUM(fsi) fsi FROM temp_fysieke_dichtheid GROUP BY cell_id) AS b
	WHERE a.cell_id = b.cell_id
;
-- add the gemmente name where the cell's centroid is located
UPDATE datasysteem.ruimtelijke_kenmerken AS a
	SET gemeente = b.gemeente
	FROM (SELECT cbs.c28992r100 AS cell_id, rap.gemeen_rap AS gemeente
		FROM sources.vdm_vierkant_2014_pnh_lisa AS cbs,
		sources.pnh_rap_en_plancapaciteit AS rap
		WHERE ST_Intersects(ST_Centroid(cbs.geom), rap.geom)
	) b
	WHERE a.cell_id = b.cell_id
;
--
CREATE INDEX ruimtelijke_kenmerken_geom_idx ON datasysteem.ruimtelijke_kenmerken USING GIST (geom);


----
-- Ontwikkellocaties kenmerken
-- Insert RAP data
-- DELETE FROM datasysteem.ontwikkellocaties WHERE plan_naam = 'Woningbouwafspraken 2020';
INSERT INTO datasysteem.ontwikkellocaties (geom, plan_naam, plan_id, gemeente, plaatsnaam, adres,
		bestaande_woningen, geplande_woningen, net_nieuwe_woningen, vlakte)
	SELECT geom, 'Woningbouwafspraken 2020', objectid, gemeen_rap, regio, '', 0, 
		rap_totaal, rap_totaal, round(ST_Area(geom)::numeric,0)
	FROM sources.pnh_rap_en_plancapaciteit
;
-- DELETE FROM datasysteem.ontwikkellocaties WHERE plan_naam = 'Tekort aan plannen 2020';
INSERT INTO datasysteem.ontwikkellocaties (geom, plan_naam, plan_id, gemeente, plaatsnaam, adres,
		bestaande_woningen, geplande_woningen, net_nieuwe_woningen, vlakte)
	SELECT geom, 'Tekort aan plannen 2020', objectid, gemeen_rap, regio, '', 
		plan_sloop, rap_totaal, rap_totaal-plan_sloop, round(ST_Area(geom)::numeric,0)
	FROM sources.pnh_rap_en_plancapaciteit
;
-- Insert Plancapaciteit data
-- DELETE FROM datasysteem.ontwikkellocaties WHERE plan_naam = 'Plancapaciteit';
INSERT INTO datasysteem.ontwikkellocaties(geom, plan_naam, plan_id, gemeente, plaatsnaam, adres,
		bestaande_woningen, geplande_woningen, net_nieuwe_woningen, vlakte)
	SELECT ST_Force2D(geom), 'Plancapaciteit', planid, gemnaam, naamplan, straat, 
		te_slopen, (op2016 + op201719 + op202024 + op202550 + oplonb), 
		(op2016 + op201719 + op202024 + op202550 + oplonb - te_slopen), 
		round(ST_Area(geom)::numeric,0)
	FROM sources.vdm_plancapaciteit_2016_update
;
-- Insert Kantorenleegstand data
-- DELETE FROM datasysteem.ontwikkellocaties WHERE plan_naam = 'Kantorleegstanden';
INSERT INTO datasysteem.ontwikkellocaties(geom, plan_naam, plan_id, gemeente, plaatsnaam, adres,
		bestaande_woningen, geplande_woningen, net_nieuwe_woningen, vlakte)
	SELECT geom, 'Kantorenleegstand', rinnummer, gemeente, plannaam, ookbekend,
		0, leegstand::numeric/100.0, leegstand::numeric/100.0, round(ST_Area(geom)::numeric,0)
	FROM sources.pnh_werklocaties_kantoren_leegstanden
;
-- Calculate dichtheid (per hectare = 10000m2)
UPDATE datasysteem.ontwikkellocaties SET dichtheid = geplande_woningen/vlakte*10000.0;
-- Calculate mean values of spatial characteristics of location
-- UPDATE datasysteem.ontwikkellocaties SET gemiddelde_bereikbaarheidsindex = NULL, gemiddelde_huishoudens = NULL, gemiddelde_intensiteit = NULL, gemiddelde_dichtheid = NULL, gemiddelde_woz = NULL, cell_ids = NULL;
UPDATE datasysteem.ontwikkellocaties dev SET
	gemiddelde_bereikbaarheidsindex = agg.mean_bereikbaarheid,
	gemiddelde_huishoudens = agg.mean_huishoudens,
	gemiddelde_intensiteit = agg.mean_intensiteit,
	gemiddelde_dichtheid = agg.mean_dichtheid,
	gemiddelde_woz = agg.mean_woz,
	cell_ids = agg.ids
	FROM (SELECT loc.sid, 
			round(avg(spat.ov_bereikbaarheidsindex)::numeric,2) AS mean_bereikbaarheid,
			round(avg(spat.huishoudens)::numeric,0) AS mean_huishoudens,
			round(avg(spat.intensiteit)::numeric,0) AS mean_intensiteit,
			round(avg(spat.fysieke_dichtheid)::numeric,3) AS mean_dichtheid,
			round(avg(spat.woz_waarde)::numeric,0) AS mean_woz,
			string_agg(spat.cell_id,',' ORDER BY spat.cell_id) ids
		FROM (
			SELECT * 
			FROM datasysteem.ontwikkellocaties
			WHERE plan_naam IN ('Plancapaciteit', 'Kantorenleegstand')
		) loc,
		(
			SELECT * 
			FROM datasysteem.ruimtelijke_kenmerken
			WHERE ov_bereikbaarheidsindex > 0
		) spat
		WHERE ST_Intersects(loc.geom,spat.geom)
		GROUP BY loc.sid
	) agg
	WHERE dev.sid = agg.sid
;
CREATE INDEX ontwikkellocaties_gidx ON datasysteem.ontwikkellocaties USING GIST (geom);


-----
-- OV isochronen van knooppunten
-- create polygons for isochrones
-- DELETE FROM datasysteem.isochronen WHERE modaliteit IN ('bus','tram','metro');
INSERT INTO datasysteem.isochronen(geom, halte_naam, halte_modaliteit, 
		modaliteit, isochroon_afstand)
	SELECT ST_Multi(ST_MakePolygon(ST_ExteriorRing((ST_Dump(
		ST_Simplify(ST_Union(ST_Buffer(ST_Simplify(geom,10),100,'quad_segs=2')),20))).geom))), 
		station_name, 'trein', stop_mode, 10
	FROM isochrone_analysis.stop_isochrone_wegen
	GROUP BY station_name, stop_mode
;
UPDATE datasysteem.isochronen AS iso SET halte_id = halte.halte_id
	FROM (SELECT * FROM datasysteem.ov_haltes WHERE trein = TRUE) AS halte
	WHERE iso.halte_naam = halte.halte_naam AND iso.halte_id IS NULL
;


-----
-- Invloedsgebied overlap
-- DELETE FROM datasysteem.invloedsgebied_overlap;
INSERT INTO datasysteem.invloedsgebied_overlap(geom, huishoudens, intensiteit, station_namen, station_aantal)
	SELECT ST_Multi(ST_Union(spaces.geom)), sum(spaces.huishoudens)::numeric, sum(spaces.intensiteit)::numeric,
		spaces.station_names, spaces.total
	FROM (
		SELECT min(a.geom) AS geom, a.cell_id, count(*) AS total, 
			string_agg(b.halte_naam,',' ORDER BY b.halte_naam) AS station_names,
			min(huishoudens) AS huishoudens, min(intensiteit) AS intensiteit
		FROM (SELECT * FROM datasysteem.ruimtelijke_kenmerken) a,
		(SELECT * FROM datasysteem.isochronen WHERE modaliteit = 'fiets') b
		WHERE ST_Intersects(ST_Centroid(a.geom),b.geom)
		GROUP BY a.cell_id
	) spaces
	WHERE spaces.total > 1
	GROUP BY spaces.total, spaces.station_names
;
-- update ov routes with stops in the overlap regions
-- UPDATE datasysteem.invloedsgebied_overlap SET ov_routes_ids = NULL;
UPDATE datasysteem.invloedsgebied_overlap AS overlap SET 
	ov_routes_ids = routes.ids
	FROM (SELECT c.sid, string_agg(c.route_id,',' ORDER BY c.route_id) ids
		FROM (SELECT a.sid, b.route_id
			FROM (
				SELECT route_id, ST_Multi((ST_DumpPoints(geom)).geom) geom
				FROM datasysteem.ov_routes
			) AS b, 
			datasysteem.invloedsgebied_overlap a
			WHERE ST_Intersects(a.geom,b.geom)
			GROUP BY a.sid, b.route_id
		) c
		GROUP BY c.sid
	) routes
	WHERE overlap.sid = routes.sid
;


----
-- Belangrijke locaties
-- DELETE FROM datasysteem.belangrijke_locaties;
INSERT INTO datasysteem.belangrijke_locaties(geom, locatie_id, locatie_naam, op_loopafstand, station_namen)
	SELECT locatie.geom, locatie.objectid, locatie.naam, FALSE, NULL
	FROM sources."economische_kerngebieden_DEF" locatie,
	(SELECT geom FROM datasysteem.grens WHERE grens_naam = 'Noord-Holland') pilot
	WHERE ST_Intersects(locatie.geom, pilot.geom)
;
-- update op_loopafstand
UPDATE datasysteem.belangrijke_locaties AS locatie SET 
	op_loopafstand = TRUE,
	station_namen = isochrone.halte_naam
	FROM (
		SELECT a.sid, b.halte_naam
		FROM datasysteem.belangrijke_locaties a,
		(SELECT * FROM datasysteem.isochronen WHERE halte_modaliteit = 'trein' AND modaliteit = 'walk'
		) b
		WHERE ST_Intersects(a.geom, b.geom) 
	) isochrone
	WHERE locatie.sid = isochrone.sid
;
-- update ov routes crossing the belangrijke locaties
-- UPDATE datasysteem.belangrijke_locaties SET ov_routes_ids = NULL;
UPDATE datasysteem.belangrijke_locaties AS locatie SET 
	ov_routes_ids = routes.ids
	FROM (SELECT c.sid, string_agg(c.route_id,',' ORDER BY c.route_id) ids
		FROM (SELECT a.sid, b.route_id
			FROM (
				SELECT route_id, ST_Multi((ST_DumpPoints(geom)).geom) geom
				FROM datasysteem.ov_routes
			) AS b, datasysteem.belangrijke_locaties a
			WHERE ST_DWithin(a.geom,b.geom,200)
			GROUP BY a.sid, b.route_id
		) c
		GROUP BY c.sid
	) routes
	WHERE locatie.sid = routes.sid
;


----
-- Calculate location of magneten
-- DELETE FROM datasysteem.magneten;
INSERT INTO datasysteem.magneten(geom, locatie_kwaliteit, locatie_naam, op_loopafstand, op_fietsafstand, op_ovafstand, 		station_namen)
	SELECT locatie.geom, locatie."kwal cat", locatie.naam, FALSE, FALSE, FALSE, NULL
	FROM sources.pnh_magneten locatie,
	(SELECT geom FROM datasysteem.grens WHERE grens_naam = 'Noord-Holland') pilot
	WHERE ST_Intersects(locatie.geom, pilot.geom)
;
-- update op_loopafstand
UPDATE datasysteem.magneten AS locatie SET 
	op_loopafstand = TRUE,
	station_namen = isochrone.halte_naam
	FROM (
		SELECT a.sid, b.halte_naam
		FROM datasysteem.magneten a,
		(SELECT * FROM datasysteem.isochronen WHERE halte_modaliteit = 'trein' AND modaliteit = 'walk'
		) b
		WHERE ST_Intersects(a.geom, b.geom) 
	) isochrone
	WHERE locatie.sid = isochrone.sid
;
-- update op_fietsafstand
UPDATE datasysteem.magneten AS locatie SET 
	op_fietsafstand = TRUE,
	station_namen = CASE
		WHEN locatie.station_namen IS NULL THEN isochrone.halte_namen
		ELSE locatie.station_namen||','||isochrone.halte_namen
	END
	FROM ( SELECT c.sid, string_agg(c.halte_naam,',' ORDER BY c.halte_naam) halte_namen
		FROM (SELECT a.sid, b.halte_naam
			FROM datasysteem.magneten a,
			(SELECT * FROM datasysteem.isochronen WHERE halte_modaliteit = 'trein' AND modaliteit = 'fiets'
			) b
			WHERE ST_Intersects(a.geom, b.geom)
		) c
		GROUP BY c.sid		
	) isochrone
	WHERE locatie.sid = isochrone.sid
;
-- update op_ovafstand
UPDATE datasysteem.magneten AS locatie SET 
	op_ovafstand = TRUE,
	station_namen = CASE
		WHEN locatie.station_namen IS NULL THEN isochrone.halte_namen
		ELSE locatie.station_namen||','||isochrone.halte_namen
	END
	FROM ( SELECT c.sid, string_agg(c.halte_naam,',' ORDER BY c.halte_naam) halte_namen
		FROM (SELECT a.sid, b.halte_naam
			FROM datasysteem.magneten a,
			(SELECT * FROM datasysteem.isochronen WHERE halte_modaliteit = 'trein' 
				AND modaliteit IN ('bus','tram','metro')
			) b
			WHERE ST_Intersects(a.geom, b.geom)
		) c
		GROUP BY c.sid		
	) isochrone
	WHERE locatie.sid = isochrone.sid
;
-- update ov routes crossing the magneten
-- UPDATE datasysteem.magneten SET ov_routes_ids = NULL;
UPDATE datasysteem.magneten AS locatie SET 
	ov_routes_ids = routes.ids
	FROM (SELECT c.sid, string_agg(c.route_id,',' ORDER BY c.route_id) ids
		FROM (SELECT a.sid, b.route_id
			FROM (
				SELECT route_id, ST_Multi((ST_DumpPoints(geom)).geom) geom
				FROM datasysteem.ov_routes
			) AS b, datasysteem.magneten a
			WHERE ST_DWithin(a.geom,b.geom,400)
			GROUP BY a.sid, b.route_id
		) c
		GROUP BY c.sid
	) routes
	WHERE locatie.sid = routes.sid
;


----
-- Build relevant cycle routes
-- identify links around stations (200m buffer)
-- DROP TABLE origin_destination_links CASCADE;
CREATE TEMP TABLE origin_destination_links AS 
	SELECT DISTINCT link.linknummer, stops.halte_naam station_naam
	FROM networks.fiets_links AS link,
	(SELECT * FROM datasysteem.ov_haltes WHERE trein = TRUE) AS stops
	WHERE ST_DWithin(link.geom,stops.geom,100)
;
-- build route geometry of routes that start/end at stations
-- DROP TABLE selected_fiets_routes CASCADE;
CREATE TEMP TABLE selected_fiets_routes AS
	SELECT routes.routeid, links.station_naam
	FROM networks.fiets_routes_ends routes,
	origin_destination_links links
	WHERE routes.start_link = links.linknummer
;
INSERT INTO selected_fiets_routes
	SELECT routes.routeid, links.station_naam
	FROM networks.fiets_routes_ends routes,
	origin_destination_links links
	WHERE routes.end_link = links.linknummer
;
-- DELETE FROM datasysteem.fietsroutes;
INSERT INTO datasysteem.fietsroutes(geom, route_id, route_intensiteit, station_naam)
	SELECT ST_MakeLine(pieces.geom), pieces.routeid, avg(pieces.intensiteit), min(pieces.station_naam)
	FROM (
		SELECT links.geom, routes.routeid, routes.id, links.linknummer,routes.station_naam, links.intensiteit
		FROM (SELECT a.routeid, a.id, a.linknummer, b.station_naam
			FROM networks.fiets_routes a,
			selected_fiets_routes b
			WHERE a.routeid = b.routeid
		) AS routes
		JOIN networks.fiets_links AS links
		USING(linknummer)
		ORDER BY routes.routeid, routes.id
	) pieces
	GROUP BY pieces.routeid
;
-- UPDATE datasysteem.fietsroutes SET invloedsgebied_ids = NULL;
UPDATE datasysteem.fietsroutes f SET invloedsgebied_ids = r.ids
	FROM (
		SELECT routes.sid, string_agg(overlap.sid::text,',' ORDER BY overlap.sid) ids 
		FROM datasysteem.fietsroutes AS routes, 
		datasysteem.invloedsgebied_overlap AS overlap
		WHERE routes.station_naam = ANY(string_to_array(overlap.station_namen,','))
		AND ST_Intersects(routes.geom,overlap.geom)
		GROUP BY routes.sid
	) r
	WHERE f.sid = r.sid
;
DELETE FROM datasysteem.fietsroutes WHERE ST_Length(geom) > 6000;