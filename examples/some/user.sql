create table table_user (
	user_id   integer not null,
	name      varchar(200),
	login     varchar(50) not null unique,
	counter   integer default 0 not null,
	passkey   varchar(50),
  loginDate timestamp,
	registerDate timestamp,
	anonymous integer not null,

	primary key (user_id)
);

create generator table_user_seq;
