#!/usr/bin/env bash
# MLEnv Init Command
# Version: 2.0.0

cmd_init() {
    # Source template engine
    source "${MLENV_LIB}/templates/engine.sh"
    
    # Initialize template system
    template_init
    
    # Parse flags
    local list_templates=false
    local template_name=""
    local project_name=""
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --list|-l)
                list_templates=true
                shift
                ;;
            --template|-t)
                template_name="$2"
                shift 2
                ;;
            *)
                # First non-flag argument is project name
                if [[ -z "$project_name" ]]; then
                    project_name="$1"
                fi
                shift
                ;;
        esac
    done
    
    # Handle --list flag
    if [[ "$list_templates" == "true" ]]; then
        template_list
        return 0
    fi
    
    # Require template name
    if [[ -z "$template_name" ]]; then
        echo "Usage: mlenv init --template <template-name> [project-name]"
        echo ""
        echo "Options:"
        echo "  --list, -l              List available templates"
        echo "  --template <name>, -t   Template name (required)"
        echo ""
        echo "Examples:"
        echo "  mlenv init --list"
        echo "  mlenv init --template pytorch my-project"
        echo "  mlenv init --template minimal my-experiment"
        echo ""
        echo "Available templates:"
        template_list
        return 1
    fi
    
    # Determine project directory and name
    local project_dir="${project_name:-.}"
    local final_project_name
    if [[ -n "$project_name" ]]; then
        final_project_name="$(basename "$project_name")"
    else
        final_project_name="$(basename "$(pwd)")"
    fi
    
    # If project name provided and directory doesn't exist, create it
    if [[ -n "$project_name" ]] && [[ ! -d "$project_dir" ]]; then
        info "Creating project directory: $project_dir"
        mkdir -p "$project_dir" || die "Failed to create directory: $project_dir"
    fi
    
    # Check if directory is empty (unless it's current directory)
    if [[ "$project_dir" != "." ]] && [[ -d "$project_dir" ]]; then
        local file_count=$(find "$project_dir" -mindepth 1 -maxdepth 1 2>/dev/null | wc -l)
        if [[ $file_count -gt 0 ]]; then
            warn "Directory '$project_dir' is not empty"
            read -p "Continue anyway? [y/N] " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                info "Cancelled"
                return 0
            fi
        fi
    fi
    
    # Get template path to check if it exists
    local template_path
    template_path=$(template_get_path "$template_name")
    
    if [[ $? -ne 0 ]]; then
        error "Template not found: $template_name"
        echo ""
        echo "Available templates:"
        template_list
        return 1
    fi
    
    # Show template info
    echo ""
    info "Template: $template_name"
    
    # Try to get template metadata
    if [[ -f "$template_path/template.yaml" ]]; then
        local desc=$(grep "^description:" "$template_path/template.yaml" | cut -d: -f2- | xargs)
        if [[ -n "$desc" ]]; then
            info "Description: $desc"
        fi
        
        # Check for default image in template
        local default_image=$(grep "^  image:" "$template_path/template.yaml" | head -1 | cut -d: -f2- | xargs)
        if [[ -n "$default_image" ]]; then
            info "Default image: $default_image"
        fi
    fi
    
    echo ""
    
    # Save original directory
    local orig_dir="$(pwd)"
    
    # Apply template (this will cd into project_dir)
    template_apply "$template_name" "$project_dir" "$final_project_name" || true
    local apply_result=$?
    
    # Return to original directory if template_apply changed it
    if [[ "$apply_result" -eq 0 ]]; then
        # template_apply succeeded, now create .mlenvrc in the project directory
        local abs_project_dir
        if [[ "$project_dir" = /* ]]; then
            abs_project_dir="$project_dir"
        elif [[ "$project_dir" == "." ]]; then
            abs_project_dir="$orig_dir"
        else
            abs_project_dir="$orig_dir/$project_dir"
        fi
        
        # Create .mlenvrc if template has defaults
        if [[ -f "$template_path/template.yaml" ]]; then
            local default_image=$(grep "^  image:" "$template_path/template.yaml" | head -1 | cut -d: -f2- | xargs)
            if [[ -n "$default_image" ]]; then
                local mlenvrc="$abs_project_dir/.mlenvrc"
                if [[ ! -f "$mlenvrc" ]]; then
                    vlog "Creating .mlenvrc with template defaults..."
                    {
                        echo "# MLEnv Configuration"
                        echo "# Generated from template: $template_name"
                        echo ""
                        echo "DEFAULT_IMAGE=$default_image"
                        
                        # Extract ports if available
                        local ports=$(grep "^    - " "$template_path/template.yaml" | grep -E "[0-9]+:[0-9]+" | sed 's/.*- //' | tr '\n' ',' | sed 's/,$//' | xargs)
                        if [[ -n "$ports" ]]; then
                            echo "DEFAULT_PORTS=$ports"
                        fi
                        
                        # Extract GPU devices if available
                        local gpu_devices=$(grep "^  gpu_devices:" "$template_path/template.yaml" | cut -d: -f2- | xargs)
                        if [[ -n "$gpu_devices" ]]; then
                            echo "DEFAULT_GPUS=$gpu_devices"
                        fi
                    } > "$mlenvrc"
                    success "Created .mlenvrc"
                fi
            fi
        fi
        
        echo ""
        success "Project initialized successfully!"
        echo ""
        info "Next steps:"
        if [[ "$project_dir" != "." ]]; then
            echo "  cd $project_dir"
        fi
        echo "  mlenv up"
        echo "  mlenv exec"
        
        # Return to original directory
        cd "$orig_dir" || true
    else
        die "Template apply failed"
    fi
}
