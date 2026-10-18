# Weather Live Wallpaper

Wallpaper animado para macOS que acompanha o clima da cidade escolhida, usando o renderizador do app **Tempo** instalado no próprio Mac.

## Recursos

- Clima automático, com consulta a cada 10 minutos e atualização da iluminação a cada minuto.
- Céu, nuvens, chuva, neve, neblina e outros efeitos do WeatherUI/VFX.
- Lua com fase, rotação e posição calculadas pelo provedor astronômico do sistema.
- Sol reenquadrado para aparecer na composição do desktop durante o dia.
- Estrelas mais sutis, com redução gradual na parte inferior da tela.
- Qualidade Retina de até 60 fps ou modo econômico de 30 fps.
- Execução sem ícone no Dock, início com o Mac e opção para ocultar o ícone da barra de menus.
- Atalho global **⌘⇧P** para recuperar os controles.

## Requisitos

Esta versão foi desenvolvida e verificada em:

- Mac com Apple Silicon (ARM64).
- macOS 27.0.1, build 26A434, com WeatherUI 1454.0.1.
- Xcode 27.1 e Command Line Tools selecionadas.
- Aplicativo Tempo instalado no caminho padrão do sistema.

O projeto usa APIs privadas e uma ponte de ABI Swift específica do ambiente acima. Outras versões do macOS podem exigir adaptações. Não há suporte verificado para Intel.

## Baixar e instalar

**[Baixar a versão mais recente para macOS](https://github.com/mateusfrmacedo/weather-live-wallpaper/releases/latest)**

1. Baixe o arquivo `.dmg` na seção **Assets** da versão.
2. Abra o `.dmg` e arraste **Weather Wallpaper.app** para **Applications**.
3. Abra o app, escolha uma cidade e clique em **Usar como wallpaper**.

Também está disponível um `.zip`: descompacte e copie o aplicativo para a pasta Aplicativos. Não é necessário instalar Xcode para usar o download pronto.

O download é para **Apple Silicon e macOS 27**, verificado no macOS 27.0.1 (26A434). A compatibilidade com outras versões depende dos componentes privados do sistema.

O aplicativo tem assinatura **ad hoc**, sem notarização da Apple. Se o macOS bloquear a primeira abertura, tente abrir o app e depois acesse **Ajustes do Sistema → Privacidade e Segurança → Abrir Mesmo Assim**. Confirme apenas se o arquivo veio deste repositório. Os hashes para conferir a integridade estão em `SHA256SUMS.txt` na mesma versão.

## Compilar e instalar pelo código-fonte

```sh
git clone https://github.com/mateusfrmacedo/weather-live-wallpaper.git
cd weather-live-wallpaper
./Scripts/install.sh
open "$HOME/Applications/Weather Wallpaper.app"
```

A instalação compila e assina o app localmente com assinatura ad hoc, depois o copia para `~/Applications/Weather Wallpaper.app`.

Para compilar sem instalar:

```sh
./Scripts/build.sh
open "Build/Weather Wallpaper.app"
```

Não são necessários pacotes externos, chave WeatherKit ou instalação do REA para compilar o aplicativo.

Para gerar os pacotes de distribuição `.dmg`, `.zip` e os hashes SHA-256:

```sh
./Scripts/package.sh
```

Os arquivos são criados em `Build/Release/<versão>/`.

## Usar

1. Busque uma cidade e selecione o resultado.
2. Clique em **Usar como wallpaper**.
3. Abra **Preferências** para escolher qualidade, iniciar com o Mac ou ocultar o ícone da barra de menus.

Para recuperar os controles, use **⌘⇧P**, abra o aplicativo novamente pelo Finder ou use o menu de status. O menu também permite pausar a animação e sair. Ao sair, o fundo anterior volta a aparecer.

As cenas e os seletores de Dia/Entardecer/Noite servem como prévia manual. Selecionar uma cena desativa o modo automático; escolha **Clima automático** para retomá-lo.

A cidade e a última resposta meteorológica válida ficam salvas no Mac. O app consulta novamente ao despertar e tenta recuperar falhas após um minuto. O modo de pouca energia limita a animação a 30 fps.

## Dados e renderização

Os dados meteorológicos e a busca de cidades usam o [Open-Meteo](https://open-meteo.com/). Não é solicitada permissão de localização: o usuário escolhe a cidade. As condições podem divergir das exibidas pelo serviço Apple Weather.

A implementação carrega em tempo de execução a cena `WeatherV136_Default_Background.vfx`, as bibliotecas e as texturas do WeatherUI/VFX do sistema. O repositório não inclui esses recursos. O script de compilação gera localmente um ícone espelhado a partir do ícone do Tempo instalado; a barra de menus usa o símbolo monocromático `cloud.sun`.

As configurações de clima, altitude das nuvens, iluminação e gradientes vêm dos geradores originais do WeatherUI. A saída usa conversão sRGB, com uma camada de gradiente de fundo aplicada pela função original do sistema.

Há adaptações visuais para o desktop:

- Menor densidade, tamanho, brilho e cintilação das estrelas.
- Máscara vertical noturna nas condições limpas ou com poucas nuvens; também atenua nuvens finas na parte inferior.
- Nebulosas decorativas desativadas por produzirem contornos artificiais neste host.
- Reenquadramento do emissor solar para dentro da área visível.

Essas adaptações são calibradas visualmente; não representam igualdade pixel a pixel com o Tempo. A Lua usa os dados astronômicos originais para as coordenadas da cidade. O reenquadramento do Sol é uma composição visual para o wallpaper, não uma câmera orientada para uma direção celeste real.

## Verificação

```sh
./Scripts/test.sh
```

O script compila o app, aplica 143 casos ao renderizador e verifica a assinatura. Os casos cobrem condições e elevações solares, altitude das nuvens, stops e componentes finitos dos gradientes, estabilidade das estrelas em atualizações repetidas, dados lunares e configuração solar diurna.

A validação automática não substitui a inspeção visual de Metal. Foram conferidos localmente nuvens, precipitação, dia/entardecer/noite, Sol, Lua, pausa, busca de cidades e modo desktop. O registro de início com o Mac foi verificado, mas não foi realizado um novo login completo durante os testes.

## Estrutura

| Caminho | Responsabilidade |
| --- | --- |
| `Sources/main.m` | Interface Catalyst, controles e atualização automática |
| `Sources/WeatherRuntime.swift` | Configurações originais do WeatherUI e integração lunar |
| `Sources/SwiftCall.s` | Ponte ARM64 para a ABI Swift |
| `Sources/WeatherService.swift` | Open-Meteo e cálculo da iluminação solar |
| `Sources/DesktopBridge.m` | Janela de desktop, menu de status, login e atalho global |
| `Scripts/` | Compilação, instalação, ícone e validação |
| `Tests/` | Verificações de integração com o renderizador |

O [REA](https://github.com/morluto/rea) foi utilizado na investigação inicial do aplicativo e dos componentes instalados. As ferramentas e os dumps dessa investigação permanecem locais e não fazem parte da distribuição.

## Limites

- Um monitor por vez.
- Sem integração com a tela bloqueada.
- Sem colisão das gotas com elementos da interface.
- Mudanças de condição são aplicadas diretamente, sem uma transição adicional.
- Compatibilidade dependente dos componentes privados da versão instalada do macOS.

Projeto independente, sem vínculo com a Apple.
