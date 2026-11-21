import json
import unittest
from unittest import mock

import handler


def evento(*cuerpos):
    return {"Records": [{"messageId": f"m{i}", "body": json.dumps(c)} for i, c in enumerate(cuerpos)]}


PEDIDO_OK = {"pedidoId": 1, "usuarioId": 7, "montoTotal": 9990, "estado": "PENDIENTE"}


class HandlerTest(unittest.TestCase):

    def test_pedido_valido_no_genera_fallos(self):
        with mock.patch.dict("os.environ", {}, clear=True):
            self.assertEqual(handler.lambda_handler(evento(PEDIDO_OK), None), {"batchItemFailures": []})

    def test_pedido_sin_monto_se_reporta_como_fallido(self):
        malo = {"pedidoId": 2, "usuarioId": 7}
        with mock.patch.dict("os.environ", {}, clear=True):
            resultado = handler.lambda_handler(evento(PEDIDO_OK, malo), None)
        self.assertEqual(resultado, {"batchItemFailures": [{"itemIdentifier": "m1"}]})

    def test_monto_cero_es_invalido(self):
        with self.assertRaises(ValueError):
            handler.validar_pedido({"pedidoId": 1, "usuarioId": 1, "montoTotal": 0})

    def test_llama_a_pagos_y_notifica_cuando_estan_configurados(self):
        entorno = {"PAGOS_URL": "http://pagos:8084", "TOPIC_ARN": "arn:aws:sns:us-east-1:1:t"}
        with mock.patch.dict("os.environ", entorno, clear=True), \
                mock.patch.object(handler, "registrar_pago") as pago, \
                mock.patch.object(handler, "notificar") as aviso:
            handler.lambda_handler(evento(PEDIDO_OK), None)
        pago.assert_called_once_with("http://pagos:8084", PEDIDO_OK)
        aviso.assert_called_once_with("arn:aws:sns:us-east-1:1:t", PEDIDO_OK)

    def test_json_invalido_se_reporta_como_fallido(self):
        roto = {"Records": [{"messageId": "x", "body": "no es json"}]}
        self.assertEqual(handler.lambda_handler(roto, None), {"batchItemFailures": [{"itemIdentifier": "x"}]})


if __name__ == "__main__":
    unittest.main()
