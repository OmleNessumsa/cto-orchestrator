#!/usr/bin/env python3
"""Tests for typed SSE frames in roro_events. Run: python3 scripts/test_roro_sse_typed.py"""
import json
import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import roro_events as re_


class SSEFormatTests(unittest.TestCase):
    payload = {"schema_version": 1, "type": "cto.morty.done", "ts": "t", "payload": {}}

    def test_untyped_is_legacy_format(self):
        expected = f"id: 7\ndata: {json.dumps(self.payload)}\n\n".encode("utf-8")
        self.assertEqual(re_._format_sse_event(7, self.payload), expected)
        self.assertEqual(re_._format_sse_event(7, self.payload, False), expected)

    def test_typed_adds_event_line(self):
        out = re_._format_sse_event(7, self.payload, True).decode("utf-8")
        self.assertEqual(
            out, f"id: 7\nevent: cto.morty.done\ndata: {json.dumps(self.payload)}\n\n"
        )

    def test_typed_without_type_falls_back_to_untyped(self):
        self.assertEqual(re_._format_sse_event(1, {"a": 1}, True), re_._format_sse_event(1, {"a": 1}))

    def test_buffer_stores_payloads(self):
        re_._sse_event_buffer.clear()
        re_._push_to_sse(self.payload)
        self.assertIs(re_._sse_event_buffer[-1][1], self.payload)

    def test_ping_only_every_50(self):
        import queue
        q = queue.Queue()
        re_._sse_clients.append(q)
        try:
            with re_._sse_buffer_lock:
                re_._sse_event_counter = 48
            for _ in range(3):
                re_._push_to_sse(self.payload)
            items = []
            while not q.empty():
                items.append(q.get_nowait())
            self.assertEqual(sum(1 for i in items if i is re_._SSE_PING), 1)
        finally:
            re_._sse_clients.remove(q)


if __name__ == "__main__":
    unittest.main()
