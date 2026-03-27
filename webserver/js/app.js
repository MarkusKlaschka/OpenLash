// Adjusted app.js for OpenLash WebUI
function toggleSidebar() {
 document.getElementById('sidebar').classList.toggle('hidden');
}

document.querySelectorAll('.menu-item').forEach(item => {
 item.addEventListener('click', async () => {
 const url = item.dataset.url;
 if (!url) return;

 try {
 const res = await fetch(url);
 const data = await res.text(); // oder .json() – je nach API
 document.getElementById('content').innerHTML = data;
 } catch (e) {
 document.getElementById('content').innerHTML = '<p>Fehler beim Laden...</p>';
 }
 });
});

// Bei Mobile: Sidebar erstmal verstecken
if (window.innerWidth < 768) {
 document.getElementById('sidebar').classList.add('hidden');
}

// Start: Sidebar offen lassen? Oder hidden? Hier offen.
document.getElementById('sidebar').classList.remove('hidden');

const lockBtn = document.getElementById('lock-btn');
const logPanel = document.getElementById('log-panel');
const logContent = document.getElementById('log-content');

let logInterval = null;

lockBtn.addEventListener('click', () => {
 logPanel.classList.toggle('hidden');
 
 if (!logPanel.classList.contains('hidden')) {
 // Startet Auto-Refresh, wenn offen
 loadLogs();
 logInterval = setInterval(loadLogs, 5000); // alle 5 Sek
 } else {
 clearInterval(logInterval);
 }
});

async function loadLogs() {
 try {
 const res = await fetch('/api/logs'); // <- deine URL
 const text = await res.text();
 logContent.textContent = text || 'Keine neuen Logs...';
 logContent.scrollTop = logContent.scrollHeight; // auto-scroll nach unten
 } catch (e) {
 logContent.textContent = 'Fehler beim Log-Laden.';
 }
}
