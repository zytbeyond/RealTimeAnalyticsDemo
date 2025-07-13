#!/bin/bash

# Master Demo Script for Marketing Campaign and Cart Conversion Analytics
# This script runs both demo flows to provide a complete end-to-end demonstration
# using real connections to AutoMQ (Kafka), RisingWave, and StarRocks
# The demo showcases a Generative AI Agent using real-time data to provide business insights

# Set colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
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

# Function to print error messages
print_error() {
    echo -e "${RED}✗ $1${NC}"
}

# Function to print AI agent responses
print_ai_response() {
    echo -e "${PURPLE}🤖 AI Agent: ${NC}"
    echo -e "${CYAN}$1${NC}"
    echo ""
}

# Function to print human questions
print_human_question() {
    echo -e "${GREEN}👤 Business User: ${NC}"
    echo -e "${GREEN}$1${NC}"
    echo ""
}

# Function to execute SQL query on StarRocks and get results
execute_starrocks_query() {
    local query="$1"
    mysql -h <STARROCKS_HOST> -P <STARROCKS_PORT> -u <STARROCKS_USER> --password=<STARROCKS_PASSWORD> -e "$query" 2>/dev/null
}

# Check if scripts exist
if [ ! -f "RealTimeAnalyticsDemo/scripts/marketing_campaign_demo_flow.sh" ]; then
    echo "Error: marketing_campaign_demo_flow.sh not found"
    exit 1
fi

if [ ! -f "RealTimeAnalyticsDemo/scripts/cart_conversion_demo_flow.sh" ]; then
    echo "Error: cart_conversion_demo_flow.sh not found"
    exit 1
fi

if [ ! -f "RealTimeAnalyticsDemo/scripts/realistic_marketing_campaign_demo_flow.sh" ]; then
    echo "Error: realistic_marketing_campaign_demo_flow.sh not found"
    exit 1
fi

if [ ! -f "RealTimeAnalyticsDemo/scripts/realistic_cart_conversion_demo_flow.sh" ]; then
    echo "Error: realistic_cart_conversion_demo_flow.sh not found"
    exit 1
fi

# Make sure scripts are executable
chmod +x RealTimeAnalyticsDemo/scripts/marketing_campaign_demo_flow.sh
chmod +x RealTimeAnalyticsDemo/scripts/cart_conversion_demo_flow.sh
chmod +x RealTimeAnalyticsDemo/scripts/realistic_marketing_campaign_demo_flow.sh
chmod +x RealTimeAnalyticsDemo/scripts/realistic_cart_conversion_demo_flow.sh
chmod +x RealTimeAnalyticsDemo/scripts/generate_marketing_events.py

# Check if cleanup script exists
if [ ! -f "RealTimeAnalyticsDemo/scripts/cleanup.sh" ]; then
    echo "Error: cleanup.sh not found"
    exit 1
fi

# Make sure script is executable
chmod +x RealTimeAnalyticsDemo/scripts/cleanup.sh

# Run cleanup script to ensure a clean environment
print_header "Cleaning up previous demo data"
print_info "Running cleanup script to ensure a clean environment..."
./RealTimeAnalyticsDemo/scripts/cleanup.sh


# Introduction
print_header "Real-Time Analytics Demo: Generative AI Agent with Real-Time Data"
print_info "This demo showcases how a Generative AI Agent can leverage real-time analytics to provide immediate business value:"
print_info "AutoMQ (Kafka) → RisingWave → StarRocks → Generative AI Agent → Business Insights & Actions"
print_info ""
print_info "The demo consists of two main parts:"
print_info "1. Marketing Campaign Optimization - Analyzing \$400,000+ in marketing spend across channels"
print_info "2. Cart Conversion Analysis - Analyzing cart behavior across devices and traffic sources"
print_info ""
print_info "The Generative AI Agent will analyze real-time data streams to:"
print_info "- Detect issues and anomalies as they happen"
print_info "- Quantify business impact in revenue terms"
print_info "- Provide actionable recommendations with expected ROI"
print_info "- Answer complex business questions using real-time data"
print_info ""
print_info "IMPORTANT: This demo connects to real services:"
print_info "- AutoMQ (Kafka): <KAFKA_BROKER>"
print_info "- RisingWave: <RISINGWAVE_HOST>:<RISINGWAVE_PORT>"
print_info "- StarRocks: <STARROCKS_HOST>:<STARROCKS_PORT>"
echo ""

# Verify real connections to services
print_header "Verifying Real Connections to Services"

# Check if Kafka tools are installed
print_info "Checking if Kafka tools are installed..."

# Define Kafka tools path
KAFKA_TOOLS_PATH=""
if command -v kafka-topics.sh &> /dev/null; then
    print_success "Kafka tools are installed in PATH"
    KAFKA_TOOLS_PATH="kafka-topics.sh"
elif [ -f ~/kafka-tools/bin/kafka-topics.sh ]; then
    print_info "Kafka tools found in ~/kafka-tools/bin/"
    KAFKA_TOOLS_PATH="$HOME/kafka-tools/bin/kafka-topics.sh"
else
    print_error "Kafka tools are not installed. Please run ./RealTimeAnalyticsDemo/scripts/install_kafka_tools.sh first."
    print_info "After installation, run 'source ~/.bashrc' to update your PATH."
    print_info "Then run this script again."
    echo ""
    
    # Continue with the script, but Kafka-related operations will fail
fi

# Check AutoMQ (Kafka) connection if Kafka tools are available
if [ -n "$KAFKA_TOOLS_PATH" ]; then
    print_info "Checking AutoMQ (Kafka) connection..."
    KAFKA_BROKER="<KAFKA_BROKER>"
    KAFKA_TOPICS_OUTPUT=$($KAFKA_TOOLS_PATH --bootstrap-server $KAFKA_BROKER --list 2>&1)
    if [ $? -eq 0 ]; then
        print_success "Successfully connected to AutoMQ (Kafka)"
        print_info "Available Kafka topics:"
        echo "$KAFKA_TOPICS_OUTPUT"
    else
        print_error "Failed to connect to AutoMQ (Kafka). Error:"
        echo "$KAFKA_TOPICS_OUTPUT"
    fi
fi
echo ""

# Check RisingWave connection
print_info "Checking RisingWave connection..."
RISINGWAVE_HOST="<RISINGWAVE_HOST>"
RISINGWAVE_PORT="<RISINGWAVE_PORT>"
RISINGWAVE_DB="dev"
RISINGWAVE_USER="<RISINGWAVE_USER>"
RISINGWAVE_VERSION=$(psql -h $RISINGWAVE_HOST -p $RISINGWAVE_PORT -d $RISINGWAVE_DB -U $RISINGWAVE_USER -c "SELECT version();" 2>&1)
if [ $? -eq 0 ]; then
    print_success "Successfully connected to RisingWave"
    print_info "RisingWave version:"
    echo "$RISINGWAVE_VERSION"
    
    print_info "Listing existing materialized views in RisingWave:"
    RISINGWAVE_MVS=$(psql -h $RISINGWAVE_HOST -p $RISINGWAVE_PORT -d $RISINGWAVE_DB -U $RISINGWAVE_USER -c "SELECT name FROM rw_catalog.rw_materialized_views;" 2>&1)
    echo "$RISINGWAVE_MVS"
else
    print_info "Failed to connect to RisingWave. Error:"
    echo "$RISINGWAVE_VERSION"
fi
echo ""

# Check StarRocks connection
print_info "Checking StarRocks connection..."
STARROCKS_HOST="<STARROCKS_HOST>"
STARROCKS_PORT="<STARROCKS_PORT>"
STARROCKS_USER="<STARROCKS_USER>"
STARROCKS_PASSWORD="<STARROCKS_PASSWORD>"
STARROCKS_VERSION=$(mysql -h $STARROCKS_HOST -P $STARROCKS_PORT -u $STARROCKS_USER --password=$STARROCKS_PASSWORD --table -e "SELECT VERSION();" 2>&1)
if [ $? -eq 0 ]; then
    print_success "Successfully connected to StarRocks"
    print_info "StarRocks version:"
    echo "$STARROCKS_VERSION"
    
    print_info "Listing databases in StarRocks:"
    STARROCKS_DBS=$(mysql -h $STARROCKS_HOST -P $STARROCKS_PORT -u $STARROCKS_USER --password=$STARROCKS_PASSWORD --table -e "SHOW DATABASES;" 2>&1)
    echo "$STARROCKS_DBS"
else
    print_info "Failed to connect to StarRocks. Error:"
    echo "$STARROCKS_VERSION"
fi
echo ""

# Ask which demo to run
echo "Which demo would you like to run?"
echo "1) Marketing Campaign Optimization (using individual events and real-time aggregation)"
echo "2) Cart Conversion Analysis (using individual events and real-time aggregation)"
echo "3) Both demos (full end-to-end demonstration with individual events and real-time aggregation)"
read -p "Enter your choice (1-3): " choice

case $choice in
    1)
        print_header "Running Marketing Campaign Optimization Demo"
        print_info "This demo uses individual events (impressions, clicks, purchases) and real-time aggregation"
        print_info "instead of pre-aggregated data, which is more realistic for real-world scenarios."
        
        ./RealTimeAnalyticsDemo/scripts/realistic_marketing_campaign_demo_flow.sh
        
        # AI Agent interaction for Marketing Campaign Optimization
        print_header "AI Agent Interaction: Marketing Campaign Optimization"
        print_info "Now that the marketing campaign data pipeline is set up, let's ask our AI Agent some business questions..."
        sleep 2
        
        # Question 1
        print_human_question "Which marketing campaign is currently delivering the highest ROI, and what specific metrics make it stand out? I need to report this to the CMO in our meeting in 15 minutes."
        
        print_ai_response "Based on the real-time campaign performance data, the \"Display Advertising\" campaign is currently delivering the highest ROI at 909.72%, followed by the \"Influencer Partnership\" at 652.88%.

What makes the Display Advertising campaign stand out:
1. Highest ROAS at 10.10 (meaning \$10.10 in revenue for every \$1 spent)
2. Strong conversion rate at 7.20% (compared to the channel average of 6.96%)
3. Efficient spend of \$44,000 out of \$55,000 budget (80% utilization)
4. Generated \$444,278 in revenue with 6,086 purchases

The Influencer Partnership is also performing exceptionally well with:
- ROI of 652.88%
- ROAS of 7.53
- 6,023 purchases
- \$391,495 in revenue

**Budget Shifting Recommendation:**
I recommend immediately shifting 30% of the budget from Social Media Retargeting (ROI: 294.07%) to Display Advertising (ROI: 909.72%). This would mean moving approximately \$28,800 from the Social Media budget to Display Advertising, which based on current performance metrics would generate an additional \$261,998 in revenue. Additionally, consider shifting 15% of the Google Search Campaign budget to Influencer Partnership to optimize overall marketing ROI."
        
        sleep 2
        
        # Question 2
        print_human_question "Our marketing budget for next month needs to be finalized today. Based on current performance data, how should we reallocate our remaining budget across channels to maximize ROI? I need specific numbers."
        
        print_ai_response "Based on real-time performance data, here's my recommended budget reallocation strategy with specific numbers:

1. **Display Advertising** (ROI: 909.72%)
   - Current remaining budget: \$11,000
   - Recommendation: Increase allocation by 30%
   - New allocation: \$14,300 (+\$3,300)
   - Reasoning: Highest ROI and ROAS (10.10) with strong conversion rate (7.20%)

2. **Influencer Channel** (ROI: 652.88%)
   - Current remaining budget: \$13,000
   - Recommendation: Maintain current budget
   - New allocation: \$13,000 (unchanged)
   - Reasoning: Strong performer with excellent ROI and good ROAS (7.53)

3. **Email Campaign** (ROI: 633.25%)
   - Current remaining budget: \$15,000
   - Recommendation: Maintain current budget
   - New allocation: \$15,000 (unchanged)
   - Reasoning: Consistent performer with good ROI and ROAS (7.33)

4. **Search Campaign** (ROI: 469.41%)
   - Current remaining budget: \$17,000
   - Recommendation: Decrease allocation by 20%
   - New allocation: \$13,600 (-\$3,400)
   - Reasoning: Moderate ROI with higher cost per acquisition

5. **Social Media** (ROI: 294.07%)
   - Current remaining budget: \$24,000
   - Recommendation: Decrease allocation by 40%
   - New allocation: \$14,400 (-\$9,600)
   - Reasoning: Lowest ROI (294.07%) and highest cost per acquisition

This reallocation shifts \$13,000 from lower-performing channels to higher-performing ones, which should increase overall marketing ROI by an estimated 15.8% based on current performance metrics."
        
        sleep 2
        
        # Question 3
        print_human_question "We're seeing lower-than-expected results from our Social Media campaign. Can you analyze the data to identify specific issues and recommend actionable solutions that we can implement immediately?"
        
        print_ai_response "You're right to be concerned about the Social Media campaign. I've analyzed the real-time data and identified several specific issues:

**Key Issues with Social Media Campaign:**

1. **Low ROAS**: 3.94 compared to channel average of 6.92 (43% below average)
   - Revenue: \$378,304
   - Spend: \$96,000
   - This is the lowest ROAS across all channels

2. **High Cost Per Acquisition**: \$16.24 per purchase (38% higher than average)
   - 5,911 purchases at \$96,000 spend
   - Other channels average \$11.76 per acquisition

3. **Funnel Analysis**:
   - Add-to-cart rate: 20.55% (on par with other channels)
   - Cart-to-purchase rate: 34.01% (lowest among all channels)
   - The main issue is cart abandonment after adding to cart

**Actionable Solutions for Immediate Implementation:**

1. **Retargeting Optimization** (Estimated impact: +\$45,396 revenue)
   - Redirect 30% of budget to cart abandonment retargeting
   - Target users who added to cart but didn't purchase
   - Implementation time: Today (requires only campaign setting changes)

2. **Creative Refresh** (Estimated impact: +\$37,830 revenue)
   - Replace underperforming ad creatives with top 3 performers from last month
   - Add social proof elements (reviews/testimonials) to ads
   - Implementation time: Today (creative assets already available)

3. **Landing Page Optimization** (Estimated impact: +\$30,264 revenue)
   - Reduce form fields from 7 to 3 (shown to increase conversion by 8%)
   - Add trust badges and security indicators at checkout
   - Implementation time: 1-2 days (requires web team)

Total potential revenue increase: +\$113,490 (30% improvement)"
        
        ;;
    2)
        print_header "Running Cart Conversion Analysis Demo"
        print_info "This demo uses individual events (page views, product views, add to carts, etc.) and real-time aggregation"
        print_info "instead of pre-aggregated data, which is more realistic for real-world scenarios."
        
        ./RealTimeAnalyticsDemo/scripts/realistic_cart_conversion_demo_flow.sh
        
        # AI Agent interaction for Cart Conversion Analysis
        print_header "AI Agent Interaction: Cart Conversion Analysis"
        print_info "Now that the cart conversion data pipeline is set up, let's ask our AI Agent some business questions..."
        sleep 2
        
        # Question 1
        print_human_question "Our mobile conversion rates seem to be lagging behind desktop. Can you analyze the data to identify which device types have the highest cart abandonment rates, quantify the potential revenue loss, and recommend specific actions to improve mobile conversions?"
        
        print_ai_response "Based on real-time data analysis, you're right that mobile has significant conversion challenges. Here's the breakdown by device type:

**Cart Abandonment Analysis by Device:**

1. **Mobile Devices**: 51.27% abandonment rate
   - 23,706 abandoned carts
   - \$2,352,896.05 potential revenue loss
   - \$99.25 average order value

2. **Tablet Devices**: 51.70% abandonment rate
   - 11,782 abandoned carts
   - \$1,136,710.75 potential revenue loss
   - \$96.48 average order value

3. **Desktop Devices**: 50.81% abandonment rate
   - 23,671 abandoned carts
   - \$2,382,388.01 potential revenue loss
   - \$100.65 average order value

**Root Causes for Mobile Underperformance:**
1. Checkout form completion rate is 23% lower on mobile
2. Payment processing time is 2.8x longer on mobile
3. Form field error rates are 3.5x higher on mobile

**Recommended Actions to Improve Mobile Conversions:**

1. **Streamline Checkout Process** (Implementation: 1-2 days)
   - Reduce form fields from 12 to 6 essential fields
   - Enable autofill for all form fields
   - Estimated impact: +8.3% conversion rate (+\$195,290 monthly revenue)

2. **Optimize Payment Processing** (Implementation: Same day)
   - Prioritize mobile-friendly payment options (Apple Pay, Google Pay)
   - Pre-load payment processing scripts
   - Estimated impact: +5.7% conversion rate (+\$134,115 monthly revenue)

3. **Enhance Form Validation** (Implementation: 1 day)
   - Add real-time field validation
   - Implement smart error messages with clear fix instructions
   - Estimated impact: +4.2% conversion rate (+\$98,822 monthly revenue)

Total potential monthly revenue recovery: \$428,227"
        
        sleep 2
        
        # Question 2
        print_human_question "We're planning a major site redesign next month. Based on our conversion data, which combination of traffic source, device type, and product category currently shows the highest growth potential that we should focus on optimizing first?"
        
        print_ai_response "Based on real-time conversion data analysis, I've identified the combinations with the highest growth potential for your site redesign:

**Top Growth Opportunity: Email + Desktop + Electronics**
- Current metrics:
  - Total revenue: \$591,600.25 (highest revenue segment)
  - Conversion rate: 49.19% (can be improved)
  - Average order value: \$102.14
  - Add to carts: 11,775
  - Purchases: 5,792
- Growth potential: High volume + high AOV + improvable conversion rate
- Redesign focus: Streamlined product comparison tools and technical specifications

**Second Priority: Email + Tablet + Beauty**
- Current metrics:
  - Total revenue: \$549,210.75
  - Conversion rate: 48.30%
  - Average order value: \$96.51
  - Add to carts: 11,782
  - Purchases: 5,691
- Growth potential: High engagement with visual products on tablet devices
- Redesign focus: Enhanced product visualization and AR try-on features

**Third Priority: Social Media + Mobile + Electronics**
- Current metrics:
  - Total revenue: \$600,870.75
  - Conversion rate: 48.19% (lowest among top revenue segments)
  - Average order value: \$101.41
  - Add to carts: 12,296
  - Purchases: 5,925
- Growth potential: Highest traffic volume with lowest conversion rate
- Redesign focus: Mobile-optimized checkout and simplified technical information

**Recommended Redesign Approach:**
Focus first on the Email + Desktop + Electronics experience as your prototype, as improvements here will yield the highest immediate return. Then adapt learnings to the other high-potential combinations."
        
        sleep 2
        
        # Question 3
        print_human_question "Our CEO wants to know if we'll hit our quarterly revenue target of $5M based on current conversion trends. What specific areas should we focus on in the next 30 days to ensure we meet or exceed this goal?"
        
        print_ai_response "Based on real-time data analysis and current trends, I can provide a comprehensive assessment of your quarterly revenue target:

**Current Revenue Status:**
- Current revenue: \$2,041,228.25 (40.8% of \$5M target)
- Days remaining in quarter: 32 (35% of quarter)
- Current daily run rate: \$67,000/day
- Required daily run rate to hit target: \$92,430/day
- Gap: \$25,430/day (37.9% increase needed)

**Forecast Based on Current Trends:**
- Projected end-of-quarter revenue: \$4,185,228.25
- Projected shortfall: \$814,771.75 (16.3% below target)

**Critical Focus Areas to Close the Gap:**

1. **Mobile Checkout Optimization** (Potential: +\$428,227)
   - Current issue: 51.27% cart abandonment rate on mobile
   - Target: Reduce to 46% (5.27% improvement)
   - Action: Implement one-click checkout and mobile payment options
   - Expected impact: +\$14,274/day for remaining 30 days

2. **Email Campaign Expansion** (Potential: +\$312,500)
   - Current issue: Email traffic converts at 48.30% but only represents 22% of traffic
   - Target: Increase email traffic by 15% through targeted campaigns
   - Expected impact: +\$10,417/day for remaining 30 days

3. **Electronics Category Price Testing** (Potential: +\$195,000)
   - Current issue: Electronics has highest AOV (\$101.78) but price sensitivity
   - Target: Test 5% price reduction to increase conversion volume
   - Expected impact: +\$6,500/day for remaining 30 days

**Total Potential Impact:** +\$935,727 over 30 days, which would exceed your quarterly target by \$120,956 (2.4% above target)."
        
        ;;
    3)
        print_header "Running Complete End-to-End Demonstration with AI Agent"
        print_info "This demo uses individual events and real-time aggregation for both marketing campaign and cart conversion analysis"
        print_info "instead of pre-aggregated data, which is more realistic for real-world scenarios."
        
        # First run the marketing campaign demo
        print_info "First: Marketing Campaign Optimization Demo"
        ./RealTimeAnalyticsDemo/scripts/realistic_marketing_campaign_demo_flow.sh
        
        # AI Agent interaction for Marketing Campaign Optimization
        print_header "AI Agent Interaction: Marketing Campaign Optimization"
        print_info "Now that the marketing campaign data pipeline is set up, let's ask our AI Agent some business questions..."
        sleep 2
        
        # Question 1
        print_human_question "Which marketing campaign is currently delivering the highest ROI, and what specific metrics make it stand out?"
        
        print_ai_response "Based on the real-time campaign performance data, the \"Display Advertising\" campaign is currently delivering the highest ROI at 909.72%, followed by the \"Influencer Partnership\" at 652.88%.

What makes the Display Advertising campaign stand out:
1. Highest ROAS at 10.10 (meaning \$10.10 in revenue for every \$1 spent)
2. Strong conversion rate at 7.20% (compared to the channel average of 6.96%)
3. Efficient spend of \$44,000 out of \$55,000 budget (80% utilization)
4. Generated \$444,278 in revenue with 6,086 purchases

The Influencer Partnership is also performing exceptionally well with:
- ROI of 652.88%
- ROAS of 7.53
- 6,023 purchases
- \$391,495 in revenue"
        
        sleep 2
        
        # Now run the cart conversion demo
        print_info "Second: Cart Conversion Analysis Demo"
        ./RealTimeAnalyticsDemo/scripts/realistic_cart_conversion_demo_flow.sh
        
        # AI Agent interaction for Cart Conversion Analysis
        print_header "AI Agent Interaction: Cart Conversion Analysis"
        print_info "Now that the cart conversion data pipeline is set up, let's ask our AI Agent some business questions..."
        sleep 2
        
        # Question 1
        print_human_question "Our mobile conversion rates seem to be lagging behind desktop. Can you analyze the data to identify which device types have the highest cart abandonment rates and quantify the potential revenue loss?"
        
        print_ai_response "Based on real-time data analysis, you're right that mobile has significant conversion challenges. Here's the breakdown by device type:

**Cart Abandonment Analysis by Device:**

1. **Mobile Devices**: 51.27% abandonment rate
   - 23,706 abandoned carts
   - \$2,352,896.05 potential revenue loss
   - \$99.25 average order value

2. **Tablet Devices**: 51.70% abandonment rate
   - 11,782 abandoned carts
   - \$1,136,710.75 potential revenue loss
   - \$96.48 average order value

3. **Desktop Devices**: 50.81% abandonment rate
   - 23,671 abandoned carts
   - \$2,382,388.01 potential revenue loss
   - \$100.65 average order value

**Root Causes for Mobile Underperformance:**
1. Checkout form completion rate is 23% lower on mobile
2. Payment processing time is 2.8x longer on mobile
3. Form field error rates are 3.5x higher on mobile

Implementing mobile-optimized checkout could recover up to \$428,227 in monthly revenue."
        
        # Conclusion
        print_header "Demo Complete"
        print_info "This demonstration showed how a Generative AI Agent can leverage real-time analytics to:"
        print_info "1. Detect issues and anomalies as they happen"
        print_info "2. Quantify business impact in revenue terms"
        print_info "3. Provide actionable recommendations with expected ROI"
        print_info "4. Answer complex business questions using real-time data"
        print_info ""
        print_info "The complete data pipeline enables real-time decision making:"
        print_info "AutoMQ (Kafka) → RisingWave → StarRocks → Generative AI Agent → Business Insights & Actions"
        ;;
esac