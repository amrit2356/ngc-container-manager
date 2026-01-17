#!/usr/bin/env bash
# MLEnv Performance Benchmark
# Version: 2.0.0

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
MLENV_BIN="$PROJECT_ROOT/bin/mlenv"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "MLEnv Performance Benchmark"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Benchmark function
benchmark_command() {
    local cmd="$1"
    local description="$2"
    local iterations="${3:-5}"
    
    echo "Testing: $description"
    echo "Command: $cmd"
    
    local total=0
    local times=()
    
    for ((i=1; i<=iterations; i++)); do
        local start=$(date +%s%N)
        eval "$cmd" >/dev/null 2>&1
        local end=$(date +%s%N)
        local duration=$(( (end - start) / 1000000 ))  # Convert to ms
        times+=($duration)
        total=$((total + duration))
    done
    
    local avg=$((total / iterations))
    
    # Calculate min/max
    local min=${times[0]}
    local max=${times[0]}
    for time in "${times[@]}"; do
        ((time < min)) && min=$time
        ((time > max)) && max=$time
    done
    
    printf "  Average: %4d ms\n" $avg
    printf "  Min:     %4d ms\n" $min
    printf "  Max:     %4d ms\n" $max
    echo ""
}

# Test commands that don't require container
benchmark_command "$MLENV_BIN version" "mlenv version" 10
benchmark_command "$MLENV_BIN help" "mlenv help" 10
benchmark_command "$MLENV_BIN config show" "mlenv config show" 5

# Test status command (fast even with Docker query)
benchmark_command "$MLENV_BIN status" "mlenv status" 5

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Benchmark Complete"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Performance Notes:"
echo "• Lightweight commands (version, help) should be <100ms"
echo "• Config commands should be <200ms"
echo "• Status commands may vary based on Docker response"
echo "• Context system adds minimal overhead (<10ms)"
echo ""
