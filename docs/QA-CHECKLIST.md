# QA-Checkliste

Vor jedem TestFlight-Upload. Automatisch prüft `swift test` den Fachkern. Der Simulator prüft die Navigation (`SprachduettUITests`). Der Rest steht hier, damit er nicht nur im Kopf bleibt.

## Navigation

- [x] Start, Einstellungen, Runde, Alltags-Check, Tutorial, Duo und Feedback haben Schließen, Fertig oder Zurück.
- [x] Die Runde fragt „Runde pausieren?“ und der Start bietet danach Weiterspielen oder Neue Runde.
- [x] Wischen vom Rand ist auf Runde und Alltags-Check wieder an (`SwipeBackEnabler`).
- [x] Leerer Lernpfad erzeugt keine Runde und keinen Absturz (`testEmptyPathStaysOnTheHomeLabel`).
- [x] Simulator: Zusammen spielen → Zurück → Weiterspielen, und Einstellungen → Fertig.

## Sprache

- [x] `Info.plist` enthält `NSSpeechRecognitionUsageDescription` und `NSMicrophoneUsageDescription`.
- [x] Erlaubnis für Spracherkennung und Mikrofon, Locale `th-TH`, on-device, sonst Server.
- [x] Vor dem Aufnehmen stoppt die Stimme, die Session geht auf `.playAndRecord` / `.measurement` / Lautsprecher.
- [x] Der Tap nutzt das Format des Mikrofons, nachdem die Session aktiv ist. Sample-Rate 0 bricht mit einer Meldung ab.
- [x] Leise oder leere Aufnahme ist „Nichts gehört“ und rot, nie ein Treffer. Husten und fremde Wörter sind `.miss`.
- [x] Langsam ist `Minimum + 0.15`, normal `Default × 0.9`. Der Test verlangt, dass langsam höchstens halb so schnell ist.
- [ ] Am Gerät: Dialoge, Pegel, Live-Text, grün/gelb/rote Silben, Haptik, und dass langsam hörbar langsamer ist.

## Aussehen

- [x] Farben nur in `Theme.swift`. Creme und Karte hell, Nachtblau dunkel. Gold ist im Hellen dunkelbronze (Text), im Dunkeln hell.
- [x] Knöpfe sind durchgehend Nachtblau mit weißer Schrift, damit der Kontrast in beiden Modi über 4,5:1 liegt.
- [x] Titel und Knöpfe nutzen Textstile und `minimumScaleFactor`, damit Dynamic Type nicht abschneidet. Emoji bleiben fest, sonst sprengen sie die Zeile.
- [ ] Am Gerät: Heller und dunkler Modus, größte Dynamic-Type-Stufe, kein abgeschnittener Satz.

## Inhalt und Tutorial

- [x] Eine Seite: „Ihr spielt zu zweit auf einem Handy. Hört zu, sprecht laut, tippt.“ Die vier Coach-Karten sind Zuhören, Tippen, Sagen, Mini-Dialog.
- [x] Links und rechts haben ผม/ครับ oder ฉัน/ค่ะ. Die Umschrift blendet nach acht sicheren Wiederholungen aus.
- [x] Kein อรุณสวัสดิ์, kein ราตรีสวัสดิ์, kein ดิฉัน. ข้าว ist fallend `khâao`, ข่าว bleibt tief `khàao`.

## Vor dem Upload

- [x] `swift test` grün.
- [x] Diese Liste gegen den Stand gelesen.
- [ ] Simulator-Navigation in CI grün (läuft im TestFlight-Workflow, nicht auf Linux).
