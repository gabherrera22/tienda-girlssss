package com.girlssss.envios.controller;

import com.girlssss.envios.model.Envio;
import com.girlssss.envios.service.EnvioService;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/envios")
public class EnvioController {

    private final EnvioService envioService;

    public EnvioController(EnvioService envioService) {
        this.envioService = envioService;
    }

    @GetMapping
    public List<Envio> listar() {
        return envioService.listarEnvios();
    }

    @GetMapping("/{id}")
    public Envio buscar(@PathVariable Long id) {
        return envioService.buscarPorId(id);
    }

    @PostMapping
    public Envio crear(@RequestBody Envio envio) {
        return envioService.guardar(envio);
    }

    @PutMapping("/{id}")
    public Envio actualizar(
            @PathVariable Long id,
            @RequestBody Envio envio) {
        return envioService.actualizar(id, envio);
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> eliminar(@PathVariable Long id) {
        envioService.eliminar(id);
        return ResponseEntity.noContent().build();
    }
}