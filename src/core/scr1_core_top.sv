/// Copyright by Syntacore LLC © 2016-2021. See LICENSE for details
/// @file       <scr1_core_top.sv>
/// @brief      SCR1 core top
///

//`include "scr1_arch_description.svh"
//`include "scr1_arch_types.svh"
//`include "scr1_memif.svh"

//`ifdef SCR1_DBG_EN
//`include "scr1_tapc.svh"
//`include "scr1_dm.svh"
//`include "scr1_hdu.svh"
//`endif // SCR1_DBG_EN

//`ifdef SCR1_IPIC_EN
//`include "scr1_ipic.svh"
//`endif // SCR1_IPIC_EN

module scr1_core_top (
    // Common
    input   logic                                   pwrup_rst_n,                // Power-Up reset
    input   logic                                   rst_n,                      // Regular reset
    input   logic                                   cpu_rst_n,                  // CPU reset
    input   logic                                   test_mode,                  // DFT Test Mode
    input   logic                                   test_rst_n,                 // DFT Test Reset
    input   logic                                   clk,                        // Core clock
    output  logic                                   core_rst_n_o,               // Core reset
    output  logic                                   core_rdc_qlfy_o,            // Core RDC qualifier


    // Fuses
    input   logic [`SCR1_XLEN-1:0]                  core_fuse_mhartid_i,        // Fuse MHARTID value
    // IRQ
    input   logic                                   core_irq_ext_i,             // External interrupt request
    input   logic                                   core_irq_soft_i,            // Software generated interrupt request
    input   logic                                   core_irq_mtimer_i,          // Machine timer interrupt request

    // Memory-mapped external timer
    input   logic [63:0]                            core_mtimer_val_i,          // Machine timer value



    // Instruction Memory Interface
    input   logic                                   imem2core_req_ack_i,        // IMEM request acknowledge
    output  logic                                   core2imem_req_o,            // IMEM request
    output  type_scr1_mem_cmd_e                     core2imem_cmd_o,            // IMEM command
    output  logic [`SCR1_IMEM_AWIDTH-1:0]           core2imem_addr_o,           // IMEM address
    input   logic [`SCR1_IMEM_DWIDTH-1:0]           imem2core_rdata_i,          // IMEM read data
    input   type_scr1_mem_resp_e                    imem2core_resp_i,           // IMEM response

    // Data Memory Interface
    input   logic                                   dmem2core_req_ack_i,        // DMEM request acknowledge
    output  logic                                   core2dmem_req_o,            // DMEM request
    output  type_scr1_mem_cmd_e                     core2dmem_cmd_o,            // DMEM command
    output  type_scr1_mem_width_e                   core2dmem_width_o,          // DMEM data width
    output  logic [`SCR1_DMEM_AWIDTH-1:0]           core2dmem_addr_o,           // DMEM address
    output  logic [`SCR1_DMEM_DWIDTH-1:0]           core2dmem_wdata_o,          // DMEM write data
    input   logic [`SCR1_DMEM_DWIDTH-1:0]           dmem2core_rdata_i,          // DMEM read data
    input   type_scr1_mem_resp_e                    dmem2core_resp_i            // DMEM response
);

//-------------------------------------------------------------------------------
// Local parameters
//-------------------------------------------------------------------------------
localparam int unsigned SCR1_CORE_TOP_RST_SYNC_STAGES_NUM               = 2;

//-------------------------------------------------------------------------------
// Local signals declaration
//-------------------------------------------------------------------------------

// Reset Logic
`ifdef SCR1_DBG_EN
`else // SCR1_DBG_EN
logic                                           core_rst_n_in_sync;
logic                                           core_rst_n_qlfy;
logic                                           core_rst_n_status;
`endif // SCR1_DBG_EN
logic                                           core_rst_n;
logic                                           core_rst_n_status_sync;
logic                                           core_rst_status;
logic                                           core2hdu_rdc_qlfy;
logic                                           core2dm_rdc_qlfy;
logic                                           pwrup_rst_n_sync;
logic                                           rst_n_sync;
logic                                           cpu_rst_n_sync;







//-------------------------------------------------------------------------------
// Reset Logic
//-------------------------------------------------------------------------------


// Reset inputs are assumed synchronous
assign pwrup_rst_n_sync   = pwrup_rst_n;
assign rst_n_sync         = rst_n;
assign cpu_rst_n_sync     = cpu_rst_n;
assign core_rst_n_in_sync = rst_n_sync & cpu_rst_n_sync;
assign core_rst_status      = ~core_rst_n_status_sync;
assign core_rdc_qlfy_o      = core_rst_n_qlfy;

assign core_rst_n_o         = core_rst_n;

//-------------------------------------------------------------------------------
// SCR1 pipeline
//-------------------------------------------------------------------------------
scr1_pipe_top i_pipe_top (
    // Control
    .pipe_rst_n                     (core_rst_n             ),
    .clk                            (clk                    ),
    // Instruction memory interface
    .pipe2imem_req_o                (core2imem_req_o        ),
    .pipe2imem_cmd_o                (core2imem_cmd_o        ),
    .pipe2imem_addr_o               (core2imem_addr_o       ),
    .imem2pipe_req_ack_i            (imem2core_req_ack_i    ),
    .imem2pipe_rdata_i              (imem2core_rdata_i      ),
    .imem2pipe_resp_i               (imem2core_resp_i       ),

    // Data memory interface
    .pipe2dmem_req_o                (core2dmem_req_o        ),
    .pipe2dmem_cmd_o                (core2dmem_cmd_o        ),
    .pipe2dmem_width_o              (core2dmem_width_o      ),
    .pipe2dmem_addr_o               (core2dmem_addr_o       ),
    .pipe2dmem_wdata_o              (core2dmem_wdata_o      ),
    .dmem2pipe_req_ack_i            (dmem2core_req_ack_i    ),
    .dmem2pipe_rdata_i              (dmem2core_rdata_i      ),
    .dmem2pipe_resp_i               (dmem2core_resp_i       ),
    // IRQ

    .soc2pipe_irq_ext_i             (core_irq_ext_i         ),
    .soc2pipe_irq_soft_i            (core_irq_soft_i        ),
    .soc2pipe_irq_mtimer_i          (core_irq_mtimer_i      ),
    // Memory-mapped external timer
    .soc2pipe_mtimer_val_i          (core_mtimer_val_i      ),

    // Fuse
    .soc2pipe_fuse_mhartid_i        (core_fuse_mhartid_i    )
);


endmodule : scr1_core_top
