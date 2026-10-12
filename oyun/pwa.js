const download=document.getElementById('offline-download'),status=document.getElementById('offline-status'),install=document.getElementById('install-app'),update=document.getElementById('update-app');
let registration,installEvent;
function workerMessage(type,onProgress=()=>{}){
  return new Promise(async(resolve,reject)=>{
    try{
      const reg=registration??await navigator.serviceWorker.ready,worker=reg.active;
      if(!worker)throw new Error('Çevrimdışı hazırlık henüz hazır değil.');
      const channel=new MessageChannel(),timeout=setTimeout(()=>reject(new Error('İndirme yanıtı gecikti. Bağlantını kontrol edip yeniden dene.')),120000);
      channel.port1.onmessage=event=>{const data=event.data;if(data.type==='progress')onProgress(data);else{clearTimeout(timeout);channel.port1.close();data.type==='error'?reject(new Error(data.message)):resolve(data);}};
      worker.postMessage({type},[channel.port2]);
    }catch(error){reject(error);}
  });
}
if('serviceWorker'in navigator&&isSecureContext){
  const scope=new URL('../',import.meta.url).pathname;
  navigator.serviceWorker.getRegistration(scope).then(async existing=>{
    if(existing){if(navigator.onLine)existing.update().catch(()=>{});return existing;}
    return navigator.serviceWorker.register(new URL('../sw.js',import.meta.url),{scope});
  }).then(async reg=>{
    registration=reg;await navigator.serviceWorker.ready;download.disabled=false;
    const state=await workerMessage('STATUS');status.textContent=state.done===10?'40 kart çevrimdışı kullanıma hazır.':'Oyunu çevrimdışı açabilirsin. Tüm kart resimleri için indirme seçeneğini kullan.';
    if(reg.waiting)update.hidden=false;
    reg.addEventListener('updatefound',()=>{const worker=reg.installing;worker?.addEventListener('statechange',()=>{if(worker.state==='installed'&&navigator.serviceWorker.controller)update.hidden=false;});});
  }).catch(()=>{status.textContent='Çevrimdışı hazırlık yapılamadı. Bağlantı varken oyun normal çalışır.';});
}else status.textContent='Bu tarayıcıda çevrimdışı kurulum desteklenmiyor; bağlantı varken oynayabilirsin.';
download.addEventListener('click',async()=>{
  download.disabled=true;
  try{const result=await workerMessage('CACHE_ART',progress=>{status.textContent=`Kart görselleri hazırlanıyor: ${progress.done*4}/40`;});status.textContent=result.done===10?'40 kart çevrimdışı kullanıma hazır.':'İndirme tamamlanmadı; yeniden deneyebilirsin.';}catch(error){status.textContent=error.message;}finally{download.disabled=false;}
});
window.addEventListener('beforeinstallprompt',event=>{event.preventDefault();installEvent=event;install.hidden=false;});
install.addEventListener('click',async()=>{await installEvent?.prompt();install.hidden=true;installEvent=null;});
window.addEventListener('appinstalled',()=>{install.hidden=true;status.textContent='Destan Diyarları cihaza eklendi.';});
let updating=false;
update.addEventListener('click',()=>{window.dispatchEvent(new Event('destan-save'));updating=true;registration?.waiting?.postMessage({type:'ACTIVATE'});});
navigator.serviceWorker?.addEventListener('controllerchange',()=>{if(updating)location.reload();});
