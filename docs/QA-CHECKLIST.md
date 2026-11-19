# QA-Checkliste

Vor dem Release-Kandidaten gelesen. `swift test` prüft den Fachkern. Der Simulator prüft Start, Runde und Zurück. Was ein Mikrofon oder eine echte Stimme braucht, steht unten offen.

## Navigation

- [x] Der Start ist ein Pfad mit LOS, gesperrten und fertigen Knoten und einer Truhe am Kapitelende. Unten vier Reiter: Lernen, Üben, Fortschritt, Profil.
- [x] Die Lektion hat einen Balken, ein X mit Pause-Frage, ein Banner wer dran ist, und CHECK oder WEITER. Am Ende Konfetti und zurück auf den Pfad.
- [x] Start, Profil, Runde, Alltags-Check, Tutorial, Duo, Feedback, Ton-Duell, Schrift, eigene Sätze, Reise, Rollenspiel und die Teilkarte haben Zurück, X oder einen Reiter.
- [x] Die Runde fragt „Runde pausieren?“ und der Start bietet Weiterspielen.
- [x] Wischen vom Rand ist auf Runde und Alltags-Check an.
- [x] Leerer Lernpfad und leere Tonpaare zeigen einen Satz, keinen Absturz.
- [x] Hör & Zeig erklärt den Ablauf in einem Satz, nennt die aktive Person, gibt das Handy weiter und wertet nur gemeinsam.
- [x] Gemeinsam bauen verteilt einen Satz auf beide. Nur die richtige Reihenfolge vor der Zeit gibt beiden den Punkt.
- [x] Die Wochenquest steht neben der Serie: 5 Runden und ein Restaurant-Test. Sie nimmt keine Serie weg.

## Sprache

- [x] Info.plist bittet um Spracherkennung und Mikrofon.
- [x] Locale `th-TH`, on-device, sonst Server. Leise oder fremde Laute sind rot, nie ein Treffer.
- [x] Langsam ist höchstens halb so schnell wie normal (`SpeechPace`).
- [x] Liegt `Audio/<id>.m4a` im Bundle, spielt sie im normalen Tempo. Langsam und fehlende Dateien nutzen die Synthese. Die 300 Sätze stehen in `docs/AUDIO-SCRIPT.csv`. Es sind keine erfundenen Aufnahmen im Bundle.
- [x] Pegel und Aufnahme-Automat sind als reine Funktion getestet. Profil → Debug → Mikrofon-Test zeigt Pegel, Pufferzahl und Teiltext. Die Erkennung erzwingt kein On-Device-Modell.
- [ ] Am Gerät: Pegel bewegt sich, Teiltext erscheint, Tippen und Gedrückthalten stoppen, nach einer Sprechpause endet die Aufnahme.

## Aussehen und Zugang

- [x] Farben nur in `Theme.swift`. Creme hell, Nacht dunkel, Gold als Text im Hellen dunkel und im Dunkeln hell. Knöpfe Nachtblau mit weißer Schrift.
- [x] Titel nutzen Textstile und `minimumScaleFactor`. Schilder und Emoji bleiben fest, damit sie wie ein Bild wirken.
- [x] Banner, Bilder, Schilder und das Wort des Tages haben VoiceOver-Namen. Die Bildwahl sagt „Bild 1“ und nicht die Lösung.
- [x] Die Übergabe im Duett blendet mit einer Feder, außer Bewegung reduzieren ist an.
- [ ] Am Gerät: heller und dunkler Modus, größte Schrift, VoiceOver einmal durch Start und Hör & Zeig.

## Inhalt

- [x] Tutorial ist ein Satz und vier Karten, die zum Sagen-und-Zeigen passen.
- [x] Links und rechts wählen ผม/ครับ oder ฉัน/ค่ะ. Ab A1 blendet die Umschrift aus, wenn das Wort sitzt. „Umschrift ausblenden“ nimmt sie ganz weg.
- [x] Eine gelbe oder rote Bewertung nennt Ton oder Vokallänge und bietet langsames Hören. Nach Grün kann die eigene Stimme gemerkt und später als Partnerstimme gespielt werden.
- [x] Alltagssprache: kein อรุณสวัสดิ์, kein ราตรีสวัสดิ์, kein ดิฉัน. ข้าว ist `khâao`.
- [x] Üben öffnet Ton-Duell, Schrift, Reise, eigene Sätze und Rollenspiel. Fortschritt zeigt Checks, lokale Zahlen, die Teilkarte und Feedback. Der Pfad zeigt das Wort des Tages, die Quest und startet die Abend-Erinnerung. Profil hat Geschlecht und Umschrift.
- [x] Der Restaurant-Test nutzt denselben Balken, dasselbe X und CHECK wie eine Lektion.

## Vor dem Upload

- [x] `swift test` grün.
- [x] Diese Liste gegen den Stand gelesen.
- [ ] Simulator-Navigation in CI grün.
