# -*- coding: utf-8 -*-
"""
============================================================
 DDS 信号发生器上位机
============================================================
功能特性
  1. 串口管理：自动扫描、打开/关闭、波特率选择
  2. 波形控制：正弦波 / 方波 / 三角波 / 锯齿波
  3. 频率控制：输入 Hz 自动计算 FTW 下发，支持 ±100Hz 步进微调
  4. 扩展控制：幅值(%) / 占空比(%) 指令预留（协议前瞻设计）
  5. 自动扫频：起始/终止/步进/间隔可配，自动逐点下发并统计成功数
  6. 波形显示：深色示波器风格，本地示意 + FPGA 采样数据(DATA:)实时绘制
  7. 状态回显：底部全宽日志区，vvv收发记录带时间戳，状态码中文解析
  8. 辅助功能：日志导出、日志清空、关闭时配置自动记忆

通信协议
  - 波特率 921600，数据位 8，停止位 1，无校验，帧尾 '\\n'
  - 下行：W{0-3} 波形 | F{FTW} 频率 | A{0-100} 幅值 | D{1-99} 占空比 | R 读波形
  - 上行：STA:OK | STA:ERR:01(格式错误) | STA:ERR:02(超范围) | DATA:v1,v2,...

依赖：pyserial  numpy  matplotlib
运行：python dds上位机.py
============================================================
"""

import json
import os
import queue
import threading
import time
import tkinter as tk
from datetime import datetime
from tkinter import filedialog, messagebox, ttk

import serial
import serial.tools.list_ports

import matplotlib
matplotlib.use("TkAgg")
import numpy as np
from matplotlib.backends.backend_tkagg import FigureCanvasTkAgg
from matplotlib.figure import Figure

# 中文字体设置（兼容 Windows / Linux / macOS）
matplotlib.rcParams["font.sans-serif"] = [
    "Microsoft YaHei", "SimHei", "Noto Sans CJK SC",
    "WenQuanYi Micro Hei", "PingFang SC", "Arial Unicode MS",
]
matplotlib.rcParams["axes.unicode_minus"] = False

# ==================== 协议常量 ====================
WAVE_MAP = {"正弦波": 0, "方波": 1, "三角波": 2, "锯齿波": 3}
WAVE_LIST = list(WAVE_MAP.keys())
DEFAULT_BAUDRATE = 921600
BAUD_LIST = [9600, 19200, 38400, 57600, 115200, 230400, 460800, 921600]
FRAME_TAIL = "\n"
CONFIG_FILE = "config.json"

# 扩展指令（协议预留）
CMD_AMPLITUDE = "A"
CMD_DUTY = "D"
CMD_READ_WAVE = "R"

# DDS 计算参数
F_CLK = 100_000_000      # 系统时钟 100MHz
ACC_WIDTH = 32           # 相位累加器位宽
SAMPLE_POINTS = 2048      # 波形采样点数

# ==================== 界面配色 ====================
COLOR_BG        = "#eef0f4"   # 窗口背景
COLOR_CARD      = "#ffffff"   # 分组卡片背景
COLOR_CARD_LINE = "#d9dde3"   # 卡片边框
COLOR_TEXT      = "#1f2329"   # 主文字
COLOR_HEADER    = "#ffffff"   # 顶栏背景
COLOR_HEADER_LINE = "#2b6ef3" # 顶栏强调线
COLOR_BAR       = "#1c212b"   # 状态栏背景
COLOR_BAR_TEXT  = "#cfd6e4"   # 状态栏文字
COLOR_ACCENT    = "#2b6ef3"   # 主色（强调按钮）
COLOR_ACCENT_DN = "#1e54c4"
COLOR_PLOT_BG   = "#0e1116"   # 波形图背景
COLOR_GRID      = "#232a36"   # 波形图网格
COLOR_AXIS      = "#8a93a6"   # 波形图坐标文字
COLOR_WAVE_LINE = "#22d3ee"   # 波形线（青色）
COLOR_LOG_BG    = "#0d1117"   # 日志区背景
COLOR_LOG_FG    = "#c9d1d9"   # 日志文字

WINDOW_SIZE = "1040x720"
LEFT_PANEL_WIDTH = 400


# ==================== 工具函数 ====================
def calc_ftw(freq_hz):
    """频率(Hz) → 频率控制字 FTW"""
    ftw = int(freq_hz * (2 ** ACC_WIDTH) / F_CLK)
    return max(0, min(ftw, 2 ** ACC_WIDTH - 1))


def load_config():
    """读取本地配置，文件缺失或损坏时回退默认值"""
    defaults = {
        "port": "", "baudrate": 921600, "wave": "正弦波", "freq": "200",
    }
    if not os.path.exists(CONFIG_FILE):
        return defaults
    try:
        with open(CONFIG_FILE, "r", encoding="utf-8") as f:
            cfg = json.load(f)
        return {**defaults, **cfg}
    except Exception:
        return defaults


def save_config(port, baudrate, wave, freq):
    """保存当前配置到本地文件"""
    cfg = {
        "port": port, "baudrate": baudrate, "wave": wave, "freq": freq,
    }
    try:
        with open(CONFIG_FILE, "w", encoding="utf-8") as f:
            json.dump(cfg, f, indent=2, ensure_ascii=False)
    except Exception:
        pass


# ==================== 主窗口 ====================
class SerialHost(tk.Tk):
    """DDS 信号发生器上位机主窗口"""

    def __init__(self):
        super().__init__()

        # ---- 运行状态 ----
        self.ser = None
        self.is_serial_open = False
        self.receive_queue = queue.Queue()   # 串口接收数据
        self.log_queue = queue.Queue()       # 后台线程日志（线程安全）
        self.receive_thread = None
        self.running = False
        self.sample_buffer = []    # 波形采样缓冲
        self._recv_count = 0       # 接收计数（用于节流绘图）
        self.paused = False
        self.display_points = 256

        self.config = load_config()

        # ---- 窗口 ----
        self.title("DDS 信号发生器上位机")
        self.geometry(WINDOW_SIZE)
        self.minsize(1000, 680)

        self.configure(bg=COLOR_BG)
        self._setup_style()
        self._build_ui()

        # ---- 启动初始化 ----
        self.scan_ports()
        self._apply_config()
        self.protocol("WM_DELETE_WINDOW", self._on_closing)
        self.after(100, self._check_receive)
        self._update_plot()
        self._update_status()

    # ==================== 界面：风格 ====================
    def _setup_style(self):
        """统一 ttk 控件风格（白卡片 + 主色强调）"""
        style = ttk.Style(self)
        try:
            style.theme_use("clam")
        except tk.TclError:
            pass

        style.configure("TFrame", background=COLOR_BG)
        style.configure("TLabel", background=COLOR_CARD, foreground=COLOR_TEXT)
        style.configure(
            "TLabelframe", background=COLOR_CARD, bordercolor=COLOR_CARD_LINE)
        style.configure(
            "TLabelframe.Label", background=COLOR_CARD, foreground="#5a6270",
            font=("Microsoft YaHei", 9, "bold"))
        style.configure("TButton", font=("Microsoft YaHei", 9), padding=(10, 5))
        style.map("TButton",
                  background=[("active", "#e6ebf5")],
                  foreground=[("disabled", "#a0a6b0")])
        style.configure(
            "Accent.TButton", font=("Microsoft YaHei", 9, "bold"),
            background=COLOR_ACCENT, foreground="#ffffff", padding=(10, 5))
        style.map("Accent.TButton",
                  background=[("active", COLOR_ACCENT_DN), ("disabled", "#9db4e8")],
                  foreground=[("disabled", "#eef2fb")])
        style.configure("TCombobox", padding=2, fieldbackground=COLOR_CARD)
        style.configure("TEntry", padding=2, fieldbackground=COLOR_CARD)

    # ==================== 界面：整体布局 ====================
    def _build_ui(self):
        """顶栏 + Notebook(主界面/绘图) + 底部状态栏"""
        self._build_header()

        # ---- Notebook 标签页 ----
        self.notebook = ttk.Notebook(self)
        self.notebook.pack(fill="both", expand=True, padx=5, pady=5)

        # Tab 1：主界面
        self.tab_main = tk.Frame(self.notebook, bg=COLOR_BG)
        self.notebook.add(self.tab_main, text="  主界面  ")

        # Tab 2：波形绘制
        self.tab_draw = tk.Frame(self.notebook, bg=COLOR_BG)
        self.notebook.add(self.tab_draw, text="  波形绘制  ")

        # ---- Tab 1 内部布局 ----
        main = tk.Frame(self.tab_main, bg=COLOR_BG)
        main.pack(fill="both", expand=True, padx=10, pady=(8, 4))

        left_container = tk.Frame(main, bg=COLOR_BG, width=LEFT_PANEL_WIDTH)
        left_container.pack(side="left", fill="y", padx=(0, 10))
        left_container.pack_propagate(False)

        left_canvas = tk.Canvas(left_container, bg=COLOR_BG,
                                highlightthickness=0, width=LEFT_PANEL_WIDTH - 20)
        left_scroll = ttk.Scrollbar(left_container, orient="vertical",
                                    command=left_canvas.yview)
        left_canvas.configure(yscrollcommand=left_scroll.set)

        left_scroll.pack(side="right", fill="y")
        left_canvas.pack(side="left", fill="both", expand=True)

        left = tk.Frame(left_canvas, bg=COLOR_BG)
        left_canvas.create_window((0, 0), window=left, anchor="nw",
                                  width=LEFT_PANEL_WIDTH - 20)

        def _on_left_configure(event):
            left_canvas.configure(scrollregion=left_canvas.bbox("all"))
        left.bind("<Configure>", _on_left_configure)

        def _on_mousewheel(event):
            left_canvas.yview_scroll(int(-1 * (event.delta / 120)), "units")
        left.bind("<MouseWheel>", _on_mousewheel)

        right = tk.Frame(main, bg=COLOR_BG)
        right.pack(side="right", fill="both", expand=True)

        self._build_left_panel(left)
        self._build_plot_panel(right)
        self._build_log_panel(self.tab_main)

        # ---- Tab 2：绘图 ----
        self._build_draw_panel(self.tab_draw)

        # ---- 底部状态栏 ----
        self._build_status_bar()
           
    # ==================== 界面：顶栏 ====================
    def _build_header(self):
        """顶部标题栏"""
        header = tk.Frame(self, bg=COLOR_HEADER, height=44)
        header.pack(fill="x")
        header.pack_propagate(False)

        logo = tk.Canvas(header, width=16, height=16, bg=COLOR_HEADER,
                         highlightthickness=0)
        logo.create_oval(3, 3, 13, 13, fill=COLOR_ACCENT, outline="")
        logo.pack(side="left", padx=(14, 8), pady=14)

        tk.Label(header, text="DDS 信号发生器上位机", bg=COLOR_HEADER,
                 fg=COLOR_TEXT, font=("Microsoft YaHei", 12, "bold")).pack(side="left")

        tk.Label(header, text="协议 921600-8N1  ·  FTW 自动换算",
                 bg=COLOR_HEADER, fg="#9aa1ad",
                 font=("Microsoft YaHei", 9)).pack(side="right", padx=14)

        # 底部强调线
        line = tk.Frame(self, bg=COLOR_HEADER_LINE, height=2)
        line.pack(fill="x")

    # ==================== 界面：左侧控制面板 ====================
    def _build_left_panel(self, parent):
        """串口 / 波形 / 频率 / 扩展 / 扫频 五组白卡片"""
        # ---- 1. 串口配置 ----
        f_serial = ttk.LabelFrame(parent, text="串口配置", padding=8)
        f_serial.pack(fill="x", pady=(0, 6))

        ttk.Label(f_serial, text="端口:").grid(row=0, column=0, sticky="e", padx=(0, 4), pady=2)
        self.comb_port = ttk.Combobox(f_serial, width=13, state="readonly")
        self.comb_port.grid(row=0, column=1, sticky="we", padx=(0, 10), pady=2)

        ttk.Label(f_serial, text="波特率:").grid(row=0, column=2, sticky="e", padx=(0, 4), pady=2)
        self.comb_baud = ttk.Combobox(f_serial, width=9, state="readonly", values=BAUD_LIST)
        self.comb_baud.grid(row=0, column=3, sticky="we", pady=2)

        self.btn_scan = ttk.Button(f_serial, text="刷新端口", command=self.scan_ports)
        self.btn_scan.grid(row=1, column=0, columnspan=2, sticky="we", padx=(0, 4), pady=(5, 2))

        self.btn_switch = ttk.Button(
            f_serial, text="打开串口", style="Accent.TButton", command=self.switch_serial)
        self.btn_switch.grid(row=1, column=2, columnspan=2, sticky="we", pady=(5, 2))

        f_serial.columnconfigure(1, weight=1)
        f_serial.columnconfigure(3, weight=1)

        # ---- 2. 波形控制 ----
        f_wave = ttk.LabelFrame(parent, text="波形控制", padding=8)
        f_wave.pack(fill="x", pady=5)

        ttk.Label(f_wave, text="波形类型:").grid(row=0, column=0, sticky="e", padx=(0, 4), pady=2)
        self.comb_wave = ttk.Combobox(f_wave, width=10, state="readonly", values=WAVE_LIST)
        self.comb_wave.grid(row=0, column=1, sticky="we", padx=(0, 8), pady=2)

        self.btn_set_wave = ttk.Button(f_wave, text="设置波形", command=self.send_wave_cmd)
        self.btn_set_wave.grid(row=0, column=2, sticky="we", padx=(0, 4), pady=2)

        self.btn_read_wave = ttk.Button(f_wave, text="读取波形", command=self.read_wave_cmd)
        self.btn_read_wave.grid(row=0, column=3, sticky="we", pady=2)

        f_wave.columnconfigure(1, weight=1)
        f_wave.columnconfigure(2, weight=1)
        f_wave.columnconfigure(3, weight=1)

        # ---- 3. 频率控制 ----
        f_freq = ttk.LabelFrame(parent, text="频率控制", padding=8)
        f_freq.pack(fill="x", pady=5)

        ttk.Label(f_freq, text="频率(Hz):").grid(row=0, column=0, sticky="e", padx=(0, 4), pady=2)
        self.entry_freq = ttk.Entry(f_freq, width=10)
        self.entry_freq.grid(row=0, column=1, sticky="we", padx=(0, 8), pady=2)

        self.btn_set_freq = ttk.Button(f_freq, text="设置频率", command=self.send_freq_cmd)
        self.btn_set_freq.grid(row=0, column=2, sticky="we", padx=(0, 4), pady=2)

        self.btn_freq_minus = ttk.Button(f_freq, text="-10", command=lambda: self.step_freq(-10))
        self.btn_freq_minus.grid(row=0, column=3, sticky="we", padx=(0, 4), pady=2)

        self.btn_freq_plus = ttk.Button(f_freq, text="+10", command=lambda: self.step_freq(10))
        self.btn_freq_plus.grid(row=0, column=4, sticky="we", pady=2)

        f_freq.columnconfigure(1, weight=1)
        f_freq.columnconfigure(2, weight=1)
        f_freq.columnconfigure(3, weight=1)
        f_freq.columnconfigure(4, weight=1)

        # ---- 4. 工作模式 ----
        f_mode = ttk.LabelFrame(parent, text="工作模式", padding=8)
        f_mode.pack(fill="x", pady=5)

        mode_list = [
            ("正常",     "M0"),
            ("跳频",     "M1"),
            ("扫频",     "M2"),
            ("AM 调制",  "M3"),
            ("FM 调制",  "M4"),
            ("任意波形", "M5"),
            ("CPFSK",    "M6"),
        ]

        for i, (name, cmd) in enumerate(mode_list):
            btn = ttk.Button(
                f_mode, text=name,
                command=lambda c=cmd, n=name: self.send_mode_cmd(c, n))
            btn.grid(row=i // 3, column=i % 3, sticky="we", padx=2, pady=2)

        for i in range(3):
            f_mode.columnconfigure(i, weight=1)

        # ---- 5. 调制参数 ----
        f_mod = ttk.LabelFrame(parent, text="调制参数", padding=8)
        f_mod.pack(fill="x", pady=5)

        # 调制深度
        tk.Label(f_mod, text="调制深度:").grid(row=0, column=0, sticky="e", padx=(0, 4))
        self.scale_depth = ttk.Scale(
            f_mod, from_=0, to=100, orient="horizontal",
            command=lambda v: self.lbl_depth.config(text=f"{int(float(v))}"))
        self.scale_depth.set(50)
        self.scale_depth.grid(row=0, column=1, sticky="we", padx=(0, 4))
        self.scale_depth.bind("<ButtonRelease-1>", lambda e: self.send_param_cmd())
        self.lbl_depth = tk.Label(f_mod, text="50", width=4)
        self.lbl_depth.grid(row=0, column=2)

        # 调制频率
        tk.Label(f_mod, text="调制频率:").grid(row=1, column=0, sticky="e", padx=(0, 4))
        self.scale_mfreq = ttk.Scale(
            f_mod, from_=0, to=100, orient="horizontal",
            command=lambda v: self.lbl_mfreq.config(text=f"{int(float(v))}"))
        self.scale_mfreq.set(50)
        self.scale_mfreq.grid(row=1, column=1, sticky="we", padx=(0, 4))
        self.scale_mfreq.bind("<ButtonRelease-1>", lambda e: self.send_param_cmd())
        self.lbl_mfreq = tk.Label(f_mod, text="50", width=4)
        self.lbl_mfreq.grid(row=1, column=2)

        # 应用按钮（可选，兜底）
        ttk.Button(f_mod, text="应用参数", command=self.send_param_cmd).grid(
            row=2, column=0, columnspan=3, sticky="we", pady=(6, 0))

        f_mod.columnconfigure(1, weight=1)

    # ==================== 界面：右侧波形区（深色示波器） ====================
    def _build_plot_panel(self, parent):
        """深色示波器风格波形显示"""
        f_plot = ttk.LabelFrame(parent, text="波形实时显示", padding=6)
        f_plot.pack(fill="both", expand=True)

        self.fig = Figure(figsize=(6.2, 4.4), dpi=100, facecolor=COLOR_PLOT_BG)
        self.ax = self.fig.add_subplot(111)
        self.ax.set_facecolor(COLOR_PLOT_BG)
        self.ax.set_title("输出波形", fontsize=12, color=COLOR_AXIS)
        self.ax.set_xlabel("采样点", color=COLOR_AXIS)
        self.ax.set_ylabel("幅度", color=COLOR_AXIS)
        self.ax.grid(True, alpha=0.35, color=COLOR_GRID)
        self.ax.set_xlim(0, SAMPLE_POINTS)
        self.ax.set_ylim(-1.25, 1.25)
        for spine in self.ax.spines.values():
            spine.set_color("#3a4150")
        self.ax.tick_params(colors=COLOR_AXIS, labelsize=9)

        (self.plot_line,) = self.ax.plot([], [], lw=2.0, color=COLOR_WAVE_LINE)

        self.fig.tight_layout()
        self.canvas = FigureCanvasTkAgg(self.fig, master=f_plot)
        self.canvas.get_tk_widget().pack(fill="both", expand=True)
        self.canvas.draw()

        # 顶部控制栏：显示点数下拉框 + 暂停按钮
        ctrl = tk.Frame(f_plot, bg=COLOR_CARD)
        ctrl.pack(side="top", fill="x", pady=(0, 4))

        tk.Label(ctrl, text="显示点数:", bg=COLOR_CARD, fg=COLOR_TEXT,
                font=("Microsoft YaHei", 9)).pack(side="left", padx=(4, 2))

        self.comb_display = ttk.Combobox(
            ctrl, width=8, state="readonly",
            values=[32, 64, 128, 256, 512, 1024, 2048])
        self.comb_display.current(3)   # 默认 256
        self.comb_display.pack(side="left", padx=(0, 8))
        self.comb_display.bind("<<ComboboxSelected>>", self._on_display_change)

        self.btn_pause = ttk.Button(ctrl, text="暂停", command=self._toggle_pause)
        self.btn_pause.pack(side="left", fill="x", expand=True)

    # ==================== 界面：底部日志区 ====================
    def _build_log_panel(self,parent):
        """横跨全宽的收发日志区（按钮右侧竖排，Text 固定高度）"""
        f_log = ttk.LabelFrame(parent, text="状态与数据回显", padding=6)
        f_log.pack(side="bottom", fill="x", padx=10, pady=(0, 6))

        # 右侧竖排操作按钮
        btn_col = tk.Frame(f_log, bg=COLOR_CARD)
        btn_col.pack(side="right", fill="y", padx=(6, 0))
        self.btn_export_log = ttk.Button(btn_col, text="导出日志", command=self.export_log)
        self.btn_export_log.pack(side="top", fill="x", pady=(0, 4))
        self.btn_clear_log = ttk.Button(btn_col, text="清空日志", command=self.clear_log)
        self.btn_clear_log.pack(side="top", fill="x")

        # 日志文本（固定高度，不随内容拉伸产生空白）
        self.text_log = tk.Text(
            f_log, height=5, wrap="word", state="disabled",
            bg=COLOR_LOG_BG, fg=COLOR_LOG_FG,
            font=("Consolas", 9), insertbackground=COLOR_LOG_FG,
            relief="flat", padx=8, pady=5)
        self.text_log.pack(side="left", fill="both", expand=True)

        # 滚动条（必须先有 text_log 再引用其 yview）
        sb = ttk.Scrollbar(f_log, command=self.text_log.yview)
        sb.pack(side="right", fill="y")
        self.text_log.configure(yscrollcommand=sb.set)

    def _build_draw_panel(self, parent):
        """波形绘制界面"""
        # 画布
        canvas = tk.Canvas(parent, width=900, height=400, bg='black',
                        highlightthickness=0)
        canvas.pack(padx=10, pady=10)

        # 网格
        for i in range(0, 900, 50):
            canvas.create_line(i, 0, i, 400, fill='#333')
        for i in range(0, 400, 50):
            canvas.create_line(0, i, 900, i, fill='#333')

        self.draw_points = [2048] * 1024

        def redraw():
            canvas.delete("wave")
            pts = []
            for i in range(1024):
                x = i / 1024 * 900
                y = 400 - (self.draw_points[i] / 4095 * 400)
                pts.append(x)
                pts.append(y)
            canvas.create_line(pts, fill='cyan', width=2, tags="wave")

        def on_drag(event):
            x = max(0, min(event.x, 899))
            y = max(0, min(event.y, 399))
            val = int((400 - y) / 400 * 4095)
            idx = int(x / 900 * 1024)
            for i in range(max(0, idx - 2), min(1024, idx + 3)):
                self.draw_points[i] = val
            redraw()

        canvas.bind("<B1-Motion>", on_drag)
        canvas.bind("<Button-1>", on_drag)

        self.draw_canvas = canvas
        self.draw_redraw = redraw

        # 按钮区
        btn_frame = tk.Frame(parent, bg=COLOR_BG)
        btn_frame.pack(fill='x', padx=10, pady=5)

        ttk.Button(btn_frame, text="清空", command=self._draw_clear).pack(side='left', padx=3)
        ttk.Button(btn_frame, text="正弦波", command=self._draw_sin).pack(side='left', padx=3)
        ttk.Button(btn_frame, text="三角波", command=self._draw_tri).pack(side='left', padx=3)
        ttk.Button(btn_frame, text="方波", command=self._draw_square).pack(side='left', padx=3)
        ttk.Button(btn_frame, text="上传到 FPGA", command=self._draw_upload,
                style="Accent.TButton").pack(side='right', padx=3)

        # 状态提示
        self.draw_status = tk.Label(parent, text="用鼠标画波形，或点预设按钮",
                                    bg=COLOR_BG, fg=COLOR_TEXT)
        self.draw_status.pack(pady=5)

        redraw()
        

    def _draw_clear(self):
        self.draw_points = [2048] * 1024
        self.draw_redraw()

    def _draw_sin(self):
        import math
        for i in range(1024):
            self.draw_points[i] = int(2048 + 2047 * math.sin(2 * math.pi * i / 1024))
        self.draw_redraw()

    def _draw_tri(self):
        for i in range(1024):
            if i < 512:
                self.draw_points[i] = int(i / 511 * 4095)
            else:
                self.draw_points[i] = int((1023 - i) / 511 * 4095)
        self.draw_redraw()

    def _draw_square(self):
        for i in range(1024):
            self.draw_points[i] = 4095 if i < 512 else 0
        self.draw_redraw()

    def _draw_upload(self):
        """上传波形到 FPGA"""
        if not self.is_serial_open:
            messagebox.showwarning("提示", "请先打开串口")
            return

        self.draw_status.config(text="切换到 AWG 模式...")
        self._send("M5", "切换到任意波形模式")
        self.update()
        time.sleep(0.1)

        self.draw_status.config(text="上传中...")
        for i in range(1024):
            val = max(0, min(self.draw_points[i], 4095))
            self._send(f"U{i},{val}", silent=True)
            if i % 20 == 0:
                self.draw_status.config(text=f"上传 {i}/1024")
                self.update()
            time.sleep(0.002)

        self.draw_status.config(text="上传完成！切回主界面看波形")
    
            # ==================== 界面：底部状态栏 ====================
    def _build_status_bar(self):
        """深色状态栏"""
        bar = tk.Frame(self, bg=COLOR_BAR, height=30)
        bar.pack(side="bottom", fill="x")
        bar.pack_propagate(False)

        self.status_dot = tk.Canvas(bar, width=12, height=12, bg=COLOR_BAR,
                                    highlightthickness=0)
        self.status_dot.pack(side="left", padx=(14, 6), pady=9)
        self._dot_id = self.status_dot.create_oval(2, 2, 10, 10, fill="#8a93a6", outline="")

        self.lbl_status = tk.Label(bar, text="未连接", bg=COLOR_BAR, fg="#e2e8f0",
                                   font=("Microsoft YaHei", 9, "bold"))
        self.lbl_status.pack(side="left", padx=(0, 16))

        self.lbl_status_info = tk.Label(bar, text="端口: --   ·   波特率: 115200",
                                        bg=COLOR_BAR, fg=COLOR_BAR_TEXT,
                                        font=("Microsoft YaHei", 9))
        self.lbl_status_info.pack(side="left", padx=(0, 16))

        self.lbl_status_mode = tk.Label(bar, text="模式: 正常", bg=COLOR_BAR,
                                fg=COLOR_BAR_TEXT, font=("Microsoft YaHei", 9))
        self.lbl_status_mode.pack(side="left", padx=(0, 16))

        self.lbl_status_wave = tk.Label(bar, text="波形: 正弦波", bg=COLOR_BAR,
                                        fg=COLOR_BAR_TEXT, font=("Microsoft YaHei", 9))
        self.lbl_status_wave.pack(side="left", padx=(0, 16))

        self.lbl_status_freq = tk.Label(bar, text="频率: --", bg=COLOR_BAR,
                                        fg=COLOR_BAR_TEXT, font=("Microsoft YaHei", 9))
        self.lbl_status_freq.pack(side="left", padx=(0, 16))


    # ==================== 波形生成与显示 ====================
    def _gen_wave(self, wave_code, amp_ratio=1.0, points=SAMPLE_POINTS):
        """生成指定波形的采样数据（示意用）"""
        x = np.linspace(0, 2 * np.pi, points, endpoint=False)
        if wave_code == 0:        # 正弦波
            y = np.sin(x)
        elif wave_code == 1:      # 方波
            y = np.sign(np.sin(x))
        elif wave_code == 2:      # 三角波
            t = x / (2 * np.pi)
            y = 2 * np.abs(2 * (t - np.floor(t + 0.5))) - 1
        else:                     # 锯齿波
            t = x / (2 * np.pi)
            y = 2 * (t - np.floor(t)) - 1
        return y * amp_ratio

    def _get_amp_ratio(self):
        """读取幅值输入并转为 0~1 比例"""
        return 1.0

    def _update_plot(self):
        """按当前波形/幅值刷新本地示意波形"""
        try:
            wave_code = self.comb_wave.current()
        except tk.TclError:
            return
        y = self._gen_wave(wave_code, self._get_amp_ratio())
        self.plot_line.set_data(np.arange(len(y)), y)
        self.canvas.draw_idle()

    def _plot_samples(self, samples):
        if len(samples) < 2:
            return
        samples = samples[-self.display_points:]
        y = np.array(samples, dtype=float) / 4095.0 * 2.0 - 1.0
        x = np.arange(len(y))
        self.plot_line.set_data(x, y)
        self.ax.set_xlim(0, self.display_points)
        self.canvas.draw_idle()

    # ==================== 串口功能 ====================
    def scan_ports(self):
        """扫描本机可用串口"""
        devices = [p.device for p in serial.tools.list_ports.comports()]
        self.comb_port["values"] = devices
        if devices:
            saved = self.config.get("port", "")
            if saved in devices:
                self.comb_port.current(devices.index(saved))
            else:
                self.comb_port.current(0)
            self._append_log(f"扫描完成，共发现 {len(devices)} 个串口")
        else:
            self.comb_port.set("")
            self._append_log("未检测到可用串口")

    def switch_serial(self):
        """打开 / 关闭串口"""
        if self.is_serial_open:
            self._close_serial()
        else:
            self._open_serial()

    def _open_serial(self):
        if self.is_serial_open:
            return
        port = self.comb_port.get()
        try:
            baud = int(self.comb_baud.get())
        except ValueError:
            messagebox.showwarning("提示", "波特率无效")
            return
        if not port:
            messagebox.showwarning("提示", "请先选择串口端口")
            return

        try:
            self.ser = serial.Serial(port, baud, timeout=0)
        except Exception as e:
            messagebox.showerror("错误", f"串口打开失败：{e}")
            return

        self.is_serial_open = True
        self.running = True
        self.receive_thread = threading.Thread(target=self._receive_loop, daemon=True)
        self.receive_thread.start()

        self.btn_switch.config(text="关闭串口")
        self._append_log(f"串口 {port} 打开成功，波特率 {baud}")
        self._update_status()

    def _close_serial(self):
        self.running = False

        # 关键：等接收线程自己退出，再去关串口
        if self.receive_thread and self.receive_thread.is_alive():
            self.receive_thread.join(timeout=1.0)

        try:
            if self.ser and self.ser.is_open:
                self.ser.close()
        except Exception:
            pass
        self.ser = None
        self.is_serial_open = False
        self.btn_switch.config(text="打开串口")
        self._append_log("串口已关闭")
        self._update_status()

    # ==================== 指令发送 ====================
    def _send(self, payload, log_msg=None, silent=False):
        """统一发送入口，组帧并写串口"""
        if not self.is_serial_open or self.ser is None:
            messagebox.showwarning("提示", "请先打开串口")
            return False
        cmd = f"{payload}{FRAME_TAIL}"
        try:
            self.ser.write(cmd.encode("utf-8"))
            if not silent:
                self._append_log(log_msg if log_msg else f"发送: {payload}")
            return True
        except Exception as e:
            self._append_log(f"发送失败: {e}")
            return False

    def send_wave_cmd(self):
        """发送波形设置指令 W{0-3}"""
        wave = self.comb_wave.get()
        code = WAVE_MAP.get(wave, 0)
        if self._send(f"W{code}", f"发送: W{code}（{wave}）"):
            self._update_plot()

    def send_freq_cmd(self, freq_hz=None):
        """发送频率指令 F{FTW}，自动换算"""
        if freq_hz is None:
            try:
                freq_hz = int(self.entry_freq.get().strip())
            except ValueError:
                messagebox.showwarning("提示", "频率请输入正整数")
                return
        if freq_hz <= 0 or freq_hz > 1_000_000:
            messagebox.showwarning("提示", "频率范围：1 ~ 1000000 Hz")
            return

        ftw = calc_ftw(freq_hz)
        if self._send(f"F{ftw}", f"发送: F{ftw}（{freq_hz}Hz）"):
            self.entry_freq.delete(0, "end")
            self.entry_freq.insert(0, str(freq_hz))
            self._update_status()
            if self.paused:
                self.sample_buffer = []
                self.after(150, lambda: self._plot_samples(self.sample_buffer))

    def send_mode_cmd(self, cmd, name):
        """发送模式切换命令 M0~M5"""
        if self._send(cmd, f"发送: {cmd}（{name}）"):
            self.lbl_status_mode.config(text=f"模式: {name}")

    def send_param_cmd(self):
        """发送调制参数 K(深度) 和 L(频率)"""
        depth = int(self.scale_depth.get())
        freq  = int(self.scale_mfreq.get())
        self._send(f"K{depth}", f"发送: K{depth}（调制深度 {depth}）")
        self._send(f"L{freq}",  f"发送: L{freq}（调制频率 {freq}）")
    def step_freq(self, delta):
        """频率步进微调"""
        try:
            cur = int(self.entry_freq.get().strip())
        except ValueError:
            cur = 1000
        self.send_freq_cmd(max(1, cur + delta))

    def read_wave_cmd(self):
        """请求 FPGA 回传波形采样"""
        self._send(CMD_READ_WAVE, "发送: R（请求波形采样）")

        # ==================== 数据接收 ====================
    def _receive_loop(self):
        buf = bytearray()
        while self.running:
            try:
                if self.ser is None or not self.ser.is_open:
                    break
                n = self.ser.in_waiting
                if n > 0:
                    buf.extend(self.ser.read(n))
                    while len(buf) >= 4:
                        if buf[0] != 0xAA:
                            buf = buf[1:]
                            continue
                        if buf[3] != 0x55:
                            buf = buf[1:]
                            continue
                        low  = buf[1]
                        high = buf[2]
                        value = (high << 8) | low
                        self.sample_buffer.append(value)
                        if len(self.sample_buffer) > SAMPLE_POINTS:
                            self.sample_buffer = self.sample_buffer[-SAMPLE_POINTS:]
                        buf = buf[4:]
                else:
                    time.sleep(0.005)
            except Exception:
                break
        self.running = False

    def _toggle_pause(self):
        self.paused = not self.paused
        self.btn_pause.config(text="继续" if self.paused else "暂停")
        if not self.paused:
            self.sample_buffer = []
    def _on_display_change(self, event=None):
        self.display_points = int(self.comb_display.get())
        if len(self.sample_buffer) >= 2:
            self._plot_samples(self.sample_buffer)

    def _check_receive(self):
        try:
            for _ in range(20):
                if self.log_queue.empty(): break
                self._append_log(self.log_queue.get_nowait())

            if self.paused:
                if len(self.sample_buffer) >= SAMPLE_POINTS:
                    self._plot_samples(self.sample_buffer[:SAMPLE_POINTS])
                    self.sample_buffer = []
            else:
                if len(self.sample_buffer) >= 2:
                    self._plot_samples(self.sample_buffer)
        except Exception as e:
            pass    # 出错不崩，继续下一轮

        self.after(100, self._check_receive)   # 50 → 100ms，减轻负担

    def _handle_received(self, value):
        """接收到一个采样点数值（0~4095）"""
        self.sample_buffer.append(value)
        if len(self.sample_buffer) > SAMPLE_POINTS:
            self.sample_buffer = self.sample_buffer[-SAMPLE_POINTS:]

        self._recv_count += 1
        # 每收到 8 个点刷新一次（节流）
        if self._recv_count >= 8:
            self._recv_count = 0
            self._plot_samples(self.sample_buffer)

    # ==================== 日志与状态 ====================
    def _append_log(self, msg):
        """向日志区添加一条带时间戳的记录"""
        line = f"[{datetime.now().strftime('%H:%M:%S')}] {msg}\n"
        self.text_log.config(state="normal")
        self.text_log.insert("end", line)
        self.text_log.see("end")
        self.text_log.config(state="disabled")

    def _update_status(self):
        """刷新底部状态栏"""
        if self.is_serial_open and self.ser and self.ser.is_open:
            self.status_dot.itemconfig(self._dot_id, fill="#22c55e")
            self.lbl_status.config(text="已连接")
            self.lbl_status_info.config(
                text=f"端口: {self.comb_port.get()}   ·   波特率: {self.comb_baud.get()}")
        else:
            self.status_dot.itemconfig(self._dot_id, fill="#8a93a6")
            self.lbl_status.config(text="未连接")
            self.lbl_status_info.config(text="端口: --   ·   波特率: 115200")

        self.lbl_status_wave.config(text=f"波形: {self.comb_wave.get()}")
        freq = self.entry_freq.get().strip()
        self.lbl_status_freq.config(text=f"频率: {freq} Hz" if freq else "频率: --")
    def export_log(self):
        """导出日志为 txt 文件"""
        content = self.text_log.get("1.0", "end").strip()
        if not content:
            messagebox.showinfo("提示", "日志为空，无需导出")
            return

        default_name = f"DDS上位机日志_{datetime.now().strftime('%Y%m%d_%H%M%S')}.txt"
        filename = filedialog.asksaveasfilename(
            defaultextension=".txt",
            filetypes=[("文本文件", "*.txt"), ("所有文件", "*.*")],
            initialfile=default_name)
        if not filename:
            return
        try:
            with open(filename, "w", encoding="utf-8") as f:
                f.write(content)
            messagebox.showinfo("成功", f"日志已保存：\n{filename}")
        except Exception as e:
            messagebox.showerror("错误", f"保存失败：{e}")

    def clear_log(self):
        """清空日志区"""
        if messagebox.askyesno("确认", "确定清空全部日志？"):
            self.text_log.config(state="normal")
            self.text_log.delete("1.0", "end")
            self.text_log.config(state="disabled")

    # ==================== 配置应用与退出 ====================
    def _apply_config(self):
        """把记忆的配置应用到控件"""
        cfg = self.config
        baud = cfg.get("baudrate", DEFAULT_BAUDRATE)
        if baud in BAUD_LIST:
            self.comb_baud.current(BAUD_LIST.index(baud))
        else:
            self.comb_baud.current(BAUD_LIST.index(DEFAULT_BAUDRATE))

        wave = cfg.get("wave", "正弦波")
        if wave in WAVE_LIST:
            self.comb_wave.current(WAVE_LIST.index(wave))

        self.entry_freq.delete(0, "end")
        self.entry_freq.insert(0, cfg.get("freq", "200"))

    def _on_closing(self):
        """关闭窗口：保存配置并释放资源"""
        save_config(
            port=self.comb_port.get(),
            baudrate=int(self.comb_baud.get() or DEFAULT_BAUDRATE),
            wave=self.comb_wave.get(),
            freq=self.entry_freq.get().strip() or "200",
        )
        self.running = False
        try:
            if self.ser and self.ser.is_open:
                self.ser.close()
        except Exception:
            pass
        self.destroy()


if __name__ == "__main__":
    app = SerialHost()
    app.mainloop()
