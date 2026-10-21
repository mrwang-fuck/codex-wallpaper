const fs = require('node:fs');
const path = require('node:path');
const {readState,updateSettings} = require('./settings-store.cjs');
async function main() {
  const args = process.argv.slice(2);
  const action = args.shift();
  let root = path.resolve(__dirname,'..');
  if (args.length) {
    if (args.length !== 2 || args[0] !== '--root' || !path.isAbsolute(args[1])) throw new Error('无效的设置目录');
    root = path.resolve(args[1]);
  }
  if (action === 'apply') {
    const input = fs.readFileSync(0,'utf8').replace(/^\uFEFF/,'');
    if (Buffer.byteLength(input) > 65536) throw new Error('设置数据过大');
    await updateSettings(root,JSON.parse(input));
  } else if (action !== 'state') throw new Error('用法：node control.cjs state|apply [--root 完整目录]；apply 从标准输入读取 JSON');
  process.stdout.write(JSON.stringify(readState(root)) + '\n');
}
main().catch(error=>{process.stderr.write(JSON.stringify({error:error.message}) + '\n');process.exitCode=1;});
