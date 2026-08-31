# Lumberjack John – Android mobile build

Mobilní práce probíhají pouze ve větvi `mobile`.

Větev `backup-before-mobile-2026-08-31` je nedotčená záloha funkční PC verze a nesmí se upravovat.

## Cílové zobrazení

- landscape
- základní návrhové rozlišení 1600×900 (16:9)
- Godot `canvas_items` + `expand`, takže širší telefony dostanou více prostoru místo ořezání UI
- na Androidu je povolen pouze landscape senzorový režim
- dotyková tlačítka mají mobilní minimální výšku přes `mobile_ui.gd`

## Android application ID

`com.welewan.lumberjackjohn`

Tento identifikátor po prvním vydání APK/AAB neměnit. Android podle něj poznává aktualizace stejné aplikace a zachovává `user://` data.

## APK přes GitHub Actions

Workflow: `.github/workflows/android-apk.yml`

Build používá Godot CI image s Android SDK a debug keystorem. Lokální Android SDK ani lokální Godot nejsou pro stažení hotového APK potřeba.

Workflow při buildu:

1. načte repozitář,
2. spustí Godot headless import/parsing projektu,
3. vytvoří debug Android APK,
4. uloží `LumberjackJohn.apk` do artifactu `LumberjackJohn-Android-APK`.

Po buildu otevři GitHub → Actions → Android APK → konkrétní run → Artifacts → `LumberjackJohn-Android-APK`. GitHub artifact stáhne jako ZIP; uvnitř je normální instalovatelný soubor `LumberjackJohn.apk`.

Dokud je workflow pouze ve vývojové větvi `mobile`, build se automaticky spouští po změnách v této větvi. `workflow_dispatch` je připravený pro ruční spuštění; GitHub ho standardně zpřístupní z UI po umístění workflow na výchozí větev.

## Save export / import

V záložce NASTAVENÍ je přidaný přenos save přes schránku:

- `EXPORT SAVE` uloží lokální zálohu a zkopíruje kompletní save balíček do schránky,
- text lze poslat do druhého zařízení,
- na druhém zařízení se text zkopíruje do schránky a použije `IMPORT SAVE`,
- import před zápisem validuje formát a vytvoří předimportní lokální zálohu,
- po importu je nutné hru úplně zavřít a znovu spustit.

Balíček zahrnuje hlavní save, inventář obchodu, zakázky, dopravu a offline timestamp, pokud příslušné save soubory existují.
