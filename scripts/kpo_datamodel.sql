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
	code character varying,
	plaatsnaam character varying,
	scenario_naam character varying,
	op_loopafstand boolean,
	op_fietsafstand boolean,
	dichtstbijzijnde_station character varying,
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
	scenario_naam character varying,
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
	station_naam character varying,
	halte_id character varying,
	halte_naam character varying,
	scenario_naam character varying,
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
	fietsroutes character varying,
	ov_routes character varying,
	CONSTRAINT knooppunten_pkey PRIMARY KEY (sid)
);

-- DROP TABLE IF EXISTS datasysteem.ruimtelijke_kenmerken CASCADE;
CREATE TABLE datasysteem.ruimtelijke_kenmerken(
	sid serial NOT NULL,
	geom geometry(MultiPolygon,28992),
	cell_id character varying,
	huishoudens integer,
	inwoners integer,
	intensiteit integer,
	fysieke_dichtheid double precision,
	woz_waarde double precision,
	ov_bereikbaarheidsniveau character varying,
	ov_bereikbaarheidsindex double precision,
	CONSTRAINT ruimtelijke_kenmerken_pkey PRIMARY KEY (sid)
);

-- DROP TABLE IF EXISTS datasysteem.ontwikkellocaties CASCADE;
CREATE TABLE datasysteem.ontwikkellocaties(
	sid serial NOT NULL,
	geom geometry(MultiPolygon,28992),
	plan_naam character varying,
	plan_id character varying,
	gemeente character varying,
	plaatsnaam character varying,
	adres character varying,
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
	plan_naam character varying,
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
	station_namen character varying,
	station_aantal smallint,
	ov_routes_ids character varying,
	CONSTRAINT invloedsgebied_overlap_pkey PRIMARY KEY (sid)
);

-- DROP TABLE IF EXISTS datasysteem.belangrijke_locaties CASCADE;
CREATE TABLE datasysteem.belangrijke_locaties(
	sid serial NOT NULL,
	geom geometry(MultiPolygon,28992),
	locatie_id character varying,
	locatie_naam character varying,
	op_loopafstand boolean,
	ov_routes_ids character varying,
	CONSTRAINT belangrijke_locaties_pkey PRIMARY KEY (sid)
);

-- DROP TABLE IF EXISTS datasysteem.regionale_voorzieningen CASCADE;
CREATE TABLE datasysteem.regionale_voorzieningen(
	sid serial NOT NULL,
	geom geometry(MultiPoint,28992),
	locatie_id character varying,
	type_locatie character varying,
	locatie_naam character varying,
	op_loopafstand boolean,
	ov_routes_ids character varying,
	CONSTRAINT regionale_voorzieningen_pkey PRIMARY KEY (sid)
);

-- DROP TABLE IF EXISTS datasysteem.fietsroutes CASCADE;
CREATE TABLE datasysteem.fietsroutes(
	sid serial NOT NULL,
	geom geometry(Linestring,28992),
	route_id character varying,
	link_id character varying,
	route_intensiteit smallint,
	invloedsgebied_ids character varying,
	CONSTRAINT fietsroutes_pkey PRIMARY KEY (sid)
);

-- DROP TABLE IF EXISTS datasysteem.ov_routes CASCADE;
CREATE TABLE datasysteem.ov_routes(
	sid serial NOT NULL,
	geom geometry(Linestring,28992),
	route_id character varying,
	route_naam character varying,
	modaliteit character varying,
	ochtendspits double precision,
	daluren double precision,
	avondspits double precision,
	CONSTRAINT ov_routes_pkey PRIMARY KEY (sid)
);

-- DROP TABLE IF EXISTS datasysteem.isochronen CASCADE;
CREATE TABLE datasysteem.isochronen(
	sid serial NOT NULL,
	geom geometry(MultiPolygon,28992),
	halte_id character varying,
	halte_naam character varying,
	halte_modaliteit character varying,
	modaliteit character varying,
	isochroon_afstand smallint,
	CONSTRAINT isochronen_pkey PRIMARY KEY (sid)
);

-- DROP TABLE IF EXISTS datasysteem.ov_haltes CASCADE;
CREATE TABLE datasysteem.ov_haltes(
	sid serial NOT NULL,
	geom geometry(Point,28992),
	halte_id character varying,
	halte_zone integer,
	halte_naam character varying,
	halte_gemeente character varying,
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