#!/bin/bash

################################################################################
# DISK USAGE REPORT
# Monitor disk space usage for all applications
#
# Shows:
# - Per-app breakdown (repos, staging, production)
# - Total disk per app
# - Savings from symlinks
# - Overall statistics
#
# Usage:
#   bash disk-usage-report.sh [--detailed|--summary|--sort] [--save-report]
#
# Examples:
#   bash disk-usage-report.sh              (summary)
#   bash disk-usage-report.sh --detailed   (per-folder breakdown)
#   bash disk-usage-report.sh --sort       (sorted by size)
#   bash disk-usage-report.sh --save-report (save to file)
################################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
GRAY='\033[0;37m'
NC='\033[0m'

# Configuration
APPS_DIR="$HOME/apps"
REPORT_FILE="$APPS_DIR/.disk-usage-report-$(date +%Y%m%d-%H%M%S).txt"

# Functions
print_header() {
    echo -e "\n${BLUE}════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}\n"
}

print_row() {
    printf "%-20s %12s %12s %12s %12s\n" "$1" "$2" "$3" "$4" "$5"
}

get_size_bytes() {
    local path=$1
    if [ -d "$path" ]; then
        du -sb "$path" 2>/dev/null | awk '{print $1}'
    else
        echo "0"
    fi
}

format_bytes() {
    local bytes=$1
    if [ "$bytes" -lt 1024 ]; then
        echo "${bytes}B"
    elif [ "$bytes" -lt 1048576 ]; then
        printf "%.1fKB" $(echo "scale=1; $bytes / 1024" | bc)
    elif [ "$bytes" -lt 1073741824 ]; then
        printf "%.1fMB" $(echo "scale=1; $bytes / 1048576" | bc)
    else
        printf "%.1fGB" $(echo "scale=1; $bytes / 1073741824" | bc)
    fi
}

is_symlink() {
    local path=$1
    if [ -L "$path" ]; then
        echo "✓"
    else
        echo " "
    fi
}

# ============================================================================
# MAIN REPORTING
# ============================================================================

REPORT_MODE=${1:-summary}
SAVE_REPORT=false

# Parse arguments
for arg in "$@"; do
    case $arg in
        --save-report)
            SAVE_REPORT=true
            ;;
    esac
done

# Collect data
declare -A app_repos_size
declare -A app_staging_size
declare -A app_staging_symlink
declare -A app_prod_size
declare -A app_total_size

total_repos=0
total_staging=0
total_prod=0
total_all=0

symlink_count=0
total_apps=0

print_header "Collecting disk usage data..."

apps_list=$(ls -d "$APPS_DIR/repos"/*/ 2>/dev/null | xargs -n1 basename | sort)

if [ -z "$apps_list" ]; then
    echo -e "${RED}✗ No apps found in $APPS_DIR/repos${NC}"
    exit 1
fi

for app in $apps_list; do
    ((total_apps++))
    
    repos_path="$APPS_DIR/repos/$app/node_modules"
    staging_path="$APPS_DIR/staging/$app/node_modules"
    prod_path="$APPS_DIR/production/$app/node_modules"
    
    # Get sizes
    repos_bytes=$(get_size_bytes "$repos_path")
    staging_bytes=$(get_size_bytes "$staging_path")
    prod_bytes=$(get_size_bytes "$prod_path")
    
    app_repos_size[$app]=$repos_bytes
    app_staging_size[$app]=$staging_bytes
    app_prod_size[$app]=$prod_bytes
    
    # Check if staging is symlink
    if [ -L "$staging_path" ]; then
        app_staging_symlink[$app]="✓"
        ((symlink_count++))
        # Symlink doesn't use disk space
        staging_bytes=0
    else
        app_staging_symlink[$app]=" "
    fi
    
    # Calculate totals
    app_total=$((repos_bytes + staging_bytes + prod_bytes))
    app_total_size[$app]=$app_total
    
    total_repos=$((total_repos + repos_bytes))
    total_staging=$((total_staging + staging_bytes))
    total_prod=$((total_prod + prod_bytes))
    total_all=$((total_all + app_total))
done

# ============================================================================
# OUTPUT REPORTS
# ============================================================================

# Start output
{
    print_header "DISK USAGE REPORT - $(date '+%Y-%m-%d %H:%M:%S')"
    
    # Summary statistics
    echo -e "${CYAN}Summary Statistics:${NC}"
    echo "  Total Apps: $total_apps"
    echo "  Apps with Symlinks: $symlink_count"
    echo "  Symlink Coverage: $(echo "scale=1; $symlink_count * 100 / $total_apps" | bc)%"
    echo ""
    echo "  Total Disk Usage:"
    echo "    Repos:      $(format_bytes $total_repos)"
    echo "    Staging:    $(format_bytes $total_staging)"
    echo "    Production: $(format_bytes $total_prod)"
    echo "    ───────────────────"
    echo "    TOTAL:      $(format_bytes $total_all)"
    echo ""
    
    # Savings calculation
    if [ $symlink_count -gt 0 ]; then
        # If all were independent (without symlinks)
        theoretical_max=$((total_repos * 2 + total_prod))
        savings=$((theoretical_max - total_all))
        savings_pct=$(echo "scale=1; $savings * 100 / $theoretical_max" | bc)
        
        echo -e "${GREEN}Savings from Symlinks:${NC}"
        echo "  Potential without symlinks: $(format_bytes $theoretical_max)"
        echo "  Current with symlinks:      $(format_bytes $total_all)"
        echo "  Space saved:                $(format_bytes $savings) ($savings_pct%)"
        echo ""
    fi
    
    # Average per app
    avg_per_app=$((total_all / total_apps))
    echo "  Average per app: $(format_bytes $avg_per_app)"
    echo ""
    
    # Detailed breakdown
    if [ "$REPORT_MODE" != "summary" ]; then
        print_header "PER-APP BREAKDOWN"
        
        echo -e "${CYAN}Detailed View:${NC}"
        print_row "App Name" "Repos" "Staging" "Prod" "Total"
        echo "────────────────────────────────────────────────────────────"
        
        # Sort apps by total size if --sort flag
        if [ "$REPORT_MODE" == "sort" ]; then
            apps_list=$(echo "$apps_list" | while read app; do
                echo "${app_total_size[$app]} $app"
            done | sort -rn | awk '{print $2}')
        fi
        
        for app in $apps_list; do
            repos_fmt=$(format_bytes ${app_repos_size[$app]})
            staging_fmt=$(format_bytes ${app_staging_size[$app]})
            prod_fmt=$(format_bytes ${app_prod_size[$app]})
            total_fmt=$(format_bytes ${app_total_size[$app]})
            
            printf "%-20s %12s %12s %12s %12s\n" "$app" "$repos_fmt" "$staging_fmt" "$prod_fmt" "$total_fmt"
        done
        
        echo "════════════════════════════════════════════════════════════"
        echo ""
        
        if [ "$REPORT_MODE" == "detailed" ] || [ "$REPORT_MODE" == "sort" ]; then
            print_header "SYMLINK STATUS"
            
            echo -e "${CYAN}Staging Symlinks:${NC}"
            for app in $apps_list; do
                status="${app_staging_symlink[$app]}"
                if [ "$status" == "✓" ]; then
                    target=$(readlink "$APPS_DIR/staging/$app/node_modules" 2>/dev/null || echo "N/A")
                    echo -e "  $app: ${GREEN}✓${NC} (points to $target)"
                else
                    echo -e "  $app: ${YELLOW} ${NC} (independent copy)"
                fi
            done
            echo ""
        fi
    fi
    
    # Recommendations
    print_header "OPTIMIZATION RECOMMENDATIONS"
    
    echo -e "${CYAN}Current Status:${NC}"
    
    if [ $symlink_count -eq $total_apps ]; then
        echo -e "  ${GREEN}✓ All apps using symlinks - Excellent!${NC}"
        echo "  Staging directory optimized."
        echo ""
    elif [ $symlink_count -gt 0 ]; then
        unoptimized=$((total_apps - symlink_count))
        echo -e "  ${YELLOW}⚠ $unoptimized apps not using symlinks yet${NC}"
        echo "  Potential additional savings: $(format_bytes $((unoptimized * 300 * 1024 * 1024)))"
        echo ""
        echo -e "${CYAN}To optimize remaining apps:${NC}"
        echo "  ./node_modules-optimizer.sh all init"
        echo ""
    else
        echo -e "  ${YELLOW}⚠ No apps using symlinks yet${NC}"
        echo "  Potential additional savings: $(format_bytes $((total_apps * 300 * 1024 * 1024)))"
        echo ""
        echo -e "${CYAN}To optimize all apps:${NC}"
        echo "  ./node_modules-optimizer.sh all init"
        echo ""
    fi
    
    # Disk space warnings
    echo -e "${CYAN}Disk Space Alerts:${NC}"
    
    disk_usage=$(df -h "$APPS_DIR" | tail -1 | awk '{print $(NF-1)}' | tr -d '%')
    if [ "$disk_usage" -gt 80 ]; then
        echo -e "  ${RED}✗ WARNING: $disk_usage% disk usage (critical)${NC}"
        echo "    Cleanup required immediately"
    elif [ "$disk_usage" -gt 60 ]; then
        echo -e "  ${YELLOW}⚠ CAUTION: $disk_usage% disk usage (high)${NC}"
        echo "    Consider cleanup after next deployment"
    else
        echo -e "  ${GREEN}✓ Disk usage: $disk_usage% (healthy)${NC}"
    fi
    echo ""
    
    # Footer
    echo -e "${GRAY}Report generated: $(date '+%Y-%m-%d %H:%M:%S')${NC}"
    
} | tee /tmp/disk-report.tmp

# Copy to screen
cat /tmp/disk-report.tmp

# Optionally save to file
if [ "$SAVE_REPORT" = true ]; then
    cp /tmp/disk-report.tmp "$REPORT_FILE"
    echo ""
    echo -e "${GREEN}✓ Report saved to: $REPORT_FILE${NC}"
fi

rm -f /tmp/disk-report.tmp
