const fs = require('node:fs');
const path = require('node:path');
const net = require('node:net');
const { randomUUID,createHash } = require('node:crypto');
const { readSettings } = require('./runtime.cjs');
const defaults = {enabled:false,brightness:1,blur:0,tint:0.36,scope:'window'};
function readRaw(root) {
  const file = path.join(root,'settings.json');
  return fs.existsSync(file) ? JSON.parse(fs.readFileSync(file,'utf8').replace(/^\uFEFF/,'')) : {...defaults};
}
async function withSettingsLock(root,work) {
  const identity=fs.realpathSync.native(root).toLowerCase();
  const pipe='\\\\.\\pipe\\codex-wallpaper-settings-'+createHash('sha256').update(identity).digest('hex');
  const deadline=Date.now()+8000;
  while(true) {
    const server=net.createServer(socket=>socket.destroy());
    try {
      await new Promise((resolve,reject)=>{server.once('error',reject);server.listen({path:pipe,exclusive:true},resolve);});
    } catch(error) {
      if(!['EADDRINUSE','EACCES'].includes(error.code)) throw error;
      if(Date.now()>deadline) throw new Error('另一个窗口正在保存壁纸设置，请稍后重试');
      await new Promise(resolve=>setTimeout(resolve,35));continue;
    }
    // Windows releases this exclusive pipe when the process exits, including crashes.
    try {return await work();} finally {await new Promise(resolve=>server.close(resolve));}
  }
}
async function updateSettings(root, change) {
  return withSettingsLock(root,()=>writeSettings(root,change));
}
function writeSettings(root, change) {
  if (!change || typeof change !== 'object' || Array.isArray(change)) throw new Error('设置必须是 JSON 对象');
  const allowed = new Set(['enabled','imagePath','brightness','blur','tint','scope','transparency']);
  for (const key of Object.keys(change)) if (!allowed.has(key)) throw new Error('未知设置：' + key);
  const settings = {...defaults,...readRaw(root),...change};
  if (typeof settings.enabled !== 'boolean') throw new Error('enabled 必须是布尔值');
  if (change.transparency !== undefined) {
    if (change.tint !== undefined) throw new Error('请只指定透明度或蒙层浓度中的一项');
    if (typeof change.transparency !== 'number' || !Number.isFinite(change.transparency) || change.transparency < 10 || change.transparency > 100) throw new Error('透明度范围为 10–100%');
    settings.tint = Number((1 - change.transparency / 100).toFixed(4));
  }
  delete settings.transparency;
  for (const [key,low,high] of [['brightness',0.1,2],['blur',0,30],['tint',0,0.9]]) {
    if (typeof settings[key] !== 'number' || !Number.isFinite(settings[key]) || settings[key] < low || settings[key] > high) throw new Error(key + ' 超出允许范围：' + low + '–' + high);
  }
  if (!['chat','window'].includes(settings.scope)) throw new Error('范围必须为 window 或 chat');
  if (Object.hasOwn(change,'imagePath') && (typeof settings.imagePath !== 'string' || !path.isAbsolute(settings.imagePath))) throw new Error('请选择图片的完整路径');
  const file = path.join(root,'settings.json');
  const candidate = file + '.' + randomUUID() + '.candidate';
  try {
    const validateImage = settings.enabled || Object.hasOwn(change,'imagePath');
    fs.writeFileSync(candidate,JSON.stringify(validateImage ? {...settings,enabled:true} : settings,null,2));
    readSettings(candidate);
    if (validateImage && !settings.enabled) fs.writeFileSync(candidate,JSON.stringify(settings,null,2));
    fs.renameSync(candidate,file);
  } finally { if (fs.existsSync(candidate)) fs.unlinkSync(candidate); }
  return settings;
}
function readState(root) {
  const file=path.join(root,'settings.json');
  const raw=fs.existsSync(file)?fs.readFileSync(file,'utf8'):null;
  const settings=raw===null?{...defaults}:JSON.parse(raw.replace(/^\uFEFF/,''));
  let live = {state:'closed'};
  try { live = JSON.parse(fs.readFileSync(path.join(root,'live-status.json'),'utf8')); } catch { }
  const fresh = Date.now() - Date.parse(live.time) >= -5000 && Date.now() - Date.parse(live.time) < 6000;
  let alive = false;
  if (fresh && Number.isInteger(live.pid) && live.pid > 0) {
    try { process.kill(live.pid,0); alive = true; } catch (error) { alive = error.code === 'EPERM'; }
  }
  live.running = alive && !['closed','failed'].includes(live.state);
  live.applied=!!(live.running&&live.mainReady&&['active','disabled'].includes(live.state)&&raw!==null&&live.settingsHash===createHash('sha256').update(raw).digest('hex'));
  return {settings,live};
}
module.exports = {readRaw,updateSettings,readState};
