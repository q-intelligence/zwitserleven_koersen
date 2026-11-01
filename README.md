# Zwitserleven koersen

Haalt elke werkdag automatisch de fondskoersen van
<https://www.zwitserleven.nl/en/about-zwitserleven/sustainability/funds/> op
en bewaart ze als CSV. Draait gratis op GitHub Actions; je eigen computer hoeft niet aan.

## Bestanden

| Bestand | Inhoud |
|---|---|
| `koersen.R` | Het script dat de koersen ophaalt |
| `.github/workflows/koersen.yml` | Planning voor GitHub Actions |
| `data/koersen.csv` | Volledige historie (1 rij per fonds per koersdatum) |
| `data/laatste.csv` | Alleen de meest recente koers per fonds |

## Kolommen in koersen.csv

`fonds`, `slug`, `datum` (YYYY-MM-DD), `koers` (euro), `opgehaald_op` (UTC)

## Let op

- De pagina toont alleen de laatste koers. De historie begint op de dag dat je dit voor het eerst draait.
- Controleer af en toe tabblad **Actions**. Als de paginastructuur verandert, mislukt de run en krijg je een melding.
- Gebruik voor eigen administratie en controleer de gebruiksvoorwaarden van Zwitserleven.
