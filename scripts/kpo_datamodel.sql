-- KPO data system data model
-- author: Jorge Gil, 2017


-- object: datasysteem | type: SCHEMA --
-- DROP SCHEMA IF EXISTS datasysteem CASCADE;
CREATE SCHEMA datasysteem;
ALTER SCHEMA datasysteem OWNER TO postgres;

-- DROP TABLE IF EXISTS datasysteem.woonscenarios CASCADE;
CREATE TABLE datasysteem.woonscenarios(
	sid serial NOT NULL,
	geom geometry(MultiPolygon,28992),
	code varchar,
	plaatsnaam varchar,
	scenario_naam varchar,
	op_loopafstand boolean,
	op_fietsafstand boolean,
	dichtstbijzijnde_station varchar,
	huishoudens integer,
	area double precision,
	dichtheid double precision,
	nieuwe_huishoudens integer,
	procentuele_verandering double precision,
	CONSTRAINT woonscenarios_pk PRIMARY KEY (sid)
);

-- DROP TABLE IF EXISTS datasysteem.overzicht_woonscenarios CASCADE;
CREATE TABLE datasysteem.overzicht_woonscenarios(
	sid serial NOT NULL,
	scenario_naam varchar,
	tod_beleidsniveau smallint,
	verwachte_huishoudens integer,
	op_loopafstand integer,
	op_fietsafstand integer,
	buiten_invloedsgebied integer,
	CONSTRAINT overzicht_woonscenarios_pkey PRIMARY KEY (sid)
);

-- DROP TABLE IF EXISTS datasysteem.knooppunten CASCADE;
CREATE TABLE datasysteem.knooppunten(
	sid serial NOT NULL,
	geom geometry(MultiPoint,28992),
	station_naam varchar,
	halte_id varchar,
	halte_naam varchar,
	scenario_naam varchar,
	tod_beleidsniveau smallint,
	huishoudens integer,
	procentuele_verandering double precision,
	in_uitstappers integer,
	in_uitstappers_verschil integer,
	fietsparkeerplaatsen integer,
	fietsen integer,
	fietsenstalling_capaciteit double precision,
	perron_capaciteit integer,
	perron_verschil double precision,
	stijgpunten_capaciteit integer,
	stijgpunten_verschil double precision,
	loopstromen_capaciteit integer,
	loopstromen_verschil double precision,
	fietsroutes varchar,
	ov_routes varchar,
	CONSTRAINT knooppunten_pkey PRIMARY KEY (sid)
);

-- DROP TABLE IF EXISTS datasysteem.ruimtelijke_kenmerken CASCADE;
CREATE TABLE datasysteem.ruimtelijke_kenmerken(
	sid serial NOT NULL,
	geom geometry(MultiPolygon,28992),
	cell_id varchar,
	huishoudens integer,
	inwoners integer,
	intensiteit integer,
	fysieke_dichtheid double precision,
	woz_waarde double precision,
	ov_bereikbaarheidsniveau varchar,
	ov_bereikbaarheidsindex double precision,
	CONSTRAINT ruimtelijke_kenmerken_pkey PRIMARY KEY (sid)
);

-- DROP TABLE IF EXISTS datasysteem.ontwikkellocaties CASCADE;
CREATE TABLE datasysteem.ontwikkellocaties(
	sid serial NOT NULL,
	geom geometry(MultiPolygon,28992),
	plan_naam varchar,
	plan_id varchar,
	gemeente varchar,
	plaatsnaam varchar,
	adres varchar,
	bestaande_woningen integer,
	geplande_woningen integer,
	net_nieuwe_woningen integer,
	vlakte double precision,
	dichtheid double precision,
	gemiddelde_bereikbaarheidsindex double precision,
	maximale_bereikbaarheidsindex double precision,
	bereikbaare_locatie boolean,
	CONSTRAINT ontwikkellocaties_pkey PRIMARY KEY (sid)
);

-- DROP TABLE IF EXISTS datasysteem.overzicht_ontwikkellocaties CASCADE;
CREATE TABLE datasysteem.overzicht_ontwikkellocaties(
	sid serial NOT NULL,
	plan_naam varchar,
	geplande_woningen integer,
	in_onderbenut_bereikbaar integer,
	buiten_onderbenut_bereikbaar integer,
	CONSTRAINT overzicht_ontwikkellocaties_pkey PRIMARY KEY (sid)
);

-- DROP TABLE IF EXISTS datasysteem.invloedsgebied_overlap CASCADE;
CREATE TABLE datasysteem.invloedsgebied_overlap(
	sid serial NOT NULL,
	geom geometry(MultiPolygon,28992),
	inwoner_dichtheid integer,
	intensiteit integer,
	station_namen varchar,
	station_aantal smallint,
	ov_routes_ids varchar,
	CONSTRAINT invloedsgebied_overlap_pkey PRIMARY KEY (sid)
);

-- DROP TABLE IF EXISTS datasysteem.belangrijke_locaties CASCADE;
CREATE TABLE datasysteem.belangrijke_locaties(
	sid serial NOT NULL,
	geom geometry(MultiPolygon,28992),
	locatie_id varchar,
	location_naam varchar,
	ov_routes_ids varchar,
	CONSTRAINT belangrijke_locaties_pkey PRIMARY KEY (sid)
);

-- DROP TABLE IF EXISTS datasysteem.regionale_voorzieningen CASCADE;
CREATE TABLE datasysteem.regionale_voorzieningen(
	sid serial NOT NULL,
	geom geometry(MultiPoint,28992),
	locatie_id varchar,
	location_naam varchar,
	ov_routes_ids varchar,
	CONSTRAINT regionale_voorzieningen_pkey PRIMARY KEY (sid)
);

-- DROP TABLE IF EXISTS datasysteem.fietsroutes CASCADE;
CREATE TABLE datasysteem.fietsroutes(
	sid serial NOT NULL,
	geom geometry(Linestring,28992),
	route_id varchar,
	link_id varchar,
	route_intensiteit smallint,
	invloedsgebied_ids varchar,
	CONSTRAINT fietsroutes_pkey PRIMARY KEY (sid)
);

-- DROP TABLE IF EXISTS datasysteem.ov_routes CASCADE;
CREATE TABLE datasysteem.ov_routes(
	sid serial NOT NULL,
	geom geometry(Linestring,28992),
	route_id varchar,
	route_naam varchar,
	route_modaliteit varchar,
	route_frequentie double precision,
	CONSTRAINT ov_routes_pkey PRIMARY KEY (sid)
);

-- DROP TABLE IF EXISTS datasysteem.isochronen CASCADE;
CREATE TABLE datasysteem.isochronen(
	sid serial NOT NULL,
	geom geometry(MultiPolygon,28992),
	halte_id varchar,
	halte_naam varchar,
	halte_modaliteit varchar,
	modaliteit varchar,
	isochroon_afstand smallint,
	CONSTRAINT isochronen_pkey PRIMARY KEY (sid)
);

-- DROP TABLE IF EXISTS datasysteem.ov_haltes CASCADE;
CREATE TABLE datasysteem.ov_haltes(
	sid serial NOT NULL,
	geom geometry(Point,28992),
	halte_id varchar,
	halte_zone integer,
	halte_naam varchar,
	halte_gemeente varchar,
	tram boolean,
	metro boolean,
	trein boolean,
	bus boolean,
	veerboot boolean,
	bus_ochtendspits double precision,
	bus_daluren double precision,
	bus_avondspits double precision,
	tram_ochtendspits double precision,
	tram_daluren double precision,
	tram_avondspits double precision,
	metro_ochtendspits double precision,
	metro_daluren double precision,
	metro_avondspits double precision,
	veerboot_ochtendspits double precision,
	veerboot_daluren double precision,
	veerboot_avondspits double precision,
	trein_ochtendspits double precision,
	trein_daluren double precision,
	trein_avondspits double precision,
	hsl_ochtendspits double precision,
	hsl_daluren double precision,
	hsl_avondspits double precision,
	ic_ochtendspits double precision,
	ic_daluren double precision,
	ic_avondspits double precision,
	spr_ochtendspits double precision,
	spr_daluren double precision,
	spr_avondspits double precision,
	CONSTRAINT ov_haltes_pkey PRIMARY KEY (sid)
);