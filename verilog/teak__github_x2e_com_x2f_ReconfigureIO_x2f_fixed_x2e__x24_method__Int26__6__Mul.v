//
// (c) 2018 ReconfigureIO
//
// <COPYRIGHT TERMS>
//

//
// Implements a 26d6 x 26d6 fixed point multipler with a 32-bit truncated output.
// Uses a single pipelined DSP slice with sequential calculation of 17x17
// partial products. This choice of partial product size should enable the use
// of the 17-bit DSP integrated shift operator.
//

`timescale 1ns/1ps

module teak__github_x2e_com_x2f_ReconfigureIO_x2f_fixed_x2e__x24_method__Int26__6__Mul
  (goValid, goStop, doneValid, doneStop, operandsReady, operandsData,
  operandsStop, resultReady, resultData, resultStop, clk, srst);

// Specify function go/done control signals.
input  goValid;
output goStop;
output doneValid;
input  doneStop;

// Specify operands input signals.
input        operandsReady;
input [63:0] operandsData;
output       operandsStop;

// Specify result output signals.
output        resultReady;
output [31:0] resultData;
input         resultStop;

// Specifies the clock and active high synchronous reset signals.
input clk;
input srst;

// Specify the operand input register signals.
reg        operandsValid_q;
reg [31:0] operandAData_q;
reg [31:0] operandBData_q;

// Common operand handshake signals.
wire multiplyStop;
reg  inputBlocked;

// Specify input state machine state space.
parameter [2:0]
  Partial00Idle = 0,
  Partial01 = 1,
  Partial10 = 2,
  Partial11 = 3,
  Partial02 = 4,
  Partial20 = 5;

reg [2:0] inputState_d;
reg [2:0] inputState_q;

// Specify the output control commands.
parameter [1:0]
  OutputInit = 0,
  OutputUpdate = 1,
  OutputShiftUpdate = 2,
  OutputDone = 3;

// Specify first stage pipeline signals.
reg [1:0]  outputCmdP1_d;
reg [16:0] partialOpA_d;
reg [16:0] partialOpB_d;

reg [1:0]  outputCmdP1_q;
reg [16:0] partialOpA_q;
reg [16:0] partialOpB_q;

// Specify second stage pipeline signals.
reg [1:0]  outputCmdP2_q;
reg [33:0] partialMultP2_q;

// Specify third stage pipeline signals.
reg [1:0]  outputCmdP3_q;
reg [33:0] partialMultP3_q;

// Specify output pipeline signals.
reg        resultValid_d;
reg [35:0] resultDataHigh_d;
reg [33:0] resultDataLow_d;
reg        resultValid_q;
reg [35:0] resultDataHigh_q;
reg [33:0] resultDataLow_q;

// Specify output toggle buffer signals.
reg        resultBufValid_q;
reg [31:0] resultBufData_q;

// Pass through the go/done signals.
assign doneValid = goValid;
assign goStop = doneStop;

// Map common operand handshake signals.
assign operandsStop = multiplyStop | inputBlocked;

// Implement resettable input control registers.
always @(posedge clk)
begin
  if (srst)
  begin
    operandsValid_q <= 1'b0;
  end
  else if (~operandsStop)
  begin
    operandsValid_q <= operandsReady;
  end
end

// Implement non-resettable input data registers.
always @(posedge clk)
begin
  if (~operandsStop)
  begin
    operandAData_q <= operandsData [31:0];
    operandBData_q <= operandsData [63:32];
  end
end

// Implement combinatorial logic for input state machine.
always @(inputState_q, operandsValid_q, operandAData_q, operandBData_q)
begin

  // Hold current state by default.
  inputState_d = inputState_q;
  outputCmdP1_d = OutputInit;
  inputBlocked = 1'b1;

  // Implement state machine.
  case (inputState_q)

    // Calculate partial product 1,0.
    Partial10 :
    begin
      inputState_d = Partial01;
      outputCmdP1_d = OutputShiftUpdate;
      partialOpA_d = operandAData_q [16:0];
      partialOpB_d = {operandBData_q [31],
        operandBData_q [31], operandBData_q [31:17]};
    end

    // Calculate partial product 0,1.
    Partial01 :
    begin
      inputState_d = Partial02;
      outputCmdP1_d = OutputUpdate;
      partialOpA_d = {operandAData_q [31],
        operandAData_q [31], operandAData_q [31:17]};
      partialOpB_d = operandBData_q[16:0];
    end

    // Calcaulte partial product 0,2.
    Partial02:
    begin
      inputState_d = Partial20;
      outputCmdP1_d = OutputShiftUpdate;
      partialOpA_d = (operandAData_q [31] == 1'b0) ? 17'd0 : ~17'd0;
      partialOpB_d = operandBData_q[16:0];
    end

    // Calcaulte partial product 2,0.
    Partial20:
    begin
      inputState_d = Partial11;
      outputCmdP1_d = OutputUpdate;
      partialOpA_d = operandAData_q[16:0];
      partialOpB_d = (operandBData_q [31] == 1'b0) ? 17'd0 : ~17'd0;
    end

    // Calculate partial product 1,1.
    Partial11 :
    begin
      inputState_d = Partial00Idle;
      outputCmdP1_d = OutputDone;
      inputBlocked = 1'b0;
      partialOpA_d = {operandAData_q [31],
        operandAData_q [31], operandAData_q [31:17]};
      partialOpB_d = {operandBData_q [31],
        operandBData_q [31], operandBData_q [31:17]};
    end

    // From the idle state, wait for new operands to become available.
    // Calculates partial product 0,0.
    default :
    begin
      if (operandsValid_q)
        inputState_d = Partial10;
      else
        inputBlocked = 1'b0;
      partialOpA_d = operandAData_q[16:0];
      partialOpB_d = operandBData_q[16:0];
    end
  endcase
end

// Implement resettable sequential control logic for input state machine.
always @(posedge clk)
begin
  if (srst)
  begin
    inputState_q <= Partial00Idle;
    outputCmdP1_q <= OutputInit;
  end
  else if (~multiplyStop)
  begin
    inputState_q <= inputState_d;
    outputCmdP1_q <= outputCmdP1_d;
  end
end

// Implement non-resettable sequential datapath logic for input state machine.
always @(posedge clk)
begin
  if (~multiplyStop)
  begin
    partialOpA_q <= partialOpA_d;
    partialOpB_q <= partialOpB_d;
  end
end

// Implement second and third stage control pipeline.
always @(posedge clk)
begin
  if (srst)
  begin
    outputCmdP2_q <= OutputInit;
    outputCmdP3_q <= OutputInit;
  end
  else if (~multiplyStop)
  begin
    outputCmdP2_q <= outputCmdP1_q;
    outputCmdP3_q <= outputCmdP2_q;
  end
end

// Implement second and third stage multiplier pipeline.
always @(posedge clk)
begin
  if (~multiplyStop)
  begin
    partialMultP2_q <= partialOpA_q * partialOpB_q;
    partialMultP3_q <= partialMultP2_q;
  end
end

// Implement combinatorial logic for output pipeline stage.
always @(resultDataHigh_q, resultDataLow_q, outputCmdP3_q, partialMultP3_q)
begin

  // Implement partial term addition. The least significant partial products
  // are calculated first, which allows the accumulator to be implemented as a
  // shift register with constant alignment to the multiplier output. This
  // allows the output adder and registers of the Xilinx DSP block to be used
  // for holding the result.
  case (outputCmdP3_q)
    OutputInit :
    begin
      resultDataHigh_d = 36'd32;
      resultDataLow_d = 17'd0;
    end
    OutputShiftUpdate :
    begin
      resultDataHigh_d = {17'd0, resultDataHigh_q [35:17]};
      resultDataLow_d = {resultDataHigh_q [16:0], resultDataLow_q [33:17]};
    end
    default :
    begin
      resultDataHigh_d = resultDataHigh_q;
      resultDataLow_d = resultDataLow_q;
    end
  endcase

  resultDataHigh_d = resultDataHigh_d + {2'd0, partialMultP3_q};

  // Generate data valid signal.
  if (outputCmdP3_q == OutputDone)
    resultValid_d = 1'b1;
  else
    resultValid_d = 1'b0;

end

// Implement sequential logic for resettable output control signals.
always @(posedge clk)
begin
  if (srst)
  begin
    resultValid_q <= 1'b0;
  end
  else if (~multiplyStop)
  begin
    resultValid_q <= resultValid_d;
  end
end

// Implement sequential logic for non-resettable output data signals.
always @(posedge clk)
begin
  if (~multiplyStop)
  begin
    resultDataLow_q <= resultDataLow_d;
    resultDataHigh_q <= resultDataHigh_d;
  end
end

// Implement output toggle buffer to break combinatorial SELF control lines.
always @(posedge clk)
begin
  if (srst)
    resultBufValid_q <= 1'b0;
  else if (resultBufValid_q)
    resultBufValid_q <= resultStop;
  else
    resultBufValid_q <= resultValid_q;
end

always @(posedge clk)
begin
  if (~resultBufValid_q)
    resultBufData_q <= {resultDataHigh_q [3:0], resultDataLow_q [33:6]};
end

assign multiplyStop = resultValid_q & resultBufValid_q;
assign resultReady = resultBufValid_q;
assign resultData = resultBufData_q;

endmodule
