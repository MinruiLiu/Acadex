# Acadex Web Frontend

This folder contains the Web migration of the mobile app, built with React + Vite + Supabase.

## Features migrated from mobile

- Auth: email sign in / sign up / sign out
- Papers list: load all papers and group by `upload_batch_id`
- My Uploads: upload PDF/JPG/PNG to Supabase Storage and write metadata to `papers`
- Catalog: choose or create `schools` and `courses`
- Preview: open grouped papers in modal and preview PDF/image
- Delete: remove storage objects and related `papers` rows

## Localhost setup

1. Install dependencies:

```bash
npm install
```

2. Create env file:

```bash
cp .env.example .env.local
```

3. Fill Supabase values in `.env.local`:

```env
VITE_SUPABASE_URL=your_supabase_url
VITE_SUPABASE_ANON_KEY=your_supabase_anon_key
```

4. Start local server:

```bash
npm run dev
```

Vite will print a local URL (usually `http://localhost:5173`).
