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
-- DELETE FROM datasysteem.knooppunten;
-- TOD 0
-- insert knooppunten values for TOD scenario 0, only stations within walking or cycling distance
INSERT INTO datasysteem.knooppunten (geom, station_naam, halte_id, halte_naam,
		scenario_naam, tod_beleidsniveau, huishoudens, procentuele_verandering)
	SELECT areas.geom, areas.alt_name, stops.stop_id, stops.stop_name, 
		woon.scenario_naam, 0, SUM(woon.huishoudens),
		CASE
			WHEN SUM(woon.huishoudens-woon.nieuwe_huishoudens) = 0 THEN SUM(woon.nieuwe_huishoudens)
			ELSE SUM(woon.nieuwe_huishoudens)::numeric/SUM(woon.huishoudens-woon.nieuwe_huishoudens)::numeric
		END
	FROM networks.ov_stop_areas AS areas
	JOIN (
		SELECT stop_id, stop_name, stop_area FROM networks.ov_stops
		WHERE trein = True AND location_type = 1
	) AS stops
	ON(areas.sid = stops.stop_area)
	JOIN (
		SELECT scenario_naam, dichtstbijzijnde_station, huishoudens, nieuwe_huishoudens
		FROM datasysteem.woonscenarios
		WHERE op_loopafstand = TRUE OR op_fietsafstand = TRUE
	) AS woon
	ON (stops.stop_name = woon.dichtstbijzijnde_station)
	GROUP BY areas.geom, areas.alt_name, stops.stop_id, stops.stop_name, woon.scenario_naam
;
-- TOD 50
-- insert knooppunten values for TOD scenario 0, only stations within walking or cycling distance
INSERT INTO datasysteem.knooppunten (geom, station_naam, halte_id, halte_naam,
		scenario_naam, tod_beleidsniveau, huishoudens, procentuele_verandering)
	SELECT areas.geom, areas.alt_name, stops.stop_id, stops.stop_name, 
		woon.scenario_naam, 50, SUM(woon.huishoudens),
		CASE
			WHEN SUM(woon.huishoudens-woon.nieuwe_huishoudens) = 0 THEN SUM(woon.nieuwe_huishoudens)
			ELSE SUM(woon.nieuwe_huishoudens)::numeric/SUM(woon.huishoudens-woon.nieuwe_huishoudens)::numeric
		END
	FROM networks.ov_stop_areas AS areas
	JOIN (
		SELECT stop_id, stop_name, stop_area FROM networks.ov_stops
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
	GROUP BY areas.geom, areas.alt_name, stops.stop_id, stops.stop_name, woon.scenario_naam
;
-- TOD 100
-- insert knooppunten values for TOD scenario 0, only stations within walking or cycling distance
INSERT INTO datasysteem.knooppunten (geom, station_naam, halte_id, halte_naam,
		scenario_naam, tod_beleidsniveau, huishoudens, procentuele_verandering)
	SELECT areas.geom, areas.alt_name, stops.stop_id, stops.stop_name, 
		woon.scenario_naam, 100, SUM(woon.huishoudens),
		CASE
			WHEN SUM(woon.huishoudens-woon.nieuwe_huishoudens) = 0 THEN SUM(woon.nieuwe_huishoudens)
			ELSE SUM(woon.nieuwe_huishoudens)::numeric/SUM(woon.huishoudens-woon.nieuwe_huishoudens)::numeric
		END
	FROM networks.ov_stop_areas AS areas
	JOIN (
		SELECT stop_id, stop_name, stop_area FROM networks.ov_stops
		WHERE trein = True AND location_type = 1
	) AS stops
	ON(areas.sid = stops.stop_area)
	JOIN (
		SELECT scenario_naam, dichtstbijzijnde_station, huishoudens, nieuwe_huishoudens
		FROM datasysteem.woonscenarios
		WHERE scenario_naam <> 'Huidige situatie'
	) AS woon
	ON (stops.stop_name = woon.dichtstbijzijnde_station)
	GROUP BY areas.geom, areas.alt_name, stops.stop_id, stops.stop_name, woon.scenario_naam
;
-- update knooppunt characteristics
-- current scenario values
UPDATE datasysteem.knooppunten knoop
	SET in_uitstappers = stations.in_uit_15,
	in_uitstappers_verschil = 0,
	fietsparkeerplaatsen = stations.aantal_fie, 
	fietsen = stations.aantal_geb,
	fietsenstalling_capaciteit = CASE
		WHEN stations.aantal_fie > 0 
		THEN stations.aantal_geb::numeric/stations.aantal_fie::numeric
		ELSE 0
		END
	FROM sources.rws_treinstations_2015_pnh stations
	WHERE knoop.scenario_naam = 'Huidige situatie'
	AND knoop.station_naam = stations.station
;
-- other scenarios for different TOD policy levels
UPDATE datasysteem.knooppunten knoop
	SET in_uitstappers = (knoop.procentuele_verandering * stations.in_uitstappers) + stations.in_uitstappers,
	in_uitstappers_verschil = knoop.procentuele_verandering * stations.in_uitstappers,
	fietsparkeerplaatsen = stations.fietsparkeerplaatsen, 
	fietsen = (knoop.procentuele_verandering * stations.fietsen) + stations.fietsen,
	fietsenstalling_capaciteit = 
		(knoop.procentuele_verandering * stations.fietsenstalling_capaciteit) 
		+ stations.fietsenstalling_capaciteit
	FROM (SELECT * FROM datasysteem.knooppunten WHERE scenario_naam = 'Huidige situatie') stations
	WHERE knoop.scenario_naam <> 'Huidige situatie'
	AND knoop.halte_id = stations.halte_id
;