# Provere izdanja 1.1.0

Datum: 16.11.2026.

## Automatske provere aplikacije

**26/26 testova prolazi.** Pokriveno je: suvlasništvo i vrednost udela grupe; odvojene valute EUR/RSD; prazni i nulti iznosi; pretraga po KO, parceli, napomeni i predmetu; filtriranje manjinskog suvlasnika bez dupliranja; otvoreni i zakašnjeli koraci; stabilnost statusa nakon promene naziva; validacija i bezbedan CSV/HTML izlaz; odbijanje privilegovanog ključa; poklapanje obrazaca i kolona baze; CSP hash; čuvanje kompletne forme; kartica i svi izveštaji; preview i samostalni dokument za štampu, uspravna/horizontalna orijentacija i očuvanje filtera; odbijanje izmene za Pregled; sukob verzija; učitavanje preko 1.000 redova; čišćenje neuspelog priloga i očuvanje potvrđenog novog priloga kada čišćenje starog ne uspe.

```sh
node build.mjs
node --test tests/*.test.mjs
```

## PostgreSQL provere

U stvarnom PostgreSQL engine-u za browser, PostgreSQL 18.6 / PGlite 0.5.16, prolaze:

- Celokupna `supabase/schema.sql` migracija, uključujući ponovljeno izvršavanje.
- `tests/rls.sql`: neprijavljen/neaktivan korisnik, podela uloga, izmene, verzije, istorija i prava upravljanja.
- `tests/rls_extended.sql`: izolacija dve organizacije, zabrana povezivanja tuđeg vlasnika, ograničenje pet koraka, privatno čitanje i otpremanje priloga, zabrana podizanja sopstvenih prava i zaštita poslednjeg aktivnog administratora.

Za ponavljanje otvorite `tests/browser_database.html` preko lokalnog HTTP servera čiji je koren direktorijum ovog projekta. Provera učitava precizno označenu razvojnu zavisnost sa CDN-a i radi u memoriji pregledača. Ova stranica se ne nalazi u produkcijskom direktorijumu `public`.

Auth i Storage sistemske tabele/funkcije su u ovoj probi lokalne zamene Supabase okruženja. Time su provereni PostgreSQL sintaksa, funkcije, trigeri i RLS, a ne stvarni GoTrue servis, slanje mejlova, API gateway ili Storage API.

## Provere u pregledaču

Potvrđeni su početni ekran, demo pregled i navigacija; uspešno čuvanje katastarske opštine, broja parcele i slobodne napomene; unos katastarskog predmeta sa brojem, fazom i tačnim statusom iz izvora; izveštaj bez upotrebne dozvole; pregled kartice pre štampe i stvarno preuzimanje zasebnog HTML dokumenta sa ispravnim sadržajem i A4 uspravnom orijentacijom. Preuzeti dokument je ponovo otvoren i vizuelno proveren. Podaci korišćeni za sve ove provere su izmišljeni DEMO podaci.

Dijalog operativnog sistema za štampu/PDF nije potvrđen u automatizovanom cloud pregledaču. Potrebno je proveriti završni PDF i štampač na računaru korisnika.

## Preostaje provera ciljne instalacije

Nisu izvršeni Vercel deployment, prava Supabase prijava/pozivnica/oporavak lozinke ni stvarni Storage upload i preuzimanje. Za njih je potreban konfigurisan ciljni projekat. Pre operativne upotrebe sprovesti konkretne korake iz `UPUTSTVO.md`.
