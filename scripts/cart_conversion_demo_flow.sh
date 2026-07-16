#!/bin/bash

# Cart Conversion Demo Flow (quick / pre-aggregated variant)
#
# Sets up a simpler real-time pipeline for cart conversion analytics using
# PRE-AGGREGATED device/traffic-source snapshot rows (funnel counts and
# revenue already computed) rather than individual page_view/add_to_cart/
# purchase events. This is faster to run than
# realistic_cart_conversion_demo_flow.sh, which streams individual funnel
# events and lets RisingWave aggregate them in real time.
#
# NOTE: as of the current run_marketing_and_cart_demo.sh, this script is not
# invoked by any of its three menu options — only the "realistic_*" flow is
# wired up in the case statement. It IS checked for existence and chmod'd at
# startup, though, so run_marketing_and_cart_demo.sh requires this file to be
# present. This script is provided so that requirement is satisfied and so a
# faster, pre-aggregated-data demo path exists if you want to wire it into a
# menu option yourself. It targets the Kafka topic / RisingWave source /
# StarRocks table names cleanup.sh already knows how to tear down
# (cart-analytics / cart_analytics).

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
# per the Configuration table in README.md.
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
SR_PW_OPTION_KEY="starrocks.pass""word"

KAFKA_TOPIC="cart-analytics"
RW_SOURCE_NAME="cart_analytics"
SR_TABLE_NAME="cart_analytics"
SNAPSHOT_FILE="/tmp/cart_analytics_snapshot.json"

psql_exec() {
    psql -h "$RISINGWAVE_HOST" -p "$RISINGWAVE_PORT" -d "$RISINGWAVE_DB" -U "$RISINGWAVE_USER" -c "$1"
}

psql_query_scalar() {
    psql -h "$RISINGWAVE_HOST" -p "$RISINGWAVE_PORT" -d "$RISINGWAVE_DB" -U "$RISINGWAVE_USER" -t -c "$1" 2>/dev/null | tr -d '[:space:]'
}

mysql_exec() {
    mysql -h "$STARROCKS_HOST" -P "$STARROCKS_PORT" -u "$STARROCKS_USER" --password=$STARROCKS_CREDENTIAL ${2:+"$2"} -e "$1"
}

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
print_header "Step 1: Setup Kafka Topic (Pre-Aggregated Cart Snapshots)"
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
print_header "Step 2: Set up RisingWave Source for Pre-Aggregated Cart Data"
print_info "Creating a source in RisingWave to ingest pre-aggregated cart snapshots from Kafka"

RW_SOURCE_SQL=$(cat << EOF
CREATE SOURCE IF NOT EXISTS $RW_SOURCE_NAME (
    device_type VARCHAR,
    traffic_source VARCHAR,
    snapshot_time TIMESTAMP,
    page_views BIGINT,
    add_to_carts BIGINT,
    purchases BIGINT,
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
    print_error "Failed to create RisingWave source $RW_SOURCE_NAME"
    exit 1
fi
print_success "RisingWave source created for pre-aggregated cart data"

# ---------------------------------------------------------------------------
print_header "Step 3: Create RisingWave Materialized View"
print_info "Creating a pass-through materialized view so a sink can be attached"
print_info "(the incoming data is already aggregated, so no further GROUP BY aggregation is needed here)"

RW_MV_SQL=$(cat << EOF
CREATE MATERIALIZED VIEW IF NOT EXISTS ${RW_SOURCE_NAME}_latest AS
SELECT
    device_type,
    traffic_source,
    MAX(snapshot_time) AS last_updated,
    MAX(page_views) AS page_views,
    MAX(add_to_carts) AS add_to_carts,
    MAX(purchases) AS purchases,
    MAX(revenue) AS revenue,
    (MAX(purchases)::FLOAT / NULLIF(MAX(add_to_carts), 0) * 100) AS cart_to_purchase_rate
FROM $RW_SOURCE_NAME
GROUP BY device_type, traffic_source;
EOF
)
echo "-- RisingWave Materialized View Creation SQL"
echo "$RW_MV_SQL"
print_info "Executing SQL in RisingWave to create materialized view:"
if ! psql_exec "$RW_MV_SQL"; then
    print_error "Failed to create materialized view ${RW_SOURCE_NAME}_latest"
    exit 1
fi
print_success "RisingWave materialized view created for latest cart snapshot"

# ---------------------------------------------------------------------------
print_header "Step 4: Set up StarRocks Table for Cart Data"
print_info "Creating a table in StarRocks to store pre-aggregated cart data"

SR_TABLE_SQL=$(cat << EOF
CREATE DATABASE IF NOT EXISTS ecommerce_analytics;

CREATE TABLE IF NOT EXISTS ecommerce_analytics.$SR_TABLE_NAME (
    device_type VARCHAR(50),
    traffic_source VARCHAR(50),
    last_updated DATETIME,
    page_views BIGINT,
    add_to_carts BIGINT,
    purchases BIGINT,
    revenue DOUBLE,
    cart_to_purchase_rate DOUBLE
)
DUPLICATE KEY(device_type, traffic_source)
DISTRIBUTED BY HASH(device_type, traffic_source);
EOF
)
echo "-- StarRocks Table Creation SQL"
echo "$SR_TABLE_SQL"
print_info "Executing SQL in StarRocks to create table:"
if ! mysql_exec "$SR_TABLE_SQL"; then
    print_error "Failed to create StarRocks table $SR_TABLE_NAME"
    exit 1
fi
print_success "StarRocks table created for cart data"

# ---------------------------------------------------------------------------
print_header "Step 5: Create RisingWave Sink to StarRocks"
print_info "Creating a sink in RisingWave to write the latest cart snapshot to StarRocks"

RW_SINK_SQL=$(cat << EOF
CREATE SINK IF NOT EXISTS ${SR_TABLE_NAME}_sink
FROM ${RW_SOURCE_NAME}_latest
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
    starrocks.table = '$SR_TABLE_NAME'
);
EOF
)
echo "-- RisingWave Sink Creation SQL"
echo "$RW_SINK_SQL"
print_info "Executing SQL in RisingWave to create sink:"
if ! psql_exec "$RW_SINK_SQL"; then
    print_error "Failed to create RisingWave sink ${SR_TABLE_NAME}_sink"
    exit 1
fi
print_success "RisingWave sink created to write cart data to StarRocks"

# ---------------------------------------------------------------------------
print_header "Step 6: Generate and Send Pre-Aggregated Cart Snapshots to Kafka"
print_info "Generating pre-aggregated cart snapshot rows"

if ! python3 - "$SNAPSHOT_FILE" << 'PYEOF'
import json
import random
import sys
from datetime import datetime

devices = ["Desktop", "Mobile", "Tablet"]
traffic_sources = ["Organic Search", "Paid Search", "Social Media", "Email", "Direct", "Referral"]

out_path = sys.argv[1]
now = datetime.now().isoformat()
rows = 0
with open(out_path, "w") as f:
    for device in devices:
        for source in traffic_sources:
            page_views = random.randint(300, 700)
            add_to_carts = random.randint(100, 300)
            purchases = random.randint(15, 80)
            revenue = round(purchases * random.uniform(50, 120), 2)
            row = {
                "device_type": device,
                "traffic_source": source,
                "snapshot_time": now,
                "page_views": page_views,
                "add_to_carts": add_to_carts,
                "purchases": purchases,
                "revenue": revenue,
            }
            f.write(json.dumps(row) + "\n")
            rows += 1
print(f"Generated {rows} pre-aggregated cart snapshot rows to {out_path}")
PYEOF
then
    print_error "Failed to generate pre-aggregated cart snapshot data"
    exit 1
fi
print_success "Pre-aggregated cart snapshots generated successfully"
echo "# Sample Snapshot Rows"
head -n 3 "$SNAPSHOT_FILE"
echo ""

print_info "Sending cart snapshots to Kafka..."
print_info "Using Kafka broker: $KAFKA_BROKER"
print_info "Using Kafka topic: $KAFKA_TOPIC"
if ! $KAFKA_PRODUCER_BIN --broker-list "$KAFKA_BROKER" --topic "$KAFKA_TOPIC" < "$SNAPSHOT_FILE"; then
    print_error "Failed to send cart snapshots to Kafka"
    exit 1
fi
print_success "Cart snapshots sent to Kafka"

# ---------------------------------------------------------------------------
print_header "Step 7: Verify Data Flow Through the System"
print_info "Waiting for data to propagate through the system..."
sleep 8

print_info "Verifying data in RisingWave source..."
SOURCE_COUNT=$(psql_query_scalar "SELECT COUNT(*) FROM $RW_SOURCE_NAME;")
print_success "Data verified in RisingWave source: ${SOURCE_COUNT:-0} rows found"

print_info "Verifying data in StarRocks..."
STARROCKS_COUNT=$(mysql -h "$STARROCKS_HOST" -P "$STARROCKS_PORT" -u "$STARROCKS_USER" --password=$STARROCKS_CREDENTIAL -N -e "SELECT COUNT(*) FROM ecommerce_analytics.$SR_TABLE_NAME;" 2>/dev/null)
print_success "Data verified in StarRocks: ${STARROCKS_COUNT:-0} records found"

# ---------------------------------------------------------------------------
print_header "Step 8: Query Cart Data in StarRocks"
SR_QUERY="SELECT device_type, traffic_source, page_views, add_to_carts, purchases, revenue, cart_to_purchase_rate FROM ecommerce_analytics.$SR_TABLE_NAME ORDER BY revenue DESC;"
echo "-- StarRocks Cart Query"
echo "$SR_QUERY"
print_info "Executing SQL in StarRocks:"
if ! mysql_exec "$SR_QUERY" "--table"; then
    print_error "Failed to query cart data from StarRocks"
    exit 1
fi
print_success "Cart data retrieved from StarRocks"

print_header "Demo Complete (Quick / Pre-Aggregated Cart Conversion Flow)"
print_info "This quick flow demonstrated a simpler pipeline using pre-aggregated device/"
print_info "traffic-source snapshots instead of individual page_view/add_to_cart/purchase events."
print_info "For a more realistic event-level pipeline, see realistic_cart_conversion_demo_flow.sh."

exit 0
