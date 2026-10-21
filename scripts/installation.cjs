const fs=require('node:fs');
const path=require('node:path');
function readInstallation(root){
  const file=path.join(root,'installation.json');
  if(!fs.existsSync(file)) throw new Error('Run scripts/configure.ps1 to locate the installed Codex application');
  const installation=JSON.parse(fs.readFileSync(file,'utf8').replace(/^\uFEFF/,''));
  const executable=installation.executable;
  if(typeof executable!=='string'||!path.isAbsolute(executable)||!['chatgpt.exe','codex.exe'].includes(path.basename(executable).toLowerCase())||!fs.existsSync(executable)||!fs.statSync(executable).isFile()) throw new Error('Invalid Codex installation; run scripts/configure.ps1 again');
  return installation;
}
module.exports={readInstallation};
