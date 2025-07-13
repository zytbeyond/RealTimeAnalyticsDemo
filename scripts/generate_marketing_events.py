#!/usr/bin/env python3
"""
Marketing Events Generator for Real-Time Analytics Demo
This script generates individual marketing events (impressions, clicks, purchases)
that will be sent to Kafka for real-time processing by RisingWave.
"""

import json
import random
import time
import uuid
from datetime import datetime, timedelta
import argparse

# Campaign definitions
CAMPAIGNS = [
    {
        "campaign_id": "CAMP-001",
        "campaign_name": "Summer Sale Email Campaign",
        "channel": "Email",
        "budget": 75000,
        "spend_rate": 2500,  # spend per day
        "ctr": 0.15,         # click-through rate (15%)
        "cvr": 0.075,        # conversion rate (7.5%)
        "aov": 70.0          # average order value
    },
    {
        "campaign_id": "CAMP-002",
        "campaign_name": "Social Media Retargeting",
        "channel": "Social Media",
        "budget": 120000,
        "spend_rate": 4000,
        "ctr": 0.09,
        "cvr": 0.053,
        "aov": 70.0
    },
    {
        "campaign_id": "CAMP-003",
        "campaign_name": "Google Search Campaign",
        "channel": "Search",
        "budget": 85000,
        "spend_rate": 2800,
        "ctr": 0.20,
        "cvr": 0.097,
        "aov": 70.0
    },
    {
        "campaign_id": "CAMP-004",
        "campaign_name": "Influencer Partnership",
        "channel": "Influencer",
        "budget": 65000,
        "spend_rate": 2200,
        "ctr": 0.07,
        "cvr": 0.043,
        "aov": 70.0
    },
    {
        "campaign_id": "CAMP-005",
        "campaign_name": "Display Advertising",
        "channel": "Display",
        "budget": 55000,
        "spend_rate": 1800,
        "ctr": 0.03,
        "cvr": 0.044,
        "aov": 70.0
    }
]

# Device types and their distribution
DEVICES = ["Mobile", "Desktop", "Tablet"]
DEVICE_WEIGHTS = [0.55, 0.35, 0.10]  # 55% Mobile, 35% Desktop, 10% Tablet

# Product categories and their distribution
PRODUCT_CATEGORIES = ["Electronics", "Clothing", "Home & Garden", "Beauty", "Sports"]
CATEGORY_WEIGHTS = [0.30, 0.25, 0.20, 0.15, 0.10]

def generate_user_id():
    """Generate a random user ID"""
    return f"user-{uuid.uuid4().hex[:8]}"

def generate_impression_event(campaign, timestamp):
    """Generate an impression event"""
    device = random.choices(DEVICES, weights=DEVICE_WEIGHTS)[0]
    
    return {
        "event_type": "impression",
        "event_id": str(uuid.uuid4()),
        "timestamp": timestamp.isoformat(),
        "campaign_id": campaign["campaign_id"],
        "campaign_name": campaign["campaign_name"],
        "channel": campaign["channel"],
        "user_id": generate_user_id(),
        "device_type": device,
        "cost": round(campaign["spend_rate"] / (1000 + random.randint(-100, 100)), 4)  # Cost per impression varies slightly
    }

def generate_click_event(impression_event):
    """Generate a click event based on an impression"""
    # Click happens a few seconds after impression
    click_timestamp = datetime.fromisoformat(impression_event["timestamp"]) + timedelta(seconds=random.randint(1, 30))
    
    return {
        "event_type": "click",
        "event_id": str(uuid.uuid4()),
        "timestamp": click_timestamp.isoformat(),
        "campaign_id": impression_event["campaign_id"],
        "campaign_name": impression_event["campaign_name"],
        "channel": impression_event["channel"],
        "user_id": impression_event["user_id"],
        "device_type": impression_event["device_type"],
        "impression_id": impression_event["event_id"],
        "cost": round(impression_event["cost"] * 5, 4)  # CPC is higher than CPM
    }

def generate_purchase_event(click_event):
    """Generate a purchase event based on a click"""
    # Purchase happens a few minutes after click
    purchase_timestamp = datetime.fromisoformat(click_event["timestamp"]) + timedelta(minutes=random.randint(1, 15))
    product_category = random.choices(PRODUCT_CATEGORIES, weights=CATEGORY_WEIGHTS)[0]
    
    # Base price varies by category
    base_prices = {
        "Electronics": 120,
        "Clothing": 60,
        "Home & Garden": 80,
        "Beauty": 40,
        "Sports": 70
    }
    
    # Add some randomness to the price
    price = base_prices[product_category] * (1 + random.uniform(-0.2, 0.3))
    
    return {
        "event_type": "purchase",
        "event_id": str(uuid.uuid4()),
        "timestamp": purchase_timestamp.isoformat(),
        "campaign_id": click_event["campaign_id"],
        "campaign_name": click_event["campaign_name"],
        "channel": click_event["channel"],
        "user_id": click_event["user_id"],
        "device_type": click_event["device_type"],
        "click_id": click_event["event_id"],
        "product_category": product_category,
        "revenue": round(price, 2)
    }

def generate_events(duration_seconds=60, events_per_second=10):
    """Generate a stream of events for the specified duration"""
    start_time = datetime.now()
    end_time = start_time + timedelta(seconds=duration_seconds)
    current_time = start_time
    
    while current_time < end_time:
        # Generate multiple events per second
        for _ in range(events_per_second):
            # Select a random campaign
            campaign = random.choice(CAMPAIGNS)
            
            # Generate an impression event
            impression = generate_impression_event(campaign, current_time)
            yield json.dumps(impression)
            
            # Determine if the impression leads to a click based on CTR
            if random.random() < campaign["ctr"]:
                click = generate_click_event(impression)
                yield json.dumps(click)
                
                # Determine if the click leads to a purchase based on CVR
                if random.random() < campaign["cvr"]:
                    purchase = generate_purchase_event(click)
                    yield json.dumps(purchase)
        
        # Move time forward
        current_time += timedelta(seconds=1)
        time.sleep(0.1)  # Slow down generation for demo purposes

def main():
    parser = argparse.ArgumentParser(description='Generate marketing events for Kafka')
    parser.add_argument('--duration', type=int, default=60, help='Duration in seconds to generate events')
    parser.add_argument('--rate', type=int, default=10, help='Events per second to generate')
    parser.add_argument('--output', type=str, help='Output file (if not specified, prints to stdout)')
    
    args = parser.parse_args()
    
    if args.output:
        with open(args.output, 'w') as f:
            for event in generate_events(args.duration, args.rate):
                f.write(f"{event}\n")
    else:
        for event in generate_events(args.duration, args.rate):
            print(event)

if __name__ == "__main__":
    main()