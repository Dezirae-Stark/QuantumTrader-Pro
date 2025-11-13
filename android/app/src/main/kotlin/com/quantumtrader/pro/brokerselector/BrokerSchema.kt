package com.quantumtrader.pro.brokerselector

import android.util.Log
import org.json.JSONArray
import org.json.JSONException

/**
 * Schema validator for broker catalog JSON.
 *
 * Validates that broker list JSON conforms to the expected schema:
 * - Must be an array
 * - Each item must have required fields: name, server, platform, webTerminalUrl
 * - Platform must be "MT4" or "MT5"
 * - webTerminalUrl must use HTTPS
 */
object BrokerSchema {
    private const val TAG = "BrokerSchema"

    /**
     * Validates and parses a broker list JSON string.
     *
     * @param jsonString The JSON string to validate and parse
     * @return List of validated Broker objects, or null if validation fails
     */
    fun validateAndParse(jsonString: String): List<Broker>? {
        try {
            val jsonArray = JSONArray(jsonString)

            if (jsonArray.length() == 0) {
                Log.e(TAG, "Broker list is empty")
                return null
            }

            val brokers = mutableListOf<Broker>()
            val errors = mutableListOf<String>()

            for (i in 0 until jsonArray.length()) {
                try {
                    val jsonObject = jsonArray.getJSONObject(i)
                    val broker = Broker.fromJson(jsonObject)
                    brokers.add(broker)
                } catch (e: Exception) {
                    val errorMsg = "Invalid broker at index $i: ${e.message}"
                    Log.e(TAG, errorMsg, e)
                    errors.add(errorMsg)
                }
            }

            if (errors.isNotEmpty()) {
                Log.e(TAG, "Validation failed with ${errors.size} error(s):\n${errors.joinToString("\n")}")
                return null
            }

            if (brokers.isEmpty()) {
                Log.e(TAG, "No valid brokers parsed")
                return null
            }

            Log.i(TAG, "Successfully validated ${brokers.size} broker(s)")
            return brokers

        } catch (e: JSONException) {
            Log.e(TAG, "Failed to parse broker JSON: ${e.message}", e)
            return null
        } catch (e: Exception) {
            Log.e(TAG, "Unexpected error during validation: ${e.message}", e)
            return null
        }
    }

    /**
     * Validates broker list JSON without parsing to full objects.
     * Faster check for initial validation.
     *
     * @param jsonString The JSON string to validate
     * @return true if the JSON appears to be valid broker list, false otherwise
     */
    fun isValid(jsonString: String): Boolean {
        return try {
            val jsonArray = JSONArray(jsonString)
            if (jsonArray.length() == 0) return false

            // Check first item has required fields
            val firstItem = jsonArray.getJSONObject(0)
            firstItem.has("name") &&
            firstItem.has("server") &&
            firstItem.has("platform") &&
            firstItem.has("webTerminalUrl")
        } catch (e: Exception) {
            Log.e(TAG, "Validation check failed: ${e.message}")
            false
        }
    }

    /**
     * Gets a human-readable validation error message for debugging.
     *
     * @param jsonString The JSON string to validate
     * @return Error message, or null if valid
     */
    fun getValidationError(jsonString: String): String? {
        return try {
            val jsonArray = JSONArray(jsonString)

            if (jsonArray.length() == 0) {
                return "Broker list is empty"
            }

            for (i in 0 until jsonArray.length()) {
                try {
                    val jsonObject = jsonArray.getJSONObject(i)
                    Broker.fromJson(jsonObject)
                } catch (e: Exception) {
                    return "Invalid broker at index $i: ${e.message}"
                }
            }

            null // Valid
        } catch (e: JSONException) {
            "Invalid JSON format: ${e.message}"
        } catch (e: Exception) {
            "Validation error: ${e.message}"
        }
    }
}
