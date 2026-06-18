// weekly-report.js
import { gameState, saveGameData } from './state.js';
import { getRankForLevel, localDateStr } from './utils.js';
import { showSystemToast, updateUI } from './ui.js';

// ==========================================================================
// SISTEMA DE AVALIAÇÃO SEMANAL (WEEKLY REPORT)
// ==========================================================================
function getISOWeekString(date) {
    const d = new Date(Date.UTC(date.getFullYear(), date.getMonth(), date.getDate()));
    const dayNum = d.getUTCDay() || 7;
    d.setUTCDate(d.getUTCDate() + 4 - dayNum);
    const yearStart = new Date(Date.UTC(d.getUTCFullYear(), 0, 1));
    const weekNo = Math.ceil((((d - yearStart) / 86400000) + 1) / 7);
    const padWeek = String(weekNo).padStart(2, '0');
    return `${d.getUTCFullYear()}-W${padWeek}`;
}

function getPreviousWeekDates(todayDate) {
    const dates = [];
    const d = new Date(todayDate);
    const day = d.getDay(); // 0 (domingo) a 6 (sábado)
    const diffToPrevMonday = (day === 0 ? 6 : day - 1) + 7;
    
    const prevMonday = new Date(d);
    prevMonday.setDate(d.getDate() - diffToPrevMonday);
    prevMonday.setHours(0, 0, 0, 0);
    
    for (let i = 0; i < 7; i++) {
        const dayDate = new Date(prevMonday);
        dayDate.setDate(prevMonday.getDate() + i);
        dates.push(localDateStr(dayDate));
    }
    
    const mondayDate = new Date(prevMonday);
    const sundayDate = new Date(prevMonday);
    sundayDate.setDate(prevMonday.getDate() + 6);
    
    return { dates, mondayDate, sundayDate };
}

function checkAndShowWeeklyReport() {
    const today = new Date();
    const currentWeekStr = getISOWeekString(today);
    
    const prevWeekDate = new Date(today);
    prevWeekDate.setDate(today.getDate() - 7);
    const prevWeekStr = getISOWeekString(prevWeekDate);
    
    if (!gameState.history || Object.keys(gameState.history).length === 0) return;
    if (gameState.lastWeeklyReportYearWeek === prevWeekStr) return;
    
    const { dates, mondayDate, sundayDate } = getPreviousWeekDates(today);
    
    let completedQuests = 0;
    let totalQuests = 0;
    let perfectDays = 0;
    let goodDays = 0;
    let missedDays = 0;
    let activeDaysCount = 0;
    const completedTitles = [];
    
    dates.forEach(dStr => {
        const log = gameState.history[dStr];
        if (log) {
            activeDaysCount++;
            completedQuests += (log.count || 0);
            totalQuests += (log.total || 0);
            
            if (log.status === 'perfect') perfectDays++;
            else if (log.status === 'good') goodDays++;
            else if (log.status === 'missed' || log.status === 'bad') missedDays++;
            
            if (log.completedIds && Array.isArray(log.completedIds)) {
                completedTitles.push(...log.completedIds);
            }
        }
    });
    
    if (activeDaysCount === 0) {
        gameState.lastWeeklyReportYearWeek = prevWeekStr;
        saveGameData();
        return;
    }
    
    const survivalRate = totalQuests > 0 ? Math.round((completedQuests / totalQuests) * 100) : 0;
    
    const skillCounts = {};
    const allQuests = [...(gameState.quests || []), ...(gameState.sideQuests || [])];
    
    completedTitles.forEach(title => {
        const match = allQuests.find(q => q.title === title);
        const skill = match ? (match.skill || 'routine') : 'routine';
        skillCounts[skill] = (skillCounts[skill] || 0) + 1;
    });
    
    let topSkill = 'routine';
    let maxCount = 0;
    Object.entries(skillCounts).forEach(([skill, count]) => {
        if (count > maxCount) {
            maxCount = count;
            topSkill = skill;
        }
    });
    
    const skillNames = {
        routine: 'Rotina',
        physical: 'Força Física',
        wisdom: 'Sabedoria/Estudos',
        mental: 'Saúde Mental',
        productivity: 'Produtividade',
        social: 'Social/Conexões'
    };
    const topSkillName = skillNames[topSkill] || 'Rotina';
    
    let rankLabel = 'RANK D';
    let rankClass = 'rank-glow-d';
    let goldReward = 0;
    let xpReward = 0;
    let verdictDesc = '';
    
    if (survivalRate >= 90) {
        rankLabel = 'RANK S';
        rankClass = 'rank-glow-s';
        goldReward = 80;
        xpReward = 150;
        verdictDesc = '"Desempenho lendário. Suas habilidades crescem em ritmo avassalador. O topo do mundo está ao seu alcance."';
    } else if (survivalRate >= 75) {
        rankLabel = 'RANK A';
        rankClass = 'rank-glow-a';
        goldReward = 50;
        xpReward = 100;
        verdictDesc = '"Desempenho formidável. O Sistema reconhece seu vigor e determinação. Continue subindo de nível."';
    } else if (survivalRate >= 50) {
        rankLabel = 'RANK B';
        rankClass = 'rank-glow-b';
        goldReward = 30;
        xpReward = 60;
        verdictDesc = '"Progresso aceitável. Suas conquistas são constantes, mas a complacência é sua maior inimiga."';
    } else if (survivalRate >= 30) {
        rankLabel = 'RANK C';
        rankClass = 'rank-glow-c';
        goldReward = 15;
        xpReward = 30;
        verdictDesc = '"Abaixo das expectativas. Você está apenas sobrevivendo. O Sistema exige mais empenho e atitude."';
    } else {
        rankLabel = 'RANK D';
        rankClass = 'rank-glow-d';
        goldReward = 0;
        xpReward = 0;
        verdictDesc = '"Desempenho patético. Você corre risco de estagnação. Desperte antes que seja tarde demais."';
    }
    
    const formatDate = (d) => `${String(d.getDate()).padStart(2, '0')}/${String(d.getMonth() + 1).padStart(2, '0')}`;
    const periodText = `PERÍODO DE AVALIAÇÃO: ${formatDate(mondayDate)} a ${formatDate(sundayDate)}`;
    
    const periodEl = document.getElementById('report-period-text');
    const rateValEl = document.getElementById('report-rate-val');
    const rateBarEl = document.getElementById('report-rate-bar');
    const countEl = document.getElementById('report-quests-count');
    const perfEl = document.getElementById('report-days-perfect');
    const goodEl = document.getElementById('report-days-good');
    const missEl = document.getElementById('report-days-missed');
    const focusEl = document.getElementById('report-skill-focus');
    const rankEl = document.getElementById('report-verdict-rank');
    const descEl = document.getElementById('report-verdict-desc');
    const btn = document.getElementById('btn-claim-weekly-report');
    
    if (periodEl) periodEl.innerText = periodText;
    if (rateValEl) rateValEl.innerText = `${survivalRate}%`;
    if (rateBarEl) rateBarEl.style.width = `${survivalRate}%`;
    if (countEl) countEl.innerText = `Concluiu ${completedQuests} de ${totalQuests} missões programadas`;
    
    if (perfEl) perfEl.innerText = perfectDays;
    if (goodEl) goodEl.innerText = goodDays;
    if (missEl) missEl.innerText = missedDays;
    
    if (focusEl) {
        if (maxCount > 0) {
            focusEl.innerHTML = `Você focou majoritariamente na habilidade: <strong style="color: var(--neon-purple);">${topSkillName}</strong> (${maxCount} quests feitas).`;
        } else {
            focusEl.innerHTML = `Nenhuma missão realizada no período.`;
        }
    }
    
    if (rankEl) {
        rankEl.innerText = rankLabel;
        rankEl.className = `font-hud ${rankClass}`;
    }
    if (descEl) descEl.innerText = verdictDesc;
    
    if (btn) {
        btn.dataset.rewards = JSON.stringify({ gold: goldReward, xp: xpReward, rank: rankLabel });
        btn.dataset.week = prevWeekStr;
    }
    
    const modal = document.getElementById('modal-weekly-report');
    if (modal) modal.style.display = 'flex';
}

function claimWeeklyReport(rewards, weekStr) {
    const gold = rewards.gold || 0;
    const xp = rewards.xp || 0;
    const rank = rewards.rank || 'RANK D';
    
    if (xp > 0) {
        gameState.xp += xp;
        if (gameState.xp >= gameState.xpToNext) {
            gameState.level++;
            gameState.xp = gameState.xp - gameState.xpToNext;
            gameState.xpToNext = getXpToNextForLevel(gameState.level);
            syncQuestsByLevel();
            triggerLevelUpOverlay();
            checkAndActivateBossQuest();
        }
    }
    if (gold > 0) {
        gameState.gold = (gameState.gold || 0) + gold;
    }
    
    let systemMessage = `🔔 *NOTIFICAÇÃO DE AVALIAÇÃO DO SISTEMA*\n\nSemana avaliada: *${weekStr}*\nResultado obtido: *${rank}*\n\n`;
    if (gold > 0 || xp > 0) {
        systemMessage += `Recompensa resgatada:\n+${xp} XP · +${gold} Ouro 🪙`;
    } else {
        systemMessage += `Nenhuma recompensa concedida devido ao baixo desempenho.`;
    }
    
    if (typeof receiveMessage === 'function') {
        setTimeout(() => {
            receiveMessage(systemMessage);
            if (typeof showChatBadge === 'function') showChatBadge();
        }, 500);
    }
    
    gameState.lastWeeklyReportYearWeek = weekStr;
    saveGameData();
    updateUI();
    
    const modal = document.getElementById('modal-weekly-report');
    if (modal) modal.style.display = 'none';
    showSystemToast(`🏆 Avaliação finalizada. Recompensas recebidas.`);
}



export {
    getISOWeekString,
    getPreviousWeekDates,
    checkAndShowWeeklyReport,
    claimWeeklyReport
};
