package com.girlssss.envios.service;

import com.girlssss.envios.model.Envio;
import com.girlssss.envios.repository.EnvioRepository;
import org.springframework.stereotype.Service;

import java.util.List;

@Service
public class EnvioService {

    private final EnvioRepository envioRepository;

    public EnvioService(EnvioRepository envioRepository) {
        this.envioRepository = envioRepository;
    }

    public List<Envio> listarEnvios() {
        return envioRepository.findAll();
    }

    public Envio buscarPorId(Long id) {
        return envioRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Envío no encontrado"));
    }

    public Envio guardar(Envio envio) {
        return envioRepository.save(envio);
    }

    public Envio actualizar(Long id, Envio envio) {
        Envio existente = buscarPorId(id);

        existente.setPedidoId(envio.getPedidoId());
        existente.setDireccionDestino(envio.getDireccionDestino());
        existente.setNumeroSeguimiento(envio.getNumeroSeguimiento());
        existente.setEstado(envio.getEstado());
        existente.setFechaActualizacion(envio.getFechaActualizacion());

        return envioRepository.save(existente);
    }

    public void eliminar(Long id) {
        Envio envio = buscarPorId(id);
        envioRepository.delete(envio);
    }
}