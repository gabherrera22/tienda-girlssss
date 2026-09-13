package com.girlssss.envios.controller;

import com.girlssss.envios.model.Envio;
import com.girlssss.envios.repository.EnvioRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/envios")
public class EnvioController {

    @Autowired
    private EnvioRepository envioRepository;

    @GetMapping
    public List<Envio> obtenerTodos() {
        return envioRepository.findAll();
    }

    @GetMapping("/pedido/{pedidoId}")
    public ResponseEntity<Envio> obtenerPorPedido(@PathVariable Long pedidoId) {
        return envioRepository.findByPedidoId(pedidoId)
                .map(ResponseEntity::ok)
                .orElse(ResponseEntity.notFound().build());
    }

    @PostMapping
    public Envio registrarEnvio(@RequestBody Envio envio) {
        return envioRepository.save(envio);
    }
}