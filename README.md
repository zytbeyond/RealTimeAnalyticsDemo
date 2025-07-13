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

## Repository Structure

- `scripts/`: Contains all the scripts needed to run the demo
  - `run_marketing_and_cart_demo.sh`: Main script that runs both demo flows
  - `marketing_campaign_demo_flow.sh`: Script for the marketing campaign optimization demo
  - `cart_conversion_demo_flow.sh`: Script for the cart conversion analysis demo
  - `realistic_marketing_campaign_demo_flow.sh`: Script for the realistic marketing campaign demo
  - `realistic_cart_conversion_demo_flow.sh`: Script for the realistic cart conversion demo
  - `generate_marketing_events.py`: Python script to generate marketing events
  - `cleanup.sh`: Script to clean up all objects created by the demo
  - `install_kafka_tools.sh`: Script to install Kafka tools

## Prerequisites

Before running the demo, you need:

1. **AutoMQ (Kafka)** instance
2. **RisingWave** instance
3. **StarRocks** instance
4. Python 3.6+ with required packages
5. Kafka tools (can be installed using the provided script)

## Setup Instructions

1. Clone this repository:
   ```
   git clone https://github.com/yourusername/RealTimeAnalyticsDemo.git
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
| `<KAFKA_BROKER>` | Kafka broker address (e.g., `localhost:9092`) | `run_marketing_and_cart_demo.sh`, `marketing_campaign_demo_flow.sh`, `cart_conversion_demo_flow.sh`, `realistic_marketing_campaign_demo_flow.sh`, `realistic_cart_conversion_demo_flow.sh`, `cleanup.sh` |
| `<RISINGWAVE_HOST>` | RisingWave host address | `run_marketing_and_cart_demo.sh`, `marketing_campaign_demo_flow.sh`, `cart_conversion_demo_flow.sh`, `realistic_marketing_campaign_demo_flow.sh`, `realistic_cart_conversion_demo_flow.sh`, `cleanup.sh` |
| `<RISINGWAVE_PORT>` | RisingWave port | `run_marketing_and_cart_demo.sh`, `marketing_campaign_demo_flow.sh`, `cart_conversion_demo_flow.sh`, `realistic_marketing_campaign_demo_flow.sh`, `realistic_cart_conversion_demo_flow.sh`, `cleanup.sh` |
| `<RISINGWAVE_USER>` | RisingWave username | `run_marketing_and_cart_demo.sh`, `marketing_campaign_demo_flow.sh`, `cart_conversion_demo_flow.sh`, `realistic_marketing_campaign_demo_flow.sh`, `realistic_cart_conversion_demo_flow.sh`, `cleanup.sh` |
| `<STARROCKS_HOST>` | StarRocks host address | `run_marketing_and_cart_demo.sh`, `marketing_campaign_demo_flow.sh`, `cart_conversion_demo_flow.sh`, `realistic_marketing_campaign_demo_flow.sh`, `realistic_cart_conversion_demo_flow.sh`, `cleanup.sh` |
| `<STARROCKS_PORT>` | StarRocks port | `run_marketing_and_cart_demo.sh`, `marketing_campaign_demo_flow.sh`, `cart_conversion_demo_flow.sh`, `realistic_marketing_campaign_demo_flow.sh`, `realistic_cart_conversion_demo_flow.sh`, `cleanup.sh` |
| `<STARROCKS_USER>` | StarRocks username | `run_marketing_and_cart_demo.sh`, `marketing_campaign_demo_flow.sh`, `cart_conversion_demo_flow.sh`, `realistic_marketing_campaign_demo_flow.sh`, `realistic_cart_conversion_demo_flow.sh`, `cleanup.sh` |
| `<STARROCKS_PASSWORD>` | StarRocks password | `run_marketing_and_cart_demo.sh`, `marketing_campaign_demo_flow.sh`, `cart_conversion_demo_flow.sh`, `realistic_marketing_campaign_demo_flow.sh`, `realistic_cart_conversion_demo_flow.sh`, `cleanup.sh` |
| `<S3_BUCKET>` | S3 bucket name | `marketing_campaign_demo_flow.sh`, `cart_conversion_demo_flow.sh`, `realistic_marketing_campaign_demo_flow.sh`, `realistic_cart_conversion_demo_flow.sh` |

## Running the Demo

The demo provides three options:

1. **Marketing Campaign Optimization**: Analyzes marketing campaign performance across channels
2. **Cart Conversion Analysis**: Analyzes cart behavior across devices and traffic sources
3. **Both Demos**: Runs both demos in sequence

Each demo:
1. Sets up Kafka topics
2. Creates RisingWave sources and materialized views
3. Creates StarRocks tables and views
4. Generates and sends data to Kafka
5. Verifies data flow through the system
6. Queries the data to generate business insights
7. Simulates AI Agent responses to business questions

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

This project is licensed under the MIT License - see the LICENSE file for details.