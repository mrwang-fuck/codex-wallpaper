const {updateSettings}=require(process.argv[2]);
process.send('ready');
process.once('message',()=>Promise.resolve().then(()=>updateSettings(process.argv[3],JSON.parse(process.argv[4]))).then(()=>process.disconnect()).catch(error=>{console.error(error);process.exit(1);}));
