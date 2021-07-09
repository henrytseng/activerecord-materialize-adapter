CREATE TABLE transactions (
  id SERIAL CONSTRAINT transactions_id PRIMARY KEY,
  product_id integer NOT NULL,
  quantity integer NOT NULL,
  price integer NOT NULL,
  buyer character varying(255) NOT NULL,
  created_at date
)
