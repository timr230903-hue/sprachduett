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

## Freigegeben, noch nicht in diesem Stand

Jeder Punkt bekommt einen eigenen TestFlight-Stand, ohne Bezahlschranke. Thai bleibt die einzige ausgelieferte Sprache, bis ein Sprachpaket wirklich fertig ist.

1. Aufnahmen: `Audio/<id>.m4a` abspielen, sonst Vorlesen. Die Liste der Sätze steht in `docs/AUDIO-SCRIPT.csv`. Die Dateien nimmt ein Mensch auf, die App erfindet sie nicht.
2. Ton-Duell: Minimalpaare, die sich nur im Ton unterscheiden. Abwechselnd tippen, welcher Ton gemeint war.
3. Schrift, ein paar Buchstaben am Tag, dann Schilder und Speisekarten als gezeichnete Texte, keine Fotos.
4. Eigene Sätze: deutsches Suchwort im Kuratieren, Thai von Hand, Aufnahme vom Partner, Karte für beide. Keine Cloud-KI.
5. Reise-Modus: große Karten für Taxi, Markt, Arzt, Hotel, offline.
6. Abend-Erinnerung lokal: „Partner hat heute schon gespielt, jetzt du?“ Kein Serien-Verlust.
7. Rollenspiel mit erzeugter Umgebungsfläche (Markt, Massage, Tuk-Tuk), nichts Lizenziertes.
8. Teilbare Fortschrittskarte, zum Beispiel „Wir können jetzt im Restaurant bestellen“.
9. Widget „Wort des Tages“. Die Auswahl steckt in `WordOfDay` und steht auf dem Startbildschirm. Die WidgetKit-Extension (`SprachduettWidget/WordOfDayWidget.swift`) ist absichtlich nicht im signierten Archiv.

   Tim braucht dafür: eine App-ID `de.timroot.sprachduett.widget`, eine App Group `group.de.timroot.sprachduett`, ein App-Store-Profil für die Extension und das bestehende Profil der App um die App Group erweitert. Ohne diese Profile bricht das TestFlight-Archiv, deshalb bleibt die Extension draußen.
10. Sprachpakete: der Katalog hängt an einer Sprache. Ausgeliefert wird weiter nur Thai.
