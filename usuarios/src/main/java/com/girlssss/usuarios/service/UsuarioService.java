package com.girlssss.usuarios.service;

import com.girlssss.usuarios.model.Usuario;
import com.girlssss.usuarios.repository.UsuarioRepository;
import org.springframework.stereotype.Service;

import java.util.List;

@Service
public class UsuarioService {

    private final UsuarioRepository usuarioRepository;

    public UsuarioService(UsuarioRepository usuarioRepository) {
        this.usuarioRepository = usuarioRepository;
    }

    public List<Usuario> listarUsuarios() {
        return usuarioRepository.findAll();
    }

    public Usuario buscarPorId(Long id) {
        return usuarioRepository.findById(id).orElse(null);
    }

    public Usuario guardar(Usuario usuario) {
        return usuarioRepository.save(usuario);
    }

    public Usuario actualizar(Long id, Usuario usuario) {
        Usuario existente = buscarPorId(id);
        if (existente != null) {
            existente.setNombre(usuario.getNombre());
            existente.setEmail(usuario.getEmail());
            existente.setPassword(usuario.getPassword());
            return usuarioRepository.save(existente);
        }
        return null;
    }

    public void eliminar(Long id) {
        usuarioRepository.deleteById(id);
    }

    // Método necesario para la autenticación con JWT
    public String login(String email, String password) {
        return usuarioRepository.findAll().stream()
                .filter(u -> u.getEmail() != null && u.getEmail().equals(email) 
                          && u.getPassword() != null && u.getPassword().equals(password))
                .findFirst()
                .map(Usuario::getEmail)
                .orElse(null);
    }
}