module soc #(
    parameter FIRMWARE_FILE = "firmware.mem",
    parameter ROM_ADDR_BITS = 10,
    parameter RAM_ADDR_BITS = 17
) (
    input clk,
    input resetn,
    input [7:0] gpio_pin_in,
    output [7:0] gpio_pin_out,
    output [3:0] uart_tx,
    input [3:0] uart_rx,
    output spi_clk,
    input spi_miso,
    output spi_mosi,


    // exposing internal details
    output [31:0] cpu_alu_out_q,
    output cpu_compressed_instr,
    output [63:0] cpu_count_cycle,
    output [63:0] cpu_count_instr,
    output [7:0] cpu_cpu_state,
    output [31:0] cpu_decoded_imm,
    output [31:0] cpu_decoded_imm_j,
    output [4:0] cpu_decoded_rd,
    output [4:0] cpu_decoded_rs1,
    output [4:0] cpu_decoded_rs2,
    output cpu_decoder_pseudo_trigger,
    output cpu_decoder_trigger,
    output cpu_instr_add,
    output cpu_instr_addi,
    output cpu_instr_and,
    output cpu_instr_andi,
    output cpu_instr_auipc,
    output cpu_instr_beq,
    output cpu_instr_bge,
    output cpu_instr_bgeu,
    output cpu_instr_blt,
    output cpu_instr_bltu,
    output cpu_instr_bne,
    output cpu_instr_getq,
    output cpu_instr_jal,
    output cpu_instr_jalr,
    output cpu_instr_lb,
    output cpu_instr_lbu,
    output cpu_instr_lh,
    output cpu_instr_lhu,
    output cpu_instr_lui,
    output cpu_instr_lw,
    output cpu_instr_maskirq,
    output cpu_instr_or,
    output cpu_instr_ori,
    output cpu_instr_rdcycle,
    output cpu_instr_rdcycleh,
    output cpu_instr_rdinstr,
    output cpu_instr_rdinstrh,
    output cpu_instr_retirq,
    output cpu_instr_sb,
    output cpu_instr_setq,
    output cpu_instr_sh,
    output cpu_instr_sll,
    output cpu_instr_slli,
    output cpu_instr_slt,
    output cpu_instr_slti,
    output cpu_instr_sltiu,
    output cpu_instr_sltu,
    output cpu_instr_sra,
    output cpu_instr_srai,
    output cpu_instr_srl,
    output cpu_instr_srli,
    output cpu_instr_sub,
    output cpu_instr_sw,
    output cpu_instr_timer,
    output cpu_instr_waitirq,
    output cpu_instr_xor,
    output cpu_instr_xori,
    output cpu_is_alu_reg_imm,
    output cpu_is_alu_reg_reg,
    output cpu_is_beq_bne_blt_bge_bltu_bgeu,
    output cpu_is_compare,
    output cpu_is_jalr_addi_slti_sltiu_xori_ori_andi,
    output cpu_is_lb_lh_lw_lbu_lhu,
    output cpu_is_lbu_lhu_lw,
    output cpu_is_lui_auipc_jal,
    output cpu_is_lui_auipc_jal_jalr_addi_add_sub,
    output cpu_is_sb_sh_sw,
    output cpu_is_sll_srl_sra,
    output cpu_is_slli_srli_srai,
    output cpu_is_slti_blt_slt,
    output cpu_is_sltiu_bltu_sltu,
    output cpu_latched_branch,
    output cpu_latched_compr,
    output cpu_latched_is_lb,
    output cpu_latched_is_lh,
    output cpu_latched_is_lu,
    output [4:0] cpu_latched_rd,
    output cpu_latched_stalu,
    output cpu_latched_store,
    output [31:0] cpu_mem_addr,
    output cpu_mem_do_prefetch,
    output cpu_mem_do_rdata,
    output cpu_mem_do_rinst,
    output cpu_mem_do_wdata,
    output [31:0] cpu_mem_rdata_q,
    output [1:0] cpu_mem_state,
    output cpu_mem_valid,
    output [31:0] cpu_mem_wdata,
    output [1:0] cpu_mem_wordsize,
    output [3:0] cpu_mem_wstrb,
    output [31:0] cpu_reg_next_pc,
    output [31:0] cpu_reg_op1,
    output [31:0] cpu_reg_op2,
    output [31:0] cpu_reg_out,
    output [31:0] cpu_reg_pc,
    output [4:0] cpu_reg_sh,
    output cpu_trap,
    output [1023:0] cpu_cpuregs
);

wire mem_valid;
wire mem_instr;
wire mem_ready;
wire [31:0] mem_addr;
wire [31:0] mem_wdata;
wire [3:0] mem_wstrb;
wire [31:0] mem_rdata;

// CPU
picorv32 cpu(
    .clk (clk),
    .resetn (resetn),
    .mem_valid (mem_valid),
    .mem_instr (mem_instr),
    .mem_ready (mem_ready),
    .mem_addr (mem_addr),
    .mem_wdata (mem_wdata),
    .mem_wstrb (mem_wstrb),
    .mem_rdata (mem_rdata),
    // exposing internal wires
    .internal_alu_out_q (cpu_alu_out_q),
    .internal_compressed_instr (cpu_compressed_instr),
    .internal_count_cycle (cpu_count_cycle),
    .internal_count_instr (cpu_count_instr),
    .internal_cpu_state (cpu_cpu_state),
    .internal_decoded_imm (cpu_decoded_imm),
    .internal_decoded_imm_j (cpu_decoded_imm_j),
    .internal_decoded_rd (cpu_decoded_rd),
    .internal_decoded_rs1 (cpu_decoded_rs1),
    .internal_decoded_rs2 (cpu_decoded_rs2),
    .internal_decoder_pseudo_trigger (cpu_decoder_pseudo_trigger),
    .internal_decoder_trigger (cpu_decoder_trigger),
    .internal_instr_add (cpu_instr_add),
    .internal_instr_addi (cpu_instr_addi),
    .internal_instr_and (cpu_instr_and),
    .internal_instr_andi (cpu_instr_andi),
    .internal_instr_auipc (cpu_instr_auipc),
    .internal_instr_beq (cpu_instr_beq),
    .internal_instr_bge (cpu_instr_bge),
    .internal_instr_bgeu (cpu_instr_bgeu),
    .internal_instr_blt (cpu_instr_blt),
    .internal_instr_bltu (cpu_instr_bltu),
    .internal_instr_bne (cpu_instr_bne),
    .internal_instr_getq (cpu_instr_getq),
    .internal_instr_jal (cpu_instr_jal),
    .internal_instr_jalr (cpu_instr_jalr),
    .internal_instr_lb (cpu_instr_lb),
    .internal_instr_lbu (cpu_instr_lbu),
    .internal_instr_lh (cpu_instr_lh),
    .internal_instr_lhu (cpu_instr_lhu),
    .internal_instr_lui (cpu_instr_lui),
    .internal_instr_lw (cpu_instr_lw),
    .internal_instr_maskirq (cpu_instr_maskirq),
    .internal_instr_or (cpu_instr_or),
    .internal_instr_ori (cpu_instr_ori),
    .internal_instr_rdcycle (cpu_instr_rdcycle),
    .internal_instr_rdcycleh (cpu_instr_rdcycleh),
    .internal_instr_rdinstr (cpu_instr_rdinstr),
    .internal_instr_rdinstrh (cpu_instr_rdinstrh),
    .internal_instr_retirq (cpu_instr_retirq),
    .internal_instr_sb (cpu_instr_sb),
    .internal_instr_setq (cpu_instr_setq),
    .internal_instr_sh (cpu_instr_sh),
    .internal_instr_sll (cpu_instr_sll),
    .internal_instr_slli (cpu_instr_slli),
    .internal_instr_slt (cpu_instr_slt),
    .internal_instr_slti (cpu_instr_slti),
    .internal_instr_sltiu (cpu_instr_sltiu),
    .internal_instr_sltu (cpu_instr_sltu),
    .internal_instr_sra (cpu_instr_sra),
    .internal_instr_srai (cpu_instr_srai),
    .internal_instr_srl (cpu_instr_srl),
    .internal_instr_srli (cpu_instr_srli),
    .internal_instr_sub (cpu_instr_sub),
    .internal_instr_sw (cpu_instr_sw),
    .internal_instr_timer (cpu_instr_timer),
    .internal_instr_waitirq (cpu_instr_waitirq),
    .internal_instr_xor (cpu_instr_xor),
    .internal_instr_xori (cpu_instr_xori),
    .internal_is_alu_reg_imm (cpu_is_alu_reg_imm),
    .internal_is_alu_reg_reg (cpu_is_alu_reg_reg),
    .internal_is_beq_bne_blt_bge_bltu_bgeu (cpu_is_beq_bne_blt_bge_bltu_bgeu),
    .internal_is_compare (cpu_is_compare),
    .internal_is_jalr_addi_slti_sltiu_xori_ori_andi (cpu_is_jalr_addi_slti_sltiu_xori_ori_andi),
    .internal_is_lb_lh_lw_lbu_lhu (cpu_is_lb_lh_lw_lbu_lhu),
    .internal_is_lbu_lhu_lw (cpu_is_lbu_lhu_lw),
    .internal_is_lui_auipc_jal (cpu_is_lui_auipc_jal),
    .internal_is_lui_auipc_jal_jalr_addi_add_sub (cpu_is_lui_auipc_jal_jalr_addi_add_sub),
    .internal_is_sb_sh_sw (cpu_is_sb_sh_sw),
    .internal_is_sll_srl_sra (cpu_is_sll_srl_sra),
    .internal_is_slli_srli_srai (cpu_is_slli_srli_srai),
    .internal_is_slti_blt_slt (cpu_is_slti_blt_slt),
    .internal_is_sltiu_bltu_sltu (cpu_is_sltiu_bltu_sltu),
    .internal_latched_branch (cpu_latched_branch),
    .internal_latched_compr (cpu_latched_compr),
    .internal_latched_is_lb (cpu_latched_is_lb),
    .internal_latched_is_lh (cpu_latched_is_lh),
    .internal_latched_is_lu (cpu_latched_is_lu),
    .internal_latched_rd (cpu_latched_rd),
    .internal_latched_stalu (cpu_latched_stalu),
    .internal_latched_store (cpu_latched_store),
    .internal_mem_addr (cpu_mem_addr),
    .internal_mem_do_prefetch (cpu_mem_do_prefetch),
    .internal_mem_do_rdata (cpu_mem_do_rdata),
    .internal_mem_do_rinst (cpu_mem_do_rinst),
    .internal_mem_do_wdata (cpu_mem_do_wdata),
    .internal_mem_rdata_q (cpu_mem_rdata_q),
    .internal_mem_state (cpu_mem_state),
    .internal_mem_valid (cpu_mem_valid),
    .internal_mem_wdata (cpu_mem_wdata),
    .internal_mem_wordsize (cpu_mem_wordsize),
    .internal_mem_wstrb (cpu_mem_wstrb),
    .internal_reg_next_pc (cpu_reg_next_pc),
    .internal_reg_op1 (cpu_reg_op1),
    .internal_reg_op2 (cpu_reg_op2),
    .internal_reg_out (cpu_reg_out),
    .internal_reg_pc (cpu_reg_pc),
    .internal_reg_sh (cpu_reg_sh),
    .internal_trap (cpu_trap),
    .internal_cpuregs (cpu_cpuregs)
);

// ROM
wire rom_valid = mem_valid && mem_addr[31:24] == 8'h00;
wire [31:0] rom_rdata;
wire rom_ready;
rom #(
    .ADDR_BITS (ROM_ADDR_BITS),
    .FILENAME (FIRMWARE_FILE)
) rom (
    .clk (clk),
    .valid (rom_valid),
    .addr (mem_addr),
    .dout (rom_rdata),
    .ready (rom_ready)
);

// RAM
wire ram_valid = mem_valid && mem_addr[31:24] == 8'h20;
wire [31:0] ram_rdata;
wire ram_ready;
ram #(
    .ADDR_BITS (RAM_ADDR_BITS)
) ram (
    .clk (clk),
    .valid (ram_valid),
    .addr (mem_addr),
    .din (mem_wdata),
    .wstrb (mem_wstrb),
    .dout (ram_rdata),
    .ready (ram_ready)
);

// GPIO
wire gpio_ready;
wire gpio_sel;
wire [31:0] gpio_rdata;
gpio #(
    .ADDR(32'h4000_0000)
) gpio (
    .clk (clk),
    .resetn (resetn),
    .mem_valid (mem_valid),
    .mem_addr (mem_addr),
    .mem_wdata (mem_wdata),
    .mem_wstrb (mem_wstrb),
    .gpio_ready (gpio_ready),
    .gpio_sel (gpio_sel),
    .gpio_rdata (gpio_rdata),
    .gpio_pin_in (gpio_pin_in),
    .gpio_pin_out (gpio_pin_out)
);

// UARTs
wire uart_ready [3:0];
wire uart_sel [3:0];
wire [31:0] uart_rdata [3:0];
genvar i;
for (i = 0; i < 4; i = i + 1) begin : uarts
    uart #(
        .ADDR(32'h4000_1000 + (32'h1000 * i))
    ) uart1 (
        .clk (clk),
        .resetn (resetn),
        .ser_tx (uart_tx[i]),
        .ser_rx (uart_rx[i]),
        .mem_valid (mem_valid),
        .mem_addr (mem_addr),
        .mem_wdata (mem_wdata),
        .mem_wstrb (mem_wstrb),
        .uart_ready (uart_ready[i]),
        .uart_sel (uart_sel[i]),
        .uart_rdata (uart_rdata[i])
    );
end

// SPI
wire spi_ready;
wire spi_sel;
wire [31:0] spi_rdata;
spi #(
    .ADDR(32'h4000_5000)
) spi (
    .clk (clk),
    .resetn (resetn),
    .spi_clk (spi_clk),
    .spi_miso (spi_miso),
    .spi_mosi (spi_mosi),
    .mem_valid (mem_valid),
    .mem_addr (mem_addr),
    .mem_wdata (mem_wdata),
    .mem_wstrb (mem_wstrb),
    .spi_ready (spi_ready),
    .spi_sel (spi_sel),
    .spi_rdata (spi_rdata)
);

// memory inputs
assign mem_ready = (rom_valid && rom_ready) ||
    (ram_valid && ram_ready) ||
    (gpio_sel && gpio_ready) ||
    (uart_sel[0] && uart_ready[0]) ||
    (uart_sel[1] && uart_ready[1]) ||
    (uart_sel[2] && uart_ready[2]) ||
    (uart_sel[3] && uart_ready[3]) ||
    (spi_sel && spi_ready);
assign mem_rdata = (rom_valid && rom_ready) ? rom_rdata :
    (ram_valid && ram_ready) ? ram_rdata :
    (gpio_sel) ? gpio_rdata :
    (uart_sel[0]) ? uart_rdata[0] :
    (uart_sel[1]) ? uart_rdata[1] :
    (uart_sel[2]) ? uart_rdata[2] :
    (uart_sel[3]) ? uart_rdata[3] :
    (spi_sel) ? spi_rdata :
    32'h 0000_0000;

endmodule
