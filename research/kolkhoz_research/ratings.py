from __future__ import annotations

from dataclasses import dataclass
from math import exp, log1p, sqrt


DEFAULT_MU = 25.0
DEFAULT_SIGMA = DEFAULT_MU / 3.0
MIN_SIGMA = 2.0
BETA = DEFAULT_MU / 6.0
TAU = DEFAULT_MU / 300.0
DISPLAY_SCALE = 32.0
DISPLAY_MIN = 100
DISPLAY_MAX = 3000


@dataclass(frozen=True)
class RatingInput:
    key: str
    rank: float
    score: float
    mu: float = DEFAULT_MU
    sigma: float = DEFAULT_SIGMA


@dataclass(frozen=True)
class RatingOutput:
    key: str
    mu: float
    sigma: float
    display_rating: int


def display_rating(mu: float, sigma: float) -> int:
    value = round(
        1000.0
        + (mu - DEFAULT_MU) * DISPLAY_SCALE
        - (sigma - DEFAULT_SIGMA) * (DISPLAY_SCALE / 4.0)
    )
    return max(DISPLAY_MIN, min(DISPLAY_MAX, value))


def rate_multiplayer(participants: list[RatingInput]) -> dict[str, RatingOutput]:
    if len(participants) < 2:
        return {
            item.key: RatingOutput(
                key=item.key,
                mu=item.mu,
                sigma=item.sigma,
                display_rating=display_rating(item.mu, item.sigma),
            )
            for item in participants
        }

    deltas = {item.key: 0.0 for item in participants}
    counts = {item.key: 0 for item in participants}
    by_key = {item.key: item for item in participants}
    for index, left in enumerate(participants):
        for right in participants[index + 1 :]:
            left_actual = _pairwise_actual(left.rank, right.rank)
            right_actual = 1.0 - left_actual
            expected_left = _expected_score(left, right)
            expected_right = 1.0 - expected_left
            scale = _match_scale(left, right)
            deltas[left.key] += scale * (left_actual - expected_left)
            deltas[right.key] += scale * (right_actual - expected_right)
            counts[left.key] += 1
            counts[right.key] += 1

    outputs: dict[str, RatingOutput] = {}
    for key, item in by_key.items():
        pair_count = max(1, counts[key])
        next_mu = max(1.0, item.mu + deltas[key] / pair_count)
        inflated_sigma = sqrt(item.sigma * item.sigma + TAU * TAU)
        next_sigma = max(MIN_SIGMA, inflated_sigma * 0.985)
        outputs[key] = RatingOutput(
            key=key,
            mu=next_mu,
            sigma=next_sigma,
            display_rating=display_rating(next_mu, next_sigma),
        )
    return outputs


def _pairwise_actual(left_rank: float, right_rank: float) -> float:
    if left_rank < right_rank:
        return 1.0
    if left_rank > right_rank:
        return 0.0
    return 0.5


def _expected_score(left: RatingInput, right: RatingInput) -> float:
    variance = sqrt(
        left.sigma * left.sigma
        + right.sigma * right.sigma
        + 2.0 * BETA * BETA
    )
    exponent = max(-30.0, min(30.0, (right.mu - left.mu) / variance))
    return 1.0 / (1.0 + exp(exponent))


def _match_scale(left: RatingInput, right: RatingInput) -> float:
    uncertainty = sqrt(left.sigma * left.sigma + right.sigma * right.sigma)
    uncertainty /= sqrt(2.0) * DEFAULT_SIGMA
    uncertainty = max(0.65, min(1.5, uncertainty))
    margin = abs(left.score - right.score)
    margin_scale = 1.0 + min(0.35, log1p(margin) / 20.0)
    return 2.4 * uncertainty * margin_scale
