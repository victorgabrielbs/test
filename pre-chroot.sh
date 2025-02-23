#!/bin/bash
set -e

echo "### Particionamento do disco ###"
lsblk
read -p "Digite o dispositivo a ser particionado (ex: /dev/sda): " DEVICE

echo "O sistema está em BIOS/Legacy ou UEFI? (Digite 'bios' ou 'uefi')"
read -r BOOT_MODE

if [[ "$BOOT_MODE" == "uefi" ]]; then
    ESP_SIZE="50M"
else
    ESP_SIZE="500M"
fi

echo "Criando tabela de partições..."
cfdisk "$DEVICE"

echo "Formatando partições..."
if [[ "$BOOT_MODE" == "uefi" ]]; then
    mkfs.vfat -F32 "${DEVICE}1"
else
    mkfs.ext2 "${DEVICE}1"
fi
mkfs.ext4 "${DEVICE}2"
mkfs.ext4 "${DEVICE}3"

echo "Montando partições..."
mkdir -p /mnt/exherbo
mount "${DEVICE}2" /mnt/exherbo
mkdir -p /mnt/exherbo/home /mnt/exherbo/boot
mount "${DEVICE}3" /mnt/exherbo/home
mount "${DEVICE}1" /mnt/exherbo/boot

echo "Baixando stage do Exherbo..."
cd /mnt/exherbo
curl -O https://stages.exherbolinux.org/x86_64-pc-linux-gnu/exherbo-x86_64-pc-linux-gnu-gcc-current.tar.xz
curl -O https://stages.exherbolinux.org/x86_64-pc-linux-gnu/exherbo-x86_64-pc-linux-gnu-gcc-current.tar.xz.sha256sum
sha256sum -c exherbo-x86_64-pc-linux-gnu-gcc-current.tar.xz.sha256sum

echo "Extraindo o stage..."
tar xJpf exherbo*xz

echo "Configurando fstab..."
cat <<EOF > /mnt/exherbo/etc/fstab
# <fs>       <mountpoint>    <type>    <opts>      <dump/pass>
/dev/sda2    /               ext4      defaults    0 0
/dev/sda3    /home           ext4      defaults    0 2
EOF

if [[ "$BOOT_MODE" == "uefi" ]]; then
    echo "/dev/sda1    /boot           vfat      defaults    0 0" >> /mnt/exherbo/etc/fstab
else
    echo "/dev/sda1    /boot           ext2      defaults    0 0" >> /mnt/exherbo/etc/fstab
fi

echo "Montando diretórios para chroot..."
mount -o rbind /dev /mnt/exherbo/dev
mount -o rbind /sys /mnt/exherbo/sys
mount -t proc none /mnt/exherbo/proc

echo "Copiando configuração de rede..."
cp /etc/resolv.conf /mnt/exherbo/etc/resolv.conf

echo "### Sistema pronto para chroot. Execute o próximo script dentro do chroot. ###"
echo "Para entrar, use:"
echo "  env -i TERM=\$TERM SHELL=/bin/bash HOME=\$HOME chroot /mnt/exherbo /bin/bash"
