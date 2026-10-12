"""Kullanıcının dışa aktardığı maç değerlendirmelerini özetler; veri uydurmaz."""
import argparse
import csv
import statistics
from collections import Counter
from pathlib import Path

parser=argparse.ArgumentParser(description='Maç değerlendirme CSV özeti')
parser.add_argument('csv',type=Path)
args=parser.parse_args()
with args.csv.open(encoding='utf-8-sig',newline='') as f:
    records=list(csv.DictReader(f))
if not records:
    print('Değerlendirme kaydı yok.')
    raise SystemExit(0)
required={'matchId','mode','experience','fun','seconds','again','winner','first'}
if not required.issubset(records[0]):
    raise SystemExit('Bu dosya oyun içi değerlendirme CSV biçiminde değil.')
unique={r['matchId']:r for r in records}
records=list(unique.values())
ratings=[int(r['fun']) for r in records]
seconds=[int(r['seconds']) for r in records]
print(f'Maç değerlendirmesi: {len(records)} (oyuncu sayısı değildir)')
print(f'Ortalama eğlence: {statistics.mean(ratings):.2f}/5')
print(f'Ortanca aktif süre: {statistics.median(seconds):.0f} saniye')
print(f'Tekrar oynamak isteyen: {sum(r["again"]=="True" or r["again"]=="true" for r in records)}/{len(records)}')
for mode,count in sorted(Counter(r['mode'] for r in records).items()):
    print(f'{mode}: {count} kayıt')
print('Kayıtlar öz bildirimdir; otomatik test veya örnek dosyaları insan denge kanıtı olarak saymayın.')
