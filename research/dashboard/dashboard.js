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

function rollingPoints(points, key, windowSize = 32) {
  return points.map((point, index) => {
    const start = Math.max(0, index - windowSize + 1);
    const slice = points.slice(start, index + 1);
    const value = slice.reduce((total, item) => total + Number(item[key] || 0), 0) / slice.length;
    return { episode: point.episode, value };
  });
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

function drawCurve(svgId, latestId, points, key, options = {}) {
  const svg = document.getElementById(svgId);
  const latest = document.getElementById(latestId);
  if (!points.length) {
    svg.innerHTML = "";
    latest.textContent = "-";
    return;
  }
  const width = 640;
  const height = 190;
  const left = 42;
  const right = 12;
  const top = 16;
  const bottom = 30;
  const plotWidth = width - left - right;
  const plotHeight = height - top - bottom;
  const episodes = points.map((point) => Number(point.episode));
  const minEpisode = Math.min(...episodes);
  const maxEpisode = Math.max(...episodes);
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
  const raw = polyline(points, xFor, yFor, (point) => Number(point[key] || 0));
  const smooth = rollingPoints(points, key, options.window || 32);
  const smoothLine = polyline(smooth, xFor, yFor, (point) => point.value);
  const lastSmooth = smooth[smooth.length - 1];
  const latestValue = recentMean(points, key, options.window || 32);
  latest.textContent = options.percent ? fmtPercent(latestValue) : fmtNumber(latestValue, options.digits ?? 3);
  const topLabel = options.invert ? domainLow : domainHigh;
  const bottomLabel = options.invert ? domainHigh : domainLow;
  svg.innerHTML = `
    <line class="curve-gridline" x1="${left}" y1="${top}" x2="${width - right}" y2="${top}"></line>
    <line class="curve-gridline" x1="${left}" y1="${top + plotHeight / 2}" x2="${width - right}" y2="${top + plotHeight / 2}"></line>
    <line class="curve-axis" x1="${left}" y1="${top + plotHeight}" x2="${width - right}" y2="${top + plotHeight}"></line>
    <line class="curve-axis" x1="${left}" y1="${top}" x2="${left}" y2="${top + plotHeight}"></line>
    <text class="curve-label" x="4" y="${top + 4}">${options.percent ? fmtPercent(topLabel) : fmtNumber(topLabel, options.digits ?? 1)}</text>
    <text class="curve-label" x="4" y="${top + plotHeight + 4}">${options.percent ? fmtPercent(bottomLabel) : fmtNumber(bottomLabel, options.digits ?? 1)}</text>
    <text class="curve-label" x="${left}" y="${height - 7}">${minEpisode}</text>
    <text class="curve-label" x="${width - right}" y="${height - 7}" text-anchor="end">${maxEpisode}</text>
    <polyline class="curve-raw" points="${raw}"></polyline>
    <polyline class="curve-smooth" points="${smoothLine}"></polyline>
    <circle class="curve-point" cx="${xFor(lastSmooth.episode).toFixed(1)}" cy="${yFor(lastSmooth.value).toFixed(1)}" r="4"></circle>
  `;
}

function renderCurves(current, trainings) {
  const source = current?.curve?.points?.length ? current : (trainings || []).find((record) => record.curve?.points?.length);
  const points = source?.curve?.points || [];
  document.getElementById("curveCount").textContent = points.length
    ? `${points.length} points${source.curve.sampled ? ` from ${source.curve.source_episodes} episodes` : ""}`
    : "0 points";
  document.getElementById("curveEmpty").style.display = points.length ? "none" : "block";
  document.querySelector(".curve-grid").style.display = points.length ? "grid" : "none";
  drawCurve("rewardCurve", "rewardLatest", points, "reward", { digits: 3 });
  drawCurve("winCurve", "winLatest", points, "win", { domain: [0, 1], percent: true });
  drawCurve("rankCurve", "rankLatest", points, "rank", { domain: [1, 4], invert: true, digits: 2 });
  drawCurve("marginCurve", "marginLatest", points, "margin", { digits: 2 });
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
    renderCurves(payload.current, payload.trainings || []);
    renderTimeline(payload.history || []);
    renderBenchmarkList(payload.benchmarks || []);
  } catch (error) {
    stateEl.classList.remove("live");
    updatedEl.textContent = "Dashboard disconnected";
  }
}

refresh();
setInterval(refresh, 5000);
