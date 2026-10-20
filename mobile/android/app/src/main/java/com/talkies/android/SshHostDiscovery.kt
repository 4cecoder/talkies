package com.talkies.android

import android.content.Context
import android.net.nsd.NsdManager
import android.net.nsd.NsdServiceInfo
import java.util.concurrent.ConcurrentHashMap

/** Finds SSH servers explicitly advertised on the local network via DNS-SD. */
internal class SshHostDiscovery(context: Context) : AutoCloseable {
    private val manager = context.applicationContext.getSystemService(Context.NSD_SERVICE) as NsdManager
    private val resolved = ConcurrentHashMap<String, DiscoveredSshHost>()
    @Volatile private var listener: NsdManager.DiscoveryListener? = null
    @Volatile private var onUpdate: ((List<DiscoveredSshHost>) -> Unit)? = null

    @Suppress("DEPRECATION") // resolveService is supported back to the app's API 28 baseline.
    fun start(onUpdate: (List<DiscoveredSshHost>) -> Unit) {
        stop()
        this.onUpdate = onUpdate
        resolved.clear()
        val next = object : NsdManager.DiscoveryListener {
            override fun onDiscoveryStarted(serviceType: String) = Unit
            override fun onServiceFound(serviceInfo: NsdServiceInfo) {
                if (serviceInfo.serviceType.trimEnd('.') != SSH_SERVICE_TYPE.trimEnd('.')) return
                manager.resolveService(serviceInfo, object : NsdManager.ResolveListener {
                    override fun onResolveFailed(info: NsdServiceInfo, errorCode: Int) = Unit
                    override fun onServiceResolved(info: NsdServiceInfo) {
                        val address = info.host?.hostAddress ?: return
                        val name = info.serviceName.trim().ifBlank { info.host.hostName ?: address }
                        val username = runCatching {
                            info.attributes["user"]?.toString(Charsets.UTF_8)?.trim()?.takeIf(String::isNotEmpty)
                        }.getOrNull()
                        val candidate = DiscoveredSshHost(
                            name = name,
                            host = address,
                            port = info.port,
                            username = username,
                        )
                        resolved["${candidate.host}:${candidate.port}"] = candidate
                        this@SshHostDiscovery.onUpdate?.invoke(resolved.values.sortedBy { it.name.lowercase() })
                    }
                })
            }
            override fun onServiceLost(serviceInfo: NsdServiceInfo) {
                val key = resolved.entries.firstOrNull { it.value.name == serviceInfo.serviceName }?.key ?: return
                resolved.remove(key)
                this@SshHostDiscovery.onUpdate?.invoke(resolved.values.sortedBy { it.name.lowercase() })
            }
            override fun onDiscoveryStopped(serviceType: String) = Unit
            override fun onStartDiscoveryFailed(serviceType: String, errorCode: Int) { stop() }
            override fun onStopDiscoveryFailed(serviceType: String, errorCode: Int) { stop() }
        }
        listener = next
        runCatching { manager.discoverServices(SSH_SERVICE_TYPE, NsdManager.PROTOCOL_DNS_SD, next) }
            .onFailure { stop() }
    }

    fun stop() {
        val current = listener ?: return
        listener = null
        runCatching { manager.stopServiceDiscovery(current) }
        onUpdate = null
    }

    override fun close() = stop()

    companion object {
        private const val SSH_SERVICE_TYPE = "_ssh._tcp."
    }
}

internal data class DiscoveredSshHost(
    val name: String,
    val host: String,
    val port: Int,
    val username: String? = null,
) {
    fun toProfile(usernameFallback: String?): SshHostProfile? {
        val user = username?.takeIf(String::isNotBlank) ?: usernameFallback?.takeIf(String::isNotBlank) ?: return null
        return runCatching {
            SshHostProfile(
                id = java.util.UUID.randomUUID().toString(),
                name = name.take(64).ifBlank { host },
                host = host,
                port = port,
                username = user,
            ).validate()
        }.getOrNull()
    }
}
