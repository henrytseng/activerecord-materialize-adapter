CREATE TABLE products (
    id SERIAL,
    factory_id integer NOT NULL,
    name character varying(255) NOT NULL,
    created_at date
)
