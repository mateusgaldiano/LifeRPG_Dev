# LifeRPG OS — Pipeline de Pendências

> **Sincronizado automaticamente com `pipeline.html`.** Não editar à mão — editar o array `items` no HTML e ressincronizar.
> **Total: 37 itens pendentes.**

---

## 🔴 P0 — CRÍTICO (3)

### BUG-002 · Mensagens do chat global não aparecem ao enviar
**Cluster:** Bug Crítico | **Esforço:** S | **Tipo:** Bug | **Fase:** Agora

Usuário envia mensagem, ela não aparece no canal. Provável causa: falta de subscription ativa no canal Realtime ou RLS bloqueando SELECT na tabela de chat.

```
Ver 1.core/modules/social.js.
1. Abrir `1.core/modules/social.js` e localizar a função de envio de mensagem do chat global
2. Verificar se existe subscription ativa no canal Realtime de chat (procurar por `.channel(` ou `.on('postgres_changes'`)
3. Se subscription não existir: criar `supabase.channel('global-chat').on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'global_chat' }, callback).subscribe()`
4. No Supabase Dashboard → Authentication → Policies: confirmar que a tabela `global_chat` tem RLS policy de SELECT para usuários autenticados
5. Adicionar policy se ausente: `CREATE POLICY "Authenticated users can read chat" ON global_chat FOR SELECT TO authenticated USING (true);`
6. Testar: enviar mensagem e confirmar que aparece sem refresh
7. Commit: "fix: subscription Realtime no chat global + RLS policy de SELECT"
```

### UX-001 · Settings modal muito denso — fontes pequenas (feedback confirmado)
**Cluster:** UX/Visual | **Esforço:** M | **Tipo:** Enhancement | **Fase:** Agora

Modal de configurações identificado como inacessível. Escalonamento de fontes pendente.

```
Ver 1.core/styles.css.
1. Abrir `1.core/styles.css`
2. Localizar `body` e ajustar: `font-size: 15px; line-height: 1.5;`
3. Localizar `.quest-title` e ajustar: `font-size: 15px;`
4. Localizar `.quest-meta`, `.payout-xp`, `.payout-gold` e ajustar: `font-size: 11px;`
5. Localizar `.section-title h2` e ajustar: `font-size: 22px;`
6. Localizar `.player-name` e ajustar: `font-size: 16px;`
7. Localizar `.attr-bar-name` e ajustar: `font-size: 12px;`
8. Localizar `.settings-group-title` e ajustar: `font-size: 13px;`
9. Localizar `.settings-group-desc` e ajustar: `font-size: 12px;`
10. Localizar `label`, `.form-field label` e ajustar: `font-size: 12px;`
11. Localizar `.btn-submit` dentro do settings e ajustar: `font-size: 14px;`
12. No `#modal-settings`: condensar bloco de notificações — unificar Manhã/Noite em uma linha compacta lado a lado
13. Reduzir aviso de Hard Reset para 1 linha, diminuir padding do bloco
14. Testar no Dev em resolução 390px (iPhone 14)
15. Commit: "feat: escalonamento de fontes e simplificação do modal Settings"
```

### SEG-002 · Verificar RLS em todas as tabelas Supabase
**Cluster:** Segurança | **Esforço:** S | **Tipo:** Segurança | **Fase:** Agora

Confirmar que persons, users, inventory, pvp_duels, friendships, global_chat têm RLS ativo.

```
1. Acessar Supabase Dashboard → SQL Editor
2. Executar: SELECT tablename, rowsecurity FROM pg_tables WHERE schemaname = 'public' ORDER BY tablename;
3. Para cada tabela com rowsecurity = false: executar ALTER TABLE nome_tabela ENABLE ROW LEVEL SECURITY;
4. Verificar policies existentes: SELECT tablename, policyname, cmd FROM pg_policies WHERE schemaname = 'public';
5. Tabelas que devem ter RLS: persons, users, quests, history, items, inventory, analytics_events, pvp_duels, friendships, global_chat, weekly_reports
6. Garantir que cada tabela tem ao menos 1 policy para usuários autenticados
7. Documentar resultado em CLAUDE.md seção de segurança
8. Commit: "chore: habilitar RLS em todas as tabelas do schema public"
```

## 🟡 P1 — ALTO (20)

### PWA-001 · iOS Safari: virtual keyboard empurra chat UI
**Cluster:** Mobile & PWA | **Esforço:** M | **Tipo:** Bug | **Fase:** Próximas semanas

```
Ver 1.core/modules/social.js, 1.core/styles.css.
1. Abrir styles.css e localizar .modal-box-social ou o container do chat global
2. Substituir height: 90dvh por height: calc(100dvh - env(safe-area-inset-top) - env(safe-area-inset-bottom))
3. No input do chat (.chat-input-row), adicionar padding-bottom: env(safe-area-inset-bottom)
4. Em social.js, adicionar listener para visualViewport resize:
   if (window.visualViewport) {
     window.visualViewport.addEventListener('resize', () => {
       const chatBox = document.querySelector('.social-modal-body');
       if (chatBox) chatBox.style.height = window.visualViewport.height * 0.75 + 'px';
     });
   }
5. Testar no iPhone via BrowserStack ou dispositivo real: abrir chat, focar no input, confirmar que campo de input não é coberto pelo teclado
6. Commit: "fix: ajustar height do chat modal para visualViewport no iOS Safari"
```

### PWA-003 · Sem feedback de estado offline
**Cluster:** Mobile & PWA | **Esforço:** M | **Tipo:** Bug | **Fase:** Próximas semanas

```
1. Adicionar div no index.html logo após a abertura do body: <div id="offline-banner" class="offline-banner" style="display:none">⚡ MODO OFFLINE — dados serão sincronizados ao reconectar</div>
2. Em styles.css, criar .offline-banner: position fixed, top 0, width 100%, background #ef4444, color #fff, text-align center, padding 6px, font-size 12px, z-index 9999, font-family var(--font-hud), letter-spacing 1px
3. Em pwa.js, adicionar:
   window.addEventListener('offline', () => document.getElementById('offline-banner').style.display = 'block');
   window.addEventListener('online', () => { document.getElementById('offline-banner').style.display = 'none'; saveToCloud(); });
4. Commit: "feat: banner de modo offline + trigger de sync ao reconectar"
```

### ENG-001 · Imagens de avatar 1MB+ sem otimização
**Cluster:** Engenharia | **Esforço:** M | **Tipo:** Tech Debt | **Fase:** Próximas semanas

```
1. Instalar sharp ou squoosh CLI se disponível: npm install -g @squoosh/cli
2. Converter cada avatar PNG para WebP com qualidade 80: squoosh-cli --webp '{"quality":80}' 2.assets/avatars/*.png
3. Target: cada arquivo < 80KB
4. Atualizar referências no HTML: 2.assets/avatars/1.rank-e.png → 1.rank-e.webp
5. Adicionar fallback no HTML para browsers sem suporte WebP:
   <picture><source srcset="2.assets/avatars/1.rank-e.webp" type="image/webp"><img id="char-avatar-img" src="2.assets/avatars/1.rank-e.png" alt="Avatar"></picture>
6. Em ui.js, buscar todas as referências que atualizam o src do avatar e atualizar para .webp
7. Adicionar loading="lazy" no elemento <img id="char-avatar-img">
8. Commit: "perf: converter avatares para WebP e adicionar lazy loading"
```

### UX-002 · 3 colunas de quest muito estreitas em mobile
**Cluster:** UX/Visual | **Esforço:** M | **Tipo:** Enhancement | **Fase:** Próximas semanas

```
Ver 1.core/styles.css.
1. Abrir styles.css e localizar .quests-three-columns
2. Modificar para ser responsivo:
   @media (max-width: 640px) {
     .quests-three-columns {
       grid-template-columns: 1fr;
     }
     .quest-attr-column {
       display: none;
     }
     .quest-attr-column.active-mobile {
       display: block;
     }
   }
3. Em index.html, adicionar tabs de seleção de coluna para mobile (Vontade / Intelecto / Vitalidade) que aparecem apenas em mobile (display none em desktop)
4. Em ui.js, adicionar listener nos tabs mobile para alternar qual .quest-attr-column tem a classe active-mobile
5. Primeira coluna ativa por padrão no load mobile
6. Commit: "feat: layout responsivo de quests em mobile (1 coluna com tabs)"
```

### UX-003 · Toast messages do Iroh muito longas
**Cluster:** UX/Visual | **Esforço:** S | **Tipo:** Enhancement | **Fase:** Próximas semanas

```
Ver 1.core/modules/ui.js, 1.core/styles.css.
1. Em ui.js, localizar a função showSystemToast
2. Adicionar lógica de duração baseada em tamanho: const duration = msg.length > 120 ? 8000 : 4500;
3. Para toasts com mais de 200 caracteres (mensagens de penalidade severa do Iroh): abrir em modal próprio ao invés de toast
4. Criar função showIrohMessage(text) que abre um modal leve com o texto formatado e botão ENTENDIDO
5. Em game-logic.js, substituir os irohMessages de penalidade severa (tone === 'severe' e tone === 'angry') para chamar showIrohMessage em vez de showSystemToast
6. Commit: "feat: toasts longos do Iroh abrem em modal — melhora legibilidade"
```

### UX-004 · Level Up overlay não mostra o que desbloqueou
**Cluster:** UX/Visual | **Esforço:** M | **Tipo:** Enhancement | **Fase:** Próximas semanas

```
Ver 1.core/modules/ui.js, index.html.
1. Em ui.js, localizar a função triggerLevelUpOverlay
2. Após calcular o novo nível, buscar em ALL_HABITS_DATABASE os hábitos com minLevel === novoNivel
3. Buscar em BOSS_QUEST_BY_LEVEL se o novo nível ativa uma boss quest
4. Adicionar no overlay HTML (index.html) uma div #levelup-unlocks logo abaixo do .levelup-new-level
5. Injetar via JS: lista de novos hábitos + boss quest ativada (se houver) + próximo rank (se rank up)
6. Estilizar: fundo rgba(124,58,237,0.1), border roxa, padding 10px, font-size 12px
7. Commit: "feat: overlay de Level Up exibe hábitos desbloqueados e boss quest ativada"
```

### UX-005 · Radar chart sem labels nos vértices
**Cluster:** UX/Visual | **Esforço:** S | **Tipo:** Enhancement | **Fase:** Próximas semanas

```
Ver 1.core/modules/ui.js.
1. Em ui.js, localizar a função que renderiza o radar chart (skills-radar-chart canvas)
2. Após desenhar o hexágono preenchido, adicionar renderização de labels nos 6 vértices
3. Labels curtos: FÍS / MEN / FOC / SAB / ROT / CON
4. Posicionar via ctx.fillText() offset da extremidade de cada vértice (adicionar 8-12px além do raio máximo)
5. Font: 9px Inter, cor: var(--text-muted) → como hex literal (ex: #475569) pois canvas não aceita CSS vars
6. Adicionar tooltip no hover do canvas: ao detectar mouse próximo a um vértice, mostrar div tooltip com nome completo + nível
7. Commit: "feat: labels nos vértices do radar chart e tooltip no hover"
```

### UX-006 · Weekly Report com texto pequeno em mobile
**Cluster:** UX/Visual | **Esforço:** S | **Tipo:** Enhancement | **Fase:** Próximas semanas

```
Ver 1.core/styles.css.
1. Abrir styles.css e localizar estilos do .weekly-report-modal-box
2. Garantir font-size mínimo de 11px em todos os elementos internos do modal
3. No grid de dias (Perfeitos/Bons/Falhados), alterar de 3 colunas para 2 colunas em mobile:
   @media (max-width: 480px) { .weekly-report-modal-box .report-days-grid { grid-template-columns: 1fr 1fr; } }
4. Aumentar padding interno de 8px para 12px nos .report-stat-card
5. Taxa de Sobrevivência: aumentar font-size de 38px para 34px em mobile para caber melhor
6. Commit: "fix: legibilidade do Weekly Report em mobile — font sizes e grid responsivo"
```

### GAME-001 · Penalidade P0 muito punitiva para novos jogadores (< nível 10)
**Cluster:** Game Design | **Esforço:** S | **Tipo:** Feature | **Fase:** Próximas semanas

```
Ver 1.core/modules/game-logic.js.
1. Em game-logic.js, localizar a função applyDailyPenalty
2. Após determinar xpPenaltyPct, adicionar cap por nível:
   if (gameState.level < 10) {
     xpPenaltyPct = Math.min(xpPenaltyPct, 0.10); // cap 10% para iniciantes
     streakReset = misses >= 3 ? true : false; // streak só reseta com 3+ falhas para novatos
   }
3. Adicionar mensagem diferenciada do Iroh para tone 'severe' quando nível < 10 (mais encorajador, menos punitivo)
4. Commit: "game: cap de penalidade para jogadores nível < 10 — reduzir churn de novatos"
```

### GAME-002 · Buff Double XP sem indicador visual nos quest cards
**Cluster:** Game Design | **Esforço:** S | **Tipo:** Feature | **Fase:** Próximas semanas

```
1. Em ui.js, localizar a função renderQuests (que gera o HTML dos cards de quest)
2. Se gameState.buffs?.doubleXp === true: adicionar no card um badge pulsante "2x XP" acima do payout
3. Badge HTML: <span class="buff-active-badge double-xp-badge">⚡ 2x XP</span>
4. Em styles.css, criar .buff-active-badge: background rgba(251,191,36,0.15), border 1px solid #fbbf24, color #fbbf24, font-size 9px, padding 2px 6px, border-radius 3px, animation pulse 1.5s infinite
5. Fazer o mesmo para buffs.legendaryFocus: badge "x3 💰 GOLD" em amarelo-ouro
6. Commit: "feat: indicadores visuais de buffs ativos (Double XP, Legendary Focus) nos quest cards"
```

### GAME-003 · Daily reset sem countdown visível para o usuário
**Cluster:** Game Design | **Esforço:** S | **Tipo:** Feature | **Fase:** Próximas semanas

```
1. Adicionar elemento no header da aba Missões: <div id="reset-countdown" class="reset-countdown"></div>
2. Em ui.js, criar função updateResetCountdown() que calcula tempo até meia-noite local:
   const now = new Date(); const midnight = new Date(); midnight.setHours(24,0,0,0);
   const diff = midnight - now; const h = Math.floor(diff/3600000); const m = Math.floor((diff%3600000)/60000);
   document.getElementById('reset-countdown').textContent = `🔄 Reset em ${h}h ${m}m`;
3. Chamar updateResetCountdown() no boot e com setInterval a cada 60 segundos
4. Estilizar: font-size 11px, color var(--text-muted), font-family var(--font-hud), letter-spacing 1px
5. Commit: "feat: countdown de reset diário na aba de Missões"
```

### SOCIAL-001 · Friends: busca por prefixo ao invés de username exato
**Cluster:** Social | **Esforço:** M | **Tipo:** Feature | **Fase:** Próximas semanas

```
Ver 1.core/modules/social.js.
1. Em social.js, localizar a função de busca de amigos (provavelmente triggerFriendSearch ou similar)
2. Substituir query de busca exata por ILIKE:
   .from('persons').select('id, username, level, rank').ilike('username', `%${searchTerm}%`).limit(5)
3. Exibir resultados como lista de 5 cards com: avatar placeholder, username, nível e botão "ADICIONAR"
4. Commit: "feat: busca de amigos por prefixo (ILIKE) ao invés de username exato"
```

### SOCIAL-002 · Sem botão de desafio PvP no modal de perfil
**Cluster:** Social | **Esforço:** S | **Tipo:** Feature | **Fase:** Próximas semanas

```
1. Em index.html, localizar o modal #modal-player-profile
2. Adicionar antes do botão de amizade existente:
   <button id="btn-profile-pvp-challenge" class="btn-submit" style="width:100%;background:linear-gradient(90deg,#f59e0b,#fbbf24);color:#000;margin-bottom:8px;">⚔️ DESAFIAR PARA DUELO</button>
3. Em social.js, ao abrir o modal de perfil de outro jogador, salvar o ID do jogador em window._profileViewTarget
4. Adicionar listener no btn-profile-pvp-challenge: ao clicar, pré-preencher o modal #modal-pvp-challenge com window._profileViewTarget e abrir
5. Commit: "feat: botão de desafio PvP direto do modal de perfil do jogador"
```

### SEC-001 · Chat global: rate limit para evitar spam
**Cluster:** Segurança | **Esforço:** M | **Tipo:** Segurança | **Fase:** Próximas semanas

```
1. No Supabase SQL Editor, adicionar RLS policy de rate limit em global_chat:
   CREATE POLICY "Rate limit chat messages" ON global_chat FOR INSERT TO authenticated WITH CHECK (
     (SELECT COUNT(*) FROM global_chat WHERE user_id = auth.uid() AND created_at > NOW() - INTERVAL '1 minute') < 10
   );
2. Em social.js, adicionar debounce no botão de envio:
   let lastMsgTime = 0;
   btnSend.addEventListener('click', () => { if (Date.now() - lastMsgTime < 3000) { showToast('Aguarde 3 segundos entre mensagens'); return; } lastMsgTime = Date.now(); sendMessage(); });
3. Commit: "security: rate limit de 10 msgs/min no chat global via RLS + debounce 3s no frontend"
```

### MKT-002 · "Streak em risco" push notification às 22h
**Cluster:** Marketing | **Esforço:** M | **Tipo:** Feature | **Fase:** Próximas semanas

```
1. Criar Supabase Edge Function `send-streak-reminder` que:
   - Busca todos os users com push_subscription ativo que NÃO completaram nenhuma daily hoje
   - Envia push notification com payload: { title: '⚠️ LifeRPG — Streak em Risco', body: 'Seu streak de X dias não sobrevive à meia-noite sem uma missão.' }
2. No pg_cron, agendar: SELECT cron.schedule('streak-reminder', '0 22 * * *', $SELECT net.http_post(url := current_setting('app.edge_functions_url') || '/send-streak-reminder', headers := '{"Authorization": "Bearer " || current_setting("app.service_role_key")}')$);
3. Em pwa.js, garantir que push_subscription do usuário é salvo em uma tabela `push_subscriptions` ao se inscrever
4. Commit: "feat: push notification de streak em risco às 22h via Edge Function + pg_cron"
```

### A11Y-001 · Botões ✕/✓ com área de toque insuficiente em mobile
**Cluster:** Acessibilidade | **Esforço:** S | **Tipo:** Enhancement | **Fase:** Próximas semanas

```
Ver 1.core/styles.css.
1. Abrir styles.css e localizar estilos dos botões de completar/remover quest (✓ e ✕)
2. Garantir min-width: 44px; min-height: 44px; em todos os botões de ação dos quest cards
3. Se visualmente não couber 44px de botão, usar padding negativo:
   .btn-quest-complete { min-width: 44px; min-height: 44px; display: flex; align-items: center; justify-content: center; margin: -8px; padding: 8px; }
4. Verificar também os botões de + e - do contador de água: mesma regra de 44px
5. Commit: "a11y: aumentar área de toque dos botões de quest para mínimo 44x44px"
```

### A11Y-002 · Toasts e overlays sem ARIA
**Cluster:** Acessibilidade | **Esforço:** S | **Tipo:** Enhancement | **Fase:** Próximas semanas

```
1. Em index.html, localizar #toast-container e adicionar role="status" aria-live="polite" aria-atomic="true"
2. Localizar #level-up-overlay e adicionar role="dialog" aria-modal="true" aria-labelledby="levelup-title"
3. Localizar #quest-cleared-overlay e adicionar role="status" aria-live="assertive"
4. Localizar #penalty-overlay e adicionar role="alertdialog" aria-modal="true"
5. Em styles.css, adicionar @media (prefers-reduced-motion: reduce) { .levelup-flash, .quest-cleared-overlay, .flash-red-penalty { animation: none !important; transition: none !important; } }
6. Commit: "a11y: adicionar ARIA roles em toasts/overlays + respeitar prefers-reduced-motion"
```

### ONBOARD-001 · Wizard: adicionar 3ª opção de gênero + mover para após o nome
**Cluster:** Onboarding | **Esforço:** S | **Tipo:** Enhancement | **Fase:** Próximas semanas

```
Ver index.html, 1.core/modules/app.js.
1. Em index.html, localizar #wizard-step-0 (seleção de gênero)
2. Adicionar terceiro card: <div class="gender-card" id="btn-gender-neutral" data-gender="neutral"><div style="font-size: 3.5rem; margin-bottom: 10px;">⚡</div><strong>Neutro</strong></div>
3. No app.js/pwa.js, adicionar data-gender="neutral" ao handler de seleção existente
4. Alterar a ordem dos steps: mover step de gênero para APÓS step-1 (nome do jogador)
5. Update lógica de navegação entre steps (back/next buttons)
6. Commit: "feat: adicionar opção de gênero neutro no onboarding + reordenar step para após nome"
```

### ONBOARD-002 · Hook habit do onboarding personalizado por archetype
**Cluster:** Onboarding | **Esforço:** M | **Tipo:** Enhancement | **Fase:** Próximas semanas

```
Ver 1.core/modules/game-logic.js ou app.js.
1. Criar mapa de archetype → hábitos sugeridos:
   const ARCHETYPE_HABITS = {
     corpo: [{ title: 'Treinar 20 minutos', skill: 'physical', xp: 30, gold: 15 }, { title: 'Beber 2L de água', skill: 'physical', xp: 20, gold: 10 }, { title: 'Caminhar 30 minutos', skill: 'physical', xp: 25, gold: 12 }],
     foco: [{ title: 'Trabalhar em bloco de 25 minutos (Pomodoro)', skill: 'productivity', xp: 30, gold: 15 }, { title: 'Planejar o dia em 5 minutos', skill: 'routine', xp: 15, gold: 8 }, { title: 'Ler 15 páginas', skill: 'wisdom', xp: 25, gold: 12 }],
     zen: [{ title: 'Meditar por 5 minutos', skill: 'mental', xp: 20, gold: 10 }, { title: 'Journaling — 3 gratidões', skill: 'wisdom', xp: 15, gold: 8 }, { title: 'Sem tela 30min antes de dormir', skill: 'routine', xp: 20, gold: 10 }],
     rotina: [{ title: 'Dormir antes das 23h', skill: 'routine', xp: 20, gold: 10 }, { title: 'Acordar no horário planejado', skill: 'routine', xp: 25, gold: 12 }, { title: 'Refeições sem tela', skill: 'routine', xp: 15, gold: 8 }],
     outros: [{ title: 'Completar 1 tarefa importante', skill: 'productivity', xp: 30, gold: 15 }]
   };
2. No wizard-step-hook, ao invés de hábito único hardcoded: renderizar os 3 hábitos do archetype selecionado como cards clicáveis
3. Usuário seleciona 1, que é salvo como primeira daily ao finalizar o wizard
4. Commit: "feat: hook habits do onboarding personalizados por archetype — 3 opções por tipo"
```

### META-001 · Novos achievements — expandir catálogo
**Cluster:** Meta-Progressão | **Esforço:** M | **Tipo:** Feature | **Fase:** Próximas semanas

```
Ver 1.core/modules/game-logic.js.
1. Em game-logic.js, localizar o array ACHIEVEMENTS_DEFS
2. Adicionar os seguintes achievements ao array:
   { id: 'quests_5_day', title: 'Dia Lendário', desc: 'Complete 5 missões em um único dia', icon: '🔥', rewardGold: 30, rarity: 'raro', check: (gs) => (gs._maxDailyCompleted || 0) >= 5, progress: (gs) => ({ cur: Math.min(gs._maxDailyCompleted || 0, 5), max: 5 }) },
   { id: 'quests_50_total', title: 'Veterano', desc: 'Complete 50 missões no total', icon: '⚔️', rewardGold: 80, rarity: 'raro', check: (gs) => (gs._totalQuestsCompleted || 0) >= 50, progress: (gs) => ({ cur: Math.min(gs._totalQuestsCompleted || 0, 50), max: 50 }) },
   { id: 'quests_100_total', title: 'Lenda', desc: 'Complete 100 missões no total', icon: '👑', rewardGold: 200, rarity: 'lendário', check: (gs) => (gs._totalQuestsCompleted || 0) >= 100, progress: (gs) => ({ cur: Math.min(gs._totalQuestsCompleted || 0, 100), max: 100 }) },
   { id: 'pvp_first_win', title: 'Gladiador', desc: 'Vença seu primeiro duelo PvP', icon: '🏆', rewardGold: 100, rarity: 'raro', check: (gs) => (gs._pvpWins || 0) >= 1, progress: (gs) => ({ cur: Math.min(gs._pvpWins || 0, 1), max: 1 }) },
   { id: 'friends_3', title: 'Aliança', desc: 'Tenha 3 amigos no sistema', icon: '🤝', rewardGold: 50, rarity: 'incomum', check: (gs) => (gs._friendsCount || 0) >= 3, progress: (gs) => ({ cur: Math.min(gs._friendsCount || 0, 3), max: 3 }) }
3. Em toggleQuest, incrementar gs._totalQuestsCompleted++ ao completar qualquer quest
4. Commit: "feat: 5 novos achievements — Dia Lendário, Veterano, Lenda, Gladiador, Aliança"
```

## 🟣 P2 — MÉDIO (7)

### GAME-004 · Comeback mechanic para usuários que voltam após 7+ dias
**Cluster:** Game Design | **Esforço:** M | **Tipo:** Feature | **Fase:** Próximas semanas

```
1. Em state.js ou app.js, no boot do app, calcular dias desde last_active
2. Se days_absent >= 7: ativar flag gameState._comebackMode = true por 3 dias
3. Em game-logic.js, em addRewards(): se _comebackMode === true, multiplicar XP por 1.5
4. Mensagem especial do Iroh ao detectar retorno longo
5. Commit: "feat: Modo Retorno — 1.5x XP por 3 dias após ausência de 7+ dias"
```

### ENG-002 · social.js: lazy loading ao abrir o modal Social
**Cluster:** Engenharia | **Esforço:** M | **Tipo:** Tech Debt | **Fase:** Próximas semanas

```
1. Em app.js, no evento de clique do botão #btn-header-social:
   const { initSocial } = await import('./modules/social.js');
   initSocial();
2. Remover import estático de social.js no topo de app.js
3. Garantir que a referência ao modal social funciona após import dinâmico
4. Commit: "perf: lazy load do módulo social.js — import dinâmico ao abrir modal"
```

### GAME-005 · Dungeon pool: expandir para 20+ missões com raridade
**Cluster:** Meta-Progressão | **Esforço:** M | **Tipo:** Feature | **Fase:** Próximas semanas

```
Ver 1.core/modules/state.js.
1. Em state.js, localizar DUNGEON_POOL
2. Expandir para pelo menos 20 entradas cobrindo todos os 6 skills
3. Adicionar campo rarity: 'comum' | 'raro' | 'épico' com multiplicadores de recompensa 1x / 1.5x / 2.5x
4. Épico: chance de 10%, Raro: 25%, Comum: 65%
5. Em game-logic.js, spawnDungeon(): usar Math.random() para determinar raridade e aplicar multiplicador de recompensa
6. Commit: "feat: expandir dungeon pool para 20+ missões com sistema de raridade"
```

### A11Y-003 · Radar chart com descrição para screen readers
**Cluster:** Acessibilidade | **Esforço:** S | **Tipo:** Enhancement | **Fase:** Próximas semanas

```
1. Em index.html, adicionar após o canvas do radar: <div class="sr-only" id="radar-description" aria-live="polite"></div>
2. Em ui.js, após renderizar o radar, injetar texto: "Atributos: Força de Vontade nível X, Intelecto nível Y, ..."
3. Adicionar aria-labelledby="radar-description" no canvas
4. Commit: "a11y: descrição de texto para o radar chart — acessibilidade screen readers"
```

### MKT-003 · Weekly Report: botão de compartilhar
**Cluster:** Marketing | **Esforço:** M | **Tipo:** Feature | **Fase:** Próximas semanas

```
Ver 1.core/modules/weekly-report.js, index.html.
1. Em index.html, adicionar botão no modal-weekly-report: <button id="btn-share-report" class="btn-submit btn-secondary" style="width:100%;margin-top:8px;">📤 COMPARTILHAR RELATÓRIO</button>
2. Em weekly-report.js, no listener do btn-share-report:
   - Usar html2canvas (importar do CDN) para capturar o modal como imagem
   - Se Web Share API disponível: navigator.share({ files: [imageFile], title: 'Meu Relatório LifeRPG' })
   - Fallback: download direto da imagem
3. Commit: "feat: botão de compartilhar relatório semanal como imagem"
```

### SEC-003 · Presença Supabase: configurar heartbeat e expiração de sessões zombie
**Cluster:** Segurança | **Esforço:** S | **Tipo:** Segurança | **Fase:** Próximas semanas

```
Ver 1.core/modules/social.js.
1. Em social.js, localizar initPresence() ou o código de channel Presence
2. Ao criar o canal Presence, configurar: { config: { presence: { key: userId }, heartbeat_interval_ms: 30000 } }
3. Adicionar limpeza no evento beforeunload: window.addEventListener('beforeunload', () => presenceChannel.untrack())
4. Commit: "fix: heartbeat de 30s e cleanup de presença ao fechar o app"
```

### ONBOARD-003 · Prompt de instalação PWA no final do onboarding
**Cluster:** Onboarding | **Esforço:** S | **Tipo:** Enhancement | **Fase:** Próximas semanas

```
1. Em app.js ou pwa.js, capturar o evento beforeinstallprompt: let deferredPrompt; window.addEventListener('beforeinstallprompt', (e) => { e.preventDefault(); deferredPrompt = e; });
2. No wizard step final (btn-wizard-finish), após completar o onboarding:
   if (deferredPrompt) { const step = document.getElementById('wizard-step-install'); if (step) step.style.display = 'block'; }
3. Adicionar step extra no wizard (wizard-step-install) com texto "📱 Instale o app para a experiência completa" e botão INSTALAR que chama deferredPrompt.prompt()
4. Commit: "feat: prompt de instalação PWA ao final do onboarding wizard"
```

## ⚪ P3 — FUTURO (7)

### ENG-003 · styles.css: PurgeCSS e minificação para produção
**Cluster:** Engenharia | **Esforço:** M | **Tipo:** Tech Debt | **Fase:** Futuro

```
1. Configurar build script com PurgeCSS: npx purgecss --css 1.core/styles.css --content index.html 1.core/**/*.js --output 1.core/styles.min.css
2. Atualizar link no index.html para styles.min.css em produção
3. Target: reduzir de 110KB para < 40KB gzipped
4. Commit: "perf: PurgeCSS no pipeline de produção — remover CSS não utilizado"
```

### GAME-007 · Prestige system após Rank S (nível 30)
**Cluster:** Meta-Progressão | **Esforço:** L | **Tipo:** Feature | **Fase:** Futuro

```
1. Definir mecânica: ao atingir nível 30, opção de "Ascender" — reseta XP para 0 mas mantém hábitos e conquistas
2. Adicionar campo gameState.prestige_level (inicia em 0)
3. Benefício do prestige: +5% multiplicador permanente de XP por nível de prestige (max 3)
4. Avatar especial dourado para prestige 1+ com borda especial automática
5. Commit: "feat: Prestige system — progressão além do Rank S"
```

### FEAT-001 · Aba MENTOR (Tio Iroh IA via Claude API) — desabilitar display:none
**Cluster:** Meta-Progressão | **Esforço:** XL | **Tipo:** Feature | **Fase:** Futuro

```
1. Criar Supabase Edge Function `mentor-chat` que recebe { message, gameState_summary } e chama Claude API
2. System prompt: persona do Tio Iroh com contexto do gameState do jogador (nível, streak, skills, missão atual)
3. Em index.html: remover style="display:none" da <section id="tab-chat">
4. Adicionar botão da aba Mentor na nav: <button class="tab-link" data-tab="chat">🎓 MENTOR</button>
5. Em ui.js, criar função sendMentorMessage() que chama a Edge Function e renderiza resposta
6. Commit: "feat: ativar aba Mentor — Tio Iroh IA contextualizado com gameState do jogador"
```

### FEAT-002 · Sistema de missões semanais
**Cluster:** Game Design | **Esforço:** L | **Tipo:** Feature | **Fase:** Futuro

```
1. Criar tabela weekly_challenges (id, title, description, target_count, skill, xp_reward, gold_reward, week_number, year)
2. Implementar lógica de contagem semanal separada do streak diário
3. UI: banner na aba Missões mostrando desafio semanal atual com barra de progresso
4. Resetar contagem toda segunda-feira às 00h via pg_cron
5. Commit: "feat: sistema de Desafios Semanais com recompensas de XP e Gold"
```

### FEAT-003 · Landing page pública com CTA de instalação
**Cluster:** Marketing | **Esforço:** L | **Tipo:** Feature | **Fase:** Futuro

```
1. Criar arquivo landing.html na raiz do repo (ou subdomínio separado)
2. Conteúdo: headline, 3 benefícios principais, screenshots do app, botão "INSTALAR O SISTEMA"
3. Estética: manter visual Solo Leveling — fundo escuro, neon purple/cyan, fonte Orbitron
4. Adicionar og:image e twitter:card próprios da landing
5. Commit: "feat: landing page pública com CTA de instalação do PWA"
```

### FEAT-004 · Sistema de convite com link único
**Cluster:** Marketing | **Esforço:** M | **Tipo:** Feature | **Fase:** Futuro

```
1. Criar tabela invite_codes (code text PK, created_by uuid, used_by uuid, created_at, used_at)
2. Gerar código único ao usuário se inscrever (8 chars alfanumérico)
3. URL de convite: https://mateusgaldiano.github.io/LifeRPG/?invite=CODE
4. Ao novo usuário completar onboarding com invite code: +50 Gold para quem convidou, +30 Gold para o novo
5. Achievement "Recrutador" ao convidar 3 amigos
6. Commit: "feat: sistema de convite com link único e recompensas bilaterais"
```

### FEAT-005 · Roadmap gamificado dentro do app ("NEXUS")
**Cluster:** Meta-Progressão | **Esforço:** S | **Tipo:** Feature | **Fase:** Futuro

```
1. Criar modal #modal-roadmap com título "NEXUS — Missões do Sistema"
2. Listar features futuras como "missões bloqueadas": Clãs, Chat Privado, Mentor IA, Desafios Semanais
3. Cada item com status: EM DESENVOLVIMENTO / EM TESTES / EM BREVE
4. Adicionar botão de acesso no header ou sidebar
5. Commit: "feat: modal de roadmap gamificado — 'NEXUS — Missões do Sistema'"
```
