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
	SELECT vdm.geom, vdm.c28992r100, CASE WHEN vdm.won2012 >= 0 THEN vdm.won2012 ELSE 0 END, 
		CASE WHEN vdm.inw2014 >= 0 THEN vdm.inw2014 ELSE 0 END, vdm.sum_banen,
		CASE WHEN vdm.wozwon2012 >= 0 THEN vdm.wozwon2012 ELSE 0 END
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
UPDATE datasysteem.ruimtelijke_kenmerken AS a
	SET fysieke_dichtheid = b.fsi
	FROM (SELECT cbs.c28992r100 AS cell_id, 
		SUM(ST_Area(ST_Intersection(cbs.geom, ST_MakeValid(pbl.geom)))*pbl.fsi)/10000.0 AS fsi
		FROM sources.vdm_vierkant_2014_pnh_lisa cbs, sources.pbl_bouwvlak_fsi pbl
		WHERE ST_Intersects(cbs.geom, pbl.geom)
		GROUP BY cbs.c28992r100
		) b
	WHERE a.cell_id = b.cell_id
;


----
-- Ontwikkellocaties kenmerken
-- Insert RAP data
-- DELETE FROM datasysteem.ontwikkellocaties WHERE plan_naam = 'RAP 2020';
INSERT INTO datasysteem.ontwikkellocaties (geom, plan_naam, plan_id, gemeente, plaatsnaam, adres,
		bestaande_woningen, geplande_woningen, net_nieuwe_woningen, vlakte)
	SELECT geom, 'RAP 2020', objectid, gemeen_rap, regio, '', 0, rap_totaal, rap_totaal, ST_Area(geom)
	FROM sources.pnh_rap_en_plancapaciteit
;
-- DELETE FROM datasysteem.ontwikkellocaties WHERE plan_naam = 'RAP minder Plancapaciteit';
INSERT INTO datasysteem.ontwikkellocaties (geom, plan_naam, plan_id, gemeente, plaatsnaam, adres,
		bestaande_woningen, geplande_woningen, net_nieuwe_woningen, vlakte)
	SELECT geom, 'RAP minder Plancapaciteit', objectid, gemeen_rap, regio, '', 
		plan_sloop, rap_totaal, rap_totaal-plan_sloop, ST_Area(geom)
	FROM sources.pnh_rap_en_plancapaciteit
;
-- Insert Plancapaciteit data
-- DELETE FROM datasysteem.ontwikkellocaties WHERE plan_naam = 'Plancapaciteit';
INSERT INTO datasysteem.ontwikkellocaties(geom, plan_naam, plan_id, gemeente, plaatsnaam, adres,
		bestaande_woningen, geplande_woningen, net_nieuwe_woningen, vlakte)
	SELECT ST_Force2D(geom), 'Plancapaciteit', planid, gemnaam, naamplan, straat, 
		te_slopen, (wtypapp + wtypggb), (wtypapp + wtypggb - te_slopen), ST_Area(geom)
	FROM sources.vdm_plancapaciteit_2016_update
;
-- Insert Leegstanden data
-- DELETE FROM datasysteem.ontwikkellocaties WHERE plan_naam = 'Leegstanden';
INSERT INTO datasysteem.ontwikkellocaties(geom, plan_naam, plan_id, gemeente, plaatsnaam, adres,
		bestaande_woningen, geplande_woningen, net_nieuwe_woningen, vlakte)
	SELECT geom, 'Leegstanden', rinnummer, gemeente, plannaam, ookbekend,
		0, leegstand::numeric/100.0, leegstand::numeric/100.0, ST_Area(geom)
	FROM sources.pnh_werklocaties_kantoren_leegstanden
;
-- Calculate dichtheid (per hectare = 10000m2)
UPDATE datasysteem.ontwikkellocaties SET dichtheid = geplande_woningen/vlakte*10000;
-- Calculate gemiddelde_bereikbaarheidsindex, maximale_bereikbaarheidsindex
UPDATE datasysteem.ontwikkellocaties dev SET
	gemiddelde_bereikbaarheidsindex = acc.mean,
	maximale_bereikbaarheidsindex = acc.max
	FROM (SELECT loc.sid, max(spat.ov_bereikbaarheidsindex) AS max, avg(spat.ov_bereikbaarheidsindex) AS mean
		FROM datasysteem.ontwikkellocaties loc,
		(SELECT ST_Centroid(geom) AS geom, ov_bereikbaarheidsindex 
			FROM datasysteem.ruimtelijke_kenmerken
			WHERE ov_bereikbaarheidsindex > 0
		) spat
		WHERE ST_Intersects(loc.geom,spat.geom)
		GROUP BY loc.sid
	)acc
	WHERE dev.sid = acc.sid
;
CREATE INDEX ontwikkellocaties_gidx ON datasysteem.ontwikkellocaties USING GIST (geom);


----
-- OV routes
-- DELETE FROM datasysteem.ov_routes;
INSERT INTO datasysteem.ov_routes(geom, route_id, route_naam, modaliteit)
	SELECT trips.geom, routes.route_id, min(trips.route_name), min(trips.trip_mode)
	FROM (
		SELECT ST_MakeLine(links.geom) geom, links.trip_id, min(links.trip_mode) AS trip_mode, 
			min(links.route_name) AS route_name, sum(links.duration_in_secs) AS trip_duration
		FROM (SELECT geom, trip_id, trip_mode, route_name, trip_sequence, duration_in_secs
			FROM networks.ov_links
			WHERE trip_mode !='trein'
			ORDER BY trip_id, trip_sequence
		) links
		GROUP BY links.trip_id
	) AS trips
	JOIN networks.ov_trips as routes
	USING(trip_id)
	GROUP BY trips.geom, trips.trip_mode, routes.route_id, trips.route_name
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
-- Invloedsgebied overlap
-- DELETE FROM datasysteem.invloedsgebied_overlap;
INSERT INTO datasysteem.invloedsgebied_overlap(geom, inwoner_dichtheid, intensiteit, station_namen, station_aantal)
	SELECT ST_Multi(ST_Union(spaces.geom)), sum(spaces.inwoners)::numeric/count(*)::numeric, 
		sum(spaces.intensiteit)::numeric/count(*)::numeric,
		spaces.station_names, spaces.total
	FROM (
		SELECT min(a.geom) AS geom, a.cell_id, count(*) AS total, 
			string_agg(b.halte_naam,',' ORDER BY b.halte_naam) AS station_names,
			min(inwoners) AS inwoners, min(intensiteit) AS intensiteit
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
-- DELETE FROM datasysteem.belangrijke_locaties;
INSERT INTO datasysteem.belangrijke_locaties(geom, locatie_id, locatie_naam)
	SELECT locatie.geom, locatie.objectid, locatie.naam
	FROM sources."economische_kerngebieden_DEF" locatie,
	(SELECT ST_Buffer(geom,5000) geom FROM datasysteem.boundary LIMIT 1) pilot
	WHERE ST_Intersects(locatie.geom, pilot.geom)
;
-- update op_loopafstand
UPDATE datasysteem.belangrijke_locaties AS locatie SET 
	op_loopafstand = TRUE
	FROM (
		SELECT a.sid
		FROM datasysteem.belangrijke_locaties a,
		(SELECT * FROM datasysteem.isochronen
		WHERE halte_modaliteit = 'trein' AND modaliteit = 'walk') b
		WHERE ST_Intersects(a.geom, b.geom) 
	) isochrone
	WHERE locatie.sid = isochrone.sid
;
UPDATE datasysteem.belangrijke_locaties SET op_loopafstand = FALSE WHERE op_loopafstand IS NULL;
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
-- Calculate location of important services
-- DELETE FROM datasysteem.regionale_voorzieningen;
INSERT INTO datasysteem.regionale_voorzieningen(geom, locatie_id, type_locatie, locatie_naam)
	SELECT locatie.geom, locatie.lisanr, locatie.vdm_type_v, locatie.naam
	FROM sources.pnh_lisa_2016_selectie_voorzieningen locatie,
	(SELECT ST_Buffer(geom,5000) geom FROM datasysteem.boundary LIMIT 1) pilot
	WHERE ST_Intersects(locatie.geom, pilot.geom)
;
-- update op_loopafstand
UPDATE datasysteem.regionale_voorzieningen AS locatie SET 
	op_loopafstand = TRUE
	FROM (
		SELECT a.sid
		FROM datasysteem.regionale_voorzieningen a,
		(SELECT * FROM datasysteem.isochronen
		WHERE halte_modaliteit = 'trein' AND modaliteit = 'walk') b
		WHERE ST_Intersects(a.geom, b.geom) 
	) isochrone
	WHERE locatie.sid = isochrone.sid
;
UPDATE datasysteem.regionale_voorzieningen SET op_loopafstand = FALSE WHERE op_loopafstand IS NULL;
-- update ov routes crossing the regionale voorzieningen
-- UPDATE datasysteem.regionale_voorzieningen SET ov_routes_ids = NULL;
UPDATE datasysteem.regionale_voorzieningen AS locatie SET 
	ov_routes_ids = routes.ids
	FROM (SELECT c.sid, string_agg(c.route_id,',' ORDER BY c.route_id) ids
		FROM (SELECT a.sid, b.route_id
			FROM (
				SELECT route_id, ST_Multi((ST_DumpPoints(geom)).geom) geom
				FROM datasysteem.ov_routes
			) AS b, datasysteem.regionale_voorzieningen a
			WHERE ST_DWithin(a.geom,b.geom,400)
			GROUP BY a.sid, b.route_id
		) c
		GROUP BY c.sid
	) routes
	WHERE locatie.sid = routes.sid
;


----
-- Build relevant cycle routes 
-- DELETE FROM datasysteem.cycle_routes;
INSERT INTO datasysteem.cycle_routes(geom,route_id,route_name,link_frequency)
	SELECT
	FROM 
;
--select count(*) from (select distinct(routeid) routeid from sources.fietstelweek_routes2016) as foo

