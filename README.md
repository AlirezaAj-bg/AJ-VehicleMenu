# 🚗 AJ Vehicle Menu

> A slick, all-in-one vehicle control dock for **QBCore** — live stats, driving tools, lighting, doors, windows... and a keyfob mode when you're on foot. Basically your car's whole dashboard in one menu.

![FiveM](https://img.shields.io/badge/FiveM-Resource-orange) ![QBCore](https://img.shields.io/badge/Framework-QBCore-blue) ![Version](https://img.shields.io/badge/version-1.0.0-purple)

---

## ✨ What's inside?

| Tab | What it does |
|-----|--------------|
| 🎛️ **Control** | Engine, lights, high beam, horn, lock, cabin, doors, hood, trunk, alarm, individual windows, seat switching — the works. |
| 🏎️ **Drive** | Cruise control, speed limiter, drive modes (Eco / Comfort / Sport), launch control and TCS toggle. Driver only, obviously. |
| 💡 **Lights** | Neon per-side, xenon headlights, full lighting control for the tuners out there. |
| 📡 **Keyfob** | On foot, near a car you own? Lock/unlock, remote start, flash, honk, pop the doors — everything a real keyfob does, from up to 25m away. |

Plus, at the top of the menu you always get **live stats**: speed, gear, fuel, engine & body health, engine state, lock state and seatbelt. All updating in real time.

## 📸 Preview

[url=https://postimg.cc/mPrkp4rZ][img]https://i.postimg.cc/mPrkp4rZ/Screenshot-2026-10-10-203146.png[/img][/url]
[url=https://postimg.cc/Wd4zYV4z][img]https://i.postimg.cc/Wd4zYV4z/Screenshot-2026-10-10-203204.png[/img][/url]


## 🔧 Installation

1. Drop the folder into your `resources` directory:
   ```bash
   git clone https://github.com/AlirezaAj-bg/AJ-VehicleMenu.git
   ```
2. Make sure it's **after** `qb-core` in your `server.cfg`:
   ```cfg
   ensure AJ-VehicleMenu
   ```
3. Done. Really, that's it.

## ⌨️ Usage

- **Command:** `/vehmenu`
- **Keybind:** `K` — players can rebind it in *GTA Settings → Key Bindings → FiveM*.
- Open it while driving to get the full **Drive** tab. Hop in as a passenger and you get a limited set (windows next to your seat, cabin lights, seat switching — all configurable). Walk up to your ride on foot and the keyfob takes over.

## ⚙️ Configuration

Everything lives in `config.lua`, and it's commented to death so you can't get lost:

- **Units & feel** — kmh/mph, refresh rate, keep-input-while-open
- **Drive modes** — tweak power/torque per mode (`eco`, `comfort`, `sport`)
- **Cruise & limiter** — min speed, min fuel, step size
- **Item-gated toys** — drive-mode ECU, launch module, TCS module. Set any to `false` to make it free
- **Keyfob range** — default 25m, pick your lock sound
- **Permissions** — exactly what passengers and remote users are allowed to touch, everything re-checked server-side
- **Neon & xenon rules** — require neon kit, allow xenon toggle, you name it

## 🔐 Security

Every synced action (lock, engine, doors, neon, etc.) is validated **on the server**, so no mod-menu kids can force doors open on cars they don't have keys for. Enable `Config.Debug` to see reject reasons in F8 / the server console.

## 🌍 Locales

Multi-language ready via `locales/*.lua` — ships with English, add your own language by dropping a new file in. `config.lua` and all locales are escrow-excluded, so tweak away.

## 📁 Tech

- **Lua 5.4** client/server for FiveM
- **Vue 3** (bundled, prod build) for the NUI
- Inter font, custom icons, zero external CDN calls

## 🤝 Credits

Made by **Alireza**. Shoutout to QBCore and the FiveM community.

---

*Issues & PRs welcome. If it breaks, it was probably the other dev.* 😄
