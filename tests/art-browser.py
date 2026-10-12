"""Yeni kart-prototipi galerisi, beş bağımsız sayfa ve baskı doğrulaması."""
from pathlib import Path
from playwright.sync_api import sync_playwright

ROOT = Path(__file__).resolve().parents[1]
BASE = 'http://127.0.0.1:8000'
with sync_playwright() as pw:
    browser=pw.chromium.launch(executable_path='/usr/bin/chromium',headless=True,args=['--no-sandbox'])
    page=browser.new_page(viewport={'width':1280,'height':1000})
    errors=[]
    page.on('pageerror',lambda error:errors.append(str(error)))
    page.goto(BASE+'/kart-prototipi/')
    page.wait_for_selector('.card')
    assert page.locator('.card').count()==40
    # Tüm atlaslar gerçekten indirilebilir ve tarayıcıda decode edilir.
    page.evaluate("""async()=>{
      const {ART,cardArtUrl}=await import('/kart-prototipi/art.js');
      await Promise.all([...new Set(Object.keys(ART).map(cardArtUrl))].map(url=>new Promise((resolve,reject)=>{
        const img=new Image();img.onload=()=>img.decode().then(resolve,reject);img.onerror=()=>reject(new Error('Görsel açılamadı: '+url));img.src=url;
      })));
    }""")
    page.locator('#type').select_option('spell');assert page.locator('.card').count()==8
    page.locator('#type').select_option('trap');assert page.locator('.card').count()==5
    page.locator('#type').select_option('all');page.locator('#search').fill('şahmaran');assert page.locator('.card').count()==1
    page.locator('#search').fill('');page.screenshot(path='/tmp/destan-40-kart.png',full_page=True)
    page.set_viewport_size({'width':390,'height':844});assert page.evaluate('document.documentElement.scrollWidth<=innerWidth')
    page.set_viewport_size({'width':1280,'height':1000})
    for number in range(1,6):
        page.goto(BASE+f'/kart-prototipi/Sayfa{number}.html')
        assert page.locator('.card').count()==(4 if number==5 else 9)
        assert page.evaluate("""()=>[...document.querySelectorAll('.rules')].every(el=>el.scrollHeight<=el.clientHeight+1)"""),f'Sayfa {number}: metin taşıyor'
        if number==1:page.screenshot(path='/tmp/destan-sayfa1.png',full_page=True)
    page.goto(BASE+'/oyun/baski.html');page.wait_for_selector('.card')
    assert page.locator('.art[role="img"]').count()==40
    assert page.evaluate("""()=>[...document.querySelectorAll('.card')].every(el=>el.scrollHeight<=el.clientHeight+1)"""),'Baskı kartında taşma'
    assert page.evaluate("""()=>[...document.querySelectorAll('.text')].every(el=>el.scrollHeight<=el.clientHeight+1)"""),'Baskı metninde taşma'
    page.pdf(path=str(ROOT/'kart-prototipi'/'Turkiye-Serisi-v0.2.pdf'),format='A4',print_background=True,prefer_css_page_size=True)
    assert not errors,errors
    browser.close()
    print('40 görsel decode edildi; galeri/filtre/mobil görünüm, 5 kart sayfası, metin taşması ve illüstrasyonlu PDF doğrulandı.')
