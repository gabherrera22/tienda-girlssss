package com.girlssss.pagos.service;

import com.girlssss.pagos.model.Pago;
import com.girlssss.pagos.repository.PagoRepository;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigDecimal;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class PagoServiceTest {

    @Mock
    PagoRepository repository;

    @InjectMocks
    PagoService service;

    @Test
    void nuevoPago_naceEnEstadoCompletado() {
        Pago p = new Pago(1L, new BigDecimal("15000"), "TARJETA");
        when(repository.save(p)).thenReturn(p);

        assertEquals("COMPLETADO", service.guardar(p).getEstado());
    }

    @Test
    void buscarPorId_lanzaExcepcionSiNoExiste() {
        when(repository.findById(99L)).thenReturn(Optional.empty());

        assertThrows(RuntimeException.class, () -> service.buscarPorId(99L));
    }
}