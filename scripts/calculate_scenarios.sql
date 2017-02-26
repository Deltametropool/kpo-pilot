-- KPO data system data model
-- author: Jorge Gil, 2017


-----
-- calculate dichtstbijzijnde station of housing scenario regions
-- loopafstand
UPDATE datasysteem.woonscenarios scenario
	SET op_loopafstand = TRUE
	FROM (
		SELECT * FROM datasysteem.isochronen 
		WHERE halte_modaliteit = 'trein'
		AND modaliteit = 'walk'
	) isochrone
	WHERE ST_Intersects(scenario.geom,isochrone.geom) 
;
-- fietsafstand
UPDATE datasysteem.woonscenarios scenario
	SET op_fietsafstand = TRUE
	FROM (
		SELECT * FROM datasysteem.isochronen 
		WHERE halte_modaliteit = 'trein'
		AND modaliteit = 'fiets'
	) isochrone
	WHERE ST_Intersects(scenario.geom,isochrone.geom) 
;
-- dichtstbijzijnde station
-- identify stations
-- DROP TABLE top_station;
CREATE TEMP TABLE top_station AS
	SELECT DISTINCT ON (woon.code) woon.code, iso.halte_naam ,iso.hsl_avondspits,iso.ic_avondspits,iso.spr_avondspits
	FROM (
		SELECT * FROM datasysteem.woonscenarios
		WHERE scenario_naam = 'Huidige situatie'
	) AS woon,
	(
		SELECT a.geom, a.halte_naam, a.isochroon_afstand, b.hsl_avondspits, b.ic_avondspits, b.spr_avondspits 
		FROM (
			SELECT * FROM datasysteem.isochronen 
			WHERE halte_modaliteit = 'trein'
		) a,(
			SELECT * FROM datasysteem.ov_haltes
			WHERE trein = TRUE
		) b
		WHERE a.halte_id = b.halte_id
	) AS iso
	WHERE ST_Intersects(woon.geom,iso.geom)
	ORDER BY woon.code ASC, 
		iso.isochroon_afstand ASC, -- comment this out to link to the strongest station
		coalesce(iso.hsl_avondspits,0) DESC, 
		coalesce(iso.ic_avondspits,0) DESC, 
		coalesce(iso.spr_avondspits,0) DESC
;
-- update scenarios table
UPDATE datasysteem.woonscenarios AS scenario
	SET dichtstbijzijnde_station = station.halte_naam
	FROM top_station AS station
	WHERE scenario.code = station.code 
;
-- get stations for remaining scenarios
DROP TABLE top_station;
CREATE TEMP TABLE top_station AS
	SELECT DISTINCT ON (woon.code) woon.code, iso.halte_naam ,iso.hsl_avondspits,iso.ic_avondspits,iso.spr_avondspits
	FROM (
		SELECT * FROM datasysteem.woonscenarios
		WHERE scenario_naam = 'Huidige situatie'
		AND dichtstbijzijnde_station IS NULL
	) AS woon,
	(
		SELECT a.geom, a.halte_naam, a.isochroon_afstand, b.hsl_avondspits, b.ic_avondspits, b.spr_avondspits 
		FROM (
			SELECT * FROM datasysteem.isochronen 
			WHERE halte_modaliteit = 'trein'
			AND modaliteit = 'fiets'
		) a,(
			SELECT * FROM datasysteem.ov_haltes
			WHERE trein = TRUE
		) b
		WHERE a.halte_id = b.halte_id
	) AS iso
	ORDER BY woon.code ASC,
		woon.geom <-> iso.geom,
		coalesce(iso.hsl_avondspits,0) DESC, 
		coalesce(iso.ic_avondspits,0) DESC, 
		coalesce(iso.spr_avondspits,0) DESC
;
-- update table for remaining scenarios
UPDATE datasysteem.woonscenarios AS scenario
	SET dichtstbijzijnde_station = station.halte_naam
	FROM top_station AS station
	WHERE dichtstbijzijnde_station IS NULL
	AND scenario.code = station.code 
;


-----
-- Overzicht woonscenarios
-- DELETE FROM datasysteem.overzicht_woonscenarios;
-- TOD level 0
INSERT INTO datasysteem.overzicht_woonscenarios (scenario_naam, tod_beleidsniveau, verwachte_huishoudens,
	op_loopafstand, op_fietsafstand)
	SELECT scenario_naam, 0, SUM(huishoudens), 
		SUM(CASE WHEN op_loopafstand THEN huishoudens END),
		SUM(CASE WHEN op_fietsafstand AND NOT op_loopafstand THEN huishoudens END)
	FROM datasysteem.woonscenarios
	GROUP BY scenario_naam
;
UPDATE datasysteem.overzicht_woonscenarios 
	SET buiten_invloedsgebied = (verwachte_huishoudens-op_loopafstand-op_fietsafstand)
	WHERE tod_beleidsniveau = 0
;
-- TOD level 50
INSERT INTO datasysteem.overzicht_woonscenarios (scenario_naam, tod_beleidsniveau, verwachte_huishoudens,
	op_loopafstand, op_fietsafstand)
	SELECT scenario_naam, 50, SUM(huishoudens), 
		SUM(CASE WHEN op_loopafstand THEN huishoudens END),
		SUM(CASE WHEN op_fietsafstand AND NOT op_loopafstand THEN huishoudens END)
	FROM datasysteem.woonscenarios
	GROUP BY scenario_naam
;
UPDATE datasysteem.overzicht_woonscenarios 
	SET buiten_invloedsgebied = (verwachte_huishoudens-op_loopafstand-op_fietsafstand)::float/2.0, 
		op_fietsafstand = op_fietsafstand+(verwachte_huishoudens-op_loopafstand-op_fietsafstand)::float/2.0
	WHERE tod_beleidsniveau = 50
;
-- TOD level 100
INSERT INTO datasysteem.overzicht_woonscenarios (scenario_naam, tod_beleidsniveau, verwachte_huishoudens,
	op_loopafstand, op_fietsafstand)
	SELECT scenario_naam, 100, SUM(huishoudens), 
		SUM(CASE WHEN op_loopafstand THEN huishoudens END),
		SUM(CASE WHEN op_fietsafstand AND NOT op_loopafstand THEN huishoudens END)
	FROM datasysteem.woonscenarios
	GROUP BY scenario_naam
;
UPDATE datasysteem.overzicht_woonscenarios 
	SET buiten_invloedsgebied = 0, 
		op_fietsafstand = op_fietsafstand+(verwachte_huishoudens-op_loopafstand-op_fietsafstand)
	WHERE tod_beleidsniveau = 100
;


-----
-- Kenmerken van knooppunten
-- DELETE FROM datasysteem.knooppuntenscenarios;
-- TOD 0
-- insert knooppunten scenario values for TOD scenario 0, only stations within walking or cycling distance
INSERT INTO datasysteem.knooppuntenscenarios (geom, station_vdm_code, station_naam, halte_id, halte_naam,
		scenario_naam, tod_beleidsniveau, huishoudens, procentuele_verandering)
	SELECT areas.geom, stops.stop_code, areas.alt_name, stops.stop_id, stops.stop_name, 
		woon.scenario_naam, 0, SUM(woon.huishoudens),
		CASE
			WHEN SUM(woon.huishoudens-woon.nieuwe_huishoudens) = 0 THEN SUM(woon.nieuwe_huishoudens)
			ELSE SUM(woon.nieuwe_huishoudens)::numeric/SUM(woon.huishoudens-woon.nieuwe_huishoudens)::numeric
		END
	FROM networks.ov_stop_areas AS areas
	JOIN (
		SELECT stop_id, stop_name, stop_area, stop_code FROM networks.ov_stops
		WHERE trein = True AND location_type = 1
	) AS stops
	ON(areas.sid = stops.stop_area)
	JOIN (
		SELECT scenario_naam, dichtstbijzijnde_station, huishoudens, nieuwe_huishoudens
		FROM datasysteem.woonscenarios
		WHERE (op_loopafstand = TRUE OR op_fietsafstand = TRUE)
		AND scenario_naam <> 'Huidige situatie'
	) AS woon
	ON (stops.stop_name = woon.dichtstbijzijnde_station)
	GROUP BY areas.geom, stops.stop_code, areas.alt_name, stops.stop_id, stops.stop_name, woon.scenario_naam
;
-- TOD 50
-- insert knooppunten values for TOD scenario 0, only stations within walking or cycling distance
INSERT INTO datasysteem.knooppuntenscenarios (geom, station_vdm_code, station_naam, halte_id, halte_naam,
		scenario_naam, tod_beleidsniveau, huishoudens, procentuele_verandering)
	SELECT areas.geom, stops.stop_code, areas.alt_name, stops.stop_id, stops.stop_name, 
		woon.scenario_naam, 50, SUM(woon.huishoudens),
		CASE
			WHEN SUM(woon.huishoudens-woon.nieuwe_huishoudens) = 0 THEN SUM(woon.nieuwe_huishoudens)
			ELSE SUM(woon.nieuwe_huishoudens)::numeric/SUM(woon.huishoudens-woon.nieuwe_huishoudens)::numeric
		END
	FROM networks.ov_stop_areas AS areas
	JOIN (
		SELECT stop_id, stop_name, stop_code, stop_area FROM networks.ov_stops
		WHERE trein = True AND location_type = 1
	) AS stops
	ON(areas.sid = stops.stop_area)
	JOIN (
		SELECT scenario_naam, dichtstbijzijnde_station, 
			CASE
				WHEN op_loopafstand = TRUE OR op_fietsafstand = TRUE THEN huishoudens
				ELSE huishoudens * 0.5
			END AS huishoudens,
			CASE
				WHEN op_loopafstand = TRUE OR op_fietsafstand = TRUE THEN nieuwe_huishoudens
				ELSE nieuwe_huishoudens * 0.5
			END AS nieuwe_huishoudens
		FROM datasysteem.woonscenarios
		WHERE scenario_naam <> 'Huidige situatie'
	) AS woon
	ON (stops.stop_name = woon.dichtstbijzijnde_station)
	GROUP BY areas.geom, stops.stop_code, areas.alt_name, stops.stop_id, stops.stop_name, woon.scenario_naam
;
-- TOD 100
-- insert knooppunten values for TOD scenario 0, only stations within walking or cycling distance
INSERT INTO datasysteem.knooppuntenscenarios (geom, station_vdm_code, station_naam, halte_id, halte_naam,
		scenario_naam, tod_beleidsniveau, huishoudens, procentuele_verandering)
	SELECT areas.geom, stops.stop_code, areas.alt_name, stops.stop_id, stops.stop_name, 
		woon.scenario_naam, 100, SUM(woon.huishoudens),
		CASE
			WHEN SUM(woon.huishoudens-woon.nieuwe_huishoudens) = 0 THEN SUM(woon.nieuwe_huishoudens)
			ELSE SUM(woon.nieuwe_huishoudens)::numeric/SUM(woon.huishoudens-woon.nieuwe_huishoudens)::numeric
		END
	FROM networks.ov_stop_areas AS areas
	JOIN (
		SELECT stop_id, stop_name, stop_code, stop_area FROM networks.ov_stops
		WHERE trein = True AND location_type = 1
	) AS stops
	ON(areas.sid = stops.stop_area)
	JOIN (
		SELECT scenario_naam, dichtstbijzijnde_station, huishoudens, nieuwe_huishoudens
		FROM datasysteem.woonscenarios
		WHERE scenario_naam <> 'Huidige situatie'
	) AS woon
	ON (stops.stop_name = woon.dichtstbijzijnde_station)
	GROUP BY areas.geom, stops.stop_code, areas.alt_name, stops.stop_id, stops.stop_name, woon.scenario_naam
;
-- update knooppunt scenario characteristics
UPDATE datasysteem.knooppuntenscenarios knoop SET
	totaal_passanten = (knoop.procentuele_verandering * stations.totaal_passanten) + stations.totaal_passanten,
	in_uit_trein = (knoop.procentuele_verandering * stations.in_uit_trein) + stations.in_uit_trein,
	overstappers = (knoop.procentuele_verandering * stations.overstappers) + stations.overstappers,
	in_uit_btm = (knoop.procentuele_verandering * stations.in_uit_btm) + stations.in_uit_btm,
	bezoekers = (knoop.procentuele_verandering * stations.bezoekers) + stations.bezoekers,
	fiets_bezetting = (knoop.procentuele_verandering * stations.fiets_bezetting) + stations.fiets_bezetting,
	pr_bezetting = (knoop.procentuele_verandering * stations.pr_bezetting) + stations.pr_bezetting
	FROM datasysteem.knooppunten AS stations
	WHERE knoop.halte_id = stations.halte_id
;