INSERT INTO products (factory_id, name)
  WITH a2z AS (
    SELECT chr(generate_series(65, 122))::text letter
  )
  SELECT
    (random() * 3364 + 1)::int factory_id,
    ('Widget ' || t1.letter || t2.letter)::text
  FROM a2z t1
    CROSS JOIN (SELECT * FROM a2z) t2
ON CONFLICT DO NOTHING
