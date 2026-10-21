const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const cp = require('node:child_process');
const crypto = require('node:crypto');
const api = path.resolve(__dirname, '../scripts/control.cjs');
function fixture(t) {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'codex-wallpaper-ui-'));
  t.after(() => {assert.ok(path.resolve(root).startsWith(path.join(os.tmpdir(),'codex-wallpaper-ui-')));fs.rmSync(root, {recursive:true, force:true});});
  const image = path.join(root, '星空 壁纸 & test.png');
  fs.writeFileSync(image, Buffer.from([137,80,78,71,13,10,26,10,0,0,0,0]));
  const settings = {enabled:true, imagePath:image, brightness:1, blur:0, tint:0.36, scope:'window'};
  fs.writeFileSync(path.join(root, 'settings.json'), JSON.stringify(settings));
  return {root, image, settings};
}
function call(root, action, value) {
  return cp.spawnSync(process.execPath, [api, action, '--root', root], {input:JSON.stringify(value || {}), encoding:'utf8', windowsHide:true});
}
test('desktop and skill API changes only requested settings and preserves Unicode image paths', t => {
  const {root,image} = fixture(t);
  const result = call(root, 'apply', {brightness:0.8,blur:5,transparency:70});
  assert.equal(result.status, 0, result.stderr);
  const saved = JSON.parse(fs.readFileSync(path.join(root,'settings.json')));
  assert.equal(saved.imagePath,image); assert.equal(saved.scope,'window');
  assert.equal(saved.brightness,0.8); assert.equal(saved.blur,5);
  assert.ok(Math.abs(saved.tint - 0.3) < 1e-9);
  assert.equal(JSON.parse(result.stdout).settings.enabled,true);
});
test('invalid requests leave the complete previous settings untouched', t => {
  const {root} = fixture(t); const file = path.join(root,'settings.json'); const before = fs.readFileSync(file,'utf8');
  for (const change of [{brightness:0},{blur:31},{transparency:101},{scope:'all'},{enabled:'yes'},{unknown:true},{imagePath:path.join(root,'missing.png')},{brightness:null}]) {
    const result = call(root,'apply',change);
    assert.notEqual(result.status,0,JSON.stringify(change));
    assert.equal(typeof JSON.parse(result.stderr).error,'string');
    assert.equal(fs.readFileSync(file,'utf8'),before);
  }
  assert.deepEqual(fs.readdirSync(root).filter(name => name.includes('.candidate')),[]);
});
test('restoring default keeps the chosen image and can disable even if the source image disappeared', t => {
  const {root,image} = fixture(t); fs.unlinkSync(image);
  assert.equal(call(root,'apply',{enabled:false}).status,0);
  const settings = JSON.parse(fs.readFileSync(path.join(root,'settings.json')));
  assert.equal(settings.enabled,false); assert.equal(settings.imagePath,image);
  assert.notEqual(call(root,'apply',{enabled:true}).status,0);
  assert.equal(JSON.parse(fs.readFileSync(path.join(root,'settings.json'))).enabled,false);
});
test('status distinguishes saved settings from a fresh live application', t => {
  const {root} = fixture(t); const statusFile=path.join(root,'live-status.json');
  fs.writeFileSync(statusFile,JSON.stringify({state:'active',pid:process.pid,time:new Date(0).toISOString()}));
  let result=call(root,'state'); assert.equal(result.status,0,result.stderr);
  assert.equal(JSON.parse(result.stdout).live.running,false);
  const settingsHash=crypto.createHash('sha256').update(fs.readFileSync(path.join(root,'settings.json'))).digest('hex');
  fs.writeFileSync(statusFile,JSON.stringify({state:'active',pid:process.pid,time:new Date().toISOString(),mainReady:true,settingsHash}));
  result=call(root,'state'); assert.equal(result.status,0,result.stderr);
  assert.equal(JSON.parse(result.stdout).live.running,true);
  assert.equal(JSON.parse(result.stdout).live.mainReady,true);
  assert.equal(JSON.parse(result.stdout).live.applied,true);
  const changed=call(root,'apply',{blur:2});assert.equal(changed.status,0,changed.stderr);
  assert.equal(JSON.parse(changed.stdout).live.applied,false,'an older active acknowledgement cannot confirm new settings');
});
test('simultaneous GUI and skill saves preserve all requested fields', async t => {
  const {root,image}=fixture(t);
  const bytes=Buffer.alloc(16*1024*1024);fs.readFileSync(image).copy(bytes);fs.writeFileSync(image,bytes);
  const changes=[{brightness:.75},{blur:6},{tint:.25},{scope:'chat'}];
  const children=changes.map(change=>cp.fork(path.join(__dirname,'fixtures','save-settings.cjs'),[path.resolve(__dirname,'../scripts/settings-store.cjs'),root,JSON.stringify(change)],{silent:true,windowsHide:true}));
  t.after(()=>children.forEach(child=>{if(child.exitCode===null) child.kill();}));
  const completions=children.map(child=>new Promise((resolve,reject)=>{
    let error='';child.stderr.on('data',chunk=>{error+=chunk;});
    child.once('exit',code=>code===0?resolve():reject(new Error(error||'save process failed')));child.once('error',reject);
  }));
  await Promise.all(children.map(child=>new Promise((resolve,reject)=>{child.once('message',resolve);child.once('error',reject);})));
  children.forEach(child=>child.send('save'));
  await Promise.all(completions);
  const saved=JSON.parse(fs.readFileSync(path.join(root,'settings.json')));
  for(const change of changes) for(const [key,value] of Object.entries(change)) assert.equal(saved[key],value,key+' survives concurrent saves');
});
