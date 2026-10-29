#!/usr/bin/env python3
"""Unit tests for forward_dish_feedback.py. No live network."""

from __future__ import annotations

import io
import json
import unittest
from urllib.error import HTTPError, URLError

import forward_dish_feedback as forward


class FakeResponse:
    def __init__(self, status=200):
        self.status = status

    def __enter__(self):
        return self

    def __exit__(self, *args):
        return False


class ForwardDishFeedbackTests(unittest.TestCase):
    def test_clips_to_500_and_maps_fields(self) -> None:
        body = forward.webhook_body(
            {
                "text": "  " + ("x" * 520) + "  ",
                "dishName": "Jasmine Rice",
                "hall": "anteatery",
                "meal": "Lunch",
                "date": "2026-10-29",
            }
        )
        self.assertEqual(len(body["text"]), 500)
        self.assertEqual(
            body,
            {
                "text": "x" * 500,
                "dish": "Jasmine Rice",
                "hall": "anteatery",
                "meal": "Lunch",
                "date": "2026-10-29",
            },
        )

    def test_missing_url_is_inert(self) -> None:
        called = {"n": 0}

        def opener(_request, timeout=20):
            called["n"] += 1
            return FakeResponse()

        code = forward.post_feedback(
            url="",
            key="secret",
            payload={"text": "Sauce is cold", "dishName": "Rice", "hall": "anteatery", "meal": "Lunch", "date": "2026-10-29"},
            opener=opener,
        )
        self.assertEqual(code, 0)
        self.assertEqual(called["n"], 0)

    def test_posts_json_and_authorization_header(self) -> None:
        captured: dict = {}

        def opener(request, timeout=20):
            captured["url"] = request.full_url
            captured["auth"] = request.get_header("Authorization")
            captured["type"] = request.get_header("Content-type")
            captured["body"] = json.loads(request.data.decode("utf-8"))
            captured["timeout"] = timeout
            return FakeResponse(204)

        code = forward.post_feedback(
            url="https://example.test/hook",
            key="Bearer test-key",
            payload={
                "text": "Wrong sauce",
                "dishName": "Linguine",
                "hall": "brandywine",
                "meal": "Dinner",
                "date": "2026-10-29",
            },
            opener=opener,
        )
        self.assertEqual(code, 0)
        self.assertEqual(captured["url"], "https://example.test/hook")
        self.assertEqual(captured["auth"], "Bearer test-key")
        self.assertEqual(captured["type"], "application/json")
        self.assertEqual(
            captured["body"],
            {
                "text": "Wrong sauce",
                "dish": "Linguine",
                "hall": "brandywine",
                "meal": "Dinner",
                "date": "2026-10-29",
            },
        )

    def test_http_error_is_nonzero(self) -> None:
        def opener(_request, timeout=20):
            raise HTTPError("https://example.test/hook", 500, "nope", hdrs=None, fp=io.BytesIO())

        code = forward.post_feedback(
            url="https://example.test/hook",
            key="",
            payload={"text": "note", "dishName": "Rice", "hall": "a", "meal": "Lunch", "date": "2026-10-29"},
            opener=opener,
        )
        self.assertEqual(code, 1)

    def test_url_error_is_nonzero(self) -> None:
        def opener(_request, timeout=20):
            raise URLError("offline")

        code = forward.post_feedback(
            url="https://example.test/hook",
            key="",
            payload={"text": "note", "dishName": "Rice", "hall": "a", "meal": "Lunch", "date": "2026-10-29"},
            opener=opener,
        )
        self.assertEqual(code, 1)


if __name__ == "__main__":
    unittest.main()
