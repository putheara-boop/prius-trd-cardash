#include <stdint.h>
#define TRD_METER_PATH "/var/mobile/codex-car/audio-meter.bin"
#define TRD_METER_MAGIC 0x54524431
#define TRD_METER_SIZE 4096
typedef struct {uint32_t magic;volatile uint32_t sequence;volatile float rms,peak;volatile uint64_t timestamp;volatile uint64_t heartbeat;volatile uint32_t callbacks;} TRDMeter;
