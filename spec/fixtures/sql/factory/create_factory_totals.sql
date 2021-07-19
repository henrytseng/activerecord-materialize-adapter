CREATE MATERIALIZED VIEW factory_totals AS
  SELECT
    f.id as factory_id,
    f.name as factory_name,
    sum(t.quantity * t.price) as total
  FROM transactions t
  JOIN products p ON p.id = t.product_id
  JOIN factories f ON f.id = p.factory_id
  GROUP BY f.id, f.name;
