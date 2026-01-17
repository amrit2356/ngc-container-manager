-- MLEnv NGC Registry Database Schema
-- Version: 2.0.0

-- NGC Images Catalog
CREATE TABLE IF NOT EXISTS ngc_images (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    display_name TEXT,
    organization TEXT NOT NULL,
    team TEXT,
    category TEXT,              -- pytorch, tensorflow, rapids, etc.
    description TEXT,
    created_at DATETIME,
    updated_at DATETIME,
    last_synced DATETIME DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(organization, team, name)
);

-- Image Versions/Tags
CREATE TABLE IF NOT EXISTS image_versions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    image_id INTEGER NOT NULL,
    tag TEXT NOT NULL,
    digest TEXT,
    size_bytes INTEGER,
    created_at DATETIME,
    cuda_version TEXT,
    python_version TEXT,
    framework_version TEXT,
    architecture TEXT DEFAULT 'amd64',
    manifest_json TEXT,         -- Full manifest
    is_cached BOOLEAN DEFAULT 0,
    FOREIGN KEY (image_id) REFERENCES ngc_images(id),
    UNIQUE(image_id, tag)
);

-- Container Instances (Running/Stopped)
CREATE TABLE IF NOT EXISTS container_instances (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    container_id TEXT NOT NULL UNIQUE,
    container_name TEXT NOT NULL,
    image_name TEXT NOT NULL,
    project_path TEXT NOT NULL,
    status TEXT DEFAULT 'created',  -- created, running, stopped, error
    
    -- Resource allocation
    cpu_limit REAL,
    memory_limit_gb REAL,
    gpu_devices TEXT,           -- JSON array
    
    -- Port mappings
    port_mappings TEXT,         -- JSON
    
    -- Timestamps
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    started_at DATETIME,
    stopped_at DATETIME,
    
    -- Metrics
    cpu_usage_avg REAL,
    memory_usage_avg_gb REAL,
    gpu_utilization_avg REAL
);

-- Resource Usage History
CREATE TABLE IF NOT EXISTS resource_metrics (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    container_id TEXT NOT NULL,
    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
    
    -- System resources
    cpu_percent REAL,
    memory_used_gb REAL,
    memory_percent REAL,
    
    -- GPU resources (JSON array for multi-GPU)
    gpu_metrics TEXT,           -- [{gpu_id, utilization, memory_used, memory_total}]
    
    -- I/O
    disk_read_mb REAL,
    disk_write_mb REAL,
    network_rx_mb REAL,
    network_tx_mb REAL,
    
    FOREIGN KEY (container_id) REFERENCES container_instances(container_id)
);

-- System Resource Snapshots
CREATE TABLE IF NOT EXISTS system_snapshots (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
    
    -- CPU
    cpu_percent REAL,
    cpu_cores INTEGER,
    
    -- Memory
    memory_total_gb REAL,
    memory_used_gb REAL,
    memory_available_gb REAL,
    memory_percent REAL,
    
    -- GPU (JSON array)
    gpu_stats TEXT,
    
    -- Load average
    load_1min REAL,
    load_5min REAL,
    load_15min REAL
);

-- NGC API Cache
CREATE TABLE IF NOT EXISTS api_cache (
    endpoint TEXT PRIMARY KEY,
    response TEXT,
    cached_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    expires_at DATETIME
);

-- Project Quotas
CREATE TABLE IF NOT EXISTS project_quotas (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    project_path TEXT NOT NULL UNIQUE,
    max_containers INTEGER DEFAULT 5,
    max_cpu_cores REAL,
    max_memory_gb REAL,
    max_gpus INTEGER,
    current_containers INTEGER DEFAULT 0,
    current_cpu_cores REAL DEFAULT 0,
    current_memory_gb REAL DEFAULT 0,
    current_gpus INTEGER DEFAULT 0
);

-- GPU Allocations (for reservation system)
CREATE TABLE IF NOT EXISTS gpu_allocations (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    gpu_id INTEGER NOT NULL,
    container_name TEXT NOT NULL,
    allocated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(gpu_id, container_name)
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_images_category ON ngc_images(category);
CREATE INDEX IF NOT EXISTS idx_images_org ON ngc_images(organization);
CREATE INDEX IF NOT EXISTS idx_versions_image ON image_versions(image_id);
CREATE INDEX IF NOT EXISTS idx_containers_status ON container_instances(status);
CREATE INDEX IF NOT EXISTS idx_containers_project ON container_instances(project_path);
CREATE INDEX IF NOT EXISTS idx_metrics_container ON resource_metrics(container_id);
CREATE INDEX IF NOT EXISTS idx_metrics_timestamp ON resource_metrics(timestamp);
CREATE INDEX IF NOT EXISTS idx_snapshots_timestamp ON system_snapshots(timestamp);
CREATE INDEX IF NOT EXISTS idx_gpu_allocations_gpu ON gpu_allocations(gpu_id);
CREATE INDEX IF NOT EXISTS idx_gpu_allocations_container ON gpu_allocations(container_name);

-- Views for common queries

-- Active containers with resource usage
CREATE VIEW IF NOT EXISTS v_active_containers AS
SELECT 
    ci.container_name,
    ci.image_name,
    ci.project_path,
    ci.status,
    ci.cpu_limit,
    ci.memory_limit_gb,
    ci.gpu_devices,
    ci.created_at,
    ci.started_at,
    ROUND(AVG(rm.cpu_percent), 2) as avg_cpu,
    ROUND(AVG(rm.memory_used_gb), 2) as avg_memory_gb
FROM container_instances ci
LEFT JOIN resource_metrics rm ON ci.container_id = rm.container_id
    AND rm.timestamp > datetime('now', '-5 minutes')
WHERE ci.status = 'running'
GROUP BY ci.container_id;

-- System resource summary
CREATE VIEW IF NOT EXISTS v_system_summary AS
SELECT 
    ROUND(AVG(cpu_percent), 2) as avg_cpu_percent,
    ROUND(MAX(cpu_percent), 2) as max_cpu_percent,
    ROUND(AVG(memory_percent), 2) as avg_memory_percent,
    ROUND(MAX(memory_percent), 2) as max_memory_percent,
    ROUND(AVG(memory_available_gb), 2) as avg_available_gb,
    COUNT(*) as snapshot_count
FROM system_snapshots
WHERE timestamp > datetime('now', '-1 hour');
