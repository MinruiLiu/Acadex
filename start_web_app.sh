#!/usr/bin/env bash
set -euo pipefail

# Repo root = directory containing this script
cd "$(dirname "$0")"

if [[ ! -d web_app ]]; then
  echo "[ERROR] web_app folder not found."
  exit 1
fi

cd web_app

if [[ ! -d node_modules ]]; then
  echo "Installing dependencies..."
  npm install
fi

echo "Starting web app..."
npm run dev
