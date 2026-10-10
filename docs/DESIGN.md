# Referenzanalyse und Designübertragung

Die beiden bereitgestellten Bilder wurden vor der Implementierung betrachtet. Sie zeigen eine Flugbuchungs-App und deren Designpalette; keine Ansicht enthält Ernährungselemente. Entsprechend werden Gestaltung, Proportionen und Materialwirkung auf die benötigten Ernährungselemente übertragen.

## Bild 1

- Fast schwarzer Hintergrund mit weichem dunkelgrünem Licht im oberen Bereich; punktuell türkise Leuchteffekte.
- Weiße, ruhige, serifenlose Überschriften und deutlich blassere Sekundärtexte.
- Glasartig transparente, abgerundete Karten mit heller Oberkante und sehr zurückhaltendem Rand.
- Orange aktive Navigation und primäre Hervorhebungen; mintfarbene Symbole.
- Große redaktionelle Überschrift, großzügige Ränder, kompakte Datenkarten und abgesetzte Bedienelemente.
- Schwebende, abgerundete untere Navigation mit Icon und Text.

## Bild 2

- Satoshi Variable mit Regular, Medium und Semibold als Typografievorlage.
- Hintergrund `#040A0A`, Weiß `#FFFFFF`, Grün `#49DC7A`, Aqua `#22F2EF`.
- Der orange dargestellte Farbkreis trägt die widersprüchliche Beschriftung `#C923F8` (violett). Verwendet wird das sichtbare Orange aus Bild 1, `#FF6B00`.
- Runde Glasflächen, dünne lichtdurchlässige Ränder, weiche grüne/türkise Hintergrundleuchten.

## Umsetzung

`Theme.swift` zentralisiert Palette, Satoshi-Schrift, Hintergründe, Karten, Eingaben und Buttons. Die originale Satoshi-Variable-Schrift ist unverändert eingebunden; Regular, Medium und Semibold werden als SwiftUI-Schriftgewichte angefordert. Der PostScript-Name der gelieferten variablen Datei lautet `SatoshiVariable-Bold`; die tatsächliche Gewichtachse reicht von 300 bis 900. Die Zuordnung der angeforderten Gewichte ist beim Mac-Rendering zu kontrollieren. Statische Regular-/Medium-/Bold-Dateien dienen als Fallback. Benutzer-Schriftgrößen werden über relative SwiftUI-Fonts berücksichtigt.

Das Dashboard verwendet dieselbe Hierarchie: Marke und Datum, große zweizeilige Überschrift, transparente Tageskarte, primärer oranger Foto-Button und dezente ergänzende Erfassungsbuttons. Kalorien sind typografisch dominant; alle fünf Werte erhalten horizontale Balken. Ohne Referenzwert bleiben die Balken neutral.

Die Mahlzeitkarten zeigen Foto, Name/Uhrzeit, Kalorien sowie vier weitere Nährwerte. Der Flugticket-Trennstrich wird als feine horizontale Teilung innerhalb der Übersicht übertragen. Die untere Glasnavigation enthält die drei benötigten Bereiche Heute, Verlauf und Einstellungen. Analyse, Prüfung und Einstellungen verwenden dieselben Materialien und Abstände.

Kamera, Fotopicker, Datumsauswahl, Berechtigungsdialoge, Tastatur und Löschbestätigung bleiben native Apple-Komponenten. Ihre systemeigene Darstellung ist beabsichtigt.

## Ausstehende visuelle Prüfung

Unter Windows ist kein SwiftUI-Rendering verfügbar. Die tatsächliche Darstellung, Safe Areas, Tastaturinteraktion, VoiceOver und Dynamic Type müssen im iPhone-Simulator geprüft werden. Es wurde kein Bildschirmfoto einer laufenden App erzeugt und keine Übereinstimmung auf Pixelebene behauptet. Der UI-Test erzeugt native Screenshot-Anhänge, sobald er auf einem Mac ausgeführt wird.
