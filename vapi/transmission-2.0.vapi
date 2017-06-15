[CCode (cheader_filename = "libtransmission/transmission.h", lower_case_cprefix = "tr_", cprefix = "TR_")]
namespace Transmission {

	[CCode (cname = "TR_SHA_DIGEST_LENGTH")]
	public const int SHA_DIGEST_LENGTH;
	[CCode (cname = "TR_INET6_ADDRSTRLEN")]
	public const int INET6_ADDRSTRLEN;
	[CCode (cname = "TR_RPC_SESSION_ID_HEADER")]
	public const string RPC_SESSION_ID_HEADER;

	[SimpleType]
	[CCode (cname = "tr_file_index", has_type_id = false)]
	public struct file_index : uint32 {}

	//TODO unused
	[CCode (cname = "tr_preallocation_mode", cprefix = "TR_PREALLOCATE_", has_type_id = false)]
	public enum PreallocationMode {
		NONE,
		SPARSE,
		FULL
	}

	[CCode (cname = "tr_encryption_mode", cprefix = "TR_", has_type_id = false)]
	public enum EncryptionMode {
		CLEAR_PREFERRED,
		ENCRYPTION_PREFERRED,
		ENCRYPTION_REQUIRED
	}

	/**
	 * Transmission's default configuration file directory.
	 *
	 * The default configuration directory is determined this way:
	 * # If the TRANSMISSION_HOME environment variable is set, its value is used.
	 * # On Darwin, "${HOME}/Library/Application Support/${appname}" is used.
	 * # On Windows, "${CSIDL_APPDATA}/${appname}" is used.
	 * # If XDG_CONFIG_HOME is set, "${XDG_CONFIG_HOME}/${appname}" is used.
	 * # ${HOME}/.config/${appname}" is used as a last resort.
	 */
	[CCode (cname = "tr_getDefaultConfigDir")]
	public unowned string get_default_config_dir (string appname);

	/**
	 * Transmisson's default download directory.
	 *
	 * The default download directory is determined this way:
	 * # If the HOME environment variable is set, "${HOME}/Downloads" is used.
	 * # On Windows, "${CSIDL_MYDOCUMENTS}/Downloads" is used.
	 * # Otherwise, getpwuid(getuid())->pw_dir + "/Downloads" is used.
	 */
	[CCode (cname = "tr_getDefaultDownloadDir")]
	public unowned string get_default_download_dir ();

	[CCode (cprefix = "TR_DEFAULT_")]
	namespace Defaults {
		public const string BIND_ADDRESS_IPV4;
		public const string BIND_ADDRESS_IPV6;
		public const string RPC_WHITELIST;
		public const string RPC_PORT_STR;
		public const string RPC_URL_STR;
		public const string PEER_PORT_STR;
		public const string PEER_SOCKET_TOS_STR;
		public const string PEER_LIMIT_GLOBAL_STR;
		public const string PEER_LIMIT_TORRENT_STR;
	}

	[CCode (cprefix = "TR_PREFS_KEY_")]
	namespace Prefs {
		public const string ALT_SPEED_ENABLED;
		public const string ALT_SPEED_UP_KBps;
		public const string ALT_SPEED_DOWN_KBps;
		public const string ALT_SPEED_TIME_BEGIN;
		public const string ALT_SPEED_TIME_ENABLED;
		public const string ALT_SPEED_TIME_END;
		public const string ALT_SPEED_TIME_DAY;
		public const string BIND_ADDRESS_IPV4;
		public const string BIND_ADDRESS_IPV6;
		public const string BLOCKLIST_ENABLED;
		public const string BLOCKLIST_URL;
		public const string MAX_CACHE_SIZE_MB;
		public const string DHT_ENABLED;
		public const string UTP_ENABLED;
		public const string LPD_ENABLED;
		public const string PREFETCH_ENABLED;
		public const string DOWNLOAD_DIR;
		public const string ENCRYPTION;
		public const string IDLE_LIMIT;
		public const string IDLE_LIMIT_ENABLED;
		public const string INCOMPLETE_DIR;
		public const string INCOMPLETE_DIR_ENABLED;
		public const string MSGLEVEL;
		public const string PEER_LIMIT_GLOBAL;
		public const string PEER_LIMIT_TORRENT;
		public const string PEER_PORT;
		public const string PEER_PORT_RANDOM_ON_START;
		public const string PEER_PORT_RANDOM_LOW;
		public const string PEER_PORT_RANDOM_HIGH;
		public const string PEER_SOCKET_TOS;
		public const string PEER_CONGESTION_ALGORITHM;
		public const string PEX_ENABLED;
		public const string PORT_FORWARDING;
		public const string PREALLOCATION;
		public const string RATIO;
		public const string RATIO_ENABLED;
		public const string RENAME_PARTIAL_FILES;
		public const string RPC_AUTH_REQUIRED;
		public const string RPC_BIND_ADDRESS;
		public const string RPC_ENABLED;
		public const string RPC_PASSWORD;
		public const string RPC_PORT;
		public const string RPC_USERNAME;
		public const string RPC_URL;
		public const string RPC_WHITELIST_ENABLED;
		public const string SCRAPE_PAUSED_TORRENTS;
		public const string SCRIPT_TORRENT_DONE_FILENAME;
		public const string SCRIPT_TORRENT_DONE_ENABLED;
		public const string RPC_WHITELIST;
		public const string DSPEED_KBps;
		public const string DSPEED_ENABLED;
		public const string USPEED_KBps;
		public const string USPEED_ENABLED;
		public const string UMASK;
		public const string UPLOAD_SLOTS_PER_TORRENT;
		public const string START;
		public const string TRASH_ORIGINAL;
	}

	/**
	 * Add libtransmission's default settings to the {@link benc} dictionary.
	 */
	[CCode (cname = "tr_sessionGetDefaultSettings")]
	public void get_default_settings (ref variant_dict dictionary);

	/**
	 * Load settings from the configuration directory's settings.json file, using libtransmission's default settings as fallbacks for missing keys.
	 *
	 * @param dictionary where to put settings
	 * @param config_dir the configuration directory to find settings.json
	 * @param app_name if configDir is empty, appName is used to find the default dir.
	 * @return success true if the settings were loaded, false otherwise
	 */
	[CCode (cname = "tr_sessionLoadSettings")]
	public bool load_default_settings (ref variant_dict dictionary, string config_dir, string app_name);

	[CCode (cheader_filename = "libtransmission/transmission.h,libtransmission/variant.h", cprefix = "TR_VARIANT_FMT_", cname = "tr_variant_fmt", has_type_id = false)]
	public enum VariantFormat {
		BENC,
		JSON,
		JSON_LEAN
	}

	/**
	 * Variant data storage
	 *
	 * An object that acts like a union for integers, strings, lists, dictionaries, booleans, and floating-point numbers. The structure is named benc due to the historical reason that it was originally tightly coupled with bencoded data. It currently supports being parsed from, and serialized to, both bencoded notation and json notation.
	 *
	 */
	[CCode (cheader_filename = "libtransmission/transmission.h,libtransmission/variant.h", cname = "tr_variant", free_function = "tr_variantFree", has_type_id = false)]
	public struct variant {
		[CCode (cname = "tr_variantLoadFile")]
		public static int load_file (out variant variant, VariantFormat mode, string filename);
		[CCode (cname = "tr_variantParse")]
		public static int parse (void* buf, void* buffend, out variant variant, out unowned uint8[] end);
		[CCode (cname = "tr_variantLoad")]
		public static int load ([CCode (array_lengh_type = "size_t")] uint8[] buf, out variant variant, out unowned uint8[] end);

		[CCode (cname = "tr_variantInitStr")]
		public variant.str ([CCode (array_lengh_type = "int")] char[] raw);
		[CCode (cname = "tr_variantInitRaw")]
		public variant.raw ([CCode (array_lengh_type = "size_t")] uint8[] raw);
		[CCode (cname = "tr_variantInitInt")]
		public variant.int(int64 num);
		[CCode (cname = "tr_variantInitBool")]
		public variant.bool(int val);
		[CCode (cname = "tr_variantInitReal")]
		public variant.real (double val);

		[CCode (cname = "tr_variantToFile")]
		public int to_file (VariantFormat mode, string filename);

		[CCode (cname = "tr_variantToStr", array_length_pos = 1.9)]
		public uint8[] to_string (VariantFormat mode);

		/**
		 * Get an int64 from a variant object
		 *
		 * @return true if successful, or false if the variant could not be represented as an int64
		 */
		[CCode (cname = "tr_variantGetInt")]
		public bool get_int (out int64 val);

		/**
		 * Get an string from a variant object
		 *
		 * @return true if successful, or false if the variant could not be represented as a string
		 */
		[CCode (cname = "tr_variantGetStr")]
		public bool get_str (out string val);

		/**
		 * Get a raw byte array from a variant object
		 *
		 * @return true if successful, or false if the variant could not be represented as a raw byte array
		 */
		[CCode (cname = "tr_variantGetRaw")]
		public bool get_raw ([CCode (array_lengh_type = "size_t")] out uint8[] raw);

		/**
		 * Get a boolean from a variant object
		 *
		 * @return true if successful, or false if the variant could not be represented as a boolean
		 */
		[CCode (cname = "tr_variantGetBool")]
		public bool get_bool (out bool val);

		/**
		 * Get a floating-point number from a variant object
		 *
		 * @return true if successful, or false if the variant could not be represented as a floating-point number
		 */
		[CCode (cname = "tr_variantGetReal")]
		public bool GetReal (out double val);

		[CCode (cname = "tr_variantIsInt")]
		public bool is_int ();
		[CCode (cname = "tr_variantIsDict")]
		public bool is_dict ();
		[CCode (cname = "tr_variantIsList")]
		public bool is_list ();
		[CCode (cname = "tr_variantIsString")]
		public bool is_string ();
		[CCode (cname = "tr_variantIsBool")]
		public bool is_bool ();
		[CCode (cname = "tr_variantIsReal")]
		public bool is_real ();
	}
	[CCode (cheader_filename = "libtransmission/transmission.h,libtransmission/variant.h", cname = "tr_variant", free_function = "tr_variantFree", has_type_id = false)]
	public struct variant_list : variant {
		[CCode (cname = "tr_variantInitList")]
		public variant_list (size_t reserveCount);
		[CCode (cname = "tr_variantListReserve")]
		public int set_reserve (size_t reserve_count);
		[CCode (cname = "tr_variantListAdd")]
		public unowned variant? add_list ();
		[CCode (cname = "tr_variantListAddBool")]
		public unowned variant list_add_bool (bool val);
		[CCode (cname = "tr_variantListAddInt")]
		public unowned variant list_add_int (int64 val);
		[CCode (cname = "tr_variantListAddReal")]
		public unowned variant ListAddReal (double val);
		[CCode (cname = "tr_variantListAddStr")]
		public unowned variant ListAddStr (string val);
		[CCode (cname = "tr_variantListAddRaw")]
		public unowned variant ListAddRaw ([CCode (array_lengh_type = "size_t")] uint8[] val);
		[CCode (cname = "tr_variantListAddList")]
		public unowned variant ListAddList (size_t reserveCount);
		[CCode (cname = "tr_variantListAddDict")]
		public unowned variant ListAddDict (size_t reserveCount);
		public size_t size {
			[CCode (cname = "tr_variantListSize")]
			get;
		}
		[CCode (cname = "tr_variantListChild")]
		public unowned variant? get (size_t n);
		[CCode (cname = "tr_variantListRemove")]
		public bool remove (size_t n);
	}
	[CCode (cheader_filename = "libtransmission/transmission.h,libtransmission/variant.h", cname = "tr_variant", free_function = "tr_variantFree", has_type_id = false)]
	public struct variant_dict : variant {
		[CCode (cname = "tr_variantInitDict")]
		public variant_dict (size_t reserve_count);
		[CCode (cname = "tr_variantDictReserve")]
		public bool set_reserve (size_t reserve_count);
		[CCode (cname = "tr_variantDictRemove")]
		public bool remove (string key);
		[CCode (cname = "tr_variantDictAdd")]
		public unowned variant? add (string key);
		[CCode (cname = "tr_variantDictAddReal")]
		public unowned variant? add_real (string key, double val);
		[CCode (cname = "tr_variantDictAddInt")]
		public unowned variant? add_int (string key, int64 val);
		[CCode (cname = "tr_variantDictAddBool")]
		public unowned variant? add_bool (string key, bool val);
		[CCode (cname = "tr_variantDictAddStr")]
		public unowned variant? add_str (string key, string val);
		[CCode (cname = "tr_variantDictAddList")]
		public unowned variant? add_list (string key, size_t reserve);
		[CCode (cname = "tr_variantDictAddDict")]
		public unowned variant? add_dict (string key, size_t reserve);
		[CCode (cname = "tr_variantDictAddRaw")]
		public unowned variant? add_raw (string key, [CCode (array_lengh_type = "size_t")] uint8[] raw);
		[CCode (cname = "tr_variantDictChild")]
		public bool get_child (size_t i, out string key, out variant? val);
		[CCode (cname = "tr_variantDictFind")]
		public unowned variant? get (string key);
		[CCode (cname = "tr_variantDictFindList")]
		public bool find_list (string key, out unowned variant? val);
		[CCode (cname = "tr_variantDictFindDict")]
		public bool find_doc (string key, out unowned variant? val);
		[CCode (cname = "tr_variantDictFindInt")]
		public bool find_int (string key, out int64 val);
		[CCode (cname = "tr_variantDictFindReal")]
		public bool find_real (string key, out double val);
		[CCode (cname = "tr_variantDictFindBool")]
		public bool find_bool (string key, out bool val);
		[CCode (cname = "tr_variantDictFindStr")]
		public bool find_str (string key, out unowned string? val);
		[CCode (cname = "tr_variantDictFindRaw")]
		public bool find_raw (string key, [CCode (array_lengh_type = "size_t")] out uint8[]? raw);
	}

	[CCode (cname = "tr_session", cprefix = "tr_session", free_function = "tr_sessionClose", has_type_id = false)]
	[Compact]
	public class Session {
		/**
		 * Add the session's current configuration settings to the benc dictionary.
		 */
		[CCode (cname = "tr_sessionGetSettings")]
		public void get_settings (variant_dict dictionary);

		/**
		 * Add the session's configuration settings to the benc dictionary and save it to the configuration directory's settings.json file.
		 */
		[CCode (cname = "tr_sessionSaveSettings")]
		public void save_settings (string config_dir, variant_dict dictonary);

		/**
		 * Initialize a libtransmission session.
		 *
		 * @param config_dir where Transmission will look for resume files, blocklists, etc.
		 * @param message_queueing if false, messages will be dumped to stderr
		 * @param settings libtransmission settings
		 */
		[CCode (cname = "tr_sessionInit")]
		public Session (string config_dir, bool message_queueing, variant settings);

		/**
		 * Update a session's settings from a benc dictionary.
		 */
		[CCode (cname = "tr_sessionSet")]
		public void update_settings (variant_dict settings);

		/**
		 * Rescan the blocklists directory and reload whatever blocklist files are found there
		 */
		[CCode (cname = "tr_sessionReloadBlocklists")]
		public void reload_block_lists ();

		/**
		 * The session's configuration directory.
		 *
		 * This is where transmission stores its .torrent files, .resume files, blocklists, etc. It's set during initialisation and is immutable during the session.
		 */
		public string config_dir {
			[CCode (cname = "tr_sessionGetConfigDir")]
			get;
		}

		/**
		 * The per-session default download folder for new torrents.
		 *
		 * This can be overridden on a per-torrent basis by {@link TorrentConstructor.set_download_dir}.
		 */
		public string download_dir {
			[CCode (cname = "tr_sessionSetDownloadDir")]
			set;
			[CCode (cname = "tr_sessionGetDownloadDir")]
			get;
		}

		/**
		 * The per-session incomplete download folder.
		 *
		 * When you add a new torrent and the session's incomplete directory is enabled, the new torrent will start downloading into that directory, and then be moved to downloadDir when the torrent is finished downloading.
		 *
		 * Torrents aren't moved as a result of changing the session's incomplete dir -- it's applied to new torrents, not existing ones.
		 *
		 * {@link Torrent.set_location} overrules the incomplete dir: when a user specifies a new location, that becomes the torrent's new downloadDir and the torrent is moved there immediately regardless of whether or not it's complete.
		 */
		public string incomplete_dir {
			[CCode (cname = "tr_sessionSetIncompleteDir")]
			set;
			[CCode (cname = "tr_sessionGetIncompleteDir")]
			get;
		}

		/**
		 * Use of the incomplete download folder
		 */
		public bool use_incomplete_dir {
			[CCode (cname = "tr_seesionSetIncompleteDirEnabled")]
			set;
			[CCode (cname = "tr_sessionIsIncompleteDirEnabled")]
			get;
		}

		/**
		 * If files will end in ".part" until they're complete
		 *
		 * When enabled, newly-created files will have ".part" appended to their filename until the file is fully downloaded
		 *
		 * This is not retroactive -- toggling this will not rename existing files. It only applies to new files created by Transmission after this API call.
		 */
		public bool incomplete_file_naming {
			[CCode (cname = "tr_sessionSetIncompleteFileNamingEnabled")]
			set;
			[CCode (cname = "tr_sessionIsIncompleteFileNamingEnabled")]
			get;
		}

		/**
		 * Whether or not RPC calls are allowed in this session.
		 *
		 * If true, libtransmission will open a server socket to listen for incoming http RPC requests as described in docs/rpc-spec.txt.
		 */
		public bool rpc_enabled {
			[CCode (cname = "tr_sessionSetRPCEnabled")]
			set;
			[CCode (cname = "tr_sessionIsRPCEnabled")]
			get;
		}

		/**
		 * Listen port for RPC requests on.
		 */
		public uint32 rpc_port {
			[CCode (cname = "tr_sessionGetRPCPort")]
			get;
			[CCode (cname = "tr_sessionSetRPCPort")]
			set;
		}

		/**
		 * Which base URL to use.
		 *
		 * The RPC API is accessible under $url/rpc, the web interface under $url/web.
		 */
		public string rpc_url {
			[CCode (cname = "tr_sessionGetRPCUrl")]
			get;
			[CCode (cname = "tr_sessionSetRPCUrl")]
			set;
		}

		/**
		 * A whitelist for remote RPC access
		 *
		 * The whitelist is a comma-separated list of dotted-quad IP addresses to be allowed. Wildmat notation is supported, meaning that '?' is interpreted as a single-character wildcard and '*' is interprted as a multi-character wildcard.
		 */
		public string rpc_whitelist {
			[CCode (cname = "tr_sessionGetRPCWhitelist")]
			get;
			[CCode (cname = "tr_sessionSetRPCWhitelist")]
			set;
		}

		public bool rpc_whitelist_enabled {
			[CCode (cname = "tr_sessionSetRPCWhitelistEnabled")]
			set;
			[CCode (cname = "tr_sessionGetRPCWhitelistEnabled")]
			get;
		}

		public string rpc_password {
			[CCode (cname = "tr_sessionSetRPCPassword")]
			set;
			[CCode (cname = "tr_sessionGetRPCPassword")]
			get;
		}
		public string rpc_username {
			[CCode (cname = "tr_sessionSetRPCUsername")]
			set;
			[CCode (cname = "tr_sessionGetRPCUsername")]
			get;
		}

		public bool rpc_password_enabled {
			[CCode (cname = "tr_sessionSetRPCPasswordEnabled")]
			set;
			[CCode (cname = "tr_sessionIsRPCPasswordEnabled")]
			get;
		}

		public string rpc_bind_address {
			[CCode (cname = "tr_sessionGetRPCBindAddress")]
			get;
		}

		/**
		 * Register to be notified whenever something is changed via RPC, such as a torrent being added, removed, started, stopped, etc.
		 *
		 * The function is invoked FROM LIBTRANSMISSION'S THREAD! This means the function must be fast (to avoid blocking peers), shouldn't call libtransmission functions (to avoid deadlock), and shouldn't modify client-level memory without using a mutex!
		 */
		public Callback rpc_callback {
			[CCode (cname = "tr_sessionSetRPCCallback")]
			set;
			[CCode (cname = "tr_sessionGetRPCCallback")]
			get;
		}

		/**
		 * Get bandwidth use statistics for the current session
		 */
		[CCode (cname = "tr_sessionGetStats")]
		public void get_stats (out Stats stats);

		/**
		 * Get cumulative bandwidth statistics for current and past sessions
		 */
		[CCode (cname = "tr_sessionGetCumulativeStats")]
		public void get_cumulative_stats (out Stats stats);

		[CCode (cname = "tr_sessionClearStats")]
		public void clear_stats ();

		/**
		 * Set whether or not torrents are allowed to do peer exchanges.
		 *
		 * PEX is always disabled in private torrents regardless of this. In public torrents, PEX is enabled by default.
		 */
		public bool pex_enabled {
			[CCode (cname = "tr_sessionSetPexEnabled")]
			set;
			[CCode (cname = "tr_sessionIsPexEnabled")]
			get;
		}

		public bool dht_enabled {
			[CCode (cname = "tr_sessionSetDHTEnabled")]
			set;
			[CCode (cname = "tr_sessionIsDHTEnabled")]
			get;
		}

		public bool utp_enabled {
			[CCode (cname = "tr_sessionSetUTPEnabled")]
			set;
			[CCode (cname = "tr_sessionIsUTPEnabled")]
			get;
		}

		public bool lpd_enabled {
			[CCode (cname = "tr_sessionSetLPDEnabled")]
			set;
			[CCode (cname = "tr_sessionIsLPDEnabled")]
			get;
		}

		public int cache_limit {
			[CCode (cname = "tr_sessionSetCacheLimit_MB")]
			set;
			[CCode (cname = "tr_sessionGetCacheLimit_MB")]
			get;
		}

		public EncryptionMode Encryption {
			[CCode (cname = "tr_sessionSetEncryption")]
			set;
			[CCode (cname = "tr_sessionGetEncryption")]
			get;
		}

		public bool port_forwarding_enabled {
			[CCode (cname = "tr_sessionSetPortForwardingEnabled")]
			set;
			[CCode (cname = "tr_sessionIsPortForwardingEnabled")]
			get;
		}

		public uint32 peer_port {
			[CCode (cname = "tr_sessionSetPeerPort")]
			set;
			[CCode (cname = "tr_sessionGetPeerPort")]
			get;
		}

		public bool peer_port_random_on_start {
			[CCode (cname = "tr_sessionSetPeerPortRandomOnStart")]
			set;
			[CCode (cname = "tr_sessionGetPeerPortRandomOnStart")]
			get;
		}

		public PortForwarding port_forwarding {
			[CCode (cname = "tr_sessionGetPortForwarding")]
			get;
		}

		[CCode (cname = "tr_sessionSetSpeedLimit_KBps")]
		public void set_speed_limit (Direction direction, int kbps);
		[CCode (cname = "tr_sessionGetSpeedLimit_KBps")]
		public int get_speed_limit (Direction direction);

		[CCode (cname = "tr_sessionLimitSpeed")]
		public void set_speed_limited (Direction direction, bool limited);
		[CCode (cname = "tr_sessionIsSpeedLimited")]
		public bool is_speed_limited (Direction direction);

		[CCode (cname = "tr_sessionSetAltSpeed_KBps")]
		public void set_alt_speed (Direction direction, int bps);
		[CCode (cname = "tr_sessionGetAltSpeed_KBps")]
		public int get_alt_speed (Direction direction);

		public bool use_alt_speed {
			[CCode (cname = "tr_sessionUseAltSpeed")]
			set;
			[CCode (cname = "tr_sessionUsesAltSpeed")]
			get;
		}

		public bool use_alt_time {
			[CCode (cname = "tr_sessionUseAltSpeedTime")]
			set;
			[CCode (cname = "tr_sessionUsesAltSpeedTime")]
			get;
		}

		public int alt_speed_begin {
			[CCode (cname = "tr_sessionSetAltSpeedBegin")]
			set;
			[CCode (cname = "tr_sessionGetAltSpeedBegin")]
			get;
		}

		public int alt_speed_end {
			[CCode (cname = "tr_sessionSetAltSpeedEnd")]
			set;
			[CCode (cname = "tr_sessionGetAltSpeedEnd")]
			get;
		}

		public ScheduleDay alt_speed_day {
			[CCode (cname = "tr_sessionSetAltSpeedDay")]
			set;
			[CCode (cname = "tr_sessionGetAltSpeedDay")]
			get;
		}

		[CCode (cname = "tr_sessionClearAltSpeedFunc")]
		public void clear_alt_speed_func ();
		[CCode (cname = "tr_sessionSetAltSpeedFunc")]
		public void set_alt_speed_func (AltSpeedFunc func);

		[CCode (cname = "tr_sessionGetActiveSpeedLimit_KBps")]
		public bool get_active_speed_limit (Direction dir, out double limit);

		[CCode (cname = "tr_sessionGetRawSpeed_KBps")]
		public double get_raw_speed (Direction direction);

		public bool ratio_limited {
			[CCode (cname = "tr_sessionSetRatioLimited")]
			set;
			[CCode (cname = "tr_sessionIsRatioLimited")]
			get;
		}

		public double ratio_limit {
			[CCode (cname = "tr_sessionSetRatioLimit")]
			set;
			[CCode (cname = "tr_sessionGetRatioLimit")]
			get;
		}

		public bool idle_limited {
			[CCode (cname = "tr_sessionSetIdleLimited")]
			set;
			[CCode (cname = "tr_sessionIsIdleLimited")]
			get;
		}

		public uint16 idle_limit {
			[CCode (cname = "tr_sessionSetIdleLimit")]
			set;
			[CCode (cname = "tr_sessionGetIdleLimit")]
			get;
		}

		public uint16 peer_limit {
			[CCode (cname = "tr_sessionSetPeerLimit")]
			set;
			[CCode (cname = "tr_sessionGetPeerLimit")]
			get;
		}

		public uint16 peer_limit_per_torrent {
			[CCode (cname = "tr_sessionSetPeerLimitPerTorrent")]
			set;
			[CCode (cname = "tr_sessionGetPeerLimitPerTorrent")]
			get;
		}

		public bool paused {
			[CCode (cname = "tr_sessionSetPaused")]
			set;
			[CCode (cname = "tr_sessionGetPaused")]
			get;
		}

		public bool delete_source {
			[CCode (cname = "tr_sessionSetDeleteSource")]
			set;
			[CCode (cname = "tr_sessionGetDeleteSource")]
			get;
		}

		/**
		 * Load all the torrents in the torrent directory.
		 *
		 * This can be used at startup to kickstart all the torrents from the previous session.
		 */
		[CCode (array_length_pos = 1.9, free_function = "tr_free", cname = "tr_sessionLoadTorrents")]
		public Torrent[] load_torrents (TorrentConstructor ctor);

		public bool torrent_done_script_enabled {
			[CCode (cname = "tr_sessionSetTorrentDoneScriptEnabled")]
			set;
			[CCode (cname = "tr_sessionIsTorrentDoneScriptEnabled")]
			get;
		}

		public string torrent_done_script {
			[CCode (cname = "tr_sessionSetTorrentDoneScript")]
			set;
			[CCode (cname = "tr_sessionGetTorrentDoneScript")]
			get;
		}
		[CCode (cname = "tr_torrentFindFromId")]
		public unowned Torrent get (int id);
		[CCode (cname = "tr_torrentFindFromHash")]
		public unowned Torrent get_by_hash ([CCode (array_length = false)] uint8[] hash);
		[CCode (cname = "tr_torrentFindFromMagnetLink")]
		public unowned Torrent get_by_magnet (string link);

		public BlockList blocklist {
			[CCode (cname = "")]
			get;
		}
	}

	[CCode (cname = "tr_session", has_type_id = false)]
	[Compact]
	public class BlockList {
		/**
		 * The file in the $config/blocklists/ directory that's used by {@link set_content} and "blocklist-update"
		 */
		public const string DEFAULT_FILENAME;

		/**
		 * Specify a range of IPs for Transmission to block.
		 *
		 * @param filename The uncompressed ASCII file, or null to clear the blocklist. libtransmission does not keep a handle to `filename' after this call returns, so the caller is free to keep or delete `filename' as it wishes. libtransmission makes its own copy of the file massaged into a binary format easier to search.
		 * @return the number of rules
		 */
		[CCode (cname = "tr_blocklistSetContent")]
		public int set_content (string? filename);
		public int count {
			[CCode (cname = "tr_blocklistGetRuleCount")]
			get;
		}
		public bool exists {
			[CCode (cname = "tr_blocklistExists")]
			get;
		}
		[CCode (cname = "tr_blocklistSetEnabled")]
		public bool enabled {
			[CCode (cname = "tr_blocklistSetEnabled")]
			set;
			[CCode (cname = "tr_blocklistIsEnabled")]
			get;
		}
		/**
		 * The blocklist that gets updated when an RPC client invokes the "blocklist-update" method
		 */
		public string url {
			[CCode (cname = "tr_blocklistSetURL")]
			set;
			[CCode (cname = "tr_blocklistGetURL")]
			get;
		}
	}

	[CCode (cname = "tr_altSpeedFunc", has_type_id = false)]
	public delegate void AltSpeedFunc (Session session, bool active, bool userDriven);

	[CCode (cname = "tr_sched_day", cprefix = "TR_SCHED_", has_type_id = false)]
	[Flags]
	public enum ScheduleDay {
		SUN,
		MON,
		TUES,
		WED,
		THURS,
		FRI,
		SAT,
		WEEKDAY,
		WEEKEND,
		ALL
	}

	[CCode (cname = "tr_port_forwarding", cprefix = "TR_PORT_", has_type_id = false)]
	public enum PortForwarding {
		ERROR,
		UNMAPPED,
		UNMAPPING,
		MAPPING,
		MAPPED
	}

	[CCode (cname = "tr_direction", cprefix = "TR_", has_type_id = false)]
	public enum Direction {
		CLIENT_TO_PEER, UP,
		PEER_TO_CLIENT, DOWN
	}

	[CCode (cname = "tr_rpc_callback_type", cprefix = "TR_RPC_", has_type_id = false)]
	public enum CallbackType {
		TORRENT_ADDED,
		TORRENT_STARTED,
		TORRENT_STOPPED,
		TORRENT_REMOVING,
		TORRENT_TRASHING,
		TORRENT_CHANGED,
		TORRENT_MOVED,
		SESSION_CHANGED,
		SESSION_CLOSE
	}

	[CCode (cname = "tr_rpc_callback_status", cprefix = "TR_RPC_", has_type_id = false)]
	public enum CallbackStatus {
		/**
		 * No special handling is needed by the caller
		 */
		OK,
		/**
		 * Indicates to the caller that the client will take care of removing the torrent itself. For example the client may need to keep the torrent alive long enough to cleanly close some resources in another thread.
		 */
		NOREMOVE
	}

	[CCode (cname = "tr_rpc_func", has_type_id = false)]
	public delegate CallbackStatus Callback (Session session, CallbackType type, Torrent? torrent);

	[CCode (cname = "tr_session_stats", has_type_id = false)]
	[Compact]
	public class Stats {
		public float ratio;
		public uint64 uploadedBytes;
		public uint64 downloadedBytes;
		public uint64 filesAdded;
		public uint64 sessionCount;
		public uint64 secondsActive;
	}

	[CCode (cname = "tr_msg_level", cprefix = "TR_MSG_", has_type_id = false)]
	public enum MessageLevel {
		ERR,
		INF,
		DBG;
		[CCode (cname = "tr_setMessageLevel")]
		public void activate ();
		[CCode (cname = "getMessageLevel", cheader_filename = "libtransmission/utils.h")]
		public static MessageLevel get_current ();
		[CCode (cname = "msgLoggingIsActive", cheader_filename = "libtransmission/utils.h")]
		public bool is_logging_active ();
	}

	[CCode (cname = "tr_msg_list", free_function = "freeMessageList", has_type_id = false)]
	[Compact]
	public class MessageList {
		public MessageList level;
		/**
		 * The line number in the source file where this message originated
		 */
		public int line;
		/**
		 * Time the message was generated
		 */
		public time_t when;
		/**
		 * The torrent associated with this message, or a module name such as "Port Forwarding" for non-torrent messages, or null.
		 */
		public string? name;
		/**
		 * The message
		 */
		public string message;
		/**
		 * The source file where this message originated
		 */
		public const string file;
		public MessageList next;
	}

	[CCode (cname = "tr_setMessageQueuing")]
	public void set_message_queuing (bool is_enabled);
	[CCode (cname = "tr_getMessageQueuing")]
	public bool get_message_queuing ();

	[CCode (cname = "tr_getQueuedMessages")]
	public MessageList get_queued_messages ();

	[CCode (cname = "tr_ctorMode", cprefix = "TR_", has_type_id = false)]
	public enum ConstructionMode {
		/**
		 * Indicates the constructor value should be used only in case of missing resume settings
		 */
		FALLBACK,
		/**
		 * Indicates the constructor value should be used regardless of what's in the resume settings
		 */
		FORCE
	}

	/**
	 * Utility class to instantiate {@link Torrent}s
	 *
	 * Instantiating a {@link Torrent} had gotten more complicated as features were added. At one point there were four functions to check metainfo and five to create a {@link Torrent} object.
	 *
	 * To remedy this, a Torrent Constructor has been introduced:
	 * * Simplifies the API to two functions: {@link TorrentConstructor.parse} and {@link TorrentConstructor.instantiate}
	 * * You can set the fields you want; the system sets defaults for the rest.
	 * * You can specify whether or not your fields should supercede resume's.
	 * * We can add new features to the torrent constructor without breaking {@link TorrentConstructor.instantiate}'s API.
	 *
	 * You must call one of the {@link TorrentConstructor.set_metainfo} functions before creating a torrent with a torrent constructor. The other functions are optional.
	 *
	 * You can reuse a single tr_ctor to create a batch of torrents -- just call one of the SetMetainfo() functions between each {@link TorrentConstructor.instantiate} call.
	 */
	[CCode (cname = "tr_ctor", cprefix = "tr_ctor", free_function = "tr_ctorFree", has_type_id = false)]
	[Compact]
	public class TorrentConstructor {
		/**
		 * The torrent's bandwidth priority.
		 */
		public Priority bandwidth_priority {
			[CCode (cname = "tr_ctorSetBandwidthPriority")]
			set;
			[CCode (cname = "tr_ctorGetBandwidthPriority")]
			get;
		}

		/**
		 * Create a torrent constructor object used to instantiate a {@link Torrent}
		 * @param session This is required if you're going to call {@link TorrentConstructor.instantiate}, but you can use null for {@link TorrentConstructor.parse}.
		 */
		[CCode (cname = "tr_ctorNew")]
		public TorrentConstructor (Session? session);

		/**
		 * Instantiate a single torrent.
		 */
		[CCode (cname = "tr_torrentNew")]
		public unowned Torrent? instantiate (out ParseResult error, out int duplicate_id);

		/**
		 * Whether or not to delete the source .torrent file when the torrent is added. (Default: False)
		 */
		public bool delete_source {
			[CCode (cname = "tr_ctorSetDeleteSource")]
			set;
			[CCode (cname = "tr_ctorGetDeleteSource")]
			get;
		}

		/**
		 * Set the constructor's metainfo from a magnet link
		 */
		[CCode (cname = "tr_ctorSetMetainfoFromMagnetLink")]
		public int set_metainfo_from_magnet_link (string magnet);

		/**
		 * Set the constructor's metainfo from a raw benc already in memory
		 */
		[CCode (cname = "tr_ctorSetMetainfo")]
		public int set_metainfo ([CCode (array_length_type = "size_t")] uint8[] metainfo);

		/**
		 * Set the constructor's metainfo from a local .torrent file
		 */
		[CCode (cname = "tr_ctorSetMetainfoFromFile")]
		public int set_metainfo_from_file (string filename);

		/**
		 * Set the metainfo from an existing file in the torrent directory.
		 *
		 * This is used by the Mac client on startup to pick and choose which
		 * torrents to load
		 */
		[CCode (cname = "tr_ctorSetMetainfoFromHash")]
		public int set_metainfo_from_hash (string hash_string);

		/**
		 * Set how many peers this torrent can connect to. (Default: 50)
		 */
		[CCode (cname = "tr_ctorSetPeerLimit")]
		public void set_peer_limit (ConstructionMode mode, uint16 limit);

		/**
		 * Set the download folder for the torrent being added with this ctor.
		 */
		[CCode (cname = "tr_ctorSetDownloadDir")]
		public void set_download_dir (ConstructionMode mode, string directory);

		/**
		 * Set whether or not the torrent begins downloading/seeding when created. (Default: not paused)
		 */
		[CCode (cname = "tr_ctorSetPaused")]
		public void set_paused (ConstructionMode mode, bool is_paused);

		/**
		 * Set the priorities for files in a torrent
		 */
		[CCode (cname = "tr_ctorSetFilePriorities")]
		public void set_file_priorities ([CCode (array_length_type = "tr_file_index_t")] file_index[] files, int8 priority);

		/**
		 * Set the download flag for files in a torrent
		 */
		[CCode (cname = "tr_ctorSetFilesWanted")]
		public void set_files_wanted ([CCode (array_length_type = "tr_file_index_t")] file_index[] files, bool wanted);

		/**
		 * Get this peer constructor's peer limit
		 */
		[CCode (cname = "tr_ctorGetPeerLimit")]
		public int get_peer_limit (ConstructionMode mode, out uint16 count);

		/**
		 * Get the paused flag from this peer constructor
		 */
		[CCode (cname = "tr_ctorGetPaused")]
		public int get_paused (ConstructionMode mode, out bool is_paused);

		/**
		 * Get the download path from this peer constructor
		 */
		[CCode (cname = "tr_ctorGetDownloadDir")]
		public bool get_download_dir (ConstructionMode mode, out unowned string? download_dir);

		/**
		 * Get the incomplete directory from this peer constructor
		 */
		[CCode (cname = "tr_ctorGetIncompleteDir")]
		public bool get_incomplete_dir (out unowned string? incomplete_dir);

		/**
		 * Get the metainfo from this peer constructor
		 */
		[CCode (cname = "tr_ctorGetMetainfo")]
		public bool get_metainfo (out unowned variant variant);

		/**
		 * Get the "delete .torrent file" flag from this peer constructor
		 */
		[CCode (cname = "tr_ctorGetDeleteSource")]
		public bool get_delete_source (out bool do_delete);

		/**
		 * The underlying session from this peer constructor
		 */
		public Session? session {
			[CCode (cname = "tr_ctorGetSession")]
			get;
		}

		/**
		 * Get the .torrent file that this torrent constructors 's metainfo came from, or null if {@link TorrentConstructor.set_metainfo_from_file} wasn't used
		 */
		public string? source_file {
			[CCode (cname = "tr_ctorGetSourceFile")]
			get;
		}

		/**
		 * Parses the specified metainfo
		 *
		 * This method won't be able to check for duplicates -- and therefore won't return {@link ParseResult.DUPLICATE} -- unless the constructors's "download-dir" and session variable is set.
		 *
		 * The torrent field of the info can't be set unless constructors's session variable is set.
		 *
		 * @param info If parsing is successful and info is non-null, the parsed metainfo is stored there
		 */
		[CCode (cname = "tr_torrentParse")]
		public ParseResult parse (out info info);
	}

	[CCode (cname = "tr_parse_result", cprefix = "TR_PARSE_", has_type_id = false)]
	public enum ParseResult {
		OK,
		ERR,
		DUPLICATE
	}

	[CCode (cname = "tr_fileFunc", has_target = false, has_type_id = false)]
	public delegate int FileFunc (string filename);

	[CCode (cname = "int", cprefix = "TR_LOC_", has_type_id = false)]
	public enum LocationStatus {
		MOVING,
		DONE,
		ERROR
	}

	[CCode (cname = "tr_ratiolimit", cprefix = "TR_RATIOLIMIT_", has_type_id = false)]
	public enum RatioLimit {
		/**
		 * Follow the global settings
		 */
		GLOBAL,
		/**
		 * Orverride the global settings, seeding until a certain ratio
		 */
		SINGLE,
		/**
		 * Override the global settings, seeding regardless of ratio
		 */
		UNLIMITED
	}

	[CCode (cname = "tr_idlelimit", cprefix = "TR_IDLELIMIT_", has_type_id = false)]
	public enum IdleLimit {
		/**
		 * Follow the global settings
		 */
		GLOBAL,
		/**
		 * Override the global settings, seeding until a certain idle time
		 */
		SINGLE,
		/**
		 * Override the global settings, seeding regardless of activity
		 */
		UNLIMITED
	}

	[CCode (cname = "int", cprefix = "TR_PRI_", has_type_id = false)]
	public enum Priority {
		LOW,
		NORMAL,
		HIGH
	}

	/**
	 * Represents a single tracker
	 */
	[CCode (cname = "tr_tracker_info", has_destroy_function = false, has_copy_function = false, has_type_id = false)]
	public struct tracker_info {
		public int tier;
		public unowned string announce;
		public unowned string scrape;
		/**
		 * Unique identifier used to match to a {@link tracker_stat}
		 */
		public uint32 id;
	}

	[CCode (cname = "tr_completeness", cprefix = "TR_", has_type_id = false)]
	public enum Completeness {
		/**
		 * Doesn't have all the desired pieces
		 */
		LEECH,
		/**
		 * Has the entire torrent
		 */
		SEED,
		/**
		 * Has the desired pieces, but not the entire torrent
		 */
		PARTIAL_SEED
	}

	[CCode (cname = "tr_torrent_completeness_func", has_type_id = false)]
	public delegate void CompletnessFunc (Torrent torrent, Completeness completeness, bool wasRunning);
	[CCode (cname = "tr_torrent_ratio_limit_hit_func", has_type_id = false)]
	public delegate void RatioLimitHitFunc (Torrent torrent);
	[CCode (cname = "tr_torrent_idle_limit_hit_func", has_type_id = false)]
	public delegate void IdleLimitHitFunc (Torrent torrent);
	[CCode (cname = "tr_torrent_metadata_func", has_type_id = false)]
	public delegate void MetadataFunc (Torrent torrent);

	[CCode (cname = "tr_peer_stat", has_destroy_function = false, has_copy_function = false, has_type_id = false)]
	public struct peer_stat {
		[CCode (cname = "isUTP")]
		public bool is_utp;
		[CCode (cname = "isEncrypted")]
		public bool is_encrypted;
		[CCode (cname = "isDownloadingFrom")]
		public bool is_downloading_from;
		[CCode (cname = "isUploadingTo")]
		public bool is_uploading_to;
		[CCode (cname = "isSeed")]
		public bool is_seed;
		[CCode (cname = "peerIsChoked")]
		public bool peer_is_choked;
		[CCode (cname = "peerIsInterested")]
		public bool peer_is_interested;
		[CCode (cname = "clientIsChoked")]
		public bool client_is_choked;
		[CCode (cname = "clientIsInterested")]
		public bool client_is_interested;
		[CCode (cname = "isIncoming")]
		public bool is_incoming;
		public uint8 from;
		public uint32 port;
		public unowned char addr[46];
		public unowned char client[80];
		[CCode (cname = "flagStr")]
		public unowned char flag[32];
		public float progress;
		[CCode (cname = "rateToPeer_KBps")]
		public double rate_to_peer_kbps;
		[CCode (cname = "rateToClient_KBps")]
		public double rate_to_client_kbps;

		/**
		 * How many requests the peer has made that we haven't responded to yet
		 */
		[CCode (cname = "pendingReqsToClient")]
		public int pending_reqs_to_client;

		/**
		 * How many requests we've made and are currently awaiting a response for
		 */
		[CCode (cname = "pendingReqsToPeer")]
		public int pending_reqs_to_peer;
	}
	[CCode (cname = "tr_tracker_state", cprefix = "TR_TRACKER_", has_type_id = false)]
	public enum TrackerState {
		/**
		 * Won't (announce,scrape) this torrent to this tracker because the torrent is stopped, or because of an error, or whatever
		 */
		INACTIVE,
		/**
		 * Will (announce,scrape) this torrent to this tracker, and are waiting for enough time to pass to satisfy the tracker's interval
		 */
		WAITING,
		/**
		 * It's time to (announce,scrape) this torrent, and we're waiting on a a free slot to open up in the announce manager
		 */
		QUEUED,
		/**
		 * We're (announcing,scraping) this torrent right now
		 */
		ACTIVE
	}

	[CCode (cname = "tr_tracker_stat", has_destroy_function = false, has_copy_function = false, has_type_id = false)]
	public struct tracker_stat {
		/**
		 * How many downloads this tracker knows of (-1 means it does not know)
		 */
		public int downloadCount;

		/**
		 * Whether or not we've ever sent this tracker an announcement
		 */
		public bool hasAnnounced;

		/**
		 * Whether or not we've ever scraped to this tracker
		 */
		public bool hasScraped;

		/**
		 * Human-readable string identifying the tracker
		 */
		public unowned char host[1024];

		/**
		 * The full announce URL
		 */
		public unowned char announce[1024];

		/**
		 * The full scrape URL
		 */
		public unowned char scrape[1024];

		/**
		 * Transmission uses one tracker per tier, and the others are kept as backups
		 */
		public bool isBackup;

		/**
		 * Is the tracker announcing, waiting, queued, etc
		 */
		public TrackerState announceState;

		/**
		 * Is the tracker scraping, waiting, queued, etc
		 */
		public TrackerState scrapeState;

		/**
		 * Number of peers the tracker told us about last time. If {@link tracker_stat.lastAnnounceSucceeded} is false, this field is undefined.
		 */
		public int lastAnnouncePeerCount;

		/**
		 * Human-readable string with the result of the last announce. If {@link tracker_stat.hasAnnounced} is false, this field is undefined.
		 */
		public unowned char lastAnnounceResult[128];

		/**
		 * When the last announce was sent to the tracker. If {@link tracker_stat.hasAnnounced} is false, this field is undefined
		 */
		public time_t lastAnnounceStartTime;

		/**
		 * Whether or not the last announce was a success. If {@link tracker_stat.hasAnnounced} is false, this field is undefined.
		 */
		public bool lastAnnounceSucceeded;

		/**
		 * Whether or not the last announce timed out.
		 */
		public bool lastAnnounceTimedOut;

		/**
		 * When the last announce was completed. If {@link tracker_stat.hasAnnounced} is false, this field is undefined
		 */
		public time_t lastAnnounceTime;

		/**
		 * Human-readable string with the result of the last scrape. If {@link tracker_stat.hasScraped} is false, this field is undefined.
		 */
		public unowned char lastScrapeResult[128];

		/**
		 * When the last scrape was sent to the tracker. If {@link tracker_stat.hasScraped} is false, this field is undefined.
		 */
		public time_t lastScrapeStartTime;

		/**
		 * Whether or not the last scrape was a success. If {@link tracker_stat.hasAnnounced} is false, this field is undefined.
		 */
		public bool lastScrapeSucceeded;

		/**
		 * Whether or not the last scrape timed out.
		 */
		public bool lastScrapeTimedOut;

		/**
		 * When the last scrape was completed. If {@link tracker_stat.hasScraped} is false, this field is undefined.
		 */
		public time_t lastScrapeTime;

		/**
		 * Number of leechers this tracker knows of (-1 means it does not know)
		 */
		public int leecherCount;

		/**
		 * When the next periodic announce message will be sent out. If {@link tracker_stat.announceState} isn't {@link TrackerState.WAITING}, this field is undefined.
		 */
		public time_t nextAnnounceTime;

		/**
		 * when the next periodic scrape message will be sent out. If {@link tracker_stat.scrapeState} isn't {@link TrackerState.WAITING}, this field is undefined.
		 */
		public time_t nextScrapeTime;

		/**
		 * Number of seeders this tracker knows of (-1 means it does not know)
		 */
		public int seederCount;

		/**
		 * Which tier this tracker is in
		 */
		public int tier;
		/**
		 * Used to match to a {@link tracker_info}
		 */
		public uint32 id;
	}

	[CCode (cname = "tr_file_stat", has_destroy_function = false, has_copy_function = false, has_type_id = false)]
	public struct file_stat {
		public uint64 bytesCompleted;
		public float progress;
	}

	/**
	 * A single file of the torrent's content
	 */
	[CCode (cname = "tr_file", has_destroy_function = false, has_copy_function = false, has_type_id = false)]
	public struct File {
		/**
		 * Length of the file, in bytes
		 */
		public uint64 length;
		/**
		 * Path to the file
		 */
		public unowned string name;
		public Priority priority;
		/**
		 * "Do not download" flag
		 */
		public int8 dnd;
		/**
		 * We need pieces [firstPiece...
		 */
		public uint32 firstPiece;
		/**
		 * ...lastPiece] to dl this file
		 */
		public uint32 lastPiece;
		/**
		 * File begins at the torrent's nth byte
		 */
		public uint64 offset;
	}

	/**
	 * A single piece of the torrent's content
	 */
	[CCode (cname = "tr_piece", has_destroy_function = false, has_copy_function = false, has_type_id = false)]
	public struct Piece {
		/**
		 * The last time we tested this piece
		 */
		public time_t timeChecked;
		/**
		 * Pieces hash
		 */
		public unowned uint8 hash[20];
		public int8 priority;
		/**
		 * "Do not download" flag
		 */
		public int8 dnd;
	}

	/**
	 * Information about a torrent that comes from its metainfo file
	 */
	[CCode (cname = "tr_info", has_destroy_function = false, has_copy_function = false, has_type_id = false)]
	public struct info {
		/**
		 * Total size of the torrent, in bytes
		 */
		public uint64 totalSize;
		/**
		 * The torrent's name
		 */
		public unowned string name;
		/**
		 * Path to torrent Transmission's internal copy of the .torrent file.
		 */
		public unowned string torrent;

		[CCode (array_length_type = "int", array_length_cname = "webseedCount")]
		public unowned string[] webseeds;

		public unowned string comment;
		public unowned string creator;
		[CCode (array_length_type = "tr_file_index_t", array_length_cname = "fileCount")]
		public unowned File[] files;
		[CCode (array_length_type = "tr_piece_index_t", array_length_cname = "pieceCount")]
		public unowned Piece[] pieces;

		/**
		 * These trackers are sorted by tier
		 */
		[CCode (array_length_type = "int", array_length_cname = "trackerCount")]
		public unowned tracker_info[] trackers;

		public time_t dateCreated;

		public uint32 pieceSize;

		public uint8 hash[20];
		public unowned string hashString;
		public bool isPrivate;
		public bool isMultifile;
	}

	/**
	 * What the torrent is doing right now.
	 */
	[CCode (cname = "tr_torrent_activity", cprefix = "TR_STATUS_", has_type_id = false)]
	[Flags]
	public enum Activity {
		/**
		 * Waiting in queue to check files
		 */
		CHECK_WAIT,
		/**
		 * Checking files
		 */
		CHECK,
		/**
		 * Downloading
		 */
		DOWNLOAD,
		/**
		 * Seeding
		 */
		SEED,
		/**
		 * Torrent is stopped
		 */
		STOPPED,
	}

	[CCode (cname = "int", cprefix = "TR_PEER_FROM_", has_type_id = false)]
	public enum PeerFrom {
		/**
		 * Connections made to the listening port
		 */
		INCOMING,
		/**
		 * Peers found by local announcements
		 */
		LPD,
		/**
		 * Peers found from a tracker
		 */
		TRACKER,
		/**
		 * Peers found from the DHT
		 */
		DHT,
		/**
		 * Peers found from PEX
		 */
		PEX,
		/**
		 * Peers found in the .resume file
		 */
		RESUME,
		/**
		 * Peer address provided in an LTEP handshake
		 */
		LTEP
	}

	[CCode (cname = "tr_stat_errtype", cprefix = "TR_STAT_", has_type_id = false)]
	public enum StatError {
		/**
		 * Everything's fine
		 */
		OK,
		/**
		 * When we anounced to the tracker, we got a warning in the response
		 */
		TRACKER_WARNING,
		/**
		 * When we anounced to the tracker, we got an error in the response
		 */
		TRACKER_ERROR,
		/**
		 * Local trouble, such as disk full or permissions error
		 */
		LOCAL_ERROR
	}

	[CCode (cname = "TR_RATIO_NA")]
	public const double RATIO_NA;
	[CCode (cname = "TR_RATIO_INF")]
	public const double RATIO_INF;

	[CCode (cname = "TR_ETA_NOT_AVAIL ")]
	public int ETA_NOT_AVAIL;
	[CCode (cname = "TR_ETA_UNKNOWN ")]
	public int ETA_UNKNOWN;

	/**
	 * A torrent's state and statistics
	 */
	[CCode (cname = "tr_stat", has_type_id = false)]
	public struct stat {
		/**
		 * The torrent's unique Id.
		 * @see Torrent.id
		 */
		public int id;
		/**
		 * What is this torrent doing right now?
		 */
		public Activity activity;
		/**
		 * Defines what kind of text is in errorString.
		 */
		public StatError error;
		/**
		 * A warning or error message regarding the torrent.
		 */
		public char errorString[512];
		/**
		 * When {@link stat.activity} is {@link Activity.CHECK} or {@link Activity.CHECK_WAIT}, this is the percentage of how much of the files has been verified. When it gets to 1, the verify process is done.
		 */
		public float recheckProgress;
		/**
		 * How much has been downloaded of the entire torrent.
		 */
		public float percentComplete;
		/**
		 * How much of the metadata the torrent has. For torrents added from a .torrent this will always be 1. For magnet links, this number will from from 0 to 1 as the metadata is downloaded.
		 */
		public float metadataPercentComplete;
		/**
		 * How much has been downloaded of the files the user wants. This differs from {@link stat.percentComplete} if the user wants only some of the torrent's files.
		 */
		public float percentDone;
		/**
		 * How much has been uploaded to satisfy the seed ratio. This is 1 if the ratio is reached or the torrent is set to seed forever.
		 */
		public float seedRatioPercentDone;
		/**
		 * Speed all data being sent for this torrent. This includes piece data, protocol messages, and TCP overhead
		 */
		public float rawUploadSpeed_KBps;
		/**
		 *  Speed all data being received for this torrent. This includes piece data, protocol messages, and TCP overhead
		 */
		public float rawDownloadSpeed_KBps;
		/**
		 * Speed all piece being sent for this torrent. This ONLY counts piece data.
		 */
		public float pieceUploadSpeed_KBps;
		/**
		 * Speed all piece being received for this torrent. This ONLY counts piece data.i
		 */
		public float pieceDownloadSpeed_KBps;
		/**
		 * If downloading, estimated number of seconds left until the torrent is done. If seeding, estimated number of seconds left until seed ratio is reached.
		 */
		public int eta;
		/**
		 * If seeding, number of seconds left until the idle time limit is reached.
		 */
		public int etaIdle;
		/**
		 * Number of peers that we're connected to
		 */
		public int peersConnected;
		/**
		 * How many peers we found out about from the tracker, or from PEX, or from incoming connections, or from our resume file.
		 */
		public int peersFrom[8];
		/**
		 * Number of peers that are sending data to us.
		 */
		public int peersSendingToUs;
		/**
		 * Number of peers that we're sending data to
		 */
		public int peersGettingFromUs;
		/**
		 * Number of webseeds that are sending data to us.
		 */
		public int webseedsSendingToUs;
		/**
		 * Byte count of all the piece data we'll have downloaded when we're done, whether or not we have it yet. This may be less than {@link info.totalSize} if only some of the torrent's files are wanted.
		 */
		public uint64 sizeWhenDone;
		/**
		 * Byte count of how much data is left to be downloaded until we've got all the pieces that we want.
		 */
		public uint64 leftUntilDone;
		/**
		 * Byte count of all the piece data we want and don't have yet, but that a connected peer does have.
		 */
		public uint64 desiredAvailable;
		/**
		 * Byte count of all the corrupt data you've ever downloaded for this torrent. If you're on a poisoned torrent, this number can grow very large.
		 */
		public uint64 corruptEver;
		/**
		 * Byte count of all data you've ever uploaded for this torrent.
		 */
		public uint64 uploadedEver;
		/**
		 * Byte count of all the non-corrupt data you've ever downloaded for this torrent. If you deleted the files and downloaded a second time, this will be 2*totalSize.
		 */
		public uint64 downloadedEver;
		/**
		 * Byte count of all the checksum-verified data we have for this torrent.
		 */
		public uint64 haveValid;
		/**
		 * Byte count of all the partial piece data we have for this torrent. As pieces become complete, this value may decrease as portions of it are moved to `corrupt' or `haveValid'.
		 */
		public uint64 haveUnchecked;
		/**
		 * Time when one or more of the torrent's trackers will allow you to manually ask for more peers, or 0 if you can't
		 */
		public time_t manualAnnounceTime;
		/**
		 * {@link RATIO_INF}, {@link RATIO_NA}, or a regular ratio
		 */
		public float ratio;
		/**
		 * When the torrent was first added.
		 */
		public time_t addedDate;
		/**
		 * When the torrent finished downloading.
		 */
		public time_t doneDate;
		/**
		 * When the torrent was last started.
		 */
		public time_t startDate;
		/**
		 * The last time we uploaded or downloaded piece data on this torrent.
		 */
		public time_t activityDate;
		/**
		 * Number of seconds since the last activity (or since started). -1 if activity is not seeding or downloading.
		 */
		public int idleSecs;
		/**
		 * Cumulative seconds the torrent's ever spent downloading
		 */
		public int secondsDownloading;
		/**
		 * Cumulative seconds the torrent's ever spent seeding
		 */
		public int secondsSeeding;
		/**
		 *  A torrent is considered finished if it has met its seed ratio. As a result, only paused torrents can be finished.
		 */
		public bool finished;
	}

	[CCode (cname = "tr_torrent", cprefix = "tr_torrent", free_function = "tr_free", has_type_id = false)]
	[Compact]
	public class Torrent {

		[PrintfFormat]
		[CCode (header_filename = "libtransmission/utils.h", cname = "tr_torerr")]
		public void show_error (string fmt, ...);
		[PrintfFormat]
		[CCode (header_filename = "libtransmission/utils.h", cname = "tr_torinf")]
		public void show_info (string fmt, ...);
		[PrintfFormat]
		[CCode (header_filename = "libtransmission/utils.h", cname = "tr_tordbg")]
		public void show_debug (string fmt, ...);

		/**
		 * Removes our .torrent and .resume files for this torrent and frees it.
		 */
		[DestroysInstance]
		[CCode (cname = "tr_torrentRemove")]
		public void remove ();

		/**
		 * Start a torrent
		 */
		[CCode (cname = "tr_torrentStart")]
		public void start ();

		/**
		 * Stop (pause) a torrent
		 */
		[CCode (cname = "tr_torrentStop")]
		public void stop ();

		/**
		 * Tell transmsision where to find this torrent's local data.
		 *
		 * @param move_from_previous_location If `true', the torrent's incompleteDir will be clobberred such that additional files being added will be saved to the torrent's downloadDir.
		 */
		[CCode (cname = "tr_torrentSetLocation")]
		public void set_location (string location, bool move_from_previous_location, out double progress, out LocationStatus state);

		public uint64 bytes_left_to_allocate {
			[CCode (cname = "tr_torrentGetBytesLeftToAllocate")]
			get;
		}

		/**
		 * This torrent's unique ID.
		 *
		 * IDs are good as simple lookup keys, but are not persistent between sessions. If you need that, use {@link info.hash} or {@link info.hashString}.
		 */
		public int id {
			[CCode (cname = "tr_torrentId")]
			get;
		}

		/**
		 * This torrent's name.
		 */
		public string name {
			[CCode (cname = "tr_torrentName")]
			get;
		}

		/**
		 * Find the location of a torrent's file by looking with and without the ".part" suffix, looking in downloadDir and incompleteDir, etc.
		 * @param fileNum The index into {@link info.files}
		 * @return The location of this file on disk, or null if no file exists yet.
		 */
		[CCode (cname = "tr_torrentFindFile")]
		public string? get (int fileNo);

		[CCode (cname = "tr_torrentSetSpeedLimit_KBps")]
		public void set_speed_limit (Direction direction, int kBps);
		[CCode (cname = "tr_torrentGetSpeedLimit_KBps")]
		public int get_speed_limit (Direction direction);

		[CCode (cname = "tr_torrentUseSpeedLimit")]
		public void use_speed_limit (Direction direction, bool use);
		[CCode (cname = "tr_torrentUsesSpeedLimit")]
		public bool uses_speed_limit (Direction direction);

		public bool use_session_limits {
			[CCode (cname = "tr_torrentUseSessionLimits")]
			set;
			[CCode (cname = "tr_torrentUsesSessionLimits")]
			get;
		}

		public RatioLimit ratio_mode {
			[CCode (cname = "tr_torrentSetRatioMode")]
			set;
			[CCode (cname = "tr_torrentGetRatioMode")]
			get;
		}

		public double ratio_limit {
			[CCode (cname = "tr_torrentSetRatioLimit")]
			set;
			[CCode (cname = "tr_torrentGetRatioLimit")]
			get;
		}

		[CCode (cname = "tr_torrentGetSeedRatio")]
		public bool get_seed_ratio (out double ratio);

		public IdleLimit idlde_mode {
			[CCode (cname = "tr_torrentSetIdleMode")]
			set;
			[CCode (cname = "tr_torrentGetIdleMode")]
			get;
		}

		public uint16 idle_limit {
			[CCode (cname = "tr_torrentSetIdleLimit")]
			set;
			[CCode (cname = "tr_torrentGetIdleLimit")]
			get;
		}

		[CCode (cname = "tr_torrentGetSeedIdle")]
		public bool get_seed_idle (out uint16 minutes);

		public uint16 peer_limit {
			[CCode (cname = "tr_torrentSetPeerLimit")]
			set;
			[CCode (cname = "tr_torrentGetPeerLimit")]
			get;
		}

		/**
		 * Set a batch of files to a particular priority.
		 */
		[CCode (cname = "tr_torrentSetFilePriorities")]
		public void set_file_priorities ([CCode (array_length_type = "tr_file_index_t")] file_index[] files, Priority priority);

		/**
		 * Get this torrent's file priorities.
		 */
		[CCode (cname = "tr_torrentGetFilePriorities")]
		public Priority[] get_file_priorities ();

		/**
		 * Set a batch of files to be downloaded or not.
		 */
		[CCode (cname = "tr_torrentSetFileDLs")]
		public void set_file_downloads ([CCode (array_length_type = "tr_file_index_t")] file_index[] files, bool download);

		public info? info {
			[CCode (cname = "tr_torrentInfo")]
			get;
		}

		/**
		 * Raw function to change the torrent's downloadDir field.
		 *
		 * This should only be used by libtransmission or to bootstrap a newly-instantiated object.
		 */
		public string download_dir {
			[CCode (cname = "tr_torrentSetDownloadDir")]
			set;
			[CCode (cname = "tr_torrentGetDownloadDir")]
			get;
		}

		/**
		 * Returns the root directory of where the torrent is.
		 *
		 * This will usually be the downloadDir. However if the torrent has an incompleteDir enabled and hasn't finished downloading yet, that will be returned instead.
		 */
		public string current_dir {
			[CCode (cname = "tr_torrentGetCurrentDir")]
			get;
		}

		/**
		 * Returns a string with a magnet link of the torrent.
		 */
		public string magnet_link {
			[CCode (cname = "tr_torrentGetMagnetLink")]
			owned get;
		}

		/**
		 * Modify a torrent's tracker list.
		 *
		 * This updates both the torrent object's tracker list and the metainfo file in configuration directory's torrent subdirectory.
		 *
		 *
		 * NOTE: only the `tier' and `announce' fields are used. libtransmission derives `scrape' from `announce' and reassigns 'id'.
		 * @param trackers An array of trackers, sorted by tier from first to last.
		 */
		[CCode (cname = "tr_torrentSetAnnounceList")]
		public bool set_announce_list ([CCode (array_length_type = "int")] tracker_info[] trackers);

		/**
		 * Register to be notified whenever a torrent's "completeness" changes.
		 *
		 * This will be called, for example, when a torrent finishes downloading and changes from {@link Completeness.LEECH} to
		 * either {@link Completeness.SEED} or {@link Completeness.PARTIAL_SEED}.
		 *
		 * The function is invoked FROM LIBTRANSMISSION'S THREAD! This means the function must be fast (to avoid blocking peers), shouldn't call libtransmission functions (to avoid deadlock), and shouldn't modify client-level memory without using a mutex!
		 */
		[CCode (cname = "tr_torrentSetCompletenessCallback")]
		public void set_completeness_callback (CompletnessFunc func);
		[CCode (cname = "tr_torrentClearCompletenessCallback")]
		public void clear_completeness_callback ();

		/**
		 * Register to be notified whenever a torrent changes from having incomplete metadata to having complete metadata.
		 *
		 * This happens when a magnet link finishes downloading metadata from its peers.
		 */
		[CCode (cname = "tr_torrentSetMetadataCallback")]
		public void set_metadata_callback (MetadataFunc func);

		/**
		 * Register to be notified whenever a torrent's ratio limit has been hit.
		 *
		 * This will be called when the torrent's upload/download ratio has met or exceeded the designated ratio limit.
		 *
		 * Has the same restrictions as {@link Torrent.set_completeness_callback}
		 */
		[CCode (cname = "tr_torrentSetRatioLimitHitCallback")]
		public void set_ratio_limit_callback (RatioLimitHitFunc func);
		[CCode (cname = "tr_torrentClearRatioLimitHitCallback")]
		public void clear_ratio_limit_callback ();

		/**
		 * Register to be notified whenever a torrent's idle limit has been hit.
		 *
		 * This will be called when the seeding torrent's idle time has met or exceeded the designated idle limit.
		 *
		 * Has the same restrictions as {@link Torrent.set_completeness_callback}
		 */
		[CCode (cname = "tr_torrentSetIdleLimitHitCallback")]
		public void set_idle_limit_hit_callback (IdleLimitHitFunc func);

		[CCode (cname = "tr_torrentClearIdleLimitHitCallback")]
		public void clear_idle_limit_hit_callback ();

		/**
		 * Perform a manual announce
		 *
		 * Trackers usually set an announce interval of 15 or 30 minutes. Users can send one-time announce requests that override this interval by calling this method.
		 *
		 * The wait interval for manual announce is much smaller. You can test whether or not a manual update is possible (for example, to desensitize the button) by calling {@link Torrent.can_manual_update}.
		 */
		[CCode (cname = "tr_torrentManualUpdate")]
		public void manual_update ();
		public bool can_manual_update {
			[CCode (cname = "tr_torrentCanManualUpdate")]
			get;
		}

		public Priority priority {
			[CCode (cname = "tr_torrentSetPriority")]
			set;
			[CCode (cname = "tr_torrentGetPriority")]
			get;
		}

		public peer_stat[] peers {
			[CCode (array_length_pos = 0.9, cname = "tr_torrentPeers")]
			owned get;
		}

		public tracker_stat[] trackers {
			[CCode (array_length_pos = 0.9, cname = "tr_torrentTrackers")]
			owned get;
		}

		/**
		 * Get the download speeds for each of this torrent's webseed sources.
		 *
		 * To differentiate "idle" and "stalled" status, idle webseeds will return -1 instead of 0 KiB/s.
		 * @return an array floats giving download speeds. Each speed in the array corresponds to the webseed at the same array index in {@link info.webseeds}.
		 */
		public double[] web_speeds {
			[CCode (cname = "tr_torrentWebSpeeds_KBps")]
			owned get;
		}

		public file_stat[] files {
			[CCode (array_length_pos = 0.9, cname = "tr_torrentFiles")]
			owned get;
		}

		/**
		 * Use this to draw an advanced progress bar.
		 *
		 * Fills 'tab' which you must have allocated: each byte is set to either -1 if we have the piece, otherwise it is set to the number of connected peers who have the piece.
		 */
		[CCode (cname = "tr_torrentAvailability")]
		public void get_availability ([CCode (array_length_type = "int")] int8[] tab);
		[CCode (cname = "tr_torrentAmountFinished")]
		public void get_amount_finished ([CCode (array_length_type = "int")] float[] tab);
		[CCode (cname = "tr_torrentVerify")]
		public void verify ();

		public bool has_metadata {
			[CCode (cname = "tr_torrentHasMetadata")]
			get;
		}

		/**
		 * Get updated information on the torrent.
		 *
		 * This is typically called by the GUI clients every second or so to get a new snapshot of the torrent's status.
		 */
		public stat? stat {
			[CCode (cname = "tr_torrentStat")]
			get;
		}

		/**
		 * Get updated information on the torrent.
		 *
		 * Like {@link Torrent.stat}, but only recalculates the statistics if it's been longer than a second since they were last calculated. This can reduce the CPU load if you're calling it frequently.
		 */
		public stat? stat_cached {
			[CCode (cname = "tr_torrentStatCached")]
			get;
		}
	}

	[CCode (cheader_filename = "libtorrent/makemeta.h", cname = "tr_metainfo_builder_file", has_destroy_function = false, has_copy_function = false, has_type_id = false)]
	public struct builder_file {
		public unowned string filename;
		public uint64 size;
	}

	[CCode (cheader_filename = "libtorrent/makemeta.h", cname = "tr_metainfo_builder_err", cprefix = "TR_MAKEMETA_", has_type_id = false)]
	public enum BuilderError {
		OK,
		URL,
		CANCELLED,
		IO_READ,
		IO_WRITE
	}

	[CCode (cheader_filename = "libtorrent/makemeta.h", cname = "tr_metainfo_builder", cprefix = "tr_metaInfoBuilder", free_function = "tr_metaInfoBuilderFree", has_type_id = false)]
	[Compact]
	public class Builder {
		[CCode (cname = "tr_metaInfoBuilderCreate")]
		public Builder (string topFile);

		public string top;
		[CCode (array_length_cname = "fileCount", array_length_type = "uint32")]
		public builder_file[] files;
		[CCode (cname = "totalSize")]
		public uint64 total_size;
		[CCode (cname = "pieceSize")]
		public uint32 piece_size;
		[CCode (cname = "pieceCount")]
		public uint32 piece_count;
		[CCode (cname = "isSingleFile")]
		public bool is_single_file;

		[CCode (array_length_cname = "trackerCount", array_length_type = "int")]
		public tracker_info[] trackers;
		public string comment;
		[CCode (cname = "outputFile")]
		public string outputFile;
		[CCode (cname = "isPrivate")]
		public bool is_private;

		[CCode (cname = "pieceIndex")]
		public uint32 piece_index;
		[CCode (cname = "abortFlag")]
		public bool abort_flag;
		[CCode (cname = "isDone")]
		public bool is_done;
		public BuilderError result;

		/**
		 * File in use when result was set to {@link BuilderError.IO_READ} or {@link BuilderError.IO_WRITE}, or the URL in use when the result was set to {@link BuilderError.URL}.
		 */
		public char errfile[2048];

		/**
		 * errno encountered when result was set to {@link BuilderError.IO_READ} or {@link BuilderError.IO_WRITE}
		 */
		public int my_errno;

		/**
		 * Create a new .torrent file
		 *
		 * This is actually done in a worker thread, not the main thread!
		 * Otherwise the client's interface would lock up while this runs.
		 *
		 * It is the caller's responsibility to poll {@link Builder.is_done} from time to time! When the worker thread sets that flag, the caller must destroy the builder.
		 *
		 * @param outputFile If null, {@link Builder.top} + ".torrent" will be used.
		 * @param trackers An array of trackers, sorted by tier from first to last.
		 */
		[CCode (cname = "tr_makeMetaInfo")]
		public void make_file (string outputFile, tracker_info[] trackers, string comment, bool is_private);
	}

	[CCode (cheader_filename = "libtransmission/utils.h", cprefix = "tr_", lower_case_cprefix = "tr_")]
	namespace Log {
		[CCode (cname = "TR_MAX_MSG_LOG")]
		public const int MAX_MSG_LOG;

		[PrintfFormat]
		[CCode (cname = "tr_msg")]
		public void message (string file, int line, MessageLevel level, string torrent, string fmt, ...);

		[PrintfFormat]
		[CCode (cname = "tr_nerr")]
		public void named_error (string name, string fmt, ...);
		[PrintfFormat]
		[CCode (cname = "tr_ninf")]
		public void named_info (string name, string fmt, ...);
		[PrintfFormat]
		[CCode (cname = "tr_ndbg")]
		public void named_debug (string name, string fmt, ...);

		[PrintfFormat]
		[CCode (cname = "tr_err")]
		public void error (string fmt, ...);
		[PrintfFormat]
		[CCode (cname = "tr_inf")]
		public void info (string fmt, ...);
		[PrintfFormat]
		[CCode (cname = "tr_dbg")]
		public void debug (string fmt, ...);

		/**
		 * Return true if deep logging has been enabled by the user; false otherwise
		 */
		[CCode (cname = "tr_deepLoggingIsActive")]
		public bool is_deep_logging ();

		[PrintfFormat]
		[CCode (cname = "tr_deepLog")]
		public void deep_log (string file, int line, string name, string fmt, ...);

		/**
		 * Set the buffer with the current time formatted for deep logging.
		 */
		public unowned string get_log_time ([CCode (array_length_type = "size_t")] char[] buf);
	}

	[CCode (cheader_filename = "libtransmission/utils.h", cprefix = "tr_", lower_case_cprefix = "tr_")]
	namespace Path {
		/**
		 * Rich Salz's classic implementation of shell-style pattern matching for?, \, [], and * characters.
		 * @return 1 if the pattern matches, 0 if it doesn't, or -1 if an error occurred
		 */
		public int wildmat (string text, string pattern);

		/**
		 * Portability wrapper for basename() that uses the system implementation if available
		 */
		public string basename (string path);

		/**
		 * Portability wrapper for dirname() that uses the system implementation if available
		 */
		public string dirname (string path);

		/**
		 * Portability wrapper for mkdir()
		 *
		 * A portability wrapper around mkdir().
		 * On WIN32, the `permissions' argument is unused.
		 *
		 * @return zero on success, or -1 if an error occurred (in which case errno is set appropriately).
		 */
		public int mkdir (string path, int permissions);

		/**
		 * Like mkdir, but makes parent directories as needed.
		 *
		 * @return zero on success, or -1 if an error occurred (in which case errno is set appropriately).
		 */
		public int mkdirp (string path, int permissions);

		/**
		 * Loads a file and returns its contents.
		 * @return The file's contents. On failure, null is returned and errno is set.
		 */
		[CCode (cname = "tr_loadFile", array_length_type = "size_t", array_length_pos = 1.9)]
		uint8[]? load_file (string filename);

		/**
		 * Build a filename from a series of elements using the platform's correct directory separator.
		 */
		[CCode (cname = "tr_buildPath", sentinel = "NULL")]
		string build_path (string first_element, ...);

		/**
		 * Move a file
		 * @return 0 on success; otherwise, return -1 and set errno
		 */
		[CCode (cname = "tr_moveFile")]
		public int move_file (string oldpath, string newpath, out bool renamed);

		/**
		 * Test to see if the two filenames point to the same file.
		 */
		[CCode (cname = "tr_is_same_file")]
		public bool is_same_file (string filename1, string filename2);
	}

	[CCode (cheader_filename = "libtransmission/utils.h", cprefix = "tr_", lower_case_cprefix = "tr_")]
	namespace Time {

		[CCode (cname = "struct event", cprefix = "tr_", has_type_id = false)]
		[Compact]
		class Event {
			/**
			 * Convenience wrapper around timer_add() to have a timer wake up in a number of seconds and microseconds
			 * @param timer
			 * @param seconds
			 * @param microseconds
			 */
			[CCode (cname = "tr_timerAdd")]
			public void add (int seconds, int microseconds);

			/**
			 * Convenience wrapper around timer_add() to have a timer wake up in a number of milliseconds
			 * @param timer
			 * @param milliseconds
			 */
			[CCode (cname = "tr_timerAddMsec")]
			public void add_msec (int milliseconds);
		}

		/**
		 * Return the current date in milliseconds
		 */
		[CCode (cname = "tr_time_msec")]
		public uint64 get_time_msec ();

		/**
		 * Sleep the specified number of milliseconds
		 */
		[CCode (cname = "tr_wait_msec")]
		public void wait_msec (long delay_milliseconds);
		/**
		 * Very inexpensive form of time(NULL)
		 *
		 * This function returns a second counter that is updated once per second. If something blocks the libtransmission thread for more than a second, that counter may be thrown off, so this function is not guaranteed to always be accurate. However, it is *much* faster when 100% accuracy isn't needed.
		 * @return the current epoch time in seconds
		 */
		public time_t get_time ();
	}

	[CCode (cheader_filename = "libtransmission/utils.h", cprefix = "tr_", lower_case_cprefix = "tr_")]
	namespace Url {

		/**
		 * Return true if the URL is a http or https URL that Transmission understands
		 */
		[CCode (cname = "tr_urlIsValidTracker")]
		public bool is_valid_tracker (string url);

		/**
		 * Return true if the URL is a [ http, https, ftp, ftps ] URL that Transmission understands
		 */
		[CCode (cname = "tr_urlIsValid")]
		public bool is_valid (uint8[] url);

		/**
		 * Parse a URL into its component parts
		 * @return zero on success or an error number if an error occurred
		 */
		[CCode (cname = "tr_urlParse")]
		public int parse (string url, int url_len, out string scheme, out string host, out int port, out string path);
	}

	[CCode (cheader_filename = "libtransmission/utils.h", cprefix = "tr_", lower_case_cprefix = "tr_")]
	namespace String {
		/**
		 * Make a copy of 'str' whose non-utf8 content has been corrected or stripped
		 * @return a new string
		 * @param str the string to make a clean copy of
		 * @param len the length of the string to copy. If -1, the entire string is used.
		 */
		[CCode (cname = "utf8clean")]
		public string make_utf8_clean (string str, int len = -1);

		public void sha1_to_hex ([CCode (array_null_terminated = true)] char[] result, uint8[] sha1);

		public void hex_to_sha1 ([CCode (array_length = false)] uint8[] result, string hex);

		/**
		 * Convenience function to determine if an address is an IP address (IPv4 or IPv6)
		 */
		[CCode (cname = "tr_addressIsIP")]
		public bool address_is_ip (string address);

		/**
		 * Compute a ratio given a numerator and denominator.
		 * @return {@link RATIO_NA}, {@link RATIO_INF}, or a number in [0..1]
		 */
		[CCode (cname = "tr_getRatio")]
		public double get_ratio (uint64 numerator, uint64 denominator);

		/**
		 * Given a string like "1-4" or "1-4,6,9,14-51", this returns an array of all the integers in the set.
		 *
		 * For example, "5-8" will return [ 5, 6, 7, 8 ].
		 * @return an array of integers or null if a fragment of the string can't be parsed.
		 */
		[CCode (array_length_type = "int", array_length_pos = 2.9, cname = "parseNumberRange")]
		public int[]? parse_number_range (string str, int str_len);

		/**
		 * Truncate a double value at a given number of decimal places.
		 *
		 * This can be used to prevent a printf() call from rounding up:
		 * call with the decimal_places argument equal to the number of
		 * decimal places in the printf()'s precision:
		 *
		 * * printf("%.2f%%", 99.999 ) ==> "100.00%"
		 * * printf("%.2f%%", tr_truncd(99.999, 2)) ==> "99.99%"
		 * These should match
		 */
		[CCode (cname = "tr_truncd")]
		public double truncate (double x, int decimal_places);

		/**
		 * Return a percent formatted string of either x.xx, xx.x or xxx
		 */
		[CCode (cname = "tr_strpercent")]
		public unowned string format_precent ([CCode (array_length_type = "size_t", array_length_pos = 2.9)] char[] buf, double x);

		/**
		 * Convert ratio to a string
		 * @param buf the buffer to write the string to
		 * @param ratio the ratio to convert to a string
		 * @param the string representation of "infinity"
		 */
		[CCode (cname = "tr_strratio")]
		public unowned string format_ratio ([CCode (array_length_type = "size_t")] char[] buf, double ratio, string infinity);

		public uint speed_K;
		public uint mem_K;
		public uint size_K;

		[CCode (cprefix = "tr_formatter_")]
		namespace Units {
			public void size_init (uint kilo, string kb, string mb, string gb, string tb);
			public void speed_init (uint kilo, string kb, string mb, string gb, string tb);
			[CCode (cname = "tr_formatter_mem_init")]
			public void mem_init (uint kilo, string kb, string mb, string gb, string tb);

			/**
			 * Format a speed from KBps into a user-readable string.
			 */
			public unowned string speed_KBps ([CCode (array_length_type = "size_t", array_length_pos = 2.9)] char[] buf, double KBps);

			/**
			 * Format a memory size from bytes into a user-readable string.
			 */
			public unowned string mem_B ([CCode (array_length_type = "size_t", array_length_pos = 2.9)] char[] buf, int64 bytes);

			/**
			 * Format a memory size from MB into a user-readable string.
			 */
			public unowned string mem_MB ([CCode (array_length_type = "size_t", array_length_pos = 2.9)] char[] buf, double MBps);

			/**
			 * Format a file size from bytes into a user-readable string.
			 */
			public unowned string size_B ([CCode (array_length_type = "size_t", array_length_pos = 2.9)] char[] buf, int64 bytes);

			public void get_units (variant dict);
		}
	}
}

