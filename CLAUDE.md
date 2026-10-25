# ART Volg- en ontwikkelsysteem (ART VOS)

Volg- en ontwikkelsysteem voor ART 1 (Ajax Regionale Trainingen) bij AS'80. Eigenaar/hoofdtrainer: Sofian.
Naam sinds 2026-10-25 (besluit Sofian): "ART Volg- en ontwikkelsysteem", kort "ART VOS" (spelers volgen, trainers
ontwikkelen; was "ART Spelersvolgsysteem"). Live op https://www.artsvs.nl (artsvs.nl stuurt door naar www). Taal van de UI en van het overleg: Nederlands.
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
   → Claude controleert www.artsvs.nl → Sofian test live; bevalt het niet, dan passen we het aan.
   Besluit Sofian 2026-10-19: rechtstreeks live, geen tussenstap via de testversie meer. Uitzondering die Claude zelf
   bewaakt: grote of riskante wijzigingen (databasewijzigingen die bestaande data raken, inloggen, veel tegelijk
   ombouwen) eerst via `push-test`, en dat dan vooraf even melden.
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

## Demo (www.artsvs.nl/demo), gebouwd 2026-09-28 voor de pitch bij Ajax
- `vercel.json` herschrijft /demo naar index.html; `DEMO` = pad is /demo. Inloggen gaat via het echte account; alleen de
  (echte) hoofdtrainer mag de demo starten (`startDemo`), anderen zien "Alleen voor de hoofdtrainer".
- Na inloggen wordt `sb` vervangen door `DemoDB.client(real)`: een nep-Supabase in het geheugen (select/insert/upsert/
  update/delete + eq/order/single/maybeSingle, rpc set_attendance, storage met getekende poppetjes als foto,
  manage-users alleen "list"). Auth (inloggen/uitloggen) blijft echt; wachtwoord wijzigen kan niet in de demo.
  Er gaat dus NIETS naar de echte database; verversen = demo weer schoon. Seizoen/periodisering/logo komen wel uit
  de echte app_settings (Branding.load vóór de wissel).
- Verzonnen data (`DemoDB.seed`): 24 spelers, trainers Tim de Groot/Kevin Postma/Rick Verhoef, scouts Johan Laan/Erik
  Stam, beoordelingen, aanwezigheid, en de training van 27 sep (`DEMO_VORMEN`, kopie van de echte 5 vormen) met
  reflectie, tips/tops en een reactie van de hoofdtrainer. Geen echte kinderen of namen in de demo.
- Rondleiding (`Tour`), laptop eerst (Sofian presenteert altijd op de laptop): app links (±70%), vast uitlegpaneel
  rechts (`--tp` = clamp(340px, 30vw, 500px)) met tekst, Vorige/Volgende, voortgangsbalk en alle stappen als lijst
  (klik = springen). Besproken onderdeel krijgt een gele rand (licht gedimde rest). App-vensters blijven in het linkerdeel
  (`body.tour-open .overlay{right:var(--tp)}`). 17 stappen, incl. "Zo ziet een scout het" (bekijken als scout).
  Pijltjestoetsen, Esc = paneel dicht. Smal scherm: paneel onderin (niet het doel).
  Gele "DEMO"-pil bovenaan met knop "Rondleiding". Stappen zijn in `Tour` aan te passen (sel, title, text, go).
- Wijzigt de app, controleer dan of de selectors van de rondleiding nog kloppen.
- Rondleiding herschreven 2026-10-24 voor iemand uit de Ajax-gemeenschap (Sofian: het gaat om de trainers, scouts zijn nog
  niet toe aan digitaal). 22 stappen in drie lijnen: Wat we trainen (weekstrook, training, vorm, tekentool, hele training,
  vormenbank) → Trainers ontwikkelen (rollen rouleren, Voor jou, tips/tops, evaluatie+reflectie, reactie) → Wat opvalt bij
  spelers (aanwezig offline, opvallende spelers/SoccerLab, beoordelen, spelerskaart-tijdlijn, toernooi, nabespreking-rapport,
  rapport/Ajax-lijst) → Namen oefenen, seizoen bijhouden, veilig. Scout-kant weggelaten.
- Demo-seed aangevuld: duur bij de vormen, `opvallend` (27 sep), toernooi-nabespreking met oordelen voor het laatste
  toernooi uit de periodisering, en voor "Voor jou" een eigen concept-A1 + tip in de eerstvolgende training.
  In de demo is het Toernooi-tabblad altijd zichtbaar (laatste toernooi).

## Vorm van een ander lezen (2026-10-25)
- Oefenvorm-venster: alle tekstvakken groeien mee met hun tekst (`groeiMee`), rechterkolom scrollt. Kan de gebruiker niet
  bewerken (vorm van een andere trainer), dan `.oef-lezen`: één kolom, tekst 19px, niet grijs, lege velden verborgen.

## Verwacht per groep en doorschuiven (2026-10-25)
- Bovenaan Aanwezig én Training → Voorbereiden: kaart "Verwacht vandaag / op [datum]" met totaal en per lichting het aantal
  niet-afgemelde spelers (`verwachting`, `verwachtHtml`), met "+1 uit 2018", "1 naar andere groep", "1 afwezig".
  Niet bij afgelaste trainingen en toernooien.
- Doorschuiven: knop ⇄ per aanwezige speler in Aanwezig → "Sluit vandaag aan bij" (lichting-chips). Opgeslagen in de
  aanwezigheid van die datum als { groep: "l2019" } (geen schemawijziging; `groepVan`). Eigen lichting kiezen = wissen.
  Afwezig zetten vervangt de waarde (doorschuiven vervalt).

## Opvallende spelers (2026-10-23)
- Tabel `opvallend` (training_date, player_id, bron, tekst; migratie 20261023_opvallend.sql; RLS alleen hoofdtrainer).
- Training → Evaluatie, kaart bovenaan (hoofdtrainer): per speler noteren wat scouts/trainers na de training noemden
  (wie = vrije tekst met eerder gebruikte namen), "Kopieer voor SoccerLab" (tekst per speler met lichting en hesje).
  Verschijnt ook op de tijdlijn van de spelerskaart.
- 2026-10-25: notities zijn te wijzigen (knop "Wijzigen": speler, wie, tekst; `Store.updOpvallend`). Bij "wie" staan
  eerder gebruikte namen én de voornamen van de trainers als keuze (trainers vertellen ook wat opviel).

## Toernooi-tabblad (gebouwd 2026-10-03 voor het toernooi van 4 okt)
- Eigen tabblad "Toernooi" (trainers + hoofdtrainer), alleen zichtbaar van 1 dag vóór tot 7 dagen ná een datum met
  `toernooi` in de periodisering (`Toernooi.actief()`); daarna vanzelf weg. Geen databasewijziging.
- Toernooi 4 okt (Sofian): 2019/2018 4 x 10 min (rust 2-5-2), 2017/2016 4 x 15 min (rust 2-10-2); 2018 en 2017: Milan
  (gast) vaste keeper; 2019 en 2016: keeper rouleert, maar alleen in de rust (geen handschoenen wisselen tijdens het spel);
  veldspelers wisselen elke 5 min (invaller neemt de plek van wie eruit gaat); posities alleen in de rust opnieuw verdeeld.
  `maak` = greedy per blok: minste speeltijd speelt (±1 blok), keeper per periode = minst gekeept.
- Per lichting: spelvorm (O8/O9 6v6, O10/O11 8v8; aanpasbaar), perioden/periodelengte/wissel-interval, wie speelt mee
  (standaard: afgemeld bij Aanwezig = niet), keeper (K-knop; "staat de hele wedstrijd op doel" of rouleert).
  Schema (`maak`): sliding window over de spelers, elk blok schuiven de bankspelers erin voor wie het langst speelde;
  posities per plek in de rij (aanval → middenveld → verdediging → keeper), dus gelijke speeltijd (±1 blok) en alle posities.
- GEDEELD (besluit Sofian 2026-10-03: iedereen, ook scouts, moet hetzelfde zien): de 10 gastspelers van een andere
  ART-locatie staan als gewone spelers in `players` (zonder hesje; Sofian geeft op 4 okt nummers; daarna evt. prullenbak):
  Milan van der Straeten (2018, keeper), Benjamin Darkik, Seyyid Yildiz, Skylan van Engel (2018), Amin el Aakel, Jerome
  Kaersenhout, Amin el Safoury, Haitam Liazid (2017), Loek Ooyevaar, Yusuf Yilmaz (2016).
  Toernooi-instellingen per team staan in `app_settings.periodisering.toernooi[datum].teams[lichting]` = {F, P, pl, wb,
  keeper, kAlles, extra:[speler-ids uit andere lichting]}; alleen de hoofdtrainer wijzigt (UI uitgeschakeld voor trainers).
  Wie meespeelt = Aanwezig van die datum (vinkje in het tabblad schrijft naar Aanwezig). Milan speelt ook bij 2017 (extra).
- Definitief (2026-10-03 avond): EXACT gelijke speeltijd. `maak` verdeelt de totale speeltijd (P x L) in N gelijke stukken
  (N = spelers die rouleren). Zonder vaste keeper: stuk i keept speler i, de volgende s (= N - F) zitten op de bank →
  iedereen keept één stuk en speelt exact even lang (2019: 34,3 min, keeper 5:43; 2016: 60 min, keeper 7:30). Met vaste
  keeper: bank schuift één speler per stuk door (2018: 25 min, 2017: 42 min). Wisselmomenten vallen op de stukgrenzen
  (bv. 5:43, 11:26), steeds "bij de eerste bal uit"; posities opnieuw in de rust. `sch.meta[j]` = {per, a, b (sec in periode), start}.
  Tabel: kop P1..P4 (colspan), letters als span in td (eerder stond class tt-p op de td → tabel kapot).
- Iedereen keept (scout, 2026-10-03) bij teams zonder vaste keeper (2019, 2016; vinkje "Iedereen keept", standaard aan):
  per periode ceil(spelers/perioden) keepers; keeperwissel midden in de periode bij een bal uit = één handeling
  (2019: de wisselspeler gaat op doel, de keeper eruit; 2016 zonder bank: keeper ruilt met een veldspeler en neemt zijn
  plek). Nieuwe keepers en posities in de rust. Lege momenten worden overgeslagen (`moment`, `momentTekst`).
- Wedstrijdmodus (telefoon): klok per periode (tijdstempels, overleeft scherm uit), "Volgende wissel over m:ss", op het
  moment een gele kaart "WISSEL · bij de eerste bal uit: IN x / UIT y (positie)" met piep/trillen en knop Gewisseld,
  "Tijd!" na de periode, rustscherm met aftellen + keeperwissel + nieuwe posities, einde met minuten per speler.
  Scherm blijft aan (Wake Lock). Alleen de klokstand staat per toestel in localStorage `art-toernooi-<datum>`.
- Afdrukken (per team of alle teams, 1 pagina per team), WhatsApp-tekst per team, "Afmeldingen naar Ajax" als WhatsApp-tekst.

## Toernooi-nabespreking en -rapport (gebouwd 2026-10-04)
- Scouts werken op papier (besluit scouting); Sofian noteert in de nabespreking. Alleen de hoofdtrainer ziet/schrijft (RLS).
- Tabellen (migratie 20261004_toernooi_oordelen.sql): `toernooi_nabespreking` (datum, beoordelaars jsonb [{naam, rol
  scout|trainer, lichtingen[]}]), `toernooi_oordelen` (datum, player_id, beoordelaar, rol, waarde -2..2; uniek per
  datum+speler+beoordelaar), `toernooi_notities` (datum, player_id, tekst).
- Toernooi-tabblad (hoofdtrainer): schakelaar Wedstrijd / Nabespreking. Nabespreking: beoordelaars beheren (naam, rol,
  lichtingen), per lichting de spelers die speelden, per beoordelaar een vakje → kiezer −− − +− + ++ (springt door naar
  de volgende beoordelaar), toelichting per speler, totaal live.
- Rapport-tabblad: kaart "Toernooi-rapporten" (per datum) → venster met per lichting tabel (Q, scouts, trainers, totaal,
  toelichting), top 3 groen / onderkant 3 rood, labels AVS (3× ++ scouts) en "oneens" (|gem scouts − gem trainers| ≥ 1,5),
  samenvatting (AVS, Q4 en toch hoog, hoog maar Q1, oneens). Afdrukken/pdf. Totaal = gemiddelde van alle oordelen.
- 4 okt ingevoerd (137 oordelen, 32 spelers, 29 toelichtingen) uit de nabespreking + correcties Sofian. Welke scout/trainer
  welk oordeel gaf is uit de opname benaderd; de totalen kloppen met het PowerPoint-rapport (~/Downloads).

## AVS (eenmalig, 5 okt 2026) — opgeruimd 2026-10-19
- AVS-tabblad en -gegevens verwijderd op verzoek van Sofian (back-up nr. 8 ervoor, bevat de namen nog tot hij
  uit de wekelijkse rotatie valt). De motor `maakSchema(B)` ondersteunt nog `B.spelers` (eigen teams), maar er is geen
  instantie meer.

## Spelersarchief (2026-10-19)
- Kolom `players.archived_at` (migratie 20261019_spelers_archief.sql). RLS: alleen de hoofdtrainer leest gearchiveerde
  (en verwijderde) spelers. Store: `players` = niet verwijderd en niet gearchiveerd, `getArchief()`, `setArchived(ids, aan)`.
- Spelerskaart (hoofdtrainer): knop "Archiveren". Instellingen → Spelers beheren → Archief: lijst met "Terugzetten" en
  "Meerdere spelers tegelijk archiveren" (vinkjes per lichting). Bedoeld voor gastspelers van toernooien: oordelen,
  notities en beoordelingen blijven; het toernooirapport neemt gearchiveerde spelers mee.
- "Lijst van Ajax vergelijken" (Instellingen → Spelers beheren, `parseAjaxLijst`, `renderAjaxVergelijk`): plak de tekst
  van de Ajax-pdf/Excel; namen + jaren worden eruit gehaald (pdf-pagina's plakken namen aan elkaar: bekende namen gaan voor,
  rest per 2 woorden + tussenvoegsels; jaren op volgorde gekoppeld als het aantal klopt). Voorstel met vinkjes: nieuw
  (naam/lichting aanpasbaar), terug uit archief, spelling (fuzzy, Levenshtein ≤1, ≥10 tekens ≤2), niet meer op de lijst →
  archiveren. Pas na bevestiging. Getest met "ART 2 AS'80.pdf" (blok 2, 24 namen).
- Blok 2 (2026-10-19): Ian Ringeling, Mason Crawford (2017), Kabilan Dilip (2016) toegevoegd (nog geen hesje/Q);
  Anass Belhaj en Amin el Aakel gearchiveerd; Royce Kinman → Royce Kimman.
- Niet de prullenbak gebruiken voor gasten: die verwijdert na 30 dagen definitief (met hun toernooi-oordelen).

## Na het platformdocument (2026-10-17)
- Sofian deelde een generieke "Voetbaltrainersplatform"-spec (Desktop). Besluit: niet herbouwen (geen React/Konva, geen
  animatie, geen multi-club); alleen overnemen wat ART helpt. (Werkwijze inmiddels: rechtstreeks live, zie afspraak 3.)
- Tekentool-magneet (`snapPt`): bij neerzetten/slepen springt een item horizontaal/verticaal op één lijn met andere items
  (binnen 12 px), blauwe hulplijnen tijdens slepen; schakelaar "Magneet: netjes uitlijnen" (localStorage art-draw-magneet);
  Alt/Option = even vrij.
- Meervoudig selecteren in de tekentool: slepen over een lege plek = selectievak (st.drag.mode "box", `st.multi`),
  Shift+klik = toevoegen/weghalen, Cmd/Ctrl+A = alles; groep slepen (mode "group"), Backspace/Delete = alles weg,
  Cmd/Ctrl+D = groep dupliceren, Esc = selectie weg. Selectiebalk toont "x geselecteerd".
- Knopstanden tekentool: altijd precies één knop "aan" (lichtblauw vlak + dikke blauwe rand, kleur van het selectievak):
  "Selecteren" (pijltje, Esc) als er geen gereedschap aan staat, anders het gekozen gereedschap. Muis: kruisje bij
  neerzetten/tekenen, pijl bij selecteren, verplaatskruis boven een item (`#drawSvg.plaatsen` / `.kiezen`).
- Opstellingen in de tekentool (`OPST`, `zetOpstelling`): 6v6 2-1-2 en 8v8 3-3-1, eigen team (rood) of tegenstander (geel,
  gespiegeld); staande velden verdedigen onder, liggende links.
- Vormenbank (Training → derde knop "Vormenbank", `renderBank`): alle gedeelde vormen, zoeken + filters (vaardigheid,
  droog/SSG, werkte ja/deels/nee/nog niet), tegels met tekening; venster met alles incl. evaluatie en reflectie en
  "Gebruik als basis" → kopie (status concept) naar een vorm van de eerstvolgende training die je mag bewerken.
  Kopie neemt tekening_json mee, nooit tekening_path (anders verwijdert een nieuwe upload het origineel).
- "Training overnemen" (hoofdtrainer, Voorbereiden): alle vormen van een eerdere datum kopiëren; bestaande blijven staan.

## Laptopweergave (2026-10-19)
- Vanaf 1024px breed (laptop, tablet liggend) één CSS-blok aan het EINDE van de stylesheet (moet na de basisregels staan):
  tabbalk bovenin onder de kop (`order`), knoppen naast elkaar met streepje onder; panelen tot 1280px (Instellingen 900px);
  Spelers auto-fill kolommen (min 160px); Aanwezig rijen in kolommen (min 360px) en bedieningskaart op één regel;
  Training: weekstrook (`#trWeeks`, alle trainingen van het blok met "x van 5", klik = naar die training) en A/B/C
  naast elkaar (`.tr-ocols`, per kolom 2 tegels naast elkaar: hele training op één scherm). Telefoon ongewijzigd (weekstrook verborgen).
- Oefenvorm-venster op de laptop schermvullend (KNVB-indeling): tekening links in een groot vak (leeg = gestippeld vak met
  "Tekening maken"), velden rechts in twee kolommen en compact (Sofian: zo min mogelijk scrollen). Let op: de basisregel
  `.sheet{max-width:520px}` staat laat in de stylesheet; brede vensters daarom met `.sheet.oef-sheet` / `.sheet.tv-sheet`.
- Tekentool (2026-10-19): "Opnieuw" (redo; Cmd/Ctrl+Shift+Z of Ctrl+Y; `st.redo`, gewist bij nieuwe actie); nieuwe vakken
  ("Vak markeren") tonen hun maat in meters ("20 x 15 m", 10 px = 1 m; `it.maat`, knop "Maat verbergen/tonen"; oude vakken
  zonder maat), "vak met hoedjes" toont de maat tijdens het slepen; kleur achteraf wijzigen in de selectiebalk
  (`#drawKleur`) voor spelers (4 teamkleuren, krijgen volgend rugnummer), hoedjes en schijfjes, ook voor meerdere tegelijk.
- Oefenvorm: veld "Duur (min)" naast Aantallen (kolom `oefenvormen.duur` smallint, migratie 20261019_oefenvorm_duur.sql);
  waarschuwing boven Ajax-maximum (`DUUR_MAX`: vorm 1 = 6, vorm 2 = 8 min); op tegels in de vormenbank, "Bekijk hele
  training", vormenbank-venster en afdruk; wordt meegekopieerd. "Wanneer is het gelukt?" bewust NIET (besluit Sofian).

## Uit Sofians starterspakket (2026-10-23)
- Sofian heeft een starterspakket (Desktop: app-controle.md, brein.md, lessen-uit-fouten.md, herbruikbare-onderdelen.md,
  stappenplan-techniek.md) uit zijn app mijnrijlesplanner. Werkwijze daaruit: eerst een voorbeeld (mockup) met voordelen,
  nadelen en advies, pas bouwen na zijn ja; "een status zonder knop is ruis"; meldingen verdwijnen vanzelf als het gedaan is.
- "Live"-pil rechtsboven weg (`#modePill` hidden). In de plaats: `#netBanner` (gele regel) alleen bij geen verbinding of
  bewaarde wijzigingen (`renderNet`).
- Aanwezig offline: `Store.setAttendance` zet de wijziging meteen in beeld en bij geen/slecht internet in een wachtrij
  (localStorage `art-wachtrij-aanwezig`, items {playerId, date, value, user, t}); `verstuurWachtrij` bij `online`, bij start
  en elke 30 s; nieuwste keuze per speler+datum wint; rij toont "⏳ nog niet verstuurd". `loadPlayers` legt de wachtrij
  over de geladen data. Andere schrijfacties (beoordelen, vormen) zijn niet offline.
- Krimpende titel op de telefoon (< 1024 px): na 60 px scrollen `body.kop-klein`: grote kop weg, tabnaam klein (`#kopTab`,
  tik = naar boven); terug onder 10 px. Bij tabwissel bovenaan beginnen.
- Agenda-abonnement voor trainers: voorgesteld en akkoord, maar GEPARKEERD (Sofian 2026-10-23: later, als hij met de
  trainers is). Tijden: trainers verzamelen 09:30, training 10:45-12:00 (zondag). Nodig bij bouwen: per trainer een
  geheime link → kolom in `profiles` (eerst vragen) + Edge Function die een .ics teruggeeft.

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
- Tekening zonder opgeslagen plaatje (alleen `tekening_json`) wordt door de app zelf getekend (`DrawTool.staticSvg`):
  tegels, "Bekijk hele training", invulvenster en afdruk. Opslaan in de tekentool maakt alsnog een JPEG.
- Blok 1: 13 sep = training 1 (Simon), 20 sep = training 2 (Kai), 27 sep = training 3 (Tommy). Kick-off 6 sep telt niet
  (niet op de hoofdlocatie). Het traject in de app begint bij 27 sep; 13 en 20 sep blijven leeg (tenzij Sofian ze aanlevert
  voor de vormenbank).
- 2026-09-28: training 27 sep ingevoerd door Claude vanuit de planner-foto + evaluatieverslag "3e training" (Sofians
  eigen test-A1/A2 op 27 sep op zijn verzoek overschreven; hun 2 tekening-jpg's staan nog los in de bucket): A Passeren (A1, A2), B Afwerken (B1, B2), C Beschermen/vrijmaken (C2), met
  nagetekende tekeningen (tekening_json), status gedeeld, eigenaar leeg, korte algemene evaluatie. Sofian past aan.
- Periodisering niet opgeschoven (20 sep ging één keer mis: Kai deed de training van de week erna). In plaats daarvan
  toont de app per onderdeel wat er echt gemaakt is (`thema()`: doelvaardigheid/aantallen van de vorm gaan voor de
  periodisering). Een trainer "hernoemt" een onderdeel door de doelvaardigheid in zijn vorm aan te passen.
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

## Na de UX-analyse (gebouwd 2026-10-17, eerst op de testversie)
- Zoeken in Spelers (`#spelersZoek`, `zoekSpelers`): op hesjenummer of naam, over alle lichtingen; exact nummer eerst
  en met blauwe rand (`pc-hit`); Enter opent de kaart, Esc wist. Scouts krijgen een cijfertoetsenbord.
- "Voor jou" bovenaan Voorbereiden (`voorJouItems`): nieuwe reactie van de hoofdtrainer, tips/tops van collega's op
  eigen vormen (weg zodra gelezen, of met ×; localStorage `art-gezien-<uid>`), eigen vormen van de eerstvolgende training
  die nog niet klaar zijn, en nog te evalueren vormen van de vorige training (vervangt het oude evaluatie-balkje).
  Rode badge op het tabblad Training = aantal nieuwe berichten.
- Spelerskaart (hoofdtrainer): "Tijdlijn" (`tijdlijnHtml`) per blok de letters trainers/scouts en per toernooi het
  gemiddelde oordeel, scoutsymbolen en toelichting (vervangt de rijen Trainers/Scouts van één blok).
- Uitleg bij de eerste keer inloggen (`Uitleg`): 3 kaartjes voor trainer of scout, één keer per account en rol per
  toestel (`art-uitleg-<uid>-<rol>`), opnieuw via accountmenu → "Uitleg bekijken". Niet in de demo.
- Instellingen → "Privacy en opruimen" (`vulPrivacy`): AVS-teams per datum verwijderen (uit
  `app_settings.periodisering.avs`, met bevestiging) en overzicht van scout-accounts met knop naar Accounts.
- Scout-toegang per bezoek (besluit Sofian 2026-10-17): scout-account staat normaal uit; Accounts → "Toegang voor vandaag"
  (`manage-users` actie `grant_day`: unban + `app_metadata.toegang_tot` = nu + 24 u; nieuwe scout krijgt dat meteen).
  pg_cron `art-scout-toegang` (elk kwartier, `scout_toegang_verlopen()`, migratie 20261017_scout_toegang.sql) zet verlopen
  accounts uit (ban) en wist hun sessies; open app stopt binnen een uur. Zelfde wachtwoord blijft werken. "Nu uitzetten"
  = set_disabled (wist toegang_tot). Scout zonder toegang_tot en niet uitgezet = "altijd toegang" (oude manier).

## Openstaand werk
- [x] 2026-09-27: testdata opgeschoond (alle beoordelingen, scoutrapporten, favorieten) en alle accounts behalve Sofian
      (hoofdtrainer) verwijderd, o.a. Tommy (trainer, tommyverhulst1@gmail.com) en Peter Muster (scout). Back-up nr. 2 ervoor.
      Trainers en scouts opnieuw aanmaken via Instellingen → Accounts wanneer het testen/gebruik begint.
- [ ] Spelersfoto's: 23 foto's voorbereid in ~/Downloads/ART-fotos/klaar-om-te-uploaden (naam = hesjenummer);
      Sofian uploadt ze via Instellingen → "Spelersfoto's in één keer uploaden". Speler zonder hesje (lichting 2017) heeft nog geen foto.
- [ ] Opruimen: mislukte `vercel deploy`-deployments 5Pt3wQ9YF en 77GpcfXHQ laten verwijderen door Sofian.
- [ ] Later: Command Line Developer Tools installeren en overstappen op gewone git.
