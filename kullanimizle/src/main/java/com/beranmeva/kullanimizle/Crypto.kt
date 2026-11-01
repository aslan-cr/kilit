package com.beranmeva.kullanimizle

import android.util.Base64
import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import java.security.MessageDigest
import java.security.SecureRandom
import java.util.zip.GZIPInputStream
import java.util.zip.GZIPOutputStream
import javax.crypto.Cipher
import javax.crypto.SecretKeyFactory
import javax.crypto.spec.GCMParameterSpec
import javax.crypto.spec.PBEKeySpec
import javax.crypto.spec.SecretKeySpec

/** Cihaz koduna bağlı konu adı ve şifreleme. İki uygulamada aynıdır. */
object Crypto {
    private const val ALPHA = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
    const val SERVER = "https://ntfy.sh"

    fun newCode(): String {
        val r = SecureRandom()
        val c = CharArray(8) { ALPHA[r.nextInt(ALPHA.length)] }
        return String(c, 0, 4) + "-" + String(c, 4, 4)
    }

    fun norm(code: String): String = code.uppercase().filter { it in ALPHA }

    fun valid(code: String): Boolean = norm(code).length == 8

    fun pretty(code: String): String {
        val n = norm(code)
        return if (n.length == 8) n.substring(0, 4) + "-" + n.substring(4) else n
    }

    fun topic(code: String): String {
        val h = MessageDigest.getInstance("SHA-256").digest(("topic:" + norm(code)).toByteArray())
        return "bmk" + h.joinToString("") { "%02x".format(it) }.take(32)
    }

    private fun key(code: String): SecretKeySpec {
        val f = SecretKeyFactory.getInstance("PBKDF2WithHmacSHA256")
        val spec = PBEKeySpec(norm(code).toCharArray(), "beranmeva-kullanim".toByteArray(), 10000, 256)
        return SecretKeySpec(f.generateSecret(spec).encoded, "AES")
    }

    /** JSON metni -> gzip -> AES-GCM -> base64 (ntfy mesajı) */
    fun pack(code: String, json: String): String {
        val bo = ByteArrayOutputStream()
        GZIPOutputStream(bo).use { it.write(json.toByteArray(Charsets.UTF_8)) }
        val iv = ByteArray(12).also { SecureRandom().nextBytes(it) }
        val c = Cipher.getInstance("AES/GCM/NoPadding")
        c.init(Cipher.ENCRYPT_MODE, key(code), GCMParameterSpec(128, iv))
        return Base64.encodeToString(iv + c.doFinal(bo.toByteArray()), Base64.NO_WRAP)
    }

    fun unpack(code: String, msg: String): String {
        val raw = Base64.decode(msg.trim(), Base64.NO_WRAP)
        val iv = raw.copyOfRange(0, 12)
        val c = Cipher.getInstance("AES/GCM/NoPadding")
        c.init(Cipher.DECRYPT_MODE, key(code), GCMParameterSpec(128, iv))
        val plain = c.doFinal(raw, 12, raw.size - 12)
        return GZIPInputStream(ByteArrayInputStream(plain)).use { String(it.readBytes(), Charsets.UTF_8) }
    }
}
