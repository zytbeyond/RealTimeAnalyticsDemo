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
  - `run_marketing_and_cart_demo.sh`: Interactive demo runner. Verifies AutoMQ (Kafka), RisingWave, and StarRocks connectivity, lets you pick Marketing Campaign Optimization, Cart Conversion Analysis, or both, then prints simulated AI Agent responses to a scripted set of business questions.
  - `generate_marketing_events.py`: Standalone Python generator that produces synthetic marketing events (impressions, clicks, purchases) as JSON lines across 5 predefined campaigns/channels. Prints to stdout by default, or to a file with `--output`; intended to be piped into a Kafka producer.
  - `cleanup.sh`: Drops the RisingWave sinks, materialized views, and sources, drops the StarRocks tables under `ecommerce_analytics`, and deletes/recreates the `marketing-campaigns` and `cart-analytics` Kafka topics.
  - `install_kafka_tools.sh`: Installs OpenJDK, downloads Apache Kafka 3.5.1 client tools into `~/kafka-tools`, adds them to `PATH` via `~/.bashrc`, and installs `kafkacat` and the `kafka-python` pip package.

⚠️ **Note**: `run_marketing_and_cart_demo.sh` checks for and calls four additional flow scripts — `marketing_campaign_demo_flow.sh`, `cart_conversion_demo_flow.sh`, `realistic_marketing_campaign_demo_flow.sh`, and `realistic_cart_conversion_demo_flow.sh` — that are **not included in this repository**. As shipped, running it will exit immediately with an `Error: ... not found` message. You will need to supply those flow scripts yourself (they are responsible for setting up the Kafka topics, RisingWave sources/materialized views, and StarRocks tables, then generating and loading data) before the demo runner will proceed past its startup checks.

## Prerequisites

Before running the demo, you need:

1. **AutoMQ (Kafka)** instance
2. **RisingWave** instance
3. **StarRocks** instance
4. Python 3.6+ (standard library only — `generate_marketing_events.py` has no external dependencies)
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
| `<KAFKA_BROKER>` | Kafka broker address (e.g., `localhost:9092`) | `run_marketing_and_cart_demo.sh`, `cleanup.sh` |
| `<RISINGWAVE_HOST>` | RisingWave host address | `run_marketing_and_cart_demo.sh`, `cleanup.sh` |
| `<RISINGWAVE_PORT>` | RisingWave port | `run_marketing_and_cart_demo.sh`, `cleanup.sh` |
| `<RISINGWAVE_USER>` | RisingWave username | `run_marketing_and_cart_demo.sh`, `cleanup.sh` |
| `<STARROCKS_HOST>` | StarRocks host address | `run_marketing_and_cart_demo.sh`, `cleanup.sh` |
| `<STARROCKS_PORT>` | StarRocks port | `run_marketing_and_cart_demo.sh`, `cleanup.sh` |
| `<STARROCKS_USER>` | StarRocks username | `run_marketing_and_cart_demo.sh`, `cleanup.sh` |
| `<STARROCKS_PASSWORD>` | StarRocks password | `run_marketing_and_cart_demo.sh`, `cleanup.sh` |

Note: the four `<...>` placeholders above are only found in `run_marketing_and_cart_demo.sh` and `cleanup.sh` — the two shell scripts actually shipped in this repo that connect to real services. There is no `<S3_BUCKET>` placeholder in any file currently in the repo.

## Running the Demo

As shipped, `run_marketing_and_cart_demo.sh` checks at startup whether four "flow" scripts exist (`marketing_campaign_demo_flow.sh`, `cart_conversion_demo_flow.sh`, `realistic_marketing_campaign_demo_flow.sh`, `realistic_cart_conversion_demo_flow.sh`). **These are not included in this repository**, so the script exits immediately with an `Error: ... not found` message before it ever runs cleanup, checks AutoMQ/RisingWave/StarRocks connectivity, or prompts for a demo choice.

Once you supply those flow scripts yourself, the intended flow is: `run_marketing_and_cart_demo.sh` runs a cleanup pass, checks connectivity to AutoMQ (Kafka), RisingWave, and StarRocks, then prompts you to pick one of three options:

1. **Marketing Campaign Optimization**: Analyzes marketing campaign performance across channels
2. **Cart Conversion Analysis**: Analyzes cart behavior across devices and traffic sources
3. **Both Demos**: Runs both demos in sequence

For each option, the actual pipeline work — setting up Kafka topics, creating RisingWave sources and materialized views, creating StarRocks tables, and generating/sending event data (e.g. via `generate_marketing_events.py`) — would live inside the missing flow script that `run_marketing_and_cart_demo.sh` calls (e.g. `realistic_marketing_campaign_demo_flow.sh`). After that flow script runs, `run_marketing_and_cart_demo.sh` prints a scripted set of business questions and simulated AI Agent answers based on `$400,000`+ in modeled marketing spend and synthetic cart-conversion data — these responses are hardcoded in the script, not generated live by an LLM.

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