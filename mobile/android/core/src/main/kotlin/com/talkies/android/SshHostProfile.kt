package com.talkies.android

/** A saved SSH destination. Authentication secrets are deliberately never part of this model. */
data class SshHostProfile(
    val id: String,
    val name: String,
    val host: String,
    val port: Int = 22,
    val username: String,
) {
    fun validate(): SshHostProfile {
        require(id.isNotBlank()) { "Host profile ID cannot be blank." }
        require(name.isNotBlank() && name.length <= 64) { "Give this host a name (up to 64 characters)." }
        require(host.isNotBlank() && host.length <= 253 && host.all { it.isLetterOrDigit() || it in ".:-_%[]" }) {
            "Enter a valid host name or IP address."
        }
        require(port in 1..65535) { "SSH port must be between 1 and 65535." }
        require(username.isNotBlank() && username.length <= 128 && username.none { it.isWhitespace() || it == ':' }) {
            "Enter a valid SSH username."
        }
        return this
    }
}

/** Separates validated profile persistence from Android storage and the SSH transport. */
interface SshHostProfileStore {
    fun list(): List<SshHostProfile>
    fun save(profile: SshHostProfile)
    fun delete(id: String)
}
