#!/usr/bin/env bash
# MLEnv Catalog Command
# Version: 2.1.0 - Context-based

cmd_catalog() {
    # Source catalog module
    source "${MLENV_LIB}/registry/catalog.sh"
    
    local subcmd="${1:-list}"
    shift || true
    
    case "$subcmd" in
        init)
            catalog_init || {
                error_with_help "Failed to initialize catalog" "config_error"
                return 1
            }
            ;;
        search)
            local query="${1:-}"
            local category="${2:-}"
            catalog_search "$query" "$category" || {
                error_with_help "Search failed" "config_error"
                return 1
            }
            ;;
        list)
            catalog_list_popular || {
                error_with_help "Failed to list catalog" "config_error"
                return 1
            }
            ;;
        add)
            if [[ $# -lt 2 ]]; then
                error_with_help "Organization and name required" "invalid_argument"
                info "Usage: mlenv catalog add <org> <name> [display_name] [category] [description]"
                return 1
            fi
            catalog_add_image "$@" || {
                error_with_help "Failed to add image" "config_error"
                return 1
            }
            ;;
        remove)
            if [[ $# -lt 2 ]]; then
                error_with_help "Organization and name required" "invalid_argument"
                info "Usage: mlenv catalog remove <org> <name>"
                return 1
            fi
            catalog_remove_image "$1" "$2" || {
                error_with_help "Failed to remove image" "config_error"
                return 1
            }
            ;;
        stats)
            catalog_stats || {
                error_with_help "Failed to show stats" "config_error"
                return 1
            }
            ;;
        categories)
            catalog_list_categories || {
                error_with_help "Failed to list categories" "config_error"
                return 1
            }
            ;;
        export)
            local output="${1:-ngc_catalog.json}"
            catalog_export "$output" || {
                error_with_help "Failed to export catalog" "config_error"
                return 1
            }
            ;;
        import)
            if [[ -z "$1" ]]; then
                error_with_help "Import file required" "invalid_argument"
                info "Usage: mlenv catalog import <file>"
                return 1
            fi
            catalog_import "$1" || {
                error_with_help "Failed to import catalog" "config_error"
                return 1
            }
            ;;
        *)
            echo "Usage: mlenv catalog {init|search|list|add|remove|stats|categories|export|import}"
            echo ""
            echo "Commands:"
            echo "  init                    Initialize catalog database"
            echo "  search [query] [cat]    Search NGC images (optional category filter)"
            echo "  list                    List popular images by category"
            echo "  add <org> <name> ...    Add custom image to catalog"
            echo "  remove <org> <name>     Remove image from catalog"
            echo "  stats                   Show catalog statistics"
            echo "  categories              List all categories"
            echo "  export [file]           Export catalog to JSON"
            echo "  import <file>           Import catalog from JSON"
            return 1
            ;;
    esac
    
    return 0
}
