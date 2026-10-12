"""İki bağımsız tarayıcı hesabı, gerçek UI hamleleri ve hesap kurtarma."""
import os
import tempfile
from pathlib import Path
from playwright.sync_api import sync_playwright
BASE=os.environ['DESTAN_ONLINE_URL']

with sync_playwright() as pw:
    browser=pw.chromium.launch(executable_path='/usr/bin/chromium',headless=True,args=['--no-sandbox'])
    ca=browser.new_context(viewport={'width':1280,'height':900},accept_downloads=True)
    cb=browser.new_context(viewport={'width':390,'height':844})
    a=ca.new_page();b=cb.new_page();errors=[]
    for page in [a,b]:page.on('pageerror',lambda error:errors.append(str(error)));page.on('dialog',lambda dialog:dialog.accept())
    a.goto(BASE+'/online.html');b.goto(BASE+'/online.html')
    for page in [a,b]:page.wait_for_selector('#online-lobby:not([hidden])')
    # Kurtarma anahtarı test değişkenlerinde kalır; çıktı veya ekran görüntüsü yok.
    saved_key=a.locator('#recovery-key').input_value()
    assert len(saved_key)==64
    assert '30 altın' in a.locator('#account-summary').inner_text()
    assert a.locator('#join-queue').is_disabled()
    assert b.evaluate('document.documentElement.scrollWidth<=innerWidth')
    a.locator('#create-room').click();a.wait_for_selector('#waiting-room:not([hidden])')
    code=a.locator('#room-code').inner_text();assert len(code)==8
    b.locator('#join-code').fill(code);b.locator('#join-room').click()
    for page in [a,b]:page.wait_for_selector('#online-confirm-mulligan') if page is a else None
    a.locator('#online-confirm-mulligan').click()
    b.wait_for_selector('#online-confirm-mulligan');b.locator('#online-confirm-mulligan').click()
    # İki oyuncu için normalize edilmiş durumdaki legal hamleleri DOM üzerinden uygula.
    saw_board=False
    for step in range(60):
        choice=None
        for page in [a,b]:
            state=page.evaluate("""async()=>{
              const me=await (await fetch('/api/me')).json();
              const room=await (await fetch('/api/matches/'+me.matchId)).json();
              const {chooseBotAction}=await import('/oyun/bot.js');
              return {status:room.status,active:room.state.active,action:room.state.active===0?chooseBotAction(room.state):null};
            }""")
            if state['status']=='finished':break
            if state['active']==0:choice=(page,state['action']);break
        if state['status']=='finished':break
        page,action=choice
        # Polling UI'nin sunucu durumunu yakalaması.
        page.wait_for_function("()=>document.querySelector('#online-turn').textContent.includes('Senin turun')")
        if action['type']=='play':
            page.locator(f'#online-hand [data-index="{action["index"]}"]').click()
            if action.get('target'):
                page.locator(f'.targetable[data-target="{action["target"]}"]').click()
        elif action['type']=='attack':
            page.locator(f'#online-my-board [data-uid="{action["uid"]}"]').click();page.locator(f'.targetable[data-target="{action["target"]}"]').click()
        else:page.locator('#online-end').click()
        page.wait_for_timeout(80)
        if a.locator('#online-my-board .unit-info').count() and not saw_board:
            a.locator('#online-my-board .unit-info').first.click();assert a.locator('#online-detail-art').get_attribute('style');a.locator('#online-detail-close').click();saw_board=True
        if step==8:
            b.reload();b.wait_for_selector('#online-match:not([hidden])')
    assert saw_board
    # Teslim, sonucu diğer tarayıcıya aktarır. Ardından sunucu hikâyesi ve ödül.
    a.locator('#leave-match').click();a.wait_for_selector('#online-lobby:not([hidden])')
    a.locator('#start-server-story').click();a.wait_for_selector('#online-confirm-mulligan')
    a.locator('#online-confirm-mulligan').click()
    for _ in range(100):
        snapshot=a.evaluate("""async()=>{
          const me=await (await fetch('/api/me')).json();const room=await (await fetch('/api/matches/'+me.matchId)).json();
          const {chooseBotAction}=await import('/oyun/bot.js');return {finished:room.status==='finished',action:room.status==='finished'?null:chooseBotAction(room.state)};
        }""")
        if snapshot['finished']:break
        action=snapshot['action']
        if action['type']=='play':
            a.locator(f'#online-hand [data-index="{action["index"]}"]').click()
            if action.get('target'):a.locator(f'.targetable[data-target="{action["target"]}"]').click()
        elif action['type']=='attack':
            a.locator(f'#online-my-board [data-uid="{action["uid"]}"]').click();a.locator(f'.targetable[data-target="{action["target"]}"]').click()
        else:a.locator('#online-end').click()
        a.wait_for_timeout(80)
    else:raise AssertionError('Sunucu eğitim maçı bitmedi')
    a.wait_for_selector('#online-result:not([hidden])')
    assert 'ödül hesabına eklendi' in a.locator('#online-result').inner_text()
    a.locator('#online-collection-open').click();assert '1 ücretsiz paket' in a.locator('#online-wallet').inner_text()
    a.locator('#online-pack').click();a.wait_for_function("()=>document.querySelector('#online-wallet').textContent.includes('0 ücretsiz paket')")
    assert a.locator('#online-pack-result').inner_text()
    a.locator('#online-collection-close').click()
    with a.expect_download() as download:
        a.locator('#online-replay').click()
    with tempfile.TemporaryDirectory() as temp:
        path=Path(temp)/'replay.json';download.value.save_as(path);assert 'entropy' in path.read_text()
    # Üçüncü temiz tarayıcı aynı hesabı anahtarla geri alır, ödülü tekrar vermez.
    cc=browser.new_context();c=cc.new_page();c.on('pageerror',lambda error:errors.append(str(error)));c.goto(BASE+'/online.html');c.wait_for_selector('#online-lobby:not([hidden])')
    c.get_by_text('Hesabını koru veya kurtar',exact=True).click();c.locator('#recover-input').fill(saved_key);c.locator('#recover-account').click()
    c.wait_for_selector('#online-result:not([hidden])')
    c.locator('#online-collection-open').click();assert '0 ücretsiz paket' in c.locator('#online-wallet').inner_text()
    assert not errors,errors
    browser.close()
    print('İki tarayıcı: oda/katılma, gerçek hamleler, mobil görünüm, yeniden bağlantı, sunucu hikâye ödülü/paket, maç kaydı ve üçüncü cihazda hesap kurtarma geçti.')
