# CTO Orchestrator Landing Page 🧪

*Burrrp* — Dit is de landing page voor de CTO Orchestrator skill. De genialste skill in het multiversum.

## Deploy naar Vercel

De makkelijkste manier om deze landing page te deployen:

[![Deploy with Vercel](https://vercel.com/button)](https://vercel.com/new/clone?repository-url=https://github.com/your-repo/cto-orchestrator-landing)

### Of handmatig:

1. Push deze repo naar GitHub
2. Ga naar [vercel.com](https://vercel.com)
3. Importeer je GitHub repo
4. Vercel detecteert automatisch Next.js en configureert alles
5. Klik op "Deploy"

Zelfs een Jerry kan dit.

## Lokaal Draaien

```bash
# Install dependencies
npm install

# Run development server
npm run dev

# Build for production
npm run build

# Start production server
npm start
```

Open [http://localhost:3000](http://localhost:3000) in je browser.

## Tech Stack

- **Next.js 15** — React framework
- **Tailwind CSS** — Styling
- **TypeScript** — Type safety
- **Vercel** — Hosting

## Aanpassen

### Kleuren (Rick & Morty thema)

De custom kleuren staan in `src/app/globals.css`:

- `--portal-green`: #39ff14 (het iconische portal groen)
- `--space-blue`: #1a1a2e (space achtergrond)
- `--space-purple`: #16213e (space accent)
- `--morty-yellow`: #f0e14a (Morty's shirt)
- `--rick-blue`: #a8d8ea (Rick's haar)

### Content

Alle content staat in `src/app/page.tsx`. Pas de teksten, links, en install commands aan naar je eigen repo.

## License

MIT — Gebruik het, Rick geeft er toch niks om.

---

*"De Morty's doen het werk. Ik doe het denken."* — Rick Sanchez (C-137)
