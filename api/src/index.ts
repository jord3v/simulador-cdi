import { Hono } from 'hono'
import { cors } from 'hono/cors'

const app = new Hono()

app.use('*', cors())

app.get('/api/cdi', async (c) => {
  const dataInicial = c.req.query('dataInicial')
  const dataFinal = c.req.query('dataFinal')
  const valorInicialStr = c.req.query('valorInicial')
  const percentualCdiStr = c.req.query('percentualCdi')
  const aporteMensalStr = c.req.query('aporteMensal') || '0'
  const diaAporteStr = c.req.query('diaAporte') || '1'

  if (!dataInicial || !valorInicialStr || !percentualCdiStr) {
    return c.json({ error: 'Parâmetros dataInicial, valorInicial e percentualCdi são obrigatórios.' }, 400)
  }

  const valorInicial = parseFloat(valorInicialStr)
  const percentualCdi = parseFloat(percentualCdiStr)
  const aporteMensal = parseFloat(aporteMensalStr)
  const diaAporte = parseInt(diaAporteStr)

  if (isNaN(valorInicial) || isNaN(percentualCdi) || isNaN(aporteMensal) || isNaN(diaAporte)) {
    return c.json({ error: 'Valores numéricos inválidos.' }, 400)
  }

  let apiUrl = `https://api.bcb.gov.br/dados/serie/bcdata.sgs.12/dados/?formato=json&dataInicial=${dataInicial}`
  if (dataFinal) {
    apiUrl += `&dataFinal=${dataFinal}`
  }

  try {
    const response = await fetch(apiUrl)
    if (!response.ok) {
      throw new Error(`Erro na API do Banco Central: ${response.statusText}`)
    }
    
    const bcbData = await response.json() as { data: string, valor: string }[]

    // Fetch latest rate for projection
    const latestResponse = await fetch('https://api.bcb.gov.br/dados/serie/bcdata.sgs.12/dados/ultimos')
    const latestData = await latestResponse.json() as { data: string, valor: string }[]
    const taxaAtual = latestData[0]?.valor || "0"
    
    const parseDateBR = (dateStr: string) => {
      const [day, month, year] = dateStr.split('/')
      return new Date(parseInt(year), parseInt(month) - 1, parseInt(day))
    }

    const formatDateBR = (date: Date) => {
      const dd = String(date.getDate()).padStart(2, '0')
      const mm = String(date.getMonth() + 1).padStart(2, '0')
      const yyyy = date.getFullYear()
      return `${dd}/${mm}/${yyyy}`
    }

    const dataDict = new Map<string, string>()
    bcbData.forEach(item => {
      dataDict.set(item.data, item.valor)
    })

    const dataBaseDate = parseDateBR(dataInicial)
    let lastBcbDate = dataBaseDate
    if (bcbData.length > 0) {
      lastBcbDate = parseDateBR(bcbData[bcbData.length - 1].data)
    }

    const endDate = dataFinal ? parseDateBR(dataFinal) : lastBcbDate
    
    // Fetch Holidays
    const startYear = dataBaseDate.getFullYear()
    const endYear = endDate.getFullYear()
    const holidayMap = new Map<string, string>()
    
    const mesesPt: Record<string, string> = {
      "janeiro": "01", "fevereiro": "02", "março": "03", "abril": "04",
      "maio": "05", "junho": "06", "julho": "07", "agosto": "08",
      "setembro": "09", "outubro": "10", "novembro": "11", "dezembro": "12"
    }

    try {
      const yearPromises = []
      for (let y = startYear; y <= endYear; y++) {
        yearPromises.push(
          fetch(`https://feriadosbancarios.febraban.org.br/Home/ObterFeriadosFederais?ano=${y}`)
            .then(res => res.json())
            .then((holidays: any[]) => ({ year: y, holidays }))
            .catch(() => ({ year: y, holidays: [] }))
        )
      }
      
      const yearsData = await Promise.all(yearPromises)
      for (const { year, holidays } of yearsData) {
        if (Array.isArray(holidays)) {
          for (const h of holidays) {
            // diaMes: "01 de janeiro"
            const match = h.diaMes.match(/(\d{2})\s+de\s+([a-zç]+)/i)
            if (match) {
              const dd = match[1]
              const mesNome = match[2].toLowerCase()
              const mm = mesesPt[mesNome]
              if (mm) {
                holidayMap.set(`${dd}/${mm}/${year}`, h.nomeFeriado)
              }
            }
          }
        }
      }
    } catch (e) {
      console.error("Failed to fetch holidays", e)
    }

    const fullDataSequence = []
    let currentDateSequence = new Date(dataBaseDate)

    while (currentDateSequence <= endDate) {
      const dateStr = formatDateBR(currentDateSequence)
      const isFuture = currentDateSequence > lastBcbDate
      const dayOfWeek = currentDateSequence.getDay()
      const isWeekend = dayOfWeek === 0 || dayOfWeek === 6
      const isHoliday = holidayMap.has(dateStr)
      const holidayName = isHoliday ? holidayMap.get(dateStr) : null

      let valor = "0"
      let isProjecao = false

      if (dataDict.has(dateStr)) {
        valor = dataDict.get(dateStr)!
        // BCB data dictates the rate, but if it's magically a holiday in BCB data, we still use BCB rate (very rare).
      } else {
        if (isFuture) {
          isProjecao = true
          if (!isWeekend && !isHoliday) {
            valor = taxaAtual
          }
        }
      }

      fullDataSequence.push({
        data: dateStr,
        valor: valor,
        isProjecao: isProjecao,
        isWeekend: isWeekend,
        isHoliday: isHoliday,
        holidayName: holidayName
      })

      currentDateSequence.setDate(currentDateSequence.getDate() + 1)
    }
    
    interface Tranche {
      valorInicial: number
      valorAcumulado: number
      dataInicio: Date
    }

    const tranches: Tranche[] = [{
      valorInicial: valorInicial,
      valorAcumulado: valorInicial,
      dataInicio: new Date(dataBaseDate.getTime())
    }]

    const getLastDayOfMonth = (year: number, month: number) => {
      return new Date(year, month + 1, 0).getDate()
    }
    const clampDay = (year: number, month: number, targetDay: number) => {
      const lastDay = getLastDayOfMonth(year, month)
      return Math.min(targetDay, lastDay)
    }

    let nextContrYear = dataBaseDate.getFullYear()
    let nextContrMonth = dataBaseDate.getMonth()
    if (dataBaseDate.getDate() >= diaAporte) {
      nextContrMonth += 1
      if (nextContrMonth > 11) {
        nextContrMonth = 0
        nextContrYear += 1
      }
    }
    
    let nextContrDay = clampDay(nextContrYear, nextContrMonth, diaAporte)
    let nextContributionDate = new Date(nextContrYear, nextContrMonth, nextContrDay)

    let resgateLiquidoAnterior = valorInicial
    const resultados = []

    const getIofRate = (days: number) => {
      if (days >= 30) return 0
      const iofTable = [
        100, 96, 93, 90, 86, 83, 80, 76, 73, 70, 66,
        63, 60, 56, 53, 50, 46, 43, 40, 36, 33, 30,
        26, 23, 20, 16, 13, 10, 6, 3
      ]
      return iofTable[days] || 0
    }

    const getIrRate = (days: number) => {
      if (days <= 180) return 22.5
      if (days <= 360) return 20.0
      if (days <= 720) return 17.5
      return 15.0
    }

    for (const dia of fullDataSequence) {
      const currentDate = parseDateBR(dia.data)
      const taxaDia = parseFloat(dia.valor)
      
      let isAporteDay = false
      if (!dia.isWeekend && !dia.isHoliday && currentDate.getTime() >= nextContributionDate.getTime() && aporteMensal > 0) {
        tranches.push({
          valorInicial: aporteMensal,
          valorAcumulado: aporteMensal,
          dataInicio: new Date(currentDate.getTime())
        })
        isAporteDay = true
        
        nextContrMonth += 1
        if (nextContrMonth > 11) {
          nextContrMonth = 0
          nextContrYear += 1
        }
        nextContrDay = clampDay(nextContrYear, nextContrMonth, diaAporte)
        nextContributionDate = new Date(nextContrYear, nextContrMonth, nextContrDay)
      }

      let rendimentoDiaTotal = 0
      for (const tranche of tranches) {
        const rendimento = tranche.valorAcumulado * ((taxaDia / 100) * (percentualCdi / 100))
        tranche.valorAcumulado += rendimento
        rendimentoDiaTotal += rendimento
      }

      let totalAcumuladoBruto = 0
      let totalAportado = 0
      let totalIof = 0
      let totalIr = 0

      for (const tranche of tranches) {
        totalAcumuladoBruto += tranche.valorAcumulado
        totalAportado += tranche.valorInicial

        const diffTime = currentDate.getTime() - tranche.dataInicio.getTime()
        const diffDays = Math.max(1, Math.floor(diffTime / (1000 * 60 * 60 * 24)) + 1)
        
        const lucroTranche = tranche.valorAcumulado - tranche.valorInicial
        const iofTranche = lucroTranche * (getIofRate(diffDays) / 100)
        totalIof += iofTranche

        const baseIr = lucroTranche - iofTranche
        const irTranche = baseIr * (getIrRate(diffDays) / 100)
        totalIr += irTranche
      }

      let resgateLiquido = totalAcumuladoBruto - totalIof - totalIr
      
      if (dia.isWeekend || dia.isHoliday) {
        resgateLiquido = resgateLiquidoAnterior
      }

      const rendimentoLiquidoDia = resgateLiquido - resgateLiquidoAnterior
      resgateLiquidoAnterior = resgateLiquido

      resultados.push({
        data: dia.data,
        taxaDia: taxaDia,
        rendimentoDia: rendimentoDiaTotal,
        valorAcumulado: totalAcumuladoBruto,
        valorIof: totalIof,
        valorIr: totalIr,
        resgateLiquido: resgateLiquido,
        rendimentoLiquidoDia: rendimentoLiquidoDia,
        isProjecao: dia.isProjecao || false,
        isWeekend: dia.isWeekend,
        isHoliday: dia.isHoliday,
        holidayName: dia.holidayName,
        isAporteDay: isAporteDay
      })
    }

    const finalResgate = resultados.length > 0 ? resultados[resultados.length - 1].resgateLiquido : valorInicial
    let totalAportadoFinal = tranches.reduce((sum, t) => sum + t.valorInicial, 0)

    return c.json({
      resultados,
      valorFinal: finalResgate,
      lucroTotal: finalResgate - totalAportadoFinal,
      totalAportado: totalAportadoFinal,
      taxaAtual: taxaAtual
    })
  } catch (error: any) {
    return c.json({ error: 'Falha ao buscar dados do BCB', details: error.message }, 500)
  }
})

export default app
