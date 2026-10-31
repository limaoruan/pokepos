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
  arte         text check (arte is null or length(btrim(arte)) between 1 and 100),  -- arte do botton (opcional; pode ser informada na entrega)
  fabricado_em timestamptz not null default now(),   -- registro de fabricação
  entregue_em  timestamptz,                          -- registro de entrega
  preco_venda  numeric(10,2) check (preco_venda > 0),
  recebido_em  timestamptz,                          -- null + entregue = "a receber"
  primary key (folha, numero),
  check ((entregue_em is null and preco_venda is null and recebido_em is null)
         or (entregue_em is not null and preco_venda is not null)),
  check (recebido_em is null or entregue_em is not null)
);

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

-- p_arte é opcional: se vier preenchida, grava/atualiza a arte do botton na entrega.
create or replace function entregar(p_folha bigint, p_botton smallint, p_preco numeric, p_a_receber boolean, p_arte text default null)
returns void language plpgsql set search_path = public as $$
declare
  agora timestamptz := now();
  v_custo numeric(10,2);
  v_arte text := nullif(btrim(coalesce(p_arte, '')), '');
begin
  update bottons
     set entregue_em = agora,
         preco_venda = p_preco,
         recebido_em = case when p_a_receber then null else agora end,
         arte        = coalesce(v_arte, arte)
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

-- Criar folha: o número é sempre o seguinte ao maior já cadastrado (0 se não houver nenhuma).
-- Cria a folha com p_qtd bottons (itens 1 a p_qtd, números 0 a p_qtd-1), sem arte.
create or replace function criar_folha(p_qtd int)
returns void language plpgsql set search_path = public as $$
declare v_num bigint;
begin
  if p_qtd is null or p_qtd < 1 or p_qtd > 100 then
    raise exception 'Informe de 1 a 100 bottons.';
  end if;
  perform pg_advisory_xact_lock(2);   -- evita duas folhas com o mesmo número ao mesmo tempo
  select coalesce(max(numero) + 1, 0) into v_num from folhas;
  if v_num > 999999999 then
    raise exception 'Limite de folhas atingido.';
  end if;
  insert into folhas (numero) values (v_num);
  insert into bottons (folha, numero)
  select v_num, g::smallint from generate_series(0, p_qtd - 1) g;
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
-- Folhas paginadas (mais recentes primeiro, de 100 em 100). p_antes = só folhas com número menor que esse.
-- tem_mais = true quando ainda existem folhas mais antigas.
create or replace function pos_folhas(p_limite int default 100, p_antes bigint default null) returns json
language sql stable set search_path = public as $$
  with lim as (
    select least(greatest(coalesce(p_limite, 100), 1), 500) as n
  ), pagina as (
    select f.numero from folhas f
     where p_antes is null or f.numero < p_antes
     order by f.numero desc
     limit (select n from lim) + 1
  ), pg as (
    select numero from pagina order by numero desc limit (select n from lim)
  )
  select json_build_object(
    'folhas', (
      select coalesce(json_agg(t order by t.numero desc), '[]'::json) from (
        select f.numero, f.numero + 1 as lote,
               substr(lpad(f.numero::text,9,'0'),1,3) || '-' || substr(lpad(f.numero::text,9,'0'),4,3) || '-' || substr(lpad(f.numero::text,9,'0'),7,3) as codigo,
               count(b.numero)::int as bottons, count(b.entregue_em)::int as entregues
          from pg f left join bottons b on b.folha = f.numero
         group by f.numero
      ) t
    ),
    'tem_mais', (select count(*) > (select n from lim) from pagina)
  )
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
      from bottons b where b.folha = p_folha order by b.numero asc
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

-- Caixa: totais + histórico paginado (mais recentes primeiro, todos os tipos juntos).
-- p_limite = tamanho da página (padrão 100); p_antes = só eventos com id menor que esse (para "carregar mais").
-- tem_mais = true quando ainda existem eventos mais antigos.
create or replace function pos_caixa(p_limite int default 100, p_antes bigint default null) returns json
language sql stable set search_path = public as $$
  with lim as (
    select least(greatest(coalesce(p_limite, 100), 1), 500) as n
  ), pagina as (
    select e.* from caixa_eventos e
     where p_antes is null or e.id < p_antes
     order by e.id desc
     limit (select n from lim) + 1
  )
  select json_build_object(
    'totais', (select row_to_json(x) from (select qtd_bottons, custo, lucro from caixa_totais) x),
    'historico', (
      select coalesce(json_agg(t order by t.id desc), '[]'::json) from (
        select p.id, p.tipo, p.valor, p.custo_delta, p.lucro_delta, p.descricao,
               case when p.folha is null then null else pid_fmt(p.folha, p.botton) end as pid,
               to_char(p.criado_em at time zone 'America/Sao_Paulo', 'DD/MM/YYYY HH24:MI:SS') as quando
          from (select * from pagina order by id desc limit (select n from lim)) p
      ) t
    ),
    'tem_mais', (select count(*) > (select n from lim) from pagina)
  )
$$;

-- Ping: consulta mínima e pública, só para manter o projeto Supabase ativo (não lê nenhum dado).
-- Chamada por uma tarefa agendada no cron-job.org (ver README, seção Manutenção).
create or replace function ping() returns text
language sql stable set search_path = public as $$ select 'ok'::text $$;

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
  pid_fmt(bigint, smallint), bloquear_exclusao_entregue(),
  entregar(bigint, smallint, numeric, boolean, text), criar_folha(int), receber(bigint, smallint),
  custear(numeric, text), investir(numeric, text),
  pos_folhas(int, bigint), pos_bottons(bigint), pos_a_receber(), pos_caixa(int, bigint), ping()
  from public, anon, authenticated;

grant select, insert, update, delete on folhas, bottons to authenticated;
grant select, insert on caixa_eventos to authenticated;          -- o histórico não pode ser editado nem apagado pelo site
grant select on caixa_totais, a_receber to authenticated;
grant usage, select on sequence caixa_eventos_id_seq to authenticated;

grant execute on function pid_fmt(bigint, smallint)                          to authenticated;
grant execute on function entregar(bigint, smallint, numeric, boolean, text) to authenticated;
grant execute on function criar_folha(int)                                   to authenticated;
grant execute on function receber(bigint, smallint)                          to authenticated;
grant execute on function custear(numeric, text)                             to authenticated;
grant execute on function investir(numeric, text)                            to authenticated;
grant execute on function pos_folhas(int, bigint)                            to authenticated;
grant execute on function pos_bottons(bigint)                                to authenticated;
grant execute on function pos_a_receber()                                    to authenticated;
grant execute on function pos_caixa(int, bigint)                             to authenticated;
grant execute on function ping()                                             to anon, authenticated;
