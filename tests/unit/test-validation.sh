#!/usr/bin/env bash
# Unit tests for validation system
# Version: 2.0.0

# Setup test environment
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
export MLENV_LIB="$PROJECT_ROOT/lib/mlenv"

# Source dependencies
source "${MLENV_LIB}/utils/logging.sh"
source "${MLENV_LIB}/utils/validation.sh"

# Test counter
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Test helper
assert_true() {
    local condition="$1"
    local message="${2:-Assertion failed}"
    
    ((TESTS_RUN++))
    
    if eval "$condition"; then
        ((TESTS_PASSED++))
        echo "  ✓ $message"
        return 0
    else
        ((TESTS_FAILED++))
        echo "  ✗ $message"
        return 1
    fi
}

assert_false() {
    local condition="$1"
    local message="${2:-Assertion failed}"
    
    ((TESTS_RUN++))
    
    if ! eval "$condition"; then
        ((TESTS_PASSED++))
        echo "  ✓ $message"
        return 0
    else
        ((TESTS_FAILED++))
        echo "  ✗ $message"
        return 1
    fi
}

# Test: Port validation
test_port_validation() {
    echo "Test: Port Validation"
    
    assert_true "validate_ports '8888:8888'" "Valid single port"
    assert_true "validate_ports '8888:8888,6006:6006'" "Valid multiple ports"
    assert_true "validate_ports '1:1'" "Valid min port"
    assert_true "validate_ports '65535:65535'" "Valid max port"
    assert_true "validate_ports ''" "Empty ports (valid)"
    
    assert_false "validate_ports 'invalid'" "Invalid format"
    assert_false "validate_ports '8888'" "Missing container port"
    assert_false "validate_ports 'abc:8888'" "Non-numeric host port"
    assert_false "validate_ports '8888:abc'" "Non-numeric container port"
    assert_false "validate_ports '0:8888'" "Port 0 invalid"
    assert_false "validate_ports '65536:8888'" "Port > 65535 invalid"
    
    echo ""
}

# Test: GPU device validation
test_gpu_validation() {
    echo "Test: GPU Device Validation"
    
    assert_true "validate_gpu_devices 'all'" "Valid 'all'"
    assert_true "validate_gpu_devices '0'" "Valid single GPU"
    assert_true "validate_gpu_devices '0,1,2'" "Valid multiple GPUs"
    assert_true "validate_gpu_devices ''" "Empty (valid)"
    
    assert_false "validate_gpu_devices 'invalid'" "Invalid format"
    assert_false "validate_gpu_devices '0,a'" "Non-numeric device"
    assert_false "validate_gpu_devices '0,,1'" "Double comma"
    
    echo ""
}

# Test: Container name validation
test_container_name_validation() {
    echo "Test: Container Name Validation"
    
    assert_true "validate_container_name 'mlenv-test-12345678'" "Valid container name"
    assert_true "validate_container_name 'test_container'" "Valid with underscore"
    assert_true "validate_container_name 'test-container'" "Valid with dash"
    assert_true "validate_container_name 'test.container'" "Valid with dot"
    
    assert_false "validate_container_name '-test'" "Cannot start with dash"
    assert_false "validate_container_name '.test'" "Cannot start with dot"
    assert_false "validate_container_name 'test@container'" "Invalid character @"
    assert_false "validate_container_name 'test container'" "Space not allowed"
    
    echo ""
}

# Test: Image name validation
test_image_name_validation() {
    echo "Test: Image Name Validation"
    
    assert_true "validate_image_name 'ubuntu:20.04'" "Valid image with tag"
    assert_true "validate_image_name 'nvcr.io/nvidia/pytorch:25.12-py3'" "Valid NGC image"
    assert_true "validate_image_name 'myregistry.com/org/image:tag'" "Valid with registry"
    
    assert_false "validate_image_name ''" "Empty image name"
    assert_false "validate_image_name 'UPPERCASE:TAG'" "Uppercase not allowed"
    
    echo ""
}

# Test: Memory limit validation
test_memory_limit_validation() {
    echo "Test: Memory Limit Validation"
    
    assert_true "validate_memory_limit '4g'" "Valid GB"
    assert_true "validate_memory_limit '512m'" "Valid MB"
    assert_true "validate_memory_limit '1024k'" "Valid KB"
    assert_true "validate_memory_limit '4G'" "Valid uppercase G"
    assert_true "validate_memory_limit '100'" "Valid number only"
    assert_true "validate_memory_limit ''" "Empty (valid)"
    
    assert_false "validate_memory_limit 'abc'" "Invalid format"
    assert_false "validate_memory_limit '4gb'" "Invalid unit"
    
    echo ""
}

# Test: CPU limit validation
test_cpu_limit_validation() {
    echo "Test: CPU Limit Validation"
    
    assert_true "validate_cpu_limit '2'" "Valid integer"
    assert_true "validate_cpu_limit '1.5'" "Valid decimal"
    assert_true "validate_cpu_limit '0.5'" "Valid fraction"
    assert_true "validate_cpu_limit ''" "Empty (valid)"
    
    assert_false "validate_cpu_limit 'abc'" "Invalid format"
    assert_false "validate_cpu_limit '2.5.1'" "Multiple dots"
    
    echo ""
}

# Test: Boolean validation
test_boolean_validation() {
    echo "Test: Boolean Validation"
    
    assert_true "validate_boolean 'true'" "Valid true"
    assert_true "validate_boolean 'false'" "Valid false"
    assert_true "validate_boolean 'yes'" "Valid yes"
    assert_true "validate_boolean 'no'" "Valid no"
    assert_true "validate_boolean '1'" "Valid 1"
    assert_true "validate_boolean '0'" "Valid 0"
    
    assert_false "validate_boolean 'maybe'" "Invalid value"
    assert_false "validate_boolean ''" "Empty"
    
    echo ""
}

# Test: Boolean normalization
test_boolean_normalization() {
    echo "Test: Boolean Normalization"
    
    local result
    
    result=$(normalize_boolean "true")
    assert_true "[[ '$result' == 'true' ]]" "true → true"
    
    result=$(normalize_boolean "yes")
    assert_true "[[ '$result' == 'true' ]]" "yes → true"
    
    result=$(normalize_boolean "1")
    assert_true "[[ '$result' == 'true' ]]" "1 → true"
    
    result=$(normalize_boolean "false")
    assert_true "[[ '$result' == 'false' ]]" "false → false"
    
    result=$(normalize_boolean "no")
    assert_true "[[ '$result' == 'false' ]]" "no → false"
    
    result=$(normalize_boolean "invalid")
    assert_true "[[ '$result' == 'false' ]]" "invalid → false (default)"
    
    echo ""
}

# Run all tests
main() {
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "MLEnv Validation System Unit Tests"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    test_port_validation
    test_gpu_validation
    test_container_name_validation
    test_image_name_validation
    test_memory_limit_validation
    test_cpu_limit_validation
    test_boolean_validation
    test_boolean_normalization
    
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
