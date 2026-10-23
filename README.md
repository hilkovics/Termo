# Skládka Senec · CH₄, CO a teplota LFG

Interaktívna mapa skládky Senec, ktorá spája:

- **CH₄ z dronu** (laserový detektor, ppm·m) z dvoch záznamov 19. 8. 2026 (18:19:26 a 19:41:33). Tvar značky ukazuje záznam, farba hodnotu.
- **Odplyňovacie šachty OŠ 1–15, OŠ 10A a ventily OT1–OT5** s polohou z PDF STELLA a meraním zo 6. 6. 2025.
- **Teplotu LFG a CO** z merania Senec V/2026 v okruhu 30 m okolo 10 sond. Prekryv susedných okruhov je rozdelený v polovici vzdialenosti, každé miesto patrí najbližšej sonde.
- **Termo ortomozaiku** (zmenšená `termo-result.png`) s prelínaním alebo oponou voči podkladu.

## Otvorenie

Otvorte `index.html` v prehliadači. Súbor `termo-result.png` musí byť v rovnakom priečinku. Podkladové mapy (Esri, CARTO) a knižnica Leaflet sa načítavajú z internetu.

## Obsah

| Cesta | Čo obsahuje |
|---|---|
| `index.html` | hotová mapa s vloženými dátami |
| `termo-result.png` | termo ortomozaika zmenšená 8× (13 cm/px) z `result.tif` |
| `data/*_flight_record.csv` | záznamy z dronu (1 Hz) |
| `data/Tabuľka výsledkov meraní Senec V_2026.xlsx` | T LFG, CO a ďalšie hodnoty pre 10 sond |
| `data/Tabulka CO.xlsx` | staršia tabuľka CO (rovnaké hodnoty CO ako V/2026) |
| `data/Súradnice STELLA.pdf` | polohy šachiet a meranie 6. 6. 2025 |
| `scripts/` | zostavenie mapy a pomocné nástroje |

Pôvodný `result.tif` (317 MB, GeoTIFF WGS84) v repozitári nie je, presahuje limit GitHubu 100 MB na súbor.

## Zostavenie mapy

`scripts/template.html` je šablóna mapy. Polohy šachiet (PDF STELLA) a merania V/2026 sú v nej zapísané priamo. `scripts/build.ps1` do nej vloží body CH₄ z CSV (Windows PowerShell 5.1):

```powershell
& .\scripts\build.ps1 -Csv ".\data\20260819 181926_flight_record.csv" -Extra ".\data\20260819 194133_flight_record.csv" -Template .\scripts\template.html -Out .\index.html
```

Termo PNG vznikla z `result.tif` cez `scripts/TifDown.cs` (dlaždicový RGBA TIFF s kompresiou deflate, zmenšenie 8×):

```powershell
Add-Type -Path .\scripts\TifDown.cs -ReferencedAssemblies System.Drawing
[TifDown]::Run("C:\cesta\result.tif", 8, "$PWD\termo-result.png")
```

Ďalšie skripty:

- `tiffinfo.ps1` vypíše hlavičku a georeferencovanie TIF.
- `xlsx.ps1` vypíše obsah XLSX bez Excelu.
- `HueStats.cs` vyhodnotí farby termo snímky.
- `serve.ps1` spustí jednoduchý lokálny server.

## Poznámky

- **Súradnice v PDF STELLA** sú stupne a minúty bez oddeľovačov: `4814785` = 48° 14,785′ = 48,24642° N, `1722969` = 17° 22,969′ = 17,38282° E.
- **Termo snímka** je zafarbený obrázok bez teplotnej stupnice. Poradie farieb (sivá → červená → žltá → zelená) je odhad.
- **CO 1 000 ppm** pri sondách 2 a 15 je pravdepodobne horná hranica meracieho prístroja.
- **Tabuľka č. 2 (1. 12. 2025)** v PDF STELLA obsahuje len hlavičku, riadky chýbajú.
