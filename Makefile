ASM_COMPILER=nasm

SRC_DIR=src
BUILD_DIR=build
LOG_DIR=log

.PHONY: all floppy_image_generator kernel bootloader clean always

# Floppy Image Generator
floppy_image_generator: $(BUILD_DIR)/os_build.img
$(BUILD_DIR)/os_build.img: bootloader kernel
	dd if=/dev/zero of=$(BUILD_DIR)/os_build.img bs=512 count=2880
	mkfs.fat -F 12 -n "NBOS" $(BUILD_DIR)/os_build.img
	dd if=$(BUILD_DIR)/bootloader.bin of=$(BUILD_DIR)/os_build.img conv=notrunc
	mcopy -i $(BUILD_DIR)/os_build.img $(BUILD_DIR)/kernel.bin "::kernel.bin"
	hex $(BUILD_DIR)/os_build.img > $(LOG_DIR)/os_build.hex

# Bootloader Compiler
bootloader: $(BUILD_DIR)/bootloader.bin
$(BUILD_DIR)/bootloader.bin: always
	$(ASM_COMPILER) $(SRC_DIR)/bootloader/bootloader.asm -f bin -o $(BUILD_DIR)/bootloader.bin

# Kernel Compiler
kernel: $(BUILD_DIR)/kernel.bin
$(BUILD_DIR)/kernel.bin: always
	$(ASM_COMPILER) $(SRC_DIR)/kernel/kernel.asm -f bin -o $(BUILD_DIR)/kernel.bin

# Always
always:
	mkdir -p $(BUILD_DIR) $(LOG_DIR)

# Clean
clean:
	rm -rf $(BUILD_DIR) $(LOG_DIR)

