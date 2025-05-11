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

    reg [4:0] serBuf;             // 5 bit buffer for storing i_sdin values
    reg [2:0] cycles, count;      // Counters for counting upto 5: cycles for waiting 5 cycles, count for 5 sdin bits
    reg [1:0] clk_div;            // Counter for generating i_clk/4
    reg [11:0] ADCbuf;            // 12 bit buffer for storing i_ADC_out values of last 3 cycles
    reg [5:0] ADCsum;             // 6 bit ADCsum (4'b1111 *4 = 6'b111100)
    reg [3:0] ADCavg;

    reg [2:0] state, next;
    reg prev;

    localparam [2:0] IDLE = 0,  // Reset state
                   SERIAL = 1,  // Serial Communication on going
                    EN_RO = 2,  // Set o_enableRO
                    WAIT5 = 3,  // Waiting for 5 cycles
                  IB_CORE = 4,  // Set o_Ibias, o_core_clk
                   RESETS = 5,  // Set o_resetb_amp, o_resetb_core
                  WAIT5_2 = 6,  // Waiting for 5 cycles
                    READY = 7;
    
    // Generating i_clk/4
    always @(posedge i_clk or negedge i_resetbALL) begin
      if(!i_resetbALL) begin
        clk_div <= 0;
      end

      else begin
        clk_div <= clk_div+1;
      end
    end
    
    // Computing moving average 
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

    // Setting o_gain, serial communication
    always @(posedge i_clk or negedge i_resetbALL) begin
        if(!i_resetbALL)  begin
            prev   <= 0;
            serBuf <= 0;
            o_gain <= 0;
            count  <= 0;
        end
        else  begin
            prev <= i_sclk;
            if({prev, i_sclk}==2'b01) begin
                serBuf <= {i_sdin, serBuf[3:0]};
                o_gain <= serBuf[4:2];
                count  <= (count==4)? 0:count+1;
            end
        end
    end

    // Setting outputs based on current state
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

    // Next state transition logic
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

    assign o_core_clk = (o_Ibias_2x)? clk_div[1]:((state>WAIT5)? i_clk:1'b0);  // set o_core_clk based on o_Ibias_2x and state

endmodule
