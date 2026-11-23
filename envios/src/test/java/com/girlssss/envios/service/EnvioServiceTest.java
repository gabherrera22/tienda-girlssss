package com.girlssss.envios.service;

import com.girlssss.envios.model.Envio;
import com.girlssss.envios.repository.EnvioRepository;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.Optional;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class EnvioServiceTest {

    @Mock
    EnvioRepository repository;

    @InjectMocks
    EnvioService service;

    @Test
    void nuevoEnvio_naceEnPreparacion() {
        Envio e = new Envio(1L, "Av. Siempre Viva 123", "TRK-001");
        when(repository.save(e)).thenReturn(e);

        assertEquals("EN_PREPARACION", service.guardar(e).getEstado());
    }

    @Test
    void buscarPorId_lanzaExcepcionSiNoExiste() {
        when(repository.findById(99L)).thenReturn(Optional.empty());

        assertThrows(RuntimeException.class, () -> service.buscarPorId(99L));
    }
}