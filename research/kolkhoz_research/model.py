from __future__ import annotations

import ctypes
import json
import random
from dataclasses import dataclass
from pathlib import Path
from typing import Any

from .c_engine import KCPolicyModelBuffer


FEATURE_VERSION = 7
INPUT_SIZE = 200
STATE_INPUT_SIZE = 200
VALUE_INPUT_SIZE = 64
HEAD_COUNT = 16
MAX_HIDDEN_LAYERS = 4


def _flat(values: Any) -> list[float]:
    if values is None:
        return []
    if isinstance(values, list) and values and isinstance(values[0], list):
        return [float(item) for row in values for item in row]
    if isinstance(values, list):
        return [float(item) for item in values]
    return []


def _double_array(values: list[float]) -> ctypes.Array[ctypes.c_double]:
    return (ctypes.c_double * len(values))(*values)


@dataclass
class PolicyArtifact:
    data: dict[str, Any]
    path: Path | None = None

    def __post_init__(self) -> None:
        self._arrays: list[Any] = []
        self._hidden_weight_arrays: list[Any] = []
        self._hidden_bias_arrays: list[Any] = []
        self._output_array: Any | None = None
        self._simple_arrays: tuple[Any, Any, Any] | None = None
        self._b2_value: Any | None = None
        self._b2s_array: Any | None = None
        self._layer_weight_ptrs = (ctypes.POINTER(ctypes.c_double) * MAX_HIDDEN_LAYERS)()
        self._layer_bias_ptrs = (ctypes.POINTER(ctypes.c_double) * MAX_HIDDEN_LAYERS)()

    @property
    def backend(self) -> str:
        return str(self.data.get("backend", "c-mlp"))

    @property
    def input_size(self) -> int:
        return int(self.data.get("input_size", self.data.get("inputSize", INPUT_SIZE)))

    @property
    def hidden_size(self) -> int:
        return int(self.data.get("hidden_size", self.data.get("hiddenSize", 0)))

    @property
    def layer_sizes(self) -> list[int]:
        raw = self.data.get("hidden_layers", self.data.get("layerSizes", []))
        if not raw:
            return []
        return [int(item) for item in raw]

    @property
    def head_count(self) -> int:
        return int(self.data.get("head_count", self.data.get("headCount", len(self.data.get("b2s", [])) or 1)))

    @classmethod
    def load(cls, path: Path) -> "PolicyArtifact":
        with path.open("r", encoding="utf-8") as handle:
            data = json.load(handle)
        if not isinstance(data, dict):
            raise ValueError(f"{path} must contain a JSON object")
        return cls(data=data, path=path)

    @classmethod
    def scratch(
        cls,
        *,
        hidden_layers: list[int],
        seed: int,
        scale: float,
        input_size: int = INPUT_SIZE,
        head_count: int = HEAD_COUNT,
    ) -> "PolicyArtifact":
        if not hidden_layers:
            raise ValueError("scratch model requires at least one hidden layer")
        if len(hidden_layers) > MAX_HIDDEN_LAYERS:
            raise ValueError(f"C policy backend supports at most {MAX_HIDDEN_LAYERS} hidden layers")
        rng = random.Random(seed)

        def weights(count: int) -> list[float]:
            return [rng.gauss(0.0, scale) for _ in range(count)]

        hidden_weights: list[list[float]] = []
        hidden_biases: list[list[float]] = []
        previous = input_size
        for size in hidden_layers:
            hidden_weights.append(weights(previous * size))
            hidden_biases.append(weights(size))
            previous = size

        return cls(
            data={
                "version": 5,
                "feature_version": FEATURE_VERSION,
                "backend": "c-mlp",
                "input_size": input_size,
                "hidden_size": hidden_layers[0],
                "hidden_layers": hidden_layers,
                "hidden_weights": hidden_weights,
                "hidden_biases": hidden_biases,
                "output_weights": weights(hidden_layers[-1] * head_count),
                "b2": 0.0,
                "b2s": [0.0] * head_count,
                "value_bias": 0.0,
                "value_weights": [0.0] * VALUE_INPUT_SIZE,
            }
        )

    def c_buffer(self) -> KCPolicyModelBuffer:
        if self.backend != "c-mlp":
            raise ValueError(f"policy backend {self.backend!r} cannot be loaded into the C MLP backend")
        self._arrays.clear()
        self._hidden_weight_arrays = []
        self._hidden_bias_arrays = []
        self._output_array = None
        self._simple_arrays = None
        self._b2_value = None
        self._b2s_array = None
        self._layer_weight_ptrs = (ctypes.POINTER(ctypes.c_double) * MAX_HIDDEN_LAYERS)()
        self._layer_bias_ptrs = (ctypes.POINTER(ctypes.c_double) * MAX_HIDDEN_LAYERS)()

        layer_sizes = self.layer_sizes
        layer_count = len(layer_sizes)
        if layer_count > MAX_HIDDEN_LAYERS:
            raise ValueError(f"C policy backend supports at most {MAX_HIDDEN_LAYERS} hidden layers")

        buffer = KCPolicyModelBuffer()
        buffer.input_size = self.input_size
        buffer.hidden_size = self.hidden_size or (layer_sizes[0] if layer_sizes else 0)
        buffer.layer_count = layer_count
        buffer.head_count = self.head_count
        for index, size in enumerate(layer_sizes):
            buffer.layer_sizes[index] = size

        hidden_weights = self.data.get("hidden_weights", self.data.get("layerWeights"))
        hidden_biases = self.data.get("hidden_biases", self.data.get("layerBiases"))
        if layer_count and hidden_weights and hidden_biases:
            for index in range(layer_count):
                weights = _double_array(_flat(hidden_weights[index]))
                biases = _double_array(_flat(hidden_biases[index]))
                self._arrays.extend([weights, biases])
                self._hidden_weight_arrays.append(weights)
                self._hidden_bias_arrays.append(biases)
                self._layer_weight_ptrs[index] = ctypes.cast(weights, ctypes.POINTER(ctypes.c_double))
                self._layer_bias_ptrs[index] = ctypes.cast(biases, ctypes.POINTER(ctypes.c_double))
            buffer.layer_weights = self._layer_weight_ptrs
            buffer.layer_biases = self._layer_bias_ptrs
            output = _double_array(_flat(self.data.get("output_weights", self.data.get("outputWeights"))))
            self._arrays.append(output)
            self._output_array = output
            buffer.output_weights = ctypes.cast(output, ctypes.POINTER(ctypes.c_double))
        else:
            w1 = _double_array(_flat(self.data.get("w1")))
            b1 = _double_array(_flat(self.data.get("b1")))
            w2 = _double_array(_flat(self.data.get("w2", self.data.get("output_weights", self.data.get("outputWeights")))))
            self._arrays.extend([w1, b1, w2])
            self._simple_arrays = (w1, b1, w2)
            buffer.layer_count = 0
            buffer.w1 = ctypes.cast(w1, ctypes.POINTER(ctypes.c_double))
            buffer.b1 = ctypes.cast(b1, ctypes.POINTER(ctypes.c_double))
            buffer.w2 = ctypes.cast(w2, ctypes.POINTER(ctypes.c_double))

        b2_value = ctypes.c_double(float(self.data.get("b2", 0.0)))
        self._arrays.append(b2_value)
        self._b2_value = b2_value
        buffer.b2 = ctypes.pointer(b2_value)
        b2s_raw = _flat(self.data.get("b2s"))
        if b2s_raw:
            b2s = _double_array(b2s_raw)
            self._arrays.append(b2s)
            self._b2s_array = b2s
            buffer.b2s = ctypes.cast(b2s, ctypes.POINTER(ctypes.c_double))
        return buffer

    def value_weights_pointer(self) -> ctypes.POINTER(ctypes.c_double):
        values = _flat(self.data.get("value_weights", self.data.get("valueWeights")))
        if not values:
            values = [0.0] * VALUE_INPUT_SIZE
        weights = _double_array(values)
        self._arrays.append(weights)
        return ctypes.cast(weights, ctypes.POINTER(ctypes.c_double))

    def sync_from_c(self) -> None:
        layer_sizes = self.layer_sizes
        head_count = self.head_count
        if layer_sizes:
            hidden_weights: list[list[float]] = []
            hidden_biases: list[list[float]] = []
            previous = self.input_size
            for index, size in enumerate(layer_sizes):
                weight_count = previous * size
                weights = self._hidden_weight_arrays[index]
                biases = self._hidden_bias_arrays[index]
                hidden_weights.append([float(weights[i]) for i in range(weight_count)])
                hidden_biases.append([float(biases[i]) for i in range(size)])
                previous = size
            if self._output_array is None:
                raise RuntimeError("policy output array is not loaded")
            self.data["hidden_weights"] = hidden_weights
            self.data["hidden_biases"] = hidden_biases
            self.data["output_weights"] = [float(self._output_array[i]) for i in range(layer_sizes[-1] * head_count)]
        else:
            hidden_size = self.hidden_size
            if self._simple_arrays is None:
                raise RuntimeError("simple policy arrays are not loaded")
            w1, b1, w2 = self._simple_arrays
            self.data["w1"] = [float(w1[i]) for i in range(self.input_size * hidden_size)]
            self.data["b1"] = [float(b1[i]) for i in range(hidden_size)]
            self.data["w2"] = [float(w2[i]) for i in range(hidden_size * head_count)]
        if self._b2_value is not None:
            self.data["b2"] = float(self._b2_value.value)
        if self._b2s_array is not None:
            self.data["b2s"] = [float(self._b2s_array[i]) for i in range(head_count)]

    def save(self, path: Path) -> None:
        path.parent.mkdir(parents=True, exist_ok=True)
        self.data.setdefault("version", 5)
        self.data.setdefault("feature_version", FEATURE_VERSION)
        self.data.setdefault("backend", "c-mlp")
        with path.open("w", encoding="utf-8") as handle:
            json.dump(self.data, handle, indent=2, sort_keys=True)
            handle.write("\n")
