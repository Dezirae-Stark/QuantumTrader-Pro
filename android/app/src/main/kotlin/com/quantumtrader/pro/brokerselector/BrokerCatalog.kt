package com.quantumtrader.pro.brokerselector

import android.content.Context
import android.util.Log
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONArray
import java.io.File
import java.io.IOException
import java.net.HttpURLConnection
import java.net.URL

/**
 * Manages broker catalog loading with multiple fallback strategies.
 *
 * Loading priority:
 * 1. Cached catalog (if recent and valid)
 * 2. Remote catalog (verified with signature)
 * 3. Embedded fallback catalog
 *
 * All remote catalogs must pass Ed25519 signature verification.
 */
class BrokerCatalog(private val context: Context) {

    companion object {
        private const val TAG = "BrokerCatalog"
        private const val EMBEDDED_ASSET_NAME = "brokers.json"
        private const val CACHE_FILE_NAME = "brokers_cache.json"
        private const val CACHE_METADATA_FILE = "brokers_cache_metadata.json"
        private const val ETAG_KEY = "etag"
        private const val TIMESTAMP_KEY = "timestamp"
    }

    /**
     * Load the broker catalog from cache or embedded fallback.
     * This is synchronous and suitable for UI initialization.
     *
     * @return List of brokers, never null (falls back to embedded)
     */
    fun loadCatalog(): List<Broker> {
        // Try cache first
        loadCached()?.let { return it }

        // Fall back to embedded
        return loadEmbedded()
    }

    /**
     * Load brokers from embedded assets.
     * This is the ultimate fallback and should always work.
     *
     * @return List of brokers from embedded assets
     */
    fun loadEmbedded(): List<Broker> {
        return try {
            val json = context.assets.open(EMBEDDED_ASSET_NAME).bufferedReader().use { it.readText() }
            val brokers = BrokerSchema.validateAndParse(json)

            if (brokers != null) {
                Log.i(TAG, "Loaded ${brokers.size} brokers from embedded assets")
                brokers
            } else {
                Log.e(TAG, "Failed to parse embedded broker list")
                emptyList()
            }
        } catch (e: IOException) {
            Log.e(TAG, "Failed to read embedded broker list", e)
            // Return minimal emergency fallback
            listOf(
                Broker(
                    name = "LHFX Demo",
                    server = "lhfx-demo",
                    platform = "MT4",
                    webTerminalUrl = "https://trade.mql5.com/trade?servers=LHFX-Demo",
                    demo = true
                )
            )
        }
    }

    /**
     * Load brokers from local cache if available and recent.
     *
     * @return Cached brokers or null if cache is invalid/expired
     */
    fun loadCached(): List<Broker>? {
        return try {
            val cacheFile = getCacheFile()
            if (!cacheFile.exists()) {
                Log.d(TAG, "No cache file exists")
                return null
            }

            // Check cache age
            val metadata = getCacheMetadata()
            val cacheTimestamp = metadata.optLong(TIMESTAMP_KEY, 0)
            val age = System.currentTimeMillis() - cacheTimestamp

            if (age > BrokerCatalogConfig.CACHE_EXPIRATION_MS) {
                Log.d(TAG, "Cache expired (age: ${age}ms)")
                return null
            }

            // Load and validate
            val json = cacheFile.readText()
            val brokers = BrokerSchema.validateAndParse(json)

            if (brokers != null) {
                Log.i(TAG, "Loaded ${brokers.size} brokers from cache (age: ${age}ms)")
                brokers
            } else {
                Log.e(TAG, "Cached broker list failed validation")
                null
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to load cached brokers", e)
            null
        }
    }

    /**
     * Fetch and verify broker catalog from remote source.
     * This is a suspend function and should be called from a coroutine.
     *
     * @return List of verified brokers or null on failure
     */
    suspend fun fetchAndVerify(): List<Broker>? = withContext(Dispatchers.IO) {
        try {
            Log.i(TAG, "Fetching broker catalog from ${BrokerCatalogConfig.CATALOG_URL}")

            // Get cached ETag for conditional request
            val metadata = getCacheMetadata()
            val cachedETag = metadata.optString(ETAG_KEY, null)

            // Fetch catalog JSON
            val (catalogJson, newETag) = fetchWithETag(BrokerCatalogConfig.CATALOG_URL, cachedETag)
                ?: return@withContext null

            if (catalogJson == null) {
                Log.i(TAG, "Catalog not modified (ETag match)")
                return@withContext loadCached()
            }

            // Fetch signature
            val signature = fetch(BrokerCatalogConfig.SIGNATURE_URL)
            if (signature == null) {
                Log.e(TAG, "Failed to fetch signature")
                return@withContext null
            }

            // Verify signature
            if (!SignatureVerifier.verifySignatureFile(catalogJson.toByteArray(), signature)) {
                Log.e(TAG, "Signature verification FAILED - catalog may be tampered!")
                return@withContext null
            }

            Log.i(TAG, "Signature verification PASSED")

            // Validate schema
            val brokers = BrokerSchema.validateAndParse(catalogJson)
            if (brokers == null) {
                Log.e(TAG, "Fetched catalog failed schema validation")
                return@withContext null
            }

            // Save to cache atomically
            saveCached(catalogJson, newETag)

            Log.i(TAG, "Successfully fetched and verified ${brokers.size} brokers")
            brokers

        } catch (e: Exception) {
            Log.e(TAG, "Failed to fetch and verify catalog", e)
            null
        }
    }

    /**
     * Save broker list to cache.
     */
    fun saveCached(json: String, etag: String?) {
        try {
            // Save JSON
            val cacheFile = getCacheFile()
            cacheFile.parentFile?.mkdirs()
            cacheFile.writeText(json)

            // Save metadata
            val metadata = JSONArray().apply {
                put(org.json.JSONObject().apply {
                    put(TIMESTAMP_KEY, System.currentTimeMillis())
                    etag?.let { put(ETAG_KEY, it) }
                })
            }
            getCacheMetadataFile().writeText(metadata.toString())

            Log.i(TAG, "Cached broker catalog (${json.length} bytes)")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to save cache", e)
        }
    }

    /**
     * Clear the cached broker catalog.
     */
    fun clearCache() {
        try {
            getCacheFile().delete()
            getCacheMetadataFile().delete()
            Log.i(TAG, "Cache cleared")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to clear cache", e)
        }
    }

    /**
     * Check if a catalog update is recommended based on cache age.
     */
    fun shouldUpdate(): Boolean {
        val metadata = getCacheMetadata()
        val cacheTimestamp = metadata.optLong(TIMESTAMP_KEY, 0)
        val age = System.currentTimeMillis() - cacheTimestamp
        return age > BrokerCatalogConfig.MIN_UPDATE_INTERVAL_MS
    }

    /**
     * Get cache file location.
     */
    private fun getCacheFile(): File {
        return File(context.cacheDir, CACHE_FILE_NAME)
    }

    /**
     * Get cache metadata file.
     */
    private fun getCacheMetadataFile(): File {
        return File(context.cacheDir, CACHE_METADATA_FILE)
    }

    /**
     * Load cache metadata.
     */
    private fun getCacheMetadata(): org.json.JSONObject {
        return try {
            val file = getCacheMetadataFile()
            if (file.exists()) {
                val array = JSONArray(file.readText())
                if (array.length() > 0) {
                    array.getJSONObject(0)
                } else {
                    org.json.JSONObject()
                }
            } else {
                org.json.JSONObject()
            }
        } catch (e: Exception) {
            org.json.JSONObject()
        }
    }

    /**
     * Fetch URL content with ETag support.
     *
     * @return Pair of (content, etag) or null on error. Content is null if not modified (304).
     */
    private fun fetchWithETag(urlString: String, cachedETag: String?): Pair<String?, String?>? {
        return try {
            val url = URL(urlString)
            val connection = url.openConnection() as HttpURLConnection
            connection.connectTimeout = BrokerCatalogConfig.CONNECT_TIMEOUT_MS.toInt()
            connection.readTimeout = BrokerCatalogConfig.READ_TIMEOUT_MS.toInt()
            connection.requestMethod = "GET"

            // Add ETag for conditional request
            cachedETag?.let {
                connection.setRequestProperty("If-None-Match", it)
            }

            val responseCode = connection.responseCode

            when (responseCode) {
                HttpURLConnection.HTTP_OK -> {
                    val content = connection.inputStream.bufferedReader().use { it.readText() }
                    val etag = connection.getHeaderField("ETag")
                    Pair(content, etag)
                }
                HttpURLConnection.HTTP_NOT_MODIFIED -> {
                    Log.d(TAG, "Resource not modified (304)")
                    Pair(null, cachedETag)
                }
                else -> {
                    Log.e(TAG, "HTTP error: $responseCode")
                    null
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Fetch failed: ${e.message}", e)
            null
        }
    }

    /**
     * Simple fetch without ETag support.
     */
    private fun fetch(urlString: String): String? {
        return try {
            val url = URL(urlString)
            val connection = url.openConnection() as HttpURLConnection
            connection.connectTimeout = BrokerCatalogConfig.CONNECT_TIMEOUT_MS.toInt()
            connection.readTimeout = BrokerCatalogConfig.READ_TIMEOUT_MS.toInt()
            connection.requestMethod = "GET"

            if (connection.responseCode == HttpURLConnection.HTTP_OK) {
                connection.inputStream.bufferedReader().use { it.readText() }
            } else {
                Log.e(TAG, "HTTP error: ${connection.responseCode}")
                null
            }
        } catch (e: Exception) {
            Log.e(TAG, "Fetch failed: ${e.message}", e)
            null
        }
    }
}
