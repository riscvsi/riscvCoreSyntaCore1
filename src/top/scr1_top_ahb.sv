/// Copyright by Syntacore LLC © 2016-2021. See LICENSE for details
/// @file       <scr1_top_ahb.sv>
/// @brief      SCR1 AHB top
///

`include "scr1_arch_description.svh"
`include "scr1_memif.svh"
`include "scr1_ahb.svh"


`ifdef SCR1_TCM_EN
 `define SCR1_IMEM_ROUTER_EN
`endif // SCR1_TCM_EN

module scr1_top_ahb (
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
    output  logic [SCR1_AHB_WIDTH-1:0]              imem_haddr,
    input   logic                                   imem_hready,
    input   logic [SCR1_AHB_WIDTH-1:0]              imem_hrdata,
    input   logic                                   imem_hresp,

    // Data Memory Interface
    output  logic [3:0]                             dmem_hprot,
    output  logic [2:0]                             dmem_hburst,
    output  logic [2:0]                             dmem_hsize,
    output  logic [1:0]                             dmem_htrans,
    output  logic                                   dmem_hmastlock,
    output  logic [SCR1_AHB_WIDTH-1:0]              dmem_haddr,
    output  logic                                   dmem_hwrite,
    output  logic [SCR1_AHB_WIDTH-1:0]              dmem_hwdata,
    input   logic                                   dmem_hready,
    input   logic [SCR1_AHB_WIDTH-1:0]              dmem_hrdata,
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
`ifdef SCR1_DBG_EN
logic                                               tapc_trst_n;
`endif // SCR1_DBG_EN

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

`ifdef SCR1_TCM_EN
// Instruction memory interface from router to TCM
logic                                               tcm_imem_req_ack;
logic                                               tcm_imem_req;
type_scr1_mem_cmd_e                                 tcm_imem_cmd;
logic [`SCR1_IMEM_AWIDTH-1:0]                       tcm_imem_addr;
logic [`SCR1_IMEM_DWIDTH-1:0]                       tcm_imem_rdata;
type_scr1_mem_resp_e                                tcm_imem_resp;

// Data memory interface from router to TCM
logic                                               tcm_dmem_req_ack;
logic                                               tcm_dmem_req;
type_scr1_mem_cmd_e                                 tcm_dmem_cmd;
type_scr1_mem_width_e                               tcm_dmem_width;
logic [`SCR1_DMEM_AWIDTH-1:0]                       tcm_dmem_addr;
logic [`SCR1_DMEM_DWIDTH-1:0]                       tcm_dmem_wdata;
logic [`SCR1_DMEM_DWIDTH-1:0]                       tcm_dmem_rdata;
type_scr1_mem_resp_e                                tcm_dmem_resp;
`endif // SCR1_TCM_EN

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
scr1_core_top i_core_top (
    // Common
    .pwrup_rst_n                (pwrup_rst_n_sync ),
    .rst_n                      (rst_n_sync       ),
    .cpu_rst_n                  (cpu_rst_n_sync   ),
    .test_mode                  (test_mode        ),
    .test_rst_n                 (test_rst_n       ),
    .clk                        (clk              ),
    .core_rst_n_o               (core_rst_n_local ),
    .core_rdc_qlfy_o            (                 ),
`ifdef SCR1_DBG_EN
    .sys_rst_n_o                (sys_rst_n_o      ),
    .sys_rdc_qlfy_o             (sys_rdc_qlfy_o   ),
`endif // SCR1_DBG_EN

    // Fuses
    .core_fuse_mhartid_i        (fuse_mhartid     ),
`ifdef SCR1_DBG_EN
    .tapc_fuse_idcode_i         (fuse_idcode      ),
`endif // SCR1_DBG_EN

    // IRQ
`ifdef SCR1_IPIC_EN
    .core_irq_lines_i           (irq_lines        ),
`else // SCR1_IPIC_EN
    .core_irq_ext_i             (ext_irq          ),
`endif // SCR1_IPIC_EN
    .core_irq_soft_i            (soft_irq         ),
    .core_irq_mtimer_i          (timer_irq        ),

    // Memory-mapped external timer
    .core_mtimer_val_i          (timer_val        ),

`ifdef SCR1_DBG_EN
    // Debug interface
    .tapc_trst_n                (tapc_trst_n      ),
    .tapc_tck                   (tck              ),
    .tapc_tms                   (tms              ),
    .tapc_tdi                   (tdi              ),
    .tapc_tdo                   (tdo              ),
    .tapc_tdo_en                (tdo_en           ),
`endif // SCR1_DBG_EN

    // Instruction memory interface
    .imem2core_req_ack_i        (core_imem_req_ack),
    .core2imem_req_o            (core_imem_req    ),
    .core2imem_cmd_o            (core_imem_cmd    ),
    .core2imem_addr_o           (core_imem_addr   ),
    .imem2core_rdata_i          (core_imem_rdata  ),
    .imem2core_resp_i           (core_imem_resp   ),

    // Data memory interface
    .dmem2core_req_ack_i        (core_dmem_req_ack),
    .core2dmem_req_o            (core_dmem_req    ),
    .core2dmem_cmd_o            (core_dmem_cmd    ),
    .core2dmem_width_o          (core_dmem_width  ),
    .core2dmem_addr_o           (core_dmem_addr   ),
    .core2dmem_wdata_o          (core_dmem_wdata  ),
    .dmem2core_rdata_i          (core_dmem_rdata  ),
    .dmem2core_resp_i           (core_dmem_resp   )
);


`ifdef SCR1_TCM_EN
//-------------------------------------------------------------------------------
// TCM instance
//-------------------------------------------------------------------------------
scr1_tcm #(
    .SCR1_TCM_SIZE  (`SCR1_DMEM_AWIDTH'(~SCR1_TCM_ADDR_MASK + 1'b1))
) i_tcm (
    .clk            (clk             ),
    .rst_n          (core_rst_n_local),

    // Instruction interface to TCM
    .imem_req_ack   (tcm_imem_req_ack),
    .imem_req       (tcm_imem_req    ),
    .imem_addr      (tcm_imem_addr   ),
    .imem_rdata     (tcm_imem_rdata  ),
    .imem_resp      (tcm_imem_resp   ),

    // Data interface to TCM
    .dmem_req_ack   (tcm_dmem_req_ack),
    .dmem_req       (tcm_dmem_req    ),
    .dmem_cmd       (tcm_dmem_cmd    ),
    .dmem_width     (tcm_dmem_width  ),
    .dmem_addr      (tcm_dmem_addr   ),
    .dmem_wdata     (tcm_dmem_wdata  ),
    .dmem_rdata     (tcm_dmem_rdata  ),
    .dmem_resp      (tcm_dmem_resp   )
);
`endif // SCR1_TCM_EN


//-------------------------------------------------------------------------------
// Memory-mapped timer instance
//-------------------------------------------------------------------------------



endmodule : scr1_top_ahb


