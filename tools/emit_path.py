#!/usr/bin/env python3
"""Schreibt den Lernpfad (A0 und A1) als Swift-Daten."""
from pathlib import Path

# (phrase id, emoji)
def U(id, stage, title, words, dialogs):
    return dict(id=id, stage=stage, title=title, words=words, dialogs=dialogs)

UNITS = [
    U("a0-hallo", 1, "Hallo", [
        ("pol-01", "👋"), ("pol-05", "🙏"), ("pol-06", "💚"), ("pol-07", "😊"),
        ("pol-15", "☺️"), ("pol-16", "❓"), ("pol-18", "👋"),
    ], [
        ("h1", ("สวัสดี", "sà-wàt-dii", "Hallo."), ("สวัสดี", "sà-wàt-dii", "Hallo.")),
        ("h2", ("สบายดีไหม", "sà-baai-dii mǎi", "Wie geht's?"), ("สบายดี", "sà-baai-dii", "Mir geht's gut.")),
        ("h3", ("ขอบคุณ", "khɔ̀ɔp-khun", "Danke."), ("ไม่เป็นไร", "mâi-bpen-rai", "Gern geschehen.")),
    ]),
    U("a0-ja", 1, "Ja und Nein", [
        ("pol-09", "✅"), ("pol-10", "❌"), ("pol-11", "👍"), ("pol-12", "👎"),
        ("pol-02", "🙋"), ("pol-03", "🙋‍♀️"), ("pol-04", "❓"),
    ], [
        ("j1", ("ใช่ไหม", "châi mǎi", "Ja?"), ("ใช่", "châi", "Ja.")),
        ("j2", ("ได้ไหม", "dâai mǎi", "Geht das?"), ("ไม่ได้", "mâi-dâai", "Nein, geht nicht.")),
    ]),
    U("a0-zahlen", 1, "Zahlen 1–10", [
        ("num-01", "1️⃣"), ("num-02", "2️⃣"), ("num-03", "3️⃣"), ("num-04", "4️⃣"),
        ("num-05", "5️⃣"), ("num-06", "6️⃣"), ("num-07", "7️⃣"), ("num-08", "8️⃣"),
        ("num-09", "9️⃣"), ("num-10", "🔟"),
    ], [
        ("z1", ("หนึ่ง", "nʉ̀ng", "Eins."), ("สอง", "sɔ̌ɔng", "Zwei.")),
        ("z2", ("สิบ", "sìp", "Zehn."), ("ห้า", "hâa", "Fünf.")),
    ]),
    U("a0-toene", 1, "Fünf Töne", [
        ("ton-01", "🚶"), ("ton-06", "👋"), ("ton-02", "✨"), ("ton-03", "🚫"),
        ("ton-04", "🪵"), ("ton-05", "❓"), ("ton-07", "🐴"), ("ton-08", "🐶"),
    ], [
        ("t1", ("ใหม่", "mài", "Neu."), ("ไม่", "mâi", "Nicht.")),
        ("t2", ("หมา", "mǎa", "Hund."), ("ม้า", "máa", "Pferd.")),
    ]),
    U("a1-essen", 2, "Essen", [
        ("food-17", "🐷"), ("food-18", "🐔"), ("food-19", "🥩"), ("food-20", "🐟"),
        ("food-21", "🦐"), ("food-22", "🧈"), ("food-23", "🥦"), ("food-25", "🥭"),
        ("food-26", "🍈"), ("food-27", "🍌"), ("food-28", "🍍"), ("food-29", "🍎"),
        ("food-31", "🌶️"), ("food-32", "🧄"), ("food-35", "🥚"), ("food-36", "🍞"),
        ("food-01", "🍚"), ("food-05", "🍜"), ("food-06", "🥗"), ("food-12", "🍗"),
        ("food-15", "🍳"), ("food-16", "🍳"), ("food-37", "🥣"), ("tas-01", "😋"),
        ("tas-03", "🌶️"), ("tas-04", "🍯"), ("tas-06", "🍋"),
    ], [
        ("e1", ("เอาข้าว", "ao khàao", "Ich nehme Reis."), ("ได้", "dâai", "Okay.")),
        ("e2", ("อร่อยไหม", "à-rɔ̀i mǎi", "Lecker?"), ("อร่อย", "à-rɔ̀i", "Lecker.")),
    ]),
    U("a1-trinken", 2, "Trinken", [
        ("dri-01", "💧"), ("dri-02", "🥤"), ("dri-03", "🧊"), ("dri-05", "🍵"),
        ("dri-06", "🧋"), ("dri-07", "☕"), ("dri-08", "🧊"), ("dri-09", "🥛"),
        ("dri-10", "🍊"), ("dri-11", "🥥"), ("dri-12", "🍺"), ("dri-14", "🍷"),
    ], [
        ("d1", ("ขอน้ำ", "khɔ̌ɔ náam", "Wasser, bitte."), ("ได้เลย", "dâai ləəi", "Kommt sofort.")),
        ("d2", ("กาแฟ", "gaa-fɛɛ", "Kaffee."), ("ชา", "chaa", "Tee.")),
    ]),
    U("a1-bestellen", 2, "Bestellen", [
        ("res-01", "📋"), ("res-06", "🪑"), ("res-08", "🥄"), ("res-14", "✋"),
        ("res-16", "💳"), ("cls-gaew", "🥛"), ("cls-jaan", "🍽️"), ("cls-baht", "🪙"),
        ("mar-01", "💰"), ("food-05", "🍜"),
    ], [
        ("b1", ("ขอดูเมนู", "khɔ̌ɔ duu mee-nuu", "Die Karte, bitte."), ("เชิญ", "chəən", "Bitte sehr.")),
        ("b2", ("เช็คบิล", "chék bin", "Die Rechnung, bitte."), ("ได้", "dâai", "Okay.")),
    ]),
    U("a1-einkauf", 2, "Einkaufen", [
        ("mar-02", "💸"), ("mar-04", "🏷️"), ("mar-05", "📉"), ("mar-07", "👆"),
        ("mar-09", "🛍️"), ("mar-10", "🙅"), ("mar-12", "💐"), ("day-01", "💵"),
        ("cls-an", "📦"), ("plc-05", "🧺"),
    ], [
        ("k1", ("อันนี้เท่าไหร่", "an-níi thâo-rài", "Was kostet das?"), ("สิบบาท", "sìp bàat", "Zehn Baht.")),
        ("k2", ("แพงไป", "phaeng bpai", "Zu teuer."), ("ลดได้", "lót dâai", "Ich kann runtergehen.")),
    ]),
    U("a1-weg", 2, "Nach dem Weg", [
        ("way-01", "⬆️"), ("way-02", "⬅️"), ("way-03", "➡️"), ("way-04", "👈"),
        ("way-05", "👉"), ("way-08", "📍"), ("way-09", "🗺️"), ("way-15", "❓"),
        ("plc-01", "🏠"), ("plc-03", "🚻"), ("plc-07", "🍽️"), ("plc-12", "🛕"),
        ("plc-14", "🌊"), ("plc-15", "🏖️"), ("trn-02", "🚕"),
    ], [
        ("w1", ("ตรงไป", "dtrong bpai", "Geradeaus."), ("แล้วเลี้ยวซ้าย", "lɛ́ɛo líiao sâai", "Dann links.")),
        ("w2", ("ไกลไหม", "glai mǎi", "Ist es weit?"), ("ไม่ไกล", "mâi glai", "Nicht weit.")),
    ]),
    U("a1-familie", 2, "Familie", [
        ("fam-01", "👨"), ("fam-02", "👩"), ("fam-05", "🧒"), ("fam-06", "👦"),
        ("fam-07", "👧"), ("fam-08", "👴"), ("fam-09", "👵"), ("fam-12", "👦"),
        ("fam-13", "👧"), ("fam-16", "🤵"), ("fam-17", "👰"), ("fam-18", "👨‍👩‍👧"),
        ("pro-17", "💑"), ("pro-16", "🧑‍🤝‍🧑"),
    ], [
        ("f1", ("นี่แม่", "nîi mɛ̂ɛ", "Das ist Mama."), ("สวัสดี", "sà-wàt-dii", "Hallo.")),
        ("f2", ("นี่แฟน", "nîi fɛɛn", "Das ist mein Schatz."), ("ยินดีที่ได้รู้จัก", "yin-dii thîi dâai rúu-jàk", "Freut mich.")),
    ]),
    U("a1-zeit", 2, "Zeit", [
        ("tim-01", "📅"), ("tim-02", "⏭️"), ("tim-03", "⏮️"), ("tim-06", "🌅"),
        ("tim-08", "☀️"), ("tim-10", "🌆"), ("tim-12", "🌙"), ("tim-15", "⏱️"),
        ("tim-27", "1️⃣"), ("tim-31", "5️⃣"), ("tim-33", "☀️"), ("tim-35", "🕕"),
    ], [
        ("c1", ("วันนี้", "wan-níi", "Heute."), ("พรุ่งนี้", "phrûng-níi", "Morgen.")),
        ("c2", ("หกโมงเย็น", "hòk moong yen", "Sechs Uhr abends."), ("ได้", "dâai", "Okay.")),
    ]),
    U("a1-farben", 2, "Farben und Tiere", [
        ("col-02", "🔴"), ("col-03", "🟢"), ("col-04", "🟡"), ("col-05", "🔵"),
        ("col-06", "⚫"), ("col-07", "⚪"), ("col-08", "🟠"), ("col-09", "🩷"),
        ("col-10", "🟣"), ("ani-01", "🐶"), ("ani-02", "🐱"), ("ani-03", "🐘"),
        ("ani-04", "🐦"), ("ani-06", "🐴"), ("ani-07", "🦟"), ("ani-08", "🐄"),
    ], [
        ("r1", ("สีแดง", "sǐi dɛɛng", "Rot."), ("สีเขียว", "sǐi khìao", "Grün.")),
        ("r2", ("หมา", "mǎa", "Hund."), ("แมว", "mɛɛo", "Katze.")),
    ]),
    U("a1-unterwegs", 2, "Unterwegs", [
        ("trn-01", "🚗"), ("trn-02", "🚕"), ("trn-03", "🚌"), ("trn-05", "🚐"),
        ("trn-06", "⛵"), ("trn-09", "🎫"), ("plc-08", "🏨"), ("plc-10", "✈️"),
        ("plc-11", "🚉"), ("plc-13", "🏫"), ("bod-01", "🙂"), ("bod-03", "👁️"),
        ("bod-08", "✋"), ("clo-01", "👕"), ("clo-03", "👟"), ("clo-05", "👜"),
        ("wea-05", "🌧️"), ("wea-07", "☀️"), ("wea-02", "🥵"), ("day-02", "☎️"),
        ("day-03", "📱"), ("day-06", "🍲"),
    ], [
        ("u1", ("ไปไหน", "bpai nǎi", "Wohin?"), ("ไปตลาด", "bpai dtà-làat", "Zum Markt.")),
        ("u2", ("รถเมล์", "rót mee", "Der Bus."), ("ขอบคุณ", "khɔ̀ɔp-khun", "Danke.")),
    ]),
]

out = Path(__file__).resolve().parents[1] / "Sprachduett/Core/PathData.swift"
lines = []
lines.append("import Foundation")
lines.append("")
lines.append("enum PathData {")
lines.append("    static let refs: [UnitRef] = [")
for u in UNITS:
    lines.append("        UnitRef(")
    lines.append(f'            id: "{u["id"]}", stage: {u["stage"]}, title: "{u["title"]}",')
    lines.append("            words: [")
    for pid, emoji in u["words"]:
        lines.append(f'                WordRef(id: "{pid}", emoji: "{emoji}"),')
    lines.append("            ],")
    lines.append("            dialogs: [")
    for did, a, b in u["dialogs"]:
        lines.append(f'                DialogRef(id: "{did}",')
        lines.append(f'                    a: LineRef(thai: "{a[0]}", roman: "{a[1]}", german: "{a[2]}"),')
        lines.append(f'                    b: LineRef(thai: "{b[0]}", roman: "{b[1]}", german: "{b[2]}")),')
    lines.append("            ]")
    lines.append("        ),")
lines.append("    ]")
lines.append("}")
lines.append("")
out.write_text("\n".join(lines) + "\n", encoding="utf-8")
print(f"{len(UNITS)} units, {sum(len(u['words']) for u in UNITS)} words -> {out}")
