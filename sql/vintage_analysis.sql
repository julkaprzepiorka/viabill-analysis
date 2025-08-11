-- 3.1 first_tx_cohorts
WITH first_tx AS (
  SELECT
    t.user_id,
    MIN(t.transaction_date) AS first_tx_date
  FROM transactions t
  GROUP BY t.user_id
),
first_tx_rows AS (
  SELECT
    t.user_id,
    t.transaction_id AS first_tx_id,
    t.transaction_date AS first_tx_date,
    strftime('%Y-%m', t.transaction_date) AS cohort_month
  FROM transactions t
  JOIN first_tx f
    ON f.user_id = t.user_id
   AND t.transaction_date = f.first_tx_date
)
SELECT *
FROM first_tx_rows
ORDER BY cohort_month, first_tx_date;


-- 3.2 first tx dpd90 first hit
WITH first_tx_rows AS (
  SELECT
    t.user_id,
    t.transaction_id AS first_tx_id,
    t.transaction_date AS first_tx_date,
    strftime('%Y-%m', t.transaction_date) AS cohort_month
  FROM transactions t
  JOIN (
    SELECT user_id, MIN(transaction_date) AS first_tx_date
    FROM transactions GROUP BY user_id
  ) f
    ON f.user_id = t.user_id
   AND t.transaction_date = f.first_tx_date
),
inst_threshold AS (
  SELECT
    i.transaction_id,
    CASE
      WHEN i.payment_date IS NULL
           AND date('now') >= date(i.scheduled_date, '+90 day')
        THEN date(i.scheduled_date, '+90 day')
      WHEN i.payment_date IS NOT NULL
           AND CAST(julianday(i.payment_date) - julianday(i.scheduled_date) AS INT) >= 90
        THEN date(i.scheduled_date, '+90 day')
      ELSE NULL
    END AS threshold_date
  FROM installments i
),
first_hit AS (
  SELECT
    f.cohort_month,
    f.first_tx_id,
    f.first_tx_date,
    MIN(t.threshold_date) AS dpd90_first_date
  FROM first_tx_rows f
  LEFT JOIN inst_threshold t
    ON t.transaction_id = f.first_tx_id
  GROUP BY f.cohort_month, f.first_tx_id, f.first_tx_date
),
first_hit_with_month AS (
  SELECT
    cohort_month,
    first_tx_id,
    first_tx_date,
    dpd90_first_date,
    CASE
      WHEN dpd90_first_date IS NULL THEN NULL
      ELSE CAST((julianday(dpd90_first_date) - julianday(first_tx_date)) / 30 AS INT)
    END AS month_plus
  FROM first_hit
)
SELECT *
FROM first_hit_with_month
ORDER BY cohort_month, first_tx_id;


-- 3.3 vintage exact month rates
WITH base AS (
  SELECT
    cohort_month,
    first_tx_id,
    month_plus
  FROM (
    SELECT
      cohort_month, first_tx_id, month_plus
    FROM (
      SELECT
        cohort_month, first_tx_id, month_plus
      FROM (
        SELECT
          cohort_month, first_tx_id, month_plus
        FROM (
          SELECT
            cohort_month,
            first_tx_id,
            CASE
              WHEN dpd90_first_date IS NULL THEN NULL
              ELSE CAST((julianday(dpd90_first_date) - julianday(first_tx_date)) / 30 AS INT)
            END AS month_plus
          FROM (
            WITH first_tx_rows AS (
              SELECT
                t.user_id,
                t.transaction_id AS first_tx_id,
                t.transaction_date AS first_tx_date,
                strftime('%Y-%m', t.transaction_date) AS cohort_month
              FROM transactions t
              JOIN (
                SELECT user_id, MIN(transaction_date) AS first_tx_date
                FROM transactions GROUP BY user_id
              ) f
                ON f.user_id = t.user_id
               AND t.transaction_date = f.first_tx_date
            ),
            inst_threshold AS (
              SELECT
                i.transaction_id,
                CASE
                  WHEN i.payment_date IS NULL
                       AND date('now') >= date(i.scheduled_date, '+90 day')
                    THEN date(i.scheduled_date, '+90 day')
                  WHEN i.payment_date IS NOT NULL
                       AND CAST(julianday(i.payment_date) - julianday(i.scheduled_date) AS INT) >= 90
                    THEN date(i.scheduled_date, '+90 day')
                  ELSE NULL
                END AS threshold_date
              FROM installments i
            ),
            first_hit AS (
              SELECT
                f.cohort_month,
                f.first_tx_id,
                f.first_tx_date,
                MIN(t.threshold_date) AS dpd90_first_date
              FROM first_tx_rows f
              LEFT JOIN inst_threshold t
                ON t.transaction_id = f.first_tx_id
              GROUP BY f.cohort_month, f.first_tx_id, f.first_tx_date
            )
            SELECT cohort_month, first_tx_id, first_tx_date, dpd90_first_date
            FROM first_hit
          )
        )
      )
    )
  )
),
cohort_sizes AS (
  SELECT cohort_month, COUNT(*) AS cohort_n
  FROM base
  GROUP BY cohort_month
),
hits AS (
  SELECT cohort_month, month_plus, COUNT(*) AS hit_n
  FROM base
  WHERE month_plus IS NOT NULL
  GROUP BY cohort_month, month_plus
)
SELECT
  h.cohort_month,
  h.month_plus,
  h.hit_n,
  s.cohort_n,
  ROUND(100.0 * h.hit_n / s.cohort_n, 2) AS dpd90_rate_at_month_pct
FROM hits h
JOIN cohort_sizes s USING (cohort_month)
ORDER BY h.cohort_month, h.month_plus;


-- 3.4 vintage curves cumulative
WITH dist AS (
  WITH base AS (
    SELECT
      cohort_month,
      first_tx_id,
      CASE
        WHEN dpd90_first_date IS NULL THEN NULL
        ELSE CAST((julianday(dpd90_first_date) - julianday(first_tx_date)) / 30 AS INT)
      END AS month_plus
    FROM (
      WITH first_tx_rows AS (
        SELECT
          t.user_id,
          t.transaction_id AS first_tx_id,
          t.transaction_date AS first_tx_date,
          strftime('%Y-%m', t.transaction_date) AS cohort_month
        FROM transactions t
        JOIN (
          SELECT user_id, MIN(transaction_date) AS first_tx_date
          FROM transactions GROUP BY user_id
        ) f
          ON f.user_id = t.user_id
         AND t.transaction_date = f.first_tx_date
      ),
      inst_threshold AS (
        SELECT
          i.transaction_id,
          CASE
            WHEN i.payment_date IS NULL
                 AND date('now') >= date(i.scheduled_date, '+90 day')
              THEN date(i.scheduled_date, '+90 day')
            WHEN i.payment_date IS NOT NULL
                 AND CAST(julianday(i.payment_date) - julianday(i.scheduled_date) AS INT) >= 90
              THEN date(i.scheduled_date, '+90 day')
            ELSE NULL
          END AS threshold_date
        FROM installments i
      ),
      first_hit AS (
        SELECT
          f.cohort_month,
          f.first_tx_id,
          f.first_tx_date,
          MIN(t.threshold_date) AS dpd90_first_date
        FROM first_tx_rows f
        LEFT JOIN inst_threshold t
          ON t.transaction_id = f.first_tx_id
        GROUP BY f.cohort_month, f.first_tx_id, f.first_tx_date
      )
      SELECT cohort_month, first_tx_id, first_tx_date, dpd90_first_date
      FROM first_hit
    )
  ),
  cohort_sizes AS (
    SELECT cohort_month, COUNT(*) AS cohort_n
    FROM base
    GROUP BY cohort_month
  ),
  hits AS (
    SELECT cohort_month, month_plus, COUNT(*) AS hit_n
    FROM base
    WHERE month_plus IS NOT NULL
    GROUP BY cohort_month, month_plus
  )
  SELECT
    h.cohort_month,
    h.month_plus,
    h.hit_n,
    s.cohort_n,
    1.0 * h.hit_n / s.cohort_n AS rate_at_month
  FROM hits h
  JOIN cohort_sizes s USING (cohort_month)
),
cum AS (
  SELECT
    cohort_month,
    month_plus,
    ROUND(100.0 * SUM(rate_at_month)
            OVER (PARTITION BY cohort_month
                  ORDER BY month_plus
                  ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW), 2) AS dpd90_cum_pct
  FROM dist
)
SELECT *
FROM cum
ORDER BY cohort_month, month_plus;

