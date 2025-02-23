#!/bin/bash
set -e

echo "Carregando ambiente dentro do chroot..."
source /etc/profile
export PS1="(chroot) $PS1"

echo "Sincronizando pacotes..."
cave sync

echo "### Instalação do Kernel ###"
echo "Baixando kernel mais recente..."
cd /usr/src
curl -O https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-6.13.4.tar.xz
tar xJf linux-6.13.4.tar.xz
cd linux-6.13.4

echo "Configurando o Kernel..."
make nconfig
make -j$(nproc)
make modules_install
cp arch/x86/boot/bzImage /boot/kernel

echo "Deseja instalar o systemd? (s/n)"
read -r INSTALL_SYSTEMD
if [[ "$INSTALL_SYSTEMD" == "s" ]]; then
    cave resolve --execute --preserve-world --skip-phase test sys-apps/systemd
fi

echo "### Configuração do Bootloader ###"
if [[ "$BOOT_MODE" == "uefi" ]]; then
    bootctl install
else
    grub-install /dev/sda
    grub-mkconfig -o /boot/grub/grub.cfg
fi

echo "Configurando hostname..."
echo "Digite um hostname para o sistema:"
read -r HOSTNAME
echo "$HOSTNAME" > /etc/hostname

echo "Configurando hosts..."
cat <<EOF > /etc/hosts
127.0.0.1    $HOSTNAME    localhost
::1          localhost
EOF

echo "Deseja instalar firmware adicional? (s/n)"
read -r INSTALL_FIRMWARE
if [[ "$INSTALL_FIRMWARE" == "s" ]]; then
    cave resolve linux-firmware
fi

echo "Criando senha de root..."
passwd

echo "Definindo timezone..."
ln -sf /usr/share/zoneinfo/America/Sao_Paulo /etc/localtime

echo "### Instalação concluída. Reinicie o sistema. ###"
echo "Use 'reboot' para reiniciar."
