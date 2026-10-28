# Skládka Senec · CH₄, CO a teplota LFG

Interaktívna mapa skládky Senec, ktorá spája:

- **CH₄ z dronu** (laserový detektor, ppm·m) z troch záznamov 19. 8. 2026 (18:19:26, 19:01:05 a 19:41:33). Tvar značky ukazuje záznam, farba hodnotu.
- **Prieniky medzi letmi**: miesta, kde CH₄ nad prahom zachytilo viac letov do zvolenej vzdialenosti od seba (zóny na mape, zoznam, matica dvojíc letov, export CSV).
- **Odplyňovacie šachty OŠ 1–15, OŠ 10A a ventily OT1–OT5** s polohou z PDF STELLA a meraním zo 6. 6. 2025.
- **Teplotu LFG a CO** z merania Senec V/2026 v okruhu 30 m okolo 10 sond. Prekryv susedných okruhov je rozdelený v polovici vzdialenosti, každé miesto patrí najbližšej sonde.
- **Termo ortomozaiku** (zmenšená `termo-result.png`) s prelínaním alebo oponou voči podkladu.
- **Približnú teplotu z termo snímky**: kliknutím kamkoľvek do mapy a pri šachtách ako priemer, maximum a podiel najteplejšej (farebnej) plochy v kruhu 30 m.

## Otvorenie

Otvorte `index.html` v prehliadači. Súbor `termo-result.png` musí byť v rovnakom priečinku. Podkladové mapy (Esri, CARTO) a knižnica Leaflet sa načítavajú z internetu.

## Obsah

| Cesta | Čo obsahuje |
|---|---|
| `index.html` | hotová mapa s vloženými dátami |
| `termo-result.png` | termo ortomozaika zmenšená 8× (13 cm/px) z `result.tif` |
| `data/*_flight_record.csv`, `data/*_flight_record.xlsx` | záznamy z dronu (1 Hz), CSV alebo XLSX s rovnakými stĺpcami |
| `data/Tabuľka výsledkov meraní Senec V_2026.xlsx` | T LFG, CO a ďalšie hodnoty pre 10 sond |
| `data/Tabulka CO.xlsx` | staršia tabuľka CO (rovnaké hodnoty CO ako V/2026) |
| `data/Súradnice STELLA.pdf` | polohy šachiet a meranie 6. 6. 2025 |
| `data/termo-grid.bin` | poloha farby v palete Hot Iron po 40 cm, z `result.tif` (vložená do mapy) |
| `scripts/` | zostavenie mapy a pomocné nástroje |

Pôvodný `result.tif` (317 MB, GeoTIFF WGS84) v repozitári nie je, presahuje limit GitHubu 100 MB na súbor.

## Zostavenie mapy

`scripts/template.html` je šablóna mapy. Polohy šachiet (PDF STELLA) a merania V/2026 sú v nej zapísané priamo. `scripts/build.ps1` do nej vloží body CH₄ zo záznamov letov (CSV alebo XLSX) a teplotnú mriežku (Windows PowerShell 5.1). Prvý záznam je hlavný, ďalšie sa pridávajú cez `-Extra` v poradí, v akom sa majú zobraziť:

```powershell
& .\scripts\build.ps1 -Csv ".\data\20260819 181926_flight_record.csv" -Extra ".\data\20260819 190105_flight_record.xlsx", ".\data\20260819 194133_flight_record.csv" -TempGrid .\data\termo-grid.bin -Template .\scripts\template.html -Out .\index.html
```

Teplotná mriežka vznikla z `result.tif` cez `scripts/TempCode.cs`. Každý pixel dostane polohu v palete: šedá časť podľa jasu, farebná podľa odtieňa. Hodnoty sa spriemerujú po blokoch 24 × 24 px (40 cm):

```powershell
Add-Type -Path .\scripts\TempCode.cs
[TempCode]::Run("C:\cesta\result.tif", 24, "$PWD\data\termo-grid.bin")
```

Teplotu z polohy v palete dopočíta až mapa. Šedá časť zodpovedá 22 °C až hranici farby, farebná hranici farby až 35 °C. Hranicu farby (predvolene 30 °C) nastavíte v mape posuvníkom.

Termo PNG vznikla z `result.tif` cez `scripts/TifDown.cs` (dlaždicový RGBA TIFF s kompresiou deflate, zmenšenie 8×):

```powershell
Add-Type -Path .\scripts\TifDown.cs -ReferencedAssemblies System.Drawing
[TifDown]::Run("C:\cesta\result.tif", 8, "$PWD\termo-result.png")
```

Jeden súbor na zdieľanie vytvorí `scripts/standalone.ps1`. Do hotového `index.html` vloží termo snímku a knižnicu Leaflet a uloží `dist/Skladka-Senec.html` (asi 11 MB, v gite nie je). Súbor stačí otvoriť v prehliadači, bez servera a bez ďalších súborov. Podkladové mapy a písma sa načítavajú z internetu, bez pripojenia funguje mapa bez podkladu.

```powershell
& .\scripts\standalone.ps1
```

Ďalšie skripty:

- `tiffinfo.ps1` vypíše hlavičku a georeferencovanie TIF.
- `xlsx.ps1` vypíše obsah XLSX bez Excelu.
- `HueStats.cs` vyhodnotí farby termo snímky.
- `serve.ps1` spustí jednoduchý lokálny server.
- `standalone.ps1` vytvorí jeden súbor na zdieľanie (pozri vyššie).

## Prieniky medzi letmi

Panel **Prieniky medzi letmi** hľadá miesta, kde metán zachytilo viac letov:

1. Z každého letu sa vezmú body nad prahom. Prah je buď v ppm·m, rovnaký pre všetky lety, alebo „najvyššie % letu“. Druhá možnosť vezme z každého letu rovnaký podiel jeho najsilnejších bodov a vyrovná tak rozdiely v citlivosti a výške letu. Záznam 19:01:05 má nastavenú citlivosť High a vyššie hodnoty pozadia.
2. Bod je v prieniku, ak má do zvolenej vzdialenosti (1 – 20 m) bod aspoň jedného ďalšieho letu. Pri voľbe „Všetky vybrané“ musí mať nablízku body všetkých vybraných letov.
3. Body prieniku, ktoré sú od seba do zvolenej vzdialenosti, sa spoja do jednej zóny. Zóny sú zoradené podľa počtu letov a potom podľa najnižšieho z maxím jednotlivých letov, teda hodnoty, ktorú prekročil každý let.

Matica dvojíc ukazuje, koľko % bodov jedného letu má nablízku bod iného letu. Kliknutím na bunku sa porovná len táto dvojica. Tlačidlo **Stiahnuť zóny (CSV)** uloží zóny s aktuálnym nastavením (oddeľovač `;`, desatinná čiarka).

## Poznámky

- **Súradnice v PDF STELLA** sú stupne a minúty bez oddeľovačov: `4814785` = 48° 14,785′ = 48,24642° N, `1722969` = 17° 22,969′ = 17,38282° E.
- **Termo snímka** je zafarbený obrázok (paleta Hot Iron) s rozsahom teplôt 22 – 35 °C. Chladnejšie miesta sú šedé, najteplejšie zafarbené od červenej po žltú. Stupnica v snímke nie je a nie je známe, pri akej teplote začína farba. Teploty medzi krajmi sú preto len približné, rozhodujúce je porovnanie miest medzi sebou.
- **CO 1 000 ppm** pri sondách 2 a 15 je pravdepodobne horná hranica meracieho prístroja.
- **Tabuľka č. 2 (1. 12. 2025)** v PDF STELLA obsahuje len hlavičku, riadky chýbajú.
