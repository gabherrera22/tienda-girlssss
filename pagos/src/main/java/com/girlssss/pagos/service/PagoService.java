package com.girlssss.pagos.service;

import com.girlssss.pagos.model.Pago;
import com.girlssss.pagos.repository.PagoRepository;
import org.springframework.stereotype.Service;

import java.util.List;

@Service
public class PagoService {

    private final PagoRepository pagoRepository;

    public PagoService(PagoRepository pagoRepository) {
        this.pagoRepository = pagoRepository;
    }

    public List<Pago> listarPagos() {
        return pagoRepository.findAll();
    }

    public Pago buscarPorId(Long id) {
        return pagoRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Pago no encontrado"));
    }

    public Pago guardar(Pago pago) {
        return pagoRepository.save(pago);
    }

    public Pago actualizar(Long id, Pago pago) {
        Pago existente = buscarPorId(id);

        existente.setEstado(pago.getEstado());

        return pagoRepository.save(existente);
    }

    public void eliminar(Long id) {
        Pago pago = buscarPorId(id);
        pagoRepository.delete(pago);
    }
}