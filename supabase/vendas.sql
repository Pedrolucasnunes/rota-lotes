-- =====================================================================
-- Rota Condomínio — mapa de vendas de lotes (ESBOÇO)
-- Rodar no SQL Editor do Supabase, depois do setup.sql (que já está rodado).
-- Pode rodar mais de uma vez sem problema: este arquivo só ACRESCENTA coisas.
-- Não apaga nem altera nada do que já existe: tabelas, regras de segurança,
-- código da portaria e página do entregador continuam funcionando igual.
-- =====================================================================

-- 1) Condomínios: chave do modo vendas e ponto do stand de vendas
--    em_vendas: quando ligada, o mapa público de vendas (vendas.html) mostra os lotes.
--               Começa DESLIGADA em todos os condomínios.
--    stand_lat / stand_lng: de onde saem as visitas. Se ficar vazio, a rota sai da portaria.
alter table public.condominios add column if not exists em_vendas boolean not null default false;
alter table public.condominios add column if not exists stand_lat double precision;
alter table public.condominios add column if not exists stand_lng double precision;

-- 2) Lotes: situação da venda, área e preço
--    Os lotes que já estão cadastrados começam como 'disponivel'.
--    Área em metros quadrados e preço em reais; os dois podem ficar vazios.
alter table public.lotes add column if not exists status  text not null default 'disponivel';
alter table public.lotes add column if not exists area_m2 numeric;
alter table public.lotes add column if not exists preco   numeric;

--    Trava: o status só aceita 'disponivel', 'reservado' ou 'vendido'.
--    (O Postgres não tem "criar esta regra só se ainda não existir", então conferimos antes.)
do $$
begin
  if not exists (
    select 1 from pg_constraint
     where conrelid = 'public.lotes'::regclass
       and conname  = 'lotes_status_valido'
  ) then
    alter table public.lotes
      add constraint lotes_status_valido
      check (status in ('disponivel', 'reservado', 'vendido'));
  end if;
end
$$;

-- 3) Mapa público de vendas: quem abre vendas.html?c=<slug> (corretor ou cliente, sem login)
--    recebe os lotes e as ruas, mas SÓ se o condomínio estiver com o modo vendas ligado.
--    Modo vendas desligado, ou link errado: não devolve nada.
--    Nunca devolve a observação do lote (obs), que pode ter informação de morador.
--    Também não mostra o preço de lote já vendido (é o valor que o comprador pagou).
create or replace function public.mapa_vendas(p_slug text)
returns table (condominio text,
               stand_lat double precision, stand_lng double precision,
               portaria_lat double precision, portaria_lng double precision,
               ruas jsonb, lotes jsonb)
language sql
stable
security definer
set search_path = public
as $$
  select c.nome,
         c.stand_lat, c.stand_lng,
         c.portaria_lat, c.portaria_lng,
         (select coalesce(jsonb_agg(r.coords), '[]'::jsonb)
            from ruas r
           where r.condominio_id = c.id),
         (select coalesce(jsonb_agg(jsonb_build_object(
                   'quadra',  l.quadra,
                   'lote',    l.lote,
                   'lat',     l.lat,
                   'lng',     l.lng,
                   'status',  l.status,
                   'area_m2', l.area_m2,
                   'preco',   case when l.status = 'vendido' then null else l.preco end
                 ) order by l.quadra, l.lote), '[]'::jsonb)
            from lotes l
           where l.condominio_id = c.id)
    from condominios c
   where c.slug = p_slug
     and c.em_vendas = true;
$$;

-- 4) Quem pode usar a função: qualquer pessoa com o link (anon) e a equipe logada (authenticated).
--    As tabelas continuam fechadas para quem não fez login; a função entrega só o necessário.
revoke all on function public.mapa_vendas(text) from public;
grant execute on function public.mapa_vendas(text) to anon, authenticated;

-- 5) Pede para a API do Supabase enxergar as colunas novas na hora.
notify pgrst, 'reload schema';
