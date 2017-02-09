-- KPO data system data model
-- author: Jorge Gil, 2017


-- object: datasysteem | type: SCHEMA --
-- DROP SCHEMA IF EXISTS datasysteem CASCADE;
CREATE SCHEMA datasysteem;
ALTER SCHEMA datasysteem OWNER TO postgres;

-- DROP TABLE IF EXISTS datasysteem.housing_scenarios CASCADE;
CREATE TABLE datasysteem.housing_scenarios(
	sid serial NOT NULL,
	geom geometry(MultiPolygon,28992),
	postcode varchar,
	place_name varchar,
	scenario_name varchar,
	within_walking_dist boolean,
	within_cycling_dist boolean,
	nearest_station varchar,
	households integer,
	area double precision,
	density double precision,
	new_households integer,
	percent_change double precision,
	CONSTRAINT housing_scenarios_pk PRIMARY KEY (sid)
);

-- DROP TABLE IF EXISTS datasysteem.housing_summary CASCADE;
CREATE TABLE datasysteem.housing_summary(
	sid serial NOT NULL,
	scenario_name varchar,
	policy_level smallint,
	new_households integer,
	within_walking_dist integer,
	within_cycling_dist integer,
	outside_influence integer,
	CONSTRAINT housing_summary_pkey PRIMARY KEY (sid)
);

-- DROP TABLE IF EXISTS datasysteem.transit_nodes CASCADE;
CREATE TABLE datasysteem.transit_nodes(
	sid serial NOT NULL,
	geom geometry(MultiPoint,28992),
	station_name varchar,
	scenario_name varchar,
	policy_level smallint,
	users integer,
	users_diff integer,
	users_pc_change double precision,
	bicycle_parking integer,
	bicycle_occupation integer,
	bicycle_occupation_diff double precision,
	bicycle_pc_change double precision,
	platform integer,
	platform_diff double precision,
	platform_pc_change double precision,
	stairs integer,
	stairs_diff double precision,
	stairs_pc_change double precision,
	user_flows integer,
	user_flows_diff double precision,
	user_flows_pc_change double precision,
	cycle_routes varchar,
	public_transport_routes varchar,
	CONSTRAINT transit_nodes_pkey PRIMARY KEY (sid)
);

-- DROP TABLE IF EXISTS datasysteem.spatial_characteristics CASCADE;
CREATE TABLE datasysteem.spatial_characteristics(
	sid serial NOT NULL,
	geom geometry(MultiPolygon,28992),
	cell_id varchar,
	households integer,
	residents integer,
	intensity integer,
	built_density double precision,
	property_value double precision,
	pta_level varchar,
	pta_index double precision,
	CONSTRAINT spatial_characteristics_pkey PRIMARY KEY (sid)
);

-- DROP TABLE IF EXISTS datasysteem.development_plans CASCADE;
CREATE TABLE datasysteem.development_plans(
	sid serial NOT NULL,
	geom geometry(MultiPolygon,28992),
	plan_name varchar,
	site_id varchar,
	municipality varchar,
	site_name varchar,
	address varchar,
	built_dwellings integer,
	planned_dwellings integer,
	net_dwellings integer,
	area double precision,
	density double precision,
	mean_ptal double precision,
	max_ptal double precision,
	CONSTRAINT development_locations_pkey PRIMARY KEY (sid)
);

-- DROP TABLE IF EXISTS datasysteem.development_plans_summary CASCADE;
CREATE TABLE datasysteem.development_plans_summary(
	sid serial NOT NULL,
	plan_name varchar,
	new_dwellings integer,
	in_development_potential integer,
	outside_development_potential integer,
	CONSTRAINT development_locations_summary_pkey PRIMARY KEY (sid)
);

-- DROP TABLE IF EXISTS datasysteem.station_influence_overlap CASCADE;
CREATE TABLE datasysteem.station_influence_overlap(
	sid serial NOT NULL,
	geom geometry(MultiPolygon,28992),
	residents integer,
	intensity integer,
	station_names varchar,
	station_number smallint,
	cycle_routes varchar,
	ov_routes varchar,
	CONSTRAINT station_influence_overlap_pkey PRIMARY KEY (sid)
);

-- DROP TABLE IF EXISTS datasysteem.important_locations CASCADE;
CREATE TABLE datasysteem.important_locations(
	sid serial NOT NULL,
	geom geometry(MultiPolygon,28992),
	location_type varchar,
	location_id varchar,
	location_name varchar,
	cycle_routes varchar,
	ov_routes varchar,
	CONSTRAINT important_locations_pkey PRIMARY KEY (sid)
);

-- DROP TABLE IF EXISTS datasysteem.cycle_routes CASCADE;
CREATE TABLE datasysteem.cycle_routes(
	sid serial NOT NULL,
	geom geometry(Linestring,28992),
	route_id varchar,
	route_name varchar,
	route_intensity smallint,
	CONSTRAINT cycle_routes_pkey PRIMARY KEY (sid)
);

-- DROP TABLE IF EXISTS datasysteem.ov_routes CASCADE;
CREATE TABLE datasysteem.ov_routes(
	sid serial NOT NULL,
	geom geometry(Linestring,28992),
	route_id varchar,
	route_name varchar,
	route_mode varchar,
	trein_type varchar,
	route_frequency double precision,
	CONSTRAINT ov_routes_pkey PRIMARY KEY (sid)
);

-- DROP TABLE IF EXISTS datasysteem.isochrones CASCADE;
CREATE TABLE datasysteem.isochrones(
	sid serial NOT NULL,
	geom geometry(MultiPolygon,28992),
	stop_id varchar,
	stop_name varchar,
	travel_mode varchar,
	distance smallint,
	CONSTRAINT isochrones_pkey PRIMARY KEY (sid)
);

-- DROP TABLE IF EXISTS datasysteem.ov_stops CASCADE;
CREATE TABLE datasysteem.ov_stops(
	sid serial NOT NULL,
	geom geometry(Point,28992),
	stop_id varchar,
	stop_area integer,
	stop_name varchar,
	stop_municipality varchar,
	tram boolean,
	metro boolean,
	trein boolean,
	bus boolean,
	veerboot boolean,
	bus_ochtendspits double precision,
	bus_middagdal double precision,
	bus_avondspits double precision,
	tram_ochtendspits double precision,
	tram_middagdal double precision,
	tram_avondspits double precision,
	metro_ochtendspits double precision,
	metro_middagdal double precision,
	metro_avondspits double precision,
	veerboot_ochtendspits double precision,
	veerboot_middagdal double precision,
	veerboot_avondspits double precision,
	trein_ochtendspits double precision,
	trein_middagdal double precision,
	trein_avondspits double precision,
	hsl_ochtendspits double precision,
	hsl_middagdal double precision,
	hsl_avondspits double precision,
	ic_ochtendspits double precision,
	ic_middagdal double precision,
	ic_avondspits double precision,
	spr_ochtendspits double precision,
	spr_middagdal double precision,
	spr_avondspits double precision,
	CONSTRAINT ov_stops_pkey PRIMARY KEY (sid)
);

-- DROP TABLE IF EXISTS datasysteem.ov_links CASCADE;
CREATE TABLE datasysteem.ov_links(
	sid serial NOT NULL,
	geom geometry(LineString,28992),
	origin_stop_id varchar,
	destination_stop_id varchar,
	link_mode varchar,
	trein_type varchar,
	ochtendspits double precision,
	middagdal double precision,
	avondspits double precision,
	CONSTRAINT ov_links_pkey PRIMARY KEY (sid)
);