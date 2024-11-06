/* -*-Asm-*- */
/*
 *  GRUB  --  GRand Unified Bootloader
 *  Copyright (C) 1999,2000,2001,2002,2005,2006,2007,2008,2009  Free Software Foundation, Inc.
 *
 *  GRUB is free software: you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation, either version 3 of the License, or
 *  (at your option) any later version.
 *
 *  GRUB is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with GRUB.  If not, see <http://www.gnu.org/licenses/>.
 */

#include <grub/symbol.h>
#include <grub/machine/boot.h>

/*
 *  defines for the code go here
 */

	/* Print message string */
#define MSG(x)	movw $x, %si; call LOCAL(message)
#define ERR(x)	movw $x, %si; jmp LOCAL(error_message)

	.macro floppy
part_start:

LOCAL(probe_values):
	.byte	36, 18, 15, 9, 0

LOCAL(floppy_probe):
	pushw	%dx
/*
 *  Perform floppy probe.
 */
#ifdef __APPLE__
	LOCAL(probe_values_minus_one) = LOCAL(probe_values) - 1
	movw	MACRO_DOLLAR(LOCAL(probe_values_minus_one)), %si
#else
	movw	MACRO_DOLLAR(LOCAL(probe_values)) - 1, %si
#endif

LOCAL(probe_loop):
	/* reset floppy controller INT 13h AH=0 */
	xorw	%ax, %ax
	int	MACRO_DOLLAR(0x13)

	incw	%si
	movb	(%si), %cl

	/* if number of sectors is 0, display error and die */
	testb	%cl, %cl
	jnz	1f

/*
 * Floppy disk probe failure.
 */
	MSG(fd_probe_error_string)
	jmp	LOCAL(general_error)

/* "Floppy" */
fd_probe_error_string:	.asciz "Floppy"

1:
	/* perform read */
	movw	MACRO_DOLLAR(GRUB_BOOT_MACHINE_BUFFER_SEG), %bx
	movw	%bx, %es
	xorw	%bx, %bx
	movw	MACRO_DOLLAR(0x201), %ax
	movb	MACRO_DOLLAR(0), %ch
	movb	MACRO_DOLLAR(0), %dh
	int	MACRO_DOLLAR(0x13)

	/* if error, jump to "LOCAL(probe_loop)" */
	jc	LOCAL(probe_loop)

	/* %cl is already the correct value! */
	movb	MACRO_DOLLAR(1), %dh
	movb	MACRO_DOLLAR(79), %ch

	jmp	LOCAL(final_init)
	.endm

	.macro scratch

	/* scratch space */
mode:
	.byte	0
disk_address_packet:
sectors:
	.long	0
heads:
	.long	0
cylinders:
	.word	0
sector_start:
	.byte	0
head_start:
	.byte	0
cylinder_start:
	.word	0
	/* more space... */
	.endm

	.file	"boot.S"

	.text

	/* Tell GAS to generate 16-bit instructions so that this code works
	   in real mode. */
	.code16

  /**
  * 第一个扇区的代码, 被加载到0x7c00
  */
.globl _start, start;
_start:
start:
	/*
	 * _start is loaded at 0x7c00 and is jumped to with CS:IP 0:0x7c00
	 */

	/*
	 * Beginning of the sector is compatible with the FAT/HPFS BIOS
	 * parameter block.
   * 扇区的开头与 FAT/HPFS BIOS 参数块兼容。
	 */

	jmp	LOCAL(after_BPB)
	nop	/* do I care about this ??? */

#ifdef HYBRID_BOOT
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop

	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop

	nop
	nop
	jmp	LOCAL(after_BPB)
#else
	/*
	 * This space is for the BIOS parameter block!!!!  Don't change
	 * the first jump, nor start the code anywhere but right after
	 * this area.
	 */

	.org GRUB_BOOT_MACHINE_BPB_START
	.org 4
#endif
#ifdef HYBRID_BOOT
	floppy
#else
	scratch
#endif

	.org GRUB_BOOT_MACHINE_BPB_END
	/*
	 * End of BIOS parameter block.
	 */

LOCAL(kernel_address):
	.word	GRUB_BOOT_MACHINE_KERNEL_ADDR

#ifndef HYBRID_BOOT
	.org GRUB_BOOT_MACHINE_KERNEL_SECTOR
LOCAL(kernel_sector):
	.long	1
LOCAL(kernel_sector_high):
	.long	0
#endif

	.org GRUB_BOOT_MACHINE_BOOT_DRIVE
boot_drive:
	.byte 0xff	/* the disk to load kernel from */
			/* 0xff means use the boot drive */

/* 0x7c00跳转到的实际代码位置 */
LOCAL(after_BPB):

/* general setup */
  /* 关闭中断 */
	cli		/* we're not safe here! */

        /*
         * This is a workaround for buggy BIOSes which don't pass boot
         * drive correctly. If GRUB is installed into a HDD, check if
         * DL is masked correctly. If not, assume that the BIOS passed
         * a bogus value and set DL to 0x80, since this is the only
         * possible boot drive. If GRUB is installed into a floppy,
         * this does nothing (only jump).
         */
	.org GRUB_BOOT_MACHINE_DRIVE_CHECK
boot_drive_check:
        jmp     3f	/* grub-setup may overwrite this jump */
        testb   $0x80, %dl
        jz      2f
3:
	/* Ignore %dl different from 0-0x0f and 0x80-0x8f.  */
	testb   $0x70, %dl
	jz      1f
2:	
        movb    $0x80, %dl
1:
	/*
	 * ljmp to the next instruction because some bogus BIOSes
	 * jump to 07C0:0000 instead of 0000:7C00.
   * 将CS设置为0x00, IP保存完整代码位置
	 */
	ljmp	$0, $real_start

real_start:

	/* set up %ds and %ss as offset from 0 */
  /* 将%ds和%ss设置为0 */
	xorw	%ax, %ax
	movw	%ax, %ds
	movw	%ax, %ss

	/* set up the REAL stack */
  /* 设置栈 */
	movw	$GRUB_BOOT_MACHINE_STACK_SEG, %sp

  /* 开启中断 */
	sti		/* we're safe again */

	/*
	 *  Check if we have a forced disk reference here
   *  检查此处是否有强制磁盘引用 
	 */
	movb   boot_drive, %al
	cmpb	$0xff, %al
	je	1f
	movb	%al, %dl
1:
	/* save drive reference first thing! */
  /* 保存%dx */
	pushw	%dx

	/* print a notification message on the screen */
  /* 调用MSG打印字符串 */
	MSG(notification_string)

	/* set %si to the disk address packet */
	movw	$disk_address_packet, %si

	/* check if LBA is supported */
  /*
  * 扩展 Int13H 调用中规定了两个主要的 API 子集
  * 第一个子集提供了访问大硬盘所必须的功能, 包括 检查扩展 In13H 是否存在( 41h ), 扩展读( 42h ), 扩展写( 43h ), 校验扇区( 44h ), 扩展定位( 47h ) 和 取得驱动器参数 ( 48h ).
  * 第二个子集提供了对软件控制驱动器锁定和弹出的支持, 包括 检查扩展 Int13H 是否存在( 41h ), 锁定/解锁驱动器( 45h ), 弹出驱动器( 46h ), 取得驱动器参数( 48h ), 取得扩展驱动器改变状态( 4Arrayh ), 
  * int 15h。 如果使用了调用规范中不支持的功能 , BIOS 将返回： 错误码 ah = 01h ；CF = 1。
  */
  /* 检查是否支持LBA, 如果支持LBA, CF标志为0, bx为0x55aa, 如果不支持CF标志为1 */
  /*  %cx 的 0 位表示是否支持第一个子集, 1位表示是否 支持第二个子集 */

	movb	$0x41, %ah
	movw	$0x55aa, %bx
	int	$0x13

	/*
	 *  %dl may have been clobbered by INT 13, AH=41H.
	 *  This happens, for example, with AST BIOS 1.04.
	 */
	popw	%dx
	pushw	%dx

	/* use CHS if fails */
  /* 不支持LBA, 使用CHS */
	jc	LOCAL(chs_mode)
	cmpw	$0xaa55, %bx
	jne	LOCAL(chs_mode)

  /* 检查是否支持INT 13H第一个API子集, 不支持将使用CHS模式 */
	andw	$1, %cx
	jz	LOCAL(chs_mode)

  /*
  * LBA 是一种逻辑寻址方式，较新型的硬盘和操作系统都使用 LBA 进行寻址。
  * LBA 使用一个简单的逻辑块编号来表示硬盘上的每一个扇区，不再考虑物理的柱面、磁头和扇区的具体位置。
  *
  * Logical Block Address (逻辑块地址): 每个扇区的编号从 0 开始，LBA 只是通过一个单一的数字来标识硬盘上的扇区，无需考虑 CHS 的复杂结构。
  */
LOCAL(lba_mode):
  /* 通过%si设置disk_address_packet */
  /* 内存缓冲区的偏移量设置为0 */
	xorw	%ax, %ax
	movw	%ax, 4(%si)

	incw	%ax
	/* set the mode to non-zero */
  /* 表示是lba模式读取的数据 */
	movb	%al, -1(%si)

	/* the blocks */
  /* 设置读取的扇区数 */
	movw	%ax, 2(%si)

	/* the size and the reserved byte */
  /* 设置DAP的大小 */
	movw	$0x0010, (%si)

	/* the absolute address */
  /* 从第一个扇区开始读取,第0个扇区就是当前执行的代码，已经被bios读取带内存了 */
	movl	LOCAL(kernel_sector), %ebx
	movl	%ebx, 8(%si)
	movl	LOCAL(kernel_sector_high), %ebx
	movl	%ebx, 12(%si)

	/* the segment of buffer address */
  /* 读取到0x7000 << 4 ,段地址 */
	movw	$GRUB_BOOT_MACHINE_BUFFER_SEG, 6(%si)

/*
 * BIOS call "INT 0x13 Function 0x42" to read sectors from disk into memory
 *	Call with	%ah = 0x42
 *			%dl = drive number
 *			%ds:%si = segment:offset of disk address packet
 *	Return:
 *			%al = 0x0 on success; err code on failure
 */

  /*
   * 通过INT 13H 功能号42H 从磁盘读取数据
   * %ah = 0x42 功能号
   * %dl = 驱动器索引, 0x80表示第一个硬盘
   * %ds:%si = 磁盘地址包(DAP)的内存地址
   * DAP的结构：
   *  0: DAP 的大小
   *  1: 未使用的字节，设置为0x00
   *  2-3：要读取的扇区数
   *  4-7：指向要传输扇区的内存缓冲区的偏移量指针(4-5: 偏移, 6-7: 段地址)
   *  8-f：使用逻辑块寻址要读取的扇区起始位置的绝对编号
   */

	movb	$0x42, %ah
	int	$0x13

	/* LBA read is not supported, so fallback to CHS.  */
	jc	LOCAL(chs_mode)

	movw	$GRUB_BOOT_MACHINE_BUFFER_SEG, %bx
	jmp	LOCAL(copy_buffer)

  /*
  * CHS 是传统的硬盘寻址方式，在早期硬盘中使用广泛，直到较大的硬盘引入了 LBA 模式。
  *
  * Cylinder (Cylindrical，柱面): 磁盘的物理结构将磁头的活动视为在一个垂直轴上移动，称为柱面。磁盘分为多个柱面，每个柱面有若干个扇区。
  * Head (磁头): 每个磁盘有多个磁头，每个磁头用于读取或写入特定的柱面。
  * Sector (扇区): 磁盘被分为多个扇区，每个扇区通常是 512 字节，表示最小的数据存储单位。
  */

LOCAL(chs_mode):
	/*
	 *  Determine the hard disk geometry from the BIOS!
	 *  We do this first, so that LS-120 IDE floppies work correctly.
	 */
  /* 读取驱动器参数, 如果CF=1表示有错误 */
  /* INT 13H 功能号8的返回值
  * CF: 错误标识0表示没有错误
  * AH: 状态 (07h)
  * BL: 驱动器类型(仅限 AT/PS2 软盘)
  * CH: 最大柱面号的低八位(柱面是从0开始计算的)
  * CL: 单个磁道的扇区号(位 5-0, 扇区数是从1开始计算的),最大柱面号的高两位（位 7-6）
  * DH: 最大磁头数-1(磁头数是从0开始计算)
  * DL: 磁盘数量
  * ES:DI -> 驱动器参数表(仅限软盘)
  */
	movb	$8, %ah
	int	$0x13
  /* 没有错误跳转到final_init */
	jnc	LOCAL(final_init)

  /* 恢复%dx */
	popw	%dx
	/*
	 *  The call failed, so maybe use the floppy probe instead.
	 */
  /* 相等? 永远不会跳转到floppy_probe */
	testb	%dl, %dl
	jnb	LOCAL(floppy_probe)

	/* Nope, we definitely have a hard disk, and we're screwed. */
  /* 打印错误信息到屏幕 */
	ERR(hd_probe_error_string)

LOCAL(final_init):
	/* set the mode to zero */
  /* %dh是最大头数 */
	movzbl	%dh, %eax
  /* mode设置为0, 表示使用chs模式 */
	movb	%ah, -1(%si)

	/* save number of heads */
  /* 磁头加1，磁头是从0开始的 */
	incw	%ax
	movl	%eax, 4(%si)

	movzbw	%cl, %dx
	shlw	$2, %dx
	movb	%ch, %al
	movb	%dh, %ah
  /* 将%cl的6-7位作为高位，%ch作为低位，得到柱面数 */

	/* save number of cylinders */
  /* 柱面数量是从0开始计算的，真实数量要+1 */
	incw	%ax
	movw	%ax, 8(%si)

  /* 获取扇区数量 */
	movzbw	%dl, %ax
	shrb	$2, %al

	/* save number of sectors */
  /* 设置扇区 */
	movl	%eax, (%si)

setup_sectors:
	/* load logical sector start (top half) */
  /* 测试kernel_sector_high必须为0 */
	movl	LOCAL(kernel_sector_high), %eax

	orl	%eax, %eax
	jnz	LOCAL(geometry_error)

	/* load logical sector start (bottom half) */
  /* 加载逻辑扇区 */
  /*
  * 逻辑扇区到CHS的转换
  * 柱面 = 逻辑扇区/(磁头总数*单个磁道的扇区数)
  * 磁头 = 逻辑扇区/单个磁道的扇区数 % 磁头总数
  * 扇区 = 逻辑扇区 % 单个磁道的扇区数 + 1
  * */
	movl	LOCAL(kernel_sector), %eax

	/* zero %edx */
  /* 清空%edx */
	xorl	%edx, %edx

	/* divide by number of sectors */
  /*
   * %edx:%eax 作为被除数
   * (%si)地址处的扇区数作为除数
   * 商放在%eax, 余数放在%edx
   */
	divl	(%si)

	/* save sector start */
  /* 扇区数量 */
	movb	%dl, %cl

	xorw	%dx, %dx	/* zero %edx */
  /* 用上次的商再除磁头的数量，得到柱面的数量 */
	divl	4(%si)		/* divide by number of heads */

	/* do we need too many cylinders? */
  /* 柱面数量不能大于柱面的总数 */
	cmpw	8(%si), %ax
	jge	LOCAL(geometry_error)

	/* normalize sector start (1-based) */
  /* 扇区从1开始编号，需要+1 */
	incb	%cl

	/* low bits of cylinder start */
  /* 设置柱面 */
	movb	%al, %ch

	/* high bits of cylinder start */
  /* 设置扇区数, %cl的6-7位是柱面的高位 */
	xorb	%al, %al
	shrw	$2, %ax
	orb	%al, %cl

	/* save head start */
  /* 设置磁头参数 */
	movb	%dl, %al

	/* restore %dl */
  /* 恢复%dl */
	popw	%dx

	/* head start */
	movb	%al, %dh

/*
 * BIOS call "INT 0x13 Function 0x2" to read sectors from disk into memory
 *	Call with	%ah = 0x2
 *			%al = number of sectors
 *			%ch = cylinder
 *			%cl = sector (bits 6-7 are high bits of "cylinder")
 *			%dh = head
 *			%dl = drive (0x80 for hard disk, 0x0 for floppy disk)
 *			%es:%bx = segment:offset of buffer
 *	Return:
 *			%al = 0x0 on success; err code on failure
 */

 /*
  * INT 0x13 功能号 0x2 读取数据到内存
  * 功能号 %ah = 0x2
  *     %al = 读取扇区数
  *			%ch = 柱面
  *			%cl = 扇区（6-7位是柱面的高位）
  *			%dh = 磁头
  *			%dl = 磁盘 (0x80 硬盘, 0x0 软盘)
  *			%es:%bx = 数据读取到的位置
  *	返回值:
  *			%al = 0表示成功
  */
  /* 设置数据保持的位置 */
	movw	$GRUB_BOOT_MACHINE_BUFFER_SEG, %bx
	movw	%bx, %es	/* load %es segment with disk buffer */

  /* 清空 %bx */
	xorw	%bx, %bx	/* %bx = 0, put it at 0 in the segment */
  /* 设置功能号0x2, 读取的扇区数量是1 */
	movw	$0x0201, %ax	/* function 2 */
	int	$0x13

	jc	LOCAL(read_error)

  /* 设置读取到的buffer段寄存器 */
	movw	%es, %bx

LOCAL(copy_buffer):
	/*
	 * We need to save %cx and %si because the startup code in
	 * kernel uses them without initializing them.
	 */
  /* 保存寄存器 */
	pusha
	pushw	%ds

	movw	$0x100, %cx
	movw	%bx, %ds
	xorw	%si, %si
	movw	$GRUB_BOOT_MACHINE_KERNEL_ADDR, %di
	movw	%si, %es

  /* 清除方向标志 */
	cld

  /* 移动数据%ds << 4 + si -->  %es << 4 + %di */
  /*  0x70000 --> 0x8000 */
	rep
	movsw

	popw	%ds
	popa

	/* boot kernel */
  /* 跳转到0x8000位置,编译的diskboot.img文件 */
	jmp	*(LOCAL(kernel_address))

/* END OF MAIN LOOP */

/*
 * BIOS Geometry translation error (past the end of the disk geometry!).
 */
LOCAL(geometry_error):
	ERR(geometry_error_string)

/*
 * Read error on the disk.
 */
LOCAL(read_error):
	movw	$read_error_string, %si
LOCAL(error_message):
	call	LOCAL(message)
LOCAL(general_error):
	MSG(general_error_string)

/* go here when you need to stop the machine hard after an error condition */
        /* tell the BIOS a boot failure, which may result in no effect */
        int	$0x18
LOCAL(stop):
	jmp	LOCAL(stop)

notification_string:	.asciz "GRUB "
geometry_error_string:	.asciz "Geom"
hd_probe_error_string:	.asciz "Hard Disk"
read_error_string:	.asciz "Read"
general_error_string:	.asciz " Error\r\n"

/*
 * message: write the string pointed to by %si
 *
 *   WARNING: trashes %si, %ax, and %bx
 */

	/*
	 * Use BIOS "int 10H Function 0Eh" to write character in teletype mode
	 *	%ah = 0xe	%al = character
	 *	%bh = page	%bl = foreground color (graphics modes)
	 */
  /*
  * 使用 int 10H的bios中断打印字符
  * %ah = 0xe
  * %al = 打印的字符
  * %bh = 打印的页码
  * %bl = 背景颜色
  */
1:
	movw	$0x0001, %bx
	movb	$0xe, %ah
	int	$0x10		/* display a byte */
LOCAL(message):
  /* 从DS:SI加载一个字节到%al, 根据标志寄存器中的方向标志（DF，Direction Flag）更新 SI */
	lodsb
	cmpb	$0, %al
  /* 如果没有读取到0x00就一直循环 */
	jne	1b	/* if not end of string, jmp to display */
	ret

	/*
	 *  Windows NT breaks compatibility by embedding a magic
	 *  number here.
	 */

#ifdef HYBRID_BOOT
	.org 0x1b0
LOCAL(kernel_sector):
	.long	1
LOCAL(kernel_sector_high):
	.long	0
#endif
	.org GRUB_BOOT_MACHINE_WINDOWS_NT_MAGIC
nt_magic:
	.long 0
	.word 0

	/*
	 *  This is where an MBR would go if on a hard disk.  The code
	 *  here isn't even referenced unless we're on a floppy.  Kinda
	 *  sneaky, huh?
	*/

	.org GRUB_BOOT_MACHINE_PART_START

#ifndef HYBRID_BOOT
	floppy
#else
	scratch
#endif

	.org GRUB_BOOT_MACHINE_PART_END
	
/* the last 2 bytes in the sector 0 contain the signature */
	.word	GRUB_BOOT_MACHINE_SIGNATURE
