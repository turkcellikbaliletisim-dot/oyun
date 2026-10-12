const ROOT=new URL('./',self.location.href);
const PREFIX='destan-static:'+ROOT.pathname+':';
const CACHE=PREFIX+'v02-2';
const CORE=['online.html','oyun/online.js','index.html','manifest.webmanifest','oyun/icon.svg','oyun/style.css','oyun/app.js','oyun/engine.js','oyun/cards.js','oyun/decks.js','oyun/bot.js','oyun/chapters.js','oyun/economy.js','oyun/playtest.js','oyun/pwa.js','oyun/sound.js','oyun/baski.html','oyun/print.js','kart-prototipi/art.js','kart-prototipi/index.html','kart-prototipi/gallery.js','kart-prototipi/style.css','kart-prototipi/Main.html',...Array.from({length:5},(_,i)=>`kart-prototipi/Sayfa${i+1}.html`)];
const ATLAS=Array.from({length:10},(_,i)=>`kart-prototipi/gorseller/${String(i*4+1).padStart(2,'0')}-${String(i*4+4).padStart(2,'0')}.png`);
const url=path=>new URL(path,ROOT).href;
const core=new Set(CORE.map(url)),art=new Set(ATLAS.map(url));
self.addEventListener('install',event=>event.waitUntil((async()=>{const cache=await caches.open(CACHE);await cache.addAll(CORE.map(url));if(!self.registration.active)await self.skipWaiting();})()));
self.addEventListener('activate',event=>event.waitUntil((async()=>{
  for(const key of await caches.keys())if(key.startsWith(PREFIX)&&key!==CACHE)await caches.delete(key);
  await self.clients.claim();
})()));
self.addEventListener('fetch',event=>{
  const request=event.request,target=new URL(request.url);
  if(request.method!=='GET'||target.origin!==ROOT.origin)return;
  let key=new URL(target.href);key.search='';key.hash='';
  if(key.pathname.endsWith('/'))key=new URL('index.html',key);
  if(!core.has(key.href)&&!art.has(key.href))return; // API, hesap ve ödül yanıtları önbelleğe alınmaz.
  event.respondWith((async()=>{
    const cache=await caches.open(CACHE),cached=await cache.match(key.href);
    if(art.has(key.href)&&cached)return cached;
    try{
      const response=await fetch(request);
      if(response.ok)await cache.put(key.href,response.clone());
      return response;
    }catch(error){if(cached)return cached;throw error;}
  })());
});
self.addEventListener('message',event=>{
  const port=event.ports[0];
  if(event.data?.type==='ACTIVATE'){self.skipWaiting();return;}
  if(event.data?.type!=='CACHE_ART'&&event.data?.type!=='STATUS')return;
  event.waitUntil((async()=>{
    try{
      const cache=await caches.open(CACHE);
      let done=0;
      for(const path of ATLAS){
        const key=url(path);
        if(event.data.type==='CACHE_ART'&&!(await cache.match(key))){const response=await fetch(key);if(!response.ok)throw new Error('Kart indirmesi tamamlanamadı.');await cache.put(key,response);}
        if(await cache.match(key))done++;
        if(event.data.type==='CACHE_ART')port?.postMessage({type:'progress',done,total:10});
      }
      port?.postMessage({type:'complete',done,total:10});
    }catch(error){port?.postMessage({type:'error',message:error.message});}
  })());
});
