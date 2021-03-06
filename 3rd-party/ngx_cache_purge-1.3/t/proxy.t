# vi:filetype=perl

use lib 'lib';
use Test::Nginx::Socket;

repeat_each(1);

plan tests => repeat_each() * (blocks() * 3 + 3 * 1);

our $http_config = <<'_EOC_';
    proxy_cache_path  /tmp/ngx_cache_purge_cache keys_zone=test_cache:10m;
    proxy_temp_path   /tmp/ngx_cache_purge_temp 1 2;
_EOC_

our $config = <<'_EOC_';
    location /proxy {
        proxy_pass         $scheme://127.0.0.1:$server_port/etc/passwd;
        proxy_cache        test_cache;
        proxy_cache_key    $uri$is_args$args;
        proxy_cache_valid  3m;
        add_header         X-Cache-Status $upstream_cache_status;
    }

    location ~ /purge(/.*) {
        proxy_cache_purge  test_cache $1$is_args$args;
    }

    location = /etc/passwd {
        root               /;
    }
_EOC_

worker_connections(128);
no_shuffle();
run_tests();

no_diff();

__DATA__

=== TEST 1: prepare
--- http_config eval: $::http_config
--- config eval: $::config
--- request
GET /proxy/passwd
--- error_code: 200
--- response_headers
Content-Type: text/plain
--- response_body_like: root
--- timeout: 10
--- skip_nginx2: 3: < 0.8.3 or < 0.7.62



=== TEST 2: get from cache
--- http_config eval: $::http_config
--- config eval: $::config
--- request
GET /proxy/passwd
--- error_code: 200
--- response_headers
Content-Type: text/plain
X-Cache-Status: HIT
--- response_body_like: root
--- timeout: 10
--- skip_nginx2: 4: < 0.8.3 or < 0.7.62



=== TEST 3: purge from cache
--- http_config eval: $::http_config
--- config eval: $::config
--- request
DELETE /purge/proxy/passwd
--- error_code: 200
--- response_headers
Content-Type: text/html
--- response_body_like: Successful purge
--- timeout: 10
--- skip_nginx2: 3: < 0.8.3 or < 0.7.62



=== TEST 4: purge from empty cache
--- http_config eval: $::http_config
--- config eval: $::config
--- request
DELETE /purge/proxy/passwd
--- error_code: 404
--- response_headers
Content-Type: text/html
--- response_body_like: 404 Not Found
--- timeout: 10
--- skip_nginx2: 3: < 0.8.3 or < 0.7.62



=== TEST 5: get from source
--- http_config eval: $::http_config
--- config eval: $::config
--- request
GET /proxy/passwd
--- error_code: 200
--- response_headers
Content-Type: text/plain
X-Cache-Status: MISS
--- response_body_like: root
--- timeout: 10
--- skip_nginx2: 4: < 0.8.3 or < 0.7.62



=== TEST 6: get from cache (again)
--- http_config eval: $::http_config
--- config eval: $::config
--- request
GET /proxy/passwd
--- error_code: 200
--- response_headers
Content-Type: text/plain
X-Cache-Status: HIT
--- response_body_like: root
--- timeout: 10
--- skip_nginx2: 4: < 0.8.3 or < 0.7.62
