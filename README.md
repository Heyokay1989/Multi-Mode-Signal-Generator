# 可扩展多模式信号发生平台 (Multi-Mode Signal Generator)

## 1. 项目简介
本项目为 2026 年全国大学生嵌入式芯片与系统设计竞赛参赛作品。项目基于 AMD-Xilinx Artix-7 (XC7A35T) FPGA 平台，我们设计并实现了一款**可扩展的多模式信号发生平台**。

系统采用“DDS 底座 + 多模式信号源”的架构，底层包含 32 位相位累加器、PLL 时钟管理与高速 UART 通信链路；上层通过模式仲裁逻辑支持正弦/方波/三角/锯齿四款基础波形，以及 LFSR 跳频、扫频、AM/FM 模拟调制、CPFSK 数字调制等多种扩展模式。

此外，我们配套开发了基于 Python 的可视化上位机，支持实时波形回传显示，并创新性地实现了**任意波形绘制与下载功能**（用户通过鼠标画图，经双口 RAM 实时注入 FPGA 输出）。

## 2. 开发环境
*   **FPGA 工具**：Vivado 2018.3
*   **硬件平台**：XC7A35T (FGG484)
*   **上位机**：Python 3.12 + pyserial + matplotlib + tkinter
*   **通信协议**：UART 921600 bps (8N1)

## 3. 目录结构
*   `src/`：FPGA RTL 源码和上位机文件
*   `sim/`：Testbench 仿真文件
*   `build/`：Tcl 一键重建脚本与综合/时序报告
*   `board/`：板级测试文件
*   `data/`：ROM 波形初始化 COE 文件
*   `skill/`：可复用的开发经验与避坑技能包
*   `report/`：设计报告与 AI 协作记录

## 4. 复现指南
1. 打开 Vivado 2018.3，在 Tcl Console 中运行：`source 你的文件路径/build/build_project.tcl`
2. 完成后会进入主页面，请等待1分钟后再进行下一步。
3. 点击`Run Synthesis`，可能会出现error，这时重新点击`Run Synthesis`，直至error消失只剩warnings，完成之后点击`Run Implementation`，等待完成。
4. 等待工程构建完成后，点击 `Generate Bitstream`。
5. 点击`Open Hardware Manager`栏下的`Program Device`,选择开发板,将 `.bit` 文件下载至开发板。
6. 将开发板通过 USB 连接至 PC，确认设备管理器中出现串口（如 COM5）。
7. 安装 Python 依赖：`pip install pyserial matplotlib numpy`。
8. 运行 `board/dds_host.py`，选择对应串口，波特率设为 `921600`，点击“打开串口”即可交互。

## 5. 致谢
本项目为参赛作品，感谢指导老师的指导与团队成员的通力合作。
