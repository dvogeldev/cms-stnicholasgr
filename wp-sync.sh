#!/bin/bash

set -euo pipefail  # Exit on error, undefined variables, and pipeline errors

# Load environment variables from .env file
if [ ! -f ".env" ]; then
    echo -e "\033[0;31m[ERROR]\033[0m .env file not found. Please create one with required variables."
    exit 1
fi
source .env

# Validate required environment variables
required_vars=(
    "REMOTE_USER" "REMOTE_HOST" "REMOTE_WP_PATH" "SSH_PORT"
    "REMOTE_DB_NAME" "REMOTE_DB_USER" "REMOTE_DB_PASS" "REMOTE_DB_HOST"
    "LOCAL_PROJECT_NAME"
)
for var in "${required_vars[@]}"; do
    if [ -z "${!var}" ]; then
        echo -e "\033[0;31m[ERROR]\033[0m Missing required environment variable: $var"
        exit 1
    fi
done

# Derive paths and URLs
LOCAL_WP_PATH="./"  # Local directory (relative to script, typically DDEV project root)
REMOTE_URL="https://$REMOTE_HOST"  # Remote site URL
LOCAL_URL="https://$LOCAL_PROJECT_NAME.ddev.site"  # Local DDEV URL

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

# Check if required tools are installed
check_dependencies() {
    log_info "Checking dependencies..."
    
    local missing_deps=()
    
    for cmd in ssh rsync ddev; do
        if ! command -v "$cmd" &> /dev/null; then
            missing_deps+=("$cmd")
        fi
    done
    
    # Check for WP-CLI via ddev wp
    if ! ddev wp --version &> /dev/null; then
        missing_deps+=("ddev wp")
    fi
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        log_error "Missing required dependencies: ${missing_deps[*]}"
        log_error "Please install them using: sudo apt install openssh-client rsync"
        log_error "For DDEV and WP-CLI: follow https://ddev.readthedocs.io/en/stable/#installation"
        exit 1
    fi
    
    log_success "All dependencies are installed"
}

# Verify DDEV project is running
verify_ddev_status() {
    log_info "Verifying DDEV environment..."
    
    if ! ddev list | grep -q "$LOCAL_PROJECT_NAME"; then
        log_error "DDEV project '$LOCAL_PROJECT_NAME' not found"
        log_info "Available projects:"
        ddev list --json-output | jq -r '.[] | "\(.name) (\(.status))"'
        exit 1
    fi
    
    if ! ddev describe "$LOCAL_PROJECT_NAME" &> /dev/null; then
        log_error "Could not describe DDEV project '$LOCAL_PROJECT_NAME'"
        exit 1
    fi
    
    if ! ddev status "$LOCAL_PROJECT_NAME" | grep -q "running"; then
        log_info "Starting DDEV project..."
        ddev start "$LOCAL_PROJECT_NAME"
    fi
    
    log_success "DDEV environment is ready"
}

# Sync wp-content directory
sync_wp_content() {
    local direction="$1"
    
    if [ "$direction" = "remote-to-local" ]; then
        log_info "Syncing wp-content from remote to local..."
        rsync -avz \
            --delete \
            --exclude='cache/*' \
            --exclude='uploads/ai1wm-backups/*' \
            --exclude='.git*' \
            --exclude='*.log' \
            --exclude='debug.log' \
            -e "ssh -p $SSH_PORT" \
            "$REMOTE_USER@$REMOTE_HOST:$REMOTE_WP_PATH/wp-content/" \
            "$LOCAL_WP_PATH/wp-content/"
    else
        log_info "Syncing wp-content from local to remote..."
        rsync -avz \
            --delete \
            --exclude='cache/*' \
            --exclude='uploads/ai1wm-backups/*' \
            --exclude='.git*' \
            --exclude='*.log' \
            --exclude='debug.log' \
            -e "ssh -p $SSH_PORT" \
            "$LOCAL_WP_PATH/wp-content/" \
            "$REMOTE_USER@$REMOTE_HOST:$REMOTE_WP_PATH/wp-content/"
    fi
    
    log_success "wp-content sync completed"
}

# Export database
export_database() {
    local direction="$1"
    local backup_dir="$LOCAL_WP_PATH/backups"
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local db_backup_file="$backup_dir/db-$timestamp.sql"
    
    mkdir -p "$backup_dir"
    
    if [ "$direction" = "remote-to-local" ]; then
        log_info "Exporting remote database..."
        ssh -p "$SSH_PORT" "$REMOTE_USER@$REMOTE_HOST" "
            mysqldump -u'$REMOTE_DB_USER' -p'$REMOTE_DB_PASS' -h'$REMOTE_DB_HOST' '$REMOTE_DB_NAME' \
            --single-transaction \
            --routines \
            --triggers \
            --skip-lock-tables \
            > /tmp/remote-db-dump.sql
        "
        scp -P "$SSH_PORT" "$REMOTE_USER@$REMOTE_HOST:/tmp/remote-db-dump.sql" "$db_backup_file"
        ssh -p "$SSH_PORT" "$REMOTE_USER@$REMOTE_HOST" "rm -f /tmp/remote-db-dump.sql"
    else
        log_info "Exporting local DDEV database..."
        ddev export-db --project-name="$LOCAL_PROJECT_NAME" --file="$db_backup_file"
    fi
    
    log_success "Database exported to: $db_backup_file"
    echo "$db_backup_file"
}

# Backup remote database (for local-to-remote sync)
backup_remote_database() {
    log_info "Backing up remote database..."
    
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local remote_backup_file="/tmp/remote-db-backup-$timestamp.sql"
    local local_backup_dir="$LOCAL_WP_PATH/backups"
    local local_backup_file="$local_backup_dir/remote-db-backup-$timestamp.sql"
    
    mkdir -p "$local_backup_dir"
    
    ssh -p "$SSH_PORT" "$REMOTE_USER@$REMOTE_HOST" "
        mysqldump -u'$REMOTE_DB_USER' -p'$REMOTE_DB_PASS' -h'$REMOTE_DB_HOST' '$REMOTE_DB_NAME' \
        --single-transaction \
        --routines \
        --triggers \
        --skip-lock-tables \
        > '$remote_backup_file'
    "
    
    scp -P "$SSH_PORT" "$REMOTE_USER@$REMOTE_HOST:$remote_backup_file" "$local_backup_file"
    ssh -p "$SSH_PORT" "$REMOTE_USER@$REMOTE_HOST" "rm -f '$remote_backup_file'"
    
    log_success "Remote database backed up to: $local_backup_file"
}

# Import database
import_database() {
    local direction="$1"
    local db_file="$2"
    
    if [ "$direction" = "remote-to-local" ]; then
        log_info "Importing database to local DDEV environment..."
        ddev wp db reset --yes --project-name="$LOCAL_PROJECT_NAME" || true
        ddev import-db --project-name="$LOCAL_PROJECT_NAME" --file="$db_file"
    else
        log_info "Importing database to remote Hostinger server..."
        local remote_db_file="/tmp/local-db-import.sql"
        scp -P "$SSH_PORT" "$db_file" "$REMOTE_USER@$REMOTE_HOST:$remote_db_file"
        ssh -p "$SSH_PORT" "$REMOTE_USER@$REMOTE_HOST" "
            mysql -u'$REMOTE_DB_USER' -p'$REMOTE_DB_PASS' -h'$REMOTE_DB_HOST' '$REMOTE_DB_NAME' < '$remote_db_file' &&
            rm -f '$remote_db_file'
        "
    fi
    
    log_success "Database imported successfully"
}

# Update WordPress URLs
update_urls() {
    local direction="$1"
    
    if [ "$direction" = "remote-to-local" ]; then
        log_info "Updating URLs for local DDEV environment..."
        ddev wp option update siteurl "$LOCAL_URL" --project-name="$LOCAL_PROJECT_NAME"
        ddev wp option update home "$LOCAL_URL" --project-name="$LOCAL_PROJECT_NAME"
        ddev wp search-replace "$REMOTE_URL" "$LOCAL_URL" --all-tables --project-name="$LOCAL_PROJECT_NAME"
        ddev wp option update blog_public 1 --project-name="$LOCAL_PROJECT_NAME"
        ddev wp rewrite flush --project-name="$LOCAL_PROJECT_NAME"
    else
        log_info "Updating URLs on remote Hostinger server..."
        local temp_sql=$(mktemp)
        cat > "$temp_sql" << EOF
UPDATE wp_options SET option_value = '$REMOTE_URL' WHERE option_name IN ('siteurl', 'home');
UPDATE wp_posts SET guid = REPLACE(guid, '$LOCAL_URL', '$REMOTE_URL');
UPDATE wp_posts SET post_content = REPLACE(post_content, '$LOCAL_URL', '$REMOTE_URL');
UPDATE wp_postmeta SET meta_value = REPLACE(meta_value, '$LOCAL_URL', '$REMOTE_URL');
EOF
        local remote_sql="/tmp/update-urls.sql"
        scp -P "$SSH_PORT" "$temp_sql" "$REMOTE_USER@$REMOTE_HOST:$remote_sql"
        ssh -p "$SSH_PORT" "$REMOTE_USER@$REMOTE_HOST" "
            mysql -u'$REMOTE_DB_USER' -p'$REMOTE_DB_PASS' -h'$REMOTE_DB_HOST' '$REMOTE_DB_NAME' < '$remote_sql' &&
            rm -f '$remote_sql'
        "
        rm -f "$temp_sql"
    fi
    
    log_success "URLs updated"
}

# Update wp-config.php for local environment (remote-to-local only)
update_local_config() {
    log_info "Updating local wp-config.php..."
    
    local config_path="$LOCAL_WP_PATH/wp-config.php"
    
    cp "$config_path" "$config_path.bak.$(date +%Y%m%d_%H%M%S)"
    
    ddev wp config set WP_DEBUG true --raw --project-name="$LOCAL_PROJECT_NAME"
    ddev wp config set WP_DEBUG_LOG true --raw --project-name="$LOCAL_PROJECT_NAME"
    ddev wp config set WP_DEBUG_DISPLAY false --raw --project-name="$LOCAL_PROJECT_NAME"
    ddev wp config set SCRIPT_DEBUG true --raw --project-name="$LOCAL_PROJECT_NAME"
    
    log_success "wp-config.php updated for local development"
}

# Clear caches
clear_caches() {
    local direction="$1"
    
    if [ "$direction" = "remote-to-local" ]; then
        log_info "Clearing local caches..."
        ddev wp cache flush --project-name="$LOCAL_PROJECT_NAME" || true
        ddev wp cache flush-object-cache --project-name="$LOCAL_PROJECT_NAME" || true
        ddev restart "$LOCAL_PROJECT_NAME"
    else
        log_info "Clearing remote caches..."
        ssh -p "$SSH_PORT" "$REMOTE_USER@$REMOTE_HOST" "
            if [ -f '$REMOTE_WP_PATH/wp-content/object-cache.php' ]; then
                rm -f '$REMOTE_WP_PATH/wp-content/object-cache.php'
                echo 'Object cache cleared'
            fi
            if [ -d '$REMOTE_WP_PATH/wp-content/cache' ]; then
                rm -rf '$REMOTE_WP_PATH/wp-content/cache/*'
                echo 'Cache directory cleared'
            fi
        " || log_warning "Could not clear remote caches (may not exist)"
    fi
    
    log_success "Caches cleared"
}

# Final summary
show_summary() {
    local direction="$1"
    
    log_success "✅ Sync completed successfully!"
    echo
    echo "Project: $LOCAL_PROJECT_NAME"
    if [ "$direction" = "remote-to-local" ]; then
        echo "Local URL: $LOCAL_URL"
        echo "Remote source: $REMOTE_USER@$REMOTE_HOST:$SSH_PORT"
        echo
        echo "Next steps:"
        echo "1. Open your browser and visit: $LOCAL_URL"
        echo "2. Login with your WordPress credentials"
        echo "3. Check for any mixed content warnings"
        echo "4. Backups stored in: $LOCAL_WP_PATH/backups/"
    else
        echo "Local URL: $LOCAL_URL"
        echo "Remote URL: $REMOTE_URL"
        echo "Remote server: $REMOTE_USER@$REMOTE_HOST:$SSH_PORT"
        echo
        echo "Next steps:"
        echo "1. Open your browser and visit: $REMOTE_URL"
        echo "2. Login with your WordPress credentials"
        echo "3. Check for any mixed content warnings or broken links"
        echo "4. Verify backups in: $LOCAL_WP_PATH/backups/"
    fi
}

# Prompt for sync direction
prompt_sync_direction() {
    log_info "Select sync direction:"
    echo "1) Remote to Local (Hostinger to DDEV)"
    echo "2) Local to Remote (DDEV to Hostinger)"
    read -p "Enter choice (1 or 2): " choice
    case "$choice" in
        1) echo "remote-to-local" ;;
        2) echo "local-to-remote" ;;
        *) log_error "Invalid choice. Please select 1 or 2." ; exit 1 ;;
    esac
}

# Main execution
main() {
    log_info "Starting WordPress sync..."
    log_info "Project: $LOCAL_PROJECT_NAME"
    log_info "Remote: $REMOTE_USER@$REMOTE_HOST:$SSH_PORT"
    echo
    
    # Prompt for sync direction
    direction=$(prompt_sync_direction)
    
    # Debug: Log the direction to verify
    log_info "Selected direction: $direction"
    
    # Confirm overwrite based on direction
    case "$direction" in
        "remote-to-local")
            read -p "This will overwrite your local database and files in $LOCAL_PROJECT_NAME. Continue? (y/N): " -n 1 -r
            ;;
        "local-to-remote")
            read -p "WARNING: This will overwrite LIVE site data on $REMOTE_HOST. Continue? (y/N): " -n 1 -r
            ;;
        *)
            log_error "Invalid direction value: $direction"
            exit 1
            ;;
    esac
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Operation cancelled by user."
        exit 0
    fi
    
    # Run common steps
    check_dependencies
    verify_ddev_status
    
    # Execute sync based on direction
    if [ "$direction" = "remote-to-local" ]; then
        sync_wp_content "$direction"
        local db_file
        db_file=$(export_database "$direction")
        import_database "$direction" "$db_file"
        update_urls "$direction"
        update_local_config
        clear_caches "$direction"
        show_summary "$direction"
    else
        backup_remote_database
        sync_wp_content "$direction"
        local db_file
        db_file=$(export_database "$direction")
        import_database "$direction" "$db_file"
        update_urls "$direction"
        clear_caches "$direction"
        show_summary "$direction"
    fi
}

# Error handling
trap 'log_error "Script failed at line $LINENO"' ERR

# Run main function
main "$@"
