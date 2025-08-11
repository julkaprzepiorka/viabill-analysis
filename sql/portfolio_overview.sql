-- 1.1 new customers by month
SELECT
  strftime('%Y-%m', registration_date) AS month,
  COUNT(*) AS new_customers
FROM users
GROUP BY 1
ORDER BY 1;

-- 1.2 active customers by month
SELECT
  strftime('%Y-%m', transaction_date) AS month,
  COUNT(DISTINCT user_id) AS active_customers
FROM transactions
GROUP BY 1
ORDER BY 1;

-- 1.3 transactions volume by month
SELECT
  strftime('%Y-%m', transaction_date) AS month,
  COUNT(*) AS tx_count,
  SUM(transaction_amount) AS tx_amount
FROM transactions
GROUP BY 1
ORDER BY 1;

-- 1.4 installments breakdown by month
WITH base AS (
  SELECT
    strftime('%Y-%m', transaction_date) AS month,
    installments_count,
    COUNT(*) AS cnt
  FROM transactions
  GROUP BY 1, 2
),
tot AS (
  SELECT month, SUM(cnt) AS month_total
  FROM base
  GROUP BY 1
)
SELECT
  b.month,
  b.installments_count,
  b.cnt,
  ROUND(100.0 * b.cnt / t.month_total, 2) AS share_pct
FROM base b
JOIN tot t USING (month)
ORDER BY b.month, b.installments_count;

-- 1.5 merchant categories by month
SELECT
  strftime('%Y-%m', t.transaction_date) AS month,
  m.category,
  COUNT(*) AS tx_cnt
FROM transactions t
JOIN merchants m USING (merchant_id)
GROUP BY 1, 2
ORDER BY month, tx_cnt DESC;

-- 1.5a merchant categories top3 by month
WITH cat AS (
  SELECT
    strftime('%Y-%m', t.transaction_date) AS month,
    m.category,
    COUNT(*) AS tx_cnt
  FROM transactions t
  JOIN merchants m USING (merchant_id)
  GROUP BY 1, 2
),
ranked AS (
  SELECT
    month, category, tx_cnt,
    ROW_NUMBER() OVER (PARTITION BY month ORDER BY tx_cnt DESC) AS rn
  FROM cat
)
SELECT month, category, tx_cnt
FROM ranked
WHERE rn <= 3
ORDER BY month, tx_cnt DESC;

-- 1.X portfolio KPIs summary
WITH new_users AS (
  SELECT strftime('%Y-%m', registration_date) AS month,
         COUNT(*) AS new_customers
  FROM users
  GROUP BY 1
),
active_users AS (
  SELECT strftime('%Y-%m', transaction_date) AS month,
         COUNT(DISTINCT user_id) AS active_customers
  FROM transactions
  GROUP BY 1
),
tx_vol AS (
  SELECT strftime('%Y-%m', transaction_date) AS month,
         COUNT(*) AS tx_count,
         SUM(transaction_amount) AS tx_amount
  FROM transactions
  GROUP BY 1
)
SELECT
  COALESCE(n.month, a.month, v.month) AS month,
  COALESCE(n.new_customers, 0)        AS new_customers,
  COALESCE(a.active_customers, 0)     AS active_customers,
  COALESCE(v.tx_count, 0)             AS tx_count,
  COALESCE(v.tx_amount, 0.0)          AS tx_amount
FROM new_users n
FULL OUTER JOIN active_users a ON a.month = n.month
FULL OUTER JOIN tx_vol v       ON v.month = COALESCE(n.month, a.month)
ORDER BY month;