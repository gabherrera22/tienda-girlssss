package com.girlssss.pedidos.service;

import com.girlssss.pedidos.model.Pedido;
import com.girlssss.pedidos.repository.PedidoRepository;

import org.springframework.stereotype.Service;

import java.util.List;

@Service
public class PedidoService {

    private final PedidoRepository pedidoRepository;
    private final SqsPublisher sqsPublisher;

    public PedidoService(PedidoRepository pedidoRepository, SqsPublisher sqsPublisher) {
        this.pedidoRepository = pedidoRepository;
        this.sqsPublisher = sqsPublisher;
    }

    public List<Pedido> listarPedidos() {
        return pedidoRepository.findAll();
    }

    public Pedido buscarPorId(Long id) {
        return pedidoRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Pedido no encontrado"));
    }

    public Pedido guardar(Pedido pedido) {
        Pedido guardado = pedidoRepository.save(pedido);
        // Productor: avisa por la cola que hay un pedido nuevo.
        sqsPublisher.publicarPedidoCreado(guardado);
        return guardado;
    }

    public Pedido actualizar(Long id, Pedido pedido) {

        Pedido existente = buscarPorId(id);

        existente.setUsuarioId(pedido.getUsuarioId());
        existente.setMontoTotal(pedido.getMontoTotal());
        existente.setEstado(pedido.getEstado());

        return pedidoRepository.save(existente);
    }

    public void eliminar(Long id) {

        Pedido pedido = buscarPorId(id);

        pedidoRepository.delete(pedido);
    }
}
