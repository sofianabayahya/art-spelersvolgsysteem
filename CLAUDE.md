# ART Spelersvolgsysteem

Spelersvolgsysteem voor ART 1 (Ajax Regionale Trainingen) bij AS'80. Eigenaar/hoofdtrainer: Sofian.
Live op https://www.artsvs.nl (artsvs.nl stuurt door naar www). Taal van de UI en van het overleg: Nederlands.
Los project; heeft niets te maken met ClubComm (`~/Projects/clubcomm`).

## Techniek
- Frontend: één bestand `index.html` (inline CSS + vanilla JS, geen framework, geen build-stap). Supabase JS-client via CDN.
- `manifest.json`, `sw.js` (service worker zonder caching, alleen voor installeerbaarheid), `icon-192.png`, `icon-512.png`.
- Backend: Supabase-project `vosamkqhdnmkkecvebyl`. Tabellen: `players`, `scores`, `evaluations`, `scout_reports`,
  `cancelled_trainings`, `profiles`, `player_favorites`, `app_settings`. RLS per rol (`hoofdtrainer`, `trainer`, `scout`).
  Storage: `branding` (publiek, clublogo) en `player-photos` (privé, signed URLs; alleen hoofdtrainer schrijft). Kolom `players.foto_path`.
- Hosting: Vercel-project `art-spelersvolgsysteem` (`prj_XZDu9w49p1TRanw9dzuMRnvECCp1`, team `sofian8`),
  gekoppeld aan GitHub `sofianabayahya/art-spelersvolgsysteem` (publiek). Push naar `main` = automatische productie-deploy.
  `.vercelignore` houdt `CLAUDE.md`, `tools/`, `supabase/` en `.claude/` uit de live site.

## Afspraken (kaders)
1. GitHub `main` is de enige bron. Nooit deployen met `vercel deploy`, nooit bestanden uploaden via de GitHub-website.
   (Op 2026-09-27 ging de site offline door twee losse `vercel deploy`-uploads; hersteld door 7cfd654 te promoten.)
2. Eén werkplek: Claude Code in deze map. Geen wijzigingen meer vanuit Claude Chat/Cowork.
3. Werkwijze per wijziging: Sofian beschrijft → Claude past lokaal aan → Claude toont de wijziging → Sofian zegt akkoord
   → push → Vercel deployt → Claude controleert www.artsvs.nl.
4. Sofian doet inloggen en klikken in dashboards (Vercel, Supabase, GitHub); Claude doet code, testen, pushen, controleren.
5. Supabase-schema niet wijzigen zonder eerst te vragen (backend is live en in gebruik).
6. Sofian is geen developer: leg stap voor stap uit, één stap tegelijk, en controleer zelf na elke stap.

## Inloggen en accounts
- Inloggen met gebruikersnaam + wachtwoord (geen e-mailcode meer; besluit Sofian 2026-09-27). Gebruikersnaam `jan` = intern
  account `jan@artsvs.nl`; een volledig e-mailadres invullen werkt ook (bestaande accounts).
- Sofian maakt accounts aan in Instellingen; wachtwoord wordt gegenereerd en via WhatsApp doorgestuurd.
  Elke scout een eigen account, na het bezoek uitzetten (niet delen: scouts zien spelersgegevens van minderjarigen).
- Edge Function `manage-users` (bron: `supabase/functions/manage-users/index.ts`, deploy via Supabase MCP):
  list / create / reset_password / set_disabled. Controleert dat de beller hoofdtrainer is; raakt nooit
  het eigen account of een hoofdtrainer. Uitzetten = Supabase ban.
- E-mail: domein artsvs.nl is geverifieerd in Brevo (DKIM via Hostnet-DNS, DMARC p=reject blijft). Nog niet gekoppeld
  als SMTP in Supabase; alleen nodig als we later mail willen versturen.

## Git zonder git
De Command Line Developer Tools (en dus `git`) zijn nog niet geïnstalleerd. Tot die tijd:
- `perl tools/gh.pl status` — verschil tussen lokale bestanden en GitHub `main`.
- `perl tools/gh.pl pull` — alles van GitHub ophalen (overschrijft lokaal), zet `.last-sync`.
- `perl tools/gh.pl push "bericht" bestand1 bestand2` — één commit op `main`; weigert als GitHub buiten ons om is gewijzigd.
- `perl tools/gh.pl push-test "bericht" bestanden` — zet het op branch `test`: Vercel-preview op
  https://art-spelersvolgsysteem-git-test-sofian8.vercel.app (afgeschermd, Sofian test daar vóór livegang).
- `perl tools/serve.pl` — lokale testserver (poort 5060). De ingebouwde browser kan localhost hier niet openen.
Token: fine-grained GitHub-token "ART app" (alleen deze repo, Contents read/write, 90 dagen, aangemaakt 2026-09-27),
opgeslagen in de macOS-sleutelhanger onder `github-art-token`. Nooit tonen of loggen.
Bij verlopen token: nieuwe maken met dezelfde rechten en opslaan met
`security add-generic-password -U -a "$USER" -s github-art-token -w`.
Zodra `git` beschikbaar is: overstappen op een gewone clone.

## Openstaand werk
- [ ] Spelersfoto's van Sofian verwerken (hesjenummer koppelen aan speler).
- [ ] Opruimen: mislukte `vercel deploy`-deployments 5Pt3wQ9YF en 77GpcfXHQ laten verwijderen door Sofian.
- [ ] Later: Command Line Developer Tools installeren en overstappen op gewone git.
