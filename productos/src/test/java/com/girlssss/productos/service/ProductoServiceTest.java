package com.girlssss.productos.service;

import com.girlssss.productos.model.Producto;
import com.girlssss.productos.repository.ProductoRepository;
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
class ProductoServiceTest {

    @Mock
    ProductoRepository repository;

    @InjectMocks
    ProductoService service;

    @Test
    void buscarPorId_devuelveElProductoSiExiste() {
        Producto p = new Producto("SKU-1", "Crema", "Hidratante", new BigDecimal("9990"), 10);
        when(repository.findById(1L)).thenReturn(Optional.of(p));

        assertEquals("Crema", service.buscarPorId(1L).getNombre());
    }

    @Test
    void buscarPorId_lanzaExcepcionSiNoExiste() {
        when(repository.findById(99L)).thenReturn(Optional.empty());

        assertThrows(RuntimeException.class, () -> service.buscarPorId(99L));
    }
}