"""Uygulama ve kırk kartın gerçek çevrimdışı tarayıcı doğrulaması."""
from playwright.sync_api import sync_playwright
BASE='http://127.0.0.1:8000'
with sync_playwright() as pw:
    browser=pw.chromium.launch(executable_path='/usr/bin/chromium',headless=True,args=['--no-sandbox'])
    context=browser.new_context(viewport={'width':390,'height':844})
    page=context.new_page();errors=[];page.on('pageerror',lambda error:errors.append(str(error)))
    page.goto(BASE)
    page.wait_for_function("document.querySelector('#offline-download').disabled===false",timeout=30000)
    manifest=page.evaluate("async()=>await (await fetch('/manifest.webmanifest')).json()")
    assert manifest['display']=='standalone' and manifest['lang']=='tr'
    page.get_by_text('Telefona ekle ve çevrimdışı oyna',exact=True).click()
    page.locator('#offline-download').click()
    page.wait_for_function("document.querySelector('#offline-status').textContent.includes('40 kart çevrimdışı')",timeout=120000)
    page.reload();page.wait_for_function('navigator.serviceWorker.controller!==null')
    context.set_offline(True)
    page.reload();page.wait_for_selector('#new-game')
    page.locator('#mode').select_option('story')
    page.locator('#new-game button[type="submit"]').click();page.locator('#confirm-mulligan').click()
    page.wait_for_function("document.querySelector('#my-hero').textContent.includes('Enerji')")
    page.locator('#music-toggle').click();assert page.locator('#music-toggle').get_attribute('aria-pressed')=='true'
    page.locator('#sound-toggle').click();assert page.locator('#sound-toggle').get_attribute('aria-pressed')=='true'
    page.locator('#back').click()
    page.goto(BASE+'/kart-prototipi/');page.wait_for_selector('.card');assert page.locator('.card').count()==40
    page.evaluate("""async()=>{
      const {ART,cardArtUrl}=await import('/kart-prototipi/art.js');
      await Promise.all([...new Set(Object.keys(ART).map(cardArtUrl))].map(url=>new Promise((resolve,reject)=>{
        const img=new Image();img.onload=()=>img.decode().then(resolve,reject);img.onerror=()=>reject(new Error(url));img.src=url;
      })));
    }""")
    page.goto(BASE+'/oyun/baski.html');page.wait_for_selector('.card');assert page.locator('.card').count()==40
    assert not errors,errors
    browser.close()
    print('PWA: shell, yeni hikâye maçı, ses/müzik, 40 resim, galeri ve baskı internet kapalıyken çalıştı.')
