package com.girlssss.pedidos.service;

import com.girlssss.pedidos.model.Pedido;
import org.junit.jupiter.api.Test;

import java.math.BigDecimal;

import static org.junit.jupiter.api.Assertions.assertDoesNotThrow;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

class SqsPublisherTest {

    @Test
    void sinUrlDeCola_quedaDeshabilitadoYNoFalla() {
        SqsPublisher publisher = new SqsPublisher("", "us-east-1");
        Pedido p = new Pedido(1L, new BigDecimal("9990"));

        assertFalse(publisher.estaHabilitado());
        assertDoesNotThrow(() -> publisher.publicarPedidoCreado(p));
    }

    @Test
    void conUrlDeCola_quedaHabilitado() {
        SqsPublisher publisher = new SqsPublisher("https://sqs.us-east-1.amazonaws.com/123/cola", "us-east-1");

        assertTrue(publisher.estaHabilitado());
    }

    @Test
    void elMensajeIncluyeLosDatosDelPedido() {
        Pedido p = new Pedido(7L, new BigDecimal("9990"));
        p.setId(3L);

        String json = SqsPublisher.construirMensaje(p);

        assertTrue(json.contains("\"pedidoId\":3"));
        assertTrue(json.contains("\"usuarioId\":7"));
        assertTrue(json.contains("\"montoTotal\":9990"));
        assertTrue(json.contains("\"estado\":\"PENDIENTE\""));
    }
}
