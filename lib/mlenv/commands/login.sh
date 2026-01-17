#!/usr/bin/env bash
# MLEnv Login Command
# Version: 2.1.0 - Context-based

cmd_login() {
    # NGC authentication doesn't require context, but we validate for consistency
    ngc_auth_registry_login
    return $?
}
