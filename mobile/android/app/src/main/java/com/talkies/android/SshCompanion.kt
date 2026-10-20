package com.talkies.android

import android.content.Context
import com.jcraft.jsch.ChannelShell
import com.jcraft.jsch.JSch
import com.jcraft.jsch.UserInfo
import org.json.JSONArray
import org.json.JSONObject
import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.InputStream
import java.io.OutputStream
import java.nio.charset.StandardCharsets
import java.util.concurrent.CompletableFuture
import java.util.concurrent.TimeUnit
import java.nio.CharBuffer

/** Local connection profiles. SSH passwords live separately in Android Keystore-backed storage. */
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

    fun runCommand(
        command: String,
        standardInput: ByteArray? = null,
        environment: Map<String, String> = emptyMap(),
    ): String {
        check(!closed && session.isConnected) { "SSH connection is closed. Reconnect to continue." }
        require(environment.keys.all { it == "CMUX_SOCKET_PASSWORD" }) { "Only the cmux socket password may be forwarded over SSH." }
        require(environment.values.all { value -> value.length <= MAX_CMUX_PASSWORD_LENGTH && value.none { it == '\u0000' || it == '\r' || it == '\n' } }) {
            "Invalid SSH environment value."
        }
        val channel = session.openChannel("exec") as com.jcraft.jsch.ChannelExec
        val stdout = channel.inputStream
        val stderr = ByteArrayOutputStream()
        channel.setErrStream(stderr)
        channel.setCommand(command)
        channel.setInputStream(standardInput?.let(::ByteArrayInputStream))
        environment.forEach { (key, value) ->
            channel.setEnv(key, value)
        }
        try {
            channel.connect(10_000)
            val output = ByteArrayOutputStream()
            val buffer = ByteArray(4096)
            val deadline = System.nanoTime() + java.util.concurrent.TimeUnit.SECONDS.toNanos(25)
            while (!channel.isClosed) {
                while (stdout.available() > 0) {
                    val count = stdout.read(buffer, 0, minOf(buffer.size, stdout.available()))
                    if (count > 0) {
                        check(output.size() + count <= MAX_COMMAND_OUTPUT_BYTES) { "Remote agent output exceeded the 1 MiB limit." }
                        output.write(buffer, 0, count)
                    }
                }
                if (System.nanoTime() >= deadline) {
                    throw java.net.SocketTimeoutException("Remote agent command timed out.")
                }
                Thread.sleep(20)
            }
            while (stdout.available() > 0) {
                val count = stdout.read(buffer, 0, minOf(buffer.size, stdout.available()))
                if (count > 0) {
                    check(output.size() + count <= MAX_COMMAND_OUTPUT_BYTES) { "Remote agent output exceeded the 1 MiB limit." }
                    output.write(buffer, 0, count)
                }
            }
            val text = output.toString(StandardCharsets.UTF_8.name())
            if (channel.exitStatus != 0) {
                val reason = stderr.toString(StandardCharsets.UTF_8.name()).trim().take(300)
                throw IllegalStateException(reason.ifEmpty { "Remote command failed (exit ${channel.exitStatus})." })
            }
            return text
        } finally {
            channel.disconnect()
            stdout.close()
        }
    }

    override fun close() {
        closed = true
        shell.disconnect()
        session.disconnect()
    }

    companion object {
        private const val MAX_COMMAND_OUTPUT_BYTES = 1024 * 1024
        private const val MAX_CMUX_PASSWORD_LENGTH = 4096

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
