import { test } from 'node:test'

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

const taxaDia = 0.040168
const percentualCdi = 100

// Scenario 1: Just 1000 for 180 days
let val1 = 1000
for (let i = 0; i < 180; i++) {
  val1 += val1 * ((taxaDia/100) * (percentualCdi/100))
}
let lucro1 = val1 - 1000
let ir1 = lucro1 * 0.225
let net1 = lucro1 - ir1
console.log("No Aporte -> Gross:", val1.toFixed(2), "Net Profit:", net1.toFixed(2))

// Scenario 2: 1000 + 100/mo for 180 days (6 months)
interface Tranche { valInit: number, valAcum: number, startDay: number }
let tranches: Tranche[] = [ { valInit: 1000, valAcum: 1000, startDay: 0 } ]

for (let day = 0; day < 180; day++) {
  if (day > 0 && day % 30 === 0) {
    tranches.push({ valInit: 100, valAcum: 100, startDay: day })
  }
  for (let t of tranches) {
    t.valAcum += t.valAcum * ((taxaDia/100) * (percentualCdi/100))
  }
}

let totalNetProfit = 0
for (let t of tranches) {
  let diffDays = 180 - t.startDay
  let lucro = t.valAcum - t.valInit
  let iof = lucro * (getIofRate(diffDays) / 100)
  let baseIr = lucro - iof
  let ir = baseIr * (getIrRate(diffDays) / 100)
  let netLucro = lucro - iof - ir
  totalNetProfit += netLucro
}
console.log("With Aportes -> Net Profit:", totalNetProfit.toFixed(2))
