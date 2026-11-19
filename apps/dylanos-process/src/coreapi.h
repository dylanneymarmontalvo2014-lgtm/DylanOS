// Declaraciones de la API C del núcleo Rust (apps/dylanos-process/core).
// Se mantienen en un encabezado propio para que ningún .cpp dependa del layout
// interno de Rust más allá de estas estructuras estables.

#pragma once

#include <cstddef>
#include <cstdint>

extern "C" {

struct DpProcess {
    int32_t pid;
    int32_t ppid;
    const char *name;
    const char *command;
    const char *user;
    uint32_t uid;
    float cpu;
    uint64_t rss;
    const char *icon;
    const char *state;
    uint32_t threads;
    int32_t priority;
    int32_t nice;
    uint64_t uptime_secs;
    uint64_t io_read;
    uint64_t io_write;
    uint64_t swap_kb;
};

struct DpSnapshot {
    size_t count;
    const DpProcess *processes;
    float cpu_percent;
    uint64_t mem_total;
    uint64_t mem_used;
    uint64_t swap_total;
    uint64_t swap_used;
    double net_rx;
    double net_tx;
    double disk_read;
    double disk_write;
    float load1;
    float load5;
    float load15;
    double uptime;
    uint32_t cores;
    uint64_t threads;
};

struct DpService {
    const char *name;
    const char *description;
    int32_t active;
    const char *scope;
};

struct DpServiceList {
    size_t count;
    const DpService *items;
};

struct DpSampler;

DpSampler *dp_sampler_new(void);
void dp_sampler_free(DpSampler *handle);
const DpSnapshot *dp_sample(DpSampler *handle);
int32_t dp_terminate(int32_t pid, int32_t force, char *buffer, size_t len);
int32_t dp_set_priority(int32_t pid, int32_t level, char *buffer, size_t len);
int32_t dp_priority_level(int32_t nice);
int32_t dp_is_alive(int32_t pid);
DpServiceList *dp_service_list(void);
void dp_service_list_free(DpServiceList *list);
int32_t dp_service_set_active(const char *name, int32_t active, int32_t user_scope,
                              char *buffer, size_t len);
size_t dp_icon_count(DpSampler *handle);
const char *dp_icon_path(DpSampler *handle, const char *name);
const char *dp_state_label(int32_t code);

} // extern "C"
