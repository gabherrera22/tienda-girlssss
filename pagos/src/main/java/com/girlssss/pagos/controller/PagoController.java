package com.girlssss.pagos.controller;

import com.girlssss.pagos.model.Pago;
import com.girlssss.pagos.service.PagoService;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/pagos")
public class PagoController {

    private final PagoService pagoService;

    public PagoController(PagoService pagoService) {
        this.pagoService = pagoService;
    }

    @GetMapping
    public List<Pago> listar() {
        return pagoService.listarPagos();
    }

    @GetMapping("/{id}")
    public Pago buscar(@PathVariable Long id) {
        return pagoService.buscarPorId(id);
    }

    @PostMapping
    public Pago crear(@RequestBody Pago pago) {
        return pagoService.guardar(pago);
    }

    @PutMapping("/{id}")
    public Pago actualizar(
            @PathVariable Long id,
            @RequestBody Pago pago) {
        return pagoService.actualizar(id, pago);
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> eliminar(@PathVariable Long id) {
        pagoService.eliminar(id);
        return ResponseEntity.noContent().build();
    }
}