/* ─── CloudflareSpeedTest Web UI ─── */

let pollTimer = null;
let logOffset = 0;

// ─── 标签页切换 ────────────────────────────────────────────────────────────
document.querySelectorAll('.tab').forEach(tab => {
  tab.addEventListener('click', () => {
    const target = tab.dataset.tab;
    document.querySelectorAll('.tab').forEach(t => t.classList.remove('active'));
    document.querySelectorAll('.panel').forEach(p => p.classList.remove('active'));
    tab.classList.add('active');
    document.getElementById('panel-' + target).classList.add('active');

    if (target === 'result') loadResult();
    if (target === 'history') loadHistory();
    if (target === 'settings') loadIPConfig();
  });
});

// ─── 测速模式切换 ──────────────────────────────────────────────────────────
document.querySelectorAll('.toggle-btn').forEach(btn => {
  btn.addEventListener('click', () => {
    document.querySelectorAll('.toggle-btn').forEach(b => b.classList.remove('active'));
    btn.classList.add('active');
    document.getElementById('httping').value = btn.dataset.mode === 'httping' ? '1' : '';
  });
});

// ─── 获取表单参数 ──────────────────────────────────────────────────────────
function getParams() {
  const p = {};
  const threads = document.getElementById('threads').value;
  const pingTimes = document.getElementById('ping_times').value;
  const downloadCount = document.getElementById('download_count').value;
  const downloadTime = document.getElementById('download_time').value;
  const port = document.getElementById('port').value;
  const maxDelay = document.getElementById('max_delay').value;
  const minDelay = document.getElementById('min_delay').value;
  const maxLoss = document.getElementById('max_loss').value;
  const minSpeed = document.getElementById('min_speed').value;
  const cfcolo = document.getElementById('cfcolo').value.trim();
  const httpingCode = document.getElementById('httping_code').value;
  const url = document.getElementById('url').value.trim();
  const ipText = document.getElementById('ip_text').value.trim();

  if (threads) p.threads = parseInt(threads);
  if (pingTimes) p.ping_times = parseInt(pingTimes);
  if (downloadCount) p.download_count = parseInt(downloadCount);
  if (downloadTime) p.download_time = parseInt(downloadTime);
  if (port) p.port = parseInt(port);
  if (document.getElementById('httping').value === '1') p.httping = true;
  if (maxDelay) p.max_delay = parseInt(maxDelay);
  if (minDelay) p.min_delay = parseInt(minDelay);
  if (maxLoss) p.max_loss = parseFloat(maxLoss);
  if (minSpeed) p.min_speed = parseFloat(minSpeed);
  if (cfcolo) p.cfcolo = cfcolo;
  if (httpingCode) p.httping_code = parseInt(httpingCode);
  if (url) p.url = url;
  if (ipText) p.ip_text = ipText;
  if (document.getElementById('disable_download').checked) p.disable_download = true;
  if (document.getElementById('all_ip').checked) p.all_ip = true;
  if (document.getElementById('debug').checked) p.debug = true;

  return p;
}

// ─── 开始测速 ──────────────────────────────────────────────────────────────
async function startTest() {
  const btn = document.getElementById('btnStart');
  btn.disabled = true;
  btn.textContent = '启动中...';

  try {
    const res = await fetch('/api/start', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(getParams()),
    });
    const data = await res.json();
    if (data.ok) {
      showToast('测速任务已启动', 'success');
      logOffset = 0;
      document.getElementById('logOutput').innerHTML = '';
      document.getElementById('logCard').style.display = 'block';
      startPolling();
    } else {
      showToast(data.msg, 'error');
    }
  } catch (e) {
    showToast('启动失败: ' + e.message, 'error');
  } finally {
    btn.disabled = false;
    btn.textContent = '🚀 开始测速';
  }
}

// ─── 停止测速 ──────────────────────────────────────────────────────────────
async function stopTest() {
  try {
    const res = await fetch('/api/stop', { method: 'POST' });
    const data = await res.json();
    showToast(data.msg, data.ok ? 'success' : 'error');
  } catch (e) {
    showToast('停止失败: ' + e.message, 'error');
  }
}

// ─── 轮询状态 ──────────────────────────────────────────────────────────────
function startPolling() {
  if (pollTimer) clearInterval(pollTimer);
  pollTimer = setInterval(pollStatus, 1000);
}

function stopPolling() {
  if (pollTimer) {
    clearInterval(pollTimer);
    pollTimer = null;
  }
}

async function pollStatus() {
  try {
    const [statusRes, logRes] = await Promise.all([
      fetch('/api/status'),
      fetch('/api/log?offset=' + logOffset),
    ]);
    const status = await statusRes.json();
    const log = await logRes.json();

    // 更新 badge
    const badge = document.getElementById('statusBadge');
    badge.className = 'badge ' + status.status;
    const statusMap = {
      idle: '空闲',
      running: '运行中',
      finished: '已完成',
      error: '错误',
      stopped: '已停止',
    };
    badge.textContent = statusMap[status.status] || status.status;

    // 更新按钮
    const btnStart = document.getElementById('btnStart');
    const btnStop = document.getElementById('btnStop');
    if (status.status === 'running') {
      btnStart.style.display = 'none';
      btnStop.style.display = 'inline-flex';
    } else {
      btnStart.style.display = 'inline-flex';
      btnStop.style.display = 'none';
    }

    // 追加日志
    if (log.lines && log.lines.length > 0) {
      const logEl = document.getElementById('logOutput');
      log.lines.forEach(line => {
        const div = document.createElement('div');
        div.className = 'log-line';
        if (line.includes('[完成]') || line.includes('完成')) div.classList.add('success');
        else if (line.includes('[错误]') || line.includes('错误')) div.classList.add('error');
        else if (line.includes('[启动]') || line.includes('[提示]')) div.classList.add('info');
        div.textContent = line;
        logEl.appendChild(div);
      });
      logOffset = log.total;
      logEl.scrollTop = logEl.scrollHeight;
      document.getElementById('logCount').textContent = logOffset + ' 行';
    }

    // 完成或错误时停止轮询
    if (['finished', 'error', 'stopped', 'idle'].includes(status.status)) {
      stopPolling();
      if (status.status === 'finished') {
        showToast('测速完成！', 'success');
        loadResult();
      }
    }
  } catch (e) {
    // 网络错误时静默
  }
}

// ─── 加载结果 ──────────────────────────────────────────────────────────────
async function loadResult() {
  try {
    const res = await fetch('/api/result');
    const data = await res.json();
    renderTable(data.results, 'resultTableWrap');
  } catch (e) {
    console.error(e);
  }
}

function renderTable(results, containerId) {
  const container = document.getElementById(containerId);
  if (!results || results.length === 0) {
    container.innerHTML = '<p class="empty-hint">暂无测速结果 📭</p>';
    return;
  }

  const headers = Object.keys(results[0]);
  let html = '<table><thead><tr>';
  headers.forEach(h => {
    html += `<th>${escapeHtml(h)}</th>`;
  });
  html += '</tr></thead><tbody>';

  results.forEach(row => {
    html += '<tr>';
    headers.forEach(h => {
      const val = escapeHtml(row[h] || '');
      let cls = '';
      if (h.includes('速度') || h.includes('speed')) cls = 'speed-cell';
      else if (h.includes('延迟') || h.includes('delay')) cls = 'delay-cell';
      else if (h.includes('丢包') || h.includes('loss')) {
        cls = 'loss-cell';
        html += `<td class="${cls}" data-loss="${val}">${val}</td>`;
        return;
      }
      html += `<td class="${cls}">${val}</td>`;
    });
    html += '</tr>';
  });

  html += '</tbody></table>';
  container.innerHTML = html;
}

// ─── 历史记录 ──────────────────────────────────────────────────────────────
async function loadHistory() {
  try {
    const res = await fetch('/api/history');
    const data = await res.json();
    const list = document.getElementById('historyList');

    if (!data.history || data.history.length === 0) {
      list.innerHTML = '<p class="empty-hint">暂无历史记录 📭</p>';
      return;
    }

    let html = '';
    data.history.forEach(item => {
      const timeStr = item.time.replace(/_/g, ' ').replace(/(\d{4})(\d{2})(\d{2})/, '$1-$2-$3');
      html += `
        <div class="history-item" onclick="viewHistory('${item.filename}')">
          <span class="history-time">📅 ${escapeHtml(timeStr)}</span>
          <span class="history-count">${item.count} 条结果</span>
        </div>
      `;
    });
    list.innerHTML = html;
  } catch (e) {
    console.error(e);
  }
}

async function viewHistory(filename) {
  try {
    const res = await fetch('/api/history/' + filename);
    const data = await res.json();

    const modal = document.getElementById('modal');
    document.getElementById('modalTitle').textContent = '📊 ' + filename;
    const body = document.getElementById('modalBody');

    if (data.results && data.results.length > 0) {
      const headers = Object.keys(data.results[0]);
      let html = '<div style="overflow-x:auto"><table><thead><tr>';
      headers.forEach(h => { html += `<th>${escapeHtml(h)}</th>`; });
      html += '</tr></thead><tbody>';
      data.results.forEach(row => {
        html += '<tr>';
        headers.forEach(h => {
          html += `<td>${escapeHtml(row[h] || '')}</td>`;
        });
        html += '</tr>';
      });
      html += '</tbody></table></div>';
      html += `<div style="margin-top:16px;text-align:center">
        <button class="btn btn-sm" onclick="downloadHistoryCSV('${filename}')">📥 下载 CSV</button>
      </div>`;
      body.innerHTML = html;
    } else {
      body.innerHTML = '<p class="empty-hint">无数据</p>';
    }

    modal.classList.add('show');
  } catch (e) {
    showToast('加载失败', 'error');
  }
}

function downloadHistoryCSV(filename) {
  window.open('/api/history/' + filename + '/csv', '_blank');
}

// ─── 导出 CSV ──────────────────────────────────────────────────────────────
function exportCSV() {
  window.open('/api/result/csv', '_blank');
}

// ─── IP 配置 ───────────────────────────────────────────────────────────────
async function loadIPConfig() {
  try {
    const res = await fetch('/api/config');
    const data = await res.json();
    document.getElementById('ipContent').value = data.ip_content || '';
  } catch (e) {
    showToast('加载失败', 'error');
  }
}

async function saveIPConfig() {
  try {
    const content = document.getElementById('ipContent').value;
    const res = await fetch('/api/config/ip', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ content }),
    });
    const data = await res.json();
    showToast(data.msg, data.ok ? 'success' : 'error');
  } catch (e) {
    showToast('保存失败: ' + e.message, 'error');
  }
}

// ─── 弹窗 ──────────────────────────────────────────────────────────────────
function closeModal(e) {
  if (e && e.target !== e.currentTarget) return;
  document.getElementById('modal').classList.remove('show');
}

// ─── Toast ──────────────────────────────────────────────────────────────────
function showToast(msg, type) {
  const toast = document.getElementById('toast');
  toast.textContent = msg;
  toast.className = 'toast show ' + (type || '');
  setTimeout(() => { toast.className = 'toast'; }, 3000);
}

// ─── 工具函数 ──────────────────────────────────────────────────────────────
function escapeHtml(text) {
  const div = document.createElement('div');
  div.textContent = text;
  return div.innerHTML;
}

// ─── 初始化 ────────────────────────────────────────────────────────────────
async function init() {
  try {
    const res = await fetch('/api/health');
    const data = await res.json();
    const el = document.getElementById('healthStatus');
    if (data.binary) {
      el.textContent = 'v' + data.version + ' ✅';
      el.style.color = '#34d399';
    } else {
      el.textContent = '⚠️ 二进制文件缺失';
      el.style.color = '#f87171';
    }
  } catch (e) {
    document.getElementById('healthStatus').textContent = '⚠️ 连接失败';
  }

  // 检查是否有正在运行的任务
  try {
    const res = await fetch('/api/status');
    const status = await res.json();
    if (status.status === 'running') {
      logOffset = 0;
      document.getElementById('logCard').style.display = 'block';
      startPolling();
    }
  } catch (e) {}
}

init();

// 键盘快捷键
document.addEventListener('keydown', e => {
  if (e.key === 'Escape') closeModal();
});
