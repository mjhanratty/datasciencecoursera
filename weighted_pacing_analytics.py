# Authentication and Libraries
from google.colab import auth
from google.cloud import bigquery
import pandas as pd
import numpy as np
from datetime import datetime
from calendar import monthrange

# Initialize authentication and client
auth.authenticate_user()
bq = bigquery.Client(project="orcaanalytics")


def load_full_data():
    """Load pacing and forecast data from BigQuery."""
    query_pacing = """
        SELECT
            date,
            total_spend
        FROM `orcaanalytics.analytics.pacing___template`
        WHERE total_spend IS NOT NULL
        ORDER BY date
    """
    
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


def calculate_daily_weights(pacing_df, year, month):
    """Calculate daily spending weights based on actual historical spend pattern."""
    # Filter pacing data for the specific month
    pacing_df['date'] = pd.to_datetime(pacing_df['date'])
    month_mask = (pacing_df['date'].dt.year == year) & (pacing_df['date'].dt.month == month)
    month_data = pacing_df[month_mask].copy()
    
    if month_data.empty:
        raise ValueError(f"No pacing data found for {year}-{month:02d}")
    
    # Sort by date to ensure proper order
    month_data = month_data.sort_values('date')
    
    # Calculate total spend for the month
    total_month_spend = month_data['total_spend'].sum()
    
    if total_month_spend == 0:
        raise ValueError(f"Total spend is zero for {year}-{month:02d}")
    
    # Calculate daily weights (proportion of total monthly spend)
    daily_weights = (month_data['total_spend'] / total_month_spend).tolist()
    
    return daily_weights, len(daily_weights)


def distribute_weights_to_target_month(daily_weights, source_days, target_days):
    """Distribute weights from source month to target month with different day counts."""
    
    if source_days == target_days:
        # Same number of days, return weights as-is
        return daily_weights
    
    elif source_days > target_days:
        # Source month has more days, need to consolidate
        # Group consecutive days and sum their weights
        days_per_group = source_days / target_days
        new_weights = []
        
        for i in range(target_days):
            start_idx = int(i * days_per_group)
            end_idx = int((i + 1) * days_per_group)
            # Sum weights for this group of days
            group_weight = sum(daily_weights[start_idx:end_idx])
            new_weights.append(group_weight)
        
        return new_weights
    
    else:
        # Source month has fewer days, need to distribute
        # Interpolate weights to target month length
        source_positions = np.linspace(0, 1, source_days)
        target_positions = np.linspace(0, 1, target_days)
        
        # Use numpy interpolation to distribute weights
        interpolated_weights = np.interp(target_positions, source_positions, daily_weights)
        
        # Normalize to ensure they still sum to 1.0
        total_weight = sum(interpolated_weights)
        normalized_weights = [w / total_weight for w in interpolated_weights]
        
        return normalized_weights.tolist()


def generate_weighted_mom_pacing(pacing_df, forecast_df, target_year, target_month):
    """Generate month-over-month pacing with weighted spend distribution."""
    # Create a copy to avoid modifying original data
    forecast_df = forecast_df.copy()
    
    # Parse forecast month column
    forecast_df["month_date"] = pd.to_datetime(forecast_df["month"], format="%Y-%m", errors="coerce")
    forecast_df["year"] = forecast_df["month_date"].dt.year
    forecast_df["month_num"] = forecast_df["month_date"].dt.month
    
    # Helper function to get projection for a given year/month
    def get_projection(year, month):
        row = forecast_df[(forecast_df["year"] == year) & (forecast_df["month_num"] == month)]
        if row.empty:
            raise ValueError(f"No forecast data found for {year}-{month:02d}")
        return float(row.iloc[0]["projection_spend"])
    
    # Get target month projection
    target_projection = get_projection(target_year, target_month)
    
    # Calculate previous month
    prev_year, prev_month = (target_year - 1, 12) if target_month == 1 else (target_year, target_month - 1)
    
    # Get daily weights from previous month's actual spending pattern
    daily_weights, prev_days = calculate_daily_weights(pacing_df, prev_year, prev_month)
    
    # Get target month day count
    target_days = monthrange(target_year, target_month)[1]
    
    # Distribute weights to match target month length
    target_weights = distribute_weights_to_target_month(daily_weights, prev_days, target_days)
    
    # Generate target month dates
    target_dates = pd.date_range(
        start=datetime(target_year, target_month, 1), 
        periods=target_days, 
        freq='D'
    )
    
    # Return weighted budget allocation (as multipliers, not dollar amounts)
    return [
        {
            "date": date.strftime("%Y-%m-%d"), 
            "weight": weight,
            "projected_spend": target_projection * weight
        }
        for date, weight in zip(target_dates, target_weights)
    ]


# Example usage function
def example_usage():
    """Example of how to use the weighted pacing function."""
    # Load data
    pacing_df, forecast_df = load_full_data()
    
    # Generate weighted pacing for February 2024 based on January 2024 pattern
    result = generate_weighted_mom_pacing(pacing_df, forecast_df, 2024, 2)
    
    # Print first few results
    for i, day_data in enumerate(result[:5]):
        print(f"Day {i+1}: {day_data['date']} - Weight: {day_data['weight']:.3f} - Projected: ${day_data['projected_spend']:,.2f}")
    
    return result
