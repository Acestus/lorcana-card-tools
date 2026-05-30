#!/bin/bash

if [ -z "$1" ]; then
    echo "Error: Message is required"
    echo "Usage: claude <message>"
    exit 1
fi

ssh violet "openclaw agent --message '$1' --session-id main"
