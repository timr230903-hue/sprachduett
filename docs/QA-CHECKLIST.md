# QA-Checkliste

Vor dem Release-Kandidaten gelesen. `swift test` prüft den Fachkern. Der Simulator prüft Start, Runde und Zurück. Was ein Mikrofon oder eine echte Stimme braucht, steht unten offen.

## Navigation

- [x] Start, Einstellungen, Runde, Alltags-Check, Tutorial, Duo, Feedback, Ton-Duell, Schrift, eigene Sätze, Reise, Rollenspiel und die Teilkarte haben Zurück, Fertig oder Schließen.
- [x] Die Runde fragt „Runde pausieren?“ und der Start bietet Weiterspielen.
- [x] Wischen vom Rand ist auf Runde und Alltags-Check an.
- [x] Leerer Lernpfad und leere Tonpaare zeigen einen Satz, keinen Absturz.
- [x] Hör & Zeig erklärt den Ablauf in einem Satz, nennt die aktive Person, gibt das Handy weiter und wertet nur gemeinsam.

## Sprache

- [x] Info.plist bittet um Spracherkennung und Mikrofon.
- [x] Locale `th-TH`, on-device, sonst Server. Leise oder fremde Laute sind rot, nie ein Treffer.
- [x] Langsam ist höchstens halb so schnell wie normal (`SpeechPace`).
- [x] Liegt `Audio/<id>.m4a` im Bundle, spielt sie im normalen Tempo. Langsam und fehlende Dateien nutzen die Synthese. Die 300 Sätze stehen in `docs/AUDIO-SCRIPT.csv`. Es sind keine erfundenen Aufnahmen im Bundle.
- [ ] Am Gerät: Pegel, Live-Text, Silbenfarben, Haptik, hörbar langsames Tempo, und ob eine echte Aufnahme die Stimme ersetzt.

## Aussehen und Zugang

- [x] Farben nur in `Theme.swift`. Creme hell, Nacht dunkel, Gold als Text im Hellen dunkel und im Dunkeln hell. Knöpfe Nachtblau mit weißer Schrift.
- [x] Titel nutzen Textstile und `minimumScaleFactor`. Schilder und Emoji bleiben fest, damit sie wie ein Bild wirken.
- [x] Banner, Bilder, Schilder und das Wort des Tages haben VoiceOver-Namen. Die Bildwahl sagt „Bild 1“ und nicht die Lösung.
- [x] Die Übergabe im Duett blendet mit einer Feder, außer Bewegung reduzieren ist an.
- [ ] Am Gerät: heller und dunkler Modus, größte Schrift, VoiceOver einmal durch Start und Hör & Zeig.

## Inhalt

- [x] Tutorial ist ein Satz und vier Karten, die zum Sagen-und-Zeigen passen.
- [x] Links und rechts wählen ผม/ครับ oder ฉัน/ค่ะ. Die Umschrift blendet aus, wenn das Wort sitzt.
- [x] Alltagssprache: kein อรุณสวัสดิ์, kein ราตรีสวัสดิ์, kein ดิฉัน. ข้าว ist `khâao`.
- [x] Ton-Duell, Schrift pro Tag, Reise offline, eigene Karten, erzeugte Geräusche, Teilkarte, Abend-Hinweis ohne Serienverlust, nur Thai als Sprache.

## Vor dem Upload

- [x] `swift test` grün.
- [x] Diese Liste gegen den Stand gelesen.
- [ ] Simulator-Navigation in CI grün.
