from __future__ import annotations

import ctypes
import hashlib
import os
import platform
import subprocess
from dataclasses import dataclass
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[2]
ENGINE_DIR = REPO_ROOT / "ios/KolkhozSwiftUI/Sources/KolkhozCEngine"
ENGINE_C = ENGINE_DIR / "KolkhozCEngine.c"
ENGINE_H = ENGINE_DIR / "include/KolkhozCEngine.h"
BUILD_DIR = REPO_ROOT / "research/.build"


class KCVariants(ctypes.Structure):
    _fields_ = [
        ("deck_type", ctypes.c_int32),
        ("nomenclature", ctypes.c_bool),
        ("allow_swap", ctypes.c_bool),
        ("northern_style", ctypes.c_bool),
        ("mice_variant", ctypes.c_bool),
        ("orden_nachalniku", ctypes.c_bool),
        ("medals_count", ctypes.c_bool),
        ("accumulate_jobs", ctypes.c_bool),
        ("hero_of_soviet_union", ctypes.c_bool),
    ]


class KCCard(ctypes.Structure):
    _fields_ = [
        ("suit", ctypes.c_int32),
        ("value", ctypes.c_int32),
    ]


class KCAction(ctypes.Structure):
    _fields_ = [
        ("kind", ctypes.c_int32),
        ("player_id", ctypes.c_int32),
        ("suit", ctypes.c_int32),
        ("card", KCCard),
        ("hand_card", KCCard),
        ("plot_card", KCCard),
        ("plot_zone", ctypes.c_int32),
        ("target_suit", ctypes.c_int32),
    ]


class KCGameRunResult(ctypes.Structure):
    _fields_ = [
        ("actions", ctypes.c_int32),
        ("checksum", ctypes.c_int32),
    ]


DoublePointer = ctypes.POINTER(ctypes.c_double)
LayerPointerArray = DoublePointer * 4


class KCPolicyModelBuffer(ctypes.Structure):
    _fields_ = [
        ("input_size", ctypes.c_int32),
        ("hidden_size", ctypes.c_int32),
        ("layer_count", ctypes.c_int32),
        ("layer_sizes", ctypes.c_int32 * 4),
        ("head_count", ctypes.c_int32),
        ("w1", DoublePointer),
        ("b1", DoublePointer),
        ("layer_weights", LayerPointerArray),
        ("layer_biases", LayerPointerArray),
        ("w2", DoublePointer),
        ("output_weights", DoublePointer),
        ("b2", DoublePointer),
        ("b2s", DoublePointer),
    ]


class KCPolicyGradientConfig(ctypes.Structure):
    _fields_ = [
        ("episodes", ctypes.c_int32),
        ("batch_size", ctypes.c_int32),
        ("seed", ctypes.c_uint64),
        ("learning_rate", ctypes.c_double),
        ("temperature", ctypes.c_double),
        ("max_gradient_norm", ctypes.c_double),
        ("l2", ctypes.c_double),
        ("win_weight", ctypes.c_double),
        ("strict_weight", ctypes.c_double),
        ("rank_weight", ctypes.c_double),
        ("margin_weight", ctypes.c_double),
        ("score_delta_weight", ctypes.c_double),
        ("margin_delta_weight", ctypes.c_double),
        ("work_delta_weight", ctypes.c_double),
        ("claim_delta_weight", ctypes.c_double),
        ("own_requisition_weight", ctypes.c_double),
        ("thread_count", ctypes.c_int32),
        ("greedy_sample_rate", ctypes.c_double),
        ("advantage_baseline_beta", ctypes.c_double),
        ("advantage_clip", ctypes.c_double),
        ("value_learning_rate", ctypes.c_double),
        ("value_weights", DoublePointer),
        ("training_seat_count", ctypes.c_int32),
        ("training_seats", ctypes.c_int32 * 4),
        ("round_curriculum", ctypes.c_bool),
        ("round_plot_cards", ctypes.c_int32),
        ("round_famine_rate", ctypes.c_double),
        ("has_opponent_model", ctypes.c_bool),
        ("opponent_is_heuristic", ctypes.c_bool),
        ("paired_baseline", ctypes.c_bool),
        ("freeze_hidden", ctypes.c_bool),
        ("per_transition_value_advantages", ctypes.c_bool),
        ("phase_balanced_ppo", ctypes.c_bool),
        ("use_ppo", ctypes.c_bool),
        ("use_adam", ctypes.c_bool),
        ("imitation_weight", ctypes.c_double),
        ("imitation_trump_weight", ctypes.c_double),
        ("imitation_swap_weight", ctypes.c_double),
        ("imitation_play_weight", ctypes.c_double),
        ("imitation_assign_weight", ctypes.c_double),
        ("teacher_forcing_rate", ctypes.c_double),
        ("ppo_epochs", ctypes.c_int32),
        ("ppo_minibatch_size", ctypes.c_int32),
        ("ppo_clip", ctypes.c_double),
        ("entropy_weight", ctypes.c_double),
        ("adam_beta1", ctypes.c_double),
        ("adam_beta2", ctypes.c_double),
        ("adam_epsilon", ctypes.c_double),
        ("opponent_model", KCPolicyModelBuffer),
    ]


class KCPolicyGradientResult(ctypes.Structure):
    _fields_ = [
        ("episodes", ctypes.c_int32),
        ("actions", ctypes.c_int32),
        ("batches", ctypes.c_int32),
        ("checksum", ctypes.c_int32),
        ("top_rate", ctypes.c_double),
        ("average_rank", ctypes.c_double),
        ("average_margin", ctypes.c_double),
        ("average_reward", ctypes.c_double),
        ("average_advantage", ctypes.c_double),
        ("last_gradient_norm", ctypes.c_double),
        ("last_clip_scale", ctypes.c_double),
        ("average_ppo_kl", ctypes.c_double),
        ("average_ppo_abs_kl", ctypes.c_double),
        ("average_ppo_entropy", ctypes.c_double),
        ("average_ppo_clip_fraction", ctypes.c_double),
        ("weight_checksum", ctypes.c_double),
    ]


class KCPolicyMatchupGameResult(ctypes.Structure):
    _fields_ = [
        ("status", ctypes.c_int32),
        ("actions", ctypes.c_int32),
        ("checksum", ctypes.c_int32),
        ("scores", ctypes.c_int32 * 4),
        ("medals", ctypes.c_int32 * 4),
        ("winner_id", ctypes.c_int32),
    ]


class KCPolicyActionFeatures(ctypes.Structure):
    _fields_ = [
        ("action", KCAction),
        ("action_head", ctypes.c_int32),
        ("feature_count", ctypes.c_int32),
        ("feature_indices", ctypes.c_int32 * 256),
        ("feature_values", ctypes.c_double * 256),
    ]


@dataclass(frozen=True)
class EngineProvenance:
    git_sha: str
    c_sha256: str
    header_sha256: str
    library_path: str


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _git_sha() -> str:
    try:
        result = subprocess.run(
            ["git", "rev-parse", "HEAD"],
            cwd=REPO_ROOT,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            check=True,
        )
        return result.stdout.strip()
    except Exception:
        return "unknown"


def shared_library_path() -> Path:
    suffix = ".dylib" if platform.system() == "Darwin" else ".so"
    return BUILD_DIR / f"libkolkhoz_engine{suffix}"


def build_shared_library(force: bool = False) -> Path:
    BUILD_DIR.mkdir(parents=True, exist_ok=True)
    output = shared_library_path()
    source_mtime = max(ENGINE_C.stat().st_mtime, ENGINE_H.stat().st_mtime)
    if output.exists() and not force and output.stat().st_mtime >= source_mtime:
        return output

    if platform.system() == "Darwin":
        command = [
            "clang",
            "-std=c11",
            "-O3",
            "-dynamiclib",
            "-I",
            str(ENGINE_DIR / "include"),
            str(ENGINE_C),
            "-o",
            str(output),
        ]
    else:
        command = [
            "cc",
            "-std=c11",
            "-O3",
            "-shared",
            "-fPIC",
            "-I",
            str(ENGINE_DIR / "include"),
            str(ENGINE_C),
            "-o",
            str(output),
        ]
    subprocess.run(command, cwd=REPO_ROOT, check=True)
    return output


class CEngine:
    def __init__(self, library_path: Path | None = None) -> None:
        self.library_path = library_path or build_shared_library()
        self.lib = ctypes.CDLL(os.fspath(self.library_path))

        self.lib.kc_variants_kolkhoz.argtypes = [ctypes.POINTER(KCVariants)]
        self.lib.kc_variants_kolkhoz.restype = None
        self.lib.kc_run_benchmark_game.argtypes = [ctypes.c_uint64, KCVariants]
        self.lib.kc_run_benchmark_game.restype = KCGameRunResult
        self.lib.kc_engine_alloc.argtypes = []
        self.lib.kc_engine_alloc.restype = ctypes.c_void_p
        self.lib.kc_engine_free.argtypes = [ctypes.c_void_p]
        self.lib.kc_engine_free.restype = None
        self.lib.kc_engine_init.argtypes = [ctypes.c_void_p, ctypes.c_uint64, KCVariants]
        self.lib.kc_engine_init.restype = None
        self.lib.kc_engine_apply_policy_action.argtypes = [ctypes.c_void_p, KCAction]
        self.lib.kc_engine_apply_policy_action.restype = ctypes.c_int32
        self.lib.kc_engine_policy_action_features.argtypes = [
            ctypes.c_void_p,
            ctypes.c_int32,
            ctypes.c_int32,
            ctypes.POINTER(KCPolicyActionFeatures),
            ctypes.c_int32,
        ]
        self.lib.kc_engine_policy_action_features.restype = ctypes.c_int32
        self.lib.kc_engine_heuristic_policy_action.argtypes = [ctypes.c_void_p, ctypes.POINTER(KCAction)]
        self.lib.kc_engine_heuristic_policy_action.restype = ctypes.c_bool
        self.lib.kc_engine_waiting_player.argtypes = [ctypes.c_void_p]
        self.lib.kc_engine_waiting_player.restype = ctypes.c_int32
        self.lib.kc_final_score.argtypes = [ctypes.c_void_p, ctypes.c_int32]
        self.lib.kc_final_score.restype = ctypes.c_int32
        self.lib.kc_total_medals.argtypes = [ctypes.c_void_p, ctypes.c_int32]
        self.lib.kc_total_medals.restype = ctypes.c_int32
        self.lib.kc_run_policy_matchup_game.argtypes = [
            ctypes.c_uint64,
            KCVariants,
            KCPolicyModelBuffer,
            ctypes.c_bool,
            KCPolicyModelBuffer,
            ctypes.c_bool,
            ctypes.c_int32,
            ctypes.c_bool,
            ctypes.c_int32,
            ctypes.c_double,
        ]
        self.lib.kc_run_policy_matchup_game.restype = KCPolicyMatchupGameResult
        self.lib.kc_train_policy_gradient.argtypes = [
            KCPolicyModelBuffer,
            KCPolicyGradientConfig,
            ctypes.POINTER(KCPolicyGradientResult),
        ]
        self.lib.kc_train_policy_gradient.restype = ctypes.c_int32

    def kolkhoz_variants(self) -> KCVariants:
        variants = KCVariants()
        self.lib.kc_variants_kolkhoz(ctypes.byref(variants))
        return variants

    def run_smoke_game(self, seed: int) -> KCGameRunResult:
        return self.lib.kc_run_benchmark_game(ctypes.c_uint64(seed), self.kolkhoz_variants())

    def new_engine(self, seed: int) -> ctypes.c_void_p:
        pointer = self.lib.kc_engine_alloc()
        if not pointer:
            raise MemoryError("kc_engine_alloc failed")
        self.lib.kc_engine_init(pointer, ctypes.c_uint64(seed), self.kolkhoz_variants())
        return ctypes.c_void_p(pointer)

    def free_engine(self, pointer: ctypes.c_void_p) -> None:
        self.lib.kc_engine_free(pointer)

    def waiting_player(self, pointer: ctypes.c_void_p) -> int:
        return int(self.lib.kc_engine_waiting_player(pointer))

    def policy_action_features(
        self,
        pointer: ctypes.c_void_p,
        *,
        player_id: int,
        input_size: int,
        max_features: int = 256,
    ) -> list[KCPolicyActionFeatures]:
        items = (KCPolicyActionFeatures * max_features)()
        count = self.lib.kc_engine_policy_action_features(
            pointer,
            ctypes.c_int32(player_id),
            ctypes.c_int32(input_size),
            items,
            ctypes.c_int32(max_features),
        )
        return [items[index] for index in range(int(count))]

    def heuristic_action(self, pointer: ctypes.c_void_p) -> KCAction:
        action = KCAction()
        ok = self.lib.kc_engine_heuristic_policy_action(pointer, ctypes.byref(action))
        if not ok:
            raise RuntimeError("C heuristic could not choose an action")
        return action

    def apply_policy_action(self, pointer: ctypes.c_void_p, action: KCAction) -> None:
        status = int(self.lib.kc_engine_apply_policy_action(pointer, action))
        if status != 0:
            raise RuntimeError(f"C engine rejected policy action with status {status}")

    def final_scores(self, pointer: ctypes.c_void_p) -> list[int]:
        return [int(self.lib.kc_final_score(pointer, player_id)) for player_id in range(4)]

    def total_medals(self, pointer: ctypes.c_void_p) -> list[int]:
        return [int(self.lib.kc_total_medals(pointer, player_id)) for player_id in range(4)]

    def run_policy_matchup_game(
        self,
        *,
        seed: int,
        model: KCPolicyModelBuffer,
        model_is_heuristic: bool,
        opponent_model: KCPolicyModelBuffer,
        opponent_is_heuristic: bool,
        model_seat: int,
        round_curriculum: bool = False,
        round_plot_cards: int = 0,
        round_famine_rate: float = 0.0,
    ) -> KCPolicyMatchupGameResult:
        return self.lib.kc_run_policy_matchup_game(
            ctypes.c_uint64(seed),
            self.kolkhoz_variants(),
            model,
            bool(model_is_heuristic),
            opponent_model,
            bool(opponent_is_heuristic),
            ctypes.c_int32(model_seat),
            bool(round_curriculum),
            ctypes.c_int32(round_plot_cards),
            ctypes.c_double(round_famine_rate),
        )

    def train_policy_gradient(
        self,
        model: KCPolicyModelBuffer,
        config: KCPolicyGradientConfig,
    ) -> tuple[int, KCPolicyGradientResult]:
        result = KCPolicyGradientResult()
        status = self.lib.kc_train_policy_gradient(model, config, ctypes.byref(result))
        return int(status), result

    def provenance(self) -> EngineProvenance:
        return EngineProvenance(
            git_sha=_git_sha(),
            c_sha256=_sha256(ENGINE_C),
            header_sha256=_sha256(ENGINE_H),
            library_path=os.fspath(self.library_path),
        )
