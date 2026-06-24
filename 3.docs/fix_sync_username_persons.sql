-- ==========================================================================
-- FIX: "Could not find the function sync_user_state_secure in the schema cache"
-- + coluna username faltando em persons (migração de username)
--
-- Rode este script INTEIRO no Supabase → SQL Editor → New query → Run.
-- É idempotente: pode rodar mais de uma vez sem problema.
-- ==========================================================================

-- 1) Garante a coluna username em persons (lida pelo client após a migração).
--    Sem UNIQUE para não conflitar — a unicidade já é garantida por users.username.
ALTER TABLE persons ADD COLUMN IF NOT EXISTS username text;

-- 2) Backfill: copia o username já existente em users para persons,
--    para perfis criados antes da migração.
UPDATE persons p
SET username = u.username
FROM users u
WHERE u.person_id = p.id
  AND (p.username IS NULL OR p.username = '');

-- 3) Recria a função com a assinatura EXATA que o client chama (10 parâmetros).
--    Mantém todas as validações originais e passa a gravar o username também
--    em persons (fonte de leitura do client após a migração).
CREATE OR REPLACE FUNCTION sync_user_state_secure(
  p_username TEXT DEFAULT NULL,
  p_level INT DEFAULT 1,
  p_xp INT DEFAULT 0,
  p_gold INT DEFAULT 0,
  p_streak INT DEFAULT 0,
  p_rank TEXT DEFAULT 'CANDIDATO',
  p_archetype TEXT DEFAULT NULL,
  p_active_skin TEXT DEFAULT 'default',
  p_skills JSONB DEFAULT '{}'::jsonb,
  p_settings JSONB DEFAULT '{}'::jsonb
) RETURNS VOID AS $$
DECLARE
  v_current_level INT;
  v_current_xp INT;
  v_current_gold INT;
  v_current_streak INT;
  v_user_id UUID;
  v_xp_needed INT;
  v_xp_total_old INT := 0;
  v_xp_total_new INT := 0;
  i INT;
BEGIN
  SELECT id, level, xp, gold, streak
  INTO v_user_id, v_current_level, v_current_xp, v_current_gold, v_current_streak
  FROM users
  WHERE person_id = auth.uid();

  IF v_user_id IS NULL THEN
    RAISE EXCEPTION '[VAL_ERR_USER_NOT_FOUND] Perfil de usuário correspondente ao auth.uid() não encontrado.';
  END IF;

  -- VALIDAÇÃO 1: REGRESSÃO DE NÍVEL
  IF p_level < v_current_level THEN
    RAISE EXCEPTION '[VAL_ERR_LEVEL_REGRESSION] O nível não pode regredir. Atual no banco: %, Enviado: %', v_current_level, p_level;
  END IF;

  -- VALIDAÇÃO 2: CONSISTÊNCIA DE XP
  v_xp_needed := round(100 * (p_level::double precision ^ 1.5))::int;
  IF p_xp >= v_xp_needed AND p_level < 30 THEN
    RAISE EXCEPTION '[VAL_ERR_XP_OVERFLOW] XP enviado (%) é maior ou igual ao limite de subida (%) para o nível %.', p_xp, v_xp_needed, p_level;
  END IF;

  -- VALIDAÇÃO 3: CONSISTÊNCIA DE RANK
  IF (p_level >= 20 AND p_rank <> 'S') OR
     (p_level >= 15 AND p_level < 20 AND p_rank <> 'A') OR
     (p_level >= 10 AND p_level < 15 AND p_rank <> 'B') OR
     (p_level >= 5 AND p_level < 10 AND p_rank <> 'C') OR
     (p_level >= 3 AND p_level < 5 AND p_rank <> 'D') OR
     (p_level < 3 AND p_rank <> 'E') THEN
    RAISE EXCEPTION '[VAL_ERR_INVALID_RANK] Rank "%" inválido para o nível %.', p_rank, p_level;
  END IF;

  -- VALIDAÇÃO 4: LIMITE FIXO DE GANHO DE RECURSOS
  IF (p_gold - v_current_gold) > 2000 THEN
    RAISE EXCEPTION '[VAL_ERR_GOLD_LIMIT_EXCEEDED] Ganho de Ouro (%) excede o limite fixo de 2000 por sync.', (p_gold - v_current_gold);
  END IF;

  FOR i IN 1..(v_current_level - 1) LOOP
    v_xp_total_old := v_xp_total_old + round(100 * (i::double precision ^ 1.5))::int;
  END LOOP;
  v_xp_total_old := v_xp_total_old + v_current_xp;

  FOR i IN 1..(p_level - 1) LOOP
    v_xp_total_new := v_xp_total_new + round(100 * (i::double precision ^ 1.5))::int;
  END LOOP;
  v_xp_total_new := v_xp_total_new + p_xp;

  IF (v_xp_total_new - v_xp_total_old) > 2000 THEN
    RAISE EXCEPTION '[VAL_ERR_XP_LIMIT_EXCEEDED] Ganho de XP (%) excede o limite fixo de 2000 por sync.', (v_xp_total_new - v_xp_total_old);
  END IF;

  -- ATUALIZAÇÃO SEGURA (SECURITY DEFINER ignora RLS de UPDATE)
  UPDATE users
  SET
    username = COALESCE(p_username, username),
    level = p_level,
    xp = p_xp,
    gold = p_gold,
    streak = p_streak,
    rank = p_rank,
    archetype = COALESCE(p_archetype, archetype),
    active_skin = p_active_skin,
    skills = p_skills,
    settings = p_settings,
    last_active_at = now()
  WHERE id = v_user_id;

  -- Sincroniza o username também em persons (fonte de leitura do client)
  IF p_username IS NOT NULL THEN
    UPDATE persons SET username = p_username WHERE id = auth.uid();
  END IF;

END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4) Força o PostgREST a recarregar o schema cache imediatamente.
--    (É isto que resolve o "Could not find the function ... in the schema cache".)
NOTIFY pgrst, 'reload schema';
