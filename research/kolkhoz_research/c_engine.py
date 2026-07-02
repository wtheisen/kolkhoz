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


class KCGameRunResult(ctypes.Structure):
    _fields_ = [
        ("actions", ctypes.c_int32),
        ("checksum", ctypes.c_int32),
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
    if output.exists() and not force and output.stat().st_mtime >= ENGINE_C.stat().st_mtime:
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

    def kolkhoz_variants(self) -> KCVariants:
        variants = KCVariants()
        self.lib.kc_variants_kolkhoz(ctypes.byref(variants))
        return variants

    def run_smoke_game(self, seed: int) -> KCGameRunResult:
        return self.lib.kc_run_benchmark_game(ctypes.c_uint64(seed), self.kolkhoz_variants())

    def provenance(self) -> EngineProvenance:
        return EngineProvenance(
            git_sha=_git_sha(),
            c_sha256=_sha256(ENGINE_C),
            header_sha256=_sha256(ENGINE_H),
            library_path=os.fspath(self.library_path),
        )

