# Black Box frontend

React 19, TypeScript, Tailwind 4 and Pixi.js 8. All gameplay comes from Go over WebSocket.

## Development

```sh
npm ci
npm run dev
```

Start the backend separately on 127.0.0.1:8080. Vite serves 127.0.0.1:5173 and proxies /ws and /health.

```sh
npm run build
npm run typecheck
```

Build regenerates types from Go before checking TypeScript. The Go toolchain must therefore be available. The output is dist/, served by Fiber in production. npm run preview is only a static build preview; use the Go server for a working game.

## Boundaries

- useGame.ts: connection, reconnect, request IDs, responses and CSV downloads.
- generated/protocol.ts: generated transport types, goods, activities and roles.
- App.tsx: presentation state, input routing and saved camera/selection updates.
- world/WorldRenderer.ts: Pixi terrain, sprites, picking, depth ordering, camera and animation.
- components/: household/person/cell inspectors, minimap, charts, archive and experiment settings.

No inventory changes, movement planning, production, barter, births, deaths or random simulation draws occur in the browser. Visual noise is a coordinate hash. Movement interpolates keyframes whose timing is computed in Go from the original display rules. Adding animation should extend the renderer, not create a second simulation.

## Interface

The reference-inspired layout uses a dark glass HUD, gold and blue accents, an upper status bar, left map layers, right inspector and lower economy dashboard. The world is an isometric Pixi scene built from separate generated sprites.

Click Economy Overview for detailed production, trade, barter ratio, specialization and demographic charts. History loads 4096 days at a time; events load 100 records per page. The bottom live graph keeps 180 recent days. Missing observed barter ratios are gaps, not zero prices.

Click a hut, person or terrain cell to inspect it. Resource overlays can show berries, game, wood or stone. Space toggles play; 0–5 choose speed; WASD/arrows pan; scroll zooms; L follows the selected person.

## Artwork

All 22 new PNG assets live in public/art/. Objects have transparent backgrounds; three terrain textures are opaque. Assets were generated separately using the built-in image generator, following the supplied art direction. Original generated files were retained. [prompts.json](public/art/prompts.json) records each exact prompt.

| Group | Assets |
| --- | --- |
| Terrain | meadow, forest, rocky |
| Homes | hut-01, hut-02, hut-03 |
| Woodland | pine, oak, berry bush, stone deposit, deer, wood pile |
| People | man, woman, child, elder man, elder woman |
| Inventory | berries, meat, wood, stone, spear |

Lucide supplies interface icons. No screenshot text, sample economy numbers or invented seasons are used as game data. The reference's river, fishing and weather are not systems in the original simulation; the playable world preserves its three terrain kinds and five goods.

Desktop is the main layout. Compact layouts retain the controls and inspectors in narrow panels. The renderer respects reduced-motion CSS for UI transitions; world playback remains an observer animation controlled by pause.
