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
 const data = await res.text(); // or .json() – depending on API
 document.getElementById('content').innerHTML = data;
 } catch (e) {
 document.getElementById('content').innerHTML = '<p>Error while loading...</p>';
 }
 });
});
// For mobile: Hide sidebar initially
if (window.innerWidth < 768) {
 document.getElementById('sidebar').classList.add('hidden');
}
// Start: Keep sidebar open? Or hidden? Here open.
document.getElementById('sidebar').classList.remove('hidden');
const lockBtn = document.getElementById('lock-btn');
const logPanel = document.getElementById('log-panel');
const logContent = document.getElementById('log-content');
let logInterval = null;
lockBtn.addEventListener('click', () => {
 logPanel.classList.toggle('hidden');
 
 if (!logPanel.classList.contains('hidden')) {
 // Starts auto-refresh when open
 loadLogs();
 logInterval = setInterval(loadLogs, 5000); // every 5 sec
 } else {
 clearInterval(logInterval);
 }
});
async function loadLogs() {
 try {
 const res = await fetch('/api/logs'); // <- your URL
 const text = await res.text();
 logContent.textContent = text || 'No new logs...';
 logContent.scrollTop = logContent.scrollHeight; // auto-scroll to bottom
 } catch (e) {
 logContent.textContent = 'Error while loading log.';
 }
}
