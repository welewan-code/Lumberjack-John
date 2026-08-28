# Dřevo Tycoon – ekonomika, náklady a výroba

Tento soubor je pracovní referenční zdroj pro další chaty a balancování hry.

## Základní ceny a převody

| Položka | Hodnota |
|---|---:|
| Špalky – nákup | 1 100 Kč / m³ |
| Měkká kulatina – nákup | 1 200 Kč / m³ |
| Štípané dřevo – přímý prodej | 1 100 Kč / m³ |
| Špalky → štípané | 1,0 m³ → 1,5 m³ |
| Kulatina → špalky | 1,0 m³ → 1,333 m³ |
| Kulatina → štípané | 1,0 m³ → 2,0 m³ |
| Kapacita skladu | 10 m³ celkem |

## Vzorce

- Tržba = vyrobené m³ × prodejní cena za m³
- Materiálový náklad = spotřebované m³ × nákupní cena za m³
- Mzda = počet cyklů × mzda za cyklus
- Zisk = tržba − materiál − mzdy
- Čistý zisk po nástroji = zisk − pořizovací cena nástroje
- Zisk/min = zisk na cyklus × 60 / délka cyklu v sekundách
- Návratnost nástroje = cena nástroje / zisk vytvořený za minutu

## Štípání

Jeden sek: 0,010 m³ špalků → 0,015 m³ štípaného.

- Hodnota výstupu: 16,50 Kč
- Cena vstupu: 11 Kč
- Vlastní práce: +5,50 Kč/sek
- Brigádník: mzda 2 Kč/sek → +3,50 Kč/sek

| Varianta | Cyklus | Zisk/min | Zisk z 1 m³ špalků |
|---|---:|---:|---:|
| Hráč + tupá sekera | 1,8 s | 183,33 Kč | 550 Kč |
| Hráč + nabroušená | 1,6 s | 206,25 Kč | 550 Kč |
| Brigádník + tupá | 1,8 s | 116,67 Kč | 350 Kč |
| Brigádník + nabroušená | 1,6 s | 131,25 Kč | 350 Kč |

## Řezání kulatiny

Jeden cyklus: 0,025 m³ kulatiny → 0,0333 m³ špalků.

- Cena vstupu/cyklus: 30 Kč
- Mzda pilaře: 3 Kč/cyklus
- Hodnota vzniklých špalků proti přímému nákupu: 36,67 Kč
- Přidaná hodnota: 3,67 Kč/cyklus

| Pila | Cena | Cyklus | Přidaná hodnota/min | 1 m³ kulatiny |
|---|---:|---:|---:|---:|
| Rezavá rámovka | 80 Kč | 20 s | 11 Kč/min | 13 min 20 s |
| Aku pila z eshopu | 800 Kč | 5 s | 44 Kč/min | 3 min 20 s |

Aku pila nezvyšuje marži na kubík, ale je 4× rychlejší a výrazně zvyšuje průtok výroby.

## Celý výrobní řetězec

| Řetězec | Tržba | Materiál | Mzdy | Zisk před nástroji |
|---|---:|---:|---:|---:|
| 1 m³ špalků → štípat sám | 1 650 Kč | 1 100 Kč | 0 Kč | 550 Kč |
| 1 m³ špalků → brigádník | 1 650 Kč | 1 100 Kč | 200 Kč | 350 Kč |
| 1 m³ kulatiny → pilař → štípat sám | 2 200 Kč | 1 200 Kč | 120 Kč | 880 Kč |
| 1 m³ kulatiny → pilař → brigádník | 2 200 Kč | 1 200 Kč | 120 + 267 Kč | cca 613 Kč |

## Ekonomický smysl nástrojů

| Nástroj | Cena | Rychlost | Smysl |
|---|---:|---:|---|
| Tupá dřevěná sekera | 100 Kč | 1,8 s/sek | Odemkne vlastní štípání |
| Nabroušená sekera | 150 Kč | 1,6 s/sek | Stejná marže/m³, +12,5 % rychlejší |
| Rezavá rámovka | 80 Kč | 20 s/řez | Levný start, velký časový bottleneck |
| Aku pila z eshopu | 800 Kč | 5 s/řez | 4× rychlejší než rámovka |
| Děravé kolečko | 120 Kč | — | Odemkne sousedské zakázky/dopravu |

Orientační návratnost:
- tupá sekera: ~0,5 min vlastní výroby
- příplatek nabroušená vs tupá: ~2,2 min
- rámovka: ~7,3 min řezání
- příplatek aku pila vs rámovka: ~21,8 min proti rámovce

## Bottlenecky – 1 m³ měkké kulatiny

| Konfigurace | Řezání | Štípání | Sekvenčně celkem | Bottleneck |
|---|---:|---:|---:|---|
| Rámovka + tupá | 13,33 min | 4,00 min | 17,33 min | rámovka |
| Rámovka + nabroušená | 13,33 min | 3,56 min | 16,89 min | rámovka |
| Aku pila + tupá | 3,33 min | 4,00 min | 7,33 min | štípač |
| Aku pila + nabroušená | 3,33 min | 3,56 min | 6,89 min | téměř vyrovnané |

> Poznámka: jde o herní ekonomiku, ne fyzikální převod skutečného dřeva. Při změně ceny je potřeba přepočítat zisk/cyklus, zisk/min a návratnost nástrojů.
