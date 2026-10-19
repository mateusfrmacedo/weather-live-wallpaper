#!/bin/zsh
set -eu
cd "$(dirname "$0")/.."

Scripts/build-native-prototype.sh --release
app="$PWD/Build/ReleaseApp/Weather Wallpaper.app"
version=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$app/Contents/Info.plist")
output="$PWD/Build/Release/$version"
name="Weather-Wallpaper-$version-macOS-arm64"
mkdir -p "$output"
stage=$(mktemp -d "$PWD/Build/package.XXXXXX")
trap 'rm -rf "$stage"' EXIT

codesign --verify --deep --strict "$app"
ditto "$app" "$stage/Weather Wallpaper.app"
ln -s /Applications "$stage/Applications"
cat > "$stage/LEIA-ME.txt" <<'EOF'
Weather Wallpaper

Requisitos: Mac com Apple Silicon e macOS 27.
Verificado no macOS 27.0.1 (26A434). Outras versões podem ser incompatíveis
porque o app usa componentes privados do aplicativo Tempo do sistema.

Instalação: arraste Weather Wallpaper.app para Applications e abra o app.
O download ZIP também pode ser descompactado e copiado para Aplicativos.
Não é necessário instalar Xcode para usar esta versão pronta.

Esta versão tem assinatura ad hoc e não é notarizada pela Apple.
Se o macOS bloquear a abertura, tente abrir o app uma vez e, em seguida,
acesse Ajustes do Sistema > Privacidade e Segurança > Abrir Mesmo Assim.
Confirme a abertura apenas se o arquivo veio do repositório oficial abaixo.

Escolha uma cidade nas configurações.
Em Animação, escolha Sempre animado ou Ao bloquear.
Para Ao bloquear: clique em Ajustes de Papel de Parede, selecione
Weather Wallpaper e escolha a mesma opção como proteção de tela.
Mantenha o app aberto para atualizar o clima. A primeira preparação
leva alguns segundos. A seleção anterior do papel de parede do sistema
não é substituída automaticamente.

Novidades 0.3.2: halo lunar reduzido preservando os detalhes da lua,
estrelas mais discretas na parte inferior e captura Retina com HEVC.
Mantém o movimento lunar atualizado e a estrela cadente em toda a largura.
Inclui dois modos de animação, configurações compactas,
botões Liquid Glass e preferência de modo salva.
O loop nativo é experimental e pode apresentar uma emenda visível.
Atalho para recuperar os controles: Command + Shift + P.

Código-fonte, documentação e novas versões:
https://github.com/mateusfrmacedo/weather-live-wallpaper
EOF

ditto -c -k --sequesterRsrc --keepParent "$app" "$output/$name.zip"
hdiutil create -volname "Weather Wallpaper $version" -srcfolder "$stage" \
  -format UDZO -ov "$output/$name.dmg"
(cd "$output" && shasum -a 256 "$name.dmg" "$name.zip" > SHA256SUMS.txt)
echo "$output"
