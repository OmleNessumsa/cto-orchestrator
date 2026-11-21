#!/usr/bin/env python3
"""Tests for token coalescing in roro_events. Run: python3 scripts/test_roro_token_coalesce.py"""
import os
import sys
import unittest
from unittest import mock

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import roro_events as re_


class TokenCoalesceTests(unittest.TestCase):
    def setUp(self):
        self._env = mock.patch.dict(os.environ, {"RICK_TOKEN_COALESCE_MS": "100"}, clear=False)
        self._env.start()
        self.sent = []
        self._p = mock.patch.object(
            re_, "get_config",
            return_value={"enabled": True, "endpoint": "http://localhost:1/x", "timeout": 1.0},
        )
        self._p.start()
        self._s = mock.patch.object(re_, "_send_event", side_effect=lambda ep, payload, *a: self.sent.append(payload))
        self._s.start()

    def tearDown(self):
        re_.flush()
        self._s.stop()
        self._p.stop()
        self._env.stop()

    def _texts(self):
        return [(p.get("payload") or p.get("data"))["text"] for p in self.sent]

    def test_rapid_tokens_coalesced_in_order(self):
        for i in range(50):
            re_.emit_stream_progress("morty.token", {"text": f"{i},"}, role="backend-morty")
        re_.flush()
        self.assertTrue(1 <= len(self.sent) <= 2)
        self.assertEqual("".join(self._texts()), "".join(f"{i}," for i in range(50)))

    def test_non_token_event_flushes_first(self):
        re_.emit_stream_progress("morty.token", {"text": "abc"}, role="backend-morty")
        re_.emit_morty_done(role="backend-morty")
        re_.flush()
        types = [p.get("type") or p.get("eventType") for p in self.sent]
        self.assertEqual(types, ["cto.morty.token", "cto.morty.done"])

    def test_disabled_emits_each_token(self):
        os.environ["RICK_TOKEN_COALESCE_MS"] = "0"
        for i in range(5):
            re_.emit_stream_progress("morty.token", {"text": "x"}, role="backend-morty")
        re_.flush()
        self.assertEqual(len(self.sent), 5)


if __name__ == "__main__":
    unittest.main()
