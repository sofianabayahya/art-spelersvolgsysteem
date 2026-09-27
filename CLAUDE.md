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
3. Werkwijze per wijziging: Sofian beschrijft → Claude past lokaal aan en controleert → push naar main → Vercel deployt
   → Claude controleert www.artsvs.nl → Sofian test live. Geen tussenstap via de test-branch zolang de app nog niet
   in gebruik is (besluit Sofian 2026-09-27). Zodra trainers/scouts de app echt gebruiken: weer eerst via `push-test`.
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

## Scouting
- ART is een scoutingsprogramma: scouts vullen de Ajax-lijst in voor ART-spelers: Wedstrijdbeoordeling + Potentieel
  (A/B/C/D, zelfde als trainers), Rank (#1 bovenste 3 / #3 onderste 3 per lichting, leeg = middenmoot), Advies 1-4,
  plus een notitie "waarom". Eén beoordeling per scout per speler per blok (tabel `scout_reports`,
  kolommen `wedstrijdbeoordeling`, `potentieel`, `notitie`). Oude uitgebreide rapportvelden blijven bestaan voor oude data.
- Scouts zien alleen hun eigen beoordelingen (RLS); de hoofdtrainer ziet alles.
- Overzicht toont per speler "Scout A/B" (aantal scoutbeoordelingen met A of B) en bovenaan de Sterspelers. Alleen een
  melding; contact met jeugdcoördinator/jeugdscout doet Sofian zelf.
- Migraties staan in `supabase/migrations/`.

## Praktische afspraken in de app
- Prullenbak: spelers verwijderen = `players.deleted_at` zetten; RLS verbergt ze voor niet-hoofdtrainers; pg_cron-job
  `art-prullenbak-legen` (dagelijks 03:30 UTC) verwijdert na 30 dagen definitief. Terugzetten/definitief in Instellingen.
- Back-ups: Supabase Pro maakt dagelijks een volledige back-up (7 dagen). Daarnaast tabel `backups` met JSON-momentopname
  via `make_backup()`; pg_cron-job `art-wekelijkse-backup` (maandag 03:00 UTC), laatste 26 bewaard, downloadbaar in Instellingen.
- Invulvensters vragen bevestiging bij sluiten met niet-opgeslagen wijzigingen (`guardSheet`).
- supabase-js staat vast op 2.117.2 met SRI-integrity; bij updaten ook de hash vernieuwen.
- Mobiel: invoervelden 16px (anders zoomt iOS in), grotere tikvlakken bij `pointer:coarse`.
- Supabase heeft twee projecten in dezelfde Pro-organisatie: ARTsvs Project (deze app) en ClubComm (ander project, niet aanraken).
- Alles wat niet ongedaan kan (speler/foto/evaluatie/scoutrapport/logo verwijderen, account uitzetten, nieuw wachtwoord,
  training afgelasten, foto's vervangen) gaat via `confirmDialog()`: een venster met naam en gevolgen. Nooit meer
  "twee keer tikken"; daardoor werd op 2026-09-27 per ongeluk speler 108 (Jaël Martina) verwijderd (teruggezet, aanwezigheid kwijt).
- Updates: `Updater` vergelijkt de pagina op de server met de geladen versie (bij terugkeren naar de app en elke 5 min).
  Terugkeren zonder open venster = stil vernieuwen; anders een balk "Nieuwe versie" met knop.
- Foto-links (signed URLs) 24 uur geldig en bewaard in localStorage; gewist bij uitloggen. Nieuwe upload = nieuwe bestandsnaam.
- Hesjenummer overal groot in rood/geel naast de foto (`playerIdentHtml`, `fillPlayerPhotos`).
- Tabblad Spelers = smoelenboek (2 kolommen, 3 op tablet). Foto blijft schoon (hesje op de foto toont het nummer); balk
  onder de foto: hesjenummer · geboortekwartaal (scouts wegen het mee) · ster/! rechts, daaronder de naam. Geen knoppen in de lijst: tikken opent de spelerskaart (`openPlayerCard`) met per rol
  de info en acties (Beoordelen; hoofdtrainer ook Bewerken). Beheer (nieuwe speler, importeren, foto's, prullenbak) staat
  in Instellingen → Spelers beheren. Instellingen is ingedeeld in uitklapbare groepen.
- Beoordelen gebeurt vanuit Spelers (tabbladen Beoordelen en Scouting zijn opgeheven): balk "Beoordelen in [blok]" met
  "x van y door jou beoordeeld", groen ✓ rechtsboven op de foto = door jou beoordeeld in dat blok, tik → spelerskaart → Beoordelen
  (trainer/hoofdtrainer: trainerlijst; scout: Ajax-scoutlijst). Eén blokkeuze voor iedereen (`state.beoordelenBlok`).
  Geen "opslaan & volgende" (besluit Sofian). Heeft iemand maar één tabblad (scout), dan is de tabbalk onderin verborgen.
- Favorieten (eigen top 3) zijn geschrapt (besluit Sofian): de ster ★ komt vanzelf uit de beoordelingen. Ster = aantal
  trainer- + scoutbeoordelingen met een A of B >= `app_settings.scout_signaal_drempel`. Alleen zichtbaar voor de hoofdtrainer.
  Tabel `player_favorites` bestaat nog in de database maar wordt niet meer gebruikt.
- Denkwijze bij ontwerp (Sofian): per knop afwegen wie hem gebruikt en hoe vaak; zelden gebruikt = naar Instellingen.

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
- [ ] Spelersfoto's: 23 foto's voorbereid in ~/Downloads/ART-fotos/klaar-om-te-uploaden (naam = hesjenummer);
      Sofian uploadt ze via Instellingen → "Spelersfoto's in één keer uploaden". Speler zonder hesje (lichting 2017) heeft nog geen foto.
- [ ] Opruimen: mislukte `vercel deploy`-deployments 5Pt3wQ9YF en 77GpcfXHQ laten verwijderen door Sofian.
- [ ] Later: Command Line Developer Tools installeren en overstappen op gewone git.
