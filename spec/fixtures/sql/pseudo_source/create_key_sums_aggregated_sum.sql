CREATE MATERIALIZED VIEW key_sums AS
    SELECT key, sum(value) FROM pseudo_source GROUP BY key;
