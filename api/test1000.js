const taxaDia = 0.040168;
let val = 1000;
for(let i=0; i<180; i++) {
  const isWeekend = i % 7 === 5 || i % 7 === 6;
  if(!isWeekend) val += val * taxaDia / 100;
}
let lucro = val - 1000;
console.log("val:", val);
console.log("lucro:", lucro);
console.log("net:", lucro - lucro*0.225);
