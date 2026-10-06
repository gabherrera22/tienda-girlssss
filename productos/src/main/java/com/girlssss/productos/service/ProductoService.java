package com.girlssss.productos.service;

import com.girlssss.productos.model.Producto;
import com.girlssss.productos.repository.ProductoRepository;

import org.springframework.stereotype.Service;

import java.util.List;

@Service
public class ProductoService {

    private final ProductoRepository productoRepository;

    public ProductoService(ProductoRepository productoRepository) {
        this.productoRepository = productoRepository;
    }

    public List<Producto> listarProductos() {
        return productoRepository.findAll();
    }

    public Producto buscarPorId(Long id) {
        return productoRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Producto no encontrado"));
    }

    public Producto guardar(Producto producto) {
        return productoRepository.save(producto);
    }

    public Producto actualizar(Long id, Producto producto) {

        Producto existente = buscarPorId(id);

        existente.setSku(producto.getSku());
        existente.setNombre(producto.getNombre());
        existente.setDescripcion(producto.getDescripcion());
        existente.setPrecio(producto.getPrecio());
        existente.setStockActual(producto.getStockActual());
        existente.setActivo(producto.getActivo());

        return productoRepository.save(existente);
    }

    public void eliminar(Long id) {

        Producto producto = buscarPorId(id);

        productoRepository.delete(producto);
    }
}