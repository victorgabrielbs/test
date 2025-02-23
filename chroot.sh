#!/bin/bash
# Este script deve ser executado dentro do chroot.
if [ "$(id -u)" -ne 0 ]; then
    echo "Este script precisa ser executado como root (dentro do chroot)."
    exit 1
fi

echo "=== Instalação DENTRO DO CHROOT para Exherbo ==="
echo

# Opcional: montar /proc, /sys e /dev se ainda não estiverem montados
read -p "Deseja montar /proc, /sys e /dev (caso ainda não estejam montados)? (S/n): " MOUNT_SYS
MOUNT_SYS=${MOUNT_SYS:-S}
if [[ "$MOUNT_SYS" =~ ^[Ss] ]]; then
    mount -t proc proc /proc
    mount --rbind /sys /sys
    mount --rbind /dev /dev
    echo "Sistemas de arquivos montados."
fi

# 1. Configurar Paludis e sincronizar as árvores
read -p "Deseja configurar o Paludis e sincronizar as árvores (cave sync)? (S/n): " CONFIG_PALUDIS
CONFIG_PALUDIS=${CONFIG_PALUDIS:-S}
if [[ "$CONFIG_PALUDIS" =~ ^[Ss] ]]; then
    cd /etc/paludis || { echo "Não foi possível acessar /etc/paludis"; exit 1; }
    echo "Configure os arquivos de configuração do Paludis conforme necessário."
    read -p "Pressione Enter para continuar após verificar as configurações..."
    cave sync || { echo "Erro ao sincronizar as árvores"; exit 1; }
fi

# 2. Instalar ou atualizar o kernel
read -p "Deseja instalar/atualizar o kernel? (S/n): " INSTALL_KERNEL
INSTALL_KERNEL=${INSTALL_KERNEL:-S}
if [[ "$INSTALL_KERNEL" =~ ^[Ss] ]]; then
    echo "Selecione a opção:"
    echo "1 - Compilar kernel manualmente"
    echo "2 - Instalar kernel pré-compilado"
    read -p "Opção [1/2]: " KERNEL_OPTION
    if [ "$KERNEL_OPTION" == "1" ]; then
        echo "Iniciando compilação do kernel..."
        read -p "Informe o diretório do código fonte do kernel: " KERNEL_DIR
        cd "$KERNEL_DIR" || { echo "Diretório não encontrado"; exit 1; }
        make nconfig || { echo "Erro no make nconfig"; exit 1; }
        make || { echo "Erro na compilação do kernel"; exit 1; }
        make modules_install || { echo "Erro na instalação dos módulos"; exit 1; }
        cp arch/x86/boot/bzImage /boot/kernel || { echo "Erro ao copiar o kernel"; exit 1; }
    elif [ "$KERNEL_OPTION" == "2" ]; then
        echo "Instalando kernel pré-compilado..."
        read -p "Informe o caminho para o kernel pré-compilado (bzImage): " KERNEL_PATH
        cp "$KERNEL_PATH" /boot/kernel || { echo "Erro ao copiar o kernel"; exit 1; }
    else
        echo "Opção inválida. Pulando instalação do kernel."
    fi
fi

# 3. Instalar o bootloader
read -p "Deseja instalar o bootloader? (S/n): " INSTALL_BOOTLOADER
INSTALL_BOOTLOADER=${INSTALL_BOOTLOADER:-S}
if [[ "$INSTALL_BOOTLOADER" =~ ^[Ss] ]]; then
    echo "Selecione a opção:"
    echo "1 - GRUB (BIOS/Legacy)"
    echo "2 - systemd-boot (UEFI)"
    read -p "Opção [1/2]: " BOOT_OPTION
    if [ "$BOOT_OPTION" == "1" ]; then
        read -p "Informe o dispositivo para instalar o GRUB (ex: /dev/sda): " GRUB_DEV
        read -p "Informe o dispositivo da partição raiz (ex: /dev/sda2): " ROOT_PART
        grub-install "$GRUB_DEV" || { echo "Erro ao instalar GRUB"; exit 1; }
        cat <<EOF > /boot/grub/grub.cfg
set timeout=10
set default=0
menuentry "Exherbo" {
    set root=(hd0,1)
    linux /kernel root=$ROOT_PART
}
EOF
        echo "GRUB instalado e configurado."
    elif [ "$BOOT_OPTION" == "2" ]; then
        bootctl install || { echo "Erro ao instalar systemd-boot"; exit 1; }
        read -p "Informe a versão do kernel para configurar systemd-boot: " KERNEL_VERSION
        kernel-install add "$KERNEL_VERSION" /boot/vmlinuz-"$KERNEL_VERSION" || { echo "Erro ao adicionar kernel"; exit 1; }
        echo "systemd-boot instalado e configurado."
    else
        echo "Opção inválida. Pulando instalação do bootloader."
    fi
fi

# 4. Configurar hostname e /etc/hosts
read -p "Deseja configurar o hostname? (S/n): " CONFIG_HOSTNAME
CONFIG_HOSTNAME=${CONFIG_HOSTNAME:-S}
if [[ "$CONFIG_HOSTNAME" =~ ^[Ss] ]]; then
    read -p "Informe o hostname desejado: " HOSTNAME
    echo "$HOSTNAME" > /etc/hostname
    cat <<EOF > /etc/hosts
127.0.0.1    ${HOSTNAME}.localdomain   $HOSTNAME   localhost
::1          localhost
EOF
    echo "Hostname configurado para $HOSTNAME."
fi

# 5. Instalar firmware e dependências adicionais
read -p "Deseja instalar linux-firmware e dependências adicionais? (S/n): " INSTALL_FW
INSTALL_FW=${INSTALL_FW:-S}
if [[ "$INSTALL_FW" =~ ^[Ss] ]]; then
    cave resolve linux-firmware || { echo "Erro ao instalar linux-firmware"; exit 1; }
fi

# 6. Configurar locale e timezone
read -p "Deseja configurar os locales? (S/n): " CONFIG_LOCALES
CONFIG_LOCALES=${CONFIG_LOCALES:-S}
if [[ "$CONFIG_LOCALES" =~ ^[Ss] ]]; then
    read -p "Informe o locale desejado (ex: en_US.UTF-8): " LOCALE
    echo "LANG=\"$LOCALE\"" > /etc/env.d/99locale
    echo "Locale configurado para $LOCALE."
fi

read -p "Deseja configurar o timezone? (S/n): " CONFIG_TIMEZONE
CONFIG_TIMEZONE=${CONFIG_TIMEZONE:-S}
if [[ "$CONFIG_TIMEZONE" =~ ^[Ss] ]]; then
    read -p "Informe a região/horário desejado (ex: Europe/Copenhagen): " TIMEZONE
    ln -sf /usr/share/zoneinfo/"$TIMEZONE" /etc/localtime || { echo "Erro ao configurar timezone"; exit 1; }
    echo "Timezone configurado para $TIMEZONE."
fi

# 7. Definir a senha do root
read -p "Deseja definir a senha do root agora? (S/n): " SET_ROOT_PASS
SET_ROOT_PASS=${SET_ROOT_PASS:-S}
if [[ "$SET_ROOT_PASS" =~ ^[Ss] ]]; then
    passwd root
fi

echo "Instalação DENTRO DO CHROOT concluída. Agora você pode reiniciar o sistema."
