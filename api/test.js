const getIofRate = (days) => {
  if (days >= 30) return 0
  const iofTable = [
    100, 96, 93, 90, 86, 83, 80, 76, 73, 70, 66,
    63, 60, 56, 53, 50, 46, 43, 40, 36, 33, 30,
    26, 23, 20, 16, 13, 10, 6, 3
  ]
  return iofTable[days] || 0
}

const getIrRate = (days) => {
  if (days <= 180) return 22.5
  if (days <= 360) return 20.0
  if (days <= 720) return 17.5
  return 15.0
}

const tranches = [
  { valorInicial: 1000, valorAcumulado: 1000, dataInicio: new Date('2026-01-01T00:00:00') }
]

const endDate = new Date('2026-06-30T00:00:00')
let currentDate = new Date('2026-01-01T00:00:00')
let nextContributionDate = new Date('2026-02-01T00:00:00')

const taxaDia = 0.040168
const percentualCdi = 100

let lastResgateLiquido = 1000

while(currentDate <= endDate) {
  const isWeekend = currentDate.getDay() === 0 || currentDate.getDay() === 6
  const isHoliday = false // skip for simplicity
  
  if (!isWeekend && currentDate.getTime() >= nextContributionDate.getTime()) {
    tranches.push({
      valorInicial: 100,
      valorAcumulado: 100,
      dataInicio: new Date(currentDate.getTime())
    })
    nextContributionDate.setMonth(nextContributionDate.getMonth() + 1)
  }

  for (const tranche of tranches) {
    if (!isWeekend) {
      const rendimento = tranche.valorAcumulado * ((taxaDia / 100) * (percentualCdi / 100))
      tranche.valorAcumulado += rendimento
    }
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
  
  if (isWeekend) {
    resgateLiquido = lastResgateLiquido
  } else {
    lastResgateLiquido = resgateLiquido
  }

  if (currentDate.getTime() === endDate.getTime()) {
    console.log("FINAL RESULTS:")
    console.log("Total Aportado:", totalAportado)
    console.log("Total Acumulado Bruto:", totalAcumuladoBruto)
    console.log("Total IOF:", totalIof)
    console.log("Total IR:", totalIr)
    console.log("Resgate Liquido:", resgateLiquido)
    console.log("Lucro Liquido:", resgateLiquido - totalAportado)
  }
  
  currentDate.setDate(currentDate.getDate() + 1)
}
