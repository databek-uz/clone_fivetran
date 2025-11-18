// =============================================================================
// PipeZone Dashboard - Main Application
// =============================================================================

// Global state
const state = {
    user: null,
    cluster: 'medium_cluster',
    services: {
        minio: { status: 'unknown', data: {} },
        spark: { status: 'unknown', data: {} },
        airflow: { status: 'unknown', data: {} }
    },
    notebooks: []
};

// Initialize application
document.addEventListener('DOMContentLoaded', async () => {
    console.log('🚀 PipeZone Dashboard initializing...');

    try {
        // Load user info
        await loadUserInfo();

        // Load saved cluster selection
        loadClusterSelection();

        // Load recent notebooks
        await loadRecentNotebooks();

        // Start service status polling
        startServicePolling();

        // Set up keyboard shortcuts
        setupKeyboardShortcuts();

        console.log('✓ Dashboard initialized successfully');
    } catch (error) {
        console.error('Failed to initialize dashboard:', error);
        showNotification('Failed to load dashboard', 'error');
    }
});

// =============================================================================
// User Management
// =============================================================================

async function loadUserInfo() {
    try {
        // Try to get user from environment or localStorage
        const username = localStorage.getItem('pipezone_user') ||
                        getUsernameFromEnv() ||
                        'default';

        state.user = username;
        document.getElementById('userName').textContent = username;

        console.log('✓ User loaded:', username);
    } catch (error) {
        console.error('Failed to load user info:', error);
        state.user = 'default';
        document.getElementById('userName').textContent = 'Default User';
    }
}

function getUsernameFromEnv() {
    // In a real implementation, this would be injected by the server
    return window.PIPEZONE_USER || null;
}

// =============================================================================
// Cluster Management
// =============================================================================

function loadClusterSelection() {
    const savedCluster = localStorage.getItem('pipezone_cluster') || 'medium_cluster';
    state.cluster = savedCluster;

    // Update UI
    const radio = document.querySelector(`input[value="${savedCluster}"]`);
    if (radio) {
        radio.checked = true;
    }

    // Update badge
    const clusterNames = {
        'small_cluster': 'Small',
        'medium_cluster': 'Medium',
        'large_cluster': 'Large'
    };
    document.getElementById('clusterBadge').textContent = clusterNames[savedCluster] || 'Medium';

    console.log('✓ Cluster loaded:', savedCluster);
}

function saveClusterSelection() {
    const selectedRadio = document.querySelector('input[name="cluster"]:checked');
    if (!selectedRadio) {
        showNotification('Please select a cluster', 'warning');
        return;
    }

    const cluster = selectedRadio.value;
    state.cluster = cluster;

    // Save to localStorage
    localStorage.setItem('pipezone_cluster', cluster);

    // Update environment variable (would be done via API in production)
    console.log('Setting SELECTED_CLUSTER to:', cluster);

    // Update badge
    const clusterNames = {
        'small_cluster': 'Small',
        'medium_cluster': 'Medium',
        'large_cluster': 'Large'
    };
    document.getElementById('clusterBadge').textContent = clusterNames[cluster];

    showNotification(`Cluster configuration saved: ${clusterNames[cluster]}`, 'success');
    console.log('✓ Cluster saved:', cluster);
}

// =============================================================================
// Service Polling
// =============================================================================

function startServicePolling() {
    // Initial load
    updateAllServices();

    // Poll every 30 seconds
    setInterval(updateAllServices, 30000);

    console.log('✓ Service polling started');
}

async function updateAllServices() {
    try {
        await Promise.all([
            updateMinioStatus(),
            updateSparkStatus(),
            updateAirflowStatus()
        ]);
    } catch (error) {
        console.error('Failed to update services:', error);
    }
}

// =============================================================================
// Recent Notebooks
// =============================================================================

async function loadRecentNotebooks() {
    try {
        const notebookList = document.getElementById('notebookList');
        notebookList.innerHTML = '<p class="loading">Loading notebooks...</p>';

        // In production, this would fetch from API
        // For now, simulate with dummy data
        await new Promise(resolve => setTimeout(resolve, 500));

        const notebooks = [
            { name: 'data_analysis.ipynb', path: '/workspace/data_analysis.ipynb', modified: '2 hours ago' },
            { name: 'ml_model_training.ipynb', path: '/workspace/ml_model_training.ipynb', modified: '1 day ago' },
            { name: 'etl_pipeline.ipynb', path: '/shared/notebooks/etl_pipeline.ipynb', modified: '3 days ago' },
        ];

        state.notebooks = notebooks;

        if (notebooks.length === 0) {
            notebookList.innerHTML = '<p class="loading">No recent notebooks</p>';
            return;
        }

        notebookList.innerHTML = notebooks.map(nb => `
            <div class="notebook-item fade-in">
                <div class="notebook-info">
                    <div class="notebook-name">📓 ${nb.name}</div>
                    <div class="notebook-meta">Modified ${nb.modified}</div>
                </div>
                <div class="notebook-actions">
                    <button class="icon-btn" onclick="openNotebook('${nb.path}')" title="Open">
                        📂
                    </button>
                    <button class="icon-btn" onclick="scheduleNotebook('${nb.path}')" title="Schedule">
                        ⏰
                    </button>
                </div>
            </div>
        `).join('');

        console.log('✓ Notebooks loaded:', notebooks.length);
    } catch (error) {
        console.error('Failed to load notebooks:', error);
        document.getElementById('notebookList').innerHTML =
            '<p class="loading" style="color: var(--status-error);">Failed to load notebooks</p>';
    }
}

// =============================================================================
// Quick Actions
// =============================================================================

function createNotebook() {
    const notebookName = prompt('Enter notebook name:', 'new_notebook.ipynb');
    if (!notebookName) return;

    // Ensure .ipynb extension
    const name = notebookName.endsWith('.ipynb') ? notebookName : `${notebookName}.ipynb`;

    console.log('Creating notebook:', name);
    showNotification(`Creating notebook: ${name}`, 'success');

    // In production, this would create the file and open it
    setTimeout(() => {
        window.location.href = `/vscode?folder=/home/coder/workspace&file=${name}`;
    }, 500);
}

function scheduleJob() {
    console.log('Opening job scheduler...');
    showNotification('Opening job scheduler...', 'info');

    // In production, this would open the scheduler UI
    setTimeout(() => {
        openAirflow();
    }, 500);
}

function openShared() {
    console.log('Opening shared folder...');
    window.location.href = '/vscode?folder=/home/coder/shared';
}

function uploadToMinio() {
    console.log('Opening MinIO uploader...');
    showNotification('Opening MinIO console...', 'info');

    setTimeout(() => {
        openMinio();
    }, 500);
}

// =============================================================================
// Service Links
// =============================================================================

function openMinio() {
    const minioUrl = getServiceUrl('minio', 9001);
    window.open(minioUrl, '_blank');
}

function openSparkUI() {
    const sparkUrl = getServiceUrl('spark-history-server', 18080);
    window.open(sparkUrl, '_blank');
}

function openAirflow() {
    const airflowUrl = getServiceUrl('airflow-webserver', 8081);
    window.open(airflowUrl, '_blank');
}

function openJupyter() {
    const jupyterUrl = getServiceUrl('jupyter', 8888);
    window.open(jupyterUrl, '_blank');
}

function getServiceUrl(service, port) {
    // In production, this would be properly configured
    const host = window.location.hostname;
    return `http://${host}:${port}`;
}

// =============================================================================
// Notebook Actions
// =============================================================================

function openNotebook(path) {
    console.log('Opening notebook:', path);
    window.location.href = `/vscode?file=${path}`;
}

function scheduleNotebook(path) {
    console.log('Scheduling notebook:', path);
    showNotification(`Opening scheduler for: ${path}`, 'info');

    // In production, this would open the scheduling dialog
    setTimeout(() => {
        openAirflow();
    }, 500);
}

// =============================================================================
// Keyboard Shortcuts
// =============================================================================

function setupKeyboardShortcuts() {
    document.addEventListener('keydown', (e) => {
        // Ctrl/Cmd + N: New Notebook
        if ((e.ctrlKey || e.metaKey) && e.key === 'n') {
            e.preventDefault();
            createNotebook();
        }

        // Ctrl/Cmd + Shift + S: Schedule Job
        if ((e.ctrlKey || e.metaKey) && e.shiftKey && e.key === 's') {
            e.preventDefault();
            scheduleJob();
        }

        // Ctrl/Cmd + Shift + F: Open Shared
        if ((e.ctrlKey || e.metaKey) && e.shiftKey && e.key === 'f') {
            e.preventDefault();
            openShared();
        }
    });

    console.log('✓ Keyboard shortcuts enabled');
}

// =============================================================================
// Utilities
// =============================================================================

function showNotification(message, type = 'info') {
    // Simple console notification for now
    const emoji = {
        'success': '✓',
        'error': '✗',
        'warning': '⚠',
        'info': 'ℹ'
    }[type] || 'ℹ';

    console.log(`${emoji} ${message}`);

    // In production, this would show a toast notification
}

function formatBytes(bytes) {
    if (bytes === 0) return '0 B';
    const k = 1024;
    const sizes = ['B', 'KB', 'MB', 'GB', 'TB'];
    const i = Math.floor(Math.log(bytes) / Math.log(k));
    return Math.round(bytes / Math.pow(k, i) * 100) / 100 + ' ' + sizes[i];
}

function formatRelativeTime(timestamp) {
    const now = Date.now();
    const diff = now - timestamp;

    const seconds = Math.floor(diff / 1000);
    const minutes = Math.floor(seconds / 60);
    const hours = Math.floor(minutes / 60);
    const days = Math.floor(hours / 24);

    if (days > 0) return `${days} day${days > 1 ? 's' : ''} ago`;
    if (hours > 0) return `${hours} hour${hours > 1 ? 's' : ''} ago`;
    if (minutes > 0) return `${minutes} minute${minutes > 1 ? 's' : ''} ago`;
    return 'Just now';
}

// =============================================================================
// Export for testing
// =============================================================================

if (typeof module !== 'undefined' && module.exports) {
    module.exports = {
        state,
        loadUserInfo,
        loadClusterSelection,
        saveClusterSelection,
        createNotebook,
        openNotebook
    };
}

console.log('✓ PipeZone Dashboard loaded');
