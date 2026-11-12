#!/usr/bin/env python3
"""Unit tests for require_reviews_token.py. No GitHub network."""

from __future__ import annotations

from pathlib import Path
import unittest

import require_reviews_token as guard

ROOT = Path(__file__).resolve().parents[2]


class RequireReviewsTokenTests(unittest.TestCase):
    def test_present_token_passes(self) -> None:
        code, line = guard.check_token("github_pat_test", "true")
        self.assertEqual(code, 0)
        self.assertIn("is set", line)

    def test_empty_token_warns_until_required(self) -> None:
        code, line = guard.check_token("", "")
        self.assertEqual(code, 0)
        self.assertTrue(line.startswith("::warning::"))
        self.assertIn("ZOTEATS_REVIEWS_TOKEN is empty", line)

    def test_empty_token_fails_when_required(self) -> None:
        code, line = guard.check_token("  ", "true")
        self.assertEqual(code, 1)
        self.assertTrue(line.startswith("::error::"))

    def test_require_accepts_yes_and_one(self) -> None:
        self.assertTrue(guard.is_required("YES"))
        self.assertTrue(guard.is_required("1"))
        self.assertFalse(guard.is_required("false"))
        self.assertFalse(guard.is_required(""))

    def test_release_workflows_call_the_guard(self) -> None:
        testflight = (ROOT / ".github/workflows/testflight.yml").read_text()
        android = (ROOT / ".github/workflows/android.yml").read_text()
        self.assertIn("apple/scripts/require_reviews_token.py", testflight)
        self.assertIn("ZOTEATS_REQUIRE_REVIEWS_TOKEN", testflight)
        self.assertIn("apple/scripts/require_reviews_token.py", android)


if __name__ == "__main__":
    unittest.main()
