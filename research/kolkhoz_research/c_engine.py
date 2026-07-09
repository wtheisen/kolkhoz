from __future__ import annotations

import ctypes
import hashlib
import os
import platform
import subprocess
from dataclasses import dataclass
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[2]
ENGINE_DIR = REPO_ROOT / "engine/KolkhozCEngine"
ENGINE_H = ENGINE_DIR / "include/KolkhozCEngine.h"
BUILD_DIR = REPO_ROOT / "research/.build"
OBJECT_SCALAR_COUNT = 8
ACTION_SCALAR_COUNT = 32
STATE_INPUT_SIZE = 200
MAX_OBJECT_TOKENS = 256


class KCVariants(ctypes.Structure):
    _fields_ = [
        ("deck_type", ctypes.c_int32),
        ("max_years", ctypes.c_int32),
        ("nomenclature", ctypes.c_bool),
        ("allow_swap", ctypes.c_bool),
        ("northern_style", ctypes.c_bool),
        ("mice_variant", ctypes.c_bool),
        ("orden_nachalniku", ctypes.c_bool),
        ("medals_count", ctypes.c_bool),
        ("accumulate_jobs", ctypes.c_bool),
        ("hero_of_soviet_union", ctypes.c_bool),
        ("wrecker", ctypes.c_bool),
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


class KCControllers(ctypes.Structure):
    _fields_ = [
        ("seats", ctypes.c_int32 * 4),
    ]


class KCGameRunResult(ctypes.Structure):
    _fields_ = [
        ("actions", ctypes.c_int32),
        ("checksum", ctypes.c_int32),
    ]


DoublePointer = ctypes.POINTER(ctypes.c_double)
FloatPointer = ctypes.POINTER(ctypes.c_float)
IntPointer = ctypes.POINTER(ctypes.c_int32)
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


class KCObjectToken(ctypes.Structure):
    _fields_ = [
        ("type", ctypes.c_int32),
        ("owner", ctypes.c_int32),
        ("zone", ctypes.c_int32),
        ("suit", ctypes.c_int32),
        ("value", ctypes.c_int32),
        ("index", ctypes.c_int32),
        ("scalars", ctypes.c_double * OBJECT_SCALAR_COUNT),
    ]


class KCDensePolicyActionFeatures(ctypes.Structure):
    _fields_ = [
        ("actions", ctypes.POINTER(KCAction)),
        ("action_heads", IntPointer),
        ("kind_ids", IntPointer),
        ("player_ids", IntPointer),
        ("suit_ids", IntPointer),
        ("target_suit_ids", IntPointer),
        ("card_suit_ids", IntPointer),
        ("card_value_ids", IntPointer),
        ("hand_suit_ids", IntPointer),
        ("hand_value_ids", IntPointer),
        ("plot_suit_ids", IntPointer),
        ("plot_value_ids", IntPointer),
        ("plot_zone_ids", IntPointer),
        ("action_scalars", FloatPointer),
        ("action_scalar_count", ctypes.c_int32),
        ("features", FloatPointer),
        ("max_actions", ctypes.c_int32),
        ("input_size", ctypes.c_int32),
    ]


class KCDenseObjectTokens(ctypes.Structure):
    _fields_ = [
        ("type_ids", IntPointer),
        ("owner_ids", IntPointer),
        ("zone_ids", IntPointer),
        ("suit_ids", IntPointer),
        ("value_ids", IntPointer),
        ("index_ids", IntPointer),
        ("scalars", FloatPointer),
        ("max_tokens", ctypes.c_int32),
    ]


@dataclass(frozen=True)
class DensePolicyActionFeatures:
    count: int
    input_size: int
    actions: object
    action_heads: object
    kind_ids: object
    player_ids: object
    suit_ids: object
    target_suit_ids: object
    card_suit_ids: object
    card_value_ids: object
    hand_suit_ids: object
    hand_value_ids: object
    plot_suit_ids: object
    plot_value_ids: object
    plot_zone_ids: object
    action_scalars: object
    action_scalar_count: int
    features: object

    def __len__(self) -> int:
        return self.count

    def action_at(self, index: int) -> KCAction:
        return self.actions[index]


@dataclass(frozen=True)
class DenseObjectTokens:
    count: int
    type_ids: object
    owner_ids: object
    zone_ids: object
    suit_ids: object
    value_ids: object
    index_ids: object
    scalars: object

    def __len__(self) -> int:
        return self.count


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


def _engine_sources() -> list[Path]:
    return sorted(ENGINE_DIR.glob("*.c"))


def _sha256_sources(paths: list[Path]) -> str:
    digest = hashlib.sha256()
    for path in paths:
        digest.update(path.name.encode("utf-8"))
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
    sources = _engine_sources()
    source_mtime = max([ENGINE_H.stat().st_mtime, *(source.stat().st_mtime for source in sources)])
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
            *(str(source) for source in sources),
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
            *(str(source) for source in sources),
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
        self.lib.kc_engine_clone.argtypes = [ctypes.c_void_p, ctypes.c_void_p]
        self.lib.kc_engine_clone.restype = None
        self.lib.kc_engine_sample_determinization.argtypes = [
            ctypes.c_void_p,
            ctypes.c_int32,
            ctypes.c_uint64,
            ctypes.c_void_p,
        ]
        self.lib.kc_engine_sample_determinization.restype = ctypes.c_bool
        self.lib.kc_engine_init.argtypes = [ctypes.c_void_p, ctypes.c_uint64, KCVariants]
        self.lib.kc_engine_init.restype = None
        self.lib.kc_engine_init_with_controllers.argtypes = [
            ctypes.c_void_p,
            ctypes.c_uint64,
            KCVariants,
            KCControllers,
        ]
        self.lib.kc_engine_init_with_controllers.restype = None
        self.lib.kc_engine_init_curriculum.argtypes = [
            ctypes.c_void_p,
            ctypes.c_uint64,
            KCVariants,
            ctypes.c_int32,
            ctypes.c_double,
        ]
        self.lib.kc_engine_init_curriculum.restype = None
        self.lib.kc_engine_init_curriculum_rounds.argtypes = [
            ctypes.c_void_p,
            ctypes.c_uint64,
            KCVariants,
            ctypes.c_int32,
            ctypes.c_double,
            ctypes.c_int32,
        ]
        self.lib.kc_engine_init_curriculum_rounds.restype = None
        self.lib.kc_engine_step_automatic.argtypes = [ctypes.c_void_p]
        self.lib.kc_engine_step_automatic.restype = ctypes.c_int32
        self.lib.kc_engine_step_policy_automatic.argtypes = [
            ctypes.c_void_p,
            KCPolicyModelBuffer,
        ]
        self.lib.kc_engine_step_policy_automatic.restype = ctypes.c_int32
        self.lib.kc_engine_policy_action.argtypes = [
            ctypes.c_void_p,
            KCPolicyModelBuffer,
            ctypes.POINTER(KCAction),
        ]
        self.lib.kc_engine_policy_action.restype = ctypes.c_bool
        self.lib.kc_engine_apply_ai_action.argtypes = [ctypes.c_void_p, KCAction]
        self.lib.kc_engine_apply_ai_action.restype = ctypes.c_int32
        self.lib.kc_engine_apply_policy_action.argtypes = [ctypes.c_void_p, KCAction]
        self.lib.kc_engine_apply_policy_action.restype = ctypes.c_int32
        self.lib.kc_engine_apply.argtypes = [ctypes.c_void_p, KCAction]
        self.lib.kc_engine_apply.restype = ctypes.c_int32
        self.lib.kc_engine_legal_actions.argtypes = [
            ctypes.c_void_p,
            ctypes.POINTER(KCAction),
            ctypes.c_int32,
        ]
        self.lib.kc_engine_legal_actions.restype = ctypes.c_int32
        self.lib.kc_engine_policy_action_features.argtypes = [
            ctypes.c_void_p,
            ctypes.c_int32,
            ctypes.c_int32,
            ctypes.POINTER(KCPolicyActionFeatures),
            ctypes.c_int32,
        ]
        self.lib.kc_engine_policy_action_features.restype = ctypes.c_int32
        self.lib.kc_engine_policy_action_dense_features.argtypes = [
            ctypes.c_void_p,
            ctypes.c_int32,
            KCDensePolicyActionFeatures,
        ]
        self.lib.kc_engine_policy_action_dense_features.restype = ctypes.c_int32
        self.lib.kc_engine_state_features.argtypes = [
            ctypes.c_void_p,
            ctypes.c_int32,
            ctypes.POINTER(ctypes.c_float),
            ctypes.c_int32,
        ]
        self.lib.kc_engine_state_features.restype = ctypes.c_int32
        self.lib.kc_engine_object_tokens.argtypes = [
            ctypes.c_void_p,
            ctypes.c_int32,
            ctypes.POINTER(KCObjectToken),
            ctypes.c_int32,
        ]
        self.lib.kc_engine_object_tokens.restype = ctypes.c_int32
        self.lib.kc_engine_object_token_dense_features.argtypes = [
            ctypes.c_void_p,
            ctypes.c_int32,
            KCDenseObjectTokens,
        ]
        self.lib.kc_engine_object_token_dense_features.restype = ctypes.c_int32
        self.lib.kc_engine_heuristic_policy_action.argtypes = [ctypes.c_void_p, ctypes.POINTER(KCAction)]
        self.lib.kc_engine_heuristic_policy_action.restype = ctypes.c_bool
        self.lib.kc_engine_waiting_for_external_action.argtypes = [ctypes.c_void_p]
        self.lib.kc_engine_waiting_for_external_action.restype = ctypes.c_bool
        self.lib.kc_engine_waiting_player.argtypes = [ctypes.c_void_p]
        self.lib.kc_engine_waiting_player.restype = ctypes.c_int32
        self.lib.kc_engine_phase.argtypes = [ctypes.c_void_p]
        self.lib.kc_engine_phase.restype = ctypes.c_int32
        self.lib.kc_engine_year.argtypes = [ctypes.c_void_p]
        self.lib.kc_engine_year.restype = ctypes.c_int32
        self.lib.kc_engine_winner_id.argtypes = [ctypes.c_void_p]
        self.lib.kc_engine_winner_id.restype = ctypes.c_int32
        self.lib.kc_visible_score.argtypes = [ctypes.c_void_p, ctypes.c_int32]
        self.lib.kc_visible_score.restype = ctypes.c_int32
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

    def new_engine(
        self,
        seed: int,
        *,
        variants: KCVariants | None = None,
        controllers: KCControllers | None = None,
        round_curriculum: bool = False,
        round_plot_cards: int = 0,
        round_famine_rate: float = 0.0,
        curriculum_rounds: int = 2,
    ) -> ctypes.c_void_p:
        pointer = self.lib.kc_engine_alloc()
        if not pointer:
            raise MemoryError("kc_engine_alloc failed")
        if round_curriculum:
            self.lib.kc_engine_init_curriculum_rounds(
                pointer,
                ctypes.c_uint64(seed),
                self.kolkhoz_variants(),
                ctypes.c_int32(round_plot_cards),
                ctypes.c_double(round_famine_rate),
                ctypes.c_int32(curriculum_rounds),
            )
        elif controllers is not None:
            self.lib.kc_engine_init_with_controllers(
                pointer,
                ctypes.c_uint64(seed),
                variants or self.kolkhoz_variants(),
                controllers,
            )
        else:
            self.lib.kc_engine_init(
                pointer, ctypes.c_uint64(seed), variants or self.kolkhoz_variants()
            )
        return ctypes.c_void_p(pointer)

    def free_engine(self, pointer: ctypes.c_void_p) -> None:
        self.lib.kc_engine_free(pointer)

    def clone_engine(self, pointer: ctypes.c_void_p) -> ctypes.c_void_p:
        clone = self.lib.kc_engine_alloc()
        if not clone:
            raise MemoryError("kc_engine_alloc failed")
        self.lib.kc_engine_clone(pointer, clone)
        return ctypes.c_void_p(clone)

    def sample_determinization(
        self,
        pointer: ctypes.c_void_p,
        *,
        perspective_player: int,
        sample_seed: int,
    ) -> ctypes.c_void_p:
        sampled = self.lib.kc_engine_alloc()
        if not sampled:
            raise MemoryError("kc_engine_alloc failed")
        ok = self.lib.kc_engine_sample_determinization(
            pointer,
            ctypes.c_int32(perspective_player),
            ctypes.c_uint64(sample_seed),
            sampled,
        )
        if not ok:
            self.lib.kc_engine_free(sampled)
            raise RuntimeError("C engine could not sample hidden-state determinization")
        return ctypes.c_void_p(sampled)

    def waiting_player(self, pointer: ctypes.c_void_p) -> int:
        return int(self.lib.kc_engine_waiting_player(pointer))

    def waiting_for_external_action(self, pointer: ctypes.c_void_p) -> bool:
        return bool(self.lib.kc_engine_waiting_for_external_action(pointer))

    def phase(self, pointer: ctypes.c_void_p) -> int:
        return int(self.lib.kc_engine_phase(pointer))

    def year(self, pointer: ctypes.c_void_p) -> int:
        return int(self.lib.kc_engine_year(pointer))

    def winner_id(self, pointer: ctypes.c_void_p) -> int:
        return int(self.lib.kc_engine_winner_id(pointer))

    def legal_actions(self, pointer: ctypes.c_void_p, max_actions: int = 256) -> list[KCAction]:
        actions = (KCAction * max_actions)()
        count = self.lib.kc_engine_legal_actions(pointer, actions, ctypes.c_int32(max_actions))
        return [actions[index] for index in range(int(count))]

    def apply_action(self, pointer: ctypes.c_void_p, action: KCAction) -> None:
        status = int(self.lib.kc_engine_apply(pointer, action))
        if status != 0:
            raise RuntimeError(f"kc_engine_apply failed with status {status}")

    def step_automatic(self, pointer: ctypes.c_void_p) -> int:
        return int(self.lib.kc_engine_step_automatic(pointer))

    def step_policy_automatic(
        self,
        pointer: ctypes.c_void_p,
        model: KCPolicyModelBuffer,
    ) -> int:
        return int(self.lib.kc_engine_step_policy_automatic(pointer, model))

    def policy_action(
        self,
        pointer: ctypes.c_void_p,
        model: KCPolicyModelBuffer,
    ) -> KCAction | None:
        action = KCAction()
        ok = self.lib.kc_engine_policy_action(pointer, model, ctypes.byref(action))
        return action if ok else None

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

    def dense_policy_action_features(
        self,
        pointer: ctypes.c_void_p,
        *,
        player_id: int,
        input_size: int,
        max_features: int = 256,
    ) -> DensePolicyActionFeatures:
        actions = (KCAction * max_features)()
        action_heads = (ctypes.c_int32 * max_features)()
        kind_ids = (ctypes.c_int32 * max_features)()
        player_ids = (ctypes.c_int32 * max_features)()
        suit_ids = (ctypes.c_int32 * max_features)()
        target_suit_ids = (ctypes.c_int32 * max_features)()
        card_suit_ids = (ctypes.c_int32 * max_features)()
        card_value_ids = (ctypes.c_int32 * max_features)()
        hand_suit_ids = (ctypes.c_int32 * max_features)()
        hand_value_ids = (ctypes.c_int32 * max_features)()
        plot_suit_ids = (ctypes.c_int32 * max_features)()
        plot_value_ids = (ctypes.c_int32 * max_features)()
        plot_zone_ids = (ctypes.c_int32 * max_features)()
        action_scalars = (ctypes.c_float * (max_features * ACTION_SCALAR_COUNT))()
        features = (ctypes.c_float * (max_features * input_size))()
        output = KCDensePolicyActionFeatures(
            actions,
            action_heads,
            kind_ids,
            player_ids,
            suit_ids,
            target_suit_ids,
            card_suit_ids,
            card_value_ids,
            hand_suit_ids,
            hand_value_ids,
            plot_suit_ids,
            plot_value_ids,
            plot_zone_ids,
            action_scalars,
            ACTION_SCALAR_COUNT,
            features,
            max_features,
            input_size,
        )
        count = self.lib.kc_engine_policy_action_dense_features(
            pointer,
            ctypes.c_int32(player_id),
            output,
        )
        return DensePolicyActionFeatures(
            count=int(count),
            input_size=input_size,
            actions=actions,
            action_heads=action_heads,
            kind_ids=kind_ids,
            player_ids=player_ids,
            suit_ids=suit_ids,
            target_suit_ids=target_suit_ids,
            card_suit_ids=card_suit_ids,
            card_value_ids=card_value_ids,
            hand_suit_ids=hand_suit_ids,
            hand_value_ids=hand_value_ids,
            plot_suit_ids=plot_suit_ids,
            plot_value_ids=plot_value_ids,
            plot_zone_ids=plot_zone_ids,
            action_scalars=action_scalars,
            action_scalar_count=ACTION_SCALAR_COUNT,
            features=features,
        )

    def state_features(
        self,
        pointer: ctypes.c_void_p,
        *,
        perspective_player: int,
        input_size: int = STATE_INPUT_SIZE,
    ) -> list[float]:
        features = (ctypes.c_float * input_size)()
        count = self.lib.kc_engine_state_features(
            pointer,
            ctypes.c_int32(perspective_player),
            features,
            ctypes.c_int32(input_size),
        )
        if int(count) <= 0:
            return []
        return [float(features[index]) for index in range(input_size)]

    def object_tokens(
        self,
        pointer: ctypes.c_void_p,
        *,
        perspective_player: int,
        max_tokens: int = MAX_OBJECT_TOKENS,
    ) -> list[KCObjectToken]:
        items = (KCObjectToken * max_tokens)()
        count = self.lib.kc_engine_object_tokens(
            pointer,
            ctypes.c_int32(perspective_player),
            items,
            ctypes.c_int32(max_tokens),
        )
        return [items[index] for index in range(int(count))]

    def dense_object_tokens(
        self,
        pointer: ctypes.c_void_p,
        *,
        perspective_player: int,
        max_tokens: int = MAX_OBJECT_TOKENS,
    ) -> DenseObjectTokens:
        type_ids = (ctypes.c_int32 * max_tokens)()
        owner_ids = (ctypes.c_int32 * max_tokens)()
        zone_ids = (ctypes.c_int32 * max_tokens)()
        suit_ids = (ctypes.c_int32 * max_tokens)()
        value_ids = (ctypes.c_int32 * max_tokens)()
        index_ids = (ctypes.c_int32 * max_tokens)()
        scalars = (ctypes.c_float * (max_tokens * OBJECT_SCALAR_COUNT))()
        output = KCDenseObjectTokens(
            type_ids,
            owner_ids,
            zone_ids,
            suit_ids,
            value_ids,
            index_ids,
            scalars,
            max_tokens,
        )
        count = self.lib.kc_engine_object_token_dense_features(
            pointer,
            ctypes.c_int32(perspective_player),
            output,
        )
        return DenseObjectTokens(
            count=int(count),
            type_ids=type_ids,
            owner_ids=owner_ids,
            zone_ids=zone_ids,
            suit_ids=suit_ids,
            value_ids=value_ids,
            index_ids=index_ids,
            scalars=scalars,
        )

    def heuristic_action(self, pointer: ctypes.c_void_p) -> KCAction:
        action = KCAction()
        ok = self.lib.kc_engine_heuristic_policy_action(pointer, ctypes.byref(action))
        if not ok:
            raise RuntimeError(
                "C heuristic could not choose an action "
                f"(phase={self.phase(pointer)}, year={self.year(pointer)}, waiting_player={self.waiting_player(pointer)})"
            )
        return action

    def apply_ai_action(self, pointer: ctypes.c_void_p, action: KCAction) -> None:
        status = int(self.lib.kc_engine_apply_ai_action(pointer, action))
        if status != 0:
            raise RuntimeError(f"C engine rejected AI action with status {status}")

    def apply_policy_action(self, pointer: ctypes.c_void_p, action: KCAction) -> None:
        self.apply_ai_action(pointer, action)

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
        sources = _engine_sources()
        return EngineProvenance(
            git_sha=_git_sha(),
            c_sha256=_sha256_sources(sources),
            header_sha256=_sha256(ENGINE_H),
            library_path=os.fspath(self.library_path),
        )
