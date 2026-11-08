"""Whole-sentence translations for the Summary's one-line overview.

The app writes "A good {period} overall." with the period filled in, but
in German, Spanish and French the adjectives agree with the noun, so each
sentence is translated whole here and merged into assets/l10n/*.json:

  python3 tool/l10n_overview.py
"""
import json

NOUNS = ['day', 'week', 'month', 'few months', 'year']
EN = [
    "You're getting fitter: a very active {}.",
    'A steadily active {}. Keep building.',
    'A quiet {}. More movement will help you get fitter.',
    'A great, well-balanced {}.',
    'A good {} overall.',
    'A fair {}, with room to improve.',
    'A tough {}. Small steps will help.',
]

T = {
    'de': [
        ['Du wirst fitter: ein sehr aktiver Tag.', 'Du wirst fitter: eine sehr aktive Woche.', 'Du wirst fitter: ein sehr aktiver Monat.', 'Du wirst fitter: sehr aktive Monate.', 'Du wirst fitter: ein sehr aktives Jahr.'],
        ['Ein beständig aktiver Tag. Weiter so.', 'Eine beständig aktive Woche. Weiter so.', 'Ein beständig aktiver Monat. Weiter so.', 'Beständig aktive Monate. Weiter so.', 'Ein beständig aktives Jahr. Weiter so.'],
        ['Ein ruhiger Tag. Mehr Bewegung macht dich fitter.', 'Eine ruhige Woche. Mehr Bewegung macht dich fitter.', 'Ein ruhiger Monat. Mehr Bewegung macht dich fitter.', 'Ruhige Monate. Mehr Bewegung macht dich fitter.', 'Ein ruhiges Jahr. Mehr Bewegung macht dich fitter.'],
        ['Ein toller, ausgewogener Tag.', 'Eine tolle, ausgewogene Woche.', 'Ein toller, ausgewogener Monat.', 'Tolle, ausgewogene Monate.', 'Ein tolles, ausgewogenes Jahr.'],
        ['Insgesamt ein guter Tag.', 'Insgesamt eine gute Woche.', 'Insgesamt ein guter Monat.', 'Insgesamt gute Monate.', 'Insgesamt ein gutes Jahr.'],
        ['Ein ordentlicher Tag, mit Luft nach oben.', 'Eine ordentliche Woche, mit Luft nach oben.', 'Ein ordentlicher Monat, mit Luft nach oben.', 'Ordentliche Monate, mit Luft nach oben.', 'Ein ordentliches Jahr, mit Luft nach oben.'],
        ['Ein harter Tag. Kleine Schritte helfen.', 'Eine harte Woche. Kleine Schritte helfen.', 'Ein harter Monat. Kleine Schritte helfen.', 'Harte Monate. Kleine Schritte helfen.', 'Ein hartes Jahr. Kleine Schritte helfen.'],
    ],
    'es': [
        ['Estás mejorando tu forma: un día muy activo.', 'Estás mejorando tu forma: una semana muy activa.', 'Estás mejorando tu forma: un mes muy activo.', 'Estás mejorando tu forma: unos meses muy activos.', 'Estás mejorando tu forma: un año muy activo.'],
        ['Un día de actividad constante. Sigue así.', 'Una semana de actividad constante. Sigue así.', 'Un mes de actividad constante. Sigue así.', 'Unos meses de actividad constante. Sigue así.', 'Un año de actividad constante. Sigue así.'],
        ['Un día tranquilo. Moverte más te ayudará a ponerte en forma.', 'Una semana tranquila. Moverte más te ayudará a ponerte en forma.', 'Un mes tranquilo. Moverte más te ayudará a ponerte en forma.', 'Unos meses tranquilos. Moverte más te ayudará a ponerte en forma.', 'Un año tranquilo. Moverte más te ayudará a ponerte en forma.'],
        ['Un día excelente y equilibrado.', 'Una semana excelente y equilibrada.', 'Un mes excelente y equilibrado.', 'Unos meses excelentes y equilibrados.', 'Un año excelente y equilibrado.'],
        ['Un buen día en general.', 'Una buena semana en general.', 'Un buen mes en general.', 'Unos buenos meses en general.', 'Un buen año en general.'],
        ['Un día aceptable, con margen de mejora.', 'Una semana aceptable, con margen de mejora.', 'Un mes aceptable, con margen de mejora.', 'Unos meses aceptables, con margen de mejora.', 'Un año aceptable, con margen de mejora.'],
        ['Un día difícil. Los pequeños pasos ayudan.', 'Una semana difícil. Los pequeños pasos ayudan.', 'Un mes difícil. Los pequeños pasos ayudan.', 'Unos meses difíciles. Los pequeños pasos ayudan.', 'Un año difícil. Los pequeños pasos ayudan.'],
    ],
    'fr': [
        ['Vous êtes en meilleure forme : une journée très active.', 'Vous êtes en meilleure forme : une semaine très active.', 'Vous êtes en meilleure forme : un mois très actif.', 'Vous êtes en meilleure forme : quelques mois très actifs.', 'Vous êtes en meilleure forme : une année très active.'],
        ['Une journée active et régulière. Continuez.', 'Une semaine active et régulière. Continuez.', 'Un mois actif et régulier. Continuez.', 'Quelques mois actifs et réguliers. Continuez.', 'Une année active et régulière. Continuez.'],
        ['Une journée calme. Bouger davantage vous aidera à gagner en forme.', 'Une semaine calme. Bouger davantage vous aidera à gagner en forme.', 'Un mois calme. Bouger davantage vous aidera à gagner en forme.', 'Quelques mois calmes. Bouger davantage vous aidera à gagner en forme.', 'Une année calme. Bouger davantage vous aidera à gagner en forme.'],
        ['Une excellente journée, bien équilibrée.', 'Une excellente semaine, bien équilibrée.', 'Un excellent mois, bien équilibré.', 'D’excellents mois, bien équilibrés.', 'Une excellente année, bien équilibrée.'],
        ['Une bonne journée dans l’ensemble.', 'Une bonne semaine dans l’ensemble.', 'Un bon mois dans l’ensemble.', 'De bons mois dans l’ensemble.', 'Une bonne année dans l’ensemble.'],
        ['Une journée correcte, avec une marge de progrès.', 'Une semaine correcte, avec une marge de progrès.', 'Un mois correct, avec une marge de progrès.', 'Quelques mois corrects, avec une marge de progrès.', 'Une année correcte, avec une marge de progrès.'],
        ['Une journée difficile. Les petits pas aident.', 'Une semaine difficile. Les petits pas aident.', 'Un mois difficile. Les petits pas aident.', 'Quelques mois difficiles. Les petits pas aident.', 'Une année difficile. Les petits pas aident.'],
    ],
}
JA_NOUN = ['1日', '1週間', '1か月', 'ここ数か月', '1年']
JA = [
    '体力がついてきています。とてもアクティブな{}でした。',
    '安定してアクティブな{}でした。この調子で続けましょう。',
    '静かな{}でした。もっと体を動かすと体力アップにつながります。',
    'すばらしく、バランスのとれた{}でした。',
    '全体的に良い{}でした。',
    'まずまずの{}でした。まだ伸びしろがあります。',
    '大変な{}でした。小さな一歩が助けになります。',
]
ZH_NOUN = ['一天', '一周', '一个月', '这几个月', '一年']
ZH = [
    '你的体能在提升：非常活跃的{}。',
    '持续活跃的{}。继续保持。',
    '比较安静的{}。多活动有助于提升体能。',
    '出色而均衡的{}。',
    '总体来说是不错的{}。',
    '还算可以的{}，仍有提升空间。',
    '艰难的{}。一小步一小步来。',
]

# The greeting with the user's name.
GREETINGS = {
    'Good morning, {0}': {'de': 'Guten Morgen, {0}', 'es': 'Buenos días, {0}', 'fr': 'Bonjour, {0}', 'ja': 'おはようございます、{0}さん', 'zh': '早上好，{0}'},
    'Good afternoon, {0}': {'de': 'Guten Tag, {0}', 'es': 'Buenas tardes, {0}', 'fr': 'Bon après-midi, {0}', 'ja': 'こんにちは、{0}さん', 'zh': '下午好，{0}'},
    'Good evening, {0}': {'de': 'Guten Abend, {0}', 'es': 'Buenas noches, {0}', 'fr': 'Bonsoir, {0}', 'ja': 'こんばんは、{0}さん', 'zh': '晚上好，{0}'},
}


def main():
    for lang in ['de', 'es', 'fr', 'ja', 'zh']:
        path = f'assets/l10n/{lang}.json'
        table = json.load(open(path))
        for i, en in enumerate(EN):
            for j, noun in enumerate(NOUNS):
                if lang == 'ja':
                    out = JA[i].format(JA_NOUN[j])
                elif lang == 'zh':
                    out = ZH[i].format(ZH_NOUN[j])
                else:
                    out = T[lang][i][j]
                table[en.format(noun)] = out
        for en, by in GREETINGS.items():
            table[en] = by[lang]
        with open(path, 'w') as f:
            json.dump(table, f, ensure_ascii=False, indent=0, sort_keys=True)


main()
