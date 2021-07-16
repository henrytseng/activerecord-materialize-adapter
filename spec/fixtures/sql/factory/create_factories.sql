CREATE TABLE factories (
  id SERIAL CONSTRAINT factories_id PRIMARY KEY,
  name character varying(255) NOT NULL,
  created_at date
)
