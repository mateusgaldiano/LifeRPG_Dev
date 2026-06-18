-- ================================================================
-- LifeRPG OS v2.5 — Supabase Setup — NOTIFICAÇÕES PUSH REAIS
-- Execute no SQL Editor do Supabase Dashboard
-- ================================================================

-- ────────────────────────────────────────────────────────────────
-- 1. CORREÇÃO PRÉ-REQUISITO: RLS na Tabela `persons`
-- ────────────────────────────────────────────────────────────────
-- Garante que o fluxo de ensureUserProfile() não falhe com erros 403/409

-- Policy de INSERT: Usuário autenticado pode criar seu próprio registro
DROP POLICY IF EXISTS "persons_insert_own" ON persons;
CREATE POLICY "persons_insert_own" ON persons
  FOR INSERT WITH CHECK (auth.uid() = id);

-- Policy de SELECT: Usuário autenticado pode ler seu próprio registro
DROP POLICY IF EXISTS "persons_select_own" ON persons;
CREATE POLICY "persons_select_own" ON persons
  FOR SELECT USING (auth.uid() = id);

-- Policy de UPDATE: Usuário autenticado pode atualizar seu próprio registro
DROP POLICY IF EXISTS "persons_update_own" ON persons;
CREATE POLICY "persons_update_own" ON persons
  FOR UPDATE USING (auth.uid() = id) WITH CHECK (auth.uid() = id);


-- ────────────────────────────────────────────────────────────────
-- 2. CRIAÇÃO DA TABELA `push_subscriptions`
-- ────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS push_subscriptions (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    uuid REFERENCES users(id) ON DELETE CASCADE,
  endpoint   text NOT NULL,
  p256dh     text NOT NULL,
  auth       text NOT NULL,
  created_at timestamptz DEFAULT now(),
  UNIQUE(user_id, endpoint)
);

-- Índice para busca rápida de inscrições associadas ao usuário
CREATE INDEX IF NOT EXISTS idx_push_subscriptions_user_id 
  ON push_subscriptions(user_id);

-- Habilitar Row Level Security (RLS)
ALTER TABLE push_subscriptions ENABLE ROW LEVEL SECURITY;


-- ────────────────────────────────────────────────────────────────
-- 3. POLÍTICAS RLS PARA `push_subscriptions`
-- ────────────────────────────────────────────────────────────────

-- SELECT: Jogador só pode ver suas próprias inscrições
DROP POLICY IF EXISTS "select_own_subscriptions" ON push_subscriptions;
CREATE POLICY "select_own_subscriptions" ON push_subscriptions
  FOR SELECT USING (
    user_id IN (SELECT id FROM users WHERE person_id = auth.uid())
  );

-- INSERT: Jogador só pode inserir inscrições para si mesmo
DROP POLICY IF EXISTS "insert_own_subscriptions" ON push_subscriptions;
CREATE POLICY "insert_own_subscriptions" ON push_subscriptions
  FOR INSERT WITH CHECK (
    user_id IN (SELECT id FROM users WHERE person_id = auth.uid())
  );

-- DELETE: Jogador só pode deletar suas próprias inscrições
DROP POLICY IF EXISTS "delete_own_subscriptions" ON push_subscriptions;
CREATE POLICY "delete_own_subscriptions" ON push_subscriptions
  FOR DELETE USING (
    user_id IN (SELECT id FROM users WHERE person_id = auth.uid())
  );


-- ────────────────────────────────────────────────────────────────
-- 4. CONFIGURAÇÃO DE SEGREDOS NO SUPABASE CLI (Dashboard -> Secrets)
-- ────────────────────────────────────────────────────────────────
-- Execute localmente no terminal para definir a chave privada VAPID gerada:
-- supabase secrets set VAPID_PRIVATE_KEY="<VAPID_PRIVATE_KEY>"


-- ────────────────────────────────────────────────────────────────
-- 5. AGENDAMENTO DO TRIGGER DIÁRIO (pg_cron + pg_net)
-- ────────────────────────────────────────────────────────────────
-- Habilita as extensões necessárias
CREATE EXTENSION IF NOT EXISTS pg_cron;
CREATE EXTENSION IF NOT EXISTS pg_net;

-- Agendar tarefa diária às 21h30 (horário do servidor)
-- Executa um POST HTTP chamando a Edge Function send-push para disparar lembretes
-- Substitua a URL e a Service Role Key com os valores do seu projeto
SELECT cron.schedule(
  'lembrete-diario-quests-pendentes',
  '30 21 * * *',
  $$
  SELECT net.http_post(
    url := 'https://ppsqvppnunzagxqruoqf.supabase.co/functions/v1/send-push',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer <SUPABASE_SERVICE_ROLE_KEY>'
    ),
    body := jsonb_build_object(
      'action', 'trigger_all_reminders'
    )
  );
  $$
);
