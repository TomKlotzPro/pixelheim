import { chromium } from "@playwright/test";
const browser = await chromium.launch({ args: ["--autoplay-policy=no-user-gesture-required"] });
const page = await browser.newPage();
const errors = [];
page.on("pageerror", (e) => errors.push(e.message));
page.on("console", (m) => m.type() === "error" && errors.push(m.text()));
await page.goto("http://localhost:4444/pixelheim/");
await page.getByRole("button", { name: "New Game" }).click();
await page.getByPlaceholder("Dragonsbane...").fill("DJ");
await page.getByRole("button", { name: "Begin the climb" }).click();
await page.getByRole("button", { name: /Mossy Cellar/ }).click();
for (let i = 0; i < 6; i++) { await page.getByRole("button", { name: "Attack", exact: true }).click().catch(() => {}); await page.waitForTimeout(80); }
await page.waitForTimeout(500);
console.log("pipeline errors:", errors.length ? errors : "none");
await browser.close();
