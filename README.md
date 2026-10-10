# Velox Nutrition

Native, private iPhone-App zur Ernährungserfassung mit SwiftUI, SwiftData und echter OpenAI-Foto-/Textanalyse. Die Gestaltung übernimmt die beigefügten Velox-Referenzen: dunkler grün beleuchteter Hintergrund, transparente Karten, Satoshi-Schrift und orange Navigation.

**Status, 10. Oktober 2026:** Der vollständige Quellcode und das Xcode-Projekt sind erstellt. Die statische Swift-Syntax-, Projekt- und Ressourcenprüfung besteht. Ein erfolgreicher Apple-SDK-Build, Simulatorlauf oder Gerätetest ist noch nicht bestätigt: Die Entwicklungsumgebung läuft unter Windows ohne Xcode, Swift-Compiler oder iOS-Simulator. Ein API-Schlüssel wurde nicht bereitgestellt; es wurden keine echten API-Anfragen ausgeführt. Details und die noch auszuführenden Prüfungen stehen in [TESTING.md](TESTING.md).

## Auf dem iPhone starten

1. Diesen Projektordner auf einen Mac mit Xcode 15 oder neuer übertragen. Ein aktuelles Xcode mit installiertem iOS-Simulator ist empfohlen. Die App benötigt iOS 17 oder neuer.
2. Nach einem GitHub-Checkout im Projektordner `python3 scripts/download_fonts.py` ausführen, um die Satoshi-Schriften direkt von Fontshare zu beziehen. Dann `VeloxNutrition.xcodeproj` öffnen. Das Projekt ist bereits erzeugt; XcodeGen, CocoaPods und Drittanbieter-iOS-Pakete sind nicht erforderlich. Der Mac-Testlauf lädt fehlende Schriften automatisch.
3. Das Scheme **VeloxNutrition** und zunächst einen iPhone-Simulator auswählen. Mit **⌘R** bauen und starten. Die App startet mit einer leeren lokalen Datenbank; es gibt keine künstlichen Mahlzeiten oder Demo-Analysen.
4. Für ein echtes iPhone unter **Signing & Capabilities** beim App-Target dein Apple-Team wählen und gegebenenfalls den Bundle Identifier `app.veloxnutrition.personal` durch einen eigenen eindeutigen Identifier ersetzen. Entwickler-Modus auf dem iPhone aktivieren, das Gerät verbinden und als Run-Ziel wählen.
5. Zunächst eine Mahlzeit über **Manuell** erfassen. Diese Funktion und der gesamte Verlauf brauchen weder Internet noch API-Schlüssel.
6. Unter **Einstellungen → OpenAI API-Schlüssel** deinen persönlichen Schlüssel eingeben, **Schlüssel speichern** und optional **Verbindung testen** wählen. Der Test führt eine kleine echte Anfrage aus und kann API-Kosten verursachen. Ein ChatGPT-Abonnement ersetzt keinen API-Schlüssel mit Modellzugriff/API-Guthaben.
7. **Mahlzeit fotografieren** oder **Beschreiben** auswählen, Angaben ergänzen und **Mit KI analysieren** antippen. Danach alle Schätzungen prüfen und erst mit **Mahlzeit speichern** bestätigen.

Eine über Xcode installierte App mit kostenlosem Personal-Team kann eine erneute Signierung erfordern. Für den Privatgebrauch sind kein App-Login, keine Cloud-Datenbank und kein eigener Server nötig. Die Signierung ist eine Apple-Installationseinstellung, keine Registrierung innerhalb der App.

## Implementierte Funktionen

- Tagesübersicht mit Kalorien, Protein, Kohlenhydraten, Fett und Ballaststoffen; fünf horizontale Balken und freiwillige Referenzwerte. Ohne Referenzwert entsteht kein erfundener Fortschrittsprozentsatz.
- Mahlzeitenliste mit Name, Uhrzeit, optionalem Foto und allen fünf Nährwerten; Detailansicht, Bearbeitung und Löschung.
- Manuelle Eingabe von Name, Nährwerten, Beschreibung, Foto und Datum/Uhrzeit, vollständig offline.
- Kamera und Apple-Fotopicker, HEIC/JPEG-Verarbeitung, Orientierungsnormalisierung, maximal 1.600 Pixel Kantenlänge und JPEG-Komprimierung.
- Echte multimodale Responses-Anfrage mit Foto und Zusatztext oder nur Beschreibungstext.
- Mikrofon-Button für Apple-Diktat; anschließend bearbeitbarer Text. Es wird ausschließlich gerätelokale Spracherkennung angefordert. Nicht unterstützte Geräte/Sprachen erhalten eine Fehlermeldung; Tippen bleibt möglich.
- Ergebnisprüfung mit editierbaren Bestandteilen, Mengenangaben, Einzelwerten, Gesamtwerten und Unsicherheiten. Beim Ändern der Einzelwerte wird die Summe neu berechnet. Eine separate Korrektur der Gesamtwerte bleibt möglich.
- Wiederholung und Abbruch von Analysen, Ladeanzeigen und verständliche Fehler bei fehlendem Schlüssel, Modellzugriff, Netzwerk-, Berechtigungs- und Kontingentproblemen.
- Datumsauswahl und Tagwechsel im Verlauf, einschließlich korrekter Tagesgrenzen bei Zeitumstellungen.
- Keychain-Schlüssel anzeigen, ersetzen und entfernen; Verbindungstest; optionale Referenzwerte, Haptik und Diktiersprache.
- Löschen aller Mahlzeiten/Fotos sowie vollständiges Zurücksetzen einschließlich Einstellungen und Schlüssel.

## Speicherung und Datenschutz

SwiftData liegt unter `Application Support/VeloxNutrition/Nutrition.store`; Fotos liegen im Unterordner `Photos`. CloudKit ist ausdrücklich deaktiviert. Dieser Ordner ist von Geräte-Backups ausgeschlossen, damit gespeicherte Ernährungseinträge nicht automatisch in iCloud-Backups übertragen werden. **Dadurch gibt es auch keine automatische Wiederherstellung bei Geräteverlust oder App-Deinstallation.**

Der Schlüssel wird ausschließlich als nicht synchronisierbares Keychain-Element mit `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` gespeichert. Es gibt keinen Schlüssel im Quellcode, keine Schlüssel-Logs und keine Analytics. Das Projekt enthält nur klar erkennbare Testzeichenketten in isolierten Tests.

Eine Analyse sendet nur den aktuellen Beschreibungstext und gegebenenfalls das vorbereitete Foto direkt über HTTPS an `api.openai.com`. Gespeicherte Mahlzeiten werden nicht automatisch hochgeladen. Die Netzwerk-Session verwendet keinen dauerhaften Cache und keine Cookies; Weiterleitungen werden abgewiesen. `store: false` verhindert die Speicherung als abrufbare Responses-Antwort, bedeutet aber nicht automatisch Zero Data Retention. Die externe Verarbeitung und die Möglichkeit von API-Kosten werden vor dem Start angezeigt. Maßgeblich bleiben [OpenAIs API-Datenrichtlinien](https://developers.openai.com/api/docs/guides/your-data).

Fotos werden vor dem Datenbank-Commit geschrieben; bei fehlgeschlagenem Speichern wird ein neu angelegtes Foto wieder entfernt und die Datenbank zurückgerollt. Nicht mehr referenzierte Dateien werden nach einem Commit entfernt und beim nächsten Start erneut bereinigt. Ein beschädigter oder nicht zugänglicher Store wird nicht durch einen leeren Store ersetzt.

## OpenAI-Vertrag

Die am 10. Oktober 2026 gelesene [offizielle Modellseite](https://developers.openai.com/api/docs/models/gpt-6-luna) bestätigt die Modell-ID `gpt-6-luna`, Bildeingaben, Responses API und Structured Outputs. Es gibt keinen automatischen Modellwechsel.

- Endpoint: `POST https://api.openai.com/v1/responses`
- Foto: `input_image` als komprimiertes JPEG im Base64-Data-URL-Format, siehe [Images and vision](https://developers.openai.com/api/docs/guides/images-vision).
- Antwortformat: `text.format.type = json_schema`, `strict = true`, siehe [Structured Outputs](https://developers.openai.com/api/docs/guides/structured-outputs?api-mode=responses).
- Nährwertschlüssel: `calories_kcal`, `protein_g`, `carbohydrates_g`, `fat_g`, `fiber_g`.
- Schema- und zusätzliche lokale Validierung prüfen Pflichtfelder, unerwartete Felder, Typen, nicht negative endliche Werte, Anzahl der Bestandteile und Konfidenz. Verweigerte/unvollständige Antworten werden nicht gespeichert.
- Gesamtwerte werden lokal aus den Bestandteilen berechnet. Abweichende KI-Summen werden mit einem Hinweis korrigiert.
- API-Aufrufe starten ausschließlich durch ausdrückliches Antippen; eine laufende Analyse kann nicht doppelt gestartet werden.

Portions- und Nährwertangaben sind Schätzungen und werden ausdrücklich als solche dargestellt. Die App gibt keine Diätvorgaben und bewertet Lebensmittel nicht moralisch.

## Projektaufbau

```text
VeloxNutrition.xcodeproj/  Fertiges Projekt, App-, Unit-Test- und UI-Test-Targets
VeloxNutrition/
  VeloxNutritionApp.swift  Lokaler Store und Startfehlerbehandlung
  Models/                 Mahlzeiten, Einstellungen und ungespeicherte Entwürfe
  Services/               Keychain, Fotos, persistente Aktionen und Spracherkennung
  UI/                     Dashboard, Verlauf, Erfassung, Prüfung, Details, Einstellungen
  Resources/              Satoshi, Icon, Startfarbe, Info.plist, Privacy Manifest
NutritionCore/            Nährwertlogik, Kalendergrenzen, Schema und API-Client
Tests/Core/               Plattformunabhängige XCTest-Tests
Tests/iOS/                SwiftData-, Foto- und isolierte Keychain-Tests
Tests/UI/                 Lokaler Erfassungsablauf und Screenshot-Anhänge
scripts/                  Projekterzeugung, statische Prüfung und Mac-Testlauf
docs/DESIGN.md            Analyse und Übertragung der Referenzbilder
Package.swift             Separater Core-Testlauf mit swift test
```

Die Core-Dateien sind direkt in das App-Target eingebunden. Das Swift-Package dient zusätzlich zum unabhängigen Testen derselben Logik; es ist keine doppelte Implementierung.

## Tests und Projektpflege

Auf einem Mac:

```bash
bash scripts/test_on_mac.sh
```

Oder **⌘U** in Xcode. Der Mac-Testlauf erzeugt ein nach dem Zeitpunkt benanntes `TestResults-….xcresult` mit Testergebnissen und UI-Screenshots; mehrere Durchläufe überschreiben sich nicht. Der GitHub-Actions-Workflow führt diese Tests auf einem macOS-Runner aus. Sein tatsächlicher Status ist im Repository unter **Actions** sichtbar.

Nach Hinzufügen/Entfernen von Swift- oder Ressourcen-Dateien kann das Projekt deterministisch neu erzeugt werden:

```bash
python3 scripts/generate_project.py
```

Die lokale statische Prüfung ist in [TESTING.md](TESTING.md) beschrieben. Eine bestandene statische Prüfung ersetzt keinen Apple-Build.

## Schriften

Die Oberfläche verwendet die originale Satoshi-Variable-Schrift von [Fontshare](https://www.fontshare.com/fonts/satoshi) mit SwiftUI-Schriftgewichten; statische Regular-/Medium-/Bold-Dateien dienen als Fallback. Rohe Schriftdateien werden aufgrund der Fontshare-Lizenz nicht im öffentlichen Repository verteilt. `scripts/download_fonts.py` lädt sie für den lokalen Build direkt vom Anbieter und speichert die geltende Lizenz unter `VeloxNutrition/Resources/Fonts/FFL.txt`. Das App-Icon ist eine eigens gezeichnete geometrische Blattmarke.
