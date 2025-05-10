module backend (
    input i_clk,
    input i_resetbALL,
    input i_sclk,
    input i_sdin,
    input i_RO_clk,
    input [3:0] i_ADCout,
    
    output reg o_ready,
    output reg o_resetb_amp,
    output reg o_resetb_core,
    output reg [2:0] o_gain,
    output reg o_Ibias_2x,
    output reg o_enableRO,
    output o_core_clk
);

    reg [4:0] serBuf;
    reg [2:0] cycles, count;
    reg [1:0] clk_div;
    reg [11:0] ADCbuf;
    reg [5:0] ADCsum;
    reg [3:0] ADCavg;

    reg [2:0] state, next;
    reg prev;

    localparam [2:0] IDLE = 0,
                   SERIAL = 1,
                    EN_RO = 2,
                    WAIT5 = 3,
                  IB_CORE = 4,
                   RESETS = 5,
                  WAIT5_2 = 6,
                    READY = 7;
    
    always @(posedge i_clk or negedge i_resetbALL) begin
      if(!i_resetbALL) begin
        clk_div <= 0;
      end

      else begin
        clk_div <= clk_div+1;
      end
    end

    always @(posedge i_clk or negedge i_resetbALL) begin
        if(!i_resetbALL)  begin
            ADCbuf <= 12'd0;
            ADCsum <= 0;
            ADCavg <= 0;
        end
        else begin
            ADCsum <= i_ADCout + ADCbuf[11:8] + ADCbuf[7:4] + ADCbuf[3:0];
            ADCavg <= ADCsum>>2;
            ADCbuf <= {i_ADCout, ADCbuf[11:4]};
        end
    end

    always @(posedge i_clk or negedge i_resetbALL) begin
        if(!i_resetbALL)  begin
            prev   <= 0;
            serBuf <= 0;
            o_gain <= 0;
        end
        else  begin
            prev <= i_sclk;
            if({prev, i_sclk}==2'b01) begin
                serBuf <= {i_sdin, serBuf[3:0]};
                o_gain <= serBuf[4:2];
            end
        end
    end

    always @(posedge i_clk or negedge i_resetbALL)  begin
        if(!i_resetbALL) begin
            state <= IDLE;
        end

        else begin
            state <= next;
        end

        case(state)
           IDLE:  begin
                cycles <= 0;
                count  <= 0;
                o_enableRO    <= 0;
                o_resetb_amp  <= 0;
                o_resetb_core <= 0;
                o_Ibias_2x    <= 0;
                o_ready       <= 0;
           end
           SERIAL: begin
                cycles <= 0;
                count  <= count+1;
                o_enableRO    <= 0;
                o_resetb_amp  <= 0;
                o_resetb_core <= 0;
                o_Ibias_2x    <= 0;
                o_ready       <= 0;
           end
           EN_RO: begin
                cycles <= 0;
                count  <= 0;
                o_enableRO    <= 1;
                o_resetb_amp  <= 0;
                o_resetb_core <= 0;
                o_Ibias_2x    <= 0;
                o_ready       <= 0;
           end
           WAIT5: begin
                cycles <= cycles+1;
                count  <= 0;
                o_enableRO    <= 1;
                o_resetb_amp  <= 0;
                o_resetb_core <= 0;
                o_Ibias_2x    <= 0;
                o_ready       <= 0;
           end
           IB_CORE: begin
                cycles <= 0;
                count  <= 0;
                o_enableRO    <= 1;
                o_resetb_amp  <= 0;
                o_resetb_core <= 0;
                o_Ibias_2x    <= (ADCavg>12)? 1'b1:1'b0;
                o_ready       <= 0;
           end
           RESETS: begin
                cycles <= 0;
                count  <= 0;
                o_enableRO    <= 1;
                o_resetb_amp  <= 1;
                o_resetb_core <= 1;
                o_Ibias_2x    <= o_Ibias_2x;
                o_ready       <= 0;
           end
           WAIT5_2:  begin
                cycles <= cycles+1;
                count  <= 0;
                o_enableRO    <= 1;
                o_resetb_amp  <= 1;
                o_resetb_core <= 1;
                o_Ibias_2x    <= o_Ibias_2x;
                o_ready       <= 0;
           end
           READY:  begin
                cycles <= 0;
                count  <= 0;
                o_enableRO    <= 1;
                o_resetb_amp  <= 1;
                o_resetb_core <= 1;
                o_ready       <= 1;
                
                if(ADCavg < 8) begin
                    o_Ibias_2x <= 0;
                end
                else if(ADCavg > 12)  begin
                    o_Ibias_2x <= 1;
                end
           end
        endcase
    end

    always @(*)  begin
        case(state)
           IDLE   : next <= SERIAL;
           SERIAL : next <= (count==4)? EN_RO:SERIAL;
           EN_RO  : next <= WAIT5;
           WAIT5  : next <= (cycles==4)? IB_CORE:WAIT5;
           IB_CORE: next <= RESETS;
           RESETS : next <= WAIT5_2;
           WAIT5_2: next <= (cycles==4)? READY: WAIT5_2;
           READY  : next <= READY;
        endcase
    end

    assign o_core_clk = (o_Ibias_2x)? clk_div[1]:((state>WAIT5)? i_clk:1'b0);

endmodule