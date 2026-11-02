# Rota Condomínio — contexto do projeto

Ideia de negócio (Natal/RN): software para condomínios horizontais que mostra a entregadores (iFood) e motoristas (Uber) a localização exata da casa dentro do condomínio.

## Fluxo
1. Equipe mapeia o condomínio: clica em cada lote sobre o satélite e salva quadra/lote/coordenada.
2. Porteiro escolhe a casa no painel e gera um código de 4 dígitos (vale 20 min).
3. Entregador escaneia o QR fixo do totem (`entregador.html?c=<slug>`), digita o código e abre a rota no Google Maps ou Waze.

## Stack (MVP, sem build)
- HTML + JS puro. Leaflet (mapa), tiles Esri World Imagery (satélite) e CARTO Voyager (ruas — não usar tile.openstreetmap.org, bloqueia apps), qrcodejs, supabase-js v2 via CDN.
- Supabase (projeto `rota-condominio`, ref `mxxtnatjpkazbjvciupr`, região sa-east-1, org Free "Rota Condomínio").
  - Tabelas: `condominios`, `lotes`, `entregas` — RLS: só `authenticated` lê/escreve.
  - RPC `criar_entrega(p_lote_id)` (authenticated) e `buscar_entrega(p_slug, p_codigo)` (anon) — ambas SECURITY DEFINER de propósito.
  - Script completo em `supabase/setup.sql`.
- Hospedagem planejada: Vercel ligada a este repositório privado (GitHub Pages exige plano pago para repo privado).

## Arquivos
- `index.html` — painel (login, Mapear, Portaria, QR do totem)
- `entregador.html` — página pública do entregador
- `config.js` — URL + chave publishable do Supabase (pública)

## Limitações conhecidas / próximos passos
- Todos os usuários logados veem todos os condomínios (falta multi-tenant por condomínio).
- Código de 4 dígitos sem limite de tentativas (considerar 5–6 dígitos ou rate limit).
- Tiles gratuitos servem para piloto; para produção avaliar MapTiler pago.
- Usuário (José Hugo) não é desenvolvedor: explicar em português simples, passo a passo.
