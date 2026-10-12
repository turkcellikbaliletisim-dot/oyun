import {randomBytes,randomInt,randomUUID,createHash,timingSafeEqual} from 'node:crypto';
import {createGame,applyAction,validateDeck,RuleError,exportReplay,legalActions} from '../oyun/engine.js';
import {chooseBotAction} from '../oyun/bot.js';
import {CHAPTERS,chapterOptions,chapterCompleted} from '../oyun/chapters.js';
import {DECKS} from '../oyun/decks.js';
import {newProfile,loginReward,matchReward,chapterReward,deckOwned,openPack,craftCard,dismantleCard,archiveCard} from '../oyun/economy.js';
import {Store} from './store.js';

export class ApiError extends Error{constructor(status,message){super(message);this.status=status;}}
const check=(ok,status,message)=>{if(!ok)throw new ApiError(status,message);};
const hash=value=>createHash('sha256').update(value).digest('hex');
const secret=()=>randomBytes(32).toString('hex');
const day=now=>new Intl.DateTimeFormat('sv-SE',{timeZone:'Europe/Istanbul',year:'numeric',month:'2-digit',day:'2-digit'}).format(new Date(now));
const entropy=()=>Array.from({length:80},()=>randomInt(0,4294967296));
const requestId=id=>check(typeof id==='string'&&/^[A-Za-z0-9_-]{1,80}$/.test(id),400,'Geçerli işlem kimliği gerekli.');
const canonical=value=>JSON.stringify((function ordered(v){return Array.isArray(v)?v.map(ordered):v&&typeof v==='object'?Object.fromEntries(Object.keys(v).sort().map(k=>[k,ordered(v[k])])):v;})(value));
export const league=mmr=>mmr<1000?'Çırak':mmr<1200?'Kalfa':mmr<1400?'Usta':mmr<1600?'Destancı':'Efsane';

export class Service {
  constructor(store,data,now){this.store=store;this.data=data;this.now=now;this.tail=Promise.resolve();this.dirty=false;this.presence=new Map();}
  static async open(dir,now=Date.now){const store=new Store(dir),data=await store.load();if(data.seasonStarted==null)data.seasonStarted=now();return new Service(store,data,now);}
  call(fn){
    const task=this.tail.then(async()=>{
      const preTick=structuredClone(this.data);this.dirty=false;this.tick();
      try{if(this.dirty)await this.store.save(this.data);}catch(error){this.data=preTick;throw error;}
      const before=structuredClone(this.data);this.dirty=false;
      try{const result=fn();if(this.dirty)await this.store.save(this.data);return result;}
      catch(error){this.data=before;if(error instanceof RuleError)throw new ApiError(422,error.message);throw error;}
    });
    this.tail=task.catch(()=>{});return task;
  }
  mark(){this.dirty=true;}
  session(token){
    if(typeof token!=='string'||!/^[a-f0-9]{64}$/.test(token))return null;
    const entry=this.data.sessions[hash(token)];return entry&&entry.expires>this.now()&&this.data.users[entry.userId]?entry:null;
  }
  auth(token,csrf,write=false){
    const session=this.session(token);check(session,401,'Oturum bulunamadı. Hesabını aç veya kurtar.');
    if(write)check(typeof csrf==='string'&&/^[a-f0-9]{64}$/.test(csrf)&&timingSafeEqual(Buffer.from(csrf),Buffer.from(session.csrf)),403,'İşlem doğrulanamadı. Sayfayı yenile.');
    this.presence.set(session.userId,this.now());
    return this.data.users[session.userId];
  }
  account(user,token){
    const history=Object.values(this.data.matches).filter(m=>m.users.includes(user.id)&&m.game?.status==='finished').sort((a,b)=>b.created-a.created).slice(0,20).map(m=>({id:m.id,kind:m.kind,chapterId:m.chapterId??0,turns:m.game.turn,result:m.game.winner==null?'draw':m.users[m.game.winner]===user.id?'win':'loss'}));
    return {id:user.id,profile:structuredClone(user.profile),mmr:user.mmr,placements:user.placements,league:league(user.mmr),matchId:user.matchId,queued:this.data.queue.some(q=>q.userId===user.id),history,csrf:this.session(token).csrf};
  }
  newSession(user){const token=secret();this.data.sessions[hash(token)]={userId:user.id,csrf:secret(),expires:this.now()+30*86400000};this.mark();return token;}
  bootstrap(token){return this.call(()=>{
    let session=this.session(token),user,recoveryKey;
    if(session)user=this.data.users[session.userId];
    else{recoveryKey=secret();user={id:randomUUID(),recoveryHash:hash(recoveryKey),profile:newProfile(),mmr:1000,placements:0,matchId:null,ops:{}};this.data.users[user.id]=user;token=this.newSession(user);}
    user.profile=loginReward(user.profile,day(this.now()));this.mark();
    this.presence.set(user.id,this.now());
    return {token,recoveryKey,account:this.account(user,token)};
  });}
  recover(key){return this.call(()=>{
    check(typeof key==='string'&&/^[a-f0-9]{64}$/.test(key),400,'Kurtarma anahtarı geçersiz.');
    const digest=hash(key),user=Object.values(this.data.users).find(u=>u.recoveryHash===digest);check(user,401,'Kurtarma anahtarı doğrulanamadı.');
    const token=this.newSession(user);user.profile=loginReward(user.profile,day(this.now()));return {token,account:this.account(user,token)};
  });}
  me(token){return this.call(()=>this.account(this.auth(token),token));}
  rotateKey(token,csrf){return this.call(()=>{const user=this.auth(token,csrf,true),key=secret();user.recoveryHash=hash(key);this.mark();return {recoveryKey:key};});}
  checkFree(user){const match=this.data.matches[user.matchId];check(!match||match.game?.status==='finished'||match.status==='cancelled',409,'Önce mevcut maçı bitir.');}
  ownDeck(user,deck){validateDeck(deck);check(deckOwned(user.profile,deck),403,'Destede koleksiyonunda olmayan kartlar var.');return [...deck];}
  start(match){
    match.game=createGame({decks:match.decks,seed:0,entropy:entropy()});match.status='playing';match.deadline=this.now()+45000;match.version++;this.mark();
  }
  room(token,csrf,deck){return this.call(()=>{
    const user=this.auth(token,csrf,true);this.checkFree(user);check(!this.data.queue.some(q=>q.userId===user.id),409,'Önce eşleştirmeyi iptal et.');
    const alphabet='ABCDEFGHJKLMNPQRSTUVWXYZ23456789';let code;
    do{code=Array.from({length:8},()=>alphabet[randomInt(alphabet.length)]).join('');}while(Object.values(this.data.matches).some(m=>m.code===code));
    const match={id:randomUUID(),code,kind:'friendly',users:[user.id,null],decks:[this.ownDeck(user,deck),null],status:'waiting',game:null,version:0,deadline:null,misses:[0,0],requests:{},settled:false,created:this.now()};
    this.data.matches[match.id]=match;user.matchId=match.id;this.mark();return this.view(match,0);
  });}
  join(token,csrf,code,deck){return this.call(()=>{
    const user=this.auth(token,csrf,true);this.checkFree(user);check(!this.data.queue.some(q=>q.userId===user.id),409,'Önce eşleştirmeyi iptal et.');
    check(typeof code==='string'&&/^[A-Z2-9]{8}$/.test(code),400,'Oda kodu sekiz karakter olmalı.');
    const match=Object.values(this.data.matches).find(m=>m.code===code&&m.status==='waiting'&&m.kind==='friendly');check(match,404,'Açık oda bulunamadı.');check(match.users[0]!==user.id,409,'Kendi odana rakip olarak katılamazsın.');
    match.users[1]=user.id;match.decks[1]=this.ownDeck(user,deck);user.matchId=match.id;this.start(match);return this.view(match,1);
  });}
  solo(token,csrf,chapterId,deck){return this.call(()=>{
    const user=this.auth(token,csrf,true);this.checkFree(user);check(!this.data.queue.some(q=>q.userId===user.id),409,'Önce eşleştirmeyi iptal et.');
    check(Number.isInteger(chapterId)&&chapterId>=0&&chapterId<=10,400,'Bölüm geçersiz.');check(chapterId<=1||user.profile.chapterRewards.includes(chapterId-1),403,'Önce önceki bölümü tamamla.');
    const chapter=CHAPTERS[chapterId-1],options=chapter?chapterOptions(chapter,0):{decks:[this.ownDeck(user,deck),DECKS.tempo.cards],seed:0};
    const match={id:randomUUID(),code:null,kind:chapter?'story':'bot',chapterId,users:[user.id,null],decks:options.decks,status:'playing',game:createGame({...options,entropy:entropy()}),version:1,deadline:null,misses:[0,0],requests:{},settled:false,created:this.now()};
    this.data.matches[match.id]=match;user.matchId=match.id;this.bot(match);this.mark();return this.view(match,0);
  });}
  member(token,id){const user=this.auth(token),match=this.data.matches[id],p=match?.users.indexOf(user.id);check(match&&p>=0,404,'Maç bulunamadı.');return {user,match,p};}
  getMatch(token,id){return this.call(()=>{const {match,p}=this.member(token,id);return this.view(match,p);});}
  view(match,p){
    const result={id:match.id,code:match.code,kind:match.kind,chapterId:match.chapterId??0,status:match.status,version:match.version,deadline:match.deadline,serverNow:this.now(),state:null};
    if(!match.game)return result;
    const s=match.game,order=[p,1-p];
    result.state={version:s.version,nextUid:s.nextUid,status:s.status,active:s.active===p?0:1,first:s.first===p?0:1,turn:s.turn,phase:s.phase,winner:s.winner==null?null:s.winner===p?0:1,reason:s.reason,log:s.log.map(line=>line.replaceAll('Destancı',p===0?'Sen':'Rakip').replaceAll('Gölge',p===1?'Sen':'Rakip')),pending:s.pending?(s.active===p?structuredClone(s.pending):{kind:'waiting'}):null,
      players:order.map((actual,index)=>{
        const player=s.players[actual];
        return {hp:player.hp,energy:player.energy,maxEnergy:player.maxEnergy,turns:player.turns,half:player.half,hand:index===0?[...player.hand]:Array(player.hand.length).fill(null),deck:Array(player.deck.length).fill(null),board:structuredClone(player.board),traps:index===0?structuredClone(player.traps):Array(player.traps.length).fill({hidden:true}),grave:structuredClone(player.grave),stats:index===0?structuredClone(player.stats):null,mulliganPinned:index===0?[...player.mulliganPinned]:[]};
      })};
    if(s.pending?.kind==='scry'&&s.active===p)result.state.players[0].deck[0]=s.players[p].deck[0];
    result.actions=legalActions(result.state,0);
    return result;
  }
  action(token,csrf,id,version,request,action){return this.call(()=>{
    const user=this.auth(token,csrf,true),{match,p}=this.member(token,id);requestId(request);
    const key=user.id+':'+request,digest=hash(canonical({version,action}));
    if(match.requests[key]){check(match.requests[key]===digest,409,'İşlem kimliği başka hamlede kullanıldı.');return this.view(match,p);}
    check(match.game,409,'Rakip henüz katılmadı.');check(Number.isInteger(version)&&version===match.version,409,'Maç ilerledi. Güncel durumu yükle.');
    const translated=structuredClone(action);
    if(/^hero:[01]$/.test(translated.target??''))translated.target=`hero:${Number(translated.target.slice(-1))===0?p:1-p}`;
    const previousTurn=match.game.turn,previousActive=match.game.active;
    match.game=applyAction(match.game,p,translated);match.version++;match.requests[key]=digest;match.misses[p]=0;
    if(match.kind==='friendly'||match.kind==='ranked'){
      if(match.game.turn!==previousTurn||match.game.active!==previousActive)match.deadline=this.now()+45000;
    }
    this.bot(match);this.settle(match);this.mark();return this.view(match,p);
  });}
  bot(match){
    if(match.kind!=='story'&&match.kind!=='bot')return;
    let steps=0;
    while(match.game.status!=='finished'&&match.game.active===1){
      check(++steps<=100,500,'Bot turu tamamlanamadı.');
      const chapter=CHAPTERS[match.chapterId-1],action=chapter?.passive&&match.game.status==='playing'&&!match.game.pending?{type:'end'}:chooseBotAction(match.game,1);
      match.game=applyAction(match.game,1,action);match.version++;
    }
    this.settle(match);
  }
  settle(match){
    if(match.game?.status!=='finished'||match.settled)return;
    match.settled=true;match.status='finished';match.deadline=null;match.finished=this.now();
    for(let p=0;p<2;p++){
      const user=this.data.users[match.users[p]];if(!user)continue;
      const state={status:'finished',winner:match.game.winner==null?null:match.game.winner===p?0:1,turn:match.game.turn,history:match.game.history.map(e=>({...e,p:e.p===p?0:1})),players:[match.game.players[p]]};
      user.profile=loginReward(user.profile,day(this.now()));user.profile=matchReward(user.profile,{id:match.id,state,day:day(this.now()),chapterId:match.chapterId});
      if(p===0&&match.kind==='story'&&chapterCompleted(CHAPTERS[match.chapterId-1],match.game))user.profile=chapterReward(user.profile,match.chapterId);
    }
    if(match.kind==='ranked'){
      const [a,b]=match.users.map(id=>this.data.users[id]);
      if(a&&b){const expected=1/(1+10**((b.mmr-a.mmr)/400)),score=match.game.winner===null?.5:match.game.winner===0?1:0;
        const delta=Math.round(Math.min(a.placements<10?40:24,b.placements<10?40:24)*(score-expected));a.mmr+=delta;b.mmr-=delta;a.placements++;b.placements++;}
    }
    this.mark();
  }
  queue(token,csrf,deck){return this.call(()=>{
    const user=this.auth(token,csrf,true);this.checkFree(user);check(user.profile.chapterRewards.includes(10),403,'Lig için hikâye finalini tamamla.');
    check(!this.data.queue.some(q=>q.userId===user.id),409,'Zaten eşleştirme bekliyorsun.');
    user.matchId=null;this.data.queue.push({userId:user.id,deck:this.ownDeck(user,deck),since:this.now()});this.matchQueue();this.mark();return this.account(user,token);
  });}
  cancelQueue(token,csrf){return this.call(()=>{const user=this.auth(token,csrf,true);this.data.queue=this.data.queue.filter(q=>q.userId!==user.id);this.mark();return this.account(user,token);});}
  matchQueue(){
    for(let i=0;i<this.data.queue.length;i++)for(let j=i+1;j<this.data.queue.length;j++){
      const a=this.data.queue[i],b=this.data.queue[j],ua=this.data.users[a.userId],ub=this.data.users[b.userId];
      const width=q=>Math.min(300,100+Math.floor((this.now()-q.since)/15000)*50);
      if(!ua||!ub||Math.abs(ua.mmr-ub.mmr)>Math.min(width(a),width(b)))continue;
      const match={id:randomUUID(),kind:'ranked',code:null,users:[a.userId,b.userId],decks:[a.deck,b.deck],status:'waiting',game:null,version:0,deadline:null,misses:[0,0],requests:{},settled:false,created:this.now()};
      this.data.matches[match.id]=match;ua.matchId=match.id;ub.matchId=match.id;this.data.queue.splice(j,1);this.data.queue.splice(i,1);this.start(match);this.mark();return this.matchQueue();
    }
  }
  wallet(token,csrf,operation,id,request){return this.call(()=>{
    const user=this.auth(token,csrf,true);requestId(request);const digest=hash(canonical({operation,id:id??null}));
    if(user.ops[request]){check(user.ops[request].digest===digest,409,'İşlem kimliği başka istekte kullanıldı.');return {...structuredClone(user.ops[request].result),account:this.account(user,token)};}
    user.profile=loginReward(user.profile,day(this.now()));let result={};
    try{
      if(operation==='pack'){const pack=openPack(user.profile,()=>randomInt(0,4294967296)/4294967296);user.profile=pack.profile;result.rewards=pack.rewards;}
      else if(operation==='craft')user.profile=craftCard(user.profile,id);
      else if(operation==='dismantle')user.profile=dismantleCard(user.profile,id);
      else if(operation==='archive')user.profile=archiveCard(user.profile,id);
      else throw new ApiError(400,'İşlem bulunamadı.');
    }catch(error){if(error instanceof ApiError)throw error;throw new ApiError(422,error.message);}
    user.ops[request]={digest,result};this.mark();return {...result,account:this.account(user,token)};
  });}
  replay(token,id){return this.call(()=>{const {match}=this.member(token,id);check(match.game?.status==='finished',409,'Maç bitmeden gizli kart kaydı indirilemez.');return exportReplay(match.game);});}
  leave(token,csrf,id){return this.call(()=>{
    const user=this.auth(token,csrf,true),{match,p}=this.member(token,id);
    if(match.game&&match.game.status!=='finished'){match.game=applyAction(match.game,p,{type:'surrender'});match.version++;this.settle(match);}
    if(!match.game)match.status='cancelled';user.matchId=null;this.mark();return this.account(user,token);
  });}
  remove(token,csrf){return this.call(()=>{
    const user=this.auth(token,csrf,true),match=this.data.matches[user.matchId];
    if(match?.game&&match.game.status!=='finished'){match.game=applyAction(match.game,match.users.indexOf(user.id),{type:'surrender'});match.version++;this.settle(match);}
    if(match?.status==='waiting')match.status='cancelled';
    for(const entry of Object.values(this.data.matches))entry.users=entry.users.map(id=>id===user.id?null:id);
    for(const entry of Object.values(this.data.matches))for(const key of Object.keys(entry.requests))if(key.startsWith(user.id+':'))delete entry.requests[key];
    for(const [key,session] of Object.entries(this.data.sessions))if(session.userId===user.id)delete this.data.sessions[key];
    this.data.queue=this.data.queue.filter(q=>q.userId!==user.id);delete this.data.users[user.id];this.mark();return {deleted:true};
  });}
  tick(){
    const queue=this.data.queue.filter(q=>this.now()-(this.presence.get(q.userId)??q.since)<60000&&this.data.users[q.userId]);
    if(queue.length!==this.data.queue.length){this.data.queue=queue;this.mark();}
    for(const match of Object.values(this.data.matches)){
      if(match.status==='waiting'&&this.now()-match.created>15*60000){match.status='cancelled';const owner=this.data.users[match.users[0]];if(owner?.matchId===match.id)owner.matchId=null;this.mark();continue;}
      if(!match.game||match.game.status==='finished'||match.deadline===null||match.deadline>this.now())continue;
      const p=match.game.active;match.misses[p]++;
      if(match.misses[p]>=2)match.game=applyAction(match.game,p,{type:'surrender'});
      else if(match.game.status==='mulligan')match.game=applyAction(match.game,p,{type:'mulligan',indices:[]});
      else{
        while(match.game.pending&&match.game.status!=='finished')match.game=applyAction(match.game,p,match.game.pending.kind==='scry'?{type:'scry',bottom:false}:{type:'discard',index:0});
        if(match.game.status!=='finished')match.game=applyAction(match.game,p,{type:'end'});
      }
      match.version++;match.deadline=this.now()+45000;match.turnDeadline=match.deadline;match.lastTurn=match.game.turn;this.settle(match);this.mark();
    }
    this.matchQueue();
    if(this.now()-this.data.seasonStarted>=56*86400000){for(const user of Object.values(this.data.users)){user.mmr=Math.round(1000+.5*(user.mmr-1000));user.placements=0;}this.data.seasonStarted=this.now();this.mark();}
  }
}
