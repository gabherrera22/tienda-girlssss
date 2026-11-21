package com.girlssss.pedidos.service;

import com.girlssss.pedidos.model.Pedido;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.DisposableBean;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;
import software.amazon.awssdk.regions.Region;
import software.amazon.awssdk.services.sqs.SqsClient;
import software.amazon.awssdk.services.sqs.model.SendMessageRequest;
import software.amazon.awssdk.services.sqs.model.SendMessageResponse;

/**
 * Productor de mensajes: publica en la cola SQS cada pedido nuevo.
 *
 * - Si no se configura la URL de la cola (aws.sqs.queue-url vacia), queda
 *   deshabilitado y el servicio funciona igual (entorno local y Swarm).
 * - No lleva credenciales en el codigo: el SDK las busca solo (variables de
 *   entorno, perfil local o rol de la instancia EC2).
 */
@Component
public class SqsPublisher implements DisposableBean {

    private static final Logger log = LoggerFactory.getLogger(SqsPublisher.class);

    private final String queueUrl;
    private final String region;
    private SqsClient client;

    public SqsPublisher(
            @Value("${aws.sqs.queue-url:}") String queueUrl,
            @Value("${aws.region:us-east-1}") String region) {
        this.queueUrl = queueUrl;
        this.region = region;
    }

    public boolean estaHabilitado() {
        return queueUrl != null && !queueUrl.isBlank();
    }

    public void publicarPedidoCreado(Pedido pedido) {
        if (!estaHabilitado()) {
            log.info("SQS deshabilitado (aws.sqs.queue-url vacia): no se publica el pedido {}", pedido.getId());
            return;
        }
        try {
            SendMessageResponse respuesta = cliente().sendMessage(
                    SendMessageRequest.builder()
                            .queueUrl(queueUrl)
                            .messageBody(construirMensaje(pedido))
                            .build());
            log.info("Pedido {} publicado en SQS (messageId={})", pedido.getId(), respuesta.messageId());
        } catch (Exception e) {
            // El pedido ya esta guardado: un fallo de la cola no debe romper la compra.
            log.error("No se pudo publicar el pedido {} en SQS", pedido.getId(), e);
        }
    }

    static String construirMensaje(Pedido pedido) {
        return String.format(
                "{\"pedidoId\":%s,\"usuarioId\":%s,\"montoTotal\":%s,\"estado\":\"%s\",\"fechaCreacion\":\"%s\"}",
                pedido.getId(),
                pedido.getUsuarioId(),
                pedido.getMontoTotal() == null ? "0" : pedido.getMontoTotal().toPlainString(),
                pedido.getEstado(),
                pedido.getFechaCreacion());
    }

    private synchronized SqsClient cliente() {
        if (client == null) {
            client = SqsClient.builder().region(Region.of(region)).build();
        }
        return client;
    }

    @Override
    public void destroy() {
        if (client != null) {
            client.close();
        }
    }
}
