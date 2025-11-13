package com.quantumtrader.pro.brokerselector

import android.content.Context
import android.util.Log
import androidx.work.*
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.util.concurrent.TimeUnit

/**
 * Background worker for updating broker catalog periodically.
 *
 * Uses WorkManager to schedule weekly background updates with:
 * - Exponential backoff on failure
 * - Network connectivity requirement
 * - Battery-friendly constraints
 */
class BrokerUpdateWorker(
    appContext: Context,
    workerParams: WorkerParameters
) : CoroutineWorker(appContext, workerParams) {

    companion object {
        private const val TAG = "BrokerUpdateWorker"
        const val WORK_NAME = "broker_catalog_update"
        const val UPDATE_RESULT_KEY = "update_result"
        const val BROKERS_COUNT_KEY = "brokers_count"

        /**
         * Schedule periodic broker catalog updates.
         *
         * @param context Application context
         * @param repeatIntervalDays How often to check for updates (default: 7 days)
         */
        fun schedule(context: Context, repeatIntervalDays: Long = 7) {
            val constraints = Constraints.Builder()
                .setRequiredNetworkType(NetworkType.CONNECTED)
                .setRequiresBatteryNotLow(true)
                .build()

            val updateRequest = PeriodicWorkRequestBuilder<BrokerUpdateWorker>(
                repeatIntervalDays, TimeUnit.DAYS,
                1, TimeUnit.DAYS  // Flex interval: can run anytime in the last day
            )
                .setConstraints(constraints)
                .setBackoffCriteria(
                    BackoffPolicy.EXPONENTIAL,
                    WorkRequest.MIN_BACKOFF_MILLIS,
                    TimeUnit.MILLISECONDS
                )
                .addTag("broker_updates")
                .build()

            WorkManager.getInstance(context)
                .enqueueUniquePeriodicWork(
                    WORK_NAME,
                    ExistingPeriodicWorkPolicy.KEEP,  // Keep existing schedule
                    updateRequest
                )

            Log.i(TAG, "Scheduled periodic broker updates (every $repeatIntervalDays days)")
        }

        /**
         * Request an immediate one-time update.
         *
         * @param context Application context
         * @return WorkRequest that can be observed
         */
        fun requestImmediateUpdate(context: Context): OneTimeWorkRequest {
            val constraints = Constraints.Builder()
                .setRequiredNetworkType(NetworkType.CONNECTED)
                .build()

            val updateRequest = OneTimeWorkRequestBuilder<BrokerUpdateWorker>()
                .setConstraints(constraints)
                .setBackoffCriteria(
                    BackoffPolicy.EXPONENTIAL,
                    WorkRequest.MIN_BACKOFF_MILLIS,
                    TimeUnit.MILLISECONDS
                )
                .addTag("broker_updates")
                .addTag("manual_update")
                .build()

            WorkManager.getInstance(context)
                .enqueueUniqueWork(
                    "${WORK_NAME}_manual",
                    ExistingWorkPolicy.REPLACE,
                    updateRequest
                )

            Log.i(TAG, "Requested immediate broker catalog update")
            return updateRequest
        }

        /**
         * Cancel all scheduled updates.
         */
        fun cancel(context: Context) {
            WorkManager.getInstance(context).cancelUniqueWork(WORK_NAME)
            Log.i(TAG, "Canceled broker catalog updates")
        }

        /**
         * Check if updates are currently scheduled.
         */
        suspend fun isScheduled(context: Context): Boolean = withContext(Dispatchers.IO) {
            val workInfos = WorkManager.getInstance(context)
                .getWorkInfosForUniqueWork(WORK_NAME)
                .get()

            workInfos.any { it.state == WorkInfo.State.ENQUEUED || it.state == WorkInfo.State.RUNNING }
        }
    }

    override suspend fun doWork(): Result = withContext(Dispatchers.IO) {
        try {
            Log.i(TAG, "Starting broker catalog update (attempt ${runAttemptCount + 1})")

            val catalog = BrokerCatalog(applicationContext)

            // Check if update is needed
            if (!catalog.shouldUpdate()) {
                Log.i(TAG, "Catalog is recent, skipping update")
                return@withContext Result.success(
                    workDataOf(UPDATE_RESULT_KEY to "skipped_recent")
                )
            }

            // Fetch and verify
            val brokers = catalog.fetchAndVerify()

            if (brokers != null) {
                Log.i(TAG, "Broker catalog updated successfully: ${brokers.size} brokers")
                Result.success(
                    workDataOf(
                        UPDATE_RESULT_KEY to "success",
                        BROKERS_COUNT_KEY to brokers.size
                    )
                )
            } else {
                Log.w(TAG, "Broker catalog update failed, will retry")
                Result.retry()
            }

        } catch (e: Exception) {
            Log.e(TAG, "Broker catalog update error", e)
            Result.retry()
        }
    }
}

/**
 * Helper class for managing broker catalog updates from UI.
 */
class BrokerUpdateManager(private val context: Context) {

    companion object {
        private const val TAG = "BrokerUpdateManager"
        private const val PREFS_NAME = "broker_updater"
        private const val LAST_UPDATE_KEY = "last_update_timestamp"
        private const val LAST_CHECK_KEY = "last_check_timestamp"
        private const val AUTO_UPDATE_ENABLED_KEY = "auto_update_enabled"
    }

    private val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    /**
     * Enable or disable automatic background updates.
     */
    fun setAutoUpdateEnabled(enabled: Boolean) {
        prefs.edit().putBoolean(AUTO_UPDATE_ENABLED_KEY, enabled).apply()

        if (enabled) {
            BrokerUpdateWorker.schedule(context)
            Log.i(TAG, "Auto-update enabled")
        } else {
            BrokerUpdateWorker.cancel(context)
            Log.i(TAG, "Auto-update disabled")
        }
    }

    /**
     * Check if auto-update is enabled.
     */
    fun isAutoUpdateEnabled(): Boolean {
        return prefs.getBoolean(AUTO_UPDATE_ENABLED_KEY, true)  // Default: enabled
    }

    /**
     * Request an immediate update and return the work request for observation.
     */
    fun updateNow(): OneTimeWorkRequest {
        recordCheckTimestamp()
        return BrokerUpdateWorker.requestImmediateUpdate(context)
    }

    /**
     * Get the timestamp of the last successful update.
     */
    fun getLastUpdateTimestamp(): Long {
        return prefs.getLong(LAST_UPDATE_KEY, 0)
    }

    /**
     * Record a successful update.
     */
    fun recordUpdate() {
        val now = System.currentTimeMillis()
        prefs.edit().putLong(LAST_UPDATE_KEY, now).apply()
        Log.i(TAG, "Recorded update at $now")
    }

    /**
     * Get the timestamp of the last update check.
     */
    fun getLastCheckTimestamp(): Long {
        return prefs.getLong(LAST_CHECK_KEY, 0)
    }

    /**
     * Record an update check attempt.
     */
    private fun recordCheckTimestamp() {
        val now = System.currentTimeMillis()
        prefs.edit().putLong(LAST_CHECK_KEY, now).apply()
    }

    /**
     * Get human-readable time since last update.
     */
    fun getTimeSinceLastUpdate(): String {
        val lastUpdate = getLastUpdateTimestamp()
        if (lastUpdate == 0L) return "Never"

        val elapsed = System.currentTimeMillis() - lastUpdate
        val hours = elapsed / (1000 * 60 * 60)
        val days = hours / 24

        return when {
            days > 0 -> "$days day${if (days != 1L) "s" else ""} ago"
            hours > 0 -> "$hours hour${if (hours != 1L) "s" else ""} ago"
            else -> "Just now"
        }
    }

    /**
     * Check if an update is recommended based on time since last check.
     */
    fun shouldCheckForUpdate(): Boolean {
        val lastCheck = getLastCheckTimestamp()
        val elapsed = System.currentTimeMillis() - lastCheck
        return elapsed > BrokerCatalogConfig.MIN_UPDATE_INTERVAL_MS
    }
}
