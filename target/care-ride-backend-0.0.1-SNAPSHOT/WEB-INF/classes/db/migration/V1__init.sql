
create table service_type (
  id serial primary key,
  name varchar(60) not null,
  description varchar(255) not null
);
insert into service_type(name,description) values
('Ambulatory Transport','Curb-to-curb rides'),
('Wheelchair Transport','Accessible van with ramp'),
('Stretcher Transport','Stretcher-ready vehicle');

create table booking (
  id bigserial primary key,
  full_name varchar(120) not null,
  phone varchar(30) not null,
  email varchar(120),
  pickup_address varchar(255) not null,
  dropoff_address varchar(255) not null,
  pickup_time timestamp not null,
  service_type_id int not null references service_type(id),
  notes varchar(500),
  created_at timestamp not null default now(),
  status varchar(20) not null default 'PENDING'
);
