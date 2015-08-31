--DROP SCHEMA hyper CASCADE;
CREATE SCHEMA IF NOT EXISTS hyper;

CREATE TABLE IF NOT EXISTS hyper.battery (
	bat_id 		BIGSERIAL,
	bat_name   	VARCHAR(255),
	bat_time 	TIMESTAMP DEFAULT now(),
	PRIMARY KEY (bat_id),
	UNIQUE (bat_name)
);

-- DROP TABLE hyper.version;
CREATE TABLE IF NOT EXISTS hyper.version (
	ver_id 		BIGSERIAL,
	bat_id		INT8,
	ver_desc 	VARCHAR(255),
	ver_time	TIMESTAMP DEFAULT now(),
	PRIMARY KEY (ver_id),
	FOREIGN KEY (bat_id) REFERENCES hyper.battery (bat_id),
	UNIQUE (bat_id, ver_desc)
);

CREATE TABLE IF NOT EXISTS hyper.experiment (   
	hex_id      	BIGSERIAL,
	bat_id      	INT8,
	ver_id		INT8,
	hex_time 	TIMESTAMP DEFAULT now(),
	FOREIGN KEY (bat_id) REFERENCES hyper.battery(bat_id),
	FOREIGN KEY (ver_id) REFERENCES hyper.version(ver_id),
	PRIMARY KEY (hex_id)
);

CREATE TABLE IF NOT EXISTS hyper.param (
	hex_id		INT8,
	hex_param	JSON,
	PRIMARY KEY (hex_id),
	FOREIGN KEY (hex_id) REFERENCES hyper.experiment (hex_id)
);

CREATE TABLE IF NOT EXISTS hyper.meta (
	hex_id		INT8,
	hex_meta	VARCHAR(255),
	PRIMARY KEY (hex_id),
	FOREIGN KEY (hex_id) REFERENCES hyper.experiment (hex_id)
);

CREATE TABLE IF NOT EXISTS hyper.result (
	hex_id		INT8,
	hex_result	JSON,
	PRIMARY KEY (hex_id),
	FOREIGN KEY (hex_id) REFERENCES hyper.experiment (hex_id)
);

