CREATE SCHEMA hyper;

CREATE SEQUENCE hyper.xp_id_gen MINVALUE 0 MAXVALUE 2000000000;

CREATE TABLE hyper.experiment (   
   hex_id       INT8 DEFAULT next_val(hyper.xp_id_gen),
   bat_id       INT8,
   ver_id		INT8,
   hex_time 	TIMESTAMP DEFAULT now(),
   PRIMARY KEY (xp_id)
);

CREATE TABLE hyper.battery (
	bat_id 		INT8 DEFAULT next_val,
	bat_name   	VARCHAR(255),
	PRIMARY KEY (xp_id),
	UNIQUE (bat_name)
);

CREATE TABLE hyper.version (
	ver_id 		INT8 DEFAULT next_val,
	bat_id		INT8,
	ver_num		INT8,
	ver_desc 	VARCHAR(255),
	PRIMARY KEY (ver_id),
	UNIQUE (bat_id, ver_num, ver_desc)
);

CREATE TABLE hyper.param (
	hex_id		INT8,
	param_name	VARCHAR(255),
	param_val	TEXT, --serialized json (slow but easy and cross-platform)
	PRIMARY KEY (hex_id, param_name)
);

CREATE TABLE hyper.metadata (
	hex_id		INT8,
	meta_name	VARCHAR(255),
	meta_val 	VARCHAR(255), --json
	PRIMARY KEY (hex_id, meta_name)
);

CREATE TABLE hyper.maxima (
	hex_id		INT8,
	train_val   FLOAT8,
	valid_val   FLOAT8,
	test_val	FLOAT8,
	PRIMARY KEY (hex_id)
);

CREATE TABLE hyper.learncurve (
	hex_id		INT8,
	hex_epoch	INT8,
	train_val   FLOAT8,
	valid_val   FLOAT8,
	test_val	FLOAT8,
	PRIMARY KEY (hex_id, hex_epoch)
);



	

