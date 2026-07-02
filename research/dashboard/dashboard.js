const stateEl = document.getElementById("refreshState");
const updatedEl = document.getElementById("updatedAt");

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

function shortPath(value) {
  if (!value) return "-";
  const parts = String(value).split("/");
  if (parts.length <= 3) return String(value);
  return `${parts.slice(0, 2).join("/")}/.../${parts.slice(-2).join("/")}`;
}

function when(value) {
  if (!value) return "-";
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return value;
  return date.toLocaleString([], { hour: "2-digit", minute: "2-digit", second: "2-digit", month: "short", day: "numeric" });
}

function architectureLabel(model) {
  if (!model) return "unknown";
  const layers = Array.isArray(model.layers) && model.layers.length ? ` ${model.layers.join("x")}` : "";
  return `${model.architecture || "unknown"}${layers}`;
}

function metricSource(record) {
  if (!record) return {};
  return record.summary || record.result || {};
}

function renderCurrent(record) {
  const model = record?.model || {};
  const progress = record?.progress || {};
  const summary = metricSource(record);
  const fallbackPercent = record && record.status !== "running" ? 1 : 0;
  const percent = Math.max(0, Math.min(1, Number(progress.percent ?? fallbackPercent)));
  text("currentTitle", record ? record.kind.replaceAll("_", " ") : "No experiment");
  text("architecture", architectureLabel(model));
  text("backend", model.backend || record?.backend || "backend unknown");
  text("device", model.device || record?.device || "device unknown");
  text("outputModel", shortPath(model.output_model));
  text("baselineModel", shortPath(model.baseline_model || record?.baseline_model));
  text("seedValue", record?.seed ?? record?.training?.seed ?? "-");
  text("progressValue", fmtPercent(percent));
  const progressLabel = progress.total_episodes
    ? `${progress.completed_episodes || 0} / ${progress.total_episodes} episodes`
    : progress.total_games
      ? `${progress.completed_games || 0} / ${progress.total_games} games`
      : "Completed record";
  text("progressLabel", progressLabel);
  document.getElementById("progressBar").style.width = `${Math.round(percent * 100)}%`;
  const status = document.getElementById("currentStatus");
  status.textContent = record?.status || "unknown";
  status.className = `status-pill ${record?.status || ""}`;
  text("metricWin", fmtPercent(summary.top_rate ?? summary.candidate_win_rate));
  text("metricRank", fmtNumber(summary.average_rank ?? summary.candidate_average_rank));
  text("metricMargin", fmtNumber(summary.average_margin ?? summary.candidate_average_margin));
  text("metricReward", fmtNumber(summary.average_reward));
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

function renderLatestBenchmark(benchmarks) {
  const latest = benchmarks?.[0];
  const target = document.getElementById("benchmarkDeltas");
  if (!latest?.intervals) {
    target.innerHTML = `<p class="mini">No benchmark records yet.</p>`;
    return;
  }
  target.innerHTML = [
    deltaRow("Win delta", latest.intervals.win_delta),
    deltaRow("Rank delta", latest.intervals.rank_delta),
    deltaRow("Margin delta", latest.intervals.margin_delta),
  ].join("");
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
    return `<div class="record">
      <strong>${record.status || "unknown"} - ${when(record.timestamp)}</strong>
      <p>${architectureLabel(record.model)} vs ${shortPath(record.model?.baseline_model)}</p>
      <p>win ${fmtNumber(win)} / rank ${fmtNumber(rank)} / margin ${fmtNumber(margin)}</p>
    </div>`;
  }).join("") || `<div class="record"><p>No benchmark records yet.</p></div>`;
}

async function refresh() {
  try {
    const response = await fetch("/api/status", { cache: "no-store" });
    const payload = await response.json();
    stateEl.classList.add("live");
    updatedEl.textContent = `Updated ${when(payload.generated_at)}`;
    renderCurrent(payload.current);
    renderCounts(payload.counts || {});
    renderLatestBenchmark(payload.benchmarks || []);
    renderTimeline(payload.history || []);
    renderBenchmarkList(payload.benchmarks || []);
  } catch (error) {
    stateEl.classList.remove("live");
    updatedEl.textContent = "Dashboard disconnected";
  }
}

refresh();
setInterval(refresh, 5000);
