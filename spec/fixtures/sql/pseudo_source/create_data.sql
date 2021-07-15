CREATE MATERIALIZED VIEW pseudo_source (key, value) AS
  VALUES ('a', 1), ('a', 2), ('a', 3), ('a', 4),
  ('b', 5), ('c', 6), ('c', 7)
