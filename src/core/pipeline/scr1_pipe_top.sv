
module scr1_pipe_top (
    // Common
    input   logic                                       pipe_rst_n,                 // Pipe reset
    input   logic                                       clk,                        // Pipe clock

    // Instruction Memory Interface
    output  logic                                       pipe2imem_req_o,            // IMEM request
    output  type_scr1_mem_cmd_e                         pipe2imem_cmd_o,            // IMEM command
    output  logic [`SCR1_IMEM_AWIDTH-1:0]               pipe2imem_addr_o,           // IMEM address
    input   logic                                       imem2pipe_req_ack_i,        // IMEM request acknowledge
    input   logic [`SCR1_IMEM_DWIDTH-1:0]               imem2pipe_rdata_i,          // IMEM read data
    input   type_scr1_mem_resp_e                        imem2pipe_resp_i,           // IMEM response

    // Data Memory Interface
    output  logic                                       pipe2dmem_req_o,            // DMEM request
    output  type_scr1_mem_cmd_e                         pipe2dmem_cmd_o,            // DMEM command
    output  type_scr1_mem_width_e                       pipe2dmem_width_o,          // DMEM data width
    output  logic [`SCR1_DMEM_AWIDTH-1:0]               pipe2dmem_addr_o,           // DMEM address
    output  logic [`SCR1_DMEM_DWIDTH-1:0]               pipe2dmem_wdata_o,          // DMEM write data
    input   logic                                       dmem2pipe_req_ack_i,        // DMEM request acknowledge
    input   logic [`SCR1_DMEM_DWIDTH-1:0]               dmem2pipe_rdata_i,          // DMEM read data
    input   type_scr1_mem_resp_e                        dmem2pipe_resp_i,           // DMEM response
    input   logic                                       soc2pipe_irq_ext_i,         // External interrupt request
    input   logic                                       soc2pipe_irq_soft_i,        // Software generated interrupt request
    input   logic                                       soc2pipe_irq_mtimer_i,      // Machine timer interrupt request

    // Memory-mapped external timer
    input   logic [63:0]                                soc2pipe_mtimer_val_i,      // Machine timer value
    // Fuse
    input   logic [`SCR1_XLEN-1:0]                      soc2pipe_fuse_mhartid_i,     // Fuse MHARTID value
    output   logic                                       clkout,                        // Pipe clock out for ram
);

//-------------------------------------------------------------------------------
// Local signals declaration
//-------------------------------------------------------------------------------

// Pipeline control
logic [`SCR1_XLEN-1:0]                      curr_pc;                // Current PC
logic [`SCR1_XLEN-1:0]                      next_pc;                // Is written to MEPC on interrupt trap
logic                                       new_pc_req;             // New PC request (jumps, branches, traps etc)
logic [`SCR1_XLEN-1:0]                      new_pc;                 // New PC

logic                                       stop_fetch;             // Stop IFU
logic                                       exu_exc_req;            // Exception request
logic                                       brkpt;                  // Breakpoint (sw) on current instruction
logic                                       exu_init_pc;            // Reset exit
logic                                       wfi_run2halt;           // Transition to WFI halted state
logic                                       instret;                // Instruction retirement (with or without exception)
logic                                       instret_nexc;           // Instruction retirement (without exception)

// IFU <-> IDU
logic                                       ifu2idu_vd;             // IFU request
logic [`SCR1_IMEM_DWIDTH-1:0]               ifu2idu_instr;          // IFU instruction
logic                                       ifu2idu_imem_err;       // IFU instruction access fault
logic                                       ifu2idu_err_rvi_hi;     // 1 - imem fault when trying to fetch second half of an unaligned RVI instruction
logic                                       idu2ifu_rdy;            // IDU ready for new data

// IDU <-> EXU
logic                                       idu2exu_req;            // IDU request
type_scr1_exu_cmd_s                         idu2exu_cmd;            // IDU command (see scr1_riscv_isa_decoding.svh)
logic                                       idu2exu_use_rs1;        // Instruction uses rs1
logic                                       idu2exu_use_rs2;        // Instruction uses rs2
logic                                       idu2exu_use_rd;         // Instruction uses rd
logic                                       idu2exu_use_imm;        // Instruction uses immediate
logic                                       exu2idu_rdy;            // EXU ready for new data

// EXU <-> MPRF
logic [`SCR1_MPRF_AWIDTH-1:0]               exu2mprf_rs1_addr;      // MPRF rs1 read address
logic [`SCR1_XLEN-1:0]                      mprf2exu_rs1_data;      // MPRF rs1 read data
logic [`SCR1_MPRF_AWIDTH-1:0]               exu2mprf_rs2_addr;      // MPRF rs2 read address
logic [`SCR1_XLEN-1:0]                      mprf2exu_rs2_data;      // MPRF rs2 read data
logic                                       exu2mprf_w_req;         // MPRF write request
logic [`SCR1_MPRF_AWIDTH-1:0]               exu2mprf_rd_addr;       // MPRF rd write address
logic [`SCR1_XLEN-1:0]                      exu2mprf_rd_data;       // MPRF rd write data

// EXU <-> CSR
logic [SCR1_CSR_ADDR_WIDTH-1:0]             exu2csr_rw_addr;        // CSR read/write address
logic                                       exu2csr_r_req;          // CSR read request
logic [`SCR1_XLEN-1:0]                      csr2exu_r_data;         // CSR read data
logic                                       exu2csr_w_req;          // CSR write request
type_scr1_csr_cmd_sel_e                     exu2csr_w_cmd;          // CSR write command
logic [`SCR1_XLEN-1:0]                      exu2csr_w_data;         // CSR write data
logic                                       csr2exu_rw_exc;         // CSR read/write access exception

// EXU <-> CSR event interface
logic                                       exu2csr_take_irq;       // Take IRQ trap
logic                                       exu2csr_take_exc;       // Take exception trap
logic                                       exu2csr_mret_update;    // MRET update CSR
logic                                       exu2csr_mret_instr;     // MRET instruction
type_scr1_exc_code_e                        exu2csr_exc_code;       // Exception code (see scr1_arch_types.svh)
logic [`SCR1_XLEN-1:0]                      exu2csr_trap_val;       // Trap value
logic [`SCR1_XLEN-1:0]                      csr2exu_new_pc;         // Exception/IRQ/MRET new PC
logic                                       csr2exu_irq;            // IRQ request
logic                                       csr2exu_ip_ie;          // Some IRQ pending and locally enabled
logic                                       csr2exu_mstatus_mie_up; // MSTATUS or MIE update in the current cycle


logic                                       exu_busy;


logic                                       pipe2clkctl_wake_req_o;

//-------------------------------------------------------------------------------
// Pipeline logic
//-------------------------------------------------------------------------------
assign stop_fetch   = wfi_run2halt;


//-------------------------------------------------------------------------------
// Instruction fetch unit
//-------------------------------------------------------------------------------
scr1_pipe_ifu i_pipe_ifu (
    .rst_n                    (pipe_rst_n         ),
    .clk                      (clk                ),
    // Instruction memory interface
    .imem2ifu_req_ack_i       (imem2pipe_req_ack_i),
    .ifu2imem_req_o           (pipe2imem_req_o    ),
    .ifu2imem_cmd_o           (pipe2imem_cmd_o    ),
    .ifu2imem_addr_o          (pipe2imem_addr_o   ),
    .imem2ifu_rdata_i         (imem2pipe_rdata_i  ),
    .imem2ifu_resp_i          (imem2pipe_resp_i   ),
    // New PC interface
    .exu2ifu_pc_new_req_i     (new_pc_req         ),
    .exu2ifu_pc_new_i         (new_pc             ),
    .pipe2ifu_stop_fetch_i    (stop_fetch         ),
    // IFU <-> IDU interface
    .idu2ifu_rdy_i            (idu2ifu_rdy        ),
    .ifu2idu_instr_o          (ifu2idu_instr      ),
    .ifu2idu_imem_err_o       (ifu2idu_imem_err   ),
    .ifu2idu_err_rvi_hi_o     (ifu2idu_err_rvi_hi ),
    .ifu2idu_vd_o             (ifu2idu_vd         )
);

//-------------------------------------------------------------------------------
// Instruction decode unit
//-------------------------------------------------------------------------------
scr1_pipe_idu i_pipe_idu (
    .idu2ifu_rdy_o          (idu2ifu_rdy       ),
    .ifu2idu_instr_i        (ifu2idu_instr     ),
    .ifu2idu_imem_err_i     (ifu2idu_imem_err  ),
    .ifu2idu_err_rvi_hi_i   (ifu2idu_err_rvi_hi),
    .ifu2idu_vd_i           (ifu2idu_vd        ),
    .idu2exu_req_o          (idu2exu_req       ),
    .idu2exu_cmd_o          (idu2exu_cmd       ),
    .idu2exu_use_rs1_o      (idu2exu_use_rs1   ),
    .idu2exu_use_rs2_o      (idu2exu_use_rs2   ),
    .idu2exu_use_rd_o       (idu2exu_use_rd    ),
    .idu2exu_use_imm_o      (idu2exu_use_imm   ),
    .exu2idu_rdy_i          (exu2idu_rdy       )
);

//-------------------------------------------------------------------------------
// Execution unit
//-------------------------------------------------------------------------------
scr1_pipe_exu i_pipe_exu (
    .rst_n                          (pipe_rst_n              ),
    .clk                            (clk                     ),
    // IDU <-> EXU interface
    .idu2exu_req_i                  (idu2exu_req             ),
    .exu2idu_rdy_o                  (exu2idu_rdy             ),
    .idu2exu_cmd_i                  (idu2exu_cmd             ),
    .idu2exu_use_rs1_i              (idu2exu_use_rs1         ),
    .idu2exu_use_rs2_i              (idu2exu_use_rs2         ),
    .idu2exu_use_rd_i               (idu2exu_use_rd          ),
    .idu2exu_use_imm_i              (idu2exu_use_imm         ),
    // EXU <-> MPRF interface
    .exu2mprf_rs1_addr_o            (exu2mprf_rs1_addr       ),
    .mprf2exu_rs1_data_i            (mprf2exu_rs1_data       ),
    .exu2mprf_rs2_addr_o            (exu2mprf_rs2_addr       ),
    .mprf2exu_rs2_data_i            (mprf2exu_rs2_data       ),
    .exu2mprf_w_req_o               (exu2mprf_w_req          ),
    .exu2mprf_rd_addr_o             (exu2mprf_rd_addr        ),
    .exu2mprf_rd_data_o             (exu2mprf_rd_data        ),
    // EXU <-> CSR read/write interface
    .exu2csr_rw_addr_o              (exu2csr_rw_addr         ),
    .exu2csr_r_req_o                (exu2csr_r_req           ),
    .csr2exu_r_data_i               (csr2exu_r_data          ),
    .exu2csr_w_req_o                (exu2csr_w_req           ),
    .exu2csr_w_cmd_o                (exu2csr_w_cmd           ),
    .exu2csr_w_data_o               (exu2csr_w_data          ),
    .csr2exu_rw_exc_i               (csr2exu_rw_exc          ),
    // EXU <-> CSR event interface
    .exu2csr_take_irq_o             (exu2csr_take_irq        ),
    .exu2csr_take_exc_o             (exu2csr_take_exc        ),
    .exu2csr_mret_update_o          (exu2csr_mret_update     ),
    .exu2csr_mret_instr_o           (exu2csr_mret_instr      ),
    .exu2csr_exc_code_o             (exu2csr_exc_code        ),
    .exu2csr_trap_val_o             (exu2csr_trap_val        ),
    .csr2exu_new_pc_i               (csr2exu_new_pc          ),
    .csr2exu_irq_i                  (csr2exu_irq             ),
    .csr2exu_ip_ie_i                (csr2exu_ip_ie           ),
    .csr2exu_mstatus_mie_up_i       (csr2exu_mstatus_mie_up  ),
    // EXU <-> DMEM interface
    .exu2dmem_req_o                 (pipe2dmem_req_o         ),
    .exu2dmem_cmd_o                 (pipe2dmem_cmd_o         ),
    .exu2dmem_width_o               (pipe2dmem_width_o       ),
    .exu2dmem_addr_o                (pipe2dmem_addr_o        ),
    .exu2dmem_wdata_o               (pipe2dmem_wdata_o       ),
    .dmem2exu_req_ack_i             (dmem2pipe_req_ack_i     ),
    .dmem2exu_rdata_i               (dmem2pipe_rdata_i       ),
    .dmem2exu_resp_i                (dmem2pipe_resp_i        ),
    // EXU control
    .exu2pipe_exc_req_o             (exu_exc_req             ),
    .exu2pipe_brkpt_o               (brkpt                   ),
    .exu2pipe_init_pc_o             (exu_init_pc             ),
    .exu2pipe_wfi_run2halt_o        (wfi_run2halt            ),
    .exu2pipe_instret_o             (instret                 ),
    .exu2csr_instret_no_exc_o       (instret_nexc            ),
    .exu2pipe_exu_busy_o            (exu_busy                ),

    // PC interface
    .exu2pipe_pc_curr_o             (curr_pc                 ),
    .exu2csr_pc_next_o              (next_pc                 ),
    .exu2ifu_pc_new_req_o           (new_pc_req              ),
    .exu2ifu_pc_new_o               (new_pc                  )
);

//-------------------------------------------------------------------------------
// Multi-port register file
//-------------------------------------------------------------------------------
scr1_pipe_mprf i_pipe_mprf (
    .clk                    (clk              ),
    .exu2mprf_rs1_addr_i    (exu2mprf_rs1_addr),
    .mprf2exu_rs1_data_o    (mprf2exu_rs1_data),
    .exu2mprf_rs2_addr_i    (exu2mprf_rs2_addr),
    .mprf2exu_rs2_data_o    (mprf2exu_rs2_data),
    .exu2mprf_w_req_i       (exu2mprf_w_req   ),
    .exu2mprf_rd_addr_i     (exu2mprf_rd_addr ),
    .exu2mprf_rd_data_i     (exu2mprf_rd_data )
);

//-------------------------------------------------------------------------------
// Control and status registers
//-------------------------------------------------------------------------------

//-------------------------------------------------------------------------------
// Integrated programmable interrupt controller
//-------------------------------------------------------------------------------

//-------------------------------------------------------------------------------
// Breakpoint module
//-------------------------------------------------------------------------------


//-------------------------------------------------------------------------------
// HART Debug Unit (HDU)
//-------------------------------------------------------------------------------


endmodule : scr1_pipe_top
