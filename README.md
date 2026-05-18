# ols-wp

基于 `litespeedtech/openlitespeed:1.9.0-lsphp85` 的 OpenLiteSpeed + LSPHP + WordPress Docker 方案。

这个版本是**单容器轻量化自动化版**：

- 使用 `ols(OpenLiteSpeed) + lsphp + wp(WordPress)`
- 容器只处理 HTTP(80)，HTTPS(443) 由外部网关/反向代理处理
- 不带数据库管理工具，比如 phpMyAdmin
- 使用 `template/` 目录中的本地模板包构建 WordPress 文件
- 首次初始化时导入 `WORDPRESS_TEMPLATE_SQL` 指定的 SQL
- 首次初始化时根据 `.env` 生成 `wp-config.php`
- 使用 `.ols-wp-initialized` 作为初始化完成标记
- 自动写入数据库连接、WordPress salts、反向代理 HTTPS 检测等配置

## 单独编译docker
```bash
docker build \
  --build-arg OLS_VERSION=1.9.0-lsphp85 \
  --build-arg WORDPRESS_TEMPLATE=template/woostify.tar.gz \
  --build-arg WORDPRESS_TEMPLATE_SQL=sql/woostify.sql \
  -t yourname/ols-wp-woostify:latest \
  .

# docker login
# docker push yourname/ols-wp-woostify:latest
# image: yourname/ols-wp-woostify:latest
```

## 1panel

使用 1p_compose.yml 和 1p.env

## dpaneel

上传目录服务器编译或者使用 1p_compose.yml 和 1p.env

## 适用场景

适合这种场景：

- 已经有公用网关处理 SSL/TLS
- 已经有公用数据库、Redis
- 只想单独部署一个 WordPress 站点容器
- 希望容器轻量化、少维护
- 希望使用预先准备好的 WordPress 模板包
- 不想手动维护 `wp-config.php`

## 模板说明

> 模版只能使用.tar.gz格式压缩，根目录必须是 wordpress，否则解压异常目录错乱。

**请登录后马上修改模板的默认用户名密码**

> wp后台
- 用户名: demo
- 密码：demo
- 密码串：$wp$2y$12$HexwVzImup4hTpjKppj43eR7T8FlQDOP0Yz8QKplYDxjCxQvMF1sS

> ols后台
- 用户名: demo
- 密码：123456
- `/usr/local/lsws/admin/misc/admpass.sh` 修改账号密码

### 模板列表

1. latest模板，官方6.9.4 纯净版
2. woostify模板，主题使用woostify，已经安装好基础插件

## 项目文件

- `Dockerfile`：构建 OpenLiteSpeed + LSPHP + WordPress 镜像
- `compose.yml`：Docker Compose 启动示例
- `.env.example`：环境变量示例
- `template/`：本地 WordPress 模板压缩包目录，例如 `latest.tar.gz`、`woostify.tar.gz`
- `sql/`：本地数据库初始化 SQL 目录，例如 `latest.sql`、`woostify.sql`
- `scripts/docker-entrypoint.sh`：启动入口脚本，负责数据库检查、SQL 导入、`wp-config.php` 生成
- `conf/ols/wordpress.htaccess`：WordPress rewrite 与基础防护
- `conf/ols/conf/httpd_config.conf`：OpenLiteSpeed 全局配置，包含 `lsphp` 进程内存限制
- `conf/ols/vhosts/vhconf.conf`：站点级 PHP 配置，包含 `memory_limit`
- `test/wp-config-sample.php.txt`：用于测试 `wp-config.php` 生成逻辑的样本文件

## 快速开始

1. 准备模板包。
   把模板压缩包放到 `template/` 目录，例如：
   - `template/latest.tar.gz`
   - `template/woostify.tar.gz`
2. 复制环境变量文件：
   `cp .env.example .env`
3. 编辑 `.env`，至少修改以下配置：
   - `WORDPRESS_TEMPLATE`
   - `WORDPRESS_DB_HOST`
   - `WORDPRESS_DB_NAME`
   - `WORDPRESS_DB_USER`
   - `WORDPRESS_DB_PASSWORD`
4. 构建并启动：
   `docker compose up -d --build`
5. 访问：
   - WordPress：`http://localhost:8080`
   - OpenLiteSpeed WebAdmin：`http://localhost:7080`

> 生产环境建议不要把 `7080` 暴露到公网。如果不需要 WebAdmin，可以删除 `compose.yml` 里的 `7080:7080` 端口映射。

## 环境变量

### 必填

| 变量 | 说明 | 示例 |
| --- | --- | --- |
| `WORDPRESS_DB_HOST` | 数据库地址，支持 `host` 或 `host:port` 格式 | `mysql:3306` 或 `mysql` |
| `WORDPRESS_DB_NAME` | 数据库名；如果不存在，脚本会自动创建 | `wordpress` |
| `WORDPRESS_DB_USER` | 数据库用户名 | `wordpress` |
| `WORDPRESS_DB_PASSWORD` | 数据库密码 | `change-me` |

### 可选

| 变量 | 默认值 | 说明 |
| --- | --- | --- |
| `WORDPRESS_TEMPLATE` | `template/latest.tar.gz` | 构建时使用的 WordPress 文件模板包路径，路径相对项目根目录 |
| `WORDPRESS_TEMPLATE_SQL` | `sql/latest.sql` | 构建时复制进镜像的数据库初始化 SQL 路径，路径相对项目根目录 |
| `WORDPRESS_INIT_SQL_FILE` | `/docker-entrypoint-initdb.d/init.sql` | 运行时使用的 SQL 文件路径（镜像内路径），一般无需修改 |
| `HTTP_PORT` | `8080` | 宿主机暴露的 HTTP 端口 |
| `OLS_ADMIN_PORT` | `7080` | 宿主机暴露的 OLS WebAdmin 端口 |
| `WORDPRESS_DB_PORT` | `3306` | 数据库端口；如果 `WORDPRESS_DB_HOST` 已包含端口则忽略此项 |
| `WORDPRESS_DB_CHARSET` | `utf8mb4` | 数据库字符集 |
| `WORDPRESS_DB_COLLATE` | 空 | 数据库排序规则；一般留空即可 |
| `WORDPRESS_TABLE_PREFIX` | `wp_` | WordPress 表前缀 |
| `WORDPRESS_DEBUG` | `false` | 是否开启 WP debug |
| `WORDPRESS_DISALLOW_FILE_EDIT` | `true` | 是否禁止后台编辑主题/插件文件 |
| `WORDPRESS_FORCE_SSL_ADMIN` | `false` | 是否强制后台使用 HTTPS |
| `WORDPRESS_BEHIND_PROXY` | `1` | 是否写入反向代理 HTTPS 识别逻辑 |
| `WORDPRESS_HOME` | 空 | 固定站点首页 URL |
| `WORDPRESS_SITEURL` | 空 | 固定站点 URL |
| `WORDPRESS_CONFIG_EXTRA` | 空 | 追加到 `wp-config.php` 受管配置块中的自定义 PHP 配置 |

## PHP 与 OLS 资源配置

镜像内的 PHP 与 OpenLiteSpeed 相关限制主要分布在两处：

- `conf/ols/vhosts/vhconf.conf`：站点级 PHP 配置
- `conf/ols/conf/httpd_config.conf`：OpenLiteSpeed 全局配置，包含 `lsphp` 进程限制、请求体大小限制和内存缓冲配置

当前实际生效的关键配置为：

- `memory_limit = 512M` - PHP 单请求内存限制
- `lsphp memSoftLimit = 512M` - OLS `lsphp` 进程软限制
- `lsphp memHardLimit = 512M` - OLS `lsphp` 进程硬限制
- `inMemBufSize = 50M` - OLS 内存缓冲大小
- `maxReqBodySize = 512M` - OLS 请求体大小上限
- `upload_max_filesize = 256M` - PHP 上传文件大小限制
- `post_max_size = 256M` - PHP POST 数据大小限制
- `max_execution_time = 300` - 脚本最大执行时间（秒）
- `max_input_vars = 3000` - 最大输入变量数
- `expose_php = Off` - 隐藏 PHP 版本信息

> 注意：`memory_limit = 512M` 和 `lsphp memHardLimit = 512M` 已经比较接近 `compose.yml` 里 `600m` 的容器内存上限。该配置适合需要较高单请求内存的 WordPress 场景，但如果插件较重、并发较高或出现 OOM，应优先考虑下调 PHP/LSAPI 内存限制，或提高容器内存上限。

## 安全加固

`.htaccess` 文件（`conf/ols/wordpress.htaccess`）包含基础安全规则：

- WordPress 标准 rewrite 规则
- HTTP Authorization 头传递支持（用于 REST API 认证）
- 禁止直接访问敏感文件：`wp-config.php`、`.env`、`composer.json`、`composer.lock`、`package.json`、`package-lock.json`
- 禁用目录列表（`Options -Indexes`）

## 模板包机制

项目使用本地 `template/` 目录中的模板包。构建时由 `.env` 中的 `WORDPRESS_TEMPLATE` 指定模板包路径，例如：
`WORDPRESS_TEMPLATE=template/woostify.tar.gz`

> 模版只能使用.tar.gz格式压缩，根目录必须是 wordpress，否则解压异常目录错乱。

`Dockerfile` 会检查这个文件是否存在：`template/woostify.tar.gz`
如果文件不存在，镜像构建会直接失败。
模板包会被解压到镜像内的站点目录：`/var/www/vhosts/localhost/html`
这个目录会作为 Docker named volume 首次初始化时的种子文件来源。

## 数据库模板 SQL

构建时由 `.env` 中的 `WORDPRESS_TEMPLATE_SQL` 指定初始化 SQL 文件路径，例如：`WORDPRESS_TEMPLATE_SQL=sql\woostify.sql`
`Dockerfile` 会检查这个文件是否存在，并复制到镜像内固定位置：`/docker-entrypoint-initdb.d/init.sql`
容器首次初始化时，入口脚本会导入这个文件。

## 数据持久化与初始化关系

`compose.yml` 默认使用 Docker named volume：
`wordpress-data:/var/www/vhosts/localhost/html`

需要区分两层初始化：

1. **站点文件初始化**
   - 由 Docker named volume 的默认行为完成
   - 当 `wordpress-data` 是新建空 volume 时，Docker 会把镜像内 `/var/www/vhosts/localhost/html` 的文件复制到 volume 中
   - 如果 `wordpress-data` 已经有内容，重建镜像/容器不会覆盖 volume 中的 WordPress 文件

2. **WordPress 业务初始化**
   - 由 `scripts/docker-entrypoint.sh` 完成
   - 判断标记是：`/var/www/vhosts/localhost/html/.ols-wp-initialized`
   - 标记不存在时执行初始化
   - 标记存在时跳过初始化

初始化流程：

1. 检查数据库服务连接
2. 确保目标数据库存在
3. 连接目标数据库
4. 导入 `WORDPRESS_TEMPLATE_SQL` 指定的 SQL
5. 根据模板生成 `wp-config.php`
6. 写入 `.ols-wp-initialized`

如果要完全重新初始化，通常需要同时处理：

- 删除 `wordpress-data` volume，或手动清理站点目录
- 清理/重建目标数据库
- 确认 `WORDPRESS_TEMPLATE_SQL` 指定的 SQL 是你要导入的数据

最直接但会删除站点文件的方式是：

`docker compose down -v`

> `down -v` 会删除 `wordpress-data`，包括 WordPress 文件、上传内容、插件、主题、`wp-config.php` 和 `.ols-wp-initialized`，操作前请先备份。

## `wp-config.php` 生成逻辑

入口脚本会从模板中的 `wp-config-sample.php` 生成 `wp-config.php`。

为了避免重复定义常量，脚本现在使用单一受管配置块：

- `/* ols-wp managed config:start */`
- `/* ols-wp managed config:end */`

受管配置块中包含：

- WordPress salts
- `DISALLOW_FILE_EDIT`
- `FORCE_SSL_ADMIN`
- `WP_HOME`
- `WP_SITEURL`
- 反向代理 HTTPS 检测逻辑
- `WORDPRESS_CONFIG_EXTRA`

生成逻辑只会把受管块插入到真正的 WordPress stop marker 前：
`/* That's all, stop editing! Happy publishing. */`
避免误匹配说明文字里的 `stop editing`，从根源避免重复插入配置块。

## 数据库连接检查与 SQL 导入

镜像内会安装 `mariadb-client`。容器启动时会执行以下数据库检查流程：

1. **检查数据库服务器连接** - 验证能否连接到 `WORDPRESS_DB_HOST` 指定的数据库服务器
2. **确保目标数据库存在** - 如果数据库不存在，自动执行 `CREATE DATABASE` 创建
3. **检查目标数据库连接** - 验证能否连接到具体的数据库
4. **导入初始化 SQL**（仅首次初始化时）- 导入 `/docker-entrypoint-initdb.d/init.sql`

这个 SQL 文件来自 `.env` 中的 `WORDPRESS_TEMPLATE_SQL`。
导入失败时容器会退出，由 Docker 的重启策略继续拉起。

### 数据库连接错误诊断

入口脚本会根据不同的数据库错误提供诊断提示：

- **ERROR 2002/2003/2005** - 网络/主机/端口连接失败，检查 `WORDPRESS_DB_HOST`、Docker 网络、数据库容器状态
- **ERROR 1045** - 认证失败，检查数据库用户名、密码和主机访问权限
- **ERROR 1049** - 目标数据库不存在（通常不会出现，因为脚本会自动创建）

## 反向代理说明

容器只监听 HTTP。HTTPS 应在外部网关、Nginx、Traefik、Caddy、负载均衡器等处终止。
默认会写入 `X-Forwarded-Proto` 检测逻辑。当反向代理传入：
`X-Forwarded-Proto: https`
WordPress 会识别当前请求为 HTTPS，避免后台跳转、混合内容、Cookie secure 判断等问题。
代理层建议传递：
- `Host`
- `X-Forwarded-Host`
- `X-Forwarded-Proto`

## 构建指定模板包

在 `.env` 中设置：
`WORDPRESS_TEMPLATE=template/woostify.tar.gz`
`WORDPRESS_TEMPLATE_SQL=sql/latest.sql`
然后重新构建：
`docker compose build --no-cache`
或者：
`docker compose up -d --build`

## 常用命令

第一次部署或修改镜像内容后启动：
`docker compose up -d --build`
日常启动：
`docker compose up -d`
日常重启：
`docker compose restart ols-wp`
查看日志：
`docker compose logs -f ols-wp`
停止：
`docker compose down`
停止并删除站点 volume：
`docker compose down -v`

## 注意事项 / 目前可能的问题

1. 当前项目不包含 MySQL/Redis 服务，只适合连接外部数据库/Redis。
2. 生产环境不要使用 `.env.example` 里的默认密码。
3. `WORDPRESS_TEMPLATE` 和 `WORDPRESS_TEMPLATE_SQL` 路径必须使用正斜杠 `/`（Unix 风格），例如 `template/woostify.tar.gz`，不要使用反斜杠 `\`。
4. 模板包必须使用 `.tar.gz` 格式压缩，且解压后的根目录必须是 `wordpress`，否则会导致目录结构错乱。
5. `litespeedtech/openlitespeed:1.9.0-lsphp85` 自带默认 OLS 配置。本项目目前仍复用基础镜像默认 listener/vhost，如果你需要完全可控的 OLS 站点配置，后续应显式接管 OLS 配置。
