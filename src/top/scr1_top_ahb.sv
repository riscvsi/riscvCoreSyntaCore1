

module ARAMB_RISCV_180_SOC (
    // Control
    input   logic                                   pwrup_rst_n,            // Power-Up Reset
    input   logic                                   rst_n,                  // Regular Reset signal
    input   logic                                   cpu_rst_n,              // CPU Reset (Core Reset)
    input   logic                                   test_mode,              // Test mode
    input   logic                                   test_rst_n,             // Test mode's reset
    input   logic                                   clk,                    // System clock
    input   logic                                   rtc_clk,                // Real-time clock

    input   logic                                   ext_irq,                // External IRQ input
    input   logic                                   soft_irq,               // Software IRQ input

    // Instruction Memory Interface
    output  logic [3:0]                             imem_hprot,
    output  logic [2:0]                             imem_hburst,
    output  logic [2:0]                             imem_hsize,
    output  logic [1:0]                             imem_htrans,
    output  logic                                   imem_hmastlock,
    output  logic [31:0]              imem_haddr,
    input   logic                                   imem_hready,
    input   logic [31:0]              imem_hrdata,
    input   logic                                   imem_hresp,

    // Data Memory Interface
    output  logic [3:0]                             dmem_hprot,
    output  logic [2:0]                             dmem_hburst,
    output  logic [2:0]                             dmem_hsize,
    output  logic [1:0]                             dmem_htrans,
    output  logic                                   dmem_hmastlock,
    output  logic [31:0]              dmem_haddr,
    output  logic                                   dmem_hwrite,
    output  logic [31:0]              dmem_hwdata,
    input   logic                                   dmem_hready,
    input   logic [31:0]              dmem_hrdata,
    input   logic                                   dmem_hresp
);

//-------------------------------------------------------------------------------
// Local parameters
//-------------------------------------------------------------------------------
localparam int unsigned SCR1_CLUSTER_TOP_RST_SYNC_STAGES_NUM            = 2;

//-------------------------------------------------------------------------------
// Local signal declaration
//-------------------------------------------------------------------------------
// Reset logic
logic                                               pwrup_rst_n_sync;
logic                                               rst_n_sync;
logic                                               cpu_rst_n_sync;
logic                                               core_rst_n_local;
logic                                               clkout;
// Instruction memory interface from core to router
logic                                               core_imem_req_ack;
logic                                               core_imem_req;
type_scr1_mem_cmd_e                                 core_imem_cmd;
logic [`SCR1_IMEM_AWIDTH-1:0]                       core_imem_addr;
logic [`SCR1_IMEM_DWIDTH-1:0]                       core_imem_rdata;
type_scr1_mem_resp_e                                core_imem_resp;

// Data memory interface from core to router
logic                                               core_dmem_req_ack;
logic                                               core_dmem_req;
type_scr1_mem_cmd_e                                 core_dmem_cmd;
type_scr1_mem_width_e                               core_dmem_width;
logic [`SCR1_DMEM_AWIDTH-1:0]                       core_dmem_addr;
logic [`SCR1_DMEM_DWIDTH-1:0]                       core_dmem_wdata;
logic [`SCR1_DMEM_DWIDTH-1:0]                       core_dmem_rdata;
type_scr1_mem_resp_e                                core_dmem_resp;

// Instruction memory interface from router to AHB bridge
logic                                               ahb_imem_req_ack;
logic                                               ahb_imem_req;
type_scr1_mem_cmd_e                                 ahb_imem_cmd;
logic [`SCR1_IMEM_AWIDTH-1:0]                       ahb_imem_addr;
logic [`SCR1_IMEM_DWIDTH-1:0]                       ahb_imem_rdata;
type_scr1_mem_resp_e                                ahb_imem_resp;

// Data memory interface from router to AHB bridge
logic                                               ahb_dmem_req_ack;
logic                                               ahb_dmem_req;
type_scr1_mem_cmd_e                                 ahb_dmem_cmd;
type_scr1_mem_width_e                               ahb_dmem_width;
logic [`SCR1_DMEM_AWIDTH-1:0]                       ahb_dmem_addr;
logic [`SCR1_DMEM_DWIDTH-1:0]                       ahb_dmem_wdata;
logic [`SCR1_DMEM_DWIDTH-1:0]                       ahb_dmem_rdata;
type_scr1_mem_resp_e                                ahb_dmem_resp;


// Data memory interface from router to memory-mapped timer
logic                                               timer_dmem_req_ack;
logic                                               timer_dmem_req;
type_scr1_mem_cmd_e                                 timer_dmem_cmd;
type_scr1_mem_width_e                               timer_dmem_width;
logic [`SCR1_DMEM_AWIDTH-1:0]                       timer_dmem_addr;
logic [`SCR1_DMEM_DWIDTH-1:0]                       timer_dmem_wdata;
logic [`SCR1_DMEM_DWIDTH-1:0]                       timer_dmem_rdata;
type_scr1_mem_resp_e                                timer_dmem_resp;

logic                                               timer_irq;
logic [63:0]                                        timer_val;


//-------------------------------------------------------------------------------
// Reset logic
//-------------------------------------------------------------------------------
// Power-Up Reset synchronizer

//-------------------------------------------------------------------------------
// SCR1 core instance
//-------------------------------------------------------------------------------


scr1_pipe_top i_pipe_top (
    // Control
    .pipe_rst_n                     (cpu_rst_n_sync             ),
    .clk                            (clk                    ),
    // Instruction memory interface
    .pipe2imem_req_o                (core_imem_req        ),
    .pipe2imem_cmd_o                (core_imem_cmd        ),
    .pipe2imem_addr_o               (core_imem_addr       ),
    .imem2pipe_req_ack_i            (core_imem_req_ack    ),
    .imem2pipe_rdata_i              (core_imem_rdata      ),
    .imem2pipe_resp_i               (core_imem_resp       ),

    // Data memory interface
    .pipe2dmem_req_o                (core_dmem_req        ),
    .pipe2dmem_cmd_o                (core_dmem_cmd        ),
    .pipe2dmem_width_o              (core_dmem_width        ),
    .pipe2dmem_addr_o               (core_dmem_addr        ),
    .pipe2dmem_wdata_o              (core_dmem_wdata        ),
    .dmem2pipe_req_ack_i            (core_dmem_req_ack        ),
    .dmem2pipe_rdata_i              (core_dmem_rdata        ),
    .dmem2pipe_resp_i               (core_dmem_resp        ),
    // IRQ

    .soc2pipe_irq_ext_i             (ext_irq         ),
    .soc2pipe_irq_soft_i            (soft_irq        ),
    .soc2pipe_irq_mtimer_i          (timer_irq      ),
    // Memory-mapped external timer
    .soc2pipe_mtimer_val_i          (timer_val      ),

    // Fuse
    .soc2pipe_fuse_mhartid_i        (fuse_mhartid    ),
    .clkout                         (clkout)
);


//-------------------------------------------------------------------------------
// TCM instance
//-------------------------------------------------------------------------------



sram_32_1024_scl180 sram_32_1024_scl180 (
    .clk0    ( clkout),
    .csb0   ( core_imem_req ),
    .web0  ( core_imem_cmd ),
    .addr0     ( core_dmem_addr ),
    .din0   ( dmem_hrdata),
    .dout0   ( dmem_hwdata)
);

endmodule : scr1_top_ahb
