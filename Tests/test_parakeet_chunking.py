#!/usr/bin/env python3
"""Unit tests for Parakeet chunking helpers."""

import os
import sys
import unittest

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "Sources"))

from ml import parakeet  # noqa: E402


class ParakeetChunkingTests(unittest.TestCase):
    def test_iter_chunk_ranges_with_overlap(self):
        ranges = parakeet._iter_chunk_ranges(
            total_samples=160_000,  # 10s @ 16kHz
            chunk_samples=64_000,   # 4s
            overlap_samples=16_000, # 1s overlap
        )
        self.assertEqual(
            ranges,
            [
                (0, 64_000),
                (48_000, 112_000),
                (96_000, 160_000),
            ],
        )

    def test_iter_chunk_ranges_overlap_guard(self):
        ranges = parakeet._iter_chunk_ranges(
            total_samples=30,
            chunk_samples=10,
            overlap_samples=10,  # invalid; should be guarded
        )
        self.assertEqual(ranges, [(0, 10), (8, 18), (16, 26), (24, 30)])

    def test_merge_text_with_overlap(self):
        merged = parakeet._merge_text_with_overlap(
            "hello world how are",
            "how are you today",
        )
        self.assertEqual(merged, "hello world how are you today")

    def test_merge_text_without_overlap(self):
        merged = parakeet._merge_text_with_overlap(
            "hello world",
            "good morning",
        )
        self.assertEqual(merged, "hello world good morning")


if __name__ == "__main__":
    unittest.main()
