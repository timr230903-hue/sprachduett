# Sprachduett – Roadmap

Eine Runde folgt dem Lernpfad. Stufe 1 (A0) und Stufe 2 (A1) sind in der App: Hallo, Ja/Nein, Zahlen, Töne, Essen, Trinken, Bestellen, Einkaufen, Weg, Familie, Zeit, Farben, Tiere, Unterwegs. Eine Einheit öffnet die nächste, wenn etwa 80 Prozent der Wörter sitzen.

## Stufe 3 · A2

Vergangenheit und Zukunft im Satz (`แล้ว`, `จะ`, `กำลัง`), Alltagsgespräche über den Tag, Pläne, Wetter, Befinden. Dieselben drei Spiele, längere Mini-Dialoge, Wiederholung aus A0 und A1.

## Stufe 4 · B1 und Schrift

Thai-Schrift Buchstabe für Buchstabe, dann Silben lesen, längere Dialoge und Hörverstehen ohne Umschrift. Die Töne bleiben an der Schrift hängen, weil die Klasse des Konsonanten den Ton bestimmt.

V1 ist der gemeinsame Thai-Dialog: koppeln, abwechselnd laut sprechen, Serie nur zu zweit, kuratierter Wortschatz. Alles darunter kommt danach und bleibt ohne Cloud-KI.

## Pantomime und Erklär-Runden

Eine Person sieht das Thai, darf es nicht sagen und erklärt auf Deutsch oder mit Gesten. Die andere sagt das Thai. Punkte gibt es nur, wenn die sprechende Person die Zeile trifft. Das zwingt weg vom Ablesen.

## Alltagsmissionen

Kurze Aufträge außerhalb der App: beim nächsten Essen eine Bestellung auf Thai, eine Wegbeschreibung auf dem Weg, eine Nachricht auf der Mailbox. Beide haken erst ab, wenn sie es einander erzählt haben. Die Mission zählt für die Serie wie eine Szene.

## Partner-Duelle mit Einsätzen

Ein kleines Duell über zehn Karten. Wer die Zeile zuerst sauber sagt, bekommt den Punkt. Der Einsatz ist etwas Harmloses, das ihr vorher festlegt (Kaffee holen, Abwasch). Der Stand synchronisiert über denselben Duo-Record. Kein Geld, keine Rangliste außerhalb des Paares.

## Thai-Schrift, Schritt für Schritt

Erst die Konsonantenklassen, die den Ton bestimmen, dann die Vokale, dann kurze Wörter aus dem vorhandenen Katalog. Jede Lektion endet damit, dass eine Person ein Wort schreibt und die andere es vorliest. Die Umschrift bleibt die Kontrolle, nicht der Ersatz.

## Weitere Sprachen

Dasselbe Duo, ein zweites JSON. Vietnamesisch und Italienisch liegen nah, weil das Paar sie braucht und die Rollenlogik gleich bleibt. Die Erkennung wechselt das Locale (`vi-VN`, `it-IT`). Töne, Partikel und Schrift bleiben sprachspezifisch im Katalog, nicht im View-Code.

## Im Pfad und in den Reitern

Ohne Bezahlschranke. Thai ist das einzige geladene Paket (`ContentPacks`, Sprache `th-TH`).

1. Aufnahmen: `Audio/<id>.m4a` ersetzt die Stimme im normalen Tempo. Sonst Vorlesen. Die Liste ist `docs/AUDIO-SCRIPT.csv`. Es liegen keine erfundenen Dateien im Bundle.
2. Ton-Duell unter Üben.
3. Schrift unter Üben: ein paar Buchstaben am Tag, dann ein gezeichnetes Schild.
4. Eigene Sätze unter Üben. Treffer aus dem Heft oder Thai von Hand, Aufnahme vom Partner, Karte in der nächsten Runde.
5. Reise unter Üben: Taxi, Markt, Arzt, Hotel, offline.
6. Abend-Hinweis lokal, sobald der Pfad offen ist: „Partner hat heute schon gespielt, jetzt du?“ Die Serie wird nicht gekürzt.
7. Rollenspiel unter Üben. Markt, Massage, Tuk-Tuk sind erzeugtes Rauschen.
8. Fortschritt zeigt die Checks und teilt eine Karte.
9. Wort des Tages steht auf dem Pfad. Die Widget-Extension liegt in `SprachduettWidget/WordOfDayWidget.swift` und ist nicht im Archiv.

   Tim braucht dafür: eine App-ID `de.timroot.sprachduett.widget`, eine App Group `group.de.timroot.sprachduett`, ein App-Store-Profil für die Extension und das App-Profil um die Gruppe erweitert. Vorher bleibt das Widget draußen, sonst scheitert die Signierung.
10. Weitere Sprachen wären ein zweites Paket. Der View lädt nur das Thai-Paket.

Geschlecht (ผม/ครับ, ฉัน/ค่ะ) und „Umschrift ausblenden“ liegen im Profil. Ab A1 blendet die Paiboon-Umschrift aus, wenn ein Wort sitzt. Die Truhe am Kapitelende ist der Alltag-Check oder der Restaurant-Test. Feedback liegt bei Fortschritt, im Profil und beim Schütteln. Die Nutzungszahlen stehen unter Fortschritt und bleiben auf dem Gerät.
