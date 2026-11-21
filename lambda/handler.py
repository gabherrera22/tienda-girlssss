"""
Funcion Lambda: procesar-pedido

Consumidor de la cola SQS "tienda-pedidos". Por cada pedido nuevo:
  1. Valida el mensaje.
  2. Registra el pago llamando al microservicio "pagos" (si PAGOS_URL esta definida).
  3. Notifica al cliente publicando en un topico SNS (si TOPIC_ARN esta definido).

Variables de entorno (todas opcionales):
  PAGOS_URL  URL base del microservicio pagos, p. ej. http://1.2.3.4:8084
  TOPIC_ARN  ARN del topico SNS que envia el correo de notificacion
"""
import json
import os
import urllib.error
import urllib.request


def lambda_handler(event, context):
    """Punto de entrada. Devuelve los mensajes fallidos para que SQS los reintente."""
    fallidos = []
    for registro in event.get("Records", []):
        try:
            pedido = json.loads(registro["body"])
            procesar_pedido(pedido)
        except Exception as error:  # noqa: BLE001 - se informa y se reintenta ese mensaje
            print(f"ERROR procesando mensaje {registro.get('messageId')}: {error}")
            fallidos.append({"itemIdentifier": registro["messageId"]})
    return {"batchItemFailures": fallidos}


def procesar_pedido(pedido):
    validar_pedido(pedido)
    print(f"Procesando pedido {pedido['pedidoId']} del usuario {pedido['usuarioId']}")

    pagos_url = os.environ.get("PAGOS_URL", "")
    if pagos_url:
        registrar_pago(pagos_url, pedido)

    topic_arn = os.environ.get("TOPIC_ARN", "")
    if topic_arn:
        notificar(topic_arn, pedido)


def validar_pedido(pedido):
    for campo in ("pedidoId", "usuarioId", "montoTotal"):
        if pedido.get(campo) is None:
            raise ValueError(f"Falta el campo obligatorio '{campo}'")
    if float(pedido["montoTotal"]) <= 0:
        raise ValueError("El monto del pedido debe ser mayor que cero")


def registrar_pago(pagos_url, pedido):
    cuerpo = json.dumps({
        "pedidoId": pedido["pedidoId"],
        "monto": pedido["montoTotal"],
        "metodoPago": "TARJETA",
    }).encode("utf-8")
    solicitud = urllib.request.Request(
        pagos_url.rstrip("/") + "/api/pagos",
        data=cuerpo,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(solicitud, timeout=5) as respuesta:
            print(f"Pago registrado para el pedido {pedido['pedidoId']} (HTTP {respuesta.status})")
    except urllib.error.URLError as error:
        raise RuntimeError(f"No se pudo registrar el pago: {error}") from error


def notificar(topic_arn, pedido):
    import boto3  # incluido en el entorno de ejecucion de Lambda

    boto3.client("sns").publish(
        TopicArn=topic_arn,
        Subject=f"Tu pedido {pedido['pedidoId']} fue recibido",
        Message=(
            f"Hola! Recibimos tu pedido {pedido['pedidoId']} "
            f"por un total de ${pedido['montoTotal']}. "
            "Te avisaremos cuando salga en despacho."
        ),
    )
    print(f"Notificacion enviada para el pedido {pedido['pedidoId']}")
