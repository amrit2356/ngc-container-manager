#!/usr/bin/env bash
# MLEnv Logout Command
# Version: 2.1.0 - Context-based

cmd_logout() {
    # NGC authentication doesn't require context, but we validate for consistency
    ngc_auth_registry_logout
    return $?
}
