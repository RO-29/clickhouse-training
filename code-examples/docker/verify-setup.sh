#!/bin/bash

# Docker Compose Verification Script
# Purpose: Verify that all Docker services are running correctly and healthy

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    local status=$1
    local message=$2

    case $status in
        "ok")
            echo -e "${GREEN}[✓]${NC} $message"
            ;;
        "fail")
            echo -e "${RED}[✗]${NC} $message"
            ;;
        "warn")
            echo -e "${YELLOW}[!]${NC} $message"
            ;;
        "info")
            echo -e "${BLUE}[i]${NC} $message"
            ;;
    esac
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check Docker daemon
check_docker() {
    print_status "info" "Checking Docker installation..."

    if ! command_exists docker; then
        print_status "fail" "Docker is not installed"
        return 1
    fi

    print_status "ok" "Docker is installed"

    if ! docker ps >/dev/null 2>&1; then
        print_status "fail" "Docker daemon is not running"
        return 1
    fi

    print_status "ok" "Docker daemon is running"
    return 0
}

# Function to check Docker Compose
check_docker_compose() {
    print_status "info" "Checking Docker Compose installation..."

    if ! command_exists docker-compose; then
        print_status "fail" "Docker Compose is not installed"
        return 1
    fi

    local version=$(docker-compose --version | grep -oP 'Docker Compose version \K[0-9.]+')
    print_status "ok" "Docker Compose version: $version"

    # Check if version is 2.0+
    local major_version=$(echo $version | cut -d. -f1)
    if [ "$major_version" -lt 2 ]; then
        print_status "warn" "Docker Compose version 2.0+ recommended (current: $version)"
    fi

    return 0
}

# Function to check system resources
check_resources() {
    print_status "info" "Checking system resources..."

    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        local total_mem=$(free -b | awk '/^Mem:/ {print $2}')
        local avail_mem=$(free -b | awk '/^Mem:/ {print $7}')
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        local total_mem=$(sysctl -n hw.memsize)
        local avail_mem=$(vm_stat | grep "Pages free" | awk '{print $3 * 4096}')
    else
        print_status "warn" "Cannot determine available memory on this system"
        return 0
    fi

    local total_gb=$((total_mem / 1024 / 1024 / 1024))
    local avail_gb=$((avail_mem / 1024 / 1024 / 1024))

    print_status "ok" "Total Memory: ${total_gb}GB, Available: ${avail_gb}GB"

    if [ "$avail_gb" -lt 4 ]; then
        print_status "warn" "Only ${avail_gb}GB available memory. Recommended minimum: 8GB"
    else
        print_status "ok" "Sufficient memory available"
    fi

    # Check disk space
    local avail_disk=$(df . | tail -1 | awk '{print $4}')
    local avail_disk_gb=$((avail_disk / 1024 / 1024))

    print_status "ok" "Available disk space: ${avail_disk_gb}GB"

    if [ "$avail_disk_gb" -lt 20 ]; then
        print_status "warn" "Only ${avail_disk_gb}GB available disk. Recommended minimum: 20GB"
    else
        print_status "ok" "Sufficient disk space available"
    fi
}

# Function to verify Docker compose files exist
check_compose_files() {
    print_status "info" "Checking Docker Compose files..."

    local files=(
        "docker-compose-single.yml"
        "docker-compose-cluster.yml"
        "docker-compose-kafka.yml"
        "docker-compose-migration.yml"
        "docker-compose-monitoring.yml"
    )

    local missing_files=0

    for file in "${files[@]}"; do
        if [ -f "$file" ]; then
            print_status "ok" "Found: $file"
        else
            print_status "fail" "Missing: $file"
            ((missing_files++))
        fi
    done

    if [ $missing_files -eq 0 ]; then
        print_status "ok" "All compose files present"
        return 0
    else
        print_status "fail" "Missing $missing_files compose files"
        return 1
    fi
}

# Function to verify configuration files
check_config_files() {
    print_status "info" "Checking configuration files..."

    local config_dir="configs"
    local required_configs=(
        "single-node.xml"
        "cluster-node.xml"
        "kafka-node.xml"
        "migration-node.xml"
        "monitoring-node.xml"
        "prometheus.yml"
        "alert-rules.yml"
    )

    local missing_configs=0

    for config in "${required_configs[@]}"; do
        if [ -f "$config_dir/$config" ]; then
            print_status "ok" "Found: $config"
        else
            print_status "fail" "Missing: $config"
            ((missing_configs++))
        fi
    done

    if [ $missing_configs -eq 0 ]; then
        print_status "ok" "All config files present"
        return 0
    else
        print_status "warn" "Missing $missing_configs config files"
        return 0  # Don't fail, configs can be auto-generated
    fi
}

# Function to verify init scripts
check_init_scripts() {
    print_status "info" "Checking initialization scripts..."

    local scripts_dir="init-scripts"
    local required_scripts=(
        "00-base-setup.sql"
        "kafka-setup.sql"
        "clickhouse-migration-setup.sql"
        "monitoring-setup.sql"
    )

    local missing_scripts=0

    for script in "${required_scripts[@]}"; do
        if [ -f "$scripts_dir/$script" ]; then
            print_status "ok" "Found: $script"
        else
            print_status "fail" "Missing: $script"
            ((missing_scripts++))
        fi
    done

    if [ $missing_scripts -eq 0 ]; then
        print_status "ok" "All init scripts present"
        return 0
    else
        print_status "warn" "Missing $missing_scripts init scripts"
        return 0  # Don't fail
    fi
}

# Function to check port availability
check_ports() {
    print_status "info" "Checking port availability..."

    local ports=(
        "8123:ClickHouse HTTP"
        "9000:ClickHouse Native"
        "2181:ZooKeeper"
        "9092:Kafka"
        "9090:Prometheus"
        "3000:Grafana"
        "9093:AlertManager"
    )

    local ports_in_use=0

    for port_info in "${ports[@]}"; do
        local port="${port_info%%:*}"
        local service="${port_info##*:}"

        if command_exists lsof; then
            if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1; then
                print_status "warn" "Port $port ($service) is already in use"
                ((ports_in_use++))
            else
                print_status "ok" "Port $port ($service) is available"
            fi
        else
            print_status "info" "Cannot check port $port (lsof not available)"
        fi
    done

    if [ $ports_in_use -eq 0 ]; then
        print_status "ok" "All required ports are available"
        return 0
    else
        print_status "warn" "$ports_in_use ports are already in use"
        return 0  # Don't fail, user might want to use different ports
    fi
}

# Function to test Docker connectivity
test_docker_connectivity() {
    print_status "info" "Testing Docker connectivity..."

    if docker pull hello-world:latest >/dev/null 2>&1; then
        print_status "ok" "Can pull images from Docker Hub"
    else
        print_status "warn" "Cannot pull images from Docker Hub (check internet connection)"
    fi
}

# Function to run all checks
run_all_checks() {
    echo -e "\n${BLUE}=== ClickHouse Docker Environment Verification ===${NC}\n"

    local all_passed=true

    check_docker || all_passed=false
    echo ""

    check_docker_compose || all_passed=false
    echo ""

    check_resources
    echo ""

    check_compose_files || all_passed=false
    echo ""

    check_config_files
    echo ""

    check_init_scripts
    echo ""

    check_ports
    echo ""

    test_docker_connectivity
    echo ""

    if [ "$all_passed" = true ]; then
        echo -e "${GREEN}=== All critical checks passed! ===${NC}\n"
        echo "You can now run:"
        echo "  docker-compose -f docker-compose-single.yml up -d"
        echo ""
        return 0
    else
        echo -e "${RED}=== Some critical checks failed ===${NC}\n"
        echo "Please fix the issues above and try again."
        echo ""
        return 1
    fi
}

# Main execution
main() {
    if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
        echo "ClickHouse Docker Verification Script"
        echo ""
        echo "Usage: ./verify-setup.sh [OPTIONS]"
        echo ""
        echo "Options:"
        echo "  -h, --help          Show this help message"
        echo "  -d, --docker        Check Docker installation only"
        echo "  -c, --compose       Check Docker Compose only"
        echo "  -r, --resources     Check system resources only"
        echo "  -p, --ports         Check port availability only"
        echo ""
        echo "Without options, runs all checks."
        echo ""
        return 0
    fi

    case "$1" in
        -d|--docker)
            check_docker
            ;;
        -c|--compose)
            check_docker_compose
            ;;
        -r|--resources)
            check_resources
            ;;
        -p|--ports)
            check_ports
            ;;
        *)
            run_all_checks
            ;;
    esac
}

# Run main function
main "$@"
exit $?
