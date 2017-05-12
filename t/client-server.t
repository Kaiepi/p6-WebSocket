use v6;
use Test;

use lib 't/lib';

use HTTP::Server::Tiny;
use WebSocket::P6SGI;
use WebSocket::Client;

use Test::TCP;

plan 5;

my $port = 15555;

# server thread
Promise.start: {
    note 'starting server';
    my $s = HTTP::Server::Tiny.new(port => $port);
    $s.run(-> %env {
        ws-psgi(%env,
            on-ready => -> $ws {
                ok 1, 's: ready';
            },
            on-text => -> $ws, $txt {
                is $txt, 'STEP1', 's: got text';
                $ws.send-text('STEP2');
            },
            on-binary => -> $ws, $binary {
                $ws.send-binary($binary);
            },
            on-close => -> $ws {
                ok 1, 's: close';
            },
        );
    })
}

wait_port($port);

note 'ready connect';

await Promise.anyof(
  Promise.start({
    WebSocket::Client.connect(
        "ws://127.0.0.1:$port/",
        on-text => -> $h, $txt {
            is $txt, 'STEP2', 'c:text';
            $h.send-close;
        },
        on-binary => -> $h, $txt {
            note 'got binary data'
        },
        on-close => -> $h {
            ok 1, 'c: close';
        },
        on-ready => -> $h {
            ok 1, 'c: ready';
            # Wait before sending the message to ensure the server handle setup is complete
            # This behaviour seems to be related to HTTP::Server::Tiny
            sleep 0.1;
            $h.send-text("STEP1");
        },
    )
  }),
  Promise.in(5).then( { fail "Test timed out!" } ),
);
