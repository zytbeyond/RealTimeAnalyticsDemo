# Real-Time Analytics Demo

This repository contains scripts and code for demonstrating real-time analytics using a modern data stack:

- **AutoMQ (Kafka)**: For real-time data ingestion
- **RisingWave**: For real-time stream processing
- **StarRocks**: For high-performance analytics
- **Generative AI Agent**: For business insights and recommendations

## Demo Overview

The demo showcases how a Generative AI Agent can leverage real-time analytics to provide immediate business value. It consists of two main parts:

1. **Marketing Campaign Optimization**: Analyzing $400,000+ in marketing spend across channels
2. **Cart Conversion Analysis**: Analyzing cart behavior across devices and traffic sources

The Generative AI Agent analyzes real-time data streams to:
- Detect issues and anomalies as they happen
- Quantify business impact in revenue terms
- Provide actionable recommendations with expected ROI
- Answer complex business questions using real-time data

Note: in the scripts currently in this repository, the "AI Agent" responses printed by `run_marketing_and_cart_demo.sh` are scripted/hardcoded text illustrating what such an agent could say, not live output from an LLM call.

## Repository Structure

- `scripts/`: Contains the scripts included in this repository
  - `run_marketing_and_cart_demo.sh`: Interactive demo runner. Verifies AutoMQ (Kafka), RisingWave, and StarRocks connectivity, lets you pick Marketing Campaign Optimization, Cart Conversion Analysis, or both, runs the corresponding "realistic" flow script (see below), then prints simulated AI Agent responses to a scripted set of business questions.
  - `realistic_marketing_campaign_demo_flow.sh`: The flow actually invoked by `run_marketing_and_cart_demo.sh` for the Marketing Campaign option (and as part of "both demos"). Creates the `marketing-events` Kafka topic, a RisingWave `marketing_events` source, two materialized views (`campaign_hourly_metrics`, `campaign_performance`) that aggregate individual impression/click/purchase events in real time, the `ecommerce_analytics.campaign_performance` StarRocks table, a RisingWave sink from the materialized view into that table, and a `campaign_insights` StarRocks view. It then runs `generate_marketing_events.py` twice (once to seed data, once more to demonstrate the materialized views updating live) and queries StarRocks before and after to show the real-time aggregation working.
  - `realistic_cart_conversion_demo_flow.sh`: The flow actually invoked by `run_marketing_and_cart_demo.sh` for the Cart Conversion option (and as part of "both demos"). Creates the `cart-events` Kafka topic, a RisingWave `cart_events` source, two materialized views (`cart_hourly_metrics`, `cart_conversion_funnel`) that aggregate individual page_view/product_view/add_to_cart/checkout_start/purchase events in real time, the `ecommerce_analytics.cart_conversion_funnel` StarRocks table, a RisingWave sink into that table, and a `cart_conversion_insights` StarRocks view. It runs the new `generate_cart_events.py` generator twice and queries StarRocks before and after, the same way the marketing flow does.
  - `marketing_campaign_demo_flow.sh` and `cart_conversion_demo_flow.sh`: Quicker, pre-aggregated-data variants. `run_marketing_and_cart_demo.sh` checks for their existence and `chmod +x`'s them at startup, but — as shipped — its menu `case` statement only ever calls the `realistic_*` flows above; these two plain scripts are not currently wired into any menu option. They stand up a simpler pipeline (a Kafka topic carrying already-aggregated snapshot rows, a pass-through RisingWave materialized view, and a StarRocks table/sink) using the `marketing-campaigns`/`marketing_campaigns` and `cart-analytics`/`cart_analytics` names that `cleanup.sh` already knows how to tear down, so they satisfy `run_marketing_and_cart_demo.sh`'s startup checks and are available if you want to wire a faster demo path into the menu yourself.
  - `generate_marketing_events.py`: Standalone Python generator that produces synthetic marketing events (impressions, clicks, purchases) as JSON lines across 5 predefined campaigns/channels. Prints to stdout by default, or to a file with `--output`; intended to be piped into a Kafka producer. Invoked by `realistic_marketing_campaign_demo_flow.sh`.
  - `generate_cart_events.py`: Standalone Python generator, structurally mirroring `generate_marketing_events.py`, that produces synthetic cart/browsing-funnel events (page_view, product_view, add_to_cart, checkout_start, purchase) as JSON lines, with each session probabilistically dropping out at each funnel stage. Prints to stdout by default, or to a file with `--output`. Invoked by `realistic_cart_conversion_demo_flow.sh`.
  - `cleanup.sh`: Drops the RisingWave sinks, materialized views, and sources, drops the StarRocks tables under `ecommerce_analytics`, and deletes/recreates the `marketing-campaigns` and `cart-analytics` Kafka topics.
  - `install_kafka_tools.sh`: Installs OpenJDK, downloads Apache Kafka 3.5.1 client tools into `~/kafka-tools`, adds them to `PATH` via `~/.bashrc`, and installs `kafkacat` and the `kafka-python` pip package.

**Note on working directory**: `run_marketing_and_cart_demo.sh` references its flow scripts as `RealTimeAnalyticsDemo/scripts/<name>.sh`, which implies it is meant to be run from a *parent* directory containing a cloned `RealTimeAnalyticsDemo/` folder (i.e. `./RealTimeAnalyticsDemo/scripts/run_marketing_and_cart_demo.sh`), not from inside the repo itself. If you follow the "Setup Instructions" below and `cd RealTimeAnalyticsDemo` first, you will need to either run the demo from one directory above (`cd .. && ./RealTimeAnalyticsDemo/scripts/run_marketing_and_cart_demo.sh`) or adjust the paths in `run_marketing_and_cart_demo.sh` to match your preferred working directory.

## Prerequisites

Before running the demo, you need:

1. **AutoMQ (Kafka)** instance
2. **RisingWave** instance
3. **StarRocks** instance
4. Python 3.6+ (standard library only — `generate_marketing_events.py` and `generate_cart_events.py` have no external dependencies)
5. Kafka tools (can be installed using the provided `install_kafka_tools.sh` script)
6. `psql` and `mysql` command-line clients — `run_marketing_and_cart_demo.sh` and `cleanup.sh` call `psql` to talk to RisingWave and `mysql` to talk to StarRocks, but neither client is installed by `install_kafka_tools.sh`, so install them separately (e.g. `apt-get install -y postgresql-client mysql-client`)

## Setup Instructions

1. Clone this repository:
   ```
   git clone https://github.com/zytbeyond/RealTimeAnalyticsDemo.git
   cd RealTimeAnalyticsDemo
   ```

2. Install Kafka tools:
   ```
   ./scripts/install_kafka_tools.sh
   source ~/.bashrc  # To update your PATH
   ```

3. Update connection information in the scripts (see "Configuration" section below)

4. Run the demo:
   ```
   ./scripts/run_marketing_and_cart_demo.sh
   ```

## Configuration

⚠️ **IMPORTANT**: Before running the demo, you need to update the connection information in the scripts. Look for the following placeholders and replace them with your actual values:

| Placeholder | Description | Files to Update |
|-------------|-------------|----------------|
| `<KAFKA_BROKER>` | Kafka broker address (e.g., `localhost:9092`) | `run_marketing_and_cart_demo.sh`, `cleanup.sh`, all four `*_demo_flow.sh` scripts |
| `<RISINGWAVE_HOST>` | RisingWave host address | `run_marketing_and_cart_demo.sh`, `cleanup.sh`, all four `*_demo_flow.sh` scripts |
| `<RISINGWAVE_PORT>` | RisingWave port | `run_marketing_and_cart_demo.sh`, `cleanup.sh`, all four `*_demo_flow.sh` scripts |
| `<RISINGWAVE_USER>` | RisingWave username | `run_marketing_and_cart_demo.sh`, `cleanup.sh`, all four `*_demo_flow.sh` scripts |
| `<STARROCKS_HOST>` | StarRocks host address | `run_marketing_and_cart_demo.sh`, `cleanup.sh`, all four `*_demo_flow.sh` scripts |
| `<STARROCKS_PORT>` | StarRocks MySQL-protocol port | `run_marketing_and_cart_demo.sh`, `cleanup.sh`, all four `*_demo_flow.sh` scripts |
| `<STARROCKS_HTTP_PORT>` | StarRocks HTTP port (used by the RisingWave `starrocks` sink connector's `starrocks.httpport` option) | The four `*_demo_flow.sh` scripts only |
| `<STARROCKS_USER>` | StarRocks username | `run_marketing_and_cart_demo.sh`, `cleanup.sh`, all four `*_demo_flow.sh` scripts |
| `<STARROCKS_PASSWORD>` | StarRocks password | `run_marketing_and_cart_demo.sh`, `cleanup.sh`, all four `*_demo_flow.sh` scripts |

Note: `<STARROCKS_HTTP_PORT>` is new relative to earlier versions of this README — it's required by the RisingWave-to-StarRocks sink DDL (`starrocks.httpport`) that the flow scripts create, in addition to the MySQL-protocol port used for direct `mysql` CLI queries.

## Running the Demo

`run_marketing_and_cart_demo.sh` runs a cleanup pass, checks connectivity to AutoMQ (Kafka), RisingWave, and StarRocks, then prompts you to pick one of three options:

1. **Marketing Campaign Optimization**: Runs `realistic_marketing_campaign_demo_flow.sh`, then prints scripted AI Agent answers about campaign ROI/ROAS.
2. **Cart Conversion Analysis**: Runs `realistic_cart_conversion_demo_flow.sh`, then prints scripted AI Agent answers about cart abandonment by device.
3. **Both Demos**: Runs both flows in sequence, printing a subset of the scripted AI Agent answers from each.

For each option, the actual pipeline work — creating the Kafka topic, the RisingWave source and materialized views, the StarRocks table and sink, and generating/sending event data via `generate_marketing_events.py` or `generate_cart_events.py` — lives inside the corresponding `realistic_*_demo_flow.sh` script. After that flow script runs, `run_marketing_and_cart_demo.sh` prints a scripted set of business questions and simulated AI Agent answers based on `$400,000`+ in modeled marketing spend and synthetic cart-conversion data — these responses are hardcoded in the script, not generated live by an LLM.

`run_marketing_and_cart_demo.sh` does not check the exit status of the flow scripts it calls (there is no `set -e` and no `if`/`$?` check around those invocations), so if a flow script fails partway through — e.g. because a placeholder wasn't replaced, or a service is unreachable — the demo runner will still proceed to print the scripted AI Agent Q&A afterward. Watch the flow script's own `✓`/`✗` output to know whether the pipeline setup actually succeeded.

## Cleaning Up

After running the demo, you can clean up all created objects:

```
./scripts/cleanup.sh
```

This will:
- Drop all RisingWave sinks, materialized views, and sources
- Drop all StarRocks tables
- Delete and recreate Kafka topics

## Extending the Demo

You can extend the demo by:
- Adding new data sources
- Creating additional materialized views
- Implementing more complex business logic
- Integrating with other systems

## License

No LICENSE file is currently included in this repository.