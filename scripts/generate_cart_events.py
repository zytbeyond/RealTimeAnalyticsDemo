#!/usr/bin/env python3
"""
Cart Conversion Events Generator for Real-Time Analytics Demo
This script generates individual cart/browsing funnel events (page views,
product views, add-to-cart, checkout starts, purchases) that will be sent to
Kafka for real-time processing by RisingWave.

It mirrors the structure and CLI of generate_marketing_events.py so both
generators can be driven the same way by the demo flow scripts.
"""

import json
import random
import time
import uuid
from datetime import datetime, timedelta
import argparse

# Device types and their distribution
DEVICES = ["Desktop", "Mobile", "Tablet"]
DEVICE_WEIGHTS = [0.40, 0.40, 0.20]

# Traffic sources and their distribution
TRAFFIC_SOURCES = ["Organic Search", "Paid Search", "Social Media", "Email", "Direct", "Referral"]
TRAFFIC_SOURCE_WEIGHTS = [0.22, 0.20, 0.18, 0.16, 0.14, 0.10]

# Product categories and their distribution
PRODUCT_CATEGORIES = ["Electronics", "Clothing", "Home & Garden", "Beauty", "Sports", "Toys"]
CATEGORY_WEIGHTS = [0.28, 0.22, 0.18, 0.14, 0.10, 0.08]

# Base price per category (randomized per-event within a range around this)
BASE_PRICES = {
    "Electronics": 120,
    "Clothing": 60,
    "Home & Garden": 80,
    "Beauty": 40,
    "Sports": 70,
    "Toys": 35,
}

# Funnel conversion probabilities between consecutive stages
PRODUCT_VIEW_RATE = 0.60     # page_view -> product_view
ADD_TO_CART_RATE = 0.35      # product_view -> add_to_cart
CHECKOUT_START_RATE = 0.50   # add_to_cart -> checkout_start
PURCHASE_RATE = 0.55         # checkout_start -> purchase


def generate_session_id():
    """Generate a random session ID"""
    return str(uuid.uuid4())


def generate_user_id():
    """Generate a random user ID. Roughly half of sessions are anonymous."""
    if random.random() < 0.5:
        return None
    return str(uuid.uuid4())


def generate_product_id(product_category):
    """Generate a random product ID scoped to its category"""
    slug = product_category.lower().replace(" & ", "-").replace(" ", "-")
    return f"{slug}-{random.randint(1000, 9999)}"


def generate_page_view_event(session_id, user_id, device, traffic_source,
                              product_category, product_id, price, quantity, timestamp):
    """Generate the first event of a session's funnel: a page view"""
    return {
        "event_type": "page_view",
        "event_id": str(uuid.uuid4()),
        "timestamp": timestamp.isoformat(),
        "session_id": session_id,
        "user_id": user_id,
        "device_type": device,
        "traffic_source": traffic_source,
        "product_id": product_id,
        "product_category": product_category,
        "product_price": price,
        "quantity": quantity,
        "cart_id": None,
        "checkout_id": None,
        "purchase_id": None,
        "revenue": None,
    }


def generate_product_view_event(page_view_event, timestamp):
    """Generate a product view event based on a preceding page view"""
    event = dict(page_view_event)
    event["event_type"] = "product_view"
    event["event_id"] = str(uuid.uuid4())
    event["timestamp"] = timestamp.isoformat()
    return event


def generate_add_to_cart_event(product_view_event, timestamp):
    """Generate an add-to-cart event based on a preceding product view"""
    event = dict(product_view_event)
    event["event_type"] = "add_to_cart"
    event["event_id"] = str(uuid.uuid4())
    event["timestamp"] = timestamp.isoformat()
    event["cart_id"] = f"cart-{event['session_id']}"
    return event


def generate_checkout_start_event(add_to_cart_event, timestamp):
    """Generate a checkout start event based on a preceding add-to-cart"""
    event = dict(add_to_cart_event)
    event["event_type"] = "checkout_start"
    event["event_id"] = str(uuid.uuid4())
    event["timestamp"] = timestamp.isoformat()
    event["checkout_id"] = f"checkout-{event['session_id']}"
    return event


def generate_purchase_event(checkout_start_event, timestamp):
    """Generate a purchase event based on a preceding checkout start"""
    event = dict(checkout_start_event)
    event["event_type"] = "purchase"
    event["event_id"] = str(uuid.uuid4())
    event["timestamp"] = timestamp.isoformat()
    event["purchase_id"] = f"purchase-{event['session_id']}"
    event["revenue"] = round(event["product_price"] * event["quantity"], 2)
    return event


def generate_funnel_events(current_time):
    """Generate one session's worth of funnel events (1-5 events) starting at current_time"""
    session_id = generate_session_id()
    user_id = generate_user_id()
    device = random.choices(DEVICES, weights=DEVICE_WEIGHTS)[0]
    traffic_source = random.choices(TRAFFIC_SOURCES, weights=TRAFFIC_SOURCE_WEIGHTS)[0]
    product_category = random.choices(PRODUCT_CATEGORIES, weights=CATEGORY_WEIGHTS)[0]
    product_id = generate_product_id(product_category)
    price = round(BASE_PRICES[product_category] * (1 + random.uniform(-0.2, 0.3)), 2)
    quantity = random.randint(1, 3)

    events = []

    page_view = generate_page_view_event(
        session_id, user_id, device, traffic_source, product_category,
        product_id, price, quantity, current_time
    )
    events.append(page_view)

    # Determine if the page view leads to a product view
    if random.random() < PRODUCT_VIEW_RATE:
        t = current_time + timedelta(seconds=random.randint(2, 20))
        product_view = generate_product_view_event(page_view, t)
        events.append(product_view)

        # Determine if the product view leads to an add-to-cart
        if random.random() < ADD_TO_CART_RATE:
            t = t + timedelta(seconds=random.randint(5, 60))
            add_to_cart = generate_add_to_cart_event(product_view, t)
            events.append(add_to_cart)

            # Determine if the cart leads to checkout
            if random.random() < CHECKOUT_START_RATE:
                t = t + timedelta(minutes=random.randint(1, 5))
                checkout_start = generate_checkout_start_event(add_to_cart, t)
                events.append(checkout_start)

                # Determine if checkout leads to purchase
                if random.random() < PURCHASE_RATE:
                    t = t + timedelta(minutes=random.randint(1, 10))
                    purchase = generate_purchase_event(checkout_start, t)
                    events.append(purchase)

    return events


def generate_events(duration_seconds=60, events_per_second=10):
    """Generate a stream of cart funnel events for the specified duration"""
    start_time = datetime.now()
    end_time = start_time + timedelta(seconds=duration_seconds)
    current_time = start_time

    while current_time < end_time:
        # Generate multiple sessions per second
        for _ in range(events_per_second):
            for event in generate_funnel_events(current_time):
                yield json.dumps(event)

        # Move time forward
        current_time += timedelta(seconds=1)
        time.sleep(0.1)  # Slow down generation for demo purposes


def main():
    parser = argparse.ArgumentParser(description='Generate cart conversion funnel events for Kafka')
    parser.add_argument('--duration', type=int, default=60, help='Duration in seconds to generate events')
    parser.add_argument('--rate', type=int, default=10, help='Sessions per second to generate')
    parser.add_argument('--output', type=str, help='Output file (if not specified, prints to stdout)')

    args = parser.parse_args()

    count = 0
    if args.output:
        with open(args.output, 'w') as f:
            for event in generate_events(args.duration, args.rate):
                f.write(f"{event}\n")
                count += 1
        print(f"Generated {count} events to {args.output}")
    else:
        for event in generate_events(args.duration, args.rate):
            print(event)
            count += 1


if __name__ == "__main__":
    main()
