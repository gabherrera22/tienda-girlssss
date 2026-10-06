package com.girlssss.usuarios.config;

import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.SignatureAlgorithm;
import io.jsonwebtoken.security.Keys;
import org.springframework.stereotype.Component;

import java.security.Key;
import java.util.Date;

@Component
public class JwtUtil {

    // Clave secreta (mínimo 256 bits / 32 caracteres)
    private static final String SECRET_KEY = "MiClaveSuperSecretaParaTiendaGirlssss2026!";
    // Tiempo de expiración: 1 día (en milisegundos)
    private static final long EXPIRATION_TIME = 86_400_000;

    private final Key key = Keys.hmacShaKeyFor(SECRET_KEY.getBytes());

    public String generarToken(String email) {
        return Jwts.builder()
                .setSubject(email)
                .setIssuedAt(new Date())
                .setExpiration(new Date(System.currentTimeMillis() + EXPIRATION_TIME))
                .signWith(key, SignatureAlgorithm.HS256)
                .compact();
    }
}