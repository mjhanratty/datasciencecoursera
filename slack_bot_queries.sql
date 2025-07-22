-- =============================================================================
-- INTERNAL REPORTING QUERY (All Clients + bROAS)
-- =============================================================================

-- Query for Internal Reports: All clients performance with bROAS (L3D)
-- Usage: Replace {client_filter} with specific client or remove WHERE clause for all clients

WITH weekly_targets AS (
  SELECT
    DATE_TRUNC(PARSE_DATE('%m/%d/%Y', day), WEEK(SUNDAY)) AS week
    , COALESCE(client, 'all_clients') AS client
    , SUM(CAST(spend AS FLOAT64)) AS target_spend
    , SUM(CAST(new_orders AS FLOAT64)) AS target_new_orders
    , SUM(CAST(new_revenue AS FLOAT64)) AS target_new_revenue
    , CASE 
      WHEN SUM(CAST(new_orders AS FLOAT64)) = 0 THEN NULL 
      ELSE ROUND(SUM(CAST(spend AS FLOAT64)) / SUM(CAST(new_orders AS FLOAT64)), 2) 
    END AS target_cac
    , SUM(CAST(total_orders AS FLOAT64)) AS target_total_orders
    , SUM(CAST(total_revenue AS FLOAT64)) AS target_total_revenue
    , SUM(CAST(broas_l3d AS FLOAT64)) AS target_broas_l3d
  FROM `orcaanalytics.google_sheets__paka.projections`
  WHERE DATE_TRUNC(PARSE_DATE('%m/%d/%Y', day), WEEK(SUNDAY))
        = DATE_SUB(DATE_TRUNC(CURRENT_DATE('America/New_York'), WEEK(SUNDAY)), INTERVAL 1 WEEK)
    -- Optional client filter: AND COALESCE(client, 'all_clients') = '{client_filter}'
  GROUP BY week, client
)
, weekly_actuals AS (
  SELECT
    DATE_TRUNC(date, WEEK(SUNDAY)) AS week
    , COALESCE(client, 'all_clients') AS client
    , SUM(total_spend) AS total_spend
    , CAST(SUM(new_orders) AS FLOAT64) AS new_orders
    , CAST(SUM(new_revenue) AS FLOAT64) AS new_revenue
    , CASE 
      WHEN SUM(new_orders) = 0 THEN NULL 
      ELSE ROUND(SUM(total_spend) / SUM(new_orders), 2) 
    END AS cac
    , CAST(SUM(total_orders) AS FLOAT64) AS total_orders
    , CAST(SUM(total_revenue) AS FLOAT64) AS total_revenue
    , CAST(AVG(broas_l3d) AS FLOAT64) AS broas_l3d
  FROM `orcaanalytics.analytics.pacing__paka`
  WHERE DATE_TRUNC(date, WEEK(SUNDAY))
        = DATE_SUB(DATE_TRUNC(CURRENT_DATE('America/New_York'), WEEK(SUNDAY)), INTERVAL 1 WEEK)
    -- Optional client filter: AND COALESCE(client, 'all_clients') = '{client_filter}'
  GROUP BY week, client
)
, weekly_metrics AS (
SELECT 
  wa.week
  , wa.client
  , wa.*
  , wt.target_spend
  , wt.target_new_orders
  , wt.target_new_revenue
  , wt.target_cac
  , wt.target_total_orders
  , wt.target_total_revenue
  , wt.target_broas_l3d
  , ROUND(wa.total_spend / NULLIF(wt.target_spend, 0) - 1, 2) AS delta_spend
  , ROUND(wa.new_orders / NULLIF(wt.target_new_orders, 0) - 1, 2) AS delta_new_orders
  , ROUND(wa.new_revenue / NULLIF(wt.target_new_revenue, 0) - 1, 2) AS delta_new_revenue
  , ROUND(wa.cac / NULLIF(wt.target_cac, 0) - 1, 2) AS delta_cac 
  , ROUND(wa.total_orders / NULLIF(wt.target_total_orders, 0) - 1, 2) AS delta_total_orders
  , ROUND(wa.total_revenue / NULLIF(wt.target_total_revenue, 0) - 1, 2) AS delta_total_revenue
  , ROUND(wa.broas_l3d / NULLIF(wt.target_broas_l3d, 0) - 1, 2) AS delta_broas_l3d
FROM weekly_actuals wa 
LEFT JOIN weekly_targets wt ON wt.week = wa.week AND wt.client = wa.client
)
SELECT
  week AS `Week`
  , client AS `Client`
  , metric AS `Metric`
  , actual_value AS `Actuals`
  , target_value AS `Targets`
  , delta_value AS `% from Target`
FROM weekly_metrics
UNPIVOT(
  (actual_value, target_value, delta_value) 
  FOR metric IN (
    (total_spend, target_spend, delta_spend) AS 'Total Spend',
    (new_orders, target_new_orders, delta_new_orders) AS 'New Orders',
    (new_revenue, target_new_revenue, delta_new_revenue) AS 'New Revenue',
    (cac, target_cac, delta_cac) AS 'CAC',
    (total_orders, target_total_orders, delta_total_orders) AS 'Total Orders',
    (total_revenue, target_total_revenue, delta_total_revenue) AS 'Total Revenue',
    (broas_l3d, target_broas_l3d, delta_broas_l3d) AS 'bROAS (L3D)'
  )
)
ORDER BY client, week DESC, metric;

-- =============================================================================
-- EXTERNAL REPORTING QUERY (Monday Updates: Weekly Actuals vs Targets + DoD)
-- =============================================================================

-- Part 1: Weekly Business Actuals vs Targets
WITH weekly_targets AS (
  SELECT
    DATE_TRUNC(PARSE_DATE('%m/%d/%Y', day), WEEK(SUNDAY)) AS week
    , SUM(CAST(spend AS FLOAT64)) AS target_spend
    , SUM(CAST(new_revenue AS FLOAT64)) AS target_new_revenue
    , CASE 
      WHEN SUM(CAST(new_orders AS FLOAT64)) = 0 THEN NULL 
      ELSE ROUND(SUM(CAST(spend AS FLOAT64)) / SUM(CAST(new_orders AS FLOAT64)), 2) 
    END AS target_cac
    , SUM(CAST(total_revenue AS FLOAT64)) AS target_total_revenue
  FROM `orcaanalytics.google_sheets__paka.projections`
  WHERE DATE_TRUNC(PARSE_DATE('%m/%d/%Y', day), WEEK(SUNDAY))
        = DATE_SUB(DATE_TRUNC(CURRENT_DATE('America/New_York'), WEEK(SUNDAY)), INTERVAL 1 WEEK)
    -- Client filter: WHERE COALESCE(client, 'all_clients') = '{client_name}'
  GROUP BY week
)
, weekly_actuals AS (
  SELECT
    DATE_TRUNC(date, WEEK(SUNDAY)) AS week
    , SUM(total_spend) AS total_spend
    , CAST(SUM(new_revenue) AS FLOAT64) AS new_revenue
    , CASE 
      WHEN SUM(new_orders) = 0 THEN NULL 
      ELSE ROUND(SUM(total_spend) / SUM(new_orders), 2) 
    END AS cac
    , CAST(SUM(total_revenue) AS FLOAT64) AS total_revenue
  FROM `orcaanalytics.analytics.pacing__paka`
  WHERE DATE_TRUNC(date, WEEK(SUNDAY))
        = DATE_SUB(DATE_TRUNC(CURRENT_DATE('America/New_York'), WEEK(SUNDAY)), INTERVAL 1 WEEK)
    -- Client filter: AND COALESCE(client, 'all_clients') = '{client_name}'
  GROUP BY week
)
, weekly_metrics AS (
SELECT 
  wa.*
  , wt.target_spend
  , wt.target_new_revenue
  , wt.target_cac
  , wt.target_total_revenue
  , ROUND(wa.total_spend / NULLIF(wt.target_spend, 0) - 1, 2) AS delta_spend
  , ROUND(wa.new_revenue / NULLIF(wt.target_new_revenue, 0) - 1, 2) AS delta_new_revenue
  , ROUND(wa.cac / NULLIF(wt.target_cac, 0) - 1, 2) AS delta_cac 
  , ROUND(wa.total_revenue / NULLIF(wt.target_total_revenue, 0) - 1, 2) AS delta_total_revenue
FROM weekly_actuals wa 
LEFT JOIN weekly_targets wt ON wt.week = wa.week 
)
, weekly_report AS (
SELECT
  week AS `Week`
  , metric AS `Metric`
  , actual_value AS `Actuals`
  , target_value AS `Targets`
  , delta_value AS `% from Target`
  , 'Weekly vs Target' AS report_type
FROM weekly_metrics
UNPIVOT(
  (actual_value, target_value, delta_value) 
  FOR metric IN (
    (total_spend, target_spend, delta_spend) AS 'Total Spend',
    (new_revenue, target_new_revenue, delta_new_revenue) AS 'New Revenue',
    (cac, target_cac, delta_cac) AS 'CAC',
    (total_revenue, target_total_revenue, delta_total_revenue) AS 'Total Revenue'
  )
)
)
-- Part 2: Day-over-Day Business Metrics
, daily_actuals AS (
  SELECT
    date
    , SUM(total_spend) AS daily_spend
    , CAST(SUM(new_revenue) AS FLOAT64) AS daily_new_revenue
    , CAST(SUM(total_revenue) AS FLOAT64) AS daily_total_revenue
    , CASE 
      WHEN SUM(new_orders) = 0 THEN NULL 
      ELSE ROUND(SUM(total_spend) / SUM(new_orders), 2) 
    END AS daily_cac
  FROM `orcaanalytics.analytics.pacing__paka`
  WHERE date >= DATE_SUB(CURRENT_DATE('America/New_York'), INTERVAL 2 DAYS)
    -- Client filter: AND COALESCE(client, 'all_clients') = '{client_name}'
  GROUP BY date
  ORDER BY date DESC
  LIMIT 2
)
, dod_comparison AS (
  SELECT 
    date
    , daily_spend
    , daily_new_revenue
    , daily_total_revenue
    , daily_cac
    , LAG(daily_spend) OVER (ORDER BY date) AS prev_daily_spend
    , LAG(daily_new_revenue) OVER (ORDER BY date) AS prev_daily_new_revenue
    , LAG(daily_total_revenue) OVER (ORDER BY date) AS prev_daily_total_revenue
    , LAG(daily_cac) OVER (ORDER BY date) AS prev_daily_cac
  FROM daily_actuals
)
, dod_metrics AS (
  SELECT
    ROUND((daily_spend / NULLIF(prev_daily_spend, 0) - 1), 2) AS dod_spend_change
    , ROUND((daily_new_revenue / NULLIF(prev_daily_new_revenue, 0) - 1), 2) AS dod_new_revenue_change
    , ROUND((daily_total_revenue / NULLIF(prev_daily_total_revenue, 0) - 1), 2) AS dod_total_revenue_change
    , ROUND((daily_cac / NULLIF(prev_daily_cac, 0) - 1), 2) AS dod_cac_change
    , daily_spend
    , daily_new_revenue  
    , daily_total_revenue
    , daily_cac
    , prev_daily_spend
    , prev_daily_new_revenue
    , prev_daily_total_revenue
    , prev_daily_cac
  FROM dod_comparison
  WHERE prev_daily_spend IS NOT NULL
)
, dod_report AS (
SELECT
  CAST(NULL AS DATE) AS `Week`
  , metric AS `Metric`
  , current_value AS `Actuals`
  , previous_value AS `Targets`
  , dod_change AS `% from Target`
  , 'Day-over-Day' AS report_type
FROM dod_metrics
UNPIVOT(
  (current_value, previous_value, dod_change)
  FOR metric IN (
    (daily_spend, prev_daily_spend, dod_spend_change) AS 'Daily Spend (DoD)',
    (daily_new_revenue, prev_daily_new_revenue, dod_new_revenue_change) AS 'Daily New Revenue (DoD)',
    (daily_total_revenue, prev_daily_total_revenue, dod_total_revenue_change) AS 'Daily Total Revenue (DoD)',
    (daily_cac, prev_daily_cac, dod_cac_change) AS 'Daily CAC (DoD)'
  )
)
)

-- Combined External Report Output
SELECT * FROM weekly_report
UNION ALL
SELECT * FROM dod_report
ORDER BY 
  report_type,
  Week DESC,
  Metric;