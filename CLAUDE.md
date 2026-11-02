# Rota Condomínio — contexto do projeto

Ideia de negócio (Natal/RN): software para condomínios horizontais que mostra a entregadores (iFood) e motoristas (Uber) a localização exata da casa dentro do condomínio.

## Fluxo
1. Equipe mapeia o condomínio: clica em cada lote sobre o satélite e salva quadra/lote/coordenada. Na aba Ruas, importa as ruas do OpenStreetMap (Overpass, só no painel) e desenha à mão as que faltam; "Testar caminho" no popup do lote confere a rota.
2. Porteiro escolhe a casa no painel e gera um código de 4 dígitos (vale 20 min).
3. Entregador escaneia o QR fixo do totem (`entregador.html?c=<slug>`), digita o código e vê o caminho DENTRO da página: linha azul portaria → casa pelas ruas internas (calculada no navegador com `rotas.js`), GPS ao vivo e distância restante. Some quando o código expira.
   - Privacidade: a coordenada da casa NUNCA é enviada ao Google Maps/Waze (ficaria no histórico do entregador). Esses apps só são usados para chegar à portaria.
   - QR alternativo na portaria: `entregador.html?c=<slug>&k=<codigo>` (código já incluído; a página remove o `k` da URL).

## Stack (MVP, sem build)
- HTML + JS puro. Leaflet (mapa), tiles Esri World Imagery (satélite) e CARTO Voyager (ruas — não usar tile.openstreetmap.org, bloqueia apps), qrcodejs, supabase-js v2 via CDN.
- Supabase (projeto `rota-condominio`, ref `mxxtnatjpkazbjvciupr`, região sa-east-1, org Free "Rota Condomínio").
  - Tabelas: `condominios`, `lotes`, `entregas`, `ruas` (coords jsonb, origem osm/manual), `tentativas_codigo` — RLS: só `authenticated` lê/escreve.
  - `buscar_entrega` devolve também portaria e ruas (jsonb) do condomínio.
  - RPC `criar_entrega(p_lote_id)` (authenticated) e `buscar_entrega(p_slug, p_codigo)` (anon, com limite de tentativas) — ambas SECURITY DEFINER de propósito.
  - Script completo em `supabase/setup.sql`.
- Hospedagem planejada: Vercel ligada a este repositório privado (GitHub Pages exige plano pago para repo privado).

## Arquivos
- `index.html` — painel (login, Mapear, Portaria, QR do totem)
- `entregador.html` — página pública do entregador
- `config.js` — URL + chave publishable do Supabase (pública)
- `rotas.js` — grafo das ruas, menor caminho (Dijkstra) e progresso do GPS no caminho; usado pelas duas páginas

## Limitações conhecidas / próximos passos
- Todos os usuários logados veem todos os condomínios (falta multi-tenant por condomínio).
- Código de 4 dígitos com limite de tentativas (`tentativas_codigo`: 8 erros/IP e 100 erros/condomínio a cada 15 min). O IP vem de x-forwarded-for e pode ser falsificado; o limite por condomínio cobre isso, mas permite bloqueio temporário por abuso. Avaliar códigos de 5–6 dígitos.
- Tiles gratuitos servem para piloto; para produção avaliar MapTiler pago.
- Usuário (José Hugo) não é desenvolvedor: explicar em português simples, passo a passo.
