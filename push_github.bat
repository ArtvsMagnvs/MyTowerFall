@echo off
cd /d "C:\Users\Alejandro\Desktop\My Tower Fall"

echo === Inicializando repositorio git ===
git init -b main

echo === Configurando usuario ===
git config user.name "Artvs"
git config user.email "alexandros.olmo.magno@gmail.com"

echo === Conectando con GitHub ===
git remote add origin https://github.com/ArtvsMagnvs/MyTowerFall.git

echo === Añadiendo archivos ===
git add .

echo === Creando commit inicial ===
git commit -m "v0.8.3: Niide El Circulo Darico - mecanicas completas"

echo === Subiendo a GitHub (se pediran credenciales si no estan guardadas) ===
git push -u origin main

echo.
echo === HECHO ===
pause
