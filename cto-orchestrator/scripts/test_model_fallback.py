#!/usr/bin/env python3
"""Tests for model_fallback. Run: python3 scripts/test_model_fallback.py"""
import os
import sys
import unittest
from unittest import mock

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import model_fallback as mf


class FallbackTests(unittest.TestCase):
    def setUp(self):
        self._env = mock.patch.dict(os.environ, {}, clear=False)
        self._env.start()
        os.environ.pop("CTO_FALLBACK_MODELS", None)

    def tearDown(self):
        self._env.stop()

    def test_default_chains(self):
        self.assertEqual(mf.fallback_chain_for("opus"), "sonnet")
        self.assertEqual(mf.fallback_chain_for("sonnet"), "haiku")
        self.assertEqual(mf.fallback_chain_for("haiku"), "")
        self.assertEqual(mf.fallback_chain_for("gpt-x"), "")

    def test_versioned_aliases(self):
        for m in ("opus-4-7", "claude-opus-4-7"):
            self.assertEqual(mf.fallback_chain_for(m), "sonnet")
        self.assertEqual(mf.fallback_chain_for("sonnet-4-6"), "haiku")
        self.assertEqual(mf.fallback_chain_for("claude-haiku-4-5-20251001"), "")

    def test_env_override(self):
        os.environ["CTO_FALLBACK_MODELS"] = "opus=sonnet,haiku;sonnet=haiku;haiku="
        self.assertEqual(mf.fallback_chain_for("opus"), "sonnet,haiku")
        os.environ["CTO_FALLBACK_MODELS"] = "haiku=sonnet"
        self.assertEqual(mf.fallback_chain_for("haiku"), "sonnet")
        self.assertEqual(mf.fallback_chain_for("opus"), "sonnet")  # default kept

    def test_env_disable(self):
        for v in ("off", "none", "0", "false", "OFF"):
            os.environ["CTO_FALLBACK_MODELS"] = v
            self.assertEqual(mf.fallback_chain_for("opus"), "", v)

    def test_env_malformed_and_self_entry(self):
        os.environ["CTO_FALLBACK_MODELS"] = "opus=bogus;garbage;sonnet=sonnet,haiku;=x"
        self.assertEqual(mf.fallback_chain_for("opus"), "sonnet")  # default
        self.assertEqual(mf.fallback_chain_for("sonnet"), "haiku")  # self dropped

    def test_reviewer_strict(self):
        self.assertEqual(mf.fallback_chain_for("opus", "reviewer-morty"), "")
        with mock.patch.object(mf, "_supported_cache", True):
            self.assertEqual(mf.fallback_args("opus", "reviewer-morty"), [])

    def test_args_supported_and_unsupported(self):
        with mock.patch.object(mf, "_supported_cache", True):
            self.assertEqual(mf.fallback_args("opus", "backend-morty"),
                             ["--fallback-model", "sonnet"])
            self.assertEqual(mf.fallback_args("haiku"), [])
        with mock.patch.object(mf, "_supported_cache", False):
            self.assertEqual(mf.fallback_args("opus"), [])

    def test_supported_exception(self):
        with mock.patch.object(mf, "_supported_cache", None), \
             mock.patch.object(mf.subprocess, "run", side_effect=OSError("no claude")):
            self.assertFalse(mf.fallback_supported())

    def test_detect_model_used(self):
        self.assertEqual(mf.detect_model_used(
            {"type": "system", "subtype": "init", "model": "claude-opus-4-7"}), "claude-opus-4-7")
        self.assertEqual(mf.detect_model_used(
            {"type": "assistant", "message": {"model": "claude-sonnet-4-6"}}), "claude-sonnet-4-6")
        self.assertEqual(mf.detect_model_used(
            {"type": "result", "modelUsage": {
                "claude-opus-4-7": {"outputTokens": 5},
                "claude-sonnet-4-6": {"outputTokens": 900}}}), "claude-sonnet-4-6")
        self.assertIsNone(mf.detect_model_used({"type": "result"}))
        self.assertIsNone(mf.detect_model_used({"type": "assistant", "message": {}}))
        self.assertIsNone(mf.detect_model_used({"type": "system", "subtype": "hook"}))

    def test_result_prefers_requested_family(self):
        ev = {"type": "result", "modelUsage": {
            "claude-sonnet-4-6": {"outputTokens": 10},
            "claude-haiku-4-5": {"outputTokens": 5000}}}
        self.assertEqual(mf.detect_model_used(ev, requested="sonnet"), "claude-sonnet-4-6")
        self.assertEqual(mf.detect_model_used(ev), "claude-haiku-4-5")
        only_sonnet = {"type": "result", "modelUsage": {"claude-sonnet-4-6": {"outputTokens": 1}}}
        used = mf.detect_model_used(only_sonnet, requested="opus")
        self.assertEqual(used, "claude-sonnet-4-6")
        self.assertTrue(mf.is_fallback("opus", used))

    def test_is_fallback(self):
        self.assertTrue(mf.is_fallback("opus", "claude-sonnet-4-6"))
        self.assertFalse(mf.is_fallback("opus", "claude-opus-4-7"))
        self.assertFalse(mf.is_fallback("opus", None))


if __name__ == "__main__":
    unittest.main(verbosity=2)
