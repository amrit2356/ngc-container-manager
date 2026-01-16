#!/usr/bin/env bash
# MLEnv Catalog Command
# Version: 2.0.0

cmd_catalog() {
    # Source catalog module
    source "${MLENV_LIB}/registry/catalog.sh"
    
    local subcmd="${1:-list}"
    shift || true
    
    case "$subcmd" in
        init)
            catalog_init
            ;;
        search)
            local query="${1:-}"
            local category="${2:-}"
            catalog_search "$query" "$category"
            ;;
        list)
            catalog_list_popular
            ;;
        add)
            if [[ $# -lt 2 ]]; then
                die "Usage: mlenv catalog add <org> <name> [display_name] [category] [description]"
            fi
            catalog_add_image "$@"
            ;;
        remove)
            if [[ $# -lt 2 ]]; then
                die "Usage: mlenv catalog remove <org> <name>"
            fi
            catalog_remove_image "$1" "$2"
            ;;
        stats)
            catalog_stats
            ;;
        categories)
            catalog_list_categories
            ;;
        export)
            local output="${1:-ngc_catalog.json}"
            catalog_export "$output"
            ;;
        import)
            if [[ -z "$1" ]]; then
                die "Usage: mlenv catalog import <file>"
            fi
            catalog_import "$1"
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
            ;;
    esac
}
