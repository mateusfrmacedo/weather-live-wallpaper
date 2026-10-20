# Telas e composição do céu

Referências oficiais consultadas em 20/10/2026. As resoluções abaixo são pixels físicos; os pontos de interface e a escala Retina variam com a configuração do macOS.

| Tela | Pixels físicos | Referência |
| --- | --- | --- |
| MacBook Air 13″ | 2560 × 1664 | [Apple](https://www.apple.com/macbook-air/specs/) |
| MacBook Air 15″ | 2880 × 1864 | [Apple](https://www.apple.com/macbook-air/specs/) |
| MacBook Pro 14″ | 3024 × 1964 | [Apple](https://www.apple.com/mac/compare/) |
| MacBook Pro 16″ | 3456 × 2234 | [Apple](https://www.apple.com/mac/compare/) |
| iMac 24″ | 4480 × 2520 | [Apple](https://www.apple.com/imac/specs/) |
| Studio Display / Studio Display XDR 27″ | 5120 × 2880 | [Studio Display](https://support.apple.com/en-il/111890), [Studio Display XDR](https://www.apple.com/studio-display-xdr/specs/) |
| Pro Display XDR 32″ (modelo anterior) | 6016 × 3384 | [Apple](https://support.apple.com/en-ca/111892) |
| Dell S2721DGF 27″ conectado no teste | 2560 × 1440, 72 Hz | Inventário local do macOS |

A composição considera a proporção e a escala do destino, não apenas suas polegadas. A janela acompanha mudanças de tela e de escala; a camada de estrelas tem margem nas duas direções. A câmera mantém margem para a Lua e a reprodução nativa preserva a borda superior ao preencher uma tela com outra proporção. O ajuste não fornece renderizações meteorológicas independentes por monitor: uma gravação ainda é compartilhada entre os destinos.

A estrela cadente do modo de bloqueio é uma camada Core Animation, com textura preparada localmente e publicada junto da cena. Ela acompanha o compositor da tela e não é gravada nos quadros do vídeo de nuvens. A trajetória percorre 30% da largura em 1,1 segundo e desaparece, com pausa e retomada ligadas ao estado da sessão.

A imagem e o vídeo usam a mesma curva sRGB. A gravação usa HEVC Main10, com reprodução em buffers de 10 bits e composição em 16 bits por componente. A entrada Metal e o poster continuam sujeitos à precisão do renderizador original; isso não transforma a origem em HDR. A névoa decorativa de nebulosas foi removida por criar manchas no gradiente. A exportação preserva os pixels físicos até 6144 pixels no maior lado.

Os testes de enquadramento cobrem as oito resoluções acima. A validação compara também as cores e a orientação do primeiro quadro do vídeo com o poster. Os testes de sessão simulam os eventos de bloqueio e desbloqueio sem bloquear a sessão do usuário; a transição física e a percepção de fluidez no monitor devem ser confirmadas no uso normal.
