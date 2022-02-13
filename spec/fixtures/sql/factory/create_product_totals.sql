CREATE MATERIALIZED VIEW product_totals AS
  SELECT
    t.product_id as id,
    t.product_id,
    p.name as product_name,
    sum(t.quantity * t.price) as total
  FROM transactions t
  JOIN products p ON p.id = t.product_id
  GROUP BY p.id, t.product_id, p.name;
