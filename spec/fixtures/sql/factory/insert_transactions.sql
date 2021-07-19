INSERT INTO transactions (product_id, quantity, price, buyer)
  WITH a2z AS (
    SELECT chr(generate_series(65, 122))::text letter
  )
  SELECT
    (random() * 3364 + 1)::int product_id,
    (random() * 10 + 1)::int quantity,
    (random() * 100 + 10)::int price,
    (t1.letter || t2.letter || t3.letter || ' Co')::text buyer
  FROM a2z t1
    CROSS JOIN (SELECT * FROM a2z) t2
    CROSS JOIN (SELECT * FROM a2z) t3
ON CONFLICT DO NOTHING
