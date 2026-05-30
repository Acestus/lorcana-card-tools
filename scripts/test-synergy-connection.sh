#!/bin/bash

# Script to test network connectivity for Synergy KVM setup
# Usage: ./test-synergy-connection.sh [OPTIONS]

# Default target host (Synergy server/client)
TARGET_HOST="192.168.8.241"
SYNERGY_PORT=24800
VERBOSE=false
QUICK_TEST=false

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to show usage
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --host, -h <ip>      Target host IP (default: $TARGET_HOST)"
    echo "  --port, -p <port>    Synergy port to test (default: $SYNERGY_PORT)"
    echo "  --verbose, -v        Show detailed output"
    echo "  --quick, -q          Run quick tests only"
    echo "  --help               Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                           # Test default host"
    echo "  $0 --host 192.168.1.100     # Test specific IP"
    echo "  $0 --verbose                # Detailed output"
    echo "  $0 --quick                  # Quick connectivity test only"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --host|-h)
            TARGET_HOST="$2"
            shift 2
            ;;
        --port|-p)
            SYNERGY_PORT="$2"
            shift 2
            ;;
        --verbose|-v)
            VERBOSE=true
            shift
            ;;
        --quick|-q)
            QUICK_TEST=true
            shift
            ;;
        --help)
            show_usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Function to print status messages
print_status() {
    local status=$1
    local message=$2
    case $status in
        "INFO")
            echo -e "${BLUE}[INFO]${NC} $message"
            ;;
        "SUCCESS")
            echo -e "${GREEN}[✓]${NC} $message"
            ;;
        "WARNING")
            echo -e "${YELLOW}[!]${NC} $message"
            ;;
        "ERROR")
            echo -e "${RED}[✗]${NC} $message"
            ;;
    esac
}

# Function to test basic ping connectivity
test_ping() {
    print_status "INFO" "Testing basic ping connectivity..."
    
    if ping -c 4 -W 2 "$TARGET_HOST" >/dev/null 2>&1; then
        # Get average ping time
        avg_time=$(ping -c 4 -W 2 "$TARGET_HOST" 2>/dev/null | tail -1 | awk -F'/' '{print $5}')
        print_status "SUCCESS" "Host $TARGET_HOST is reachable (avg: ${avg_time}ms)"
        return 0
    else
        print_status "ERROR" "Host $TARGET_HOST is not reachable via ping"
        return 1
    fi
}

# Function to test port connectivity
test_port() {
    local port=$1
    local service_name=$2
    
    print_status "INFO" "Testing port $port ($service_name)..."
    
    if command -v nc >/dev/null 2>&1; then
        if timeout 5 nc -z "$TARGET_HOST" "$port" 2>/dev/null; then
            print_status "SUCCESS" "Port $port ($service_name) is open and accessible"
            return 0
        else
            print_status "ERROR" "Port $port ($service_name) is not accessible"
            return 1
        fi
    elif command -v telnet >/dev/null 2>&1; then
        if timeout 5 bash -c "</dev/tcp/$TARGET_HOST/$port" 2>/dev/null; then
            print_status "SUCCESS" "Port $port ($service_name) is open and accessible"
            return 0
        else
            print_status "ERROR" "Port $port ($service_name) is not accessible"
            return 1
        fi
    else
        print_status "WARNING" "Neither nc (netcat) nor telnet available for port testing"
        return 2
    fi
}

# Function to test network latency and quality
test_network_quality() {
    print_status "INFO" "Testing network quality (10 pings)..."
    
    local ping_output
    ping_output=$(ping -c 10 -i 0.2 "$TARGET_HOST" 2>/dev/null)
    
    if [[ $? -eq 0 ]]; then
        local packet_loss=$(echo "$ping_output" | grep "packet loss" | awk '{print $6}')
        local avg_time=$(echo "$ping_output" | tail -1 | awk -F'/' '{print $5}')
        local min_time=$(echo "$ping_output" | tail -1 | awk -F'/' '{print $4}')
        local max_time=$(echo "$ping_output" | tail -1 | awk -F'/' '{print $6}')
        
        print_status "SUCCESS" "Network quality test completed"
        echo "    Packet Loss: $packet_loss"
        echo "    Min/Avg/Max: ${min_time}/${avg_time}/${max_time} ms"
        
        # Evaluate network quality
        local avg_int=$(echo "$avg_time" | cut -d'.' -f1)
        if [[ $avg_int -lt 5 ]]; then
            print_status "SUCCESS" "Excellent network quality (< 5ms average)"
        elif [[ $avg_int -lt 20 ]]; then
            print_status "SUCCESS" "Good network quality (< 20ms average)"
        elif [[ $avg_int -lt 100 ]]; then
            print_status "WARNING" "Moderate network quality (< 100ms average)"
        else
            print_status "WARNING" "Poor network quality (> 100ms average)"
        fi
        
        return 0
    else
        print_status "ERROR" "Failed to test network quality"
        return 1
    fi
}

# Function to test SSH connectivity (if applicable)
test_ssh() {
    print_status "INFO" "Testing SSH connectivity (port 22)..."
    
    if timeout 5 nc -z "$TARGET_HOST" 22 2>/dev/null; then
        print_status "SUCCESS" "SSH service appears to be running"
        
        if [[ "$VERBOSE" == true ]]; then
            print_status "INFO" "Testing SSH banner..."
            ssh_banner=$(timeout 3 nc "$TARGET_HOST" 22 2>/dev/null | head -1)
            if [[ -n "$ssh_banner" ]]; then
                echo "    SSH Banner: $ssh_banner"
            fi
        fi
        return 0
    else
        print_status "INFO" "SSH service not available (this is normal for some setups)"
        return 1
    fi
}

# Function to test ARP table entry
test_arp() {
    print_status "INFO" "Checking ARP table for MAC address..."
    
    local mac_address
    mac_address=$(arp -n "$TARGET_HOST" 2>/dev/null | grep "$TARGET_HOST" | awk '{print $3}')
    
    if [[ -n "$mac_address" && "$mac_address" != "(incomplete)" ]]; then
        print_status "SUCCESS" "MAC address found: $mac_address"
        return 0
    else
        print_status "WARNING" "No ARP entry found (may need to ping first)"
        return 1
    fi
}

# Function to show network route to target
show_route() {
    if [[ "$VERBOSE" == true ]]; then
        print_status "INFO" "Network route to target:"
        if command -v traceroute >/dev/null 2>&1; then
            traceroute -m 5 "$TARGET_HOST" 2>/dev/null | head -6
        elif command -v tracepath >/dev/null 2>&1; then
            tracepath "$TARGET_HOST" 2>/dev/null | head -6
        else
            print_status "INFO" "No traceroute tool available"
        fi
    fi
}

# Function to check local network configuration
check_local_network() {
    if [[ "$VERBOSE" == true ]]; then
        print_status "INFO" "Local network configuration:"
        
        # Get default gateway
        local gateway
        gateway=$(ip route | grep default | awk '{print $3}' | head -1)
        echo "    Default Gateway: $gateway"
        
        # Get local IP on same subnet as target
        local local_ip
        local target_subnet
        target_subnet=$(echo "$TARGET_HOST" | cut -d'.' -f1-3)
        local_ip=$(ip addr show | grep -E "inet.*$target_subnet" | awk '{print $2}' | cut -d'/' -f1 | head -1)
        
        if [[ -n "$local_ip" ]]; then
            echo "    Local IP (same subnet): $local_ip"
        else
            echo "    Local IP: $(ip route get 8.8.8.8 | grep src | awk '{print $7}' | head -1)"
        fi
    fi
}

# Main testing function
run_tests() {
    echo "=================================="
    echo "Synergy KVM Network Connectivity Test"
    echo "=================================="
    echo ""
    echo "Target Host: $TARGET_HOST"
    echo "Synergy Port: $SYNERGY_PORT"
    echo "Quick Test: $QUICK_TEST"
    echo ""
    
    local tests_passed=0
    local total_tests=0
    
    # Check local network info first
    check_local_network
    echo ""
    
    # Test 1: Basic ping connectivity
    ((total_tests++))
    if test_ping; then
        ((tests_passed++))
    fi
    echo ""
    
    # Test 2: ARP table check
    if [[ "$QUICK_TEST" != true ]]; then
        ((total_tests++))
        test_arp
        echo ""
    fi
    
    # Test 3: Synergy port connectivity
    ((total_tests++))
    if test_port "$SYNERGY_PORT" "Synergy"; then
        ((tests_passed++))
    fi
    echo ""
    
    # Test 4: SSH connectivity (optional)
    if [[ "$QUICK_TEST" != true ]]; then
        ((total_tests++))
        if test_ssh; then
            ((tests_passed++))
        fi
        echo ""
    fi
    
    # Test 5: Network quality
    if [[ "$QUICK_TEST" != true ]]; then
        ((total_tests++))
        if test_network_quality; then
            ((tests_passed++))
        fi
        echo ""
    fi
    
    # Test 6: Common ports that might be useful
    if [[ "$QUICK_TEST" != true ]]; then
        echo "Testing additional common ports..."
        test_port 80 "HTTP"
        test_port 443 "HTTPS"
        test_port 3389 "RDP"
        test_port 5900 "VNC"
        echo ""
    fi
    
    # Show route information
    show_route
    
    # Summary
    echo "=================================="
    echo "Test Summary"
    echo "=================================="
    echo "Tests passed: $tests_passed/$total_tests"
    
    if [[ $tests_passed -eq $total_tests ]]; then
        print_status "SUCCESS" "All critical tests passed! Synergy should work properly."
    elif [[ $tests_passed -gt 0 ]]; then
        print_status "WARNING" "Some tests passed. Synergy might work but check failed tests."
    else
        print_status "ERROR" "All tests failed. Check network configuration and target host."
    fi
    
    echo ""
    echo "Synergy KVM Tips:"
    echo "- Synergy server should be running on port $SYNERGY_PORT"
    echo "- Make sure firewall allows Synergy traffic"
    echo "- Check that Synergy server is configured correctly"
    echo "- Ensure both machines are on the same network segment"
}

# Run the tests
run_tests