# Simulador CDI 🚀

Um ecossistema completo para simulação de investimentos em Renda Fixa (CDI), com cálculo preciso de impostos (IOF e IR Regressivo), juros compostos e tratamento de dias úteis e feriados com base nas métricas oficiais do Banco Central do Brasil.

## 🏗️ Arquitetura do Projeto

Este projeto é dividido em 3 grandes pilares:

### 1. Backend API (`/api`)
O cérebro matemático da operação. Uma API ultrarrápida construída com **Hono** e **TypeScript** hospedada de forma distribuída no Cloudflare Workers. 
Ela consome dados do Banco Central e realiza iterações diárias calculando o rendimento bruto, o desconto exato de impostos baseados na idade de cada aporte (subcontas) e isolando feriados bancários.
- **Produção:** `https://api.desenvolvimento-0d9.workers.dev`

### 2. Frontend Web (`/web`)
Uma interface de luxo desenvolvida em **Vue 3** + **Vite** + **TailwindCSS** hospedada no Cloudflare Pages.
Ideal para uso em Desktop, com geração de relatórios em PDF, comparação de múltiplos cenários lado a lado, gráficos em área fluídos (Chart.js) e um sistema inteligente de histórico de consultas locais (`localStorage`).
- **Acesse agora:** [https://simulador-cdi.pages.dev](https://simulador-cdi.pages.dev)

### 3. App Mobile Nativo (`/mobile`)
O simulador na palma da mão, desenvolvido em **Flutter** (Dart).
Um aplicativo nativo com layout Material Design 3, focado em facilidade de uso, com animações suaves, gráficos didáticos (`fl_chart`) e o extrato diário vertical das finanças.
O aplicativo se conecta perfeitamente à API Hono local.

---

## 🚀 Como Executar

### Pré-requisitos
- Node.js (v18+)
- Flutter SDK (v3.41+)
- Emulador Android (opcional, para rodar nativamente) ou Edge/Chrome (para rodar Flutter Web).

### Iniciando a API (Cérebro)
```bash
cd api
npm install
npm run dev
```

### Iniciando a Plataforma Web
Em um novo terminal:
```bash
cd web
npm install
npm run dev
```

### Iniciando o Aplicativo Mobile (Flutter)
Em um novo terminal:
```bash
cd mobile
flutter run
```
*(Você pode rodar no Edge usando `flutter run -d edge` ou iniciar seu Emulador Android preferido e rodar `flutter run` nativamente).*

---

## 📈 Lógica de "Subcontas" (Aportes Mensais)

O grande diferencial deste simulador é o motor de cálculo para "Aportes Mensais". A maioria dos simuladores do mercado calcula o IOF e o Imposto de Renda de forma burra sobre o montante final. 

O **Simulador CDI Premium** separa cada aporte mensal em uma "subconta" ou "fatia" individual. Isso garante que:
1. O IOF só será cobrado no dinheiro que foi depositado há menos de 30 dias.
2. O IR de um aporte recente será de 22.5%, enquanto o IR do aporte inicial (se tiver mais de 2 anos) será de 15%.
3. Dias de fim de semana ou feriados bancários não geram descontos ilusórios, estabilizando o gráfico nos dias não-úteis.

---

*Desenvolvido com precisão e estética de banco digital.*

---

**Criado Por:** [Jorge Miguel](https://jorgemiguel.wc4.com.br/)
**Código Fonte:** [GitHub](https://github.com/jorgemiguel)
