# Sprachduett – Architektur

Zwei iPhones, eine Sprache. V1 ist Thai. Die Zeile, die du sprichst, steht nur auf deinem Display. Der andere hört zu und tippt „Verstanden“, falls die Erkennung aussetzt.

## Entscheidungen

| Thema | Entscheidung |
|---|---|
| UI | SwiftUI, iOS 17, Deutsch, warme Farben. Views bleiben klein, damit der Swift-Typchecker nicht abreißt. |
| Fachkern | `Sprachduett/Core`, Swift Package `SprachduettCore`, `swift test` auf macOS und Linux |
| Inhalt | Gebündeltes `thai.json`. Kein Netz, kein Modell. Paiboon-Umschrift mit Tonzeichen. |
| Konto | Apple-ID über CloudKit. Ohne iCloud läuft die App als Solo. |
| Sync | Eine Record-Zone `Duo-<UUID>` in der privaten Datenbank, geteilt per zonenweitem `CKShare`. `CKSyncEngine` für private und geteilte Datenbank, gleiches Muster wie Vorrat. |
| Stand | Ein `DuoState`-Record mit JSON. Zusammenführen vereinigt Übungstage und bestätigte Zeilen; die Dialogposition nimmt die längere, passende Linie. |
| Stimme | `Speech` mit Locale `th-TH`, on-device wenn `supportsOnDeviceRecognition`. Sonst der Server, sonst nur „Verstanden“. Vorlesen über `AVSpeechSynthesizer` `th-TH`. |
| Projekt | XcodeGen, `project.yml`. Team `3YVJ6AK57U`, Bundle `de.timroot.sprachduett`. |

## Ordner

```
Sprachduett/App          Einstieg, CloudKit-Einladung
Sprachduett/Core         Katalog, Partikel, Zug, Serie, Punkte, Merge
Sprachduett/Data         Lokaler Stand
Sprachduett/Speech       Erkennung und Vorlesen
Sprachduett/Sync         CKSyncEngine und Freigabe
Sprachduett/Views        Heute, Duette, Wörter, Wir
SprachduettTests         swift test
ci                       Export und App-Store-Vorprüfung
```

## Duo

Der Ersteller legt die Zone an und teilt sie. Die andere Person öffnet den Apple-Link; `SceneDelegate` nimmt die `CKShare.Metadata` an. Danach sieht sie die Zone in der geteilten Datenbank.

Rollen: Ersteller ist A, die eingeladene Person B, solange B noch frei ist. „Rollen tauschen“ dreht beide.

Solo schreibt nichts nach iCloud. „Ein Handy weitergeben“ deckt die nächste Zeile erst ab, wenn das Gerät wirklich weitergegeben wurde.

## Serie und Punkte

Ein Tag zählt in der gemeinsamen Serie nur, wenn jedes Mitglied an diesem Kalendertag mindestens eine eigene Zeile gesagt hat. Fehlt heute noch eine Stimme, bleibt die Serie der abgeschlossenen Tage stehen. Mit einer Person (Solo) zählt deren Üben.

Punkte: 10 je Zeile, einmal pro Person und Zeile. 50, wenn eine Szene komplett ist und die Person mitgesprochen hat. 30 extra an einem Tag, an dem beide geübt haben.

## Thai

Fünf Töne, Paiboon: ohne Zeichen mittel, à tief, â fallend, á hoch, ǎ steigend. Unaspiriert g j d dt b, ป ist bp. Die männliche Partikel wird als gesprochenes khráp (hoch) gelehrt. Frauen: ค่ะ khâ in Aussagen, คะ khá in Fragen. Die Zeile im Dialog speichert den Satz ohne Partikel; die App hängt sie nach der Einstellung an.

## CloudKit-Schalter

`SPRACHDUETT_CLOUDKIT_ENABLED` wählt `Config/Sprachduett-YES.entitlements` oder `Sprachduett-NO.entitlements` und steht als `SprachduettCloudKitEnabled` in der Info.plist. Debug ist NO, damit ein Entwicklungsprofil ohne Production-Push signiert. Release und CI setzen YES.

Die signierte Release-App verlangt:

- `com.apple.developer.icloud-container-identifiers`: `iCloud.de.timroot.sprachduett`
- `com.apple.developer.icloud-services`: `CloudKit`
- `com.apple.developer.icloud-container-environment`: `Production`
- `aps-environment`: `production`
- Hintergrundmodus `remote-notification`
- `CKSharingSupported`
- `NSSpeechRecognitionUsageDescription`, `NSMicrophoneUsageDescription`

Container in der Apple-Developer-Konsole anlegen, am App-ID hängen, Schema nach Production schieben, Push für die App-ID einschalten. Das Profil „Sprachduett App Store CI“ muss Container und `aps-environment` = production enthalten.

## CI

`.github/workflows/testflight.yml` auf `macos-15-intel`, Xcode `latest-stable`, iOS-SDK mindestens 26. Build-Nummer ist `github.run_number`, erhöht falls schon vergeben. Upload nach TestFlight, App-ID `6836831879`.

Secrets, gleiche Namen wie Vorrat:

- `ASC_KEY_P8`
- `DIST_CERT_P12`
- `DIST_CERT_PASSWORD`
- `PROFILE`

`ASC_KEY_ID` `5DPB4C6LCQ` und `ASC_ISSUER_ID` `9317135c-5c0e-4e25-ab66-1220d739ce53` stehen im Workflow. Team `3YVJ6AK57U`. Distributionszertifikat `M7JL49W67G` (`Apple Distribution`).
