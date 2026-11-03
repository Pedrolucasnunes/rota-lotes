# Rota Lotes — contexto do projeto

Ideia de negócio (Natal/RN): mapa de vendas de lotes para loteadoras. Durante as vendas, corretor e cliente veem no celular, sobre o satélite, os lotes disponíveis, reservados e vendidos, e seguem o caminho pelas ruas internas até o lote. Depois da entrega do loteamento, o mesmo mapa vira um bônus para a portaria e os entregadores (iFood/Uber), com o fluxo de código de 4 dígitos herdado do projeto original (rota-condominio).

## Repositório e banco
- GitHub: `Pedrolucasnunes/rota-lotes`. Neste clone ele é o remote `novo`; o `origin` é o repositório antigo do Hugo (`jhgadelha/rota-condominio`). **Nunca fazer push para `origin`.**
- Trabalhar em branch e abrir PR em rascunho para a `main`; não fazer commit nem merge direto na `main`.
- Supabase próprio do rota-lotes: ref `vjsyfbfodbcfddiyqynq` (API `https://vjsyfbfodbcfddiyqynq.supabase.co`). O Supabase antigo do Hugo (`mxxtnatjpkazbjvciupr`) não é usado aqui.
- Sem acesso direto ao banco: mudança de banco vai num arquivo SQL novo, só aditivo e idempotente, que o Pedro roda no SQL Editor. Não alterar o conteúdo de `supabase/setup.sql`. `setup.sql` e `vendas.sql` já foram rodados no Supabase do rota-lotes.

## Fluxo de vendas (foco atual, esboço)
1. Equipe mapeia o loteamento no painel (`index.html`, aba Mapear): lotes (quadra/lote, situação, área, preço), ruas (importadas do OpenStreetMap ou desenhadas), portaria e stand de vendas. "Testar do stand" no popup do lote confere a rota.
2. Na aba Vendas, liga o "Modo vendas (mapa público)" e compartilha o link/QR `vendas.html?c=<slug>` com os corretores.
3. `vendas.html` (pública, sem login) chama a RPC `mapa_vendas(slug)`: lotes coloridos por situação (verde disponível, amarelo reservado, cinza vendido), legenda, filtro "Só disponíveis / Todos", resumo "X disponíveis de Y" e card do lote. "Como chegar até este lote" aparece só para disponível e reservado: caminho saindo do stand (ou da portaria) calculado no navegador com `rotas.js`, com GPS opcional.
   - Privacidade: `mapa_vendas` só responde com `em_vendas = true` e nunca devolve `obs` nem o preço de lote vendido. Google Maps/Waze só recebem o ponto do stand/portaria, nunca o lote. Quando as vendas acabarem, desligar o modo vendas.

## Fluxo de entrega (bônus depois da entrega do loteamento)
1. Porteiro escolhe a casa no painel e gera um código de 4 dígitos (vale 20 min).
2. Entregador escaneia o QR fixo do totem (`entregador.html?c=<slug>`), digita o código e vê o caminho DENTRO da página: linha azul portaria → casa pelas ruas internas (calculada no navegador com `rotas.js`), GPS ao vivo e distância restante. Some quando o código expira.
   - Privacidade: a coordenada da casa NUNCA é enviada ao Google Maps/Waze (ficaria no histórico do entregador). Esses apps só são usados para chegar à portaria.
   - QR alternativo na portaria: `entregador.html?c=<slug>&k=<codigo>` (código já incluído; a página remove o `k` da URL).

## Stack (MVP, sem build)
- HTML + JS puro. Leaflet (mapa), tiles Esri World Imagery (satélite) e CARTO Voyager (ruas — não usar tile.openstreetmap.org, bloqueia apps), qrcodejs, supabase-js v2 via CDN.
- Supabase:
  - Tabelas: `condominios` (com `em_vendas`, `stand_lat`, `stand_lng`), `lotes` (com `status` disponivel/reservado/vendido, `area_m2`, `preco`), `entregas`, `ruas` (coords jsonb, origem osm/manual), `tentativas_codigo` — RLS: só `authenticated` lê/escreve.
  - RPCs, todas SECURITY DEFINER de propósito: `criar_entrega(p_lote_id)` (authenticated), `buscar_entrega(p_slug, p_codigo)` (anon, com limite de tentativas; devolve também portaria e ruas) e `mapa_vendas(p_slug)` (anon; só com o modo vendas ligado).
  - Scripts: `supabase/setup.sql` (base) e `supabase/vendas.sql` (mapa de vendas).
- Hospedagem do rota-lotes: a definir (o rota-condominio original é publicado pela Vercel a partir da `main`).

## Arquivos
- `index.html` — painel (login, Mapear, Portaria, QR do totem, Vendas)
- `vendas.html` — mapa público de vendas
- `entregador.html` — página pública do entregador
- `config.js` — URL + chave publishable do Supabase (pública)
- `rotas.js` — grafo das ruas, menor caminho (Dijkstra) e progresso do GPS no caminho; usado pelas três páginas
- `supabase/setup.sql`, `supabase/vendas.sql`

## Limitações conhecidas / próximos passos
- O mapa de vendas é um esboço: sem login de corretor, sem reserva feita pelo próprio mapa e sem histórico de vendas.
- Todos os usuários logados veem todos os condomínios (falta separar o acesso por loteadora/condomínio).
- Código de 4 dígitos com limite de tentativas (`tentativas_codigo`: 8 erros/IP e 100 erros/condomínio a cada 15 min). O IP vem de x-forwarded-for e pode ser falsificado; o limite por condomínio cobre isso, mas permite bloqueio temporário por abuso. Avaliar códigos de 5–6 dígitos.
- Tiles gratuitos servem para piloto; para produção avaliar MapTiler pago.

## Comunicação
- Responder em português. Instruções para quem opera o sistema (painel, Supabase) em linguagem simples, passo a passo.
