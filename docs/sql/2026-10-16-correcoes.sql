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
