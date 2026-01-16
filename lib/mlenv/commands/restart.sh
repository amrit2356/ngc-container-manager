#!/usr/bin/env bash
# MLEnv Restart Command
# Version: 2.0.0

cmd_restart() {
    cmd_down
    sleep 1
    cmd_up
}
