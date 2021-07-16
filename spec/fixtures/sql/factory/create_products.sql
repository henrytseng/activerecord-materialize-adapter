CREATE TABLE products (
  id SERIAL CONSTRAINT products_id PRIMARY KEY,
  factory_id integer NOT NULL,
  name character varying(255) NOT NULL,
  created_at date
)
