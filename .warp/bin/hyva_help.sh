#!/bin/bash

hyva_help_usage() {
    warp_message ""
    warp_message_info "Usage:"
    warp_message " warp hyva command [options] [arguments]"
    warp_message ""

    warp_message ""
    warp_message_info "Options:"
    warp_message_info " -h, --help         $(warp_message 'display this help message')"
    warp_message ""

    warp_message_info "Available commands:"
    warp_message_info " discover           $(warp_message 'scan themes and create/update app/design/hyva-themes.json')"
    warp_message_info " list               $(warp_message 'list themes from app/design/hyva-themes.json')"
    warp_message_info " prepare[:themeKey] $(warp_message 'run npm run generate only')"
    warp_message_info " setup[:themeKey]   $(warp_message 'run npm install and npm run generate')"
    warp_message_info " build[:themeKey]   $(warp_message 'run npm run build')"
    warp_message_info " watch[:themeKey]   $(warp_message 'run npm run watch (single theme)')"
    warp_message ""

    warp_message_info "Quick flow:"
    warp_message " First run:  discover -> setup -> build"
    warp_message " Next runs:  build (or watch)"
    warp_message " prepare runs generate only."
    warp_message " build auto-detects generate in prebuild/build."
    warp_message " setup/prepare/build show spinner + duration and write logs in var/log/warp-hyva/."
    warp_message ""

    warp_message_info "Examples:"
    warp_message " warp hyva discover"
    warp_message " warp hyva setup:Client_HyvaWebsite"
    warp_message " warp hyva build:Client_HyvaWebsite"
    warp_message " warp hyva watch:Client_HyvaWebsite"
    warp_message " warp hyva prepare:Client_HyvaWebsite"
    warp_message ""
}

hyva_discover_help_usage() {
    warp_message ""
    warp_message_info "Usage:"
    warp_message " warp hyva discover [options]"
    warp_message ""
    warp_message_info "Options:"
    warp_message_info " --dry-run          $(warp_message 'print generated JSON without writing file')"
    warp_message_info " --set-default KEY  $(warp_message 'set default theme key')"
    warp_message_info " --merge            $(warp_message 'preserve manual fields from existing JSON')"
    warp_message ""
}

hyva_prepare_help_usage() {
    warp_message ""
    warp_message_info "Usage:"
    warp_message " warp hyva prepare[:themeKey]"
    warp_message " warp hyva setup[:themeKey] [--no-generate]"
    warp_message ""
    warp_message " prepare: generate only"
    warp_message " setup: install (+ optional generate)"
    warp_message ""
}

hyva_build_help_usage() {
    warp_message ""
    warp_message_info "Usage:"
    warp_message " warp hyva build[:themeKey]"
    warp_message ""
}

hyva_watch_help_usage() {
    warp_message ""
    warp_message_info "Usage:"
    warp_message " warp hyva watch[:themeKey]"
    warp_message ""
    warp_message " If no :themeKey is provided and multiple themes are enabled,"
    warp_message " warp will show a numeric prompt to choose one theme."
    warp_message ""
}

hyva_help() {
    warp_message_info " hyva               $(warp_message 'hyva tailwind helper commands')"
}
