import unittest

from research.kolkhoz_research.ratings import (
    DEFAULT_MU,
    DEFAULT_SIGMA,
    RatingInput,
    display_rating,
    rate_multiplayer,
)


class RatingTests(unittest.TestCase):
    def test_multiplayer_rating_rewards_higher_finish(self) -> None:
        outputs = rate_multiplayer(
            [
                RatingInput(key="winner", rank=1, score=42),
                RatingInput(key="second", rank=2, score=31),
                RatingInput(key="third", rank=3, score=20),
                RatingInput(key="fourth", rank=4, score=10),
            ]
        )

        self.assertGreater(outputs["winner"].mu, DEFAULT_MU)
        self.assertLess(outputs["fourth"].mu, DEFAULT_MU)
        self.assertGreater(
            outputs["winner"].display_rating,
            outputs["fourth"].display_rating,
        )
        self.assertLess(outputs["winner"].sigma, DEFAULT_SIGMA)

    def test_display_rating_keeps_default_at_1000(self) -> None:
        self.assertEqual(display_rating(DEFAULT_MU, DEFAULT_SIGMA), 1000)


if __name__ == "__main__":
    unittest.main()
