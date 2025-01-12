#!/bin/bash

# Function to log with a timestamp
log() {
  echo "$(date +"%Y-%m-%d %H:%M:%S") - $1"
}

# Get the current short Git commit hash or fallback to a timestamp
BUILD_NUMBER=$(git rev-parse --short HEAD 2>/dev/null || date +%Y%m%d%H%M%S)
log "Using build number: $BUILD_NUMBER"

# Keep track of the last successful build
LAST_SUCCESSFUL_BUILD=$(docker ps -a --filter "name=task_management_app_" --format "{{.Names}}" | sort -r | head -n 1 | sed 's/.*_//')
if [ -z "$LAST_SUCCESSFUL_BUILD" ]; then
  LAST_SUCCESSFUL_BUILD="None"
fi
log "Last successful build: $LAST_SUCCESSFUL_BUILD"

# Stop and remove old containers but keep the last 3 builds
log "Cleaning up old containers but keeping the last 3 builds..."
docker ps -a --filter "name=task_management_" --format "{{.ID}} {{.Names}}" | sort -r | tail -n +4 | awk '{print $1}' | xargs -r docker rm -f

# Log directory for failed builds
LOG_DIR="./docker_logs"
mkdir -p "$LOG_DIR"

# Remove older logs (keep only the last 3 logs)
log "Cleaning up old logs..."
ls -1t "$LOG_DIR"/*.log 2>/dev/null | tail -n +4 | xargs -r rm -f

# Attempt to run the new build
BUILD_LOG="$LOG_DIR/build_${BUILD_NUMBER}.log"
log "Starting new build... Log saved to $BUILD_LOG"
BUILD_SUCCESS=false

BUILD_NUMBER=$BUILD_NUMBER docker-compose up --build 2>&1 | tee "$BUILD_LOG"
EXIT_CODE=${PIPESTATUS[0]}

if [ $EXIT_CODE -eq 0 ]; then
  BUILD_SUCCESS=true
  log "Build completed successfully!"
else
  log "Build failed!"
  log "Error details:"
  cat "$BUILD_LOG" | grep -iE "error|failed|exception" | tail -n 10

  # Option to fall back to the last successful build
  if [ "$LAST_SUCCESSFUL_BUILD" != "None" ]; then
    log "Reverting to the last successful build: $LAST_SUCCESSFUL_BUILD"
    docker ps -a --filter "name=task_management_" | grep "$LAST_SUCCESSFUL_BUILD" | awk '{print $1}' | xargs -r docker start
  else
    log "No previous successful build available to revert to!"
  fi
fi

# Clean up temporary log file
log "Build process finished."
