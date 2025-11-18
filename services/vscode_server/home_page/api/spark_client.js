// =============================================================================
// Spark Client API
// =============================================================================

async function updateSparkStatus() {
    const statusIndicator = document.getElementById('sparkStatus');
    const jobsEl = document.getElementById('sparkJobs');
    const executorsEl = document.getElementById('sparkExecutors');

    try {
        // Get Spark endpoint
        const endpoint = getSparkEndpoint();

        // Fetch Spark status
        const status = await fetchSparkStatus(endpoint);

        // Update status indicator
        if (status.activeJobs > 0) {
            statusIndicator.className = 'status-indicator status-active';
        } else {
            statusIndicator.className = 'status-indicator status-warning';
        }

        // Update job info
        jobsEl.textContent = status.activeJobs;
        executorsEl.textContent = status.executors;

        // Update state
        state.services.spark = {
            status: status.activeJobs > 0 ? 'active' : 'idle',
            data: status
        };

        console.log('✓ Spark status updated');
    } catch (error) {
        console.error('Failed to fetch Spark status:', error);

        statusIndicator.className = 'status-indicator status-inactive';
        jobsEl.textContent = '--';
        executorsEl.textContent = '--';

        state.services.spark = {
            status: 'error',
            data: {}
        };
    }
}

async function fetchSparkStatus(endpoint) {
    // Simulate API call - in production, this would call Spark History Server API
    return new Promise((resolve) => {
        setTimeout(() => {
            const activeJobs = Math.floor(Math.random() * 3);
            const clusterConfig = getClusterConfig(state.cluster);

            resolve({
                activeJobs,
                completedJobs: Math.floor(Math.random() * 100),
                executors: clusterConfig.executors,
                totalCores: clusterConfig.executors * clusterConfig.executorCores,
                totalMemory: clusterConfig.executors * parseMemory(clusterConfig.executorMemory),
                cluster: state.cluster
            });
        }, 500);
    });

    /* Production implementation:
    const response = await fetch(`${endpoint}/api/v1/applications`, {
        headers: {
            'Accept': 'application/json'
        }
    });

    if (!response.ok) {
        throw new Error(`Spark API error: ${response.status}`);
    }

    const data = await response.json();

    // Process and return relevant data
    return {
        activeJobs: data.activeApps ? data.activeApps.length : 0,
        completedJobs: data.completedApps ? data.completedApps.length : 0,
        executors: calculateTotalExecutors(data),
        // ... more processing
    };
    */
}

function getSparkEndpoint() {
    return window.SPARK_HISTORY_URL ||
           `http://${window.location.hostname}:18080`;
}

// =============================================================================
// Cluster Configuration
// =============================================================================

function getClusterConfig(clusterName) {
    const configs = {
        'small_cluster': {
            executors: 2,
            executorCores: 1,
            executorMemory: '2g',
            driverCores: 1,
            driverMemory: '2g'
        },
        'medium_cluster': {
            executors: 4,
            executorCores: 2,
            executorMemory: '4g',
            driverCores: 2,
            driverMemory: '4g'
        },
        'large_cluster': {
            executors: 8,
            executorCores: 4,
            executorMemory: '8g',
            driverCores: 4,
            driverMemory: '8g'
        }
    };

    return configs[clusterName] || configs['medium_cluster'];
}

function parseMemory(memStr) {
    // Parse memory string like "4g" to bytes
    const value = parseInt(memStr);
    const unit = memStr.slice(-1).toLowerCase();

    const multipliers = {
        'k': 1024,
        'm': 1024 * 1024,
        'g': 1024 * 1024 * 1024,
        't': 1024 * 1024 * 1024 * 1024
    };

    return value * (multipliers[unit] || 1);
}

// =============================================================================
// Spark Job Operations
// =============================================================================

async function listSparkJobs() {
    try {
        const endpoint = getSparkEndpoint();

        // In production, fetch from Spark History Server
        return [
            {
                id: 'app-20241118-001',
                name: 'Data Processing',
                status: 'running',
                startTime: Date.now() - 3600000,
                duration: '1h 0m'
            },
            {
                id: 'app-20241118-002',
                name: 'ML Training',
                status: 'completed',
                startTime: Date.now() - 7200000,
                duration: '45m'
            }
        ];
    } catch (error) {
        console.error('Failed to list Spark jobs:', error);
        return [];
    }
}

async function getSparkJobDetails(jobId) {
    try {
        const endpoint = getSparkEndpoint();

        // In production, fetch job details from API
        return {
            id: jobId,
            name: 'Data Processing',
            status: 'running',
            stages: 10,
            completedStages: 7,
            tasks: 1000,
            completedTasks: 700,
            executors: 4,
            totalCores: 8
        };
    } catch (error) {
        console.error('Failed to get job details:', error);
        return null;
    }
}

async function killSparkJob(jobId) {
    try {
        const endpoint = getSparkEndpoint();

        console.log(`Killing Spark job: ${jobId}`);

        // In production, call Spark API to kill job
        await new Promise(resolve => setTimeout(resolve, 500));

        console.log('✓ Job killed successfully');
        return true;
    } catch (error) {
        console.error('Failed to kill job:', error);
        return false;
    }
}

// =============================================================================
// Export functions
// =============================================================================

if (typeof module !== 'undefined' && module.exports) {
    module.exports = {
        updateSparkStatus,
        getClusterConfig,
        listSparkJobs,
        getSparkJobDetails,
        killSparkJob
    };
}
