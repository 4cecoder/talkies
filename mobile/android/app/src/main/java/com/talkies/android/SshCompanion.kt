package com.talkies.android

import android.content.Context
import com.jcraft.jsch.ChannelShell
import com.jcraft.jsch.JSch
import com.jcraft.jsch.UserInfo
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.io.InputStream
import java.io.OutputStream
import java.nio.charset.StandardCharsets
import java.util.concurrent.CompletableFuture
import java.util.concurrent.TimeUnit
import java.nio.CharBuffer

/** Local, non-secret connection profiles. Passwords are requested for each connection, never saved. */
internal class AndroidSshHostProfileStore(context: Context) : SshHostProfileStore {
    private val preferences = context.getSharedPreferences("ssh-hosts", Context.MODE_PRIVATE)

    @Synchronized
    override fun list(): List<SshHostProfile> = runCatching {
        val json = JSONArray(preferences.getString("profiles", "[]"))
        (0 until json.length()).map { index ->
            val item = json.getJSONObject(index)
            SshHostProfile(
                id = item.getString("id"),
                name = item.getString("name"),
                host = item.getString("host"),
                port = item.getInt("port"),
                username = item.getString("username"),
            ).validate()
        }
    }.getOrDefault(emptyList())

    @Synchronized
    override fun save(profile: SshHostProfile) {
        profile.validate()
        val updated = list().filterNot { it.id == profile.id } + profile
        val json = JSONArray().apply {
            updated.forEach { host ->
                put(JSONObject().apply {
                    put("id", host.id)
                    put("name", host.name)
                    put("host", host.host)
                    put("port", host.port)
                    put("username", host.username)
                })
            }
        }
        check(preferences.edit().putString("profiles", json.toString()).commit()) {
            "Could not save the SSH host profile."
        }
    }

    @Synchronized
    override fun delete(id: String) {
        val remaining = list().filterNot { it.id == id }
        val json = JSONArray().apply {
            remaining.forEach { host ->
                put(JSONObject().apply {
                    put("id", host.id)
                    put("name", host.name)
                    put("host", host.host)
                    put("port", host.port)
                    put("username", host.username)
                })
            }
        }
        preferences.edit().putString("profiles", json.toString()).commit()
    }
}

/** A single interactive SSH PTY. It owns the password-bearing session and never logs its data. */
internal class SshTerminalSession private constructor(
    private val session: com.jcraft.jsch.Session,
    private val shell: ChannelShell,
    private val input: InputStream,
    private val output: OutputStream,
) : AutoCloseable {
    @Volatile private var closed = false

    fun startReading(onBytes: (ByteArray) -> Unit, onClosed: (Throwable?) -> Unit) {
        Thread({
            val buffer = ByteArray(4096)
            try {
                while (!closed) {
                    val count = input.read(buffer)
                    if (count < 0) break
                    onBytes(buffer.copyOf(count))
                }
                if (!closed) onClosed(null)
            } catch (error: Throwable) {
                if (!closed) onClosed(error)
            }
        }, "talkies-ssh-output").apply { isDaemon = true }.start()
    }

    @Synchronized
    fun send(text: String) {
        send(text.toByteArray(StandardCharsets.UTF_8))
    }

    @Synchronized
    fun send(bytes: ByteArray) {
        check(!closed && shell.isConnected) { "SSH connection is closed. Reconnect to continue." }
        output.write(bytes)
        output.flush()
    }

    fun resize(rows: Int, columns: Int) {
        if (!closed && shell.isConnected && rows > 0 && columns > 0) {
            shell.setPtySize(columns, rows, 0, 0)
        }
    }

    override fun close() {
        closed = true
        shell.disconnect()
        session.disconnect()
    }

    companion object {
        fun connect(
            context: Context,
            profile: SshHostProfile,
            password: CharArray,
            onHostTrustRequest: (String, CompletableFuture<Boolean>) -> Unit,
        ): SshTerminalSession {
            profile.validate()
            val encoded = StandardCharsets.UTF_8.encode(CharBuffer.wrap(password))
            val secret = ByteArray(encoded.remaining())
            encoded.get(secret)
            if (encoded.hasArray()) encoded.array().fill(0)
            password.fill('\u0000')
            var session: com.jcraft.jsch.Session? = null
            try {
                val knownHosts = File(context.filesDir, "ssh/known_hosts").apply {
                    parentFile?.mkdirs()
                    if (!exists()) createNewFile()
                }
                val jsch = JSch().apply { setKnownHosts(knownHosts.absolutePath) }
                val sshSession = jsch.getSession(profile.username, profile.host, profile.port)
                session = sshSession
                sshSession.setPassword(secret)
                sshSession.setConfig("StrictHostKeyChecking", "ask")
                sshSession.setServerAliveInterval(15_000)
                sshSession.setServerAliveCountMax(3)
                sshSession.setUserInfo(object : UserInfo {
                    override fun getPassphrase(): String? = null
                    override fun getPassword(): String? = null
                    override fun promptPassword(message: String?): Boolean = false
                    override fun promptPassphrase(message: String?): Boolean = false
                    override fun promptYesNo(message: String): Boolean {
                        val answer = CompletableFuture<Boolean>()
                        onHostTrustRequest(message, answer)
                        return try {
                            answer.get(2, TimeUnit.MINUTES)
                        } catch (_: Exception) {
                            false
                        }
                    }
                    override fun showMessage(message: String?) = Unit
                })
                sshSession.connect(20_000)
                val channel = sshSession.openChannel("shell") as ChannelShell
                channel.setPtyType("xterm-256color", 100, 32, 0, 0)
                val output = channel.outputStream
                val input = channel.inputStream
                channel.connect(10_000)
                sshSession.setUserInfo(null)
                sshSession.setPassword(ByteArray(0))
                return SshTerminalSession(sshSession, channel, input, output)
            } catch (error: Throwable) {
                session?.disconnect()
                throw error
            } finally {
                secret.fill(0)
                session?.setUserInfo(null)
                session?.setPassword(ByteArray(0))
            }
        }
    }
}
