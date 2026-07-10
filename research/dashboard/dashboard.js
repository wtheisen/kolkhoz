const stateEl = document.getElementById("refreshState");
const updatedEl = document.getElementById("updatedAt");
const curveZoom = {
  distillLossCurve: 1,
  distillMatchCurve: 1,
  distillEntropyCurve: 1,
  distillCandidatesCurve: 1,
  rewardCurve: 1,
  winCurve: 1,
  rankCurve: 1,
  marginCurve: 1,
};
const curveZoomLabels = {
  distillLossCurve: "distillLossZoom",
  distillMatchCurve: "distillMatchZoom",
  distillEntropyCurve: "distillEntropyZoom",
  distillCandidatesCurve: "distillCandidatesZoom",
  rewardCurve: "rewardZoom",
  winCurve: "winZoom",
  rankCurve: "rankZoom",
  marginCurve: "marginZoom",
};
const minCurveZoom = 1;
const maxCurveZoom = 8;
const curveZoomStep = 1.5;
const curveFollowAnchor = 0.7;
const seedOverlayColors = ["#3f7a4b", "#a96f2d", "#7b4fb3", "#b9922f", "#a5483c", "#315f7d", "#5c7f42", "#8f5c38"];
let latestPayload = null;
let distillSeriesKey = null;
let distillPoints = [];
let trainingCurveSourceKey = null;
let liveSupervisedSeriesKey = null;
let liveSupervisedPoints = [];
let liveMaskedStateSeriesKey = null;
let liveMaskedStatePoints = [];

function text(id, value) {
  document.getElementById(id).textContent = value ?? "-";
}

function fmtNumber(value, digits = 3) {
  if (value === undefined || value === null || Number.isNaN(Number(value))) return "-";
  return Number(value).toFixed(digits);
}

function fmtPercent(value) {
  if (value === undefined || value === null || Number.isNaN(Number(value))) return "-";
  return `${Math.round(Number(value) * 100)}%`;
}

function fmtPercentPoint(value, digits = 1) {
  if (value === undefined || value === null || Number.isNaN(Number(value))) return "-";
  const points = Number(value) * 100;
  return `${points >= 0 ? "+" : ""}${points.toFixed(digits)}pp`;
}

function fmtStatus(value) {
  if (!value) return "-";
  return String(value).replaceAll("_", " ");
}

function fmtZoom(value) {
  return `${Number(value).toFixed(1).replace(/\.0$/, "")}x`;
}

function updateCurveZoomControls(svgId) {
  const zoom = curveZoom[svgId] || 1;
  const label = document.getElementById(curveZoomLabels[svgId]);
  if (label) label.textContent = fmtZoom(zoom);
  document.querySelectorAll(`[data-curve-target="${svgId}"]`).forEach((button) => {
    const action = button.dataset.curveZoom;
    button.disabled = (action === "out" && zoom <= minCurveZoom)
      || (action === "in" && zoom >= maxCurveZoom);
  });
}

function rerenderCurvesAfterZoom(svgId) {
  const scrollContainer = document.getElementById(svgId)?.closest(".curve-scroll");
  if (scrollContainer) scrollContainer.dataset.autoFollow = "true";
  if (latestPayload) renderCurves(latestPayload.current, latestPayload.trainings || []);
}

function setCurveZoom(svgId, action) {
  const current = curveZoom[svgId] || 1;
  let next = current;
  if (action === "in") next = Math.min(maxCurveZoom, current * curveZoomStep);
  if (action === "out") next = Math.max(minCurveZoom, current / curveZoomStep);
  if (action === "reset") next = minCurveZoom;
  next = Number(next.toFixed(3));
  if (next === current && action !== "reset") return;
  curveZoom[svgId] = next;
  updateCurveZoomControls(svgId);
  rerenderCurvesAfterZoom(svgId);
}

function attachCurveZoomControls() {
  document.querySelectorAll("[data-curve-zoom]").forEach((button) => {
    button.addEventListener("click", () => {
      setCurveZoom(button.dataset.curveTarget, button.dataset.curveZoom);
    });
  });
  Object.keys(curveZoom).forEach(updateCurveZoomControls);
}

function shortPath(value) {
  if (!value) return "-";
  const parts = String(value).split("/");
  if (parts.length <= 3) return String(value);
  return `${parts.slice(0, 2).join("/")}/.../${parts.slice(-2).join("/")}`;
}

function comparisonLabel(record) {
  if (!record) return "baseline";
  if (record.comparison_label) return String(record.comparison_label);
  if (record.comparison === "heuristic" || record.baseline_model === "heuristic") return "heuristic";
  return "current best";
}

function when(value) {
  if (!value) return "-";
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return value;
  return date.toLocaleString([], { hour: "2-digit", minute: "2-digit", second: "2-digit", month: "short", day: "numeric" });
}

function renderOnlineSmoke(smoke) {
  const button = document.getElementById("runOnlineSmoke");
  const summary = document.getElementById("onlineSmokeSummary");
  const runs = document.getElementById("onlineSmokeRuns");
  if (!button || !summary || !runs) return;
  button.disabled = Boolean(smoke?.running);
  button.textContent = smoke?.running ? "Game running…" : "Run test game";
  const latest = smoke?.latest;
  summary.textContent = smoke?.running
    ? "An authenticated production game is in progress."
    : latest
      ? `${latest.status === "passed" ? "Latest run passed" : "Latest run failed"} ${when(latest.finishedAt)} in ${fmtNumber(latest.durationSeconds, 1)}s.`
      : "No production smoke runs recorded.";
  runs.innerHTML = (smoke?.runs || []).slice(0, 8).map((run) => `
    <div class="smoke-run ${run.status || "unknown"}">
      <strong>${run.status || "unknown"}</strong>
      <span>${when(run.finishedAt)}</span>
      <span>${run.actionsSubmitted ?? "-"} actions</span>
      <span>${run.sessionID ? String(run.sessionID).slice(0, 8) : run.error || "-"}</span>
    </div>
  `).join("");
}

async function runOnlineSmoke() {
  const button = document.getElementById("runOnlineSmoke");
  if (button) button.disabled = true;
  try {
    await fetch("/api/online-smoke/run", { method: "POST" });
  } finally {
    refresh();
  }
}

function architectureLabel(model) {
  if (!model) return "unknown";
  const layers = Array.isArray(model.layers) && model.layers.length ? ` ${model.layers.join("x")}` : "";
  return `${model.architecture || "unknown"}${layers}`;
}

function metricSource(record) {
  if (!record) return {};
  return record.summary
    || record.latest_generation_benchmark?.summary
    || record.latest_generation?.summary
    || record.result
    || {};
}

function latestBenchmarkLike(record) {
  if (!record) return null;
  if (record.latest_generation_benchmark?.intervals) {
    const latest = record.latest_generation || {};
    return {
      ...record.latest_generation_benchmark,
      generation: latest.generation,
      promoted: latest.promoted,
      benchmark_status: latest.benchmark_status || record.latest_generation_benchmark.status,
    };
  }
  if (record.intervals) return record;
  const latest = record.latest_generation;
  if (latest?.intervals) {
    return {
      ...latest,
      status: latest.benchmark_status || (latest.promoted ? "promoted" : "rejected"),
      evidence: latest.evidence,
      summary: latest.summary,
    };
  }
  return null;
}

function latestMarginShapeRecord(current, benchmarks = []) {
  const source = trainingDisplaySource(current);
  const evals = (source?.evaluations || []).filter((item) => item?.distribution);
  if (evals.length) {
    const latestEpisode = Math.max(...evals.map((item) => Number(item.completed_episodes || 0)));
    const latest = evals
      .filter((item) => Number(item.completed_episodes || 0) === latestEpisode)
      .sort((left, right) => {
        const leftCurrent = comparisonLabel(left) === "current best" ? 0 : 1;
        const rightCurrent = comparisonLabel(right) === "current best" ? 0 : 1;
        return leftCurrent - rightCurrent;
      })[0];
    if (latest) return latest;
  }
  const benchmark = latestBenchmarkLike(current);
  if (benchmark?.distribution) return benchmark;
  return (benchmarks || []).find((record) => record?.distribution) || null;
}

function isSelfPlayLoop(record) {
  return record?.kind === "self_play_improvement_loop" || record?.kind === "self_play_seed_pool";
}

function trainingDisplaySource(record) {
  if (isSelfPlayLoop(record) && record.latest_generation_training) {
    return record.latest_generation_training;
  }
  return record;
}

function generationProgress(record) {
  const progress = record?.progress || {};
  const latest = record?.latest_generation || {};
  const generations = Array.isArray(record?.generations) ? record.generations : [];
  const promoted = record?.promoted_count ?? generations.filter((item) => item?.promoted).length;
  return {
    current: Number(latest.generation || record?.completed_generations || progress.completed_generations || generations.length || 0),
    completed: Number(record?.completed_generations || progress.completed_generations || generations.length || 0),
    total: Number(record?.requested_generations || progress.total_generations || 0),
    promoted: Number(promoted || 0),
  };
}

function curriculumLabel(rounds) {
  const value = Number(rounds);
  if (!Number.isFinite(value)) return "Curriculum";
  if (value >= 5) return "Full game";
  return `${value} ${value === 1 ? "year" : "years"}`;
}

function totalEpisodes(record) {
  const progress = record?.progress || {};
  const training = record?.training || {};
  const curve = record?.curve || {};
  const points = curve.points || [];
  const supervisedPoints = supervisedCurvePoints(record);
  const maskedPoints = maskedStateCurvePoints(record);
  const lastCurvePoint = points.length ? Number(points[points.length - 1].episode) : 0;
  const lastSupervisedPoint = supervisedPoints.length ? Number(supervisedPoints[supervisedPoints.length - 1].episode) : 0;
  const lastMaskedPoint = maskedPoints.length ? Number(maskedPoints[maskedPoints.length - 1].episode) : 0;
  return Number(
    progress.total_episodes
    || progress.total_epochs
    || training.episodes
    || training.epochs
    || curve.source_episodes
    || lastCurvePoint
    || lastSupervisedPoint
    || lastMaskedPoint
    || 0
  );
}

function trainingCurveKey(record) {
  if (!record) return null;
  return [
    record.model?.output_model || record.output_model || "unknown-output",
    record.model?.start_model || record.start_model || "unknown-start",
    record.training?.seed || record.seed || "unknown-seed",
    totalEpisodes(record) || "unknown-total",
  ].join("|");
}

function comparableCurveKey(record, mode) {
  if (!record) return null;
  const model = record.model || {};
  return [
    mode,
    record.kind || "unknown-kind",
    model.architecture || "unknown-architecture",
    Array.isArray(model.layers) ? model.layers.join("x") : "",
    totalEpisodes(record) || "unknown-total",
  ].join("|");
}

function seedLabel(record) {
  const seed = record?.seed ?? record?.training?.seed;
  if (seed !== undefined && seed !== null) return `seed ${seed}`;
  const output = record?.model?.output_model || record?.output_model || "";
  const match = String(output).match(/(\d{8}T\d{6}Z|generation_\d+|seed_\d+)/);
  return match ? match[1].replaceAll("_", " ") : shortPath(output);
}

function seedOverlaySeries(source, trainings, mode) {
  if (!source || mode !== "rl") return [];
  const sourceKey = comparableCurveKey(source, mode);
  const sourceCurveKey = trainingCurveKey(source);
  const seenSeeds = new Set();
  const records = [source, ...(trainings || []).map(trainingDisplaySource)]
    .filter((record) => record && comparableCurveKey(record, mode) === sourceKey)
    .filter((record) => {
      const curve = trainingCurvePoints(record);
      if (curve.mode !== mode || curve.points.length < 2) return false;
      const seed = record.seed ?? record.training?.seed ?? trainingCurveKey(record);
      if (seenSeeds.has(seed)) return false;
      seenSeeds.add(seed);
      return true;
    })
    .sort((left, right) => String(seedLabel(left)).localeCompare(String(seedLabel(right))));
  return records.slice(0, 8).map((record, index) => ({
    label: seedLabel(record),
    points: trainingCurvePoints(record).points,
    color: seedOverlayColors[index % seedOverlayColors.length],
    primary: trainingCurveKey(record) === sourceCurveKey,
  }));
}

function renderSeedOverlayLegend(series) {
  const target = document.getElementById("seedOverlayLegend");
  if (!target) return;
  if (!series || series.length <= 1) {
    target.innerHTML = "";
    target.style.display = "none";
    return;
  }
  target.style.display = "flex";
  target.innerHTML = series.map((item) => `
    <span class="${item.primary ? "primary" : ""}">
      <i style="background:${item.color}"></i>
      ${item.label}
    </span>
  `).join("");
}

function curriculumStages(record) {
  const training = record?.training || {};
  const total = totalEpisodes(record);
  if (!total || !Number.isFinite(total)) return [];
  const schedule = training.curriculum_schedule || "constant";
  const roundCurriculum = Boolean(training.round_curriculum || schedule === "scaled" || schedule === "mixed");
  if (!roundCurriculum) {
    return [{ label: "Full game", rounds: 5, startEpisode: 1, endEpisode: total }];
  }
  if (schedule === "mixed" && Array.isArray(training.curriculum_mixture)) {
    return training.curriculum_mixture.map((phase) => ({
      label: phase.name || "mixed",
      rounds: null,
      startEpisode: Number(phase.start_episode || 1),
      endEpisode: Number(phase.end_episode || total),
    })).filter((phase) => phase.startEpisode <= phase.endEpisode);
  }
  const scaled = Array.isArray(training.scaled_curriculum_rounds)
    ? training.scaled_curriculum_rounds.map(Number).filter(Number.isFinite)
    : [];
  const rounds = schedule === "scaled" && scaled.length
    ? scaled
    : [Number(training.curriculum_rounds || training.default_curriculum_rounds || 2)];
  return rounds.map((roundCount, index) => {
    const startEpisode = index === 0 ? 1 : Math.ceil((index * (total - 1)) / rounds.length + 1);
    const nextStart = index === rounds.length - 1
      ? total + 1
      : Math.ceil(((index + 1) * (total - 1)) / rounds.length + 1);
    return {
      label: curriculumLabel(roundCount),
      rounds: roundCount,
      startEpisode,
      endEpisode: Math.max(startEpisode, nextStart - 1),
    };
  });
}

function currentCurriculumStage(record) {
  const completed = Number(record?.progress?.completed_episodes || 0);
  const stages = curriculumStages(record);
  return stages.find((stage) => completed >= stage.startEpisode && completed <= stage.endEpisode)
    || stages.find((stage) => completed < stage.startEpisode)
    || stages[stages.length - 1]
    || null;
}

function nextEvalMarker(record) {
  const training = record?.training || {};
  const progress = record?.progress || {};
  const completedEvalEpisodes = [...new Set((record?.evaluations || [])
    .map((evaluation) => Number(evaluation?.completed_episodes))
    .filter((episode) => Number.isFinite(episode) && episode > 0))]
    .sort((left, right) => left - right);
  const inferredInterval = completedEvalEpisodes.length > 1
    ? Math.min(...completedEvalEpisodes.slice(1).map((episode, index) => episode - completedEvalEpisodes[index]).filter((delta) => delta > 0))
    : completedEvalEpisodes[0] || 0;
  const interval = Number(training.eval_interval || inferredInterval || 0);
  const total = totalEpisodes(record);
  const completed = Number(progress.completed_episodes || 0);
  if (!record || record.status !== "running" || !interval || !total || !Number.isFinite(interval)) return null;
  if (record.phase === "evaluation" || record.phase === "eval") {
    const episode = Math.max(1, Math.min(total, completed));
    return { episode, label: "eval now", active: true };
  }
  const episode = Math.ceil((completed + 1) / interval) * interval;
  if (!Number.isFinite(episode) || episode <= 0 || episode > total) return null;
  return { episode, label: `next eval ${episode}`, active: false };
}

function renderCurriculumProgress(record) {
  const stageLayer = document.getElementById("progressStages");
  const evalLayer = document.getElementById("progressEvals");
  const legend = document.getElementById("curriculumLegend");
  const stages = curriculumStages(record);
  const total = totalEpisodes(record);
  if (!stages.length || !total) {
    stageLayer.innerHTML = "";
    if (evalLayer) evalLayer.innerHTML = "";
    legend.innerHTML = "";
    return;
  }
  const completed = Number(record?.progress?.completed_episodes || 0);
  const stageMarkup = stages.map((stage, index) => {
    const left = Math.max(0, ((stage.startEpisode - 1) / total) * 100);
    const width = Math.max(0.4, ((stage.endEpisode - stage.startEpisode + 1) / total) * 100);
    const state = completed > stage.endEpisode ? "past" : completed >= stage.startEpisode ? "active" : "future";
    const marker = index === 0 ? "" : `<span class="progress-stage-marker" style="left:${left}%"></span>`;
    return `${marker}<span class="progress-stage-band ${state}" style="left:${left}%;width:${width}%"></span>`;
  }).join("");
  const evalMarker = nextEvalMarker(record);
  let evalMarkup = "";
  if (evalMarker) {
    const left = Math.max(0, Math.min(100, (evalMarker.episode / total) * 100));
    const edge = left > 78 ? "edge" : "";
    evalMarkup = `<span class="progress-eval-marker ${evalMarker.active ? "active" : ""} ${edge}" style="left:${left}%"><small>${evalMarker.label}</small></span>`;
  }
  stageLayer.innerHTML = stageMarkup;
  if (evalLayer) evalLayer.innerHTML = evalMarkup;
  legend.innerHTML = stages.map((stage) => {
    const state = completed > stage.endEpisode ? "past" : completed >= stage.startEpisode ? "active" : "future";
    return `<span class="curriculum-chip ${state}"><strong>${stage.label}</strong><small>${stage.startEpisode}-${stage.endEpisode}</small></span>`;
  }).join("") + (evalMarker ? `<span class="curriculum-chip eval ${evalMarker.active ? "active" : ""}"><strong>${evalMarker.active ? "Eval now" : "Next eval"}</strong><small>${evalMarker.episode}</small></span>` : "");
}

function renderCurrent(record) {
  const model = record?.model || {};
  const progress = record?.progress || {};
  const summary = metricSource(record);
  const fallbackPercent = record && record.status !== "running" ? 1 : 0;
  const rawPercent = Math.max(0, Math.min(1, Number(progress.percent ?? fallbackPercent)));
  const percent = isSelfPlayLoop(record) && record?.status !== "running" ? 1 : rawPercent;
  text("currentTitle", record ? record.kind.replaceAll("_", " ") : "No experiment");
  text("architecture", architectureLabel(model));
  text("backend", model.backend || record?.backend || "backend unknown");
  text("device", model.device || record?.device || "device unknown");
  text("outputModel", shortPath(model.output_model || record?.output_model));
  text("baselineModel", shortPath(model.baseline_model || record?.baseline_model || record?.teacher_model));
  text("seedValue", record?.seed ?? record?.training?.seed ?? "-");
  text("progressValue", isSelfPlayLoop(record) && record?.status !== "running" ? fmtStatus(record?.status) : fmtPercent(percent));
  const defaultProgressLabel = progress.total_episodes
    ? `${progress.completed_episodes || 0} / ${progress.total_episodes} episodes`
    : progress.total_epochs
      ? `${progress.completed_epochs || 0} / ${progress.total_epochs} epochs`
    : progress.total_games
      ? `${progress.completed_games || 0} / ${progress.total_games} games`
    : progress.total_generations
      ? `${progress.completed_generations || 0} / ${progress.total_generations} generations`
      : "Completed record";
  const generation = generationProgress(record);
  const progressLabel = isSelfPlayLoop(record)
    ? record?.status === "running"
      ? `Generation ${generation.current || 1}${generation.total ? ` / ${generation.total}` : ""} / promoted ${generation.promoted}`
      : `Stopped after ${generation.completed || generation.current || 0}${generation.total ? ` / ${generation.total}` : ""} generations${record?.stopped_reason ? ` / ${fmtStatus(record.stopped_reason)}` : ""} / promoted ${generation.promoted}`
    : defaultProgressLabel;
  const stage = currentCurriculumStage(record);
  text("progressLabel", !isSelfPlayLoop(record) && stage && progress.total_episodes ? `${progressLabel} / ${stage.label}` : progressLabel);
  document.getElementById("progressBar").style.width = `${Math.round(percent * 100)}%`;
  renderCurriculumProgress(record);
  const status = document.getElementById("currentStatus");
  const displayStatus = record?.status === "running" && (record?.phase === "evaluation" || record?.phase === "eval")
    ? "eval"
    : record?.status || "unknown";
  status.textContent = displayStatus;
  status.className = `status-pill ${displayStatus}`;
  text("metricWin", fmtPercent(summary.top_rate ?? summary.candidate_win_rate));
  text("metricRank", fmtNumber(summary.average_rank ?? summary.candidate_average_rank));
  text("metricMargin", fmtNumber(summary.average_margin ?? summary.candidate_average_margin));
  text("metricReward", fmtNumber(summary.average_reward));
  const components = [
    fmtNumber(summary.average_win_component, 2),
    fmtNumber(summary.average_rank_component, 2),
    fmtNumber(summary.average_margin_component, 2),
  ];
  text("metricComponents", components.every((item) => item === "-") ? "-" : components.join(" / "));
  text("metricPolicyLoss", fmtNumber(summary.policy_loss));
  text("metricValueLoss", fmtNumber(summary.value_loss));
  text("metricEntropy", fmtNumber(summary.entropy));
  text("metricActions", fmtNumber(summary.average_action_count, 1));
}

function renderCounts(counts) {
  const target = document.getElementById("counts");
  const items = [
    ["Records", counts.history],
    ["Trainings", counts.trainings],
    ["Benchmarks", counts.benchmarks],
    ["Evaluations", counts.evaluations],
  ];
  target.innerHTML = items.map(([label, value]) => `<div class="count"><span>${label}</span><strong>${value || 0}</strong></div>`).join("");
}

function deltaRow(label, interval) {
  if (!interval) return "";
  const mean = Number(interval.mean || 0);
  const width = Math.min(50, Math.abs(mean) * 100);
  const cls = mean < 0 ? "delta-fill negative" : "delta-fill";
  return `<div>
    <div class="delta-row"><span>${label}</span><strong>${fmtNumber(mean)}</strong></div>
    <div class="delta-track"><div class="${cls}" style="width:${width}%"></div></div>
    <p class="mini">CI ${fmtNumber(interval.low)} to ${fmtNumber(interval.high)}</p>
  </div>`;
}

function renderLatestBenchmark(benchmarks, current) {
  const latest = latestBenchmarkLike(current) || benchmarks?.[0];
  const target = document.getElementById("benchmarkDeltas");
  if (!latest?.intervals) {
    target.innerHTML = `<p class="mini">No benchmark records yet.</p>`;
    return;
  }
  const evidence = latest.evidence;
  const evidenceLine = evidence
    ? `<p class="mini">Evidence ${evidence.grade || "unknown"} / promotion ${evidence.promotion_eligible ? "eligible" : "not eligible"} / ${latest.total_games || 0} paired games</p>`
    : "";
  target.innerHTML = [
    evidenceLine,
    latest.promoted !== undefined ? `<p class="mini">Generation ${latest.generation || "-"} / ${fmtStatus(latest.benchmark_status || latest.status)} / ${latest.promoted ? "promoted" : "not promoted"}</p>` : "",
    deltaRow("Win delta", latest.intervals.win_delta),
    deltaRow("Rank delta", latest.intervals.rank_delta),
    deltaRow("Margin delta", latest.intervals.margin_delta),
  ].join("");
}

function evalSummaryRow(label, evaluation, options = {}) {
  if (!evaluation?.summary && !evaluation?.intervals) return "";
  const summary = evaluation.summary || {};
  const comparison = options.comparison || comparisonLabel(evaluation);
  const win = evaluation.intervals?.win_delta;
  const rank = evaluation.intervals?.rank_delta;
  const margin = evaluation.intervals?.margin_delta;
  const episode = evaluation.completed_episodes ? `${evaluation.completed_episodes} ep` : options.episode || "-";
  const status = options.status || evaluation.status;
  return `
    <div class="self-play-row">
      <div>
        <strong>${label}</strong>
        <span>${episode}${status ? ` / ${fmtStatus(status)}` : ""}</span>
      </div>
      <div>
        <strong>${fmtPercent(summary.candidate_win_rate)} vs ${fmtPercent(summary.baseline_win_rate)}</strong>
        <span>candidate / ${comparison} win</span>
      </div>
      <div>
        <strong class="${Number(win?.mean) < 0 ? "negative" : "positive"}">${fmtPercentPoint(win?.mean)}</strong>
        <span>CI ${fmtPercentPoint(win?.low)} to ${fmtPercentPoint(win?.high)}</span>
      </div>
      <div>
        <strong>${fmtNumber(rank?.mean, 2)}</strong>
        <span>rank delta</span>
      </div>
      <div>
        <strong>${fmtNumber(margin?.mean, 1)}</strong>
        <span>margin delta</span>
      </div>
    </div>
  `;
}

function renderSelfPlayDetails(record) {
  if (!isSelfPlayLoop(record)) return "";
  const generation = generationProgress(record);
  const latest = record.latest_generation || {};
  const training = record.latest_generation_training || {};
  const selected = record.selected_evaluation || training.selected_evaluation;
  const latestEval = record.generation_latest_evaluation || training.latest_evaluation;
  const benchmark = latestBenchmarkLike(record);
  const gateRecord = benchmark
    ? {
      ...benchmark,
      completed_episodes: null,
      status: benchmark.benchmark_status || benchmark.status,
    }
    : null;
  const status = latest.benchmark_status || record.stopped_reason || record.status;
  return `
    <div class="self-play-box">
      <div class="eval-history-head">
        <span>Self-play loop</span>
        <small>${generation.promoted} promoted</small>
      </div>
      <div class="self-play-summary">
        <div>
          <strong>Generation ${generation.current || latest.generation || "-"}</strong>
          <span>${generation.completed || 0}${generation.total ? ` / ${generation.total}` : ""} complete</span>
        </div>
        <div>
          <strong>${fmtStatus(status)}</strong>
          <span>${record.stopped_reason ? "stop reason" : "gate status"}</span>
        </div>
        <div>
          <strong>${shortPath(record.best_model || record.current_best_model || record.model?.output_model)}</strong>
          <span>current best</span>
        </div>
      </div>
      <div class="self-play-evals">
        ${evalSummaryRow("Selected checkpoint eval", selected)}
        ${latestEval && latestEval !== selected ? evalSummaryRow("Final training eval", latestEval) : ""}
        ${evalSummaryRow("Promotion gate", gateRecord, { comparison: "current best", status: gateRecord?.status })}
      </div>
    </div>
  `;
}

function renderTrainingEval(record) {
  const target = document.getElementById("trainingEval");
  const source = trainingDisplaySource(record);
  const evaluations = (source?.evaluations || []).filter((item) => item?.intervals);
  const latestEpisode = evaluations.length
    ? Math.max(...evaluations.map((item) => Number(item.completed_episodes || 0)))
    : 0;
  const latestRecords = evaluations
    .filter((item) => Number(item.completed_episodes || 0) === latestEpisode)
    .sort((left, right) => comparisonLabel(left).localeCompare(comparisonLabel(right)));
  const selfPlayMarkup = renderSelfPlayDetails(record);
  if (!latestRecords.length && !selfPlayMarkup) {
    target.innerHTML = "";
    return;
  }
  target.innerHTML = `
    ${selfPlayMarkup}
    <div class="eval-box">
      <p class="label">Latest training eval</p>
      ${latestRecords.map((latest) => {
        const summary = latest.summary || {};
        return `
          <div class="eval-box-row">
            <p><strong>${latest.completed_episodes || "-"} episodes</strong> vs ${comparisonLabel(latest)} / ${latest.total_games || 0} full games</p>
            <p>win delta ${fmtNumber(latest.intervals.win_delta?.mean)} / CI ${fmtNumber(latest.intervals.win_delta?.low)} to ${fmtNumber(latest.intervals.win_delta?.high)}</p>
            <p>candidate win ${fmtPercent(summary.candidate_win_rate)} / ${comparisonLabel(latest)} ${fmtPercent(summary.baseline_win_rate)}</p>
          </div>
        `;
      }).join("") || `<p class="mini">No live training eval in this record.</p>`}
    </div>
  `;
}

function renderTrainingEvalList(record) {
  const target = document.getElementById("trainingEvalList");
  const source = trainingDisplaySource(record);
  const evaluations = [...(source?.evaluations || [])]
    .filter((item) => item?.intervals || item?.summary)
    .sort((left, right) => Number(right.completed_episodes || 0) - Number(left.completed_episodes || 0))
    .slice(0, 8);
  if (!evaluations.length) {
    target.innerHTML = "";
    return;
  }
  target.innerHTML = `
    <div class="eval-history-head">
      <span>Eval history</span>
      <small>${evaluations.length} shown</small>
    </div>
    <div class="eval-history">
      ${evaluations.map((record) => {
        const summary = record.summary || {};
        const win = record.intervals?.win_delta || {};
        const rank = record.intervals?.rank_delta || {};
        const margin = record.intervals?.margin_delta || {};
        const winMean = Number(win.mean);
        const state = Number.isFinite(winMean) && winMean < 0 ? "negative" : "positive";
        const comparison = comparisonLabel(record);
        const comparisonClass = comparison === "heuristic" ? "heuristic" : "current-best";
        return `
          <div class="eval-row">
            <div>
              <strong>${record.completed_episodes || "-"} ep</strong>
              <span class="eval-target ${comparisonClass}">vs ${comparison}</span>
            </div>
            <div>
              <strong>${fmtPercent(summary.candidate_win_rate)} vs ${fmtPercent(summary.baseline_win_rate)}</strong>
              <span>candidate / ${comparison} win</span>
            </div>
            <div>
              <strong class="${state}">${fmtPercentPoint(win.mean)}</strong>
              <span>CI ${fmtPercentPoint(win.low)} to ${fmtPercentPoint(win.high)}</span>
            </div>
            <div>
              <strong>${fmtNumber(rank.mean, 2)}</strong>
              <span>rank delta</span>
            </div>
            <div>
              <strong>${fmtNumber(margin.mean, 1)}</strong>
              <span>margin delta</span>
            </div>
          </div>
        `;
      }).join("")}
    </div>
  `;
}

function benchmarkDeltaSummary(record) {
  if (!record?.intervals && !record?.summary) return `<span class="pool-muted">pending</span>`;
  const win = record.intervals?.win_delta || {};
  const rank = record.intervals?.rank_delta || {};
  const margin = record.intervals?.margin_delta || {};
  const utility = record.intervals?.utility_delta || {};
  return `
    <div class="pool-metrics">
      <span class="${Number(win.mean) < 0 ? "negative" : "positive"}">W ${fmtPercentPoint(win.mean)}</span>
      <span>R ${fmtNumber(rank.mean, 2)}</span>
      <span>M ${fmtNumber(margin.mean, 1)}</span>
      ${utility.mean !== undefined ? `<span>U ${fmtNumber(utility.mean, 3)}</span>` : ""}
    </div>
  `;
}

function poolStatusLabel(item) {
  const parts = [];
  if (item.promoted) parts.push("promoted");
  else if (item.promotion_eligible) parts.push("promotion eligible");
  else if (item.finalist) parts.push("finalist");
  if (item.benchmark_status) parts.push(fmtStatus(item.benchmark_status));
  return parts.join(" / ") || "candidate";
}

function renderModelPool(record) {
  const panel = document.getElementById("modelPoolPanel");
  const empty = document.getElementById("modelPoolEmpty");
  const table = document.getElementById("modelPoolTable");
  const count = document.getElementById("modelPoolCount");
  const pool = Array.isArray(record?.model_pool) ? record.model_pool : [];
  panel.style.display = pool.length ? "block" : "none";
  if (!pool.length) {
    empty.style.display = "block";
    table.innerHTML = "";
    count.textContent = "No pool";
    return;
  }
  const promoted = pool.filter((item) => item.promoted).length;
  const finalists = pool.filter((item) => item.finalist).length;
  count.textContent = `${pool.length} models / ${finalists} finalists / ${promoted} promoted`;
  empty.style.display = "none";
  table.innerHTML = `
    <div class="table-scroll">
      <table>
        <thead>
          <tr>
            <th>Model</th>
            <th>Selection benchmark</th>
            <th>Current best gate</th>
            <th>Arena</th>
            <th>Status</th>
          </tr>
        </thead>
        <tbody>
          ${pool.map((item) => {
            const selection = item.selection || {};
            const currentBest = item.promotion_current_best || {};
            const arenaText = item.finalist
              ? `${fmtNumber(item.arena_score, 3)} score / ${fmtPercentPoint(item.arena_mean_win_delta)} mean win / ${fmtPercentPoint(item.worst_arena_win_delta)} worst`
              : "not finalist";
            const statusClass = item.promoted ? "promoted" : item.finalist ? "finalist" : "";
            return `
              <tr>
                <td title="${item.candidate_model || ""}">
                  <strong>Seed ${item.generation || "-"}</strong>
                  <span>${shortPath(item.candidate_model)}</span>
                  <small>train ${item.seed || "-"} / eval ${item.eval_seed || "-"}</small>
                </td>
                <td>
                  ${benchmarkDeltaSummary(selection)}
                  <small>${selection.total_games || 0} games</small>
                </td>
                <td>
                  ${item.finalist ? benchmarkDeltaSummary(currentBest) : `<span class="pool-muted">not run</span>`}
                  ${item.finalist ? `<small>${currentBest.total_games || 0} games</small>` : ""}
                </td>
                <td>
                  <span>${arenaText}</span>
                  ${item.finalist ? `<small>${(item.arena_records || []).length} opponents / ${item.complete_arena ? "complete" : "running"}</small>` : ""}
                </td>
                <td>
                  <span class="pool-state ${statusClass}">${poolStatusLabel(item)}</span>
                </td>
              </tr>
            `;
          }).join("")}
        </tbody>
      </table>
    </div>
  `;
}

function drawMarginHistogram(distribution) {
  const svg = document.getElementById("marginShapeHistogram");
  const buckets = distribution?.margin_delta_histogram || [];
  if (!buckets.length) {
    svg.innerHTML = "";
    return;
  }
  const width = 760;
  const height = 220;
  const left = 42;
  const right = 14;
  const top = 16;
  const bottom = 34;
  const plotWidth = width - left - right;
  const plotHeight = height - top - bottom;
  const maxCount = Math.max(...buckets.map((bucket) => Number(bucket.count || 0)), 1);
  const minLow = Math.min(...buckets.map((bucket) => Number(bucket.low)));
  const maxHigh = Math.max(...buckets.map((bucket) => Number(bucket.high)));
  const xFor = (value) => {
    if (maxHigh === minLow) return left + plotWidth / 2;
    return left + ((value - minLow) / (maxHigh - minLow)) * plotWidth;
  };
  const zeroX = xFor(0);
  const bars = buckets.map((bucket) => {
    const low = Number(bucket.low);
    const high = Number(bucket.high);
    const count = Number(bucket.count || 0);
    const x = xFor(low) + 1;
    const barWidth = Math.max(1, xFor(high) - xFor(low) - 2);
    const barHeight = (count / maxCount) * plotHeight;
    const y = top + plotHeight - barHeight;
    const cls = high <= 0 ? "negative" : low >= 0 ? "positive" : "mixed";
    return `
      <rect class="margin-hist-bar ${cls}" x="${x.toFixed(1)}" y="${y.toFixed(1)}" width="${barWidth.toFixed(1)}" height="${barHeight.toFixed(1)}">
        <title>${fmtNumber(low, 0)} to ${fmtNumber(high, 0)}: ${count} games</title>
      </rect>
    `;
  }).join("");
  svg.innerHTML = `
    <line class="curve-gridline" x1="${left}" y1="${top}" x2="${width - right}" y2="${top}"></line>
    <line class="curve-gridline" x1="${left}" y1="${top + plotHeight / 2}" x2="${width - right}" y2="${top + plotHeight / 2}"></line>
    <line class="curve-axis" x1="${left}" y1="${top + plotHeight}" x2="${width - right}" y2="${top + plotHeight}"></line>
    <line class="curve-axis" x1="${left}" y1="${top}" x2="${left}" y2="${top + plotHeight}"></line>
    <line class="margin-zero-line" x1="${zeroX.toFixed(1)}" y1="${top}" x2="${zeroX.toFixed(1)}" y2="${top + plotHeight}"></line>
    <text class="curve-label" x="4" y="${top + 4}">${maxCount}</text>
    <text class="curve-label" x="${left}" y="${height - 8}">${fmtNumber(minLow, 0)}</text>
    <text class="curve-label" x="${width - right}" y="${height - 8}" text-anchor="end">${fmtNumber(maxHigh, 0)}</text>
    <text class="curve-label" x="${Math.min(width - right - 18, Math.max(left + 2, zeroX + 3)).toFixed(1)}" y="${top + 12}">0</text>
    ${bars}
  `;
}

function renderMarginShape(current, benchmarks) {
  const panel = document.getElementById("marginShapePanel");
  const grid = document.getElementById("marginShapeGrid");
  const empty = document.getElementById("marginShapeEmpty");
  const record = latestMarginShapeRecord(current, benchmarks);
  const distribution = record?.distribution;
  panel.style.display = distribution ? "block" : "none";
  if (!distribution) {
    grid.style.display = "none";
    empty.style.display = "block";
    return;
  }
  const shape = distribution.win_loss_shape || {};
  const rates = distribution.positive_rates || {};
  const quantiles = distribution.margin_delta_quantiles || {};
  const label = record.completed_episodes
    ? `${record.completed_episodes} ep vs ${comparisonLabel(record)}`
    : `${record.total_games || 0} games vs ${shortPath(record.baseline_model || record.model?.baseline_model)}`;
  document.getElementById("marginShapeSource").textContent = label;
  document.getElementById("marginPositiveRate").textContent = fmtPercent(rates.margin_delta);
  empty.style.display = "none";
  grid.style.display = "grid";
  drawMarginHistogram(distribution);
  document.getElementById("marginShapeStats").innerHTML = `
    <div class="margin-shape-stat">
      <strong>${fmtPercent(rates.win_delta)}</strong>
      <span>P(win delta &gt; 0)</span>
    </div>
    <div class="margin-shape-stat">
      <strong>${fmtPercent(rates.margin_delta)}</strong>
      <span>P(margin delta &gt; 0)</span>
    </div>
    <div class="margin-shape-stat">
      <strong>${fmtNumber(shape.mean_winning_margin, 1)}</strong>
      <span>mean winning margin</span>
    </div>
    <div class="margin-shape-stat">
      <strong>${fmtNumber(shape.mean_losing_margin, 1)}</strong>
      <span>mean losing margin</span>
    </div>
    <div class="margin-shape-stat">
      <strong>${fmtPercent(shape.close_loss_rate)}</strong>
      <span>losses within 5</span>
    </div>
    <div class="margin-shape-stat">
      <strong>${fmtPercent(shape.blowout_loss_rate)}</strong>
      <span>losses by 15+</span>
    </div>
    <div class="margin-shape-stat wide">
      <strong>${fmtNumber(quantiles.p25, 1)} / ${fmtNumber(quantiles.median, 1)} / ${fmtNumber(quantiles.p75, 1)}</strong>
      <span>margin delta p25 / median / p75</span>
    </div>
  `;
}

function renderTimeline(records) {
  const body = document.getElementById("timelineBody");
  body.innerHTML = (records || []).slice(0, 30).map((record) => `
    <tr>
      <td>${when(record.timestamp)}</td>
      <td>${record.kind.replaceAll("_", " ")}</td>
      <td>${architectureLabel(record.model)}</td>
      <td title="${record.model?.output_model || ""}">${shortPath(record.model?.output_model)}</td>
      <td>${record.status || "-"}</td>
    </tr>
  `).join("");
}

function renderBenchmarkList(records) {
  const target = document.getElementById("benchmarkList");
  target.innerHTML = (records || []).slice(0, 12).map((record) => {
    const win = record.intervals?.win_delta?.mean;
    const rank = record.intervals?.rank_delta?.mean;
    const margin = record.intervals?.margin_delta?.mean;
    const status = record.benchmark_status || record.status || "unknown";
    const promoted = record.promoted !== undefined ? ` / ${record.promoted ? "promoted" : "not promoted"}` : "";
    return `<div class="record">
      <strong>${status}${promoted} - ${when(record.timestamp)}</strong>
      <p>${architectureLabel(record.model)} vs ${shortPath(record.model?.baseline_model)}</p>
      <p>${record.evidence?.grade ? `evidence ${record.evidence.grade}${record.evidence.promotion_eligible ? " / promotion eligible" : ""}` : "evidence unknown"}</p>
      <p>win ${fmtNumber(win)} / rank ${fmtNumber(rank)} / margin ${fmtNumber(margin)}</p>
    </div>`;
  }).join("") || `<div class="record"><p>No benchmark records yet.</p></div>`;
}

function resultLine(record) {
  const summary = metricSource(record);
  const parts = [];
  if (record.intervals?.win_delta) parts.push(`win delta ${fmtNumber(record.intervals.win_delta.mean)}`);
  if (record.intervals?.rank_delta) parts.push(`rank delta ${fmtNumber(record.intervals.rank_delta.mean)}`);
  if (record.intervals?.margin_delta) parts.push(`margin delta ${fmtNumber(record.intervals.margin_delta.mean)}`);
  if (summary.candidate_win_rate !== undefined) parts.push(`candidate win ${fmtPercent(summary.candidate_win_rate)}`);
  if (summary.top_rate !== undefined) parts.push(`top ${fmtPercent(summary.top_rate)}`);
  if (summary.average_rank !== undefined) parts.push(`rank ${fmtNumber(summary.average_rank)}`);
  if (summary.average_margin !== undefined) parts.push(`margin ${fmtNumber(summary.average_margin)}`);
  if (record.total_games) parts.push(`${record.total_games} games`);
  return parts.join(" / ") || "no scalar result recorded";
}

function renderEvaluationList(records) {
  const target = document.getElementById("evaluationList");
  target.innerHTML = (records || []).slice(0, 12).map((record) => `
    <div class="record">
      <strong>${record.status || "unknown"} - ${when(record.timestamp)}</strong>
      <p>${record.kind.replaceAll("_", " ")} / ${architectureLabel(record.model)}</p>
      <p>${resultLine(record)}</p>
    </div>
  `).join("") || `<div class="record"><p>No evaluation records yet.</p></div>`;
}

function rollingPoints(points, key, windowSize = 32) {
  return points.map((point, index) => {
    const start = Math.max(0, index - windowSize + 1);
    const slice = points.slice(start, index + 1);
    const value = slice.reduce((total, item) => total + Number(item[key] || 0), 0) / slice.length;
    return { episode: point.episode, value };
  });
}

function valuePoints(points, key, windowSize = 1) {
  if (windowSize <= 1) {
    return points.map((point) => ({ episode: point.episode, value: Number(point[key] || 0) }));
  }
  return rollingPoints(points, key, windowSize);
}

function curveDomain(points, key, fixedDomain) {
  if (fixedDomain) return fixedDomain;
  const values = points.map((point) => Number(point[key])).filter((value) => Number.isFinite(value));
  if (!values.length) return [-1, 1];
  let low = Math.min(...values);
  let high = Math.max(...values);
  if (low === high) {
    low -= 1;
    high += 1;
  }
  const padding = Math.max((high - low) * 0.12, 0.01);
  return [low - padding, high + padding];
}

function polyline(points, xFor, yFor, valueFor) {
  return points
    .map((point) => `${xFor(point.episode).toFixed(1)},${yFor(valueFor(point)).toFixed(1)}`)
    .join(" ");
}

function recentMean(points, key, windowSize = 32) {
  if (!points.length) return null;
  const slice = points.slice(-Math.min(windowSize, points.length));
  return slice.reduce((total, point) => total + Number(point[key] || 0), 0) / slice.length;
}

function trendline(points, key) {
  const data = points
    .map((point) => ({ x: Number(point.episode), y: Number(point[key]) }))
    .filter((point) => Number.isFinite(point.x) && Number.isFinite(point.y));
  if (data.length < 2) return null;
  const xMean = data.reduce((total, point) => total + point.x, 0) / data.length;
  const yMean = data.reduce((total, point) => total + point.y, 0) / data.length;
  let numerator = 0;
  let denominator = 0;
  for (const point of data) {
    const xDelta = point.x - xMean;
    numerator += xDelta * (point.y - yMean);
    denominator += xDelta * xDelta;
  }
  if (!denominator) return null;
  const slope = numerator / denominator;
  const intercept = yMean - slope * xMean;
  return {
    slope,
    startEpisode: Math.min(...data.map((point) => point.x)),
    endEpisode: Math.max(...data.map((point) => point.x)),
    valueAt: (episode) => intercept + slope * episode,
  };
}

function slopeLabel(fit, options = {}) {
  if (!fit) return "slope -";
  const perThousand = fit.slope * 1000;
  if (options.percent) {
    const points = perThousand * 100;
    return `${points >= 0 ? "+" : ""}${points.toFixed(1)}pp/1k`;
  }
  return `${perThousand >= 0 ? "+" : ""}${perThousand.toFixed(options.slopeDigits ?? 2)}/1k`;
}

function evalMarkerValue(evaluation, key) {
  const summary = evaluation?.summary || {};
  if (key === "win") return summary.candidate_win_rate;
  if (key === "rank") return summary.candidate_average_rank;
  if (key === "margin") return summary.candidate_average_margin;
  return null;
}

function evalBaselineValue(evaluation, key) {
  const summary = evaluation?.summary || {};
  if (key === "win") return summary.baseline_win_rate;
  if (key === "rank") return summary.baseline_average_rank;
  if (key === "margin") return summary.baseline_average_margin;
  return null;
}

function evalCandidateIsBetter(candidate, baseline, key) {
  if (!Number.isFinite(candidate) || !Number.isFinite(baseline)) return false;
  if (key === "rank") return candidate < baseline;
  return candidate > baseline;
}

function drawCurve(svgId, latestId, slopeId, points, key, options = {}) {
  const svg = document.getElementById(svgId);
  const latest = document.getElementById(latestId);
  const slopeEl = document.getElementById(slopeId);
  if (!points.length) {
    svg.innerHTML = "";
    latest.textContent = "-";
    if (slopeEl) slopeEl.textContent = "slope -";
    return;
  }
  const width = Number(options.width || 1280) * Number(curveZoom[svgId] || 1);
  const height = 190;
  svg.setAttribute("viewBox", `0 0 ${width} ${height}`);
  svg.style.width = `${width}px`;
  svg.style.minWidth = `${width}px`;
  const left = 42;
  const right = 12;
  const top = 16;
  const bottom = 30;
  const plotWidth = width - left - right;
  const plotHeight = height - top - bottom;
  const episodes = points.map((point) => Number(point.episode));
  const minEpisode = Math.min(Number(options.xMin || Math.min(...episodes)), Math.min(...episodes));
  const maxEpisode = Math.max(Number(options.xMax || Math.max(...episodes)), Math.max(...episodes));
  const [domainLow, domainHigh] = curveDomain(points, key, options.domain);
  const xFor = (episode) => {
    if (minEpisode === maxEpisode) return left + plotWidth / 2;
    return left + ((episode - minEpisode) / (maxEpisode - minEpisode)) * plotWidth;
  };
  const yFor = (value) => {
    const span = domainHigh - domainLow || 1;
    const ratio = options.invert ? (value - domainLow) / span : (domainHigh - value) / span;
    return top + Math.max(0, Math.min(1, ratio)) * plotHeight;
  };
  const rawPoints = valuePoints(points, key, options.rawWindow || 1);
  const raw = polyline(rawPoints, xFor, yFor, (point) => point.value);
  const smooth = rollingPoints(points, key, options.window || 32);
  const smoothLine = polyline(smooth, xFor, yFor, (point) => point.value);
  const overlayMarkup = (options.overlaySeries || []).map((series) => {
    const overlayPoints = (series.points || [])
      .filter((point) => Number.isFinite(Number(point.episode)) && Number.isFinite(Number(point[key])));
    if (overlayPoints.length < 2) return "";
    const smoothed = rollingPoints(overlayPoints, key, options.window || 32);
    const line = polyline(smoothed, xFor, yFor, (point) => point.value);
    return `
      <polyline class="curve-seed-overlay ${series.primary ? "primary" : ""}"
        style="--series-color:${series.color || "var(--blue)"}"
        points="${line}">
        <title>${series.label}</title>
      </polyline>
    `;
  }).join("");
  const lastSmooth = smooth[smooth.length - 1];
  const latestValue = recentMean(points, key, options.latestWindow || options.window || 32);
  latest.textContent = options.percent ? fmtPercent(latestValue) : fmtNumber(latestValue, options.digits ?? 3);
  const fit = trendline(
    rawPoints.map((point) => ({ episode: point.episode, [key]: point.value })),
    key
  );
  if (slopeEl) {
    slopeEl.textContent = slopeLabel(fit, options);
    slopeEl.className = `curve-slope ${fit && fit.slope > 0 ? "positive" : fit && fit.slope < 0 ? "negative" : ""}`;
  }
  const topLabel = options.invert ? domainLow : domainHigh;
  const bottomLabel = options.invert ? domainHigh : domainLow;
  const middleLabel = (topLabel + bottomLabel) / 2;
  const yScale = document.querySelector(`[data-curve-y-scale="${svgId}"]`);
  if (yScale) {
    const labels = [topLabel, middleLabel, bottomLabel];
    yScale.querySelectorAll("span").forEach((item, index) => {
      item.textContent = options.percent ? fmtPercent(labels[index]) : fmtNumber(labels[index], options.digits ?? 1);
    });
  }
  const stageMarkup = (options.curriculumStages || []).map((stage, index) => {
    if (stage.endEpisode < minEpisode || stage.startEpisode > maxEpisode) return "";
    const x1 = xFor(Math.max(stage.startEpisode, minEpisode));
    const x2 = xFor(Math.min(stage.endEpisode, maxEpisode));
    const bandWidth = Math.max(0, x2 - x1);
    const marker = index === 0 ? "" : `<line class="curve-stage-marker" x1="${xFor(stage.startEpisode).toFixed(1)}" y1="${top}" x2="${xFor(stage.startEpisode).toFixed(1)}" y2="${top + plotHeight}"></line>`;
    const labelX = Math.min(x1 + 5, width - right - 44);
    return `
      <rect class="curve-stage-band ${index % 2 ? "alternate" : ""}" x="${x1.toFixed(1)}" y="${top}" width="${bandWidth.toFixed(1)}" height="${plotHeight}"></rect>
      ${marker}
      <text class="curve-stage-label" x="${labelX.toFixed(1)}" y="${top + 12}">${stage.label}</text>
    `;
  }).join("");
  const trendMarkup = fit ? `
    <line class="curve-trend"
      x1="${xFor(fit.startEpisode).toFixed(1)}"
      y1="${yFor(fit.valueAt(fit.startEpisode)).toFixed(1)}"
      x2="${xFor(fit.endEpisode).toFixed(1)}"
      y2="${yFor(fit.valueAt(fit.endEpisode)).toFixed(1)}"></line>
  ` : "";
  const evals = (options.evaluations || [])
    .filter((evaluation) => {
      const episode = Number(evaluation?.completed_episodes);
      return Number.isFinite(episode) && episode >= minEpisode && episode <= maxEpisode;
    });
  const evalMarkup = evals.map((evaluation) => {
    const episode = Number(evaluation.completed_episodes);
    const x = xFor(episode);
    const candidate = Number(evalMarkerValue(evaluation, key));
    const baseline = Number(evalBaselineValue(evaluation, key));
    if (!Number.isFinite(candidate) || !Number.isFinite(baseline)) return "";
    const state = evalCandidateIsBetter(candidate, baseline, key) ? "positive" : "negative";
    const episodeLabel = episode >= 1000 ? `${Math.round(episode / 1000)}k` : `${episode || "?"}`;
    const label = comparisonLabel(evaluation);
    const baselineClass = evaluation.comparison === "heuristic" || evaluation.baseline_model === "heuristic"
      ? "heuristic-baseline"
      : "baseline";
    return `
      <circle class="curve-eval-dot ${baselineClass}" cx="${x.toFixed(1)}" cy="${yFor(baseline).toFixed(1)}" r="4">
        <title>${episodeLabel} ${label} ${options.percent ? fmtPercent(baseline) : fmtNumber(baseline, options.digits ?? 2)}</title>
      </circle>
      <circle class="curve-eval-dot candidate ${state}" cx="${x.toFixed(1)}" cy="${yFor(candidate).toFixed(1)}" r="4.8">
        <title>${episodeLabel} candidate vs ${label} ${options.percent ? fmtPercent(candidate) : fmtNumber(candidate, options.digits ?? 2)}</title>
      </circle>
    `;
  }).join("");
  const nextEval = options.nextEvalMarker;
  const nextEvalMarkup = nextEval
    && Number.isFinite(Number(nextEval.episode))
    && Number(nextEval.episode) >= minEpisode
    && Number(nextEval.episode) <= maxEpisode
    ? `
      <line class="curve-next-eval-marker ${nextEval.active ? "active" : ""}"
        x1="${xFor(Number(nextEval.episode)).toFixed(1)}"
        y1="${top}"
        x2="${xFor(Number(nextEval.episode)).toFixed(1)}"
        y2="${top + plotHeight}"></line>
      <text class="curve-next-eval-label ${nextEval.active ? "active" : ""}"
        x="${Math.min(xFor(Number(nextEval.episode)) + 5, width - right - 58).toFixed(1)}"
        y="${top + plotHeight - 7}">${nextEval.active ? "eval now" : "next eval"}</text>
    `
    : "";
  svg.innerHTML = `
    ${stageMarkup}
    <line class="curve-gridline" x1="${left}" y1="${top}" x2="${width - right}" y2="${top}"></line>
    <line class="curve-gridline" x1="${left}" y1="${top + plotHeight / 2}" x2="${width - right}" y2="${top + plotHeight / 2}"></line>
    <line class="curve-axis" x1="${left}" y1="${top + plotHeight}" x2="${width - right}" y2="${top + plotHeight}"></line>
    <line class="curve-axis" x1="${left}" y1="${top}" x2="${left}" y2="${top + plotHeight}"></line>
    <text class="curve-label" x="4" y="${top + 4}">${options.percent ? fmtPercent(topLabel) : fmtNumber(topLabel, options.digits ?? 1)}</text>
    <text class="curve-label" x="4" y="${top + plotHeight + 4}">${options.percent ? fmtPercent(bottomLabel) : fmtNumber(bottomLabel, options.digits ?? 1)}</text>
    <text class="curve-label" x="${left}" y="${height - 7}">${options.xFormatter ? options.xFormatter(minEpisode) : minEpisode}</text>
    <text class="curve-label" x="${width - right}" y="${height - 7}" text-anchor="end">${options.xFormatter ? options.xFormatter(maxEpisode) : maxEpisode}</text>
    ${overlayMarkup}
    <polyline class="curve-raw" points="${raw}"></polyline>
    <polyline class="curve-smooth" points="${smoothLine}"></polyline>
    ${trendMarkup}
    ${evalMarkup}
    ${nextEvalMarkup}
    <circle class="curve-point" cx="${xFor(lastSmooth.episode).toFixed(1)}" cy="${yFor(lastSmooth.value).toFixed(1)}" r="4"></circle>
  `;
  const scrollContainer = svg.closest(".curve-scroll");
  if (scrollContainer && !scrollContainer.dataset.scrollListenerAttached) {
    scrollContainer.dataset.scrollListenerAttached = "true";
    scrollContainer.dataset.autoFollow = "true";
    scrollContainer.addEventListener("scroll", () => {
      if (scrollContainer.dataset.programmaticScroll === "true") return;
      scrollContainer.dataset.autoFollow = "false";
    }, { passive: true });
  }
  if (scrollContainer && scrollContainer.dataset.autoFollow !== "false") {
    requestAnimationFrame(() => {
      scrollContainer.dataset.programmaticScroll = "true";
      scrollContainer.scrollLeft = Math.max(
        0,
        xFor(lastSmooth.episode) - scrollContainer.clientWidth * curveFollowAnchor
      );
      requestAnimationFrame(() => {
        scrollContainer.dataset.programmaticScroll = "false";
      });
    });
  }
  updateCurveZoomControls(svgId);
}

function distillActionKindLabel(kind) {
  const labels = {
    1: "Trump",
    2: "Swap",
    3: "Confirm",
    4: "Play",
    5: "Assign",
    6: "Submit",
    7: "Continue",
  };
  return labels[Number(kind)] || `Kind ${kind}`;
}

function distillCurrentKey(record) {
  if (!record || record.kind !== "torch_policy_distillation") return null;
  return [
    record.output_model || record.model?.output_model || "unknown-output",
    record.training?.seed || "unknown-seed",
    record.progress?.total_states || record.training?.states || "unknown-states",
  ].join("|");
}

function updateDistillSeries(record) {
  const key = distillCurrentKey(record);
  if (!key) return;
  if (key !== distillSeriesKey) {
    distillSeriesKey = key;
    distillPoints = [];
    document.querySelectorAll("#distillPanel .curve-scroll").forEach((container) => {
      container.dataset.autoFollow = "true";
    });
  }
  const progress = record.progress || {};
  const summary = record.summary || {};
  const states = Number(progress.completed_states || progress.completedStates || 0);
  if (!Number.isFinite(states) || states <= 0) return;
  const point = {
    episode: states,
    loss: Number(summary.loss),
    match: Number(summary.teacher_match_rate),
    entropy: Number(summary.teacher_entropy),
    candidate_count: Number(summary.candidate_count_mean),
    candidate_count_max: Number(summary.candidate_count_max),
  };
  if (!Number.isFinite(point.loss) && !Number.isFinite(point.match) && !Number.isFinite(point.entropy)) return;
  const previous = distillPoints[distillPoints.length - 1];
  if (previous && previous.episode === point.episode) {
    distillPoints[distillPoints.length - 1] = point;
  } else if (!previous || point.episode > previous.episode) {
    distillPoints.push(point);
  }
  if (distillPoints.length > 1000) {
    distillPoints = distillPoints.slice(-1000);
  }
}

function renderDistillBars(targetId, buckets, labelForKey = (key) => key) {
  const target = document.getElementById(targetId);
  if (!target) return;
  const rows = Object.entries(buckets || {})
    .map(([key, value]) => ({
      key,
      label: labelForKey(key),
      states: Number(value.states || 0),
      rate: Number(value.teacher_match_rate),
    }))
    .filter((row) => Number.isFinite(row.rate))
    .sort((left, right) => {
      const stateDelta = right.states - left.states;
      return stateDelta || Number(left.key) - Number(right.key);
    })
    .slice(0, 8);
  if (!rows.length) {
    target.innerHTML = `<p class="mini">No diagnostics yet.</p>`;
    return;
  }
  target.innerHTML = rows.map((row) => `
    <div class="distill-bar-row">
      <span>${row.label}</span>
      <div class="distill-bar-track"><div style="width:${Math.max(1, Math.min(100, row.rate * 100)).toFixed(1)}%"></div></div>
      <strong>${fmtPercent(row.rate)}</strong>
      <small>${Math.round(row.states)} states</small>
    </div>
  `).join("");
}

function renderDistillation(record) {
  const panel = document.getElementById("distillPanel");
  const isDistill = record?.kind === "torch_policy_distillation" || record?.phase === "distillation";
  panel.style.display = isDistill || distillPoints.length ? "block" : "none";
  if (isDistill) updateDistillSeries(record);
  const points = distillPoints;
  const progress = record?.progress || {};
  const summary = record?.summary || {};
  const totalStates = Number(progress.total_states || record?.training?.states || 0);
  document.getElementById("distillCount").textContent = points.length
    ? `${points.length} samples from ${Math.round(Number(progress.completed_states || points[points.length - 1]?.episode || 0)).toLocaleString()} states`
    : "0 points";
  document.getElementById("distillEmpty").style.display = points.length ? "none" : "block";
  document.querySelector(".distill-grid").style.display = points.length ? "grid" : "none";
  const latestState = points.length ? Math.max(...points.map((point) => Number(point.episode) || 0)) : 0;
  const chartWidth = Math.max(1280, Math.min(3600, Math.ceil((totalStates || latestState || 1024) / 260)));
  const xFormatter = (value) => {
    const number = Number(value);
    if (!Number.isFinite(number)) return "-";
    if (number >= 1000) return `${Math.round(number / 1000)}k`;
    return `${Math.round(number)}`;
  };
  const options = {
    xMin: 1,
    xMax: totalStates || latestState || undefined,
    width: chartWidth,
    xFormatter,
    window: 5,
    latestWindow: 3,
  };
  drawCurve("distillLossCurve", "distillLossLatest", "distillLossSlope", points, "loss", { ...options, digits: 4, slopeDigits: 4 });
  drawCurve("distillMatchCurve", "distillMatchLatest", "distillMatchSlope", points, "match", { ...options, domain: [0, 1], percent: true });
  drawCurve("distillEntropyCurve", "distillEntropyLatest", "distillEntropySlope", points, "entropy", { ...options, digits: 3 });
  drawCurve("distillCandidatesCurve", "distillCandidatesLatest", "distillCandidatesSlope", points, "candidate_count", { ...options, digits: 2 });
  renderDistillBars("distillActionKinds", summary.teacher_match_by_action_kind, distillActionKindLabel);
  renderDistillBars("distillCandidateCounts", summary.teacher_match_by_candidate_count, (key) => `${key} actions`);
}

function isSupervisedPretrain(record) {
  return record?.kind === "torch_policy_supervised_pretrain"
    || record?.phase === "supervised_pretrain";
}

function supervisedCurvePoints(record) {
  if (!isSupervisedPretrain(record)) return [];
  if (Array.isArray(record?.updates)) {
    return record.updates.map(supervisedPointFromUpdate).filter((point) => Number.isFinite(point.episode));
  }
  const key = supervisedLiveKey(record);
  if (key && key === liveSupervisedSeriesKey) return liveSupervisedPoints;
  return [];
}

function supervisedLiveKey(record) {
  if (!record) return null;
  return [
    record.output_model || "unknown-output",
    record.start_model || "unknown-start",
    record.model?.architecture || "unknown-architecture",
    record.training?.epochs || record.progress?.total_epochs || "unknown-total",
  ].join("|");
}

function supervisedPointFromUpdate(update, index = 0) {
  const epoch = Number(update?.epoch || index + 1);
  return {
    episode: epoch,
    loss: Number(update?.loss),
    match: Number(update?.target_match_rate),
    policy_loss: Number(update?.policy_loss),
    value_loss: Number(update?.value_loss),
  };
}

function rememberLiveSupervisedPoint(record) {
  if (!isSupervisedPretrain(record) || Array.isArray(record?.updates)) return;
  const point = supervisedPointFromUpdate(record.summary);
  if (!Number.isFinite(point.episode)) return;
  const key = supervisedLiveKey(record);
  if (!key) return;
  if (key !== liveSupervisedSeriesKey) {
    liveSupervisedSeriesKey = key;
    liveSupervisedPoints = [];
  }
  const existingIndex = liveSupervisedPoints.findIndex((item) => item.episode === point.episode);
  if (existingIndex >= 0) {
    liveSupervisedPoints[existingIndex] = point;
  } else {
    liveSupervisedPoints.push(point);
    liveSupervisedPoints.sort((a, b) => a.episode - b.episode);
  }
}

function isMaskedStateTraining(record) {
  return record?.kind === "masked_state_policy_training"
    || record?.model?.architecture === "masked-state-mlp"
    || record?.architecture === "masked-state-mlp"
    || record?.model?.architecture === "masked-state-rnn"
    || record?.architecture === "masked-state-rnn"
    || record?.model?.architecture === "masked-state-transformer"
    || record?.architecture === "masked-state-transformer"
    || record?.model?.architecture === "masked-state-routed-transformer"
    || record?.architecture === "masked-state-routed-transformer";
}

function maskedStateLiveKey(record) {
  if (!record) return null;
  return [
    record.output_model || record.model?.output_model || "unknown-output",
    record.start_model || "unknown-start",
    record.training?.seed || record.seed || "unknown-seed",
    record.training?.episodes || record.progress?.total_episodes || "unknown-total",
  ].join("|");
}

function maskedStatePointFromUpdate(update) {
  const episode = Number(update?.episode || update?.completed_episodes);
  return {
    episode,
    reward: Number(update?.average_reward),
    loss: Number(update?.loss),
    policy_loss: Number(update?.policy_loss),
    value_loss: Number(update?.value_loss),
    entropy: Number(update?.entropy),
    actions: Number(update?.actions),
    eval_win: update?.eval ? Number(update.eval.win_rate) : undefined,
    eval_margin: update?.eval ? Number(update.eval.average_margin) : undefined,
  };
}

function rememberLiveMaskedStatePoint(record) {
  if (!isMaskedStateTraining(record) || Array.isArray(record?.points)) return;
  const point = maskedStatePointFromUpdate(record.latest_point);
  if (!Number.isFinite(point.episode)) return;
  const key = maskedStateLiveKey(record);
  if (!key) return;
  if (key !== liveMaskedStateSeriesKey) {
    liveMaskedStateSeriesKey = key;
    liveMaskedStatePoints = [];
  }
  const existingIndex = liveMaskedStatePoints.findIndex((item) => item.episode === point.episode);
  if (existingIndex >= 0) {
    liveMaskedStatePoints[existingIndex] = point;
  } else {
    liveMaskedStatePoints.push(point);
    liveMaskedStatePoints.sort((a, b) => a.episode - b.episode);
  }
  if (liveMaskedStatePoints.length > 1000) {
    liveMaskedStatePoints = liveMaskedStatePoints.slice(-1000);
  }
}

function maskedStateCurvePoints(record) {
  if (!isMaskedStateTraining(record)) return [];
  if (Array.isArray(record?.points)) {
    return record.points.map(maskedStatePointFromUpdate).filter((point) => Number.isFinite(point.episode));
  }
  if (Array.isArray(record?.curve?.points)) {
    return record.curve.points.map(maskedStatePointFromUpdate).filter((point) => Number.isFinite(point.episode));
  }
  const key = maskedStateLiveKey(record);
  if (key && key === liveMaskedStateSeriesKey) return liveMaskedStatePoints;
  return [];
}

function trainingCurvePoints(record) {
  const source = trainingDisplaySource(record);
  if (source !== record) return trainingCurvePoints(source);
  const masked = maskedStateCurvePoints(record);
  if (masked.length) {
    return { mode: "masked", points: masked };
  }
  const supervised = supervisedCurvePoints(record);
  if (supervised.length) {
    return { mode: "supervised", points: supervised };
  }
  return { mode: "rl", points: record?.curve?.points || [] };
}

function setCurveLabels(mode) {
  const supervised = mode === "supervised";
  const masked = mode === "masked";
  text("curvePanelTitle", supervised ? "Live supervised metrics" : masked ? "Live masked PPO metrics" : "Live episode metrics");
  text("rewardCurveLabel", supervised || masked ? "Loss" : "Reward");
  text("winCurveLabel", supervised ? "Target Match" : masked ? "Reward" : "Win Rate");
  text("rankCurveLabel", supervised || masked ? "Policy Loss" : "Rank");
  text("marginCurveLabel", supervised || masked ? "Value Loss" : "Margin");
}

function renderCurves(current, trainings) {
  const currentSource = trainingDisplaySource(current);
  const currentCurve = trainingCurvePoints(currentSource);
  const historicalSource = (trainings || [])
    .map(trainingDisplaySource)
    .find((record) => trainingCurvePoints(record).points.length);
  const source = currentCurve.points.length ? currentSource : historicalSource;
  const curveData = trainingCurvePoints(source);
  const mode = curveData.mode;
  const sourceKey = trainingCurveKey(source);
  if (sourceKey && sourceKey !== trainingCurveSourceKey) {
    trainingCurveSourceKey = sourceKey;
    document.querySelectorAll("#trainingCurveGrid .curve-scroll").forEach((container) => {
      container.dataset.autoFollow = "true";
      container.scrollLeft = 0;
    });
  }
  const points = curveData.points;
  const stages = mode === "supervised" || mode === "masked" ? [] : curriculumStages(source);
  const episodeTotal = totalEpisodes(source);
  setCurveLabels(mode);
  document.getElementById("curveCount").textContent = points.length
    ? mode === "supervised"
      ? `${points.length} epochs`
      : mode === "masked"
        ? `${points.length} PPO batches`
      : `${points.length} points${source.curve.sampled ? ` from ${source.curve.source_episodes} episodes` : ""}`
    : "0 points";
  document.getElementById("curveEmpty").style.display = points.length ? "none" : "block";
  document.getElementById("trainingCurveGrid").style.display = points.length ? "grid" : "none";
  const latestEpisode = points.length ? Math.max(...points.map((point) => Number(point.episode) || 0)) : 0;
  const chartWidth = mode === "supervised"
    ? Math.max(1280, Math.min(2400, Math.ceil((episodeTotal || latestEpisode || 12) * 120)))
    : Math.max(1280, Math.min(3600, Math.ceil((episodeTotal || latestEpisode || 640) / 4)));
  const evaluations = source?.evaluations || [];
  const options = { curriculumStages: stages, evaluations, nextEvalMarker: nextEvalMarker(source), xMin: 1, xMax: episodeTotal || undefined, width: chartWidth };
  const seedSeries = mode === "rl" ? seedOverlaySeries(source, trainings, mode) : [];
  renderSeedOverlayLegend(seedSeries);
  if (mode === "supervised") {
    drawCurve("rewardCurve", "rewardLatest", "rewardSlope", points, "loss", { ...options, digits: 4, slopeDigits: 4 });
    drawCurve("winCurve", "winLatest", "winSlope", points, "match", { ...options, domain: [0, 1], percent: true });
    drawCurve("rankCurve", "rankLatest", "rankSlope", points, "policy_loss", { ...options, digits: 4, slopeDigits: 4 });
    drawCurve("marginCurve", "marginLatest", "marginSlope", points, "value_loss", { ...options, digits: 4, slopeDigits: 4 });
  } else if (mode === "masked") {
    drawCurve("rewardCurve", "rewardLatest", "rewardSlope", points, "loss", { ...options, digits: 4, slopeDigits: 4 });
    drawCurve("winCurve", "winLatest", "winSlope", points, "reward", { ...options, digits: 3 });
    drawCurve("rankCurve", "rankLatest", "rankSlope", points, "policy_loss", { ...options, digits: 4, slopeDigits: 4 });
    drawCurve("marginCurve", "marginLatest", "marginSlope", points, "value_loss", { ...options, digits: 4, slopeDigits: 4 });
  } else {
    drawCurve("rewardCurve", "rewardLatest", "rewardSlope", points, "reward", { ...options, digits: 3 });
    drawCurve("winCurve", "winLatest", "winSlope", points, "win", {
      ...options,
      domain: [0, 1],
      percent: true,
      overlaySeries: seedSeries,
    });
    drawCurve("rankCurve", "rankLatest", "rankSlope", points, "rank", { ...options, domain: [1, 4], invert: true, digits: 2 });
    drawCurve("marginCurve", "marginLatest", "marginSlope", points, "margin", { ...options, digits: 2 });
  }
}

async function refresh() {
  try {
    const response = await fetch("/api/status", { cache: "no-store" });
    const payload = await response.json();
    latestPayload = payload;
    rememberLiveSupervisedPoint(payload.current);
    rememberLiveMaskedStatePoint(payload.current);
    stateEl.classList.add("live");
    updatedEl.textContent = `Updated ${when(payload.generated_at)}`;
    renderCurrent(payload.current);
    renderCounts(payload.counts || {});
    renderOnlineSmoke(payload.online_smoke || {});
    renderLatestBenchmark(payload.benchmarks || [], payload.current);
    renderTrainingEval(payload.current);
    renderTrainingEvalList(payload.current);
    renderModelPool(payload.current);
    renderMarginShape(payload.current, payload.benchmarks || []);
    renderDistillation(payload.current);
    renderCurves(payload.current, payload.trainings || []);
    renderTimeline(payload.history || []);
    renderBenchmarkList(payload.benchmarks || []);
    renderEvaluationList(payload.evaluations || []);
  } catch (error) {
    stateEl.classList.remove("live");
    updatedEl.textContent = "Dashboard disconnected";
  }
}

attachCurveZoomControls();
refresh();
setInterval(refresh, 5000);
document.getElementById("runOnlineSmoke")?.addEventListener("click", runOnlineSmoke);
