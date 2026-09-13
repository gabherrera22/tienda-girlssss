package com.girlssss.pedidos.repository;

import com.girlssss.pedidos.model.Pedido;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface PedidoRepository extends JpaRepository<Pedido, Long> {
    // Permite consultar rápidamente las compras realizadas por un cliente específico
    List<Pedido> findByUsuarioId(Long usuarioId);
}