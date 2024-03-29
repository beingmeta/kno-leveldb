typedef struct KNO_LEVELDB {
  KNO_CONS_HEADER;
  u8_string path, realpath;
  lispval opts;
  struct KNO_LEVELDB *leveldb_list;
  unsigned int readonly, saved_xrefs;
  enum leveldb_status {
    leveldb_raw = 0,
    leveldb_sketchy,
    leveldb_closed,
    leveldb_opened,
    leveldb_opening,
    leveldb_closing,
    leveldb_error } dbstatus;
  struct XTYPE_REFS xrefs;
  U8_MUTEX_DECL(leveldb_lock);
  struct leveldb_t *dbptr;
  struct leveldb_options_t *optionsptr;
  struct leveldb_readoptions_t *readopts;
  struct leveldb_writeoptions_t *writeopts;
  struct leveldb_cache_t *cacheptr;
  struct leveldb_env_t *envptr;}  *kno_leveldb;

KNO_EXPORT kno_lisp_type kno_leveldb_type;

KNO_EXPORT int kno_init_leveldb(void) KNO_LIBINIT_FN;

typedef struct KNO_LEVELDB_POOL {
  KNO_POOL_FIELDS;
  unsigned int pool_load; time_t pool_mtime;
  unsigned int locked:1;
  struct KNO_LEVELDB *leveldb;} KNO_LEVELDB_POOL;
typedef struct KNO_LEVELDB_POOL *kno_leveldb_pool;

typedef struct KNO_LEVELDB_INDEX {
  KNO_INDEX_FIELDS;
  unsigned int locked:1;
  struct KNO_LEVELDB *leveldb;} KNO_LEVELDB_INDEX;
typedef struct KNO_LEVELDB_INDEX *kno_leveldb_index;

KNO_EXPORT struct KNO_LEVELDB *kno_open_leveldb(u8_string path,lispval opts);
KNO_EXPORT int kno_close_leveldb(kno_leveldb db);
KNO_EXPORT kno_leveldb kno_reopen_leveldb(kno_leveldb db);

KNO_EXPORT kno_index kno_open_leveldb_index(u8_string path,kno_storage_flags flags,lispval opts);
KNO_EXPORT kno_index kno_make_leveldb_index(u8_string path,lispval opts);

KNO_EXPORT kno_pool kno_open_leveldb_pool(u8_string path,kno_storage_flags flags,lispval opts);
KNO_EXPORT kno_pool kno_make_leveldb_pool(u8_string path,lispval base,lispval cap,lispval opts);
