#!/bin/bash
# Verifica se o script está sendo executado como root.
if [ "$(id -u)" -ne 0 ]; then
    echo "Este script precisa ser executado como root."
    exit 1
fi

echo "=== Instalação PRÉ-CHROOT para Exherbo ==="
echo

# 1. Montar a partição raiz
read -p "Informe o dispositivo da partição raiz (ex: /dev/sda2): " ROOT_PART
mkdir -p /mnt/exherbo
echo "Montando $ROOT_PART em /mnt/exherbo..."
mount "$ROOT_PART" /mnt/exherbo || { echo "Erro ao montar $ROOT_PART"; exit 1; }

# 2. Download do stage tarball e do arquivo de checksum
STAGE_URL="https://stages.exherbolinux.org/x86_64-pc-linux-gnu/exherbo-x86_64-pc-linux-gnu-gcc-current.tar.xz"
SHA256_URL="${STAGE_URL}.sha256sum"

echo "Baixando stage tarball..."
curl -O "$STAGE_URL" || { echo "Erro ao baixar o stage tarball"; exit 1; }
echo "Baixando arquivo de checksum..."
curl -O "$SHA256_URL" || { echo "Erro ao baixar o arquivo de checksum"; exit 1; }

# 3. Verificação do checksum
read -p "Deseja verificar o checksum SHA256? (S/n): " VERIFY
VERIFY=${VERIFY:-S}
if [[ "$VERIFY" =~ ^[Ss] ]]; then
    echo "Verificando o checksum..."
    sha256sum -c "$(basename "$SHA256_URL")" || { echo "Checksum inválido!"; exit 1; }
else
    echo "Pulando verificação do checksum."
fi

# 4. Extração do stage tarball
read -p "Deseja extrair o stage tarball? (S/n): " EXTRACT
EXTRACT=${EXTRACT:-S}
if [[ "$EXTRACT" =~ ^[Ss] ]]; then
    echo "Extraindo o stage..."
    tar xJpf "$(basename "$STAGE_URL")" -C /mnt/exherbo || { echo "Erro na extração"; exit 1; }
else
    echo "Pulando extração do stage."
fi

# 5. Atualização do fstab
read -p "Deseja atualizar o arquivo fstab (/mnt/exherbo/etc/fstab)? (S/n): " UPDATEFSTAB
UPDATEFSTAB=${UPDATEFSTAB:-S}
if [[ "$UPDATEFSTAB" =~ ^[Ss] ]]; then
    echo "Configurando /mnt/exherbo/etc/fstab..."
    echo "Digite o dispositivo para a partição raiz (já utilizado): $ROOT_PART"
    read -p "Informe o dispositivo para a partição home (ou deixe em branco para ignorar): " HOME_PART
    read -p "Informe o dispositivo para a partição boot (ou deixe em branco para ignorar): " BOOT_PART

    FSTAB_FILE="/mnt/exherbo/etc/fstab"
    echo "# /etc/fstab" > "$FSTAB_FILE"
    echo "$ROOT_PART    /       ext4    defaults    0 0" >> "$FSTAB_FILE"
    if [ -n "$HOME_PART" ]; then
        echo "$HOME_PART    /home   ext4    defaults    0 2" >> "$FSTAB_FILE"
    fi
    if [ -n "$BOOT_PART" ]; then
        read -p "O boot é BIOS/Legacy ou UEFI? (B/U): " BOOT_TYPE
        if [[ "$BOOT_TYPE" =~ ^[Uu] ]]; then
            echo "$BOOT_PART    /boot   vfat    defaults    0 0" >> "$FSTAB_FILE"
        else
            echo "$BOOT_PART    /boot   ext2    defaults    0 0" >> "$FSTAB_FILE"
        fi
    fi
    echo "fstab atualizado em $FSTAB_FILE."
else
    echo "Pulando atualização do fstab."
fi

echo "Instalação PRÉ-CHROOT concluída."
echo "Agora, copie o script 'chroot-install.sh' para /mnt/exherbo e execute-o dentro do chroot."
