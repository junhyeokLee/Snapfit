from pathlib import Path
from xml.sax.saxutils import escape

from reportlab.pdfgen import canvas
from reportlab.lib import colors
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.platypus import Paragraph


ROOT = Path('/Users/devsheep/SnapFit/SnapFit')
OUT = ROOT / 'output/pdf/스냅핏_사업장_무상사용_확인서.pdf'
OUT.parent.mkdir(parents=True, exist_ok=True)
FONTS = ROOT / 'assets/fonts'
pdfmetrics.registerFont(TTFont('NotoKR', str(FONTS / 'NotoSansKR-Regular.ttf')))
pdfmetrics.registerFont(TTFont('NotoKR-Bold', str(FONTS / 'NotoSansKR-Bold.ttf')))

W, H = A4
LEFT, RIGHT = 54, W - 54
WIDTH = RIGHT - LEFT
INK = colors.HexColor('#202428')
MUTED = colors.HexColor('#59616A')
RULE = colors.HexColor('#9EA5AC')
PALE = colors.HexColor('#F3F4F5')

c = canvas.Canvas(str(OUT), pagesize=A4, pageCompression=1)
c.setTitle('스냅핏 사업장 무상사용 확인서')
c.setAuthor('스냅핏')
c.setSubject('가족 소유 주택 일부 공간의 사업장 무상사용 및 사업자등록 신청 확인')


def paragraph(text, x, top, width, size=11, leading=19, bold=False, color=INK):
    style = ParagraphStyle(
        'body', fontName='NotoKR-Bold' if bold else 'NotoKR',
        fontSize=size, leading=leading, textColor=color,
        spaceBefore=0, spaceAfter=0,
    )
    p = Paragraph(escape(text).replace('\n', '<br/>'), style)
    _, height = p.wrap(width, H)
    p.drawOn(c, x, top - height)
    return height


c.setFillColor(INK)
c.setFont('NotoKR-Bold', 23)
c.drawCentredString(W / 2, H - 86, '사업장 무상사용 확인서')
c.setFont('NotoKR', 10)
c.setFillColor(MUTED)
c.drawCentredString(W / 2, H - 111, '사업자등록 신청용')
c.setStrokeColor(INK)
c.setLineWidth(1.1)
c.line(LEFT, H - 133, RIGHT, H - 133)

rows = [
    ('상호', '스냅핏', 43),
    ('사용자 / 신청인', '이준혁', 43),
    ('사용 주소', '경기도 남양주시 별내5로 81\nKCC스위첸아파트 3106동 1704호', 63),
    ('사용 범위', '위 주택의 일부 공간', 43),
    ('사용 목적', '앱·웹서비스 개발 및 운영\n유료 디지털 템플릿·소재 및 AI 기능 제공\n맞춤 포토북 온라인 판매', 69),
    ('사용 조건', '보증금 및 사용료 없음(무상)', 43),
]
table_top = H - 163
table_height = sum(r[2] for r in rows)
label_width = 112
bottom = table_top - table_height
c.setFillColor(PALE)
c.rect(LEFT, bottom, label_width, table_height, fill=1, stroke=0)
c.setStrokeColor(RULE)
c.setLineWidth(0.65)
c.rect(LEFT, bottom, WIDTH, table_height, fill=0, stroke=1)
c.line(LEFT + label_width, bottom, LEFT + label_width, table_top)

y = table_top
for index, (label, value, row_height) in enumerate(rows):
    label_lines = paragraph(label, LEFT + 13, y - (row_height - 16) / 2,
                            label_width - 26, size=10, leading=16, bold=True)
    value_style = ParagraphStyle('value', fontName='NotoKR', fontSize=11,
                                leading=18, textColor=INK)
    p = Paragraph(escape(value).replace('\n', '<br/>'), value_style)
    _, ph = p.wrap(WIDTH - label_width - 30, row_height - 12)
    if ph > row_height - 12:
        raise ValueError(f'Row overflow: {label}')
    p.drawOn(c, LEFT + label_width + 15, y - (row_height + ph) / 2)
    y -= row_height
    if index < len(rows) - 1:
        c.line(LEFT, y, RIGHT, y)

consent = (
    '위 주택의 소유자는 위 주소 중 일부 공간을 이준혁이 “스냅핏”의 '
    '사업장으로 무상 사용하고, 해당 주소로 사업자등록을 신청하는 데 동의합니다.'
)
consent_height = paragraph(consent, LEFT + 2, bottom - 29, WIDTH - 4,
                           size=11.5, leading=21)

signature_top = bottom - 29 - consent_height - 43
c.setFont('NotoKR', 11)
c.setFillColor(INK)
c.drawString(LEFT + 8, signature_top, '확인·서명일')
c.drawRightString(RIGHT - 8, signature_top, '년                 월                 일')
c.setStrokeColor(RULE)
c.setLineWidth(0.6)
c.line(LEFT + 120, signature_top - 6, RIGHT - 8, signature_top - 6)

owner_y = signature_top - 60
c.setFont('NotoKR-Bold', 11)
c.drawString(LEFT + 8, owner_y, '소유자 성명')
c.setStrokeColor(INK)
c.line(LEFT + 111, owner_y - 7, LEFT + 278, owner_y - 7)
c.setFont('NotoKR', 11)
c.drawString(LEFT + 307, owner_y, '서명 또는 인')
c.line(LEFT + 307, owner_y - 35, RIGHT - 8, owner_y - 35)

c.setStrokeColor(RULE)
c.setLineWidth(0.5)
c.line(LEFT, 81, RIGHT, 81)
paragraph('소유자가 내용을 확인한 후 성명과 서명(또는 날인), 실제 서명일을 직접 기재해 주세요.',
          LEFT, 65, WIDTH, size=8.2, leading=13, color=MUTED)
c.setFont('NotoKR', 8)
c.setFillColor(MUTED)
c.drawString(LEFT, 32, '문서 작성일: 2026년 10월 28일')
c.drawRightString(RIGHT, 32, '1 / 1')

if owner_y - 35 < 105:
    raise ValueError('Signature area overlaps footer')
c.showPage()
c.save()
print(OUT)
