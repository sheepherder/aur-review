# aur-review

Ein Hook für [yay](https://github.com/Jguer/yay), der jedes AUR-Paket vor dem Bauen von Claude Code bewerten lässt und danach fragt, ob gebaut werden soll.

## Warum vor dem Bauen

Beim Bauen eines AUR-Pakets führt makepkg den Code der PKGBUILD mit den Rechten des Nutzers aus. Dieser Code kann alles im Home-Verzeichnis lesen und ändern, auch Browserprofile und Zugangsdaten. Ein pacman-Hook käme deshalb zu spät, denn pacman kommt erst nach dem Bauen zum Zug. yay bietet ab Version 13.0.0 das Lua-Ereignis `AURPreInstall`, das nach dem Holen der AUR-Repos und vor dem ersten Aufruf von makepkg läuft. Dort setzt dieser Hook an.

## Was Claude bekommt

Für jedes Paket sammelt `aur-review` die folgenden Daten:

- Alle Dateien des AUR-Repos gehen mit; Textdateien vollständig, Binärdateien und symbolische Links nur mit Name und Größe bzw. Linkziel.
- Ist das Paket installiert, kommt der Diff seit dem Commit dazu, der zur installierten Version gehört. Die Version liefert `pacman -Q`, den Commit die `.SRCINFO` in der Git-Historie.
- Die letzten 30 Einträge des Git-Logs zeigen, wer das Paket zuletzt geändert hat.
- Die AUR-Metadaten nennen unter anderem Maintainer, Votes und das Datum der ersten Einreichung.

Claude soll die Download-Quellen und Prüfsummen bewerten, Code außerhalb von `$srcdir` und `$pkgdir` suchen, alles benennen, was als root oder automatisch läuft, und die Änderungen gegenüber der installierten Version beschreiben. Die erste Zeile der Antwort lautet `Bewertung: unbedenklich`, `prüfen` oder `gefährlich`. Danach fragt das Skript `<paket> bauen? [j/N]`, und bei Nein bricht yay ab.

## Ablauf bei `yay -Syu`

1. yay aktualisiert die Paketdatenbanken und fragt, welche Upgrades ausgeschlossen werden sollen.
2. yay holt die AUR-Repos. Code aus einer PKGBUILD läuft dabei noch nicht.
3. Für jedes AUR-Paket, alphabetisch nacheinander, läuft die Bewertung, danach kommt die Frage.
4. Es folgen yays eigene Menüs wie „Packages to cleanBuild?" und „Diffs to show?".
5. Erst danach lädt makepkg die Quellen und baut.

Ein Nein bei einem einzigen Paket bricht den ganzen yay-Lauf ab, weil `yay.abort` die gesamte Operation beendet. Wer nur ein Paket auslassen will, startet yay neu und schließt es bei „Packages to exclude" aus.

## Voraussetzungen

Gebraucht werden yay ab Version 13.0.0, ein angemeldetes Claude Code (`claude`) sowie git und curl.

## Installation

```sh
install -Dm755 aur-review ~/.local/bin/aur-review
install -Dm644 claude_review.lua ~/.config/yay/hooks/claude_review.lua
```

Danach in `~/.config/yay/init.lua` (bzw. `$XDG_CONFIG_HOME/yay/init.lua`) diese Zeile eintragen und die Datei anlegen, falls es sie noch nicht gibt:

```lua
require("hooks.claude_review")
```

yay sucht Module relativ zum Verzeichnis der `init.lua` und findet `hooks/claude_review.lua` deshalb dort. Der Hook erwartet das Skript unter `~/.local/bin/aur-review`; wer es woanders ablegt, passt `script` in `claude_review.lua` an. Zum Abschalten genügt es, die `require`-Zeile auszukommentieren.

## Wie Claude aufgerufen wird

Das Skript startet `claude -p --tools "" --no-session-persistence --strict-mcp-config` aus dem Verzeichnis `/`. Mit `--tools ""` hat Claude keine Werkzeuge, sodass Text in einer PKGBUILD, der das Modell zu Aktionen verleiten soll, nichts ausführen kann. `--strict-mcp-config` lädt keine MCP-Server, und `--no-session-persistence` speichert die Sitzung nicht. Der Start aus `/` verhindert, dass eine `CLAUDE.md` oder `.claude/`-Einstellungen aus dem AUR-Repo geladen werden. `--bare` würde noch mehr abschalten, setzt aber einen `ANTHROPIC_API_KEY` voraus und funktioniert mit einer OAuth-Anmeldung nicht.

## Grenzen

Claude sieht nur die Build-Dateien, nicht die heruntergeladenen Programme. Ob diese echt sind, hängt an Prüfsummen und Signaturen; die Bewertung meldet, wenn sie fehlen.

Eine PKGBUILD kann Text enthalten, der das Modell täuschen soll. Weil Claude keine Werkzeuge hat, ist die schlimmste Folge eine falsche Bewertung. Deshalb fragt das Skript bei jedem Paket und nicht nur bei einer kritischen Bewertung.

Eine Bewertung dauerte im Test knapp drei Minuten (ein Paket, 22 KB Eingabe). Bei mehreren AUR-Updates laufen die Bewertungen nacheinander. Jede Bewertung ist ein Aufruf über das eigene Claude-Konto, und die Dateien des AUR-Repos gehen dabei an Anthropic. Schlägt der Aufruf von `claude` fehl, bricht yay ab.

Prompt und Ausgabe sind deutsch.
