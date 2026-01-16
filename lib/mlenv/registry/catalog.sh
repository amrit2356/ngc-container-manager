#!/usr/bin/env bash
# MLEnv NGC Catalog Management
# Version: 2.0.0

# Source dependencies
source "${MLENV_LIB}/utils/logging.sh"
source "${MLENV_LIB}/utils/error.sh"
source "${MLENV_LIB}/database/init.sh"

# NGC API configuration
NGC_API_BASE="${NGC_API_BASE:-https://api.ngc.nvidia.com/v2}"
NGC_CACHE_TTL=86400  # 24 hours in seconds

# Popular NGC container categories
declare -a NGC_CATEGORIES=(
    "pytorch"
    "tensorflow"
    "rapids"
    "cuda"
    "tensorrt"
    "tritonserver"
    "deepstream"
    "clara"
    "merlin"
)

# Initialize catalog
catalog_init() {
    vlog "Initializing NGC catalog..."
    
    # Ensure database is initialized
    db_init
    
    # Seed with popular images if empty
    local count
    count=$(db_query "SELECT COUNT(*) FROM ngc_images;" "")
    
    if [[ "$count" -eq 0 ]]; then
        info "Seeding catalog with popular NGC images..."
        catalog_seed_popular
    fi
    
    vlog "Catalog initialized"
}

# Seed with popular NGC images (without API)
catalog_seed_popular() {
    vlog "Seeding popular NGC images..."
    
    # PyTorch
    db_execute "INSERT OR IGNORE INTO ngc_images (organization, team, name, display_name, category, description) VALUES
        ('nvidia', NULL, 'pytorch', 'PyTorch', 'pytorch', 'PyTorch deep learning framework with GPU support'),
        ('nvidia', NULL, 'l4t-pytorch', 'PyTorch for Jetson', 'pytorch', 'PyTorch optimized for NVIDIA Jetson');"
    
    # TensorFlow
    db_execute "INSERT OR IGNORE INTO ngc_images (organization, team, name, display_name, category, description) VALUES
        ('nvidia', NULL, 'tensorflow', 'TensorFlow', 'tensorflow', 'TensorFlow deep learning framework with GPU support'),
        ('nvidia', NULL, 'l4t-tensorflow', 'TensorFlow for Jetson', 'tensorflow', 'TensorFlow optimized for NVIDIA Jetson');"
    
    # RAPIDS
    db_execute "INSERT OR IGNORE INTO ngc_images (organization, team, name, display_name, category, description) VALUES
        ('nvidia', NULL, 'rapidsai', 'RAPIDS', 'rapids', 'GPU-accelerated data science and analytics');"
    
    # CUDA
    db_execute "INSERT OR IGNORE INTO ngc_images (organization, team, name, display_name, category, description) VALUES
        ('nvidia', NULL, 'cuda', 'CUDA', 'cuda', 'NVIDIA CUDA Toolkit base image');"
    
    # TensorRT
    db_execute "INSERT OR IGNORE INTO ngc_images (organization, team, name, display_name, category, description) VALUES
        ('nvidia', NULL, 'tensorrt', 'TensorRT', 'tensorrt', 'High-performance deep learning inference');"
    
    # Triton
    db_execute "INSERT OR IGNORE INTO ngc_images (organization, team, name, display_name, category, description) VALUES
        ('nvidia', NULL, 'tritonserver', 'Triton Inference Server', 'tritonserver', 'Scalable deep learning inference serving');"
    
    # DeepStream
    db_execute "INSERT OR IGNORE INTO ngc_images (organization, team, name, display_name, category, description) VALUES
        ('nvidia', NULL, 'deepstream', 'DeepStream SDK', 'deepstream', 'Real-time video analytics SDK');"
    
    vlog "Seeded popular NGC images"
}

# Search images in catalog
catalog_search() {
    local query="$1"
    local category="${2:-}"
    local limit="${3:-20}"
    
    vlog "Searching catalog: query='$query' category='$category'"
    
    local sql="SELECT 
        organization || '/' || name as full_name,
        display_name,
        category,
        description
    FROM ngc_images"
    
    local where_clauses=()
    
    if [[ -n "$query" ]]; then
        where_clauses+=("(name LIKE '%${query}%' OR display_name LIKE '%${query}%' OR description LIKE '%${query}%')")
    fi
    
    if [[ -n "$category" ]]; then
        where_clauses+=("category = '${category}'")
    fi
    
    if [[ ${#where_clauses[@]} -gt 0 ]]; then
        sql="$sql WHERE ${where_clauses[0]}"
        for ((i=1; i<${#where_clauses[@]}; i++)); do
            sql="$sql AND ${where_clauses[$i]}"
        done
    fi
    
    sql="$sql ORDER BY name LIMIT $limit;"
    
    db_query "$sql" "-column"
}

# List popular images
catalog_list_popular() {
    cat <<'EOF' | db_query "$(cat)" "-column"
SELECT 
    organization || '/' || name as image,
    display_name as name,
    category,
    description
FROM ngc_images
WHERE name IN ('pytorch', 'tensorflow', 'cuda', 'rapids', 'tritonserver', 'tensorrt', 'deepstream')
ORDER BY 
    CASE name
        WHEN 'pytorch' THEN 1
        WHEN 'tensorflow' THEN 2
        WHEN 'cuda' THEN 3
        WHEN 'rapids' THEN 4
        WHEN 'tensorrt' THEN 5
        WHEN 'tritonserver' THEN 6
        ELSE 99
    END;
EOF
}

# List all categories
catalog_list_categories() {
    db_query "SELECT DISTINCT category, COUNT(*) as image_count 
              FROM ngc_images 
              GROUP BY category 
              ORDER BY image_count DESC;" "-column"
}

# Get image details
catalog_get_image() {
    local org="$1"
    local name="$2"
    
    db_query "SELECT * FROM ngc_images 
              WHERE organization='$org' AND name='$name';" "-column"
}

# List available tags/versions for an image
catalog_list_tags() {
    local org="$1"
    local name="$2"
    
    local image_id
    image_id=$(db_query "SELECT id FROM ngc_images WHERE organization='$org' AND name='$name';" "")
    
    if [[ -z "$image_id" ]]; then
        error "Image not found: $org/$name"
        return 1
    fi
    
    db_query "SELECT 
        tag,
        ROUND(size_bytes / 1024.0 / 1024.0 / 1024.0, 2) as size_gb,
        cuda_version,
        python_version,
        framework_version,
        created_at
    FROM image_versions
    WHERE image_id = $image_id
    ORDER BY created_at DESC
    LIMIT 20;" "-column"
}

# Add custom image to catalog
catalog_add_image() {
    local org="$1"
    local name="$2"
    local display_name="${3:-$name}"
    local category="${4:-custom}"
    local description="${5:-Custom image}"
    
    vlog "Adding image to catalog: $org/$name"
    
    db_query "INSERT OR REPLACE INTO ngc_images 
        (organization, name, display_name, category, description, last_synced)
        VALUES ('$org', '$name', '$display_name', '$category', '$description', datetime('now'));" ""
    
    success "Added image: $org/$name"
}

# Remove image from catalog
catalog_remove_image() {
    local org="$1"
    local name="$2"
    
    vlog "Removing image from catalog: $org/$name"
    
    # Get image ID
    local image_id
    image_id=$(db_query "SELECT id FROM ngc_images WHERE organization='$org' AND name='$name';" "")
    
    if [[ -z "$image_id" ]]; then
        error "Image not found: $org/$name"
        return 1
    fi
    
    # Delete versions first
    db_query "DELETE FROM image_versions WHERE image_id = $image_id;" ""
    
    # Delete image
    db_query "DELETE FROM ngc_images WHERE id = $image_id;" ""
    
    success "Removed image: $org/$name"
}

# Get catalog statistics
catalog_stats() {
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "NGC Catalog Statistics"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    local total_images
    total_images=$(db_query "SELECT COUNT(*) FROM ngc_images;" "")
    echo "Total Images: $total_images"
    
    echo ""
    echo "Images by Category:"
    catalog_list_categories
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# Export catalog to JSON
catalog_export() {
    local output_file="${1:-ngc_catalog.json}"
    
    info "Exporting catalog to: $output_file"
    
    db_query "SELECT 
        organization || '/' || name as image,
        display_name,
        category,
        description,
        last_synced
    FROM ngc_images
    ORDER BY organization, name;" "-json" > "$output_file"
    
    success "Catalog exported: $output_file"
}

# Import catalog from JSON
catalog_import() {
    local input_file="$1"
    
    if [[ ! -f "$input_file" ]]; then
        die "Import file not found: $input_file"
    fi
    
    info "Importing catalog from: $input_file"
    
    # Use jq to parse and insert
    if command -v jq >/dev/null 2>&1; then
        local count=0
        while IFS= read -r line; do
            local org=$(echo "$line" | jq -r '.image' | cut -d'/' -f1)
            local name=$(echo "$line" | jq -r '.image' | cut -d'/' -f2)
            local display_name=$(echo "$line" | jq -r '.display_name')
            local category=$(echo "$line" | jq -r '.category')
            local description=$(echo "$line" | jq -r '.description')
            
            catalog_add_image "$org" "$name" "$display_name" "$category" "$description"
            ((count++))
        done < <(jq -c '.[]' "$input_file")
        
        success "Imported $count images"
    else
        warn "jq not available - cannot import JSON"
        return 1
    fi
}
