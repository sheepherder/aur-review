# aur-review

Ein Hook für [yay](https://github.com/Jguer/yay), der jedes AUR-Paket vor dem Bauen von Claude Code bewerten lässt und danach fragt, ob gebaut werden soll.

## Warum vor dem Bauen

Beim Bauen eines AUR-Pakets führt makepkg den Code der PKGBUILD mit den Rechten des Nutzers aus. Dieser Code kann alles im Home-Verzeichnis lesen und ändern, auch Browserprofile und Zugangsdaten. Ein pacman-Hook käme deshalb zu spät, denn pacman kommt erst nach dem Bauen zum Zug. yay bietet ab Version 13.0.0 das Lua-Ereignis `AURPreInstall`, das nach dem Holen der AUR-Repos und vor dem ersten Aufruf von makepkg läuft. Dort setzt dieser Hook an.

## Was Claude bekommt

Für jedes Paket sammelt `aur-review` die folgenden Daten:

- Alle Dateien des AUR-Repos gehen mit; Textdateien vollständig, Binärdateien und symbolische Links nur mit Name und Größe bzw. Linkziel.
- Wurde das Paket schon einmal geprüft, kommt der Diff seit dieser Prüfung dazu. Nach einem „j" merkt sich das Skript den geprüften Stand als Git-Ref `AUR_REVIEWED` im Git-Repo des Pakets, bei AUR-Paketen also unter `~/.cache/yay/<paket>`. Bei der ersten Prüfung eines Pakets, auch wenn es schon installiert ist, und nach dem Löschen von yays Cache gibt es keinen Diff; dann bekommt Claude nur die vollständigen Dateien.
- Die letzten 30 Einträge des Git-Logs zeigen, wer das Paket zuletzt geändert hat.
- Die AUR-Metadaten nennen unter anderem Maintainer, Votes und das Datum der ersten Einreichung.

Claude soll die Download-Quellen und Prüfsummen bewerten, Code außerhalb von `$srcdir` und `$pkgdir` suchen, auch Aufrufe von `sudo` und ausgeführte Dateien aus dem AUR-Repo, alles benennen, was als root oder automatisch läuft, und die Änderungen seit der letzten Prüfung beschreiben. Die erste Zeile der Antwort lautet `Bewertung: unbedenklich`, `prüfen` oder `gefährlich`; der Prompt legt fest, was zu welcher Stufe führt. Danach folgen höchstens 15 Zeilen.

## Ablauf bei `yay -Syu`

1. yay aktualisiert die Paketdatenbanken und fragt, welche Upgrades ausgeschlossen werden sollen.
2. yay holt die AUR-Repos. Code aus einer PKGBUILD läuft dabei noch nicht.
3. Für jedes AUR-Paket, alphabetisch nacheinander, läuft die Bewertung; danach fragt das Skript `<paket> bauen? [j/N]`.
4. Es folgen yays eigene Menüs wie „Packages to cleanBuild?" und „Diffs to show?".
5. Erst danach lädt makepkg die Quellen und baut.

Ein Nein bei einem einzigen Paket bricht den ganzen yay-Lauf ab, weil `yay.abort` die gesamte Operation beendet. Wer nur ein Paket auslassen will, startet yay neu und schließt es bei „Packages to exclude" aus.

## Voraussetzungen

Gebraucht werden yay ab Version 13.0.1 und ein angemeldetes Claude Code (`claude`).

## Installation

```sh
make install
```

Das kopiert `aur-review` nach `~/.local/bin/` und `claude_review.lua` in den Ordner `hooks/` neben der `init.lua`, die yay liest; wie yay nimmt das Makefile die erste vorhandene von `$XDG_CONFIG_HOME/yay/init.lua` und `~/.config/yay/init.lua`. An diese `init.lua` hängt es drei Zeilen an, zwei Kommentare und `require("hooks.claude_review")`; steht die `require`-Zeile schon dort, auch auskommentiert, bleibt die Datei unverändert. yay sucht Module relativ zum Verzeichnis der `init.lua` und findet den Hook deshalb dort.

## Abschalten und Deinstallation

Steht `AUR_REVIEW=0` vor dem yay-Befehl, etwa `AUR_REVIEW=0 yay -Syu`, läuft dieser eine Aufruf ohne Prüfung. Dauerhaft abgeschaltet ist der Hook, wenn in `init.lua` die Zeile `require("hooks.claude_review")` auskommentiert ist. Bricht yay nach der Prüfung ab, etwa weil die Anmeldung bei Claude abgelaufen ist, nennt die Meldung die Umgehung und die Zeile in `init.lua`, mit der man den Hook abschaltet.

`make uninstall` entfernt zuerst die drei Zeilen aus `init.lua` und danach die beiden Dateien. Steht danach noch eine aktive `require`-Zeile in `init.lua`, etwa eine von Hand geänderte, bricht es ab und lässt die Dateien liegen. Wer von Hand deinstalliert, muss dieselbe Reihenfolge einhalten, denn fehlt die Hook-Datei, während die `require`-Zeile noch steht, startet yay nicht mehr. Die Refs `AUR_REVIEWED` in den Paket-Repos unter `~/.cache/yay/` bleiben stehen; yay benutzt sie nicht.

## Wie Claude aufgerufen wird

Das Skript startet `claude -p --safe-mode --tools "" --no-session-persistence` aus dem Verzeichnis `/`. `--safe-mode` schaltet laut `claude --help` unter anderem CLAUDE.md, Hooks und MCP-Server ab; Anmeldung und Modellwahl aus den eigenen Einstellungen funktionieren normal. Mit `--tools ""` hat Claude keine Werkzeuge. In der Init-Meldung des Aufrufs (`--output-format stream-json --verbose`) stehen entsprechend keine Werkzeuge und keine MCP-Server. `--no-session-persistence` speichert die Sitzung nicht. Der Start aus `/` hält Projekteinstellungen aus dem Verzeichnis fern, in dem yay gestartet wurde.

## Grenzen

Claude sieht nur die Build-Dateien, nicht die heruntergeladenen Programme. Ob diese echt sind, hängt an Prüfsummen und Signaturen; die Bewertung meldet, wenn sie fehlen.

Eine PKGBUILD kann Text enthalten, der das Modell täuschen soll. Weil Claude keine Werkzeuge hat, ist die schlimmste Folge eine falsche Bewertung. Deshalb fragt das Skript bei jedem Paket und nicht nur bei einer kritischen Bewertung.

Nachbauten der AUR-Vorfälle vom Juli und Oktober 2026 hat es als „gefährlich" bewertet. Die Nachbauten folgen den Presseberichten; den echten Schadcode enthielten sie nicht.

Eine Bewertung dauerte in den Tests 15 bis 60 Sekunden. Bei mehreren AUR-Updates laufen die Bewertungen nacheinander. Jede Bewertung ist ein Aufruf über das eigene Claude-Konto, und die Dateien des AUR-Repos gehen dabei an Anthropic.

Prompt und Ausgabe sind deutsch.
