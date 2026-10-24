-- AURPreInstall: Claude bewertet jedes AUR-Paket, bevor yay Code aus der
-- PKGBUILD ausführt; danach fragt das Skript, ob gebaut werden soll.
-- Bei Nein oder einem Fehler der Prüfung bricht yay ab.

local script = os.getenv("HOME") .. "/.local/bin/aur-review"

yay.create_autocmd("AURPreInstall", {
  desc = "PKGBUILD-Bewertung mit claude -p",
  callback = function(event)
    if os.execute(string.format("'%s' '%s'", script, event.data.dir)) ~= 0 then
      yay.abort(event.match .. ": Bau abgelehnt oder Prüfung fehlgeschlagen")
    end
  end,
})
