#!/bin/bash

# Script to copy a specific file from Music/audiobooks to headphones drive
# Usage: ./copy-to-headphones.sh <filename_or_path> [--dry-run] [--verbose]

# Default paths
SOURCE_DIR="/home/acestus/Music/audiobooks"
DEST_DIR="/media/acestus/S18"

# Initialize variables
FILENAME=""
DRY_RUN=false
VERBOSE=false

# Function to show usage
show_usage() {
    echo "Usage: $0 <filename_or_path> [OPTIONS]"
    echo ""
    echo "Arguments:"
    echo "  filename_or_path Full path to file OR filename in $SOURCE_DIR"
    echo ""
    echo "Options:"
    echo "  --dry-run, -n    Show what would be copied without actually copying"
    echo "  --verbose, -v    Show detailed output"
    echo "  --help, -h       Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 'The Software Engineer's Guide.m4b'"
    echo "  $0 '/home/acestus/Music/audiobooks/Men are From Mars.mp3'"
    echo "  $0 'myfile.txt' --dry-run"
    echo "  $0 '/full/path/to/document.pdf' --verbose"
}

# Parse command line arguments
if [[ $# -eq 0 ]]; then
    echo "Error: File path or filename is required"
    echo ""
    show_usage
    exit 1
fi

# First argument should be the filename or full path
FILE_INPUT="$1"
shift

# Parse remaining arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run|-n)
            DRY_RUN=true
            shift
            ;;
        --verbose|-v)
            VERBOSE=true
            shift
            ;;
        --help|-h)
            show_usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

echo "================================="
echo "Copy File to Headphones Script"
echo "================================="
echo ""

# Determine if input is a full path or just a filename
if [[ "$FILE_INPUT" == /* ]]; then
    # Full path provided
    SOURCE_FILE="$FILE_INPUT"
    FILENAME=$(basename "$SOURCE_FILE")
    ACTUAL_SOURCE_DIR=$(dirname "$SOURCE_FILE")
    echo "Configuration:"
    echo "  Input: Full path"
    echo "  Source File: $SOURCE_FILE"
    echo "  Filename: $FILENAME"
    echo "  Destination Directory: $DEST_DIR"
    echo "  Dry Run: $DRY_RUN"
else
    # Just filename provided, use default source directory
    FILENAME="$FILE_INPUT"
    SOURCE_FILE="$SOURCE_DIR/$FILENAME"
    ACTUAL_SOURCE_DIR="$SOURCE_DIR"
    echo "Configuration:"
    echo "  Input: Filename only"
    echo "  Filename: $FILENAME"
    echo "  Source Directory: $SOURCE_DIR"
    echo "  Destination Directory: $DEST_DIR"
    echo "  Dry Run: $DRY_RUN"
fi
echo ""

# Check if source directory exists
if [[ ! -d "$SOURCE_DIR" ]]; then
    echo "Error: Source directory $SOURCE_DIR does not exist"
    exit 1
fi

# Check if destination directory exists
if [[ ! -d "$DEST_DIR" ]]; then
    echo "Error: Destination directory $DEST_DIR does not exist"
    echo "Please make sure the S18 drive is mounted"
    exit 1
fi

# Construct full file path
# SOURCE_FILE is already set above based on input type

# Check if source file exists
if [[ ! -f "$SOURCE_FILE" ]]; then
    echo "Error: File '$FILENAME' not found at $SOURCE_FILE"
    echo ""
    if [[ "$FILE_INPUT" == /* ]]; then
        echo "The full path you specified does not exist."
    else
        echo "Available files in $ACTUAL_SOURCE_DIR:"
        ls -la "$ACTUAL_SOURCE_DIR" 2>/dev/null | grep -v "^d" | awk '{print "  " $9}' | grep -v "^\s*$" || echo "  (directory not accessible or empty)"
    fi
    exit 1
fi

echo "File found: $SOURCE_FILE"

# Get file information
size=$(stat -c%s "$SOURCE_FILE")
size_mb=$((size / 1024 / 1024))
echo "File size: ${size_mb} MB"
echo ""

# Check available space on destination
available_space=$(df "$DEST_DIR" | awk 'NR==2 {print $4}')
available_space_mb=$((available_space / 1024))

echo "Available space on headphones: ${available_space_mb} MB"
echo ""

if [[ $size -gt $((available_space * 1024)) ]]; then
    echo "Warning: Not enough space on destination drive!"
    echo "Required: ${size_mb} MB, Available: ${available_space_mb} MB"
    echo ""
    read -p "Do you want to continue anyway? (y/N): " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Copy operation cancelled"
        exit 1
    fi
fi

# Perform the copy operation
echo "Starting copy operation..."
echo ""

# Set up file paths
dest_file="$DEST_DIR/$FILENAME"

echo -n "Preparing to copy $FILENAME... "

if [[ "$DRY_RUN" == true ]]; then
    echo "[DRY RUN] Would copy to $dest_file"
    echo ""
    echo "Copy operation completed! (Dry run)"
else
        
    echo ""
    echo "================================================"
    echo "Starting copy operation for: $FILENAME"
    echo "File size: ${size_mb} MB"
    echo "================================================"
    echo ""
    
    # Check file system type for better compatibility
    fs_type=$(df -T "$DEST_DIR" | awk 'NR==2 {print $2}')
    echo "Destination file system: $fs_type"
    echo ""
    
    # Use appropriate copy method based on file system
    if command -v rsync >/dev/null 2>&1 && [[ "$fs_type" != "vfat" && "$fs_type" != "ntfs" ]]; then
        # rsync with progress bar for native Linux file systems
        echo "Using rsync for copy with progress..."
        rsync -ah --progress "$SOURCE_FILE" "$dest_file"
        rsync_exit=$?
    else
        # Use pv (pipe viewer) for better progress on Windows file systems
        if command -v pv >/dev/null 2>&1; then
            echo "Using pv + cp for copy with progress (FAT32/NTFS compatible)..."
            pv "$SOURCE_FILE" > "$dest_file"
            rsync_exit=$?
        else
            # Fallback to cp with manual progress monitoring
            echo "Using cp with progress monitoring (pv not available)..."
            cp "$SOURCE_FILE" "$dest_file" &
            cp_pid=$!
            
            # Monitor progress by checking destination file size
            start_time=$(date +%s)
            while kill -0 $cp_pid 2>/dev/null; do
                if [[ -f "$dest_file" ]]; then
                    dest_size=$(stat -c%s "$dest_file" 2>/dev/null || echo 0)
                    percent=$((dest_size * 100 / size))
                    current_time=$(date +%s)
                    elapsed=$((current_time - start_time))
                    if [[ $elapsed -gt 0 && $dest_size -gt 0 ]]; then
                        speed=$((dest_size / elapsed / 1024 / 1024))
                        echo -ne "\rProgress: ${percent}% (${dest_size}/${size} bytes) - ${speed}MB/s"
                    else
                        echo -ne "\rProgress: ${percent}% (${dest_size}/${size} bytes)"
                    fi
                fi
                sleep 1
            done
            echo ""
            wait $cp_pid
            rsync_exit=$?
        fi
    fi
    
    if [[ $rsync_exit -eq 0 ]]; then
        echo "✓ Copy completed successfully!"
        
        # Verify copied file
        echo ""
        echo "Verifying copied file..."
        if [[ -f "$dest_file" ]]; then
            source_size=$(stat -c%s "$SOURCE_FILE")
            dest_size=$(stat -c%s "$dest_file")
            
            if [[ $source_size -eq $dest_size ]]; then
                echo "  ✓ $FILENAME - Size verified (${size_mb} MB)"
            else
                echo "  ✗ $FILENAME - Size mismatch!"
                echo "    Source: $source_size bytes"
                echo "    Destination: $dest_size bytes"
            fi
        else
            echo "  ✗ $FILENAME - File not found in destination"
        fi
    else
        echo "✗ Copy failed!"
        exit 1
    fi
fi

echo ""
echo "Done!"