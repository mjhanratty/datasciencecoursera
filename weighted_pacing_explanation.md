# Weighted Pacing Analytics - Enhanced Approach

## Key Changes from Flat Pacing:

### 1. Historical Pattern Analysis
The new approach analyzes the actual spending pattern from the previous month instead of assuming flat daily distribution.

### 2. Weight Calculation Process:

**Step 1: Extract Previous Month Spending**
```python
# Filter actual spending data for previous month
month_data = pacing_df[(pacing_df['date'].dt.year == prev_year) & 
                       (pacing_df['date'].dt.month == prev_month)]

# Calculate daily weights as proportion of total monthly spend
daily_weights = month_data['total_spend'] / total_month_spend
```

**Step 2: Handle Different Month Lengths**
- **Same days**: Use weights directly
- **Fewer target days**: Consolidate weights by grouping consecutive days
- **More target days**: Interpolate weights using numpy interpolation

**Step 3: Apply Weights to Target Budget**
```python
projected_spend = target_projection * weight
```

### 3. Example Scenario:

**Previous Month (January - 31 days, $300,000 budget):**
- Day 1: $8,000 (weight: 0.027)
- Day 2: $12,000 (weight: 0.040)
- Day 3: $6,000 (weight: 0.020)
- etc.

**Target Month (February - 28 days, $280,000 budget):**
- Day 1: $280,000 × 0.027 = $7,560
- Day 2: $280,000 × 0.040 = $11,200
- Day 3: $280,000 × 0.020 = $5,600
- etc.

### 4. Handling Month Length Differences:

**Case 1: 31-day month → 28-day month**
Groups days (e.g., days 1-2 weights combined for day 1 of target)

**Case 2: 28-day month → 31-day month**
Interpolates weights across the longer period while maintaining the spending pattern

### 5. Return Format:
Each day returns:
- `date`: The target date
- `weight`: The budget multiplier (0.15, 0.25, 1.1, etc.)
- `projected_spend`: The actual dollar amount for that day

### 6. Benefits:
- **Realistic pacing**: Reflects actual business spending patterns
- **Flexible**: Handles different month lengths automatically
- **Scalable**: Works with any budget size
- **Pattern preservation**: Maintains the shape of spending curves

### 7. Error Handling:
- Validates that historical data exists for the previous month
- Ensures total spend is not zero
- Normalizes weights to sum to 1.0 when interpolating

This approach gives you a much more realistic projection that accounts for real business spending patterns like higher spend at month-end, lower spend on weekends, etc.
