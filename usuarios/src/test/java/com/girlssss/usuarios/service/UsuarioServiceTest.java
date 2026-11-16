package com.girlssss.usuarios.service;

import com.girlssss.usuarios.model.Usuario;
import com.girlssss.usuarios.repository.UsuarioRepository;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class UsuarioServiceTest {

    @Mock
    UsuarioRepository repository;

    @InjectMocks
    UsuarioService service;

    @Test
    void login_devuelveEmailConCredencialesCorrectas() {
        Usuario u = new Usuario();
        u.setEmail("ana@correo.cl");
        u.setPassword("1234");
        when(repository.findAll()).thenReturn(List.of(u));

        assertEquals("ana@correo.cl", service.login("ana@correo.cl", "1234"));
    }

    @Test
    void login_devuelveNullConCredencialesIncorrectas() {
        Usuario u = new Usuario();
        u.setEmail("ana@correo.cl");
        u.setPassword("1234");
        when(repository.findAll()).thenReturn(List.of(u));

        assertNull(service.login("ana@correo.cl", "mala"));
    }
}