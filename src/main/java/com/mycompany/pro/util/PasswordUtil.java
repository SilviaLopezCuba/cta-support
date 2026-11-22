package com.mycompany.pro.util;

import org.mindrot.jbcrypt.BCrypt;
import java.util.regex.Pattern;

public class PasswordUtil {

    private static final Pattern MD5_PATTERN = Pattern.compile("^[a-fA-F0-9]{32}$");
    private static final Pattern BCRYPT_PATTERN = Pattern.compile("^\\$2[aby]\\$.{56}$");

    /** Genera un hash BCrypt nuevo para una contraseña en texto plano. */
    public static String hashPassword(String plainPassword) {
        return BCrypt.hashpw(plainPassword, BCrypt.gensalt(12));
    }

    /** true si el hash guardado tiene formato BCrypt. */
    public static boolean isBcrypt(String storedHash) {
        return storedHash != null && BCRYPT_PATTERN.matcher(storedHash).matches();
    }

    /** true si el hash guardado tiene formato MD5 (legado). */
    public static boolean isLegacyMd5(String storedHash) {
        return storedHash != null && MD5_PATTERN.matcher(storedHash).matches();
    }

    /** Verifica una contraseña en texto plano contra un hash BCrypt. */
    public static boolean checkBcrypt(String plainPassword, String storedHash) {
        return BCrypt.checkpw(plainPassword, storedHash);
    }

    /** MD5 sin sal — SOLO para verificar contra hashes legado durante la migración. */
    public static String md5Legacy(String plainPassword) {
        try {
            java.security.MessageDigest md = java.security.MessageDigest.getInstance("MD5");
            md.update(plainPassword.getBytes(), 0, plainPassword.length());
            return new java.math.BigInteger(1, md.digest()).toString(16);
        } catch (Exception e) {
            throw new RuntimeException(e);
        }
    }
}