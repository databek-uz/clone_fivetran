// =============================================================================
// Cluster Selector Component
// =============================================================================

const ClusterSelector = {
    currentCluster: 'medium_cluster',

    init() {
        console.log('Initializing cluster selector component...');
        this.loadSavedCluster();
        this.setupEventListeners();
    },

    loadSavedCluster() {
        const saved = localStorage.getItem('pipezone_cluster');
        if (saved) {
            this.currentCluster = saved;
            this.updateUI();
        }
    },

    setupEventListeners() {
        // Listen for cluster radio button changes
        const radios = document.querySelectorAll('input[name="cluster"]');
        radios.forEach(radio => {
            radio.addEventListener('change', (e) => {
                this.onClusterChange(e.target.value);
            });
        });
    },

    onClusterChange(cluster) {
        console.log('Cluster selection changed:', cluster);
        this.currentCluster = cluster;
        this.updatePreview(cluster);
    },

    updatePreview(cluster) {
        const config = getClusterConfig(cluster);

        // Show a preview of what resources this cluster will use
        console.log('Cluster configuration:', {
            executors: config.executors,
            cores: config.executorCores * config.executors,
            memory: config.executorMemory
        });
    },

    save() {
        try {
            // Save to localStorage
            localStorage.setItem('pipezone_cluster', this.currentCluster);

            // Update environment variable (would be done via API in production)
            this.updateEnvironmentVariable('SELECTED_CLUSTER', this.currentCluster);

            // Show success message
            showNotification(`Cluster configuration saved: ${this.getClusterDisplayName()}`, 'success');

            // Update badge
            this.updateBadge();

            console.log('✓ Cluster configuration saved');
            return true;
        } catch (error) {
            console.error('Failed to save cluster configuration:', error);
            showNotification('Failed to save cluster configuration', 'error');
            return false;
        }
    },

    updateEnvironmentVariable(name, value) {
        // In production, this would call an API to update the environment variable
        console.log(`Setting ${name}=${value}`);

        // For now, we can only update it for the current session
        if (typeof window !== 'undefined') {
            window[name] = value;
        }
    },

    updateBadge() {
        const badge = document.getElementById('clusterBadge');
        if (badge) {
            badge.textContent = this.getClusterDisplayName();
        }
    },

    updateUI() {
        const radio = document.querySelector(`input[value="${this.currentCluster}"]`);
        if (radio) {
            radio.checked = true;
        }
        this.updateBadge();
    },

    getClusterDisplayName() {
        const names = {
            'small_cluster': 'Small',
            'medium_cluster': 'Medium',
            'large_cluster': 'Large'
        };
        return names[this.currentCluster] || 'Medium';
    },

    getResourceInfo() {
        const config = getClusterConfig(this.currentCluster);

        return {
            name: this.getClusterDisplayName(),
            executors: config.executors,
            totalCores: config.executors * config.executorCores,
            totalMemory: config.executors * parseMemory(config.executorMemory),
            driverMemory: parseMemory(config.driverMemory)
        };
    }
};

// Auto-initialize if not in module context
if (typeof module === 'undefined') {
    ClusterSelector.init();
}

if (typeof module !== 'undefined' && module.exports) {
    module.exports = ClusterSelector;
}
