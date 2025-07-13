#!/bin/bash

# Cleanup script for RealTimeAnalyticsDemo
# This script removes all objects created by the demo in AutoMQ, RisingWave, and StarRocks

# Set colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print section headers
print_header() {
    echo -e "\n${BLUE}$1${NC}"
    echo -e "${BLUE}$(printf '=%.0s' {1..80})${NC}"
}

# Function to print success messages
print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

# Function to print info messages
print_info() {
    echo -e "${YELLOW}➜ $1${NC}"
}

# Set connection variables
RISINGWAVE_HOST="<RISINGWAVE_HOST>"
RISINGWAVE_PORT="<RISINGWAVE_PORT>"
RISINGWAVE_DB="dev"
RISINGWAVE_USER="<RISINGWAVE_USER>"
STARROCKS_HOST="<STARROCKS_HOST>"
STARROCKS_PORT="<STARROCKS_PORT>"
STARROCKS_USER="<STARROCKS_USER>"
STARROCKS_PASSWORD="<STARROCKS_PASSWORD>"

# Cleanup RisingWave objects
print_header "Cleaning up RisingWave objects"

# Drop sinks
print_info "Dropping RisingWave sinks..."
RISINGWAVE_DROP_SINKS=$(cat << EOF
DROP SINK IF EXISTS campaign_performance_sink;
DROP SINK IF EXISTS cart_conversion_funnel_sink;
EOF
)
psql -h $RISINGWAVE_HOST -p $RISINGWAVE_PORT -d $RISINGWAVE_DB -U $RISINGWAVE_USER -c "$RISINGWAVE_DROP_SINKS"
print_success "RisingWave sinks dropped"

# Drop all materialized views
print_info "Dropping all RisingWave materialized views..."
# First, get a list of all materialized views
MV_LIST=$(psql -h $RISINGWAVE_HOST -p $RISINGWAVE_PORT -d $RISINGWAVE_DB -U $RISINGWAVE_USER -t -c "SELECT name FROM rw_catalog.rw_materialized_views;")

# Drop each materialized view
for mv in $MV_LIST; do
    if [ ! -z "$mv" ]; then
        print_info "Dropping materialized view: $mv"
        # Try to drop the materialized view, but don't exit if it fails
        psql -h $RISINGWAVE_HOST -p $RISINGWAVE_PORT -d $RISINGWAVE_DB -U $RISINGWAVE_USER -c "DROP MATERIALIZED VIEW IF EXISTS $mv;" || true
    fi
done

# Also try to drop our specific materialized views in case they weren't in the list
psql -h $RISINGWAVE_HOST -p $RISINGWAVE_PORT -d $RISINGWAVE_DB -U $RISINGWAVE_USER -c "DROP MATERIALIZED VIEW IF EXISTS campaign_performance;"
psql -h $RISINGWAVE_HOST -p $RISINGWAVE_PORT -d $RISINGWAVE_DB -U $RISINGWAVE_USER -c "DROP MATERIALIZED VIEW IF EXISTS cart_conversion_funnel;"
psql -h $RISINGWAVE_HOST -p $RISINGWAVE_PORT -d $RISINGWAVE_DB -U $RISINGWAVE_USER -c "DROP MATERIALIZED VIEW IF EXISTS detailed_campaign_performance;"
psql -h $RISINGWAVE_HOST -p $RISINGWAVE_PORT -d $RISINGWAVE_DB -U $RISINGWAVE_USER -c "DROP MATERIALIZED VIEW IF EXISTS hourly_performance;"
psql -h $RISINGWAVE_HOST -p $RISINGWAVE_PORT -d $RISINGWAVE_DB -U $RISINGWAVE_USER -c "DROP MATERIALIZED VIEW IF EXISTS ad_events_stream;"
psql -h $RISINGWAVE_HOST -p $RISINGWAVE_PORT -d $RISINGWAVE_DB -U $RISINGWAVE_USER -c "DROP MATERIALIZED VIEW IF EXISTS platform_device_performance;"
psql -h $RISINGWAVE_HOST -p $RISINGWAVE_PORT -d $RISINGWAVE_DB -U $RISINGWAVE_USER -c "DROP MATERIALIZED VIEW IF EXISTS geographic_performance;"

print_success "RisingWave materialized views dropped"

# Drop all sources
print_info "Dropping all RisingWave sources..."
# First, get a list of all sources
SOURCE_LIST=$(psql -h $RISINGWAVE_HOST -p $RISINGWAVE_PORT -d $RISINGWAVE_DB -U $RISINGWAVE_USER -t -c "SELECT name FROM rw_catalog.rw_sources WHERE connector = 'kafka';")

# Drop each source
for source in $SOURCE_LIST; do
    if [ ! -z "$source" ]; then
        print_info "Dropping source: $source"
        psql -h $RISINGWAVE_HOST -p $RISINGWAVE_PORT -d $RISINGWAVE_DB -U $RISINGWAVE_USER -c "DROP SOURCE IF EXISTS $source;"
    fi
done

# Also try to drop our specific sources in case they weren't in the list
psql -h $RISINGWAVE_HOST -p $RISINGWAVE_PORT -d $RISINGWAVE_DB -U $RISINGWAVE_USER -c "DROP SOURCE IF EXISTS marketing_campaigns;"
psql -h $RISINGWAVE_HOST -p $RISINGWAVE_PORT -d $RISINGWAVE_DB -U $RISINGWAVE_USER -c "DROP SOURCE IF EXISTS cart_analytics;"

print_success "RisingWave sources dropped"

# Cleanup StarRocks objects
print_header "Cleaning up StarRocks objects"

# Drop StarRocks tables
print_info "Dropping StarRocks tables..."
STARROCKS_DROP_TABLES=$(cat << EOF
DROP TABLE IF EXISTS ecommerce_analytics.marketing_campaigns;
DROP TABLE IF EXISTS ecommerce_analytics.cart_analytics;
DROP TABLE IF EXISTS ecommerce_analytics.campaign_performance;
DROP TABLE IF EXISTS ecommerce_analytics.cart_conversion_funnel;
DROP TABLE IF EXISTS ecommerce_analytics.cart_abandonment_by_device;
DROP TABLE IF EXISTS ecommerce_analytics.inventory_analytics;
DROP TABLE IF EXISTS ecommerce_analytics.error_analytics;
DROP TABLE IF EXISTS ecommerce_analytics.revenue_impact_analysis;
DROP TABLE IF EXISTS ecommerce_analytics.product_performance;
DROP TABLE IF EXISTS ecommerce_analytics.user_behavior;
DROP TABLE IF EXISTS ecommerce_analytics.geographic_analytics;
DROP TABLE IF EXISTS ecommerce_analytics.hourly_analytics;
EOF
)
mysql -h $STARROCKS_HOST -P $STARROCKS_PORT -u $STARROCKS_USER --password=$STARROCKS_PASSWORD -e "$STARROCKS_DROP_TABLES"
print_success "StarRocks tables dropped"

# Create AutoMQ topics (if kafka tools are available)
print_header "Checking for Kafka tools"
if command -v kafka-topics.sh &> /dev/null; then
    print_info "Kafka tools found, recreating topics..."
    
    # Delete topics if they exist
    print_info "Deleting existing topics..."
    KAFKA_BROKER="<KAFKA_BROKER>"
    kafka-topics.sh --bootstrap-server $KAFKA_BROKER --delete --topic marketing-campaigns --if-exists
    kafka-topics.sh --bootstrap-server $KAFKA_BROKER --delete --topic cart-analytics --if-exists
    
    # Create topics
    print_info "Creating topics..."
    kafka-topics.sh --bootstrap-server $KAFKA_BROKER --create --topic marketing-campaigns --partitions 1 --replication-factor 1
    kafka-topics.sh --bootstrap-server $KAFKA_BROKER --create --topic cart-analytics --partitions 1 --replication-factor 1
    
    print_success "Kafka topics recreated"
else
    print_info "Kafka tools not found. Please install Kafka tools or add them to your PATH."
    print_info "You can install Kafka tools with:"
    print_info "  apt-get update && apt-get install -y kafkacat"
    print_info "  or"
    print_info "  pip install kafka-python"
fi

print_header "Cleanup Complete"
print_success "All demo objects have been removed from RisingWave and StarRocks"
print_info "You can now run the demo again with a clean environment"