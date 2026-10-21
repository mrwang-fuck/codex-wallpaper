const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const os=require('node:os');
const path=require('node:path');
const {shouldApplyToURL,readSettings}=require('../scripts/runtime.cjs');
test('wallpaper targets the main app page and excludes pets, sandbox frames and external sites',()=>{
  assert.equal(shouldApplyToURL('app://-/index.html'),true);
  for(const url of ['app://-/detached-window.html','app://other/index.html','https://example.com/index.html','codex-sandbox://example.com/','invalid']) assert.equal(shouldApplyToURL(url),false);
});
test('disabled wallpaper needs no image and enabled settings validate image bytes',t=>{
  const root=fs.mkdtempSync(path.join(os.tmpdir(),'wallpaper-runtime-test-'));
  t.after(()=>{assert.ok(path.resolve(root).startsWith(path.join(os.tmpdir(),'wallpaper-runtime-test-')));fs.rmSync(root,{recursive:true,force:true});});
  const config=path.join(root,'settings.json');
  fs.writeFileSync(config,JSON.stringify({enabled:false,imagePath:'missing.png'}));
  assert.equal(readSettings(config).enabled,false);
  const image=path.join(root,'example.jpg');
  fs.writeFileSync(image,Buffer.from([137,80,78,71,13,10,26,10,0,0,0,0]));
  fs.writeFileSync(config,JSON.stringify({enabled:true,imagePath:image,brightness:99,blur:-4}));
  const value=readSettings(config);assert.equal(value.brightness,2);assert.equal(value.blur,0);
  assert.equal(value.dataUri.startsWith('data:image/png;base64,'),true);
  fs.writeFileSync(image,'<svg xmlns="http://www.w3.org/2000/svg"></svg>');
  assert.throws(()=>readSettings(config),/PNG|JPEG|WebP/);
});
