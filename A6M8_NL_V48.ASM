;**********************************************************************************************
;在A6M7_ES0617_NL_V47.ASM基础上进行修改，增加了等级控制使能功能2019-8-10
;修改了反写卡记录调取失败的问题2019-2-14
;在A6M7_ES0617_NL_V46.ASM基础上进行修改，增加了一次卡功能2019-1-10
;在A6M7_ES0617_NL_V45.ASM基础上进行修改，酒店客人卡和酒店预定客人卡的等级权限修改为大于房号判断，即等级通过则认为房号对2018-10-16
;在A6M7_ES0617_NL_V44.ASM基础上进行修改，取消了CLICK的强制状态2018-10-15
;在A6M7_ES0617_NL_V42.ASM基础上进行修改，增加了TIME_GROUP、TIME_PATTEN和黑名单扩散功能2018-7-30
;在A6M7_ES0617_NL_V41.ASM基础上进行修改，增加了办公型卡片的起始时间检测，2017-8-3
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;在A6M7_ES0617_NL_V4.ASM基础上进行修改，将CLICK状态强制修改为CLICK2，2017-3-2 备注：该功能在V45版本中去除
;试图将系统耗电降低
;在A6M7_ES0617_NL_V2.ASM基础上进行修改，增加了总控卡选择是否可开反锁的功能
;在A6M7_ES0617_NL_V1.ASM基础上进行修改，修改了32级别的控制和设定方式，以兼容以前的控制方式
;在A6M7_ES0617_SL_V1.ASM基础上进行修改，使之兼容FM1702NL的芯片，其余功能与原程序相同
;在A6M7_ES0617_SL.ASM基础上进行修改，增加了酒店办公合并程序，另外C1C2的设置方式也由密码卡设置改为房号卡和设置卡设置，2014-5-16
;将原先总控卡的级别设置由8级增加到32级，涉及改动卡片有房号卡、设置卡、总控卡，2014-5-23
;* 根据ES9024A.ASM(1000张卡,通道锁可挂失\授权\清除,用24C64)改成:500条记录，提记录时排序
;* 用RC500的办公型锁,mifare1卡读7、8扇区,卡上有开锁时间段列表,(首批使用在英国大学2000多套)
;* 原始卡可以在0或7扇区，记录卡只能在0扇区
;* 多层卡有13个单独的层号，房间卡有8个单独的房间号,方舌打开可以自动关锁,方舌打开门内开锁可以常开
;* 有常开跳线，密码卡+主舌常开=原始卡，有设置卡=密码卡+时钟卡+房号卡，没有门未关好报警
;* 记录所有不能开门的开门卡,房间卡可以开反锁、读卡就常开常闭功能。
;* 常开状态时只有 同一房间的房间卡、楼层卡、多层卡、总控卡、紧急卡 才可以关闭
;* 第9扇区为反写最后4条操作记录、房号、低压计数器
;* 程序名:        ES9024A4M2.ASM (MAX824)
;* 卡片:          m1
;* 记录卡:        m1*12
;* PCB:		 ES0605.PCB
;* SCH:		 ES0605.S01
;* CPU:          STC89LE54RD+(24MHZ\低电压片3.3V)
;* 时钟:         PCF8563 (1HZ)
;* 开始时间:	 2007/12/1
;***********************************************************************************************
;P4口定义:
P4			EQU	0E8H			;STC单片机!
WDTCONTER		EQU	0E1H
AUXR			EQU	08EH
TH2			EQU	0CDH
TL2			EQU	0CCH
RCAP2H			EQU	0CBH
RCAP2L			EQU	0CAH
T2CON			EQU	0C8H
TR2			BIT	0CAH			;T2CON.2e
TF2			BIT	0CFH
ET2			BIT	0ADH

XICON			EQU	0C0H

IT2			BIT	0C0H.0			;INT2
IE2			BIT	0C0H.1
EX2			BIT	0C0H.2
PX2			BIT	0C0H.3

IT3			BIT	0C0H.4			;INT3
IE3			BIT	0C0H.5
EX3			BIT	0C0H.6
PX3			BIT	0C0H.7

FJCBUFF_END_MIF		EQU	0FFH
FJCBUFF_BEG_MIF		EQU	0A0H			;多层卡和房间卡需要多读的一块数据

;内存地址定义:
STACK_POINT		EQU	0DFH			;堆栈指针

BUFF_END_RWR		EQU	8FH
BUFF_BEG_RWR		EQU	60H			;反写卡时暂存2块数据(第3块直接存Wbuf?356)

LSBUFF_END_MIF		EQU	0BFH
LSBUFF_BEG_MIF		EQU	0B0H			;多层卡和房间卡需要多读的一块数据

BUFF_END_MIF		EQU	0AFH			;注:卡缓冲区共16*5=80BYTE,其中60H-7F的32BYTE为读到
BUFF_MID_MIF		EQU	7FH			;的卡的基本数据,可直接(所以老程序的有关部分可不改动)或间接寻址,
BUFF_BEG_MIF		EQU	60H			;80H-AFH为开锁时间段列表,只可间接寻址,0A0-0AF也作为读16BYTE的缓冲区

BUFF_END_24C1X		EQU	5FH			;16BYTE
BUFF_BEG_24C1X		EQU	50H

;UID_Buffer              EQU     5CH                     ;读取到卡序列号后，暂时利用存储器空间暂时存储，读卡完毕后解除
;在读RC500时40H-4FH的寄存器没有被使用所以可以借用
LS_END_MIF		EQU	4FH
LS_BEG_MIF		EQU	40H
;退出RC500读卡程序时,要把数据存入0B0H-0BFH,释放40H-4FH内存
;以下的内存从程序启动到RC500读卡完毕期间不能有数据传输(全局变量不能放在此处40H--4FH)
BITCOUNT_24C1X		EQU	4FH			;读写24C1X的BIT计数器
R_W_COUNT_24C1X_0      	EQU     4EH               	;读写24C1X次数计数器0

TBLK_COUNT		EQU	4DH
LEDBUZZ_MODE		EQU	4CH
HADDR_24C1X		EQU	4BH
LADDR_24C1X		EQU	4AH
LENGTH_24C1X		EQU	49H

BK_HADDR_24C1X		EQU	48H			;调用读24C1X程序以前用来备份其块和地址
BK_LADDR_24C1X		EQU	47H

BUFF_END_8563		EQU	46H			;7BYTE!
BUFF_BEG_8563		EQU	40H
;以上的内存从程序启动到RC500读卡完毕期间不能有数据传输
PWR_24C1X_NUM		EQU	3FH

SEC_COUNT		EQU	3EH			;扇区计数器
BLK_COUNT		EQU	3DH			;块计数器
U_SECNR			EQU	3CH
U_BLKNR                 EQU     3BH

VOL_STATE		EQU	3AH			;电压状态

CT_TEMP			EQU	39H
count1			equ	38h
LOW45_NUM		EQU	37H			;低压4.5V计数器
XIALING_NUM		EQU	36H
TIME_60S                EQU     35H
;RC500中断程序中只用到R0,R7（即08H和0FH,其余还可使用）
T0INTCOUNT		EQU	09H			;0.1S中断次数计数器
COUNT0			EQU	0AH			;公用计数器
DCOUNT1			EQU	0BH			;延时用计数器0
DCOUNT2			EQU	0CH			;延时用计数器1
DCOUNT3			EQU	0DH			;延时用计数器2

;位定义:RC500程序中0FH位
TEST_1702SL		BIT	00H			;20H
TEST_TONGUE		BIT	01H			;中断方式: 1->主舌上电
CHANG_KAI_FLAG		BIT	02H			;20H.3,常开标志
BKLK_SW_BK		BIT	03H
TONGUE_SW_BK		BIT	04H
XIALING_FLAG		BIT	05H
TONG_DAO_FLAG		BIT	06H			;20H.4,通道锁标志
CHANGE_PAGE_FLAG	BIT	07H
CHRP_FLAG		BIT	08H
ACK_8563		BIT	09H
ACK_24C1X		BIT	09H
;REC_KEY_FLAG		BIT	0AH
FLAG_OUT2359		BIT	0AH			;过午夜标志
reset_flag		BIT	0BH
CARD_FLAG               BIT     0CH
FANGHAOCARD_FLAG	BIT	0DH
SPKP_FLAG		BIT	0EH			;锁内批号大于卡的批号标志
JIU_DIAN_FLAG		BIT	0FH

;22H
PLUS_FLAG		BIT	10H
TEST_RC500_1S		BIT	11H
ONE_OPEN_FLAG		BIT	12H
JD_SPE_FLAG             BIT     13H

;口线定义:

RLED			BIT	P2.4
GLED			BIT	P2.5
BUZZ			BIT	P1.7

SQ_SW			BIT	P2.4
OBSW			BIT	P2.5
YSK_SW			BIT	P1.7

BKLK_SW			BIT	P1.4
TONGUE_SW		BIT	P2.0
KEY_SW			BIT	P2.6
MC_SW			BIT	P4.1
MAX824			BIT	P4.1
LOW45			BIT	P4.0
TONGUE_INT		BIT	P4.2
CHANGKAI_SW		BIT	P2.7

MID_VOL 		BIT	P3.5                   ;5.6V
LOW_VOL 		BIT	P3.4                   ;4.8V

TOTAL_PWR		BIT	P2.1                   ;总电源

MOT_PWR			BIT	P2.2                   ;电机电源
MOT_CTRL		BIT	P2.3                   ;电机控制

PWR_24C64		BIT	P1.5
SDA_24C64		BIT	P1.6
SCL_24C64		BIT	P1.2

CLOCK_INT		BIT	P3.3
SDA_8563		BIT	P1.3
SCL_8563		BIT	P1.2

;常量定义:

LOW_VOL_LIMIT		EQU	30			;低压开锁的限制次数,30次
LOW_VOL_LIMIT_50	EQU	50			;低压开锁的限制次数,50次
LOW_VOL_LIMIT_250	EQU	250			;低压开锁的限制次数,50次

OK			EQU	00H
ERROR			EQU	01H
ERR_24C64               EQU     02H

COMP_STATE0		EQU	02H			;读24C16出错
COMP_STATE1		EQU	03H			;主序号没有和自己相同的
COMP_STATE2		EQU	04H			;主序号和自己相同,且副序号也相同
COMP_STATE3		EQU	05H			;主序号和自己相同,副序号大于自己
COMP_STATE4		EQU	06H			;主序号和自己相同,副序号小于自己但不为0
COMP_STATE5		EQU	07H			;主序号和自己相同,副序号为0

FIND_BLANK		EQU	08H			;FIND_WR程序在调用时有可能只用到一半
FIND_ITSELF		EQU	09H			;因此设两个标志

FIND_STATE0		EQU	0AH			;读/写24C16出错
FIND_STATE1		EQU	0BH			;没找到空位置
FIND_STATE2		EQU	0CH			;找到空位置,且顺利把自己的序号填入

CHECK_TIME_STATE0	EQU	0DH			;限期已到
CHECK_TIME_STATE1	EQU	0EH			;未到有效时分
CHECK_TIME_STATE2	EQU	0FH			;超过无效时分
CHECK_TIME_STATE3	EQU	10H			;有效

WRJL_STATE1		EQU	11H			;写卡失败
WRJL_STATE2		EQU	12H			;写卡成功
WRJL_STATE0		EQU	13H			;24C1X读写错误

V_HIGH			EQU	14H
V_MIDDLE		EQU	15H
V_LOW			EQU	16H

STATE0			EQU	20H
STATE1			EQU	21H
STATE2			EQU	22H

CH_I_T_STATE0		EQU	0AH
CH_I_T_STATE1		EQU	0BH
CH_I_T_STATE2		EQU	0CH
CH_I_T_STATE3		EQU	0DH

;;;;;;;;;;;;;;;;;;以下常量为固定数据,不可随意更改;;;;;;;;;;;;;;;;;;;;;;;;;;
;3字节卡号表
CARD			EQU	0A0H			;卡片开锁(SN)
KEYOPEN			EQU	0FEH			;钥匙开锁
INTEROPEN		EQU	0F8H			;门内开锁
CLOSE_X			EQU	0FDH			;门未关好
CLOSE			EQU	0FCH			;关锁
ILLEGAL			EQU	0F2H			;非法进入
OUTBUTTON		EQU	0FBH			;出门按扭
AUTO_CHANGKAI		EQU	0F0H			;自动常开
AUTO_CLOSE		EQU	0eFH			;自动关闭

;1字节状态表
NO_CARD			EQU	0B0H			;非卡操作
CARD_OPEN 		EQU	0B1H			;正常刷卡
CARD_CHANGKAI		EQU	0B2H			;卡片常开
CARD_CHANGBI		EQU	0B3H			;卡片关闭
DOOR_BKLK		EQU	0B4H			;方舌打出
MI_MA_ERROR		EQU	0B5H			;密码错误
FANG_HAO_ERROR		EQU	0B6H			;房号错误
SHI_JIAN_ERROR		EQU	0B7H			;时间错误
WEIDAO_YOUXIAO_SHIJIAN	EQU	0B8H			;未到有效时间
CHAOGUO_WUXIAO_SHIJIAN 	EQU	0B9H			;超过无效时间
LOW_VOL_OFF		EQU	0BAH			;低电压关闭
CARD_GUA_SHI		EQU	0BBH			;卡被挂失
CARD_QING_CHU		EQU	0BCH			;卡被清除
CARD_NO_BLANK		EQU	0BDH			;卡号已满
CARD_JIN_ZHI		EQU	0BFH			;卡类被禁止
CARD_FU_GAI		EQU	0C0H			;卡类被覆盖
;*********************************************************************************************
;;;;有关mifare的常量和变量定义;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;*********************************************************************************************


; /****************************************
; 卡密码
; /****************************************

KEYA0				EQU	19H
KEYA1                   	EQU	94H
KEYA2                   	EQU	04H
KEYA3                   	EQU	28H
KEYA4				EQU	19H
KEYA5				EQU	70H
;***************************************************
;内存变量
;***************************************************

CMDSEND_COMD            EQU     2BH     ;命令码
CMDSEND_LENG            EQU     2CH     ;命令长度

UID_Buffer              EQU     10H	;5 BYTE :卡序列号缓冲区

As_Buffer		EQU     0C0H	;16BYTE :出入1702的各种命令的数据流缓冲区 (RevBuffer)
Wr_Buffer		EQU     0D0H	;16BYTE :待写卡数据缓冲区 (SndBuffer)

;***************************************************
;/* FM1702命令码 */
;***************************************************
Transceive              EQU     1EH	;/* 发送接收命令 */
Transmit                EQU	1AH	;/* 发送命令 */
ReadE2                  EQU     03H	;/* 读FM1702 EEPROM命令 */
WriteE2                 EQU     01H     ;/* 写FM1702 EEPROM命令 */
Authent1                EQU     0CH     ;/* 验证命令认证过程第1步 */
Authent2                EQU     14H     ;/* 验证命令认证过程第2步 */
LoadKeyE2               EQU     0BH     ;/* 将密钥从EEPROM复制到KEY缓存 */
LoadKey                 EQU     19H     ;/* 将密钥从FIFO缓存复制到KEY缓存 */
RF_TimeOut              EQU    0b0H     ;/* 发送命令延时时间 */

;***************************************************
;/* 射频卡通信命令码定义 */
;***************************************************
RF_CMD_MIF_REQUEST_STD  EQU     26H	;/* 只选择天线范围内IDLE模式的卡片 */
RF_CMD_MIF_REQUEST_ALL  EQU     52H	;/* 选择天线范围内所有卡片 */
RF_CMD_ANTICOL		EQU     93H	;/* 选择卡片的系列号 */
RF_CMD_ANTICOL_DES      EQU     95H
RF_CMD_SELECT		EQU     93H	;/*  */
RF_CMD_SELECT_DES       EQU     95H
RF_CMD_AUTH_LA		EQU     60H	;/* 使用KEYA作验证 */
RF_CMD_AUTH_LB		EQU     61H	;/* 使KEYB作验证 */
RF_CMD_READ		EQU     30H	;/* 读 */
RF_CMD_WRITE		EQU    0A0H	;/* 写 */
RF_CMD_INC		EQU    0C1H	;/* 增 */
RF_CMD_DEC		EQU    0C0H	;/* 减 */
RF_CMD_RESTORE		EQU    0C2H	;/* 复位 */
RF_CMD_TRANSFER		EQU    0B0H	;/* 要传输数据的卡片块地址 */
RF_CMD_HALT		EQU     50H	;/* 置于halt模式 */

;***************************************************
;/* FM1702寄存器定义 */
;***************************************************
Page_Sel	        EQU	00H	;/* 页写寄存器 */
Command		        EQU     01H	;/* 命令寄存器 */
FIFO		        EQU     02H	;/* 64字节FIFO缓冲的输入输出寄存器 */
PrimaryStatus	        EQU     03H	;/* 发射器接收器及FIFO的状态寄存器1 */
FIFO_Length             EQU     04H	;/* 当前FIFO内字节数寄存器 */
SecondaryStatus         EQU     05H	;/* 各种状态寄存器2 */
InterruptEn             EQU     06H	;/* 中断使能/禁止寄存器 */
Int_Req			EQU     07H	;/* 中断请求标识寄存器 */
Control			EQU     09H	;/* 控制寄存器 */
ErrorFlag		EQU     0AH	;/* 错误状态寄存器 */
CollPos			EQU     0BH	;/* 冲突检测寄存器 */
TimerValue		EQU     0CH	;/* 定时器当前值 */
Bit_Frame		EQU     0FH	;/* 位帧调整寄存器 */
TxControl		EQU     11H	;/* 发送控制寄存器 */
CWConductance		EQU     12H	;/* 选择发射脚TX1和TX2发射天线的阻抗 */
ModConductance		EQU     13H	;/* 定义输出驱动阻抗 */
CoderControl		EQU     14H	;/* 定义编码模式和时钟频率 */
DecoderControl		EQU     1AH	;/* 解码控制寄存器 */
RxControl1		EQU     19H	;/*接收增益控制*/
RxControl2		EQU     1EH	;/* 解码控制及选择接收源 */
RxWait			EQU     21H	;/* 选择发射和接收之间的时间间隔 */
ChannelRedundancy	EQU     22H	;/* RF通道检验模式设置寄存器 */
CRCPresetLSB		EQU     23H     ;/*CRC预置值低8位*/
CRCPresetMSB		EQU     24H     ;/*CRC预置值高8位*/
MFOUTSelect		EQU     26H	;/* mf OUT 选择配置寄存器 */
TimerClock		EQU     2AH	;/* 定时器周期设置寄存器 */
TimerControl		EQU     2BH	;/* 定时器控制寄存器 */
TimerReload		EQU     2CH	;/* 定时器初值寄存器 */
TypeSH			EQU     31H	;/* 上海标准选择寄存器 */
TestDigiSelect		EQU     3DH	;/* 测试管脚配置寄存器 */

;***************************************************
;/* 函数错误代码定义 ERR CODE  */
;***************************************************
FM1702_OK		EQU     0	;/* 正确 */
FM1702_NOTAGERR         EQU     81H	;/* 无卡 */
FM1702_CRCERR           EQU     82H	;/* 卡片CRC校验错误 */
FM1702_EMPTY            EQU     83H	;/* 数值溢出错误 */
FM1702_AUTHERR          EQU     84H	;/* 验证不成功 */
FM1702_PARITYERR        EQU	85H	;/* 卡片奇偶校验错误 */
FM1702_CODEERR		EQU	86H	;/* 通讯错误(BCC校验错) */
FM1702_SERNRERR		EQU	88H	;/* 卡片序列号错误(anti-collision 错误) */
FM1702_SELECTERR	EQU	89H	;/* 卡片数据长度字节错误(SELECT错误) */
FM1702_NOTAUTHERR	EQU	8AH	;/* 卡片没有通过验证 */
FM1702_BITCOUNTERR	EQU	8BH	;/* 从卡片接收到的位数错误 */
FM1702_BYTECOUNTERR	EQU	8CH	;/* 从卡片接收到的字节数错误仅读函数有效 */
FM1702_RESTERR		EQU	8DH	;/* 调用restore函数出错 */
FM1702_TRANSERR		EQU	8EH	;/* 调用transfer函数出错 */
FM1702_WRITEERR		EQU	8FH	;/* 调用write函数出错 */
FM1702_INCRERR		EQU	90H	;/* 调用increment函数出错 */
FM1702_DECRERR		EQU	91H	;/* 调用decrement函数出错 */
FM1702_READERR		EQU	92H	;/* 调用read函数出错 */
FM1702_LOADKEYERR	EQU	93H	;/* 调用LOADKEY函数出错 */
FM1702_FRAMINGERR	EQU	94H	;/* FM1702帧错误 */
FM1702_REQERR		EQU	95H	;/* 调用req函数出错 */
FM1702_SELERR		EQU	96H	;/* 调用sel函数出错 */
FM1702_MIF_ANTICOLLERR	EQU	97H	;/* 调用MIF_ANTICOLL函数出错 */
FM1702_INTIVALERR	EQU	98H	;/* 调用初始化函数出错 */
FM1702_READVALERR	EQU	99H	;/* 调用高级读块值函数出错 */
FM1702_DESELECTERR	EQU	9AH
FM1702_CMD_ERR		EQU	9BH	;/* 命令错误 */
;***************************************************
;口线
;***************************************************
;SCK_1702SL 		BIT     P0.0
;MOSI_1702SL		BIT     P3.7
;MISO_1702SL		BIT     P3.6
IRQ_1702SL		BIT     P3.2
RST_1702SL		BIT     P1.0
;NSS_1702SL		BIT     P0.1
PWR_1702SL		BIT     P1.1

RST_RC500			BIT	p1.0
INT_RC500			BIT	P3.2
WR_RC500			BIT	P3.6
RD_RC500			BIT	P3.7
PWR_RC500			BIT	P1.1
;***********************************************************************************************
                	ORG     0000H
                	LJMP    MAIN

			;ORG	0003H
			;LJMP	EX0_INT

                	ORG     000BH
                	LJMP   	T0_INT

                	ORG	0013H			;INT1
			LJMP	EX1_INT

			ORG     001BH			;喂 MAX824(1.2S)
                	LJMP   	T1_INT

                	ORG	003BH			;INT3
			LJMP	EX3_INT

;***********************************************************************************************
;;;;8563中断服务子程序(RC500)
;***********************************************************************************************
EX1_INT:                CLR	EX1
			CLR	EX3
			ANL	PCON,#11111100B
			SETB	RST_1702SL
			CLR	PWR_1702SL
			SETB	TEST_1702SL
                	CLR	TEST_TONGUE
			CPL	TEST_RC500_1S
			RETI

;***********************************************************************************************
;;;;INT3中断服务子程序
;***********************************************************************************************
EX3_INT:		CLR	EX1
			CLR	EX3
			ANL	PCON,#11111100B
			CLR	TEST_1702SL
                	SETB	TEST_TONGUE
                	RETI

;***********************************************************************************************
;;;;喂外部看门狗MAX824（1.2S）
;***********************************************************************************************
T1_INT:			SETB	MAX824			;喂外部看门狗MAX824
			MOV     TH1,#15H          	;时钟=24MHZ,机器周期为0.5US
                	MOV     TL1,#0A0H         	;定时(2E16-初值)*0.5EXP-6=0.03S
                	NOP
                	NOP
                	CLR	MAX824
                	RETI


;***********************************************************************************************

                	ORG     0100H

MAIN:           	MOV     SP,#STACK_POINT
			MOV	WDTCONTER,#00110111B
			MOV	p0,#0FFh
                        SETB	RD_RC500
			SETB	WR_RC500
			SETB	INT_RC500
			SETB	RST_RC500
			SETB	PWR_24C64
			SETB	SCL_24C64
			SETB	SDA_24C64

MCU_INITIALIZE:		SETB 	MOT_CTRL
			SETB	MOT_PWR
			SETB    RLED
        	        SETB    GLED
                	SETB    BUZZ
    			SETB	TOTAL_PWR
			CLR	PWR_1702SL
    			MOV	20H,#00H		;标志位
    			MOV	21H,#00H		;标志位

                	MOV	LOW45_NUM,#0
                	MOV     TMOD,#01H
                	MOV     T0INTCOUNT,#250    	;0.03S*250=7.5S

		        MOV     TH0,#15H          	;时钟=24MHZ,机器周期为0.5US
                	MOV     TL0,#0A0H         	;定时(2E16-初值)*0.5EXP-6=0.03S
                	SETB    ET0
                	SETB    EA
                	SETB    TR0

                	MOV     TH1,#15H          	;时钟=24MHZ,机器周期为0.5US
                	MOV     TL1,#0A0H         	;定时(2E16-初值)*0.5EXP-6=0.03S
                	SETB    ET1			;开T1中断
                	SETB    TR1			;启动T1

                	SETB	IT0
			CLR	EX0
			SETB	PX0

                        MOV     TIME_60S,#00H

			LCALL	DELAY05S
			LCALL	DELAY05S
			setb	LOW45
			JB	LOW45,AUTO_TEST		;复位后如低于4.5V,不自检(以免写坏EEPROM)
			LCALL	DELAY005S
			JB	LOW45,AUTO_TEST
			MOV	PWR_24C1X_NUM,#0
			LCALL	CLKOUT_8563_CLEAR
			SETB	TEST_1702SL
                	SETB	BKLK_SW_BK
                	LJMP	AUTO_TEST_END		;发声光信号;(此时由于低于4.5V,2分钟左右会停机,但由于外部看门狗的存在,将重复执行复位并到此处)

;***********************************************************************************************
AUTO_TEST:        	setb	reset_flag
			MOV	LOW45_NUM,#0

			;SETB	MOT_CTRL			;上电先关闭电机
			;LCALL	DELAY500US
			;CLR	MOT_PWR
			;LCALL	DELAY02S
			;SETB	MOT_PWR

			SETB	BKLK_SW				;备份方舌状态
			LCALL	DELAY5US
			MOV	C,BKLK_SW
			MOV	BKLK_SW_BK,C
			CLR	BKLK_SW

			LCALL	SELECT_MIFRAM
			MOV	T0INTCOUNT,#250
AUTO_TEST_MIF:		LCALL   INIT_1702
                	;SETB	RST_1702SL
                	CJNE    A,#OK,AUTO_TEST_MIF_1
                	LCALL	SELECT_CLOSERAM
			LJMP	AUTO_TEST_EEPROM
AUTO_TEST_MIF_1:	MOV	A,T0INTCOUNT
                	CJNE	A,#150,AUTO_TEST_MIF_2		;
AUTO_TEST_MIF_2:	JC	AUTO_TEST_ERR1
			AJMP	AUTO_TEST_MIF

AUTO_TEST_EEPROM:	LCALL	READ_ONE_TWO
			CJNE	A,#OK,AUTO_TEST_ERR2

			MOV	HADDR_24C1X,#00H
			MOV	LADDR_24C1X,#04H
			MOV	LENGTH_24C1X,#4
			LCALL	RD_24C64
			CJNE	A,#OK,AUTO_TEST_ERR2

AUTO_TEST_8563:		MOV	PWR_24C1X_NUM,#1
			LCALL	RD_8563
			CJNE	A,#OK,AUTO_TEST_ERR3
			LCALL	XIALING_CHECK_CARD
			CJNE	A,#OK,AUTO_TEST_ERR2
			MOV	XIALING_NUM,#60

			LCALL	CLKOUT_8563
			CJNE	A,#OK,AUTO_TEST_ERR3

			CLR	BUZZ

AUTO_TEST_END:		CLR	RLED
			CLR	GLED
			LCALL	DELAY01S
			SETB	GLED
			SETB	RLED
			SETB	BUZZ
			AJMP	PWR_DOWN


AUTO_TEST_ERR1:		LCALL	LEDBUZZ_LOADKEY_ER	;硬件故障
			AJMP	AUTO_TEST_ERR3

AUTO_TEST_ERR2:		LCALL	LEDBUZZ_EEPROM_ERROR	;24C64读写错误

AUTO_TEST_ERR3:		LCALL	DELAY05S
			LCALL	DELAY05S
			LCALL	DELAY05S
			LJMP	MAIN

;***********************************************************************************************
PWR_DOWN:		LCALL	SELECT_CLOSERAM
			MOV	WDTCONTER,#00110111B
			MOV	T0INTCOUNT,#250
			JB	TEST_1702SL,PWR_DOWN_1
			LCALL	CLKOUT_8563

PWR_DOWN_1:		CLR	TOTAL_PWR
			SETB	PWR_1702SL
			SETB	CLOCK_INT
			SETB	TONGUE_INT

PWR_DOWN_2:		MOV	A,PWR_24C1X_NUM
			JNZ	PWR_DOWN_2

			MOV	C,reset_flag
    			ANL	20H,#00101100B
    			ANL	21H,#10000000B		;标志位
    			MOV	reset_flag,C
    			SETB	MAX824

    			CLR	EA

    			MOV	P0,#00H
			MOV	P1,#11101111B
			MOV	P2,#01000000B
			MOV	P3,#00001011B
			MOV	P4,#00001101B

			CLR	ET0			;关T0中断
			CLR	TR0
			MOV     TH0,#15H          	;时钟=24MHZ,机器周期为0.5US
                	MOV     TL0,#0A0H         	;定时(2E16-初值)*0.5EXP-6=0.03S

			CLR	ET1			;关T1中断
			CLR	TR1
			MOV     TH1,#15H          	;时钟=24MHZ,机器周期为0.5US
                	MOV     TL1,#0A0H         	;定时(2E16-初值)*0.5EXP-6=0.03S

			CLR	IE0
			SETB	IT0
			CLR	EX0

			CLR	IE1
			SETB	IT1
			SETB	EX1

			CLR	IE2
			SETB	IT2
			CLR	EX2

			CLR	IE3
			SETB	IT3
			SETB	EX3

			SETB    EA			;中断总允许
                	MOV	PCON,#00000011B		;掉电!!!!
                	;LCALL	DELAY05S
			;LCALL	DELAY05S
			NOP
			NOP
			NOP
			NOP
			NOP				;几个NOP非常重要,否则程序会乱!!!!


;...............................................................................................

TEST_WORK:		SETB	MOT_CTRL		;MOT_CTRL高电平时反转,以确保锁不常开
			MOV	WDTCONTER,#00110111B
			MOV     T0INTCOUNT,#250
			SETB	ET0			;开T0中断
			SETB	TR0
			JB	TEST_1702SL,TEST_MIF

TEST_WORK_1:		JNB	TEST_TONGUE,TEST_WORK_OVER
			SETB	ET1
			SETB	TR1
			CLR	TEST_TONGUE
			;;JB	CHANG_KAI_FLAG,TEST_WORK_1_3
			;SETB	KEY_SW
			SETB	TONGUE_SW
			LCALL	DELAY5US
			JB	KEY_SW,TEST_WORK_1_1
			;CLR	KEY_SW
			;;JB	TONGUE_SW,TEST_WORK_1_3  	;检测主舌,无主舌为开关抖动，跳转
			CLR	TONGUE_SW
			LJMP	REC_KEY

TEST_WORK_1_1:		MOV	R6,#1
TEST_WORK_1_1_1:	MOV	R7,#100
TEST_WORK_1_2:		;CLR	KEY_SW
			;;SETB	BKLK_SW
			;;LCALL	DELAY5US
			;;JNB	BKLK_SW,TEST_WORK_1_3

			;CLR	TONGUE_SW
			;SETB	KEY_SW
			;SETB	TONGUE_SW
			LCALL	DELAY5US
			;;JB	TONGUE_SW,TEST_WORK_1_3  	;检测主舌,无主舌为开关抖动，跳转
			JB	KEY_SW,TEST_WORK_1_2_1
			LJMP	REC_KEY
TEST_WORK_1_2_1:	DJNZ	R7,TEST_WORK_1_2
			DJNZ	R6,TEST_WORK_1_1_1
			;LJMP	TONGUE_TEST

TEST_WORK_1_3:		CLR	BKLK_SW
			CLR	KEY_SW
			CLR	TONGUE_SW
			SETB	OBSW
			LCALL	DELAY5US
			JB	OBSW,TEST_WORK_1_4 		;检测出门按钮,跳转检测原始卡
			CLR	OBSW
			LJMP	OBSW_TEST

TEST_WORK_1_4:		SETB	YSK_SW
			CLR	OBSW
			LCALL	DELAY5US
			JB	YSK_SW,TEST_WORK_OVER
			CLR	YSK_SW
			LJMP	YSK_TEST

TEST_WORK_OVER:		LJMP    PWR_DOWN

;***********************************************************************************************
;测试RC500有没有卡片
TEST_MIF:		MOV	A,LOW45_NUM
			CJNE	A,#LOW_VOL_LIMIT_250,TEST_MIF_1
TEST_MIF_1:		JC	TEST_MIF_2
			LCALL	CLKOUT_8563_CLEAR
			LJMP	PWR_DOWN

TEST_MIF_2:		MOV	A,XIALING_NUM
		        JNZ	TEST_MIF_2_1
			MOV	XIALING_NUM,#120;修改为近似每分钟检测一次
		        LCALL	XIALING_TEST;夏令时检测，每分钟检测一次
                        LCALL   AUTO_CHANGKAI_TEST;定时常开检测，每分钟检测一次

TEST_MIF_2_1:		DEC	XIALING_NUM
			CLR	RST_1702SL
			SETB	LOW45
			NOP
			NOP
			JB	LOW45,TEST_MIF_3
			INC	LOW45_NUM
			AJMP	TEST_MIF_4
TEST_MIF_3:		MOV	LOW45_NUM,#0
TEST_MIF_4:		CLR	LOW45
			JB	TEST_RC500_1S,TEST_MIF_BKLK_SW
                        MOV	p0,#0FFh
			SETB	RD_RC500
			SETB	WR_RC500
			SETB	INT_RC500
			MOV	T0INTCOUNT,#1
			MOV     TH0,#15H          	;时钟=24MHZ,机器周期为0.5US
                	MOV     TL0,#0A0H         	;定时(2E16-初值)*0.5EXP-6=0.03S
                	SETB	ET0			;关T0中断
			SETB	TR0

			LCALL	SELECT_MIFRAM

			mov	count1,#2
			LCALL	mifscard_1
			CJNE	A,#OK,TEST_MIF_BKLK_SW

			MOV	T0INTCOUNT,#250
			LCALL	CPU_INITIALIZE
			CLR	TEST_1702SL
			SETB	TONGUE_SW		;密码卡时的防抖动
			LCALL	DELAY5US
			MOV	C,TONGUE_SW
			MOV	TONGUE_SW_BK,C
			CLR	TONGUE_SW
			LCALL	TEST_M1_PLUS
			CJNE	A,#OK,TEST_MIF_BKLK_SW
			LJMP	READ_CARD

TEST_MIF_BKLK_SW:       JB	JIU_DIAN_FLAG,TEST_MIF_OVER_NO
                        JNB	ONE_OPEN_FLAG,TEST_MIF_OVER_NO
			SETB	BKLK_SW
			LCALL	DELAY5US
			JB	BKLK_SW,TEST_MIF_BKLK_SW_1
			JNB	BKLK_SW_BK,TEST_MIF_OVER
			MOV	C,BKLK_SW
			MOV	BKLK_SW_BK,C
			LCALL	CPU_INITIALIZE
			LCALL	RD_8563
			MOV	A,#CLOSE
			MOV	B,#NO_CARD
                	LCALL	SAVE_REC
			CLR	CHANG_KAI_FLAG
			LCALL	MOT_REVERSE
			LJMP	TEST_MIF_OVER_END

TEST_MIF_BKLK_SW_1:	JB	BKLK_SW_BK,TEST_MIF_OVER
			MOV	C,BKLK_SW
			MOV	BKLK_SW_BK,C
			LCALL	CPU_INITIALIZE
			LCALL	RD_8563
			MOV     A,#INTEROPEN		;记录“门内开锁”
			MOV	B,#NO_CARD
                	LCALL	SAVE_REC
			SETB	CHANG_KAI_FLAG

			LCALL	MOT_POSITIVE
			LJMP	TEST_MIF_OVER_END

TEST_MIF_OVER:		SETB	BKLK_SW
			LCALL	DELAY5US
			MOV	C,BKLK_SW
			MOV	BKLK_SW_BK,C
			CLR	BKLK_SW
TEST_MIF_OVER_END:	LJMP    PWR_DOWN

TEST_MIF_OVER_NO:	lcall	DELAY100US		;唤醒时程序执行时间太短，会马上再次唤醒，所以一定要延时
			LJMP    PWR_DOWN

;***********************************************************************************************
;记录机械钥匙
REC_KEY:          	;CLR	KEY_SW

                	MOV	R7,#45
REC_KEY2:               MOV     COUNT0,#200		;记录机械钥匙开锁
REC_KEY1:          	SETB	TONGUE_SW
			LCALL	DELAY5US
			JB	TONGUE_SW,REC_KEY4	;如果主舌松开,马上记录
                	CLR	TONGUE_SW
			LCALL	DELAY100US
                	DJNZ	COUNT0,REC_KEY1		;如果主舌一直不松开,等待1.2S
		        DJNZ	R7,REC_KEY2

REC_KEY3:       	CLR	TONGUE_SW
			LCALL	CPU_INITIALIZE
			LCALL	LEDBUZZ_TONGUE_SW	;主舌一直不松开,亮0.5S红灯再记录

REC_KEY4:		CLR	TONGUE_SW
			LCALL	CPU_INITIALIZE
			LCALL	RD_8563
                	CLR	GLED
                	MOV	A,#KEYOPEN
                	MOV	B,#NO_CARD
                	LCALL   SAVE_REC
                	LCALL	DELAY02S
                	SETB	GLED
                	;CJNE	A,#OK,REC_KEY_EEPROM_ERR;读写24C16(记录)失败,跳ER_R_W_24C16
REC_KEY_END:          	LJMP    PWR_DOWN

REC_KEY_EEPROM_ERR:	LCALL	LEDBUZZ_EEPROM_ERROR		;24C64读写错误
			LJMP	PWR_DOWN
;***********************************************************************************************
;记录门没有关好///门内常开
TONGUE_TEST:            JB	JIU_DIAN_FLAG,TONGUE_TEST_END
                        ;CLR	KEY_SW
           	  	CLR	TONGUE_SW
             	  	;JB	BKLK_SW_BK,TONGUE_TEST_END
			LCALL	CPU_INITIALIZE
			LCALL	RD_8563
			MOV     A,#INTEROPEN		;记录“门内开锁”
			MOV	B,#NO_CARD
                	LCALL   SAVE_REC
                	SETB	CHANG_KAI_FLAG

			LCALL	MOT_POSITIVE
;			CLR	MOT_CTRL			;正转
;			LCALL	DELAY500US
;			CLR	MOT_PWR
;
;			MOV	R6,#4
;TONGUE_TEST_1:		JNB	KEY_SW,TONGUE_TEST_2
;			SETB	REC_KEY_FLAG
;TONGUE_TEST_2:		LCALL	DELAY005S
;			DJNZS	R6,TONGUE_TEST_1
;			SETB	MOT_PWR
;			LCALL	DELAY500US
;
TONGUE_TEST_END:        CLR	TONGUE_SW
			LJMP	PWR_DOWN

;TONGUE_TEST:    	;CLR	KEY_SW
;
;			MOV	R7,#90
;TONGUE_TEST2:		MOV     COUNT0,#200
;TONGUE_TEST1:		SETB	TONGUE_SW
;			LCALL	DELAY5US
;			JB	TONGUE_SW,TONGUE_TEST_END	;门关好
;               	CLR	TONGUE_SW
;			LCALL	DELAY100US
;                	DJNZ	COUNT0,TONGUE_TEST1	;
;                	DJNZ	R7,TONGUE_TEST2			;所有检测"门未关好"时间为2S
;               	CLR	TONGUE_SW
;
;               	LCALL	CPU_INITIALIZE
;			LCALL	LEDBUZZ_NOCLOSE
;		    	LCALL	RD_8563
;			MOV     A,#CLOSE_X		;记录“门未关好”
;			MOV	B,#NO_CARD
;                	LCALL   SAVE_REC
;                	CJNE	A,#OK,TONGUE_TEST_EEPROM_ERR;读写24C16(记录)失败,跳ER_R_W_24C16
;
;TONGUE_TEST_END:        CLR	TONGUE_SW
;			LJMP    PWR_DOWN
;
;TONGUE_TEST_EEPROM_ERR:	LCALL	LEDBUZZ_EEPROM_ERROR		;24C64读写错误
;			LJMP	PWR_DOWN
;***********************************************************************************************
;出门按钮
OBSW_TEST:		LCALL	DELAY001S
			SETB	OBSW
			LCALL	DELAY5US
			JB	OBSW,OBSW_TEST_END
			CLR	OBSW
			LCALL	CPU_INITIALIZE
                        LCALL	DELAY001S
			LCALL	RD_8563
			MOV	A,#OUTBUTTON
			MOV	B,#NO_CARD
                	LCALL	SAVE_REC
			;CJNE	A,#OK,OBSW_TEST_EEPROM_ERR	;记录错也要开门
			CLR	BUZZ			;蜂鸣0.5S 1次
			CLR	GLED
			LCALL	MOT_POSITIVE
			LCALL	DELAY02S
			SETB	BUZZ
			SETB	GLED
			JB	CHANG_KAI_FLAG,OBSW_TEST_END
			LCALL	DELAY05S
			LCALL	DELAY05S
			LCALL	DELAY05S
			LCALL	DELAY05S
			LCALL	MOT_REVERSE
OBSW_TEST_END:		LJMP	PWR_DOWN

OBSW_TEST_EEPROM_ERR:	LCALL	LEDBUZZ_EEPROM_ERROR		;24C64读写错误
			LJMP	PWR_DOWN
;***********************************************************************************************
;原始卡按钮
YSK_TEST:		MOV	COUNT0,#120
YSK_TEST_1:		SETB	YSK_SW
			LCALL	DELAY5US
			JB	YSK_SW,YSK_TEST_END
			CLR	YSK_SW
			LCALL	DELAY001S
			DJNZ	COUNT0,YSK_TEST_1
			LCALL	CPU_INITIALIZE
			LJMP	YUAN_SHI_CARD2

YSK_TEST_END:		CLR	YSK_SW
			LJMP	PWR_DOWN

;***********************************************************************************************
READ_CARD:           	MOV 	COUNT0,#10         	;钥匙、主舌都不是,再次寻卡

READ_CARD1:		MOV	T0INTCOUNT,#250
READ_CARD1_1:      	mov	count1,#10		;mifscard_1中使用的参数

                        LCALL	SELECT_MIFRAM
			MOV  	R1,#As_Buffer
			MOV	@R1,#0FFH
			INC	R1
			MOV	@R1,#0FFH
READ_CARD1_2:           LCALL	INIT_1702
			CJNE	A,#OK,READ_CARD1X_ERR

                        LCALL   MIF_HALT
                        CJNE	A,#OK,READ_CARD1X_ERR

                        LCALL	MIF_REQUEST			;MIF_REQUEST中已判断0400H
			CJNE	A,#OK,READ_CARD1X_ERR
			LJMP    READ_7S

READ_CARD1X_ERR:	DJNZ	COUNT1,READ_CARD1_2
               		LCALL	DELAY005S
			;LCALL	DELAY002S
			;LCALL	DELAY002S
			DJNZ	COUNT0,READ_CARD1_1
			LJMP	PWR_DOWN

                	CJNE	A,#ERROR,READ_7S
               		LCALL	DELAY005S
			;LCALL	DELAY002S
			;LCALL	DELAY002S
			DJNZ	COUNT0,READ_CARD1_1
			LJMP	PWR_DOWN

READ_CARD1_ERR_JP:	LJMP	READ_CARD1_ERR

READ_7S:         	MOV	T0INTCOUNT,#34
                        MOV	U_SECNR,#7
                        LCALL	MIF_ANTICOLL
			CJNE	A,#OK,READ_CARD1_ERR_JP
			LCALL   SELECT_CARD
			CJNE	A,#OK,READ_CARD1_ERR_JP
			LCALL   LOAD_KEYE2
			CJNE	A,#OK,READ_CARD1_ERR_JP
			LCALL   AUTHENTICATION
			CJNE	A,#OK,READ_CARD1_ERR_JP

RD_28:			MOV	U_SECNR,#7
			MOV	U_BLKNR,#28
			LCALL   MIF_READ
			CJNE	A,#OK,READ_CARD1_ERR_JP

RD28_CTYPE_OK:    	MOV 	R0,#As_Buffer
                	MOV 	R1,#BUFF_BEG_MIF
                	MOV 	R7,#16
RD28LOOP:  	    	MOV 	A,@R0
                	MOV 	@R1,A
                	INC 	R0
                	INC 	R1
                	DJNZ 	R7,RD28LOOP		;将第1块的16字节移至BUFF_BEG_MIF开始

RD_29:                	MOV  	U_BLKNR,#29
			LCALL	MIF_READ		;第29块
			CJNE	A,#OK,READ_CARD1_ERR_JP

                	MOV 	R0,#As_Buffer
                	MOV 	R1,#BUFF_BEG_MIF+16
                	MOV 	R7,#16
RD29LOOP:     	 	MOV 	A,@R0
                	MOV 	@R1,A
                	INC 	R0
                	INC 	R1
                	DJNZ 	R7,RD29LOOP		;将第29块的16字节移至BUFF_BEG_MIF+16开始

			;;;;;;;;;;;;;;;;;;是全00或全FF的卡要再去读0扇区
CHECK_NS_00H:           MOV	R0,#BUFF_BEG_MIF
                	MOV	R7,#24
CHECK_NS_00H_1:	   	CJNE	@R0,#00H,CHECK_NS_FFH
                	INC	R0
                	DJNZ	R7,CHECK_NS_00H_1
                	LJMP	READ_0S
CHECK_NS_FFH: 		MOV	R0,#BUFF_BEG_MIF
                	MOV	R7,#24
CHECK_NS_FFH_1:	   	CJNE	@R0,#0FFH,CHECK_00H_OR_08H
                	INC	R0
                	DJNZ	R7,CHECK_NS_FFH_1
                	LJMP	READ_0S

CHECK_00H_OR_08H:   	;MOV	R0,#BUFF_BEG_MIF		;如果是原始卡或记录卡不用判断56H78H
                	;CJNE	@R0,#00H,CHECK_00H_OR_08H_1
                	;LJMP	CHECK_0_24
CHECK_00H_OR_08H_1:    ;	CJNE	@R0,#08H,CHECK_00H_OR_08H_2
                	;LJMP	CHECK_0_24

                	;;;;;;;;;;;;;;;;;;如果24、25字节不是56H78H为读错
CHECK_00H_OR_08H_2: 	MOV	R0,#BUFF_BEG_MIF+24
                	CJNE	@R0,#56H,READ_CARD1_ERR_ADP1
                	MOV	R0,#BUFF_BEG_MIF+25
                	CJNE	@R0,#78H,READ_CARD1_ERR_ADP1
                        LJMP    CHECK_0_24
READ_CARD1_ERR_ADP1:    MOV	R0,#BUFF_BEG_MIF+24
                	CJNE	@R0,#60H,READ_CARD1_ERR
                	MOV	R0,#BUFF_BEG_MIF+25
                	CJNE	@R0,#78H,READ_CARD1_ERR              ;如果24、25字节是60H78H为正确卡（密码加密卡）
                	;;;;;;;;;;;;;;;;;;;;

CHECK_0_24:           	MOV     R7,#24			;校验前24字节
                	CLR     A
                	MOV     R0,#BUFF_BEG_MIF
CHECK_0_24_1:          	XRL     A,@R0
                	INC     R0
                	DJNZ    R7,CHECK_0_24_1
			JNZ	READ_CARD1_ERR

                        LCALL   UN_ENCODE                               ;前24字节校验通过后就可以进行加密密码的解密了

RD29_CTYPE:		MOV	R0,#BUFF_BEG_MIF		;授权\清除\挂失\多层\房间卡读7扇区第2块
			CJNE	@R0,#05H,RD29_CTYPE_1
			LJMP	RD_30
RD29_CTYPE_1:		CJNE	@R0,#06H,RD29_CTYPE_2
			LJMP	RD_30
RD29_CTYPE_2:		CJNE	@R0,#07H,RD29_CTYPE_3
			LJMP	RD_30
RD29_CTYPE_3:		CJNE	@R0,#0BH,RD29_CTYPE_4
			LJMP	RD_30
RD29_CTYPE_4:           CJNE	@R0,#10H,RD29_CTYPE_5
			LJMP	RD_30
RD29_CTYPE_5:           CJNE	@R0,#80H,RD29_CTYPE_6
			LJMP	RD_30
RD29_CTYPE_6:           CJNE	@R0,#0DH,READ_7S_OK

RD_30:			MOV  	U_BLKNR,#30
			LCALL	MIF_READ		;第30块
			CJNE	A,#OK,READ_CARD1_ERR

                	MOV 	R0,#As_Buffer
                	MOV 	R1,#LS_BEG_MIF		;第30块暂存在40H-4FH
                	MOV 	R7,#16			;退出读卡程序时要把数据存入0B0H-0BFH
RD30LOOP:   	   	MOV 	A,@R0
                	MOV 	@R1,A
                	INC 	R0
                	INC 	R1
                	DJNZ 	R7,RD30LOOP		;将第30块的16字节移至LS_BEG_MIF开始

CHECK_25_47:           	MOV     R7,#16			;校验后24字节
                	CLR     A
                	MOV     R0,#LS_BEG_MIF
CHECK_25_47_1:         	XRL     A,@R0
                	INC     R0
                	DJNZ    R7,CHECK_25_47_1
                	MOV     R7,#8
                	MOV     R0,#BUFF_BEG_MIF+24
CHECK_25_47_2:         	XRL     A,@R0
                	INC     R0
                	DJNZ    R7,CHECK_25_47_2
                	MOV     R0,#BUFF_BEG_MIF+22
                	XRL     A,@R0
			JZ	READ_7S_OK

READ_CARD1_ERR:        	DJNZ	COUNT0,READ_CARD1_JP	;校验错，或读卡错,再读
			LJMP	READ_0S			;去读0扇区

READ_CARD1_JP:		LJMP	READ_CARD1
;;;;;;;;;;;;;;;;;;;;;;;;
READOK_JP:		MOV	R0,#BUFF_BEG_MIF		;授权\清除\挂失\多层\房间卡读7扇区第2块
			CJNE	@R0,#05H,RD30_CTYPE_1
			LJMP	READOK_JP_1
RD30_CTYPE_1:		CJNE	@R0,#06H,RD30_CTYPE_2
			LJMP	READOK_JP_1
RD30_CTYPE_2:		CJNE	@R0,#07H,RD30_CTYPE_3
			LJMP	READOK_JP_1
RD30_CTYPE_3:		CJNE	@R0,#0BH,RD30_CTYPE_4
			LJMP	READOK_JP_1
RD30_CTYPE_4:           CJNE	@R0,#10H,RD30_CTYPE_5
			LJMP	READOK_JP_1
RD30_CTYPE_5:           CJNE	@R0,#80H,RD30_CTYPE_6
			LJMP	READOK_JP_1
RD30_CTYPE_6:           CJNE	@R0,#0DH,READOK_JP_2

READOK_JP_1:           	MOV 	R0,#LS_BEG_MIF
                	MOV 	R1,#LSBUFF_BEG_MIF	;多层卡和房间卡多读的一块暂存在40H-4FH
                	MOV 	R7,#16			;退出读卡程序时要把数据存入0B0H-0BFH
READOK_LOOP:      	MOV 	A,@R0
                	MOV 	@R1,A
                	INC 	R0
                	INC 	R1
                	DJNZ 	R7,READOK_LOOP		;将第30块的16字节移至0B0H开始
READOK_JP_2:            LCALL   READ_CARD3
                        LJMP	READOK
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
READ_7S_OK:
                        MOV	R0,#BUFF_BEG_MIF	;
			CJNE	@R0,#09H,READ_7S_OK_1	;>=09,开门卡
READ_7S_OK_1:		JC	READOK_JP		;
			LJMP	READ_8S
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
READ_CARD2:		MOV	T0INTCOUNT,#250
READ_CARD2_1:      	mov	count1,#10		;mifscard_1中使用的参数
			LCALL	mifscard_1
                	CJNE	A,#ERROR,READ_8S
               		LCALL	DELAY005S
			LCALL	DELAY002S
			LCALL	DELAY002S
			DJNZ	COUNT0,READ_CARD2_1
			LJMP	PWR_DOWN

READ_CARD2_ERR_JP:	LJMP	READ_CARD2_ERR

READ_8S:                MOV	U_SECNR,#8
                        LCALL	MIF_ANTICOLL
			CJNE	A,#OK,READ_CARD2_ERR
			LCALL   SELECT_CARD
			CJNE	A,#OK,READ_CARD2_ERR
			LCALL   LOAD_KEYE2
			CJNE	A,#OK,READ_CARD2_ERR
			LCALL   AUTHENTICATION
			CJNE	A,#OK,READ_CARD2_ERR
RD_32:			MOV	U_SECNR,#8
			MOV  	U_BLKNR,#32
			LCALL	MIF_READ		;第32块
			CJNE	A,#OK,READ_CARD2_ERR

                	MOV 	R0,#As_Buffer
                	MOV 	R1,#BUFF_BEG_MIF+32
                	MOV 	R7,#16
RD32LOOP:   	   	MOV 	A,@R0
                	MOV 	@R1,A
                	INC 	R0
                	INC 	R1
                	DJNZ 	R7,RD32LOOP		;将第32块的16字节移至BUFF_BEG_MIF+32开始

RD_33:                	MOV  	U_BLKNR,#33
			LCALL	MIF_READ		;第33块
			CJNE	A,#OK,READ_CARD2_ERR

                	MOV 	R0,#As_Buffer
                	MOV 	R1,#BUFF_BEG_MIF+48
                	MOV 	R7,#16
RD33LOOP:    	  	MOV 	A,@R0
                	MOV 	@R1,A
                	INC 	R0
                	INC 	R1
                	DJNZ 	R7,RD33LOOP		;将第33块的16字节移至BUFF_BEG_MIF+48开始

RD_34:			MOV  	U_BLKNR,#34
			LCALL	MIF_READ		;第34块
			CJNE	A,#OK,READ_CARD2_ERR		;第34块地址正好顺延

                        MOV 	R0,#As_Buffer
                	MOV 	R1,#BUFF_BEG_MIF+64
                	MOV 	R7,#16
RD34LOOP:    	  	MOV 	A,@R0
                	MOV 	@R1,A
                	INC 	R0
                	INC 	R1
                	DJNZ 	R7,RD34LOOP

                        MOV 	R0,#BUFF_BEG_MIF
                        MOV     A,@R0
                        XRL     A,#16H
                        JZ      CHECK36_2
                        MOV 	R0,#BUFF_BEG_MIF
                        MOV     A,@R0
                        XRL     A,#17H
                        JZ      CHECK36_2               ;若卡片是自动常开设置卡（新）或可用时段设置卡，则直接跳过校验


CHECK36:           	MOV     R7,#36			;校验后36字节
                	CLR     A
                	MOV     R0,#BUFF_BEG_MIF+32
CHECK36_1:           	XRL     A,@R0
                	INC     R0
                	DJNZ    R7,CHECK36_1
                	JNZ	READ_CARD2_ERR
CHECK36_2:
                	LJMP	READOK_JP

READ_CARD2_ERR:        	DJNZ	COUNT0,READ_CARD2_JP	;校验错，或读卡错,再读
                	LJMP	RDER			;读卡错/卡格式错(即校验错)报警
READ_CARD2_JP:		LJMP	READ_CARD2

;;;;;读0扇区
READ_0S:		MOV	COUNT0,#10
			MOV	T0INTCOUNT,#250
RD0S_1:	    	  	mov	count1,#10		;mifscard_1中使用的参数
			LCALL	mifscard_1
                	CJNE	A,#ERROR,RD0S_READON
               		LCALL	DELAY005S
			LCALL	DELAY002S
			LCALL	DELAY002S
			DJNZ	COUNT0,RD0S_1
			LJMP	PWR_DOWN

RD0S_ER_JP:		LJMP	RD0S_ER

RD0S_READON:         	MOV	T0INTCOUNT,#34
			MOV	U_SECNR,#0
			LCALL	MIF_ANTICOLL
			CJNE	A,#OK,RD0S_ER_JP
			LCALL   SELECT_CARD
			CJNE	A,#OK,RD0S_ER_JP
			LCALL   LOAD_KEYE2
			CJNE	A,#OK,RD0S_ER_JP
			LCALL   AUTHENTICATION
			CJNE	A,#OK,RD0S_ER_JP

			MOV	U_SECNR,#0
			MOV  	U_BLKNR,#1
			LCALL	MIF_READ		;第1块
			CJNE	A,#OK,RD0S_ER_JP

                	MOV 	R0,#As_Buffer
                	MOV	A,@R0
                	CJNE	A,#08H,RD0S_CTYPE_1		;
                	LJMP	RD0S_CTYPE_OK
RD0S_CTYPE_1:         	CJNE	A,#00H,RD0S_CTYPE_2		;此处0扇区只处理这2种卡
			LJMP	RD0S_CTYPE_OK
RD0S_CTYPE_2:         	LJMP	RD0S_ER

RD0S_CTYPE_OK:		MOV 	R0,#As_Buffer
                	MOV 	R1,#BUFF_BEG_MIF
                	MOV 	R7,#16
RD0S_3:    	  	MOV 	A,@R0
                	MOV 	@R1,A
                	INC 	R0
                	INC 	R1
                	DJNZ 	R7,RD0S_3		;将第1块的16字节移至BUFF_BEG_MIF开始

                	MOV  	U_BLKNR,#2
			LCALL	MIF_READ		;第2块
			CJNE	A,#OK,RD0S_ER

                	MOV 	R0,#As_Buffer
                	MOV 	R1,#BUFF_BEG_MIF+16
                	MOV 	R7,#16
RD0S_4:      		MOV 	A,@R0
                	MOV 	@R1,A
                	INC 	R0
                	INC 	R1
                	DJNZ 	R7,RD0S_4		;将第2块的16字节移至BUFF_BEG_MIF+16开始

CHECK0S_24:           	MOV     R7,#24			;校验前24字节
                	CLR     A
                	MOV     R0,#BUFF_BEG_MIF
CHECK0S_24_1:          	XRL     A,@R0
                	INC     R0
                	DJNZ    R7,CHECK0S_24_1
			JNZ	RD0S_ER
                        LCALL   UN_ENCODE                               ;前24字节校验通过后就可以进行记录卡加密密码的解密了
			LJMP	READOK

RD0S_ER:               	DJNZ	COUNT0,RD0S_1_JP	;校验错，或读卡错,再读

RDER:                	MOV	T0INTCOUNT,#250
			SETB	RST_1702SL
			CLR 	BUZZ			;&&
			LCALL	DELAY002S
			SETB	BUZZ
			LCALL	LEDBUZZ_FORMAT_ERROR	;读卡错/卡格式错(即校验错)报警
                	LJMP	PWR_DOWN

RD0S_1_JP:		LJMP	RD0S_1
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
READ_CARD3:           	MOV 	COUNT0,#5

READ_CARD3_1:		MOV	T0INTCOUNT,#250
READ_CARD3_2:      	mov	count1,#10		;mifscard_1中使用的参数
			LCALL	mifscard_1
                	CJNE	A,#ERROR,READ_10S
               		LCALL	DELAY002S
			;LCALL	DELAY002S
READ_CARD3_ERR:        	DJNZ	COUNT0,READ_CARD3_2	;校验错，或读卡错,再读
			LJMP	READ_CARD3_OVER

READ_10S:         	MOV	T0INTCOUNT,#34
			MOV	U_SECNR,#10
			LCALL	MIF_ANTICOLL
			CJNE	A,#OK,READ_CARD3_ERR
			LCALL   SELECT_CARD
			CJNE	A,#OK,READ_CARD3_ERR
			LCALL   LOAD_KEYE2
			CJNE	A,#OK,READ_CARD3_ERR
			LCALL   AUTHENTICATION
			CJNE	A,#OK,READ_CARD3_ERR

RD_40:			MOV	U_BLKNR,#40
			LCALL   MIF_READ
			CJNE	A,#OK,READ_CARD3_ERR

			LCALL	SELECT_EXTRAM
			MOV 	R0,#As_Buffer
                	MOV 	R1,#FJCBUFF_BEG_MIF+00H
                	MOV 	R7,#16
RD40LOOP:  	    	MOV 	A,@R0
                	MOVX 	@R1,A
                	INC 	R0
                	INC 	R1
                	DJNZ 	R7,RD40LOOP
                	LCALL	SELECT_MIFRAM

RD_41:                	MOV	U_BLKNR,#41
			LCALL   MIF_READ
			CJNE	A,#OK,READ_CARD3_ERR

                	LCALL	SELECT_EXTRAM
			MOV 	R0,#As_Buffer
                	MOV 	R1,#FJCBUFF_BEG_MIF+10H
                	MOV 	R7,#16
RD41LOOP:     	 	MOV 	A,@R0
                	MOVX 	@R1,A
                	INC 	R0
                	INC 	R1
                	DJNZ 	R7,RD41LOOP
			LCALL	SELECT_MIFRAM

RD_42:                	MOV	U_BLKNR,#42
			LCALL   MIF_READ
			CJNE	A,#OK,READ_CARD3_ERR

                	LCALL	SELECT_EXTRAM
			MOV 	R0,#As_Buffer
                	MOV 	R1,#FJCBUFF_BEG_MIF+20H
                	MOV 	R7,#16
RD42LOOP:     	 	MOV 	A,@R0
                	MOVX 	@R1,A
                	INC 	R0
                	INC 	R1
                	DJNZ 	R7,RD42LOOP
			LCALL	SELECT_MIFRAM
                        LJMP    RD42CHECK


READ_CARD3_ERR_JP:	LJMP	READ_CARD3_ERR

RD42CHECK:		MOV 	R0,#BUFF_BEG_MIF
                        MOV     A,@R0
                        XRL     A,#16H
                        JZ      READ_CARD3_OK
                        MOV 	R0,#BUFF_BEG_MIF
                        MOV     A,@R0
                        XRL     A,#17H
                        JZ      READ_CARD3_OK

                        LCALL	SELECT_EXTRAM
                        MOV 	R1,#FJCBUFF_BEG_MIF
                	CLR	A
                	MOV	B,A
                	MOV 	R7,#48
RD42CHECK_2:     	MOVX 	A,@R1
                	XRL	A,B
                	MOV	B,A
                	INC 	R1
                	DJNZ 	R7,RD42CHECK_2
			LCALL	SELECT_MIFRAM
			MOV	A,B
			JZ	READ_CARD3_OK

READ_CARD3_OVER:	MOV	T0INTCOUNT,#250
			MOV	A,#ERROR
			RET

READ_CARD3_OK:
                        MOV 	COUNT0,#5

READ_CARD4_1:		MOV	T0INTCOUNT,#250
READ_CARD4_2:      	mov	count1,#10		;mifscard_1中使用的参数
			LCALL	mifscard_1
                	CJNE	A,#ERROR,READ_11S
               		LCALL	DELAY002S
			;LCALL	DELAY002S
READ_CARD4_ERR:        	DJNZ	COUNT0,READ_CARD4_2	;校验错，或读卡错,再读
			LJMP	READ_CARD3_OVER
READ_11S:
                        MOV	T0INTCOUNT,#34
			MOV	U_SECNR,#11
			LCALL	MIF_ANTICOLL
			CJNE	A,#OK,READ_CARD4_ERR
			LCALL   SELECT_CARD
			CJNE	A,#OK,READ_CARD4_ERR
			LCALL   LOAD_KEYE2
			CJNE	A,#OK,READ_CARD4_ERR
			LCALL   AUTHENTICATION
			CJNE	A,#OK,READ_CARD4_ERR

			MOV	U_BLKNR,#44
			LCALL   MIF_READ
			CJNE	A,#OK,READ_CARD4_ERR

			LCALL	SELECT_EXTRAM
			MOV 	R0,#As_Buffer
                	MOV 	R1,#FJCBUFF_BEG_MIF+30H
                	MOV 	R7,#16
RD43LOOP:  	    	MOV 	A,@R0
                	MOVX 	@R1,A
                	INC 	R0
                	INC 	R1
                	DJNZ 	R7,RD43LOOP
                	LCALL	SELECT_MIFRAM

                	MOV	U_BLKNR,#45
			LCALL   MIF_READ
			CJNE	A,#OK,READ_CARD4_ERR

                	LCALL	SELECT_EXTRAM
			MOV 	R0,#As_Buffer
                	MOV 	R1,#FJCBUFF_BEG_MIF+40H
                	MOV 	R7,#16
RD44LOOP:     	 	MOV 	A,@R0
                	MOVX 	@R1,A
                	INC 	R0
                	INC 	R1
                	DJNZ 	R7,RD44LOOP
			LCALL	SELECT_MIFRAM

                	MOV	U_BLKNR,#46
			LCALL   MIF_READ
			CJNE	A,#OK,READ_CARD4_ERR

                	LCALL	SELECT_EXTRAM
			MOV 	R0,#As_Buffer
                	MOV 	R1,#FJCBUFF_BEG_MIF+50H
                	MOV 	R7,#16
RD45LOOP:     	 	MOV 	A,@R0
                	MOVX 	@R1,A
                	INC 	R0
                	INC 	R1
                	DJNZ 	R7,RD45LOOP
			LCALL	SELECT_MIFRAM

                        MOV	T0INTCOUNT,#250
			SETB	FANGHAOCARD_FLAG
			MOV	A,#OK
			RET
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
READONI:		LJMP	ER_R_W_24C16

READOK:			MOV	T0INTCOUNT,#250
			MOV	WDTCONTER,#00110111B
			LCALL	CPU_INITIALIZE
			LCALL	SELECT_CLOSERAM

			;SETB	RST_RC500
			MOV	P0,#00H
			CLR	INT_RC500
			CLR	WR_RC500
			CLR	RD_RC500

			CLR 	BUZZ			;&&
			LCALL	DELAY002S
			SETB	BUZZ

                        CLR	JIU_DIAN_FLAG
			MOV	HADDR_24C1X,#00H
			MOV	LADDR_24C1X,#5FH
			MOV	LENGTH_24C1X,#1
			LCALL	RD_24C64		;读出公司标志等(16BYTE)以备用
			CJNE	A,#OK,READONI
			MOV	A,BUFF_BEG_24C1X
			CJNE	A,#01H,READON01
			SETB	JIU_DIAN_FLAG

READON01:

			LCALL	READ_ONE_TWO
			CJNE	A,#OK,READONf

			LCALL	TEST_VOL		;测电压
			MOV	VOL_STATE,A		;状态放VOL_STATE,备用
			CJNE	A,#V_HIGH,READON00
			MOV	BUFF_BEG_24C1X,#00H
			MOV	HADDR_24C1X,#00H
			MOV	LADDR_24C1X,#0DH
			MOV	LENGTH_24C1X,#1
			LCALL	WR_24C64		;高压时,清低压计数器为0
			CJNE	A,#OK,READONF


READON00:		MOV	HADDR_24C1X,#00H
			MOV	LADDR_24C1X,#00H
			MOV	LENGTH_24C1X,#16
			LCALL	RD_24C64		;读出公司标志等(16BYTE)以备用
			CJNE	A,#OK,READONF
			MOV	A,BUFF_BEG_24C1X+0BH
			JZ	READON00_1
			SETB	TONG_DAO_FLAG

READON00_1:		MOV	A,BUFF_BEG_MIF

			CJNE	A,#00H,READON1
			LJMP	YUAN_SHI_CARD		;原始卡

READON1:		CJNE	A,#01H,READON10
			LJMP	MI_MA_CARD		;密码卡

READON10:		CJNE	A,#10H,READON80
			LJMP	SHE_ZHI_CARD		;设置卡

READON80:		CJNE	A,#80H,READON9
			LJMP	SHE_ZHI_CARD		;设置卡

READON9:		CJNE	A,#09H,READONA
			LJMP	KAI_SUO_CARD		;JING_JI_CARD

READONA:		CJNE	A,#0AH,READONB
			LJMP	KAI_SUO_CARD		;ZONG_KONG_CARD

READONB:		CJNE	A,#0BH,READONC
			LJMP	KAI_SUO_CARD		;DUO_CENG_CARD

READONC:		CJNE	A,#0CH,READOND
			LJMP	KAI_SUO_CARD		;LOU_CENG_CARD

READOND:		CJNE	A,#0DH,READON0F
			LJMP	KAI_SUO_CARD		;FANG_JIAN_CARD

READON0F:               CJNE	A,#0FH,READON1D
			LJMP	KAI_SUO_CARD_JD         ;YI_CI_CARD

READON1D:		CJNE	A,#1DH,READON1E
			LJMP	KAI_SUO_CARD_JD		;酒店客人卡

READON1E:		CJNE	A,#1EH,READON2
			LJMP	KAI_SUO_CARD_JD		;酒店预订客人卡

READONF:		LJMP	ER_R_W_24C16

READON2:		LCALL	CHECK_MI_MA		;判断密码
			CJNE	A,#OK,READON_Z

			MOV	A,BUFF_BEG_MIF

			CJNE	A,#02H,READON3		;房号卡
			LJMP	FANG_HAO_CARD

READON3:		CJNE	A,#03H,READON4
			LJMP	SHI_JIAN_CARD		;时间卡

READON4:		CJNE	A,#04H,READON5
			LJMP	ZONG_QING_CARD		;总清卡

READON5:		CJNE	A,#05H,READON6
			LJMP	SHOU_QUAN_CARD		;授权卡

READON6:		CJNE	A,#06H,READON7
			LJMP	QING_CHU_CARD		;清除卡

READON7:		CJNE	A,#07H,READON8
			LJMP	GUA_SHI_CARD		;挂失卡

READON8:		CJNE	A,#08H,READON12
			LJMP	JI_LU_CARD		;记录卡

READON12:		CJNE	A,#12H,READON14
			LJMP	XUAN_ZE_CARD		;选择卡

READON14:		CJNE	A,#14H,READON15
			LJMP	JIN_ZHI_CARD		;禁止卡

READON15:		CJNE	A,#15H,READON16
			LJMP	JIE_JIN_CARD		;解禁卡

READON16:		CJNE	A,#16H,READON17
			LJMP	TIME_GROUP_CARD		;自动常开设置卡（新）

READON17:		CJNE	A,#17H,READONE
			LJMP	TIME_PATTEN_CARD        ;可用时段设置卡

READONE:		LCALL	LEDBUZZ_FORMAT_ERROR	;非本系统卡,即使恰好通过校验,也认为卡格式错
			LJMP	PWR_DOWN

READON_Z:		LCALL	LEDBUZZ_MI_MA_ERROR	;密码错误(声光信号)
			LJMP	PWR_DOWN

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

YUAN_SHI_CARD:		MOV	A,BUFF_BEG_MIF+1	;原始卡
			CJNE	A,#05H,YUAN_SHI_CARD1
			MOV	A,BUFF_BEG_MIF+2
			CJNE	A,#19H,YUAN_SHI_CARD1
			MOV	A,BUFF_BEG_MIF+3
			CJNE	A,#51H,YUAN_SHI_CARD1
			MOV	A,BUFF_BEG_MIF+4
			CJNE	A,#16H,YUAN_SHI_CARD1
			MOV	A,BUFF_BEG_MIF+5
			CJNE	A,#28H,YUAN_SHI_CARD1
			MOV	A,BUFF_BEG_MIF+6
			CJNE	A,#30H,YUAN_SHI_CARD1
                        MOV	A,BUFF_BEG_MIF+7
			CJNE	A,#51H,YUAN_SHI_CARD1
			MOV	A,BUFF_BEG_MIF+8
			CJNE	A,#95H,YUAN_SHI_CARD1
			MOV	A,BUFF_BEG_MIF+9
			CJNE	A,#11H,YUAN_SHI_CARD1
			MOV	A,BUFF_BEG_MIF+10
			CJNE	A,#66H,YUAN_SHI_CARD1
			MOV	A,BUFF_BEG_MIF+11
			CJNE	A,#27H,YUAN_SHI_CARD1
			LJMP	YUAN_SHI_CARD2

YUAN_SHI_CARD1:		LJMP	TEST_JTDL;PWR_DOWN			;原始卡数据有误,不做提示

YUAN_SHI_CARD2:
                        MOV	R7,#16
			MOV	R0,#BUFF_BEG_24C1X
			MOV	R1,#0
			MOV	DPTR,#YS_TAB1
YUAN_SHI_CARD3:		MOV 	A,R1
			MOVC	A,@A+DPTR
			MOV	@R0,A
			INC	R0
			INC	R1
			DJNZ	R7,YUAN_SHI_CARD3
			LJMP	YUAN_SHI_CARD4

YS_TAB1:		DB	05H,11H,44H,44H,0FFH,0FFH,0FFH,0FFH
			DB	00H,00H,00H,00H,00H,00H,00H,00H		;记录用计数器

YUAN_SHI_CARD_ERR1_JP:	LJMP	YUAN_SHI_CARD8

YUAN_SHI_CARD8_J1:	LJMP	YUAN_SHI_CARD8

YUAN_SHI_CARD4:		MOV	HADDR_24C1X,#00H
			MOV	LADDR_24C1X,#00H
                	MOV	LENGTH_24C1X,#16	;写入锁内24C16开头的16字节
			LCALL	WR_24C64
			CJNE	A,#OK,YUAN_SHI_CARD8_J1

			MOV	BUFF_BEG_MIF+9,#00H	;虚拟房号卡的总控卡标志

YUAN_SHI_CARD5:		MOV	HADDR_24C1X,#00H
			MOV	LADDR_24C1X,#29H
			MOV	LENGTH_24C1X,#1
			LCALL	RD_24C64
			CJNE	A,#OK,YUAN_SHI_CARD8_J1
			MOV	BUFF_BEG_MIF+15,BUFF_BEG_24C1X

                        JNB     FANGHAOCARD_FLAG,YUAN_SHI_CARD8_ADP1
                        MOV	HADDR_24C1X,#00H
			MOV	LADDR_24C1X,#2AH
			MOV	LENGTH_24C1X,#1
			LCALL	RD_24C64
			CJNE	A,#OK,YUAN_SHI_CARD_ERR1_JP
                        MOV     A,BUFF_BEG_24C1X
                        MOV     R0,#BUFF_BEG_MIF
                        MOV     @R0,A                           ;临时占用BUFF_BEG_MIF
YUAN_SHI_CARD8_ADP1:


                        MOV	HADDR_24C1X,#00H
			MOV	LADDR_24C1X,#5FH
			MOV	LENGTH_24C1X,#1
			LCALL	RD_24C64
			CJNE	A,#OK,YUAN_SHI_CARD8_J1
			MOV	BUFF_BEG_MIF+14,BUFF_BEG_24C1X

			MOV	R7,#16
			MOV	R0,#BUFF_BEG_24C1X
YUAN_SHI_CARD6:		MOV	@R0,#00H
			INC	R0
			DJNZ	R7,YUAN_SHI_CARD6

			MOV	HADDR_24C1X,#00H
			MOV	LADDR_24C1X,#10H

YUAN_SHI_CARD7:		MOV	A,LADDR_24C1X
			ANL	a,#00110000b
			JNZ	YUAN_SHI_CARD7_1
			;CPL	yLED			;&&黄灯闪烁
			CPL	RLED
			CPL	GLED

YUAN_SHI_CARD7_1:	MOV	LENGTH_24C1X,#16
			LCALL	WR_24C64
			CJNE	A,#ERROR,YUAN_SHI_CARD7_2
                        LJMP    YUAN_SHI_CARD8
YUAN_SHI_CARD7_2:
			MOV	A,HADDR_24C1X
			CJNE	A,#20H,YUAN_SHI_CARD7	;到了1FFFH
			;SETB	yLED
			SETB	RLED
			SETB	GLED

			MOV	BUFF_BEG_24C1X,BUFF_BEG_MIF+15
			MOV	HADDR_24C1X,#00H
			MOV	LADDR_24C1X,#29H
			MOV	LENGTH_24C1X,#1
			LCALL	WR_24C64
			CJNE	A,#OK,YUAN_SHI_CARD8

                        JNB     FANGHAOCARD_FLAG,YUAN_SHI_CARD8_ADP2
                        MOV     R0,#BUFF_BEG_MIF
                        MOV     A,@R0
                        MOV     BUFF_BEG_24C1X,A                ;将CLICK状态取回
                        MOV	HADDR_24C1X,#00H
			MOV	LADDR_24C1X,#2AH
			MOV	LENGTH_24C1X,#1
			LCALL	WR_24C64
			CJNE	A,#OK,YUAN_SHI_CARD8
YUAN_SHI_CARD8_ADP2:

			JNB	FANGHAOCARD_FLAG,YUAN_SHI_CARD7_END

			MOV	BUFF_BEG_24C1X+0,BUFF_BEG_MIF+9	        ;房号卡的总控卡标志
                        MOV	HADDR_24C1X,#00H
			MOV	LADDR_24C1X,#28H
			MOV	LENGTH_24C1X,#1
			LCALL	WR_24C64
			CJNE	A,#OK,YUAN_SHI_CARD8
                        MOV	BUFF_BEG_24C1X+0,BUFF_BEG_MIF+11	;房号卡的总控卡标志
                        MOV	BUFF_BEG_24C1X+1,BUFF_BEG_MIF+12	;房号卡的总控卡标志
                        MOV	BUFF_BEG_24C1X+2,BUFF_BEG_MIF+13	;房号卡的总控卡标志
			MOV	HADDR_24C1X,#00H
			MOV	LADDR_24C1X,#2BH
			MOV	LENGTH_24C1X,#3
			LCALL	WR_24C64
			CJNE	A,#OK,YUAN_SHI_CARD8

                        MOV	BUFF_BEG_24C1X,BUFF_BEG_MIF+14	;房号卡的总控卡标志
			MOV	HADDR_24C1X,#00H
			MOV	LADDR_24C1X,#5FH
			MOV	LENGTH_24C1X,#1
			LCALL	WR_24C64
			CJNE	A,#OK,YUAN_SHI_CARD8

                        MOV	BUFF_BEG_24C1X,BUFF_BEG_MIF+17	;房号卡的总控卡标志使能标志
                        MOV	HADDR_24C1X,#00H
			MOV	LADDR_24C1X,#12H
			MOV	LENGTH_24C1X,#1
			LCALL	WR_24C64
			CJNE	A,#OK,YUAN_SHI_CARD8

YUAN_SHI_CARD7_END:	LCALL	LEDBUZZ_SETUP		;原始卡输入成功

			LJMP	PWR_DOWN
YUAN_SHI_CARD8:		LJMP	ER_R_W_24C16

TEST_JTDL:		MOV	A,BUFF_BEG_MIF+1	;测试静态电流
			CJNE	A,#05H,TEST_JTDL1
			MOV	A,BUFF_BEG_MIF+2
			CJNE	A,#19H,TEST_JTDL1
			MOV	A,BUFF_BEG_MIF+3
			CJNE	A,#51H,TEST_JTDL1
			MOV	A,BUFF_BEG_MIF+4
			CJNE	A,#14H,TEST_JTDL1
			MOV	A,BUFF_BEG_MIF+5
			CJNE	A,#44H,TEST_JTDL1
			MOV	A,BUFF_BEG_MIF+6
			CJNE	A,#40H,TEST_JTDL1
			MOV	A,BUFF_BEG_MIF+7
			CJNE	A,#51H,TEST_JTDL1
			MOV	A,BUFF_BEG_MIF+8
			CJNE	A,#95H,TEST_JTDL1
			MOV	A,BUFF_BEG_MIF+9
			CJNE	A,#11H,TEST_JTDL1
			MOV	A,BUFF_BEG_MIF+10
			CJNE	A,#63H,TEST_JTDL1
			MOV	A,BUFF_BEG_MIF+11
			CJNE	A,#09H,TEST_JTDL1
			LCALL	CLKOUT_8563_CLEAR
			SETB	TEST_1702SL
TEST_JTDL1:		LJMP	PWR_DOWN

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

MI_MA_CARD:		JB	TONGUE_SW_BK,MI_MA_CARD0
			SETB	TONGUE_SW
			LCALL	DELAY5US
			JB	TONGUE_SW,MI_MA_CARD0  	;有可能是抖动
			CLR	TONGUE_SW
MI_MA_CARD_YSK1:	LCALL	CHECK_MI_MA
			CJNE	A,#OK,MI_MA_CARD_YSK2
			LJMP	MI_MA_CARD_YSK_OK
MI_MA_CARD_YSK2:	MOV	A,BUFF_BEG_24C1X+4	;非FFFFFFFF,判断卡的旧密码是否等于锁内密码
			CJNE	A,BUFF_BEG_MIF+5,MI_MA_CARD6
			MOV	A,BUFF_BEG_24C1X+5
			CJNE	A,BUFF_BEG_MIF+6,MI_MA_CARD6
			MOV	A,BUFF_BEG_24C1X+6
			CJNE	A,BUFF_BEG_MIF+7,MI_MA_CARD6
			MOV	A,BUFF_BEG_24C1X+7
			CJNE	A,BUFF_BEG_MIF+8,MI_MA_CARD6
MI_MA_CARD_YSK_OK:	LJMP	YUAN_SHI_CARD2		;密码卡+主舌常开 实现原始卡功能

MI_MA_CARD0:		MOV	A,BUFF_BEG_24C1X	;密码卡
			CJNE	A,#05H,MI_MA_CARD1	;判断锁内24C16公司标志区是否为05114444
			MOV	A,BUFF_BEG_24C1X+1	;如果是,说明被以往原始卡清过,可以输密码
			CJNE	A,#11H,MI_MA_CARD1
			MOV	A,BUFF_BEG_24C1X+2
			CJNE	A,#44H,MI_MA_CARD1
			MOV	A,BUFF_BEG_24C1X+3
			CJNE	A,#44H,MI_MA_CARD1
			LJMP	MI_MA_CARD2

MI_MA_CARD1:		LCALL	LEDBUZZ_DATA_ERROR      ;锁内24C16数据错误(未被原始卡清过)
			LJMP	PWR_DOWN
MI_MA_CARD6:		LCALL	LEDBUZZ_MI_MA_ERROR	;旧密码不对
			LJMP	PWR_DOWN

MI_MA_CARD2:		MOV	A,BUFF_BEG_24C1X+4
			CJNE	A,#0FFH,MI_MA_CARD3	;先判断锁内24C16密码区是否为FFFFFFFF
			MOV	A,BUFF_BEG_24C1X+5	;如果是,说明刚被原始卡清过
			CJNE	A,#0FFH,MI_MA_CARD3
			MOV	A,BUFF_BEG_24C1X+6
			CJNE	A,#0FFH,MI_MA_CARD3
			MOV	A,BUFF_BEG_24C1X+7
			CJNE	A,#0FFH,MI_MA_CARD3

			LJMP	MI_MA_CARD4		;直接去写密码

MI_MA_CARD3:		LCALL	CHECK_MI_MA
			CJNE	A,#ERROR,MI_MA_CARD_OK

			MOV	A,BUFF_BEG_24C1X+4	;非FFFFFFFF,判断卡的旧密码是否等于锁内密码
			CJNE	A,BUFF_BEG_MIF+5,MI_MA_CARD6
			MOV	A,BUFF_BEG_24C1X+5
			CJNE	A,BUFF_BEG_MIF+6,MI_MA_CARD6
			MOV	A,BUFF_BEG_24C1X+6
			CJNE	A,BUFF_BEG_MIF+7,MI_MA_CARD6
			MOV	A,BUFF_BEG_24C1X+7
			CJNE	A,BUFF_BEG_MIF+8,MI_MA_CARD6

MI_MA_CARD4:		MOV	BUFF_BEG_24C1X,BUFF_BEG_MIF+1
			MOV	BUFF_BEG_24C1X+1,BUFF_BEG_MIF+2
			MOV	BUFF_BEG_24C1X+2,BUFF_BEG_MIF+3
			MOV	BUFF_BEG_24C1X+3,BUFF_BEG_MIF+4

			MOV	HADDR_24C1X,#00H
			MOV	LADDR_24C1X,#04H
			MOV	LENGTH_24C1X,#4
			LCALL	WR_24C64
			CJNE	A,#OK,MI_MA_CARD7

MI_MA_CARD_OK:		;MOV	A,BUFF_BEG_MIF+9
			;LCALL	WRITE_ONE_TWO
			;CJNE	A,#OK,MI_MA_CARD7
			LCALL	LEDBUZZ_SETUP		;密码卡输入成功
			LJMP	PWR_DOWN

MI_MA_CARD7:		LJMP	ER_R_W_24C16


WRITE_ONE_TWO:		MOV	BUFF_BEG_24C1X,A
			MOV	HADDR_24C1X,#00H
			MOV	LADDR_24C1X,#2AH
			MOV	LENGTH_24C1X,#1
			LCALL	WR_24C64
			CJNE	A,#OK,WRITE_ONE_TWO_ERR
			SETB	ONE_OPEN_FLAG
			MOV	A,BUFF_BEG_24C1X
			JZ	WRITE_ONE_TWO_OK
			CLR	ONE_OPEN_FLAG
WRITE_ONE_TWO_OK:	MOV	A,#OK
WRITE_ONE_TWO_ERR:	RET


READ_ONE_TWO:		MOV	HADDR_24C1X,#00H
			MOV	LADDR_24C1X,#2AH
			MOV	LENGTH_24C1X,#1
			LCALL	RD_24C64			;读出常开标志来设置锁的状态
			CJNE	A,#OK,READ_ONE_TWO_ERR
			SETB	ONE_OPEN_FLAG
			MOV	A,BUFF_BEG_24C1X
			JZ	READ_ONE_TWO_END
			CLR	ONE_OPEN_FLAG
READ_ONE_TWO_END:	MOV	A,#OK
READ_ONE_TWO_ERR:	RET


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

SHE_ZHI_CARD:		MOV	A,BUFF_BEG_24C1X	;密码卡
			CJNE	A,#05H,SHE_ZHI_CARD1	;判断锁内24C16公司标志区是否为05114444
			MOV	A,BUFF_BEG_24C1X+1	;如果是,说明被以往原始卡清过,可以输密码
			CJNE	A,#11H,SHE_ZHI_CARD1
			MOV	A,BUFF_BEG_24C1X+2
			CJNE	A,#44H,SHE_ZHI_CARD1
			MOV	A,BUFF_BEG_24C1X+3
			CJNE	A,#44H,SHE_ZHI_CARD1
			LJMP	SHE_ZHI_CARD2

SHE_ZHI_CARD1:		LCALL	LEDBUZZ_DATA_ERROR      ;锁内24C16数据错误(未被原始卡清过)
			LJMP	PWR_DOWN

SHE_ZHI_CARD2:		MOV	A,BUFF_BEG_24C1X+4
			CJNE	A,#0FFH,SHE_ZHI_CARD3	;先判断锁内24C16密码区是否为FFFFFFFF
			MOV	A,BUFF_BEG_24C1X+5	;如果是,说明刚被原始卡清过
			CJNE	A,#0FFH,SHE_ZHI_CARD3
			MOV	A,BUFF_BEG_24C1X+6
			CJNE	A,#0FFH,SHE_ZHI_CARD3
			MOV	A,BUFF_BEG_24C1X+7
			CJNE	A,#0FFH,SHE_ZHI_CARD3

			LJMP	SHE_ZHI_CARD4		;直接去写密码

SHE_ZHI_CARD3:		LCALL	CHECK_MI_MA
			CJNE	A,#ERROR,SHE_ZHI_CARD5

			MOV	A,BUFF_BEG_24C1X+4	;非FFFFFFFF,判断卡的旧密码是否等于锁内密码
			CJNE	A,BUFF_BEG_MIF+5,SHE_ZHI_CARD_ERR1
			MOV	A,BUFF_BEG_24C1X+5
			CJNE	A,BUFF_BEG_MIF+6,SHE_ZHI_CARD_ERR1
			MOV	A,BUFF_BEG_24C1X+6
			CJNE	A,BUFF_BEG_MIF+7,SHE_ZHI_CARD_ERR1
			MOV	A,BUFF_BEG_24C1X+7
			CJNE	A,BUFF_BEG_MIF+8,SHE_ZHI_CARD_ERR1

SHE_ZHI_CARD4:		MOV	BUFF_BEG_24C1X,BUFF_BEG_MIF+1
			MOV	BUFF_BEG_24C1X+1,BUFF_BEG_MIF+2
			MOV	BUFF_BEG_24C1X+2,BUFF_BEG_MIF+3
			MOV	BUFF_BEG_24C1X+3,BUFF_BEG_MIF+4

			MOV	HADDR_24C1X,#00H
			MOV	LADDR_24C1X,#04H
			MOV	LENGTH_24C1X,#4

			LCALL	WR_24C64
			CJNE	A,#OK,SHE_ZHI_CARD_ERR2

SHE_ZHI_CARD5:   	MOV	BUFF_BEG_8563,BUFF_BEG_MIF+13
			MOV	BUFF_BEG_8563+1,BUFF_BEG_MIF+14
			MOV	BUFF_BEG_8563+2,BUFF_BEG_MIF+15
			MOV	BUFF_BEG_8563+3,BUFF_BEG_MIF+16
			MOV	BUFF_BEG_8563+4,BUFF_BEG_MIF+17
			MOV	BUFF_BEG_8563+5,BUFF_BEG_MIF+18
			MOV	BUFF_BEG_8563+6,BUFF_BEG_MIF+19
			LCALL	XIALING_CHECK_CARD
			CJNE	A,#ERROR,SHE_ZHI_CARD6
			LJMP	SHE_ZHI_CARD_ERR2

SHE_ZHI_CARD6:		MOV	BUFF_BEG_MIF+5,BUFF_BEG_MIF+9
			MOV	BUFF_BEG_MIF+6,BUFF_BEG_MIF+10
			MOV	BUFF_BEG_MIF+7,BUFF_BEG_MIF+11
			MOV	BUFF_BEG_MIF+8,BUFF_BEG_MIF+12
			MOV	BUFF_BEG_MIF+9,BUFF_BEG_MIF+20
			CLR	F0
			MOV	A,BUFF_BEG_MIF
			CJNE	A,#80H,SHE_ZHI_CARD_7
			SETB	F0
SHE_ZHI_CARD_7:		MOV	BUFF_BEG_MIF+10,BUFF_BEG_MIF+21              ;将CLICK设置修改到房号卡的对应位置
                        MOV     R0,#LSBUFF_BEG_MIF
                        MOV	BUFF_BEG_MIF+11,@R0
                        INC     R0
                        MOV	BUFF_BEG_MIF+12,@R0
                        INC     R0
                        MOV	BUFF_BEG_MIF+13,@R0;取得等级的后3字节
                        INC     R0
                        INC     R0
                        MOV	BUFF_BEG_MIF+17,@R0;取得等级使能标志
                        MOV	BUFF_BEG_MIF,#02H
			LJMP	FANG_HAO_CARD

SHE_ZHI_CARD_ERR1:	LCALL	LEDBUZZ_MI_MA_ERROR	;旧密码不对
			LJMP	PWR_DOWN

SHE_ZHI_CARD_ERR2:	LJMP	ER_R_W_24C16

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

FANG_HAO_CARD:          MOV	A,BUFF_BEG_MIF+10
			LCALL	WRITE_ONE_TWO
			CJNE	A,#OK,FANG_HAO_CARD3

                        LCALL	CHECK_LOU_CENG_FANG
			CJNE	A,#OK,FANG_HAO_CARD2	;判断卡的房间号是否等于锁内房间号

			MOV	A,BUFF_BEG_24C1X+11	;判断卡的通道标志是否等于锁内通道标志
			CJNE	A,BUFF_BEG_MIF+8,FANG_HAO_CARD2

			MOV	HADDR_24C1X,#00H
			MOV	LADDR_24C1X,#28H
			MOV	LENGTH_24C1X,#6
			LCALL	RD_24C64
			CJNE	A,#OK,FANG_HAO_CARD3
			MOV	A,BUFF_BEG_24C1X+0	;判断卡的通道标志是否等于锁内通道标志
			CJNE	A,BUFF_BEG_MIF+9,FANG_HAO_CARD2
                        MOV	A,BUFF_BEG_24C1X+3	;判断卡的通道标志是否等于锁内通道标志
			CJNE	A,BUFF_BEG_MIF+11,FANG_HAO_CARD2
                        MOV	A,BUFF_BEG_24C1X+4	;判断卡的通道标志是否等于锁内通道标志
			CJNE	A,BUFF_BEG_MIF+12,FANG_HAO_CARD2
                        MOV	A,BUFF_BEG_24C1X+5	;判断卡的通道标志是否等于锁内通道标志
			CJNE	A,BUFF_BEG_MIF+13,FANG_HAO_CARD2

			LCALL	LEDBUZZ_FANG_HAO_EQU	;房号卡的房间号和通道标志都和锁一样:
			LJMP	PWR_DOWN

FANG_HAO_CARD2:		MOV	BUFF_BEG_24C1X,BUFF_BEG_MIF+5
			MOV	BUFF_BEG_24C1X+1,BUFF_BEG_MIF+6
			MOV	BUFF_BEG_24C1X+2,BUFF_BEG_MIF+7
			MOV	BUFF_BEG_24C1X+3,BUFF_BEG_MIF+8

			MOV	HADDR_24C1X,#00H
			MOV	LADDR_24C1X,#08H
			MOV	LENGTH_24C1X,#4
			LCALL	WR_24C64
			CJNE	A,#OK,FANG_HAO_CARD3

			;LCALL	LEDBUZZ_SETUP   	;房号卡输入成功:
			;LJMP	PWR_DOWN
			SETB	FANGHAOCARD_FLAG
			JB	F0,FANG_HAO_CARD_END
			LCALL	CLEAR_CARD
FANG_HAO_CARD_END:	CLR	F0
			LJMP	YUAN_SHI_CARD5		;借用原始卡一段

FANG_HAO_CARD3:		LJMP	ER_R_W_24C16


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

SHI_JIAN_CARD:		MOV	BUFF_BEG_8563,BUFF_BEG_MIF+5
			MOV	BUFF_BEG_8563+1,BUFF_BEG_MIF+6
			MOV	BUFF_BEG_8563+2,BUFF_BEG_MIF+7
			MOV	BUFF_BEG_8563+3,BUFF_BEG_MIF+8
			MOV	BUFF_BEG_8563+4,BUFF_BEG_MIF+9
			MOV	BUFF_BEG_8563+5,BUFF_BEG_MIF+10
			MOV	BUFF_BEG_8563+6,BUFF_BEG_MIF+11

			LCALL	XIALING_CHECK_CARD
			CJNE	A,#OK,SHI_JIAN_CARD2
			LCALL	LEDBUZZ_SETUP   	;时间卡输入成功:
			LJMP	PWR_DOWN

SHI_JIAN_CARD2:		LJMP	ER_R_W_24C16		;如果时间卡输入错误,WR_8563中已有报警

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

ZONG_QING_CARD:		MOV	BUFF_BEG_24C1X,#00H
			MOV	BUFF_BEG_24C1X+1,#00H
			MOV	BUFF_BEG_24C1X+2,#00H
			MOV	BUFF_BEG_24C1X+3,#00H

                	MOV	HADDR_24C1X,#00H
			MOV	LADDR_24C1X,#0CH
                	MOV	LENGTH_24C1X,#4		;清常开标志,低压计数器,重置记录指针
			LCALL	WR_24C64
			CJNE	A,#OK,ZONG_QING_CARD5

			MOV	HADDR_24C1X,#00H
			MOV	LADDR_24C1X,#2BH
			MOV	LENGTH_24C1X,#4
			LCALL	RD_24C64
			CJNE	A,#OK,ZONG_QING_CARD5
			MOV	BUFF_BEG_MIF+9,BUFF_BEG_24C1X+0	;虚拟房号卡的总控卡标志
                        MOV	BUFF_BEG_MIF+11,BUFF_BEG_24C1X+1	;虚拟房号卡的总控卡标志
                        MOV	BUFF_BEG_MIF+12,BUFF_BEG_24C1X+2	;虚拟房号卡的总控卡标志
                        MOV	BUFF_BEG_MIF+13,BUFF_BEG_24C1X+3	;虚拟房号卡的总控卡标志
			SETB	FANGHAOCARD_FLAG
			LJMP	YUAN_SHI_CARD5		;借用原始卡一段

ZONG_QING_CARD5:	LJMP	ER_R_W_24C16
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

XUAN_ZE_CARD:		MOV	BUFF_BEG_24C1X,BUFF_BEG_MIF+8

                	MOV	HADDR_24C1X,#00H
			MOV	LADDR_24C1X,#5FH
                	MOV	LENGTH_24C1X,#1		;选择酒店或办公
			LCALL	WR_24C64
			CJNE	A,#OK,XUAN_ZE_CARD_ERR1
			LCALL	LEDBUZZ_SETUP
			CLR	JIU_DIAN_FLAG
			MOV	A,BUFF_BEG_MIF+8
			CJNE	A,#01H,XUAN_ZE_CARD_END
			SETB	JIU_DIAN_FLAG
XUAN_ZE_CARD_END:	LJMP	PWR_DOWN

XUAN_ZE_CARD_ERR1:	LJMP	ER_R_W_24C16

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

JIN_ZHI_CARD:		MOV	BUFF_BEG_24C1X,#01H

                	MOV	HADDR_24C1X,#00H
			MOV	LADDR_24C1X,#5EH
                	MOV	LENGTH_24C1X,#1		;设置客人卡禁止标志
			LCALL	WR_24C64
			CJNE	A,#OK,JIN_ZHI_CARD_ERR1
			LCALL	LEDBUZZ_SETUP
			LJMP	PWR_DOWN

JIN_ZHI_CARD_ERR1:	LJMP	ER_R_W_24C16

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

JIE_JIN_CARD:		MOV	BUFF_BEG_24C1X,#00H

                	MOV	HADDR_24C1X,#00H
			MOV	LADDR_24C1X,#5EH
                	MOV	LENGTH_24C1X,#1		;清除客人卡禁止标志
			LCALL	WR_24C64
			CJNE	A,#OK,JIE_JIN_CARD_ERR1
			LCALL	LEDBUZZ_SETUP
			LJMP	PWR_DOWN

JIE_JIN_CARD_ERR1:	LJMP	ER_R_W_24C16

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

SHOU_QUAN_CARD:		LCALL	DUEI_HAO_LCF
			CJNE	A,#OK,SHOU_QUAN_CARD8   	;判断房间号

			;MOV 	A,BUFF_BEG_MIF+8
			;CJNE	A,#01H,SHOU_QUAN_CARD15 	;是授权已清除的对号卡吗

			LCALL	COMP_SN				;

			CJNE	A,#COMP_STATE0,SHOU_QUAN_CARD1	;读24C16出错
			LJMP	SHOU_QUAN_CARD9

SHOU_QUAN_CARD1:	CJNE	A,#COMP_STATE1,SHOU_QUAN_CARD2	;主序号没有和自己相同的
			MOV	A,#FIND_BLANK
			LJMP	SHOU_QUAN_CARD11		;从序号区找一个4字节为00的空白区,把自己的序号填入

SHOU_QUAN_CARD2:	CJNE	A,#COMP_STATE2,SHOU_QUAN_CARD3	;主序号和自己相同,且副序号也相同
			LJMP	SHOU_QUAN_CARD10

SHOU_QUAN_CARD3:	CJNE	A,#COMP_STATE3,SHOU_QUAN_CARD4	;主序号和自己相同,副序号大于自己
			LJMP	SHOU_QUAN_CARD10

SHOU_QUAN_CARD4:	CJNE	A,#COMP_STATE4,SHOU_QUAN_CARD5	;主序号和自己相同,副序号小于自己但不为0
			LJMP	SHOU_QUAN_CARD10

SHOU_QUAN_CARD5:	CJNE	A,#COMP_STATE5,SHOU_QUAN_CARD6	;主序号和自己相同,副序号为0
			MOV	A,#FIND_ITSELF
			LJMP	SHOU_QUAN_CARD11

SHOU_QUAN_CARD6:	LCALL	LEDBUZZ_PRG_ERROR		;程序运行错误(正常状态下不可能出现)
			LJMP	PWR_DOWN

SHOU_QUAN_CARD8:	LCALL	LEDBUZZ_FANG_HAO_ERROR		;房间号错误
			LJMP	PWR_DOWN

SHOU_QUAN_CARD9:	LJMP	ER_R_W_24C16			;读24C16出错


SHOU_QUAN_CARD10:	LCALL	LEDBUZZ_NOT_SHOU_QUAN		;不必或已经授权
			LJMP	PWR_DOWN

SHOU_QUAN_CARD11:	LCALL	FIND_WR 			;从序号区找一个4字节为00的空白区,把自己的序号填入

			CJNE	A,#FIND_STATE0,SHOU_QUAN_CARD12	;读/写24C16出错
			LJMP	SHOU_QUAN_CARD9

SHOU_QUAN_CARD12:	CJNE	A,#FIND_STATE1,SHOU_QUAN_CARD13	;没找到空位置
			LCALL	LEDBUZZ_NO_BLANK
			LJMP	PWR_DOWN

SHOU_QUAN_CARD13:	CJNE	A,#FIND_STATE2,SHOU_QUAN_CARD14	;找到空位置,且顺利把自己的序号填入
			LCALL	LEDBUZZ_SETUP
			LJMP	PWR_DOWN

SHOU_QUAN_CARD14:	LJMP	SHOU_QUAN_CARD6			;程序运行错误(正常状态下不可能出现)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

QING_CHU_CARD:		LCALL	DUEI_HAO_LCF
			CJNE	A,#OK,QING_CHU_CARD8   		;判断房间号

			;MOV 	A,BUFF_BEG_MIF+8
			;CJNE	A,#01H,QING_CHU_CARD16  	;是清除对号卡吗

			LCALL	COMP_SN				;

			CJNE	A,#COMP_STATE0,QING_CHU_CARD1	;读24C16出错
			LJMP	QING_CHU_CARD9

QING_CHU_CARD1:		CJNE	A,#COMP_STATE1,QING_CHU_CARD2	;主序号没有和自己相同的
			MOV	A,#FIND_BLANK
			LJMP	QING_CHU_CARD10

QING_CHU_CARD2:		CJNE	A,#COMP_STATE2,QING_CHU_CARD3	;主序号和自己相同,且副序号也相同
			LJMP	QING_CHU_CARD14

QING_CHU_CARD3:		CJNE	A,#COMP_STATE3,QING_CHU_CARD4	;主序号和自己相同,副序号大于自己
			LJMP	QING_CHU_CARD14

QING_CHU_CARD4:		CJNE	A,#COMP_STATE4,QING_CHU_CARD5	;主序号和自己相同,副序号小于自己但不为0
			LJMP	QING_CHU_CARD14

QING_CHU_CARD5:		CJNE	A,#COMP_STATE5,QING_CHU_CARD6	;主序号和自己相同,副序号为0
			LJMP	QING_CHU_CARD15

QING_CHU_CARD6:		LCALL	LEDBUZZ_PRG_ERROR		;程序运行错误(正常状态下不可能出现)
			LJMP	PWR_DOWN

QING_CHU_CARD8:		LCALL	LEDBUZZ_FANG_HAO_ERROR		;房间号错误
			LJMP	PWR_DOWN

QING_CHU_CARD9:		LJMP	ER_R_W_24C16			;读24C16出错

QING_CHU_CARD10:	MOV	BUFF_BEG_MIF+21,#00H		;将卡带来的副序号改成00
			LCALL	FIND_WR 			;把00填入

			CJNE	A,#FIND_STATE0,QING_CHU_CARD11	;读/写24C16出错
			LJMP	QING_CHU_CARD9

QING_CHU_CARD11:	CJNE	A,#FIND_STATE1,QING_CHU_CARD12	;没找到空位置
			LCALL	LEDBUZZ_NO_BLANK
			LJMP	PWR_DOWN

QING_CHU_CARD12:	CJNE	A,#FIND_STATE2,QING_CHU_CARD13	;找到空位置,且顺利把序号填入
			LCALL	LEDBUZZ_SETUP
			LJMP	PWR_DOWN

QING_CHU_CARD13:	LJMP	QING_CHU_CARD6			;程序运行错误(正常状态下不可能出现)


QING_CHU_CARD14:	MOV	A,#FIND_ITSELF
			LJMP	QING_CHU_CARD10

QING_CHU_CARD15:	LCALL	LEDBUZZ_NOT_QING_CHU		;不必或已经清除
			LJMP	PWR_DOWN

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

GUA_SHI_CARD:		MOV	A,BUFF_BEG_MIF+8		;判断是否对号
GUA_SHI_09H:		CJNE	A,#09H,GUA_SHI_0AH
			LJMP	GUA_SHI_DUEI_HAO		;挂失紧急卡

GUA_SHI_0AH:		CJNE	A,#0AH,GUA_SHI_0BH
			LJMP	GUA_SHI_DUEI_HAO		;挂失总控卡

GUA_SHI_0BH:		CJNE	A,#0BH,GUA_SHI_0CH
			LCALL	DUEI_HAO_LC			;挂失多层卡
			CJNE	A,#ERROR,GUA_SHI_DUEI_HAO
			LJMP	GUA_SHI_BU_DUEI_HAO

GUA_SHI_0CH:		CJNE	A,#0CH,GUA_SHI_0DH
			MOV	BUFF_BEG_MIF+7,BUFF_BEG_MIF+6
			LCALL	CHECK_LOU_CENG			;挂失楼层卡
			CJNE	A,#ERROR,GUA_SHI_DUEI_HAO
			LJMP	GUA_SHI_BU_DUEI_HAO

GUA_SHI_0DH:		CJNE	A,#0DH,GUA_SHI_CARD8
			LCALL	DUEI_HAO_LCF			;挂失房间卡
			CJNE	A,#ERROR,GUA_SHI_DUEI_HAO
			LJMP	GUA_SHI_BU_DUEI_HAO

GUA_SHI_DUEI_HAO:	LCALL	COMP_SN				;挂失对号卡!!!!!!

			CJNE	A,#COMP_STATE0,GUA_SHI_CARD1	;读24C16出错
			LJMP	GUA_SHI_CARD9

GUA_SHI_CARD1:		CJNE	A,#COMP_STATE1,GUA_SHI_CARD2	;主序号没有和自己相同的
			MOV	A,#FIND_BLANK			;找空位置写入
			LJMP	GUA_SHI_CARD10

GUA_SHI_CARD2:		CJNE	A,#COMP_STATE2,GUA_SHI_CARD3	;主序号和自己相同,且副序号也相同
			LJMP	GUA_SHI_CARD15			;已经挂失

GUA_SHI_CARD3:		CJNE	A,#COMP_STATE3,GUA_SHI_CARD4	;主序号和自己相同,副序号大于自己
			LJMP	GUA_SHI_CARD15			;不必挂失

GUA_SHI_CARD4:		CJNE	A,#COMP_STATE4,GUA_SHI_CARD5	;主序号和自己相同,副序号小于自己但不为0
			LJMP	GUA_SHI_CARD14			;改副序号

GUA_SHI_CARD5:		CJNE	A,#COMP_STATE5,GUA_SHI_CARD6	;主序号和自己相同,副序号为0
			LJMP	GUA_SHI_CARD15			;属于被清除的对号卡,不能挂失

GUA_SHI_CARD6:		LCALL	LEDBUZZ_PRG_ERROR		;程序运行错误(正常状态下不可能出现)
			LJMP	PWR_DOWN

GUA_SHI_CARD8:		LCALL	LEDBUZZ_FANG_HAO_ERROR		;房间号错误
			LJMP	PWR_DOWN

GUA_SHI_CARD9:		LJMP	ER_R_W_24C16			;读24C16出错

GUA_SHI_CARD10:		LCALL	FIND_WR 			;把自己的序号填入

			CJNE	A,#FIND_STATE0,GUA_SHI_CARD11	;读/写24C16出错
			LJMP	GUA_SHI_CARD9

GUA_SHI_CARD11:		CJNE	A,#FIND_STATE1,GUA_SHI_CARD12	;没找到空位置
			LCALL	LEDBUZZ_NO_BLANK
			LJMP	PWR_DOWN

GUA_SHI_CARD12:		CJNE	A,#FIND_STATE2,GUA_SHI_CARD13	;找到空位置,且顺利把序号填入
			LCALL	LEDBUZZ_SETUP
			LJMP	PWR_DOWN

GUA_SHI_CARD13:		LJMP	GUA_SHI_CARD6			;程序运行错误(正常状态下不可能出现)


GUA_SHI_CARD14:		MOV	A,#FIND_ITSELF
			LJMP	GUA_SHI_CARD10

GUA_SHI_CARD15:		LCALL	LEDBUZZ_NOT_GUA_SHI		;不必或已经挂失
			LJMP	PWR_DOWN

;;;;;;;;;;;;;;;

GUA_SHI_BU_DUEI_HAO:	LCALL	COMP_SN				;挂失非对号卡!!!!!!

			CJNE	A,#COMP_STATE0,GUA_SHI_CARD17	;读24C16出错
			LJMP	GUA_SHI_CARD9

GUA_SHI_CARD17:		CJNE	A,#COMP_STATE1,GUA_SHI_CARD18	;主序号没有和自己相同的
			LJMP	GUA_SHI_CARD15			;不必挂失

GUA_SHI_CARD18:		CJNE	A,#COMP_STATE2,GUA_SHI_CARD19	;主序号和自己相同,且副序号也相同
			LJMP	GUA_SHI_CARD15			;已经挂失

GUA_SHI_CARD19:		CJNE	A,#COMP_STATE3,GUA_SHI_CARD20	;主序号和自己相同,副序号大于自己
			LJMP	GUA_SHI_CARD15			;不必挂失

GUA_SHI_CARD20:		CJNE	A,#COMP_STATE4,GUA_SHI_CARD21	;主序号和自己相同,副序号小于自己但不为0
			LJMP	GUA_SHI_CARD14			;改副序号

GUA_SHI_CARD21:		CJNE	A,#COMP_STATE5,GUA_SHI_CARD22	;主序号和自己相同,副序号为0
			LJMP	GUA_SHI_CARD15			;其实正常状态下这种情况不可能出现

GUA_SHI_CARD22:		LJMP	GUA_SHI_CARD6			;程序运行错误(正常状态下不可能出现)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;要注意COUNT0变量
JILUCARD_2_JP:		LJMP	JILUCARD_2

JI_LU_CARD:		MOV	T0INTCOUNT,#200

			MOV	A,BUFF_BEG_MIF+5

JILUCARD_1:		CJNE    A,#01H,JILUCARD_2_JP		;记录卡1
			LCALL	RD_8563				;读时钟
			MOV	BUFF_BEG_24C1X,BUFF_BEG_8563
			MOV	BUFF_BEG_24C1X+1,BUFF_BEG_8563+1
			MOV	BUFF_BEG_24C1X+2,BUFF_BEG_8563+2
			MOV	BUFF_BEG_24C1X+3,BUFF_BEG_8563+3
			MOV	BUFF_BEG_24C1X+4,BUFF_BEG_8563+4
			MOV	HADDR_24C1X,#00H
			MOV	LADDR_24C1X,#20H
			MOV	LENGTH_24C1X,#5
			LCALL	WR_24C64			;把时钟写入24C64的020-024,共5字节
			CJNE	A,#OK,JILUCARD_1_1_0

			MOV	C,CHANG_KAI_FLAG
			MOV	A,#00H
			RLC	A
			MOV	BUFF_BEG_24C1X,A
			MOV	HADDR_24C1X,#00H
			MOV	LADDR_24C1X,#0CH
			MOV	LENGTH_24C1X,#1
			LCALL	WR_24C64			;把常开状态写入24C64的000CH
			CJNE	A,#OK,JILUCARD_1_1_0

			NOP					;写记录卡1, 分二大部分
			MOV	HADDR_24C1X,#00H		;第1部分:常规字节(即24C64的00-5F)
			MOV	LADDR_24C1X,#00H

			MOV     U_SECNR,#1			;:从1扇区开始
                        MOV     U_BLKNR,#4			;绝对块号为4(即1扇区的第0块)
                        MOV	SEC_COUNT,#2			;先写二个扇区
                        MOV     BLK_COUNT,#3			;每扇区用3块
			MOV	TBLK_COUNT,#6			;一共6块(在整扇区一写时,此变量其实多余)
			SETB	CHRP_FLAG			;置标志:写记录卡1时要将记录计数器"假写"为0000
			LCALL	WRITE_JI_LU_CARD1		;先写6块,注意是调用WRITE_JI_LU_CARD1!!!

JILUCARD_1_1:		CJNE	A,#WRJL_STATE0,JILUCARD_1_1_1
JILUCARD_1_1_0:		LJMP	ER_R_W_24C16			;读锁内24C64失败
JILUCARD_1_1_1:		CJNE	A,#WRJL_STATE2,JILUCARD_1_1_2	;写记录成功(第1部分)
			LJMP	JILUCARD_1_2			;继续
JILUCARD_1_1_2:		LCALL	LEDBUZZ_JI_LU_N2		;写记录卡失败
			CLR	TOTAL_PWR
			LCALL	DELAY05S
			LCALL	DELAY05S
			LCALL	DELAY05S
			LJMP	PWR_DOWN

JILUCARD_1_2:		MOV	DPTR,#0				;第2部分:DPTR放本卡累加值
			MOV     U_SECNR,#3			;从3扇区开始
                        MOV     U_BLKNR,#12			;绝对块号为12(即1扇区的第0块)
                        MOV	SEC_COUNT,#13			;写13扇区
                        MOV     BLK_COUNT,#3			;每扇区用3块
			MOV	TBLK_COUNT,#39			;一共39块(在整扇区一写时,此变量其实多余)
			LCALL	JILUCARD_SUB1
			LJMP	JI_LU_CARD_08

JILUCARD_2:		CJNE    A,#02H,JILUCARD_3		;记录卡2
			MOV	DPTR,#78
			MOV     U_SECNR,#1
                        MOV     U_BLKNR,#4
                        MOV	SEC_COUNT,#15
                        MOV     BLK_COUNT,#3
			MOV	TBLK_COUNT,#45
			LCALL	JILUCARD_SUB1
			LJMP	JI_LU_CARD_08

JILUCARD_3:		CJNE    A,#03H,JILUCARD_4		;记录卡3
			MOV	DPTR,#78+90
			MOV     U_SECNR,#1
                        MOV     U_BLKNR,#4
                        MOV	SEC_COUNT,#15
                        MOV     BLK_COUNT,#3
			MOV	TBLK_COUNT,#45
			LCALL	JILUCARD_SUB1
			LJMP	JI_LU_CARD_08

JILUCARD_4:		CJNE    A,#04H,JILUCARD_5		;记录卡4
			MOV	DPTR,#78+90+90
			MOV     U_SECNR,#1
                        MOV     U_BLKNR,#4
                        MOV	SEC_COUNT,#15
                        MOV     BLK_COUNT,#3
			MOV	TBLK_COUNT,#45
			LCALL	JILUCARD_SUB1
			LJMP	JI_LU_CARD_08

JILUCARD_5:		CJNE    A,#05H,JILUCARD_6		;记录卡5
			MOV	DPTR,#78+90+90+90
			MOV     U_SECNR,#1
                        MOV     U_BLKNR,#4
                        MOV	SEC_COUNT,#15
                        MOV     BLK_COUNT,#3
			MOV	TBLK_COUNT,#45
			LCALL	JILUCARD_SUB1
			LJMP	JI_LU_CARD_08

JILUCARD_6:		CJNE    A,#06H,JILUCARD_7		;记录卡6, 分二大部分
			MOV	DPTR,#78+90+90+90+90		;第1部分
			MOV     U_SECNR,#1
                        MOV     U_BLKNR,#4
                        MOV	SEC_COUNT,#12			;12!
                        MOV     BLK_COUNT,#3
			MOV	TBLK_COUNT,#31			;31
			LCALL	JILUCARD_SUB1

JILUCARD_6_1:		CJNE	A,#WRJL_STATE0,JILUCARD_6_1_1
			LJMP	ER_R_W_24C16			;读锁内24C64失败
JILUCARD_6_1_1:		CJNE	A,#WRJL_STATE2,JILUCARD_6_1_2	;写记录成功(第1部分)
			LJMP	JILUCARD_6_2			;继续
JILUCARD_6_1_2:		LCALL	LEDBUZZ_JI_LU_N2		;写记录卡失败
			CLR	TOTAL_PWR
			LCALL	DELAY05S
			LCALL	DELAY05S
			LCALL	DELAY05S
			LJMP	PWR_DOWN

JILUCARD_6_2:		MOV	HADDR_24C1X,#10H		;第2部分:常规字节(即24C64的1000-XXXX)
			MOV	LADDR_24C1X,#00H

			MOV     U_SECNR,#11			;从11扇区开始
                        MOV     U_BLKNR,#45			;绝对块号为32(即11扇区的第1块)
                        MOV	SEC_COUNT,#5			;写5个扇区
                        MOV     BLK_COUNT,#2			;首扇区用2块
			MOV	TBLK_COUNT,#14			;一共14块(此时非在一整扇区,此变量有用)
			LCALL	WRITE_JI_LU_CARD1		;注意是调用WRITE_JI_LU_CARD1

			LJMP	JI_LU_CARD_08

JILUCARD_7:		JZ	JI_LU_CARD_08_2			;记录卡7-12,记录卡副标不可为0,不可>=13
			CJNE	A,#13,JI_LU_CARD7_1		;
JI_LU_CARD7_1:		JNC	JI_LU_CARD_08_2

			CLR	C
			SUBB	A,#7				;-7
			RL	A  				;(副卡标)*2
			MOV	R7,A				;暂存
			MOV	DPTR,#ADDR_TAB
			MOVC	A,@A+DPTR
			MOV	HADDR_24C1X,A
			MOV	A,R7
			INC	A
			MOVC	A,@A+DPTR
			MOV	LADDR_24C1X,A
			LJMP	JI_LU_CARD7_2

ADDR_TAB:		DW 	720*6
			DW 	720*7
			DW 	720*8
			DW 	720*9
			DW 	720*10
			DW 	720*11

JI_LU_CARD7_2:		LCALL   WRITE_JI_LU_CARD
			LJMP	JI_LU_CARD_08

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

JI_LU_CARD_08:		CJNE	A,#WRJL_STATE0,JI_LU_CARD_08_1
			LJMP	ER_R_W_24C16			;读锁内24C64失败
JI_LU_CARD_08_1:	CJNE	A,#WRJL_STATE2,JI_LU_CARD_08_2
			LCALL	LEDBUZZ_SETUP			;写记录成功
JI_LU_CARD_08_1_1:	CLR	TOTAL_PWR
			LCALL	DELAY05S
			LCALL	DELAY05S
			LCALL	DELAY05S
			LJMP	PWR_DOWN

JI_LU_CARD_08_2:	LCALL	LEDBUZZ_JI_LU_N2		;写记录卡失败
			CLR	TOTAL_PWR
			LCALL	DELAY05S
			LCALL	DELAY05S
			LCALL	DELAY05S
			LJMP	PWR_DOWN

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;此程序仅用于计算开锁记录的那部分字节,排序后并写入记录卡
;入口:
;DPTR:本记录卡累加值
;U_SECNR:开始扇区(不包括常规字节)
;U_ADR:开始绝对块号
;SEC_COUNT:扇区数
;BLK_COUNT:开始扇区要写的块数
;TBLK_COUNT:总共要写的块数(在整扇区一写时,此变量其实多余)
;出口:A
;WRJL_STATE0 24C64错误
;WRJL_STATE1 写卡失败
;WRJL_STATE2 写卡成功
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

JILUCARD_SUB1:		NOP

			MOV	HADDR_24C1X,#00H
			MOV	LADDR_24C1X,#0EH
			MOV	LENGTH_24C1X,#2
			LCALL	RD_24C64				;读记录计数器
			CJNE	A,#OK,JILUCARD_SUB1_RET1_JP

			MOV	BUFF_BEG_24C1X+2,BUFF_BEG_24C1X
			MOV	BUFF_BEG_24C1X+3,BUFF_BEG_24C1X+1	;暂存

			CLR	C
			MOV	A,BUFF_BEG_24C1X+1
			SUBB	A,DPL
			MOV	BUFF_BEG_24C1X+1,A
			MOV	A,BUFF_BEG_24C1X
			SUBB	A,DPH
			MOV	BUFF_BEG_24C1X,A			;记录计数器-本卡累加值

			JNC	JILUCARD_SUB1_0				;记录计数器>=本卡累加值,跳JILUCARD_SUB1_0

			MOV	A,BUFF_BEG_24C1X+3			;记录计数器<本卡累加值
			ADD	A,#0DCH
			MOV	BUFF_BEG_24C1X+1,A
			MOV	A,BUFF_BEG_24C1X+2
			ADDC	A,#01H
			MOV	BUFF_BEG_24C1X,A			;+476(01DCH);+500(01F4H)

			CLR	C
			MOV	A,BUFF_BEG_24C1X+1
			SUBB	A,DPL
			MOV	BUFF_BEG_24C1X+1,A
			MOV	A,BUFF_BEG_24C1X
			SUBB	A,DPH
			MOV	BUFF_BEG_24C1X,A			;再-本卡累加值

			LJMP	JILUCARD_SUB1_0

JILUCARD_SUB1_RET1_JP:	LJMP	JILUCARD_SUB1_RET1

JILUCARD_SUB1_0:	MOV	R1,BUFF_BEG_24C1X
			MOV	R2,BUFF_BEG_24C1X+1
			MOV	R3,#8					;x8
			LCALL	HEX2MUL1				;无符号2字节乘1字节:(R1R2)*(R3)=(R1R2R3)

			MOV	A,R3
			ADD	A,#20H
			MOV	LADDR_24C1X,A
			MOV	BK_LADDR_24C1X,A
			MOV	A,R2
			ADDC	A,#01H
			MOV	HADDR_24C1X,A				;计数器x8+记录首地址(0060H):作为取记录的地址
			MOV	BK_HADDR_24C1X,A

JILUCARD_SUB1_1:	MOV	COUNT0,#2				;2*8=16
			MOV	R6,#Wr_Buffer

JILUCARD_SUB1_2:	CLR	C
			MOV	A,BK_LADDR_24C1X
			SUBB	A,#8
			MOV	BK_LADDR_24C1X,A
			MOV	A,BK_HADDR_24C1X
			SUBB	A,#0
			MOV	BK_HADDR_24C1X,A

			CJNE	A,#01H,JILUCARD_SUB1_2_1
			MOV	A,BK_LADDR_24C1X
			CJNE	A,#20H,JILUCARD_SUB1_2_1
JILUCARD_SUB1_2_1:	JNC	JILUCARD_SUB1_2_2
			MOV	BK_HADDR_24C1X,#0FH
			MOV	BK_LADDR_24C1X,#0F8H

JILUCARD_SUB1_2_2:	MOV	HADDR_24C1X,BK_HADDR_24C1X
			MOV	LADDR_24C1X,BK_LADDR_24C1X
			MOV	LENGTH_24C1X,#8
			LCALL	RD_24C64
			CJNE	A,#OK,JILUCARD_SUB1_RET1

			MOV	R0,#BUFF_BEG_24C1X
			MOV	A,R6
			MOV	R1,A
			MOV	R7,#8
JILUCARD_SUB1_2_3:	MOV	A,@R0
			MOV	@R1,A
			INC	R0
			INC	R1
			DJNZ	R7,JILUCARD_SUB1_2_3

			MOV	A,R1
			MOV	R6,A

			DJNZ	COUNT0,JILUCARD_SUB1_2		;2条记录整理为1行

JILUCARD_SUB1_3:	;CPL	YLED				;闪黄灯
                        CPL	GLED
                        CPL	RLED
                        MOV	COUNT0,#10
JILUCARD_SUB1_3_1:      MOV	COUNT1,#10
			LCALL   WRITE16BYTE
                        CJNE	A,#OK,JILUCARD_SUB1_3_2
                        LJMP	JILUCARD_SUB1_3_3
JILUCARD_SUB1_3_2:	DJNZ	COUNT0,JILUCARD_SUB1_3_1
                  	;SETB    YLED
			SETB	GLED
			SETB	RLED
			MOV	A,#WRJL_STATE1			;写卡失败
                  	RET

JILUCARD_SUB1_3_3:      INC     U_BLKNR
                        DJNZ	TBLK_COUNT,JILUCARD_SUB1_3_4	;查总块数(在整扇区一写时,此变量其实多余)
                    	LJMP	JILUCARD_SUB1_3_5

JILUCARD_SUB1_3_4:    	DJNZ    BLK_COUNT,JILUCARD_SUB1_1
                        MOV     BLK_COUNT,#3
                        INC     U_BLKNR
                        INC     U_SECNR
                        DJNZ    SEC_COUNT,JILUCARD_SUB1_1

JILUCARD_SUB1_3_5:    	;SETB    YLED
			SETB	GLED
			SETB	RLED
			MOV     A,#WRJL_STATE2			;写卡成功
                        RET

JILUCARD_SUB1_RET1:	;SETB    YLED
			SETB	GLED
			SETB	RLED
			MOV     A,#WRJL_STATE0			;24C64错误
                        RET

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
KAI_SUO_CARD7_JP1:	LJMP	KAI_SUO_CARD7

KAI_SUO_CARD:           MOV	T0INTCOUNT,#250
			MOV	WDTCONTER,#00110111B

                        LCALL   COPY_BUFF_2_EXTRAM

                        LCALL   SELECT_EXTRAM
                        LCALL   SPREAD_BLIST
                        LCALL   SELECT_MIFRAM
                        CJNE    A,#OK,KAI_SUO_CARD7_JP1

                        LCALL   RD_8563
			CJNE	A,#OK,KAI_SUO_CARD_JPOUT		;如果时钟错误,也算时间有效

                        MOV	HADDR_24C1X,#00H
                        MOV	LADDR_24C1X,#060H
KAI_SUO_CARD_LOOP:
                        LCALL   GET_DATA_AUTO
                        CJNE	A,#OK,KAI_SUO_CARD7_JP1

                        LCALL   CHECK_TIME_CORRECT
                        CJNE    A,#00H,KAI_SUO_CARD_ADP0
                        LJMP    KAI_SUO_CARD_JPOUT
KAI_SUO_CARD_ADP0:
                        CJNE    A,#01H,KAI_SUO_CARD_ADP1
                        LCALL	LEDBUZZ_JIN_ZHI			;卡被禁止
			LJMP	PWR_DOWN
KAI_SUO_CARD_ADP1:
                        LCALL   TEST_DEVICE_ENABLE
                        CJNE	A,#OK,KAI_SUO_CARD_NEXT

                        LCALL   CHECK_ST_TIME
                        CJNE    A,#OK,KAI_SUO_CARD_NEXT

			LCALL	CHECK_TIME_ADP			;判断时间
			CJNE	A,#CHECK_TIME_STATE3,KAI_SUO_CARD_NEXT
                        LJMP    KAI_SUO_CARD_JPOUT
KAI_SUO_CARD_NEXT:
                        MOV     A,LADDR_24C1X
                        XRL     A,#00H
                        JNZ     KAI_SUO_CARD_LOOP
                        LCALL	LEDBUZZ_JIN_ZHI			;卡被禁止
			LJMP	PWR_DOWN
KAI_SUO_CARD_JPOUT:
                        LCALL   COPY_EXTRAM_2_BUFF
                        MOV	HADDR_24C1X,#00H
			MOV	LADDR_24C1X,#00H
			MOV	LENGTH_24C1X,#16
			CALL	RD_24C64		;读出公司标志等(16BYTE!),以备用
			CJNE	A,#OK,KAI_SUO_CARD7_JP1

	                SETB	CARD_FLAG			;置"卡操作标志",

			LCALL	CHECK_MI_MA			;开锁卡
			CJNE	A,#OK,KAI_SUO_JP1		;判断密码

			LCALL	CHECK_TIME			;判断时间
			CJNE	A,#CHECK_TIME_STATE3,KAI_SUO_JP2

			jb	reset_flag,LOW_VOL_OK		;上电复位后第一次开锁不判断低压计数器（可能是外接电源）

			MOV	A,BUFF_BEG_MIF
			CJNE	A,#0DH,LOW_VOL_TEST_2
LOW_VOL_TEST_1:		MOV	A,BUFF_BEG_24C1X+0DH		;判断KEYCARD低电压
			CJNE	A,#LOW_VOL_LIMIT,LOW_VOL_TEST_1_1;KEYCARD为30次
LOW_VOL_TEST_1_1:	JC	LOW_VOL_OK
LOW_VOL_TEST_OFF:	MOV     A,#CARD				;记录低电压关闭
                	MOV	B,#LOW_VOL_OFF
                	LCALL   SAVE_REC			;
                	CJNE	A,#STATE0,KAI_SUO_JP_F_JP1	;STATE0:存储记录和反写卡都成功
			LCALL	LEDBUZZ_LOW_VOL_OFF
			LJMP	PWR_DOWN

KAI_SUO_JP1:		LJMP	KAI_SUO_CARD15
KAI_SUO_JP2:		LJMP	KAI_SUO_CARD16
KAI_SUO_JP_F_JP1:	LJMP	KAI_SUO_JP_F

LOW_VOL_TEST_2:		MOV	A,BUFF_BEG_24C1X+0DH		;判断管理卡低电压
			CJNE	A,#LOW_VOL_LIMIT_50,LOW_VOL_TEST_2_1;管理卡为50次
LOW_VOL_TEST_2_1:	JNC	LOW_VOL_TEST_OFF

LOW_VOL_OK:		clr	reset_flag
			;MOV	A,BUFF_BEG_24C1X+0CH		;判断是否常开状态
			;CJNE	A,#00H,KAI_SUO_JP3
			;JB	CHANG_KAI_FLAG,KAI_SUO_JP3	;判断是否常开状态(改在开锁前判断)


			;LCALL	CHECK_DUI_HAO			;判断对号(通道锁和非通道锁都包括)
			;CJNE	A,#OK,KAI_SUO_JP5
			MOV	A,BUFF_BEG_MIF			;判断是否对号
KAI_SUO_09H:		CJNE	A,#09H,KAI_SUO_0AH
KAI_SUO_DUEI_HAO_JP:	LJMP	KAI_SUO_DUEI_HAO		;紧急卡

KAI_SUO_0AH:		CJNE	A,#0AH,KAI_SUO_0AJP1		;总控卡
                        LJMP    KAI_SUO_0AH_CONT
KAI_SUO_0AJP1:
                        LJMP    KAI_SUO_0BH
KAI_SUO_0AH_CONT:
                        MOV	HADDR_24C1X,#00H
			MOV	LADDR_24C1X,#12H
			MOV	LENGTH_24C1X,#1
			LCALL	RD_24C64
			CJNE	A,#ERROR,KAI_SUO_0AH_CONT1
                        LJMP    KAI_SUO_CARD7_JP
KAI_SUO_0AH_CONT1:
                        MOV     R0,#BUFF_BEG_24C1X
                        MOV     A,@R0
                        CJNE    A,#00H,KAI_SUO_0AH_X0
                        LJMP    KAI_SUO_0AH_DEFAULT
KAI_SUO_0AH_X0:
                        CJNE    A,#0FFH,KAI_SUO_0AH_X1
                        LJMP    KAI_SUO_0AH_DEFAULT             ;若字节定义为00或FF，则认为是默认状态，需查询4字节等级
KAI_SUO_0AH_X1:                                                 ;若字节定义为其它，则需查询后3字节等级
                        MOV     R7,#3
			MOV	R0,#BUFF_BEG_MIF+6
                        MOV     A,#00H
KAI_SUO_0AH_LOP1:
                        ORL     A,@R0
                        INC     R0
                        DJNZ    R7,KAI_SUO_0AH_LOP1
			JZ	KAI_SUO_DUEI_HAO_JP

CHECK_ZKC_BZ:		MOV	HADDR_24C1X,#00H
			MOV	LADDR_24C1X,#28H
			MOV	LENGTH_24C1X,#6
			LCALL	RD_24C64
			CJNE	A,#ERROR,CHECK_ZKC_BZ_JP1
                        LJMP    KAI_SUO_CARD7_JP
CHECK_ZKC_BZ_JP1:
                        MOV     R0,#BUFF_BEG_24C1X+3
                        MOV     R1,#BUFF_BEG_MIF+7
                        MOV     R7,#3
CHECK_ZKC_BZ_LOP1:
                        MOV     A,@R1
                        CPL     A
                        ORL     A,@R0
                        CJNE    A,#0FFH,CHECK_ZKC_BZ_ADP1
                        INC     R0
                        DEC     R1
                        DJNZ    R7,CHECK_ZKC_BZ_LOP1
			LJMP	CHECK_ZKC_BZ_N
CHECK_ZKC_BZ_ADP1:
			LJMP	KAI_SUO_DUEI_HAO
KAI_SUO_0AH_DEFAULT:
                        MOV     R7,#4
			MOV	R0,#BUFF_BEG_MIF+5
                        MOV     A,#00H
KAI_SUO_0AH_LOPX1:
                        ORL     A,@R0
                        INC     R0
                        DJNZ    R7,KAI_SUO_0AH_LOPX1
			JZ	KAI_SUO_DUEI_HAO_JP

                        MOV	HADDR_24C1X,#00H
			MOV	LADDR_24C1X,#28H
			MOV	LENGTH_24C1X,#6
			LCALL	RD_24C64
			CJNE	A,#OK,KAI_SUO_CARD7_JP

                        MOV     R0,#BUFF_BEG_24C1X+1
                        MOV     R1,#BUFF_BEG_24C1X+3
                        MOV     R7,#3
CHECK_ZKC_BZ_LOPX0:
                        MOV     A,@R1
                        MOV     @R0,A
                        INC     R0
                        INC     R1
                        DJNZ    R7,CHECK_ZKC_BZ_LOPX0

                        MOV     R0,#BUFF_BEG_24C1X
                        MOV     R1,#BUFF_BEG_MIF+8
                        MOV     R7,#4
CHECK_ZKC_BZ_LOPX1:
                        MOV     A,@R1
                        CPL     A
                        ORL     A,@R0
                        CJNE    A,#0FFH,CHECK_ZKC_BZ_ADPX1
                        INC     R0
                        DEC     R1
                        DJNZ    R7,CHECK_ZKC_BZ_LOPX1
			LJMP	CHECK_ZKC_BZ_N
CHECK_ZKC_BZ_ADPX1:
			LJMP	KAI_SUO_DUEI_HAO

CHECK_ZKC_BZ_N:
KAI_SUO_CARD20:		MOV     A,#CARD				;该类总控卡被禁止
                	MOV	B,#CARD_JIN_ZHI
                	LCALL   SAVE_REC			;
                	CJNE	A,#STATE0,KAI_SUO_JP_F		;STATE0:存储记录和反写卡都成功
			LCALL	LEDBUZZ_JIN_ZHI			;卡被禁止
			LJMP	PWR_DOWN


KAI_SUO_0BH:		CJNE	A,#0BH,KAI_SUO_0CH
			LCALL	DUEI_HAO_LC			;多层卡
			CJNE	A,#ERROR,KAI_SUO_DUEI_HAO
			LJMP	KAI_SUO_FEI_DUEI_HAO_JP

KAI_SUO_0CH:		CJNE	A,#0CH,KAI_SUO_0DH
			MOV	BUFF_BEG_MIF+7,BUFF_BEG_MIF+6
			LCALL	CHECK_LOU_CENG			;楼层卡
			CJNE	A,#ERROR,KAI_SUO_DUEI_HAO
			LJMP	KAI_SUO_FEI_DUEI_HAO_JP

KAI_SUO_0DH:		CJNE	A,#0DH,KAI_SUO_JP4
                        JB	JIU_DIAN_FLAG,KAI_SUO_CARD20
			LCALL	DUEI_HAO_LCF			;房间卡
			CJNE	A,#ERROR,KAI_SUO_DUEI_HAO
			JNB	FANGHAOCARD_FLAG,KAI_SUO_0DH_N
			LCALL	KAI_SUO_CHECK_10S
			CJNE	A,#ERROR,KAI_SUO_DUEI_HAO
KAI_SUO_0DH_N:		LJMP	KAI_SUO_FEI_DUEI_HAO_JP

KAI_SUO_JP3:		LJMP	KAI_SUO_CARD17
KAI_SUO_JP4:		LJMP	KAI_SUO_CARD19
KAI_SUO_FEI_DUEI_HAO_JP:	LJMP	KAI_SUO_FEI_DUEI_HAO



KAI_SUO_DUEI_HAO:	LCALL	COMP_SN

			CJNE	A,#COMP_STATE0,KAI_SUO_CARD1	;读24C16出错
KAI_SUO_CARD7_JP:	LJMP	KAI_SUO_CARD7

KAI_SUO_CARD1:		CJNE	A,#COMP_STATE1,KAI_SUO_CARD2	;主序号没有和自己相同的
			MOV	A,#FIND_BLANK			;找空位置写入
			LJMP	KAI_SUO_CARD8

KAI_SUO_CARD2:		CJNE	A,#COMP_STATE2,KAI_SUO_CARD3	;主序号和自己相同,且副序号也相同
			LJMP	KAI_SUO_CARD9			;正常

KAI_SUO_CARD3:		CJNE	A,#COMP_STATE3,KAI_SUO_CARD4	;主序号和自己相同,副序号大于自己
			LJMP	KAI_SUO_CARD10			;自己已挂失

KAI_SUO_CARD4:		CJNE	A,#COMP_STATE4,KAI_SUO_CARD5	;主序号和自己相同,副序号小于自己但不为0
			MOV	A,#FIND_ITSELF			;改副序号(覆盖)
			LJMP	KAI_SUO_CARD8

KAI_SUO_CARD5:		CJNE	A,#COMP_STATE5,KAI_SUO_CARD6	;主序号和自己相同,副序号为0
			LJMP	KAI_SUO_CARD11			;属于被清除的对号卡,不能开锁

KAI_SUO_CARD6:		LCALL	LEDBUZZ_PRG_ERROR		;程序运行错误(正常状态下不可能出现)
			LJMP	PWR_DOWN

KAI_SUO_CARD7:		LJMP	ER_R_W_24C16			;读24C16出错

KAI_SUO_JP_F:		CJNE	A,#STATE1,KAI_SUO_JP_F_1	;STATE1:24C64错误
			LJMP	KAI_SUO_CARD7
KAI_SUO_JP_F_1:		LJMP	PWR_DOWN			;STATE2:反写卡不成功,不再发声光信号,直接掉电


KAI_SUO_CARD8:		LCALL	FIND_WR 			;把自己的序号填入(原位或空位)
			CJNE	A,#FIND_STATE0,KAI_SUO_CARD8_1	;读/写24C16出错
			LJMP	ER_R_W_24C16

KAI_SUO_CARD8_1:	CJNE	A,#FIND_STATE1,KAI_SUO_CARD8_2	;没找到空位置
			MOV     A,#CARD				;记录卡号已满,没有空位置
                	MOV	B,#CARD_NO_BLANK
                	LCALL   SAVE_REC			;
                	CJNE	A,#STATE0,KAI_SUO_JP_F		;STATE0:存储记录和反写卡都成功
			LCALL	LEDBUZZ_NO_BLANK
			LJMP	PWR_DOWN

KAI_SUO_CARD8_2:	CJNE	A,#FIND_STATE2,KAI_SUO_CARD8_3	;顺利把序号填入

			LJMP	KAI_SUO_CARD12			;准备开锁

KAI_SUO_CARD8_3:	LJMP	KAI_SUO_CARD6			;程序运行错误(正常状态下不可能出现)


KAI_SUO_CARD9:		LJMP	KAI_SUO_CARD12			;准备开锁


KAI_SUO_CARD10:		MOV     A,#CARD				;记录卡号已挂失
                	MOV	B,#CARD_GUA_SHI
                	LCALL   SAVE_REC			;
                	CJNE	A,#STATE0,KAI_SUO_JP_F		;STATE0:存储记录和反写卡都成功
			LCALL	LEDBUZZ_GUA_SHI
			LJMP	PWR_DOWN

KAI_SUO_CARD11:		MOV     A,#CARD				;记录卡号已经清除
                	MOV	B,#CARD_QING_CHU
                	LCALL   SAVE_REC			;
                	CJNE	A,#STATE0,KAI_SUO_JP_F		;STATE0:存储记录和反写卡都成功
			LCALL	LEDBUZZ_QING_CHU		;已经清除
			LJMP	PWR_DOWN


KAI_SUO_CARD12:		MOV	A,BUFF_BEG_MIF
			CJNE	A,#09H,KAI_SUO_CARD12_1		;紧急卡?
			LJMP	KAI_SUO_CARD13
KAI_SUO_CARD12_1:	CJNE	A,#0DH,KAI_SUO_CARD12_2	        ;房间卡?
			LJMP	KAI_SUO_CARD13
KAI_SUO_CARD12_2:       CJNE	A,#0AH,KAI_SUO_CARD14_JP	;总控卡?
                        MOV     R0,#BUFF_BEG_MIF+26
                        MOV     A,@R0
                        XRL     A,#0FFH
                        JZ      KAI_SUO_CARD14_JP               ;假如总控卡未有开反锁标志（01），则仍然进行方舌检测
			LJMP	KAI_SUO_CARD13
KAI_SUO_CARD14_JP:	LJMP	KAI_SUO_CARD14

KAI_SUO_CARD17_JP:	LJMP	KAI_SUO_CARD17

KAI_SUO_CARD13:		JB	CHANG_KAI_FLAG,KAI_SUO_CARD17_JP;判断是否常开状态

			MOV	A,#CARD
			MOV	B,#CARD_OPEN
                	LCALL	SAVE_REC			;先记录
                        XRL     A,#STATE0
                        JZ      KAI_SUO_CARD13_ADP1
                        LJMP    KAI_SUO_JP_F		        ;STATE0:存储记录和反写卡都成功
KAI_SUO_CARD13_ADP1:
			MOV	A,BUFF_BEG_MIF
			CJNE	A,#0DH,KAI_SUO_CARD13_1		;房间卡?要具有常开常闭功能！！
			JNB	ONE_OPEN_FLAG,KAI_SUO_CARD13_1
			MOV     A,#CARD				;记录常开
                	MOV	B,#CARD_CHANGKAI
                	LCALL   SAVE_REC			;不再做其他判断
                	CJNE	A,#STATE0,KAI_SUO_JP_F_JP2	;STATE0:存储记录和反写卡都成功
			LCALL	LEDBUZZ_OPEN
			LCALL	MOT_POSITIVE			;打开电机
			SETB	CHANG_KAI_FLAG
			CLR	TOTAL_PWR
			MOV	R7,#6
LOOP_5S_1:		MOV	T0INTCOUNT,#250
			LCALL	DELAY05S
			DJNZ	R7,LOOP_5S_1
			LJMP	PWR_DOWN

KAI_SUO_JP_F_JP2:	LJMP	KAI_SUO_JP_F

KAI_SUO_CARD13_1:	LCALL	LEDBUZZ_OPEN

			SETB	TONGUE_SW
			LCALL	DELAY5US
			MOV	C,TONGUE_SW			;因为主舌很可能坏
			MOV	TONGUE_SW_BK,C			;所以记下当时的主舌状态,以判断以后是否动作
			CLR	TONGUE_SW

			LCALL	MOT_POSITIVE			;打开电机
			;CJNE	A,#OK,KAI_SUO_CARD7		;读写24C16(置常开标志)失败,跳ER_R_W_24C16


TEST_TONGUE_SW:		MOV	COUNT0,#180
TEST_TONGUE_SW0:    	SETB	TONGUE_SW
			LCALL	DELAY5US
			JNB	TONGUE_SW,TEST_TONGUE_SW1	;是否扳动手柄(主舌合上否)
			CLR	TONGUE_SW
			LCALL	DELAY001S
			DJNZ	COUNT0,TEST_TONGUE_SW0		;2S

TEST_TONGUE_SW1:	;SETB	GLED				;&*关绿灯
			SETB	CHANGKAI_SW
			LCALL	DELAY5US
			JB	CHANGKAI_SW,KAI_SUO_READ_20
			CLR	CHANGKAI_SW
			;CLR 	YLED				;&*亮黄灯
			CLR	GLED
			CLR	RLED

			MOV	T0INTCOUNT,#250
			MOV	WDTCONTER,#00110111B
KAI_SUO_READ_0:
KAI_SUO_READ_00:       	;;;;;
			CLR	RST_1702SL
			LCALL	SELECT_MIFRAM
                        SETB	TEST_1702SL
                        SETB	RD_RC500
			SETB	WR_RC500
			;SETB	TEST_1702SL
			mov	count1,#10
			LCALL	mifscard_1
			SETB	RST_1702SL
			CLR	TEST_1702SL
			CJNE	A,#ERROR,HAVECARD_2
			LCALL	DELAY02S
			LCALL	DELAY01S
			SETB	TONGUE_SW
			LCALL	DELAY5US
			JNB	TONGUE_SW,KAI_SUO_READ_2	;是否扳动手柄(主舌合上否)
			CLR	TONGUE_SW
			MOV	A,T0INTCOUNT
                	CJNE	A,#200,KAI_SUO_READ_1		;(250-200)*.03=1.5,即再读1.5S卡（不管多少次）
KAI_SUO_READ_1:		JNC	KAI_SUO_READ_0
			LJMP	KAI_SUO_READ_20

KAI_SUO_READ_2:         ;lcall   buzzer
                        JNB	TONGUE_SW_BK,KAI_SUO_READ_00	;原来主舌开关就是坏的,则继续读卡

;;;;;;;;;;;;;;;

KAI_SUO_READ_20:	CLR	CHANGKAI_SW
			MOV	COUNT0,#100
KAI_SUO_READ_21:	LCALL	DELAY001S
                	SETB	TONGUE_SW
			LCALL	DELAY5US
			JB	TONGUE_SW,KAI_SUO_READ_22	;如手柄还未松开,再等3S
                	CLR	TONGUE_SW
			DJNZ	COUNT0,KAI_SUO_READ_21
KAI_SUO_READ_22:	SETB	GLED
			SETB	RLED
			LCALL	MOT_REVERSE			;关闭电机
			;CJNE	A,#OK,JP_CARD7			;读写24C16(记录)失败,跳ER_R_W_24C16

LOW_VOL_TEST:		MOV	A,VOL_STATE			;注:关闭后才能测电压!
			CJNE	A,#V_LOW,LOW_VOL_TEST_END
			MOV	HADDR_24C1X,#00H
			MOV	LADDR_24C1X,#0DH
			MOV	LENGTH_24C1X,#1
			LCALL	RD_24C64			;读出低压计数器的值
			CJNE	A,#OK,JP_CARD7			;读写24C16(记录)失败,跳ER_R_W_24C16
                	MOV	A,BUFF_BEG_24C1X
                	ADD	A,#1
                	MOV	BUFF_BEG_24C1X,A
                	MOV	HADDR_24C1X,#00H
			MOV	LADDR_24C1X,#0DH
			MOV	LENGTH_24C1X,#1
			LCALL	WR_24C64			;加1后写回低压计数器
			CJNE	A,#OK,JP_CARD7			;读写24C16(记录)失败,跳ER_R_W_24C16

                	LCALL	LEDBUZZ_LOW_VOL
LOW_VOL_TEST_END:	CLR	TOTAL_PWR
			MOV	R7,#6
LOOP_5S_2:		MOV	T0INTCOUNT,#250
			LCALL	DELAY05S
			DJNZ	R7,LOOP_5S_2
			LJMP	PWR_DOWN

HAVECARD_2:
                        CLR	BUZZ
			LCALL	DELAY002S
			;LCALL	DELAY001S
			SETB    buzz
			MOV     A,#CARD				;记录常开
                	MOV	B,#CARD_CHANGKAI
                	LCALL   SAVE_REC			;不再做其他判断
                	CJNE	A,#STATE0,KAI_SUO_READ_22	;STATE0:存储记录和反写卡都成功
			LCALL	LEDBUZZ_CHANG_KAI		;读到卡,不再做其他判断,也不能测电压!
			SETB	CHANG_KAI_FLAG
			CLR	TOTAL_PWR
			MOV	R7,#6
LOOP_5S_3:		MOV	T0INTCOUNT,#250
			LCALL	DELAY05S
			DJNZ	R7,LOOP_5S_3
			LJMP	PWR_DOWN

JP_CARD7:		LJMP	KAI_SUO_CARD7

KAI_SUO_CARD14:		SETB	BKLK_SW
			LCALL	DELAY5US
			JB	BKLK_SW,KAI_SUO_CARD13_JP	;非紧急卡,要测方舌
			CLR	BKLK_SW
			JB	TONG_DAO_FLAG,KAI_SUO_CARD13_JP	;通道锁,不测方舌
			MOV     A,#CARD				;记录方舌反锁
                	MOV	B,#DOOR_BKLK
                	LCALL   SAVE_REC
                	CJNE	A,#STATE0,KAI_SUO_JP_F_JP3		;STATE0:存储记录和反写卡都成功
			LCALL	LEDBUZZ_BKLK			;方舌反锁,报警
			LJMP	PWR_DOWN

KAI_SUO_CARD13_JP:	LJMP	KAI_SUO_CARD13
KAI_SUO_JP_F_JP3:	LJMP	KAI_SUO_JP_F

KAI_SUO_CARD15:		LCALL   RD_8563
			MOV     A,#CARD				;记录密码错误
                	MOV	B,#MI_MA_ERROR
                	LCALL   SAVE_REC
                	CJNE	A,#STATE0,KAI_SUO_JP_F_JP3		;STATE0:存储记录和反写卡都成功
			LCALL	LEDBUZZ_MI_MA_ERROR		;密码错误
			LJMP	PWR_DOWN

KAI_SUO_CARD16:		CJNE	A,#CHECK_TIME_STATE0,KAI_SUO_CARD16_1
			MOV     A,#CARD				;记录时间错误
                	MOV	B,#SHI_JIAN_ERROR
                	LCALL   SAVE_REC
                	CJNE	A,#STATE0,KAI_SUO_JP_F_JP3		;STATE0:存储记录和反写卡都成功
			LCALL   LEDBUZZ_CHECK_TIME0		;限期已到
			LJMP	PWR_DOWN

KAI_SUO_CARD16_1:	CJNE	A,#CHECK_TIME_STATE1,KAI_SUO_CARD16_2
			MOV     A,#CARD				;记录未到有效时间
                	MOV	B,#WEIDAO_YOUXIAO_SHIJIAN
                	LCALL   SAVE_REC			;
                	CJNE	A,#STATE0,KAI_SUO_JP_F_JP3		;STATE0:存储记录和反写卡都成功
			LCALL   LEDBUZZ_CHECK_TIME1		;未到有效时间
			LJMP	PWR_DOWN

KAI_SUO_CARD16_2:	CJNE	A,#CHECK_TIME_STATE2,KAI_SUO_CARD16_3
			MOV     A,#CARD				;记录超过无效时间
                	MOV	B,#CHAOGUO_WUXIAO_SHIJIAN
                	LCALL   SAVE_REC			;
                	CJNE	A,#STATE0,KAI_SUO_JP_F_JP3		;STATE0:存储记录和反写卡都成功
			LCALL   LEDBUZZ_CHECK_TIME2		;超过无效时间
			LJMP	PWR_DOWN

KAI_SUO_CARD16_3:	LJMP	KAI_SUO_CARD6			;程序运行错误(正常状态下不可能出现)


KAI_SUO_CARD17:		MOV     A,#CARD				;且前面已判断过密码和时间
                	MOV	B,#CARD_CHANGBI
                	LCALL   SAVE_REC			;不再做其他判断
                	CJNE	A,#STATE0,KAI_SUO_JP_F_JP3		;STATE0:存储记录和反写卡都成功
			LCALL	LEDBUZZ_CLOSE			;常开状态关锁
			LCALL	MOT_REVERSE			;关闭电机
			CJNE	A,#OK,ER_R_W_24C16		;读写24C16(记录)失败,跳ER_R_W_24C16
			LJMP	LOW_VOL_TEST


;KAI_SUO_CARD18:		CJNE	A,#03H,KAI_SUO_CARD18_1		;通道锁处理(注:通道锁不测方舌)

;KAI_SUO_CARD18_0:	LJMP	KAI_SUO_CARD13			;03,总通道,因前面已判断过密码和时间等,因此可直接开锁


;KAI_SUO_CARD18_1:	CJNE	A,#02H,KAI_SUO_CARD18_2		;02,楼通道
;			LCALL	CHECK_DUI_HAO
;			CJNE	A,#OK,KAI_SUO_CARD18_1_1	;执行CHECK_DUI_HAO后,紧急卡和总控卡已通过
;			LJMP	KAI_SUO_CARD18_0		;

;KAI_SUO_CARD18_1_1:	LCALL	CHECK_LOU_HAO			;其余卡再核对楼号
;			CJNE	A,#OK,KAI_SUO_CARD19		;楼号不对,跳转报警
;			LJMP	KAI_SUO_CARD18_0		;


;KAI_SUO_CARD18_2:	CJNE	A,#01H,KAI_SUO_CARD18_3		;01,层通道

;			LCALL	CHECK_DUI_HAO
;			CJNE	A,#OK,KAI_SUO_CARD18_2_1	;执行CHECK_DUI_HAO后,紧急卡,总控卡,多层卡,楼层卡已通过
;			LJMP	KAI_SUO_CARD18_0		;

;KAI_SUO_CARD18_2_1:	LCALL	CHECK_LOU_HAO			;仅余下房间卡,再核对楼号
;			CJNE	A,#OK,KAI_SUO_CARD19		;楼号不对,跳转报警
;			LCALL	CHECK_CENG_HAO			;再核对层号
;			CJNE	A,#OK,KAI_SUO_CARD19
;			LJMP	KAI_SUO_CARD18_0		;

;KAI_SUO_CARD18_3:	LJMP	KAI_SUO_CARD6			;程序运行错误(正常状态下不可能出现)


KAI_SUO_CARD19:		MOV     A,#CARD				;
                	MOV	B,#FANG_HAO_ERROR
                	LCALL   SAVE_REC			;
                	CJNE	A,#STATE0,KAI_SUO_JP_F_JP3		;STATE0:存储记录和反写卡都成功
			LCALL	LEDBUZZ_FANG_HAO_ERROR		;房间号错误
			LJMP	PWR_DOWN


KAI_SUO_FEI_DUEI_HAO:	LCALL	COMP_SN				;处理非对号卡!!!!!!

			CJNE	A,#COMP_STATE0,KAI_SUO_CARD21	;读24C16出错
			LJMP	KAI_SUO_CARD7

KAI_SUO_CARD21:		CJNE	A,#COMP_STATE1,KAI_SUO_CARD22	;主序号没有和自己相同的
			LJMP	KAI_SUO_CARD19			;未授权,提示房间号错误

KAI_SUO_CARD22:		CJNE	A,#COMP_STATE2,KAI_SUO_CARD23	;主序号和自己相同,且副序号也相同
			LJMP	KAI_SUO_CARD9			;正常

KAI_SUO_CARD23:		CJNE	A,#COMP_STATE3,KAI_SUO_CARD24	;主序号和自己相同,副序号大于自己
			LJMP	KAI_SUO_CARD10			;自己已挂失

KAI_SUO_CARD24:		CJNE	A,#COMP_STATE4,KAI_SUO_CARD25	;主序号和自己相同,副序号小于自己但不为0
			MOV	A,#FIND_ITSELF			;改副序号(覆盖)
			LJMP	KAI_SUO_CARD8

KAI_SUO_CARD25:		CJNE	A,#COMP_STATE5,KAI_SUO_CARD26	;主序号和自己相同,副序号为0
			LJMP	KAI_SUO_CARD11			;属于被清除的对号卡,不能开锁(正常状态下不可能出现)

KAI_SUO_CARD26:		LCALL	LEDBUZZ_PRG_ERROR		;程序运行错误(正常状态下不可能出现)
			LJMP	PWR_DOWN

ER_R_W_24C16:		LCALL	LEDBUZZ_EEPROM_ERROR
			LJMP	PWR_DOWN

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

KAI_SUO_CARD_JD:	JB	JIU_DIAN_FLAG,KAI_SUO_CARD_JD_BEG
			LJMP	KAI_SUO_CARD20

KAI_SUO_CARD_JD_BEG:	SETB	CARD_FLAG			;置"卡操作标志",

			jb	reset_flag,LOW_VOL_JD_OK		;上电复位后第一次开锁不判断低压计数器（可能是外接电源）
			MOV	A,BUFF_BEG_24C1X+0DH		;判断KEYCARD低电压
			CJNE	A,#LOW_VOL_LIMIT,LOW_VOL_TEST_JD_1;KEYCARD为30次
LOW_VOL_TEST_JD_1:	JC	LOW_VOL_JD_OK
			MOV     A,#CARD				;记录低电压关闭
                	MOV	B,#LOW_VOL_OFF
                	LCALL   SAVE_REC			;
                	CJNE	A,#STATE0,KAI_SUO_JP_F_JP4	;STATE0:存储记录和反写卡都成功
			LCALL	LEDBUZZ_LOW_VOL_OFF
			LJMP	PWR_DOWN

LOW_VOL_JD_OK:		clr	reset_flag
			LCALL	CHECK_MI_MA			;开锁卡
			CJNE	A,#ERROR,KAI_SUO_JD_1		;判断密码
			LJMP	KAI_SUO_CARD15			;记录密码错误

KAI_SUO_JD_1:
                        MOV	HADDR_24C1X,#00H
			MOV	LADDR_24C1X,#12H
			MOV	LENGTH_24C1X,#1
			LCALL	RD_24C64
			CJNE	A,#OK,ER_R_W_24C16
                        MOV     R0,#BUFF_BEG_24C1X
                        MOV     A,@R0
                        CJNE    A,#00H,KAI_SUO_JD_1_0
                        CLR     JD_SPE_FLAG
                        LJMP    KAI_SUO_JD_1X
KAI_SUO_JD_1_0:
                        CJNE    A,#0FFH,KAI_SUO_JD_1_1
                        CLR     JD_SPE_FLAG
                        LJMP    KAI_SUO_JD_1X                   ;若使能标志为0，说明无需查客人卡等级
KAI_SUO_JD_1_1:

                        CLR     JD_SPE_FLAG
                        MOV     R7,#3
			MOV	R0,#BUFF_BEG_MIF+8
                        MOV     A,#00H
                        ORL     A,@R0
			JZ	KAI_SUO_JD_1X                  ;若等级为全0，则认为是老版本卡或是无等级卡，直接进入下面的流程

		        MOV	HADDR_24C1X,#00H
			MOV	LADDR_24C1X,#28H
			MOV	LENGTH_24C1X,#1
			LCALL	RD_24C64
			CJNE	A,#OK,ER_R_W_24C16

                        SETB    JD_SPE_FLAG
                        MOV     R0,#BUFF_BEG_24C1X
                        MOV     R1,#BUFF_BEG_MIF+8
                        MOV     A,@R1
                        CPL     A
                        ORL     A,@R0
                        CJNE    A,#0FFH,KAI_SUO_JD_1X
                        CLR     JD_SPE_FLAG                     ;标志置位说明为特殊房正确，一旦正确则查房号后需要借助该标志判断走向


	                ;MOV     A,#CARD				;该类客人卡被禁止
                	;MOV	B,#CARD_JIN_ZHI
                	;LCALL   SAVE_REC			;
                	;CJNE	A,#STATE0,KAI_SUO_JP_F_JP4	;STATE0:存储记录和反写卡都成功
			;LCALL	LEDBUZZ_JIN_ZHI			;卡被禁止
			;LJMP	PWR_DOWN
KAI_SUO_JD_1X:

                        MOV	A,BUFF_BEG_24C1X+0BH
			CJNE	A,#04H,$+3
			JNC	KAI_SUO_CARD19_JP
			LCALL	CHECK_LOU_CENG_FANG_A
			CJNE	A,#ERROR,KAI_SUO_JD_2
                        JB      JD_SPE_FLAG,KAI_SUO_JD_2X       ;房间号错误，再查特殊房标志是否正确，正确则继续流程
KAI_SUO_CARD19_JP:	LJMP	KAI_SUO_CARD19			;房间号错误

KAI_SUO_JD_2:		CLR     JD_SPE_FLAG                     ;无论特殊房是否正确，房号判断通过后一律清除该标志
KAI_SUO_JD_2X:
                        LCALL	CHECK_TIME_JD			;判断时间
			CJNE	A,#CHECK_TIME_STATE3,KAI_SUO_CARD16_JP
			LJMP	KAI_SUO_JD_3
KAI_SUO_CARD16_JP:	LJMP	KAI_SUO_CARD16			;限期已到

KAI_SUO_JP_F_JP4:	LJMP	KAI_SUO_JP_F

KAI_SUO_JD_3:
KE_REN_CARD:		;JB	TAIFANG_FLAG,KE_REN_CARD0

                        MOV     A,BUFF_BEG_MIF+00H
                        CJNE    A,#0FH,KE_REN_CARD00
                        LJMP    KAI_SUO_JD_4                    ;一旦检测为单次卡，则跳过批次号处理流程

KE_REN_CARD00:
			MOV	A,BUFF_BEG_24C1X+0BH
			JNZ	KE_REN_CARD0
			LCALL	CHECK_IN_TIME_KRK		;客人卡和预订客人卡,特殊处理
			CJNE	A,#CH_I_T_STATE0,KE_REN_CARD1
KE_REN_CARD0:		MOV	HADDR_24C1X,#00H		;相等
			MOV	LADDR_24C1X,#5EH
			MOV	LENGTH_24C1X,#1
			LCALL	RD_24C64			;查禁止标记
			CJNE	A,#OK,KAI_SUO_JP_E
			MOV	A,BUFF_BEG_24C1X
			JNZ	KAI_SUO_JP5_2			;卡被禁止
			LJMP	KAI_SUO_JD_4			;如未禁止,仍旧可用

KE_REN_CARD1:		CJNE	A,#CH_I_T_STATE1,KE_REN_CARD2
			MOV	HADDR_24C1X,#00H		;锁内小于卡
			MOV	LADDR_24C1X,#5EH
			MOV	LENGTH_24C1X,#1
			MOV	BUFF_BEG_24C1X,#00H
			LCALL	WR_24C64			;清禁止标记
			CJNE	A,#OK,KAI_SUO_JP_E
			LJMP	KAI_SUO_JD_4

KE_REN_CARD2:		CJNE	A,#CH_I_T_STATE2,KE_REN_CARD3
			LJMP	KAI_SUO_JP5_1                   ;锁内大于卡,卡被覆盖
KE_REN_CARD3:		LJMP	KAI_SUO_JP_E


KAI_SUO_JP5_1:		MOV     A,#CARD				;该类总控卡被覆盖
                	MOV	B,#CARD_FU_GAI
                	LCALL   SAVE_REC			;
                	CJNE	A,#STATE0,KAI_SUO_JP_F_JP4
			LCALL	LEDBUZZ_FU_GAI			;卡被覆盖
			LJMP	PWR_DOWN

KAI_SUO_JP5_2:		MOV     A,#CARD				;该类卡被禁止
                	MOV	B,#CARD_JIN_ZHI
                	LCALL   SAVE_REC			;
                	CJNE	A,#STATE0,KAI_SUO_JP_F_JP4	;STATE0:存储记录和反写卡都成功
			LCALL	LEDBUZZ_JIN_ZHI			;卡被禁止
			LJMP	PWR_DOWN


KAI_SUO_JP_E:		LJMP	ER_R_W_24C16			;24C64错误


KAI_SUO_JD_4:
			MOV	A,#CARD
			MOV	B,#CARD_OPEN
                	LCALL	SAVE_REC			;先记录
			CJNE	A,#STATE0,KAI_SUO_JP_F_JP4	;STATE0:存储记录和反写卡都成功

                        MOV     A,BUFF_BEG_MIF+00H
                        CJNE    A,#0FH,KAI_SUO_JD_40
                        LCALL   CLEAR_CARD

KAI_SUO_JD_40:
			LCALL	LEDBUZZ_OPEN

			SETB	TONGUE_SW
			LCALL	DELAY5US
			MOV	C,TONGUE_SW			;因为主舌很可能坏
			MOV	TONGUE_SW_BK,C			;所以记下当时的主舌状态,以判断以后是否动作
			CLR	TONGUE_SW

			LCALL	MOT_POSITIVE			;打开电机

			MOV	COUNT0,#200
TEST_TONGUE_JD:    	SETB	TONGUE_SW
			LCALL	DELAY5US
			JNB	TONGUE_SW,TEST_TONGUE_JD1	;是否扳动手柄(主舌合上否)
			CLR	TONGUE_SW
			LCALL	DELAY001S
			DJNZ	COUNT0,TEST_TONGUE_JD		;2S

TEST_TONGUE_JD1:
			MOV	T0INTCOUNT,#250
			MOV	WDTCONTER,#00110111B

			MOV	COUNT0,#150
TEST_TONGUE_JD2:	LCALL	DELAY001S
                	SETB	TONGUE_SW
			LCALL	DELAY5US
			JB	TONGUE_SW,TEST_TONGUE_JD3	;如手柄还未松开,再等3S
                	CLR	TONGUE_SW
			DJNZ	COUNT0,TEST_TONGUE_JD2
TEST_TONGUE_JD3:	SETB	GLED
			SETB	RLED
			LCALL	DELAY05S
                	LCALL	MOT_REVERSE			;关闭电机

LOW_VOL_JD:		MOV	A,VOL_STATE			;注:关闭后才能测电压!
			CJNE	A,#V_LOW,LOW_VOL_JD_END
			MOV	HADDR_24C1X,#00H
			MOV	LADDR_24C1X,#0DH
			MOV	LENGTH_24C1X,#1
			LCALL	RD_24C64			;读出低压计数器的值
			CJNE	A,#OK,KAI_SUO_JP_E		;读写24C16(记录)失败,跳ER_R_W_24C16
                	MOV	A,BUFF_BEG_24C1X
                	ADD	A,#1
                	MOV	BUFF_BEG_24C1X,A
                	MOV	HADDR_24C1X,#00H
			MOV	LADDR_24C1X,#0DH
			MOV	LENGTH_24C1X,#1
			LCALL	WR_24C64			;加1后写回低压计数器
			CJNE	A,#OK,KAI_SUO_JP_E1		;读写24C16(记录)失败,跳ER_R_W_24C16

                	LCALL	LEDBUZZ_LOW_VOL
LOW_VOL_JD_END:		CLR	TOTAL_PWR
			LJMP	PWR_DOWN
KAI_SUO_JP_E1:
                        LJMP    KAI_SUO_JP_E
;ZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZ
;;;;子程序
;ZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZ
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
CPU_INITIALIZE:		SETB    MOT_PWR			;关电机电源
			SETB	MOT_CTRL		;MOT_CTRL高电平时反转,以确保锁不常开
			SETB	BUZZ
			SETB	RLED
			SETB	GLED
			;SETB	YLED
			SETB	MID_VOL
			SETB	LOW_VOL
			CLR	BKLK_SW
			SETB	TOTAL_PWR		;开外设电源
			MOV	T0INTCOUNT,#250
			MOV     TH0,#15H          	;时钟=24MHZ,机器周期为0.5US
                	MOV     TL0,#0A0H         	;定时(2E16-初值)*0.5EXP-6=0.03S
                	SETB	ET0			;开T0中断
			SETB	TR0
			SETB	ET1
			SETB	TR1
			RET
;***********************************************************************************************
;;;;选择外部存储器(EXTRAM和RC500)
;***********************************************************************************************
SELECT_MIFRAM:		CLR	EX0
			MOV	AUXR,#02H
			RET
SELECT_EXTRAM:		CLR	EX0
			MOV	AUXR,#00H
			RET
SELECT_CLOSERAM:	CLR	EX0
			MOV	AUXR,#01H
			RET

;***********************************************************************************************
;;;;延时子程序(24M晶振)
;***********************************************************************************************
;;;;2US延时;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
DELAY2US:		NOP
			NOP
			;NOP
			;NOP
			RET
;;;;5US延时;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
DELAY5US:		MOV	DCOUNT1,#4
			DJNZ	DCOUNT1,$
			RET
;;;;10US延时;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
DELAY10US:		MOV	DCOUNT1,#9
			DJNZ	DCOUNT1,$
			RET
;;;;20US延时;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
DELAY20US:		MOV	DCOUNT1,#19;38;9
			DJNZ	DCOUNT1,$
			RET
;;;;50US延时;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
DELAY50US:		MOV	DCOUNT1,#49;98;23
			DJNZ	DCOUNT1,$
			RET
;;;;100US延时;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
DELAY100US:		MOV	DCOUNT1,#99;199
			DJNZ	DCOUNT1,$
			RET

;;;;500US延时;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
DELAY500US:		MOV 	DCOUNT1,#5
			MOV	WDTCONTER,#00110111B
D500US:          	MOV 	DCOUNT2,#99;199
                	DJNZ 	DCOUNT2,$
                	DJNZ 	DCOUNT1,D500US
                	RET
;;;;0.001秒延时;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
DELAY0001S:      	MOV 	DCOUNT1,#10
			MOV	WDTCONTER,#00110111B
D00011:          	MOV 	DCOUNT2,#99;199
                	DJNZ 	DCOUNT2,$
                	DJNZ 	DCOUNT1,D00011
                	RET

;;;;0.01秒延时;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
DELAY001S:      	MOV 	DCOUNT1,#100
			MOV	WDTCONTER,#00110111B
D0011:          	MOV 	DCOUNT2,#99;199
                	DJNZ 	DCOUNT2,$
                	DJNZ 	DCOUNT1,D0011
                	RET
;;;;0.02秒延时;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
DELAY002S:      	MOV 	DCOUNT1,#200
			MOV	WDTCONTER,#00110111B
D0021:          	MOV 	DCOUNT2,#99;199
                	DJNZ 	DCOUNT2,$
                	DJNZ 	DCOUNT1,D0021
                	RET
;;;;0.05秒延时;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

DELAY005S:      	MOV 	DCOUNT3,#5
D0051:			LCALL	DELAY001S
                	DJNZ 	DCOUNT3,D0051
                	RET
;;;;0.1秒延时;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

DELAY01S:		LCALL	DELAY005S
			LCALL	DELAY005S
			RET
;;;;0.2秒延时;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

DELAY02S:       	LCALL	DELAY01S
			LCALL	DELAY01S
			RET
;;;;0.5秒延时;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

DELAY05S:       	MOV 	DCOUNT3,#50
D051:           	LCALL	DELAY001S
			DJNZ 	DCOUNT3,D051
                	RET

;***********************************************************************************************

;***********************************************************************************************
;;;;T0中断服务子程序(用作看门狗和某些定时)
;***********************************************************************************************

T0_INT:          	CLR	TF0
			MOV     TH0,#15H          	;时钟=24MHZ,机器周期为0.5US
                	MOV     TL0,#0A0H         	;定时(2E16-初值)*0.5EXP-6=0.03S
                	PUSH	ACC
                	PUSH	PSW
T0INT_1:		MOV	A,PWR_24C1X_NUM
			JZ	T0INT_2
                	DEC	PWR_24C1X_NUM
                	LJMP	T0INT_3

T0INT_2:               	SETB	PWR_24C64
			SETB	SDA_24C64
			SETB	SCL_24C64

T0INT_3:              	POP	PSW
			POP	ACC
			DJNZ	T0INTCOUNT,T0INT_RET
			POP     ACC
			POP	ACC
			MOV	DPTR,#MAIN
			PUSH	DPL
			PUSH	DPH
T0INT_RET:		RETI

;***********************************************************************************************
;;;;测电压
;***********************************************************************************************
TEST_VOL:		JB	MID_VOL,TEST_VOL2	;如果MID_VOL为1,说明是高压状态
			JB	LOW_VOL,TEST_VOL1	;MID_VOL为0,但LOW_VOL为1,说明是中压状态
			MOV	A,#V_LOW		;否则为低压状态
			RET
TEST_VOL1:		MOV	A,#V_MIDDLE
			RET
TEST_VOL2:		MOV	A,#V_HIGH
			RET


;***********************************************************************************************
;;;;声光信号
;LEDBUZZ_MODE:
;D7D6D5D4分别表示:RLED,GLED,YLED,BUZZ,0为亮,1为灭
;D3表示延时选择:0为0.25S,1为0.05S(为表达方便,改称为0.5S和0.1S)
;D2D1D0从001到111,为循环次数
;停顿时间等于点亮时间
;***********************************************************************************************
;***********************************************************************************************
;红\黄\绿三灯使用此处程序
;LEDBUZZ:		SETB	GLED
;			SETB	RLED
;			SETB	YLED
;			SETB	BUZZ
;			lcall	delay02s
;			lcall	delay005s
;			MOV	A,LEDBUZZ_MODE
;			ANL	A,#07H
;			MOV 	COUNT0,A
;
;LEDBUZZ_1:		MOV	A,LEDBUZZ_MODE
;			MOV	C,ACC.7
;			MOV	RLED,C
;			MOV	C,ACC.6
;			MOV	GLED,C
;			MOV	C,ACC.5
;			MOV	YLED,C
;			MOV	C,ACC.4
;			MOV	BUZZ,C
;
;			MOV	C,ACC.3
;			JC	LEDBUZZ_2
;
;			LCALL	DELAY02S
;LEDBUZZ_2:		LCALL	DELAY005S
;
;			SETB	RLED
;			SETB	GLED
;			SETB	YLED
;			SETB	BUZZ
;
;			JC	LEDBUZZ_3
;
;			LCALL	DELAY02S
;LEDBUZZ_3:		LCALL	DELAY01S
;			DJNZ	COUNT0,LEDBUZZ_1
;
;			LCALL	DELAY02S
;			RET

;只有红\绿双色灯(没有黄灯)使用此处程序
LEDBUZZ:		MOV	T0INTCOUNT,#250
			SETB	GLED
			SETB	RLED
			SETB	BUZZ
			lcall	delay02s
			lcall	delay005s
			MOV	A,LEDBUZZ_MODE
			JNB	ACC.7,LEDBUZZ_R
			JNB	ACC.6,LEDBUZZ_R
			JNB	ACC.5,LEDBUZZ_R
LEDBUZZ_B:		JB	ACC.4,LEDBUZZ_END_JP
			ANL	A,#07H
			MOV 	COUNT0,A
LEDBUZZ_B1:		MOV	A,LEDBUZZ_MODE
			MOV	C,ACC.4
			MOV	BUZZ,C
			MOV	C,ACC.3
			JC	LEDBUZZ_B2
			LCALL	DELAY02S
LEDBUZZ_B2:		LCALL	DELAY005S
			SETB	GLED
			SETB	RLED
			SETB	BUZZ
			JC	LEDBUZZ_B3
			LCALL	DELAY02S
LEDBUZZ_B3:		LCALL	DELAY01S
			DJNZ	COUNT0,LEDBUZZ_B1
			LCALL	DELAY02S
LEDBUZZ_END_JP:		LJMP	LEDBUZZ_END

LEDBUZZ_R:		MOV	T0INTCOUNT,#250
			MOV	A,LEDBUZZ_MODE
			JB	ACC.7,LEDBUZZ_G
			ANL	A,#07H
			MOV 	COUNT0,A
LEDBUZZ_R1:		MOV	A,LEDBUZZ_MODE
			MOV	C,ACC.7
			MOV	RLED,C
			MOV	C,ACC.4
			MOV	BUZZ,C
			MOV	C,ACC.3
			JC	LEDBUZZ_R2
			LCALL	DELAY02S
LEDBUZZ_R2:		LCALL	DELAY005S
			SETB	GLED
			SETB	RLED
			SETB	BUZZ
			JC	LEDBUZZ_R3
			LCALL	DELAY02S
LEDBUZZ_R3:		LCALL	DELAY01S
			DJNZ	COUNT0,LEDBUZZ_R1
			LCALL	DELAY02S

LEDBUZZ_G:		MOV	T0INTCOUNT,#250
			MOV	A,LEDBUZZ_MODE
			JB	ACC.6,LEDBUZZ_Y
			ANL	A,#07H
			MOV 	COUNT0,A
LEDBUZZ_G1:		MOV	A,LEDBUZZ_MODE
			MOV	C,ACC.6
			MOV	GLED,C
			MOV	C,ACC.4
			MOV	BUZZ,C
			MOV	C,ACC.3
			JC	LEDBUZZ_G2
			LCALL	DELAY02S
LEDBUZZ_G2:		LCALL	DELAY005S
			SETB	GLED
			SETB	RLED
			SETB	BUZZ
			JC	LEDBUZZ_G3
			LCALL	DELAY02S
LEDBUZZ_G3:		LCALL	DELAY01S
			DJNZ	COUNT0,LEDBUZZ_G1
			LCALL	DELAY02S

LEDBUZZ_Y:		MOV	T0INTCOUNT,#250
			MOV	A,LEDBUZZ_MODE
			JB	ACC.5,LEDBUZZ_END
			ANL	A,#07H
			MOV 	COUNT0,A
LEDBUZZ_Y1:		MOV	A,LEDBUZZ_MODE
			MOV	C,ACC.5
			MOV	RLED,C
			MOV	GLED,C
			MOV	C,ACC.4
			MOV	BUZZ,C
			MOV	C,ACC.3
			JC	LEDBUZZ_Y2
			LCALL	DELAY02S
LEDBUZZ_Y2:		LCALL	DELAY005S
			SETB	RLED
			SETB	GLED
			SETB	BUZZ
			JC	LEDBUZZ_Y3
			LCALL	DELAY02S
LEDBUZZ_Y3:		LCALL	DELAY01S
			DJNZ	COUNT0,LEDBUZZ_Y1
			LCALL	DELAY02S

LEDBUZZ_END:		RET

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;&&用机械钥匙开锁后一直不松开声光信号
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

LEDBUZZ_TONGUE_SW:	MOV	LEDBUZZ_MODE,#01110001B	;红灯0.5S 1次
			LCALL	LEDBUZZ
			RET

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;&&密码错误(或输密码卡时旧密码核对失败)声光信号
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

LEDBUZZ_MI_MA_ERROR:	MOV	LEDBUZZ_MODE,#01110010B	;红灯0.5S 2次
			LCALL	LEDBUZZ
			RET

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;&&房号错误声光信号
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

LEDBUZZ_FANG_HAO_ERROR:	MOV	LEDBUZZ_MODE,#01110011B	;红灯0.5S 3次
			LCALL	LEDBUZZ
			RET

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;&&锁内24C16读写错误声光信号
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

LEDBUZZ_EEPROM_ERROR:	MOV	LEDBUZZ_MODE,#01110110B	;红灯0.5S 6次
			LCALL	LEDBUZZ
			RET

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;&&机械钥匙开关接通声光信号
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

LEDBUZZ_KEY_SW:		MOV	LEDBUZZ_MODE,#11010001B	;黄灯0.5S 1次
			LCALL	LEDBUZZ
			RET

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;&&锁内24C16数据错误(未被原始卡清过)报警声光信号
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

LEDBUZZ_DATA_ERROR:	MOV	LEDBUZZ_MODE,#11010010B	;黄灯0.5S 2次
                        LCALL	LEDBUZZ
                        RET

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;&&房号卡数据和锁内一样时声光信号
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

LEDBUZZ_FANG_HAO_EQU:	MOV	LEDBUZZ_MODE,#11010011B	;黄灯0.5S 3次
			LCALL	LEDBUZZ
			RET

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;&&关闭声光信号
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

LEDBUZZ_CLOSE:		CLR 	BUZZ
			;CLR	YLED
			CLR	GLED
			CLR	RLED
			LCALL	DELAY02s	        ;黄灯,蜂鸣0.5S 1次
			;SETB	YLED
			SETB	GLED
			SETB	RLED
			SETB 	BUZZ
			RET

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;&&卡片正确开锁开声光信号
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

LEDBUZZ_OPEN:		CLR	GLED			;&*亮绿灯,不关!
			;CLR	BUZZ			;蜂鸣0.5S 1次
			;LCALL	DELAY02S
			;LCALL	DELAY01S
			;SETB 	BUZZ
			RET

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;&&门锁置为常开状态声光信号
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

LEDBUZZ_CHANG_KAI:	MOV	LEDBUZZ_MODE,#11101100B	;蜂鸣0.1S 4次
			LCALL	LEDBUZZ
			RET

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;&&门未关好报警声光信号
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

LEDBUZZ_NOCLOSE:	MOV	T0INTCOUNT,#250
			MOV	R7,#5			;蜂鸣0.1S 5*3次
LBN1:			CLR	TONGUE_SW
			MOV	R6,#3
LBN2:			CLR	BUZZ
			LCALL	DELAY002S
			LCALL	DELAY001S
			SETB	BUZZ
			LCALL	DELAY01S
			DJNZ	R6,LBN2
			MOV	R5,#255
LBN3:			SETB	TONGUE_SW
			LCALL	DELAY5US
			JB	TONGUE_SW,LBN4		;主舌伸出,不再报警,
			CLR	TONGUE_SW
			LCALL	DELAY0001S
			DJNZ	R5,LBN3
			DJNZ	R7,LBN1
LBN4:			CLR	TONGUE_SW
			RET

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;&&卡格式错(即校验错)报警声光信号
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

LEDBUZZ_FORMAT_ERROR:	MOV	LEDBUZZ_MODE,#01010010B	;红灯,黄灯0.5S 2次
                        LCALL	LEDBUZZ
                        RET

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;&&不必或已经授权声光信号
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

LEDBUZZ_NOT_SHOU_QUAN:	MOV	LEDBUZZ_MODE,#01010011B	;红灯,黄灯0.5S 3次
			LCALL	LEDBUZZ
			RET

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;&&不必或已经清除声光信号
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

LEDBUZZ_NOT_QING_CHU:	MOV	LEDBUZZ_MODE,#01010100B	;红灯,黄灯0.5S 4次
			LCALL	LEDBUZZ
			RET

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;&&不必或已经挂失声光信号
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

LEDBUZZ_NOT_GUA_SHI:	MOV	LEDBUZZ_MODE,#01010101B	;红灯,黄灯0.5S 5次
			LCALL	LEDBUZZ
			RET
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;&&装载密码失败(硬件故障)声光信号
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

LEDBUZZ_LOADKEY_ER:	MOV	LEDBUZZ_MODE,#01010110B	;红灯,黄灯0.5S 6次
			LCALL	LEDBUZZ
			RET

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;&&内存已满,不能操作(挂失,授权,开锁等)声光信号
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

LEDBUZZ_NO_BLANK:	MOV	LEDBUZZ_MODE,#01010111B	;红灯,黄灯0.5S 7次
			LCALL	LEDBUZZ
			RET

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;&&8563读写错误声光信号
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
LEDBUZZ_8563_ERROR:	MOV	T0INTCOUNT,#250
			CLR	RLED			;红灯,蜂鸣2S 1次
			CLR	BUZZ
DELAY2:        		MOV 	DCOUNT3,#150
D21:            	LCALL	DELAY001S
                	DJNZ 	DCOUNT3,D21
			SETB	RLED
			SETB	BUZZ
			RET
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;&&门被反锁声光信号
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

LEDBUZZ_BKLK:		MOV	LEDBUZZ_MODE,#01101010B	;红灯,蜂鸣0.1S 2次
			LCALL	LEDBUZZ
			RET

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;&&限期已到声光信号
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

LEDBUZZ_CHECK_TIME0:	MOV	LEDBUZZ_MODE,#01101011B	;红灯,蜂鸣0.1S 3次
			LCALL	LEDBUZZ
			RET

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;&&对号卡已被清除声光信号
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

LEDBUZZ_QING_CHU:	MOV	LEDBUZZ_MODE,#01101100B	;红灯,蜂鸣0.1S 4次
			LCALL	LEDBUZZ
			RET

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;&&卡被挂失作废声光信号
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

LEDBUZZ_GUA_SHI:	MOV	LEDBUZZ_MODE,#01101111B	;红灯,蜂鸣0.1S 7次
			LCALL	LEDBUZZ
			RET

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;&&未到开启时间声光信号(统一为不在开锁时间段)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
LEDBUZZ_JIN_ZHI:
LEDBUZZ_CHECK_TIME1:	MOV	LEDBUZZ_MODE,#11001010B	;黄灯,蜂鸣0.1S 2次
			LCALL	LEDBUZZ
			RET

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;&&超过关闭时间声光信号
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

LEDBUZZ_CHECK_TIME2:	MOV	LEDBUZZ_MODE,#11001011B	;黄灯,蜂鸣0.1S 3次
			LCALL	LEDBUZZ
			RET

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;&&卡被覆盖声光信号
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

LEDBUZZ_FU_GAI:		MOV	LEDBUZZ_MODE,#11001011B	;黄灯,蜂鸣0.1S 3次
			LCALL	LEDBUZZ
			RET

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;&&原始卡,密码卡,房号卡,时间卡,总清卡,授权卡,清除卡,挂失卡,记录卡输入成功声光信号
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

LEDBUZZ_SETUP:		MOV	LEDBUZZ_MODE,#10101010B	;绿灯,蜂鸣0.1S 2次
                        LCALL	LEDBUZZ
                        RET

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;&&程序运行错误声光信号
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

LEDBUZZ_PRG_ERROR:	MOV	LEDBUZZ_MODE,#00000011B	;红灯,绿灯,黄灯,蜂鸣0.5S 3次
			LCALL	LEDBUZZ
			RET

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;&&写记录提取器失败声光信号
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

LEDBUZZ_JI_LU_N2:	MOV	LEDBUZZ_MODE,#01001011B	;红灯,黄灯,蜂鸣0.1S 3次
			LCALL	LEDBUZZ
			RET


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;&&低压报警声光信号
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

LEDBUZZ_LOW_VOL:	MOV	LEDBUZZ_MODE,#11001101B	;黄灯,蜂鸣0.1S 5次
			LCALL	LEDBUZZ
			RET

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;&&低压报警限制次数到声光信号
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

LEDBUZZ_LOW_VOL_OFF:	MOV	LEDBUZZ_MODE,#01101101B	;红灯,蜂鸣0.1S 5次
			LCALL	LEDBUZZ
			RET

;***********************************************************************************************
;;;;读常开标志子程序
;***********************************************************************************************
;RD_CHANGKAI_BYTE:	MOV	HADDR_24C1X,#00H
;			MOV	LADDR_24C1X,#0CH
;			MOV	LENGTH_24C1X,#1
;			LCALL	RD_24C64
;			RET

;***********************************************************************************************
;;;;电机正反转
;***********************************************************************************************

MOT_POSITIVE:		CLR	MOT_CTRL			;正转
			LCALL	DELAY500US
			CLR	MOT_PWR

			LCALL	DELAY01S
			LCALL	DELAY01S
			LCALL	DELAY005S
			SETB	MOT_PWR
			LCALL	DELAY500US

			;MOV	BUFF_BEG_24C1X,#01H	;置常开标志
			;MOV	HADDR_24C1X,#00H
			;MOV	LADDR_24C1X,#0CH
			;MOV	LENGTH_24C1X,#1
			;LCALL	WR_24C64
			RET
;***********************************************************************************************

MOT_REVERSE:		SETB	MOT_CTRL			;反转
			LCALL	DELAY500US
			CLR	MOT_PWR

			LCALL	DELAY01S
			LCALL	DELAY01S
			LCALL	DELAY005S
			SETB	MOT_PWR
			LCALL	DELAY500US

			;MOV	BUFF_BEG_24C1X,#00H		;清常开标志
			;MOV	HADDR_24C1X,#00H
			;MOV	LADDR_24C1X,#0CH
			;MOV	LENGTH_24C1X,#1
			;LCALL	WR_24C64
			;CJNE	A,#OK,MOT_REVERSE_RET
			CLR	CHANG_KAI_FLAG

CNTADD:			MOV	HADDR_24C1X,#00H		;计数加1程序
			MOV	LADDR_24C1X,#25H			;计数器首址
			MOV	LENGTH_24C1X,#3
			LCALL	RD_24C64
			CJNE	A,#OK,MOT_REVERSE_RET

       		  	MOV 	R0,#BUFF_BEG_24C1X+2		;27H即个位,十位
                	MOV 	A,@R0
                	ADD 	A,#1
                	DA 	A
                	MOV 	@R0,A

                	MOV 	R7,#3

CNTADD1:        	DEC 	R0				;DEC,非INC!
                	MOV 	A,@R0
                	ADDC 	A,#0
                	DA 	A
                	MOV 	@R0,A
                	DJNZ 	R7,CNTADD1

			MOV	HADDR_24C1X,#00H
			MOV	LADDR_24C1X,#25H
			MOV	LENGTH_24C1X,#3
			LCALL	WR_24C64

MOT_REVERSE_RET:	RET

;***********************************************************************************************
;;;;核对密码:判断卡的密码是否等于锁内密码
;***********************************************************************************************

CHECK_MI_MA:		MOV	A,BUFF_BEG_24C1X+4
			CJNE	A,BUFF_BEG_MIF+1,CHECK_MI_MA2
			MOV	A,BUFF_BEG_24C1X+5
			CJNE	A,BUFF_BEG_MIF+2,CHECK_MI_MA2
			MOV	A,BUFF_BEG_24C1X+6
			CJNE	A,BUFF_BEG_MIF+3,CHECK_MI_MA2
			MOV	A,BUFF_BEG_24C1X+7
			CJNE	A,BUFF_BEG_MIF+4,CHECK_MI_MA2

			MOV	A,#OK
			RET

CHECK_MI_MA2:		MOV	A,#ERROR
			RET


;***********************************************************************************************
;;;;核对楼号:判断卡的楼号是否等于锁内楼号
;***********************************************************************************************
;
;CHECK_LOU_HAO:		MOV	A,BUFF_BEG_24C1X+8
;			CJNE	A,BUFF_BEG_MIF+5,CHECK_LOU_HAO1
;			MOV	A,#OK
;			RET
;
;CHECK_LOU_HAO1:		MOV	A,#ERROR
;			RET
;
;***********************************************************************************************
;;;;核对层号:判断卡的层号是否等于锁内层号(如为多层卡,还要另外判断)
;***********************************************************************************************
;
;CHECK_CENG_HAO:		MOV	A,BUFF_BEG_24C1X+9
;			CJNE	A,BUFF_BEG_MIF+6,CHECK_CENG_HAO1
;			MOV	A,#OK
;			RET
;
;CHECK_CENG_HAO1:	MOV	A,#ERROR
;			RET
;
;***********************************************************************************************
;;;;核对房号:判断卡的房号是否等于锁内房号
;***********************************************************************************************
;
;CHECK_FANG_HAO:		MOV	A,BUFF_BEG_24C1X+10
;			CJNE	A,BUFF_BEG_MIF+7,CHECK_FANG_HAO1
;			MOV	A,#OK
;			RET
;
;CHECK_FANG_HAO1:	MOV	A,#ERROR
;			RET
;
;***********************************************************************************************
;;;;核对房间号(楼号,层号,房号)
;***********************************************************************************************
;
;CHECK_FANG_JIAN_HAO:	LCALL	CHECK_LOU_HAO
;			CJNE	A,#OK,CHECK_FANG_JIAN_HAO1
;			LCALL	CHECK_CENG_HAO
;			CJNE	A,#OK,CHECK_FANG_JIAN_HAO1
;			LCALL	CHECK_FANG_HAO
;			CJNE	A,#OK,CHECK_FANG_JIAN_HAO1
;			MOV	A,#OK
;			RET
;
;CHECK_FANG_JIAN_HAO1:	MOV	A,#ERROR
;			RET
;***********************************************************************************************
;*****$$$$$
;;;;核对楼层房号(楼号,层号,房号)**房间号专用判断通道类型**
;*****$$$$$

DUEI_HAO_LCF:		ACALL	CHECK_LOU_CENG_FANG		;第一块的第一个楼层房号
			CJNE	A,#ERROR,DUEI_HAO_LCF_RET

			MOV	R7,#2
			MOV	R0,#BUFF_BEG_MIF+26	;第一块的后二个单独的楼层房号
DUEI_HAO_LCF_1:		MOV	R1,#BUFF_BEG_MIF+5	;放在楼层号的位置(BUFF_BEG_MIF+5至7)
			MOV	A,@R0			;换楼号
			MOV	@R1,A
			INC	R0
			INC	R1
			MOV	A,@R0			;换层号
			MOV	@R1,A
			INC	R0
			INC	R1
			MOV	A,@R0			;换房号
			MOV	@R1,A
			INC	R0
			ACALL	CHECK_LOU_CENG_FANG
			CJNE	A,#ERROR,DUEI_HAO_LCF_RET
			DJNZ	R7,DUEI_HAO_LCF_1

DUEI_HAO_LCF_10S:	MOV	R7,#5
			MOV	R0,#LSBUFF_BEG_MIF	;第二块的五个单独的楼层房号
DUEI_HAO_LCF_2:		MOV	R1,#BUFF_BEG_MIF+5	;放在楼层号的位置(BUFF_BEG_MIF+5至7)
			MOV	A,@R0			;换楼号
			MOV	@R1,A
			INC	R0
			INC	R1
			MOV	A,@R0			;换层号
			MOV	@R1,A
			INC	R0
			INC	R1
			MOV	A,@R0			;换房号
			MOV	@R1,A
			INC	R0
			ACALL	CHECK_LOU_CENG_FANG
			CJNE	A,#ERROR,DUEI_HAO_LCF_RET
			DJNZ	R7,DUEI_HAO_LCF_2

DUEI_HAO_LCF_RET:	RET

;$$$$判断房间号
CHECK_LOU_CENG_FANG:	MOV	A,BUFF_BEG_MIF
			CJNE	A,#02H,CHECK_LOU_CENG_FANG_1
			LJMP	CHECK_LOU_CENG_FANG_B	;房号卡
CHECK_LOU_CENG_FANG_1:	CJNE	A,#05H,CHECK_LOU_CENG_FANG_2
			LJMP	CHECK_LOU_CENG_FANG_B	;授权卡
CHECK_LOU_CENG_FANG_2:	CJNE	A,#06H,CHECK_LOU_CENG_FANG_3
			LJMP	CHECK_LOU_CENG_FANG_B	;清除卡
CHECK_LOU_CENG_FANG_3:	CJNE	A,#07H,CHECK_LOU_CENG_FANG_4
			LJMP	CHECK_LOU_CENG_FANG_A	;挂失卡
CHECK_LOU_CENG_FANG_4:	CJNE	A,#0DH,CHECK_LOU_CENG_FANG_ER
							;房间卡
CHECK_LOU_CENG_FANG_A:	MOV	A,BUFF_BEG_24C1X+0BH
			CJNE	A,#03H,CHECK_LOU_CENG_FANG_A1
			LJMP	CHECK_LOU_CENG_FANG_OK	;总通道
CHECK_LOU_CENG_FANG_A1:	CJNE	A,#02H,CHECK_LOU_CENG_FANG_A2
			MOV	A,BUFF_BEG_24C1X+8	;楼通道
			CJNE	A,BUFF_BEG_MIF+5,CHECK_LOU_CENG_FANG_ER
			LJMP	CHECK_LOU_CENG_FANG_OK
CHECK_LOU_CENG_FANG_A2:	CJNE	A,#01H,CHECK_LOU_CENG_FANG_B
			MOV	A,BUFF_BEG_24C1X+8	;层通道
			CJNE	A,BUFF_BEG_MIF+5,CHECK_LOU_CENG_FANG_ER
			MOV	A,BUFF_BEG_24C1X+9
			CJNE	A,BUFF_BEG_MIF+6,CHECK_LOU_CENG_FANG_ER
			LJMP	CHECK_LOU_CENG_FANG_OK

CHECK_LOU_CENG_FANG_B:	MOV	A,BUFF_BEG_24C1X+8	;非通道
			CJNE	A,BUFF_BEG_MIF+5,CHECK_LOU_CENG_FANG_ER
			MOV	A,BUFF_BEG_24C1X+9
			CJNE	A,BUFF_BEG_MIF+6,CHECK_LOU_CENG_FANG_ER
			MOV	A,BUFF_BEG_24C1X+10
			CJNE	A,BUFF_BEG_MIF+7,CHECK_LOU_CENG_FANG_ER
CHECK_LOU_CENG_FANG_OK:	MOV	A,#OK
			RET

CHECK_LOU_CENG_FANG_ER:	MOV	A,#ERROR
			RET

;$$$$判断房间号
KAI_SUO_CHECK_10S:
KAI_SUO_CHECK_10S_1:	LCALL	SELECT_EXTRAM
			MOV 	R0,#LSBUFF_BEG_MIF
                	MOV 	R1,#FJCBUFF_BEG_MIF
                	MOV 	R7,#15
KAI_SUO_CHECK_10S_1_1: 	MOVX 	A,@R1
                	MOV 	@R0,A
                	INC 	R0
                	INC 	R1
                	DJNZ 	R7,KAI_SUO_CHECK_10S_1_1
			LCALL	DUEI_HAO_LCF_10S		;房间卡
			CJNE	A,#ERROR,KAI_SUO_CHECK_10S_RET
KAI_SUO_CHECK_10S_2:	MOV 	R0,#LSBUFF_BEG_MIF
                	MOV 	R1,#FJCBUFF_BEG_MIF+15
                	MOV 	R7,#15
KAI_SUO_CHECK_10S_2_1: 	MOVX 	A,@R1
                	MOV 	@R0,A
                	INC 	R0
                	INC 	R1
                	DJNZ 	R7,KAI_SUO_CHECK_10S_2_1
			LCALL	DUEI_HAO_LCF_10S		;房间卡
			CJNE	A,#ERROR,KAI_SUO_CHECK_10S_RET
KAI_SUO_CHECK_10S_3:	MOV 	R0,#LSBUFF_BEG_MIF
                	MOV 	R1,#FJCBUFF_BEG_MIF+30
                	MOV 	R7,#15
KAI_SUO_CHECK_10S_3_1: 	MOVX 	A,@R1
                	MOV 	@R0,A
                	INC 	R0
                	INC 	R1
                	DJNZ 	R7,KAI_SUO_CHECK_10S_3_1
			LCALL	DUEI_HAO_LCF_10S		;房间卡
			CJNE	A,#ERROR,KAI_SUO_CHECK_10S_RET
KAI_SUO_CHECK_10S_RET:	LCALL	SELECT_MIFRAM
			RET


;***********************************************************************************************
;*****$$$$$
;;;;核对楼层号(楼号,层号)**楼层号专用判断通道类型**
;*****$$$$$

DUEI_HAO_LC:		ACALL	CHECK_LOU_CENG		;第一块的第一个楼层号（始末层）
			CJNE	A,#ERROR,DUEI_HAO_LC_RET

			MOV	R7,#3
			MOV	R0,#BUFF_BEG_MIF+26	;第一块的后三个单独的楼层号
DUEI_HAO_LC_1:		MOV	R1,#BUFF_BEG_MIF+5	;放在楼层号的位置(BUFF_BEG_MIF+5至7)
			MOV	A,@R0			;换楼号
			MOV	@R1,A
			INC	R0
			INC	R1
			MOV	A,@R0			;换启始层号
			MOV	@R1,A
			INC	R1
			MOV	A,@R0			;换末尾层号
			MOV	@R1,A
			INC	R0
			ACALL	CHECK_LOU_CENG
			CJNE	A,#ERROR,DUEI_HAO_LC_RET
			DJNZ	R7,DUEI_HAO_LC_1

			MOV	R7,#8
			MOV	R0,#LSBUFF_BEG_MIF	;第二块的八个单独的楼层号
DUEI_HAO_LC_2:		MOV	R1,#BUFF_BEG_MIF+5	;放在楼层号的位置(BUFF_BEG_MIF+5至7)
			MOV	A,@R0			;换楼号
			MOV	@R1,A
			INC	R0
			INC	R1
			MOV	A,@R0			;换启始层号
			MOV	@R1,A
			INC	R1
			MOV	A,@R0			;换末尾层号
			MOV	@R1,A
			INC	R0
			ACALL	CHECK_LOU_CENG
			CJNE	A,#ERROR,DUEI_HAO_LC_RET
			DJNZ	R7,DUEI_HAO_LC_2

DUEI_HAO_LC_RET:	RET


;$$$$判断楼层
CHECK_LOU_CENG:		MOV	A,BUFF_BEG_24C1X+0BH
			CJNE	A,#03H,CHECK_LOU_CENG_1
			LJMP	CHECK_LOU_CENG_OK	;总通道
CHECK_LOU_CENG_1:	CJNE	A,#02H,CHECK_LOU_CENG_2
			MOV	A,BUFF_BEG_24C1X+8	;楼通道
			CJNE	A,BUFF_BEG_MIF+5,CHECK_LOU_CENG_ER
			LJMP	CHECK_LOU_CENG_OK
CHECK_LOU_CENG_2:	CJNE	A,#01H,CHECK_LOU_CENG_3	;非通道也只判断到楼层
CHECK_LOU_CENG_3:	MOV	A,BUFF_BEG_24C1X+8	;层通道
			CJNE	A,BUFF_BEG_MIF+5,CHECK_LOU_CENG_ER
			MOV	A,BUFF_BEG_24C1X+9
			CJNE	A,BUFF_BEG_MIF+6,CHECK_LOU_CENG_A
			LJMP	CHECK_LOU_CENG_OK
CHECK_LOU_CENG_A:	JC	CHECK_LOU_CENG_ER
			CJNE	A,BUFF_BEG_MIF+7,CHECK_LOU_CENG_A1
			LJMP	CHECK_LOU_CENG_OK
CHECK_LOU_CENG_A1:	JNC	CHECK_LOU_CENG_ER
CHECK_LOU_CENG_OK:	MOV	A,#OK
			RET

CHECK_LOU_CENG_ER:	MOV	A,#ERROR
			RET
;$$$$判断楼层


;***********************************************************************************************
;***********************************************************************************************
;;;;判断开锁卡是否到期,是否在有效时段
;程序执行后返回各种状态:
;CHECK_TIME_STATE0:限期已到
;CHECK_TIME_STATE1:未到有效时分
;CHECK_TIME_STATE2:超过无效时分
;CHECK_TIME_STATE3:有效

;***********************************************************************************************

CHECK_TIME:
                        LCALL   RD_8563
			CJNE	A,#OK,CHECK_TIME3		;如果时钟错误,也算时间有效
                        JB	CHANG_KAI_FLAG,CHECK_TIME3	;判断是否常开状态
CHECK_TIME_ADP:
                        MOV     R0,#BUFF_BEG_MIF+68
                        MOV     R7,#5
CHECK_TIME_ADP_X1:
                        MOV     A,@R0
                        CJNE    A,#0FFH,CHECK_TIME_ADP_X0
                        INC     R0
                        DJNZ    R7,CHECK_TIME_ADP_X1
                        LJMP    CHECK_TIME_ADP_1                            ;若起始时间均为FF，则认为起始时间正常，继续进行无效时间的判定
CHECK_TIME_ADP_X0:
                        CLR     C
                        MOV	R0,#BUFF_BEG_MIF+68                         ;比较起始时间
                        MOV     A,@R0
                        CJNE	A,BUFF_BEG_8563+0,CHECK_TIME_ADP_0          ;年
                        MOV	R0,#BUFF_BEG_MIF+69
                        MOV     A,@R0
                        CJNE	A,BUFF_BEG_8563+1,CHECK_TIME_ADP_0          ;月
                        MOV	R0,#BUFF_BEG_MIF+70
                        MOV     A,@R0
                        CJNE	A,BUFF_BEG_8563+2,CHECK_TIME_ADP_0          ;日
                        MOV	R0,#BUFF_BEG_MIF+71
                        MOV     A,@R0
                        CJNE	A,BUFF_BEG_8563+3,CHECK_TIME_ADP_0          ;时
                        MOV	R0,#BUFF_BEG_MIF+72
                        MOV     A,@R0
                        CJNE	A,BUFF_BEG_8563+4,CHECK_TIME_ADP_0          ;分
                        LJMP    CHECK_TIME_ADP_1                            ;起始时间和当前时间一样，也认为是有效时间，继续进行无效时间的判定
CHECK_TIME_ADP_0:
                        JC      CHECK_TIME_ADP_1                            ;起始时间小于当前时间的，则认为已超过起始时间，允许进行无效时间的判定
                        MOV     A,#CHECK_TIME_STATE1
                        RET
CHECK_TIME_ADP_1:



                	MOV	A,BUFF_BEG_MIF+9		;比较到期时间

                	CJNE	A,BUFF_BEG_8563,CHECK_TIME2	;年

                	MOV	A,BUFF_BEG_MIF+10
                	CJNE	A,BUFF_BEG_8563+1,CHECK_TIME2	;月

                	MOV	A,BUFF_BEG_MIF+11
                	CJNE	A,BUFF_BEG_8563+2,CHECK_TIME2	;日

                	MOV	A,BUFF_BEG_MIF+12
                	CJNE	A,BUFF_BEG_8563+3,CHECK_TIME2	;时

                	MOV	A,BUFF_BEG_MIF+13
                	CJNE	A,BUFF_BEG_8563+4,CHECK_TIME2	;分

CHECK_TIME1:           	MOV	A,#CHECK_TIME_STATE0		;限期已到
                	RET

CHECK_TIME3:		MOV	A,#CHECK_TIME_STATE3		;有效
			RET

CHECK_TIME2:		JC	CHECK_TIME1			;限期未到

CHECK_TIME_NEW:		MOV	COUNT1,#7			;最多7段
			MOV	R0,#BUFF_BEG_MIF+32
			MOV	A,R0
			MOV	R2,A

CTN1:			MOV	A,R0
			MOV	R2,A

			MOV	A,R0
			ADD	A,#2
			MOV	R1,A
			MOV	A,@R1
			MOV	CT_TEMP,A

			MOV	A,@R0
			CJNE	A,#0FFH,CTN2
			MOV	A,#CHECK_TIME_STATE1;ERROR			;碰到FF,完毕
			RET

CTN2:			CJNE	A,CT_TEMP,CTN3
			INC	R0
			INC	R1
			MOV	A,@R1
			MOV	CT_TEMP,A
			MOV	A,@R0
			CJNE	A,CT_TEMP,CTN3
			LJMP	T1_SMLEQU_T2			;T1=<T2,正常班
CTN3:			JC	T1_SMLEQU_T2
			LJMP	T1_LAG_T2			;T1>T2,隔夜班

T1_SMLEQU_T2:		MOV	A,R2				;(T1=<T2,正常班)"有效时分"的时字节
			MOV	R0,A
			MOV	A,@R0				;比较有效时
                	CJNE	A,BUFF_BEG_8563+3,T1_SMLEQU_T2_1;时
                	INC	R0
                	MOV	A,@R0
                	CJNE	A,BUFF_BEG_8563+4,T1_SMLEQU_T2_1;分

T1_SMLEQU_T2_0:		LJMP	T1_SMLEQU_T2_2			;已到(或已过)有效时分,还要比较无效时分

T1_SMLEQU_T2_1:		JC	T1_SMLEQU_T2_0
                	MOV	A,#CHECK_TIME_STATE1		;未到有效时分
                	LJMP	CHTLOOP

T1_SMLEQU_T2_2:		MOV	A,R2
			ADD	A,#2
			MOV	R0,A
                	MOV	A,@R0				;比较无效时分
                	CJNE	A,BUFF_BEG_8563+3,T1_SMLEQU_T2_4;时

                	INC	R0
                	MOV	A,@R0
                	CJNE	A,BUFF_BEG_8563+4,T1_SMLEQU_T2_4;分
                	LJMP	T1_SMLEQU_T2_4

T1_SMLEQU_T2_3:		;MOV	A,#CHECK_TIME_STATE2		;超过无效时分
			MOV	A,#CHECK_TIME_STATE1
			LJMP	CHTLOOP

T1_SMLEQU_T2_4:		JC	T1_SMLEQU_T2_3
			MOV	A,#CHECK_TIME_STATE3		;有效
			LJMP	CHECK_WEEK

T1_LAG_T2:		MOV	A,R2				;(T1>T2,隔夜班)"有效时分"的时字节
			MOV	R0,A
			MOV	A,@R0				;比较有效时
                	CJNE	A,BUFF_BEG_8563+3,T1_LAG_T2_1;时
                	INC	R0
                	MOV	A,@R0
                	CJNE	A,BUFF_BEG_8563+4,T1_LAG_T2_1;分

T1_LAG_T2_0:		MOV	A,#CHECK_TIME_STATE3		;已到(或已过)有效时分,肯定有效(此时肯定未过午夜)
			CLR	FLAG_OUT2359			;清"过午夜标志"
			LJMP	CHECK_WEEK

T1_LAG_T2_1:		JC	T1_LAG_T2_0                	;小于有效时分,还要比较无效时分(可能是第2天了)
T1_LAG_T2_2:		MOV	A,R2
			ADD	A,#2
			MOV	R0,A				;比较无效时分
                	MOV	A,@R0

                	CJNE	A,BUFF_BEG_8563+3,T1_LAG_T2_4;时

                	INC	R0
                	MOV	A,@R0
                	CJNE	A,BUFF_BEG_8563+4,T1_LAG_T2_4;分
                	LJMP	T1_LAG_T2_4

T1_LAG_T2_3:		;MOV	A,#CHECK_TIME_STATE2		;超过无效时分
			MOV	A,#CHECK_TIME_STATE1		;
			LJMP	CHTLOOP

T1_LAG_T2_4:		JC	T1_LAG_T2_3
			MOV	A,#CHECK_TIME_STATE3		;有效
			SETB	FLAG_OUT2359			;置"过午夜标志"
			LJMP	CHECK_WEEK

CHECK_WEEK:		MOV	A,R2
			ADD	A,#4				;星期字节
			MOV	R0,A

			MOV	A,@R0
			MOV	CT_TEMP,A

			MOV	A,BUFF_BEG_8563+6
			JNB	FLAG_OUT2359,CW_1		;有过午夜标志,星期数-1
			DEC	A
			CJNE	A,#0FFH,CW_1
			MOV	A,#6				;星期日-1=FF=星期6

CW_1:			CJNE	A,#6,CW_2
			CLR	A
			SETB	ACC.6
			LJMP	CHECK_WEEK_A

CW_2:			CJNE	A,#5,CW_3
			CLR	A
			SETB	ACC.5
			LJMP	CHECK_WEEK_A

CW_3:			CJNE	A,#4,CW_4
			CLR	A
			SETB	ACC.4
			LJMP	CHECK_WEEK_A

CW_4:			CJNE	A,#3,CW_5
			CLR	A
			SETB	ACC.3
			LJMP	CHECK_WEEK_A

CW_5:			CJNE	A,#2,CW_6
			CLR	A
			SETB	ACC.2
			LJMP	CHECK_WEEK_A

CW_6:			CJNE	A,#1,CW_7
			CLR	A
			SETB	ACC.1
			LJMP	CHECK_WEEK_A

CW_7:			CLR	A
			SETB	ACC.0
			LJMP	CHECK_WEEK_A

CHECK_WEEK_A:		ANL	A,CT_TEMP
			ANL	A,#7FH
			JZ	CHTLOOP
			MOV	A,#CHECK_TIME_STATE3		;有效
			RET

CHTLOOP:		MOV	A,R2
			ADD	A,#5
			MOV	R0,A
			DJNZ	COUNT1,CTN1_JP

			MOV	A,#CHECK_TIME_STATE1;ERROR
			RET

CTN1_JP:		LJMP	CTN1

;**************
CHECK_TIME_JD:       	LCALL   RD_8563
			CJNE	A,#OK,CHECK_TIME_OUT1		;如果时钟错误,也算时间有效

                	MOV	A,BUFF_BEG_MIF+9		;比较到期时间

                	CJNE	A,BUFF_BEG_8563,CHECK_TIME_JD1		;年

                	MOV	A,BUFF_BEG_MIF+10
                	CJNE	A,BUFF_BEG_8563+1,CHECK_TIME_JD1	;月

                	MOV	A,BUFF_BEG_MIF+11
                	CJNE	A,BUFF_BEG_8563+2,CHECK_TIME_JD1	;日

                	MOV	A,BUFF_BEG_MIF+12
                	CJNE	A,BUFF_BEG_8563+3,CHECK_TIME_JD1	;时

                	MOV	A,BUFF_BEG_MIF+13
                	CJNE	A,BUFF_BEG_8563+4,CHECK_TIME_JD1	;分

CHECK_TIME_OUT1:	MOV	A,#CHECK_TIME_STATE0		;限期已到
                	RET

CHECK_TIME_JD1:		JC	CHECK_TIME_OUT1			;限期未到
			MOV	A,BUFF_BEG_MIF
			CJNE	A,#1EH,CHECK_TIME_OUT2
                	LJMP	CHECK_TIME_JD2
CHECK_TIME_OUT2:	MOV	A,#CHECK_TIME_STATE3		;有效
                	RET

CHECK_TIME_JD2:		MOV	A,BUFF_BEG_MIF+26		;比较预订时间
                	CJNE	A,BUFF_BEG_8563+0,CHECK_TIME_JD2_1
                	MOV	A,BUFF_BEG_MIF+27
                	CJNE	A,BUFF_BEG_8563+1,CHECK_TIME_JD2_1
                	MOV	A,BUFF_BEG_MIF+28
                	CJNE	A,BUFF_BEG_8563+2,CHECK_TIME_JD2_1
                	MOV	A,BUFF_BEG_MIF+29
                	CJNE	A,BUFF_BEG_8563+3,CHECK_TIME_JD2_1
                	MOV	A,BUFF_BEG_MIF+30
                	CJNE	A,BUFF_BEG_8563+4,CHECK_TIME_JD2_1
                	LJMP	CHECK_TIME_OUT2
CHECK_TIME_JD2_1:       JC	CHECK_TIME_OUT2
			MOV	A,#CHECK_TIME_STATE1		;未到预订时间
                	RET

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;***********************************************************************************************
;;;;判断覆盖时间,客人卡专用
;***********************************************************************************************
CHECK_IN_TIME_KRK:    	JNB     JD_SPE_FLAG,CHECK_IN_TIME_KRK0X
                        MOV	A,#CH_I_T_STATE0			;一旦特殊房标志置位，表示不用判断覆盖，则直接报相等退出
                	RET
CHECK_IN_TIME_KRK0X:
                        CLR	SPKP_FLAG				;清"锁内批号大于卡的批号标志"
			MOV	HADDR_24C1X,#00H
			MOV	LADDR_24C1X,#58H
			MOV	LENGTH_24C1X,#7
			LCALL	RD_24C64
			CJNE	A,#OK,CHECK_IN_TIME_KRK5

CHECK_IN_TIME_KRK0:	MOV	A,BUFF_BEG_MIF+31			;比较房号1的覆盖批号高字节
                	CJNE	A,BUFF_BEG_24C1X+5,CHECK_IN_TIME_KRK1
                	LJMP	CHECK_IN_TIME_KRK2

CHECK_IN_TIME_KRK1:	JNC	CHECK_IN_TIME_KRK1_1
			SETB	SPKP_FLAG				;置"锁内批号大于卡的批号标志"

CHECK_IN_TIME_KRK1_1:	MOV	A,BUFF_BEG_MIF+26			;批号不等,再比较覆盖时间
                	CJNE	A,BUFF_BEG_24C1X,CHECK_IN_TIME_KRK3	;年

                	MOV	A,BUFF_BEG_MIF+27
                	CJNE	A,BUFF_BEG_24C1X+1,CHECK_IN_TIME_KRK3	;月

                	MOV	A,BUFF_BEG_MIF+28
                	CJNE	A,BUFF_BEG_24C1X+2,CHECK_IN_TIME_KRK3	;日

                	MOV	A,BUFF_BEG_MIF+29
                	CJNE	A,BUFF_BEG_24C1X+3,CHECK_IN_TIME_KRK3	;时

                	MOV	A,BUFF_BEG_MIF+30
                	CJNE	A,BUFF_BEG_24C1X+4,CHECK_IN_TIME_KRK3	;分

CHECK_IN_TIME_KRK1_2:	JB	SPKP_FLAG,CHECK_IN_TIME_KRK4		;锁内批号大于卡的批号,且时间相等:也算覆盖
			LJMP	CHECK_IN_TIME_KRK3			;锁内批号小于卡的批号,且时间相等:按"锁内小于卡"重写原时间和大批号

CHECK_IN_TIME_KRK2:
                        MOV	A,#CH_I_T_STATE0			;相等
                	RET

CHECK_IN_TIME_KRK3:	JC	CHECK_IN_TIME_KRK4
			MOV	BUFF_BEG_24C1X,BUFF_BEG_MIF+26
			MOV	BUFF_BEG_24C1X+1,BUFF_BEG_MIF+27
			MOV	BUFF_BEG_24C1X+2,BUFF_BEG_MIF+28
			MOV	BUFF_BEG_24C1X+3,BUFF_BEG_MIF+29
			MOV	BUFF_BEG_24C1X+4,BUFF_BEG_MIF+30
			MOV	BUFF_BEG_24C1X+5,BUFF_BEG_MIF+31
			MOV	LENGTH_24C1X,#6
			MOV	HADDR_24C1X,#00H
			MOV	LADDR_24C1X,#58H
			LCALL	WR_24C64
			CJNE	A,#OK,CHECK_IN_TIME_KRK5

			MOV	A,#CH_I_T_STATE1			;锁内小于卡
			RET
CHECK_IN_TIME_KRK4:	MOV	A,#CH_I_T_STATE2			;锁内大于卡
			RET
CHECK_IN_TIME_KRK5:	MOV	A,#CH_I_T_STATE3			;24C64读写错误
			RET


;***********************************************************************************************

;PCF8563 子程序

;口线定义:

;SDA_8563		BIT
;SCL_8563		BIT

;标志位定义:

;FLAG_8563		BIT
;ACK_8563		BIT

;内存地址定义:

;BUFF_BEG_8563		EQU				;时钟缓冲区首末址
;BUFF_END_8563		EQU				;从低到高:年月日时分,共5字节,读写共用

;用到2个延时程序:DELAY001S,
;用到A,R7,C

;***********************************************************************************************

START_8563:		SETB	SDA_8563
                	LCALL	DELAY2US

			SETB	SCL_8563
			LCALL	DELAY2US

			CLR	SDA_8563
			LCALL	DELAY2US

			CLR	SCL_8563
			LCALL	DELAY2US
			RET


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

STOP_8563:		CLR	SDA_8563
			LCALL	DELAY2US

			SETB	SCL_8563
			LCALL	DELAY2US

			SETB	SDA_8563
			LCALL	DELAY2US
			RET

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

SENTBYTE:       	MOV     R7, #08H
SENTB:			RLC	A
			MOV	SDA_8563, C
			LCALL	DELAY2US

			SETB	SCL_8563
			LCALL	DELAY2US

			CLR	SCL_8563
                	DJNZ    R7, SENTB
			LCALL	DELAY2US

			SETB	SDA_8563
			LCALL	DELAY2US

			SETB	SCL_8563
			LCALL	DELAY2US

			CLR     ACK_8563
			JNB	SDA_8563,ACKEND
                	SETB    ACK_8563
ACKEND: 		LCALL	DELAY2US

			CLR	SCL_8563
			RET

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

RCVBYTE:		SETB	SDA_8563
                	MOV     R7, #08H

RCV:			CLR	SCL_8563
			LCALL	DELAY2US

			SETB	SCL_8563
			LCALL	DELAY2US

			MOV	C, SDA_8563
			RLC	A
			LCALL	DELAY2US

			DJNZ    R7, RCV
			NOP
			NOP

			CLR	SCL_8563
			LCALL	DELAY2US

			CLR	SDA_8563
			JNB	ACK_8563, SENTACKB
			SETB	SDA_8563
SENTACKB:		LCALL	DELAY2US

			SETB	SCL_8563
			LCALL	DELAY2US

			CLR	SCL_8563
			CLR	ACK_8563
			RET

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

WR_8563:        	MOV     TH0,#15H          	;时钟=24MHZ,机器周期为0.5US
                	MOV     TL0,#0A0H         	;定时(2E16-初值)*0.5EXP-6=0.03S
                	CLR	PWR_24C64
			SETB    SDA_8563
                	CLR     SCL_8563
                	LCALL	DELAY2US
			LCALL	DELAY5US

                	LCALL   START_8563
                	MOV     A, #0A2H
                	LCALL   SENTBYTE
                	JB      ACK_8563, WR_8563_ERROR
                	MOV     A, #02H
                	LCALL   SENTBYTE
                	JB      ACK_8563, WR_8563_ERROR

                	MOV     A,BUFF_BEG_8563+5      ;秒
                	LCALL   SENTBYTE
                	JB      ACK_8563, WR_8563_ERROR

	                MOV     A,BUFF_BEG_8563+4       ;分
        	        LCALL   SENTBYTE
                	JB      ACK_8563, WR_8563_ERROR

                	MOV     A,BUFF_BEG_8563+3       ;时
                	LCALL   SENTBYTE
                	JB      ACK_8563, WR_8563_ERROR

               	 	MOV     A,BUFF_BEG_8563+2       ;日
                	LCALL   SENTBYTE
                	JB      ACK_8563, WR_8563_ERROR

                	MOV     A,BUFF_BEG_8563+6       ;星期
                	LCALL   SENTBYTE
                	JB      ACK_8563, WR_8563_ERROR

                	MOV     A,BUFF_BEG_8563+1       ;月
                	LCALL   SENTBYTE
                	JB      ACK_8563, WR_8563_ERROR

                	MOV     A,BUFF_BEG_8563+0       ;年(低位)
                	LCALL   SENTBYTE
                	JB      ACK_8563, WR_8563_ERROR

                	LCALL   STOP_8563

                	MOV	A,#OK
                	RET

WR_8563_ERROR:    	LCALL	LEDBUZZ_8563_ERROR	;&&时钟读写错误:红灯,蜂鸣2S 1次
			MOV	A,#ERROR
			RET

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

RD_8563:        	MOV     TH0,#15H          	;时钟=24MHZ,机器周期为0.5US
                	MOV     TL0,#0A0H         	;定时(2E16-初值)*0.5EXP-6=0.03S
                	CLR	PWR_24C64
			SETB    SDA_8563
                	CLR     SCL_8563
                	LCALL	DELAY2US
			LCALL	DELAY5US

                	LCALL   START_8563
                	MOV     A, #0A2H
                	LCALL   SENTBYTE
                	JB      ACK_8563, RD_8563_ERROR
                	MOV     A, #02H
                	LCALL   SENTBYTE
                	JB      ACK_8563, RD_8563_ERROR
                	LCALL   START_8563
                	MOV     A, #0A2H
			SETB	ACC.0
                	LCALL   SENTBYTE
                	JB      ACK_8563, RD_8563_ERROR

                	CLR	ACK_8563

                	LCALL   RCVBYTE                 ;秒
                	ANL     A,#7FH
                	MOV     BUFF_BEG_8563+5,A

                	LCALL   RCVBYTE                 ;分
                	ANL     A,#7FH
                	MOV     BUFF_BEG_8563+4,A

                	LCALL   RCVBYTE                 ;时
                	ANL     A,#3FH
                	MOV     BUFF_BEG_8563+3,A

                	LCALL   RCVBYTE                 ;日
                	ANL     A,#3FH
                	MOV     BUFF_BEG_8563+2,A

                	LCALL   RCVBYTE                 ;星期
                	ANL     A,#07H
                	MOV     BUFF_BEG_8563+6,A

                	LCALL   RCVBYTE                 ;月
                	ANL     A,#1FH
                	MOV     BUFF_BEG_8563+1,A

                	SETB    ACK_8563

                	LCALL   RCVBYTE                 ;年
                	MOV     BUFF_BEG_8563+0,A

                      	LCALL   STOP_8563

                	MOV	A,#OK
                	RET

RD_8563_ERROR:     	LCALL	LEDBUZZ_8563_ERROR	;&&时钟读写错误:红灯,蜂鸣2S 1次
			MOV	A,#ERROR
		     	RET

;***********************************************************************************************
CLKOUT_8563:        	MOV	COUNT1,#100
CLKOUT_8563_1:		MOV     TH0,#15H          	;时钟=24MHZ,机器周期为0.5US
                	MOV     TL0,#0A0H         	;定时(2E16-初值)*0.5EXP-6=0.03S
                	CLR	PWR_24C64
			SETB    SDA_8563
                	CLR     SCL_8563
                	LCALL	DELAY2US
                	LCALL	DELAY5US

                	LCALL   START_8563
                	MOV     A, #0A2H
                	LCALL   SENTBYTE
                	JB      ACK_8563, CLKOUT_8563_ERROR
                	MOV     A, #0DH
                	LCALL   SENTBYTE
                	JB      ACK_8563, CLKOUT_8563_ERROR

                	MOV     A,#83H                  ;1Hz
                	LCALL   SENTBYTE
                	JB      ACK_8563, CLKOUT_8563_ERROR

                	LCALL   STOP_8563

                	MOV	A,#OK
                	MOV	COUNT1,#0
                	LJMP    CLKOUTRETURN

CLKOUT_8563_ERROR:    	LCALL   STOP_8563
                	DJNZ	COUNT1,CLKOUT_8563_1
			LCALL	LEDBUZZ_8563_ERROR	;&&时钟读写错误:红灯,蜂鸣2S 1次
			MOV	A,#ERROR

CLKOUTRETURN:		RET
;***********************************************************************************************
CLKOUT_8563_CLEAR:     	MOV	COUNT1,#100
CLKOUT_8563_CLEAR_1:	MOV     TH0,#15H          	;时钟=24MHZ,机器周期为0.5US
                	MOV     TL0,#0A0H         	;定时(2E16-初值)*0.5EXP-6=0.03S
                	CLR	PWR_24C64
			SETB    SDA_8563
                	CLR     SCL_8563
                	LCALL	DELAY2US
                	LCALL	DELAY5US

                	LCALL   START_8563
                	MOV     A, #0A2H
                	LCALL   SENTBYTE
                	JB      ACK_8563, CLKOUT_8563_CLEAR_ERROR
                	MOV     A, #0DH
                	LCALL   SENTBYTE
                	JB      ACK_8563, CLKOUT_8563_CLEAR_ERROR

                	MOV     A,#03H                  ;0Hz
                	LCALL   SENTBYTE
                	JB      ACK_8563, CLKOUT_8563_CLEAR_ERROR

                	LCALL   STOP_8563

                	MOV	A,#OK
                	MOV	COUNT1,#0
                	RET

CLKOUT_8563_CLEAR_ERROR:LCALL   STOP_8563
                	DJNZ	COUNT1,CLKOUT_8563_CLEAR_1
			;LCALL	LEDBUZZ_8563_ERROR	;&&时钟读写错误:红灯,蜂鸣2S 1次
			MOV	A,#ERROR
			RET


	;2011-2040/03	;2011-2040/10
;***********************************************************************************************
XIALING_BEG:		DB	27H,25H,31H,30H,29H,27H,26H,25H,31H,0FFH,0FFH,0FFH,0FFH,0FFH,0FFH
			DB	29H,28H,27H,26H,31H,30H,29H,28H,26H,0FFH,0FFH,0FFH,0FFH,0FFH,0FFH
			DB	25H,31H,30H,28H,27H,26H,25H,30H,29H,0FFH,0FFH,0FFH,0FFH,0FFH,0FFH
			DB	28H,27H,25H

XIALING_END:		DB	30H,28H,27H,26H,25H,30H,29H,28H,27H,0FFH,0FFH,0FFH,0FFH,0FFH,0FFH
			DB	25H,31H,31H,29H,27H,26H,25H,31H,29H,0FFH,0FFH,0FFH,0FFH,0FFH,0FFH
			DB	28H,27H,26H,31H,30H,29H,28H,26H,25H,0FFH,0FFH,0FFH,0FFH,0FFH,0FFH
			DB	31H,30H,28H
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
XIALING_CHECK:
			MOV	A,BUFF_BEG_8563+0
			CJNE	A,#11H,$+3
			JC	XIALING_CHECK_RET
			CJNE	A,#41H,$+3
			JNC	XIALING_CHECK_RET

XIALING_CHECK_1:	MOV	A,BUFF_BEG_8563+1
			CJNE	A,#03H,XIALING_CHECK_2
			MOV	A,BUFF_BEG_8563+0
			CLR	C
			SUBB	A,#11H
			MOV	DPTR,#XIALING_BEG
			MOVC	A,@A+DPTR
			CJNE	A,BUFF_BEG_8563+2,XIALING_CHECK_RET
			MOV	A,BUFF_BEG_8563+3
			CJNE	A,#1,XIALING_CHECK_RET
XIALING_CHECK_YES:	JB	XIALING_FLAG,XIALING_CHECK_RET
			INC	BUFF_BEG_8563+3
			SETB	XIALING_FLAG
			LJMP	XIALING_CHECK_RET

XIALING_CHECK_2:	MOV	A,BUFF_BEG_8563+1
			CJNE	A,#10H,XIALING_CHECK_RET
			MOV	A,BUFF_BEG_8563+0
			CLR	C
			SUBB	A,#11H
			MOV	DPTR,#XIALING_END
			MOVC	A,@A+DPTR
			CJNE	A,BUFF_BEG_8563+2,XIALING_CHECK_RET
			MOV	A,BUFF_BEG_8563+3
			CJNE	A,#1,XIALING_CHECK_RET
XIALING_CHECK_NO:	JNB	XIALING_FLAG,XIALING_CHECK_RET
			DEC	BUFF_BEG_8563+3
			CLR	XIALING_FLAG
			LJMP	XIALING_CHECK_RET

XIALING_CHECK_RET:	RET

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
XIALING_TEST:
			SETB	ET1
			SETB	TR1
			MOV	HADDR_24C1X,#00H
			MOV	LADDR_24C1X,#29H
			MOV	LENGTH_24C1X,#1
			LCALL	RD_24C64
			CJNE	A,#OK,XIALING_TEST_RET_ERR1
			MOV	A,BUFF_BEG_24C1X
			MOV	C,ACC.0
			MOV	F0,C
			MOV	XIALING_FLAG,C

			LCALL	RD_8563
			CJNE	A,#OK,XIALING_TEST_RET_ERR2
			LCALL	XIALING_CHECK
			CLR	A
			MOV	C,XIALING_FLAG
			MOV	ACC.0,C
			MOV	BUFF_BEG_24C1X,A
			MOV	C,F0
			MOV	ACC.0,C
			CJNE	A,BUFF_BEG_24C1X,XIALING_TEST_1
			LJMP	XIALING_TEST_RET_OK

XIALING_TEST_1:		LCALL	WR_8563
			CJNE	A,#OK,XIALING_TEST_RET_ERR2
			MOV	HADDR_24C1X,#00H
			MOV	LADDR_24C1X,#29H
			MOV	LENGTH_24C1X,#1
			LCALL	WR_24C64
			CJNE	A,#OK,XIALING_TEST_RET_ERR1
XIALING_TEST_RET_OK:	MOV	A,#OK
			RET

XIALING_TEST_RET_ERR1:	MOV	A,#ERROR
			RET

XIALING_TEST_RET_ERR2:	MOV	A,#ERROR	;假的好
			RET

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
XIALING_CHECK_CARD:	CLR	XIALING_FLAG
			MOV	A,BUFF_BEG_8563+0
			CJNE	A,#11H,$+3
			JC	XIALING_CHECK_CARD_RET
			CJNE	A,#41H,$+3
			JNC	XIALING_CHECK_CARD_RET

XIALING_CHECK_CARD_1:	MOV	A,BUFF_BEG_8563+1
			CJNE	A,#03H,XIALING_CHECK_CARD_2
			MOV	A,BUFF_BEG_8563+0
			CLR	C
			SUBB	A,#11H
			MOV	DPTR,#XIALING_BEG
			MOVC	A,@A+DPTR
			CJNE	A,BUFF_BEG_8563+2,XIALING_CHECK_CARD_1_2
			MOV	A,BUFF_BEG_8563+3
			CJNE	A,#1,$+3
			JC	XIALING_CHECK_CARD_NO
XIALING_CHECK_CARD_YES:	SETB	XIALING_FLAG
			LJMP	XIALING_CHECK_CARD_RET

XIALING_CHECK_CARD_1_2:	JNC	XIALING_CHECK_CARD_NO
			LJMP	XIALING_CHECK_CARD_YES

XIALING_CHECK_CARD_2:	JC	XIALING_CHECK_CARD_NO
			MOV	A,BUFF_BEG_8563+1
			CJNE	A,#10H,XIALING_CHECK_CARD_3
			MOV	A,BUFF_BEG_8563+0
			CLR	C
			SUBB	A,#11H
			MOV	DPTR,#XIALING_END
			MOVC	A,@A+DPTR
			CJNE	A,BUFF_BEG_8563+2,XIALING_CHECK_CARD_2_2
			MOV	A,BUFF_BEG_8563+3
			CJNE	A,#1,$+3
			JC	XIALING_CHECK_CARD_YES
XIALING_CHECK_CARD_NO:	CLR	XIALING_FLAG
			LJMP	XIALING_CHECK_CARD_RET

XIALING_CHECK_CARD_2_2:	JC	XIALING_CHECK_CARD_NO
			LJMP	XIALING_CHECK_CARD_YES

XIALING_CHECK_CARD_3:	JNC	XIALING_CHECK_CARD_NO
			LJMP	XIALING_CHECK_CARD_YES

XIALING_CHECK_CARD_RET:	LCALL	WR_8563
			CJNE	A,#OK,XIALING_CHECK_CARD_ERR2
			CLR	A
			MOV	C,XIALING_FLAG
			MOV	ACC.0,C
			MOV	BUFF_BEG_24C1X,A
			MOV	HADDR_24C1X,#00H
			MOV	LADDR_24C1X,#29H
			MOV	LENGTH_24C1X,#1
			LCALL	WR_24C64
			CJNE	A,#OK,XIALING_CHECK_CARD_ERR1
XIALING_CHECK_CARD_OK:	MOV	A,#OK
			RET

XIALING_CHECK_CARD_ERR1:MOV	A,#ERROR
			RET

XIALING_CHECK_CARD_ERR2:MOV	A,#ERROR	;假的好
			RET



;***********************************************************************************************
;主板24C64 读/写子程序
;用到A,R0.2.3.4,C
;***********************************************************************************************
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
START_24C64:    	LCALL	DELAY2US

                	SETB    SDA_24C64
                	LCALL	DELAY2US
			SETB    SCL_24C64
                	LCALL	DELAY5US
                	CLR	SDA_24C64
                	LCALL	DELAY5US
                	CLR	SCL_24C64
                	LCALL	DELAY5US
                	RET

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

STOP_24C64:   		LCALL	DELAY2US
			CLR 	SDA_24C64
        		LCALL	DELAY2US
			SETB 	SCL_24C64
        		LCALL	DELAY5US
			SETB 	SDA_24C64
        		LCALL	DELAY5US
			RET

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;WRBIT_24C64:		MOV	SDA_24C64,C
;			LCALL	DELAY2US
;			SETB	SCL_24C64
;			LCALL	DELAY5US
;			CLR	SCL_24C64
;                	LCALL	DELAY5US
;			RET
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;RDBIT_24C64:		SETB	SDA_24C64
;			NOP
;			NOP
;			SETB	SCL_24C64
;			LCALL	DELAY2US
;			LCALL	DELAY2US
;			MOV	C,SDA_24C64
;			CLR	SCL_24C64
;                	LCALL	DELAY2US
;			RET
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

WRBYTE_24C64:		MOV	BITCOUNT_24C1X,#8
WRBYTE_24C64_1:		RLC	A

			;LCALL	WRBIT_24C64
			MOV	SDA_24C64,C
			LCALL	DELAY2US
			SETB	SCL_24C64
			LCALL	DELAY5US
			CLR	SCL_24C64
			LCALL	DELAY2US
			LCALL	DELAY2US

			DJNZ	BITCOUNT_24C1X,WRBYTE_24C64_1
			;LCALL	RDBIT_24C64
			NOP
			SETB	SDA_24C64
			NOP
			SETB	SCL_24C64
			LCALL	DELAY2US
			LCALL	DELAY2US
			MOV	C,SDA_24C64
			NOP
			CLR	SCL_24C64
			LCALL	DELAY2US
			RET

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

RDBYTE_24C64:		MOV	BITCOUNT_24C1X,#8
RDBYTE_24C64_1:		;LCALL	RDBIT_24C64
			NOP
			SETB	SDA_24C64
			NOP
			SETB	SCL_24C64
			LCALL	DELAY2US
			LCALL	DELAY2US
			MOV	C,SDA_24C64
			NOP
			CLR	SCL_24C64
			LCALL	DELAY2US
			NOP
			NOP
			RLC 	A
			DJNZ	BITCOUNT_24C1X,RDBYTE_24C64_1
			MOV	C,ACK_24C1X
			;LCALL	WRBIT_24C64
			MOV	SDA_24C64,C
			LCALL	DELAY2US
			SETB	SCL_24C64
			LCALL	DELAY5US
			CLR	SCL_24C64
			LCALL	DELAY2US
			LCALL	DELAY2US
			RET


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


RD_24C64:              	MOV     T0INTCOUNT,#250
			MOV	WDTCONTER,#00110111B
			MOV     TH0,#15H          	;时钟=24MHZ,机器周期为0.5US
                	MOV     TL0,#0A0H         	;定时(2E16-初值)*0.5EXP-6=0.03S
                	;mov	PWR_24C1X_NUM,#0
			CLR	PWR_24C64
			MOV     R0,#BUFF_BEG_24C1X
                	MOV     R2,HADDR_24C1X
                	MOV     R3,LADDR_24C1X
			MOV     R4,LENGTH_24C1X

RD_24C64_1:		MOV     R_W_COUNT_24C1X_0,#20

RD_24C64_2:           	LCALL   STOP_24C64
                	SETB    SDA_24C64
                	CLR     SCL_24C64
                	LCALL   START_24C64

                	MOV	A,#0A0H				;DEVICE ADDRESS:000
                	LCALL	WRBYTE_24C64
                	JNC     RD_24C64_3
                	DJNZ    R_W_COUNT_24C1X_0,RD_24C64_2
			LJMP	RD_24C64_ERROR

RD_24C64_3:           	MOV     A,R2
                	LCALL   WRBYTE_24C64
                	JNC     RD_24C64_4
                	DJNZ    R_W_COUNT_24C1X_0,RD_24C64_2
                	LJMP	RD_24C64_ERROR

RD_24C64_4:            	MOV     A,R3
                	LCALL   WRBYTE_24C64
                	JNC     RD_24C64_5
                	DJNZ    R_W_COUNT_24C1X_0,RD_24C64_2
                	LJMP	RD_24C64_ERROR

RD_24C64_5:		LCALL   START_24C64
                	MOV     A,#0A1H				;DEVICE ADDRESS:000
                	LCALL   WRBYTE_24C64
                	JNC     RD_24C64_6
                        DJNZ    R_W_COUNT_24C1X_0,RD_24C64_2
                	LJMP    RD_24C64_ERROR

RD_24C64_6:             CLR	ACK_24C1X
			CJNE	R4,#1,RD_24C64_7
			SETB	ACK_24C1X
RD_24C64_7:		LCALL   RDBYTE_24C64
                	MOV	@R0,A
                	INC	R0
                	INC     R3
                	CJNE    R3,#00H,RD_24C64_8	;加1后的地址=00H,说明跨块
                	INC     R2			;因此块数要加1

RD_24C64_8:           	DJNZ    R4,RD_24C64_6
			LCALL	STOP_24C64

                	MOV	HADDR_24C1X,R2		;保存读地址
                	MOV     LADDR_24C1X,R3

			MOV	A,#OK
			LJMP	RD_24C64_RET


RD_24C64_ERROR:		MOV	A,#ERROR

RD_24C64_RET:         	SETB	SDA_24C64
			SETB	SCL_24C64
			CLR	CHANGE_PAGE_FLAG
			;SETB	PWR_24C64
			RET

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

WR_24C64:     		MOV     T0INTCOUNT,#250
			MOV	WDTCONTER,#00110111B
			MOV     TH0,#15H          	;时钟=24MHZ,机器周期为0.5US
                	MOV     TL0,#0A0H         	;定时(2E16-初值)*0.5EXP-6=0.03S
                	MOV	PWR_24C1X_NUM,#4
			CLR	PWR_24C64
                	MOV     R0,#BUFF_BEG_24C1X
                	MOV     R2,HADDR_24C1X
                	MOV     R3,LADDR_24C1X
                	MOV     R4,LENGTH_24C1X

WR_24C64_1:            	MOV     R_W_COUNT_24C1X_0,#20
WR_24C64_2:   		LCALL   STOP_24C64

         		SETB    SDA_24C64
                	CLR     SCL_24C64

			LCALL   START_24C64
                	MOV     A,#0A0H				   ;DEVICE ADDRESS:000
                	LCALL   WRBYTE_24C64
                	JNC	WR_24C64_3
			DJNZ	R_W_COUNT_24C1X_0,WR_24C64_2
			LJMP	WR_24C64_ERROR

WR_24C64_3:            	MOV     A,R2
        	        LCALL   WRBYTE_24C64
                	JNC     WR_24C64_4
	                DJNZ    R_W_COUNT_24C1X_0,WR_24C64_2
        	        LJMP    WR_24C64_ERROR

WR_24C64_4:     	MOV     A,R3
        	        LCALL   WRBYTE_24C64
                	JNC     WR_24C64_5
	                DJNZ    R_W_COUNT_24C1X_0,WR_24C64_2
        	        LJMP    WR_24C64_ERROR

WR_24C64_5:		MOV     A,@R0
                	LCALL   WRBYTE_24C64
                	JNC     WR_24C64_6
                	DJNZ    R_W_COUNT_24C1X_0,WR_24C64_2
                	LJMP    WR_24C64_ERROR

WR_24C64_6:     	INC	R0
			INC	R3
			CJNE	R3,#00H,WR_24C64_7
			INC	R2

WR_24C64_7:		MOV	A,R3
			ANL	A,#1FH				;24C64为32字节一页
			JNZ	WR_24C64_8
			SETB	CHANGE_PAGE_FLAG

WR_24C64_8:     	DJNZ    R4,WR_24C64_9
                	LCALL	STOP_24C64

                	MOV     HADDR_24C1X,R2         		;保存写地址
                	MOV     LADDR_24C1X,R3
		     	MOV	A,#OK
                	LJMP	WR_24C64_RET

WR_24C64_9:		JNB	CHANGE_PAGE_FLAG,WR_24C64_5
			CLR	CHANGE_PAGE_FLAG
			LJMP	WR_24C64_1

WR_24C64_ERROR: 	MOV	A,#ERROR

WR_24C64_RET:   	SETB	SDA_24C64
			SETB	SCL_24C64
			CLR	CHANGE_PAGE_FLAG
			RET

;***********************************************************************************************
;***********************************************************************************************

;从序号区读序号并和自己比较,返回各种状态(放在A)的子程序

;内存地址定义:

;COUNT0              	EQU                    		;比较次数计数器
;BK_HADDR_24C1X		EQU				;调用读24C16以前用来备份其块和地址
;BK_LADDR_24C1X		EQU

;常量定义:

;COMP_STATE0:		EQU	80H			;读24C16出错
;COMP_STATE1:		EQU	81H			;主序号没有和自己相同的
;COMP_STATE2:		EQU	82H			;主序号和自己相同,且副序号也相同
;COMP_STATE3:		EQU	83H			;主序号和自己相同,副序号大于自己
;COMP_STATE4:		EQU	84H			;主序号和自己相同,副序号小于自己但不为0
;COMP_STATE5:		EQU	85H			;主序号和自己相同,副序号为0

;用到A

;***********************************************************************************************

COMP_SN:		MOV	HADDR_24C1X,#10H		;序号区的首块
			MOV	LADDR_24C1X,#60H		;首地址

COMP:			MOV	COUNT0,#4
			MOV	BK_HADDR_24C1X,HADDR_24C1X	;调用读24C16以前备份其块和地址
			MOV	BK_LADDR_24C1X,LADDR_24C1X	;以供改写时使用
			MOV	LENGTH_24C1X,#16
			LCALL	RD_24C64
			CJNE	A,#OK,COMP_JUMP0
			MOV	R0,#BUFF_BEG_24C1X+3

COMP_1:			MOV	A,BUFF_BEG_MIF+20
			CJNE	A,BUFF_BEG_24C1X+2,COMP_NOTEQU

			MOV	A,BUFF_BEG_MIF+19
			CJNE	A,BUFF_BEG_24C1X+1,COMP_NOTEQU

			MOV	A,BUFF_BEG_MIF+18
			CJNE	A,BUFF_BEG_24C1X+0,COMP_NOTEQU

			LJMP	COMP_3_EQU

COMP_NOTEQU:		MOV	A,BK_LADDR_24C1X
			ADD	A,#4
			MOV	BK_LADDR_24C1X,A
			INC	R0
			MOV	BUFF_BEG_24C1X+0,@R0
			INC	R0
			MOV	BUFF_BEG_24C1X+1,@R0
			INC	R0
			MOV	BUFF_BEG_24C1X+2,@R0
			INC	R0
			MOV	BUFF_BEG_24C1X+3,@R0
			DJNZ	COUNT0,COMP_1
			MOV	A,HADDR_24C1X
			CJNE	A,#20H,COMP
			LJMP	COMP_JUMP1			;主序号没有和自己相同的

COMP_3_EQU:		MOV	A,BUFF_BEG_MIF+21
			CJNE	A,BUFF_BEG_24C1X+3,COMP_4_NOTEQU

			LJMP	COMP_JUMP2			;主序号和自己相同,且副序号也相同

COMP_4_NOTEQU:		JC	COMP_JUMP3			;主序号和自己相同,副序号大于自己
			MOV	A,BUFF_BEG_24C1X+3
			CJNE	A,#00H,COMP_JUMP4		;主序号和自己相同,副序号小于自己但不为0
			LJMP	COMP_JUMP5			;主序号和自己相同,且副序号为0

COMP_JUMP0:		MOV	A,#COMP_STATE0			;读24C16出错
			RET

COMP_JUMP1:		MOV	A,#COMP_STATE1
			RET

COMP_JUMP2:		MOV	A,#COMP_STATE2
			RET

COMP_JUMP3:		MOV	A,#COMP_STATE3
			RET

COMP_JUMP4:		MOV	A,#COMP_STATE4
			RET

COMP_JUMP5:		MOV	A,#COMP_STATE5
			RET

;***********************************************************************************************

;从序号区找一个4字节为00的空白区或在自己的主序号位置,把相应的序号填入,返回各种状态(放在A)子程序

;内存地址定义:

;COUNT0              	EQU                    		;查找次数计数器
;BK_HADDR_24C1X		EQU				;调用读24C16以前用来备份其块和地址
;BK_LADDR_24C1X		EQU

;常量定义:

;FIND_BLANK		EQU	00H			;FIND_WR程序在调用时有可能只用到一半
;FIND_ITSELF		EQU	0FFH			;因此设两个标志
;FIND_STATE0:		EQU	80H			;读/写24C16出错
;FIND_STATE1:		EQU	81H			;没找到空位置
;FIND_STATE2:		EQU	82H			;找到空位置,且顺利把自己的序号填入

;用到A

;***********************************************************************************************

FIND_WR:		CJNE	A,#FIND_BLANK,FIND_OK

			MOV	HADDR_24C1X,#10H
			MOV	LADDR_24C1X,#60H

FIND:			MOV	COUNT0,#4
			MOV	BK_HADDR_24C1X,HADDR_24C1X	;调用读24C16以前备份其块和地址
			MOV	BK_LADDR_24C1X,LADDR_24C1X	;以供写入时使用
			MOV	LENGTH_24C1X,#16
			LCALL	RD_24C64
			CJNE	A,#OK,FIND_JUMP0		;24C16读错误
			MOV	R0,#BUFF_BEG_24C1X+3

FIND_1:			MOV	A,BUFF_BEG_24C1X+2
			CJNE	A,#00H,FIND_NOTBLANK

			MOV	A,BUFF_BEG_24C1X+1
			CJNE	A,#00H,FIND_NOTBLANK

			MOV	A,BUFF_BEG_24C1X+0
			CJNE	A,#00H,FIND_NOTBLANK

			LJMP	FIND_OK				;找到空位置

FIND_NOTBLANK:		MOV	A,BK_LADDR_24C1X
			ADD	A,#4
			MOV	BK_LADDR_24C1X,A
			INC	R0
			MOV	BUFF_BEG_24C1X+0,@R0
			INC	R0
			MOV	BUFF_BEG_24C1X+1,@R0
			INC	R0
			MOV	BUFF_BEG_24C1X+2,@R0
			INC	R0
			MOV	BUFF_BEG_24C1X+3,@R0
			DJNZ	COUNT0,FIND_1
			MOV	A,HADDR_24C1X
			CJNE	A,#20H,FIND
			LJMP	FIND_JUMP1			;没有找到空位置


FIND_OK:		MOV	BUFF_BEG_24C1X,BUFF_BEG_MIF+18
			MOV	BUFF_BEG_24C1X+1,BUFF_BEG_MIF+19
			MOV	BUFF_BEG_24C1X+2,BUFF_BEG_MIF+20
			MOV	BUFF_BEG_24C1X+3,BUFF_BEG_MIF+21

			MOV	HADDR_24C1X,BK_HADDR_24C1X
			MOV	LADDR_24C1X,BK_LADDR_24C1X
			MOV	LENGTH_24C1X,#4

			LCALL	WR_24C64
			CJNE	A,#OK,FIND_JUMP0		;24C16写错误
			LJMP	FIND_JUMP2

FIND_JUMP0:		MOV 	A,#FIND_STATE0
			RET

FIND_JUMP1:		MOV 	A,#FIND_STATE1
			RET

FIND_JUMP2:		MOV 	A,#FIND_STATE2
			RET

;***********************************************************************************************
;存储记录,且对开锁卡反写最后4条记录子程序
;但本程序中,仅记录"开锁卡的各种操作,钥匙,门未关好,通讯开锁等",不记录"非开锁卡"等的操作
;存储记录子程序
;入口参数A(卡序号),B(状态)
;***********************************************************************************************

SAVE_REC:		CJNE	A,#CARD,SAVE_REC1
			MOV	BUFF_BEG_24C1X+4,BUFF_BEG_MIF+18;卡片开锁
			MOV	BUFF_BEG_24C1X+5,BUFF_BEG_MIF+19
			MOV	BUFF_BEG_24C1X+6,BUFF_BEG_MIF+20
			MOV	BUFF_BEG_24C1X+7,B
			MOV	A,B
			CJNE	A,#CARD_CHANGKAI,SAVE_REC23
			LCALL	CONSTRINGE_TIME				;压缩时间字节
			MOV	HADDR_24C1X,BK_HADDR_24C1X		;记录`卡片常开`
			MOV	LADDR_24C1X,BK_LADDR_24C1X
			MOV	LENGTH_24C1X,#8
			LCALL	WR_24C64
			CJNE	A,#OK,SAVE_REC8_JP
			LJMP	SAVE_REC7

SAVE_REC8_JP:		LJMP	SAVE_REC8

SAVE_REC1:		MOV	BUFF_BEG_24C1X+4,#0FFH
			MOV	BUFF_BEG_24C1X+5,#0FFH
			MOV	BUFF_BEG_24C1X+6,A
			MOV	BUFF_BEG_24C1X+7,B
			LJMP	SAVE_REC23

SAVE_REC23:		MOV	HADDR_24C1X,#00H
			MOV	LADDR_24C1X,#0EH
			MOV	LENGTH_24C1X,#2
			LCALL	RD_24C64			;读指针
			CJNE	A,#OK,SAVE_REC8_JP

			MOV	DPTR,#476			;如>=500,肯定是受干扰所致
			MOV	A,BUFF_BEG_24C1X
			CJNE	A,DPH,SAVE_REC23_1
			MOV	A,BUFF_BEG_24C1X+1
			CJNE	A,DPL,SAVE_REC23_1

SAVE_REC23_1:		JC	SAVE_REC23_2
			MOV	BUFF_BEG_24C1X,#00H
			MOV	BUFF_BEG_24C1X+1,#00H
			MOV	HADDR_24C1X,#00H
			MOV	LADDR_24C1X,#0EH
			MOV	LENGTH_24C1X,#2
			LCALL	WR_24C64				;所以计数器要改写为0
			CJNE	A,#OK,SAVE_REC8

SAVE_REC23_2:		MOV	R1,BUFF_BEG_24C1X
			MOV	R2,BUFF_BEG_24C1X+1
			MOV	R3,#8					;x8
			LCALL	HEX2MUL1				;无符号2字节乘1字节:(R1R2)*(R3)=(R1R2R3)

			MOV	A,R3
			ADD	A,#20H
			MOV	LADDR_24C1X,A
			MOV	A,R2
			ADDC	A,#01H
			MOV	HADDR_24C1X,A				;计数器x8+记录首地址(0120H):作为本条记录的写入地址

			LCALL	CONSTRINGE_TIME				;压缩时间字节

			MOV	BK_HADDR_24C1X,HADDR_24C1X		;备份记录指针,记录`卡片常开`使用
			MOV	BK_LADDR_24C1X,LADDR_24C1X
			MOV	LENGTH_24C1X,#8
			LCALL	WR_24C64
			CJNE	A,#OK,SAVE_REC8

			MOV	HADDR_24C1X,#00H
			MOV	LADDR_24C1X,#0EH
			MOV	LENGTH_24C1X,#2
			LCALL	RD_24C64				;再读记录计数器
			CJNE	A,#OK,SAVE_REC8

			MOV	A,BUFF_BEG_24C1X+1
			ADD	A,#1
			MOV	BUFF_BEG_24C1X+1,A
			MOV	A,BUFF_BEG_24C1X
			ADDC	A,#0
			MOV	BUFF_BEG_24C1X,A			;+1

			MOV	DPTR,#476				;如>=500,
			MOV	A,BUFF_BEG_24C1X
			CJNE	A,DPH,SAVE_REC23_3
			MOV	A,BUFF_BEG_24C1X+1
			CJNE	A,DPL,SAVE_REC23_3

SAVE_REC23_3:		JC	SAVE_REC23_4
			MOV	BUFF_BEG_24C1X,#00H
			MOV	BUFF_BEG_24C1X+1,#00H			;改为0

SAVE_REC23_4:		MOV	HADDR_24C1X,#00H
			MOV	LADDR_24C1X,#0EH
			MOV	LENGTH_24C1X,#2
			LCALL	WR_24C64				;写回
			CJNE	A,#OK,SAVE_REC8

SAVE_REC7:		JB	CARD_FLAG,SAVE_REC_7_1
			MOV	A,#STATE0				;非卡操作,存储记录后不必反写
			RET

SAVE_REC_7_1:		LCALL	RE_WR					;回写房号,低压计数器,最后操作4条记录等
			RET						;此处RET,A的内容由RE_WR决定

SAVE_REC8:		MOV	A,#STATE1
			RET

;***********************************************************************************************
;回写房号,低压计数器,最后4条操作记录等的子程序
;***********************************************************************************************
RE_WR:			NOP						;

RE_WR_0:		LCALL	SELECT_EXTRAM				;转存80字节
			MOV	R0,#BUFF_BEG_8563			;从BUFF_BEG_24C1X开始
			MOV	R1,#00H					;外存首址
			MOV	R7,#160
RE_WR_0_1:		MOV	A,@R0
			MOVX	@R1,A
			INC	R0
			INC	R1
			DJNZ	R7,RE_WR_0_1
			LCALL	SELECT_MIFRAM				;注:执行本RE_WR程序后,一般马上就是掉电,因此不转存也可

			MOV	HADDR_24C1X,#00H
			MOV	LADDR_24C1X,#0EH
			MOV	LENGTH_24C1X,#2
			LCALL	RD_24C64				;读记录计数器
			CJNE	A,#OK,RE_WR_E1_JP1

			MOV	A,BUFF_BEG_24C1X			;如>=500,肯定是受干扰所致
			CJNE	A,#HIGH(476),RE_WR_1
			MOV	A,BUFF_BEG_24C1X+1
			CJNE	A,#LOW(476),RE_WR_1

RE_WR_1:		JC	RE_WR_2
			MOV	BUFF_BEG_24C1X,#00H			;所以计数器要改写为0
			MOV	BUFF_BEG_24C1X+1,#00H
			MOV	HADDR_24C1X,#00H
			MOV	LADDR_24C1X,#0EH			;000EH
			MOV	LENGTH_24C1X,#2
			LCALL	WR_24C64
			CJNE	A,#OK,RE_WR_E1_JP1
			LJMP	RE_WR_2

RE_WR_2:		MOV	A,BUFF_BEG_24C1X
			JNZ	RE_WR_2_4

			MOV	A,BUFF_BEG_24C1X+1
			CJNE	A,#0,RE_WR_2_1
			LJMP	RE_WR_PR0				;记录地址计数器=0
RE_WR_2_1:		CJNE	A,#1,RE_WR_2_2
			LJMP	RE_WR_PR1				;记录地址计数器=1
RE_WR_2_2:		CJNE	A,#2,RE_WR_2_3
			LJMP	RE_WR_PR2				;记录地址计数器=2
RE_WR_2_3:		CJNE	A,#3,RE_WR_2_4
			LJMP	RE_WR_PR3				;记录地址计数器=3
RE_WR_2_4:		LJMP	RE_WR_PR4				;记录地址计数器>=4

RE_WR_E1_JP1:		LJMP	RE_WR_E1
;;;;;;;;;;

RE_WR_PR0:		MOV	HADDR_24C1X,#0FH			;记录地址计数器=0时
			MOV	LADDR_24C1X,#0E0H
			MOV	LENGTH_24C1X,#16
			LCALL	RD_24C64
			CJNE	A,#OK,RE_WR_E1_JP1

			MOV	R0,#BUFF_BEG_24C1X
			MOV	R1,#BUFF_BEG_RWR
			MOV	R7,#16
RE_WR_PR0_1:		MOV	A,@R0
			MOV	@R1,A
			INC	R0
			INC	R1
			DJNZ	R7,RE_WR_PR0_1

			MOV	HADDR_24C1X,#0FH
			MOV	LADDR_24C1X,#0F0H
			MOV	LENGTH_24C1X,#16
			LCALL	RD_24C64
			CJNE	A,#OK,RE_WR_E1_JP1

			MOV	R0,#BUFF_BEG_24C1X
			MOV	R1,#BUFF_BEG_RWR+16
			MOV	R7,#16
RE_WR_PR0_2:		MOV	A,@R0
			MOV	@R1,A
			INC	R0
			INC	R1
			DJNZ	R7,RE_WR_PR0_2

			LJMP	RE_WR_3
;;;;;;;;;;

RE_WR_PR1:		MOV	HADDR_24C1X,#0FH			;记录地址计数器=1时
			MOV	LADDR_24C1X,#0E8H
			MOV	LENGTH_24C1X,#16
			LCALL	RD_24C64
			CJNE	A,#OK,RE_WR_E1_JP2

			MOV	R0,#BUFF_BEG_24C1X
			MOV	R1,#BUFF_BEG_RWR
			MOV	R7,#16
RE_WR_PR1_1:		MOV	A,@R0
			MOV	@R1,A
			INC	R0
			INC	R1
			DJNZ	R7,RE_WR_PR1_1

			MOV	HADDR_24C1X,#0FH
			MOV	LADDR_24C1X,#0F8H
			MOV	LENGTH_24C1X,#8
			LCALL	RD_24C64
			CJNE	A,#OK,RE_WR_E1_JP2

			MOV	R0,#BUFF_BEG_24C1X
			MOV	R1,#BUFF_BEG_RWR+16
			MOV	R7,#8
RE_WR_PR1_2:		MOV	A,@R0
			MOV	@R1,A
			INC	R0
			INC	R1
			DJNZ	R7,RE_WR_PR1_2

			MOV	HADDR_24C1X,#01H
			MOV	LADDR_24C1X,#20H
			MOV	LENGTH_24C1X,#8
			LCALL	RD_24C64
			CJNE	A,#OK,RE_WR_E1_JP2

			MOV	R0,#BUFF_BEG_24C1X
			MOV	R1,#BUFF_BEG_RWR+24
			MOV	R7,#8
RE_WR_PR1_3:		MOV	A,@R0
			MOV	@R1,A
			INC	R0
			INC	R1
			DJNZ	R7,RE_WR_PR1_3

			LJMP	RE_WR_3

;;;;;;;;;;

RE_WR_PR2:		MOV	HADDR_24C1X,#0FH			;记录地址计数器=2时
			MOV	LADDR_24C1X,#0F0H
			MOV	LENGTH_24C1X,#16
			LCALL	RD_24C64
			CJNE	A,#OK,RE_WR_E1_JP2

			MOV	R0,#BUFF_BEG_24C1X
			MOV	R1,#BUFF_BEG_RWR
			MOV	R7,#16
RE_WR_PR2_1:		MOV	A,@R0
			MOV	@R1,A
			INC	R0
			INC	R1
			DJNZ	R7,RE_WR_PR2_1

			MOV	HADDR_24C1X,#01H
			MOV	LADDR_24C1X,#20H
			MOV	LENGTH_24C1X,#16
			LCALL	RD_24C64
			CJNE	A,#OK,RE_WR_E1_JP2

			MOV	R0,#BUFF_BEG_24C1X
			MOV	R1,#BUFF_BEG_RWR+16
			MOV	R7,#16
RE_WR_PR2_2:		MOV	A,@R0
			MOV	@R1,A
			INC	R0
			INC	R1
			DJNZ	R7,RE_WR_PR2_2

			LJMP	RE_WR_3

RE_WR_E1_JP2:		LJMP	RE_WR_E1
;;;;;;;;;;

RE_WR_PR3:		MOV	HADDR_24C1X,#0FH			;记录地址计数器=3时
			MOV	LADDR_24C1X,#0F8H
			MOV	LENGTH_24C1X,#8
			LCALL	RD_24C64
			CJNE	A,#OK,RE_WR_E1_JP2

			MOV	R0,#BUFF_BEG_24C1X
			MOV	R1,#BUFF_BEG_RWR
			MOV	R7,#8
RE_WR_PR3_1:		MOV	A,@R0
			MOV	@R1,A
			INC	R0
			INC	R1
			DJNZ	R7,RE_WR_PR3_1

			MOV	HADDR_24C1X,#01H
			MOV	LADDR_24C1X,#20H
			MOV	LENGTH_24C1X,#16
			LCALL	RD_24C64
			CJNE	A,#OK,RE_WR_E1_JP2

			MOV	R0,#BUFF_BEG_24C1X
			MOV	R1,#BUFF_BEG_RWR+8
			MOV	R7,#16
RE_WR_PR3_2:		MOV	A,@R0
			MOV	@R1,A
			INC	R0
			INC	R1
			DJNZ	R7,RE_WR_PR3_2

			MOV	HADDR_24C1X,#01H
			MOV	LADDR_24C1X,#30H
			MOV	LENGTH_24C1X,#8
			LCALL	RD_24C64
			CJNE	A,#OK,RE_WR_E1_JP2

			MOV	R0,#BUFF_BEG_24C1X
			MOV	R1,#BUFF_BEG_RWR+24
			MOV	R7,#8
RE_WR_PR3_3:		MOV	A,@R0
			MOV	@R1,A
			INC	R0
			INC	R1
			DJNZ	R7,RE_WR_PR3_3

			LJMP	RE_WR_3

;;;;;;;;;;

RE_WR_PR4:		CLR	C					;记录地址计数器>=4时
			MOV	A,BUFF_BEG_24C1X+1
			SUBB	A,#4
			MOV	R2,A
			MOV	A,BUFF_BEG_24C1X
			SUBB	A,#0					;-4
			MOV	R1,A
			MOV	R3,#8					;x8
			LCALL	HEX2MUL1				;无符号2字节乘1字节:(R1R2)*(R3)=(R1R2R3)

			MOV	A,R3
			ADD	A,#20H
			MOV	LADDR_24C1X,A
			MOV	A,R2
			ADDC	A,#01H
			MOV	HADDR_24C1X,A				;计数器x8+记录首地址(0700H):作为读4条记录的首地址

			MOV	LENGTH_24C1X,#16
			LCALL	RD_24C64
			CJNE	A,#OK,RE_WR_E1_JP3

			MOV	R0,#BUFF_BEG_24C1X			;读16字节
			MOV	R1,#BUFF_BEG_RWR
			MOV	R7,#16
RE_WR_PR4_1:		MOV	A,@R0
			MOV	@R1,A
			INC	R0
			INC	R1
			DJNZ	R7,RE_WR_PR4_1

			MOV	LENGTH_24C1X,#16			;地址顺延,再读16字节
			LCALL	RD_24C64
			CJNE	A,#OK,RE_WR_E1_JP3

			MOV	R0,#BUFF_BEG_24C1X
			MOV	R1,#BUFF_BEG_RWR+16
			MOV	R7,#16
RE_WR_PR4_2:		MOV	A,@R0
			MOV	@R1,A
			INC	R0
			INC	R1
			DJNZ	R7,RE_WR_PR4_2

			LJMP	RE_WR_3
RE_WR_E1_JP3:		LJMP	RE_WR_E1
;;;;;;;;;;;;;;

RE_WR_3:		NOP						;此时4条记录32字节已存在BUFF_BEG_RWR

			MOV	HADDR_24C1X,#00H			;读房号7字节
			MOV	LADDR_24C1X,#08H
			MOV	LENGTH_24C1X,#6
			LCALL	RD_24C64
			CJNE	A,#OK,RE_WR_E1_JP3

			MOV	BUFF_BEG_24C1X+4,BUFF_BEG_24C1X+5
			CLR	A
			MOV	R1,#BUFF_BEG_24C1X+5
			MOV	R7,#11
RE_WR_3_1:		MOV	@R1,A
			INC	R1
			DJNZ	R7,RE_WR_3_1

			MOV	R0,#BUFF_BEG_24C1X
			MOV	R1,#BUFF_BEG_RWR+32
			MOV	R7,#16
RE_WR_3_2:		MOV	A,@R0
			MOV	@R1,A
			INC	R0
			INC	R1
			DJNZ	R7,RE_WR_3_2

RE_WR_4:		MOV	A,#00H					;求校验(BUFF_BEG_RWR的47字节)
			MOV	R0,#BUFF_BEG_RWR
			MOV	R7,#47
RE_WR_4_1:		XRL	A,@R0
			INC	R0
			DJNZ	R7,RE_WR_4_1
			CPL	A
			MOV	R0,#BUFF_BEG_RWR+47
			MOV	@R0,A

                        SETB	RD_RC500
			SETB	WR_RC500

        MOV	T0INTCOUNT,#250
        MOV     COUNT0,#0

RE_WR_5:		MOV     U_SECNR,#9			;反写记录从9扇区开始
                        MOV     U_BLKNR,#36			;绝对块号为36(即9扇区的第0块)
                        MOV	SEC_COUNT,#1			;每卡写1扇区
                        MOV     BLK_COUNT,#3			;每扇区用3块

			MOV	CT_TEMP,#BUFF_BEG_RWR	;读出的24C1X缓冲区数据送卡缓冲区
RE_WR_5_1:		MOV	R0,CT_TEMP
			MOV	R1,#Wr_Buffer
                        MOV	R7,#16
RE_WR_5_2:		MOV	A,@R0
                        MOV	@R1,A
                        INC	R0
                        INC	R1
                        DJNZ	R7,RE_WR_5_2
			MOV	CT_TEMP,R0

RE_WR_6:                MOV	COUNT0,#4				;次数不可太多
RE_WR_6_1:      	mov	count1,#10
			LCALL   WRITE16BYTE
                        CJNE	A,#OK,RE_WR_6_2
                        LJMP	RE_WR_7					;第3行数据(即低压计数器等)写卡成功,无声光信号
RE_WR_6_2:		DJNZ	COUNT0,RE_WR_6_1
RE_WR_6_3:             	LJMP	RE_WR_E2				;写卡失败

RE_WR_7:		INC     U_BLKNR
                        DJNZ    BLK_COUNT,RE_WR_5_1
                        LJMP	RE_WR_OK			;写卡成功

RE_WR_OK:		MOV	B,#STATE0				;回写成功
			LJMP	RE_WR_RET

RE_WR_E1:		MOV	B,#STATE1				;24C64错误
			LJMP	RE_WR_RET

RE_WR_E2:		CLR	RLED					;0.1S红灯
                  	LCALL	DELAY01S
                  	SETB	RLED
                  	;MOV	B,#STATE2				;mifare写卡错误
			MOV	B,#STATE0				;认为回写成功
			LJMP	RE_WR_RET

RE_WR_RET:		LCALL	SELECT_EXTRAM
			MOV	R0,#BUFF_BEG_8563
			MOV	R1,#00H
			MOV	R7,#160
RE_WR_RET_1:		MOVX	A,@R1
			MOV	@R0,A
			INC	R0
			INC	R1
			DJNZ	R7,RE_WR_RET_1
			LCALL	SELECT_MIFRAM				;转存的80字节写回原处,恢复现场
			MOV	A,B
			RET


;***********************************************************************************************
;***********************************************************************************************
;无符号2字节乘1字节:(R1R2)*(R3)=(R1R2R3)
;***********************************************************************************************
HEX2MUL1:		MOV	A,R2
			MOV	B,R3
			MUL	AB
			XCH	A,R3
			MOV	R2,B
			MOV	B,R1
			MUL	AB
			ADD	A,R2
			MOV	R2,A
			CLR	A
			ADDC	A,B
			MOV	R1,A
			RET
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
CONSTRINGE_TIME:	MOV	A,BUFF_BEG_8563				;年(MAX=63)
			LCALL	BCDTOHEX
			RL	A
			RL	A
			ANL	A,#11111100B
			MOV	R7,A
			MOV	A,BUFF_BEG_8563+1			;月
			LCALL	BCDTOHEX
			RR	A
			RR	A
			ANL	A,#00000011B
			ORL	A,R7
			MOV	BUFF_BEG_24C1X+0,A			;

			MOV	A,BUFF_BEG_8563+1			;月
			LCALL	BCDTOHEX
			RL	A
			RL	A
			RL	A
			RL	A
			RL	A
			RL	A
			ANL	A,#11000000B
			MOV	R7,A
			MOV	A,BUFF_BEG_8563+2			;日
			LCALL	BCDTOHEX
			RL	A
			ANL	A,#00111110B
			ORL	A,R7
			MOV	R7,A
			MOV	A,BUFF_BEG_8563+3			;时
			LCALL	BCDTOHEX
			RR	A
			RR	A
			RR	A
			RR	A
			ANL	A,#00000001B
			ORL	A,R7
			MOV	BUFF_BEG_24C1X+1,A


			MOV	A,BUFF_BEG_8563+3			;时
			LCALL	BCDTOHEX
			RL	A
			RL	A
			RL	A
			RL	A
			ANL	A,#11110000B
			MOV	R7,A
			MOV	A,BUFF_BEG_8563+4			;分
			LCALL	BCDTOHEX
			RR	A
			RR	A
			ANL	A,#00001111B
			ORL	A,R7
			MOV	BUFF_BEG_24C1X+2,A			;

			MOV	A,BUFF_BEG_8563+4			;分
			LCALL	BCDTOHEX
			RL	A
			RL	A
			RL	A
			RL	A
			RL	A
			RL	A
			ANL	A,#11000000B
			MOV	R7,A
			MOV	A,BUFF_BEG_8563+5			;秒
			LCALL	BCDTOHEX
			ORL	A,R7
			MOV	BUFF_BEG_24C1X+3,A			;
			RET

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
BCDTOHEX:		MOV	R6,A
			ANL	A,#11110000B
			SWAP	A
			MOV	B,#10
			MUL	AB
			MOV	B,A
			MOV	A,R6
			ANL	A,#00001111B
			ADD	A,B
			RET

HEXTOBCD:		MOV	B,#10
			DIV	AB
			SWAP	A
			ORL	A,B
			RET

;***********************************************************************************************
;;;;mifare子程序;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;***********************************************************************************************
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;***********************************************************************************************

;写记录卡程序:规定每张记录卡从1扇区的0块(即绝对4块)开始,到15扇区的3块(即绝对62块),共15*3*16=720字节
;调用本程序的入口为24C64中被复制的数据的起始块和地址

;内存地址定义:
;SEC_COUNT						;扇区计数器
;BLK_COUNT						;每扇区用3块计数器
;COUNT0              	                    		;写次数计数器

;常量定义:
;WRJL_STATE1						;写卡失败
;WRJL_STATE2						;写卡成功
;WRJL_STATE0						;24C1X读写错误
;用到A,R0,1,7

;***********************************************************************************************
WRITE_JI_LU_CARD:       MOV     U_SECNR,#1			;写记录卡从1扇区开始
                        MOV     U_BLKNR,#4			;绝对块号为4(即1扇区的第0块)
                        MOV	SEC_COUNT,#15			;每卡写15扇区
                        MOV     BLK_COUNT,#3			;每扇区用3块
			MOV	TBLK_COUNT,#45			;一共45块(在整扇区一写时,此变量其实多余)

WRITE_JI_LU_CARD1:      NOP					;注:此处也可调用
			;CPL	YLED				;闪黄灯
                        CPL	RLED
                        CPL	GLED
                        MOV	LENGTH_24C1X,#16

		        LCALL	RD_24C64
		        CJNE	A,#OK,WRITE_JI_LU_CARD6

                        MOV	R0,#BUFF_BEG_24C1X		;读出的24C1X缓冲区数据送卡缓冲区
                        MOV	R1,#Wr_Buffer
                        MOV	R7,#16
WRITE_JI_LU_CARD2:      MOV	A,@R0
                        MOV	@R1,A
                        INC	R0
                        INC	R1
                        DJNZ	R7,WRITE_JI_LU_CARD2

			JNB	CHRP_FLAG,WRITE_JI_LU_CARD2_1	;将记录计数器"假写"为0000
			CLR	CHRP_FLAG			;注:本程序中,记录计数器刚好位于第1行,才可这样做
			MOV	R1,#Wr_Buffer+14
			MOV	@R1,#00H
			INC	R1
			MOV	@R1,#00H
                        SETB	RD_RC500
	                SETB	WR_RC500
                        MOV	T0INTCOUNT,#250

WRITE_JI_LU_CARD2_1:    MOV	COUNT0,#10
WRITE_JI_LU_CARD3:      mov	count1,#10
			LCALL   WRITE16BYTE
                        CJNE	A,#OK,WRITE_JI_LU_CARD4
                        LJMP	WRITE_JI_LU_CARD5
WRITE_JI_LU_CARD4:	DJNZ	COUNT0,WRITE_JI_LU_CARD3
                  	MOV	A,#WRJL_STATE1			;写卡失败
                  	RET

WRITE_JI_LU_CARD5:      INC     U_BLKNR
                        DJNZ	TBLK_COUNT,WRITE_JI_LU_CARD5_1	;查总块数(在整扇区一写时,此变量其实多余)
                    	LJMP	WRITE_JI_LU_CARD5_2

WRITE_JI_LU_CARD5_1:    DJNZ    BLK_COUNT,WRITE_JI_LU_CARD1
                        MOV     BLK_COUNT,#3
                        INC     U_BLKNR
                        INC     U_SECNR
                        DJNZ    SEC_COUNT,WRITE_JI_LU_CARD1

WRITE_JI_LU_CARD5_2:    ;SETB    YLED
			SETB	RLED
			SETB	GLED
			MOV     A,#WRJL_STATE2			;写卡成功
                        RET

WRITE_JI_LU_CARD6:      MOV     A,#WRJL_STATE0			;24C64读写错误
                        RET

WRITE16BYTE:    	SETB	RD_RC500
	                SETB	WR_RC500
                        MOV	T0INTCOUNT,#250
                        LCALL	mifscard_1
			CJNE	A,#ERROR,WRITE16BYTE_1
			LJMP	WRITE16BYTE_ER

WRITE16BYTE_1:		LCALL	MIF_ANTICOLL
			CJNE	A,#OK,WRITE16BYTE_ER
			LCALL   SELECT_CARD
			CJNE	A,#OK,WRITE16BYTE_ER
			LCALL   LOAD_KEYE2
			CJNE	A,#OK,WRITE16BYTE_ER
			LCALL   AUTHENTICATION
			CJNE	A,#OK,WRITE16BYTE_ER
			LCALL   MIF_WRITE
			CJNE	A,#OK,WRITE16BYTE_ER
			RET
WRITE16BYTE_ER:		MOV	A,#ERROR
			RET

;***********************************************************************************************
CLEAR_CARD:		MOV     U_SECNR,#7			;写记录卡从1扇区开始
                        MOV     U_BLKNR,#28			;绝对块号为4(即1扇区的第0块)
                        MOV	SEC_COUNT,#1			;每卡写15扇区
                        MOV     BLK_COUNT,#3			;每扇区用3块

CLEAR_CARD1:     	 NOP					;注:此处也可调用
			;CPL	YLED				;闪黄灯
                        CPL	RLED
                        CPL	GLED

                        MOV	R1,#Wr_Buffer
                        MOV	R7,#16
CLEAR_CARD2:     	MOV	A,#00H
                        MOV	@R1,A
                        INC	R1
                        DJNZ	R7,CLEAR_CARD2

			MOV	COUNT0,#10
CLEAR_CARD3:      	MOV	count1,#10
			LCALL   WRITE16BYTE
                        CJNE	A,#OK,CLEAR_CARD4
                        LJMP	CLEAR_CARD5
CLEAR_CARD4:		DJNZ	COUNT0,CLEAR_CARD3
                  	MOV	A,#WRJL_STATE1			;写卡失败
                  	RET

CLEAR_CARD5:      	INC     U_BLKNR
                        DJNZ    BLK_COUNT,CLEAR_CARD1

                        ;SETB    YLED
			SETB	RLED
			SETB	GLED
			MOV     A,#WRJL_STATE2			;写卡成功
                        RET

;***********************************************************************************************
;***********************************************************************************************

;***********************************************************************************************
; /*名称:mifscard_1
; /*功能:寻卡
; /*入口:COUNT1:执行次数
; /*出口:A:OK/ERROR
;***********************************************************************************************
mifscard_1:		;mov	count1,#1			;调用时传入
                        ;MOV	p0,#0FFh
			;SETB	RD_RC500
			;SETB	WR_RC500
			;SETB	INT_RC500
			LCALL	SELECT_MIFRAM

			MOV  	R1,#As_Buffer
			MOV	@R1,#0FFH
			INC	R1
			MOV	@R1,#0FFH

mifscard_1_1:		LCALL	INIT_1702
			CJNE	A,#OK,mifscard_1_ERR

                        ;LCALL   MIF_HALT
                        ;CJNE	A,#OK,mifscard_1_ERR

                        LCALL   DELAY500US
                        ;LCALL   DELAY500US
                        ;LCALL   DELAY500US
                        ;LCALL   DELAY500US
                        ;LCALL   DELAY500US
                        ;LCALL   DELAY500US

mifscard_1_2:		LCALL	MIF_REQUEST			;MIF_REQUEST中已判断0400H
			CJNE	A,#OK,mifscard_1_ERR
			RET

mifscard_1_ERR:		DJNZ	COUNT1,mifscard_1_1
			MOV	A,#ERROR
			SETB	RST_RC500
			MOV	P0,#00H
			;CLR	INT_RC500
			CLR	WR_RC500
			CLR	RD_RC500
			RET
;***********************************************************************************************
; /*名称:INIT_1702
; /*功能:初始化FM1702SL
; /*入口:TEST_1702SL
; /*出口:A:OK/ERROR
;***********************************************************************************************
INIT_1702:		LCALL   DELAY100US
			LCALL   DELAY100US
			LCALL   DELAY100US
			MOV     R2,#4
			JB	TEST_1702SL,INIT_1702_1	;为测试卡时加的
			SETB    RST_RC500
			LCALL   DELAY500US
			CLR     RST_RC500
			LCALL   DELAY500US
INIT_1702_0:		MOV     R2,#250

INIT_1702_1:            MOV	R0,#Command
			MOVX 	A,@R0
        		JZ      INIT_1702_S1
			DJNZ    R2,INIT_1702_1
			MOV     A,#ERROR
			RET

INIT_1702_S1:   	MOV     R0,#Page_Sel
        		MOV     A,#00H
        		MOVX 	@R0,A

        		;MOV     R7,#TimerClock
        		;MOV     R5,#0BH
        		;LCALL   MIF_SPIWRITE
        		;
        		;MOV     R7,#TimerControl
        		;MOV     R5,#02H
        		;LCALL   MIF_SPIWRITE
        		;
        		;MOV     R7,#TimerReload
        		;MOV     R5,#42H
        		;LCALL   MIF_SPIWRITE
        		;
        		;MOV     R7,#InterruptEn
        		;MOV     R5,#7FH
        		;LCALL   MIF_SPIWRITE
        		;
			;MOV     R7,#Int_Req
        		;MOV     R5,#7FH
        		;LCALL   MIF_SPIWRITE
        		;
        		;MOV     R7,#MFOUTSelect
        		;MOV     R5,#02H
        		;LCALL   MIF_SPIWRITE

        		MOV     R0,#TxControl
        		MOV     A,#5BH
        		MOVX 	@R0,A

        		MOV     R0,#RxControl2
        		MOV     A,#01H
        		MOVX 	@R0,A

        		;MOV     R7,#RxWait
        		;MOV     R5,#05H
        		;LCALL   MIF_SPIWRITE

        		MOV     A,#OK
			RET

;***********************************************************************************************
; /*名称:MIF_HALT
; /*功能:暂停MIFARE卡  (本程序没用到)
; /*入口:
; /*出口:A:OK/ERROR/或各种错误标志
;***********************************************************************************************
MIF_HALT:      		MOV     R0,#As_Buffer
        		MOV     @R0,#RF_CMD_HALT
        		MOV     A,#00H
        		INC     R0
        		MOV     @R0,A

        		MOV     CMDSEND_COMD,#Transmit
        		MOV     CMDSEND_LENG,#2
        		LCALL   COMMAND_SEND
        		CJNE    A,#OK,MIF_HALT_1
        		RET

MIF_HALT_1:     	JB	TEST_1702SL,MIF_HALT_ERR3	;为测试卡时加的
			MOV     R0,#ErrorFlag
        		MOVX    A,@R0
        		JB      ACC.1,MIF_HALT_ERR1
        		JB      ACC.2,MIF_HALT_ERR2
        		MOV     A,#FM1702_NOTAGERR
        		RET
MIF_HALT_ERR1: 		MOV     A,#FM1702_PARITYERR
        		RET
MIF_HALT_ERR2:  	MOV     A,#FM1702_FRAMINGERR
        		RET
MIF_HALT_ERR3:  	MOV     A,#ERROR
        		RET
;***********************************************************************************************
; /*名称:MIF_REQUEST
; /*功能:实现FM1702SL向空间发送MIF_REQUEST信号
; /*入口:
; /*出口:A:OK/ERROR/或各种错误标志
;***********************************************************************************************
MIF_REQUEST:		MOV     R0,#Bit_Frame
			MOV     A,#07H
			MOVX 	@R0,A

			MOV     R0,#Control
			MOVX 	A,@R0
			ANL     A,#0F7H

			MOV     R0,#Control
			MOVX 	@R0,A

			MOV     R0,#As_Buffer
			MOV     A,#RF_CMD_MIF_REQUEST_ALL
			MOV     @R0,A
			MOV     CMDSEND_COMD,#Transceive
			MOV     CMDSEND_LENG,#1
			LCALL   COMMAND_SEND
			CJNE    A,#OK,MIF_REQUEST_ERR

                        MOV  	R1,#As_Buffer
			MOV	@R1,#0FFH
			INC	R1
			MOV	@R1,#0FFH			;清2字节,也可不用

        		LCALL   READ_FIFO

        		;MOV     R0,#As_Buffer+01H
        		;MOV     A,@R0
        		;CJNE	A,#00H,MIF_REQUEST_ERR

        		MOV     R0,#As_Buffer
        		MOV     A,@R0
                        CJNE	A,#44H,MIF_REQUEST_0
        		LJMP	MIF_REQUEST_OK
MIF_REQUEST_0:          CJNE	A,#02H,MIF_REQUEST_1
        		LJMP	MIF_REQUEST_OK
MIF_REQUEST_1:		CJNE	A,#04H,MIF_REQUEST_2
        		LJMP	MIF_REQUEST_OK
MIF_REQUEST_2:		CJNE	A,#05H,MIF_REQUEST_3
        		LJMP	MIF_REQUEST_OK
MIF_REQUEST_3:		CJNE	A,#53H,MIF_REQUEST_4
        		LJMP	MIF_REQUEST_OK
MIF_REQUEST_4:		CJNE	A,#03H,MIF_REQUEST_5
        		LJMP	MIF_REQUEST_OK
MIF_REQUEST_5:	        CJNE	A,#08H,MIF_REQUEST_ERR
			LJMP	MIF_REQUEST_2
MIF_REQUEST_OK:		MOV     A,#OK				;0400H表示寻卡正确(M1卡,其余都认为错)
        		RET

MIF_REQUEST_ERR:	MOV     A,#FM1702_NOTAGERR
        		RET

;***********************************************************************************************
; /*名称:MIF_ANTICOLL
; /*功能:防碰撞
; /*入口:
; /*出口:A:OK/ERROR/或各种错误标志,UID_Buffer(5字节SNR)
;***********************************************************************************************
MIF_ANTICOLL:		MOV     R0,#CRCPresetLSB
        		MOV     A,#63H
        		MOVX 	@R0,A

        		MOV     R0,#CWConductance
        		MOV     A,#3FH
        		MOVX 	@R0,A

        		MOV     R0,#ChannelRedundancy
        		MOV     A,#03H
        		MOVX 	@R0,A

        		MOV     R0,#As_Buffer
        		MOV     A,#RF_CMD_ANTICOL
        		MOV     @R0,A
        		INC     R0
        		MOV     @R0,#20H

        		MOV     CMDSEND_COMD,#Transceive
        		MOV     CMDSEND_LENG,#2
        		LCALL   COMMAND_SEND
			CJNE    A,#OK,MIF_ANTICOLL_ERR1

        		MOV     R0,#FIFO_Length
        		MOVX 	A,@R0
        		CJNE	A,#5,MIF_ANTICOLL_ERR2		;非5字节,直接报错

        		LCALL   READ_FIFO

SAVE_UID:		MOV     R7,#5				;保存卡片收到的序列号
        		MOV     R0,#As_Buffer
        		MOV     R1,#UID_Buffer
SAVE_UID_1:		MOV     A,@R0
        		MOV     @R1,A
        		INC     R0
        		INC     R1
        		DJNZ    R7,SAVE_UID_1

        		MOV     R0,#ErrorFlag
        		MOVX 	A,@R0
        		ANL     A,#1
        		JNZ     MIF_ANTICOLL_ERR0

MIF_ANTICOLL_1:	        MOV     R0,#UID_Buffer			;Check_UID
        		MOV     R7,#5
        		MOV     A,#00H
MIF_ANTICOLL_1_1:	XRL     A,@R0
        		INC     R0
        		DJNZ    R7,MIF_ANTICOLL_1_1
        		JNZ     MIF_ANTICOLL_1_1
        		MOV     A,#OK
        		RET

MIF_ANTICOLL_ERR0:	MOV     A,#ERROR
        		RET
MIF_ANTICOLL_ERR1:	MOV     A,#FM1702_NOTAGERR
        		RET
MIF_ANTICOLL_ERR2:	MOV     A,#FM1702_BYTECOUNTERR
        		RET
MIF_ANTICOLL_ERR3:	MOV     A,#FM1702_SERNRERR
        	        RET
MIF_ANTICOLL_DESFIRE:   MOV     R0,#CRCPresetLSB
        		MOV     A,#63H
        		MOVX 	@R0,A

        		MOV     R0,#CWConductance
        		MOV     A,#3FH
        		MOVX 	@R0,A

        		MOV     R0,#ChannelRedundancy
        		MOV     A,#03H
        		MOVX 	@R0,A

        		MOV     R0,#As_Buffer
        		MOV     A,#RF_CMD_ANTICOL_DES
        		MOV     @R0,A
        		INC     R0
        		MOV     @R0,#20H

        		MOV     CMDSEND_COMD,#Transceive
        		MOV     CMDSEND_LENG,#2
        		LCALL   COMMAND_SEND
			CJNE    A,#OK,MIF_ANTICOLL_D_ERR1

        		MOV     R0,#FIFO_Length
        		MOVX 	A,@R0
        		CJNE	A,#5,MIF_ANTICOLL_D_ERR2		;非5字节,直接报错

        		LCALL   READ_FIFO

SAVE_UID_D:		MOV     R7,#5				;保存卡片收到的序列号
        		MOV     R0,#As_Buffer
        		MOV     R1,#UID_Buffer
SAVE_UID_D_1:		MOV     A,@R0
        		MOV     @R1,A
        		INC     R0
        		INC     R1
        		DJNZ    R7,SAVE_UID_D_1

        		MOV     R0,#ErrorFlag
        		MOVX 	A,@R0
        		ANL     A,#1
        		JNZ     MIF_ANTICOLL_D_ERR0

MIF_ANTICOLL_D_1:	MOV     R0,#UID_Buffer			;Check_UID
        		MOV     R7,#5
        		MOV     A,#00H
MIF_ANTICOLL_D_1_1:	XRL     A,@R0
        		INC     R0
        		DJNZ    R7,MIF_ANTICOLL_D_1_1
        		JNZ     MIF_ANTICOLL_D_1_1
        		MOV     A,#OK
        		RET

MIF_ANTICOLL_D_ERR0:	MOV     A,#ERROR
        		RET
MIF_ANTICOLL_D_ERR1:	MOV     A,#FM1702_NOTAGERR
        		RET
MIF_ANTICOLL_D_ERR2:	MOV     A,#FM1702_BYTECOUNTERR
        		RET
MIF_ANTICOLL_D_ERR3:	MOV     A,#FM1702_SERNRERR
        	        RET
;***********************************************************************************************
; /*名称:SELECT_CARD
; /*功能:对放入FM1702操作范围之内的某张卡片进行选择
; /*入口:UID_Buffer(5字节SNR)
; /*出口:A:OK/ERROR/或各种错误标志
;***********************************************************************************************
SELECT_CARD:		MOV     R0,#CRCPresetLSB
        		MOV     A,#63H
        		MOVX 	@R0,A

        		MOV     R0,#CWConductance
        		MOV     A,#3FH
        		MOVX 	@R0,A

        		MOV     R0,#ChannelRedundancy
        		MOV     A,#0FH
        		MOVX 	@R0,A

        		MOV     R0,#As_Buffer
        		MOV     A,#RF_CMD_SELECT
        		MOV     @R0,A
        		INC     R0
        		MOV     @R0,#70H
        		INC     R0
        		MOV     R1,#UID_Buffer
        		MOV     R7,#5
SELECTCARD_LOOP:	MOV     A,@R1
        		MOV     @R0,A
        		INC     R0
        		INC     R1
        		DJNZ    R7,SELECTCARD_LOOP

        		MOV     CMDSEND_COMD,#Transceive
        		MOV     CMDSEND_LENG,#7
        		LCALL   COMMAND_SEND
        		CJNE    A,#OK,SELECTCARD_ERR1

        		MOV     R0,#ErrorFlag
        		MOVX 	A,@R0

        		JB      ACC.1,SELECTCARD_ERR2
        		JB      ACC.2,SELECTCARD_ERR3
        		JB      ACC.3,SELECTCARD_ERR4

        		MOV     R0,#FIFO_Length
        		MOVX 	A,@R0
        		ANL     A,#1
        		JZ      SELECTCARD_ERR5

        		LCALL   READ_FIFO

        		MOV     R0,#As_Buffer
        		MOV     A,@R0
        		CJNE    A,#24H,SELECTCARD_0
        		MOV     A,#OK
        		RET
SELECTCARD_0:           CJNE    A,#18H,SELECTCARD_1
        		MOV     A,#OK
        		RET
SELECTCARD_1:		CJNE    A,#08H,SELECTCARD_2
        		MOV     A,#OK
        		RET
SELECTCARD_2:		CJNE    A,#88H,SELECTCARD_3
        		MOV     A,#OK
        		RET
SELECTCARD_3:		CJNE    A,#0AH,SELECTCARD_4
        		MOV     A,#OK
        		RET
SELECTCARD_4:		CJNE    A,#20H,SELECTCARD_5
        		MOV     A,#OK
        		RET
SELECTCARD_5:		CJNE    A,#28H,SELECTCARD_6
        		MOV     A,#OK
        		RET
SELECTCARD_6:		CJNE    A,#53H,SELECTCARD_ERR6
        		MOV     A,#OK
        		RET
SELECTCARD_ERR1:	MOV     A,#FM1702_NOTAGERR
        		RET
SELECTCARD_ERR2:	MOV     A,#FM1702_PARITYERR
        		RET
SELECTCARD_ERR3:	MOV     A,#FM1702_FRAMINGERR
        		RET
SELECTCARD_ERR4:	MOV     A,#FM1702_CRCERR
        		RET
SELECTCARD_ERR5:	MOV     A,#FM1702_BYTECOUNTERR
        		RET
SELECTCARD_ERR6:	MOV     A,#FM1702_SELERR
        		RET
SELECT_CARD_DESFIRE:    MOV     R0,#CRCPresetLSB
        		MOV     A,#63H
        		MOVX 	@R0,A

        		MOV     R0,#CWConductance
        		MOV     A,#3FH
        		MOVX 	@R0,A

        		MOV     R0,#ChannelRedundancy
        		MOV     A,#0FH
        		MOVX 	@R0,A

        		MOV     R0,#As_Buffer
        		MOV     A,#RF_CMD_SELECT_DES
        		MOV     @R0,A
        		INC     R0
        		MOV     @R0,#70H
        		INC     R0
        		MOV     R1,#UID_Buffer
        		MOV     R7,#5
SELECTCARD_D_LOOP:	MOV     A,@R1
        		MOV     @R0,A
        		INC     R0
        		INC     R1
        		DJNZ    R7,SELECTCARD_D_LOOP

        		MOV     CMDSEND_COMD,#Transceive
        		MOV     CMDSEND_LENG,#7
        		LCALL   COMMAND_SEND
        		CJNE    A,#OK,SELECTCARD_D_ERR1

        		MOV     R0,#ErrorFlag
        		MOVX 	A,@R0

        		JB      ACC.1,SELECTCARD_D_ERR2
        		JB      ACC.2,SELECTCARD_D_ERR3
        		JB      ACC.3,SELECTCARD_D_ERR4

        		MOV     R0,#FIFO_Length
        		MOVX 	A,@R0
        		ANL     A,#1
        		JZ      SELECTCARD_D_ERR5

        		LCALL   READ_FIFO

        		MOV     R0,#As_Buffer
        		MOV     A,@R0
        		CJNE    A,#24H,SELECTCARD_D_0
        		MOV     A,#OK
        		RET
SELECTCARD_D_0:         CJNE    A,#18H,SELECTCARD_D_1
        		MOV     A,#OK
        		RET
SELECTCARD_D_1:		CJNE    A,#08H,SELECTCARD_D_2
        		MOV     A,#OK
        		RET
SELECTCARD_D_2:		CJNE    A,#88H,SELECTCARD_D_3
        		MOV     A,#OK
        		RET
SELECTCARD_D_3:		CJNE    A,#0AH,SELECTCARD_D_4
        		MOV     A,#OK
        		RET
SELECTCARD_D_4:		CJNE    A,#20H,SELECTCARD_D_5
        		MOV     A,#OK
        		RET
SELECTCARD_D_5:		CJNE    A,#28H,SELECTCARD_D_6
        		MOV     A,#OK
        		RET
SELECTCARD_D_6:		CJNE    A,#53H,SELECTCARD_D_ERR6
        		MOV     A,#OK
        		RET
SELECTCARD_D_ERR1:	MOV     A,#FM1702_NOTAGERR
        		RET
SELECTCARD_D_ERR2:	MOV     A,#FM1702_PARITYERR
        		RET
SELECTCARD_D_ERR3:	MOV     A,#FM1702_FRAMINGERR
        		RET
SELECTCARD_D_ERR4:	MOV     A,#FM1702_CRCERR
        		RET
SELECTCARD_D_ERR5:	MOV     A,#FM1702_BYTECOUNTERR
        		RET
SELECTCARD_D_ERR6:	MOV     A,#FM1702_SELERR
        		RET
;***********************************************************************************************
; /*名称:LOAD_KEYE2
; /*功能:装载密钥(把计算过后的密钥写入EEPROM中(?))
; /*入口:As_Buffer//+2..中转换好的密钥
; /*出口:A:OK/ERROR
;***********************************************************************************************
LOAD_KEYE2:		LCALL   HOSTCODEKEY
        		;//LCALL   MIF_WRITEE2

        		;//MOV     R0,#As_Buffer
        		;//MOV     A,#80H			;LSB
        		;//MOV     @R0,A
        		;//INC     R0
        		;//MOV     A,#00H			;MSB
        		;//MOV     @R0,A

        		MOV     CMDSEND_COMD,#LoadKey;//#LoadKeyE2
        		MOV     CMDSEND_LENG,#16;//#2
        		LCALL   COMMAND_SEND
        		CJNE    A,#OK,LOAD_KEYE2_ERR	;后加的判断

        		MOV     R0,#ErrorFlag
        		MOVX 	A,@R0
        		ANL     A,#40H

        		CJNE    A,#40H,LOADKEYE2_SUCC
LOAD_KEYE2_ERR:		MOV     A,#ERROR
        		RET
LOADKEYE2_SUCC:		MOV     A,#OK
        		RET
;***********************************************************************************************
; /*名称:HOSTCODEKEY
; /*功能:转换密钥格式
; /*入口:(KAYA)
; /*出口:As_Buffer+2...中保存转换好的密钥
;***********************************************************************************************
HOSTCODEKEY:		MOV     R7,#6
        		MOV     DPTR,#KEYS
        		MOV     R1,#0
        		MOV     R0,#As_Buffer+0;//+2		;直接放入WRITE_E2程序将要用的位置
HOSTCODEKEY1:		MOV     A,R1
        		MOVC    A,@A+DPTR
			ANL     A,#0F0H
			SWAP   	A
			MOV     B,A
			CPL	A
        		ANL     A,#0FH
        		SWAP    A
			ORL     A,B
			MOV     @R0,A
			INC     R0

			MOV     A,R1
        		MOVC    A,@A+DPTR
			ANL     A,#0FH
			MOV     B,A
			CPL	A
        		ANL     A,#0FH
        		SWAP    A
			ORL     A,B
			MOV     @R0,A
			INC     R0
			INC     R1
        		DJNZ    R7,HOSTCODEKEY1
        		RET
KEYS:   		DB      19H,94H,04H,28H,19H,70H
;***********************************************************************************************
; /*名称:MIF_WRITEE2
; /*功能:向FM1702的EE中写入数据(转换后的密钥)
; /*入口:As_Buffer+2...中转换好的密钥
; /*出口:A:OK/ERROR
;***********************************************************************************************
MIF_WRITEE2:		MOV     R0,#As_Buffer
        		MOV     A,#80H				;LSB
        		MOV     @R0,A
        		INC     R0
        		MOV     A,#00H				;MSB
        		MOV     @R0,A
        		NOP					;其余12字节的密码数据已在HOSTCODEKEY程序中放好(As_Buffer+2...

        		MOV     CMDSEND_COMD,#WriteE2
        		MOV     CMDSEND_LENG,#14
        		LCALL   COMMAND_SEND
        		CJNE    A,#OK,MIF_WRITEE2_ERR		;后加的判断

        		MOV     R0,#SecondaryStatus
        		MOVX 	A,@R0
        		ANL     A,#40H

        		CJNE    A,#40H,MIF_WRITEE2_ERR

        		MOV     R0,#Command
        		MOV     A,#00H
        		MOVX 	@R0,A

        		MOV     A,#OK
        		RET

MIF_WRITEE2_ERR:	MOV     A,#ERROR
        		RET
;***********************************************************************************************
; /*名称:AUTHENTICATION
; /*功能:密码认证
; /*入口:UID_Buffer:卡片4字节序列号,U_SECNR:扇区号
; /*出口:A:OK/ERROR/或各种错误标志
;***********************************************************************************************
AUTHENTICATION:		MOV     R0,#CRCPresetLSB
        		MOV     A,#63H
        		MOVX 	@R0,A

        		MOV     R0,#CWConductance
        		MOV     A,#3FH
        		MOVX 	@R0,A

        		MOV     R0,#As_Buffer
        		MOV     @R0,#RF_CMD_AUTH_LA

        		MOV     A,U_SECNR
        		CJNE	A,#32,AUTHENTICATION_1
AUTHENTICATION_1:	JNC	AUTHENTICATION_2
			MOV     B,#4
        		MUL     AB
        		ADD     A,#3					;(扇区号*4)+3=密码块
        		INC     R0
        		MOV     @R0,A
        		INC     R0
        		MOV     R7,#4
        		MOV     R1,#UID_Buffer
        		LJMP	AUTHENTICATION_10

AUTHENTICATION_2:	CJNE	A,#40,AUTHENTICATION_3
AUTHENTICATION_3:	JNC	AUTHENTICATION_ERR
			CLR	C
			SUBB	A,#32

			MOV     B,#16
        		MUL     AB
        		ADD     A,#15					;(扇区号-32)*16+15=密码块
        		ADD	A,#128					;4K卡的总块号
        		INC     R0
        		MOV     @R0,A
        		INC     R0
        		MOV     R7,#4
        		MOV     R1,#UID_Buffer
        		LJMP	AUTHENTICATION_10


AUTHENTICATION_10:      MOV     A,@R1
        		MOV     @R0,A
        		INC     R0
        		INC     R1
        		DJNZ    R7,AUTHENTICATION_10

        		MOV     R0,#ChannelRedundancy
        		MOV     A,#0FH
        		MOVX 	@R0,A

        		MOV     CMDSEND_COMD,#Authent1
        		MOV     CMDSEND_LENG,#6
        		LCALL   COMMAND_SEND
        		CJNE    A,#OK,AUTHENTICATION_ERR

        		MOV     R0,#ErrorFlag
        		MOVX 	A,@R0

        		JB      ACC.2,AUTHENTICATION_ERR1
        		JB      ACC.3,AUTHENTICATION_ERR2
        		JB      ACC.4,AUTHENTICATION_ERR3

        		MOV     CMDSEND_COMD,#Authent2
        		MOV     CMDSEND_LENG,#0				;0??????!为什么?
        		LCALL   COMMAND_SEND
        		CJNE    A,#OK,AUTHENTICATION_ERR

        		MOV     R0,#ErrorFlag
        		MOVX 	A,@R0

        		JB      ACC.2,AUTHENTICATION_ERR1
        		JB      ACC.3,AUTHENTICATION_ERR2
        		JB      ACC.4,AUTHENTICATION_ERR3

        		MOV     R0,#Control
        		MOVX 	A,@R0
        		ANL     A,#8
        		CJNE    A,#8,AUTHENTICATION_ERR4

        		MOV     A,#OK
        		RET

AUTHENTICATION_ERR:	MOV     A,#FM1702_AUTHERR;#ERROR
        		RET
AUTHENTICATION_ERR1:	MOV     A,#FM1702_PARITYERR
        		RET
AUTHENTICATION_ERR2:	MOV     A,#FM1702_FRAMINGERR
        		RET
AUTHENTICATION_ERR3:	MOV     A,#FM1702_CRCERR
        		RET
AUTHENTICATION_ERR4:	MOV     A,#FM1702_AUTHERR
        		RET
;***********************************************************************************************
; /*名称:COMMAND_SEND
; /*功能:发送命令
; /*入口:CMDSEND_COMD:命令码,CMDSEND_LENG:长度,As_Buffer...:命令数据串
; /*出口:A,OK/ERROR
;***********************************************************************************************
COMMAND_SEND:		JB	TEST_1702SL,COMMAND_SEND_0	;为测试卡时加的
			MOV     R0,#Command
        		MOV     A,#00H
        		MOVX 	@R0,A

        		LCALL   CLEAR_FIFO

COMMAND_SEND_0:		LCALL   WRITE_FIFO

        		MOV     R0,#Command
        		MOV     A,CMDSEND_COMD
        		MOVX 	@R0,A

        		MOV     R4,#RF_TimeOut
        		JNB	TEST_1702SL,COMMAND_SEND_1	;为测试卡时加的
			LCALL   DELAY100US
			LCALL   DELAY100US
			LCALL   DELAY100US
                        LCALL   DELAY100US
			LCALL   DELAY50US

COMMAND_SEND_1:		MOV     R0,#Command
        		MOVX 	A,@R0
        		JNZ     COMMAND_SEND_2
        		MOV     A,#OK
        		RET

COMMAND_SEND_2:		JB	TEST_1702SL,COMMAND_SEND_err	;为测试卡时加的
			MOV     R0,#Int_Req
        		MOVX 	A,@R0
        		ANL     A,#80H
        		CJNE    A,#80H,COMMAND_SEND_2_1
        		MOV     A,#OK
        		RET

COMMAND_SEND_2_1:       LCALL   DELAY100US
                        ;LCALL   DELAY100US
                        DJNZ    R4,COMMAND_SEND_1
COMMAND_SEND_err:	MOV     A,#ERROR
        		RET
;***********************************************************************************************
; /*名称:CLEAR_FIFO
; /*功能:清空FIFO
; /*入口:
; /*出口:A,OK/ERROR
;***********************************************************************************************
CLEAR_FIFO:		MOV     R0,#Control
        		MOVX 	A,@R0

			ORL  	A,#01H			;清空FIFO
        		MOV     R0,#Control
        		MOVX 	@R0,A

        		MOV     R4,#RF_TimeOut		;此处延时可以调整
CLEAR_FIFO_1:		MOV     R0,#FIFO_Length
        		MOVX 	A,@R0
        		JZ      CLEARFIFO_SUCC
        		DJNZ    R4,CLEAR_FIFO_1
        		MOV     R7,#ERROR
        		RET
CLEARFIFO_SUCC:		MOV     R7,#OK
        		RET
;***********************************************************************************************
; /*名称:WRITE_FIFO
; /*功能:写FIFO(仅由COMMAND_SEND调用)
; /*入口:CMDSEND_LENG:长度,As_Buffer...:命令数据串
; /*出口:
;***********************************************************************************************
WRITE_FIFO:		MOV     A,CMDSEND_LENG
        		JZ      WRITE_FIFO_R
        		MOV     R4,A

        		MOV     R1,#As_Buffer
WRITE_FIFO_1:		MOV     A,@R1
        		MOV     R0,#FIFO
        		MOVX 	@R0,A
        		INC     R1
        		DJNZ    R4,WRITE_FIFO_1
WRITE_FIFO_R:		RET

;***********************************************************************************************
; /*名称:READ_FIFO
; /*功能:读FIFO	(先读长度,再由长度决定读的次数)
; /*入口:
; /*出口:As_Buffer...:读出的数据串
;***********************************************************************************************
READ_FIFO:		MOV     R1,#As_Buffer
        		MOV     R0,#FIFO_Length
        		MOVX 	A,@R0			;有些地方已经读过长度MIF_ANTICOLL3:
        		JNZ     READ_FIFO_1
        		MOV     @R1,A
        		RET

READ_FIFO_1:		MOV     R4,A
        		CLR     C
        		SUBB    A,#16			;与As_Buffer的长度有关:超过16,仅读16
        		JC      READ_FIFO_2
        		MOV     R4,#16
READ_FIFO_2:		MOV     R0,#FIFO
        		MOVX 	A,@R0
        		MOV     @R1,A
        		INC     R1
        		DJNZ    R4,READ_FIFO_2
        		RET
;***********************************************************************************************
; /*名称:MIF_READ
; /*功能:读mifare卡的某块
; /*入口:U_BLKNR:块号
; /*出口:A:OK/ERROR/或各种错误标志, As_Buffer...:读出的16字节数据
;***********************************************************************************************
MIF_READ:		MOV     R0,#CRCPresetLSB
        		MOV     A,#63H
        		MOVX 	@R0,A

        		MOV     R0,#CWConductance
        		MOV     A,#3FH
        		MOVX 	@R0,A

        		MOV     R0,#ModConductance
        		MOV     A,#3FH
        		MOVX 	@R0,A

        		MOV     R0,#ChannelRedundancy
        		MOV     A,#0FH
        		MOVX 	@R0,A

        		MOV     R0,#As_Buffer
        		MOV     @R0,#RF_CMD_READ
        		INC     R0
        		MOV     A,U_BLKNR
        		MOV     @R0,A

        		MOV     CMDSEND_COMD,#Transceive
        		MOV     CMDSEND_LENG,#2
        		LCALL   COMMAND_SEND
        		CJNE    A,#OK,MIF_READ_ERR

        		MOV     R0,#ErrorFlag
        		MOVX 	A,@R0

        		JB      ACC.2,MIF_READ_ERR1
        		JB      ACC.3,MIF_READ_ERR2
        		JB      ACC.4,MIF_READ_ERR3

        		MOV     R0,#FIFO_Length
        		MOVX 	A,@R0

        		CJNE    A,#10H,MIF_READ_1		;16字节
        		LCALL   READ_FIFO
        		MOV     A,#OK
        		RET
MIF_READ_1:
        		CJNE    A,#4,MIF_READ_ERR4
        		LCALL   READ_FIFO
        		MOV     A,#OK
        		RET
MIF_READ_ERR:
        		MOV     A,#FM1702_NOTAGERR
        		RET
MIF_READ_ERR1:
        		MOV     A,#FM1702_PARITYERR
        		RET
MIF_READ_ERR2:
        		MOV     A,#FM1702_FRAMINGERR
        		RET
MIF_READ_ERR3:
        		MOV     A,#FM1702_CRCERR
        		RET
MIF_READ_ERR4:
        		MOV     A,#FM1702_BYTECOUNTERR
        		RET
;***********************************************************************************************
; /*名称:MIF_Write
; /*功能:写mifare卡的某块
; /*入口:U_BLKNR:块号,WR_Buffer...:待写的16字节数据
; /*出口:A:OK/ERROR/或各种错误标志
;***********************************************************************************************
MIF_WRITE:
        		MOV     R0,#CRCPresetLSB
        		MOV     A,#63H
        		MOVX 	@R0,A

        		MOV     R0,#CWConductance
        		MOV     A,#3FH
        		MOVX 	@R0,A

        		MOV     R0,#ChannelRedundancy
        		MOV     A,#07H
        		MOVX 	@R0,A

        		MOV     R0,#As_Buffer
        		MOV     @R0,#RF_CMD_WRITE
        		INC     R0
        		MOV     A,U_BLKNR
        		MOV     @R0,A

        		MOV     CMDSEND_COMD,#Transceive
        		MOV     CMDSEND_LENG,#2
        		LCALL   COMMAND_SEND
        		CJNE    A,#OK,MIF_WRITE_ERR

        		MOV     R0,#FIFO_Length
        		MOVX 	A,@R0

        		JZ      MIF_WRITE_ERR1

        		LCALL   READ_FIFO

        		MOV     R0,#As_Buffer
        		MOV     A,@R0
        		CJNE    A,#00H,MIF_WRITE_1
        		LJMP    MIF_WRITE_ERR2
MIF_WRITE_1:		CJNE    A,#04H,MIF_WRITE_2
        		LJMP    MIF_WRITE_ERR3
MIF_WRITE_2:		CJNE    A,#01H,MIF_WRITE_3
        		LJMP    MIF_WRITE_ERR4
MIF_WRITE_3:		CJNE    A,#05H,MIF_WRITE_4
        		LJMP    MIF_WRITE_ERR5
MIF_WRITE_4:		CJNE    A,#0AH,MIF_WRITE_ERR6

MIF_WRITE_5:           	MOV	R0,#Wr_Buffer		;把Wr_Buffer中的待写数据送Cm_Buffer,以统一COMMAND_SEND的入口
                  	MOV	R1,#As_Buffer
                  	MOV	R7,#16
MIF_WRITE_5_1:		MOV	A,@R0
			MOV	@R1,A
			INC	R0
			INC	R1
			DJNZ	R7,MIF_WRITE_5_1

        		MOV     CMDSEND_COMD,#Transceive
        		MOV     CMDSEND_LENG,#16
        		LCALL   COMMAND_SEND
        		CJNE    A,#OK,MIF_WRITE_6
        		MOV     A,#OK
        		RET
MIF_WRITE_6:
        		MOV     R0,#ErrorFlag
        		MOVX 	A,@R0
        		MOV     A,#ERROR
        		RET
MIF_WRITE_ERR:
        		MOV     A,#FM1702_NOTAGERR
        		RET
MIF_WRITE_ERR1:
        		MOV     A,#FM1702_BYTECOUNTERR
        		RET
MIF_WRITE_ERR2:
        		MOV     A,#FM1702_NOTAUTHERR
        		RET
MIF_WRITE_ERR3:
        		MOV     A,#FM1702_EMPTY
        		RET
MIF_WRITE_ERR4:
        		MOV     A,#FM1702_CRCERR
        		RET
MIF_WRITE_ERR5:
        		MOV     A,#FM1702_PARITYERR
        		RET
MIF_WRITE_ERR6:
        		MOV     A,#FM1702_WRITEERR
        		RET
;====================================================================;
;***********************************************************************************************
TEST_M1_PLUS:          	MOV	T0INTCOUNT,#250
			CLR	PLUS_FLAG
			mov	count1,#10		;mifscard_1中使用的参数
			LCALL	mifscard_1
                	CJNE	A,#ERROR,TEST_M1_PLUS_1
TEST_M1_PLUS_ERR:	MOV	A,#ERROR
			RET

TEST_M1_PLUS_1:        	MOV	T0INTCOUNT,#34
			LCALL	MIF_ANTICOLL
			CJNE	A,#OK,TEST_M1_PLUS_ERR
                        LCALL   SELECT_CARD
			CJNE	A,#OK,TEST_M1_PLUS_ERR
                        LCALL	MIF_ANTICOLL_DESFIRE
                        CJNE	A,#OK,TEST_M1_PLUS_END
			LCALL   SELECT_CARD_DESFIRE
			CJNE	A,#OK,TEST_M1_PLUS_END

			SETB	PLUS_FLAG
TEST_M1_PLUS_END:	MOV	A,#OK
			RET

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
UN_ENCODE:
        MOV     R0,#BUFF_BEG_MIF+00
        MOV     A,@R0
        JNZ     UN_ENCODE_1
        RET                                     ;若为原始卡则不用解密
UN_ENCODE_1:
        MOV     R0,#BUFF_BEG_MIF+24
        MOV     A,@R0
        XRL     A,#60H
        JZ      UN_ENCODE_TRUE                  ;卡的第24字节为60H的话，为加密卡片，进入解密程序
        RET
UN_ENCODE_TRUE:
        MOV     R0,#UID_Buffer
        MOV     R1,#BUFF_BEG_24C1X
        MOV     R7,#4
UE_1:
        MOV     A,@R0
        MOV     @R1,A
        INC     R0
        INC     R1
        DJNZ    R7,UE_1                         ;将UID暂时转存到数据区，准备解密
        LCALL   UNENCOD_UID
        MOV     R0,#BUFF_BEG_MIF+1
        MOV     R1,#BUFF_BEG_24C1X
        MOV     R7,#4
UE_2:
        MOV     A,@R1
        XRL     A,@R0
        MOV     @R0,A
        INC     R0
        INC     R1
        DJNZ    R7,UE_2                         ;将加密后的数据与计算好的UID异或，则可得到数据原文
        MOV     R0,#BUFF_BEG_MIF+00
        MOV     A,@R0
        CJNE    A,#01H,UE_3
        LJMP    UE_5
UE_3:
        CJNE    A,#10H,UE_4
UE_5:                                           ;若为密码卡或设置卡，对旧密码区也进行解密
        MOV     R0,#BUFF_BEG_MIF+5
        MOV     R1,#BUFF_BEG_24C1X
        MOV     R7,#4
UE_5_1:
        MOV     A,@R1
        XRL     A,@R0
        MOV     @R0,A
        INC     R0
        INC     R1
        DJNZ    R7,UE_5_1
UE_4:
        RET

UNENCOD_UID:                                    ;将UID加密，加密后的数据存于BUFF_BEG_24C1X 0-3
        MOV     R0,#BUFF_BEG_24C1X+0
        MOV     A,@R0
        SWAP    A
        MOV     @R0,A
        CPL     A
        XCHD    A,@R0
        MOV     A,@R0
        SWAP    A
        MOV     @R0,A
        MOV     R0,#BUFF_BEG_24C1X+1
        MOV     A,@R0
        CPL     A
        XCHD    A,@R0
        MOV     R0,#BUFF_BEG_24C1X+2
        MOV     A,@R0
        SWAP    A
        MOV     @R0,A
        CPL     A
        XCHD    A,@R0
        MOV     A,@R0
        SWAP    A
        MOV     @R0,A
        MOV     R0,#BUFF_BEG_24C1X+3
        MOV     A,@R0
        SWAP    A
        MOV     @R0,A
        CPL     A
        XCHD    A,@R0
        MOV     A,@R0
        SWAP    A
        MOV     @R0,A

        MOV     R0,#BUFF_BEG_24C1X+3
        MOV     A,@R0
        ANL     A,#0F0H
        MOV     R7,A
        MOV     R0,#BUFF_BEG_24C1X+1
        MOV     A,@R0
        SWAP    A
        ANL     A,#0FH
        ORL     A,R7
        MOV     R0,#BUFF_BEG_24C1X+4
        MOV     @R0,A

        MOV     R0,#BUFF_BEG_24C1X+3
        MOV     A,@R0
        SWAP    A
        ANL     A,#0F0H
        MOV     R7,A
        MOV     R0,#BUFF_BEG_24C1X+0
        MOV     A,@R0
        SWAP    A
        ANL     A,#0FH
        ORL     A,R7
        MOV     R0,#BUFF_BEG_24C1X+5
        MOV     @R0,A

        MOV     R0,#BUFF_BEG_24C1X+2
        MOV     A,@R0
        SWAP    A
        ANL     A,#0F0H
        MOV     R7,A
        MOV     R0,#BUFF_BEG_24C1X+1
        MOV     A,@R0
        ANL     A,#0FH
        ORL     A,R7
        MOV     R0,#BUFF_BEG_24C1X+6
        MOV     @R0,A

        MOV     R0,#BUFF_BEG_24C1X+0
        MOV     A,@R0
        SWAP    A
        ANL     A,#0F0H
        MOV     R7,A
        MOV     R0,#BUFF_BEG_24C1X+2
        MOV     A,@R0
        SWAP    A
        ANL     A,#0FH
        ORL     A,R7
        MOV     R0,#BUFF_BEG_24C1X+7
        MOV     @R0,A

        MOV     R0,#BUFF_BEG_24C1X+4
        MOV     A,@R0
        XRL     A,#78H
        MOV     R0,#BUFF_BEG_24C1X+0
        MOV     @R0,A
        MOV     R0,#BUFF_BEG_24C1X+5
        MOV     A,@R0
        XRL     A,#1AH
        MOV     R0,#BUFF_BEG_24C1X+1
        MOV     @R0,A
        MOV     R0,#BUFF_BEG_24C1X+6
        MOV     A,@R0
        XRL     A,#77H
        MOV     R0,#BUFF_BEG_24C1X+2
        MOV     @R0,A
        MOV     R0,#BUFF_BEG_24C1X+7
        MOV     A,@R0
        XRL     A,#9FH
        MOV     R0,#BUFF_BEG_24C1X+3
        MOV     @R0,A
        RET
;==========================================================================;
AUTO_CHANGKAI_TEST:     LCALL   RD_8563
			CJNE	A,#OK,AUTO_CHANGKAI_TEST_ERR1		;如果时钟错误,也算时间有效

                        MOV	HADDR_24C1X,#00H
                        MOV	LADDR_24C1X,#0C0H
AUTO_CHANGKAI_TEST_LOOP:
                        LCALL   GET_DATA_AUTO
                        CJNE	A,#OK,AUTO_CHANGKAI_TEST_ERR1

                        LCALL   CHECK_ST_TIME
                        CJNE    A,#OK,AUTO_CHANGKAI_TEST_NEXT

			LCALL	CHECK_TIME_ADP			;判断时间
			CJNE	A,#CHECK_TIME_STATE3,AUTO_CHANGKAI_TEST_NEXT
                        LJMP    AUTO_CHANGKAI_TEST_JPOUT
AUTO_CHANGKAI_TEST_NEXT:
                        MOV     A,LADDR_24C1X
                        XRL     A,#20H
                        JNZ     AUTO_CHANGKAI_TEST_LOOP
                        LJMP    AUTO_CHANGKAI_TEST_1
AUTO_CHANGKAI_TEST_JPOUT:
			MOV	HADDR_24C1X,#00H
			MOV	LADDR_24C1X,#0CH
			MOV	LENGTH_24C1X,#1
			CALL	RD_24C64
			CJNE	A,#OK,AUTO_CHANGKAI_TEST_ERR1
                        MOV     A,BUFF_BEG_24C1X
                        JNZ     AUTO_CHANGKAI_TEST_ERR1

			MOV	BUFF_BEG_24C1X,#03H		;置常开标志
			MOV	HADDR_24C1X,#00H
			MOV	LADDR_24C1X,#0CH
			MOV	LENGTH_24C1X,#1
			CALL	WR_24C64
			CJNE	A,#OK,AUTO_CHANGKAI_TEST_ERR1	;读写24C64(记录)失败,跳ER_R_W_24C64
			SETB	CHANG_KAI_FLAG		;置常开标志

                        CLR     CARD_FLAG
			MOV	A,#AUTO_CHANGKAI
			MOV	B,#NO_CARD
			LCALL	SAVE_REC		;先记录

                        LCALL	CPU_INITIALIZE
			LCALL   MOT_POSITIVE
			MOV	A,#OK
			RET

AUTO_CHANGKAI_TEST_ERR1:MOV	A,#ERROR
			RET

AUTO_CHANGKAI_TEST_1:

                        MOV	HADDR_24C1X,#00H
			MOV	LADDR_24C1X,#0CH
			MOV	LENGTH_24C1X,#1
			CALL	RD_24C64
			CJNE	A,#OK,AUTO_CHANGKAI_TEST_ERR1
                        MOV     A,BUFF_BEG_24C1X
                        JZ      AUTO_CHANGKAI_TEST_ERR1

                        MOV	BUFF_BEG_24C1X,#00H		;置常开标志
			MOV	HADDR_24C1X,#00H
			MOV	LADDR_24C1X,#0CH
			MOV	LENGTH_24C1X,#1
			CALL	WR_24C64
			CJNE	A,#OK,AUTO_CHANGKAI_TEST_ERR1

                        LCALL	CPU_INITIALIZE
			LCALL   MOT_REVERSE

                        CLR     CARD_FLAG
			MOV	A,#AUTO_CLOSE
			MOV	B,#NO_CARD
			CALL	SAVE_REC		;先记录
			MOV	A,#OK
			RET
;***********************************************************************************************
GET_DATA_AUTO:
	MOV	LENGTH_24C1X,#16
	LCALL	RD_24C64
	CJNE	A,#OK,GET_DATA_AUTO_ERR1
	MOV	R0,#BUFF_BEG_24C1X+5
	MOV	R1,#BUFF_BEG_MIF+9
	MOV	R7,#5
GET_DATA_AUTO_LOOP1:
	MOV	A,@R0
	MOV	@R1,A
	INC	R0
	INC	R1
	DJNZ	R7,GET_DATA_AUTO_LOOP1

	MOV	R0,#BUFF_BEG_24C1X+10
	MOV	R1,#BUFF_BEG_MIF+32
	MOV	R7,#5
GET_DATA_AUTO_LOOP2:
	MOV	A,@R0
	MOV	@R1,A
	INC	R0
	INC	R1
	DJNZ	R7,GET_DATA_AUTO_LOOP2

        MOV	R7,#5
GET_DATA_AUTO_LOOP3:
        MOV     @R1,#0FFH
        INC     R1
        DJNZ    R7,GET_DATA_AUTO_LOOP3
	MOV	A,#OK                              ;后面补FF，表示不用再查
	RET
GET_DATA_AUTO_ERR1:
	MOV	A,#ERROR
	RET
;***********************************************************************************************
;比较开始时间，开始时间存放于BUFF_BEG_24C1X+0-4，实时时钟存放于BUFF_BEG_8563
;***********************************************************************************************
CHECK_ST_TIME:
        MOV     R0,#BUFF_BEG_24C1X+0
        MOV     R7,#5
        MOV     A,#0FFH
CHECK_ST_TIME_LOP:
        ANL     A,@R0
        INC     R0
        DJNZ    R7,CHECK_ST_TIME_LOP
        XRL     A,#0FFH
        JZ      CHECK_ST_TIME_ERR
        MOV     R0,#BUFF_BEG_24C1X+0
        MOV     R1,#BUFF_BEG_8563+0
        MOV     A,@R0
        XRL     A,@R1
        JZ      CHECK_ST_TIME_0
        MOV     A,@R0
        CLR     C
        SUBB    A,@R1
        JNC     CHECK_ST_TIME_ERR
        MOV     A,#OK
        RET
CHECK_ST_TIME_0:
        MOV     R0,#BUFF_BEG_24C1X+1
        MOV     R1,#BUFF_BEG_8563+1
        MOV     A,@R0
        XRL     A,@R1
        JZ      CHECK_ST_TIME_1
        MOV     A,@R0
        CLR     C
        SUBB    A,@R1
        JNC     CHECK_ST_TIME_ERR
        MOV     A,#OK
        RET
CHECK_ST_TIME_1:
        MOV     R0,#BUFF_BEG_24C1X+2
        MOV     R1,#BUFF_BEG_8563+2
        MOV     A,@R0
        XRL     A,@R1
        JZ      CHECK_ST_TIME_2
        MOV     A,@R0
        CLR     C
        SUBB    A,@R1
        JNC     CHECK_ST_TIME_ERR
        MOV     A,#OK
        RET
CHECK_ST_TIME_2:
        MOV     R0,#BUFF_BEG_24C1X+4
        MOV     R1,#BUFF_BEG_8563+4
        MOV     A,@R0
        XRL     A,@R1
        JZ      CHECK_ST_TIME_4
        MOV     A,@R0
        CLR     C
        SUBB    A,@R1
        JNC     CHECK_ST_TIME_ERR
        MOV     A,#OK
        RET
CHECK_ST_TIME_4:
        MOV     R0,#BUFF_BEG_24C1X+5
        MOV     R1,#BUFF_BEG_8563+5
        MOV     A,@R0
        XRL     A,@R1
        JZ      CHECK_ST_TIME_ERR
        MOV     A,@R0
        CLR     C
        SUBB    A,@R1
        JNC     CHECK_ST_TIME_ERR
        MOV     A,#OK
        RET
CHECK_ST_TIME_ERR:
        MOV     A,#ERROR
        RET
;***********************************************************************************************
;测试设备是否允许该种卡片运行，检测字节为BUFF_BEG_24C1X+15
TEST_DEVICE_ENABLE:
        MOV     A,BUFF_BEG_MIF
        CJNE    A,#09H,TEST_DEVICE_ENABLE_1
        MOV     A,#01H
        CPL     A
        LJMP    TEST_DEVICE_ENABLE_OUT
TEST_DEVICE_ENABLE_1:
        CJNE    A,#0AH,TEST_DEVICE_ENABLE_2
        MOV     A,#02H
        CPL     A
        LJMP    TEST_DEVICE_ENABLE_OUT
TEST_DEVICE_ENABLE_2:
        CJNE    A,#0BH,TEST_DEVICE_ENABLE_3
        MOV     A,#04H
        CPL     A
        LJMP    TEST_DEVICE_ENABLE_OUT
TEST_DEVICE_ENABLE_3:
        CJNE    A,#0CH,TEST_DEVICE_ENABLE_4
        MOV     A,#08H
        CPL     A
        LJMP    TEST_DEVICE_ENABLE_OUT
TEST_DEVICE_ENABLE_4:
        CJNE    A,#0DH,TEST_DEVICE_ENABLE_5
        MOV     A,#10H
        CPL     A
        LJMP    TEST_DEVICE_ENABLE_OUT
TEST_DEVICE_ENABLE_5:
        CJNE    A,#1DH,TEST_DEVICE_ENABLE_6
        MOV     A,#20H
        CPL     A
        LJMP    TEST_DEVICE_ENABLE_OUT
TEST_DEVICE_ENABLE_6:
        MOV     A,#40H
        CPL     A
TEST_DEVICE_ENABLE_OUT:
        MOV     R0,#BUFF_BEG_24C1X+15
        ORL     A,@R0
        XRL     A,#0FFH
        JZ      TEST_DEVICE_ENABLE_ERR
        MOV     A,#OK
        RET
TEST_DEVICE_ENABLE_ERR:
        MOV     A,#ERROR
        RET
;***********************************************************************************************
TIME_GROUP_CARD:
        MOV	HADDR_24C1X,#00H
	MOV	LADDR_24C1X,#0C0H
        MOV     R6,#BUFF_BEG_MIF+20H
        MOV     R5,#3
TIME_GROUP_CARD_LOOP2:
        MOV     A,R6
        MOV	R0,A
        MOV     R1,#BUFF_BEG_24C1X
        MOV     R7,#16
TIME_GROUP_CARD_LOOP1:
        MOV     A,@R0
        MOV     @R1,A
        INC     R0
        INC     R1
        DJNZ    R7,TIME_GROUP_CARD_LOOP1

        MOV	LENGTH_24C1X,#16
	LCALL	WR_24C64
	CJNE	A,#OK,TIME_GROUP_CARD_ERR1

        MOV     A,R6
        ADD     A,#16
        MOV     R6,A
        DJNZ    R5,TIME_GROUP_CARD_LOOP2

        LCALL   SELECT_EXTRAM
        MOV     R6,#FJCBUFF_BEG_MIF+00H
        MOV     R5,#3
TIME_GROUP_CARD_LOOP4:
        MOV     A,R6
        MOV	R0,A
        MOV     R1,#BUFF_BEG_24C1X
        MOV     R7,#16
TIME_GROUP_CARD_LOOP3:
        MOVX    A,@R0
        MOV     @R1,A
        INC     R0
        INC     R1
        DJNZ    R7,TIME_GROUP_CARD_LOOP3

        MOV	LENGTH_24C1X,#16
	LCALL	WR_24C64
	CJNE	A,#OK,TIME_GROUP_CARD_ERR1

        MOV     A,R6
        ADD     A,#16
        MOV     R6,A
        DJNZ    R5,TIME_GROUP_CARD_LOOP4

	LCALL	LEDBUZZ_SETUP
        LCALL   SELECT_MIFRAM
	LJMP    PWR_DOWN
TIME_GROUP_CARD_ERR1:
	LCALL	LEDBUZZ_EEPROM_ERROR;24C256读写错误
        LCALL   SELECT_MIFRAM
	LJMP	PWR_DOWN
;***********************************************************************************************
TIME_PATTEN_CARD:
        MOV	HADDR_24C1X,#00H
	MOV	LADDR_24C1X,#060H
        MOV     R6,#BUFF_BEG_MIF+20H
        MOV     R5,#3
TIME_PATTEN_CARD_LOOP2:
        MOV     A,R6
        MOV	R0,A
        MOV     R1,#BUFF_BEG_24C1X
        MOV     R7,#16
TIME_PATTEN_CARD_LOOP1:
        MOV     A,@R0
        MOV     @R1,A
        INC     R0
        INC     R1
        DJNZ    R7,TIME_PATTEN_CARD_LOOP1

        MOV	LENGTH_24C1X,#16
	LCALL	WR_24C64
	CJNE	A,#OK,TIME_PATTEN_CARD_ERR1

        MOV     A,R6
        ADD     A,#16
        MOV     R6,A
        DJNZ    R5,TIME_PATTEN_CARD_LOOP2

        LCALL   SELECT_EXTRAM
        MOV     R6,#FJCBUFF_BEG_MIF+00H
        MOV     R5,#3
TIME_PATTEN_CARD_LOOP4:
        MOV     A,R6
        MOV	R0,A
        MOV     R1,#BUFF_BEG_24C1X
        MOV     R7,#16
TIME_PATTEN_CARD_LOOP3:
        MOVX    A,@R0
        MOV     @R1,A
        INC     R0
        INC     R1
        DJNZ    R7,TIME_PATTEN_CARD_LOOP3

        MOV	LENGTH_24C1X,#16
	LCALL	WR_24C64
	CJNE	A,#OK,TIME_PATTEN_CARD_ERR1

        MOV     A,R6
        ADD     A,#16
        MOV     R6,A
        DJNZ    R5,TIME_PATTEN_CARD_LOOP4

	LCALL	LEDBUZZ_SETUP
        LCALL   SELECT_MIFRAM
	LJMP    PWR_DOWN
TIME_PATTEN_CARD_ERR1:
	LCALL	LEDBUZZ_EEPROM_ERROR;24C256读写错误
        LCALL   SELECT_MIFRAM
	LJMP	PWR_DOWN
;***********************************************************************************************
;扩散黑名单，若卡片的11扇区有黑名单数据，则将其写入锁具黑名单，初始数据存放于EXBUFF_BEG_WR+0C3H开始的数据区
;返回说明ERR_24C64：存储器错误，OK：黑名单扩散完成
SPREAD_BLIST:
                        MOV     COUNT1,#0                      ;最多12组黑名单
SPREAD_BLIST_LOOP2:
                        MOV     A,COUNT1
                        MOV     B,#4
                        MUL     AB
                        MOV     R0,#FJCBUFF_BEG_MIF+30H
                        ADD     A,R0
                        MOV     R0,A
                        MOV     R7,#4
                        MOV     R1,#BUFF_BEG_MIF+18
SPREAD_BLIST_LOOP1:
                        MOVX    A,@R0
                        MOV     @R1,A
                        INC     R0
                        INC     R1
                        DJNZ    R7,SPREAD_BLIST_LOOP1

                        MOV     R0,#BUFF_BEG_MIF+18
                        MOV     R7,#4
                        MOV     A,#00H
SPREAD_BLIST_LOOP3:
                        ORL     A,@R0
                        INC     R0
                        DJNZ    R7,SPREAD_BLIST_LOOP3
                        JNZ     SPREAD_BLIST_0
                        MOV     A,#OK
                        RET                                     ;若卡片内黑名单区有全0的，则报成功退出，后面的数据不用再去处理

SPREAD_BLIST_0:
                        LCALL   COMP_SN
                        CJNE	A,#COMP_STATE0,SPREAD_BLIST_1   ;读24C256出错
                        MOV     A,#ERR_24C64
			RET

SPREAD_BLIST_1:		CJNE	A,#COMP_STATE1,SPREAD_BLIST_2   ;主序号没有和自己相同的
			MOV	A,#FIND_BLANK			;找空位置写入
			LJMP	SPREAD_BLIST_WR

SPREAD_BLIST_2:		CJNE	A,#COMP_STATE2,SPREAD_BLIST_3	;主序号和自己相同,且副序号也相同
			LJMP	SPREAD_BLIST_NEXT		;已经挂失

SPREAD_BLIST_3:		CJNE	A,#COMP_STATE3,SPREAD_BLIST_4	;主序号和自己相同,副序号大于自己
			LJMP	SPREAD_BLIST_NEXT		;不必挂失

SPREAD_BLIST_4:		CJNE	A,#COMP_STATE4,SPREAD_BLIST_5	;主序号和自己相同,副序号小于自己但不为0
                        MOV	A,#FIND_ITSELF
			LJMP	SPREAD_BLIST_WR			;改副序号

SPREAD_BLIST_5:                                                 ;主序号和自己相同,副序号为0
			LJMP	SPREAD_BLIST_NEXT		;属于被清除的对号卡,不能挂失
SPREAD_BLIST_WR:
                        LCALL	FIND_WR 			;把自己的序号填入

			CJNE	A,#FIND_STATE0,SPREAD_BLIST_6   ;读/写24C256出错
                        MOV     A,#ERR_24C64
			RET

SPREAD_BLIST_6:		CJNE	A,#FIND_STATE1,SPREAD_BLIST_7	;没找到空位置
                        LJMP	SPREAD_BLIST_NEXT

SPREAD_BLIST_7:		                                        ;找到空位置,且顺利把序号填入
SPREAD_BLIST_NEXT:      INC     COUNT1
                        MOV     A,COUNT1
                        XRL     A,#12
                        JNZ     SPREAD_BLIST_LOOP2
                        MOV     A,#OK
                        RET
;***********************************************************************************************
;***********************************************************************************************
;检测时间组数据是否正确，若为全0或全FF则说明无需进行时间组检测，直接跳过
;返回说明：0表示数据全0，未设置过，应允许所有卡片使用；1表示数据为全FF，则应该继续查下一组或直接报错；2表示以外数据，应进行继续检测
CHECK_TIME_CORRECT:
                        MOV     R1,#BUFF_BEG_24C1X
                        MOV     A,#00H
                        MOV     R7,#16
CHECK_TIME_CORRECT_LOOP:
                        ORL     A,@R1
                        INC     R1
                        DJNZ    R7,CHECK_TIME_CORRECT_LOOP
                        JNZ     CHECK_TIME_CORRECT_1
                        MOV     A,#00H
                        RET
CHECK_TIME_CORRECT_1:
                        MOV     R1,#BUFF_BEG_24C1X
                        MOV     A,#0FFH
                        MOV     R7,#16
CHECK_TIME_CORRECT_LOOP1:
                        ANL     A,@R1
                        INC     R1
                        DJNZ    R7,CHECK_TIME_CORRECT_LOOP1
                        XRL     A,#0FFH
                        JNZ     CHECK_TIME_CORRECT_2
                        MOV     A,#01H
                        RET
CHECK_TIME_CORRECT_2:
                        MOV     A,#02H
                        RET
;***********************************************************************************************
COPY_BUFF_2_EXTRAM:
                        LCALL   SELECT_EXTRAM
                        MOV     DPTR,#100H
                        MOV     R0,#BUFF_BEG_MIF
                        MOV     R7,#50H
CB2E_LOOP1:
                        MOV     A,@R0
                        MOVX    @DPTR,A
                        INC     R0
                        INC     DPTR
                        DJNZ    R7,CB2E_LOOP1
                        MOV     R0,#LS_BEG_MIF
                        MOV     R7,#10H
CB2E_LOOP2:
                        MOV     A,@R0
                        MOVX    @DPTR,A
                        INC     R0
                        INC     DPTR
                        DJNZ    R7,CB2E_LOOP2
                        LCALL   SELECT_MIFRAM
                        RET
;***********************************************************************************************
COPY_EXTRAM_2_BUFF:
                        LCALL   SELECT_EXTRAM
                        MOV     DPTR,#100H
                        MOV     R0,#BUFF_BEG_MIF
                        MOV     R7,#50H
CE2B_LOOP1:
                        MOVX    A,@DPTR
                        MOV     @R0,A
                        INC     R0
                        INC     DPTR
                        DJNZ    R7,CE2B_LOOP1
                        MOV     R0,#LS_BEG_MIF
                        MOV     R7,#10H
CE2B_LOOP2:
                        MOVX    A,@DPTR
                        MOV     @R0,A
                        INC     R0
                        INC     DPTR
                        DJNZ    R7,CE2B_LOOP2
                        LCALL   SELECT_MIFRAM
                        RET
;==========================================================================;
COMM_A:
                        MOV	T2CON,#00110000B	;T2做波特率9600
			MOV	TH2,#0FFH
			MOV	TL2,#0b2H
			MOV	RCAP2H,#0FFH
			MOV	RCAP2L,#0b2H

			MOV	PCON,#00H		;波特率不倍增
			MOV	SCON,#50H		;串口工作方式1
			SETB	TR2

                        MOV	HADDR_24C1X,#10H
			MOV	LADDR_24C1X,#60H
                        MOV     R6,#12
tx_BUFF_WR_2:
			MOV	LENGTH_24C1X,#16
			LCALL	RD_24C64

                        MOV	r0,#BUFF_BEG_24C1X
			MOV	R7,#10h
tx_BUFF_WR_1:		CLR	TI				;发送
			MOV	A,@r0
                        mov     sbuf,a
			JNB	TI,$
                        clr     ti
			inc	r0
			DJNZ	R7,tx_BUFF_WR_1
                        DJNZ    R6,tx_BUFF_WR_2

	               	ret


buzzer:
        cpl     buzz
        lcall   delay0001s
        lcall   delay0001s
        mov     WDTCONTER,#00110111B
        MOV	T0INTCOUNT,#200
        ljmp    buzzer


aaa:
                        MOV     T0INTCOUNT,#250
                        lcall   COMM_A
                        cpl     buzz
                        lcall   delay05s
                        lcall   delay05s
                        ljmp    aaa

			END
