const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const os=require('node:os');
const path=require('node:path');
test('a portable installation record accepts an absolute Codex executable and rejects unsafe or missing targets',t=>{
  const {readInstallation}=require('../scripts/installation.cjs');
  const root=fs.mkdtempSync(path.join(os.tmpdir(),'wallpaper-installation-'));
  t.after(()=>{assert.ok(path.resolve(root).startsWith(path.join(os.tmpdir(),'wallpaper-installation-')));fs.rmSync(root,{recursive:true,force:true});});
  const executable=path.join(root,'ChatGPT.exe');fs.writeFileSync(executable,'fixture');
  const write=value=>fs.writeFileSync(path.join(root,'installation.json'),JSON.stringify({executable:value}));
  write(executable);assert.equal(readInstallation(root).executable,executable);
  for(const value of ['ChatGPT.exe',path.join(root,'missing','ChatGPT.exe'),path.join(root,'tool.cmd')]) {write(value);assert.throws(()=>readInstallation(root));}
  fs.unlinkSync(path.join(root,'installation.json'));assert.throws(()=>readInstallation(root),/configure/);
});
