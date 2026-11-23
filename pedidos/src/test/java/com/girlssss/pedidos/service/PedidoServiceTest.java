package com.girlssss.pedidos.service;

import com.girlssss.pedidos.model.Pedido;
import com.girlssss.pedidos.repository.PedidoRepository;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigDecimal;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class PedidoServiceTest {

    @Mock
    PedidoRepository repository;

    @Mock
    SqsPublisher sqsPublisher;

    @InjectMocks
    PedidoService service;

    @Test
    void nuevoPedido_naceEnEstadoPendiente() {
        Pedido p = new Pedido(1L, new BigDecimal("15000"));
        when(repository.save(p)).thenReturn(p);

        assertEquals("PENDIENTE", service.guardar(p).getEstado());
    }

    @Test
    void guardar_publicaElPedidoEnLaCola() {
        Pedido p = new Pedido(1L, new BigDecimal("15000"));
        when(repository.save(p)).thenReturn(p);

        service.guardar(p);

        verify(sqsPublisher).publicarPedidoCreado(p);
    }

    @Test
    void buscarPorId_lanzaExcepcionSiNoExiste() {
        when(repository.findById(99L)).thenReturn(Optional.empty());

        assertThrows(RuntimeException.class, () -> service.buscarPorId(99L));
    }
}
