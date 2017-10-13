package main

import (
	// Import the entire framework (including bundled verilog)
	_ "sdaccel"

	aximemory "axi/memory"
	axiprotocol "axi/protocol"

	"github.com/ReconfigureIO/fixed"
)

// A small kernel to test our fixed library
func Top(
	a int32,
	b int32,
	addr uintptr,

	// The second set of arguments will be the ports for interacting with memory
	memReadAddr chan<- axiprotocol.Addr,
	memReadData <-chan axiprotocol.ReadData,

	memWriteAddr chan<- axiprotocol.Addr,
	memWriteData chan<- axiprotocol.WriteData,
	memWriteResp <-chan axiprotocol.WriteResp) {

	// Since we're not reading anything from memory, disable those reads
	go axiprotocol.ReadDisable(memReadAddr, memReadData)

	// Calculate the value
	pre_val := fixed.Int26_6(a)
	val := pre_val.Mul(fixed.Int26_6(b))

	// Write it back to the pointer the host requests
	aximemory.WriteUInt32(
		memWriteAddr, memWriteData, memWriteResp, false, addr, uint32(val))
}
