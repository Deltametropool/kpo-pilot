-- KPO data system
-- author: Jorge Gil, 2017

-- adapted to data and attributes available in GTFS by 9292.nl

-- STEP 1: create GTFS schema
DROP SCHEMA IF EXISTS gtfs CASCADE;
CREATE SCHEMA gtfs;

CREATE TABLE gtfs.agency
(
	agency_id varchar,
	agency_name varchar,
	agency_url varchar,
	agency_timezone varchar,
	agency_lang varchar(2),
	agency_phone varchar
);

CREATE TABLE gtfs.stops
(
	stop_id varchar,
	stop_code varchar,
	stop_name varchar,
	stop_desc varchar,
	platform_code varchar,
	stop_lat numeric,
	stop_lon numeric,
	zone_id varchar,
	stop_url varchar,
	location_type integer,
	parent_station varchar
);

CREATE TABLE gtfs.routes
(
	route_id varchar,
	agency_id varchar,
	route_short_name varchar,
	route_long_name varchar,
	route_desc varchar,
	route_type integer,
	route_url varchar,
	route_color varchar(8),
	route_text_color varchar(8)
);

CREATE TABLE gtfs.trips
(
	route_id varchar,
	service_id varchar,
	trip_id varchar,
	trip_headsign varchar,
	direction_id integer,
	block_id varchar,
	shape_id varchar
);

CREATE TABLE gtfs.stop_times
(
	trip_id varchar,
	arrival_time varchar,
	departure_time varchar,
	stop_id varchar,
	stop_sequence integer,
	stop_headsign varchar,
	pickup_type integer,
	drop_off_type integer,
	shape_dist_traveled varchar
);

CREATE TABLE gtfs.calendar
(
	service_id varchar,
	monday boolean,
	tuesday boolean,
	wednesday boolean,
	thursday boolean,
	friday boolean,
	saturday boolean,
	sunday boolean,
	start_date date,
	end_date date
);

CREATE TABLE gtfs.calendar_dates
(
	service_id varchar,
	exception_date date,
	exception_type integer
);

CREATE TABLE gtfs.shapes
(
	shape_id varchar,
	shape_pt_lat numeric,
	shape_pt_lon numeric,
	shape_pt_sequence integer
);

CREATE TABLE gtfs.transfers
(
	from_stop_id varchar,
	to_stop_id varchar,
	transfer_type integer,
	min_transfer_time integer
);

CREATE TABLE gtfs.feed_info
(
	feed_publisher_name varchar,
	feed_publisher_url varchar,
	feed_lang varchar,
	feed_start_date date,
	feed_end_date date,
	feed_version varchar
);

-- STEP 2: load GTFS files
COPY gtfs.agency FROM '/Users/Shared/gtfs/agency.txt' CSV DELIMITER ',' HEADER;
COPY gtfs.stops FROM '/Users/Shared/gtfs/stops.txt' CSV DELIMITER ',' HEADER;
COPY gtfs.routes FROM '/Users/Shared/gtfs/routes.txt' CSV DELIMITER ',' HEADER;
COPY gtfs.trips FROM '/Users/Shared/gtfs/trips.txt' CSV DELIMITER ',' HEADER;
COPY gtfs.stop_times FROM '/Users/Shared/gtfs/stop_times.txt' CSV DELIMITER ',' HEADER;
COPY gtfs.calendar_dates FROM '/Users/Shared/gtfs/calendar_dates.txt' CSV DELIMITER ',' HEADER;
COPY gtfs.transfers FROM '/Users/Shared/gtfs/transfers.txt' CSV DELIMITER ',' HEADER;
COPY gtfs.feed_info FROM '/Users/Shared/gtfs/feed_info.txt' CSV DELIMITER ',' HEADER;
COPY gtfs.shapes FROM '/Users/Shared/gtfs/shapes.txt' CSV DELIMITER ',' HEADER;
