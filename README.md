# Acadex

This repository now contains:

- `mobile_app`: original Flutter mobile app
- `web_app`: migrated Web frontend (React + Vite + Supabase)

## Run Web locally

```bash
cd web_app
npm install
cp .env.example .env.local
# fill VITE_SUPABASE_URL and VITE_SUPABASE_ANON_KEY
npm run dev
```