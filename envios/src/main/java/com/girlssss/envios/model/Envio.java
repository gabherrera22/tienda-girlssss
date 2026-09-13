package com.girlssss.envios.model;

import jakarta.persistence.*;
import java.time.LocalDateTime;

@Entity
@Table(name = "envios")
public class Envio {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    // Referencia lógica al pedido
    @Column(name = "pedido_id", nullable = false)
    private Long pedidoId;

    @Column(name = "direccion_destino", nullable = false)
    private String direccionDestino;

    @Column(name = "numero_seguimiento")
    private String numeroSeguimiento;

    @Column(nullable = false)
    private String estado = "EN_PREPARACION"; // EN_PREPARACION, EN_TRANSITO, ENTREGADO

    @Column(name = "fecha_actualizacion")
    private LocalDateTime fechaActualizacion = LocalDateTime.now();

    public Envio() {}

    public Envio(Long pedidoId, String direccionDestino, String numeroSeguimiento) {
        this.pedidoId = pedidoId;
        this.direccionDestino = direccionDestino;
        this.numeroSeguimiento = numeroSeguimiento;
        this.estado = "EN_PREPARACION";
    }

    // Getters y Setters
    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }
    public Long getPedidoId() { return pedidoId; }
    public void setPedidoId(Long pedidoId) { this.pedidoId = pedidoId; }
    public String getDireccionDestino() { return direccionDestino; }
    public void setDireccionDestino(String direccionDestino) { this.direccionDestino = direccionDestino; }
    public String getNumeroSeguimiento() { return numeroSeguimiento; }
    public void setNumeroSeguimiento(String numeroSeguimiento) { this.numeroSeguimiento = numeroSeguimiento; }
    public String getEstado() { return estado; }
    public void setEstado(String estado) { this.estado = estado; }
    public LocalDateTime getFechaActualizacion() { return fechaActualizacion; }
    public void setFechaActualizacion(LocalDateTime fechaActualizacion) { this.fechaActualizacion = fechaActualizacion; }
}