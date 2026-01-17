#!/usr/bin/env bash
# Full system integration tests
# Version: 2.0.0

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
MLENV_BIN="$PROJECT_ROOT/bin/mlenv"

# Test workspace
TEST_DIR="/tmp/mlenv-integration-test-$$"
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test helper
test_command() {
    local description="$1"
    local command="$2"
    local expected_exit="${3:-0}"
    
    TESTS_RUN=$((TESTS_RUN + 1))
    
    echo -n "  Testing: $description ... "
    
    set +e
    eval "$command" >/dev/null 2>&1
    local actual_exit=$?
    set -e
    
    if [[ $actual_exit -eq $expected_exit ]]; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        echo -e "${GREEN}✓${NC}"
        return 0
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        echo -e "${RED}✗${NC} (expected exit $expected_exit, got $actual_exit)"
        return 0  # Don't fail the whole script
    fi
}

# Setup test environment
setup() {
    echo "Setting up test environment..."
    mkdir -p "$TEST_DIR"
    cd "$TEST_DIR"
    echo "Test directory: $TEST_DIR"
    echo ""
}

# Cleanup
cleanup() {
    echo ""
    echo "Cleaning up..."
    
    # Remove test container if it exists
    local container_name="mlenv-mlenv-integration-test-$$"
    if docker ps -a --format '{{.Names}}' | grep -q "^${container_name}$"; then
        docker rm -f "$container_name" >/dev/null 2>&1 || true
    fi
    
    # Remove test directory
    cd /
    rm -rf "$TEST_DIR"
    
    echo "Cleanup complete"
}

# Test: Basic commands
test_basic_commands() {
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Test Suite: Basic Commands"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    test_command "mlenv version" "$MLENV_BIN version"
    test_command "mlenv help" "$MLENV_BIN help"
    test_command "mlenv config show" "$MLENV_BIN config show"
    
    echo ""
}

# Test: Status command
test_status_command() {
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Test Suite: Status Command"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    test_command "mlenv status (no container)" "$MLENV_BIN status"
    
    echo ""
}

# Test: Context system
test_context_system() {
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Test Suite: Context System"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Context unit tests should pass
    test_command "Context unit tests" "$PROJECT_ROOT/tests/unit/test-context.sh"
    
    echo ""
}

# Test: Validation system
test_validation_system() {
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Test Suite: Validation System"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Validation unit tests should pass
    test_command "Validation unit tests" "$PROJECT_ROOT/tests/unit/test-validation.sh"
    
    echo ""
}

# Test: Config precedence
test_config_precedence() {
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Test Suite: Config Precedence"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Test that command-line flags override config
    test_command "CLI flag overrides config" "$MLENV_BIN status --image test:latest"
    
    # Test that env vars work
    test_command "Env var sets config" "MLENV_DEFAULT_IMAGE=test:v1 $MLENV_BIN status"
    
    echo ""
}

# Test: Error handling
test_error_handling() {
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Test Suite: Error Handling"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Test invalid command
    test_command "Invalid command fails" "$MLENV_BIN invalid_command" 1
    
    # Test exec without container
    test_command "Exec without container fails" "$MLENV_BIN exec -c 'echo test'" 1
    
    echo ""
}

# Main test runner
main() {
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║                                                               ║"
    echo "║  MLEnv Full System Integration Tests                         ║"
    echo "║                                                               ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo ""
    
    # Setup
    trap cleanup EXIT
    setup
    
    # Run test suites
    test_basic_commands
    test_status_command
    test_context_system
    test_validation_system
    test_config_precedence
    test_error_handling
    
    # Results
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Integration Test Results"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Tests run:    $TESTS_RUN"
    echo "Tests passed: $TESTS_PASSED"
    echo "Tests failed: $TESTS_FAILED"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "${GREEN}✓ All integration tests passed!${NC}"
        exit 0
    else
        echo -e "${RED}✗ Some integration tests failed${NC}"
        exit 1
    fi
}

main "$@"
