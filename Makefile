# Installiert aur-review für den aktuellen Benutzer und trägt den Hook in
# yays init.lua ein. uninstall entfernt zuerst die Zeilen aus init.lua und
# danach die Dateien: Fehlt die Hook-Datei, während die require-Zeile noch
# steht, startet yay nicht mehr.

BIN  = $(HOME)/.local/bin/aur-review
CONF = $(or $(XDG_CONFIG_HOME),$(HOME)/.config)
# Wie yay: die erste vorhandene init.lua, sonst eine neue unter CONF.
INIT = $(firstword $(wildcard $(CONF)/yay/init.lua $(HOME)/.config/yay/init.lua) $(CONF)/yay/init.lua)
HOOK = $(dir $(INIT))hooks/claude_review.lua

# Diese drei Zeilen kommen in init.lua; uninstall löscht genau sie wieder.
LINE1 = -- aur-review: Claude prüft jedes AUR-Paket vor dem Bauen; AUR_REVIEW=0 yay ... überspringt das.
LINE2 = -- Hook: $(HOOK), Skript: $(BIN)
LINE3 = require("hooks.claude_review")

.PHONY: install uninstall

# Vor 13.0.0 liest yay init.lua nicht, und erst ab 13.0.1 findet require()
# die Hook-Datei neben init.lua. Die Version kommt aus der Paketdatenbank,
# weil yay --version init.lua lädt und an einer kaputten init.lua scheitert,
# also gerade dann, wenn install sie reparieren soll. grep ohne -x zählt
# auch eine auskommentierte require-Zeile, damit ein abgeschalteter Hook
# abgeschaltet bleibt.
install:
	@command -v claude >/dev/null || { echo "aur-review: claude nicht gefunden"; exit 1; }
	@v=$$(pacman -Q "$$(pacman -Qqo yay 2>/dev/null)" 2>/dev/null | awk '{ print $$2 }'); \
	  [ "$$(vercmp "$$v" 13.0.1)" -ge 0 ] || \
	  { echo "aur-review: braucht yay ab 13.0.1, gefunden: $${v:-keins}"; exit 1; }
	install -Dm755 aur-review $(BIN)
	install -Dm644 claude_review.lua $(HOOK)
	grep -qsF '$(LINE3)' $(INIT) || printf '%s\n' '$(LINE1)' '$(LINE2)' '$(LINE3)' >> $(INIT)

# --follow-symlinks, damit eine verlinkte init.lua (stow, chezmoi) ein Link
# bleibt. Steht danach noch eine aktive require-Zeile da, etwa von Hand
# geändert, bleibt die Hook-Datei liegen. rm -f, damit uninstall auch nach
# einer teilweisen Deinstallation durchläuft.
uninstall:
	sed -i --follow-symlinks -e '\|^$(LINE1)$$|d' -e '\|^$(LINE2)$$|d' -e '\|^$(LINE3)$$|d' $(INIT)
	@! grep -q '^[[:space:]]*require.*hooks\.claude_review' $(INIT) || \
	  { echo "aur-review: $(INIT) enthält noch eine aktive require-Zeile für den Hook, Dateien nicht gelöscht"; exit 1; }
	rm -f $(BIN) $(HOOK)
