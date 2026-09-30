#include <stdatomic.h>
#include <stddef.h>
#include <stdint.h>
#include <stdbool.h>
#include <string.h>

#define TS_MAX_NAME 128
#define TS_TABLE_SIZE 256

typedef struct
{
  _Atomic(uint64_t) hash;
  char name[TS_MAX_NAME];
  size_t name_len;
  _Atomic(int64_t) count;
} ts_entry_t;

static ts_entry_t ts_table[TS_TABLE_SIZE];

static uint64_t ts_hash(const char* s, size_t len)
{
  uint64_t h = 14695981039346656037ULL;
  for(size_t i = 0; i < len; i++)
  {
    h ^= (uint64_t)(unsigned char)s[i];
    h *= 1099511628211ULL;
  }
  if(h == 0) h = 1;
  return h;
}

static ts_entry_t* ts_find_or_create(const char* name, size_t len)
{
  if(len > TS_MAX_NAME - 1) len = TS_MAX_NAME - 1;
  uint64_t h = ts_hash(name, len);
  size_t mask = TS_TABLE_SIZE - 1;
  size_t idx = (size_t)h & mask;

  for(size_t i = 0; i < TS_TABLE_SIZE; i++)
  {
    size_t pos = (idx + i) & mask;
    ts_entry_t* e = &ts_table[pos];

    uint64_t existing = atomic_load_explicit(&e->hash, memory_order_acquire);

    if(existing == h && e->name_len == len
      && memcmp(e->name, name, len) == 0)
      return e;

    if(existing == 0)
    {
      uint64_t zero = 0;
      if(atomic_compare_exchange_strong_explicit(&e->hash, &zero, h,
        memory_order_acq_rel, memory_order_acquire))
      {
        memcpy(e->name, name, len);
        e->name[len] = '\0';
        e->name_len = len;
        atomic_store_explicit(&e->count, 0, memory_order_release);
        return e;
      }

      existing = atomic_load_explicit(&e->hash, memory_order_acquire);
      if(existing == h && e->name_len == len
        && memcmp(e->name, name, len) == 0)
        return e;
    }
  }

  return NULL;
}

static ts_entry_t* ts_find(const char* name, size_t len)
{
  if(len > TS_MAX_NAME - 1) len = TS_MAX_NAME - 1;
  uint64_t h = ts_hash(name, len);
  size_t mask = TS_TABLE_SIZE - 1;
  size_t idx = (size_t)h & mask;

  for(size_t i = 0; i < TS_TABLE_SIZE; i++)
  {
    size_t pos = (idx + i) & mask;
    ts_entry_t* e = &ts_table[pos];

    uint64_t existing = atomic_load_explicit(&e->hash, memory_order_acquire);

    if(existing == h && e->name_len == len
      && memcmp(e->name, name, len) == 0)
      return e;

    if(existing == 0)
      return NULL;
  }

  return NULL;
}

void mi_ts_inc(const char* name, size_t len)
{
  ts_entry_t* e = ts_find_or_create(name, len);
  if(e != NULL)
    atomic_fetch_add_explicit(&e->count, 1, memory_order_relaxed);
}

void mi_ts_dec(const char* name, size_t len)
{
  ts_entry_t* e = ts_find(name, len);
  if(e != NULL)
    atomic_fetch_sub_explicit(&e->count, 1, memory_order_relaxed);
}

int64_t mi_ts_get(const char* name, size_t len)
{
  ts_entry_t* e = ts_find(name, len);
  if(e != NULL)
    return atomic_load_explicit(&e->count, memory_order_relaxed);
  return 0;
}

size_t mi_ts_count(void)
{
  size_t n = 0;
  for(size_t i = 0; i < TS_TABLE_SIZE; i++)
  {
    if(atomic_load_explicit(&ts_table[i].hash, memory_order_relaxed) != 0)
      n++;
  }
  return n;
}

size_t mi_ts_snapshot(const char** names, size_t* lens, int64_t* counts,
  size_t max)
{
  size_t n = 0;
  for(size_t i = 0; i < TS_TABLE_SIZE && n < max; i++)
  {
    ts_entry_t* e = &ts_table[i];
    if(atomic_load_explicit(&e->hash, memory_order_acquire) != 0)
    {
      names[n] = e->name;
      lens[n] = e->name_len;
      counts[n] = atomic_load_explicit(&e->count, memory_order_relaxed);
      n++;
    }
  }
  return n;
}
