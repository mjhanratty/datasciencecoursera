# Authentication and Libraries
from google.colab import auth
from google.cloud import bigquery
import pandas as pd
from datetime import datetime
from calendar import monthrange

# Initialize authentication and client
auth.authenticate_user()
bq = bigquery.Client(project="orcaanalytics")


def load_full_data():
    """Load pacing and forecast data from BigQuery."""
    # Simplified pacing query - removed unnecessary DATE() wrapper
    query_pacing = """
        SELECT
            date,
            total_spend
        FROM `orcaanalytics.analytics.pacing___template`
        WHERE total_spend IS NOT NULL
    """
    
    # Simplified forecast query - removed redundant SAFE functions where not needed
    query_forecast = """
        SELECT
            PARSE_DATE('%Y-%m-%d', date) AS date,
            month,
            CAST(projection_spend AS FLOAT64) AS projection_spend
        FROM `orcaanalytics.google_sheets__paka.projections_monthly`
        WHERE projection_spend IS NOT NULL
    """
    
    pacing_df = bq.query(query_pacing).to_dataframe()
    forecast_df = bq.query(query_forecast).to_dataframe()
    
    return pacing_df, forecast_df


def generate_mom_pacing(pacing_df, forecast_df, target_year, target_month):
    """Generate month-over-month pacing data."""
    # Create a copy to avoid modifying original data
    forecast_df = forecast_df.copy()
    
    # Parse forecast month column more efficiently
    forecast_df["month_date"] = pd.to_datetime(forecast_df["month"], format="%Y-%m", errors="coerce")
    forecast_df["year"] = forecast_df["month_date"].dt.year
    forecast_df["month_num"] = forecast_df["month_date"].dt.month
    
    # Helper function to get projection for a given year/month
    def get_projection(year, month):
        row = forecast_df[(forecast_df["year"] == year) & (forecast_df["month_num"] == month)]
        if row.empty:
            raise ValueError(f"No forecast data found for {year}-{month:02d}")
        return float(row.iloc[0]["projection_spend"])
    
    # Get target and previous month projections
    target_projection = get_projection(target_year, target_month)
    
    # Calculate previous month
    prev_year, prev_month = (target_year - 1, 12) if target_month == 1 else (target_year, target_month - 1)
    prev_projection = get_projection(prev_year, prev_month)
    
    # Calculate daily distribution
    num_prev_days = monthrange(prev_year, prev_month)[1]
    num_target_days = monthrange(target_year, target_month)[1]
    
    # Create even daily weights and scale to target month
    daily_spend = target_projection / num_prev_days
    
    # Generate target month dates and spend values
    target_dates = pd.date_range(
        start=datetime(target_year, target_month, 1), 
        periods=num_target_days, 
        freq='D'
    )
    
    # Return simplified result
    return [
        {"date": date.strftime("%Y-%m-%d"), "spend": daily_spend}
        for date in target_dates[:num_prev_days]  # Only use as many days as previous month
    ]
