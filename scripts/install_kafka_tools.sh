#!/bin/bash

# Install Kafka tools for RealTimeAnalyticsDemo
# This script installs the necessary Kafka tools to interact with AutoMQ

# Set colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
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

print_header "Installing Kafka Tools"

# Check if we have sudo access
HAS_SUDO=false
if command -v sudo &> /dev/null; then
    HAS_SUDO=true
fi

# Install Java if not already installed
print_info "Checking for Java..."
if ! command -v java &> /dev/null; then
    print_info "Java not found. Installing OpenJDK..."
    if [ "$HAS_SUDO" = true ]; then
        sudo apt-get update
        sudo apt-get install -y openjdk-11-jdk
    else
        apt-get update
        apt-get install -y openjdk-11-jdk
    fi
    print_success "Java installed"
else
    print_success "Java is already installed"
    java -version
fi

# Create a directory for Kafka tools
print_info "Creating directory for Kafka tools..."
mkdir -p ~/kafka-tools
cd ~/kafka-tools

# Download Kafka
print_info "Downloading Kafka..."
KAFKA_VERSION="3.5.1"
SCALA_VERSION="2.13"
# Use the Apache archive mirror which is more reliable
KAFKA_URL="https://archive.apache.org/dist/kafka/${KAFKA_VERSION}/kafka_${SCALA_VERSION}-${KAFKA_VERSION}.tgz"

if ! command -v wget &> /dev/null; then
    print_info "Installing wget..."
    if [ "$HAS_SUDO" = true ]; then
        sudo apt-get update
        sudo apt-get install -y wget
    else
        apt-get update
        apt-get install -y wget
    fi
fi

print_info "Downloading from: $KAFKA_URL"
if ! wget -q $KAFKA_URL -O kafka.tgz; then
    print_error "Failed to download Kafka from $KAFKA_URL"
    print_info "Please check your internet connection and try again."
    exit 1
fi

# Verify the download size
FILE_SIZE=$(stat -c%s kafka.tgz)
if [ "$FILE_SIZE" -lt 10000000 ]; then  # 10MB minimum size
    print_error "Downloaded file is too small ($FILE_SIZE bytes). Download may be incomplete."
    print_info "Please try running the script again."
    exit 1
fi

print_success "Kafka downloaded successfully ($(du -h kafka.tgz | cut -f1))"

# Extract Kafka
print_info "Extracting Kafka..."
if ! tar -xzf kafka.tgz; then
    print_error "Failed to extract Kafka. The download may be incomplete or corrupted."
    print_info "Please try running the script again."
    exit 1
fi

if [ ! -d "kafka_${SCALA_VERSION}-${KAFKA_VERSION}" ]; then
    print_error "Kafka directory not found after extraction."
    print_info "Expected directory: kafka_${SCALA_VERSION}-${KAFKA_VERSION}"
    print_info "Please try running the script again."
    exit 1
fi

mv kafka_${SCALA_VERSION}-${KAFKA_VERSION}/* .
rm -rf kafka_${SCALA_VERSION}-${KAFKA_VERSION}
rm kafka.tgz
print_success "Kafka extracted"

# Add Kafka tools to PATH
print_info "Adding Kafka tools to PATH..."

# Check if Kafka tools exist
if [ ! -f ~/kafka-tools/bin/kafka-topics.sh ]; then
    print_error "kafka-topics.sh not found in ~/kafka-tools/bin/"
    print_info "The Kafka extraction may have failed or the directory structure is different."
    print_info "Please try running the script again."
    exit 1
fi

# Add Kafka tools directory to PATH in .bashrc
if ! grep -q "export PATH=\"\$HOME/kafka-tools/bin:\$PATH\"" ~/.bashrc; then
    echo 'export PATH="$HOME/kafka-tools/bin:$PATH"' >> ~/.bashrc
    print_success "Added Kafka tools directory to PATH in ~/.bashrc"
else
    print_success "Kafka tools directory already in PATH"
fi

# Export PATH for current session
export PATH="$HOME/kafka-tools/bin:$PATH"

# Verify the tools are in PATH
print_info "Verifying Kafka tools are in PATH..."
if ! which kafka-topics.sh &> /dev/null; then
    print_error "Failed to add kafka-topics.sh to PATH"
    print_info "Please try running the script again."
    exit 1
fi

print_success "Kafka tools added to PATH"

# Install kafkacat (kcat) for additional Kafka tools
print_info "Installing kafkacat (kcat)..."
if [ "$HAS_SUDO" = true ]; then
    sudo apt-get install -y kafkacat
else
    apt-get install -y kafkacat
fi
print_success "kafkacat installed"

# Install Python Kafka client
print_info "Installing Python Kafka client..."
pip install kafka-python
print_success "Python Kafka client installed"

print_header "Kafka Tools Installation Complete"

# Final verification
print_info "Performing final verification..."

# Check if kafka-topics.sh is in PATH
if command -v kafka-topics.sh &> /dev/null; then
    print_success "kafka-topics.sh is in PATH"
    KAFKA_VERSION_OUTPUT=$(kafka-topics.sh --version 2>&1)
    if [[ "$KAFKA_VERSION_OUTPUT" == *"version"* ]]; then
        print_success "kafka-topics.sh is working: $KAFKA_VERSION_OUTPUT"
    else
        print_info "kafka-topics.sh found but may not be working correctly"
        print_info "Output: $KAFKA_VERSION_OUTPUT"
        
        # Try running with full path
        FULL_PATH_OUTPUT=$(~/kafka-tools/bin/kafka-topics.sh --version 2>&1)
        print_info "Trying with full path: $FULL_PATH_OUTPUT"
    fi
else
    print_error "kafka-topics.sh is not in PATH"
    print_info "You need to run 'source ~/.bashrc' or restart your shell"
    
    # Try running with full path
    if [ -f ~/kafka-tools/bin/kafka-topics.sh ]; then
        FULL_PATH_OUTPUT=$(~/kafka-tools/bin/kafka-topics.sh --version 2>&1)
        print_info "Trying with full path: $FULL_PATH_OUTPUT"
    fi
fi

print_success "The following Kafka tools are now available:"
print_info "- kafka-topics.sh: For managing Kafka topics"
print_info "- kafka-console-producer.sh: For sending messages to Kafka topics"
print_info "- kafka-console-consumer.sh: For consuming messages from Kafka topics"
print_info "- kafkacat: A versatile command-line Kafka producer and consumer"
print_info "- kafka-python: Python client for Kafka"

print_info "IMPORTANT: You MUST run 'source ~/.bashrc' or restart your shell to update your PATH"
print_info "After that, verify installation with: kafka-topics.sh --version"