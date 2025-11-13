package com.quantumtrader.pro.brokerselector

import org.json.JSONObject

/**
 * Represents a broker configuration for MT4/MT5 trading.
 *
 * @property name Display name of the broker (e.g., "LHFX", "OANDA")
 * @property server Server identifier for MT4/MT5 connection (e.g., "lhfx-live")
 * @property platform Trading platform type - "MT4" or "MT5"
 * @property webTerminalUrl HTTPS URL to the broker's MetaQuotes WebTerminal
 * @property logo Optional HTTPS URL to broker logo image
 * @property description Optional brief description of the broker
 * @property demo Whether this is a demo/practice account server
 */
data class Broker(
    val name: String,
    val server: String,
    val platform: String,
    val webTerminalUrl: String,
    val logo: String? = null,
    val description: String? = null,
    val demo: Boolean = false
) {
    companion object {
        /**
         * Parse a Broker from a JSONObject.
         * Throws IllegalArgumentException if required fields are missing or invalid.
         */
        fun fromJson(json: JSONObject): Broker {
            val name = json.optString("name", "").trim()
            val server = json.optString("server", "").trim()
            val platform = json.optString("platform", "").trim()
            val webTerminalUrl = json.optString("webTerminalUrl", "").trim()
            val logo = json.optString("logo", null)?.takeIf { it.isNotBlank() }
            val description = json.optString("description", null)?.takeIf { it.isNotBlank() }
            val demo = json.optBoolean("demo", false)

            // Validation
            require(name.isNotEmpty()) { "Broker name cannot be empty" }
            require(server.isNotEmpty()) { "Broker server cannot be empty" }
            require(platform in setOf("MT4", "MT5")) {
                "Platform must be 'MT4' or 'MT5', got: '$platform'"
            }
            require(webTerminalUrl.startsWith("https://", ignoreCase = true)) {
                "WebTerminal URL must use HTTPS: '$webTerminalUrl'"
            }

            return Broker(
                name = name,
                server = server,
                platform = platform,
                webTerminalUrl = webTerminalUrl,
                logo = logo,
                description = description,
                demo = demo
            )
        }
    }

    /**
     * Convert this Broker to a JSONObject for serialization.
     */
    fun toJson(): JSONObject {
        return JSONObject().apply {
            put("name", name)
            put("server", server)
            put("platform", platform)
            put("webTerminalUrl", webTerminalUrl)
            logo?.let { put("logo", it) }
            description?.let { put("description", it) }
            put("demo", demo)
        }
    }

    /**
     * Get a display-friendly string representation.
     */
    fun getDisplayName(): String {
        return if (demo) "$name (Demo)" else name
    }

    /**
     * Get a subtitle showing platform and server info.
     */
    fun getSubtitle(): String {
        return "$platform • $server"
    }
}
