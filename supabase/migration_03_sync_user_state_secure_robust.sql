-- ============================================================================
-- SQL 3 — Atualização robusta da função sync_user_state_secure
-- Rode este script no SQL Editor do Supabase Dashboard
-- ============================================================================

-- 1. Dropar qualquer versão anterior da função para garantir que não haja conflitos de assinaturas
DROP FUNCTION IF EXISTS sync_user_state_secure(TEXT, INT, INT, INT, INT, TEXT, TEXT, TEXT, JSONB, JSONB);

-- 2. Recriar a função com parâmetros robustos (defaults) e COALESCE nos campos opcionais/not-null
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
  -- Obter o ID do usuário e o estado atual correspondente ao auth.uid() do Supabase Auth
  SELECT id, level, xp, gold, streak 
  INTO v_user_id, v_current_level, v_current_xp, v_current_gold, v_current_streak
  FROM users
  WHERE person_id = auth.uid();

  IF v_user_id IS NULL THEN
    RAISE EXCEPTION '[VAL_ERR_USER_NOT_FOUND] Perfil de usuário correspondente ao auth.uid() não encontrado.';
  END IF;

  -- ── VALIDAÇÃO 1: SANITIZAÇÃO E VALIDAÇÃO DE USERNAME
  -- Se p_username for nulo, pulamos a validação (o COALESCE manterá o nome existente)
  IF p_username IS NOT NULL AND (length(p_username) > 30 OR p_username !~ '^[a-zA-Z0-9 _áéíóúâêîôûãõçÁÉÍÓÚÂÊÎÔÛÃÕÇ-]+$') THEN
    RAISE EXCEPTION '[VAL_ERR_INVALID_USERNAME] Username inválido. Deve ter no máximo 30 caracteres e conter apenas letras, números e caracteres especiais básicos.';
  END IF;

  -- ── VALIDAÇÃO 2: REGRESSÃO DE NÍVEL
  IF p_level < v_current_level THEN
    RAISE EXCEPTION '[VAL_ERR_LEVEL_REGRESSION] O nível não pode regredir. Atual no banco: %, Enviado: %', v_current_level, p_level;
  END IF;

  -- ── VALIDAÇÃO 3: CONSISTÊNCIA DE XP
  v_xp_needed := round(100 * (p_level::double precision ^ 1.5))::int;
  IF p_xp >= v_xp_needed AND p_level < 30 THEN
    RAISE EXCEPTION '[VAL_ERR_XP_OVERFLOW] XP enviado (%) é maior ou igual ao limite de subida (%) para o nível %.', p_xp, v_xp_needed, p_level;
  END IF;

  -- ── VALIDAÇÃO 5: VALORES NEGATIVOS
  IF p_gold < 0 THEN
    RAISE EXCEPTION '[VAL_ERR_NEGATIVE_GOLD] Ouro não pode ser negativo.';
  END IF;
  IF p_xp < 0 THEN
    RAISE EXCEPTION '[VAL_ERR_NEGATIVE_XP] XP não pode ser negativo.';
  END IF;

  -- ── VALIDAÇÃO 6: CONSISTÊNCIA DE RANK OBRIGATÓRIA POR FAIXA
  -- Faixas: 1-2 -> CANDIDATO | 3-4 -> E | 5-9 -> D | 10-14 -> C | 15-19 -> B | 20-24 -> S | 25-29 -> NACIONAL | 30-34 -> GOVERNANTE | 35+ -> MONARCA
  IF (p_level >= 35 AND p_rank <> 'MONARCA') OR
     (p_level >= 30 AND p_level < 35 AND p_rank <> 'GOVERNANTE') OR
     (p_level >= 25 AND p_level < 30 AND p_rank <> 'NACIONAL') OR
     (p_level >= 20 AND p_level < 25 AND p_rank <> 'S') OR
     (p_level >= 15 AND p_level < 20 AND p_rank <> 'B') OR
     (p_level >= 10 AND p_level < 15 AND p_rank <> 'C') OR
     (p_level >= 5 AND p_level < 10 AND p_rank <> 'D') OR
     (p_level >= 3 AND p_level < 5 AND p_rank <> 'E') OR
     (p_level < 3 AND p_rank <> 'CANDIDATO') THEN
    RAISE EXCEPTION '[VAL_ERR_INVALID_RANK] Rank "%" inválido para o nível %.', p_rank, p_level;
  END IF;

  -- ── VALIDAÇÃO 7: LIMITE FIXO DE GANHO DE RECURSOS (MÁX +2.000 GOLD E +2.000 XP)
  
  -- A. Validação de Ganho de Ouro (Máximo de +2.000 Ouro por sync)
  IF (p_gold - v_current_gold) > 2000 THEN
    RAISE EXCEPTION '[VAL_ERR_GOLD_LIMIT_EXCEEDED] Ganho de Ouro (%) excede o limite fixo de 2000 por sync.', (p_gold - v_current_gold);
  END IF;

  -- B. Validação de Ganho de XP (Máximo de +2.000 XP por sync)
  -- Calcula XP total acumulado do nível 1 até o nível antigo
  FOR i IN 1..(v_current_level - 1) LOOP
    v_xp_total_old := v_xp_total_old + round(100 * (i::double precision ^ 1.5))::int;
  END LOOP;
  v_xp_total_old := v_xp_total_old + v_current_xp;

  -- Calcula XP total acumulado do nível 1 até o novo nível
  FOR i IN 1..(p_level - 1) LOOP
    v_xp_total_new := v_xp_total_new + round(100 * (i::double precision ^ 1.5))::int;
  END LOOP;
  v_xp_total_new := v_xp_total_new + p_xp;

  IF (v_xp_total_new - v_xp_total_old) > 2000 THEN
    RAISE EXCEPTION '[VAL_ERR_XP_LIMIT_EXCEEDED] Ganho de XP (%) excede o limite fixo de 2000 por sync.', (v_xp_total_new - v_xp_total_old);
  END IF;

  -- 3. Atualização no banco (SECURITY DEFINER ignora a falta de RLS de UPDATE)
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

END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4. Notificar o PostgREST para recarregar o schema cache imediatamente
NOTIFY pgrst, 'reload schema';
