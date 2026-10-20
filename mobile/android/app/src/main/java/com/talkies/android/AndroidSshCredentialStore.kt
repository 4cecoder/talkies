package com.talkies.android

import android.content.Context
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import java.io.File
import java.nio.ByteBuffer
import java.nio.CharBuffer
import java.nio.charset.StandardCharsets
import java.security.KeyStore
import java.security.MessageDigest
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/** Stores opt-in SSH passwords encrypted with a non-exportable Android Keystore key. */
internal class AndroidSshCredentialStore(context: Context) {
    private val directory = File(context.noBackupFilesDir, DIRECTORY).apply { mkdirs() }

    @Synchronized
    fun save(profile: SshHostProfile, password: CharArray) {
        require(password.isNotEmpty())
        val encoded = StandardCharsets.UTF_8.encode(CharBuffer.wrap(password))
        val plaintext = ByteArray(encoded.remaining()).also { encoded.get(it) }
        if (encoded.hasArray()) encoded.array().fill(0)
        var ciphertext: ByteArray? = null
        var payload: ByteArray? = null
        val temporary = File(directory, "${fileFor(profile.id).name}.tmp")
        try {
            val cipher = Cipher.getInstance(TRANSFORMATION)
            cipher.init(Cipher.ENCRYPT_MODE, getOrCreateKey())
            val associatedData = profile.associatedData()
            try {
                cipher.updateAAD(associatedData)
            } finally {
                associatedData.fill(0)
            }
            ciphertext = cipher.doFinal(plaintext)
            payload = ByteArray(cipher.iv.size + requireNotNull(ciphertext).size)
            cipher.iv.copyInto(requireNotNull(payload))
            requireNotNull(ciphertext).copyInto(requireNotNull(payload), cipher.iv.size)
            val destination = fileFor(profile.id)
            temporary.outputStream().buffered().use { it.write(requireNotNull(payload)) }
            check(temporary.renameTo(destination)) { "Could not save the encrypted SSH password." }
        } finally {
            plaintext.fill(0)
            ciphertext?.fill(0)
            payload?.fill(0)
            temporary.delete()
        }
    }

    @Synchronized
    fun load(profile: SshHostProfile): CharArray? {
        val file = fileFor(profile.id)
        if (!file.isFile) return null
        val payload = runCatching { file.readBytes() }.getOrNull() ?: return null
        if (payload.size <= IV_LENGTH) {
            file.delete()
            payload.fill(0)
            return null
        }
        val iv = payload.copyOfRange(0, IV_LENGTH)
        val ciphertext = payload.copyOfRange(IV_LENGTH, payload.size)
        payload.fill(0)
        return try {
            val cipher = Cipher.getInstance(TRANSFORMATION)
            cipher.init(Cipher.DECRYPT_MODE, getOrCreateKey(), GCMParameterSpec(TAG_BITS, iv))
            val associatedData = profile.associatedData()
            try {
                cipher.updateAAD(associatedData)
            } finally {
                associatedData.fill(0)
            }
            val plaintext = cipher.doFinal(ciphertext)
            try {
                val decoded = StandardCharsets.UTF_8.decode(ByteBuffer.wrap(plaintext))
                try {
                    CharArray(decoded.remaining()).also { decoded.get(it) }
                } finally {
                    if (decoded.hasArray()) decoded.array().fill('\u0000')
                }
            } finally {
                plaintext.fill(0)
            }
        } catch (_: Exception) {
            // A changed host profile or invalidated Keystore key must require a fresh password.
            file.delete()
            null
        } finally {
            iv.fill(0)
            ciphertext.fill(0)
        }
    }

    @Synchronized
    fun delete(profileId: String) {
        fileFor(profileId).delete()
    }

    private fun getOrCreateKey(): SecretKey {
        val keyStore = KeyStore.getInstance(ANDROID_KEY_STORE).apply { load(null) }
        (keyStore.getKey(KEY_ALIAS, null) as? SecretKey)?.let { return it }
        return KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, ANDROID_KEY_STORE).run {
            init(
                KeyGenParameterSpec.Builder(
                    KEY_ALIAS,
                    KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT,
                )
                    .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                    .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                    .setKeySize(256)
                    .build(),
            )
            generateKey()
        }
    }

    private fun fileFor(profileId: String): File {
        val digest = MessageDigest.getInstance("SHA-256")
            .digest(profileId.toByteArray(StandardCharsets.UTF_8))
            .joinToString("") { "%02x".format(it.toInt() and 0xff) }
        return File(directory, "$digest.credential")
    }

    private fun SshHostProfile.associatedData(): ByteArray =
        "$id\u0000$host\u0000$port\u0000$username".toByteArray(StandardCharsets.UTF_8)

    private companion object {
        const val ANDROID_KEY_STORE = "AndroidKeyStore"
        const val DIRECTORY = "ssh-credentials"
        const val KEY_ALIAS = "talkies.ssh.credentials.v1"
        const val TRANSFORMATION = "AES/GCM/NoPadding"
        const val IV_LENGTH = 12
        const val TAG_BITS = 128
    }
}
