# 1. Persiapan buat Image Kosong:
qemu-img create -f qcow2 \
/home/$USER/KVMs/rocky8.qcow2 \
50G

# 2. Menjalankan image:
virt-install --name rocky8 \
  --virt-type kvm --memory 2048 --vcpus 2 \
  --boot hd,menu=on \
  --disk path=/home/$USER/KVMs/rocky8.qcow2,device=disk \
  --cdrom=/home/$USER/KVMs/Rocky-8.10-x86_64-minimal.iso \
  --graphics vnc \
  --os-type Linux --os-variant rocky8

# 3. Kompress File
#Compress the Image
qemu-img convert -c \
/home/$USER/KVMs/rocky8.qcow2 -O qcow2 \
/home/$USER/KVMs/cl-rl8.qcow2
