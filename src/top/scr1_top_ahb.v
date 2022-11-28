
module ARAMB_RISCV_180_SOC (
          pwrup_rst_n,
          rst_n,      
          cpu_rst_n,  
          test_mode,  
          test_rst_n, 
          clk,        
          rtc_clk,    

                       ext_irq,     
                       soft_irq,    

                        imem_hprot,
                        imem_hburst,
                        imem_hsize,
                        imem_htrans,
                        imem_hmastlock,
          imem_haddr,
                        imem_hready,
          imem_hrdata,
                        imem_hresp,

                        dmem_hprot,
                        dmem_hburst,
                        dmem_hsize,
                        dmem_htrans,
                        dmem_hmastlock,
          dmem_haddr,
                        dmem_hwrite,
          dmem_hwdata,
                        dmem_hready,
          dmem_hrdata,
                        dmem_hresp
);


    input                                    pwrup_rst_n;
    input                                    rst_n;
    input                                    cpu_rst_n;
    input                                    test_mode;
    input                                    test_rst_n;
    input                                    clk;
    input                                    rtc_clk;
    output                                  ext_irq;
    output                                  soft_irq;
    output [3:0]                             imem_hprot;
    output [2:0]                             imem_hburst;
    output [2:0]                             imem_hsize;
    output [1:0]                             imem_htrans;
    output                                   imem_hmastlock;
    output [31:0]              imem_haddr;
    input                                    imem_hready;
    input  [31:0]              imem_hrdata;
    input                                    imem_hresp;
    output [3:0]                             dmem_hprot;
    output [2:0]                             dmem_hburst;
    output [2:0]                             dmem_hsize;
    output [1:0]                             dmem_htrans;
    output                                   dmem_hmastlock;
    output [31:0]              dmem_haddr;
    output                                   dmem_hwrite;
    output [31:0]              dmem_hwdata;
    input                                    dmem_hready;
    input  [31:0]              dmem_hrdata;
    input                                    dmem_hresp;


     wire                                    pwrup_rst_n;
     wire                                    rst_n;
     wire                                    cpu_rst_n;
     wire                                    test_mode;
     wire                                    test_rst_n;
     wire                                    clk;
     wire                                    rtc_clk;
     wire                                  ext_irq;
     wire                                  soft_irq;
     wire [3:0]                             imem_hprot;
     wire [2:0]                             imem_hburst;
     wire [2:0]                             imem_hsize;
     wire [1:0]                             imem_htrans;
     wire                                   imem_hmastlock;
     wire [31:0]              imem_haddr;
     wire                                    imem_hready;
     wire  [31:0]              imem_hrdata;
     wire                                    imem_hresp;
     wire [3:0]                             dmem_hprot;
     wire [2:0]                             dmem_hburst;
     wire [2:0]                             dmem_hsize;
     wire [1:0]                             dmem_htrans;
     wire                                   dmem_hmastlock;
     wire [31:0]              dmem_haddr;
     wire                                   dmem_hwrite;
     wire [31:0]              dmem_hwdata;
     wire                                    dmem_hready;
     wire  [31:0]              dmem_hrdata;
     wire                                    dmem_hresp;


scr1_pipe_top i_pipe_top (
    // Control
    .pipe_rst_n                     (cpu_rst_n ),
    .clk                            (clk                    ),
    // Instruction memory interface
    .pipe2imem_req_o                (dmem_hmastlock ),
    .pipe2imem_cmd_o                (dmem_hwrite ),
    .pipe2imem_addr_o               (dmem_haddr ),
    .imem2pipe_req_ack_i            (imem_hresp ),
    .imem2pipe_rdata_i              (dmem_hrdata ),
    .imem2pipe_resp_i               (dmem_hresp),

    // Data memory interface
    .pipe2dmem_req_o                (soft_irq ),
    .pipe2dmem_cmd_o                ( ext_irq ),
    .pipe2dmem_width_o              (imem_htrans ), 
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


sram_32_1024_scl180 sram_32_1024_scl180 (
    .clk0    ( clkout),
    .csb0   ( core_imem_req ),
    .web0  ( core_imem_cmd ),
    .addr0     ( core_dmem_addr ),
    .din0   ( core_dmem_wdata ),
    .dout0   ( dmem_hwdata)
);

endmodule 
