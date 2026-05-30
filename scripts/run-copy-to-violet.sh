#!/usr/bin/env bash
set -euo pipefail

# Thin local caller for scripts/copy-to-violet.ps1
# Usage:
#   ./scripts/run-copy-to-violet.sh [--source /path] [--dest-host violet] [--dest-path /media/violet/movies01] [--dry-run|--no-dry-run] [--delete-extra|--no-delete-extra] [--verbose]

SOURCE="/media/acestus/INFUSE"
DEST_HOST="violet"
DEST_PATH="/media/violet/movies01"
DRY_RUN="true"
DELETE_EXTRA="false"
VERBOSE="false"

print_usage() {
  cat <<EOF
Usage: $0 [options]

Options:
  --source /path           Source path (default: $SOURCE)
  --dest-host HOST         Destination host (default: $DEST_HOST)
  --dest-path PATH         Destination path on host (default: $DEST_PATH)
  --dry-run / --no-dry-run Use dry-run (default: --dry-run)
  --delete-extra / --no-delete-extra  Remove extra files on destination (default: --no-delete-extra)
  --verbose                Verbose output
  -h, --help               Show this help and exit

Examples:
  $0 --source /media/acestus/INFUSE --no-dry-run --delete-extra --verbose
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --source|-s)
      SOURCE="$2"; shift 2;;
    --dest-host)
      DEST_HOST="$2"; shift 2;;
    --dest-path)
      DEST_PATH="$2"; shift 2;;
    --dry-run)
      DRY_RUN="true"; shift;;
    --no-dry-run)
      DRY_RUN="false"; shift;;
    --delete-extra)
      DELETE_EXTRA="true"; shift;;
    --no-delete-extra)
      DELETE_EXTRA="false"; shift;;
    --verbose|-v)
      VERBOSE="true"; shift;;
    -h|--help)
      print_usage; exit 0;;
    *)
      echo "Unknown argument: $1"; print_usage; exit 1;;
  esac
done

# Build pwsh arguments
PWARGS=("-SourcePath" "$SOURCE" "-DestinationHost" "$DEST_HOST" "-DestinationPath" "$DEST_PATH")
[ "$DRY_RUN" = "true" ] && PWARGS+=("-DryRun")
[ "$DELETE_EXTRA" = "true" ] && PWARGS+=("-DeleteExtra")
[ "$VERBOSE" = "true" ] && PWARGS+=("-VerboseOutput")

echo "Executing: pwsh -NoProfile -NonInteractive -ExecutionPolicy Bypass ./scripts/copy-to-violet.ps1 ${PWARGS[*]}"
exec pwsh -NoProfile -NonInteractive -ExecutionPolicy Bypass ./scripts/copy-to-violet.ps1 "${PWARGS[@]}"
