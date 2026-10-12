"""Tarayıcıda gerçek kullanıcı hamleleri; Python Playwright ve Chromium gerekir.
Çalıştırma: python3 tests/browser-smoke.py (sunucu 127.0.0.1:8000 üzerinde açık).
Bu araç oyun bağımlılığı değildir; npm test saf Node.js testlerini çalıştırır.
"""
import json
import os
import tempfile
from pathlib import Path
from playwright.sync_api import sync_playwright

BASE = os.environ.get('DESTAN_TEST_URL', 'http://127.0.0.1:8000')

with sync_playwright() as pw:
    browser = pw.chromium.launch(executable_path='/usr/bin/chromium', headless=True, args=['--no-sandbox'])
    context = browser.new_context(viewport={'width': 1280, 'height': 900}, accept_downloads=True)
    page = context.new_page()
    errors = []
    page.on('pageerror', lambda error: errors.append(str(error)))
    response = page.goto(BASE)
    assert response.status == 200
    assert page.locator('#setup').is_visible()
    assert not page.locator('#match').is_visible()
    page.locator('#help-open').click()
    assert page.locator('#help').is_visible()
    page.locator('#help-close').click()
    page.locator('#collection-open').click()
    assert '30 altın' in page.locator('#wallet').inner_text()
    assert page.locator('#open-pack').is_disabled()
    page.locator('[data-inspect-id="26"]').click()
    assert 'Ergenekon' in page.locator('#detail-name').inner_text()
    assert 'tekrarlanmaz' in page.locator('#detail-text').inner_text()
    page.locator('#detail-close').click()
    page.locator('#collection-close').click()

    # Koleksiyon modu sahip olunmayan desteyi reddeder.
    page.locator('#owned-only').check()
    page.locator('#deck').select_option('tempo')
    page.locator('#new-game button[type="submit"]').click()
    assert 'eksik kart' in page.locator('#notice').inner_text()
    page.locator('#owned-only').uncheck()

    # Deste oluşturma: geçersiz 19 kart reddedilir, geçerli 20 kart seçilebilir.
    page.locator('summary').first.click()
    page.locator('[data-card-id="1"]').fill('1')
    page.locator('#use-custom').click()
    assert '20 kart' in page.locator('#notice').inner_text()
    page.locator('[data-card-id="1"]').fill('2')
    page.locator('#use-custom').click()
    assert page.locator('#deck').input_value() == 'custom'
    page.locator('summary').first.click()

    # Eğitim maçı gerçek düğmeler ve hedef seçimiyle tamamlanır.
    page.locator('#mode').select_option('story')
    page.locator('#chapter').select_option('1')
    page.locator('#new-game button[type="submit"]').click()
    assert not page.locator('#setup').is_visible()
    assert page.locator('#chapter-task').is_visible()
    targeted = False
    for _ in range(240):
        snapshot = page.evaluate("""async () => {
          const {restoreReplay}=await import('/oyun/engine.js');
          const {chooseBotAction}=await import('/oyun/bot.js');
          const saved=JSON.parse(localStorage.getItem('destan-v02-match'));
          const s=restoreReplay(saved.replay);
          return {status:s.status,active:s.active,action:s.active===0?chooseBotAction(s,0):null};
        }""")
        if snapshot['status'] == 'finished':
            break
        if snapshot['active'] == 1:
            page.wait_for_timeout(100)
            continue
        a = snapshot['action']
        if a['type'] == 'mulligan':
            for i in a['indices']:
                page.locator(f'#hand [data-index="{i}"]').click()
            page.locator('#confirm-mulligan').focus()
            page.keyboard.press('Enter')
        elif a['type'] == 'play':
            page.locator(f'#hand [data-index="{a["index"]}"]').click()
            if 'target' in a:
                targeted = True
                assert page.evaluate('document.activeElement.classList.contains("targetable")')
                page.locator(f'.targetable[data-target="{a["target"]}"]').click()
        elif a['type'] == 'attack':
            page.locator(f'#my-board [data-uid="{a["uid"]}"]').click()
            page.locator(f'.targetable[data-target="{a["target"]}"]').click()
        elif a['type'] == 'end':
            page.locator('#end-turn').click()
        elif a['type'] == 'discard':
            page.locator(f'#hand [data-index="{a["index"]}"]').click()
        elif a['type'] == 'scry':
            page.locator('#decision button').nth(1 if a['bottom'] else 0).click()
    else:
        raise AssertionError('Eğitim maçı bitmedi')
    assert targeted
    assert 'Görev tamamlandı' in page.locator('#result').inner_text()
    assert json.loads(page.evaluate("localStorage.getItem('destan-v02-story')")) == [1]
    assert not page.locator('#chapter option[value="2"]').evaluate('(option) => option.disabled')
    assert page.locator('#chapter option[value="3"]').evaluate('(option) => option.disabled')
    page.locator('#my-board .unit-info').first.click()
    assert page.locator('#detail-art').get_attribute('style')
    assert 'SAL' in page.locator('#detail-stats').inner_text()
    page.locator('#detail-close').click()
    page.locator('#feedback-open').click()
    page.locator('#feedback-fun').select_option('4')
    page.locator('#feedback-confusion').fill('Tuzakların sırasını öğrenmek istiyorum.')
    page.locator('#feedback-form button[type="submit"]').click()
    feedback = json.loads(page.evaluate("localStorage.getItem('destan-v02-feedback')"))
    assert len(feedback) == 1 and feedback[0]['fun'] == 4
    assert feedback[0]['seconds'] > 0
    page.locator('#collection-open').click()
    assert '130 altın' in page.locator('#wallet').inner_text()
    assert '1 ücretsiz paket' in page.locator('#wallet').inner_text()
    page.locator('#open-pack').click()
    assert '0 ücretsiz paket' in page.locator('#wallet').inner_text()
    assert page.locator('#pack-result').inner_text()
    page.on('dialog', lambda dialog: dialog.accept())
    for i in [1,2,3,5]:
        page.locator(f'[data-scrap-id="{i}"]').click()
    assert '40 toz' in page.locator('#wallet').inner_text()
    page.locator('[data-craft-id="1"]').click()
    assert '0 toz' in page.locator('#wallet').inner_text()
    page.locator('#collection-close').click()

    with page.expect_download() as download_info:
        page.locator('#export').click()
    with tempfile.TemporaryDirectory() as temp:
        export_path = Path(temp) / 'match.json'
        download_info.value.save_as(export_path)
        replay = json.loads(export_path.read_text())
        assert replay['version'] == '0.2' and len(replay['history']) > 10
        page.locator('#back').click()
        page.locator('#import-replay').set_input_files(str(export_path))
        assert page.locator('#result').is_visible()

    page.locator('#back').click()
    with page.expect_download() as feedback_download:
        page.locator('#feedback-export').click()
    with tempfile.TemporaryDirectory() as temp:
        csv_path=Path(temp)/'feedback.csv'
        feedback_download.value.save_as(csv_path)
        assert 'Tuzakların sırasını' in csv_path.read_text(encoding='utf-8-sig')
    page.reload()
    page.locator('#resume').click()
    assert page.locator('#result').is_visible()
    page.locator('#back').click()
    page.locator('#mode').select_option('practice')
    page.locator('#seed').fill('0')
    page.locator('#timed').check()
    page.locator('#new-game button[type="submit"]').click()
    page.set_viewport_size({'width': 390, 'height': 844})
    assert page.evaluate('document.documentElement.scrollWidth <= window.innerWidth')
    page.screenshot(path='/tmp/destan-mobile.png', full_page=True)
    page.set_viewport_size({'width':195,'height':844})
    assert page.evaluate('document.documentElement.scrollWidth <= window.innerWidth'), 'Dar/zoomlu görünüm taşıyor'
    page.set_viewport_size({'width':390,'height':844})
    page.locator('#confirm-mulligan').click()
    page.wait_for_function("JSON.parse(localStorage.getItem('destan-v02-match')).replay.history.length>=2")
    assert 'sn' in page.locator('#timer').inner_text()
    page.evaluate('Date.now = (() => { const original=Date.now; return () => original()+46000; })()')
    page.wait_for_function("JSON.parse(localStorage.getItem('destan-v02-match')).replay.history.some(e=>e.p===0&&e.action.type==='end')")

    # Baskı: 40 kartın ölçüsü, metin taşması ve altı A4 sayfa.
    print_page = context.new_page()
    print_page.on('pageerror', lambda error: errors.append(str(error)))
    print_page.goto(BASE + '/oyun/baski.html')
    print_page.wait_for_selector('.card')
    assert print_page.locator('.card').count() == 40
    assert print_page.locator('section').count() == 6
    checks = print_page.evaluate("""() => [...document.querySelectorAll('.card')].map(c=>({
      w:c.getBoundingClientRect().width,h:c.getBoundingClientRect().height,
      overflow:c.scrollHeight>c.clientHeight+1
    }))""")
    assert all(abs(c['w'] - 63 * 96 / 25.4) < 1 and abs(c['h'] - 88 * 96 / 25.4) < 1 for c in checks)
    assert not any(c['overflow'] for c in checks)
    print_page.pdf(path='/tmp/destan-kartlari-v02.pdf', format='A4', print_background=True, prefer_css_page_size=True)
    assert not errors, errors
    browser.close()
    print('Tarayıcı kontrolleri geçti: deste/sahiplik, hedefleme, eğitim/bölüm, koleksiyon/paket/üretim/parçalama, kayıt/ithal/yenileme, tur saati, mobil taşma, 40 baskı kartı ve PDF.')
