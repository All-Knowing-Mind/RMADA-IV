const menu = document.querySelector('#mobile-menu')
const menuLinks = document.querySelector ('.navbar__menu')

menu.addEventListener ('click', function () {
    menu.classList.toggle ('is-active')
    menuLinks.classList.toggle('active')
})

// Real-time chart + WebSocket logic
document.addEventListener('DOMContentLoaded', () => {
    const connStatus = document.getElementById('connStatus');
    const connectBtn = document.getElementById('connectBtn');
    const wsUrlInput = document.getElementById('wsUrl');
    const requestPermBtn = document.getElementById('requestPermBtn');
    const alertsList = document.getElementById('alerts');

    // find canvases
    const chartsCount = 6;
    const charts = [];
    const chartData = [];
    const maxPoints = 60;

    for (let i = 0; i < chartsCount; i++) {
        const canvas = document.getElementById(`chart-${i}`);
        if (!canvas) continue;
        const labels = [];
        const values = [];
        chartData.push({ labels, values });
        const c = new Chart(canvas.getContext('2d'), {
            type: 'line',
            data: {
                labels: labels,
                datasets: [{
                    label: `Série ${i+1}`,
                    data: values,
                    borderColor: 'rgba(75, 192, 192, 1)',
                    backgroundColor: 'rgba(75, 192, 192, 0.12)',
                    fill: true,
                    tension: 0.3,
                }]
            },
            options: {
                animation: false,
                responsive: true,
                maintainAspectRatio: false,
                scales: {
                    x: { display: true, title: { display: true, text: 'Hora' } },
                    y: { display: true, title: { display: true, text: 'Valor' } }
                },
                plugins: { legend: { display: false } }
            }
        });
        charts.push(c);
    }

    function addPointToChart(index, value) {
        if (index < 0 || index >= charts.length) return;
        const now = new Date().toLocaleTimeString();
        const data = chartData[index];
        data.labels.push(now);
        data.values.push(Number(value));
        if (data.labels.length > maxPoints) { data.labels.shift(); data.values.shift(); }
        charts[index].update();
    }

    // Audio alert (WebAudio, short beep)
    let audioCtx = null;
    function playAlertSound() {
        try {
            if (!audioCtx) audioCtx = new (window.AudioContext || window.webkitAudioContext)();
            const o = audioCtx.createOscillator();
            const g = audioCtx.createGain();
            o.type = 'sine';
            o.frequency.value = 880;
            o.connect(g);
            g.connect(audioCtx.destination);
            g.gain.value = 0.0001;
            const now = audioCtx.currentTime;
            g.gain.exponentialRampToValueAtTime(0.12, now + 0.02);
            o.start(now);
            g.gain.exponentialRampToValueAtTime(0.0001, now + 0.5);
            o.stop(now + 0.55);
        } catch (e) { console.warn('Audio failed', e); }
    }

    // persistence: alerts and chart series
    const ALERTS_KEY = 'rmada_alerts_v1';
    const CHART_KEY = 'rmada_charts_v1';

    function saveAlerts() {
        const items = [];
        alertsList.querySelectorAll('li').forEach(li => items.push({ text: li.textContent, cls: li.className }));
        localStorage.setItem(ALERTS_KEY, JSON.stringify(items));
    }
    function loadAlerts() {
        const raw = localStorage.getItem(ALERTS_KEY);
        if (!raw) return;
        try {
            const items = JSON.parse(raw);
            alertsList.innerHTML = '';
            items.forEach(it => {
                const li = document.createElement('li');
                li.textContent = it.text; li.className = it.cls || 'info';
                alertsList.appendChild(li);
            });
        } catch (e) { console.warn('loadAlerts', e); }
    }

    function saveCharts() {
        try {
            const payload = chartData.map(d => ({ labels: d.labels.slice(-maxPoints), values: d.values.slice(-maxPoints) }));
            localStorage.setItem(CHART_KEY, JSON.stringify(payload));
        } catch (e) { console.warn('saveCharts', e); }
    }
    function loadCharts() {
        try {
            const raw = localStorage.getItem(CHART_KEY);
            if (!raw) return;
            const payload = JSON.parse(raw);
            payload.forEach((p, idx) => {
                if (!chartData[idx]) return;
                chartData[idx].labels.splice(0, chartData[idx].labels.length, ...p.labels.slice(-maxPoints));
                chartData[idx].values.splice(0, chartData[idx].values.length, ...p.values.slice(-maxPoints));
                if (charts[idx]) charts[idx].update();
            });
        } catch (e) { console.warn('loadCharts', e); }
    }

    loadAlerts();
    loadCharts();

    // --- Authentication UI wiring ---
    // subscribe triggers: any element with class 'subscribe' (navbar, hero, service cards)
    const subscribeEls = document.querySelectorAll('.subscribe');
    const authModal = document.getElementById('authModal');
    const authClose = document.getElementById('authClose');
    const tabs = document.querySelectorAll('.tabs .tab');

    function openAuth() { if (!authModal) return; authModal.setAttribute('aria-hidden', 'false'); }
    function closeAuth() { if (!authModal) return; authModal.setAttribute('aria-hidden', 'true'); }

    if (subscribeEls && subscribeEls.length) {
        subscribeEls.forEach(el => el.addEventListener('click', (e) => { e.preventDefault?.(); openAuth(); }));
    }
    authClose?.addEventListener('click', closeAuth);
    authModal?.addEventListener('click', (e) => { if (e.target === authModal) closeAuth(); });

    tabs.forEach(t => t.addEventListener('click', () => {
        tabs.forEach(x => x.classList.remove('active'));
        t.classList.add('active');
        const target = t.dataset.tab;
        document.querySelectorAll('.tab-panels .panel').forEach(p => p.style.display = (p.id === 'panel-' + target) ? 'block' : 'none');
    }));

    // auth buttons
    const doRegister = document.getElementById('doRegister');
    const doDefenseLogin = document.getElementById('doDefenseLogin');

    async function postJson(url, body) {
        const res = await fetch(url, { method: 'POST', headers: { 'Content-Type':'application/json' }, body: JSON.stringify(body) });
        return res;
    }

    doRegister?.addEventListener('click', async () => {
        const username = document.getElementById('regUser').value.trim();
        const password = document.getElementById('regPass').value;
        const ownerCode = document.getElementById('regOwnerCode').value.trim();
        const msg = document.getElementById('regMsg');
        msg.textContent = 'Enviando...';
        try {
            const res = await postJson('/api/register-owner', { username, password, ownerCode });
            const j = await res.json();
            if (!res.ok) { msg.textContent = j.error || 'erro'; return; }
            localStorage.setItem('rmada_token', j.token);
            localStorage.setItem('rmada_role', 'owner');
            msg.textContent = 'Registrado! Acesso Proprietário ativado.';
            setTimeout(closeAuth, 800);
        } catch (e) { msg.textContent = 'Erro de rede'; }
    });

    doDefenseLogin?.addEventListener('click', async () => {
        const code = document.getElementById('defCode').value.trim();
        const msg = document.getElementById('defMsg');
        msg.textContent = 'Verificando...';
        try {
            const res = await postJson('/api/login-defense', { code });
            const j = await res.json();
            if (!res.ok) { msg.textContent = j.error || 'erro'; return; }
            localStorage.setItem('rmada_token', j.token);
            localStorage.setItem('rmada_role', 'defense');
            msg.textContent = 'Acesso Defesa Civil ativado!';
            setTimeout(closeAuth, 800);
        } catch (e) { msg.textContent = 'Erro de rede'; }
    });

    // helper to include token in websocket url
    function appendTokenToUrl(url) {
        try {
            const t = localStorage.getItem('rmada_token');
            if (!t) return url;
            const u = new URL(url);
            u.searchParams.set('token', t);
            return u.toString();
        } catch (e) { return url + (url.includes('?') ? '&' : '?') + 'token=' + encodeURIComponent(localStorage.getItem('rmada_token') || ''); }
    }

    // notifications
    function showAlert(text, level = 'info') {
        const li = document.createElement('li');
        li.textContent = `${new Date().toLocaleTimeString()} — ${text}`;
        li.className = level === 'critical' ? 'critical' : 'info';
        alertsList.insertBefore(li, alertsList.firstChild);
        saveAlerts();
        // browser notification
        if (window.Notification && Notification.permission === 'granted') {
            try { new Notification('Alerta RMADA', { body: text }); } catch (e) { console.warn(e); }
        }
        if (level === 'critical') playAlertSound();
    }

    requestPermBtn?.addEventListener('click', () => {
        if (!('Notification' in window)) return alert('Navegador não suporta Notifications API');
        Notification.requestPermission().then(p => alert('Permissão: ' + p));
    });

    // map device IDs to chart indices (D1..D6)
    const deviceMap = { 'D1':0, 'D2':1, 'D3':2, 'D4':3, 'D5':4, 'D6':5 };

    function deviceIndexFromId(id) {
        if (!id) return -1;
        if (id in deviceMap) return deviceMap[id];
        const up = id.toString().toUpperCase();
        return up in deviceMap ? deviceMap[up] : -1;
    }

    function setDeviceStatus(idx, ok) {
        const dev = `D${idx+1}`;
        const el = document.getElementById(`status-${dev}`);
        if (!el) return;
        el.textContent = ok ? 'OK' : 'ALERTA';
        el.style.background = ok ? '#2e8b57' : '#cc0000';
    }

    // shared message processor
    function processIncoming(obj) {
        // expected: { deviceId: 'D1', value: 12.3 }
        let deviceId = obj.deviceId ?? obj.id ?? obj.dev;
        let raw = obj.value ?? obj.v ?? obj.val ?? obj.payload ?? obj.data ?? obj;
        const idx = deviceIndexFromId(deviceId);
        const n = Number(raw);
        if (!isNaN(n) && idx >= 0) {
            addPointToChart(idx, n);
            // threshold check (read from DOM)
            const card = document.querySelectorAll('.chart-card')[idx];
            const th = card ? Number(card.querySelector('.threshold')?.textContent ?? 80) : 80;
            if (n >= th) {
                setDeviceStatus(idx, false);
                showAlert(`ALERTA: ${deviceId} valor=${n} >= threshold ${th}`, 'critical');
            } else {
                setDeviceStatus(idx, true);
            }
            saveCharts();
        } else if (!isNaN(n) && idx === -1) {
            // no mapping -> distribute round-robin
            const rr = Math.floor(Math.random()*charts.length);
            addPointToChart(rr, n);
            saveCharts();
        }
    }

    // Simulation when no WS
    let simTimer = null;
    function startSimulation() {
        stopSimulation();
        connStatus.textContent = 'Modo simulação';
        connStatus.classList.remove('connected'); connStatus.classList.add('disconnected');
        simTimer = setInterval(() => {
            // simulate 6 devices
            for (let d=1; d<=6; d++) {
                const deviceId = `D${d}`;
                // simulate value with occasional spikes
                let base = 20 + d*5;
                let noise = (Math.random()*10 - 5);
                let spike = Math.random() < 0.03 ? (30 + Math.random()*70) : 0;
                const v = Math.max(0, (base + noise + spike)).toFixed(2);
                processIncoming({ deviceId, value: v });
            }
        }, 1000);
    }
    function stopSimulation() { if (simTimer) { clearInterval(simTimer); simTimer = null; } }

    // WebSocket connection with exponential backoff
    let socket = null;
    let currentUrl = wsUrlInput.value.trim();
    let retryDelay = 1000;
    const maxDelay = 30000;
    let reconnectTimer = null;
    let manualClose = false;

    function scheduleReconnect() {
        if (reconnectTimer) return;
        const delay = retryDelay;
        reconnectTimer = setTimeout(() => {
            reconnectTimer = null;
            connect(currentUrl);
            retryDelay = Math.min(maxDelay, retryDelay * 2);
        }, delay);
    }

    function connect(url) {
        manualClose = false;
        currentUrl = url;
        if (socket) { socket.close(); socket = null; }
        // append token if present
        const urlWithToken = appendTokenToUrl(url);
        try { socket = new WebSocket(urlWithToken); } catch (e) { console.error(e); connStatus.textContent = 'Erro ao criar WS'; startSimulation(); scheduleReconnect(); return; }

        socket.addEventListener('open', () => {
            connStatus.textContent = 'Conectado';
            connStatus.classList.add('connected'); connStatus.classList.remove('disconnected');
            stopSimulation();
            // reset backoff
            retryDelay = 1000;
            if (reconnectTimer) { clearTimeout(reconnectTimer); reconnectTimer = null; }
        });

        socket.addEventListener('message', (evt) => {
            let payload = evt.data;
            try {
                const parsed = JSON.parse(payload);
                processIncoming(parsed);
            } catch (err) {
                const n = Number(payload);
                if (!isNaN(n)) processIncoming({ value: n });
            }
        });

        socket.addEventListener('close', (ev) => {
            if (!manualClose) scheduleReconnect();
            connStatus.textContent = 'Desconectado'; connStatus.classList.remove('connected'); connStatus.classList.add('disconnected');
            startSimulation();
        });

        socket.addEventListener('error', (err) => {
            console.error('WS error', err);
            connStatus.textContent = 'Erro na conexão';
            startSimulation();
            scheduleReconnect();
        });
    }

    // Wire UI
    connectBtn.addEventListener('click', () => {
        const url = wsUrlInput.value.trim();
        if (!url) return alert('Insira URL do WebSocket');
        connStatus.textContent = 'Conectando...';
        currentUrl = url;
        retryDelay = 1000;
        connect(url);
    });

    // periodic save
    setInterval(saveCharts, 5000);

    // start simulation by default
    startSimulation();
    // try auto connect after short delay
    setTimeout(() => {
        const url = wsUrlInput.value.trim();
        if (url) { currentUrl = url; connect(url); }
    }, 800);
});