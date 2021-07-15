SELECT lhs.key, sum(rhs.value)
FROM lhs
JOIN pseudo_source AS rhs
ON lhs.value = rhs.key
GROUP BY lhs.key;