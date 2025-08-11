-- 2.1 installments dpd
WITH inst AS (
  SELECT
    i.installment_id,
    i.transaction_id,
    i.installment_number,
    i.scheduled_date,
    i.payment_date,
    i.scheduled_amount,
    i.paid_amount,
    CASE
      WHEN i.payment_date IS NULL AND date('now') > i.scheduled_date
        THEN CAST(julianday(date('now')) - julianday(i.scheduled_date) AS INT)
      WHEN i.payment_date IS NOT NULL AND i.payment_date > i.scheduled_date
        THEN CAST(julianday(i.payment_date) - julianday(i.scheduled_date) AS INT)
      ELSE 0
    END AS dpd_days
  FROM installments i
)
SELECT *
FROM inst
ORDER BY transaction_id, installment_number;


-- 2.2 transactions dpd90 flags
WITH inst_dpd AS (
  SELECT
    i.transaction_id,
    CASE
      WHEN i.payment_date IS NULL AND date('now') > i.scheduled_date
        THEN CAST(julianday(date('now')) - julianday(i.scheduled_date) AS INT)
      WHEN i.payment_date IS NOT NULL AND i.payment_date > i.scheduled_date
        THEN CAST(julianday(i.payment_date) - julianday(i.scheduled_date) AS INT)
      ELSE 0
    END AS dpd_days
  FROM installments i
)
SELECT
  transaction_id,
  CASE WHEN MAX(CASE WHEN dpd_days >= 90 THEN 1 ELSE 0 END) = 1
       THEN 1 ELSE 0
  END AS dpd90
FROM inst_dpd
GROUP BY transaction_id
ORDER BY transaction_id;


-- 2.3 dpd90 rates (percentage of transactions with dpd90=1) by segment

WITH users_bands AS (
  SELECT
    u.user_id,
    CASE
      WHEN u.age BETWEEN 18 AND 25 THEN '18-25'
      WHEN u.age BETWEEN 26 AND 35 THEN '26-35'
      WHEN u.age BETWEEN 36 AND 50 THEN '36-50'
      ELSE '51+'
    END AS age_band,
    CASE
      WHEN u.income < 15000 THEN '0-15k'
      WHEN u.income < 30000 THEN '15k-30k'
      WHEN u.income < 60000 THEN '30k-60k'
      ELSE '60k+'
    END AS income_band
  FROM users u
),
tx_enriched AS (
  SELECT
    t.transaction_id,
    t.user_id,
    strftime('%Y-%m', t.transaction_date) AS tx_month
  FROM transactions t
),
tx_flag AS (
  SELECT
    i.transaction_id,
    CASE
      WHEN MAX(CASE
        WHEN (i.payment_date IS NULL AND date('now') > i.scheduled_date)
          THEN CAST(julianday(date('now')) - julianday(i.scheduled_date) AS INT)
        WHEN (i.payment_date IS NOT NULL AND i.payment_date > i.scheduled_date)
          THEN CAST(julianday(i.payment_date) - julianday(i.scheduled_date) AS INT)
        ELSE 0
      END) >= 90
      THEN 1 ELSE 0
    END AS dpd90
  FROM installments i
  GROUP BY i.transaction_id
)

-- 2.3a dpd90 by age band
SELECT
  ub.age_band,
  ROUND(AVG(tf.dpd90) * 100, 2) AS dpd90_rate_pct,
  COUNT(*) AS tx_cnt
FROM tx_enriched te
JOIN tx_flag tf        ON tf.transaction_id = te.transaction_id
JOIN users_bands ub    ON ub.user_id = te.user_id
GROUP BY ub.age_band
ORDER BY CASE ub.age_band
  WHEN '18-25' THEN 1
  WHEN '26-35' THEN 2
  WHEN '36-50' THEN 3
  ELSE 4 END;


-- 2.3b dpd90 by income band
WITH users_bands AS (
  SELECT
    u.user_id,
    CASE
      WHEN u.age BETWEEN 18 AND 25 THEN '18-25'
      WHEN u.age BETWEEN 26 AND 35 THEN '26-35'
      WHEN u.age BETWEEN 36 AND 50 THEN '36-50'
      ELSE '51+'
    END AS age_band,
    CASE
      WHEN u.income < 15000 THEN '0-15k'
      WHEN u.income < 30000 THEN '15k-30k'
      WHEN u.income < 60000 THEN '30k-60k'
      ELSE '60k+'
    END AS income_band
  FROM users u
),
tx_enriched AS (
  SELECT
    t.transaction_id,
    t.user_id,
    strftime('%Y-%m', t.transaction_date) AS tx_month
  FROM transactions t
),
tx_flag AS (
  SELECT
    i.transaction_id,
    CASE
      WHEN MAX(CASE
        WHEN (i.payment_date IS NULL AND date('now') > i.scheduled_date)
          THEN CAST(julianday(date('now')) - julianday(i.scheduled_date) AS INT)
        WHEN (i.payment_date IS NOT NULL AND i.payment_date > i.scheduled_date)
          THEN CAST(julianday(i.payment_date) - julianday(i.scheduled_date) AS INT)
        ELSE 0
      END) >= 90
      THEN 1 ELSE 0
    END AS dpd90
  FROM installments i
  GROUP BY i.transaction_id
)
SELECT
  ub.income_band,
  ROUND(AVG(tf.dpd90) * 100, 2) AS dpd90_rate_pct,
  COUNT(*) AS tx_cnt
FROM tx_enriched te
JOIN tx_flag tf     ON tf.transaction_id = te.transaction_id
JOIN users_bands ub ON ub.user_id = te.user_id
GROUP BY ub.income_band
ORDER BY CASE ub.income_band
  WHEN '0-15k' THEN 1
  WHEN '15k-30k' THEN 2
  WHEN '30k-60k' THEN 3
  ELSE 4 END;


-- 2.3c dpd90 by tx month
WITH tx_enriched AS (
  SELECT
    t.transaction_id,
    strftime('%Y-%m', t.transaction_date) AS tx_month
  FROM transactions t
),
tx_flag AS (
  SELECT
    i.transaction_id,
    CASE
      WHEN MAX(CASE
        WHEN (i.payment_date IS NULL AND date('now') > i.scheduled_date)
          THEN CAST(julianday(date('now')) - julianday(i.scheduled_date) AS INT)
        WHEN (i.payment_date IS NOT NULL AND i.payment_date > i.scheduled_date)
          THEN CAST(julianday(i.payment_date) - julianday(i.scheduled_date) AS INT)
        ELSE 0
      END) >= 90
      THEN 1 ELSE 0
    END AS dpd90
  FROM installments i
  GROUP BY i.transaction_id
)
SELECT
  te.tx_month,
  ROUND(AVG(tf.dpd90) * 100, 2) AS dpd90_rate_pct,
  COUNT(*) AS tx_cnt
FROM tx_enriched te
JOIN tx_flag tf ON tf.transaction_id = te.transaction_id
GROUP BY te.tx_month
ORDER BY te.tx_month;

