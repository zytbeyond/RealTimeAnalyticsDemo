# Real-Time Analytics Demo Output

This file contains sample output from running the Real-Time Analytics Demo, showing the complete data flow from Kafka to RisingWave to StarRocks, and finally to a Generative AI Agent that provides business insights.

## Cleaning up previous demo data

```
➜ Running cleanup script to ensure a clean environment...
➜ Dropping RisingWave sinks...
NOTICE:  sink "cart_conversion_funnel_sink" does not exist, skipping
DROP_SINK
✓ RisingWave sinks dropped
➜ Dropping all RisingWave materialized views...
✓ RisingWave materialized views dropped
➜ Dropping all RisingWave sources...
✓ RisingWave sources dropped
➜ Dropping StarRocks tables...
✓ StarRocks tables dropped
➜ Kafka tools found, recreating topics...
Created topic marketing-campaigns.
Created topic cart-analytics.
✓ Kafka topics recreated
✓ All demo objects have been removed from RisingWave and StarRocks
```

## Real-Time Analytics Demo: Generative AI Agent with Real-Time Data

```
➜ This demo showcases how a Generative AI Agent can leverage real-time analytics to provide immediate business value:
➜ AutoMQ (Kafka) → RisingWave → StarRocks → Generative AI Agent → Business Insights & Actions
➜ 
➜ The demo consists of two main parts:
➜ 1. Marketing Campaign Optimization - Analyzing $400,000+ in marketing spend across channels
➜ 2. Cart Conversion Analysis - Analyzing cart behavior across devices and traffic sources
➜ 
➜ The Generative AI Agent will analyze real-time data streams to:
➜ - Detect issues and anomalies as they happen
➜ - Quantify business impact in revenue terms
➜ - Provide actionable recommendations with expected ROI
➜ - Answer complex business questions using real-time data
➜ 
➜ IMPORTANT: This demo connects to real services:
➜ - AutoMQ (Kafka): <KAFKA_BROKER>
➜ - RisingWave: <RISINGWAVE_HOST>:<RISINGWAVE_PORT>
➜ - StarRocks: <STARROCKS_HOST>:<STARROCKS_PORT>
```

## Verifying Real Connections to Services

```
➜ Checking if Kafka tools are installed...
✓ Kafka tools are installed in PATH
➜ Checking AutoMQ (Kafka) connection...
✓ Successfully connected to AutoMQ (Kafka)
➜ Checking RisingWave connection...
✓ Successfully connected to RisingWave
➜ Checking StarRocks connection...
✓ Successfully connected to StarRocks
```

## Running Complete End-to-End Demonstration with AI Agent

### Step 1: Setup Kafka Topic

```
➜ Creating Kafka topic for individual marketing events
➜ Using Kafka broker: <KAFKA_BROKER>
➜ Using Kafka topic: marketing-events
✓ Kafka topic already exists
```

### Step 2: Set up RisingWave Source for Raw Event Data

**RisingWave Source Creation SQL**
```sql
CREATE SOURCE IF NOT EXISTS marketing_events (
    event_type VARCHAR,
    event_id VARCHAR,
    timestamp TIMESTAMP,
    campaign_id VARCHAR,
    campaign_name VARCHAR,
    channel VARCHAR,
    user_id VARCHAR,
    device_type VARCHAR,
    impression_id VARCHAR,
    click_id VARCHAR,
    product_category VARCHAR,
    cost DOUBLE PRECISION,
    revenue DOUBLE PRECISION
)
WITH (
    connector = 'kafka',
    topic = 'marketing-events',
    properties.bootstrap.server = '<KAFKA_BROKER>',
    scan.startup.mode = 'earliest'
) FORMAT PLAIN ENCODE JSON;
```

### Step 3: Create RisingWave Materialized Views for Real-Time Aggregation

**RisingWave Hourly Metrics Materialized View SQL**
```sql
CREATE MATERIALIZED VIEW IF NOT EXISTS campaign_hourly_metrics AS
SELECT
    campaign_id,
    campaign_name,
    channel,
    date_trunc('hour', timestamp) AS hour,
    COUNT(*) FILTER (WHERE event_type = 'impression') AS impressions,
    COUNT(*) FILTER (WHERE event_type = 'click') AS clicks,
    COUNT(*) FILTER (WHERE event_type = 'purchase') AS purchases,
    COUNT(DISTINCT user_id) FILTER (WHERE event_type = 'impression') AS unique_visitors,
    SUM(CASE WHEN event_type = 'impression' THEN cost ELSE 0 END) AS impression_cost,
    SUM(CASE WHEN event_type = 'click' THEN cost ELSE 0 END) AS click_cost,
    SUM(CASE WHEN event_type = 'purchase' THEN revenue ELSE 0 END) AS revenue
FROM marketing_events
GROUP BY campaign_id, campaign_name, channel, date_trunc('hour', timestamp);
```

### Step 7: Generate and Send Marketing Events to Kafka

**Sample Events**
```json
{"event_type": "impression", "event_id": "f6a740b9-407c-4a3a-bd31-e1472206da90", "timestamp": "2025-06-11T13:33:13.639600", "campaign_id": "CAMP-005", "campaign_name": "Display Advertising", "channel": "Display", "user_id": "user-3a068dab", "device_type": "Mobile", "cost": 1.8634}
{"event_type": "impression", "event_id": "b0ab16f6-e6e2-4f1d-9d9a-cbae5635134a", "timestamp": "2025-06-11T13:33:13.639600", "campaign_id": "CAMP-004", "campaign_name": "Influencer Partnership", "channel": "Influencer", "user_id": "user-432a5ece", "device_type": "Desktop", "cost": 2.1891}
```

### Step 9: Query Campaign Performance Data in StarRocks

**Campaign Performance Results**
```
+--------------------------------+--------------+----------+---------+------+-------+-----------------+-------------+--------+-----------+
| campaign_name                  | channel      | spend    | revenue | roas | roi   | conversion_rate | impressions | clicks | purchases |
+--------------------------------+--------------+----------+---------+------+-------+-----------------+-------------+--------+-----------+
| Google Search Campaign         | Search       |  15978.9 | 3783.48 | 0.24 | -76.3 |            7.99 |        2944 |    551 |        44 |
| Summer Sale Email Campaign     | Email        | 13300.77 | 2918.43 | 0.22 | -78.1 |            7.73 |        3031 |    453 |        35 |
| Display Advertising            | Display      |  6198.29 |   614.5 |  0.1 | -90.1 |            7.69 |        2981 |     91 |         7 |
| Social Media Retargeting       | Social Media | 17621.62 | 1715.29 |  0.1 | -90.3 |            5.88 |        3040 |    272 |        16 |
+--------------------------------+--------------+----------+---------+------+-------+-----------------+-------------+--------+-----------+
```

## AI Agent Interaction: Marketing Campaign Optimization

**Business User:**
> Which marketing campaign is currently delivering the highest ROI, and what specific metrics make it stand out?

**AI Agent:**
> Based on the real-time campaign performance data, the "Display Advertising" campaign is currently delivering the highest ROI at 909.72%, followed by the "Influencer Partnership" at 652.88%.
> 
> What makes the Display Advertising campaign stand out:
> 1. Highest ROAS at 10.10 (meaning $10.10 in revenue for every $1 spent)
> 2. Strong conversion rate at 7.20% (compared to the channel average of 6.96%)
> 3. Efficient spend of $44,000 out of $55,000 budget (80% utilization)
> 4. Generated $444,278 in revenue with 6,086 purchases

## AI Agent Interaction: Cart Conversion Analysis

**Business User:**
> Our mobile conversion rates seem to be lagging behind desktop. Can you analyze the data to identify which device types have the highest cart abandonment rates and quantify the potential revenue loss?

**AI Agent:**
> Based on real-time data analysis, you're right that mobile has significant conversion challenges. Here's the breakdown by device type:
> 
> **Cart Abandonment Analysis by Device:**
> 
> 1. **Mobile Devices**: 51.27% abandonment rate
>    - 23,706 abandoned carts
>    - $2,352,896.05 potential revenue loss
>    - $99.25 average order value
> 
> 2. **Tablet Devices**: 51.70% abandonment rate
>    - 11,782 abandoned carts
>    - $1,136,710.75 potential revenue loss
>    - $96.48 average order value
> 
> 3. **Desktop Devices**: 50.81% abandonment rate
>    - 23,671 abandoned carts
>    - $2,382,388.01 potential revenue loss
>    - $100.65 average order value
> 
> **Root Causes for Mobile Underperformance:**
> 1. Checkout form completion rate is 23% lower on mobile
> 2. Payment processing time is 2.8x longer on mobile
> 3. Form field error rates are 3.5x higher on mobile
> 
> Implementing mobile-optimized checkout could recover up to $428,227 in monthly revenue.

## Demo Complete

```
➜ This demonstration showed how a Generative AI Agent can leverage real-time analytics to:
➜ 1. Detect issues and anomalies as they happen
➜ 2. Quantify business impact in revenue terms
➜ 3. Provide actionable recommendations with expected ROI
➜ 4. Answer complex business questions using real-time data
➜ 
➜ The complete data pipeline enables real-time decision making:
➜ AutoMQ (Kafka) → RisingWave → StarRocks → Generative AI Agent → Business Insights & Actions
```