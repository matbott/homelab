#!/bin/bash

# Variables de configuración
VERSION="1.3.0"
FILE="figurine_linux_amd64_v${VERSION}.tar.gz"
URL="https://github.com/arsham/figurine/releases/download/v${VERSION}/${FILE}"
TEMP_DIR=$(mktemp -d)
INSTALL_DIR="/usr/local/bin"
BIN_PATH="${INSTALL_DIR}/figurine"
FONT_DIR="/usr/share/figurine-fonts"
FONT_NAME="3d.flf"
FONT_URL="https://unpkg.com/figlet/fonts/3d.flf"
PROFILE_SCRIPT="/etc/profile.d/figurine.sh" # Script que se ejecutará al iniciar sesión

echo "[*] Iniciando instalación de Figurine v$VERSION..."

# Limpiar instalación anterior si existe
if command -v figurine &> /dev/null; then
    echo "[*] Eliminando binario 'figurine' de instalación anterior..."
    sudo rm -f "$BIN_PATH"
fi
if [[ -f "$PROFILE_SCRIPT" ]]; then
    echo "[*] Eliminando script de bienvenida anterior: $PROFILE_SCRIPT"
    sudo rm -f "$PROFILE_SCRIPT"
fi
if [[ -d "$FONT_DIR" ]]; then
    echo "[*] Eliminando directorio de fuentes anterior: $FONT_DIR"
    sudo rm -rf "$FONT_DIR"
fi


# Descargar Figurine
echo "[*] Descargando Figurine desde $URL..."
if ! wget -qO "${TEMP_DIR}/${FILE}" "$URL"; then
    echo "[ERROR] No se pudo descargar Figurine. Verifica la conexión a internet y la URL."
    rm -rf "$TEMP_DIR"
    exit 1
fi
echo "[✓] Figurine descargado correctamente."

# Extraer el paquete
echo "[*] Extrayendo archivos de Figurine..."
if ! tar -xf "${TEMP_DIR}/${FILE}" -C "$TEMP_DIR"; then
    echo "[ERROR] No se pudo extraer el archivo. Es posible que el archivo descargado esté corrupto o no sea un tar.gz válido."
    rm -rf "$TEMP_DIR"
    exit 1
fi
echo "[✓] Extracción completada."

# Buscar el binario 'figurine' en el directorio extraído
echo "[*] Buscando el binario ejecutable 'figurine'..."
FIGURINE_BIN_TEMP=$(find "$TEMP_DIR" -maxdepth 2 -name "figurine" -type f -executable | head -1)

if [[ -z "$FIGURINE_BIN_TEMP" ]]; then
    echo "[ERROR] No se encontró el binario 'figurine' en el archivo extraído."
    echo "[INFO] Contenido del archivo extraído:"
    ls -la "$TEMP_DIR"
    find "$TEMP_DIR" -type f -executable
    rm -rf "$TEMP_DIR"
    exit 1
fi

echo "[✓] Binario 'figurine' encontrado en: $FIGURINE_BIN_TEMP"

# Mover y dar permisos al binario
echo "[*] Instalando binario en $INSTALL_DIR..."
sudo cp "$FIGURINE_BIN_TEMP" "$BIN_PATH"
sudo chmod +x "$BIN_PATH"

# Verificar instalación del binario y si es ejecutable
if [[ ! -f "$BIN_PATH" ]] || ! "$BIN_PATH" version &> /dev/null; then
    echo "[ADVERTENCIA] El binario de Figurine se copió, pero no parece funcionar correctamente ('$BIN_PATH version' falló)."
    echo "[ADVERTENCIA] El banner de Figurine podría no mostrarse."
    # No salimos aquí, permitimos que el resto del script se ejecute para el banner informativo
else
    echo "[✓] Binario 'figurine' instalado y verificado."
fi

# Instalar fuente (opcional, pero mejora el banner)
echo "[*] Instalando fuente '$FONT_NAME' para Figurine..."
sudo mkdir -p "$FONT_DIR"
if ! sudo curl -sL "$FONT_URL" -o "$FONT_DIR/$FONT_NAME"; then
    echo "[ADVERTENCIA] No se pudo descargar la fuente, Figurine usará su fuente por defecto."
    FONT_NAME_FOR_BANNER="" 
    FONT_DIR_FOR_BANNER=""  
else
    echo "[✓] Fuente '$FONT_NAME' instalada en $FONT_DIR."
    FONT_NAME_FOR_BANNER="$FONT_NAME" # Solo el nombre del archivo
    FONT_DIR_FOR_BANNER="$FONT_DIR"    # El directorio de la fuente
fi

# Crear script de bienvenida con información del sistema simplificada
echo "[*] Configurando el script de bienvenida en $PROFILE_SCRIPT..."
# Usamos un heredoc sin comillas (EOF) para que las variables de shell ($BIN_PATH, etc.)
# se expandan durante la creación de este archivo.
sudo tee "$PROFILE_SCRIPT" > /dev/null << EOF
#!/bin/bash

# Colores ANSI para una mejor visualización
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
GRAY='\033[0;37m'
BOLD='\033[1m'
RESET='\033[0m' # Restablece todos los atributos a su valor por defecto

# Variables para el path del binario de figurine y la fuente
# Estos valores se inyectan desde el script de instalación principal
FIGURINE_BIN="${BIN_PATH}"
FIGURINE_FONT_DIR="${FONT_DIR_FOR_BANNER}"
FIGURINE_FONT_NAME="${FONT_NAME_FOR_BANNER}"

# Función para mostrar la información del sistema
show_system_info() {
    # Solo ejecutar en una sesión de terminal interactiva y si no es un terminal "dumb"
    # Se eliminó la condición SSH_TTY para que se muestre en todas las consolas.
    if [[ -t 1 ]] && [[ "\$TERM" != "dumb" ]]; then
        clear # Limpia la pantalla al iniciar la sesión de terminal
        echo ""

        # Intenta mostrar el hostname con Figurine (ASCII Art)
        local figurine_cmd="\${FIGURINE_BIN}"
        if [[ -n "\${FIGURINE_FONT_DIR}" && -n "\${FIGURINE_FONT_NAME}" ]]; then
            export FIGURINE_FONT_DIR="\${FIGURINE_FONT_DIR}" # Exporta la variable de entorno para figurine
            figurine_cmd="\${FIGURINE_BIN} -f \${FIGURINE_FONT_NAME}" # Pasa solo el nombre del archivo de la fuente
        fi

        if [[ -x "\${FIGURINE_BIN}" ]]; then
            FIGURINE_OUTPUT=\$( \${figurine_cmd} "\$(hostname)" 2>&1 )
            
            if [[ \$? -eq 0 && -n "\$FIGURINE_OUTPUT" ]]; then
                echo -e "\${CYAN}\${BOLD}"
                echo "\$FIGURINE_OUTPUT"
                echo -e "\${RESET}"
            else
                # Fallback si figurine falla o no produce salida
                echo -e "\${CYAN}\${BOLD}=== \$(hostname) ===${RESET}"
                echo -e "\${RED}  [ADVERTENCIA] Figurine no pudo generar el banner (Error: '\$(echo "\$FIGURINE_OUTPUT" | head -n 1)').${RESET}"
            fi
        else
            # Fallback si el binario de figurine no se encuentra o no es ejecutable
            echo -e "\${CYAN}\${BOLD}=== \$(hostname) ===${RESET}"
            echo -e "\${RED}  [ADVERTENCIA] Binario de Figurine no encontrado o no es ejecutable en: \${FIGURINE_BIN}${RESET}"
        fi
        
        echo "" # Espacio después del banner de figurine

        # INFORMACIÓN DEL SISTEMA (SIMPLE Y SIN MARCOS)
        echo -e "${YELLOW}${BOLD}INFORMACIÓN DEL SISTEMA:${RESET}"
        echo "" # Espacio adicional

        # Información básica del sistema
        OS_INFO=\$(grep "PRETTY_NAME" /etc/os-release 2>/dev/null | cut -d'"' -f2 || echo "N/A")
        KERNEL=\$(uname -r 2>/dev/null || echo "N/A")
        UPTIME=\$(uptime -p 2>/dev/null | sed 's/up //g' || echo "N/A")
        
        printf "${GREEN}${BOLD}🌐 Sistema:${RESET} %s\n" "\${OS_INFO}"
        printf "${GREEN}${BOLD}🧠 Kernel: ${RESET} %s\n" "\${KERNEL}"
        printf "${GREEN}${BOLD}⏰ Uptime: ${RESET} %s\n" "\${UPTIME}"
        
        echo "" # Separador

        # CPU
        CPU_MODEL=\$(grep "model name" /proc/cpuinfo 2>/dev/null | head -1 | cut -d':' -f2 | sed 's/^ *//' || echo "N/A")
        CPU_CORES=\$(nproc 2>/dev/null || echo "N/A")
        
        # Uso de CPU (intentando mpstat o top como fallback)
        CPU_USAGE="N/A"
        if command -v mpstat &>/dev/null; then
            CPU_USAGE=\$(mpstat -u 1 1 2>/dev/null | tail -n 1 | awk '{print 100 - \$NF}' | cut -d. -f1 || echo "0")
        elif command -v top &> /dev/null && command -v awk &> /dev/null; then
            CPU_USAGE=\$(top -bn1 2>/dev/null | grep "Cpu(s)" | awk '{print \$2}' | sed 's/[^0-9.]*//g' | cut -d. -f1 || echo "0")
        fi

        printf "${MAGENTA}${BOLD}💻 CPU: ${RESET}%s (Cores: %s)\n" "\${CPU_MODEL}" "\$CPU_CORES"
        printf "${MAGENTA}${BOLD}📊 Uso CPU:${RESET} %s%%\n" "\${CPU_USAGE}"
        
        echo "" # Separador

        # Memoria
        MEM_TOTAL_GB="N/A"
        MEM_USED_GB="N/A"
        
        MEM_TOTAL_KB_PROC=\$(awk '/MemTotal:/ {print \$2}' /proc/meminfo 2>/dev/null)
        MEM_AVAIL_KB_PROC=\$(awk '/MemAvailable:/ {print \$2}' /proc/meminfo 2>/dev/null)

        if [[ -n "\$MEM_TOTAL_KB_PROC" && -n "\$MEM_AVAIL_KB_PROC" && "\$MEM_TOTAL_KB_PROC" -gt 0 ]]; then
            MEM_USED_KB=\$((MEM_TOTAL_KB_PROC - MEM_AVAIL_KB_PROC))
            MEM_TOTAL_GB=\$((MEM_TOTAL_KB_PROC / 1024 / 1024))
            MEM_USED_GB=\$((MEM_USED_KB / 1024 / 1024))
            # Asegurar que los GB sean al menos 1 si el total es > 0 y menor a 1GB
            if [[ "\$MEM_TOTAL_GB" -eq 0 && "\$MEM_TOTAL_KB_PROC" -gt 0 ]]; then MEM_TOTAL_GB=1; fi
            if [[ "\$MEM_USED_GB" -eq 0 && "\$MEM_USED_KB" -gt 0 ]]; then MEM_USED_GB=1; fi
        elif command -v free &>/dev/null; then # Fallback a free -m
            MEM_INFO=\$(free -m 2>/dev/null | grep "Mem:" || echo "")
            if [[ -n "\$MEM_INFO" ]]; then
                MEM_TOTAL_MB=\$(echo "\$MEM_INFO" | awk '{print \$2}')
                MEM_USED_MB=\$(echo "\$MEM_INFO" | awk '{print \$3}')
                MEM_TOTAL_GB=\$((MEM_TOTAL_MB / 1024))
                MEM_USED_GB=\$((MEM_USED_MB / 1024))
                if [[ "\$MEM_TOTAL_GB" -eq 0 && "\$MEM_TOTAL_MB" -gt 0 ]]; then MEM_TOTAL_GB=1; fi
                if [[ "\$MEM_USED_GB" -eq 0 && "\$MEM_USED_MB" -gt 0 ]]; then MEM_USED_GB=1; fi
            fi
        fi

        printf "${BLUE}${BOLD}💾 Memoria:${RESET} ${YELLOW}%sGB${RESET} / ${YELLOW}%sGB${RESET}\n" "\${MEM_USED_GB}" "\${MEM_TOTAL_GB}"
        
        echo "" # Separador

        # Disco (partición raíz)
        DISK_USED_GB="N/A"
        DISK_TOTAL_GB="N/A"
        
        DISK_INFO=\$(df -BG / 2>/dev/null | tail -1 || echo "")
        if [[ -n "\$DISK_INFO" ]]; then
            # Extraer los valores con "G" y luego limpiar
            DISK_TOTAL_RAW=\$(echo "\$DISK_INFO" | awk '{print \$2}' | sed 's/G//')
            DISK_USED_RAW=\$(echo "\$DISK_INFO" | awk '{print \$3}' | sed 's/G//')
            
            # Asignar a las variables solo si son números, y asegurar que sean al menos 1GB si no es 0
            if [[ "\$DISK_TOTAL_RAW" =~ ^[0-9]+$ ]]; then DISK_TOTAL_GB=\$DISK_TOTAL_RAW; fi
            if [[ "\$DISK_TOTAL_GB" -eq 0 && "\$DISK_TOTAL_RAW" -gt 0 ]]; then DISK_TOTAL_GB=1; fi

            if [[ "\$DISK_USED_RAW" =~ ^[0-9]+$ ]]; then DISK_USED_GB=\$DISK_USED_RAW; fi
            if [[ "\$DISK_USED_GB" -eq 0 && "\$DISK_USED_RAW" -gt 0 ]]; then DISK_USED_GB=1; fi
        fi

        printf "${CYAN}${BOLD}💽 Disco:  ${RESET} ${YELLOW}%sGB${RESET} / ${YELLOW}%sGB${RESET}\n" "\${DISK_USED_GB}" "\${DISK_TOTAL_GB}"
        
        echo "" # Separador
        
        # Red e información adicional
        IP_LOCAL=\$(hostname -I 2>/dev/null | awk '{print \$1}' || echo "N/A")
        PROCESSES=\$(ps aux 2>/dev/null | wc -l || echo "N/A")
        LOAD_AVG=\$(uptime 2>/dev/null | awk -F'load average:' '{print \$2}' | sed 's/^ *//' | cut -d, -f1 || echo "N/A")
        
        printf "${YELLOW}${BOLD}🌐 IP Local:  ${RESET} %s\n" "\$IP_LOCAL"
        printf "${GRAY}${BOLD}⚙️  Procesos:  ${RESET} %s\n" "\$PROCESSES"
        printf "${GRAY}${BOLD}📈 Load Avg:  ${RESET} %s\n" "\$LOAD_AVG"
        printf "${GRAY}${BOLD}📅 Fecha:     ${RESET} %s\n" "\$(date '+%Y-%m-%d %H:%M')"
        
        echo ""
        echo -e "${GREEN}${BOLD}🚀 ¡Bienvenido al sistema!${RESET} ${BLUE}Disfruta tu sesión${RESET}"
        echo ""
    fi
}

show_system_info
EOF

# Dar permisos de ejecución al script de bienvenida
sudo chmod +x "$PROFILE_SCRIPT"
echo "[✓] Script de bienvenida creado y configurado en $PROFILE_SCRIPT"

# Limpieza de archivos temporales
rm -rf "$TEMP_DIR"

echo "[✓] Instalación de Figurine finalizada completamente."
echo ""
echo "Para verificar el funcionamiento de Figurine, puedes ejecutar:"
echo "  /usr/local/bin/figurine \"Hola Mundo\""
echo ""
echo "El mensaje de bienvenida simplificado se mostrará automáticamente al iniciar CADA nueva sesión de terminal."
echo "Para verlo ahora, abre una nueva terminal o ejecuta: source /etc/profile.d/figurine.sh"
echo ""
