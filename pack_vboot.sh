futility --debug vbutil_kernel \
         --pack vmlinux.kpart \
         --version 1 \
         --vmlinuz kernel.itb \
         --arch arm \
         --keyblock kernel.keyblock \
         --signprivate kernel_data_key.vbprivk \
         --config cmdline \
         --bootloader bootloader.bin
