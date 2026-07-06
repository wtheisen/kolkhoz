# Kolkhoz Legacy Model Store

The Swift RL trainer is retired. Current training and benchmarking live under
`research/` and use the C engine through the Python/Torch harness.

This directory is kept only for historical C-compatible JSON model artifacts that are
still useful as baselines or opponents. Final `candidate.json` and `candidate_best.json`
files are models; old `candidate_e*.json` epoch snapshots are disposable.

Do not add new training code, scripts, dashboards, or experiment records here. Current
AI work belongs in `research/`; this directory is a legacy model input store for the
research harness.

Use the current CLI for new work:

```bash
python3 -m research.kolkhoz_research.cli engine-smoke --games 8
python3 -m research.kolkhoz_research.cli torch-train --help
python3 -m research.kolkhoz_research.cli torch-benchmark --help
```

Use the research cleanup command before deleting model artifacts:

```bash
python3 -m research.kolkhoz_research.cli cleanup-artifacts --include-files
```
