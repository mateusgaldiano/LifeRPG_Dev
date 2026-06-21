-- ==========================================================================
-- MIGRATION: Adicionar UNIQUE constraint em users.person_id
-- Execute no SQL Editor do Supabase Dashboard
-- Corrige o erro: "there is no unique or exclusion constraint matching
--                  the ON CONFLICT specification"
-- ==========================================================================

-- 1. Adicionar a constraint UNIQUE em person_id (caso não exista)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'users_person_id_key'
          AND conrelid = 'users'::regclass
    ) THEN
        ALTER TABLE users ADD CONSTRAINT users_person_id_key UNIQUE (person_id);
        RAISE NOTICE 'Constraint users_person_id_key criada com sucesso.';
    ELSE
        RAISE NOTICE 'Constraint users_person_id_key já existe. Nenhuma ação necessária.';
    END IF;
END $$;

-- 2. Verificar o resultado
SELECT conname, contype, pg_get_constraintdef(oid)
FROM pg_constraint
WHERE conrelid = 'users'::regclass
ORDER BY conname;
