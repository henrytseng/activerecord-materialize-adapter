INSERT INTO factories (name)
  WITH a2z AS (
    SELECT chr(generate_series(65, 122))::text letter
  )
  SELECT ('Facility ' || t1.letter || t2.letter) FROM a2z t1
    CROSS JOIN (SELECT * FROM a2z) t2
ON CONFLICT DO NOTHING
