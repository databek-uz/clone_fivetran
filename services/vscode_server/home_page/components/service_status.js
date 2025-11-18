// =============================================================================
// Service Status Component
// =============================================================================

const ServiceStatus = {
    updateInterval: null,

    init() {
        console.log('Initializing service status component...');
        this.startMonitoring();
    },

    startMonitoring() {
        // Initial update
        this.updateAllStatuses();

        // Set up periodic updates
        this.updateInterval = setInterval(() => {
            this.updateAllStatuses();
        }, 30000); // Update every 30 seconds
    },

    stopMonitoring() {
        if (this.updateInterval) {
            clearInterval(this.updateInterval);
            this.updateInterval = null;
        }
    },

    async updateAllStatuses() {
        try {
            await Promise.all([
                updateMinioStatus(),
                updateSparkStatus(),
                updateAirflowStatus()
            ]);
        } catch (error) {
            console.error('Failed to update service statuses:', error);
        }
    },

    getStatusColor(status) {
        const colors = {
            'active': 'var(--status-active)',
            'idle': 'var(--status-warning)',
            'error': 'var(--status-error)',
            'unknown': 'var(--status-inactive)'
        };

        return colors[status] || colors.unknown;
    },

    formatUptime(milliseconds) {
        const seconds = Math.floor(milliseconds / 1000);
        const minutes = Math.floor(seconds / 60);
        const hours = Math.floor(minutes / 60);
        const days = Math.floor(hours / 24);

        if (days > 0) return `${days}d ${hours % 24}h`;
        if (hours > 0) return `${hours}h ${minutes % 60}m`;
        if (minutes > 0) return `${minutes}m`;
        return `${seconds}s`;
    }
};

// Auto-initialize if not in module context
if (typeof module === 'undefined') {
    ServiceStatus.init();
}

if (typeof module !== 'undefined' && module.exports) {
    module.exports = ServiceStatus;
}
