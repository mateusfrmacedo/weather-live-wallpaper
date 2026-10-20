# Estrela cadente — referência do Tempo

Inspeção local do app Tempo e da cena WeatherV136 do WeatherUI no macOS 27.0.1. A cena original define:

- Intervalo variável: 11–15 segundos por emissão.
- Duração: 0,48–0,52 segundo.
- Velocidade: 220–280 unidades de cena por segundo.
- Tamanho inicial: 20–28 × 0,4–0,72 unidades de cena.
- Opacidade ao longo da vida: 0,971978 → 0,6777403 → 0, nos tempos normalizados 0 / 0,63438773 / 1.
- Comprimento: 0,13634618 → 0,29414064 → 0,94886214 → 0,6532588 nos tempos 0 / 0,20899282 / 0,36603463 / 1.
- Espessura: 0 → 0,8524266 → 0,7545708 → 0,631836 nos tempos 0 / 0,4175663 / 0,7314295 / 1.

`Sources/MeteorAnimation.h` aplica essas faixas e curvas nos dois modos. O compositor anima o rastro independentemente da taxa do vídeo, mantendo o brilho discreto aprovado. O ciclo reúne 16 emissões com intervalos e alturas variáveis, em vez de repetir um único movimento a cada 13 segundos.

A posição e a velocidade são projetadas para a tela do wallpaper; a inclinação é uma adaptação de composição. A opacidade é interpolada linearmente e as dimensões usam o interpolador cúbico do Core Animation. Isso aproxima o comportamento do Tempo usando seus parâmetros autorados, sem afirmar equivalência exata entre o interpolador VFX e o Core Animation.
