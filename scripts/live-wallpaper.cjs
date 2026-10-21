// Alternative for immutable Store packages: start the original executable and
// apply CSS through its loopback debugging endpoint. No package files are edited.
const fs = require('node:fs');
const path = require('node:path');
const cp = require('node:child_process');
const net = require('node:net');
const {createHash} = require('node:crypto');
const {readInstallation}=require('./installation.cjs');
let { readSettings, validateSettings, buildStylesheet, shouldApplyToURL } = require('./runtime.cjs');
const styleModulePath = require.resolve('./runtime.cjs');
let styleModuleTime = fs.statSync(styleModulePath).mtimeMs;
const root = path.resolve(__dirname, '..');
const statusFile = path.join(root, 'live-status.json');
const settingsFile = path.join(root, 'settings.json');
const delay = ms => new Promise(resolve => setTimeout(resolve, ms));
let stopping = false;
let executable;
let port;
const startedAt = new Date().toISOString();
let cachedSettingsKey;
let cachedSettings;
let cachedStylesheet;
let cachedSettingsHash;
function currentSettings() {
  const moduleTime = fs.statSync(styleModulePath).mtimeMs;
  if (moduleTime !== styleModuleTime) {
    delete require.cache[styleModulePath];
    ({ readSettings, validateSettings, buildStylesheet, shouldApplyToURL } = require(styleModulePath));
    styleModuleTime = moduleTime;
  }
  const raw = fs.readFileSync(settingsFile,'utf8');
  const config = JSON.parse(raw.replace(/^\uFEFF/,''));
  const image = config.enabled === true ? fs.statSync(config.imagePath) : null;
  const key = raw + (image ? `${image.size}:${image.mtimeMs}` : '') + moduleTime;
  if (key !== cachedSettingsKey) { cachedSettings = validateSettings(config); cachedStylesheet = buildStylesheet(cachedSettings); cachedSettingsHash=createHash('sha256').update(raw).digest('hex'); cachedSettingsKey = key; }
  return cachedSettings;
}
function status(state, extra = {}) {
  const temp = statusFile + '.tmp';
  fs.writeFileSync(temp, JSON.stringify({ state, pid: process.pid, startedAt, time: new Date().toISOString(), executable, port, ...extra }, null, 2));
  fs.renameSync(temp, statusFile);
}
async function installedProcesses() {
  const literal = "'" + executable.replace(/'/g, "''") + "'";
  const script = `$ErrorActionPreference='Stop';$env:PSModulePath=(Join-Path $PSHOME 'Modules')+';'+$env:PSModulePath;@(Get-CimInstance Win32_Process -Filter "Name='ChatGPT.exe'" | Where-Object {$_.ExecutablePath -eq ${literal}} | ForEach-Object {$_.ProcessId}) | ConvertTo-Json -Compress`;
  const output = await new Promise((resolve, reject) => cp.execFile(path.join(process.env.WINDIR, 'System32', 'WindowsPowerShell', 'v1.0', 'powershell.exe'), ['-NoProfile','-EncodedCommand',Buffer.from(script,'utf16le').toString('base64')], { windowsHide: true, timeout: 10000 }, (error, stdout) => error ? reject(error) : resolve(stdout)));
  const value = output.trim() ? JSON.parse(output) : [];
  return Array.isArray(value) ? value : [value];
}
async function availablePort() {
  const server = net.createServer();
  await new Promise((resolve, reject) => { server.once('error',reject); server.listen(0,'127.0.0.1',resolve); });
  const selected = server.address().port;
  await new Promise((resolve,reject) => server.close(error => error ? reject(error) : resolve()));
  return selected;
}
class Renderer {
  constructor(target) { this.target = target; this.pending = new Map(); this.nextId = 0; this.styleId = null; this.text = null; }
  async open() {
    const endpoint = new URL(this.target.webSocketDebuggerUrl);
    if (endpoint.protocol !== 'ws:' || endpoint.hostname !== '127.0.0.1' || Number(endpoint.port) !== port) throw new Error('Unexpected debugging endpoint');
    this.socket = new WebSocket(endpoint);
    await new Promise((resolve,reject) => {
      const timer = setTimeout(() => { this.socket.close(); reject(new Error('Renderer connection timed out')); },5000);
      this.socket.onopen = () => { clearTimeout(timer); resolve(); };
      this.socket.onerror = () => { clearTimeout(timer); reject(new Error('Renderer connection failed')); };
    });
    this.socket.onmessage = event => {
      const message = JSON.parse(event.data);
      const waiting = this.pending.get(message.id);
      if (waiting) { clearTimeout(waiting.timer); this.pending.delete(message.id); message.error ? waiting.reject(new Error(message.error.message)) : waiting.resolve(message.result); }
      if (message.method === 'Page.frameNavigated' && !message.params.frame.parentId) { this.styleId = null; this.text = null; }
    };
    this.socket.onclose = () => { for (const item of this.pending.values()) { clearTimeout(item.timer); item.reject(new Error('Renderer closed')); } this.pending.clear(); };
    await this.call('Page.enable');
  }
  call(method, params = {}) {
    return new Promise((resolve,reject) => {
      const id = ++this.nextId;
      const timer = setTimeout(() => { this.pending.delete(id); reject(new Error(method + ' timed out')); },5000);
      this.pending.set(id,{ resolve,reject,timer });
      try { this.socket.send(JSON.stringify({ id,method,params })); } catch (error) { clearTimeout(timer); this.pending.delete(id); reject(error); }
    });
  }
  async apply(text, enabled, scope) {
    if (this.text !== text) {
      const inject = `(() => {if(location.protocol!=='app:'||location.hostname!=='-'||location.pathname!=='/index.html')return false;const id='codex-wallpaper-style';let s=document.getElementById(id);if(s&&s.tagName!=='STYLE')throw new Error('Wallpaper element conflict');if(!s){s=document.createElement('style');s.id=id;(document.head||document.documentElement).appendChild(s);}s.textContent=${JSON.stringify(text)};return true;})()`;
      const changed = await this.call('Runtime.evaluate',{ expression: inject,returnByValue: true });
      if (changed.exceptionDetails) throw new Error('Wallpaper stylesheet could not be inserted');
      if (changed.result.value !== true) return false;
      this.text = text;
    }
    const surface = scope === 'window' ? 'document.body' : 'm';
    const expression = `(() => {const m=document.querySelector('#root main[class*="MainContentSurface"]');return !!m && ${enabled ? `getComputedStyle(${surface},'::before').backgroundImage.startsWith('url("data:image/')` : "getComputedStyle(m,'::before').backgroundImage==='none'&&getComputedStyle(document.body,'::before').backgroundImage==='none'"};})()`;
    const result = await this.call('Runtime.evaluate',{ expression,returnByValue: true });
    if (result.exceptionDetails) throw new Error('Could not verify the main conversation surface');
    return result.result.value === true;
  }
  close() { this.socket?.close(); }
}
async function main() {
    executable = readInstallation(root).executable;
    readSettings(settingsFile);
    if (process.argv.includes('--resume')) {
      const previous = JSON.parse(fs.readFileSync(statusFile,'utf8'));
      if (previous.executable !== executable || !Number.isInteger(previous.port) || previous.port < 1 || previous.port > 65535) throw new Error('No verified original Codex endpoint is available to resume');
      port = previous.port;
      status('connecting-original');
    } else {
    const deadline = Date.now() + 10 * 60 * 1000;
    status('waiting-for-codex-exit');
    while ((await installedProcesses()).length) {
      if (Date.now() > deadline) throw new Error('Timed out waiting for Codex to exit. No application files were changed.');
      status('waiting-for-codex-exit'); await delay(800);
    }
    port = await availablePort();
    const app = cp.spawn(executable,['--remote-debugging-address=127.0.0.1','--remote-debugging-port=' + port],{ cwd: path.dirname(executable),detached: true,windowsHide: true,stdio: 'ignore' });
    await new Promise((resolve,reject) => { app.once('spawn',resolve); app.once('error',reject); });
    app.unref(); status('starting-original');
    }
  const sessions = new Map();
  const deadline = Date.now() + 90000;
  let connected = false;
  let lastProcessCheck = 0;
  try { while (!stopping) {
    try {
      const response = await fetch(`http://127.0.0.1:${port}/json/list`,{ signal: AbortSignal.timeout(1500),redirect: 'error' });
      const targets = (await response.json()).filter(target => target.type === 'page' && shouldApplyToURL(target.url));
      for (const [id,session] of sessions) if (!targets.some(target => target.id === id)) { session.close(); sessions.delete(id); }
      const settings = currentSettings();
      const text = cachedStylesheet;
      let mainReady = false;
      let lastError;
      for (const target of targets) {
        try {
          let session = sessions.get(target.id);
          if (!session) { session = new Renderer(target); sessions.set(target.id,session); await session.open(); }
          if (await session.apply(text,settings.enabled,settings.scope)) mainReady = true;
        } catch (error) { lastError = error.message; sessions.get(target.id)?.close(); sessions.delete(target.id); }
      }
      if (mainReady) { connected = true; status(settings.enabled ? 'active' : 'disabled',{ mainReady: true,scope:settings.scope,settingsHash:cachedSettingsHash,originalFilesModified: false }); }
      else status('waiting-for-main',{ mainReady: false,message: lastError });
    } catch (error) {
      if (connected) status('waiting-for-renderer',{ message: error.message });
      if (connected && Date.now() - lastProcessCheck > 4000) {
        lastProcessCheck = Date.now();
        if (!(await installedProcesses()).length) { stopping = true; status('closed'); }
      }
    }
    if (!connected && Date.now() > deadline) throw new Error('Could not connect to the original Codex window. The original program files were not changed.');
    await delay(700);
  } } finally { for (const session of sessions.values()) session.close(); }
}
process.on('SIGINT',() => { stopping = true; });
process.on('SIGTERM',() => { stopping = true; });
main().catch(error => { status('failed',{ message: error.message,originalFilesModified: false }); process.exitCode = 1; });
