<?php
/**
 * The base configuration for WordPress
 *
 * The wp-config.php creation script uses this file during the installation.
 * You don't have to use the website, you can copy this file to "wp-config.php"
 * and fill in the values.
 *
 * This file contains the following configurations:
 *
 * * Database settings
 * * Secret keys
 * * Database table prefix
 * * ABSPATH
 *
 * @link https://developer.wordpress.org/advanced-administration/wordpress/wp-config/
 *
 * @package WordPress
 */

// ** Database settings - You can get this info from your web host ** //
/** The name of the database for WordPress */
define( 'DB_NAME', 'wp' );

/** Database username */
define( 'DB_USER', 'root' );

/** Database password */
define( 'DB_PASSWORD', '123456' );

/** Database hostname */
define( 'DB_HOST', 'db:3306' );

/** Database charset to use in creating database tables. */
define( 'DB_CHARSET', 'utf8mb4' );

/** The database collate type. Don't change this if in doubt. */
define( 'DB_COLLATE', '' );

/**#@+
 * Authentication unique keys and salts.
 *
 * Change these to different unique phrases! You can generate these using
 * the {@link https://api.wordpress.org/secret-key/1.1/salt/ WordPress.org secret-key service}.
 *
 * You can change these at any point in time to invalidate all existing cookies.
 * This will force all users to have to log in again.
 *
 * @since 2.6.0
 */

/**#@-*/

/**
 * WordPress database table prefix.
 *
 * You can have multiple installations in one database if you give each
 * a unique prefix. Only numbers, letters, and underscores please!
 *
 * At the installation time, database tables are created with the specified prefix.
 * Changing this value after WordPress is installed will make your site think
 * it has not been installed.
 *
 * @link https://developer.wordpress.org/advanced-administration/wordpress/wp-config/#table-prefix
 */
$table_prefix = 'wp_';

/**
 * For developers: WordPress debugging mode.
 *
 * Change this to true to enable the display of notices during development.
 * It is strongly recommended that plugin and theme developers use WP_DEBUG
 * in their development environments.
 *
 * For information on other constants that can be used for debugging,
 * visit the documentation.
 *
 * @link https://developer.wordpress.org/advanced-administration/debug/debug-wordpress/
 */
define( 'WP_DEBUG', false );

/* Add any custom values between this line and the "stop editing" line. */




/* ols-wp managed config:start */
define( 'AUTH_KEY', 'z+6o7tYhGybBg32PdE5L3J7Kcpvp5ZZfs2aqHGOi3i2Kyqlgp0Dh3jtvVM9j3wfu' );
define( 'SECURE_AUTH_KEY', 'pEmKr4c1InSkZZSiPiFKANVwWlB0STPKcVLcl6yPXHOejcwVmlWl4DXXq7Zp1m' );
define( 'LOGGED_IN_KEY', 'xIaO6YGdY5aRKgoYV7mgpAIFOYpzDb5AUlaxveX+1EBeMV5KSkCdLnwhV9o0nO' );
define( 'NONCE_KEY', 'a2SeC6F82d8VJeC7Ng2ekqKodknSIRxQpWaNGlVUETMucuylvtP2SZzAfTHjenQ' );
define( 'AUTH_SALT', 'H4QOIll9R03nhgqpUMAGTmKU743t5v8ZZc5jij9W5PQmnrOVE3sajnx2YrE67SD' );
define( 'SECURE_AUTH_SALT', 'ThUOSyQ2rpZuh9sucCaSebuSMJGqStD4jwmcmEoVAzbLeEDqLTxejOn9ECkv88m' );
define( 'LOGGED_IN_SALT', 'kGuegE4vQcQGIUGWm8jvI2RfslCUvOUPcmiv+Xo2AKFovg+a9QDZ+63Lbs8xZmZ' );
define( 'NONCE_SALT', 'hgw19T2MlQOmdk1jk7ElfjgDV9yWzLppEuu8JojIe1cBVL2ttpuRjr2ShmYC1JI' );
define( 'DISALLOW_FILE_EDIT', true );
define( 'FORCE_SSL_ADMIN', false );
define( 'WP_HOME', 'https://example.com' );
define( 'WP_SITEURL', 'https://example.com' );
if ( isset( $_SERVER['HTTP_X_FORWARDED_PROTO'] ) && strpos( $_SERVER['HTTP_X_FORWARDED_PROTO'], 'https' ) !== false ) {
    $_SERVER['HTTPS'] = 'on';
}
/* ols-wp managed config:end */

/* That's all, stop editing! Happy publishing. */

/** Absolute path to the WordPress directory. */
if ( ! defined( 'ABSPATH' ) ) {
	define( 'ABSPATH', __DIR__ . '/' );
}

/** Sets up WordPress vars and included files. */
require_once ABSPATH . 'wp-settings.php';
