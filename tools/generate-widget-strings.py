#!/usr/bin/env python3
"""Generates the widget extension's Localizable.strings from the app's catalogs.

The widget's *content* uses the app's own `L10n` layer, so it follows the
language picked inside the app. But the configuration screen and the widget
gallery are drawn by the system before our code runs, and those strings have to
come from `Localizable.strings` in the extension bundle — iOS resolves them
against the *device* language.

This script writes one `.lproj` per language so both behave sensibly:

    python3 tools/generate-widget-strings.py

Re-run it after changing any `widget.*` key in Resources/L10n.
"""

import json
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
CATALOGS = ROOT / "Resources" / "L10n"
OUTPUT = ROOT / "Resources" / "WidgetStrings"

# Widget-only labels, which have no counterpart in the app's own UI.
EXTRA = {
    "en": {
        "widget.intent.title": "Statistics",
        "widget.intent.description": "Pick a period, what to count and which numbers to show.",
        "widget.type.period": "Period",
        "widget.type.data": "Data",
        "widget.type.compare": "Compare with",
        "widget.type.metric": "Metric",
        "widget.parameter.period": "Period",
        "widget.parameter.ago": "Ago",
        "widget.parameter.ago.description": "How many periods back. 0 is the current one.",
        "widget.parameter.showPrevious": "Show previous period",
        "widget.parameter.from": "From",
        "widget.parameter.to": "To",
        "widget.parameter.data": "Data",
        "widget.parameter.compare": "Compare with",
        "widget.parameter.mainMetric": "Main metric",
        "widget.parameter.alsoShow": "Also show",
    },
    "cs": {
        "widget.intent.title": "Statistiky",
        "widget.intent.description": "Zvolte období, co počítat a které hodnoty zobrazit.",
        "widget.type.period": "Období",
        "widget.type.data": "Data",
        "widget.type.compare": "Srovnat s",
        "widget.type.metric": "Metrika",
        "widget.parameter.period": "Období",
        "widget.parameter.ago": "Před",
        "widget.parameter.ago.description": "Kolik období zpět. 0 je to současné.",
        "widget.parameter.showPrevious": "Zobrazit předchozí období",
        "widget.parameter.from": "Od",
        "widget.parameter.to": "Do",
        "widget.parameter.data": "Data",
        "widget.parameter.compare": "Srovnat s",
        "widget.parameter.mainMetric": "Hlavní metrika",
        "widget.parameter.alsoShow": "Zobrazit také",
    },
    "de": {
        "widget.intent.title": "Statistiken",
        "widget.intent.description": "Wähle Zeitraum, Zählweise und die Zahlen, die erscheinen sollen.",
        "widget.type.period": "Zeitraum",
        "widget.type.data": "Daten",
        "widget.type.compare": "Vergleichen mit",
        "widget.type.metric": "Wert",
        "widget.parameter.period": "Zeitraum",
        "widget.parameter.ago": "Zurück",
        "widget.parameter.ago.description": "Wie viele Zeiträume zurück. 0 ist der aktuelle.",
        "widget.parameter.showPrevious": "Vorherigen Zeitraum zeigen",
        "widget.parameter.from": "Von",
        "widget.parameter.to": "Bis",
        "widget.parameter.data": "Daten",
        "widget.parameter.compare": "Vergleichen mit",
        "widget.parameter.mainMetric": "Hauptwert",
        "widget.parameter.alsoShow": "Außerdem zeigen",
    },
    "es": {
        "widget.intent.title": "Estadísticas",
        "widget.intent.description": "Elige el periodo, qué contar y qué cifras mostrar.",
        "widget.type.period": "Periodo",
        "widget.type.data": "Datos",
        "widget.type.compare": "Comparar con",
        "widget.type.metric": "Métrica",
        "widget.parameter.period": "Periodo",
        "widget.parameter.ago": "Hace",
        "widget.parameter.ago.description": "Cuántos periodos atrás. 0 es el actual.",
        "widget.parameter.showPrevious": "Mostrar periodo anterior",
        "widget.parameter.from": "Desde",
        "widget.parameter.to": "Hasta",
        "widget.parameter.data": "Datos",
        "widget.parameter.compare": "Comparar con",
        "widget.parameter.mainMetric": "Métrica principal",
        "widget.parameter.alsoShow": "Mostrar también",
    },
    "fr": {
        "widget.intent.title": "Statistiques",
        "widget.intent.description": "Choisissez la période, ce qu'il faut compter et les chiffres à afficher.",
        "widget.type.period": "Période",
        "widget.type.data": "Données",
        "widget.type.compare": "Comparer à",
        "widget.type.metric": "Mesure",
        "widget.parameter.period": "Période",
        "widget.parameter.ago": "Il y a",
        "widget.parameter.ago.description": "Nombre de périodes en arrière. 0 correspond à la période actuelle.",
        "widget.parameter.showPrevious": "Afficher la période précédente",
        "widget.parameter.from": "Du",
        "widget.parameter.to": "Au",
        "widget.parameter.data": "Données",
        "widget.parameter.compare": "Comparer à",
        "widget.parameter.mainMetric": "Mesure principale",
        "widget.parameter.alsoShow": "Afficher aussi",
    },
    "it": {
        "widget.intent.title": "Statistiche",
        "widget.intent.description": "Scegli il periodo, cosa contare e quali numeri mostrare.",
        "widget.type.period": "Periodo",
        "widget.type.data": "Dati",
        "widget.type.compare": "Confronta con",
        "widget.type.metric": "Metrica",
        "widget.parameter.period": "Periodo",
        "widget.parameter.ago": "Fa",
        "widget.parameter.ago.description": "Quanti periodi indietro. 0 è quello attuale.",
        "widget.parameter.showPrevious": "Mostra periodo precedente",
        "widget.parameter.from": "Da",
        "widget.parameter.to": "A",
        "widget.parameter.data": "Dati",
        "widget.parameter.compare": "Confronta con",
        "widget.parameter.mainMetric": "Metrica principale",
        "widget.parameter.alsoShow": "Mostra anche",
    },
    "pt": {
        "widget.intent.title": "Estatísticas",
        "widget.intent.description": "Escolha o período, o que contar e que números mostrar.",
        "widget.type.period": "Período",
        "widget.type.data": "Dados",
        "widget.type.compare": "Comparar com",
        "widget.type.metric": "Métrica",
        "widget.parameter.period": "Período",
        "widget.parameter.ago": "Há",
        "widget.parameter.ago.description": "Quantos períodos atrás. 0 é o atual.",
        "widget.parameter.showPrevious": "Mostrar período anterior",
        "widget.parameter.from": "De",
        "widget.parameter.to": "Até",
        "widget.parameter.data": "Dados",
        "widget.parameter.compare": "Comparar com",
        "widget.parameter.mainMetric": "Métrica principal",
        "widget.parameter.alsoShow": "Mostrar também",
    },
    "ja": {
        "widget.intent.title": "統計",
        "widget.intent.description": "期間、集計する内容、表示する数値を選びます。",
        "widget.type.period": "期間",
        "widget.type.data": "データ",
        "widget.type.compare": "比較対象",
        "widget.type.metric": "指標",
        "widget.parameter.period": "期間",
        "widget.parameter.ago": "過去",
        "widget.parameter.ago.description": "いくつ前の期間か。0が現在の期間です。",
        "widget.parameter.showPrevious": "前の期間も表示",
        "widget.parameter.from": "開始",
        "widget.parameter.to": "終了",
        "widget.parameter.data": "データ",
        "widget.parameter.compare": "比較対象",
        "widget.parameter.mainMetric": "メインの指標",
        "widget.parameter.alsoShow": "他に表示",
    },
    "ko": {
        "widget.intent.title": "통계",
        "widget.intent.description": "기간, 집계 기준, 표시할 수치를 선택하세요.",
        "widget.type.period": "기간",
        "widget.type.data": "데이터",
        "widget.type.compare": "비교 대상",
        "widget.type.metric": "지표",
        "widget.parameter.period": "기간",
        "widget.parameter.ago": "이전",
        "widget.parameter.ago.description": "몇 기간 전인지. 0은 현재 기간입니다.",
        "widget.parameter.showPrevious": "이전 기간 표시",
        "widget.parameter.from": "시작",
        "widget.parameter.to": "종료",
        "widget.parameter.data": "데이터",
        "widget.parameter.compare": "비교 대상",
        "widget.parameter.mainMetric": "주요 지표",
        "widget.parameter.alsoShow": "추가로 표시",
    },
    "zh-Hans": {
        "widget.intent.title": "统计",
        "widget.intent.description": "选择时间段、统计内容和要显示的数值。",
        "widget.type.period": "时间段",
        "widget.type.data": "数据",
        "widget.type.compare": "对比",
        "widget.type.metric": "指标",
        "widget.parameter.period": "时间段",
        "widget.parameter.ago": "往前",
        "widget.parameter.ago.description": "往前多少个时间段。0 表示当前。",
        "widget.parameter.showPrevious": "显示上一时间段",
        "widget.parameter.from": "从",
        "widget.parameter.to": "至",
        "widget.parameter.data": "数据",
        "widget.parameter.compare": "对比",
        "widget.parameter.mainMetric": "主要指标",
        "widget.parameter.alsoShow": "同时显示",
    },
}

# Catalog keys the configuration screen reuses, so the wording matches the app.
FROM_CATALOG = {
    "widget.period.day": "period.day",
    "widget.period.last24Hours": "period.last24Hours",
    "widget.period.week": "period.week",
    "widget.period.month": "period.month",
    "widget.period.quarter": "period.quarter",
    "widget.period.year": "period.year",
    "widget.period.custom": "period.custom",
    "widget.scope.all": "scope.all",
    "widget.scope.all.caption": "scope.all.caption",
    "widget.scope.activities": "scope.activities",
    "widget.scope.activities.caption": "scope.activities.caption",
    "widget.comparison.previous": "comparison.previous",
    "widget.comparison.lastYear": "comparison.lastYear",
    "widget.metric.steps": "metric.steps",
    "widget.metric.distance": "metric.distance",
    "widget.metric.elevation": "metric.elevation",
    "widget.metric.exercise": "metric.exercise",
    "widget.metric.activities": "metric.activities",
}


def strings_escape(value: str) -> str:
    return value.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n")


def main() -> int:
    missing = []
    for code in EXTRA:
        catalog_path = CATALOGS / f"{code}.json"
        if not catalog_path.exists():
            print(f"missing catalog: {catalog_path}")
            return 1
        catalog = json.loads(catalog_path.read_text())

        table = dict(EXTRA[code])
        for widget_key, catalog_key in FROM_CATALOG.items():
            if catalog_key not in catalog:
                missing.append((code, catalog_key))
                continue
            table[widget_key] = catalog[catalog_key]

        directory = OUTPUT / f"{code}.lproj"
        directory.mkdir(parents=True, exist_ok=True)
        lines = ["/* Generated by tools/generate-widget-strings.py — do not edit. */", ""]
        for key in sorted(table):
            lines.append(f'"{strings_escape(key)}" = "{strings_escape(table[key])}";')
        (directory / "Localizable.strings").write_text("\n".join(lines) + "\n")
        print(f"{code}: {len(table)} strings")

    if missing:
        for code, key in missing:
            print(f"missing catalog key {key} in {code}")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
