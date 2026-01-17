#!/usr/bin/env bash
# Unit tests for context system
# Version: 2.0.0

# Setup test environment
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
export MLENV_LIB="$PROJECT_ROOT/lib/mlenv"

# Source dependencies
source "${MLENV_LIB}/utils/logging.sh"
source "${MLENV_LIB}/core/context.sh"

# Test counter
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Test helper functions
assert_equals() {
    local expected="$1"
    local actual="$2"
    local message="${3:-Assertion failed}"
    
    ((TESTS_RUN++))
    
    if [[ "$expected" == "$actual" ]]; then
        ((TESTS_PASSED++))
        echo "  ✓ $message"
        return 0
    else
        ((TESTS_FAILED++))
        echo "  ✗ $message"
        echo "    Expected: $expected"
        echo "    Actual:   $actual"
        return 1
    fi
}

assert_not_empty() {
    local value="$1"
    local message="${2:-Value should not be empty}"
    
    ((TESTS_RUN++))
    
    if [[ -n "$value" ]]; then
        ((TESTS_PASSED++))
        echo "  ✓ $message"
        return 0
    else
        ((TESTS_FAILED++))
        echo "  ✗ $message"
        return 1
    fi
}

# Test: Context creation
test_context_creation() {
    echo "Test: Context Creation"
    
    declare -A ctx
    mlenv_context_create ctx
    
    assert_not_empty "${ctx[workdir]}" "workdir should be set"
    assert_not_empty "${ctx[project_name]}" "project_name should be set"
    assert_not_empty "${ctx[container_name]}" "container_name should be set"
    assert_not_empty "${ctx[workdir_hash]}" "workdir_hash should be set"
    assert_not_empty "${ctx[log_dir]}" "log_dir should be set"
    assert_not_empty "${ctx[log_file]}" "log_file should be set"
    assert_equals "2.0.0" "${ctx[version]}" "version should be 2.0.0"
    
    echo ""
}

# Test: Context validation
test_context_validation() {
    echo "Test: Context Validation"
    
    # Valid context
    declare -A valid_ctx
    valid_ctx[workdir]="/some/path"
    valid_ctx[container_name]="test-container"
    valid_ctx[project_name]="test-project"
    
    if mlenv_context_validate valid_ctx 2>/dev/null; then
        ((TESTS_RUN++))
        ((TESTS_PASSED++))
        echo "  ✓ Valid context passes validation"
    else
        ((TESTS_RUN++))
        ((TESTS_FAILED++))
        echo "  ✗ Valid context should pass validation"
    fi
    
    # Invalid context - missing workdir
    declare -A invalid_ctx
    invalid_ctx[container_name]="test-container"
    invalid_ctx[project_name]="test-project"
    
    if ! mlenv_context_validate invalid_ctx 2>/dev/null; then
        ((TESTS_RUN++))
        ((TESTS_PASSED++))
        echo "  ✓ Invalid context fails validation (missing workdir)"
    else
        ((TESTS_RUN++))
        ((TESTS_FAILED++))
        echo "  ✗ Invalid context should fail validation"
    fi
    
    echo ""
}

# Test: Context get/set
test_context_get_set() {
    echo "Test: Context Get/Set"
    
    declare -A ctx
    mlenv_context_create ctx
    
    # Test set
    mlenv_context_set ctx "test_key" "test_value"
    
    # Test get
    local value=$(mlenv_context_get ctx "test_key" "default")
    assert_equals "test_value" "$value" "Get should return set value"
    
    # Test get with default
    local default_value=$(mlenv_context_get ctx "nonexistent_key" "my_default")
    assert_equals "my_default" "$default_value" "Get should return default for nonexistent key"
    
    echo ""
}

# Test: Container name generation
test_container_name_generation() {
    echo "Test: Container Name Generation"
    
    # Set workdir
    export WORKDIR="/test/project/path"
    
    declare -A ctx
    mlenv_context_create ctx
    
    local expected_project="path"
    assert_equals "$expected_project" "${ctx[project_name]}" "Project name should be directory name"
    
    # Container name should start with mlenv-
    if [[ "${ctx[container_name]}" =~ ^mlenv- ]]; then
        ((TESTS_RUN++))
        ((TESTS_PASSED++))
        echo "  ✓ Container name starts with mlenv-"
    else
        ((TESTS_RUN++))
        ((TESTS_FAILED++))
        echo "  ✗ Container name should start with mlenv-"
    fi
    
    # Container name should contain hash
    if [[ "${ctx[container_name]}" =~ -[0-9a-f]{8}$ ]]; then
        ((TESTS_RUN++))
        ((TESTS_PASSED++))
        echo "  ✓ Container name contains hash"
    else
        ((TESTS_RUN++))
        ((TESTS_FAILED++))
        echo "  ✗ Container name should contain 8-char hash"
    fi
    
    unset WORKDIR
    echo ""
}

# Test: Context export
test_context_export() {
    echo "Test: Context Export"
    
    declare -A ctx
    ctx[workdir]="/test/path"
    ctx[project_name]="testproj"
    ctx[container_name]="mlenv-testproj-12345678"
    ctx[log_dir]="/test/path/.mlenv"
    ctx[log_file]="/test/path/.mlenv/mlenv.log"
    ctx[image]="test-image:v1"
    
    # Export context
    mlenv_context_export ctx
    
    # Verify exports
    assert_equals "/test/path" "$WORKDIR" "WORKDIR should be exported"
    assert_equals "testproj" "$PROJECT_NAME" "PROJECT_NAME should be exported"
    assert_equals "mlenv-testproj-12345678" "$CONTAINER_NAME" "CONTAINER_NAME should be exported"
    assert_equals "test-image:v1" "$IMAGE" "IMAGE should be exported"
    
    echo ""
}

# Test: Context with command-line options
test_context_with_options() {
    echo "Test: Context with Command-Line Options"
    
    # Set global options (simulating command-line parsing)
    export IMAGE="custom-image:v2"
    export GPU_DEVICES="0,1"
    export PORTS="8888:8888,6006:6006"
    
    declare -A ctx
    mlenv_context_create ctx
    
    assert_equals "custom-image:v2" "${ctx[image]}" "Context should capture IMAGE"
    assert_equals "0,1" "${ctx[gpu_devices]}" "Context should capture GPU_DEVICES"
    assert_equals "8888:8888,6006:6006" "${ctx[ports]}" "Context should capture PORTS"
    
    # Cleanup
    unset IMAGE GPU_DEVICES PORTS
    echo ""
}

# Run all tests
main() {
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "MLEnv Context System Unit Tests"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    test_context_creation
    test_context_validation
    test_context_get_set
    test_container_name_generation
    test_context_export
    test_context_with_options
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Test Results"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Tests run:    $TESTS_RUN"
    echo "Tests passed: $TESTS_PASSED"
    echo "Tests failed: $TESTS_FAILED"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo "✓ All tests passed!"
        exit 0
    else
        echo "✗ Some tests failed"
        exit 1
    fi
}

main "$@"
