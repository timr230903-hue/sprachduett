# Plan v2 – Weniger Teile, echte Ergebnisse

## Kritik

Die letzte Runde hat die alten Lektionsmenüs ersetzt, aber die App erklärt sich immer noch über zu viele Türen: Solo, Duo, Tutorial und Fortschritt stehen gleichberechtigt neben dem Spiel. Wer zum ersten Mal öffnet, muss eine kleine Bedienungsanleitung verstehen, bevor etwas passiert.

Der wichtigere Fehler sitzt im Spiel selbst. Bei „Sag's mir“ und im Mini-Dialog entscheidet der Partner, ob das Thai richtig war. Beide können noch kein Thai. „Richtig“ ist dann ein Gefälligkeitsknopf, kein Maß. Punkte und Serie zählen Taps, nicht ob jemand in Bangkok einen Satz sagen könnte.

## Entscheidungen

1. Der Startbildschirm hat eine Aufgabe: Zusammen spielen. Fortschritt steht darüber in einer Zeile. Alles andere (Solo, Duo, Tutorial, Statistik, Feedback) liegt hinter dem Zahnrad.
2. Onboarding ist ein Satz, kein Kurs. Hinweise erscheinen einmal, direkt auf dem ersten Vorkommen jedes Spiels.
3. Das Handy bewertet das Gesprochene. Der Partner tippt nur, wenn die Erkennung fehlt oder nicht erlaubt ist.
4. Die Überschrift des Fortschritts ist ein Kann-Satz aus dem Alltags-Check, nicht eine Punktzahl. Punkte und Serie bleiben klein auf dem Ergebnis.
5. Feedback und Nutzungszahlen bleiben auf dem Gerät. Tim schickt eine Notiz per Teilen, ohne Server.

## Lernpfad

Stufe 1 (A0) und Stufe 2 (A1) bleiben der spielbare Stoff. Eine Einheit öffnet die nächste bei etwa 80 Prozent. Die erste Runde einer Einheit lässt neue Wörter hören und nachsprechen, bevor sie abgefragt werden.

Am Ende einer Stufe, und danach etwa einmal im Monat, kommt der Alltags-Check. Stufe 1: Hallo, Danke, Ja, Zahlen. Stufe 2: bestellen, Preis, Rechnung, Herkunft. Das Handy spielt die andere Seite auf Thai vor. Die Antwort wird erkannt. Dazu eine kurze Hörfrage mit drei deutschen Bedeutungen. Das Ergebnis sagt, was ihr in Bangkok schon könntet und was noch nicht.

A2 (Zeitformen, längere Alltagsgespräche) und B1 (Schrift, Lesen, längeres Hören) bleiben auf der Roadmap.

## Spracherkennung

Locale `th-TH`, on-device wenn das Gerät es kann, sonst die Server-Erkennung. Der Vergleich normalisiert Thai, streicht Höflichkeitspartikeln und vergleicht zeichenweise. Ein sicherer Treffer ist grün. Klingt es nah, aber der Ton sitzt nicht, ist es gelb: nochmal langsam anhören, Tonpfeil zeigen. Daneben ist rot. Langsames Vorsprechen liegt bei Rate 0,35. Jede Bewertung schreibt einen Aussprachewert ins Wortgedächtnis.

## Aufräumen

Nicht verlinkte Lektions-, Wort- und Szenenbildschirme fliegen raus. Der Inhalt (JSON, Lernpfad, Dialoge) bleibt.
