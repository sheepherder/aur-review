-- AURPreInstall: Claude bewertet jedes AUR-Paket, bevor yay Code aus der
-- PKGBUILD ausführt; danach fragt das Skript, ob gebaut werden soll.
-- Bei Nein oder einem Fehler der Prüfung bricht yay ab.
-- AUR_REVIEW=0 vor dem yay-Befehl überspringt die Prüfung für diesen Lauf.

local script = os.getenv("HOME") .. "/.local/bin/aur-review"
-- init.lua liegt eine Ebene über hooks/, denn require() sucht relativ zu ihr.
local init = debug.getinfo(1, "S").source:gsub("hooks/claude_review%.lua$", "init.lua")

yay.create_autocmd("AURPreInstall", {
  desc = "PKGBUILD-Bewertung mit claude -p",
  callback = function(event)
    if os.getenv("AUR_REVIEW") == "0" then
      yay.log.warn(event.match .. ": Prüfung übersprungen (AUR_REVIEW=0)")
      return
    end
    -- Der Hinweis steht hier und nicht im Skript, damit er auch erscheint,
    -- wenn das Skript fehlt oder nicht startet. Er nennt die require-Zeile
    -- und nicht diese Datei: Fehlt die Datei, während die Zeile noch steht,
    -- startet yay nicht mehr.
    if os.execute(string.format("'%s' '%s'", script, event.data.dir)) ~= 0 then
      yay.abort("nicht gebaut (Nein oder aur-review fehlgeschlagen). Ohne Prüfung: AUR_REVIEW=0 yay ...\n"
        .. '    Abschalten: require("hooks.claude_review") in ' .. init .. " auskommentieren")
    end
  end,
})
