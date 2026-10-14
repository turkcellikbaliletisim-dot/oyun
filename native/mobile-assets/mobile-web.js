'use strict';
window.destanDownload=(text,name)=>{
 const blob=new Blob([text],{type:name.endsWith('.json')?'application/json':'text/plain;charset=utf-8'});
 const link=document.createElement('a');link.download=name.replace(/[^\w.\-]/g,'_');link.href=URL.createObjectURL(blob);document.body.append(link);link.click();
 setTimeout(()=>{URL.revokeObjectURL(link.href);link.remove();},1000);
};
const shell=document.createElement('div');shell.id='mobile-controls';
const full=document.createElement('button');full.textContent='Tam ekran';full.setAttribute('aria-label','Oyunu tam ekran aç');
full.onclick=async()=>{try{await document.documentElement.requestFullscreen();if(screen.orientation?.lock)await screen.orientation.lock('landscape');}catch{}};
shell.append(full);document.body.append(shell);
const rotate=document.createElement('aside');rotate.id='rotate-tip';rotate.innerHTML='<strong>DESTAN DİYARLARI</strong><span>Telefonunu yatay çevir</span><p>Kart masası yatay ekranda oynanır.</p>';
document.body.append(rotate);
const style=document.createElement('style');style.textContent=`#mobile-controls{position:fixed;bottom:6px;right:8px;z-index:20}#mobile-controls button{background:#17252cbd;color:#dfc17f;border:1px solid #897348;border-radius:7px;min-height:32px;padding:4px 10px;font:12px sans-serif}#rotate-tip{display:none;position:fixed;inset:0;z-index:40;align-items:center;justify-content:center;flex-direction:column;background:linear-gradient(150deg,#223741,#0b1720);color:#dfc17f;text-align:center;padding:24px;font:16px system-ui}#rotate-tip strong{font-family:serif;font-size:24px;margin-bottom:42px}#rotate-tip span{font-size:22px}#rotate-tip p{color:#c4cdd1}canvas{touch-action:none}@media(orientation:portrait) and (max-width:900px){#rotate-tip{display:flex}}:fullscreen #mobile-controls{display:none}`;
document.head.append(style);
