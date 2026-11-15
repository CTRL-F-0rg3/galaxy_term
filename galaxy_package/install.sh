#!/bin/bash
echo "🚀 Instalowanie Galaxy Terminal..."

# Tworzenie katalogów docelowych (jeśli nie istnieją)
mkdir -p ~/.local/bin
mkdir -p ~/.local/share/applications
mkdir -p ~/.local/share/icons/hicolor/scalable/apps

# Kopiowanie plików
cp galaxy-term ~/.local/bin/
chmod +x ~/.local/bin/galaxy-term
cp galaxy-term.desktop ~/.local/share/applications/
cp galaxy-term.svg ~/.local/share/icons/hicolor/scalable/apps/

# Odświeżenie menu systemowego i ikon
update-desktop-database ~/.local/share/applications/ 2>/dev/null || true
gtk-update-icon-cache ~/.local/share/icons/hicolor 2>/dev/null || true

echo "✅ Sukces! Możesz uruchomić 'Galaxy Terminal' z menu lub wpisując 'galaxy-term' w terminalu."
