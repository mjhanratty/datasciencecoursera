-- Enhanced Multi-Client Metrics Query for Slack Bot
-- Supports Internal (all clients + bROAS) and External (weekly + DoD) reporting

-- Configuration variables (these would be set by your Slack bot based on client/mode)
DECLARE report_mode STRING DEFAULT 'external'; -- 'internal' or 'external'
DECLARE client_filter STRING DEFAULT NULL; -- NULL for all clients, or specific client name
DECLARE include_broas BOOL DEFAULT TRUE; -- Toggle bROAS metric
DECLARE include_new_orders BOOL DEFAULT FALSE; -- Toggle new orders metric
DECLARE include_total_orders BOOL DEFAULT FALSE; -- Toggle total orders metric
DECLARE include_dod_metrics BOOL DEFAULT TRUE; -- Toggle day-over-day metrics

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
    AND (client_filter IS NULL OR COALESCE(client, 'all_clients') = client_filter)
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
    AND (client_filter IS NULL OR COALESCE(client, 'all_clients') = client_filter)
  GROUP BY week, client
)
, daily_actuals AS (
  -- For day-over-day comparisons
  SELECT
    date
    , COALESCE(client, 'all_clients') AS client
    , SUM(total_spend) AS daily_spend
    , CAST(SUM(new_orders) AS FLOAT64) AS daily_new_orders
    , CAST(SUM(new_revenue) AS FLOAT64) AS daily_new_revenue
    , CAST(SUM(total_orders) AS FLOAT64) AS daily_total_orders
    , CAST(SUM(total_revenue) AS FLOAT64) AS daily_total_revenue
    , CAST(AVG(broas_l3d) AS FLOAT64) AS daily_broas_l3d
  FROM `orcaanalytics.analytics.pacing__paka`
  WHERE date >= DATE_SUB(CURRENT_DATE('America/New_York'), INTERVAL 7 DAYS)
    AND (client_filter IS NULL OR COALESCE(client, 'all_clients') = client_filter)
  GROUP BY date, client
)
, dod_metrics AS (
  SELECT 
    client
    , daily_spend
    , daily_new_revenue
    , daily_total_revenue
    , daily_broas_l3d
    , LAG(daily_spend) OVER (PARTITION BY client ORDER BY date) AS prev_daily_spend
    , LAG(daily_new_revenue) OVER (PARTITION BY client ORDER BY date) AS prev_daily_new_revenue
    , LAG(daily_total_revenue) OVER (PARTITION BY client ORDER BY date) AS prev_daily_total_revenue
    , LAG(daily_broas_l3d) OVER (PARTITION BY client ORDER BY date) AS prev_daily_broas_l3d
    , ROUND((daily_spend / NULLIF(LAG(daily_spend) OVER (PARTITION BY client ORDER BY date), 0) - 1), 2) AS dod_spend_change
    , ROUND((daily_new_revenue / NULLIF(LAG(daily_new_revenue) OVER (PARTITION BY client ORDER BY date), 0) - 1), 2) AS dod_new_revenue_change
    , ROUND((daily_total_revenue / NULLIF(LAG(daily_total_revenue) OVER (PARTITION BY client ORDER BY date), 0) - 1), 2) AS dod_total_revenue_change
    , ROUND((daily_broas_l3d / NULLIF(LAG(daily_broas_l3d) OVER (PARTITION BY client ORDER BY date), 0) - 1), 2) AS dod_broas_change
  FROM daily_actuals
  WHERE date = DATE_SUB(CURRENT_DATE('America/New_York'), INTERVAL 1 DAY)
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
, unpivoted_weekly AS (
SELECT
  week AS `Week`
  , client AS `Client`
  , metric AS `Metric`
  , actual_value AS `Actuals`
  , target_value AS `Targets`
  , delta_value AS `% from Target`
  , 'weekly' AS report_type
FROM weekly_metrics
UNPIVOT(
  (actual_value, target_value, delta_value) 
  FOR metric IN (
    (total_spend, target_spend, delta_spend) AS 'Total Spend'
    , CASE WHEN include_new_orders THEN (new_orders, target_new_orders, delta_new_orders) END AS 'New Orders'
    , (new_revenue, target_new_revenue, delta_new_revenue) AS 'New Revenue'
    , (cac, target_cac, delta_cac) AS 'CAC'
    , CASE WHEN include_total_orders THEN (total_orders, target_total_orders, delta_total_orders) END AS 'Total Orders'
    , (total_revenue, target_total_revenue, delta_total_revenue) AS 'Total Revenue'
    , CASE WHEN include_broas THEN (broas_l3d, target_broas_l3d, delta_broas_l3d) END AS 'bROAS (L3D)'
  )
)
WHERE metric IS NOT NULL
)
, unpivoted_dod AS (
SELECT
  CAST(NULL AS DATE) AS `Week`
  , client AS `Client`
  , metric AS `Metric`
  , current_value AS `Actuals`
  , previous_value AS `Targets`
  , dod_change AS `% from Target`
  , 'daily' AS report_type
FROM dod_metrics
UNPIVOT(
  (current_value, previous_value, dod_change)
  FOR metric IN (
    (daily_spend, prev_daily_spend, dod_spend_change) AS 'Daily Spend (DoD)'
    , (daily_new_revenue, prev_daily_new_revenue, dod_new_revenue_change) AS 'Daily New Revenue (DoD)'
    , (daily_total_revenue, prev_daily_total_revenue, dod_total_revenue_change) AS 'Daily Total Revenue (DoD)'
    , CASE WHEN include_broas THEN (daily_broas_l3d, prev_daily_broas_l3d, dod_broas_change) END AS 'Daily bROAS L3D (DoD)'
  )
)
WHERE include_dod_metrics 
  AND metric IS NOT NULL
)

-- Final output based on report mode
SELECT * FROM (
  SELECT * FROM unpivoted_weekly
  WHERE report_mode IN ('internal', 'external')
  
  UNION ALL
  
  SELECT * FROM unpivoted_dod  
  WHERE report_mode = 'external' AND include_dod_metrics
)
ORDER BY 
  Client,
  CASE WHEN report_type = 'weekly' THEN 1 ELSE 2 END,
  Week DESC,
  Metric;