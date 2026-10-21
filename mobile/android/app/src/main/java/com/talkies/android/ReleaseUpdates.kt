package com.talkies.android

import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL

internal data class ReleaseUpdate(val version: String, val url: String)

internal object ReleaseUpdates {
    const val latestReleaseUrl = "https://github.com/4cecoder/talkies/releases/latest"
    private const val apiUrl = "https://api.github.com/repos/4cecoder/talkies/releases/latest"

    fun check(currentVersion: String): ReleaseUpdate? {
        val connection = URL(apiUrl).openConnection() as HttpURLConnection
        try {
            connection.connectTimeout = 5_000
            connection.readTimeout = 5_000
            connection.setRequestProperty("Accept", "application/vnd.github+json")
            connection.setRequestProperty("User-Agent", "Talkies-Android")
            if (connection.responseCode !in 200..299) error("Release check failed (${connection.responseCode})")
            val release = JSONObject(connection.inputStream.bufferedReader().use { it.readText() })
            if (release.optBoolean("draft", false) || release.optBoolean("prerelease", false)) return null
            val version = release.optString("tag_name").removePrefix("v")
            val releaseUrl = release.optString("html_url", latestReleaseUrl)
            require(version.isNotBlank() && releaseUrl.startsWith("https://github.com/4cecoder/talkies/releases/")) {
                "Invalid release metadata"
            }
            return if (compareVersions(version, currentVersion) > 0) ReleaseUpdate(version, releaseUrl) else null
        } finally {
            connection.disconnect()
        }
    }

    internal fun compareVersions(left: String, right: String): Int {
        fun parts(value: String) = value.split('.').map { it.toIntOrNull() ?: 0 }
        val a = parts(left)
        val b = parts(right)
        for (index in 0 until maxOf(a.size, b.size)) {
            val comparison = (a.getOrElse(index) { 0 }).compareTo(b.getOrElse(index) { 0 })
            if (comparison != 0) return comparison
        }
        return 0
    }
}
