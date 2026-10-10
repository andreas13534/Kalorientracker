# Prüfstatus – 10. Oktober 2026

## Hier tatsächlich ausgeführt

Umgebung: Windows, PowerShell. Swift und Xcode sind nicht installiert. Der vorhandene XcodeBuildMCP-Aufruf `list_sims` scheitert mit `spawn xcrun ENOENT`; WSL ist ebenfalls nicht installiert. Es steht kein Simulator oder verbundenes iPhone zur Verfügung.

Erfolgreich:

1. Alle 24 Swift-Dateien einschließlich Package-Manifest und Tests mit Tree-sitter Swift syntaktisch gelesen, keine Parserfehler.
2. Die OpenStep-Struktur der `project.pbxproj` eingelesen und alle 93 Xcode-Objekte samt Verweisen geprüft.
3. Sämtliche Swift-Dateien in den vorgesehenen Xcode-Targets referenziert; keine fehlenden Quelldateien oder Ressourcen.
4. Info.plist und Privacy Manifest geparst, Kamera-/Foto-/Mikrofon-/Speech-Texte geprüft.
5. Registrierte Satoshi-Dateien und Asset-Dateien geprüft; Shared Scheme als XML geparst.
6. Source-Checks auf fehlende CloudKit-Deaktivierung, fehlende Keychain-Gerätesperrung, fehlende lokale Spracherkennung, HTTP-Endpoint, Schlüsselmarker und nicht implementierte Marker bestanden.

Befehl und Ergebnis:

```text
python scripts/validate_project.py
PASS: syntax parsed for 24 Swift files; 93 Xcode objects and all references validated;
plist, permissions, fonts, assets and scheme valid.
LIMIT: static checks do not verify Swift types, Apple SDK compatibility, rendering or runtime behavior.
```

Zur Wiederholung:

```bash
python3 -m pip install --target .tools tree-sitter==0.26.0 tree-sitter-swift==0.7.4 pbxproj==4.3.3
python3 scripts/validate_project.py
```

Die Parserpakete werden ausschließlich für Entwicklung verwendet und sind keine App-Abhängigkeiten.

## Implementierte, hier noch nicht ausgeführte XCTest-Tests

**15 Testfälle** sind vorbereitet:

- Core (9): alle fünf Summen und Referenzfortschritt; Dezimalkomma/ungültige Werte; Wiener Sommer-/Winterzeitgrenzen; Schema-Validierung und Neuberechnung; stabile Lebensmittel-IDs nach Speicherung; Ablehnung zusätzlicher, fehlender, negativer und boolescher Werte; Responses-Ausgabe mit Reasoning/Refusal/unvollständigen Antworten; Bildrequest und striktes Schema; HTTP-Fehlerzuordnung und fehlender Schlüssel.
- iOS (5): Speichern/Bearbeiten/Tagwechsel/Löschen; Wiederöffnen eines echten lokalen Stores; Foto-Komprimierung/Ersetzung/Orphans/Gesamtlöschung; keine Speicherung vor Bestätigung; Keychain-Speichern/Ersetzen/Entfernen mit isoliertem Test-Service.
- UI (1): manuelle Erfassung ohne Schlüssel, Verlauf und Einstellungen, mit nativen Screenshot-Anhängen.

Die Transporttests verwenden nur innerhalb des Testtargets einen URLProtocol-Stub. Der ausgelieferte App-Code enthält keinen Demo- oder Fake-Analysemodus. Keychain-Tests verwenden einen zufälligen Test-Service und verändern den persönlichen API-Schlüssel nicht.

## Auf einem Mac ausführen

```bash
swift test
bash scripts/test_on_mac.sh
```

Das Skript führt zusätzlich den iPhone-Simulator-Build und alle Xcode-Tests aus. Alternativ in Xcode das Scheme **VeloxNutrition** auswählen und **⌘U** drücken. Compiler- und Laufzeitfehler müssen anhand dieses ersten tatsächlichen Apple-Builds behoben werden; die aktuelle statische Prüfung bestätigt keine Typkorrektheit.

Für eine erste Simulatorprüfung:

1. Leerer Start ohne API-Schlüssel; offline eine Mahlzeit mit allen fünf Werten und einem Foto erfassen.
2. App beenden und erneut öffnen; Mahlzeit und Einstellungen müssen erhalten bleiben.
3. Name, Werte und Datum auf gestern ändern; heutige und gestrige Summen müssen aktualisiert werden.
4. Mahlzeit und anschließend alle Daten löschen; Listen und Summen müssen leer sein.
5. Referenzwerte einzeln aktivieren, entfernen und Werte über der Referenz prüfen; keinen moralischen Warntext anzeigen.
6. Dashboard, Editor, Verlauf und Einstellungen auf kleinen und großen iPhones sowie mit großer Schrift prüfen. Ränder, Scrollbarkeit und Tastatur dürfen keine Aktionen blockieren.
7. API-Analyse ohne Schlüssel starten; verständliche Meldung und manuelle Alternative prüfen.

## Echtes iPhone und API-Schlüssel erforderlich

Noch nicht geprüft:

- Kameraaufnahme, Orientierung, erstmalig erteilte/verweigerte Kameraberechtigung.
- Fotopicker mit großen HEIC-Dateien und zunächst nur in iCloud liegenden Fotos.
- Mikrofon- und Speech-Berechtigungen, Diktatqualität und `supportsOnDeviceRecognition` für `de-AT`, `de-DE` und `en-US`.
- Tatsächliche Keychain-Persistenz über Neustart/Sperrung und Verhalten bei Deinstallation.
- Echte Text- und Fotoanalyse mit `gpt-6-luna`, Verbindungsprüfung, projektspezifischer Modellzugriff und API-Guthaben.
- Netzwerkabbruch, Hintergrundwechsel und Abbrechen/Wiederholen während einer echten laufenden Analyse.
- Plausibilität von geschätzten Portionen, Öl-/Saucenannahmen und allen fünf Nährwerten.

Geeignete Testbeschreibungen sind „zwei Spiegeleier, drei Scheiben Speck und eine Semmel“ sowie ein Foto mit „250 g Steak; Kartoffeln mit Butter gebraten“. Nach der Analyse Einzelwerte und Gesamtwerte ändern; vor dem Bestätigen darf die Mahlzeit nicht im Verlauf erscheinen. Eine Wiederholung darf keinen doppelten gespeicherten Eintrag erzeugen.

Es wurden keine externen OpenAI-API-Aufrufe ausgeführt und kein installierbares IPA erzeugt. Der erste erfolgreiche Xcode-Build und die genannten Gerätetests bleiben für die vollständige Abnahme erforderlich. Die Veröffentlichung auf GitHub wurde anschließend ausdrücklich beauftragt; der tatsächliche CI-Status ist unter **Actions** zu prüfen.

## Übergabe für den Mac-Testlauf

Ein Mac mit Xcode ist nach Auskunft des Nutzers vorhanden. Er ist in dieser Windows-Umgebung nicht per SSH konfiguriert; der Nutzer führt den Testlauf auf dem Mac aus und stellt anschließend die Ausgabe bereit. Das Quellcodearchiv `Delivery/VeloxNutrition-mac.zip` enthält den übertragbaren Projektordner ohne Entwickler-Caches oder Zugangsdaten.

Archiv auf dem Mac entpacken, im Terminal in `VeloxNutritionProject` wechseln und ausführen:

```bash
bash scripts/test_on_mac.sh 2>&1 | tee mac-test.log
```

Bei Fehlern die Ausgabe einschließlich des ersten Compilerfehlers zurückgeben. Ein fehlender iOS-Simulator kann unter Xcode → Settings → Components installiert werden. Die Tests benötigen keinen echten API-Schlüssel und führen keine kostenpflichtigen KI-Anfragen aus.
