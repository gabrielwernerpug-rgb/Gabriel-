-- Correções aplicadas direto no banco de produção em 16/10/2026, uma por vez.
-- Tudo aqui é idempotente: pode rodar de novo sem quebrar nada.
-- Quando houver crédito no Lovable, este arquivo vira uma migration do projeto.

-- ═══ P1: funções de cota abertas para qualquer pessoa ═══════════════════
-- A migration 20260910161901 fez REVOKE de anon/authenticated mas esqueceu o
-- PUBLIC, de quem os dois herdam. Testado depois: chamar
-- /rest/v1/rpc/ai_usage_refund_kind de fora → "permission denied".
REVOKE ALL ON FUNCTION public.ai_usage_hit_kind(uuid, text, integer, integer) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.ai_usage_refund_kind(uuid, text)                FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.ai_usage_hit_kind(uuid, text, integer, integer) TO service_role;
GRANT EXECUTE ON FUNCTION public.ai_usage_refund_kind(uuid, text)                TO service_role;
REVOKE ALL ON FUNCTION public.user_plan(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.user_plan(uuid) TO authenticated, service_role;
-- Função nova não nasce mais executável por anon/authenticated: GRANT explícito.
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC, anon, authenticated;

-- ═══ P2: tabelas que o código da Fase 1 (commit 12ea626) espera ═══════════
-- Sem elas o disjuntor não acha a config e toda chamada à IA vira 503.
-- Testado: ai_global_hit com teto 1 → 1ª true, 2ª false; anon sem acesso.
CREATE TABLE IF NOT EXISTS public.identify_sessions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  candidates jsonb NOT NULL,
  source text,
  organ text,
  created_at timestamptz NOT NULL DEFAULT now(),
  used_at timestamptz
);
CREATE INDEX IF NOT EXISTS identify_sessions_user_idx ON public.identify_sessions (user_id, created_at DESC);
ALTER TABLE public.identify_sessions ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.identify_sessions FROM PUBLIC, anon, authenticated;
GRANT ALL ON public.identify_sessions TO service_role;

CREATE TABLE IF NOT EXISTS public.ai_global_usage (
  day date NOT NULL DEFAULT ((now() AT TIME ZONE 'UTC')::date),
  kind text NOT NULL,
  count integer NOT NULL DEFAULT 0,
  PRIMARY KEY (day, kind)
);
ALTER TABLE public.ai_global_usage ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.ai_global_usage FROM PUBLIC, anon, authenticated;
GRANT ALL ON public.ai_global_usage TO service_role;

CREATE OR REPLACE FUNCTION public.ai_global_hit(_kind text, _cap integer)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $$
DECLARE
  _day date := (now() AT TIME ZONE 'UTC')::date;
  _count integer;
BEGIN
  INSERT INTO public.ai_global_usage AS g (day, kind, count)
  VALUES (_day, _kind, 1)
  ON CONFLICT (day, kind) DO UPDATE SET count = g.count + 1
  RETURNING g.count INTO _count;
  RETURN _count <= _cap;
END;
$$;
REVOKE ALL ON FUNCTION public.ai_global_hit(text, integer) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.ai_global_hit(text, integer) TO service_role;

CREATE TABLE IF NOT EXISTS public.ai_calls (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  kind text NOT NULL,
  model text,
  input_tokens integer,
  output_tokens integer,
  ms integer,
  ok boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS ai_calls_created_idx ON public.ai_calls (created_at DESC);
ALTER TABLE public.ai_calls ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.ai_calls FROM PUBLIC, anon, authenticated;
GRANT ALL ON public.ai_calls TO service_role;

INSERT INTO public.app_config (key, value) VALUES
  ('ai_enabled', 'true'), ('ai_daily_cap', '300'), ('plantnet_daily_cap', '450')
ON CONFLICT (key) DO NOTHING;

-- ═══ P3: funções antigas que gravavam o chat no contador de identificação ═══
-- O código (commit 12ea626) não usa mais nenhuma das duas. Testado: 0 restantes.
DROP FUNCTION IF EXISTS public.ai_usage_hit(uuid, integer);
DROP FUNCTION IF EXISTS public.ai_usage_refund(uuid);

-- ═══ P4: teste grátis de 14 dias (não existia) ═══════════════════════════
-- Testado com rollback: teste valendo → pro; vencido → free; manutenção derruba
-- a coluna; conta Google nova → pro/trialing/14d; mesmo e-mail de novo → free.
-- Quem já usou o teste (hash do e-mail): apagar a conta e criar de novo não dá outro teste.
CREATE TABLE IF NOT EXISTS public.trial_claims (
  email_hash text PRIMARY KEY,
  created_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.trial_claims ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.trial_claims FROM PUBLIC, anon, authenticated;
GRANT ALL ON public.trial_claims TO service_role;

-- Todo perfil novo de conta Google ganha 14 dias de Pro, uma vez por e-mail.
-- Vale tanto para o perfil criado no cadastro quanto para o criado pelo servidor.
CREATE OR REPLACE FUNCTION public.profiles_grant_trial()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'extensions' AS $$
DECLARE
  _email text;
  _anon boolean;
  _first boolean;
BEGIN
  IF EXISTS (SELECT 1 FROM public.profiles WHERE user_id = NEW.user_id) THEN RETURN NEW; END IF;
  IF NEW.plan <> 'free' OR NEW.trial_ends_at IS NOT NULL THEN RETURN NEW; END IF;
  SELECT u.email, COALESCE(u.is_anonymous, false) INTO _email, _anon FROM auth.users u WHERE u.id = NEW.user_id;
  IF _email IS NULL OR _anon THEN RETURN NEW; END IF;
  INSERT INTO public.trial_claims (email_hash)
  VALUES (encode(extensions.digest(lower(_email), 'sha256'), 'hex'))
  ON CONFLICT DO NOTHING
  RETURNING true INTO _first;
  IF _first THEN
    NEW.plan := 'pro';
    NEW.subscription_status := 'trialing';
    NEW.trial_ends_at := now() + interval '14 days';
  END IF;
  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'profiles_grant_trial: %', SQLERRM;
  RETURN NEW;
END;
$$;
REVOKE ALL ON FUNCTION public.profiles_grant_trial() FROM PUBLIC, anon, authenticated;
DROP TRIGGER IF EXISTS profiles_grant_trial ON public.profiles;
CREATE TRIGGER profiles_grant_trial BEFORE INSERT ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.profiles_grant_trial();

-- Cria o perfil já no cadastro (o gatilho acima decide o teste).
CREATE OR REPLACE FUNCTION public.handle_new_user_profile()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $$
BEGIN
  INSERT INTO public.profiles (user_id) VALUES (NEW.id) ON CONFLICT (user_id) DO NOTHING;
  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'handle_new_user_profile: %', SQLERRM;  -- nunca bloquear o cadastro
  RETURN NEW;
END;
$$;
REVOKE ALL ON FUNCTION public.handle_new_user_profile() FROM PUBLIC, anon, authenticated;
-- Funções de gatilho não são chamáveis diretamente; o GRANT só garante que o
-- serviço de login nunca tropece em permissão.
GRANT EXECUTE ON FUNCTION public.handle_new_user_profile() TO supabase_auth_admin, service_role;
GRANT EXECUTE ON FUNCTION public.profiles_grant_trial() TO supabase_auth_admin, service_role;

-- "É Pro?" num lugar só, olhando a data do teste.
CREATE OR REPLACE FUNCTION public.user_plan(_user_id uuid)
RETURNS text LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public' AS $$
  SELECT CASE
    WHEN auth.uid() IS NOT NULL AND auth.uid() <> _user_id THEN 'free'
    ELSE COALESCE((
      SELECT CASE
        WHEN p.plan = 'pro' AND p.subscription_status IN ('active', 'manual') THEN 'pro'
        WHEN p.plan = 'pro' AND p.subscription_status = 'trialing' AND p.trial_ends_at > now() THEN 'pro'
        ELSE 'free'
      END
      FROM public.profiles p WHERE p.user_id = _user_id), 'free')
  END;
$$;

-- O servidor ainda lê a coluna plan: o teste vencido vira free de hora em hora.
CREATE OR REPLACE FUNCTION public.maintenance_hourly()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $$
DECLARE _expired int; _sessions int; _rl int;
BEGIN
  UPDATE public.profiles SET plan = 'free', subscription_status = 'expired'
   WHERE plan = 'pro' AND subscription_status = 'trialing' AND trial_ends_at <= now();
  GET DIAGNOSTICS _expired = ROW_COUNT;
  DELETE FROM public.identify_sessions WHERE created_at < now() - interval '2 days';
  GET DIAGNOSTICS _sessions = ROW_COUNT;
  DELETE FROM public.rate_limits WHERE reset_at < now() - interval '1 day';
  GET DIAGNOSTICS _rl = ROW_COUNT;
  RETURN jsonb_build_object('trials_expirados', _expired, 'sessoes_apagadas', _sessions, 'rate_limits_apagados', _rl);
END;
$$;
REVOKE ALL ON FUNCTION public.maintenance_hourly() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.maintenance_hourly() TO service_role;

-- Para a página /conta.
CREATE OR REPLACE FUNCTION public.my_usage()
RETURNS TABLE(plan text, subscription_status text, trial_ends_at timestamptz,
              identify_month integer, identify_today integer, chat_today integer)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public' AS $$
  WITH me AS (SELECT auth.uid() AS uid, (now() AT TIME ZONE 'UTC')::date AS today)
  SELECT public.user_plan(me.uid), p.subscription_status, p.trial_ends_at,
    COALESCE((SELECT sum(u.count) FROM public.ai_usage u WHERE u.user_id = me.uid AND u.kind = 'identify'
              AND u.day >= date_trunc('month', me.today)::date), 0)::int,
    COALESCE((SELECT sum(u.count) FROM public.ai_usage u WHERE u.user_id = me.uid AND u.kind = 'identify'
              AND u.day = me.today), 0)::int,
    COALESCE((SELECT sum(u.count) FROM public.ai_usage u WHERE u.user_id = me.uid AND u.kind = 'chat'
              AND u.day = me.today), 0)::int
  FROM me LEFT JOIN public.profiles p ON p.user_id = me.uid
  WHERE me.uid IS NOT NULL;
$$;
REVOKE ALL ON FUNCTION public.my_usage() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.my_usage() TO authenticated, service_role;

-- Gatilho no cadastro (pode não ter permissão; aí o perfil nasce na 1ª chamada ao servidor).
DO $$
BEGIN
  EXECUTE 'DROP TRIGGER IF EXISTS on_auth_user_created_profile ON auth.users';
  EXECUTE 'CREATE TRIGGER on_auth_user_created_profile AFTER INSERT ON auth.users
           FOR EACH ROW EXECUTE FUNCTION public.handle_new_user_profile()';
EXCEPTION WHEN insufficient_privilege THEN
  RAISE WARNING 'sem permissão para gatilho em auth.users';
END $$;

SELECT cron.schedule('maintenance-hourly', '7 * * * *', 'SELECT public.maintenance_hourly()');


-- ═══ P5: excluir a conta apaga tudo (LGPD) ═══════════════════════════════
-- 5 tabelas não tinham chave estrangeira para auth.users: apagar a conta
-- deixava conversas, mensagens, lembretes e uso para trás. Testado com
-- rollback: usuário com 1 conversa e 5 mensagens → tudo apagado.
DO $$
DECLARE t text; orf bigint;
BEGIN
  FOREACH t IN ARRAY ARRAY['ai_usage','plant_chats','plant_messages','reminders','push_subscriptions'] LOOP
    IF NOT EXISTS (
      SELECT 1 FROM pg_constraint con
      WHERE con.conrelid = ('public.' || t)::regclass AND con.contype = 'f' AND con.confrelid = 'auth.users'::regclass
    ) THEN
      EXECUTE format('ALTER TABLE public.%I ADD CONSTRAINT %I FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE NOT VALID',
                     t, t || '_user_id_fkey');
    END IF;
    EXECUTE format('SELECT count(*) FROM public.%I x WHERE NOT EXISTS (SELECT 1 FROM auth.users u WHERE u.id = x.user_id)', t) INTO orf;
    IF orf = 0 THEN
      EXECUTE format('ALTER TABLE public.%I VALIDATE CONSTRAINT %I', t, t || '_user_id_fkey');
    END IF;
  END LOOP;
END $$;

-- ═══ P6: lembretes ════════════════════════════════════════════════════════
-- (a) criado depois do horário de hoje não dispara na hora; (b) só Pro recebe
-- (quem saiu do teste fica pausado, sem perder o lembrete); (c) teto de 50.
-- Testado com rollback: a=ok, b=ok, grátis 0 enviados, Pro 2, barrou no 51º.
CREATE OR REPLACE FUNCTION public.reminders_before_insert()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $$
DECLARE _n int;
BEGIN
  SELECT count(*) INTO _n FROM public.reminders WHERE user_id = NEW.user_id;
  IF _n >= 50 THEN
    RAISE EXCEPTION 'Limite de 50 lembretes por conta.' USING ERRCODE = 'check_violation';
  END IF;
  BEGIN
    IF NEW.last_sent_at IS NULL
       AND (now() AT TIME ZONE COALESCE(NULLIF(NEW.timezone, ''), 'UTC'))::time >= (NEW.time || ':00')::time THEN
      NEW.last_sent_at := now();
    END IF;
  EXCEPTION WHEN OTHERS THEN
    NULL;
  END;
  RETURN NEW;
END;
$$;
REVOKE ALL ON FUNCTION public.reminders_before_insert() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.reminders_before_insert() TO authenticated, service_role;
DROP TRIGGER IF EXISTS reminders_before_insert ON public.reminders;
CREATE TRIGGER reminders_before_insert BEFORE INSERT ON public.reminders
  FOR EACH ROW EXECUTE FUNCTION public.reminders_before_insert();

CREATE OR REPLACE FUNCTION public.claim_due_reminders()
RETURNS TABLE(id uuid, user_id uuid, name text, amount text, plant_key text)
LANGUAGE sql SECURITY DEFINER SET search_path TO 'public' AS $$
  WITH due AS (
    SELECT r.id
    FROM public.reminders r
    WHERE r.enabled
      AND public.user_plan(r.user_id) = 'pro'
      AND (now() AT TIME ZONE COALESCE(NULLIF(r.timezone, ''), 'UTC'))::time >= (r.time || ':00')::time
      AND (
        r.last_sent_at IS NULL
        OR (
          (now() AT TIME ZONE COALESCE(NULLIF(r.timezone, ''), 'UTC'))::date
          - (r.last_sent_at AT TIME ZONE COALESCE(NULLIF(r.timezone, ''), 'UTC'))::date
        ) >= GREATEST(1, COALESCE(NULLIF(regexp_replace(r.freq, '\D', '', 'g'), '')::int, 1))
      )
    FOR UPDATE SKIP LOCKED
  )
  UPDATE public.reminders AS t
  SET last_sent_at = now()
  WHERE t.id IN (SELECT due.id FROM due)
  RETURNING t.id, t.user_id, t.name, t.amount, t.plant_key;
$$;

-- ═══ P7: tetos de tamanho e de correções por dia ═══════════════════════════
-- Testado com rollback: mensagem de 5000 letras barrada, normal passa,
-- 31ª correção do dia barrada; os 5 limites validados nas linhas antigas.
DO $$
DECLARE c record;
BEGIN
  FOR c IN SELECT * FROM (VALUES
    ('plant_messages',     'plant_messages_content_len', 'length(content) <= 4000'),
    ('plant_corrections',  'plant_corrections_len',      'length(corrected_sci) <= 200 AND coalesce(length(suggested_sci),0) <= 200 AND coalesce(length(corrected_name),0) <= 200 AND coalesce(length(suggested_name),0) <= 200 AND length(kind) <= 40 AND coalesce(length(organ),0) <= 20'),
    ('reminders',          'reminders_len',              'length(name) <= 120 AND length(amount) <= 60 AND length(freq) <= 4 AND length(freq_label) <= 40 AND time ~ ''^[0-2][0-9]:[0-5][0-9]$'' AND coalesce(length(img),0) <= 2000 AND length(plant_key) <= 200 AND length(timezone) <= 64'),
    ('plant_chats',        'plant_chats_len',            'length(plant_key) <= 200 AND octet_length(plant::text) <= 100000'),
    ('push_subscriptions', 'push_subscriptions_len',     'length(endpoint) <= 1000 AND length(p256dh) <= 200 AND length(auth) <= 100')
  ) AS t(tbl, con, expr)
  LOOP
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = c.con) THEN
      EXECUTE format('ALTER TABLE public.%I ADD CONSTRAINT %I CHECK (%s) NOT VALID', c.tbl, c.con, c.expr);
    END IF;
    BEGIN
      EXECUTE format('ALTER TABLE public.%I VALIDATE CONSTRAINT %I', c.tbl, c.con);
    EXCEPTION WHEN check_violation THEN
      RAISE WARNING 'linhas antigas fora do limite em %', c.tbl;
    END;
  END LOOP;
END $$;

CREATE OR REPLACE FUNCTION public.plant_corrections_rate()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $$
BEGIN
  IF (SELECT count(*) FROM public.plant_corrections
      WHERE user_id = NEW.user_id AND created_at > now() - interval '1 day') >= 30 THEN
    RAISE EXCEPTION 'Limite de correções por dia atingido.' USING ERRCODE = 'check_violation';
  END IF;
  RETURN NEW;
END;
$$;
REVOKE ALL ON FUNCTION public.plant_corrections_rate() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.plant_corrections_rate() TO authenticated, service_role;
DROP TRIGGER IF EXISTS plant_corrections_rate ON public.plant_corrections;
CREATE TRIGGER plant_corrections_rate BEFORE INSERT ON public.plant_corrections
  FOR EACH ROW EXECUTE FUNCTION public.plant_corrections_rate();

-- ═══ Conferência final: tabelas internas sem permissão de visitante ═══════
-- RLS já bloqueava (sem política), mas o privilégio de tabela também sai.
-- Resultado da conferência geral depois disto: nenhuma tabela sem RLS, nenhuma
-- função SECURITY DEFINER aberta para anon, nenhuma função sem search_path,
-- nenhuma tabela legível por anon sem política. Fica só o aviso de pg_net no
-- schema public (instalado pela plataforma; mover quebraria o cron).
REVOKE ALL ON public.ai_usage, public.rate_limits FROM PUBLIC, anon, authenticated;
GRANT ALL ON public.ai_usage, public.rate_limits TO service_role;
