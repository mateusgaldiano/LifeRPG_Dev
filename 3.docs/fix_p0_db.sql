-- ==========================================================================
-- P0 — Correções de banco (rodar no Supabase -> SQL Editor)
-- Cobre: SEG-002 (auditoria RLS), BUG-002 (chat global), BUG-004 (pg_cron duelos)
-- Idempotente. Leia os comentários antes de rodar cada bloco.
-- ==========================================================================


-- ──────────────────────────────────────────────────────────────────────────
-- SEG-002 · AUDITORIA DE RLS (diagnóstico — NÃO altera nada)
-- Rode este SELECT primeiro. Tabelas com rls_ativo = false OU qtd_policies = 0
-- estão expostas (ou serão bloqueadas se ativar RLS sem policy).
-- ──────────────────────────────────────────────────────────────────────────
SELECT t.tablename,
       t.rowsecurity                AS rls_ativo,
       COUNT(p.policyname)          AS qtd_policies
FROM pg_tables t
LEFT JOIN pg_policies p
  ON p.schemaname = t.schemaname AND p.tablename = t.tablename
WHERE t.schemaname = 'public'
GROUP BY t.tablename, t.rowsecurity
ORDER BY t.rowsecurity ASC, qtd_policies ASC, t.tablename;

-- AVISO: ativar RLS numa tabela SEM policy bloqueia TODO acesso direto (.from()).
-- RPCs SECURITY DEFINER (ex: sync_user_state_secure) continuam funcionando.
-- Só ative RLS em tabelas que já tenham policy. Template de remediação por tabela:
--
--   ALTER TABLE <tabela> ENABLE ROW LEVEL SECURITY;
--   CREATE POLICY "<tabela>_select_own" ON <tabela> FOR SELECT TO authenticated
--     USING (user_id IN (SELECT id FROM users WHERE person_id = auth.uid()));
--
-- Ajuste a coluna de dono (user_id / person_id) conforme a tabela.


-- ──────────────────────────────────────────────────────────────────────────
-- BUG-002 · CHAT GLOBAL — reaplica RLS, policies e publicação Realtime
-- Resolve "mensagens não aparecem" quando o comunidade_schema.sql não foi
-- aplicado por completo. Reproduz exatamente as policies originais.
-- ──────────────────────────────────────────────────────────────────────────
ALTER TABLE chat_messages ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Leitura do chat global" ON chat_messages;
CREATE POLICY "Leitura do chat global"
  ON chat_messages FOR SELECT
  USING (channel = 'global');

DROP POLICY IF EXISTS "Postagem no chat global" ON chat_messages;
CREATE POLICY "Postagem no chat global"
  ON chat_messages FOR INSERT
  WITH CHECK (
    channel = 'global'
    AND user_id IN (SELECT id FROM users WHERE person_id = auth.uid())
  );

-- Garante que a tabela está na publicação Realtime (sem duplicar).
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND tablename = 'chat_messages'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE chat_messages;
  END IF;
END $$;


-- ──────────────────────────────────────────────────────────────────────────
-- BUG-004 · pg_cron — finalização automática de duelos PvP a cada 6h
-- Pré-requisitos:
--   1. Extensão pg_cron habilitada (Dashboard -> Database -> Extensions -> pg_cron)
--   2. Função check_and_finalize_duels já criada (rode 3.docs/pvp_duels.sql)
-- ──────────────────────────────────────────────────────────────────────────
DO $$
BEGIN
  -- pg_cron disponível?
  IF NOT EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
    RAISE NOTICE 'pg_cron NAO habilitado. Ative em Database -> Extensions e rode de novo.';
    RETURN;
  END IF;

  -- função existe?
  IF NOT EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'check_and_finalize_duels') THEN
    RAISE NOTICE 'Funcao check_and_finalize_duels NAO existe. Rode 3.docs/pvp_duels.sql antes.';
    RETURN;
  END IF;

  -- remove agendamento antigo (se houver) e recria
  IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'check-duels') THEN
    PERFORM cron.unschedule('check-duels');
  END IF;

  PERFORM cron.schedule('check-duels', '0 */6 * * *', 'SELECT check_and_finalize_duels();');
  RAISE NOTICE 'Job check-duels agendado a cada 6h.';
END $$;

-- Conferir o agendamento:
--   SELECT jobname, schedule, command FROM cron.job WHERE jobname = 'check-duels';
