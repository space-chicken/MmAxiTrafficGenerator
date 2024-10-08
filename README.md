# MmAxiTrafficGenerator
A simple traffic generator with an AXI4 memory-mapped interface that can be used for performance testing, simulation and circuit verification.

# Key feature and benefits:
- Support AXI4 memory-mapped interface
- Support linear and pseudo-random accesses with address update after each burst
- Burst length can by dynamically changed
- Supported burst lengths are 32, 64, 128, 256, 512, 1024, 2048 or 4096 bytes
- Optional transfer start and stop time capture 
  
# Parameters
|Parameter name|Default value|Description|
|---|---|---|
|G_TIMEBASE_WIDTH|32|Timebase register width|
|G_ADDRESS_WIDTH|32|Start and bondary addresses register width|
|G_COUNTERS_WIDTH|32|Transfer counters width|
|G_AXI_DATA_WIDTH|128|AXI data bus width|
|G_AXI_ADDR_WIDTH|49|AXI address width|