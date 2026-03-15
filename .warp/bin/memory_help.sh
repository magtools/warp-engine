#!/bin/bash

memory_help_usage() {
    warp_message ""
    warp_message_info "Usage:"
    warp_message " warp memory [report] [options]"
    warp_message ""

    warp_message ""
    warp_message_info "Options:"
    warp_message_info " -h, --help         $(warp_message 'display this help message')"
    warp_message_info " --json             $(warp_message 'output report as JSON')"
    warp_message_info " --no-suggest       $(warp_message 'show usage and current config only')"
    warp_message ""

    warp_message_info "Examples:"
    warp_message " warp memory report"
    warp_message " warp memory report --json"
    warp_message " warp memory report --no-suggest"
    warp_message ""
}

memory_help() {
    warp_message_info " memory             $(warp_message 'memory usage report and threshold suggestions')"
}
