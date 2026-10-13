import {createApp} from '../server/http.js';
import {resolve} from 'node:path';
const app=await createApp({dataDir:resolve('.data/mobile-local'),mobileDir:resolve('native-builds/web')});
app.server.listen(8082,'127.0.0.1',()=>console.log('Mobile local preview: http://127.0.0.1:8082/mobile/'));
const stop=async()=>{await app.close();process.exit(0);};
process.on('SIGINT',stop);process.on('SIGTERM',stop);
