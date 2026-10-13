#!/usr/bin/env python3
"""Build the same Godot game for Web/Android/iOS using project-local tools."""
import argparse,hashlib,json,os,re,subprocess,sys
from pathlib import Path
from urllib.parse import urlsplit
ROOT=Path(__file__).resolve().parent.parent
TOOLS=ROOT/'.mobile-tools'
GODOT=TOOLS/'godot/Godot'
PRESETS={'web':('Web Mobile','native-builds/web/index.html'),'android':('Android Development','native-builds/android/DestanDiyarlari.apk'),'ios':('iOS Development','native-builds/ios/DestanDiyarlari.zip')}
def run(*args,**kwargs):return subprocess.run([str(a) for a in args],cwd=ROOT,check=True,**kwargs)
def sha(path):
 h=hashlib.sha256()
 with path.open('rb') as f:
  for block in iter(lambda:f.read(1024*1024),b''):h.update(block)
 return h.hexdigest()
def prepare_web(folder):
 html=folder/'index.html'
 source=html.read_text()
 import shutil
 shutil.copy2(ROOT/'native/mobile-assets/mobile-web.js',folder/'mobile-controls.js')
 source=source.replace('</body>','<script src="mobile-controls.js"></script></body>')
 blocks=[]
 def extract(match):
  name='boot-%d.js'%len(blocks)
  (folder/name).write_text(match.group(1))
  blocks.append(name)
  return '<script src="%s"></script>'%name
 source=re.sub(r'<script\s*>(.*?)</script>',extract,source,flags=re.S|re.I)
 html.write_text(source)
 # Package compression is served by the Node host, not the game service worker.
 script="import{brotliCompressSync,constants}from'node:zlib';import{readdirSync,readFileSync,writeFileSync}from'node:fs';const dir=process.argv[1];for(const name of readdirSync(dir)){if(/\\.(wasm|js|pck)$/.test(name)){writeFileSync(dir+'/'+name+'.br',brotliCompressSync(readFileSync(dir+'/'+name),{params:{[constants.BROTLI_PARAM_QUALITY]:5}}));}}"
 run('node','--input-type=module','-e',script,folder)
def main():
 parser=argparse.ArgumentParser()
 parser.add_argument('platform',choices=PRESETS)
 parser.add_argument('--server-url',default='')
 parser.add_argument('--team-id',default=os.environ.get('DESTAN_APPLE_TEAM_ID',''))
 args=parser.parse_args()
 if not GODOT.exists():parser.error('Run the project-local mobile tool setup first.')
 url=args.server_url
 if not url and (ROOT/'.mobile-server.env').exists():
  for line in (ROOT/'.mobile-server.env').read_text().splitlines():
   if line.startswith('DESTAN_PUBLIC_URL='):url=line.split('=',1)[1].strip()
 if url:
  parsed=urlsplit(url)
  if parsed.scheme!='https' or not parsed.hostname or parsed.username or parsed.password or parsed.path not in ('','/') or parsed.query or parsed.fragment:parser.error('Use an HTTPS origin without credentials/path/query.')
  url=url.rstrip('/')
 if args.platform=='ios':
  if not Path('/Applications/Xcode.app/Contents/Developer').is_dir():parser.error('Full Xcode is required to build/sign the iOS application. Web Mobile already supports iPhone browsers.')
  if not re.fullmatch('[A-Z0-9]{10}',args.team_id):parser.error('Supply your Apple Team ID with --team-id (10 characters).')
 config=ROOT/'native/client.json'
 old=config.read_bytes()
 presets=ROOT/'export_presets.cfg'
 old_presets=presets.read_bytes()
 env=os.environ.copy()
 env['JAVA_HOME']=str(TOOLS/'java/Contents/Home')
 env['ANDROID_HOME']=str(TOOLS/'android-sdk')
 if args.platform=='ios':env['DEVELOPER_DIR']='/Applications/Xcode.app/Contents/Developer'
 name,relative=PRESETS[args.platform]
 destination=ROOT/relative
 destination.parent.mkdir(parents=True,exist_ok=True)
 try:
  config.write_text(json.dumps({'server_url':url},ensure_ascii=False)+'\n')
  if args.platform=='ios':presets.write_text(old_presets.decode().replace('application/app_store_team_id=""','application/app_store_team_id="'+args.team_id+'"'))
  run(GODOT,'--headless','--path',ROOT,'--editor','--import','--quit',env=env)
  run(GODOT,'--headless','--path',ROOT,'--export-debug',name,destination,env=env)
  if args.platform=='web':prepare_web(destination.parent)
  if args.platform=='android':
   signer=TOOLS/'android-sdk/build-tools/36.0.0/apksigner'
   run(signer,'verify','--verbose',destination,env=env)
   downloads=ROOT/'native-builds/web/downloads'
   downloads.mkdir(parents=True,exist_ok=True)
   import shutil
   shutil.copy2(destination,downloads/destination.name)
  report={'platform':args.platform,'version':'0.3.0','godot':'4.7.2','server_url':url,'file':relative,'bytes':destination.stat().st_size,'sha256':sha(destination),'signing':'development' if args.platform=='android' else 'pending Apple signing' if args.platform=='ios' else 'not applicable'}
  (destination.parent/'build.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
  print(json.dumps(report,ensure_ascii=False,indent=2))
 finally:
  config.write_bytes(old)
  presets.write_bytes(old_presets)
if __name__=='__main__':main()
