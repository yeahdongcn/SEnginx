# vi:filetype=

use Test::Nginx::Socket; # 'no_plan';

repeat_each(2);

plan tests => 37 * repeat_each();

no_diff;

run_tests();

__DATA__

=== TEST 1: set Server
--- config
    #more_set_headers 'Last-Modified: x';
    more_clear_headers 'Last-Modified';
--- request
    GET /index.html
--- response_headers
! Last-Modified
--- response_body_like: It works!



=== TEST 2: variables in the Ranges header
--- config
    location /index.html {
        set $rfrom 1;
        set $rto 3;
        more_set_input_headers 'Range: bytes=$rfrom - $rto';
        #more_set_input_headers 'Range: bytes=1 - 3';
        #echo $http_range;
    }
--- request
GET /index.html
--- error_code: 206
--- response_body chomp
htm



=== TEST 3: mime type overriding (inlined types)
--- config
    more_clear_headers 'X-Powered-By' 'X-Runtime' 'ETag';

    types {
        text/html                             html htm shtml;
        text/css                              css;
    }
--- user_files
>>> a.css
hello
--- request
GET /a.css
--- error_code: 200
--- response_headers
Content-Type: text/css
--- response_body
hello



=== TEST 4: mime type overriding (included types file)
--- config
    more_clear_headers 'X-Powered-By' 'X-Runtime' 'ETag';
    include mime.types;
--- user_files
>>> a.css
hello
>>> ../conf/mime.types
types {
    text/html                             html htm shtml;
    text/css                              css;
}
--- request
GET /a.css
--- error_code: 200
--- response_headers
Content-Type: text/css
--- response_body
hello



=== TEST 5: empty variable as the header value
--- config
    location /foo {
        more_set_headers 'X-Foo: $arg_foo';
        echo hi;
    }
--- request
    GET /foo
--- response_headers
! X-Foo
--- response_body
hi



=== TEST 6: range bug
--- config
    location /index.html {
        more_clear_input_headers "Range*" ;
        more_clear_input_headers "Content-Range*" ;

        more_set_input_headers 'Range: bytes=1-5';
        more_set_headers  'Content-Range: bytes 1-5/1000';
    }
--- request
    GET /index.html
--- more_headers
Range: bytes=1-3
--- raw_response_headers_like: Content-Range: bytes 1-5/1000$
--- response_body chop
html>
--- error_code: 206
--- SKIP



=== TEST 7: Allow-Ranges
--- config
    location /index.html {
        more_clear_headers 'Accept-Ranges';
    }
--- request
    GET /index.html
--- response_headers
! Accept-Ranges
--- response_body_like: It works



=== TEST 8: clear hand-written Allow-Ranges headers
--- config
    location /index.html {
        more_set_headers 'Accept-Ranges: bytes';
        more_clear_headers 'Accept-Ranges';
    }
--- request
    GET /index.html
--- response_headers
! Accept-Ranges
--- response_body_like: It works



=== TEST 9: clear first, then add
--- config
    location /bug {
        more_clear_headers 'Foo';
        more_set_headers 'Foo: a';
        echo hello;
    }
--- request
    GET /bug
--- raw_response_headers_like eval
".*Foo: a.*"
--- response_body
hello



=== TEST 10: first add, then clear, then add again
--- config
    location /bug {
        more_set_headers 'Foo: a';
        more_clear_headers 'Foo';
        more_set_headers 'Foo: b';
        echo hello;
    }
--- request
    GET /bug
--- raw_response_headers_like eval
".*Foo: b.*"
--- response_body
hello



=== TEST 11: override charset
--- config
    location /foo {
        charset iso-8859-1;
        default_type "text/html";
        echo hiya;
    }

    location /bug {
        more_set_headers "Content-Type: text/html; charset=UTF-8";
        proxy_pass http://127.0.0.1:$server_port/foo;
    }
--- request
    GET /bug
--- response_body
hiya
--- response_headers
Content-Type: text/html; charset=UTF-8



=== TEST 12: set multi-value header to a single value
--- config
    location /main {
        set $footer '';
        proxy_pass http://127.0.0.1:$server_port/foo;
        more_set_headers 'Foo: b';
        header_filter_by_lua '
            ngx.var.footer = ngx.header.Foo
        ';
        echo_after_body $footer;
    }
    location /foo {
        echo foo;
        add_header Foo a;
        add_header Foo c;
    }
--- request
    GET /main
--- response_headers
Foo: b
--- response_body
foo
b



=== TEST 13: set multi values to cache-control and override it with multiple values (to reproduce a bug)
--- config
    location /lua {
        content_by_lua '
            ngx.header.cache_control = { "private", "no-store", "foo", "bar", "baz" }
            ngx.send_headers()
            ngx.say("Cache-Control: ", ngx.var.sent_http_cache_control)
        ';
        more_clear_headers Cache-Control;
        add_header Cache-Control "blah";
    }
--- request
    GET /lua
--- response_headers
Cache-Control: blah
--- response_body
Cache-Control: blah



=== TEST 14: set 20+ headers
--- config
    location /test {
        more_clear_input_headers "Authorization";
        echo $http_a1;
        echo $http_authorization;
        echo $http_a2;
        echo $http_a3;
        echo $http_a23;
        echo $http_a24;
        echo $http_a25;
    }
--- request
    GET /test
--- more_headers eval
my $i = 1;
my $s;
while ($i <= 25) {
    $s .= "A$i: $i\n";
    if ($i == 22) {
        $s .= "Authorization: blah\n";
    }
    $i++;
}
#warn $s;
$s
--- response_body
1

2
3
23
24
25

