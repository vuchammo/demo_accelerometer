// Web Dashboard HTML, CSS, và JS được nhúng trực tiếp để Local Web Server phục vụ cho máy tính / laptop.
// Tích hợp thư viện Apache ECharts, thiết kế Dark Mode Neon cao cấp.

const String webDashboardHtml = r'''<!DOCTYPE html>
<html lang="vi">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Motion Sensor Web Dashboard</title>
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=Outfit:wght@400;500;600;700;800&family=JetBrains+Mono:wght@400;600&display=swap" rel="stylesheet">
  <script src="https://cdn.jsdelivr.net/npm/echarts@5.5.0/dist/echarts.min.js"></script>
  <style>
    :root {
      --bg: #090B10;
      --card-bg: #121622;
      --card-hover: #171D2D;
      --border: #202738;
      --border-focus: #00E5FF;
      --text: #F1F5F9;
      --text-muted: #94A3B8;
      --cyan: #00E5FF;
      --blue: #2979FF;
      --green: #00E676;
      --orange: #FF9100;
      --red: #FF5252;
      --sidebar-width: 340px;
    }

    * {
      box-sizing: border-box;
      margin: 0;
      padding: 0;
    }

    body {
      font-family: 'Outfit', -apple-system, BlinkMacSystemFont, sans-serif;
      background: var(--bg);
      color: var(--text);
      min-height: 100vh;
      display: flex;
      flex-direction: column;
      overflow-x: hidden;
    }

    /* TOP NAVBAR */
    header {
      background: rgba(18, 22, 34, 0.85);
      backdrop-filter: blur(16px);
      border-bottom: 1px solid var(--border);
      height: 64px;
      display: flex;
      align-items: center;
      justify-content: space-between;
      padding: 0 24px;
      position: sticky;
      top: 0;
      z-index: 100;
    }

    .brand {
      display: flex;
      align-items: center;
      gap: 12px;
    }

    .brand-logo {
      width: 36px;
      height: 36px;
      background: linear-gradient(135deg, var(--cyan), var(--blue));
      border-radius: 10px;
      display: flex;
      align-items: center;
      justify-content: center;
      box-shadow: 0 0 16px rgba(0, 229, 255, 0.4);
    }

    .brand-logo svg {
      width: 20px;
      height: 20px;
      fill: #fff;
    }

    .brand-title {
      font-size: 1.15rem;
      font-weight: 700;
      letter-spacing: -0.02em;
      background: linear-gradient(to right, #fff, #94A3B8);
      -webkit-background-clip: text;
      -webkit-text-fill-color: transparent;
    }

    .brand-badge {
      font-size: 0.72rem;
      font-weight: 600;
      text-transform: uppercase;
      padding: 2px 8px;
      background: rgba(0, 229, 255, 0.15);
      border: 1px solid rgba(0, 229, 255, 0.3);
      color: var(--cyan);
      border-radius: 999px;
      margin-left: 6px;
    }

    .nav-actions {
      display: flex;
      align-items: center;
      gap: 10px;
    }

    .status-pill {
      display: flex;
      align-items: center;
      gap: 8px;
      padding: 6px 12px;
      border-radius: 999px;
      font-size: 0.82rem;
      font-weight: 600;
      background: rgba(0, 230, 118, 0.1);
      border: 1px solid rgba(0, 230, 118, 0.3);
      color: var(--green);
    }

    .status-dot {
      width: 8px;
      height: 8px;
      border-radius: 50%;
      background: var(--green);
      box-shadow: 0 0 8px var(--green);
      animation: pulse 2s infinite;
    }

    @keyframes pulse {
      0% { transform: scale(0.95); opacity: 0.8; }
      50% { transform: scale(1.3); opacity: 1; }
      100% { transform: scale(0.95); opacity: 0.8; }
    }

    .btn {
      display: inline-flex;
      align-items: center;
      gap: 7px;
      padding: 7px 14px;
      border-radius: 8px;
      font-size: 0.85rem;
      font-weight: 600;
      font-family: inherit;
      cursor: pointer;
      transition: all 0.2s ease;
      border: 1px solid transparent;
      outline: none;
    }

    .btn-secondary {
      background: rgba(255, 255, 255, 0.06);
      color: var(--text);
      border-color: var(--border);
    }

    .btn-secondary:hover {
      background: rgba(255, 255, 255, 0.12);
      border-color: rgba(255, 255, 255, 0.2);
    }

    .btn-primary {
      background: linear-gradient(135deg, var(--cyan), var(--blue));
      color: #000;
      font-weight: 700;
      box-shadow: 0 4px 14px rgba(0, 229, 255, 0.3);
    }

    .btn-primary:hover {
      transform: translateY(-1px);
      box-shadow: 0 6px 20px rgba(0, 229, 255, 0.5);
    }

    /* MAIN APP LAYOUT */
    .app-container {
      display: flex;
      flex: 1;
      height: calc(100vh - 64px);
    }

    /* SIDEBAR */
    .sidebar {
      width: var(--sidebar-width);
      border-right: 1px solid var(--border);
      background: var(--card-bg);
      display: flex;
      flex-direction: column;
      flex-shrink: 0;
    }

    .sidebar-header {
      padding: 18px 18px 14px 18px;
      border-bottom: 1px solid var(--border);
    }

    .search-box {
      position: relative;
      margin-top: 10px;
    }

    .search-box input {
      width: 100%;
      background: rgba(255, 255, 255, 0.04);
      border: 1px solid var(--border);
      padding: 9px 14px 9px 36px;
      border-radius: 8px;
      color: var(--text);
      font-family: inherit;
      font-size: 0.85rem;
      outline: none;
      transition: all 0.2s;
    }

    .search-box input:focus {
      border-color: var(--cyan);
      box-shadow: 0 0 10px rgba(0, 229, 255, 0.2);
    }

    .search-box svg {
      position: absolute;
      left: 11px;
      top: 50%;
      transform: translateY(-50%);
      width: 15px;
      height: 15px;
      fill: var(--text-muted);
    }

    .tag-filter-bar {
      display: flex;
      gap: 6px;
      overflow-x: auto;
      padding: 8px 0 2px 0;
      scrollbar-width: none;
    }
    .tag-filter-bar::-webkit-scrollbar {
      display: none;
    }
    .tag-chip {
      font-size: 0.72rem;
      padding: 3px 9px;
      border-radius: 999px;
      background: rgba(255,255,255,0.06);
      border: 1px solid var(--border);
      color: var(--text-muted);
      cursor: pointer;
      white-space: nowrap;
      transition: all 0.2s;
    }
    .tag-chip:hover {
      background: rgba(255,255,255,0.12);
      color: #fff;
    }
    .tag-chip.active {
      background: rgba(99, 102, 241, 0.25);
      border-color: rgba(99, 102, 241, 0.6);
      color: #818cf8;
      font-weight: 600;
    }
    .badge-tag {
      font-size: 0.68rem;
      padding: 2px 6px;
      border-radius: 6px;
      background: rgba(99, 102, 241, 0.15);
      border: 1px solid rgba(99, 102, 241, 0.35);
      color: #a5b4fc;
      font-weight: 600;
      display: inline-flex;
      align-items: center;
      gap: 3px;
      width: fit-content;
    }
    .detail-tag-wrapper {
      display: inline-flex;
      align-items: center;
      gap: 8px;
    }
    .btn-tag-edit {
      font-size: 0.72rem;
      padding: 3px 8px;
      border-radius: 6px;
      background: rgba(255, 255, 255, 0.08);
      border: 1px solid var(--border);
      color: var(--text-muted);
      cursor: pointer;
      display: inline-flex;
      align-items: center;
      gap: 4px;
      transition: all 0.2s;
    }
    .btn-tag-edit:hover {
      background: rgba(255, 255, 255, 0.16);
      color: #fff;
    }

    .ai-badge-label {
      font-size: 0.65rem;
      padding: 1px 6px;
      border-radius: 4px;
      font-weight: 700;
      font-family: 'JetBrains Mono', monospace;
      display: inline-flex;
      align-items: center;
      gap: 3px;
    }
    .ai-badge-label.moving {
      background: rgba(0, 230, 118, 0.15);
      border: 1px solid rgba(0, 230, 118, 0.4);
      color: #00E676;
    }
    .ai-badge-label.still {
      background: rgba(148, 163, 184, 0.12);
      border: 1px solid rgba(148, 163, 184, 0.3);
      color: #94A3B8;
    }
    .ai-label-pill {
      display: inline-flex;
      align-items: center;
      gap: 6px;
      padding: 3px 9px;
      border-radius: 6px;
      font-size: 0.74rem;
      font-weight: 600;
      cursor: pointer;
      user-select: none;
      transition: all 0.2s;
    }
    .ai-label-pill.moving {
      background: rgba(0, 230, 118, 0.14);
      border: 1px solid rgba(0, 230, 118, 0.45);
      color: #00E676;
    }
    .ai-label-pill.moving:hover {
      background: rgba(0, 230, 118, 0.24);
      border-color: #00E676;
    }
    .ai-label-pill.still {
      background: rgba(148, 163, 184, 0.12);
      border: 1px solid rgba(148, 163, 184, 0.3);
      color: #CBD5E1;
    }
    .ai-label-pill.still:hover {
      background: rgba(148, 163, 184, 0.22);
      border-color: #CBD5E1;
    }
    .btn-export-all {
      width: 100%;
      margin-top: 10px;
      justify-content: center;
      font-size: 0.78rem;
      padding: 7px 12px;
      background: rgba(0, 229, 255, 0.08);
      border: 1px solid rgba(0, 229, 255, 0.3);
      color: var(--cyan);
    }
    .btn-export-all:hover {
      background: rgba(0, 229, 255, 0.18);
      border-color: var(--cyan);
      color: #fff;
    }
    .toast-msg {
      position: fixed;
      bottom: 24px;
      right: 24px;
      background: #171D2D;
      border: 1px solid var(--cyan);
      color: #F1F5F9;
      padding: 10px 18px;
      border-radius: 8px;
      box-shadow: 0 8px 24px rgba(0,0,0,0.5);
      font-size: 0.85rem;
      font-weight: 500;
      z-index: 9999;
      opacity: 0;
      transform: translateY(10px);
      transition: all 0.25s ease;
      pointer-events: none;
      display: flex;
      align-items: center;
      gap: 8px;
    }
    .toast-msg.show {
      opacity: 1;
      transform: translateY(0);
    }

    .session-list {
      flex: 1;
      overflow-y: auto;
      padding: 12px;
      display: flex;
      flex-direction: column;
      gap: 8px;
    }

    .session-card {
      background: rgba(255, 255, 255, 0.02);
      border: 1px solid var(--border);
      border-radius: 10px;
      padding: 14px;
      cursor: pointer;
      transition: all 0.2s ease;
      position: relative;
    }

    .session-card:hover {
      background: var(--card-hover);
      border-color: rgba(0, 229, 255, 0.4);
      transform: translateX(2px);
    }

    .session-card.active {
      background: rgba(0, 229, 255, 0.08);
      border-color: var(--cyan);
      box-shadow: 0 0 16px rgba(0, 229, 255, 0.15);
    }

    .session-card.active::before {
      content: '';
      position: absolute;
      left: 0;
      top: 12px;
      bottom: 12px;
      width: 3.5px;
      background: var(--cyan);
      border-radius: 0 4px 4px 0;
    }

    .card-top {
      display: flex;
      align-items: center;
      justify-content: space-between;
      margin-bottom: 6px;
    }

    .card-title {
      font-weight: 700;
      font-size: 0.95rem;
      color: #fff;
    }

    .card-date {
      font-size: 0.76rem;
      color: var(--text-muted);
    }

    .card-metrics {
      display: flex;
      gap: 12px;
      font-size: 0.78rem;
      color: var(--text-muted);
      margin-top: 8px;
    }

    .metric-badge {
      display: flex;
      align-items: center;
      gap: 4px;
      background: rgba(255, 255, 255, 0.04);
      padding: 3px 7px;
      border-radius: 6px;
    }

    .metric-badge.cyan { color: var(--cyan); }
    .metric-badge.green { color: var(--green); }

    /* CONTENT VIEW */
    .main-content {
      flex: 1;
      overflow-y: auto;
      padding: 24px;
      display: flex;
      flex-direction: column;
      gap: 20px;
    }

    /* TOP STATS */
    .session-header {
      display: flex;
      align-items: center;
      justify-content: space-between;
      background: var(--card-bg);
      border: 1px solid var(--border);
      border-radius: 14px;
      padding: 20px 24px;
    }

    .session-info h2 {
      font-size: 1.45rem;
      font-weight: 800;
      margin-bottom: 4px;
    }

    .session-info p {
      font-size: 0.85rem;
      color: var(--text-muted);
    }

    .session-actions {
      display: flex;
      gap: 10px;
    }

    /* KPI CARDS */
    .kpi-grid {
      display: grid;
      grid-template-columns: repeat(4, 1fr);
      gap: 16px;
    }

    .kpi-card {
      background: var(--card-bg);
      border: 1px solid var(--border);
      border-radius: 12px;
      padding: 18px;
      display: flex;
      flex-direction: column;
      gap: 6px;
      position: relative;
      overflow: hidden;
    }

    .kpi-card::after {
      content: '';
      position: absolute;
      top: 0;
      left: 0;
      right: 0;
      height: 2px;
      background: linear-gradient(90deg, transparent, var(--accent, var(--cyan)), transparent);
    }

    .kpi-label {
      font-size: 0.8rem;
      font-weight: 600;
      text-transform: uppercase;
      letter-spacing: 0.03em;
      color: var(--text-muted);
      display: flex;
      align-items: center;
      gap: 6px;
    }

    .kpi-value {
      font-size: 1.65rem;
      font-weight: 800;
      font-family: 'JetBrains Mono', monospace;
      color: #fff;
    }

    .kpi-sub {
      font-size: 0.76rem;
      color: var(--text-muted);
    }

    /* CHART SECTION */
    .chart-container {
      background: var(--card-bg);
      border: 1px solid var(--border);
      border-radius: 14px;
      padding: 20px;
      display: flex;
      flex-direction: column;
      gap: 16px;
    }

    .chart-toolbar {
      display: flex;
      align-items: center;
      justify-content: space-between;
      flex-wrap: wrap;
      gap: 12px;
    }

    .chart-toolbar-title {
      font-size: 1.1rem;
      font-weight: 700;
    }

    .chart-toggles {
      display: flex;
      align-items: center;
      gap: 8px;
    }

    .toggle-chip {
      background: rgba(255, 255, 255, 0.05);
      border: 1px solid var(--border);
      padding: 5px 12px;
      border-radius: 999px;
      font-size: 0.78rem;
      font-weight: 600;
      cursor: pointer;
      transition: all 0.2s;
      color: var(--text-muted);
      user-select: none;
    }

    .toggle-chip.active {
      background: rgba(0, 229, 255, 0.15);
      border-color: var(--cyan);
      color: var(--cyan);
    }

    #mainChart {
      width: 100%;
      height: 480px;
    }

    /* SECONDARY STATS (BOTTOM) */
    .bottom-grid {
      display: grid;
      grid-template-columns: 1fr;
      gap: 16px;
    }

    .sub-card {
      background: var(--card-bg);
      border: 1px solid var(--border);
      border-radius: 14px;
      padding: 20px;
      display: flex;
      flex-direction: column;
    }

    .sub-card h3 {
      font-size: 1.05rem;
      font-weight: 700;
      margin-bottom: 14px;
    }

    .breakdown-table {
      width: 100%;
      border-collapse: collapse;
      margin-top: 8px;
    }

    .breakdown-table th, .breakdown-table td {
      padding: 10px 14px;
      text-align: left;
      font-size: 0.85rem;
      border-bottom: 1px solid var(--border);
    }

    .breakdown-table th {
      color: var(--text-muted);
      font-weight: 600;
    }

    .breakdown-table td:last-child {
      text-align: right;
      font-family: 'JetBrains Mono', monospace;
      font-weight: 600;
    }

    /* EMPTY & LOADING */
    .empty-state {
      flex: 1;
      display: flex;
      flex-direction: column;
      align-items: center;
      justify-content: center;
      padding: 60px 20px;
      color: var(--text-muted);
      gap: 14px;
      text-align: center;
    }

    .empty-state svg {
      width: 64px;
      height: 64px;
      fill: var(--text-muted);
      opacity: 0.4;
    }

    /* SCROLLBAR */
    ::-webkit-scrollbar {
      width: 6px;
      height: 6px;
    }
    ::-webkit-scrollbar-track {
      background: transparent;
    }
    ::-webkit-scrollbar-thumb {
      background: #252D42;
      border-radius: 3px;
    }
    ::-webkit-scrollbar-thumb:hover {
      background: #374260;
    }

    @media (max-width: 1024px) {
      .app-container {
        flex-direction: column;
        height: auto;
      }
      .sidebar {
        width: 100%;
        height: 280px;
      }
      .kpi-grid {
        grid-template-columns: repeat(2, 1fr);
      }
      .bottom-grid {
        grid-template-columns: 1fr;
      }
    }
  </style>
</head>
<body>

  <!-- TOP HEADER -->
  <header>
    <div class="brand">
      <div class="brand-logo">
        <svg viewBox="0 0 24 24"><path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm-1 14h2v2h-2zm0-10h2v8h-2z"/></svg>
      </div>
      <div>
        <span class="brand-title">Motion Sensor</span>
        <span class="brand-badge">Web Live</span>
      </div>
    </div>

    <div class="nav-actions">
      <div class="status-pill">
        <div class="status-dot"></div>
        <span id="connectionStatus">Đã kết nối điện thoại</span>
      </div>
      <input type="file" id="fileInput" accept=".json" style="display:none" onchange="handleFileSelect(event)">
      <button class="btn btn-secondary" onclick="document.getElementById('fileInput').click()">
        <svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor"><path d="M19.35 10.04C18.67 6.59 15.64 4 12 4 9.11 4 6.6 5.64 5.35 8.04 2.34 8.36 0 10.91 0 14c0 3.31 2.69 6 6 6h13c2.76 0 5-2.24 5-5 0-2.64-2.05-4.78-4.65-4.96zM14 13v4h-4v-4H7l5-5 5 5h-3z"/></svg>
        Nhập JSON
      </button>
      <button class="btn btn-secondary" onclick="loadSessions()">
        <svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor"><path d="M17.65 6.35C16.2 4.9 14.21 4 12 4c-4.42 0-7.99 3.58-7.99 8s3.57 8 7.99 8c3.73 0 6.84-2.55 7.73-6h-2.08c-.82 2.33-3.04 4-5.65 4-3.31 0-6-2.69-6-6s2.69-6 6-6c1.66 0 3.14.69 4.22 1.78L13 11h7V4l-2.35 2.35z"/></svg>
        Làm mới
      </button>
    </div>
  </header>

  <!-- APP BODY -->
  <div class="app-container">
    
    <!-- LEFT SIDEBAR -->
    <aside class="sidebar">
      <div class="sidebar-header">
        <div style="display:flex; justify-content:space-between; align-items:center;">
          <span style="font-weight:700; font-size:0.95rem;">Lịch sử phiên ghi</span>
          <span id="sessionCountBadge" style="font-size:0.75rem; color:var(--text-muted); background:rgba(255,255,255,0.06); padding:2px 8px; border-radius:999px;">0 phiên</span>
        </div>
        <div class="search-box">
          <svg viewBox="0 0 24 24"><path d="M15.5 14h-.79l-.28-.27C15.41 12.59 16 11.11 16 9.5 16 5.91 13.09 3 9.5 3S3 5.91 3 9.5 5.91 16 9.5 16c1.61 0 3.09-.59 4.23-1.57l.27.28v.79l5 4.99L20.49 19l-4.99-5zm-6 0C7.01 14 5 11.99 5 9.5S7.01 5 9.5 5 14 7.01 14 9.5 11.99 14 9.5 14z"/></svg>
          <input type="text" id="searchInput" placeholder="Tìm theo tag, ngày..." oninput="filterSessions()">
        </div>
        <div class="tag-filter-bar" id="tagFilterBar"></div>
        <button class="btn btn-secondary btn-export-all" id="btnExportAll" onclick="exportAllSessionsCSV()" title="Gộp tất cả phiên thành 1 file CSV chuẩn AI với đầy đủ cột session_id, relative_time, magnitude, label, tag">
          <svg width="13" height="13" viewBox="0 0 24 24" fill="currentColor"><path d="M19.35 10.04C18.67 6.59 15.64 4 12 4 9.11 4 6.6 5.64 5.35 8.04 2.34 8.36 0 10.91 0 14c0 3.31 2.69 6 6 6h13c2.76 0 5-2.24 5-5 0-2.64-2.05-4.78-4.65-4.96zM17 13l-5 5-5-5h3V9h4v4h3z"/></svg>
          Xuất toàn bộ Dataset AI (.csv)
        </button>
      </div>

      <div class="session-list" id="sessionList">
        <div class="empty-state">
          <p>Đang tải dữ liệu từ điện thoại...</p>
        </div>
      </div>
    </aside>

    <!-- RIGHT MAIN CONTENT -->
    <main class="main-content" id="mainContent">
      <div class="empty-state" id="emptyPlaceholder">
        <svg viewBox="0 0 24 24"><path d="M19 3H5c-1.1 0-2 .9-2 2v14c0 1.1.9 2 2 2h14c1.1 0 2-.9 2-2V5c0-1.1-.9-2-2-2zm-5 14H7v-2h7v2zm3-4H7v-2h10v2zm0-4H7V7h10v2z"/></svg>
        <h3>Chưa có phiên đo nào được chọn</h3>
        <p style="max-width:400px; font-size:0.9rem;">Chọn một phiên đo từ điện thoại bên trái, kéo thả file JSON vào bất kỳ đâu trên màn hình, hoặc trải nghiệm dữ liệu mẫu.</p>
        <div style="display:flex; gap:12px; margin-top:14px;">
          <button class="btn btn-primary" onclick="loadDemoSession()">Xem dữ liệu mẫu</button>
          <button class="btn btn-secondary" onclick="document.getElementById('fileInput').click()">Chọn file JSON từ máy</button>
        </div>
      </div>

      <div id="sessionDetailArea" style="display:none; flex-direction:column; gap:20px;">
        <!-- SESSION HEADER -->
        <div class="session-header">
          <div class="session-info">
            <div style="display:flex; align-items:center; gap:10px; flex-wrap:wrap;">
              <h2 id="sessionTitle" style="margin:0;">Phiên ghi nhận</h2>
              <div id="sessionTagBadgeContainer"></div>
            </div>
            <p id="sessionSubtitle">Bắt đầu: ...</p>
          </div>
          <div class="session-actions">
            <button class="btn btn-secondary" onclick="exportJSON()" title="Xuất file JSON nguyên bản">
              <svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor"><path d="M19 9h-4V3H9v6H5l7 7 7-7zM5 18v2h14v-2H5z"/></svg>
              Xuất JSON
            </button>
            <button class="btn btn-primary" onclick="exportCSV()" title="Xuất CSV chuẩn AI Training (relative_time, magnitude, label, tag)">
              <svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor"><path d="M14 2H6c-1.1 0-1.99.9-1.99 2L4 20c0 1.1.89 2 1.99 2H18c1.1 0 2-.9 2-2V8l-6-6zm2 16H8v-2h8v2zm0-4H8v-2h8v2zm-3-5V3.5L18.5 9H13z"/></svg>
              Xuất CSV (AI Training)
            </button>
          </div>
        </div>

        <!-- 4 KPI CARDS -->
        <div class="kpi-grid">
          <div class="kpi-card" style="--accent: var(--cyan)">
            <div class="kpi-label">⏱️ Thời lượng</div>
            <div class="kpi-value" id="kpiDuration">00:00</div>
            <div class="kpi-sub" id="kpiDurationMs">0 ms</div>
          </div>
          <div class="kpi-card" style="--accent: var(--blue)">
            <div class="kpi-label">📊 Tổng số mẫu</div>
            <div class="kpi-value" id="kpiSamples">0</div>
            <div class="kpi-sub" id="kpiSamplingRate">Tần số ~50Hz</div>
          </div>
          <div class="kpi-card" style="--accent: var(--green)">
            <div class="kpi-label">⚡ Gia tốc trung bình</div>
            <div class="kpi-value" id="kpiAvgMag">0.00</div>
            <div class="kpi-sub">m/s²</div>
          </div>
          <div class="kpi-card" style="--accent: var(--orange)">
            <div class="kpi-label">🎯 Gia tốc đỉnh (Peak)</div>
            <div class="kpi-value" id="kpiPeakMag">0.00</div>
            <div class="kpi-sub">m/s²</div>
          </div>
        </div>

        <!-- MAIN CHART -->
        <div class="chart-container">
          <div class="chart-toolbar">
            <span class="chart-toolbar-title">Biểu đồ gia tốc chi tiết (m/s²)</span>
            <div class="chart-toggles">
              <span class="toggle-chip active" id="chipDots" onclick="toggleDots()">Điểm chấm (dots)</span>
              <span class="toggle-chip active" id="chipAvg" onclick="toggleAvg()">Đường TB (avg)</span>
              <span class="toggle-chip active" id="chipThresholds" onclick="toggleThresholds()">Ngưỡng Min/Max</span>
              <button class="btn btn-secondary" style="padding:4px 10px; font-size:0.78rem;" onclick="resetChartZoom()">Đặt lại 1x</button>
            </div>
          </div>
          <div id="mainChart"></div>
        </div>

        <!-- BOTTOM STATS -->
        <div class="bottom-grid">
          <div class="sub-card">
            <h3>Thống kê phân vị & Biên độ gia tốc</h3>
            <table class="breakdown-table">
              <thead>
                <tr>
                  <th>Dải gia tốc</th>
                  <th>Mức độ</th>
                  <th>Số mẫu</th>
                  <th>Tỷ lệ</th>
                </tr>
              </thead>
              <tbody id="distributionTableBody">
                <!-- Sẽ chèn bằng JS -->
              </tbody>
            </table>
          </div>
        </div>
      </div>
    </main>
  </div>

  <script>
    let allSessions = [];
    let currentSession = null;
    let currentDataPoints = [];
    let mainChartInstance = null;
    let manualSessionLabels = {};

    function removeDiacritics(str) {
      if (!str) return '';
      return str.normalize('NFD')
        .replace(/[\u0300-\u036f]/g, '')
        .replace(/đ/g, 'd')
        .replace(/Đ/g, 'D')
        .toLowerCase()
        .trim();
    }

    const STILL_KEYWORDS = [
      'khong di chuyen',
      'dung yen',
      'de ban',
      'dat ban',
      'de tren ban',
      'dat tren ban',
      'tinh',
      'ngoi yen',
      'ngoi',
      'still',
      'stop',
      'rest',
      'bat dong',
      'khong chuyen dong',
      'dung',
      'nam yen'
    ];

    const MOVING_KEYWORDS = [
      'cam tren tay',
      'cam tay',
      'di cham',
      'di bo',
      'walk',
      'chay',
      'run',
      'jogging',
      'di chuyen',
      'moving',
      'motion',
      'bo tui',
      'tui quan',
      'xe may',
      'oto',
      'xe',
      'bike',
      'car',
      'di lai',
      'buoc chan',
      'hoat dong'
    ];

    function determineSessionLabel(session) {
      if (!session) return 0;
      if (manualSessionLabels[session.id] !== undefined) {
        return manualSessionLabels[session.id];
      }
      const tag = (session.label || '').trim();
      if (tag) {
        const norm = removeDiacritics(tag);
        for (const kw of STILL_KEYWORDS) {
          if (norm.includes(kw)) return 0;
        }
        for (const kw of MOVING_KEYWORDS) {
          if (norm.includes(kw)) return 1;
        }
      }
      const pct = Number(session.motion_percentage || 0);
      return pct >= 50.0 ? 1 : 0;
    }

    function slugifyTag(tag) {
      if (!tag) return '';
      return removeDiacritics(tag)
        .replace(/[^a-z0-9]+/g, '_')
        .replace(/^_+|_+$/g, '');
    }

    function toggleCurrentSessionLabel() {
      if (!currentSession) return;
      const cur = determineSessionLabel(currentSession);
      const next = cur === 1 ? 0 : 1;
      manualSessionLabels[currentSession.id] = next;
      renderSessionDetails();
      renderSessionList(getFilteredSessions());
      showToast(`Đã đổi nhãn AI phiên #${currentSession.id}: [${next}] ${next === 1 ? 'Di chuyển' : 'Đứng yên'}`);
    }

    function showToast(msg) {
      const el = document.getElementById('toastMsg');
      if (!el) return;
      el.textContent = msg;
      el.classList.add('show');
      clearTimeout(window._toastTimeout);
      window._toastTimeout = setTimeout(() => {
        el.classList.remove('show');
      }, 3500);
    }

    // Chart options state
    let showDots = true;
    let showAvg = true;
    let showThresholds = true;
    let zoomStart = 0;
    let zoomEnd = 100;

    document.addEventListener('DOMContentLoaded', () => {
      initCharts();
      loadSessions();
      setupFileDrop();
      window.addEventListener('resize', () => {
        mainChartInstance?.resize();
      });
    });

    function initCharts() {
      const chartDom = document.getElementById('mainChart');
      mainChartInstance = echarts.init(chartDom, 'dark', { renderer: 'canvas' });
      setupSmoothWheelZoom(chartDom);

      if (window.ResizeObserver) {
        const ro = new ResizeObserver(() => {
          mainChartInstance?.resize();
        });
        const mainContent = document.getElementById('mainContent');
        if (mainContent) ro.observe(mainContent);
        if (chartDom) ro.observe(chartDom);
      }
    }

    function setupSmoothWheelZoom(chartDom) {
      mainChartInstance.on('dataZoom', (params) => {
        let s, e;
        if (params.batch && params.batch.length > 0) {
          s = params.batch[0].start;
          e = params.batch[0].end;
        } else if (params.start !== undefined && params.end !== undefined) {
          s = params.start;
          e = params.end;
        }
        if (s !== undefined && e !== undefined) {
          zoomStart = s;
          zoomEnd = e;
        }
      });

      function onWheel(evt) {
        evt.preventDefault();
        evt.stopPropagation();
        if (!mainChartInstance) return;

        const rect = chartDom.getBoundingClientRect();
        const mouseX = evt.clientX - rect.left;
        const gridLeft = rect.width * 0.02;
        const gridWidth = rect.width * 0.95;
        let ratio = (mouseX - gridLeft) / gridWidth;
        if (ratio < 0) ratio = 0;
        if (ratio > 1) ratio = 1;

        // Cuộn lên (deltaY < 0) = Phóng to (Zoom In)
        // Cuộn xuống (deltaY > 0) = Thu nhỏ (Zoom Out)
        const isZoomIn = evt.deltaY < 0;
        let step = Math.min(Math.abs(evt.deltaY) * 0.015, 2.5);
        if (!isZoomIn) step = -step;

        const currentSpan = zoomEnd - zoomStart;
        if (currentSpan <= 0.3 && isZoomIn) return;

        let newStart = zoomStart + step * ratio;
        let newEnd = zoomEnd - step * (1 - ratio);

        if (newEnd - newStart < 0.3) {
          const mid = (zoomStart + zoomEnd) / 2;
          newStart = mid - 0.15;
          newEnd = mid + 0.15;
        }

        if (newStart < 0) {
          newEnd = Math.min(100, newEnd - newStart);
          newStart = 0;
        }
        if (newEnd > 100) {
          newStart = Math.max(0, newStart - (newEnd - 100));
          newEnd = 100;
        }

        zoomStart = Math.max(0, Math.min(100, newStart));
        zoomEnd = Math.max(0, Math.min(100, newEnd));

        mainChartInstance.dispatchAction({
          type: 'dataZoom',
          start: zoomStart,
          end: zoomEnd
        });
      }

      // Gắn sự kiện ở Capture phase để bắt sự kiện trước khi canvas nội bộ của ECharts nuốt sự kiện
      chartDom.addEventListener('wheel', onWheel, { capture: true, passive: false });
    }

    function setupFileDrop() {
      window.addEventListener('dragover', (e) => e.preventDefault());
      window.addEventListener('drop', (e) => {
        e.preventDefault();
        if (e.dataTransfer.files && e.dataTransfer.files.length) {
          readFile(e.dataTransfer.files[0]);
        }
      });
    }

    function handleFileSelect(e) {
      if (e.target.files && e.target.files.length) {
        readFile(e.target.files[0]);
      }
    }

    function readFile(file) {
      const reader = new FileReader();
      reader.onload = (evt) => {
        try {
          const json = JSON.parse(evt.target.result);
          if (json.session && json.dataPoints) {
            allSessions.unshift(json.session);
            currentSession = json.session;
            currentDataPoints = json.dataPoints;
            renderSessionList(allSessions);
            renderSessionDetails();
          } else {
            alert('File JSON không đúng định dạng phiên ghi!');
          }
        } catch (err) {
          alert('Không thể đọc file: ' + err.message);
        }
      };
      reader.readAsText(file);
    }

    function loadDemoSession() {
      const now = new Date();
      const demoSession = {
        id: 999,
        label: 'Mẫu thử: Đi bộ túi quần (Demo)',
        start_time: new Date(now.getTime() - 25000).toISOString(),
        end_time: now.toISOString(),
        duration_ms: 25000,
        total_samples: 250,
        avg_magnitude: 2.18,
        motion_percentage: 68.0
      };

      const demoPoints = [];
      for (let i = 0; i < 250; i++) {
        const t = +(i * 0.1).toFixed(2);
        let mag = 0.35 + Math.sin(i * 0.38) * 1.9 + Math.random() * 0.4;
        if (mag < 0.1) mag = 0.12;
        if (i >= 60 && i <= 90) mag = 0.15 + Math.random() * 0.25; // still phase
        if (i === 150 || i === 151) mag = 9.4; // spike
        const isMoving = mag >= 1.0;
        demoPoints.push({
          relative_time: t,
          magnitude: +mag.toFixed(3),
          is_moving: isMoving,
          category: mag > 8.0 ? 'spike' : (isMoving ? 'motion' : 'still')
        });
      }

      allSessions.unshift(demoSession);
      currentSession = demoSession;
      currentDataPoints = demoPoints;
      renderTagChips();
      renderSessionList(allSessions);
      renderSessionDetails();
    }

    async function loadSessions() {
      try {
        const res = await fetch('/api/sessions');
        if (!res.ok) throw new Error('Failed to fetch');
        allSessions = await res.json();
        renderTagChips();
        renderSessionList(allSessions);
        
        // Auto select first session
        if (allSessions.length > 0 && !currentSession) {
          selectSession(allSessions[0].id);
        } else if (allSessions.length === 0) {
          document.getElementById('sessionList').innerHTML = `
            <div class="empty-state">
              <p>Chưa có phiên đo nào trên điện thoại.</p>
              <button class="btn btn-secondary" style="margin-top:10px" onclick="loadDemoSession()">Xem dữ liệu mẫu</button>
            </div>
          `;
        }
      } catch (err) {
        console.warn('Lỗi kết nối API điện thoại (Chế độ xem ngoại tuyến):', err);
        document.getElementById('connectionStatus').textContent = 'Ngoại tuyến (Hỗ trợ kéo thả JSON)';
        document.getElementById('connectionStatus').parentElement.style.borderColor = 'rgba(255,255,255,0.2)';
        document.getElementById('connectionStatus').parentElement.style.color = 'var(--text-muted)';
        document.querySelector('.status-dot').style.background = 'var(--text-muted)';
        document.querySelector('.status-dot').style.boxShadow = 'none';
        document.querySelector('.status-dot').style.animation = 'none';

        if (allSessions.length === 0) {
          document.getElementById('sessionList').innerHTML = `
            <div class="empty-state">
              <p>Chưa có phiên đo nào.</p>
              <button class="btn btn-primary" style="margin-top:10px; font-size:0.8rem;" onclick="loadDemoSession()">Xem dữ liệu mẫu</button>
            </div>
          `;
        }
      }
    }

    let selectedTag = null;

    function renderTagChips() {
      const container = document.getElementById('tagFilterBar');
      if (!container) return;

      const tags = [...new Set(allSessions.map(s => (s.label || '').trim()).filter(Boolean))].sort();
      if (tags.length === 0) {
        container.innerHTML = '';
        container.style.display = 'none';
        return;
      }
      container.style.display = 'flex';

      let html = `<div class="tag-chip ${selectedTag === null ? 'active' : ''}" onclick="selectTagFilter(null)">Tất cả</div>`;
      tags.forEach(tag => {
        const isAct = selectedTag === tag;
        html += `<div class="tag-chip ${isAct ? 'active' : ''}" onclick="selectTagFilter('${tag.replace(/'/g, "\\'")}')">#${tag}</div>`;
      });
      container.innerHTML = html;
    }

    function selectTagFilter(tag) {
      selectedTag = tag;
      renderTagChips();
      filterSessions();
    }

    function renderSessionList(sessions) {
      document.getElementById('sessionCountBadge').textContent = `${sessions.length} phiên`;
      const container = document.getElementById('sessionList');
      if (sessions.length === 0) {
        container.innerHTML = '<div class="empty-state"><p>Không tìm thấy phiên ghi phù hợp.</p></div>';
        return;
      }

      container.innerHTML = sessions.map(s => {
        const isActive = currentSession && currentSession.id === s.id;
        const durationSec = Math.round(s.duration_ms / 1000);
        const mins = Math.floor(durationSec / 60);
        const secs = durationSec % 60;
        const timeStr = `${String(mins).padStart(2, '0')}:${String(secs).padStart(2, '0')}`;
        
        const d = new Date(s.start_time);
        const dateStr = `${d.getDate().toString().padStart(2,'0')}/${(d.getMonth()+1).toString().padStart(2,'0')} ${d.getHours().toString().padStart(2,'0')}:${d.getMinutes().toString().padStart(2,'0')}`;
        const hasTag = s.label && s.label.trim();
        const tagBadge = hasTag ? `<span class="badge-tag">#${s.label.trim()}</span>` : '';
        const aiLabel = determineSessionLabel(s);
        const aiBadge = aiLabel === 1
          ? '<span class="ai-badge-label moving" title="Nhãn AI Ground Truth: 1 (Di chuyển)">[1] Di chuyển</span>'
          : '<span class="ai-badge-label still" title="Nhãn AI Ground Truth: 0 (Đứng yên)">[0] Đứng yên</span>';

        return `
          <div class="session-card ${isActive ? 'active' : ''}" onclick="selectSession(${s.id})">
            <div class="card-top">
              <div style="display:flex; flex-direction:column; gap:4px; overflow:hidden;">
                <span class="card-title">${hasTag ? s.label.trim() : `Phiên #${s.id}`}</span>
                ${tagBadge}
              </div>
              <span class="card-date">${dateStr}</span>
            </div>
            <div class="card-metrics">
              <span class="metric-badge cyan">⏱️ ${timeStr}</span>
              <span class="metric-badge green">⚡ ${Number(s.avg_magnitude).toFixed(2)} m/s²</span>
              ${aiBadge}
            </div>
          </div>
        `;
      }).join('');
    }

    function getFilteredSessions() {
      const q = document.getElementById('searchInput') ? document.getElementById('searchInput').value.toLowerCase().trim() : '';
      return allSessions.filter(s => {
        // Tag chip match
        if (selectedTag) {
          const sLabel = (s.label || '').trim().toLowerCase();
          if (sLabel !== selectedTag.toLowerCase()) return false;
        }
        // Search text match
        if (q) {
          const title = (s.label || `Phiên #${s.id}`).toLowerCase();
          const date = (s.start_time || '').toLowerCase();
          const idStr = String(s.id);
          if (!title.includes(q) && !date.includes(q) && !idStr.includes(q)) {
            return false;
          }
        }
        return true;
      });
    }

    function filterSessions() {
      renderSessionList(getFilteredSessions());
    }

    async function editSessionTag() {
      if (!currentSession || !currentSession.id) return;
      const currentTag = currentSession.label || '';
      const newTag = prompt('Nhập tag cho phiên ghi (để trống để xóa):', currentTag);
      if (newTag === null) return; // user cancelled

      const cleanTag = newTag.trim();
      try {
        await fetch(`/api/sessions/${currentSession.id}/label`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ label: cleanTag || null })
        });
      } catch (err) {
        console.warn('Cập nhật local/offline tag:', err);
      }

      currentSession.label = cleanTag || null;
      const idx = allSessions.findIndex(s => s.id === currentSession.id);
      if (idx !== -1) {
        allSessions[idx].label = cleanTag || null;
      }
      renderTagChips();
      filterSessions();
      renderSessionDetails();
    }

    async function selectSession(sessionId) {
      // If it's a demo or loaded session without API call
      const existing = allSessions.find(s => s.id === sessionId);
      if (existing && existing.id === 999 && currentDataPoints.length) {
        currentSession = existing;
        renderSessionList(allSessions);
        renderSessionDetails();
        return;
      }

      try {
        const res = await fetch(`/api/sessions/${sessionId}`);
        if (!res.ok) throw new Error('Failed to fetch session detail');
        const data = await res.json();
        
        currentSession = data.session;
        currentDataPoints = data.dataPoints || [];

        renderSessionList(allSessions);
        renderSessionDetails();
      } catch (err) {
        console.error('Lỗi tải chi tiết phiên:', err);
      }
    }

    function renderSessionDetails() {
      if (!currentSession) return;

      document.getElementById('emptyPlaceholder').style.display = 'none';
      const detailArea = document.getElementById('sessionDetailArea');
      detailArea.style.display = 'flex';

      // Header
      const hasTag = currentSession.label && currentSession.label.trim();
      const title = hasTag ? currentSession.label.trim() : `Phiên ghi #${currentSession.id}`;
      document.getElementById('sessionTitle').textContent = title;

      const tagContainer = document.getElementById('sessionTagBadgeContainer');
      if (tagContainer) {
        const curLabel = determineSessionLabel(currentSession);
        tagContainer.innerHTML = `
          <div class="detail-tag-wrapper">
            ${hasTag ? `<span class="badge-tag" style="font-size:0.75rem; padding:3px 9px;">#${currentSession.label.trim()}</span>` : '<span style="font-size:0.75rem; color:var(--text-muted); font-style:italic;">Chưa có tag</span>'}
            <button class="btn-tag-edit" onclick="editSessionTag()">
              <svg width="11" height="11" viewBox="0 0 24 24" fill="currentColor"><path d="M3 17.25V21h3.75L17.81 9.94l-3.75-3.75L3 17.25zM20.71 7.04c.39-.39.39-1.02 0-1.41l-2.34-2.34c-.39-.39-1.02-.39-1.41 0l-1.83 1.83 3.75 3.75 1.83-1.83z"/></svg>
              ${hasTag ? 'Đổi tag' : 'Thêm tag'}
            </button>
            <div class="ai-label-pill ${curLabel === 1 ? 'moving' : 'still'}" onclick="toggleCurrentSessionLabel()" title="Bấm để chuyển đổi nhãn AI Ground Truth (1: Di chuyển, 0: Đứng yên)">
              <span style="font-weight:700">Nhãn AI:</span> [${curLabel}] ${curLabel === 1 ? 'Di chuyển (Moving)' : 'Đứng yên (Still)'} ⇄
            </div>
          </div>
        `;
      }
      
      const dStart = new Date(currentSession.start_time);
      const dEnd = new Date(currentSession.end_time);
      document.getElementById('sessionSubtitle').textContent = 
        `Bắt đầu: ${dStart.toLocaleTimeString()} • Kết thúc: ${dEnd.toLocaleTimeString()} (${dStart.toLocaleDateString()})`;

      // KPI Cards
      const durationSec = Math.round(currentSession.duration_ms / 1000);
      const mins = Math.floor(durationSec / 60);
      const secs = durationSec % 60;
      document.getElementById('kpiDuration').textContent = `${String(mins).padStart(2, '0')}:${String(secs).padStart(2, '0')}`;
      document.getElementById('kpiDurationMs').textContent = `${currentSession.duration_ms} ms (${durationSec}s)`;
      
      document.getElementById('kpiSamples').textContent = currentSession.total_samples.toLocaleString();
      const rate = durationSec > 0 ? (currentSession.total_samples / durationSec).toFixed(1) : '50';
      document.getElementById('kpiSamplingRate').textContent = `Tốc độ ~${rate} mẫu/giây`;

      document.getElementById('kpiAvgMag').textContent = Number(currentSession.avg_magnitude).toFixed(2);

      // Find peak magnitude
      let peak = 0;
      for (const p of currentDataPoints) {
        if (p.magnitude > peak) peak = p.magnitude;
      }
      document.getElementById('kpiPeakMag').textContent = peak.toFixed(2);

      // Render Charts
      updateMainChart();
      updateDistributionTable();

      // Bắt buộc resize canvas để fill đầy toàn bộ chiều ngang container
      requestAnimationFrame(() => {
        mainChartInstance?.resize();
      });
      setTimeout(() => {
        mainChartInstance?.resize();
      }, 50);
    }

    function updateMainChart() {
      if (!mainChartInstance || !currentDataPoints.length) return;

      const t0 = currentDataPoints[0].relative_time || 0;
      const chartData = currentDataPoints.map(p => [
        Number((p.relative_time - t0).toFixed(2)),
        Number(p.magnitude.toFixed(3))
      ]);
      const maxTime = chartData.length > 0 && chartData[chartData.length - 1][0] > 0
          ? chartData[chartData.length - 1][0]
          : undefined;

      const avgVal = Number(currentSession.avg_magnitude || 0).toFixed(2);

      const markLines = [];
      if (showThresholds) {
        markLines.push({
          yAxis: 1.0,
          name: 'Ngưỡng Min (1.0)',
          lineStyle: { color: '#00E676', type: 'dashed', width: 1.2 },
          label: { formatter: 'Min: 1.0', position: 'end', color: '#00E676' }
        });
        markLines.push({
          yAxis: 8.0,
          name: 'Ngưỡng Max (8.0)',
          lineStyle: { color: '#FF5252', type: 'dashed', width: 1.2 },
          label: { formatter: 'Max: 8.0', position: 'end', color: '#FF5252' }
        });
      }
      if (showAvg) {
        markLines.push({
          yAxis: Number(avgVal),
          name: 'TB',
          lineStyle: { color: '#FFB300', type: 'dashed', width: 1.5 },
          label: { formatter: `TB: ${avgVal}`, position: 'end', color: '#FFB300' }
        });
      }

      const option = {
        backgroundColor: 'transparent',
        tooltip: {
          trigger: 'axis',
          axisPointer: {
            type: 'cross',
            crossStyle: { color: '#00E5FF', width: 1, type: 'dashed' }
          },
          backgroundColor: '#161A29',
          borderColor: '#202738',
          textStyle: { color: '#F1F5F9', fontSize: 12 },
          formatter: (params) => {
            if (!params || !params.length) return '';
            const item = params[0];
            const time = item.value[0];
            const mag = item.value[1];
            return `
              <div style="font-weight:700; margin-bottom:4px; font-size:13px; color:#00E5FF">${mag.toFixed(3)} m/s²</div>
              <div style="font-size:11.5px; color:#94A3B8">Thời gian: +${time.toFixed(2)}s</div>
            `;
          }
        },
        grid: {
          left: '2%',
          right: '3%',
          bottom: '12%',
          top: '8%',
          containLabel: true
        },
        xAxis: {
          type: 'value',
          name: 'Thời gian (s)',
          nameTextStyle: { color: '#94A3B8', fontSize: 11 },
          min: 0,
          max: maxTime,
          axisLine: { lineStyle: { color: '#202738' } },
          splitLine: { lineStyle: { color: 'rgba(255,255,255,0.05)' } },
          axisLabel: { color: '#94A3B8', formatter: '{value}s' }
        },
        yAxis: {
          type: 'value',
          name: 'Độ lớn (m/s²)',
          nameTextStyle: { color: '#94A3B8', fontSize: 11 },
          axisLine: { lineStyle: { color: '#202738' } },
          splitLine: { lineStyle: { color: 'rgba(255,255,255,0.05)' } },
          axisLabel: { color: '#94A3B8' }
        },
        dataZoom: [
          {
            type: 'slider',
            show: true,
            xAxisIndex: [0],
            start: zoomStart,
            end: zoomEnd,
            bottom: '0%',
            height: 24,
            borderColor: 'transparent',
            backgroundColor: 'rgba(255,255,255,0.03)',
            fillerColor: 'rgba(0, 229, 255, 0.15)',
            handleStyle: { color: '#00E5FF' },
            textStyle: { color: '#94A3B8', fontSize: 10 }
          },
          {
            type: 'inside',
            xAxisIndex: [0],
            zoomOnMouseWheel: false,
            moveOnMouseMove: true,
            moveOnMouseWheel: false
          }
        ],
        series: [
          {
            name: 'Gia tốc',
            type: 'line',
            smooth: 0.18,
            symbol: showDots ? 'circle' : 'none',
            symbolSize: 4.5,
            itemStyle: { color: '#00E5FF' },
            lineStyle: {
              width: 2.4,
              color: new echarts.graphic.LinearGradient(0, 0, 1, 0, [
                { offset: 0, color: '#2979FF' },
                { offset: 1, color: '#00E5FF' }
              ])
            },
            areaStyle: {
              color: new echarts.graphic.LinearGradient(0, 0, 0, 1, [
                { offset: 0, color: 'rgba(0, 229, 255, 0.25)' },
                { offset: 1, color: 'rgba(0, 229, 255, 0.0)' }
              ])
            },
            markLine: markLines.length > 0 ? {
              silent: true,
              symbol: 'none',
              data: markLines
            } : undefined,
            data: chartData
          }
        ]
      };

      mainChartInstance.setOption(option, true);
    }

    function updateDistributionTable() {
      if (!currentDataPoints.length) return;

      let c1 = 0;   // < 1.0
      let c2 = 0;   // 1.0 - 4.0
      let c3 = 0;   // 4.0 - 8.0
      let c4 = 0;   // > 8.0

      for (const p of currentDataPoints) {
        const m = p.magnitude;
        if (m < 1.0) c1++;
        else if (m < 4.0) c2++;
        else if (m <= 8.0) c3++;
        else c4++;
      }

      const total = currentDataPoints.length;
      const pct = (c) => ((c / total) * 100).toFixed(1) + '%';

      const tbody = document.getElementById('distributionTableBody');
      tbody.innerHTML = `
        <tr>
          <td><span style="color:#94A3B8">< 1.0 m/s² (Dưới ngưỡng Min)</span></td>
          <td>Gia tốc ổn định / Tĩnh</td>
          <td>${c1} mẫu</td>
          <td>${pct(c1)}</td>
        </tr>
        <tr>
          <td><span style="color:#00E5FF">1.0 – 4.0 m/s² (Mức vừa)</span></td>
          <td>Gia tốc mức vừa</td>
          <td>${c2} mẫu</td>
          <td>${pct(c2)}</td>
        </tr>
        <tr>
          <td><span style="color:#FFB300">4.0 – 8.0 m/s² (Tiệm cận Max)</span></td>
          <td>Gia tốc cao</td>
          <td>${c3} mẫu</td>
          <td>${pct(c3)}</td>
        </tr>
        <tr>
          <td><span style="color:#FF5252">> 8.0 m/s² (Vượt ngưỡng Max)</span></td>
          <td>Gia tốc cực đại / Đột biến</td>
          <td>${c4} mẫu</td>
          <td>${pct(c4)}</td>
        </tr>
      `;
    }

    // TOGGLES
    function toggleDots() {
      showDots = !showDots;
      document.getElementById('chipDots').classList.toggle('active', showDots);
      updateMainChart();
    }

    function toggleAvg() {
      showAvg = !showAvg;
      document.getElementById('chipAvg').classList.toggle('active', showAvg);
      updateMainChart();
    }

    function toggleThresholds() {
      showThresholds = !showThresholds;
      document.getElementById('chipThresholds').classList.toggle('active', showThresholds);
      updateMainChart();
    }

    function resetChartZoom() {
      if (!mainChartInstance) return;
      zoomStart = 0;
      zoomEnd = 100;
      mainChartInstance.dispatchAction({
        type: 'dataZoom',
        start: 0,
        end: 100
      });
    }

    // EXPORT FUNCTIONS
    function exportJSON() {
      if (!currentSession) return;
      const data = {
        exportedAt: new Date().toISOString(),
        session: currentSession,
        dataPoints: currentDataPoints
      };
      const blob = new Blob([JSON.stringify(data, null, 2)], { type: 'application/json' });
      downloadBlob(blob, `session_${currentSession.id}_${Date.now()}.json`);
    }

    function exportCSV() {
      if (!currentSession || !currentDataPoints.length) {
        showToast('Không có dữ liệu để xuất CSV');
        return;
      }
      const label = determineSessionLabel(currentSession);
      const tag = slugifyTag(currentSession.label) || 'none';

      let csv = 'relative_time,magnitude,label,tag\n';
      const t0 = currentDataPoints[0].relative_time || 0;
      for (const p of currentDataPoints) {
        const relTime = Math.max(0, (p.relative_time - t0)).toFixed(3);
        const mag = Number(p.magnitude).toFixed(3);
        csv += `${relTime},${mag},${label},${tag}\n`;
      }

      const labelPrefix = label === 1 ? 'label1_moving' : 'label0_still';
      const tagPart = tag !== 'none' ? `_${tag}` : '';
      const filename = `${labelPrefix}_session_${String(currentSession.id).padStart(2, '0')}${tagPart}.csv`;

      const blob = new Blob([csv], { type: 'text/csv;charset=utf-8;' });
      downloadBlob(blob, filename);
      showToast(`Đã xuất file AI: ${filename}`);
    }

    async function exportAllSessionsCSV() {
      const sessions = getFilteredSessions();
      if (!sessions || sessions.length === 0) {
        alert('Không có phiên ghi nào phù hợp để xuất.');
        return;
      }

      showToast(`Đang gộp dữ liệu ${sessions.length} phiên cho AI...`);

      let csv = 'session_id,relative_time,magnitude,label,tag\n';

      for (let i = 0; i < sessions.length; i++) {
        const s = sessions[i];
        let points = [];
        if (currentSession && currentSession.id === s.id && currentDataPoints.length) {
          points = currentDataPoints;
        } else if (s.id === 999 && currentDataPoints.length) {
          points = currentDataPoints;
        } else {
          try {
            const res = await fetch(`/api/sessions/${s.id}`);
            if (res.ok) {
              const data = await res.json();
              points = data.dataPoints || [];
            }
          } catch (e) {
            console.warn('Lỗi tải dữ liệu phiên:', s.id, e);
          }
        }

        if (points.length) {
          const label = determineSessionLabel(s);
          const tag = slugifyTag(s.label) || 'none';
          const t0 = points[0].relative_time || 0;
          for (const p of points) {
            const relTime = Math.max(0, (p.relative_time - t0)).toFixed(3);
            const mag = Number(p.magnitude).toFixed(3);
            csv += `${s.id},${relTime},${mag},${label},${tag}\n`;
          }
        }
      }

      const dateStr = new Date().toISOString().slice(0, 10).replace(/-/g, '');
      const filename = `motion_dataset_all_${sessions.length}_sessions_${dateStr}.csv`;
      const blob = new Blob([csv], { type: 'text/csv;charset=utf-8;' });
      downloadBlob(blob, filename);
      showToast(`Đã xuất toàn bộ dataset: ${filename}`);
    }

    function downloadBlob(blob, filename) {
      const url = URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = filename;
      document.body.appendChild(a);
      a.click();
      document.body.removeChild(a);
      URL.revokeObjectURL(url);
    }
  </script>
  <div id="toastMsg" class="toast-msg"></div>
</body>
</html>
''';
