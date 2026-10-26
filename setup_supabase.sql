-- =====================================================================
-- PokéPOS · Banco de dados (Supabase / PostgreSQL 15+)
-- Usado por: PokéPOS (usuário logado, leitura/escrita)
-- Execute este arquivo inteiro no SQL Editor do Supabase, uma única vez (setup_supabase.sql).
-- Se for usar também o PIDgey no mesmo projeto, rode ESTE arquivo primeiro e depois o do PIDgey.
-- Horários são guardados em UTC (timestamptz); o site exibe em America/Sao_Paulo.
-- Segurança: RLS ligado em todas as tabelas; o público (anon) não acessa nada daqui.
-- =====================================================================

-- ---------- 1. Formatação do PID: PID-LLL-LLL-LLL/II ----------
create or replace function pid_fmt(f bigint, b smallint) returns text
language sql immutable set search_path = public as $$
  select 'PID-' || substr(lpad(f::text, 9, '0'), 1, 3)
      || '-'    || substr(lpad(f::text, 9, '0'), 4, 3)
      || '-'    || substr(lpad(f::text, 9, '0'), 7, 3)
      || '/'    || lpad(b::text, 2, '0')
$$;

-- ---------- 2. Folhas (lotes) ----------
-- numero 0 = Lote 1 ... 999.999.999 = Lote 1.000.000.000
create table folhas (
  numero    bigint primary key check (numero between 0 and 999999999),
  criada_em timestamptz not null default now()
);

-- ---------- 3. Bottons (itens) ----------
-- numero 0 = Item 1 ... 99 = Item 100  (máx. 100 por folha, garantido pela chave)
create table bottons (
  folha        bigint   not null references folhas(numero) on delete cascade,
  numero       smallint not null check (numero between 0 and 99),
  arte         text check (arte is null or length(btrim(arte)) between 1 and 100),  -- arte do botton (obrigatória no cadastro)
  fabricado_em timestamptz not null default now(),   -- registro de fabricação
  entregue_em  timestamptz,                          -- registro de entrega
  preco_venda  numeric(10,2) check (preco_venda > 0),
  recebido_em  timestamptz,                          -- null + entregue = "a receber"
  primary key (folha, numero),
  check ((entregue_em is null and preco_venda is null and recebido_em is null)
         or (entregue_em is not null and preco_venda is not null)),
  check (recebido_em is null or entregue_em is not null)
);

-- Exige a arte em todo botton novo (botton antigo sem arte continua válido)
create or replace function exigir_arte() returns trigger
language plpgsql set search_path = public as $$
begin
  if length(btrim(coalesce(new.arte, ''))) = 0 then
    raise exception 'Informe a arte do botton.';
  end if;
  new.arte := btrim(new.arte);
  return new;
end $$;

create trigger trg_exigir_arte
before insert on bottons
for each row execute function exigir_arte();

-- Bloqueia exclusão de botton já entregue (e, por cascata, de folha que tenha algum)
create or replace function bloquear_exclusao_entregue() returns trigger
language plpgsql set search_path = public as $$
begin
  if old.entregue_em is not null then
    raise exception 'Botton já entregue não pode ser excluído (%).', pid_fmt(old.folha, old.numero);
  end if;
  return old;
end $$;

create trigger trg_bloquear_exclusao
before delete on bottons
for each row execute function bloquear_exclusao_entregue();

-- ---------- 4. Histórico do Caixa (uma linha por evento) ----------
create table caixa_eventos (
  id          bigserial primary key,
  tipo        text not null check (tipo in ('entrega','recebimento','custeio','investimento')),
  criado_em   timestamptz not null default now(),
  folha       bigint,
  botton      smallint,
  valor       numeric(10,2) not null check (valor > 0),
  custo_delta numeric(10,2) not null default 0,
  lucro_delta numeric(10,2) not null default 0,
  descricao   text,
  foreign key (folha, botton) references bottons(folha, numero),
  check (tipo not in ('custeio','investimento') or length(btrim(coalesce(descricao, ''))) > 0)  -- custeio e investimento exigem descrição
);
create index on caixa_eventos (criado_em desc);

-- ---------- 5. Visões (security_invoker: respeitam o RLS de quem consulta) ----------
-- Totais do Caixa: Qtd. de Bottons | Custo | Lucro
create view caixa_totais with (security_invoker = true) as
select
  (select count(*) from caixa_eventos where tipo = 'entrega')::int as qtd_bottons,
  coalesce(sum(custo_delta), 0) as custo,
  coalesce(sum(lucro_delta), 0) as lucro
from caixa_eventos;

-- Aba "À Receber"
create view a_receber with (security_invoker = true) as
select folha, numero as botton, pid_fmt(folha, numero) as pid, preco_venda, entregue_em
from bottons
where entregue_em is not null and recebido_em is null
order by entregue_em;

-- ---------- 6. Operações (cada uma é uma transação única) ----------
-- Regra: 53,50% do valor recebido -> Custo (arredondado SEMPRE para cima, ex.: 2,675 -> 2,68) ; o restante -> Lucro (preço - custo)

create or replace function entregar(p_folha bigint, p_botton smallint, p_preco numeric, p_a_receber boolean)
returns void language plpgsql set search_path = public as $$
declare
  agora timestamptz := now();
  v_custo numeric(10,2);
begin
  update bottons
     set entregue_em = agora,
         preco_venda = p_preco,
         recebido_em = case when p_a_receber then null else agora end
   where folha = p_folha and numero = p_botton and entregue_em is null;
  if not found then
    raise exception 'Botton inexistente ou já entregue.';
  end if;

  insert into caixa_eventos (tipo, criado_em, folha, botton, valor)
  values ('entrega', agora, p_folha, p_botton, p_preco);

  if not p_a_receber then
    v_custo := ceil(p_preco * 0.535 * 100) / 100;
    insert into caixa_eventos (tipo, criado_em, folha, botton, valor, custo_delta, lucro_delta)
    values ('recebimento', agora, p_folha, p_botton, p_preco, v_custo, p_preco - v_custo);
  end if;
end $$;

create or replace function receber(p_folha bigint, p_botton smallint)
returns void language plpgsql set search_path = public as $$
declare
  agora timestamptz := now();
  v_preco numeric(10,2);
  v_custo numeric(10,2);
begin
  update bottons set recebido_em = agora
   where folha = p_folha and numero = p_botton
     and entregue_em is not null and recebido_em is null
  returning preco_venda into v_preco;
  if not found then
    raise exception 'Botton não está pendente de recebimento.';
  end if;

  v_custo := ceil(v_preco * 0.535 * 100) / 100;
  insert into caixa_eventos (tipo, criado_em, folha, botton, valor, custo_delta, lucro_delta)
  values ('recebimento', agora, p_folha, p_botton, v_preco, v_custo, v_preco - v_custo);
end $$;

-- Custear: retira do Custo (descrição obrigatória; não deixa o Custo ficar negativo)
create or replace function custear(p_valor numeric, p_descricao text)
returns void language plpgsql set search_path = public as $$
declare v_saldo numeric(10,2);
begin
  perform pg_advisory_xact_lock(1);
  select coalesce(sum(custo_delta), 0) into v_saldo from caixa_eventos;
  if p_valor > v_saldo then
    raise exception 'Valor maior que o Custo disponível (R$ %).', v_saldo;
  end if;
  insert into caixa_eventos (tipo, valor, custo_delta, descricao)
  values ('custeio', p_valor, -p_valor, p_descricao);
end $$;

-- Investir: adiciona dinheiro ao Custo (descrição obrigatória)
create or replace function investir(p_valor numeric, p_descricao text)
returns void language plpgsql set search_path = public as $$
begin
  perform pg_advisory_xact_lock(1);
  insert into caixa_eventos (tipo, valor, custo_delta, descricao)
  values ('investimento', p_valor, p_valor, p_descricao);
end $$;

-- ---------- 7. Leituras do PokéPOS (já formatadas) ----------
create or replace function pos_folhas() returns json
language sql stable set search_path = public as $$
  select coalesce(json_agg(t), '[]'::json) from (
    select f.numero, f.numero + 1 as lote,
           substr(lpad(f.numero::text,9,'0'),1,3) || '-' || substr(lpad(f.numero::text,9,'0'),4,3) || '-' || substr(lpad(f.numero::text,9,'0'),7,3) as codigo,
           count(b.numero)::int as bottons, count(b.entregue_em)::int as entregues
      from folhas f left join bottons b on b.folha = f.numero
     group by f.numero order by f.criada_em desc, f.numero desc
  ) t
$$;

create or replace function pos_bottons(p_folha bigint) returns json
language sql stable set search_path = public as $$
  select coalesce(json_agg(t), '[]'::json) from (
    select b.numero, b.numero + 1 as item, pid_fmt(b.folha, b.numero) as pid, b.arte, b.preco_venda,
           to_char(b.fabricado_em at time zone 'America/Sao_Paulo', 'DD/MM/YYYY HH24:MI:SS') as fabricado_em,
           to_char(b.entregue_em  at time zone 'America/Sao_Paulo', 'DD/MM/YYYY HH24:MI:SS') as entregue_em,
           to_char(b.recebido_em  at time zone 'America/Sao_Paulo', 'DD/MM/YYYY HH24:MI:SS') as recebido_em,
           case when b.entregue_em is null then 'estoque'
                when b.recebido_em is null then 'a_receber' else 'recebido' end as status
      from bottons b where b.folha = p_folha order by b.fabricado_em desc, b.numero desc
  ) t
$$;

create or replace function pos_a_receber() returns json
language sql stable set search_path = public as $$
  select coalesce(json_agg(t), '[]'::json) from (
    select ar.folha, ar.botton, ar.pid, ar.preco_venda,
           to_char(ar.entregue_em at time zone 'America/Sao_Paulo', 'DD/MM/YYYY HH24:MI:SS') as entregue_em
      from a_receber ar order by ar.entregue_em desc, ar.folha desc, ar.botton desc
  ) t
$$;

create or replace function pos_caixa(p_limite int default 100) returns json
language sql stable set search_path = public as $$
  select json_build_object(
    'totais', (select row_to_json(x) from (select qtd_bottons, custo, lucro from caixa_totais) x),
    'historico', (
      select coalesce(json_agg(t order by t.id desc), '[]'::json) from (
        select id, tipo, valor, custo_delta, lucro_delta, descricao,
               case when folha is null then null else pid_fmt(folha, botton) end as pid,
               to_char(criado_em at time zone 'America/Sao_Paulo', 'DD/MM/YYYY HH24:MI:SS') as quando
          from (
            select e.*, row_number() over (partition by e.tipo order by e.id desc) as n
              from caixa_eventos e
          ) e
         where n <= least(greatest(coalesce(p_limite, 100), 1), 500)  -- limite POR TIPO
      ) t
    )
  )
$$;

-- ---------- 8. Segurança (RLS + permissões) ----------
alter table folhas        enable row level security;
alter table bottons       enable row level security;
alter table caixa_eventos enable row level security;

-- Só usuário logado (o dono) enxerga e altera. O cadastro de novos usuários deve ficar DESLIGADO no painel.
create policy dono_folhas  on folhas        for all    to authenticated using (true) with check (true);
create policy dono_bottons on bottons       for all    to authenticated using (true) with check (true);
create policy dono_caixa_l on caixa_eventos for select to authenticated using (true);
create policy dono_caixa_i on caixa_eventos for insert to authenticated with check (true);

-- Tira tudo do público (anon) nas tabelas e nas funções deste arquivo; depois libera só o necessário.
-- (As funções são citadas uma a uma para não mexer na consultar_pid do PIDgey, se ela já existir.)
revoke all on all tables    in schema public from anon, authenticated;
revoke all on all sequences in schema public from anon, authenticated;
revoke execute on function
  pid_fmt(bigint, smallint), exigir_arte(), bloquear_exclusao_entregue(),
  entregar(bigint, smallint, numeric, boolean), receber(bigint, smallint),
  custear(numeric, text), investir(numeric, text),
  pos_folhas(), pos_bottons(bigint), pos_a_receber(), pos_caixa(int)
  from public, anon, authenticated;

grant select, insert, update, delete on folhas, bottons to authenticated;
grant select, insert on caixa_eventos to authenticated;          -- o histórico não pode ser editado nem apagado pelo site
grant select on caixa_totais, a_receber to authenticated;
grant usage, select on sequence caixa_eventos_id_seq to authenticated;

grant execute on function pid_fmt(bigint, smallint)                          to authenticated;
grant execute on function entregar(bigint, smallint, numeric, boolean)       to authenticated;
grant execute on function receber(bigint, smallint)                          to authenticated;
grant execute on function custear(numeric, text)                             to authenticated;
grant execute on function investir(numeric, text)                            to authenticated;
grant execute on function pos_folhas()                                       to authenticated;
grant execute on function pos_bottons(bigint)                                to authenticated;
grant execute on function pos_a_receber()                                    to authenticated;
grant execute on function pos_caixa(int)                                     to authenticated;
