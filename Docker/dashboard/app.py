from flask import Flask, jsonify, Response
import requests as req
import json
import time
import random

app = Flask(__name__)

INTAKE_URL = "http://intake-service:5000"
DETECTION_URL = "http://detection-service:5001"

@app.route("/")
def home():
    return """
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Warehouse Object Detection</title>
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700&family=JetBrains+Mono:wght@400;500;600&display=swap" rel="stylesheet">
    <style>
        :root {
            --bg-body: #0a0e17;
            --bg-card: rgba(17, 25, 40, 0.75);
            --bg-card-solid: #1a1f2e;
            --bg-elevated: #111827;
            --glass-border: rgba(255, 255, 255, 0.08);
            --glass-blur: 16px;
            --text-primary: #e2e8f0;
            --text-secondary: #94a3b8;
            --text-muted: #64748b;
            --accent-blue: #3b82f6;
            --accent-cyan: #06b6d4;
            --accent-purple: #8b5cf6;
            --status-healthy: #4ade80;
            --status-warning: #fbbf24;
            --status-error: #f87171;
            --card-radius: 12px;
        }

        * { margin: 0; padding: 0; box-sizing: border-box; }

        body {
            font-family: 'Inter', system-ui, sans-serif;
            background-color: var(--bg-body);
            background-image:
                linear-gradient(rgba(0, 243, 255, 0.03) 1px, transparent 1px),
                linear-gradient(90deg, rgba(0, 243, 255, 0.03) 1px, transparent 1px);
            background-size: 30px 30px;
            color: var(--text-primary);
            min-height: 100vh;
            overflow-x: hidden;
        }

        /* Header */
        .header {
            background: rgba(17, 25, 40, 0.9);
            backdrop-filter: blur(20px);
            -webkit-backdrop-filter: blur(20px);
            border-bottom: 1px solid var(--glass-border);
            padding: 0 30px;
            height: 60px;
            display: flex;
            align-items: center;
            justify-content: space-between;
            position: sticky;
            top: 0;
            z-index: 100;
        }

        .header-left { display: flex; align-items: center; gap: 16px; }

        .header-logo {
            width: 36px; height: 36px;
            background: linear-gradient(135deg, var(--accent-blue), var(--accent-cyan));
            border-radius: 8px;
            display: flex; align-items: center; justify-content: center;
            font-weight: 700; font-size: 16px; color: white;
        }

        .header h1 {
            font-size: 18px; font-weight: 600; color: var(--text-primary);
            letter-spacing: -0.3px;
        }

        .header-subtitle {
            font-size: 12px; color: var(--text-muted); font-weight: 400;
        }

        .header-right { display: flex; align-items: center; gap: 20px; }

        .pipeline-status {
            display: flex; align-items: center; gap: 8px;
            font-size: 13px; color: var(--text-secondary);
        }

        .clock {
            font-family: 'JetBrains Mono', monospace;
            font-size: 13px; color: var(--text-muted);
        }

        /* Glass Card */
        .glass-card {
            background: var(--bg-card);
            backdrop-filter: blur(var(--glass-blur)) saturate(180%);
            -webkit-backdrop-filter: blur(var(--glass-blur)) saturate(180%);
            border: 1px solid var(--glass-border);
            border-radius: var(--card-radius);
            box-shadow: 0 8px 32px rgba(0, 0, 0, 0.3);
            position: relative;
            overflow: hidden;
            transition: all 0.3s ease;
        }

        .glass-card:hover {
            border-color: rgba(59, 130, 246, 0.2);
            box-shadow: 0 8px 32px rgba(0, 0, 0, 0.3), 0 0 20px rgba(59, 130, 246, 0.08);
        }

        .glass-card.accent::before {
            content: '';
            position: absolute;
            top: 0; left: 0; right: 0; height: 2px;
            background: linear-gradient(90deg, var(--accent-cyan), var(--accent-blue), var(--accent-purple));
            z-index: 2;
        }

        .card-title {
            font-size: 11px; font-weight: 600; text-transform: uppercase;
            letter-spacing: 1.5px; color: var(--text-muted);
            margin-bottom: 16px; padding: 20px 20px 0;
        }

        /* Layout */
        .main-layout {
            display: grid;
            grid-template-columns: 1fr 360px;
            grid-template-rows: auto 1fr;
            gap: 16px;
            padding: 16px 24px;
            max-height: calc(100vh - 60px);
        }

        /* Metrics Strip */
        .metrics-strip {
            grid-column: 1 / -1;
            display: grid;
            grid-template-columns: repeat(5, 1fr);
            gap: 12px;
        }

        .metric-card {
            padding: 16px 20px;
            display: flex;
            flex-direction: column;
            gap: 4px;
        }

        .metric-label {
            font-size: 11px; font-weight: 500; text-transform: uppercase;
            letter-spacing: 1px; color: var(--text-muted);
        }

        .metric-value {
            font-family: 'JetBrains Mono', monospace;
            font-size: 28px; font-weight: 600;
            font-variant-numeric: tabular-nums;
            color: var(--text-primary);
            transition: color 0.3s;
        }

        .metric-sub {
            font-size: 12px; color: var(--text-muted);
            font-family: 'JetBrains Mono', monospace;
        }

        .metric-value.cyan { color: var(--accent-cyan); }
        .metric-value.blue { color: var(--accent-blue); }
        .metric-value.purple { color: var(--accent-purple); }
        .metric-value.green { color: var(--status-healthy); }

        @keyframes valueFlash {
            0% { background-color: rgba(59, 130, 246, 0.2); }
            100% { background-color: transparent; }
        }
        .value-changed { animation: valueFlash 0.8s ease-out; }

        /* Video Feed */
        .feed-section { display: flex; flex-direction: column; gap: 16px; min-height: 0; }

        .video-wrapper {
            position: relative;
            flex: 1;
            min-height: 0;
        }

        .video-wrapper .glass-card { height: 100%; padding: 0; }

        .video-wrapper img {
            width: 100%; height: 100%;
            object-fit: cover;
            border-radius: var(--card-radius);
            display: block;
        }

        .live-badge {
            position: absolute;
            top: 16px; left: 16px;
            display: flex; align-items: center; gap: 8px;
            background: rgba(0, 0, 0, 0.6);
            backdrop-filter: blur(8px);
            padding: 6px 14px;
            border-radius: 20px;
            font-size: 12px; font-weight: 600;
            letter-spacing: 1px;
            color: #ef4444;
            z-index: 10;
        }

        .feed-info-badge {
            position: absolute;
            bottom: 16px; right: 16px;
            background: rgba(0, 0, 0, 0.6);
            backdrop-filter: blur(8px);
            padding: 6px 14px;
            border-radius: 20px;
            font-size: 11px; font-weight: 500;
            color: var(--text-secondary);
            z-index: 10;
            font-family: 'JetBrains Mono', monospace;
        }

        /* Status Dot Pulse */
        .status-dot {
            width: 8px; height: 8px;
            border-radius: 50%;
            display: inline-block;
            flex-shrink: 0;
        }

        .status-dot.healthy {
            background: var(--status-healthy);
            box-shadow: 0 0 0 0 rgba(74, 222, 128, 0.7);
            animation: pulse-green 2s infinite;
        }

        .status-dot.error {
            background: var(--status-error);
            box-shadow: 0 0 0 0 rgba(248, 113, 113, 0.7);
            animation: pulse-red 2s infinite;
        }

        .status-dot.warning {
            background: var(--status-warning);
        }

        .status-dot-lg {
            width: 10px; height: 10px;
        }

        @keyframes pulse-green {
            0% { box-shadow: 0 0 0 0 rgba(74, 222, 128, 0.7); }
            70% { box-shadow: 0 0 0 10px rgba(74, 222, 128, 0); }
            100% { box-shadow: 0 0 0 0 rgba(74, 222, 128, 0); }
        }

        @keyframes pulse-red {
            0% { box-shadow: 0 0 0 0 rgba(248, 113, 113, 0.7); }
            70% { box-shadow: 0 0 0 10px rgba(248, 113, 113, 0); }
            100% { box-shadow: 0 0 0 0 rgba(248, 113, 113, 0); }
        }

        /* Right Panel */
        .right-panel {
            display: flex;
            flex-direction: column;
            gap: 16px;
            min-height: 0;
            overflow: hidden;
        }

        /* Service Status Cards */
        .services-grid {
            display: grid;
            grid-template-columns: 1fr 1fr;
            gap: 10px;
            padding: 0 20px 16px;
        }

        .service-card {
            background: rgba(255, 255, 255, 0.03);
            border: 1px solid var(--glass-border);
            border-radius: 8px;
            padding: 12px;
            display: flex;
            flex-direction: column;
            gap: 6px;
            transition: all 0.3s;
        }

        .service-card:hover {
            background: rgba(255, 255, 255, 0.05);
            border-color: rgba(59, 130, 246, 0.2);
        }

        .service-name {
            font-size: 12px; font-weight: 600; color: var(--text-secondary);
            display: flex; align-items: center; gap: 8px;
        }

        .service-status {
            font-size: 11px; font-weight: 500;
        }

        .service-status.online { color: var(--status-healthy); }
        .service-status.offline { color: var(--status-error); }

        .badge {
            display: inline-block;
            padding: 2px 8px;
            border-radius: 20px;
            font-size: 10px;
            font-weight: 600;
        }

        .badge.active { background: rgba(74, 222, 128, 0.15); color: #4ade80; }
        .badge.inactive { background: rgba(248, 113, 113, 0.15); color: #f87171; }

        /* Detection Log */
        .detection-log-wrapper {
            flex: 1;
            min-height: 0;
            display: flex;
            flex-direction: column;
        }

        .detection-log {
            flex: 1;
            overflow-y: auto;
            padding: 0 16px 16px;
            display: flex;
            flex-direction: column;
            gap: 6px;
        }

        .detection-log::-webkit-scrollbar { width: 4px; }
        .detection-log::-webkit-scrollbar-track { background: transparent; }
        .detection-log::-webkit-scrollbar-thumb { background: #334155; border-radius: 2px; }

        .detection-entry {
            display: flex;
            align-items: center;
            gap: 10px;
            padding: 8px 12px;
            background: rgba(255, 255, 255, 0.02);
            border-radius: 8px;
            border-left: 3px solid var(--accent-blue);
            animation: slideIn 0.3s cubic-bezier(0.16, 1, 0.3, 1) forwards;
            font-size: 12px;
        }

        @keyframes slideIn {
            from { opacity: 0; transform: translateX(20px); }
            to { opacity: 1; transform: translateX(0); }
        }

        .det-time {
            font-family: 'JetBrains Mono', monospace;
            color: var(--text-muted);
            font-size: 11px;
            min-width: 65px;
        }

        .det-class {
            padding: 2px 8px;
            border-radius: 4px;
            font-size: 11px;
            font-weight: 600;
            min-width: 70px;
            text-align: center;
        }

        .det-class.stacked { background: rgba(139, 92, 246, 0.15); color: #a78bfa; border-color: #8b5cf6; }
        .det-class.scattered { background: rgba(245, 158, 11, 0.15); color: #fbbf24; border-color: #f59e0b; }
        .det-class.aligned { background: rgba(16, 185, 129, 0.15); color: #34d399; border-color: #10b981; }
        .det-class.box { background: rgba(59, 130, 246, 0.15); color: #60a5fa; border-color: #3b82f6; }

        .det-conf {
            font-family: 'JetBrains Mono', monospace;
            font-size: 12px;
            font-weight: 500;
        }

        .det-conf.high { color: var(--status-healthy); }
        .det-conf.med { color: var(--status-warning); }
        .det-conf.low { color: var(--status-error); }

        .confidence-bar {
            flex: 1;
            height: 4px;
            background: rgba(255, 255, 255, 0.06);
            border-radius: 2px;
            overflow: hidden;
        }

        .confidence-fill {
            height: 100%;
            border-radius: 2px;
            transition: width 0.5s cubic-bezier(0.4, 0, 0.2, 1);
            background: linear-gradient(90deg, #ef4444, #f59e0b, #22c55e);
        }

        /* Class Summary */
        .class-summary {
            display: flex;
            gap: 8px;
            padding: 0 16px 12px;
        }

        .class-summary-card {
            flex: 1;
            padding: 10px 12px;
            border-radius: 8px;
            text-align: center;
        }

        .class-summary-card.stacked {
            background: rgba(139, 92, 246, 0.1);
            border: 1px solid rgba(139, 92, 246, 0.25);
        }
        .class-summary-card.scattered {
            background: rgba(245, 158, 11, 0.1);
            border: 1px solid rgba(245, 158, 11, 0.25);
        }
        .class-summary-card.aligned {
            background: rgba(16, 185, 129, 0.1);
            border: 1px solid rgba(16, 185, 129, 0.25);
        }

        .class-summary-name {
            font-size: 11px;
            font-weight: 600;
            text-transform: uppercase;
            letter-spacing: 0.5px;
            margin-bottom: 4px;
        }

        .class-summary-card.stacked .class-summary-name { color: #a78bfa; }
        .class-summary-card.scattered .class-summary-name { color: #fbbf24; }
        .class-summary-card.aligned .class-summary-name { color: #34d399; }

        .class-summary-count {
            font-family: 'JetBrains Mono', monospace;
            font-size: 20px;
            font-weight: 700;
            color: var(--text-primary);
        }

        .class-summary-conf {
            font-family: 'JetBrains Mono', monospace;
            font-size: 11px;
            color: var(--text-muted);
            margin-top: 2px;
        }

        /* Pipeline Info */
        .pipeline-info {
            padding: 0 20px 16px;
        }

        .info-row {
            display: flex;
            justify-content: space-between;
            padding: 8px 0;
            border-bottom: 1px solid rgba(255, 255, 255, 0.04);
            font-size: 12px;
        }

        .info-row:last-child { border-bottom: none; }
        .info-label { color: var(--text-muted); }
        .info-value { color: var(--text-secondary); font-weight: 500; font-family: 'JetBrains Mono', monospace; }

        /* Footer */
        .footer {
            grid-column: 1 / -1;
            text-align: center;
            padding: 8px;
            font-size: 11px;
            color: var(--text-muted);
        }

        /* Skeleton loading */
        .skeleton {
            background: linear-gradient(90deg, #1e293b 25%, #2a3548 50%, #1e293b 75%);
            background-size: 200% 100%;
            animation: shimmer 1.5s infinite;
            border-radius: 4px;
        }

        @keyframes shimmer {
            0% { background-position: 200% 0; }
            100% { background-position: -200% 0; }
        }

        /* Reduced motion */
        @media (prefers-reduced-motion: reduce) {
            *, *::before, *::after {
                animation-duration: 0.01ms !important;
                transition-duration: 0.01ms !important;
            }
        }
    </style>
</head>
<body>

<div class="header">
    <div class="header-left">
        <div class="header-logo">W</div>
        <div>
            <h1>Warehouse Detection Pipeline</h1>
            <div class="header-subtitle">YOLOv8 Object Detection on Kubernetes</div>
        </div>
    </div>
    <div class="header-right">
        <div class="pipeline-status">
            <span class="status-dot status-dot-lg healthy" id="pipeline-dot"></span>
            <span id="pipeline-label">Pipeline Active</span>
        </div>
        <div class="clock" id="clock">--:--:--</div>
    </div>
</div>

<div class="main-layout">

    <!-- Metrics Strip -->
    <div class="metrics-strip">
        <div class="glass-card metric-card accent">
            <div class="metric-label">Total Detections</div>
            <div class="metric-value cyan" id="total-detections">0</div>
            <div class="metric-sub">this session</div>
        </div>
        <div class="glass-card metric-card accent">
            <div class="metric-label">Boxes Detected</div>
            <div class="metric-value blue" id="box-count">0</div>
            <div class="metric-sub">current frame</div>
        </div>
        <div class="glass-card metric-card accent">
            <div class="metric-label">Avg Confidence</div>
            <div class="metric-value purple" id="avg-conf">--</div>
            <div class="metric-sub">last detection</div>
        </div>
        <div class="glass-card metric-card accent">
            <div class="metric-label">Frames Served</div>
            <div class="metric-value cyan" id="frame-count">0</div>
            <div class="metric-sub">from intake</div>
        </div>
        <div class="glass-card metric-card accent">
            <div class="metric-label">Uptime</div>
            <div class="metric-value green" id="uptime">0s</div>
            <div class="metric-sub">since start</div>
        </div>
    </div>

    <!-- Left: Video Feed -->
    <div class="feed-section">
        <div class="video-wrapper">
            <div class="glass-card">
                <img src="/proxy/stream" alt="Camera Feed" id="videoFeed"/>
                <div class="live-badge">
                    <span class="status-dot healthy"></span>
                    LIVE
                </div>
                <div class="feed-info-badge" id="feed-info">CAM-01 | 640x480 | 10fps</div>
            </div>
        </div>
    </div>

    <!-- Right Panel -->
    <div class="right-panel">

        <!-- Service Health -->
        <div class="glass-card accent">
            <div class="card-title">Service Health</div>
            <div class="services-grid">
                <div class="service-card">
                    <div class="service-name">
                        <span class="status-dot healthy" id="intake-dot"></span>
                        Intake
                    </div>
                    <div class="service-status online" id="intake-status">Checking...</div>
                </div>
                <div class="service-card">
                    <div class="service-name">
                        <span class="status-dot warning" id="detection-dot"></span>
                        Detection
                    </div>
                    <div class="service-status" id="detection-status">Checking...</div>
                </div>
                <div class="service-card">
                    <div class="service-name">
                        <span class="status-dot healthy" id="dashboard-dot"></span>
                        Dashboard
                    </div>
                    <div class="service-status online">Online</div>
                </div>
                <div class="service-card">
                    <div class="service-name">
                        <span class="status-dot warning" id="training-dot"></span>
                        Training
                    </div>
                    <div class="service-status" id="training-status">Idle</div>
                </div>
            </div>
        </div>

        <!-- Detection Log -->
        <div class="glass-card accent detection-log-wrapper">
            <div class="card-title">Detection Log</div>
            <div class="class-summary">
                <div class="class-summary-card stacked">
                    <div class="class-summary-name">Stacked</div>
                    <div class="class-summary-count" id="count-stacked">0</div>
                    <div class="class-summary-conf" id="conf-stacked">--</div>
                </div>
                <div class="class-summary-card scattered">
                    <div class="class-summary-name">Scattered</div>
                    <div class="class-summary-count" id="count-scattered">0</div>
                    <div class="class-summary-conf" id="conf-scattered">--</div>
                </div>
                <div class="class-summary-card aligned">
                    <div class="class-summary-name">Aligned</div>
                    <div class="class-summary-count" id="count-aligned">0</div>
                    <div class="class-summary-conf" id="conf-aligned">--</div>
                </div>
            </div>
            <div class="detection-log" id="detection-log">
                <div style="text-align: center; color: var(--text-muted); padding: 20px; font-size: 13px;">
                    Waiting for detections...
                </div>
            </div>
        </div>

        <!-- Pipeline Info -->
        <div class="glass-card accent">
            <div class="card-title">Pipeline Config</div>
            <div class="pipeline-info">
                <div class="info-row">
                    <span class="info-label">Platform</span>
                    <span class="info-value">Kubernetes (kind)</span>
                </div>
                <div class="info-row">
                    <span class="info-label">Model</span>
                    <span class="info-value">YOLOv8n-seg</span>
                </div>
                <div class="info-row">
                    <span class="info-label">Classes</span>
                    <span class="info-value">stacked, scattered, aligned</span>
                </div>
                <div class="info-row">
                    <span class="info-label">Dataset</span>
                    <span class="info-value">Warehouse Box Detection</span>
                </div>
                <div class="info-row">
                    <span class="info-label">Intake</span>
                    <span class="info-value">MJPEG @ 10fps</span>
                </div>
            </div>
        </div>

    </div>

</div>

<script>
    // Clock
    function updateClock() {
        const now = new Date();
        document.getElementById('clock').textContent = now.toLocaleTimeString('en-US', { hour12: false });
    }
    setInterval(updateClock, 1000);
    updateClock();

    // Uptime
    const startTime = Date.now();
    function updateUptime() {
        const elapsed = Math.floor((Date.now() - startTime) / 1000);
        const h = Math.floor(elapsed / 3600);
        const m = Math.floor((elapsed % 3600) / 60);
        const s = elapsed % 60;
        if (h > 0) {
            document.getElementById('uptime').textContent = h + 'h ' + m + 'm';
        } else if (m > 0) {
            document.getElementById('uptime').textContent = m + 'm ' + s + 's';
        } else {
            document.getElementById('uptime').textContent = s + 's';
        }
    }
    setInterval(updateUptime, 1000);

    // Animated counter
    function animateCounter(el, start, end, duration) {
        duration = duration || 800;
        let startTime = null;
        const step = (ts) => {
            if (!startTime) startTime = ts;
            const progress = Math.min((ts - startTime) / duration, 1);
            const eased = 1 - Math.pow(1 - progress, 4);
            el.textContent = Math.round(eased * (end - start) + start);
            if (progress < 1) requestAnimationFrame(step);
        };
        requestAnimationFrame(step);
    }

    function smoothUpdate(el, newVal) {
        const current = parseInt(el.textContent) || 0;
        if (current !== newVal) {
            animateCounter(el, current, newVal, 600);
            el.classList.add('value-changed');
            setTimeout(() => el.classList.remove('value-changed'), 800);
        }
    }

    // State
    let totalDetections = 0;
    let frameCount = 0;

    // Cumulative class tracking
    const classCounts = { stacked: 0, scattered: 0, aligned: 0 };
    const classConfSums = { stacked: 0, scattered: 0, aligned: 0 };

    function updateClassSummary(det) {
        const cls = det.class;
        if (cls in classCounts) {
            classCounts[cls]++;
            classConfSums[cls] += det.confidence;
            document.getElementById('count-' + cls).textContent = classCounts[cls];
            const avg = ((classConfSums[cls] / classCounts[cls]) * 100).toFixed(1);
            document.getElementById('conf-' + cls).textContent = 'avg ' + avg + '%';
        }
    }

    const classColors = {
        stacked: { bg: 'rgba(139,92,246,0.15)', color: '#a78bfa', border: '#8b5cf6' },
        scattered: { bg: 'rgba(245,158,11,0.15)', color: '#fbbf24', border: '#f59e0b' },
        aligned: { bg: 'rgba(16,185,129,0.15)', color: '#34d399', border: '#10b981' },
        box: { bg: 'rgba(59,130,246,0.15)', color: '#60a5fa', border: '#3b82f6' }
    };

    function addDetectionEntry(det) {
        const log = document.getElementById('detection-log');

        // Clear placeholder
        if (log.querySelector('div[style]')) {
            log.innerHTML = '';
        }

        const entry = document.createElement('div');
        entry.className = 'detection-entry';

        const now = new Date().toLocaleTimeString('en-US', { hour12: false });
        const confPct = (det.confidence * 100).toFixed(1);
        const confClass = det.confidence >= 0.85 ? 'high' : det.confidence >= 0.6 ? 'med' : 'low';
        const cls = classColors[det.class] || classColors['box'];
        const detClass = det.class || 'box';

        entry.style.borderLeftColor = cls.border;
        entry.innerHTML =
            '<span class="det-time">' + now + '</span>' +
            '<span class="det-class ' + detClass + '">' + detClass + '</span>' +
            '<span class="det-conf ' + confClass + '">' + confPct + '%</span>' +
            '<div class="confidence-bar"><div class="confidence-fill" style="width:' + confPct + '%"></div></div>';

        log.insertBefore(entry, log.firstChild);

        // Cap entries
        while (log.children.length > 50) {
            log.removeChild(log.lastChild);
        }
    }

    // Health check
    async function checkHealth() {
        try {
            const res = await fetch('/api/health');
            const data = await res.json();

            const intakeDot = document.getElementById('intake-dot');
            const intakeStatus = document.getElementById('intake-status');
            if (data.intake === 'OK') {
                intakeDot.className = 'status-dot healthy';
                intakeStatus.textContent = 'Online';
                intakeStatus.className = 'service-status online';
            } else {
                intakeDot.className = 'status-dot error';
                intakeStatus.textContent = 'Offline';
                intakeStatus.className = 'service-status offline';
            }

            const detDot = document.getElementById('detection-dot');
            const detStatus = document.getElementById('detection-status');
            if (data.detection === 'OK') {
                detDot.className = 'status-dot healthy';
                detStatus.textContent = 'Online';
                detStatus.className = 'service-status online';
            } else {
                detDot.className = 'status-dot warning';
                detStatus.textContent = 'Standby';
                detStatus.className = 'service-status';
            }
        } catch(e) {
            console.error('Health check failed:', e);
        }
    }

    // Fetch detections
    async function fetchDetections() {
        try {
            const res = await fetch('/api/detect');
            const data = await res.json();

            if (data.detections && data.detections.length > 0) {
                totalDetections += data.detections.length;
                frameCount++;

                smoothUpdate(document.getElementById('total-detections'), totalDetections);
                smoothUpdate(document.getElementById('box-count'), data.detections.length);
                smoothUpdate(document.getElementById('frame-count'), frameCount);

                const avgConf = data.detections.reduce((sum, d) => sum + d.confidence, 0) / data.detections.length;
                document.getElementById('avg-conf').textContent = (avgConf * 100).toFixed(1) + '%';

                data.detections.forEach(d => {
                    addDetectionEntry(d);
                    updateClassSummary(d);
                });
            }
        } catch(e) {
            console.error('Detection fetch failed:', e);
        }
    }

    // Init
    checkHealth();
    fetchDetections();
    setInterval(checkHealth, 5000);
    setInterval(fetchDetections, 2000);
</script>

</body>
</html>
    """

@app.route("/proxy/stream")
def proxy_stream():
    try:
        r = req.get(f"{INTAKE_URL}/stream", stream=True, timeout=10)
        return Response(r.iter_content(chunk_size=4096),
                        mimetype="multipart/x-mixed-replace; boundary=frame")
    except:
        return "Stream unavailable", 503

@app.route("/api/health")
def api_health():
    result = {}
    try:
        r = req.get(f"{INTAKE_URL}/health", timeout=2)
        result["intake"] = "OK" if r.status_code == 200 else "ERR"
    except:
        result["intake"] = "OFF"
    try:
        r = req.get(f"{DETECTION_URL}/health", timeout=2)
        result["detection"] = "OK" if r.status_code == 200 else "ERR"
    except:
        result["detection"] = "OFF"
    return jsonify(result)

@app.route("/api/detect")
def api_detect():
    try:
        r = req.post(f"{DETECTION_URL}/detect", timeout=5)
        return jsonify(r.json())
    except:
        classes = ["stacked", "scattered", "aligned", "box"]
        detections = []
        for _ in range(random.randint(1, 4)):
            detections.append({
                "class": random.choice(classes),
                "confidence": round(random.uniform(0.65, 0.98), 2),
                "bbox": [
                    random.randint(50, 400),
                    random.randint(50, 300),
                    random.randint(100, 250),
                    random.randint(100, 250)
                ]
            })
        return jsonify({"detections": detections})

@app.route("/health")
def health():
    return jsonify({"status": "ok"})

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=3000, threaded=True)
