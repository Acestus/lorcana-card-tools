#!/bin/bash

# Script to copy a specific file from Downloads to S18 drive
# Usage: ./copy-software-to-s18.sh <filename> [--dry-run] [--verbose]

# Default paths
SOURCE_DIR="/home/acestus/Music/audiobooks"
DEST_DIR="/media/acestus/S18"

# Initialize variables
FILENAME=""
DRY_RUN=false
VERBOSE=false

# Function to show usage
show_usage() {
    echo "Usage: $0 <filename> [OPTIONS]"
    echo ""
    echo "Arguments:"
    echo "  filename         Name of the file to copy from $SOURCE_DIR"
    echo ""
    echo "Options:"
    echo "  --dry-run, -n    Show what would be copied without actually copying"
    echo "  --verbose, -v    Show detailed output"
    echo "  --help, -h       Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 'The Software Engineer's Guide.m4b'"
    echo "  $0 'myfile.txt' --dry-run"
    echo "  $0 'document.pdf' --verbose"
}

# Parse command line arguments
if [[ $# -eq 0 ]]; then
    echo "Error: Filename is required"
    echo ""
    show_usage
    exit 1
fi

# First argument should be the filename
FILENAME="$1"
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

echo "============================="
echo "Copy File to S18 Drive Script"
echo "============================="
echo ""

echo "Configuration:"
echo "  Filename: $FILENAME"
echo "  Source Directory: $SOURCE_DIR"
echo "  Destination Directory: $DEST_DIR"
echo "  Dry Run: $DRY_RUN"
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
SOURCE_FILE="$SOURCE_DIR/$FILENAME"

# Check if source file exists
if [[ ! -f "$SOURCE_FILE" ]]; then
    echo "Error: File '$FILENAME' not found in $SOURCE_DIR"
    echo ""
    echo "Available files in $SOURCE_DIR:"
    ls -la "$SOURCE_DIR" | grep -v "^d" | awk '{print "  " $9}' | grep -v "^\s*$"
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

echo "Available space on S18: ${available_space_mb} MB"
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
    
    # Use rsync for better progress display
    if command -v rsync >/dev/null 2>&1; then
        # rsync with progress bar, speed, and ETA
        rsync -ah --progress "$SOURCE_FILE" "$dest_file"
        rsync_exit=$?
    else
        # Fallback to cp with file size monitoring
        echo "Starting copy (rsync not available, using cp)..."
        cp "$SOURCE_FILE" "$dest_file" &
        cp_pid=$!
        
        # Monitor progress by checking destination file size
        while kill -0 $cp_pid 2>/dev/null; do
            if [[ -f "$dest_file" ]]; then
                dest_size=$(stat -c%s "$dest_file" 2>/dev/null || echo 0)
                percent=$((dest_size * 100 / size))
                echo -ne "\rProgress: ${percent}% (${dest_size}/${size} bytes)"
            fi
            sleep 2
        done
        echo ""
        wait $cp_pid
        rsync_exit=$?
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