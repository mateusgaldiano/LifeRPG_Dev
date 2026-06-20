# LifeRPG OS — Pipeline de Pendências
**Gerado em: 20/06/2026 | Auditoria completa pós-leitura do Drive**
**Repo Dev:** `https://mateusgaldiano.github.io/LifeRPG_Dev/`
**Local:** `C:\Users\mateu\.gemini\antigravity\scratch\liferpg`
**Supabase:** `https://ppsqvppnunzagxqruoqf.supabase.co`

---

## ⚠️ CONTEXTO PARA O EXECUTOR

- O projeto foi migrado para **ES Modules**. Entry point: `1.core/app.js`. Módulos em `1.core/modules/`: `state.js`, `utils.js`, `ui.js`, `game-logic.js`, `weekly-report.js`, `social.js`, `pwa.js` + `report-worker.js`
- `supabase-config.js` permanece **script clássico** (não é ES Module)
- Funções expostas globalmente no HTML (onclick) devem ser migradas para listeners ou explicitamente expostas in `window.*`
- Sempre testar no Dev antes do Prod
- Patches cirúrgicos via search/replace — nunca reescrever arquivo inteiro
- Commits descritivos: `fix:` / `feat:` / `refactor:` / `chore:`

---

## 🔴 P0 — CRÍTICO (Resolver esta semana)

---

### BUG-001 · `ensureUserProfile` 403/409 no primeiro login OAuth
**Cluster:** Bug Crítico | **Esforço:** M | **Arquivo:** `1.core/modules/state.js`

Bloqueia: chip de grupo, notificações push e validação de cloud sync. Causa provável: race condition entre INSERT em `persons` e `users` no primeiro OAuth — o perfil ainda não existe quando a segunda inserção é tentada.

```
1. Abrir `1.core/modules/state.js` e localizar a função `ensureUserProfile`
2. Substituir INSERT direto em `persons` por UPSERT: usar `.upsert({...}, { onConflict: 'id' })`
3. Substituir INSERT direto em `users` por UPSERT: usar `.upsert({...}, { onConflict: 'user_id' })`
4. Remover qualquer chamada `.single()` que possa lançar erro 406 — substituir por `.maybeSingle()`
5. Envolver toda a função em try/catch com logging: `console.error('[ensureUserProfile]', err)`
6. Testar no Dev: fazer logout, limpar cookies, fazer login Google pela primeira vez
7. Confirmar que o chip de grupo aparece após login bem-sucedido
8. Commit: "fix: ensureUserProfile upsert para evitar 403/409 no primeiro OAuth"
```

---

### BUG-002 · Mensagens do chat global não aparecem ao enviar
**Cluster:** Bug Crítico | **Esforço:** S | **Arquivo:** `1.core/modules/social.js`

Usuário envia mensagem, ela não aparece no canal. Provável causa: falta de subscription ativa no canal Realtime ou RLS bloqueando SELECT na tabela de chat.

```
1. Abrir `1.core/modules/social.js` e localizar a função de envio de mensagem do chat global
2. Verificar se existe subscription ativa no canal Realtime de chat (procurar por `.channel(` ou `.on('postgres_changes'`)
3. Se subscription não existir: criar `supabase.channel('global-chat').on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'global_chat' }, callback).subscribe()`
4. No Supabase Dashboard → Authentication → Policies: confirmar que a tabela `global_chat` tem RLS policy de SELECT para usuários autenticados
5. Adicionar policy se ausente: `CREATE POLICY "Authenticated users can read chat" ON global_chat FOR SELECT TO authenticated USING (true);`
6. Testar: enviar mensagem e confirmar que aparece sem refresh
7. Commit: "fix: subscription Realtime no chat global + RLS policy de SELECT"
```

---

### BUG-003 · PWA manifest `start_url` scope mismatch → 404 ao abrir app instalado
**Cluster:** Bug Crítico | **Esforço:** XS | **Arquivo:** `1.core/manifest.json`

App instalado abre em 404 porque `start_url` não bate com `scope` do manifest.

```
1. Abrir `1.core/manifest.json`
2. Verificar o valor atual de `start_url` e `scope`
3. Para o repo Dev (GitHub Pages): definir `"start_url": "/LifeRPG_Dev/"` e `"scope": "/LifeRPG_Dev/"`
4. Para o repo Prod: definir `"start_url": "/LifeRPG/"` e `"scope": "/LifeRPG/"`
5. Confirmar que o `sw.js` registra o scope correto (procurar `navigator.serviceWorker.register`)
6. Fazer uninstall do PWA no celular, reabrir no browser, reinstalar
7. Confirmar que não há 404 ao abrir
8. Commit: "fix: manifest start_url e scope para corrigir 404 no PWA instalado"
```

---

### SEG-001 · VAPID private key comprometida — gerar novo par
**Cluster:** Segurança | **Esforço:** XS

Chave privada apareceu em documento. Notificações push completamente não funcionais.

```
1. No terminal local, instalar web-push se necessário: `npm install -g web-push`
2. Gerar novo par: `web-push generate-vapid-keys`
3. Copiar a PUBLIC KEY para `1.core/pwa.js` (substituir a constante VAPID_PUBLIC_KEY existente)
4. Acessar Supabase Dashboard → Edge Functions → Secrets
5. Atualizar (ou criar) o secret `VAPID_PRIVATE_KEY` com o novo valor
6. NUNCA colocar a private key em nenhum arquivo do projeto — apenas em Secrets
7. Atualizar também o secret `VAPID_SUBJECT` se ausente (ex: `mailto:mateusgaldiano@gmail.com`)
8. Testar subscription de push no Dev após correção do BUG-001
9. Commit: "fix: atualizar VAPID public key — par comprometido revogado"
```

---

### UX-001 · Settings modal muito denso — fontes pequenas (feedback confirmado)
**Cluster:** UX/Visual | **Esforço:** M | **Arquivo:** `1.core/styles.css`

Modal de configurações identificado como inacessível. Escalonamento de fontes pendente.

```
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

---

### SEG-002 · Verificar RLS em todas as tabelas Supabase
**Cluster:** Segurança | **Esforço:** S

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

---

### BUG-004 · pg_cron para `check_and_finalize_duels` — confirmação pendente
**Cluster:** Bug Crítico | **Esforço:** XS | **Banco:** Supabase SQL

Duelos PvP podem nunca ser finalizados se o cron não foi criado.

```
1. Acessar Supabase Dashboard → SQL Editor
2. Executar: SELECT * FROM cron.job;
3. Se não existir job para check_and_finalize_duels: criar com
   SELECT cron.schedule('check-duels', '0 */6 * * *', $$SELECT check_and_finalize_duels();$$);
4. Confirmar que a função `check_and_finalize_duels` existe: SELECT proname FROM pg_proc WHERE proname = 'check_and_finalize_duels';
5. Se função não existir: criar conforme RPC já planejada (verificar 3.docs/ para spec)
6. Testar executando manualmente: SELECT check_and_finalize_duels();
7. Commit: "fix: criar pg_cron job para finalização automática de duelos PvP"
```

---

### TECH-001 · `CLAUDE.md` desatualizado — reescrever seção Firebase → Supabase
**Cluster:** Bug Crítico | **Esforço:** S | **Arquivo:** `CLAUDE.md` (na raiz ou 1.core/)

Executor pode confundir arquivos Firebase inexistentes com os arquivos Supabase atuais.

```
1. Abrir CLAUDE.md no projeto local
2. Localizar a seção 6 (ou qualquer seção que mencione Firebase, firebase-config.js, Firestore)
3. Substituir todas as referências Firebase por equivalentes Supabase:
   - firebase-config.js → 1.core/supabase-config.js
   - Firestore → Supabase (tabelas: persons, users, quests, history, items, inventory, analytics_events)
   - Firebase Auth → Supabase Auth (OAuth Google)
   - Firebase Functions → Supabase Edge Functions
4. Atualizar estrutura de módulos ES: listar state.js, utils.js, ui.js, game-logic.js, social.js, pwa.js, weekly-report.js, report-worker.js
5. Atualizar a seção de bugs conhecidos com os itens P0 desta pipeline
6. Commit ao Drive e ao repositório: "chore: atualizar CLAUDE.md — remover Firebase, documentar Supabase + ES Modules"
```

---

### BUG-005 · `switchRankingMode` e `switchTavernaTab` chamados inline no HTML
**Cluster:** Bug Crítico | **Esforço:** S | **Arquivos:** `index.html`, `1.core/app.js`

Funções chamadas via onclick no HTML mas definidas em módulos ES — podem não estar em `window`.

```
1. Abrir index.html e buscar todos os atributos onclick="switchRankingMode" e onclick="switchTavernaTab"
2. Remover os atributos onclick do HTML
3. Abrir 1.core/app.js (entry point)
4. Após os imports, adicionar event listeners para os botões correspondentes:
   document.getElementById('btn-ranking-global').addEventListener('click', () => switchRankingMode('global'));
   document.getElementById('btn-ranking-friends').addEventListener('click', () => switchRankingMode('friends'));
   document.getElementById('subtab-btn-shop').addEventListener('click', () => switchTavernaTab('shop'));
   document.getElementById('subtab-btn-inventory').addEventListener('click', () => switchTavernaTab('inventory'));
5. Confirmar que switchRankingMode está exportada de social.js e importada no app.js
6. Confirmar que switchTavernaTab está exportada de ui.js e importada no app.js
7. Testar clique nas abas do Ranking e Taverna no Dev
8. Commit: "fix: migrar onclick inline de switchRankingMode/switchTavernaTab para event listeners ES Module"
```

---

### MKT-001 · `og:image` e meta tags de compartilhamento ausentes no HTML
**Cluster:** Marketing | **Esforço:** XS | **Arquivo:** `index.html`

Links compartilhados no WhatsApp/Twitter aparecem sem preview. 5 minutos de trabalho.

```
1. Abrir index.html, localizar o bloco <head>
2. Adicionar após as meta tags existentes:
   <meta property="og:title" content="LifeRPG OS — The System">
   <meta property="og:description" content="Transforme seus hábitos em missões. Sistema de gamificação Solo Leveling-inspired para vida real.">
   <meta property="og:image" content="https://mateusgaldiano.github.io/LifeRPG_Dev/2.assets/og-preview.png">
   <meta property="og:url" content="https://mateusgaldiano.github.io/LifeRPG_Dev/">
   <meta property="og:type" content="website">
   <meta name="twitter:card" content="summary_large_image">
   <meta name="twitter:title" content="LifeRPG OS — The System">
   <meta name="twitter:image" content="https://mateusgaldiano.github.io/LifeRPG_Dev/2.assets/og-preview.png">
3. Criar imagem 1200x630px com identidade visual do app e salvar em 2.assets/og-preview.png
4. Commit: "feat: adicionar meta tags og e twitter card para preview de compartilhamento"
```

---

## 🟡 P1 — ALTO (Próximas 2 semanas)

---

### BUG-006 · 16 chamadas `trackEvent` sem implementação funcional
**Cluster:** Bug Crítico | **Esforço:** M | **Arquivo:** `1.core/modules/utils.js`

Analytics completamente cegas. Todas as chamadas existentes no código disparam no vazio.

```
1. Abrir 1.core/modules/utils.js
2. Criar e exportar a função trackEvent:
   export async function trackEvent(eventName, properties = {}) {
     try {
       const user = window._currentUserDbId;
       if (!user || !window.supabase) return;
       await window.supabase.from('analytics_events').insert({
         user_id: user,
         event_name: eventName,
         properties: properties,
         created_at: new Date().toISOString()
       });
     } catch(e) { console.warn('[trackEvent]', e); }
   }
3. Confirmar que a tabela analytics_events existe no Supabase com colunas: id, user_id, event_name, properties (jsonb), created_at
4. Se tabela não existir: CREATE TABLE analytics_events (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), user_id uuid REFERENCES auth.users(id), event_name text NOT NULL, properties jsonb DEFAULT '{}', created_at timestamptz DEFAULT now());
5. Buscar todas as 16 ocorrências de trackEvent( no projeto e confirmar que window.trackEvent está importado/exposto
6. Priorizar eventos: quest_completed, buff_purchased, level_up, daily_penalty, onboarding_complete
7. Commit: "feat: implementar trackEvent com insert em analytics_events no Supabase"
```

---

### BUG-007 · Group multiplier chip oculto — remover `display:none !important` após BUG-001
**Cluster:** Bug Crítico | **Esforço:** XS | **Dependência:** BUG-001 resolvido

```
1. Após confirmar que BUG-001 (ensureUserProfile) está resolvido e perfil é criado corretamente
2. Abrir index.html e localizar o elemento #group-multiplier-chip
3. Remover o atributo style="display: none !important;" do HTML
4. Em state.js ou ui.js, localizar a função que controla visibilidade do chip de grupo
5. Confirmar que friendsCount bidirecional está calculando corretamente (amizades onde user_id = eu OU friend_id = eu)
6. Testar: adicionar amigo e confirmar que chip aparece com multiplicador correto
7. Commit: "fix: exibir group multiplier chip após correção do ensureUserProfile"
```

---

### PWA-001 · iOS Safari: virtual keyboard empurra chat UI
**Cluster:** Mobile & PWA | **Esforço:** M | **Arquivo:** `1.core/modules/social.js`, `1.core/styles.css`

```
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

---

### PWA-002 · Service Worker sem versionamento explícito
**Cluster:** Mobile & PWA | **Esforço:** S | **Arquivo:** `1.core/sw.js`

```
1. Abrir 1.core/sw.js
2. Localizar a constante CACHE_NAME (ex: const CACHE_NAME = 'liferpg-cache-v1')
3. Incrementar versão sempre que houver deploy significativo: 'liferpg-cache-v1.2.0'
4. Adicionar no evento 'activate' do SW:
   self.addEventListener('activate', event => {
     event.waitUntil(
       caches.keys().then(keys => Promise.all(
         keys.filter(k => k !== CACHE_NAME).map(k => caches.delete(k))
       ))
     );
     return self.clients.claim();
   });
5. Adicionar no evento 'install': self.skipWaiting();
6. Commit: "fix: versionamento de cache no SW + skipWaiting e clientsClaim"
```

---

### PWA-003 · Sem feedback de estado offline
**Cluster:** Mobile & PWA | **Esforço:** M | **Arquivos:** `1.core/pwa.js`, `1.core/styles.css`, `index.html`

```
1. Adicionar div no index.html logo após a abertura do body: <div id="offline-banner" class="offline-banner" style="display:none">⚡ MODO OFFLINE — dados serão sincronizados ao reconectar</div>
2. Em styles.css, criar .offline-banner: position fixed, top 0, width 100%, background #ef4444, color #fff, text-align center, padding 6px, font-size 12px, z-index 9999, font-family var(--font-hud), letter-spacing 1px
3. Em pwa.js, adicionar:
   window.addEventListener('offline', () => document.getElementById('offline-banner').style.display = 'block');
   window.addEventListener('online', () => { document.getElementById('offline-banner').style.display = 'none'; saveToCloud(); });
4. Commit: "feat: banner de modo offline + trigger de sync ao reconectar"
```

---

### ENG-001 · Imagens de avatar 1MB+ sem otimização
**Cluster:** Engenharia | **Esforço:** M | **Pasta:** `2.assets/avatars/`

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

---

### UX-002 · 3 colunas de quest muito estreitas em mobile
**Cluster:** UX/Visual | **Esforço:** M | **Arquivo:** `1.core/styles.css`

```
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

---

### UX-003 · Toast messages do Iroh muito longas
**Cluster:** UX/Visual | **Esforço:** S | **Arquivo:** `1.core/modules/ui.js`, `1.core/styles.css`

```
1. Em ui.js, localizar a função showSystemToast
2. Adicionar lógica de duração baseada em tamanho: const duration = msg.length > 120 ? 8000 : 4500;
3. Para toasts com mais de 200 caracteres (mensagens de penalidade severa do Iroh): abrir em modal próprio ao invés de toast
4. Criar função showIrohMessage(text) que abre um modal leve com o texto formatado e botão ENTENDIDO
5. Em game-logic.js, substituir os irohMessages de penalidade severa (tone === 'severe' e tone === 'angry') para chamar showIrohMessage em vez de showSystemToast
6. Commit: "feat: toasts longos do Iroh abrem em modal — melhora legibilidade"
```

---

### UX-004 · Level Up overlay não mostra o que desbloqueou
**Cluster:** UX/Visual | **Esforço:** M | **Arquivo:** `1.core/modules/ui.js`, `index.html`

```
1. Em ui.js, localizar a função triggerLevelUpOverlay
2. Após calcular o novo nível, buscar em ALL_HABITS_DATABASE os hábitos com minLevel === novoNivel
3. Buscar em BOSS_QUEST_BY_LEVEL se o novo nível ativa uma boss quest
4. Adicionar no overlay HTML (index.html) uma div #levelup-unlocks logo abaixo do .levelup-new-level
5. Injetar via JS: lista de novos hábitos + boss quest ativada (se houver) + próximo rank (se rank up)
6. Estilizar: fundo rgba(124,58,237,0.1), border roxa, padding 10px, font-size 12px
7. Commit: "feat: overlay de Level Up exibe hábitos desbloqueados e boss quest ativada"
```

---

### UX-005 · Radar chart sem labels nos vértices
**Cluster:** UX/Visual | **Esforço:** S | **Arquivo:** `1.core/modules/ui.js`

```
1. Em ui.js, localizar a função que renderiza o radar chart (skills-radar-chart canvas)
2. Após desenhar o hexágono preenchido, adicionar renderização de labels nos 6 vértices
3. Labels curtos: FÍS / MEN / FOC / SAB / ROT / CON
4. Posicionar via ctx.fillText() offset da extremidade de cada vértice (adicionar 8-12px além do raio máximo)
5. Font: 9px Inter, cor: var(--text-muted) → como hex literal (ex: #475569) pois canvas não aceita CSS vars
6. Adicionar tooltip no hover do canvas: ao detectar mouse próximo a um vértice, mostrar div tooltip com nome completo + nível
7. Commit: "feat: labels nos vértices do radar chart e tooltip no hover"
```

---

### UX-006 · Weekly Report com texto pequeno em mobile
**Cluster:** UX/Visual | **Esforço:** S | **Arquivo:** `1.core/styles.css`

```
1. Abrir styles.css e localizar estilos do .weekly-report-modal-box
2. Garantir font-size mínimo de 11px em todos os elementos internos do modal
3. No grid de dias (Perfeitos/Bons/Falhados), alterar de 3 colunas para 2 colunas em mobile:
   @media (max-width: 480px) { .weekly-report-modal-box .report-days-grid { grid-template-columns: 1fr 1fr; } }
4. Aumentar padding interno de 8px para 12px nos .report-stat-card
5. Taxa de Sobrevivência: aumentar font-size de 38px para 34px em mobile para caber melhor
6. Commit: "fix: legibilidade do Weekly Report em mobile — font sizes e grid responsivo"
```

---

### GAME-001 · Penalidade P0 muito punitiva para novos jogadores (< nível 10)
**Cluster:** Game Design | **Esforço:** S | **Arquivo:** `1.core/modules/game-logic.js`

```
1. Em game-logic.js, localizar a função applyDailyPenalty
2. Após determinar xpPenaltyPct, adicionar cap por nível:
   if (gameState.level < 10) {
     xpPenaltyPct = Math.min(xpPenaltyPct, 0.10); // cap 10% para iniciantes
     streakReset = misses >= 3 ? true : false; // streak só reseta com 3+ falhas para novatos
   }
3. Adicionar mensagem diferenciada do Iroh para tone 'severe' quando nível < 10 (mais encorajador, menos punitivo)
4. Commit: "game: cap de penalidade para jogadores nível < 10 — reduzir churn de novatos"
```

---

### GAME-002 · Buff Double XP sem indicador visual nos quest cards
**Cluster:** Game Design | **Esforço:** S | **Arquivos:** `1.core/modules/ui.js`, `1.core/styles.css`

```
1. Em ui.js, localizar a função renderQuests (que gera o HTML dos cards de quest)
2. Se gameState.buffs?.doubleXp === true: adicionar no card um badge pulsante "2x XP" acima do payout
3. Badge HTML: <span class="buff-active-badge double-xp-badge">⚡ 2x XP</span>
4. Em styles.css, criar .buff-active-badge: background rgba(251,191,36,0.15), border 1px solid #fbbf24, color #fbbf24, font-size 9px, padding 2px 6px, border-radius 3px, animation pulse 1.5s infinite
5. Fazer o mesmo para buffs.legendaryFocus: badge "x3 💰 GOLD" em amarelo-ouro
6. Commit: "feat: indicadores visuais de buffs ativos (Double XP, Legendary Focus) nos quest cards"
```

---

### GAME-003 · Daily reset sem countdown visível para o usuário
**Cluster:** Game Design | **Esforço:** S | **Arquivos:** `index.html`, `1.core/modules/ui.js`

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

---

### SOCIAL-001 · Friends: busca por prefixo ao invés de username exato
**Cluster:** Social | **Esforço:** M | **Arquivo:** `1.core/modules/social.js`

```
1. Em social.js, localizar a função de busca de amigos (provavelmente triggerFriendSearch ou similar)
2. Substituir query de busca exata por ILIKE:
   .from('persons').select('id, username, level, rank').ilike('username', `%${searchTerm}%`).limit(5)
3. Exibir resultados como lista de 5 cards com: avatar placeholder, username, nível e botão "ADICIONAR"
4. Commit: "feat: busca de amigos por prefixo (ILIKE) ao invés de username exato"
```

---

### SOCIAL-002 · Sem botão de desafio PvP no modal de perfil
**Cluster:** Social | **Esforço:** S | **Arquivos:** `index.html`, `1.core/modules/social.js`

```
1. Em index.html, localizar o modal #modal-player-profile
2. Adicionar antes do botão de amizade existente:
   <button id="btn-profile-pvp-challenge" class="btn-submit" style="width:100%;background:linear-gradient(90deg,#f59e0b,#fbbf24);color:#000;margin-bottom:8px;">⚔️ DESAFIAR PARA DUELO</button>
3. Em social.js, ao abrir o modal de perfil de outro jogador, salvar o ID do jogador em window._profileViewTarget
4. Adicionar listener no btn-profile-pvp-challenge: ao clicar, pré-preencher o modal #modal-pvp-challenge com window._profileViewTarget e abrir
5. Commit: "feat: botão de desafio PvP direto do modal de perfil do jogador"
```

---

### ANALYTICS-001 · Evento de buff comprado para medir conversão da Taverna
**Cluster:** Analytics | **Esforço:** XS | **Arquivo:** `1.core/modules/game-logic.js`

Depende de ANALYTICS-001 (trackEvent implementado).

```
1. Em game-logic.js, localizar a função buyStoreItem
2. Após a linha gameState.gold -= cost; e antes de saveGameData(), adicionar:
   trackEvent('item_purchased', { item_id: itemId, cost: cost, player_level: gameState.level, player_gold_after: gameState.gold });
3. Adicionar também evento para compra bloqueada por nível insuficiente: trackEvent('item_purchase_blocked', { item_id: itemId, required_level: requiredLevel, player_level: gameState.level })
4. Commit: "analytics: trackEvent em compras da Taverna e bloqueios por nível"
```

---

### SEC-001 · Chat global: rate limit para evitar spam
**Cluster:** Segurança | **Esforço:** M | **Banco:** Supabase SQL + `social.js`

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

---

### MKT-002 · "Streak em risco" push notification às 22h
**Cluster:** Marketing | **Esforço:** M | **Dependência:** SEG-001 (VAPID) resolvido

```
1. Criar Supabase Edge Function `send-streak-reminder` que:
   - Busca todos os users com push_subscription ativo que NÃO completaram nenhuma daily hoje
   - Envia push notification com payload: { title: '⚠️ LifeRPG — Streak em Risco', body: 'Seu streak de X dias não sobrevive à meia-noite sem uma missão.' }
2. No pg_cron, agendar: SELECT cron.schedule('streak-reminder', '0 22 * * *', $$SELECT net.http_post(url := current_setting('app.edge_functions_url') || '/send-streak-reminder', headers := '{"Authorization": "Bearer " || current_setting("app.service_role_key")}')$$);
3. Em pwa.js, garantir que push_subscription do usuário é salvo em uma tabela `push_subscriptions` ao se inscrever
4. Commit: "feat: push notification de streak em risco às 22h via Edge Function + pg_cron"
```

---

### A11Y-001 · Botões ✕/✓ com área de toque insuficiente em mobile
**Cluster:** Acessibilidade | **Esforço:** S | **Arquivo:** `1.core/styles.css`

```
1. Abrir styles.css e localizar estilos dos botões de completar/remover quest (✓ e ✕)
2. Garantir min-width: 44px; min-height: 44px; em todos os botões de ação dos quest cards
3. Se visualmente não couber 44px de botão, usar padding negativo:
   .btn-quest-complete { min-width: 44px; min-height: 44px; display: flex; align-items: center; justify-content: center; margin: -8px; padding: 8px; }
4. Verificar também os botões de + e - do contador de água: mesma regra de 44px
5. Commit: "a11y: aumentar área de toque dos botões de quest para mínimo 44x44px"
```

---

### A11Y-002 · Toasts e overlays sem ARIA
**Cluster:** Acessibilidade | **Esforço:** S | **Arquivos:** `index.html`, `1.core/modules/ui.js`

```
1. Em index.html, localizar #toast-container e adicionar role="status" aria-live="polite" aria-atomic="true"
2. Localizar #level-up-overlay e adicionar role="dialog" aria-modal="true" aria-labelledby="levelup-title"
3. Localizar #quest-cleared-overlay e adicionar role="status" aria-live="assertive"
4. Localizar #penalty-overlay e adicionar role="alertdialog" aria-modal="true"
5. Em styles.css, adicionar @media (prefers-reduced-motion: reduce) { .levelup-flash, .quest-cleared-overlay, .flash-red-penalty { animation: none !important; transition: none !important; } }
6. Commit: "a11y: adicionar ARIA roles em toasts/overlays + respeitar prefers-reduced-motion"
```

---

### ONBOARD-001 · Wizard: adicionar 3ª opção de gênero + mover para após o nome
**Cluster:** Onboarding | **Esforço:** S | **Arquivo:** `index.html`, `1.core/modules/app.js`

```
1. Em index.html, localizar #wizard-step-0 (seleção de gênero)
2. Adicionar terceiro card: <div class="gender-card" id="btn-gender-neutral" data-gender="neutral"><div style="font-size: 3.5rem; margin-bottom: 10px;">⚡</div><strong>Neutro</strong></div>
3. No app.js/pwa.js, adicionar data-gender="neutral" ao handler de seleção existente
4. Alterar a ordem dos steps: mover step de gênero para APÓS step-1 (nome do jogador)
5. Update lógica de navegação entre steps (back/next buttons)
6. Commit: "feat: adicionar opção de gênero neutro no onboarding + reordenar step para após nome"
```

---

### ONBOARD-002 · Hook habit do onboarding personalizado por archetype
**Cluster:** Onboarding | **Esforço:** M | **Arquivo:** `1.core/modules/game-logic.js` ou `app.js`

```
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

---

### META-001 · Novos achievements — expandir catálogo
**Cluster:** Meta-Progressão | **Esforço:** M | **Arquivo:** `1.core/modules/game-logic.js`

```
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

---

### META-002 · Avatar ranks — confirmar que todos os ranks têm ambos os gêneros
**Cluster:** Meta-Progressão | **Esforço:** M | **Pasta:** `2.assets/avatars/`

```
1. Listar todos os arquivos em 2.assets/avatars/ para ambas as pastas (female/male)
2. Confirmar que existem arquivos para ranks: 1.rank-e, 2.rank-d, 3.rank-c, 4.rank-b, 5.rank-a, 6.rank-s
3. Para ranks faltantes: criar ou solicitar arte (placeholder aceitável enquanto arte não está pronta)
4. Em ui.js, confirmar que a função de troca de avatar usa corretamente gameState.gender para selecionar a pasta certa
5. Adicionar gênero neutral como alias para male ou criar pasta separada
6. Commit: "feat: garantir cobertura de todos os ranks para todos os gêneros nos avatares"
```

---

## 🟣 P2 — MÉDIO (Próximas semanas, ordem flexível)

---

### GAME-004 · Comeback mechanic para usuários que voltam após 7+ dias
**Cluster:** Game Design | **Esforço:** M

```
1. Em state.js ou app.js, no boot do app, calcular dias desde last_active
2. Se days_absent >= 7: ativar flag gameState._comebackMode = true por 3 dias
3. Em game-logic.js, em addRewards(): se _comebackMode === true, multiplicar XP por 1.5
4. Mensagem especial do Iroh ao detectar retorno longo
5. Commit: "feat: Modo Retorno — 1.5x XP por 3 dias após ausência de 7+ dias"
```

---

### ENG-002 · social.js: lazy loading ao abrir o modal Social
**Cluster:** Engenharia | **Esforço:** M

```
1. Em app.js, no evento de clique do botão #btn-header-social:
   const { initSocial } = await import('./modules/social.js');
   initSocial();
2. Remover import estático de social.js no topo de app.js
3. Garantir que a referência ao modal social funciona após import dinâmico
4. Commit: "perf: lazy load do módulo social.js — import dinâmico ao abrir modal"
```

---

### GAME-005 · Dungeon pool: expandir para 20+ missões com raridade
**Cluster:** Meta-Progressão | **Esforço:** M | **Arquivo:** `1.core/modules/state.js`

```
1. Em state.js, localizar DUNGEON_POOL
2. Expandir para pelo menos 20 entradas cobrindo todos os 6 skills
3. Adicionar campo rarity: 'comum' | 'raro' | 'épico' com multiplicadores de recompensa 1x / 1.5x / 2.5x
4. Épico: chance de 10%, Raro: 25%, Comum: 65%
5. Em game-logic.js, spawnDungeon(): usar Math.random() para determinar raridade e aplicar multiplicador de recompensa
6. Commit: "feat: expandir dungeon pool para 20+ missões com sistema de raridade"
```

---

### UX-007 · Empty state da Visão Global reescrito
**Cluster:** UX/Visual | **Esforço:** XS | **Arquivo:** `index.html`

```
1. Em index.html, localizar #global-empty-state
2. Substituir o texto interno por:
   "Seu mapa tático está em formação. Complete sua primeira missão hoje e a primeira marca será revelada às 00h."
3. Adicionar um mini-heatmap placeholder animado (5x5 grid de quadrados semitransparentes pulsantes como preview)
4. Commit: "ux: reescrever empty state da Visão Global para ser mais motivacional"
```

---

### A11Y-003 · Radar chart com descrição para screen readers
**Cluster:** Acessibilidade | **Esforço:** S

```
1. Em index.html, adicionar após o canvas do radar: <div class="sr-only" id="radar-description" aria-live="polite"></div>
2. Em ui.js, após renderizar o radar, injetar texto: "Atributos: Força de Vontade nível X, Intelecto nível Y, ..."
3. Adicionar aria-labelledby="radar-description" no canvas
4. Commit: "a11y: descrição de texto para o radar chart — acessibilidade screen readers"
```

---

### MKT-003 · Weekly Report: botão de compartilhar
**Cluster:** Marketing | **Esforço:** M | **Arquivo:** `1.core/modules/weekly-report.js`, `index.html`

```
1. Em index.html, adicionar botão no modal-weekly-report: <button id="btn-share-report" class="btn-submit btn-secondary" style="width:100%;margin-top:8px;">📤 COMPARTILHAR RELATÓRIO</button>
2. Em weekly-report.js, no listener do btn-share-report:
   - Usar html2canvas (importar do CDN) para capturar o modal como imagem
   - Se Web Share API disponível: navigator.share({ files: [imageFile], title: 'Meu Relatório LifeRPG' })
   - Fallback: download direto da imagem
3. Commit: "feat: botão de compartilhar relatório semanal como imagem"
```

---

### GAME-006 · XP necessário para próximo nível visível na XP bar
**Cluster:** Game Design | **Esforço:** XS

```
1. Em index.html, no .xp-bar-header, o elemento já tem #lbl-xp-current e #lbl-xp-next
2. Confirmar que updateUI() atualiza esses valores corretamente com gameState.xp e gameState.xpToNext
3. Adicionar tooltip ao hover na XP bar: "Faltam X XP para o Nível Y"
4. Commit: "ux: confirmar visibilidade de XP atual/necessário na barra de experiência"
```

---

### SEC-003 · Presença Supabase: configurar heartbeat e expiração de sessões zombie
**Cluster:** Segurança | **Esforço:** S | **Arquivo:** `1.core/modules/social.js`

```
1. Em social.js, localizar initPresence() ou o código de channel Presence
2. Ao criar o canal Presence, configurar: { config: { presence: { key: userId }, heartbeat_interval_ms: 30000 } }
3. Adicionar limpeza no evento beforeunload: window.addEventListener('beforeunload', () => presenceChannel.untrack())
4. Commit: "fix: heartbeat de 30s e cleanup de presença ao fechar o app"
```

---

### ONBOARD-003 · Prompt de instalação PWA no final do onboarding
**Cluster:** Onboarding | **Esforço:** S

```
1. Em app.js ou pwa.js, capturar o evento beforeinstallprompt: let deferredPrompt; window.addEventListener('beforeinstallprompt', (e) => { e.preventDefault(); deferredPrompt = e; });
2. No wizard step final (btn-wizard-finish), após completar o onboarding:
   if (deferredPrompt) { const step = document.getElementById('wizard-step-install'); if (step) step.style.display = 'block'; }
3. Adicionar step extra no wizard (wizard-step-install) com texto "📱 Instale o app para a experiência completa" e botão INSTALAR que chama deferredPrompt.prompt()
4. Commit: "feat: prompt de instalação PWA ao final do onboarding wizard"
```

---

## ⚪ P3 — FUTURO (Backlog estratégico)

---

### ENG-003 · styles.css: PurgeCSS e minificação para produção
**Cluster:** Engenharia | **Esforço:** M

```
1. Configurar build script com PurgeCSS: npx purgecss --css 1.core/styles.css --content index.html 1.core/**/*.js --output 1.core/styles.min.css
2. Atualizar link no index.html para styles.min.css em produção
3. Target: reduzir de 110KB para < 40KB gzipped
4. Commit: "perf: PurgeCSS no pipeline de produção — remover CSS não utilizado"
```

---

### GAME-007 · Prestige system após Rank S (nível 30)
**Cluster:** Meta-Progressão | **Esforço:** L

```
1. Definir mecânica: ao atingir nível 30, opção de "Ascender" — reseta XP para 0 mas mantém hábitos e conquistas
2. Adicionar campo gameState.prestige_level (inicia em 0)
3. Benefício do prestige: +5% multiplicador permanente de XP por nível de prestige (max 3)
4. Avatar especial dourado para prestige 1+ com borda especial automática
5. Commit: "feat: Prestige system — progressão além do Rank S"
```

---

### FEAT-001 · Aba MENTOR (Tio Iroh IA via Claude API) — desabilitar display:none
**Cluster:** Meta-Progressão | **Esforço:** XL

```
1. Criar Supabase Edge Function `mentor-chat` que recebe { message, gameState_summary } e chama Claude API
2. System prompt: persona do Tio Iroh com contexto do gameState do jogador (nível, streak, skills, missão atual)
3. Em index.html: remover style="display:none" da <section id="tab-chat">
4. Adicionar botão da aba Mentor na nav: <button class="tab-link" data-tab="chat">🎓 MENTOR</button>
5. Em ui.js, criar função sendMentorMessage() que chama a Edge Function e renderiza resposta
6. Commit: "feat: ativar aba Mentor — Tio Iroh IA contextualizado com gameState do jogador"
```

---

### FEAT-002 · Sistema de missões semanais
**Cluster:** Game Design | **Esforço:** L

```
1. Criar tabela weekly_challenges (id, title, description, target_count, skill, xp_reward, gold_reward, week_number, year)
2. Implementar lógica de contagem semanal separada do streak diário
3. UI: banner na aba Missões mostrando desafio semanal atual com barra de progresso
4. Resetar contagem toda segunda-feira às 00h via pg_cron
5. Commit: "feat: sistema de Desafios Semanais com recompensas de XP e Gold"
```

---

### FEAT-003 · Landing page pública com CTA de instalação
**Cluster:** Marketing | **Esforço:** L

```
1. Criar arquivo landing.html na raiz do repo (ou subdomínio separado)
2. Conteúdo: headline, 3 benefícios principais, screenshots do app, botão "INSTALAR O SISTEMA"
3. Estética: manter visual Solo Leveling — fundo escuro, neon purple/cyan, fonte Orbitron
4. Adicionar og:image e twitter:card próprios da landing
5. Commit: "feat: landing page pública com CTA de instalação do PWA"
```

---

### FEAT-004 · Sistema de convite com link único
**Cluster:** Marketing | **Esforço:** M

```
1. Criar tabela invite_codes (code text PK, created_by uuid, used_by uuid, created_at, used_at)
2. Gerar código único ao usuário se inscrever (8 chars alfanumérico)
3. URL de convite: https://mateusgaldiano.github.io/LifeRPG/?invite=CODE
4. Ao novo usuário completar onboarding com invite code: +50 Gold para quem convidou, +30 Gold para o novo
5. Achievement "Recrutador" ao convidar 3 amigos
6. Commit: "feat: sistema de convite com link único e recompensas bilaterais"
```

---

### FEAT-005 · Roadmap gamificado dentro do app ("NEXUS")
**Cluster:** Meta-Progressão | **Esforço:** S

```
1. Criar modal #modal-roadmap com título "NEXUS — Missões do Sistema"
2. Listar features futuras como "missões bloqueadas": Clãs, Chat Privado, Mentor IA, Desafios Semanais
3. Cada item com status: EM DESENVOLVIMENTO / EM TESTES / EM BREVE
4. Adicionar botão de acesso no header ou sidebar
5. Commit: "feat: modal de roadmap gamificado — 'NEXUS — Missões do Sistema'"
```

---

## 📋 RESUMO EXECUTIVO

| Prioridade | Qtd | Foco Principal |
|-----------|-----|----------------|
| **P0 Crítico** | 8 | Bugs bloqueantes, segurança, UX crítica |
| **P1 Alto** | 23 | Performance, retenção, analytics, UX |
| **P2 Médio** | 18 | Game design, social, acessibilidade |
| **P3 Futuro** | 7 | Features estratégicas e endgame |

**Ordem recomendada de execução P0:**
```
1. BUG-003 (manifest PWA 404) — 5 minutos
2. MKT-001 (og:image meta tags) — 10 minutos
3. SEG-001 (novo par VAPID) — 15 minutos
4. TECH-001 (CLAUDE.md atualizado) — 20 minutos
5. SEG-002 (RLS todas as tabelas) — 30 minutos
6. BUG-004 (pg_cron duelos) — 15 minutos
7. BUG-005 (onclick inline → listeners) — 30 minutos
8. UX-001 (fontes Settings modal) — 45 minutos
9. BUG-001 (ensureUserProfile) — 60 minutos
10. BUG-002 (chat não aparece) — 45 minutos
```

---

*Pipeline gerado via auditoria completa do Drive (index.html 85KB, game-logic.js 46KB, social.js 110KB, ui.js 75KB, state.js 34KB, styles.css 110KB, weekly-report.js 13KB, utils.js 10KB, sw.js 9KB, report-worker.js 4KB)*
