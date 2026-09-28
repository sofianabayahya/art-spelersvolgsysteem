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
- Tabvolgorde: Spelers · Aanwezigheid · Evaluatie · Rapport (Rapport = voormalig Overzicht, alleen hoofdtrainer, data-tab
  heet intern nog "overzicht"). Rank is overal geschrapt (besluit Sofian); kolommen `rank` bestaan nog in de database.
- Rapport: lijst (geen tabel) per blok met per speler gemiddelde letters Trainers en Scouts (Wedstrijd · Potentieel),
  ster, afwezig-waarschuwing alleen bij >20%, advies-keuze; tik = volledige lijst van alle beoordelingen per blok.
  "Ajax-lijst maken" drukt het Ajax-formulier af (per lichting; letters = gemiddelde trainers + scouts). CSV-download blijft.
- Letterkleuren: A donkergroen, B lichtgroen, C neutraal, D rood (`letterChip`).
- Tabbalk zoals ClubComm: knoppen ± 12pt boven de onderrand (veilige zone min 22px).
- Overzicht toont per speler "Scout A/B" (aantal scoutbeoordelingen met A of B) en bovenaan de Sterspelers. Alleen een
  melding; contact met jeugdcoördinator/jeugdscout doet Sofian zelf.
- Migraties staan in `supabase/migrations/`.

## Praktische afspraken in de app
- Terugvegen (iPhone) / terugknop (Android) sluit het bovenste open venster via zijn sluitknop (één extra stap in
  history zolang er een venster openstaat). Namenspel heeft ook een grote knop "Stoppen".
- Rolwissel (alleen hoofdtrainer): accountmenu → "Bekijk de app als" Hoofdtrainer/Trainer/Scout (`Auth.setViewAs`,
  localStorage `art-view-as`). Puur weergave: database-rechten blijven hoofdtrainer, opslaan onder eigen account.
  Gele testbalk met "Terug naar hoofdtrainer". Eigen rol is niet te wijzigen in Accounts; database-trigger
  `trg_laatste_hoofdtrainer` weigert dat de laatste hoofdtrainer van rol verandert of verdwijnt.
- Seizoen instelbaar (Instellingen → Seizoen): `app_settings.training_dates` (datum+blok) en `app_settings.lichtingen`;
  `applySeason()` past het toe. De vaste lijsten in de code zijn alleen nog de terugval.
- Account verwijderen laat beoordelingen/evaluaties staan (FK on delete set null); naam beoordelaar wordt bewaard in
  `trainer_naam` / `scout_naam` (trigger `bewaar_beoordelaar_naam`). Toch: accounts bij voorkeur uitzetten.
- Logo wordt bij upload verkleind tot max. 256px PNG (`shrinkImage`).
- Prullenbak: spelers verwijderen = `players.deleted_at` zetten; RLS verbergt ze voor niet-hoofdtrainers; pg_cron-job
  `art-prullenbak-legen` (dagelijks 03:30 UTC) verwijdert na 30 dagen definitief. Terugzetten/definitief in Instellingen.
- Back-ups: Supabase Pro maakt dagelijks een volledige back-up (7 dagen). Daarnaast tabel `backups` met JSON-momentopname
  via `make_backup()`; pg_cron-job `art-wekelijkse-backup` (maandag 03:00 UTC), laatste 26 bewaard, downloadbaar in Instellingen.
- Invulvensters vragen bevestiging bij sluiten met niet-opgeslagen wijzigingen (`guardSheet`).
- supabase-js staat vast op 2.117.2 met SRI-integrity; bij updaten ook de hash vernieuwen.
- Vast app-frame: html/body overflow hidden, #appRoot 100% hoog (flex), kop en tabbalk zijn gewone flex-items, alleen
  <main> scrollt (overscroll contain). Geen position:sticky/fixed voor kop/tabbalk: dat liet ze op iOS meeschuiven.
- iOS-beginscherm-app: de app valt tussen statusbalk en thuis-streepje; die stroken kleurt iOS met theme-color /
  manifest-kleur. Die staan op #16223F (= kleur van kop en tabbalk), zodat de balken doorlopen tot de rand.
  Na wijzigen van manifest-kleuren kan opnieuw toevoegen aan het beginscherm nodig zijn.
- Tabbalk zoals Magister: actief = gekleurd icoon/tekst + streepje bovenaan, geen groot blok.
- Als Vercel een push niet oppakt (geen deployment voor de commit): nieuwe push geeft een nieuw seintje.
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
  Blokkeuze en voortgang staan compact op één regel naast de titel "Spelers" ("Blok 1 ▾ · 3/7 ✓").
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

## Namen oefenen
- Knop "Namen oefenen" boven het smoelenboek (alle rollen). Twee vormen: Koppelen (tik foto + naam; goed = naam op kaart en
  weg uit lijst) en Wie is dit? (grote foto, kies naam; fouten komen 2 vragen later terug). Per lichting of "Alle" (8 minst
  gekende). Voortgang per gebruiker in localStorage `art-namen-<userId>`; gekend = 3x goed over >= 2 dagen.

## Coachdashboard (tabblad Training, fase 1 gebouwd 2026-09-28)
- Tabbladen: Spelers · Aanwezig · Training · Rapport (scout: alleen Spelers). Aanwezig is een eigen tabblad (veld,
  telefoon) met eigen datumkeuze en telling "x aanwezig · y afwezig". Training = datumkeuze + Voorbereiden / Evaluatie
  (paneel evaluatie is sub-paneel; zijn datumkeuze is verborgen, state.trainingDate stuurt het aan).
- Voorbereiden = weekplan: "Jouw taak" (eigen onderdeel, vormen, deadline), "De training" (per onderdeel eigenaar +
  status per vorm, "x van 5 gedeeld" / "✓ Compleet" als A1 A2 B1 B2 C2 gedeeld zijn; hoofdtrainer krijgt een
  WhatsApp-knop "Herinner" met ingevuld bericht), knop "Bekijk hele training" (scherm, Ajax-opbouw, alleen lezen)
  en Downloaden. Rolverdeling alleen voor de hoofdtrainer, plus "Rooster maken": rollen voor de eerste training van
  een blok kiezen, daarna schuift iedereen per training één rol door; toernooien tellen niet mee; trainingen die al
  geweest zijn blijven ongemoeid; deadline = x dagen vóór de training. Opslaan = rijen in training_plans (geen schema).
- Alle trainers zien de hele training (en elkaars reflecties); alleen de eigenaar (en hoofdtrainer) bewerkt.
- Update 2026-09-28 (2): Training opent altijd op Voorbereiden van de eerstvolgende training; balkje "jouw vorm nog
  evalueren" voor de vorige training. Rollen heten Trainer A / Trainer B / Assistent (niet "hoofdtrainer A/B": verwarrend
  met de app-rol). Geen rolverdelingskaart meer: hoofdtrainer heeft knop "Rollen wijzigen" (rollen + evt. afwijkende
  deadline + rooster). Deadline = vanzelf vrijdagavond (training_plans.deadline null = 2 dagen voor zondag; `effDeadline`).
  Knoppen bij een vorm: "Opslaan, nog niet klaar" en "Klaar" (status concept/gedeeld); upload = linkje "of een
  foto/screenshot toevoegen". Oefenvormvenster: tekening links (laptop, blijft staan) of bovenaan (telefoon), ook bij evalueren.
- Fase 2 gebouwd: evaluatie per vorm bevat reflectie (`oefenvormen.reflectie_goed`, `reflectie_anders`, zichtbaar voor
  alle trainers). Reactie hoofdtrainer in tabel `reflectie_reacties` (1 per vorm; RLS: alleen die trainer + hoofdtrainer
  lezen, alleen hoofdtrainer schrijft). Oude evaluatieformulier uit beeld; oude evaluaties alleen nog getoond als ze er
  zijn ("Eerdere evaluaties"). Trainingstabellen staan nu in de realtime-publicatie. Migratie 20260928_reflectie.sql.
- Opbouw per vaardigheid (Sofian, 2026-09-28): A1 = droog (A1.1, spacing, A1.2 contextvariatie); A2 = small-sided game
  (A2.1, spacing, A2.2 contextvariatie). Dus bij BEIDE vormen is x.2 de contextvariatie. C alleen C2 (SSG).
- Voorbereiden/Evaluatie tonen de vormen als tegels met de tekening (`vormTile`): telefoon 2 naast elkaar, laptop max
  320px per tegel; eigen rij met groene rand; "Jouw taak" is één regel bovenaan.
- Tekentool op telefoon/tablet: gele tip "uittekenen gaat het snelst op een laptop" (sluitbaar). Laptop-efficiëntie:
  sneltoetsen op de knoppen (1-4 spelers, T, K, B bal, H hoedje in laatst gekozen kleur, V vak met hoedjes, D pupillendoel,
  M minidoel, L/P/R/S pijlen), "Vak met hoedjes" (sleep rechthoek = 4 hoedjes op de hoeken), klik op bestaand item met
  neerzet-knop actief = pakken, rechtermuisklik = stoppen. In vorm 2: "Neem tekening van A1 over". Nog niet: meerdere
  items tegelijk selecteren (later, als ze het missen).
- Tekentool zoomt bij opslaan automatisch in op het getekende stuk (`contentBox`: alle items + 60px marge, 3:2, min 330x220;
  gebruikt de tekening > 80% van het veld, dan heel veld). Vinkje "Opslaan ingezoomd op de spelers" (standaard aan,
  bewaard als `zoom` in tekening_json). Tekenen gebeurt altijd op het hele veld. Geen aparte "kwart vak"-veldvorm (besluit).
- Tekentool: nog een keer op de actieve knop = stoppen met neerzetten. Spelers r=12.5 (was 17). ART gebruikt alleen
  pupillendoelen (5x2 m) en minidoelen (2x1 m); ~10 beeldpunten per meter (oude "L" groot doel wordt nog getekend).
  Pion vervangen door trainingshoedjes in 6 kleuren (oranje, blauw, rood, geel, groen, roze; `HAT`, `hatSvg`), getekend
  naar de foto's van Sofian (niet de foto's zelf: scherper, lichter, geen webshopnaam). Bal: wit met naden (`ballSvg`).
- Ajax-opbouw (Sofian): vorm 1 is droog, zonder weerstand (1v0, bewegingsvariaties); vorm 2 is de contextvorm met
  weerstand (aantallen uit de periodisering, bv. 2v1 of 3v3), x2.2 = contextvariatie (welke regel/ruimte verandert).
- Kleine tekeningen (thumbnail) bij elke vorm, ook in Evaluatie; eigen vormen staan bovenaan.
- Besluiten 2026-09-28 leeromgeving: reactie van de hoofdtrainer op een reflectie is alleen zichtbaar voor die trainer;
  GEEN persoonlijk leerdoel per blok; GEEN "zien hoe hij groeit"-overzicht. WEL een vormenbank (fase 3).
  Plan: fase 2 = één evaluatie per vorm incl. reflectie + reactie hoofdtrainer, oude evaluatieformulier weg
  (schemawijziging, eerst vragen); fase 3 = vormenbank; fase 4 = scout: zoeken op hesjenummer, "vandaag trainen ze op",
  oude uitgebreide scoutformulier opruimen.
- Tabellen: `training_plans` (per datum: hoofd_a, hoofd_b, assistent, deadline), `oefenvormen` (datum, onderdeel A/B/C,
  volgnr 1/2, eigenaar, vaste velden, tekening_path, status concept/gedeeld, eval_*), `oefenvorm_feedback` (tip/top).
  Bucket `training-images` (privé). Onderdeel A = hoofd_a, B = hoofd_b, C = assistent (alleen C.2).
- Periodisering in `app_settings.periodisering` = { regels: [...], trainingen: { datum: {A:{v,a},B,C} | {toernooi} } },
  gekoppeld op datum aan de afgesproken trainingen (kick-off 6 sep en 17 jan zijn geen trainingen in de app).
- Oefenvorm volgt de Ajax Training planner: volgnr 1 = deel 1 bewegingsvariaties (rondes x1.1/x1.2, max 6 min),
  volgnr 2 = deel 2 contextvorm (x2.1 beschrijving, x2.2 contextvariatie, max 8 min); velden `variatie_1`, `variatie_2`.
  Weergave als A1/A2/B1/B2/C2.
- Tekentool (`DrawTool`, SVG): veldvormen 11x11 (staand/liggend), 8x8, 6x6, half veld, vak (geen zaalvoetbal);
  spelers in 4 kleuren x 2 vormen (rood/lichtblauw rondje, geel/blauw driehoek) met automatisch nummer per team,
  trainer T en keeper K; bal, pion, schijfjes (wit/geel/oranje/roze), goals L/M/S, kaatsbord; pijlen (loop/pass/
  dribbel/schot), muur, nummers, vak, tekst; dupliceren (Cmd/Ctrl+D), draaien, ongedaan maken. Opslaan = JPEG (tekening_path) + bewerkbare gegevens (`tekening_json`).
  Laptop eerst, werkt ook met vinger. Geen animatie (besluit Sofian).
- "Training downloaden": afdruk/PDF in Ajax-plannervorm (per thema deel 1 en 2 met tekening en teksten).
- Namen oefenen alleen voor trainers en hoofdtrainer (scouts niet, besluit Sofian).
- Nog niet: bibliotheek, timer.
- Trainingsopzet: hoofdtrainer A en B hebben elk een vaardigheid; per vaardigheid oefenvorm 1 en 2, elk twee keer gegeven
  (groep 1, spacing, groep 2; assistent draait door). Rolverdeling per training zichtbaar (hoofdtrainer A/B, assistent,
  taken/coachgedrag), eigenaar + deadline per oefenvorm, controlepunt wedstrijdelement, aanpassingen vooraf ("als het niet loopt").
- Evaluatie per oefenvorm: kwam de doelvaardigheid terug (ja/deels/nee), groep 1 → wat aangepast → groep 2, loopt het /
  wat aangepast, ruimte en welke lichting had moeite, wat volgende keer anders.
- NIET: aantal keer per speler, video (upload of link), groepsindeling voor scouts, halfuur-timer. Grote instelbare timer:
  Sofian denkt nog na.
- Tekening: upload screenshot/foto van de oefenvorm (verkleind); tekst in vaste velden in de app. Eenvoudig tekenbord pas later.
- Periodisering Blok 1+2 aangeleverd als pptx (Downloads).

## Openstaand werk
- [x] 2026-09-27: testdata opgeschoond (alle beoordelingen, scoutrapporten, favorieten) en alle accounts behalve Sofian
      (hoofdtrainer) verwijderd, o.a. Tommy (trainer, tommyverhulst1@gmail.com) en Peter Muster (scout). Back-up nr. 2 ervoor.
      Trainers en scouts opnieuw aanmaken via Instellingen → Accounts wanneer het testen/gebruik begint.
- [ ] Spelersfoto's: 23 foto's voorbereid in ~/Downloads/ART-fotos/klaar-om-te-uploaden (naam = hesjenummer);
      Sofian uploadt ze via Instellingen → "Spelersfoto's in één keer uploaden". Speler zonder hesje (lichting 2017) heeft nog geen foto.
- [ ] Opruimen: mislukte `vercel deploy`-deployments 5Pt3wQ9YF en 77GpcfXHQ laten verwijderen door Sofian.
- [ ] Later: Command Line Developer Tools installeren en overstappen op gewone git.
