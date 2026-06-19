<script setup lang="ts">
import { ref, computed } from 'vue'
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Button } from '@/components/ui/button'
import {
  Chart as ChartJS,
  CategoryScale,
  LinearScale,
  PointElement,
  LineElement,
  Title as ChartTitle,
  Tooltip,
  Legend,
  Filler
} from 'chart.js'
import { Line } from 'vue-chartjs'

ChartJS.register(
  CategoryScale,
  LinearScale,
  PointElement,
  LineElement,
  ChartTitle,
  Tooltip,
  Legend,
  Filler
)

interface Resultado {
  data: string
  taxaDia: number
  rendimentoDia: number
  valorAcumulado: number
  taxaIof: number
  valorIof: number
  taxaIr: number
  valorIr: number
  resgateLiquido: number
  rendimentoLiquidoDia: number
  isProjecao: boolean
  isWeekend: boolean
  isHoliday?: boolean
  holidayName?: string
  isAporteDay?: boolean
}

interface ScenarioForm {
  id: string;
  tipoInvestimento: 'cdi' | 'tesouro';
  valorInicial: number;
  aporteMensal: number;
  diaAporte: number;
  percentualCdi: number;
  dataInicial: string;
  dataFinal: string;
}

interface SimulationResult {
  id: string;
  nome: string;
  cenario: ScenarioForm;
  resultados: Resultado[];
  valorFinal: number;
  lucroTotal: number;
  totalAportado: number;
  taxaAtual: string;
}

interface HistoryItem {
  id: string;
  timestamp: string;
  title: string;
  scenarios: ScenarioForm[];
}

const currentYear = new Date().getFullYear()

const generateId = () => Math.random().toString(36).substr(2, 9)

const scenarios = ref<ScenarioForm[]>([
  {
    id: generateId(),
    tipoInvestimento: 'cdi',
    valorInicial: 1000,
    aporteMensal: 0,
    diaAporte: 1,
    percentualCdi: 100,
    dataInicial: `${currentYear}-01-01`,
    dataFinal: ''
  }
])

const addScenario = () => {
  scenarios.value.push({
    id: generateId(),
    tipoInvestimento: 'cdi',
    valorInicial: 1000,
    aporteMensal: 0,
    diaAporte: 1,
    percentualCdi: 100,
    dataInicial: `${currentYear}-01-01`,
    dataFinal: ''
  })
}

const removeScenario = (index: number) => {
  if (scenarios.value.length > 1) {
    scenarios.value.splice(index, 1)
  }
}

const simulacoes = ref<SimulationResult[]>([])
const loading = ref(false)
const errorMsg = ref('')
const selectedTab = ref<number | 'comparativo'>('comparativo')
const showResults = ref(false)
const history = ref<HistoryItem[]>([])

try {
  const saved = localStorage.getItem('sim_history')
  if (saved) {
    history.value = JSON.parse(saved)
  }
} catch(e) {}

const formatCurrency = (val: number) => {
  return new Intl.NumberFormat('pt-BR', { style: 'currency', currency: 'BRL' }).format(val)
}

const formatPercent = (val: number) => {
  return new Intl.NumberFormat('pt-BR', { style: 'percent', minimumFractionDigits: 4 }).format(val / 100)
}

const getWeekday = (dateStr: string) => {
  if (!dateStr) return ''
  const [day, month, year] = dateStr.split('/')
  const date = new Date(parseInt(year), parseInt(month) - 1, parseInt(day))
  return new Intl.DateTimeFormat('pt-BR', { weekday: 'long' }).format(date)
}

const gerarPdf = () => {
  window.print()
}

const simular = async () => {
  errorMsg.value = ''
  
  // Validation
  for (let i = 0; i < scenarios.value.length; i++) {
    const s = scenarios.value[i]
    if (!s.valorInicial || !s.dataInicial || !s.percentualCdi) {
      errorMsg.value = `Preencha os campos obrigatórios no Cenário ${i + 1}.`
      return
    }
  }

  loading.value = true
  simulacoes.value = []

  try {
    const formatDateToBr = (dateStr: string) => {
      const [year, month, day] = dateStr.split('-')
      return `${day}/${month}/${year}`
    }

    const promises = scenarios.value.map(async (scenario, index) => {
      const queryParams = new URLSearchParams({
        valorInicial: scenario.valorInicial.toString(),
        percentualCdi: scenario.percentualCdi.toString(),
        dataInicial: formatDateToBr(scenario.dataInicial),
        aporteMensal: scenario.aporteMensal.toString(),
        diaAporte: scenario.diaAporte.toString()
      })
      
      if (scenario.dataFinal) {
        queryParams.append('dataFinal', formatDateToBr(scenario.dataFinal))
      }

      // Using Production Cloudflare Worker URL
      const apiUrl = `https://api.desenvolvimento-0d9.workers.dev/api/cdi?${queryParams.toString()}`
      const response = await fetch(apiUrl)
      
      const data = await response.json()
      if (!response.ok) {
        throw new Error(data.error || `Erro ao buscar dados para o Cenário ${index + 1}`)
      }

      return {
        id: scenario.id,
        nome: `Cenário ${index + 1}`,
        cenario: { ...scenario },
        resultados: data.resultados,
        valorFinal: data.valorFinal,
        lucroTotal: data.lucroTotal,
        totalAportado: data.totalAportado,
        taxaAtual: data.taxaAtual
      } as SimulationResult
    })

    const results = await Promise.all(promises)
    simulacoes.value = results
    selectedTab.value = results.length > 1 ? 'comparativo' : 0
    showResults.value = true

    // Save to History
    try {
      const title = scenarios.value.length === 1 
        ? `Simulação: ${scenarios.value[0].tipoInvestimento.toUpperCase()} (${scenarios.value[0].percentualCdi}%)` 
        : `Comparativo: ${scenarios.value.length} Cenários`
      
      const newItem: HistoryItem = {
        id: generateId(),
        timestamp: new Date().toISOString(),
        title,
        scenarios: JSON.parse(JSON.stringify(scenarios.value)) // Deep copy
      }
      
      // Prevent duplicates: remove older entry with exact same configuration so it just moves to the top
      const stringifiedNew = JSON.stringify(newItem.scenarios)
      history.value = history.value.filter(h => JSON.stringify(h.scenarios) !== stringifiedNew)
      
      history.value.unshift(newItem)
      if (history.value.length > 10) history.value.pop()
      
      localStorage.setItem('sim_history', JSON.stringify(history.value))
    } catch(e) {}

  } catch (e: any) {
    errorMsg.value = e.message || 'Erro inesperado.'
  } finally {
    loading.value = false
  }
}

// Chart computed prop
const chartData = computed(() => {
  if (simulacoes.value.length === 0) return { labels: [], datasets: [] }
  
  let longestSim = simulacoes.value[0]
  for (const sim of simulacoes.value) {
    if (sim.resultados.length > longestSim.resultados.length) {
      longestSim = sim
    }
  }
  
  const labels = longestSim.resultados.map(r => r.data)
  const hexColors = ['#10b981', '#3b82f6', '#f59e0b', '#ef4444', '#8b5cf6', '#ec4899']
  const bgColors = ['rgba(16, 185, 129, 0.1)', 'rgba(59, 130, 246, 0.1)', 'rgba(245, 158, 11, 0.1)', 'rgba(239, 68, 68, 0.1)', 'rgba(139, 92, 246, 0.1)', 'rgba(236, 72, 153, 0.1)']
  
  const datasets = simulacoes.value.map((sim, index) => {
    const dataMap = new Map(sim.resultados.map(r => [r.data, r.resgateLiquido]))
    const data = labels.map(label => dataMap.has(label) ? dataMap.get(label)! : null)

    return {
      label: sim.nome,
      data: data,
      borderColor: hexColors[index % hexColors.length],
      backgroundColor: bgColors[index % bgColors.length],
      fill: true,
      tension: 0.4, // Smooth curve
      pointRadius: 0,
      pointHoverRadius: 6,
      borderWidth: 3,
      spanGaps: true
    }
  })

  return { labels, datasets }
})

const chartOptions = {
  responsive: true,
  maintainAspectRatio: false,
  plugins: {
    legend: { position: 'top' as const, labels: { font: { family: 'Outfit', weight: 'bold' as const } } },
    tooltip: {
      mode: 'index' as const,
      intersect: false,
      backgroundColor: 'rgba(15, 23, 42, 0.9)',
      titleFont: { family: 'Outfit', size: 13 },
      bodyFont: { family: 'Outfit', size: 14, weight: 'bold' as const },
      padding: 12,
      cornerRadius: 0,
      callbacks: {
        label: function(context: any) {
          let label = context.dataset.label || ''
          if (label) label += ': '
          if (context.parsed.y !== null) {
            label += new Intl.NumberFormat('pt-BR', { style: 'currency', currency: 'BRL' }).format(context.parsed.y)
          }
          return label
        }
      }
    }
  },
  interaction: { mode: 'index' as const, intersect: false },
  scales: {
    x: { grid: { display: false }, ticks: { font: { family: 'Outfit' } } },
    y: { grid: { color: '#e2e8f0', strokeDash: [4, 4] }, ticks: { font: { family: 'Outfit' } } }
  }
}

// Helpers
const isMultiple = computed(() => simulacoes.value.length > 1)
const taxaAtualGlobal = computed(() => simulacoes.value.length > 0 ? simulacoes.value[0].taxaAtual : '')

const melhorSimulacao = computed(() => {
  if (simulacoes.value.length < 2) return null
  return [...simulacoes.value].sort((a, b) => a.lucroTotal - b.lucroTotal).pop()
})
const piorSimulacao = computed(() => {
  if (simulacoes.value.length < 2) return null
  return [...simulacoes.value].sort((a, b) => a.lucroTotal - b.lucroTotal)[0]
})
const diffLucro = computed(() => {
  if (!melhorSimulacao.value || !piorSimulacao.value) return 0
  return melhorSimulacao.value.lucroTotal - piorSimulacao.value.lucroTotal
})

const loadHistory = (item: HistoryItem) => {
  scenarios.value = JSON.parse(JSON.stringify(item.scenarios))
  simular()
}

const clearHistory = () => {
  history.value = []
  localStorage.removeItem('sim_history')
}

const formatDateTime = (isoString: string) => {
  const d = new Date(isoString)
  return new Intl.DateTimeFormat('pt-BR', { dateStyle: 'short', timeStyle: 'short' }).format(d)
}
</script>

<template>
  <div class="min-h-screen bg-[#F8F9FA] pb-24 print:bg-white print:p-0">
    
    <!-- Premium Header -->
    <header class="bg-slate-900 text-white pt-10 pb-20 px-6 sm:px-12 print:hidden relative overflow-hidden">
      <!-- Decorator Blob -->
      <div class="absolute top-0 right-0 w-[500px] h-[500px] bg-emerald-500/10 rounded-full blur-3xl -translate-y-1/2 translate-x-1/3"></div>
      
      <div class="max-w-6xl mx-auto relative z-10 flex flex-col md:flex-row md:items-end justify-between gap-6">
        <div>
          <h1 class="text-4xl sm:text-5xl font-black tracking-tight mb-2 flex items-center gap-3">
            <svg xmlns="http://www.w3.org/2000/svg" width="40" height="40" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3" stroke-linecap="round" stroke-linejoin="round" class="text-emerald-400"><polyline points="22 7 13.5 15.5 8.5 10.5 2 17"></polyline><polyline points="16 7 22 7 22 13"></polyline></svg>
            <span>Simulador <span class="text-transparent bg-clip-text bg-gradient-to-r from-emerald-400 to-teal-300">CDI</span></span>
          </h1>
          <p class="text-slate-400 font-medium max-w-xl text-lg mt-4">Crie múltiplos cenários, altere prazos e compare o efeito dos juros compostos com precisão matemática oficial.</p>
          <p class="text-xs text-slate-500 mt-3 max-w-xl">* As projeções têm caráter puramente informativo e educacional. Os valores finais podem sofrer pequenas variações de banco para banco devido a metodologias internas de arredondamento de dias úteis e taxas flutuantes.</p>
        </div>
        
        <div v-if="taxaAtualGlobal" class="bg-slate-800/80 backdrop-blur-md border border-slate-700 px-4 py-3 flex items-center gap-3">
          <span class="w-3 h-3 bg-emerald-500 shadow-[0_0_10px_rgba(16,185,129,0.8)] animate-pulse"></span>
          <div>
            <p class="text-[10px] text-slate-400 font-bold uppercase tracking-widest">CDI Atual</p>
            <p class="text-lg font-bold text-white leading-none">{{ formatPercent(parseFloat(taxaAtualGlobal)) }} <span class="text-xs font-normal text-slate-400">ao dia</span></p>
          </div>
        </div>
      </div>
    </header>

    <main class="max-w-6xl mx-auto px-4 sm:px-6 lg:px-8 -mt-10 relative z-20 print:mt-0 print:px-0">
      
      <!-- Forms Section -->
      <div v-if="!showResults" class="space-y-6 print:hidden">
        <div 
          v-for="(scenario, index) in scenarios" 
          :key="scenario.id" 
          class="bg-white border border-slate-200 shadow-[0_8px_30px_rgb(0,0,0,0.04)] p-6 transition-all duration-300 hover:shadow-[0_8px_30px_rgb(0,0,0,0.08)]"
        >
          <div class="flex justify-between items-center mb-6">
            <h3 class="font-black text-slate-800 text-lg uppercase tracking-wider flex items-center gap-2">
              <span class="bg-slate-900 text-white w-6 h-6 flex items-center justify-center text-sm">{{ index + 1 }}</span>
              Cenário
            </h3>
            <button v-if="scenarios.length > 1" @click="removeScenario(index)" type="button" class="text-xs font-bold text-slate-400 hover:text-red-600 uppercase tracking-wider transition-colors flex items-center gap-1">
              <svg xmlns="http://www.w3.org/2000/svg" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M18 6 6 18"/><path d="m6 6 12 12"/></svg>
              Remover
            </button>
          </div>

          <div class="grid grid-cols-1 md:grid-cols-3 gap-8">
            <!-- Col 1: Produto -->
            <div class="space-y-4 md:border-r border-slate-100 md:pr-6">
              <h4 class="text-[10px] font-bold text-slate-400 uppercase tracking-widest border-b border-slate-100 pb-2">O Produto</h4>
              <div class="space-y-3">
                <div class="space-y-1">
                  <Label class="text-xs font-semibold text-slate-600">Tipo de Investimento</Label>
                  <select v-model="scenario.tipoInvestimento" class="flex h-10 w-full rounded-md border border-slate-300 bg-white px-3 py-2 text-sm font-medium focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-emerald-500 transition-all">
                  <option value="cdi">Rendimento no CDI</option>
                  <option value="selic" disabled>Tesouro Direto (Selic) - em breve...</option>
                </select>
                </div>
                <div class="space-y-1">
                  <Label class="text-xs font-semibold text-slate-600">Taxa do Produto (%)</Label>
                  <Input type="number" step="0.01" v-model="scenario.percentualCdi" required :disabled="scenario.tipoInvestimento === 'tesouro'" class="rounded-none bg-slate-50 border-slate-300 font-medium h-10 focus-visible:ring-2 focus-visible:ring-emerald-500 focus-visible:border-transparent disabled:opacity-50 transition-all" />
                </div>
              </div>
            </div>

            <!-- Col 2: Capital -->
            <div class="space-y-4 md:border-r border-slate-100 md:pr-6">
              <h4 class="text-[10px] font-bold text-slate-400 uppercase tracking-widest border-b border-slate-100 pb-2">O Capital</h4>
              <div class="space-y-3">
                <div class="space-y-1">
                  <Label class="text-xs font-semibold text-slate-600">Valor Inicial (R$)</Label>
                  <Input type="number" step="0.01" v-model="scenario.valorInicial" required class="rounded-none bg-slate-50 border-slate-300 font-bold text-emerald-700 h-10 focus-visible:ring-2 focus-visible:ring-emerald-500 focus-visible:border-transparent transition-all" />
                </div>
                <div class="grid grid-cols-2 gap-3">
                  <div class="space-y-1">
                    <Label class="text-xs font-semibold text-slate-600">Aporte Mensal</Label>
                    <Input type="number" step="0.01" v-model="scenario.aporteMensal" class="rounded-none bg-slate-50 border-slate-300 font-medium h-10 focus-visible:ring-2 focus-visible:ring-emerald-500 focus-visible:border-transparent transition-all" />
                  </div>
                  <div class="space-y-1">
                    <Label class="text-xs font-semibold text-slate-600">Dia Aporte</Label>
                    <Input type="number" min="1" max="31" v-model="scenario.diaAporte" required class="rounded-none bg-slate-50 border-slate-300 font-medium h-10 focus-visible:ring-2 focus-visible:ring-emerald-500 focus-visible:border-transparent transition-all" />
                  </div>
                </div>
              </div>
            </div>

            <!-- Col 3: Prazo -->
            <div class="space-y-4">
              <h4 class="text-[10px] font-bold text-slate-400 uppercase tracking-widest border-b border-slate-100 pb-2">O Prazo</h4>
              <div class="space-y-3">
                <div class="space-y-1">
                  <Label class="text-xs font-semibold text-slate-600">Data de Início</Label>
                  <Input type="date" v-model="scenario.dataInicial" required class="rounded-none bg-slate-50 border-slate-300 font-medium h-10 focus-visible:ring-2 focus-visible:ring-emerald-500 focus-visible:border-transparent transition-all" />
                </div>
                <div class="space-y-1">
                  <Label class="text-xs font-semibold text-slate-600 flex justify-between">
                    Data de Resgate 
                    <span class="text-[9px] font-normal text-slate-400 uppercase">Opcional</span>
                  </Label>
                  <Input type="date" v-model="scenario.dataFinal" class="rounded-none bg-slate-50 border-slate-300 font-medium h-10 focus-visible:ring-2 focus-visible:ring-emerald-500 focus-visible:border-transparent transition-all" />
                </div>
              </div>
            </div>
          </div>
        </div>

        <!-- Action Buttons -->
        <div class="flex flex-col sm:flex-row gap-4 pt-4">
          <Button type="button" @click="addScenario" class="h-14 px-8 rounded-none border-2 border-slate-300 bg-white hover:bg-slate-50 text-slate-700 font-bold uppercase tracking-wider transition-all hover:-translate-y-0.5">
            + Adicionar Cenário
          </Button>
          <Button type="button" @click="simular" class="h-14 flex-1 rounded-none bg-slate-900 hover:bg-slate-800 text-white font-black text-lg uppercase tracking-widest transition-all hover:-translate-y-0.5 shadow-[0_10px_20px_rgba(15,23,42,0.2)]" :disabled="loading">
            {{ loading ? 'Processando...' : 'Executar Simulação' }}
          </Button>
        </div>

        <div v-if="errorMsg" class="p-4 bg-red-50 border-l-4 border-red-500 text-red-800 font-medium shadow-sm">
          {{ errorMsg }}
        </div>
      </div>
      
      <!-- HISTORY SECTION -->
      <div v-if="!showResults && history.length > 0" class="mt-12 space-y-4 print:hidden">
        <div class="flex items-center justify-between border-b border-slate-200 pb-2">
          <h3 class="text-slate-800 font-bold uppercase tracking-widest text-sm flex items-center gap-2">
            <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="text-emerald-500"><circle cx="12" cy="12" r="10"/><polyline points="12 6 12 12 16 14"/></svg>
            Consultas Recentes
          </h3>
          <button @click="clearHistory" class="text-[10px] uppercase font-bold text-slate-400 hover:text-red-500 transition-colors">Limpar Histórico</button>
        </div>
        
        <div class="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-4">
          <div 
            v-for="item in history" 
            :key="item.id"
            @click="loadHistory(item)"
            class="bg-white border border-slate-200 p-4 shadow-sm hover:shadow-md hover:border-emerald-300 transition-all cursor-pointer group"
          >
            <p class="text-[10px] text-slate-400 font-bold uppercase tracking-widest mb-1 group-hover:text-emerald-600 transition-colors">{{ formatDateTime(item.timestamp) }}</p>
            <p class="text-sm text-slate-800 font-bold mb-2 truncate">{{ item.title }}</p>
            <p class="text-[11px] text-slate-500 font-medium truncate">
              Investimento Inicial: {{ formatCurrency(item.scenarios[0].valorInicial) }}
            </p>
          </div>
        </div>
      </div>


      <!-- RESULTS SECTION -->
      <div v-if="showResults" class="space-y-6 print:mt-0 print:space-y-4">
        
        <div class="bg-white border border-slate-200 shadow-xl print:border-none print:shadow-none">
          <div class="bg-slate-900 px-6 py-4 flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4 print:hidden">
            <h2 class="text-white font-bold text-lg uppercase tracking-widest flex items-center gap-3">
              <svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="text-emerald-400"><path d="M3 3v18h18"/><path d="m19 9-5 5-4-4-3 3"/></svg>
              Resultados da Simulação
            </h2>
            <div class="flex items-center gap-3">
              <Button variant="ghost" @click="showResults = false" class="text-slate-300 hover:text-white uppercase text-xs font-bold tracking-widest px-2 hover:bg-transparent">
                ← Nova Simulação
              </Button>
              <Button variant="outline" size="sm" @click="gerarPdf" class="rounded-none border-slate-700 bg-slate-800 hover:bg-slate-700 text-white font-semibold uppercase tracking-wider text-xs">
                Gerar PDF
              </Button>
            </div>
          </div>

          <!-- TABS -->
          <div v-if="isMultiple" class="flex flex-wrap border-b border-slate-200 bg-slate-50 print:hidden px-2 pt-2 gap-1">
            <button 
              @click="selectedTab = 'comparativo'"
              :class="['px-6 py-3 text-xs font-black uppercase tracking-widest outline-none transition-all relative top-[1px]', selectedTab === 'comparativo' ? 'text-emerald-700 border-t-2 border-x border-t-emerald-500 border-x-slate-200 bg-white' : 'text-slate-500 hover:text-slate-700 hover:bg-slate-100 border-transparent border-t-2 border-x']"
            >
              Comparativo
            </button>
            <button 
              v-for="(sim, index) in simulacoes" 
              :key="sim.id"
              @click="selectedTab = index"
              :class="['px-6 py-3 text-xs font-black uppercase tracking-widest outline-none transition-all relative top-[1px]', selectedTab === index ? 'text-slate-900 border-t-2 border-x border-t-slate-900 border-x-slate-200 bg-white' : 'text-slate-500 hover:text-slate-700 hover:bg-slate-100 border-transparent border-t-2 border-x']"
            >
              {{ sim.nome }}
            </button>
          </div>

          <div class="p-0 print:p-0">
            
            <!-- COMPARATIVO TAB -->
            <div v-if="isMultiple" v-show="selectedTab === 'comparativo'" class="p-6 sm:p-10 print:p-2 bg-white">
              
              <div v-if="diffLucro > 0" class="mb-10 p-5 bg-gradient-to-r from-emerald-50 to-teal-50 border-l-4 border-emerald-500 rounded-r-lg">
                <p class="text-slate-800 text-lg font-medium">
                  O <strong class="text-emerald-700 font-black">{{ melhorSimulacao?.nome }}</strong> superou o cenário mais fraco em <strong class="text-emerald-700 font-black">+{{ formatCurrency(diffLucro) }}</strong> de lucro líquido final.
                </p>
              </div>

              <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 print:gap-2 mb-12">
                <div v-for="sim in simulacoes" :key="sim.id" class="p-5 bg-white border border-slate-200 shadow-sm hover:shadow-md transition-shadow print:p-2 print:border-b">
                  <p class="text-[10px] text-slate-400 font-black uppercase tracking-widest mb-1">{{ sim.nome }}</p>
                  <p class="text-[11px] text-slate-600 font-medium mb-4 pb-3 border-b border-slate-100 truncate">
                    <span class="bg-slate-100 px-1.5 py-0.5 rounded-sm">{{ sim.cenario.tipoInvestimento === 'cdi' ? sim.cenario.percentualCdi + '% CDI' : 'Selic' }}</span>
                    <span class="ml-2">Inv: {{ formatCurrency(sim.cenario.valorInicial) }}</span>
                  </p>
                  <p class="text-[10px] text-slate-500 font-bold uppercase tracking-widest mb-0.5">Lucro Líquido</p>
                  <p class="text-2xl font-black text-emerald-600 mb-4">+{{ formatCurrency(sim.lucroTotal) }}</p>
                  <div class="flex justify-between items-center text-xs">
                    <span class="text-slate-500 font-medium">Resgate</span>
                    <span class="text-slate-800 font-bold">{{ formatCurrency(sim.valorFinal) }}</span>
                  </div>
                </div>
              </div>
              
              <div class="h-[400px] w-full mt-4">
                <Line :data="chartData" :options="chartOptions" />
              </div>
            </div>

            <!-- INDIVIDUAL SIMULATION TABS -->
            <div 
              v-for="(sim, index) in simulacoes" 
              :key="sim.id" 
              v-show="selectedTab === index || !isMultiple"
            >
              <!-- SCENARIO DETAILS HEADER -->
              <div class="px-6 py-6 border-b border-slate-100 bg-slate-50 flex flex-col sm:flex-row sm:items-center justify-between gap-4 print:p-2 print:border-none">
                <div>
                  <h4 class="text-2xl font-black text-slate-900 mb-1">{{ sim.nome }}</h4>
                  <p class="text-sm text-slate-500 font-medium">{{ sim.cenario.tipoInvestimento === 'cdi' ? 'Rendimento atrelado ao CDI' : 'Tesouro Direto (Selic)' }}</p>
                </div>
                <div class="flex flex-wrap gap-2 text-xs font-semibold print:text-[10px]">
                  <div class="bg-white border border-slate-200 px-3 py-1.5 shadow-sm">
                    <span class="text-slate-400 uppercase tracking-wider text-[9px] block">Taxa</span>
                    <span class="text-slate-800">{{ sim.cenario.percentualCdi }}%</span>
                  </div>
                  <div class="bg-white border border-slate-200 px-3 py-1.5 shadow-sm">
                    <span class="text-slate-400 uppercase tracking-wider text-[9px] block">Capital Inicial</span>
                    <span class="text-slate-800">{{ formatCurrency(sim.cenario.valorInicial) }}</span>
                  </div>
                  <div v-if="sim.cenario.aporteMensal > 0" class="bg-white border border-slate-200 px-3 py-1.5 shadow-sm">
                    <span class="text-slate-400 uppercase tracking-wider text-[9px] block">Aporte Mensal (Dia {{ sim.cenario.diaAporte }})</span>
                    <span class="text-blue-700">{{ formatCurrency(sim.cenario.aporteMensal) }}</span>
                  </div>
                </div>
              </div>

              <!-- WIDGETS -->
              <div class="grid grid-cols-1 md:grid-cols-3 gap-6 p-6 sm:p-10 border-b border-slate-100 bg-white print:gap-2 print:p-2 print:border-none">
                <div class="flex flex-col print:border-b print:pb-2">
                  <p class="text-[10px] text-slate-400 font-bold uppercase tracking-widest mb-1">Total Aportado</p>
                  <p class="text-3xl font-black text-slate-800 print:text-lg">{{ formatCurrency(sim.totalAportado) }}</p>
                </div>
                
                <div class="flex flex-col border-l border-emerald-100 pl-6 print:border-none print:pl-0 print:border-b print:pb-2">
                  <p class="text-[10px] text-emerald-600 font-bold uppercase tracking-widest mb-1">Lucro Líquido</p>
                  <p class="text-4xl font-black text-emerald-600 print:text-xl drop-shadow-sm">+{{ formatCurrency(sim.lucroTotal || 0) }}</p>
                </div>

                <div class="flex flex-col border-l border-slate-100 pl-6 print:border-none print:pl-0 print:border-b print:pb-2">
                  <p class="text-[10px] text-slate-400 font-bold uppercase tracking-widest mb-1">Resgate Final</p>
                  <p class="text-3xl font-black text-slate-800 print:text-lg">{{ formatCurrency(sim.valorFinal || 0) }}</p>
                </div>
              </div>

              <!-- TABLE -->
              <div class="h-[60vh] print:h-auto print:overflow-visible overflow-y-auto relative scroll-smooth border-b border-slate-200 print:border-none bg-white">
                <Table class="print:text-[10px]">
                  <TableHeader>
                    <TableRow class="hover:bg-transparent">
                      <TableHead class="sticky top-0 bg-slate-50 z-10 font-black text-[10px] uppercase tracking-widest text-slate-500 border-b-2 border-slate-200 print:py-1 print:h-8">Data</TableHead>
                      <TableHead class="sticky top-0 bg-slate-50 z-10 font-black text-[10px] uppercase tracking-widest text-slate-500 border-b-2 border-slate-200 print:py-1 print:h-8">Indexador</TableHead>
                      <TableHead class="sticky top-0 bg-emerald-50 z-10 font-black text-[10px] uppercase tracking-widest text-emerald-700 border-b-2 border-emerald-500 print:py-1 print:h-8">Líquido no Dia</TableHead>
                      <TableHead class="sticky top-0 bg-slate-50 z-10 font-black text-[10px] uppercase tracking-widest text-red-500 border-b-2 border-slate-200 print:py-1 print:h-8">Impostos Retidos</TableHead>
                      <TableHead class="sticky top-0 bg-slate-50 z-10 text-right font-black text-[10px] uppercase tracking-widest text-slate-500 pr-6 border-b-2 border-slate-200 print:py-1 print:h-8">Saldo Líquido</TableHead>
                    </TableRow>
                  </TableHeader>
                  <TableBody>
                    <TableRow v-for="(dia, diaIndex) in sim.resultados" :key="diaIndex" :class="(dia.isWeekend || dia.isHoliday) ? 'bg-slate-50/50 opacity-60 grayscale hover:bg-slate-50/50 transition-none print:opacity-100' : (dia.isProjecao ? 'bg-blue-50/30 hover:bg-blue-50/50 transition-none' : 'hover:bg-slate-50/80 transition-colors')">
                      
                      <TableCell class="whitespace-nowrap py-3 border-b border-slate-100 print:py-1">
                        <div class="flex flex-col">
                          <span class="text-[9px] font-bold uppercase tracking-widest text-slate-400 print:text-[8px]">{{ getWeekday(dia.data) }}</span>
                          <div class="flex items-center gap-2 mt-0.5">
                            <span class="text-sm font-bold text-slate-700 print:text-[10px]">{{ dia.data }}</span>
                            <span v-if="dia.isAporteDay" class="text-[8px] font-black bg-blue-600 text-white px-1.5 py-0.5 rounded-sm uppercase tracking-widest shadow-sm" title="Dia do Aporte Mensal">+ Aporte</span>
                            <span v-if="dia.isProjecao && !dia.isWeekend && !dia.isHoliday" class="text-[8px] font-black bg-slate-200 text-slate-600 px-1.5 py-0.5 rounded-sm uppercase tracking-widest" title="Projeção Futura">Proj</span>
                          </div>
                        </div>
                      </TableCell>
                      
                      <TableCell class="text-slate-500 font-semibold border-b border-slate-100 print:py-1 text-xs">{{ formatPercent(dia.taxaDia) }}</TableCell>
                      
                      <TableCell v-if="dia.isWeekend || dia.isHoliday" class="text-slate-400 font-semibold border-b border-slate-100 text-[10px] uppercase tracking-widest print:py-1">
                        {{ dia.isHoliday ? dia.holidayName : 'Fim de Semana' }}
                      </TableCell>
                      <TableCell v-else class="bg-emerald-50/50 text-emerald-700 font-black border-b border-slate-100 text-sm print:py-1 print:text-[10px]">
                        +{{ formatCurrency(dia.rendimentoLiquidoDia) }}
                      </TableCell>

                      <TableCell v-if="dia.isWeekend || dia.isHoliday" class="text-slate-300 font-bold border-b border-slate-100 text-[10px] uppercase tracking-widest print:py-1">
                        -
                      </TableCell>
                      <TableCell v-else class="border-b border-slate-100 print:py-1">
                        <span v-if="dia.valorIof + dia.valorIr > 0" class="text-red-600 font-bold text-sm flex flex-col">
                          -{{ formatCurrency(dia.valorIof + dia.valorIr) }}
                          <span class="text-[9px] text-red-400/80 font-semibold uppercase tracking-widest mt-0.5">
                            (IOF: {{ dia.valorIof > 0 ? formatCurrency(dia.valorIof) : '0,00' }} | IR: {{ formatCurrency(dia.valorIr) }})
                          </span>
                        </span>
                        <span v-else class="text-slate-300 font-bold uppercase tracking-widest text-[10px]">Isento</span>
                      </TableCell>
                      
                      <TableCell class="text-right font-black text-slate-800 text-base pr-6 border-b border-slate-100 print:py-1 print:text-[10px]">{{ formatCurrency(dia.resgateLiquido) }}</TableCell>
                    </TableRow>
                  </TableBody>
                </Table>
              </div>
              <div class="px-6 py-4 bg-white border-t border-slate-100 text-[10px] font-semibold text-slate-400 uppercase tracking-widest space-y-1 print:text-[8px] print:p-2">
                <p><span class="text-slate-500">* IOF:</span> Cobrado caso o resgate ocorra nos primeiros 30 dias de cada aporte.</p>
                <p><span class="text-slate-500">** IR:</span> Cobrado sobre o lucro regressivamente (22,5% a 15%).</p>
              </div>
            </div>

          </div>
        </div>
      </div>

      <!-- FOOTER -->
      <footer class="mt-16 border-t border-slate-200 py-8 text-center print:hidden">
        <div class="flex flex-row flex-wrap items-center justify-center gap-12">
          <a href="https://jorgemiguel.wc4.com.br/" target="_blank" rel="noopener noreferrer" class="flex items-center gap-3 hover:opacity-80 transition-opacity text-left">
            <img src="https://jorgemiguel.wc4.com.br/favicon.svg" alt="Jorge Miguel" class="w-8 h-8" />
            <div class="flex flex-col">
              <span class="text-slate-400 text-[10px] font-bold uppercase tracking-widest">Criado Por</span>
              <span class="text-slate-700 font-bold text-sm">Jorge Miguel</span>
            </div>
          </a>
          <a href="https://github.com/jorgemiguel" target="_blank" rel="noopener noreferrer" class="flex items-center gap-3 hover:opacity-80 transition-opacity text-left">
            <svg xmlns="http://www.w3.org/2000/svg" width="28" height="28" viewBox="0 0 24 24" fill="currentColor" class="text-slate-400"><path d="M12 0c-6.626 0-12 5.373-12 12 0 5.302 3.438 9.8 8.207 11.387.599.111.793-.261.793-.577v-2.234c-3.338.726-4.033-1.416-4.033-1.416-.546-1.387-1.333-1.756-1.333-1.756-1.089-.745.083-.729.083-.729 1.205.084 1.839 1.237 1.839 1.237 1.07 1.834 2.807 1.304 3.492.997.107-.775.418-1.305.762-1.604-2.665-.305-5.467-1.334-5.467-5.931 0-1.311.469-2.381 1.236-3.221-.124-.303-.535-1.524.117-3.176 0 0 1.008-.322 3.301 1.23.957-.266 1.983-.399 3.003-.404 1.02.005 2.047.138 3.006.404 2.291-1.552 3.297-1.23 3.297-1.23.653 1.653.242 2.874.118 3.176.77.84 1.235 1.911 1.235 3.221 0 4.609-2.807 5.624-5.479 5.921.43.372.823 1.102.823 2.222v3.293c0 .319.192.694.801.576 4.765-1.589 8.199-6.086 8.199-11.386 0-6.627-5.373-12-12-12z"/></svg>
            <div class="flex flex-col">
              <span class="text-slate-400 text-[10px] font-bold uppercase tracking-widest">Código Fonte</span>
              <span class="text-slate-700 font-bold text-sm">GitHub</span>
            </div>
          </a>
          <a href="#" target="_blank" rel="noopener noreferrer" class="flex items-center gap-3 hover:opacity-80 transition-opacity text-left">
            <svg xmlns="http://www.w3.org/2000/svg" width="28" height="28" viewBox="0 0 24 24" fill="currentColor" class="text-emerald-500"><path d="M17.523 15.3414C17.523 15.3414 17.523 15.3414 17.523 15.3414C17.1504 15.3414 16.848 15.6423 16.848 16.0125C16.848 16.3828 17.1504 16.6836 17.523 16.6836C17.8955 16.6836 18.198 16.3828 18.198 16.0125C18.198 15.6423 17.8955 15.3414 17.523 15.3414ZM6.47701 15.3414C6.10443 15.3414 5.80201 15.6423 5.80201 16.0125C5.80201 16.3828 6.10443 16.6836 6.47701 16.6836C6.84958 16.6836 7.152 16.3828 7.152 16.0125C7.152 15.6423 6.84958 15.3414 6.47701 15.3414ZM17.7027 10.7424L19.5398 7.56149C19.6469 7.37582 19.5833 7.13851 19.3976 7.03155C19.2119 6.92461 18.9746 6.9881 18.8677 7.17377L17.0016 10.4054C15.4965 9.71887 13.8041 9.32432 12 9.32432C10.1959 9.32432 8.50346 9.71887 6.99841 10.4054L5.13228 7.17377C5.02534 6.9881 4.78801 6.92461 4.60235 7.03155C4.41668 7.13851 4.35316 7.37582 4.46011 7.56149L6.29731 10.7424C3.21855 12.4431 1.13525 15.5492 0.772583 19.2162H23.2274C22.8647 15.5492 20.7815 12.4431 17.7027 10.7424Z"/></svg>
            <div class="flex flex-col">
              <span class="text-emerald-500/80 text-[10px] font-bold uppercase tracking-widest">Instale</span>
              <span class="text-emerald-700 font-bold text-sm">App Android</span>
            </div>
          </a>
        </div>
      </footer>
    </main>
  </div>
</template>

<style>
/* Global adjustments for the neo-premium look */
body {
  font-family: 'Outfit', sans-serif;
  -webkit-font-smoothing: antialiased;
  -moz-osx-font-smoothing: grayscale;
}
</style>
