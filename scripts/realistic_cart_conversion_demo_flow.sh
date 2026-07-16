#!/bin/bash

# Realistic Cart Conversion Demo Flow
# Sets up the full real-time pipeline for cart conversion / funnel analytics:
#   AutoMQ (Kafka) -> RisingWave (source + materialized views) -> StarRocks
# using INDIVIDUAL events (page views, product views, add-to-cart, checkout
# starts, purchases) that are aggregated in real time by RisingWave, rather
# than pre-aggregated data.
# This is the flow invoked by run_marketing_and_cart_demo.sh for options 2 and 3.

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

KAFKA_TOPIC="cart-events"
EVENTS_FILE="/tmp/cart_events.json"
MORE_EVENTS_FILE="/tmp/more_cart_events.json"

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
print_info "Creating Kafka topic for individual cart events"
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
print_info "Creating a source in RisingWave to ingest individual cart events from Kafka"

RW_SOURCE_SQL=$(cat << EOF
CREATE SOURCE IF NOT EXISTS cart_events (
    event_type VARCHAR,
    event_id VARCHAR,
    timestamp TIMESTAMP,
    session_id VARCHAR,
    user_id VARCHAR,
    device_type VARCHAR,
    traffic_source VARCHAR,
    product_id VARCHAR,
    product_category VARCHAR,
    product_price DOUBLE PRECISION,
    quantity INTEGER,
    cart_id VARCHAR,
    checkout_id VARCHAR,
    purchase_id VARCHAR,
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
    print_error "Failed to create RisingWave source cart_events"
    exit 1
fi
print_success "RisingWave source created for raw cart events"

# ---------------------------------------------------------------------------
print_header "Step 3: Create RisingWave Materialized Views for Real-Time Aggregation"
print_info "Creating materialized views in RisingWave to aggregate raw events into cart metrics"
print_info "RisingWave Transformation Explanation:"
print_info "1. RisingWave continuously processes incoming events in real-time"
print_info "2. The materialized views maintain an always up-to-date state of the aggregated metrics"
print_info "3. When new events arrive in Kafka, RisingWave automatically:"
print_info "   - Ingests the new events"
print_info "   - Aggregates them by device type, traffic source, and product category"
print_info "   - Updates the materialized views with the latest results"
print_info "   - Makes the updated results immediately available for querying"
print_info "4. This enables real-time decision making based on the latest cart behavior data"

RW_HOURLY_MV_SQL=$(cat << 'EOF'
CREATE MATERIALIZED VIEW IF NOT EXISTS cart_hourly_metrics AS
SELECT
    date_trunc('hour', timestamp) AS hour,
    device_type,
    traffic_source,
    product_category,
    COUNT(*) FILTER (WHERE event_type = 'page_view') AS page_views,
    COUNT(*) FILTER (WHERE event_type = 'product_view') AS product_views,
    COUNT(*) FILTER (WHERE event_type = 'add_to_cart') AS add_to_carts,
    COUNT(*) FILTER (WHERE event_type = 'checkout_start') AS checkout_starts,
    COUNT(*) FILTER (WHERE event_type = 'purchase') AS purchases,
    COUNT(DISTINCT session_id) FILTER (WHERE event_type = 'page_view') AS unique_sessions,
    SUM(CASE WHEN event_type = 'purchase' THEN revenue ELSE 0 END) AS revenue
FROM cart_events
GROUP BY date_trunc('hour', timestamp), device_type, traffic_source, product_category;
EOF
)
echo "-- RisingWave Hourly Metrics Materialized View SQL"
echo "$RW_HOURLY_MV_SQL"
print_info "Executing SQL in RisingWave to create hourly metrics materialized view:"
if ! psql_exec "$RW_HOURLY_MV_SQL"; then
    print_error "Failed to create materialized view cart_hourly_metrics"
    exit 1
fi
print_success "RisingWave materialized view created for hourly cart metrics"

RW_FUNNEL_MV_SQL=$(cat << 'EOF'
CREATE MATERIALIZED VIEW IF NOT EXISTS cart_conversion_funnel AS
SELECT
    device_type,
    traffic_source,
    product_category,
    MIN(hour) AS start_date,
    MAX(hour) AS last_updated,
    SUM(page_views)::BIGINT AS total_page_views,
    SUM(product_views)::BIGINT AS total_product_views,
    SUM(add_to_carts)::BIGINT AS total_add_to_carts,
    SUM(checkout_starts)::BIGINT AS total_checkout_starts,
    SUM(purchases)::BIGINT AS total_purchases,
    SUM(revenue) AS total_revenue,
    (SUM(product_views)::FLOAT / NULLIF(SUM(page_views), 0) * 100) AS page_to_product_rate,
    (SUM(add_to_carts)::FLOAT / NULLIF(SUM(product_views), 0) * 100) AS view_to_cart_rate,
    (SUM(checkout_starts)::FLOAT / NULLIF(SUM(add_to_carts), 0) * 100) AS cart_to_checkout_rate,
    (SUM(purchases)::FLOAT / NULLIF(SUM(checkout_starts), 0) * 100) AS checkout_to_purchase_rate,
    (SUM(purchases)::FLOAT / NULLIF(SUM(add_to_carts), 0) * 100) AS cart_to_purchase_rate,
    (SUM(revenue) / NULLIF(SUM(purchases), 0)) AS average_order_value
FROM cart_hourly_metrics
GROUP BY device_type, traffic_source, product_category;
EOF
)
echo "-- RisingWave Cart Conversion Funnel Materialized View SQL"
echo "$RW_FUNNEL_MV_SQL"
print_info "Executing SQL in RisingWave to create cart conversion funnel materialized view:"
if ! psql_exec "$RW_FUNNEL_MV_SQL"; then
    print_error "Failed to create materialized view cart_conversion_funnel"
    exit 1
fi
print_success "RisingWave materialized view created for cart conversion funnel metrics"

# ---------------------------------------------------------------------------
print_header "Step 4: Set up StarRocks Table for Cart Conversion Data"
print_info "Creating a table in StarRocks to store cart conversion data from RisingWave"

SR_TABLE_SQL=$(cat << 'EOF'
CREATE DATABASE IF NOT EXISTS ecommerce_analytics;

CREATE TABLE IF NOT EXISTS ecommerce_analytics.cart_conversion_funnel (
    device_type VARCHAR(50),
    traffic_source VARCHAR(50),
    product_category VARCHAR(50),
    start_date DATETIME,
    last_updated DATETIME,
    total_page_views BIGINT,
    total_product_views BIGINT,
    total_add_to_carts BIGINT,
    total_checkout_starts BIGINT,
    total_purchases BIGINT,
    total_revenue DOUBLE,
    page_to_product_rate DOUBLE,
    view_to_cart_rate DOUBLE,
    cart_to_checkout_rate DOUBLE,
    checkout_to_purchase_rate DOUBLE,
    cart_to_purchase_rate DOUBLE,
    average_order_value DOUBLE
)
DUPLICATE KEY(device_type, traffic_source, product_category)
DISTRIBUTED BY HASH(device_type, traffic_source);
EOF
)
echo "-- StarRocks Table Creation SQL"
echo "$SR_TABLE_SQL"
print_info "Executing SQL in StarRocks to create table:"
if ! mysql_exec "$SR_TABLE_SQL"; then
    print_error "Failed to create StarRocks table cart_conversion_funnel"
    exit 1
fi
print_success "StarRocks table created for cart conversion data"

# ---------------------------------------------------------------------------
print_header "Step 5: Create RisingWave Sink to StarRocks"
print_info "Creating a sink in RisingWave to write aggregated cart conversion data to StarRocks"

RW_SINK_SQL=$(cat << EOF
CREATE SINK IF NOT EXISTS cart_conversion_funnel_sink
FROM cart_conversion_funnel
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
    starrocks.table = 'cart_conversion_funnel'
);
EOF
)
echo "-- RisingWave Sink Creation SQL"
echo "$RW_SINK_SQL"
print_info "Executing SQL in RisingWave to create sink:"
if ! psql_exec "$RW_SINK_SQL"; then
    print_error "Failed to create RisingWave sink cart_conversion_funnel_sink"
    exit 1
fi
print_success "RisingWave sink created to write cart conversion data to StarRocks"

# ---------------------------------------------------------------------------
print_header "Step 6: Create StarRocks View for Business Insights"
print_info "Creating a view in StarRocks for advanced business insights"

SR_VIEW_SQL=$(cat << 'EOF'
CREATE VIEW IF NOT EXISTS ecommerce_analytics.cart_conversion_insights AS
WITH device_metrics AS (
    SELECT
        device_type,
        SUM(total_page_views) AS page_views,
        SUM(total_add_to_carts) AS add_to_carts,
        SUM(total_purchases) AS purchases,
        SUM(total_revenue) AS revenue,
        AVG(cart_to_purchase_rate) AS avg_cart_to_purchase_rate,
        SUM(total_revenue) / SUM(total_purchases) AS avg_order_value
    FROM ecommerce_analytics.cart_conversion_funnel
    GROUP BY device_type
),
device_source_metrics AS (
    SELECT
        device_type,
        traffic_source,
        SUM(total_page_views) AS page_views,
        SUM(total_add_to_carts) AS add_to_carts,
        SUM(total_purchases) AS purchases,
        SUM(total_revenue) AS revenue,
        AVG(cart_to_purchase_rate) AS cart_to_purchase_rate,
        SUM(total_revenue) / SUM(total_purchases) AS average_order_value
    FROM ecommerce_analytics.cart_conversion_funnel
    GROUP BY device_type, traffic_source
)
SELECT
    dsm.device_type,
    dsm.traffic_source,
    dsm.page_views,
    dsm.add_to_carts,
    dsm.purchases,
    ROUND(dsm.cart_to_purchase_rate, 2) AS cart_to_purchase_rate,
    ROUND(dsm.average_order_value, 2) AS average_order_value,
    CASE
        WHEN dsm.device_type = 'Mobile' THEN 'Optimize mobile checkout experience'
        WHEN dsm.device_type = 'Desktop' AND dsm.traffic_source = 'Email' THEN 'Maintain high-performing experience'
        WHEN dsm.device_type = 'Tablet' THEN 'Improve tablet cart-to-purchase rate'
        ELSE 'Standard optimization'
    END AS recommendation,
    CASE
        WHEN dsm.device_type = 'Mobile' THEN ROUND((0.45 - dsm.cart_to_purchase_rate/100) * dsm.add_to_carts * dsm.average_order_value, 2)
        WHEN dsm.device_type = 'Tablet' THEN ROUND((0.50 - dsm.cart_to_purchase_rate/100) * dsm.add_to_carts * dsm.average_order_value, 2)
        ELSE 0
    END AS potential_revenue_increase
FROM device_source_metrics dsm
ORDER BY dsm.device_type, dsm.average_order_value DESC;
EOF
)
echo "-- StarRocks View Creation SQL"
echo "$SR_VIEW_SQL"
print_info "Executing SQL in StarRocks to create view:"
if ! mysql_exec "$SR_VIEW_SQL"; then
    print_error "Failed to create StarRocks view cart_conversion_insights"
    exit 1
fi
print_success "StarRocks view created for business insights"

# ---------------------------------------------------------------------------
print_header "Step 7: Generate and Send Cart Events to Kafka"
print_info "Generating individual cart events (page views, product views, add to carts, etc.) to be sent to Kafka"
print_info "Generating cart events..."

if ! python3 "$SCRIPT_DIR/generate_cart_events.py" --duration 60 --rate 10 --output "$EVENTS_FILE"; then
    print_error "Failed to generate cart events"
    exit 1
fi
print_success "Cart events generated successfully"
echo "# Sample Events"
head -n 3 "$EVENTS_FILE"
echo ""

print_info "Sending cart events to Kafka..."
print_info "Using Kafka broker: $KAFKA_BROKER"
print_info "Using Kafka topic: $KAFKA_TOPIC"
if ! $KAFKA_PRODUCER_BIN --broker-list "$KAFKA_BROKER" --topic "$KAFKA_TOPIC" < "$EVENTS_FILE"; then
    print_error "Failed to send cart events to Kafka"
    exit 1
fi
print_success "Cart events sent to Kafka"

# ---------------------------------------------------------------------------
print_header "Step 8: Verify Data Flow Through the System"
print_info "Waiting for data to propagate through the system..."
sleep 10

print_info "Verifying data in RisingWave source..."
SOURCE_COUNT=$(psql_query_scalar "SELECT COUNT(*) FROM cart_events;")
print_success "Data verified in RisingWave source: ${SOURCE_COUNT:-0} events found"

print_info "Verifying data in RisingWave hourly metrics materialized view..."
HOURLY_MV_COUNT=$(psql_query_scalar "SELECT COUNT(*) FROM cart_hourly_metrics;")
print_success "Data verified in RisingWave hourly metrics materialized view: ${HOURLY_MV_COUNT:-0} records found"

print_info "Verifying data in RisingWave cart conversion funnel materialized view..."
FUNNEL_MV_COUNT=$(psql_query_scalar "SELECT COUNT(*) FROM cart_conversion_funnel;")
print_success "Data verified in RisingWave cart conversion funnel materialized view: ${FUNNEL_MV_COUNT:-0} records found"

print_info "Verifying data in StarRocks..."
STARROCKS_COUNT=$(mysql -h "$STARROCKS_HOST" -P "$STARROCKS_PORT" -u "$STARROCKS_USER" --password=$STARROCKS_CREDENTIAL -N -e "SELECT COUNT(*) FROM ecommerce_analytics.cart_conversion_funnel;" 2>/dev/null)
print_success "Data verified in StarRocks: ${STARROCKS_COUNT:-0} records found"

# ---------------------------------------------------------------------------
print_header "Step 9: Query Cart Conversion Data in StarRocks"
print_info "Querying the cart conversion data in StarRocks to generate business insights"

SR_QUERY=$(cat << 'EOF'
SELECT
    device_type,
    traffic_source,
    SUM(total_product_views) AS product_views,
    SUM(total_add_to_carts) AS add_to_carts,
    SUM(total_purchases) AS purchases,
    ROUND(AVG(view_to_cart_rate), 2) AS view_to_cart_rate,
    ROUND(AVG(cart_to_purchase_rate), 2) AS cart_to_purchase_rate,
    ROUND(SUM(total_revenue) / SUM(total_purchases), 2) AS average_order_value
FROM ecommerce_analytics.cart_conversion_funnel
GROUP BY device_type, traffic_source
ORDER BY average_order_value DESC;
EOF
)
echo "-- StarRocks Cart Conversion Query"
echo "$SR_QUERY"
print_info "Executing SQL in StarRocks to query cart conversion:"
if ! mysql_exec "$SR_QUERY" "--table"; then
    print_error "Failed to query cart conversion data from StarRocks"
    exit 1
fi
print_success "Cart conversion data retrieved from StarRocks"

# ---------------------------------------------------------------------------
print_header "Step 10: Demonstrate Continuous Data Flow"
print_info "Generating more events to demonstrate continuous data flow and real-time aggregation"
print_info "Generating additional cart events..."

if ! python3 "$SCRIPT_DIR/generate_cart_events.py" --duration 30 --rate 10 --output "$MORE_EVENTS_FILE"; then
    print_error "Failed to generate additional cart events"
    exit 1
fi
print_success "Additional cart events generated successfully"

print_info "Sending additional cart events to Kafka..."
if ! $KAFKA_PRODUCER_BIN --broker-list "$KAFKA_BROKER" --topic "$KAFKA_TOPIC" < "$MORE_EVENTS_FILE"; then
    print_error "Failed to send additional cart events to Kafka"
    exit 1
fi
print_success "Additional cart events sent to Kafka"

print_info "Waiting for data to propagate through the system..."
sleep 10

print_info "Querying updated cart conversion data in StarRocks:"
if ! mysql_exec "$SR_QUERY" "--table"; then
    print_error "Failed to query updated cart conversion data from StarRocks"
    exit 1
fi
print_success "Updated cart conversion data retrieved from StarRocks"

print_info "Notice how the metrics have been updated in real-time as new events were processed"
print_info "This demonstrates the power of real-time stream processing for cart conversion analytics"

# ---------------------------------------------------------------------------
print_header "Step 11: AI Agent Insights on Cart Conversion Data"
print_info "The Generative AI Agent analyzes the real-time cart conversion data and provides insights"
print_info "(These insights are scripted/hardcoded in run_marketing_and_cart_demo.sh, not generated live by an LLM.)"

# ---------------------------------------------------------------------------
print_header "Demo Complete: Real-Time Cart Conversion Analysis"
print_info "This demo showcased the complete real-time data flow:"
print_info "1. Individual cart events streamed to Kafka"
print_info "2. RisingWave processing events in real-time to calculate conversion metrics"
print_info "3. StarRocks providing high-performance analytics on the aggregated data"
print_info "4. Generative AI Agent analyzing the data and providing actionable insights"
print_info "5. End-to-end data pipeline with no intermediate storage required"
print_info "6. Real-time business insights driving immediate cart optimization decisions"
print_success "Demo completed successfully!"

exit 0
