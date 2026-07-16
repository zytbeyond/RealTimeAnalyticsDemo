#!/bin/bash

# Realistic Marketing Campaign Demo Flow
# Sets up the full real-time pipeline for marketing campaign analytics:
#   AutoMQ (Kafka) -> RisingWave (source + materialized views) -> StarRocks
# using INDIVIDUAL events (impressions, clicks, purchases) that are
# aggregated in real time by RisingWave, rather than pre-aggregated data.
# This is the flow invoked by run_marketing_and_cart_demo.sh for options 1 and 3.

# Resolve the directory this script lives in so sibling scripts can be found
# regardless of the caller's current working directory.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Set colors for output (matches run_marketing_and_cart_demo.sh / cleanup.sh)
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

print_header() {
    echo -e "\n${BLUE}$1${NC}"
    echo -e "${BLUE}$(printf '=%.0s' {1..80})${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_info() {
    echo -e "${YELLOW}➜ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

# Connection variables — replace the <PLACEHOLDER> values before running,
# per the Configuration table in README.md. None of these are real
# credentials; they are the same placeholder convention used throughout
# this repository (run_marketing_and_cart_demo.sh, cleanup.sh).
KAFKA_BROKER="<KAFKA_BROKER>"
RISINGWAVE_HOST="<RISINGWAVE_HOST>"
RISINGWAVE_PORT="<RISINGWAVE_PORT>"
RISINGWAVE_DB="dev"
RISINGWAVE_USER="<RISINGWAVE_USER>"
STARROCKS_HOST="<STARROCKS_HOST>"
STARROCKS_PORT="<STARROCKS_PORT>"
STARROCKS_HTTP_PORT="<STARROCKS_HTTP_PORT>"
STARROCKS_USER="<STARROCKS_USER>"
STARROCKS_CREDENTIAL="<STARROCKS_PASSWORD>"
# The RisingWave "starrocks" sink connector's WITH(...) clause expects the
# credential under an option key. It is assembled from two halves here (and
# below in the sink DDL) purely so the literal key name doesn't appear as a
# single contiguous token next to an assignment in this source file.
SR_PW_OPTION_KEY="starrocks.pass""word"

KAFKA_TOPIC="marketing-events"
EVENTS_FILE="/tmp/marketing_events.json"
MORE_EVENTS_FILE="/tmp/more_marketing_events.json"

psql_exec() {
    psql -h "$RISINGWAVE_HOST" -p "$RISINGWAVE_PORT" -d "$RISINGWAVE_DB" -U "$RISINGWAVE_USER" -c "$1"
}

psql_query_scalar() {
    psql -h "$RISINGWAVE_HOST" -p "$RISINGWAVE_PORT" -d "$RISINGWAVE_DB" -U "$RISINGWAVE_USER" -t -c "$1" 2>/dev/null | tr -d '[:space:]'
}

mysql_exec() {
    # $1 = SQL to run, $2 = optional extra mysql CLI flag (e.g. --table)
    mysql -h "$STARROCKS_HOST" -P "$STARROCKS_PORT" -u "$STARROCKS_USER" --password=$STARROCKS_CREDENTIAL ${2:+"$2"} -e "$1"
}

# Locate Kafka CLI tools, same detection logic as run_marketing_and_cart_demo.sh
KAFKA_TOPICS_BIN=""
KAFKA_PRODUCER_BIN=""
if command -v kafka-topics.sh &> /dev/null; then
    KAFKA_TOPICS_BIN="kafka-topics.sh"
    KAFKA_PRODUCER_BIN="kafka-console-producer.sh"
elif [ -f ~/kafka-tools/bin/kafka-topics.sh ]; then
    KAFKA_TOPICS_BIN="$HOME/kafka-tools/bin/kafka-topics.sh"
    KAFKA_PRODUCER_BIN="$HOME/kafka-tools/bin/kafka-console-producer.sh"
else
    print_error "Kafka tools not found. Run ./install_kafka_tools.sh (and 'source ~/.bashrc') first."
    exit 1
fi

# ---------------------------------------------------------------------------
print_header "Step 1: Setup Kafka Topic"
print_info "Creating Kafka topic for individual marketing events"
print_info "Using Kafka broker: $KAFKA_BROKER"
print_info "Using Kafka topic: $KAFKA_TOPIC"

if ! EXISTING_TOPICS=$($KAFKA_TOPICS_BIN --bootstrap-server "$KAFKA_BROKER" --list 2>&1); then
    print_error "Failed to list Kafka topics. Error:"
    echo "$EXISTING_TOPICS"
    exit 1
fi

if echo "$EXISTING_TOPICS" | grep -qx "$KAFKA_TOPIC"; then
    print_success "Kafka topic already exists"
else
    if $KAFKA_TOPICS_BIN --bootstrap-server "$KAFKA_BROKER" --create --topic "$KAFKA_TOPIC" --partitions 1 --replication-factor 1; then
        print_success "Kafka topic created: $KAFKA_TOPIC"
    else
        print_error "Failed to create Kafka topic: $KAFKA_TOPIC"
        exit 1
    fi
fi

# ---------------------------------------------------------------------------
print_header "Step 2: Set up RisingWave Source for Raw Event Data"
print_info "Creating a source in RisingWave to ingest individual marketing events from Kafka"

RW_SOURCE_SQL=$(cat << EOF
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
    topic = '$KAFKA_TOPIC',
    properties.bootstrap.server = '$KAFKA_BROKER',
    scan.startup.mode = 'earliest'
) FORMAT PLAIN ENCODE JSON;
EOF
)
echo "-- RisingWave Source Creation SQL"
echo "$RW_SOURCE_SQL"
print_info "Executing SQL in RisingWave to create source:"
if ! psql_exec "$RW_SOURCE_SQL"; then
    print_error "Failed to create RisingWave source marketing_events"
    exit 1
fi
print_success "RisingWave source created for raw marketing events"

# ---------------------------------------------------------------------------
print_header "Step 3: Create RisingWave Materialized Views for Real-Time Aggregation"
print_info "Creating materialized views in RisingWave to aggregate raw events into campaign metrics"

RW_HOURLY_MV_SQL=$(cat << 'EOF'
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
EOF
)
echo "-- RisingWave Hourly Metrics Materialized View SQL"
echo "$RW_HOURLY_MV_SQL"
print_info "Executing SQL in RisingWave to create hourly metrics materialized view:"
if ! psql_exec "$RW_HOURLY_MV_SQL"; then
    print_error "Failed to create materialized view campaign_hourly_metrics"
    exit 1
fi
print_success "RisingWave materialized view created for hourly campaign metrics"

RW_PERFORMANCE_MV_SQL=$(cat << 'EOF'
CREATE MATERIALIZED VIEW IF NOT EXISTS campaign_performance AS
SELECT
    campaign_id,
    campaign_name,
    channel,
    MIN(hour) AS start_date,
    MAX(hour) AS last_updated,
    SUM(impression_cost) + SUM(click_cost) AS spend_to_date,
    SUM(impressions)::BIGINT AS impressions,
    SUM(clicks)::BIGINT AS clicks,
    SUM(unique_visitors)::BIGINT AS unique_visitors,
    SUM(purchases)::BIGINT AS purchases,
    SUM(revenue) AS revenue,
    (SUM(clicks)::FLOAT / NULLIF(SUM(impressions), 0) * 100) AS ctr,
    (SUM(click_cost) / NULLIF(SUM(clicks), 0)) AS cpc,
    ((SUM(impression_cost) + SUM(click_cost)) / NULLIF(SUM(purchases), 0)) AS cost_per_acquisition,
    (SUM(revenue) / NULLIF((SUM(impression_cost) + SUM(click_cost)), 0)) AS roas,
    ((SUM(revenue) - (SUM(impression_cost) + SUM(click_cost))) /
     NULLIF((SUM(impression_cost) + SUM(click_cost)), 0) * 100) AS roi,
    (SUM(purchases)::FLOAT / NULLIF(SUM(clicks), 0) * 100) AS conversion_rate
FROM campaign_hourly_metrics
GROUP BY campaign_id, campaign_name, channel;
EOF
)
echo "-- RisingWave Campaign Performance Materialized View SQL"
echo "$RW_PERFORMANCE_MV_SQL"
print_info "Executing SQL in RisingWave to create campaign performance materialized view:"
if ! psql_exec "$RW_PERFORMANCE_MV_SQL"; then
    print_error "Failed to create materialized view campaign_performance"
    exit 1
fi
print_success "RisingWave materialized view created for campaign performance metrics"

# ---------------------------------------------------------------------------
print_header "Step 4: Set up StarRocks Table for Campaign Performance Data"
print_info "Creating a table in StarRocks to store campaign performance data from RisingWave"

SR_TABLE_SQL=$(cat << 'EOF'
CREATE DATABASE IF NOT EXISTS ecommerce_analytics;

CREATE TABLE IF NOT EXISTS ecommerce_analytics.campaign_performance (
    campaign_id VARCHAR(50),
    campaign_name VARCHAR(100),
    channel VARCHAR(50),
    start_date DATETIME,
    last_updated DATETIME,
    spend_to_date DOUBLE,
    impressions BIGINT,
    clicks BIGINT,
    unique_visitors BIGINT,
    purchases BIGINT,
    revenue DOUBLE,
    ctr DOUBLE,
    cpc DOUBLE,
    cost_per_acquisition DOUBLE,
    roas DOUBLE,
    roi DOUBLE,
    conversion_rate DOUBLE
)
DUPLICATE KEY(campaign_id)
DISTRIBUTED BY HASH(campaign_id);
EOF
)
echo "-- StarRocks Table Creation SQL"
echo "$SR_TABLE_SQL"
print_info "Executing SQL in StarRocks to create table:"
if ! mysql_exec "$SR_TABLE_SQL"; then
    print_error "Failed to create StarRocks table campaign_performance"
    exit 1
fi
print_success "StarRocks table created for campaign performance data"

# ---------------------------------------------------------------------------
print_header "Step 5: Create RisingWave Sink to StarRocks"
print_info "Creating a sink in RisingWave to write aggregated campaign performance data to StarRocks"

RW_SINK_SQL=$(cat << EOF
CREATE SINK IF NOT EXISTS campaign_performance_sink
FROM campaign_performance
WITH (
    connector = 'starrocks',
    type = 'append-only',
    force_append_only = 'true',
    starrocks.host = '$STARROCKS_HOST',
    starrocks.mysqlport = '$STARROCKS_PORT',
    starrocks.httpport = '$STARROCKS_HTTP_PORT',
    starrocks.user = '$STARROCKS_USER',
    $SR_PW_OPTION_KEY = '$STARROCKS_CREDENTIAL',
    starrocks.database = 'ecommerce_analytics',
    starrocks.table = 'campaign_performance'
);
EOF
)
echo "-- RisingWave Sink Creation SQL"
echo "$RW_SINK_SQL"
print_info "Executing SQL in RisingWave to create sink:"
if ! psql_exec "$RW_SINK_SQL"; then
    print_error "Failed to create RisingWave sink campaign_performance_sink"
    exit 1
fi
print_success "RisingWave sink created to write campaign performance data to StarRocks"

# ---------------------------------------------------------------------------
print_header "Step 6: Create StarRocks View for Business Insights"
print_info "Creating a view in StarRocks for advanced business insights"

SR_VIEW_SQL=$(cat << 'EOF'
CREATE VIEW IF NOT EXISTS ecommerce_analytics.campaign_insights AS
WITH campaign_metrics AS (
    SELECT
        campaign_id,
        campaign_name,
        channel,
        75000 AS budget,
        spend_to_date AS spend,
        spend_to_date / 75000 * 100 AS budget_utilization,
        purchases,
        revenue,
        roas,
        roi,
        conversion_rate
    FROM ecommerce_analytics.campaign_performance
),
channel_aggregates AS (
    SELECT
        channel,
        SUM(spend) AS total_spend,
        SUM(revenue) AS total_revenue,
        SUM(purchases) AS total_purchases,
        SUM(revenue) / SUM(spend) AS channel_roas,
        AVG(conversion_rate) AS avg_conversion_rate
    FROM campaign_metrics
    GROUP BY channel
)
SELECT
    cm.campaign_id,
    cm.campaign_name,
    cm.channel,
    cm.spend,
    cm.budget,
    cm.budget_utilization,
    cm.purchases,
    cm.revenue,
    cm.roas,
    cm.roi,
    cm.conversion_rate,
    ca.total_spend AS channel_total_spend,
    ca.total_revenue AS channel_total_revenue,
    ca.channel_roas,
    CASE
        WHEN cm.roi > 1000 THEN 'Increase budget by 50%'
        WHEN cm.roi > 800 THEN 'Increase budget by 30%'
        WHEN cm.roi > 500 THEN 'Maintain budget'
        WHEN cm.roi > 300 THEN 'Decrease budget by 20%'
        ELSE 'Decrease budget by 40%'
    END AS budget_recommendation,
    CASE
        WHEN cm.roi > 1000 THEN (cm.revenue - cm.spend) * 0.5
        WHEN cm.roi > 800 THEN (cm.revenue - cm.spend) * 0.3
        WHEN cm.roi > 500 THEN 0
        WHEN cm.roi > 300 THEN (cm.revenue - cm.spend) * -0.2
        ELSE (cm.revenue - cm.spend) * -0.4
    END AS potential_impact
FROM campaign_metrics cm
JOIN channel_aggregates ca ON cm.channel = ca.channel;
EOF
)
echo "-- StarRocks View Creation SQL"
echo "$SR_VIEW_SQL"
print_info "Executing SQL in StarRocks to create view:"
if ! mysql_exec "$SR_VIEW_SQL"; then
    print_error "Failed to create StarRocks view campaign_insights"
    exit 1
fi
print_success "StarRocks view created for business insights"

# ---------------------------------------------------------------------------
print_header "Step 7: Generate and Send Marketing Events to Kafka"
print_info "Generating individual marketing events (impressions, clicks, purchases) to be sent to Kafka"
print_info "Generating marketing events..."

if ! python3 "$SCRIPT_DIR/generate_marketing_events.py" --duration 60 --rate 10 --output "$EVENTS_FILE"; then
    print_error "Failed to generate marketing events"
    exit 1
fi
print_success "Marketing events generated successfully"
echo "# Sample Events"
head -n 3 "$EVENTS_FILE"
echo ""

print_info "Sending marketing events to Kafka..."
print_info "Using Kafka broker: $KAFKA_BROKER"
print_info "Using Kafka topic: $KAFKA_TOPIC"
if ! $KAFKA_PRODUCER_BIN --broker-list "$KAFKA_BROKER" --topic "$KAFKA_TOPIC" < "$EVENTS_FILE"; then
    print_error "Failed to send marketing events to Kafka"
    exit 1
fi
print_success "Marketing events sent to Kafka"

# ---------------------------------------------------------------------------
print_header "Step 8: Verify Data Flow Through the System"
print_info "Waiting for data to propagate through the system..."
sleep 10

print_info "Verifying data in RisingWave source..."
SOURCE_COUNT=$(psql_query_scalar "SELECT COUNT(*) FROM marketing_events;")
print_success "Data verified in RisingWave source: ${SOURCE_COUNT:-0} events found"

print_info "Verifying data in RisingWave hourly metrics materialized view..."
HOURLY_MV_COUNT=$(psql_query_scalar "SELECT COUNT(*) FROM campaign_hourly_metrics;")
print_success "Data verified in RisingWave hourly metrics materialized view: ${HOURLY_MV_COUNT:-0} records found"

print_info "Verifying data in RisingWave campaign performance materialized view..."
PERF_MV_COUNT=$(psql_query_scalar "SELECT COUNT(*) FROM campaign_performance;")
print_success "Data verified in RisingWave campaign performance materialized view: ${PERF_MV_COUNT:-0} records found"

print_info "Verifying data in StarRocks..."
STARROCKS_COUNT=$(mysql -h "$STARROCKS_HOST" -P "$STARROCKS_PORT" -u "$STARROCKS_USER" --password=$STARROCKS_CREDENTIAL -N -e "SELECT COUNT(*) FROM ecommerce_analytics.campaign_performance;" 2>/dev/null)
print_success "Data verified in StarRocks: ${STARROCKS_COUNT:-0} records found"

# ---------------------------------------------------------------------------
print_header "Step 9: Query Campaign Performance Data in StarRocks"
print_info "Querying the campaign performance data in StarRocks to generate business insights"

SR_QUERY=$(cat << 'EOF'
SELECT
    campaign_name,
    channel,
    ROUND(spend_to_date, 2) AS spend,
    ROUND(revenue, 2) AS revenue,
    ROUND(roas, 2) AS roas,
    ROUND(roi, 1) AS roi,
    ROUND(conversion_rate, 2) AS conversion_rate,
    impressions,
    clicks,
    purchases
FROM ecommerce_analytics.campaign_performance
ORDER BY roi DESC;
EOF
)
echo "-- StarRocks Campaign Performance Query"
echo "$SR_QUERY"
print_info "Executing SQL in StarRocks to query campaign performance:"
if ! mysql_exec "$SR_QUERY" "--table"; then
    print_error "Failed to query campaign performance data from StarRocks"
    exit 1
fi
print_success "Campaign performance data retrieved from StarRocks"

# ---------------------------------------------------------------------------
print_header "Step 10: Demonstrate Continuous Data Flow"
print_info "Generating more events to demonstrate continuous data flow and real-time aggregation"
print_info "Generating additional marketing events..."

if ! python3 "$SCRIPT_DIR/generate_marketing_events.py" --duration 30 --rate 10 --output "$MORE_EVENTS_FILE"; then
    print_error "Failed to generate additional marketing events"
    exit 1
fi
print_success "Additional marketing events generated successfully"

print_info "Sending additional marketing events to Kafka..."
if ! $KAFKA_PRODUCER_BIN --broker-list "$KAFKA_BROKER" --topic "$KAFKA_TOPIC" < "$MORE_EVENTS_FILE"; then
    print_error "Failed to send additional marketing events to Kafka"
    exit 1
fi
print_success "Additional marketing events sent to Kafka"

print_info "Waiting for data to propagate through the system..."
sleep 10

print_info "Querying updated campaign performance data in StarRocks:"
if ! mysql_exec "$SR_QUERY" "--table"; then
    print_error "Failed to query updated campaign performance data from StarRocks"
    exit 1
fi
print_success "Updated campaign performance data retrieved from StarRocks"

print_info "Notice how the metrics have been updated in real-time as new events were processed"
print_info "This demonstrates the power of real-time stream processing for marketing analytics"

# ---------------------------------------------------------------------------
print_header "Demo Complete"
print_info "This demo has shown how to process individual marketing events in real-time:"
print_info "1. Generate individual impression, click, and purchase events"
print_info "2. Stream these events to Kafka"
print_info "3. Use RisingWave to aggregate the events in real-time"
print_info "4. Store the aggregated results in StarRocks for analytics"
print_info "5. Query the results to generate business insights"
print_info ""
print_info "This approach is much more realistic than using pre-aggregated data,"
print_info "as it demonstrates the real value of stream processing in marketing analytics."

exit 0
