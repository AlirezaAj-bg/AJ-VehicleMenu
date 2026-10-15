const { createApp } = Vue;

const DRIVER_ONLY_TABS = ['drive', 'lights', 'extras'];

const emptyState = () => ({
    engine: false, lights: false, highbeam: false, cabin: false, indicator: 0,
    doors: [false, false, false, false, false, false],
    windows: [false, false, false, false],
    neon: [false, false, false, false], neonColor: [255, 255, 255],
    xenon: false, siren: false, alarm: false, locked: false, extras: {},
    driving: { cruise: { on: false, speed: 0 }, limiter: { on: false, speed: 80 }, mode: 'comfort', launch: false, tcs: true },
});

createApp({
    data() {
        return {
            open: false,
            context: 'driver',
            tab: 'control',
            vehicle: { name: '', plate: '', doors: [], windows: [], extras: [], seats: 0 },
            state: emptyState(),
            stats: { speed: 0, rpm: 0, gear: 0, fuel: 0, engine: 0, body: 0, seats: [] },
            perms: { context: 'driver', passenger: {}, remote: {} },
            config: { unit: 'KM/H', keepInput: false, driveModes: [], defaultMode: 'comfort', itemLabels: {}, limiter: { min: 20, max: 250, default: 80 }, cruiseStep: 5, ownCruise: true },
            limiterDraft: 80,
            pending: [],          // optimistic UI: [{ path: ['doors', 2], value, until }]
            windowTiles: [
                { i: 0, label: 'Front L' }, { i: 1, label: 'Front R' },
                { i: 2, label: 'Rear L' }, { i: 3, label: 'Rear R' },
            ],
            tabs: [
                { id: 'control', label: 'Control', icon: 'control' },
                { id: 'drive', label: 'Drive', icon: 'cruise' },
                { id: 'lights', label: 'Lights', icon: 'neon' },
                { id: 'extras', label: 'Extras', icon: 'extras' },
            ],
        };
    },

    computed: {
        contextLabel() {
            if (this.context === 'remote') return 'Keyfob';
            if (this.context === 'driver') return 'Driver';
            return 'Passenger · Seat ' + ((this.perms.seat ?? 0) + 2);
        },
        drv() { return this.state.driving || emptyState().driving; },
        gearLabel() {
            if (!this.state.engine) return 'P';
            if (this.stats.gear === 0) return this.stats.speed > 1 ? 'R' : 'N';
            return 'G' + this.stats.gear;
        },
        rpmLit() { return Math.round(Math.max(0, Math.min(1, this.stats.rpm || 0)) * 26); },
        rangePct() { return Math.max(0, 100 - ((this.stats.distance || 0) / 25) * 100); },
        gauges() {
            const tone = (v) => (v <= 20 ? 'bad' : v <= 45 ? 'warn' : 'ok');
            return [
                { key: 'fuel', label: 'Fuel', icon: 'fuel', value: this.stats.fuel || 0, tone: tone(this.stats.fuel || 0) },
                { key: 'engine', label: 'Engine', icon: 'wrench', value: this.stats.engine || 0, tone: tone(this.stats.engine || 0) },
                { key: 'body', label: 'Body', icon: 'health', value: this.stats.body || 0, tone: tone(this.stats.body || 0) },
            ];
        },
        modeHint() {
            const hints = {
                eco: 'Softer throttle, less torque. Saves fuel.',
                comfort: 'Stock tuning, balanced response.',
                sport: 'Sharper throttle and extra power.',
            };
            const base = hints[this.drv.mode] || '';
            if (this.drv.launch === 'armed') return 'Launch armed: hold brake + throttle, then release the brake.';
            return base;
        },
        occupied() { return (this.stats.seats || []).filter((s) => s.occupied).length; },
        anyDoorOpen() { return this.state.doors.some((d, i) => d && this.vehicle.doors[i]); },
        anyWindowDown() { return this.state.windows.some(Boolean); },
        anyNeon() { return this.state.neon.some(Boolean); },
        neonCss() { return 'rgb(' + (this.state.neonColor || [255, 255, 255]).join(',') + ')'; },
        visibleTabs() {
            return this.tabs.filter((t) => {
                if (this.context === 'passenger' && DRIVER_ONLY_TABS.includes(t.id)) return false;
                if (t.id === 'drive' && !this.vehicle.drivingTools) return false;
                if (t.id === 'extras' && !this.vehicle.extras.length) return false;
                return true;
            });
        },
        gliderStyle() {
            const idx = Math.max(0, this.visibleTabs.findIndex((t) => t.id === this.tab));
            return { width: `calc(${100 / this.visibleTabs.length}% - 4px)`, transform: `translateX(calc(${idx * 100}% + ${idx * 4}px))` };
        },
        // seat dots on the top-down car diagram (driver front-left)
        carSeats() {
            const pos = [[56, 118], [84, 118], [56, 152], [84, 152], [70, 135]];
            return (this.stats.seats || []).slice(0, 4).map((s, i) => ({ ...s, x: pos[i][0], y: pos[i][1] }));
        },
    },

    methods: {
        icon(name) { return (window.VM_ICONS && window.VM_ICONS[name]) || ''; },
        pad(n) { return String(Math.max(0, n || 0)).padStart(3, '0'); },

        can(id, value) {
            const ctx = this.context;
            if (ctx === 'driver') return true;
            if (ctx === 'passenger') {
                const p = this.perms.passenger || {};
                if (id === 'seat') return !!p.seat;
                if (id === 'cabin') return !!p.cabin;
                if (id === 'window') {
                    if (p.window === true) return true;
                    if (p.window === 'own') return value === undefined ? true : value === this.perms.ownWindow;
                }
                return false;
            }
            if (ctx === 'remote') return !!(this.perms.remote || {})[id];
            return false;
        },

        act(id, value) {
            if (!this.can(id, value)) return;
            this.predict(id, value);
            postNui('action', { id, value });
        },

        // Flip the tile/diagram right away instead of waiting for the game to report it back
        // (doors in particular take ~1s to swing far enough to register as open).
        predict(id, value) {
            const st = this.state;
            const set = (path, v) => {
                this.pending = this.pending.filter((p) => p.path.join('.') !== path.join('.'));
                this.pending.push({ path, value: v, until: Date.now() + 1800 });
            };
            const flip = (path) => set(path, !this.getPath(st, path));
            switch (id) {
                case 'engine': case 'remoteEngine': flip(['engine']); break;
                case 'lights': case 'highbeam': case 'cabin': case 'xenon': case 'siren': case 'alarm': flip([id]); break;
                case 'lock': flip(['locked']); break;
                case 'door': flip(['doors', value]); break;
                case 'window': flip(['windows', value]); break;
                case 'neon': flip(['neon', value]); break;
                case 'extra': flip(['extras', String(value)]); break;
                case 'doorsAll': { const open = !this.anyDoorOpen; this.vehicle.doors.forEach((ok, i) => ok && set(['doors', i], open)); break; }
                case 'windowsAll': { const down = !this.anyWindowDown; [0, 1, 2, 3].forEach((i) => set(['windows', i], down)); break; }
                case 'neonAll': { const on = !this.anyNeon; [0, 1, 2, 3].forEach((i) => set(['neon', i], on)); break; }
                case 'indicator': { const want = value === 'left' ? 1 : 2; set(['indicator'], st.indicator === want ? 0 : want); break; }
                case 'hazards': set(['indicator'], st.indicator === 3 ? 0 : 3); break;
                default: return;
            }
            this.state = this.withPending(Object.assign({}, st), false);
        },

        getPath(obj, path) { return path.reduce((o, k) => (o == null ? undefined : o[k]), obj); },

        // confirm = true when `state` comes from the game: drop predictions the game now agrees with.
        withPending(state, confirm = true) {
            const now = Date.now();
            this.pending = this.pending.filter((p) => p.until > now && !(confirm && this.getPath(state, p.path) === p.value));
            for (const p of this.pending) {
                const parentPath = p.path.slice(0, -1);
                const key = p.path[p.path.length - 1];
                let parent = state;
                for (const k of parentPath) {
                    parent[k] = Array.isArray(parent[k]) ? parent[k].slice() : Object.assign({}, parent[k]);
                    parent = parent[k];
                }
                parent[key] = p.value;
            }
            return state;
        },

        hasItem(key) { return !this.state.items || this.state.items[key] !== false; },
        itemLabel(key) { return (this.config.itemLabels || {})[key] || 'required item'; },

        seat(s) {
            if (s.me || s.occupied || !this.can('seat')) return;
            this.act('seat', s.index);
        },

        close() { postNui('close'); },

        onMessage(e) {
            const d = e.data || {};
            if (d.action === 'open') {
                this.context = d.context;
                this.vehicle = d.vehicle;
                this.perms = d.perms || this.perms;
                this.config = Object.assign({}, this.config, d.config || {});
                this.applyState(d.state, d.stats);
                if (!this.open) this.pending = [];
                if (!this.open) this.limiterDraft = this.drv.limiter.speed || this.config.limiter.default;
                if (this.context === 'passenger' || !this.visibleTabs.some((t) => t.id === this.tab)) this.tab = 'control';
                this.open = true;
            } else if (d.action === 'update') {
                this.applyState(d.state, d.stats);
            } else if (d.action === 'close') {
                this.open = false;
            }
        },

        applyState(state, stats) {
            if (state) this.state = this.withPending(Object.assign(emptyState(), state));
            if (stats) this.stats = stats;
        },

        onKey(e) {
            if (!this.open) return;
            if (e.key === 'Escape') { this.close(); return; }
            if (this.context !== 'remote' && /^[1-9]$/.test(e.key)) {
                const s = (this.stats.seats || [])[Number(e.key) - 1];
                if (s) this.seat(s);
            }
        },
    },

    watch: {
        context(ctx) { if (ctx === 'passenger' && DRIVER_ONLY_TABS.includes(this.tab)) this.tab = 'control'; },
    },

    mounted() {
        window.addEventListener('message', this.onMessage);
        window.addEventListener('keydown', this.onKey);
    },
}).mount('#app');
