import {createServer} from 'node:http';
import {createReadStream} from 'node:fs';
import {stat,realpath} from 'node:fs/promises';
import {resolve,join,extname,sep} from 'node:path';
import {fileURLToPath} from 'node:url';
import {Service,ApiError} from './service.js';
import {Store} from './store.js';

const ROOT=fileURLToPath(new URL('../',import.meta.url));
const MIME={'.html':'text/html; charset=utf-8','.js':'text/javascript; charset=utf-8','.css':'text/css; charset=utf-8','.json':'application/json; charset=utf-8','.webmanifest':'application/manifest+json','.svg':'image/svg+xml','.png':'image/png','.pdf':'application/pdf','.md':'text/plain; charset=utf-8','.wasm':'application/wasm','.pck':'application/octet-stream','.apk':'application/vnd.android.package-archive','.zip':'application/zip'};
const fail=(ok,status,message)=>{if(!ok)throw new ApiError(status,message);};
function keys(body,allowed){fail(body&&typeof body==='object'&&!Array.isArray(body),400,'JSON nesnesi gerekli.');fail(Object.keys(body).every(k=>allowed.includes(k)),400,'İstekte desteklenmeyen alan var.');}
function cleanAction(action){
  fail(action&&typeof action==='object'&&!Array.isArray(action),400,'Hamle nesnesi gerekli.');
  const allowed={mulligan:['type','indices'],play:['type','index','target'],attack:['type','uid','target'],end:['type'],surrender:['type'],scry:['type','bottom'],discard:['type','index']}[action.type];
  fail(allowed,400,'Hamle türü geçersiz.');keys(action,allowed);return action;
}
async function jsonBody(req){
  fail(req.headers['content-type']?.split(';')[0]==='application/json',415,'JSON içerik türü gerekli.');
  let size=0,parts=[];
  for await(const chunk of req){size+=chunk.length;if(size<=16384)parts.push(chunk);}
  fail(size<=16384,413,'İstek çok büyük.');
  try{return JSON.parse(Buffer.concat(parts).toString('utf8')||'{}');}catch{throw new ApiError(400,'JSON okunamadı.');}
}
function cookie(req){const item=(req.headers.cookie??'').split(';').map(s=>s.trim()).find(s=>s.startsWith('destan_session='));return item?.slice('destan_session='.length);}
function sessionCookie(token,secure,remove=false){return `destan_session=${remove?'':token}; HttpOnly; SameSite=Strict; Path=/; Max-Age=${remove?0:2592000}${secure?'; Secure':''}`;}
function send(res,status,body,headers={}){
  const text=JSON.stringify(body);res.writeHead(status,{'Content-Type':'application/json; charset=utf-8','Cache-Control':'no-store',...headers});res.end(text);
}
export async function createApp({dataDir=join(ROOT,'.data'),now=Date.now,origin,production=false,mobileDir=process.env.DESTAN_MOBILE_DIR??join(ROOT,'mobile')}={}){
  if(production&&(!origin||!origin.startsWith('https://')))throw new Error('Üretim için HTTPS APP_ORIGIN gerekli.');
  const release=await new Store(dataDir).acquire();let service;
  try{service=await Service.open(dataDir,now);}catch(error){await release();throw error;}
  const rates=new Map();let server,closing;
  server=createServer(async(req,res)=>{
    res.setHeader('X-Content-Type-Options','nosniff');res.setHeader('Referrer-Policy','same-origin');
    res.setHeader('Content-Security-Policy',"default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; connect-src 'self'; worker-src 'self'; object-src 'none'; base-uri 'self'; frame-ancestors 'self'");
    try{
      const path=new URL(req.url,'http://localhost').pathname,token=cookie(req),csrf=req.headers['x-destan-csrf'];
      if(path.startsWith('/mobile/'))res.setHeader('Content-Security-Policy',"default-src 'self'; script-src 'self' 'wasm-unsafe-eval'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; connect-src 'self'; worker-src 'self'; object-src 'none'; base-uri 'self'; frame-ancestors 'self'");
      if(path.startsWith('/api/')){
        const rateKey=service.session(token)?.userId??req.socket.remoteAddress,rate=rates.get(rateKey)??{since:now(),count:0};
        if(now()-rate.since>=60000){rate.since=now();rate.count=0;}rate.count++;rates.set(rateKey,rate);fail(rate.count<=360,429,'Çok sık istek gönderildi. Biraz bekle.');
        if(rates.size>10000)for(const [key,entry]of rates)if(now()-entry.since>60000)rates.delete(key);
        const unsafe=!['GET','HEAD'].includes(req.method);
        if(unsafe){const expected=origin?[origin]:[`http://127.0.0.1:${server.address().port}`,`http://localhost:${server.address().port}`];fail(expected.includes(req.headers.origin),403,'İstek kaynağı doğrulanamadı.');}
        const body=unsafe?await jsonBody(req):null;let result;
        if(req.method==='POST'&&path==='/api/session'){keys(body,[]);const session=await service.bootstrap(token);send(res,200,{...session.account,...(session.recoveryKey?{recoveryKey:session.recoveryKey}:{})},{'Set-Cookie':sessionCookie(session.token,production)});return;}
        if(req.method==='POST'&&path==='/api/recover'){keys(body,['key']);const session=await service.recover(body.key);send(res,200,session.account,{'Set-Cookie':sessionCookie(session.token,production)});return;}
        if(req.method==='GET'&&path==='/api/health')result={ready:true,version:'0.2'};
        else if(req.method==='GET'&&path==='/api/me')result=await service.me(token);
        else if(req.method==='POST'&&path==='/api/recovery-key'){keys(body,[]);result=await service.rotateKey(token,csrf);}
        else if(req.method==='POST'&&path==='/api/rooms'){keys(body,['deck']);result=await service.room(token,csrf,body.deck);}
        else if(req.method==='POST'&&path==='/api/join'){keys(body,['code','deck']);result=await service.join(token,csrf,body.code,body.deck);}
        else if(req.method==='POST'&&path==='/api/solo'){keys(body,['chapterId','deck']);result=await service.solo(token,csrf,body.chapterId,body.deck);}
        else if(req.method==='POST'&&path==='/api/queue'){keys(body,['deck']);result=await service.queue(token,csrf,body.deck);}
        else if(req.method==='POST'&&path==='/api/queue/cancel'){keys(body,[]);result=await service.cancelQueue(token,csrf);}
        else if(req.method==='DELETE'&&path==='/api/account'){keys(body,[]);result=await service.remove(token,csrf);res.setHeader('Set-Cookie',sessionCookie('',production,true));}
        else if(req.method==='POST'&&path==='/api/uga/score'){keys(body,['world','wave']);result=await service.ugaScore(token,csrf,body.world,body.wave);}
        else if(req.method==='POST'&&path==='/api/uga/race'){keys(body,['world']);result=await service.ugaRaceCreate(token,csrf,body.world);}
        else {
          const board=/^\/api\/uga\/board\/([0-4])$/.exec(path);
          const race=/^\/api\/uga\/race\/([A-Z0-9]{6})(?:\/(result))?$/.exec(path);
          if(board&&req.method==='GET'){result=await service.ugaBoard(token,Number(board[1]));send(res,200,result);return;}
          if(race&&req.method==='GET'&&!race[2]){result=await service.ugaRace(token,race[1]);send(res,200,result);return;}
          if(race&&req.method==='POST'&&race[2]==='result'){keys(body,['wave']);result=await service.ugaRaceResult(token,csrf,race[1],body.wave);send(res,200,result);return;}
          const match=/^\/api\/matches\/([a-f0-9-]{36})(?:\/(actions|leave|replay))?$/.exec(path);
          const wallet=/^\/api\/collection\/(pack|craft|dismantle|archive)$/.exec(path);
          if(match&&req.method==='GET'&&!match[2])result=await service.getMatch(token,match[1]);
          else if(match&&req.method==='GET'&&match[2]==='replay')result=await service.replay(token,match[1]);
          else if(match&&req.method==='POST'&&match[2]==='leave'){keys(body,[]);result=await service.leave(token,csrf,match[1]);}
          else if(match&&req.method==='POST'&&match[2]==='actions'){keys(body,['version','requestId','action']);result=await service.action(token,csrf,match[1],body.version,body.requestId,cleanAction(body.action));}
          else if(wallet&&req.method==='POST'){keys(body,['cardId','requestId']);if(wallet[1]!=='pack')fail(Number.isInteger(body.cardId),400,'Kart numarası gerekli.');result=await service.wallet(token,csrf,wallet[1],body.cardId,body.requestId);}
          else throw new ApiError(404,'İşlem bulunamadı.');
        }
        send(res,200,result);return;
      }
      fail(req.method==='GET'||req.method==='HEAD',405,'Yöntem desteklenmiyor.');
      const decoded=decodeURIComponent(path);fail(!decoded.split('/').some(part=>part.startsWith('.')),404,'Dosya bulunamadı.');
      const mobile=decoded==='/mobile'||decoded.startsWith('/mobile/');
      const staticRoot=(mobile?await realpath(resolve(mobileDir)):resolve(ROOT))+sep;
      const relative=mobile?decoded.slice('/mobile'.length)||'/':decoded;
      let file=resolve(staticRoot,'.'+relative);fail(file===staticRoot.slice(0,-1)||file.startsWith(staticRoot),404,'Dosya bulunamadı.');
      let info=await stat(file);if(info.isDirectory()){file=join(file,'index.html');info=await stat(file);}
      const actual=await realpath(file);fail(actual.startsWith(staticRoot),404,'Dosya bulunamadı.');
      const mime=MIME[extname(file)];fail(mime,404,'Dosya bulunamadı.');
      let encoding={};
      if(mobile&&/\bbr\b/.test(req.headers['accept-encoding']??'')&&['.wasm','.js','.pck'].includes(extname(file))){
        try{const compressed=await realpath(file+'.br');fail(compressed.startsWith(staticRoot),404,'Dosya bulunamadı.');const packed=await stat(compressed);file=compressed;info=packed;encoding={'Content-Encoding':'br',Vary:'Accept-Encoding'};}catch(error){if(error instanceof ApiError)throw error;if(error.code!=='ENOENT')throw error;}
      }
      res.writeHead(200,{'Content-Type':mime,'Content-Length':info.size,'Cache-Control':extname(file)==='.png'?'public, max-age=86400':'no-cache',...encoding});
      if(req.method==='HEAD'){res.end();return;}
      createReadStream(file).on('error',()=>res.destroy()).pipe(res);
    }catch(error){
      const status=error.status??(error.code==='ENOENT'?404:500);
      send(res,status,{error:error instanceof ApiError?error.message:status===404?'Dosya bulunamadı.':'İşlem tamamlanamadı. Yeniden dene.'});
    }
  });
  server.requestTimeout=15000;server.headersTimeout=10000;
  const timer=setInterval(()=>service.call(()=>null).catch(()=>{}),250);timer.unref();
  const finalize=()=>closing??=(async()=>{clearInterval(timer);await service.tail;await release();})();
  server.on('close',finalize);
  const close=async()=>{await new Promise(resolve=>server.close(resolve));await finalize();};
  return {server,service,close};
}
if(process.argv[1]&&resolve(process.argv[1])===fileURLToPath(import.meta.url)){
  const production=process.env.NODE_ENV==='production',port=Number(process.env.PORT??8080),host=process.env.HOST??'127.0.0.1';
  try{
    const app=await createApp({dataDir:process.env.DESTAN_DATA_DIR??join(ROOT,'.data'),origin:process.env.APP_ORIGIN,production});
    app.server.listen(port,host,()=>process.stdout.write(`Destan sunucusu ${host}:${port} üzerinde hazır.\n`));
    const stop=async()=>{await app.close();process.exit(0);};process.on('SIGTERM',stop);process.on('SIGINT',stop);
  }catch{process.stderr.write('Sunucu başlatılamadı. Ortam ayarlarını ve kayıt/yedek dosyalarını kontrol edin.\n');process.exitCode=1;}
}
