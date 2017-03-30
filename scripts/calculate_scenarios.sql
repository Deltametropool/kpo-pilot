-- KPO data system woon scenario calculation
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
-- UPDATE datasysteem.woonscenarios scenario SET dichtstbijzijnde_station = NULL;
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
-- Knooppunten scenarios
-- DELETE FROM datasysteem.knooppuntenscenarios;
-- TOD 0
-- insert knooppunten scenario values for TOD scenario 0, only stations within walking or cycling distance
INSERT INTO datasysteem.knooppuntenscenarios (geom, station_vdm_code, station_naam, halte_id, halte_naam,
		scenario_naam, tod_beleidsniveau, huishoudens, nieuwe_huishoudens, 
		procent_huis_verandering, procent_locale_reizigers)
	SELECT stops.geom, stops.station_vdm_code, stops.station_naam, stops.halte_id, stops.halte_naam, 
		woon.scenario_naam, 0, SUM(woon.huishoudens), SUM(woon.nieuwe_huishoudens),
		CASE
			WHEN SUM(woon.huishoudens)-SUM(woon.nieuwe_huishoudens) = 0 
				THEN SUM(woon.nieuwe_huishoudens)
			ELSE SUM(woon.nieuwe_huishoudens)::numeric/(SUM(woon.huishoudens)-SUM(woon.nieuwe_huishoudens))::numeric
		END,
		CASE 
			WHEN stops.lopen_voortransport IS NOT NULL AND stops.fiets_voortransport IS NOT NULL
			THEN stops.lopen_voortransport::double precision + stops.fiets_voortransport::double precision
		END
	FROM (
		SELECT geom, station_vdm_code, station_naam, halte_id, halte_naam, lopen_voortransport, fiets_voortransport
		FROM datasysteem.knooppunten
	) stops
	JOIN (
		SELECT scenario_naam, dichtstbijzijnde_station, huishoudens, nieuwe_huishoudens
		FROM datasysteem.woonscenarios
		WHERE (op_loopafstand = TRUE OR op_fietsafstand = TRUE)
		AND scenario_naam <> 'Huidige situatie'
	) AS woon
	ON (stops.halte_naam = woon.dichtstbijzijnde_station)
	GROUP BY stops.geom, stops.station_vdm_code, stops.station_naam, stops.halte_id, stops.halte_naam, 
		stops.lopen_voortransport, stops.fiets_voortransport, woon.scenario_naam
;
-- TOD 50
-- insert knooppunten values for TOD scenario 50, 50% new households to nearest stations
INSERT INTO datasysteem.knooppuntenscenarios (geom, station_vdm_code, station_naam, halte_id, halte_naam,
		scenario_naam, tod_beleidsniveau, huishoudens, nieuwe_huishoudens, 
		procent_huis_verandering, procent_locale_reizigers)
	SELECT stops.geom, stops.station_vdm_code, stops.station_naam, stops.halte_id, stops.halte_naam, 
		woon.scenario_naam, 50, SUM(woon.huishoudens), SUM(woon.nieuwe_huishoudens),
		CASE
			WHEN SUM(woon.huishoudens)-SUM(woon.nieuwe_huishoudens) = 0 THEN SUM(woon.nieuwe_huishoudens)
			ELSE SUM(woon.nieuwe_huishoudens)::numeric/(SUM(woon.huishoudens)-SUM(woon.nieuwe_huishoudens))::numeric
		END,
		CASE 
			WHEN stops.lopen_voortransport IS NOT NULL AND stops.fiets_voortransport IS NOT NULL
			THEN stops.lopen_voortransport::double precision + stops.fiets_voortransport::double precision
		END
	FROM (
		SELECT geom, station_vdm_code, station_naam, halte_id, halte_naam, lopen_voortransport, fiets_voortransport
		FROM datasysteem.knooppunten
	) stops
	JOIN (
		SELECT scenario_naam, dichtstbijzijnde_station, 
			CASE
				WHEN op_loopafstand = TRUE OR op_fietsafstand = TRUE 
					THEN huishoudens
				WHEN op_loopafstand = FALSE AND op_fietsafstand = FALSE AND nieuwe_huishoudens <= 0 
					THEN 0
				ELSE nieuwe_huishoudens * 0.5
			END AS huishoudens,
			CASE
				WHEN op_loopafstand = TRUE OR op_fietsafstand = TRUE THEN nieuwe_huishoudens
				WHEN op_loopafstand = FALSE AND op_fietsafstand = FALSE AND nieuwe_huishoudens <= 0 THEN 0
				ELSE nieuwe_huishoudens * 0.5
			END AS nieuwe_huishoudens
		FROM datasysteem.woonscenarios
		WHERE scenario_naam <> 'Huidige situatie'
	) AS woon
	ON (stops.halte_naam = woon.dichtstbijzijnde_station)
	GROUP BY stops.geom, stops.station_vdm_code, stops.station_naam, stops.halte_id, stops.halte_naam, 
		stops.lopen_voortransport, stops.fiets_voortransport, woon.scenario_naam
;
-- TOD 100
-- insert knooppunten values for TOD scenario 100, 100% new households to nearest stations
INSERT INTO datasysteem.knooppuntenscenarios (geom, station_vdm_code, station_naam, halte_id, halte_naam,
		scenario_naam, tod_beleidsniveau, huishoudens, nieuwe_huishoudens, 
		procent_huis_verandering, procent_locale_reizigers)
	SELECT stops.geom, stops.station_vdm_code, stops.station_naam, stops.halte_id, stops.halte_naam, 
		woon.scenario_naam, 100, SUM(woon.huishoudens), SUM(woon.nieuwe_huishoudens),
		CASE
			WHEN SUM(woon.huishoudens)-SUM(woon.nieuwe_huishoudens) = 0 THEN SUM(woon.nieuwe_huishoudens)
			ELSE SUM(woon.nieuwe_huishoudens)::numeric/(SUM(woon.huishoudens)-SUM(woon.nieuwe_huishoudens))::numeric
		END,
		CASE 
			WHEN stops.lopen_voortransport IS NOT NULL AND stops.fiets_voortransport IS NOT NULL
			THEN stops.lopen_voortransport::double precision + stops.fiets_voortransport::double precision
		END
	FROM (
		SELECT geom, station_vdm_code, station_naam, halte_id, halte_naam, lopen_voortransport, fiets_voortransport
		FROM datasysteem.knooppunten
	) stops
	JOIN (
		SELECT scenario_naam, dichtstbijzijnde_station, 
			CASE
				WHEN op_loopafstand = TRUE OR op_fietsafstand = TRUE THEN huishoudens
				WHEN op_loopafstand = FALSE AND op_fietsafstand = FALSE AND nieuwe_huishoudens <= 0 
					THEN 0
				ELSE nieuwe_huishoudens
			END AS huishoudens,
			CASE
				WHEN op_loopafstand = FALSE AND op_fietsafstand = FALSE AND nieuwe_huishoudens <= 0 THEN 0
				ELSE nieuwe_huishoudens
			END AS nieuwe_huishoudens
		FROM datasysteem.woonscenarios
		WHERE scenario_naam <> 'Huidige situatie'
	) AS woon
	ON (stops.halte_naam = woon.dichtstbijzijnde_station)
	GROUP BY stops.geom, stops.station_vdm_code, stops.station_naam, stops.halte_id, stops.halte_naam, 
		stops.lopen_voortransport, stops.fiets_voortransport, woon.scenario_naam
;
UPDATE datasysteem.knooppuntenscenarios SET procent_huis_verandering = round(procent_huis_verandering::numeric*100.0,2);
-- get the actual change from huising change and local train users
UPDATE datasysteem.knooppuntenscenarios SET procent_knoop_verandering = CASE
	WHEN procent_locale_reizigers IS NOT NULL
	THEN (procent_huis_verandering/100) * (procent_locale_reizigers/100)
	ELSE (procent_huis_verandering/100)
	END;
-- update knooppunt scenario characteristics
UPDATE datasysteem.knooppuntenscenarios knoop SET
	fiets_plaatsen = stations.fiets_plaatsen,
	pr_plaatsen = stations.pr_plaatsen,
	in_uit_trein = (procent_knoop_verandering * stations.in_uit_trein) + stations.in_uit_trein,
	in_uit_btm = (procent_knoop_verandering * stations.in_uit_btm) + stations.in_uit_btm,
	fiets_bezetting = (procent_knoop_verandering * stations.fiets_bezetting) + stations.fiets_bezetting,
	pr_bezetting = (procent_knoop_verandering * stations.pr_bezetting) + stations.pr_bezetting
	FROM datasysteem.knooppunten AS stations
	WHERE knoop.halte_id = stations.halte_id
;
UPDATE datasysteem.knooppuntenscenarios SET procent_knoop_verandering = round(procent_knoop_verandering::numeric*100.0,2);
