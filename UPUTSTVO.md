# Balkan Imovina 1.1.0

Datum izdanja: 16.11.2026. Jezik: srpski, latinica. Vremenska zona: Europe/Belgrade.

Aplikacija je jedan HTML fajl sa ugrađenim stilovima, programskim kodom, šifarnicima i SQL skriptom za instalaciju baze. Vercel isporučuje aplikaciju, a Supabase obezbeđuje prijavu, PostgreSQL bazu i privatne priloge. Supabase JavaScript biblioteka 2.119.0 učitava se sa precizno navedene CDN adrese kada se povezuje stvarna baza. Demo radi bez te biblioteke.

## Sadržaj paketa

- `Balkan_Imovina.html` — samostalna aplikacija za lokalno otvaranje, demonstraciju i povezivanje preko javnih parametara.
- `public/index.html` — ista aplikacija namenjena hostingu.
- `supabase/schema.sql` — kompletna inicijalizacija baze, dozvola, evidencije izmena i privatnog Storage bucket-a.
- `vercel.json` — build i bezbednosna HTTP podešavanja.
- `build.mjs`, `src/` — izvorni kod i ponovljivo generisanje jednog HTML fajla.
- `tests/` — automatske provere i dodatna SQL provera pristupa za Supabase test projekat.

## Najbrža proba

Otvorite `Balkan_Imovina.html` i izaberite „Otvori demo evidenciju“. Podaci su izmišljeni i jasno označeni. Izmene u demonstraciji čuvaju se samo u tom pregledaču. Nisu povezane sa stvarnom bazom i ne prenose se automatski u produkciju.

Za lokalni HTTP pregled, iz direktorijuma projekta pokrenite:

```sh
python3 -m http.server 4173 --bind 127.0.0.1 --directory public
```

Otvorite `http://127.0.0.1:4173`. Za produkciju koristite HTTPS adresu Vercel projekta.

## Supabase: postavljanje baze i prvog administratora

1. Kreirajte namenski Supabase projekat za evidenciju. U SQL Editor-u pokrenite ceo `supabase/schema.sql`. Skripta koristi prefiks `bg_` i ne briše poslovne podatke prilikom ponovnog pokretanja iste verzije. Kasnija proširenja strukture zahtevaju novu migraciju.
2. U Authentication → Users kreirajte ili pozovite prvog korisnika, sa njegovim stvarnim e-mailom. Lozinku korisnik postavlja kroz dozvoljeni tok prijave/pozivnice; nema ugrađene lozinke.
3. U SQL Editor-u aktivirajte prvog administratora, zamenjujući adresu:

```sql
update public.bg_profiles
set active = true, role = 'admin'
where lower(email) = lower('vas.admin@firma.rs');

select email, display_name, role, active
from public.bg_profiles
where lower(email) = lower('vas.admin@firma.rs');
```

Proverite da je izmenjen tačan korisnik. Ako nema reda, nalog još nije kreiran u ovom projektu.

4. U Authentication podešavanjima isključite samostalno otvaranje javnih naloga. Ostale korisnike pozovite ili kreirajte kroz Authentication. Novi korisnik je neaktivan dok mu administrator u aplikaciji ne dodeli pristup.
5. Podesite produkcijski SMTP za slanje pozivnica i obnove lozinke. Podesite odgovarajuću politiku lozinki i ograničenja Auth zahteva u svom projektu.
6. U URL Configuration upišite stvarni Vercel/domen URL kao Site URL i dozvoljeni Redirect URL, uključujući putanju aplikacije. Za razvoj lokalni URL dodajte odvojeno. Za produkciju koristite tačne adrese svojih domena.
7. Iz podešavanja projekta preuzmite Project URL i publishable ključ. Legacy `anon` ključ je takođe podržan. `service_role` i `sb_secret_` ključevi se ne stavljaju u HTML, Vercel javne parametre niti korisnički unos.

Skripta uključuje RLS za sve tabele aplikacije. Neprijavljeni korisnici nemaju pristup poslovnim tabelama. Uloge su:

| Uloga | Prava |
|---|---|
| Pregled | Čitanje evidencije, izveštaji, štampa, CSV izvoz i preuzimanje dostupnih priloga |
| Urednik | Sve prethodno, plus unos i izmena poslovnih podataka i upload priloga |
| Administrator | Sve prethodno, plus brisanje, upravljanje listama, odobravanje korisnika, istorija izmena i kompletan JSON izvoz |

Jedna organizacija predstavlja Balkan grupu. Vlasnici unutar nje mogu biti različite firme ili fizička lica. Korisnički pristup u ovoj verziji odnosi se na celu evidenciju grupe; nema odvojenih prava po pojedinačnoj firmi.

Promene korisničkih prava proveravaju se u bazi. Poslednji aktivni administrator ne može da bude deaktiviran ili degradiran kroz aplikaciju. Osvežavanje prikaza proverava aktuelni profil; automatsko osvežavanje je na 90 sekundi kada nema otvorenog obrasca. Baza odmah primenjuje promenu prava i na neposredne API zahteve.

## Vercel: objavljivanje

1. Postavite sadržaj ovog direktorijuma u svoj Git repozitorijum i uvezite ga u Vercel. Ako je projekat u poddirektorijumu repozitorijuma, izaberite taj direktorijum kao Root Directory.
2. Framework Preset: **Other**. Node.js: **22 ili noviji**. Build Command: `node build.mjs`. Output Directory: `public`.
3. U Vercel Environment Variables unesite `SUPABASE_URL` i `SUPABASE_PUBLISHABLE_KEY`. Unosite javni publishable ključ. Označite okruženja na koja se podešavanja odnose.
4. Pokrenite deployment. Build ugrađuje javne parametre u HTML i računa CSP hash programskog koda. Nemojte ručno menjati generisani HTML bez ponovnog build-a.
5. Stvarnu objavljenu adresu dodajte u Supabase Auth URL Configuration i ponovite deployment posle promene Vercel promenljivih.
6. Prijavite se kao administrator i izvršite proveru rada navedenu ispod.

Za lokalni build sa lokalnim parametrima možete koristiti Node 22+:

```sh
node --env-file=.env build.mjs
node --test tests/*.test.mjs
```

`.env` pravite prema `.env.example`. Vercel svoje promenljive prosleđuje direktno; tamo nije potreban `.env` fajl. Projekat nema npm zavisnosti za build. Sve izmene u `src/` zahtevaju ponovno izvršavanje `node build.mjs`.

Za Vercel koristite ceo ovaj paket: izvorni kod ostaje u repozitorijumu, dok se javno isporučuje samo sadržaj direktorijuma `public`, sa jednim HTML fajlom aplikacije. Ako se parametri unose kroz ekran povezivanja, javna konfiguracija ostaje u lokalnom pregledaču, pa je za rad više korisnika praktičniji build sa Vercel promenljivima.

## Rad sa evidencijom

**Vlasnici.** Unesite naziv, pravno/fizičko lice, državu, PIB/poreski i matični broj po potrebi, kontakt i napomenu. Oznaka „U obuhvatu Balkan grupe“ određuje čiji se udeli prikazuju u vrednosti grupe. Spoljne suvlasnike takođe evidentirajte, sa isključenom oznakom.

**Nepokretnosti.** Jedan red je jedna pravna/celovita jedinica evidencije, sa trajnim internim UUID-om i čitljivim poslovnim ID-om. Obrazac obuhvata osnovne podatke, lokaciju/kompleks, katastarsku opštinu, parcelu i podbroj, objekat, poseban deo, LN/izvod, odvojene površine zemljišta/neto/bruto, dozvole, upis, postupke, terete, sticanje, vrednosti, zakup i slobodnu napomenu. Vodeći vlasnik služi za pregled; svi stvarni udeli unose se kroz Suvlasništvo.

Za različite pravne jedinice unesite odvojene nepokretnosti i zajedničku oznaku kompleksa. Ne unosite istu tržišnu vrednost ponovo kao zaseban zbir celog kompleksa. Ako jedinica obuhvata više parcela, polja KO/parcela su tekstualna; navedite jasnu oznaku svake parcele i odgovarajuće KO, a pojedinačno praćenje više pravnih jedinica vodite odvojeno.

**Suvlasništvo.** Jedan zapis po paru vlasnik–nepokretnost. Unesite brojilac i imenilac kao cele brojeve. Ukupan evidentirani udeo treba da bude 100%. Parcijalni i prekomerni zbir se označavaju kao nepotpuni; vrednost udela grupe se tada ne uključuje u zbir. Promena naziva vlasnika ne prekida veze jer se one oslanjaju na interni ID.

**Pet koraka.** Svaka nepokretnost ima najviše pet tekućih koraka sa opisom, odgovornim licem, rokom, statusom i napomenom. Prvi nezavršen korak redom 1–5 predstavlja naredni korak. Kašnjenja obuhvataju sve otvorene korake. Završene korake možete zameniti narednim aktivnostima; administrator ima istoriju prethodnih izmena.

**CEOP i katastar.** Za jednu nepokretnost možete uneti više predmeta: sistem, broj predmeta, vrstu, normalizovanu fazu, tačan status iz izvora, nadležni organ/SKN, datume podnošenja i provere, rok, odgovorno lice, URL, ishod/rešenje i slobodnu napomenu. Statusi se ažuriraju ručno. Nije implementovano automatsko preuzimanje sa zvaničnih portala niti zaobilaženje njihovog pristupa. Datum poslednje provere pokazuje starost unetog statusa.

**Dokumentacija.** Jedan zapis po dokumentu, sa ID-om, vrstom, brojem, statusom, izdavanjem, rokom i napomenom. Možete dodati spoljni HTTPS link ili privatni prilog do 20 MB: PDF, JPG/JPEG, PNG, WEBP, DOCX, XLSX i TXT. Preuzimanje koristi kratkotrajni potpisani URL. Sačuvana dokumenta ne menjaju automatski status dozvole na nepokretnosti; status ažurirajte nakon provere isprave.

**Komunalije.** Jedan zapis po usluzi/brojilu. ED i korisnički brojevi, brojila, ugovori, nosilac ugovora, priključna snaga u kW, valute i troškovi čuvaju se odvojeno. Trošak komunalija se ne dodaje automatski mesečnom održavanju.

## Filteri, obračuni i izveštaji

- Pretraga obuhvata naziv, poslovni ID, grad, adresu, KO, parcelu, sve vlasnike, napomene i brojeve/status predmeta.
- Filter vlasnika uključuje sve suvlasnike, bez ponavljanja iste nepokretnosti.
- EUR i RSD se prikazuju odvojeno. Kursna konverzija nije uključena.
- Svi osnovni uneti finansijski iznosi odnose se na 100% nepokretnosti. Pripadajuća vrednost vlasnika/grupe računa se iz udela, uz potpuno evidentirano vlasništvo. Stvarna naplata zakupa i računovodstvena knjiženja nisu predmet ove evidencije.
- Izveštaj „Bez upotrebne dozvole“ uključuje izričit status „Nema“. Nepoznati status je zaseban filter.
- „U postupku“ uključuje označeni postupak/ozakonjenje, dozvole u postupku ili otvoren CEOP/katastarski predmet. To je operativni pregled prema unetim podacima.
- Izveštaji: jedinstveni pregled, po firmi/vlasniku, u postupku, bez upotrebne dozvole, otvoreni predmeti, koraci/rokovi i dokumentacija.
- Kartica nepokretnosti štampa osnovne i katastarske podatke, dozvole, finansije, sve vlasnike, pet koraka, predmete, dokumentaciju, komunalije i slobodnu napomenu.
- Dugmad za štampu prvo otvaraju pregled sadržaja. U njemu „Štampa / PDF“ poziva dijalog pregledača: izaberite štampač ili „Save as PDF“. „Preuzmi dokument za štampu“ čuva zaseban HTML sa izabranim sadržajem, bez prijave, skripti i veze sa bazom; otvorite ga i odštampajte kroz pregledač. Dokument sadrži podatke iz izveštaja i prosleđuje se samo ovlašćenim licima. Pregledi su A4 horizontalno, pojedinačna kartica A4 uspravno. Isključite dodatne zaglavlja/podnožja pregledača ako nisu potrebna.
- CSV izvoz je UTF-8 sa BOM-om i separatorom `;`, prilagođen otvaranju u Excel-u. Tekstovi koji bi mogli da budu protumačeni kao formule štite se apostrofom.

## Administracija i održavanje

Nazivi lista mogu da se menjaju, dok trajne šifre ostaju iste. Stavke se deaktiviraju umesto brisanja, da bi stare evidencije zadržale značenje. Za statuse portfelja administrator određuje uključivanje u vrednost portfelja, a za statuse koraka/predmeta da li ih zatvaraju. Za postupke određuje da li se vode kao „u toku“.

Brisanje je dostupno samo administratoru i zahteva potvrdu. Povezane nepokretnosti/vlasnici imaju referencijalnu zaštitu: najpre uklonite veze ili koristite arhiviranje/deaktiviranje. Arhivirane nepokretnosti ostaju u evidenciji, a podrazumevani zbir portfelja ih isključuje.

Izmene se beleže serverski sa korisnikom i prethodnim/novim podacima. Istorija u aplikaciji prikazuje poslednjih 200 događaja; stariji ostaju u bazi. Paralelna izmena istog zapisa proverava verziju i sprečava tiho prepisivanje. Ako je verzija promenjena, sačuvajte svoj tekst i osvežite prikaz.

Preuzimanje JSON-a predstavlja izvoz poslovnih podataka i metapodataka, bez sadržaja Storage datoteka i bez Auth naloga/lozinki. Automatski povrat JSON-a kroz interfejs nije uključen. Za potpun oporavak planirajte PostgreSQL backup u Supabase-u i odvojeno čuvanje Storage datoteka; dostupnost i zadržavanje zavise od vašeg izabranog paketa. Prava pristupa vraćajte kontrolisano.

Aplikacija učitava tabele u stranicama po 1.000 stavki. Interfejs prikazuje po 25 redova. Granica je 50.000 stavki po pojedinačnoj tabeli; iznad nje prikaz se prekida sa jasnom porukom, bez tihog izostavljanja. Za veći obim treba uvesti serverske upite/agregacije. Ova granica je nezavisna od početnih 300 redova Excel šablona.

## Obavezna provera konkretne instalacije

Pre operativnog unosa proverite:

1. Anoniman i neaktivan nalog ne čitaju podatke; uloga Pregled čita i štampa, ali ne menja; Urednik čuva izmene; samo Administrator briše i upravlja pravima.
2. Novi korisnik ima ispravan tok pozivnice i obnove lozinke na stvarnom domenu.
3. Unos jedne nepokretnosti, dva suvlasnika sa 1/2 + 1/2, jednog koraka i jednog CEOP/katastarskog predmeta radi nakon osvežavanja i ponovne prijave.
4. Paralelna izmena iz dva pregledača javlja sukob verzija.
5. Privatni prilog se otprema i preuzima samo odobrenim korisnikom. Testirajte i neuspeh veze pri upload-u.
6. Izveštaji i kartica imaju odgovarajuće podatke i izgled u štampi/PDF-u.
7. Pokrenite `tests/rls.sql`, pa `tests/rls_extended.sql` u zasebnom Supabase test projektu nakon šeme. Skripte vraćaju test promene kroz ROLLBACK. Ne pokrećite ih u produkciji.

Automatski lokalni testovi proveravaju obračune, filtere, nedostajuće i nulte vrednosti, bezbednost CSV/HTML izlaza, odbijanje privilegovanog ključa, usklađenost obrazaca sa kolonama, CSP, čuvanje obrazaca, konflikte verzija i kompenzaciju neuspelog priloga. Ne zamenjuju probu na vašem stvarnom Auth/PostgreSQL/Storage okruženju. SQL migracija je izvršena dvaput i obe SQL grupe testova prolaze u izolovanom PostgreSQL 18.6 engine-u (PGlite 0.5.16), uz lokalne zamene sistemskih Auth/Storage tabela. To proverava SQL, trigere i pravila pristupa, a ne stvarne Supabase Auth/Storage servise. Stvarna Vercel/Supabase instalacija nije izvršena bez pristupa vašim projektima. Detalji su u `PROVERE.md`.

## Zvanična dokumentacija korišćena pri izradi

Provereno 16.11.2026:

- https://supabase.com/docs/reference/javascript/initializing
- https://supabase.com/docs/guides/database/postgres/row-level-security
- https://supabase.com/docs/guides/storage/security/access-control
- https://supabase.com/docs/reference/javascript/auth-resetpasswordforemail
- https://supabase.com/docs/reference/javascript/storage-from-createsignedurl
- https://vercel.com/docs/project-configuration/vercel-json
- https://www.apr.gov.rs/usluge/eservisi/egradjevinske-dozvole.2407.html
- https://www.rgz.gov.rs/info-centar-rgz

## Izmene u verziji 1.1.0

- Dodat pregled pre štampe kartice i izveštaja, sa preuzimanjem zasebnog HTML dokumenta za štampu.
- Ispravljena provera putanje privatnog priloga u Storage pravilima. Unutrašnji SQL upit sada izričito koristi ime Storage objekta, čime odobreni korisnik može da otpremi i preuzme prilog svoje nepokretnosti. Prilozi drugih organizacija ostaju nedostupni.
- Dodate provere izolacije organizacija, privatnih priloga, zabrane samostalnog podizanja prava i zaštite poslednjeg administratora.
- Provereni čuvanje KO/parcele/napomene, unos predmeta i preuzimanje kartice kroz stvarni pregledač u demonstraciji.

Ako ste već instalirali 1.0.0, ponovo pokrenite ceo `supabase/schema.sql` iz ovog izdanja da se ažuriraju funkcije i pravila, zatim postavite novu aplikaciju. Ista šema ne briše postojeće poslovne podatke i ne menja već izmenjene nazive lista. Prethodno isprobajte ažuriranje u test projektu.
