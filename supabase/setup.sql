-- =====================================================================
-- Rota Condomínio — estrutura do banco (rodar UMA vez no SQL Editor do Supabase)
-- =====================================================================

create extension if not exists pgcrypto;

-- 1) Condomínios atendidos
create table if not exists public.condominios (
  id            uuid primary key default gen_random_uuid(),
  nome          text not null,
  slug          text not null unique,          -- identificador usado no QR do totem
  portaria_lat  double precision,
  portaria_lng  double precision,
  criado_em     timestamptz not null default now()
);

-- 2) Lotes/casas mapeados
create table if not exists public.lotes (
  id             uuid primary key default gen_random_uuid(),
  condominio_id  uuid not null references public.condominios(id) on delete cascade,
  quadra         text not null,
  lote           text not null,
  obs            text,
  lat            double precision not null,
  lng            double precision not null,
  criado_em      timestamptz not null default now(),
  unique (condominio_id, quadra, lote)
);

-- 3) Entregas: cada código gerado na portaria
create table if not exists public.entregas (
  id             bigint generated always as identity primary key,
  condominio_id  uuid not null references public.condominios(id) on delete cascade,
  lote_id        uuid not null references public.lotes(id) on delete cascade,
  codigo         text not null,
  criado_por     uuid default auth.uid(),
  criado_em      timestamptz not null default now(),
  expira_em      timestamptz not null default now() + interval '20 minutes',
  aberto_em      timestamptz                    -- quando o entregador abriu a rota
);
create index if not exists entregas_condo_codigo_idx on public.entregas (condominio_id, codigo);

-- 4) Segurança: só usuários logados (você e os porteiros) acessam as tabelas.
--    O entregador NÃO acessa as tabelas; ele só consegue usar a função buscar_entrega.
alter table public.condominios enable row level security;
alter table public.lotes       enable row level security;
alter table public.entregas    enable row level security;

drop policy if exists equipe_condominios on public.condominios;
create policy equipe_condominios on public.condominios
  for all to authenticated using (true) with check (true);

drop policy if exists equipe_lotes on public.lotes;
create policy equipe_lotes on public.lotes
  for all to authenticated using (true) with check (true);

drop policy if exists equipe_entregas_leitura on public.entregas;
create policy equipe_entregas_leitura on public.entregas
  for select to authenticated using (true);

-- Permissões explícitas (necessárias se "Automatically expose new tables" estiver desligado)
grant usage on schema public to anon, authenticated;
grant select, insert, update, delete on public.condominios, public.lotes to authenticated;
grant select on public.entregas to authenticated;

-- 5) Porteiro gera o código de 4 dígitos para uma casa
create or replace function public.criar_entrega(p_lote_id uuid)
returns table (codigo_gerado text, valido_ate timestamptz)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_condo uuid;
  v_cod   text;
  v_exp   timestamptz;
  v_tent  int := 0;
begin
  if auth.uid() is null then
    raise exception 'Faça login para gerar códigos';
  end if;

  select l.condominio_id into v_condo from lotes l where l.id = p_lote_id;
  if v_condo is null then
    raise exception 'Lote não encontrado';
  end if;

  loop
    v_cod := lpad((floor(random() * 10000))::int::text, 4, '0');
    exit when not exists (
      select 1 from entregas e
      where e.condominio_id = v_condo and e.codigo = v_cod and e.expira_em > now()
    );
    v_tent := v_tent + 1;
    if v_tent > 50 then
      raise exception 'Não há códigos livres no momento';
    end if;
  end loop;

  insert into entregas (condominio_id, lote_id, codigo)
  values (v_condo, p_lote_id, v_cod)
  returning entregas.expira_em into v_exp;

  return query select v_cod, v_exp;
end;
$$;

-- 6) Entregador digita o código e recebe o destino (só se o código estiver válido)
create or replace function public.buscar_entrega(p_slug text, p_codigo text)
returns table (condominio text, quadra text, lote text, obs text,
               lat double precision, lng double precision, valido_ate timestamptz)
language sql
security definer
set search_path = public
as $$
  update entregas e
     set aberto_em = coalesce(e.aberto_em, now())
    from lotes l, condominios c
   where e.lote_id = l.id
     and e.condominio_id = c.id
     and c.slug = p_slug
     and e.codigo = p_codigo
     and e.expira_em > now()
  returning c.nome, l.quadra, l.lote, l.obs, l.lat, l.lng, e.expira_em;
$$;

-- 7) Quem pode chamar cada função
revoke all on function public.criar_entrega(uuid) from public, anon;
grant execute on function public.criar_entrega(uuid) to authenticated;

revoke all on function public.buscar_entrega(text, text) from public;
grant execute on function public.buscar_entrega(text, text) to anon, authenticated;
