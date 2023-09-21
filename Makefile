ASM_COMPILER=nasm

SRC_DIR=src
BUILD_DIR=build
IMG_DIR=img
LOG_DIR=$(BUILD_DIR)/log

$(IMG_DIR)/bootloader.img: $(BUILD_DIR)/bootloader.bin
	cp $(BUILD_DIR)/bootloader.bin $(IMG_DIR)/bootloader.img
	truncate -s 1440k $(IMG_DIR)/bootloader.img
	hex $(IMG_DIR)/bootloader.img > $(LOG_DIR)/bootloader.hex

$(BUILD_DIR)/bootloader.bin: $(SRC_DIR)/bootloader.asm
	$(ASM_COMPILER) $(SRC_DIR)/bootloader.asm -f bin -o $(BUILD_DIR)/bootloader.bin
